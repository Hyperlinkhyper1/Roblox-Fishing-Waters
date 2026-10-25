-- Pure rod crate checks: odds, rolls, saved skins, the wallet transaction and
-- the catch / mutation bonuses. Run: lute run scripts/rod-skins.luau. No Roblox runtime.
local BoatData = require("../src/server/BoatData")
local FishMutations = require("../src/shared/FishMutations")
local RodSkins = require("../src/shared/RodSkins")
local RodUpgrades = require("../src/shared/RodUpgrades")

local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

-- The crate's rarity odds and the per-skin chances both add up to 100%.
local crate = RodSkins.Crates.TideCrate
check(crate.Price == 350, "The Tide Crate costs $350")
local oddsTotal, skinTotal = 0, 0
for _, rarity in RodSkins.RarityOrder do
	oddsTotal += crate.Odds[rarity]
end
for _, id in crate.Skins do
	check(RodSkins.valid(id), id .. " must be a catalog skin")
	skinTotal += RodSkins.chance("TideCrate", id)
end
check(math.abs(oddsTotal - 1) < 1e-9 and math.abs(skinTotal - 1) < 1e-9, "Crate odds must add up to 100%")
check(crate.Odds.Common == 0.675 and crate.Odds.Legendary == 0.005, "Crate odds match the design")
check(math.abs(RodSkins.chance("TideCrate", "MageStaff") - 0.005) < 1e-12, "Mage Staff is the 0.5% legendary")
check(math.abs(RodSkins.chance("TideCrate", "UmbrellaRod") - 0.3375) < 1e-12, "Commons split their 67.5%")

-- Rolls land on the boundaries the odds promise.
check(RodSkins.roll("TideCrate", 0, 0) == "UmbrellaRod", "Lowest pick is the first common")
check(RodSkins.roll("TideCrate", 0.6749, 0.99) == "BambooRod", "Last common pick")
check(RodSkins.roll("TideCrate", 0.676, 0) == "BoneRod", "First uncommon pick")
check(RodSkins.roll("TideCrate", 0.926, 0) == "BaguetteRod", "Rare band")
check(RodSkins.roll("TideCrate", 0.976, 0) == "NightRod", "Epic band")
check(RodSkins.roll("TideCrate", 0.996, 0) == "MageStaff", "Legendary band")
check(RodSkins.roll("TideCrate", 0.99999999, 0.99999999) == "MageStaff", "Top pick stays legendary")
math.randomseed(7)
local counts = {}
local ROLLS = 200000
for _ = 1, ROLLS do
	local id = RodSkins.roll("TideCrate", math.random(), math.random())
	counts[id] = (counts[id] or 0) + 1
end
for _, id in crate.Skins do
	local expected = RodSkins.chance("TideCrate", id)
	check(math.abs((counts[id] or 0) / ROLLS - expected) < 0.004, id .. " rolls near its stated chance")
end

-- Rarer skins are never weaker, and every skin boosts speed and/or strength.
local previousPower = -1
for _, rarity in RodSkins.RarityOrder do
	local best = 0
	for _, id in crate.Skins do
		local skin = RodSkins.Skins[id]
		if skin.Rarity == rarity then
			check((skin.Reel or 0) + (skin.Size or 0) > 0, id .. " adds speed or strength")
			best = math.max(best, (skin.Reel or 0) + (skin.Size or 0))
		end
	end
	check(best > previousPower, rarity .. " skins outclass the rarity below")
	previousPower = best
end
check(RodSkins.Skins.NightRod.Astral == 0.04, "Night Rod adds 4% Astral (the night mutation)")
check(RodSkins.Skins.MageStaff.Mutation == 0.02, "Mage Staff adds 2% mutation chance")

-- Skin stats stack on top of the angler's upgrades.
local base = RodUpgrades.boosts({ Speed = 2, Strength = 1 })
local staff = RodSkins.apply(base, "MageStaff")
check(
	math.abs(staff.reel - (base.reel + 0.2)) < 1e-9 and math.abs(staff.size - (base.size + 0.4)) < 1e-9,
	"Staff stacks"
)
check(staff.mutation == 0.02 and staff.astral == 0 and staff.luck == base.luck, "Staff mutation bonus only")
local plain = RodSkins.apply(base, nil)
check(plain.reel == base.reel and plain.mutation == 0 and plain.astral == 0, "No skin adds nothing")
check(RodSkins.apply(base, "Bogus").reel == base.reel, "Unknown skins add nothing")
check(base.mutation == nil, "apply must not mutate the upgrade boosts")

-- Mutation bonuses: none changes nothing, the staff adds 2%, the night rod adds 4% Astral after dark.
local trout = { Rarity = "Common" }
local function rate(bonus, night: boolean, key: string?)
	math.randomseed(11)
	local rng = math.random
	local hits = 0
	for _ = 1, ROLLS do
		local traits = FishMutations.roll(trout, night, rng, bonus)
		local parts = FishMutations.parts(traits.Mutation)
		if (key == nil and traits.Mutation ~= "Normal") or (key and parts[key]) then
			hits += 1
		end
	end
	return hits / ROLLS
end
check(math.abs(rate(nil, false) - FishMutations.CHANCE) < 0.001, "Plain rods keep the base mutation chance")
check(math.abs(rate(staff, false) - (FishMutations.CHANCE + 0.02)) < 0.002, "Mage Staff adds 2% mutation chance")
local night = RodSkins.apply(base, "NightRod")
check(
	math.abs(rate(night, true, "Astral") - (FishMutations.ASTRAL_CHANCE + 0.04)) < 0.002,
	"Night Rod adds 4% Astral at night"
)
check(rate(night, false, "Astral") == 0, "Astral never appears by day, even with the Night Rod")
check(math.abs(rate(night, false) - FishMutations.CHANCE) < 0.001, "Night Rod adds nothing by day")
check(FishMutations.roll({ Rarity = "Junk" }, true, function()
	return 0
end, staff).Mutation == "Normal", "Junk never mutates, even with a skin")

-- Saved skins: counts survive, unknown skins are dropped, bad data is rejected.
local fresh = BoatData.decode(nil)
check(next(fresh.RodSkins) == nil and fresh.EquippedRodSkin == nil, "New players own no skins")
local legacy = BoatData.decode({ Version = 1, Cash = 0, OwnedBoats = {} })
check(next(legacy.RodSkins) == nil, "Old saves migrate with no skins")
local saved = BoatData.decode({
	Version = 1,
	Cash = 0,
	OwnedBoats = {},
	RodSkins = { BoneRod = 2, RetiredRod = 1 },
	EquippedRodSkin = "RetiredRod",
})
check(saved.RodSkins.BoneRod == 2 and saved.RodSkins.RetiredRod == nil, "Retired skins are dropped")
check(saved.EquippedRodSkin == nil, "An equipped skin that is no longer owned falls back to the starter look")
check(not pcall(BoatData.decode, { Version = 1, Cash = 0, OwnedBoats = {}, RodSkins = { BoneRod = 1.5 } }), "Bad count")
check(not pcall(BoatData.decode, { Version = 1, Cash = 0, OwnedBoats = {}, EquippedRodSkin = 5 }), "Bad equip")

-- Opening a crate: needs the rod and $350, pays once, adds one copy.
local profile = BoatData.decode({ Version = 1, Cash = 1000, OwnedBoats = {}, OwnedRods = {} })
profile.OwnedRods.StarterRod = nil
check(BoatData.openRodCrate(profile, "TideCrate", "BoneRod") == "NoRod" and profile.Cash == 1000, "Crates need a rod")
profile.OwnedRods.StarterRod = true
check(BoatData.openRodCrate(profile, "TideCrate", "Bogus") == "UnknownCrate", "Skins must come from the crate")
check(BoatData.openRodCrate(profile, "Nope", "BoneRod") == "UnknownCrate", "Unknown crates are refused")
check(BoatData.openRodCrate(profile, "TideCrate", "BoneRod") == "Opened", "A crate opens")
check(profile.Cash == 650 and profile.RodSkins.BoneRod == 1, "A crate costs $350 and adds the skin")
check(profile.Angler.Stats.CoinsSpent == 350, "Crate spend counts as coins spent")
BoatData.openRodCrate(profile, "TideCrate", "BoneRod")
check(profile.RodSkins.BoneRod == 2 and profile.Cash == 300, "Duplicates stack")
check(BoatData.openRodCrate(profile, "TideCrate", "BoneRod") == "InsufficientFunds" and profile.Cash == 300, "No debt")
local roundTrip = BoatData.decode(profile)
check(roundTrip.RodSkins.BoneRod == 2, "Skin counts save")
check(
	#roundTrip.RodSkinCopies == 2 and roundTrip.RodSkinCopies[1].Serial == 1 and roundTrip.RodSkinCopies[2].Serial == 2,
	"Duplicate copies keep separate serials after reload"
)
check(roundTrip.NextRodSkinSerial.BoneRod == 3, "The next serial survives reload")
roundTrip.Cash = 350
local outcome, serial = BoatData.openRodCrate(roundTrip, "TideCrate", "MageStaff")
check(outcome == "Opened" and serial == 1, "A different skin starts its own serial sequence")
local migrated = BoatData.decode({
	Version = 1,
	Cash = 0,
	OwnedBoats = {},
	RodSkins = { BoneRod = 2, BambooRod = 1 },
	EquippedRodSkin = "BoneRod",
})
check(
	#migrated.RodSkinCopies == 3 and migrated.RodSkinCopies[1].SkinId == "BambooRod",
	"Existing rewards migrate in a stable order"
)
local migratedAgain = BoatData.decode(migrated)
check(
	migratedAgain.RodSkinCopies[2].Serial == migrated.EquippedRodSkinSerial
		and migratedAgain.NextRodSkinSerial.BoneRod == 3
		and migratedAgain.NextRodSkinSerial.BambooRod == 2,
	"Migration does not renumber saved copies"
)
-- Migrate the old collection-wide sequence without losing the selected copy.
local globalSerials = BoatData.decode({
	Version = 1,
	Cash = 700,
	OwnedBoats = {},
	RodSkinCopies = {
		{ SkinId = "BoneRod", Serial = 8 },
		{ SkinId = "BambooRod", Serial = 3 },
		{ SkinId = "BoneRod", Serial = 5 },
	},
	NextRodSkinSerial = 9,
	EquippedRodSkin = "BoneRod",
	EquippedRodSkinSerial = 8,
})
check(
	globalSerials.RodSkinCopies[1].SkinId == "BambooRod" and globalSerials.RodSkinCopies[1].Serial == 1,
	"Each migrated skin starts at one"
)
check(
	globalSerials.EquippedRodSkin == "BoneRod" and globalSerials.EquippedRodSkinSerial == 2,
	"Migration preserves the selected copy even when the old array is reordered"
)
local migratedReload = BoatData.decode(globalSerials)
check(
	migratedReload.EquippedRodSkinSerial == 2
		and migratedReload.NextRodSkinSerial.BoneRod == 3
		and migratedReload.NextRodSkinSerial.BambooRod == 2,
	"Migration is stable on reload"
)
local _, bambooSerial = BoatData.openRodCrate(migratedReload, "TideCrate", "BambooRod")
local _, boneSerial = BoatData.openRodCrate(migratedReload, "TideCrate", "BoneRod")
check(bambooSerial == 2 and boneSerial == 3, "Opening one skin never advances another skin's sequence")
local sparse = BoatData.decode({
	Version = 1,
	Cash = 350,
	OwnedBoats = {},
	RodSkinCopies = { { SkinId = "BoneRod", Serial = 4 }, { SkinId = "BambooRod", Serial = 4 } },
	NextRodSkinSerial = { BoneRod = 9, BambooRod = 2 },
	EquippedRodSkin = "BambooRod",
	EquippedRodSkinSerial = 4,
})
check(
	sparse.NextRodSkinSerial.BambooRod == 5 and sparse.NextRodSkinSerial.BoneRod == 9,
	"Counters recover per skin and never reuse old serials"
)
check(
	sparse.EquippedRodSkin == "BambooRod" and sparse.EquippedRodSkinSerial == 4,
	"The same serial can belong to different skins"
)
local sparseSnapshot = BoatData.decode(sparse)
sparseSnapshot.NextRodSkinSerial.BambooRod = 50
check(sparse.NextRodSkinSerial.BambooRod == 5, "Decoding uses independent serial counter tables")

roundTrip.RodSkinCopies[1].Serial = 99
check(profile.RodSkinCopies[1].Serial == 1, "Decoded copies are independent of cached inventory")
local bad = BoatData.decode(profile)
bad.RodSkinCopies[2].Serial = 1
check(not pcall(BoatData.decode, bad), "Duplicate saved serials cannot overwrite ownership")

-- Equipping: only owned skins; nil returns to the starter look.
check(BoatData.equipRodSkin(profile, "MageStaff") == "NotOwned", "Unowned skins cannot be equipped")
check(BoatData.equipRodSkin(profile, "Bogus") == "UnknownSkin", "Unknown skins cannot be equipped")
check(BoatData.equipRodSkin(profile, "BoneRod") == "Equipped" and profile.EquippedRodSkin == "BoneRod", "Equip")
check(BoatData.decode(profile).EquippedRodSkin == "BoneRod", "The equipped skin saves")
check(
	BoatData.equipRodSkin(profile, "BoneRod", 2) == "Equipped" and BoatData.decode(profile).EquippedRodSkinSerial == 2,
	"Selecting a particular duplicate persists"
)
check(
	BoatData.equipRodSkin(profile, "BoneRod", 3) == "NotOwned" and profile.EquippedRodSkinSerial == 2,
	"Forged serials cannot select unowned copies"
)
check(BoatData.equipRodSkin(profile, "MageStaff", 2) == "NotOwned", "A serial cannot be used with another skin")
check(BoatData.equipRodSkin(profile, nil) == "Equipped" and profile.EquippedRodSkin == nil, "Back to starter")
check(profile.EquippedRodSkinSerial == nil, "Plain look clears the equipped serial")

print(`Rod skins: {checks} checks passed (pure rules; no Roblox runtime)`)
