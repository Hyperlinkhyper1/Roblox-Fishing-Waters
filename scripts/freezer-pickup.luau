-- Exercise the production freezer display and pickup using recording model doubles.
local fs = require("@lute/fs")
local luau = require("@lute/luau")
local file = fs.open("src/server/CustomerService.luau", "r")
local source = fs.read(file)
fs.close(file)
luau.compile(source)
local function section(first, last)
	local start = assert(string.find(source, first, 1, true))
	local finish = assert(string.find(source, last, start, true))
	return string.sub(source, start, finish - 1)
end
local models = {}
local function model()
	local result = {}
	function result:Destroy()
		self.destroyed, self.Parent = true, nil
		for _, child in models do
			if child.Parent == self then child:Destroy() end
		end
	end
	table.insert(models, result)
	return result
end
local frame = setmetatable({}, { __mul = function(a) return a end })
local record = { FishId = "Trout", Mutation = "Normal", Kg = 2, CaughtAt = 100, Value = 20 }
local freezer = { record }
local owner = { UserId = 42 }
local api = luau.load(luau.compile(
	section("local function recordKey(", "local function setAnchored(")
	.. section("local function takeFromFreezer(", "local function putOnCounter(")
	.. "\nreturn { refresh = refreshDisplay, take = takeFromFreezer }"
), "freezer-pickup", {
	string = string, table = table, math = math, tostring = tostring,
	ownerOf = function() return owner end,
	BoatService = { getProfile = function() return { Angler = { Freezer = freezer } } end },
	DISPLAY_LIMIT = 24, DISPLAY_ROWS = { 0 },
	AnglerData = { FREEZER_CAPACITY = 4 },
	freezerFrames = function() return { frame } end,
	Instance = { new = model },
	FishFreezer = {
		frame = function() return frame end,
		ICE_X = { X = -5, Y = 5 },
		iceSurface = function() return frame end,
	},
	CFrame = { identity = frame, Angles = function() return frame end },
	fishModel = function(_, welded)
		assert(welded, "Display fish must be welded for pickup")
		return model(), { Y = 1, Z = 0.5 }
	end,
	restOn = function() end,
	carry = function(customer, fish) fish.Parent = customer.model end,
})()
local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end
local shop = { freezerPrompt = { Parent = { Parent = {} } } }
local customer = { record = record, model = { FindFirstChild = function() return true end } }
shop.customers = { customer }

api.refresh(shop)
local original = shop.displayFish[1].model
check(api.take(shop, customer) == original, "Pickup moves the actual displayed fish")
check(original.Parent == customer.model and not original.destroyed, "Display refresh preserves the carried fish")
check(#shop.displayFish == 0 and #freezer == 1, "Pickup clears ice immediately and retains stock until payment")
api.refresh(shop)
check(#shop.displayFish == 0, "Periodic refresh cannot restore a fish at the counter")
customer.taken = false
api.refresh(shop)
check(#shop.displayFish == 1, "Cancelled sale returns the fish to the freezer display")
-- Equal records still represent separate fish: only the chosen one leaves.
freezer = { record, table.clone(record) }
api.refresh(shop)
original = shop.displayFish[1].model
check(api.take(shop, customer) == original and #shop.displayFish == 1, "Pickup removes exactly one identical catch")
table.remove(freezer, 1)
customer.sold, customer.taken = true, false
api.refresh(shop)
check(#shop.displayFish == 1, "Selling one identical catch preserves the other display")
customer.taken = false
customer.record = table.clone(record)
customer.record.Mutation = "Golden"
check(api.take(shop, customer) == nil, "Pickup cannot take another mutation")
customer.record = record
customer.model.FindFirstChild = function() return nil end
check(api.take(shop, customer) == nil and #shop.displayFish == 1, "Missing hand leaves freezer intact")
print("Freezer pickup: " .. checks .. " production display and transfer checks passed.")
