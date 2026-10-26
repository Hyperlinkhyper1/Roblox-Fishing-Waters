local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local AnglerData = (function()
	-- DATA_SOURCE --
end)()
local Color3 = {
	fromRGB = function()
		return {}
	end,
}
local StaffCatalog = (function()
	-- STAFF_SOURCE --
end)()
local vector = {}
local Vector3 = {}
function Vector3.new(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z, Kind = "Vector3", Magnitude = math.sqrt(x * x + y * y + z * z) }, vector)
end
function vector.__sub(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
function vector.__add(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
local cframe = {}
local CFrame = {}
function CFrame.new(x, y, z)
	return setmetatable({ Position = Vector3.new(x or 0, y or 0, z or 0), Kind = "CFrame" }, cframe)
end
function cframe.__mul(a, b)
	return CFrame.new(a.Position.X + b.Position.X, a.Position.Y + b.Position.Y, a.Position.Z + b.Position.Z)
end
function cframe.__index(a, key)
	if key == "PointToObjectSpace" then
		return function(_, point)
			return point - a.Position
		end
	end
end
local function typeof(value)
	return if type(value) == "table" and value.Kind then value.Kind else type(value)
end
local owner = { UserId = 42 }
local currentOwner = owner
local marker = {
	Position = Vector3.new(0, 0, 0),
	IsA = function()
		return true
	end,
}
local base = {
	FindFirstChild = function()
		return marker
	end,
	GetAttribute = function()
		return CFrame.new()
	end,
}
local function ownerOf()
	return currentOwner
end
local boatOwner, boatId, moorPier, moorPickup = 42, "Rowboat", nil, nil
local boat = {
	PrimaryPart = { Position = Vector3.new(0, 0, 0), AssemblyLinearVelocity = Vector3.new(0, 0, 0) },
	GetAttribute = function(_, name)
		if name == "PorterPier" then
			return moorPier
		end
		if name == "PorterPickup" then
			return moorPickup
		end
		return boatOwner
	end,
}
local activeBoat = boat
local profile, failSave, beforeTransform
local saves = 0
local BoatService = {
	activeBoat = function()
		return boatId, activeBoat
	end,
	getProfile = function()
		return profile
	end,
	updateProgress = function(_, transform)
		if failSave then
			return false, "Failed save"
		end
		local current = { Cash = profile.Cash, Angler = AnglerData.decode(profile.Angler) }
		if beforeTransform then
			beforeTransform(current)
		end
		local ok = pcall(transform, current)
		if not ok then
			return false, "Rejected transaction"
		end
		profile = current
		saves += 1
		return true
	end,
}
local SERVE_DISTANCE, PORTER_DOCK_DISTANCE, CARRY_LENGTH = 14, 32, 1.8
local ShopDesk = {
	frame = function()
		return CFrame.new()
	end,
}
local FishFreezer = {
	DEPTH = 3.6,
	frame = function()
		return CFrame.new()
	end,
}
local StorageRack = { DEPTH = 2 }
local NpcNavigation = {
	clearance = function()
		return 2
	end,
}
local function fixtureFrames()
	return { CFrame.new(10, 0, -8) }
end
local manualNear = false
local function near()
	return manualNear
end
local function notify() end
local function refreshDisplay() end
local function leave(customer)
	customer.leaving = true
end
local function describeFish()
	return "Trout"
end
local function bubble() end
local visualCount, destroyedVisuals, destroyedGrips = 0, 0, 0
local function fishModel()
	visualCount += 1
	return {
		Destroy = function()
			destroyedVisuals += 1
		end,
	}
end
local function carry(worker)
	worker.grip = {
		Destroy = function()
			destroyedGrips += 1
		end,
	}
end
local walkCount, onWalk, failWalkAt = 0, nil, nil
local walkedPositions, groundChecks, straightChecks = {}, {}, {}
local function walk(worker, position, _, stayOnGround, straight)
	walkCount += 1
	table.insert(walkedPositions, position)
	groundChecks[walkCount] = stayOnGround
	straightChecks[walkCount] = straight
	worker.root.Position = position + Vector3.new(0, worker.humanoid.HipHeight + worker.root.Size.Y / 2, 0)
	if onWalk then
		onWalk()
	end
	return worker.active and walkCount ~= failWalkAt
end
local task = {
	spawn = function(callback)
		callback()
	end,
}
local function warn() end
-- SELL_SOURCE --
-- PORTER_SOURCE --

local species = { YellowfinTuna = { AverageKg = 100, RarityDenominator = 10 } }
local record = AnglerData.recordCatch(nil, "YellowfinTuna", "Normal", 100, 20, 100, species, { Normal = {} }).Hand
local freezerCapacity = 0
local packed = AnglerData.decode(nil)
while AnglerData.canFreeze(packed, record) do
	table.insert(packed.Freezer, record)
	freezerCapacity += 1
end
check(freezerCapacity == 4, "Four large tuna fit the test cooler")
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
		active = true,
		humanoid = { Health = 100, HipHeight = 2 },
		root = { Position = Vector3.new(0, 3, 0), Size = Vector3.new(2, 2, 1) },
		model = {
			Parent = true,
			Destroy = function(self)
				self.Parent = nil
			end,
		},
	}
	shop = { base = base, frame = CFrame.new(), staff = { Seller = worker, Porter = worker } }
	customer = { shop = shop, active = true, root = { Position = Vector3.new(0, 0, 0) }, record = record }
	failSave, beforeTransform, onWalk, manualNear, walkCount = false, nil, nil, false, 0
	walkedPositions, groundChecks, straightChecks, failWalkAt = {}, {}, {}, nil
	visualCount, destroyedVisuals, destroyedGrips = 0, 0, 0
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
check(
	profile.Cash == 100 and #profile.Angler.Freezer == 1 and not customer.sold,
	"Failed automatic sale preserves inventory"
)
failSave = false
sell(owner, customer, worker)
check(profile.Cash == 120 and customer.sold, "Seller retries a failed sale")
reset()
beforeTransform = function()
	currentOwner = {}
end
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
check(walkCount == 8 and worker.fish == nil and not worker.busy, "Trip cleans its visual copy and lock")
for index = 1, walkCount do
	check(groundChecks[index] == true, "Every unloading leg requires supported ground")
end
check(
	walkedPositions[1].X == 17 and walkedPositions[1].Z == 11 and walkedPositions[1].Y == 5.9,
	"Collection starts toward the dock without a front-door detour"
)
check(
	walkedPositions[7].X == 17 and walkedPositions[7].Z == 11 and walkedPositions[8].Z == FishFreezer.DEPTH / 2 + 2.4,
	"Return goes directly from the dock landing to the freezer"
)
for index = 2, 7 do
	check(straightChecks[index] == true, "Dock legs follow centerlines without navmesh detours")
end
check(not straightChecks[1] and not straightChecks[8], "Quay and freezer routes retain normal pathfinding")
reset()
worker.root.Position = Vector3.new(17, 7, 4)
runPorter(shop, worker, owner)
for _, position in walkedPositions do
	check(
		position.X ~= 0 or (position.Z ~= 18.6 and position.Z ~= 11),
		"Porter already outside never targets the front door or entrance aisle"
	)
end
check(#profile.Angler.Freezer == 2, "Porter starting outside still delivers cargo")
check(
	walkedPositions[1].Z == 4 and walkedPositions[2].Z == -38,
	"Porter already on the ramp continues toward the pickup instead of returning to the quay"
)
reset()
worker.root.Position = Vector3.new(6, 6.3, -38)
runPorter(shop, worker, owner)
check(
	walkedPositions[1].X == 6 and walkedPositions[2].X == 0 and walkedPositions[2].Z == -38,
	"Pickup retry on the crosswalk goes straight to the fish without a quay detour"
)
check(#profile.Angler.Freezer == 2, "Crosswalk retry completes the delivery")
reset()
worker.root.Position = Vector3.new(-17, 6.3, -24)
runPorter(shop, worker, owner)
check(
	walkedPositions[2].X == -17 and walkedPositions[2].Z == -38 and walkedPositions[3].X == 0,
	"Porter already on the left pier approaches the pickup from that side without overshooting to the right pier"
)
check(#profile.Angler.Freezer == 2, "Left-pier pickup completes the delivery")
for _, side in { -1, 1 } do
	reset()
	moorPier, moorPickup = Vector3.new(side * 17, 3.2, -24), Vector3.new(side * 20, 3.2, -24)
	runPorter(shop, worker, owner)
	check(#profile.Angler.Freezer == 2, "Moored boat can be unloaded from either pier")
	check(
		walkedPositions[1].X == side * 17 and walkedPositions[7].X == side * 17,
		"Company porter uses the landing on the boat's dock side"
	)
	check(walkedPositions[4] == moorPier, "Company pickup stays at pier center despite legacy edge attributes")
end
reset()
failWalkAt = 3
runPorter(shop, worker, owner)
check(
	#profile.Angler.Freezer == 1 and #profile.Angler.Holds.Rowboat == 2 and worker.fish == nil and not worker.busy,
	"Unsafe pickup route keeps cargo aboard and releases the porter for a later retry"
)
check(worker.active and shop.staff.Porter == worker, "Blocked route on the deck keeps the existing porter")
reset()
failWalkAt = 1
onWalk = function()
	worker.root.Position = Vector3.new(20, 4, -12)
end
runPorter(shop, worker, owner)
check(
	not worker.active and worker.model.Parent == nil and shop.staff.Porter == nil,
	"Porter stranded below the deck is retired so the staff loop can replace him"
)
check(
	#profile.Angler.Freezer == 1 and #profile.Angler.Holds.Rowboat == 2 and not worker.busy,
	"Stranded porter recovery leaves all cargo in its hold"
)
reset()
failWalkAt = 5
onWalk = function()
	if walkCount == 5 then
		worker.root.Position = Vector3.new(20, 4, -12)
	end
end
runPorter(shop, worker, owner)
check(
	not worker.active and worker.fish == nil and #profile.Angler.Freezer == 1 and #profile.Angler.Holds.Rowboat == 2,
	"Falling on the return trip removes the carried visual without losing or duplicating cargo"
)
reset()
failWalkAt = 1
onWalk = function()
	worker.root.Position = Vector3.new(20, 4, -12)
	currentOwner = {}
end
runPorter(shop, worker, owner)
check(
	worker.active and shop.staff.Porter == worker,
	"Owner changes cancel unloading without retiring another owner's staff"
)
reset()
onWalk = function()
	boat.PrimaryPart.Position = Vector3.new(100, 0, 0)
end
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 1 and #profile.Angler.Holds.Rowboat == 2, "Boat departing during trip preserves cargo")
reset()
onWalk = function()
	if walkCount == 5 then
		profile.Angler.Holds.Rowboat = {}
	end
end
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 1 and worker.fish == nil, "Player taking fish during walk cannot duplicate stock")
reset()
onWalk = function()
	if walkCount == 5 then
		for index = 1, freezerCapacity do
			profile.Angler.Freezer[index] = record
		end
	end
end
runPorter(shop, worker, owner)
check(
	#profile.Angler.Freezer == 4 and #profile.Angler.Holds.Rowboat == 2,
	"Freezer filling during trip preserves cargo"
)
reset()
beforeTransform = function()
	currentOwner = {}
end
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 1 and #profile.Angler.Holds.Rowboat == 2, "Porter transaction rechecks base ownership")
reset()
failSave = true
runPorter(shop, worker, owner)
check(
	#profile.Angler.Freezer == 1 and #profile.Angler.Holds.Rowboat == 2 and not worker.busy,
	"Failed porter save preserves fish and releases trip lock"
)
reset()
for index = 1, freezerCapacity do
	profile.Angler.Freezer[index] = record
end
runPorter(shop, worker, owner)
check(
	#profile.Angler.Storage == 0 and #profile.Angler.Holds.Rowboat == 2,
	"Full freezer without racks keeps cargo aboard"
)
reset()
for index = 1, freezerCapacity do
	profile.Angler.Freezer[index] = record
end
profile.Angler.Furniture = { { ItemId = "StorageRack", X = 10, Z = -8, R = 0 } }
runPorter(shop, worker, owner)
check(
	#profile.Angler.Storage == 1 and #profile.Angler.Holds.Rowboat == 1 and walkCount == 10,
	"Full freezer sends cargo to a storage rack"
)
reset()
profile.Angler.Freezer = {}
profile.Angler.Storage = { record }
profile.Angler.Holds.Rowboat = { { PartId = "Oar", X = 1, Y = 1, R = 0 } }
profile.Angler.Furniture = { { ItemId = "StorageRack", X = 10, Z = -8, R = 0 } }
runPorter(shop, worker, owner)
check(
	#profile.Angler.Freezer == 1 and #profile.Angler.Storage == 0 and walkCount == 6,
	"Porter restocks the freezer from a rack"
)
reset()
profile.Angler.Freezer = {}
profile.Angler.Storage = { record }
profile.Angler.Holds.Rowboat = { { PartId = "Oar", X = 1, Y = 1, R = 0 } }
profile.Angler.Furniture = { { ItemId = "StorageRack", X = 10, Z = -8, R = 0 } }
onWalk = function()
	if walkCount == 4 then
		profile.Angler.Storage = {}
	end
end
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 0 and worker.fish == nil, "Player taking stored fish mid-restock cannot duplicate it")

local function batchSetup()
	reset()
	profile.Angler.Upgrades = { PorterSpeed = 4, PorterCapacity = 4 }
	profile.Angler.Freezer = {}
	for index = 1, 6 do
		local fish = table.clone(record)
		fish.CaughtAt += index
		table.insert(profile.Angler.Holds.Rowboat, { Fish = fish, X = index + 2, Y = 1, R = 0 })
	end
end
batchSetup()
local beforeSaves = saves
-- Four large tuna fit; the porter can carry five but must stop at available space.
runPorter(shop, worker, owner)
check(worker.humanoid.WalkSpeed == 32, "Saved speed upgrade applies to the working porter")
check(
	#profile.Angler.Freezer == 4 and #profile.Angler.Holds.Rowboat == 4 and walkCount == 8,
	"One trip carries multiple fish and respects freezer room"
)
check(saves == beforeSaves + 1, "A whole porter load is committed in one transaction")
check(
	visualCount == 4 and destroyedVisuals == 4 and destroyedGrips == 4 and worker.load == nil,
	"Each carried fish has a visual and all fish/grips are cleaned after delivery"
)
check(profile.Angler.Holds.Rowboat[1].PartId == "Oar", "Batch unloading preserves boat parts")
batchSetup()
profile.Angler.Upgrades.PorterCapacity = 1
runPorter(shop, worker, owner)
check(
	#profile.Angler.Freezer == 2 and #profile.Angler.Holds.Rowboat == 6,
	"The first carry upgrade moves exactly two fish"
)
batchSetup()
for index = 1, 4 do
	profile.Angler.Freezer[index] = record
end
profile.Angler.Furniture = { { ItemId = "StorageRack", X = 10, Z = -8, R = 0 } }
runPorter(shop, worker, owner)
check(
	#profile.Angler.Storage == 5 and #profile.Angler.Holds.Rowboat == 3,
	"Maximum capacity carries five fish from a boat to a rack"
)
batchSetup()
for index = 1, 4 do
	profile.Angler.Freezer[index] = record
end
profile.Angler.Furniture = {
	{ ItemId = "StorageRack", X = 10, Z = -8, R = 0 },
	{ ItemId = "StorageRack", X = 10, Z = -4, R = 0 },
}
for index = 1, 7 do
	profile.Angler.Storage[index] = record
end
runPorter(shop, worker, owner)
check(
	#profile.Angler.Storage == 8 and #profile.Angler.Holds.Rowboat == 7,
	"A load stops at the physical rack's remaining space"
)
batchSetup()
profile.Angler.Holds.Rowboat = {}
profile.Angler.Storage = { record, record, record, record, record }
profile.Angler.Furniture = { { ItemId = "StorageRack", X = 10, Z = -8, R = 0 } }
runPorter(shop, worker, owner)
check(
	#profile.Angler.Freezer == 4 and #profile.Angler.Storage == 1 and walkCount == 6,
	"Carry upgrades also batch restocking and respect freezer capacity"
)
batchSetup()
beforeSaves = saves
onWalk = function()
	if walkCount == 5 then
		local changed = table.clone(record)
		changed.CaughtAt += 100
		profile.Angler.Holds.Rowboat[5].Fish = changed
	end
end
runPorter(shop, worker, owner)
check(
	#profile.Angler.Freezer == 0 and #profile.Angler.Holds.Rowboat == 8 and saves == beforeSaves,
	"A stale fish rolls back the entire load, including fish processed earlier in the transaction"
)
check(
	destroyedVisuals == visualCount and destroyedGrips == visualCount and not worker.busy,
	"Rejected batches release every visual, grip and trip lock"
)
batchSetup()
failSave = true
runPorter(shop, worker, owner)
check(
	#profile.Angler.Freezer == 0 and #profile.Angler.Holds.Rowboat == 8 and destroyedVisuals == visualCount,
	"A failed batch save keeps the entire catch aboard and cleans the carried models"
)
batchSetup()
onWalk = function()
	if walkCount == 5 then
		for index = 1, 3 do
			profile.Angler.Freezer[index] = record
		end
	end
end
runPorter(shop, worker, owner)
check(
	#profile.Angler.Freezer == 3 and #profile.Angler.Holds.Rowboat == 8,
	"Freezer filling mid-trip rejects the whole batch without overflowing or losing cargo"
)
batchSetup()
activeBoat = nil
companyDock = function()
	return "Rowboat", boat
end
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 4, "Company boats receive the same multi-fish unloading upgrades")
companyDock = nil
-- A large fish can be blocked while a small catch still fits in the gaps.
reset()
for index = 1, freezerCapacity do
	profile.Angler.Freezer[index] = record
end
local little = table.clone(record)
little.FishId, little.Kg, little.CaughtAt = "Anchovy", 0.01, 500
profile.Angler.Holds.Rowboat = {
	{ Fish = record, X = 1, Y = 1, R = 0 },
	{ Fish = little, X = 2, Y = 1, R = 0 },
}
check(
	not AnglerData.canFreeze(profile.Angler, record) and AnglerData.canFreeze(profile.Angler, little),
	"Remaining cooler gaps accept a small fish after large fish stop fitting"
)
runPorter(shop, worker, owner)
check(
	#profile.Angler.Freezer == freezerCapacity + 1
		and #profile.Angler.Holds.Rowboat == 1
		and profile.Angler.Holds.Rowboat[1].Fish.FishId == record.FishId,
	"Porter skips a blocked large fish and delivers the small fish that fits"
)
print(
	"Home staff: " .. checks .. " production seller, dock and porter transaction checks passed (world/store doubles)."
)
