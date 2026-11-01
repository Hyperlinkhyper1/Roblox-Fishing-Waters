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

	-- Open sea species are worth roughly double their lake tier, plus 20%.
	Clownfish = species("Clownfish", "Common", 4, 0.03, 0.09, 0.45, 19, 0.03, {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	}),
	Sardine = species("Sardine", "Common", 4, 0.04, 0.12, 0.5, 18, 0.04, {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "###" },
	}),
	Anchovy = species("Anchovy", "Common", 4, 0.01, 0.04, 0.18, 17, 0.05, {
		Normal = { "#" },
		Big = { "#" },
		Huge = { "##" },
	}),
	Catfish = species("Catfish", "Uncommon", 9, 0.6, 3, 28, 48, 0.04, {
		Normal = { "###" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	}),
	Pufferfish = species("Pufferfish", "Uncommon", 9, 0.2, 0.9, 6, 53, 0.02, {
		Normal = { "#" },
		Big = { "##", "##" },
		Huge = { ".#.", "###", ".#." },
	}),
	YellowfinTuna = species("Yellowfin Tuna", "Rare", 12, 6, 35, 200, 150, 0.08, {
		Normal = { "###", "###" },
		Big = { "####", "####" },
		Huge = { ".####.", "######", ".####." },
	}),
	Sailfish = species("Sailfish", "Epic", 30, 12, 40, 150, 372, 0.07, {
		Normal = { ".##.", "####" },
		Big = { ".###.", "#####" },
		Huge = { ".####.", "######" },
	}),
	Swordfish = species("Swordfish", "Epic", 30, 20, 90, 600, 408, 0.06, {
		Normal = { "####" },
		Big = { "#####", ".###." },
		Huge = { "#######", ".#####." },
	}),
	Yellowshark = species("Yellowshark", "Legendary", 90, 40, 180, 1100, 1260, 0.08, {
		Normal = { "..#..", "#####", "#####" },
		Big = { "...#..", "######", "######", ".####." },
		Huge = { "...#...", "#######", "#######", "#######", ".#####." },
	}),

	-- Main lake additions.
	Pike = species("Pike", "Uncommon", 9, 0.5, 2.5, 25, 26, 0.07, {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "#####", ".###." },
	}),
	ShovelnoseSturgeon = species("Shovelnose Sturgeon", "Epic", 50, 0.8, 2.5, 8, 165, 0.05, {
		Normal = { "####" },
		Big = { "#####" },
		Huge = { "#####", ".###." },
	}),
	Tilapia = species("Tilapia", "Common", 4, 0.2, 0.8, 4, 10, 0.02, {
		Normal = { "##" },
		Big = { "##", "##" },
		Huge = { "###", "###" },
	}),
	RainbowTrout = species("Rainbow Trout", "Rare", 20, 0.3, 1.5, 12, 62, 0.05, {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	}),
	Dorado = species("Dorado", "Uncommon", 9, 1, 4, 30, 27, 0.06, {
		Normal = { "###" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	}),
	Sunfish = species("Sunfish", "Legendary", 150, 20, 90, 600, 520, 0.04, {
		Normal = { ".##.", "####", ".##." },
		Big = { ".###.", "#####", ".###." },
		Huge = { ".####.", "######", "######", ".####." },
	}),
	Lingcod = species("Lingcod", "Uncommon", 9, 1, 5, 35, 25, 0.05, {
		Normal = { "###" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	}),
	Walleye = species("Walleye", "Rare", 20, 0.5, 2, 11, 63, 0.04, {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "####", "####" },
	}),
	MidnightCarp = species("Midnight Carp", "Epic", 50, 1, 5, 35, 170, 0.05, {
		Normal = { "##", "##" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	}),

	-- Open sea additions.
	RedMullet = species("Red Mullet", "Uncommon", 9, 0.1, 0.4, 2, 50, 0.03, {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	}),
	GreenSturgeon = species("Green Sturgeon", "Epic", 30, 10, 45, 160, 395, 0.07, {
		Normal = { "#####" },
		Big = { "######", ".####." },
		Huge = { "#######", "#######" },
	}),
	RedSnapper = species("Red Snapper", "Common", 4, 0.5, 2.5, 20, 19, 0.04, {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	}),
	Flounder = species("Flounder", "Rare", 12, 0.4, 1.5, 9, 145, 0.03, {
		Normal = { "##", "##" },
		Big = { "###", "##." },
		Huge = { "###", "###" },
	}),
	Halibut = species("Halibut", "Common", 4, 1, 6, 180, 18, 0.04, {
		Normal = { "##", "##" },
		Big = { "###", "###" },
		Huge = { "#####", "#####", "#####" },
	}),
	Herring = species("Herring", "Uncommon", 9, 0.1, 0.25, 0.9, 48, 0.04, {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "###" },
	}),
	YellowSeaCucumber = species("Yellow Sea Cucumber", "Uncommon", 9, 0.1, 0.4, 1.5, 50, 0, {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####" },
	}),
	Albacore = species("Albacore", "Epic", 30, 4, 15, 45, 380, 0.07, {
		Normal = { "###", "###" },
		Big = { "####", "####" },
		Huge = { ".####.", "######", ".####." },
	}),

	-- Seasonal additions.
	SmallmouthBass = species("Smallmouth Bass", "Uncommon", 9, 0.3, 1.2, 6, 25, 0.06, {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	}),
	Shad = species("Shad", "Common", 4, 0.3, 1, 3.5, 10, 0.04, {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####" },
	}),
	DeepwaterEel = species("Deepwater Eel", "Rare", 12, 0.8, 3, 18, 150, 0.07, {
		Normal = { "####" },
		Big = { "#####", "#...." },
		Huge = { "######", "#....#" },
	}),
	OrangeSeaCucumber = species("Orange Sea Cucumber", "Rare", 12, 0.1, 0.5, 2, 140, 0, {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####" },
	}),
	YellowAngler = species("Yellow Angler", "Legendary", 90, 2, 8, 50, 1200, 0.07, {
		Normal = { "###", "###" },
		Big = { "####", "####" },
		Huge = { "#####", "#####", ".###." },
	}),
	SockeyeSalmon = species("Sockeye Salmon", "Rare", 12, 1, 2.7, 7, 148, 0.07, {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "####", "####" },
	}),
	Mackerel = species("Mackerel", "Common", 4, 0.2, 0.5, 2, 18, 0.05, {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####" },
	}),
	Shrimp = species("Shrimp", "Uncommon", 9, 0.01, 0.03, 0.12, 46, 0.02, {
		Normal = { "#" },
		Big = { "#" },
		Huge = { "##" },
	}),
	Seabass = species("Seabass", "Common", 4, 0.5, 2, 12, 19, 0.04, {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	}),

	-- Found in both the lake and the open sea, so worth somewhere between the two tiers.
	Crimsonfish = species("Crimsonfish", "Rare", 15, 0.3, 1.2, 8, 100, 0.05, {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	}),
	TigerTrout = species("Tiger Trout", "Common", 4, 0.3, 1.5, 10, 14, 0.05, {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	}),
	Glacierfish = species("Glacierfish", "Legendary", 120, 5, 22, 140, 900, 0.08, {
		Normal = { "###", "###" },
		Big = { "####", "####" },
		Huge = { "#####", "#####", "#####" },
	}),

	-- These species are exclusive to mussel nets.
	BlueMussel = species("Blue Mussel", "Common", 4, 0.03, 0.12, 0.6, 9, 0, {
		Normal = { "#" }, Big = { "##" }, Huge = { "##", "##" },
	}),
	GreenMussel = species("Green Mussel", "Uncommon", 6, 0.04, 0.18, 0.9, 15, 0, {
		Normal = { "#" }, Big = { "##" }, Huge = { "##", "##" },
	}),
	GoldenMussel = species("Golden Mussel", "Rare", 12, 0.05, 0.22, 1.1, 28, 0, {
		Normal = { "#" }, Big = { "##" }, Huge = { "##", "##" },
	}),
	Kelp = species("Kelp", "Common", 4, 0.1, 0.35, 1.5, 7, 0, {
		Normal = { "#" }, Big = { "##" }, Huge = { "##", "##" },
	}),
	SeaLettuce = species("Sea Lettuce", "Uncommon", 6, 0.05, 0.2, 0.9, 12, 0, {
		Normal = { "#" }, Big = { "##" }, Huge = { "##", "##" },
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

-- Shark rewards use the same carrying, storage and selling systems as catches.
Catalog.Fish.SharkMeat = species("Shark Meat", "Common", 1 / 0.60, 1, 1, 1, 35, 0, { Normal = { "#" } })
Catalog.Fish.SharkFin = species("Shark Fin", "Uncommon", 5, 1, 1, 1, 90, 0, { Normal = { "#" } })
Catalog.Fish.SharkTail = species("Shark Tail", "Rare", 1 / 0.12, 1, 1, 1, 180, 0, { Normal = { "#" } })
Catalog.Fish.SharkHead = species("Shark Head", "Epic", 20, 1, 1, 1, 400, 0, { Normal = { "#" } })
Catalog.Fish.GreatWhiteTooth = species("Great White Tooth", "Legendary", 1 / 0.03, 1, 1, 1, 800, 0, { Normal = { "#" } })

for _, id in { "SharkMeat", "SharkFin", "SharkTail", "SharkHead", "GreatWhiteTooth" } do
	Catalog.Fish[id].DropOnly = true
end

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
			"Pike",
			"ShovelnoseSturgeon",
			"Tilapia",
			"RainbowTrout",
			"Dorado",
			"Sunfish",
			"Lingcod",
			"Walleye",
			"MidnightCarp",
			"SmallmouthBass",
			"Shad",
			"Crimsonfish",
			"TigerTrout",
			"Glacierfish",
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
			"RedMullet",
			"GreenSturgeon",
			"RedSnapper",
			"Flounder",
			"Halibut",
			"Herring",
			"YellowSeaCucumber",
			"Albacore",
			"DeepwaterEel",
			"OrangeSeaCucumber",
			"YellowAngler",
			"SockeyeSalmon",
			"Mackerel",
			"Shrimp",
			"Seabass",
			"Crimsonfish",
			"TigerTrout",
			"Glacierfish",
		},
	},
}
Catalog.DefaultPool = "MainLake"

-- The seasons each species bites in (Shared.Seasons names), in calendar order.
-- Species left out here (junk, crabs, mussels, shark drops) turn up all year.
local SUMMER = { "Summer" }
local seasons = {
	Trout = SUMMER,
	Carp = SUMMER,
	BlueMackerel = SUMMER,
	Cod = SUMMER,
	Bluegill = SUMMER,
	Angelfish = SUMMER,
	ArrowSquid = SUMMER,
	GreyEel = SUMMER,
	GulfFlounder = SUMMER,
	Stingray = SUMMER,
	Clownfish = SUMMER,
	Sardine = SUMMER,
	Anchovy = SUMMER,
	Catfish = SUMMER,
	Pufferfish = SUMMER,
	YellowfinTuna = SUMMER,
	Sailfish = SUMMER,
	Swordfish = SUMMER,
	Yellowshark = SUMMER,
	Pike = { "Summer", "Autumn" },
	RedMullet = { "Summer", "Autumn" },
	GreenSturgeon = { "Spring", "Summer" },
	ShovelnoseSturgeon = { "Spring", "Summer" },
	Tilapia = { "Summer", "Autumn" },
	RedSnapper = { "Summer", "Autumn", "Winter" },
	RainbowTrout = SUMMER,
	Dorado = SUMMER,
	Crimsonfish = SUMMER,
	Flounder = { "Spring", "Summer", "Autumn", "Winter" },
	Halibut = { "Spring", "Summer", "Autumn" },
	Sunfish = { "Spring", "Summer" },
	Herring = { "Spring", "Winter" },
	YellowSeaCucumber = { "Autumn", "Winter" },
	TigerTrout = { "Autumn", "Winter" },
	Albacore = { "Autumn", "Winter" },
	Lingcod = { "Winter" },
	Walleye = { "Spring", "Winter" },
	MidnightCarp = { "Spring", "Autumn", "Winter" },
	Glacierfish = { "Winter" },
	SmallmouthBass = { "Spring", "Autumn" },
	Shad = { "Spring" },
	DeepwaterEel = { "Spring", "Autumn" },
	OrangeSeaCucumber = SUMMER,
	YellowAngler = { "Autumn" },
	SockeyeSalmon = { "Autumn" },
	Mackerel = { "Spring", "Summer", "Autumn", "Winter" },
	Shrimp = { "Summer", "Autumn", "Winter" },
	Seabass = { "Spring", "Winter" },
}
for id, list in seasons do
	Catalog.Fish[id].Seasons = list
end

-- Species that only bite while a condition holds at the fishing spot
-- (Shared.CatchConditions keys): rain overhead, night, or a sandy beach shallow.
local requires = {
	Tilapia = "Rain",
	RainbowTrout = "Rain",
	MidnightCarp = "Night",
	Crimsonfish = "Beach",
}
for id, condition in requires do
	Catalog.Fish[id].Requires = condition
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
