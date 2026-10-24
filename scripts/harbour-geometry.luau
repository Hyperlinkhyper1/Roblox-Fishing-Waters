-- Run with scripts/check-harbour-geometry.ps1. Production Harbour source is
-- inserted at the marker, then its real builders run against recording mocks.
-- This checks surface geometry, not Roblox physics, rendering, or Studio play.

local function vectorType(dimensions)
	local methods = {}
	local mt = {}
	local function new(x, y, z)
		return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, mt)
	end
	function mt.__add(a, b)
		return new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
	end
	function mt.__sub(a, b)
		return new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
	end
	function mt.__unm(a)
		return new(-a.X, -a.Y, -a.Z)
	end
	function mt.__mul(a, b)
		if type(a) == "number" then
			a, b = b, a
		end
		return new(a.X * b, a.Y * b, a.Z * b)
	end
	function mt.__div(a, b)
		return new(a.X / b, a.Y / b, a.Z / b)
	end
	function mt.__index(a, key)
		if key == "Magnitude" then
			return math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z)
		elseif key == "Unit" then
			return a / a.Magnitude
		end
		return methods[key]
	end
	function methods:Dot(b)
		return self.X * b.X + self.Y * b.Y + self.Z * b.Z
	end
	function methods:Cross(b)
		assert(dimensions == 3)
		return new(self.Y * b.Z - self.Z * b.Y, self.Z * b.X - self.X * b.Z, self.X * b.Y - self.Y * b.X)
	end
	function methods:Min(b)
		return new(math.min(self.X, b.X), math.min(self.Y, b.Y), math.min(self.Z, b.Z))
	end
	function methods:Max(b)
		return new(math.max(self.X, b.X), math.max(self.Y, b.Y), math.max(self.Z, b.Z))
	end
	function methods:Lerp(b, t)
		return self + (b - self) * t
	end
	return { new = new, zero = new(0, 0, 0) }
end

local Vector2 = vectorType(2)
local Vector3 = vectorType(3)
local Color3 = {}
function Color3.new(r, g, b)
	return {
		R = r,
		G = g,
		B = b,
		Lerp = function(self, other, t)
			return Color3.new(
				self.R + (other.R - self.R) * t,
				self.G + (other.G - self.G) * t,
				self.B + (other.B - self.B) * t
			)
		end,
	}
end
function Color3.fromRGB(r, g, b)
	return Color3.new(r / 255, g / 255, b / 255)
end

local Random = {}
function Random.new(seed)
	local state = seed
	local rng = {}
	function rng:NextNumber(low, high)
		state = (state * 16807) % 2147483647
		local t = state / 2147483647
		return (low or 0) + ((high or 1) - (low or 0)) * t
	end
	function rng:NextInteger(low, high)
		return math.min(high, math.floor(self:NextNumber(low, high + 1)))
	end
	return rng
end

local CFrame = {}
function CFrame.new(x, y, z)
	return { Position = if type(x) == "table" then x else Vector3.new(x, y, z) }
end

local Enum = setmetatable({}, {
	__index = function(self, category)
		local values = setmetatable({}, {
			__index = function(_, value)
				return value
			end,
		})
		rawset(self, category, values)
		return values
	end,
})
local Instance = {
	new = function(kind)
		return {
			ClassName = kind,
			SetAttribute = function() end,
			FindFirstChild = function()
				return nil
			end,
			GetChildren = function()
				return {}
			end,
			GetDescendants = function()
				return {}
			end,
		}
	end,
}
local task = { wait = function() end }
local game = {
	GetService = function()
		return { AddTag = function() end }
	end,
}
local terrainFills = {}
local workspace = { Terrain = {} }
function workspace.Terrain:FillBlock(frame, size, material)
	table.insert(
		terrainFills,
		{ bottom = frame.Position.Y - size.Y / 2, top = frame.Position.Y + size.Y / 2, material = material }
	)
end
function workspace.Terrain:FillCylinder(frame, height, _radius, material)
	table.insert(
		terrainFills,
		{ bottom = frame.Position.Y - height / 2, top = frame.Position.Y + height / 2, material = material }
	)
end
local RaycastParams = {
	new = function()
		return {}
	end,
}

local surfaces = {}
local triangles, slabs = 0, 0
local plazaSlabs = {}
local function record(points, parent, kind, color)
	local name = parent.Name or "Unnamed"
	table.insert(surfaces, { points = points, group = name, kind = kind, color = color })
end
local function noop()
	return {}
end
local Props = setmetatable({}, {
	__index = function()
		return noop
	end,
})
function Props.pick(rng, values)
	return values[rng:NextInteger(1, #values)]
end
function Props.part(parent, size, frame, color, _material)
	slabs += 1
	if parent.Name == "Plaza" then
		table.insert(plazaSlabs, { Size = size, CFrame = frame, Material = _material })
	end
	local p = frame.Position
	local x, y, z = size.X / 2, size.Y / 2, size.Z / 2
	record({
		Vector3.new(p.X - x, p.Y + y, p.Z - z),
		Vector3.new(p.X + x, p.Y + y, p.Z - z),
		Vector3.new(p.X + x, p.Y + y, p.Z + z),
		Vector3.new(p.X - x, p.Y + y, p.Z + z),
	}, parent, "slab", color)
	return { Size = size, CFrame = frame }
end
local LowPoly = {}
function LowPoly.triangle(a, b, c, _inside, color, parent, _material)
	triangles += 1
	record({ a, b, c }, parent, "triangle", color)
	return {}
end
local dependencies = {
	BaseHouse = { ensure = noop },
	RodShop = { build = noop, ensure = noop },
	FurnitureShop = { build = noop, ensure = noop },
	Drydock = {
		build = noop,
		ensureDock = noop,
	},
	Props = Props,
	LowPoly = LowPoly,
	BeachDetails = setmetatable({}, {
		__index = function()
			return noop
		end,
	}),
	Islands = {
		surface = function()
			return nil
		end,
	},
	Mediterranean = setmetatable({}, {
		__index = function()
			return noop
		end,
	}),
}

local function loadBiomes()
	-- BIOMES_SOURCE --
end
local Biomes = loadBiomes()
dependencies.Biomes = Biomes
local function loadSeabed()
	-- SEABED_SOURCE --
end
local Seabed = loadSeabed()
dependencies.Seabed = Seabed
local function loadIslands()
	-- ISLANDS_SOURCE --
end
local Islands = loadIslands()

local function loadHarbour()
	-- HARBOUR_SOURCE --
end
local Harbour = loadHarbour()

local checks, failures = 0, 0
local function check(condition, message)
	checks += 1
	if not condition then
		failures += 1
		if failures <= 10 then
			print(`FAIL: {message}`)
		end
	end
end
local EPS = 1e-5
local function pointKey(point)
	return string.format("%.5f,%.5f,%.5f", point.X, point.Y, point.Z)
end
local function edgeKey(a, b)
	local ka, kb = pointKey(a), pointKey(b)
	return if ka < kb then ka .. ";" .. kb else kb .. ";" .. ka
end

-- A continuous slope has no exposed edge above its bed and no vertical side.
local function auditSlopes(label, floor, plateau)
	local edges = {}
	local slopes, boundary, joined = 0, 0, 0
	for _, surface in surfaces do
		check(surface.group ~= "Foundation", label .. ": vertical foundation remains")
		if surface.group == "Ground" or surface.group == "SeabedSlope" then
			local points = surface.points
			local normal = (points[2] - points[1]):Cross(points[3] - points[1])
			local low, high = math.huge, -math.huge
			for i, a in points do
				low, high = math.min(low, a.Y), math.max(high, a.Y)
				local b = points[i % #points + 1]
				if a.Y < 0 and b.Y < 0 then
					local key = edgeKey(a, b)
					local edge = edges[key] or { count = 0, a = a, b = b }
					edge.count += 1
					edges[key] = edge
				end
			end
			if low < 0 and high > floor then
				check(normal.Magnitude > EPS and math.abs(normal.Unit.Y) > EPS, label .. ": vertical underwater wall")
				if high - low > EPS then
					slopes += 1
				end
			end
		end
	end
	for _, edge in edges do
		check(edge.count <= 2, label .. ": overlapping underwater faces")
		if edge.count == 1 then
			boundary += 1
			if plateau and math.abs(edge.a.Y - plateau) < EPS and math.abs(edge.b.Y - plateau) < EPS then
				joined += 1 -- the inner rim is embedded into the solid biome bed
			else
				check(math.max(edge.a.Y, edge.b.Y) <= floor, label .. ": underwater mesh stops above the bed")
			end
		end
	end
	if plateau then
		check(joined == 96, label .. ": shelf rim does not meet the solid bed")
	end
	check(boundary > 0 and slopes > 0, label .. ": missing continuous slope into the bed")
	print(label .. ": continuous slope, all open edges buried in the bed.")
end
local function area(points)
	local sum = 0
	for i, p in points do
		local q = points[i % #points + 1]
		sum += p.X * q.Z - q.X * p.Z
	end
	return sum * 0.5
end
local function side(p, a, b)
	return (b.X - a.X) * (p.Z - a.Z) - (b.Z - a.Z) * (p.X - a.X)
end
local function clippedArea(subject, clip)
	local polygon = subject
	local winding = if area(clip) > 0 then 1 else -1
	for i, a in clip do
		local b = clip[i % #clip + 1]
		local output = {}
		if #polygon == 0 then
			return 0
		end
		local previous = polygon[#polygon]
		local previousDistance = side(previous, a, b) * winding
		for _, current in polygon do
			local currentDistance = side(current, a, b) * winding
			local currentInside, previousInside = currentDistance >= 0, previousDistance >= 0
			if currentInside ~= previousInside then
				local t = previousDistance / (previousDistance - currentDistance)
				table.insert(output, previous:Lerp(current, t))
			end
			if currentInside then
				table.insert(output, current)
			end
			previous, previousDistance = current, currentDistance
		end
		polygon = output
	end
	return math.abs(area(polygon))
end

local function prepare(surface)
	local points = surface.points
	local normal = (points[2] - points[1]):Cross(points[3] - points[1])
	check(normal.Magnitude > EPS, `Degenerate {surface.group} {surface.kind}`)
	surface.normal = normal.Unit
	surface.minX, surface.maxX, surface.minZ, surface.maxZ = math.huge, -math.huge, math.huge, -math.huge
	local coordinates = {}
	for _, p in points do
		check(p.X == p.X and p.Y == p.Y and p.Z == p.Z, "Geometry contains NaN")
		surface.minX, surface.maxX = math.min(surface.minX, p.X), math.max(surface.maxX, p.X)
		surface.minZ, surface.maxZ = math.min(surface.minZ, p.Z), math.max(surface.maxZ, p.Z)
		table.insert(coordinates, string.format("%.4f,%.4f,%.4f", p.X, p.Y, p.Z))
	end
	table.sort(coordinates)
	surface.key = table.concat(coordinates, ";")
	if surface.group == "Ground" then
		check(area(points) > EPS, "Ground triangle inverted in the horizontal plane")
	end
end

local function auditSurfaces()
	local bins, unique = {}, {}
	local overlaps, candidates = 0, 0
	for index, surface in surfaces do
		prepare(surface)
		check(not unique[surface.key], `Duplicate surface in {surface.group}`)
		unique[surface.key] = true
		local seen = {}
		local minX, maxX = math.floor(surface.minX / 32), math.floor(surface.maxX / 32)
		local minZ, maxZ = math.floor(surface.minZ / 32), math.floor(surface.maxZ / 32)
		for x = minX, maxX do
			for z = minZ, maxZ do
				local key = `{x},{z}`
				local bin = bins[key] or {}
				for _, other in bin do
					if seen[other] then
						continue
					end
					seen[other] = true
					if
						surface.maxX <= other.minX + EPS
						or surface.minX >= other.maxX - EPS
						or surface.maxZ <= other.minZ + EPS
						or surface.minZ >= other.maxZ - EPS
					then
						continue
					end
					candidates += 1
					if surface.normal:Cross(other.normal).Magnitude > EPS then
						continue
					end
					if math.abs(surface.normal:Dot(other.points[1] - surface.points[1])) > EPS then
						continue
					end
					local overlap = clippedArea(surface.points, other.points)
					if overlap > EPS then
						overlaps += 1
						if overlaps <= 5 then
							print(`OVERLAP {surface.group}/{other.group}: {overlap} square studs, surface {index}`)
						end
					end
				end
				table.insert(bin, surface)
				bins[key] = bin
			end
		end
	end
	check(overlaps == 0, `{overlaps} coplanar positive-area overlaps found`)
	print(
		`Audited {#surfaces} emitted surfaces ({triangles} triangles, {slabs} slab tops); {candidates} nearby pairs; {overlaps} coplanar area overlaps.`
	)
end

local shape = Harbour.makeShape(Vector2.zero)
check(#shape.beach > 30, "Beach shoreline must be subdivided into a smooth curve")
local totalLength, curvature = 0, 0
for i, point in shape.beach do
	check(math.abs(Harbour.coastDistance(shape, point)) < EPS, "Beach props and land use different coastlines")
	if i > 1 then
		local length = (point - shape.beach[i - 1]).Magnitude
		check(length > EPS and length < 9, "Beach curve has a duplicate or oversized edge")
		totalLength += length
	end
	if i > 2 then
		local before, after = point - shape.beach[i - 1], shape.beach[i - 1] - shape.beach[i - 2]
		curvature += math.abs(before.X * after.Y - before.Y * after.X)
	end
end
check(math.abs(totalLength - shape.beachLength) < EPS, "Beach length does not match its vertices")
check(curvature > 1, "Beach coastline remains straight")
print(`Shared curved beach: {#shape.beach} vertices, {string.format("%.1f", shape.beachLength)} studs.`)

local function auditGroundGrid()
	local minX, minZ = math.huge, math.huge
	for _, point in shape.coast do
		minX, minZ = math.min(minX, point.X), math.min(minZ, point.Y)
	end
	minX, minZ = minX - Harbour.GROUND_MARGIN, minZ - Harbour.GROUND_MARGIN
	local vertices, cells = {}, {}
	local displaced, maxOffset = 0, 0
	local diagonals = { 0, 0 }
	for _, surface in surfaces do
		if surface.group ~= "Ground" then
			continue
		end
		local indices = {}
		local lowI, highI, lowK, highK = math.huge, -math.huge, math.huge, -math.huge
		for _, point in surface.points do
			local i = math.floor((point.X - minX) / Harbour.CELL + 0.5)
			local k = math.floor((point.Z - minZ) / Harbour.CELL + 0.5)
			local dx, dz = point.X - minX - i * Harbour.CELL, point.Z - minZ - k * Harbour.CELL
			local offset = math.max(math.abs(dx), math.abs(dz))
			maxOffset = math.max(maxOffset, offset)
			check(offset <= Harbour.CELL * 0.24 + EPS, "Ground jitter exceeds the non-inversion bound")
			if surface.kind == "slab" then
				check(offset < EPS, "Merged flat slab has an irregular edge")
			end
			local key = `{i},{k}`
			local previous = vertices[key]
			if previous then
				check((point - previous).Magnitude < EPS, "Adjacent ground surfaces disagree at a shared vertex")
			else
				vertices[key] = point
				if offset > EPS then
					displaced += 1
				end
			end
			table.insert(indices, { i, k })
			lowI, highI = math.min(lowI, i), math.max(highI, i)
			lowK, highK = math.min(lowK, k), math.max(highK, k)
		end
		if surface.kind == "triangle" then
			check(highI - lowI == 1 and highK - lowK == 1, "Ground triangle no longer covers one source cell")
			local key = `{lowI},{lowK}`
			cells[key] = (cells[key] or 0) + 1
			for i, a in indices do
				local b = indices[i % #indices + 1]
				if math.abs(a[1] - b[1]) == 1 and math.abs(a[2] - b[2]) == 1 then
					local diagonal = if (a[1] - b[1]) * (a[2] - b[2]) > 0 then 1 else 2
					diagonals[diagonal] += 1
				end
			end
		end
	end
	for _, count in cells do
		check(count == 2, "Ground cell has a missing or duplicated triangle")
	end
	check(displaced > 100, "Beach mesh remains aligned to the straight square grid")
	check(diagonals[1] > 100 and diagonals[2] > 100, "Ground mesh uses only one diagonal direction")
	print(
		`Shared ground vertices agree; {displaced} irregular vertices, maximum axis offset {string.format(
			"%.3f",
			maxOffset
		)} studs; both diagonal directions present.`
	)
end

local parent = Instance.new("Model")
Harbour.buildGround(shape, parent, Random.new(8173))
auditSlopes("Harbour", Biomes.SeaFloor)
check(#terrainFills == 0, "Harbour still emits stepped terrain terraces")
if Harbour.beachTakesIsland then
	Harbour.buildBeach(shape, parent, parent, {}, Random.new(9281))
else
	Harbour.buildBeach(shape, parent, {}, Random.new(9281))
end
Harbour.buildPlaza(parent, shape.toWorld({ 870, 694 }), Random.new(1039))
-- Side faces need their own projection: the top-surface audit cannot see a
-- foundation, inlay and curb competing for pixels on a vertical edge.
local function sideOverlaps(parts)
	local faces = {}
	for i, part in parts do
		local p, h = part.CFrame.Position, part.Size / 2
		for _, sign in { -1, 1 } do
			table.insert(faces, {
				owner = i,
				axis = "X",
				sign = sign,
				plane = p.X + sign * h.X,
				low = p.Z - h.Z,
				high = p.Z + h.Z,
				bottom = p.Y - h.Y,
				top = p.Y + h.Y,
			})
			table.insert(faces, {
				owner = i,
				axis = "Z",
				sign = sign,
				plane = p.Z + sign * h.Z,
				low = p.X - h.X,
				high = p.X + h.X,
				bottom = p.Y - h.Y,
				top = p.Y + h.Y,
			})
		end
	end
	local count = 0
	for i, a in faces do
		for j = i + 1, #faces do
			local b = faces[j]
			if a.owner == b.owner or a.axis ~= b.axis or a.sign ~= b.sign or math.abs(a.plane - b.plane) > EPS then
				continue
			end
			local width = math.min(a.high, b.high) - math.max(a.low, b.low)
			local height = math.min(a.top, b.top) - math.max(a.bottom, b.bottom)
			if width > EPS and height > EPS then
				count += 1
			end
		end
	end
	return count
end
local plazaOverlapCount = sideOverlaps(plazaSlabs)
check(plazaOverlapCount == 0, `{plazaOverlapCount} coplanar plaza side overlaps`)
print(`Plaza: {#plazaSlabs} paving/curb blocks, {plazaOverlapCount} coplanar vertical overlaps.`)

if Harbour.ensurePlazaPaving then
	-- Reconstruct the old full-width foundation and edge-reaching inlays from
	-- the new paving, then exercise the production saved-map update in place.
	local parts = {}
	local center = plazaSlabs[1].CFrame.Position
	for _, item in plazaSlabs do
		local s, p = item.Size, item.CFrame.Position
		if math.abs(s.Y - 0.6) < EPS then
			s = Vector3.new(120, s.Y, 120)
		elseif math.abs(s.Y - 0.12) < EPS then
			if s.Z > 100 then
				s = Vector3.new(s.X, s.Y, 120)
			elseif math.abs(p.X - s.X / 2 - (center.X - 58)) < EPS then
				s = Vector3.new(s.X + 2, s.Y, s.Z)
				p -= Vector3.new(1, 0, 0)
			elseif math.abs(p.X + s.X / 2 - (center.X + 58)) < EPS then
				s = Vector3.new(s.X + 2, s.Y, s.Z)
				p += Vector3.new(1, 0, 0)
			end
		end
		local part = {
			Size = s,
			CFrame = CFrame.new(p),
			Material = item.Material,
			IsA = function(_, class)
				return class == "Part"
			end,
		}
		setmetatable(part, {
			__index = function(self, key)
				if key == "Position" then
					return self.CFrame.Position
				end
			end,
		})
		table.insert(parts, part)
	end
	check(sideOverlaps(parts) > 0, "Saved plaza fixture must reproduce side z-fighting")
	local version = nil
	local saved = {
		Name = "Plaza",
		IsA = function(_, class)
			return class == "Model"
		end,
		GetAttribute = function()
			return version
		end,
		SetAttribute = function(_, _, value)
			version = value
		end,
		GetChildren = function()
			return parts
		end,
	}
	local root = {
		GetDescendants = function()
			return { saved }
		end,
	}
	Harbour.ensurePlazaPaving(root)
	check(version == 2, "Saved plaza update must be marked complete")
	check(sideOverlaps(parts) == 0, "Saved plaza side overlaps remain")
	for i, part in parts do
		check((part.Size - plazaSlabs[i].Size).Magnitude < EPS, "Saved/new paving sizes differ")
		check(
			(part.CFrame.Position - plazaSlabs[i].CFrame.Position).Magnitude < EPS,
			"Saved/new paving placement differs"
		)
	end
	Harbour.ensurePlazaPaving(root)
	check(sideOverlaps(parts) == 0, "Repeated saved-map update changed the plaza")
	print(
		"Saved plaza: original overlaps reproduced, updated paving matches fresh generation; repeated update is stable."
	)
end
auditGroundGrid()
auditSurfaces()

if
	false -- EXPORT_PREVIEW --
then
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, point in shape.beach do
		minX, maxX = math.min(minX, point.X), math.max(maxX, point.X)
		minZ, maxZ = math.min(minZ, point.Y), math.max(maxZ, point.Y)
	end
	minX, maxX, minZ, maxZ = minX - 100, maxX + 100, minZ - 100, maxZ + 100
	local svg = {
		string.format(
			'<svg xmlns="http://www.w3.org/2000/svg" viewBox="%f %f %f %f">',
			minX,
			minZ,
			maxX - minX,
			maxZ - minZ
		),
		string.format(
			'<rect x="%f" y="%f" width="%f" height="%f" fill="#649ca7"/>',
			minX,
			minZ,
			maxX - minX,
			maxZ - minZ
		),
	}
	for _, surface in surfaces do
		if surface.minX > maxX or surface.maxX < minX or surface.minZ > maxZ or surface.maxZ < minZ then
			continue
		end
		local points, y = {}, 0
		for _, point in surface.points do
			table.insert(points, string.format("%.3f,%.3f", point.X, point.Z))
			y += point.Y / #surface.points
		end
		local color = surface.color
		local r, g, b = color.R, color.G, color.B
		if y < 0 and surface.group == "Ground" then
			local depth = math.clamp(-y / 20, 0, 1)
			r, g, b = 0.45 - depth * 0.12, 0.75 - depth * 0.12, 0.76 - depth * 0.08
		end
		local fill = string.format("#%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
		table.insert(
			svg,
			string.format(
				'<polygon points="%s" fill="%s" stroke="#33464a" stroke-opacity=".3" stroke-width=".3"/>',
				table.concat(points, " "),
				fill
			)
		)
	end
	table.insert(
		svg,
		string.format(
			'<text x="%f" y="%f" font-family="sans-serif" font-size="7" fill="white">Actual emitted geometry - top view, props omitted</text>',
			minX + 8,
			minZ + 14
		)
	)
	table.insert(svg, "</svg>")
	print("HARBOUR_SVG_BEGIN")
	print(table.concat(svg, "\n"))
	print("HARBOUR_SVG_END")
end
surfaces = {}
for _, shapeName in { "plateau", "peak", "stack", "mound", "berg", "volcano", "atoll" } do
	for _, radius in { 6, 75, 160, 440 } do
		for _, seed in { 1847, 9281 } do
			surfaces = {}
			Islands.build({
				position = Vector2.new(713, -289),
				radius = radius,
				height = if shapeName == "atoll" then 7 else radius * 0.5,
				shape = shapeName,
				palette = {
					top = Color3.fromRGB(98, 116, 78),
					cliff = Color3.fromRGB(120, 118, 116),
					shore = Color3.fromRGB(186, 172, 138),
				},
				rng = Random.new(seed),
			})
			auditSlopes(`{shapeName}, radius {radius}, seed {seed}`, Biomes.SeaFloor)
		end
	end
end
for _, floor in { Biomes.SeaFloor, -22, -14 } do
	local previous = 0
	for distance = 1, 128 do
		local height = Seabed.height(distance, 128, 0, floor)
		check(height < previous, "Underwater slope contains a plateau or uphill step")
		previous = height
	end
	check(math.abs(previous - floor) < EPS, "Slope does not meet its local bed")
	check(math.abs(Seabed.height(0, 128, 0, floor)) < EPS, "Slope does not meet the waterline")
	check(math.abs(Seabed.height(136, 128, 0, floor) - (floor - 8)) < EPS, "Slope overlap is not buried")
	-- The final tangent flattens into the bed instead of ending with a wall.
	check(math.abs(Seabed.height(127.99, 128, 0, floor) - previous) < 0.001, "Slope ends abruptly")
	surfaces = {}
	Islands.build({
		position = Vector2.zero,
		radius = 100,
		height = 7,
		shape = "atoll",
		palette = {
			top = Color3.fromRGB(98, 116, 78),
			cliff = Color3.fromRGB(120, 118, 116),
			shore = Color3.fromRGB(186, 172, 138),
		},
		rng = Random.new(1847),
		seaFloor = floor,
	})
	auditSlopes("Atoll, local bed " .. floor, floor)
end
terrainFills = {}
for _, top in { -22, -14 } do
	surfaces = {}
	Seabed.shelf(Vector2.new(80, -140), 1250, top, Enum.Material.Mud, Color3.fromRGB(64, 58, 36), parent)
	check(math.abs(terrainFills[#terrainFills].top - top) < EPS, "Biome shelf surface height changed")
	auditSlopes("Biome shelf " .. top, Biomes.SeaFloor, top)
end
for _, fill in terrainFills do
	check(fill.bottom <= Biomes.SeaFloor - 4, "Biome bed floats above the sea floor")
	check(fill.top > fill.bottom, "Biome bed has an invalid height")
end
assert(failures == 0, `{failures} geometry checks failed`)
print(`PASS: {checks} geometry assertions. Recording mocks do not verify Roblox rendering or live gameplay.`)
