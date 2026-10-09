-- selene: allow(mixed_table)
-- the large preview of the selected preset, taken with Roblox's own renderer.
const vide = require("../vide")
const Theme = require("./Theme")
const IconButton = require("./IconButton")
const Spinner = require("./Spinner")
const Icons = require("../Icons")
const Store = require("../Store")
const Automatic = require("../Preview/Automatic")

const new = vide.create

export type Props = {
	store: Store.Store,
	layoutOrder: number,
}

const function PreviewPanel(props: Props): Frame
	const store = props.store

	const busy = function(): boolean
		const preset = store.selected()
		return preset ~= nil and store.previewing()[preset.id] == true
	end
	const problem = function(): string?
		const preset = store.selected()
		return if preset then store.previewErrors()[preset.id] else nil
	end
	const entry = function()
		const preset = store.selected()
		return if preset then store.preview(preset) else nil
	end

	Automatic(store)

	const message = function(): string
		const preset = store.selected()
		if preset == nil then
			return "Pick a preset to preview it."
		elseif busy() then
			return if entry() then "" else "Taking preview…"
		elseif problem() then
			return problem() :: string
		end
		return if entry() == nil then "Click refresh to capture a preview." else ""
	end

	return new("Frame")({
		Name = "PreviewPanel",
		Size = UDim2.fromScale(1, 0),
		LayoutOrder = props.layoutOrder,
		BackgroundColor3 = Theme.DARKER,
		BorderSizePixel = 0,
		ClipsDescendants = true,

		new("UIAspectRatioConstraint")({ AspectRatio = 16 / 9, DominantAxis = Enum.DominantAxis.Width }),
		new("UICorner")({ CornerRadius = UDim.new(0, 6) }),
		Theme.stroke(Theme.BORDER),
		new("ImageLabel")({
			Name = "Preview",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ImageContent = function()
				const current = entry()
				return if current then Content.fromObject(current.large) else Content.none
			end,
			ImageTransparency = function()
				return if busy() then 0.4 else 0
			end,
			ScaleType = Enum.ScaleType.Crop,

			new("UICorner")({ CornerRadius = UDim.new(0, 6) }),
		}),
		new("TextLabel")({
			Name = "Message",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -40, 0, 60),
			BackgroundTransparency = 1,
			Text = message,
			TextWrapped = true,
			TextColor3 = function()
				return if problem() and not busy() then Theme.RED else Theme.MUTED
			end,
			Font = Enum.Font.SourceSans,
			TextSize = 16,
		}),
		new("TextLabel")({
			Name = "PresetName",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 8, 1, -8),
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			Visible = function()
				return store.selected() ~= nil
			end,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.4,
			Text = function()
				const preset = store.selected()
				if preset == nil then
					return ""
				end
				return if busy() then `      {preset.name}` else preset.name
			end,
			TextColor3 = Theme.TEXT,
			Font = Enum.Font.SourceSansSemibold,
			TextSize = 15,

			new("UICorner")({ CornerRadius = UDim.new(0, 4) }),
			new("UIPadding")({ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
			Spinner(busy),
		}),
		vide.show(function()
			return store.selected() ~= nil and not busy()
		end, function()
			return IconButton({
				icon = Icons.refresh,
				label = "Retake preview",
				variant = "ghost",
				size = 26,
				anchorPoint = Vector2.new(1, 0),
				position = UDim2.new(1, -8, 0, 8),
				activated = function()
					const preset = store.selected()
					if preset then
						store.requestPreview(preset, true)
					end
				end,
			})
		end),
	}) :: Frame
end

return PreviewPanel
