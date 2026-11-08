-- Decoration and tiny-detail collision policy (Props.simplifyDecorationCollision /
-- ensureDecorationCollision) against recording mocks. Run: node scripts/check-decoration-collision.cjs
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

local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local function colliders(model)
	local n, total = 0, 0
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") then
			total += 1
			if piece.CanCollide then
				n += 1
			end
		end
	end
	return n, total
end

-- Fresh builds: trees keep their trunk only, plants and lights keep nothing.
local root = Instance.new("Model")
local before, after = 0, 0
local leaves = { Color3.new(0, 1, 0) }
for seed = 1, 20 do
	local rng = Random.new(seed)
	local at = Vector3.new(seed * 30, 0, 0)
	for _, tree in {
		Props.broadleaf(root, at, rng, leaves),
		Props.palm(root, at, rng),
		Props.pine(root, at, rng, Color3.new(0, 1, 0)),
		Props.deadTree(root, at, rng, Color3.new()),
		Props.mangrove(root, at, rng, -6, Color3.new(), leaves),
		Med.olive(root, at, rng),
		Med.stonePine(root, at, rng),
	} do
		local n, total = colliders(tree)
		before += total
		after += n
		check(n >= 1, tree.Name .. " lost its trunk")
		for _, piece in tree:GetDescendants() do
			if piece:IsA("BasePart") and piece.CanCollide then
				check(piece.Material == Enum.Material.Wood, tree.Name .. " kept a non-wood collider")
				check(piece.CanQuery ~= false, tree.Name .. " trunk not queryable")
			elseif piece:IsA("BasePart") then
				check(not piece.CanQuery and not piece.CanTouch, tree.Name .. " leaf still queryable")
			end
		end
	end
	for _, plant in {
		Props.reeds(root, at, rng),
		Props.lilyPad(root, at, rng),
		Props.coral(root, at, rng, leaves),
		Props.seaweed(root, at, rng),
		Props.lantern(root, CFrame.new(at)),
		Props.stringLights(root, at, at + Vector3.new(20, 0, 0), rng),
		Med.lavender(root, at, rng),
		Med.bougainvillea(root, CFrame.new(at), rng, 6),
	} do
		local n, total = colliders(plant)
		before += total
		after += n
		check(n == 0, plant.Name .. " kept a collider")
	end
	local pot = Med.pot(root, at, rng, "lemon")
	local n, total = colliders(pot)
	before += total
	after += n
	check(n == 2, "pot should keep exactly its two terracotta cylinders, got " .. n)
end

-- Baked map: models predating the policy are migrated by ensureDecorationCollision,
-- tiny details lose hitbox and shadow, protected areas and functional parts stay intact.
local baked = Instance.new("Model")
local function bakedTree()
	local m = Instance.new("Model")
	m.Name = "Tree"
	m.Parent = baked
	local trunk = Props.part(m, Vector3.new(1.4, 1.4, 9), CFrame.new(), Color3.new(), Enum.Material.Wood)
	local canopy = Props.part(m, Vector3.new(6, 5, 6), CFrame.new(0, 9, 0), Color3.new(), Enum.Material.LeafyGrass)
	return m, trunk, canopy
end
local tree, trunk, canopy = bakedTree()
local bolt = Props.part(baked, Vector3.new(0.3, 0.3, 0.3), CFrame.new(5, 0, 0), Color3.new())
local plank = Props.part(baked, Vector3.new(0.3, 0.3, 4), CFrame.new(6, 0, 0), Color3.new())
local hidden = Props.part(baked, Vector3.new(0.3, 0.3, 0.3), CFrame.new(7, 0, 0), Color3.new())
hidden.Transparency = 1
local loose = Props.part(baked, Vector3.new(0.3, 0.3, 0.3), CFrame.new(8, 0, 0), Color3.new())
loose.Anchored = false
local prompted = Props.part(baked, Vector3.new(0.3, 0.3, 0.3), CFrame.new(9, 0, 0), Color3.new())
local prompt = Instance.new("ProximityPrompt")
prompt.Parent = prompted
local base = Instance.new("Model")
base.Name = "Base1"
base.Parent = baked
local tagged = { PlayerBase = { base } }
local realGame = game
game = setmetatable({ GetService = function(self, name)
	if name == "CollectionService" then
		return { GetTagged = function(_, tag) return tagged[tag] or {} end }
	end
	return realGame:GetService(name)
end }, { __index = realGame })
local function descends(item, ancestor)
	local at = item.Parent
	while at do
		if at == ancestor then return true end
		at = at.Parent
	end
	return false
end
local knob = Props.part(base, Vector3.new(0.3, 0.3, 0.3), CFrame.new(10, 0, 0), Color3.new())
local baseTree = Instance.new("Model")
baseTree.Name = "Tree"
baseTree.Parent = base
local baseCanopy = Props.part(baseTree, Vector3.new(6, 5, 6), CFrame.new(0, 9, 0), Color3.new(), Enum.Material.LeafyGrass)

for _, piece in baked:GetDescendants() do
	if piece:IsA("BasePart") then
		piece.CanCollide, piece.CanQuery, piece.CastShadow = true, true, true
	end
end
local resumed = 0
Props.ensureDecorationCollision(baked, function()
	resumed += 1
end)
check(resumed > 0, "pause was never called")
check(trunk.CanCollide and not canopy.CanCollide and not canopy.CanQuery, "baked tree not migrated")
check(tree:GetAttribute("DecorationCollisionVersion") == 2, "baked tree not versioned")
check(not bolt.CanCollide and not bolt.CanQuery and not bolt.CastShadow, "tiny bolt kept hitbox/shadow")
check(plank.CanCollide and plank.CastShadow, "long thin plank lost collision")
check(hidden.CanCollide, "invisible helper part was changed")
check(loose.CanCollide, "unanchored part was changed")
check(prompted.CanCollide and prompted.CanQuery, "prompt holder was changed")
check(knob.CanCollide and knob.CastShadow, "part inside a player base was changed")
check(baseCanopy.CanCollide, "tree inside a player base was changed")
Props.ensureDecorationCollision(baked)
check(trunk.CanCollide and plank.CanCollide, "second pass changed kept colliders")
print(string.format("PASS: %d decoration collision checks; built decorations %d -> %d colliders. Live physics not exercised.", checks, before, after))
