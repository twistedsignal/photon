-- Shared preview defaults and validation for cross-place plugin settings.
const Settings = {}

export type Options = {
	autoCapture: boolean,
	fieldOfView: number,
	cameraDistance: number,
	cameraYaw: number,
	cameraElevation: number,
	floorColor: string,
	grid: boolean,
	referenceProps: boolean,
	modelSize: number,
	modelRotation: number,
	settleTime: number,
}

Settings.defaults = {
	autoCapture = true,
	fieldOfView = 50,
	cameraDistance = 1,
	cameraYaw = 0,
	cameraElevation = 10,
	floorColor = "#5B5B5B",
	grid = true,
	referenceProps = true,
	modelSize = 16,
	modelRotation = 0,
	settleTime = 1.5,
} :: Options

const ranges = {
	fieldOfView = { 25, 90 },
	cameraDistance = { 0.5, 3 },
	cameraYaw = { -180, 180 },
	cameraElevation = { 0, 75 },
	modelSize = { 4, 40 },
	modelRotation = { -180, 180 },
	settleTime = { 0.5, 5 },
}

function Settings.clean(saved: any): Options
	const result = table.clone(Settings.defaults) :: any
	if type(saved) ~= "table" then
		return result
	end
	for name, default in Settings.defaults do
		const value = saved[name]
		if type(default) == "boolean" and type(value) == "boolean" then
			result[name] = value
		elseif type(default) == "number" and type(value) == "number" and value == value then
			const range = ranges[name]
			result[name] = math.clamp(value, range[1], range[2])
		elseif name == "floorColor" and type(value) == "string" and string.match(value, "^#%x%x%x%x%x%x$") then
			result[name] = string.upper(value)
		end
	end
	return result
end

-- Auto-capture only changes when a picture is requested, not what it looks like.
function Settings.key(options: Options, modelId: string?): string
	return table.concat({
		"stage-v2", modelId or "default", tostring(options.fieldOfView),
		tostring(options.cameraDistance), tostring(options.cameraYaw), tostring(options.cameraElevation), options.floorColor,
		tostring(options.grid), tostring(options.referenceProps), tostring(options.modelSize),
		tostring(options.modelRotation), tostring(options.settleTime),
	}, ":")
end

return Settings
