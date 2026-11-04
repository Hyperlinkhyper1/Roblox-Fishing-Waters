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
-- Supplied with a company island (AnglerData.COMPANY_KIT) instead of sold.
Furniture.KitOrder = { "CompanyPrep", "CompanyDesk" }
-- Catalogue groups describe the existing inventory; they do not change purchase
-- rules, placement rooms, or ownership.
Furniture.Categories = {
	{ Id = "All", Name = "All" },
	{ Id = "Shop", Name = "Shop counters" },
	{ Id = "Kitchen", Name = "Kitchen" },
	{ Id = "Storage", Name = "Storage" },
	{ Id = "Seating", Name = "Tables & seating" },
	{ Id = "Lighting", Name = "Lighting" },
	{ Id = "Plants", Name = "Plants" },
	{ Id = "Nautical", Name = "Nautical" },
	{ Id = "Decor", Name = "Decorations" },
}
local CATEGORY_BY_ITEM = {
	Freezer = "Shop", Register = "Shop", FoodCase = "Shop",
	GrillStation = "Kitchen", Smoker = "Kitchen", SushiBar = "Kitchen", CompanyPrep = "Kitchen",
	StorageRack = "Storage", KitchenStorage = "Storage", Bookcase = "Storage", WallShelf = "Storage",
	DiningTable = "Seating", WoodenBench = "Seating", CompanyDesk = "Seating",
	FloorLamp = "Lighting", PottedPlant = "Plants", FlowerPlanter = "Plants",
	BarrelDisplay = "Nautical", CrateStack = "Nautical", RopeBasket = "Nautical", LifeRingStand = "Nautical",
	AnchorDisplay = "Nautical", FishingNetDisplay = "Nautical", NauticalSign = "Nautical", ShipWheelDisplay = "Nautical",
	WeatherRadar = "Decor", FishStatue = "Decor", Aquarium = "Decor", Rug = "Decor", CoatRack = "Decor",
}
function Furniture.category(itemId: string): string
	return CATEGORY_BY_ITEM[itemId] or "Decor"
end
function Furniture.matchesCategory(itemId: string, category: string): boolean
	return category == "All" or Furniture.category(itemId) == category
end
local DECORATION_ROOMS = { "Shop", "Storage", "Processing" }

Furniture.Items = {
	Freezer = {
		Name = "Fish freezer",
		Price = 375,
		Room = "Shop",
		MaxPlaced = 4,
		Description = "Another chilled display for customers. Smaller fish leave room for more stock.",
		-- Two cells along the wall; customers stand in the strip in front (+Z).
		Cells = { 2, 1 },
		Width = 9,
		Depth = 3.6,
		Front = 2,
		Back = 0,
	},
	Register = {
		Name = "Cash register counter",
		Price = 250,
		Room = "Shop",
		MaxPlaced = 3,
		Description = "A second till. Each counter serves one more customer at a time.",
		-- Customers queue in the -Z strip; the seller stands in the +Z one.
		Cells = { 2, 1 },
		Centered = true,
		Width = 8.2,
		Depth = 3.35,
		Front = 1.5,
		Back = 2,
	},
	StorageRack = {
		Name = "Storage rack",
		Price = 150,
		Room = "Storage",
		MaxPlaced = 6,
		Description = "Shelving for overflow stock. Holds 12 fish when your freezers are full, so you can empty your boat.",
		Cells = { 1, 1 },
		Width = 4.4,
		Depth = 2.2,
		Front = 0,
		Back = 0,
	},
	-- Requires names the Paths stage that unlocks buying and placing the item.
	FoodCase = {
		Name = "Food display case",
		Price = 300,
		Room = "Shop",
		MaxPlaced = 3,
		Requires = "Supermarket",
		Description = "A chilled glass case. Shows 6 cooked dishes for shop customers to buy.",
		Cells = { 2, 1 },
		Width = 9,
		Depth = 2.6,
		Front = 1,
		Back = 0,
	},
	GrillStation = {
		Name = "Grill station",
		Price = 1000,
		Room = "Processing",
		MaxPlaced = 1,
		Requires = "Supermarket",
		Description = "Cooks grilled fish and fish skewers from Uncommon fish and rarer.",
		-- The cook stands in the open front of the cells.
		Cells = { 2, 1 },
		Width = 9,
		Depth = 2.4,
		Front = 0,
		Back = 0,
	},
	Smoker = {
		Name = "Smokehouse",
		Price = 2000,
		Room = "Processing",
		MaxPlaced = 1,
		Requires = "Supermarket",
		Description = "Slow-smokes Rare fish and rarer into smoked fish.",
		Cells = { 2, 1 },
		Width = 9,
		Depth = 2.4,
		Front = 0,
		Back = 0,
	},
	SushiBar = {
		Name = "Sushi bar",
		Price = 3750,
		Room = "Processing",
		MaxPlaced = 1,
		Requires = "Supermarket",
		Description = "Turns Epic and Legendary fish into sushi platters and golden sashimi.",
		Cells = { 2, 1 },
		Width = 9,
		Depth = 2.4,
		Front = 0,
		Back = 0,
	},
	KitchenStorage = {
		Name = "Kitchen storage",
		Price = 375,
		Room = "Processing",
		MaxPlaced = 1,
		Requires = "Supermarket",
		Description = "A chilled prep table. Select up to 8 fish by rarity for your porter to bring here for cooking.",
		Cells = { 2, 1 },
		Width = 9,
		Depth = 2.4,
		Front = 0,
		Back = 0,
	},
	DiningTable = {
		Name = "Dining table",
		Price = 200,
		Room = "Dining",
		MaxPlaced = 8,
		Requires = "Restaurant",
		Description = "A table for two in your dining room. Each seat welcomes one diner.",
		-- The table with a chair at each end (local ±Z).
		Cells = { 1, 2 },
		Centered = true,
		Width = 4.2,
		Depth = 7.2,
		Front = 0,
		Back = 0,
	},
	WeatherRadar = {
		Name = "Weather radar",
		Price = 750,
		Room = "Yard",
		MaxPlaced = 1,
		Description = "A round radar table for your yard. Shows the rain, storm cells and tornadoes around your base, live.",
		Cells = { 1, 1 },
		Centered = true,
		Width = 4.2,
		Depth = 4.2,
		Front = 0,
		Back = 0,
	},
	PottedPlant = {
		Name = "Potted plant",
		Price = 60,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 12,
		Description = "A leafy plant in a ceramic pot to brighten your base.",
		Cells = { 1, 1 },
		Centered = true,
		Width = 2.6,
		Depth = 2.6,
		Front = 0,
		Back = 0,
	},
	FlowerPlanter = {
		Name = "Flower planter",
		Price = 90,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 10,
		Description = "A wooden planter filled with colorful flowers.",
		Cells = { 1, 1 },
		Width = 4.2,
		Depth = 1.6,
		Front = 0,
		Back = 0,
	},
	WoodenBench = {
		Name = "Wooden bench",
		Price = 110,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 8,
		Description = "A simple wooden bench for a cozy corner.",
		Cells = { 1, 1 },
		Width = 4.2,
		Depth = 1.8,
		Front = 0,
		Back = 0,
	},
	FloorLamp = {
		Name = "Floor lamp",
		Price = 100,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 8,
		Description = "A warm lamp for a welcoming room.",
		Cells = { 1, 1 },
		Centered = true,
		Width = 1.6,
		Depth = 1.6,
		Front = 0,
		Back = 0,
	},
	BarrelDisplay = {
		Name = "Decorative barrel",
		Price = 50,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 12,
		Description = "A weathered barrel with a seaside feel.",
		Cells = { 1, 1 },
		Centered = true,
		Width = 2.6,
		Depth = 2.6,
		Front = 0,
		Back = 0,
	},
	CrateStack = {
		Name = "Crate stack",
		Price = 75,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 8,
		Description = "A stack of wooden crates for a working harbor look.",
		Cells = { 1, 1 },
		Centered = true,
		Width = 3.6,
		Depth = 3,
		Front = 0,
		Back = 0,
	},
	RopeBasket = {
		Name = "Rope basket",
		Price = 45,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 10,
		Description = "A basket of coiled rope, ready for the next voyage.",
		Cells = { 1, 1 },
		Centered = true,
		Width = 2.2,
		Depth = 2.2,
		Front = 0,
		Back = 0,
	},
	LifeRingStand = {
		Name = "Life ring stand",
		Price = 80,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 6,
		Description = "A colorful life ring on its own display stand.",
		Cells = { 1, 1 },
		Centered = true,
		Width = 2.2,
		Depth = 1.4,
		Front = 0,
		Back = 0,
	},
	AnchorDisplay = {
		Name = "Anchor display",
		Price = 150,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 6,
		Description = "A sturdy anchor displayed as a nautical ornament.",
		Cells = { 1, 1 },
		Centered = true,
		Width = 2.6,
		Depth = 1.4,
		Front = 0,
		Back = 0,
	},
	FishingNetDisplay = {
		Name = "Fishing net display",
		Price = 90,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 6,
		Description = "A decorative fishing net displayed on a wooden frame.",
		Cells = { 1, 1 },
		Width = 4.2,
		Depth = 1.2,
		Front = 0,
		Back = 0,
	},
	NauticalSign = {
		Name = "Harbor sign",
		Price = 65,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 6,
		Description = "A freestanding sign inspired by the harbor.",
		Cells = { 1, 1 },
		Centered = true,
		Width = 3.4,
		Depth = 1.2,
		Front = 0,
		Back = 0,
	},
	ShipWheelDisplay = {
		Name = "Ship wheel display",
		Price = 175,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 6,
		Description = "A ship's wheel on a display stand.",
		Cells = { 1, 1 },
		Centered = true,
		Width = 2.6,
		Depth = 1.3,
		Front = 0,
		Back = 0,
	},
	FishStatue = {
		Name = "Fish statue",
		Price = 225,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 6,
		Description = "A fish sculpture to celebrate your favorite catch.",
		Cells = { 1, 1 },
		Centered = true,
		Width = 2.4,
		Depth = 2.4,
		Front = 0,
		Back = 0,
	},
	Aquarium = {
		Name = "Decorative aquarium",
		Price = 450,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 4,
		Description = "A decorative aquarium with an underwater scene.",
		Cells = { 2, 1 },
		Width = 8.2,
		Depth = 2,
		Front = 0,
		Back = 0,
	},
	Rug = {
		Name = "Woven rug",
		Price = 90,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 8,
		Description = "A woven rug that adds color underfoot.",
		Cells = { 2, 1 },
		Centered = true,
		Width = 8.2,
		Depth = 4,
		Front = 0,
		Back = 0,
	},
	CoatRack = {
		Name = "Coat rack",
		Price = 80,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 6,
		Description = "A freestanding coat rack for a welcoming entrance.",
		Cells = { 1, 1 },
		Centered = true,
		Width = 1.8,
		Depth = 1.8,
		Front = 0,
		Back = 0,
	},
	Bookcase = {
		Name = "Bookcase",
		Price = 150,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 6,
		Description = "A wooden bookcase stocked with colorful books.",
		Cells = { 1, 1 },
		Width = 4.2,
		Depth = 1.4,
		Front = 0,
		Back = 0,
	},
	WallShelf = {
		Name = "Display shelf",
		Price = 130,
		Room = "Shop",
		Rooms = DECORATION_ROOMS,
		Decoration = true,
		MaxPlaced = 6,
		Description = "A freestanding shelf for a collection of seaside keepsakes.",
		Cells = { 1, 1 },
		Width = 4.2,
		Depth = 1.2,
		Front = 0,
		Back = 0,
	},
	-- Kit items go only on a company island's plot. Each placed prep bench takes
	-- the first free company bench key (Recipes.CompanyBuiltIn) as its saved Key.
	CompanyPrep = {
		Name = "Prep bench",
		Price = 0,
		Kit = true,
		Room = "Plot",
		Sites = { "Company" },
		MaxPlaced = 2,
		Description = "A company kitchen bench. Cooks fillets and fish & chips; your company chef works here too.",
		Cells = { 2, 1 },
		Width = 9,
		Depth = 2.4,
		Front = 0,
		Back = 0,
	},
	CompanyDesk = {
		Name = "Company desk",
		Price = 0,
		Kit = true,
		Room = "Plot",
		Sites = { "Company" },
		MaxPlaced = 1,
		Description = "The office desk where you manage staff and the business.",
		-- Desk and chair fill the cells; the owner stands in the +Z strip.
		Cells = { 2, 1 },
		Centered = true,
		Width = 8.2,
		Depth = 4.1,
		Front = 1.5,
		Back = 0,
	},
}
-- Racks, the prep table, the radar and decorations also furnish a company plot.
for id, item in Furniture.Items do
	if item.Decoration or id == "StorageRack" or id == "KitchenStorage" or id == "WeatherRadar" then
		item.Sites = { "Home", "Company" }
	end
end
Furniture.RACK_CAPACITY = 12
Furniture.KITCHEN_STORAGE_CAPACITY = 8
-- Keep in step with BaseGrid.CELL_SIZE; saved positions are intentionally
-- not revalidated until an item is moved.
Furniture.GRID = 4.5
-- Every item fills a block of 1x1 or 1x2 grid cells (Cells = { across, deep }).
-- It is saved at the centre of its first cell, and a second cell extends along
-- its local +X or +Z. The model (Width x Depth) sits inside: centred, or with
-- its back WALL_GAP in from the cells' back edge so it meets a wall. Front and
-- Back are strips beyond the cells where people stand; strips may share space
-- with other strips but not with furniture.
local WALL_GAP = 0.4
-- Walls straddle cell borders, so rooms and keep-clear zones are tested
-- against cells shrunk by a little more than a wall reaches into them.
local SLACK = 0.45
-- The most any partition reaches past a cell border (half its thickness).
local WALL_REACH = 0.33

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
	Plot = "company island plot",
}
-- A company island's building plot, in its own frame (CompanyIslands.plotFrame:
-- y=0 is the plot's surface, -Z faces the terrace stairs). Same lattice as a house.
Furniture.PLOT = { -54, -31.5, 54, 31.5 }
-- The gate from the stairs stays clear for the owner and the porter.
Furniture.PlotBlocked = {
	{ -4.5, -31.5, 4.5, -27 },
}
-- Floor height of a room where it isn't the house floor.
Furniture.FloorHeights = {
	Yard = 0,
}
-- Walkways, doorways and the built-in fixtures stay clear.
Furniture.Blocked = {
	{ -4, 65.6, 4, 78.4 }, -- shop entrance aisle customers walk along
	{ 15.6, 69.5, 20.8, 78.5 }, -- shop's built-in freezer and its customer strip
	{ -21, 65.6, -11.5, 74.9 }, -- shop's built-in counter, its customers and the seller
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

-- "Home" is the base house (Furniture), "Company" the island plot (CompanyFurniture).
function Furniture.allowedOn(itemId: string, site: string?): boolean
	local item = Furniture.Items[itemId]
	return item ~= nil and table.find(item.Sites or { "Home" }, site or "Home") ~= nil
end

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

-- Turns an item-local rectangle { x1, z1, x2, z2 } by r quarter turns and moves
-- it to (x, z). Clockwise seen from above matches CFrame.Angles(0, r * pi / 2, 0).
local function place(rect: { number }, x: number, z: number, r: number): { number }
	local ax, az, bx, bz = rect[1], rect[2], rect[3], rect[4]
	for _ = 1, r % 4 do
		ax, az, bx, bz = az, -ax, bz, -bx
	end
	return { x + math.min(ax, bx), z + math.min(az, bz), x + math.max(ax, bx), z + math.max(az, bz) }
end

-- The item's cells as an item-local rectangle around its saved spot, and the
-- centre of its body (the model's own frame) in the same coordinates.
function Furniture.layout(itemId: string): ({ number }?, number, number)
	local item = Furniture.Items[itemId]
	if not item then
		return nil, 0, 0
	end
	local half = Furniture.GRID / 2
	local cells = { -half, -half, -half + item.Cells[1] * Furniture.GRID, -half + item.Cells[2] * Furniture.GRID }
	local bodyZ = if item.Centered then (cells[2] + cells[4]) / 2 else cells[2] + WALL_GAP + item.Depth / 2
	return cells, (cells[1] + cells[3]) / 2, bodyZ
end

-- The grid cells { x1, z1, x2, z2 } the item fills.
function Furniture.footprint(itemId: string, x: number, z: number, r: number): { number }?
	local cells = Furniture.layout(itemId)
	return if cells then place(cells, x, z, r) else nil
end

-- The standing strips just beyond the item's cells (none for most items).
function Furniture.access(itemId: string, x: number, z: number, r: number): { { number } }
	local item = Furniture.Items[itemId]
	local cells = Furniture.layout(itemId)
	local strips = {}
	if item and cells then
		if item.Front > 0 then
			table.insert(strips, place({ cells[1], cells[4], cells[3], cells[4] + item.Front }, x, z, r))
		end
		if item.Back > 0 then
			table.insert(strips, place({ cells[1], cells[2] - item.Back, cells[3], cells[2] }, x, z, r))
		end
	end
	return strips
end

-- The model's own outline, inside its cells.
function Furniture.body(itemId: string, x: number, z: number, r: number): { number }?
	local item = Furniture.Items[itemId]
	local cells, bodyX, bodyZ = Furniture.layout(itemId)
	if not item or not cells then
		return nil
	end
	local halfW, halfD = item.Width / 2, item.Depth / 2
	return place({ bodyX - halfW, bodyZ - halfD, bodyX + halfW, bodyZ + halfD }, x, z, r)
end

local function overlaps(a: { number }, b: { number }): boolean
	return a[1] < b[3] - 1e-3 and a[3] > b[1] + 1e-3 and a[2] < b[4] - 1e-3 and a[4] > b[2] + 1e-3
end

local function inside(a: { number }, room: { number }): boolean
	return a[1] >= room[1] - 1e-3 and a[3] <= room[3] + 1e-3 and a[2] >= room[2] - 1e-3 and a[4] <= room[4] + 1e-3
end

local function shrink(a: { number }, by: number): { number }
	local dx, dz = math.min(by, (a[3] - a[1]) / 2), math.min(by, (a[4] - a[2]) / 2)
	return { a[1] + dx, a[2] + dz, a[3] - dx, a[4] - dz }
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
	-- A model may meet a wall face, or tuck its end into a wall it runs into.
	local body = shrink(Furniture.body(entry.ItemId, entry.X, entry.Z, entry.R) :: { number }, WALL_REACH)
	for _, wall in GRID_WALLS do
		if overlaps(body, wall) then return true end
	end
	if item.Room == "Dining" and overlaps(body, { -24.4, -30.5, -19.5, -23.5 }) then
		return true
	end
	return false
end

local function onGrid(value: number, grid: number): boolean
	return type(value) == "number"
		and value == value
		and math.abs(value) <= 96
		and math.abs(value / grid - math.round(value / grid)) < 1e-6
end

-- Checks one placement against the room rules and the other placed items
-- (`placed`, skipping index `skip`) on one site. Returns nil when it fits, or a
-- player-facing reason.
local function check(placed, itemId: string, x: number, z: number, r: number, skip: number?, legacy: boolean?, site: string?): string?
	local item = Furniture.Items[itemId]
	if not item then
		return "That isn't furniture."
	elseif not ((if legacy then type(x) == "number" and x == x and math.abs(x) <= 96
		and type(z) == "number" and z == z and math.abs(z) <= 96 else onGrid(x, Furniture.GRID) and onGrid(z, Furniture.GRID))
		and type(r) == "number" and r % 1 == 0 and r >= 0 and r <= 3) then
		return "That isn't a spot in your house."
	end
	local area = Furniture.footprint(itemId, x, z, r) :: { number }
	local strips = Furniture.access(itemId, x, z, r)
	-- Everything the item needs, for the room and keep-clear rules.
	local needs = { shrink(area, SLACK) }
	for _, strip in strips do
		table.insert(needs, shrink(strip, SLACK))
	end
	local function within(room: { number }): boolean
		for _, need in needs do
			if not inside(need, room) then return false end
		end
		return true
	end
	local function clearOf(zones): boolean
		for _, zone in zones do
			for _, need in needs do
				if overlaps(need, zone) then return false end
			end
		end
		return true
	end
	if site == "Company" then
		if not Furniture.allowedOn(itemId, "Company") then
			return item.Name .. "s belong in your house, not on the company plot."
		elseif not within(Furniture.PLOT) then
			return "Keep furniture inside your company plot's fence."
		elseif not clearOf(Furniture.PlotBlocked) then
			return "Keep the plot gate clear."
		end
	elseif not Furniture.allowedOn(itemId, "Home") then
		return item.Name .. "s can only go on your company island plot."
	else
		local fitsRoom = false
		for _, room in Furniture.allowedRooms(itemId) do
			if within(Furniture.Rooms[room]) then
				fitsRoom = true
				break
			end
		end
		if not fitsRoom then
			return item.Name .. "s can only go in the " .. Furniture.roomNames(itemId) .. "."
		elseif not clearOf(Furniture.Blocked) then
			return "Keep doorways, the aisle and the built-in fixtures clear."
		end
	end
	-- Cells never share space; standing strips may overlap each other.
	for index, other in placed do
		local otherArea = Furniture.footprint(other.ItemId, other.X, other.Z, other.R)
		if index ~= skip and otherArea then
			if overlaps(area, otherArea) then
				return "That spot is taken by other furniture."
			end
			for _, strip in strips do
				if overlaps(strip, otherArea) then
					return "Leave room to stand in front of it."
				end
			end
			for _, strip in Furniture.access(other.ItemId, other.X, other.Z, other.R) do
				if overlaps(area, strip) then
					return "That would block the space in front of other furniture."
				end
			end
		end
	end
	return nil
end

function Furniture.check(placed, itemId: string, x: number, z: number, r: number, skip: number?, site: string?): string?
	return check(placed, itemId, x, z, r, skip, false, site)
end

-- Historical saves used half-stud positions. This relaxed snapping is only for
-- relocating an existing item when the new walls would otherwise cover it.
function Furniture.checkRelocation(placed, itemId: string, x: number, z: number, r: number, site: string?): string?
	return check(placed, itemId, x, z, r, nil, true, site)
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

-- Floor height (house-local y) an item stands on; the company plot is flat at 0.
function Furniture.floor(itemId: string?, site: string?): number
	if site == "Company" then
		return 0
	end
	local item = itemId and Furniture.Items[itemId]
	return item and Furniture.FloorHeights[item.Room] or 0.16
end

-- World frame on the floor of the house (or the yard deck, or the company plot
-- when `houseFrame` is a plot frame) for a placed entry: the centre of the
-- model's base, which sits inside its cells. Built-in benches have no ItemId
-- and stand exactly on their saved spot.
function Furniture.frame(houseFrame, entry, site: string?)
	local _, bodyX, bodyZ = Furniture.layout(entry.ItemId)
	return houseFrame
		* CFrame.new(entry.X, Furniture.floor(entry.ItemId, site), entry.Z)
		* CFrame.Angles(0, entry.R * math.pi / 2, 0)
		* CFrame.new(bodyX, 0, bodyZ)
end

return Furniture
