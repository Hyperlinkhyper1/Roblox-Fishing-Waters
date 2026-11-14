-- A 1:1 model of the cruise ship MSC Preziosa (Fantasia class, STX France, 2013): 333.3 m long,
-- 37.9 m beam, 8.65 m draught and 66.8 m from the keel to the masthead, at the game's scale of
-- 0.28 m per stud.
--
-- The deck outlines were traced from MSC's published plans of decks 4-18. Each plan was lined up
-- with the others by its lift shafts, which run straight through the ship: lined up that way every
-- deck ends within 2 m of the 333 m stern. Decks 13-18 are drawn at about 0.88x the scale of the
-- lower plans (their cabins are narrower on paper), which is corrected here.
--
-- Heights and stations were measured from broadside, bow and stern-quarter photographs (Wikimedia
-- Commons, "MSC Preziosa (ship, 2013)"), scaled by the ship's length and corrected for the
-- camera's perspective: the cabin decks are 2.78 m apart, the lifeboats hang at deck 7, the pool
-- deck is deck 14 behind its dark glass walls and the masthead is 58.15 m above the water.
--
-- From the bow aft, above the cabin decks: the Aurea Spa's raked glazing over the bridge, the
-- Yacht Club's two cabin decks under The One sun deck and the swept mast, the magrodome over La
-- Playa Preziosa between swooping glass screens, the open Aqua Park pool under the deck 15
-- walking track, the round Galaxy lounge with the Top 18 solarium on its roof, the louvered
-- funnel wrapped by the Vertigo slide, Doremi Castle and the Brezza Marina solarium, and the
-- Garden Pool at the stern.
--
-- Ship coordinates are metres: x aft from the tip of the bow, y out from the centre line and z up
-- from the waterline. The model's origin is the waterline amidships, with the bow towards -X and
-- +y towards +Z: seen in game that is the port side, so starboard-only fittings sit at negative y.
-- Vector3s passed to strut() and tube() hold ship coordinates (x, y, z) in metres.
local MscPreziosa = {}

MscPreziosa.LENGTH = 333.3
MscPreziosa.BEAM = 37.9
MscPreziosa.DRAUGHT = 8.65
MscPreziosa.HEIGHT = 66.8 -- keel to masthead
MscPreziosa.STUDS = 1 / 0.28 -- studs per metre

local STUDS = MscPreziosa.STUDS
local MID = MscPreziosa.LENGTH / 2
local KEEL = -MscPreziosa.DRAUGHT
local MASTHEAD = MscPreziosa.HEIGHT - MscPreziosa.DRAUGHT

local rgb = Color3.fromRGB
local M = Enum.Material
local WHITE = rgb(244, 245, 247)
local ANTIFOULING = rgb(122, 38, 40)
local GLASS = rgb(34, 47, 74)
local RAIL = rgb(150, 182, 205)
local TEAK = rgb(170, 124, 82)
local FOREDECK = rgb(198, 172, 132)
local FUNNEL = rgb(24, 34, 64)
local STEEL = rgb(150, 156, 162)
local BRONZE = rgb(176, 132, 70)
local ORANGE = rgb(238, 112, 34)
local POOL = rgb(64, 172, 214)
local NAVY = rgb(20, 30, 70)
local CABIN_DARK = rgb(42, 52, 72) -- the shaded cabin wall behind a balcony
local TINTED = rgb(40, 60, 98) -- the blue-tinted balcony glass
local AQUA = rgb(126, 204, 208) -- the turquoise windbreaks round the aft pool
local SLANT = rgb(38, 68, 128) -- the glazing over the bridge
local HELM = rgb(206, 64, 36)
local SOOT = rgb(58, 58, 62)
local PARTITION = rgb(228, 230, 233)

-- Floor of each deck above the waterline (there is no deck 17 on MSC ships). Cabin decks are
-- 2.78 m apart; the promenade (7) and the pool deck (14) are taller.
local FLOOR = {
	[4] = 3.0,
	[5] = 6.0,
	[6] = 9.2,
	[7] = 12.5,
	[8] = 16.6,
	[9] = 19.4,
	[10] = 22.2,
	[11] = 25.0,
	[12] = 27.8,
	[13] = 30.6,
	[14] = 33.4,
	[15] = 37.1,
	[16] = 39.9,
	[18] = 42.7,
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
-- the bridge), open balconies behind a blue glass balustrade, a plain white stair tower, a
-- full-height glass band, glazing that leans back over the bridge, or a wall with long separate
-- windows. Balconies run forward to where each photographed row stops under the bridge, and the
-- decks over the lifeboats are framed by white stair towers.
local function recessed(head)
	local style = table.clone(head)
	for _, range in
		{
			{ 113, 117, "wall" },
			{ 117, 139.5, "balcony" },
			{ 139.5, 142.5, "wall" },
			{ 142.5, 200, "balcony" },
			{ 200, 203.5, "wall" },
			{ 203.5, 259, "balcony" },
			{ 259, 263, "wall" },
			{ 263, 276, "balcony" },
			{ 276, 284, "wall" },
			{ 284, 999, "balcony" },
		}
	do
		table.insert(style, range)
	end
	return style
end
local STYLE = {
	-- Deck 8 faces the open foredeck; forward of its front the hull carries only the bulwark
	[8] = recessed({ { 0, 113, "windows" } }),
	[9] = recessed({ { 0, 113, "windows" } }),
	[10] = recessed({ { 0, 70, "windows" }, { 70, 113, "balcony" } }),
	[11] = recessed({ { 0, 68, "windows" }, { 68, 113, "balcony" } }),
	[12] = recessed({ { 0, 66, "windows" }, { 66, 113, "balcony" } }),
	[13] = recessed({ { 0, 57, "bridge" }, { 57, 113, "balcony" } }),
	[14] = { { 0, 64, "slant" }, { 64, 999, "panels" } },
	-- The Yacht Club forward, the children's clubs under the Galaxy, La Palmeraie aft
	[15] = { { 0, 67, "strip" }, { 67, 114, "balcony" }, { 114, 117, "wall" }, { 200, 283, "few" }, { 283, 999, "band" } },
	[16] = { { 0, 79, "strip" }, { 79, 114, "balcony" }, { 114, 117, "wall" }, { 200, 999, "few" } },
}
-- Balcony width (the partitions between balconies sit on one grid through every deck) and depth
local BAY = 2.9
local DEPTH = 1.7

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
		-- The tiers under the bridge step forward deck by deck, as photographed from abeam
		{ 9, 1, 29.5, 11.08, 41 },
		{ 10, 1, 35, 10.79, 50 },
		{ 11, 1, 40.5, 10.79, 55 },
		{ 12, 1, 46.5, 10.03, 59 },
		-- The bridge front curves in one sweep out to the wing ends, overhanging deck 12
		{ 13, 1, 43, 6, 50 },
		{ 15, 1, 51, 10.07, 66 },
		{ 16, 1, 58, 10.83, 73 },
		{ 18, 1, 69, 10.89, 83 },
	}
do
	PLAN[front[1]][front[2]] = rounded(PLAN[front[1]][front[2]], front[3], front[4], front[5])
end
-- Deck 8's enclosed part starts under deck 9's front; forward of it is the open foredeck
local DECK8 = rounded(PLAN[8][1], 29.5, 11.08, 41)

-- Cuts an outline off at station x, or runs it on to there at its last breadth
local function endAt(poly, x: number)
	local last = poly[#poly]
	if last[1] > x then
		return clip(poly, poly[1][1], x)
	end
	local out = table.clone(poly)
	if x - last[1] > 0.01 then
		table.insert(out, { x, last[2] })
	end
	return out
end

-- Rounds an outline's after end over its last `length` metres, from its breadth there to a stern
-- face `face` half-breadth wide
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
-- The stern is a broad flat transom with tightly rounded corners, and each deck above the hull
-- ends a little further forward than the one below, so the after balconies step up in terraces.
-- { deck, piece, stern station, length of the corner curve, stern face half-breadth }
for _, stern in
	{
		{ 4, 1, 331.5, 5, 14.5 },
		{ 5, 1, 331.5, 5, 14.5 },
		{ 8, 1, 333.0, 5, 14.6 },
		{ 9, 1, 332.4, 5, 14.6 },
		{ 10, 1, 331.8, 5, 14.5 },
		{ 11, 1, 331.2, 5, 14.4 },
		{ 12, 1, 330.6, 5, 14.3 },
		{ 13, 1, 330.0, 5, 14.2 },
		{ 14, 1, 329.4, 5, 13.8 },
		{ 15, 1, 329.0, 5, 13.4 },
	}
do
	PLAN[stern[1]][stern[2]] = roundedEnd(endAt(PLAN[stern[1]][stern[2]], stern[3]), stern[4], stern[5])
end
DECK8 = roundedEnd(endAt(DECK8, 333.0), 5, 14.6)

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

-- The Galaxy lounge on deck 16 is a drum 34 m across, centred here, under the Top 18 solarium
local GALAXY = { 219.6, 17.2 }
local GALAXY_ROOF = FLOOR[16] + 4.1
-- The enclosed block of deck 16 between the Galaxy and the aft solarium (it carries the funnel)
local NECK = { 236, 279, 11.6 }

-- The hull plating below deck 8. The stem rakes 1.5 m forward for every metre of height, from
-- 27 m behind the tip of the bow at the waterline to the tip at the top of the bulwark; the bow
-- flares from deck 5's fine entry to deck 8's full one, the bilges round in below 3 m and the
-- stern cuts up under water. Aft the hull ends in a broad transom with rounded corners.
local BOW_TOP = FLOOR[8] + 1.3
local STEM_RAKE = 27 / BOW_TOP
local function stemAt(z: number): number
	return math.max(0, 27 - z * STEM_RAKE)
end
local function hullPlan(z: number)
	local tip = stemAt(z)
	local stern = if z >= 1 then 331.5 else 331.5 - (1 - z) * 3
	local flare = math.clamp((z - 6) / 10.6, 0, 1)
	local bilge = if z >= -3 then 1 else 1 - 0.2 * ((-3 - z) / 5.65) ^ 2
	local fine, full = PLAN[5][1], PLAN[8][1]
	local out = {}
	for _, u in { 0, 1, 2, 3, 5, 7, 10, 13, 16, 20, 25, 30, 36, 43, 50, 58, 67, 77, 88, 100 } do
		local entry = if 17 + u > 97 then 18.93 else sample(fine, 17 + u)
		local half = entry + (sample(full, math.min(u, 100)) - entry) * flare
		table.insert(out, { tip + u, half * bilge })
	end
	-- The transom narrows below the waterline
	local tuck = 4.4 + math.clamp(-z * 1.4, 0, 8)
	for i = 0, 10 do
		local t = i / 10 * math.pi / 2
		table.insert(out, { stern - 6 + 6 * math.sin(t), (18.93 - tuck * (1 - math.cos(t))) * bilge })
	end
	return out
end
MscPreziosa.hullPlan = hullPlan

-- The top of the bulwark round the open foredeck: chest-high at the stem, sweeping up aft into
-- the side of the first tier of the superstructure
local function bulwarkTop(x: number): number
	if x <= 6 then
		return BOW_TOP
	elseif x <= 30 then
		local t = (x - 6) / 24
		return BOW_TOP + 3.0 * t * t * (3 - 2 * t)
	end
	return math.min(FLOOR[10], BOW_TOP + 3.0 + (x - 30) / 11 * (FLOOR[10] - BOW_TOP - 3.0))
end

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
-- either side. With `shell`, only a wall that thick is built along each side, leaving the middle
-- open.
local function slab(
	parent: Instance,
	name: string,
	poly,
	z0: number,
	z1: number,
	color: Color3,
	material: Enum.Material?,
	centre: number?,
	shell: number?
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
			if shell and lo > shell then
				for _, side in { -1, 1 } do
					table.insert(
						made,
						sideBox(parent, name, a[1], b[1], yc + side * (lo - shell), yc + side * lo, z0, z1, color, material)
					)
				end
			else
				table.insert(made, box(parent, name, a[1], b[1], yc - lo, yc + lo, z0, z1, color, material))
			end
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
	-- The white lip of a balcony's floor, under its glass balustrade
	local lip = 0.4
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
					side * (half + 0.03),
					z0 + 1.05,
					z0 + 2.05,
					GLASS
				)
			end)
		end
	elseif style == "windows" or style == "bridge" then
		slab(parent, "Wall", poly, z0, z1, WHITE)
		local bottom, top, spacing = z0 + 0.85, z1 - 0.55, 2.4
		if style == "bridge" then
			bottom, top, spacing = z0 + 0.9, z1 - 0.45, 1.5
		end
		ribbon(parent, poly, bottom, top, front)
		mullions(parent, poly, bottom, top, spacing, front, if style == "bridge" then 0.2 else 0.9)
	elseif style == "few" then
		-- Separate square windows along a white wall
		slab(parent, "Wall", poly, z0, z1, WHITE)
		ribbon(parent, poly, z0 + 1.0, z0 + 2.0, front)
		mullions(parent, poly, z0 + 1.0, z0 + 2.0, 2.6, front, 1.6)
	elseif style == "strip" then
		-- A long dark slit of raked lounge windows in a smooth white front
		slab(parent, "Wall", poly, z0, z1, WHITE)
		ribbon(parent, poly, z0 + 0.95, z1 - 0.85, front)
	elseif style == "balcony" then
		-- An open balcony: the white lip of its floor, a blue glass balustrade with a white handrail,
		-- white partitions between neighbours and the dark glass doors of the cabin set back behind.
		-- The floor of the deck above is its ceiling.
		slab(parent, "Balconies", poly, z0, z0 + lip, WHITE)
		local inner = widen(poly, -DEPTH)
		inner = clip(inner, inner[1][1] + (if front then DEPTH else 0), inner[#inner][1] - (if back then DEPTH else 0))
		if #inner > 1 then
			slab(parent, "Cabins", inner, z0 + lip, z1, WHITE)
			-- Each cabin has a glass door on to its balcony, with a white partition either side.
			-- They are spaced along the hull so they stay evenly spread round the stern's corners,
			-- where the cabin wall is closer behind the rail.
			for _, side in { -1, 1 } do
				local index = 0
				walk(poly, BAY / 2, function(x, half, nx, ny)
					index += 1
					if half <= DEPTH + 0.5 or ny < 0.3 then
						return
					end
					local depth = DEPTH * ny
					local tangent = Vector3.new(side * ny, 0, -nx).Unit
					local outward = Vector3.new(nx, 0, side * ny).Unit
					local function inboard(t: number, z: number): Vector3
						return at(x - nx * t, side * (half - ny * t), z)
					end
					if index % 2 == 1 then
						part(
							parent,
							"Partition",
							Vector3.new(0.1 * STUDS, (z1 - z0 - lip) * STUDS, (depth - 0.08) * STUDS),
							CFrame.fromMatrix(inboard(depth / 2, (z0 + lip + z1) / 2), tangent, Vector3.yAxis, outward),
							PARTITION,
							M.SmoothPlastic
						)
					else
						part(
							parent,
							"CabinDoor",
							Vector3.new(1.8 * STUDS, 2.0 * STUDS, 0.1 * STUDS),
							CFrame.fromMatrix(inboard(depth - 0.02, z0 + lip + 1.02), tangent, Vector3.yAxis, outward),
							CABIN_DARK,
							M.Glass
						)
					end
				end)
			end
		end
		local rail = widen(poly, -0.06)
		edges(parent, "BalconyGlass", rail, z0 + lip, 1.05, TINTED, M.Glass, 0.4)
		edges(parent, "BalconyRail", rail, z0 + lip + 1.05, 0.07, WHITE, M.SmoothPlastic, 0)
	elseif style == "band" then
		slab(parent, "Wall", poly, z0, z0 + 0.4, WHITE)
		slab(parent, "Windows", widen(poly, -0.3), z0 + 0.4, z1 - 0.4, GLASS)
		slab(parent, "Wall", poly, z1 - 0.4, z1, WHITE)
		mullions(parent, widen(poly, -0.3), z0 + 0.4, z1 - 0.4, 1.8, front)
	elseif style == "panels" then
		-- Long dark windows with white piers between them
		slab(parent, "Wall", poly, z0, z1, WHITE)
		local x0, x1 = poly[1][1] + 0.1, poly[#poly][1] - 0.1
		for a = x0, x1 - 2, 13.5 do
			local pane = clip(poly, a + 0.75, math.min(a + 12.75, x1))
			if #pane > 1 then
				slab(parent, "Windows", widen(pane, 0.06), z0 + 0.8, z1 - 0.5, GLASS)
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
	-- The plans list the stern as an open end; close it so the balconies and windows carry on
	-- across the flat after face
	if stern then
		local endp = poly[#poly]
		local x, half = endp[1], endp[2]
		if half > 0.5 and style == "balcony" then
			-- After-facing balconies, their partitions splayed outwards from the centre line
			local glass =
				box(parent, "BalconyGlass", x - 0.12, x - 0.04, -half + 0.1, half - 0.1, z0 + lip, z0 + lip + 1.05, TINTED, M.Glass)
			glass.Transparency = 0.4
			glass.CastShadow = false
			box(parent, "BalconyRail", x - 0.14, x - 0.02, -half, half, z0 + lip + 1.05, z0 + lip + 1.12, WHITE)
			local zm = (z0 + lip + z1) / 2
			local count = math.floor(2 * (half - 0.6) / BAY)
			for i = 0, count do
				local y = (i - count / 2) * BAY
				local splay = if y < -0.1 then -0.5 elseif y > 0.1 then 0.5 else 0
				strut(
					parent,
					"Partition",
					Vector3.new(x - DEPTH, y, zm),
					Vector3.new(x - 0.14, y + splay, zm),
					0.1,
					z1 - z0 - lip,
					PARTITION
				)
			end
		elseif half > 0.5 then
			-- Sit the detail a few centimetres proud of the plating so nothing z-fights
			local back0, back1 = x - 0.32, x - 0.05
			local face0, face1 = x - 0.025, x + 0.025
			box(parent, "SternBulkhead", back0, back1, -half, half, z0, z1, WHITE)
			if style ~= "wall" then
				local bottom, top = z0 + 1, z0 + 2.0
				if style == "bridge" then
					bottom, top = z0 + 0.9, z1 - 0.45
				elseif style == "strip" or style == "band" then
					bottom, top = z0 + 0.7, z1 - 0.5
				elseif style == "panels" then
					bottom, top = z0 + 0.8, z1 - 0.5
				end
				box(parent, "SternWindows", face0, face1, -half + 1.2, half - 1.2, bottom, top, GLASS)
				if style ~= "few" then
					local spacing = if style == "panels" then 4.8 else 2.6
					for y = -half + 1.2, half - 1.2, spacing do
						box(parent, "Mullion", face0 - 0.02, face1 + 0.02, y - 0.08, y + 0.08, bottom, top, WHITE)
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
	color: Color3,
	material: Enum.Material?
): { BasePart }
	local made = {}
	local ab, bc, ca = (b - a).Magnitude, (c - b).Magnitude, (a - c).Magnitude
	if bc >= ab and bc >= ca then
		a, b, c = b, c, a
	elseif ca >= ab and ca >= bc then
		a, b, c = c, a, b
	end
	local edge = b - a
	local length = edge.Magnitude
	if length < 0.02 then
		return made
	end
	local foot = a + edge * ((c - a):Dot(edge) / (length * length))
	if (c - foot).Magnitude < 0.02 then
		return made
	end
	local n = edge:Cross(c - a).Unit
	if n:Dot(outward) < 0 then
		n = -n
	end
	local sink = n * (-thickness * STUDS / 2)
	for _, corner in { a, b } do
		if (foot - corner).Magnitude > 0.02 then
			table.insert(made, wedge(parent, name, foot + sink, corner + sink, c + sink, thickness * STUDS, color, material))
		end
	end
	return made
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

-- The lifeboats hang in a recess that opens the hull side between these stations, from just
-- under the promenade deck up to deck 8
local RECESS = { 103, 289, 11.6 }

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
	slab(hull, "BootTop", hullPlan(0.4), 0.2, 0.5, rgb(26, 38, 66))
	local aft = {
		{ -3, -1, hullPlan(-2) },
		{ -1, 0, hullPlan(-0.5) },
		{ 0, FLOOR[4], hullPlan(1.5) },
		{ FLOOR[4], FLOOR[5], PLAN[4][1] },
		{ FLOOR[5], FLOOR[6], PLAN[5][1] },
		{ FLOOR[6], RECESS[3], hullPlan(10.4) },
		-- Deck 7 is a promenade recessed behind the lifeboats
		{ RECESS[3], FLOOR[8], capped(hullPlan(14), RECESS[1], RECESS[2], 16) },
	}
	for _, layer in aft do
		local outline = layer[3]
		slab(hull, "Hull", clip(outline, BOW_END, outline[#outline][1]), layer[1], layer[2], colour(layer[2]))
		transom(outline, layer[1], layer[2], colour(layer[2]))
	end
	-- The bow up to the foredeck is a skin of triangles between hull contours, so the flare and
	-- the raked stem read as one smooth surface
	bowSkin(
		hull,
		{ -3, -1.5, 0, 1.5, FLOOR[4], 4.5, FLOOR[5], 7.6, FLOOR[6], 10.8, FLOOR[7], 13.9, 15.3, FLOOR[8] },
		BOW_END
	)

	-- The outward normal of the plating at station x and height z on one side
	local function normalAt(x: number, z: number, side: number): Vector3
		local function on(px: number, pz: number): Vector3
			return at(px, side * sample(hullPlan(pz), px), pz)
		end
		local n = (on(x + 0.5, z) - on(x - 0.5, z)):Cross(on(x, z + 0.5) - on(x, z - 0.5)).Unit
		return if n.Z * side < 0 then -n else n
	end
	-- A plate lying on the plating, following its flare, `length` by `height` metres
	local function plate(name: string, x: number, z: number, side: number, length: number, height: number, color: Color3)
		local n = normalAt(x, z, side)
		local up = (Vector3.yAxis - n * Vector3.yAxis:Dot(n)).Unit
		local surface = at(x, side * sample(hullPlan(z), x), z)
		return part(
			hull,
			name,
			Vector3.new(length, height, 0.3) * STUDS,
			CFrame.fromMatrix(surface - n * 0.1 * STUDS, up:Cross(n), up),
			color,
			M.SmoothPlastic
		)
	end
	-- A round window on the parallel sides of the hull
	local function porthole(x: number, z: number, side: number, diameter: number)
		local half = sample(hullPlan(z), x)
		local glass = part(
			hull,
			"Porthole",
			Vector3.new(0.5, diameter, diameter) * STUDS,
			CFrame.fromMatrix(at(x, side * (half - 0.15), z), Vector3.zAxis, Vector3.yAxis),
			GLASS,
			M.SmoothPlastic
		)
		glass.Shape = Enum.PartType.Cylinder
	end

	-- Bulbous bow
	local bulb = part(
		hull,
		"BulbousBow",
		Vector3.new(14, 5.4, 5.4) * STUDS,
		CFrame.new(at(34, 0, -4.6)),
		ANTIFOULING,
		M.SmoothPlastic
	)
	bulb.Shape = Enum.PartType.Cylinder
	part(hull, "BulbousBow", Vector3.one * 5.4 * STUDS, CFrame.new(at(27, 0, -4.6)), ANTIFOULING, M.SmoothPlastic).Shape =
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

	for _, side in { -1, 1 } do
		-- The big round windows of deck 6 in groups of four, and the smaller rows of decks 5 and 4.
		-- All three stop short of the logo near the stern.
		local i = 0
		for x = 118, 296, 3.6 do
			i += 1
			if i % 5 ~= 0 then
				porthole(x, 10.75, side, 1.5)
			end
		end
		for x = 62, 292, 3.2 do
			porthole(x, 7.5, side, 0.85)
		end
		for x = 74, 290, 3.2 do
			porthole(x, 4.5, side, 0.5)
		end
		-- The dark band of promenade windows at the back of the lifeboat recess
		sideBox(hull, "PromenadeWindows", RECESS[1] + 3, RECESS[2] - 3, side * 16.0, side * 16.06, 13.5, 15.7, GLASS)
		-- The anchor in its deep pocket low on the bow, and the mooring ports of deck 7 above it
		plate("AnchorPocket", 34, 5.8, side, 6.2, 3.6, CABIN_DARK)
		plate("Anchor", 34.4, 5.5, side, 1.6, 2.4, SOOT).Material = M.Metal
		for _, x in { 20.5, 23, 25.5, 28, 33.5, 40.5 } do
			plate("MooringPort", x, 14.4, side, 1.7, 0.6, CABIN_DARK)
		end
		-- The life-raft stations: four openings in the plating forward of the lifeboats
		for _, x in { 79.5, 84.6, 89.7, 94.8 } do
			plate("RaftStation", x, 14.5, side, 4.2, 2.9, CABIN_DARK)
			for k = -1, 1 do
				local half = sample(hullPlan(13.6), x + k * 1.1)
				sideBox(
					hull,
					"LifeRaft",
					x + k * 1.1 - 0.45,
					x + k * 1.1 + 0.45,
					side * (half - 0.6),
					side * (half + 0.02),
					13.2,
					14.1,
					WHITE
				)
			end
		end
	end

	-- Two long bands of restaurant windows across the stern, wrapping round its corners, with white
	-- piers between the panes
	for _, band in { { 13.0, 15.2 }, { 9.7, 11.9 } } do
		-- Proud of the plating round the corners and stopped inside the transom plate, so the glass
		-- never shares a face with the hull
		local wrap = widen(clip(hullPlan((band[1] + band[2]) / 2), 323, 331.3), 0.06)
		for _, glass in slab(hull, "SternWindows", wrap, band[1], band[2], GLASS) do
			glass.CastShadow = false
		end
		box(hull, "SternWindows", 331.4, 331.62, -14.3, 14.3, band[1], band[2], GLASS)
		for y = -13.2, 13.2, 2.4 do
			box(hull, "SternMullion", 331.35, 331.7, y - 0.08, y + 0.08, band[1], band[2], WHITE)
		end
	end
	-- The barred mooring ports of the after mooring deck, under the port of registry
	for _, y in { -11.6, -5.8, 0, 5.8, 11.6 } do
		box(hull, "MooringPort", 331.3, 331.58, y - 2, y + 2, 7.2, 8.15, CABIN_DARK)
		for _, z in { 7.48, 7.82 } do
			box(hull, "MooringBar", 331.5, 331.64, y - 2, y + 2, z, z + 0.07, WHITE)
		end
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
		-- The name on the swept-up bulwark under the first tier, and the small emblem near the stem
		local name = sign(livery, onHull(hullPlan(18), 33.5, 18.0, side, 0.08), 13.5, 1.3)
		words(name, "MSC PREZIOSA", 0, 0, 1, 1, NAVY, Enum.Font.Garamond)
		local n = hullNormal(9.5, 14.6, side)
		local up = (Vector3.yAxis - n * Vector3.yAxis:Dot(n)).Unit
		local bow = at(9.5, side * sample(hullPlan(14.6), 9.5), 14.6) + n * 0.1 * STUDS
		star(livery, bow, n, up, 1.1, NAVY, WHITE, NAVY)
		-- Low on the hull near the stern: the star and "MSC", two decks tall. Seen from either side
		-- the star comes first, so on the starboard side (negative y) it is the after end of the group
		local starX, textX = 303.6, 315.4
		if side < 0 then
			starX, textX = 319.2, 307.4
		end
		local outward = Vector3.new(0, 0, side)
		star(livery, onHull(hullPlan(5.9), starX, 5.9, side, 0.12).Position, outward, Vector3.yAxis, 3.4, NAVY, WHITE, NAVY)
		words(sign(livery, onHull(hullPlan(5.8), textX, 5.8, side, 0.12), 12, 4.3), "MSC", 0, 0, 1, 1, NAVY, Enum.Font.Garamond)
	end
	-- Name and port of registry across the stern
	local stern = CFrame.fromMatrix(at(331.56, 0, 15.9), Vector3.zAxis, Vector3.yAxis)
	words(sign(livery, stern, 17, 1.2), "MSC PREZIOSA", 0, 0, 1, 1, NAVY, Enum.Font.Garamond)
	local port = CFrame.fromMatrix(at(331.56, 0, 8.85), Vector3.zAxis, Vector3.yAxis)
	words(sign(livery, port, 5, 0.6), "PANAMA", 0, 0, 1, 1, NAVY, Enum.Font.Garamond)
	return livery
end

-- A glass screen standing on an outline: panes along both sides and across both ends, white posts
-- every `spacing` metres and a white rail along the top
local function screen(
	parent: Instance,
	name: string,
	poly,
	z0: number,
	height: number,
	color: Color3,
	transparency: number,
	spacing: number
)
	edges(parent, name, poly, z0, height, color, M.Glass, transparency)
	edges(parent, name .. "Rail", poly, z0 + height, 0.08, WHITE, M.SmoothPlastic, 0)
	for _, side in { -1, 1 } do
		walk(poly, spacing, function(x, half)
			box(parent, name .. "Post", x - 0.06, x + 0.06, side * half - 0.09, side * half + 0.09, z0, z0 + height, WHITE)
		end)
	end
	for _, p in { poly[1], poly[#poly] } do
		if p[2] > 0.3 then
			local pane = box(parent, name, p[1] - 0.06, p[1] + 0.06, -p[2], p[2], z0, z0 + height, color, M.Glass)
			pane.Transparency = transparency
			pane.CastShadow = false
			box(parent, name .. "Rail", p[1] - 0.06, p[1] + 0.06, -p[2], p[2], z0 + height, z0 + height + 0.08, WHITE)
			for _, y in across(p[2] - 0.2, spacing) do
				box(parent, name .. "Post", p[1] - 0.09, p[1] + 0.09, y - 0.06, y + 0.06, z0, z0 + height, WHITE)
			end
		end
	end
end

-- A circle of radius r centred on the centre line at station cx, as an outline. Its two ends are
-- cut off as short flat faces so every stretch of it is wide enough to build on.
local function circle(cx: number, r: number, steps: number)
	local out = {}
	local t0 = 0.12
	for i = 0, steps do
		local t = t0 + (math.pi - 2 * t0) * i / steps
		table.insert(out, { cx - r * math.cos(t), r * math.sin(t) })
	end
	return out
end

-- A satellite dome on a pedestal standing on `base`
local function radome(parent: Instance, x: number, y: number, base: number, diameter: number)
	box(parent, "RadomeBase", x - 0.7, x + 0.7, y - 0.7, y + 0.7, base, base + 0.45, WHITE)
	tube(parent, "RadomeBase", Vector3.new(x, y, base + 0.4), Vector3.new(x, y, base + 0.9), diameter * 0.45, WHITE)
	part(
		parent,
		"Radome",
		Vector3.one * diameter * STUDS,
		CFrame.new(at(x, y, base + 0.5 + diameter / 2)),
		WHITE,
		M.SmoothPlastic
	).Shape =
		Enum.PartType.Ball
end

-- A line dressed with signal flags between two points (ship coordinates)
local FLAGS = { rgb(214, 40, 40), rgb(250, 202, 40), rgb(40, 90, 200), WHITE, rgb(30, 150, 80) }
local function dressingLine(parent: Instance, a: Vector3, b: Vector3)
	strut(parent, "DressingLine", a, b, 0.05, 0.05, SOOT)
	local count = math.floor((b - a).Magnitude / 3.4)
	for i = 1, count - 1 do
		local p = a + (b - a) * (i / count)
		box(parent, "SignalFlag", p.X - 0.32, p.X + 0.32, p.Y - 0.02, p.Y + 0.02, p.Z - 0.72, p.Z - 0.06, FLAGS[i % #FLAGS + 1])
	end
end

-- The bridge on deck 13: a heavy white roof over the window band and the wings, struts under the
-- wings, and below it the rounded tiers of decks 9-12 stepping forward to the foredeck, each open
-- terrace behind a white parapet
local function buildBridge(parent: Instance)
	local front = Instance.new("Model")
	front.Name = "Bridge"
	front.Parent = parent
	-- The roof follows the curve of the bridge and wings, overhanging the windows but stopping
	-- flush with the wing ends
	local bridge = PLAN[13][1]
	local z = FLOOR[14]
	local roof = {}
	for _, p in widen(clip(bridge, bridge[1][1], 57), 0.7) do
		table.insert(roof, { p[1], math.min(p[2], 23.59) })
	end
	slab(front, "BridgeRoof", roof, z - 0.45, z + 0.3, WHITE)
	box(front, "BridgeRoof", bridge[1][1] - 0.8, bridge[1][1] + 0.2, -roof[1][2], roof[1][2], z - 0.45, z + 0.3, WHITE)
	-- The wing roofs are sand-coloured open decks
	slab(front, "WingDeck", widen(roof, -0.5), z + 0.3, z + 0.35, FOREDECK)
	edges(front, "WingRail", widen(roof, -0.1), z + 0.3, 1.1, RAIL, M.Glass, 0.5)
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
	-- Deck 12 has no terrace: the bridge overhangs its front
	for _, deck in { 9, 10, 11 } do
		local above = deck + 1
		local outline = PLAN[deck][1]
		local terrace = clip(outline, outline[1][1], PLAN[above][1][1][1] + 2)
		edges(front, "Parapet", terrace, FLOOR[above], 1.05, WHITE, M.SmoothPlastic, 0)
		box(
			front,
			"Parapet",
			terrace[1][1],
			terrace[1][1] + 0.12,
			-terrace[1][2],
			terrace[1][2],
			FLOOR[above],
			FLOOR[above] + 1.05,
			WHITE
		)
		-- Each tier's front is capped by a white band proud of the windows below
		slab(front, "TerraceLip", widen(terrace, 0.3), FLOOR[above] - 0.4, FLOOR[above] + 0.08, WHITE)
		box(
			front,
			"TerraceLip",
			terrace[1][1] - 0.3,
			terrace[1][1] + 0.1,
			-terrace[1][2] - 0.3,
			terrace[1][2] + 0.3,
			FLOOR[above] - 0.4,
			FLOOR[above] + 0.08,
			WHITE
		)
	end
	return front
end

-- The white mast: a fin swept sharply aft from a streamlined house over the forward stair core,
-- with two radar platforms cantilevered from its leading edge, and the satellite domes round it
local function buildMast(parent: Instance)
	local mast = Instance.new("Model")
	mast.Name = "Mast"
	mast.Parent = parent
	local z0 = ROOF
	local house = { { 92.5, 2.6 }, { 94, 5.2 }, { 97, 6.5 }, { 112, 6.5 }, { 114.5, 5.4 }, { 115.5, 3.2 } }
	slab(mast, "MastHouse", house, z0, z0 + 3.6, WHITE)
	box(mast, "MastHouse", 92.3, 92.6, -2.6, 2.6, z0, z0 + 3.6, WHITE)
	box(mast, "MastHouse", 115.4, 115.6, -3.2, 3.2, z0, z0 + 3.6, WHITE)
	for _, side in { -1, 1 } do
		sideBox(mast, "HouseWindows", 98, 111, side * 6.5, side * 6.57, z0 + 1.3, z0 + 2.3, GLASS)
	end
	slab(mast, "MastBase", { { 94.6, 1.3 }, { 96.2, 2.6 }, { 104.5, 2.6 }, { 107.5, 1.5 } }, z0 + 3.6, z0 + 5.3, WHITE)
	box(mast, "MastBase", 94.4, 94.7, -1.3, 1.3, z0 + 3.6, z0 + 5.3, WHITE)
	box(mast, "MastBase", 107.4, 107.7, -1.5, 1.5, z0 + 3.6, z0 + 5.3, WHITE)

	-- The fin: { height, leading edge, trailing edge }
	local fin = {
		{ 48.0, 95.8, 104.4 },
		{ 49.5, 98.4, 104.8 },
		{ 51.0, 100.4, 105.2 },
		{ 52.5, 102.0, 105.6 },
		{ 54.0, 103.3, 106.0 },
		{ 55.5, 104.3, 106.4 },
		{ 57.0, 105.2, 106.8 },
	}
	for i = 1, #fin - 1 do
		local a, b = fin[i], fin[i + 1]
		local ca, cb = (a[2] + a[3]) / 2, (b[2] + b[3]) / 2
		local chord = ((a[3] - a[2]) + (b[3] - b[2])) / 2
		local dx, dz = cb - ca, b[1] - a[1]
		strut(
			mast,
			"Mast",
			Vector3.new(ca - dx * 0.1, 0, a[1] - dz * 0.1),
			Vector3.new(cb + dx * 0.1, 0, b[1] + dz * 0.1),
			1.5 - i * 0.13,
			chord * dz / math.sqrt(dx * dx + dz * dz),
			WHITE,
			nil,
			Vector3.xAxis
		)
	end
	-- { platform from, to, half-breadth, height, scanner station, scanner height, scanner half-length }
	for _, deck in { { 97.2, 101.6, 2.1, 51.3, 99.3, 54.2, 2.1 }, { 101.6, 105.2, 1.5, 55.5, 103.0, 57.25, 2.0 } } do
		local z = deck[4]
		box(mast, "MastPlatform", deck[1], deck[2], -deck[3], deck[3], z, z + 0.2, WHITE)
		edges(mast, "MastRail", { { deck[1], deck[3] }, { deck[2], deck[3] } }, z + 0.2, 0.9, RAIL, M.Glass, 0.4)
		box(mast, "MastRail", deck[1] - 0.05, deck[1] + 0.05, -deck[3], deck[3], z + 0.2, z + 1.1, RAIL, M.Glass).Transparency = 0.4
		box(mast, "RadarPedestal", deck[5] - 0.2, deck[5] + 0.2, -0.2, 0.2, z + 0.2, deck[6], WHITE)
		box(mast, "RadarScanner", deck[5] - 0.3, deck[5] + 0.3, -deck[7], deck[7], deck[6], deck[6] + 0.28, STEEL, M.Metal)
	end
	box(mast, "RadarScanner", 100.6, 101.0, -1.0, 1.0, 52.9, 53.1, STEEL, M.Metal)
	-- The masthead pole and its yard
	box(mast, "Mast", 105.9, 106.3, -0.15, 0.15, 56.6, MASTHEAD, WHITE)
	box(mast, "MastYard", 106.0, 106.2, -2.4, 2.4, 57.5, 57.65, WHITE)

	radome(mast, 112.6, 0, z0 + 3.6, 4.6)
	for _, side in { -1, 1 } do
		radome(mast, 109, side * 4.6, z0 + 3.6, 2.0)
	end

	-- The dressing lines: down to the jackstaff over a pole on the lounge roof, and aft to the funnel
	box(mast, "AntennaPole", 70.8, 71.2, -0.15, 0.15, z0, z0 + 6, WHITE)
	local head = Vector3.new(106.1, 0, MASTHEAD - 0.4)
	local pole = Vector3.new(71, 0, z0 + 5.9)
	dressingLine(mast, pole, head)
	dressingLine(mast, Vector3.new(1.55, 0, FLOOR[8] + 7.9), pole)
	dressingLine(mast, head, Vector3.new(248.5, 0, 54.3))
	return mast
end

-- The funnel: a tall, narrow navy sail on the roof of the block behind the Galaxy. In side view
-- its forward edge climbs out of the Galaxy's roof in a long gentle curve to a crest 10.6 m above
-- its foot, the crest runs aft almost level, and the after edge drops steeply. Two fans of
-- horizontal slats fall away from the crest to the deck, with a solid navy panel under the MSC
-- compass on each side and eight exhaust stacks breaking out along the top.
local FUNNEL_AT = { 234, 247, 269, 282 } -- forward foot, crest start/end, aft foot
local FUNNEL_TOP = 53.3
local FUNNEL_BASE = ROOF
local STACK_TOP = 57.3
local CROWN = 0.7 -- how far the crest's ends sit below its middle
local CREST = 1.35 -- half-breadth of the ridge
local FUNNEL_HALF = 6.6 -- half-breadth at the bottom of the slats

-- The height of the crest at station x
local function crest(x: number): number
	local a, b, c, d = FUNNEL_AT[1], FUNNEL_AT[2], FUNNEL_AT[3], FUNNEL_AT[4]
	local shoulder = FUNNEL_TOP - CROWN
	if x < b then
		local t = math.clamp((x - a) / (b - a), 0, 1)
		return FUNNEL_BASE + (shoulder - FUNNEL_BASE) * t ^ 0.85
	elseif x <= c then
		return FUNNEL_TOP - CROWN * ((x - (b + c) / 2) / ((c - b) / 2)) ^ 2
	end
	local t = math.clamp((x - c) / (d - c), 0, 1)
	return shoulder - (shoulder - FUNNEL_BASE) * t ^ 1.25
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
	-- The breadth of the sail surface at station x for a given z, on one side
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
			local z = FUNNEL_BASE + 0.5 + (FUNNEL_TOP - CROWN - 0.6 - FUNNEL_BASE - 0.5) * k / 19
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
					if edge then 0.4 else 0.16,
					if edge then 0.36 else 0.17,
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
					funnelPoint(x + (x - 258) * 0.1 * v0, v0, side),
					funnelPoint(x + (x - 258) * 0.1 * v1, v1, side),
					0.28,
					0.3,
					FUNNEL
				)
			end
		end
		-- Solid plating behind the slats under the emblem
		local cells, rows = 9, 5
		local function inner(i: number, j: number): Vector3
			local x, v = 250 + 19 * i / cells, 0.1 + 0.8 * j / rows
			return world(funnelPoint(x, v, side)) - normal(x, v, side) * 0.28 * STUDS
		end
		for i = 0, cells - 1 do
			for j = 0, rows - 1 do
				local outward = normal(250 + 19 * (i + 0.5) / cells, 0.1 + 0.8 * (j + 0.5) / rows, side)
				triangle(funnel, "FunnelPlating", inner(i, j), inner(i + 1, j), inner(i, j + 1), outward, 0.2, FUNNEL)
				triangle(funnel, "FunnelPlating", inner(i + 1, j), inner(i + 1, j + 1), inner(i, j + 1), outward, 0.2, FUNNEL)
			end
		end
		-- The compass emblem in the middle of the plating
		local emblemX, emblemV = 260.5, 0.5
		local n = normal(emblemX, emblemV, side)
		local up = (Vector3.yAxis - n * Vector3.yAxis:Dot(n)).Unit
		star(funnel, world(funnelPoint(emblemX, emblemV, side)) + n * 0.7 * STUDS, n, up, 3.3, WHITE, WHITE, FUNNEL)
		-- A heavy navy beam down each edge of the sail
		for _, span in { { FUNNEL_AT[1], FUNNEL_AT[2] }, { FUNNEL_AT[3], FUNNEL_AT[4] } } do
			local steps = 5
			for i = 0, steps - 1 do
				local x0, x1 = span[1] + (span[2] - span[1]) * i / steps, span[1] + (span[2] - span[1]) * (i + 1) / steps
				strut(
					funnel,
					"FunnelEdge",
					Vector3.new(x0, side * CREST, crest(x0)),
					Vector3.new(x1, side * CREST, crest(x1)),
					0.5,
					0.5,
					FUNNEL
				)
			end
		end
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
	for i, x in { 250.5, 255, 259.5, 264 } do
		for _, y in { -1.05, 1.05 } do
			local baseZ = crest(x) - 0.9
			local base = Vector3.new(x, y, baseZ)
			local top = base + Vector3.new(2.3, y * 0.5, (if i >= 3 then STACK_TOP else STACK_TOP - 0.5) - baseZ)
			tube(funnel, "ExhaustStack", base, top, 1.8, STEEL, M.Metal)
			local dir = top - base
			tube(funnel, "ExhaustStack", top - dir * 0.08, top + dir * 0.02, 1.86, SOOT, M.Metal)
		end
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

-- A round whirlpool: a white drum with water in it
local function whirlpool(parent: Instance, x: number, y: number, z: number, diameter: number)
	tube(parent, "Whirlpool", Vector3.new(x, y, z), Vector3.new(x, y, z + 0.55), diameter, WHITE)
	tube(parent, "Whirlpool", Vector3.new(x, y, z + 0.3), Vector3.new(x, y, z + 0.62), diameter - 0.6, POOL)
end

-- A pool sunk in a white rim, from x0 to x1 and `half` either side of y
local function pool(parent: Instance, x0: number, x1: number, y: number, half: number, z: number)
	box(parent, "PoolRim", x0 - 0.6, x1 + 0.6, y - half - 0.6, y + half + 0.6, z, z + 0.32, WHITE)
	box(parent, "Pool", x0, x1, y - half, y + half, z + 0.32, z + 0.4, POOL)
end

-- A bar: a white counter under a flat canopy on four posts
local function bar(parent: Instance, x0: number, x1: number, y0: number, y1: number, z: number, roof: Color3)
	box(parent, "BarCounter", x0, x1, y0, y1, z, z + 1.1, WHITE)
	for _, x in { x0 - 0.3, x1 + 0.3 } do
		for _, y in { y0 - 0.3, y1 + 0.3 } do
			box(parent, "BarPost", x - 0.12, x + 0.12, y - 0.12, y + 0.12, z, z + 2.7, WHITE)
		end
	end
	box(parent, "BarCanopy", x0 - 0.9, x1 + 0.9, y0 - 0.9, y1 + 0.9, z + 2.7, z + 2.9, roof)
end

-- Midships the ship is hollow from deck 14 up. Behind the Yacht Club lies La Playa Preziosa, the
-- covered pool, in a hall two decks high under a sliding glass roof (the magrodome); aft of it the
-- open Aqua Park pool, overlooked by the deck 15 walking track. Deck 14's sides are glass walls
-- along the whole of it, and above them glass screens swoop down from the top of the Yacht Club
-- to the rail of deck 15.
local HALL = { 116, 146 } -- La Playa Preziosa
local DOME = { 118, 144, 13 } -- the magrodome: from, to, half-breadth
local AQUA_PARK = { 146, 198 }
local TRACK = 12 -- the inner edge of the walking track round the Aqua Park

-- The top edge of the swooping glass screens: from the Yacht Club's roof down to deck 15's rail
local SCREEN = { 116, 165 }
local function screenTop(x: number): number
	local t = (x - SCREEN[1]) / (SCREEN[2] - SCREEN[1])
	return (ROOF + 0.7) + (FLOOR[15] + 1.1 - ROOF - 0.7) * t
end

local function buildPools(parent: Instance)
	local lido = Instance.new("Model")
	lido.Name = "Pool Decks"
	lido.Parent = parent
	local z14, z15, z16 = FLOOR[14], FLOOR[15], FLOOR[16]
	local x0, x1 = HALL[1], AQUA_PARK[2]
	local sides = clip(PLAN[14][1], x0, x1)
	local half = sample(sides, (x0 + x1) / 2)

	-- The pool deck itself, and deck 14's glass walls between white piers
	slab(lido, "PoolDeck", widen(sides, -0.3), z14 - 0.1, z14 + 0.05, TEAK, M.WoodPlanks)
	slab(lido, "Wall", sides, z14, z14 + 0.8, WHITE, nil, nil, 0.45)
	slab(lido, "Wall", sides, z15 - 0.5, z15, WHITE, nil, nil, 0.45)
	for _, glass in slab(lido, "PoolScreen", widen(sides, -0.1), z14 + 0.8, z15 - 0.5, GLASS, M.Glass, nil, 0.12) do
		glass.Transparency = 0.2
		glass.CastShadow = false
	end
	for x = x0 + 0.6, x1 - 0.5, 6.75 do
		for _, side in { -1, 1 } do
			sideBox(lido, "Wall", x - 0.35, x + 0.35, side * (half - 0.45), side * half, z14 + 0.8, z15 - 0.5, WHITE)
		end
	end

	-- La Playa Preziosa: the pool and its four whirlpools on deck 14, a gallery round the well on
	-- deck 15 behind dark glass, and the roof round the magrodome
	local hall = clip(PLAN[15][1], HALL[1], HALL[2])
	pool(lido, 124, 134.5, 0, 3, z14 + 0.05)
	for _, x in { 122.2, 136.3 } do
		for _, side in { -1, 1 } do
			whirlpool(lido, x, side * 5.4, z14 + 0.05, 3.2)
		end
	end
	loungers(lido, 123, 136, { 9.5, 14 }, z14 + 0.05)
	slab(lido, "Gallery", hall, z15 - 0.25, z15, WHITE, nil, nil, half - 10.5)
	box(lido, "Gallery", HALL[1], 122, -10.5, 10.5, z15 - 0.25, z15, WHITE)
	box(lido, "Gallery", 141, HALL[2], -10.5, 10.5, z15 - 0.25, z15, WHITE)
	for _, side in { -1, 1 } do
		local rail = sideBox(lido, "GalleryRail", 122, 141, side * 10.4, side * 10.5, z15, z15 + 1.1, RAIL, M.Glass)
		rail.Transparency = 0.5
		rail.CastShadow = false
	end
	slab(lido, "Wall", hall, z15, z15 + 0.5, WHITE, nil, nil, 0.45)
	slab(lido, "Wall", hall, z16 - 0.3, z16, WHITE, nil, nil, 0.45)
	slab(lido, "HallWindows", widen(hall, 0.04), z15 + 0.5, z16 - 0.3, GLASS, nil, nil, 0.3)
	mullions(lido, widen(hall, 0.04), z15 + 0.5, z16 - 0.3, 2.6, false)
	-- The after wall of the hall, glazed over the Aqua Park
	local after = box(lido, "HallWindows", HALL[2] - 0.15, HALL[2], -half + 0.4, half - 0.4, z15, z16, RAIL, M.Glass)
	after.Transparency = 0.4
	after.CastShadow = false
	-- The lifts and stairs between the two pools
	box(lido, "LiftLobby", 141.5, HALL[2] + 4, -6, 6, z14, z16 + 1.2, WHITE)
	for _, side in { -1, 1 } do
		sideBox(lido, "LobbyWindows", 142.3, HALL[2] + 3.2, side * 6, side * 6.06, z14 + 0.6, z15 - 0.6, GLASS)
		sideBox(lido, "LobbyWindows", 142.3, HALL[2] + 3.2, side * 6, side * 6.06, z15 + 0.6, z16 - 0.4, GLASS)
	end

	-- The roof round the magrodome
	local dx0, dx1, span = DOME[1], DOME[2], DOME[3]
	slab(lido, "HallRoof", hall, z16 - 0.2, z16, WHITE, nil, nil, half - span)
	box(lido, "HallRoof", HALL[1], dx0, -span, span, z16 - 0.2, z16, WHITE)
	box(lido, "HallRoof", dx1, HALL[2], -span, span, z16 - 0.2, z16, WHITE)
	for _, side in { -1, 1 } do
		sideBox(lido, "DomeCurb", dx0, dx1, side * (span - 0.2), side * (span + 0.3), z16, z16 + 0.4, WHITE)
	end
	-- The magrodome: a low glass vault on white ribs, glazed at both ends
	local rise = 2.4
	local function vault(j: number): Vector3
		local t = math.pi * j / 8
		return Vector3.new(0, -span * math.cos(t), z16 + 0.4 + rise * math.sin(t))
	end
	for j = 0, 7 do
		local p, q = vault(j), vault(j + 1)
		local mid = (p + q) / 2
		local chord = q - p
		local pane = strut(
			lido,
			"Magrodome",
			Vector3.new(dx0, mid.Y, mid.Z),
			Vector3.new(dx1, mid.Y, mid.Z),
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
		for _, x in (if math.min(p.Z, q.Z) > z16 + 0.5 then { dx0, dx1 } else {}) do
			local gable =
				sideBox(lido, "Magrodome", x - 0.05, x + 0.05, p.Y, q.Y, z16 + 0.4, math.min(p.Z, q.Z), RAIL, M.Glass)
			gable.Transparency = 0.4
			gable.CastShadow = false
		end
	end
	for x = dx0, dx1 + 0.01, (dx1 - dx0) / 10 do
		for j = 0, 7 do
			local p, q = vault(j), vault(j + 1)
			strut(lido, "DomeRib", Vector3.new(x, p.Y, p.Z), Vector3.new(x, q.Y, q.Z), 0.25, 0.3, WHITE)
		end
	end
	local crown = vault(4)
	box(lido, "DomeRib", dx0, dx1, -0.2, 0.2, crown.Z, crown.Z + 0.3, WHITE)

	-- The Aqua Park: the main pool with a whirlpool at each corner, open to the sky
	local ax0, ax1 = AQUA_PARK[1], AQUA_PARK[2]
	slab(lido, "PoolRim", { { 162.9, 2.6 }, { 165.2, 5.3 }, { 184.8, 5.3 }, { 187.1, 2.6 } }, z14 + 0.05, z14 + 0.42, WHITE)
	slab(lido, "Pool", { { 163.5, 2.2 }, { 165.6, 4.7 }, { 184.4, 4.7 }, { 186.5, 2.2 } }, z14 + 0.42, z14 + 0.5, POOL)
	for _, x in { 161.2, 188.8 } do
		for _, side in { -1, 1 } do
			whirlpool(lido, x, side * 6.6, z14 + 0.05, 4.2)
		end
	end
	loungers(lido, 157, 192, { 9.3 }, z14 + 0.05)
	for _, side in { -1, 1 } do
		sideBox(lido, "BarCounter", 193.5, 197, side * 5, side * 11, z14 + 0.05, z14 + 1.15, WHITE)
	end
	-- The deck 15 walking track round it, on columns, with a glass rail over the pool
	local track = clip(PLAN[15][1], ax0, ax1)
	slab(lido, "Track", track, z15 - 0.25, z15, WHITE, nil, nil, half - TRACK)
	slab(lido, "TrackDeck", widen(track, -0.2), z15, z15 + 0.04, TEAK, M.WoodPlanks, nil, half - TRACK - 0.4)
	for _, bridge in { { ax0, ax0 + 6 }, { ax1 - 5, ax1 } } do
		box(lido, "Track", bridge[1], bridge[2], -TRACK, TRACK, z15 - 0.25, z15, WHITE)
		box(lido, "TrackDeck", bridge[1] + 0.2, bridge[2] - 0.2, -TRACK, TRACK, z15, z15 + 0.04, TEAK, M.WoodPlanks)
	end
	local well = { { ax0 + 6, TRACK }, { ax1 - 5, TRACK } }
	screen(lido, "TrackRail", well, z15, 1.1, RAIL, 0.5, 2.4)
	for x = ax0 + 9, ax1 - 6, 7 do
		for _, side in { -1, 1 } do
			sideBox(lido, "Column", x - 0.18, x + 0.18, side * (TRACK + 0.15), side * (TRACK + 0.5), z14, z15 - 0.25, WHITE)
		end
	end
	for _, side in { -1, 1 } do
		whirlpool(lido, ax0 + 3, side * 8.5, z15, 3.4)
	end
	loungers(lido, ax0 + 8, ax1 - 7, { 14.6 }, z15 + 0.04)

	-- The swooping glass screens along each side, darker where they stand in front of the
	-- magrodome, with the ship's name on them
	for _, side in { -1, 1 } do
		local y = side * (half - 0.15)
		local outward = Vector3.new(0, 0, side)
		local x = SCREEN[1]
		while x < SCREEN[2] - 0.1 do
			local x2 = math.min(x + 2.45, SCREEN[2])
			local bottom = if x < HALL[2] then z16 else z15 + 1.1
			local t1, t2 = screenTop(x), math.max(screenTop(x2), bottom + 0.02)
			local p1, p2 = at(x, y, bottom), at(x2, y, bottom)
			local q1, q2 = at(x, y, t1), at(x2, y, t2)
			local color = if x < 142 then TINTED else RAIL
			for _, pair in { { p1, p2, q1 }, { p2, q2, q1 } } do
				for _, pane in triangle(lido, "SideScreen", pair[1], pair[2], pair[3], outward, 0.08, color, M.Glass) do
					pane.Transparency = if x < 142 then 0.2 else 0.45
					pane.CastShadow = false
				end
			end
			if t1 - bottom > 0.3 then
				sideBox(lido, "ScreenPost", x - 0.07, x + 0.07, y - side * 0.1, y + side * 0.06, bottom, t1, WHITE)
			end
			x = x2
		end
		strut(
			lido,
			"ScreenRail",
			Vector3.new(SCREEN[1], y, screenTop(SCREEN[1]) + 0.06),
			Vector3.new(SCREEN[2], y, screenTop(SCREEN[2]) + 0.06),
			0.22,
			0.16,
			WHITE
		)
		local plate = CFrame.fromMatrix(at(129.5, side * (half - 0.02), z16 + 0.82), outward:Cross(Vector3.yAxis), Vector3.yAxis)
		words(sign(lido, plate, 12, 1.0), "MSC PREZIOSA", 0, 0, 1, 1, NAVY, Enum.Font.Garamond)
	end

	-- The panoramic lifts in a glass tower between the Aqua Park and the Galaxy
	local shaft = box(lido, "PanoramicLift", 197.7, 201.9, -3.6, 3.6, z15, GALAXY_ROOF + 1.2, RAIL, M.Glass)
	shaft.Transparency = 0.3
	for _, x in { 197.7, 201.9 } do
		for _, y in { -3.6, 3.6 } do
			box(lido, "LiftFrame", x - 0.15, x + 0.15, y - 0.15, y + 0.15, z15, GALAXY_ROOF + 1.4, WHITE)
		end
	end
	for z = z15 + 2.8, GALAXY_ROOF + 1.3, 2.8 do
		box(lido, "LiftFrame", 197.55, 202.05, -3.75, 3.75, z, z + 0.2, WHITE)
	end
	return lido
end

-- The One sun deck on the roof of the Yacht Club's two cabin decks: a small pool, a whirlpool and
-- a bar behind a tall dark glass windbreak that wraps round the front of the ship
local function buildYachtClubTop(parent: Instance)
	local club = Instance.new("Model")
	club.Name = "Yacht Club Sun Deck"
	club.Parent = parent
	local z = ROOF
	local roof = widen(clip(PLAN[16][1], 58, 116), -0.25)
	slab(club, "SunDeck", roof, z - 0.05, z + 0.05, TEAK, M.WoodPlanks)
	-- The roof forward of the windbreak is bare white steel
	slab(club, "LoungeRoof", clip(roof, 58, 70.5), z + 0.05, z + 0.09, WHITE)
	screen(club, "Windbreak", widen(clip(PLAN[18][1], 69, 116), -0.35), z, 3.0, GLASS, 0.25, 1.5)

	pool(club, 87.3, 92.2, 0, 3, z + 0.05)
	whirlpool(club, 83.4, 0, z + 0.05, 3.4)
	bar(club, 85, 91.5, 9.2, 11.4, z + 0.05, WHITE)
	loungers(club, 76, 83, { 6.5, 11.5 }, z + 0.05)
	loungers(club, 94, 113, { 9.4, 12.2, 15.4 }, z + 0.05)
	return club
end

-- The aft top of the ship: the round Galaxy lounge with the Top 18 solarium on its roof, the block
-- behind it that carries the funnel, the Vertigo slide looping down the starboard side, Doremi
-- Castle and the Brezza Marina solarium on deck 16 over La Palmeraie, and the Garden Pool at the
-- stern of deck 15
local function buildAftTop(parent: Instance)
	local aft = Instance.new("Model")
	aft.Name = "Aft Sun Decks"
	aft.Parent = parent
	local z15, z16 = FLOOR[15], FLOOR[16]
	local cx, r = GALAXY[1], GALAXY[2]

	-- Deck 15's open promenades either side of the children's clubs, behind a white bulwark
	local deck15 = clip(PLAN[15][1], AQUA_PARK[2], PLAN[15][1][#PLAN[15][1]][1])
	slab(aft, "Promenade", widen(deck15, -0.25), z15 - 0.03, z15 + 0.04, TEAK, M.WoodPlanks)

	-- The Galaxy: a white dish under a band of panoramic windows, and on its roof the Top 18
	-- solarium behind a white parapet and a glass windbreak
	slab(aft, "Galaxy", circle(cx, r - 1.8, 20), z16, z16 + 0.55, WHITE)
	slab(aft, "Galaxy", circle(cx, r - 0.8, 20), z16 + 0.55, z16 + 1.1, WHITE)
	slab(aft, "GalaxyWindows", circle(cx, r - 0.25, 20), z16 + 1.1, z16 + 3.9, GLASS)
	slab(aft, "Galaxy", circle(cx, r, 20), z16 + 3.9, GALAXY_ROOF, WHITE)
	for k = 1, 17 do
		local t = math.pi * k / 18
		local x, y = cx - (r - 0.2) * math.cos(t), (r - 0.2) * math.sin(t)
		for _, side in { -1, 1 } do
			box(aft, "GalaxyMullion", x - 0.15, x + 0.15, side * y - 0.15, side * y + 0.15, z16 + 1.1, z16 + 3.9, WHITE)
		end
	end
	local parapet = circle(cx, r - 0.15, 20)
	edges(aft, "GalaxyParapet", parapet, GALAXY_ROOF, 1.2, WHITE, M.SmoothPlastic, 0)
	for _, p in { parapet[1], parapet[#parapet] } do
		box(aft, "GalaxyParapet", p[1] - 0.06, p[1] + 0.06, -p[2], p[2], GALAXY_ROOF, GALAXY_ROOF + 1.2, WHITE)
	end
	screen(aft, "Top18Screen", circle(cx, r - 0.2, 20), GALAXY_ROOF + 1.2, 2.0, RAIL, 0.45, 2.2)
	slab(aft, "Top18", circle(cx, r - 0.5, 20), GALAXY_ROOF, GALAXY_ROOF + 0.06, TEAK, M.WoodPlanks)
	whirlpool(aft, cx - 12.4, 0, GALAXY_ROOF + 0.06, 3.4)
	for x = cx - 12, cx + 9, 1.25 do
		for _, y in { 6.5, 9.4, 12.3 } do
			if x > cx - 9.5 and (x - cx) ^ 2 + (y + 1.3) ^ 2 < (r - 1.4) ^ 2 then
				for _, side in { -1, 1 } do
					box(aft, "Lounger", x - 0.35, x + 0.35, side * y - 0.95, side * y + 0.95, GALAXY_ROOF + 0.06, GALAXY_ROOF + 0.4, WHITE)
				end
			end
		end
	end
	radome(aft, cx + 3.5, -3.6, GALAXY_ROOF + 0.06, 4.2)
	radome(aft, cx - 4.5, 3.4, GALAXY_ROOF + 0.06, 2.4)

	-- Deck 16 round the block behind the Galaxy is an open walkway behind a glass rail; the block's
	-- roof is a railed deck round the foot of the funnel
	local deck16 = clip(PLAN[16][2], NECK[1], 284)
	slab(aft, "Deck16", deck16, z16 - 0.25, z16, WHITE)
	slab(aft, "Deck16Teak", widen(deck16, -0.2), z16, z16 + 0.04, TEAK, M.WoodPlanks)
	edges(aft, "DeckRail", widen(clip(PLAN[16][2], 238, NECK[2]), -0.15), z16, 1.1, RAIL, M.Glass, 0.5)
	local neckRoof = { { NECK[1] + 1, NECK[3] - 0.2 }, { NECK[2] - 0.2, NECK[3] - 0.2 } }
	slab(aft, "FunnelDeck", neckRoof, ROOF, ROOF + 0.05, TEAK, M.WoodPlanks)
	edges(aft, "FunnelDeckRail", neckRoof, ROOF, 1.1, RAIL, M.Glass, 0.5)
	local rail = box(aft, "FunnelDeckRail", NECK[2] - 0.26, NECK[2] - 0.14, -NECK[3] + 0.2, NECK[3] - 0.2, ROOF, ROOF + 1.1, RAIL, M.Glass)
	rail.Transparency = 0.5
	rail.CastShadow = false

	-- The aft solarium on deck 16, behind a tall dark glass windbreak: Doremi Castle's water play,
	-- the Brezza Marina bar under its dark canopy, two whirlpools and rows of loungers
	local solarium = clip(PLAN[16][2], NECK[2], 319)
	slab(aft, "Solarium", solarium, z16 - 0.25, z16, WHITE)
	slab(aft, "SolariumDeck", widen(solarium, -0.2), z16, z16 + 0.04, TEAK, M.WoodPlanks)
	screen(aft, "SolariumScreen", widen(clip(PLAN[16][2], 281, 319), -0.3), z16, 2.3, GLASS, 0.3, 1.8)
	local floor = z16 + 0.04
	box(aft, "AquaPark", 281.5, 293.5, -6, 6, floor, floor + 0.12, rgb(86, 164, 224))
	box(aft, "AquaPark", 282.5, 292.5, -5.3, 5.3, floor + 0.12, floor + 0.17, rgb(236, 242, 246))
	for _, post in { { 284, -3.2 }, { 284, 1.6 }, { 290, -3.2 }, { 290, 1.6 } } do
		box(aft, "AquaPark", post[1] - 0.18, post[1] + 0.18, post[2] - 0.18, post[2] + 0.18, floor, floor + 4.0, rgb(250, 202, 40))
	end
	box(aft, "AquaPark", 283.7, 290.4, -3.5, 1.9, floor + 1.9, floor + 2.15, rgb(250, 202, 40))
	box(aft, "AquaPark", 283.4, 286.4, -3.7, -1.2, floor + 4.0, floor + 4.8, rgb(140, 70, 170))
	box(aft, "AquaPark", 288, 290.6, -0.4, 1.9, floor + 4.0, floor + 4.8, rgb(66, 170, 88))
	box(aft, "AquaPark", 291.2, 293, 2.6, 4.4, floor, floor + 1.7, rgb(248, 136, 36))
	tube(aft, "AquaPark", Vector3.new(287, 3.2, floor + 3.2), Vector3.new(287, 3.2, floor + 4.2), 2.0, rgb(250, 202, 40))
	for _, y in { -2.6, -1.4 } do
		strut(aft, "AquaPark", Vector3.new(290.4, y, floor + 2.0), Vector3.new(293.4, y - 2.4, floor + 0.25), 0.9, 0.28, rgb(216, 40, 40))
	end
	box(aft, "BarCounter", 298, 312, -2.6, 2.6, floor, floor + 1.1, WHITE)
	for _, x in { 296.6, 304.5, 312.4 } do
		for _, y in { -4.3, 4.3 } do
			box(aft, "BarPost", x - 0.13, x + 0.13, y - 0.13, y + 0.13, floor, floor + 2.6, WHITE)
		end
	end
	box(aft, "BarCanopy", 296, 313, -4.7, 4.7, floor + 2.6, floor + 2.8, TINTED, M.Glass).Transparency = 0.15
	box(aft, "BarCanopy", 295.9, 313.1, -4.8, 4.8, floor + 2.5, floor + 2.6, WHITE)
	for _, side in { -1, 1 } do
		whirlpool(aft, 296.5, side * 9.6, floor, 3.4)
	end
	loungers(aft, 300, 311, { 7.4, 10.4 }, floor)
	radome(aft, 291.5, -11.8, floor, 4.0)

	-- The Garden Pool on deck 15 behind turquoise glass windbreaks
	local garden = clip(PLAN[15][1], 300, PLAN[15][1][#PLAN[15][1]][1])
	screen(aft, "GardenScreen", widen(garden, -0.18), z15, 1.9, AQUA, 0.45, 1.6)
	pool(aft, 320.6, 326.4, 0, 4.6, z15 + 0.04)
	loungers(aft, 320.5, 326.5, { 7.6, 10.2 }, z15 + 0.04)
	bar(aft, 303, 307, 9.8, 12, z15 + 0.04, WHITE)
	box(aft, "Ensign", 328.2, 328.4, -0.1, 0.1, z15, z15 + 6.5, WHITE)
	dressingLine(aft, Vector3.new(268.5, 0, 53.9), Vector3.new(328.3, 0, z15 + 6.4))

	-- Vertigo: from a platform beside the funnel the navy tube runs aft, doubles back round a tight
	-- bend and falls forward along the starboard side (negative y) on tall white pylons, corkscrews down in a notch
	-- of deck 16 and runs aft again to its splash lane beside Doremi Castle
	local start = Vector3.new(275.5, -9.2, 47.9)
	for _, corner in { { -1.4, -1.4 }, { -1.4, 1.4 }, { 1.4, -1.4 }, { 1.4, 1.4 } } do
		local x, y = start.X + corner[1], start.Y + corner[2]
		box(aft, "SlideTower", x - 0.15, x + 0.15, y - 0.15, y + 0.15, ROOF, start.Z + 0.4, WHITE)
	end
	for z = ROOF + 2.5, start.Z - 1.5, 2.5 do
		box(aft, "SlideTower", start.X - 1.55, start.X + 1.55, start.Y - 1.55, start.Y + 1.55, z, z + 0.2, WHITE)
	end
	box(aft, "SlidePlatform", start.X - 1.7, start.X + 1.7, start.Y - 1.7, start.Y + 1.7, start.Z - 0.9, start.Z - 0.7, WHITE)
	for _, s in { -1, 1 } do
		box(aft, "SlidePlatformRail", start.X - 1.7, start.X + 1.7, start.Y + s * 1.62 - 0.05, start.Y + s * 1.62 + 0.05, start.Z - 0.7, start.Z + 0.4, rgb(250, 202, 40))
		box(aft, "SlidePlatformRail", start.X + s * 1.62 - 0.05, start.X + s * 1.62 + 0.05, start.Y - 1.7, start.Y + 1.7, start.Z + 0.3, start.Z + 0.4, rgb(250, 202, 40))
	end
	local path = spline({
		start,
		Vector3.new(282, -9.6, 47.7),
		Vector3.new(287.2, -10.6, 47.5),
		Vector3.new(290.2, -13.4, 47.3),
		Vector3.new(288.4, -16.4, 47.1),
		Vector3.new(283, -17.0, 46.6),
		Vector3.new(272, -17.0, 45.7),
		Vector3.new(260, -17.0, 44.7),
		Vector3.new(251, -17.0, 43.9),
		Vector3.new(246, -17.4, 43.4),
		Vector3.new(242.4, -15.6, 42.9),
		Vector3.new(242.4, -12.9, 42.5),
		Vector3.new(245.2, -11.9, 42.1),
		Vector3.new(248.2, -13.4, 41.8),
		Vector3.new(251, -14.6, 41.6),
		Vector3.new(258, -14.5, 41.4),
		Vector3.new(270, -14.5, 41.1),
		Vector3.new(278.5, -13.8, 40.95),
		Vector3.new(283.5, -11.4, 40.8),
		Vector3.new(286.6, -8.6, 40.7),
	}, 6)
	for i = 1, #path - 1 do
		-- One stretch of the fall along the side is clear acrylic
		local clear = i > 38 and i <= 46
		local pipe = tube(aft, "WaterSlide", path[i], path[i + 1], 1.3, if clear then RAIL else FUNNEL)
		if pipe and clear then
			pipe.Transparency = 0.45
		end
	end
	-- The pylons along the side stand on deck 15's rail and fork under the tube
	for _, x in { 284, 277, 270, 263, 256, 250 } do
		local zTube = 46.65 - (283 - x) * 0.083
		box(aft, "SlidePylon", x - 0.2, x + 0.2, -17.3, -16.9, z15, zTube - 1.7, WHITE)
		for _, lean in { -1.3, 1.3 } do
			strut(aft, "SlidePylon", Vector3.new(x, -17.1, zTube - 1.8), Vector3.new(x + lean, -17.0, zTube - 0.6), 0.2, 0.2, WHITE)
		end
	end
	for _, p in { Vector3.new(287.2, -10.6, 47.5), Vector3.new(290.2, -13.4, 47.3), Vector3.new(282, -9.6, 47.7) } do
		box(aft, "SlidePylon", p.X - 0.18, p.X + 0.18, p.Y - 0.18, p.Y + 0.18, z16, p.Z - 0.6, WHITE)
	end
	for x = 256, 276, 6.5 do
		box(aft, "SlidePylon", x - 0.15, x + 0.15, -14.65, -14.35, z16, 40.75, WHITE)
	end
	-- The splash lane
	box(aft, "SplashLane", 285.8, 294, -9.6, -7.6, floor, floor + 0.5, rgb(86, 164, 224))
	return aft
end

local function buildTop(parent: Instance)
	local top = Instance.new("Model")
	top.Name = "Superstructure"
	top.Parent = parent

	-- The open foredeck on deck 8, over the enclosed mooring deck: sand-coloured, with the crew's
	-- round pool, inside a bulwark that sweeps up aft into the side of the first tier
	local foredeck = clip(PLAN[8][1], 0.3, 41)
	slab(top, "Foredeck", widen(foredeck, -0.2), FLOOR[8] - 0.12, FLOOR[8] + 0.04, FOREDECK)
	local rim = {}
	for x = 0.3, 41, 1.85 do
		table.insert(rim, { x, sample(PLAN[8][1], x) })
	end
	table.insert(rim, { 41, sample(PLAN[8][1], 41) })
	local z0 = FLOOR[8] - 0.2
	for i = 1, #rim - 1 do
		local a, b = rim[i], rim[i + 1]
		for _, side in { -1, 1 } do
			local outward = Vector3.new(0, 0, side)
			local p1, p2 = at(a[1], side * a[2], z0), at(b[1], side * b[2], z0)
			local q1, q2 = at(a[1], side * a[2], bulwarkTop(a[1])), at(b[1], side * b[2], bulwarkTop(b[1]))
			triangle(top, "Bulwark", p1, p2, q1, outward, 0.25, WHITE)
			triangle(top, "Bulwark", p2, q2, q1, outward, 0.25, WHITE)
		end
		-- A stay inside the bulwark every few metres
		if i % 2 == 0 and a[2] > 2 then
			for _, side in { -1, 1 } do
				strut(
					top,
					"BulwarkStay",
					Vector3.new(a[1], side * (a[2] - 0.2), bulwarkTop(a[1]) - 0.1),
					Vector3.new(a[1], side * (a[2] - 0.9), FLOOR[8]),
					0.12,
					0.12,
					WHITE
				)
			end
		end
	end
	box(top, "Bulwark", -0.1, 0.4, -rim[1][2], rim[1][2], z0, BOW_TOP, WHITE)
	box(top, "Jackstaff", 1.4, 1.7, -0.15, 0.15, FLOOR[8], FLOOR[8] + 8, WHITE)
	whirlpool(top, 22, 0, FLOOR[8] + 0.04, 5)
	for _, x in { 7, 11.5 } do
		for _, side in { -1, 1 } do
			tube(top, "Capstan", Vector3.new(x, side * 2.4, FLOOR[8]), Vector3.new(x, side * 2.4, FLOOR[8] + 1.1), 1.2, STEEL, M.Metal)
		end
	end
	box(top, "Windlass", 13.5, 16, -3.4, 3.4, FLOOR[8], FLOOR[8] + 1.2, STEEL, M.Metal)
	-- A white breakwater across the foredeck forward of the pool
	for _, side in { -1, 1 } do
		strut(top, "Breakwater", Vector3.new(17.5, 0, FLOOR[8] + 0.45), Vector3.new(19, side * 8, FLOOR[8] + 0.45), 0.15, 0.9, WHITE)
	end

	-- The white bulwark and rail along deck 15's open sides, from the Aqua Park to the Garden Pool
	local bulwark = widen(clip(PLAN[15][1], HALL[2], 300), -0.1)
	edges(top, "Bulwark", bulwark, FLOOR[15], 1.1, WHITE, M.SmoothPlastic, 0)

	buildPools(top)
	buildYachtClubTop(top)
	buildAftTop(top)

	-- Deck 14 overhangs the lifeboats on a girder, with beams under it where the cabins stand back
	for _, side in { -1, 1 } do
		sideBox(top, "EdgeGirder", 117, 283, side * 17.2, side * 17.8, FLOOR[14] - 0.55, FLOOR[14], WHITE)
	end
	for x = 120, 280, 6 do
		local cabins = sample(PLAN[13][1], x)
		if cabins < 14 then
			for _, side in { -1, 1 } do
				sideBox(top, "SoffitBeam", x - 0.15, x + 0.15, side * cabins, side * 17.3, FLOOR[14] - 0.35, FLOOR[14] - 0.02, WHITE)
			end
		end
	end

	buildBridge(top)
	buildMast(top)
	buildFunnel(top)
	return top
end

-- The outline of a boat `length` long from `bow`, `half` its breadth, drawn in by `inset`
local function boatPlan(bow: number, length: number, half: number, inset: number)
	local h = half - inset
	return {
		{ bow + inset * 1.3, h * 0.25 },
		{ bow + length * 0.1, h * 0.72 },
		{ bow + length * 0.25, h },
		{ bow + length * 0.82, h },
		{ bow + length * 0.94, h * 0.84 },
		{ bow + length - inset * 0.8, h * 0.58 },
	}
end

-- Where the boats hang: their centre line and the height of their keels
local BOAT_Y = 18.5
local BOAT_KEEL = 11.9

-- Two davits a boat: a post against the back of the recess, an arm out over the boat and the fall
-- down to its lifting hook
local function davits(parent: Instance, bow: number, length: number, side: number, hook: number)
	for _, f in { 0.12, 0.88 } do
		local x = bow + length * f
		sideBox(parent, "Davit", x - 0.2, x + 0.2, side * 15.95, side * 16.35, RECESS[3], FLOOR[8] - 0.2, WHITE)
		local tip = Vector3.new(x, side * (BOAT_Y + 0.2), FLOOR[8] - 0.55)
		strut(parent, "Davit", Vector3.new(x, side * 16.2, FLOOR[8] - 0.35), tip, 0.3, 0.38, WHITE)
		sideBox(parent, "DavitWinch", x - 0.35, x + 0.35, side * 16.35, side * 16.95, FLOOR[8] - 1.5, FLOOR[8] - 0.75, HELM)
		strut(parent, "Fall", tip, Vector3.new(x, tip.Y, hook), 0.06, 0.06, SOOT)
		box(parent, "LiftingHook", x - 0.18, x + 0.18, tip.Y - 0.18, tip.Y + 0.18, hook - 0.25, hook, STEEL, M.Metal)
	end
end

-- A partially enclosed lifeboat: a white hull with a keel and a rubbing strake, an orange canopy
-- tumbling home to a flat roof with a hatch, a raised helm position aft and a strip of side
-- openings, hanging from two davits
local function lifeboat(parent: Instance, x: number, side: number)
	local length, half = 10.2, 2.2
	local y, k = side * BOAT_Y, BOAT_KEEL
	local bow = x - length / 2
	local function station(f: number): number
		return bow + length * f
	end
	box(parent, "Keel", station(0.14), station(0.9), y - 0.22, y + 0.22, k, k + 0.4, WHITE)
	slab(parent, "BoatHull", boatPlan(bow, length, half, 0.6), k + 0.3, k + 0.95, WHITE, nil, y)
	slab(parent, "BoatHull", boatPlan(bow, length, half, 0), k + 0.95, k + 1.75, WHITE, nil, y)
	slab(parent, "Canopy", boatPlan(bow, length, half, 0.1), k + 1.75, k + 2.65, ORANGE, nil, y)
	slab(parent, "Canopy", boatPlan(bow, length, half, 0.75), k + 2.65, k + 3.15, ORANGE, nil, y)
	box(parent, "Hatch", station(0.3), station(0.66), y - half + 1.15, y + half - 1.15, k + 3.15, k + 3.24, HELM)
	box(parent, "Helm", station(0.72), station(0.86), y - 0.6, y + 0.6, k + 3.15, k + 3.72, ORANGE)
	box(parent, "HelmWindows", station(0.72) - 0.04, station(0.86) + 0.04, y - 0.64, y + 0.64, k + 3.36, k + 3.6, GLASS)
	box(parent, "Rudder", station(0.93), station(0.99), y - 0.08, y + 0.08, k + 0.1, k + 0.95, HELM)
	for _, s in { -1, 1 } do
		sideBox(parent, "Strake", station(0.25), station(0.82), y + s * (half - 0.04), y + s * (half + 0.07), k + 1.6, k + 1.78, HELM)
		sideBox(parent, "BoatOpening", station(0.3), station(0.68), y + s * (half - 0.14), y + s * (half - 0.07), k + 1.98, k + 2.42, GLASS)
		sideBox(parent, "GrabLine", station(0.26), station(0.8), y + s * (half - 0.03), y + s * (half + 0.03), k + 1.2, k + 1.26, STEEL)
	end
	davits(parent, bow, length, side, k + 3.4)
end

-- A tender: a larger white boat with a band of cabin windows under an orange roof and a
-- wheelhouse on top
local function tender(parent: Instance, x: number, side: number)
	local length, half = 12.4, 2.3
	local y, k = side * BOAT_Y, BOAT_KEEL - 0.1
	local bow = x - length / 2
	local function station(f: number): number
		return bow + length * f
	end
	box(parent, "Keel", station(0.14), station(0.9), y - 0.25, y + 0.25, k, k + 0.4, WHITE)
	slab(parent, "BoatHull", boatPlan(bow, length, half, 0.6), k + 0.3, k + 0.95, WHITE, nil, y)
	slab(parent, "BoatHull", boatPlan(bow, length, half, 0), k + 0.95, k + 1.8, WHITE, nil, y)
	slab(parent, "Cabin", boatPlan(bow, length, half, 0.28), k + 1.8, k + 3.0, WHITE, nil, y)
	slab(parent, "CabinWindows", boatPlan(bow + 0.9, length - 1.8, half, 0.22), k + 2.15, k + 2.75, GLASS, nil, y)
	slab(parent, "Roof", boatPlan(bow + 0.3, length - 0.6, half, 0.55), k + 3.0, k + 3.2, ORANGE, nil, y)
	box(parent, "Helm", station(0.5), station(0.68), y - 0.9, y + 0.9, k + 3.2, k + 3.95, WHITE)
	box(parent, "HelmWindows", station(0.5) - 0.04, station(0.68) + 0.04, y - 0.94, y + 0.94, k + 3.45, k + 3.8, GLASS)
	box(parent, "Rudder", station(0.93), station(0.99), y - 0.08, y + 0.08, k + 0.1, k + 0.95, NAVY)
	for _, s in { -1, 1 } do
		sideBox(parent, "Strake", station(0.25), station(0.82), y + s * (half - 0.04), y + s * (half + 0.07), k + 1.62, k + 1.8, NAVY)
	end
	davits(parent, bow, length, side, k + 3.4)
end

-- The fast rescue boat: a small orange boat under a white frame crane
local function rescueBoat(parent: Instance, x: number, side: number)
	local length, half = 6.6, 1.3
	local y, k = side * BOAT_Y, BOAT_KEEL + 1.2
	local bow = x - length / 2
	slab(parent, "BoatHull", boatPlan(bow, length, half, 0.3), k, k + 0.6, ORANGE, nil, y)
	slab(parent, "BoatHull", boatPlan(bow, length, half, 0), k + 0.6, k + 1.2, ORANGE, nil, y)
	box(parent, "Helm", bow + length * 0.5, bow + length * 0.66, y - 0.45, y + 0.45, k + 1.2, k + 2.0, HELM)
	for _, f in { 0.1, 0.9 } do
		local px = bow + length * f
		sideBox(parent, "Davit", px - 0.2, px + 0.2, side * 15.95, side * 16.35, RECESS[3], FLOOR[8] - 0.2, WHITE)
		strut(
			parent,
			"Davit",
			Vector3.new(px, side * 16.2, FLOOR[8] - 0.4),
			Vector3.new(px, side * (BOAT_Y + 1.2), FLOOR[8] - 0.5),
			0.3,
			0.34,
			WHITE
		)
	end
	sideBox(parent, "Davit", bow + length * 0.1, bow + length * 0.9, side * (BOAT_Y + 0.9), side * (BOAT_Y + 1.2), FLOOR[8] - 0.7, FLOOR[8] - 0.36, WHITE)
	strut(parent, "Fall", Vector3.new(x, side * BOAT_Y, FLOOR[8] - 0.7), Vector3.new(x, side * BOAT_Y, k + 2.0), 0.06, 0.06, SOOT)
end

-- A side: eleven lifeboats, the rescue boat among them and the three tenders aft, as photographed
local LIFEBOATS = { 110.5, 122.6, 134.7, 146.8, 158.9, 171.0, 183.1, 203.0, 215.1, 227.2, 239.3 }
local RESCUE_BOAT = 193.2
local TENDERS = { 252.9, 266.7, 280.5 }

local function buildLifeboats(parent: Instance)
	local boats = Instance.new("Model")
	boats.Name = "Lifeboats"
	boats.Parent = parent
	for _, side in { -1, 1 } do
		for _, x in LIFEBOATS do
			lifeboat(boats, x, side)
		end
		rescueBoat(boats, RESCUE_BOAT, side)
		for _, x in TENDERS do
			tender(boats, x, side)
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
	buildDeck(ship, 8, FLOOR[9], { DECK8 })
	for i, deck in tops do
		local top = if tops[i + 1] then FLOOR[tops[i + 1]] else FLOOR[18]
		local pieces = PLAN[deck]
		if deck == 14 then
			-- Enclosed forward (the spa) and aft (the buffets); the pool decks lie open between them
			pieces = { clip(DECK14, DECK14[1][1], HALL[1]), clip(DECK14, AQUA_PARK[2], DECK14[#DECK14][1]) }
		elseif deck == 15 then
			-- The Yacht Club forward, the children's clubs under the Galaxy and the funnel, and La
			-- Palmeraie under the aft solarium
			pieces = {
				clip(PLAN[15][1], 51, HALL[1]),
				{ { 202, 5 }, { 203.5, 9 }, { 206, 11.5 }, { 209, 12.4 }, { 276, 12.4 }, { 279, 11 }, { 281, 8 } },
				widen(clip(PLAN[16][2], 284, 319), -1.2),
			}
		elseif deck == 16 then
			-- The Yacht Club's upper cabins, and the block that carries the funnel
			pieces = { clip(PLAN[16][1], 58, HALL[1]), { { NECK[1], NECK[3] }, { NECK[2], NECK[3] } } }
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
