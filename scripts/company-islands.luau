-- Pure save/economy regression checks: lute run scripts/company-islands.luau
local Data = require("../src/server/AnglerData")
local Islands = require("../src/shared/CompanyIslands")
local Recipes = require("../src/shared/Recipes")
local Furniture = require("../src/shared/FurnitureCatalog")
local checks = 0
local function check(value, message) checks += 1; assert(value, message) end
local function fish(id)
	return { FishId = id or "Trout", Mutation = "Normal", Kg = 2, Value = 100, Rarity = 10, Relative = 1, CaughtAt = 1 }
end
local function profile(cash, company)
	local data = Data.decode(nil)
	data.Paths.Unlocked.Supermarket = true
	data.Paths.Unlocked.Company = company or nil
	data.Storage = { fish() }
	data.Furniture = { { ItemId = "StorageRack", X = 13.5, Z = 0, R = 0 } }
	return { Cash = cash, Angler = data, OwnedBoats = { Rowboat = true } }
end

check(Data.decode(nil).CompanyIsland == nil, "Old profiles do not acquire a paid property")
check(Islands.COUNT == 15 and #Islands.Names == Islands.COUNT, "Every player in a fifteen-person lobby has a named company property")
check(Islands.purchase(profile(100000, false), 1) == nil, "Company path is required")
check(Islands.purchase(profile(49999, true), 1) == nil, "Cannot buy without enough cash")
for _, id in { 0, Islands.COUNT + 1, 1.5, "1", math.huge } do
	check(Islands.purchase(profile(50000, true), id) == nil, "Invalid plot ids cannot charge the wallet")
end
local original = profile(50000, true)
local bought = assert(Islands.purchase(original, 3))
check(bought.Cash == 0 and bought.Angler.CompanyIsland == 3, "Buy charges exactly once and saves the preferred plot")
check(original.Cash == 50000 and original.Angler.CompanyIsland == nil, "Purchase does not mutate its input")
check(bought.Angler.Stats.CoinsSpent == 50000 and original.Angler.Stats.CoinsSpent == 0, "Property spending updates statistics without mutating the original")
check(bought.OwnedBoats.Rowboat and #bought.Angler.Storage == 1 and #bought.Angler.Furniture == 1, "Boat, fish and furniture survive buying")
check(Islands.purchase(bought, 4) == nil and bought.Cash == 0, "Duplicate purchases cannot charge again")
local loaded = Data.decode(bought.Angler)
check(loaded.CompanyIsland == 3 and #loaded.Storage == 1 and #loaded.Furniture == 1, "Ownership and inventories survive a save round trip")
check(Data.storageCapacity(loaded) == 12, "The island's racks add nothing until they are placed")
for itemId, count in Data.COMPANY_KIT do
	check(loaded.FurnitureStock[itemId] == count, "Buying grants the island kit to place: " .. itemId)
end
check(loaded.CompanyKit == 1 and Data.decode(loaded).FurnitureStock.StorageRack == 4, "The kit is granted once, not on every load")
check(Data.decode({ CompanyIsland = 2 }).FurnitureStock.CompanyDesk == 1, "Owners from before the kit receive it too")
check(Data.decode(nil).FurnitureStock.CompanyDesk == nil, "Players without an island get no kit")
check(not pcall(Data.decode, { CompanyKit = 2 }), "Corrupt kit markers are rejected")
check(not pcall(Data.decode, { CompanyFurniture = { { ItemId = "CompanyPrep", X = 0, Z = 0, R = 0, Key = "Prep1" } } }), "Corrupt bench keys are rejected")

-- Placing the kit on the plot.
check(Data.placeFurniture(loaded, "StorageRack", 0, 0, 0, "Company") ~= nil, "Racks go on the company plot")
check(Data.placeFurniture(loaded, "CompanyDesk", 13.5, 0, 0) == nil, "Kit fixtures cannot go in the harbour house")
local freezerOwner = Data.decode(loaded)
freezerOwner.FurnitureStock.Freezer = 1
check(Data.placeFurniture(freezerOwner, "Freezer", 0, 0, 0, "Company") == nil, "Shop fixtures stay at the harbour")
check(Data.placeFurniture(loaded, "StorageRack", 54, 0, 0, "Company") == nil, "Furniture stays inside the plot fence")
check(Data.placeFurniture(loaded, "StorageRack", 0, -31.5, 0, "Company") == nil, "The plot gate stays clear")
check(Data.placeFurniture(Data.decode(profile(0, true).Angler), "StorageRack", 0, 0, 0, "Company") == nil, "Without an island there is no plot")
local furnished = loaded
for index, x in { -40.5, -36, -31.5, -27 } do
	furnished = assert(Data.placeFurniture(furnished, "StorageRack", x, 18, 0, "Company"))
	check(Data.storageCapacity(furnished) == 12 + 12 * index, "Each placed island rack adds twelve slots")
end
check(furnished.FurnitureStock.StorageRack == nil and #furnished.Furniture == 1, "Placing uses the kit and leaves the house alone")
check(Data.placeFurniture(furnished, "StorageRack", 0, 0, 0, "Company") == nil, "Only owned racks can be placed")
check(Data.placeFurniture(furnished, "CompanyDesk", -40.5, 18, 0, "Company") == nil, "Plot furniture cannot overlap")
furnished = assert(Data.placeFurniture(furnished, "CompanyDesk", 0, 13.5, 2, "Company"))
furnished = assert(Data.placeFurniture(furnished, 5, 0, 22.5, 2, "Company"))
check(furnished.CompanyFurniture[5].Z == 22.5 and furnished.FurnitureStock.CompanyDesk == nil, "Plot furniture moves without returning to stock")
check(Furniture.check(furnished.CompanyFurniture, "CompanyDesk", 0, 22.5, 2, 5, "Company") == nil, "Build mode previews the same rules")
for _, id in { 0, Islands.COUNT + 1, 1.5, "1", false } do
	check(not pcall(Data.decode, { CompanyIsland = id }), "Corrupt property saves are rejected")
end
for id = 1, Islands.COUNT do
	local source = profile(Islands.PRICE + 123, true)
	local purchased = assert(Islands.purchase(source, id))
	check(purchased.Cash == 123 and purchased.Angler.CompanyIsland == id, "Every property ID can be purchased at the same price")
	check(source.Cash == Islands.PRICE + 123 and source.Angler.CompanyIsland == nil, "Purchasing any property preserves the original profile")
	local restored = Data.decode(Data.decode(purchased.Angler))
	check(restored.CompanyIsland == id and #restored.Storage == 1 and #restored.Furniture == 1,
		"Every property ID and its inventory survive repeated save decoding")
	check(restored.Stats.CoinsSpent == Islands.PRICE, "Each property purchase records its spending after a save round trip")
end

local species = { Trout = { Rarity = "Common" } }
loaded.Hand = fish()
check(Data.startCooking(loaded, "CompanyPrep1", "FishFillet", species, 100) == nil, "Island cooking needs a placed bench")
loaded = assert(Data.placeFurniture(loaded, "CompanyPrep", 18, 9, 0, "Company"))
check(loaded.CompanyFurniture[1].Key == "CompanyPrep1", "The first bench takes the first island bench key")
local cooking = assert(Data.startCooking(loaded, "CompanyPrep1", "FishFillet", species, 100))
check(cooking.Hand == nil and cooking.Kitchen.CompanyPrep1.ReadyAt == 106, "Island cooking reserves the fish and saves its timer")
cooking.Hand = fish()
local parallel = assert(Data.startCooking(cooking, "Prep1", "FishFillet", species, 100))
check(parallel.Kitchen.CompanyPrep1 and parallel.Kitchen.Prep1, "Harbour and island benches have independent jobs")
check(Data.startCooking(parallel, "CompanyPrep1", "FishFillet", species, 101) == nil, "An occupied bench cannot consume another fish")
check(Data.collectDish(parallel, "CompanyPrep1", 105) == nil, "Cannot collect an unfinished dish")
local collected = assert(Data.collectDish(Data.decode(parallel), "CompanyPrep1", 106))
check(#collected.Pantry == 1 and collected.Kitchen.CompanyPrep1 == nil and collected.Kitchen.Prep1, "Collecting after rejoin preserves the other station")
check(Data.startCooking(cooking, "CompanyPrep2", "FishFillet", species, 100) == nil, "The second bench key needs a second bench")
check(Data.pickUpFurniture(parallel, 1, "Company") == nil, "A bench holding a dish stays put")
local benches = assert(Data.placeFurniture(collected, "CompanyPrep", 27, 9, 0, "Company"))
check(benches.CompanyFurniture[2].Key == "CompanyPrep2", "The second bench takes the second key")
benches = assert(Data.pickUpFurniture(benches, 1, "Company"))
benches = assert(Data.placeFurniture(benches, "CompanyPrep", 18, 9, 0, "Company"))
check(benches.CompanyFurniture[2].Key == "CompanyPrep1" and benches.FurnitureStock.CompanyPrep == nil, "A re-placed bench takes the free key back")
local unowned = profile(100000, true).Angler
unowned.Hand = fish()
check(Data.startCooking(unowned, "CompanyPrep1", "FishFillet", species, 100) == nil, "Island benches require paid ownership")
check(Recipes.stationOf("CompanyPrep2") == "Prep", "The recipe picker recognizes both island benches")
local full = Data.decode(loaded)
full.Furniture, full.Storage = {}, {}
full.CompanyFurniture = {}
for _, x in { -40.5, -36, -31.5, -27 } do
	table.insert(full.CompanyFurniture, { ItemId = "StorageRack", X = x, Z = 18, R = 0 })
end
for _ = 1, 48 do table.insert(full.Storage, fish()) end
full.Hand = fish()
check(Data.storeFish(full) == nil and #full.Storage == 48 and full.Hand, "Full island storage cannot lose a carried fish")
check(Data.pickUpFurniture(full, 1, "Company") == nil, "An island rack holding fish cannot be picked up")
print(string.format("Company islands: %d save, purchase, storage and cooking checks passed.", checks))
