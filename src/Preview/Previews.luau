-- preview images by preset: a large one for the preview panel and a small copy for its card.
-- they're kept in memory and saved to plugin settings, so each preset is only previewed once.
-- a preview belongs to the exact lighting it was taken of; editing a preset invalidates it.
const Data = require("../Data")
const Base64 = require("../Loader/Base64")
const Codec = require("../Loader/Codec")
const Schema = require("../Loader/Schema")
const Image = require("./Image")

const SAVED_PREFIX = "PhotonPreview_"
const LARGE_WIDTH, LARGE_HEIGHT = 384, 216
const CARD_WIDTH, CARD_HEIGHT = 192, 108

export type Entry = { key: string, large: EditableImage, card: EditableImage }

export type Previews = {
	key: (data: Schema.Data) -> string,
	get: (id: string, data: Schema.Data) -> Entry?,
	put: (id: string, data: Schema.Data, large: EditableImage) -> Entry,
	load: (id: string, data: Schema.Data) -> Entry?,
	forget: (id: string) -> (),
	clear: (ids: { string }) -> (),
	destroy: () -> (),
}

const function create(plugin: Plugin, context: (() -> string)?): Previews
	local memory: { [string]: Entry } = {}
	local destroyed = false

	const self = {} :: Previews

	-- the share code fingerprints everything that changes how a preset looks.
	function self.key(data: Schema.Data): string
		return Codec.encode(data) .. "|" .. (if context then context() else "default")
	end

	const function release(entry: Entry?)
		if entry then
			entry.large:Destroy()
			entry.card:Destroy()
		end
	end

	function self.get(id: string, data: Schema.Data): Entry?
		const entry = memory[id]
		return if entry and entry.key == self.key(data) then entry else nil
	end

	function self.put(id: string, data: Schema.Data, large: EditableImage): Entry
		const entry = { key = self.key(data), large = large, card = Image.fit(large, CARD_WIDTH, CARD_HEIGHT) }
		if destroyed or entry.key ~= self.key(data) then
			release(entry)
			return entry
		end
		if memory[id] ~= entry then
			release(memory[id])
		end
		memory[id] = entry
		task.spawn(function()
			if destroyed or memory[id] ~= entry then
				return
			end
			const packed = Image.pack(large)
			if packed then
				pcall(Data.save, plugin, SAVED_PREFIX .. id, {
					key = entry.key,
					width = large.Size.X,
					height = large.Size.Y,
					pixels = Base64.encode(packed),
				})
			end
		end)
		return entry
	end

	-- a saved preview, if it was taken of the same lighting.
	function self.load(id: string, data: Schema.Data): Entry?
		const cached = self.get(id, data)
		if cached then
			return cached
		end
		const ok, saved = pcall(Data.load, plugin, SAVED_PREFIX .. id, nil)
		if not ok or type(saved) ~= "table" or saved.key ~= self.key(data) or type(saved.pixels) ~= "string" then
			return nil
		end
		const width, height = tonumber(saved.width), tonumber(saved.height)
		if width == nil or height == nil then
			return nil
		end
		const large = Image.unpack(Base64.decode(saved.pixels), width, height)
		if large == nil then
			return nil
		end
		if saved.key ~= self.key(data) then
			large:Destroy()
			return nil
		end
		const entry = { key = saved.key, large = large, card = Image.fit(large, CARD_WIDTH, CARD_HEIGHT) }
		if destroyed or saved.key ~= self.key(data) then
			release(entry)
			return nil
		end
		release(memory[id])
		memory[id] = entry
		return entry
	end

	function self.forget(id: string)
		release(memory[id])
		memory[id] = nil
		pcall(function()
			plugin:SetSetting(SAVED_PREFIX .. id, nil)
		end)
	end

	function self.clear(ids: { string })
		for _, id in ids do
			self.forget(id)
		end
		for _, entry in memory do
			release(entry)
		end
		memory = {}
	end

	function self.destroy()
		destroyed = true
		for _, entry in memory do
			release(entry)
		end
		memory = {}
	end

	return self
end

return {
	create = create,
	WIDTH = LARGE_WIDTH,
	HEIGHT = LARGE_HEIGHT,
}
