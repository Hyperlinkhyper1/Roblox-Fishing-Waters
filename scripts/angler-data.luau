-- Pure saved-progress regression checks. No Roblox network or DataStore claims.
local Data = require("../src/server/AnglerData")
local BoatData = require("../src/server/BoatData")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local function rejects(raw)
	check(not pcall(Data.decode, raw), "Malformed saved progress must be rejected")
end
local fish = { Trout = { AverageKg = 2, RarityDenominator = 10 }, Shark = { AverageKg = 100, RarityDenominator = 500 } }
local mutations = { Normal = {}, Albino = { RarityMultiplier = 100 } }
local fresh = Data.decode(nil)
check(fresh.Stats.TotalCaught == 0 and next(fresh.Catches) == nil, "No invented catches")
check(fresh.Settings.MasterVolume == 100 and fresh.Settings.Shadows, "Sensible settings defaults")
local other = Data.decode(nil)
fresh.Settings.MasterVolume = 0
check(other.Settings.MasterVolume == 100, "Profiles must not share settings")
local a = Data.recordCatch(nil, "Trout", "Normal", 3, 48, 100, fish, mutations)
local b = Data.recordCatch(a, "Trout", "Albino", 4, 150, 200, fish, mutations)
local c = Data.recordCatch(b, "Shark", "Normal", 110, 1000, 300, fish, mutations)
check(c.Stats.TotalCaught == 3 and c.Stats.CatchStreak == 3 and c.Stats.HighestCatchStreak == 3, "Catch/streak totals")
check(c.Catches.Trout.Count == 2 and c.Catches.Trout.BiggestKg == 4, "Per-species count and maximum")
check(c.Catches.Trout.Mutations.Normal == 1 and c.Catches.Trout.Mutations.Albino == 1, "Independent mutation counts")
check(c.Findings.HighestValue.FishId == "Shark" and c.Findings.Largest.Kg == 110, "Highest value and absolute largest")
check(c.Findings.Rarest.Mutation == "Albino" and c.Findings.Rarest.Rarity == 1000, "Mutation-adjusted rarity")
check(
	c.Findings.RelativeLargest.FishId == "Trout" and c.Findings.RelativeLargest.Relative == 2,
	"Relative largest uses species average"
)
check(a.Catches.Trout.Count == 1 and a.Catches.Trout.BiggestKg == 3, "Never mutate previous saved records")
c.Findings.HighestValue.Kg = 999
check(c.Findings.Largest.Kg == 110, "Finding records must not alias one another")
for _, kg in { -1, 0, math.huge, 0 / 0 } do
	check(not pcall(Data.recordCatch, nil, "Trout", "Normal", kg, 1, 1, fish, mutations), "Reject invalid fish weight")
end
check(
	not pcall(Data.recordCatch, nil, "Unknown", "Normal", 1, 1, 1, fish, mutations),
	"Unknown species cannot enter progress"
)
check(not pcall(Data.recordCatch, nil, "Trout", "Unknown", 1, 1, 1, fish, mutations), "Unknown mutations rejected")
for _, key in { "MasterVolume", "EffectsVolume", "MusicVolume" } do
	for _, value in { 0, 10, 100 } do
		check(Data.validSetting(key, value), "Valid volume")
	end
	for _, value in { -1, 101, 0.5, math.huge, 0 / 0, "10", true } do
		check(not Data.validSetting(key, value), "Invalid volume rejected")
	end
end
check(Data.validSetting("Shadows", false) and Data.validSetting("WeatherEffects", true), "Boolean setting changes")
check(
	not Data.validSetting("Shadows", 1) and not Data.validSetting("Cash", 500),
	"No setting coercion or arbitrary fields"
)
for _, raw in
	{
		false,
		1,
		"bad",
		{ Stats = false },
		{ Settings = { MasterVolume = -1 } },
		{ Stats = { TotalCaught = 0 / 0 } },
		{ Catches = { Trout = { Count = 1, BiggestKg = -1, Mutations = {} } } },
		{ Findings = { Largest = {} } },
		{ Titles = { Admin = "yes" } },
		{ EquippedTitle = false },
	}
do
	rejects(raw)
end
local legacy = { Version = 1, Cash = 900, OwnedBoats = {}, OwnedRods = { FutureRod = true }, Quest = 8 }
local migrated = BoatData.decode(legacy)
check(
	migrated.Cash == 900 and migrated.Quest == 8 and migrated.OwnedRods.FutureRod,
	"Migration preserves wallet, equipment and future fields"
)
check(migrated.Angler.Stats.TotalCaught == 0 and legacy.Angler == nil, "Migration is copy-on-write")
migrated.Angler = b
migrated.Angler.Settings.EffectsVolume = 20
local purchased = BoatData.purchase(migrated)
check(purchased.Cash == 400 and purchased.Angler.Stats.CoinsSpent == 500, "Atomic purchase tracks actual spending")
check(
	purchased.Angler.Catches.Trout.Count == 2 and purchased.Angler.Settings.EffectsVolume == 20,
	"Boat purchases preserve catches and settings"
)
local rod = BoatData.purchaseRod(purchased)
check(
	rod.Angler.Stats.CoinsSpent == 500 and rod.Angler.Catches.Trout.Mutations.Albino == 1,
	"Free rod doesn't change spending or catches"
)
rod.Angler.Catches.Trout.Mutations.Albino = 900
check(purchased.Angler.Catches.Trout.Mutations.Albino == 1, "Nested progress never aliases between transactions")
check(c.Hand.Kg == 3 and c.Hand.FishId == "Trout", "The first catch goes into the angler's hand")
check(
	c.Catches.Shark.Count == 1 and c.Stats.TotalCaught == 3,
	"Catches with full hands are released but still count in the bestiary"
)
c.Hand.Kg = 999
check(a.Hand.Kg == 3 and c.Findings.Largest.Kg == 110, "Hand fish never alias previous saves or findings")
c.Hand.Kg = 3
local huge = Data.recordCatch(nil, "Trout", "Normal", 9, 90, 100, fish, mutations, "Huge")
check(huge.Hand.Size == "Huge" and huge.Findings.Largest.Size == "Huge", "Size class is stored with the catch")

-- Cargo grid geometry.
local Cargo = require("../src/shared/Cargo")
local BoatCatalog = require("../src/shared/BoatCatalog")
local cells, width, height = Cargo.cells({ "#.", "##" }, 1)
check(width == 2 and height == 2 and #cells == 3, "Rotation keeps every cell")
local rotated = {}
for _, offset in cells do
	rotated[offset[1] .. "," .. offset[2]] = true
end
check(rotated["0,0"] and rotated["1,0"] and rotated["0,1"] and not rotated["1,1"], "An L turns clockwise")
local _, longWidth, longHeight = Cargo.cells({ "####" }, 3)
check(longWidth == 1 and longHeight == 4, "A quarter turn swaps width and height")
check(Cargo.capacity(BoatCatalog.FishingBoat.Hold) > Cargo.capacity(BoatCatalog.Rowboat.Hold), "Bigger boats hold more")
for boatId, spec in BoatCatalog do
	local kit = Data.hold({ Holds = {} }, boatId, spec)
	for index, part in kit do
		check(
			Cargo.fits(spec.Hold, Cargo.occupied(kit, {}, index), Cargo.shape(part, {}), part.X, part.Y, part.R),
			"Starter kit fits its own hold"
		)
	end
end

-- Moving fish between hand, hold and water.
local shaped = {
	Trout = { AverageKg = 2, RarityDenominator = 10, Shapes = { Normal = { "##" }, Huge = { "###", "###" } } },
	Squid = { AverageKg = 1, RarityDenominator = 20, Shapes = { Normal = { "#.", "##" } } },
}
local tiny = { Hold = { "####", "####", "####" }, StarterParts = { { PartId = "Engine", X = 1, Y = 1, R = 0 } } }
local angler = Data.recordCatch(nil, "Squid", "Normal", 1, 20, 50, shaped, mutations)
check(not Data.moveCargo(angler, "Tiny", tiny, "Hand", { X = 1, Y = 1, R = 0 }, shaped), "Fish can't overlap boat parts")
check(not Data.moveCargo(angler, "Tiny", tiny, "Hand", { X = 4, Y = 1, R = 0 }, shaped), "Fish can't hang off the hull")
local stowed = Data.moveCargo(angler, "Tiny", tiny, "Hand", { X = 3, Y = 1, R = 2 }, shaped)
check(stowed and stowed.Hand == nil and #stowed.Holds.Tiny == 2, "Hand fish rotate into a free spot")
check(angler.Hand ~= nil and next(angler.Holds) == nil, "Stowing is copy-on-write")
check(stowed.Holds.Tiny[1].PartId == "Engine", "A new hold starts with the boat's kit")
check(not Data.moveCargo(stowed, "Tiny", tiny, "Hand", { X = 1, Y = 3, R = 0 }, shaped), "Empty hands stow nothing")
local second = Data.recordCatch(stowed, "Trout", "Normal", 2, 10, 60, shaped, mutations)
check(not Data.moveCargo(second, "Tiny", tiny, "Hand", { X = 3, Y = 2, R = 0 }, shaped), "Fish can't overlap fish")
check(not Data.moveCargo(second, "Tiny", tiny, 2, "Hand", shaped), "A full hand can't take from the hold")
local moved = Data.moveCargo(stowed, "Tiny", tiny, 2, { X = 3, Y = 1, R = 1 }, shaped)
check(moved and moved.Holds.Tiny[2].R == 1, "Hold fish turn in place without colliding with themselves")
check(not Data.moveCargo(stowed, "Tiny", tiny, 1, "Release", shaped), "Boat parts can't be released")
local engine = Data.moveCargo(stowed, "Tiny", tiny, 1, { X = 1, Y = 2, R = 0 }, shaped)
check(engine and engine.Holds.Tiny[1].Y == 2 and engine.Holds.Tiny[1].PartId == "Engine", "Boat parts rearrange")
local taken = Data.moveCargo(stowed, "Tiny", tiny, 2, "Hand", shaped)
check(taken and taken.Hand.FishId == "Squid" and #taken.Holds.Tiny == 1, "Hold fish return to the hand")
local released = Data.moveCargo(angler, nil, nil, "Hand", "Release", shaped)
check(released and released.Hand == nil and released.Catches.Squid.Count == 1, "Releasing keeps the bestiary entry")
check(not Data.moveCargo(stowed, nil, nil, 2, "Hand", shaped), "An out-of-reach hold can't be used")
for _, spot in { { X = 0, Y = 1, R = 0 }, { X = 1.5, Y = 1, R = 0 }, { X = 1, Y = 1, R = 4 }, { X = 1, Y = 1 } } do
	check(not Data.moveCargo(angler, "Tiny", tiny, "Hand", spot, shaped), "Malformed spots are rejected")
end

-- Stocking places exactly the carried fish and never unloads stored cargo.
local stocking = Data.decode(nil)
stocking.Hand = table.clone(huge.Hand)
stocking.Cooler = { table.clone(c.Findings.Largest) }
stocking.Holds = {
	Rowboat = { { Fish = table.clone(a.Hand), X = 2, Y = 2, R = 0 } },
	FishingBoat = { { PartId = "Engine", X = 3, Y = 7, R = 0 }, { Fish = table.clone(angler.Hand), X = 3, Y = 3, R = 0 } },
}
check(Data.unstocked(stocking) == 4, "Unstocked fish counts hand, cooler and holds")
local stocked, count = Data.stockFreezer(stocking)
check(count == 1 and #stocked.Freezer == 1 and stocked.Hand == nil, "Stocking places one fish")
check(stocked.Freezer[1].Size == "Huge" and #stocked.Cooler == 1, "Only the hand fish is stocked; old cooler stays intact")
check(#stocked.Holds.Rowboat == 1 and #stocked.Holds.FishingBoat == 2, "Fish in every boat hold stay aboard")
check(stocked.Holds.FishingBoat[1].PartId == "Engine", "Boat parts stay aboard")
check(Data.unstocked(stocking) == 4, "Stocking is copy-on-write")
local emptyHand, emptyCount = Data.stockFreezer(stocked)
check(emptyCount == 0 and #emptyHand.Freezer == 1 and Data.unstocked(emptyHand) == 3, "Repeated stocking cannot pull fish from storage")
local pickedUp = Data.moveCargo(stocked, "FishingBoat", tiny, 2, "Hand", shaped)
local nextStocked, nextCount = Data.stockFreezer(pickedUp)
check(nextCount == 1 and #nextStocked.Freezer == 2 and nextStocked.Hand == nil, "The next fish must first be picked up from the boat")
local packed = Data.decode(nil)
for index = 1, Data.FREEZER_CAPACITY - 1 do
	packed.Freezer[index] = table.clone(huge.Hand)
end
packed.Hand, packed.Cooler = table.clone(a.Hand), { table.clone(huge.Hand) }
local leftover, fitted = Data.stockFreezer(packed)
check(fitted == 1 and leftover.Hand == nil and #leftover.Cooler == 1, "A full freezer leaves the rest waiting")
leftover.Hand = table.clone(c.Findings.Largest)
local full, fullCount = Data.stockFreezer(leftover)
check(fullCount == 0 and full.Hand.FishId == "Shark" and #full.Freezer == Data.FREEZER_CAPACITY, "A full freezer preserves the carried fish")
local forSale = Data.decode(stocked)
forSale.Hand = table.clone(c.Findings.Largest)
forSale = Data.stockFreezer(forSale)
local sold, price = Data.sellFrozen(forSale, forSale.Freezer[2])
check(sold and price == 1000 and #sold.Freezer == 1, "Customers buy the exact frozen fish")
check(sold.Stats.CoinsEarned == stocking.Stats.CoinsEarned + 1000 and #forSale.Freezer == 2, "Sales count as earnings")
check(Data.sellFrozen(sold, forSale.Freezer[2]) == nil, "A fish can only be sold once")
rejects({ Freezer = { { FishId = "Trout" } } })
rejects({ Cooler = { { FishId = "Trout" } } })
rejects({ Cooler = { Bad = huge.Hand } })
rejects({ Hand = { FishId = "Trout" } })
rejects({ Holds = { Rowboat = { { Fish = huge.Hand, X = 0, Y = 1, R = 0 } } } })
rejects({ Holds = { Rowboat = { { Fish = huge.Hand, X = 1, Y = 1, R = 5 } } } })
rejects({ Holds = { Rowboat = { { PartId = "Engine", Fish = huge.Hand, X = 1, Y = 1, R = 0 } } } })
rejects({ Holds = { Rowboat = "full" } })
-- Furniture: bought into stock, placed only in its own room, never on fixtures,
-- doorways or other furniture, and never picked up from under stored fish.
local Furniture = require("../src/shared/FurnitureCatalog")
local home = Data.decode(nil)
check(Data.freezerCapacity(home) == 4 and Data.storageCapacity(home) == 0, "Built-in freezer only")
check(Data.placeFurniture(home, "Freezer", -10, 9, 1) == nil, "Unbought furniture cannot be placed")
home = Data.buyFurniture(home, "Freezer")
home = Data.buyFurniture(home, "StorageRack")
home = Data.buyFurniture(home, "StorageRack")
check(home.FurnitureStock.Freezer == 1 and home.FurnitureStock.StorageRack == 2, "Purchases land in stock")
check(Data.buyFurniture(home, "Sofa") == nil, "Unknown furniture is not sold")
local _, wrongRoom = Data.placeFurniture(home, "StorageRack", -10, 9, 0)
check(wrongRoom and string.find(wrongRoom, "storage room"), "Storage racks stay in the storage room")
local _, wrongShop = Data.placeFurniture(home, "Freezer", 15, -10, 0)
check(wrongShop and string.find(wrongShop, "front shop room"), "Freezers stay in the front shop room")
check(Data.placeFurniture(home, "Freezer", 0, 9, 1) == nil, "The entrance aisle stays clear")
check(Data.placeFurniture(home, "Freezer", -18, 7, 1) == nil, "Built-in freezer spot stays clear")
check(Data.placeFurniture(home, "Freezer", -10.25, 9, 1) == nil, "Placements snap to the grid")
home = assert(Data.placeFurniture(home, "Freezer", -10, 9, 1))
check(home.FurnitureStock.Freezer == nil and #home.Furniture == 1, "Placing uses the stock")
check(Data.freezerCapacity(home) == 8, "A placed freezer adds four slots")
home = assert(Data.placeFurniture(home, "StorageRack", 16, -12, 2))
check(Data.placeFurniture(home, "StorageRack", 16, -12, 2) == nil, "Furniture cannot overlap")
home = assert(Data.placeFurniture(home, "StorageRack", 16, -6, 2))
check(Data.storageCapacity(home) == 16, "Each rack holds eight fish")
local fp = Furniture.footprint("Register", 0, 0, 1)
check(fp[3] - fp[1] == 3.05 + 4 and fp[4] - fp[2] == 7.5, "Quarter turns swap the footprint")
check(Data.placeFurniture(home, 1, -10, 6, 1) == nil, "Doorways stay clear")
home = assert(Data.placeFurniture(home, 1, -10, 10, 1))
check(home.Furniture[1].Z == 10 and #home.Furniture == 3, "Moving keeps one placed copy")
local stash = Data.recordCatch(home, "Trout", "Normal", 3, 48, 900, fish, mutations)
check(Data.takeStored(stash) == nil, "Empty racks give nothing")
stash = assert(Data.storeFish(stash))
check(stash.Hand == nil and #stash.Storage == 1, "Carried fish goes onto a rack")
check(Data.storeFish(stash) == nil, "Nothing to store with empty hands")
check(Data.pickUpFurniture(stash, 2) and Data.pickUpFurniture(Data.pickUpFurniture(stash, 2), 2) == nil, "The last rack holding fish stays")
stash.Freezer = { stash.Storage[1], stash.Storage[1], stash.Storage[1], stash.Storage[1], stash.Storage[1] }
check(Data.pickUpFurniture(stash, 1) == nil, "A freezer holding overflow fish stays")
local restocked = Data.restockFish(stash, stash.Storage[1])
check(restocked and #restocked.Freezer == 6 and #restocked.Storage == 0, "Rack fish restocks a freezer")
local back = assert(Data.takeStored(stash))
check(back.Hand and #back.Storage == 0, "Stored fish returns to the hand")
stash = Data.pickUpFurniture(Data.decode({ Furniture = { { ItemId = "Register", X = -12, Z = 10, R = 1 } } }), 1)
check(stash and stash.FurnitureStock.Register == 1 and #stash.Furniture == 0, "Picking up returns furniture to stock")
rejects({ Furniture = { { ItemId = "Freezer", X = 1, Z = 1, R = 7 } } })
rejects({ Storage = { { FishId = "Trout" } } })
rejects({ FurnitureStock = { Freezer = -1 } })
print("Angler progress: "
 .. checks .. " checks passed (pure data; no Roblox runtime).")
