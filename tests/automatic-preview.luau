-- Real Vide effects must survive selecting an uncached preset and nested source updates.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")
local vide = {
	root = require("../Packages/_Index/centau_vide@0.4.1/vide/src/root"),
	source = require("../Packages/_Index/centau_vide@0.4.1/vide/src/source"),
	effect = require("../Packages/_Index/centau_vide@0.4.1/vide/src/effect"),
	untrack = require("../Packages/_Index/centau_vide@0.4.1/vide/src/untrack"),
}
-- The package omits its standalone Roblox mocks. Load cleanup with Roblox typeof
-- enabled while keeping the actual Vide graph used by the other core modules.
local graph = require("../Packages/_Index/centau_vide@0.4.1/vide/src/graph")
vide.cleanup = luau.load(fs.readFile("Packages/_Index/centau_vide@0.4.1/vide/src/cleanup.luau"), {
	environment = setmetatable({
		game = true,
		task = task,
		require = function(path) assert(path == "./graph"); return graph end,
	}, { __index = getfenv(1) }),
})()
local source = fs.readFile("src/Preview/Automatic.luau"):gsub("%f[%w]const%f[%W]", "local")
local Automatic = luau.load(source, {
	debugName = "Automatic",
	environment = setmetatable({
		task = task,
		require = function(path)
			if path == "../vide" then return vide end
			assert(path == "../Store", path)
			return {}
		end,
	}, { __index = getfenv(1) }),
})()

local flags = require("../Packages/_Index/centau_vide@0.4.1/vide/src/flags")
local initialStrict = flags.strict
local function check(strict)
	flags.strict = strict
	local selected = vide.source(nil)
	local version = vide.source(0)
	local errors = vide.source({})
	local settings = vide.source({autoCapture = true})
	local busy = vide.source(false)
	local cached = {}
	local requests = {}
	local store = {
		selected = selected,
		previewsVersion = version,
		previewErrors = errors,
		previewSettings = settings,
		loaded = function() return true end,
		preview = function(preset) return cached[preset.id] end,
		requestPreview = function(preset)
			if busy() then return end
			table.insert(requests, preset.id)
			busy(true)
			-- Mirrors the Store's synchronous update that used to re-enter untrack.
			errors({})
		end,
	}
	local stop = vide.root(function()
		Automatic(store)
		vide.effect(function() busy() end)
	end)
	local a = {id = "a"}
	local b = {id = "b"}
	selected(a)
	assert(#requests == 0, "capture ran during reactive evaluation")
	task.wait()
	assert(#requests == 1 and requests[1] == "a", "selected preset wasn't requested")
	-- The source update during requestPreview may schedule a guarded follow-up, as in Store.
	cached.a = true
	busy(false)
	version(1)
	task.wait()
	assert(#requests == 1, "cached preset was captured again")
	
	selected(b)
	selected(a)
	task.wait()
	assert(#requests == 1, "stale selection wasn't cancelled")
	settings({autoCapture = false})
	selected(b)
	task.wait()
	assert(#requests == 1, "disabled automatic capture requested a preview")
	errors({b = "failed"})
	settings({autoCapture = true})
	task.wait()
	assert(#requests == 1, "failed preview was retried automatically")
	errors({})
	stop()
	task.wait()
	assert(#requests == 1, "unmounted preview still requested a capture")
end
check(false)
check(true)
flags.strict = initialStrict
print("automatic preview: strict and optimized effects, nested updates and cancellation passed")
