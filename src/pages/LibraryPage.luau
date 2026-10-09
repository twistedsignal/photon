-- selene: allow(mixed_table)
-- the preview on top, then search and the presets, grouped in collapsible folders.
const vide = require("../vide")
const Theme = require("../components/Theme")
const IconButton = require("../components/IconButton")
const Menu = require("../components/Menu")
const PresetCard = require("../components/PresetCard")
const PresetDialogs = require("../components/PresetDialogs")
const PreviewPanel = require("../components/PreviewPanel")
const Icons = require("../Icons")
const Store = require("../Store")

const new = vide.create

const MIN_CARD_WIDTH = 140
const GAP = 8
const NAME_HEIGHT = 26
const HEADER_HEIGHT = 28

export type Props = {
	store: Store.Store,
}

-- one folder: a header that collapses it, and its presets in a grid.
const function FolderSection(store: Store.Store, id: string, order: () -> number, width: () -> number): Frame
	const section = function(): Store.Section?
		for _, entry in store.sections() do
			if entry.id == id then
				return entry
			end
		end
		return nil
	end
	const presets = function(): { Store.Preset }
		const current = section()
		return if current then current.presets else {}
	end
	const collapsed = function(): boolean
		return store.isCollapsed(id)
	end
	const columns = function(): number
		return math.max(1, math.floor((width() + GAP) / (MIN_CARD_WIDTH + GAP)))
	end
	const cellSize = function(): UDim2
		const count = columns()
		const cell = math.floor((width() - GAP * (count - 1)) / count)
		return UDim2.fromOffset(math.max(cell, 1), math.floor(cell * 9 / 16) + NAME_HEIGHT)
	end
	const empty = function(): string
		if #presets() > 0 then
			return ""
		end
		return if id == Store.UNSORTED_FOLDER
			then "Presets you save or import land here."
			else "Empty. Use a preset's ••• menu to move it here."
	end

	const function openMenu(button: GuiObject)
		const current = section()
		if current == nil or not current.custom then
			return
		end
		const folder = { id = current.id, name = current.name }
		Menu.open(button, {
			{ text = "Rename folder", activated = function()
				PresetDialogs.renameFolder(store, folder)
			end },
			{ text = "Delete folder", danger = true, activated = function()
				PresetDialogs.deleteFolder(store, folder)
			end },
		})
	end

	return new("Frame")({
		Name = id,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		BackgroundTransparency = 1,

		new("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
		new("TextButton")({
			Name = "Header",
			Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
			LayoutOrder = 1,
			BackgroundColor3 = Theme.SECTION,
			BorderSizePixel = 0,
			AutoButtonColor = true,
			Text = "",
			Activated = function()
				store.toggleFolder(id)
			end,

			new("UICorner")({ CornerRadius = UDim.new(0, 4) }),
			Theme.stroke(Theme.BORDER),
			new("ImageLabel")({
				Name = "Arrow",
				Size = UDim2.fromOffset(12, 12),
				Position = UDim2.new(0, 8, 0.5, -6),
				BackgroundTransparency = 1,
				Image = Theme.ARROW_IMAGE,
				ImageColor3 = Theme.TEXT,
				Rotation = function()
					return if collapsed() then -90 else 0
				end,
			}),
			new("TextLabel")({
				Name = "Title",
				Position = UDim2.fromOffset(28, 0),
				Size = UDim2.new(1, -70, 1, 0),
				BackgroundTransparency = 1,
				Text = function()
					const current = section()
					if current == nil then
						return ""
					end
					return `{current.name}  <font color="#{Theme.SUBTLE:ToHex()}">{#current.presets}</font>`
				end,
				RichText = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = Theme.TEXT,
				Font = Enum.Font.SourceSansSemibold,
				TextSize = 15,
			}),
			new("TextButton")({
				Name = "More",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -6, 0.5, 0),
				Size = UDim2.fromOffset(26, 20),
				Visible = function()
					const current = section()
					return current ~= nil and current.custom
				end,
				BackgroundTransparency = 1,
				Text = "•••",
				TextColor3 = Theme.MUTED,
				Font = Enum.Font.SourceSansBold,
				TextSize = 12,
				vide.action(function(instance)
					vide.cleanup((instance :: TextButton).Activated:Connect(function()
						openMenu(instance :: GuiObject)
					end))
				end),
			}),
		}),
		new("TextLabel")({
			Name = "Empty",
			Size = UDim2.new(1, 0, 0, 22),
			LayoutOrder = 2,
			Visible = function()
				return not collapsed() and empty() ~= ""
			end,
			BackgroundTransparency = 1,
			Text = empty,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Theme.SUBTLE,
			Font = Enum.Font.SourceSans,
			TextSize = 14,

			new("UIPadding")({ PaddingLeft = UDim.new(0, 8) }),
		}),
		new("Frame")({
			Name = "Grid",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 3,
			Visible = function()
				return not collapsed() and #presets() > 0
			end,
			BackgroundTransparency = 1,

			new("UIGridLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				CellPadding = UDim2.fromOffset(GAP, GAP),
				CellSize = cellSize,
			}),
			vide.values(presets, function(preset: Store.Preset, index: () -> number)
				return PresetCard({ store = store, preset = preset, layoutOrder = index })
			end),
		}),
	}) :: Frame
end

const function LibraryPage(props: Props): ScrollingFrame
	const store = props.store
	const width = vide.source(0)
	const sectionIds = function(): { string }
		const ids = {}
		for _, section in store.sections() do
			table.insert(ids, section.id)
		end
		return ids
	end
	const noMatches = function(): boolean
		return store.query() ~= "" and #store.sections() == 0
	end

	return new("ScrollingFrame")({
		Name = "LibraryPage",
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.BORDER,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		vide.changed("AbsoluteSize", function(size: Vector2)
			-- the grid is the page minus the scrollbar and padding.
			const next = size.X - 10
			if math.abs(next - width()) >= 1 then
				width(next)
			end
		end),

		new("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
		new("UIPadding")({ PaddingBottom = UDim.new(0, 10), PaddingRight = UDim.new(0, 2) }),

		PreviewPanel({ store = store, layoutOrder = 1 }),

		new("Frame")({
			Name = "Search",
			Size = UDim2.new(1, 0, 0, 28),
			LayoutOrder = 2,
			BackgroundTransparency = 1,

			new("TextBox")({
				Name = "Query",
				Size = UDim2.new(1, -36, 1, 0),
				BackgroundColor3 = Theme.INPUT,
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				Text = store.query(),
				PlaceholderText = "Search presets",
				PlaceholderColor3 = Theme.SUBTLE,
				TextColor3 = Theme.TEXT,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Enum.Font.SourceSans,
				TextSize = 15,
				vide.changed("Text", store.query),

				Theme.stroke(Theme.BORDER),
				new("UICorner")({ CornerRadius = UDim.new(0, 4) }),
				new("UIPadding")({ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
			}),
			IconButton({
				icon = Icons.newFolder,
				label = "New folder",
				size = 28,
				anchorPoint = Vector2.new(1, 0),
				position = UDim2.fromScale(1, 0),
				activated = function()
					PresetDialogs.newFolder(store)
				end,
			}),
		}),

		new("TextLabel")({
			Name = "NoMatches",
			Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = 3,
			Visible = noMatches,
			BackgroundTransparency = 1,
			Text = function()
				return `No presets match "{store.query()}".`
			end,
			TextColor3 = Theme.SUBTLE,
			Font = Enum.Font.SourceSans,
			TextSize = 15,
		}),

		new("Frame")({
			Name = "Folders",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 4,
			BackgroundTransparency = 1,

			new("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
			vide.values(sectionIds, function(id: string, index: () -> number)
				return FolderSection(store, id, index, width)
			end),
		}),
	}) :: ScrollingFrame
end

return LibraryPage
