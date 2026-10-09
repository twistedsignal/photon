-- selene: allow(mixed_table)
-- Compact preview controls, saved across places.
const vide = require("../vide")
const Theme = require("../components/Theme")
const Button = require("../components/Button")
const SliderSetting = require("../components/SliderSetting")
const ToggleSetting = require("../components/ToggleSetting")
const ColorSetting = require("../components/ColorSetting")
const BaseSetting = require("../components/BaseSetting")
const Store = require("../Store")

const new = vide.create

export type Props = {
	store: Store.Store,
	pluginVersion: string,
}

const function heading(text: string, order: number): TextLabel
	return new("TextLabel")({
		Name = text,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Text = `  {string.upper(text)}`,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		TextColor3 = Theme.SUBTLE,
		Font = Enum.Font.SourceSansBold,
		TextSize = 13,

		new("UIPadding")({ PaddingBottom = UDim.new(0, 4) }),
	}) :: TextLabel
end

-- a row of buttons side by side.
const function actions(order: number, buttons: { { text: string | () -> string, activated: () -> (), enabled: (() -> boolean)? } }): Frame
	const children = {}
	for index, button in buttons do
		table.insert(children, Button({
			text = button.text,
			enabled = button.enabled,
			layoutOrder = index,
			size = UDim2.new(1 / #buttons, -6, 1, 0),
			activated = button.activated,
		}))
	end
	return new("Frame")({
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = order,
		BackgroundTransparency = 1,

		new("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		new("UIPadding")({ PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 2) }),
		children,
	}) :: Frame
end

const function SettingsPage(props: Props): ScrollingFrame
	const store = props.store

	local order = 0
	const function nextOrder(): number
		order += 1
		return order
	end

	const function toggle(name: string, key: string, description: string?): Frame
		return ToggleSetting({
			name = name, index = nextOrder(), description = description,
			value = function() return (store.previewSettings() :: any)[key] end,
			onChange = function(value) store.setPreviewSetting(key, value) end,
		})
	end
	const function slider(name: string, key: string, min: number, max: number, step: number, description: string?): Frame
		return SliderSetting({
			name = name, index = nextOrder(), min = min, max = max, step = step,
			description = description,
			value = function() return (store.previewSettings() :: any)[key] end,
			onChange = function(value) store.setPreviewSetting(key, value) end,
		})
	end
	const modelRow = BaseSetting({ name = "Saved model", index = nextOrder(), labelWidth = 0.36 })
	new("TextLabel")({
		Name = "ModelName", Parent = modelRow,
		Position = UDim2.fromScale(0.36, 0), Size = UDim2.fromScale(0.64, 1),
		BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = function() return store.previewModelName() or "Default scene" end,
		TextColor3 = Theme.TEXT, Font = Enum.Font.SourceSans, TextSize = 15,
		new("UIPadding")({ PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8) }),
	})

	return new("ScrollingFrame")({
		Name = "SettingsPage",
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.BORDER,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		new("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding")({ PaddingBottom = UDim.new(0, 12) }),

		heading("Preview model", 0),
		modelRow,
		actions(nextOrder(), {
			{
				text = function() return if store.modelSaving() then "Saving…" else "Use selection" end,
				enabled = function() return store.loaded() and not store.modelSaving() and store.previewSelection() ~= nil end,
				activated = store.setPreviewModel,
			},
			{
				text = "Use default",
				enabled = function() return store.loaded() and not store.modelSaving() and store.previewModelName() ~= nil end,
				activated = store.clearPreviewModel,
			},
		}),
		new("TextLabel")({
			Name = "SelectionHint", LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
			Text = function()
				const selected = store.previewSelection()
				return if selected then `  Selected: {selected}` else "  Select in Explorer. Saved across places."
			end,
			TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = Theme.SUBTLE,
			Font = Enum.Font.SourceSans, TextSize = 13,
		}),
		slider("Model size", "modelSize", 4, 40, 1, "Longest side in studs. Applies to your saved model."),
		slider("Model rotation", "modelRotation", -180, 180, 5, "Turns your saved model in degrees."),

		heading("Camera", nextOrder()),
		slider("Distance", "cameraDistance", 0.5, 3, 0.1, "Multiplier of the fitted camera distance. Lower values zoom in."),
		slider("Field of view", "fieldOfView", 25, 90, 1),
		slider("Orbit angle", "cameraYaw", -180, 180, 5),
		slider("Elevation", "cameraElevation", 0, 75, 1),

		heading("Baseplate", nextOrder()),
		ColorSetting({
			name = "Floor color", index = nextOrder(),
			value = function() return store.previewSettings().floorColor end,
			onChange = function(value) store.setPreviewSetting("floorColor", value) end,
		}),
		toggle("Grid", "grid"),
		toggle("Reference props", "referenceProps", "Material spheres and shadow props alongside the preview model."),

		heading("Capture", nextOrder()),
		toggle("Automatic previews", "autoCapture", "Capture missing previews when you select, save or import a preset."),
		slider("Settle time", "settleTime", 0.5, 5, 0.5, "Seconds to wait before taking screenshots. Increase if lighting loads slowly."),
		actions(nextOrder(), {
			{ text = "Clear previews", activated = function()
				store.clearPreviews()
				store.setNotice("Saved previews cleared.", "info")
			end },
			{ text = "Reset settings", activated = store.resetPreviewSettings },
		}),

		new("TextLabel")({
			Name = "About", Size = UDim2.new(1, 0, 0, 36), LayoutOrder = nextOrder(),
			BackgroundTransparency = 1,
			Text = `  Photon v{props.pluginVersion} · Twisted Signal · MIT`,
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.SUBTLE,
			Font = Enum.Font.SourceSans, TextSize = 13,
		}),
	}) :: ScrollingFrame
end

return SettingsPage
