-- selene: allow(mixed_table)
-- a square button with an icon and a hover label.
const vide = require("../vide")
const Theme = require("./Theme")
const HoverDescription = require("./HoverDescription")
const Overlay = require("../Overlay")

const new = vide.create

export type Props = {
	icon: string,
	label: string,
	activated: () -> (),
	variant: ("default" | "accent" | "ghost")?,
	size: number?,
	enabled: (() -> boolean)?,
	layoutOrder: number?,
	position: UDim2?,
	anchorPoint: Vector2?,
}

const COLORS = {
	default = { background = Theme.BUTTON, border = Theme.BORDER },
	accent = { background = Theme.BLUE, border = Theme.BLUE_DARK },
	ghost = { background = Theme.SECTION, border = Theme.BORDER },
}

const function IconButton(props: Props): ImageButton
	const colors = COLORS[props.variant or "default"]
	const size = props.size or 30
	const hovered = vide.source(false)
	const enabled = props.enabled or function()
		return true
	end
	const button = new("ImageButton")({
		Name = props.label,
		Size = UDim2.fromOffset(size, size),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder or 0,
		BackgroundColor3 = function()
			return if hovered() and enabled() then Theme.hover(colors.background) else colors.background
		end,
		BackgroundTransparency = function()
			return if enabled() then 0 else 0.45
		end,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Image = "",
		MouseEnter = function()
			hovered(true)
		end,
		MouseLeave = function()
			hovered(false)
		end,
		Activated = function()
			if enabled() then
				props.activated()
			end
		end,

		Theme.stroke(colors.border),
		new("UICorner")({ CornerRadius = UDim.new(0, 4) }),
		new("ImageLabel")({
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(math.floor(size * 0.55), math.floor(size * 0.55)),
			BackgroundTransparency = 1,
			Image = props.icon,
			ImageColor3 = Theme.TEXT,
			ImageTransparency = function()
				return if enabled() then 0 else 0.5
			end,
		}),
	}) :: ImageButton
	HoverDescription({ root = Overlay.layer(), target = button, text = props.label, width = #props.label * 8 + 32 })
	return button
end

return IconButton
