-- Production placement and save round trips for the wider multiplayer pads.
local Furniture = require("../src/shared/FurnitureCatalog")
local Data = require("../src/server/AnglerData")
local BoatData = require("../src/server/BoatData")
local checks = 0
local function check(value, message) checks += 1; assert(value, message) end

local normal = Furniture.roomsFor(false)
local wide = Furniture.roomsFor(true)
check(normal == Furniture.Rooms and normal.Storage[3] == 24.35, "Original rooms remain unchanged")
check(wide.Shop[1] == normal.Shop[1] and wide.Shop[3] == normal.Shop[3], "Shop width remains unchanged beside the protected roads")
for name, room in wide do
	check(room[2] == normal[name][2] and room[4] == normal[name][4], "Expansion never moves rooms toward the road: " .. name)
end
for _, spot in {
	{ "StorageRack", 40.5, -13.5, 0 },
	{ "GrillStation", -40.5, -13.5, 0 },
	{ "OfficeDesk", -40.5, 4.5, 0 },
	{ "DiningTable", -40.5, -22.5, 0 },
	{ "WeatherRadar", 40.5, -22.5, 0 },
} do
	check(Furniture.check({}, spot[1], spot[2], spot[3], spot[4], nil, "Home", true) == nil, "Furniture fits its widened room: " .. spot[1])
	check(Furniture.check({}, spot[1], spot[2], spot[3], spot[4], nil, "Home", false) ~= nil, "Ordinary plots cannot use the extension: " .. spot[1])
end
for _, x in { -40.5, 36 } do
	check(Furniture.check({}, "Freezer", x, 72, 0, nil, "Home", true) ~= nil, "Expanded saves keep shop furniture out of the roads beside the shop")
	check(Furniture.check({}, "Freezer", x, 72, 0, nil, "Home", false) ~= nil, "Ordinary saves retain their original shop width")
end
check(Furniture.check({}, "PottedPlant", 36, 45, 0, nil, "Home", true) ~= nil, "Expanded furniture cannot occupy the road gap")
check(Furniture.check({}, "StorageRack", 54, -13.5, 0, nil, "Home", true) ~= nil, "Furniture outside enlarged ground remains rejected")
check(Furniture.check({}, "StorageRack", -40.5, -13.5, 0, nil, "Home", true) ~= nil, "Room-specific placement remains enforced")
local placed = {{ ItemId = "StorageRack", X = 40.5, Z = -13.5, R = 0 }}
check(Furniture.check(placed, "StorageRack", 40.5, -13.5, 0, nil, "Home", true) ~= nil, "Extended furniture cannot overlap another item")
local freezer = {{ ItemId = "Freezer", X = 9, Z = 67.5, R = 0 }}
check(Furniture.check({}, "Freezer", 9, 67.5, 0, nil, "Home", true) == nil, "The original shop remains usable in expanded mode")
check(Furniture.check(freezer, "PottedPlant", 9, 72, 0, nil, "Home", true) ~= nil, "Expanded mode still keeps standing access strips clear")
check(Furniture.check({}, "StorageRack", 58.5, 0, 0, nil, "Company", true) ~= nil, "Harbour expansion never enlarges company-island fences")

local angler = Data.decode(nil)
angler.FurnitureStock.StorageRack = 1
angler.FurnitureStock.WeatherRadar = 1
check(Data.placeFurniture(angler, "StorageRack", 40.5, -13.5, 0, "Home") == nil, "Default server placement rejects unauthorized expanded ground")
local expanded = assert(Data.placeFurniture(angler, "StorageRack", 40.5, -13.5, 0, "Home", true))
expanded = assert(Data.placeFurniture(expanded, "WeatherRadar", 40.5, -22.5, 0, "Home", true))
check(angler.FurnitureStock.StorageRack == 1 and #angler.Furniture + 2 == #expanded.Furniture, "Expanded placement uses copies and consumes only placed stock")
local raw = BoatData.decode({ Version = 1, Cash = 975, OwnedBoats = { Rowboat = true }, Angler = expanded,
	SaveInfo = { OwnerUserId = 10, Slot = 1, Multiplayer = true, PlotExpanded = true } })
local restored = BoatData.decode(BoatData.decode(raw))
local rack, radar
for _, item in restored.Angler.Furniture do
	if item.ItemId == "StorageRack" then rack = item end
	if item.ItemId == "WeatherRadar" and item.X == 40.5 then radar = item end
end
check(rack and rack.X == 40.5 and rack.Z == -13.5 and radar and radar.Z == -22.5, "Expanded positions survive whole-profile repeated save round trips")
check(restored.Cash == 975 and restored.SaveInfo.PlotExpanded, "Furniture save round trip retains wallet and expanded entitlement")
local moved = assert(Data.placeFurniture(restored.Angler, #restored.Angler.Furniture - 1, 45, -13.5, 0, "Home", true))
check(moved.Furniture[#moved.Furniture - 1].X == 45 and rack.X == 40.5, "Moving saved extended furniture preserves the prior snapshot")
local picked = assert(Data.pickUpFurniture(moved, #moved.Furniture - 1, "Home"))
check(picked.FurnitureStock.StorageRack == 1, "Extended furniture can return to stock after rejoining")
print("Expanded furniture: " .. checks .. " placement, collision, authorization and save checks passed.")
