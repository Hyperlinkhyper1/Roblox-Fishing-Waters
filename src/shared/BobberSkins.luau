-- Budget bobber skins. Luck uses the same rarity bias as Finn's upgrades;
-- Mutation adds percentage points to the mutation roll. Only one skin contributes.
local BobberSkins = {}

BobberSkins.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
BobberSkins.Rarities = {
	Common = { Color = { 196, 201, 205 } },
	Uncommon = { Color = { 111, 202, 125 } },
	Rare = { Color = { 86, 156, 240 } },
	Epic = { Color = { 186, 104, 240 } },
	Legendary = { Color = { 255, 196, 64 } },
}
BobberSkins.Skins = {
	CherryBobber = {
		Name = "Cherry Bobber",
		Rarity = "Common",
		Top = { 221, 66, 73 },
		Bottom = { 248, 239, 218 },
		Luck = 0.005,
		Mutation = 0.0001,
	},
	BlueBobber = {
		Name = "Blue Bobber",
		Rarity = "Common",
		Top = { 64, 139, 224 },
		Bottom = { 248, 239, 218 },
		Luck = 0.005,
		Mutation = 0.0001,
	},
	MintBobber = {
		Name = "Mint Bobber",
		Rarity = "Uncommon",
		Top = { 93, 201, 153 },
		Bottom = { 235, 251, 242 },
		Luck = 0.01,
		Mutation = 0.0002,
	},
	OrangeBobber = {
		Name = "Orange Bobber",
		Rarity = "Uncommon",
		Top = { 241, 151, 60 },
		Bottom = { 255, 232, 191 },
		Luck = 0.01,
		Mutation = 0.0002,
	},
	RoseBobber = {
		Name = "Rose Bobber",
		Rarity = "Rare",
		Top = { 231, 116, 169 },
		Bottom = { 95, 48, 92 },
		Luck = 0.015,
		Mutation = 0.0004,
	},
	NeonPurpleBobber = {
		Name = "Neon Purple Bobber",
		Rarity = "Epic",
		Top = { 178, 48, 255 },
		Bottom = { 15, 13, 20 },
		NeonTop = true,
		Luck = 0.02,
		Mutation = 0.0007,
	},
	CrownedGoldBobber = {
		Name = "Crowned Gold Bobber",
		Rarity = "Legendary",
		Top = { 255, 199, 65 },
		Bottom = { 207, 147, 34 },
		Crown = true,
		Luck = 0.03,
		Mutation = 0.001,
	},
}

BobberSkins.CrateOrder = { "BobberCase" }
BobberSkins.Crates = {
	BobberCase = {
		Name = "Bobber Case",
		Description = "Simple recolors with small luck and mutation perks. Epic and legendary have special finishes.",
		Price = 350,
		Odds = { Common = 0.675, Uncommon = 0.25, Rare = 0.05, Epic = 0.02, Legendary = 0.005 },
		Skins = {
			"CherryBobber",
			"BlueBobber",
			"MintBobber",
			"OrangeBobber",
			"RoseBobber",
			"NeonPurpleBobber",
			"CrownedGoldBobber",
		},
	},
}

function BobberSkins.valid(id: any): boolean
	return type(id) == "string" and BobberSkins.Skins[id] ~= nil
end

function BobberSkins.validCrate(id: any): boolean
	return type(id) == "string" and BobberSkins.Crates[id] ~= nil
end

function BobberSkins.rarity(id: string, _crateId: string?): string
	return BobberSkins.Skins[id].Rarity
end

function BobberSkins.roll(crateId: string, rarityPick: number, skinPick: number): string
	local crate = BobberSkins.Crates[crateId]
	local rarity = BobberSkins.RarityOrder[1]
	for _, name in BobberSkins.RarityOrder do
		rarity = name
		rarityPick -= crate.Odds[name]
		if rarityPick < 0 then
			break
		end
	end
	local pool = {}
	for _, id in crate.Skins do
		if BobberSkins.rarity(id) == rarity then
			table.insert(pool, id)
		end
	end
	return pool[math.clamp(math.floor(skinPick * #pool) + 1, 1, #pool)]
end

function BobberSkins.chance(crateId: string, skinId: string): number
	local crate = BobberSkins.Crates[crateId]
	if not table.find(crate.Skins, skinId) then
		return 0
	end
	local rarity, count = BobberSkins.rarity(skinId), 0
	for _, id in crate.Skins do
		if BobberSkins.rarity(id) == rarity then
			count += 1
		end
	end
	return crate.Odds[rarity] / count
end

function BobberSkins.apply(boosts, skinId: string?)
	local result = table.clone(boosts)
	local skin = skinId and BobberSkins.Skins[skinId]
	if skin then
		result.luck = (result.luck or 0) + skin.Luck
		result.mutation = (result.mutation or 0) + skin.Mutation
	end
	return result
end

function BobberSkins.perks(skinId: string): { string }
	local skin = BobberSkins.Skins[skinId]
	return {
		string.format("+%g%% luck", skin.Luck * 100),
		string.format("+%g%% mutation chance", skin.Mutation * 100),
	}
end

return BobberSkins
