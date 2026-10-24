-- Furniture sold at the plaza's furniture shop and the placement rules for a base
-- house, shared by the server (which validates every placement) and the build
-- mode preview. Pure: no Roblox services, so the saved-data tests run it directly.
--
-- Positions are house-local studs (the BaseHouse "HouseFrame": +Z is the street
-- front, the floor is y=0.16). An item at X, Z turns R quarter turns about +Y; its
-- own +Z is the side customers or the porter use.
local Furniture = {}

Furniture.Order = { "Freezer", "Register", "StorageRack" }
Furniture.Items = {
	Freezer = {
		Name = "Fish freezer",
		Price = 750,
		Room = "Shop",
		MaxPlaced = 4,
		Description = "Another chilled display. Holds 4 more fish for customers to buy.",
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
		Description = "Shelving for overflow stock. Holds 8 fish when your freezers are full, so you can empty your boat.",
		Width = 6,
		Depth = 2,
		Front = 1.5,
		Back = 0,
	},
}
Furniture.RACK_CAPACITY = 8
Furniture.GRID = 0.5

-- Inner floor of each furnishable room, as { x1, z1, x2, z2 }.
Furniture.Rooms = {
	Shop = { -22.6, 1.35, 22.6, 14.6 },
	Storage = { 3.35, -14.6, 22.6, 0.65 },
}
Furniture.RoomNames = { Shop = "front shop room", Storage = "storage room" }
-- Walkways, doorways and the built-in fixtures stay clear.
Furniture.Blocked = {
	{ -4, 1.35, 4, 14.6 }, -- entrance aisle customers walk along
	{ -13.5, 1.35, -6.5, 4 }, -- doorway to the processing room
	{ 8.5, -3, 15.5, 4 }, -- doorway between the shop and the storage room
	{ 3.35, -10.5, 6.5, -3.5 }, -- passage from the processing room
	{ -20.8, 2.5, -15.6, 11.5 }, -- built-in freezer and its customer strip
	{ 11.5, 6.4, 21, 14.6 }, -- built-in counter, its customers and the seller
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
	return type(value) == "number" and value == value and math.abs(value) <= 64
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
		if index ~= skip and overlaps(area, Furniture.footprint(other.ItemId, other.X, other.Z, other.R) :: { number }) then
			return "That spot is taken by other furniture."
		end
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

-- World frame on the floor of the house for a placed entry.
function Furniture.frame(houseFrame, entry)
	return houseFrame * CFrame.new(entry.X, 0.16, entry.Z) * CFrame.Angles(0, entry.R * math.pi / 2, 0)
end

return Furniture
