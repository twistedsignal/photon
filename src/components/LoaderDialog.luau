-- selene: allow(mixed_table)
const vide = require("../vide")
const Theme = require("./Theme")
const Modal = require("./Modal")
const ToggleSetting = require("./ToggleSetting")
const DropdownSetting = require("./DropdownSetting")
const TextBoxSetting = require("./TextBoxSetting")
const ParentPicker = require("./ParentPicker")
const Overlay = require("../Overlay")
const Builder = require("../LoaderBuilder")
const Store = require("../Store")

const new = vide.create
const LoaderDialog = {}

function LoaderDialog.open(store: Store.Store): () -> ()
	const options = vide.source(Builder.clean(store.loaderOptions()))
	const parent = vide.source(store.insertionParent())
	const name = vide.source("PhotonLoader")
	const problem = vide.source("")
	const function change(key: string, value: any)
		const next = table.clone(options()) :: any
		next[key] = value
		options(Builder.clean(next))
		problem("")
	end
	const function section(text: string, order: number): TextLabel
		return new("TextLabel")({
			Name = text, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1, Text = `  {text}`, TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Theme.SUBTLE, Font = Enum.Font.SourceSansBold, TextSize = 14,
		}) :: TextLabel
	end
	return Modal.open({
		title = "Insert loader", width = 440,
		height = math.min(650, math.max(300, Overlay.layer().AbsoluteSize.Y - 24)),
		buttons = {
			{ text = "Cancel", activated = function(close) close() end },
			{ text = "Insert", variant = "accent",
				enabled = function() return Builder.problem(options()) == nil and string.match(name(), "%S") ~= nil end,
				activated = function(close)
					const ok, message = store.insertLoader(options(), parent(), name())
					if ok then
						close()
					else
						problem(message or "Couldn't insert the loader.")
					end
				end,
			},
		},
		body = function()
			const rows = {}
			for index, feature in Builder.features do
				table.insert(rows, ToggleSetting({
					name = "." .. feature.id, index = index + 1, description = feature.description,
					value = function() return options().features[feature.id] == true end,
					onChange = function(value)
						const features = table.clone(options().features)
						features[feature.id] = value
						change("features", features)
					end,
				}))
			end
			return new("ScrollingFrame")({
				Name = "LoaderOptions", BackgroundTransparency = 1, BorderSizePixel = 0,
				ScrollBarThickness = 5, ScrollBarImageColor3 = Theme.BORDER,
				CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
				VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
				new("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }),
				new("UIPadding")({ PaddingRight = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6) }),
				section("Functions", 1), rows,
				section("Code style", 20),
				DropdownSetting({
					name = "Function casing", index = 21,
					text = function() return options().casing end,
					options = function() return {
						{ label = "PascalCase", value = "PascalCase" },
						{ label = "camelCase", value = "camelCase" },
						{ label = "snake_case", value = "snake_case" },
						{ label = "UPPER_CASE", value = "UPPER_CASE" },
					} end,
					onSelect = function(value) change("casing", value) end,
				}),
				DropdownSetting({
					name = "Bindings", index = 22,
					description = "const keeps mutable bindings local. local uses ordinary declarations throughout.",
					text = function() return options().binding end,
					options = function() return {
						{ label = "const", value = "const" }, { label = "local", value = "local" },
					} end,
					onSelect = function(value) change("binding", value) end,
				}),
				ToggleSetting({ name = "Types", index = 23,
					value = function() return options().types end,
					onChange = function(value) change("types", value) end,
				}),
				section("Destination", 30),
				TextBoxSetting({ name = "Module name", index = 31, value = name, onCommit = name }),
				ParentPicker.rows(parent, problem, 32),
				new("TextLabel")({
					Name = "Problem", LayoutOrder = 40, Size = UDim2.new(1, 0, 0, 38),
					BackgroundTransparency = 1, Text = function() return problem() ~= "" and problem() or Builder.problem(options()) or "" end,
					TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = Theme.RED, Font = Enum.Font.SourceSans, TextSize = 14,
				}),
			}) :: ScrollingFrame
		end,
	})
end

return LoaderDialog
