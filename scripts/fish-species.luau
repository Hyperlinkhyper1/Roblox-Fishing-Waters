-- Shared.FishSpecies for lute harnesses: loads every src/shared/Fish module.
-- `luau.load` environments see no globals, so `env` adds the standard library
-- to whatever the harness mocks and sets FishSpecies; `inline` points a
-- module's `require(script.Parent.FishSpecies)` at that global.
local fs = require("@lute/fs")
local luau = require("@lute/luau")

local FishSpecies = {}

local GLOBALS = {
	assert = assert,
	error = error,
	type = type,
	tostring = tostring,
	tonumber = tonumber,
	pairs = pairs,
	ipairs = ipairs,
	next = next,
	select = select,
	setmetatable = setmetatable,
	getmetatable = getmetatable,
	pcall = pcall,
	print = print,
	table = table,
	string = string,
	math = math,
}

-- Every species module, loaded with `env` (their Build functions run in it).
function FishSpecies.load(env: { [string]: any }?)
	local species = {}
	local dir = "src/shared/Fish"
	for _, entry in fs.listdir(dir) do
		local id = string.match(entry.name, "^(.+)%.luau$")
		if id then
			local file = fs.open(dir .. "/" .. entry.name, "r")
			local source = fs.read(file)
			fs.close(file)
			species[id] = luau.load(luau.compile(source), id, env or GLOBALS)()
		end
	end
	return species
end

function FishSpecies.env(extra: { [string]: any }): { [string]: any }
	local env = table.clone(GLOBALS)
	for key, value in extra do
		env[key] = value
	end
	env.FishSpecies = env.FishSpecies or FishSpecies.load(env)
	return env
end

function FishSpecies.inline(source: string): string
	return (string.gsub(source, "require%(script%.Parent%.FishSpecies%)", "FishSpecies"))
end

return FishSpecies
