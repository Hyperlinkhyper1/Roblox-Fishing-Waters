-- Production plaza and shop builders are inserted by check-rod-shop.mjs.
-- Recording mocks check geometry and migrations, not Roblox rendering or live physics.
local root = Instance.new("Folder")
root.Name = "Map"
local village = Instance.new("Model")
village.Name, village.Parent = "Village", root
local plazaCenter = shape.toWorld({ 870, 694 })
Harbour.buildPlaza(village, plazaCenter, Random.new(Biomes.Seed + 1))
local plaza = root:FindFirstChild("Plaza", true)
local paving
for _, piece in plaza:GetChildren() do
	if piece:IsA("BasePart") and piece.Size.X == 116 and piece.Size.Z == 116 then
		paving = piece
	end
end
assert(paving, "Plaza paving was not built")
local plazaFrame = paving.CFrame * CFrame.new(0, paving.Size.Y / 2, 0)
local function avatarAt(frame)
	return { Size = Vector3.new(3, 5.5, 3), CFrame = frame }
end
local function solids(model)
	local list = {}
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") and piece.CanCollide then
			table.insert(list, piece)
		end
	end
	return list
end
local function walk(route, frame, obstacles, label)
	for segment = 1, #route - 1 do
		local a, b = route[segment], route[segment + 1]
		local steps = math.ceil((b - a).Magnitude / 0.5)
		for step = 0, steps do
			local avatar = avatarAt(frame * CFrame.new(a:Lerp(b, step / steps)))
			for _, obstacle in obstacles do
				check(not overlaps(avatar, obstacle), label .. " blocked by " .. obstacle:GetFullName())
			end
		end
	end
end

-- The storefront on the square: a door that leads in, and no purchase volume of its own
local rodShop = plaza:FindFirstChild("FishingRodShop")
check(rodShop ~= nil, "Plaza lacks its rod store")
check(not CollectionService:HasTag(rodShop, "FishingRodShop"), "The storefront must not carry the purchase tag")
local streetDoor = rodShop:FindFirstChild("StreetDoor", true)
local enter = streetDoor and streetDoor:FindFirstChild("RodStoreDoorPrompt")
check(enter and enter:IsA("ProximityPrompt") and enter.ActionText == "Enter", "Street door lacks its Enter prompt")

-- The hall away from the map carries the purchase volume, counter and exit
local interiors = workspace:FindFirstChild("Interiors")
local hall = interiors and interiors:FindFirstChild("RodStoreInterior")
check(hall and CollectionService:HasTag(hall, "FishingRodShop"), "Rod store interior is missing or untagged")
check(hall:GetAttribute("Price") == 0 and hall:GetAttribute("RodId") == "StarterRod", "Starter rod must be free")
local arrival = hall:GetAttribute("ArrivalFrame")
local interiorFrame, interiorSize = hall:GetAttribute("InteriorFrame"), hall:GetAttribute("InteriorSize")
check(typeof(arrival) == "CFrame" and typeof(interiorFrame) == "CFrame", "Interior frames missing")
check(
	(enter:GetAttribute("TeleportTo").Position - arrival.Position).Magnitude < EPS,
	"Street door does not lead to the hall's arrival point"
)
local function insideHall(p)
	local q = interiorFrame:PointToObjectSpace(p)
	return math.abs(q.X) < interiorSize.X / 2
		and math.abs(q.Y) < interiorSize.Y / 2
		and math.abs(q.Z) < interiorSize.Z / 2
end
check(insideHall(arrival.Position), "Arrival point is outside the purchase volume")
check(
	(arrival.Position - Vector3.new(0, arrival.Position.Y, 0)).Magnitude > 5200 + 500,
	"Interior must stand well beyond the map's edge"
)
check(arrival.LookVector:Dot(interiorFrame.ZVector) > 0.99, "Arrival must face into the hall")
local exitDoor = hall:FindFirstChild("ExitDoor", true)
local leave = exitDoor and exitDoor:FindFirstChild("RodStoreDoorPrompt")
local exitFrame = rodShop:GetAttribute("ExitFrame")
check(leave and leave.ActionText == "Leave", "Hall exit lacks its Leave prompt")
check(
	typeof(exitFrame) == "CFrame" and (leave:GetAttribute("TeleportTo").Position - exitFrame.Position).Magnitude < EPS,
	"Hall exit does not lead back to the street door"
)
check(
	(exitFrame.Position - streetDoor.Position).Magnitude < enter.MaxActivationDistance,
	"Leaving should set the angler down by the street door"
)
check(
	(arrival.Position - exitDoor.Position).Magnitude < leave.MaxActivationDistance,
	"The exit prompt should be reachable from the arrival point"
)

-- Nothing solid where either teleport sets an avatar down, nor on the way to the counter
local hallSolids = solids(hall)
local plazaSolids = solids(plaza)
for _, obstacle in plazaSolids do
	check(not overlaps(avatarAt(exitFrame), obstacle), "Exit point lands inside " .. obstacle:GetFullName())
end
local buyRod = hall:FindFirstChild("BuyFishingRodPrompt", true)
check(buyRod and buyRod.Parent.Name == "CounterTop", "Rod browse prompt must be on the indoor counter")
local counter = buyRod.Parent
local hallFrame = interiorFrame * CFrame.new(0, -interiorSize.Y / 2, 0)
local counterLocal = hallFrame:PointToObjectSpace(counter.Position)
local customerZ = counterLocal.Z - counter.Size.Z / 2 - 2
walk(
	{ hallFrame:PointToObjectSpace(arrival.Position), Vector3.new(0, 3.3, customerZ) },
	hallFrame,
	hallSolids,
	"Aisle to counter"
)
check(insideHall(hallFrame * Vector3.new(0, 3.3, customerZ)), "Counter customer is outside the purchase volume")
check(
	((hallFrame * Vector3.new(0, 3.3, customerZ)) - counter.Position).Magnitude < buyRod.MaxActivationDistance,
	"Browse prompt is out of reach from the customer side"
)
-- Plaza approach: from the square up to the street door
local doorLocal = plazaFrame:PointToObjectSpace(exitFrame.Position)
walk(
	{ Vector3.new(-15, 3.4, doorLocal.Z), Vector3.new(doorLocal.X, 3.4, doorLocal.Z) },
	plazaFrame,
	plazaSolids,
	"Plaza route to rod store"
)

-- Reproduce the server's eye-to-prompt ray against the actual part boxes.
local function segmentHit(a, b, obstacle)
	local origin = obstacle.CFrame:PointToObjectSpace(a)
	local delta = obstacle.CFrame:VectorToObjectSpace(b - a)
	local near, far = 0, 1
	for _, axis in { "X", "Y", "Z" } do
		local half = obstacle.Size[axis] / 2
		if math.abs(delta[axis]) < EPS then
			if math.abs(origin[axis]) > half then
				return nil
			end
		else
			local low = (-half - origin[axis]) / delta[axis]
			local high = (half - origin[axis]) / delta[axis]
			near = math.max(near, math.min(low, high))
			far = math.min(far, math.max(low, high))
			if near > far then
				return nil
			end
		end
	end
	return near
end
for _, x in { -3, 0, 3 } do
	local eye = hallFrame * Vector3.new(x, 5.2, customerZ)
	local counterHit = segmentHit(eye, counter.Position, counter)
	check(counterHit ~= nil, "Browse eye ray does not reach its counter")
	for _, obstacle in hall:GetDescendants() do
		if obstacle:IsA("BasePart") and obstacle ~= counter and obstacle.CanQuery ~= false then
			local hit = segmentHit(eye, counter.Position, obstacle)
			check(not hit or hit >= counterHit - EPS, "Browse ray from x=" .. x .. " is blocked by " .. obstacle.Name)
		end
	end
end

-- Stairs climb in walkable steps to the gallery deck
local stairs = {}
for _, piece in hall:GetChildren() do
	if piece:IsA("BasePart") and piece.Name == "Stair" then
		table.insert(stairs, hallFrame:PointToObjectSpace(piece.Position).Y * 2)
	end
end
table.sort(stairs)
check(#stairs >= 10, "Gallery stairs are missing")
for i, top in stairs do
	check(top - (stairs[i - 1] or 0) <= 1 + EPS, "Stair step " .. i .. " is too tall to walk up")
end
check(math.abs(stairs[#stairs] - 12) < EPS, "Stairs must arrive level with the gallery deck")

-- Terraces round the square: plots on streets stay empty, generated houses are cleared away
local houses = Instance.new("Model")
houses.Name, houses.Parent = "Houses", village
local doomed = Instance.new("Model")
doomed.Name, doomed.Parent = "Townhouse", houses
local doomedWall = Instance.new("Part")
doomedWall.Size, doomedWall.CFrame, doomedWall.Parent =
	Vector3.new(10, 10, 10), plazaFrame * CFrame.new(-72, 4, -30), doomed
local spared = Instance.new("Model")
spared.Name, spared.Parent = "Townhouse", houses
local sparedWall = Instance.new("Part")
sparedWall.Size, sparedWall.CFrame, sparedWall.Parent =
	Vector3.new(10, 10, 10), plazaFrame * CFrame.new(-120, 4, -30), spared
local road = Instance.new("Model")
road.Name, road.Parent = "Road", village
local street = Instance.new("Part")
street.Size, street.CFrame, street.Parent = Vector3.new(30, 1, 16), plazaFrame * CFrame.new(72, -0.6, 10), road
local terraces = dependencies.PlazaHouses.build(plaza, plazaFrame)
local built = {}
for _, house in terraces:GetChildren() do
	table.insert(built, house)
end
check(#built >= 14, "Too few terrace houses round the square: " .. #built)
check(doomed.Parent == nil, "A generated house on a terrace plot was not cleared")
check(spared.Parent == houses, "A generated house clear of the terraces was removed")
for _, house in built do
	for _, piece in house:GetDescendants() do
		if piece:IsA("BasePart") and piece.CanCollide then
			check(not overlaps(piece, street), house.Name .. " was built across a street")
			check(not overlaps(piece, paving), house.Name .. " intrudes on the paving")
		end
	end
end
local afterTerraces = #plaza:GetDescendants()
check(dependencies.PlazaHouses.build(plaza, plazaFrame) == terraces, "Terrace build is not idempotent")
check(#plaza:GetDescendants() == afterTerraces, "Terrace rebuild duplicated parts")

-- Harbour Home, the furniture shop across the fountain: a tagged counter, nothing built into it,
-- and room to stand at the counter
local furnitureShop = plaza:FindFirstChild("FurnitureShop")
check(furnitureShop ~= nil, "Plaza lacks its furniture shop")
local counterTop = furnitureShop and furnitureShop:FindFirstChild("CounterTop")
check(counterTop and CollectionService:HasTag(counterTop, "FurnitureShop"), "Furniture counter is untagged")
local browse = counterTop and counterTop:FindFirstChild("BrowseFurniturePrompt")
check(browse and browse:IsA("ProximityPrompt"), "Furniture counter lacks its browse prompt")
local shopSolids = solids(furnitureShop)
for _, piece in plaza:GetDescendants() do
	-- Paving, kerbs and inlays are flat slabs the shop stands on.
	if piece:IsA("BasePart") and piece.CanCollide and not piece:IsDescendantOf(furnitureShop) and piece.Size.Y > 1 then
		for _, own in shopSolids do
			check(not overlaps(own, piece), "Furniture shop collides with " .. piece:GetFullName())
		end
	end
end
local keeperFrame = furnitureShop:GetAttribute("KeeperFrame")
local customerSpot = keeperFrame * CFrame.new(0, 2.9, -dependencies.ShopDesk.DEPTH - 2.9)
local obstacles = {}
for _, piece in plaza:GetDescendants() do
	if piece:IsA("BasePart") and piece.CanCollide and piece.Size.Y > 1 then
		table.insert(obstacles, piece)
	end
end
walk({ Vector3.new(0, 0, 0), Vector3.new(0, 0, -8) }, customerSpot, obstacles, "Furniture counter approach")
local afterFurniture = #plaza:GetDescendants()
check(dependencies.FurnitureShop.build(plaza, plazaFrame) == furnitureShop, "Furniture shop build is not idempotent")
check(#plaza:GetDescendants() == afterFurniture, "Furniture shop rebuild duplicated parts")

for _, width in { 116, 120 } do
	local saved = Instance.new("Folder")
	local savedPlaza = Instance.new("Model")
	savedPlaza.Name, savedPlaza.Parent = "Plaza", saved
	local savedFloor = Instance.new("Part")
	savedFloor.Size, savedFloor.CFrame, savedFloor.Parent =
		Vector3.new(width, 0.6, width), CFrame.new(112, 8.5, -92) * CFrame.Angles(0, 0.72, 0), savedPlaza
	local unrelated = Instance.new("Part")
	unrelated.Name, unrelated.Parent = "UnrelatedPlazaDecoration", savedPlaza
	dependencies.RodShop.ensure(saved)
	local result = savedPlaza:FindFirstChild("FishingRodShop")
	check(result ~= nil, "Saved plaza " .. width .. " did not receive its rod store")
	local expected = savedFloor.CFrame * CFrame.new(0, 0.3, 0) * CFrame.new(-45, 0, 35)
	local exitAt = savedFloor.CFrame:PointToObjectSpace(result:GetAttribute("ExitFrame").Position)
	local wanted = savedFloor.CFrame:PointToObjectSpace(expected.Position)
	check(
		math.abs(exitAt.Z - wanted.Z) < 12 and exitAt.X > wanted.X,
		"Saved rod store ignored paving position or rotation"
	)
	local afterRodEnsure = #saved:GetDescendants()
	local hallBefore = workspace:FindFirstChild("Interiors"):FindFirstChild("RodStoreInterior")
	dependencies.RodShop.ensure(saved)
	check(
		savedPlaza:FindFirstChild("FishingRodShop") == result and #saved:GetDescendants() == afterRodEnsure,
		"Rod store saved-map upgrade is not idempotent"
	)
	check(
		workspace:FindFirstChild("Interiors"):FindFirstChild("RodStoreInterior") == hallBefore,
		"Rod store interior was rebuilt needlessly"
	)
	check(unrelated.Parent == savedPlaza, "Rod store upgrade removed an unrelated plaza decoration")
	dependencies.FurnitureShop.ensure(saved)
	local savedFurniture = savedPlaza:FindFirstChild("FurnitureShop")
	check(savedFurniture ~= nil, "Saved plaza " .. width .. " did not receive its furniture shop")
	local afterFurnitureEnsure = #saved:GetDescendants()
	dependencies.FurnitureShop.ensure(saved)
	check(#saved:GetDescendants() == afterFurnitureEnsure, "Furniture shop saved-map upgrade is not idempotent")

	result:SetAttribute("LayoutVersion", 0)
	dependencies.RodShop.ensure(saved)
	local upgraded = savedPlaza:FindFirstChild("FishingRodShop")
	check(result.Parent == nil and upgraded ~= result, "Stale rod store layout did not upgrade")
	local relinked = hallBefore:FindFirstChild("ExitDoor", true):FindFirstChild("RodStoreDoorPrompt")
	check(
		(relinked:GetAttribute("TeleportTo").Position - upgraded:GetAttribute("ExitFrame").Position).Magnitude < EPS,
		"Hall exit was not relinked to the rebuilt storefront"
	)
end
assert(failures == 0, tostring(failures) .. " rod store geometry checks failed")
print(
	string.format(
		"PASS: %d rod store geometry assertions; street door and hall exit teleports, clear landing spots, aisle and counter sightlines, walkable gallery stairs, plaza terraces clearing houses but not streets, saved-map upgrades and idempotency. Recording mocks do not verify live Roblox rendering or physics.",
		checks
	)
)
