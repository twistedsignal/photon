--!strict
-- Photon lighting loader. MIT License, Copyright (c) 2026 Twisted Signal.
-- https://github.com/twistedsignal/photon
--
--   local Photon = require(game.ReplicatedStorage.Photon.Loader)
--   Photon.load("Golden Hour")                          -- a preset in the Presets folder
--   Photon.load("Golden Hour", TweenInfo.new(2))        -- tween to it over 2 seconds
--   Photon.load("PHEB4...")                             -- a share code
--   Photon.load(somePresetFolder)                       -- any preset folder
--
-- works from the server (everyone sees it) or a LocalScript (only that player).
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Schema = require("@self/Schema")
local Codec = require("@self/Codec")
local Snapshot = require("@self/Snapshot")
local Template = require("@self/Template")

export type Data = Schema.Data
export type Target = string | Instance | Data

local Photon = {}

Photon.Schema = Schema
Photon.Codec = Codec
Photon.Snapshot = Snapshot
Photon.Template = Template

-- tweens and connections from the last load, stopped when another load starts.
local active: { Tween } = {}
local connections: { RBXScriptConnection } = {}

local function stop()
	for _, tween in active do
		tween:Cancel()
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(active)
	table.clear(connections)
end

local function play(instance: Instance, info: TweenInfo, goals: { [string]: any })
	if next(goals) == nil then
		return
	end
	local tween = TweenService:Create(instance, info, goals)
	table.insert(active, tween)
	tween:Play()
end

-- ClockTime tweens the short way around midnight instead of rewinding through the day.
local function tweenClock(target: number, info: TweenInfo)
	local start = Lighting.ClockTime
	local goal = target
	if goal - start > 12 then
		goal -= 24
	elseif start - goal > 12 then
		goal += 24
	end
	local value = Instance.new("NumberValue")
	value.Value = start
	table.insert(connections, value.Changed:Connect(function(current: number)
		Lighting.ClockTime = current % 24
	end))
	local tween = TweenService:Create(value, info, { Value = goal })
	table.insert(active, tween)
	tween.Completed:Once(function()
		value:Destroy()
	end)
	tween:Play()
end

-- sets every property, tweening the ones that can be when info is given.
local function transition(instance: Instance, fields: { Schema.Field }, values: { [string]: any }, info: TweenInfo?)
	local goals = {}
	for _, field in fields do
		local value = values[field.name]
		if value == nil or not Schema.valid(field, value) then
			continue
		end
		if info and Schema.tweenable(field) then
			if instance == Lighting and field.name == "ClockTime" then
				tweenClock(value, info)
			else
				goals[field.name] = Schema.toRoblox(field, value)
			end
		else
			pcall(Schema.write, instance, field, value)
		end
	end
	if info then
		play(instance, info, goals)
	end
end

local function presets(): Instance?
	local parent = script.Parent
	return if parent then parent:FindFirstChild("Presets") else nil
end

-- turns a preset name, folder, share code or data table into preset data.
function Photon.resolve(target: Target): (Data?, string?)
	if type(target) == "table" then
		return Snapshot.clean(target), nil
	elseif typeof(target) == "Instance" then
		if not Template.isPreset(target) then
			return nil, `{target:GetFullName()} isn't a Photon preset folder`
		end
		return Template.fromFolder(target), nil
	elseif type(target) == "string" then
		local folder = presets()
		local preset = if folder then folder:FindFirstChild(target) else nil
		if preset and Template.isPreset(preset) then
			return Template.fromFolder(preset), nil
		end
		if string.sub(target, 1, #Codec.PREFIX) == Codec.PREFIX then
			return Codec.decode(target)
		end
		return nil, `There's no preset named "{target}"`
	end
	return nil, "Photon.load expects a preset name, folder, share code or data table"
end

-- loads a preset. without tweenInfo it applies instantly.
function Photon.load(target: Target, tweenInfo: TweenInfo?)
	local data, problem = Photon.resolve(target)
	if data == nil then
		error(`Photon: {problem}`, 2)
	end
	Photon.apply(data, tweenInfo)
end

function Photon.apply(data: Data, tweenInfo: TweenInfo?)
	stop()
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	transition(Lighting, Schema.lighting.fields, data.lighting, tweenInfo)

	-- reuse instances of the same class in order, so effects tween instead of popping.
	local existing: { [string]: { Instance } } = {}
	for _, instance in Snapshot.managed(Lighting, terrain) do
		existing[instance.ClassName] = existing[instance.ClassName] or {}
		table.insert(existing[instance.ClassName], instance)
	end
	for _, effect in data.effects do
		local section = Schema.byClass[effect.class]
		local pool = existing[effect.class]
		local instance = if pool then table.remove(pool, 1) else nil
		if instance then
			instance.Name = effect.name
			transition(instance, section.fields, effect.props, tweenInfo)
		else
			local parent = if section.parent == "Terrain" then terrain else Lighting
			if parent then
				Snapshot.build(effect).Parent = parent
			end
		end
	end
	for _, pool in existing do
		for _, instance in pool do
			instance:Destroy()
		end
	end
end

-- names of the presets in the Presets folder next to this module.
function Photon.list(): { string }
	local names = {}
	local folder = presets()
	if folder then
		for _, child in folder:GetChildren() do
			if Template.isPreset(child) then
				table.insert(names, child.Name)
			end
		end
	end
	table.sort(names)
	return names
end

-- the place's current lighting as preset data.
function Photon.capture(): Data
	return Snapshot.capture(Lighting, workspace:FindFirstChildOfClass("Terrain"))
end

function Photon.encode(data: Data): string
	return Codec.encode(data)
end

function Photon.decode(code: string): (Data?, string?)
	return Codec.decode(code)
end

return Photon
