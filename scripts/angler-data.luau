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
check(#c.Cooler == 3 and c.Cooler[3].FishId == "Shark" and c.Cooler[1].Kg == 3, "Catches wait in the cooler in order")
c.Cooler[1].Kg = 999
check(a.Cooler[1].Kg == 3 and c.Findings.Largest.Kg == 110, "Cooler fish never alias previous saves or findings")
local huge = Data.recordCatch(nil, "Trout", "Normal", 9, 90, 100, fish, mutations, "Huge")
check(huge.Cooler[1].Size == "Huge" and huge.Findings.Largest.Size == "Huge", "Size class is stored with the catch")
local full = Data.decode(nil)
for index = 1, Data.COOLER_CAPACITY do
	full.Cooler[index] = table.clone(huge.Cooler[1])
end
local overflow = Data.recordCatch(full, "Shark", "Normal", 100, 1, 1, fish, mutations)
check(
	#overflow.Cooler == Data.COOLER_CAPACITY and overflow.Catches.Shark.Count == 1,
	"A full cooler releases the fish but still records the bestiary catch"
)
local stocked, moved = Data.stockFreezer(c)
check(moved == 3 and #stocked.Cooler == 0 and #stocked.Freezer == 3, "Stocking empties the cooler into the freezer")
check(stocked.Freezer[1].FishId == "Trout" and #c.Cooler == 3, "Stocking keeps order and is copy-on-write")
local packed = Data.decode(nil)
for index = 1, Data.FREEZER_CAPACITY - 1 do
	packed.Freezer[index] = table.clone(huge.Cooler[1])
end
local _, fitted = Data.stockFreezer({ Cooler = c.Cooler, Freezer = packed.Freezer })
check(fitted == 1, "A full freezer leaves the rest in the cooler")
local sold, price = Data.sellFrozen(stocked, stocked.Freezer[3])
check(sold and price == 1000 and #sold.Freezer == 2, "Customers buy the exact frozen fish")
check(sold.Stats.CoinsEarned == c.Stats.CoinsEarned + 1000 and #stocked.Freezer == 3, "Sales count as earnings")
check(Data.sellFrozen(sold, stocked.Freezer[3]) == nil, "A fish can only be sold once")
rejects({ Freezer = { { FishId = "Trout" } } })
rejects({ Cooler = { { FishId = "Trout" } } })
rejects({ Cooler = { Bad = huge.Cooler[1] } })
print("Angler progress: " .. checks .. " checks passed (pure data; no Roblox runtime).")
