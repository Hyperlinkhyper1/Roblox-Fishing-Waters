-- Set dressing: trees, buildings, harbour clutter, rocks and effects, all using Roblox's textured materials.
-- Each builder takes a ground position and puts its parts in a new Model under `parent`.

local LowPoly = require(script.Parent.LowPoly)

local Props = {}

local TAU = math.pi * 2
local rgb = Color3.fromRGB
local M = Enum.Material

local WOOD = rgb(122, 92, 64)
local WOOD_DARK = rgb(78, 60, 46)
local TRUNK = rgb(88, 66, 50)
local WHITE = rgb(232, 228, 218)
local RED = rgb(170, 52, 44)
local IRON = rgb(52, 50, 48)
local ROPE = rgb(176, 150, 106)
local STONE = rgb(132, 126, 118)
local LAMP = rgb(255, 210, 140)
local LAVA = rgb(255, 96, 28)

local function newModel(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function part(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = material or M.SmoothPlastic
	p.Color = color
	p.Size = size
	p.CFrame = cframe
	p.Parent = parent
	return p
end

-- Upright cylinder centered on `center`.
local function cylinder(
	parent: Instance,
	center: Vector3,
	height: number,
	diameter: number,
	color: Color3,
	material: Enum.Material?
): Part
	local p = part(
		parent,
		Vector3.new(height, diameter, diameter),
		CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A block stretched between two points; trunks, roots, posts, branches, ropes and fronds.
local function beam(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	width: number,
	color: Color3,
	thickness: number?,
	material: Enum.Material?
): Part
	if math.abs((b - a).Unit.Y) > 0.999 then
		b += Vector3.new(0.01, 0, 0)
	end
	return part(
		parent,
		Vector3.new(width, thickness or width, (b - a).Magnitude),
		CFrame.lookAt((a + b) / 2, b),
		color,
		material
	)
end

-- Randomly rotated block; reads as a chunky clump (canopies, rocks, coral).
local function blob(
	parent: Instance,
	center: Vector3,
	size: Vector3,
	rng: Random,
	color: Color3,
	material: Enum.Material?
): Part
	local spin = CFrame.Angles(rng:NextNumber(0, TAU), rng:NextNumber(0, TAU), rng:NextNumber(0, TAU))
	return part(parent, size, CFrame.new(center) * spin, color, material)
end

local function ball(parent: Instance, center: Vector3, size: number, color: Color3, material: Enum.Material?): Part
	local p = part(parent, Vector3.new(size, size, size), CFrame.new(center), color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
end

local function shade(color: Color3, rng: Random, amount: number): Color3
	local s = 1 + rng:NextNumber(-amount, amount)
	return Color3.new(math.min(color.R * s, 1), math.min(color.G * s, 1), math.min(color.B * s, 1))
end

function Props.pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

Props.part = part
Props.cylinder = cylinder
Props.beam = beam
Props.blob = blob
Props.ball = ball
Props.light = light
Props.shade = shade

----------------------------------------------------------------------------------------------------
-- Trees

-- Tiered conifer; `snow` frosts the tiers for the ice biome.
function Props.pine(parent: Instance, ground: Vector3, rng: Random, leaves: Color3, snow: Color3?): Model
	local m = newModel("Pine", parent)
	local h = rng:NextNumber(14, 30)
	local width = h * rng:NextNumber(0.2, 0.26)
	part(m, Vector3.new(1.2, h * 0.3, 1.2), CFrame.new(ground + Vector3.new(0, h * 0.15 - 1, 0)), TRUNK, M.Wood)

	local tiers = if h > 21 then 3 else 2
	local spin = rng:NextNumber(0, TAU)
	for i = 1, tiers do
		local k = (i - 1) / tiers
		local baseY = h * (0.16 + k * 0.6)
		local apexY = if i == tiers then h else baseY + h * 0.5
		local r = width * (1 - k * 0.55)
		local base = {}
		for s = 0, 3 do
			local a = spin + i * 0.7 + s * TAU / 4 + rng:NextNumber(-0.2, 0.2)
			base[s + 1] = ground + Vector3.new(math.cos(a) * r, baseY, math.sin(a) * r)
		end
		local apex = ground + Vector3.new(rng:NextNumber(-0.4, 0.4), apexY, rng:NextNumber(-0.4, 0.4))
		local color = shade(leaves, rng, 0.08)
		local material = M.Grass
		if snow then
			color = color:Lerp(snow, if i == tiers then 0.85 else 0.45)
			material = if i == tiers then M.Snow else M.Grass
		end
		LowPoly.pyramid(base, apex, color, m, material)
	end
	return m
end

-- Round-canopied tree (the orange/brown autumn trees around the Sound).
function Props.broadleaf(parent: Instance, ground: Vector3, rng: Random, colors: { Color3 }): Model
	local m = newModel("Tree", parent)
	local h = rng:NextNumber(10, 16)
	local top = ground + Vector3.new(rng:NextNumber(-1, 1), h * 0.65, rng:NextNumber(-1, 1))
	beam(m, ground - Vector3.new(0, 1, 0), top, 1.4, TRUNK, nil, M.Wood)
	for _ = 1, 2 do
		local a = rng:NextNumber(0, TAU)
		local tip = top:Lerp(ground, 0.35) + Vector3.new(math.cos(a) * 3.5, 3, math.sin(a) * 3.5)
		beam(m, top:Lerp(ground, 0.4), tip, 0.6, TRUNK, nil, M.Wood)
	end
	for _ = 1, rng:NextInteger(3, 4) do
		local s = rng:NextNumber(5, 8)
		local offset = Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(0, 3.5), rng:NextNumber(-3, 3))
		blob(m, top + offset, Vector3.new(s, s * 0.8, s), rng, shade(Props.pick(rng, colors), rng, 0.06), M.LeafyGrass)
	end
	return m
end

-- Mangrove on arching stilt roots. `floorY` is where the roots end (sea floor or ground).
function Props.mangrove(
	parent: Instance,
	ground: Vector3,
	rng: Random,
	floorY: number,
	bark: Color3,
	canopy: { Color3 }
): Model
	local m = newModel("Mangrove", parent)
	local h = rng:NextNumber(16, 28)
	local hub = ground + Vector3.new(0, rng:NextNumber(4, 7), 0)
	local top = ground + Vector3.new(rng:NextNumber(-2, 2), h, rng:NextNumber(-2, 2))
	beam(m, hub, top, 1.4, bark, nil, M.Wood)

	for _ = 1, rng:NextInteger(4, 6) do
		local a = rng:NextNumber(0, TAU)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local reach = rng:NextNumber(5, 9)
		local knee = hub + dir * reach * 0.6 + Vector3.new(0, rng:NextNumber(0, 2), 0)
		local foot = Vector3.new(ground.X, floorY, ground.Z) + dir * reach
		beam(m, hub + Vector3.new(0, 1, 0), knee, 0.8, bark, nil, M.Wood)
		beam(m, knee, foot, 0.8, bark, nil, M.Wood)
	end

	local crowns = { top }
	for _ = 1, rng:NextInteger(2, 3) do
		local a = rng:NextNumber(0, TAU)
		local from = hub:Lerp(top, rng:NextNumber(0.5, 0.85))
		local to = from
			+ Vector3.new(math.cos(a) * rng:NextNumber(5, 9), rng:NextNumber(2, 5), math.sin(a) * rng:NextNumber(5, 9))
		beam(m, from, to, 0.7, bark, nil, M.Wood)
		table.insert(crowns, to)
	end
	for _, crown in crowns do
		local s = rng:NextNumber(8, 13)
		local tilt = CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, TAU), rng:NextNumber(-0.2, 0.2))
		part(
			m,
			Vector3.new(s, s * 0.45, s),
			CFrame.new(crown) * tilt,
			shade(Props.pick(rng, canopy), rng, 0.06),
			M.LeafyGrass
		)
	end
	return m
end

function Props.palm(parent: Instance, ground: Vector3, rng: Random): Model
	local m = newModel("Palm", parent)
	local h = rng:NextNumber(14, 22)
	local lean = rng:NextNumber(0, TAU)
	local dir = Vector3.new(math.cos(lean), 0, math.sin(lean))
	local bend = rng:NextNumber(2, 6)

	local prev = ground - Vector3.new(0, 1, 0)
	for k = 1, 5 do
		local t = k / 5
		local p = ground + Vector3.new(0, h * t, 0) + dir * (bend * t * t)
		beam(m, prev, p, 1.3 - t * 0.4, if k % 2 == 0 then rgb(140, 112, 78) else rgb(120, 94, 66), nil, M.Wood)
		prev = p
	end

	local top = prev
	for f = 1, 6 do
		local a = f / 6 * TAU + rng:NextNumber(-0.2, 0.2)
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local mid = top + d * 5 + Vector3.new(0, 1.2, 0)
		local tip = top + d * 10 + Vector3.new(0, -2.5, 0)
		beam(m, top, mid, 2.4, rgb(78, 140, 60), 0.25, M.LeafyGrass)
		beam(m, mid, tip, 2, rgb(62, 118, 52), 0.25, M.LeafyGrass)
	end
	for _ = 1, rng:NextInteger(1, 3) do
		ball(m, top + Vector3.new(rng:NextNumber(-1, 1), -1, rng:NextNumber(-1, 1)), 1.1, rgb(96, 70, 44), M.Wood)
	end
	return m
end

-- Bare trunk with a few branches; swamp snags and charred volcanic trees.
function Props.deadTree(parent: Instance, ground: Vector3, rng: Random, color: Color3): Model
	local m = newModel("DeadTree", parent)
	local h = rng:NextNumber(8, 16)
	local top = ground + Vector3.new(rng:NextNumber(-1.5, 1.5), h, rng:NextNumber(-1.5, 1.5))
	beam(m, ground - Vector3.new(0, 1, 0), top, 1.1, color, nil, M.Wood)
	for _ = 1, rng:NextInteger(2, 3) do
		local a = rng:NextNumber(0, TAU)
		local from = ground:Lerp(top, rng:NextNumber(0.45, 0.85))
		local to = from
			+ Vector3.new(
				math.cos(a) * rng:NextNumber(3, 6),
				rng:NextNumber(1.5, 4),
				math.sin(a) * rng:NextNumber(3, 6)
			)
		beam(m, from, to, 0.5, color, nil, M.Wood)
	end
	return m
end

function Props.bush(parent: Instance, ground: Vector3, rng: Random, colors: { Color3 }): Model
	local m = newModel("Bush", parent)
	for _ = 1, rng:NextInteger(2, 3) do
		local s = rng:NextNumber(2.5, 4.5)
		local offset = Vector3.new(rng:NextNumber(-1.5, 1.5), s * 0.25, rng:NextNumber(-1.5, 1.5))
		blob(
			m,
			ground + offset,
			Vector3.new(s, s * 0.7, s),
			rng,
			shade(Props.pick(rng, colors), rng, 0.06),
			M.LeafyGrass
		)
	end
	return m
end

-- Little clump of flowers.
function Props.flowers(parent: Instance, ground: Vector3, rng: Random): Model
	local m = newModel("Flowers", parent)
	local colors = { rgb(230, 90, 90), rgb(250, 210, 90), rgb(240, 240, 240), rgb(180, 120, 220), rgb(250, 150, 60) }
	local color = Props.pick(rng, colors)
	for _ = 1, rng:NextInteger(4, 7) do
		local at = ground + Vector3.new(rng:NextNumber(-1.8, 1.8), 0, rng:NextNumber(-1.8, 1.8))
		part(m, Vector3.new(0.15, 1.2, 0.15), CFrame.new(at + Vector3.new(0, 0.6, 0)), rgb(80, 120, 60), M.Grass)
		ball(m, at + Vector3.new(0, 1.3, 0), 0.6, color, M.Plastic)
	end
	return m
end

----------------------------------------------------------------------------------------------------
-- Rocks and ice

function Props.rock(parent: Instance, ground: Vector3, rng: Random, size: number, color: Color3): Part
	return blob(
		parent,
		ground + Vector3.new(0, size * 0.2, 0),
		Vector3.new(size, size * rng:NextNumber(0.5, 0.9), size * rng:NextNumber(0.7, 1.1)),
		rng,
		shade(color, rng, 0.08),
		M.Rock
	)
end

function Props.boulder(
	parent: Instance,
	ground: Vector3,
	rng: Random,
	radius: number,
	color: Color3,
	material: Enum.Material?
): Model
	local m = newModel("Boulder", parent)
	LowPoly.boulder(
		ground + Vector3.new(0, radius * 0.3, 0),
		radius,
		rng,
		shade(color, rng, 0.06),
		m,
		material or M.Rock
	)
	return m
end

-- Tall leaning four-sided shard (ice spikes, obsidian).
function Props.spike(
	parent: Instance,
	ground: Vector3,
	rng: Random,
	height: number,
	radius: number,
	color: Color3,
	material: Enum.Material?
): Model
	local m = newModel("Spike", parent)
	local spin = rng:NextNumber(0, TAU)
	local base = {}
	for i = 0, 3 do
		local a = spin + i * TAU / 4 + rng:NextNumber(-0.2, 0.2)
		local r = radius * rng:NextNumber(0.8, 1.2)
		base[i + 1] = ground + Vector3.new(math.cos(a) * r, -2, math.sin(a) * r)
	end
	local lean = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * height * 0.15
	LowPoly.pyramid(base, ground + Vector3.new(0, height, 0) + lean, shade(color, rng, 0.05), m, material or M.Ice)
	return m
end

-- Cluster of basalt columns.
function Props.basalt(parent: Instance, ground: Vector3, rng: Random, color: Color3): Model
	local m = newModel("Basalt", parent)
	for _ = 1, rng:NextInteger(3, 6) do
		local h = rng:NextNumber(4, 12)
		local offset = Vector3.new(rng:NextNumber(-3, 3), h / 2 - 1, rng:NextNumber(-3, 3))
		part(
			m,
			Vector3.new(2.6, h, 2.6),
			CFrame.new(ground + offset) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
			shade(color, rng, 0.1),
			M.Basalt
		)
	end
	return m
end

----------------------------------------------------------------------------------------------------
-- Water plants

function Props.reeds(parent: Instance, position: Vector3, rng: Random): Model
	local m = newModel("Reeds", parent)
	for _ = 1, rng:NextInteger(5, 8) do
		local base = position + Vector3.new(rng:NextNumber(-2.5, 2.5), -3, rng:NextNumber(-2.5, 2.5))
		local tip = base + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(7, 12), rng:NextNumber(-1, 1))
		beam(m, base, tip, 0.35, shade(rgb(150, 150, 72), rng, 0.12), nil, M.Grass)
	end
	return m
end

function Props.lilyPad(parent: Instance, position: Vector3, rng: Random): Model
	local m = newModel("LilyPad", parent)
	local d = rng:NextNumber(2.5, 5)
	cylinder(m, position + Vector3.new(0, 0.1, 0), 0.2, d, shade(rgb(84, 116, 56), rng, 0.1), M.LeafyGrass)
	if rng:NextNumber() < 0.2 then
		blob(m, position + Vector3.new(0, 0.5, 0), Vector3.new(0.9, 0.9, 0.9), rng, rgb(230, 170, 190), M.Plastic)
	end
	return m
end

function Props.coral(parent: Instance, ground: Vector3, rng: Random, colors: { Color3 }): Model
	local m = newModel("Coral", parent)
	for _ = 1, rng:NextInteger(2, 4) do
		local s = rng:NextNumber(1.5, 4)
		local offset = Vector3.new(rng:NextNumber(-2, 2), s * 0.4, rng:NextNumber(-2, 2))
		blob(m, ground + offset, Vector3.new(s * 0.6, s * 1.4, s * 0.6), rng, Props.pick(rng, colors), M.Pebble)
	end
	return m
end

----------------------------------------------------------------------------------------------------
-- Buildings

local SHUTTERS = { rgb(70, 92, 112), rgb(112, 60, 50), rgb(72, 102, 74), rgb(64, 62, 60) }

-- Cottage with timber corners, framed windows and a gabled roof; front door on its local +Z.
-- `stilts` raises it on posts (swamp shacks, beach huts). Tall ones get a second floor of windows.
function Props.house(
	parent: Instance,
	ground: Vector3,
	facing: number,
	rng: Random,
	wall: Color3,
	roof: Color3,
	stilts: number?
): Model
	local m = newModel("House", parent)
	local w, d = rng:NextNumber(11, 16), rng:NextNumber(9, 13)
	local stories = if not stilts and rng:NextNumber() < 0.3 then 2 else 1
	local h = if stories == 2 then rng:NextNumber(15, 17) else rng:NextNumber(8, 10.5)
	local lift = stilts or 0
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	local trim = wall:Lerp(Color3.new(0, 0, 0), 0.45)
	local shutter = Props.pick(rng, SHUTTERS)
	local wallMaterial = if stilts or rng:NextNumber() < 0.45 then M.WoodPlanks else M.Plaster
	local roofMaterial = if stilts then M.Fabric elseif rng:NextNumber() < 0.5 then M.RoofShingles else M.ClayRoofTiles

	if lift > 0 then
		for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
			local x, z = c[1] * (w / 2 - 0.5), c[2] * (d / 2 - 0.5)
			beam(
				m,
				base:PointToWorldSpace(Vector3.new(x, -6, z)),
				base:PointToWorldSpace(Vector3.new(x, lift, z)),
				0.9,
				WOOD_DARK,
				nil,
				M.Wood
			)
		end
		part(m, Vector3.new(w + 2, 0.6, d + 4), base * CFrame.new(0, lift - 0.7, 1.5), WOOD, M.WoodPlanks)
	end

	local floor = if lift > 0 then lift - 0.4 else 0.6
	if lift == 0 then
		part(m, Vector3.new(w + 0.8, 2, d + 0.8), base * CFrame.new(0, -0.4, 0), STONE, M.Cobblestone)
	end
	part(m, Vector3.new(w, h, d), base * CFrame.new(0, floor + h / 2, 0), wall, wallMaterial)
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		part(m, Vector3.new(0.8, h, 0.8), base * CFrame.new(c[1] * w / 2, floor + h / 2, c[2] * d / 2), trim, M.Wood)
	end
	if stories == 2 then
		part(m, Vector3.new(w + 0.4, 0.6, d + 0.4), base * CFrame.new(0, floor + h / 2, 0), trim, M.Wood)
	end

	-- Roof: two slanted panels, a ridge beam and the gable triangles
	local top = floor + h
	local pitch = math.rad(rng:NextNumber(32, 42))
	local rise = d / 2 * math.tan(pitch)
	local slant = (d / 2 + 1.2) / math.cos(pitch)
	for side = -1, 1, 2 do
		part(
			m,
			Vector3.new(w + 1.8, 0.7, slant),
			base * CFrame.new(0, top + rise / 2, side * d / 4) * CFrame.Angles(side * pitch, 0, 0),
			roof,
			roofMaterial
		)
		local x = side * w / 2
		LowPoly.triangle(
			base:PointToWorldSpace(Vector3.new(x, top, -d / 2)),
			base:PointToWorldSpace(Vector3.new(x, top, d / 2)),
			base:PointToWorldSpace(Vector3.new(x, top + rise, 0)),
			base:PointToWorldSpace(Vector3.new(0, top, 0)),
			wall,
			m,
			wallMaterial
		)
	end
	part(
		m,
		Vector3.new(w + 2, 0.8, 0.8),
		base * CFrame.new(0, top + rise + 0.2, 0),
		roof:Lerp(Color3.new(0, 0, 0), 0.3),
		M.Wood
	)

	-- Door with a frame, a handle and a step
	local front = d / 2
	part(m, Vector3.new(3.4, 5.8, 0.2), base * CFrame.new(0, floor + 2.9, front + 0.05), trim, M.Wood)
	part(m, Vector3.new(2.4, 5, 0.3), base * CFrame.new(0, floor + 2.5, front + 0.1), WOOD_DARK, M.WoodPlanks)
	ball(m, base:PointToWorldSpace(Vector3.new(0.8, floor + 2.5, front + 0.3)), 0.35, rgb(200, 170, 80), M.Metal)
	if lift == 0 then
		part(m, Vector3.new(4, 0.6, 1.6), base * CFrame.new(0, floor - 0.2, front + 0.8), STONE, M.Slate)
	end

	-- Framed, shuttered front windows on every floor, plain windows on the sides
	local storyHeight = h / stories
	for s = 1, stories do
		local y = floor + (s - 1) * storyHeight + storyHeight * 0.55
		for side = -1, 1, 2 do
			local x = side * (w / 4 + 0.8)
			part(m, Vector3.new(2.4, 2.6, 0.15), base * CFrame.new(x, y, front + 0.05), trim, M.Wood)
			local glass = part(m, Vector3.new(1.7, 1.9, 0.2), base * CFrame.new(x, y, front + 0.1), LAMP, M.Neon)
			part(m, Vector3.new(0.15, 1.9, 0.25), base * CFrame.new(x, y, front + 0.12), trim, M.Wood)
			part(m, Vector3.new(2.8, 0.3, 0.7), base * CFrame.new(x, y - 1.4, front + 0.3), trim, M.Wood)
			for flap = -1, 1, 2 do
				part(
					m,
					Vector3.new(0.8, 2.6, 0.15),
					base * CFrame.new(x + flap * 1.7, y, front + 0.1),
					shutter,
					M.WoodPlanks
				)
			end
			if s == 1 and side == 1 then
				light(glass, LAMP, 16, 0.8)
			end
			part(m, Vector3.new(0.2, 1.9, 1.7), base * CFrame.new(side * (w / 2 + 0.05), y, 0), LAMP, M.Neon)
		end
	end

	if rng:NextNumber() < 0.6 then
		local chimney = base * CFrame.new(w / 3, top + rise * 0.7, -d / 5)
		part(m, Vector3.new(1.8, rise + 3, 1.8), chimney, rgb(140, 84, 66), M.Brick)
		part(m, Vector3.new(2.3, 0.5, 2.3), chimney * CFrame.new(0, (rise + 3) / 2, 0), rgb(80, 70, 66), M.Slate)
	end
	if lift == 0 and rng:NextNumber() < 0.45 then
		-- Little porch roof over the door, with a lantern
		part(
			m,
			Vector3.new(5, 0.4, 2.8),
			base * CFrame.new(0, floor + 6, front + 1.3) * CFrame.Angles(0.25, 0, 0),
			roof,
			roofMaterial
		)
		for side = -1, 1, 2 do
			part(m, Vector3.new(0.4, 6, 0.4), base * CFrame.new(side * 2.2, floor + 3, front + 2.5), trim, M.Wood)
		end
		Props.lantern(m, base * CFrame.new(1.6, floor + 5.2, front + 0.6))
	end
	if rng:NextNumber() < 0.4 then
		local box = base * CFrame.new(-(w / 4 + 0.8), floor + storyHeight * 0.55 - 2, front + 0.7)
		part(m, Vector3.new(2.8, 0.8, 0.9), box, WOOD, M.WoodPlanks)
		for k = -1, 1 do
			ball(
				m,
				box.Position + base.RightVector * k * 0.8 + Vector3.new(0, 0.6, 0),
				0.7,
				Props.pick(rng, {
					rgb(220, 80, 80),
					rgb(250, 210, 90),
					rgb(240, 240, 240),
				}),
				M.Plastic
			)
		end
	end
	return m
end

-- Waterside fishing hut on a plank deck: front porch under a tin roof, life ring, lantern and bench.
-- Faces its local +Z. `color` tints the plank walls.
function Props.fishingHut(parent: Instance, ground: Vector3, facing: number, rng: Random, color: Color3): Model
	local m = newModel("FishingHut", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	local w, d, h = 16, 12, 10
	local wall = color:Lerp(rgb(150, 150, 140), 0.45)
	local trim = rgb(96, 70, 50)
	local tin = rgb(118, 122, 124)

	-- Raised deck with a porch out front
	part(m, Vector3.new(w + 4, 0.8, d + 9), base * CFrame.new(0, 0.6, 2.5), WOOD, M.WoodPlanks)
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		part(
			m,
			Vector3.new(0.9, 2, 0.9),
			base * CFrame.new(c[1] * (w / 2 + 1.5), 0, 2.5 + c[2] * (d + 8) / 2),
			WOOD_DARK,
			M.Wood
		)
	end
	part(m, Vector3.new(w, h, d), base * CFrame.new(0, 1 + h / 2, 0), wall, M.WoodPlanks)
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		part(m, Vector3.new(0.8, h, 0.8), base * CFrame.new(c[1] * w / 2, 1 + h / 2, c[2] * d / 2), trim, M.Wood)
	end
	part(m, Vector3.new(w + 0.4, 0.6, d + 0.4), base * CFrame.new(0, 1.3, 0), trim, M.Wood)

	-- Gabled tin roof that runs forward over the porch
	local top = 1 + h
	local pitch = math.rad(28)
	local rise = w / 2 * math.tan(pitch)
	local depth = d + 7
	for side = -1, 1, 2 do
		local slant = (w / 2 + 1.2) / math.cos(pitch)
		part(
			m,
			Vector3.new(slant, 0.5, depth),
			base * CFrame.new(side * w / 4, top + rise / 2, 3) * CFrame.Angles(0, 0, -side * pitch),
			tin,
			M.CorrodedMetal
		)
		local z = side * d / 2
		LowPoly.triangle(
			base:PointToWorldSpace(Vector3.new(-w / 2, top, z)),
			base:PointToWorldSpace(Vector3.new(w / 2, top, z)),
			base:PointToWorldSpace(Vector3.new(0, top + rise, z)),
			base:PointToWorldSpace(Vector3.new(0, top, 0)),
			wall,
			m,
			M.WoodPlanks
		)
	end
	part(m, Vector3.new(0.8, 0.8, depth + 0.4), base * CFrame.new(0, top + rise + 0.2, 3), trim, M.Wood)
	for side = -1, 1, 2 do
		part(m, Vector3.new(0.7, h, 0.7), base * CFrame.new(side * (w / 2 - 0.4), 1 + h / 2, d / 2 + 6.2), trim, M.Wood)
	end

	-- Porch railing with a gap for the steps
	local railY = 3
	for side = -1, 1, 2 do
		local x = side * (w / 2 + 1.6)
		beam(
			m,
			base:PointToWorldSpace(Vector3.new(x, railY, d / 2)),
			base:PointToWorldSpace(Vector3.new(x, railY, d / 2 + 6.5)),
			0.35,
			trim,
			nil,
			M.Wood
		)
		part(m, Vector3.new(0.4, 2.5, 0.4), base * CFrame.new(x, 2, d / 2 + 6.5), trim, M.Wood)
		beam(
			m,
			base:PointToWorldSpace(Vector3.new(x, railY, d / 2 + 6.5)),
			base:PointToWorldSpace(Vector3.new(side * 3, railY, d / 2 + 6.5)),
			0.35,
			trim,
			nil,
			M.Wood
		)
	end

	-- Front: door, window, life ring, lantern
	local front = d / 2
	part(m, Vector3.new(3.6, 6.4, 0.2), base * CFrame.new(-3, 4.2, front + 0.05), trim, M.Wood)
	part(m, Vector3.new(2.8, 5.8, 0.3), base * CFrame.new(-3, 3.9, front + 0.1), WOOD_DARK, M.WoodPlanks)
	part(m, Vector3.new(4.2, 3.4, 0.15), base * CFrame.new(3.5, 6, front + 0.05), trim, M.Wood)
	local glass = part(m, Vector3.new(3.4, 2.6, 0.2), base * CFrame.new(3.5, 6, front + 0.1), LAMP, M.Neon)
	light(glass, LAMP, 18, 0.9)
	part(m, Vector3.new(0.2, 2.6, 0.25), base * CFrame.new(3.5, 6, front + 0.15), trim, M.Wood)
	part(m, Vector3.new(4.6, 0.3, 0.8), base * CFrame.new(3.5, 4.2, front + 0.4), trim, M.Wood)
	Props.lifeRing(m, base * CFrame.new(0.2, 7.6, front + 0.3))
	Props.lantern(m, base * CFrame.new(-0.6, 9.2, front + 4))
	Props.bench(m, base:PointToWorldSpace(Vector3.new(3.5, 1, front + 1.6)), facing + math.pi)
	Props.crates(m, base:PointToWorldSpace(Vector3.new(-w / 2 - 0.2, 1, front + 5)), rng)
	Props.ropeCoil(m, base:PointToWorldSpace(Vector3.new(w / 2 - 1, 1, front + 5)))

	-- Side window and a stovepipe
	part(m, Vector3.new(0.2, 2.4, 3), base * CFrame.new(w / 2 + 0.05, 6, -1), LAMP, M.Neon)
	part(m, Vector3.new(0.15, 3, 3.6), base * CFrame.new(w / 2 + 0.02, 6, -1), trim, M.Wood)
	cylinder(m, base:PointToWorldSpace(Vector3.new(-w / 4, top + rise + 1.5, -d / 4)), 4, 1.2, IRON, M.Metal)
	return m
end

function Props.clockTower(parent: Instance, ground: Vector3, facing: number): Model
	local m = newModel("ClockTower", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	part(m, Vector3.new(11, 2, 11), base * CFrame.new(0, 0, 0), STONE, M.Cobblestone)
	part(m, Vector3.new(9, 30, 9), base * CFrame.new(0, 15, 0), WHITE, M.Plaster)
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		part(m, Vector3.new(1.2, 30, 1.2), base * CFrame.new(c[1] * 4.5, 15, c[2] * 4.5), STONE, M.Brick)
	end
	part(m, Vector3.new(10, 1.2, 10), base * CFrame.new(0, 29.6, 0), rgb(90, 80, 76), M.Slate)
	part(m, Vector3.new(7, 8, 7), base * CFrame.new(0, 34, 0), WHITE, M.Plaster)
	for k = 0, 3 do
		local side = base * CFrame.Angles(0, k * math.pi / 2, 0)
		cylinder(m, (side * CFrame.new(0, 34, 3.6)).Position, 0.3, 4.4, rgb(255, 240, 200), M.Neon).CFrame = side
			* CFrame.new(0, 34, 3.6)
			* CFrame.Angles(0, math.pi / 2, 0)
		part(m, Vector3.new(0.3, 1.6, 0.2), side * CFrame.new(0, 34.6, 3.85), IRON, M.Metal)
		part(m, Vector3.new(1.2, 0.3, 0.2), side * CFrame.new(0.5, 34, 3.85), IRON, M.Metal)
		part(m, Vector3.new(2.2, 3.2, 0.2), side * CFrame.new(0, 20, 4.55), rgb(70, 92, 112), M.Glass)
	end
	part(m, Vector3.new(3.4, 6.4, 0.2), base * CFrame.new(0, 4.2, 4.55), rgb(90, 80, 76), M.Wood)
	part(m, Vector3.new(3, 6, 0.3), base * CFrame.new(0, 4, 4.6), WOOD_DARK, M.WoodPlanks)

	local corners = {}
	for i, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		corners[i] = base:PointToWorldSpace(Vector3.new(c[1] * 4.5, 38, c[2] * 4.5))
	end
	LowPoly.pyramid(corners, base:PointToWorldSpace(Vector3.new(0, 47, 0)), RED, m, M.RoofShingles)
	return m
end

-- Small dock details never snag characters, boats, or interaction raycasts.
local function dockDetail(p: BasePart, name: string): BasePart
	p.Name = name
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local DOCK_WOOD = rgb(119, 83, 53)
local DOCK_WORN = rgb(158, 122, 81)
local DOCK_PILE = rgb(77, 55, 39)

-- Local -Z runs along the section. Every board has a level top at local Y = 0.3.
local function dockDeck(parent: Model, frame: CFrame, width: number, length: number, rng: Random)
	local count = math.ceil(length / 1.3)
	local pitch = length / count
	for i = 1, count do
		local z = -(i - 0.5) * pitch
		local color = DOCK_WOOD:Lerp(DOCK_WORN, rng:NextNumber(0.08, 0.8))
		local board = part(parent, Vector3.new(width, 0.6, pitch - 0.055), frame * CFrame.new(0, 0, z), color, M.Wood)
		board.Name = "DeckPlank"
		if i % 3 == 1 then
			for _, side in { -1, 1 } do
				dockDetail(
					cylinder(
						parent,
						(frame * CFrame.new(side * (width / 2 - 0.6), 0.306, z)).Position,
						0.025,
						0.13,
						IRON,
						M.Metal
					),
					"PlankNail"
				)
			end
		end
	end
	for _, side in { -1, 1 } do
		local stringer = part(
			parent,
			Vector3.new(0.5, 0.85, length),
			frame * CFrame.new(side * (width / 2 - 0.3), -0.65, -length / 2),
			DOCK_PILE,
			M.Wood
		)
		stringer.Name = "Stringer"
	end
end

local function dockPile(parent: Model, frame: CFrame, x: number, z: number, rng: Random)
	local position = frame * CFrame.new(x, 0, z)
	local pile =
		cylinder(parent, (position * CFrame.new(0, -7.2, 0)).Position, 18, 1.2, shade(DOCK_PILE, rng, 0.08), M.Wood)
	pile.Name = "Pile"
	dockDetail(
		cylinder(parent, (position * CFrame.new(0, 1.83, 0)).Position, 0.1, 1.24, DOCK_WORN, M.Wood),
		"PileEndGrain"
	)
	dockDetail(
		cylinder(parent, (position * CFrame.new(0, -3.1, 0)).Position, 0.85, 1.23, rgb(65, 69, 48), M.Wood),
		"TidalMark"
	)
	dockDetail(cylinder(parent, (position * CFrame.new(0, -0.5, 0)).Position, 0.18, 1.26, IRON, M.Metal), "PileCollar")
	for i = 0, 2 do
		dockDetail(
			cylinder(parent, (position * CFrame.new(0, 1.05 + i * 0.14, 0)).Position, 0.11, 1.3, ROPE, M.Fabric),
			"RopeLashing"
		)
	end
end

local function dockRope(parent: Model, frame: CFrame, a: Vector3, b: Vector3)
	local previous = frame:PointToWorldSpace(a)
	for i = 1, 4 do
		local t = i / 4
		local nextPoint = frame:PointToWorldSpace(a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * 0.24, 0))
		dockDetail(beam(parent, previous, nextPoint, 0.18, ROPE, nil, M.Fabric), "RopeRail")
		previous = nextPoint
	end
end

-- Warm inset panes with dark metal frames, mounted outside the walking lane.
local function dockLamp(parent: Model, frame: CFrame)
	local model = newModel("DockLamp", parent)
	part(model, Vector3.new(0.5, 4.8, 0.5), frame * CFrame.new(0, 2.4, 0), DOCK_PILE, M.Wood)
	part(model, Vector3.new(1.15, 0.18, 1.15), frame * CFrame.new(0, 4.85, 0), IRON, M.Metal)
	local pane = part(model, Vector3.new(0.76, 1.05, 0.76), frame * CFrame.new(0, 5.45, 0), rgb(255, 228, 163), M.Neon)
	dockDetail(pane, "LampPane")
	light(pane, rgb(255, 215, 148), 17, 1.15)
	for _, x in { -0.48, 0.48 } do
		for _, z in { -0.48, 0.48 } do
			dockDetail(
				part(model, Vector3.new(0.1, 1.2, 0.1), frame * CFrame.new(x, 5.45, z), IRON, M.Metal),
				"LampFrame"
			)
		end
	end
	dockDetail(part(model, Vector3.new(1.35, 0.22, 1.35), frame * CFrame.new(0, 6.12, 0), IRON, M.Metal), "LampCap")
end

type DockOptions = { innerSide: number?, junctionStart: number?, junctionEnd: number? }

-- Pier with an open central walk lane and an optional opening for the crosswalk.
function Props.dock(
	parent: Instance,
	start: Vector3,
	direction: Vector3,
	length: number,
	rng: Random,
	options: DockOptions?
): Vector3
	local m = newModel("Dock", parent)
	local origin = Vector3.new(start.X, 3, start.Z)
	local frame = CFrame.lookAt(origin, origin + Vector3.new(direction.X, 0, direction.Z))
	dockDeck(m, frame, 7, length, rng)
	local postsZ = { 1.2 }
	for z = 10.2, length - 2, 9 do
		table.insert(postsZ, z)
	end
	table.insert(postsZ, length - 1.2)
	for _, side in { -1, 1 } do
		local sidePosts = {}
		for _, z in postsZ do
			if
				not (
					options
					and side == options.innerSide
					and options.junctionStart
					and options.junctionEnd
					and z > options.junctionStart
					and z < options.junctionEnd
				)
			then
				table.insert(sidePosts, z)
			end
		end
		if options and side == options.innerSide and options.junctionStart and options.junctionEnd then
			if not table.find(sidePosts, options.junctionStart) then
				table.insert(sidePosts, options.junctionStart)
			end
			if not table.find(sidePosts, options.junctionEnd) then
				table.insert(sidePosts, options.junctionEnd)
			end
		end
		table.sort(sidePosts)
		for _, z in sidePosts do
			dockPile(m, frame, side * 3.85, -z, rng)
		end
		for i = 1, #sidePosts - 1 do
			local a, b = sidePosts[i], sidePosts[i + 1]
			if
				not (options and side == options.innerSide and a == options.junctionStart and b == options.junctionEnd)
			then
				dockRope(m, frame, Vector3.new(side * 3.85, 1.3, -a), Vector3.new(side * 3.85, 1.3, -b))
			end
		end
	end
	for i, z in postsZ do
		local bearer = part(m, Vector3.new(8.5, 0.65, 0.7), frame * CFrame.new(0, -1.1, -z), DOCK_PILE, M.Wood)
		bearer.Name = "Bearer"
		if i % 2 == 0 then
			for _, side in { -1, 1 } do
				local brace = beam(
					m,
					frame * Vector3.new(side * 3.85, -3.2, -z),
					frame * Vector3.new(side * 0.7, -1.45, -z),
					0.35,
					DOCK_WOOD,
					nil,
					M.Wood
				)
				brace.Name = "Brace"
			end
		end
	end
	local lampSide = if options and options.innerSide then -options.innerSide else 1
	dockLamp(m, frame * CFrame.new(lampSide * 4.15, 0.3, -(length - 1.2)))
	-- Keep the ladder beyond the tip and the landing free of loose props.
	Props.ladder(m, frame * CFrame.new(-1.5, 0, -length), -6)
	return (frame * CFrame.new(0, 0.3, -(length - 5))).Position
end

-- Matching boarded crosswalk. Local X spans 27 studs; both ends stay open.
function Props.dockLink(parent: Instance, frame: CFrame, rng: Random): Model
	local model = newModel("DockLink", parent)
	local along = frame * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(0, 0, 13.5)
	dockDeck(model, along, 5, 27, rng)
	for _, x in { -8, 0, 8 } do
		dockPile(model, frame, x, -3.1, rng)
		local joist = part(model, Vector3.new(0.7, 0.7, 6.6), frame * CFrame.new(x, -1.1, 0), DOCK_PILE, M.Wood)
		joist.Name = "Joist"
	end
	for _, a in { -8, 0 } do
		dockRope(model, frame, Vector3.new(a, 1.3, -3.1), Vector3.new(a + 8, 1.3, -3.1))
	end
	return model
end

-- Big striped lighthouse on a round stone platform. Its "LighthouseLens" part is spun by Map.animate.
function Props.lighthouse(parent: Instance, ground: Vector3): Model
	local m = newModel("Lighthouse", parent)
	local gx, gz = ground.X, ground.Z

	-- Round platform with a fence around the edge
	cylinder(m, Vector3.new(gx, ground.Y + 0.5, gz), 3, 36, STONE, M.Cobblestone)
	local fence = {}
	for i = 1, 20 do
		local a = i / 20 * TAU
		fence[i] = Vector3.new(gx + math.cos(a) * 17, ground.Y + 2, gz + math.sin(a) * 17)
		part(m, Vector3.new(0.5, 3, 0.5), CFrame.new(fence[i] + Vector3.new(0, 1.5, 0)), WOOD_DARK, M.Wood)
	end
	for i = 1, 20 do
		if i ~= 5 then -- gap facing the path
			beam(
				m,
				fence[i] + Vector3.new(0, 2.4, 0),
				fence[i % 20 + 1] + Vector3.new(0, 2.4, 0),
				0.3,
				WOOD,
				nil,
				M.WoodPlanks
			)
		end
	end

	local y = ground.Y + 2
	local r = 8.5
	for i = 1, 7 do
		cylinder(m, Vector3.new(gx, y + 4, gz), 8, r * 2, if i % 2 == 1 then WHITE else RED, M.Plaster)
		if i % 2 == 0 then
			for _, a in { 0, math.pi } do
				local face = CFrame.new(gx, y + 4, gz) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, r - 0.2)
				part(m, Vector3.new(1.6, 2.6, 0.6), face, rgb(50, 56, 62), M.Glass)
			end
		end
		y += 8
		r -= 0.5
	end
	part(m, Vector3.new(3, 6, 0.6), CFrame.new(gx, ground.Y + 5, gz) * CFrame.new(0, 0, 8.4), WOOD_DARK, M.WoodPlanks)

	-- Gallery with railing
	cylinder(m, Vector3.new(gx, y + 0.5, gz), 1, (r + 3) * 2, rgb(60, 56, 54), M.DiamondPlate)
	local rail = {}
	for i = 1, 16 do
		local a = i / 16 * TAU
		rail[i] = Vector3.new(gx + math.cos(a) * (r + 2.6), y + 1, gz + math.sin(a) * (r + 2.6))
		part(m, Vector3.new(0.3, 3, 0.3), CFrame.new(rail[i] + Vector3.new(0, 1.5, 0)), IRON, M.Metal)
	end
	for i = 1, 16 do
		beam(m, rail[i] + Vector3.new(0, 3, 0), rail[i % 16 + 1] + Vector3.new(0, 3, 0), 0.3, IRON, nil, M.Metal)
	end

	-- Lantern room
	local glass = cylinder(m, Vector3.new(gx, y + 4, gz), 6, (r - 0.5) * 2, rgb(255, 240, 200), M.SmoothPlastic)
	glass.Transparency = 0.5
	local lamp = ball(m, Vector3.new(gx, y + 4, gz), 3, LAMP, M.Neon)
	light(lamp, LAMP, 100, 3)

	local lens = part(m, Vector3.new(1, 1, 1), CFrame.new(gx, y + 4, gz), LAMP)
	lens.Name = "LighthouseLens"
	lens.Transparency = 1
	lens.CanCollide = false
	lens.CanQuery = false
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Range = 60
	spot.Angle = 35
	spot.Brightness = 8
	spot.Color = LAMP
	spot.Parent = lens
	local a0 = Instance.new("Attachment")
	a0.Parent = lens
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0, -180)
	a1.Parent = lens
	local ray = Instance.new("Beam")
	ray.Attachment0 = a0
	ray.Attachment1 = a1
	ray.Width0 = 3
	ray.Width1 = 40
	ray.FaceCamera = true
	ray.LightEmission = 1
	ray.Segments = 1
	ray.Color = ColorSequence.new(LAMP)
	ray.Transparency = NumberSequence.new(0.55, 1)
	ray.Parent = lens

	-- Domed cap
	cylinder(m, Vector3.new(gx, y + 7.3, gz), 0.6, (r + 0.6) * 2, RED, M.Metal)
	local cap = {}
	for i = 1, 8 do
		local a = i / 8 * TAU
		cap[i] = Vector3.new(gx + math.cos(a) * (r + 0.3), y + 7.6, gz + math.sin(a) * (r + 0.3))
	end
	LowPoly.pyramid(cap, Vector3.new(gx, y + 12, gz), RED, m, M.Metal)
	ball(m, Vector3.new(gx, y + 12.5, gz), 1.4, IRON, M.Metal)
	return m
end

-- Channel marker floating at the waterline.
function Props.buoy(parent: Instance, position: Vector3, rng: Random): Model
	local m = newModel("Buoy", parent)
	local color = if rng:NextNumber() < 0.5 then RED else WHITE
	cylinder(m, position + Vector3.new(0, 0.3, 0), 2.4, 5, color, M.Plastic)
	cylinder(m, position + Vector3.new(0, 1.6, 0), 0.5, 5.4, rgb(60, 56, 54), M.Rubber)
	local top = position + Vector3.new(0, 7, 0)
	for k = 0, 2 do
		local a = k * TAU / 3
		beam(m, position + Vector3.new(math.cos(a) * 1.8, 1.5, math.sin(a) * 1.8), top, 0.35, color, nil, M.Metal)
	end
	local lamp = part(m, Vector3.new(1.2, 1.2, 1.2), CFrame.new(top + Vector3.new(0, 0.6, 0)), LAMP, M.Neon)
	light(lamp, LAMP, 24, 2)
	return m
end

----------------------------------------------------------------------------------------------------
-- Harbour and village clutter

function Props.lampPost(parent: Instance, ground: Vector3): Model
	local m = newModel("LampPost", parent)
	part(m, Vector3.new(1.4, 0.8, 1.4), CFrame.new(ground + Vector3.new(0, 0.4, 0)), IRON, M.Metal)
	cylinder(m, ground + Vector3.new(0, 4.5, 0), 9, 0.55, IRON, M.Metal)
	part(m, Vector3.new(1.8, 0.4, 1.8), CFrame.new(ground + Vector3.new(0, 10.8, 0)), IRON, M.Metal)
	part(m, Vector3.new(0.8, 0.5, 0.8), CFrame.new(ground + Vector3.new(0, 11.2, 0)), IRON, M.Metal)
	local lamp = part(m, Vector3.new(1.1, 1.5, 1.1), CFrame.new(ground + Vector3.new(0, 9.8, 0)), LAMP, M.Neon)
	light(lamp, LAMP, 22, 1.2)
	return m
end

-- Small hanging lantern centred on `cframe`.
function Props.lantern(parent: Instance, cframe: CFrame, range: number?, brightness: number?): Model
	local m = newModel("Lantern", parent)
	part(m, Vector3.new(0.2, 1, 0.2), cframe * CFrame.new(0, 1.1, 0), IRON, M.Metal)
	part(m, Vector3.new(1.2, 0.3, 1.2), cframe * CFrame.new(0, 0.6, 0), IRON, M.Metal)
	part(m, Vector3.new(1.2, 0.2, 1.2), cframe * CFrame.new(0, -0.6, 0), IRON, M.Metal)
	local glow = part(m, Vector3.new(0.9, 1, 0.9), cframe, LAMP, M.Neon)
	light(glow, LAMP, range or 14, brightness or 1)
	return m
end

-- Festoon of coloured bulbs sagging between two points.
function Props.stringLights(parent: Instance, a: Vector3, b: Vector3, rng: Random, sag: number?): Model
	local m = newModel("StringLights", parent)
	local colors = { rgb(255, 200, 120), rgb(255, 150, 60), rgb(170, 110, 255), rgb(120, 220, 255) }
	local droop = sag or (b - a).Magnitude * 0.08
	local count = math.max(4, math.floor((b - a).Magnitude / 4))
	local prev = a
	for i = 1, count do
		local t = i / count
		local p = a:Lerp(b, t) - Vector3.new(0, droop * 4 * t * (1 - t), 0)
		beam(m, prev, p, 0.12, IRON, nil, M.Fabric)
		if i < count then
			local bulb = ball(m, p - Vector3.new(0, 0.35, 0), 0.5, Props.pick(rng, colors), M.Neon)
			bulb.CanCollide = false
			bulb.CastShadow = false
		end
		prev = p
	end
	return m
end

-- Red-and-white life ring hung on a wall; `cframe` faces out of the wall.
function Props.lifeRing(parent: Instance, cframe: CFrame): Model
	local m = newModel("LifeRing", parent)
	local sides = 8
	for i = 1, sides do
		local a0, a1 = (i - 1) / sides * TAU, i / sides * TAU
		local p0 = cframe:PointToWorldSpace(Vector3.new(math.cos(a0) * 1.3, math.sin(a0) * 1.3, 0))
		local p1 = cframe:PointToWorldSpace(Vector3.new(math.cos(a1) * 1.3, math.sin(a1) * 1.3, 0))
		beam(m, p0, p1, 0.55, if i % 2 == 0 then RED else WHITE, 0.55, M.Plastic)
	end
	return m
end

-- Ladder hanging down from `top` (its local -Z is out over the water) to height `bottomY`.
function Props.ladder(parent: Instance, top: CFrame, bottomY: number): Model
	local m = newModel("Ladder", parent)
	local height = top.Position.Y - bottomY
	for side = -1, 1, 2 do
		part(
			m,
			Vector3.new(0.3, height + 1.5, 0.3),
			top * CFrame.new(side * 0.9, -height / 2 + 0.75, -0.3),
			WOOD_DARK,
			M.Wood
		)
	end
	for y = 0.8, height, 1.4 do
		part(m, Vector3.new(1.8, 0.2, 0.25), top * CFrame.new(0, -y + 0.8, -0.3), WOOD, M.Wood)
	end
	return m
end

function Props.ropeCoil(parent: Instance, ground: Vector3): Model
	local m = newModel("RopeCoil", parent)
	cylinder(m, ground + Vector3.new(0, 0.3, 0), 0.6, 2.6, ROPE, M.Fabric)
	cylinder(m, ground + Vector3.new(0, 0.75, 0), 0.4, 1.8, ROPE, M.Fabric)
	return m
end

-- Netted crab pot.
function Props.crabPot(parent: Instance, ground: Vector3, rng: Random): Model
	local m = newModel("CrabPot", parent)
	local frame = CFrame.new(ground + Vector3.new(0, 1, 0)) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
	local net = part(m, Vector3.new(3, 1.8, 2.2), frame, rgb(120, 130, 120), M.Fabric)
	net.Transparency = 0.35
	for _, y in { -0.9, 0.9 } do
		part(m, Vector3.new(3.1, 0.15, 2.3), frame * CFrame.new(0, y, 0), IRON, M.Metal)
	end
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		part(m, Vector3.new(0.15, 1.8, 0.15), frame * CFrame.new(c[1] * 1.5, 0, c[2] * 1.1), IRON, M.Metal)
	end
	part(m, Vector3.new(0.4, 0.4, 0.4), frame * CFrame.new(0.4, 0, 0), rgb(220, 100, 60), M.Plastic)
	return m
end

function Props.barrel(parent: Instance, ground: Vector3, rng: Random): Model
	local m = newModel("Barrel", parent)
	local center = ground + Vector3.new(0, 1.5, 0)
	cylinder(m, center, 3, 2.3, shade(WOOD, rng, 0.1), M.WoodPlanks)
	cylinder(m, center + Vector3.new(0, 0.8, 0), 0.3, 2.45, IRON, M.Metal)
	cylinder(m, center - Vector3.new(0, 0.8, 0), 0.3, 2.45, IRON, M.Metal)
	return m
end

function Props.crates(parent: Instance, ground: Vector3, rng: Random): Model
	local m = newModel("Crates", parent)
	local y = ground.Y
	for i = 1, rng:NextInteger(1, 3) do
		local s = rng:NextNumber(2.4, 3.4)
		local offset = if i == 3
			then Vector3.zero
			else Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
		local at = Vector3.new(ground.X, y + s / 2, ground.Z) + offset
		part(
			m,
			Vector3.new(s, s, s),
			CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
			shade(WOOD, rng, 0.12),
			M.WoodPlanks
		)
		if i == 2 then
			y += s
		end
	end
	return m
end

function Props.bench(parent: Instance, ground: Vector3, facing: number): Model
	local m = newModel("Bench", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	part(m, Vector3.new(5, 0.4, 1.6), base * CFrame.new(0, 1.6, 0), WOOD, M.WoodPlanks)
	part(m, Vector3.new(5, 1.4, 0.3), base * CFrame.new(0, 2.6, -0.8) * CFrame.Angles(-0.2, 0, 0), WOOD, M.WoodPlanks)
	for side = -1, 1, 2 do
		part(m, Vector3.new(0.4, 1.6, 1.4), base * CFrame.new(side * 2.1, 0.8, 0), IRON, M.Metal)
	end
	return m
end

-- Signpost with an arrow board per entry ({text, angle relative to `facing`}).
function Props.signpost(parent: Instance, ground: Vector3, facing: number, arrows: { { any } }): Model
	local m = newModel("Signpost", parent)
	part(m, Vector3.new(0.6, 8, 0.6), CFrame.new(ground + Vector3.new(0, 4, 0)), WOOD_DARK, M.Wood)
	for i, arrow in arrows do
		local board = part(
			m,
			Vector3.new(5, 1.2, 0.3),
			CFrame.new(ground + Vector3.new(0, 7.4 - i * 1.5, 0))
				* CFrame.Angles(0, facing + arrow[2], 0)
				* CFrame.new(2.4, 0, 0),
			WOOD,
			M.WoodPlanks
		)
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 40
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.Garamond
			label.TextScaled = true
			label.TextColor3 = rgb(40, 30, 22)
			label.Text = arrow[1]
			label.Parent = gui
			gui.Parent = board
		end
	end
	return m
end

-- Market stall with a striped canopy and a counter of fish; faces its local +Z.
function Props.stall(parent: Instance, ground: Vector3, facing: number, rng: Random, canopy: Color3): Model
	local m = newModel("Stall", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	part(m, Vector3.new(9, 3, 3), base * CFrame.new(0, 1.5, 1.5), WOOD, M.WoodPlanks)
	part(m, Vector3.new(9.4, 0.3, 3.4), base * CFrame.new(0, 3.1, 1.5), WOOD_DARK, M.Wood)
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		part(m, Vector3.new(0.5, 8, 0.5), base * CFrame.new(c[1] * 4.3, 4, c[2] * 2.5 + 0.5), WOOD_DARK, M.Wood)
	end
	for i = 0, 4 do
		local stripe = if i % 2 == 0 then canopy else WHITE
		part(
			m,
			Vector3.new(2, 0.3, 7),
			base * CFrame.new(-4 + i * 2, 8.2, 0.5) * CFrame.Angles(0.18, 0, 0),
			stripe,
			M.Fabric
		)
	end
	part(m, Vector3.new(8.6, 1.2, 2.4), base * CFrame.new(0, 3.5, 1.5), rgb(200, 220, 230), M.Ice)
	for k = 1, 4 do
		local fish = base * CFrame.new(-3.5 + k * 1.6, 4.2, 1.5) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0)
		part(m, Vector3.new(0.6, 0.4, 1.8), fish, shade(rgb(150, 160, 170), rng, 0.15), M.Foil)
	end
	Props.lantern(m, base * CFrame.new(3.8, 6.6, 3.2))
	Props.crates(m, base:PointToWorldSpace(Vector3.new(5.8, 0, -1)), rng)
	return m
end

function Props.well(parent: Instance, ground: Vector3): Model
	local m = newModel("Well", parent)
	cylinder(m, ground + Vector3.new(0, 1.5, 0), 3, 7, STONE, M.Cobblestone)
	cylinder(m, ground + Vector3.new(0, 2.9, 0), 0.4, 5.6, rgb(40, 70, 80), M.Glass)
	for side = -1, 1, 2 do
		part(m, Vector3.new(0.6, 7, 0.6), CFrame.new(ground + Vector3.new(side * 3, 5, 0)), WOOD_DARK, M.Wood)
	end
	part(m, Vector3.new(6.4, 0.4, 0.4), CFrame.new(ground + Vector3.new(0, 6.2, 0)), WOOD_DARK, M.Wood)
	part(m, Vector3.new(1, 1.4, 1), CFrame.new(ground + Vector3.new(0, 5, 0)), WOOD, M.WoodPlanks)
	for side = -1, 1, 2 do
		part(
			m,
			Vector3.new(8, 0.4, 3.4),
			CFrame.new(ground + Vector3.new(0, 8.6, side * 1.4)) * CFrame.Angles(side * 0.5, 0, 0),
			RED,
			M.RoofShingles
		)
	end
	return m
end

-- Two posts with fish hung out to dry.
function Props.fishRack(parent: Instance, ground: Vector3, facing: number, rng: Random): Model
	local m = newModel("FishRack", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	for side = -1, 1, 2 do
		part(m, Vector3.new(0.5, 6, 0.5), base * CFrame.new(side * 4, 3, 0), WOOD_DARK, M.Wood)
	end
	part(m, Vector3.new(8.6, 0.4, 0.4), base * CFrame.new(0, 5.8, 0), WOOD_DARK, M.Wood)
	for k = 1, 4 do
		part(
			m,
			Vector3.new(0.5, 1.8, 0.3),
			base * CFrame.new(-4 + k * 1.6, 4.6, 0),
			shade(rgb(160, 168, 172), rng, 0.15),
			M.Foil
		)
	end
	return m
end

-- Low wooden fence between two points.
function Props.fence(parent: Instance, a: Vector3, b: Vector3): Model
	local m = newModel("Fence", parent)
	local length = (b - a).Magnitude
	local count = math.max(1, math.floor(length / 4))
	for i = 0, count do
		part(m, Vector3.new(0.4, 2.6, 0.4), CFrame.new(a:Lerp(b, i / count) + Vector3.new(0, 1.3, 0)), WOOD, M.Wood)
	end
	for _, y in { 1, 2.1 } do
		beam(m, a + Vector3.new(0, y, 0), b + Vector3.new(0, y, 0), 0.25, WOOD, nil, M.WoodPlanks)
	end
	return m
end

function Props.flag(parent: Instance, ground: Vector3, color: Color3): Model
	local m = newModel("Flag", parent)
	cylinder(m, ground + Vector3.new(0, 9, 0), 18, 0.5, rgb(70, 66, 62), M.Metal)
	part(m, Vector3.new(0.2, 4, 6), CFrame.new(ground + Vector3.new(0, 15.6, 3.2)), color, M.Fabric)
	ball(m, ground + Vector3.new(0, 18.2, 0), 0.9, rgb(200, 170, 80), M.Metal)
	return m
end

----------------------------------------------------------------------------------------------------
-- Beach

-- Striped beach umbrella on a pole stuck in the sand.
function Props.beachUmbrella(parent: Instance, ground: Vector3, rng: Random, color: Color3): Model
	local m = newModel("BeachUmbrella", parent)
	local lean = CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12))
	local base = CFrame.new(ground) * lean
	local function at(x: number, y: number, z: number): Vector3
		return base:PointToWorldSpace(Vector3.new(x, y, z))
	end
	beam(m, at(0, -1, 0), at(0, 9.4, 0), 0.35, WHITE, nil, M.Metal)
	local apex, inside = at(0, 9.4, 0), at(0, 7, 0)
	for i = 1, 10 do
		local a0, a1 = i / 10 * TAU, (i + 1) / 10 * TAU
		local r0 = at(math.cos(a0) * 5.4, 7.8, math.sin(a0) * 5.4)
		local r1 = at(math.cos(a1) * 5.4, 7.8, math.sin(a1) * 5.4)
		local stripe = if i % 2 == 0 then color else WHITE
		LowPoly.triangle(r0, r1, apex, inside, stripe, m, M.Fabric)
		-- Scalloped valance hanging from the rim
		beam(m, r0 - Vector3.new(0, 0.35, 0), r1 - Vector3.new(0, 0.35, 0), 0.1, stripe, 0.7, M.Fabric)
	end
	ball(m, apex + Vector3.new(0, 0.3, 0), 0.6, WHITE, M.Plastic)
	return m
end

-- Sun lounger with a raised backrest; the foot end points along `facing`.
function Props.sunLounger(parent: Instance, ground: Vector3, facing: number, color: Color3): Model
	local m = newModel("SunLounger", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	part(m, Vector3.new(2.6, 0.3, 4.6), base * CFrame.new(0, 1.2, 1), WHITE, M.Plastic)
	part(m, Vector3.new(2.3, 0.25, 4.4), base * CFrame.new(0, 1.45, 1), color, M.Fabric)
	local back = base * CFrame.new(0, 1.3, -1.3) * CFrame.Angles(0.75, 0, 0) * CFrame.new(0, 0, -1.3)
	part(m, Vector3.new(2.6, 0.3, 2.6), back, WHITE, M.Plastic)
	part(m, Vector3.new(2.3, 0.25, 2.4), back * CFrame.new(0, 0.25, 0), color, M.Fabric)
	part(m, Vector3.new(1.4, 0.45, 0.7), back * CFrame.new(0, 0.5, -0.8), WHITE, M.Fabric)
	for _, x in { -1.1, 1.1 } do
		for _, z in { -1.1, 3 } do
			part(m, Vector3.new(0.25, 1.1, 0.25), base * CFrame.new(x, 0.55, z), WHITE, M.Plastic)
		end
	end
	return m
end

-- Striped towel following the sand's slope, built from adjoining fabric panels.
function Props.towel(parent: Instance, ground: Vector3, facing: number, color: Color3, normal: Vector3?): Model
	local m = newModel("Towel", parent)
	local up = if normal and normal.Magnitude > 0.001 then normal.Unit else Vector3.yAxis
	local right = Vector3.new(math.cos(facing), 0, -math.sin(facing))
	right -= up * right:Dot(up)
	if right.Magnitude < 0.001 then
		right = if math.abs(up.Y) < 0.9 then Vector3.yAxis:Cross(up) else Vector3.zAxis:Cross(up)
	end
	right = right.Unit
	local base = CFrame.fromMatrix(ground, right, up, right:Cross(up))
	local function panel(from: number, to: number, tint: Color3)
		local fabric =
			part(m, Vector3.new(2.8, 0.1, to - from), base * CFrame.new(0, 0.05, (from + to) / 2), tint, M.Fabric)
		fabric.CanCollide = false
		fabric.CanTouch = false
		fabric.CanQuery = false
		fabric.CastShadow = false
	end
	local edge = -2.8
	for _, z in { -2, 0, 2 } do
		panel(edge, z - 0.25, color)
		panel(z - 0.25, z + 0.25, WHITE)
		edge = z + 0.25
	end
	panel(edge, 2.8, color)
	return m
end

-- White lifeguard tower on stilts with a red roof, a ladder at the back and a life ring.
function Props.lifeguardTower(parent: Instance, ground: Vector3, facing: number): Model
	local m = newModel("LifeguardTower", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	local floor = 8
	for _, x in { -2.6, 2.6 } do
		for _, z in { -2.6, 2.6 } do
			beam(
				m,
				base * Vector3.new(x * 1.25, -1, z * 1.25),
				base * Vector3.new(x, floor, z),
				0.6,
				WHITE,
				nil,
				M.Wood
			)
		end
	end
	for _, z in { -3.05, 3.05 } do
		beam(m, base * Vector3.new(-3.05, 2, z), base * Vector3.new(3.05, 2, z), 0.3, WHITE, nil, M.Wood)
	end
	part(m, Vector3.new(7, 0.5, 7), base * CFrame.new(0, floor, 0), WOOD, M.WoodPlanks)
	-- Cabin: low walls round three sides, open toward the sea
	part(m, Vector3.new(6.4, 3, 0.3), base * CFrame.new(0, floor + 1.7, -3.1), WHITE, M.WoodPlanks)
	for side = -1, 1, 2 do
		part(m, Vector3.new(0.3, 3, 6.4), base * CFrame.new(side * 3.1, floor + 1.7, 0), WHITE, M.WoodPlanks)
		part(m, Vector3.new(0.3, 3.6, 0.3), base * CFrame.new(side * 3.1, floor + 5, 3.1), WHITE, M.Wood)
	end
	part(m, Vector3.new(6.4, 1.2, 0.3), base * CFrame.new(0, floor + 0.8, 3.1), RED, M.WoodPlanks)
	part(m, Vector3.new(8, 0.4, 8), base * CFrame.new(0, floor + 7, 0) * CFrame.Angles(0.12, 0, 0), RED, M.WoodPlanks)
	-- Ladder up the back
	local ladderTop, ladderFoot = base * Vector3.new(0, floor, -3.6), base * Vector3.new(0, 0, -7)
	for side = -1, 1, 2 do
		local offset = base:VectorToWorldSpace(Vector3.new(side * 0.9, 0, 0))
		beam(m, ladderFoot + offset, ladderTop + offset, 0.25, WOOD, nil, M.Wood)
	end
	for k = 1, 7 do
		beam(
			m,
			ladderFoot:Lerp(ladderTop, k / 8) + base:VectorToWorldSpace(Vector3.new(-0.9, 0, 0)),
			ladderFoot:Lerp(ladderTop, k / 8) + base:VectorToWorldSpace(Vector3.new(0.9, 0, 0)),
			0.2,
			WOOD,
			nil,
			M.Wood
		)
	end
	Props.lifeRing(m, base * CFrame.new(0, floor + 1.7, 3.3))
	-- Red flag on a pole beside it
	cylinder(m, base * Vector3.new(4.6, 7, -1), 14, 0.3, WHITE, M.Metal)
	part(
		m,
		Vector3.new(0.15, 2, 3),
		CFrame.new(base * Vector3.new(4.6, 13, -1)) * CFrame.Angles(0, facing, 0) * CFrame.new(0, 0, 1.5),
		RED,
		M.Fabric
	)
	return m
end

-- Striped changing cabana with a pointed roof; the doorway faces along `facing`.
function Props.cabana(parent: Instance, ground: Vector3, facing: number, color: Color3): Model
	local m = newModel("Cabana", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	local w, h = 5, 7
	part(m, Vector3.new(w + 1, 0.4, w + 1), base * CFrame.new(0, 0.2, 0), WOOD, M.WoodPlanks)
	for i = 0, 4 do
		local x = -w / 2 + (i + 0.5) * w / 5
		local stripe = if i % 2 == 0 then color else WHITE
		part(m, Vector3.new(w / 5, h, 0.2), base * CFrame.new(x, h / 2 + 0.4, -w / 2), stripe, M.Fabric)
		part(m, Vector3.new(0.2, h, w / 5), base * CFrame.new(w / 2, h / 2 + 0.4, x), stripe, M.Fabric)
		part(m, Vector3.new(0.2, h, w / 5), base * CFrame.new(-w / 2, h / 2 + 0.4, x), stripe, M.Fabric)
	end
	-- Curtains drawn back either side of the door
	for side = -1, 1, 2 do
		part(m, Vector3.new(1.4, h, 0.25), base * CFrame.new(side * 1.8, h / 2 + 0.4, w / 2), color, M.Fabric)
	end
	part(m, Vector3.new(w + 0.4, 0.6, w + 0.4), base * CFrame.new(0, h + 0.7, 0), WHITE, M.Wood)
	local roof = {
		base * Vector3.new(-w / 2 - 0.6, h + 1, -w / 2 - 0.6),
		base * Vector3.new(w / 2 + 0.6, h + 1, -w / 2 - 0.6),
		base * Vector3.new(w / 2 + 0.6, h + 1, w / 2 + 0.6),
		base * Vector3.new(-w / 2 - 0.6, h + 1, w / 2 + 0.6),
	}
	LowPoly.pyramid(roof, base * Vector3.new(0, h + 4.5, 0), color, m, M.Fabric)
	ball(m, base * Vector3.new(0, h + 4.8, 0), 0.6, WHITE, M.Wood)
	return m
end

-- Bleached driftwood log half sunk in the sand, with a stub of branch.
function Props.driftwood(parent: Instance, ground: Vector3, rng: Random): Model
	local m = newModel("Driftwood", parent)
	local a = rng:NextNumber(0, TAU)
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local length = rng:NextNumber(6, 11)
	local color = shade(rgb(196, 182, 160), rng, 0.06)
	local p0, p1 =
		ground - dir * length / 2 + Vector3.new(0, 0.3, 0), ground + dir * length / 2 + Vector3.new(0, 0.5, 0)
	beam(m, p0, p1, rng:NextNumber(0.9, 1.4), color, nil, M.Wood)
	local fork = p0:Lerp(p1, 0.7)
	beam(m, fork, fork + (dir + Vector3.new(-dir.Z, 0.5, dir.X)).Unit * 3, 0.45, color, nil, M.Wood)
	return m
end

-- A scatter of shells and pebbles round `ground`.
function Props.shells(parent: Instance, ground: Vector3, rng: Random): Model
	local m = newModel("Shells", parent)
	local colors = { rgb(246, 228, 214), rgb(236, 190, 170), rgb(214, 196, 168), rgb(250, 244, 236) }
	for _ = 1, rng:NextInteger(4, 8) do
		local p = ground + Vector3.new(rng:NextNumber(-4, 4), 0.1, rng:NextNumber(-4, 4))
		local s = rng:NextNumber(0.35, 0.7)
		local shell = part(
			m,
			Vector3.new(s, s * 0.4, s * 1.2),
			CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
			shade(Props.pick(rng, colors), rng, 0.05),
			M.Marble
		)
		shell.CanCollide = false
	end
	return m
end

-- Little sandcastle with four towers, a keep and a flag, ringed by a moat.
function Props.sandcastle(parent: Instance, ground: Vector3, color: Color3): Model
	local m = newModel("Sandcastle", parent)
	cylinder(m, ground + Vector3.new(0, 0.05, 0), 0.1, 7.5, rgb(120, 140, 130), M.SmoothPlastic).Transparency = 0.3
	part(m, Vector3.new(4, 1.2, 4), CFrame.new(ground + Vector3.new(0, 0.6, 0)), color, M.Sand)
	for _, x in { -1.8, 1.8 } do
		for _, z in { -1.8, 1.8 } do
			cylinder(m, ground + Vector3.new(x, 1, z), 2, 1.2, color, M.Sand)
			LowPoly.pyramid({
				ground + Vector3.new(x - 0.6, 2, z - 0.6),
				ground + Vector3.new(x + 0.6, 2, z - 0.6),
				ground + Vector3.new(x + 0.6, 2, z + 0.6),
				ground + Vector3.new(x - 0.6, 2, z + 0.6),
			}, ground + Vector3.new(x, 2.8, z), color, m, M.Sand)
		end
	end
	part(m, Vector3.new(1.8, 2.2, 1.8), CFrame.new(ground + Vector3.new(0, 2.3, 0)), color, M.Sand)
	cylinder(m, ground + Vector3.new(0, 4, 0), 1.6, 0.1, WOOD, M.Wood)
	part(m, Vector3.new(0.05, 0.5, 0.8), CFrame.new(ground + Vector3.new(0, 4.5, 0.4)), RED, M.Fabric)
	return m
end

-- Beach volleyball net between two posts, with a ball lying nearby.
function Props.volleyballNet(parent: Instance, ground: Vector3, facing: number): Model
	local m = newModel("VolleyballNet", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	for side = -1, 1, 2 do
		cylinder(m, base * Vector3.new(side * 9, 4, 0), 9, 0.4, WHITE, M.Metal)
	end
	local net = part(m, Vector3.new(18, 3, 0.1), base * CFrame.new(0, 6.2, 0), rgb(40, 40, 44), M.Fabric)
	net.Transparency = 0.45
	part(m, Vector3.new(18, 0.4, 0.15), base * CFrame.new(0, 7.8, 0), WHITE, M.Fabric)
	-- Court boundary lines meet at the corners without overlapping their top faces.
	for _, z in { -8, 8 } do
		part(m, Vector3.new(18.3, 0.08, 0.3), base * CFrame.new(0, 0.04, z), WHITE, M.Fabric).CanCollide = false
	end
	for _, x in { -9, 9 } do
		part(m, Vector3.new(0.3, 0.08, 15.7), base * CFrame.new(x, 0.04, 0), WHITE, M.Fabric).CanCollide = false
	end
	Props.beachBall(m, base * Vector3.new(3, 0, 4))
	return m
end

-- Beach ball in segments of bright colour.
function Props.beachBall(parent: Instance, ground: Vector3): Model
	local m = newModel("BeachBall", parent)
	ball(m, ground + Vector3.new(0, 0.9, 0), 1.8, WHITE, M.SmoothPlastic)
	local colors = { RED, rgb(240, 200, 50), rgb(40, 110, 190) }
	for i, color in colors do
		local band = part(
			m,
			Vector3.new(0.45, 1.85, 1.85),
			CFrame.new(ground + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, i / #colors * math.pi, 0),
			color,
			M.SmoothPlastic
		)
		band.Shape = Enum.PartType.Cylinder
	end
	return m
end

-- Clump of washed-up seaweed along the tide line.
function Props.seaweed(parent: Instance, ground: Vector3, rng: Random): Model
	local m = newModel("Seaweed", parent)
	for _ = 1, rng:NextInteger(3, 6) do
		local p = ground + Vector3.new(rng:NextNumber(-2.5, 2.5), 0.08, rng:NextNumber(-2.5, 2.5))
		local strand = part(
			m,
			Vector3.new(rng:NextNumber(0.5, 1.1), 0.15, rng:NextNumber(2, 4)),
			CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
			shade(rgb(64, 84, 46), rng, 0.15),
			M.Grass
		)
		strand.CanCollide = false
	end
	return m
end

----------------------------------------------------------------------------------------------------
-- Volcanic effects

local function anchor(parent: Instance, position: Vector3): Part
	local p = part(parent, Vector3.new(4, 1, 4), CFrame.new(position), LAVA)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	return p
end

local function smoke(parent: BasePart, size: number, rise: number)
	local s = Instance.new("Smoke")
	s.Color = rgb(70, 64, 62)
	s.Opacity = 0.22
	s.Size = size
	s.RiseVelocity = rise
	s.Parent = parent
end

function Props.lavaPool(parent: Instance, ground: Vector3, rng: Random, diameter: number?): Model
	local m = newModel("LavaPool", parent)
	local d = diameter or rng:NextNumber(6, 14)
	cylinder(m, ground + Vector3.new(0, 0.1, 0), 0.3, d + 3, rgb(60, 40, 36), M.CrackedLava)
	local pool = cylinder(m, ground + Vector3.new(0, 0.2, 0), 0.4, d, LAVA, M.Neon)
	light(pool, LAVA, d * 2.5, 2)
	return m
end

-- Glowing ribbon following a list of surface points.
function Props.lavaFlow(parent: Instance, points: { Vector3 })
	local m = newModel("LavaFlow", parent)
	for i = 1, #points - 1 do
		local width = 7 - 4 * i / #points
		local lift = Vector3.new(0, 0.6, 0)
		local p = beam(m, points[i] + lift, points[i + 1] + lift, width, LAVA, 0.5, M.Neon)
		if i % 4 == 1 then
			light(p, LAVA, 40, 1.5)
		end
	end
end

function Props.vent(parent: Instance, ground: Vector3)
	smoke(anchor(parent, ground + Vector3.new(0, 2, 0)), 14, 10)
end

-- Lava lake in a volcano's crater with rising smoke and embers.
function Props.crater(parent: Instance, center: Vector3, radius: number, rimY: number)
	local m = newModel("Crater", parent)
	local lake = cylinder(m, center + Vector3.new(0, 1, 0), 0.6, radius * 2, LAVA, M.Neon)
	light(lake, LAVA, 60, 5)

	local embers = Instance.new("ParticleEmitter")
	embers.Color = ColorSequence.new(rgb(255, 180, 80), rgb(255, 70, 20))
	embers.LightEmission = 1
	embers.Size = NumberSequence.new(0.8, 0)
	embers.Lifetime = NumberRange.new(2, 5)
	embers.Rate = 25
	embers.Speed = NumberRange.new(15, 35)
	embers.SpreadAngle = Vector2.new(25, 25)
	embers.Acceleration = Vector3.new(0, -6, 0)
	embers.Parent = anchor(m, center + Vector3.new(0, 2, 0))

	smoke(anchor(m, Vector3.new(center.X, rimY + 10, center.Z)), 60, 18)
end

return Props
