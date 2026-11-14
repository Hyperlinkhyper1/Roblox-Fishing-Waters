-- Hills behind the distant city. The mainland chart stops at the world edge on the south and
-- east, so a faceted range rises from those edges behind the suburbs and the woods: patchwork
-- fields and hedgerows on the foothills, woods and pines up the slopes, bare rock on the steep
-- faces, moorland and granite tors on the tops, and a gravel track that zigzags up from the end
-- of the last suburb road to a radio mast on the summit. Both tips of the range run down into
-- the sea, so no boat can slip under it. A Grand Prix circuit (see CityCircuit) is cut into the
-- foot of the south range: the facets under it are pinned just below its levels and the ground
-- around it eases back to the natural slopes.
-- Coordinates are relative to the city centre, like the rest of the city (north is -Z).
local LowPoly = require(script.Parent.LowPoly)
local CityCircuit = require(script.Parent.CityCircuit)

local CityHills = {}

local TOP = 8 -- the city's walkable land height (see ModernCity)
local EDGE = 1180 -- the chart's south and east edges, where the hills meet the mainland
local CELL = 59 -- the edges fall on grid lines (EDGE is a whole number of cells)
local EDGE_INDEX = EDGE // CELL
local I0, I1 = -21, 31 -- vertex columns, x = i * CELL: from the west tip to the outer rim
local J0, J1 = -20, 40 -- vertex rows, z = j * CELL: from the north tip to the outer rim
local LAND_I, LAND_J = -20, -19 -- edge vertices from here on sit on the mainland's own edge
local DEPTH = I1 * CELL - EDGE -- how far the range reaches past the edges
local SEA = -22 -- where the tips of the range end, under the water
local BLOCK = 3 -- cells per side of one streaming piece
local rgb = Color3.fromRGB
local M = Enum.Material

CityHills.EDGE = EDGE
CityHills.CELL = CELL
CityHills.SUMMIT = { 1150, 1615 }
-- From the east end of the last suburb road, out past the edge and in long zigzags up the
-- face to the summit
CityHills.TRACK = {
	{ 1110, 1110 },
	{ 1290, 1140 },
	{ 1350, 1280 },
	{ 1030, 1430 },
	{ 1400, 1520 },
	{ 1000, 1590 },
	{ 1150, 1615 },
}
local TRACK_WIDTH = 6

local MEADOW = rgb(104, 122, 74)
local WOODLAND = rgb(70, 90, 56)
local ROCK = rgb(112, 106, 96)
local SCREE = rgb(140, 134, 120)
local MOOR = rgb(128, 120, 80)
local SHORE = rgb(148, 138, 116)
local VERGE = rgb(96, 132, 66)
local CROPS = {
	{ rgb(112, 138, 78), M.Grass, "pasture" },
	{ rgb(198, 182, 74), M.Grass }, -- rapeseed
	{ rgb(118, 94, 70), M.Ground }, -- ploughed
	{ rgb(150, 140, 86), M.Grass }, -- stubble
	{ rgb(132, 146, 88), M.Grass },
	{ rgb(96, 112, 66), M.Grass },
}
local LEAVES = { rgb(78, 102, 62), rgb(92, 112, 70), rgb(70, 92, 60), rgb(104, 118, 74) }
local PINES = { rgb(48, 70, 50), rgb(56, 78, 54), rgb(44, 64, 48) }

-- Deterministic noise in [0, 1)
local function hash(a: number, b: number, salt: number): number
	local v = math.sin(a * 12.9898 + b * 78.233 + salt * 37.719) * 43758.5453
	return v - math.floor(v)
end

local function smoothstep(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

-- How far a point lies past the edges
local function depth(x: number, z: number): number
	return math.max(x - EDGE, z - EDGE, 0)
end

-- The range itself: it climbs out of the edge, crests a few hundred studs back in a line of
-- peaks and saddles, then falls away again on the far side.
local function terrain(x: number, z: number): number
	local d = depth(x, z)
	local rise = smoothstep(0, 470, d) ^ 1.25
	local broad = math.noise(x / 540, z / 540, 0.37)
	local rolling = math.noise(x / 240 + 3.1, z / 240, 4.13)
	local ridged = 1 - 2 * math.abs(math.noise(x / 320, z / 320, 9.71))
	local crest = math.clamp(150 + 120 * broad + 40 * rolling + 40 * ridged, 70, 300)
	local detail = 6 * math.noise(x / 75, z / 75, 2.29) * math.clamp(d / 90, 0, 1)
	local back = 1 - 0.6 * smoothstep(520, DEPTH, d)
	return TOP + (rise * crest + detail) * back
end

local SUMMIT_HEIGHT = terrain(CityHills.SUMMIT[1], CityHills.SUMMIT[2])
CityCircuit.shape(terrain)

-- Cells under the circuit are split into SUB x SUB smaller ones, fine enough for the ground to
-- step between stretches of track at different levels. All heights live on one lattice FINE
-- studs apart; a plain cell uses only its corners, every SUB-th lattice point.
local SUB = 3
local FINE = CELL / SUB
local DROP = 0.6 -- pinned ground sits this far below the circuit's levels

local function latticeKey(fi: number, fj: number): number
	return (fi + 400) * 4000 + (fj + 400)
end

local splitCells: { [number]: boolean } = {}
local pinned: { [number]: number } = {}
local heights: { [number]: number } = {}

local function split(i: number, j: number): boolean
	return splitCells[latticeKey(i, j)] == true
end

local function cellExists(i: number, j: number): boolean
	return i >= I0 and i < I1 and j >= J0 and j < J1 and (i >= EDGE_INDEX or j >= EDGE_INDEX)
end

-- The first row meets the mainland's edge exactly
local function fixed(fi: number, fj: number): boolean
	if fi % SUB ~= 0 or fj % SUB ~= 0 then
		return false
	end
	local i, j = fi // SUB, fj // SUB
	return (i == EDGE_INDEX and j <= EDGE_INDEX and j >= LAND_J)
		or (j == EDGE_INDEX and i <= EDGE_INDEX and i >= LAND_I)
end

-- A lattice point on the edge of a split cell that it shares with a plain one has to stay on
-- that cell's straight edge: the corners at either end, and how far along it lies
local function edgeOf(fi: number, fj: number): (number?, number, number, number, number)
	local onX, onZ = fi % SUB == 0, fj % SUB == 0
	local i, j = fi // SUB, fj // SUB
	if onX and not onZ and not (split(i - 1, j) and split(i, j)) then
		return fi, j * SUB, fi, (j + 1) * SUB, (fj % SUB) / SUB
	elseif onZ and not onX and not (split(i, j - 1) and split(i, j)) then
		return i * SUB, fj, (i + 1) * SUB, fj, (fi % SUB) / SUB
	end
	return nil, 0, 0, 0, 0
end

-- The natural ground, eased round the circuit from its levels back to the hills
local function groundAt(x: number, z: number, jitter: number): number
	local h = terrain(x, z)
	-- The summit is levelled off for the mast
	local r = math.sqrt((x - CityHills.SUMMIT[1]) ^ 2 + (z - CityHills.SUMMIT[2]) ^ 2)
	h = SUMMIT_HEIGHT + (h - SUMMIT_HEIGHT) * smoothstep(35, 80, r)
	-- Both ends of the range sink into the sea
	local taper = smoothstep(I0 * CELL, -880, x) * smoothstep(J0 * CELL, -830, z)
	h = SEA + (h - SEA) * taper
	h += (jitter - 0.5) * 4 * math.clamp(depth(x, z) / 90, 0, 1)
	local clearance, level = CityCircuit.level(x, z)
	if clearance < CityCircuit.BLEND then
		local base = level - DROP
		local shaped = base + (h - base) * smoothstep(0, CityCircuit.BLEND, math.max(clearance, 0))
		-- Preserve the level join to the city even where the paddock's earthworks
		-- blend towards the edge of the hills.
		h += (shaped - h) * smoothstep(0, 110, depth(x, z))
	end
	return h
end

local function latticeHeight(fi: number, fj: number): number
	local id = latticeKey(fi, fj)
	local h = heights[id]
	if h then
		return h
	end
	local ai, aj, bi, bj, t = edgeOf(fi, fj)
	if fixed(fi, fj) then
		h = TOP
	elseif pinned[id] then
		h = pinned[id]
	elseif ai then
		local a = latticeHeight(ai, aj)
		h = a + (latticeHeight(bi, bj) - a) * t
	elseif fi % SUB == 0 and fj % SUB == 0 then
		h = groundAt(fi * FINE, fj * FINE, hash(fi // SUB, fj // SUB, 3))
	else
		h = groundAt(fi * FINE, fj * FINE, hash(fi, fj, 7))
	end
	heights[id] = h
	return h
end

local function height(i: number, j: number): number
	return latticeHeight(i * SUB, j * SUB)
end

-- Each cell (and sub-cell) is split along one diagonal or the other, so the facets never line up
local function flipped(i: number, j: number): boolean
	return hash(i, j, 41) < 0.5
end
local function subFlipped(fi: number, fj: number): boolean
	return hash(fi, fj, 43) < 0.5
end

-- The facet holding (u, w) across a square: its three corners as offsets, and the weight of each
local function corners(flip: boolean, u: number, w: number): { number }
	if flip then
		if u + w <= 1 then
			return { 0, 0, 1 - u - w, 1, 0, u, 0, 1, w }
		end
		return { 1, 1, u + w - 1, 0, 1, 1 - u, 1, 0, 1 - w }
	elseif u >= w then
		return { 0, 0, 1 - u, 1, 0, u - w, 1, 1, w }
	end
	return { 0, 0, 1 - w, 1, 1, u, 0, 1, w - u }
end

-- The facet under (x, z): its corners as lattice points, each with its weight
local function facetAt(x: number, z: number): { number }
	local i, j = math.floor(x / CELL), math.floor(z / CELL)
	local f
	if split(i, j) then
		local fi, fj = math.floor(x / FINE), math.floor(z / FINE)
		f = corners(subFlipped(fi, fj), x / FINE - fi, z / FINE - fj)
		for v = 0, 2 do
			f[v * 3 + 1] += fi
			f[v * 3 + 2] += fj
		end
	else
		f = corners(flipped(i, j), x / CELL - i, z / CELL - j)
		for v = 0, 2 do
			f[v * 3 + 1] = (f[v * 3 + 1] + i) * SUB
			f[v * 3 + 2] = (f[v * 3 + 2] + j) * SUB
		end
	end
	return f
end

-- Pin every corner of a facet under the circuit just below the level of the nearest stretch of
-- track (or of the pits), then lower the corners of any facet that still rises into the road,
-- each by its share, until none does. Lowering never lifts another facet, so only the points
-- that failed last time need another look.
do
	local px, pz, ptop = {}, {}, {}
	CityCircuit.eachGroundPoint(function(x: number, z: number, top: number)
		local i, j = math.floor(x / CELL), math.floor(z / CELL)
		if cellExists(i, j) then
			splitCells[latticeKey(i, j)] = true
			table.insert(px, x)
			table.insert(pz, z)
			table.insert(ptop, top)
		end
	end)
	local function pin(fi: number, fj: number)
		local id = latticeKey(fi, fj)
		if not fixed(fi, fj) and pinned[id] == nil then
			local _, level = CityCircuit.level(fi * FINE, fj * FINE)
			pinned[id] = level - DROP
		end
	end
	-- A facet's corners as the movable lattice points they hang from, with their weights
	local function terms(f: { number }): ({ [number]: number }, number)
		local out, constant = {}, 0
		local function add(fi: number, fj: number, weight: number)
			if fixed(fi, fj) then
				constant += TOP * weight
			else
				local id = latticeKey(fi, fj)
				out[id] = (out[id] or 0) + weight
			end
		end
		for v = 0, 2 do
			local fi, fj, weight = f[v * 3 + 1], f[v * 3 + 2], f[v * 3 + 3]
			local ai, aj, bi, bj, t = edgeOf(fi, fj)
			if ai then
				add(ai :: number, aj, weight * (1 - t))
				add(bi, bj, weight * t)
			else
				add(fi, fj, weight)
			end
		end
		return out, constant
	end
	local active = {}
	for p = 1, #px do
		local f = facetAt(px[p], pz[p])
		for v = 0, 2 do
			local fi, fj = f[v * 3 + 1], f[v * 3 + 2]
			local ai, aj, bi, bj = edgeOf(fi, fj)
			if ai then
				pin(ai :: number, aj)
				pin(bi, bj)
			else
				pin(fi, fj)
			end
		end
		active[p] = p
	end
	for _ = 1, 100 do
		local failed = {}
		for _, p in active do
			local weights, y = terms(facetAt(px[p], pz[p]))
			local limit = ptop[p] - DROP + 0.2
			local above = 0 -- how much the corners higher than the limit hold the facet up
			for id, weight in weights do
				y += pinned[id] * weight
				above += weight * math.max(pinned[id] - limit, 0)
			end
			local excess = y - limit
			if excess > 0 and above > 0 then
				-- Only the corners above the limit come down, each part of the way to it, so a
				-- corner already low enough for its own stretch of track stays where it is
				local share = math.min((excess + 0.02) / above, 1)
				for id in weights do
					local over = pinned[id] - limit
					if over > 0 then
						pinned[id] -= over * share
					end
				end
				table.insert(failed, p)
			end
		end
		if #failed == 0 then
			break
		end
		active = failed
	end
end

local function nearCircuit(i: number, j: number): boolean
	return split(i, j)
		or pinned[latticeKey(i * SUB, j * SUB)] ~= nil
		or pinned[latticeKey((i + 1) * SUB, j * SUB)] ~= nil
		or pinned[latticeKey(i * SUB, (j + 1) * SUB)] ~= nil
		or pinned[latticeKey((i + 1) * SUB, (j + 1) * SUB)] ~= nil
end

local function vertex(i: number, j: number): Vector3
	return Vector3.new(i * CELL, height(i, j), j * CELL)
end

local function latticeVertex(fi: number, fj: number): Vector3
	return Vector3.new(fi * FINE, latticeHeight(fi, fj), fj * FINE)
end

-- The cell's triangles, in local coordinates: two, or two for each sub-cell of a split cell
local function triangles(i: number, j: number): { { Vector3 } }
	if split(i, j) then
		local out = {}
		for a = 0, SUB - 1 do
			for b = 0, SUB - 1 do
				local fi, fj = i * SUB + a, j * SUB + b
				local v00, v10 = latticeVertex(fi, fj), latticeVertex(fi + 1, fj)
				local v01, v11 = latticeVertex(fi, fj + 1), latticeVertex(fi + 1, fj + 1)
				if subFlipped(fi, fj) then
					table.insert(out, { v00, v10, v01 })
					table.insert(out, { v10, v11, v01 })
				else
					table.insert(out, { v00, v10, v11 })
					table.insert(out, { v00, v11, v01 })
				end
			end
		end
		return out
	end
	local v00, v10, v01, v11 = vertex(i, j), vertex(i + 1, j), vertex(i, j + 1), vertex(i + 1, j + 1)
	if flipped(i, j) then
		return { { v00, v10, v01 }, { v10, v11, v01 } }
	end
	return { { v00, v10, v11 }, { v00, v11, v01 } }
end

-- Whether (x, z) lies on the hills rather than the mainland or past the rim
function CityHills.covers(x: number, z: number): boolean
	return cellExists(math.floor(x / CELL), math.floor(z / CELL))
end

-- Ground height at (x, z), exactly on the facets. The mainland is flat at TOP.
function CityHills.surface(x: number, z: number): number
	if not cellExists(math.floor(x / CELL), math.floor(z / CELL)) then
		return TOP
	end
	local f = facetAt(x, z)
	local y = 0
	for v = 0, 2 do
		y += latticeHeight(f[v * 3 + 1], f[v * 3 + 2]) * f[v * 3 + 3]
	end
	return y
end

local function upness(a: Vector3, b: Vector3, c: Vector3): number
	return math.abs((b - a):Cross(c - a).Unit.Y)
end

-- Distance from (x, z) to the track's centreline
local function trackDistance(x: number, z: number): number
	local best = math.huge
	local track = CityHills.TRACK
	for k = 1, #track - 1 do
		local a, b = track[k], track[k + 1]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local t = math.clamp(((x - a[1]) * dx + (z - a[2]) * dz) / (dx * dx + dz * dz), 0, 1)
		best = math.min(best, math.sqrt((a[1] + dx * t - x) ^ 2 + (a[2] + dz * t - z) ^ 2))
	end
	return best
end

-- Room for dressing at (x, z): clear of both the farm track and the circuit
local function clear(x: number, z: number, track: number, circuit: number): boolean
	return trackDistance(x, z) > track and CityCircuit.clearance(x, z) > circuit
end

local function forest(x: number, z: number): number
	return math.noise(x / 260, z / 260, 7.7) + 0.4 * math.noise(x / 90, z / 90, 1.9)
end

---------------------------------------------------------------------------------------------------
-- Building

local center = Vector3.zero

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	frame: CFrame,
	color: Color3,
	material: Enum.Material,
	collidable: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = frame
	p.Anchored = true
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = collidable ~= false
	if collidable == false then
		p.CanQuery = false
		p.CastShadow = false
	end
	p.Parent = parent
	return p
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(center + Vector3.new(x, y, z))
end

local function shaded(color: Color3, amount: number): Color3
	return Color3.new(math.min(color.R * amount, 1), math.min(color.G * amount, 1), math.min(color.B * amount, 1))
end

local function pieceModel(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m:AddTag("LodPiece")
	m.Parent = parent
	return m
end

local function broadleaf(parent: Instance, x: number, z: number, scale: number, seed: number)
	local y = CityHills.surface(x, z)
	local trunk = 8 + scale * 6
	part(
		parent,
		"TreeTrunk",
		Vector3.new(1.6 + scale, trunk + 2, 1.6 + scale),
		at(x, y - 1 + trunk / 2, z),
		rgb(88, 70, 54),
		M.Wood
	)
	local crown = part(
		parent,
		"TreeCrown",
		Vector3.one * (11 + scale * 9),
		at(x, y + trunk + 3 + scale * 2, z),
		LEAVES[seed % #LEAVES + 1],
		M.Grass,
		false
	)
	crown.Shape = Enum.PartType.Ball
end

-- A pine is a trunk under two stacked discs, the upper one narrower
local function pine(parent: Instance, x: number, z: number, scale: number, seed: number)
	local y = CityHills.surface(x, z)
	local tall = 14 + scale * 8
	part(
		parent,
		"PineTrunk",
		Vector3.new(1.2 + scale * 0.5, tall, 1.2 + scale * 0.5),
		at(x, y - 1 + tall / 2, z),
		rgb(80, 62, 50),
		M.Wood
	)
	local color = PINES[seed % #PINES + 1]
	local upright = CFrame.Angles(0, 0, math.pi / 2)
	local wide = 9 + scale * 5
	part(
		parent,
		"PineTier",
		Vector3.new(6 + scale * 2, wide, wide),
		at(x, y + tall * 0.55, z) * upright,
		color,
		M.Grass,
		false
	).Shape =
		Enum.PartType.Cylinder
	part(
		parent,
		"PineTier",
		Vector3.new(5 + scale * 2, wide * 0.6, wide * 0.6),
		at(x, y + tall * 0.55 + 5 + scale * 2, z) * upright,
		color,
		M.Grass,
		false
	).Shape =
		Enum.PartType.Cylinder
end

-- Granite tor: weathered slabs piled up a little askew
local function tor(parent: Instance, x: number, z: number, seed: number)
	local y = CityHills.surface(x, z) - 1.5
	local granite = rgb(128, 124, 116)
	for k, size in { Vector3.new(14, 5, 11), Vector3.new(11, 4.5, 9), Vector3.new(7, 4, 6) } do
		local yaw = hash(seed, k, 63) * math.pi
		local dx, dz = (hash(seed, k, 64) - 0.5) * 3, (hash(seed, k, 65) - 0.5) * 3
		part(
			parent,
			"Tor",
			size,
			at(x + dx, y + size.Y / 2, z + dz) * CFrame.Angles(0, yaw, (hash(seed, k, 66) - 0.5) * 0.12),
			shaded(granite, 0.92 + hash(seed, k, 67) * 0.14),
			M.Slate
		)
		y += size.Y - 0.4
	end
end

local function sheep(parent: Instance, x: number, z: number, seed: number)
	local y = CityHills.surface(x, z)
	local frame = at(x, y + 1.7, z) * CFrame.Angles(0, hash(seed, 1, 71) * math.pi * 2, 0)
	part(parent, "Sheep", Vector3.new(2.6, 2.2, 4.2), frame, rgb(232, 228, 214), M.Fabric, false)
	part(
		parent,
		"SheepHead",
		Vector3.new(1.3, 1.4, 1.5),
		frame * CFrame.new(0, 0.6, -2.5),
		rgb(50, 46, 44),
		M.SmoothPlastic,
		false
	)
end

-- A farmhouse and its barn on a stone plinth that takes up the slope
local function farm(parent: Instance, x: number, z: number, low: number, high: number, seed: number)
	local yaw = (seed % 4) * math.pi / 2
	local base = at(x, high, z) * CFrame.Angles(0, yaw, 0)
	local plinth = high - low + 2
	part(
		parent,
		"FarmPlinth",
		Vector3.new(34, plinth, 20),
		base * CFrame.new(4, 0.5 - plinth / 2, 0),
		rgb(124, 118, 104),
		M.Cobblestone
	)
	local wall = ({ rgb(206, 196, 176), rgb(178, 160, 136), rgb(150, 100, 82) })[seed % 3 + 1]
	part(parent, "Farmhouse", Vector3.new(16, 9, 11), base * CFrame.new(-4, 5, 0), wall, M.Plaster)
	for _, slope in { -1, 1 } do
		part(
			parent,
			"FarmRoof",
			Vector3.new(17, 0.8, 7.6),
			base * CFrame.new(-4, 11.2, slope * 3) * CFrame.Angles(slope * 0.62, 0, 0),
			rgb(78, 60, 54),
			M.Slate
		)
	end
	part(parent, "Barn", Vector3.new(12, 8, 16), base * CFrame.new(13, 4.5, 0), rgb(110, 50, 42), M.WoodPlanks)
	part(parent, "BarnRoof", Vector3.new(13, 1, 17), base * CFrame.new(13, 9, 0), rgb(70, 72, 72), M.CorrodedMetal)
end

-- Hedge along a grid edge: grid edges are facet edges, so it follows the ground exactly
local function hedge(parent: Instance, a: Vector3, b: Vector3)
	local mid = center + (a + b) / 2
	local frame = CFrame.lookAt(mid, center + b) + Vector3.new(0, 1, 0)
	part(parent, "Hedgerow", Vector3.new(2, 2.8, (b - a).Magnitude + 1), frame, rgb(62, 84, 50), M.Grass)
end

type Cell = { kind: string, crop: { any }?, parcel: number }

local function classify(i: number, j: number): Cell
	local pi, pj = i // 2, j // 2
	if nearCircuit(i, j) then
		return { kind = "circuit", parcel = pi * 1000 + pj }
	end
	local tris = triangles(i, j)
	local low, high = math.huge, -math.huge
	for _, tri in tris do
		for _, v in tri do
			low, high = math.min(low, v.Y), math.max(high, v.Y)
		end
	end
	local flat = math.min(upness(tris[1][1], tris[1][2], tris[1][3]), upness(tris[2][1], tris[2][2], tris[2][3]))
	local cx, cz = (i + 0.5) * CELL, (j + 0.5) * CELL
	local woods = forest(cx, cz)
	local parcel = pi * 1000 + pj
	if low > TOP - 1 and high < 62 and flat > 0.88 and woods < 0.35 then
		local crop = CROPS[math.floor(hash(pi, pj, 51) * #CROPS) + 1]
		return { kind = "field", crop = crop, parcel = parcel }
	elseif low > TOP - 1 and high < 210 and flat > 0.72 and woods > 0.1 then
		return { kind = "wood", parcel = parcel }
	end
	return { kind = "open", parcel = parcel }
end

-- A facet entirely under the circuit's asphalt or its pit and paddock slabs is never seen
local function hidden(a: Vector3, b: Vector3, c: Vector3): boolean
	for _, p in { a, b, c, (a + b + c) / 3, (a + b) / 2, (b + c) / 2, (c + a) / 2 } do
		if not CityCircuit.covered(p.X, p.Z) then
			return false
		end
	end
	return true
end

local function faceStyle(a: Vector3, b: Vector3, c: Vector3, cell: Cell, seed: number): (Color3, Enum.Material)
	local y = (a.Y + b.Y + c.Y) / 3
	local up = upness(a, b, c)
	local mx, mz = (a.X + b.X + c.X) / 3, (a.Z + b.Z + c.Z) / 3
	local shade = 0.93 + hash(seed, y, 31) * 0.12
	-- The banks cut and piled up for the circuit stay grassed unless they are really steep
	local near = cell.kind == "circuit" or CityCircuit.clearance(mx, mz) < CityCircuit.BLEND
	if y < 2 then
		return shaded(SHORE, shade), M.Pebble
	elseif up < (if near then 0.5 else 0.7) then
		return shaded(ROCK, shade), M.Slate
	elseif cell.kind == "circuit" then
		-- Mown verges round the circuit
		return shaded(VERGE, shade), M.Grass
	elseif near and up < 0.7 then
		return shaded(MEADOW, shade), M.Grass
	elseif up < 0.7 then
		return shaded(ROCK, shade), M.Slate
	elseif cell.kind == "field" and cell.crop then
		return shaded(cell.crop[1], 0.97 + hash(cell.parcel, 1, 32) * 0.06), cell.crop[2]
	elseif y > 175 + 25 * math.noise(mx / 200, mz / 200, 5.5) then
		if up < 0.82 then
			return shaded(SCREE, shade), M.Rock
		end
		return shaded(MOOR, shade), M.Grass
	elseif cell.kind == "wood" then
		return shaded(WOODLAND, shade), M.Grass
	end
	return shaded(MEADOW, shade), M.Grass
end

local function buildTrack(ground: Instance)
	local model = pieceModel(ground, "HillTrack")
	local count = 0
	local gravel = rgb(156, 146, 124)
	local track = CityHills.TRACK
	for k = 1, #track - 1 do
		local a, b = track[k], track[k + 1]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		-- Break the leg wherever it crosses a facet edge, so every piece lies flat on one facet
		local cuts = { 0, 1 }
		for i = math.floor(math.min(a[1], b[1]) / CELL) + 1, math.floor(math.max(a[1], b[1]) / CELL) do
			table.insert(cuts, (i * CELL - a[1]) / dx)
		end
		for j = math.floor(math.min(a[2], b[2]) / CELL) + 1, math.floor(math.max(a[2], b[2]) / CELL) do
			table.insert(cuts, (j * CELL - a[2]) / dz)
		end
		table.sort(cuts)
		local pieces = {}
		for k2 = 1, #cuts - 1 do
			local t0, t1 = cuts[k2], cuts[k2 + 1]
			if t1 - t0 > 1e-6 then
				table.insert(pieces, t0)
				local tm = (t0 + t1) / 2
				local i, j = math.floor((a[1] + dx * tm) / CELL), math.floor((a[2] + dz * tm) / CELL)
				local t
				if flipped(i, j) then
					t = ((i + j + 1) * CELL - a[1] - a[2]) / (dx + dz)
				else
					t = ((i - j) * CELL - a[1] + a[2]) / (dx - dz)
				end
				if t > t0 + 1e-6 and t < t1 - 1e-6 then
					table.insert(pieces, t)
				end
			end
		end
		table.insert(pieces, 1)
		for s = 1, #pieces - 1 do
			local t0, t1 = pieces[s], pieces[s + 1]
			local x0, z0 = a[1] + dx * t0, a[2] + dz * t0
			local x1, z1 = a[1] + dx * t1, a[2] + dz * t1
			-- Sample just inside the piece, so a point on an edge reads the facet it belongs to
			local p0 = Vector3.new(x0, CityHills.surface(x0 + dx * 1e-4, z0 + dz * 1e-4) + 0.3, z0)
			local p1 = Vector3.new(x1, CityHills.surface(x1 - dx * 1e-4, z1 - dz * 1e-4) + 0.3, z1)
			local length = (p1 - p0).Magnitude
			if length > 0.2 then
				local frame = CFrame.lookAt(center + (p0 + p1) / 2, center + p1)
				part(model, "HillTrack", Vector3.new(TRACK_WIDTH, 0.8, length + 0.8), frame, gravel, M.Pebble)
				count += 1
				if count % 150 == 0 then
					model = pieceModel(ground, "HillTrack")
				end
			end
		end
		-- A turning area at each bend
		if k > 1 then
			local y = CityHills.surface(a[1], a[2])
			part(
				model,
				"TrackBend",
				Vector3.new(0.8, TRACK_WIDTH + 4, TRACK_WIDTH + 4),
				at(a[1], y + 0.2, a[2]) * CFrame.Angles(0, 0, math.pi / 2),
				gravel,
				M.Pebble
			).Shape =
				Enum.PartType.Cylinder
		end
	end
end

local function buildSummit(ground: Instance)
	local model = pieceModel(ground, "HillSummit")
	local x, z = CityHills.SUMMIT[1], CityHills.SUMMIT[2]
	local y = CityHills.surface(x, z)
	local concrete = rgb(150, 146, 136)
	part(model, "MastBase", Vector3.new(12, 3, 12), at(x + 8, y, z + 8), concrete, M.Concrete)
	local red, white = rgb(196, 60, 48), rgb(230, 228, 222)
	local rise = y + 1.5
	for k = 1, 5 do
		local width = 2.8 - k * 0.3
		part(
			model,
			"RadioMast",
			Vector3.new(width, 16, width),
			at(x + 8, rise + 8, z + 8),
			if k % 2 == 1 then red else white,
			M.Metal
		)
		rise += 16
	end
	for _, side in { -1, 1 } do
		part(model, "MastAntenna", Vector3.new(0.6, 6, 2.4), at(x + 8 + side * 1.6, rise - 12, z + 8), white, M.Metal)
	end
	part(model, "MastLight", Vector3.new(1.4, 1.4, 1.4), at(x + 8, rise + 0.7, z + 8), rgb(255, 40, 30), M.Neon, false)
	part(model, "MastHut", Vector3.new(10, 7, 8), at(x - 6, y + 3, z + 10), rgb(176, 172, 160), M.Concrete)
	part(model, "MastHutRoof", Vector3.new(11, 0.6, 9), at(x - 6, y + 6.8, z + 10), rgb(70, 72, 72), M.Metal)
	-- A bench looking back over the city
	part(model, "Bench", Vector3.new(7, 0.5, 2), at(x - 8, y + 1.8, z - 10), rgb(110, 84, 60), M.WoodPlanks)
	part(model, "BenchBack", Vector3.new(7, 2, 0.4), at(x - 8, y + 3, z - 9), rgb(110, 84, 60), M.WoodPlanks)
	for _, side in { -1, 1 } do
		part(
			model,
			"BenchLeg",
			Vector3.new(0.5, 1.8, 2),
			at(x - 8 + side * 3, y + 0.8, z - 10),
			rgb(60, 60, 60),
			M.Metal
		)
	end
end

-- A white trig pillar on the highest point well away from the mast
local function buildTrigPillar(ground: Instance)
	local best, bx, bz = -math.huge, 0, 0
	for i = I0 + 4, I1 - 1 do
		for j = EDGE_INDEX + 1, J1 - 1 do
			local h = height(i, j)
			local x, z = i * CELL, j * CELL
			if h > best and math.abs(x - CityHills.SUMMIT[1]) > 600 then
				best, bx, bz = h, x, z
			end
		end
	end
	local model = pieceModel(ground, "TrigPillar")
	local y = CityHills.surface(bx, bz)
	part(model, "TrigPillar", Vector3.new(2.4, 5, 2.4), at(bx, y + 2, bz), rgb(226, 224, 216), M.Concrete)
	part(model, "TrigCap", Vector3.new(1.6, 0.4, 1.6), at(bx, y + 4.7, bz), rgb(120, 120, 116), M.Metal)
end

function CityHills.build(ground: Instance, origin: Vector3)
	center = origin
	local cells: { [number]: { [number]: Cell } } = {}
	for i = I0, I1 - 1 do
		cells[i] = {}
		for j = J0, J1 - 1 do
			if cellExists(i, j) then
				cells[i][j] = classify(i, j)
			end
		end
	end
	local function cellAt(i: number, j: number): Cell?
		return cells[i] and cells[i][j]
	end

	buildTrack(ground)
	buildSummit(ground)
	buildTrigPillar(ground)
	task.wait()
	CityCircuit.build(ground, origin, CityHills.surface)
	task.wait()

	local farms = 0
	for bi = I0, I1 - 1, BLOCK do
		for bj = J0, J1 - 1, BLOCK do
			local block: Model? = nil
			local slopes: { Model } = {}
			local facets = 0
			-- The facets first, so only they are marked to stand in the distant shell. Split
			-- cells under the circuit have many more, so a block may need several pieces.
			for i = bi, math.min(bi + BLOCK, I1) - 1 do
				for j = bj, math.min(bj + BLOCK, J1) - 1 do
					local cell = cellAt(i, j)
					if not cell then
						continue
					end
					for k, tri in triangles(i, j) do
						if not block or facets >= 150 then
							block = pieceModel(ground, "HillSlope")
							table.insert(slopes, block :: Model)
							facets = 0
						end
						facets += 2
						local a, b, c = tri[1], tri[2], tri[3]
						if cell.kind == "circuit" and hidden(a, b, c) then
							continue
						end
						local color, material = faceStyle(a, b, c, cell, i * 131 + j * 17 + k)
						local below = center + (a + b + c) / 3 - Vector3.new(0, 60, 0)
						LowPoly.triangle(center + a, center + b, center + c, below, color, block :: Model, material, 1)
					end
				end
			end
			if not block then
				continue
			end
			for _, slope in slopes do
				for _, w in slope:GetChildren() do
					w:SetAttribute("LodKeep", true)
				end
			end

			-- Then what grows and stands on them
			for i = bi, math.min(bi + BLOCK, I1) - 1 do
				for j = bj, math.min(bj + BLOCK, J1) - 1 do
					local cell = cellAt(i, j)
					if not cell then
						continue
					end
					local x0, z0 = i * CELL, j * CELL
					local seed = i * 211 + j * 37
					if cell.kind == "wood" then
						for k = 1, 2 + (if hash(i, j, 52) < 0.5 then 1 else 0) do
							local x = x0 + 6 + hash(i, j, 53 + k) * (CELL - 12)
							local z = z0 + 6 + hash(j, i, 57 + k) * (CELL - 12)
							if clear(x, z, 10, 8) then
								local y = CityHills.surface(x, z)
								local scale = 0.5 + hash(x, z, 61) * 0.9
								if y > 150 or (y > 90 and hash(x, z, 62) < 0.6) then
									pine(block :: Model, x, z, scale, seed + k)
								else
									broadleaf(block :: Model, x, z, scale, seed + k)
								end
							end
						end
					elseif cell.kind == "field" and cell.crop then
						local low, high = math.huge, -math.huge
						for _, v in { vertex(i, j), vertex(i + 1, j), vertex(i, j + 1), vertex(i + 1, j + 1) } do
							low, high = math.min(low, v.Y), math.max(high, v.Y)
						end
						local cx, cz = x0 + CELL / 2, z0 + CELL / 2
						local farmed = false
						if farms < 8 and high - low < 12 and hash(i, j, 81) < 0.07 and clear(cx, cz, 40, 40) then
							farms += 1
							farmed = true
							farm(block :: Model, cx, cz, low, high, seed)
						end
						if cell.crop[3] == "pasture" and not farmed then
							for k = 1, 3 do
								if hash(i, j, 72 + k) < 0.7 then
									local x = x0 + 8 + hash(i, j, 75 + k) * (CELL - 16)
									local z = z0 + 8 + hash(j, i, 78 + k) * (CELL - 16)
									if clear(x, z, 8, 6) then
										sheep(block :: Model, x, z, seed + k)
									end
								end
							end
						end
						-- Hedges where the field meets a different one or open ground
						for _, side in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
							local other = cellAt(i + side[1], j + side[2])
							local neighbourField = other and other.kind == "field"
							if
								neighbourField and (side[1] < 0 or side[2] < 0 or (other :: Cell).parcel == cell.parcel)
							then
								continue
							end
							local a, b
							if side[1] ~= 0 then
								local ei = if side[1] > 0 then i + 1 else i
								a, b = vertex(ei, j), vertex(ei, j + 1)
							else
								local ej = if side[2] > 0 then j + 1 else j
								a, b = vertex(i, ej), vertex(i + 1, ej)
							end
							local gap = hash(a.X, a.Z, 83) < 0.12
							local crossing = false
							for t = 0, 1, 0.125 do
								local p = a:Lerp(b, t)
								if not clear(p.X, p.Z, TRACK_WIDTH, 4) then
									crossing = true
								end
							end
							if not gap and not crossing then
								hedge(block :: Model, a, b)
								if hash(a.X, a.Z, 84) < 0.18 then
									broadleaf(block :: Model, a.X, a.Z, 0.35, seed)
								end
							end
						end
					end
					-- Tors on the open tops
					local v = vertex(i, j)
					if v.Y > 150 and cell.kind ~= "wood" and hash(i, j, 91) < 0.08 then
						local x, z = x0 + CELL * 0.3, z0 + CELL * 0.3
						if clear(x, z, 16, 12) then
							tor(block :: Model, x, z, seed)
						end
					end
				end
			end
		end
		task.wait()
	end
end

return CityHills
