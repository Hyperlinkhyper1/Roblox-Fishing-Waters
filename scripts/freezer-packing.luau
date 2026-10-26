local Packing, Models = freezerTestPacking, freezerTestModels
local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end
local function fish(id, kg, n)
	return { FishId = id, Mutation = "Normal", Kg = kg, CaughtAt = n or 1, Value = 10, Rarity = 1, Relative = 1 }
end
local function fill(record, count)
	local data = Data.decode(nil)
	for _ = 2, count or 1 do
		table.insert(data.Furniture, { ItemId = "Freezer", X = 0, Z = 0, R = 0 })
	end
	for _ = 1, 300 do
		data.Hand = table.clone(record)
		local nextData, moved = Data.stockFreezer(data)
		if moved == 0 then
			return data
		end
		check(data.Hand ~= nil and #nextData.Freezer == #data.Freezer + 1, "Stocking is copy-on-write")
		data = nextData
	end
	error("Cooler never filled")
end
local function verify(data)
	local layout, fits = Data.freezerLayout(data)
	check(fits, "Accepted inventory must all fit")
	local boxes = {}
	for index, record in data.Freezer do
		local p = layout[index]
		check(p ~= nil, "Every stocked fish gets a display position")
		local size = Models.catchBounds(record)
		local width, depth = math.max(size.Y, size.Z), size.X
		if p.Rotated then
			width, depth = depth, width
		end
		local y = (p.Z - Packing.BACK) / math.cos(Packing.SLOPE)
		local box = { bed = p.Freezer, x = p.X - width / 2, y = y - depth / 2, w = width, h = depth }
		check(
			box.x >= Packing.LEFT + Packing.MARGIN - 1e-6 and box.x + box.w <= Packing.RIGHT - Packing.MARGIN + 1e-6,
			"Fish stays inside cooler walls"
		)
		check(
			box.y >= Packing.MARGIN - 1e-6
				and box.y + box.h
					<= (Packing.FRONT - Packing.BACK) / math.cos(Packing.SLOPE) - Packing.MARGIN + 1e-6,
			"Fish stays on the sloped ice bed"
		)
		for _, other in boxes do
			check(
				box.bed ~= other.bed
					or box.x + box.w <= other.x + 1e-6
					or other.x + other.w <= box.x + 1e-6
					or box.y + box.h <= other.y + 1e-6
					or other.y + other.h <= box.y + 1e-6,
				"Fish never overlap"
			)
		end
		table.insert(boxes, box)
	end
end
local small = fill(fish("Anchovy", 0.01))
local large = fill(fish("YellowfinTuna", 100))
check(#small.Freezer > 4 and #small.Freezer > 24, "Small fish use the full cooler beyond the old display cap")
check(#small.Freezer > #large.Freezer, "Small fish allow more stock than large fish")
verify(small)
verify(large)
local two = fill(fish("YellowfinTuna", 100), 2)
check(#two.Freezer == 2 * #large.Freezer, "Placed cooler doubles identical-fish capacity")
verify(two)
check(not Data.pickUpFurniture(two, 1), "Cannot remove a cooler while its fish would overflow")
local sold, price = Data.sellFrozen(large, large.Freezer[1])
check(price == 10 and Data.canFreeze(sold, large.Freezer[1]), "A sale releases enough room for that fish")
local fullCount = #large.Freezer
local unchanged, moved = Data.stockFreezer(large)
check(
	moved == 0 and unchanged.Hand ~= nil and #unchanged.Freezer == fullCount,
	"Rejected stocking preserves the held catch"
)
large.Holds.Rowboat = { { X = 1, Y = 1, R = 0, Fish = large.Hand } }
check(Data.unloadFish(large, "Rowboat", 1, large.Hand) == nil, "Porter cannot overfill the cooler")
large.Storage = { large.Hand }
check(Data.restockFish(large, large.Hand) == nil, "Rack restock cannot overfill the cooler")
local mixed = Data.decode(nil)
for round = 1, 12 do
	for _, id in { "Anchovy", "Trout", "Clownfish", "YellowfinTuna", "Stingray" } do
		local record = fish(id, if id == "Anchovy" then 0.01 else round, round)
		if Models.has(id) then
			mixed.Hand = record
			mixed = Data.stockFreezer(mixed)
		end
	end
end
verify(mixed)
-- Every supported fish silhouette, including flatfish, eels and junk catches.
for _, id in
	{
		"Trout",
		"Carp",
		"BlueMackerel",
		"Cod",
		"Bluegill",
		"Angelfish",
		"ArrowSquid",
		"GreyEel",
		"GulfFlounder",
		"Stingray",
		"Clownfish",
		"Sardine",
		"Anchovy",
		"Catfish",
		"Pufferfish",
		"YellowfinTuna",
		"Sailfish",
		"Swordfish",
		"Yellowshark",
		"WoodenBranch",
		"LeatherBoot",
	}
do
	for _, kg in { 0.01, 2, 100 } do
		verify(fill(fish(id, kg)))
	end
end
local corrupt = fish("Trout", 2)
corrupt.Mutation, corrupt.Corruptions = "Corrupted", { "Eye" }
local model = Models.create(corrupt.FishId, corrupt)
local actual, expected = model:GetAttribute("BoundsSize"), Models.catchBounds(corrupt)
local ratio = Models.catchLength(corrupt.Kg) / math.max(actual.X, actual.Y, actual.Z, 0.1)
check(
	math.abs(expected.X - actual.X * ratio) < 1e-6 and math.abs(expected.Y - actual.Y * ratio) < 1e-6,
	"Packing includes shape-changing mutations"
)
local legacy = Data.decode(nil)
for _ = 1, 30 do
	table.insert(legacy.Freezer, fish("YellowfinTuna", 100))
end
check(
	#Data.decode(legacy).Freezer == 30 and not Data.canFreeze(legacy, fish("Anchovy", 0.01)),
	"Legacy overflow is preserved and cannot accept more stock"
)
print(
	"Freezer packing: "
		.. checks
		.. " checks passed; one cooler fits "
		.. #small.Freezer
		.. " tiny anchovies or "
		.. #large.Freezer
		.. " large tuna (model doubles; no Studio runtime)."
)
