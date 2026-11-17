-- Exercise every recipe through the real saved-data cooking and sale rules.
-- Run: lute run scripts/cooking-recipes.luau
local Data = require("../src/server/AnglerData")
local Paths = require("../src/shared/Paths")
local Recipes = require("../src/shared/Recipes")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

local species = {}
for rarity in Recipes.RarityOrder do
	species[rarity] = { Rarity = rarity, AverageKg = 2, RarityDenominator = 10, Shapes = { Normal = { "##" } } }
end
local function fish(rarity, value)
	return { FishId = rarity, Mutation = "Normal", Kg = 2, Value = value or 137, Rarity = 10, Relative = 1, CaughtAt = 1 }
end
local base = Data.choosePath(Data.decode(nil), "Supermarket", Paths.Stages.Supermarket)
base.Paths.Unlocked.Restaurant = true
base.Staff.RestaurantChef = true
for index, id in { "GrillStation", "Smoker", "SushiBar" } do
	table.insert(base.Furniture, { ItemId = id, X = -13.5 + (index - 1) * 9, Z = -9, R = 0 })
end
local backpack = { Hold = { "####" } }
local seen = {}
for _, id in Recipes.Order do
	check(not seen[id], "Recipe appears only once in the picker: " .. id)
	seen[id] = true
	local recipe = Recipes.Items[id]
	check(recipe ~= nil, "Picker recipe exists: " .. id)
	local key = if recipe.Station == "Prep" then "Prep1" else recipe.Station
	local source = Data.decode(base)
	source.Hand = fish(recipe.MinRarity)
	local wrongKey = if key == "Prep1" then "GrillStation" else "Prep1"
	local wrong, reason = Data.startCooking(source, wrongKey, id, species, 100, 1)
	check(wrong == nil and reason ~= nil and source.Hand ~= nil and next(source.Kitchen) == nil,
		"Wrong station cannot consume the fish: " .. id)
	local tooLow = Data.decode(source)
	tooLow.Hand = fish("Junk")
	local rejected, rarityReason = Data.startCooking(tooLow, key, id, species, 100, 1)
	check(rejected == nil and rarityReason ~= nil and tooLow.Hand.FishId == "Junk",
		"Below-minimum rarity cannot consume the fish: " .. id)
	local steps = Recipes.Steps[id]
	check(steps ~= nil and #steps >= 2 and Recipes.minigameSeconds(id) > 2,
		"Recipe plays a timed minigame: " .. id)
	for _, step in steps do
		check(type(step.Text) == "string" and #step.Text > 0, "Step explains the action: " .. id)
		if step.Kind == "Mash" then
			check(step.Clicks > 0 and step.Time > 0, "Mash step can finish: " .. id)
		elseif step.Kind == "Timing" then
			check(step.Hits > 0 and step.Speed > 0 and step.Zone > 0 and step.Zone < 1,
				"Timing step has a reachable target: " .. id)
		elseif step.Kind == "Hold" then
			check(step.Fill > 0 and step.Target > 0 and step.Target < 1 and step.Zone > 0 and step.Zone < 1,
				"Hold step has a reachable target: " .. id)
		else
			check(false, "Unsupported minigame action: " .. id)
		end
	end
	for _, quality in { 1, 0 } do
		local cooked = assert(Data.startCooking(source, key, id, species, 100, quality))
		local job = cooked.Kitchen[key]
		local expected = math.max(1, math.floor(Recipes.value(id, 137) * Recipes.grade(quality).Multiplier))
		check(cooked.Hand == nil and job.ReadyAt == 100 and job.Dish.RecipeId == id and job.Dish.Value == expected,
			"Hand cooking consumes one fish and applies its grade: " .. id)
		check(source.Hand ~= nil and next(source.Kitchen) == nil, "Cooking preserves the input profile: " .. id)
		local saved = Data.decode(cooked)
		check(saved.Kitchen[key].Dish.RecipeId == id and saved.Kitchen[key].Dish.Value == expected,
			"New dish survives saving on the station: " .. id)
		local blocked = Data.collectDish(saved, key, 100, { Hold = {} }, species)
		check(blocked == nil and saved.Kitchen[key] ~= nil, "A full backpack preserves the finished dish: " .. id)
		local collected = assert(Data.collectDish(saved, key, 100, backpack, species))
		local dish = collected.Backpack[1].Dish
		check(collected.Kitchen[key] == nil and dish.RecipeId == id and collected.Stats.FoodCooked == 1,
			"The finished dish enters inventory once: " .. id)
		local stocked = assert(Data.moveInventory(Data.decode(collected), "Backpack", 1, "Pantry", dish, nil, nil, backpack, species,
			function(item, expectedDish) return Data.sameDish(item.Dish, expectedDish) end))
		check(#stocked.Backpack == 0 and stocked.Pantry[1].RecipeId == id, "Dish can be stocked after reloading: " .. id)
		local sold, paid = Data.sellDish(stocked, stocked.Pantry[1], Recipes.RESTAURANT_MARKUP, "DinersServed")
		check(sold ~= nil and paid == Recipes.dinerPrice(expected) and #sold.Pantry == 0 and sold.Stats.DinersServed == 1,
			"Restaurant sale pays the graded dish's markup: " .. id)
		check(Data.sellDish(sold, dish, 1, "FoodSold") == nil, "The same dish cannot be sold twice: " .. id)
	end
	local chef = assert(Data.setChefRecipe(base, "RestaurantChef", id))
	chef.Hand = fish("Common", 99)
	chef.KitchenStorage.Fish = { fish("Junk", 1), fish(recipe.MinRarity) }
	local started = assert(Data.startChefCooking(chef, "RestaurantChef", key, species, 200))
	local job = started.Kitchen[key]
	check(started.Hand.Value == 99 and #started.KitchenStorage.Fish == 1 and started.KitchenStorage.Fish[1].FishId == "Junk",
		"Chef chooses eligible storage fish and preserves the player's hand: " .. id)
	check(job.ReadyAt == 200 + recipe.Seconds and job.Dish.Value == Recipes.value(id, 137),
		"Chef uses the recipe timer and ungraded value: " .. id)
	local saved = Data.decode(started)
	check(saved.ChefRecipes.RestaurantChef == id and saved.Kitchen[key].ChefRole == "RestaurantChef",
		"Chef assignment and active job survive saving: " .. id)
	check(Data.collectChefDish(saved, "RestaurantChef", key, job.ReadyAt - 1) == nil,
		"Chef cannot collect before the timer: " .. id)
	local served = assert(Data.collectChefDish(saved, "RestaurantChef", key, job.ReadyAt))
	check(served.Kitchen[key] == nil and served.Pantry[1].RecipeId == id and served.Stats.FoodCooked == 1,
		"Chef sends the completed dish to the pass: " .. id)
end
for id in Recipes.Items do
	check(seen[id], "Every recipe is offered in the picker: " .. id)
end
check(#Recipes.Order == 19, "The expanded kitchen offers nineteen recipes")
print(string.format("Cooking recipes: %d checks passed across %d recipes (manual cooking, inventory, sales, chefs and saves).", checks, #Recipes.Order))
