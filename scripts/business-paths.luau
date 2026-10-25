-- Pure checks for the business paths (Shared.Paths) and the saved kitchen, pantry
-- and fisherman rules in AnglerData. Run: lute run scripts/business-paths.luau
local Data = require("../src/server/AnglerData")
local Paths = require("../src/shared/Paths")
local Recipes = require("../src/shared/Recipes")
local Furniture = require("../src/shared/FurnitureCatalog")
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
check(Paths.chooseProblem(profile(shop, 4999), "Supermarket") ~= nil, "The next path costs coins")
check(Paths.chooseProblem(profile(shop, 5000), "Restaurant") ~= nil, "The restaurant needs the supermarket first")
check(Paths.chooseProblem(profile(shop, 5000), "Supermarket") == nil, "A finished stage can buy the next")

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
local _, why = Data.placeFurniture(locked, "FoodCase", -10, 8, 0)
check(why ~= nil and string.find(why, "Supermarket") ~= nil, "Path furniture can't be placed before its path")
local placedCase, reason = Data.placeFurniture(market, "FoodCase", -10, 8, 0)
check(placedCase ~= nil, "A food case fits in the shop once unlocked: " .. tostring(reason))
check(Furniture.locked("Freezer", nil) == nil, "Base furniture is never locked")
check(Furniture.check({}, "GrillStation", -10, -8, 0) == nil, "A station fits in the processing room")
check(Furniture.check({}, "DiningTable", -14, -20, 0) == nil, "A table fits in the dining room")
check(Furniture.check({}, "DiningTable", 10, 8, 0) ~= nil, "Tables stay in the dining room")
check(Furniture.check({}, "GrillStation", -21, -8, 1) ~= nil, "Built-in benches stay clear")

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
local cooked = Data.collectDish(cooking, "Prep1", 200)
check(cooked and #cooked.Pantry == 1 and cooked.Kitchen.Prep1 == nil, "Collecting moves the dish onto the pass")
check(cooked.Stats.FoodCooked == 1, "Collected dishes count as cooked")
check(Data.pantryCapacity(cooked) == Data.PANTRY_CAPACITY * 2, "The pass plus one placed case")
check(select(2, Data.pickUpFurniture(cooking, 1)) == nil, "A case can be picked up while its dishes still fit")

-- Selling a dish: shop price in the supermarket, the markup in the restaurant.
local dish = cooked.Pantry[1]
local sold, price = Data.sellDish(cooked, dish, 1, "FoodSold")
check(sold and price == 70 and #sold.Pantry == 0 and sold.Stats.FoodSold == 1, "Shop customers pay the dish value")
check(sold.Stats.CoinsEarned == cooked.Stats.CoinsEarned + 70, "Dish sales count as earnings")
local served, markup = Data.sellDish(cooked, dish, Recipes.RESTAURANT_MARKUP, "DinersServed")
check(served and markup == 105 and served.Stats.DinersServed == 1, "Diners pay the restaurant markup")
check(select(1, Data.sellDish(sold, dish, 1, "FoodSold")) == nil, "A dish can't be sold twice")

-- A station can't be picked up mid-cook.
local grill = Data.decode(cooked)
grill.Paths.Unlocked.Supermarket = true
grill.FurnitureStock.GrillStation = 1
grill = assert(Data.placeFurniture(grill, "GrillStation", -10, -8, 0))
grill.Hand = fish("Trout", 50)
grill.Hand.FishId = "Tuna"
grill = assert(Data.startCooking(grill, "GrillStation", "GrilledFish", species, 300))
local grillIndex
for index, entry in grill.Furniture do
	if entry.ItemId == "GrillStation" then
		grillIndex = index
	end
end
check(select(2, Data.pickUpFurniture(grill, grillIndex)) ~= nil, "Busy stations stay put")

-- Taking a fish back out of the freezer for the kitchen.
local freezer = Data.decode(nil)
freezer.Freezer = { fish("Trout", 10, 1), fish("Trout", 20, 2) }
local taken = Data.takeFrozen(freezer, freezer.Freezer[2])
check(taken and taken.Hand.Value == 20 and #taken.Freezer == 1, "Takes exactly the chosen fish")
check(select(2, Data.takeFrozen(taken, taken.Freezer[1])) ~= nil, "Full hands can't take another")

-- The fisherman stows catches into his boat's hold until it is full.
local layout = { Hold = { "####" }, StarterParts = {} }
local crew = Data.decode(nil)
local roll = { FishId = "Trout", Kg = 2, Value = 30, Size = "Normal", Traits = { Mutation = "Normal" } }
local first = Data.fishermanCatch(crew, "Rowboat", layout, roll, 10, species, mutations)
check(first and #first.Holds.Rowboat == 1 and first.Stats.FishermanCatches == 1, "Catches go into the hold")
check(first.Stats.TotalCaught == 0, "The fisherman's catches aren't the player's own")
local second = Data.fishermanCatch(first, "Rowboat", layout, roll, 11, species, mutations)
check(second and #second.Holds.Rowboat == 2, "Two fish fit a four-cell hold")
check(Data.fishermanCatch(second, "Rowboat", layout, roll, 12, species, mutations) == nil, "A full hold takes no more")

-- Both branches open after the supermarket; the other follows the first.
local branch = Data.decode(market)
branch.Stats.FoodCooked, branch.Stats.FoodSold, branch.Stats.CoinsEarned = 20, 15, 12500
branch.Furniture = { { ItemId = "FoodCase", X = -10, Z = 8, R = 0 }, { ItemId = "GrillStation", X = -10, Z = -8, R = 0 } }
local open = Paths.choices(profile(branch))
check(#open == 2 and table.find(open, "Restaurant") and table.find(open, "Company"), "Choose restaurant or company")
local company = Data.choosePath(branch, "Company", Paths.Stages.Company)
check(#Paths.choices(profile(company)) == 0, "The other branch waits for 100%")
company.Staff.Fisherman = true
company.Stats.FishermanCatches = 50
company.Stats.CoinsEarned += 40000
local owner = profile(company, 15000)
owner.OwnedBoats.FishingBoat = true
check(Paths.progress(owner, "Company") == 1, "Company goals complete")
local next = Paths.choices(owner)
check(#next == 1 and next[1] == "Restaurant", "The restaurant opens after the company")
local all = Data.choosePath(company, "Restaurant", Paths.Stages.Restaurant)
check(all.FurnitureStock.DiningTable == 2, "The restaurant grants dining tables")
check(not Paths.finished(profile(all)), "The last stage still has goals")
for _, id in Paths.Order do
	check(all.Paths.Unlocked[id], "Every stage stacks: " .. id)
end

print("Business paths: " .. checks .. " path, kitchen, pantry and fisherman checks passed (pure data).")
