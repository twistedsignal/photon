-- selene: allow(mixed_table)
-- a preset in the library grid: its render, name and a "..." menu of actions.
const vide = require("../vide")
const Theme = require("./Theme")
const Menu = require("./Menu")
const Spinner = require("./Spinner")
const PresetDialogs = require("./PresetDialogs")
const Store = require("../Store")
const Schema = require("../Loader/Schema")

const new = vide.create

export type Props = {
	store: Store.Store,
	preset: Store.Preset,
	layoutOrder: () -> number,
}

const NAME_HEIGHT = 26

const function color(value: any, fallback: Color3): Color3
	return if type(value) == "table" then Color3.new(value[1], value[2], value[3]) else fallback
end

-- sky and ground colors from the preset, shown until there's a real render.
const function swatch(data: Schema.Data): (Color3, Color3)
	local sky = color(data.lighting.FogColor, Color3.fromRGB(150, 170, 200))
	for _, effect in data.effects do
		if effect.class == "Atmosphere" then
			sky = color(effect.props.Color, sky)
		end
	end
	const brightness = math.clamp((data.lighting.Brightness or 2) / 3, 0.15, 1)
	const top = color(data.lighting.ColorShift_Top, Color3.new())
	sky = sky:Lerp(top, 0.3 * math.max(top.R, top.G, top.B))
	const ground = color(data.lighting.OutdoorAmbient, Color3.fromRGB(70, 70, 70))
	return sky:Lerp(Color3.new(), 1 - brightness), ground:Lerp(Color3.new(), 0.4)
end

const function PresetCard(props: Props): TextButton
	const store = props.store
	const preset = props.preset
	const hovered = vide.source(false)
	const selected = function(): boolean
		return store.selectedId() == preset.id
	end
	const image = function(): Content
		const entry = store.preview(preset)
		return if entry then Content.fromObject(entry.card) else Content.none
	end
	const busy = function(): boolean
		return store.previewing()[preset.id] == true
	end
	const sky, ground = swatch(preset.data)

	const function openMenu(button: GuiObject)
		const items: { Menu.Item } = {
			{ text = "Load", activated = function()
				store.loadPreset(preset)
			end },
			{ text = "Insert", activated = function()
				PresetDialogs.insert(store, preset)
			end },
			{ text = "Export code", activated = function()
				PresetDialogs.export(store, preset)
			end },
		}
		table.insert(items, { text = "Retake preview", activated = function()
			store.requestPreview(preset, true)
		end })
		if not preset.builtin then
			table.insert(items, { text = "Move to folder", activated = function()
				const folders: { Menu.Item } = {
					{ text = "Unsorted", activated = function()
						store.moveToFolder(preset, nil)
					end },
				}
				for _, folder in store.folders() do
					table.insert(folders, { text = folder.name, activated = function()
						store.moveToFolder(preset, folder.id)
					end })
				end
				Menu.open(button, folders)
			end })
			table.insert(items, { text = "Update from Studio", activated = function()
				PresetDialogs.update(store, preset)
			end })
			table.insert(items, { text = "Rename", activated = function()
				PresetDialogs.rename(store, preset)
			end })
			table.insert(items, { text = "Delete", danger = true, activated = function()
				PresetDialogs.delete(store, preset)
			end })
		end
		Menu.open(button, items)
	end

	return new("TextButton")({
		Name = preset.name,
		LayoutOrder = props.layoutOrder,
		BackgroundColor3 = function()
			return if hovered() then Theme.hover(Theme.SECTION) else Theme.SECTION
		end,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ClipsDescendants = true,
		MouseEnter = function()
			hovered(true)
		end,
		MouseLeave = function()
			hovered(false)
		end,
		Activated = function()
			store.selectedId(preset.id)
		end,

		new("UICorner")({ CornerRadius = UDim.new(0, 6) }),
		new("UIStroke")({
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = function()
				return if selected() then Theme.BLUE else Theme.BORDER
			end,
			Thickness = function()
				return if selected() then 2 else 1
			end,
		}),
		new("Frame")({
			Name = "Swatch",
			Size = UDim2.new(1, 0, 1, -NAME_HEIGHT),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,

			new("UIGradient")({
				Rotation = 90,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, sky),
					ColorSequenceKeypoint.new(0.62, sky:Lerp(ground, 0.5)),
					ColorSequenceKeypoint.new(0.64, ground),
					ColorSequenceKeypoint.new(1, ground),
				}),
			}),
			new("UICorner")({ CornerRadius = UDim.new(0, 6) }),
		}),
		new("ImageLabel")({
			Name = "Render",
			Size = UDim2.new(1, 0, 1, -NAME_HEIGHT),
			BackgroundTransparency = 1,
			ImageContent = image,
			ScaleType = Enum.ScaleType.Crop,

			new("UICorner")({ CornerRadius = UDim.new(0, 6) }),
		}),
		new("Frame")({
			Name = "Previewing",
			Size = UDim2.new(1, 0, 1, -NAME_HEIGHT),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.5,
			Visible = busy,

			new("UICorner")({ CornerRadius = UDim.new(0, 6) }),
			new("Frame")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(32, 16),
				BackgroundTransparency = 1,
				Spinner(busy),
			}),
		}),
		new("TextButton")({
			Name = "More",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(26, 18),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = function()
				return if hovered() or selected() then 0.35 else 1
			end,
			TextTransparency = function()
				return if hovered() or selected() then 0 else 1
			end,
			AutoButtonColor = true,
			Text = "•••",
			TextColor3 = Theme.TEXT,
			Font = Enum.Font.SourceSansBold,
			TextSize = 12,
			vide.action(function(instance)
				vide.cleanup((instance :: TextButton).Activated:Connect(function()
					store.selectedId(preset.id)
					openMenu(instance :: GuiObject)
				end))
			end),

			new("UICorner")({ CornerRadius = UDim.new(0, 4) }),
		}),
		new("TextLabel")({
			Name = "PresetName",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 8, 1, 0),
			Size = UDim2.new(1, -16, 0, NAME_HEIGHT),
			BackgroundTransparency = 1,
			Text = preset.name,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = function()
				return if selected() then Theme.TEXT else Theme.MUTED
			end,
			Font = Enum.Font.SourceSansSemibold,
			TextSize = 15,
		}),
	}) :: TextButton
end

return PresetCard
