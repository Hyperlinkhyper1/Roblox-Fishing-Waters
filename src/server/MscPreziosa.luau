-- A 1:1 model of the cruise ship MSC Preziosa (Fantasia class, STX France, 2013): 333.3 m long,
-- 37.9 m beam and 8.65 m draught, at the game's scale of 0.28 m per stud.
--
-- The deck outlines were traced from MSC's published plans of decks 4-18. Each plan was lined up
-- with the others by its lift shafts, which run straight through the ship: lined up that way every
-- deck ends within 2 m of the 333 m stern. Decks 13-18 are drawn at about 0.88x the scale of the
-- lower plans (their cabins are narrower on paper), which is corrected here. Deck heights, the stem
-- rake, the funnel, mast and lifeboats were measured from broadside and stern-quarter photographs,
-- and the livery (striped balcony decks, slanted blue glazing over the bridge, the slatted funnel
-- with its compass emblem, the hull logos) from bow, broadside and aerial photographs.
--
-- The open top decks follow the same photographs: the Yacht Club forward with its glass-fronted
-- Top Sail Lounge and The One Pool, the magrodome over La Playa Preziosa, the round Galaxy/Sky &
-- Stars pavilion, the horizontally louvered funnel over the Top 18 solarium, and the Garden pool
-- terrace at the stern.
--
-- Ship coordinates are metres: x aft from the tip of the bow, y to starboard of the centre line and
-- z up from the waterline. The model's origin is the waterline amidships, with the bow towards -X.
-- Vector3s passed to strut() and tube() hold ship coordinates (x, y, z) in metres.
local MscPreziosa = {}

MscPreziosa.LENGTH = 333.3
MscPreziosa.BEAM = 37.9
MscPreziosa.DRAUGHT = 8.65
MscPreziosa.STUDS = 1 / 0.28 -- studs per metre

local STUDS = MscPreziosa.STUDS
local MID = MscPreziosa.LENGTH / 2
local KEEL = -MscPreziosa.DRAUGHT

local rgb = Color3.fromRGB
local M = Enum.Material
local WHITE = rgb(244, 245, 247)
local ANTIFOULING = rgb(122, 38, 40)
local GLASS = rgb(34, 47, 74)
local RAIL = rgb(150, 182, 205)
local TEAK = rgb(170, 124, 82)
local MOORING = rgb(108, 122, 112)
local FUNNEL = rgb(24, 34, 64)
local STEEL = rgb(150, 156, 162)
local BRONZE = rgb(176, 132, 70)
local ORANGE = rgb(238, 112, 34)
local POOL = rgb(64, 172, 214)
local NAVY = rgb(20, 30, 70)
local CABIN_DARK = rgb(42, 52, 72) -- the shaded cabin wall behind a balcony
local TINTED = rgb(40, 60, 98) -- the blue-tinted balcony glass
local SLANT = rgb(38, 68, 128) -- the glazing over the bridge
local HELM = rgb(206, 64, 36)
local SOOT = rgb(58, 58, 62)

-- Floor of each deck above the waterline (there is no deck 17 on MSC ships)
local FLOOR = {
	[4] = 6.1,
	[5] = 9.0,
	[6] = 12.0,
	[7] = 15.1,
	[8] = 18.2,
	[9] = 21.15,
	[10] = 24.1,
	[11] = 27.05,
	[12] = 30.0,
	[13] = 33.0,
	[14] = 35.95,
	[15] = 39.3,
	[16] = 42.3,
	[18] = 45.3,
}
local ROOF = FLOOR[18]

-- Half-breadth of each deck's outer wall (balcony fronts where there are balconies) as
-- { x, half } points. Decks with an open gap between blocks list one outline per block.
-- Decks 8-13 step in over the lifeboats (x 116-283) and deck 14 cantilevers out above them.
-- stylua: ignore
local PLAN = {
	[4] = { { { 17, 1.3 }, { 20, 1.8 }, { 33, 6.85 }, { 43, 10.18 }, { 55, 13.41 }, { 62, 14.93 }, { 76, 17.45 }, { 95, 18.83 }, { 327, 18.88 }, { 331, 18.5 } } },
	[5] = { { { 17, 1.43 }, { 20, 1.81 }, { 25, 3.9 }, { 34, 7.23 }, { 42, 9.84 }, { 54, 13.27 }, { 64, 15.5 }, { 71, 16.69 }, { 79, 17.74 }, { 89, 18.59 }, { 97, 18.93 }, { 328, 18.97 }, { 332, 18.59 } } },
	[8] = { { { 0, 2.2 }, { 3, 3.66 }, { 7, 6.51 }, { 13, 10.13 }, { 19, 13.08 }, { 23, 14.69 }, { 31, 17.17 }, { 34, 17.78 }, { 37, 18.31 }, { 45, 18.88 }, { 113, 18.97 }, { 114, 17.31 }, { 117, 12.89 }, { 201, 12.89 }, { 202, 14.6 }, { 260, 14.6 }, { 261, 13.03 }, { 277, 12.98 }, { 282, 16.69 }, { 283, 18.78 }, { 329, 18.83 }, { 333, 18.31 } } },
	[9] = { { { 29, 11.08 }, { 30, 11.08 }, { 31, 12.6 }, { 32, 12.6 }, { 34, 14.88 }, { 36, 16.36 }, { 38, 17.45 }, { 40, 18.21 }, { 41, 18.93 }, { 113, 18.93 }, { 114, 17.17 }, { 118, 13.55 }, { 119, 12.84 }, { 201, 12.84 }, { 202, 16.07 }, { 261, 16.07 }, { 262, 12.89 }, { 277, 12.84 }, { 278, 13.22 }, { 282, 16.88 }, { 283, 18.88 }, { 329, 18.88 }, { 333, 18.31 } } },
	[10] = { { { 34, 10.79 }, { 35, 10.79 }, { 36, 12.41 }, { 37, 12.41 }, { 38, 13.74 }, { 39, 14.74 }, { 40, 15.64 }, { 42, 16.98 }, { 46, 18.45 }, { 50, 18.93 }, { 113, 18.93 }, { 114, 17.36 }, { 118, 13.69 }, { 119, 12.84 }, { 201, 12.84 }, { 202, 16.02 }, { 260, 16.02 }, { 261, 12.84 }, { 277, 12.79 }, { 278, 13.41 }, { 282, 17.02 }, { 283, 18.88 }, { 328, 18.88 }, { 332, 18.4 } } },
	[11] = { { { 39, 10.79 }, { 40, 10.79 }, { 41, 12.51 }, { 42, 12.51 }, { 44, 14.84 }, { 47, 16.98 }, { 50, 18.21 }, { 52, 18.69 }, { 55, 18.93 }, { 114, 18.93 }, { 115, 16.69 }, { 119, 13.08 }, { 120, 12.79 }, { 201, 12.84 }, { 202, 15.93 }, { 203, 16.02 }, { 261, 16.02 }, { 262, 12.84 }, { 277, 12.84 }, { 278, 13.27 }, { 282, 16.88 }, { 283, 18.88 }, { 329, 18.88 }, { 331, 18.59 } } },
	[12] = { { { 43, 10.03 }, { 44, 10.03 }, { 45, 11.94 }, { 46, 11.94 }, { 48, 14.46 }, { 49, 15.36 }, { 52, 17.31 }, { 56, 18.59 }, { 59, 18.93 }, { 113, 18.93 }, { 114, 17.4 }, { 119, 12.89 }, { 123, 12.79 }, { 201, 12.84 }, { 202, 16.02 }, { 260, 16.02 }, { 261, 12.89 }, { 276, 12.79 }, { 278, 13.41 }, { 282, 17.02 }, { 283, 18.88 }, { 326, 18.88 }, { 330, 18.5 } } },
	-- The bridge, with its wings reaching 4.7 m past the hull
	[13] = { { { 45, 15.66 }, { 46, 15.66 }, { 47, 20.12 }, { 48, 20.12 }, { 49, 23.17 }, { 50, 23.59 }, { 53, 23.59 }, { 55, 20.18 }, { 56, 18.97 }, { 113, 18.93 }, { 114, 17.4 }, { 118, 13.74 }, { 119, 12.89 }, { 201, 12.84 }, { 202, 15.34 }, { 203, 16.02 }, { 260, 16.02 }, { 261, 12.89 }, { 276, 12.79 }, { 278, 13.41 }, { 282, 17.02 }, { 283, 18.88 }, { 325, 18.88 }, { 327, 18.5 }, { 328, 17.92 }, { 330, 16.39 }, { 331, 16.39 } } },
	[14] = { { { 46, 18.24 }, { 48, 22.05 }, { 50, 23.59 }, { 53, 23.59 }, { 54, 23.14 }, { 56, 19 }, { 57, 18.95 }, { 114, 18.95 }, { 116, 17.8 }, { 283, 17.8 }, { 286, 18.89 }, { 325, 18.95 }, { 327, 18.78 }, { 328, 18.29 }, { 329, 17.2 }, { 330, 17.2 }, { 331, 14.65 }, { 332, 14.65 } } },
	-- The open pool deck's rails
	[15] = { { { 51, 10.07 }, { 53, 11.92 }, { 54, 11.92 }, { 56, 14.48 }, { 57, 15.41 }, { 59, 16.82 }, { 61, 17.86 }, { 63, 18.51 }, { 66, 18.95 }, { 114, 18.95 }, { 116, 17.8 }, { 282, 17.75 }, { 284, 18.95 }, { 325, 18.95 }, { 327, 18.62 }, { 329, 17.37 }, { 330, 15.79 }, { 331, 12.2 }, { 333, 7.73 }, { 334, 7.73 } } },
	-- The MSC Yacht Club forward, the sports and funnel block aft
	[16] = {
		{ { 58, 10.83 }, { 59, 10.83 }, { 60, 12.47 }, { 61, 12.47 }, { 63, 14.86 }, { 64, 15.73 }, { 67, 17.59 }, { 70, 18.62 }, { 73, 19 }, { 116, 19 }, { 117, 18.57 }, { 118, 17.8 }, { 144, 17.8 }, { 145, 9.64 }, { 146, 6.81 } },
		{ { 202, 9.09 }, { 204, 12.03 }, { 205, 13.12 }, { 208, 15.52 }, { 210, 16.71 }, { 212, 17.59 }, { 216, 18.51 }, { 220, 18.57 }, { 225, 17.42 }, { 229, 15.35 }, { 232, 14.21 }, { 236, 14.21 }, { 237, 13.01 }, { 240, 13.01 }, { 242, 11.38 }, { 246, 11.11 }, { 247, 11.43 }, { 249, 14.48 }, { 252, 14.48 }, { 256, 13.67 }, { 269, 13.67 }, { 271, 13.99 }, { 275, 15.79 }, { 277, 16.28 }, { 280, 16.28 }, { 284, 15.14 }, { 286, 14.26 }, { 289, 14.26 }, { 296, 15.3 }, { 300, 15.52 }, { 305, 15.35 }, { 309, 14.21 }, { 311, 13.12 }, { 314, 10.56 }, { 316, 7.95 }, { 319, 6.04 } },
	},
	-- The Top Sail Lounge forward, the solarium and funnel base aft
	[18] = {
		{ { 69, 10.89 }, { 70, 10.89 }, { 71, 12.63 }, { 72, 12.63 }, { 74, 14.81 }, { 77, 16.99 }, { 79, 17.97 }, { 81, 18.62 }, { 83, 18.84 }, { 134, 18.95 }, { 136, 17.86 }, { 148, 17.86 } },
		-- Aft of the funnel casing deck 18 is the open deck round the kids' aqua park
		{ { 207, 8.28 }, { 209, 11.54 }, { 210, 12.74 }, { 212, 14.59 }, { 214, 16.01 }, { 216, 17.1 }, { 220, 18.4 }, { 222, 18.67 }, { 225, 18.67 }, { 228, 18.29 }, { 232, 16.88 }, { 234, 15.79 }, { 237, 13.34 }, { 243, 13.23 }, { 252, 13.5 }, { 260, 12.5 }, { 261, 10.07 }, { 266, 10.07 }, { 267, 7.08 }, { 284, 7.08 } },
	},
}
MscPreziosa.PLAN = PLAN
MscPreziosa.FLOOR = FLOOR

-- How each deck's sides look along its length: a white wall with a ribbon of windows (taller on
-- the bridge and the solarium), recessed balconies behind blue-tinted glass, a plain white stair
-- tower, a full-height glass band, glazing that leans back over the bridge, or a wall with long
-- separate windows. The balcony decks over the lifeboats are framed by white stair towers.
local function recessed(head)
	local style = table.clone(head)
	for _, range in
		{
			{ 112, 118, "wall" },
			{ 118, 199, "balcony" },
			{ 199, 203, "wall" },
			{ 203, 259, "balcony" },
			{ 259, 263, "wall" },
			{ 263, 276, "balcony" },
			{ 276, 280, "wall" },
			{ 283, 999, "balcony" },
		}
	do
		table.insert(style, range)
	end
	return style
end
local STYLE = {
	-- Deck 8's hull plating forward of x 31 belongs to the hull
	[8] = recessed({ { 31, 112, "windows" } }),
	[9] = recessed({ { 0, 112, "windows" } }),
	[10] = recessed({ { 0, 98, "windows" }, { 98, 112, "balcony" } }),
	[11] = recessed({ { 0, 103, "windows" }, { 103, 112, "balcony" } }),
	[12] = recessed({ { 0, 107, "windows" }, { 107, 112, "balcony" } }),
	[13] = recessed({ { 0, 62, "bridge" }, { 62, 112, "windows" } }),
	[14] = { { 0, 57, "slant" }, { 57, 999, "panels" } },
	[15] = { { 0, 66, "strip" }, { 66, 117, "balcony" }, { 200, 999, "few" } },
	[16] = { { 0, 73, "windows" }, { 73, 150, "balcony" }, { 200, 999, "few" } },
	[18] = { { 0, 80, "slant" }, { 80, 200, "band" }, { 200, 264, "tall" }, { 264, 999, "wall" } },
}
-- Balcony width: the partitions between balconies sit on one grid through every deck
local BAY = 3.6

local function sample(poly, x: number): number
	if x < poly[1][1] or x > poly[#poly][1] then
		return 0
	end
	for i = 1, #poly - 1 do
		local a, b = poly[i], poly[i + 1]
		if x <= b[1] then
			local span = b[1] - a[1]
			return if span <= 0 then b[2] else a[2] + (b[2] - a[2]) * (x - a[1]) / span
		end
	end
	return poly[#poly][2]
end
MscPreziosa.sample = sample

-- The part of an outline between two stations
local function clip(poly, a: number, b: number)
	a, b = math.max(a, poly[1][1]), math.min(b, poly[#poly][1])
	local out = {}
	if b - a < 0.01 then
		return out
	end
	table.insert(out, { a, sample(poly, a) })
	for _, p in poly do
		if p[1] > a and p[1] < b then
			table.insert(out, p)
		end
	end
	table.insert(out, { b, sample(poly, b) })
	return out
end

-- Replaces an outline's front, up to station xe, with a quarter ellipse running from a flat face
-- `face` half-breadth wide at x0 round to the deck's breadth at xe. The plans draw the fronts as
-- little steps; photographs show them as smooth curves.
local function rounded(poly, x0: number, face: number, xe: number)
	local full = sample(poly, xe)
	local out = {}
	for i = 0, 12 do
		local t = i / 12 * math.pi / 2
		table.insert(out, { xe - (xe - x0) * math.cos(t), face + (full - face) * math.sin(t) })
	end
	for _, p in poly do
		if p[1] > xe + 0.01 then
			table.insert(out, p)
		end
	end
	return out
end
-- { deck, piece, front, face half-breadth, station where it reaches full breadth }
for _, front in
	{
		{ 9, 1, 29, 11.08, 41 },
		{ 10, 1, 34, 10.79, 50 },
		{ 11, 1, 39, 10.79, 55 },
		{ 12, 1, 43, 10.03, 59 },
		-- The bridge front curves in one sweep out to the wing ends
		{ 13, 1, 44.5, 6, 50 },
		{ 15, 1, 51, 10.07, 66 },
		{ 16, 1, 58, 10.83, 73 },
		{ 18, 1, 69, 10.89, 83 },
	}
do
	PLAN[front[1]][front[2]] = rounded(PLAN[front[1]][front[2]], front[3], front[4], front[5])
end

-- Rounds an outline's after end over its last `length` metres, from its breadth there to a stern
-- face `face` half-breadth wide: the stern's corners curve round in plan, tier on tier
local function roundedEnd(poly, length: number, face: number)
	local xs = poly[#poly][1] - length
	local full = sample(poly, xs)
	local out = {}
	for _, p in poly do
		if p[1] < xs - 0.01 then
			table.insert(out, p)
		end
	end
	for i = 0, 12 do
		local t = i / 12 * math.pi / 2
		table.insert(out, { xs + length * math.sin(t), full - (full - face) * (1 - math.cos(t)) })
	end
	return out
end
-- { deck, piece, length of the curve, stern face half-breadth }
for _, stern in
	{
		{ 4, 1, 14, 9.5 },
		{ 5, 1, 14, 9.5 },
		{ 8, 1, 20, 9.5 },
		{ 9, 1, 20, 9.5 },
		{ 10, 1, 20, 9.5 },
		{ 11, 1, 20, 9.5 },
		{ 12, 1, 20, 9.5 },
		{ 13, 1, 18, 9 },
		{ 14, 1, 18, 9 },
		{ 15, 1, 16, 7.7 },
	}
do
	PLAN[stern[1]][stern[2]] = roundedEnd(PLAN[stern[1]][stern[2]], stern[3], stern[4])
end

-- The wings on deck 14 are only the bridge roof; the enclosed deck starts behind it, its front
-- curving like the bridge's
local DECK14 = {}
for _, p in clip(PLAN[14][1], 46.6, PLAN[14][1][#PLAN[14][1]][1]) do
	table.insert(DECK14, { p[1], math.min(p[2], 18.95) })
end
DECK14 = rounded(DECK14, 46.6, 9, 52.5)

local function widen(poly, by: number)
	local out = {}
	for _, p in poly do
		table.insert(out, { p[1], math.max(p[2] + by, 0) })
	end
	return out
end

-- Holds an outline to `limit` between two stations
local function capped(poly, a: number, b: number, limit: number)
	local out = clip(poly, poly[1][1], a)
	table.insert(out, { a + 0.6, math.min(limit, sample(poly, a + 0.6)) })
	for _, p in poly do
		if p[1] > a + 0.6 and p[1] < b - 0.6 then
			table.insert(out, { p[1], math.min(limit, p[2]) })
		end
	end
	table.insert(out, { b - 0.6, math.min(limit, sample(poly, b - 0.6)) })
	for i, p in clip(poly, b, poly[#poly][1]) do
		if i > 1 or p[1] > b - 0.6 then
			table.insert(out, p)
		end
	end
	return out
end

-- The highest deck under a point of the open top decks, if any
local function floorAt(x: number, y: number): number?
	local off = math.abs(y)
	if off < 12.5 and x > 238 and x < 292 then
		return ROOF
	elseif off < sample(PLAN[16][2], x) and x > 202 and x < 316 then
		return FLOOR[16]
	elseif off < sample(PLAN[16][1], x) then
		return FLOOR[18]
	elseif off < sample(PLAN[15][1], x) then
		return FLOOR[15]
	end
	return nil
end

-- The hull plating below deck 9. The stem rakes 1.25 m forward for every metre of height (deck 4's
-- point is 17 m behind the tip of the bow and deck 8's is at it); the bow flares from deck 5's fine
-- entry to deck 8's full one, the bilges round in below 3 m and the stern cuts up under water.
local STEM_RAKE = 1.25
local function stemAt(z: number): number
	return math.max(0, 17 + (6.1 - z) * STEM_RAKE)
end
local function hullPlan(z: number)
	local tip = stemAt(z)
	local stern = if z >= 1 then 331.5 else 331.5 - (1 - z) * 3
	local flare = math.clamp((z - 9) / 9.2, 0, 1)
	local bilge = if z >= -3 then 1 else 1 - 0.2 * ((-3 - z) / 5.65) ^ 2
	local fine, full = PLAN[5][1], PLAN[8][1]
	local out = {}
	for _, u in { 0, 1, 2, 3, 5, 7, 10, 13, 16, 20, 25, 30, 36, 43, 50, 58, 67, 77, 88, 100 } do
		local entry = if 17 + u > 97 then 18.93 else sample(fine, 17 + u)
		local half = entry + (sample(full, math.min(u, 100)) - entry) * flare
		table.insert(out, { tip + u, half * bilge })
	end
	-- The stern's corners curve round in plan to a broad, gently rounded transom
	for i = 0, 10 do
		local t = i / 10 * math.pi / 2
		table.insert(out, { stern - 18 + 18 * math.sin(t), (18.93 - 8.4 * (1 - math.cos(t))) * bilge })
	end
	return out
end
MscPreziosa.hullPlan = hullPlan

local origin = Vector3.zero
local built = 0
-- Building thousands of parts in one go trips the script timeout, so part() hands the frame back
-- whenever a stretch of work runs past BUDGET seconds
local BUDGET = 1 / 60
local pause: () -> () = function() end
local resumed = 0

local function at(x: number, y: number, z: number): Vector3
	return origin + Vector3.new((x - MID) * STUDS, z * STUDS, y * STUDS)
end

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	frame: CFrame,
	color: Color3,
	material: Enum.Material,
	kind: string?
): BasePart
	local p = Instance.new(kind or "Part") :: BasePart
	p.Name = name
	p.Size = size
	p.CFrame = frame
	p.Anchored = true
	p.CanTouch = false
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	built += 1
	if os.clock() - resumed > BUDGET then
		pause()
		resumed = os.clock()
	end
	return p
end

-- A box between ship coordinates, in metres
local function box(
	parent: Instance,
	name: string,
	x0: number,
	x1: number,
	y0: number,
	y1: number,
	z0: number,
	z1: number,
	color: Color3,
	material: Enum.Material?
): BasePart
	return part(
		parent,
		name,
		Vector3.new(x1 - x0, z1 - z0, y1 - y0) * STUDS,
		CFrame.new(at((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)),
		color,
		material or M.SmoothPlastic
	)
end

-- A box from a to b on one side of the ship, whichever way round they are
local function sideBox(
	parent: Instance,
	name: string,
	x0: number,
	x1: number,
	a: number,
	b: number,
	z0: number,
	z1: number,
	color: Color3,
	material: Enum.Material?
): BasePart
	return box(parent, name, x0, x1, math.min(a, b), math.max(a, b), z0, z1, color, material)
end

-- A beam from a to b, `width` across and `depth` along `normal` (a world direction; any if nil)
local function strut(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	width: number,
	depth: number,
	color: Color3,
	material: Enum.Material?,
	normal: Vector3?
): BasePart?
	local p, q = at(a.X, a.Y, a.Z), at(b.X, b.Y, b.Z)
	local length = (q - p).Magnitude
	if length < 0.05 then
		return nil
	end
	local zAxis = (q - p) / length
	local hint = normal or (if math.abs(zAxis.Y) < 0.95 then Vector3.yAxis else Vector3.xAxis)
	local yAxis = (hint - zAxis * hint:Dot(zAxis)).Unit
	return part(
		parent,
		name,
		Vector3.new(width * STUDS, depth * STUDS, length),
		CFrame.fromMatrix((p + q) / 2, yAxis:Cross(zAxis), yAxis, zAxis),
		color,
		material or M.SmoothPlastic
	)
end

-- A cylinder from a to b, run on a little at each end so a chain of them has no gaps
local function tube(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	diameter: number,
	color: Color3,
	material: Enum.Material?
): BasePart?
	local p, q = at(a.X, a.Y, a.Z), at(b.X, b.Y, b.Z)
	local length = (q - p).Magnitude
	if length < 0.05 then
		return nil
	end
	local xAxis = (q - p) / length
	local zAxis = xAxis:Cross(if math.abs(xAxis.Y) < 0.95 then Vector3.yAxis else Vector3.zAxis).Unit
	local pipe = part(
		parent,
		name,
		Vector3.new(length + diameter * 0.3 * STUDS, diameter * STUDS, diameter * STUDS),
		CFrame.fromMatrix((p + q) / 2, xAxis, zAxis:Cross(xAxis), zAxis),
		color,
		material or M.SmoothPlastic
	)
	pipe.Shape = Enum.PartType.Cylinder
	return pipe
end

-- A right-angled triangle extruded `thickness` studs: r is the right-angle corner, p and q end its
-- two legs (world positions).
local function wedge(
	parent: Instance,
	name: string,
	r: Vector3,
	p: Vector3,
	q: Vector3,
	thickness: number,
	color: Color3,
	material: Enum.Material?
): BasePart
	local up, back = q - r, r - p
	local yAxis, zAxis = up.Unit, back.Unit
	return part(
		parent,
		name,
		Vector3.new(thickness, up.Magnitude, back.Magnitude),
		CFrame.fromMatrix((p + q) / 2, yAxis:Cross(zAxis), yAxis, zAxis),
		color,
		material or M.SmoothPlastic,
		"WedgePart"
	)
end

-- Extrudes an outline (mirrored either side of y = centre, the centre line by default) between two
-- heights. Each stretch is a box as wide as its narrower end, with wedges filling out the taper on
-- either side.
local function slab(
	parent: Instance,
	name: string,
	poly,
	z0: number,
	z1: number,
	color: Color3,
	material: Enum.Material?,
	centre: number?
): { BasePart }
	local made = {}
	local zm = (z0 + z1) / 2
	local yc = centre or 0
	for i = 1, #poly - 1 do
		local a, b = poly[i], poly[i + 1]
		local length = b[1] - a[1]
		local lo, hi = math.min(a[2], b[2]), math.max(a[2], b[2])
		if length < 0.01 or hi < 0.05 then
			continue
		end
		if lo > 0.05 then
			table.insert(made, box(parent, name, a[1], b[1], yc - lo, yc + lo, z0, z1, color, material))
		end
		if hi - lo > 0.05 then
			local wide, narrow = if a[2] > b[2] then a[1] else b[1], if a[2] > b[2] then b[1] else a[1]
			for _, side in { -1, 1 } do
				table.insert(
					made,
					wedge(
						parent,
						name,
						at(wide, yc + side * lo, zm),
						at(narrow, yc + side * lo, zm),
						at(wide, yc + side * hi, zm),
						(z1 - z0) * STUDS,
						color,
						material
					)
				)
			end
		end
	end
	return made
end

-- A thin wall standing on each edge of an outline (rails, bulwarks)
local function edges(
	parent: Instance,
	name: string,
	poly,
	z0: number,
	height: number,
	color: Color3,
	material: Enum.Material,
	transparency: number
)
	for i = 1, #poly - 1 do
		local a, b = poly[i], poly[i + 1]
		if math.min(a[2], b[2]) < 0.3 or b[1] - a[1] < 0.01 then
			continue
		end
		for _, side in { -1, 1 } do
			local p, q = at(a[1], side * a[2], z0 + height / 2), at(b[1], side * b[2], z0 + height / 2)
			local along = (q - p).Unit
			local wall = part(
				parent,
				name,
				Vector3.new(0.12 * STUDS, height * STUDS, (q - p).Magnitude),
				CFrame.fromMatrix((p + q) / 2, Vector3.yAxis:Cross(-along), Vector3.yAxis, -along),
				color,
				material
			)
			wall.Transparency = transparency
			wall.CastShadow = false
		end
	end
end

-- Calls visit(x, half, nx, ny) every `spacing` metres along one side of an outline, with (nx, ny)
-- the outward normal in plan
local function walk(poly, spacing: number, visit: (number, number, number, number) -> ())
	local carry = spacing / 2
	for i = 1, #poly - 1 do
		local a, b = poly[i], poly[i + 1]
		local dx, dy = b[1] - a[1], b[2] - a[2]
		local length = math.sqrt(dx * dx + dy * dy)
		if length < 0.01 then
			continue
		end
		local s = carry
		while s < length do
			local t = s / length
			if a[2] + dy * t > 0.3 then
				visit(a[1] + dx * t, a[2] + dy * t, -dy / length, dx / length)
			end
			s += spacing
		end
		carry = s - length
	end
end

-- Positions spaced `spacing` apart across a front face of half-breadth `half`
local function across(half: number, spacing: number): { number }
	local count = math.floor(2 * half / spacing)
	local out = {}
	for i = 0, count do
		table.insert(out, (i - count / 2) * spacing)
	end
	return out
end

-- White frames between the panes of a window ribbon, round the sides and across the front face
local function mullions(parent: Instance, poly, z0: number, z1: number, spacing: number, front: boolean, width: number?)
	local w = (width or 0.24) / 2
	for _, side in { -1, 1 } do
		walk(poly, spacing, function(x, half)
			box(parent, "Mullion", x - w, x + w, side * half - 0.15, side * half + 0.15, z0, z1, WHITE)
		end)
	end
	if front and poly[1][2] > 1 then
		for _, y in across(poly[1][2] - 0.4, spacing) do
			box(parent, "Mullion", poly[1][1] - 0.15, poly[1][1] + 0.15, y - w, y + w, z0, z1, WHITE)
		end
	end
end

local function ribbon(parent: Instance, poly, z0: number, z1: number, front: boolean)
	-- Kept clear of the ends so it never shares a face with the wall
	local x0, x1 = poly[1][1] + 0.1, poly[#poly][1] - 0.1
	slab(parent, "Windows", widen(clip(poly, x0, x1), 0.06), z0, z1, GLASS)
	if front and poly[1][2] > 1 then
		box(
			parent,
			"Windows",
			poly[1][1] - 0.06,
			poly[1][1] + 0.2,
			-(poly[1][2] - 0.4),
			poly[1][2] - 0.4,
			z0,
			z1,
			GLASS
		)
	end
end

-- A band of panoramic glass on a white block: proud of its sides, and a pane across its flat front
-- face so the glass never shares that face with the wall
local function glazing(parent: Instance, name: string, poly, z0: number, z1: number): { BasePart }
	local x0, half = poly[1][1], poly[1][2]
	local made = slab(parent, name, widen(clip(poly, x0 + 0.1, poly[#poly][1]), 0.08), z0, z1, GLASS, M.Glass)
	if half > 0.5 then
		table.insert(made, box(parent, name, x0 - 0.08, x0 + 0.1, -half, half, z0, z1, GLASS, M.Glass))
	end
	for _, glass in made do
		glass.Transparency = 0.12
		glass.CastShadow = false
	end
	return made
end

local function deckLayer(
	parent: Instance,
	poly,
	z0: number,
	z1: number,
	style: string,
	front: boolean,
	back: boolean,
	stern: boolean?
)
	if style == "wall" then
		slab(parent, "Wall", poly, z0, z1, WHITE)
		-- a narrow ribbon of stair-tower windows keeps the white structural bays from reading blank
		for _, side in { -1, 1 } do
			walk(poly, 3, function(x, half)
				sideBox(
					parent,
					"StairGlass",
					x - 0.55,
					x + 0.55,
					side * (half - 0.04),
					side * half,
					z0 + 1.05,
					z0 + 2.05,
					GLASS
				)
			end)
		end
	elseif style == "windows" or style == "tall" or style == "bridge" then
		slab(parent, "Wall", poly, z0, z1, WHITE)
		local bottom, top, spacing = z0 + 0.8, z1 - 0.45, 2.4
		if style == "tall" then
			bottom, top = z0 + 0.8, z1 - 0.6
		elseif style == "bridge" then
			bottom, top, spacing = z0 + 0.9, z1 - 0.45, 1.5
		end
		ribbon(parent, poly, bottom, top, front)
		mullions(parent, poly, bottom, top, spacing, front)
	elseif style == "few" then
		-- Separate square windows along a white wall
		slab(parent, "Wall", poly, z0, z1, WHITE)
		ribbon(parent, poly, z0 + 1.1, z0 + 2.1, front)
		mullions(parent, poly, z0 + 1.1, z0 + 2.1, 2.6, front, 1.6)
	elseif style == "strip" then
		slab(parent, "Wall", poly, z0, z1, WHITE)
		ribbon(parent, poly, z0 + 0.9, z1 - 0.8, front)
	elseif style == "balcony" then
		-- Real balcony decks read as a thick white fascia at each floor with a continuous band of
		-- dark glass above it, divided only by slim white partitions
		local fascia = 0.95
		slab(parent, "Balconies", poly, z0, z0 + fascia, WHITE)
		local inner = widen(poly, -1.55)
		inner = clip(inner, inner[1][1] + (if front then 1.55 else 0), inner[#inner][1] - (if back then 1.55 else 0))
		if #inner > 1 then
			slab(parent, "Cabins", inner, z0 + fascia, z1, CABIN_DARK)
			-- White partitions between neighbouring balconies, spaced along the hull so they stay
			-- evenly spread round the curved stern instead of bunching up on the x grid
			for _, side in { -1, 1 } do
				walk(poly, BAY, function(x, half, nx, ny)
					if half > 2 then
						local ox, oy = x, side * half
						local ix, iy = x - nx * 1.05, oy - side * ny * 1.05
						local mid = at((ix + ox) / 2, (iy + oy) / 2, (z0 + z1) / 2)
						local tangent = Vector3.new(side * ny, 0, -nx).Unit
						local outward = Vector3.new(nx, 0, side * ny).Unit
						part(
							parent,
							"Partition",
							Vector3.new(0.1 * STUDS, (z1 - z0) * STUDS, 1.05 * STUDS),
							CFrame.fromMatrix(mid, tangent, Vector3.yAxis, outward),
							rgb(228, 230, 233),
							M.SmoothPlastic
						)
					end
				end)
			end
		end
		for _, rail in slab(parent, "BalconyGlass", poly, z0 + fascia, z1 - 0.08, TINTED, M.Glass) do
			rail.Transparency = 0.08
			rail.CastShadow = false
		end
		-- A slim white handrail capping the glass
		for _, cap in slab(parent, "BalconyRail", widen(poly, 0.02), z1 - 0.12, z1 - 0.02, WHITE) do
			cap.CastShadow = false
		end
	elseif style == "band" then
		slab(parent, "Wall", poly, z0, z0 + 0.4, WHITE)
		slab(parent, "Windows", widen(poly, -0.3), z0 + 0.4, z1 - 0.4, GLASS)
		slab(parent, "Wall", poly, z1 - 0.4, z1, WHITE)
		mullions(parent, widen(poly, -0.3), z0 + 0.4, z1 - 0.4, 1.8, front)
	elseif style == "panels" then
		-- Long windows with white piers between them
		slab(parent, "Wall", poly, z0, z1, WHITE)
		local x0, x1 = poly[1][1] + 0.1, poly[#poly][1] - 0.1
		for a = x0, x1 - 2, 13.5 do
			local pane = clip(poly, a + 0.75, math.min(a + 12.75, x1))
			if #pane > 1 then
				slab(parent, "Windows", widen(pane, 0.06), z0 + 0.9, z1 - 0.7, GLASS)
			end
		end
	elseif style == "slant" then
		-- Blue glazing that leans back 1 m from a white sill, in three steps, with raked mullions
		local sill, head = z0 + 0.5, z1 - 0.4
		slab(parent, "Wall", poly, z0, sill, WHITE)
		local x0, x1 = poly[1][1], poly[#poly][1]
		for k = 0, 2 do
			local inset = 0.25 + k * 0.35
			local pane = clip(widen(poly, -inset), x0 + inset, x1 - (if back then inset else 0))
			for _, glass in
				slab(
					parent,
					"Glazing",
					pane,
					sill + k * (head - sill) / 3,
					sill + (k + 1) * (head - sill) / 3,
					SLANT,
					M.Glass
				)
			do
				glass.Transparency = 0.1
			end
		end
		slab(parent, "Wall", clip(widen(poly, -1.2), x0 + 1.2, x1), head, z1, WHITE)
		for _, side in { -1, 1 } do
			walk(poly, 1.6, function(x, half, nx, ny)
				strut(
					parent,
					"Mullion",
					Vector3.new(x - nx * 0.2, side * (half - ny * 0.2), sill),
					Vector3.new(x - nx * 1.2, side * (half - ny * 1.2), head),
					0.14,
					0.14,
					WHITE
				)
			end)
		end
		if front then
			for _, y in across(poly[1][2] - 0.6, 1.6) do
				strut(
					parent,
					"Mullion",
					Vector3.new(x0 + 0.2, y, sill),
					Vector3.new(x0 + 1.2, y, head),
					0.14,
					0.14,
					WHITE
				)
			end
		end
	end
	-- The plans list the stern as an open end; close it with a proper transom so the balconies and
	-- windows continue across the flat after face
	if stern then
		local endp = poly[#poly]
		local x, half = endp[1], endp[2]
		if half > 0.5 then
			-- Sit the detail a few centimetres proud of the plating so nothing z-fights
			local back0, back1 = x - 0.32, x - 0.05
			local face0, face1 = x - 0.025, x + 0.025
			box(parent, "SternBulkhead", back0, back1, -half, half, z0, z1, WHITE)
			if style == "balcony" then
				box(parent, "Balconies", face0, face1, -half, half, z0, z0 + 0.95, WHITE)
				local glass = box(
					parent,
					"BalconyGlass",
					face0,
					face1,
					-half + 0.12,
					half - 0.12,
					z0 + 0.95,
					z1 - 0.1,
					TINTED,
					M.Glass
				)
				glass.Transparency = 0.2
				glass.CastShadow = false
				for y = -half + 1.55, half - 1.55, BAY do
					box(parent, "Partition", face0 - 0.02, face1 + 0.02, y - 0.07, y + 0.07, z0 + 0.95, z1, WHITE)
				end
				box(parent, "BalconyRail", face0 - 0.02, face1 + 0.02, -half, half, z1 - 0.12, z1 - 0.02, WHITE)
			elseif style ~= "wall" then
				local bottom, top = z0 + 1, z0 + 2.1
				if style == "tall" then
					bottom, top = z0 + 0.8, z1 - 0.6
				elseif style == "bridge" then
					bottom, top = z0 + 0.9, z1 - 0.45
				elseif style == "strip" or style == "band" then
					bottom, top = z0 + 0.7, z1 - 0.5
				elseif style == "panels" then
					bottom, top = z0 + 0.9, z1 - 0.7
				end
				box(parent, "SternWindows", face0, face1, -half + 1.2, half - 1.2, bottom, top, GLASS)
				if style ~= "few" and style ~= "panels" then
					for y = -half + 1.2, half - 1.2, 2.6 do
						box(parent, "Mullion", face0 - 0.02, face1 + 0.02, y - 0.06, y + 0.06, bottom, top, WHITE)
					end
				end
			end
		end
	end
end

local function buildDeck(parent: Instance, deck: number, top: number, pieces)
	local folder = Instance.new("Model")
	folder.Name = "Deck " .. deck
	folder.Parent = parent
	for _, piece in pieces do
		for _, range in STYLE[deck] do
			local sub = clip(piece, range[1], range[2])
			if #sub > 1 then
				local stern = piece[#piece][1] > 320 and range[2] >= piece[#piece][1]
				deckLayer(
					folder,
					sub,
					FLOOR[deck],
					top,
					range[3],
					range[1] <= piece[1][1],
					range[2] >= piece[#piece][1],
					stern
				)
			end
		end
	end
	return folder
end

-- Forward of BOW_END the hull is a smooth skin; aft of it the hull is parallel-sided and thick
-- layers do.
local BOW_END = 100
-- Where each contour is sampled, as a fraction of the way from the stem to the end of the skin
local STATIONS = { 0, 0.015, 0.035, 0.06, 0.09, 0.13, 0.18, 0.25, 0.33, 0.43, 0.55, 0.7, 0.85, 1 }

-- A flat triangle on a, b, c (world positions) `thickness` metres thick, sunk inside its outer face
-- (the side facing `outward`): two right-angled wedges split at the apex's foot on the longest edge
local function triangle(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	outward: Vector3,
	thickness: number,
	color: Color3
)
	local ab, bc, ca = (b - a).Magnitude, (c - b).Magnitude, (a - c).Magnitude
	if bc >= ab and bc >= ca then
		a, b, c = b, c, a
	elseif ca >= ab and ca >= bc then
		a, b, c = c, a, b
	end
	local edge = b - a
	local length = edge.Magnitude
	if length < 0.02 then
		return
	end
	local foot = a + edge * ((c - a):Dot(edge) / (length * length))
	if (c - foot).Magnitude < 0.02 then
		return
	end
	local n = edge:Cross(c - a).Unit
	if n:Dot(outward) < 0 then
		n = -n
	end
	local sink = n * (-thickness * STUDS / 2)
	for _, corner in { a, b } do
		if (foot - corner).Magnitude > 0.02 then
			wedge(parent, name, foot + sink, corner + sink, c + sink, thickness * STUDS, color)
		end
	end
end

-- Skins the bow between hull contours at the given heights, from the stem aft to station xEnd
local function bowSkin(parent: Instance, levels: { number }, xEnd: number)
	local function contour(z: number)
		local plan = hullPlan(z)
		local tip = plan[1][1]
		local out = {}
		for _, s in STATIONS do
			local x = tip + s * (xEnd - tip)
			table.insert(out, { x, sample(plan, x) })
		end
		return out
	end
	for k = 1, #levels - 1 do
		local za, zb = levels[k], levels[k + 1]
		local lower, upper = contour(za), contour(zb)
		local color = if zb <= 0 then ANTIFOULING else WHITE
		for _, side in { -1, 1 } do
			local outward = Vector3.new(0, 0, side)
			for i = 1, #STATIONS - 1 do
				local p1 = at(lower[i][1], side * lower[i][2], za)
				local p2 = at(lower[i + 1][1], side * lower[i + 1][2], za)
				local q1 = at(upper[i][1], side * upper[i][2], zb)
				local q2 = at(upper[i + 1][1], side * upper[i + 1][2], zb)
				triangle(parent, "Hull", p1, p2, q1, outward, 0.3, color)
				triangle(parent, "Hull", p2, q2, q1, outward, 0.3, color)
			end
		end
		-- Across the blunt face of the stem
		local p1, p2 = at(lower[1][1], -lower[1][2], za), at(lower[1][1], lower[1][2], za)
		local q1, q2 = at(upper[1][1], -upper[1][2], zb), at(upper[1][1], upper[1][2], zb)
		triangle(parent, "Hull", p1, p2, q1, -Vector3.xAxis, 0.3, color)
		triangle(parent, "Hull", p2, q2, q1, -Vector3.xAxis, 0.3, color)
	end
end

local function buildHull(parent: Instance)
	local hull = Instance.new("Model")
	hull.Name = "Hull"
	hull.Parent = parent
	local function colour(z1: number): Color3
		return if z1 <= 0 then ANTIFOULING else WHITE
	end
	-- A flat plate closing the open after end of each hull layer, so the transom is watertight
	local function transom(outline, z0: number, z1: number, color: Color3)
		local last = outline[#outline]
		if last[2] > 0.5 then
			box(hull, "Transom", last[1] - 0.4, last[1], -last[2], last[2], z0, z1, color)
		end
	end
	-- Antifouling up to the waterline, white plating above it
	for _, layer in { { KEEL, -7 }, { -7, -5 }, { -5, -3 } } do
		local z0, z1 = layer[1], layer[2]
		local plan = hullPlan((z0 + z1) / 2)
		slab(hull, "Hull", plan, z0, z1, colour(z1))
		transom(plan, z0, z1, colour(z1))
	end
	-- A thin dark boot-top at the waterline
	slab(hull, "BootTop", hullPlan(0.5), 0.3, 0.62, rgb(26, 38, 66))
	local aft = {
		{ -3, -1, hullPlan(-2) },
		{ -1, 0, hullPlan(-0.5) },
		{ 0, 3, hullPlan(1.5) },
		{ 3, FLOOR[4], hullPlan(4.5) },
		{ FLOOR[4], FLOOR[5], PLAN[4][1] },
		{ FLOOR[5], FLOOR[6], PLAN[5][1] },
		{ FLOOR[6], FLOOR[7], hullPlan(13.5) },
		-- Deck 7 is a promenade recessed behind the lifeboats
		{ FLOOR[7], FLOOR[8], capped(hullPlan(16.6), 117, 282, 16) },
	}
	for _, layer in aft do
		local outline = layer[3]
		slab(hull, "Hull", clip(outline, BOW_END, outline[#outline][1]), layer[1], layer[2], colour(layer[2]))
		transom(outline, layer[1], layer[2], colour(layer[2]))
	end
	-- The bow up to deck 9 (above deck 8 only the plating forward of deck 8's windows) is a skin of
	-- triangles between hull contours, so the flare and the raked stem read as one smooth surface
	bowSkin(
		hull,
		{ -3, -1.5, 0, 1.5, 3, 4.5, FLOOR[4], 7.5, FLOOR[5], 10.5, FLOOR[6], 13.5, FLOOR[7], 16.6, FLOOR[8] },
		BOW_END
	)
	bowSkin(hull, { FLOOR[8], 19.2, 20.2, FLOOR[9] }, 31)

	-- Bulbous bow
	local bulb = part(
		hull,
		"BulbousBow",
		Vector3.new(14, 5.4, 5.4) * STUDS,
		CFrame.new(at(31, 0, -4.6)),
		ANTIFOULING,
		M.SmoothPlastic
	)
	bulb.Shape = Enum.PartType.Cylinder
	part(hull, "BulbousBow", Vector3.one * 5.4 * STUDS, CFrame.new(at(24, 0, -4.6)), ANTIFOULING, M.SmoothPlastic).Shape =
		Enum.PartType.Ball

	-- Twin shafts, propellers and rudders under the stern
	for _, side in { -1, 1 } do
		local y = side * 6.5
		local shaft = part(hull, "Shaft", Vector3.new(24, 0.8, 0.8) * STUDS, CFrame.new(at(306, y, -5)), STEEL, M.Metal)
		shaft.Shape = Enum.PartType.Cylinder
		local hub =
			part(hull, "Propeller", Vector3.new(1.6, 1.6, 1.6) * STUDS, CFrame.new(at(318.5, y, -5)), BRONZE, M.Metal)
		hub.Shape = Enum.PartType.Ball
		for blade = 0, 3 do
			local spin = CFrame.Angles(blade * math.pi / 2 + 0.4, 0, 0)
			part(
				hull,
				"Propeller",
				Vector3.new(0.3, 2.6, 1.3) * STUDS,
				CFrame.new(at(318.5, y, -5)) * spin * CFrame.new(0, 1.8 * STUDS, 0) * CFrame.Angles(0, 0.35, 0),
				BRONZE,
				M.Metal
			)
		end
		box(hull, "Rudder", 321.5, 326.5, y - 0.35, y + 0.35, -7.8, -0.8, ANTIFOULING)
	end

	-- Rows of round portholes along decks 4 and 5, stopping short of the logo near the stern
	for _, z in { 7.6, 10.6 } do
		local row = hullPlan(z)
		for x = 64, 262, 3.1 do
			local half = sample(row, x)
			for _, side in { -1, 1 } do
				tube(
					hull,
					"Porthole",
					Vector3.new(x, side * (half - 0.1), z),
					Vector3.new(x, side * (half + 0.05), z),
					0.9,
					GLASS
				)
			end
		end
	end
	-- The anchor pockets low on the bow
	for _, side in { -1, 1 } do
		local row = hullPlan(9.4)
		for _, x in { 24.5, 25.5, 26.5 } do
			local half = sample(row, x)
			sideBox(hull, "AnchorPocket", x - 0.5, x + 0.5, side * (half - 0.2), side * (half + 0.06), 8.6, 10.2, GLASS)
		end
		local half = sample(row, 25.5)
		sideBox(hull, "Anchor", 24.9, 26.1, side * (half - 0.1), side * (half + 0.12), 8.9, 9.9, SOOT, M.Metal)
	end
	-- Two long bands of restaurant and lounge windows across the stern, wrapping round the rounded
	-- transom, with white piers between the panes
	for _, band in { { 13.2, 14.85 }, { 16.7, 17.95 } } do
		-- Proud of the plating round the corners and stopped inside the transom plate, so the glass
		-- never shares a face with the hull
		local wrap = widen(clip(hullPlan((band[1] + band[2]) / 2), 320, 331.3), 0.06)
		for _, glass in slab(hull, "SternWindows", wrap, band[1], band[2], GLASS) do
			glass.Transparency = 0.1
			glass.CastShadow = false
		end
		box(hull, "SternWindows", 331.4, 331.62, -10.3, 10.3, band[1], band[2], GLASS)
		for y = -9.6, 9.6, 2.4 do
			box(hull, "SternMullion", 331.35, 331.7, y - 0.08, y + 0.08, band[1], band[2], WHITE)
		end
	end
	-- A line of portholes on the transom below the name
	for y = -8.4, 8.4, 2.4 do
		tube(hull, "Porthole", Vector3.new(331.42, y, 10.35), Vector3.new(331.66, y, 10.35), 0.8, GLASS)
	end
	return hull
end

-- An invisible plate carrying a SurfaceGui on its front face, `width` by `height` metres
local function sign(parent: Instance, frame: CFrame, width: number, height: number): SurfaceGui
	local plate = part(parent, "Lettering", Vector3.new(width, height, 0.05) * STUDS, frame, WHITE, M.SmoothPlastic)
	plate.Transparency = 1
	plate.CanCollide = false
	plate.CanQuery = false
	plate.CastShadow = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 12
	gui.LightInfluence = 1
	gui.Parent = plate
	return gui
end

local function words(
	gui: Instance,
	text: string,
	x: number,
	y: number,
	width: number,
	height: number,
	color: Color3,
	font: Enum.Font
)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(x, y)
	label.Size = UDim2.fromScale(width, height)
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = font
	label.Parent = gui
end

-- The MSC emblem: a solid eight-point compass star (four long cardinal points, four shorter
-- diagonal ones) round a thick ring studded with eight dots, and inside it a disc lettered "msc"
-- with a wave between the "m" and the "sc". Built from parts in the plane through `centre`
-- facing `normal` (world vectors).
local function star(
	parent: Instance,
	centre: Vector3,
	normal: Vector3,
	up: Vector3,
	radius: number,
	ink: Color3,
	disc: Color3,
	letters: Color3
)
	local right = up:Cross(normal)
	local r = radius * STUDS
	local function point(angle: number, distance: number): Vector3
		return centre + (right * math.sin(angle) + up * math.cos(angle)) * distance
	end
	for i = 0, 7 do
		local angle = i * math.pi / 4
		local long = i % 2 == 0
		local tip = point(angle, if long then r else r * 0.68)
		local base = point(angle, r * 0.4)
		local spread = (right * math.cos(angle) - up * math.sin(angle)) * r * (if long then 0.17 else 0.13)
		wedge(parent, "Emblem", base, base + spread, tip, 0.06 * STUDS, ink)
		wedge(parent, "Emblem", base, base - spread, tip, 0.06 * STUDS, ink)
	end
	for _, ring in { { 0.47, ink, 0.07 }, { 0.36, disc, 0.09 } } do
		local d = part(
			parent,
			"Emblem",
			Vector3.new(ring[3] * STUDS, 2 * r * ring[1], 2 * r * ring[1]),
			CFrame.fromMatrix(centre + normal * ring[3] * STUDS / 2, normal, up),
			ring[2],
			M.SmoothPlastic
		)
		d.Shape = Enum.PartType.Cylinder
	end
	-- The dots on the ring sit between the points; on a star the colour of its disc they take the
	-- lettering's colour so they still show
	local dots = if ink == disc then letters else disc
	for i = 0, 7 do
		local d = part(
			parent,
			"Emblem",
			Vector3.new(0.09 * STUDS, 2 * r * 0.03, 2 * r * 0.03),
			CFrame.fromMatrix(point((i + 0.5) * math.pi / 4, r * 0.415) + normal * 0.045 * STUDS, normal, up),
			dots,
			M.SmoothPlastic
		)
		d.Shape = Enum.PartType.Cylinder
	end
	local back = -normal
	local gui = sign(
		parent,
		CFrame.fromMatrix(centre + normal * 0.12 * STUDS, up:Cross(back), up, back),
		radius * 0.6,
		radius * 0.6
	)
	words(gui, "m", 0.12, 0.06, 0.76, 0.42, letters, Enum.Font.GothamBlack)
	words(gui, "sc", 0.18, 0.54, 0.64, 0.38, letters, Enum.Font.GothamBlack)
	-- The wave: short dashes following one period of a sine across the middle
	local steps = 14
	for k = 0, steps - 1 do
		local function wave(t: number): (number, number)
			return 0.1 + 0.8 * t, 0.5 - 0.035 * math.sin(t * 2 * math.pi)
		end
		local ax, ay = wave(k / steps)
		local bx, by = wave((k + 1) / steps)
		local dash = Instance.new("Frame")
		dash.BorderSizePixel = 0
		dash.BackgroundColor3 = letters
		dash.AnchorPoint = Vector2.new(0.5, 0.5)
		dash.Position = UDim2.fromScale((ax + bx) / 2, (ay + by) / 2)
		dash.Size = UDim2.fromScale(math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2) * 1.15, 0.035)
		dash.Rotation = math.deg(math.atan2(by - ay, bx - ax))
		dash.Parent = gui
	end
end

-- The outward normal of the hull plating at station x and height z on one side
local function hullNormal(x: number, z: number, side: number): Vector3
	local function on(px: number, pz: number): Vector3
		return at(px, side * sample(hullPlan(pz), px), pz)
	end
	local n = (on(x + 0.5, z) - on(x - 0.5, z)):Cross(on(x, z + 0.5) - on(x, z - 0.5)).Unit
	return if n.Z * side < 0 then -n else n
end

-- A frame on the hull surface at station x and height z on one side, facing outwards, `lift`
-- metres proud of the plating
local function onHull(poly, x: number, z: number, side: number, lift: number): CFrame
	local p, q = at(x - 1, side * sample(poly, x - 1), z), at(x + 1, side * sample(poly, x + 1), z)
	local outward = Vector3.yAxis:Cross(q - p).Unit
	if outward.Z * side < 0 then
		outward = -outward
	end
	return CFrame.fromMatrix((p + q) / 2 + outward * lift * STUDS, outward:Cross(Vector3.yAxis), Vector3.yAxis)
end

local function buildLivery(parent: Instance)
	local livery = Instance.new("Model")
	livery.Name = "Lettering"
	livery.Parent = parent
	for _, side in { -1, 1 } do
		-- The name under the bridge, and the small emblem near the stem
		local name = sign(livery, onHull(hullPlan(16.6), 52, 16.6, side, 0.08), 20, 1.9)
		words(name, "MSC PREZIOSA", 0, 0, 1, 1, NAVY, Enum.Font.Garamond)
		local n = hullNormal(9, 17.4, side)
		local up = (Vector3.yAxis - n * Vector3.yAxis:Dot(n)).Unit
		local bow = at(9, side * sample(hullPlan(17.4), 9), 17.4) + n * 0.1 * STUDS
		star(livery, bow, n, up, 1.3, NAVY, WHITE, NAVY)
		-- Low on the hull near the stern: the star and "MSC", two decks tall. The group is mirrored
		-- between the two sides, as on the real ship, so it reads from the star outwards on each side
		local reading = side
		local start = if side < 0 then 312 else 268
		local function along(s: number, z: number): CFrame
			return onHull(hullPlan(z), start + reading * s, z, side, 0.12)
		end
		local outward = Vector3.new(0, 0, side)
		star(livery, along(5, 6.0).Position, outward, Vector3.yAxis, 5.2, NAVY, WHITE, NAVY)
		words(sign(livery, along(17.5, 5.9), 14, 5.0), "MSC", 0, 0, 1, 1, NAVY, Enum.Font.Garamond)
	end
	-- Name and port of registry across the stern
	local stern = CFrame.fromMatrix(at(331.56, 0, 15.75), Vector3.zAxis, Vector3.yAxis)
	words(sign(livery, stern, 19, 1.7), "MSC PREZIOSA", 0, 0, 1, 1, NAVY, Enum.Font.Garamond)
	local port = CFrame.fromMatrix(at(331.56, 0, 12.45), Vector3.zAxis, Vector3.yAxis)
	words(sign(livery, port, 6, 0.7), "PANAMA", 0, 0, 1, 1, NAVY, Enum.Font.Garamond)
	return livery
end

-- The bridge front: a heavy white roof over the window band and wings, struts under the wings,
-- and white parapets round the terraces stepping up the front of decks 9-12
local function buildBridge(parent: Instance)
	local front = Instance.new("Model")
	front.Name = "Bridge"
	front.Parent = parent
	-- A heavy roof follows the curve of the bridge and wings, overhanging the windows but stopping
	-- flush with the wing ends
	local bridge = PLAN[13][1]
	local roof = {}
	for _, p in widen(clip(bridge, bridge[1][1], 57), 0.9) do
		table.insert(roof, { p[1], math.min(p[2], 23.59) })
	end
	slab(front, "BridgeRoof", roof, FLOOR[14] - 0.55, FLOOR[14] + 0.65, WHITE)
	box(
		front,
		"BridgeRoof",
		bridge[1][1] - 1.0,
		bridge[1][1] + 0.2,
		-roof[1][2],
		roof[1][2],
		FLOOR[14] - 0.55,
		FLOOR[14] + 0.65,
		WHITE
	)
	edges(front, "WingRail", widen(roof, -0.1), FLOOR[14] + 0.65, 1.15, RAIL, M.Glass, 0.5)
	for _, x in { 48.5, 52.5 } do
		for _, side in { -1, 1 } do
			strut(
				front,
				"WingStrut",
				Vector3.new(x, side * (sample(PLAN[12][1], x) - 0.2), FLOOR[12] + 0.6),
				Vector3.new(x, side * 22.8, FLOOR[13] + 0.05),
				0.35,
				0.5,
				WHITE
			)
		end
	end
	for _, deck in { 9, 10, 11, 12 } do
		local above = if deck == 12 then 13 else deck + 1
		local outline = PLAN[deck][1]
		local terrace = clip(outline, outline[1][1], PLAN[above][1][1][1] + 2)
		edges(front, "Parapet", terrace, FLOOR[above], 1, WHITE, M.SmoothPlastic, 0)
		box(
			front,
			"Parapet",
			terrace[1][1],
			terrace[1][1] + 0.12,
			-terrace[1][2],
			terrace[1][2],
			FLOOR[above],
			FLOOR[above] + 1,
			WHITE
		)
		-- Each deck's front is capped by a white eyebrow that projects over the glazing below
		slab(front, "TerraceLip", widen(terrace, 2.0), FLOOR[above] - 0.65, FLOOR[above] + 0.15, WHITE)
	end
	return front
end

-- The white mast: a tower swept back from a raked fin, two platforms with radar scanners, a signal
-- pole and the dressing lines run down to the jackstaff over a smaller antenna pole
local function buildMast(parent: Instance)
	local mast = Instance.new("Model")
	mast.Name = "Mast"
	mast.Parent = parent
	box(mast, "MastBase", 104, 114, -3, 3, ROOF, ROOF + 3.5, WHITE)
	box(mast, "Mast", 107.5, 111.5, -1.3, 1.3, ROOF, 61.5, WHITE)
	wedge(mast, "Mast", at(107.5, 0, ROOF + 3.5), at(102, 0, ROOF + 3.5), at(107.5, 0, 61.5), 2.6 * STUDS, WHITE)
	for _, deck in { { 57.4, 8.5, 3.4 }, { 61.5, 6, 2.4 } } do
		local z, length, half = deck[1], deck[2], deck[3]
		box(mast, "MastPlatform", 109.5 - length / 2, 109.5 + length / 2, -half, half, z, z + 0.35, WHITE)
		edges(
			mast,
			"MastRail",
			{ { 109.5 - length / 2, half }, { 109.5 + length / 2, half } },
			z + 0.35,
			1,
			RAIL,
			M.Glass,
			0.4
		)
	end
	box(mast, "RadarScanner", 105.6, 106.4, -3.6, 3.6, 58.6, 58.9, STEEL, M.Metal)
	box(mast, "RadarScanner", 112.6, 113.4, -3, 3, 58.6, 58.9, STEEL, M.Metal)
	box(mast, "RadarScanner", 109.1, 109.9, -2.4, 2.4, 62.7, 63, STEEL, M.Metal)
	box(mast, "Mast", 109.2, 109.8, -0.3, 0.3, 61.85, 66.8, WHITE)
	box(mast, "MastYard", 109.3, 109.7, -4, 4, 64.6, 64.9, WHITE)
	box(mast, "AntennaPole", 84.8, 85.2, -0.2, 0.2, ROOF, ROOF + 6.5, WHITE)
	local top, pole, jack =
		Vector3.new(109.5, 0, 66), Vector3.new(85, 0, ROOF + 6.4), Vector3.new(1.55, 0, FLOOR[9] + 6.9)
	strut(mast, "DressingLine", top, pole, 0.05, 0.05, SOOT)
	strut(mast, "DressingLine", pole, jack, 0.05, 0.05, SOOT)
	return mast
end

-- The funnel: a tall, narrow slatted sail standing on the Top 18 deck abaft the Galaxy pavilion.
-- In side view its forward edge rises steeply to a crest about 13 m above the deck, the crest runs
-- aft with a slight crown, and the after edge sweeps down to the solarium. Two fans of horizontal
-- slats fall away from the crest to the deck, with a solid navy panel under the MSC compass on each
-- side and eight exhaust stacks breaking out along the top.
local FUNNEL_AT = { 242, 251, 277, 292 } -- forward foot, crest start/end, aft foot
local FUNNEL_TOP = 59.0
local FUNNEL_BASE = FLOOR[18]
local CREST = 1.35 -- half-breadth of the ridge
local FUNNEL_HALF = 7.6 -- half-breadth at the bottom of the slats

-- The height of the crest at station x
local function crest(x: number): number
	local a, b, c, d = FUNNEL_AT[1], FUNNEL_AT[2], FUNNEL_AT[3], FUNNEL_AT[4]
	if x < b then
		local t = math.clamp((x - a) / (b - a), 0, 1)
		return FUNNEL_BASE + (FUNNEL_TOP - FUNNEL_BASE) * t ^ 1.12
	elseif x <= c then
		return FUNNEL_TOP - 1.8 * ((x - (b + c) / 2) / ((c - b) / 2)) ^ 2
	end
	local t = math.clamp((x - c) / (d - c), 0, 1)
	return FUNNEL_TOP - 1.8 - (FUNNEL_TOP - 1.8 - FUNNEL_BASE) * t ^ 1.9
end

-- How far the slats reach out from the ridge at x: nearly the full breadth amidships, pinching in
-- towards the two feet
local function funnelHalf(x: number): number
	local a, d = FUNNEL_AT[1], FUNNEL_AT[4]
	local nose = math.clamp((x - a) / 11, 0, 1)
	local tail = math.clamp((d - x) / 10, 0, 1)
	return CREST + (FUNNEL_HALF - CREST) * math.sqrt(nose * tail)
end

-- A point on one fan at station x, v from the ridge (0) to the lower edge (1)
local function funnelPoint(x: number, v: number, side: number): Vector3
	local zc = crest(x)
	return Vector3.new(x, side * (CREST + (funnelHalf(x) - CREST) * v), zc - (zc - FUNNEL_BASE) * v)
end

local function buildFunnel(parent: Instance)
	local funnel = Instance.new("Model")
	funnel.Name = "Funnel"
	funnel.Parent = parent
	local a, d = FUNNEL_AT[1], FUNNEL_AT[4]
	local function world(p: Vector3): Vector3
		return at(p.X, p.Y, p.Z)
	end
	local function normal(x: number, v: number, side: number): Vector3
		local du = world(funnelPoint(x + 0.2, v, side)) - world(funnelPoint(x - 0.2, v, side))
		local dv = world(funnelPoint(x, v + 0.02, side)) - world(funnelPoint(x, v - 0.02, side))
		local n = du:Cross(dv)
		if n.Magnitude < 1e-6 then
			return Vector3.yAxis
		end
		n = n.Unit
		return if n.Z * side < 0 then -n else n
	end
	local SPANS = 28
	local function station(i: number): number
		return a + (d - a) * i / SPANS
	end
	-- The height of the sail surface at station x for a given z, on one side
	local function surfaceY(x: number, z: number, side: number): number
		local zc = crest(x)
		local v = math.clamp((zc - z) / math.max(zc - FUNNEL_BASE, 0.01), 0, 1)
		return side * (CREST + (funnelHalf(x) - CREST) * v)
	end
	-- The forward and after ends of the slat at height z
	local function xRange(z: number): (number, number)
		local xf, xa
		for i = 0, 200 do
			local x = a + (d - a) * i / 200
			if crest(x) >= z then
				xf = xf or x
				xa = x
			end
		end
		return xf or a, xa or d
	end
	for _, side in { -1, 1 } do
		-- Horizontal louvres, clipped by the sloping forward and after edges of the sail
		for k = 0, 19 do
			local z = FUNNEL_BASE + 0.55 + (FUNNEL_TOP - 2.1 - FUNNEL_BASE - 0.55) * k / 19
			local xf, xa = xRange(z)
			local edge = k == 0 or k == 19
			local x = xf
			while x < xa - 0.2 do
				local x2 = math.min(x + 2.2, xa)
				local v = math.clamp((crest(x) - z) / math.max(crest(x) - FUNNEL_BASE, 0.01), 0.05, 0.95)
				strut(
					funnel,
					if edge then "FunnelRib" else "Slat",
					Vector3.new(x, surfaceY(x, z, side), z),
					Vector3.new(x2, surfaceY(x2, z, side), z),
					if edge then 0.45 else 0.16,
					if edge then 0.4 else 0.17,
					FUNNEL,
					nil,
					normal((x + x2) / 2, v, side)
				)
				x = x2
			end
		end
		-- Ribs fanning down across the slats, spreading away from the emblem
		for x = a + 5, d - 4, 5.5 do
			local split = 4
			for j = 0, split do
				local v0, v1 = j / (split + 1), (j + 1) / (split + 1)
				strut(
					funnel,
					"FunnelRib",
					funnelPoint(x + (x - 264) * 0.1 * v0, v0, side),
					funnelPoint(x + (x - 264) * 0.1 * v1, v1, side),
					0.3,
					0.32,
					FUNNEL
				)
			end
		end
		-- Solid plating behind the slats under the emblem
		local cells, rows = 9, 5
		local function inner(i: number, j: number): Vector3
			local x, v = 254 + 22 * i / cells, 0.12 + 0.76 * j / rows
			return world(funnelPoint(x, v, side)) - normal(x, v, side) * 0.28 * STUDS
		end
		for i = 0, cells - 1 do
			for j = 0, rows - 1 do
				local outward = normal(254 + 22 * (i + 0.5) / cells, 0.12 + 0.76 * (j + 0.5) / rows, side)
				triangle(funnel, "FunnelPlating", inner(i, j), inner(i + 1, j), inner(i, j + 1), outward, 0.2, FUNNEL)
				triangle(
					funnel,
					"FunnelPlating",
					inner(i + 1, j),
					inner(i + 1, j + 1),
					inner(i, j + 1),
					outward,
					0.2,
					FUNNEL
				)
			end
		end
		-- The compass emblem in the middle of the plating
		local emblemX, emblemV = 260, 0.5
		local n = normal(emblemX, emblemV, side)
		local up = (Vector3.yAxis - n * Vector3.yAxis:Dot(n)).Unit
		star(
			funnel,
			world(funnelPoint(emblemX, emblemV, side)) + n * 0.7 * STUDS,
			n,
			up,
			3.8,
			WHITE,
			WHITE,
			FUNNEL
		)
	end
	-- A white structural beam down the leading edge, as on the real funnel
	for _, side in { -1, 1 } do
		strut(
			funnel,
			"FunnelEdge",
			Vector3.new(FUNNEL_AT[1], side * funnelHalf(FUNNEL_AT[1]), FUNNEL_BASE),
			Vector3.new(FUNNEL_AT[2], side * CREST, crest(FUNNEL_AT[2])),
			0.35,
			0.4,
			WHITE
		)
	end
	-- A narrow navy cap along the crest
	for i = 0, SPANS - 1 do
		local z0, z1 = crest(station(i)), crest(station(i + 1))
		strut(
			funnel,
			"FunnelRib",
			Vector3.new(station(i), 0, z0 + 0.15),
			Vector3.new(station(i + 1), 0, z1 + 0.15),
			2 * CREST + 0.45,
			0.45,
			FUNNEL,
			nil,
			Vector3.yAxis
		)
	end
	-- Eight stacks in four pairs along the crest, splaying and leaning aft, sooty at the top
	for i, x in { 256, 262.5, 269, 275.5 } do
		for _, y in { -1.15, 1.15 } do
			local baseZ = crest(x) - 0.9
			local base = Vector3.new(x, y, baseZ)
			local top = base + Vector3.new(2.4, y * 0.55, (if i == 3 or i == 4 then 60.9 else 60.4) - baseZ)
			tube(funnel, "ExhaustStack", base, top, 1.85, STEEL, M.Metal)
			local dir = top - base
			tube(funnel, "ExhaustStack", top - dir * 0.06, top + dir * 0.03, 1.9, SOOT, M.Metal)
		end
	end
	-- A white rail around the foot of the funnel, tying it to the Top 18 deck
	for _, side in { -1, 1 } do
		sideBox(funnel, "FunnelBaseRail", 246, 287, side * 9.4, side * 9.6, FUNNEL_BASE, FUNNEL_BASE + 0.9, WHITE)
	end
	return funnel
end

-- A smooth curve through ship-coordinate points (Catmull-Rom), `steps` samples per span
local function spline(points: { Vector3 }, steps: number): { Vector3 }
	local out = {}
	for i = 1, #points - 1 do
		local p0, p1, p2 = points[math.max(i - 1, 1)], points[i], points[i + 1]
		local p3 = points[math.min(i + 2, #points)]
		for s = 0, steps - 1 do
			local t = s / steps
			table.insert(
				out,
				0.5
					* (
						2 * p1
						+ (p2 - p0) * t
						+ (2 * p0 - 5 * p1 + 4 * p2 - p3) * (t * t)
						+ (3 * p1 - p0 - 3 * p2 + p3) * (t * t * t)
					)
			)
		end
	end
	table.insert(out, points[#points])
	return out
end

-- An open white tower up to a slide start platform at `start`, landings every 2.4 m
local function slideTower(parent: Instance, start: Vector3)
	local floor = floorAt(start.X, start.Y) or ROOF
	for _, corner in { { -1.4, -1.4 }, { -1.4, 1.4 }, { 1.4, -1.4 }, { 1.4, 1.4 } } do
		local x, y = start.X + corner[1], start.Y + corner[2]
		box(parent, "SlideTower", x - 0.15, x + 0.15, y - 0.15, y + 0.15, floor, start.Z + 0.4, WHITE)
	end
	for z = floor + 2.4, start.Z - 1.5, 2.4 do
		box(parent, "SlideTower", start.X - 1.55, start.X + 1.55, start.Y - 1.55, start.Y + 1.55, z, z + 0.2, WHITE)
	end
	box(
		parent,
		"SlidePlatform",
		start.X - 1.6,
		start.X + 1.6,
		start.Y - 1.6,
		start.Y + 1.6,
		start.Z - 0.9,
		start.Z - 0.7,
		WHITE
	)
end

-- A navy water slide tube along a path, on posts down to the decks
local function slide(parent: Instance, path: { Vector3 })
	local curve = spline(path, 6)
	for i = 1, #curve - 1 do
		tube(parent, "WaterSlide", curve[i], curve[i + 1], 1.3, FUNNEL)
		local p = curve[i]
		local below = floorAt(p.X, p.Y)
		if i % 7 == 4 and below and p.Z - below > 1.2 then
			strut(parent, "SlidePost", Vector3.new(p.X, p.Y, p.Z - 0.6), Vector3.new(p.X, p.Y, below), 0.3, 0.3, WHITE)
		end
	end
end

-- Rows of sun loungers either side of the centre line, one row `rows[i]` out from it
local function loungers(parent: Instance, x0: number, x1: number, rows: { number }, z: number)
	for x = x0, x1, 1.25 do
		for _, y in rows do
			for _, side in { -1, 1 } do
				box(parent, "Lounger", x - 0.35, x + 0.35, side * y - 0.95, side * y + 0.95, z, z + 0.35, WHITE)
			end
		end
	end
end

-- Midships between the Yacht Club and the funnel block, deck 15 is the enclosed La Playa
-- Preziosa: long windows outside, an atrium over the indoor pools, and on its roof a sun deck round
-- the sliding glass roof (magrodome) over the atrium. Panoramic lifts climb the front of the
-- funnel block behind it.
local LIDO = { 117, 202 }
local ATRIUM = { 150, 197, 12 } -- from, to, half-breadth
local function buildLido(parent: Instance)
	local lido = Instance.new("Model")
	lido.Name = "La Playa"
	lido.Parent = parent
	local outline = clip(PLAN[15][1], LIDO[1], LIDO[2])
	local z0, z1 = FLOOR[15], FLOOR[16]
	local x0, x1, inner = ATRIUM[1], ATRIUM[2], ATRIUM[3]
	local outer = sample(outline, (x0 + x1) / 2)

	-- The ring of rooms round the atrium: long windows outside, gallery windows inside
	slab(lido, "Wall", clip(outline, LIDO[1], x0), z0, z1, WHITE)
	slab(lido, "Wall", clip(outline, x1, LIDO[2]), z0, z1, WHITE)
	for _, side in { -1, 1 } do
		sideBox(lido, "Wall", x0, x1, side * inner, side * outer, z0, z1, WHITE)
		sideBox(lido, "Windows", x0 + 1, x1 - 1, side * (inner - 0.06), side * inner, z0 + 0.9, z1 - 0.5, GLASS)
	end
	for a = LIDO[1] + 0.6, LIDO[2] - 2, 13.5 do
		local pane = clip(outline, a + 0.75, math.min(a + 12.75, LIDO[2] - 0.6))
		if #pane > 1 then
			slab(lido, "Windows", widen(pane, 0.06), z0 + 0.9, z1 - 0.7, GLASS)
		end
	end

	-- The sun deck round the dome (the Yacht Club block covers the roof forward of x 146)
	local deck = widen(clip(outline, 146, LIDO[2]), -0.3)
	slab(lido, "SunDeck", clip(deck, 146, x0), z1 - 0.05, z1 + 0.05, TEAK, M.WoodPlanks)
	slab(lido, "SunDeck", clip(deck, x1, LIDO[2]), z1 - 0.05, z1 + 0.05, TEAK, M.WoodPlanks)
	for _, side in { -1, 1 } do
		sideBox(
			lido,
			"SunDeck",
			x0,
			x1,
			side * (inner + 0.3),
			side * (outer - 0.3),
			z1 - 0.05,
			z1 + 0.05,
			TEAK,
			M.WoodPlanks
		)
		sideBox(lido, "DomeCurb", x0, x1, side * (inner - 0.1), side * (inner + 0.3), z1, z1 + 0.45, WHITE)
	end
	edges(lido, "DeckRail", deck, z1, 1.1, RAIL, M.Glass, 0.5)
	loungers(lido, x0 + 2, x1 - 2, { (inner + outer) / 2 }, z1 + 0.05)

	-- The magrodome: a low glass vault on white ribs, glazed at both ends
	local span, rise = inner + 0.1, 4.2
	local function vault(j: number): Vector3
		local t = math.pi * j / 8
		return Vector3.new(0, -span * math.cos(t), z1 + 0.55 + rise * math.sin(t))
	end
	for j = 0, 7 do
		local p, q = vault(j), vault(j + 1)
		local mid = (p + q) / 2
		local chord = q - p
		local pane = strut(
			lido,
			"Magrodome",
			Vector3.new(x0, mid.Y, mid.Z),
			Vector3.new(x1, mid.Y, mid.Z),
			chord.Magnitude,
			0.08,
			RAIL,
			M.Glass,
			Vector3.new(0, chord.Y, -chord.Z)
		)
		if pane then
			pane.Transparency = 0.4
			pane.CastShadow = false
		end
		for _, x in (if math.min(p.Z, q.Z) > z1 + 0.65 then { x0, x1 } else {}) do
			local gable =
				sideBox(lido, "Magrodome", x - 0.05, x + 0.05, p.Y, q.Y, z1 + 0.55, math.min(p.Z, q.Z), RAIL, M.Glass)
			gable.Transparency = 0.4
			gable.CastShadow = false
		end
	end
	for x = x0, x1 + 0.01, (x1 - x0) / 12 do
		for j = 0, 7 do
			local p, q = vault(j), vault(j + 1)
			strut(lido, "DomeRib", Vector3.new(x, p.Y, p.Z), Vector3.new(x, q.Y, q.Z), 0.25, 0.3, WHITE)
		end
	end
	local crown = vault(4)
	box(lido, "DomeRib", x0, x1, -0.2, 0.2, crown.Z, crown.Z + 0.3, WHITE)

	-- Panoramic lifts in glass towers on the front of the funnel block
	for _, side in { -1, 1 } do
		local shaft = sideBox(lido, "PanoramicLift", 198.5, 202.5, side * 5, side * 9, z1, ROOF + 1.1, RAIL, M.Glass)
		shaft.Transparency = 0.3
		for _, x in { 198.5, 202.5 } do
			for _, y in { 5, 9 } do
				sideBox(
					lido,
					"LiftFrame",
					x - 0.15,
					x + 0.15,
					side * (y - 0.15),
					side * (y + 0.15),
					z1,
					ROOF + 1.3,
					WHITE
				)
			end
		end
		for z = z1 + 3, ROOF + 1, 3 do
			sideBox(lido, "LiftFrame", 198.35, 202.65, side * 4.85, side * 9.15, z, z + 0.2, WHITE)
		end
	end
	return lido
end

-- The Yacht Club's open top deck: The One Pool and whirlpools behind the Top Sail Lounge, ringed
-- by a glass windbreak on the roof of the club's two cabin decks
local function buildYachtClubTop(parent: Instance)
	local club = Instance.new("Model")
	club.Name = "Yacht Club Sun Deck"
	club.Parent = parent
	local roof = widen(clip(PLAN[16][1], 58, 146), -0.25)
	slab(club, "SunDeck", roof, FLOOR[18] - 0.05, FLOOR[18] + 0.05, TEAK, M.WoodPlanks)
	edges(club, "DeckRail", roof, FLOOR[18], 1.15, RAIL, M.Glass, 0.5)
	-- The One Pool
	box(club, "PoolRim", 82.4, 102.6, -6.2, 6.2, FLOOR[18], FLOOR[18] + 0.32, WHITE)
	box(club, "Pool", 83, 102, -5.6, 5.6, FLOOR[18] + 0.32, FLOOR[18] + 0.4, POOL)
	-- Two whirlpools either side of the pool, and The One Bar aft of it
	for _, side in { -1, 1 } do
		tube(
			club,
			"Whirlpool",
			Vector3.new(111, side * 8.2, FLOOR[18]),
			Vector3.new(111, side * 8.2, FLOOR[18] + 0.55),
			3.0,
			WHITE
		)
		tube(
			club,
			"Whirlpool",
			Vector3.new(111, side * 8.2, FLOOR[18] + 0.3),
			Vector3.new(111, side * 8.2, FLOOR[18] + 0.62),
			2.4,
			POOL
		)
	end
	box(club, "BarCounter", 119, 131, -3.6, 3.6, FLOOR[18], FLOOR[18] + 1.1, WHITE)
	for _, post in { { 119.2, -3.4 }, { 130.8, -3.4 }, { 119.2, 3.4 }, { 130.8, 3.4 } } do
		box(
			club,
			"BarPost",
			post[1] - 0.12,
			post[1] + 0.12,
			post[2] - 0.12,
			post[2] + 0.12,
			FLOOR[18],
			FLOOR[18] + 2.9,
			WHITE
		)
	end
	box(club, "BarCanopy", 118.4, 131.6, -4.2, 4.2, FLOOR[18] + 2.9, FLOOR[18] + 3.1, WHITE)
	loungers(club, 104, 116, { 12.5 }, FLOOR[18] + 0.05)
	loungers(club, 134, 143, { 6.5, 11, 15 }, FLOOR[18] + 0.05)

	-- The Top Sail Lounge: a rounded white and glass crown at the forward end of the deck, its
	-- dark glazing rising above the pool deck
	local crown = widen(clip(PLAN[16][1], 60, 78), -0.45)
	slab(club, "TopSailLounge", crown, FLOOR[18], FLOOR[18] + 4.0, WHITE)
	glazing(club, "LoungeGlass", crown, FLOOR[18] + 0.6, FLOOR[18] + 3.7)
	mullions(club, widen(crown, 0.1), FLOOR[18] + 0.6, FLOOR[18] + 3.7, 1.5, true)
	slab(club, "LoungeRoof", widen(crown, 0.55), FLOOR[18] + 4.0, FLOOR[18] + 4.3, WHITE)
	edges(club, "LoungeRail", widen(crown, 0.1), FLOOR[18] + 4.3, 0.85, RAIL, M.Glass, 0.5)
	-- Close the lounge's after face over the pool deck
	local crownEnd = crown[#crown]
	box(
		club,
		"LoungeWall",
		crownEnd[1] - 0.2,
		crownEnd[1] + 0.05,
		-crownEnd[2],
		crownEnd[2],
		FLOOR[18],
		FLOOR[18] + 4.0,
		WHITE
	)
	box(
		club,
		"LoungeGlass",
		crownEnd[1] - 0.1,
		crownEnd[1] + 0.1,
		-crownEnd[2] + 0.5,
		crownEnd[2] - 0.5,
		FLOOR[18] + 0.6,
		FLOOR[18] + 3.7,
		GLASS,
		M.Glass
	)
	return club
end

-- A rounded silhouette for the funnel casing and the Top 18 platform
local CASING = { { 238, 8.6 }, { 241, 10.2 }, { 285, 10.2 }, { 288, 8.2 } }
local TOP18 = {
	{ 238, 5.6 },
	{ 240, 8.8 },
	{ 244, 11.3 },
	{ 250, 12.4 },
	{ 282, 12.4 },
	{ 286, 10.8 },
	{ 290, 7.4 },
	{ 292, 4.6 },
}

-- The aft top of the ship: the round Galaxy/Sky & Stars pavilion over the stern-facing terraces,
-- its roof carrying the Top 18 solarium and the funnel, and the open deck 16 solarium, bar and
-- children's aqua park aft of it
local function buildAftTop(parent: Instance)
	local aft = Instance.new("Model")
	aft.Name = "Aft Sun Decks"
	aft.Parent = parent
	local floor16, roof = FLOOR[16], FLOOR[18]
	local deck16 = clip(PLAN[16][2], 202, 316)
	local pav = clip(PLAN[16][2], 202, 240)

	-- The open deck 16 roof over the Garden terraces, with its white bulwark and glass windbreak
	slab(aft, "Solarium", widen(deck16, -0.2), floor16 - 0.06, floor16 + 0.04, TEAK, M.WoodPlanks)
	edges(aft, "Bulwark", widen(deck16, -0.25), floor16, 1.15, WHITE, M.SmoothPlastic, 0)
	edges(aft, "DeckRail", widen(deck16, -0.25), floor16 + 1.15, 1.0, RAIL, M.Glass, 0.5)

	-- The Galaxy Restaurant / Sky & Stars pavilion: two storeys of dark panoramic glazing with
	-- white piers, under a white overhanging roof
	slab(aft, "Pavilion", pav, floor16, roof + 0.55, WHITE)
	for _, band in { { floor16 + 0.65, floor16 + 1.55 }, { floor16 + 1.9, floor16 + 2.9 } } do
		glazing(aft, "PavilionGlass", pav, band[1], band[2])
		mullions(aft, widen(pav, 0.1), band[1], band[2], 1.8, true)
	end
	slab(aft, "PavilionRoof", widen(pav, 0.6), roof + 0.55, roof + 0.85, WHITE)
	edges(aft, "RoofRail", widen(pav, 0.1), roof + 0.85, 0.9, RAIL, M.Glass, 0.5)
	-- The Galaxy roof is an open teak terrace with a glazed skylight over the restaurant
	slab(aft, "PavilionSunDeck", widen(pav, -1.2), roof + 0.85, roof + 0.95, TEAK, M.WoodPlanks)
	box(aft, "PavilionSkylight", 212, 226, -5, 5, roof + 0.85, roof + 0.98, TINTED, M.Glass)
	loungers(aft, 206, 236, { 6, 10 }, roof + 0.95)

	-- Close the pavilion's after face against the funnel casing
	local pavEnd = pav[#pav]
	box(aft, "PavilionWall", pavEnd[1] - 0.2, pavEnd[1] + 0.05, -pavEnd[2], pavEnd[2], floor16, roof + 0.55, WHITE)
	-- White casing below the Top 18 platform, with a dark glazed band
	slab(aft, "FunnelCasing", CASING, floor16, roof, WHITE)
	box(aft, "CasingEnd", 238 - 0.2, 238 + 0.05, -8.6, 8.6, floor16, roof, WHITE)
	box(aft, "CasingEnd", 288 - 0.2, 288 + 0.05, -8.2, 8.2, floor16, roof, WHITE)
	for _, side in { -1, 1 } do
		sideBox(aft, "CasingWindows", 242, 284, side * 10.05, side * 10.25, floor16 + 0.8, floor16 + 2.1, GLASS)
		for x = 244, 282, 2.6 do
			sideBox(
				aft,
				"CasingMullion",
				x - 0.08,
				x + 0.08,
				side * 10.18,
				side * 10.34,
				floor16 + 0.8,
				floor16 + 2.1,
				WHITE
			)
		end
	end

	-- The Top 18 solarium round the funnel, with two whirlpools and rows of loungers
	slab(aft, "Top18", widen(TOP18, -0.15), roof - 0.05, roof + 0.05, TEAK, M.WoodPlanks)
	edges(aft, "Top18Bulwark", widen(TOP18, -0.2), roof - 0.2, 0.4, WHITE, M.SmoothPlastic, 0)
	edges(aft, "Top18Rail", widen(TOP18, -0.2), roof + 0.2, 1.05, RAIL, M.Glass, 0.5)
	for _, side in { -1, 1 } do
		tube(
			aft,
			"Whirlpool",
			Vector3.new(278, side * 10.5, roof),
			Vector3.new(278, side * 10.5, roof + 0.55),
			2.6,
			WHITE
		)
		tube(
			aft,
			"Whirlpool",
			Vector3.new(278, side * 10.5, roof + 0.3),
			Vector3.new(278, side * 10.5, roof + 0.62),
			2.1,
			POOL
		)
	end
	loungers(aft, 246, 266, { 11.2 }, roof + 0.05)

	-- Doremi Castle water play on deck 16 (port aft), with the Brezza Marina bar and hot tubs
	local floor = floor16
	box(aft, "AquaPark", 293, 309, -9.2, -1.4, floor, floor + 0.12, rgb(86, 164, 224))
	box(aft, "AquaPark", 294.5, 307.5, -8.7, -2.1, floor + 0.12, floor + 0.17, rgb(236, 242, 246))
	for _, post in { { 296, -7.6 }, { 296, -3.2 }, { 303, -7.6 }, { 303, -3.2 } } do
		box(
			aft,
			"AquaPark",
			post[1] - 0.18,
			post[1] + 0.18,
			post[2] - 0.18,
			post[2] + 0.18,
			floor,
			floor + 4.2,
			rgb(250, 202, 40)
		)
	end
	box(aft, "AquaPark", 295.7, 303.4, -7.9, -2.9, floor + 1.9, floor + 2.15, rgb(250, 202, 40))
	box(aft, "AquaPark", 295.4, 298.7, -8.1, -5.6, floor + 4.2, floor + 5.0, rgb(140, 70, 170))
	box(aft, "AquaPark", 300.4, 303.6, -5.2, -2.8, floor + 4.2, floor + 5.0, rgb(66, 170, 88))
	box(aft, "AquaPark", 305, 307.4, -4.6, -2.6, floor, floor + 1.7, rgb(248, 136, 36))
	tube(
		aft,
		"AquaPark",
		Vector3.new(300, -2.4, floor + 3.4),
		Vector3.new(300, -2.4, floor + 4.4),
		2.0,
		rgb(250, 202, 40)
	)
	for _, y in { -7.2, -6.0 } do
		strut(
			aft,
			"AquaPark",
			Vector3.new(303.4, y, floor + 2.0),
			Vector3.new(308.8, y, floor + 0.25),
			0.9,
			0.28,
			rgb(216, 40, 40)
		)
	end
	-- Brezza Marina bar and two starboard hot tubs
	box(aft, "BarCounter", 295, 307, 2.8, 8.2, floor, floor + 1.0, WHITE)
	box(aft, "BarCanopy", 294.5, 307.5, 2.3, 8.7, floor + 2.8, floor + 3.0, WHITE)
	for _, post in { { 295.2, 3 }, { 306.8, 3 }, { 295.2, 8 }, { 306.8, 8 } } do
		box(aft, "BarPost", post[1] - 0.12, post[1] + 0.12, post[2] - 0.12, post[2] + 0.12, floor, floor + 2.8, WHITE)
	end
	for _, side in { -1, 1 } do
		tube(
			aft,
			"Whirlpool",
			Vector3.new(311, side * 5.8, floor),
			Vector3.new(311, side * 5.8, floor + 0.5),
			2.4,
			WHITE
		)
		tube(
			aft,
			"Whirlpool",
			Vector3.new(311, side * 5.8, floor + 0.28),
			Vector3.new(311, side * 5.8, floor + 0.56),
			1.9,
			POOL
		)
	end
	loungers(aft, 310, 314, { 10.5 }, floor + 0.05)

	-- Big blue slides from a tower behind the funnel down to the Garden Pool, and a short one into
	-- the children's aqua park
	local tower = Vector3.new(298, -5.5, 49.2)
	slideTower(aft, tower)
	slide(aft, {
		tower,
		Vector3.new(304, -9.2, 48.2),
		Vector3.new(312, -11, 46.4),
		Vector3.new(318, -9.6, 43.8),
		Vector3.new(322, -7.2, 41.4),
		Vector3.new(323.5, -5.2, 39.8),
	})
	slide(aft, {
		tower,
		Vector3.new(295, -7.4, 48.4),
		Vector3.new(291, -8.4, 46.2),
		Vector3.new(290.5, -6.4, 44.0),
		Vector3.new(292.5, -5.2, 42.6),
	})
	return aft
end

-- The Yacht Club's Garden at the stern of deck 15: La Palmeraie restaurant forward, then the
-- infinity-edge Garden Pool in a teak terrace enclosed by a white bulwark and a glass windbreak
local function buildGarden(parent: Instance)
	local garden = Instance.new("Model")
	garden.Name = "The Garden"
	garden.Parent = parent
	local floor = FLOOR[15]
	local deck = widen(clip(PLAN[15][1], 296, 334), -0.2)
	slab(garden, "GardenDeck", deck, floor - 0.05, floor + 0.05, TEAK, M.WoodPlanks)
	edges(garden, "GardenBulwark", widen(deck, -0.15), floor, 1.15, WHITE, M.SmoothPlastic, 0)
	edges(garden, "GardenGlass", widen(deck, -0.15), floor + 1.15, 1.0, RAIL, M.Glass, 0.55)

	-- La Palmeraie, the Yacht Club's dedicated restaurant, under a white overhanging roof
	local rest = widen(clip(PLAN[15][1], 300, 313), -0.55)
	slab(garden, "LaPalmeraie", rest, floor, floor + 2.7, WHITE)
	for _, band in { { floor + 0.55, floor + 1.45 }, { floor + 1.75, floor + 2.55 } } do
		glazing(garden, "RestaurantGlass", rest, band[1], band[2])
		mullions(garden, widen(rest, 0.1), band[1], band[2], 1.9, true)
	end
	slab(garden, "RestaurantRoof", widen(rest, 0.55), floor + 2.7, floor + 3.0, WHITE)
	edges(garden, "RoofRail", widen(rest, 0.1), floor + 3.0, 0.9, RAIL, M.Glass, 0.5)
	slab(garden, "RestaurantSunDeck", widen(rest, -0.7), floor + 3.0, floor + 3.05, TEAK, M.WoodPlanks)
	-- Close the restaurant's after face over the Garden Pool
	local restEnd = rest[#rest]
	box(
		garden,
		"RestaurantWall",
		restEnd[1] - 0.2,
		restEnd[1] + 0.05,
		-restEnd[2],
		restEnd[2],
		floor,
		floor + 2.7,
		WHITE
	)
	box(
		garden,
		"RestaurantGlass",
		restEnd[1] - 0.1,
		restEnd[1] + 0.1,
		-restEnd[2] + 0.4,
		restEnd[2] - 0.4,
		floor + 0.55,
		floor + 2.55,
		GLASS,
		M.Glass
	)

	-- The Garden Pool, with a white rim and loungers on the teak round it
	box(garden, "PoolRim", 316.5, 330.5, -6.2, 6.2, floor, floor + 0.32, WHITE)
	box(garden, "Pool", 317.1, 329.9, -5.6, 5.6, floor + 0.32, floor + 0.4, POOL)
	loungers(garden, 318, 327, { 8.4 }, floor + 0.05)
	for _, side in { -1, 1 } do
		for _, x in { 303, 309, 315, 321, 327 } do
			box(
				garden,
				"Planter",
				x - 0.6,
				x + 0.6,
				side * 9.2 - 0.6,
				side * 9.2 + 0.6,
				floor,
				floor + 0.75,
				rgb(54, 112, 62)
			)
		end
	end
	-- The Garden Bar on the port side of the pool
	box(garden, "BarCounter", 314, 318, -10.2, -6.8, floor, floor + 1.0, WHITE)
	box(garden, "BarCanopy", 313.4, 318.6, -10.8, -6.2, floor + 2.7, floor + 2.9, WHITE)
	for _, post in { { 314.2, -9.9 }, { 317.8, -9.9 }, { 314.2, -7.1 }, { 317.8, -7.1 } } do
		box(
			garden,
			"BarPost",
			post[1] - 0.12,
			post[1] + 0.12,
			post[2] - 0.12,
			post[2] + 0.12,
			floor,
			floor + 2.7,
			WHITE
		)
	end
	return garden
end

local function buildTop(parent: Instance)
	local top = Instance.new("Model")
	top.Name = "Superstructure"
	top.Parent = parent

	-- The foredeck over the mooring deck, with its bulwark
	local foredeck = clip(PLAN[8][1], 0, 31)
	slab(top, "Foredeck", foredeck, FLOOR[9], FLOOR[9] + 0.1, MOORING)
	edges(top, "Bulwark", foredeck, FLOOR[9], 1.2, WHITE, M.SmoothPlastic, 0)
	box(top, "Jackstaff", 1.4, 1.7, -0.15, 0.15, FLOOR[9], FLOOR[9] + 7, WHITE)

	-- Teak over deck 14, and the glass rails round the open pool deck
	slab(top, "PoolDeck", widen(DECK14, -0.05), FLOOR[15] - 0.05, FLOOR[15] + 0.05, TEAK, M.WoodPlanks)
	edges(top, "DeckRail", PLAN[15][1], FLOOR[15], 1.2, RAIL, M.Glass, 0.5)

	-- The two indoor pools under the magrodome of La Playa Preziosa
	for _, pool in { { 158, 174, 5 }, { 181, 196, 4 } } do
		box(
			top,
			"PoolRim",
			pool[1] - 0.6,
			pool[2] + 0.6,
			-pool[3] - 0.6,
			pool[3] + 0.6,
			FLOOR[15],
			FLOOR[15] + 0.25,
			WHITE
		)
		box(top, "Pool", pool[1], pool[2], -pool[3], pool[3], FLOOR[15] + 0.25, FLOOR[15] + 0.3, POOL)
	end
	buildLido(top)
	buildYachtClubTop(top)
	buildAftTop(top)
	buildGarden(top)

	-- Brackets under deck 14 where it overhangs the lifeboats, one between each pair of boats
	for i = -1, 11 do
		local x = 124 + (i + 0.5) * 13.3
		if x > 118.5 and x < 275.5 then
			for _, side in { -1, 1 } do
				strut(
					top,
					"Bracket",
					Vector3.new(x, side * (sample(PLAN[12][1], x) - 0.1), FLOOR[12] + 0.2),
					Vector3.new(x, side * 17.5, FLOOR[14] - 0.05),
					0.3,
					0.45,
					WHITE
				)
			end
		end
	end
	for _, side in { -1, 1 } do
		sideBox(top, "EdgeGirder", 117, 283, side * 17.2, side * 17.8, FLOOR[14] - 0.55, FLOOR[14], WHITE)
	end

	-- Radomes on the Yacht Club roof and the Galaxy roof
	for _, dome in { { 92, -14, 4.8 }, { 92, 14, 4.8 }, { 104, -6, 3.6 }, { 104, 6, 3.6 }, { 210, 11, 4.6 } } do
		local base = if dome[1] > 200 then FLOOR[18] + 0.85 else FLOOR[18]
		part(
			top,
			"Radome",
			Vector3.one * dome[3] * STUDS,
			CFrame.new(at(dome[1], dome[2], base + 0.4 + dome[3] / 2)),
			WHITE,
			M.SmoothPlastic
		).Shape =
			Enum.PartType.Ball
		box(top, "RadomeBase", dome[1] - 1, dome[1] + 1, dome[2] - 1, dome[2] + 1, base, base + 0.6, WHITE)
	end

	buildBridge(top)
	buildMast(top)
	buildFunnel(top)
	return top
end

-- An enclosed lifeboat (orange canopy over a white hull, red helm position aft) or, for the
-- tenders, a white boat with a band of cabin windows under a red-orange roof, hanging from two
-- davits
local function lifeboat(parent: Instance, x: number, side: number, tender: boolean)
	local length, beam = if tender then 12.6 else 10.8, if tender then 4.4 else 4.0
	local y, half = side * 18.4, beam / 2
	local bow = x - length / 2
	local function outline(inset: number)
		local h = half - inset
		return {
			{ bow + 0.2 + inset * 1.5, h * 0.3 },
			{ bow + length * 0.2, h },
			{ bow + length * 0.85, h },
			{ bow + length - inset, h * 0.6 },
		}
	end
	local function station(f: number): number
		return bow + length * f
	end
	box(parent, "Keel", station(0.12), station(0.92), y - half * 0.45, y + half * 0.45, 13.7, 14.3, WHITE)
	slab(parent, "Hull", outline(0), 14.3, 15.4, WHITE, nil, y)
	for _, s in { -1, 1 } do
		sideBox(
			parent,
			"Fender",
			station(0.2),
			station(0.85),
			y + s * (half - 0.05),
			y + s * (half + 0.06),
			15.15,
			15.4,
			if tender then NAVY else HELM
		)
	end
	if tender then
		slab(parent, "Cabin", outline(0.25), 15.4, 16.9, WHITE, nil, y)
		slab(parent, "CabinWindows", outline(0.2), 15.9, 16.4, GLASS, nil, y)
		box(parent, "Roof", station(0.16), station(0.9), y - half + 0.7, y + half - 0.7, 16.9, 17.3, HELM)
		box(parent, "Helm", station(0.6), station(0.8), y - half * 0.4, y + half * 0.4, 17.3, 17.9, HELM)
		box(
			parent,
			"HelmWindows",
			station(0.6) - 0.04,
			station(0.8) + 0.04,
			y - half * 0.4 - 0.04,
			y + half * 0.4 + 0.04,
			17.5,
			17.75,
			GLASS
		)
	else
		slab(parent, "Canopy", outline(0.15), 15.4, 16.5, ORANGE, nil, y)
		box(parent, "Canopy", station(0.15), station(0.9), y - half + 0.6, y + half - 0.6, 16.5, 16.85, ORANGE)
		box(parent, "Helm", station(0.6), station(0.8), y - half * 0.45, y + half * 0.45, 16.5, 17.35, HELM)
		box(
			parent,
			"HelmWindows",
			station(0.6) - 0.04,
			station(0.8) + 0.04,
			y - half * 0.45 - 0.04,
			y + half * 0.45 + 0.04,
			16.95,
			17.2,
			GLASS
		)
		for _, s in { -1, 1 } do
			sideBox(
				parent,
				"Portlights",
				station(0.22),
				station(0.55),
				y + s * (half - 0.17),
				y + s * (half - 0.1),
				15.8,
				16.1,
				GLASS
			)
		end
	end
	-- Davits: posts against the promenade wall, arms reaching out over the boat, and the falls
	local roof = if tender then 17.9 else 17.35
	for _, f in { 0.22, 0.8 } do
		local xd = station(f)
		sideBox(parent, "Davit", xd - 0.18, xd + 0.18, side * 16, side * 16.3, FLOOR[7], 18.9, WHITE)
		local tip = Vector3.new(xd, y, 18.4)
		strut(parent, "Davit", Vector3.new(xd, side * 16.15, 18.9), tip, 0.3, 0.35, WHITE)
		strut(parent, "Fall", tip, Vector3.new(xd, y, roof), 0.05, 0.05, SOOT)
	end
end

local function buildLifeboats(parent: Instance)
	local boats = Instance.new("Model")
	boats.Name = "Lifeboats"
	boats.Parent = parent
	-- Twelve boats a side hang in the deck 7 recess; the three aftmost are the larger tenders
	for i = 0, 11 do
		for _, side in { -1, 1 } do
			lifeboat(boats, 124 + i * 13.3, side, i >= 9)
		end
	end
	return boats
end

function MscPreziosa.build(parent: Instance, position: Vector3, yield: (() -> ())?): Model
	origin = position
	built = 0
	pause = yield or task.wait
	resumed = os.clock()
	local ship = Instance.new("Model")
	ship.Name = "MSC Preziosa"

	buildHull(ship)
	pause()
	local tops = { 9, 10, 11, 12, 13, 14, 15, 16 }
	buildDeck(ship, 8, FLOOR[9], PLAN[8])
	for i, deck in tops do
		local top = if tops[i + 1] then FLOOR[tops[i + 1]] else FLOOR[18]
		local pieces = PLAN[deck]
		if deck == 14 then
			pieces = { DECK14 }
		elseif deck == 15 then
			-- Deck 15 is open around two enclosed blocks: the Yacht Club forward and the aft
			-- entertainment block, with the Yacht Club's Garden terrace opening to the stern
			pieces = { clip(PLAN[15][1], 51, 117), clip(PLAN[16][2], 202, 300) }
		elseif deck == 16 then
			-- The Yacht Club's upper cabins; the aft deck 16 is built as open deck above
			pieces = { PLAN[16][1] }
		end
		buildDeck(ship, deck, top, pieces)
		pause()
	end
	buildTop(ship)
	buildLifeboats(ship)
	buildLivery(ship)

	ship:SetAttribute("PartCount", built)
	ship.Parent = parent
	return ship
end

return MscPreziosa
