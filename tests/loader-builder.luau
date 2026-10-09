-- Every selectable function must work independently, without leaking unselected APIs.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Schema = require("../src/Loader/Schema")
local Codec = require("../src/Loader/Codec")
local Sources = luau.load(fs.readFile("src/Generated/LoaderSources.luau"))()
local Builder = luau.load(fs.readFile("src/LoaderBuilder.luau"):gsub("(\n%s*)const%s+", "%1local "), {
	environment = setmetatable({require = function(path)
		assert(path == "./Generated/LoaderSources")
		return Sources
	end}, {__index = getfenv(1)}),
})()
local lighting = roblox.Instance.new("Lighting")
local workspace = roblox.Instance.new("Folder")
local module = roblox.Instance.new("ModuleScript")
local parent = roblox.Instance.new("Folder")
module.Parent = parent
local environment = setmetatable({
	Instance = roblox.Instance, Color3 = roblox.Color3, Vector3 = roblox.Vector3,
	Enum = roblox.Enum, script = module, workspace = workspace,
	game = { GetService = function(_, name)
		if name == "Lighting" then return lighting end
		if name == "TweenService" then return {} end
		error("Service unavailable: " .. name)
	end },
}, {__index = getfenv(1)})
local data = {version = Schema.VERSION, lighting = {Brightness = 2.5}, effects = {
	{class = "BlurEffect", name = "Blur", props = {Size = 4}},
}}
local code = Codec.encode(data)
local count = 0
for _, casing in {"PascalCase", "camelCase", "snake_case", "UPPER_CASE"} do
	for _, binding in {"const", "local"} do
		for _, types in {true, false} do
			local configurations = {Builder.defaults(), {features = {}, casing = casing, binding = binding, types = types}}
			for _, feature in Builder.features do
				configurations[2].features[feature.id] = true
				table.insert(configurations, {features = {[feature.id] = true}, casing = casing, binding = binding, types = types})
			end
			for _, options in configurations do
				local generated = Builder.generate(options)
				assert(not generated:find('require%('), "generated module needs child modules")
				if not options.types then
					assert(not generated:find("export type", 1, true) and not generated:find("::", 1, true), "untyped source contains annotations")
				end
				if options.binding == "local" then
					assert(not generated:find("%f[%w]const%f[%W]"), "local variant contains const")
				else
					assert(generated:find("const Runtime", 1, true), "const variant wasn't generated")
				end
				local runtime = luau.load(generated:gsub("(\n%s*)const%s+", "%1local "), {environment = environment})()
				local expected = 0
				for _, feature in Builder.features do
					local key = Builder.memberName(feature.id, options.casing)
					assert((type(runtime[key]) == "function") == (options.features[feature.id] == true), key .. " has incorrect visibility")
					if options.features[feature.id] then expected += 1 end
				end
				local actual = 0
				for _ in runtime do actual += 1 end
				assert(actual == expected, "hidden helpers leaked into public API")
				local function method(name) return runtime[Builder.memberName(name, options.casing)] end
				if method("encode") then assert(method("encode")(data) == code) end
				if method("decode") then assert(Codec.encode(assert(method("decode")(code))) == code) end
				if method("resolve") then assert(Codec.encode(assert(method("resolve")(code))) == code) end
				if method("load") then method("load")(data) end
				if method("apply") then method("apply")(data) end
				if method("capture") then assert(method("capture")().lighting.Brightness == lighting.Brightness) end
				if method("stop") then method("stop")() end
				if method("toFolder") and method("fromFolder") then
					local folder = method("toFolder")(data, "Example")
					assert(Codec.encode(method("fromFolder")(folder)) == code)
					folder.Parent = parent
					if method("list") then assert(method("list")(parent)[1] == "Example") end
					if method("setPresets") then
						method("setPresets")(parent)
						assert(method("list")()[1] == "Example")
					end
					if method("load") then method("load")("Example", nil, parent) end
					folder:Destroy()
				end
				count += 1
			end
		end
	end
end
assert(Builder.problem(Builder.clean({features = {}})) ~= nil)
local default = Builder.defaults()
assert(default.casing == "PascalCase" and default.binding == "const" and default.types and default.features.load)
assert(Builder.memberName("toFolder", "snake_case") == "to_folder")
print(`loader builder: {count} configurations compiled, API visibility and independent functions passed`)
