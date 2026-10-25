-- Kitchen recipes for the Supermarket path. A dish is cooked from one carried fish
-- at a kitchen station; its value is the fish's value times the recipe's Multiplier.
-- Better recipes need a rarer fish and a bought station. Pure: no Roblox services.
local Recipes = {}

-- Same order as AnglerCatalog.Rarities (kept here so this module stays pure).
Recipes.RarityOrder = { Junk = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }
-- Diners in the restaurant pay this much more than shop customers.
Recipes.RESTAURANT_MARKUP = 1.5

-- Built-in stations are part of the processing room once the Supermarket is open.
-- The others are furniture (FurnitureCatalog item of the same id).
Recipes.Stations = {
	Prep = { Name = "Prep bench", BuiltIn = true },
	GrillStation = { Name = "Grill station" },
	Smoker = { Name = "Smokehouse" },
	SushiBar = { Name = "Sushi bar" },
}
-- Built-in benches, by station key, in house-local studs (see FurnitureCatalog).
Recipes.BuiltIn = {
	Prep1 = { Station = "Prep", X = -21.35, Z = -4.5, R = 1 },
	Prep2 = { Station = "Prep", X = -21.35, Z = -11, R = 1 },
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

-- The station type behind a station key: a built-in bench key or a furniture item id.
function Recipes.stationOf(key: string): string?
	local builtIn = Recipes.BuiltIn[key]
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
