-- Building cells and furniture placement share one lattice.
local Grid = require('../src/shared/BaseGrid')
local Furniture = require('../src/shared/FurnitureCatalog')
local Data = require('../src/server/AnglerData')

assert(Furniture.GRID == Grid.CELL_SIZE, 'Furniture and house grid sizes must match')
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
     local area = Furniture.footprint(id, x, z, r)
     if area[1] >= room[1] and area[2] >= room[2] and area[3] <= room[3] and area[4] <= room[4]
      and Furniture.check({}, id, x, z, r) == nil then
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
local legacy = Data.decode({ ShopBuildingVersion = 1, Furniture = { { ItemId = 'PottedPlant', X = -10, Z = 4.5, R = 0 } } })
assert(legacy.Furniture[1].X == -10 and legacy.Furniture[1].Z == 4.5, 'Legacy coordinates changed')
assert(Furniture.check({}, 'PottedPlant', -10, 4.5, 0) ~= nil, 'Off-grid new placement was accepted')
local picked = assert(Data.pickUpFurniture(legacy, 1))
assert(#picked.Furniture == 0 and picked.FurnitureStock.PottedPlant == 1, 'Legacy item could not be picked up')
local placed = assert(Data.placeFurniture(picked, 'PottedPlant', -9, 4.5, 0))
assert(placed.Furniture[1].X == -9 and placed.Furniture[1].Z == 4.5, 'Grid placement failed')
-- The shop moved out of the house's front room into its own building across the
-- street. Saved front-room layouts (legal under the old room rules) turn half a
-- circle with it and still fit; the kitchen and storage room keep their
-- furniture where it was.
local oldShop = {
 { ItemId = 'Freezer', X = -13.5, Z = 9, R = 1 },
 { ItemId = 'FoodCase', X = 9, Z = 9, R = 3 },
 { ItemId = 'PottedPlant', X = -22.5, Z = 4.5, R = 0 },
 { ItemId = 'Rug', X = 18, Z = 4.5, R = 0 },
 { ItemId = 'GrillStation', X = -13.5, Z = -9, R = 0 },
 { ItemId = 'StorageRack', X = 13.5, Z = -9, R = 0 },
}
local moved = Data.decode({ Furniture = oldShop })
assert(moved.ShopBuildingVersion == 1 and #moved.Furniture == #oldShop, 'Shop migration lost furniture')
for index, entry in moved.Furniture do
 local before = oldShop[index]
 if before.Z > 2.25 then
  assert(entry.X == -before.X and entry.Z == Grid.SHOP_TURN - before.Z and entry.R == (before.R + 2) % 4, before.ItemId .. ' did not turn into the shop')
  local area = Furniture.footprint(entry.ItemId, entry.X, entry.Z, entry.R)
  local room = Furniture.Rooms.Shop
  assert(area[1] >= room[1] and area[3] <= room[3] and area[2] >= room[2] and area[4] <= room[4], before.ItemId .. ' left the shop room')
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
