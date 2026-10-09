-- Configurable, self-contained runtime modules. The selected API is the entire public table.
const Sources = require("./Generated/LoaderSources")

const Builder = {}

export type Options = {
	features: { [string]: boolean },
	casing: "PascalCase" | "camelCase" | "snake_case" | "UPPER_CASE",
	binding: "const" | "local",
	types: boolean,
}

Builder.features = {
	{ id = "load", description = "Load a name, preset folder, share code or data table. Supports TweenInfo." },
	{ id = "apply", description = "Apply a preset data table directly, with an optional TweenInfo." },
	{ id = "list", description = "List names in a preset container you pass in." },
	{ id = "capture", description = "Read the current Lighting and effects into a data table." },
	{ id = "encode", description = "Turn a preset data table into a PH share code." },
	{ id = "decode", description = "Read a PH share code into a data table." },
	{ id = "resolve", description = "Read a name, folder or code as data without applying it." },
	{ id = "toFolder", description = "Create an editable preset Folder from a data table." },
	{ id = "fromFolder", description = "Read an editable preset Folder into a data table." },
	{ id = "stop", description = "Cancel the lighting tweens started by this module." },
	{ id = "setPresets", description = "Set a preset container anywhere in the game for name lookups." },
}

const dependencies = {
	["api:load"] = { "api:resolve", "api:apply" },
	["api:apply"] = { "stop", "transition", "Schema", "Snapshot" },
	["api:list"] = { "presets", "Template" },
	["api:capture"] = { "Snapshot" },
	["api:encode"] = { "Codec" },
	["api:decode"] = { "Codec" },
	["api:resolve"] = { "presets", "Snapshot", "Template", "Codec" },
	["api:toFolder"] = { "Template" },
	["api:fromFolder"] = { "Template" },
	["api:stop"] = { "stop" },
	transition = { "play", "tweenClock", "Schema" },
	Snapshot = { "Schema" },
	Template = { "Schema", "Snapshot" },
	Codec = { "Schema", "Base64" },
}
const modules = { "Schema", "Base64", "Codec", "Snapshot", "Template" }
const functions = {
	"stop", "play", "tweenClock", "transition", "presets", "api:resolve", "api:load",
	"api:apply", "api:list", "api:capture", "api:encode", "api:decode", "api:toFolder",
	"api:fromFolder", "api:stop", "api:setPresets",
}

function Builder.defaults(): Options
	return { features = { load = true }, casing = "PascalCase", binding = "const", types = true }
end

function Builder.clean(value: any): Options
	const result = Builder.defaults()
	if type(value) ~= "table" then
		return result
	end
	if type(value.features) == "table" then
		result.features = {}
		for _, feature in Builder.features do
			result.features[feature.id] = value.features[feature.id] == true
		end
	end
	if value.casing == "PascalCase" or value.casing == "camelCase" or value.casing == "snake_case" or value.casing == "UPPER_CASE" then
		result.casing = value.casing
	end
	if value.binding == "local" or value.binding == "const" then
		result.binding = value.binding
	end
	if type(value.types) == "boolean" then
		result.types = value.types
	end
	return result
end

function Builder.memberName(name: string, casing: string): string
	if casing == "PascalCase" then
		return string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
	elseif casing == "snake_case" or casing == "UPPER_CASE" then
		const snake = string.gsub(name, "(%l)(%u)", "%1_%2")
		return if casing == "UPPER_CASE" then string.upper(snake) else string.lower(snake)
	end
	return name
end

function Builder.problem(options: Options): string?
	for _, feature in Builder.features do
		if options.features[feature.id] then
			return nil
		end
	end
	return "Choose at least one function."
end

const function indent(code: string): string
	return "\t" .. string.gsub(string.gsub(code, "\n$", ""), "\n", "\n\t") .. "\n"
end

function Builder.generate(value: Options): string
	const options = Builder.clean(value)
	assert(Builder.problem(options) == nil, "Choose at least one function.")
	const variant = (if options.types then "typed" else "plain") .. (if options.binding == "const" then "Const" else "Local")
	const included: { [string]: boolean } = {}
	const function include(id: string)
		if included[id] then
			return
		end
		included[id] = true
		for _, dependency in dependencies[id] or {} do
			include(dependency)
		end
	end
	for _, feature in Builder.features do
		if options.features[feature.id] then
			include("api:" .. feature.id)
		end
	end
	const output = {
		if options.types then "--!strict" else "--!nocheck",
		"-- Photon lighting loader. MIT License, Twisted Signal.\n-- This module can live anywhere. Pass a preset Folder, data table, share code, or an explicit preset container.\n",
	}
	if options.types then
		table.insert(output, Sources.types)
	end
	for _, name in modules do
		if included[name] then
			table.insert(output, `{options.binding} {name} = (function()\n{indent(Sources[name][variant])}end)()\n`)
		end
	end
	table.insert(output, `{options.binding} Runtime = (function()\n{indent(Sources.Runtime[variant])}`)
	for _, name in functions do
		if included[name] then
			table.insert(output, indent(Sources[name][variant]))
		end
	end
	table.insert(output, "\treturn Photon\nend)()\n\nreturn {")
	for _, feature in Builder.features do
		if options.features[feature.id] then
			table.insert(output, `\t{Builder.memberName(feature.id, options.casing)} = Runtime.{feature.id},`)
		end
	end
	table.insert(output, "}\n")
	return table.concat(output, "\n")
end

return Builder
