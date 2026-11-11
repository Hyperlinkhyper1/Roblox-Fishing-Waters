-- The shark's real geometry: a smooth lofted hull, thick tapered fins, a
-- hinged lower jaw and rows of teeth, as triangle meshes. Clients turn these
-- into EditableMesh skins (SharkMeshes); the server places eyes and gills on
-- the same surface (SharkModel). Pure math on plain {x, y, z} arrays so it also
-- runs in offline checks.
--
-- Model space matches SharkModel: snout towards -Z, +Y up, origin on the water
-- surface. Everything below is designed in "design units" and built at SCALE
-- studs per unit: section(), surfaceX(), bottomY() and undersideY() answer in
-- design units, build(), joints() and jawPivot() in studs.
--
-- The hull is cut into swim segments at JOINTS; SharkSwim bends each joint in
-- turn so a wave runs from the head to the tail. Neighbouring segments overlap,
-- and each segment's overlap is pulled in a little so the owning segment's
-- surface always wins and no gap opens when the body bends.
local SharkShape = {}

SharkShape.SCALE = 1.35

-- Great-white countershading shared by the skin and the server's parts (RGB).
SharkShape.COLORS = {
	Back = { 66, 78, 88 },
	Line = { 142, 149, 151 },
	Belly = { 228, 229, 223 },
	Mouth = { 92, 32, 40 },
}

SharkShape.SNOUT_Z = -5.6
SharkShape.END_Z = 4.95
local OVERLAP = 0.3
local INSET = 0.985
local LENGTH = SharkShape.END_Z - SharkShape.SNOUT_Z

-- Swim joints (design z), each with its share of the body wave: the head and
-- trunk stay steady while the stalk and tail sweep, like a fast pelagic shark.
SharkShape.JOINTS = {
	{ z = 0.3, amplitude = 0.06 },
	{ z = 1.6, amplitude = 0.12 },
	{ z = 2.8, amplitude = 0.2 },
	{ z = 4.1, amplitude = 0.34 },
}
-- Phase lag between neighbouring joints (radians), so the wave travels backwards.
SharkShape.JOINT_LAG = 0.75

-- The mouth: a U-shaped gape under the head, reaching from the jaw hinge
-- forward to its front (half width across, length forward from the hinge).
local JAW_HINGE_Z = -2.85
local JAW_HALF_WIDTH = 0.92
local JAW_LENGTH = 1.22
SharkShape.JAW_OPEN = 0.55 -- radians at full gape

-- Body profile along the length (u = 0 snout tip, 1 tail stalk end): half
-- width, height above the axis, depth below it and the axis height. A conical
-- snout, deepest just behind the gills, then a long taper to a slim stalk.
local PROFILE = {
	{ 0.0, 0.0, 0.0, 0.0, -1.12 },
	{ 0.02, 0.24, 0.17, 0.2, -1.14 },
	{ 0.05, 0.45, 0.33, 0.38, -1.17 },
	{ 0.1, 0.74, 0.56, 0.62, -1.22 },
	{ 0.17, 1.02, 0.82, 0.88, -1.28 },
	{ 0.25, 1.27, 1.04, 1.08, -1.34 },
	{ 0.35, 1.46, 1.22, 1.24, -1.4 },
	{ 0.45, 1.44, 1.19, 1.2, -1.42 },
	{ 0.56, 1.24, 1.0, 1.0, -1.42 },
	{ 0.66, 0.96, 0.78, 0.76, -1.4 },
	{ 0.76, 0.64, 0.53, 0.5, -1.37 },
	{ 0.85, 0.39, 0.34, 0.31, -1.35 },
	{ 0.92, 0.27, 0.23, 0.21, -1.34 },
	{ 1.0, 0.2, 0.17, 0.16, -1.33 },
}

-- Monotone cubic (Fritsch-Carlson) tangents per column, so nothing overshoots.
local tangents = {}
for column = 2, 5 do
	local slopes, result = {}, {}
	for index = 1, #PROFILE - 1 do
		local a, b = PROFILE[index], PROFILE[index + 1]
		slopes[index] = (b[column] - a[column]) / (b[1] - a[1])
	end
	result[1], result[#PROFILE] = slopes[1], slopes[#PROFILE - 1]
	for index = 2, #PROFILE - 1 do
		local before, after = slopes[index - 1], slopes[index]
		result[index] = if before * after <= 0 then 0 else 2 / (1 / before + 1 / after)
	end
	tangents[column] = result
end

local function profileAt(u: number): (number, number, number, number)
	u = math.clamp(u, 0, 1)
	local index = 1
	while index < #PROFILE - 1 and PROFILE[index + 1][1] < u do
		index += 1
	end
	local a, b = PROFILE[index], PROFILE[index + 1]
	local h = b[1] - a[1]
	local t = (u - a[1]) / h
	local t2, t3 = t * t, t * t * t
	local h00, h10, h01, h11 = 2 * t3 - 3 * t2 + 1, t3 - 2 * t2 + t, -2 * t3 + 3 * t2, t3 - t2
	local values = {}
	for column = 2, 5 do
		values[column] = h00 * a[column]
			+ h10 * h * tangents[column][index]
			+ h01 * b[column]
			+ h11 * h * tangents[column][index + 1]
	end
	return math.max(values[2], 0), math.max(values[3], 0), math.max(values[4], 0), values[5]
end

local function uAt(z: number): number
	return (z - SharkShape.SNOUT_Z) / LENGTH
end

-- Half width, height above and depth below the axis, and the axis height at z.
function SharkShape.section(z: number): (number, number, number, number)
	return profileAt(uAt(z))
end

-- Lateral keels: a low ridge along each flank of the tail stalk.
local function keel(u: number): number
	local t = (u - 0.935) / 0.07
	return 0.45 * math.exp(-t * t)
end

-- How far into the mouth's U a point lies (0 = hinge centre, 1 = rim), or nil
-- behind the hinge.
local function mouthRadius(x: number, z: number): number?
	if z > JAW_HINGE_Z then
		return nil
	end
	local dz = (z - JAW_HINGE_Z) / JAW_LENGTH
	return math.sqrt((x / JAW_HALF_WIDTH) ^ 2 + dz * dz)
end

-- The roof of the mouth: inside the U the hull's underside is pushed up into
-- the head as a dome, which the closed jaw hides and the open jaw reveals.
local function palateRise(r: number): number
	return if r < 1 then 0.45 * (1 - r * r) ^ 2 else 0
end

-- Hull point at length u and angle `angle` (0 = top, pi = belly, positive = +X side).
local function hullPoint(u: number, angle: number): (number, number, number)
	local w, top, bottom, axis = profileAt(u)
	local s, c = math.sin(angle), math.cos(angle)
	local flank = 1 - math.abs(c)
	local x = w * s * (1 + keel(u) * flank * flank * flank)
	-- Blends top and bottom halves smoothly through the flank.
	local y = axis + c * (top + bottom) / 2 + c * c * (top - bottom) / 2
	local z = SharkShape.SNOUT_Z + u * LENGTH
	if c < 0 then
		local r = mouthRadius(x, z)
		if r then
			y += palateRise(r)
		end
	end
	return x, y, z
end

-- Height on the surface for a given half-angle cosine, inverted: the cosine
-- whose surface height is y at z (nil outside the hull).
local function cosineAt(z: number, y: number): number?
	local _, top, bottom, axis = SharkShape.section(z)
	local a, b, c0 = (top - bottom) / 2, (top + bottom) / 2, axis - y
	local c
	if math.abs(a) < 1e-6 then
		c = -c0 / b
	else
		local disc = b * b - 4 * a * c0
		if disc < 0 then
			return nil
		end
		c = (-b + math.sqrt(disc)) / (2 * a)
		if c < -1 or c > 1 then
			c = (-b - math.sqrt(disc)) / (2 * a)
		end
	end
	return if c >= -1 and c <= 1 then c else nil
end

-- Half width of the hull at height y and length z (0 above or below it).
function SharkShape.surfaceX(z: number, y: number): number
	local c = cosineAt(z, y)
	if not c then
		return 0
	end
	local w = SharkShape.section(z)
	return w * math.sqrt(1 - c * c)
end

function SharkShape.bottomY(z: number): number
	local _, _, bottom, axis = SharkShape.section(z)
	return axis - bottom
end

-- Height of the underside at length z, `x` studs off the centreline.
function SharkShape.undersideY(z: number, x: number): number
	local w, top, bottom, axis = SharkShape.section(z)
	if w <= 0 then
		return axis
	end
	local c = -math.sqrt(math.max(0, 1 - (x / w) ^ 2))
	return axis + c * (top + bottom) / 2 + c * c * (top - bottom) / 2
end

function SharkShape.topY(z: number): number
	local _, top, _, axis = SharkShape.section(z)
	return axis + top
end

local function sub(a, b)
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end
local function cross(a, b)
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end
local function dot(a, b)
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end
local function normalize(a)
	local m = math.sqrt(dot(a, a))
	return if m > 1e-12 then { a[1] / m, a[2] / m, a[3] / m } else { 0, 1, 0 }
end

-- Outward unit normal from the parametric surface.
local function hullNormal(u: number, angle: number)
	local e = 1e-4
	local function at(du, da)
		local x, y, z = hullPoint(math.clamp(u + du, 0, 1), angle + da)
		return { x, y, z }
	end
	local n = cross(sub(at(0, e), at(0, -e)), sub(at(e, 0), at(-e, 0)))
	local x, y, z = hullPoint(u, angle)
	local _, _, _, axis = profileAt(u)
	local outward = { x, y - axis, 0 }
	if dot(n, outward) < 0 then
		n = { -n[1], -n[2], -n[3] }
	end
	return normalize(n)
end

-- A mesh under construction: positions, normals and triangles wound outward.
local function newMesh()
	return { positions = {}, normals = {}, triangles = {} }
end
local function vertex(mesh, position, normal): number
	table.insert(mesh.positions, position)
	table.insert(mesh.normals, normal)
	return #mesh.positions
end
-- Wound so (b - a) x (c - a) faces along the vertex normals, the side Roblox draws.
local function triangle(mesh, a: number, b: number, c: number)
	local p = mesh.positions
	local n = cross(sub(p[b], p[a]), sub(p[c], p[a]))
	if dot(n, n) < 1e-14 then
		return
	end
	local m = mesh.normals
	local sum = { m[a][1] + m[b][1] + m[c][1], m[a][2] + m[b][2] + m[c][2], m[a][3] + m[b][3] + m[c][3] }
	if dot(n, sum) < 0 then
		b, c = c, b
	end
	table.insert(mesh.triangles, { a, b, c })
end
local function append(target, source)
	local offset = #target.positions
	for index, position in source.positions do
		table.insert(target.positions, position)
		table.insert(target.normals, source.normals[index])
	end
	for _, tri in source.triangles do
		table.insert(target.triangles, { tri[1] + offset, tri[2] + offset, tri[3] + offset })
	end
end

-- Colour bands around the hull, from the back (0) to the belly (1). The thin
-- middle band blends the two, giving a crisp but not jagged countershading line.
SharkShape.BANDS = {
	{ name = "Back", from = 0, to = 0.5, steps = 16 },
	{ name = "Line", from = 0.5, to = 0.57, steps = 3 },
	{ name = "Belly", from = 0.57, to = 1, steps = 14 },
}

-- Ring positions along the body: denser at the snout, with exact rings at
-- every segment cut so neighbouring segments share their edges.
local function rings(): { number }
	local list = {}
	local count = 60
	for index = 0, count do
		local t = index / count
		table.insert(list, t ^ 1.2)
	end
	for _, joint in SharkShape.JOINTS do
		for _, z in { joint.z - OVERLAP, joint.z, joint.z + OVERLAP } do
			table.insert(list, uAt(z))
		end
	end
	table.sort(list)
	local unique = {}
	for _, u in list do
		if #unique == 0 or u - unique[#unique] > 1e-4 then
			table.insert(unique, u)
		end
	end
	return unique
end

-- One colour band of one swim segment, both flanks. Rings outside the
-- segment's own joints (its overlap into a neighbour) are pulled in slightly.
-- Triangles inside the mouth go to a separate Mouth-coloured mesh.
local function hullBand(band, segment)
	local mesh, mouth = newMesh(), newMesh()
	local us = {}
	for _, u in rings() do
		local z = SharkShape.SNOUT_Z + u * LENGTH
		if z >= segment.low - 1e-6 and z <= segment.high + 1e-6 then
			table.insert(us, u)
		end
	end
	for _, side in { 1, -1 } do
		local grid = {}
		for ring, u in us do
			local row = {}
			local z0 = SharkShape.SNOUT_Z + u * LENGTH
			local inset = if z0 < segment.from - 1e-6 or z0 > segment.to + 1e-6 then INSET else 1
			local _, _, _, axis = profileAt(u)
			for step = 0, band.steps do
				local angle = side * math.pi * (band.from + (band.to - band.from) * step / band.steps)
				if u <= 0 then
					-- The snout tip collapses each row to one point facing forward.
					local x, y, z = hullPoint(0, angle)
					row[step] = vertex(mesh, { x, y, z }, { 0, 0, -1 })
				else
					local x, y, z = hullPoint(u, angle)
					row[step] = vertex(mesh, { x * inset, axis + (y - axis) * inset, z }, hullNormal(u, angle))
				end
			end
			grid[ring] = row
		end
		for ring = 1, #us - 1 do
			local row, nextRow = grid[ring], grid[ring + 1]
			for step = 0, band.steps - 1 do
				triangle(mesh, row[step], nextRow[step], nextRow[step + 1])
				triangle(mesh, row[step], nextRow[step + 1], row[step + 1])
			end
		end
		-- Cap the end of the stalk (hidden in the tail root, but keeps it closed).
		if us[#us] >= 1 - 1e-6 then
			local _, _, _, axis = profileAt(1)
			local last = grid[#us]
			local center = vertex(mesh, { 0, axis, SharkShape.END_Z }, { 0, 0, 1 })
			for step = 0, band.steps - 1 do
				triangle(mesh, center, last[step], last[step + 1])
			end
		end
	end
	-- Move mouth triangles (centre inside the U, on the underside) to the Mouth mesh.
	local kept, copied = {}, {}
	for _, tri in mesh.triangles do
		local cx, cy, cz = 0, 0, 0
		for _, v in tri do
			local p = mesh.positions[v]
			cx, cy, cz = cx + p[1] / 3, cy + p[2] / 3, cz + p[3] / 3
		end
		local r = mouthRadius(cx, cz)
		local _, _, _, axis = SharkShape.section(cz)
		if r and r < 1 and cy < axis then
			local mapped = {}
			for index, v in tri do
				if not copied[v] then
					copied[v] = vertex(mouth, mesh.positions[v], mesh.normals[v])
				end
				mapped[index] = copied[v]
			end
			table.insert(mouth.triangles, mapped)
		else
			table.insert(kept, tri)
		end
	end
	mesh.triangles = kept
	return mesh, mouth
end

-- A thick fin: `outline` points (roughly planar) fanned from `center`, swelling
-- to `thickness` in the middle and closing to a knife edge at the outline.
-- Edge vertices are shared by both faces, so the rim shades round.
local function fin(outline, center, thickness: number)
	local mesh = newMesh()
	-- Plane normal (Newell's method).
	local n = { 0, 0, 0 }
	for index, a in outline do
		local b = outline[index % #outline + 1]
		n[1] += (a[2] - b[2]) * (a[3] + b[3])
		n[2] += (a[3] - b[3]) * (a[1] + b[1])
		n[3] += (a[1] - b[1]) * (a[2] + b[2])
	end
	n = normalize(n)
	local layers = { 0, 0.35, 0.65, 0.88, 1 }
	local function profile(s: number): number
		return thickness * math.max(0, 1 - s * s) ^ 0.65
	end
	local rows = { [1] = {}, [-1] = {} }
	local edge = {}
	local accumulated = {}
	local function place(index: number)
		accumulated[index] = { 0, 0, 0 }
		return index
	end
	for index, point in outline do
		edge[index] = place(vertex(mesh, point, n))
	end
	for _, side in { 1, -1 } do
		local faceNormal = { n[1] * side, n[2] * side, n[3] * side }
		for layer, s in layers do
			local row = {}
			if s >= 1 then
				row = edge
			elseif s <= 0 then
				-- One centre vertex per face.
				local half = profile(0) / 2 * side
				local middle = place(vertex(mesh, {
					center[1] + n[1] * half,
					center[2] + n[2] * half,
					center[3] + n[3] * half,
				}, faceNormal))
				for index in outline do
					row[index] = middle
				end
			else
				local half = profile(s) / 2 * side
				for index, point in outline do
					row[index] = place(vertex(mesh, {
						center[1] + (point[1] - center[1]) * s + n[1] * half,
						center[2] + (point[2] - center[2]) * s + n[2] * half,
						center[3] + (point[3] - center[3]) * s + n[3] * half,
					}, faceNormal))
				end
			end
			rows[side][layer] = row
		end
	end
	-- Smooth normals: area-weighted face normals summed per vertex, faces wound
	-- away from the fin plane on each side.
	local faces = {}
	for _, side in { 1, -1 } do
		for layer = 1, #layers - 1 do
			local row, nextRow = rows[side][layer], rows[side][layer + 1]
			for index = 1, #outline do
				local following = index % #outline + 1
				for _, tri in
					{
						{ row[index], nextRow[index], nextRow[following] },
						{ row[index], nextRow[following], row[following] },
					}
				do
					local a, b, c = tri[1], tri[2], tri[3]
					if a ~= b and b ~= c and a ~= c then
						local p = mesh.positions
						local face = cross(sub(p[b], p[a]), sub(p[c], p[a]))
						if dot(face, n) * side < 0 then
							face = { -face[1], -face[2], -face[3] }
							b, c = c, b
						end
						table.insert(faces, { a, b, c })
						for _, v in { a, b, c } do
							local sum = accumulated[v]
							sum[1] += face[1]
							sum[2] += face[2]
							sum[3] += face[3]
						end
					end
				end
			end
		end
	end
	for index, sum in accumulated do
		mesh.normals[index] = normalize(sum)
	end
	for _, face in faces do
		triangle(mesh, face[1], face[2], face[3])
	end
	return mesh
end

-- Fin outlines in model space, by the swim segment that carries them.
local function mirror(points)
	local result = {}
	for index, p in points do
		result[index] = { -p[1], p[2], p[3] }
	end
	return result
end
local PECTORAL = {
	{ 1.0, -1.75, -2.25 },
	{ 1.9, -2.05, -1.75 },
	{ 2.7, -2.38, -0.95 },
	{ 3.35, -2.66, -0.05 },
	{ 3.62, -2.8, 0.42 },
	{ 3.3, -2.7, 0.3 },
	{ 2.6, -2.48, -0.18 },
	{ 1.8, -2.2, -0.62 },
	{ 1.0, -2.0, -0.95 },
}
local PELVIC = {
	{ 0.45, -1.95, 1.4 },
	{ 0.95, -2.3, 2.05 },
	{ 1.3, -2.58, 2.62 },
	{ 0.95, -2.45, 2.55 },
	{ 0.45, -2.15, 2.3 },
}
local FINS = {
		{
			-- First dorsal: straight leading edge, pointed apex, concave trailing edge.
			outline = {
				{ 0, -0.55, -1.25 },
				{ 0, -0.05, -0.92 },
				{ 0, 0.55, -0.48 },
				{ 0, 1.1, 0.02 },
				{ 0, 1.58, 0.5 },
				{ 0, 1.2, 0.52 },
				{ 0, 0.7, 0.55 },
				{ 0, 0.22, 0.72 },
				{ 0, -0.12, 1.02 },
				{ 0, -0.55, 0.6 },
			},
			center = { 0, -0.15, -0.25 },
			thickness = 0.3,
		},
		{ outline = PECTORAL, center = { 1.8, -2.22, -1.2 }, thickness = 0.24 },
		{ outline = mirror(PECTORAL), center = { -1.8, -2.22, -1.2 }, thickness = 0.24 },
		{
			outline = { { 0, -0.98, 2.2 }, { 0, -0.6, 2.5 }, { 0, -0.3, 2.78 }, { 0, -0.55, 2.88 }, { 0, -0.88, 3.2 } },
			center = { 0, -0.8, 2.65 },
			thickness = 0.12,
		},
		{
			outline = { { 0, -1.72, 2.6 }, { 0, -2.05, 2.85 }, { 0, -2.32, 3.0 }, { 0, -2.08, 3.18 }, { 0, -1.75, 3.4 } },
			center = { 0, -1.85, 2.95 },
			thickness = 0.12,
		},
		{ outline = PELVIC, center = { 0.75, -2.2, 2.05 }, thickness = 0.12 },
		{ outline = mirror(PELVIC), center = { -0.75, -2.2, 2.05 }, thickness = 0.12 },
		{
			-- Upper caudal lobe: long, raked and sickle-shaped.
			outline = {
				{ 0, -1.05, 4.3 },
				{ 0, -0.55, 4.85 },
				{ 0, 0.25, 5.45 },
				{ 0, 1.0, 6.0 },
				{ 0, 1.45, 6.42 },
				{ 0, 1.15, 6.3 },
				{ 0, 0.55, 5.95 },
				{ 0, -0.2, 5.6 },
				{ 0, -0.85, 5.4 },
				{ 0, -1.35, 5.3 },
				{ 0, -1.5, 4.75 },
			},
			center = { 0, -0.75, 5.05 },
			thickness = 0.22,
		},
		{
			-- Lower lobe, nearly as long: the crescent of a fast pelagic shark.
			outline = {
				{ 0, -1.25, 4.75 },
				{ 0, -1.35, 5.3 },
				{ 0, -1.85, 5.62 },
				{ 0, -2.55, 5.95 },
				{ 0, -3.15, 6.12 },
				{ 0, -2.9, 5.78 },
				{ 0, -2.4, 5.35 },
				{ 0, -1.9, 4.95 },
				{ 0, -1.55, 4.6 },
			},
			center = { 0, -1.75, 5.15 },
			thickness = 0.2,
		},
}

-- Swim segment `index` covers z from its own joint to the next (`from`..`to`),
-- plus OVERLAP into each neighbour (`low`..`high`).
SharkShape.SEGMENTS = {}
for index = 0, #SharkShape.JOINTS do
	local before, after = SharkShape.JOINTS[index], SharkShape.JOINTS[index + 1]
	table.insert(SharkShape.SEGMENTS, {
		index = index,
		from = if before then before.z else SharkShape.SNOUT_Z,
		to = if after then after.z else SharkShape.END_Z,
		low = if before then before.z - OVERLAP else SharkShape.SNOUT_Z,
		high = if after then after.z + OVERLAP else SharkShape.END_Z,
	})
end

-- The swim segment (0 = head) a design-space z belongs to.
function SharkShape.segmentAt(z: number): number
	local index = 0
	for k, joint in SharkShape.JOINTS do
		if z >= joint.z then
			index = k
		end
	end
	return index
end

-- Joint pivots in studs, on the body axis, with each joint's wave amplitude.
function SharkShape.joints()
	local list = {}
	for index, joint in SharkShape.JOINTS do
		local _, _, _, axis = SharkShape.section(joint.z)
		list[index] = {
			pivot = { 0, axis * SharkShape.SCALE, joint.z * SharkShape.SCALE },
			amplitude = joint.amplitude,
			lag = SharkShape.JOINT_LAG * index,
		}
	end
	return list
end

-- The jaw hinges about the X axis through this point, above the mouth's back edge.
local function jawHinge()
	return { 0, SharkShape.undersideY(JAW_HINGE_Z, 0) + 0.3, JAW_HINGE_Z }
end
function SharkShape.jawPivot()
	local p = jawHinge()
	return { p[1] * SharkShape.SCALE, p[2] * SharkShape.SCALE, p[3] * SharkShape.SCALE }
end

-- A point on the jaw's U: r from the hinge centre (0) to the rim (1), phi from
-- one corner (-pi/2) round the front (0) to the other.
local function jawXZ(r: number, phi: number): (number, number)
	return r * JAW_HALF_WIDTH * math.sin(phi), JAW_HINGE_Z - r * JAW_LENGTH * math.cos(phi)
end
local function jawR(x: number, z: number): number
	return math.sqrt((x / JAW_HALF_WIDTH) ^ 2 + ((z - JAW_HINGE_Z) / JAW_LENGTH) ^ 2)
end
-- Outward direction of the U's rim at phi, in the horizontal plane.
local function rimNormal(phi: number)
	return normalize({ math.sin(phi) / JAW_HALF_WIDTH, 0, -math.cos(phi) / JAW_LENGTH })
end

local JAW_RIM = 1.04
local function jawOuter(x: number, z: number): number
	return SharkShape.undersideY(z, x) - 0.035
end
local function jawInner(x: number, z: number): number
	local r = jawR(x, z)
	return SharkShape.undersideY(z, x) + 0.16 * math.max(0, 1 - r * r) + 0.02
end

-- A height-field surface over the jaw's U, facing up (+1) or down (-1).
-- Returns the grid of vertex indices so edges can be stitched.
local function jawSurface(mesh, height, facing: number)
	local rings, columns = 9, 20
	local grid = {}
	for i = 0, rings do
		local row = {}
		local r = JAW_RIM * i / rings
		for j = 0, columns do
			local x, z = jawXZ(r, -math.pi / 2 + math.pi * j / columns)
			local e = 1e-3
			local hx = (height(x + e, z) - height(x - e, z)) / (2 * e)
			local hz = (height(x, z + e) - height(x, z - e)) / (2 * e)
			local n = normalize({ -hx * facing, facing, -hz * facing })
			row[j] = vertex(mesh, { x, height(x, z), z }, n)
		end
		grid[i] = row
	end
	for i = 0, rings - 1 do
		for j = 0, columns - 1 do
			triangle(mesh, grid[i][j], grid[i + 1][j], grid[i + 1][j + 1])
			triangle(mesh, grid[i][j], grid[i + 1][j + 1], grid[i][j + 1])
		end
	end
	return grid, rings, columns
end

-- A tooth: a slim four-sided blade from a base on the gum to a point,
-- `down` for the upper row. Flat-shaded faces.
local function tooth(mesh, base, outward, down: boolean, width: number, length: number)
	local thickness = 0.045
	local tangent = { -outward[3], 0, outward[1] }
	local function corner(t, o)
		return {
			base[1] + tangent[1] * t * width / 2 + outward[1] * o * thickness / 2,
			base[2],
			base[3] + tangent[3] * t * width / 2 + outward[3] * o * thickness / 2,
		}
	end
	local corners = { corner(-1, 1), corner(1, 1), corner(1, -1), corner(-1, -1) }
	-- Points rake slightly inward, like a real shark's.
	local tip = {
		base[1] - outward[1] * 0.03,
		base[2] + (if down then -length else length),
		base[3] - outward[3] * 0.03,
	}
	local middle = {
		base[1] + (tip[1] - base[1]) * 0.3,
		base[2] + (tip[2] - base[2]) * 0.3,
		base[3] + (tip[3] - base[3]) * 0.3,
	}
	for index = 1, 4 do
		local a, b = corners[index], corners[index % 4 + 1]
		local n = cross(sub(b, a), sub(tip, a))
		local centroid = { (a[1] + b[1] + tip[1]) / 3, (a[2] + b[2] + tip[2]) / 3, (a[3] + b[3] + tip[3]) / 3 }
		if dot(n, sub(centroid, middle)) < 0 then
			n = { -n[1], -n[2], -n[3] }
		end
		n = normalize(n)
		triangle(mesh, vertex(mesh, a, n), vertex(mesh, b, n), vertex(mesh, tip, n))
	end
end

-- Upper teeth hang from the head just outside the jaw's rim, so a few show
-- over the closed lip; they stay with the head when the jaw drops.
local function upperTeeth()
	local mesh = newMesh()
	local count = 15
	for k = 0, count - 1 do
		local phi = -1.32 + 2.64 * k / (count - 1)
		local edge = math.abs(phi) / 1.32
		local x, z = jawXZ(JAW_RIM + 0.05, phi)
		local base = { x, SharkShape.undersideY(z, x) + 0.04, z }
		tooth(mesh, base, rimNormal(phi), true, 0.14 - 0.05 * edge, 0.24 - 0.12 * edge)
	end
	return mesh
end

-- The lower jaw, closed: a pale underside just below the head's, a lip round
-- the rim, a dark mouth floor inside and a row of teeth along it.
local function lowerJaw()
	local outer, inner = newMesh(), newMesh()
	local outerGrid, rings, columns = jawSurface(outer, jawOuter, -1)
	-- The floor is built in its own mesh, and copied into the outer one only
	-- for stitching positions.
	local innerGrid = jawSurface(inner, jawInner, 1)
	-- Lip round the rim and walls along the hinge line, joining the two surfaces.
	local function stitch(outerIndex, innerIndex, normal)
		local a = vertex(outer, outer.positions[outerIndex], normal)
		local b = vertex(outer, inner.positions[innerIndex], normal)
		return a, b
	end
	for j = 0, columns - 1 do
		local phi0 = -math.pi / 2 + math.pi * j / columns
		local phi1 = -math.pi / 2 + math.pi * (j + 1) / columns
		local a0, b0 = stitch(outerGrid[rings][j], innerGrid[rings][j], rimNormal(phi0))
		local a1, b1 = stitch(outerGrid[rings][j + 1], innerGrid[rings][j + 1], rimNormal(phi1))
		triangle(outer, a0, a1, b1)
		triangle(outer, a0, b1, b0)
	end
	-- The hinge-line walls lie in the plane z = hinge, facing back into the head.
	for _, j in { 0, columns } do
		for i = 0, rings - 1 do
			local a0, b0 = stitch(outerGrid[i][j], innerGrid[i][j], { 0, 0, 1 })
			local a1, b1 = stitch(outerGrid[i + 1][j], innerGrid[i + 1][j], { 0, 0, 1 })
			triangle(outer, a0, a1, b1)
			triangle(outer, a0, b1, b0)
		end
	end
	local count = 13
	for k = 0, count - 1 do
		local phi = -1.22 + 2.44 * k / (count - 1)
		local edge = math.abs(phi) / 1.22
		local x, z = jawXZ(0.93, phi)
		local base = { x, jawInner(x, z) - 0.02, z }
		tooth(outer, base, rimNormal(phi), false, 0.12 - 0.04 * edge, 0.18 - 0.08 * edge)
	end
	return outer, inner
end

local function scaled(mesh)
	local factor = SharkShape.SCALE
	for index, p in mesh.positions do
		mesh.positions[index] = { p[1] * factor, p[2] * factor, p[3] * factor }
	end
	return mesh
end

-- Every skin mesh, in studs: { segment, band, jaw?, positions, normals,
-- triangles }. Fins share the Back band of their segment and the upper teeth
-- the head's Belly band; the mouth's roof is its own Mouth mesh, and the lower
-- jaw is two meshes (pale outside with teeth, dark floor) marked `jaw`.
function SharkShape.build()
	local meshes = {}
	local roof = newMesh()
	for _, segment in SharkShape.SEGMENTS do
		for _, band in SharkShape.BANDS do
			local mesh, mouth = hullBand(band, segment)
			append(roof, mouth)
			if band.name == "Back" then
				for _, spec in FINS do
					if SharkShape.segmentAt(spec.center[3]) == segment.index then
						append(mesh, fin(spec.outline, spec.center, spec.thickness))
					end
				end
			elseif band.name == "Belly" and segment.index == 0 then
				append(mesh, upperTeeth())
			end
			mesh.segment, mesh.band = segment.index, band.name
			table.insert(meshes, mesh)
		end
	end
	roof.segment, roof.band = 0, "Mouth"
	table.insert(meshes, roof)
	local outer, inner = lowerJaw()
	outer.segment, outer.band, outer.jaw = 0, "Belly", true
	inner.segment, inner.band, inner.jaw = 0, "Mouth", true
	table.insert(meshes, outer)
	table.insert(meshes, inner)
	for _, mesh in meshes do
		scaled(mesh)
	end
	return meshes
end

return SharkShape
