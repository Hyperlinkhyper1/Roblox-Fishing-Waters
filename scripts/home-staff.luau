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
function vector.__mul(a, b)
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3.zero = Vector3.new(0, 0, 0)
local cframe = {}
local CFrame = {}
function CFrame.new(x, y, z)
	if type(x) == "table" then
		x, y, z = x.X, x.Y, x.Z
	end
	return setmetatable({ Position = Vector3.new(x or 0, y or 0, z or 0), Kind = "CFrame" }, cframe)
end
function CFrame.lookAt(at)
	return CFrame.new(at)
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
local SERVE_DISTANCE, PORTER_DOCK_DISTANCE, PORTER_TELEPORT_SECONDS, CARRY_LENGTH = 14, 32, 30, 1.8
local ShopDesk = {
	frame = function()
		return CFrame.new(0, 8.9, 22)
	end,
}
local FishFreezer = {
	DEPTH = 3.6,
	frame = function()
		return CFrame.new(-14.8, 6.06, 45.8)
	end,
}
local StorageRack = { DEPTH = 2 }
local NpcNavigation = {
	clearance = function()
		return 2
	end,
}
local function fixtureFrames(shop)
	return { shop.frame * CFrame.new(10, 0.16, -8) }
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
-- Walks finish instantly; time passes only through task.wait or a test's onWalk.
local clock = 0
local os = {
	clock = function()
		return clock
	end,
}
local function walk(worker, position, allowed, stayOnGround, straight)
	walkCount += 1
	table.insert(walkedPositions, position)
	groundChecks[walkCount] = stayOnGround
	straightChecks[walkCount] = straight
	local blocked = failWalkAt == "return" and walkCount >= 5
	if not blocked then
		worker.root.Position = position + Vector3.new(0, worker.humanoid.HipHeight + worker.root.Size.Y / 2, 0)
	end
	if onWalk then
		onWalk()
	end
	return worker.active
		and (allowed == nil or allowed())
		and walkCount ~= failWalkAt
		and not blocked
end
local task = {
	spawn = function(callback)
		callback()
	end,
	wait = function(seconds)
		clock += seconds or 0
	end,
}
-- Root positions the porter was set down at, in order.
local teleports = {}
local teleportingRoot = {
	__newindex = function(root, key, value)
		if key == "CFrame" then
			table.insert(teleports, value.Position)
			root.Position = value.Position
		else
			rawset(root, key, value)
		end
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
		humanoid = { Health = 100, HipHeight = 2, MoveTo = function() end },
		root = setmetatable({ Position = Vector3.new(0, 8.9, 22), Size = Vector3.new(2, 2, 1) }, teleportingRoot),
		model = {
			Parent = true,
			Destroy = function(self)
				self.Parent = nil
			end,
		},
	}
	shop = { base = base, frame = CFrame.new(0, 5.9, 43), staff = { Seller = worker, Porter = worker } }
	customer = { shop = shop, active = true, root = { Position = Vector3.new(0, 0, 0) }, record = record }
	failSave, beforeTransform, onWalk, manualNear, walkCount = false, nil, nil, false, 0
	walkedPositions, groundChecks, straightChecks, failWalkAt = {}, {}, {}, nil
	visualCount, destroyedVisuals, destroyedGrips = 0, 0, 0
	teleports = {}
end
-- The pickup and freezer stops as root positions of a porter set down there.
local function setDownAtPickup(index)
	local spot = teleports[index or 1]
	return spot ~= nil and spot.X == 0 and spot.Z == -38 and spot.Y >= 3.3 + 3
end
local function setDownAtFreezer(index)
	local spot = teleports[index or 1]
	return spot ~= nil and spot.X == -14.8 and spot.Z == 50 and spot.Y >= 6.06
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
check(walkCount == 14 and worker.fish == nil and not worker.busy, "Trip cleans its visual copy and lock")
check(#teleports == 0, "A walkable route never teleports the porter")
for index = 1, walkCount do
	check(groundChecks[index] == true, "Every unloading leg requires supported ground")
end
check(
	walkedPositions[1].X == -17 and walkedPositions[1].Z == -2 and walkedPositions[1].Y == 3.3,
	"Collection starts down the dock without a front-door detour"
)
check(
	walkedPositions[9].X == -17 and walkedPositions[9].Z == 13 and walkedPositions[14].X == -14.8
		and walkedPositions[14].Z == 50,
	"Return goes from the dock landing through the house to the freezer"
)
for index = 2, 11 do
	check(straightChecks[index] == true, "Dock legs follow centerlines without navmesh detours")
end
check(
	not straightChecks[1] and not straightChecks[12] and not straightChecks[14],
	"Quay, room and freezer routes retain normal pathfinding"
)
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
	walkedPositions[1].Z == -2 and walkedPositions[2].Z == -24 and walkedPositions[4].Z == -38,
	"Porter already on the ramp continues toward the pickup instead of returning to the quay"
)
reset()
worker.root.Position = Vector3.new(6, 6.3, -38)
runPorter(shop, worker, owner)
check(
	walkedPositions[1].X == 0 and walkedPositions[1].Z == -38 and #profile.Angler.Freezer == 2,
	"Pickup retry on the crosswalk goes straight to the fish without a quay detour"
)
check(#profile.Angler.Freezer == 2, "Crosswalk retry completes the delivery")
reset()
worker.root.Position = Vector3.new(6, 6.3, -36.2)
runPorter(shop, worker, owner)
check(
	walkedPositions[1].X == 0 and walkedPositions[1].Z == -38 and #profile.Angler.Freezer == 2,
	"Porter on the crosswalk's outer strip recenters before heading to pickup"
)
reset()
worker.root.Position = Vector3.new(-17, 6.3, -24)
runPorter(shop, worker, owner)
check(
	walkedPositions[1].X == -17 and walkedPositions[1].Z == -38 and walkedPositions[2].X == 0,
	"Porter already on the left pier approaches the pickup from that side without overshooting to the right pier"
)
check(#profile.Angler.Freezer == 2, "Left-pier pickup completes the delivery")
for _, side in { -1, 1 } do
	reset()
	moorPier, moorPickup = Vector3.new(side * 17, 3.2, -24), Vector3.new(side * 20, 3.2, -24)
	runPorter(shop, worker, owner)
	check(#profile.Angler.Freezer == 2, "Moored boat can be unloaded from either pier")
	check(
		walkedPositions[1].X == side * 17 and walkedPositions[5].X == side * 17,
		"Company porter uses the landing on the boat's dock side"
	)
	check(walkedPositions[2] == moorPier, "Company pickup stays at pier center despite legacy edge attributes")
end
reset()
failWalkAt = 3
runPorter(shop, worker, owner)
check(
	#profile.Angler.Freezer == 2 and #profile.Angler.Holds.Rowboat == 1 and walkCount == 14 and #teleports == 0,
	"A failed pickup leg retries from where the porter stands and still delivers"
)
check(
	walkedPositions[4].X == 0 and walkedPositions[4].Z == -38 and walkedPositions[5].X == -17,
	"Pickup retry from the pier heads straight for the fish instead of the quay"
)
check(worker.active and shop.staff.Porter == worker, "Blocked route on the deck keeps the existing porter")
reset()
onWalk = function()
	if walkCount == 2 then
		clock += PORTER_TELEPORT_SECONDS
	end
end
runPorter(shop, worker, owner)
check(
	setDownAtPickup() and #teleports == 1 and walkCount == 12,
	"A porter that cannot reach the boat within the time limit is set down at the pickup"
)
check(
	walkedPositions[3].X == -17 and walkedPositions[3].Z == -38,
	"After teleporting to the boat the porter walks the normal route back"
)
check(
	#profile.Angler.Freezer == 2 and #profile.Angler.Holds.Rowboat == 1 and not worker.busy,
	"Teleporting to the boat still completes the delivery"
)
reset()
onWalk = function()
	if walkCount == 6 then
		clock += PORTER_TELEPORT_SECONDS
	end
end
runPorter(shop, worker, owner)
check(
	setDownAtFreezer() and #teleports == 1 and walkCount == 6,
	"A porter that cannot reach the freezer within the time limit is set down there"
)
check(
	#profile.Angler.Freezer == 2 and #profile.Angler.Holds.Rowboat == 1 and destroyedVisuals == 1,
	"Teleporting to the freezer delivers the carried load exactly once"
)
reset()
-- Four pickup walks and ten delivery walks: each leg stays under the limit
-- while the whole trip does not.
local tripStart = clock
onWalk = function()
	clock += 2.5
end
runPorter(shop, worker, owner)
check(
	clock - tripStart > PORTER_TELEPORT_SECONDS and #teleports == 0 and #profile.Angler.Freezer == 2,
	"Each leg gets its own time limit"
)
reset()
failWalkAt = 5
runPorter(shop, worker, owner)
check(
	#profile.Angler.Freezer == 2 and #profile.Angler.Holds.Rowboat == 1 and walkCount == 14,
	"A transient return failure retries the same leg and completes delivery"
)
check(
	walkedPositions[4].Z == -38 and walkedPositions[6].Z == -24 and visualCount == 1 and destroyedVisuals == 1,
	"Return retry retains one carried visual instead of restarting the pickup"
)
reset()
failWalkAt = "return"
local blockedSince = clock
runPorter(shop, worker, owner)
check(
	setDownAtFreezer() and clock - blockedSince >= PORTER_TELEPORT_SECONDS and walkCount > 7,
	"Permanently blocked return keeps retrying until the time limit, then teleports to the freezer"
)
check(
	not worker.busy and #profile.Angler.Holds.Rowboat == 1 and #profile.Angler.Freezer == 2 and destroyedVisuals == 1,
	"Teleporting past a blocked return delivers the cargo once"
)
reset()
failWalkAt = 5
onWalk = function()
	if walkCount == 5 then
		activeBoat = nil
	end
end
runPorter(shop, worker, owner)
check(
	walkCount == 5 and not worker.busy and #profile.Angler.Holds.Rowboat == 2 and destroyedVisuals == 1,
	"Boat departure during a failed delivery cancels retries and preserves cargo"
)
check(#teleports == 0, "A cancelled delivery never teleports the porter")
reset()
failWalkAt = 1
onWalk = function()
	worker.root.Position = Vector3.new(20, 4, -12)
end
runPorter(shop, worker, owner)
check(
	setDownAtPickup() and #teleports == 1 and walkCount == 11,
	"Porter stranded below the deck is set down at the pickup without waiting out the time limit"
)
check(
	worker.active and shop.staff.Porter == worker and not worker.busy,
	"A stranded porter keeps working instead of being replaced"
)
check(
	#profile.Angler.Freezer == 2 and #profile.Angler.Holds.Rowboat == 1,
	"Stranded porter still completes the delivery"
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
	setDownAtFreezer() and #teleports == 1 and walkCount == 5 and worker.active,
	"Falling on the return trip sets the porter down at the freezer"
)
check(
	worker.fish == nil and destroyedVisuals == 1 and #profile.Angler.Freezer == 2 and #profile.Angler.Holds.Rowboat == 1,
	"Falling on the return trip delivers the carried load without losing or duplicating cargo"
)
reset()
failWalkAt = 1
onWalk = function()
	worker.root.Position = Vector3.new(20, 4, -12)
	currentOwner = {}
end
runPorter(shop, worker, owner)
check(
	worker.active and shop.staff.Porter == worker and #teleports == 0,
	"Owner changes cancel unloading without teleporting or retiring another owner's staff"
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
	#profile.Angler.Storage == 1 and #profile.Angler.Holds.Rowboat == 1 and walkCount == 14,
	"Full freezer sends cargo to a storage rack"
)
reset()
profile.Angler.Freezer = {}
profile.Angler.Storage = { record }
profile.Angler.Holds.Rowboat = { { PartId = "Oar", X = 1, Y = 1, R = 0 } }
profile.Angler.Furniture = { { ItemId = "StorageRack", X = 10, Z = -8, R = 0 } }
runPorter(shop, worker, owner)
check(
	#profile.Angler.Freezer == 1 and #profile.Angler.Storage == 0 and walkCount == 11,
	"Porter restocks the freezer from a rack"
)
reset()
profile.Angler.Freezer = {}
profile.Angler.Storage = { record }
profile.Angler.Holds.Rowboat = { { PartId = "Oar", X = 1, Y = 1, R = 0 } }
profile.Angler.Furniture = { { ItemId = "StorageRack", X = 10, Z = -8, R = 0 } }
worker.root.Position = Vector3.new(10, 9.06, 38.4)
runPorter(shop, worker, owner)
check(
	#profile.Angler.Freezer == 1 and #profile.Angler.Storage == 0 and walkCount == 6 and #teleports == 0,
	"Restocking from the rack walks straight into the house instead of back to the quay"
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
reset()
profile.Angler.Freezer = {}
profile.Angler.Storage = { record }
profile.Angler.Holds.Rowboat = { { PartId = "Oar", X = 1, Y = 1, R = 0 } }
profile.Angler.Furniture = { { ItemId = "StorageRack", X = 10, Z = -8, R = 0 } }
onWalk = function()
	if walkCount == 6 then
		clock += PORTER_TELEPORT_SECONDS
	end
end
runPorter(shop, worker, owner)
check(
	setDownAtFreezer() and #teleports == 1 and walkCount == 6,
	"A restocking porter that cannot reach the freezer in time is set down there"
)
check(
	#profile.Angler.Freezer == 1 and #profile.Angler.Storage == 0,
	"Teleporting while restocking still moves the fish into the freezer"
)

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
	#profile.Angler.Freezer == 4 and #profile.Angler.Holds.Rowboat == 4 and walkCount == 14,
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
for index = 1, 11 do
	profile.Angler.Storage[index] = record
end
runPorter(shop, worker, owner)
check(
	#profile.Angler.Storage == 12 and #profile.Angler.Holds.Rowboat == 7,
	"A load stops at the physical rack's remaining space"
)
batchSetup()
profile.Angler.Holds.Rowboat = {}
profile.Angler.Storage = { record, record, record, record, record }
profile.Angler.Furniture = { { ItemId = "StorageRack", X = 10, Z = -8, R = 0 } }
runPorter(shop, worker, owner)
check(
	#profile.Angler.Freezer == 4 and #profile.Angler.Storage == 1 and walkCount == 11,
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
