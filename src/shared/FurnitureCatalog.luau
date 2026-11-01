-- Furniture sold at the plaza's furniture shop and the placement rules for a base
-- house, shared by the server (which validates every placement) and the build
-- mode preview. Pure: no Roblox services, so the saved-data tests run it directly.
--
-- Positions are house-local studs (the BaseHouse "HouseFrame": +Z is the street
-- front, the floor is y=0.16, the quay deck outside is y=0). The customer shop is
-- a separate building across the street, in the same frame (BaseGrid.SHOP_FRONT
-- to SHOP_BACK) and at the same floor height. An item at X, Z turns R quarter
-- turns about +Y; its own +Z is the side customers or the porter use.
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
	"PottedPlant",
	"FlowerPlanter",
	"WoodenBench",
	"FloorLamp",
	"BarrelDisplay",
	"CrateStack",
	"RopeBasket",
	"LifeRingStand",
	"AnchorDisplay",
	"FishingNetDisplay",
	"NauticalSign",
	"ShipWheelDisplay",
	"FishStatue",
	"Aquarium",
	"Rug",
	"CoatRack",
	"Bookcase",
	"WallShelf",
}
local DECORATION_ROOMS = { "Shop", "Storage", "Processing" }

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
	PottedPlant = {
		Name = "Potted plant",
		Price = 120,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 12,
		Description = "A leafy plant in a ceramic pot to brighten your base.",
		Width = 2,
		Depth = 2,
		Front = 0,
		Back = 0,
	},
	FlowerPlanter = {
		Name = "Flower planter",
		Price = 180,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 10,
		Description = "A wooden planter filled with colorful flowers.",
		Width = 3,
		Depth = 1.5,
		Front = 0,
		Back = 0,
	},
	WoodenBench = {
		Name = "Wooden bench",
		Price = 220,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 8,
		Description = "A simple wooden bench for a cozy corner.",
		Width = 4,
		Depth = 1.5,
		Front = 0,
		Back = 0,
	},
	FloorLamp = {
		Name = "Floor lamp",
		Price = 200,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 8,
		Description = "A warm lamp for a welcoming room.",
		Width = 1.5,
		Depth = 1.5,
		Front = 0,
		Back = 0,
	},
	BarrelDisplay = {
		Name = "Decorative barrel",
		Price = 100,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 12,
		Description = "A weathered barrel with a seaside feel.",
		Width = 2.5,
		Depth = 2.5,
		Front = 0,
		Back = 0,
	},
	CrateStack = {
		Name = "Crate stack",
		Price = 150,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 8,
		Description = "A stack of wooden crates for a working harbor look.",
		Width = 3,
		Depth = 2,
		Front = 0,
		Back = 0,
	},
	RopeBasket = {
		Name = "Rope basket",
		Price = 90,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 10,
		Description = "A basket of coiled rope, ready for the next voyage.",
		Width = 2,
		Depth = 2,
		Front = 0,
		Back = 0,
	},
	LifeRingStand = {
		Name = "Life ring stand",
		Price = 160,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 6,
		Description = "A colorful life ring on its own display stand.",
		Width = 2,
		Depth = 1.5,
		Front = 0,
		Back = 0,
	},
	AnchorDisplay = {
		Name = "Anchor display",
		Price = 300,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 6,
		Description = "A sturdy anchor displayed as a nautical ornament.",
		Width = 2.5,
		Depth = 1.5,
		Front = 0,
		Back = 0,
	},
	FishingNetDisplay = {
		Name = "Fishing net display",
		Price = 180,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 6,
		Description = "A decorative fishing net displayed on a wooden frame.",
		Width = 3,
		Depth = 1.5,
		Front = 0,
		Back = 0,
	},
	NauticalSign = {
		Name = "Harbor sign",
		Price = 130,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 6,
		Description = "A freestanding sign inspired by the harbor.",
		Width = 3,
		Depth = 1.5,
		Front = 0,
		Back = 0,
	},
	ShipWheelDisplay = {
		Name = "Ship wheel display",
		Price = 350,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 6,
		Description = "A ship's wheel on a display stand.",
		Width = 2.5,
		Depth = 1.5,
		Front = 0,
		Back = 0,
	},
	FishStatue = {
		Name = "Fish statue",
		Price = 450,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 6,
		Description = "A fish sculpture to celebrate your favorite catch.",
		Width = 2.5,
		Depth = 2.5,
		Front = 0,
		Back = 0,
	},
	Aquarium = {
		Name = "Decorative aquarium",
		Price = 900,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 4,
		Description = "A decorative aquarium with an underwater scene.",
		Width = 4,
		Depth = 2,
		Front = 0,
		Back = 0,
	},
	Rug = {
		Name = "Woven rug",
		Price = 180,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 8,
		Description = "A woven rug that adds color underfoot.",
		Width = 4,
		Depth = 3,
		Front = 0,
		Back = 0,
	},
	CoatRack = {
		Name = "Coat rack",
		Price = 160,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 6,
		Description = "A freestanding coat rack for a welcoming entrance.",
		Width = 2,
		Depth = 2,
		Front = 0,
		Back = 0,
	},
	Bookcase = {
		Name = "Bookcase",
		Price = 300,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 6,
		Description = "A wooden bookcase stocked with colorful books.",
		Width = 3,
		Depth = 1.5,
		Front = 0,
		Back = 0,
	},
	WallShelf = {
		Name = "Display shelf",
		Price = 260,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 6,
		Description = "A freestanding shelf for a collection of seaside keepsakes.",
		Width = 3,
		Depth = 1.5,
		Front = 0,
		Back = 0,
	},
}
Furniture.RACK_CAPACITY = 12
Furniture.KITCHEN_STORAGE_CAPACITY = 8
-- Keep in step with BaseGrid.CELL_SIZE; saved positions are intentionally
-- not revalidated until an item is moved.
Furniture.GRID = 4.5

-- Inner floor of each furnishable room, as { x1, z1, x2, z2 }.
Furniture.Rooms = {
	-- The shop building across the street (walls at z=65.25 and 83.25).
	Shop = { -24.35, 65.6, 24.35, 82.9 },
	-- The kitchen and storage room share the house, side by side, front to back.
	Storage = { 2.55, -15.4, 24.35, 15.4 },
	Processing = { -24.35, -15.4, 1.95, 15.4 },
	Kitchen = { -24.35, -15.4, 1.95, 15.4 },
	-- The Restaurant's dining room extension behind the processing room.
	Dining = { -24.4, -33.4, -7.1, -16.1 },
	-- The open quay deck between the back of the house and the piers, right of
	-- the dining room extension.
	Yard = { -4.8, -33, 26.5, -15.8 },
}
Furniture.RoomNames = {
	Shop = "shop across the street",
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
	{ -4, 65.6, 4, 78.4 }, -- shop entrance aisle customers walk along
	{ 15.6, 69.5, 20.8, 78.5 }, -- shop's built-in freezer and its customer strip
	{ -21, 65.6, -11.5, 74.6 }, -- shop's built-in counter, its customers and the seller
	{ -4, 11.25, 1.95, 15.4 }, -- front doorway into the kitchen
	{ -24.4, 6.45, -6.45, 15.4 }, -- enclosed office in the kitchen's front corner
	{ 2.55, 11.25, 8, 15.4 }, -- front doorway into the storage room
	{ 2.55, -11.25, 6.5, -2.25 }, -- passage from the processing room
	{ -1, -11.25, 1.95, -2.25 }, -- processing room side of the storage passage
	{ -5.8, -15.4, 1.95, -11 }, -- rear door
	{ -22.6, -14.6, -18, -1 }, -- built-in prep benches and their cooks
	{ -24.4, -30.5, -19.5, -23.5 }, -- dining room entrance and approach
	{ -6, -33, 6.5, -15.8 }, -- rear steps, spawn point and the walk down to the water
	{ -4.8, -30.5, -2.5, -27.5 }, -- crab pot on the deck
	{ 4.5, -33, 8, -29 }, -- rope coil
	{ 12.5, -33, 21.5, -29 }, -- head of the right-hand gangway
	{ 16, -31, 26.5, -20 }, -- crates, barrels and crab pot by the quay edge
	{ 24.5, -33, 26.5, -30.5 }, -- lamp post
}

-- Decorations can be placed in several rooms on the same house floor.
function Furniture.allowedRooms(itemId: string): { string }
	local item = Furniture.Items[itemId]
	if not item then
		return {}
	end
	return item.Rooms or { item.Room }
end

function Furniture.roomNames(itemId: string): string
	local names = {}
	local shortNames = { Shop = "shop", Storage = "storage", Processing = "kitchen" }
	local item = Furniture.Items[itemId]
	for _, room in Furniture.allowedRooms(itemId) do
		table.insert(
			names,
			if item.Rooms then shortNames[room] or Furniture.RoomNames[room] else Furniture.RoomNames[room]
		)
	end
	if #names <= 1 then
		return names[1] or "house"
	elseif #names == 2 then
		return names[1] .. " or " .. names[2]
	end
	return table.concat(names, ", ", 1, #names - 1) .. " or " .. names[#names]
end

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

-- Solid sections of the new grid-aligned partitions. Used only to migrate
-- furniture that would otherwise be embedded in a moved wall. The enclosed
-- office also retires its floor area, so anything left inside is relocated.
local GRID_WALLS = {
	{ -24.75, 1.925, -13, 2.575 },
	{ -7, 1.925, 9, 2.575 },
	{ 15.5, 1.925, 24.75, 2.575 },
	{ 1.975, -15.75, 2.525, -11.25 },
	{ 1.975, -2.25, 2.525, 2.25 },
	{ -7.05, 6.45, -6.45, 15.75 }, -- office east wall and doorway
	{ -24.75, 6.45, -6.75, 7.05 }, -- office back wall
	{ -24.4, 7.05, -7.05, 15.4 }, -- enclosed office floor
	{ -7.05, -33.75, -6.45, -15.75 }, -- dining east wall moved inward
}

function Furniture.intersectsGridWall(entry): boolean
	local item = Furniture.Items[entry.ItemId]
	if not item then return false end
	local body = Furniture.footprint(entry.ItemId, entry.X, entry.Z, entry.R)
	for _, wall in GRID_WALLS do
		if overlaps(body, wall) then return true end
	end
	if item.Room == "Dining" and overlaps(body, { -24.4, -30.5, -19.5, -23.5 }) then
		return true
	end
	return false
end

local function onGrid(value: number): boolean
	return type(value) == "number"
		and value == value
		and math.abs(value) <= 96
		and math.abs(value / Furniture.GRID - math.round(value / Furniture.GRID)) < 1e-6
end

-- Checks one placement against the room rules and the other placed items
-- (`placed`, skipping index `skip`). Returns nil when it fits, or a player-facing reason.
local function check(placed, itemId: string, x: number, z: number, r: number, skip: number?, legacy: boolean?): string?
	local item = Furniture.Items[itemId]
	if not item then
		return "That isn't furniture."
	elseif not ((if legacy then type(x) == "number" and x == x and math.abs(x) <= 96
		and type(z) == "number" and z == z and math.abs(z) <= 96 else onGrid(x) and onGrid(z))
		and type(r) == "number" and r % 1 == 0 and r >= 0 and r <= 3) then
		return "That isn't a spot in your house."
	end
	local area = Furniture.footprint(itemId, x, z, r) :: { number }
	local fitsRoom = false
	for _, room in Furniture.allowedRooms(itemId) do
		if inside(area, Furniture.Rooms[room]) then
			fitsRoom = true
			break
		end
	end
	if not fitsRoom then
		return item.Name .. "s can only go in the " .. Furniture.roomNames(itemId) .. "."
	end
	for _, blocked in Furniture.Blocked do
		if overlaps(area, blocked) then
			return "Keep doorways, the aisle and the built-in fixtures clear."
		end
	end
	for index, other in placed do
		local otherArea = Furniture.footprint(other.ItemId, other.X, other.Z, other.R)
		if index ~= skip and otherArea and overlaps(area, otherArea) then
			return "That spot is taken by other furniture."
		end
	end
	return nil
end

function Furniture.check(placed, itemId: string, x: number, z: number, r: number, skip: number?): string?
	return check(placed, itemId, x, z, r, skip, false)
end

-- Historical saves used half-stud positions. This relaxed snapping is only for
-- relocating an existing item when the new walls would otherwise cover it.
function Furniture.checkRelocation(placed, itemId: string, x: number, z: number, r: number): string?
	return check(placed, itemId, x, z, r, nil, true)
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
