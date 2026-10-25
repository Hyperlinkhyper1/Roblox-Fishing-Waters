-- Rod skins won from crates at the Tide & Tackle counter. A skin restyles the
-- angler's one rod and adds base stats on top of Finn's upgrades; rarer skins
-- also raise mutation odds. Pure data and rules: the server rolls and saves,
-- CatchService applies the stats, and clients only present them. No Roblox
-- globals here, so BoatData can load it in tests.
local RodSkins = {}

RodSkins.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
RodSkins.Rarities = {
	Common = { Color = { 196, 201, 205 } },
	Uncommon = { Color = { 111, 202, 125 } },
	Rare = { Color = { 86, 156, 240 } },
	Epic = { Color = { 186, 104, 240 } },
	Legendary = { Color = { 255, 196, 64 } },
}

-- Reel adds to the reel progress per hit (0.05 = +5%), Size to the big and huge
-- fish odds (0.1 = +10%), Mutation to the chance of any mutation, and Astral to
-- the chance of the night-only Astral mutation after dark.
RodSkins.Skins = {
	UmbrellaRod = {
		Name = "Umbrella Rod",
		Rarity = "Common",
		Description = "A sturdy brolly with a line through the tip. Rain or shine.",
		Reel = 0.05,
		Size = 0,
	},
	BambooRod = {
		Name = "Bamboo Rod",
		Rarity = "Common",
		Description = "Hand-cut cane, light and springy.",
		Reel = 0,
		Size = 0.1,
	},
	BoneRod = {
		Name = "Bone Rod",
		Rarity = "Uncommon",
		Description = "Carved from something big that didn't get away.",
		Reel = 0,
		Size = 0.25,
	},
	LanternRod = {
		Name = "Lantern Rod",
		Rarity = "Uncommon",
		Description = "A little lantern lights the way to the bite.",
		Reel = 0.08,
		Size = 0.1,
	},
	BaguetteRod = {
		Name = "Baguette Rod",
		Rarity = "Rare",
		Description = "Freshly baked, surprisingly stiff. Do not eat.",
		Reel = 0.12,
		Size = 0.2,
	},
	NightRod = {
		Name = "Night Rod",
		Rarity = "Epic",
		Description = "Forged under a new moon. Astral fish answer its call after dark.",
		Reel = 0.15,
		Size = 0.3,
		Astral = 0.04,
	},
	MageStaff = {
		Name = "Mage Staff",
		Rarity = "Legendary",
		Description = "An old sorcerer's staff, still humming with magic.",
		Reel = 0.2,
		Size = 0.4,
		Mutation = 0.02,
	},
}

RodSkins.CrateOrder = { "TideCrate" }
RodSkins.Crates = {
	TideCrate = {
		Name = "Tide Crate",
		Description = "The first crate of rods from Finn's back room.",
		Price = 350,
		Odds = { Common = 0.675, Uncommon = 0.25, Rare = 0.05, Epic = 0.02, Legendary = 0.005 },
		Skins = { "UmbrellaRod", "BambooRod", "BoneRod", "LanternRod", "BaguetteRod", "NightRod", "MageStaff" },
	},
}

function RodSkins.valid(id: any): boolean
	return type(id) == "string" and RodSkins.Skins[id] ~= nil
end

function RodSkins.validCrate(id: any): boolean
	return type(id) == "string" and RodSkins.Crates[id] ~= nil
end

-- Rolls one skin from a crate with two uniform [0, 1) picks: the first picks the
-- rarity, the second a skin of that rarity.
function RodSkins.roll(crateId: string, rarityPick: number, skinPick: number): string
	local crate = RodSkins.Crates[crateId]
	local rarity = RodSkins.RarityOrder[1]
	local remaining = rarityPick
	for _, name in RodSkins.RarityOrder do
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
		if RodSkins.Skins[id].Rarity == rarity then
			table.insert(pool, id)
		end
	end
	return pool[math.clamp(math.floor(skinPick * #pool) + 1, 1, #pool)]
end

-- Chance of one specific skin from a crate.
function RodSkins.chance(crateId: string, skinId: string): number
	local crate = RodSkins.Crates[crateId]
	local rarity = RodSkins.Skins[skinId].Rarity
	local count = 0
	for _, id in crate.Skins do
		if RodSkins.Skins[id].Rarity == rarity then
			count += 1
		end
	end
	return if table.find(crate.Skins, skinId) then (crate.Odds[rarity] or 0) / count else 0
end

-- Adds a skin's stats to RodUpgrades.boosts; nil or unknown skins add nothing.
function RodSkins.apply(boosts, skinId: string?)
	local skin = skinId and RodSkins.Skins[skinId]
	local result = table.clone(boosts)
	result.mutation, result.astral = 0, 0
	if skin then
		result.reel += skin.Reel or 0
		result.size += skin.Size or 0
		result.mutation = skin.Mutation or 0
		result.astral = skin.Astral or 0
	end
	return result
end

-- Player-facing perk lines, e.g. { "+5% reel per hit", "+4% Astral chance at night" }.
function RodSkins.perks(skinId: string): { string }
	local skin = RodSkins.Skins[skinId]
	local lines = {}
	local function percent(value: number): number
		return math.floor(value * 100 + 0.5)
	end
	if (skin.Reel or 0) > 0 then
		table.insert(lines, string.format("+%d%% reel per hit", percent(skin.Reel)))
	end
	if (skin.Size or 0) > 0 then
		table.insert(lines, string.format("+%d%% big fish chance", percent(skin.Size)))
	end
	if (skin.Astral or 0) > 0 then
		table.insert(lines, string.format("+%d%% Astral chance at night", percent(skin.Astral)))
	end
	if (skin.Mutation or 0) > 0 then
		table.insert(lines, string.format("+%d%% mutation chance", percent(skin.Mutation)))
	end
	return lines
end

return RodSkins
