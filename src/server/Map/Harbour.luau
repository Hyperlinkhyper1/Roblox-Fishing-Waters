-- The home island: a horseshoe of land wrapped around a sheltered bay that opens to the west.
-- Player bases line the bay shore (a quay plot with two piers each), a Mediterranean village of
-- whitewashed cube houses, pastel townhouses and villas rings them around a piazza, windmills and a
-- chapel crown the hills, and a lighthouse stands on the southern headland at the bay mouth.
-- The coastline is traced from the concept sketch in pixel coordinates and scaled into the world.

local CollectionService = game:GetService("CollectionService")

local BaseHouse = require(script.Parent.BaseHouse)
local BeachDetails = require(script.Parent.BeachDetails)
local Drydock = require(script.Parent.Drydock)
local FurnitureShop = require(script.Parent.FurnitureShop)
local BackpackShop = require(script.Parent.BackpackShop)
local Islands = require(script.Parent.Islands)
local LowPoly = require(script.Parent.LowPoly)
local Med = require(script.Parent.Mediterranean)
local PlazaHouses = require(script.Parent.PlazaHouses)
local Props = require(script.Parent.Props)
local RodShop = require(script.Parent.RodShop)
local Seabed = require(script.Parent.Seabed)

local Harbour = {}

local rgb = Color3.fromRGB
local pick = Props.pick
local M = Enum.Material
local TAU = math.pi * 2

local SCALE = 0.85 -- studs per sketch pixel
local SKETCH_CENTER = Vector2.new(870, 1330) -- sketch pixel that lands on the biome center
local CELL = 16 -- ground mesh resolution
local SEABED_RUN = 128 -- continuous underwater descent from shore to the deep floor
local GROUND_MARGIN = SEABED_RUN + CELL
local LAND = 5 -- height of the flat village ground
local ROAD_OFFSET = 95 -- how far inland the ring road runs from the bay shore
local ROAD_WIDTH = 16
local LANE_OFFSET = 40 -- how far behind the ring road the back lane runs, past the first row of houses
local LANE_WIDTH = 10
local VILLAGE_BAND = 165 -- land closer than this to the bay stays flat; further inland rises into hills and cliffs
local PLAZA_HALF = 60 -- the piazza is a square this far from its centre to each edge

-- Roughly how far the island reaches from its center, for keeping other islands away.
Harbour.FOOTPRINT = 820
Harbour.BASE_TAG = "PlayerBase"

-- Sea-facing coast, clockwise from the tip of the western arm round to the southern headland.
-- The north and east shores bulge past the sketch so the piazza and the eastern bases
-- keep room for the road and a row or two of houses behind them.
local OUTER = {
	{ 430, 1340 },
	{ 372, 1290 },
	{ 330, 1200 },
	{ 312, 1090 },
	{ 318, 970 },
	{ 345, 860 },
	{ 395, 760 },
	{ 448, 672 },
	{ 528, 588 },
	{ 640, 515 },
	{ 780, 473 },
	{ 950, 477 },
	{ 1120, 510 },
	{ 1270, 552 },
	{ 1365, 600 },
	{ 1430, 680 },
	{ 1505, 790 },
	{ 1565, 945 },
	{ 1610, 1120 },
	{ 1632, 1320 },
	{ 1615, 1520 },
	{ 1560, 1712 },
	{ 1465, 1880 },
	{ 1325, 2018 },
	{ 1150, 2098 },
	{ 950, 2130 },
	{ 760, 2140 },
	{ 580, 2110 },
	{ 430, 2050 },
	{ 320, 1960 },
	{ 262, 1850 },
	{ 250, 1740 },
	{ 265, 1640 },
	{ 290, 1565 },
}

-- Bay shore, from the southern headland round the inner bay and back to the western arm.
local BAY = {
	{ 350, 1555 },
	{ 450, 1553 },
	{ 550, 1565 },
	{ 650, 1598 },
	{ 760, 1640 },
	{ 850, 1640 },
	{ 950, 1620 },
	{ 1030, 1630 },
	{ 1100, 1668 },
	{ 1170, 1690 },
	{ 1240, 1660 },
	{ 1305, 1585 },
	{ 1345, 1480 },
	{ 1362, 1360 },
	{ 1348, 1262 },
	{ 1290, 1182 },
	{ 1200, 1122 },
	{ 1105, 1090 },
	{ 1045, 1050 },
	{ 1012, 980 },
	{ 985, 902 },
	{ 940, 852 },
	{ 870, 818 },
	{ 760, 820 },
	{ 685, 850 },
	{ 652, 905 },
	{ 663, 1000 },
	{ 680, 1118 },
	{ 660, 1190 },
	{ 600, 1255 },
	{ 520, 1300 },
}

-- The "n" shapes on the sketch, as points on the bay shore.
local BASES = { { 668, 1030 }, { 1000, 950 }, { 1150, 1105 }, { 1360, 1330 }, { 1340, 1500 }, { 880, 1638 } }
local LIGHTHOUSE = { 360, 1640 }
-- The bathing beach round the head of the bay, between the first two bases.
local BEACH = { { 660, 975 }, { 652, 905 }, { 685, 850 }, { 760, 820 }, { 870, 818 }, { 940, 852 }, { 985, 902 } }
local BEACH_WIDTH = 42 -- dry sand from the waterline up to the foot of the dunes
local BEACH_FADE = 45 -- the beach blends back into the normal shore over this much coastline at each end
-- Set back from the bay so the ring road runs along the piazza's southern side; the drydock
-- slipway needs the bay about 130 studs south of the centre, so move this with SCALE.
local PLAZA = { 870, 665 }

-- Sun-baked Mediterranean ground: dry grass, maquis on the hills, pale limestone cliffs
local GRASS = rgb(146, 148, 90)
local HILL = rgb(116, 124, 74)
local SAND = rgb(224, 208, 166)
local BEACH_SAND = rgb(242, 228, 188)
local WET_SAND = rgb(196, 176, 136)
local DUNE_GRASS = { rgb(150, 156, 92), rgb(170, 168, 104), rgb(126, 140, 80) }
local BEACH_COLORS = { rgb(214, 64, 56), rgb(40, 120, 196), rgb(240, 186, 52), rgb(40, 156, 140), rgb(226, 112, 150) }
local ROCK = rgb(186, 176, 156)
local ROAD = rgb(204, 192, 168)
local DIRT = rgb(178, 140, 98)
local PAVING = rgb(228, 216, 194)
local PAVING_DARK = rgb(176, 160, 134)
local QUAY = rgb(150, 140, 126)
local DECK = rgb(132, 102, 74)

local ACCENTS = {
	rgb(60, 110, 170),
	rgb(180, 60, 50),
	rgb(70, 140, 80),
	rgb(220, 180, 60),
	rgb(130, 80, 160),
	rgb(220, 120, 50),
}
local MAQUIS = { rgb(92, 110, 64), rgb(110, 120, 70), rgb(78, 98, 60) }
local BOATS = { rgb(36, 92, 168), rgb(190, 60, 50), rgb(60, 140, 90), rgb(230, 180, 60), rgb(40, 140, 160) }

type Shape = {
	coast: { Vector2 },
	bayShore: { Vector2 },
	beach: { Vector2 },
	beachLength: number,
	center: Vector2,
	flats: { Spot }, -- areas kept level even past the village band
	toWorld: ({ number }) -> Vector2,
}
type Spot = { position: Vector2, radius: number }
type RoadPoint = { position: Vector2, inland: Vector2 }
type Street = { RoadPoint } -- an unbroken run of street, in order

----------------------------------------------------------------------------------------------------
-- Geometry

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function segmentDistance(p: Vector2, a: Vector2, b: Vector2): (number, Vector2)
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
	local q = a + ab * t
	return (p - q).Magnitude, q
end

local function isInside(poly: { Vector2 }, p: Vector2): boolean
	local inside = false
	local j = #poly
	for i = 1, #poly do
		local a, b = poly[i], poly[j]
		if (a.Y > p.Y) ~= (b.Y > p.Y) and p.X < (b.X - a.X) * (p.Y - a.Y) / (b.Y - a.Y) + a.X then
			inside = not inside
		end
		j = i
	end
	return inside
end

-- Nearest point on a polyline and the segment direction there.
local function nearestOnLine(line: { Vector2 }, p: Vector2): (number, Vector2, Vector2)
	local best, point, tangent = math.huge, p, Vector2.new(1, 0)
	for i = 1, #line - 1 do
		local dist, q = segmentDistance(p, line[i], line[i + 1])
		if dist < best then
			best, point, tangent = dist, q, (line[i + 1] - line[i]).Unit
		end
	end
	return best, point, tangent
end

-- Signed distance to the coast: positive on land, negative at sea.
local function coastDistance(shape: Shape, p: Vector2): number
	local coast = shape.coast
	local best = math.huge
	local j = #coast
	for i = 1, #coast do
		best = math.min(best, (segmentDistance(p, coast[j], coast[i])))
		j = i
	end
	return if isInside(coast, p) then best else -best
end

-- How much `p` belongs to the bathing beach: 1 along its middle, fading out at both ends and away
-- from the shore.
local function beachWeight(shape: Shape, p: Vector2): number
	local line = shape.beach
	local best, along, walked = math.huge, 0, 0
	for i = 1, #line - 1 do
		local a, b = line[i], line[i + 1]
		local dist, q = segmentDistance(p, a, b)
		if dist < best then
			best, along = dist, walked + (q - a).Magnitude
		end
		walked += (b - a).Magnitude
	end
	return smoothstep(along / BEACH_FADE)
		* smoothstep((walked - along) / BEACH_FADE)
		* (1 - smoothstep((best - 100) / 40))
end

local function beachWidthAt(p: Vector2): number
	return BEACH_WIDTH + math.noise(p.X / 42, p.Y / 42, 3.7) * 10
end

local function heightAt(shape: Shape, p: Vector2): number
	-- Water must extend beneath the original lift and out through its slipway.
	-- Keep the channel's sloping banks underneath the existing quay walls.
	local plaza = shape.toWorld(PLAZA)
	local dx, dz = math.abs(p.X - plaza.X), p.Y - plaza.Y
	if dx < 25 and dz > 108 and dz < 238 then
		local bank = math.clamp((25 - dx) / 8, 0, 1)
		local ends = math.min(math.clamp((dz - 108) / 8, 0, 1), math.clamp((238 - dz) / 8, 0, 1))
		if bank * ends >= 1 then
			return -18
		end
	end
	local d = coastDistance(shape, p)
	local beach = beachWeight(shape, p)
	if d <= 0 then
		return Seabed.height(-d, SEABED_RUN)
	end

	local h = LAND
	if d < 10 then
		h = 1.5 * d / 10
	elseif d < 24 then
		h = 1.5 + (LAND - 1.5) * smoothstep((d - 10) / 14)
	end
	if beach > 0 then
		-- A wide, nearly flat strand, then a low dune up to the village
		local width = beachWidthAt(p)
		local sand = if d < width then 2 * d / width else 2 + (LAND - 2) * smoothstep((d - width) / 16)
		-- Small wind-shaped undulations fade out before the level village ground.
		sand += math.noise(p.X / 19, p.Y / 19, 2.4) * 0.24 * smoothstep(d / 10) * (1 - smoothstep((d - width) / 12))
		h += (sand - h) * beach
	end

	-- Away from the bay the land climbs: cliffs along the open-sea coast, wooded hills inland
	local inland = smoothstep(((nearestOnLine(shape.bayShore, p)) - VILLAGE_BAND) / 65)
	for _, f in shape.flats do
		inland *= smoothstep(((p - f.position).Magnitude - f.radius) / 40)
	end
	if inland <= 0 then
		return h
	end
	local cliff = smoothstep((d - 3) / 12)
	local hill = smoothstep((d - 60) / 80)
	local noise = math.clamp(math.noise(p.X / 190, p.Y / 190, 7.3) + 0.5, 0, 1)
	return h + inland * (cliff * 12 + hill * (8 + 34 * noise))
end

local function makeShape(center: Vector2): Shape
	local function toWorld(p: { number }): Vector2
		return center + (Vector2.new(p[1], p[2]) - SKETCH_CENTER) * SCALE
	end
	local flats = { { position = toWorld(PLAZA), radius = PLAZA_HALF * 1.6 } }
	local coast, bayShore = {}, { toWorld(OUTER[#OUTER]) }
	for _, p in OUTER do
		table.insert(coast, toWorld(p))
	end
	for i, p in BAY do
		local a = toWorld(p)
		table.insert(coast, a)
		table.insert(bayShore, a)
		if i >= 20 and i <= 27 then
			-- The bathing cove follows one shared curve for land, props and surf.
			-- Keep the sketch's main anchors, rounding the long straight beach edges.
			local prev, b, nxt = toWorld(BAY[i - 1]), toWorld(BAY[i + 1]), toWorld(BAY[i + 2])
			local steps = math.ceil((b - a).Magnitude / 8)
			for k = 1, steps - 1 do
				local t = k / steps
				local q = (
					a * 2
					+ (b - prev) * t
					+ (prev * 2 - a * 5 + b * 4 - nxt) * t * t
					+ (-prev + a * 3 - b * 3 + nxt) * t * t * t
				) * 0.5
				table.insert(coast, q)
				table.insert(bayShore, q)
			end
		end
	end
	table.insert(bayShore, toWorld(OUTER[1]))
	local function coordinate(p: Vector2): (number, Vector2)
		local best, index, point = math.huge, 1, p
		for i = 1, #bayShore - 1 do
			local a, b = bayShore[i], bayShore[i + 1]
			local distance, q = segmentDistance(p, a, b)
			if distance < best then
				best, index, point = distance, i + (q - a).Magnitude / (b - a).Magnitude, q
			end
		end
		return index, point
	end
	local first, a = coordinate(toWorld(BEACH[1]))
	local last, b = coordinate(toWorld(BEACH[#BEACH]))
	local beach = { a }
	for i = math.ceil(first) - 1, math.floor(last) + 1, -1 do
		table.insert(beach, bayShore[i])
	end
	table.insert(beach, b)
	local beachLength = 0
	for i = 2, #beach do
		beachLength += (beach[i] - beach[i - 1]).Magnitude
	end
	return {
		coast = coast,
		bayShore = bayShore,
		beach = beach,
		beachLength = beachLength,
		center = center,
		flats = flats,
		toWorld = toWorld,
	}
end

-- Nearest point on the bay shore and the direction out over the water from it.
local function shoreAt(shape: Shape, p: Vector2): (Vector2, Vector2)
	local _, point, tangent = nearestOnLine(shape.bayShore, p)
	local normal = Vector2.new(-tangent.Y, tangent.X)
	if isInside(shape.coast, point + normal * 10) then
		normal = -normal
	end
	return point, normal
end

local function isFree(spots: { Spot }, p: Vector2, radius: number): boolean
	for _, s in spots do
		if (s.position - p).Magnitude < s.radius + radius then
			return false
		end
	end
	return true
end

local function reserve(spots: { Spot }, p: Vector2, radius: number)
	table.insert(spots, { position = p, radius = radius })
end

local function flat(shape: Shape, p: Vector2, radius: number): boolean
	for _, o in
		{
			Vector2.zero,
			Vector2.new(radius, 0),
			Vector2.new(-radius, 0),
			Vector2.new(0, radius),
			Vector2.new(0, -radius),
		}
	do
		if heightAt(shape, p + o) ~= LAND then
			return false
		end
	end
	return true
end

local function ground(p: Vector2, lift: number?): Vector3
	return Vector3.new(p.X, LAND + (lift or 0), p.Y)
end

local function facingToward(from: Vector2, to: Vector2): number
	local dir = to - from
	return math.atan2(dir.X, dir.Y)
end

----------------------------------------------------------------------------------------------------
-- Ground mesh and seabed

local function buildGround(shape: Shape, parent: Model, rng: Random)
	local groundModel = Instance.new("Model")
	groundModel.Name = "Ground"
	groundModel:SetAttribute("DrydockChannelVersion", 1)
	groundModel.Parent = parent

	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, p in shape.coast do
		minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
		minZ, maxZ = math.min(minZ, p.Y), math.max(maxZ, p.Y)
	end
	minX, minZ = minX - GROUND_MARGIN, minZ - GROUND_MARGIN
	local cols = math.ceil((maxX + GROUND_MARGIN - minX) / CELL)
	local rows = math.ceil((maxZ + GROUND_MARGIN - minZ) / CELL)

	local vertices = {}
	for i = 0, cols do
		vertices[i] = {}
		for k = 0, rows do
			local p = Vector2.new(minX + i * CELL, minZ + k * CELL)
			local h = heightAt(shape, p)
			-- Shared vertices keep every seam closed. Level village vertices stay on the
			-- grid so the merged grass slabs still meet the beach exactly.
			local amount = beachWeight(shape, p) * math.clamp((LAND - h) / 1.2, 0, 1)
			if amount > 0 then
				p += Vector2.new(
					math.clamp(math.noise(i * 1.73, k * 2.31, 11.7), -0.5, 0.5),
					math.clamp(math.noise(i * 2.17, k * 1.91, 29.3), -0.5, 0.5)
				) * CELL * 0.48 * amount
				h = heightAt(shape, p)
			end
			vertices[i][k] = Vector3.new(p.X, h, p.Y)
		end
		if i % 10 == 0 then
			task.wait()
		end
	end

	local function face(a: Vector3, b: Vector3, c: Vector3)
		local normal = (b - a):Cross(c - a).Unit
		local y = (a.Y + b.Y + c.Y) / 3
		local mid = (a + b + c) / 3
		local beach = beachWeight(shape, Vector2.new(mid.X, mid.Z))
		local color, material
		if y < LAND - 0.01 and math.abs(normal.Y) > 0.9 and beach > 0.35 then
			local wet = smoothstep((y + 0.9) / 0.9) * (1 - smoothstep(y / 1.1))
			color = BEACH_SAND:Lerp(WET_SAND, wet):Lerp(GRASS, smoothstep((y - 2.8) / 2.2))
			material = M.Sand
		elseif y < 0 then
			color, material = SAND, M.Sand
		elseif math.abs(normal.Y) < 0.72 then
			color, material = ROCK, M.Limestone
		elseif y < 2.2 then
			color, material = SAND, M.Sand
		elseif y > LAND + 6 then
			color, material = HILL, M.LeafyGrass
		else
			color, material = GRASS, M.Grass
		end
		-- Continuous, restrained sand variation avoids a checkerboard of random tiles.
		local shade = if beach > 0.1 or y < 0
			then 1 + math.noise(mid.X / 35, mid.Z / 35, 17.8) * 0.035
			else rng:NextNumber(0.94, 1.04)
		color = Color3.new(math.min(color.R * shade, 1), math.min(color.G * shade, 1), math.min(color.B * shade, 1))
		LowPoly.triangle(a, b, c, (a + b + c) / 3 - Vector3.new(0, 40, 0), color, groundModel, material)
	end

	for k = 0, rows - 1 do
		local z0 = minZ + k * CELL
		-- Flat village ground is merged into one slab per run of cells
		local runStart: number? = nil
		local function flush(endI: number)
			if runStart then
				local x0, x1 = minX + runStart * CELL, minX + endI * CELL
				Props.part(
					groundModel,
					Vector3.new(x1 - x0, 4, CELL),
					CFrame.new((x0 + x1) / 2, LAND - 2, z0 + CELL / 2),
					GRASS:Lerp(HILL, rng:NextNumber(0, 0.2)),
					M.Grass
				)
				runStart = nil
			end
		end
		for i = 0, cols - 1 do
			local a, b, c, d = vertices[i][k], vertices[i + 1][k], vertices[i][k + 1], vertices[i + 1][k + 1]
			if
				a.Y == LAND
				and b.Y == LAND
				and c.Y == LAND
				and d.Y == LAND
				and a.X == minX + i * CELL
				and a.Z == z0
				and b.X == minX + (i + 1) * CELL
				and b.Z == z0
				and c.X == minX + i * CELL
				and c.Z == z0 + CELL
				and d.X == minX + (i + 1) * CELL
				and d.Z == z0 + CELL
			then
				runStart = runStart or i
			else
				flush(i)
				if math.max(a.Y, b.Y, c.Y, d.Y) > Seabed.Floor then
					if (i + k) % 2 == 0 then
						face(a, b, c)
						face(b, d, c)
					else
						face(a, b, d)
						face(a, d, c)
					end
				end
			end
		end
		flush(cols)
		task.wait()
	end
end

----------------------------------------------------------------------------------------------------
-- Paths

local function resample(line: { Vector2 }, step: number): { Vector2 }
	local out = { line[1] }
	local carry = 0
	for i = 1, #line - 1 do
		local a, b = line[i], line[i + 1]
		local length = (b - a).Magnitude
		local t = step - carry
		while t <= length do
			table.insert(out, a:Lerp(b, t / length))
			t += step
		end
		carry = length - (t - step)
	end
	return out
end

-- Flat strip of path from `a` to `b` whose top sits `top` above the village ground, with a round
-- joint at `a` so bends join up without gaps. Overlapping pieces must never share a top height or
-- they z-fight: joints sit a step below the strips, and `raised` lets neighbouring strips alternate.
local PATH_STEP = 0.08

local function pathSegment(
	parent: Instance,
	a: Vector2,
	b: Vector2,
	width: number,
	color: Color3,
	material: Enum.Material,
	top: number,
	raised: boolean?
)
	local thickness = 0.6
	if (b - a).Magnitude > 0.5 then
		local y = top + (if raised then PATH_STEP else 0) - thickness / 2
		Props.beam(parent, ground(a, y), ground(b, y), width, color, thickness, material).CastShadow = false
	end
	local joint = Props.cylinder(parent, ground(a, top - PATH_STEP - thickness / 2), thickness, width, color, material)
	joint.CastShadow = false
end

-- True when the whole stretch from `a` to `b` stays on the island, back from the coast and out of
-- the keep-out spots, so a street can run along it.
local function roadClear(shape: Shape, keepOut: { Spot }, a: Vector2, b: Vector2): boolean
	local n = math.max(1, math.ceil((b - a).Magnitude / 6))
	for k = 0, n do
		local m = a:Lerp(b, k / n)
		if not (isInside(shape.coast, m) and coastDistance(shape, m) > 22 and isFree(keepOut, m, 4)) then
			return false
		end
	end
	return true
end

-- Street following the bay shore `offset` inland, as runs of points. It only breaks where it has to
-- (at the coast or a keep-out spot); runs too short to read as a street are left out.
local function buildRoad(
	shape: Shape,
	parent: Instance,
	name: string,
	keepOut: { Spot },
	offset: number,
	width: number,
	top: number
): { Street }
	local points: { RoadPoint } = {}
	for _, s in resample(shape.bayShore, 8) do
		-- Start straight inland from the shore, then settle onto the line that is exactly `offset`
		-- from the nearest shore point; that untangles the fold-backs at tight bends.
		local _, point, tangent = nearestOnLine(shape.bayShore, s)
		local inland = Vector2.new(-tangent.Y, tangent.X)
		if not isInside(shape.coast, point + inland * 10) then
			inland = -inland
		end
		local p = point + inland * offset
		for _ = 1, 4 do
			local _, q = nearestOnLine(shape.bayShore, p)
			p = q + (p - q).Unit * offset
		end
		local _, q = nearestOnLine(shape.bayShore, p)
		inland = (p - q).Unit

		if isInside(shape.coast, p) and coastDistance(shape, p) > 26 and isFree(keepOut, p, 4) then
			local last = points[#points]
			if not last then
				table.insert(points, { position = p, inland = inland })
			elseif (p - last.position).Magnitude >= 7 then
				local heading = if #points >= 2
					then (last.position - points[#points - 1].position).Unit
					else (p - last.position).Unit
				-- Points that land behind the previous one come from the inside of a bend; skip them
				if (p - last.position).Unit:Dot(heading) > -0.2 then
					table.insert(points, { position = p, inland = inland })
				end
			end
		end
	end

	-- Ease out the kinks left where fold-back points were skipped
	for _ = 1, 3 do
		local before = table.clone(points)
		for i = 2, #points - 1 do
			local a, b, c = before[i - 1].position, before[i].position, before[i + 1].position
			if (a - b).Magnitude < 30 and (c - b).Magnitude < 30 then
				points[i] = { position = b * 0.5 + (a + c) * 0.25, inland = before[i].inland }
			end
		end
	end

	-- Neighbours join whenever the whole stretch between them is clear, however far apart the
	-- skipped bend left them; a run only ends where the street has to stop.
	local runs: { Street } = {}
	local run: Street = {}
	for _, p in points do
		local last = run[#run]
		if
			last
			and not (
				(p.position - last.position).Magnitude < 120 and roadClear(shape, keepOut, last.position, p.position)
			)
		then
			table.insert(runs, run)
			run = {}
		end
		table.insert(run, p)
	end
	table.insert(runs, run)

	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	local streets: { Street } = {}
	for _, r in runs do
		local length = 0
		for i = 2, #r do
			length += (r[i].position - r[i - 1].position).Magnitude
		end
		if length < 40 then
			continue
		end
		table.insert(streets, r)
		for i, a in r do
			-- Square the inland direction to the street now that it has been smoothed
			local prev, nxt = r[math.max(i - 1, 1)].position, r[math.min(i + 1, #r)].position
			local normal = Vector2.new(prev.Y - nxt.Y, nxt.X - prev.X).Unit
			a.inland = if normal:Dot(a.inland) < 0 then -normal else normal

			local b = r[i + 1]
			pathSegment(
				model,
				a.position,
				if b then b.position else a.position,
				width,
				ROAD,
				M.Cobblestone,
				top,
				i % 2 == 0
			)
			-- Kerb stones along both edges of the main road
			if width >= ROAD_WIDTH and i % 3 == 0 then
				for _, side in { -1, 1 } do
					local kerb = a.position + a.inland * side * (width / 2 + 0.6)
					Props.part(model, Vector3.new(1.2, 0.8, 1.2), CFrame.new(ground(kerb, 0.3)), QUAY, M.Slate)
				end
			end
		end
	end
	return streets
end

local function nearestRoad(streets: { Street }, p: Vector2): RoadPoint
	local best, point = math.huge, streets[1][1]
	for _, street in streets do
		for _, r in street do
			local d = (r.position - p).Magnitude
			if d < best then
				best, point = d, r
			end
		end
	end
	return point
end

-- Keep houses off a laid path by reserving spots along it.
local function reservePath(spots: { Spot }, a: Vector2, b: Vector2, radius: number)
	local n = math.max(1, math.ceil((b - a).Magnitude / 6))
	for k = 0, n do
		reserve(spots, a:Lerp(b, k / n), radius)
	end
end

----------------------------------------------------------------------------------------------------
-- Beach: umbrellas and loungers on the sand, a lifeguard tower, cabanas and palms along the dunes,
-- boats hauled up at the waterline, surf foam and tide-line clutter, and boardwalks up to the road.

-- Waterline point `along` studs down the beach, and the direction inland from it.
local function beachFrame(shape: Shape, along: number): (Vector2, Vector2)
	local line = shape.beach
	local i = 1
	while i < #line - 1 and along > (line[i + 1] - line[i]).Magnitude do
		along -= (line[i + 1] - line[i]).Magnitude
		i += 1
	end
	local a, b = line[i], line[i + 1]
	local point, out = shoreAt(shape, a:Lerp(b, math.clamp(along / (b - a).Magnitude, 0, 1)))
	return point, -out
end

local function buildSurf(shape: Shape, island: Model, beach: Instance)
	-- Invisible shoreline samples drive the client's moving, soft-edged surf.
	-- No static foam geometry remains on the water when the waves fade out.
	local old = beach:FindFirstChild("Surf")
	if old then
		old:Destroy()
	end
	local surfModel = Instance.new("Model")
	surfModel.Name = "Surf"
	surfModel.Parent = beach
	local length = shape.beachLength
	local function surfaceAt(point: Vector2): Vector3
		return Islands.surface(island, point.X, point.Y) or Vector3.new(point.X, heightAt(shape, point), point.Y)
	end
	local start = BEACH_FADE * 0.65
	for along = start, length - start - 14, 14 do
		local a, inlandA = beachFrame(shape, along)
		local b, inlandB = beachFrame(shape, along + 13)
		local origin = (a + b) / 2
		local source = Instance.new("Part")
		source.Name = "ShoreWaveSource"
		source.Anchored = true
		source.Size = Vector3.new(1, 1, 1)
		source.CFrame = CFrame.new(origin.X, 0, origin.Y)
		source.Transparency = 1
		source.CanCollide = false
		source.CanTouch = false
		source.CanQuery = false
		source.CastShadow = false
		for index, sample in { { a, inlandA }, { b, inlandB } } do
			local point, inland = sample[1], sample[2]
			local surface = surfaceAt(point)
			local runup = surfaceAt(point + inland * 2.8)
			source:SetAttribute("Shore" .. index, Vector3.new(point.X - origin.X, 0, point.Y - origin.Y))
			source:SetAttribute("Inland" .. index, Vector3.new(inland.X, 0, inland.Y))
			source:SetAttribute("WaterHeight" .. index, math.max(0.16, surface.Y + 0.08))
			source:SetAttribute("RunupHeight" .. index, math.max(0.16, runup.Y + 0.08))
		end
		source:SetAttribute("Along", along)
		source:SetAttribute(
			"EdgeFade",
			smoothstep((along - start) / 24) * smoothstep((length - start - along - 13) / 24)
		)
		source.Parent = surfModel
		CollectionService:AddTag(source, "ShoreWaveSource")
	end
	surfModel:SetAttribute("ShoreWavesVersion", 1)
end

local function buildBeach(shape: Shape, island: Model, parent: Instance, spots: { Spot }, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Beach"
	model.Parent = parent
	local length = shape.beachLength
	local function sand(p: Vector2, lift: number?): Vector3
		-- Props sit on the rendered triangles, including the gently uneven dunes.
		local surface = Islands.surface(island, p.X, p.Y)
		return (surface or Vector3.new(p.X, heightAt(shape, p), p.Y)) + Vector3.new(0, lift or 0, 0)
	end
	-- Spot `depth` studs up the beach from the waterline at `along`, and the facing out to sea there
	local function spot(along: number, depth: number): (Vector2, number)
		local point, inland = beachFrame(shape, along)
		local p = point + inland * depth
		return p, facingToward(p, p - inland)
	end

	-- Keep trees and houses off the sand
	for along = BEACH_FADE * 0.6, length - BEACH_FADE * 0.6, 12 do
		local point, inland = beachFrame(shape, along)
		reserve(spots, point + inland * 28, 26)
	end
	buildSurf(shape, island, model)

	-- Landmarks along the strand, as fractions of its length
	local tower = length * 0.5
	local net = length * 0.78
	local cabanas = { length * 0.22, length * 0.36 }
	local walks = { length * 0.3, length * 0.66 }
	local function clearWalk(along: number, radius: number): boolean
		for _, walk in walks do
			if math.abs(along - walk) < radius + 2.5 then
				return false
			end
		end
		return true
	end

	local p, facing = spot(tower, 30)
	Props.lifeguardTower(model, sand(p), facing)
	p, facing = spot(net, 26)
	Props.volleyballNet(model, sand(p), facing)

	-- Umbrella pitches: an umbrella with a lounger or two beside it and maybe a towel in front
	for along = BEACH_FADE + 8, length - BEACH_FADE - 8, 22 do
		if math.abs(along - tower) < 16 or math.abs(along - net) < 18 or not clearWalk(along, 10) then
			continue
		end
		local depth = rng:NextNumber(16, 28)
		local color = pick(rng, BEACH_COLORS)
		local point, inland = beachFrame(shape, along + rng:NextNumber(-4, 4))
		local side = Vector2.new(-inland.Y, inland.X)
		local base = point + inland * depth
		local seaward = facingToward(base, base - inland)
		Props.beachUmbrella(model, sand(base), rng, color)
		for k = 1, rng:NextInteger(1, 2) do
			local s = if k == 1 then -1 else 1
			local loungerAt = base + side * s * 3.2 + inland * 1.5
			Props.sunLounger(model, sand(loungerAt), seaward + rng:NextNumber(-0.15, 0.15), pick(rng, BEACH_COLORS))
		end
		if rng:NextNumber() < 0.55 then
			local towelAt = base - inland * rng:NextNumber(6, 9) + side * rng:NextNumber(-3, 3)
			local _, normal = Islands.surface(island, towelAt.X, towelAt.Y)
			Props.towel(
				model,
				sand(towelAt, 0.08),
				seaward + rng:NextNumber(-0.5, 0.5),
				pick(rng, BEACH_COLORS),
				normal
			)
		end
	end

	-- Changing cabanas in a row at the foot of the dunes
	for _, from in cabanas do
		for k = 0, 3 do
			local at, face = spot(from + k * 8, 46)
			Props.cabana(model, sand(at, -0.3), face, BEACH_COLORS[(k % #BEACH_COLORS) + 1])
			reserve(spots, at, 5)
		end
	end

	-- Palms and dune grass along the top of the sand
	for along = BEACH_FADE, length - BEACH_FADE, 16 do
		if not clearWalk(along, 10) then
			continue
		end
		local inCabanas = false
		for _, from in cabanas do
			inCabanas = inCabanas or (along > from - 8 and along < from + 32)
		end
		local at = spot(along + rng:NextNumber(-5, 5), rng:NextNumber(48, 55))
		if not inCabanas and rng:NextNumber() < 0.7 then
			Props.palm(model, sand(at), rng)
			reserve(spots, at, 4)
		end
		local tuft = spot(along + rng:NextNumber(-8, 8), rng:NextNumber(40, 52))
		Props.bush(model, sand(tuft, -0.6), rng, DUNE_GRASS)
	end

	-- Boardwalks from the road down over the dunes onto the sand
	for _, along in walks do
		local point, inland = beachFrame(shape, along)
		local foot, top, road = point + inland * 32, point + inland * (BEACH_WIDTH + 16), point + inland * ROAD_OFFSET
		Props.beam(model, sand(foot, 0.3), sand(top, 0.3), 4.5, DECK, 0.5, M.WoodPlanks)
		Props.beam(model, ground(top, 0.3), ground(road, 0.3), 4.5, DECK, 0.5, M.WoodPlanks)
		local side = Vector2.new(-inland.Y, inland.X)
		for _, s in { -1, 1 } do
			local edge = side * s * 2.6
			Props.fence(model, sand(foot + edge + inland * 4), sand(top + edge))
		end
		reservePath(spots, top, road, 5)
	end

	-- Boats hauled up on the sand
	for _, along in { length * 0.14, length * 0.42, length * 0.58 } do
		local at, face = spot(along, rng:NextNumber(7, 10))
		Med.boat(model, sand(at, 0.4), face + rng:NextNumber(-0.4, 0.4), rng, pick(rng, BOATS))
	end
	-- Sandcastles and loose beach balls near the water
	for _, along in { length * 0.33, length * 0.7 } do
		local at = spot(along + rng:NextNumber(-6, 6), rng:NextNumber(9, 13))
		Props.sandcastle(model, sand(at), BEACH_SAND:Lerp(WET_SAND, 0.4))
	end
	for _ = 1, 3 do
		local at = spot(rng:NextNumber(BEACH_FADE + 10, length - BEACH_FADE - 10), rng:NextNumber(12, 30))
		Props.beachBall(model, sand(at))
	end

	-- Tide line: seaweed, shells and driftwood
	for _ = 1, 14 do
		local at = spot(rng:NextNumber(BEACH_FADE, length - BEACH_FADE), rng:NextNumber(1.5, 5))
		Props.seaweed(model, sand(at), rng)
	end
	for _ = 1, 12 do
		local at = spot(rng:NextNumber(BEACH_FADE, length - BEACH_FADE), rng:NextNumber(3, 14))
		Props.shells(model, sand(at), rng)
	end
	for _ = 1, 6 do
		local at = spot(rng:NextNumber(BEACH_FADE, length - BEACH_FADE), rng:NextNumber(8, 18))
		Props.driftwood(model, sand(at), rng)
	end
	BeachDetails.build(model, rng, length, function(along: number): (Vector2, Vector2)
		return beachFrame(shape, along)
	end, sand)
end

----------------------------------------------------------------------------------------------------
-- Player bases: a stone quay plot on the shore with two piers reaching into the bay

local DOCK_DETAIL_VERSION = 2

local function ensureDockAccess(base: Model, frame: CFrame)
	local existing = base:FindFirstChild("DockAccess")
	if existing and existing:GetAttribute("LayoutVersion") == 2 then
		return
	end
	if existing then
		existing:Destroy()
	end
	-- Remove only the original raised blocks on maps saved before ramps existed.
	for _, item in base:GetChildren() do
		if item:IsA("BasePart") then
			local p = frame:PointToObjectSpace(item.Position)
			if
				(item.Size - Vector3.new(7, 2.6, 3.2)).Magnitude < 0.01
				and math.abs(math.abs(p.X) - 17) < 0.01
				and math.abs(p.Y - 3.1) < 0.01
				and math.abs(p.Z - 6.4) < 0.01
			then
				item:Destroy()
			end
		end
	end
	local access = Instance.new("Model")
	access.Name = "DockAccess"
	local wood = Color3.fromRGB(133, 96, 62)
	local worn = Color3.fromRGB(158, 122, 81)
	local dark = Color3.fromRGB(77, 55, 39)
	local iron = Color3.fromRGB(52, 50, 48)
	local rope = Color3.fromRGB(176, 150, 106)
	local rise, run, thickness = 2.7, 8, 0.4
	local length = math.sqrt(run * run + rise * rise)
	local slope = CFrame.Angles(-math.atan2(rise, run), 0, 0)
	for _, side in { -1, 1 } do
		local gangway = Instance.new("Model")
		gangway.Name = if side < 0 then "LeftGangway" else "RightGangway"
		gangway.Parent = access
		local center = frame * CFrame.new(side * 17, 4.55, 4) * slope
		local function piece(
			name: string,
			size: Vector3,
			cf: CFrame,
			color: Color3,
			material: Enum.Material,
			decorative: boolean?
		): Part
			local part = Props.part(gangway, size, cf, color, material)
			part.Name = name
			if decorative then
				part.CanCollide, part.CanQuery = false, false
			end
			return part
		end
		-- A continuous collider carries players and NPCs across the narrow plank seams.
		-- Its top still meets the pier at y=3.2 and the quay at y=5.9.
		local ramp = piece(
			"DockRamp",
			Vector3.new(7, thickness, length + 0.2),
			center * CFrame.new(0, -thickness / 2, 0),
			wood,
			M.Wood
		)
		ramp.Transparency = 1
		ramp.CastShadow = false
		local count = 10
		local pitch = (length + 0.2) / count
		for i = 1, count do
			local z = (i - (count + 1) / 2) * pitch
			piece(
				"GangwayPlank",
				Vector3.new(7, thickness, pitch - 0.035),
				center * CFrame.new(0, -thickness / 2, z),
				wood:Lerp(worn, (i % 3) * 0.2),
				M.Wood,
				true
			)
		end
		for _, edge in { -1, 1 } do
			piece(
				"Stringer",
				Vector3.new(0.5, 0.8, length + 0.3),
				center * CFrame.new(edge * 3.15, -0.7, 0),
				dark,
				M.Wood,
				true
			)
			local x = side * 17 + edge * 3.9
			for _, z in { 0.4, 7.8, 10.6 } do
				local y = 3.2 + rise * math.min(z, run) / run
				piece("RailPost", Vector3.new(0.55, 3.1, 0.55), frame * CFrame.new(x, y + 1.3, z), dark, M.Wood)
				piece("PostCap", Vector3.new(0.7, 0.12, 0.7), frame * CFrame.new(x, y + 2.91, z), worn, M.Wood, true)
				piece(
					"PostCollar",
					Vector3.new(0.57, 0.18, 0.57),
					frame * CFrame.new(x, y + 0.45, z),
					iron,
					M.Metal,
					true
				)
			end
			for _, span in { { 0.4, 7.8 }, { 7.8, 10.6 } } do
				for _, rail in { { 2.65, 0.24, wood, M.Wood, "Handrail" }, { 1.35, 0.16, rope, M.Fabric, "RopeRail" } } do
					local function at(z: number): Vector3
						return frame * Vector3.new(x, 3.2 + rise * math.min(z, run) / run + rail[1], z)
					end
					local beam = Props.beam(gangway, at(span[1]), at(span[2]), rail[2], rail[3], nil, rail[4])
					beam.Name = rail[5]
					beam.CanCollide, beam.CanQuery = false, false
				end
			end
		end
		-- A short boarded apron bridges the coloured quay lip onto the base deck.
		local landing =
			piece("QuayLanding", Vector3.new(7, 0.3, 2.8), frame * CFrame.new(side * 17, 5.76, 9.4), dark, M.Wood)
		landing.Transparency = 1
		landing.CastShadow = false
		for i = 1, 4 do
			piece(
				"LandingPlank",
				Vector3.new(7, 0.3, 0.665),
				frame * CFrame.new(side * 17, 5.76, 8 + (i - 0.5) * 0.7),
				wood:Lerp(worn, (i % 3) * 0.2),
				M.Wood,
				true
			)
		end
		for _, z in { 0.6, 6.9 } do
			local y = 3.2 + rise * z / run
			piece(
				"Bearer",
				Vector3.new(8.4, 0.55, 0.65),
				frame * CFrame.new(side * 17, y - 1.05, z),
				dark,
				M.Wood,
				true
			)
		end
	end
	access:SetAttribute("LayoutVersion", 2)
	access.Parent = base
end

-- The legacy post extended through the lower half of the board and obscured both faces.
local function ensureDockSign(base: Model)
	local board = base:FindFirstChild("NameBoard")
	if not board or not board:IsA("BasePart") then
		return
	end
	for _, item in base:GetChildren() do
		if not item:IsA("BasePart") then
			continue
		end
		local legacyPost = (item.Size - Vector3.new(0.6, 6, 0.6)).Magnitude < 0.01
			and (board.CFrame:PointToObjectSpace(item.Position) - Vector3.new(0, -3, 0)).Magnitude < 0.01
		if item.Name == "DockSignPost" or legacyPost then
			item.Name = "DockSignPost"
			item.Size = Vector3.new(0.6, 4.5, 0.6)
			item.CFrame = board.CFrame * CFrame.new(0, -3.75, 0)
		end
	end
end

local function buildBaseDocks(base: Model, frame: CFrame, index: number)
	-- Cosmetic variation has its own stream, so adding joinery never moves village props.
	local rng = Random.new(82417 + index * 997)
	for _, side in { -1, 1 } do
		Props.dock(base, (frame * CFrame.new(side * 17, 0, 5)).Position, frame.LookVector, 48, rng, {
			innerSide = -side,
			junctionStart = 40,
			junctionEnd = 46.8,
		})
	end
	Props.dockLink(base, frame * CFrame.new(0, 3, -38), rng)
	ensureDockAccess(base, frame)
	base:SetAttribute("DockDetailVersion", DOCK_DETAIL_VERSION)
end

local function buildBase(
	shape: Shape,
	parent: Instance,
	index: number,
	anchor: Vector2,
	rng: Random
): (Vector2, Vector2)
	local shore, toWater = shoreAt(shape, anchor)
	local origin = Vector3.new(shore.X, 0, shore.Y)
	local forward = Vector3.new(toWater.X, 0, toWater.Y)
	local frame = CFrame.lookAt(origin, origin + forward)
	-- f: studs toward the water (negative = inland), r: studs to the right when facing the water
	local function cf(f: number, r: number, y: number): CFrame
		return frame * CFrame.new(r, y, -f)
	end
	local function at(f: number, r: number, y: number): Vector3
		return cf(f, r, y).Position
	end

	local accent = ACCENTS[(index - 1) % #ACCENTS + 1]
	local top = LAND + 0.5
	local deck = top + 0.4
	local facing = math.atan2(forward.X, forward.Z)

	local m = Instance.new("Model")
	m.Name = "Base" .. index
	m:SetAttribute("BaseId", index)
	m:SetAttribute("OwnerUserId", 0)
	m:SetAttribute("BoatDockFrame", frame)
	CollectionService:AddTag(m, Harbour.BASE_TAG)
	m.Parent = parent

	-- Stone quay with a plank deck, edged in the owner's colour
	Props.part(m, Vector3.new(58, 9, 52), cf(-34, 0, top - 4.5), QUAY, M.Cobblestone)
	Props.part(m, Vector3.new(55, 0.4, 49), cf(-34.5, 0, top + 0.2), DECK, M.WoodPlanks)
	Props.part(m, Vector3.new(58.4, 1, 1.2), cf(-8, 0, top - 0.3), accent, M.WoodPlanks)
	for _, r in { -29, 29 } do
		Props.part(m, Vector3.new(1.2, 1, 52), cf(-34, r, top - 0.3), accent, M.WoodPlanks)
	end
	-- Mooring bollards along the front
	for r = -24, 24, 12 do
		if math.abs(r) ~= 12 then
			Props.cylinder(m, at(-9, r, deck + 0.8), 1.6, 1.4, rgb(52, 50, 48), M.Metal)
		end
	end

	-- Ramps connect the quay to the two boarded piers without a jump.
	buildBaseDocks(m, frame, index)

	-- Keep the legacy prop builders' RNG draws: the beach and village share this
	-- seeded stream. BaseHouse.ensure replaces these props below, so upgrading
	-- the house does not also reshuffle the rest of the island.
	local hut = Props.fishingHut(m, at(-44, 10, deck), facing, rng, accent)
	hut.Name = "Hut"
	local pad = Props.cylinder(m, at(-26, -12, deck + 0.15), 0.3, 11, accent, M.Neon)
	pad.Name = "ClaimPad"
	-- Retain the plot reference and accent without a visible circle on the deck.
	pad.Transparency = 1
	pad.CanCollide = false
	pad.CanTouch = false
	pad.CanQuery = false
	m.PrimaryPart = pad

	-- Name board facing both ways; BaseService writes the owner's name on it
	local signPost = Props.part(m, Vector3.new(0.6, 4.5, 0.6), cf(-11, -22, deck + 2.25), rgb(78, 60, 46), M.Wood)
	signPost.Name = "DockSignPost"
	local board = Props.part(m, Vector3.new(7, 3, 0.4), cf(-11, -22, deck + 6), rgb(122, 92, 64), M.WoodPlanks)
	board.Name = "NameBoard"
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
		label.TextColor3 = rgb(245, 238, 220)
		label.Text = "Base " .. index
		label.Parent = gui
		gui.Parent = board
	end

	local flagAt = at(-56, -25, deck)
	Props.flag(m, flagAt, accent)
	Props.lampPost(m, at(-10.5, 27, deck))
	Props.lampPost(m, at(-10.5, -27, deck))
	-- Festoon lights from the flagpole to the lamps, like a little fairground over the quay
	Props.stringLights(m, flagAt + Vector3.new(0, 14, 0), at(-10.5, -27, deck + 10.6), rng)
	Props.stringLights(m, at(-10.5, -27, deck + 10.6), at(-10.5, 27, deck + 10.6), rng)
	Props.crates(m, at(-15, 22, deck), rng)
	Props.barrel(m, at(-19, 25, deck), rng)
	Props.barrel(m, at(-15.5, 25.5, deck), rng)
	Props.crabPot(m, at(-21, 18, deck), rng)
	Props.crabPot(m, at(-14, -4, deck), rng)
	Props.ropeCoil(m, at(-12, 6, deck))
	Props.fishRack(m, at(-38, -21, deck), facing + math.pi / 2, rng)
	Props.bench(m, at(-30, -24, deck), facing - math.pi / 2)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnPoint"
	spawn.Anchored = true
	spawn.Size = Vector3.new(5, 0.2, 5)
	spawn.CFrame = cf(-26, 4, deck + 0.2)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = m
	Drydock.ensureDock(m)
	BaseHouse.ensure(m)

	local center = at(-34, 0, 0)
	local back = at(-62, 0, 0)
	return Vector2.new(center.X, center.Z), Vector2.new(back.X, back.Z)
end
----------------------------------------------------------------------------------------------------
-- Village

-- The piazza: a domed church and bell tower along the north side flanked by shops, a two-tier
-- fountain in the middle, a café under a pergola to the west and market stalls to the east.
-- The bay lies to the south (+Z), so the buildings face that way; the ring road crosses the south side.
local function buildPlaza(parent: Instance, center: Vector2, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Plaza"
	model.Parent = parent
	local function at(x: number, z: number, lift: number?): Vector3
		return ground(center + Vector2.new(x, z), lift)
	end
	local function slab(size: Vector3, x: number, z: number, lift: number, color: Color3, material: Enum.Material)
		Props.part(model, size, CFrame.new(at(x, z, lift)), color, material).CastShadow = false
	end
	local size = PLAZA_HALF * 2
	local pavingSize = size - 4

	-- Pale limestone laid in a grid of darker bands, edged with a kerb, with a ring round the fountain
	-- The curb owns the outside faces; paving and inlays stop at its inner edge.
	slab(Vector3.new(pavingSize, 0.6, pavingSize), 0, 0, 0.5, PAVING, M.Limestone)
	for k = -2, 2 do
		-- Each crossing belongs to the north/south band. The other band butts up
		-- against it, instead of placing two differently textured faces on one plane.
		slab(Vector3.new(1.4, 0.12, pavingSize), k * 24, 0, 0.86, PAVING_DARK, M.Cobblestone)
		local from = -PLAZA_HALF + 2
		for crossing = -2, 3 do
			local edge = if crossing == 3 then PLAZA_HALF - 2 else crossing * 24 - 0.7
			slab(Vector3.new(edge - from, 0.12, 1.4), (from + edge) / 2, k * 24, 0.86, PAVING_DARK, M.Cobblestone)
			from = edge + 1.4
		end
	end
	for _, e in { -1, 1 } do
		slab(Vector3.new(size, 0.8, 2), 0, e * (PLAZA_HALF - 1), 0.64, PAVING_DARK, M.Slate)
		slab(Vector3.new(2, 0.8, size - 4), e * (PLAZA_HALF - 1), 0, 0.64, PAVING_DARK, M.Slate)
	end
	model:SetAttribute("PlazaPavingVersion", 2)
	Props.cylinder(model, at(0, 0, 0.7), 0.7, 40, PAVING_DARK, M.Cobblestone).CastShadow = false
	Props.cylinder(model, at(0, 0, 0.8), 0.7, 36, PAVING, M.Limestone).CastShadow = false
	Med.fountain(model, at(0, 0, 1.15))
	for _, offset in { Vector2.new(0, -16.5), Vector2.new(0, 16.5), Vector2.new(-16.5, 0), Vector2.new(16.5, 0) } do
		Med.pot(model, at(offset.X, offset.Y, 0.95), rng, "flowers")
	end
	for _, offset in { Vector2.new(-14, -14), Vector2.new(14, -14), Vector2.new(14, 14), Vector2.new(-14, 14) } do
		local p = center + offset
		Props.bench(model, ground(p, 0.95), facingToward(p, center))
	end

	-- North side: church, campanile and two shops, all facing the fountain
	Med.chapel(model, at(0, -40, 0.8), 0, rng, 1.5)
	Med.bellTower(model, at(-19, -47, 0.8), 0, rng)
	for _, x in { -42, 42 } do
		Med.townhouse(model, at(x, -47, 0.8), 0, rng, true)
	end
	for _, x in { -14, 14 } do
		Med.cypress(model, at(x, -24, 0.8), rng, rng:NextNumber(19, 23))
	end

	-- West: café tables under a vine-covered pergola, and a few more out in the sun
	Med.pergola(model, at(-42, -4, 0.8), 0, rng, 18, 22)
	for _, offset in { Vector2.new(-46.5, -9), Vector2.new(-37.5, -9), Vector2.new(-46.5, 2), Vector2.new(-37.5, 2) } do
		Med.cafeTable(model, at(offset.X, offset.Y, 0.8), rng)
	end
	local parasols = { rgb(36, 92, 168), rgb(180, 52, 44), rgb(56, 120, 70) }
	for i, offset in { Vector2.new(-25, -11), Vector2.new(-26, 9), Vector2.new(-24, 30) } do
		Med.cafeTable(model, at(offset.X, offset.Y, 0.8), rng, parasols[i])
	end
	for _, z in { -17, 9 } do
		Med.pot(model, at(-53, z, 0.8), rng, "lemon")
	end

	-- East: a row of market stalls facing across the square
	local canopies = { rgb(180, 52, 44), rgb(36, 92, 168), rgb(56, 120, 70), rgb(214, 160, 50) }
	for i, z in { -18, -6, 6, 18 } do
		local p = center + Vector2.new(44, z)
		Props.stall(model, ground(p, 0.8), facingToward(p, Vector2.new(center.X, p.Y)), rng, canopies[i])
		if i % 2 == 0 then
			Props.barrel(model, ground(p + Vector2.new(8, 3), 0.8), rng)
		end
	end

	-- South: a promenade of palms, benches looking out over the bay, and olive planters
	for _, x in { -34, -10, 10, 34 } do
		Props.palm(model, at(x, 52, 0.8), rng)
	end
	for _, x in { -22, 0, 22 } do
		Props.bench(model, at(x, 54, 0.8), 0)
	end
	for _, x in { -46, 46 } do
		Med.planter(model, at(x, 51, 0.8), rng, "olive")
	end

	-- Lamps round the edge with festoons strung between them and across the square
	local lamps = {}
	for _, x in { -56, 56 } do
		for _, z in { -18, 22, 56 } do
			Props.lampPost(model, at(x, z, 0.8))
			lamps[`{x},{z}`] = at(x, z, 12.4)
		end
	end
	local function festoon(a: string, b: string, sag: number?)
		Props.stringLights(model, lamps[a], lamps[b], rng, sag)
	end
	festoon("-56,-18", "-56,22")
	festoon("-56,22", "-56,56")
	festoon("56,-18", "56,22")
	festoon("56,22", "56,56")
	festoon("-56,56", "56,56", 3)
	festoon("-56,-18", "56,-18", 2)
	festoon("-56,22", "56,22", 2)
	Drydock.build(model, CFrame.new(at(0, 0, 0.8)))
	RodShop.build(model, CFrame.new(at(0, 0, 0.8)))
	FurnitureShop.build(model, CFrame.new(at(0, 0, 0.8)))
	BackpackShop.build(model, CFrame.new(at(0, 0, 0.8)))
end

local HOUSE_HALF = { cube = 14, town = 10, villa = 15, green = 9 } -- half the frontage along the street
local HOUSE_FRONT = { cube = 10, town = 9, villa = 16, green = 4 } -- how far the doorstep sits from the middle
local RING_KINDS = { { "cube", 0.4 }, { "town", 0.35 }, { "villa", 0.15 }, { "green", 0.1 } }
local LANE_KINDS = { { "cube", 0.5 }, { "town", 0.42 }, { "green", 0.08 } }

local function rollKind(kinds: { { any } }, rng: Random): string
	local roll = rng:NextNumber()
	for _, k in kinds do
		roll -= k[2]
		if roll <= 0 then
			return k[1]
		end
	end
	return kinds[#kinds][1]
end

-- Points every `step` studs along a street, each with the direction away from the bay.
local function streetFrames(street: Street, step: number): { RoadPoint }
	local frames = {}
	for i = 1, #street - 1 do
		local a, b = street[i], street[i + 1]
		local n = math.max(1, math.floor((b.position - a.position).Magnitude / step))
		for k = 0, n - 1 do
			local t = k / n
			table.insert(
				frames,
				{ position = a.position:Lerp(b.position, t), inland = a.inland:Lerp(b.inland, t).Unit }
			)
		end
	end
	return frames
end

-- One house (or a little green) at `p` with its front to the street at `toward`, and a bit of
-- life round the doorstep and sometimes a walled yard out back.
local function placeHouse(
	shape: Shape,
	model: Instance,
	kind: string,
	p: Vector2,
	toward: Vector2,
	lane: boolean,
	spots: { Spot },
	rng: Random
)
	local half = HOUSE_HALF[kind]
	local toStreet = (toward - p).Unit
	local across = Vector2.new(-toStreet.Y, toStreet.X)
	local facing = facingToward(p, toward) + rng:NextNumber(-0.04, 0.04)
	reserve(spots, p, 10)
	for _, s in { -1, 1 } do
		reserve(spots, p + across * s * (half - 5), 6)
	end

	if kind == "green" then
		if lane and rng:NextNumber() < 0.5 then
			Med.vineyard(model, ground(p), facing, rng, 16, 14)
		else
			-- A small olive green between houses
			Med.olive(model, ground(p - toStreet * 2), rng)
			Props.bench(model, ground(p + toStreet * 4), facing)
			Med.lavender(model, ground(p + across * 5), rng)
			Med.lavender(model, ground(p - across * 5), rng)
		end
		return
	end
	if kind == "cube" then
		Med.cubeHouse(model, ground(p), facing, rng)
	elseif kind == "town" then
		Med.townhouse(model, ground(p), facing, rng)
	else
		Med.villa(model, ground(p), facing, rng)
		return
	end

	local front = p + toStreet * (HOUSE_FRONT[kind] + 1)
	local extra = rng:NextNumber()
	if extra < 0.25 then
		Med.pot(model, ground(front + across * 6), rng)
		Med.pot(model, ground(front + across * 7.6), rng)
	elseif extra < 0.4 then
		Props.bench(model, ground(front - across * 6), facing)
	elseif extra < 0.5 and not lane then
		Med.cafeTable(model, ground(front + across * 7), rng)
	end
	if rng:NextNumber() < 0.35 then
		-- Walled yard out back with an olive or a lemon tree
		local yard = p - toStreet * 16
		if flat(shape, yard, 7) and isFree(spots, yard, 6) then
			reserve(spots, yard, 6)
			local corners = {
				yard + across * 7 + toStreet * 4,
				yard + across * 7 - toStreet * 4,
				yard - across * 7 - toStreet * 4,
				yard - across * 7 + toStreet * 4,
			}
			for c = 1, 3 do
				Med.stoneWall(model, ground(corners[c]), ground(corners[c + 1]), rng)
			end
			Props.part(
				model,
				Vector3.new(13, 0.4, 7),
				CFrame.new(ground(yard, 0.1)) * CFrame.Angles(0, facing, 0),
				DIRT,
				M.Ground
			)
			if rng:NextNumber() < 0.5 then
				Med.olive(model, ground(yard + across * 3), rng, 0.8)
			else
				Med.pot(model, ground(yard + across * 3), rng, "lemon")
			end
			Med.lavender(model, ground(yard - across * 3), rng)
		end
	end
end

-- A terrace of houses shoulder to shoulder along one side of a street (`side` 1 is away from the
-- bay), every door facing it. Each slot slides along until its house fits, so the row stays tight.
local function lineStreet(
	shape: Shape,
	model: Instance,
	street: Street,
	side: number,
	width: number,
	kinds: { { any } },
	spots: { Spot },
	rng: Random
)
	local last: Vector2?, lastHalf = nil, 0
	local kind = rollKind(kinds, rng)
	local gap = if kind == "town" then 0.6 else rng:NextNumber(1.5, 3.5)
	for n, f in streetFrames(street, 3) do
		local half = HOUSE_HALF[kind]
		local p = f.position + f.inland * side * (width / 2 + HOUSE_FRONT[kind] + 2)
		if last and (p - last).Magnitude < lastHalf + half + gap then
			continue
		end
		if
			isInside(shape.coast, p)
			and coastDistance(shape, p) > 30
			and flat(shape, p, half - 2)
			and isFree(spots, p, 9)
		then
			placeHouse(shape, model, kind, p, f.position, width < ROAD_WIDTH, spots, rng)
			last, lastHalf = p, half
		end
		-- Whether it fitted or not, the next slot gets a fresh roll so a big house can't stall a row
		kind = rollKind(kinds, rng)
		gap = if kind == "town" then 0.6 else rng:NextNumber(1.5, 3.5)
		if n % 40 == 0 then
			task.wait()
		end
	end
end

local function buildHouses(
	shape: Shape,
	parent: Instance,
	road: { Street },
	lanes: { Street },
	spots: { Spot },
	rng: Random
)
	local model = Instance.new("Model")
	model.Name = "Houses"
	model.Parent = parent

	-- Lamps go in first so the houses leave room for them
	local lamps = {}
	for _, street in road do
		for i, r in street do
			if i % 5 == 1 then
				local side = if i % 10 == 1 then 1 else -1
				local lampAt = r.position + r.inland * side * (ROAD_WIDTH / 2 + 1)
				Props.lampPost(model, ground(lampAt))
				reserve(spots, lampAt, 0.5)
				table.insert(lamps, ground(lampAt))
			end
		end
	end
	-- Bulbs strung across the road between some of the lamps
	for i = 1, #lamps - 1, 2 do
		local a, b = lamps[i], lamps[i + 1]
		if (a - b).Magnitude < 70 then
			Props.stringLights(model, a + Vector3.new(0, 10.6, 0), b + Vector3.new(0, 10.6, 0), rng)
		end
	end

	-- Both sides of the ring road, then the far side of each back lane; the near side of a lane is
	-- the backs of the ring road's inland row.
	for _, street in road do
		for _, side in { -1, 1 } do
			lineStreet(shape, model, street, side, ROAD_WIDTH, RING_KINDS, spots, rng)
		end
	end
	for _, street in lanes do
		lineStreet(shape, model, street, 1, LANE_WIDTH, LANE_KINDS, spots, rng)
	end
end

-- Windmills along the ridges above the village and a chapel on a hilltop, turned toward the bay
-- so they show from the water.
local function buildHilltops(shape: Shape, island: Model, spots: { Spot }, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Hilltops"
	model.Parent = island
	local coast = shape.coast

	local candidates = {}
	for _ = 1, 500 do
		local p = coast[rng:NextInteger(1, #coast)]:Lerp(shape.center, rng:NextNumber(0.05, 0.5))
		if
			isInside(coast, p)
			and coastDistance(shape, p) > 40
			and (nearestOnLine(shape.bayShore, p)) > VILLAGE_BAND + 60
		then
			local spot, normal = Islands.surface(island, p.X, p.Y)
			if spot and normal and normal.Y > 0.95 then
				table.insert(candidates, spot)
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.Y > b.Y
	end)

	local built = 0
	for _, spot in candidates do
		local p = Vector2.new(spot.X, spot.Z)
		if isFree(spots, p, 70) then
			reserve(spots, p, 18)
			local facing = facingToward(p, shape.center)
			if built == 1 then
				Props.part(
					model,
					Vector3.new(24, 10, 26),
					CFrame.new(spot - Vector3.new(0, 5.5, 0)) * CFrame.Angles(0, facing, 0),
					ROCK,
					M.Limestone
				)
				Med.chapel(model, spot - Vector3.new(0, 0.8, 0), facing, rng)
				local side = Vector3.new(math.cos(facing), 0, -math.sin(facing))
				for _, s in { -1, 1 } do
					Med.cypress(model, spot + side * s * 13 - Vector3.new(0, 0.5, 0), rng)
				end
			else
				Props.cylinder(model, spot - Vector3.new(0, 4, 0), 8, 22, ROCK, M.Limestone)
				Med.windmill(model, spot - Vector3.new(0, 0.5, 0), facing, rng)
			end
			built += 1
			if built >= 4 then
				break
			end
		end
	end
end

local function buildForest(shape: Shape, island: Model, spots: { Spot }, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Forest"
	model.Parent = island
	local placed = 0
	local coast = shape.coast
	for attempt = 1, 2600 do
		if placed >= 420 then
			break
		end
		local p = coast[rng:NextInteger(1, #coast)]:Lerp(shape.center, rng:NextNumber(0, 1))
			+ Vector2.new(rng:NextNumber(-100, 100), rng:NextNumber(-100, 100))
		if isInside(coast, p) and coastDistance(shape, p) > 8 and isFree(spots, p, 6) then
			local spot, normal = Islands.surface(island, p.X, p.Y)
			if spot and normal and normal.Y > 0.75 and spot.Y > 2 then
				reserve(spots, p, 5)
				local roll = rng:NextNumber()
				if spot.Y > LAND + 3 then
					-- Hills: umbrella pines and cypresses over maquis scrub
					if roll < 0.3 then
						Med.stonePine(model, spot, rng)
					elseif roll < 0.5 then
						Med.cypress(model, spot, rng)
					elseif roll < 0.65 then
						Med.olive(model, spot, rng)
					elseif roll < 0.9 then
						Props.bush(model, spot, rng, MAQUIS)
					else
						Med.lavender(model, spot, rng)
					end
				elseif roll < 0.35 then
					Med.olive(model, spot, rng)
				elseif roll < 0.5 then
					Med.cypress(model, spot, rng)
				elseif roll < 0.6 then
					Props.palm(model, spot, rng)
				elseif roll < 0.8 then
					Props.bush(model, spot, rng, MAQUIS)
				elseif roll < 0.9 then
					Med.lavender(model, spot, rng)
				else
					Props.flowers(model, spot, rng)
				end
				placed += 1
			end
		end
		if attempt % 100 == 0 then
			task.wait()
		end
	end
	-- Pale limestone rocks on the rocky coast; keep the bathing beach and its
	-- waterline clear, including a margin for the largest boulder's footprint.
	for _ = 1, 100 do
		local p = coast[rng:NextInteger(1, #coast)]
		local q = p:Lerp(coast[rng:NextInteger(1, #coast)], rng:NextNumber(0, 0.03))
		local spot = Islands.surface(island, q.X + rng:NextNumber(-14, 14), q.Y + rng:NextNumber(-14, 14))
		if
			spot
			and spot.Y > -3
			and nearestOnLine(shape.beach, Vector2.new(spot.X, spot.Z)) > BEACH_WIDTH + 24
			and isFree(spots, Vector2.new(spot.X, spot.Z), 4)
		then
			Props.boulder(model, spot, rng, rng:NextNumber(3, 8), ROCK, M.Limestone)
		end
	end
end

-- Painted fishing boats riding at anchor around the bay, clear of the base piers.
local function buildBoats(shape: Shape, island: Model, rng: Random, avoid: { Vector2 })
	local model = Instance.new("Model")
	model.Name = "Boats"
	model.Parent = island
	local line = shape.bayShore
	local placed: { Vector2 } = {}
	for _ = 1, 80 do
		if #placed >= 10 then
			break
		end
		local k = rng:NextInteger(1, #line - 1)
		local point, out = shoreAt(shape, line[k]:Lerp(line[k + 1], rng:NextNumber()))
		local p = point + out * rng:NextNumber(28, 90)
		local clear = coastDistance(shape, p) < -16
		for _, a in avoid do
			clear = clear and (a - p).Magnitude > 80
		end
		for _, b in placed do
			clear = clear and (b - p).Magnitude > 30
		end
		if clear then
			table.insert(placed, p)
			Med.boat(model, Vector3.new(p.X, 0, p.Y), rng:NextNumber(0, TAU), rng, pick(rng, BOATS))
		end
	end
end

----------------------------------------------------------------------------------------------------

-- Also available to charts of places baked before coast metadata was saved.
function Harbour.chartCoast(center: Vector2): { { number } }
	local coast = {}
	for _, point in makeShape(center).coast do
		table.insert(coast, { point.X, point.Y })
	end
	return coast
end

function Harbour.build(parent: Instance, rng: Random, center: Vector2): CFrame
	local island = Instance.new("Model")
	island.Name = "Harbour Isle"
	island.Parent = parent

	local shape = makeShape(center)
	local coast = {}
	for _, point in shape.coast do
		table.insert(coast, { point.X, point.Y })
	end
	island:SetAttribute("ChartCoast", game:GetService("HttpService"):JSONEncode(coast))
	buildGround(shape, island, rng)

	local village = Instance.new("Model")
	village.Name = "Village"
	village.Parent = island
	local spots: { Spot } = {}

	-- Landmarks first so the road and houses keep clear of them
	local plaza = shape.toWorld(PLAZA)
	reserve(spots, plaza, PLAZA_HALF * 1.42)
	reserve(spots, plaza + Vector2.new(0, 82), 31)
	-- Keep shore clutter clear of the rear repair basin and its water approach.
	reservePath(spots, plaza + Vector2.new(0, 104), plaza + Vector2.new(0, 198), 23)
	local lighthouse = shape.toWorld(LIGHTHOUSE)
	reserve(spots, lighthouse, 34)

	local bases = Instance.new("Folder")
	bases.Name = "Bases"
	bases.Parent = island
	local baseBacks, baseShores = {}, {}
	for index, anchor in BASES do
		local world = shape.toWorld(anchor)
		local middle, back = buildBase(shape, bases, index, world, rng)
		reserve(spots, middle, 36)
		table.insert(baseBacks, back)
		table.insert(baseShores, (shoreAt(shape, world)))
		task.wait()
	end
	buildBeach(shape, island, village, spots, rng)

	-- The road gives way to the piazza's paving where it crosses the square
	local keepOut = {
		{ position = lighthouse, radius = 26 },
		{ position = plaza, radius = PLAZA_HALF + 2 },
	}
	local road = buildRoad(shape, village, "Road", keepOut, ROAD_OFFSET, ROAD_WIDTH, 0.6)
	for _, street in road do
		for i = 2, #street do
			reservePath(spots, street[i - 1].position, street[i].position, ROAD_WIDTH / 2 + 1)
		end
	end

	-- A back lane behind the first row of houses gives the second row a street of its own to face;
	-- cross streets tie it to the ring road at each end and every block or so in between.
	local lanes = buildRoad(shape, village, "Lane", keepOut, ROAD_OFFSET + LANE_OFFSET, LANE_WIDTH, 0.45)
	local crossStreets = Instance.new("Model")
	crossStreets.Name = "CrossStreets"
	crossStreets.Parent = village
	for _, street in lanes do
		for i, r in street do
			if i > 1 then
				reservePath(spots, street[i - 1].position, r.position, LANE_WIDTH / 2 + 0.5)
			end
			if (i - 1) % 12 == 0 or i == #street then
				local joint = nearestRoad(road, r.position)
				local reach = (joint.position - r.position).Magnitude
				if reach < LANE_OFFSET + 25 and roadClear(shape, keepOut, joint.position, r.position) then
					pathSegment(crossStreets, r.position, joint.position, LANE_WIDTH, ROAD, M.Cobblestone, 0.3)
					reservePath(spots, r.position, joint.position, LANE_WIDTH / 2 + 5)
				end
			end
		end
	end

	-- Dirt tracks from each base and the lighthouse up to the road, with signposts at the junctions
	for i, back in baseBacks do
		local joint = nearestRoad(road, back)
		pathSegment(village, back, joint.position, 9, DIRT, M.Pebble, 0.4)
		reservePath(spots, back, joint.position, 11)
		local signAt = joint.position - joint.inland * (ROAD_WIDTH / 2 + 2)
		local side = Vector2.new(-joint.inland.Y, joint.inland.X)
		Props.signpost(
			village,
			ground(signAt + side * 7),
			facingToward(signAt, back) - math.pi / 2,
			{ { "Base " .. i, 0 } }
		)
		reserve(spots, signAt + side * 7, 2)
	end
	local toLighthouse = nearestRoad(road, lighthouse)
	local lighthouseGate = lighthouse + (toLighthouse.position - lighthouse).Unit * 17
	pathSegment(village, lighthouseGate, toLighthouse.position, 9, DIRT, M.Pebble, 0.4)
	reservePath(spots, lighthouseGate, toLighthouse.position, 11)

	buildPlaza(village, plaza, rng)
	local plazaRoad = nearestRoad(road, plaza)
	Props.signpost(
		village,
		ground(plazaRoad.position + plazaRoad.inland * -(ROAD_WIDTH / 2 + 3), 0.6),
		facingToward(plazaRoad.position, plaza) - math.pi / 2,
		{ { "Plaza", 0 }, { "Lighthouse", math.pi } }
	)

	Props.lighthouse(village, ground(lighthouse))
	local cottage = lighthouse + Vector2.new(36, 4)
	if flat(shape, cottage, 12) and isFree(spots, cottage, 14) then
		Med.cubeHouse(village, ground(cottage), facingToward(cottage, lighthouse), rng)
		reserve(spots, cottage, 16)
	end

	buildHouses(shape, village, road, lanes, spots, rng)
	buildHilltops(shape, island, spots, rng)
	buildForest(shape, island, spots, rng)
	-- The piazza's own terraces go in last, clearing any generated house or tree off their plots
	PlazaHouses.build(village:FindFirstChild("Plaza") :: Model, CFrame.new(ground(plaza, 0.8)))
	buildBoats(shape, island, rng, baseShores)
	Harbour.ensureBaseOneBoatClearance(island)
	Harbour.ensureLaunchClearance(island)

	-- Buoys marking the way into the bay
	local mouthA, mouthB = shape.toWorld(OUTER[1]), shape.toWorld(OUTER[#OUTER])
	for _, t in { 0.25, 0.75 } do
		for _, out in { 40, 190 } do
			local p = mouthA:Lerp(mouthB, t) + Vector2.new(-out, 0)
			Props.buoy(island, Vector3.new(p.X, 0, p.Y), rng)
		end
	end

	return CFrame.new(ground(plaza + Vector2.new(0, 34), 3.5))
end

-- Upgrade only the generated dock pieces, keeping claimed bases and their controls intact.
-- Saved Studio maps skip Map.build, so this also runs on the normal startup path.
function Harbour.ensureDocks(root: Instance)
	for _, base in root:GetDescendants() do
		if not base:IsA("Model") or not CollectionService:HasTag(base, Harbour.BASE_TAG) then
			continue
		end
		ensureDockSign(base)
		local frame = base:GetAttribute("BoatDockFrame")
		if typeof(frame) ~= "CFrame" then
			local spawn = base:FindFirstChild("SpawnPoint")
			if not spawn or not spawn:IsA("BasePart") then
				continue
			end
			frame = spawn.CFrame * CFrame.new(-4, -6.1, -26)
			base:SetAttribute("BoatDockFrame", frame)
		end
		ensureDockAccess(base, frame)
		if base:GetAttribute("DockDetailVersion") == DOCK_DETAIL_VERSION then
			continue
		end
		for _, item in base:GetChildren() do
			if item:IsA("Model") and (item.Name == "Dock" or item.Name == "DockLink") then
				item:Destroy()
			elseif item:IsA("BasePart") then
				-- The legacy crosswalk and its three anonymous piles are direct base children.
				local p = frame:PointToObjectSpace(item.Position)
				local slab = (item.Size - Vector3.new(27, 0.6, 5)).Magnitude < 0.01
					and (p - Vector3.new(0, 3, -38)).Magnitude < 0.01
				local pile = (item.Size - Vector3.new(0.9, 18, 0.9)).Magnitude < 0.01
					and math.abs(p.Y + 6.4) < 0.01
					and math.abs(p.Z + 38) < 0.01
					and (math.abs(p.X) < 0.01 or math.abs(math.abs(p.X) - 8) < 0.01)
				if slab or pile then
					item:Destroy()
				end
			end
		end
		buildBaseDocks(base, frame, base:GetAttribute("BaseId") or 1)
	end
end

-- Remove the red scenery boat and the remaining boat in front of base 1,
-- including on baked maps. Each removal has its own saved migration marker.
-- Run after generation so the shared RNG and all other scenery stay in place.
function Harbour.ensureBaseOneBoatClearance(root: Instance)
	local islands = root:GetDescendants()
	table.insert(islands, root)
	for _, island in islands do
		if island.Name ~= "Harbour Isle" then
			continue
		end
		local bases = island:FindFirstChild("Bases")
		local base = bases and bases:FindFirstChild("Base1")
		local frame = base and base:GetAttribute("BoatDockFrame")
		local boats = island:FindFirstChild("Boats")
		if typeof(frame) ~= "CFrame" or not boats then
			continue
		end
		for _, marker in { "BaseOneRedBoatRemoved", "BaseOneFrontBoatRemoved" } do
			if island:GetAttribute(marker) then
				continue
			end
			local nearest: Model? = nil
			local distance = 220
			for _, boat in boats:GetChildren() do
				if not boat:IsA("Model") or boat.Name ~= "Boat" then
					continue
				end
				local floor = boat:FindFirstChild("BoatFloor")
				local red = false
				for _, piece in boat:GetChildren() do
					if piece:IsA("BasePart") then
						red = red or piece.Color == BOATS[2]
						-- Legacy baked boats have an unnamed floor.
						if
							not floor
							and math.abs(piece.Size.Y - 0.4) < 0.001
							and piece.Size.X >= 4.6
							and piece.Size.X <= 5.6
						then
							floor = piece
						end
					end
				end
				if (marker == "BaseOneFrontBoatRemoved" or red) and floor and floor:IsA("BasePart") then
					local position = frame:PointToObjectSpace(floor.Position)
					local separation = Vector2.new(position.X, position.Z).Magnitude
					if position.Z < 0 and separation < distance then
						nearest, distance = boat, separation
					end
				end
			end
			if nearest then
				nearest:Destroy()
				island:SetAttribute(marker, true)
			end
		end
	end
end

-- Add the boat shop and launch points to a map already baked in Studio.
-- Move anchored scenery aside so the slipway and its water approach stay open.
function Harbour.ensureLaunchClearance(root: Instance)
	for _, shop in root:GetDescendants() do
		if not shop:IsA("Model") or shop.Name ~= "Drydock" then
			continue
		end
		local launch = shop:GetAttribute("LaunchWaterFrame")
		if typeof(launch) ~= "CFrame" then
			continue
		end
		for _, boat in root:GetDescendants() do
			if not boat:IsA("Model") or boat.Name ~= "Boat" then
				continue
			end
			local floor = boat:FindFirstChild("BoatFloor")
			if not floor then
				for _, piece in boat:GetChildren() do
					if piece:IsA("BasePart") then
						floor = piece
						break
					end
				end
			end
			if not floor or not floor:IsA("BasePart") then
				continue
			end
			local position = launch:PointToObjectSpace(floor.Position)
			if math.abs(position.X) < 45 and position.Z > -70 and position.Z < 55 then
				local side = if position.X < 0 then -1 else 1
				local offset = launch:VectorToWorldSpace(Vector3.new(side * 65 - position.X, 0, 0))
				for _, piece in boat:GetDescendants() do
					if piece:IsA("BasePart") then
						piece.CFrame += offset
					end
				end
			end
		end
	end
end

function Harbour.ensureBoating(root: Instance)
	for _, island in root:GetDescendants() do
		if island:IsA("Model") and island.Name == "Harbour Isle" then
			local groundMesh = island:FindFirstChild("Ground")
			local shop = island:FindFirstChild("Drydock", true)
			local footprint = shop and shop:FindFirstChild("ShopFootprint")
			if groundMesh and groundMesh:GetAttribute("DrydockChannelVersion") ~= 1 and footprint then
				local plaza = Vector2.new(footprint.Position.X, footprint.Position.Z - 82)
				local center = plaza - makeShape(Vector2.new(0, 0)).toWorld(PLAZA)
				groundMesh:Destroy()
				buildGround(makeShape(center), island, Random.new(0))
			end
		end
	end
	Harbour.ensureDocks(root)
	Harbour.ensureBaseOneBoatClearance(root)
	Drydock.ensure(root)
	Harbour.ensureLaunchClearance(root)
end

-- Saved maps also receive the enterable tackle shop, its purchase counter and the furniture shop.
function Harbour.ensureFishing(root: Instance)
	RodShop.ensure(root)
	FurnitureShop.ensure(root)
	BackpackShop.ensure(root)

	PlazaHouses.ensure(root)
end

-- Saved maps keep their terrain and docks while receiving the current base house.
function Harbour.ensureBases(root: Instance)
	for _, item in root:GetDescendants() do
		if item:IsA("Model") and CollectionService:HasTag(item, Harbour.BASE_TAG) then
			BaseHouse.ensure(item)
		end
	end
end

-- Saved beaches receive moving surf without rebuilding their terrain or decorations.
function Harbour.ensureSurf(root: Instance, center: Vector2)
	for _, island in root:GetDescendants() do
		if not island:IsA("Model") or island.Name ~= "Harbour Isle" then
			continue
		end
		local village = island:FindFirstChild("Village")
		local beach = village and village:FindFirstChild("Beach")
		if beach then
			local surf = beach:FindFirstChild("Surf")
			if not surf or surf:GetAttribute("ShoreWavesVersion") ~= 1 then
				buildSurf(makeShape(center), island, beach)
			end
		end
	end
end

-- Trim legacy paving in place, preserving every plaza prop and its placement.
function Harbour.ensurePlazaPaving(root: Instance)
	for _, plaza in root:GetDescendants() do
		if not plaza:IsA("Model") or plaza.Name ~= "Plaza" or plaza:GetAttribute("PlazaPavingVersion") == 2 then
			continue
		end
		local size = PLAZA_HALF * 2
		local floor: BasePart? = nil
		for _, child in plaza:GetChildren() do
			if child:IsA("Part") and (child.Size - Vector3.new(size, 0.6, size)).Magnitude < 0.001 then
				floor = child
				break
			end
		end
		if not floor then
			continue
		end
		local center = floor.Position
		local half = PLAZA_HALF - 2
		floor.Size = Vector3.new(half * 2, floor.Size.Y, half * 2)
		for _, child in plaza:GetChildren() do
			if not child:IsA("Part") or child.Material ~= M.Cobblestone or math.abs(child.Size.Y - 0.12) > 0.001 then
				continue
			end
			local p, s = child.Position, child.Size
			local minX, maxX = math.max(p.X - s.X / 2, center.X - half), math.min(p.X + s.X / 2, center.X + half)
			local minZ, maxZ = math.max(p.Z - s.Z / 2, center.Z - half), math.min(p.Z + s.Z / 2, center.Z + half)
			child.Size = Vector3.new(maxX - minX, s.Y, maxZ - minZ)
			child.CFrame = CFrame.new((minX + maxX) / 2, p.Y, (minZ + maxZ) / 2)
		end
		plaza:SetAttribute("PlazaPavingVersion", 2)
	end
end
return Harbour
