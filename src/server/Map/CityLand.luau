-- Mainland geometry for the distant city: an irregular coastline cut by a long estuary.
-- Coordinates are {x, z} pairs relative to the city centre; a third entry "quay" marks
-- the edge that starts at that point as a straight concrete quay wall, and "edge" marks a
-- straight edge where the land carries on as hills (see CityHills) rather than meeting water.
local LowPoly = require(script.Parent.LowPoly)

local CityLand = {}

export type Point = { any }

local STRIP = 360 -- tallest strip the fill cuts the polygon into
local SPAN = 520 -- widest single slab; wedge parts stay far below the 2048-stud limit

-- Natural edges are broken into short jittered segments so shores never run ruler-straight.
-- The jitter is seeded by position, so every server builds the same coast.
function CityLand.roughen(points: { Point }, segment: number, jitter: number): { Point }
	local result = {}
	for i, a in points do
		local b = points[i % #points + 1]
		table.insert(result, a)
		if a[3] == nil then
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local length = math.sqrt(dx * dx + dz * dz)
			local steps = math.floor(length / segment)
			for s = 1, steps - 1 do
				local t = s / steps
				local wobble = math.sin(a[1] * 0.013 + a[2] * 0.017 + s * 2.3) * jitter
				table.insert(result, { a[1] + dx * t - dz / length * wobble, a[2] + dz * t + dx / length * wobble })
			end
		end
	end
	return result
end

function CityLand.inside(points: { Point }, x: number, z: number): boolean
	local inside = false
	local j = #points
	for i = 1, #points do
		local a, b = points[i], points[j]
		if (a[2] > z) ~= (b[2] > z) and x < (b[1] - a[1]) * (z - a[2]) / (b[2] - a[2]) + a[1] then
			inside = not inside
		end
		j = i
	end
	return inside
end

-- Shortest distance from a point to the coastline.
function CityLand.edgeDistance(points: { Point }, x: number, z: number): number
	local best = math.huge
	for i, a in points do
		local b = points[i % #points + 1]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local t = math.clamp(((x - a[1]) * dx + (z - a[2]) * dz) / math.max(dx * dx + dz * dz, 1e-6), 0, 1)
		local px, pz = a[1] + dx * t - x, a[2] + dz * t - z
		best = math.min(best, math.sqrt(px * px + pz * pz))
	end
	return best
end

-- True when a whole rectangle lies on land at least `margin` from the coast.
function CityLand.fits(points: { Point }, cx: number, cz: number, w: number, d: number, margin: number): boolean
	for _, corner in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 }, { 0, 0 } } do
		local x, z = cx + corner[1] * w / 2, cz + corner[2] * d / 2
		if not CityLand.inside(points, x, z) or CityLand.edgeDistance(points, x, z) < margin then
			return false
		end
	end
	return true
end

-- Fills the polygon with solid wedge slabs. The polygon is cut into horizontal strips at
-- every vertex, so inside a strip each pair of crossing edges bounds one trapezoid.
-- `holes` are inland rectangles {x0, x1, z0, z1} left open, for rooms below ground.
function CityLand.fill(parent: Instance, points: { Point }, origin: Vector3, top: number, bottom: number, color: Color3, material: Enum.Material, holes: { { number } }?)
	local cuts = {}
	for _, p in points do
		table.insert(cuts, p[2])
	end
	local openings = table.clone(holes or {})
	table.sort(openings, function(a, b)
		return a[1] < b[1]
	end)
	for _, hole in openings do
		table.insert(cuts, hole[3])
		table.insert(cuts, hole[4])
	end
	table.sort(cuts)
	local levels = {}
	for _, z in cuts do
		local last = levels[#levels]
		if not last or z - last > 0.5 then
			if last then
				-- Keep strips short enough that no wedge grows too long
				local steps = math.ceil((z - last) / STRIP)
				for s = 1, steps - 1 do
					table.insert(levels, last + (z - last) * s / steps)
				end
			end
			table.insert(levels, z)
		end
	end

	local thickness = top - bottom
	local function slab(x00: number, x10: number, x01: number, x11: number, z0: number, z1: number)
		local a = origin + Vector3.new(x00, top, z0)
		local b = origin + Vector3.new(x10, top, z0)
		local c = origin + Vector3.new(x11, top, z1)
		local d = origin + Vector3.new(x01, top, z1)
		local below = origin + Vector3.new((x00 + x10 + x01 + x11) / 4, bottom - 10, (z0 + z1) / 2)
		LowPoly.triangle(a, b, c, below, color, parent, material, thickness)
		LowPoly.triangle(a, c, d, below, color, parent, material, thickness)
	end

	for level = 1, #levels - 1 do
		local z0, z1 = levels[level], levels[level + 1]
		local zm = (z0 + z1) / 2
		local crossings = {}
		for i, a in points do
			local b = points[i % #points + 1]
			if (a[2] <= zm) ~= (b[2] <= zm) then
				local function at(z: number): number
					return a[1] + (b[1] - a[1]) * (z - a[2]) / (b[2] - a[2])
				end
				table.insert(crossings, { at(z0), at(z1), at(zm) })
			end
		end
		table.sort(crossings, function(p, q)
			return p[3] < q[3]
		end)
		for k = 1, #crossings - 1, 2 do
			-- Each span is {left at z0, right at z0, left at z1, right at z1}, cut around holes
			local left, right = crossings[k], crossings[k + 1]
			local spans = {}
			local l0, l1 = left[1], left[2]
			for _, hole in openings do
				if hole[3] <= z0 and hole[4] >= z1 and hole[1] > math.max(l0, l1) and hole[2] < math.min(right[1], right[2]) then
					table.insert(spans, { l0, hole[1], l1, hole[1] })
					l0, l1 = hole[2], hole[2]
				end
			end
			table.insert(spans, { l0, right[1], l1, right[2] })
			for _, span in spans do
				local pieces = math.max(1, math.ceil(math.max(span[2] - span[1], span[4] - span[3]) / SPAN))
				for s = 0, pieces - 1 do
					local t0, t1 = s / pieces, (s + 1) / pieces
					slab(
						span[1] + (span[2] - span[1]) * t0,
						span[1] + (span[2] - span[1]) * t1,
						span[3] + (span[4] - span[3]) * t0,
						span[3] + (span[4] - span[3]) * t1,
						z0,
						z1
					)
				end
			end
		end
	end
end

-- Dresses every edge: a concrete wall and coping along quays, and elsewhere a low band
-- of weathered rock with a strip of shingle at the waterline.
function CityLand.shore(parent: Instance, points: { Point }, origin: Vector3, top: number)
	local rock = Color3.fromRGB(92, 88, 80)
	local shingle = Color3.fromRGB(148, 138, 116)
	local quay = Color3.fromRGB(118, 117, 110)
	local coping = Color3.fromRGB(171, 166, 150)
	for i, a in points do
		local b = points[i % #points + 1]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local length = math.sqrt(dx * dx + dz * dz)
		if length < 1 or a[3] == "edge" then
			continue
		end
		local mx, mz = (a[1] + b[1]) / 2, (a[2] + b[2]) / 2
		local nx, nz = dz / length, -dx / length
		if CityLand.inside(points, mx + nx * 2, mz + nz * 2) then
			nx, nz = -nx, -nz
		end
		local mid = origin + Vector3.new(mx, 0, mz)
		local facing = CFrame.lookAt(mid, mid + Vector3.new(dx, 0, dz))
		local function band(name: string, size: Vector3, out: number, y: number, color: Color3, material: Enum.Material)
			local p = Instance.new("Part")
			p.Name = name
			p.Anchored = true
			p.Size = size
			p.CFrame = facing + Vector3.new(nx * out, y, nz * out)
			p.Color = color
			p.Material = material
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.Parent = parent
		end
		if a[3] == "quay" then
			band("QuayWall", Vector3.new(3, top + 16, length), 1, (top - 16) / 2, quay, Enum.Material.Concrete)
			band("QuayCoping", Vector3.new(4, 0.8, length), 1.5, top + 0.1, coping, Enum.Material.Concrete)
		else
			band("ShoreRock", Vector3.new(12, top + 6, length + 10), 3, (top - 6) / 2 - 1, rock, Enum.Material.Slate)
			band("Shingle", Vector3.new(16, 3, length + 14), 9, -0.6, shingle, Enum.Material.Pebble)
		end
	end
end

return CityLand
