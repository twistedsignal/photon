-- share codes round-trip every field within its quantization step and stay short.
local Schema = require("../src/Loader/Schema")
local Codec = require("../src/Loader/Codec")
local Base64 = require("../src/Loader/Base64")

local function close(field, a, b)
	if field.kind == "color" then
		for i = 1, 3 do
			if math.abs(a[i] - b[i]) > 0.5 / 255 + 1e-9 then
				return false
			end
		end
		return true
	elseif field.kind == "vector3" then
		for i = 1, 3 do
			if math.abs(a[i] - b[i]) > field.step / 2 + 1e-6 then
				return false
			end
		end
		return true
	elseif field.kind == "number" then
		return math.abs(a - b) <= field.step / 2 + 1e-6
	end
	return a == b
end

local function check(data, decoded, label)
	for _, field in Schema.lighting.fields do
		local expected = data.lighting[field.name]
		if expected == nil then
			expected = field.default
		end
		assert(close(field, expected, decoded.lighting[field.name]), `{label}: Lighting.{field.name}`)
	end
	assert(#decoded.effects == #data.effects, `{label}: effect count {#decoded.effects} ~= {#data.effects}`)
	for index, effect in data.effects do
		local got = decoded.effects[index]
		assert(got.class == effect.class, `{label}: effect {index} class`)
		for _, field in Schema.byClass[effect.class].fields do
			local expected = effect.props[field.name]
			if expected == nil then
				expected = field.default
			end
			assert(close(field, expected, got.props[field.name]), `{label}: {effect.class}.{field.name}`)
		end
	end
end

-- default lighting is tiny.
local empty = { version = 1, lighting = {}, effects = {} }
local emptyCode = Codec.encode(empty)
assert(#emptyCode <= 10, `default code is {#emptyCode} chars: {emptyCode}`)
check(empty, assert(Codec.decode(emptyCode)), "empty")

-- deterministic pseudo-random presets covering every field kind.
local seed = 12345
local function random(): number
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end
local function value(field)
	if field.kind == "color" then
		return { math.round(random() * 255) / 255, math.round(random() * 255) / 255, math.round(random() * 255) / 255 }
	elseif field.kind == "number" then
		return field.min + random() * (field.max - field.min)
	elseif field.kind == "vector3" then
		return {
			field.min + random() * (field.max - field.min),
			field.min + random() * (field.max - field.min),
			field.min + random() * (field.max - field.min),
		}
	elseif field.kind == "bool" then
		return random() > 0.5
	elseif field.kind == "enum" then
		return field.items[math.floor(random() * #field.items) + 1]
	end
	local kinds = {
		"rbxassetid://" .. math.floor(random() * 2 ^ 40),
		"http://www.roblox.com/asset/?id=" .. math.floor(random() * 2 ^ 30),
		"rbxasset://textures/sky/sky512_up.tex",
		"rbxasset://custom/path.png",
		"",
	}
	return kinds[math.floor(random() * #kinds) + 1]
end

local lengths = {}
for round = 1, 200 do
	local data = { version = 1, lighting = {}, effects = {} }
	for _, field in Schema.lighting.fields do
		if random() > 0.3 then
			data.lighting[field.name] = value(field)
		end
	end
	for index = 2, #Schema.sections do
		local section = Schema.sections[index]
		local count = if random() > 0.5 then (if section.multiple then math.floor(random() * 3) + 1 else 1) else 0
		for _ = 1, count do
			local props = {}
			for _, field in section.fields do
				if random() > 0.3 then
					props[field.name] = value(field)
				end
			end
			table.insert(data.effects, { class = section.class, name = section.name, props = props })
		end
	end
	local code = Codec.encode(data)
	assert(string.match(code, "^PH[%w%-_]+$"), `code has unsafe characters: {code}`)
	local decoded, problem = Codec.decode(code)
	assert(decoded, `round {round}: {problem}`)
	-- asset urls normalize to rbxassetid://.
	for _, effect in data.effects do
		for key, v in effect.props do
			if type(v) == "string" then
				local id = string.match(v, "id=(%d+)$")
				if id then
					effect.props[key] = "rbxassetid://" .. id
				end
			end
		end
	end
	check(data, decoded, `round {round}`)
	-- decoding is stable: re-encoding the decoded data gives the same code.
	assert(Codec.encode(decoded) == code, `round {round}: re-encode differs`)
	table.insert(lengths, #code)
end

-- bad codes fail with a message instead of erroring.
for _, bad in { "", "PH", "hello", "PH!!!!", "PH////", "PHAAAA" .. string.rep("A", 300), "PH_w" } do
	local ok, decoded, problem = pcall(Codec.decode, bad)
	assert(ok, `decode errored on {bad}`)
	assert(decoded == nil and type(problem) == "string", `decode accepted {bad}`)
end
-- a version from the future is reported as such.
local future = Base64.url(buffer.fromstring("\240"))
local _, problem = Codec.decode("PH" .. future)
assert(string.find(problem, "newer version"), problem)

-- base64url round trip for every length.
for length = 0, 40 do
	local bytes = {}
	for i = 1, length do
		bytes[i] = string.char(math.floor(random() * 256))
	end
	local input = table.concat(bytes)
	local text = Base64.url(buffer.fromstring(input))
	assert(not string.find(text, "[+/=]"), text)
	assert(buffer.tostring(Base64.fromUrl(text)) == input, `base64url length {length}`)
end

table.sort(lengths)
print(`codec: default code {emptyCode} ({#emptyCode} chars); random presets {lengths[1]}-{lengths[#lengths]} chars, median {lengths[#lengths // 2]}`)
