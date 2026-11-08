-- Pirate Cove: a tropical trading island in the Coral Shallows, between home and the lagoon. Its
-- crew hand out quests, a rod trader sells basic rods outright, and the galley buys fish straight
-- from your hand and backpack, up to DAILY_SALES a day. Pure data and rules, so the server, the
-- client and the tests share them. Spots are island-local (x, z) offsets from CENTER (north is -Z);
-- colours are { r, g, b } because this module also loads outside Roblox.

local PirateCove = {}

PirateCove.NAME = "Pirate Cove"
-- World X/Z of the island's middle: inside the Coral Shallows, clear of its central atoll.
PirateCove.CENTER = { -650, 2150 }
PirateCove.RADIUS = 170
-- How close the server requires a player to stand to the crew member they deal with.
PirateCove.TALK_RANGE = 18

-- The galley feeds the whole cove; past this many fish a day it has all it needs.
PirateCove.DAILY_SALES = 15
-- One in-game day (DayNight runs a day every 24 real minutes).
PirateCove.DAY_SECONDS = 24 * 60

-- Rods the trader sells outright. Every one is an ordinary RodSkins copy in Field-Tested wear:
-- second-hand, but honest.
PirateCove.ROD_WEAR = 0.25
PirateCove.Rods = {
	{ SkinId = "BambooRod", Price = 500 },
	{ SkinId = "UmbrellaRod", Price = 500 },
	{ SkinId = "PencilRod", Price = 650 },
	{ SkinId = "BaseballRod", Price = 750 },
	{ SkinId = "MusketRod", Price = 2000 },
}

-- Rarity order for "bring me anything this rare" quests (matches AnglerCatalog.Rarities).
local RARITY_ORDER = {
	Junk = 0,
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythical = 6,
	Exotic = 7,
	Divine = 8,
	Limited = 9,
	Admin = 10,
}

-- Kind "Shop" opens the rod trader, "Buyer" the galley; everyone else gives quests.
PirateCove.Npcs = {
	Hale = {
		Name = "Captain Morwenna Hale",
		Title = "Cove Captain",
		Kind = "Quests",
		Spot = { 0, 9 },
		Face = { 0, 0 },
		Outfit = {
			Skin = { 196, 140, 100 },
			Shirt = { 120, 28, 32 }, -- crimson greatcoat
			Sleeves = "Long",
			Trousers = { 40, 34, 32 },
			Shoes = { 24, 20, 18 },
			Boots = { 36, 28, 24 },
			Hair = { 30, 20, 16 },
			HairStyle = "Ponytail",
			Pieces = {
				{ Kind = "ShirtFront", Color = { 236, 226, 200 }, Buttons = { 212, 172, 70 } },
				{ Kind = "Belt", Color = { 60, 38, 24 } },
				{ Kind = "Tricorne", Color = { 28, 24, 24 }, Trim = { 212, 172, 70 } },
				{ Kind = "Earring", Color = { 230, 196, 80 } },
			},
		},
		Greeting = "Welcome to Pirate Cove, sailor. Nobody asks where you came from here - only what you can catch.",
	},
	Barnaby = {
		Name = "Old Salt Barnaby",
		Title = "Dock Hand",
		Kind = "Quests",
		Spot = "Pier",
		Face = "Plaza",
		Outfit = {
			Skin = { 178, 120, 84 },
			Shirt = { 232, 226, 210 },
			Sleeves = "Short",
			Trousers = { 70, 84, 104 },
			Shoes = { 60, 44, 32 },
			Hair = { 214, 212, 206 },
			HairStyle = "Bald",
			Beard = { 222, 220, 214 },
			Pieces = {
				{ Kind = "Stripes", Color = { 150, 36, 36 } },
				{ Kind = "Bandana", Color = { 40, 60, 110 } },
				{ Kind = "Rope", Color = { 196, 168, 116 } },
			},
		},
		Greeting = "Mind the loose planks. Fifty years I've worked this pier and it still tries to drown me.",
	},
	Tamsin = {
		Name = "Tamsin",
		Title = "Galley Cook",
		Kind = "Quests",
		Spot = { 7, 18 },
		Face = { 0, 0 },
		Outfit = {
			Skin = { 150, 100, 70 },
			Shirt = { 238, 234, 222 },
			Sleeves = "Short",
			Trousers = { 92, 70, 52 },
			Shoes = { 50, 36, 26 },
			Hair = { 26, 18, 14 },
			HairStyle = "Bun",
			Pieces = {
				{ Kind = "Apron", Color = { 226, 214, 186 }, Pockets = true },
				{ Kind = "Headscarf", Color = { 200, 60, 44 } },
			},
		},
		Greeting = "Hungry? Everyone in this cove is, always. I cook whatever the sea sends us.",
	},
	Pip = {
		Name = "Pip",
		Title = "Cabin Boy",
		Kind = "Quests",
		Spot = { -9, -24 },
		Face = { 0, 0 },
		Outfit = {
			Skin = { 226, 176, 136 },
			Shirt = { 214, 190, 140 },
			Sleeves = "Short",
			Trousers = { 120, 96, 66 },
			Shoes = { 226, 176, 136 }, -- barefoot
			Hair = { 196, 120, 48 },
			HairStyle = "Short",
			Pieces = {
				{ Kind = "Bandana", Color = { 230, 180, 40 } },
				{ Kind = "Belt", Color = { 96, 62, 36 } },
			},
		},
		Greeting = "Are you a real captain? I'm going to be one. Captain Pip. Sounds good, right?",
	},
	Ines = {
		Name = "Ines",
		Title = "Navigator",
		Kind = "Quests",
		Spot = { -42, -18 },
		Face = { -60, -60 },
		Outfit = {
			Skin = { 120, 82, 58 },
			Shirt = { 34, 70, 82 }, -- teal coat
			Sleeves = "Long",
			Trousers = { 214, 200, 170 },
			Shoes = { 40, 30, 24 },
			Boots = { 52, 38, 28 },
			Hair = { 18, 14, 12 },
			HairStyle = "Ponytail",
			Pieces = {
				{ Kind = "Vest", Color = { 120, 80, 44 } },
				{ Kind = "Satchel", Color = { 132, 84, 46 } },
				{ Kind = "Tricorne", Color = { 60, 44, 32 }, Trim = { 214, 200, 170 } },
			},
		},
		Greeting = "I chart every current from here to the ice. The cannons up here make a good desk.",
	},
	Coralie = {
		Name = "Coralie",
		Title = "Pearl Diver",
		Kind = "Quests",
		Spot = { 44, -20 },
		Face = { 70, -70 },
		Outfit = {
			Skin = { 170, 112, 78 },
			Shirt = { 64, 170, 168 },
			Sleeves = "None",
			Trousers = { 64, 170, 168 },
			Shoes = { 170, 112, 78 },
			Hair = { 40, 26, 20 },
			HairStyle = "Ponytail",
			Pieces = {
				{ Kind = "Belt", Color = { 238, 226, 200 } },
				{ Kind = "Earring", Color = { 244, 240, 232 } },
			},
		},
		Greeting = "The water round the cove is so clear you can see the pearls from the boat. Nearly.",
	},
	Flint = {
		Name = "Gunner Flint",
		Title = "Rod Trader",
		Kind = "Shop",
		Spot = "RodStall",
		Face = "Plaza",
		Outfit = {
			Skin = { 204, 148, 104 },
			Shirt = { 90, 74, 58 },
			Sleeves = "Long",
			Trousers = { 50, 46, 44 },
			Shoes = { 30, 26, 24 },
			Boots = { 40, 34, 30 },
			Gloves = { 70, 50, 36 },
			Hair = { 86, 60, 40 },
			HairStyle = "Short",
			Beard = { 92, 64, 42 },
			Pieces = {
				{ Kind = "Vest", Color = { 46, 40, 36 } },
				{ Kind = "EyePatch", Color = { 20, 18, 18 } },
				{ Kind = "Bandana", Color = { 30, 30, 34 } },
			},
		},
		Greeting = "Rods! Good rods! Mostly from honest sources. Have a look.",
	},
	Bess = {
		Name = "Quartermaster Bess",
		Title = "Fish Buyer",
		Kind = "Buyer",
		Spot = "BuyerStall",
		Face = "Plaza",
		Outfit = {
			Skin = { 222, 170, 128 },
			Shirt = { 236, 230, 214 },
			Sleeves = "Long",
			Trousers = { 60, 56, 70 },
			Shoes = { 40, 34, 30 },
			Boots = { 52, 44, 38 },
			Hair = { 150, 44, 30 },
			HairStyle = "Bun",
			Pieces = {
				{ Kind = "Apron", Color = { 70, 110, 120 } },
				{ Kind = "Headscarf", Color = { 30, 60, 100 } },
				{ Kind = "Earring", Color = { 230, 196, 80 } },
			},
		},
		Greeting = "I buy fish for the whole cove. Fair prices, paid on the spot.",
	},
}

PirateCove.Order = { "Hale", "Barnaby", "Tamsin", "Pip", "Ines", "Coralie", "Flint", "Bess" }

-- Each quest giver's chain, in order. Kinds:
--   Catch         catch Count fish (any, anywhere) after accepting
--   Deliver       hand over one FishId
--   DeliverRarity hand over any fish of at least Rarity
--   DeliverMutated hand over any fish with a mutation
-- Delivered fish come from your hand first, then your backpack; locked fish are never taken.
PirateCove.Quests = {
	Hale = {
		{
			Kind = "Catch",
			Count = 10,
			Cash = 300,
			XP = 150,
			Title = "Prove Your Salt",
			Offer = "Anyone can sail in. Show me you can fish: land ten of them, anywhere you like, and come back.",
			Done = "Ten fish and still standing. You'll do.",
		},
		{
			Kind = "Deliver",
			FishId = "YellowfinTuna",
			Cash = 900,
			XP = 400,
			Title = "A Captain's Supper",
			Offer = "My crew wants a proper feast. Bring me a Yellowfin Tuna from the open water.",
			Done = "Now that is a tuna. The crew will sing about this one. Badly.",
		},
		{
			Kind = "DeliverRarity",
			Rarity = "Epic",
			Cash = 2500,
			XP = 1200,
			Title = "Legend of the Cove",
			Offer = "Last task, and the hardest. Bring me an Epic fish - or rarer. Then you're one of us.",
			Done = "Well I'll be. Welcome to the crew, Captain. The cove is yours as much as mine.",
		},
	},
	Barnaby = {
		{
			Kind = "Deliver",
			FishId = "Sardine",
			Cash = 120,
			XP = 60,
			Title = "Bait for an Old Man",
			Offer = "Out of bait again. Fetch me a Sardine, would you? My knees don't do boats any more.",
			Done = "Lovely and slimy. Just how I like 'em.",
		},
		{
			Kind = "Deliver",
			FishId = "Mackerel",
			Cash = 220,
			XP = 100,
			Title = "Mackerel Sky",
			Offer = "Mackerel sky, mackerel for tea. That's the saying. I think. Bring me one.",
			Done = "Perfect. Now if only the sky would do what the saying says.",
		},
		{
			Kind = "Catch",
			Count = 25,
			Cash = 700,
			XP = 300,
			Title = "Fifty Years of Fishing",
			Offer = "When I was your age I'd land twenty-five fish before breakfast. Let's see you match it.",
			Done = "Ha! Twenty-five. You've got the knack, right enough.",
		},
	},
	Tamsin = {
		{
			Kind = "Deliver",
			FishId = "RedSnapper",
			Cash = 180,
			XP = 80,
			Title = "Snapper Stew",
			Offer = "Tonight is snapper stew, if somebody brings me a Red Snapper. Somebody like you.",
			Done = "Into the pot it goes. Come back later for a bowl.",
		},
		{
			Kind = "Deliver",
			FishId = "Shrimp",
			Cash = 300,
			XP = 140,
			Title = "Shrimp on the Fire",
			Offer = "The crew keeps asking for grilled shrimp. Find me some Shrimp out in the open sea.",
			Done = "Oh, they're lovely. The crew will be quiet for a whole hour.",
		},
		{
			Kind = "Deliver",
			FishId = "Pufferfish",
			Cash = 450,
			XP = 220,
			Title = "A Dangerous Dish",
			Offer = "I want to try something daring. Bring me a Pufferfish. Don't worry, I know what I'm doing. Mostly.",
			Done = "Careful, careful... There. Nobody touch the spiky bits.",
		},
	},
	Pip = {
		{
			Kind = "Deliver",
			FishId = "Clownfish",
			Cash = 150,
			XP = 70,
			Title = "A Stripy Friend",
			Offer = "I want a pet fish. A Clownfish! They're the funniest fish. Can you catch me one?",
			Done = "I'm calling him Admiral. Admiral Stripes.",
		},
		{
			Kind = "Deliver",
			FishId = "LeatherBoot",
			Cash = 100,
			XP = 50,
			Title = "Treasure Hunter",
			Offer = "Real pirates collect treasure. Bring me a boot from the sea floor! Boots are treasure if you squint.",
			Done = "A real sea boot! It's the best thing I own. Don't tell Admiral Stripes.",
		},
		{
			Kind = "DeliverRarity",
			Rarity = "Uncommon",
			Cash = 350,
			XP = 160,
			Title = "Something Special",
			Offer = "Captain Hale says only good sailors catch the unusual ones. Show me an Uncommon fish or better!",
			Done = "Wow. When I'm Captain Pip, you can be my first mate.",
		},
	},
	Ines = {
		{
			Kind = "Catch",
			Count = 15,
			Cash = 350,
			XP = 160,
			Title = "Reading the Water",
			Offer = "Every catch tells me something about the currents. Land fifteen fish and I'll learn a lot.",
			Done = "Good. My charts are already better for it.",
		},
		{
			Kind = "DeliverRarity",
			Rarity = "Rare",
			Cash = 800,
			XP = 360,
			Title = "Strange Currents",
			Offer = "Rare fish follow the strange currents. Bring me a Rare fish and I can map where they run.",
			Done = "Just as I thought. The current turns east past the atoll.",
		},
		{
			Kind = "Deliver",
			FishId = "Sailfish",
			Cash = 1800,
			XP = 800,
			Title = "Fastest in the Sea",
			Offer = "Nothing crosses the sea faster than a Sailfish. Catch one and I'll know the deep-water lanes.",
			Done = "Magnificent. My map of the open sea is finally finished.",
		},
	},
	Coralie = {
		{
			Kind = "Deliver",
			FishId = "Halibut",
			Cash = 200,
			XP = 90,
			Title = "Flat on the Bottom",
			Offer = "Halibut hide flat on the sand where I dive. Catch one for me before it scares me again.",
			Done = "Ha! Not so scary up here, are you?",
		},
		{
			Kind = "DeliverMutated",
			Cash = 1200,
			XP = 500,
			Title = "A Glimmer Below",
			Offer = "Sometimes I see fish that glow, or shine with every colour. Bring me any mutated fish.",
			Done = "Look at it shimmer. Prettier than any pearl.",
		},
		{
			Kind = "Deliver",
			FishId = "Swordfish",
			Cash = 2000,
			XP = 900,
			Title = "The Sword Below",
			Offer = "A Swordfish keeps chasing me off my best pearl bed. Catch it, and the pearls are safe.",
			Done = "My pearl bed is mine again. Thank you, truly.",
		},
	},
}

-- The in-game day number at `elapsed` seconds since the DayNight epoch.
function PirateCove.day(elapsed: number): number
	return math.floor(elapsed / PirateCove.DAY_SECONDS)
end

-- Fish the galley will still buy today from a saved { Day, Count } record.
function PirateCove.salesLeft(record: { Day: number?, Count: number? }?, day: number): number
	local sold = if record and record.Day == day then record.Count or 0 else 0
	return math.max(0, PirateCove.DAILY_SALES - sold)
end

function PirateCove.salePrice(record: { Value: number }): number
	return math.max(1, math.floor(record.Value))
end

function PirateCove.quest(npcId: string, step: number?)
	local chain = PirateCove.Quests[npcId]
	return chain and chain[step or 1]
end

-- Whether a fish record satisfies a delivery quest. `rarityOf` maps a FishId to its rarity name.
function PirateCove.accepts(quest, record, rarityOf: (string) -> string?): boolean
	if quest.Kind == "Deliver" then
		return record.FishId == quest.FishId
	elseif quest.Kind == "DeliverRarity" then
		local rarity = rarityOf(record.FishId)
		return rarity ~= nil and (RARITY_ORDER[rarity] or -1) >= RARITY_ORDER[quest.Rarity]
	elseif quest.Kind == "DeliverMutated" then
		return type(record.Mutation) == "string" and record.Mutation ~= "Normal"
	end
	return false
end

-- A quest's progress line for the dialogue. `caught` is fish landed since accepting.
function PirateCove.goal(quest, caught: number?, fishName: string?): string
	if quest.Kind == "Catch" then
		return string.format("Catch %d fish (%d / %d)", quest.Count, math.min(caught or 0, quest.Count), quest.Count)
	elseif quest.Kind == "Deliver" then
		return "Bring a " .. (fishName or quest.FishId)
	elseif quest.Kind == "DeliverRarity" then
		return "Bring any " .. quest.Rarity .. " fish or rarer"
	elseif quest.Kind == "DeliverMutated" then
		return "Bring any mutated fish"
	end
	return quest.Title
end

return PirateCove
