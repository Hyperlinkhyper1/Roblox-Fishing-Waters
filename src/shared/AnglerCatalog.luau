-- The bestiary and journal read this registry. Species live one per module in
-- Shared.Fish (format in Shared.FishSpecies); this turns them into Catalog.Fish
-- and fills the pools each one names.
local FishSpecies = require(script.Parent.FishSpecies)

local Catalog = {}

-- Ordered tiers. XP is awarded per landed fish; Difficulty starts the reel minigame.
Catalog.Rarities = {
	Junk = { Name = "Junk", Order = 0, Color = Color3.fromRGB(157, 133, 104), Difficulty = 0.05, XP = 5 },
	Common = { Name = "Common", Order = 1, Color = Color3.fromRGB(196, 196, 196), Difficulty = 0.12, XP = 50 },
	Uncommon = { Name = "Uncommon", Order = 2, Color = Color3.fromRGB(111, 202, 125), Difficulty = 0.3, XP = 100 },
	Rare = { Name = "Rare", Order = 3, Color = Color3.fromRGB(82, 163, 229), Difficulty = 0.48, XP = 200 },
	Epic = { Name = "Epic", Order = 4, Color = Color3.fromRGB(176, 108, 230), Difficulty = 0.58, XP = 400 },
	Legendary = { Name = "Legendary", Order = 5, Color = Color3.fromRGB(240, 176, 64), Difficulty = 0.66, XP = 800 },
	Mythical = { Name = "Mythical", Order = 6, Color = Color3.fromRGB(232, 62, 92), Difficulty = 0.66, XP = 1600 },
	Exotic = { Name = "Exotic", Order = 7, Color = Color3.fromRGB(52, 222, 196), Difficulty = 0.66, XP = 3200 },
	Divine = { Name = "Divine", Order = 8, Color = Color3.fromRGB(255, 242, 178), Difficulty = 0.66, XP = 6400 },
	-- Limited species skip the weighted draw: they only bite while the admin
	-- dashboard has them switched on, at the chance set there (FishCatch.limited).
	Limited = { Name = "Limited", Order = 9, Color = Color3.fromRGB(255, 84, 214), Difficulty = 0.66, XP = 2500 },
}

-- Junk uses the same carrying, cargo and selling path as other catches.
Catalog.Fish = {}
for id, fish in FishSpecies do
	assert(Catalog.Rarities[fish.Rarity], id .. " has an unknown rarity")
	local requires = fish.Requires
	Catalog.Fish[id] = {
		Name = fish.Name,
		Image = fish.Image or "",
		Rarity = fish.Rarity,
		CatchXP = Catalog.Rarities[fish.Rarity].XP,
		RarityDenominator = fish.RarityDenominator,
		MinKg = fish.MinKg,
		AverageKg = fish.AverageKg,
		MaxKg = fish.MaxKg,
		BaseValue = fish.BaseValue,
		Fight = fish.Fight or 0,
		Shapes = fish.Shapes,
		Seasons = fish.Seasons,
		Requires = if type(requires) == "string" then { requires } else requires,
		DropOnly = fish.DropOnly,
	}
end

-- Where a cast lands decides its pool (Catalog.poolAt): MainLake inside the
-- sheltered bay, otherwise the pool for the biome under the bobber. Biome pools
-- inherit every Open Sea species, so a biome with few or no species of its own
-- still fishes like the open sea. Species join pools through their Pools list.
local JUNK = { "WoodenBranch", "LeatherBoot", "Seaweed" }
Catalog.Pools = {
	MainLake = { Name = "Main Lake", Area = "lake", Junk = JUNK },
	OpenSea = { Name = "Open Sea", Area = "open", Junk = JUNK },
	GullhavenSound = { Name = "Gullhaven Sound", Area = "normal", Inherits = "OpenSea", Junk = JUNK },
	SoddenMire = { Name = "The Sodden Mire", Area = "swamp", Inherits = "OpenSea", Junk = JUNK },
	CoralShallows = { Name = "Coral Shallows", Area = "tropical", Inherits = "OpenSea", Junk = JUNK },
	CinderIsles = { Name = "Cinder Isles", Area = "volcanic", Inherits = "OpenSea", Junk = JUNK },
	FrostmereExpanse = { Name = "Frostmere Expanse", Area = "ice", Inherits = "OpenSea", Junk = JUNK },
}
Catalog.DefaultPool = "MainLake"

-- Commoner species first, then by id, so pool order never depends on file order.
local ids = {}
for id in FishSpecies do
	table.insert(ids, id)
end
table.sort(ids, function(a, b)
	local fa, fb = FishSpecies[a], FishSpecies[b]
	local ra, rb = Catalog.Rarities[fa.Rarity].Order, Catalog.Rarities[fb.Rarity].Order
	if ra ~= rb then
		return ra < rb
	end
	return a < b
end)
for _, pool in Catalog.Pools do
	pool.Own = {}
end
for _, id in ids do
	for _, poolId in FishSpecies[id].Pools or {} do
		local pool = Catalog.Pools[poolId]
		assert(pool, id .. " names unknown pool " .. poolId)
		table.insert(pool.Own, id)
	end
end
-- Fish is what bites: a pool's own species plus any it inherits.
for _, pool in Catalog.Pools do
	local fish = table.clone(pool.Own)
	local parent = pool.Inherits and Catalog.Pools[pool.Inherits]
	for _, id in if parent then parent.Own else {} do
		if not table.find(fish, id) then
			table.insert(fish, id)
		end
	end
	pool.Fish = fish
end

-- The pool for an area: "lake", or a Shared.Biomes id (CatchConditions.area).
function Catalog.poolAt(area: string?)
	for _, pool in Catalog.Pools do
		if pool.Area == area then
			return pool
		end
	end
	return Catalog.Pools.OpenSea
end

-- Every key FishMutations can roll. RarityMultiplier is one over the key's
-- chance per catch (at night for Astral); scripts/fish-mutations.luau keeps
-- them in step with the roll odds.
Catalog.Mutations = {
	Normal = { Name = "Normal", RarityMultiplier = 1 },
	Neon = { Name = "Neon", RarityMultiplier = 145 },
	Albino = { Name = "Albino", RarityMultiplier = 333 },
	Rainbow = { Name = "Rainbow", RarityMultiplier = 667 },
	Astral = { Name = "Astral", RarityMultiplier = 1307 },
	Corrupted = { Name = "Corrupted", RarityMultiplier = 429 },
	["Neon+Albino"] = { Name = "Neon Albino", RarityMultiplier = 1111 },
	["Rainbow+Neon"] = { Name = "Rainbow Neon", RarityMultiplier = 1667 },
	["Astral+Rainbow"] = { Name = "Astral Rainbow", RarityMultiplier = 7407 },
	["Corrupted+Neon"] = { Name = "Corrupted Neon", RarityMultiplier = 1304 },
	["Corrupted+Albino"] = { Name = "Corrupted Albino", RarityMultiplier = 3000 },
	["Corrupted+Rainbow"] = { Name = "Corrupted Rainbow", RarityMultiplier = 6000 },
	["Corrupted+Astral"] = { Name = "Corrupted Astral", RarityMultiplier = 11765 },
	["Corrupted+Neon+Albino"] = { Name = "Corrupted Neon Albino", RarityMultiplier = 10000 },
	["Corrupted+Rainbow+Neon"] = { Name = "Corrupted Rainbow Neon", RarityMultiplier = 15000 },
	["Corrupted+Astral+Rainbow"] = { Name = "Corrupted Astral Rainbow", RarityMultiplier = 66667 },
	-- Guaranteed event traits have no natural encounter odds or added rarity score.
	VoidTouched = { Name = "Void Touched", RarityMultiplier = 1, EventOnly = true },
	["VoidTouched+Astral"] = { Name = "Void Touched Astral", RarityMultiplier = 1, EventOnly = true },
	["VoidTouched+Astral+Rainbow"] = { Name = "Void Touched Astral Rainbow", RarityMultiplier = 1, EventOnly = true },
	["VoidTouched+Neon"] = { Name = "Void Touched Neon", RarityMultiplier = 1, EventOnly = true },
	["VoidTouched+Albino"] = { Name = "Void Touched Albino", RarityMultiplier = 1, EventOnly = true },
	["VoidTouched+Rainbow"] = { Name = "Void Touched Rainbow", RarityMultiplier = 1, EventOnly = true },
	["VoidTouched+Neon+Albino"] = { Name = "Void Touched Neon Albino", RarityMultiplier = 1, EventOnly = true },
	["VoidTouched+Rainbow+Neon"] = { Name = "Void Touched Rainbow Neon", RarityMultiplier = 1, EventOnly = true },
	["Corrupted+VoidTouched"] = { Name = "Corrupted Void Touched", RarityMultiplier = 1, EventOnly = true },
	["Corrupted+VoidTouched+Astral"] = {
		Name = "Corrupted Void Touched Astral",
		RarityMultiplier = 1,
		EventOnly = true,
	},
	["Corrupted+VoidTouched+Astral+Rainbow"] = {
		Name = "Corrupted Void Touched Astral Rainbow",
		RarityMultiplier = 1,
		EventOnly = true,
	},
	["Corrupted+VoidTouched+Neon"] = { Name = "Corrupted Void Touched Neon", RarityMultiplier = 1, EventOnly = true },
	["Corrupted+VoidTouched+Albino"] = {
		Name = "Corrupted Void Touched Albino",
		RarityMultiplier = 1,
		EventOnly = true,
	},
	["Corrupted+VoidTouched+Rainbow"] = {
		Name = "Corrupted Void Touched Rainbow",
		RarityMultiplier = 1,
		EventOnly = true,
	},
	["Corrupted+VoidTouched+Neon+Albino"] = {
		Name = "Corrupted Void Touched Neon Albino",
		RarityMultiplier = 1,
		EventOnly = true,
	},
	["Corrupted+VoidTouched+Rainbow+Neon"] = {
		Name = "Corrupted Void Touched Rainbow Neon",
		RarityMultiplier = 1,
		EventOnly = true,
	},
}
-- Windy (fishing under a supercell) joins every natural key, after any
-- corruption, matching FishMutations.key order and label.
local windy = { Windy = { Name = "Windy", RarityMultiplier = 1, EventOnly = true } }
for key, entry in Catalog.Mutations do
	if key ~= "Normal" and not entry.EventOnly then
		local rest, restName = key:match("^Corrupted%+(.+)$"), entry.Name:match("^Corrupted (.+)$")
		local windyKey = if key == "Corrupted"
			then "Corrupted+Windy"
			elseif rest then "Corrupted+Windy+" .. rest
			else "Windy+" .. key
		local name = if key == "Corrupted"
			then "Corrupted Windy"
			elseif restName then "Corrupted Windy " .. restName
			else "Windy " .. entry.Name
		windy[windyKey] = { Name = name, RarityMultiplier = 1, EventOnly = true }
	end
end
for key, entry in windy do
	Catalog.Mutations[key] = entry
end
-- Special finishes and their event variants are valid saved catch keys.
for _, special in {
 { "Ascended", "Ascended", 10000 }, { "Floral", "Floral", 200 }, { "Snowy", "Snowy", 200 },
 { "Tryhard", "Tryhard", 10000 }, { "JackOFish", "Jack O' Fish", 20 }, { "JacksPet", "Jack's Pet", 500 },
 { "ZeusStruck", "Zeus Struck", 150 }, { "Nightmare", "Nightmare", 30 }, { "Obsidian", "Obsidian", 30 }, { "Gusty", "Gusty", 100 },
} do
 Catalog.Mutations[special[1]] = { Name = special[2], RarityMultiplier = special[3] }
 for _, prefix in { { "Windy+", "Windy " }, { "Corrupted+", "Corrupted " }, { "Corrupted+VoidTouched+", "Corrupted Void Touched " } } do
  Catalog.Mutations[prefix[1] .. special[1]] = { Name = prefix[2] .. special[2], RarityMultiplier = 1, EventOnly = true }
 end
end
Catalog.Equipment = {
	StarterRod = {
		Name = "Starter fishing rod",
		Kind = "Fishing rod",
		Description = "Your first companion on the water.",
	},
}
-- Titles are awarded by server gameplay, never by the menu client.
Catalog.Titles = {}
return Catalog
