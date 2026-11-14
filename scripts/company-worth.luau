local Worth = require("../src/server/CompanyWorth")
local Boats = require("../src/shared/BoatCatalog")
local Furniture = require("../src/shared/FurnitureCatalog")
local BoatFurniture = require("../src/shared/BoatFurniture")
local Backpacks = require("../src/shared/BackpackCatalog")
local Islands = require("../src/shared/CompanyIslands")
local Prices = require("../src/server/StockPrices")
local checks = 0
local function check(value, message) checks += 1; assert(value, message) end
check(Worth.calculate(nil, 0) == 0 and Worth.calculate({}, 0) == 0, "Absent assets have zero worth")
local profile = {
	Cash = 100, OwnedBoats = { Rowboat = true, FishingBoat = true, Retired = true },
	Portfolio = { Holdings = { AAPL = { Shares = 2, Cost = 99999 } } },
	Angler = {
		Stats = { CoinsEarned = 99999999, TotalCaught = 99999 },
		Catches = { Trout = { Count = 9999, HighestValue = 99999 } },
		FurnitureStock = { Freezer = 2, Unknown = 200 },
		Furniture = { { ItemId = "Freezer" } },
		CompanyFurniture = { { ItemId = "Freezer" } },
		BoatFurnitureStock = { DeckChair = 2 },
		BoatFurniture = { Rowboat = { { Id = "DeckChair" } } },
		BackpackId = "Satchel", CompanyIsland = 1,
		Hand = { Value = 10 }, Cooler = { { Value = 11 } }, Freezer = { { Value = 12 } },
		Storage = { { Value = 13 } }, Pantry = { { Value = 14 } },
		Backpack = { { Fish = { Value = 15 } }, { PartId = "Lantern" } },
		Holds = { Rowboat = { { Fish = { Value = 16 } }, { PartId = "Motor" } } },
		KitchenStorage = { Fish = { { Value = 17 } } }, Kitchen = { Prep = { Dish = { Value = 18 } } },
	},
}
local expected = math.floor(100 + Boats.FishingBoat.Price + Furniture.Items.Freezer.Price * 4
	+ BoatFurniture.Items.DeckChair.Price * 3 + Backpacks.Items.Satchel.Price + Islands.PRICE
	+ 126 + 2 * Prices.price("AAPL", 0))
check(Worth.calculate(profile, 0) == expected, "Assets and all nine fish/dish locations are valued exactly once")
profile.Angler.Stats.CoinsEarned = 0
profile.Angler.Catches = {}
check(Worth.calculate(profile, 0) == expected, "Historical earnings/catches do not inflate company assets")
profile.Cash -= 60
check(Worth.calculate(profile, 0) == expected - 60, "Spending decreases current net worth")
profile.Angler.FurnitureStock.Freezer -= 1
table.insert(profile.Angler.Furniture, { ItemId = "Freezer" })
check(Worth.calculate(profile, 0) == expected - 60, "Placing an owned item preserves net worth")
profile.Portfolio.Holdings.AAPL.Cost = 1
check(Worth.calculate(profile, 0) == expected - 60, "Shares use current market value rather than purchase cost")
profile.Portfolio.Holdings.AAPL.Shares = 1
check(Worth.calculate(profile, 0) == math.floor(expected - 60 - Prices.price("AAPL", 0)), "Shares sold are no longer counted")
check(Worth.calculate({ Cash = 2 ^ 53 - 1, OwnedBoats = { FishingBoat = true } }, 0) == 2 ^ 53 - 1,
	"Ordered score remains within exact integer range")
check(profile.Cash == 40 and profile.Angler.FurnitureStock.Freezer == 1, "Calculation does not mutate the save")
local beforeCrew = Worth.calculate(profile, 0)
profile.CompanyCrew = {
	["202"] = { Hand = { Value = 25 }, Backpack = { { Fish = { Value = 30 } }, { Fish = { Value = 45 } } } },
	["303"] = { Hand = { Value = 50 }, Backpack = { { Fish = { Value = 15 } } } },
}
check(Worth.calculate(profile, 0) == beforeCrew + 165, "Guest hands and bags count once alongside the creator's inventory")
table.insert(profile.Angler.Freezer, table.remove(profile.CompanyCrew["202"].Backpack, 1).Fish)
check(Worth.calculate(profile, 0) == beforeCrew + 165, "Unloading a guest bag into company storage preserves net worth")
print("Company net worth: " .. checks .. " asset-accounting checks passed.")
