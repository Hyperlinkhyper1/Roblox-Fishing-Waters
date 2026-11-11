-- Area banner rules (src/shared/Areas.luau): every biome and landmark has a name, subtitle and
-- accent; positions resolve to the right area; boundaries have hysteresis; stepping off a landmark
-- back into its water stays quiet. Also compiles the client banner. No Roblox runtime.
-- Run: lute run scripts/areas.luau
local fs = require("@lute/fs")
local luau = require("@lute/luau")
local Cove = require("../src/shared/PirateCove")

local function read(path: string): string
	local file = fs.open(path, "r")
	local source = fs.read(file)
	fs.close(file)
	return source
end

local vector = {}
vector.__index = vector
local function v2(x, y)
	return setmetatable({ X = x, Y = y }, vector)
end
vector.__sub = function(a, b)
	return v2(a.X - b.X, a.Y - b.Y)
end
vector.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y)
	end
	return nil
end
local env = {
	Vector2 = { new = v2 },
	Vector3 = {
		new = function(x, y, z)
			return { X = x, Y = y, Z = z }
		end,
	},
	Color3 = {
		fromRGB = function(r, g, b)
			return { r, g, b }
		end,
	},
	Enum = { Material = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	}) },
	math = math,
	string = string,
	table = table,
}
local function load(path: string, name: string, extra: { [string]: any }?)
	local scope = table.clone(env)
	for key, value in extra or {} do
		scope[key] = value
	end
	return luau.load(luau.compile(read(path)), name, scope)()
end

local Biomes = load("src/shared/Biomes.luau", "Biomes")
local Areas = load("src/shared/Areas.luau", "Areas", {
	script = { Parent = { Biomes = Biomes, PirateCove = Cove } },
	require = function(module)
		return module
	end,
})

local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

for _, path in { "src/shared/Areas.luau", "src/client/AreaBanner.luau" } do
	check(pcall(luau.load, luau.compile(read(path)), path, {}), path .. " does not compile")
end
check(
	string.find(read("src/client/init.client.luau"), '"AreaBanner"', 1, true) ~= nil,
	"AreaBanner is not started by the client"
)

local function at(x, z, current)
	return Areas.at(env.Vector3.new(x, 2, z), current)
end

-- Every biome and the open sea are announced with their own name and a subtitle.
for _, biome in Biomes.list do
	local area = Areas.Biomes[biome.id]
	check(area and area.name == biome.name, "No area for biome " .. biome.id)
	check(area.subtitle ~= "" and area.accent ~= nil, biome.id .. " has no subtitle/accent")
	check(at(biome.center.X, biome.center.Y) == area, biome.name .. " centre resolves elsewhere")
end
check(Areas.Biomes.open.name == Biomes.OpenSea.name, "Open sea uses the chart's name")
check(at(-2400, -2600) == Areas.Biomes.open, "Gap between biomes is open water")

-- Zones are biomes of their own, named and placed like the cove they cover.
local cove, city = Areas.Landmarks[1], Areas.Landmarks[2]
check(cove == Areas.Biomes.piratecove and cove.name == Cove.NAME, "Pirate Cove is a biome area")
check(cove.subtitle ~= "" and cove.accent ~= nil and cove.parent == nil, "Pirate Cove has its own banner")
check(
	Biomes.PirateCove.center.X == Cove.CENTER[1] and Biomes.PirateCove.center.Y == Cove.CENTER[2],
	"The Pirate Cove biome sits on the island"
)
check(Biomes.PirateCove.radius >= Cove.RADIUS + 60, "The Pirate Cove biome covers the island and anchorage")
check(not table.find(Biomes.list, Biomes.PirateCove), "Pirate Cove stays out of terrain generation")
check(Biomes.at(env.Vector3.new(Cove.CENTER[1], 0, Cove.CENTER[2])) == Biomes.Tropical, "Cove terrain stays tropical")
check(
	Biomes.zoneAt(env.Vector3.new(Cove.CENTER[1], 0, Cove.CENTER[2])) == Biomes.PirateCove,
	"Pirate Cove is the zone at the cove"
)
check(Biomes.zoneAt(env.Vector3.new(-1200, 0, 3000)) == Biomes.Tropical, "The rest of the Coral Shallows is tropical")
check(Biomes.zoneAt(env.Vector3.new(0, 0, 0)) == Biomes.Normal, "Zones leave other biomes alone")

-- Zones and landmarks win inside their biome.
check(at(Cove.CENTER[1], Cove.CENTER[2]) == cove, "Pirate Cove not announced at the cove")
check(at(Cove.CENTER[1] + Cove.RADIUS, Cove.CENTER[2]) == cove, "Cove shoreline is outside Pirate Cove")
check(at(7000, 7000) == city, "City centre is not Modern City")
check(at(7000 - 580, 7000 - 1580) == city, "City lighthouse is outside Modern City")
check(at(-1200, 3000) == Areas.Biomes.tropical, "Coral Shallows centre is claimed by the cove")

-- Hysteresis: a little past the edge stays put while you are in it, but not on entry.
local normal = Areas.Biomes.normal
local edge = normal.radius * 1.05
check(at(edge, 0, normal) == normal, "Gullhaven Sound drops out right at its edge")
check(at(edge, 0, nil) == Areas.Biomes.open, "Gullhaven Sound claims water past its edge on entry")
check(at(normal.radius * 1.2, 0, normal) == Areas.Biomes.open, "Gullhaven Sound holds on far past its edge")
local coveEdge = Cove.CENTER[1] + cove.radius * 1.05
check(at(coveEdge, Cove.CENTER[2], cove) == cove, "Pirate Cove drops out right at its edge")
check(at(coveEdge, Cove.CENTER[2], nil) == Areas.Biomes.tropical, "Pirate Cove claims water past its edge on entry")
-- Holding a biome never hides a landmark inside it.
check(at(Cove.CENTER[1], Cove.CENTER[2], Areas.Biomes.tropical) == cove, "Coral Shallows hides Pirate Cove")

-- Announcements.
check(Areas.announces(nil, normal), "First area is not announced")
check(Areas.announces(Areas.Biomes.open, normal), "Entering Gullhaven Sound is not announced")
check(not Areas.announces(normal, normal), "Same area announced twice")
check(Areas.announces(Areas.Biomes.tropical, cove), "Arriving at Pirate Cove is not announced")
check(Areas.announces(cove, Areas.Biomes.tropical), "Leaving the Pirate Cove biome does not announce Coral Shallows")
check(Areas.announces(cove, Areas.Biomes.open), "Sailing from the cove into open water is not announced")
check(not Areas.announces(city, Areas.Biomes.open), "Leaving the city re-announces open water")

print(`Area banner checks passed ({checks})`)
