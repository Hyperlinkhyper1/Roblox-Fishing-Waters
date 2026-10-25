-- Pure profile / purchase checks. Run: lute run scripts/boat-data.luau
-- These checks do not exercise Roblox DataStores, prompts, replication, or physics.

local BoatData = require("../src/server/BoatData")

local checks = 0
local function check(condition: boolean, message: string)
	checks += 1
	assert(condition, message)
end

local function rejects(raw: any, message: string)
	local ok = pcall(BoatData.decode, raw)
	check(not ok, message)
end

local fresh = BoatData.decode(nil)
check(fresh.Cash == 0, "New players must start with $0")
check(next(fresh.OwnedBoats) == nil, "New players must not own a boat")
check(fresh.OwnedRods.StarterRod == true, "New players start with a starter rod")
local freshAgain = BoatData.decode(nil)
check(freshAgain ~= fresh and freshAgain.OwnedBoats ~= fresh.OwnedBoats, "Profiles must not share mutable defaults")

local poor, poorResult = BoatData.purchase(nil)
check(poorResult == "InsufficientFunds", "A new player cannot buy the $500 rowboat")
check(poor.Cash == 0 and not poor.OwnedBoats.Rowboat, "Failed purchase must not award a boat or currency")

for _, cash in { 0, 1, 499 } do
	local input = { Version = 1, Cash = cash, OwnedBoats = {} }
	local profile, outcome = BoatData.purchase(input)
	check(outcome == "InsufficientFunds", `A player with ${cash} cannot afford a rowboat`)
	check(profile.Cash == cash and not profile.OwnedBoats.Rowboat, "Insufficient funds must leave progress intact")
	check(input.Cash == cash and next(input.OwnedBoats) == nil, "Purchase must not mutate its input")
end

for _, cash in { 500, 501, 1500 } do
	local input = { Version = 1, Cash = cash, OwnedBoats = {} }
	local profile, outcome = BoatData.purchase(input)
	check(outcome == "Purchased", `A player with ${cash} must be able to buy the rowboat`)
	check(profile.Cash == cash - 500 and profile.OwnedBoats.Rowboat == true, "Rowboat must cost exactly $500")
	check(profile ~= input and profile.OwnedBoats ~= input.OwnedBoats, "Purchase must copy the profile and boat set")
	check(input.Cash == cash and next(input.OwnedBoats) == nil, "Successful purchase must not mutate its input")
	local again, againResult = BoatData.purchase(profile)
	check(againResult == "AlreadyOwned", "A repeated purchase must recognize ownership")
	check(again.Cash == cash - 500 and again.OwnedBoats.Rowboat == true, "A repeated purchase must not charge twice")
end

local otherBoats: any = {
	Version = 1,
	Cash = 1200,
	OwnedBoats = { Sailboat = true, FutureBoat = false },
	FutureProgress = { Level = 8, Name = "Harbour" },
	UnknownNumber = 42,
}
local preserved: any, preservedResult = BoatData.purchase(otherBoats)
check(preservedResult == "Purchased" and preserved.Cash == 700, "Future progress must not block a valid purchase")
check(
	preserved.OwnedBoats.Sailboat == true and preserved.OwnedBoats.FutureBoat == false,
	"Purchasing must preserve other boats"
)
check(
	preserved.FutureProgress.Level == 8 and preserved.FutureProgress.Name == "Harbour",
	"Purchasing must preserve unknown profile fields"
)
check(preserved.UnknownNumber == 42, "Purchasing must preserve unknown primitive fields")
check(not otherBoats.OwnedBoats.Rowboat and otherBoats.Cash == 1200, "Preserving progress must not mutate input")

local ownedInput = { Version = 1, Cash = 0, OwnedBoats = { Rowboat = true, Sailboat = true } }
local owned, ownedResult = BoatData.purchase(ownedInput)
check(ownedResult == "AlreadyOwned", "An owner with $0 must still be recognized as an owner")
check(owned.Cash == 0 and owned.OwnedBoats.Sailboat == true, "Owned purchase must preserve the wallet and other boats")

for _, raw in { false, true, 0, 500, "500", "" } do
	rejects(raw, "Non-profile stored values must be rejected")
end
rejects({}, "An incomplete stored profile must be rejected")
rejects({ Version = 1, OwnedBoats = {} }, "Missing cash must be rejected")
rejects({ Version = 1, Cash = 0 }, "Missing boat ownership must be rejected")
rejects({ Version = 1, Cash = "500", OwnedBoats = {} }, "Text cash must be rejected")
rejects({ Version = 1, Cash = -1, OwnedBoats = {} }, "Negative cash must be rejected")
rejects({ Version = 1, Cash = 500.5, OwnedBoats = {} }, "Fractional cash must be rejected")
rejects({ Version = 1, Cash = math.huge, OwnedBoats = {} }, "Infinite cash must be rejected")
rejects({ Version = 1, Cash = 0 / 0, OwnedBoats = {} }, "NaN cash must be rejected")
rejects({ Version = 1, Cash = 500, OwnedBoats = true }, "Invalid boat ownership sets must be rejected")
rejects({ Version = 1, Cash = 500, OwnedBoats = { Rowboat = "true" } }, "Invalid rowboat ownership must be rejected")
rejects({ Version = 2, Cash = 500, OwnedBoats = {} }, "Unsupported profile versions must not be overwritten")

local invalidPurchase = { Version = 1, Cash = -500, OwnedBoats = {} }
local purchaseOk = pcall(BoatData.purchase, invalidPurchase)
check(not purchaseOk and invalidPurchase.Cash == -500, "Purchase must not silently replace invalid saved progress")

local rod = BoatData.decode(nil)
check(rod.Cash == 0 and not rod.OwnedBoats.Rowboat, "Starting rod must not grant cash or a boat")
local legacy = { Version = 1, Cash = 1200, OwnedBoats = { Rowboat = true }, Quest = 9 }
local migrated = BoatData.decode(legacy)
check(
	migrated.Cash == 1200 and migrated.OwnedBoats.Rowboat and migrated.Quest == 9,
	"Adding a rod must preserve the shared wallet and progress"
)
check(legacy.OwnedRods == nil, "Rod migration must not mutate an old saved record")
local otherRods = { Version = 1, Cash = 800, OwnedBoats = {}, OwnedRods = { OceanRod = true } }
local starterAdded = BoatData.decode(otherRods)
check(
	starterAdded.OwnedRods.OceanRod and starterAdded.OwnedRods.StarterRod,
	"Other rod ownership must survive starter rod migration"
)
check(not otherRods.OwnedRods.StarterRod, "Rod inventory must be copied before mutation")
local boatAfterRod = BoatData.purchase(starterAdded)
check(
	boatAfterRod.Cash == 300 and boatAfterRod.OwnedRods.StarterRod and boatAfterRod.OwnedRods.OceanRod,
	"Boat purchases must preserve rods"
)
rejects({ Version = 1, Cash = 0, OwnedBoats = {}, OwnedRods = false }, "Malformed rod inventories must be rejected")
rejects(
	{ Version = 1, Cash = 0, OwnedBoats = {}, OwnedRods = { StarterRod = "yes" } },
	"Malformed rod ownership must be rejected"
)

local Catalog = require("../src/shared/BoatCatalog")
check(Catalog.FishingBoat.Price > Catalog.Rowboat.Price, "Fishing boat must cost more than the wooden boat")
check(Catalog.FishingBoat.ForwardSpeed > Catalog.Rowboat.ForwardSpeed, "Fishing boat must travel faster")
check(
	Catalog.FishingBoat.Length > Catalog.Rowboat.Length and Catalog.FishingBoat.Beam > Catalog.Rowboat.Beam,
	"Fishing boat must have a larger hull"
)
local fishermanInput = { Version = 1, Cash = 3000, OwnedBoats = { Rowboat = true }, OwnedRods = { StarterRod = true } }
local fisherman, fishingOutcome = BoatData.purchase(fishermanInput, "FishingBoat")
check(
	fishingOutcome == "Purchased" and fisherman.Cash == 500 and fisherman.OwnedBoats.FishingBoat,
	"Fishing boat costs exactly $2500"
)
check(
	fisherman.OwnedBoats.Rowboat and fisherman.OwnedRods.StarterRod,
	"Upgrade retains the wooden boat and fishing rod"
)
check(fisherman.Angler.Stats.CoinsSpent == 2500, "Fishing boat spending counts toward saved statistics")
check(fishermanInput.Cash == 3000 and not fishermanInput.OwnedBoats.FishingBoat, "Upgrade cannot mutate stored input")
local repeatFisher, repeatOutcome = BoatData.purchase(fisherman, "FishingBoat")
check(repeatOutcome == "AlreadyOwned" and repeatFisher.Cash == 500, "Fishing boat repeat purchases never charge twice")
local shortFisher, shortOutcome = BoatData.purchase({ Version = 1, Cash = 2499, OwnedBoats = {} }, "FishingBoat")
check(
	shortOutcome == "InsufficientFunds" and shortFisher.Cash == 2499 and not shortFisher.OwnedBoats.FishingBoat,
	"Fishing boat requires its full price"
)
local unknownFisher, unknownOutcome = BoatData.purchase(fishermanInput, "UnknownBoat")
check(
	unknownOutcome == "UnknownBoat" and unknownFisher.Cash == 3000,
	"Unknown boat IDs cannot spend cash or grant ownership"
)
local fishingOnly = BoatData.purchase({ Version = 1, Cash = 2500, OwnedBoats = {} }, "FishingBoat")
check(
	fishingOnly.OwnedBoats.FishingBoat and not fishingOnly.OwnedBoats.Rowboat,
	"Fishing boat can be bought directly without the wooden boat"
)
local roundTrip = BoatData.decode(fisherman)
check(roundTrip.OwnedBoats.Rowboat and roundTrip.OwnedBoats.FishingBoat, "Both boats survive saved profile decoding")

print(`Boat profile and purchase checks passed: {checks}.`)

-- Sport cruiser progression and saved ownership.
check(Catalog.Speedboat.Price == 6500, "Speedboat costs exactly 6500")
check(Catalog.Speedboat.ForwardSpeed > Catalog.FishingBoat.ForwardSpeed, "Speedboat travels faster than the fisher")
check(Catalog.Speedboat.TurnRate > Catalog.FishingBoat.TurnRate, "Speedboat turns faster than the fisher")
check(Catalog.Speedboat.TurnAcceleration > Catalog.FishingBoat.TurnAcceleration, "Speedboat steering responds faster")
check(Catalog.Speedboat.Hold == Catalog.FishingBoat.Hold, "Both motorboats share the identical storage tile layout")
local speedOwner, speedResult = BoatData.purchase({ Version = 1, Cash = 6500, OwnedBoats = {} }, "Speedboat")
check(speedResult == "Purchased" and speedOwner.Cash == 0 and speedOwner.OwnedBoats.Speedboat, "Exact balance buys speedboat")
check(BoatData.decode(speedOwner).OwnedBoats.Speedboat, "Speedboat ownership survives profile decoding")
local speedAgain, speedAgainResult = BoatData.purchase(speedOwner, "Speedboat")
check(speedAgainResult == "AlreadyOwned" and speedAgain.Cash == 0, "Owned speedboat cannot charge again")
local speedPoor, speedPoorResult = BoatData.purchase({ Version = 1, Cash = 6499, OwnedBoats = {} }, "Speedboat")
check(speedPoorResult == "InsufficientFunds" and speedPoor.Cash == 6499 and not speedPoor.OwnedBoats.Speedboat, "Short balance cannot buy speedboat")
print("Speedboat catalog and purchase checks passed")

local Cargo = require("../src/shared/Cargo")
check(Catalog.PatrolBoat.Price == 25000, "Patrol cruiser costs exactly $25000")
check(Catalog.PatrolBoat.ForwardSpeed > Catalog.Speedboat.ForwardSpeed, "Patrol cruiser is faster than the $6500 speedboat")
check(Catalog.PatrolBoat.TurnRate < Catalog.Speedboat.TurnRate and Catalog.PatrolBoat.TurnRate >= Catalog.Speedboat.TurnRate * 0.85, "Patrol turns slightly slower")
check(Cargo.capacity(Catalog.PatrolBoat.Hold) == 2 * Cargo.capacity(Catalog.Speedboat.Hold), "Patrol has exactly twice the speedboat tiles")
local kit = {}
for _, item in Catalog.PatrolBoat.StarterParts do
	check(Cargo.fits(Catalog.PatrolBoat.Hold, Cargo.occupied(kit, {}), Cargo.shape(item, {}), item.X, item.Y, item.R), "Patrol starter equipment fits without overlap")
	table.insert(kit, item)
end
local patrolOwner, patrolResult = BoatData.purchase({ Version = 1, Cash = 25000, OwnedBoats = { Speedboat = true } }, "PatrolBoat")
check(patrolResult == "Purchased" and patrolOwner.Cash == 0 and patrolOwner.OwnedBoats.PatrolBoat and patrolOwner.OwnedBoats.Speedboat, "Exact funds buy patrol and preserve speedboat")
check(BoatData.decode(patrolOwner).OwnedBoats.PatrolBoat and patrolOwner.Angler.Stats.CoinsSpent == 25000, "Patrol ownership and spending persist")
local patrolAgain, patrolAgainResult = BoatData.purchase(patrolOwner, "PatrolBoat")
check(patrolAgainResult == "AlreadyOwned" and patrolAgain.Cash == 0, "Owned patrol cannot charge again")
local patrolPoor, patrolPoorResult = BoatData.purchase({ Version = 1, Cash = 24999, OwnedBoats = {} }, "PatrolBoat")
check(patrolPoorResult == "InsufficientFunds" and patrolPoor.Cash == 24999 and not patrolPoor.OwnedBoats.PatrolBoat, "Short balance cannot buy patrol")
print("Patrol cruiser catalog, cargo and purchase checks passed")

-- Racing launch trades fifteen tiles for the fastest handling in the fleet.
check(Catalog.RacingSpeedboat.Price == 12500, "Racing speedboat costs exactly $12500")
for id, spec in Catalog do
	if id ~= "RacingSpeedboat" then
		check(Catalog.RacingSpeedboat.ForwardSpeed > spec.ForwardSpeed, "Racing speedboat outruns " .. id)
		check(Catalog.RacingSpeedboat.TurnRate > spec.TurnRate, "Racing speedboat turns faster than " .. id)
	end
end
check(Cargo.capacity(Catalog.RacingSpeedboat.Hold) == 49, "Racing speedboat has 49 usable hold tiles")
check(Cargo.capacity(Catalog.FishingBoat.Hold) - Cargo.capacity(Catalog.RacingSpeedboat.Hold) == 15, "Racing hold sacrifices exactly fifteen tiles")
local racingKit = {}
for _, item in Catalog.RacingSpeedboat.StarterParts do
	check(Cargo.fits(Catalog.RacingSpeedboat.Hold, Cargo.occupied(racingKit, {}), Cargo.shape(item, {}), item.X, item.Y, item.R), "Racing starter equipment fits without overlap")
	table.insert(racingKit, item)
end
local racingInput = { Version = 1, Cash = 12500, OwnedBoats = { Speedboat = true } }
local racingOwner, racingResult = BoatData.purchase(racingInput, "RacingSpeedboat")
check(racingResult == "Purchased" and racingOwner.Cash == 0 and racingOwner.OwnedBoats.RacingSpeedboat, "Exact balance buys racing speedboat")
check(racingOwner.OwnedBoats.Speedboat and racingInput.Cash == 12500 and not racingInput.OwnedBoats.RacingSpeedboat, "Racing purchase preserves fleet and does not mutate saved input")
check(BoatData.decode(racingOwner).OwnedBoats.RacingSpeedboat, "Racing ownership survives saved-profile reload")
local racingAgain, racingAgainResult = BoatData.purchase(racingOwner, "RacingSpeedboat")
check(racingAgainResult == "AlreadyOwned" and racingAgain.Cash == 0, "Racing boat cannot charge twice")
local racingPoor, racingPoorResult = BoatData.purchase({ Version = 1, Cash = 12499, OwnedBoats = {} }, "RacingSpeedboat")
check(racingPoorResult == "InsufficientFunds" and racingPoor.Cash == 12499 and not racingPoor.OwnedBoats.RacingSpeedboat, "Short balance cannot buy racing speedboat")
print("Racing speedboat handling, cargo and purchase checks passed")
