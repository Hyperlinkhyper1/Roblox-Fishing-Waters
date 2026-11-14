-- Production rules and persisted profiles; no geometry is constructed here.
local Building = require("../src/shared/BuildingCatalog")
local Plots = require("../src/shared/MultiplayerPlots")
local BoatData = require("../src/server/BoatData")
local SaveData = require("../src/server/SaveData")

local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local function wall(x1, z1, x2, z2)
	return { Kind = "Wall", X1 = x1, Z1 = z1, X2 = x2, Z2 = z2, Level = 0, Material = "Brick", Color = { 100, 120, 140 } }
end
local function floor(x1, z1, x2, z2)
	return { Kind = "Floor", X1 = x1, Z1 = z1, X2 = x2, Z2 = z2, Level = 0, Material = "WoodPlanks", Color = { 160, 140, 120 } }
end
local function valid(entry, site, expanded, pieces)
	return Building.check(pieces or {}, entry, site, {}, nil, expanded) == nil
end

local normal = Building.bounds("Home", false)
local originalHome, originalShop = table.clone(normal[1]), table.clone(normal[2])
local expanded = Building.bounds("Home", true)
check(normal == Building.Bounds.Home and expanded == Plots.Bounds.Home, "Both build grid and placement use their profile's configured bounds")
check(expanded[1][3] - expanded[1][1] == 2 * (normal[1][3] - normal[1][1]), "Multiplayer home construction has twice the original width")
check(expanded[2][3] - expanded[2][1] == normal[2][3] - normal[2][1], "The shop retains its original width to clear the curved road and back lane")
for index, area in normal do
	local original = if index == 1 then originalHome else originalShop
	for coordinate = 1, 4 do
		check(area[coordinate] == original[coordinate], "Requesting expanded bounds never mutates another player's original bounds")
	end
end
check(Building.bounds("Company", true) == Building.Bounds.Company, "The existing offshore company plot keeps its own footprint")
check(Building.bounds(nil, true) == expanded, "The client default Home site selects the expanded footprint")

for _, entry in { wall(36, -27, 45, -27), wall(-45, -27, -36, -27), floor(27, -31.5, 49.5, -18) } do
	check(not valid(entry, "Home", false), "Solo saves cannot build in a multiplayer extension")
	check(valid(entry, "Home", true), "Expanded plots accept walls and floors entirely inside their own extensions")
end
check(not valid(floor(-49.5, 67.5, -27, 81), "Home", true), "The larger home cannot extend the shop into its neighboring public roads")
check(not valid(floor(36, 9, 45, 72), "Home", true), "Extra width never permits construction across the public road")
check(not valid(wall(-54, -27, -45, -27), "Home", true), "Construction cannot extend beyond the larger left boundary")
check(not valid(wall(45, -27, 54, -27), "Home", true), "Construction cannot extend beyond the larger right boundary")
check(not valid(floor(27, -36, 45, -18), "Home", true), "Construction cannot extend beyond the unchanged back boundary")
check(not valid(floor(27, 67.5, 45, 85.5), "Home", true), "The widened shop keeps its original front boundary")
local existing = assert(Building.normalize(wall(36, -27, 45, -27)))
existing.Id = "p1"
check(not valid(existing, "Home", true, { existing }), "Expanded plots still reject duplicate overlapping structures")
check(not valid(wall(-4.5, -31.5, 4.5, -31.5), "Company", true), "Expanded saves still keep the company island entrance clear")
check(valid(wall(9, -5, 18, -5), "Home", false) and valid(wall(9, -5, 18, -5), "Home", true), "Old local-coordinate structures fit both plot sizes without being moved")

local profile = BoatData.decode(nil)
profile.SaveInfo = SaveData.createInfo(123, 1, "Expanded company", true, 1)
profile.Angler.Building = { Home = { NextId = 2, Pieces = { existing }, Overrides = {} } }
local reloaded = BoatData.decode(profile)
check(reloaded.SaveInfo.PlotExpanded == true and reloaded.Angler.Building.Home.Pieces[1].X1 == 36, "Expanded entitlement and extension geometry survive the production profile decoder")
SaveData.edit(reloaded.SaveInfo, 123, nil, false)
local soloAgain = BoatData.decode(reloaded)
check(not soloAgain.SaveInfo.Multiplayer and soloAgain.SaveInfo.PlotExpanded, "Turning multiplayer off preserves the plot size needed by existing buildings")
check(valid(soloAgain.Angler.Building.Home.Pieces[1], "Home", soloAgain.SaveInfo.PlotExpanded), "Saved extension buildings remain valid after multiplayer is disabled")
print("Multiplayer construction: " .. checks .. " footprint, overlap, road, profile-isolation and persistence checks passed.")
