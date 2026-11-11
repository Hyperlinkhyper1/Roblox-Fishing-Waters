-- Company islands. Local -Z faces Gullhaven.
--
-- The sale board and the boat marker are permanent. The island's "Ground" and
-- "Dressing" swap together (Islands.dress): an unowned island is a small, sheer
-- mountain of faceted rock crowned with pines, with only a rock ledge and an old
-- jetty at its foot (mountainOf). While someone owns it, it becomes a sandy shore
-- and a cliff-sided terrace (shapeOf) dressed as a harbour village with a quay,
-- two piers, a walled cliff and stone stairs up to an empty fenced plot. The owner
-- furnishes that plot from build mode; FurnitureService builds it under "PlotFurniture".
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Layout = require(game:GetService("ReplicatedStorage").Shared.CompanyIslands)
local LowPoly = require(script.Parent.LowPoly)
local Props = require(script.Parent.Props)
local Lod = require(script.Parent.Lod)

local Islands = { VERSION = 6 }
local rgb, M = Color3.fromRGB, Enum.Material
local ROCK, SAND, GRASS = rgb(100, 107, 105), rgb(191, 177, 142), rgb(107, 123, 80)
local WOOD, TRIM, ROOF = rgb(133, 100, 72), rgb(66, 61, 51), rgb(69, 83, 87)
local STONE, PEBBLE, DIRT = rgb(146, 143, 132), rgb(176, 165, 140), rgb(118, 101, 80)
local LEAVES = { rgb(70, 98, 60), rgb(86, 114, 66), rgb(58, 86, 58), rgb(104, 126, 72) }
local PINES = { rgb(52, 73, 56), rgb(46, 66, 52), rgb(60, 82, 60) }
local ACCENTS = { rgb(116, 150, 147), rgb(170, 118, 95), rgb(178, 157, 107), rgb(125, 148, 115), rgb(136, 144, 169), rgb(179, 144, 120) }
local TERRACE, BEACH = 24.4, 4.4
local TAU = math.pi * 2
local v2 = Vector2.new
-- The terrace cliff runs straight along the square for FRONT_HALF studs either side,
-- with a cut (NOTCH wide, back to NOTCH_BACK) that the stair climbs through; the
-- beach ends in a straight quay front at QUAY_FRONT. Everything else about the
-- outlines differs per island (shapeOf).
local FRONT, NOTCH, NOTCH_BACK, FRONT_HALF, QUAY_FRONT = -26, 9.5, 2, 64, -97
-- The stair: 32 risers of 0.625 studs, starting this far out on the beach.
local STAIR_START, STAIR_RUN = -38, 1.25
-- Lod streams a model of up to PIECE_PARTS parts as one piece and splits bigger ones
-- into their children, so big models must not hold loose parts (they'd stream alone).
local PIECE_PARTS, CHUNK_PARTS = 200, 150

local function group(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name, model.Parent = name, parent
	return model
end

local function part(parent, name, size, frame, color, material, collide)
	local piece = Props.part(parent, size, frame, color, material)
	piece.Name = name
	if collide == false then
		piece.CanCollide, piece.CanTouch, piece.CanQuery = false, false, false
	end
	return piece
end

local function sign(parent, frame, name, value, width)
	local board = part(parent, name, Vector3.new(width or 16, 3, 0.35), frame, TRIM, M.WoodPlanks, false)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.SizingMode, gui.PixelsPerStud = face, Enum.SurfaceGuiSizingMode.PixelsPerStud, 35
		local label = Instance.new("TextLabel")
		label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		label.Font, label.TextScaled, label.TextColor3 = Enum.Font.Garamond, true, rgb(245, 234, 208)
		label.Text, label.Parent, gui.Parent = value, gui, board
	end
	return board
end

local function prompt(parent, name, action, object, ownerOnly)
	local result = Instance.new("ProximityPrompt")
	result.Name, result.ActionText, result.ObjectText = name, action, object
	result.MaxActivationDistance, result.HoldDuration, result.RequiresLineOfSight = 10, 0.3, false
	result.Parent = parent
	if ownerOnly then
		result:SetAttribute("OwnerUserId", 0)
		CollectionService:AddTag(result, "ShopOwnerPrompt")
	end
	return result
end

local function shade(color: Color3, rng: Random, amount: number): Color3
	local s = 1 + rng:NextNumber(-amount, amount)
	return Color3.new(math.min(color.R * s, 1), math.min(color.G * s, 1), math.min(color.B * s, 1))
end

local function signedArea(outline: { Vector2 }): number
	local sum = 0
	for index, a in outline do
		local b = outline[index % #outline + 1]
		sum += a.X * b.Y - b.X * a.Y
	end
	return sum / 2
end

-- Outward unit normal of each edge, outline[i] -> outline[i + 1].
local function normals(outline: { Vector2 }): { Vector2 }
	local sign = if signedArea(outline) > 0 then 1 else -1
	local result = {}
	for index, a in outline do
		local d = (outline[index % #outline + 1] - a).Unit
		result[index] = Vector2.new(d.Y, -d.X) * sign
	end
	return result
end

-- Ear clipping, so outlines can be concave (coves, the stair cut).
local function triangulate(outline: { Vector2 }): { { Vector2 } }
	local sign = if signedArea(outline) > 0 then 1 else -1
	local function turn(o, a, b)
		return ((a.X - o.X) * (b.Y - o.Y) - (a.Y - o.Y) * (b.X - o.X)) * sign
	end
	local left, result = {}, {}
	for index in outline do
		table.insert(left, index)
	end
	while #left > 3 do
		local clipped = false
		for i = 1, #left do
			local ia, ib, ic = left[(i - 2) % #left + 1], left[i], left[i % #left + 1]
			local a, b, c = outline[ia], outline[ib], outline[ic]
			local ear = turn(a, b, c) > 0
			for _, j in left do
				if ear and j ~= ia and j ~= ib and j ~= ic then
					local p = outline[j]
					ear = not (turn(a, b, p) >= 0 and turn(b, c, p) >= 0 and turn(c, a, p) >= 0)
				end
			end
			if ear then
				table.insert(result, { a, b, c })
				table.remove(left, i)
				clipped = true
				break
			end
		end
		if not clipped then
			break
		end
	end
	if #left == 3 then
		table.insert(result, { outline[left[1]], outline[left[2]], outline[left[3]] })
	end
	return result
end

-- A flat top over `outline` with rock sides falling `spread` studs outward to
-- `bottom`. No terrain edits that could flood nearby rooms.
local function plateau(parent, frame: CFrame, outline: { Vector2 }, top: number, bottom: number, spread: number, color, material)
	for _, tri in triangulate(outline) do
		local a = frame * Vector3.new(tri[1].X, top, tri[1].Y)
		local b = frame * Vector3.new(tri[2].X, top, tri[2].Y)
		local c = frame * Vector3.new(tri[3].X, top, tri[3].Y)
		LowPoly.triangle(a, b, c, (a + b + c) / 3 - frame.UpVector, color, parent, material)
	end
	local edges = normals(outline)
	-- Mitred corner offsets keep neighbouring sides joined.
	local corners = {}
	for index in outline do
		local n1, n2 = edges[(index - 2) % #outline + 1], edges[index]
		corners[index] = (n1 + n2) / math.max(1 + n1:Dot(n2), 0.5)
	end
	for index, p in outline do
		local nextIndex = index % #outline + 1
		local q = outline[nextIndex]
		local pc, qc = p + corners[index] * spread, q + corners[nextIndex] * spread
		local a, b = frame * Vector3.new(p.X, top, p.Y), frame * Vector3.new(q.X, top, q.Y)
		local c, d = frame * Vector3.new(pc.X, bottom, pc.Y), frame * Vector3.new(qc.X, bottom, qc.Y)
		local mid = (p + q) / 2 - edges[index] * 4
		local inside = frame * Vector3.new(mid.X, (top + bottom) / 2, mid.Y)
		LowPoly.triangle(a, c, d, inside, ROCK, parent, M.Slate)
		LowPoly.triangle(a, d, b, inside, ROCK, parent, M.Slate)
	end
end

local function insidePolygon(outline, x: number, z: number): boolean
	local result = false
	for index, a in outline do
		local b = outline[index % #outline + 1]
		if (a.Y > z) ~= (b.Y > z) and x < (b.X - a.X) * (z - a.Y) / (b.Y - a.Y) + a.X then
			result = not result
		end
	end
	return result
end

----------------------------------------------------------------------------------------------------
-- Landform. Each island grows from its own seed. Only what the docks, the square, the
-- stair and the plot stand on is fixed: the quay front, the cliff front behind the
-- square and the terrace round the plot. The rest of the coast (headlands, coves,
-- beach spits), the rocky knolls, the grassy hill and the sea stacks differ.

-- Outlines are drawn as radii around HUB, in SAMPLES steps.
local HUB, SAMPLES = v2(0, 26), 48
-- Terrace keep-outs for knolls and the hill: the stair cut and overlook, the plot
-- with its lamps and fence, and the village flag.
local KEEP_OUT = { { -68, -32, 68, 86 }, { 64, -16, 82, 4 } }
-- Island-local radius limit of the coast, inside Layout.FOOTPRINT with the piers.
local MAX_COAST = 172

-- Radius of a superellipse (a across, `down` toward -Z, `up` toward +Z) at `theta`.
local function superellipse(theta: number, a: number, down: number, up: number, n: number): number
	local s = math.sin(theta)
	return (math.abs(math.cos(theta) / a) ^ n + math.abs(s / (if s < 0 then down else up)) ^ n) ^ (-1 / n)
end

local function smoothstep(lo: number, hi: number, x: number): number
	local t = math.clamp((x - lo) / (hi - lo), 0, 1)
	return t * t * (3 - 2 * t)
end

-- A smooth periodic wobble: harmonics `from`..`to` with random phases.
local function wobble(rng: Random, amplitude: number, from: number, to: number): (number) -> number
	local terms = {}
	for k = from, to do
		table.insert(terms, { k, amplitude * rng:NextNumber(0.4, 1) / (k - from + 1), rng:NextNumber(0, TAU) })
	end
	return function(theta)
		local sum = 0
		for _, t in terms do
			sum += t[2] * math.cos(t[1] * theta + t[3])
		end
		return sum
	end
end

-- Bumps on random bearings round the back and sides: headlands or beach spits. Also
-- returns the bearing of the first one.
local function lobes(rng: Random, count: number, lo: number, hi: number, wide: number?): ((number) -> number, number?)
	local list = {}
	for _ = 1, count do
		table.insert(list, { rng:NextNumber(-0.3, math.pi + 0.3), rng:NextNumber(0.22, wide or 0.5), rng:NextNumber(lo, hi) })
	end
	return function(theta)
		local sum = 0
		for _, lobe in list do
			local d = (theta - lobe[1] + math.pi) % TAU - math.pi
			sum += lobe[3] * math.exp(-(d / lobe[2]) ^ 2)
		end
		return sum
	end, if list[1] then list[1][1] else nil
end

-- The part of a closed ring above `line` (in Y) as one open polyline, from where it
-- rises over the line to where it drops back. The ring starts below the line; any
-- dip back below between those crossings is lifted just over it.
local function above(ring: { Vector2 }, line: number): { Vector2 }
	local first, last
	for index, p in ring do
		if p.Y > line then
			first = first or index
			last = index
		end
	end
	local function cross(p: Vector2, q: Vector2): Vector2
		return v2(p.X + (q.X - p.X) * (line - p.Y) / (q.Y - p.Y), line)
	end
	local result = { cross(ring[first - 1], ring[first]) }
	for index = first, last do
		local p = ring[index]
		table.insert(result, if p.Y > line then p else v2(p.X, line + 1))
	end
	table.insert(result, cross(ring[last], ring[last % #ring + 1]))
	return result
end

local function bounds(outline: { Vector2 }): (number, number, number, number)
	local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
	for _, p in outline do
		x0, z0, x1, z1 = math.min(x0, p.X), math.min(z0, p.Y), math.max(x1, p.X), math.max(z1, p.Y)
	end
	return x0, z0, x1, z1
end

-- A grassy hill: rings of vertices rising to an off-centre crown, as triangles in
-- island-local space, with its base outline and the height of its surface.
local HILL_SIDES, HILL_RINGS = 14, { 1, 0.8, 0.58, 0.34 }
local function hillMesh(rng: Random, base: { Vector2 }, center: Vector2, radius: number)
	local height = radius * rng:NextNumber(0.6, 0.95)
	local crown = v2(rng:NextNumber(-0.22, 0.22), rng:NextNumber(-0.22, 0.22)) * radius
	local rings = {}
	for j, rho in HILL_RINGS do
		local t = 1 - rho
		local y = TERRACE - 0.6 + height * t * t * (3 - 2 * t)
		local ring = {}
		for i, p in base do
			local s = if j == 1 then 1 else rng:NextNumber(0.94, 1.06)
			local q = center + crown * t + (p - center) * rho * s
			ring[i] = Vector3.new(q.X, y + (if j == 1 then 0 else rng:NextNumber(-0.05, 0.05) * height), q.Y)
		end
		rings[j] = ring
	end
	local top = center + crown
	local apex = Vector3.new(top.X, TERRACE - 0.6 + height, top.Y)
	local tris = {}
	for j = 1, #rings do
		local ring, inner = rings[j], rings[j + 1]
		for i = 1, #base do
			local n = i % #base + 1
			if inner then
				table.insert(tris, { ring[i], ring[n], inner[n] })
				table.insert(tris, { ring[i], inner[n], inner[i] })
			else
				table.insert(tris, { ring[i], ring[n], apex })
			end
		end
	end
	local hill = { base = base, tris = tris, center = center, radius = radius, top = apex.Y }
	-- The mesh's own height at x, z (barycentric over its triangles); nil off it.
	function hill.heightAt(x: number, z: number): number?
		for _, tri in tris do
			local a, b, c = tri[1], tri[2], tri[3]
			local det = (b.Z - c.Z) * (a.X - c.X) + (c.X - b.X) * (a.Z - c.Z)
			if math.abs(det) > 1e-6 then
				local u = ((b.Z - c.Z) * (x - c.X) + (c.X - b.X) * (z - c.Z)) / det
				local w = ((c.Z - a.Z) * (x - c.X) + (a.X - c.X) * (z - c.Z)) / det
				if u >= -1e-6 and w >= -1e-6 and u + w <= 1 + 1e-6 then
					return a.Y * u + b.Y * w + c.Y * (1 - u - w)
				end
			end
		end
		return nil
	end
	return hill
end

local shapes = {}

-- The island's outlines (coast and terrace), knolls, hill and sea stacks. Pure and
-- cached per id, so the ground and both dressings always agree.
local function shapeOf(id: number)
	if shapes[id] then
		return shapes[id]
	end
	local rng = Random.new(7300 + id * 37)
	local size = rng:NextNumber(0, 14)
	local spread = wobble(rng, rng:NextNumber(6, 12), 2, 5)
	-- One broad headland on every island (where the hill goes), maybe a couple more.
	local head, headBearing = lobes(rng, 1, 34, 58, 0.7)
	local more = lobes(rng, rng:NextInteger(0, 2), 12, 36)
	local function heads(theta: number): number
		return head(theta) + more(theta)
	end
	local shore = wobble(rng, 9, 1, 4)
	-- Narrow sandy points, and a beach in front that is wider on one side than the other.
	local spits = lobes(rng, rng:NextInteger(1, 3), 18, 50, 0.3)
	local wideLeft, wideRight = rng:NextNumber(84, 112), rng:NextNumber(84, 112)
	local upperRing, coastRing = {}, {}
	for index = 0, SAMPLES - 1 do
		-- Clockwise from straight ahead (-Z): left flank, back, right flank.
		local theta = -math.pi / 2 - (index + rng:NextNumber(-0.3, 0.3)) * TAU / SAMPLES
		local dir = v2(math.cos(theta), math.sin(theta))
		-- Nothing grows along the front, so the square and the stair keep their ground.
		local open = smoothstep(-0.8, -0.35, dir.Y)
		local r = superellipse(theta, 80, 64, 62, 6) + 3
		r = math.min(r + open * (math.max(0, size + spread(theta) + heads(theta)) + rng:NextNumber(-1, 2.5)), 128)
		local beach = superellipse(theta, if dir.X < 0 then wideLeft else wideRight, 130, 70, 4) * (1 - smoothstep(-0.45, -0.15, dir.Y))
		local c = math.max(beach + rng:NextNumber(2, 4), r + 6 + open * math.max(0, 8 + shore(theta) + spits(theta)))
		table.insert(upperRing, HUB + dir * r)
		table.insert(coastRing, HUB + dir * math.min(c, MAX_COAST - HUB.Magnitude))
	end
	-- The terrace: the straight front with the stair cut, ragged everywhere else.
	local arc = above(upperRing, FRONT)
	local upper = { v2(-NOTCH, FRONT), v2(-FRONT_HALF, FRONT) }
	if arc[1].X < -FRONT_HALF - 1 then
		table.insert(upper, arc[1])
	end
	for index = 2, #arc - 1 do
		table.insert(upper, arc[index])
	end
	if arc[#arc].X > FRONT_HALF + 1 then
		table.insert(upper, arc[#arc])
	end
	for _, p in { v2(FRONT_HALF, FRONT), v2(NOTCH, FRONT), v2(NOTCH, NOTCH_BACK), v2(-NOTCH, NOTCH_BACK) } do
		table.insert(upper, p)
	end
	-- The coast closes along the straight quay front.
	local shape = { coast = above(coastRing, QUAY_FRONT), upper = upper, ridges = {}, stacks = {} }
	local x0, _, x1, z1 = bounds(upper)
	shape.box = { x0, FRONT, x1, z1 }

	-- A spot on the terrace at least `margin` from its edge and from the keep-outs.
	local function clear(p: Vector2, margin: number): boolean
		for _, d in { v2(0, 0), v2(margin, 0), v2(-margin, 0), v2(0, margin), v2(0, -margin) } do
			if not insidePolygon(upper, p.X + d.X, p.Y + d.Y) then
				return false
			end
		end
		for _, box in KEEP_OUT do
			if p.X > box[1] - margin and p.X < box[3] + margin and p.Y > box[2] - margin and p.Y < box[4] + margin then
				return false
			end
		end
		return true
	end
	local function covers(outline: { Vector2 }): boolean
		for _, box in KEEP_OUT do
			for _, f in { { 0, 0 }, { 0.5, 0 }, { 1, 0 }, { 0, 0.5 }, { 1, 0.5 }, { 0, 1 }, { 0.5, 1 }, { 1, 1 } } do
				if insidePolygon(outline, box[1] + (box[3] - box[1]) * f[1], box[2] + (box[4] - box[2]) * f[2]) then
					return true
				end
			end
		end
		return false
	end
	-- A ragged blob of `sides` points, or nil where it would not fit.
	local features = {}
	local function blob(center: Vector2, radius: number, sides: number, ragged: number, margin: number): { Vector2 }?
		for _, other in features do
			if (other.center - center).Magnitude < other.radius + radius * (1 + ragged) + 6 then
				return nil
			end
		end
		local stretch, turn = rng:NextNumber(0, 0.3), rng:NextNumber(0, TAU)
		local outline = {}
		for i = 1, sides do
			local theta = (i - 1) / sides * TAU
			local r = radius * (1 + stretch * math.cos(2 * (theta - turn))) * rng:NextNumber(1 - ragged, 1 + ragged)
			local p = center + v2(math.cos(theta), math.sin(theta)) * r
			if not clear(p, margin) then
				return nil
			end
			outline[i] = p
		end
		if covers(outline) then
			return nil
		end
		table.insert(features, { center = center, radius = radius * (1 + ragged) })
		return outline
	end
	local function spot(): Vector2
		return v2(rng:NextNumber(x0, x1), rng:NextNumber(FRONT, z1))
	end

	-- Most islands rise to a grassy hill wherever the outline left room for one.
	if rng:NextNumber() < 0.85 then
		for attempt = 1, 90 do
			local radius = rng:NextNumber(18, 34) * (1 - attempt / 160)
			-- First out on the big headland, against its cliffs; then anywhere.
			local center = spot()
			if attempt <= 50 then
				local best, gap = upperRing[1], math.huge
				for _, p in upperRing do
					local d = math.abs((math.atan2(p.Y - HUB.Y, p.X) - headBearing + math.pi) % TAU - math.pi)
					if d < gap then
						best, gap = p, d
					end
				end
				local out = best - HUB
				center = HUB + out.Unit * (out.Magnitude - radius * rng:NextNumber(1.1, 1.6) - 6) + v2(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8))
			end
			local base = blob(center, radius, HILL_SIDES, 0.06, 5)
			if base then
				shape.hill = hillMesh(rng, base, center, radius)
				break
			end
		end
	end
	-- Rocky knolls: flat-topped, cliff-sided outcrops above the terrace.
	local knolls = rng:NextInteger(if shape.hill then 1 else 2, if shape.hill then 3 else 4)
	for attempt = 1, 150 do
		if #shape.ridges >= knolls then
			break
		end
		local center = spot()
		-- Later tries shrink, so even a tight terrace gets an outcrop.
		local outline = blob(center, rng:NextNumber(9, 19) * (1 - attempt / 220), rng:NextInteger(7, 10), 0.18, 6)
		if outline then
			table.insert(shape.ridges, { top = TERRACE + rng:NextNumber(6, 13), outline = outline })
		end
	end
	-- Sea stacks off the back and flanks.
	for _ = 1, rng:NextInteger(1, 4) do
		local p = coastRing[rng:NextInteger(1, #coastRing)]
		local dir = (p - HUB).Unit
		local stack = p + dir * rng:NextNumber(14, 30)
		if dir.Y > -0.2 and not insidePolygon(shape.coast, stack.X, stack.Y) and stack.Magnitude < MAX_COAST + 25 then
			table.insert(shape.stacks, stack)
		end
	end
	shapes[id] = shape
	return shape
end
Islands.shapeOf = shapeOf

----------------------------------------------------------------------------------------------------
-- Wild land. A free island is a small mountain rising sheer out of the sea: one big
-- faceted rock, sometimes with a lesser summit or a shoulder beside it, pines on its
-- gentler faces and a few rock spires offshore. Nothing of the terrace or the beach
-- shows until someone buys it. Only a rock ledge at its foot (where the sale board
-- stands) and the water out along the old jetty are fixed.

-- The ledge (x0, z0, x1, z1) and the open water the jetty reaches out over.
local LEDGE = { -36, -96, -4, -70 }
local APPROACH = { -34, -260, -6, -96 }
local SPOKES, RINGS = 20, 7

local function boxDistance(box, p: Vector2): number
	local dx = math.max(box[1] - p.X, 0, p.X - box[3])
	local dz = math.max(box[2] - p.Y, 0, p.Y - box[4])
	return math.sqrt(dx * dx + dz * dz)
end

-- Height of a triangle mesh (island-local Vector3 corners) at x, z; nil off it.
local function meshHeight(tris, x: number, z: number): number?
	for _, tri in tris do
		local a, b, c = tri[1], tri[2], tri[3]
		local det = (b.Z - c.Z) * (a.X - c.X) + (c.X - b.X) * (a.Z - c.Z)
		if math.abs(det) > 1e-6 then
			local u = ((b.Z - c.Z) * (x - c.X) + (c.X - b.X) * (z - c.Z)) / det
			local w = ((c.Z - a.Z) * (x - c.X) + (a.X - c.X) * (z - c.Z)) / det
			if u >= -1e-6 and w >= -1e-6 and u + w <= 1 + 1e-6 then
				return a.Y * u + b.Y * w + c.Y * (1 - u - w)
			end
		end
	end
	return nil
end

local mountains = {}

-- The mountain's faceted surface (island-local triangles), its waterline and the
-- spires off its shore. Pure and cached per id, like shapeOf.
local function mountainOf(id: number)
	if mountains[id] then
		return mountains[id]
	end
	local rng = Random.new(9100 + id * 53)
	local function peak(center: Vector2, radius: number, height: number, shape: number)
		return {
			center = center,
			radius = radius,
			height = height,
			stretch = rng:NextNumber(0.8, 1.25),
			turn = rng:NextNumber(0, math.pi),
			-- Low exponents make peaks, high ones hulking domes with sheer sides.
			shape = shape,
			-- Leaning: a long slope one way and a sheer face the other.
			lean = rng:NextNumber(0, 0.5),
			leanTurn = rng:NextNumber(0, TAU),
			wobble = wobble(rng, 0.06, 2, 5),
		}
	end
	local cz = rng:NextNumber(12, 38)
	local main = peak(v2(rng:NextNumber(-22, 22), cz), math.min(rng:NextNumber(44, 80), (cz + 70) / 1.4), rng:NextNumber(46, 92), rng:NextNumber(1.8, 4.5))
	local peaks = { main }
	for _ = 1, rng:NextInteger(0, 2) do
		-- Lesser summits and shoulders beside and behind it, never out over the landing.
		local a = rng:NextNumber(-0.15, math.pi + 0.15)
		local center = main.center + v2(math.cos(a), math.sin(a)) * main.radius * rng:NextNumber(0.5, 0.9)
		local r = math.min(main.radius * rng:NextNumber(0.4, 0.68), (center.Y + 70) / 1.4, (MAX_COAST - 14 - center.Magnitude) / 1.6)
		if r > 16 then
			table.insert(peaks, peak(center, r, main.height * rng:NextNumber(0.35, 0.72), rng:NextNumber(1.6, 4)))
		end
	end
	local function rise(p: Vector2): number
		local best = -math.huge
		for _, k in peaks do
			local d = p - k.center
			local c, s = math.cos(k.turn), math.sin(k.turn)
			local x, z = (d.X * c + d.Y * s) / k.stretch, (d.Y * c - d.X * s) * k.stretch
			local theta = math.atan2(z, x)
			local t = math.sqrt(x * x + z * z) / k.radius * (1 + k.wobble(theta)) / (1 + k.lean * math.cos(theta - k.leanTurn))
			best = math.max(best, if t < 1 then k.height * (1 - t ^ k.shape) else -(t - 1) * k.radius * 1.6)
		end
		-- A cove for the ledge, open water out along the jetty, and nothing past the reservation.
		return math.min(best, BEACH - 1.5 + boxDistance(LEDGE, p) * 1.2, -10 + boxDistance(APPROACH, p) * 1.2, (MAX_COAST - p.Magnitude) * 1.5)
	end
	local reach = 0
	for _, k in peaks do
		reach = math.max(reach, (k.center - main.center).Magnitude + k.radius * 1.4 * (1 + k.lean))
	end
	-- Radial rings round an off-centre crown; alternate rings sit half a spoke out of
	-- phase, so the facets don't line up into spokes.
	local crown = main.center + v2(rng:NextNumber(-0.15, 0.15), rng:NextNumber(-0.15, 0.15)) * main.radius
	local apex = Vector3.new(crown.X, rise(crown), crown.Y)
	local rings = {}
	for i = 1, RINGS do
		local ring = {}
		for j = 1, SPOKES do
			local angle = (j - 1 + (i % 2) * 0.5 + rng:NextNumber(-0.18, 0.18)) / SPOKES * TAU
			local r = if i == RINGS then reach * 1.1 else reach * i / RINGS * rng:NextNumber(0.92, 1.08)
			local p = crown + v2(math.cos(angle), math.sin(angle)) * r
			local h = rise(p)
			if i == RINGS then
				h = math.min(h, -24)
			elseif h > BEACH + 3 and boxDistance(LEDGE, p) > 16 then
				-- Knock the faces about so the rock reads as split, angular slabs.
				h = math.max(h + rng:NextNumber(-0.07, 0.07) * main.height, BEACH + 3)
			end
			ring[j] = Vector3.new(p.X, h, p.Y)
		end
		rings[i] = ring
	end
	local tris = {}
	for j = 1, SPOKES do
		local n = j % SPOKES + 1
		table.insert(tris, { apex, rings[1][j], rings[1][n] })
		for i = 1, RINGS - 1 do
			local inner, outer = rings[i], rings[i + 1]
			if i % 2 == 0 then
				table.insert(tris, { inner[j], outer[j], inner[n] })
				table.insert(tris, { inner[n], outer[j], outer[n] })
			else
				table.insert(tris, { inner[j], outer[j], outer[n] })
				table.insert(tris, { inner[j], outer[n], inner[n] })
			end
		end
	end
	-- The waterline, walked in from open water along rays from the crown.
	local coast = {}
	for j = 1, 32 do
		local dir = v2(math.cos(j / 32 * TAU), math.sin(j / 32 * TAU))
		local r = reach * 1.05
		while r > 4 and (meshHeight(tris, crown.X + dir.X * r, crown.Y + dir.Y * r) or -1) < 0 do
			r -= 2
		end
		table.insert(coast, crown + dir * r)
	end
	-- Rock spires off the sides and back.
	local spires = {}
	for _ = 1, rng:NextInteger(1, 4) do
		local a = rng:NextNumber(-0.3, math.pi + 0.3)
		local p = crown + v2(math.cos(a), math.sin(a)) * reach * rng:NextNumber(1, 1.3)
		if p.Magnitude < MAX_COAST + 10 and boxDistance(APPROACH, p) > 30 and boxDistance(LEDGE, p) > 30 and not insidePolygon(coast, p.X, p.Y) then
			table.insert(spires, { position = p, radius = rng:NextNumber(4, 9), height = rng:NextNumber(6, 26) })
		end
	end
	local mountain = { tris = tris, coast = coast, spires = spires, height = main.height, apex = apex, peaks = #peaks }
	function mountain.heightAt(x: number, z: number): number?
		return meshHeight(tris, x, z)
	end
	mountains[id] = mountain
	return mountain
end
Islands.mountainOf = mountainOf

-- Height of the upper ground (the hill, a knoll or the terrace) at island-local x, z,
-- and which of them it is; nil off it.
local function groundLevel(shape, x: number, z: number): (number?, any)
	local hill = shape.hill
	if hill and insidePolygon(hill.base, x, z) then
		local y = hill.heightAt(x, z)
		if y then
			return y, hill
		end
	end
	for _, ridge in shape.ridges do
		if insidePolygon(ridge.outline, x, z) then
			return ridge.top, ridge
		end
	end
	if insidePolygon(shape.upper, x, z) then
		return TERRACE, shape.upper
	end
	return nil, nil
end

local function notchEdge(a: Vector2, b: Vector2): boolean
	return a.X == b.X and math.abs(a.X) == NOTCH
end

-- The stretch of cliff behind the square: bare rock or the village's harbour wall.
local function frontEdge(a: Vector2, b: Vector2): boolean
	return a.Y == FRONT and b.Y == FRONT and not notchEdge(a, b) and math.abs(a.X) <= FRONT_HALF and math.abs(b.X) <= FRONT_HALF
end

-- Island-local helpers shared by both dressings. `yaw` turns an island-local
-- heading (0 faces -Z, toward Gullhaven) into the world angle Props expects.
local function kit(frame: CFrame, parent: Model, rng: Random, shape)
	local self = { shape = shape }
	function self.at(x: number, y: number, z: number): Vector3
		return frame * Vector3.new(x, y, z)
	end
	function self.cf(x: number, y: number, z: number, turn: number?): CFrame
		return frame * CFrame.new(x, y, z) * CFrame.Angles(0, turn or 0, 0)
	end
	function self.yaw(turn: number): number
		local look = frame * Vector3.new(-math.sin(turn), 0, -math.cos(turn)) - frame.Position
		return math.atan2(-look.X, -look.Z)
	end
	-- A random spot on the terrace, a knoll or the hill, at least `margin` from any
	-- edge between them and outside the `avoid` boxes, with the ground height there.
	-- `flat` keeps to the terrace itself.
	function self.terraceSpot(margin: number, avoid: { { number } }, flat: boolean?): (number?, number?, number?)
		local box = shape.box
		for _ = 1, 40 do
			local x, z = rng:NextNumber(box[1], box[3]), rng:NextNumber(box[2], box[4])
			local level, surface = groundLevel(shape, x, z)
			if flat and surface ~= shape.upper then
				level = nil
			end
			for _, offset in { { margin, 0 }, { -margin, 0 }, { 0, margin }, { 0, -margin } } do
				local _, other = groundLevel(shape, x + offset[1], z + offset[2])
				if other ~= surface then
					level = nil
				end
			end
			for _, box in avoid do
				if x > box[1] and x < box[3] and z > box[2] and z < box[4] then
					level = nil
				end
			end
			if level then
				return x, z, level
			end
		end
		return nil, nil, nil
	end
	self.rng, self.parent = rng, parent
	return self
end

-- Wraps the loose parts of every model too big for one piece into chunk models.
local function pack(model: Instance)
	local count = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	if count <= PIECE_PARTS then
		return
	end
	local loose = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(loose, child)
		elseif child:IsA("Model") then
			pack(child)
		end
	end
	local chunk
	for index, piece in loose do
		if (index - 1) % CHUNK_PARTS == 0 then
			chunk = group(model, model.Name .. "Chunk")
		end
		piece.Parent = chunk
	end
end

-- Stacked, slightly tumbled rock blocks facing one cliff edge (island-local a -> b,
-- `normal` pointing out of the cliff) from `bottom` up to a ragged lip at `top`.
-- Lower courses stand further out, so the face leans back like weathered rock.
local function cliffFace(parent: Instance, k, a: Vector2, b: Vector2, normal: Vector2, top: number, bottom: number, out: number)
	local rng = k.rng
	local length = (b - a).Magnitude
	local along = (b - a) / length
	local y = bottom
	while y < top - 0.01 do
		local h = math.min(rng:NextNumber(5, 8.5), top - y)
		if top - y - h < 3 then
			h = top - y
		end
		local lip = y + h >= top - 0.01
		local lean = (top - y - h) / math.max(top - bottom, 1) * out
		local s = -1 - rng:NextNumber(0, 3)
		while s < length + 1 do
			local e = math.min(s + rng:NextNumber(6, 12), length + 1)
			local s0 = math.max(s, -1)
			if e - s0 > 1 then
				local depth = rng:NextNumber(5, 8)
				local height = h + (if lip then rng:NextNumber(-0.5, 0.6) else rng:NextNumber(0.3, 1.2))
				local mid = a + along * ((s0 + e) / 2) + normal * (rng:NextNumber(0.3, out) + lean - depth / 2)
				local center = k.at(mid.X, y + height / 2, mid.Y)
				local facing = k.at(mid.X + normal.X, y + height / 2, mid.Y + normal.Y)
				local tumble = CFrame.Angles(rng:NextNumber(-0.05, 0.05), rng:NextNumber(-0.08, 0.08), rng:NextNumber(-0.05, 0.05))
				local block = part(parent, "CliffBlock", Vector3.new(e - s0 + 0.6, height, depth), CFrame.lookAt(center, facing) * tumble, shade(ROCK, rng, 0.1), M.Slate)
				if lip and rng:NextNumber() < 0.4 then
					part(parent, "CliffMoss", Vector3.new((e - s0) * 0.8, 0.3, depth * 0.7), block.CFrame * CFrame.new(0, height / 2 + 0.1, 0), shade(GRASS, rng, 0.1), M.Grass, false)
				end
			end
			s = e
		end
		y += h
	end
end

-- A tumbled rock: one tilted slab, sometimes with smaller ones leaning on it.
local function stone(parent: Instance, k, x: number, y: number, z: number, size: number): Model
	local rng = k.rng
	local rock = group(parent, "Stone")
	for index = 1, rng:NextInteger(1, 3) do
		local s = if index == 1 then size else size * rng:NextNumber(0.4, 0.7)
		local ox, oz = 0, 0
		if index > 1 then
			ox, oz = rng:NextNumber(-0.6, 0.6) * size, rng:NextNumber(-0.6, 0.6) * size
		end
		local tilt = CFrame.Angles(rng:NextNumber(-0.35, 0.35), 0, rng:NextNumber(-0.35, 0.35))
		part(rock, "StoneBlock", Vector3.new(s, s * rng:NextNumber(0.5, 0.8), s * rng:NextNumber(0.65, 1)), k.cf(x + ox, y + s * 0.15, z + oz, rng:NextNumber(0, math.pi * 2)) * tilt, shade(ROCK, rng, 0.12), M.Slate)
	end
	return rock
end

-- Rocks along the waterline at uneven gaps, in loose clusters, some on the sand
-- and some standing well out in the water. `skip(x, z)` keeps a stretch clear.
local function shoreRocks(k, skip: (number, number) -> boolean)
	local rng = k.rng
	local rocks = group(k.parent, "ShoreRocks")
	local COAST, UPPER = k.shape.coast, k.shape.upper
	local edges = normals(COAST)
	local gap = rng:NextNumber(0, 10)
	for index, a in COAST do
		local b = COAST[index % #COAST + 1]
		local length = (b - a).Magnitude
		local t = gap
		while t < length do
			local out = if rng:NextNumber() < 0.25 then rng:NextNumber(8, 26) else rng:NextNumber(-3, 5)
			local point = a + (b - a) * (t / length) + edges[index] * out
			if not skip(point.X, point.Y) and not insidePolygon(UPPER, point.X, point.Y) then
				local y = if out < 0 then BEACH - 0.6 else rng:NextNumber(-1.2, 1.4)
				stone(rocks, k, point.X, y, point.Y, rng:NextNumber(2.5, if out > 8 then 8 else 6))
			end
			-- Either another rock close by or a long empty stretch.
			t += if rng:NextNumber() < 0.4 then rng:NextNumber(2, 5) else rng:NextNumber(8, 30)
		end
		gap = t - length
	end
	return rocks
end

-- Rocks fallen at the foot of the terrace cliff, onto the beach only.
local function cliffRocks(k, skip: (number, number) -> boolean)
	local rng = k.rng
	local rocks = group(k.parent, "CliffRocks")
	local COAST, UPPER = k.shape.coast, k.shape.upper
	local edges = normals(UPPER)
	for index, a in UPPER do
		local b = UPPER[index % #UPPER + 1]
		local length = (b - a).Magnitude
		local t = rng:NextNumber(0, 12)
		while t < length do
			local point = a + (b - a) * (t / length) + edges[index] * rng:NextNumber(3, 8)
			if insidePolygon(COAST, point.X, point.Y) and not insidePolygon(UPPER, point.X, point.Y) and not skip(point.X, point.Y) then
				stone(rocks, k, point.X, BEACH - 0.5, point.Y, rng:NextNumber(2, 5.5))
			end
			t += rng:NextNumber(6, 28)
		end
	end
	return rocks
end

-- Trees, bushes and mounds scattered over the upper terrace.
local function woodland(k, trees: number, bushes: number, avoid: { { number } })
	local rng = k.rng
	local wood = group(k.parent, "Woodland")
	-- Bigger terraces carry more trees.
	local scale = math.clamp(math.abs(signedArea(k.shape.upper)) / 21000, 0.8, 1.7)
	trees, bushes = math.round(trees * scale), math.round(bushes * scale)
	for index = 1, trees do
		local x, z, y = k.terraceSpot(7, avoid)
		if x then
			if index % 3 == 0 then
				Props.broadleaf(wood, k.at(x, y, z), rng, LEAVES)
			else
				Props.pine(wood, k.at(x, y, z), rng, Props.pick(rng, PINES))
			end
		end
	end
	for index = 1, bushes do
		local x, z, y = k.terraceSpot(3, avoid)
		if x then
			if index % 4 == 0 then
				Props.flowers(wood, k.at(x, y, z), rng)
			elseif index % 5 == 0 then
				stone(wood, k, x, y - 0.5, z, rng:NextNumber(1.8, 3.5))
			else
				Props.bush(wood, k.at(x, y, z), rng, LEAVES)
			end
		end
	end
	return wood
end

-- One wooden plank deck with gaps: `along` X or Z, top at `top`.
local function planks(parent: Instance, k, x1: number, z1: number, x2: number, z2: number, top: number, alongX: boolean, name: string)
	local rng = k.rng
	local span = if alongX then z2 - z1 else x2 - x1
	local count = math.max(1, math.floor(span / 1.6 + 0.5))
	local width = span / count
	for index = 0, count - 1 do
		local c = (if alongX then z1 else x1) + (index + 0.5) * width
		local size = if alongX then Vector3.new(x2 - x1, 0.5, width - 0.12) else Vector3.new(width - 0.12, 0.5, z2 - z1)
		local center = if alongX then Vector3.new((x1 + x2) / 2, top - 0.25, c) else Vector3.new(c, top - 0.25, (z1 + z2) / 2)
		part(parent, name, size, k.cf(center.X, center.Y, center.Z), shade(WOOD, rng, 0.1), M.WoodPlanks)
	end
end

local function pile(parent: Instance, k, x: number, z: number, top: number)
	local piece = Props.cylinder(parent, k.at(x, (top - 9) / 2, z), top + 9, 1.1, shade(TRIM, k.rng, 0.12), M.Wood)
	piece.Name = "PierPile"
	return piece
end

-- A wooden post with a crossarm and a lantern hanging off it.
local function lanternPost(parent: Instance, k, x: number, z: number, y: number, turn: number)
	local post = group(parent, "LanternPost")
	part(post, "Post", Vector3.new(0.7, 9, 0.7), k.cf(x, y + 4.5, z, turn), TRIM, M.Wood)
	part(post, "Arm", Vector3.new(0.4, 0.4, 2.8), k.cf(x, y + 8.6, z, turn) * CFrame.new(0, 0, -1.1), TRIM, M.Wood)
	part(post, "Brace", Vector3.new(0.3, 0.3, 1.8), k.cf(x, y + 7.8, z, turn) * CFrame.new(0, 0, -0.6) * CFrame.Angles(math.rad(40), 0, 0), TRIM, M.Wood, false)
	Props.lantern(post, k.cf(x, y + 7.3, z, turn) * CFrame.new(0, 0, -2.2), 18, 1.1)
	return post
end

local function bollard(parent: Instance, k, x: number, z: number, y: number)
	local piece = Props.cylinder(parent, k.at(x, y + 0.6, z), 1.2, 1, rgb(44, 46, 48), M.Metal)
	piece.Name = "Bollard"
	local cap = Props.cylinder(parent, k.at(x, y + 1.25, z), 0.25, 1.4, rgb(44, 46, 48), M.Metal)
	cap.Name, cap.CanCollide = "BollardCap", false
end

-- Top of the stair's walking surface at island-local z.
local function stairHeight(z: number): number
	return BEACH + math.clamp(math.ceil((z - STAIR_START) / STAIR_RUN), 0, 32) * 0.625
end

-- A random spot on open sand behind `zMin`, clear of the cliffs and the water's edge.
local function sandSpot(k, zMin: number): (number?, number?)
	local coast, upper = k.shape.coast, k.shape.upper
	local x0, _, x1, z1 = bounds(coast)
	for _ = 1, 30 do
		local x, z = k.rng:NextNumber(x0, x1), k.rng:NextNumber(zMin, z1)
		-- Not on the stair's foot.
		local ok = not (math.abs(x) < 22 and z < FRONT)
		for _, d in { { 0, 0 }, { 4, 0 }, { -4, 0 }, { 0, 4 }, { 0, -4 } } do
			if not insidePolygon(coast, x + d[1], z + d[2]) or insidePolygon(upper, x + d[1], z + d[2]) then
				ok = false
			end
		end
		if ok then
			return x, z
		end
	end
	return nil, nil
end

-- Keeps the docks, the stair's foot and the boat approach free of rocks.
local function clearOfLanding(x: number, z: number): boolean
	return (z < -78 and math.abs(x) < 75) or (math.abs(x) < 20 and z < FRONT and z > STAIR_START - 10)
end

local ROCKFACE, WETROCK, MOSS, LEDGE_TOP = rgb(116, 121, 121), rgb(72, 78, 79), rgb(66, 84, 60), rgb(112, 114, 108)

-- A slim spire of faceted rock standing in the sea.
local function spire(parent: Instance, k, p: Vector2, radius: number, height: number)
	local rng = k.rng
	local sides, turn = rng:NextInteger(5, 7), rng:NextNumber(0, TAU)
	local rings = {}
	for index, level in { { -8, radius }, { height * rng:NextNumber(0.45, 0.65), radius * rng:NextNumber(0.5, 0.7) } } do
		local ring = {}
		for i = 1, sides do
			local a = turn + (i + rng:NextNumber(-0.2, 0.2)) / sides * TAU
			local r = level[2] * rng:NextNumber(0.8, 1.15)
			ring[i] = k.at(p.X + math.cos(a) * r, level[1], p.Y + math.sin(a) * r)
		end
		rings[index] = ring
	end
	local top = k.at(p.X + rng:NextNumber(-0.3, 0.3) * radius, height, p.Y + rng:NextNumber(-0.3, 0.3) * radius)
	local core = k.at(p.X, height * 0.3, p.Y)
	for i = 1, sides do
		local n = i % sides + 1
		local color = shade(ROCKFACE, rng, 0.12)
		LowPoly.triangle(rings[1][i], rings[1][n], rings[2][n], core, color, parent, M.Slate)
		LowPoly.triangle(rings[1][i], rings[2][n], rings[2][i], core, color, parent, M.Slate)
		LowPoly.triangle(rings[2][i], rings[2][n], top, core, shade(ROCKFACE, rng, 0.12), parent, M.Slate)
	end
end

-- The wild landform: the mountain, the ledge at its foot and the spires offshore.
local function buildMountain(ground: Model, frame: CFrame, id: number)
	local rng = Random.new(4900 + id)
	local mountain = mountainOf(id)
	local k = kit(frame, ground, rng, shapeOf(id))
	for _, tri in mountain.tris do
		local a, b, c = tri[1], tri[2], tri[3]
		-- Faces deep under water would never be seen.
		if math.max(a.Y, b.Y, c.Y) > -14 then
			local normal = (b - a):Cross(c - a).Unit
			if normal.Y < 0 then
				normal = -normal
			end
			local y = (a.Y + b.Y + c.Y) / 3
			local color, material = shade(ROCKFACE, rng, 0.14), M.Slate
			if y < 2.5 then
				color = shade(WETROCK, rng, 0.08)
			elseif normal.Y > 0.82 and y > 10 then
				-- Only the flattest high faces hold enough soil for moss.
				color, material = shade(MOSS, rng, 0.1), M.Grass
			end
			LowPoly.triangle(frame * a, frame * b, frame * c, frame * ((a + b + c) / 3 - normal * 4), color, ground, material)
		end
	end
	local ledge = {}
	for _, p in { { -38, -98 }, { -21, -100 }, { -3, -97 }, { -1, -83 }, { -3, -68 }, { -20, -63 }, { -37, -67 }, { -40, -83 } } do
		table.insert(ledge, v2(p[1] + rng:NextNumber(-1.5, 1.5), p[2] + rng:NextNumber(-1.5, 1.5)))
	end
	plateau(ground, frame, ledge, BEACH, -10, 3, shade(LEDGE_TOP, rng, 0.04), M.Slate)
	for _, s in mountain.spires do
		spire(ground, k, s.position, s.radius, s.height)
	end
end

local function buildWild(island: Model, frame: CFrame, id: number): Model
	local dressing = Instance.new("Model")
	dressing.Name = "Dressing"
	dressing:SetAttribute("Kind", "Wild")
	local rng = Random.new(5100 + id)
	local mountain = mountainOf(id)
	local k = kit(frame, dressing, rng, shapeOf(id))
	-- Pines on the gentler faces, thickest round the summit.
	local slopes, total, area = {}, 0, 0
	for _, tri in mountain.tris do
		local a, b, c = tri[1], tri[2], tri[3]
		local cross = (b - a):Cross(c - a)
		if math.abs(cross.Unit.Y) > 0.6 and math.min(a.Y, b.Y, c.Y) > 8 then
			local height = (a.Y + b.Y + c.Y) / 3 / mountain.height
			local weight = cross.Magnitude / 2 * (0.3 + 1.7 * height * height)
			total += weight
			area += cross.Magnitude / 2
			table.insert(slopes, { tri = tri, weight = weight })
		end
	end
	local wood = group(dressing, "Woodland")
	local planted = {}
	local trees = math.clamp(math.round(area / 300), 5, 34)
	for _ = 1, trees * 4 do
		if #planted >= trees or total <= 0 then
			break
		end
		local roll, slope = rng:NextNumber(0, total), slopes[#slopes]
		for _, candidate in slopes do
			roll -= candidate.weight
			if roll <= 0 then
				slope = candidate
				break
			end
		end
		local a, b, c = slope.tri[1], slope.tri[2], slope.tri[3]
		local u, w = rng:NextNumber(), rng:NextNumber()
		if u + w > 1 then
			u, w = 1 - u, 1 - w
		end
		local p = a + (b - a) * u + (c - a) * w
		local crowded = false
		for _, other in planted do
			if (Vector2.new(other.X, other.Z) - Vector2.new(p.X, p.Z)).Magnitude < 6 then
				crowded = true
				break
			end
		end
		if not crowded then
			table.insert(planted, p)
			if #planted % 6 == 0 then
				Props.broadleaf(wood, k.at(p.X, p.Y - 0.4, p.Z), rng, LEAVES)
			else
				Props.pine(wood, k.at(p.X, p.Y - 0.4, p.Z), rng, Props.pick(rng, PINES))
			end
		end
	end
	-- Scrub on a few of the faces lower down.
	for _ = 1, math.min(#slopes, 8) do
		local tri = slopes[rng:NextInteger(1, #slopes)].tri
		local p = (tri[1] + tri[2] + tri[3]) / 3
		Props.bush(wood, k.at(p.X, p.Y - 0.3, p.Z), rng, LEAVES)
	end
	-- Fallen rock round the waterline, some of it standing out in the water.
	local rocks = group(dressing, "ShoreRocks")
	local crown = v2(mountain.apex.X, mountain.apex.Z)
	for index, a in mountain.coast do
		local b = mountain.coast[index % #mountain.coast + 1]
		for _ = 1, rng:NextInteger(0, 2) do
			local p = a:Lerp(b, rng:NextNumber())
			local out = if rng:NextNumber() < 0.3 then rng:NextNumber(5, 16) else rng:NextNumber(-2, 4)
			p += (p - crown).Unit * out
			if boxDistance(LEDGE, p) > 6 and boxDistance(APPROACH, p) > 10 then
				if out > 5 and rng:NextNumber() < 0.5 then
					LowPoly.boulder(k.at(p.X, rng:NextNumber(-2, -0.5), p.Y), rng:NextNumber(3, 6.5), rng, shade(ROCKFACE, rng, 0.1), rocks, M.Slate)
				else
					stone(rocks, k, p.X, rng:NextNumber(-1.4, 0.8), p.Y, rng:NextNumber(2.5, 6))
				end
			end
		end
	end
	-- The ledge the sale board stands on, and one old jetty out from it.
	local ledge = group(dressing, "Ledge")
	for _, spot in { { -34, -72 }, { -7, -71 }, { -37, -91 } } do
		stone(ledge, k, spot[1] + rng:NextNumber(-1.5, 1.5), BEACH - 0.4, spot[2] + rng:NextNumber(-1.5, 1.5), rng:NextNumber(1.8, 3.4))
	end
	Props.driftwood(ledge, k.at(-9, BEACH, -92), rng)
	local jetty = group(dressing, "Jetty")
	-- A plank's thickness above the ledge, so the two never fight over one surface.
	local deck = BEACH + 0.3
	planks(jetty, k, -22.5, -128, -17.5, -94, deck, true, "JettyPlank")
	for z = -128, -98, 6 do
		for _, x in { -22.6, -17.4 } do
			pile(jetty, k, x, z, deck - 0.2)
		end
	end
	bollard(jetty, k, -20, -126.5, deck)
	Props.ropeCoil(jetty, k.at(-21.5, deck, -122))
	lanternPost(jetty, k, -17.8, -127.4, deck, math.pi / 2)
	return dressing
end

-- Big stacked stone blocks facing the cliff behind the square, like an old harbour wall.
local function harbourWall(k)
	local rng = k.rng
	local wall = group(k.parent, "HarbourWall")
	local courses = { { BEACH, 9.4 }, { 9.4, 15.4 }, { 15.4, TERRACE } }
	local far = 64
	for side = -1, 1, 2 do
		-- Each course is laid on its own, so the joints stagger like brickwork.
		for course, span in courses do
			local left = NOTCH - (if course == 2 then rng:NextNumber(0, 2.5) else 0)
			while left < far - 0.2 do
				local right = math.min(left + rng:NextNumber(4.5, 7.5), far)
				local height = span[2] - span[1]
				part(wall, "WallStone", Vector3.new(right - math.max(left, NOTCH) - 0.2, height - 0.2, 4.6 + rng:NextNumber(-0.3, 0.4)), k.cf(side * (math.max(left, NOTCH) + right) / 2, span[1] + height / 2, FRONT - 2.3 + rng:NextNumber(-0.2, 0.2)), shade(STONE, rng, 0.09), M.Slate)
				left = right
			end
		end
		-- Cap stones finish the top of the wall flush with the terrace.
		for capX = NOTCH + 0.5, far - 4, 4 do
			part(wall, "CapStone", Vector3.new(3.9, 0.7, 5.2), k.cf(side * (capX + 2), TERRACE + 0.15, FRONT - 2.1), shade(rgb(158, 154, 142), rng, 0.05), M.Slate)
		end
		-- Moss trailing over the lip.
		for index = 1, 8 do
			local vx = side * rng:NextNumber(NOTCH + 3, far - 3)
			local length = rng:NextNumber(3, 9)
			part(wall, "Vine", Vector3.new(rng:NextNumber(0.8, 2), length, 0.25), k.cf(vx, TERRACE - length / 2, FRONT - 4.75), shade(rgb(74, 104, 60), rng, 0.1), M.LeafyGrass, false)
			if index % 3 == 0 then
				Props.bush(wall, k.at(vx, TERRACE, FRONT + 3), rng, LEAVES)
			end
		end
	end
	return wall
end

local function stairs(k)
	local rng = k.rng
	local steps = group(k.parent, "TerraceStairs")
	-- A wide stone stair climbs exactly twenty studs through the cut, without a jump.
	for step = 1, 32 do
		local height = step * 0.625
		part(steps, "StairTread", Vector3.new(15, height, STAIR_RUN + 0.05), k.cf(0, BEACH + height / 2, STAIR_START + (step - 0.5) * STAIR_RUN), shade(rgb(156, 154, 137), rng, 0.04), M.Cobblestone)
		-- A worn darker nosing on every step.
		part(steps, "StairNosing", Vector3.new(15, 0.12, 0.35), k.cf(0, BEACH + height + 0.06, STAIR_START + (step - 1) * STAIR_RUN + 0.2), shade(rgb(120, 118, 106), rng, 0.04), M.Slate, false)
	end
	for _, x in { -1, 1 } do
		-- Lantern newels at the foot and head, and lamps set into the walls of the cut.
		for _, spot in { { 8.6, STAIR_START - 1.6, BEACH }, { NOTCH + 1.4, NOTCH_BACK + 1.6, TERRACE } } do
			part(steps, "Newel", Vector3.new(2.2, 4, 2.2), k.cf(x * spot[1], spot[3] + 2, spot[2]), shade(STONE, rng, 0.04), M.Slate)
			Props.lantern(steps, k.cf(x * spot[1], spot[3] + 4.9, spot[2]), 18, 1.1)
		end
		for _, z in { -18, -6 } do
			Props.lantern(steps, k.cf(x * 8.2, stairHeight(z) + 5, z), 16, 0.9)
		end
	end
	return steps
end

-- Low irregular stepping stones, laid along a polyline.
local function path(parent: Instance, k, points: { Vector2 }, y: number, width: number, color: Color3)
	local rng = k.rng
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local length = (b - a).Magnitude
		for step = 0, math.floor(length / 2.6) do
			local p = a:Lerp(b, step * 2.6 / length)
			local side = Vector2.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * width * 0.25
			local stone = Props.cylinder(parent, k.at(p.X + side.X, y + 0.06, p.Y + side.Y), 0.12, rng:NextNumber(width * 0.5, width * 0.8), shade(color, rng, 0.08), M.Pebble)
			stone.Name, stone.CanCollide, stone.CanQuery = "PathStone", false, false
		end
	end
end

local function buildVillage(island: Model, frame: CFrame, id: number, pause: () -> ()): Model
	local dressing = Instance.new("Model")
	dressing.Name = "Dressing"
	dressing:SetAttribute("Kind", "Village")
	local rng = Random.new(6100 + id)
	local k = kit(frame, dressing, rng, shapeOf(id))
	local accent = ACCENTS[(id - 1) % #ACCENTS + 1]
	shoreRocks(k, clearOfLanding)
	cliffRocks(k, function(x, z) return clearOfLanding(x, z) or z < FRONT - 1 and math.abs(x) < 70 end)
	harbourWall(k)
	stairs(k)
	pause()

	-- Quay, piers and the boat terminal.
	local docks = group(dressing, "Docks")
	planks(docks, k, -52.5, -94, 52.5, -70, BEACH, true, "QuayPlank")
	part(docks, "QuayFascia", Vector3.new(106, 1.4, 0.8), k.cf(0, BEACH - 0.9, -94.3), TRIM, M.Wood)
	for x = -49, 49, 7 do
		pile(docks, k, x, -94.6, BEACH - 0.5)
		if x % 14 == 0 then
			local fender = Props.cylinder(docks, k.at(x + 3.5, BEACH - 1.6, -95.2), 1.1, 1.6, rgb(28, 28, 30), M.Rubber)
			fender.Name = "Fender"
		end
	end
	for _, x in { -47, -12, 12, 47 } do
		bollard(docks, k, x, -92.6, BEACH)
	end
	for _, x in { -30, 30 } do
		local pier = group(docks, if x < 0 then "LeftPier" else "RightPier")
		for z = -158, -98, 4 do
			part(pier, "PierPlank", Vector3.new(12, 0.6, 3.9), k.cf(x, 4.1, z), shade(WOOD, rng, 0.1), M.WoodPlanks)
		end
		part(pier, "PierHead", Vector3.new(21, 0.6, 10), k.cf(x, 4.1, -165), shade(WOOD, rng, 0.06), M.WoodPlanks)
		for z = -160, -88, 18 do
			for _, side in { -6, 6 } do
				part(pier, "PierPile", Vector3.new(0.9, 17, 0.9), k.cf(x + side, -1.5, z), TRIM, M.Wood)
			end
		end
		-- Rope rail along the outer edge, lanterns on every other post.
		local outer = if x < 0 then -6.4 else 6.4
		local previous
		for index, z in { -98, -110, -122, -134, -146, -158 } do
			part(pier, "RailPost", Vector3.new(0.6, 3.4, 0.6), k.cf(x + outer, BEACH + 1.7, z), TRIM, M.Wood)
			local top = k.at(x + outer, BEACH + 3, z)
			if previous then
				local sag = (previous + top) / 2 - Vector3.new(0, 0.6, 0)
				for _, ends in { { previous, sag }, { sag, top } } do
					local rope = part(pier, "RailRope", Vector3.new(0.2, 0.2, (ends[2] - ends[1]).Magnitude), CFrame.lookAt((ends[1] + ends[2]) / 2, ends[2]), rgb(176, 150, 106), M.Fabric, false)
					rope.CanQuery = false
				end
			end
			previous = top
			if index % 2 == 1 then
				Props.lantern(pier, k.cf(x + outer, BEACH + 4.1, z), 16, 0.9)
			end
		end
		Props.ladder(pier, k.cf(x + (if x < 0 then 4 else -4), BEACH, -170.2), -2)
		Props.lifeRing(pier, k.cf(x + outer * 1.06, BEACH + 2, -116, (if x < 0 then -1 else 1) * math.pi / 2))
		for _, hx in { -8, 8 } do
			bollard(pier, k, x + hx, -168.5, BEACH)
		end
		Props.crabPot(pier, k.at(x - 6, BEACH, -162), rng)
		Props.ropeCoil(pier, k.at(x + 6.5, BEACH, -161.5))
		Props.barrel(pier, k.at(x + (if x < 0 then -4 else 4), BEACH, -100.5), rng)
	end
	local terminal = sign(docks, k.cf(20, 7.2, -85), "BoatDockControl", "YOUR BOATS", 10)
	for _, tx in { -4.2, 4.2 } do
		part(docks, "TerminalPost", Vector3.new(0.5, 4.6, 0.5), k.cf(20 + tx, BEACH + 2.3, -85), TRIM, M.Wood)
	end
	prompt(terminal, "SpawnRowboatPrompt", "Choose boat", "Company dock", true)
	for _, spot in { { -40, -76 }, { 40, -76 }, { -49, -88 }, { 49, -73 } } do
		Props.crates(docks, k.at(spot[1], BEACH, spot[2]), rng)
	end
	for _, spot in { { -44, -73 }, { 36, -90 }, { 46, -89 }, { -6, -91 } } do
		Props.barrel(docks, k.at(spot[1], BEACH, spot[2]), rng)
	end
	for _, spot in { { -35, -90 }, { 25, -92 } } do
		Props.crabPot(docks, k.at(spot[1], BEACH, spot[2]), rng)
	end
	Props.ropeCoil(docks, k.at(8, BEACH, -91.5))
	Props.fishRack(docks, k.at(-12, BEACH, -73), k.yaw(0), rng)
	Props.stall(docks, k.at(-38, BEACH, -86), k.yaw(math.pi), rng, accent)
	for _, x in { -52, 52 } do
		Props.lampPost(docks, k.at(x * 0.95, BEACH, -71))
	end
	local buoys = group(dressing, "Buoys")
	for _, spot in { { -48, -150 }, { 48, -150 }, { 0, -178 }, { -70, -118 }, { 70, -118 } } do
		Props.buoy(buoys, k.at(spot[1], 0, spot[2]), rng)
	end
	pause()

	-- The village square on the sand between the quay and the harbour wall.
	local square = group(dressing, "Square")
	-- Straight up from the quay to the foot of the stair.
	path(square, k, { Vector2.new(0, -69), Vector2.new(0, STAIR_START - 3) }, BEACH, 6, PEBBLE)
	path(square, k, { Vector2.new(0, -67), Vector2.new(-6, -69), Vector2.new(-30, -71) }, BEACH, 5.5, PEBBLE)
	path(square, k, { Vector2.new(0, -67), Vector2.new(8, -69), Vector2.new(30, -71) }, BEACH, 5.5, PEBBLE)
	path(square, k, { Vector2.new(-6, -60), Vector2.new(-24, -52), Vector2.new(-46, -46), Vector2.new(-62, -34) }, BEACH, 5, PEBBLE)
	path(square, k, { Vector2.new(6, -60), Vector2.new(26, -50), Vector2.new(48, -42) }, BEACH, 5, PEBBLE)
	for _ = 1, 16 do
		local x, z = rng:NextNumber(-74, 74), rng:NextNumber(-64, -34)
		if math.abs(x) > 20 then
			local patch = Props.cylinder(square, k.at(x, BEACH + 0.04, z), 0.1, rng:NextNumber(6, 12), shade(GRASS, rng, 0.1), M.Grass)
			patch.Name, patch.CanCollide, patch.CanQuery = "GrassPatch", false, false
		end
	end
	Props.well(square, k.at(-44, BEACH, -38))
	Props.signpost(square, k.at(11, BEACH, -63), k.yaw(0), { { "PLOT", math.pi / 2 }, { "DOCKS", 0 }, { "GULLHAVEN", -0.4 } })
	local noticeFrame = k.cf(34, BEACH + 4.2, -36, math.pi)
	sign(square, noticeFrame, "NoticeBoard", "COMPANY NOTICES", 9)
	for _, nx in { -4, 4 } do
		part(square, "NoticePost", Vector3.new(0.5, 6, 0.5), noticeFrame * CFrame.new(nx, -1.2, 0), TRIM, M.Wood)
	end
	for _, spot in { { -32, -46, math.pi }, { 32, -46, math.pi }, { -58, -58, math.pi * 0.85 } } do
		Props.bench(square, k.at(spot[1], BEACH, spot[2]), k.yaw(spot[3]))
	end
	-- A fire pit ringed with stones and log seats.
	local fire = group(square, "FirePit")
	for index = 1, 8 do
		local angle = index / 8 * math.pi * 2
		Props.rock(fire, k.at(52 + math.cos(angle) * 2.8, BEACH, -34 + math.sin(angle) * 2.8), rng, 1.2, STONE)
	end
	local embers = part(fire, "Embers", Vector3.new(2.6, 0.5, 2.6), k.cf(52, BEACH + 0.25, -34), rgb(255, 120, 40), M.Neon, false)
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness, glow.Parent = rgb(255, 150, 70), 20, 1.4, embers
	for index = 1, 3 do
		local angle = index / 3 * math.pi * 2 + 0.4
		local seat = k.at(52 + math.cos(angle) * 6, BEACH + 0.7, -34 + math.sin(angle) * 6)
		part(fire, "LogSeat", Vector3.new(4.5, 1.4, 1.4), CFrame.lookAt(seat, k.at(52, BEACH + 0.7, -34)), rgb(104, 76, 52), M.Wood)
	end
	-- Lantern posts round the square, strung with lights.
	local posts = {}
	for _, spot in { { -30, -64 }, { -60, -44 }, { -22, -40 }, { 30, -64 }, { 60, -46 }, { 22, -40 } } do
		lanternPost(square, k, spot[1], spot[2], BEACH, if spot[1] < 0 then -math.pi / 2 else math.pi / 2)
		table.insert(posts, k.at(spot[1], BEACH + 8.8, spot[2]))
	end
	for _, pair in { { 1, 4 }, { 1, 2 }, { 2, 3 }, { 4, 5 }, { 5, 6 }, { 3, 6 } } do
		Props.stringLights(square, posts[pair[1]], posts[pair[2]], rng, 1.6)
	end
	for _, spot in { { -66, -36 }, { 72, -44 }, { -56, -33 }, { -16, -46 }, { 16, -46 }, { 40, -46 } } do
		Props.bush(square, k.at(spot[1], BEACH, spot[2]), rng, LEAVES)
		Props.flowers(square, k.at(spot[1] + 3, BEACH, spot[2] - 2), rng)
	end
	for _, spot in { { -64, -66 }, { 66, -60 }, { 72, -40 } } do
		Props.crates(square, k.at(spot[1], BEACH, spot[2]), rng)
		Props.barrel(square, k.at(spot[1] + 3.5, BEACH, spot[2] + 1), rng)
	end
	Props.fishRack(square, k.at(-68, BEACH, -48), k.yaw(math.pi / 2), rng)
	pause()

	-- The upper terrace: the empty fenced plot, an overlook and trees around it.
	local plotFrame = frame * CFrame.new(0, Layout.PLOT_HEIGHT, Layout.PLOT_Z)
	local plot = group(dressing, "Plot")
	part(plot, "PlotPad", Vector3.new(108.4, 0.3, 63.4), plotFrame * CFrame.new(0, -0.15, 0), DIRT, M.Ground)
	for _, edge in { { 0, -32.1, 109.6, 1 }, { 0, 32.1, 109.6, 1 }, { -54.8, 0, 1, 63.2 }, { 54.8, 0, 1, 63.2 } } do
		part(plot, "PlotCurb", Vector3.new(edge[3], 0.5, edge[4]), plotFrame * CFrame.new(edge[1], -0.1, edge[2]), shade(STONE, rng, 0.04), M.Cobblestone)
	end
	local function fence(x1, z1, x2, z2)
		Props.fence(plot, (plotFrame * CFrame.new(x1, -0.05, z1)).Position, (plotFrame * CFrame.new(x2, -0.05, z2)).Position)
	end
	fence(-55.6, -33, -6, -33)
	fence(6, -33, 55.6, -33)
	fence(-55.6, 33, 55.6, 33)
	fence(-55.6, -33, -55.6, 33)
	fence(55.6, -33, 55.6, 33)
	-- Gate arch with the plot's name over the way in from the stairs.
	for _, gx in { -6, 6 } do
		part(plot, "GatePost", Vector3.new(1, 9, 1), plotFrame * CFrame.new(gx, 4.5, -33), TRIM, M.Wood)
		Props.lantern(plot, plotFrame * CFrame.new(gx, 9.8, -33), 18, 1)
	end
	part(plot, "GateBeam", Vector3.new(13.4, 0.8, 0.8), plotFrame * CFrame.new(0, 8.6, -33), TRIM, M.Wood)
	sign(plot, plotFrame * CFrame.new(0, 7.2, -33.1), "PlotSign", "COMPANY PLOT", 9)
	for _, corner in { { -57.5, -35 }, { 57.5, -35 }, { -57.5, 35 }, { 57.5, 35 } } do
		Props.lampPost(plot, (plotFrame * CFrame.new(corner[1], -0.16, corner[2])).Position)
	end
	path(plot, k, { Vector2.new(0, NOTCH_BACK + 0.5), Vector2.new(0, Layout.PLOT_Z - 34) }, TERRACE, 6, PEBBLE)
	-- Overlook railing along the cliff and round the rim of the stair cut.
	for side = -1, 1, 2 do
		Props.fence(plot, k.at(side * 62, TERRACE, FRONT + 0.6), k.at(side * (NOTCH + 0.7), TERRACE, FRONT + 0.6))
		Props.fence(plot, k.at(side * (NOTCH + 0.7), TERRACE, FRONT + 0.6), k.at(side * (NOTCH + 0.7), TERRACE, NOTCH_BACK - 0.2))
	end
	for _, x in { -34, 34 } do
		Props.bench(plot, k.at(x, TERRACE, FRONT + 4), k.yaw(0))
	end
	Props.flag(plot, k.at(72, TERRACE, -6), accent)
	local around = { { -62, 2, 62, Layout.PLOT_Z + 40 }, { -14, -30, 14, 12 }, { -66, -30, 66, -18 }, { 64, -14, 80, 2 } }
	woodland(k, 22, 30, around)
	pause()

	-- Reeds and driftwood on the open shore beyond the square.
	local shore = group(dressing, "Shore")
	for index = 1, 16 do
		local x, z = sandSpot(k, FRONT + 2)
		if x then
			if index % 2 == 0 then
				Props.driftwood(shore, k.at(x, BEACH, z), rng)
			else
				Props.shells(shore, k.at(x, BEACH, z), rng)
			end
		end
	end
	return dressing
end

local tokens = setmetatable({}, { __mode = "k" })

local function finish(island: Model, dressing: Model)
	-- Owner prompts built after CompanyIslandService last refreshed still need their owner.
	for _, item in dressing:GetDescendants() do
		if item:IsA("ProximityPrompt") and CollectionService:HasTag(item, "ShopOwnerPrompt") then
			item:SetAttribute("OwnerUserId", island:GetAttribute("OwnerUserId") or 0)
		end
	end
	pack(dressing)
end

-- The owned island's landform: the beach, the terrace and its knolls clad in stacked
-- rock, the grassy hill, the cut the stair climbs through and the sea stacks. The
-- straight cliff front is left to the village dressing's harbour wall.
local function buildGround(ground: Model, frame: CFrame, id: number, pause: (() -> ())?)
	local wait = pause or function() end
	local rng = Random.new(4100 + id)
	local shape = shapeOf(id)
	local k = kit(frame, ground, rng, shape)
	local COAST, UPPER = shape.coast, shape.upper
	plateau(ground, frame, COAST, BEACH, -20, 7, SAND, M.Sand)
	plateau(ground, frame, UPPER, TERRACE, BEACH, 1, GRASS, M.Grass)
	wait()
	local edges = normals(UPPER)
	for index, a in UPPER do
		local b = UPPER[index % #UPPER + 1]
		if notchEdge(a, b) then
			cliffFace(ground, k, a, b, edges[index], TERRACE, BEACH, 0.8)
		elseif not frontEdge(a, b) and a.Y ~= NOTCH_BACK then
			cliffFace(ground, k, a, b, edges[index], TERRACE, -3, 2.5)
		end
		wait()
	end
	for _, ridge in shape.ridges do
		plateau(ground, frame, ridge.outline, ridge.top, TERRACE, 1, GRASS, M.Grass)
		local ridgeEdges = normals(ridge.outline)
		for index, a in ridge.outline do
			cliffFace(ground, k, a, ridge.outline[index % #ridge.outline + 1], ridgeEdges[index], ridge.top, TERRACE - 1, 1.8)
		end
	end
	-- Rock cheeks either side of the stair's foot step down with it, so the stair
	-- reads as cut through a spur of the cliff rather than stuck on its front.
	for side = -1, 1, 2 do
		local z = STAIR_START - 2
		while z < FRONT do
			local z2 = math.min(z + rng:NextNumber(3.5, 5.5), FRONT + 1)
			local top = stairHeight(z2) + rng:NextNumber(2.5, 4)
			local width = rng:NextNumber(7, 10)
			part(ground, "StairCheek", Vector3.new(width, top + 3, z2 - z + 0.6), k.cf(side * (8.6 + width / 2), (top - 3) / 2, (z + z2) / 2, rng:NextNumber(-0.05, 0.05)), shade(ROCK, rng, 0.1), M.Slate)
			z = z2
		end
	end
	local hill = shape.hill
	if hill then
		local mound = group(ground, "Hill")
		for _, tri in hill.tris do
			local a, b, c = frame * tri[1], frame * tri[2], frame * tri[3]
			-- Steep faces show bare rock through the grass.
			local steep = math.abs((tri[2] - tri[1]):Cross(tri[3] - tri[1]).Unit.Y) < 0.6
			local color = if steep then shade(ROCK, rng, 0.08) else shade(GRASS, rng, 0.07)
			LowPoly.triangle(a, b, c, (a + b + c) / 3 - frame.UpVector * 2, color, mound, if steep then M.Slate else M.Grass)
		end
		-- Boulders breaking through the slopes.
		for _ = 1, rng:NextInteger(3, 7) do
			local angle, reach = rng:NextNumber(0, TAU), rng:NextNumber(0.15, 0.8) * hill.radius
			local x, z = hill.center.X + math.cos(angle) * reach, hill.center.Y + math.sin(angle) * reach
			local y = hill.heightAt(x, z)
			if y then
				stone(mound, k, x, y - 0.6, z, rng:NextNumber(2.5, 5))
			end
		end
	end
	for _, spot in shape.stacks do
		local y, radius = -6, rng:NextNumber(6, 11)
		for _ = 1, rng:NextInteger(2, 6) do
			local h = rng:NextNumber(5, 8)
			local tilt = CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06))
			part(ground, "SeaStack", Vector3.new(radius * rng:NextNumber(1.7, 2.2), h + 0.6, radius * rng:NextNumber(1.7, 2.2)), k.cf(spot.X + rng:NextNumber(-1, 1), y + h / 2, spot.Y + rng:NextNumber(-1, 1), rng:NextNumber(0, math.pi)) * tilt, shade(ROCK, rng, 0.1), M.Slate)
			y += h
			radius *= rng:NextNumber(0.72, 0.88)
		end
		part(ground, "StackMoss", Vector3.new(radius * 1.8, 0.4, radius * 1.8), k.cf(spot.X, y + 0.4, spot.Y, rng:NextNumber(0, math.pi)), shade(GRASS, rng, 0.1), M.Grass, false)
		Props.bush(ground, k.at(spot.X, y + 0.5, spot.Y), rng, LEAVES)
	end
end

-- The coast for the world map, in world X/Z.
local function chart(frame: CFrame, outline: { Vector2 }): string
	local points = {}
	for _, point in outline do
		local world = frame * Vector3.new(point.X, 0, point.Y)
		table.insert(points, { world.X, world.Z })
	end
	return HttpService:JSONEncode(points)
end

-- Swaps the island to the village (its terrace landform and harbour) while owned
-- and back to the wild mountain. The new ground and dressing are built off-map and
-- cut into streaming pieces before they replace the old ones together, so clients
-- receive them piece by piece; the distant shell is redrawn after.
function Islands.dress(island: Model, owned: boolean)
	local kind = if owned then "Village" else "Wild"
	if island:GetAttribute("Dressing") == kind then
		return
	end
	island:SetAttribute("Dressing", kind)
	local token = {}
	tokens[island] = token
	task.spawn(function()
		local frame, id = island:GetAttribute("IslandFrame"), island:GetAttribute("IslandId")
		local resumed = os.clock()
		local function pause()
			if os.clock() - resumed > 0.02 then
				task.wait()
				resumed = os.clock()
			end
		end
		local ground = Instance.new("Model")
		ground.Name = "Ground"
		if owned then
			buildGround(ground, frame, id, pause)
		else
			buildMountain(ground, frame, id)
		end
		pause()
		local dressing = if owned then buildVillage(island, frame, id, pause) else buildWild(island, frame, id)
		if tokens[island] ~= token or not island.Parent then
			ground:Destroy()
			dressing:Destroy()
			return
		end
		finish(island, dressing)
		Lod.pinGround(ground)
		Lod.pin(dressing)
		for _, name in { "Ground", "Dressing" } do
			local old = island:FindFirstChild(name)
			if old then
				Lod.release(old)
				old:Destroy()
			end
		end
		ground.Parent = island
		dressing.Parent = island
		island:SetAttribute("ChartCoast", chart(frame, if owned then shapeOf(id).coast else mountainOf(id).coast))
		Lod.reshell(island)
	end)
end

local function build(root: Instance, id: number)
	local island = Instance.new("Model")
	island.Name = "Company Island " .. id
	island:SetAttribute("CompanyIslandVersion", Islands.VERSION)
	island:SetAttribute("IslandId", id)
	island:SetAttribute("OwnerUserId", 0)
	island:SetAttribute("LodRoot", true)
	island:SetAttribute("LodRadial", true)
	-- The village's coast reaches further than the mountain's, so it sets the clearance.
	local shape = shapeOf(id)
	local reach = 0
	for _, point in shape.coast do
		reach = math.max(reach, point.Magnitude)
	end
	island:SetAttribute("Radius", math.ceil(reach))
	local frame = Layout.frame(id)
	island:SetAttribute("IslandFrame", frame)
	island:SetAttribute("PlotFrame", Layout.plotFrame(id))
	island:SetAttribute("BoatDockFrame", frame * CFrame.new(0, 0, -92))
	-- Every island starts out wild.
	buildMountain(group(island, "Ground"), frame, id)
	island:SetAttribute("ChartCoast", chart(frame, mountainOf(id).coast))
	-- The sale board stands at the foot of the mountain, and on the village beach.
	local board = sign(island, frame * CFrame.new(-20, 8.3, -85), "PropertyBoard", Layout.Names[id] .. " / $50,000", 23)
	prompt(board, "BuyCompanyIslandPrompt", "View island", Layout.Names[id], false)
	local stand = group(island, "PropertySign")
	for _, x in { -10.5, 10.5 } do
		part(stand, "SignPost", Vector3.new(0.6, 5.2, 0.6), frame * CFrame.new(-20 + x, BEACH + 2.6, -85.4), TRIM, M.Wood)
	end
	-- The inner berth stays within jumping distance of the right-hand pier.
	local marker = part(island, "BoatSpawn", Vector3.one, frame * CFrame.new(14, 0, -144), TRIM, M.Wood, false)
	marker.Transparency = 1
	island:SetAttribute("PorterPickup", (frame * CFrame.new(30, BEACH, -116)).Position)
	-- Placed company furniture; one streaming piece, so later additions arrive with it.
	group(island, "PlotFurniture")
	local wild = buildWild(island, frame, id)
	finish(island, wild)
	wild.Parent = island
	island:SetAttribute("Dressing", "Wild")
	CollectionService:AddTag(island, Layout.TAG)
	island.Parent = root
	return island
end

function Islands.reserve(placed)
	for id = 1, Layout.COUNT do
		table.insert(placed, { position = Layout.position(id), radius = Layout.FOOTPRINT })
	end
end

function Islands.ensure(root: Instance)
	local current = true
	for id = 1, Layout.COUNT do
		local island = root:FindFirstChild("Company Island " .. id)
		if not island or island:GetAttribute("CompanyIslandVersion") ~= Islands.VERSION then current = false; break end
	end
	if current then return end
	-- Retrofitting a Studio-baked map removes only unowned procedural scenery
	-- inside the new property reservations; player bases and inventories survive.
	local resumed = os.clock()
	for _, model in root:GetDescendants() do
		if os.clock() - resumed > 0.05 then task.wait(); resumed = os.clock() end
		if model:IsA("Model") and model.Name == "Island" then
			local ground = model:FindFirstChild("Ground")
			if ground and ground:IsA("Model") then
				local bounds, size = ground:GetBoundingBox()
				local center = Vector2.new(bounds.X, bounds.Z)
				for id = 1, Layout.COUNT do
					if (center - Layout.position(id)).Magnitude < Layout.FOOTPRINT + math.max(size.X, size.Z) / 2 then
						model:Destroy()
						break
					end
				end
			end
		end
	end
	for id = 1, Layout.COUNT do
		local existing = root:FindFirstChild("Company Island " .. id)
		if existing and existing:GetAttribute("CompanyIslandVersion") ~= Islands.VERSION then
			existing:Destroy()
			existing = nil
		end
		if not existing then
			build(root, id)
			task.wait()
		end
	end
	-- Repositioned properties and removed scenery invalidate the baked shells.
	-- Startup's deferred LOD pass rebuilds them after the harbour opens.
	local shells = root:FindFirstChild("Lod")
	if shells then shells:Destroy() end
end

-- The company desk: a writing desk with a chair behind it (-Z) and the owner's
-- side at +Z. `frame` is the centre of its base on the plot; desk and chair
-- fill two grid cells (8.2 x 4.1, FurnitureCatalog).
function Islands.buildDesk(parent: Instance, frame: CFrame): Model
	local desk = group(parent, "CompanyDesk")
	local function block(name, size, x, y, z, color, material)
		return part(desk, name, size, frame * CFrame.new(x, y, z), color, material)
	end
	local deskZ = 0.8
	block("DeskTop", Vector3.new(8, 0.35, 2.4), 0, 3, deskZ, WOOD, M.WoodPlanks)
	block("DeskEdge", Vector3.new(8.04, 0.08, 2.44), 0, 2.8, deskZ, TRIM, M.WoodPlanks)
	for _, x in { -3.2, 3.2 } do
		block("DeskPedestal", Vector3.new(1.4, 2.8, 2.2), x, 1.4, deskZ, TRIM, M.WoodPlanks)
		-- Drawers face the chair side.
		for index = 0, 2 do
			block("DeskDrawer", Vector3.new(1.2, 0.75, 0.05), x, 0.55 + index * 0.85, deskZ - 1.12, WOOD, M.WoodPlanks)
			block("DrawerPull", Vector3.new(0.4, 0.07, 0.07), x, 0.75 + index * 0.85, deskZ - 1.17, rgb(186, 150, 84), M.Metal)
		end
	end
	block("ModestyPanel", Vector3.new(5, 2, 0.2), 0, 1.9, deskZ + 1, TRIM, M.WoodPlanks)
	block("DeskMat", Vector3.new(2.4, 0.04, 1.4), 0, 3.19, deskZ - 0.3, rgb(36, 66, 58), M.Fabric)
	block("Ledger", Vector3.new(1.4, 0.22, 1), -0.1, 3.32, deskZ - 0.3, rgb(120, 46, 40), M.Fabric)
	block("Papers", Vector3.new(1.2, 0.05, 1.6), -2.1, 3.2, deskZ, rgb(240, 234, 220), M.SmoothPlastic)
	block("Inkwell", Vector3.new(0.25, 0.25, 0.25), 1.4, 3.3, deskZ + 0.6, rgb(30, 34, 60), M.Glass)
	block("Quill", Vector3.new(0.05, 0.7, 0.05), 1.45, 3.6, deskZ + 0.6, rgb(240, 236, 226), M.Fabric)
	block("LampBase", Vector3.new(0.5, 0.5, 0.5), 3.3, 3.42, deskZ + 0.6, rgb(60, 62, 64), M.Metal)
	block("LampArm", Vector3.new(0.08, 0.7, 0.08), 3.3, 3.95, deskZ + 0.6, rgb(60, 62, 64), M.Metal)
	local lampShade = block("LampShade", Vector3.new(0.9, 0.45, 0.9), 3.3, 4.45, deskZ + 0.5, rgb(250, 222, 160), M.Neon)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Parent = rgb(255, 223, 172), 12, 1, lampShade
	-- The owner's chair, tucked up to the desk.
	block("ChairSeat", Vector3.new(1.9, 0.35, 1.7), 0, 1.9, -1.0, ROOF, M.Fabric)
	block("ChairBack", Vector3.new(1.9, 2.2, 0.3), 0, 3.1, -1.85, ROOF, M.Fabric)
	block("ChairStem", Vector3.new(0.35, 1.6, 0.35), 0, 0.9, -1.0, rgb(60, 62, 64), M.Metal)
	block("ChairBase", Vector3.new(1.5, 0.12, 1.5), 0, 0.1, -1.0, rgb(60, 62, 64), M.Metal)
	return desk
end

return Islands
