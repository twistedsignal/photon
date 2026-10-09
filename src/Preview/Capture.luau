-- previews a preset with Roblox's own renderer: apply it to the place, stage a small scene far
-- from the map, screenshot the viewport, then cancel the change-history recording so the place
-- goes back exactly as it was.
--
-- lighting takes a few seconds to finish updating after a change (sky, atmosphere and the
-- environment lighting fade in), so screenshots repeat until two in a row match.
const CaptureService = game:GetService("CaptureService")
const ChangeHistoryService = game:GetService("ChangeHistoryService")
const ContentProvider = game:GetService("ContentProvider")
const AssetService = game:GetService("AssetService")
const Lighting = game:GetService("Lighting")
const RunService = game:GetService("RunService")
const Selection = game:GetService("Selection")
const StarterGui = game:GetService("StarterGui")

const Schema = require("../Loader/Schema")
const Snapshot = require("../Loader/Snapshot")
const Stage = require("./Stage")
const Image = require("./Image")
const Settings = require("./Settings")

-- seconds before the first screenshot, and between screenshots.
const INTERVAL = 0.4
-- two screenshots this close (average difference per channel, 0-255) count as settled.
const STABLE_DIFFERENCE = 1.5
const MAX_SHOTS = 5
const SCREENSHOT_TIMEOUT = 10
const RECORDING_TIMEOUT = 3

const Capture = {}

local busy = false
const waiting: { thread } = {}

const function textures(data: Schema.Data): { string }
	const list = {}
	for _, effect in data.effects do
		if effect.class == "Sky" then
			for _, value in effect.props do
				if type(value) == "string" and value ~= "" then
					table.insert(list, value)
				end
			end
		end
	end
	return list
end

const function frames(count: number)
	for _ = 1, count do
		RunService.RenderStepped:Wait()
	end
end

-- one screenshot at a time: Studio drops a request made while another is still saving.
const function screenshot(): (EditableImage?, string?)
	local contentId: string? = nil
	local done = false
	const ok, problem = pcall(function()
		CaptureService:CaptureScreenshot(function(id: string)
			contentId = id
			done = true
		end)
	end)
	if not ok then
		return nil, `Studio couldn't take a screenshot: {problem}`
	end
	const started = os.clock()
	while not done and os.clock() - started < SCREENSHOT_TIMEOUT do
		task.wait()
	end
	if contentId == nil then
		return nil, "Studio didn't return a screenshot. Make sure the 3D viewport is visible."
	end
	const loaded, image = pcall(function()
		return AssetService:CreateEditableImageAsync(Content.fromUri(contentId :: string))
	end)
	if not loaded then
		return nil, `Couldn't read the screenshot: {image}`
	end
	return image, nil
end

-- average difference between two screenshots, sampled on a coarse grid.
const function difference(a: EditableImage, b: EditableImage): number
	if a.Size ~= b.Size then
		return math.huge
	end
	const size = a.Size
	const pixelsA = a:ReadPixelsBuffer(Vector2.zero, size)
	const pixelsB = b:ReadPixelsBuffer(Vector2.zero, size)
	local total, count = 0, 0
	for gy = 0, 35 do
		const y = math.floor((gy + 0.5) * size.Y / 36)
		for gx = 0, 63 do
			const x = math.floor((gx + 0.5) * size.X / 64)
			const offset = (y * size.X + x) * 4
			for channel = 0, 2 do
				total += math.abs(buffer.readu8(pixelsA, offset + channel) - buffer.readu8(pixelsB, offset + channel))
			end
			count += 3
		end
	end
	return total / count
end

-- other plugins can hold a recording for a moment; wait for them instead of failing.
const function beginRecording(): string?
	const started = os.clock()
	repeat
		const recording = ChangeHistoryService:TryBeginRecording("Photon preview")
		if recording then
			return recording
		end
		task.wait(0.1)
	until os.clock() - started > RECORDING_TIMEOUT
	return nil
end

-- stages the preset and screenshots it until the picture stops changing. returns the last shot.
-- the cancelled recording undoes everything here except the stage: it isn't Archivable, so
-- change history doesn't track it and it's destroyed by hand.
const function stageAndShoot(data: Schema.Data?, camera: Camera, built: { model: Model? }, options: Settings.Options, previewModel: Model?): (EditableImage?, string?)
	if data then
		Snapshot.apply(data, Lighting, nil, true)
	end
	const shot = Stage.build(workspace, options, previewModel)
	built.model = shot.model
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = shot.fieldOfView
	camera.CFrame = shot.camera
	frames(3)
	pcall(function()
		ContentProvider:PreloadAsync({ shot.model })
	end)
	task.wait(options.settleTime)

	local previous: EditableImage? = nil
	for _ = 1, MAX_SHOTS do
		-- Studio's camera controller can nudge the camera while we wait.
		camera.CFrame = shot.camera
		frames(1)
		const image, problem = screenshot()
		if image == nil then
			if previous then
				previous:Destroy()
			end
			return nil, problem
		end
		if previous then
			const settled = difference(previous, image) < STABLE_DIFFERENCE
			previous:Destroy()
			if settled then
				return image, nil
			end
		end
		previous = image
		task.wait(INTERVAL)
	end
	return previous, nil
end


-- previews data (or the place's current lighting when nil) at width x height. yields for a few
-- seconds; concurrent calls queue up and run one at a time.
function Capture.preview(data: Schema.Data?, width: number, height: number, options: Settings.Options?, previewModel: Model?): (EditableImage?, string?)
	if busy then
		table.insert(waiting, coroutine.running())
		coroutine.yield()
	end
	busy = true

	const camera = workspace.CurrentCamera
	const saved = {
		cframe = camera.CFrame,
		focus = camera.Focus,
		fieldOfView = camera.FieldOfView,
		cameraType = camera.CameraType,
	}
	const selected = Selection:Get()
	-- change history doesn't track this one, so it's put back by hand.
	const showGui = StarterGui.ShowDevelopmentGui

	if data then
		pcall(function()
			ContentProvider:PreloadAsync(textures(data))
		end)
	end

	local full: EditableImage?, problem: string?
	const recording = beginRecording()
	if recording == nil then
		problem = "Studio is in the middle of another change. Try again in a moment."
	else
		Selection:Set({})
		StarterGui.ShowDevelopmentGui = false
		const built: { model: Model? } = {}
		const ok, result, message = pcall(stageAndShoot, data, camera, built, options or Settings.defaults, previewModel)
		if built.model then
			built.model:Destroy()
		end
		StarterGui.ShowDevelopmentGui = showGui
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
		camera.CameraType = saved.cameraType
		camera.FieldOfView = saved.fieldOfView
		camera.CFrame = saved.cframe
		camera.Focus = saved.focus
		Selection:Set(selected)
		if ok then
			full, problem = result, message
		else
			problem = `Preview failed: {result}`
		end
	end

	local image: EditableImage? = nil
	if full then
		const ok, result = pcall(Image.fit, full, width, height)
		full:Destroy()
		if ok then
			image = result
		else
			problem = `Couldn't read the screenshot: {result}`
		end
	end

	busy = false
	const nextThread = table.remove(waiting, 1)
	if nextThread then
		busy = true
		task.spawn(nextThread)
	end
	return image, problem
end

return Capture
