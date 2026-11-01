-- Shark spear crate rewards. Colors are RGB triplets so this catalog can also
-- be used by the data and UI tests without Roblox globals.
local SpearSkins = {}

SpearSkins.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
SpearSkins.Rarities = {
	Common = { Color = { 196, 201, 205 } },
	Uncommon = { Color = { 111, 202, 125 } },
	Rare = { Color = { 86, 156, 240 } },
	Epic = { Color = { 186, 104, 240 } },
	Legendary = { Color = { 255, 196, 64 } },
}

-- Damage and FireRate are fractional bonuses, scaled by the rolled wear.
-- Ordinary rewards keep the standard spear silhouette; only the two highest
-- rarities introduce a different head shape.
SpearSkins.Skins = {
	Driftwood = {
		Name = "Driftwood Spear",
		Rarity = "Common",
		Description = "A weathered sea-washed finish.",
		Shape = "Standard",
		ShaftColor = { 148, 119, 84 },
		GripColor = { 84, 65, 48 },
		TipColor = { 170, 177, 177 },
		Damage = 0.05,
	},
	DeepBlue = {
		Name = "Deep Blue Spear",
		Rarity = "Common",
		Description = "Blue as the water beneath your boat.",
		Shape = "Standard",
		ShaftColor = { 48, 99, 137 },
		GripColor = { 30, 53, 72 },
		TipColor = { 175, 199, 208 },
		FireRate = 0.05,
	},
	Coral = {
		Name = "Coral Spear",
		Rarity = "Uncommon",
		Description = "A bright finish inspired by the reef.",
		Shape = "Standard",
		ShaftColor = { 222, 107, 91 },
		GripColor = { 123, 66, 61 },
		TipColor = { 230, 198, 166 },
		Damage = 0.08,
	},
	Seafoam = {
		Name = "Seafoam Spear",
		Rarity = "Uncommon",
		Description = "Pale green with a crisp sea breeze.",
		Shape = "Standard",
		ShaftColor = { 113, 194, 174 },
		GripColor = { 44, 102, 95 },
		TipColor = { 195, 226, 213 },
		FireRate = 0.08,
	},
	Obsidian = {
		Name = "Obsidian Spear",
		Rarity = "Rare",
		Description = "Dark metal with a sharp edge.",
		Shape = "Standard",
		ShaftColor = { 51, 53, 64 },
		GripColor = { 28, 27, 36 },
		TipColor = { 115, 119, 133 },
		Damage = 0.12,
	},
	Storm = {
		Name = "Storm Spear",
		Rarity = "Rare",
		Description = "A flash of silver in dark water.",
		Shape = "Standard",
		ShaftColor = { 112, 132, 158 },
		GripColor = { 49, 64, 88 },
		TipColor = { 214, 225, 235 },
		FireRate = 0.12,
	},
	ReefTrident = {
		Name = "Reef Trident",
		Rarity = "Epic",
		Description = "Three points forged for the open sea.",
		Shape = "Trident",
		ShaftColor = { 36, 139, 137 },
		GripColor = { 29, 77, 76 },
		TipColor = { 120, 222, 207 },
		Damage = 0.16,
	},
	GoldenHarpoon = {
		Name = "Golden Harpoon",
		Rarity = "Legendary",
		Description = "A gilded harpoon fit for a shark hunter.",
		Shape = "Harpoon",
		ShaftColor = { 176, 130, 49 },
		GripColor = { 83, 57, 31 },
		TipColor = { 255, 216, 111 },
		FireRate = 0.20,
	},
}

SpearSkins.CrateOrder = { "SpearCrate" }
SpearSkins.Crates = {
	SpearCrate = {
		Name = "Spear Crate",
		Description = "Sea-inspired spear finishes for shark hunters.",
		Price = 350,
		Odds = { Common = 0.675, Uncommon = 0.25, Rare = 0.05, Epic = 0.02, Legendary = 0.005 },
		Skins = { "Driftwood", "DeepBlue", "Coral", "Seafoam", "Obsidian", "Storm", "ReefTrident", "GoldenHarpoon" },
	},
}

-- Match rod wear bands exactly. Wear is rolled per copy and stays fixed.
SpearSkins.DefaultWear = 0.20
SpearSkins.WearStates = {
	{ Name = "Factory New", Max = 0.07, Multiplier = 1.20 },
	{ Name = "Minimal Wear", Max = 0.15, Multiplier = 1.10 },
	{ Name = "Field-Tested", Max = 0.38, Multiplier = 1.00 },
	{ Name = "Well-Worn", Max = 0.45, Multiplier = 0.90 },
	{ Name = "Battle-Scarred", Max = 1.01, Multiplier = 0.80 },
}

function SpearSkins.validWear(wear: any): boolean
	return type(wear) == "number" and wear >= 0 and wear <= 1
end

function SpearSkins.wearState(wear: number?): string
	local value = if SpearSkins.validWear(wear) then wear else SpearSkins.DefaultWear
	for _, state in SpearSkins.WearStates do
		if value < state.Max then
			return state.Name
		end
	end
	return "Battle-Scarred"
end

function SpearSkins.wearMultiplier(wear: number?): number
	local name = SpearSkins.wearState(wear)
	for _, state in SpearSkins.WearStates do
		if state.Name == name then
			return state.Multiplier
		end
	end
	return 1
end

function SpearSkins.valid(id: any): boolean
	return type(id) == "string" and SpearSkins.Skins[id] ~= nil
end

function SpearSkins.validCrate(id: any): boolean
	return type(id) == "string" and SpearSkins.Crates[id] ~= nil
end

function SpearSkins.rarity(skinId: string, _crateId: string?): string
	return SpearSkins.Skins[skinId].Rarity
end

function SpearSkins.roll(crateId: string, rarityPick: number, skinPick: number): string
	local crate = SpearSkins.Crates[crateId]
	local rarity = SpearSkins.RarityOrder[1]
	local remaining = rarityPick
	for _, name in SpearSkins.RarityOrder do
		local odds = crate.Odds[name] or 0
		if odds > 0 then
			rarity = name
			remaining -= odds
			if remaining < 0 then
				break
			end
		end
	end
	local pool = {}
	for _, id in crate.Skins do
		if SpearSkins.rarity(id, crateId) == rarity then
			table.insert(pool, id)
		end
	end
	return pool[math.clamp(math.floor(skinPick * #pool) + 1, 1, #pool)]
end

function SpearSkins.chance(crateId: string, skinId: string): number
	local crate = SpearSkins.Crates[crateId]
	if not table.find(crate.Skins, skinId) then
		return 0
	end
	local rarity = SpearSkins.rarity(skinId, crateId)
	local count = 0
	for _, id in crate.Skins do
		if SpearSkins.rarity(id, crateId) == rarity then
			count += 1
		end
	end
	return (crate.Odds[rarity] or 0) / count
end

function SpearSkins.boosts(skinId: string?, wear: number?)
	local skin = skinId and SpearSkins.Skins[skinId]
	local multiplier = SpearSkins.wearMultiplier(wear)
	return {
		damage = if skin then (skin.Damage or 0) * multiplier else 0,
		fireRate = if skin then (skin.FireRate or 0) * multiplier else 0,
	}
end

function SpearSkins.perks(skinId: string, wear: number?): { string }
	local boost = SpearSkins.boosts(skinId, wear)
	local lines = {}
	local function percent(value: number): string
		return string.format("%g", math.floor(value * 1000 + 0.5) / 10)
	end
	if boost.damage > 0 then
		table.insert(lines, string.format("+%s%% shark damage", percent(boost.damage)))
	end
	if boost.fireRate > 0 then
		table.insert(lines, string.format("+%s%% fire rate", percent(boost.fireRate)))
	end
	return lines
end

return SpearSkins
