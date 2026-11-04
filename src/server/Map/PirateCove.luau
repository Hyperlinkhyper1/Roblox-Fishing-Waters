-- Pirate Cove: a low tropical island in the Coral Shallows with a rocky headland, a long pier
-- pointing home towards Gullhaven, a little town round a flag-pole plaza (galley stall, rod stall,
-- tavern and shacks), cannons on the bluff and a wreck in the shallows. Built like the city: one
-- model straight under the map, versioned and rebuilt when VERSION changes, with its own seeded
-- RNG so the rest of the seeded archipelago is untouched. Island-local coordinates have north at -Z.
-- The crew who stand here are spawned by PirateCoveService at the anchors this sets.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Data = require(ReplicatedStorage.Shared.PirateCove)
local Islands = require(script.Parent.Islands)
local Lod = require(script.Parent.Lod)
local Props = require(script.Parent.Props)

local Cove = {}
Cove.VERSION = 1

local TAU = math.pi * 2
local rgb = Color3.fromRGB
local M = Enum.Material
local part, beam, cylinder = Props.part, Props.beam, Props.cylinder

local CENTER = Vector3.new(Data.CENTER[1], 0, Data.CENTER[2])
local HEIGHT = 12
local PIER_LENGTH = 72
-- Anything else on the map this close to CENTER (plus its own radius) is cleared for the cove.
local CLEARANCE = 270

local PALETTE = {
	top = rgb(98, 160, 70),
	cliff = rgb(182, 160, 120),
	shore = rgb(240, 226, 186),
	materials = { top = M.LeafyGrass, cliff = M.Sandstone, shore = M.Sand },
}
local ROCK = {
	top = rgb(142, 132, 112),
	cliff = rgb(122, 114, 100),
	shore = rgb(214, 200, 166),
	materials = { top = M.Rock, cliff = M.Rock, shore = M.Sand },
}
local WOOD = rgb(122, 88, 58)
local WOOD_DARK = rgb(70, 50, 36)
local IRON = rgb(44, 42, 42)
local SAIL = rgb(214, 200, 168)
local WALLS = { rgb(168, 128, 86), rgb(150, 112, 76), rgb(186, 150, 104), rgb(120, 140, 120) }
local THATCH = rgb(204, 172, 106)
local CANOPIES = { rgb(170, 40, 40), rgb(30, 70, 120), rgb(40, 110, 80) }

local function world(x: number, z: number): Vector3
	return CENTER + Vector3.new(x, 0, z)
end

-- Angle that turns a builder's local +Z (its front) from `from` towards `to`.
local function facing(from: Vector3, to: Vector3): number
	local d = to - from
	return math.atan2(d.X, d.Z)
end

local function newModel(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

----------------------------------------------------------------------------------------------------
-- Clearing the site

-- The seeded archipelago knows nothing of the cove, so any scenery island, rock or coral that landed
-- here is removed, along with its distant shell.
local function clearSite(root: Instance)
	local shells = root:FindFirstChild("Lod")
	local centre = Vector2.new(CENTER.X, CENTER.Z)
	for _, folder in root:GetChildren() do
		if not folder:IsA("Folder") then
			continue
		end
		for _, child in folder:GetChildren() do
			if not child:IsA("Model") or child.Name == "Harbour Isle" then
				continue
			end
			local pivot = child:GetPivot().Position
			local reach = CLEARANCE + (tonumber(child:GetAttribute("Radius")) or 0) * 1.35
			if (Vector2.new(pivot.X, pivot.Z) - centre).Magnitude < reach then
				local id = child:GetAttribute("LodId")
				local shell = if shells and id ~= nil then shells:FindFirstChild(tostring(id)) else nil
				if shell then
					shell:Destroy()
				end
				child:Destroy()
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Set pieces

-- A black flag on a tall mast with a bone-white skull and crossed bones on both faces.
local function jollyRoger(parent: Instance, ground: Vector3)
	local m = newModel("PirateFlag", parent)
	cylinder(m, ground + Vector3.new(0, 12, 0), 24, 0.7, WOOD_DARK, M.Wood)
	Props.ball(m, ground + Vector3.new(0, 24.3, 0), 1, rgb(200, 170, 80), M.Metal)
	local cloth = CFrame.new(ground + Vector3.new(0, 20.6, 4.2))
	part(m, Vector3.new(0.2, 5, 8), cloth, rgb(20, 20, 22), M.Fabric)
	local bone = rgb(236, 232, 220)
	for _, side in { -1, 1 } do
		local face = cloth * CFrame.new(side * 0.14, 0, 0)
		part(m, Vector3.new(0.06, 1.6, 1.8), face * CFrame.new(0, 0.6, 0), bone, M.SmoothPlastic)
		part(m, Vector3.new(0.06, 0.7, 1.1), face * CFrame.new(0, -0.35, 0), bone, M.SmoothPlastic)
		for _, tilt in { -0.7, 0.7 } do
			part(
				m,
				Vector3.new(0.05, 0.35, 4),
				face * CFrame.new(0, -1.3, 0) * CFrame.Angles(tilt, 0, 0),
				bone,
				M.SmoothPlastic
			)
		end
		for _, x in { -0.4, 0.4 } do
			part(
				m,
				Vector3.new(0.08, 0.36, 0.36),
				face * CFrame.new(side * 0.02, 0.75, x),
				rgb(20, 20, 22),
				M.SmoothPlastic
			)
		end
	end
	-- Mast steps and a coil of halyard at the foot.
	cylinder(m, ground + Vector3.new(0, 0.4, 0), 0.8, 3.2, WOOD, M.WoodPlanks)
	Props.ropeCoil(m, ground + Vector3.new(1.8, 0, 0.8))
end

-- Counter, striped canopy and a rack of rods; the trader stands behind the counter, customers at +Z.
local function rodStall(parent: Instance, ground: Vector3, face: number, rng: Random): Model
	local m = newModel("RodStall", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, face, 0)
	part(m, Vector3.new(9, 3, 3), base * CFrame.new(0, 1.5, 1.5), WOOD, M.WoodPlanks)
	part(m, Vector3.new(9.4, 0.3, 3.4), base * CFrame.new(0, 3.1, 1.5), WOOD_DARK, M.Wood)
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		part(m, Vector3.new(0.5, 8, 0.5), base * CFrame.new(c[1] * 4.3, 4, c[2] * 2.5 + 0.5), WOOD_DARK, M.Wood)
	end
	local canopy = rgb(30, 30, 34)
	for i = 0, 4 do
		local stripe = if i % 2 == 0 then canopy else rgb(200, 40, 40)
		part(
			m,
			Vector3.new(2, 0.3, 7),
			base * CFrame.new(-4 + i * 2, 8.2, 0.5) * CFrame.Angles(0.18, 0, 0),
			stripe,
			M.Fabric
		)
	end
	-- Rack along the back with rods leaning on it, a few more laid on the counter.
	part(m, Vector3.new(8, 0.4, 0.4), base * CFrame.new(0, 5, -2.2), WOOD_DARK, M.Wood)
	local blanks = { rgb(160, 120, 70), rgb(40, 60, 58), rgb(120, 40, 34), rgb(200, 180, 120), rgb(60, 60, 64) }
	for k = 0, 6 do
		local x = -3.3 + k * 1.1
		local foot = base:PointToWorldSpace(Vector3.new(x, 0.2, -1.4))
		local tip = base:PointToWorldSpace(Vector3.new(x + rng:NextNumber(-0.3, 0.3), 7.6, -2.6))
		beam(m, foot, tip, 0.18, blanks[k % #blanks + 1], nil, M.Wood)
		part(m, Vector3.new(0.4, 0.4, 0.4), CFrame.new(foot:Lerp(tip, 0.18)), IRON, M.Metal)
	end
	for k = 0, 2 do
		local y = 3.35 + k * 0.01
		part(
			m,
			Vector3.new(7, 0.16, 0.16),
			base * CFrame.new(0, y, 0.8 + k * 0.6) * CFrame.Angles(0, rng:NextNumber(-0.08, 0.08), 0),
			blanks[k + 1],
			M.Wood
		)
	end
	Props.lantern(m, base * CFrame.new(-3.8, 6.6, 3.2))
	Props.barrel(m, base:PointToWorldSpace(Vector3.new(-5.8, 0, -1)), rng)
	return m
end

-- An iron cannon on a wooden carriage, its muzzle along the frame's -Z.
local function cannon(parent: Instance, frame: CFrame)
	local m = newModel("Cannon", parent)
	part(m, Vector3.new(2.4, 1, 4), frame * CFrame.new(0, 0.9, 0), WOOD, M.WoodPlanks)
	for _, side in { -1, 1 } do
		part(m, Vector3.new(0.4, 1.8, 3.4), frame * CFrame.new(side * 1.05, 1.6, 0.2), WOOD_DARK, M.Wood)
		for _, z in { -1.3, 1.3 } do
			local wheel = cylinder(m, (frame * CFrame.new(side * 1.4, 0.7, z)).Position, 0.4, 1.4, WOOD_DARK, M.Wood)
			wheel.CFrame = frame * CFrame.new(side * 1.4, 0.7, z)
		end
	end
	local barrel = part(
		m,
		Vector3.new(5.2, 1.2, 1.2),
		frame * CFrame.new(0, 2.2, -0.6) * CFrame.Angles(0.1, math.pi / 2, 0),
		IRON,
		M.Metal
	)
	barrel.Shape = Enum.PartType.Cylinder
	local muzzle = part(
		m,
		Vector3.new(0.5, 1.5, 1.5),
		frame * CFrame.new(0, 2.45, -3.1) * CFrame.Angles(0.1, math.pi / 2, 0),
		IRON,
		M.Metal
	)
	muzzle.Shape = Enum.PartType.Cylinder
	for k = 0, 2 do
		Props.ball(
			m,
			(frame * CFrame.new(1.8 + (k % 2) * 0.7, 0.4 + math.floor(k / 2) * 0.6, 1.6 - k * 0.35)).Position,
			0.75,
			IRON,
			M.Metal
		)
	end
end

-- A small rowboat pulled up on the sand, bow along `frame`'s -Z.
local function beachedBoat(parent: Instance, frame: CFrame, color: Color3)
	local m = newModel("BeachedBoat", parent)
	local tilt = frame * CFrame.Angles(0, 0, 0.12)
	part(m, Vector3.new(3.4, 0.4, 8), tilt * CFrame.new(0, 0.4, 0), WOOD_DARK, M.WoodPlanks)
	for _, side in { -1, 1 } do
		part(
			m,
			Vector3.new(0.3, 1.4, 8),
			tilt * CFrame.new(side * 1.75, 1, 0) * CFrame.Angles(0, 0, side * 0.25),
			color,
			M.WoodPlanks
		)
	end
	part(m, Vector3.new(3.4, 1.4, 0.3), tilt * CFrame.new(0, 1, 3.9), color, M.WoodPlanks)
	part(m, Vector3.new(1.2, 1.4, 0.3), tilt * CFrame.new(0, 1, -4.2), color, M.WoodPlanks)
	part(m, Vector3.new(3.2, 0.25, 1), tilt * CFrame.new(0, 1.2, 0.6), WOOD, M.Wood)
	beam(
		m,
		(tilt * CFrame.new(-1, 1.4, -1)).Position,
		(tilt * CFrame.new(1.6, 0.3, 4.5)).Position,
		0.2,
		WOOD,
		nil,
		M.Wood
	)
end

-- A broken-backed ship half sunk in the shallows: listing hull, snapped mast and a torn sail.
local function wreck(parent: Instance, frame: CFrame)
	local m = newModel("Shipwreck", parent)
	m:SetAttribute("LodColor", WOOD_DARK)
	local hull = frame * CFrame.Angles(0, 0, 0.42) * CFrame.Angles(0.12, 0, 0)
	local length, beamWidth = 46, 13
	part(m, Vector3.new(2, 2, length), hull * CFrame.new(0, -6, 0), WOOD_DARK, M.Wood)
	for _, side in { -1, 1 } do
		for row = 0, 4 do
			local y = -5 + row * 1.9
			local spread = beamWidth / 2 * (0.55 + row * 0.11)
			-- Planking stops short where the hull is stove in on the low side.
			local run = if side == -1 and row >= 2 then length * 0.55 else length
			local shift = if side == -1 and row >= 2 then -length * 0.2 else 0
			part(
				m,
				Vector3.new(0.6, 2, run),
				hull * CFrame.new(side * spread, y, shift) * CFrame.Angles(0, 0, side * -0.18),
				WOOD,
				M.WoodPlanks
			)
		end
	end
	-- Ribs show through the gap.
	for k = 0, 4 do
		beam(
			m,
			(hull * CFrame.new(-3, -5.5, 4 + k * 3)).Position,
			(hull * CFrame.new(-6.6, 3, 4 + k * 3)).Position,
			0.6,
			WOOD_DARK,
			nil,
			M.Wood
		)
	end
	part(
		m,
		Vector3.new(beamWidth - 1, 0.6, length * 0.5),
		hull * CFrame.new(0, 3.6, -length * 0.22),
		WOOD,
		M.WoodPlanks
	)
	part(m, Vector3.new(beamWidth * 0.7, 3, 7), hull * CFrame.new(0, 5.6, -length * 0.4), WOOD_DARK, M.WoodPlanks)
	local foot = hull * CFrame.new(0, 3.8, -2)
	local top = foot * CFrame.Angles(0.5, 0, 0.2) * CFrame.new(0, 16, 0)
	beam(m, foot.Position, top.Position, 1.1, WOOD_DARK, nil, M.Wood)
	beam(
		m,
		(foot * CFrame.Angles(0.5, 0, 0.2) * CFrame.new(-6, 11, 0)).Position,
		(foot * CFrame.Angles(0.5, 0, 0.2) * CFrame.new(6, 11, 0)).Position,
		0.6,
		WOOD_DARK,
		nil,
		M.Wood
	)
	local sail = part(
		m,
		Vector3.new(10, 7, 0.15),
		foot * CFrame.Angles(0.5, 0, 0.2) * CFrame.new(-1, 7.4, 0.5) * CFrame.Angles(0.15, 0.1, -0.08),
		SAIL,
		M.Fabric
	)
	sail.CanCollide = false
	part(m, Vector3.new(0.2, 3, 0.2), top * CFrame.new(0, 1.5, 0), WOOD_DARK, M.Wood)
	part(m, Vector3.new(0.1, 1.6, 2.4), top * CFrame.new(0, 2.2, 1.2), rgb(20, 20, 22), M.Fabric).CanCollide = false
	Props.barrel(m, (hull * CFrame.new(2, 3.9, -length * 0.15)).Position, Random.new(4))
end

-- A ring of posts round the plaza with lanterns on top and festoon lights between them.
local function plazaLights(parent: Instance, surface: (number, number) -> Vector3, rng: Random)
	local m = newModel("PlazaLights", parent)
	local tops = {}
	for k = 0, 7 do
		local angle = (k + 0.5) / 8 * TAU
		local ground = surface(math.cos(angle) * 24, math.sin(angle) * 24)
		part(m, Vector3.new(0.6, 8, 0.6), CFrame.new(ground + Vector3.new(0, 4, 0)), WOOD_DARK, M.Wood)
		Props.lantern(m, CFrame.new(ground + Vector3.new(0, 8.8, 0)))
		table.insert(tops, ground + Vector3.new(0, 7.6, 0))
	end
	for k = 1, #tops do
		Props.stringLights(m, tops[k], tops[k % #tops + 1], rng, 1.6)
	end
end

----------------------------------------------------------------------------------------------------

function Cove.build(root: Instance): Model
	local existing = root:FindFirstChild(Data.NAME)
	if existing and existing:IsA("Model") and existing:GetAttribute("CoveVersion") == Cove.VERSION then
		return existing
	end
	local lodId = existing and existing:GetAttribute("LodId")
	if existing then
		existing:Destroy()
	end
	clearSite(root)
	local rng = Random.new(Biomes.Seed + 4077)
	local seaFloor = Biomes.Tropical.shelfDepth or Biomes.SeaFloor

	local island = Islands.build({
		position = Vector2.new(CENTER.X, CENTER.Z),
		radius = Data.RADIUS,
		height = HEIGHT,
		shape = "plateau",
		palette = PALETTE,
		rng = rng,
		seaFloor = seaFloor,
		shoreLine = 3,
		elongation = 0.12,
		roughness = 0.14,
	})
	island.Name = Data.NAME
	island:SetAttribute("CoveVersion", Cove.VERSION)
	-- Streams and draws a distant shell like an island, but added after the bake (see Map/Lod)
	island:SetAttribute("LodRoot", true)
	island:SetAttribute("LodRadial", true)
	island:SetAttribute("LodStamp", "cove" .. Cove.VERSION)
	if lodId ~= nil then
		island:SetAttribute("LodId", lodId)
	end
	-- The headland: a rocky stack on the north-west shore that shelters the pier.
	local headland = Islands.build({
		position = Vector2.new(CENTER.X - 128, CENTER.Z - 92),
		radius = 46,
		height = 38,
		shape = "stack",
		palette = ROCK,
		rng = rng,
		seaFloor = seaFloor,
		roughness = 0.35,
	})
	local ground = island:FindFirstChild("Ground") :: Model
	for _, piece in (headland:FindFirstChild("Ground") :: Model):GetChildren() do
		piece.Parent = ground
	end
	headland:Destroy()

	-- Split into streaming pieces before the first replication; props added below are split as they go in.
	Lod.prepareIsland(island)
	island.Parent = root

	local function surface(x: number, z: number): Vector3
		local hit = Islands.surface(island, CENTER.X + x, CENTER.Z + z)
		return hit or world(x, HEIGHT)
	end
	local plaza = surface(0, 0)
	local anchors = {}
	local taken: { { number } } = {}
	local function claim(x: number, z: number, radius: number)
		table.insert(taken, { x, z, radius })
	end
	local function free(x: number, z: number, radius: number): boolean
		for _, t in taken do
			if (Vector2.new(t[1], t[2]) - Vector2.new(x, z)).Magnitude < t[3] + radius then
				return false
			end
		end
		return true
	end

	-- Plaza: the flag, lights and a signpost.
	local town = newModel("Town", island)
	jollyRoger(town, plaza)
	claim(0, 0, 4)
	plazaLights(town, surface, rng)
	Props.signpost(town, surface(-6, -6), 0, {
		{ "Pier", 1.37 },
		{ "Galley", 0.3 },
		{ "Rods", 2.57 },
		{ "Tavern", -1.41 },
	})
	claim(-6, -6, 2)

	-- Market stalls facing the plaza: the galley buys fish, the rod trader sells rods.
	for _, stall in { { id = "BuyerStall", x = 17, z = -13 }, { id = "RodStall", x = -17, z = -13 } } do
		local ground = surface(stall.x, stall.z)
		local face = facing(ground, Vector3.new(plaza.X, ground.Y, plaza.Z))
		local model = if stall.id == "BuyerStall"
			then Props.stall(town, ground, face, rng, CANOPIES[1])
			else rodStall(town, ground, face, rng)
		model.Name = stall.id
		local base = CFrame.new(ground) * CFrame.Angles(0, face, 0)
		-- Behind the counter, looking out over it at the plaza.
		local stand = base * CFrame.new(0, 0, -1.1)
		anchors[stall.id] = CFrame.lookAt(stand.Position, stand.Position + base.LookVector * -1)
		claim(stall.x, stall.z, 7)
	end

	-- The tavern closes the plaza on the south; shacks ring the rest.
	local tavernGround = surface(0, 32)
	local tavern = Props.house(town, tavernGround, facing(tavernGround, plaza), rng, WALLS[1], THATCH)
	tavern.Name = "Tavern"
	Props.simplifyHouseCollision(tavern)
	claim(0, 32, 10)
	Props.barrel(town, surface(-8, 23), rng)
	Props.barrel(town, surface(-9.5, 24.5), rng)
	Props.bench(town, surface(10, 25), math.pi)
	for i, spot in { { -38, 6 }, { 38, 4 }, { -31, 34 }, { 31, 35 }, { 62, 30 }, { -62, 32 } } do
		local ground = surface(spot[1], spot[2])
		local house = Props.house(town, ground, facing(ground, plaza), rng, WALLS[(i % #WALLS) + 1], THATCH)
		house.Name = "Shack"
		Props.simplifyHouseCollision(house)
		claim(spot[1], spot[2], 10)
	end
	claim(7, 18, 3) -- the cook
	claim(0, 9, 3) -- the captain

	-- Cannons on the north-west bluff, looking out to sea, with the navigator's chart table.
	for _, spot in { { -50, -27 }, { -38, -31 }, { -62, -20 } } do
		local ground = surface(spot[1], spot[2])
		local out = Vector3.new(ground.X - 40, ground.Y, ground.Z - 40)
		cannon(town, CFrame.lookAt(ground, out))
		claim(spot[1], spot[2], 3)
	end
	local tableGround = surface(-46, -14)
	part(
		town,
		Vector3.new(4, 0.3, 2.6),
		CFrame.new(tableGround + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0.4, 0),
		WOOD,
		M.WoodPlanks
	)
	part(
		town,
		Vector3.new(3, 0.05, 2),
		CFrame.new(tableGround + Vector3.new(0, 2.78, 0)) * CFrame.Angles(0, 0.5, 0),
		rgb(226, 206, 160),
		M.Fabric
	)
	cylinder(town, tableGround + Vector3.new(0, 1.25, 0), 2.5, 0.6, WOOD_DARK, M.Wood)
	claim(-46, -14, 3)
	claim(-42, -18, 3)

	-- The pearl diver's corner: a drying rack, crates and barrels.
	Props.fishRack(town, surface(52, -12), 0.6, rng)
	Props.crates(town, surface(48, -28), rng)
	Props.barrel(town, surface(56, -24), rng)
	claim(52, -12, 5)
	claim(44, -20, 3)
	claim(52, -27, 4)
	-- The cabin boy's pile of loot.
	Props.crates(town, surface(-15, -27), rng)
	Props.barrel(town, surface(-4, -30), rng)
	claim(-9, -24, 3)
	claim(-14, -28, 4)

	-- The pier, from the north beach out towards home.
	local pierX = 4
	local shoreZ = -60
	for z = -60, -Data.RADIUS * 1.2, -2 do
		shoreZ = z
		if surface(pierX, z).Y < 2.4 then
			break
		end
	end
	local pierStart = world(pierX, shoreZ + 2)
	local pierEnd = Props.dock(town, pierStart, Vector3.new(0, 0, -1), PIER_LENGTH, rng)
	local stand = Vector3.new(pierStart.X - 2.2, 3.3, pierStart.Z - 12)
	anchors.Pier = CFrame.lookAt(stand, Vector3.new(stand.X, stand.Y, stand.Z + 10))
	Props.signpost(town, Vector3.new(pierStart.X + 4.6, 3.3, pierStart.Z - 3), 0, {
		{ Data.NAME, -math.pi / 2 },
		{ "Gullhaven", 1.28 },
	})
	Props.lifeRing(town, CFrame.new(pierEnd + Vector3.new(3.9, 0.8, 0)) * CFrame.Angles(0, math.pi / 2, 0))
	for k = 0, 3 do
		claim(pierX, shoreZ + 4 - k * 8, 6)
	end
	-- A path of planks from the plaza down to the pier.
	local prev = surface(pierX, -24)
	for z = -28, shoreZ + 8, -4 do
		local ground = surface(pierX, z)
		part(
			town,
			Vector3.new(4, 0.3, 4.4),
			CFrame.lookAt((prev + ground) / 2, ground) + Vector3.new(0, 0.15, 0),
			WOOD,
			M.WoodPlanks
		)
		prev = ground
	end
	for z = -24, shoreZ + 8, -4 do
		claim(pierX, z, 3)
	end

	-- Palms and bushes round the town and down to the beach; driftwood, shells and boats on the sand.
	local nature = newModel("Nature", island)
	local bushes = { rgb(70, 140, 60), rgb(90, 160, 70), rgb(60, 120, 64) }
	local planted = 0
	for _ = 1, 600 do
		if planted >= 70 then
			break
		end
		local a = rng:NextNumber(0, TAU)
		local d = rng:NextNumber(32, Data.RADIUS * 0.82)
		local x, z = math.cos(a) * d, math.sin(a) * d
		local hit, normal = Islands.surface(island, CENTER.X + x, CENTER.Z + z)
		if hit and normal and hit.Y > 1.4 and normal.Y > 0.85 and free(x, z, 5) then
			claim(x, z, 5)
			planted += 1
			if rng:NextNumber() < 0.7 then
				Props.palm(nature, hit, rng)
			else
				Props.simplifyDecorationCollision(Props.bush(nature, hit, rng, bushes))
			end
		end
	end
	local scattered = 0
	for _ = 1, 400 do
		if scattered >= 28 then
			break
		end
		local a = rng:NextNumber(0, TAU)
		local d = rng:NextNumber(Data.RADIUS * 0.66, Data.RADIUS * 0.86)
		local x, z = math.cos(a) * d, math.sin(a) * d
		local hit, normal = Islands.surface(island, CENTER.X + x, CENTER.Z + z)
		if hit and normal and hit.Y > 0.4 and hit.Y < 4 and normal.Y > 0.9 and free(x, z, 3) then
			claim(x, z, 3)
			scattered += 1
			local roll = rng:NextNumber()
			if roll < 0.4 then
				Props.driftwood(nature, hit, rng)
			elseif roll < 0.75 then
				Props.shells(nature, hit, rng)
			elseif roll < 0.9 then
				Props.barrel(nature, hit, rng)
			else
				Props.crates(nature, hit, rng)
			end
		end
	end
	for k, spot in { { 26, -118 }, { -24, -112 } } do
		local hit = surface(spot[1], spot[2])
		beachedBoat(
			nature,
			CFrame.lookAt(hit, hit + Vector3.new(-spot[1], 0, -spot[2]) * -1) * CFrame.new(0, -0.3, 0),
			CANOPIES[k + 1]
		)
	end

	-- The wreck in the shallows off the north-east shore.
	wreck(island, CFrame.new(world(150, -150)) * CFrame.Angles(0, 0.7, 0))

	-- Where the crew stand: named anchors for the stalls and the pier, plus the plaza for facing.
	for id, frame in anchors do
		island:SetAttribute("Anchor_" .. id, frame)
	end
	island:SetAttribute("Plaza", plaza)
	return island
end

return Cove
