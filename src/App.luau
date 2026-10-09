-- selene: allow(mixed_table)
const vide = require("./vide")
const Theme = require("./components/Theme")
const Icons = require("./Icons")
const TabButton = require("./components/TabButton")
const Button = require("./components/Button")
const IconButton = require("./components/IconButton")
const PresetDialogs = require("./components/PresetDialogs")
const Overlay = require("./Overlay")
const Store = require("./Store")
const LibraryPage = require("./pages/LibraryPage")
const SettingsPage = require("./pages/SettingsPage")
const VERSION = require("./Version")

const new = vide.create
const source = vide.source
const effect = vide.effect
const cleanup = vide.cleanup

const HEADER_HEIGHT = 56
const FOOTER_HEIGHT = 46

export type Props = {
	plugin: Plugin,
	-- dev builds hand their store out for testing.
	onStore: ((Store.Store) -> ())?,
}

const function App(props: Props): Frame
	const store = Store.create(props.plugin)
	cleanup(store.destroy)
	if props.onStore then
		props.onStore(store)
	end

	const page = source("library" :: "library" | "settings")

	-- the overlay must exist before any component that places hover text or popups in it.
	const overlay = new("Frame")({
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = Theme.OVERLAY_Z,
	}) :: Frame
	Overlay.setLayer(overlay)
	cleanup(function()
		Overlay.setLayer(nil)
	end)

	const header = new("Frame")({
		Name = "Header",
		Position = UDim2.fromOffset(0, 3),
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		BackgroundColor3 = Theme.DARKER,
		BorderSizePixel = 0,

		new("ImageLabel")({
			Name = "Logo",
			Position = UDim2.new(0, 12, 0.5, -12),
			Size = UDim2.fromOffset(18, 24),
			BackgroundTransparency = 1,
			Image = Icons.plugin,
			ScaleType = Enum.ScaleType.Fit,
		}),
		new("TextLabel")({
			Name = "Title",
			Position = UDim2.fromOffset(38, 0),
			Size = UDim2.new(0.5, -40, 1, 0),
			BackgroundTransparency = 1,
			Text = "Photon",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Theme.TEXT,
			Font = Enum.Font.SourceSansBold,
			TextSize = 18,
		}),
	}) :: Frame

	const tabs = new("Frame")({
		Name = "Tabs",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(72, 32),
		BackgroundTransparency = 1,
		Parent = header,

		new("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	const libraryTab = TabButton(tabs, "Library", Icons.library, function()
		page("library")
	end)
	const settingsTab = TabButton(tabs, "Settings", Icons.settings, function()
		page("settings")
	end)
	settingsTab.button.LayoutOrder = 1
	effect(function()
		libraryTab.active(page() == "library")
		settingsTab.active(page() == "settings")
	end)

	const hasSelection = function(): boolean
		return store.selected() ~= nil
	end
	const function withSelected(action: (Store.Preset) -> ()): () -> ()
		return function()
			const preset = store.selected()
			if preset then
				action(preset)
			end
		end
	end

	const footer = new("Frame")({
		Name = "Footer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT),
		BackgroundColor3 = Theme.DARKER,
		BorderSizePixel = 0,

		new("Frame")({
			Name = "PresetActions",
			Position = UDim2.fromOffset(10, 8),
			Size = UDim2.new(1, -130, 0, 30),
			BackgroundTransparency = 1,

			new("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			Button({
				text = "Load",
				icon = Icons.load,
				variant = "accent",
				layoutOrder = 1,
				size = UDim2.fromOffset(92, 30),
				enabled = hasSelection,
				activated = withSelected(store.loadPreset),
			}),
			Button({
				text = "Insert",
				icon = Icons.insert,
				layoutOrder = 2,
				size = UDim2.fromOffset(96, 30),
				enabled = hasSelection,
				activated = withSelected(function(preset)
					PresetDialogs.insert(store, preset)
				end),
			}),
		}),
		new("Frame")({
			Name = "LibraryActions",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 8),
			Size = UDim2.fromOffset(102, 30),
			BackgroundTransparency = 1,

			new("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			IconButton({
				icon = Icons.save,
				label = "Save current lighting",
				layoutOrder = 1,
				activated = function()
					PresetDialogs.save(store)
				end,
			}),
			IconButton({
				icon = Icons.import,
				label = "Import a code",
				layoutOrder = 2,
				activated = function()
					PresetDialogs.import(store)
				end,
			}),
			IconButton({
				icon = Icons.export,
				label = "Export as a code",
				layoutOrder = 3,
				enabled = hasSelection,
				activated = withSelected(function(preset)
					PresetDialogs.export(store, preset)
				end),
			}),
		}),
	}) :: Frame

	const notice = new("TextLabel")({
		Name = "Notice",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(FOOTER_HEIGHT + 8)),
		Size = UDim2.new(1, -40, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = function()
			const current = store.notice()
			if current and current.kind == "error" then
				return Color3.fromRGB(70, 28, 30)
			elseif current and current.kind == "success" then
				return Color3.fromRGB(26, 56, 38)
			end
			return Theme.SECTION
		end,
		BorderSizePixel = 0,
		Visible = function()
			return store.notice() ~= nil
		end,
		Text = function()
			const current = store.notice()
			return if current then current.text else ""
		end,
		TextWrapped = true,
		TextColor3 = Theme.TEXT,
		Font = Enum.Font.SourceSans,
		TextSize = 15,
		ZIndex = Theme.OVERLAY_Z - 1,

		Theme.stroke(Theme.BORDER),
		new("UICorner")({ CornerRadius = UDim.new(0, 6) }),
		new("UIPadding")({
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		}),
	})

	return new("Frame")({
		Name = "Photon",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.DARK,
		BorderSizePixel = 0,

		new("Frame")({
			Name = "AccentBar",
			Size = UDim2.new(1, 0, 0, 3),
			BackgroundColor3 = Theme.BLUE,
			BorderSizePixel = 0,
		}),
		header,
		new("Frame")({
			Name = "Content",
			Position = UDim2.fromOffset(0, HEADER_HEIGHT + 3 + 10),
			Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + 3 + 10 + FOOTER_HEIGHT)),
			BackgroundTransparency = 1,

			vide.switch(page)({
				library = function()
					return LibraryPage({ store = store })
				end,
				settings = function()
					return SettingsPage({ store = store, pluginVersion = VERSION })
				end,
			}),
		}),
		footer,
		notice,
		overlay,
	}) :: Frame
end

return App
