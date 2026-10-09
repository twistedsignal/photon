-- preset folders and Snapshot round-trip through real instances, and Schema matches Roblox.
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")

-- the loader modules use Roblox globals; load them with lune's roblox library in scope.
local loaded = {}
local function load(name)
	if loaded[name] == nil then
		local environment = setmetatable({
			Instance = roblox.Instance,
			Color3 = roblox.Color3,
			Vector3 = roblox.Vector3,
			Enum = roblox.Enum,
			require = function(path)
				return load(string.match(path, "^%./(.+)$"))
			end,
		}, { __index = getfenv(1) })
		loaded[name] = luau.load(fs.readFile(`src/Loader/{name}.luau`), { debugName = name, environment = environment })()
	end
	return loaded[name]
end
local Schema = load("Schema")
local Snapshot = load("Snapshot")
local Template = load("Template")

-- Schema defaults and property names match fresh instances of every class.
for index = 2, #Schema.sections do
	local section = Schema.sections[index]
	local instance = roblox.Instance.new(section.class)
	for _, field in section.fields do
		local ok, value = pcall(Schema.read, instance, field)
		-- lune's reflection lacks some defaults; those were checked in Studio instead.
		if not ok and string.find(tostring(value), "missing default value") then
			continue
		end
		assert(ok, `{section.class}.{field.name} can't be read: {value}`)
		assert(Schema.valid(field, value), `{section.class}.{field.name} read an invalid value`)
		assert(Schema.equal(field, value, field.default), `{section.class}.{field.name} default differs from Roblox`)
	end
end

local data = {
	version = 1,
	lighting = {
		Ambient = { 0.2, 0.3, 0.4 },
		Brightness = 3.5,
		ClockTime = 18.25,
		GlobalShadows = false,
		LightingStyle = "Soft",
		FogEnd = 500,
	},
	-- effects come back in Schema section order, so list them that way.
	effects = {
		{ class = "Sky", name = "Night Sky", props = { SkyboxUp = "rbxassetid://123", StarCount = 4000, SkyboxOrientation = { 0, 45, 0 } } },
		{ class = "Atmosphere", name = "Atmosphere", props = { Density = 0.3, Haze = 2 } },
		{ class = "Clouds", name = "Clouds", props = { Cover = 0.8 } },
		{ class = "ColorCorrectionEffect", name = "Warm", props = { TintColor = { 1, 0.9, 0.8 }, Contrast = 0.1 } },
		{ class = "ColorCorrectionEffect", name = "Fade", props = { Enabled = false, Saturation = -0.5 } },
	},
}

local folder = Template.toFolder(data, "Evening")
assert(folder.Name == "Evening" and Template.isPreset(folder))
assert(folder:FindFirstChild("Brightness").ClassName == "NumberValue")
assert(folder:FindFirstChild("Ambient").ClassName == "Color3Value")
assert(folder:FindFirstChild("LightingStyle").ClassName == "StringValue")
assert(folder:FindFirstChild("Ambient2") == nil and folder:FindFirstChild("ExposureCompensation") == nil, "unset values are skipped")
assert(#folder.child:GetChildren() == 5)

local back = Template.fromFolder(folder)
for name, value in data.lighting do
	local field
	for _, f in Schema.lighting.fields do
		if f.name == name then
			field = f
		end
	end
	assert(Schema.equal(field, value, back.lighting[name]), `Lighting.{name} round trip`)
end
assert(back.lighting.ExposureCompensation == nil, "missing values stay missing")
assert(#back.effects == #data.effects)
for index, effect in data.effects do
	local got = back.effects[index]
	assert(got.class == effect.class and got.name == effect.name, `effect {index} identity`)
	for name, value in effect.props do
		local field
		for _, f in Schema.byClass[effect.class].fields do
			if f.name == name then
				field = f
			end
		end
		assert(Schema.equal(field, value, got.props[name]), `{effect.class}.{name} round trip`)
	end
end

-- apply then capture returns the same preset, and unrelated Lighting children survive.
local lighting = roblox.Instance.new("Folder")
local terrain = roblox.Instance.new("Folder")
local keep = roblox.Instance.new("Script")
keep.Parent = lighting
local old = roblox.Instance.new("BloomEffect")
old.Parent = lighting
Snapshot.apply(back, lighting, terrain)
assert(keep.Parent == lighting, "unrelated children are kept")
assert(old.Parent == nil, "old effects are replaced")
assert(terrain:FindFirstChildOfClass("Clouds"), "clouds go to terrain")
local captured = Snapshot.capture(lighting, terrain)
assert(#captured.effects == #data.effects)
for index, effect in captured.effects do
	assert(effect.class == data.effects[index].class, `captured effect {index} class`)
end

-- clean drops junk instead of erroring.
local cleaned = Snapshot.clean({
	lighting = { Brightness = "bright", Ambient = { 1, 2 }, ClockTime = 6 },
	effects = { { class = "Part", props = {} }, { class = "BlurEffect", props = { Size = 4, Enabled = "yes" } }, 5 },
})
assert(cleaned and cleaned.lighting.Brightness == nil and cleaned.lighting.Ambient == nil and cleaned.lighting.ClockTime == 6)
assert(#cleaned.effects == 1 and cleaned.effects[1].props.Size == 4 and cleaned.effects[1].props.Enabled == nil)
assert(Snapshot.clean("nope") == nil)

print("template: folder, snapshot and schema checks passed")
