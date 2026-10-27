-- MOCKS --
local create = Instance.new
Instance.new = function(class)
	local item = create(class)
	-- Roblox defaults omitted by the shared recording mocks.
	if class == "Part" then
		item.Shape = Enum.PartType.Block
	end
	return item
end
local function loadLowPoly()
	-- LowPoly --
end
dependencies.LowPoly = loadLowPoly()
local function loadProps()
	-- Props --
end
local Props = loadProps()
dependencies.Props = Props
local function loadMed()
	-- Mediterranean --
end
local Med = loadMed()
dependencies.Mediterranean = Med
local function loadPlaza()
	-- PlazaHouses --
end
local Plaza = loadPlaza()

local checks, before, after, houses = 0, 0, 0, 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local simplify = Props.simplifyHouseCollision
local function count(house)
	local total = 0
	for _, piece in house:GetDescendants() do
		if piece:IsA("BasePart") and piece.CanCollide then
			total += 1
		end
	end
	return total
end
Props.simplifyHouseCollision = function(house)
	local previous, geometry = count(house), {}
	for _, piece in house:GetDescendants() do
		if piece:IsA("BasePart") then
			geometry[piece] = { piece.CFrame, piece.Size, piece.Transparency, piece.CanCollide }
		end
	end
	simplify(house)
	local current = count(house)
	check(current < previous, "House collision count did not decrease: " .. house.Name)
	for piece, original in geometry do
		check(
			piece.CFrame == original[1] and piece.Size == original[2] and piece.Transparency == original[3],
			"Visible house geometry changed"
		)
		if original[4] and not piece.CanCollide then
			check(not piece.CanTouch and not piece.CanQuery, "Removed collider still receives touch/query work")
		end
	end
	simplify(house)
	check(count(house) == current, "Repeated simplification changes the house")
	before += previous
	after += current
	houses += 1
end

local root = Instance.new("Model")
for seed = 1, 12 do
	local rng = Random.new(seed)
	local frame = CFrame.new(seed * 60, 4, -38) * CFrame.Angles(0, seed * 0.37, 0)
	Props.house(
		root,
		frame.Position,
		seed * 0.37,
		rng,
		Color3.new(1, 1, 1),
		Color3.new(1, 0, 0),
		if seed % 2 == 0 then 6 else nil
	)
	Med.cubeHouse(root, frame.Position, seed * 0.37, rng)
	Med.townhouse(root, frame.Position, seed * 0.37, rng)
	Med.villa(root, frame.Position, seed * 0.37, rng)
	Plaza.house(root, frame, Plaza.spec(rng, 24, 20, 2 + seed % 2), rng)
end
check(after < before * 0.75, "Scenery collision reduction is less than 25 percent")

-- Simulate a baked map: the builder has not yet run the new policy. Include
-- renamed shop exteriors and nested streaming pieces, and leave other props alone.
Props.simplifyHouseCollision = function() end
local baked = Instance.new("Model")
local house = Med.townhouse(baked, Vector3.zero, 0.6, Random.new(51))
house.Name = "FishingRodShop"
local nested = Instance.new("Model")
nested.Parent = house
for _, piece in house:GetChildren() do
	if piece:IsA("BasePart") then
		piece.Parent = nested
	end
end
local tree = Instance.new("Part")
tree.Parent = baked
local previous = count(house)
Props.simplifyHouseCollision = simplify
Props.ensureHouseCollision(baked)
check(
	count(house) < previous and tree.CanCollide,
	"Baked migration missed nested house parts or changed unrelated props"
)
local current = count(house)
Props.ensureHouseCollision(baked)
check(count(house) == current, "Saved migration is not idempotent")

-- A hollow building has no qualifying solid core. Its doorway gap and thin
-- walls/floor must survive; an outside stair and roof must also remain solid.
local hollow = Instance.new("Model")
hollow.Name, hollow.Parent = "House", baked
local walls = {}
for _, x in { -4, 4 } do
	local wall = Props.part(hollow, Vector3.new(4, 10, 0.6), CFrame.new(x, 5, 8), Color3.new())
	table.insert(walls, wall)
end
local floor = Props.part(hollow, Vector3.new(16, 0.2, 16), CFrame.new(), Color3.new())
simplify(hollow)
check(floor.CanCollide and walls[1].CanCollide and walls[2].CanCollide, "Hollow building surfaces were removed")
local solid = Instance.new("Model")
local core = Props.part(solid, Vector3.new(16, 20, 16), CFrame.new(0, 10, 0), Color3.new())
local step = Props.part(solid, Vector3.new(2.8, 8, 1), CFrame.new(10, 4, 0), Color3.new())
local roof = Props.part(solid, Vector3.new(18, 0.7, 10), CFrame.new(0, 23, 4) * CFrame.Angles(0.4, 0, 0), Color3.new())
local protruding = Props.part(solid, Vector3.new(8, 1, 8), CFrame.new(7, 9, 7) * CFrame.Angles(0, 0.7, 0), Color3.new())
simplify(solid)
check(
	core.CanCollide and step.CanCollide and roof.CanCollide and protruding.CanCollide,
	"Core, exterior stair, roof or protruding geometry lost collision"
)

-- A fresh balcony keeps exactly one hitbox over slab and ironwork, and a fresh
-- pergola one roof box over its trellis with no hitbox on the vines.
local balconyModel = Instance.new("Model")
local face = CFrame.new(240, 8, 120) * CFrame.Angles(0, 0.6, 0)
Med.balcony(balconyModel, face, 9, 2.4, Color3.new(1, 1, 1))
local balconyHitbox = balconyModel:FindFirstChild("BalconyHitbox")
check(
	balconyHitbox ~= nil and balconyHitbox.CanCollide and balconyHitbox.Transparency == 1,
	"Fresh balcony hitbox is missing or visible"
)
check(
	math.abs(balconyHitbox.Size.X - 9) < 0.001
		and math.abs(balconyHitbox.Size.Y - 3.2) < 0.001
		and math.abs(balconyHitbox.Size.Z - 2.4) < 0.001,
	"Fresh balcony hitbox does not cover slab and railing"
)
local balconySolids = 0
for _, piece in balconyModel:GetDescendants() do
	if piece:IsA("BasePart") and piece.CanCollide then
		balconySolids += 1
	end
end
check(balconySolids == 1, "Fresh balcony carries " .. balconySolids .. " colliders instead of one")

local trellis = Med.pergola(balconyModel, Vector3.new(240, 0, 140), 0.6, Random.new(3), 12, 8, 9)
local roofBox = trellis:FindFirstChild("PergolaHitbox")
check(
	roofBox ~= nil and roofBox.CanCollide and math.abs(roofBox.Size.Y - 1.1) < 0.001,
	"Pergola trellis is not one roof box"
)
local trellisSolids, trellisPosts = 0, 0
for _, piece in trellis:GetDescendants() do
	if piece:IsA("BasePart") and piece.Material == Enum.Material.Wood then
		check(not piece.CanCollide, "Pergola timber keeps its own colliders")
	end
	if
		piece:IsA("BasePart")
		and (piece.Material == Enum.Material.LeafyGrass or (piece:IsA("Part") and piece.Shape == Enum.PartType.Ball))
	then
		check(not piece.CanCollide and not piece.CanQuery, "Pergola greenery has a hitbox")
	end
	if piece:IsA("BasePart") and piece.CanCollide then
		trellisSolids += 1
		if piece.Material == Enum.Material.Plaster then
			trellisPosts += 1
		end
	end
end
check(trellisPosts > 0 and trellisSolids == trellisPosts + 1, "Pergola is not posts plus one roof box")

-- A balcony and a pergola baked before these policies: loose colliders with the
-- builders' exact shapes. The door step below the balcony must stay solid.
local legacy = Instance.new("Model")
legacy.Name, legacy.Parent = "Townhouse", root
local oldFace = CFrame.new(300, 10, -200) * CFrame.Angles(0, 1.1, 0)
local function iron(size, at, material)
	return Props.part(legacy, size, oldFace * at, Color3.new(1, 1, 1), material or Enum.Material.Metal)
end
local oldSlab = iron(Vector3.new(9, 0.5, 2.4), CFrame.new(0, -0.25, 1.2), Enum.Material.Plaster)
for i = 0, 6 do
	iron(Vector3.new(0.14, 2.6, 0.14), CFrame.new(-4.3 + 8.6 * i / 6, 1.3, 2.2))
end
iron(Vector3.new(8.8, 0.2, 0.22), CFrame.new(0, 2.6, 2.2))
for side = -1, 1, 2 do
	iron(Vector3.new(0.2, 0.2, 2.2), CFrame.new(side * 4.4, 2.6, 1.2))
end
local oldStep = iron(Vector3.new(5.2, 0.5, 1.8), CFrame.new(0, 0.25, 0.9), Enum.Material.Limestone)

local legacyPergola = Instance.new("Model")
legacyPergola.Name, legacyPergola.Parent = "Pergola", root
local oldBase = CFrame.new(320, 0, -200) * CFrame.Angles(0, 0.4, 0)
for _, corner in { Vector3.new(-7, 4.5, -5), Vector3.new(7, 4.5, -5), Vector3.new(-7, 4.5, 5), Vector3.new(7, 4.5, 5) } do
	Props.part(legacyPergola, Vector3.new(1.1, 9, 1.1), oldBase * CFrame.new(corner), Color3.new(1, 1, 1), Enum.Material.Plaster)
end
for _, z in { -5, 5 } do
	Props.part(legacyPergola, Vector3.new(16, 0.7, 0.7), oldBase * CFrame.new(0, 9.35, z), Color3.new(1, 1, 1), Enum.Material.Wood)
end
for i = 0, 3 do
	Props.part(legacyPergola, Vector3.new(0.4, 0.4, 12), oldBase * CFrame.new(-7 + 14 * i / 3, 9.9, 0), Color3.new(1, 1, 1), Enum.Material.Wood)
end
Props.blob(
	legacyPergola,
	(oldBase * CFrame.new(0, 11, 0)).Position,
	Vector3.new(2.5, 1.5, 2.5),
	Random.new(4),
	Color3.new(0, 1, 0),
	Enum.Material.LeafyGrass
)
Props.ball(
	legacyPergola,
	(oldBase * CFrame.new(1, 10, 1)).Position,
	0.8,
	Color3.new(0.5, 0, 0.5),
	Enum.Material.SmoothPlastic
)

local slabGeometry = { oldSlab.CFrame, oldSlab.Size }
Med.ensureBalconies(root)
Med.ensurePergolas(root)
local migrated = legacy:FindFirstChild("BalconyHitbox")
check(
	migrated ~= nil and migrated.CanCollide and math.abs(migrated.Size.Y - 3.2) < 0.001,
	"Baked balcony did not collapse to one hitbox"
)
check(oldStep.CanCollide, "Baked balcony migration swallowed the door step")
check(
	oldSlab.CFrame == slabGeometry[1] and oldSlab.Size == slabGeometry[2],
	"Baked balcony migration changed visible geometry"
)
local legacySolids = 0
for _, piece in legacy:GetDescendants() do
	if piece:IsA("BasePart") and piece.CanCollide then
		legacySolids += 1
	end
end
check(legacySolids == 2, "Baked balcony keeps " .. legacySolids .. " colliders instead of hitbox plus step")

local oldRoof = legacyPergola:FindFirstChild("PergolaHitbox")
check(
	oldRoof ~= nil and oldRoof.CanCollide and math.abs(oldRoof.Size.X - 16) < 0.001,
	"Baked pergola trellis did not collapse to one roof box"
)
local legacyPergolaSolids = 0
for _, piece in legacyPergola:GetDescendants() do
	if piece:IsA("BasePart") and piece.CanCollide then
		legacyPergolaSolids += 1
	end
end
check(legacyPergolaSolids == 5, "Baked pergola keeps " .. legacyPergolaSolids .. " colliders instead of posts plus roof box")

Med.ensureBalconies(root)
Med.ensurePergolas(root)
local rerun = 0
for _, model in { legacy, legacyPergola } do
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") and piece.CanCollide then
			rerun += 1
		end
	end
end
check(rerun == legacySolids + legacyPergolaSolids, "Saved hitbox migration is not idempotent")

print(
	string.format(
		"PASS: %d house collision assertions; %d scenery houses: %d -> %d colliders (%.1f%% fewer). Live Roblox physics are not exercised.",
		checks,
		houses,
		before,
		after,
		(1 - after / before) * 100
	)
)
