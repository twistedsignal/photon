--!strict
-- presets as editable instances:
--   Folder <preset name>
--     Ambient (Color3Value), Brightness (NumberValue), ... one value per Lighting property
--     child (Folder)
--       Sky, Atmosphere, Clouds, ColorCorrection, ... configured effect instances
-- a value or effect can be edited, removed or added in Studio. a missing Lighting value
-- leaves that property alone when the preset loads.
local Schema = require("./Schema")
local Snapshot = require("./Snapshot")

local CHILD = "child"

local VALUE_CLASS: { [Schema.Kind]: string } = {
	color = "Color3Value",
	number = "NumberValue",
	bool = "BoolValue",
	enum = "StringValue",
	vector3 = "Vector3Value",
	content = "StringValue",
}

local Template = {}

Template.CHILD = CHILD

function Template.toFolder(data: Schema.Data, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	for _, field in Schema.lighting.fields do
		local value = data.lighting[field.name]
		if value == nil then
			continue
		end
		local object = Instance.new(VALUE_CLASS[field.kind]) :: any
		object.Name = field.name
		object.Value = if field.kind == "enum" then value else Schema.toRoblox(field, value)
		object.Parent = folder
	end
	local child = Instance.new("Folder")
	child.Name = CHILD
	for _, effect in data.effects do
		Snapshot.build(effect).Parent = child
	end
	child.Parent = folder
	return folder
end

-- whether an instance looks like a preset folder.
function Template.isPreset(instance: Instance): boolean
	return instance:IsA("Folder") and instance:FindFirstChild(CHILD) ~= nil
end

function Template.fromFolder(folder: Instance): Schema.Data
	local values = {}
	for _, field in Schema.lighting.fields do
		local object = folder:FindFirstChild(field.name)
		if object == nil or object.ClassName ~= VALUE_CLASS[field.kind] then
			continue
		end
		local raw = (object :: any).Value
		local value = if field.kind == "color"
			then { raw.R, raw.G, raw.B }
			elseif field.kind == "vector3" then { raw.X, raw.Y, raw.Z }
			else raw
		if Schema.valid(field, value) then
			values[field.name] = value
		end
	end
	local effects = {}
	local child = folder:FindFirstChild(CHILD)
	if child then
		for index = 2, #Schema.sections do
			local section = Schema.sections[index]
			for _, instance in child:GetChildren() do
				if instance.ClassName == section.class then
					table.insert(effects, Snapshot.readEffect(instance) :: Schema.Effect)
				end
			end
		end
	end
	return { version = Schema.VERSION, lighting = values, effects = effects }
end

return Template
