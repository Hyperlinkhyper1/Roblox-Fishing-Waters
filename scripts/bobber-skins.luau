-- Pure economy, migration, odds and gameplay checks. Run: lute run scripts/bobber-skins.luau
local Data = require("../src/server/BoatData")
local Bobbers = require("../src/shared/BobberSkins")
local Rods = require("../src/shared/RodSkins")
local Upgrades = require("../src/shared/RodUpgrades")
local FishCatch = require("../src/shared/FishCatch")
local Mutations = require("../src/shared/FishMutations")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local crate = Bobbers.Crates.BobberCase
check(crate.Price == 350, "First bobber case costs $350")
local total, chances = 0, 0
local boundary = 0
for _, rarity in Bobbers.RarityOrder do
	total += crate.Odds[rarity]
	check(Bobbers.rarity(Bobbers.roll("BobberCase", boundary + 0.000001, 0)) == rarity, "Roll enters " .. rarity)
	boundary += crate.Odds[rarity]
	check(Bobbers.rarity(Bobbers.roll("BobberCase", boundary - 0.000001, 0.999999)) == rarity, "Roll leaves " .. rarity)
end
for _, id in crate.Skins do
	local skin = Bobbers.Skins[id]
	chances += Bobbers.chance("BobberCase", id)
	check(
		skin.Luck > 0 and skin.Luck <= 0.03 and skin.Mutation > 0 and skin.Mutation <= 0.001,
		"Budget case perks stay small"
	)
	check(#Bobbers.perks(id) == 2, "Both perks are displayed")
	if skin.Rarity ~= "Epic" and skin.Rarity ~= "Legendary" then
		check(not skin.NeonTop and not skin.Crown, "Lower rarities are only recolors")
	end
end
check(math.abs(total - 1) < 1e-9 and math.abs(chances - 1) < 1e-9, "Odds and individual reward chances total 100%")
check(
	Bobbers.roll("BobberCase", 0.999999, 0.999999) == "CrownedGoldBobber",
	"Highest roll awards the crowned legendary"
)
check(
	Bobbers.Skins.NeonPurpleBobber.NeonTop and Bobbers.Skins.NeonPurpleBobber.Bottom[1] < 20,
	"Epic uses neon purple and black"
)
check(Bobbers.Skins.CrownedGoldBobber.Crown, "Legendary has a crown")
local profile = Data.decode(nil)
check(next(profile.BobberSkins) == nil and profile.EquippedBobberSkin == nil, "New players keep the default bobber")
profile.BobberSkins = nil
profile = Data.decode(profile)
check(next(profile.BobberSkins) == nil, "Old profiles migrate without losing inventory")
profile.Cash = 349
check(
	Data.openBobberCrate(profile, "BobberCase", "CherryBobber") == "InsufficientFunds" and profile.Cash == 349,
	"Rejected purchases never charge"
)
profile.Cash = 700
check(Data.openBobberCrate(profile, "TideCrate", "CherryBobber") == "UnknownCrate", "Rod crates cannot award bobbers")
check(Data.openBobberCrate(profile, "BobberCase", "MageStaff") == "UnknownCrate", "Bobber cases reject rod rewards")
check(Data.equipBobberSkin(profile, "CrownedGoldBobber") == "NotOwned", "Unowned skins cannot be equipped")
check(Data.openBobberCrate(profile, "BobberCase", "CrownedGoldBobber") == "Opened", "Purchase succeeds")
Data.openBobberCrate(profile, "BobberCase", "CrownedGoldBobber")
check(
	profile.Cash == 0 and profile.BobberSkins.CrownedGoldBobber == 2 and profile.Angler.Stats.CoinsSpent == 700,
	"Duplicate copies charge and count independently"
)
check(Data.equipBobberSkin(profile, "CrownedGoldBobber") == "Equipped", "Owned skins equip")
local reloaded = Data.decode(profile)
check(
	reloaded.EquippedBobberSkin == "CrownedGoldBobber" and reloaded.BobberSkins.CrownedGoldBobber == 2,
	"Selection and copies survive reload"
)
reloaded.BobberSkins.CrownedGoldBobber = 99
check(profile.BobberSkins.CrownedGoldBobber == 2, "Decoded snapshots cannot mutate the saved inventory")
reloaded.EquippedBobberSkin = "BlueBobber"
check(Data.decode(reloaded).EquippedBobberSkin == nil, "An unowned saved selection resets safely")
reloaded.BobberSkins.RetiredBobber = 1
check(Data.decode(reloaded).BobberSkins.RetiredBobber == nil, "Retired skins do not break saves")
reloaded.BobberSkins.CherryBobber = -1
check(not pcall(Data.decode, reloaded), "Malformed bobber counts are rejected")
local base = Rods.apply(Upgrades.boosts({ Luck = 2 }), "MageStaff")
local boosted = Bobbers.apply(base, "CrownedGoldBobber")
check(
	math.abs(boosted.luck - 0.09) < 1e-9 and math.abs(boosted.mutation - 0.021) < 1e-9,
	"Bobber perks stack with upgrades and rod skin"
)
check(
	base.luck == 0.06 and base.mutation == 0.02 and boosted.reel == base.reel,
	"Applying bobber perks preserves other stats and the input"
)
check(Bobbers.apply(base, nil).mutation == base.mutation, "Default bobber adds no perk")
local species = { CommonFish = { RarityDenominator = 1 }, RareFish = { RarityDenominator = 100 } }
local pool = { Fish = { "CommonFish", "RareFish" } }
local function pick()
	return 0.9895
end
check(
	FishCatch.pickSpecies(pool, species, pick, 0) == "CommonFish"
		and FishCatch.pickSpecies(pool, species, pick, 0.03) == "RareFish",
	"Bobber luck reaches the actual species roll"
)
local function mutationPick()
	return Mutations.CHANCE + 0.0005
end
local fish = { Rarity = "Common" }
check(
	Mutations.roll(fish, false, mutationPick).Mutation == "Normal"
		and Mutations.roll(fish, false, mutationPick, Bobbers.apply({ luck = 0 }, "CrownedGoldBobber")).Mutation
			~= "Normal",
	"Bobber mutation perk reaches the actual mutation roll"
)
Data.equipBobberSkin(profile, nil)
check(
	Data.decode(profile).EquippedBobberSkin == nil and profile.BobberSkins.CrownedGoldBobber == 2,
	"Resetting the look keeps owned copies"
)
print(`Bobber skins: {checks} economy, migration, odds and gameplay checks passed.`)
