local Data = require("../src/server/AnglerData")
local Furniture = require("../src/shared/FurnitureCatalog")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

-- Every profile starts with the house fixtures (freezer, till, office desk).
local fixtures = Data.decode(nil).Furniture
local FIXTURES = #fixtures
for index, fixture in fixtures do
	check(Furniture.Items[fixture.ItemId].Keep and Data.pickUpFurniture(Data.decode(nil), index) == nil,
		"The only " .. fixture.ItemId .. " can be moved but never picked up")
end
check(Data.placeFurniture(Data.decode(nil), 3, -22.5, 9, 0) ~= nil, "The office desk moves within the office")
check(Data.placeFurniture(Data.decode(nil), 3, -9, -9, 0) == nil, "The office desk stays in the office")

-- Decorations can be bought, placed in every indoor room, saved and picked up.
-- Find a legal grid position in each room using the actual shared placement rules.
local decorationCount = 0
for _, id in Furniture.Order do
	local item = Furniture.Items[id]
	if not item.Decoration then continue end
	decorationCount += 1
	for _, roomId in { "Shop", "Storage", "Processing" } do
		local room = Furniture.Rooms[roomId]
		local xFound, zFound
		for x = math.ceil(room[1] / Furniture.GRID) * Furniture.GRID, room[3], Furniture.GRID do
			for z = math.ceil(room[2] / Furniture.GRID) * Furniture.GRID, room[4], Furniture.GRID do
				local footprint = Furniture.footprint(id, x, z, 0)
				if footprint[1] >= room[1] and footprint[2] >= room[2]
					and footprint[3] <= room[3] and footprint[4] <= room[4]
					and Furniture.check(fixtures, id, x, z, 0) == nil then
					xFound, zFound = x, z
					break
				end
			end
			if xFound then break end
		end
		check(xFound ~= nil, id .. " must have a legal spot in " .. roomId)
		local profile = assert(Data.buyFurniture(Data.decode(nil), id))
		profile = assert(Data.placeFurniture(profile, id, xFound, zFound, 0))
		local reloaded = Data.decode(profile)
		local saved = reloaded.Furniture[FIXTURES + 1]
		check(#reloaded.Furniture == FIXTURES + 1 and saved.ItemId == id
			and saved.X == xFound and saved.Z == zFound,
			id .. " must survive a saved profile round trip in " .. roomId)
		local withSecond = assert(Data.buyFurniture(reloaded, id))
		check(Data.placeFurniture(withSecond, id, xFound, zFound, 0) == nil,
			id .. " must not overlap placed furniture")
		local pickedUp = assert(Data.pickUpFurniture(reloaded, FIXTURES + 1))
		check(#pickedUp.Furniture == FIXTURES and pickedUp.FurnitureStock[id] == 1,
			id .. " must return to stock after pickup")
	end
end
check(decorationCount >= 10, "The furniture shop should offer a variety of decorations")

-- Old furniture and new stock must survive together in a single profile.
local mixed = Data.decode({
	FurnitureStock = { StorageRack = 2 },
	Furniture = { { ItemId = "Freezer", X = -10, Z = 9, R = 1 } },
})
for _, id in Furniture.Order do
	if Furniture.Items[id].Decoration then mixed = assert(Data.buyFurniture(mixed, id)) end
end
mixed = Data.decode(mixed)
check(mixed.FurnitureStock.StorageRack == 2 and mixed.Furniture[1].ItemId == "Freezer",
	"Adding decoration stock must preserve existing furniture")
for _, id in Furniture.Order do
	if not Furniture.Items[id].Decoration then continue end
	local placed = nil
	for x = -18, 18, Furniture.GRID do
		for z = -13.5, 13.5, Furniture.GRID do
			if Furniture.check(mixed.Furniture, id, x, z, 0) == nil then
				placed = assert(Data.placeFurniture(mixed, id, x, z, 0))
				break
			end
		end
		if placed then break end
	end
	check(placed ~= nil, "Could not fit " .. id .. " alongside existing furniture")
	mixed = placed
end
mixed = Data.decode(mixed)
check(#mixed.Furniture == decorationCount + 1 + FIXTURES and mixed.FurnitureStock.StorageRack == 2
	and mixed.Furniture[1].ItemId == "Freezer", "All decoration types and old furniture must survive together")

print("Decorations: " .. checks .. " purchase, placement and persistence checks passed (pure data; no Roblox runtime).")
