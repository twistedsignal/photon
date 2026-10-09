--!strict
-- share codes: preset data bit-packed against the Schema, then base64url'd behind a "PH" prefix.
--
-- layout, most significant bit first:
--   4 bits   format version
--   Lighting fields
--   for every other section: 1 presence bit, then for sections that allow several instances
--   2 bits holding (count - 1), then each instance's fields.
-- every field starts with one bit saying whether it differs from the Schema default. booleans
-- need nothing more. numbers are quantized to the field's step over min..max, colors take 24
-- bits, enums an index, and content a 2-bit tag followed by an asset id varint or a string.
local Schema = require("./Schema")
local Base64 = require("./Base64")

local PREFIX = "PH"
local MAX_INSTANCES = 4
local CONTENT_ASSET, CONTENT_KNOWN, CONTENT_STRING, CONTENT_EMPTY = 0, 1, 2, 3

-- built-in textures that can be written as an index instead of a path. append only.
local KNOWN_CONTENT = {
	"rbxasset://textures/sky/sky512_bk.tex",
	"rbxasset://textures/sky/sky512_dn.tex",
	"rbxasset://textures/sky/sky512_ft.tex",
	"rbxasset://textures/sky/sky512_lf.tex",
	"rbxasset://textures/sky/sky512_rt.tex",
	"rbxasset://textures/sky/sky512_up.tex",
	"rbxasset://sky/sun.jpg",
	"rbxasset://sky/moon.jpg",
}
local KNOWN_BITS = 5

type Writer = { data: buffer, bit: number }
type Reader = { data: buffer, bit: number, size: number }

local function bitsFor(count: number): number
	local bits = 1
	while 2 ^ bits < count do
		bits += 1
	end
	return bits
end

local function write(writer: Writer, value: number, count: number)
	for i = count - 1, 0, -1 do
		local byte = writer.bit // 8
		if byte >= buffer.len(writer.data) then
			local grown = buffer.create(buffer.len(writer.data) * 2)
			buffer.copy(grown, 0, writer.data)
			writer.data = grown
		end
		if bit32.extract(value, i, 1) == 1 then
			buffer.writeu8(writer.data, byte, bit32.bor(buffer.readu8(writer.data, byte), bit32.lshift(1, 7 - writer.bit % 8)))
		end
		writer.bit += 1
	end
end

local function read(reader: Reader, count: number): number
	local value = 0
	for _ = 1, count do
		if reader.bit >= reader.size then
			error("the code ends early", 0)
		end
		local byte = buffer.readu8(reader.data, reader.bit // 8)
		value = value * 2 + bit32.extract(byte, 7 - reader.bit % 8, 1)
		reader.bit += 1
	end
	return value
end

-- LEB128: 7 bits per byte, low bits first, high bit set while more follow. safe up to 2^53.
local function writeVarint(writer: Writer, value: number)
	repeat
		local low = value % 128
		value = value // 128
		write(writer, if value > 0 then low + 128 else low, 8)
	until value == 0
end

local function readVarint(reader: Reader): number
	local value, scale = 0, 1
	for _ = 1, 8 do
		local byte = read(reader, 8)
		value += (byte % 128) * scale
		if byte < 128 then
			return value
		end
		scale *= 128
	end
	error("an asset id is too long", 0)
end

local function steps(field: Schema.Field): number
	return math.round(((field.max :: number) - (field.min :: number)) / (field.step :: number))
end

local function writeNumber(writer: Writer, field: Schema.Field, value: number)
	local count = steps(field)
	local q = math.clamp(math.round((value - (field.min :: number)) / (field.step :: number)), 0, count)
	write(writer, q, bitsFor(count + 1))
end

local function readNumber(reader: Reader, field: Schema.Field): number
	local count = steps(field)
	local q = read(reader, bitsFor(count + 1))
	if q > count then
		error(`{field.name} is out of range`, 0)
	end
	-- trims float noise such as 0.30000000000000004.
	return tonumber(string.format("%.6f", (field.min :: number) + q * (field.step :: number))) :: number
end

-- asset urls in either form come back as rbxassetid://.
local function assetId(value: string): number?
	local id = string.match(value, "^rbxassetid://(%d+)$")
		or string.match(value, "^https?://www%.roblox%.com/asset/%?id=(%d+)$")
		or string.match(value, "^https?://assetdelivery%.roblox%.com/v1/asset/%?id=(%d+)$")
	local number = if id and #id <= 15 then tonumber(id) else nil
	return number
end

local function writeContent(writer: Writer, value: string)
	local id = assetId(value)
	local known = table.find(KNOWN_CONTENT, value)
	if value == "" then
		write(writer, CONTENT_EMPTY, 2)
	elseif id then
		write(writer, CONTENT_ASSET, 2)
		writeVarint(writer, id)
	elseif known then
		write(writer, CONTENT_KNOWN, 2)
		write(writer, known - 1, KNOWN_BITS)
	else
		write(writer, CONTENT_STRING, 2)
		writeVarint(writer, #value)
		for i = 1, #value do
			write(writer, string.byte(value, i), 8)
		end
	end
end

local function readContent(reader: Reader): string
	local tag = read(reader, 2)
	if tag == CONTENT_EMPTY then
		return ""
	elseif tag == CONTENT_ASSET then
		return `rbxassetid://{readVarint(reader)}`
	elseif tag == CONTENT_KNOWN then
		local known = KNOWN_CONTENT[read(reader, KNOWN_BITS) + 1]
		if known == nil then
			error("the code uses an unknown texture", 0)
		end
		return known
	end
	local length = readVarint(reader)
	if length > 1024 then
		error("a texture path is too long", 0)
	end
	local bytes = table.create(length)
	for i = 1, length do
		bytes[i] = string.char(read(reader, 8))
	end
	return table.concat(bytes)
end

local function writeField(writer: Writer, field: Schema.Field, value: any)
	if value == nil or not Schema.valid(field, value) or Schema.equal(field, value, field.default) then
		write(writer, 0, 1)
		return
	end
	write(writer, 1, 1)
	if field.kind == "color" then
		for i = 1, 3 do
			write(writer, math.clamp(math.round(value[i] * 255), 0, 255), 8)
		end
	elseif field.kind == "number" then
		writeNumber(writer, field, value)
	elseif field.kind == "vector3" then
		for i = 1, 3 do
			writeNumber(writer, field, value[i])
		end
	elseif field.kind == "enum" then
		local items = field.items :: { string }
		write(writer, (table.find(items, value) :: number) - 1, bitsFor(#items))
	elseif field.kind == "content" then
		writeContent(writer, value)
	end
end

local function readField(reader: Reader, field: Schema.Field): any
	if read(reader, 1) == 0 then
		return if type(field.default) == "table" then table.clone(field.default) else field.default
	end
	if field.kind == "bool" then
		return not field.default
	elseif field.kind == "color" then
		return { read(reader, 8) / 255, read(reader, 8) / 255, read(reader, 8) / 255 }
	elseif field.kind == "number" then
		return readNumber(reader, field)
	elseif field.kind == "vector3" then
		return { readNumber(reader, field), readNumber(reader, field), readNumber(reader, field) }
	elseif field.kind == "enum" then
		local items = field.items :: { string }
		local item = items[read(reader, bitsFor(#items)) + 1]
		if item == nil then
			error(`{field.name} has an unknown value`, 0)
		end
		return item
	end
	return readContent(reader)
end

local Codec = {}

Codec.PREFIX = PREFIX

function Codec.encode(data: Schema.Data): string
	local writer: Writer = { data = buffer.create(32), bit = 0 }
	write(writer, Schema.VERSION, 4)
	for _, field in Schema.lighting.fields do
		writeField(writer, field, data.lighting[field.name])
	end
	for index = 2, #Schema.sections do
		local section = Schema.sections[index]
		local instances = {}
		for _, effect in data.effects do
			if effect.class == section.class and #instances < (if section.multiple then MAX_INSTANCES else 1) then
				table.insert(instances, effect)
			end
		end
		write(writer, if #instances > 0 then 1 else 0, 1)
		if #instances == 0 then
			continue
		end
		if section.multiple then
			write(writer, #instances - 1, 2)
		end
		for _, effect in instances do
			for _, field in section.fields do
				writeField(writer, field, effect.props[field.name])
			end
		end
	end
	local size = math.ceil(writer.bit / 8)
	local packed = buffer.create(size)
	buffer.copy(packed, 0, writer.data, 0, size)
	return PREFIX .. Base64.url(packed)
end

-- returns the preset data, or nil and a message explaining what's wrong with the code.
function Codec.decode(code: string): (Schema.Data?, string?)
	local text = string.gsub(code, "%s", "")
	if string.sub(text, 1, #PREFIX) ~= PREFIX or #text <= #PREFIX then
		return nil, `Photon codes start with "{PREFIX}".`
	end
	local packed = Base64.fromUrl(string.sub(text, #PREFIX + 1))
	if packed == nil then
		return nil, "The code has characters that don't belong in a Photon code."
	end
	local reader: Reader = { data = packed, bit = 0, size = buffer.len(packed) * 8 }
	local ok, result = pcall(function(): Schema.Data
		local version = read(reader, 4)
		if version ~= Schema.VERSION then
			error(if version > Schema.VERSION
				then "This code was made by a newer version of Photon. Update Photon to import it."
				else "This code's format isn't supported.", 0)
		end
		local lighting = {}
		for _, field in Schema.lighting.fields do
			lighting[field.name] = readField(reader, field)
		end
		local effects = {}
		for index = 2, #Schema.sections do
			local section = Schema.sections[index]
			if read(reader, 1) == 0 then
				continue
			end
			local count = if section.multiple then read(reader, 2) + 1 else 1
			for _ = 1, count do
				local props = {}
				for _, field in section.fields do
					props[field.name] = readField(reader, field)
				end
				table.insert(effects, { class = section.class, name = section.name, props = props })
			end
		end
		-- whatever is left must be the zero padding of the last byte.
		if reader.size - reader.bit >= 8 then
			error("the code has extra data at the end", 0)
		end
		return { version = Schema.VERSION, lighting = lighting, effects = effects }
	end)
	if not ok then
		return nil, `Invalid code: {(string.gsub(tostring(result), "%.$", ""))}.`
	end
	return result, nil
end

return Codec
