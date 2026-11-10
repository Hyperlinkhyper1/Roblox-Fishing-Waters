-- Exercise the real decoder and furniture rules without Roblox services.
local Data = require('../src/server/AnglerData')
local Furniture = require('../src/shared/FurnitureCatalog')

local fish = { FishId = 'Trout', Mutation = 'Normal', Kg = 2, Value = 20, Rarity = 1, Relative = 1, CaughtAt = 100 }
local dish = { RecipeId = 'Grilled', FishId = 'Trout', Mutation = 'Normal', Kg = 2, Value = 25, MadeAt = 100 }
local old = {
	Furniture = {
		{ ItemId = 'PottedPlant', X = 6, Z = 3, R = 0 }, -- shifted partition
		{ ItemId = 'DiningTable', X = -7.5, Z = -21, R = 0 }, -- moved dining wall
		{ ItemId = 'DiningTable', X = -21, Z = -24, R = 0 }, -- new entrance
		{ ItemId = 'StorageRack', X = 15, Z = -12, R = 0 },
		{ ItemId = 'GrillStation', X = -10, Z = -8, R = 0 },
		{ ItemId = 'FutureFurniture', X = 30, Z = 30, R = 0 },
		{ ItemId = 'PottedPlant', X = -12, Z = 12, R = 0 }, -- enclosed office
	},
	FurnitureStock = { Freezer = 1 }, Freezer = { fish }, Storage = { fish },
	KitchenStorage = { Targets = { Common = 1 }, Fish = { fish } },
	Kitchen = { GrillStation = { Dish = dish, ReadyAt = 1000 } },
}
assert(Furniture.intersectsGridWall(old.Furniture[1]), 'Expected partition conflict')
assert(Furniture.intersectsGridWall(old.Furniture[2]), 'Expected dining wall conflict')
assert(Furniture.intersectsGridWall(old.Furniture[3]), 'Expected dining entrance conflict')
assert(Furniture.intersectsGridWall(old.Furniture[7]), 'Expected enclosed office conflict')
local data = Data.decode(old)
-- The house fixtures (freezer, till, office desk) join after the saved furniture.
assert(#data.Furniture == #old.Furniture + #Data.FIXTURES and data.FurnitureStock.Freezer == 1, 'Purchases changed')
-- The plant stood in the old front shop room, so it moved with the shop into its
-- own building across the street (turned to face the house), clear of every wall.
local plant = data.Furniture[1]
assert(plant.X == -6 and plant.Z == 78 and plant.R == 2, 'Front-room furniture did not move to the shop building')
assert(not Furniture.intersectsGridWall(plant), 'Moved shop furniture is inside a wall')
for i = 2, 3 do
	assert(not Furniture.intersectsGridWall(data.Furniture[i]), 'Affected item was not relocated')
	assert(data.Furniture[i].R == old.Furniture[i].R, 'Rotation changed')
end
for i = 4, 6 do
	assert(data.Furniture[i].X == old.Furniture[i].X and data.Furniture[i].Z == old.Furniture[i].Z, 'Unaffected item moved')
end
assert(
	not Furniture.intersectsGridWall(data.Furniture[7])
		and (data.Furniture[7].X ~= old.Furniture[7].X or data.Furniture[7].Z ~= old.Furniture[7].Z),
	'Furniture left in the enclosed office was not relocated'
)
assert(old.Furniture[1].X == 6 and old.Furniture[1].Z == 3, 'Decode mutated the original profile')
assert(#data.Freezer == 1 and #data.Storage == 1 and #data.KitchenStorage.Fish == 1, 'Fish were lost')
assert(data.Kitchen.GrillStation.Dish.RecipeId == 'Grilled' and data.Kitchen.GrillStation.ReadyAt == 1000, 'Cooking job was lost')
assert(data.FurnitureWallVersion == 2 and not data.FurnitureWallMigrationPending, 'Migration should complete')
local again = Data.decode(data)
for i, entry in data.Furniture do
	assert(again.Furniture[i].X == entry.X and again.Furniture[i].Z == entry.Z, 'Migration was not idempotent')
end

-- A previous crowded migration is not retried on ordinary reads, but is retried
-- after a successful pickup frees room. Unknown items must never block decoding.
local pending = Data.decode({
	-- Already in the shop building's coordinates, so only the wall retry applies.
	ShopBuildingVersion = 1, FurnitureWallVersion = 2, FurnitureWallMigrationPending = true,
	Furniture = { { ItemId = 'PottedPlant', X = 6, Z = 3, R = 0 }, { ItemId = 'PottedPlant', X = 18, Z = -12, R = 0 } },
})
assert(pending.Furniture[1].X == 6 and pending.Furniture[1].Z == 3, 'Ordinary decode retried pending relocation')
local resolved = assert(Data.pickUpFurniture(pending, 2))
assert(not resolved.FurnitureWallMigrationPending and not Furniture.intersectsGridWall(resolved.Furniture[1]), 'Pickup did not retry pending migration')
assert(resolved.FurnitureStock.PottedPlant == 1, 'Picked up item was lost')

-- Saturate the available space with a test fixture to exercise the genuinely
-- unplaceable case without deleting an item or its stored contents.
-- The plant straddles the old shop partition from the kitchen side, so it stays
-- in the house; the blocker also covers the shop building across the street.
Furniture.Items.MigrationTestBlocker = { Name = 'test blocker', Room = 'Shop', Cells = { 60, 60 }, Width = 200, Depth = 200, Front = 0, Back = 0 }
local blockedRaw = {
	Furniture = { { ItemId = 'PottedPlant', X = 6, Z = 1.5, R = 0 }, { ItemId = 'MigrationTestBlocker', X = -96, Z = -96, R = 0 }, { ItemId = 'StorageRack', X = 15, Z = -12, R = 0 } },
	Freezer = { fish }, Storage = { fish }, Kitchen = { GrillStation = { Dish = dish, ReadyAt = 1000 } },
}
local blocked = Data.decode(blockedRaw)
assert(blocked.FurnitureWallMigrationPending and #blocked.Furniture == 3 + #Data.FIXTURES, 'Unplaceable furniture must remain owned and placed')
assert(blocked.Furniture[1].X == 6 and blocked.Furniture[1].Z == 1.5, 'Failed relocation must retain the original position')
assert(#blocked.Freezer == 1 and #blocked.Storage == 1 and blocked.Kitchen.GrillStation.ReadyAt == 1000, 'Blocked migration lost contents')
local unblocked = assert(Data.pickUpFurniture(blocked, 2))
assert(not unblocked.FurnitureWallMigrationPending and not Furniture.intersectsGridWall(unblocked.Furniture[1]), 'Removing blocker did not complete migration')
assert(unblocked.FurnitureStock.MigrationTestBlocker == 1, 'Blocker purchase was lost')
Furniture.Items.MigrationTestBlocker = nil
print('Furniture wall migration: moved affected entries, preserved contents and jobs, and retried safely')
