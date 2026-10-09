-- Schedule captures after reactive evaluation. Vide's untrack must only read state:
-- writing sources inside it can re-enter an effect while its callback is false.
const vide = require("../vide")
const Store = require("../Store")

const function Automatic(store: Store.Store)
	vide.effect(function()
		const preset = store.selected()
		store.previewsVersion()
		if preset == nil or not store.loaded() or not store.previewSettings().autoCapture then
			return
		end
		if vide.untrack(function() return store.preview(preset) end) ~= nil or store.previewErrors()[preset.id] ~= nil then
			return
		end

		const pending = task.defer(function()
			store.requestPreview(preset)
		end)
		-- Switching presets or leaving the library cancels a request that hasn't started.
		vide.cleanup(function()
			if coroutine.status(pending) == "suspended" then
				task.cancel(pending)
			end
		end)
	end)
end

return Automatic
