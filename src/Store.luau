-- app state: presets, folders, previews, and the actions behind every button.
const ChangeHistoryService = game:GetService("ChangeHistoryService")
const HttpService = game:GetService("HttpService")
const Lighting = game:GetService("Lighting")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Selection = game:GetService("Selection")
const vide = require("./vide")
const Data = require("./Data")
const Schema = require("./Loader/Schema")
const Codec = require("./Loader/Codec")
const Snapshot = require("./Loader/Snapshot")
const Template = require("./Loader/Template")
const LoaderBuilder = require("./LoaderBuilder")
const Builtin = require("./Presets/Builtin")
const Capture = require("./Preview/Capture")
const Previews = require("./Preview/Previews")
const PreviewSettings = require("./Preview/Settings")
const PreviewModel = require("./Preview/Model")
const VERSION = require("./Version")

const source = vide.source

const PRESETS_KEY = "PhotonPresets"
const FOLDERS_KEY = "PhotonFolders"
const COLLAPSED_KEY = "PhotonCollapsed"
const SETTINGS_KEY = "PhotonPreviewSettings"
const MODEL_KEY = "PhotonPreviewModel"
const MAX_NAME_LENGTH = 50

-- the fixed sections around your own folders.
const BUILTIN_FOLDER = "builtin"
const UNSORTED_FOLDER = "unsorted"

export type Preset = {
	id: string,
	name: string,
	builtin: boolean,
	data: Schema.Data,
	-- id of the folder it's in. nil is Unsorted; built-ins are always in Built-in.
	folder: string?,
	created: number?,
	updated: number?,
}

export type Folder = { id: string, name: string }

-- a folder as the library shows it: fixed or yours, with the presets that match the search.
export type Section = { id: string, name: string, custom: boolean, presets: { Preset } }

export type Notice = { text: string, kind: "info" | "error" | "success" }

const function builtins(): { Preset }
	const list = {}
	for _, builtin in Builtin do
		table.insert(list, { id = builtin.id, name = builtin.name, builtin = true, data = builtin.data })
	end
	return list
end

const function trim(text: string): string
	return string.match(text, "^%s*(.-)%s*$") :: string
end

-- presets from plugin settings, skipping anything malformed.
const function readPresets(saved: any): { Preset }
	const list = {}
	if type(saved) ~= "table" then
		return list
	end
	for _, entry in saved do
		if type(entry) ~= "table" or type(entry.id) ~= "string" or type(entry.name) ~= "string" then
			continue
		end
		const data = Snapshot.clean(entry.data)
		if data then
			table.insert(list, {
				id = entry.id,
				name = string.sub(entry.name, 1, MAX_NAME_LENGTH),
				builtin = false,
				data = data,
				folder = if type(entry.folder) == "string" then entry.folder else nil,
				created = tonumber(entry.created),
				updated = tonumber(entry.updated),
			})
		end
	end
	return list
end

const function readFolders(saved: any): { Folder }
	const list = {}
	if type(saved) ~= "table" then
		return list
	end
	for _, entry in saved do
		if type(entry) == "table" and type(entry.id) == "string" and type(entry.name) == "string" then
			table.insert(list, { id = entry.id, name = string.sub(entry.name, 1, MAX_NAME_LENGTH) })
		end
	end
	return list
end

const function byName(a: { name: string }, b: { name: string }): boolean
	return string.lower(a.name) < string.lower(b.name)
end

const function create(plugin: Plugin)
	const previewSettings = source(table.clone(PreviewSettings.defaults))
	const previewModelName = source(nil :: string?)
	const previewModelId = source(nil :: string?)
	const modelSaving = source(false)
	const previewSelection = source(nil :: string?)
	local model: Model? = nil
	const function previewContext(): string
		return PreviewSettings.key(previewSettings(), previewModelId())
	end
	const previews = Previews.create(plugin, previewContext)
	const user = source({} :: { Preset })
	const folders = source({} :: { Folder })
	const collapsed = source({} :: { [string]: boolean })
	const selectedId = source(nil :: string?)
	const query = source("")
	const notice = source(nil :: Notice?)
	-- bumps whenever a preview appears or goes away.
	const previewsVersion = source(0)
	-- presets being previewed, and the last problem per preset.
	const previewing = source({} :: { [string]: boolean })
	const previewErrors = source({} :: { [string]: string })
	const loaderOptions = source(LoaderBuilder.defaults())
	const insertionParent = source(ReplicatedStorage :: Instance)
	const loaded = source(false)
	local destroyed = false

	const self = {}
	const allBuiltins = builtins()

	self.user = user
	self.folders = folders
	self.selectedId = selectedId
	self.query = query
	self.notice = notice
	self.previewsVersion = previewsVersion
	self.previewing = previewing
	self.previewErrors = previewErrors
	self.loaded = loaded
	self.loaderOptions = loaderOptions
	self.insertionParent = insertionParent
	self.previewSettings = previewSettings
	self.previewModelName = previewModelName
	self.modelSaving = modelSaving
	self.previewSelection = previewSelection

	const function selectionChanged()
		const selected = Selection:Get()
		const candidate = if #selected == 1 then selected[1] else nil
		previewSelection(if candidate and (candidate:IsA("Model") or candidate:IsA("BasePart")) then candidate.Name else nil)
	end
	selectionChanged()
	const selectionConnection = Selection.SelectionChanged:Connect(selectionChanged)

	function self.setNotice(text: string, kind: "info" | "error" | "success")
		const value = { text = text, kind = kind }
		notice(value)
		task.delay(if kind == "error" then 8 else 5, function()
			if notice() == value then
				notice(nil)
			end
		end)
	end

	-- ---------------------------------------------------------------
	-- state
	-- ---------------------------------------------------------------

	function self.find(id: string?): Preset?
		if id == nil then
			return nil
		end
		for _, preset in allBuiltins do
			if preset.id == id then
				return preset
			end
		end
		for _, preset in user() do
			if preset.id == id then
				return preset
			end
		end
		return nil
	end

	function self.selected(): Preset?
		return self.find(selectedId())
	end

	-- the library: Built-in, your folders by name, then Unsorted. while searching, only
	-- matching presets are listed and empty folders are hidden.
	function self.sections(): { Section }
		const text = string.lower(query())
		const function matches(preset: Preset): boolean
			return text == "" or string.find(string.lower(preset.name), text, 1, true) ~= nil
		end
		const known: { [string]: boolean } = {}
		const ordered = table.clone(folders())
		table.sort(ordered, byName)
		for _, folder in ordered do
			known[folder.id] = true
		end
		const contents: { [string]: { Preset } } = { [UNSORTED_FOLDER] = {} }
		for _, folder in ordered do
			contents[folder.id] = {}
		end
		for _, preset in user() do
			if matches(preset) then
				const id = if preset.folder and known[preset.folder] then preset.folder else UNSORTED_FOLDER
				table.insert(contents[id], preset)
			end
		end
		const builtin = {}
		for _, preset in allBuiltins do
			if matches(preset) then
				table.insert(builtin, preset)
			end
		end

		const list: { Section } = { { id = BUILTIN_FOLDER, name = "Built-in", custom = false, presets = builtin } }
		for _, folder in ordered do
			const presets = contents[folder.id]
			table.sort(presets, byName)
			table.insert(list, { id = folder.id, name = folder.name, custom = true, presets = presets })
		end
		table.sort(contents[UNSORTED_FOLDER], byName)
		table.insert(list, { id = UNSORTED_FOLDER, name = "Unsorted", custom = false, presets = contents[UNSORTED_FOLDER] })

		if text ~= "" then
			const filtered = {}
			for _, section in list do
				if #section.presets > 0 then
					table.insert(filtered, section)
				end
			end
			return filtered
		end
		return list
	end

	-- searching opens every folder so matches aren't hidden.
	function self.isCollapsed(id: string): boolean
		return query() == "" and collapsed()[id] == true
	end

	function self.toggleFolder(id: string)
		const next = table.clone(collapsed())
		next[id] = if next[id] then nil else true
		collapsed(next)
		task.spawn(pcall, Data.save, plugin, COLLAPSED_KEY, next)
	end

	const function persistPresets()
		const list = {}
		for _, preset in user() do
			table.insert(list, {
				id = preset.id,
				name = preset.name,
				data = preset.data,
				folder = preset.folder,
				created = preset.created,
				updated = preset.updated,
			})
		end
		task.spawn(function()
			const ok, problem = pcall(Data.save, plugin, PRESETS_KEY, list)
			if not ok then
				self.setNotice(`Couldn't save your presets: {problem}`, "error")
			end
		end)
	end

	const function persistFolders()
		const list = folders()
		task.spawn(function()
			const ok, problem = pcall(Data.save, plugin, FOLDERS_KEY, list)
			if not ok then
				self.setNotice(`Couldn't save your folders: {problem}`, "error")
			end
		end)
	end

	-- replaces one of your presets with a changed copy.
	const function replace(id: string, change: (Preset) -> ()): Preset?
		const list = table.clone(user())
		for index, entry in list do
			if entry.id == id then
				const updated = table.clone(entry)
				change(updated)
				list[index] = updated
				user(list)
				persistPresets()
				return updated
			end
		end
		return nil
	end

	-- ---------------------------------------------------------------
	-- names
	-- ---------------------------------------------------------------

	-- why a preset name can't be used, or nil when it's fine.
	function self.nameProblem(name: string, except: string?): string?
		const trimmed = trim(name)
		if trimmed == "" then
			return "Give the preset a name."
		elseif #trimmed > MAX_NAME_LENGTH then
			return `Names can be up to {MAX_NAME_LENGTH} characters.`
		end
		for _, preset in allBuiltins do
			if string.lower(preset.name) == string.lower(trimmed) then
				return `"{preset.name}" is a built-in preset. Pick another name.`
			end
		end
		for _, preset in user() do
			if preset.id ~= except and string.lower(preset.name) == string.lower(trimmed) then
				return `You already have a preset named "{preset.name}".`
			end
		end
		return nil
	end

	function self.folderProblem(name: string, except: string?): string?
		const trimmed = trim(name)
		if trimmed == "" then
			return "Give the folder a name."
		elseif #trimmed > MAX_NAME_LENGTH then
			return `Names can be up to {MAX_NAME_LENGTH} characters.`
		elseif string.lower(trimmed) == "built-in" or string.lower(trimmed) == "unsorted" then
			return `"{trimmed}" is already used by Photon. Pick another name.`
		end
		for _, folder in folders() do
			if folder.id ~= except and string.lower(folder.name) == string.lower(trimmed) then
				return `You already have a folder named "{folder.name}".`
			end
		end
		return nil
	end

	-- ---------------------------------------------------------------
	-- folders
	-- ---------------------------------------------------------------

	function self.createFolder(name: string): (boolean, string?)
		const problem = self.folderProblem(name)
		if problem then
			return false, problem
		end
		const list = table.clone(folders())
		table.insert(list, { id = HttpService:GenerateGUID(false), name = trim(name) })
		folders(list)
		persistFolders()
		return true, nil
	end

	function self.renameFolder(id: string, name: string): (boolean, string?)
		const problem = self.folderProblem(name, id)
		if problem then
			return false, problem
		end
		const list = table.clone(folders())
		for index, folder in list do
			if folder.id == id then
				list[index] = { id = id, name = trim(name) }
			end
		end
		folders(list)
		persistFolders()
		return true, nil
	end

	-- deletes the folder; its presets move to Unsorted.
	function self.deleteFolder(id: string)
		const list = {}
		for _, folder in folders() do
			if folder.id ~= id then
				table.insert(list, folder)
			end
		end
		folders(list)
		persistFolders()
		const presets = table.clone(user())
		local moved = false
		for index, preset in presets do
			if preset.folder == id then
				const copy = table.clone(preset)
				copy.folder = nil
				presets[index] = copy
				moved = true
			end
		end
		if moved then
			user(presets)
			persistPresets()
		end
	end

	function self.moveToFolder(preset: Preset, folder: string?)
		if preset.builtin then
			return
		end
		replace(preset.id, function(copy)
			copy.folder = folder
		end)
	end

	-- ---------------------------------------------------------------
	-- previews
	-- ---------------------------------------------------------------

	const function setFlag(target: typeof(previewing), key: string, value: any)
		const next = table.clone(target())
		next[key] = value
		target(next)
	end

	const function changed()
		previewsVersion(previewsVersion() + 1)
	end

	local settingsRevision = 0
	local savingSettings = false
	const function persistSettings()
		settingsRevision += 1
		if savingSettings then
			return
		end
		savingSettings = true
		task.spawn(function()
			repeat
				task.wait(0.2)
				const revision = settingsRevision
				const ok, problem = pcall(Data.save, plugin, SETTINGS_KEY, previewSettings())
				if not ok and not destroyed then
					self.setNotice(`Couldn't save preview settings: {problem}`, "error")
				end
			until revision == settingsRevision
			savingSettings = false
		end)
	end

	function self.setPreviewSetting(name: string, value: any)
		if not loaded() or PreviewSettings.defaults[name] == nil then
			return
		end
		const next = table.clone(previewSettings()) :: any
		next[name] = value
		previewSettings(PreviewSettings.clean(next))
		previewErrors({})
		changed()
		persistSettings()
	end

	function self.resetPreviewSettings()
		if not loaded() then
			return
		end
		previewSettings(table.clone(PreviewSettings.defaults))
		previewErrors({})
		changed()
		persistSettings()
	end

	function self.setPreviewModel()
		if not loaded() or modelSaving() then
			return
		end
		const selected = Selection:Get()
		if #selected ~= 1 then
			self.setNotice("Select one Model or part in Explorer.", "error")
			return
		end
		modelSaving(true)
		task.spawn(function()
			local candidate: Model? = nil
			const ok, result = pcall(function()
				const saved, decoded = PreviewModel.encode(selected[1], HttpService:GenerateGUID(false))
				candidate = decoded
				Data.save(plugin, MODEL_KEY, saved)
				return saved
			end)
			modelSaving(false)
			if destroyed then
				if candidate then
					candidate:Destroy()
				end
				return
			end
			if not ok then
				if candidate then
					candidate:Destroy()
				end
				self.setNotice(`Couldn't save the preview model: {result}`, "error")
				return
			end
			if model then
				model:Destroy()
			end
			model = candidate
			previewModelName(result.name)
			previewModelId(result.id)
			previewErrors({})
			changed()
			self.setNotice(`Saved "{result.name}" as your preview model.`, "success")
		end)
	end

	function self.clearPreviewModel()
		if not loaded() or modelSaving() then
			return
		end
		modelSaving(true)
		task.spawn(function()
			const ok, problem = pcall(Data.save, plugin, MODEL_KEY, false)
			modelSaving(false)
			if destroyed then
				return
			end
			if not ok then
				self.setNotice(`Couldn't reset the preview model: {problem}`, "error")
				return
			end
			if model then
				model:Destroy()
			end
			model = nil
			previewModelName(nil)
			previewModelId(nil)
			previewErrors({})
			changed()
		end)
	end

	-- the preset's preview images, if it has been previewed.
	function self.preview(preset: Preset): Previews.Entry?
		previewsVersion()
		return previews.get(preset.id, preset.data)
	end

	-- previews the preset. data defaults to the preset's own; pass current = true to take the
	-- picture of the place's lighting as it is, for a preset just saved from it.
	function self.requestPreview(preset: Preset, force: boolean?, current: boolean?)
		if not loaded() or destroyed or previewing()[preset.id] or (not force and previews.get(preset.id, preset.data)) then
			return
		end
		const context = previewContext()
		const options = table.clone(previewSettings())
		const subject = if model then model:Clone() else nil
		setFlag(previewing, preset.id, true)
		setFlag(previewErrors, preset.id, nil)
		task.spawn(function()
			local ok, large, problem = pcall(Capture.preview, if current then nil else preset.data, Previews.WIDTH, Previews.HEIGHT, options, subject)
			if not ok then
				problem = tostring(large)
				large = nil
			end
			if subject then
				subject:Destroy()
			end
			if destroyed then
				if large then
					large:Destroy()
				end
				return
			end
			setFlag(previewing, preset.id, nil)
			if context ~= previewContext() then
				if large then
					large:Destroy()
				end
				changed()
				return
			end
			if large then
				previews.put(preset.id, preset.data, large)
				if not destroyed then
					changed()
				end
			else
				setFlag(previewErrors, preset.id, problem or "Preview failed")
				self.setNotice(problem or "Preview failed", "error")
			end
		end)
	end

	function self.clearPreviews()
		const ids = {}
		for _, preset in allBuiltins do
			table.insert(ids, preset.id)
		end
		for _, preset in user() do
			table.insert(ids, preset.id)
		end
		previews.clear(ids)
		previewErrors({})
		changed()
	end

	-- saved previews load in the background once the presets are known.
	vide.effect(function()
		const list = table.clone(allBuiltins)
		for _, preset in user() do
			table.insert(list, preset)
		end
		if not loaded() then
			return
		end
		task.spawn(function()
			for _, preset in list do
				if destroyed then
					return
				end
				if previews.get(preset.id, preset.data) == nil and previews.load(preset.id, preset.data) then
					changed()
				end
			end
		end)
	end)

	task.spawn(function()
		const okSettings, savedSettings = pcall(Data.load, plugin, SETTINGS_KEY, {})
		if okSettings then
			previewSettings(PreviewSettings.clean(savedSettings))
		end
		const okModel, savedModel = pcall(Data.load, plugin, MODEL_KEY, false)
		if okModel and type(savedModel) == "table" then
			const decoded, result = pcall(PreviewModel.decode, savedModel)
			if decoded then
				if destroyed then
					result:Destroy()
					return
				end
				model = result
				previewModelName(savedModel.name or result.Name)
				previewModelId(savedModel.id or "saved")
			else
				self.setNotice(`Couldn't restore the preview model: {result}`, "error")
			end
		end
		const okPresets, presets = pcall(Data.load, plugin, PRESETS_KEY, {})
		const okFolders, savedFolders = pcall(Data.load, plugin, FOLDERS_KEY, {})
		const okCollapsed, savedCollapsed = pcall(Data.load, plugin, COLLAPSED_KEY, {})
		if okFolders then
			folders(readFolders(savedFolders))
		end
		if okCollapsed and type(savedCollapsed) == "table" then
			const clean = {}
			for id, value in savedCollapsed do
				if type(id) == "string" and value == true then
					clean[id] = true
				end
			end
			collapsed(clean)
		end
		if okPresets then
			user(readPresets(presets))
		else
			self.setNotice("Couldn't read your saved presets. Restart Studio and try again.", "error")
		end
		if not destroyed then
			loaded(true)
		end
	end)

	-- ---------------------------------------------------------------
	-- actions
	-- ---------------------------------------------------------------

	-- runs a change inside an undoable recording.
	const function undoable(name: string, change: () -> ()): (boolean, string?)
		const recording = ChangeHistoryService:TryBeginRecording(name)
		const ok, problem = pcall(change)
		if recording then
			ChangeHistoryService:FinishRecording(
				recording,
				if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
			)
		elseif ok then
			ChangeHistoryService:SetWaypoint(name)
		end
		return ok, if ok then nil else tostring(problem)
	end

	function self.loadPreset(preset: Preset)
		const ok, problem = undoable(`Load lighting "{preset.name}"`, function()
			Snapshot.apply(preset.data, Lighting, nil, true)
		end)
		if ok then
			self.setNotice(`Loaded "{preset.name}". Press Ctrl+Z to undo.`, "success")
		else
			self.setNotice(`Couldn't load "{preset.name}": {problem}`, "error")
		end
	end

	function self.isInserted(preset: Preset, parent: Instance?): boolean
		const existing = (parent or insertionParent()):FindFirstChild(preset.name)
		return existing ~= nil and Template.isPreset(existing)
	end

	const function parentProblem(parent: Instance): string?
		if parent ~= game and not parent:IsDescendantOf(game) then
			return "Choose a parent that is still in the game."
		end
		return nil
	end

	function self.insertLoader(options: LoaderBuilder.Options, parent: Instance, name: string): (boolean, string?)
		const trimmed = trim(name)
		const problem = parentProblem(parent) or LoaderBuilder.problem(options)
		if problem then
			return false, problem
		end
		if trimmed == "" or #trimmed > 100 then
			return false, "Use a module name between 1 and 100 characters."
		end
		if parent:FindFirstChild(trimmed) then
			return false, `"{trimmed}" already exists here. Choose another name.`
		end
		const generated, code = pcall(LoaderBuilder.generate, options)
		if not generated then
			return false, tostring(code)
		end
		local inserted: ModuleScript? = nil
		const ok, message = undoable("Insert Photon loader", function()
			const module = Instance.new("ModuleScript")
			module.Name = trimmed
			module.Source = code
			module:SetAttribute("PhotonVersion", VERSION)
			module:SetAttribute("PhotonLoaderOptions", HttpService:JSONEncode(LoaderBuilder.clean(options)))
			module.Parent = parent
			inserted = module
		end)
		if ok then
			loaderOptions(LoaderBuilder.clean(options))
			insertionParent(parent)
			if inserted then
				Selection:Set({ inserted })
			end
			self.setNotice(`Inserted "{trimmed}" in {parent:GetFullName()}.`, "success")
		end
		return ok, message
	end

	-- Insert the editable preset in the chosen parent, without creating a loader or folders.
	function self.insertPreset(preset: Preset, parent: Instance?): (boolean, string?)
		const destination = parent or insertionParent()
		const problem = parentProblem(destination)
		if problem then
			return false, problem
		end
		const old = destination:FindFirstChild(preset.name)
		if old and not Template.isPreset(old) then
			return false, `An object named "{preset.name}" already exists here.`
		end
		local inserted: Instance? = nil
		const ok, message = undoable(`Insert lighting "{preset.name}"`, function()
			if old then
				old.Parent = nil
			end
			const folder = Template.toFolder(preset.data, preset.name)
			folder.Parent = destination
			inserted = folder
		end)
		if ok then
			insertionParent(destination)
			if inserted then
				Selection:Set({ inserted })
			end
			self.setNotice(`Inserted "{preset.name}" in {destination:GetFullName()}.`, "success")
		end
		return ok, message
	end

	const function add(name: string, data: Schema.Data, folder: string?): Preset
		const now = os.time()
		const preset: Preset = {
			id = HttpService:GenerateGUID(false),
			name = trim(name),
			builtin = false,
			data = data,
			folder = folder,
			created = now,
			updated = now,
		}
		const list = table.clone(user())
		table.insert(list, preset)
		user(list)
		persistPresets()
		selectedId(preset.id)
		return preset
	end

	-- saves the place's current lighting as a new preset.
	function self.savePreset(name: string, folder: string?): (boolean, string?)
		const problem = self.nameProblem(name)
		if problem then
			return false, problem
		end
		const preset = add(name, Snapshot.capture(Lighting), folder)
		if previewSettings().autoCapture then
			self.requestPreview(preset, true, true)
		end
		self.setNotice(`Saved "{preset.name}".`, "success")
		return true, nil
	end

	-- overwrites a preset with the place's current lighting.
	function self.updatePreset(preset: Preset)
		const updated = replace(preset.id, function(copy)
			copy.data = Snapshot.capture(Lighting)
			copy.updated = os.time()
		end)
		if updated then
			if previewSettings().autoCapture then
				self.requestPreview(updated, true, true)
			end
			self.setNotice(`Updated "{preset.name}" with your current lighting.`, "success")
		end
	end

	function self.renamePreset(preset: Preset, name: string): (boolean, string?)
		const problem = self.nameProblem(name, preset.id)
		if problem then
			return false, problem
		end
		replace(preset.id, function(copy)
			copy.name = trim(name)
		end)
		return true, nil
	end

	function self.deletePreset(preset: Preset)
		const list = {}
		for _, entry in user() do
			if entry.id ~= preset.id then
				table.insert(list, entry)
			end
		end
		user(list)
		persistPresets()
		previews.forget(preset.id)
		if selectedId() == preset.id then
			selectedId(nil)
		end
		self.setNotice(`Deleted "{preset.name}".`, "info")
	end

	function self.exportCode(preset: Preset): string
		return Codec.encode(preset.data)
	end

	function self.decodeCode(code: string): (Schema.Data?, string?)
		return Codec.decode(code)
	end

	-- saves a share code as a new preset.
	function self.importCode(code: string, name: string, folder: string?): (boolean, string?)
		const data, problem = Codec.decode(code)
		if data == nil then
			return false, problem
		end
		const nameProblem = self.nameProblem(name)
		if nameProblem then
			return false, nameProblem
		end
		const preset = add(name, data, folder)
		if previewSettings().autoCapture then
			self.requestPreview(preset, true)
		end
		self.setNotice(`Imported "{preset.name}".`, "success")
		return true, nil
	end

	function self.destroy()
		destroyed = true
		previews.destroy()
		selectionConnection:Disconnect()
		if model then
			model:Destroy()
			model = nil
		end
	end

	return self
end

export type Store = typeof(create(nil :: any))

return {
	create = create,
	BUILTIN_FOLDER = BUILTIN_FOLDER,
	UNSORTED_FOLDER = UNSORTED_FOLDER,
}
