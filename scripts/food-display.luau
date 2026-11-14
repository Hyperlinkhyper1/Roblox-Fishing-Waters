-- Exercise production food-display updates and pickup with recording models.
local fs = require("@lute/fs")
local luau = require("@lute/luau")
local file = fs.open("src/server/CustomerService.luau", "r")
local source = fs.read(file)
fs.close(file)
local function section(first, last)
 local start = assert(string.find(source, first, 1, true))
 local finish = assert(string.find(source, last, start, true))
 return string.sub(source, start, finish - 1)
end
local models = {}
local function model()
 local m = {}
 function m:Destroy() self.destroyed = true self.Parent = nil end
 function m:PivotTo(spot) self.spot = spot self.moves = (self.moves or 0) + 1 end
 table.insert(models, m)
 return m
end
local frame = setmetatable({}, { __mul = function(_, spot) return spot end })
local firstSpot, secondSpot = {}, {}
local spots = { firstSpot, secondSpot }
local dishes = {
 {RecipeId="Soup", FishId="Trout", Kg=1, MadeAt=1, Value=10},
 {RecipeId="Soup", FishId="Trout", Kg=2, MadeAt=2, Value=20},
}
local owner = { UserId = 1 }
local api = luau.load(luau.compile(
 section("local function dishKey(", "-- Placed fixtures")
 .. section("local function refreshFoodDisplay(", "local function refreshShelves(")
 .. "\nreturn { refresh = refreshFoodDisplay, take = takeFood }"
), "food-display", {
 string = string, table = table, math = math, tostring = tostring,
 ownerOf = function() return owner end,
 BoatService = { getProfile = function() return { Angler = { Pantry = dishes } } end },
 FOOD_FIXTURES = { { itemId="FoodCase", spots=spots, depth=1 } },
 fixtureFrames = function() return { frame } end,
 Instance = {new = model},
 dishModel = function(_, spot) local m = model() m.spot = spot return m end,
 carry = function(customer, dish) dish.Parent = customer.model end,
})()
local checks = 0
local function check(condition, message) checks += 1 assert(condition, message) end
local shop = {model = {}}
local item = {record = dishes[1], food = true}
local customer = {items = {item}, model = {FindFirstChild = function() return true end}}
shop.customers = {customer}
api.refresh(shop)
local carried, survivor = shop.displayFood[1].model, shop.displayFood[2].model
local count = #models
check(api.take(shop, customer, item, 0) == carried, "Pickup transfers the displayed dish")
check(carried.Parent == customer.model and not carried.destroyed, "Pickup retains the carried dish")
check(#shop.displayFood == 1 and shop.displayFood[1].model == survivor, "Other dishes are retained")
check(#models == count and not survivor.destroyed, "Pickup does not rebuild other dishes")
item.taken = false
api.refresh(shop)
check(#shop.displayFood == 2 and shop.displayFood[2].model == survivor, "Cancelled pickup restores the dish while preserving other dishes")
spots[2] = {}
api.refresh(shop)
check(shop.displayFood[2].model == survivor and survivor.spot == spots[2], "Moved fixture updates the existing dish position")
table.remove(dishes, 2)
api.refresh(shop)
check(survivor.destroyed and #shop.displayFood == 1, "Removed stock destroys only the obsolete dish")
print("Food display: " .. checks .. " production display and transfer checks passed.")
