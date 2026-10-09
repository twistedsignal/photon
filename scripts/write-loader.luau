-- The standalone release asset uses the same defaults as the Insert loader popup.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local sources = luau.load(fs.readFile("src/Generated/LoaderSources.luau"))()
local builderSource = "\n" .. fs.readFile("src/LoaderBuilder.luau")
builderSource = builderSource:gsub("(\n%s*)const%s+", "%1local ")
local Builder = luau.load(builderSource, {
	environment = setmetatable({require = function(path)
		assert(path == "./Generated/LoaderSources")
		return sources
	end}, {__index = getfenv(1)}),
})()
fs.writeFile("build/DefaultLoader.luau", Builder.generate(Builder.defaults()))
print("Generated standalone loader with default options")
