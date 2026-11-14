-- Replacement value of the assets in one save, counted once for the company.
-- Cash + boats + placed/unplaced furniture + backpack + island + unsold fish/
-- dishes + the current market value of shares. Lifetime earnings and catch
-- records are deliberately excluded: they are history, not assets still owned.
local shared = if script then game:GetService("ReplicatedStorage").Shared else nil
local Boats = if script then require(shared.BoatCatalog) else require("../shared/BoatCatalog")
local Furniture = if script then require(shared.FurnitureCatalog) else require("../shared/FurnitureCatalog")
local BoatFurniture = if script then require(shared.BoatFurniture) else require("../shared/BoatFurniture")
local Backpacks = if script then require(shared.BackpackCatalog) else require("../shared/BackpackCatalog")
local Islands = if script then require(shared.CompanyIslands) else require("../shared/CompanyIslands")
local Stocks = if script then require(shared.Stocks) else require("../shared/Stocks")
local DayNight = if script then require(shared.DayNight) else require("../shared/DayNight")
local Prices = if script then require(script.Parent.StockPrices) else require("./StockPrices")

local Worth = {}
local MAX_VALUE = 2 ^ 53 - 1

local function amount(value)
	return if type(value) == "number" and value == value and value > 0 then math.min(value, MAX_VALUE) else 0
end

function Worth.calculate(profile, marketElapsed: number?): number
	if type(profile) ~= "table" then return 0 end
	local total = amount(profile.Cash)
	local function add(value)
		total = math.min(MAX_VALUE, total + amount(value))
	end
	for id, owned in profile.OwnedBoats or {} do
		if owned and Boats[id] then add(Boats[id].Price) end
	end
	local angler = profile.Angler or {}
	local function stock(entries, catalog)
		for id, count in entries or {} do
			if catalog[id] then add(amount(count) * amount(catalog[id].Price)) end
		end
	end
	stock(angler.FurnitureStock, Furniture.Items)
	stock(angler.BoatFurnitureStock, BoatFurniture.Items)
	for _, entries in { angler.Furniture or {}, angler.CompanyFurniture or {} } do
		for _, entry in entries do
			local item = Furniture.Items[entry.ItemId]
			if item then add(item.Price) end
		end
	end
	for _, entries in angler.BoatFurniture or {} do
		for _, entry in entries do
			local item = BoatFurniture.Items[entry.Id]
			if item then add(item.Price) end
		end
	end
	local backpack = Backpacks.Items[angler.BackpackId or "Starter"]
	if backpack then add(backpack.Price) end
	if angler.CompanyIsland then add(Islands.PRICE) end
	local function fish(entries, wrapped)
		for _, entry in entries or {} do
			local record = if wrapped then entry.Fish else entry
			if record then add(record.Value) end
		end
	end
	if angler.Hand then add(angler.Hand.Value) end
	-- Callers pass the canonical save: Angler contains the creator's carried
	-- fish, and CompanyCrew contains each guest's separate carried inventory.
	for _, personal in profile.CompanyCrew or {} do
		if type(personal) == "table" then
			if personal.Hand then add(personal.Hand.Value) end
			fish(personal.Backpack, true)
		end
	end
	for _, entries in { angler.Cooler or {}, angler.Freezer or {}, angler.Storage or {}, angler.Pantry or {} } do
		fish(entries, false)
	end
	fish(angler.Backpack, true)
	for _, entries in angler.Holds or {} do fish(entries, true) end
	fish((angler.KitchenStorage or {}).Fish, false)
	for _, job in angler.Kitchen or {} do
		if job.Dish then add(job.Dish.Value) end
	end
	local elapsed = marketElapsed
	if elapsed == nil then
		elapsed = if script then DayNight.elapsed() else os.time() - DayNight.EPOCH
	end
	local tick = Stocks.tickAt(elapsed)
	for ticker, holding in Stocks.decode(profile.Portfolio).Holdings do
		add(holding.Shares * Prices.price(ticker, tick))
	end
	return math.floor(total)
end

return Worth
