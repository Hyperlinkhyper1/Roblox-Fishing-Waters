local SpearSkins = require("../src/shared/SpearSkins")
local RodSkins = require("../src/shared/RodSkins")

local function check(condition, message)
	assert(condition, message)
end

local crate = SpearSkins.Crates.SpearCrate
check(crate.Price == 350, "Spear crate costs $350")
local total = 0
for _, id in crate.Skins do
	local skin = SpearSkins.Skins[id]
	check(SpearSkins.valid(id), "Crate skin exists")
	local hasDamage = (skin.Damage or 0) > 0
	local hasFireRate = (skin.FireRate or 0) > 0
	check(hasDamage ~= hasFireRate, "Each skin boosts exactly one stat")
	check(skin.Shape == "Standard" or skin.Rarity == "Epic" or skin.Rarity == "Legendary", "Special shapes are rare")
	total += SpearSkins.chance("SpearCrate", id)
end
check(math.abs(total - 1) < 1e-9, "All reward chances add up to one")
check(SpearSkins.roll("SpearCrate", 0, 0) == "Driftwood", "Common roll")
check(SpearSkins.roll("SpearCrate", 0.926, 0) == "Obsidian", "Rare roll")
check(SpearSkins.roll("SpearCrate", 0.976, 0) == "ReefTrident", "Epic roll")
check(SpearSkins.roll("SpearCrate", 0.999, 0) == "GoldenHarpoon", "Legendary roll")
for _, wear in { 0, 0.07, 0.15, 0.38, 0.45, 1 } do
	check(SpearSkins.wearState(wear) == RodSkins.wearState(wear), "Wear labels match rods")
	check(SpearSkins.wearMultiplier(wear) == RodSkins.wearMultiplier(wear), "Wear multipliers match rods")
end
check(SpearSkins.boosts("Driftwood", 0).damage > SpearSkins.boosts("Driftwood", 1).damage, "Wear affects damage")
check(SpearSkins.boosts("DeepBlue", 0).fireRate > SpearSkins.boosts("DeepBlue", 1).fireRate, "Wear affects fire rate")
check(
	SpearSkins.boosts(nil, 0).damage == 0 and SpearSkins.boosts("missing", 0).fireRate == 0,
	"Unknown skin adds no bonus"
)
print("Spear skins passed")
