-- Mediterranean set dressing for Harbour Isle: whitewashed cube houses, pastel townhouses, villas,
-- domed chapels, windmills, olive and cypress trees, and the fittings of a piazza.
-- Builders follow the Props conventions: a ground position, a facing (front on local +Z), parts in a new Model.

local LowPoly = require(script.Parent.LowPoly)
local Props = require(script.Parent.Props)

local Med = {}

local TAU = math.pi * 2
local rgb = Color3.fromRGB
local M = Enum.Material
local part, cylinder, beam, blob, ball = Props.part, Props.cylinder, Props.beam, Props.blob, Props.ball
local light, shade, pick = Props.light, Props.shade, Props.pick

local WHITEWASH = rgb(242, 240, 232)
local OFFWHITE = rgb(226, 222, 210)
local AEGEAN = rgb(36, 92, 168)
local TERRACOTTA = rgb(184, 92, 58)
local STONE = rgb(204, 192, 168)
local STONE_WALL = rgb(168, 154, 130)
local IRON = rgb(44, 42, 40)
local BRASS = rgb(186, 148, 70)
local WOOD = rgb(122, 92, 64)
local WOOD_DARK = rgb(78, 60, 46)
local TRUNK = rgb(96, 76, 58)
local OLIVE_BARK = rgb(112, 100, 86)
local LAMP = rgb(255, 210, 140)
local GLASS = rgb(44, 60, 76)
local DIRT = rgb(170, 132, 92)
local LEAF = rgb(70, 104, 56)
local VINE = rgb(84, 122, 58)
local CYPRESS = rgb(46, 72, 50)
local STONE_PINE = rgb(62, 92, 56)
local LAVENDER = rgb(146, 112, 196)
local CANVAS = rgb(240, 234, 218)
local WATER = rgb(78, 160, 178)

Med.WHITEWASH = WHITEWASH
Med.AEGEAN = AEGEAN

local SHUTTERS = { rgb(36, 92, 168), rgb(28, 120, 150), rgb(40, 70, 130), rgb(64, 118, 72), rgb(92, 126, 66) }
local TOWN_SHUTTERS = { rgb(64, 110, 72), rgb(92, 126, 66), rgb(112, 74, 52), rgb(40, 96, 120), rgb(150, 120, 60) }
local PASTELS = {
	rgb(236, 206, 150),
	rgb(232, 176, 140),
	rgb(242, 224, 184),
	rgb(216, 152, 112),
	rgb(246, 234, 204),
	rgb(224, 190, 120),
	rgb(210, 128, 96),
}
local ROOF_TILES = { rgb(184, 92, 58), rgb(166, 80, 52), rgb(196, 110, 70), rgb(150, 70, 48) }
local BLOOMS = { rgb(206, 44, 122), rgb(226, 80, 156), rgb(180, 40, 110), rgb(236, 120, 170) }
local OLIVE_LEAF = { rgb(128, 140, 96), rgb(112, 126, 86), rgb(142, 152, 110) }
local AWNINGS = { rgb(180, 52, 44), rgb(36, 92, 168), rgb(56, 120, 70), rgb(214, 160, 50), rgb(120, 60, 110) }
local SHOPS = { "Taverna", "Bakery", "Caffè", "Fishmonger", "Gelato", "Olive Oil", "Pottery", "Enoteca", "Bottega" }

type Look = {
	frame: Color3,
	shutter: Color3?,
	arched: boolean,
	winW: number,
	winH: number,
	spacing: number,
}

type Facade = {
	floor: number,
	storyH: number,
	stories: number,
	doorX: number?,
	doorGap: number?,
	skipSide: number?,
	extras: ((side: number, story: number, face: CFrame) -> ())?,
}

local function newModel(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

----------------------------------------------------------------------------------------------------
-- Facade pieces

-- Frame on the outer surface of one wall of a w x d block standing on `base`, `y` up from it.
-- Side 0 is the front (+Z), 1 is +X, 2 the back, 3 is -X. +Z of the frame points out of the wall.
local function wallFace(base: CFrame, w: number, d: number, side: number, y: number): (CFrame, number)
	local outward = if side % 2 == 0 then d / 2 else w / 2
	local width = if side % 2 == 0 then w else d
	return base * CFrame.Angles(0, side * math.pi / 2, 0) * CFrame.new(0, y, outward), width
end

-- Upright disc on a wall (arch heads, round windows, clock faces); `face` is its centre.
local function disc(
	m: Model,
	face: CFrame,
	diameter: number,
	thickness: number,
	color: Color3,
	material: Enum.Material
): Part
	local p = cylinder(m, Vector3.zero, thickness, diameter, color, material)
	p.CFrame = face * CFrame.Angles(0, math.pi / 2, 0)
	return p
end

-- Window centred on `face`, with a plaster surround, sill, optional arched head and open shutters.
local function window(
	m: Model,
	face: CFrame,
	width: number,
	height: number,
	frame: Color3,
	shutter: Color3?,
	arched: boolean,
	lit: boolean
): Part
	local color, material = if lit then LAMP else GLASS, if lit then M.Neon else M.Glass
	part(m, Vector3.new(width + 0.8, height + 0.8, 0.12), face * CFrame.new(0, 0, 0.06), frame, M.Plaster)
	local glassDepth = if arched then 0.18 else 0.1
	local glass = part(m, Vector3.new(width, height, 0.2), face * CFrame.new(0, 0, glassDepth), color, material)
	local mullionDepth = if arched then 0.44 else 0.26
	part(m, Vector3.new(0.15, height, mullionDepth), face * CFrame.new(0, 0, mullionDepth / 2), frame, M.Wood)
	if arched then
		-- Overlapping arch, glazing and mullion faces stay 0.08 studs apart.
		disc(m, face * CFrame.new(0, height / 2, 0.14), width + 0.8, 0.12, frame, M.Plaster)
		disc(m, face * CFrame.new(0, height / 2, 0.27), width, 0.18, color, material)
	end
	part(m, Vector3.new(width + 1.4, 0.35, 0.9), face * CFrame.new(0, -height / 2 - 0.35, 0.4), frame, M.Plaster)
	if shutter then
		for flap = -1, 1, 2 do
			part(
				m,
				Vector3.new(width / 2 + 0.1, height + 0.2, 0.15),
				face * CFrame.new(flap * (width * 0.75 + 0.55), 0, 0.1),
				shutter,
				M.WoodPlanks
			)
		end
	end
	return glass
end

-- Door standing on `face` (bottom centre on the wall) with a surround, handle and a stone step.
local function door(
	m: Model,
	face: CFrame,
	width: number,
	height: number,
	color: Color3,
	frame: Color3,
	arched: boolean
): Part
	part(
		m,
		Vector3.new(width + 1, height + 0.5, 0.12),
		face * CFrame.new(0, (height + 0.5) / 2, 0.06),
		frame,
		M.Plaster
	)
	local leaf = part(m, Vector3.new(width, height, 0.3), face * CFrame.new(0, height / 2, 0.15), color, M.WoodPlanks)
	if arched then
		disc(m, face * CFrame.new(0, height + 0.5, 0.14), width + 1, 0.12, frame, M.Plaster)
		disc(m, face * CFrame.new(0, height, 0.25), width, 0.26, color, M.WoodPlanks)
	end
	ball(m, (face * CFrame.new(width * 0.3, height * 0.45, 0.4)).Position, 0.35, BRASS, M.Metal)
	part(m, Vector3.new(width + 2.2, 0.5, 1.8), face * CFrame.new(0, 0.25, 0.9), STONE, M.Limestone)
	return leaf
end

-- Axis-aligned bounding box of `pieces` inside `frame`: minimum and maximum corners.
local function boundsIn(frame: CFrame, pieces: { BasePart }): (Vector3, Vector3)
	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = -minimum
	for _, piece in pieces do
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					local corner = frame:PointToObjectSpace(
						piece.CFrame:PointToWorldSpace(
							Vector3.new(piece.Size.X * x, piece.Size.Y * y, piece.Size.Z * z) / 2
						)
					)
					minimum = minimum:Min(corner)
					maximum = maximum:Max(corner)
				end
			end
		end
	end
	return minimum, maximum
end

-- Keep a balcony's slab and ironwork as decoration behind one bounding hitbox:
-- a single solid body instead of a dozen thin colliders.
local function collapseBalcony(parent: Instance, pieces: { BasePart }, frame: CFrame)
	local minimum, maximum = boundsIn(frame, pieces)
	local hitbox = part(parent, maximum - minimum, frame * CFrame.new((minimum + maximum) / 2), IRON, M.Slate)
	hitbox.Name = "BalconyHitbox"
	hitbox.Transparency = 1
	hitbox.CastShadow = false
	hitbox.CanCollide = true
	hitbox.CanQuery = true
	for _, piece in pieces do
		piece.CanCollide, piece.CanTouch, piece.CanQuery = false, false, false
	end
end

-- Balcony whose floor is level with `face`, with a wrought-iron railing.
local function balcony(m: Model, face: CFrame, width: number, depth: number, slab: Color3)
	local pieces = {}
	local function detail(size: Vector3, at: CFrame, color: Color3, material: Enum.Material)
		table.insert(pieces, part(m, size, at, color, material))
	end
	detail(Vector3.new(width, 0.5, depth), face * CFrame.new(0, -0.25, depth / 2), slab, M.Plaster)
	local posts = math.max(3, math.floor(width / 1.1))
	for i = 0, posts do
		local x = -width / 2 + 0.2 + (width - 0.4) * i / posts
		detail(Vector3.new(0.14, 2.6, 0.14), face * CFrame.new(x, 1.3, depth - 0.2), IRON, M.Metal)
	end
	detail(Vector3.new(width - 0.2, 0.2, 0.22), face * CFrame.new(0, 2.6, depth - 0.2), IRON, M.Metal)
	for side = -1, 1, 2 do
		detail(
			Vector3.new(0.2, 0.2, depth - 0.2),
			face * CFrame.new(side * (width / 2 - 0.2), 2.6, depth / 2),
			IRON,
			M.Metal
		)
	end
	collapseBalcony(m, pieces, face)
end

local function flowerBox(m: Model, face: CFrame, width: number, rng: Random)
	part(m, Vector3.new(width, 0.8, 0.9), face * CFrame.new(0, 0, 0.6), TERRACOTTA, M.Sandstone)
	for k = 1, 3 do
		local color = if rng:NextNumber() < 0.6 then pick(rng, BLOOMS) else LEAF
		blob(
			m,
			(face * CFrame.new((k - 2) * width / 3.2, 0.6, 0.6)).Position,
			Vector3.new(1.1, 0.9, 0.9),
			rng,
			color,
			M.LeafyGrass
		)
	end
end

-- Windows across every wall of a w x d block. The front ground floor leaves a gap for the door.
local function fenestrate(m: Model, base: CFrame, w: number, d: number, rng: Random, look: Look, facade: Facade)
	local lit = false
	for side = 0, 3 do
		if side == facade.skipSide then
			continue
		end
		local _, width = wallFace(base, w, d, side, 0)
		local n = math.max(1, math.floor(width / look.spacing))
		for s = 1, facade.stories do
			local y = facade.floor + (s - 1) * facade.storyH + facade.storyH * 0.55
			local face = wallFace(base, w, d, side, y)
			for i = 1, n do
				local x = (i - (n + 1) / 2) * width / n
				local gap = facade.doorGap or (look.winW / 2 + 3)
				local skip = if side == 0
					then s == 1 and facade.doorX ~= nil and math.abs(x - facade.doorX) < gap
					else rng:NextNumber() < 0.3
				if not skip then
					local glow = rng:NextNumber() < 0.3
					local at = face * CFrame.new(x, 0, 0)
					local glass = window(m, at, look.winW, look.winH, look.frame, look.shutter, look.arched, glow)
					if glow and not lit then
						light(glass, LAMP, 18, 0.7)
						lit = true
					end
					if facade.extras then
						facade.extras(side, s, at)
					end
				end
			end
		end
	end
end

-- Block with a flat roof: a slab lipped over the walls and a low parapet round the terrace.
local function flatBlock(m: Model, base: CFrame, w: number, d: number, floor: number, h: number, color: Color3)
	part(m, Vector3.new(w, h, d), base * CFrame.new(0, floor + h / 2, 0), color, M.Plaster)
	part(m, Vector3.new(w + 0.6, 0.4, d + 0.6), base * CFrame.new(0, floor + h + 0.2, 0), color, M.Plaster)
	for side = 0, 3 do
		local face, width = wallFace(base, w, d, side, floor + h + 0.9)
		local length = if side % 2 == 0 then width else width - 1.2
		part(m, Vector3.new(length, 1, 0.6), face * CFrame.new(0, 0, -0.3), color, M.Plaster)
	end
end

-- Shallow clay-tile roof with its ridge along local X. Returns how far the ridge rises above `top`.
local function gableRoof(
	m: Model,
	base: CFrame,
	w: number,
	d: number,
	top: number,
	pitch: number,
	roof: Color3,
	gable: Color3
): number
	local rise = d / 2 * math.tan(pitch)
	local slant = (d / 2 + 1.4) / math.cos(pitch)
	for side = -1, 1, 2 do
		part(
			m,
			Vector3.new(w + 2, 0.7, slant),
			base * CFrame.new(0, top + rise / 2, side * d / 4) * CFrame.Angles(side * pitch, 0, 0),
			roof,
			M.ClayRoofTiles
		)
		local x = side * w / 2
		LowPoly.triangle(
			base:PointToWorldSpace(Vector3.new(x, top, -d / 2)),
			base:PointToWorldSpace(Vector3.new(x, top, d / 2)),
			base:PointToWorldSpace(Vector3.new(x, top + rise, 0)),
			base:PointToWorldSpace(Vector3.new(0, top, 0)),
			gable,
			m,
			M.Plaster
		)
	end
	part(
		m,
		Vector3.new(w + 2.2, 0.8, 1),
		base * CFrame.new(0, top + rise + 0.15, 0),
		roof:Lerp(Color3.new(0, 0, 0), 0.2),
		M.ClayRoofTiles
	)
	return rise
end

-- Squat whitewashed chimney with a little capped vent, Cycladic style.
local function chimney(m: Model, at: CFrame)
	part(m, Vector3.new(1.8, 3, 1.8), at * CFrame.new(0, 1.5, 0), WHITEWASH, M.Plaster)
	part(m, Vector3.new(2.4, 0.4, 2.4), at * CFrame.new(0, 3.6, 0), WHITEWASH, M.Plaster)
	for side = -1, 1, 2 do
		part(m, Vector3.new(0.4, 0.8, 2), at * CFrame.new(side * 0.8, 3.1, 0), WHITEWASH, M.Plaster)
	end
end

-- Facade pieces shared with the piazza's bespoke houses.
Med.window, Med.door, Med.balcony, Med.flowerBox, Med.gableRoof = window, door, balcony, flowerBox, gableRoof

-- Little blue dome on a drum, topped with a cross.
local function dome(m: Model, at: Vector3, diameter: number, drum: number)
	cylinder(m, at + Vector3.new(0, drum / 2, 0), drum, diameter, WHITEWASH, M.Plaster)
	ball(m, at + Vector3.new(0, drum, 0), diameter, AEGEAN, M.SmoothPlastic)
	local tip = at + Vector3.new(0, drum + diameter / 2, 0)
	part(m, Vector3.new(0.3, 2.4, 0.3), CFrame.new(tip + Vector3.new(0, 1, 0)), IRON, M.Metal)
	part(m, Vector3.new(1.2, 0.3, 0.3), CFrame.new(tip + Vector3.new(0, 1.5, 0)), IRON, M.Metal)
end

-- Bougainvillea climbing a wall from a root on `face` to a spill of blossom `height` up.
function Med.bougainvillea(parent: Instance, face: CFrame, rng: Random, height: number): Model
	local m = newModel("Bougainvillea", parent)
	beam(
		m,
		(face * CFrame.new(0, 0, 0.4)).Position,
		(face * CFrame.new(-0.4, height, 0.5)).Position,
		0.35,
		TRUNK,
		nil,
		M.Wood
	)
	for _ = 1, rng:NextInteger(6, 9) do
		local p = face * CFrame.new(rng:NextNumber(-3.4, 1), height + rng:NextNumber(-2.4, 1), rng:NextNumber(0.5, 1.1))
		local s = rng:NextNumber(1.4, 2.4)
		local color = if rng:NextNumber() < 0.75 then shade(pick(rng, BLOOMS), rng, 0.08) else LEAF
		blob(m, p.Position, Vector3.new(s, s * 0.8, s * 0.6), rng, color, M.LeafyGrass).CanCollide = false
	end
	return m
end

-- Outdoor masonry stair running up a side wall from the front to the roof.
local function sideStair(m: Model, base: CFrame, w: number, d: number, floor: number, roofY: number, side: number)
	local steps = math.ceil((roofY - floor) / 0.9)
	local run = (d - 1.5) / steps
	local x = side * (w / 2 + 1.4)
	for i = 1, steps do
		local top = floor + (roofY - floor) * i / steps
		local z = d / 2 - 0.5 - (i - 0.5) * run
		part(m, Vector3.new(2.8, top, run), base * CFrame.new(x, top / 2, z), WHITEWASH, M.Plaster)
	end
	local low = base:PointToWorldSpace(Vector3.new(side * (w / 2 + 2.6), floor + 1.4, d / 2 - 0.5))
	local high = base:PointToWorldSpace(Vector3.new(side * (w / 2 + 2.6), roofY + 1.4, -d / 2 + 1))
	beam(m, low, high, 0.6, WHITEWASH, 1.2, M.Plaster)
end

----------------------------------------------------------------------------------------------------
-- Pots and plants

-- Terracotta pot holding flowers, a shrub or a little lemon tree.
function Med.pot(parent: Instance, ground: Vector3, rng: Random, plant: string?): Model
	local m = newModel("Pot", parent)
	local kind = plant or pick(rng, { "flowers", "shrub", "lemon" })
	local s = if kind == "lemon" then 2.6 else rng:NextNumber(1.6, 2.2)
	cylinder(m, ground + Vector3.new(0, s * 0.45, 0), s * 0.9, s, TERRACOTTA, M.Sandstone)
	cylinder(
		m,
		ground + Vector3.new(0, s * 0.92, 0),
		s * 0.15,
		s * 1.15,
		TERRACOTTA:Lerp(Color3.new(0, 0, 0), 0.15),
		M.Sandstone
	)
	local soil = ground + Vector3.new(0, s, 0)
	if kind == "lemon" then
		beam(m, soil - Vector3.new(0, 0.5, 0), soil + Vector3.new(0, 3, 0), 0.4, TRUNK, nil, M.Wood)
		local crown = soil + Vector3.new(0, 4.2, 0)
		blob(m, crown, Vector3.new(3.4, 3, 3.4), rng, rgb(60, 110, 50), M.LeafyGrass)
		for _ = 1, 6 do
			local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.6, 0.8), rng:NextNumber(-1, 1)).Unit
			ball(m, crown + dir * 1.9, 0.55, rgb(244, 214, 60), M.SmoothPlastic)
		end
	elseif kind == "shrub" then
		blob(
			m,
			soil + Vector3.new(0, 0.6, 0),
			Vector3.new(s * 1.2, s, s * 1.2),
			rng,
			shade(LEAF, rng, 0.1),
			M.LeafyGrass
		)
	else
		for _ = 1, 3 do
			local at = soil + Vector3.new(rng:NextNumber(-0.4, 0.4), 0.5, rng:NextNumber(-0.4, 0.4))
			blob(m, at, Vector3.new(1, 0.8, 1), rng, pick(rng, BLOOMS), M.LeafyGrass)
		end
	end
	return m
end

function Med.lavender(parent: Instance, ground: Vector3, rng: Random): Model
	local m = newModel("Lavender", parent)
	for _ = 1, rng:NextInteger(3, 5) do
		local at = ground + Vector3.new(rng:NextNumber(-2.2, 2.2), 0.5, rng:NextNumber(-2.2, 2.2))
		blob(m, at, Vector3.new(1.8, 1.1, 1.8), rng, rgb(104, 120, 84), M.LeafyGrass)
		part(
			m,
			Vector3.new(1.4, 0.8, 1.4),
			CFrame.new(at + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
			shade(LAVENDER, rng, 0.08),
			M.LeafyGrass
		)
	end
	return m
end

----------------------------------------------------------------------------------------------------
-- Trees

-- Gnarled olive: a twisting trunk under flat silvery-green clumps.
function Med.olive(parent: Instance, ground: Vector3, rng: Random, scale: number?): Model
	local k = scale or 1
	local m = newModel("Olive", parent)
	local lean = rng:NextNumber(0, TAU)
	local dir = Vector3.new(math.cos(lean), 0, math.sin(lean))
	local h = rng:NextNumber(8, 12) * k
	local knee = ground + Vector3.new(0, h * 0.35, 0) + dir * rng:NextNumber(0.8, 1.8) * k
	local top = ground + Vector3.new(0, h * 0.62, 0) - dir * rng:NextNumber(0, 1) * k
	beam(m, ground - Vector3.new(0, 1, 0), knee, 1.9 * k, OLIVE_BARK, nil, M.Wood)
	beam(m, knee, top, 1.4 * k, OLIVE_BARK, nil, M.Wood)
	local crowns = { top + Vector3.new(0, 1.5 * k, 0) }
	for _ = 1, rng:NextInteger(2, 3) do
		local a = rng:NextNumber(0, TAU)
		local tip = top + Vector3.new(math.cos(a) * 3.5 * k, rng:NextNumber(1, 2.5) * k, math.sin(a) * 3.5 * k)
		beam(m, knee:Lerp(top, 0.6), tip, 0.7 * k, OLIVE_BARK, nil, M.Wood)
		table.insert(crowns, tip)
	end
	for _, c in crowns do
		local s = rng:NextNumber(5, 7.5) * k
		part(
			m,
			Vector3.new(s, s * 0.5, s * rng:NextNumber(0.8, 1.1)),
			CFrame.new(c + Vector3.new(0, s * 0.15, 0))
				* CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, TAU), rng:NextNumber(-0.25, 0.25)),
			shade(pick(rng, OLIVE_LEAF), rng, 0.05),
			M.LeafyGrass
		)
	end
	return m
end

-- Tall dark spindle of a cypress.
function Med.cypress(parent: Instance, ground: Vector3, rng: Random, height: number?): Model
	local m = newModel("Cypress", parent)
	local h = height or rng:NextNumber(16, 26)
	local r = h * rng:NextNumber(0.09, 0.11)
	part(m, Vector3.new(1, 3, 1), CFrame.new(ground + Vector3.new(0, 0.5, 0)), TRUNK, M.Wood)
	local ringY = h * 0.3
	local spin = rng:NextNumber(0, TAU)
	local ring = {}
	for i = 1, 5 do
		local a = spin + i / 5 * TAU
		ring[i] = ground + Vector3.new(math.cos(a) * r, ringY + rng:NextNumber(-0.4, 0.4), math.sin(a) * r)
	end
	local color = shade(CYPRESS, rng, 0.08)
	local core = ground + Vector3.new(0, ringY, 0)
	local apex = ground + Vector3.new(rng:NextNumber(-0.3, 0.3), h, rng:NextNumber(-0.3, 0.3))
	LowPoly.pyramid(ring, apex, color, m, M.LeafyGrass, core)
	LowPoly.pyramid(ring, ground + Vector3.new(0, 1.5, 0), color:Lerp(Color3.new(0, 0, 0), 0.12), m, M.LeafyGrass, core)
	return m
end

-- Umbrella pine: a tall leaning trunk under a flat, spreading crown.
function Med.stonePine(parent: Instance, ground: Vector3, rng: Random): Model
	local m = newModel("StonePine", parent)
	local h = rng:NextNumber(17, 25)
	local lean = rng:NextNumber(0, TAU)
	local dir = Vector3.new(math.cos(lean), 0, math.sin(lean))
	local top = ground + Vector3.new(0, h, 0) + dir * rng:NextNumber(1.5, 4)
	local mid = ground:Lerp(top, 0.55) + dir * 0.6
	beam(m, ground - Vector3.new(0, 1, 0), mid, 1.5, rgb(110, 78, 58), nil, M.Wood)
	beam(m, mid, top, 1.2, rgb(110, 78, 58), nil, M.Wood)
	local crowns = { top + Vector3.new(0, 1, 0) }
	for _ = 1, rng:NextInteger(2, 3) do
		local a = rng:NextNumber(0, TAU)
		local tip = top
			+ Vector3.new(
				math.cos(a) * rng:NextNumber(4, 6),
				rng:NextNumber(-1.5, 0.5),
				math.sin(a) * rng:NextNumber(4, 6)
			)
		beam(m, mid:Lerp(top, 0.7), tip, 0.6, rgb(110, 78, 58), nil, M.Wood)
		table.insert(crowns, tip)
	end
	for i, c in crowns do
		local s = if i == 1 then rng:NextNumber(12, 15) else rng:NextNumber(7, 10)
		part(
			m,
			Vector3.new(s, 2.6, s * rng:NextNumber(0.75, 1)),
			CFrame.new(c + Vector3.new(0, 1, 0)) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), rng:NextNumber(0, TAU), 0),
			shade(STONE_PINE, rng, 0.07),
			M.LeafyGrass
		)
	end
	return m
end

----------------------------------------------------------------------------------------------------
-- Houses

-- Cycladic cube house: whitewashed walls, blue door and shutters, a flat roof terrace, and often
-- a second block stacked on top, an outside stair, a pergola or a little dome.
function Med.cubeHouse(parent: Instance, ground: Vector3, facing: number, rng: Random): Model
	local m = newModel("CubeHouse", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	local w, d, h = rng:NextNumber(17, 22), rng:NextNumber(15, 18), rng:NextNumber(10.5, 12)
	local accent = pick(rng, SHUTTERS)
	local shuttered = rng:NextNumber() < 0.65
	local look: Look = {
		frame = if shuttered then OFFWHITE else accent,
		shutter = if shuttered then accent else nil,
		arched = rng:NextNumber() < 0.4,
		winW = 2.6,
		winH = 3.2,
		spacing = 7.5,
	}
	local floor = 0.6
	local stairSide = if rng:NextNumber() < 0.5 then -1 else 1
	local hasStair = rng:NextNumber() < 0.55

	part(m, Vector3.new(w + 1, 2, d + 1), base * CFrame.new(0, -0.4, 0), STONE, M.Limestone)
	flatBlock(m, base, w, d, floor, h, WHITEWASH)
	local doorX = rng:NextNumber(-w * 0.22, w * 0.22)
	local front = wallFace(base, w, d, 0, floor)
	door(m, front * CFrame.new(doorX, 0, 0), 3.6, 7.2, accent, look.frame, rng:NextNumber() < 0.6)
	fenestrate(m, base, w, d, rng, look, {
		floor = floor,
		storyH = h,
		stories = 1,
		doorX = doorX,
		skipSide = if hasStair then (if stairSide == 1 then 1 else 3) else nil,
	})
	if rng:NextNumber() < 0.55 then
		Med.bougainvillea(m, front * CFrame.new(doorX + 3.4, 0, 0), rng, 8.6)
	end

	local roofY = floor + h + 0.4
	local hasUpper = rng:NextNumber() < 0.65
	if hasUpper then
		local w2, d2, h2 = w * rng:NextNumber(0.42, 0.58), d * rng:NextNumber(0.5, 0.65), rng:NextNumber(8.5, 9.5)
		local upper = base * CFrame.new(-stairSide * ((w - w2) / 2 - 0.6), roofY, -((d - d2) / 2 - 0.6))
		flatBlock(m, upper, w2, d2, 0, h2, WHITEWASH)
		door(m, wallFace(upper, w2, d2, 0, 0), 3, 6.6, accent, look.frame, true)
		fenestrate(m, upper, w2, d2, rng, look, { floor = 0, storyH = h2, stories = 1, doorX = 0 })
		local upperRoof = upper * CFrame.new(0, h2 + 0.4, 0)
		if rng:NextNumber() < 0.25 then
			dome(m, upperRoof.Position, math.min(w2, d2) * 0.55, 1.2)
		else
			chimney(m, upperRoof * CFrame.new(w2 / 4, 0, -d2 / 4))
		end
	else
		chimney(m, base * CFrame.new(-w / 4, roofY, -d / 4))
	end

	-- Life on the roof terrace in front of the upper block
	local terrace = base * CFrame.new(stairSide * w / 4, roofY, d / 4)
	local shaded = rng:NextNumber() < 0.45
	if shaded then
		Med.pergola(m, terrace.Position, facing, rng, w * 0.4, d * 0.35, 7)
	end
	for _, corner in { -stairSide, stairSide } do
		if rng:NextNumber() < 0.6 and not (shaded and corner == stairSide) then
			Med.pot(m, base:PointToWorldSpace(Vector3.new(corner * (w / 2 - 1.6), roofY, d / 2 - 1.6)), rng)
		end
	end
	if hasStair then
		sideStair(m, base, w, d, floor, roofY, stairSide)
	end
	Props.simplifyHouseCollision(m)
	return m
end

-- Pastel townhouse of two or three floors under a clay-tile roof: shutters, balconies,
-- flower boxes and sometimes a shopfront with a striped awning.
function Med.townhouse(parent: Instance, ground: Vector3, facing: number, rng: Random, shopfront: boolean?): Model
	local m = newModel("Townhouse", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	local w, d = rng:NextNumber(15, 19), rng:NextNumber(13, 16)
	local stories = if rng:NextNumber() < 0.6 then 2 else 3
	local storyH = rng:NextNumber(8.5, 9.5)
	local h = stories * storyH
	local wall = pick(rng, PASTELS)
	local trim = WHITEWASH:Lerp(wall, 0.2)
	local look: Look = {
		frame = trim,
		shutter = pick(rng, TOWN_SHUTTERS),
		arched = rng:NextNumber() < 0.3,
		winW = 2.4,
		winH = 3.6,
		spacing = 7,
	}
	local floor = 0.6
	local shop = if shopfront ~= nil then shopfront else rng:NextNumber() < 0.3

	part(m, Vector3.new(w + 1, 2, d + 1), base * CFrame.new(0, -0.4, 0), STONE, M.Limestone)
	part(m, Vector3.new(w, h, d), base * CFrame.new(0, floor + h / 2, 0), wall, M.Plaster)
	if rng:NextNumber() < 0.5 then
		for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
			part(m, Vector3.new(1, h, 1), base * CFrame.new(c[1] * w / 2, floor + h / 2, c[2] * d / 2), trim, M.Plaster)
		end
	end
	for s = 1, stories - 1 do
		part(m, Vector3.new(w + 0.5, 0.5, d + 0.5), base * CFrame.new(0, floor + s * storyH, 0), trim, M.Plaster)
	end
	part(m, Vector3.new(w + 1, 0.9, d + 1), base * CFrame.new(0, floor + h + 0.45, 0), trim, M.Plaster)
	gableRoof(m, base, w, d, floor + h + 0.9, math.rad(rng:NextNumber(18, 24)), pick(rng, ROOF_TILES), wall)

	local front = wallFace(base, w, d, 0, floor)
	if shop then
		-- Shop window under a striped awning, a sign board above it, the door to one side
		local sw, sx = w * 0.55, -w * 0.12
		local awning = pick(rng, AWNINGS)
		part(m, Vector3.new(sw + 1, 5.6, 0.14), front * CFrame.new(sx, 3.2, 0.07), WOOD_DARK, M.Wood)
		local glass = part(m, Vector3.new(sw, 4.6, 0.2), front * CFrame.new(sx, 3.3, 0.12), LAMP, M.Neon)
		light(glass, LAMP, 20, 0.8)
		part(m, Vector3.new(sw + 1.2, 0.6, 1.2), front * CFrame.new(sx, 0.8, 0.5), WOOD, M.WoodPlanks)
		for i = 0, 5 do
			part(
				m,
				Vector3.new(sw / 6, 0.25, 3.8),
				front * CFrame.new(sx - sw / 2 + (i + 0.5) * sw / 6, 6.6, 1.7) * CFrame.Angles(0.35, 0, 0),
				if i % 2 == 0 then awning else CANVAS,
				M.Fabric
			)
		end
		local board =
			part(m, Vector3.new(sw * 0.8, 1.4, 0.3), front * CFrame.new(sx, 7.9, 0.2), WOOD_DARK, M.WoodPlanks)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Garamond
		label.TextScaled = true
		label.TextColor3 = rgb(245, 230, 190)
		label.Text = pick(rng, SHOPS)
		label.Parent = gui
		gui.Parent = board
		door(m, front * CFrame.new(sx + sw / 2 + 2.4, 0, 0), 3, 6.4, WOOD_DARK, trim, false)
		Med.pot(m, front:PointToWorldSpace(Vector3.new(sx - sw / 2 - 1.2, 0, 1.4)), rng)
	else
		door(m, front, 3.4, 6.4, pick(rng, TOWN_SHUTTERS), trim, true)
		for side = -1, 1, 2 do
			if rng:NextNumber() < 0.5 then
				Med.pot(m, front:PointToWorldSpace(Vector3.new(side * 3.2, 0, 1.2)), rng)
			end
		end
	end

	fenestrate(m, base, w, d, rng, look, {
		floor = floor,
		storyH = storyH,
		stories = stories,
		doorX = 0,
		doorGap = if shop then w else nil,
		extras = function(side, story, face)
			if side ~= 0 or story == 1 then
				return
			end
			if rng:NextNumber() < 0.45 then
				balcony(m, face * CFrame.new(0, 0.5 - storyH * 0.55, 0), look.winW * 2 + 2, 2.2, trim)
				if rng:NextNumber() < 0.5 then
					Med.pot(m, face:PointToWorldSpace(Vector3.new(look.winW, 0.5 - storyH * 0.55, 1.2)), rng, "flowers")
				end
			elseif rng:NextNumber() < 0.6 then
				flowerBox(m, face * CFrame.new(0, -look.winH / 2 - 0.9, 0), look.winW + 0.6, rng)
			end
		end,
	})
	if not shop and rng:NextNumber() < 0.35 then
		Med.bougainvillea(m, front * CFrame.new(-2.6, 0, 0), rng, 7.4)
	end
	Props.simplifyHouseCollision(m)
	return m
end

-- Two-storey villa with a columned loggia carrying a balustraded terrace, flanked by cypresses.
function Med.villa(parent: Instance, ground: Vector3, facing: number, rng: Random): Model
	local m = newModel("Villa", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	local w, d = rng:NextNumber(22, 25), rng:NextNumber(15, 17)
	local storyH, stories = 9, 2
	local h = storyH * stories
	local wall = if rng:NextNumber() < 0.4 then WHITEWASH else pick(rng, PASTELS)
	local trim = WHITEWASH:Lerp(wall, 0.15)
	local look: Look = {
		frame = trim,
		shutter = pick(rng, TOWN_SHUTTERS),
		arched = true,
		winW = 2.4,
		winH = 3.8,
		spacing = 7,
	}
	local floor = 0.6
	local depth = 6

	part(m, Vector3.new(w + 1, 2, d + 1), base * CFrame.new(0, -0.4, 0), STONE, M.Limestone)
	part(m, Vector3.new(w + 1, 2, depth), base * CFrame.new(0, -0.4, d / 2 + 0.5 + depth / 2), STONE, M.Limestone)
	part(m, Vector3.new(w, h, d), base * CFrame.new(0, floor + h / 2, 0), wall, M.Plaster)
	part(m, Vector3.new(w + 0.5, 0.5, d + 0.5), base * CFrame.new(0, floor + storyH, 0), trim, M.Plaster)
	part(m, Vector3.new(w + 1, 0.9, d + 1), base * CFrame.new(0, floor + h + 0.45, 0), trim, M.Plaster)
	gableRoof(m, base, w, d, floor + h + 0.9, math.rad(20), pick(rng, ROOF_TILES), wall)
	chimney(m, base * CFrame.new(w / 3, floor + h + 0.9, -d / 4) * CFrame.new(0, d / 4 * math.tan(math.rad(20)), 0))

	-- Loggia: columns along the front carrying a terrace slab
	local columnZ = d / 2 + depth - 0.9
	local columns = 5
	for i = 0, columns - 1 do
		local x = -w / 2 + 1 + (w - 2) * i / (columns - 1)
		local colH = storyH - 0.6
		cylinder(m, base:PointToWorldSpace(Vector3.new(x, floor + colH / 2, columnZ)), colH, 1.5, trim, M.Plaster)
		part(m, Vector3.new(2, 0.6, 2), base * CFrame.new(x, floor + 0.3, columnZ), STONE, M.Limestone)
		part(m, Vector3.new(2, 0.6, 2), base * CFrame.new(x, floor + colH - 0.3, columnZ), trim, M.Plaster)
	end
	local terraceY = floor + storyH + 0.2
	part(
		m,
		Vector3.new(w + 0.6, 0.8, depth + 0.2),
		base * CFrame.new(0, terraceY - 0.4, d / 2 + depth / 2),
		trim,
		M.Plaster
	)
	for x = -w / 2 + 0.6, w / 2 - 0.5, 1.2 do
		cylinder(m, base:PointToWorldSpace(Vector3.new(x, terraceY + 1, d / 2 + depth - 0.4)), 2, 0.6, trim, M.Plaster)
	end
	part(m, Vector3.new(w + 0.6, 0.5, 0.9), base * CFrame.new(0, terraceY + 2.2, d / 2 + depth - 0.4), trim, M.Plaster)
	for side = -1, 1, 2 do
		part(
			m,
			Vector3.new(0.9, 2.4, depth),
			base * CFrame.new(side * (w / 2 - 0.15), terraceY + 1.2, d / 2 + depth / 2),
			trim,
			M.Plaster
		)
	end

	local front = wallFace(base, w, d, 0, floor)
	door(m, front, 4, 7, pick(rng, TOWN_SHUTTERS), trim, true)
	fenestrate(m, base, w, d, rng, look, { floor = floor, storyH = storyH, stories = stories, doorX = 0 })
	for _, x in { -w / 4, w / 4 } do
		Med.pot(m, base:PointToWorldSpace(Vector3.new(x, floor, d / 2 + depth / 2)), rng, "lemon")
		Med.pot(m, base:PointToWorldSpace(Vector3.new(x, terraceY, d / 2 + depth / 2)), rng, "flowers")
	end
	Med.bougainvillea(m, base * CFrame.new(-w / 2 + 1, floor, columnZ + 0.8), rng, storyH)
	for side = -1, 1, 2 do
		Med.cypress(m, base:PointToWorldSpace(Vector3.new(side * (w / 2 + 2), 0, columnZ)), rng, rng:NextNumber(18, 22))
	end
	Props.simplifyHouseCollision(m)
	return m
end

-- Whitewashed chapel with a blue dome, a bell gable over the door and a round window. `size` scales it.
function Med.chapel(parent: Instance, ground: Vector3, facing: number, rng: Random, size: number?): Model
	local k = size or 1
	local m = newModel("Chapel", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	local w, d, h = 13 * k, 16 * k, 10 * k
	local floor = 0.6

	part(m, Vector3.new(w + 3, 2.4, d + 3), base * CFrame.new(0, -0.6, 0), STONE, M.Limestone)
	part(m, Vector3.new(w * 0.5, 0.3, 1.6), base * CFrame.new(0, 0.15, d / 2 + 2.3), STONE, M.Limestone)
	flatBlock(m, base, w, d, floor, h, WHITEWASH)

	local front = wallFace(base, w, d, 0, floor)
	door(m, front, 3.4 * k, 6 * k, AEGEAN, OFFWHITE, true)
	local rose = front * CFrame.new(0, 8.6 * k, 0)
	disc(m, rose * CFrame.new(0, 0, 0.06), 2.4 * k, 0.12, OFFWHITE, M.Plaster)
	disc(m, rose * CFrame.new(0, 0, 0.1), 1.6 * k, 0.2, AEGEAN, M.Glass)
	for _, side in { 1, 3 } do
		for _, z in { -d / 4, d / 4 } do
			local face = wallFace(base, w, d, side, floor + h * 0.5)
			window(m, face * CFrame.new(z, 0, 0), 1.4 * k, 3.4 * k, OFFWHITE, nil, true, rng:NextNumber() < 0.5)
		end
	end

	local roofY = floor + h + 0.4
	dome(m, base:PointToWorldSpace(Vector3.new(0, roofY, -d * 0.1)), 9 * k, 3 * k)

	-- Bell gable standing on the front parapet
	local gable = base * CFrame.new(0, roofY + 1, d / 2 - 0.5)
	for side = -1, 1, 2 do
		part(m, Vector3.new(1.2 * k, 5 * k, 1), gable * CFrame.new(side * 1.9 * k, 2.5 * k, 0), WHITEWASH, M.Plaster)
	end
	part(m, Vector3.new(5 * k, 1.2 * k, 1), gable * CFrame.new(0, 5.6 * k, 0), WHITEWASH, M.Plaster)
	disc(m, gable * CFrame.new(0, 6.2 * k, 0.08), 2.6 * k, 1, WHITEWASH, M.Plaster)
	part(m, Vector3.new(0.3, 1.8 * k, 0.3), gable * CFrame.new(0, 8.2 * k, 0), IRON, M.Metal)
	part(m, Vector3.new(1 * k, 0.3, 0.3), gable * CFrame.new(0, 8.5 * k, 0), IRON, M.Metal)
	part(m, Vector3.new(2.6 * k, 0.3, 0.3), gable * CFrame.new(0, 4.9 * k, 0), IRON, M.Metal)
	ball(m, (gable * CFrame.new(0, 3.9 * k, 0)).Position, 1.8 * k, BRASS, M.Metal)

	for side = -1, 1, 2 do
		Med.pot(m, front:PointToWorldSpace(Vector3.new(side * 3.6 * k, 0, 1.2)), rng, "flowers")
	end
	return m
end

-- Square campanile with a clock face, an open belfry and a small dome.
function Med.bellTower(parent: Instance, ground: Vector3, facing: number, rng: Random): Model
	local m = newModel("BellTower", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	local s, h = 7, 22
	local floor = 0.6
	part(m, Vector3.new(s + 1.2, 2, s + 1.2), base * CFrame.new(0, -0.4, 0), STONE, M.Limestone)
	part(m, Vector3.new(s, h, s), base * CFrame.new(0, floor + h / 2, 0), WHITEWASH, M.Plaster)
	door(m, wallFace(base, s, s, 0, floor), 2.6, 5.4, WOOD_DARK, OFFWHITE, true)
	for side = 0, 3 do
		local face = wallFace(base, s, s, side, floor + h - 4)
		disc(m, face * CFrame.new(0, 0, 0.06), 5, 0.12, OFFWHITE, M.Plaster)
		disc(m, face * CFrame.new(0, 0, 0.12), 4.2, 0.2, rgb(250, 240, 214), M.SmoothPlastic)
		part(m, Vector3.new(0.3, 1.7, 0.2), face * CFrame.new(0, 0.7, 0.3), IRON, M.Metal)
		part(m, Vector3.new(1.3, 0.3, 0.2), face * CFrame.new(0.55, 0, 0.3), IRON, M.Metal)
		if side ~= 0 then
			window(m, wallFace(base, s, s, side, floor + h * 0.45), 1.2, 3, OFFWHITE, nil, true, false)
		end
	end

	local y = floor + h
	part(m, Vector3.new(s + 0.8, 0.6, s + 0.8), base * CFrame.new(0, y + 0.3, 0), OFFWHITE, M.Plaster)
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		part(
			m,
			Vector3.new(1.4, 6, 1.4),
			base * CFrame.new(c[1] * (s / 2 - 0.7), y + 3.6, c[2] * (s / 2 - 0.7)),
			WHITEWASH,
			M.Plaster
		)
	end
	part(m, Vector3.new(s - 1, 0.3, 0.3), base * CFrame.new(0, y + 5.8, 0), WOOD_DARK, M.Wood)
	ball(m, base:PointToWorldSpace(Vector3.new(0, y + 4.4, 0)), 2.8, BRASS, M.Metal)
	part(m, Vector3.new(s + 0.8, 0.6, s + 0.8), base * CFrame.new(0, y + 6.9, 0), OFFWHITE, M.Plaster)
	if rng:NextNumber() < 0.5 then
		dome(m, base:PointToWorldSpace(Vector3.new(0, y + 7.2, 0)), 5, 1)
	else
		local corners = {}
		for i, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
			corners[i] = base:PointToWorldSpace(Vector3.new(c[1] * (s / 2 + 0.4), y + 7.2, c[2] * (s / 2 + 0.4)))
		end
		LowPoly.pyramid(corners, base:PointToWorldSpace(Vector3.new(0, y + 12, 0)), TERRACOTTA, m, M.ClayRoofTiles)
	end
	return m
end

-- Greek windmill: a round white tower under a conical thatch cap, with eight triangular canvas sails.
function Med.windmill(parent: Instance, ground: Vector3, facing: number, rng: Random): Model
	local m = newModel("Windmill", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	local r, h = 6.5, 18
	cylinder(m, ground + Vector3.new(0, -1.5, 0), 5, r * 2 + 3, STONE, M.Limestone)
	cylinder(m, ground + Vector3.new(0, 1 + h / 2, 0), h, r * 2, WHITEWASH, M.Plaster)
	local ring = {}
	for i = 1, 10 do
		local a = i / 10 * TAU
		ring[i] = ground + Vector3.new(math.cos(a) * (r + 0.8), 1 + h, math.sin(a) * (r + 0.8))
	end
	LowPoly.pyramid(ring, ground + Vector3.new(0, 1 + h + 6.5, 0), rgb(150, 120, 82), m, M.Wood)

	part(m, Vector3.new(3.8, 7, 0.4), base * CFrame.new(0, 4.5, r - 0.05), OFFWHITE, M.Plaster)
	part(m, Vector3.new(3, 6.4, 0.6), base * CFrame.new(0, 4.2, r), AEGEAN, M.WoodPlanks)
	for _, spot in { { -0.7, 10 }, { 0.8, 14 } } do
		part(
			m,
			Vector3.new(1.4, 2, 0.6),
			base * CFrame.Angles(0, spot[1], 0) * CFrame.new(0, spot[2], r - 0.1),
			AEGEAN,
			M.WoodPlanks
		)
	end

	-- Sails turned to face the sea breeze
	local hub = base * CFrame.new(0, h - 1, r + 2)
	beam(m, base:PointToWorldSpace(Vector3.new(0, h - 1, 0)), hub.Position, 0.9, WOOD_DARK, nil, M.Wood)
	ball(m, hub.Position, 1.8, WOOD_DARK, M.Wood)
	local spin = rng:NextNumber(0, TAU)
	for i = 1, 8 do
		local a = spin + i / 8 * TAU
		local dir = Vector3.new(math.cos(a), math.sin(a), 0)
		local dir2 = Vector3.new(math.cos(a + 0.34), math.sin(a + 0.34), 0)
		beam(m, hub.Position, hub:PointToWorldSpace(dir * 10), 0.35, WOOD, nil, M.Wood)
		LowPoly.triangle(
			hub:PointToWorldSpace(dir * 1.6),
			hub:PointToWorldSpace(dir * 10),
			hub:PointToWorldSpace(dir2 * 8.6),
			hub:PointToWorldSpace(Vector3.new(0, 0, -1)),
			CANVAS,
			m,
			M.Fabric
		)
	end
	return m
end

----------------------------------------------------------------------------------------------------
-- Piazza and garden fittings

-- Keep a pergola's trellis as decoration behind one roof box, and the vines
-- spilling over it with no hitbox at all.
local function simplifyPergola(m: Model)
	if m:GetAttribute("CollisionVersion") == 1 then
		return
	end
	local wood = {}
	for _, piece in m:GetDescendants() do
		if not piece:IsA("BasePart") then
			continue
		end
		if piece.Material == M.Wood then
			table.insert(wood, piece)
		elseif piece.Material == M.LeafyGrass or (piece:IsA("Part") and piece.Shape == Enum.PartType.Ball) then
			piece.CanCollide, piece.CanTouch, piece.CanQuery = false, false, false
		end
	end
	if #wood == 0 then
		return
	end
	local frame = wood[1].CFrame
	local minimum, maximum = boundsIn(frame, wood)
	local hitbox = part(m, maximum - minimum, frame * CFrame.new((minimum + maximum) / 2), WOOD, M.Slate)
	hitbox.Name = "PergolaHitbox"
	hitbox.Transparency = 1
	hitbox.CastShadow = false
	hitbox.CanCollide = true
	hitbox.CanQuery = true
	for _, piece in wood do
		piece.CanCollide, piece.CanTouch, piece.CanQuery = false, false, false
	end
	m:SetAttribute("CollisionVersion", 1)
end

-- Wooden pergola on whitewashed posts, overgrown with vines and the odd bougainvillea.
function Med.pergola(
	parent: Instance,
	ground: Vector3,
	facing: number,
	rng: Random,
	w: number,
	d: number,
	height: number?
): Model
	local m = newModel("Pergola", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	local h = height or 9
	local xs = if w > 12 then { -w / 2, 0, w / 2 } else { -w / 2, w / 2 }
	for _, x in xs do
		for _, z in { -d / 2, d / 2 } do
			part(m, Vector3.new(1.1, h, 1.1), base * CFrame.new(x, h / 2, z), WHITEWASH, M.Plaster)
		end
	end
	for _, z in { -d / 2, d / 2 } do
		part(m, Vector3.new(w + 2, 0.7, 0.7), base * CFrame.new(0, h + 0.35, z), WOOD, M.Wood)
	end
	local rafters = math.max(2, math.floor(w / 2.2))
	for i = 0, rafters do
		part(m, Vector3.new(0.4, 0.4, d + 2), base * CFrame.new(-w / 2 + w * i / rafters, h + 0.9, 0), WOOD, M.Wood)
	end
	for _ = 1, math.max(3, math.floor(w * d / 14)) do
		local p = base
			* CFrame.new(rng:NextNumber(-w / 2, w / 2), h + rng:NextNumber(1, 1.6), rng:NextNumber(-d / 2, d / 2))
		local s = rng:NextNumber(1.8, 3)
		local color = if rng:NextNumber() < 0.25 then pick(rng, BLOOMS) else shade(VINE, rng, 0.1)
		blob(m, p.Position, Vector3.new(s, s * 0.6, s), rng, color, M.LeafyGrass)
		if rng:NextNumber() < 0.15 then
			ball(m, p.Position - Vector3.new(0, 1.1, 0), 0.8, rgb(90, 40, 90), M.SmoothPlastic)
		end
	end
	simplifyPergola(m)
	return m
end

-- Café table with a marble top, chairs and, if given a colour, a striped parasol.
function Med.cafeTable(parent: Instance, ground: Vector3, rng: Random, parasol: Color3?): Model
	local m = newModel("CafeTable", parent)
	cylinder(m, ground + Vector3.new(0, 0.1, 0), 0.2, 1.6, IRON, M.Metal)
	cylinder(m, ground + Vector3.new(0, 1.6, 0), 3, 0.4, IRON, M.Metal)
	cylinder(m, ground + Vector3.new(0, 3.1, 0), 0.2, 3.6, WHITEWASH, M.Marble)
	ball(m, ground + Vector3.new(0.6, 3.5, 0.3), 0.6, rgb(150, 40, 60), M.Glass)
	local chairColor = if rng:NextNumber() < 0.5 then AEGEAN else WOOD
	local spin = rng:NextNumber(0, TAU)
	local chairs = rng:NextInteger(2, 4)
	for i = 1, chairs do
		local a = spin + i / chairs * TAU
		local seatAt = ground + Vector3.new(math.cos(a) * 2.8, 0, math.sin(a) * 2.8)
		local frame = CFrame.lookAt(seatAt, Vector3.new(ground.X, seatAt.Y, ground.Z))
		part(m, Vector3.new(1.6, 0.3, 1.6), frame * CFrame.new(0, 1.9, 0), chairColor, M.Wood)
		part(m, Vector3.new(1.6, 2, 0.25), frame * CFrame.new(0, 3, 0.75), chairColor, M.Wood)
		for side = -1, 1, 2 do
			part(m, Vector3.new(0.2, 1.8, 1.4), frame * CFrame.new(side * 0.65, 0.9, 0), IRON, M.Metal)
		end
	end
	if parasol then
		cylinder(m, ground + Vector3.new(0, 4.6, 0), 9, 0.3, WHITEWASH, M.Metal)
		local apex = ground + Vector3.new(0, 9.3, 0)
		for i = 1, 8 do
			local a0, a1 = i / 8 * TAU, (i + 1) / 8 * TAU
			LowPoly.triangle(
				ground + Vector3.new(math.cos(a0) * 4.6, 7.8, math.sin(a0) * 4.6),
				ground + Vector3.new(math.cos(a1) * 4.6, 7.8, math.sin(a1) * 4.6),
				apex,
				ground + Vector3.new(0, 6, 0),
				if i % 2 == 0 then parasol else CANVAS,
				m,
				M.Fabric
			)
		end
	end
	return m
end

-- Two-tier stone fountain in a round basin, with spray falling from the top bowl.
function Med.fountain(parent: Instance, ground: Vector3): Model
	local m = newModel("Fountain", parent)
	local function at(y: number): Vector3
		return ground + Vector3.new(0, y, 0)
	end
	cylinder(m, at(0.4), 0.8, 26, STONE:Lerp(Color3.new(0, 0, 0), 0.15), M.Limestone)
	cylinder(m, at(1.4), 1.2, 22, STONE, M.Limestone)
	local pool = cylinder(m, at(2.25), 0.4, 21, WATER, M.Glass)
	pool.Transparency = 0.25
	pool.CanCollide = false
	local rim = {}
	for i = 1, 16 do
		local a = i / 16 * TAU
		rim[i] = at(2.7) + Vector3.new(math.cos(a) * 10.6, 0, math.sin(a) * 10.6)
		cylinder(m, rim[i], 1.4, 1.4, STONE, M.Limestone)
	end
	for i = 1, 16 do
		beam(m, rim[i], rim[i % 16 + 1], 1.2, STONE, 1.4, M.Limestone)
	end

	cylinder(m, at(5), 6, 3.2, STONE, M.Limestone)
	cylinder(m, at(8.4), 0.8, 9, STONE, M.Limestone)
	local bowl = cylinder(m, at(8.85), 0.2, 8, WATER, M.Glass)
	bowl.Transparency = 0.25
	cylinder(m, at(10.3), 3, 1.4, STONE, M.Limestone)
	cylinder(m, at(12.1), 0.6, 3.6, STONE, M.Limestone)
	ball(m, at(12.8), 1.2, STONE, M.Limestone)

	local spout = part(m, Vector3.new(1, 1, 1), CFrame.new(at(12.8)), WATER)
	spout.Transparency = 1
	spout.CanCollide = false
	spout.CanQuery = false
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(rgb(210, 240, 250))
	spray.Transparency = NumberSequence.new(0.3, 1)
	spray.Size = NumberSequence.new(0.5, 0.2)
	spray.Lifetime = NumberRange.new(0.9, 1.3)
	spray.Rate = 45
	spray.Speed = NumberRange.new(6, 9)
	spray.SpreadAngle = Vector2.new(35, 35)
	spray.Acceleration = Vector3.new(0, -22, 0)
	spray.LightEmission = 0.2
	spray.Parent = spout
	return m
end

-- Square stone planter with an olive or lemon tree.
function Med.planter(parent: Instance, ground: Vector3, rng: Random, tree: string): Model
	local m = newModel("Planter", parent)
	part(m, Vector3.new(7, 2, 7), CFrame.new(ground + Vector3.new(0, 1, 0)), STONE, M.Limestone)
	part(m, Vector3.new(6, 0.3, 6), CFrame.new(ground + Vector3.new(0, 2.05, 0)), DIRT, M.Ground)
	if tree == "olive" then
		Med.olive(m, ground + Vector3.new(0, 2, 0), rng, 0.85)
	else
		Med.pot(m, ground + Vector3.new(0, 2, 0), rng, "lemon")
	end
	return m
end

-- Keep the individual stones as decoration, with one smooth collision box per wall.
local function simplifyStoneWall(wall: Model)
	if wall:GetAttribute("CollisionVersion") == 1 then
		return
	end
	local stones = {}
	local frame: CFrame? = nil
	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = -minimum
	for _, stone in wall:GetChildren() do
		if not stone:IsA("BasePart") then
			continue
		end
		frame = frame or stone.CFrame
		table.insert(stones, stone)
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					local corner = frame:PointToObjectSpace(
						stone.CFrame:PointToWorldSpace(
							Vector3.new(stone.Size.X * x, stone.Size.Y * y, stone.Size.Z * z) / 2
						)
					)
					minimum = minimum:Min(corner)
					maximum = maximum:Max(corner)
				end
			end
		end
	end
	if not frame then
		return
	end
	local hitbox = part(wall, maximum - minimum, frame * CFrame.new((minimum + maximum) / 2), STONE_WALL, M.Slate)
	hitbox.Name = "WallHitbox"
	hitbox.CanCollide = true
	hitbox.CanQuery = true
	hitbox.Transparency = 1
	hitbox.CastShadow = false
	for _, stone in stones do
		stone.CanCollide = false
		stone.CanTouch = false
		stone.CanQuery = false
	end
	wall:SetAttribute("CollisionVersion", 1)
end

-- Dry-stone wall between two ground points.
function Med.stoneWall(parent: Instance, a: Vector3, b: Vector3, rng: Random): Model
	local m = newModel("StoneWall", parent)
	local length = (b - a).Magnitude
	local n = math.max(1, math.floor(length / 2.6))
	local dir = (b - a).Unit
	for i = 0, n - 1 do
		local p0, p1 = a + dir * (i * length / n), a + dir * ((i + 1) * length / n)
		local h = rng:NextNumber(2, 2.8)
		local lift = Vector3.new(0, h / 2 - 0.3, 0)
		part(
			m,
			Vector3.new(1.6 + (i % 2) * 0.12, h, length / n + 0.05),
			CFrame.lookAt((p0 + p1) / 2 + lift, p1 + lift),
			shade(STONE_WALL, rng, 0.1),
			M.Slate
		)
	end
	simplifyStoneWall(m)
	return m
end

-- Upgrade borders already baked into a saved map without rebuilding their stones.
function Med.ensureStoneWalls(root: Instance)
	for _, wall in root:GetDescendants() do
		if wall:IsA("Model") and wall.Name == "StoneWall" then
			simplifyStoneWall(wall)
		end
	end
end

-- Upgrade pergolas already baked into a saved map: their trellis and vines get
-- the same one roof box and hitbox-free greenery fresh builds get.
function Med.ensurePergolas(root: Instance)
	for _, model in root:GetDescendants() do
		if model:IsA("Model") and model.Name == "Pergola" then
			simplifyPergola(model)
		end
	end
end

-- Balconies baked before the single-hitbox policy carry every baluster and rail
-- as its own collider. Balcony posts are the only 0.14 x 2.6 x 0.14 ironwork in
-- the builders, so each cluster of them marks a balcony to collapse.
function Med.ensureBalconies(root: Instance)
	local collidable = {}
	for _, piece in root:GetDescendants() do
		if piece:IsA("BasePart") and piece.CanCollide then
			table.insert(collidable, piece)
		end
	end
	local posts = {}
	for _, piece in collidable do
		local size = piece.Size
		if
			piece.Material == M.Metal
			and math.abs(size.X - 0.14) < 0.01
			and math.abs(size.Y - 2.6) < 0.01
			and math.abs(size.Z - 0.14) < 0.01
		then
			table.insert(posts, piece)
		end
	end
	local taken = {}
	for _, seed in posts do
		if taken[seed] then
			continue
		end
		-- Balusters stand about a stud apart within one balcony; grow the
		-- cluster until no further post joins it.
		local group = { seed }
		taken[seed] = true
		local growing = true
		while growing do
			growing = false
			for _, post in posts do
				if taken[post] then
					continue
				end
				for _, member in group do
					if (post.Position - member.Position).Magnitude <= 4 then
						taken[post] = true
						table.insert(group, post)
						growing = true
						break
					end
				end
			end
		end
		if #group < 3 then
			continue
		end
		local frame = group[1].CFrame
		local minimum, maximum = boundsIn(frame, group)
		local pieces = table.clone(group)
		local inGroup = {}
		for _, piece in group do
			inGroup[piece] = true
		end
		-- The balcony's rails hug the posts at their top; its slab tops out at
		-- their feet. The door step below is deliberately left solid.
		for _, piece in collidable do
			if inGroup[piece] then
				continue
			end
			local center = frame:PointToObjectSpace(piece.Position)
			if
				center.X < minimum.X - 2.5
				or center.X > maximum.X + 2.5
				or center.Z < minimum.Z - 2.5
				or center.Z > maximum.Z + 2.5
			then
				continue
			end
			local top = center.Y + piece.Size.Y / 2
			local thin = math.min(piece.Size.X, piece.Size.Y, piece.Size.Z) <= 0.25
			local ironwork = piece.Material == M.Metal
				and thin
				and center.Y >= minimum.Y - 0.6
				and center.Y <= maximum.Y + 0.6
			local slab = math.abs(top - minimum.Y) <= 0.05
			if ironwork or slab then
				inGroup[piece] = true
				table.insert(pieces, piece)
			end
		end
		collapseBalcony(group[1].Parent, pieces, frame)
	end
end

-- Rows of vines on posts and wires over a patch of tilled earth, walled on three sides.
function Med.vineyard(parent: Instance, ground: Vector3, facing: number, rng: Random, w: number, d: number): Model
	local m = newModel("Vineyard", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	part(m, Vector3.new(w, 0.4, d), base * CFrame.new(0, 0.1, 0), DIRT, M.Ground).CastShadow = false
	local rows = math.floor(w / 3.6)
	for i = 1, rows do
		local x = -w / 2 + (i - 0.5) * w / rows
		for _, z in { -d / 2 + 1, d / 2 - 1 } do
			part(m, Vector3.new(0.4, 4, 0.4), base * CFrame.new(x, 2, z), WOOD_DARK, M.Wood)
		end
		part(m, Vector3.new(0.1, 0.1, d - 2), base * CFrame.new(x, 3.6, 0), IRON, M.Metal)
		for z = -d / 2 + 2.5, d / 2 - 2.5, 2.6 do
			blob(
				m,
				(base * CFrame.new(x, 2.6, z)).Position,
				Vector3.new(1.6, 2.2, 2.2),
				rng,
				shade(VINE, rng, 0.1),
				M.LeafyGrass
			)
			if rng:NextNumber() < 0.3 then
				ball(m, (base * CFrame.new(x + 0.9, 1.9, z)).Position, 0.7, rgb(90, 40, 90), M.SmoothPlastic)
			end
		end
	end
	local corners = {
		base:PointToWorldSpace(Vector3.new(-w / 2 - 1, 0, d / 2)),
		base:PointToWorldSpace(Vector3.new(-w / 2 - 1, 0, -d / 2 - 1)),
		base:PointToWorldSpace(Vector3.new(w / 2 + 1, 0, -d / 2 - 1)),
		base:PointToWorldSpace(Vector3.new(w / 2 + 1, 0, d / 2)),
	}
	for c = 1, 3 do
		Med.stoneWall(m, corners[c], corners[c + 1], rng)
	end
	return m
end

-- Painted wooden fishing boat floating at `position` (the waterline), bow on its local +Z.
function Med.boat(
	parent: Instance,
	position: Vector3,
	facing: number,
	rng: Random,
	color: Color3,
	dimensions: { length: number, width: number, mast: boolean }?
): Model
	local m = newModel("Boat", parent)
	local base = CFrame.new(position) * CFrame.Angles(0, facing, 0)
	local length = if dimensions then dimensions.length else rng:NextNumber(13, 17)
	local width = if dimensions then dimensions.width else rng:NextNumber(4.6, 5.6)
	local mid = length * 0.3
	local top, bottom = 1.4, -0.6

	-- Keep the floor inside the walls and above the waves. The old floor shared
	-- both outside wall faces and sat directly on the terrain water surface.
	local floor = part(m, Vector3.new(width - 0.88, 0.24, mid * 2), base * CFrame.new(0, 0.4, 0), WOOD, M.WoodPlanks)
	floor.Name = "BoatFloor"
	for side = -1, 1, 2 do
		local hull = part(
			m,
			Vector3.new(0.4, top - bottom, mid * 2),
			base * CFrame.new(side * (width / 2 - 0.2), (top + bottom) / 2, 0),
			WHITEWASH,
			M.WoodPlanks
		)
		hull.Name = "BoatSide"
		-- Cap the hull instead of laying paint over a coplanar inner wall.
		local rail = part(
			m,
			Vector3.new(0.5, 0.3, mid * 2),
			base * CFrame.new(side * (width / 2 - 0.2), top + 0.15, 0),
			color,
			M.WoodPlanks
		)
		rail.Name = "BoatRail"
	end
	for _, e in { 1, -1 } do
		local function p(x: number, y: number, z: number): Vector3
			return base:PointToWorldSpace(Vector3.new(x, y, z * e))
		end
		local tl, tr = p(-width / 2, top, mid), p(width / 2, top, mid)
		local bl, br = p(-width / 2, bottom, mid), p(width / 2, bottom, mid)
		local tip = p(0, top + (if e == 1 then 1 else 0.4), length / 2)
		local keel = p(0, bottom, length / 2 - 2)
		local inside = p(0, 0.4, mid + 1)
		-- Thin planking avoids the thick terrain wedges protruding through the
		-- neighboring bow/stern panels. The shared triangle helper retains its
		-- original thickness everywhere else on the map.
		LowPoly.triangle(tl, bl, keel, inside, WHITEWASH, m, M.WoodPlanks, 0.12)
		LowPoly.triangle(tl, keel, tip, inside, color, m, M.WoodPlanks, 0.12)
		LowPoly.triangle(tr, br, keel, inside, WHITEWASH, m, M.WoodPlanks, 0.12)
		LowPoly.triangle(tr, keel, tip, inside, color, m, M.WoodPlanks, 0.12)
		LowPoly.triangle(bl, br, keel, inside, WHITEWASH, m, M.WoodPlanks, 0.12)
		LowPoly.triangle(tl, tr, tip, inside, WOOD, m, M.WoodPlanks, 0.12)
	end
	for _, z in { -mid * 0.5, mid * 0.5 } do
		part(m, Vector3.new(width - 0.8, 0.3, 1.2), base * CFrame.new(0, 0.7, z), WOOD, M.WoodPlanks)
	end
	local mast = if dimensions then dimensions.mast else rng:NextNumber() < 0.5
	if mast then
		cylinder(m, base:PointToWorldSpace(Vector3.new(0, 4.5, mid * 0.5)), 8, 0.4, WOOD_DARK, M.Wood)
	else
		for side = -1, 1, 2 do
			beam(
				m,
				base:PointToWorldSpace(Vector3.new(side * 1, 1.2, -mid)),
				base:PointToWorldSpace(Vector3.new(side * 1.4, 1.2, mid)),
				0.3,
				WOOD,
				nil,
				M.Wood
			)
		end
	end
	m:SetAttribute("BoatGeometryVersion", 2)
	return m
end

-- Upgrade the decorative boats in saved maps too. Their original floor records
-- the exact position, rotation, beam and length, so no scenery is rerolled.
function Med.ensureBoats(root: Instance)
	for _, old in root:GetDescendants() do
		if not old:IsA("Model") or old.Name ~= "Boat" or old:GetAttribute("BoatGeometryVersion") == 2 then
			continue
		end
		local floor: BasePart? = nil
		local color: Color3? = nil
		local mast = false
		for _, child in old:GetChildren() do
			if child:IsA("Part") then
				local size = child.Size
				if math.abs(size.Y - 0.4) < 0.001 and size.X >= 4.6 and size.X <= 5.6 then
					floor = child
				elseif math.abs(size.X - 0.5) < 0.001 and math.abs(size.Y - 0.5) < 0.001 then
					color = child.Color
				elseif child.Shape == Enum.PartType.Cylinder and math.abs(size.X - 8) < 0.001 then
					mast = true
				end
			end
		end
		if floor and color then
			local frame = floor.CFrame
			Med.boat(
				old.Parent,
				frame.Position,
				math.atan2(-frame.LookVector.X, -frame.LookVector.Z),
				Random.new(0),
				color,
				{
					length = floor.Size.Z / 0.6,
					width = floor.Size.X,
					mast = mast,
				}
			)
			old:Destroy()
		end
	end
end

return Med
