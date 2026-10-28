-- Furniture sold at the plaza's furniture shop and the placement rules for a base
-- house, shared by the server (which validates every placement) and the build
-- mode preview. Pure: no Roblox services, so the saved-data tests run it directly.
--
-- Positions are house-local studs (the BaseHouse "HouseFrame": +Z is the street
-- front, the floor is y=0.16, the quay deck outside is y=0). An item at X, Z turns
-- R quarter turns about +Y; its own +Z is the side customers or the porter use.
local Furniture = {}

Furniture.Order = {
	"Freezer",
	"Register",
	"StorageRack",
	"FoodCase",
	"GrillStation",
	"Smoker",
	"SushiBar",
	"KitchenStorage",
	"DiningTable",
	"WeatherRadar",
}
Furniture.Items = {
	Freezer = {
		Name = "Fish freezer",
		Price = 750,
		Room = "Shop",
		MaxPlaced = 4,
		Description = "Another chilled display for customers. Smaller fish leave room for more stock.",
		-- Body footprint, plus the strip customers stand on in front (+Z) and behind (-Z).
		Width = 9,
		Depth = 3.6,
		Front = 2.4,
		Back = 0,
	},
	Register = {
		Name = "Cash register counter",
		Price = 500,
		Room = "Shop",
		MaxPlaced = 3,
		Description = "A second till. Each counter serves one more customer at a time.",
		Width = 7.5,
		Depth = 3.05,
		-- Customers queue on the -Z side; the seller stands on +Z.
		Front = 2,
		Back = 2,
	},
	StorageRack = {
		Name = "Storage rack",
		Price = 300,
		Room = "Storage",
		MaxPlaced = 6,
		Description = "Shelving for overflow stock. Holds 12 fish when your freezers are full, so you can empty your boat.",
		Width = 6,
		Depth = 2,
		Front = 1.5,
		Back = 0,
	},
	-- Requires names the Paths stage that unlocks buying and placing the item.
	FoodCase = {
		Name = "Food display case",
		Price = 600,
		Room = "Shop",
		MaxPlaced = 3,
		Requires = "Supermarket",
		Description = "A chilled glass case. Shows 6 cooked dishes for shop customers to buy.",
		Width = 6,
		Depth = 2.6,
		Front = 2.4,
		Back = 0,
	},
	GrillStation = {
		Name = "Grill station",
		Price = 2000,
		Room = "Processing",
		MaxPlaced = 1,
		Requires = "Supermarket",
		Description = "Cooks grilled fish and fish skewers from Uncommon fish and rarer.",
		Width = 6,
		Depth = 2.4,
		Front = 2,
		Back = 0,
	},
	Smoker = {
		Name = "Smokehouse",
		Price = 4000,
		Room = "Processing",
		MaxPlaced = 1,
		Requires = "Supermarket",
		Description = "Slow-smokes Rare fish and rarer into smoked fish.",
		Width = 6,
		Depth = 2.4,
		Front = 2,
		Back = 0,
	},
	SushiBar = {
		Name = "Sushi bar",
		Price = 7500,
		Room = "Processing",
		MaxPlaced = 1,
		Requires = "Supermarket",
		Description = "Turns Epic and Legendary fish into sushi platters and golden sashimi.",
		Width = 6,
		Depth = 2.4,
		Front = 2,
		Back = 0,
	},
	KitchenStorage = {
		Name = "Kitchen storage",
		Price = 750,
		Room = "Processing",
		MaxPlaced = 1,
		Requires = "Supermarket",
		Description = "A chilled prep table. Select up to 8 fish by rarity for your porter to bring here for cooking.",
		Width = 6,
		Depth = 2.4,
		Front = 2,
		Back = 0,
	},
	DiningTable = {
		Name = "Dining table",
		Price = 400,
		Room = "Dining",
		MaxPlaced = 8,
		Requires = "Restaurant",
		Description = "A table for two in your dining room. Each seat welcomes one diner.",
		Width = 4,
		Depth = 2.6,
		-- A chair stands on each long side.
		Front = 1.6,
		Back = 1.6,
	},
	WeatherRadar = {
		Name = "Weather radar",
		Price = 1500,
		Room = "Yard",
		MaxPlaced = 1,
		Description = "A round radar table for your yard. Shows the rain, storm cells and tornadoes around your base, live.",
		Width = 4,
		Depth = 4,
		-- The reader stands on the side the screen tilts toward.
		Front = 1.5,
		Back = 0,
	},
}
Furniture.RACK_CAPACITY = 12
Furniture.KITCHEN_STORAGE_CAPACITY = 8
Furniture.GRID = 0.5

-- Inner floor of each furnishable room, as { x1, z1, x2, z2 }.
Furniture.Rooms = {
	Shop = { -22.6, 1.35, 22.6, 14.6 },
	Storage = { 3.35, -14.6, 22.6, 0.65 },
	Processing = { -22.6, -14.6, 2.65, 0.65 },
	Kitchen = { -22.6, -14.6, 2.65, 0.65 },
	-- The Restaurant's dining room extension behind the processing room.
	Dining = { -22.4, -29.4, -6.1, -15.35 },
	-- The open quay deck between the back of the house and the piers, right of
	-- the dining room extension.
	Yard = { -4.8, -33, 26.5, -15.8 },
}
Furniture.RoomNames = {
	Shop = "front shop room",
	Storage = "storage room",
	Processing = "kitchen",
	Kitchen = "kitchen",
	Dining = "dining room",
	Yard = "yard behind your house",
}
-- Floor height of a room where it isn't the house floor.
Furniture.FloorHeights = {
	Yard = 0,
}
-- Walkways, doorways and the built-in fixtures stay clear.
Furniture.Blocked = {
	{ -4, 1.35, 4, 14.6 }, -- entrance aisle customers walk along
	{ -13.5, 1.35, -6.5, 4 }, -- doorway to the processing room
	{ 8.5, -3, 15.5, 4 }, -- doorway between the shop and the storage room
	{ 3.35, -10.5, 6.5, -3.5 }, -- passage from the processing room
	{ -20.8, 2.5, -15.6, 11.5 }, -- built-in freezer and its customer strip
	{ 11.5, 6.4, 21, 14.6 }, -- built-in counter, its customers and the seller
	{ -13.5, -3, -6.5, 1.35 }, -- processing room side of the shop doorway
	{ -0.5, -10.5, 2.65, -3.5 }, -- processing room side of the storage passage
	{ -3.5, -14.6, 2.65, -11 }, -- rear door
	{ -22.6, -14.6, -18, -1 }, -- built-in prep benches and their cooks
	{ -16, -29.4, -10, -25.5 }, -- dining room entrance
	{ -3.5, -33, 6.5, -15.8 }, -- rear steps, spawn point and the walk down to the water
	{ -4.8, -30.5, -2.5, -27.5 }, -- crab pot on the deck
	{ 4.5, -33, 8, -29 }, -- rope coil
	{ 12.5, -33, 21.5, -29 }, -- head of the right-hand gangway
	{ 16, -31, 26.5, -20 }, -- crates, barrels and crab pot by the quay edge
	{ 24.5, -33, 26.5, -30.5 }, -- lamp post
}

-- The rectangle { x1, z1, x2, z2 } the item covers, including its access strips.
function Furniture.footprint(itemId: string, x: number, z: number, r: number): { number }?
	local item = Furniture.Items[itemId]
	if not item then
		return nil
	end
	local halfW = item.Width / 2
	local low, high = -item.Depth / 2 - item.Back, item.Depth / 2 + item.Front
	-- Quarter turns of the local rectangle (x across, z from low to high).
	local corners = {}
	for _, c in { { -halfW, low }, { halfW, high } } do
		local cx, cz = c[1], c[2]
		for _ = 1, r % 4 do
			-- Clockwise seen from above matches CFrame.Angles(0, r * pi / 2, 0).
			cx, cz = cz, -cx
		end
		table.insert(corners, { cx, cz })
	end
	return {
		x + math.min(corners[1][1], corners[2][1]),
		z + math.min(corners[1][2], corners[2][2]),
		x + math.max(corners[1][1], corners[2][1]),
		z + math.max(corners[1][2], corners[2][2]),
	}
end

local function overlaps(a: { number }, b: { number }): boolean
	return a[1] < b[3] - 1e-3 and a[3] > b[1] + 1e-3 and a[2] < b[4] - 1e-3 and a[4] > b[2] + 1e-3
end

local function inside(a: { number }, room: { number }): boolean
	return a[1] >= room[1] - 1e-3 and a[3] <= room[3] + 1e-3 and a[2] >= room[2] - 1e-3 and a[4] <= room[4] + 1e-3
end

local function onGrid(value: number): boolean
	return type(value) == "number"
		and value == value
		and math.abs(value) <= 64
		and math.abs(value / Furniture.GRID - math.round(value / Furniture.GRID)) < 1e-6
end

-- Checks one placement against the room rules and the other placed items
-- (`placed`, skipping index `skip`). Returns nil when it fits, or a player-facing reason.
function Furniture.check(placed, itemId: string, x: number, z: number, r: number, skip: number?): string?
	local item = Furniture.Items[itemId]
	if not item then
		return "That isn't furniture."
	elseif not (onGrid(x) and onGrid(z) and type(r) == "number" and r % 1 == 0 and r >= 0 and r <= 3) then
		return "That isn't a spot in your house."
	end
	local area = Furniture.footprint(itemId, x, z, r) :: { number }
	if not inside(area, Furniture.Rooms[item.Room]) then
		return item.Name .. "s can only go in the " .. Furniture.RoomNames[item.Room] .. "."
	end
	for _, blocked in Furniture.Blocked do
		if overlaps(area, blocked) then
			return "Keep doorways, the aisle and the built-in fixtures clear."
		end
	end
	for index, other in placed do
		if
			index ~= skip and overlaps(area, Furniture.footprint(other.ItemId, other.X, other.Z, other.R) :: { number })
		then
			return "That spot is taken by other furniture."
		end
	end
	return nil
end

-- nil when the item can be bought and placed on this profile's path, otherwise why not.
-- `unlocked` is a Paths stage id → true map.
function Furniture.locked(itemId: string, unlocked): string?
	local item = Furniture.Items[itemId]
	if item and item.Requires and not (unlocked and unlocked[item.Requires]) then
		return item.Name .. "s unlock with the " .. item.Requires .. " path."
	end
	return nil
end

function Furniture.count(placed, itemId: string): number
	local count = 0
	for _, entry in placed do
		if entry.ItemId == itemId then
			count += 1
		end
	end
	return count
end

-- Floor height (house-local y) an item stands on.
function Furniture.floor(itemId: string?): number
	local item = itemId and Furniture.Items[itemId]
	return item and Furniture.FloorHeights[item.Room] or 0.16
end

-- World frame on the floor of the house (or the yard deck) for a placed entry.
function Furniture.frame(houseFrame, entry)
	return houseFrame
		* CFrame.new(entry.X, Furniture.floor(entry.ItemId), entry.Z)
		* CFrame.Angles(0, entry.R * math.pi / 2, 0)
end

return Furniture
