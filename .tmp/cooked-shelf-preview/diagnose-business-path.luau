-- Pure checks for the business paths (Shared.Paths) and the saved kitchen, pantry
-- and fisherman rules in AnglerData. Run: lute run scripts/business-paths.luau
local Data = require("../../src/server/AnglerData")
local Paths = require("../../src/shared/Paths")
local Recipes = require("../../src/shared/Recipes")
local Furniture = require("../../src/shared/FurnitureCatalog")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

local species = {
	Trout = { Rarity = "Common", AverageKg = 2, RarityDenominator = 10, Shapes = { Normal = { "##" } } },
	Tuna = { Rarity = "Epic", AverageKg = 40, RarityDenominator = 400, Shapes = { Normal = { "###", "###" } } },
}
local mutations = { Normal = {} }
local function fish(id, value, at)
	return { FishId = id, Mutation = "Normal", Kg = 2, Value = value, Rarity = 10, Relative = 1, CaughtAt = at or 1 }
end
local function profile(angler, cash)
	return { Cash = cash or 0, OwnedBoats = {}, RodUpgrades = {}, Angler = angler }
end

-- New and legacy profiles start as a fish shop.
local fresh = Data.decode(nil)
check(fresh.Paths.Active == "Fishshop" and fresh.Paths.Unlocked.Fishshop, "Fresh profiles start as a fish shop")
check(#fresh.Pantry == 0 and next(fresh.Kitchen) == nil, "Fresh profiles have an empty kitchen")
check(fresh.Stats.FishSold == 0 and fresh.Stats.FishermanCatches == 0, "Path counters default to zero")
check(Paths.progress(profile(fresh), "Fishshop") == 0, "Nothing done yet")
check(Paths.progress(profile(fresh), "Supermarket") == 0, "Locked stages show 0%")
check(#Paths.choices(profile(fresh)) == 0, "No next path before 100%")
check(Paths.chooseProblem(profile(fresh, 1e6), "Supermarket") ~= nil, "Cannot skip an unfinished stage")
check(not pcall(Data.decode, { Paths = { Active = "Supermarket", Unlocked = { Fishshop = true }, Completed = {}, Baseline = {} } }),
	"An active stage must be unlocked")
check(not pcall(Data.decode, { Paths = { Active = "Fishshop", Unlocked = { Fishshop = "yes" }, Completed = {}, Baseline = {} } }),
	"Malformed path flags are rejected")
check(not pcall(Data.decode, { Staff = { Cook = true } }), "Unknown staff roles are still rejected")
check(Data.decode({ Staff = { Fisherman = true }, FishermanBoat = "Rowboat" }).Staff.Fisherman, "Fisherman can be saved")

-- Lifetime stats count towards the first stage; partial goals never reach 100%.
local shop = Data.decode(nil)
shop.Stats.FishSold, shop.Stats.CoinsEarned = 25, 2400
shop.Staff.Seller, shop.Staff.Porter = true, true
local almost = Paths.progress(profile(shop), "Fishshop")
check(almost > 0.9 and almost < 1, "One open goal keeps the stage under 100%")
shop.Stats.CoinsEarned = 2500
check(Paths.progress(profile(shop), "Fishshop") == 1, "Every goal done is 100%")
local choices = Paths.choices(profile(shop))
check(#choices == 1 and choices[1] == "Supermarket", "Only the Supermarket follows the fish shop")
check(Paths.chooseProblem(profile(shop, 999), "Supermarket") ~= nil, "The next path costs coins")
check(Paths.chooseProblem(profile(shop, 1000), "Restaurant") ~= nil, "The restaurant needs the supermarket first")
check(Paths.chooseProblem(profile(shop, 1000), "Supermarket") == nil, "A finished stage can buy the next")

-- Choosing a path completes the old stage, unlocks the new one and starts its goals.
local market = Data.choosePath(shop, "Supermarket", Paths.Stages.Supermarket)
check(market.Paths.Completed.Fishshop and market.Paths.Active == "Supermarket", "Stage advances")
check(market.Paths.Unlocked.Fishshop and market.Paths.Unlocked.Supermarket, "Stages stack")
check(market.FurnitureStock.FoodCase == 1, "The supermarket grants a food display case")
check(market.Paths.Baseline.CoinsEarned == 2500, "Stat goals count from the stage start")
check(shop.Paths.Active == "Fishshop", "Choosing never mutates the previous profile")
check(Paths.progress(profile(market), "Fishshop") == 1, "Completed stages stay at 100%")
check(Paths.progress(profile(market), "Supermarket") == 0, "The new stage starts at 0%")
local earn
for _, goal in Paths.Stages.Supermarket.Goals do
	if goal.Stat == "CoinsEarned" then
		earn = goal
	end
end
market.Stats.CoinsEarned = 7500
check(select(1, Paths.goalProgress(earn, profile(market))) == 5000, "Only coins earned in this stage count")
check(Data.decode(market).Paths.Baseline.CoinsEarned == 2500, "Path progress survives a save round trip")

-- Locked furniture: food cases need the supermarket.
local locked = Data.decode(nil)
locked.FurnitureStock.FoodCase = 1
local _, why = Data.placeFurniture(locked, "FoodCase", 13.5, 72, 2)
check(why ~= nil and string.find(why, "Supermarket") ~= nil, "Path furniture can't be placed before its path")
local placedCase, reason = Data.placeFurniture(market, "FoodCase", 13.5, 72, 2)
check(placedCase ~= nil, "A food case fits in the shop once unlocked: " .. tostring(reason))
check(Furniture.locked("Freezer", nil) == nil, "Base furniture is never locked")
check(Furniture.check({}, "GrillStation", -13.5, -9, 0) == nil, "A station fits in the processing room")
check(Furniture.check({}, "DiningTable", -13.5, -22.5, 0) == nil, "A table fits in the dining room")
check(Furniture.check({}, "DiningTable", 9, 9, 0) ~= nil, "Tables stay in the dining room")
check(Furniture.check(Data.decode(market).Furniture, "GrillStation", -22.5, -9, 1) ~= nil, "The Supermarket's prep benches are placed furniture")

-- Cooking: the carried fish becomes a saved kitchen job, then a dish on the pass.
local cook = Data.decode(placedCase)
cook.Hand = fish("Trout", 50)
local _, early = Data.startCooking(Data.decode(nil), "Prep1", "FishFillet", species, 100)
check(early ~= nil, "Cooking needs the supermarket")
local _, rare = Data.startCooking(cook, "Prep1", "FishAndChips", species, 100)
check(rare ~= nil and string.find(rare, "Uncommon") ~= nil, "Recipes need a rare enough fish")
local _, station = Data.startCooking(cook, "GrillStation", "GrilledFish", species, 100)
check(station ~= nil, "Bought stations must be placed first")
local _, wrong = Data.startCooking(cook, "Prep1", "GrilledFish", species, 100)
check(wrong ~= nil, "Recipes are made at their own station")
local cooking = Data.startCooking(cook, "Prep1", "FishFillet", species, 100)
check(cooking and cooking.Hand == nil, "The fish leaves the hand when cooking starts")
local job = cooking.Kitchen.Prep1
check(job.ReadyAt == 100 + Recipes.Items.FishFillet.Seconds, "Cooking takes the recipe's time")
check(job.Dish.Value == Recipes.value("FishFillet", 50) and job.Dish.Value == 70, "Dish value scales the fish value")
check(cook.Hand ~= nil, "Starting a job never mutates the previous profile")
check(select(2, Data.startCooking(Data.decode(cooking), "Prep1", "FishFillet", species, 101)) ~= nil, "One job per station")
check(select(2, Data.collectDish(cooking, "Prep1", 103)) ~= nil, "Dishes can't be collected early")
-- Hand cooking: the minigame score grades the dish, which is ready at once.
local perfect = assert(Data.startCooking(cook, "Prep1", "FishFillet", species, 100, 0.95))
check(perfect.Kitchen.Prep1.ReadyAt == 100, "A hand-cooked dish is ready straight away")
check(perfect.Kitchen.Prep1.Dish.Value == math.floor(70 * 1.25), "A perfect dish sells for more")
local sloppy = assert(Data.startCooking(cook, "Prep1", "FishFillet", species, 100, 0.1))
check(sloppy.Kitchen.Prep1.Dish.Value == math.floor(70 * 0.85), "A sloppy dish sells for less")
check(select(2, Data.startCooking(cook, "Prep1", "FishFillet", species, 100, 2)) ~= nil, "Out-of-range scores are refused")
check(select(2, Data.startCooking(cook, "Prep1", "FishFillet", species, 100, 0 / 0)) ~= nil, "NaN scores are refused")
check(Recipes.grade(0.9).Name == "Perfect" and Recipes.grade(0.7).Name == "Great" and Recipes.grade(0).Name == "Sloppy", "Grades follow the score")
for _, id in Recipes.Order do
	local steps = Recipes.Steps[id]
	check(steps and #steps >= 2, id .. " has minigame steps")
	for _, step in steps do
		check(step.Kind == "Mash" or step.Kind == "Timing" or step.Kind == "Hold", id .. " step kind")
	end
	check(Recipes.minigameSeconds(id) > 2, id .. " can't be skipped instantly")
end
local pack = { Hold = { "####" } }
local fullPack = { Hold = {} }
check(Data.collectDish(cooking, "Prep1", 200, fullPack, species) == nil and cooking.Kitchen.Prep1 ~= nil, "A full backpack leaves the dish on the station")
local cooked = Data.collectDish(cooking, "Prep1", 200, pack, species)
check(cooked and #cooked.Backpack == 1 and #cooked.Pantry == 0 and cooked.Kitchen.Prep1 == nil, "Collecting moves the dish into the backpack")
local heldDish = cooked.Backpack[1].Dish
local stocked = assert(Data.moveInventory(cooked, "Backpack", 1, "Pantry", heldDish, nil, nil, pack, species,
	function(item, expected) return item.Dish == expected or Data.sameDish(item.Dish, expected) end))
check(#stocked.Backpack == 0 and #stocked.Pantry == 1, "Stocking explicitly moves the dish to the pass")
check(cooked.Stats.FoodCooked == 1, "Collected dishes count as cooked")
check(Data.pantryCapacity(cooked) == Data.PANTRY_CAPACITY * 2, "The pass plus one placed case")
print("Broader test index 1 contains: " .. cooking.Furniture[1].ItemId)
local _, failure = Data.pickUpFurniture(cooking, 1)
print("Existing test failure: " .. tostring(failure))
for index, entry in cooking.Furniture do
 if entry.ItemId == "FoodCase" then
  assert(Data.pickUpFurniture(cooking, index), "Actual food shelf pickup must succeed")
  print("Actual food shelf pickup succeeds at index " .. index)
 end
end
