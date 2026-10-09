-- selene: allow(mixed_table)
-- the loader in the current place, saved previews, and about.
const vide = require("../vide")
const Theme = require("../components/Theme")
const Button = require("../components/Button")
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

const function paragraph(text: string, order: number): TextLabel
	return new("TextLabel")({
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Text = text,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.MUTED,
		Font = Enum.Font.SourceSans,
		TextSize = 15,

		new("UIPadding")({
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		}),
	}) :: TextLabel
end

-- a row of buttons side by side.
const function actions(order: number, buttons: { { text: string, activated: () -> (), variant: any? } }): Frame
	const children = {}
	for index, button in buttons do
		table.insert(children, Button({
			text = button.text,
			variant = button.variant,
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

		heading("This place", nextOrder()),
		paragraph(
			"Insert adds a preset to ReplicatedStorage.Photon.Presets along with the Loader module, so scripts can "
				.. 'load it with require(ReplicatedStorage.Photon.Loader).load("Name", TweenInfo.new(2)).',
			nextOrder()
		),
		actions(nextOrder(), {
			{ text = "Add or update the loader", activated = store.updateLoader },
		}),

		heading("Previews", nextOrder()),
		paragraph(
			"Previews are taken by Roblox itself on a test baseplate far from your map, then everything is put "
				.. "back. They're saved, so each preset is only previewed once. Clear them to take them again.",
			nextOrder()
		),
		actions(nextOrder(), {
			{ text = "Clear saved previews", activated = function()
				store.clearPreviews()
				store.setNotice("Cleared the saved previews.", "info")
			end },
		}),

		heading("Library", nextOrder()),
		paragraph(
			"Your presets and folders are saved with your Studio settings, so they're there in every place you open.",
			nextOrder()
		),

		new("TextLabel")({
			Name = "About",
			Size = UDim2.new(1, 0, 0, 56),
			LayoutOrder = nextOrder(),
			BackgroundTransparency = 1,
			Text = `Photon v{props.pluginVersion} · MIT License · Twisted Signal\ngithub.com/twistedsignal/photon`,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Theme.SUBTLE,
			Font = Enum.Font.SourceSans,
			TextSize = 14,

			new("UIPadding")({ PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 12) }),
		}),
	}) :: ScrollingFrame
end

return SettingsPage
