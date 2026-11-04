-- Detailed fish built entirely from local parts, so no mesh or image upload is
-- needed. Bodies are overlapping ellipsoids (darker back and paler belly layers
-- give countershading), fins are wedge-pair triangles and markings are thin
-- discs laid on the body surface. Builders work in "fish lengths" (snout at
-- X = +0.5, tail at -0.5, back towards +Y) and are scaled to studs on creation.
local FishModels = {}
local FishMutations = require(script.Parent.FishMutations)
local FishSpecies = require(script.Parent.FishSpecies)

local SCALE = 4 -- studs per fish length
local FIN = 0.004
local rgb = Color3.fromRGB
local templates: { [string]: Model } = {}
-- Smooth skins by species (see Builder:loftBody), for FishMeshes on clients.
local lofts = {}
local LOFT_STEPS = 6 -- rings between two stations
FishModels.SCALE = SCALE
FishModels.LOFT_TAG = "FishLoft"

type Ellipsoid = { c: Vector3, h: Vector3 }

local function seeded(seed: number)
	local state = seed
	return function(low: number, high: number): number
		state = (state * 16807) % 2147483647
		return low + (high - low) * (state / 2147483647)
	end
end

local Builder = {}
Builder.__index = Builder

local function newBuilder(name: string, seed: number)
	local model = Instance.new("Model")
	model.Name = name
	return setmetatable({ model = model, sections = {} :: { Ellipsoid }, random = seeded(seed) }, Builder)
end

function Builder:part(name: string, class: string, size: Vector3, frame: CFrame, color: Color3, transparency: number?)
	local item = Instance.new(class) :: BasePart
	item.Name = name
	item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = true, false, false, false
	item.CastShadow = false
	item.Material = Enum.Material.SmoothPlastic
	item.TopSurface, item.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	item.Color = color
	item.Transparency = transparency or 0
	item.Size = Vector3.new(math.max(size.X, 0.0003), math.max(size.Y, 0.0003), math.max(size.Z, 0.0003)) * SCALE
	item.CFrame = frame.Rotation + frame.Position * SCALE
	item.Parent = self.model
	return item
end

function Builder:ellipsoid(name: string, frame: CFrame, size: Vector3, color: Color3, transparency: number?)
	local item = self:part(name, "Part", size, frame, color, transparency)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = item
	return item
end

-- An axis-aligned ellipsoid that markings can be laid on.
function Builder:body(name: string, center: Vector3, size: Vector3, color: Color3, transparency: number?)
	table.insert(self.sections, { c = center, h = size / 2 })
	return self:ellipsoid(name, CFrame.new(center), size, color, transparency)
end

-- Main colour with a darker back and paler belly layer offset above and below.
function Builder:layered(name: string, center: Vector3, size: Vector3, colors)
	self:body(name, center, size, colors.side)
	self:body(
		name .. "Back",
		center + Vector3.new(0, size.Y * 0.12, 0),
		size * Vector3.new(0.985, 0.86, 1.012),
		colors.back
	)
	self:body(
		name .. "Belly",
		center - Vector3.new(0, size.Y * 0.14, 0),
		size * Vector3.new(0.97, 0.8, 1.006),
		colors.belly
	)
end

-- Loft rings are { x, top, bottom, width (half) } cross-sections, snout first.
type Ring = { x: number, top: number, bottom: number, width: number }

-- Point on a loft cross-section; angle 0 is the back, pi the belly and positive
-- angles the +Z flank. Slightly egg-shaped: narrow over the back, fullest
-- just below the middle.
local function loftPoint(ring: Ring, angle: number): Vector3
	local c = math.cos(angle)
	local middle, half = (ring.top + ring.bottom) / 2, (ring.top - ring.bottom) / 2
	return Vector3.new(ring.x, middle + half * c, ring.width * math.sin(angle) * (1 - 0.18 * c))
end

-- The cross-section at x, between the two rings around it; outside the loft it
-- is nil, or the nearest end ring when `clamp` is set.
local function loftRing(rings: { Ring }, x: number, clamp: boolean?): Ring?
	if x >= rings[1].x then
		return if clamp then rings[1] else nil
	end
	for index = 2, #rings do
		local a, b = rings[index - 1], rings[index]
		if x >= b.x then
			local t = (a.x - x) / math.max(a.x - b.x, 1e-6)
			return {
				x = x,
				top = a.top + (b.top - a.top) * t,
				bottom = a.bottom + (b.bottom - a.bottom) * t,
				width = a.width + (b.width - a.width) * t,
			}
		end
	end
	return if clamp then rings[#rings] else nil
end

-- Outward unit normal of the loft skin at x and angle.
local function loftNormal(rings: { Ring }, x: number, angle: number): Vector3
	local ring = loftRing(rings, x, true) :: Ring
	local step = 0.004
	local ahead, behind = loftRing(rings, x + step, true) :: Ring, loftRing(rings, x - step, true) :: Ring
	local along = loftPoint(ahead, angle) - loftPoint(behind, angle)
	local around = loftPoint(ring, angle + 0.01) - loftPoint(ring, angle - 0.01)
	local point = loftPoint(ring, angle)
	local outward = point - Vector3.new(ring.x, (ring.top + ring.bottom) / 2, 0)
	local normal = along:Cross(around)
	if normal.Magnitude < 1e-9 then
		return if outward.Magnitude > 1e-9 then outward.Unit else Vector3.new(1, 0, 0)
	end
	normal = normal.Unit
	return if normal:Dot(outward) < 0 then -normal else normal
end

local function catmull(p0: number, p1: number, p2: number, p3: number, t: number): number
	return 0.5
		* (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (3 * p1 - p0 - 3 * p2 + p3) * t * t * t)
end

-- Outermost body surface at (x, y) on one side (+1 or -1), with its normal.
function Builder:surface(x: number, y: number, side: number): (Vector3?, Vector3?)
	if self.loft then
		local ring = loftRing(self.loft, x)
		if not ring or ring.top <= ring.bottom then
			return nil, nil
		end
		local c = (y - (ring.top + ring.bottom) / 2) / ((ring.top - ring.bottom) / 2)
		if math.abs(c) >= 1 then
			return nil, nil
		end
		local angle = math.acos(c) * side
		return loftPoint(ring, angle), loftNormal(self.loft, x, angle)
	end
	local best: Ellipsoid? = nil
	local bestZ = -1
	for _, section in self.sections do
		local dx, dy = (x - section.c.X) / section.h.X, (y - section.c.Y) / section.h.Y
		local remaining = 1 - dx * dx - dy * dy
		if remaining > 0 then
			local z = section.c.Z * side + section.h.Z * math.sqrt(remaining)
			if z > bestZ then
				best, bestZ = section, z
			end
		end
	end
	if not best then
		return nil, nil
	end
	local h = best.h
	local normal = Vector3.new(
		(x - best.c.X) / (h.X * h.X),
		(y - best.c.Y) / (h.Y * h.Y),
		side * (bestZ - best.c.Z * side) / (h.Z * h.Z)
	).Unit
	return Vector3.new(x, y, side * bestZ), normal
end

function Builder:top(x: number): number
	if self.loft then
		local ring = loftRing(self.loft, x)
		return if ring then math.max(ring.top, 0) else 0
	end
	local best = 0
	for _, section in self.sections do
		local dx = (x - section.c.X) / section.h.X
		if dx * dx < 1 then
			best = math.max(best, section.c.Y + section.h.Y * math.sqrt(1 - dx * dx))
		end
	end
	return best
end

function Builder:bottom(x: number): number
	if self.loft then
		local ring = loftRing(self.loft, x)
		return if ring then math.min(ring.bottom, 0) else 0
	end
	local best = 0
	for _, section in self.sections do
		local dx = (x - section.c.X) / section.h.X
		if dx * dx < 1 then
			best = math.min(best, section.c.Y - section.h.Y * math.sqrt(1 - dx * dx))
		end
	end
	return best
end

-- A thin disc painted onto the body. direction is a world X/Y heading for the
-- disc's long axis; the far side receives the mirror image automatically.
function Builder:mark(
	x: number,
	y: number,
	side: number,
	width: number,
	height: number,
	color: Color3,
	direction: Vector2?,
	lift: number?
)
	local position, normal = self:surface(x, y, side)
	if not position or not normal then
		return nil
	end
	local up = if math.abs(normal.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
	local frame = CFrame.lookAt(position, position + normal, up)
	if direction then
		local heading = frame:VectorToObjectSpace(Vector3.new(direction.X, direction.Y, 0))
		frame *= CFrame.Angles(0, 0, math.atan2(heading.Y, heading.X))
	end
	frame = frame + normal * (0.0025 + (lift or 0))
	return self:ellipsoid("Marking", frame, Vector3.new(width, height, 0.004), color)
end

function Builder:marks(x: number, y: number, width: number, height: number, color: Color3, direction: Vector2?)
	for _, side in { 1, -1 } do
		self:mark(x, y, side, width, height, color, direction)
	end
end

-- Overlapping elongated discs along a polyline on both flanks.
function Builder:stroke(points: { Vector2 }, width: number, color: Color3)
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local delta = b - a
		local steps = math.max(1, math.ceil(delta.Magnitude / (width * 1.6)))
		for step = 0, steps - 1 do
			local point = a + delta * ((step + 0.5) / steps)
			self:marks(point.X, point.Y, delta.Magnitude / steps * 1.5, width, color, delta)
		end
	end
end

function Builder:eye(x: number, y: number, size: number, iris: Color3)
	for _, side in { 1, -1 } do
		local position, normal = self:surface(x, y, side)
		if not position or not normal then
			continue
		end
		local frame = CFrame.lookAt(position, position + normal)
		self:ellipsoid("Eye", frame, Vector3.new(size, size, size * 0.35), iris)
		self:ellipsoid(
			"Pupil",
			frame + normal * size * 0.06,
			Vector3.new(size * 0.6, size * 0.6, size * 0.4),
			rgb(12, 12, 14)
		)
		local glint = position + normal * size * 0.24 + Vector3.new(size * 0.12, size * 0.14, 0)
		self:ellipsoid("EyeGlint", CFrame.new(glint), Vector3.one * size * 0.16, rgb(255, 255, 255))
	end
end

-- Two wedges make an arbitrary triangle (the standard Roblox triangle method).
function Builder:triangle(a: Vector3, b: Vector3, c: Vector3, color: Color3, transparency: number?)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local normal = ac:Cross(ab)
	if normal.Magnitude < 1e-7 then
		return
	end
	local right = normal.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local first = self:part(
		"Fin",
		"WedgePart",
		Vector3.new(FIN, height, math.abs(ab:Dot(back))),
		CFrame.fromMatrix((a + b) / 2, right, up, back),
		color,
		transparency
	)
	local second = self:part(
		"Fin",
		"WedgePart",
		Vector3.new(FIN, height, math.abs(ac:Dot(back))),
		CFrame.fromMatrix((a + c) / 2, -right, up, -back),
		color,
		transparency
	)
	return first, second
end

-- Fan triangulation; points may be Vector2 (placed at z) or Vector3.
function Builder:fin(points: { any }, color: Color3, transparency: number?, z: number?)
	local function point(value): Vector3
		return if typeof(value) == "Vector2" then Vector3.new(value.X, value.Y, z or 0) else value
	end
	for index = 2, #points - 1 do
		self:triangle(point(points[1]), point(points[index]), point(points[index + 1]), color, transparency)
	end
end

-- A tapered rod between two points (barbels, arms, fin rays, filaments).
function Builder:limb(a: Vector3, b: Vector3, diameter: number, color: Color3, name: string?)
	local delta = b - a
	if delta.Magnitude < 1e-5 then
		return nil
	end
	local up = if math.abs(delta.Unit.Y) > 0.98 then Vector3.xAxis else Vector3.yAxis
	local frame = CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.pi / 2, 0)
	return self:ellipsoid(name or "Limb", frame, Vector3.new(delta.Magnitude * 1.08, diameter, diameter), color)
end

function Builder:rays(base: Vector2, tips: { Vector2 }, color: Color3)
	for _, tip in tips do
		self:limb(Vector3.new(base.X, base.Y, 0), Vector3.new(tip.X, tip.Y, 0), 0.0055, color, "FinRay")
	end
end

function Builder:finSpot(x: number, y: number, size: number, color: Color3)
	for _, side in { 1, -1 } do
		self:ellipsoid("FinSpot", CFrame.new(x, y, side * FIN * 0.6), Vector3.new(size, size, 0.003), color)
	end
end

-- Paired fin flat against one flank, angled down and back.
function Builder:pectoral(x: number, y: number, length: number, width: number, color: Color3, transparency: number?)
	for _, side in { 1, -1 } do
		local position = self:surface(x, y, side)
		if not position then
			continue
		end
		local z = position.Z + side * 0.008
		self:fin({
			Vector3.new(x, y + width * 0.4, z),
			Vector3.new(x - length * 0.55, y + width * 0.1, z + side * length * 0.25),
			Vector3.new(x - length, y - width * 0.35, z + side * length * 0.35),
			Vector3.new(x - length * 0.6, y - width * 0.75, z + side * length * 0.2),
			Vector3.new(x, y - width * 0.4, z),
		}, color, transparency)
	end
end

-- Spots scattered over part of the flank, skipping anything off the body.
function Builder:speckle(count: number, xRange: Vector2, yRange: Vector2, sizeRange: Vector2, color: Color3)
	for _ = 1, count do
		local x, y = self.random(xRange.X, xRange.Y), self.random(yRange.X, yRange.Y)
		local size = self.random(sizeRange.X, sizeRange.Y)
		if y < self:top(x) - size and y > self:bottom(x) + size then
			self:marks(x, y, size, size * self.random(0.8, 1.1), color)
		end
	end
end

local function v2(x: number, y: number): Vector2
	return Vector2.new(x, y)
end

-- Shared bony-fish body: head, chest, rear body and tail stalk.
function Builder:fishBody(depth: number, width: number, colors, headDrop: number?)
	local drop = headDrop or 0.05
	self:layered("Chest", Vector3.new(0.1, 0, 0), Vector3.new(0.6, depth, width), colors)
	self:layered("Head", Vector3.new(0.29, -depth * drop, 0), Vector3.new(0.38, depth * 0.8, width * 0.9), colors)
	self:layered("Rear", Vector3.new(-0.13, 0, 0), Vector3.new(0.42, depth * 0.72, width * 0.78), colors)
	self:layered("TailStalk", Vector3.new(-0.29, 0, 0), Vector3.new(0.2, depth * 0.3, width * 0.42), colors)
end

-- A smooth skin lofted through `stations` ({ x, top, bottom, half width },
-- snout first) instead of overlapping spheres. EditableMesh never replicates,
-- so the sphere body is still built: servers and the wiki see it, and
-- FishMeshes hides it on each client once the skin exists. Its Chest layers
-- are the skin's colour swatches, so mutations that repaint parts repaint the
-- skin too. Markings, eyes and fins follow the skin's surface.
function Builder:loftBody(stations: { { number } }, colors, depth: number, width: number, headDrop: number?)
	local existing = {}
	for _, item in self.model:GetChildren() do
		existing[item] = true
	end
	self:fishBody(depth, width, colors, headDrop)
	local swatches = { Chest = "Side", ChestBack = "Back", ChestBelly = "Belly" }
	local anchor: BasePart? = nil
	for _, item in self.model:GetChildren() do
		if not existing[item] then
			item:SetAttribute("LoftFallback", true)
			if swatches[item.Name] then
				item:SetAttribute("LoftSwatch", swatches[item.Name])
			end
			if item.Name == "Chest" then
				anchor = item :: BasePart
			end
		end
	end
	local rings: { Ring } = {}
	local count = #stations
	for index = 1, count - 1 do
		local p0, p1 = stations[math.max(index - 1, 1)], stations[index]
		local p2, p3 = stations[index + 1], stations[math.min(index + 2, count)]
		for step = 0, LOFT_STEPS - 1 do
			local t = step / LOFT_STEPS
			local function at(key: number): number
				return catmull(p0[key], p1[key], p2[key], p3[key], t)
			end
			local top, bottom = at(2), at(3)
			table.insert(rings, { x = at(1), top = math.max(top, bottom), bottom = bottom, width = math.max(at(4), 0) })
		end
	end
	local last = stations[count]
	table.insert(rings, { x = last[1], top = last[2], bottom = last[3], width = last[4] })
	self.loft = rings
	if anchor then
		lofts[self.model.Name] = { rings = rings, anchorPosition = anchor.Position, anchorSize = anchor.Size }
		self.model:SetAttribute("LoftFish", self.model.Name)
		self.model:AddTag(FishModels.LOFT_TAG)
	end
end

function Builder:face(eyeX: number, eyeY: number, eyeSize: number, iris: Color3, line: Color3)
	self:eye(eyeX, eyeY, eyeSize, iris)
	local mouthY = self:bottom(0.46) * 0.35
	self:stroke({ v2(0.47, mouthY + 0.004), v2(0.41, mouthY - 0.012) }, 0.008, rgb(40, 32, 30))
	self:marks(0.455, eyeY + eyeSize * 0.4, 0.008, 0.008, rgb(30, 28, 26))
	local top, bottom = self:top(0.24) * 0.7, self:bottom(0.24) * 0.75
	self:stroke({ v2(0.255, top), v2(0.232, top * 0.35), v2(0.232, bottom * 0.35), v2(0.255, bottom) }, 0.007, line)
end

function Builder:forkTail(spread: number, notch: number, color: Color3, transparency: number?)
	local stalk = self:top(-0.36)
	local a, b = v2(-0.35, stalk * 0.85), v2(-0.5, spread)
	local c, d, e = v2(-0.5 + notch, 0), v2(-0.5, -spread), v2(-0.35, -stalk * 0.85)
	self:fin({ a, b, c }, color, transparency)
	self:fin({ a, c, e }, color, transparency)
	self:fin({ c, d, e }, color, transparency)
	self:rays(
		v2(-0.36, 0),
		{ v2(-0.49, spread * 0.92), v2(-0.47, spread * 0.45), v2(-0.47, -spread * 0.45), v2(-0.49, -spread * 0.92) },
		color:Lerp(rgb(0, 0, 0), 0.25)
	)
end

function Builder:roundTail(radius: number, color: Color3, transparency: number?)
	local stalk = self:top(-0.36)
	local points = { v2(-0.35, 0), v2(-0.35, stalk * 0.9) }
	for index = 0, 6 do
		local angle = math.rad(110 + index * 140 / 6)
		table.insert(points, v2(-0.38 + math.cos(angle) * radius, math.sin(angle) * radius * 1.1))
	end
	table.insert(points, v2(-0.35, -stalk * 0.9))
	self:fin(points, color, transparency)
	local tips = {}
	for index = 1, 5 do
		local angle = math.rad(120 + index * 120 / 6)
		table.insert(tips, v2(-0.38 + math.cos(angle) * radius * 0.92, math.sin(angle) * radius))
	end
	self:rays(v2(-0.35, 0), tips, color:Lerp(rgb(0, 0, 0), 0.25))
end

-- A fin whose base hugs the back (or belly) between two X positions.
function Builder:edgeFin(
	fromX: number,
	toX: number,
	heights: { number },
	color: Color3,
	below: boolean?,
	transparency: number?
)
	local sign = if below then -1 else 1
	local function edge(x: number): number
		return (if below then self:bottom(x) else self:top(x)) - sign * 0.008
	end
	local points = { v2(fromX, edge(fromX)) }
	for index, height in heights do
		local x = fromX + (toX - fromX) * (index / (#heights + 1))
		table.insert(points, v2(x, edge(x) + sign * height))
	end
	table.insert(points, v2(toX, edge(toX)))
	-- Fan from the base midpoint so spiny, uneven edges still triangulate.
	local middle = (fromX + toX) / 2
	local base = v2(middle, edge(middle) - sign * 0.004)
	table.insert(points, 1, base)
	self:fin(points, color, transparency)
	return points
end

-- Solid crescent (lunate) tail of fast pelagic fish: two sickle lobes with a
-- convex leading edge and a concave trailing edge meeting at the tail stalk.
function Builder:lunateTail(span: number, color: Color3, transparency: number?, lower: number?)
	local stalk = self:top(-0.36)
	local function bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: number): Vector2
		return p0 * (1 - t) ^ 2 + p1 * 2 * t * (1 - t) + p2 * t * t
	end
	for _, sign in { 1, -1 } do
		local reach = span * (if sign < 0 then lower or 1 else 1)
		local tip = v2(-0.5, sign * reach)
		local lead0, lead1 = v2(-0.345, sign * stalk * 0.85), v2(-0.385, sign * reach * 0.72)
		local trail0, trail1 = v2(-0.39, 0), v2(-0.415, sign * reach * 0.48)
		local previousLead, previousTrail = lead0, trail0
		for step = 1, 4 do
			local t = step / 4
			local lead, trail = bezier(lead0, lead1, tip, t), bezier(trail0, trail1, tip, t)
			self:fin({ previousLead, lead, trail, previousTrail }, color, transparency)
			previousLead, previousTrail = lead, trail
		end
	end
	self:fin({ v2(-0.345, stalk * 0.85), v2(-0.39, 0), v2(-0.345, -stalk * 0.85) }, color, transparency)
end

-- Species builders live with their data in Shared.Fish (see Shared.FishSpecies);
-- below are the body-family helpers several of them share, handed over as `kit`.
local builders = {}

-- Carp cross-sections for the smooth skin: { x, top, bottom, half width }.
local CARP_STATIONS = {
	{ 0.505, -0.018, -0.048, 0.012 },
	{ 0.495, 0.018, -0.072, 0.03 },
	{ 0.465, 0.05, -0.095, 0.047 },
	{ 0.41, 0.08, -0.115, 0.06 },
	{ 0.33, 0.11, -0.13, 0.07 },
	{ 0.22, 0.14, -0.142, 0.079 },
	{ 0.1, 0.152, -0.142, 0.081 },
	{ -0.02, 0.142, -0.13, 0.076 },
	{ -0.13, 0.112, -0.105, 0.063 },
	{ -0.22, 0.08, -0.076, 0.047 },
	{ -0.29, 0.052, -0.05, 0.03 },
	{ -0.34, 0.04, -0.039, 0.019 },
	{ -0.375, 0.036, -0.035, 0.012 },
}

-- Deep-bodied carp with scale rows, barbels and fleshy lips; `p` is the palette.
-- `p.mesh` swaps the sphere body for a smooth skin (`p.stations` or the
-- default carp profile).
local function carp(b, p)
	local colors, fin = p.colors, p.fin
	if p.mesh then
		b:loftBody(p.stations or CARP_STATIONS, colors, 0.29, 0.16, 0.08)
	else
		b:fishBody(0.29, 0.16, colors, 0.08)
	end
	b:edgeFin(0.11, -0.22, { 0.095, 0.07, 0.05, 0.045, 0.04, 0.035 }, fin, false, 0.05)
	b:edgeFin(-0.12, -0.22, { 0.07, 0.05 }, fin, true)
	b:edgeFin(0.02, -0.06, { 0.06, 0.05 }, fin, true)
	b:forkTail(0.15, 0.05, fin)
	b:pectoral(0.2, -0.08, 0.1, 0.04, fin)
	-- On the smooth skin scales overlap like shingles; spaced ones read as spots.
	local rowStep, columnStep = if p.mesh then 0.03 else 0.04, if p.mesh then 0.032 else 0.045
	local scaleWidth, scaleHeight = if p.mesh then 0.04 else 0.036, if p.mesh then 0.034 else 0.03
	local row = 0
	for y = -0.1, if p.mesh then 0.14 else 0.105, rowStep do
		row += 1
		for x = 0.2 - (row % 2) * columnStep / 2, -0.32, -columnStep do
			local color = if (row + math.floor(x * 40)) % 3 == 0 then p.scale else p.scaleAlt
			if p.mesh then
				-- Scales darken into the back instead of stopping at an edge.
				color = color:Lerp(colors.back, math.clamp((y - 0.03) / 0.09, 0, 0.8))
			end
			b:marks(x, y, scaleWidth, scaleHeight, color)
		end
	end
	for _, side in { 1, -1 } do
		b:limb(
			Vector3.new(0.47, -0.045, side * 0.02),
			Vector3.new(0.45, -0.1, side * 0.035),
			0.008,
			p.barbel,
			"Barbel"
		)
		b:limb(
			Vector3.new(0.485, -0.03, side * 0.015),
			Vector3.new(0.52, -0.06, side * 0.03),
			0.006,
			p.barbel,
			"Barbel"
		)
	end
	b:ellipsoid("Lips", CFrame.new(if p.mesh then 0.5 else 0.48, -0.035, 0), Vector3.new(0.04, 0.035, 0.055), p.lips)
	b:face(0.37, 0.01, 0.036, p.iris, p.line)
end

-- Smooth eel tube along a gently waving spine with continuous dorsal and anal
-- fin ribbons meeting at the pointed tail; `p` is the palette.
local function eel(b, p)
	local back, side, belly = p.back, p.side, p.belly
	local count = 18
	local spine = {}
	for index = 0, count do
		local t = index / count
		table.insert(spine, Vector3.new(0.5 - t, 0.035 * math.sin(t * math.pi * 2.2), 0))
	end
	local function radius(t: number): number
		return 0.058 - 0.04 * t ^ 1.25
	end
	local finTop, finBottom = {}, {}
	for index = 1, count do
		local a, c = spine[index], spine[index + 1]
		local t = (index - 0.5) / count
		local direction = (c - a).Unit
		local up = (Vector3.yAxis - direction * direction.Y).Unit
		local middle = (a + c) / 2
		local frame = CFrame.fromMatrix(middle, direction, up)
		-- Long overlap keeps the waists between sections shallow, so the body
		-- reads as one smooth tube instead of a chain of beads.
		local length, h = (c - a).Magnitude * (if index <= 2 then 2 else 3.4), radius(t)
		b:ellipsoid("Body", frame, Vector3.new(length, h * 2, h * 1.7), side)
		b:ellipsoid("BodyBack", frame + up * h * 0.14, Vector3.new(length * 0.98, h * 1.7, h * 1.72), back)
		b:ellipsoid("BodyBelly", frame - up * h * 0.16, Vector3.new(length * 0.97, h * 1.6, h * 1.71), belly)
		if t > (p.dorsalFrom or 0.22) then
			table.insert(finTop, { middle + up * h * 0.75, middle + up * (h + 0.03 * (1 - t * 0.4)) })
		end
		if t > 0.42 then
			table.insert(finBottom, { middle - up * h * 0.75, middle - up * (h + 0.026 * (1 - t * 0.4)) })
		end
	end
	local finColor = p.fin
	for _, ribbon in { finTop, finBottom } do
		for index = 1, #ribbon - 1 do
			local a, c = ribbon[index], ribbon[index + 1]
			b:fin({ a[1], a[2], c[2], c[1] }, finColor, 0.15)
		end
		local last = ribbon[#ribbon]
		b:fin({ last[1], last[2], spine[#spine] - Vector3.new(0.02, 0, 0) }, finColor, 0.15)
	end
	local headY = spine[1].Y
	-- Head no wider than the body, tapering to a pointed snout.
	b:body("Head", Vector3.new(0.43, headY, 0), Vector3.new(0.17, 0.1, 0.088), side)
	b:body("HeadBack", Vector3.new(0.43, headY + 0.012, 0), Vector3.new(0.165, 0.085, 0.09), back)
	b:body("Snout", Vector3.new(0.5, headY - 0.004, 0), Vector3.new(0.08, 0.05, 0.052), back)
	b:eye(0.475, headY + 0.016, p.eyeSize or 0.026, p.iris)
	b:stroke({ v2(0.51, headY - 0.008), v2(0.455, headY - 0.022) }, 0.007, rgb(30, 30, 30))
	b:marks(0.385, headY - 0.005, 0.012, 0.03, back:Lerp(rgb(0, 0, 0), 0.35))
	b:pectoral(0.38, headY - 0.01, 0.05, 0.03, finColor, 0.1)
end

-- Flatfish lying on its blind side with both eyes up; `p` is the palette and
-- p.ocelli (optional) are the eye-spot positions.
local function flatfish(b, p)
	local brown, under = p.top, p.under
	b:body("Disc", Vector3.new(0.02, 0, 0), Vector3.new(0.74, 0.46, 0.06), brown)
	b:ellipsoid("Underside", CFrame.new(0.02, 0, -0.008), Vector3.new(0.735, 0.455, 0.056), under)
	b:body("HeadBump", Vector3.new(0.33, 0.03, 0), Vector3.new(0.17, 0.18, 0.05), brown)
	b:ellipsoid("TailStalk", CFrame.new(-0.34, 0, 0), Vector3.new(0.09, 0.1, 0.04), brown)
	local finColor, rayColor = p.fin, p.ray
	local function edge(x: number, sign: number): number
		local dx = (x - 0.02) / 0.37
		return sign * 0.23 * math.sqrt(math.max(0, 1 - dx * dx))
	end
	for _, spec in { { 0.33, -0.3, 1, 0.07 }, { 0.17, -0.3, -1, 0.06 } } do
		local from, to, sign, height = spec[1], spec[2], spec[3], spec[4]
		local previousInner, previousOuter
		for index = 0, 12 do
			local x = from + (to - from) * index / 12
			local reach = height * math.sin(math.pi * (0.15 + 0.85 * index / 12)) + 0.012
			local inner = Vector3.new(x, edge(x, sign) * 0.9, 0)
			local outer = Vector3.new(x, edge(x, sign) + sign * reach, 0)
			if previousInner then
				b:fin({ previousInner, previousOuter, outer, inner }, finColor, 0.08)
			end
			if index % 2 == 1 then
				b:limb(inner, outer, 0.005, rayColor, "FinRay")
			end
			previousInner, previousOuter = inner, outer
		end
	end
	b:roundTail(0.14, finColor, 0.08)
	for _ = 1, 44 do
		local x, y = b.random(-0.3, 0.34), b.random(-0.2, 0.2)
		local size = b.random(0.02, 0.05)
		b:mark(
			x,
			y,
			1,
			size,
			size * b.random(0.7, 1),
			if b.random(0, 1) > 0.5 then p.light else p.dark
		)
	end
	for _, spot in p.ocelli or {} do
		b:mark(spot.X, spot.Y, 1, 0.065, 0.065, p.ring)
		b:mark(spot.X, spot.Y, 1, 0.042, 0.042, p.center, nil, 0.001)
	end
	for _, eye in { v2(0.35, 0.06), v2(0.3, 0.125) } do
		local position, normal = b:surface(eye.X, eye.Y, 1)
		if position and normal then
			local center = position + normal * 0.01
			b:ellipsoid("EyeBulge", CFrame.new(center), Vector3.new(0.045, 0.04, 0.035), brown)
			b:ellipsoid("Eye", CFrame.new(center + normal * 0.012), Vector3.new(0.032, 0.03, 0.02), p.iris)
			b:ellipsoid("Pupil", CFrame.new(center + normal * 0.018), Vector3.new(0.02, 0.012, 0.014), rgb(14, 14, 14))
		end
	end
	b:mark(0.41, -0.03, 1, 0.07, 0.012, p.mouth, v2(-1, -1.2))
	b.model:SetAttribute("ViewDirection", Vector3.new(0.15, 0.3, 1))
end

-- Sturgeons share a bony-plated body, a shark-like upper tail lobe and barbels
-- under a pointed snout; `p` is the palette and p.snout the snout size.
local function sturgeon(b, p)
	local colors, fin, scute = p.colors, p.fin, p.scute
	b:fishBody(0.16, 0.14, colors, 0.04)
	b:layered("Snout", p.snoutAt or Vector3.new(0.46, -0.018, 0), p.snout, colors)
	b:edgeFin(-0.16, -0.26, { 0.05, 0.06, 0.04 }, fin)
	b:edgeFin(-0.14, -0.24, { 0.04, 0.05, 0.03 }, fin, true)
	b:edgeFin(0.02, -0.05, { 0.035 }, fin, true)
	b:pectoral(0.24, -0.05, 0.1, 0.03, fin)
	local stalk = b:top(-0.36)
	local upper, lower = v2(-0.34, stalk * 0.9), v2(-0.34, -stalk * 0.9)
	b:fin({ upper, v2(-0.58, 0.16), v2(-0.55, 0.12), v2(-0.42, 0), lower }, fin)
	b:fin({ lower, v2(-0.44, 0), v2(-0.5, -0.09) }, fin)
	if p.filament then
		b:limb(Vector3.new(-0.56, 0.15, 0), Vector3.new(-0.74, 0.2, 0), 0.006, fin, "Filament")
	end
	for x = 0.21, -0.3, -0.05 do
		b:ellipsoid("GrowthRidge", CFrame.new(x, b:top(x) + 0.002, 0), Vector3.new(0.03, 0.014, 0.02), scute)
		b:marks(x, b:top(x) * 0.45, 0.026, 0.02, scute)
		b:marks(x, b:bottom(x) * 0.4, 0.022, 0.016, scute)
	end
	if p.stripe then
		b:stroke({ v2(0.3, 0.012), v2(0, 0.01), v2(-0.32, 0) }, 0.008, p.stripe)
	end
	local barbelX = p.barbelX or 0.46
	local chin = b:bottom(barbelX)
	for _, z in { -0.022, -0.008, 0.008, 0.022 } do
		b:limb(
			Vector3.new(barbelX, chin + 0.004, z),
			Vector3.new(barbelX - 0.012, chin - 0.05, z * 1.3),
			0.008,
			scute,
			"Barbel"
		)
	end
	b:eye(0.36, 0.02, 0.026, p.iris)
end

-- Trout-family body: adipose fin, spotted flank and an optional coloured band.
local function trout(b, p)
	local fin = p.fin
	b:fishBody(0.21, 0.12, p.colors)
	b:edgeFin(0.07, -0.08, { 0.08, 0.075, 0.06, 0.04 }, fin)
	b:ellipsoid("AdiposeFin", CFrame.new(-0.25, b:top(-0.25) + 0.004, 0), Vector3.new(0.045, 0.028, 0.012), fin)
	b:edgeFin(-0.12, -0.23, { 0.06, 0.05, 0.035 }, fin, true)
	b:edgeFin(0.02, -0.07, { 0.05, 0.045 }, fin, true)
	b:forkTail(0.11, 0.035, fin)
	b:pectoral(0.2, -0.05, 0.1, 0.035, fin)
	if p.band then
		for x = 0.27, -0.31, -0.026 do
			b:marks(x, -0.002, 0.05, 0.05 * (1 - math.abs(x) * 0.9), p.band)
		end
		-- The band narrows onto the gill cover rather than ending in a disc.
		b:marks(0.29, -0.008, 0.085, 0.045, p.band)
	end
	if p.vermiculate then
		-- Tiger trout: worm-like squiggles instead of round spots.
		for _ = 1, 22 do
			local x, y = b.random(-0.3, 0.3), b.random(-0.06, 0.1)
			if y < b:top(x) - 0.02 and y > b:bottom(x) + 0.02 then
				local bend = b.random(-0.03, 0.03)
				b:stroke({ v2(x, y), v2(x - 0.03, y + bend), v2(x - 0.06, y - bend * 0.5) }, 0.012, p.spot)
			end
		end
	else
		b:speckle(p.spots, v2(-0.33, 0.33), v2(-0.06, 0.11), v2(0.01, 0.017), p.spot)
		for _ = 1, 12 do
			b:finSpot(b.random(-0.47, -0.37), b.random(-0.09, 0.09), 0.012, p.spot)
		end
	end
	b:face(0.37, 0.02, 0.045, p.iris, p.line)
end

local function mussel(b, shell, edge)
	-- A narrow hinge grows into a broad, rounded outer end. Overlapping lobes
	-- give the closed shell its asymmetric mussel outline and a raised crown.
	local dark = shell:Lerp(rgb(12, 15, 20), 0.55)
	b:ellipsoid("ShellSeam", CFrame.new(0.02, 0, 0), Vector3.new(0.94, 0.43, 0.09), dark)
	b:body("ShellHinge", Vector3.new(-0.29, -0.035, 0), Vector3.new(0.42, 0.20, 0.20), dark)
	b:body("Shell", Vector3.new(0.04, 0, 0), Vector3.new(0.82, 0.43, 0.30), shell)
	b:body("ShellCrown", Vector3.new(0.16, 0.015, 0), Vector3.new(0.58, 0.47, 0.32), shell)
	-- Fine curved growth lines follow the exposed surface on both valves.
	for ridge = 1, 5 do
		local x = -0.21 + ridge * 0.105
		for step = -3, 3 do
			local y = step * 0.047
			local curveX = x - 0.26 * (y / 0.2) ^ 2
			for _, side in { -1, 1 } do
				local mark = b:mark(curveX, y, side, 0.012, 0.052, edge:Lerp(shell, 0.45))
				if mark then mark.Name = "GrowthRidge" end
			end
		end
	end
	for _, side in { -1, 1 } do
		b:mark(0.13, 0.095, side, 0.30, 0.035, edge:Lerp(shell, 0.4), Vector2.new(1, -0.18))
	end
	b.model:SetAttribute("ViewDirection", Vector3.new(0.2, 0.4, 1))
end
-- One flexible algal sheet from `root` along `heading`. `profile(t)` gives the
-- half-width along the blade; `ruffle` alternates the margin for a wavy edge.
local function algaBlade(b, root: Vector3, heading: Vector3, length: number, profile, color: Color3, ruffle: number, phase: number)
	heading = heading.Unit
	local across = heading:Cross(Vector3.zAxis).Unit
	local segments = 7
	local previousLeft, previousRight
	for segment = 0, segments do
		local t = segment / segments
		local center = root
			+ heading * length * t
			+ across * math.sin(t * math.pi * 2 + phase) * 0.03 * t
			+ Vector3.zAxis * math.sin(t * math.pi * 2.5 + phase) * 0.05 * t
		local width = profile(t) * (1 + (if segment % 2 == 0 then ruffle else -ruffle))
		local offset = across * width + Vector3.zAxis * math.sin(t * math.pi + phase) * width * 0.4
		local left, right = center - offset, center + offset
		if previousLeft then
			for _, points in { { previousLeft, previousRight, right }, { previousLeft, right, left } } do
				local first, second = b:triangle(points[1], points[2], points[3], color)
				for _, part in { first, second } do
					if part then
						part.Name = "SeaweedFrond"
					end
				end
			end
		end
		previousLeft, previousRight = left, right
	end
end

-- Crabs face +X like the fish: eyes and claws at the front, legs splayed out to
-- both sides (Z). The carapace is a shell dome under a darker raised one; `look`
-- sets the colours, the claw and leg proportions and each species' extras.
local function crab(b, look)
	local shell, dark, belly = look.shell, look.dark, look.belly
	local clawColor, legColor = look.clawColor or shell, look.legColor or shell
	local tipColor = look.tipColor or rgb(36, 30, 26)
	local carapace = look.carapace
	local half = carapace / 2
	local domes = {
		{ Vector3.new(0, 0, 0), carapace, shell },
		{ Vector3.new(-0.01, carapace.Y * 0.2, 0), carapace * Vector3.new(0.84, 0.76, 0.84), dark },
	}
	b:body("Carapace", domes[1][1], domes[1][2], domes[1][3])
	b:body("CarapaceBack", domes[2][1], domes[2][2], domes[2][3])
	b:ellipsoid("Underside", CFrame.new(0, -carapace.Y * 0.22, 0), carapace * Vector3.new(0.94, 0.7, 0.94), belly)
	local function height(x: number, z: number): number?
		local best = nil
		for _, dome in domes do
			local h = dome[2] / 2
			local dx, dz = (x - dome[1].X) / h.X, (z - dome[1].Z) / h.Z
			local remaining = 1 - dx * dx - dz * dz
			if remaining > 0 then
				best = math.max(best or -math.huge, dome[1].Y + h.Y * math.sqrt(remaining))
			end
		end
		return best
	end
	-- `angle` 0 is straight ahead, +-pi/2 the widest point of the shell.
	local function rim(angle: number, reach: number): Vector3
		return Vector3.new(math.cos(angle) * half.X * reach, 0, math.sin(angle) * half.Z * reach)
	end

	-- Saw teeth along the front edge, and the blue crab's long lateral spines.
	for _, side in { 1, -1 } do
		for index = 1, look.teeth do
			local angle = side * (0.4 + (index - 1) * 1.0 / math.max(look.teeth - 1, 1))
			b:limb(rim(angle, 0.92), rim(angle, 1.1), 0.03, shell, "Spine")
		end
		if look.lateral then
			local base = rim(side * math.pi / 2 * 0.97, 0.9)
			b:limb(base, base + Vector3.new(-0.01, 0.01, side * (half.Z * 0.12 + look.lateral)), 0.034, shell, "Spine")
		end
		b:ellipsoid("FrontLobe", CFrame.new(rim(side * 0.14, 0.98)), Vector3.new(0.05, 0.035, 0.05), shell)
	end
	b:ellipsoid(
		"Mouth",
		CFrame.new(half.X * 0.86, -half.Y * 0.35, 0),
		Vector3.new(0.05, 0.05, half.Z * 0.45),
		belly:Lerp(dark, 0.35)
	)
	for _, side in { 1, -1 } do
		local root = Vector3.new(half.X * 0.82, half.Y * 0.4, side * half.Z * 0.24)
		local top = root + Vector3.new(0.05, 0.05, side * 0.015)
		b:limb(root, top, 0.024, shell, "EyeStalk")
		b:ellipsoid("Eye", CFrame.new(top), Vector3.one * 0.042, rgb(18, 16, 14))
		b:ellipsoid("EyeGlint", CFrame.new(top + Vector3.new(0.012, 0.014, 0)), Vector3.one * 0.012, rgb(255, 255, 255))
	end

	-- Claws: upper arm, forearm, a palm that turns in across the face and two
	-- slightly parted fingers with dark tips. `offhand` shrinks the left claw.
	for _, side in { 1, -1 } do
		local size = look.claw * (if side == -1 then look.offhand or 1 else 1)
		local inward = Vector3.new(0, 0, -side)
		local shoulder = Vector3.new(half.X * 0.5, -half.Y * 0.3, side * half.Z * 0.62)
		local elbow = shoulder + Vector3.new(0.12, 0.02, side * 0.13) * size
		local wrist = elbow + Vector3.new(0.11, 0.025, -side * 0.035) * size
		b:limb(shoulder, elbow, 0.055 * size, clawColor, "Arm")
		b:limb(elbow, wrist, 0.06 * size, clawColor, "Arm")
		b:ellipsoid("Wrist", CFrame.new(wrist), Vector3.one * 0.07 * size, clawColor)
		local direction = Vector3.new(1, 0.08, -side * 0.55).Unit
		local palmEnd = wrist + direction * 0.15 * size
		b:ellipsoid(
			"Palm",
			CFrame.lookAt((wrist + palmEnd) / 2, palmEnd) * CFrame.Angles(0, math.pi / 2, 0),
			Vector3.new(0.18 * size, 0.1 * size, 0.08 * size),
			clawColor
		)
		for _, finger in { { -0.016, -0.006, 0.008 }, { 0.022, 0.02, -0.016 } } do
			local root = palmEnd + Vector3.new(0, finger[1], 0) * size
			local middle = root + (direction * 0.06 + Vector3.new(0, finger[2], 0)) * size
			local tip = middle + (direction * 0.045 + inward * 0.02 + Vector3.new(0, finger[3], 0)) * size
			b:limb(root, middle, 0.034 * size, clawColor, "Finger")
			b:limb(middle, tip, 0.022 * size, tipColor, "FingerTip")
		end
		if look.armSpines then
			for _, t in { 0.3, 0.7 } do
				b:ellipsoid(
					"Spine",
					CFrame.new(shoulder:Lerp(elbow, t) + Vector3.new(0, 0.03 * size, 0)),
					Vector3.new(0.016, 0.034, 0.016),
					look.spineColor or shell
				)
			end
		end
	end

	-- Walking legs, front pairs leaning forward and back pairs back. A leg is
	-- thigh, shin and a pointed dactyl, knees raised above the shell rim.
	local legs = look.legs
	for _, side in { 1, -1 } do
		for index, lean in legs.lean do
			local x = half.X * (0.32 - (index - 1) * 0.3)
			local root = Vector3.new(x, -half.Y * 0.35, side * half.Z * math.sqrt(1 - (x / half.X) ^ 2) * 0.85)
			local out = Vector3.new(lean, 0, side).Unit
			local knee = root + out * legs.thigh + Vector3.new(0, legs.lift, 0)
			local foot = knee + out * legs.shin + Vector3.new(0, -legs.drop, 0)
			local ankle = knee:Lerp(foot, 0.65)
			b:limb(root, knee, legs.width, legColor, "Leg")
			b:limb(knee, ankle, legs.width * 0.8, legColor, "Leg")
			b:limb(ankle, foot, legs.width * 0.55, if legs.paddle then legColor else tipColor, "Leg")
			if legs.paddle and index == #legs.lean then
				b:ellipsoid(
					"Paddle",
					CFrame.lookAt((ankle + foot) / 2, foot) * CFrame.Angles(0, math.pi / 2, 0),
					Vector3.new(0.1, 0.014, 0.065),
					legColor
				)
			end
			if look.armSpines then
				for _, t in { 0.35, 0.75 } do
					b:ellipsoid(
						"Spine",
						CFrame.new(root:Lerp(knee, t) + Vector3.new(0, legs.width * 0.5, 0)),
						Vector3.new(0.014, 0.03, 0.014),
						look.spineColor or shell
					)
				end
			end
		end
	end

	-- Mottling, or the king crab's spiny shell, scattered over the top dome.
	for _, scatter in { look.spots or false, look.knobs or false } do
		for _ = 1, if scatter then scatter.count else 0 do
			local x, z = b.random(-half.X, half.X), b.random(-half.Z, half.Z)
			local y = height(x, z)
			if not y or (x / half.X) ^ 2 + (z / half.Z) ^ 2 > 0.8 then
				continue
			end
			local size = b.random(scatter.size.X, scatter.size.Y)
			if scatter == look.knobs then
				b:ellipsoid("Spine", CFrame.new(x, y + size * 0.3, z), Vector3.new(size, size * 2, size), scatter.color)
			else
				b:ellipsoid("Marking", CFrame.new(x, y + 0.002, z), Vector3.new(size, 0.004, size * 0.8), scatter.color)
			end
		end
	end
	b.model:SetAttribute("ViewDirection", Vector3.new(0.9, 0.85, 0.35))
end

local kit = {
	rgb = rgb,
	v2 = v2,
	SCALE = SCALE,
	FIN = FIN,
	carp = carp,
	eel = eel,
	flatfish = flatfish,
	sturgeon = sturgeon,
	trout = trout,
	mussel = mussel,
	algaBlade = algaBlade,
	crab = crab,
}
for id, fish in FishSpecies do
	local build = fish.Build
	if build then
		builders[id] = function(b)
			build(b, kit)
		end
	end
end

-- World-axis bounds, so framing never depends on which part came first.
local function measure(model: Model)
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			local frame, half = item.CFrame, item.Size / 2
			local extent = Vector3.new(
				math.abs(frame.RightVector.X) * half.X
					+ math.abs(frame.UpVector.X) * half.Y
					+ math.abs(frame.LookVector.X) * half.Z,
				math.abs(frame.RightVector.Y) * half.X
					+ math.abs(frame.UpVector.Y) * half.Y
					+ math.abs(frame.LookVector.Y) * half.Z,
				math.abs(frame.RightVector.Z) * half.X
					+ math.abs(frame.UpVector.Z) * half.Y
					+ math.abs(frame.LookVector.Z) * half.Z
			)
			low, high = low:Min(frame.Position - extent), high:Max(frame.Position + extent)
		end
	end
	model:SetAttribute("BoundsCenter", (low + high) / 2)
	model:SetAttribute("BoundsSize", high - low)
end

-- Parts a Neon (or Astral) mutation lights up. Eyes and corrupted wounds are
-- never repainted.
local GLOWING = {
	Fin = true,
	FinRay = true,
	FinSpot = true,
	AdiposeFin = true,
	PelvicFin = true,
	Tail = true,
	Filament = true,
	Spine = true,
	Barbel = true,
	Marking = true,
	GrowthRidge = true,
	SeaweedFrond = true,
	Midrib = true,
}
local UNPAINTED = { Eye = true, Pupil = true, EyeGlint = true, Bone = true, BoneKnob = true, Wound = true }
local ASTRAL_GLOW = rgb(170, 70, 255)
-- The client cycles the hue of every part carrying a RainbowHue attribute.
FishModels.RAINBOW_TAG = "RainbowFish"
FishModels.VOID_TAG = "VoidTouchedFish"
FishModels.GLITCH_TAG = "GlitchFish"

-- A builder over an already built, unscaled fish, so corruptions can reuse the
-- surface helpers. Body sections are the axis-aligned ellipsoids.
local function rebuild(model: Model, seed: number)
	local builder = setmetatable({ model = model, sections = {} :: { Ellipsoid }, random = seeded(seed) }, Builder)
	for _, item in model:GetChildren() do
		local mesh = if item:IsA("Part") then item:FindFirstChildOfClass("SpecialMesh") else nil
		if
			mesh
			and mesh.MeshType == Enum.MeshType.Sphere
			and item.CFrame.Rotation == CFrame.identity
			and math.min(item.Size.X, item.Size.Y, item.Size.Z) / SCALE > 0.015
			and not string.find(item.Name, "Fin")
			and not UNPAINTED[item.Name]
		then
			table.insert(builder.sections, { c = item.Position / SCALE, h = item.Size / SCALE / 2 })
		end
	end
	return builder
end

-- The fish's lowest corner and size in fish lengths.
local function bounds(model: Model): (Vector3, Vector3)
	local center, size = model:GetAttribute("BoundsCenter") :: Vector3, model:GetAttribute("BoundsSize") :: Vector3
	return (center - size / 2) / SCALE, size / SCALE
end

local corruptions = {}

-- The tail end, cloned and swung up into a second tail.
function corruptions.Tail(b)
	local low, size = bounds(b.model)
	local hinge = (low.X + size.X * 0.2) * SCALE
	local turn = CFrame.new(hinge, 0, 0) * CFrame.Angles(0, 0, math.rad(-32)) * CFrame.new(-hinge, 0, 0)
	for _, item in b.model:GetChildren() do
		if item:IsA("BasePart") and item.Position.X < hinge and not UNPAINTED[item.Name] then
			local copy = item:Clone()
			copy.CFrame = turn * item.CFrame
			copy.Parent = b.model
		end
	end
end

-- A second, larger eye just behind the first on both flanks.
function corruptions.Eye(b)
	for _, item in b.model:GetChildren() do
		if item.Name == "Eye" and item:IsA("BasePart") and item.Position.Z > 0 then
			local size = item.Size.X / SCALE
			local position = item.Position / SCALE
			b:eye(position.X - size * 1.6, position.Y + size * 0.4, size * 1.15, item.Color)
			return
		end
	end
end

-- An extra pair of fins halfway down the flanks.
function corruptions.Fin(b)
	local low, size = bounds(b.model)
	local color = rgb(150, 142, 108)
	for _, item in b.model:GetChildren() do
		if item.Name == "Fin" and item:IsA("BasePart") then
			color = item.Color
			break
		end
	end
	local x = low.X + size.X * 0.42
	b:pectoral(x, b:top(x) * 0.35, size.X * 0.14, size.Y * 0.18, color)
end

-- A broken bone through a raw wound on the near flank.
function corruptions.Bone(b)
	local low, size = bounds(b.model)
	local x = low.X + size.X * 0.55
	local position, normal = b:surface(x, b:top(x) * 0.25, 1)
	if not position or not normal then
		return
	end
	local wound = b:mark(position.X, position.Y, 1, size.X * 0.07, size.X * 0.05, rgb(120, 26, 34))
	if wound then
		wound.Name = "Wound"
	end
	local tip = position + (normal + Vector3.new(-0.35, 0.3, 0)).Unit * size.X * 0.13
	local bone = rgb(236, 228, 206)
	b:limb(position - normal * 0.01, tip, size.X * 0.022, bone, "Bone")
	local across = normal:Cross(Vector3.zAxis)
	across = (if across.Magnitude > 0.01 then across.Unit else Vector3.yAxis) * size.X * 0.014
	for _, side in { 1, -1 } do
		b:ellipsoid("BoneKnob", CFrame.new(tip + across * side), Vector3.one * size.X * 0.034, bone)
	end
end

local function luminance(color: Color3): number
	return color.R * 0.3 + color.G * 0.59 + color.B * 0.11
end

local function rainbow(item: BasePart, hue: number, saturation: number, value: number)
	item:SetAttribute("RainbowHue", hue)
	item:SetAttribute("RainbowSaturation", saturation)
	item:SetAttribute("RainbowValue", value)
	item.Color = Color3.fromHSV(hue % 1, saturation, value)
end

-- The biggest body part, which carries a mutation's particles and lights.
local function bodyCore(model: Model): BasePart?
	local core: BasePart? = nil
	for _, item in model:GetChildren() do
		if item:IsA("Part") and not UNPAINTED[item.Name] and not GLOWING[item.Name] then
			if not core or item.Size.Magnitude > core.Size.Magnitude then
				core = item
			end
		end
	end
	return core
end

-- Drifting aurora motes and a faint violet glow from the biggest body part.
local function aurora(model: Model)
	local core = bodyCore(model)
	if not core then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "AstralAurora"
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rgb(70, 255, 180)),
		ColorSequenceKeypoint.new(0.5, rgb(80, 160, 255)),
		ColorSequenceKeypoint.new(1, rgb(190, 80, 255)),
	})
	emitter.LightEmission, emitter.LightInfluence = 1, 0
	emitter.Lifetime = NumberRange.new(1.4, 2.6)
	emitter.Rate = 9
	emitter.Speed = NumberRange.new(0.2, 0.6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, 0.5, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-30, 30)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.35, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = core
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range = ASTRAL_GLOW, 0.8, 6
	light.Parent = core
end

-- Supercell catches: a faint storm-sky sheen, slightly see-through fins, and
-- wind streaks and gusts racing from snout to tail. Body sections are axis
-- aligned, so the core part's -X (Left) face points down the fish to its tail.
local WINDY_SHEEN = rgb(196, 222, 236)
local function windswept(model: Model)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and not UNPAINTED[item.Name] then
			item.Color = item.Color:Lerp(WINDY_SHEEN, 0.16)
			if GLOWING[item.Name] and item.Material ~= Enum.Material.Neon then
				item.Transparency = math.max(item.Transparency, 0.12)
			end
		end
	end
	local core = bodyCore(model)
	if not core then
		return
	end
	local streaks = Instance.new("ParticleEmitter")
	streaks.Name = "WindyStreaks"
	streaks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	streaks.Orientation = Enum.ParticleOrientation.VelocityParallel
	streaks.Squash = NumberSequence.new(-4)
	streaks.EmissionDirection = Enum.NormalId.Left
	streaks.Shape = Enum.ParticleEmitterShape.Box
	streaks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	streaks.Color = ColorSequence.new(rgb(232, 244, 250))
	streaks.LightEmission, streaks.LightInfluence = 0.3, 0.4
	streaks.Lifetime = NumberRange.new(0.35, 0.6)
	streaks.Rate = 14
	streaks.Speed = NumberRange.new(5, 8)
	streaks.SpreadAngle = Vector2.new(8, 8)
	streaks.Size = NumberSequence.new(0.05)
	streaks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	streaks.LockedToPart = true
	streaks.Parent = core
	local gusts = Instance.new("ParticleEmitter")
	gusts.Name = "WindyGusts"
	gusts.Texture = "rbxasset://textures/particles/smoke_main.dds"
	gusts.EmissionDirection = Enum.NormalId.Left
	gusts.Color = ColorSequence.new(rgb(225, 238, 245))
	gusts.LightEmission, gusts.LightInfluence = 0.1, 0.8
	gusts.Lifetime = NumberRange.new(0.8, 1.2)
	gusts.Rate = 3
	gusts.Speed = NumberRange.new(2, 3.5)
	gusts.SpreadAngle = Vector2.new(25, 25)
	gusts.Rotation = NumberRange.new(0, 360)
	gusts.RotSpeed = NumberRange.new(-220, 220)
	gusts.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 0.9),
	})
	gusts.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.82),
		NumberSequenceKeypoint.new(1, 1),
	})
	gusts.LockedToPart = true
	gusts.Parent = core
end

-- A rippling lens around a completely black fish. Attachments follow its body
-- through tools, freezer models and scaling without adding physical fish parts.
local function voidAura(model: Model)
	local core: BasePart? = nil
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Color = Color3.new(0, 0, 0)
			item.Material = Enum.Material.SmoothPlastic
			item.Reflectance = 0
			item.Transparency = 0
			item:SetAttribute("RainbowHue", nil)
			if not core or item.Size.Magnitude > core.Size.Magnitude then
				core = item
			end
		end
	end
	if not core then
		return
	end
	local center = model:GetAttribute("BoundsCenter") :: Vector3
	local size = model:GetAttribute("BoundsSize") :: Vector3
	local radius = Vector3.new(size.X * 0.62, math.max(size.Y * 0.8, size.X * 0.18), size.Z * 0.6)
	local localCenter = core.CFrame:PointToObjectSpace(center)
	core:SetAttribute("VoidAuraCore", true)
	core:SetAttribute("VoidAuraOriginalSize", core.Size)
	core:SetAttribute("VoidAuraCenter", localCenter)
	core:SetAttribute("VoidAuraRadius", radius)
	local points = {}
	for index = 1, 18 do
		local angle = (index - 1) / 18 * math.pi * 2
		local point = Instance.new("Attachment")
		point.Name = "VoidLens" .. index
		point:SetAttribute("VoidLensAngle", angle)
		point.Position = localCenter + Vector3.new(math.cos(angle) * radius.X, math.sin(angle) * radius.Y, 0)
		point.Parent = core
		table.insert(points, point)
	end
	for index, point in points do
		local beam = Instance.new("Beam")
		beam.Name = "VoidDistortion"
		beam.Attachment0, beam.Attachment1 = point, points[index % #points + 1]
		beam.Width0, beam.Width1 = size.X * 0.018, size.X * 0.018
		beam.Color = ColorSequence.new(rgb(99, 39, 158))
		beam.Transparency = NumberSequence.new(0.18)
		beam.FaceCamera = true
		beam.LightEmission = 0.7
		beam.LightInfluence = 0
		beam.Segments = 1
		beam.Parent = core
	end
	model:AddTag(FishModels.VOID_TAG)
end

-- Add petals as fish geometry so they follow the fish through tools and displays.
local function flowers(model: Model)
 local core = bodyCore(model)
 if not core then return end
 local b = newBuilder("flowers", 23)
 b.model = model
 local center, size = core.Position / SCALE, core.Size / SCALE
 for _, side in { -1, 1 } do
  for _, x in { -0.2, 0.16 } do
   local origin = center + Vector3.new(size.X * x, size.Y * 0.15, side * size.Z * 0.49)
   local radius = math.max(0.018, size.X * 0.045)
   for petal = 1, 5 do
    local angle = petal * math.pi * 2 / 5
    b:ellipsoid("FlowerPetal", CFrame.new(origin + Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)), Vector3.new(radius, radius, radius * 0.45), rgb(255, 224, 241))
   end
   b:ellipsoid("FlowerCenter", CFrame.new(origin + Vector3.new(0, 0, side * radius * 0.3)), Vector3.one * radius * 0.7, rgb(255, 221, 55))
  end
 end
end

local function mutationParticles(model: Model, name: string, color: Color3, texture: string, rate: number)
 local core = bodyCore(model)
 if not core then return end
 local emitter = Instance.new("ParticleEmitter")
 emitter.Name = name
 emitter.Texture = texture
 emitter.Color = ColorSequence.new(color)
 emitter.LightEmission = 0.8
 emitter.Lifetime = NumberRange.new(0.6, 1.4)
 emitter.Speed = NumberRange.new(0.5, 2)
 emitter.SpreadAngle = Vector2.new(180, 180)
 emitter.Rotation = NumberRange.new(0, 360)
 emitter.RotSpeed = NumberRange.new(-90, 90)
 emitter.Rate = rate
 emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) })
 emitter.Parent = core
end

-- Paints a freshly created, unscaled fish with a record's mutations.
function FishModels.mutate(model: Model, traits)
	local set = FishMutations.parts(traits and traits.Mutation)
	if not next(set) then
		return
	end
	if set.Corrupted then
		local seed = 11
		for index = 1, #model.Name do
			seed = (seed * 31 + string.byte(model.Name, index)) % 2147483647
		end
		for _, kind in traits.Corruptions or { "Eye" } do
			if corruptions[kind] then
				-- Rebuilt each time so a corruption sees the parts the last one added.
				corruptions[kind](rebuild(model, seed))
			end
		end
	end
	if set.VoidTouched then
		-- Colour mutations still contribute to value, but the void consumes their
		-- appearance, including eyes, bones and every added corruption.
		measure(model)
		voidAura(model)
		return
	end
	local neon = traits.NeonColor and FishMutations.NeonColors[traits.NeonColor]
	local glow = if set.Astral then ASTRAL_GLOW elseif neon then rgb(neon[1], neon[2], neon[3]) else rgb(255, 255, 255)
	local lit = set.Neon or set.Astral
 local specialColor = if set.Ascended then rgb(255, 235, 35)
  elseif set.Floral then rgb(157, 233, 54) elseif set.Snowy then rgb(213, 240, 255)
  elseif set.JackOFish or set.JacksPet then rgb(255, 123, 20)
  elseif set.ZeusStruck then rgb(255, 244, 28) elseif set.Nightmare then rgb(12, 25, 70)
  elseif set.Obsidian then rgb(81, 35, 135) elseif set.Tryhard then rgb(80, 245, 255) else nil
	local low, size = bounds(model)
	for _, item in model:GetDescendants() do
		if not item:IsA("BasePart") or UNPAINTED[item.Name] then
			continue
		end
		-- Hue runs snout to tail.
		local hue = (1 - (item.Position.X / SCALE - low.X) / math.max(size.X, 0.01)) * 0.85
		local shade = luminance(item.Color)
		if specialColor then
   local accent = GLOWING[item.Name] or item.Name == "Marking"
   if set.Ascended then item.Color = if accent then specialColor else rgb(255, 255, 239)
   elseif set.Snowy then item.Color = if accent then specialColor else rgb(250, 253, 255)
   elseif set.Floral then item.Color = if accent then specialColor else item.Color:Lerp(specialColor, 0.4)
   elseif set.JackOFish or set.JacksPet then item.Color = if accent then rgb(20, 14, 18) else specialColor
   else item.Color = specialColor:Lerp(Color3.new(0, 0, 0), if accent then 0.45 else 0.15) end
   if set.Ascended or set.ZeusStruck or (set.JacksPet and accent) then item.Material = Enum.Material.Neon end
   if set.Obsidian then item.Material = Enum.Material.Glass item.Transparency = 0.25 item.Reflectance = 0.12 end
   if set.Tryhard then
    item:SetAttribute("GlitchBaseColor", item.Color)
    item:SetAttribute("GlitchBaseTransparency", item.Transparency)
   end
  elseif lit and GLOWING[item.Name] then
			item.Material = Enum.Material.Neon
			if set.Rainbow then
				rainbow(item, hue, 0.85, 1)
			else
				item.Color = glow
			end
		elseif set.Astral then
			item.Color = rgb(12, 12, 18):Lerp(rgb(66, 66, 76), shade)
		elseif set.Albino then
			item.Color = Color3.fromHSV(0, 0, 0.9 + 0.1 * shade)
		elseif set.Rainbow then
			rainbow(item, hue, 0.6, 0.72 + 0.28 * shade)
		end
		-- Keep corruption visible even when the rolled extra feature is small or
		-- hidden by the fish's body. Rainbow owns its animated part colours.
		if set.Corrupted and not set.Rainbow and item.Name ~= "Bone" and item.Name ~= "BoneKnob" and item.Name ~= "Wound" then
			item.Color = item.Color:Lerp(rgb(125, 35, 145), 0.55)
		end
	end
	if set.Rainbow then
		model:AddTag(FishModels.RAINBOW_TAG)
	end
	if set.Astral then
		aurora(model)
	end
	if set.Windy or set.Gusty then windswept(model) end
 if set.Corrupted then mutationParticles(model, "Corruption", rgb(185, 55, 210), "rbxasset://textures/particles/sparkles_main.dds", 16) end
 if set.Floral then flowers(model) end
 if set.Snowy then mutationParticles(model, "Snowflakes", rgb(221, 244, 255), "rbxasset://textures/particles/sparkles_main.dds", 12) end
 if set.ZeusStruck then mutationParticles(model, "Lightning", rgb(255, 245, 65), "rbxasset://textures/particles/sparkles_main.dds", 25) end
 if set.JacksPet then mutationParticles(model, "JackEmbers", rgb(255, 135, 20), "rbxasset://textures/particles/sparkles_main.dds", 14) end
 if set.Ascended then mutationParticles(model, "AscendedGlow", rgb(255, 245, 155), "rbxasset://textures/particles/sparkles_main.dds", 16) end
 if set.Tryhard then model:AddTag(FishModels.GLITCH_TAG) end
	measure(model)
end

function FishModels.has(fishId: string): boolean
	return builders[fishId] ~= nil
end

local function template(fishId: string): Model?
	local model = templates[fishId]
	if not model then
		local build = builders[fishId]
		if not build then
			return nil
		end
		local seed = 7
		for index = 1, #fishId do
			seed = (seed * 31 + string.byte(fishId, index)) % 2147483647
		end
		local builder = newBuilder(fishId, seed)
		build(builder)
		model = builder.model
		measure(model)
		if model:GetAttribute("ViewDirection") == nil then
			model:SetAttribute("ViewDirection", Vector3.new(0.18, 0.16, 1))
		end
		templates[fishId] = model
	end
	return model
end

-- `traits` is a catch record (or anything with its Mutation, NeonColor and
-- Corruptions) to paint the fish with.
function FishModels.create(fishId: string, traits: any?): Model?
	local base = template(fishId)
	if not base then
		return nil
	end
	local model = base:Clone()
	FishModels.mutate(model, traits)
	return model
end

-- A species' smooth skin: its rings (fish lengths) and where its Chest swatch
-- sat in the unscaled template (studs). Nil for sphere-bodied species.
function FishModels.loft(fishId: string)
	template(fishId)
	return lofts[fishId]
end

FishModels.loftPoint = loftPoint
FishModels.loftNormal = loftNormal

local crabSpecies = { ShoreCrab = true, BlueCrab = true, KingCrab = true }
-- Crabs cluster tightly in weight, so the cube-root curve used by fish hides
-- their differences. In hand they follow weight almost directly instead; the
-- larger base keeps an average Shore Crab the same size as before while heavier
-- crabs visibly outgrow lighter ones.
local CRAB_HELD_BASE, CRAB_HELD_EXPONENT = 2.4, 0.9

-- Compact display size for the freezer and customer hands.
function FishModels.catchLength(kg: number, fishId: string?): number
	-- Crab weights cluster tightly, so a stronger curve makes their differences
	-- visible while still keeping even a record crab within the freezer.
	local exponent = if fishId and crabSpecies[fishId] then 0.65 else 1 / 3
	local size = math.max(kg, 0.01) ^ exponent
	-- Smoothly compress record weights while retaining differences between
	-- catches. The longest side stays below the freezer's 3.54-stud ice depth.
	return 0.6 + 2.6 * size / (size + 0.75)
end

-- Held catches keep their weight differences without the freezer's size limit.
-- Huge gets a 6x trophy boost; weight keeps small species smaller than large ones.
function FishModels.heldLength(kg: number, size: string?, fishId: string?): number
	local boost = if size == "Huge" then 6 elseif size == "Big" then 1.5 else 1
	local weight = math.max(kg, 0.01)
	if fishId and crabSpecies[fishId] then
		return CRAB_HELD_BASE * weight ^ CRAB_HELD_EXPONENT * boost
	end
	return 1.6 * weight ^ (1 / 3) * boost
end

local function scaleToLength(model: Model, length: number): Vector3
	local bounds = model:GetAttribute("BoundsSize") :: Vector3
	local scale = length / math.max(bounds.X, bounds.Y, bounds.Z, 0.1)
	model:ScaleTo(scale)
	return bounds * scale
end

function FishModels.scaleCatch(model: Model, kg: number): Vector3
	return scaleToLength(model, FishModels.catchLength(kg, model.Name))
end

-- Cache unscaled geometry by species and mutations, not by catch weight.
local catchBounds = {}
function FishModels.catchBounds(record): Vector3?
	local corrupted = FishMutations.parts(record.Mutation).Corrupted
	local shapes = if corrupted then record.Corruptions or { "Eye" } else {}
	local key = record.FishId .. ":" .. (record.Mutation or "Normal") .. ":" .. table.concat(shapes, ",")
	local size = catchBounds[key]
	if not size then
		local model = FishModels.create(record.FishId, record)
		if not model then
			return nil
		end
		size = model:GetAttribute("BoundsSize")
		catchBounds[key] = size
		model:Destroy()
	end
	return size * (FishModels.catchLength(record.Kg, record.FishId) / math.max(size.X, size.Y, size.Z, 0.1))
end

function FishModels.scaleHeldCatch(model: Model, kg: number, size: string?): Vector3
	return scaleToLength(model, FishModels.heldLength(kg, size, model.Name))
end

function FishModels.silhouette(model: Model)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Color = Color3.new(1, 1, 1)
			item.Transparency = 0
			item.Reflectance = 0
		end
	end
end

-- Fills a ViewportFrame with the fish and frames it. Returns the model and the
-- camera so callers can animate either one. `traits` paints a caught fish's mutations.
function FishModels.show(viewport: ViewportFrame, fishId: string, silhouette: boolean?, traits: any?): (Model?, Camera?)
	for _, child in viewport:GetChildren() do
		if child:IsA("Model") or child:IsA("Camera") or child:IsA("WorldModel") then
			child:Destroy()
		end
	end
	local model = FishModels.create(fishId, if silhouette then nil else traits)
	if not model then
		return nil, nil
	end
	if silhouette then
		FishModels.silhouette(model)
		viewport.Ambient = Color3.new(1, 1, 1)
		viewport.LightColor = Color3.new(0, 0, 0)
	else
		viewport.Ambient = rgb(150, 150, 156)
		viewport.LightColor = rgb(255, 248, 236)
		viewport.LightDirection = Vector3.new(-0.35, -1, -0.55)
	end
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 26
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local center, size = model:GetAttribute("BoundsCenter") :: Vector3, model:GetAttribute("BoundsSize") :: Vector3
	local direction = (model:GetAttribute("ViewDirection") :: Vector3).Unit
	local distance = (size.Magnitude / 2) / math.sin(math.rad(camera.FieldOfView / 2)) * 0.82
	camera.CFrame = CFrame.lookAt(center + direction * distance, center)
	camera:SetAttribute("Focus", center)
	camera:SetAttribute("Distance", distance)
	return model, camera
end

return FishModels
