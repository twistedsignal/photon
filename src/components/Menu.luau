-- selene: allow(mixed_table)
-- a small popup list of actions, opened from a button such as a card's "..." menu.
const vide = require("../vide")
const Theme = require("./Theme")
const Overlay = require("../Overlay")

const new = vide.create

export type Item = {
	text: string,
	danger: boolean?,
	activated: () -> (),
}

const WIDTH = 150

const function open(button: GuiObject, items: { Item })
	const layer = Overlay.layer()
	const height = #items * Theme.DROPDOWN_ROW_HEIGHT
	Overlay.mount(function(close)
		const anchor = Overlay.anchor(button, close)
		const function position(): UDim2
			const at = anchor()
			const left = math.clamp(at.X + button.AbsoluteSize.X - WIDTH, 4, math.max(4, layer.AbsoluteSize.X - WIDTH - 4))
			local top = at.Y + button.AbsoluteSize.Y + 2
			if top + height > layer.AbsoluteSize.Y - 4 then
				top = at.Y - height - 2
			end
			return UDim2.fromOffset(left, top)
		end
		const rows = {}
		for index, item in items do
			const hovered = vide.source(false)
			table.insert(rows, new("TextButton")({
				Name = item.text,
				Size = UDim2.new(1, 0, 0, Theme.DROPDOWN_ROW_HEIGHT),
				LayoutOrder = index,
				BackgroundColor3 = function()
					return if hovered() then Theme.hover(Theme.SECTION) else Theme.SECTION
				end,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Text = `  {item.text}`,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = if item.danger then Theme.RED else Theme.TEXT,
				Font = Enum.Font.SourceSans,
				TextSize = 15,
				ZIndex = Theme.OVERLAY_Z + 1,
				MouseEnter = function()
					hovered(true)
				end,
				MouseLeave = function()
					hovered(false)
				end,
				Activated = function()
					close()
					item.activated()
				end,
			}))
		end
		return new("Frame")({
			Name = "Menu",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = Theme.OVERLAY_Z,

			Overlay.dismissLayer(close),
			new("Frame")({
				Name = "List",
				Position = position,
				Size = UDim2.fromOffset(WIDTH, height),
				BackgroundColor3 = Theme.SECTION,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				ZIndex = Theme.OVERLAY_Z + 1,

				Theme.stroke(Theme.BORDER),
				new("UICorner")({ CornerRadius = UDim.new(0, 4) }),
				new("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }),
				rows,
			}),
		}) :: Frame
	end)
end

return {
	open = open,
}
