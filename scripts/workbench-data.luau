-- Pure placement and saved-progress checks; no Roblox services required.
local Data = require("../src/server/AnglerData")
local Furniture = require("../src/shared/FurnitureCatalog")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local function indexOf(data)
	for index, entry in data.Furniture do
		if entry.ItemId == "Workbench" then return index end
	end
	return nil
end
local function legacy()
	local data = Data.decode(nil)
	table.remove(data.Furniture, assert(indexOf(data)))
	data.WorkbenchVersion = nil
	return data
end
local function unchanged(before, after)
	for index, entry in before do
		local saved = after[index]
		check(saved.ItemId == entry.ItemId and saved.X == entry.X and saved.Z == entry.Z and saved.R == entry.R,
			"Adding a workbench preserves existing furniture")
	end
end

local item = Furniture.Items.Workbench
check(item.Fixture and item.MaxPlaced == 1 and not item.Keep, "Workbench is a pickable house fixture")
check(item.Cells[1] == 2 and item.Cells[2] == 1 and item.Centered, "Workbench occupies a centered 2x1 footprint")
check(item.Front == 0 and item.Back == 0, "Decorative workbench reserves no working aisle")
local fresh = Data.decode(nil)
local index = assert(indexOf(fresh))
local bench = fresh.Furniture[index]
check(#fresh.Furniture == #Data.FIXTURES + 1 and fresh.WorkbenchVersion == 1, "Fresh bases receive one workbench")
check(bench.X == 4.5 and bench.Z == -13.5 and bench.R == 0,
	"Fresh workbench starts in the storage room's rear corner")
check(Furniture.check(fresh.Furniture, "Workbench", bench.X, bench.Z, bench.R, index) == nil,
	"Default workbench placement is legal")
check(Data.storageCapacity(fresh) == 0 and table.find(Furniture.Order, "Workbench") == nil,
	"Workbench adds no storage and is absent from the shop catalogue")

local old = legacy()
local upgraded = Data.decode(old)
unchanged(old.Furniture, upgraded.Furniture)
check(#upgraded.Furniture == #old.Furniture + 1 and indexOf(old) == nil and old.WorkbenchVersion == nil,
	"Existing bases receive the workbench without mutating their saved input")
check(#Data.decode(upgraded).Furniture == #upgraded.Furniture, "Repeated decode never duplicates fixtures")
for _, fixture in Data.FIXTURES do
	check(Furniture.count(upgraded.Furniture, fixture.ItemId) == 1, "Old fixtures are not re-granted")
end

local moved = assert(Data.placeFurniture(fresh, index, 22.5, -4.5, 1))
local savedMove = Data.decode(moved).Furniture[index]
check(savedMove.X == 22.5 and savedMove.Z == -4.5 and savedMove.R == 1,
	"Workbench movement and quarter-turn rotation survive reload")
local picked = assert(Data.pickUpFurniture(moved, index))
local savedStock = Data.decode(picked)
check(indexOf(savedStock) == nil and savedStock.FurnitureStock.Workbench == 1,
	"Picked-up workbench remains in stock across reload")
local replaced = assert(Data.placeFurniture(savedStock, "Workbench", bench.X, bench.Z, 0))
check(Furniture.count(replaced.Furniture, "Workbench") == 1 and replaced.FurnitureStock.Workbench == nil,
	"Placing the stored workbench consumes exactly one stock item")

-- Detect already-owned benches even when their one-time marker is absent.
moved.WorkbenchVersion = nil
local existing = Data.decode(moved)
unchanged(moved.Furniture, existing.Furniture)
check(#existing.Furniture == #moved.Furniture and existing.WorkbenchVersion == 1,
	"Preexisting placed workbench is recognized without duplication")
picked.WorkbenchVersion = nil
local stocked = Data.decode(picked)
check(indexOf(stocked) == nil and stocked.FurnitureStock.Workbench == 1 and stocked.WorkbenchVersion == 1,
	"Preexisting stored workbench is recognized without duplication")

local occupied = legacy()
table.insert(occupied.Furniture, { ItemId = "StorageRack", X = bench.X, Z = bench.Z, R = 0 })
local nearby = Data.decode(occupied)
unchanged(occupied.Furniture, nearby.Furniture)
local nearbyIndex = assert(indexOf(nearby))
local alternate = nearby.Furniture[nearbyIndex]
check(Furniture.check(nearby.Furniture, "Workbench", alternate.X, alternate.Z, alternate.R, nearbyIndex) == nil,
	"Occupied default uses a legal alternative")
local distance = (alternate.X - bench.X) ^ 2 + (alternate.Z - bench.Z) ^ 2
check(distance > 0, "Workbench never overlaps furniture at its default location")
local room, grid = Furniture.Rooms.Storage, Furniture.GRID
for x = math.ceil(room[1] / grid) * grid, room[3], grid do
	for z = math.ceil(room[2] / grid) * grid, room[4], grid do
		for r = 0, 3 do
			if Furniture.check(occupied.Furniture, "Workbench", x, z, r) == nil
				and not Furniture.intersectsGridWall({ ItemId = "Workbench", X = x, Z = z, R = r }) then
				check(distance <= (x - bench.X) ^ 2 + (z - bench.Z) ^ 2,
					"Alternative is a nearest legal grid location")
			end
		end
	end
end

local crowded = legacy()
for x = math.ceil(room[1] / grid) * grid, room[3], grid do
	for z = math.ceil(room[2] / grid) * grid, room[4], grid do
		if Furniture.check(crowded.Furniture, "PottedPlant", x, z, 0) == nil then
			table.insert(crowded.Furniture, { ItemId = "PottedPlant", X = x, Z = z, R = 0 })
		end
	end
end
local full = Data.decode(crowded)
unchanged(crowded.Furniture, full.Furniture)
check(indexOf(full) == nil and full.FurnitureStock.Workbench == 1 and full.WorkbenchVersion == 1,
	"Full storage room keeps the workbench in stock")
check(#full.Furniture == #crowded.Furniture and Data.decode(full).FurnitureStock.Workbench == 1,
	"Full-room migration preserves all furniture and never re-grants stock")
check(not pcall(Data.decode, { WorkbenchVersion = "1" }), "Invalid migration marker is rejected")
print("Workbench: " .. checks .. " placement and saved-progress checks passed.")
