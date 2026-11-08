-- Bait: a consumable boost on the hook. The equipped bait applies from the next
-- cast and one is used up each time a catch is reeled in. Crates come from Finn
-- ($25 each) or, rarely, on the end of the line; each crate holds 7-15 of one
-- bait, rolled by rarity. Rolls take uniform [0, 1) picks so tests can drive them.
local Bait = {}

Bait.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
Bait.Rarities = {
	Common = { Color = { 196, 201, 205 } },
	Uncommon = { Color = { 111, 202, 125 } },
	Rare = { Color = { 86, 156, 240 } },
	Epic = { Color = { 186, 104, 240 } },
	Legendary = { Color = { 255, 196, 64 } },
}

-- Luck uses the same rarity bias as rod luck; Size adds to the big/huge-fish
-- multiplier; Mutation adds to the mutation chance; Reel adds to reel speed.
Bait.Order = { "Worm", "Cricket", "Shrimp", "Squid", "Glowworm" }
Bait.Types = {
	Worm = { Name = "Worm", Rarity = "Common", Color = { 214, 132, 120 }, Luck = 0.03 },
	Cricket = { Name = "Cricket", Rarity = "Uncommon", Color = { 120, 96, 58 }, Luck = 0.05, Size = 0.15 },
	Shrimp = {
		Name = "Shrimp",
		Rarity = "Rare",
		Color = { 255, 150, 120 },
		Luck = 0.07,
		Size = 0.3,
		Mutation = 0.001,
	},
	Squid = {
		Name = "Squid",
		Rarity = "Epic",
		Color = { 236, 206, 230 },
		Luck = 0.1,
		Size = 0.5,
		Mutation = 0.002,
		Reel = 0.08,
	},
	Glowworm = {
		Name = "Glowworm",
		Rarity = "Legendary",
		Color = { 150, 255, 170 },
		Neon = true,
		Luck = 0.15,
		Size = 0.8,
		Mutation = 0.004,
		Reel = 0.15,
	},
}

Bait.Crate = {
	Name = "Bait Crate",
	Price = 25,
	MinBait = 7,
	MaxBait = 15,
	Odds = { Common = 0.6, Uncommon = 0.25, Rare = 0.1, Epic = 0.04, Legendary = 0.01 },
}
-- Finn sells crates in these batch sizes.
Bait.BuyCounts = { 1, 5 }
-- Chance that a landed catch also brings up a bait crate.
Bait.FISH_UP_CHANCE = 0.02

function Bait.valid(id: any): boolean
	return type(id) == "string" and Bait.Types[id] ~= nil
end

function Bait.validBuyCount(count: any): boolean
	return type(count) == "number" and table.find(Bait.BuyCounts, count) ~= nil
end

-- The bait and amount inside one crate.
function Bait.roll(rarityPick: number, amountPick: number): (string, number)
	local rarity = Bait.RarityOrder[1]
	for _, name in Bait.RarityOrder do
		rarity = name
		rarityPick -= Bait.Crate.Odds[name]
		if rarityPick < 0 then
			break
		end
	end
	local id = Bait.Order[1]
	for _, candidate in Bait.Order do
		if Bait.Types[candidate].Rarity == rarity then
			id = candidate
			break
		end
	end
	local span = Bait.Crate.MaxBait - Bait.Crate.MinBait + 1
	local amount = Bait.Crate.MinBait + math.clamp(math.floor(amountPick * span), 0, span - 1)
	return id, amount
end

function Bait.chance(id: string): number
	local rarity, count = Bait.Types[id].Rarity, 0
	for _, other in Bait.Order do
		if Bait.Types[other].Rarity == rarity then
			count += 1
		end
	end
	return Bait.Crate.Odds[rarity] / count
end

-- Rod boosts (RodUpgrades.boosts and friends) with `id`'s bait on the hook.
function Bait.apply(boosts, id: string?)
	local result = table.clone(boosts)
	local bait = id and Bait.Types[id]
	if bait then
		result.luck = (result.luck or 0) + (bait.Luck or 0)
		result.size = (result.size or 1) + (bait.Size or 0)
		result.mutation = (result.mutation or 0) + (bait.Mutation or 0)
		result.reel = (result.reel or 1) + (bait.Reel or 0)
	end
	return result
end

function Bait.perks(id: string): { string }
	local bait = Bait.Types[id]
	local perks = { string.format("+%d%% luck", math.floor(bait.Luck * 100 + 0.5)) }
	if bait.Size then
		table.insert(perks, string.format("+%d%% big fish", math.floor(bait.Size * 100 + 0.5)))
	end
	if bait.Mutation then
		table.insert(perks, string.format("+%.1f%% mutation", bait.Mutation * 100))
	end
	if bait.Reel then
		table.insert(perks, string.format("+%d%% reel", math.floor(bait.Reel * 100 + 0.5)))
	end
	return perks
end

return Bait
