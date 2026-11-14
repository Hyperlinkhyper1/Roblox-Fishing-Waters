-- A Grand Prix circuit in the hills behind the city, laid out in the spirit of Spa-Francorchamps.
-- The start straight and the pits sit on the low ground right behind the last suburb road. A
-- tight hairpin at its far end (La Source) turns the lap back along the hillside, which drops
-- into the valley for a flick and a steep compression up the other side (Eau Rouge and
-- Raidillon). A long climbing straight (Kemmel) runs up to Les Combes, where the lap dives into
-- a loop at the back of the range (a fast Malmedy and the Rivage hairpin), then a hairpin
-- (Bruxelles) and a long double-apex left (Pouhon) carry it back down past a fast right
-- (Stavelot) to a final chicane (the bus stop) before the start line.
--
-- Around it: tyre walls in the gravel traps, hoardings along the straights, countdown boards
-- before the braking zones, camera towers and marshal huts, grandstands, and pits with a car,
-- a pit-stop rig and a pit-wall stand for every team, and a paddock of transporters and
-- hospitality units behind them.
--
-- The lap runs clockwise. Its corners are straight lines filleted with circular arcs, sampled
-- every STEP studs. CityHills shapes its facets to the circuit (see CityHills): the track's
-- levels follow the land, smoothed and held to a racing gradient, and the hill vertices under
-- and around it are pinned just below those levels, so the road is cut into the slopes and
-- carried over the dips. Coordinates are relative to the city centre (north is -Z).
local LowPoly = require(script.Parent.LowPoly)

local CityCircuit = {}

local TOP = 8 -- the city's walkable land height (see ModernCity)
local WIDTH = 36
local HALF = WIDTH / 2
local STEP = 2 -- roughly: the spacing is stretched a little so a whole number of samples closes the lap
local GRADE = 0.11 -- steepest climb, and half that through the hairpins
local VERGE = 9 -- grass between the track edge and the barrier
local GRAVEL = 18 -- extra run-off on the outside of the corners
local BLEND = 100 -- how far the reshaped ground takes to fall back to the natural hills
local rgb = Color3.fromRGB
local M = Enum.Material

CityCircuit.WIDTH = WIDTH
CityCircuit.BLEND = BLEND

-- Corner points of the lap, clockwise from the end of the start straight, each with the
-- radius of the arc that rounds it off.
CityCircuit.CORNERS = {
	{ 650, 1287, 36, "La Source" },
	{ 650, 1360, 36, "La Source exit" },
	{ 140, 1380, 150, "Eau Rouge" },
	{ 45, 1368, 60, "Raidillon" },
	{ -70, 1440, 170, "Raidillon crest" },
	{ -500, 1470, 40, "Les Combes" },
	{ -564, 1541, 80, "Malmedy" },
	{ -709, 1545, 42, "Rivage" },
	{ -830, 1452, 45, "Bruxelles" },
	{ -845, 1335, 45, "Bruxelles exit" },
	{ -640, 1342, 220, "Pouhon" },
	{ -470, 1316, 220, "Pouhon second apex" },
	{ -340, 1282, 120, "Stavelot" },
	{ -230, 1284, 25, "Bus Stop" },
	{ -205, 1304, 25, "Bus Stop" },
	{ -170, 1306, 25, "Bus Stop" },
	{ -140, 1287, 25, "Bus Stop exit" },
}

-- Stretch the infield and long straights, retaining the start straight near the
-- city. Corner radii remain independently designed. The west end of the range tapers into the
-- sea (see CityHills), so the lap grows east and deep into the hills to the south instead.
local EAST_STRETCH, WEST_STRETCH, SOUTH_STRETCH = 1.4, 1.1, 2.4
local function stretch(point: { any })
	local dx = point[1] - 200
	point[1] = 200 + dx * (if dx > 0 then EAST_STRETCH else WEST_STRETCH)
	point[2] = 1390 + (point[2] - 1287) * SOUTH_STRETCH
end
for _, corner in CityCircuit.CORNERS do
	stretch(corner)
end

local START_Z = 1390 -- the start straight runs due east along this line
CityCircuit.START_Z = START_Z
CityCircuit.START_X = 200 -- the start/finish line
local PIT_FROM, PIT_TO = -60, 540 -- pit lane, alongside the start straight on its north side
local GARAGES_FROM, GARAGE_WIDTH, GARAGES = 0, 18, 25
local PADDOCK_FROM, PADDOCK_TO = -10, 480
local ACCESS_X = 245 -- the paddock road comes up between two empty plots on the last suburb road
local SUBURB_ROAD_EDGE = 1117 -- south edge of the last suburb road (ModernCity, z = 1110)
-- Across the start straight, northwards from its centreline
local PIT_WALL = HALF + 3 -- inner face of the pit wall
local LANE_IN, LANE_OUT = HALF + 4.5, HALF + 22.5
local GARAGE_FRONT, GARAGE_BACK = HALF + 23.5, HALF + 47.5
local PADDOCK_BACK = HALF + 82
CityCircuit.ACCESS_X = ACCESS_X
CityCircuit.PADDOCK_NORTH = START_Z - PADDOCK_BACK

---------------------------------------------------------------------------------------------------
-- The centreline

local SX, SZ, TX, TZ, SK = {}, {}, {}, {}, {} -- position, unit heading, curvature (+ turns right)
local SH: { number } = {} -- road level, once shaped
local RL: { number }, RR: { number } = {}, {} -- run-off to the left and right of the track
local startFrom, startTo = 0, 0 -- samples of the start straight

do
	local corners = CityCircuit.CORNERS
	local n = #corners
	local arcs = {}
	for k = 1, n do
		local p, c, q = corners[(k - 2) % n + 1], corners[k], corners[k % n + 1]
		local ix, iz = c[1] - p[1], c[2] - p[2]
		local il = math.sqrt(ix * ix + iz * iz)
		local ox, oz = q[1] - c[1], q[2] - c[2]
		local ol = math.sqrt(ox * ox + oz * oz)
		ix, iz, ox, oz = ix / il, iz / il, ox / ol, oz / ol
		local turn = math.atan2(ix * oz - iz * ox, ix * ox + iz * oz)
		arcs[k] = { turn = turn, t = c[3] * math.tan(math.abs(turn) / 2), ix = ix, iz = iz, ox = ox, oz = oz, out = ol }
	end
	local total = 0
	for k = 1, n do
		local a, b = arcs[k], arcs[k % n + 1]
		total += corners[k][3] * math.abs(a.turn) + a.out - a.t - b.t
	end
	STEP = total / math.floor(total / STEP + 0.5)
	local function push(x: number, z: number, tx: number, tz: number, k: number)
		table.insert(SX, x)
		table.insert(SZ, z)
		table.insert(TX, tx)
		table.insert(TZ, tz)
		table.insert(SK, k)
	end
	local carry = 0
	for k = 1, n do
		local c, a, b = corners[k], arcs[k], arcs[k % n + 1]
		assert(a.t + b.t <= a.out + 1e-6, "Circuit corners overlap after " .. c[4])
		-- Round the corner, turning about a centre on the inside
		local side = if a.turn > 0 then 1 else -1
		local sx, sz = c[1] - a.ix * a.t, c[2] - a.iz * a.t
		local r = c[3]
		local cx, cz = sx - a.iz * side * r, sz + a.ix * side * r
		local length = r * math.abs(a.turn)
		local d = carry
		while d < length do
			local angle = d / r * side
			local co, si = math.cos(angle), math.sin(angle)
			local rx, rz = sx - cx, sz - cz
			push(cx + rx * co - rz * si, cz + rx * si + rz * co, a.ix * co - a.iz * si, a.ix * si + a.iz * co, side / r)
			d += STEP
		end
		carry = d - length
		-- Then straight on to the next corner
		local ex, ez = c[1] + a.ox * a.t, c[2] + a.oz * a.t
		local straight = a.out - a.t - b.t
		d = carry
		if k == n then
			startFrom = #SX + 1
		end
		while d < straight do
			push(ex + a.ox * d, ez + a.oz * d, a.ox, a.oz, 0)
			d += STEP
		end
		if k == n then
			startTo = #SX
		end
		carry = d - straight
	end
end
-- Rounding can leave one extra sample right on top of the first
if (SX[#SX] - SX[1]) ^ 2 + (SZ[#SZ] - SZ[1]) ^ 2 < (STEP / 2) ^ 2 then
	for _, list in { SX, SZ, TX, TZ, SK } do
		table.remove(list)
	end
	startTo = math.min(startTo, #SX)
end
local COUNT = #SX
CityCircuit.LENGTH = COUNT * STEP

local function wrap(k: number): number
	return (k - 1) % COUNT + 1
end

-- Spatial index of the samples, for nearest-point lookups
local CELL = 40
local index: { [number]: { number } } = {}
local function key(cx: number, cz: number): number
	return (cx + 1000) * 4000 + (cz + 1000)
end
for k = 1, COUNT do
	local id = key(math.floor(SX[k] / CELL), math.floor(SZ[k] / CELL))
	local list = index[id]
	if not list then
		list = {}
		index[id] = list
	end
	table.insert(list, k)
end

-- The nearest sample within `reach` studs, and its distance
local function nearest(x: number, z: number, reach: number): (number?, number)
	local best, bestK = reach * reach, nil
	local cells = math.ceil(reach / CELL)
	local cx, cz = math.floor(x / CELL), math.floor(z / CELL)
	for i = cx - cells, cx + cells do
		for j = cz - cells, cz + cells do
			local list = index[key(i, j)]
			if list then
				for _, k in list do
					local d = (SX[k] - x) ^ 2 + (SZ[k] - z) ^ 2
					if d < best then
						best, bestK = d, k
					end
				end
			end
		end
	end
	return bestK, math.sqrt(best)
end

-- Signed offset of (x, z) from sample k: positive to the right of the direction of travel
local function offset(k: number, x: number, z: number): number
	return (x - SX[k]) * -TZ[k] + (z - SZ[k]) * TX[k]
end

---------------------------------------------------------------------------------------------------
-- Shaping the levels and the run-off

local function smooth(source: { number }, half: number): { number }
	local w = math.floor(half / STEP)
	local prefix = { [0] = 0 }
	for k = 1, COUNT do
		prefix[k] = prefix[k - 1] + source[k]
	end
	local total = prefix[COUNT]
	local function sum(a: number, b: number): number -- source[a..b], wrapping round the lap
		if a < 1 then
			return total - prefix[a - 1 + COUNT] + prefix[b]
		elseif b > COUNT then
			return total - prefix[a - 1] + prefix[b - COUNT]
		end
		return prefix[b] - prefix[a - 1]
	end
	local out = {}
	for k = 1, COUNT do
		out[k] = sum(k - w, k + w) / (2 * w + 1)
	end
	return out
end

local function sfLevel(x: number): number
	local d = (x - SX[startFrom]) / STEP
	local k = math.clamp(math.floor(d), 0, startTo - startFrom - 1)
	local t = math.clamp(d - k, 0, 1)
	return SH[startFrom + k] + (SH[startFrom + k + 1] - SH[startFrom + k]) * t
end
CityCircuit.startLevel = sfLevel

-- Level ground beside the start straight: the pit lane, the garages and the paddock behind
-- them, as { x0, x1, z0, z1 }
local PADS = {
	{ PIT_FROM - 50, PIT_TO + 50, START_Z - LANE_OUT - 2, START_Z - PIT_WALL },
	{ PADDOCK_FROM, PADDOCK_TO, START_Z - PADDOCK_BACK, START_Z - LANE_OUT - 2 },
}
CityCircuit.PADS = PADS

local shaped = false
-- Fit the circuit to the hills: `terrain(x, z)` is the natural ground height
function CityCircuit.shape(terrain: (number, number) -> number)
	shaped = true
	local natural = {}
	for k = 1, COUNT do
		natural[k] = terrain(SX[k], SZ[k])
	end
	local h = smooth(smooth(natural, 120), 120)
	-- Keep the paddock road drivable even when the hills behind the circuit rise
	-- dramatically. The lap's grade pass eases the approach down to this level.
	local accessLimit = TOP + (START_Z - PADDOCK_BACK - SUBURB_ROAD_EDGE) * 0.3
	for k = startFrom, startTo do
		h[k] = math.min(h[k], accessLimit)
	end
	-- Hold the gradient, gentler through the hairpins
	for _ = 1, 40 do
		local changed = false
		for direction = -1, 1, 2 do
			for step = 1, 2 * COUNT do
				local k = if direction > 0 then wrap(step) else wrap(2 * COUNT - step + 1)
				local before = wrap(k - direction)
				local limit = (if math.abs(SK[k]) > 1 / 70 then GRADE / 2 else GRADE) * STEP
				if h[k] > h[before] + limit then
					h[k] = h[before] + limit
					changed = true
				end
			end
		end
		if not changed then
			break
		end
	end
	-- The start straight climbs evenly, so the pits stand level along it
	for k = startFrom, startTo do
		h[k] = h[startFrom] + (h[startTo] - h[startFrom]) * (k - startFrom) / (startTo - startFrom)
	end
	SH = smooth(h, 30)

	-- Run-off: a verge either side, widening into gravel on the outside of the corners
	local out = {}
	for k = 1, COUNT do
		out[k] = GRAVEL * math.min(1, math.abs(SK[k]) * 140)
	end
	local spread = {}
	for k = 1, COUNT do
		local m = 0
		for d = -12, 25 do
			-- Mostly past the corner, where a car runs wide
			local j = wrap(k - d)
			if SK[j] * SK[k] >= 0 or SK[k] == 0 then
				m = math.max(m, out[j])
			end
		end
		spread[k] = m
	end
	local sideOf = {}
	for k = 1, COUNT do
		-- Which side is the outside of the nearest corner
		local s = 0
		for d = 0, 25 do
			local j = wrap(k - d)
			if SK[j] ~= 0 then
				s = if SK[j] > 0 then -1 else 1
				break
			end
		end
		sideOf[k] = s
	end
	spread = smooth(spread, 16)
	for k = 1, COUNT do
		local left, right = VERGE, VERGE
		if sideOf[k] < 0 then
			left += spread[k]
		elseif sideOf[k] > 0 then
			right += spread[k]
		end
		-- Never past the centre of the corner
		if SK[k] ~= 0 then
			local inside = 1 / math.abs(SK[k]) - HALF - 3
			if SK[k] > 0 then
				right = math.min(right, inside)
			else
				left = math.min(left, inside)
			end
		end
		RL[k], RR[k] = left, right
	end
	-- Where the lap passes close by itself, each part keeps to its half of the gap
	for k = 1, COUNT do
		local cx, cz = math.floor(SX[k] / CELL), math.floor(SZ[k] / CELL)
		for i = cx - 3, cx + 3 do
			for j = cz - 3, cz + 3 do
				for _, other in index[key(i, j)] or {} do
					local apart = math.abs(other - k)
					apart = math.min(apart, COUNT - apart)
					if apart > 70 then
						local dx, dz = SX[other] - SX[k], SZ[other] - SZ[k]
						local d = math.sqrt(dx * dx + dz * dz)
						local cap = d / 2 - HALF - 1
						local side = dx * -TZ[k] + dz * TX[k]
						if side > 0.5 * d then
							RR[k] = math.min(RR[k], cap)
						elseif side < -0.5 * d then
							RL[k] = math.min(RL[k], cap)
						end
					end
				end
			end
		end
	end
	-- Beside the start straight the pit wall stands just off the track
	for k = startFrom, startTo do
		RL[k] = PIT_WALL - HALF
	end
	local smoothL, smoothR = smooth(RL, 6), smooth(RR, 6)
	for k = 1, COUNT do
		RL[k], RR[k] = math.min(RL[k], smoothL[k]), math.min(RR[k], smoothR[k])
	end
end

-- Distance of (x, z) outside the circuit's ground (negative inside it), and the level there.
-- Between two parts of the circuit the level runs from one to the other across the gap, so the
-- bank between them is an even slope rather than a step where the nearer one changes.
function CityCircuit.level(x: number, z: number): (number, number)
	assert(shaped, "CityCircuit.shape first")
	-- The nearest two parts: each pad, and the two nearest stretches of track
	local first, firstLevel, second, secondLevel = math.huge, 0, math.huge, 0
	local function consider(d: number, level: number)
		if d < first then
			first, firstLevel, second, secondLevel = d, level, first, firstLevel
		elseif d < second then
			second, secondLevel = d, level
		end
	end
	for _, pad in PADS do
		local dx = math.max(pad[1] - x, x - pad[2], 0)
		local dz = math.max(pad[3] - z, z - pad[4], 0)
		local d = math.sqrt(dx * dx + dz * dz)
		if dx == 0 and dz == 0 then
			d = -math.min(x - pad[1], pad[2] - x, z - pad[3], pad[4] - z)
		end
		consider(d, sfLevel(math.clamp(x, pad[1], pad[2])))
	end
	local reach = BLEND + HALF + VERGE + GRAVEL
	local k = nearest(x, z, reach)
	if k then
		local function outside(m: number): number
			local d = math.sqrt((SX[m] - x) ^ 2 + (SZ[m] - z) ^ 2)
			return d - HALF - (if offset(m, x, z) > 0 then RR[m] else RL[m])
		end
		consider(outside(k :: number), SH[k :: number])
		-- The nearest sample from another part of the lap
		local other, otherD = nil, reach * reach
		local cells = math.ceil(reach / CELL)
		local cx, cz = math.floor(x / CELL), math.floor(z / CELL)
		for i = cx - cells, cx + cells do
			for j = cz - cells, cz + cells do
				for _, m in index[key(i, j)] or {} do
					local apart = math.abs(m - (k :: number))
					if math.min(apart, COUNT - apart) > 70 then
						local d = (SX[m] - x) ^ 2 + (SZ[m] - z) ^ 2
						if d < otherD then
							other, otherD = m, d
						end
					end
				end
			end
		end
		if other then
			consider(outside(other :: number), SH[other :: number])
		end
	end
	if first <= 0 or second == math.huge then
		return first, firstLevel
	end
	return first, firstLevel + (secondLevel - firstLevel) * first / (first + math.max(second, 0))
end

-- How far (x, z) is from anything of the circuit: the track and its run-off, the pits and
-- paddock, the grandstands. Dressing on the hills keeps clear of it.
local STANDS: { { number } } = {}
function CityCircuit.clearance(x: number, z: number): number
	local d = CityCircuit.level(x, z)
	for _, s in STANDS do
		local dx = math.max(s[1] - x, x - s[2], 0)
		local dz = math.max(s[3] - z, z - s[4], 0)
		d = math.min(d, math.sqrt(dx * dx + dz * dz))
	end
	local ax, az = ACCESS_X, (SUBURB_ROAD_EDGE + START_Z - PADDOCK_BACK) / 2
	if math.abs(x - ax) < 12 and math.abs(z - az) < 60 then
		d = math.min(d, 0)
	end
	return d
end

-- Every point the ground must stay under, with the level it must stay below: the track and its
-- run-off, then the pads
function CityCircuit.eachGroundPoint(callback: (number, number, number) -> ())
	assert(shaped, "CityCircuit.shape first")
	for k = 1, COUNT do
		local nx, nz = -TZ[k], TX[k]
		local left, right = -(HALF + RL[k] + 2), HALF + RR[k] + 2
		local o = left
		while true do
			callback(SX[k] + nx * o, SZ[k] + nz * o, SH[k])
			if o >= right then
				break
			end
			o = math.min(o + 3, right)
		end
	end
	for _, pad in PADS do
		for x = pad[1], pad[2], 3 do
			for z = pad[3], pad[4], 3 do
				callback(x, z, sfLevel(x))
			end
			callback(x, pad[4], sfLevel(x))
		end
	end
end

-- Whether (x, z) is under the asphalt or the slabs of the pit lane, pits and paddock, where
-- nobody can see the ground
function CityCircuit.covered(x: number, z: number): boolean
	local o = START_Z - z
	if x > PIT_FROM + 1 and x < PIT_TO - 1 and o > LANE_IN - 1 and o < LANE_OUT then
		return true
	elseif x > PADDOCK_FROM + 1 and x < PADDOCK_TO - 1 and o > GARAGE_FRONT and o < PADDOCK_BACK - 1 then
		return true
	end
	local k = nearest(x, z, HALF)
	return k ~= nil and math.abs(offset(k :: number, x, z)) < HALF - 1
end

-- Samples as plain data, for the checks
function CityCircuit.samples(): { { number } }
	local out = {}
	for k = 1, COUNT do
		out[k] = { SX[k], SZ[k], SH[k], RL[k], RR[k], SK[k], TX[k], TZ[k] }
	end
	return out
end

---------------------------------------------------------------------------------------------------
-- Building

local center = Vector3.zero
local surface: (number, number) -> number = function()
	return TOP
end

local ASPHALT = rgb(58, 58, 60)
local GRAVEL_COLOR = rgb(192, 178, 144)
local LINE = rgb(232, 232, 228)
local KERB_RED, KERB_WHITE = rgb(196, 40, 36), rgb(236, 234, 228)
local STEEL = rgb(168, 172, 176)
local CONCRETE = rgb(196, 192, 182)
local TEAMS = {
	rgb(200, 30, 36),
	rgb(40, 60, 160),
	rgb(0, 150, 140),
	rgb(240, 120, 20),
	rgb(30, 30, 34),
	rgb(0, 110, 60),
	rgb(230, 200, 40),
	rgb(240, 240, 240),
	rgb(120, 40, 140),
	rgb(90, 160, 220),
}

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

local function pieceModel(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m:AddTag("LodPiece")
	m.Parent = parent
	return m
end

-- A model that starts a new streaming piece once it gets full
local function pieces(parent: Instance, name: string, limit: number): (number?) -> Model
	local model, count = nil :: Model?, 0
	return function(parts: number?)
		if not model or count >= limit then
			model, count = pieceModel(parent, name), 0
		end
		count += parts or 1
		return model :: Model
	end
end

local function world(x: number, y: number, z: number): Vector3
	return center + Vector3.new(x, y, z)
end

-- A box lying from a to b (local coordinates), `width` across and `height` thick
local function span(a: Vector3, b: Vector3): (CFrame, number)
	return CFrame.lookAt(center + (a + b) / 2, center + b), (b - a).Magnitude
end

-- A point across the track at sample k
local function across(k: number, o: number, lift: number?): Vector3
	return Vector3.new(SX[k] - TZ[k] * o, SH[k] + (lift or 0), SZ[k] + TX[k] * o)
end

-- The samples the road surface is built from: close together through corners, far apart
-- along the straights, and wherever the level bends enough to show
local function keySamples(): { number }
	local kept = { 1 }
	local a = 1
	while a < COUNT do
		local b = a + 1
		while b < COUNT do
			local next = b + 1
			if (next - a) * STEP > 40 then
				break
			end
			local turn = TX[a] * TX[next] + TZ[a] * TZ[next]
			if turn < math.cos(math.rad(2)) then
				break
			end
			local bends = false
			for j = a + 1, next - 1 do
				local t = (j - a) / (next - a)
				if math.abs(SH[j] - (SH[a] + (SH[next] - SH[a]) * t)) > 0.12 then
					bends = true
					break
				end
			end
			if bends then
				break
			end
			b = next
		end
		table.insert(kept, b)
		a = b
	end
	return kept
end

local function buildTrack(ground: Instance, kept: { number })
	local surfaceModel = pieces(ground, "CircuitTrack", 200)
	local marks = pieces(ground, "CircuitKerbs", 200)
	local gravel = pieces(ground, "CircuitGravel", 200)
	local kerbCount = 0
	for s = 1, #kept do
		local a, b = kept[s], kept[s % #kept + 1]
		local la, ra, lb, rb = across(a, -HALF), across(a, HALF), across(b, -HALF), across(b, HALF)
		local below = (la + rb) / 2 - Vector3.new(0, 9, 0)
		local model = surfaceModel(4)
		LowPoly.triangle(center + la, center + ra, center + rb, center + below, ASPHALT, model, M.Asphalt, 8)
		LowPoly.triangle(center + la, center + rb, center + lb, center + below, ASPHALT, model, M.Asphalt, 8)
		-- White lines along both edges
		for _, side in { -1, 1 } do
			local p0, p1 = across(a, side * (HALF - 1.2), 0.04), across(b, side * (HALF - 1.2), 0.04)
			local frame, length = span(p0, p1)
			part(marks(), "TrackLine", Vector3.new(0.8, 0.2, length + 0.2), frame, LINE, M.SmoothPlastic, false)
		end
		-- Kerbs through the corners: on the inside, and on the outside of the tight ones
		local bend = math.max(math.abs(SK[a]), math.abs(SK[b]), math.abs(SK[wrap(a - 6)]), math.abs(SK[wrap(b + 6)]))
		if bend > 1 / 320 then
			local turning = SK[a] + SK[b] + SK[wrap(a - 6)] + SK[wrap(b + 6)]
			local inside = if turning > 0 then 1 else -1
			for _, side in { -1, 1 } do
				if side ~= inside and bend < 1 / 160 then
					continue
				end
				local inner, outer = side * (HALF - 1.6), side * (HALF + 2.4)
				local length = (across(b, inner) - across(a, inner)).Magnitude
				local blocks = math.max(1, math.ceil(length / 4.5))
				for i = 0, blocks - 1 do
					local t0, t1 = i / blocks, (i + 1) / blocks
					local function at(t: number, o: number): Vector3
						return across(a, o, 0.2):Lerp(across(b, o, 0.2), t)
					end
					local mid = (at(t0, inner) + at(t1, outer) + at(t0, outer) + at(t1, inner)) / 4
					local ahead = (at(t1, inner) + at(t1, outer)) / 2 - (at(t0, inner) + at(t0, outer)) / 2
					kerbCount += 1
					part(
						marks(),
						"Kerb",
						Vector3.new(4, 0.6, ahead.Magnitude + 0.05),
						CFrame.lookAt(
							center + mid - Vector3.new(0, 0.3, 0),
							center + mid - Vector3.new(0, 0.3, 0) + ahead
						),
						if kerbCount % 2 == 0 then KERB_RED else KERB_WHITE,
						M.SmoothPlastic
					)
				end
			end
		end
		-- Gravel traps from the kerbs out to the barrier wherever the run-off widens
		for _, side in { -1, 1 } do
			local roomA = if side > 0 then RR[a] else RL[a]
			local roomB = if side > 0 then RR[b] else RL[b]
			if math.min(roomA, roomB) > VERGE + 4 then
				local ia, oa = across(a, side * (HALF + 2.4), -0.25), across(a, side * (HALF + roomA - 1.5), -0.25)
				local ib, ob = across(b, side * (HALF + 2.4), -0.25), across(b, side * (HALF + roomB - 1.5), -0.25)
				local under = (ia + ob) / 2 - Vector3.new(0, 6, 0)
				local model = gravel(4)
				LowPoly.triangle(
					center + ia,
					center + oa,
					center + ob,
					center + under,
					GRAVEL_COLOR,
					model,
					M.Pebble,
					2
				)
				LowPoly.triangle(
					center + ia,
					center + ob,
					center + ib,
					center + under,
					GRAVEL_COLOR,
					model,
					M.Pebble,
					2
				)
			end
		end
		if s % 60 == 0 then
			task.wait()
		end
	end
end

-- Armco on both sides at the edge of the run-off, standing on the ground
local function buildBarriers(ground: Instance, kept: { number })
	local model = pieces(ground, "CircuitBarrier", 200)
	for _, side in { -1, 1 } do
		local last: Vector3? = nil
		for s = 1, #kept + 1 do
			local k = kept[(s - 1) % #kept + 1]
			local room = if side > 0 then RR[k] else RL[k]
			local pit = side < 0 and k >= startFrom and k <= startTo
			if room < 5 or pit then
				last = nil
				continue
			end
			local o = side * (HALF + room)
			local x, z = SX[k] - TZ[k] * o, SZ[k] + TX[k] * o
			local here = Vector3.new(x, surface(x, z), z)
			-- A post at every other joint (and at each end) holds the rails up
			if not last or s % 2 == 0 then
				part(
					model(),
					"BarrierPost",
					Vector3.new(0.5, 2.6, 0.5),
					CFrame.new(center + here + Vector3.new(0, 0.8, 0)),
					STEEL,
					M.Metal
				)
			end
			if last then
				local a, b = (last :: Vector3) + Vector3.new(0, 1.6, 0), here + Vector3.new(0, 1.6, 0)
				local frame, length = span(a, b)
				if length > 0.5 and length < 60 then
					part(model(), "Armco", Vector3.new(0.4, 1.1, length + 0.4), frame, STEEL, M.DiamondPlate)
				end
			end
			last = here
		end
		task.wait()
	end
end

-- An S/F-aligned frame: x along the start straight, `o` studs north of its centreline, `lift`
-- above the straight's level there
local function sfFrame(x0: number, x1: number, o: number, lift: number): (CFrame, number)
	local a = Vector3.new(x0, sfLevel(x0) + lift, START_Z - o)
	local b = Vector3.new(x1, sfLevel(x1) + lift, START_Z - o)
	return span(a, b)
end

local function sfBox(
	parent: Instance,
	name: string,
	x0: number,
	x1: number,
	o0: number,
	o1: number,
	y0: number,
	y1: number,
	color: Color3,
	material: Enum.Material,
	collidable: boolean?
): Part
	local frame, length = sfFrame(x0, x1, (o0 + o1) / 2, (y0 + y1) / 2)
	return part(parent, name, Vector3.new(math.abs(o1 - o0), y1 - y0, length), frame, color, material, collidable)
end

local function buildStart(ground: Instance)
	local model = pieceModel(ground, "CircuitStart")
	local x = CityCircuit.START_X
	local y = sfLevel(x)
	-- Chequered line
	for row = 0, 1 do
		for i = 0, WIDTH / 2 - 1 do
			local o = -HALF + 1 + i * 2
			part(
				model,
				"StartLine",
				Vector3.new(2, 0.2, 2),
				CFrame.new(world(x - 1 + row * 2, y + 0.05, START_Z + o)),
				if (i + row) % 2 == 0 then rgb(20, 20, 20) else LINE,
				M.SmoothPlastic,
				false
			)
		end
	end
	-- The grid: staggered slots behind the line
	for slot = 0, 19 do
		local gx = x - 12 - slot * 10
		local o = if slot % 2 == 0 then -6 else 6
		part(
			model,
			"GridSlot",
			Vector3.new(0.8, 0.2, 7),
			CFrame.new(world(gx, sfLevel(gx) + 0.05, START_Z + o)),
			LINE,
			M.SmoothPlastic,
			false
		)
		for _, side in { -1, 1 } do
			part(model, "GridSlotSide", Vector3.new(5, 0.2, 0.6),
				CFrame.new(world(gx - 2.5, sfLevel(gx - 2.5) + 0.05, START_Z + o + side * 3.2)),
				LINE, M.SmoothPlastic, false)
		end
	end
	-- Start gantry with its row of lights
	local gx = x + 6
	for _, o in { -(HALF + 2), HALF + 2 } do
		part(
			model,
			"GantryPost",
			Vector3.new(1.4, 20, 1.4),
			CFrame.new(world(gx, y + 9, START_Z + o)),
			rgb(60, 62, 66),
			M.Metal
		)
	end
	part(
		model,
		"Gantry",
		Vector3.new(2, 3, WIDTH + 6),
		CFrame.new(world(gx, y + 18, START_Z)),
		rgb(40, 42, 46),
		M.Metal
	)
	for i = -2, 2 do
		local light = part(
			model,
			"StartLight",
			Vector3.new(0.6, 1.4, 1.4),
			CFrame.new(world(gx - 1.1, y + 18, START_Z + i * 3.4)),
			rgb(255, 30, 24),
			M.Neon,
			false
		)
		light:SetAttribute("StartLight", i + 3)
	end
end

local function buildPits(ground: Instance)
	local lane = pieceModel(ground, "CircuitPitLane")
	-- Pit lane alongside the straight, joined to the track at both ends
	for x0 = PIT_FROM, PIT_TO - 1, 60 do
		local x1 = math.min(x0 + 60, PIT_TO)
		sfBox(lane, "PitLane", x0, x1 + 0.2, LANE_IN - 1.5, LANE_OUT + 1, -2, 0, ASPHALT, M.Asphalt)
		sfBox(lane, "PitLaneLine", x0, x1, LANE_OUT - 6, LANE_OUT - 5.4, 0, 0.1, LINE, M.SmoothPlastic, false)
		sfBox(lane, "PitWall", x0, x1, PIT_WALL, PIT_WALL + 1.5, -1, 3.2, CONCRETE, M.Concrete)
		local fence =
			sfBox(lane, "PitFence", x0, x1, PIT_WALL + 0.5, PIT_WALL + 0.7, 3.2, 9, rgb(90, 96, 100), M.Metal, false)
		fence.Transparency = 0.65
	end
	for _, ends in { { PIT_FROM - 55, PIT_FROM, 1 }, { PIT_TO, PIT_TO + 55, -1 } } do
		-- A slip road from the track edge into the lane
		local inner = (LANE_IN + LANE_OUT) / 2
		local fromO, toO = if ends[3] > 0 then HALF - 4 else inner, if ends[3] > 0 then inner else HALF - 4
		local a = Vector3.new(ends[1], sfLevel(ends[1]) - 0.85, START_Z - fromO)
		local b = Vector3.new(ends[2], sfLevel(ends[2]) - 0.85, START_Z - toO)
		local frame, length = span(a, b)
		part(lane, "PitSlip", Vector3.new(12, 1.5, length + 6), frame, ASPHALT, M.Asphalt)
	end
	task.wait()

	-- Garages under offices and a roof terrace, a race control tower over the start line
	local building = pieceModel(ground, "PitBuilding")
	local x0, x1 = GARAGES_FROM, GARAGES_FROM + GARAGES * GARAGE_WIDTH
	-- Solid down to below the mainland, so the paddock reads as a raised terrace from the town
	local drop = math.max(sfLevel(PADDOCK_FROM), sfLevel(PADDOCK_TO)) - TOP + 3
	sfBox(building, "PitFloor", x0, x1, GARAGE_FRONT - 1, PADDOCK_BACK, -drop, 0, CONCRETE, M.Concrete)
	sfBox(building, "GarageBack", x0, x1, GARAGE_BACK - 1, GARAGE_BACK, 0, 8, rgb(222, 222, 218), M.SmoothPlastic)
	sfBox(
		building,
		"GarageInterior",
		x0,
		x1,
		GARAGE_BACK - 1.4,
		GARAGE_BACK - 1,
		0.5,
		7,
		rgb(44, 46, 50),
		M.SmoothPlastic,
		false
	)
	sfBox(building, "OfficeFloor", x0, x1, GARAGE_FRONT, GARAGE_BACK, 8, 9, rgb(222, 222, 218), M.Concrete)
	sfBox(building, "OfficeGlass", x0, x1, GARAGE_FRONT + 0.2, GARAGE_FRONT + 0.8, 9, 14, rgb(110, 150, 180), M.Glass)
	sfBox(building, "OfficeBack", x0, x1, GARAGE_BACK - 1, GARAGE_BACK, 9, 14, rgb(222, 222, 218), M.SmoothPlastic)
	sfBox(
		building,
		"PitRoof",
		x0 - 1,
		x1 + 1,
		GARAGE_FRONT - 7,
		GARAGE_BACK + 1,
		14,
		15,
		rgb(236, 236, 232),
		M.SmoothPlastic
	)
	sfBox(building, "RoofRail", x0, x1, GARAGE_FRONT - 6.6, GARAGE_FRONT - 6.2, 15, 18, rgb(90, 96, 100), M.Metal).Transparency =
		0.5
	for g = 0, GARAGES do
		local gx = x0 + g * GARAGE_WIDTH
		sfBox(
			building,
			"GarageWall",
			gx - 0.4,
			gx + 0.4,
			GARAGE_FRONT,
			GARAGE_BACK - 1,
			0,
			8,
			rgb(230, 230, 226),
			M.SmoothPlastic
		)
		if g < GARAGES then
			local team = TEAMS[g // 2 % #TEAMS + 1]
			sfBox(
				building,
				"TeamBoard",
				gx + 2,
				gx + GARAGE_WIDTH - 2,
				GARAGE_FRONT - 0.3,
				GARAGE_FRONT,
				6.2,
				7.8,
				team,
				M.SmoothPlastic,
				false
			)
			sfBox(
				building,
				"GarageDoor",
				gx + 1,
				gx + GARAGE_WIDTH - 1,
				GARAGE_FRONT + 0.2,
				GARAGE_FRONT + 0.6,
				5.2,
				6.2,
				rgb(150, 154, 160),
				M.Metal,
				false
			)
		end
	end
	-- Individual working pit boxes: painted stops on the apron, team-coloured
	-- fascia, tool cabinets, timing screens and spare tyres inside each garage.
	-- In their own streaming pieces, so the pit building stays within its part budget
	local boxes = pieces(ground, "PitBoxes", 200)
	for g = 0, GARAGES - 1 do
		local gx = x0 + g * GARAGE_WIDTH
		local team = TEAMS[g // 2 % #TEAMS + 1]
		local box = boxes(10)
		sfBox(box, "PitBoxBackLine", gx + 2, gx + GARAGE_WIDTH - 2, LANE_OUT - 4, LANE_OUT - 3.5, 0.06, 0.16, LINE, M.SmoothPlastic, false)
		for _, side in { 2, GARAGE_WIDTH - 2.5 } do
			sfBox(box, "PitBoxSideLine", gx + side, gx + side + 0.5, LANE_OUT - 4, GARAGE_FRONT - 0.2, 0.06, 0.16, LINE, M.SmoothPlastic, false)
		end
		sfBox(box, "PitStopMark", gx + GARAGE_WIDTH / 2 - 1.5, gx + GARAGE_WIDTH / 2 + 1.5, LANE_OUT - 3, LANE_OUT - 2.5, 0.08, 0.18, team, M.SmoothPlastic, false)
		sfBox(box, "GarageFloorMark", gx + 1, gx + GARAGE_WIDTH - 1, GARAGE_BACK - 4, GARAGE_BACK - 3.6, 0.06, 0.16, team, M.SmoothPlastic, false)
		sfBox(box, "ToolCabinet", gx + 1, gx + 3.5, GARAGE_BACK - 4, GARAGE_BACK - 1.5, 0, 3.2, team, M.Metal)
		sfBox(box, "TimingScreen", gx + 1.2, gx + 3.3, GARAGE_BACK - 2, GARAGE_BACK - 1.4, 3.5, 5.2, rgb(25, 35, 43), M.SmoothPlastic, false)
		for tire = 0, 2 do
			sfBox(box, "SpareTyre", gx + GARAGE_WIDTH - 4.2, gx + GARAGE_WIDTH - 1.6, GARAGE_BACK - 4.5, GARAGE_BACK - 1.9, tire * 1.1, tire * 1.1 + 1, rgb(28, 29, 31), M.Rubber)
		end
	end
	-- Race control over the start line, with the podium balcony facing the straight
	local tx = CityCircuit.START_X
	sfBox(
		building,
		"RaceControl",
		tx - 14,
		tx + 14,
		GARAGE_FRONT + 2,
		GARAGE_BACK - 2,
		15,
		24,
		rgb(236, 236, 232),
		M.SmoothPlastic
	)
	sfBox(
		building,
		"RaceControlGlass",
		tx - 13,
		tx + 13,
		GARAGE_FRONT + 1.6,
		GARAGE_FRONT + 2.2,
		17,
		23,
		rgb(90, 130, 160),
		M.Glass
	)
	sfBox(
		building,
		"RaceControlRoof",
		tx - 15,
		tx + 15,
		GARAGE_FRONT + 1,
		GARAGE_BACK - 1,
		24,
		25,
		rgb(60, 62, 66),
		M.Metal
	)
	for i, step in { { -2, 2, 3 }, { -6, -2, 2 }, { 2, 6, 1 } } do
		sfBox(
			building,
			"Podium",
			tx + step[1],
			tx + step[2],
			GARAGE_FRONT - 3,
			GARAGE_FRONT,
			15,
			15 + step[3] * 0.8,
			({ rgb(212, 175, 55), rgb(192, 192, 196), rgb(176, 112, 64) })[i],
			M.SmoothPlastic
		)
	end
	task.wait()

	-- Paddock behind the garages: a raised apron with the team transporters lined up
	local paddock = pieceModel(ground, "Paddock")
	sfBox(paddock, "PaddockApron", PADDOCK_FROM, x0, GARAGE_FRONT - 1, PADDOCK_BACK, -drop, 0, CONCRETE, M.Concrete)
	sfBox(paddock, "PaddockApron", x1, PADDOCK_TO, GARAGE_FRONT - 1, PADDOCK_BACK, -drop, 0, CONCRETE, M.Concrete)
	sfBox(
		paddock,
		"PaddockRail",
		PADDOCK_FROM,
		PADDOCK_TO,
		PADDOCK_BACK - 0.6,
		PADDOCK_BACK,
		0,
		3,
		rgb(90, 96, 100),
		M.Metal
	)
	for t = 0, 9 do
		local px = x0 + 18 + t * 38
		if math.abs(px - ACCESS_X) < 20 then
			continue
		end
		local team = TEAMS[t % #TEAMS + 1]
		sfBox(
			paddock,
			"Transporter",
			px - 3.5,
			px + 3.5,
			GARAGE_BACK + 8,
			GARAGE_BACK + 28,
			1,
			9,
			team,
			M.SmoothPlastic
		)
		sfBox(
			paddock,
			"TransporterCab",
			px - 3.5,
			px + 3.5,
			GARAGE_BACK + 28,
			GARAGE_BACK + 34,
			0.5,
			7.5,
			rgb(40, 42, 46),
			M.SmoothPlastic
		)
	end
	-- The road up from the last suburb road, on an embankment
	local top = sfLevel(ACCESS_X)
	local north, south = SUBURB_ROAD_EDGE - 1, START_Z - PADDOCK_BACK + 1
	local a = Vector3.new(ACCESS_X, TOP + 0.2, north)
	local b = Vector3.new(ACCESS_X, top, south)
	local frame, length = span(a, b)
	part(paddock, "PaddockRoad", Vector3.new(14, 0.6, length), frame * CFrame.new(0, -0.3, 0), ASPHALT, M.Asphalt)
	local bank = Instance.new("WedgePart")
	bank.Name = "PaddockRoadBank"
	bank.Anchored = true
	bank.Size = Vector3.new(14, top - TOP, south - north)
	-- A wedge is full height at its back (+Z, south here) and slopes down to its front
	bank.CFrame = CFrame.new(world(ACCESS_X, TOP + (top - TOP) / 2 - 0.6, (north + south) / 2))
	bank.Color = rgb(104, 122, 74)
	bank.Material = M.Grass
	bank.Parent = paddock
end

-- Stepped stands built into the slope, each row a solid block down to the ground
local function standSection(model: Model, from: Vector3, to: Vector3, rows: number, roofed: boolean, seat: Color3)
	local along = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = along.Magnitude
	along = along.Unit
	local back = Vector3.new(along.Z, 0, -along.X) -- rows climb away to the left of from -> to
	local DEPTH, RISE = 3, 1.4
	-- Each row at least a step above the last and clear of the ground under it, so the stand
	-- climbs with the hillside instead of standing on a wall
	local tops, lows = {}, {}
	local last = -math.huge
	for r = 0, rows - 1 do
		local high, low = -math.huge, math.huge
		for t = 0, length, 8 do
			for _, d in { r * DEPTH, (r + 1) * DEPTH } do
				local p = from + along * t + back * d
				local y = surface(p.X, p.Z)
				high, low = math.max(high, y), math.min(low, y)
			end
		end
		last = math.max(last + RISE, high + 0.8)
		tops[r], lows[r] = last, low
	end
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for r = 0, rows - 1 do
		local top = tops[r]
		local mid = from + along * (length / 2) + back * ((r + 0.5) * DEPTH)
		local height = top - lows[r] + 2
		local frame = CFrame.lookAt(
			world(mid.X, top - height / 2, mid.Z),
			world(mid.X + along.X, top - height / 2, mid.Z + along.Z)
		)
		part(model, "StandStep", Vector3.new(DEPTH, height, length), frame, CONCRETE, M.Concrete)
		part(
			model,
			"StandSeats",
			Vector3.new(1.2, 1, length - 2),
			frame * CFrame.new(-0.6, height / 2 + 0.5, 0),
			seat,
			M.SmoothPlastic
		)
		for _, corner in { from + back * (r * DEPTH), to + back * ((r + 1) * DEPTH) } do
			minX, maxX = math.min(minX, corner.X), math.max(maxX, corner.X)
			minZ, maxZ = math.min(minZ, corner.Z), math.max(maxZ, corner.Z)
		end
	end
	if roofed then
		local depth = rows * DEPTH
		local top = tops[rows - 1] + 9
		for _, t in { 4, length / 2, length - 4 } do
			local p = from + along * t + back * (depth - 1)
			local y = surface(p.X, p.Z)
			part(
				model,
				"StandColumn",
				Vector3.new(1, top - y, 1),
				CFrame.new(world(p.X, (top + y) / 2, p.Z)),
				rgb(220, 220, 216),
				M.Metal
			)
		end
		local mid = from + along * (length / 2) + back * (depth / 2)
		local frame = CFrame.lookAt(world(mid.X, top, mid.Z), world(mid.X + along.X, top, mid.Z + along.Z))
		part(
			model,
			"StandRoof",
			Vector3.new(depth + 6, 0.8, length + 2),
			frame * CFrame.new(-3, 0, 0) * CFrame.Angles(0, 0, -0.08),
			rgb(236, 236, 232),
			M.SmoothPlastic
		)
	end
	table.insert(STANDS, { minX, maxX, minZ, maxZ })
end

-- A stand in short sections with stairs between, each fitted to its own patch of hillside
local function grandstand(
	ground: Instance,
	name: string,
	from: Vector3,
	to: Vector3,
	rows: number,
	roofed: boolean,
	seat: Color3
)
	local model = pieceModel(ground, name)
	local length = (to - from).Magnitude
	local sections = math.ceil(length / 45)
	for i = 0, sections - 1 do
		local a = from:Lerp(to, i / sections)
		local b = from:Lerp(to, (i + 1) / sections)
		local trim = (b - a).Unit * 1.5
		standSection(model, if i > 0 then a + trim else a, if i < sections - 1 then b - trim else b, rows, roofed, seat)
	end
end

-- Grandstands where the views are, as front-edge endpoints (rows climb to the left of a -> b)
CityCircuit.GRANDSTANDS = {
	{ "MainGrandstand", { 540, 1386 }, { 290, 1391 }, 12, true, rgb(30, 60, 150) },
	{ "EauRougeGrandstand", { 250, 1418 }, { 160, 1418 }, 10, false, rgb(200, 40, 40) },
	{ "BusStopGrandstand", { -120, 1330 }, { -240, 1330 }, 7, false, rgb(240, 190, 30) },
}

for _, stand in CityCircuit.GRANDSTANDS do
	for _, endpoint in { stand[2], stand[3] } do
		stretch(endpoint)
	end
end
-- Across the start straight from the pits, behind the debris fence (already in final coordinates)
table.insert(
	CityCircuit.GRANDSTANDS,
	{ "PitGrandstand", { 480, START_Z + HALF + VERGE + 5 }, { 250, START_Z + HALF + VERGE + 5 }, 8, true, rgb(236, 236, 232) }
)

-- An arched footbridge over the track, like the one over the climb out of the valley
local function footbridge(ground: Instance, k: number)
	local model = pieceModel(ground, "CircuitBridge")
	local deck = SH[k] + 18
	local ends = {}
	for _, side in { -1, 1 } do
		-- Each tower stands just behind the barrier on its side
		local p = across(k, side * (HALF + (if side > 0 then RR[k] else RL[k]) + 5))
		local y = surface(p.X, p.Z)
		part(
			model,
			"BridgeTower",
			Vector3.new(6, deck - y + 2, 6),
			CFrame.new(world(p.X, (deck + y) / 2, p.Z)),
			rgb(220, 220, 216),
			M.Concrete
		)
		table.insert(ends, Vector3.new(p.X, deck + 0.5, p.Z))
	end
	local frame, length = span(ends[1], ends[2])
	part(model, "BridgeDeck", Vector3.new(6, 1, length + 6), frame, rgb(220, 220, 216), M.Concrete)
	for _, side in { -1, 1 } do
		part(
			model,
			"BridgeBanner",
			Vector3.new(0.4, 4, length - 4),
			frame * CFrame.new(side * 3.2, -2.4, 0),
			rgb(240, 200, 30),
			M.SmoothPlastic
		)
		part(
			model,
			"BridgeStripe",
			Vector3.new(0.5, 1, length - 4),
			frame * CFrame.new(side * 3.25, -2.4, 0),
			rgb(30, 60, 150),
			M.SmoothPlastic
		)
	end
end

-- Marshal huts outside the corners
local function marshals(ground: Instance)
	local model = pieceModel(ground, "CircuitMarshals")
	for i, corner in CityCircuit.CORNERS do
		if i % 2 == 0 and i ~= 2 then
			continue
		end
		local k = nearest(corner[1], corner[2], 200)
		if not k then
			continue
		end
		local side = if SK[k :: number] > 0 then -1 else 1
		local room = if side > 0 then RR[k :: number] else RL[k :: number]
		if room < 6 then
			continue
		end
		local p = across(k :: number, side * (HALF + room + 5))
		local y = surface(p.X, p.Z)
		part(
			model,
			"MarshalHut",
			Vector3.new(4, 3.5, 4),
			CFrame.new(world(p.X, y + 1.5, p.Z)),
			rgb(236, 236, 232),
			M.SmoothPlastic
		)
		part(
			model,
			"MarshalRoof",
			Vector3.new(4.6, 0.5, 4.6),
			CFrame.new(world(p.X, y + 3.5, p.Z)),
			rgb(240, 120, 20),
			M.SmoothPlastic
		)
		part(
			model,
			"MarshalFlag",
			Vector3.new(0.2, 1.4, 2),
			CFrame.new(world(p.X, y + 5.2, p.Z)),
			rgb(240, 200, 30),
			M.Fabric,
			false
		)
	end
end

-- A part that lights up after dark (see CityNightLights)
local function glow(p: BasePart, color: Color3, at: number): BasePart
	p:AddTag("NightGlow")
	p:SetAttribute("GlowColor", color)
	p:SetAttribute("GlowAt", at)
	return p
end

-- Keeps the hills' trees and farms off a prop's footprint
local function claim(x: number, z: number, reach: number)
	table.insert(STANDS, { x - reach, x + reach, z - reach, z + reach })
end

local HOARDINGS = {
	rgb(200, 30, 36),
	rgb(236, 236, 232),
	rgb(30, 60, 150),
	rgb(240, 190, 30),
	rgb(0, 130, 90),
	rgb(30, 30, 34),
	rgb(240, 120, 20),
}

-- Along the barriers: tyre walls in front of the armco wherever a gravel trap opens up,
-- advertising hoardings behind it on the straights, and a debris fence along the start straight
-- facing the pits
local function buildTrackside(ground: Instance, kept: { number })
	local tyres = pieces(ground, "CircuitTyreWall", 200)
	local boards = pieces(ground, "CircuitHoarding", 200)
	local boardCount = 0
	local function onGround(k: number, o: number, lift: number): Vector3
		local x, z = SX[k] - TZ[k] * o, SZ[k] + TX[k] * o
		return Vector3.new(x, surface(x, z) + lift, z)
	end
	for _, side in { -1, 1 } do
		local lastK: number? = nil
		local belt = 0
		for s = 1, #kept + 1 do
			local k = kept[(s - 1) % #kept + 1]
			local room = if side > 0 then RR[k] else RL[k]
			local pit = side < 0 and k >= startFrom and k <= startTo
			if room < 5 or pit then
				lastK = nil
				continue
			end
			if lastK then
				local j = lastK :: number
				local roomJ = if side > 0 then RR[j] else RL[j]
				local straight = SK[j] == 0 and SK[k] == 0
				local start = side > 0 and k >= startFrom and k <= startTo and j >= startFrom
				if math.min(room, roomJ) > VERGE + 8 then
					-- Tyres stacked three high just inside the armco, with a coloured belt over them
					local a, b = onGround(j, side * (HALF + roomJ - 1.4), 1.2), onGround(k, side * (HALF + room - 1.4), 1.2)
					local frame, length = span(a, b)
					if length > 0.5 and length < 60 then
						belt += 1
						part(tyres(2), "TyreWall", Vector3.new(1.8, 2.4, length + 0.3), frame, rgb(26, 26, 28), M.Rubber)
						part(
							tyres(),
							"TyreWallBelt",
							Vector3.new(1.9, 0.9, length + 0.3),
							frame * CFrame.new(0, 0.5, 0),
							if belt % 2 == 0 then KERB_RED else KERB_WHITE,
							M.SmoothPlastic,
							false
						)
					end
				elseif start then
					-- Debris fence on posts along the straight, in front of the pit grandstand
					local a, b = onGround(j, side * (HALF + roomJ + 0.6), 6.5), onGround(k, side * (HALF + room + 0.6), 6.5)
					local frame, length = span(a, b)
					if length > 0.5 and length < 60 then
						local fence = part(
							boards(2),
							"CatchFence",
							Vector3.new(0.2, 8, length + 0.2),
							frame,
							rgb(90, 96, 100),
							M.Metal,
							false
						)
						fence.Transparency = 0.6
						part(boards(), "CatchFencePost", Vector3.new(0.5, 11, 0.5), CFrame.new(center + b - Vector3.new(0, 1.5, 0)), STEEL, M.Metal)
					end
				elseif straight then
					-- A hoarding standing just behind the armco, facing the track
					local a, b = onGround(j, side * (HALF + roomJ + 0.8), 0.6), onGround(k, side * (HALF + room + 0.8), 0.6)
					local frame, length = span(a, b)
					if length > 4 and length < 60 then
						boardCount += 1
						part(
							boards(),
							"Hoarding",
							Vector3.new(0.3, 5, length - 0.6), -- sunk well into the ground, which sags between joints
							frame,
							HOARDINGS[boardCount % #HOARDINGS + 1],
							M.SmoothPlastic
						)
					end
				end
			end
			lastK = k
		end
		task.wait()
	end
end

-- Countdown boards before the braking zones of the slow corners: three, two and one stripes at
-- 150, 100 and 50 studs out, behind the barrier on whichever side has room
local function buildDistanceBoards(ground: Instance)
	local model = pieces(ground, "CircuitBoards", 200)
	for k = 1, COUNT do
		local tight = math.abs(SK[k]) > 1 / 70
		local before = SK[wrap(k - 1)]
		if not tight or before ~= 0 then
			continue
		end
		-- Only on a real braking zone: a long straight run into the corner
		local clear = true
		for d = 1, 80 do
			if math.abs(SK[wrap(k - d)]) > 1 / 200 then
				clear = false
				break
			end
		end
		if not clear then
			continue
		end
		local outside = if SK[k] > 0 then -1 else 1
		for stripes = 1, 3 do
			local m = wrap(k - stripes * 25)
			local side = outside
			if (if side > 0 then RR[m] else RL[m]) < 5 or (side < 0 and m >= startFrom and m <= startTo) then
				side = -side
			end
			local room = if side > 0 then RR[m] else RL[m]
			if room < 5 or (side < 0 and m >= startFrom and m <= startTo) then
				continue
			end
			local p = across(m, side * (HALF + room + 2.5))
			local y = surface(p.X, p.Z)
			local base = world(p.X, y, p.Z)
			local facing = Vector3.new(-TX[m], 0, -TZ[m]) -- towards the oncoming cars
			local m0 = model(3 + stripes)
			part(m0, "DistanceBoardPost", Vector3.new(0.4, 4.5, 0.4), CFrame.new(base + Vector3.new(0, 2.25, 0)), STEEL, M.Metal)
			local frame = CFrame.lookAt(base + Vector3.new(0, 5.6, 0), base + Vector3.new(0, 5.6, 0) + facing)
			part(m0, "DistanceBoard", Vector3.new(2.6, 2.6, 0.3), frame, KERB_WHITE, M.SmoothPlastic)
			for i = 1, stripes do
				local lift = (i - (stripes + 1) / 2) * 0.75
				part(
					m0,
					"DistanceStripe",
					Vector3.new(2.2, 0.4, 0.1),
					frame * CFrame.new(0, lift, -0.18),
					rgb(24, 24, 26),
					M.SmoothPlastic,
					false
				)
			end
			claim(p.X, p.Z, 3)
		end
	end
end

-- TV camera platforms on scaffold towers outside the big corners
local CAMERA_CORNERS = { "La Source", "Eau Rouge", "Malmedy", "Rivage", "Pouhon", "Stavelot" }
local function buildCameraTowers(ground: Instance)
	local model = pieceModel(ground, "CircuitCameras")
	for _, corner in CityCircuit.CORNERS do
		if not table.find(CAMERA_CORNERS, corner[4]) then
			continue
		end
		local k = nearest(corner[1], corner[2], 240)
		if not k then
			continue
		end
		local kk = k :: number
		local side = if SK[kk] > 0 then -1 else 1
		local room = if side > 0 then RR[kk] else RL[kk]
		local p = across(kk, side * (HALF + room + 9))
		local y = surface(p.X, p.Z)
		local height = 16
		for _, leg in { { -1.6, -1.6 }, { 1.6, -1.6 }, { -1.6, 1.6 }, { 1.6, 1.6 } } do
			-- Each leg down to the slope under it
			local foot = surface(p.X + leg[1], p.Z + leg[2]) - 0.5
			part(
				model,
				"CameraTowerLeg",
				Vector3.new(0.5, y + height - foot, 0.5),
				CFrame.new(world(p.X + leg[1], (y + height + foot) / 2, p.Z + leg[2])),
				STEEL,
				M.Metal
			)
		end
		for _, lift in { 5, 10 } do
			part(
				model,
				"CameraTowerBrace",
				Vector3.new(3.7, 0.3, 3.7),
				CFrame.new(world(p.X, y + lift, p.Z)),
				STEEL,
				M.Metal,
				false
			)
		end
		part(model, "CameraPlatform", Vector3.new(5, 0.5, 5), CFrame.new(world(p.X, y + height, p.Z)), rgb(60, 62, 66), M.DiamondPlate)
		part(model, "CameraRoof", Vector3.new(5.4, 0.3, 5.4), CFrame.new(world(p.X, y + height + 4.5, p.Z)), rgb(240, 120, 20), M.SmoothPlastic, false)
		-- The camera on its tripod, looking at the track
		local at = world(p.X, y + height + 1.6, p.Z)
		local track = world(SX[kk], y + height + 1.6, SZ[kk])
		part(model, "TvCamera", Vector3.new(0.9, 0.9, 2), CFrame.lookAt(at, track), rgb(30, 30, 34), M.SmoothPlastic, false)
		part(model, "CameraTripod", Vector3.new(0.3, 1.2, 0.3), CFrame.new(at - Vector3.new(0, 0.9, 0)), rgb(30, 30, 34), M.Metal, false)
		claim(p.X, p.Z, 4)
	end
end

-- A low-poly car parked nose-out in a garage. `gx` is the garage's west wall; the nose points at
-- the pit lane (smaller `o`)
local function pitCar(parent: Instance, gx: number, team: Color3)
	local mid = gx + GARAGE_WIDTH / 2
	local c = GARAGE_FRONT + 10
	local DARK = rgb(28, 29, 31)
	local function box(name: string, x0: number, x1: number, o0: number, o1: number, y0: number, y1: number, color: Color3, material: Enum.Material?, collidable: boolean?)
		sfBox(parent, name, mid + x0, mid + x1, c + o0, c + o1, y0, y1, color, material or M.SmoothPlastic, collidable)
	end
	box("PitCar", -1.4, 1.4, -6.6, 6.2, 0.35, 1.3, team)
	box("PitCarSidepods", -2.7, 2.7, -1.2, 3.4, 0.35, 1.7, team, nil, false)
	box("PitCarEngineCover", -0.9, 0.9, 0, 5.6, 1.3, 2.7, team, nil, false)
	box("PitCarCockpit", -0.7, 0.7, -2.6, -0.4, 1.3, 2, DARK, nil, false)
	box("PitCarHalo", -0.8, 0.8, -2.8, -2.5, 1.3, 2.5, DARK, nil, false)
	box("PitCarFrontWing", -3.3, 3.3, -7.4, -6.4, 0.25, 0.6, DARK, nil, false)
	box("PitCarRearWing", -2.5, 2.5, 6.1, 6.9, 2.3, 3.3, DARK, nil, false)
	for _, side in { -1, 1 } do
		for _, axle in { -4.4, 4.6 } do
			box("PitCarWheel", side * 2.9 - 0.65, side * 2.9 + 0.65, axle - 1, axle + 1, 0, 1.9, DARK, M.Rubber, false)
		end
	end
end

-- Working detail in the pits and paddock: a car in every garage under its strip lights, the
-- pit-stop light rigs hanging off the roof over each box, team stands on the pit wall, the pit
-- lane's speed signs and exit light, flags along the roof, and hospitality units in the paddock
local function buildPitDetail(ground: Instance)
	local x0 = GARAGES_FROM
	local cars = pieces(ground, "PitCars", 200)
	local rigs = pieces(ground, "PitRigs", 200)
	for g = 0, GARAGES - 1 do
		local gx = x0 + g * GARAGE_WIDTH
		local mid = gx + GARAGE_WIDTH / 2
		local team = TEAMS[g // 2 % #TEAMS + 1]
		pitCar(cars(11), gx, team)
		local rig = rigs(5)
		local strip = sfBox(rig, "GarageLight", mid - 0.4, mid + 0.4, GARAGE_FRONT + 2, GARAGE_BACK - 3, 7.4, 7.7, rgb(236, 236, 232), M.SmoothPlastic, false)
		glow(strip, rgb(255, 250, 235), 0.2)
		-- The pit-stop rig: a boom from the roof edge and the light the driver waits on
		sfBox(rig, "PitRigBoom", mid - 0.3, mid + 0.3, GARAGE_FRONT - 6.5, GARAGE_FRONT, 13.2, 13.8, STEEL, M.Metal, false)
		sfBox(rig, "PitRigDrop", mid - 0.2, mid + 0.2, GARAGE_FRONT - 6.3, GARAGE_FRONT - 5.9, 9.5, 13.2, STEEL, M.Metal, false)
		sfBox(rig, "PitRigLight", mid - 0.9, mid + 0.9, GARAGE_FRONT - 6.6, GARAGE_FRONT - 5.6, 8.3, 9.5, rgb(30, 30, 34), M.SmoothPlastic, false)
		sfBox(rig, "PitRigLamp", mid - 0.6, mid + 0.6, GARAGE_FRONT - 6.75, GARAGE_FRONT - 6.6, 8.6, 9.2, rgb(40, 220, 80), M.Neon, false)
	end
	task.wait()

	-- Team stands on the pit wall: an awning on two posts, a row of screens and a desk
	local wall = pieceModel(ground, "PitWallStands")
	for g = 0, GARAGES - 1, 2 do
		local mid = x0 + (g + 1) * GARAGE_WIDTH
		if g == GARAGES - 1 then
			mid = x0 + (g + 0.5) * GARAGE_WIDTH
		end
		local team = TEAMS[g // 2 % #TEAMS + 1]
		sfBox(wall, "PitWallAwning", mid - 7, mid + 7, PIT_WALL - 1.5, PIT_WALL + 3, 9.3, 9.8, team, M.SmoothPlastic, false)
		for _, end_ in { -6.5, 6.5 } do
			sfBox(wall, "PitWallStandPost", mid + end_ - 0.2, mid + end_ + 0.2, PIT_WALL + 0.55, PIT_WALL + 0.95, 3.2, 9.3, STEEL, M.Metal, false)
		end
		sfBox(wall, "PitWallDesk", mid - 6, mid + 6, PIT_WALL + 1.5, PIT_WALL + 2.8, 3.6, 4, rgb(60, 62, 66), M.SmoothPlastic, false)
		for i = -1, 1 do
			local screen = sfBox(wall, "PitWallScreen", mid + i * 3.6 - 1.4, mid + i * 3.6 + 1.4, PIT_WALL + 1.5, PIT_WALL + 1.7, 4.6, 6.4, rgb(25, 35, 43), M.SmoothPlastic, false)
			glow(screen, rgb(70, 140, 200), 0.3)
		end
	end
	-- Speed limit signs at both ends of the lane, and the light at its exit
	for _, sx in { PIT_FROM + 4, PIT_TO - 4 } do
		sfBox(wall, "PitSpeedSignPost", sx - 0.2, sx + 0.2, LANE_OUT + 1.3, LANE_OUT + 1.7, 0, 5, STEEL, M.Metal)
		sfBox(wall, "PitSpeedSign", sx - 0.15, sx + 0.15, LANE_OUT, LANE_OUT + 3, 5, 8, KERB_RED, M.SmoothPlastic, false)
		sfBox(wall, "PitSpeedSignFace", sx - 0.2, sx + 0.2, LANE_OUT + 0.5, LANE_OUT + 2.5, 5.5, 7.5, KERB_WHITE, M.SmoothPlastic, false)
	end
	local ex = PIT_TO - 2
	sfBox(wall, "PitExitLightPost", ex - 0.25, ex + 0.25, PIT_WALL + 0.5, PIT_WALL + 1, 3.2, 9, STEEL, M.Metal)
	sfBox(wall, "PitExitLight", ex - 0.4, ex + 0.4, PIT_WALL + 0.1, PIT_WALL + 1.4, 7.5, 10.2, rgb(30, 30, 34), M.SmoothPlastic, false)
	sfBox(wall, "PitExitLamp", ex - 0.55, ex - 0.4, PIT_WALL + 0.35, PIT_WALL + 1.15, 9, 9.8, KERB_RED, M.Neon, false)
	sfBox(wall, "PitExitLamp", ex - 0.55, ex - 0.4, PIT_WALL + 0.35, PIT_WALL + 1.15, 7.9, 8.7, rgb(40, 220, 80), M.Neon, false)
	-- Team flags along the front of the roof
	for g = 0, GARAGES - 1, 2 do
		local fx = x0 + g * GARAGE_WIDTH + 4
		local team = TEAMS[g // 2 % #TEAMS + 1]
		sfBox(wall, "RoofFlagPole", fx - 0.15, fx + 0.15, GARAGE_FRONT - 4.15, GARAGE_FRONT - 3.85, 15, 23, STEEL, M.Metal, false)
		sfBox(wall, "RoofFlag", fx + 0.15, fx + 3.4, GARAGE_FRONT - 4.08, GARAGE_FRONT - 3.92, 20.6, 22.8, team, M.Fabric, false)
	end
	task.wait()

	-- Hospitality units between the transporters, each with an awning out to its truck
	local paddock = pieceModel(ground, "PaddockHospitality")
	for t = 0, 9 do
		local px = x0 + 18 + t * 38
		local hx = px + 19
		if math.abs(px - ACCESS_X) < 20 or math.abs(hx - ACCESS_X) < 20 or hx + 7 > PADDOCK_TO - 4 then
			continue
		end
		local team = TEAMS[t % #TEAMS + 1]
		sfBox(paddock, "Hospitality", hx - 7, hx + 7, GARAGE_BACK + 10, GARAGE_BACK + 30, 0, 5.5, rgb(70, 100, 120), M.Glass)
		sfBox(paddock, "HospitalityUpper", hx - 7.4, hx + 7.4, GARAGE_BACK + 9.6, GARAGE_BACK + 30.4, 5.5, 10, team, M.SmoothPlastic)
		sfBox(paddock, "HospitalityRail", hx - 7.4, hx + 7.4, GARAGE_BACK + 9.6, GARAGE_BACK + 10, 10, 11.6, STEEL, M.Metal).Transparency = 0.4
		local awning = sfBox(paddock, "PaddockAwning", px + 3.5, hx - 7, GARAGE_BACK + 11, GARAGE_BACK + 26, 7.6, 8, rgb(236, 236, 232), M.Fabric, false)
		awning.Transparency = 0.1
		for _, o in { 15, 21 } do
			local tx = (px + 3.5 + hx - 7) / 2
			sfBox(paddock, "PaddockTable", tx - 1.2, tx + 1.2, GARAGE_BACK + o - 1.2, GARAGE_BACK + o + 1.2, 0, 1.4, rgb(236, 236, 232), M.SmoothPlastic)
		end
	end
	-- Lamps along the paddock rail
	for lx = PADDOCK_FROM + 20, PADDOCK_TO - 10, 40 do
		if math.abs(lx - ACCESS_X) < 14 then
			continue
		end
		sfBox(paddock, "PaddockLampPost", lx - 0.25, lx + 0.25, PADDOCK_BACK - 2.5, PADDOCK_BACK - 2, 0, 11, rgb(60, 62, 66), M.Metal)
		glow(
			sfBox(paddock, "PaddockLamp", lx - 0.8, lx + 0.8, PADDOCK_BACK - 3.4, PADDOCK_BACK - 1.6, 11, 11.6, rgb(220, 220, 210), M.SmoothPlastic, false),
			rgb(255, 236, 200),
			0.35
		)
	end
end

function CityCircuit.build(ground: Instance, origin: Vector3, ground_surface: (number, number) -> number)
	assert(shaped, "CityCircuit.shape first")
	center = origin
	surface = ground_surface
	table.clear(STANDS)
	local kept = keySamples()
	buildTrack(ground, kept)
	-- The road itself shows in the distant shell, so the lap reads from across the water
	for _, model in ground:GetChildren() do
		if model.Name == "CircuitTrack" then
			for _, w in model:GetChildren() do
				w:SetAttribute("LodKeep", true)
			end
		end
	end
	task.wait()
	buildBarriers(ground, kept)
	buildTrackside(ground, kept)
	buildStart(ground)
	buildPits(ground)
	buildPitDetail(ground)
	task.wait()
	buildDistanceBoards(ground)
	buildCameraTowers(ground)
	for _, stand in CityCircuit.GRANDSTANDS do
		local a, b = stand[2] :: { number }, stand[3] :: { number }
		grandstand(
			ground,
			stand[1] :: string,
			Vector3.new(a[1], 0, a[2]),
			Vector3.new(b[1], 0, b[2]),
			stand[4] :: number,
			stand[5] :: boolean,
			stand[6] :: Color3
		)
	end
	local crest = nearest(CityCircuit.CORNERS[5][1], CityCircuit.CORNERS[5][2], 200)
	footbridge(ground, wrap((crest :: number) + 40))
	marshals(ground)
end

return CityCircuit
