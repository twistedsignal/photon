--!strict
-- reads the lighting in a place into preset data, and writes preset data back.
-- only instances whose class is in the Schema are touched; scripts, lights and anything else
-- parented to Lighting stay where they are.
local Schema = require("./Schema")

local Snapshot = {}

local function terrainOf(): Instance?
	local ok, terrain = pcall(function()
		return (workspace :: any).Terrain
	end)
	return if ok then terrain else nil
end

-- the instances a preset replaces, in Schema section order.
function Snapshot.managed(lighting: Instance, terrain: Instance?): { Instance }
	local list = {}
	for index = 2, #Schema.sections do
		local section = Schema.sections[index]
		local parent = if section.parent == "Terrain" then terrain else lighting
		if parent == nil then
			continue
		end
		for _, child in parent:GetChildren() do
			if child.ClassName == section.class then
				table.insert(list, child)
			end
		end
	end
	return list
end

function Snapshot.readEffect(instance: Instance): Schema.Effect?
	local section = Schema.byClass[instance.ClassName]
	if section == nil or section == Schema.lighting then
		return nil
	end
	local props = {}
	for _, field in section.fields do
		local ok, value = pcall(Schema.read, instance, field)
		if ok then
			props[field.name] = value
		end
	end
	return { class = section.class, name = instance.Name, props = props }
end

function Snapshot.capture(lighting: Instance?, terrain: Instance?): Schema.Data
	local source = lighting or (game :: any):GetService("Lighting")
	local clouds = terrain or terrainOf()
	local values = {}
	for _, field in Schema.lighting.fields do
		local ok, value = pcall(Schema.read, source, field)
		if ok then
			values[field.name] = value
		end
	end
	local effects = {}
	for _, instance in Snapshot.managed(source, clouds) do
		table.insert(effects, Snapshot.readEffect(instance) :: Schema.Effect)
	end
	return { version = Schema.VERSION, lighting = values, effects = effects }
end

-- writes one effect's properties onto an instance of its class.
function Snapshot.writeEffect(instance: Instance, effect: Schema.Effect)
	local section = Schema.byClass[effect.class]
	for _, field in section.fields do
		local value = effect.props[field.name]
		if value ~= nil then
			pcall(Schema.write, instance, field, value)
		end
	end
end

function Snapshot.build(effect: Schema.Effect): Instance
	local instance = Instance.new(effect.class)
	instance.Name = effect.name
	Snapshot.writeEffect(instance, effect)
	return instance
end

function Snapshot.writeLighting(lighting: Instance, values: { [string]: any })
	for _, field in Schema.lighting.fields do
		local value = values[field.name]
		if value ~= nil then
			pcall(Schema.write, lighting, field, value)
		end
	end
end

-- replaces the place's lighting with the preset, instantly. old effects are destroyed unless
-- detach is set; inside a Studio change-history recording pass detach, because undo and
-- cancelled recordings can't bring back a destroyed instance.
function Snapshot.apply(data: Schema.Data, lighting: Instance?, terrain: Instance?, detach: boolean?)
	local target = lighting or (game :: any):GetService("Lighting")
	local clouds = terrain or terrainOf()
	Snapshot.writeLighting(target, data.lighting)
	for _, instance in Snapshot.managed(target, clouds) do
		if detach then
			instance.Parent = nil
		else
			instance:Destroy()
		end
	end
	for _, effect in data.effects do
		local section = Schema.byClass[effect.class]
		local parent = if section.parent == "Terrain" then clouds else target
		if parent then
			Snapshot.build(effect).Parent = parent
		end
	end
end

-- validates data from storage or another plugin version. unknown classes, unknown
-- properties and malformed values are dropped instead of erroring later.
function Snapshot.clean(data: any): Schema.Data?
	if type(data) ~= "table" or type(data.lighting) ~= "table" or type(data.effects) ~= "table" then
		return nil
	end
	local values = {}
	for _, field in Schema.lighting.fields do
		local value = data.lighting[field.name]
		if value ~= nil and Schema.valid(field, value) then
			values[field.name] = value
		end
	end
	local effects = {}
	for _, effect in data.effects do
		local section = if type(effect) == "table" and type(effect.class) == "string"
			then Schema.byClass[effect.class]
			else nil
		if section == nil or section == Schema.lighting or type(effect.props) ~= "table" then
			continue
		end
		local props = {}
		for _, field in section.fields do
			local value = effect.props[field.name]
			if value ~= nil and Schema.valid(field, value) then
				props[field.name] = value
			end
		end
		local name = if type(effect.name) == "string" and effect.name ~= "" then effect.name else section.name
		table.insert(effects, { class = section.class, name = string.sub(name, 1, 100), props = props })
	end
	return { version = Schema.VERSION, lighting = values, effects = effects }
end

return Snapshot
