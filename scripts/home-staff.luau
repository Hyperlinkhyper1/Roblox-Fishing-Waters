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
	return setmetatable({ X = x, Y = y, Z = z, Magnitude = math.sqrt(x*x + y*y + z*z) }, vector)
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
function cframe.__eq(a, b)
	return a.Position.X == b.Position.X and a.Position.Y == b.Position.Y and a.Position.Z == b.Position.Z
end
-- Frames here are pure translations.
cframe.__index = { PointToObjectSpace = function(a, point) return point - a.Position end }
local function typeof(value) return if type(value) == "table" and value.Kind then value.Kind else type(value) end
local owner = { UserId = 42 }
local currentOwner = owner
local marker = { Position = Vector3.new(0, 0, 0), IsA = function() return true end }
-- The real dock frame sits 43 studs behind the house frame.
local base = {
	FindFirstChild = function() return marker end,
	GetAttribute = function(_, name) return if name == "BoatDockFrame" then CFrame.new(0, 0, -43) else CFrame.new() end,
}
local function ownerOf() return currentOwner end
local boatOwner, boatId = 42, "Rowboat"
local boat = {
	PrimaryPart = { Position = Vector3.new(0, 0, 0), AssemblyLinearVelocity = Vector3.new(0, 0, 0) },
	GetAttribute = function() return boatOwner end,
}
local activeBoat = boat
local companyBoat = { Parent = true, GetAttribute = function() return nil end }
local mooredCompany
local function companyDock()
	if mooredCompany then return "CompanyBoat", companyBoat end
	return nil, nil
end
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
local FishFreezer = { DEPTH = 4.5, frame = function() return CFrame.new() end }
local StorageRack = { DEPTH = 2 }
local Kitchen = { DEPTH = 2.4 }
local BaseGrid = { SHOP_FRONT = 65.25 }
local NpcNavigation = { clearance = function() return 2 end }
local StaffCatalog = { porterStats = function() return 16, 1 end }
local PORTER_TELEPORT_SECONDS = 30
local function fixtureFrames(_, current, itemId)
	local frames = {}
	for _, entry in current.Angler.Furniture do
		if entry.ItemId == itemId then table.insert(frames, CFrame.new(entry.X, 0, entry.Z)) end
	end
	return frames
end
local Catalog = { Fish = { Trout = { Rarity = "Rare" }, Anchovy = { Rarity = "Common" } } }
local furnitureRefreshes = 0
local FurnitureService = { refreshPlayer = function() furnitureRefreshes += 1 end }
local manualNear = false
local function near() return manualNear end
local function notify() end
local function refreshDisplay() end
local function refreshShelves() end
local function leave(customer) customer.leaving = true end
local function describeFish() return "Trout" end
local function bubble() end
local function fishModel() return { Destroy = function() end } end
local function carry() end
local walkCount, onWalk = 0, nil
local function walk(worker, position, allowed)
	if allowed and not allowed() then return false end
	walkCount += 1
	worker.root.Position = position
	if onWalk then onWalk() end
	return worker.active and (not allowed or allowed())
end
local task = { spawn = function(callback) callback() end }
local function warn() end
-- ROUTE_SOURCE --
-- SELL_SOURCE --
-- PORTER_SOURCE --

local species = { Trout = { AverageKg = 2, RarityDenominator = 10 } }
local record = AnglerData.recordCatch(nil, "Trout", "Normal", 2, 20, 100, species, { Normal = {} }).Hand
local function fillFreezer(data)
	while AnglerData.canFreeze(data, record) do table.insert(data.Freezer, record) end
	return #data.Freezer
end
local worker, shop, customer
local function reset()
	currentOwner, boatOwner, activeBoat, boatId = owner, 42, boat, "Rowboat"
	mooredCompany = false
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
	customer = { shop = shop, active = true, root = { Position = Vector3.new(0, 0, 0) }, items = { { record = record } } }
	failSave, beforeTransform, onWalk, manualNear, walkCount = false, nil, nil, false, 0
	furnitureRefreshes = 0
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
mooredCompany = true
profile.Angler.Holds.CompanyBoat = {}
check(dockedBoat(shop, owner) == "Rowboat", "An empty company boat does not hide the player's docked fish")
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 2 and #profile.Angler.Holds.Rowboat == 1, "Porter unloads the player boat while the company boat is empty")
reset()
mooredCompany = true
profile.Angler.Holds.CompanyBoat = { { Fish = record, X = 1, Y = 1, R = 0 } }
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 2 and #profile.Angler.Holds.CompanyBoat == 0 and #profile.Angler.Holds.Rowboat == 2, "Porter still prioritizes fish in the company boat")
reset()
mooredCompany = true
profile.Angler.Holds.CompanyBoat = {}
onWalk = function()
	if walkCount == 1 then profile.Angler.Holds.CompanyBoat = { { Fish = record, X = 1, Y = 1, R = 0 } } end
end
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 2 and #profile.Angler.Holds.Rowboat == 1 and #profile.Angler.Holds.CompanyBoat == 1, "New company cargo does not cancel a trip already collecting the player boat")
reset()
mooredCompany = true
profile.Angler.Holds.CompanyBoat = { { Fish = record, X = 1, Y = 1, R = 0 } }
onWalk = function() mooredCompany = false end
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 1 and #profile.Angler.Holds.CompanyBoat == 1, "A company boat leaving during its trip preserves cargo")
reset()
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 2 and #profile.Angler.Holds.Rowboat == 1, "Porter walks a full route and delivers")
check(walkCount == 13 and worker.fish == nil and not worker.busy, "Trip cleans its visual copy and lock")
reset()
onWalk = function() boat.PrimaryPart.Position = Vector3.new(100, 0, 0) end
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 1 and #profile.Angler.Holds.Rowboat == 2, "Boat departing during trip preserves cargo")
reset()
onWalk = function() if walkCount == 5 then profile.Angler.Holds.Rowboat = {} end end
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 1 and worker.fish == nil, "Player taking fish during walk cannot duplicate stock")
reset()
local fullCount
onWalk = function()
	if walkCount == 5 then
		fullCount = fillFreezer(profile.Angler)
	end
end
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == fullCount and #profile.Angler.Holds.Rowboat == 2, "Freezer filling during trip preserves cargo")
reset()
beforeTransform = function() currentOwner = {} end
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 1 and #profile.Angler.Holds.Rowboat == 2, "Porter transaction rechecks base ownership")
reset()
failSave = true
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 1 and #profile.Angler.Holds.Rowboat == 2 and not worker.busy, "Failed porter save preserves fish and releases trip lock")
reset()
fillFreezer(profile.Angler)
runPorter(shop, worker, owner)
check(#profile.Angler.Storage == 0 and #profile.Angler.Holds.Rowboat == 2, "Full freezer without racks keeps cargo aboard")
reset()
fillFreezer(profile.Angler)
profile.Angler.Furniture = { { ItemId = "StorageRack", X = 10, Z = -8, R = 0 } }
runPorter(shop, worker, owner)
check(#profile.Angler.Storage == 1 and #profile.Angler.Holds.Rowboat == 1 and walkCount == 13, "Full freezer sends cargo to a storage rack")
reset()
fillFreezer(profile.Angler)
mooredCompany = true
profile.Angler.Holds.CompanyBoat = {}
profile.Angler.Furniture = { { ItemId = "StorageRack", X = 10, Z = -8, R = 0 } }
runPorter(shop, worker, owner)
check(#profile.Angler.Storage == 1 and #profile.Angler.Holds.Rowboat == 1,
	"An empty company boat does not hide cargo eligible for a storage rack")
reset()
profile.Angler.Freezer = {}
profile.Angler.Storage = { record }
profile.Angler.Holds.Rowboat = { { PartId = "Oar", X = 1, Y = 1, R = 0 } }
profile.Angler.Furniture = { { ItemId = "StorageRack", X = 10, Z = -8, R = 0 } }
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 1 and #profile.Angler.Storage == 0 and walkCount == 2, "Porter restocks the freezer from a rack")
reset()
profile.Angler.Freezer = {}
profile.Angler.Storage = { record }
profile.Angler.Holds.Rowboat = { { PartId = "Oar", X = 1, Y = 1, R = 0 } }
profile.Angler.Furniture = { { ItemId = "StorageRack", X = 10, Z = -8, R = 0 } }
onWalk = function() if walkCount == 1 then profile.Angler.Storage = {} end end
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 0 and worker.fish == nil, "Player taking stored fish mid-restock cannot duplicate it")
-- Simulate a freezer with room for the smaller fish but not the first one.
-- The real transaction still uses the packing check for the fish that fits.
local canFreeze = AnglerData.canFreeze
local oversized = table.clone(record)
oversized.Kg = record.Kg + 1
AnglerData.canFreeze = function(data, fish)
	if fish and fish.Kg == oversized.Kg then return false end
	return canFreeze(data, fish)
end
reset()
profile.Angler.Holds.Rowboat = { { Fish = oversized, X = 1, Y = 1, R = 0 }, { Fish = record, X = 2, Y = 1, R = 0 } }
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 2 and #profile.Angler.Holds.Rowboat == 1
	and profile.Angler.Holds.Rowboat[1].Fish.Kg == oversized.Kg,
	"A boat fish that does not fit does not block a later fitting catch")
reset()
mooredCompany = true
profile.Angler.Holds.CompanyBoat = { { Fish = oversized, X = 1, Y = 1, R = 0 } }
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 2 and #profile.Angler.Holds.Rowboat == 1
	and #profile.Angler.Holds.CompanyBoat == 1,
	"Unfitting company cargo does not hide a fitting fish on the player boat")
reset()
mooredCompany = true
profile.Angler.Holds.CompanyBoat = { { Fish = oversized, X = 1, Y = 1, R = 0 } }
onWalk = function() boat.PrimaryPart.Position = Vector3.new(100, 0, 0) end
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 1 and #profile.Angler.Holds.Rowboat == 2
	and #profile.Angler.Holds.CompanyBoat == 1,
	"A selected player boat leaving preserves its fish even when a company boat remains")
reset()
profile.Angler.Holds.Rowboat = { { Fish = oversized, X = 1, Y = 1, R = 0 } }
profile.Angler.Storage = { oversized, record }
profile.Angler.Furniture = { { ItemId = "StorageRack", X = 10, Z = -8, R = 0 } }
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 2 and #profile.Angler.Storage == 1
	and profile.Angler.Storage[1].Kg == oversized.Kg and #profile.Angler.Holds.Rowboat == 1,
	"A fitting shelf fish can reach the freezer when earlier cargo and shelf fish do not fit")
AnglerData.canFreeze = canFreeze
reset()
profile.Angler.Furniture = { { ItemId = "KitchenStorage", X = -10, Z = -8, R = 0 } }
profile.Angler.KitchenStorage.Targets.Rare = 1
local common = table.clone(record)
common.FishId = "Anchovy"
mooredCompany = true
profile.Angler.Holds.CompanyBoat = { { Fish = common, X = 1, Y = 1, R = 0 } }
runPorter(shop, worker, owner)
check(#profile.Angler.KitchenStorage.Fish == 1 and #profile.Angler.Holds.CompanyBoat == 1
	and #profile.Angler.Holds.Rowboat == 1,
	"Kitchen selection checks the player boat when company fish do not match")
reset()
profile.Angler.Furniture = { { ItemId = "KitchenStorage", X = -10, Z = -8, R = 0 } }
profile.Angler.KitchenStorage.Targets.Rare = 1
table.insert(profile.Angler.Holds.Rowboat, 2, { Fish = common, X = 3, Y = 1, R = 0 })
runPorter(shop, worker, owner)
check(#profile.Angler.KitchenStorage.Fish == 1 and profile.Angler.KitchenStorage.Fish[1].FishId == "Trout", "Porter selects a needed rarity beyond the first fish in cargo")
check(#profile.Angler.Freezer == 1 and #profile.Angler.Holds.Rowboat == 2 and furnitureRefreshes == 1, "Kitchen delivery preserves other cargo and refreshes the table")
runPorter(shop, worker, owner)
check(#profile.Angler.Freezer == 2 and #profile.Angler.KitchenStorage.Fish == 1, "Fish go to the freezer once the kitchen target is met")
reset()
profile.Angler.Furniture = { { ItemId = "KitchenStorage", X = -10, Z = -8, R = 0 }, { ItemId = "StorageRack", X = 10, Z = -8, R = 0 } }
profile.Angler.KitchenStorage.Targets.Rare = 1
profile.Angler.Storage = { common, record }
profile.Angler.Holds.Rowboat = {}
runPorter(shop, worker, owner)
check(#profile.Angler.KitchenStorage.Fish == 1 and #profile.Angler.Storage == 1 and profile.Angler.Storage[1].FishId == "Anchovy", "Porter finds matching fish on racks")
reset()
profile.Angler.Furniture = { { ItemId = "KitchenStorage", X = -10, Z = -8, R = 0 } }
profile.Angler.KitchenStorage.Targets.Rare = 1
beforeTransform = function(current) current.Angler.KitchenStorage.Targets.Rare = 0 end
runPorter(shop, worker, owner)
check(#profile.Angler.KitchenStorage.Fish == 0 and #profile.Angler.Holds.Rowboat == 2, "Changed targets preserve cargo during a trip")
reset()
profile.Angler.Furniture = { { ItemId = "KitchenStorage", X = -10, Z = -8, R = 0 } }
profile.Angler.KitchenStorage.Targets.Rare = 1
beforeTransform = function(current) current.Angler.Furniture = {} end
runPorter(shop, worker, owner)
check(#profile.Angler.KitchenStorage.Fish == 0 and #profile.Angler.Holds.Rowboat == 2, "Removed kitchen table preserves cargo during a trip")
print("Home staff: "
 .. checks .. " production seller, dock and porter transaction checks passed (world/store doubles).")
