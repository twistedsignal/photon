-- every built-in preset is valid, has a unique name, and round-trips through a share code.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Schema = require("../src/Loader/Schema")
local Codec = require("../src/Loader/Codec")
local Snapshot = require("../src/Loader/Snapshot")

-- plugin modules use `const`; older lune releases only know `local`.
local source = fs.readFile("src/Presets/Builtin.luau"):gsub("%f[%w]const%f[%W]", "local")
local Builtin = luau.load(source, {
	debugName = "Builtin",
	environment = setmetatable({
		require = function(path)
			assert(path == "../Loader/Schema", path)
			return Schema
		end,
	}, { __index = getfenv(1) }),
})()

local names, ids, lengths = {}, {}, {}
for _, preset in Builtin do
	assert(not names[preset.name] and not ids[preset.id], `duplicate {preset.name}`)
	names[preset.name], ids[preset.id] = true, true
	-- clean keeps everything, so every value is valid.
	local cleaned = Snapshot.clean(preset.data)
	for _, field in Schema.lighting.fields do
		assert(cleaned.lighting[field.name] ~= nil, `{preset.name}: Lighting.{field.name} missing or invalid`)
	end
	assert(#cleaned.effects == #preset.data.effects, `{preset.name}: invalid effect`)
	for index, effect in preset.data.effects do
		for name in effect.props do
			assert(cleaned.effects[index].props[name] ~= nil, `{preset.name}: {effect.class}.{name} invalid`)
		end
	end
	local code = Codec.encode(preset.data)
	local decoded = assert(Codec.decode(code))
	assert(Codec.encode(decoded) == code, `{preset.name}: unstable code`)
	assert(#decoded.effects == #preset.data.effects, `{preset.name}: effects lost`)
	table.insert(lengths, `{preset.name} {#code}`)
end
print(`builtins: {#Builtin} presets; code lengths: {table.concat(lengths, ", ")}`)
