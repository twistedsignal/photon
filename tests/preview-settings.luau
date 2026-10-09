-- Malformed saved settings can't break a preview; scene changes invalidate cached images.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local source = fs.readFile("src/Preview/Settings.luau"):gsub("%f[%w]const%f[%W]", "local")
local Settings = luau.load(source)()
local defaults = Settings.clean(nil)
local clean = Settings.clean({
	fieldOfView = 1000, cameraDistance = -5, cameraYaw = 0/0,
	cameraElevation = -10, grid = "yes", autoCapture = false,
	floorColor = "#abcdef", modelSize = "big", settleTime = math.huge,
})
assert(clean.fieldOfView == 90 and clean.cameraDistance == 0.5 and clean.cameraElevation == 0)
assert(clean.cameraYaw == defaults.cameraYaw and clean.modelSize == defaults.modelSize)
assert(clean.grid == defaults.grid and clean.autoCapture == false)
assert(clean.floorColor == "#ABCDEF" and clean.settleTime == 5)
assert(Settings.clean({floorColor = "#bad"}).floorColor == defaults.floorColor)
assert(Settings.clean({fieldOfView = false}).fieldOfView == defaults.fieldOfView)
local key = Settings.key(defaults, nil)
for name, value in defaults do
	local changed = table.clone(defaults)
	if type(value) == "number" then changed[name] = value + 1
	elseif type(value) == "boolean" then changed[name] = not value
	else changed[name] = "#000000" end
	assert((Settings.key(changed, nil) == key) == (name == "autoCapture"), `{name}: incorrect cache invalidation`)
end
assert(Settings.key(defaults, "model-a") ~= key)
assert(Settings.key(defaults, "model-a") ~= Settings.key(defaults, "model-b"))
assert(Settings.clean(nil).fieldOfView == 50, "validation mutated defaults")
print("preview settings: validation and cache invalidation passed")
