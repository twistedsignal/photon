--!strict
-- every lighting property Photon saves. Snapshot, Codec and Template all read this table.
-- values are kept JSON-safe so presets can be stored in plugin settings:
--   color   {r, g, b} in 0..1
--   vector3 {x, y, z}
--   enum    the item's name
--   content the asset url string
-- share codes depend on the order of sections and fields: only ever append to them.

export type Kind = "color" | "number" | "bool" | "enum" | "vector3" | "content"

export type Field = {
	name: string,
	kind: Kind,
	-- the codec only writes values that differ from this.
	default: any,
	min: number?,
	max: number?,
	step: number?,
	-- enum fields: the Enum's name and its items in codec order.
	enum: string?,
	items: { string }?,
}

export type Section = {
	key: string,
	class: string,
	-- where the instance lives in a place.
	parent: "Lighting" | "Terrain",
	-- the Name a new instance gets.
	name: string,
	-- whether a place can have more than one, like stacked color corrections.
	multiple: boolean,
	fields: { Field },
}

local function color(name: string, r: number, g: number, b: number): Field
	return { name = name, kind = "color", default = { r / 255, g / 255, b / 255 } }
end

local function number(name: string, default: number, min: number, max: number, step: number): Field
	return { name = name, kind = "number", default = default, min = min, max = max, step = step }
end

local function bool(name: string, default: boolean): Field
	return { name = name, kind = "bool", default = default }
end

local function content(name: string, default: string): Field
	return { name = name, kind = "content", default = default }
end

local function enum(name: string, enumName: string, items: { string }): Field
	return { name = name, kind = "enum", default = items[1], enum = enumName, items = items }
end

local function vector3(name: string, min: number, max: number, step: number): Field
	return { name = name, kind = "vector3", default = { 0, 0, 0 }, min = min, max = max, step = step }
end

local SKY = "rbxasset://textures/sky/sky512_"

-- the Lighting service itself. Lighting.Technology is left out: scripts can't read it.
local lighting: Section = {
	key = "Lighting",
	class = "Lighting",
	parent = "Lighting",
	name = "Lighting",
	multiple = false,
	fields = {
		color("Ambient", 0, 0, 0),
		number("Brightness", 2, 0, 10, 0.01),
		color("ColorShift_Bottom", 0, 0, 0),
		color("ColorShift_Top", 0, 0, 0),
		number("EnvironmentDiffuseScale", 1, 0, 1, 0.001),
		number("EnvironmentSpecularScale", 1, 0, 1, 0.001),
		bool("GlobalShadows", true),
		color("OutdoorAmbient", 128, 128, 128),
		number("ShadowSoftness", 0.2, 0, 1, 0.01),
		number("ClockTime", 14.5, 0, 24, 1 / 60),
		number("GeographicLatitude", 0, -360, 360, 0.1),
		number("ExposureCompensation", 0, -3, 3, 0.01),
		color("FogColor", 192, 192, 192),
		number("FogEnd", 100000, 0, 100000, 1),
		number("FogStart", 0, 0, 100000, 1),
		enum("LightingStyle", "LightingStyle", { "Realistic", "Soft" }),
		bool("PrioritizeLightingQuality", true),
	},
}

local sections: { Section } = {
	lighting,
	{
		key = "Sky",
		class = "Sky",
		parent = "Lighting",
		name = "Sky",
		multiple = false,
		fields = {
			content("SkyboxBk", SKY .. "bk.tex"),
			content("SkyboxDn", SKY .. "dn.tex"),
			content("SkyboxFt", SKY .. "ft.tex"),
			content("SkyboxLf", SKY .. "lf.tex"),
			content("SkyboxRt", SKY .. "rt.tex"),
			content("SkyboxUp", SKY .. "up.tex"),
			content("SunTextureId", "rbxasset://sky/sun.jpg"),
			content("MoonTextureId", "rbxasset://sky/moon.jpg"),
			number("SunAngularSize", 21, 0, 60, 0.1),
			number("MoonAngularSize", 11, 0, 60, 0.1),
			number("StarCount", 3000, 0, 5000, 1),
			bool("CelestialBodiesShown", true),
			vector3("SkyboxOrientation", -360, 360, 0.1),
		},
	},
	{
		key = "Atmosphere",
		class = "Atmosphere",
		parent = "Lighting",
		name = "Atmosphere",
		multiple = false,
		fields = {
			number("Density", 0.395, 0, 1, 0.001),
			number("Offset", 0, 0, 1, 0.001),
			color("Color", 200, 170, 108),
			color("Decay", 92, 60, 14),
			number("Glare", 0, 0, 10, 0.01),
			number("Haze", 0, 0, 10, 0.01),
		},
	},
	{
		key = "Clouds",
		class = "Clouds",
		parent = "Terrain",
		name = "Clouds",
		multiple = false,
		fields = {
			bool("Enabled", true),
			number("Cover", 0.5, 0, 1, 0.001),
			number("Density", 0.7, 0, 1, 0.001),
			color("Color", 255, 255, 255),
		},
	},
	{
		key = "Bloom",
		class = "BloomEffect",
		parent = "Lighting",
		name = "Bloom",
		multiple = true,
		fields = {
			bool("Enabled", true),
			number("Intensity", 0.4, 0, 10, 0.01),
			number("Size", 24, 0, 56, 1),
			number("Threshold", 0.95, 0, 10, 0.01),
		},
	},
	{
		key = "Blur",
		class = "BlurEffect",
		parent = "Lighting",
		name = "Blur",
		multiple = true,
		fields = {
			bool("Enabled", true),
			number("Size", 24, 0, 56, 0.1),
		},
	},
	{
		key = "ColorCorrection",
		class = "ColorCorrectionEffect",
		parent = "Lighting",
		name = "ColorCorrection",
		multiple = true,
		fields = {
			bool("Enabled", true),
			number("Brightness", 0, -5, 5, 0.001),
			number("Contrast", 0, -5, 5, 0.001),
			number("Saturation", 0, -5, 5, 0.001),
			color("TintColor", 255, 255, 255),
		},
	},
	{
		key = "ColorGrading",
		class = "ColorGradingEffect",
		parent = "Lighting",
		name = "ColorGrading",
		multiple = false,
		fields = {
			bool("Enabled", true),
			enum("TonemapperPreset", "TonemapperPreset", { "Default", "Retro" }),
		},
	},
	{
		key = "DepthOfField",
		class = "DepthOfFieldEffect",
		parent = "Lighting",
		name = "DepthOfField",
		multiple = true,
		fields = {
			bool("Enabled", true),
			number("FarIntensity", 0.75, 0, 1, 0.001),
			number("FocusDistance", 0.05, 0, 500, 0.01),
			number("InFocusRadius", 10, 0, 500, 0.01),
			number("NearIntensity", 0.75, 0, 1, 0.001),
		},
	},
	{
		key = "SunRays",
		class = "SunRaysEffect",
		parent = "Lighting",
		name = "SunRays",
		multiple = true,
		fields = {
			bool("Enabled", true),
			number("Intensity", 0.25, 0, 1, 0.001),
			number("Spread", 1, 0, 1, 0.001),
		},
	},
}

local byClass: { [string]: Section } = {}
for _, section in sections do
	byClass[section.class] = section
end

local Schema = {}

Schema.VERSION = 1
Schema.lighting = lighting
Schema.sections = sections
Schema.byClass = byClass

-- preset data: lighting holds the Lighting fields. effects lists the instances, in section order.
-- a missing lighting value means "leave it alone", so older or partial presets don't reset anything.
export type Effect = { class: string, name: string, props: { [string]: any } }
export type Data = { version: number, lighting: { [string]: any }, effects: { Effect } }

-- an instance property as a JSON-safe value.
function Schema.read(instance: Instance, field: Field): any
	local value = (instance :: any)[field.name]
	if field.kind == "color" then
		return { value.R, value.G, value.B }
	elseif field.kind == "vector3" then
		return { value.X, value.Y, value.Z }
	elseif field.kind == "enum" then
		return value.Name
	end
	return value
end

-- a JSON-safe value as the property's Roblox type.
function Schema.toRoblox(field: Field, value: any): any
	if field.kind == "color" then
		return Color3.new(value[1], value[2], value[3])
	elseif field.kind == "vector3" then
		return Vector3.new(value[1], value[2], value[3])
	elseif field.kind == "enum" then
		return (Enum :: any)[field.enum][value]
	end
	return value
end

function Schema.write(instance: Instance, field: Field, value: any)
	(instance :: any)[field.name] = Schema.toRoblox(field, value)
end

-- whether a value can be tweened by TweenService.
function Schema.tweenable(field: Field): boolean
	return field.kind == "color" or field.kind == "number" or field.kind == "vector3"
end

-- compares two values the way a share code would see them.
function Schema.equal(field: Field, a: any, b: any): boolean
	if field.kind == "color" then
		-- within half an 8-bit step; Color3 stores float32, so exact rounding can flip.
		for i = 1, 3 do
			if math.abs(a[i] - b[i]) * 255 >= 0.5 + 1e-4 then
				return false
			end
		end
		return true
	elseif field.kind == "vector3" then
		local step = field.step :: number
		for i = 1, 3 do
			if math.abs(a[i] - b[i]) >= step / 2 then
				return false
			end
		end
		return true
	elseif field.kind == "number" then
		return math.abs(a - b) < (field.step :: number) / 2
	end
	return a == b
end

-- a section's fields filled with defaults.
function Schema.defaults(section: Section): { [string]: any }
	local props = {}
	for _, field in section.fields do
		props[field.name] = if type(field.default) == "table" then table.clone(field.default) else field.default
	end
	return props
end

-- checks a stored value has the right shape, so bad data can't reach a property write.
function Schema.valid(field: Field, value: any): boolean
	if field.kind == "color" or field.kind == "vector3" then
		return type(value) == "table" and type(value[1]) == "number" and type(value[2]) == "number"
			and type(value[3]) == "number"
	elseif field.kind == "number" then
		return type(value) == "number" and value == value
	elseif field.kind == "bool" then
		return type(value) == "boolean"
	elseif field.kind == "enum" then
		return type(value) == "string" and table.find(field.items :: { string }, value) ~= nil
	end
	return type(value) == "string"
end

return Schema
