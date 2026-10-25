local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local AnglerData = (function()
	-- DATA_SOURCE --
end)()
local vector = {}
local Vector3 = {}
function Vector3.new(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z, Kind = "Vector3", Magnitude = math.sqrt(x*x + y*y + z*z) }, vector)
end
function vector.__sub(a, b) return Vector3.new(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end
local cframe = {}
local CFrame = {}
function CFrame.new(x, y, z)
	return setmetatable({ Position = Vector3.new(x or 0, y or 0, z or 0), Kind = "CFrame" }, cframe)
end
function cframe.__mul(a, b)
	return CFrame.new(a.Position.X+b.Position.X, a.Position.Y+b.Position.Y, a.Position.Z+b.Position.Z)
end
function cframe.__index(a, key)
	if key == "PointToObjectSpace" then return function(_, point) return point - a.Position end end
end
local function typeof(value) return if type(value) == "table" and value.Kind then value.Kind else type(value) end
local owner = { UserId = 42 }
local currentOwner = owner
local marker = { Position = Vector3.new(0, 0, 0), IsA = function() return true end }
local base = {
	FindFirstChild = function() return marker end,
	GetAttribute = function() return CFrame.new() end,
}
local function ownerOf() return currentOwner end
local boatOwner, boatId, moorPier, moorPickup = 42, "Rowboat", nil, nil
local boat = {
	PrimaryPart = { Position = Vector3.new(0, 0, 0), AssemblyLinearVelocity = Vector3.new(0, 0, 0) },
	GetAttribute = function(_, name)
		if name == "PorterPier" then return moorPier end
		if name == "PorterPickup" then return moorPickup end
		return boatOwner
	end,
}
local activeBoat = boat
local profile, failSave, beforeTransform
local saves = 0
local BoatService = {
	activeBoat = function() return boatId, activeBoat end,
	getProfile = function() return profile end,
	updateProgress = function(_, transform)
		if failSave then return false, "Failed save" end
		local current = { Cash = profile.Cash, Angler = AnglerData.decode(profile.Angler) }
		if beforeTransform then beforeTransform(current) end
		local ok = pcall(transform, current)
		if not ok then return false, "Rejected transaction" end
		profile = current
		saves += 1
		return true
	end,
}
local SERVE_DISTANCE, PORTER_DOCK_DISTANCE, CARRY_LENGTH = 14, 32, 1.8
local ShopDesk = { frame = function() return CFrame.new() end }
local FishFreezer = { DEPTH = 3.6, frame = function() return CFrame.new() end }
local StorageRack = { DEPTH = 2 }
local NpcNavigation = { clearance = function() return 2 end }
local function fixtureFrames() return { CFrame.new(10, 0, -8) } end
local manualNear = false
local function near() return manualNear end
local function notify() end
local function refreshDisplay() end
local function leave(customer) customer.leaving = true end
local function describeFish() return "Trout" end
local function bubble() end
local function fishModel() return { Destroy = function() end } end
local function carry() end
local walkCount, onWalk, failWalkAt = 0, nil, nil
local walkedPositions, groundChecks = {}, {}
local function walk(worker, position, _, stayOnGround)
	walkCount += 1
	table.insert(walkedPositions, position)
	groundChecks[walkCount] = stayOnGround
	worker.root.Position = position
	if onWalk then onWalk() end
	return worker.active and walkCount ~= failWalkAt
end
local task = { spawn = function(callback) callback() end }
local function warn() end
-- SELL_SOURCE --
-- PORTER_SOURCE --

local species = { Trout = { AverageKg = 2, RarityDenominator = 10 } }
local record = AnglerData.recordCatch(nil, "Trout", "Normal", 2, 20, 100, species, { Normal = {} }).Hand
local worker, shop, customer
local function reset()
	currentOwner, boatOwner, activeBoat, boatId = owner, 42, boat, "Rowboat"
	moorPier, moorPickup = nil, nil
	boat.PrimaryPart.Position, boat.PrimaryPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0), Vector3.new(0, 0, 0)
	profile = { Cash = 100, Angler = AnglerData.decode(nil) }
	profile.Angler.Staff = { Seller = true, Porter = true }
	profile.Angler.Freezer = { record }
	profile.Angler.Holds.Rowboat = { { PartId = "Oar", X = 1, Y = 1, R = 0 }, { Fish = record, X = 2, Y = 1, R = 0 } }
	worker = {
		active = true, humanoid = { Health = 100 }, root = { Position = Vector3.new(0, 0, 0) },
		model = { Parent = true },
	}
	shop = { base = base, frame = CFrame.new(), staff = { Seller = worker, Porter = worker } }
	customer = { shop = shop, active = true, root = { Position = Vector3.new(0, 0, 0) }, record = record }
	failSave, beforeTransform, onWalk, manualNear, walkCount = false, nil, nil, false, 0
	walkedPositions, groundChecks, failWalkAt = {}, {}, nil
end
reset()
sell(owner, customer)
check(profile.Cash == 100 and not customer.sold, "Manual sale still requires proximity")
sell(owner, customer, worker)
check(profile.Cash == 120 and #profile.Angler.Freezer == 0 and customer.sold, "Hired seller serves while owner is away")
sell(owner, customer, worker)
check(profile.Cash == 120, "Automatic and manual sale cannot pay twice")
reset()
customer.selling = true
sell(owner, customer, worker)
check(profile.Cash == 100, "Manual/automatic sale share the in-flight lock")
reset()
profile.Angler.Staff.Seller = nil
sell(owner, customer, worker)
check(profile.Cash == 100, "Unhired seller cannot sell")
reset()
currentOwner = {}
sell(owner, customer, worker)
check(profile.Cash == 100, "Other base owner cannot be served")
reset()
failSave = true
sell(owner, customer, worker)
check(profile.Cash == 100 and #profile.Angler.Freezer == 1 and not customer.sold, "Failed automatic sale preserves inventory")
failSave = false
sell(owner, customer, worker)
check(profile.Cash == 120 and customer.sold, "Seller retries a failed sale")
reset()
beforeTransform = function() currentOwner = {} end
sell(owner, customer, worker)
check(profile.Cash == 100, "Sale revalidates ownership within transaction")

reset()
check(dockedBoat(shop, owner) == "Rowboat", "Own parked boat can unload")
boat.PrimaryPart.Position = Vector3.new(100, 0, 0)
check(dockedBoat(shop, owner) == nil, "Distant boat cannot unload")
boat.PrimaryPart.Position = Vector3.new(0, 0, 0)
boat.PrimaryPart.AssemblyLinearVelocity = Vector3.new(3, 0, 0)
check(dockedBoat(shop, owner) == nil, "Moving boat cannot unload")
boat.PrimaryPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
boatOwner = 7
check(dockedBoat(shop, owner) == nil, "Another player's boat cannot unload")
reset()
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 2 and #profile.Angler.Holds.Rowboat == 1, "Porter walks a full route and delivers")
check(walkCount == 6 and worker.fish == nil and not worker.busy, "Trip cleans its visual copy and lock")
for index = 1, walkCount do check(groundChecks[index] == true, "Every unloading leg requires supported ground") end
check(walkedPositions[1].X == 17 and walkedPositions[1].Z == 11 and walkedPositions[1].Y == 5.9,
	"Collection starts toward the dock without a front-door detour")
check(walkedPositions[5].X == 17 and walkedPositions[5].Z == 11
	and walkedPositions[6].Z == FishFreezer.DEPTH / 2 + 2.4,
	"Return goes directly from the dock landing to the freezer")
reset()
worker.root.Position = Vector3.new(17, 7, 4)
runPorter(shop, worker, owner)
for _, position in walkedPositions do
	check(position.X ~= 0 or (position.Z ~= 18.6 and position.Z ~= 11),
		"Porter already outside never targets the front door or entrance aisle")
end
check(#profile.Angler.Freezer == 2, "Porter starting outside still delivers cargo")
for _, side in { -1, 1 } do
	reset()
	moorPier, moorPickup = Vector3.new(side * 17, 3.2, -24), Vector3.new(side * 20, 3.2, -24)
	runPorter(shop, worker, owner)
	check(#profile.Angler.Freezer == 2, "Moored boat can be unloaded from either pier")
	check(walkedPositions[1].X == side * 17 and walkedPositions[5].X == side * 17,
		"Company porter uses the landing on the boat's dock side")
	check(walkedPositions[3] == moorPier, "Company pickup stays at pier center despite legacy edge attributes")
end
reset()
failWalkAt = 3
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 1 and #profile.Angler.Holds.Rowboat == 2 and worker.fish == nil and not worker.busy,
	"Unsafe pickup route keeps cargo aboard and releases the porter for a later retry")
reset()
onWalk = function() boat.PrimaryPart.Position = Vector3.new(100, 0, 0) end
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 1 and #profile.Angler.Holds.Rowboat == 2, "Boat departing during trip preserves cargo")
reset()
onWalk = function() if walkCount == 5 then profile.Angler.Holds.Rowboat = {} end end
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 1 and worker.fish == nil, "Player taking fish during walk cannot duplicate stock")
reset()
onWalk = function()
	if walkCount == 5 then
		for index = 1, AnglerData.FREEZER_CAPACITY do profile.Angler.Freezer[index] = record end
	end
end
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 4 and #profile.Angler.Holds.Rowboat == 2, "Freezer filling during trip preserves cargo")
reset()
beforeTransform = function() currentOwner = {} end
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 1 and #profile.Angler.Holds.Rowboat == 2, "Porter transaction rechecks base ownership")
reset()
failSave = true
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 1 and #profile.Angler.Holds.Rowboat == 2 and not worker.busy, "Failed porter save preserves fish and releases trip lock")
reset()
for index = 1, AnglerData.FREEZER_CAPACITY do profile.Angler.Freezer[index] = record end
runPorter(shop, worker, owner)
check(#profile.Angler.Storage == 0 and #profile.Angler.Holds.Rowboat == 2, "Full freezer without racks keeps cargo aboard")
reset()
for index = 1, AnglerData.FREEZER_CAPACITY do profile.Angler.Freezer[index] = record end
profile.Angler.Furniture = { { ItemId = "StorageRack", X = 10, Z = -8, R = 0 } }
runPorter(shop, worker, owner)
check(#profile.Angler.Storage == 1 and #profile.Angler.Holds.Rowboat == 1 and walkCount == 8, "Full freezer sends cargo to a storage rack")
reset()
profile.Angler.Freezer = {}
profile.Angler.Storage = { record }
profile.Angler.Holds.Rowboat = { { PartId = "Oar", X = 1, Y = 1, R = 0 } }
profile.Angler.Furniture = { { ItemId = "StorageRack", X = 10, Z = -8, R = 0 } }
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 1 and #profile.Angler.Storage == 0 and walkCount == 6, "Porter restocks the freezer from a rack")
reset()
profile.Angler.Freezer = {}
profile.Angler.Storage = { record }
profile.Angler.Holds.Rowboat = { { PartId = "Oar", X = 1, Y = 1, R = 0 } }
profile.Angler.Furniture = { { ItemId = "StorageRack", X = 10, Z = -8, R = 0 } }
onWalk = function() if walkCount == 4 then profile.Angler.Storage = {} end end
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 0 and worker.fish == nil, "Player taking stored fish mid-restock cannot duplicate it")
print("Home staff: "
 .. checks .. " production seller, dock and porter transaction checks passed (world/store doubles).")
