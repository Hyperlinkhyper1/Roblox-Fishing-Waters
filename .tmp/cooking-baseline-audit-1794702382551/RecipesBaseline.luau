-- Kitchen recipes for the Supermarket path. A dish is cooked from one carried fish
-- at a kitchen station; its value is the fish's value times the recipe's Multiplier.
-- Better recipes need a rarer fish and a bought station. Pure: no Roblox services.
local Recipes = {}

-- Same order as AnglerCatalog.Rarities (kept here so this module stays pure).
Recipes.RarityOrder = {
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
-- Diners in the restaurant pay this much more than shop customers.
Recipes.RESTAURANT_MARKUP = 1.5

-- Prep benches come with the house once the Supermarket is open (FurnitureCatalog
-- PrepBench, saved under a bench key below). The others are furniture
-- (FurnitureCatalog item of the same id).
Recipes.Stations = {
	Prep = { Name = "Prep bench", BuiltIn = true },
	GrillStation = { Name = "Grill station" },
	Smoker = { Name = "Smokehouse" },
	SushiBar = { Name = "Sushi bar" },
}
-- Bench keys of the house's prep benches; each placed PrepBench saves one as its Key.
Recipes.BuiltIn = {
	Prep1 = { Station = "Prep" },
	Prep2 = { Station = "Prep" },
}
-- Separate saved keys let island benches and harbour benches cook independently.
Recipes.CompanyBuiltIn = {
	CompanyPrep1 = { Station = "Prep" },
	CompanyPrep2 = { Station = "Prep" },
}

Recipes.Order = {
	"FishFillet",
	"FishAndChips",
	"GrilledFish",
	"FishSkewers",
	"SmokedFish",
	"SushiPlatter",
	"GoldenSashimi",
}
Recipes.Items = {
	FishFillet = {
		Name = "Fish fillet",
		Station = "Prep",
		MinRarity = "Common",
		Multiplier = 1.4,
		Seconds = 6,
		Look = "Fillet",
	},
	FishAndChips = {
		Name = "Fish & chips",
		Station = "Prep",
		MinRarity = "Uncommon",
		Multiplier = 1.8,
		Seconds = 10,
		Look = "Chips",
	},
	GrilledFish = {
		Name = "Grilled fish",
		Station = "GrillStation",
		MinRarity = "Uncommon",
		Multiplier = 2.2,
		Seconds = 12,
		Look = "Grilled",
	},
	FishSkewers = {
		Name = "Fish skewers",
		Station = "GrillStation",
		MinRarity = "Rare",
		Multiplier = 2.8,
		Seconds = 15,
		Look = "Skewers",
	},
	SmokedFish = {
		Name = "Smoked fish",
		Station = "Smoker",
		MinRarity = "Rare",
		Multiplier = 3.2,
		Seconds = 20,
		Look = "Smoked",
	},
	SushiPlatter = {
		Name = "Sushi platter",
		Station = "SushiBar",
		MinRarity = "Epic",
		Multiplier = 4,
		Seconds = 25,
		Look = "Sushi",
	},
	GoldenSashimi = {
		Name = "Golden sashimi",
		Station = "SushiBar",
		MinRarity = "Legendary",
		Multiplier = 5,
		Seconds = 30,
		Look = "Sashimi",
	},
}

-- Hand cooking is a short run of minigame steps (client CookingMinigame); chefs
-- still cook on the recipe's Seconds timer. Step kinds:
--   Mash   click/tap `Clicks` times within `Time` seconds
--   Timing click `Hits` times while the sweeping marker is inside the zone
--          (`Speed` bar-widths per second, zone `Zone` wide)
--   Hold   hold until the gauge (full after `Fill` seconds) reaches `Target`,
--          then release inside the `Zone`-wide band around it
Recipes.Steps = {
	FishFillet = {
		{ Kind = "Mash", Text = "Scale the fish", Clicks = 10, Time = 4 },
		{ Kind = "Timing", Text = "Fillet along the bone", Hits = 1, Speed = 1.1, Zone = 0.22 },
	},
	FishAndChips = {
		{ Kind = "Mash", Text = "Chop the potatoes", Clicks = 14, Time = 5 },
		{ Kind = "Hold", Text = "Dip in batter", Fill = 2.2, Target = 0.6, Zone = 0.22 },
		{ Kind = "Timing", Text = "Lift it out of the fryer", Hits = 1, Speed = 1.3, Zone = 0.2 },
	},
	GrilledFish = {
		{ Kind = "Mash", Text = "Season the fish", Clicks = 10, Time = 4 },
		{ Kind = "Hold", Text = "Sear until golden", Fill = 2.4, Target = 0.72, Zone = 0.2 },
		{ Kind = "Timing", Text = "Flip it", Hits = 2, Speed = 1.3, Zone = 0.2 },
	},
	FishSkewers = {
		{ Kind = "Mash", Text = "Cube the fish", Clicks = 14, Time = 5 },
		{ Kind = "Timing", Text = "Thread the skewers", Hits = 3, Speed = 1.4, Zone = 0.18 },
		{ Kind = "Hold", Text = "Grill the skewers", Fill = 2.4, Target = 0.7, Zone = 0.18 },
	},
	SmokedFish = {
		{ Kind = "Mash", Text = "Rub in the brine", Clicks = 14, Time = 5 },
		{ Kind = "Hold", Text = "Stoke the fire", Fill = 2.6, Target = 0.55, Zone = 0.18 },
		{ Kind = "Hold", Text = "Let the smoke roll", Fill = 3, Target = 0.8, Zone = 0.16 },
		{ Kind = "Timing", Text = "Pull it from the smoker", Hits = 1, Speed = 1.5, Zone = 0.16 },
	},
	SushiPlatter = {
		{ Kind = "Timing", Text = "Slice the fish", Hits = 3, Speed = 1.5, Zone = 0.17 },
		{ Kind = "Mash", Text = "Roll the rice", Clicks = 16, Time = 5 },
		{ Kind = "Timing", Text = "Plate each piece", Hits = 2, Speed = 1.6, Zone = 0.16 },
	},
	GoldenSashimi = {
		{ Kind = "Timing", Text = "Slice paper-thin", Hits = 4, Speed = 1.7, Zone = 0.15 },
		{ Kind = "Hold", Text = "Lay on the gold leaf", Fill = 2.6, Target = 0.66, Zone = 0.14 },
		{ Kind = "Mash", Text = "Garnish the plate", Clicks = 16, Time = 5 },
		{ Kind = "Timing", Text = "Serve it", Hits = 1, Speed = 1.8, Zone = 0.14 },
	},
}
-- Each step's intro and result screens take this long on the client.
Recipes.STEP_PAUSE = 1.6
-- Average step score (0..1) to grade; the grade scales the dish's value.
Recipes.Grades = {
	{ Name = "Perfect", Min = 0.9, Multiplier = 1.25 },
	{ Name = "Great", Min = 0.7, Multiplier = 1.1 },
	{ Name = "Good", Min = 0.45, Multiplier = 1 },
	{ Name = "Sloppy", Min = 0, Multiplier = 0.85 },
}

function Recipes.grade(quality: number)
	for _, grade in Recipes.Grades do
		if quality >= grade.Min then
			return grade
		end
	end
	return Recipes.Grades[#Recipes.Grades]
end

-- The quickest a person can finish a recipe's steps. The server refuses a cook
-- result sooner than this after it began, so the minigame can't be skipped.
function Recipes.minigameSeconds(recipeId: string): number
	local total = 0
	for _, step in Recipes.Steps[recipeId] or {} do
		total += Recipes.STEP_PAUSE * 0.75
		if step.Kind == "Mash" then
			total += step.Clicks / 20
		elseif step.Kind == "Timing" then
			total += step.Hits * 0.15
		elseif step.Kind == "Hold" then
			total += step.Fill * step.Target * 0.8
		end
	end
	return total
end

-- The station type behind a station key: a built-in bench key or a furniture item id.
function Recipes.stationOf(key: string): string?
	local builtIn = Recipes.BuiltIn[key] or Recipes.CompanyBuiltIn[key]
	if builtIn then
		return builtIn.Station
	end
	local station = Recipes.Stations[key]
	return if station and not station.BuiltIn then key else nil
end

-- nil when `recipeId` can be cooked at that station type from a fish of `rarity`
-- (an AnglerCatalog rarity name), otherwise a player-facing reason.
function Recipes.problem(recipeId: any, station: string, rarity: string?): string?
	local recipe = if type(recipeId) == "string" then Recipes.Items[recipeId] else nil
	if not recipe then
		return "Choose a recipe."
	elseif recipe.Station ~= station then
		return recipe.Name .. " is made at a " .. string.lower(Recipes.Stations[recipe.Station].Name) .. "."
	elseif (Recipes.RarityOrder[rarity or ""] or -1) < Recipes.RarityOrder[recipe.MinRarity] then
		return recipe.Name .. " needs a " .. recipe.MinRarity .. " fish or rarer."
	end
	return nil
end

function Recipes.value(recipeId: string, fishValue: number): number
	return math.max(1, math.floor(fishValue * Recipes.Items[recipeId].Multiplier))
end

function Recipes.dinerPrice(dishValue: number): number
	return math.max(1, math.floor(dishValue * Recipes.RESTAURANT_MARKUP))
end

return Recipes
