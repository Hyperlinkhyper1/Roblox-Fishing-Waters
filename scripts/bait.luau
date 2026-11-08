-- Bait rules and profile transactions. Run: lute run scripts/bait.luau
local Bait = require("../src/shared/Bait")
local BoatData = require("../src/server/BoatData")

local checks = 0
local function check(condition: boolean, message: string)
	checks += 1
	assert(condition, message)
end

-- Catalog shape.
local oddsTotal = 0
for _, rarity in Bait.RarityOrder do
	oddsTotal += Bait.Crate.Odds[rarity]
end
check(math.abs(oddsTotal - 1) < 1e-9, "Crate rarity odds add up to 1")
check(Bait.Crate.Price == 25, "A bait crate costs $25")
check(Bait.Crate.MinBait == 7 and Bait.Crate.MaxBait == 15, "A crate holds 7-15 bait")
for index, id in Bait.Order do
	local bait = Bait.Types[id]
	check(bait ~= nil and Bait.Rarities[bait.Rarity] ~= nil, id .. " has a known rarity")
	check(Bait.Crate.Odds[bait.Rarity] > 0, id .. " can come out of a crate")
	if index > 1 then
		check(bait.Luck > Bait.Types[Bait.Order[index - 1]].Luck, id .. " is luckier than the bait before it")
	end
end
check(Bait.Types.Worm.Rarity == "Common", "Worms are the common bait")
check(Bait.Types.Worm.Size == nil and Bait.Types.Worm.Mutation == nil, "Worms only add luck")
check(Bait.FISH_UP_CHANCE > 0 and Bait.FISH_UP_CHANCE < 0.1, "Fishing up a crate is a low chance")

-- Rolls cover every bait and stay inside the amount range.
local seen = {}
for rarity = 0, 0.999, 0.001 do
	local id, amount = Bait.roll(rarity, (rarity * 7.3) % 1)
	seen[id] = true
	check(Bait.valid(id), "Rolls return real bait")
	check(amount >= 7 and amount <= 15 and amount % 1 == 0, "Rolled amounts stay within 7-15")
end
for _, id in Bait.Order do
	check(seen[id], id .. " can be rolled")
end
check(select(2, Bait.roll(0, 0)) == 7 and select(2, Bait.roll(0, 0.99999)) == 15, "Amount picks reach both ends")
check(Bait.roll(0, 0) == "Worm", "The lowest rarity pick is a worm")
check(Bait.roll(0.99999, 0) == "Glowworm", "The highest rarity pick is the legendary bait")

-- Boosts stack on the rod's.
local base = { luck = 0.1, size = 1.2, reel = 1.1, handling = 1, mutation = 0 }
local wormed = Bait.apply(base, "Worm")
check(math.abs(wormed.luck - 0.13) < 1e-9 and wormed.size == 1.2 and wormed.reel == 1.1, "Worms add only luck")
check(base.luck == 0.1, "Applying bait doesn't change the rod's boosts")
local glow = Bait.apply(base, "Glowworm")
check(glow.size > base.size and glow.reel > base.reel and glow.mutation > 0, "Rare bait improves other stats")
check(Bait.apply(base, nil).luck == base.luck, "No bait adds nothing")
check(#Bait.perks("Worm") == 1 and #Bait.perks("Glowworm") == 4, "Perk text lists each stat")

-- Profile transactions.
local profile = BoatData.decode(nil)
check(profile.BaitCrates == 0 and next(profile.Bait) == nil and profile.EquippedBait == nil, "New players have no bait")
check(BoatData.buyBaitCrates(profile, 1) == "InsufficientFunds", "Crates cost money")
profile.Cash = 200
check(BoatData.buyBaitCrates(profile, 2) == "InvalidCount", "Only Finn's batch sizes can be bought")
check(BoatData.buyBaitCrates(profile, 5) == "Purchased", "Five crates can be bought")
check(profile.Cash == 75 and profile.BaitCrates == 5, "Five crates cost $125")
check(profile.Angler.Stats.CoinsSpent == 125, "Crate spending counts as coins spent")
check(BoatData.buyBaitCrates(profile, 5) == "InsufficientFunds" and profile.BaitCrates == 5, "Short wallets buy nothing")

check(BoatData.openBaitCrate(profile, "Nope", 9) == "UnknownBait", "Unknown bait is rejected")
check(BoatData.openBaitCrate(profile, "Worm", 9) == "Opened", "An owned crate opens")
check(profile.BaitCrates == 4 and profile.Bait.Worm == 9, "Opening moves the bait into the tin")
check(profile.EquippedBait == "Worm", "The first bait goes straight on the hook")
check(BoatData.openBaitCrate(profile, "Shrimp", 7) == "Opened", "A second crate opens")
check(profile.EquippedBait == "Worm", "Opening more bait keeps the current bait on the hook")

check(BoatData.equipBait(profile, "Squid") == "NotOwned", "Unowned bait can't be equipped")
check(BoatData.equipBait(profile, "Shrimp") == "Equipped" and profile.EquippedBait == "Shrimp", "Owned bait equips")
check(BoatData.equipBait(profile, nil) == "Equipped" and profile.EquippedBait == nil, "Bait can be taken off")
BoatData.equipBait(profile, "Shrimp")

for _ = 1, 6 do
	check(BoatData.consumeBait(profile, "Shrimp") == "Consumed", "Reeling in uses one bait")
end
check(profile.Bait.Shrimp == 1 and profile.EquippedBait == "Shrimp", "Bait stays on the hook while some is left")
check(BoatData.consumeBait(profile, "Shrimp") == "Consumed", "The last bait is used")
check(profile.Bait.Shrimp == nil and profile.EquippedBait == nil, "Running out empties the hook")
check(BoatData.consumeBait(profile, "Shrimp") == "NoBait", "Empty bait can't be used")

local empty = BoatData.decode(nil)
check(BoatData.openBaitCrate(empty, "Worm", 7) == "NoCrate", "Crates must be owned to open")

-- Saves round-trip and old/malformed saves are handled.
local saved = BoatData.decode(profile)
check(saved.BaitCrates == 3 and saved.Bait.Worm == 9 and saved.EquippedBait == nil, "Bait survives a save")
saved.EquippedBait = "Worm"
check(BoatData.decode(saved).EquippedBait == "Worm", "Equipped bait survives a save")
local old = { Version = 1, Cash = 10, OwnedBoats = {} }
local migrated = BoatData.decode(old)
check(migrated.BaitCrates == 0 and next(migrated.Bait) == nil, "Profiles from before bait load with an empty tin")
check(
	BoatData.decode({ Version = 1, Cash = 0, OwnedBoats = {}, Bait = { Retired = 3, Worm = 2 }, EquippedBait = "Retired" }).EquippedBait
		== nil,
	"Retired bait is dropped"
)
check(not pcall(BoatData.decode, { Version = 1, Cash = 0, OwnedBoats = {}, BaitCrates = -1 }), "Negative crates are rejected")
check(not pcall(BoatData.decode, { Version = 1, Cash = 0, OwnedBoats = {}, Bait = { Worm = 1.5 } }), "Fractional bait is rejected")

print(string.format("bait: %d checks passed", checks))
