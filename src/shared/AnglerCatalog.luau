-- Add each new species here once; the bestiary and journal read this registry.
-- Fish entries: { Name, Image = "rbxassetid://...", AverageKg, RarityDenominator }.
-- RarityDenominator is the base encounter odds (e.g. 100 means 1 in 100).
-- MinKg/MaxKg bound the weight roll (MaxKg is the rare HUGE record size), BaseValue
-- is the cash worth of an average-weight fish and Fight nudges the reel difficulty.
-- Shapes is the cargo-hold footprint per size class ("#" fills a cell, see
-- Shared.Cargo), so bigger catches take more room.
local Catalog = {}

-- Ordered tiers. XP is awarded per landed fish; Difficulty starts the reel minigame.
Catalog.Rarities = {
	Junk = { Name = "Junk", Order = 0, Color = Color3.fromRGB(157, 133, 104), Difficulty = 0.05, XP = 5 },
	Common = { Name = "Common", Order = 1, Color = Color3.fromRGB(196, 196, 196), Difficulty = 0.12, XP = 50 },
	Uncommon = { Name = "Uncommon", Order = 2, Color = Color3.fromRGB(111, 202, 125), Difficulty = 0.3, XP = 100 },
	Rare = { Name = "Rare", Order = 3, Color = Color3.fromRGB(82, 163, 229), Difficulty = 0.48, XP = 200 },
	Epic = { Name = "Epic", Order = 4, Color = Color3.fromRGB(176, 108, 230), Difficulty = 0.66, XP = 400 },
	Legendary = { Name = "Legendary", Order = 5, Color = Color3.fromRGB(240, 176, 64), Difficulty = 0.72, XP = 800 },
}

local function species(name, rarity, denominator, minKg, averageKg, maxKg, baseValue, fight, shapes)
	return {
		Name = name,
		Image = "",
		Rarity = rarity,
		CatchXP = Catalog.Rarities[rarity].XP,
		RarityDenominator = denominator,
		MinKg = minKg,
		AverageKg = averageKg,
		MaxKg = maxKg,
		BaseValue = baseValue,
		Fight = fight,
		Shapes = shapes,
	}
end

Catalog.Fish = {
	-- Junk uses the same carrying, cargo and selling path as other catches.
	WoodenBranch = species("Wooden Branch", "Junk", 50, 0.2, 0.5, 1, 1, 0, {
		Normal = { "###" },
	}),
	LeatherBoot = species("Leather Boot", "Junk", 50, 0.4, 0.8, 1.2, 1, 0, {
		Normal = { "#.", "##" },
	}),
	Seaweed = species("Seaweed", "Junk", 50, 0.1, 0.3, 0.8, 1, 0, {
		Normal = { "##", "#." },
	}),
	Trout = species("Trout", "Common", 4, 0.3, 1.2, 9, 10, 0.04, {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	}),
	Carp = species("Carp", "Common", 4, 0.8, 3.5, 30, 9, 0.02, {
		Normal = { "##", "##" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	}),
	BlueMackerel = species("Blue Mackerel", "Common", 4, 0.2, 0.6, 2.5, 11, 0.05, {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####" },
	}),
	Cod = species("Cod", "Uncommon", 9, 1, 4, 40, 24, 0.02, {
		Normal = { "###" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	}),
	Bluegill = species("Bluegill", "Uncommon", 9, 0.1, 0.35, 2, 20, 0, {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	}),
	Angelfish = species("Angelfish", "Uncommon", 9, 0.08, 0.25, 1.2, 28, 0.03, {
		Normal = { "#" },
		Big = { "#", "#" },
		Huge = { "#.", "##", "#." },
	}),
	ArrowSquid = species("Arrow Squid", "Rare", 20, 0.3, 1, 6, 60, 0.04, {
		Normal = { "#.", "##" },
		Big = { "#..", "###" },
		Huge = { "#...", "####", "#..." },
	}),
	GreyEel = species("Grey Eel", "Rare", 20, 0.5, 2, 12, 65, 0.06, {
		Normal = { "###" },
		Big = { "####", "#..." },
		Huge = { "#####", "#...#" },
	}),
	GulfFlounder = species("Gulf Flounder", "Epic", 50, 0.4, 1.5, 10, 160, 0.03, {
		Normal = { "##", "##" },
		Big = { "###", "##." },
		Huge = { "###", "###" },
	}),
	Stingray = species("Stingray", "Legendary", 150, 6, 25, 180, 500, 0.06, {
		Normal = { "##.", "###", "##." },
		Big = { "###.", "####", "###." },
		Huge = { "####.", "#####", "####." },
	}),

	-- Open sea species are worth roughly double their lake tier.
	Clownfish = species("Clownfish", "Common", 4, 0.03, 0.09, 0.45, 16, 0.03, {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	}),
	Sardine = species("Sardine", "Common", 4, 0.04, 0.12, 0.5, 15, 0.04, {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "###" },
	}),
	Anchovy = species("Anchovy", "Common", 4, 0.01, 0.04, 0.18, 14, 0.05, {
		Normal = { "#" },
		Big = { "#" },
		Huge = { "##" },
	}),
	Catfish = species("Catfish", "Uncommon", 9, 0.6, 3, 28, 40, 0.04, {
		Normal = { "###" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	}),
	Pufferfish = species("Pufferfish", "Uncommon", 9, 0.2, 0.9, 6, 44, 0.02, {
		Normal = { "#" },
		Big = { "##", "##" },
		Huge = { ".#.", "###", ".#." },
	}),
	YellowfinTuna = species("Yellowfin Tuna", "Rare", 20, 6, 35, 200, 125, 0.08, {
		Normal = { "###", "###" },
		Big = { "####", "####" },
		Huge = { ".####.", "######", ".####." },
	}),
	Sailfish = species("Sailfish", "Epic", 50, 12, 40, 150, 310, 0.07, {
		Normal = { ".##.", "####" },
		Big = { ".###.", "#####" },
		Huge = { ".####.", "######" },
	}),
	Swordfish = species("Swordfish", "Epic", 50, 20, 90, 600, 340, 0.06, {
		Normal = { "####" },
		Big = { "#####", ".###." },
		Huge = { "#######", ".#####." },
	}),
	Yellowshark = species("Yellowshark", "Legendary", 150, 40, 180, 1100, 1050, 0.08, {
		Normal = { "..#..", "#####", "#####" },
		Big = { "...#..", "######", "######", ".####." },
		Huge = { "...#...", "#######", "#######", "#######", ".#####." },
	}),

	-- Crabs only come from crab cages (Shared.CrabCages.Pool), never from a cast.
	ShoreCrab = species("Shore Crab", "Common", 4, 0.05, 0.2, 0.9, 12, 0, {
		Normal = { "##" },
		Big = { "##", "##" },
		Huge = { "###", "###" },
	}),
	BlueCrab = species("Blue Crab", "Uncommon", 9, 0.15, 0.45, 1.8, 26, 0, {
		Normal = { "##" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	}),
	KingCrab = species("King Crab", "Rare", 20, 0.8, 2.6, 11, 60, 0, {
		Normal = { "###", "###" },
		Big = { "####", "####" },
		Huge = { "#####", "#####", "#####" },
	}),
}

-- CatchService picks MainLake inside the sheltered bay and OpenSea everywhere else.
Catalog.Pools = {
	MainLake = {
		Name = "Main Lake",
		Junk = { "WoodenBranch", "LeatherBoot", "Seaweed" },
		Fish = {
			"Trout",
			"Carp",
			"BlueMackerel",
			"Cod",
			"Bluegill",
			"Angelfish",
			"ArrowSquid",
			"GreyEel",
			"GulfFlounder",
			"Stingray",
		},
	},
	OpenSea = {
		Name = "Open Sea",
		Junk = { "WoodenBranch", "LeatherBoot", "Seaweed" },
		Fish = {
			"Clownfish",
			"Sardine",
			"Anchovy",
			"Catfish",
			"Pufferfish",
			"YellowfinTuna",
			"Sailfish",
			"Swordfish",
			"Yellowshark",
		},
	},
}
Catalog.DefaultPool = "MainLake"

-- Every key FishMutations can roll. RarityMultiplier is one over the key's
-- chance per catch (at night for Astral); scripts/fish-mutations.luau keeps
-- them in step with the roll odds.
Catalog.Mutations = {
	Normal = { Name = "Normal", RarityMultiplier = 1 },
	Neon = { Name = "Neon", RarityMultiplier = 322 },
	Albino = { Name = "Albino", RarityMultiplier = 741 },
	Rainbow = { Name = "Rainbow", RarityMultiplier = 1481 },
	Astral = { Name = "Astral", RarityMultiplier = 1307 },
	Corrupted = { Name = "Corrupted", RarityMultiplier = 952 },
	["Neon+Albino"] = { Name = "Neon Albino", RarityMultiplier = 2469 },
	["Rainbow+Neon"] = { Name = "Rainbow Neon", RarityMultiplier = 3704 },
	["Astral+Rainbow"] = { Name = "Astral Rainbow", RarityMultiplier = 7407 },
	["Corrupted+Neon"] = { Name = "Corrupted Neon", RarityMultiplier = 2899 },
	["Corrupted+Albino"] = { Name = "Corrupted Albino", RarityMultiplier = 6667 },
	["Corrupted+Rainbow"] = { Name = "Corrupted Rainbow", RarityMultiplier = 13333 },
	["Corrupted+Astral"] = { Name = "Corrupted Astral", RarityMultiplier = 11765 },
	["Corrupted+Neon+Albino"] = { Name = "Corrupted Neon Albino", RarityMultiplier = 22222 },
	["Corrupted+Rainbow+Neon"] = { Name = "Corrupted Rainbow Neon", RarityMultiplier = 33333 },
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
