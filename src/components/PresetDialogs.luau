-- selene: allow(mixed_table)
-- the save, rename, update, delete, insert, export and import dialogs.
const vide = require("../vide")
const Theme = require("./Theme")
const Modal = require("./Modal")
const CodeBox = require("./CodeBox")
const Dropdown = require("./Dropdown")
const Store = require("../Store")

const new = vide.create
const source = vide.source

type Preset = Store.Preset

const PresetDialogs = {}

const function label(text: string | () -> string, y: number, height: number, color: Color3?): TextLabel
	return new("TextLabel")({
		Size = UDim2.new(1, 0, 0, height),
		Position = UDim2.fromOffset(0, y),
		BackgroundTransparency = 1,
		Text = text,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = color or Theme.TEXT,
		Font = Enum.Font.SourceSans,
		TextSize = 15,
		ZIndex = Theme.OVERLAY_Z + 1,
	}) :: TextLabel
end

const function textBox(value: (string?) -> string, placeholder: string, y: number, onSubmit: () -> ()): TextBox
	const box = new("TextBox")({
		Size = UDim2.new(1, 0, 0, 32),
		Position = UDim2.fromOffset(0, y),
		BackgroundColor3 = Theme.INPUT,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Text = value(),
		PlaceholderText = placeholder,
		PlaceholderColor3 = Theme.SUBTLE,
		TextColor3 = Theme.TEXT,
		Font = Enum.Font.SourceSans,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = Theme.OVERLAY_Z + 1,
		vide.changed("Text", value),
		FocusLost = function(enterPressed: boolean)
			if enterPressed then
				onSubmit()
			end
		end,
		Theme.stroke(Theme.BORDER),
		new("UIPadding")({ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	}) :: TextBox
	task.defer(function()
		if box.Parent then
			box:CaptureFocus()
		end
	end)
	return box
end

type NameOptions = {
	title: string,
	description: string,
	initial: string,
	action: string,
	placeholder: string,
	-- shows a folder picker, starting on this folder (nil is Unsorted).
	store: Store.Store?,
	folder: string?,
	submit: (name: string, folder: string?) -> (boolean, string?),
}

-- the folder picker's choices: Unsorted, then your folders by name.
const function folderOptions(store: Store.Store): { Dropdown.Option }
	const list = { { label = "Unsorted", value = Store.UNSORTED_FOLDER } }
	const folders = table.clone(store.folders())
	table.sort(folders, function(a, b)
		return string.lower(a.name) < string.lower(b.name)
	end)
	for _, folder in folders do
		table.insert(list, { label = folder.name, value = folder.id })
	end
	return list
end

-- asks for a name, then calls submit. submit returns false and a message to keep the dialog open.
const function nameDialog(options: NameOptions)
	const name = source(options.initial)
	const folder = source(options.folder or Store.UNSORTED_FOLDER)
	const problem = source("")
	const picker = options.store
	local closeDialog: (() -> ())? = nil
	const function confirm()
		const chosen = folder()
		const ok, message = options.submit(name(), if chosen == Store.UNSORTED_FOLDER then nil else chosen)
		if ok then
			if closeDialog then
				closeDialog()
			end
		else
			problem(message or "")
		end
	end
	const offset = if picker then 36 else 0
	Modal.open({
		title = options.title,
		height = 200 + offset,
		buttons = {
			{ text = "Cancel", activated = function(close)
				close()
			end },
			{ text = options.action, variant = "accent", activated = confirm },
		},
		body = function(close)
			closeDialog = close
			return new("Frame")({
				BackgroundTransparency = 1,
				label(options.description, 0, 22, Theme.MUTED),
				textBox(name, options.placeholder, 26, confirm),
				if picker
					then Dropdown({
						text = function()
							for _, option in folderOptions(picker) do
								if option.value == folder() then
									return `Folder: {option.label}`
								end
							end
							return "Folder: Unsorted"
						end,
						options = function()
							return folderOptions(picker)
						end,
						onSelect = folder,
						size = UDim2.new(1, 0, 0, 28),
						position = UDim2.fromOffset(0, 64),
					})
					else nil,
				label(problem, 64 + offset, 40, Theme.RED),
			}) :: Frame
		end,
	})
end

-- the folder new presets go in: the selected preset's folder, if it's one of yours.
const function currentFolder(store: Store.Store): string?
	const selected = store.selected()
	return if selected and not selected.builtin then selected.folder else nil
end

function PresetDialogs.save(store: Store.Store)
	nameDialog({
		title = "Save lighting",
		description = "Saves your current Studio lighting as a new preset.",
		initial = "",
		action = "Save",
		placeholder = "Preset name",
		store = store,
		folder = currentFolder(store),
		submit = store.savePreset,
	})
end

function PresetDialogs.rename(store: Store.Store, preset: Preset)
	nameDialog({
		title = "Rename preset",
		description = `Rename "{preset.name}".`,
		initial = preset.name,
		action = "Rename",
		placeholder = "Preset name",
		submit = function(name)
			return store.renamePreset(preset, name)
		end,
	})
end

function PresetDialogs.newFolder(store: Store.Store)
	nameDialog({
		title = "New folder",
		description = "Folders keep your presets organized.",
		initial = "",
		action = "Create",
		placeholder = "Folder name",
		submit = function(name)
			return store.createFolder(name)
		end,
	})
end

function PresetDialogs.renameFolder(store: Store.Store, folder: Store.Folder)
	nameDialog({
		title = "Rename folder",
		description = `Rename "{folder.name}".`,
		initial = folder.name,
		action = "Rename",
		placeholder = "Folder name",
		submit = function(name)
			return store.renameFolder(folder.id, name)
		end,
	})
end

const function confirm(title: string, text: string, action: string, variant: "accent" | "danger", activated: () -> ())
	Modal.open({
		title = title,
		height = 170,
		buttons = {
			{ text = "Cancel", activated = function(close)
				close()
			end },
			{ text = action, variant = variant, activated = function(close)
				close()
				activated()
			end },
		},
		body = function()
			return new("Frame")({
				BackgroundTransparency = 1,
				label(text, 0, 80, Theme.MUTED),
			}) :: Frame
		end,
	})
end

function PresetDialogs.update(store: Store.Store, preset: Preset)
	confirm(
		"Update preset",
		`Replace "{preset.name}" with your current Studio lighting? Its old settings will be lost.`,
		"Update",
		"danger",
		function()
			store.updatePreset(preset)
		end
	)
end

function PresetDialogs.delete(store: Store.Store, preset: Preset)
	confirm("Delete preset", `Delete "{preset.name}"? This can't be undone.`, "Delete", "danger", function()
		store.deletePreset(preset)
	end)
end

function PresetDialogs.deleteFolder(store: Store.Store, folder: Store.Folder)
	confirm(
		"Delete folder",
		`Delete the folder "{folder.name}"? The presets in it move to Unsorted.`,
		"Delete",
		"danger",
		function()
			store.deleteFolder(folder.id)
		end
	)
end

-- inserts the preset, asking first if the place already has one with that name.
function PresetDialogs.insert(store: Store.Store, preset: Preset)
	if not store.isInserted(preset) then
		store.insertPreset(preset)
		return
	end
	confirm(
		"Replace inserted preset",
		`ReplicatedStorage.Photon.Presets already has "{preset.name}". Replace it with this version?`,
		"Replace",
		"accent",
		function()
			store.insertPreset(preset)
		end
	)
end

function PresetDialogs.export(store: Store.Store, preset: Preset)
	const code = store.exportCode(preset)
	Modal.open({
		title = `Export "{preset.name}"`,
		width = 420,
		height = 210,
		buttons = {
			{ text = "Close", variant = "accent", activated = function(close)
				close()
			end },
		},
		body = function()
			const output = CodeBox({
				text = code,
				multiLine = false,
				size = UDim2.new(1, 0, 0, 36),
				position = UDim2.fromOffset(0, 0),
			})
			output.frame.ZIndex = Theme.OVERLAY_Z + 1
			output.box.ZIndex = Theme.OVERLAY_Z + 1
			task.defer(function()
				if output.box.Parent then
					output.box:CaptureFocus()
				end
			end)
			return new("Frame")({
				BackgroundTransparency = 1,
				output.frame,
				label(
					`{#code} characters. Click the code and press Ctrl+C (Cmd+C on Mac) to copy it, `
						.. "then share it with anyone using Photon or the Photon loader.",
					46,
					60,
					Theme.MUTED
				),
			}) :: Frame
		end,
	})
end

-- paste a code, check it, then name the preset.
function PresetDialogs.import(store: Store.Store)
	const code = source("")
	const name = source("")
	const validated = source(false)
	const problem = source("")
	const summary = source("")
	local closeDialog: (() -> ())? = nil

	const function advance()
		problem("")
		if not validated() then
			const data, message = store.decodeCode(code())
			if data == nil then
				problem(message or "That isn't a Photon code.")
				return
			end
			local effects = {}
			for _, effect in data.effects do
				table.insert(effects, effect.name)
			end
			summary(if #effects > 0 then `Valid code with {table.concat(effects, ", ")}.` else "Valid code.")
			validated(true)
			return
		end
		const ok, message = store.importCode(code(), name(), currentFolder(store))
		if ok then
			if closeDialog then
				closeDialog()
			end
		else
			problem(message or "Couldn't import the preset.")
		end
	end

	Modal.open({
		title = "Import lighting",
		width = 420,
		height = 230,
		buttons = {
			{ text = "Cancel", activated = function(close)
				close()
			end },
			{
				text = function()
					return if validated() then "Save" else "Next"
				end,
				variant = "accent",
				activated = advance,
			},
		},
		body = function(close)
			closeDialog = close
			const input = CodeBox({
				text = "",
				placeholder = "Paste a lighting code (starts with PH)",
				multiLine = false,
				size = UDim2.new(1, 0, 0, 32),
				position = UDim2.fromOffset(0, 26),
				onChange = function(value)
					code(value)
					if validated() then
						validated(false)
					end
				end,
			})
			input.frame.ZIndex = Theme.OVERLAY_Z + 1
			input.box.ZIndex = Theme.OVERLAY_Z + 1
			vide.effect(function()
				input.frame.Visible = not validated()
			end)
			task.defer(function()
				if input.box.Parent then
					input.box:CaptureFocus()
				end
			end)
			return new("Frame")({
				BackgroundTransparency = 1,
				label(function()
					return if validated() then summary() .. " Name your copy:" else "Paste a code someone shared with you."
				end, 0, 22, Theme.MUTED),
				input.frame,
				vide.show(validated, function()
					return textBox(name, "Preset name", 26, advance)
				end),
				label(problem, 66, 50, Theme.RED),
			}) :: Frame
		end,
	})
end

return PresetDialogs
