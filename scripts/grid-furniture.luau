-- Building cells and furniture placement share one lattice.
local Grid = require('../src/shared/BaseGrid')
local Furniture = require('../src/shared/FurnitureCatalog')
local Data = require('../src/server/AnglerData')

assert(Furniture.GRID == Grid.CELL_SIZE, 'Furniture and house grid sizes must match')
-- Every model fills a 1x1 or 1x2 block of whole cells, and sits inside it.
for id, item in Furniture.Items do
 local across, deep = item.Cells[1], item.Cells[2]
 assert(across * deep <= 2 and across >= 1 and deep >= 1, id .. ' must be 1x1 or 1x2 cells')
 for r = 0, 3 do
  local area = Furniture.footprint(id, 0, 0, r)
  for _, edge in area do
   assert(math.abs((edge - Grid.CELL_SIZE / 2) / Grid.CELL_SIZE - math.round((edge - Grid.CELL_SIZE / 2) / Grid.CELL_SIZE)) < 1e-6, id .. ' cells must sit on the grid')
  end
  local body = Furniture.body(id, 0, 0, r)
  assert(body[1] >= area[1] - 1e-6 and body[2] >= area[2] - 1e-6 and body[3] <= area[3] + 1e-6 and body[4] <= area[4] + 1e-6, id .. ' model must fit inside its cells')
 end
end
assert(Furniture.check({}, 'StorageRack', 22.5, -13.5, 0) == nil, 'Rack must fit at the storage room corner')
assert(Furniture.check({ { ItemId = 'StorageRack', X = 22.5, Z = -13.5, R = 0 } }, 'StorageRack', 18, -13.5, 0) == nil, 'Racks must fit in adjacent tiles')
assert(Furniture.check({}, 'StorageRack', 4.5, -13.5, 0) == nil, 'Rack must fit in the corner beside the passage wall')
-- A 1x2 item covers its own cell and the next one along local +X.
local freezer = Furniture.footprint('Freezer', -9, 72, 0)
assert(freezer[1] == -11.25 and freezer[3] == -2.25 and freezer[2] == 69.75 and freezer[4] == 74.25, 'Freezer cells')
local turned = Furniture.footprint('Freezer', -9, 72, 1)
assert(turned[3] - turned[1] == Grid.CELL_SIZE and turned[4] - turned[2] == 2 * Grid.CELL_SIZE, 'Turned freezer cells')
-- Two kitchen counters line up end to end with no gap.
local placedLine = { { ItemId = 'GrillStation', X = -22.5, Z = -13.5, R = 0 } }
assert(Furniture.check(placedLine, 'Smoker', -13.5, -13.5, 0) == nil, 'Counters must sit end to end')
assert(Furniture.check(placedLine, 'Smoker', -18, -13.5, 0) ~= nil, 'Counters must not overlap')
-- Standing strips keep furniture out but may share an aisle with each other.
local shopFreezer = { ItemId = 'Freezer', X = 9, Z = 67.5, R = 0 }
assert(Furniture.check({ shopFreezer }, 'PottedPlant', 9, 72, 0) ~= nil, 'A plant must not block the freezer front')
assert(Furniture.check({ shopFreezer }, 'Freezer', 13.5, 76.5, 2) == nil, 'Facing freezers may share their aisle')
for column = Grid.BASE_MIN_COLUMN, Grid.BASE_MAX_COLUMN do
 for row = Grid.BASE_MIN_ROW, Grid.BASE_MAX_ROW do
  local x, z = Grid.extendedCellToLocal(column, row)
  local actualColumn, actualRow = Grid.localToExtendedCell(x, z)
  assert(actualColumn == column and actualRow == row, 'Extended grid center must round-trip')
 end
end
for _, spot in { { -28, -34 }, { 28, 17 }, { -17, -86 }, { 17, -86 }, { 0, -81 } } do
 assert(Grid.localToExtendedCell(spot[1], spot[2]) ~= nil, 'Grid must cover the quay and dock')
end
for _, spot in { { 0, 52 }, { 0, 62.4 }, { -22.5, 62 }, { 22.5, 62 }, { -24, 82.9 }, { 24, 82.9 } } do
 assert(Grid.localToExtendedCell(spot[1], spot[2]) ~= nil, 'Grid must cover the road and the shop across it')
end
assert(Furniture.Rooms.Shop[2] > Grid.SHOP_FRONT and Furniture.Rooms.Shop[4] < Grid.SHOP_BACK, 'Shop room is inside the shop walls')
assert(Grid.localToExtendedCell(0, -110) == nil, 'Distant water is outside the base grid')
for _, id in Furniture.Order do
 for _, roomId in Furniture.allowedRooms(id) do
  local room = Furniture.Rooms[roomId]
  local found = false
  for x = math.ceil(room[1] / Grid.CELL_SIZE) * Grid.CELL_SIZE, room[3], Grid.CELL_SIZE do
   for z = math.ceil(room[2] / Grid.CELL_SIZE) * Grid.CELL_SIZE, room[4], Grid.CELL_SIZE do
    for r = 0, 3 do
     if Furniture.check({}, id, x, z, r) == nil then
      found = true
      break
     end
    end
    if found then break end
   end
   if found then break end
  end
  assert(found, id .. ' has no legal grid position in ' .. roomId)
 end
end

-- The new placement rule must never discard pre-grid purchases or positions.
-- (Every profile also holds the house fixtures, added after its saved furniture.)
local legacy = Data.decode({ ShopBuildingVersion = 1, Furniture = { { ItemId = 'PottedPlant', X = -10, Z = -4.5, R = 0 } } })
assert(legacy.Furniture[1].X == -10 and legacy.Furniture[1].Z == -4.5, 'Legacy coordinates changed')
assert(Furniture.check({}, 'PottedPlant', -10, -4.5, 0) ~= nil, 'Off-grid new placement was accepted')
local picked = assert(Data.pickUpFurniture(legacy, 1))
assert(#picked.Furniture == #Data.FIXTURES and picked.FurnitureStock.PottedPlant == 1, 'Legacy item could not be picked up')
local placed = assert(Data.placeFurniture(picked, 'PottedPlant', -9, -4.5, 0))
local plant = placed.Furniture[#placed.Furniture]
assert(plant.X == -9 and plant.Z == -4.5, 'Grid placement failed')
-- The shop moved out of the house's front room into its own building across the
-- street. Saved front-room layouts (legal under the old room rules) turn half a
-- circle with it and still fit; the kitchen and storage room keep their
-- furniture where it was.
local oldShop = {
 { ItemId = 'Freezer', X = -13.5, Z = 9, R = 1 },
 { ItemId = 'FoodCase', X = 9, Z = 9, R = 3 },
 { ItemId = 'PottedPlant', X = -13.5, Z = 13.5, R = 0 },
 { ItemId = 'Rug', X = 13.5, Z = 13.5, R = 0 },
 { ItemId = 'GrillStation', X = -13.5, Z = -9, R = 0 },
 { ItemId = 'StorageRack', X = 13.5, Z = -9, R = 0 },
}
local moved = Data.decode({ Furniture = oldShop })
assert(moved.ShopBuildingVersion == 1 and #moved.Furniture == #oldShop + #Data.FIXTURES, 'Shop migration lost furniture')
for index, before in oldShop do
 local entry = moved.Furniture[index]
 if before.Z > 2.25 then
  assert(entry.R == (before.R + 2) % 4, before.ItemId .. ' did not turn into the shop')
  assert(Furniture.check(moved.Furniture, entry.ItemId, entry.X, entry.Z, entry.R, index) == nil, before.ItemId .. ' no longer fits in the shop')
 else
  assert(entry.X == before.X and entry.Z == before.Z and entry.R == before.R, before.ItemId .. ' moved out of the house')
 end
end
local again = Data.decode(moved)
for index, entry in moved.Furniture do
 assert(again.Furniture[index].Z == entry.Z and again.Furniture[index].R == entry.R, 'Shop migration was not idempotent')
end
print('Furniture grid: all items fit in their allowed rooms; legacy positions survive and can be moved.')
