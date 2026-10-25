-- Detailed fish built entirely from local parts, so no mesh or image upload is
-- needed. Bodies are overlapping ellipsoids (darker back and paler belly layers
-- give countershading), fins are wedge-pair triangles and markings are thin
-- discs laid on the body surface. Builders work in "fish lengths" (snout at
-- X = +0.5, tail at -0.5, back towards +Y) and are scaled to studs on creation.
local FishModels = {}
local FishMutations = require(script.Parent.FishMutations)

local SCALE = 4 -- studs per fish length
local FIN = 0.004
local rgb = Color3.fromRGB
local templates: { [string]: Model } = {}

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

-- Outermost body surface at (x, y) on one side (+1 or -1), with its normal.
function Builder:surface(x: number, y: number, side: number): (Vector3?, Vector3?)
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
	self:part(
		"Fin",
		"WedgePart",
		Vector3.new(FIN, height, math.abs(ab:Dot(back))),
		CFrame.fromMatrix((a + b) / 2, right, up, back),
		color,
		transparency
	)
	self:part(
		"Fin",
		"WedgePart",
		Vector3.new(FIN, height, math.abs(ac:Dot(back))),
		CFrame.fromMatrix((a + c) / 2, -right, up, -back),
		color,
		transparency
	)
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

local builders = {}

function builders.Trout(b)
	local colors = { back = rgb(78, 90, 54), side = rgb(184, 188, 160), belly = rgb(240, 236, 224) }
	local fin = rgb(150, 142, 108)
	b:fishBody(0.21, 0.12, colors)
	b:edgeFin(0.07, -0.08, { 0.08, 0.075, 0.06, 0.04 }, fin)
	b:ellipsoid("AdiposeFin", CFrame.new(-0.25, b:top(-0.25) + 0.004, 0), Vector3.new(0.045, 0.028, 0.012), fin)
	b:edgeFin(-0.12, -0.23, { 0.06, 0.05, 0.035 }, fin, true)
	b:edgeFin(0.02, -0.07, { 0.05, 0.045 }, fin, true)
	b:forkTail(0.11, 0.045, fin)
	b:pectoral(0.2, -0.05, 0.1, 0.035, fin)
	for x = 0.26, -0.3, -0.028 do
		b:marks(x, -0.004, 0.055, 0.04 * (1 - math.abs(x) * 0.9), rgb(222, 128, 132))
	end
	b:marks(0.28, -0.02, 0.09, 0.08, rgb(216, 132, 128))
	b:speckle(46, v2(-0.33, 0.33), v2(-0.01, 0.11), v2(0.011, 0.018), rgb(32, 32, 26))
	for _ = 1, 9 do
		b:finSpot(b.random(-0.47, -0.37), b.random(-0.09, 0.09), 0.012, rgb(40, 40, 32))
	end
	for _ = 1, 4 do
		b:finSpot(b.random(-0.06, 0.04), b:top(0) + b.random(0.01, 0.05), 0.011, rgb(40, 40, 32))
	end
	b:face(0.37, 0.02, 0.045, rgb(204, 172, 96), rgb(120, 112, 96))
end

function builders.Carp(b)
	local colors = { back = rgb(86, 68, 36), side = rgb(192, 146, 64), belly = rgb(234, 208, 148) }
	local fin = rgb(176, 104, 60)
	b:fishBody(0.29, 0.16, colors, 0.08)
	b:edgeFin(0.11, -0.22, { 0.095, 0.07, 0.05, 0.045, 0.04, 0.035 }, fin, false, 0.05)
	b:edgeFin(-0.12, -0.22, { 0.07, 0.05 }, fin, true)
	b:edgeFin(0.02, -0.06, { 0.06, 0.05 }, fin, true)
	b:forkTail(0.15, 0.05, fin)
	b:pectoral(0.2, -0.08, 0.1, 0.04, fin)
	local row = 0
	for y = -0.1, 0.105, 0.04 do
		row += 1
		for x = 0.2 - (row % 2) * 0.022, -0.32, -0.045 do
			b:marks(
				x,
				y,
				0.036,
				0.03,
				if (row + math.floor(x * 40)) % 3 == 0 then rgb(164, 118, 48) else rgb(176, 130, 54)
			)
		end
	end
	for _, side in { 1, -1 } do
		b:limb(
			Vector3.new(0.47, -0.045, side * 0.02),
			Vector3.new(0.45, -0.1, side * 0.035),
			0.008,
			rgb(170, 120, 70),
			"Barbel"
		)
		b:limb(
			Vector3.new(0.485, -0.03, side * 0.015),
			Vector3.new(0.52, -0.06, side * 0.03),
			0.006,
			rgb(170, 120, 70),
			"Barbel"
		)
	end
	b:ellipsoid("Lips", CFrame.new(0.48, -0.035, 0), Vector3.new(0.04, 0.035, 0.055), rgb(198, 150, 92))
	b:face(0.37, 0.01, 0.036, rgb(214, 172, 64), rgb(130, 96, 44))
end

function builders.BlueMackerel(b)
	local colors = { back = rgb(32, 92, 118), side = rgb(158, 182, 192), belly = rgb(238, 240, 240) }
	local fin = rgb(72, 94, 104)
	b:fishBody(0.17, 0.11, colors, 0.03)
	local spines = b:edgeFin(0.11, -0.01, { 0.07, 0.065, 0.05, 0.035 }, fin, false, 0.1)
	b:rays(spines[1], { spines[4], spines[5], spines[6] }, rgb(40, 56, 64))
	b:edgeFin(-0.08, -0.14, { 0.04, 0.03 }, fin)
	b:edgeFin(-0.08, -0.14, { 0.04, 0.03 }, fin, true)
	for index = 0, 4 do
		local x = -0.17 - index * 0.028
		for _, below in { false, true } do
			local edge = if below then b:bottom(x) else b:top(x)
			local sign = if below then -1 else 1
			b:fin({
				v2(x + 0.008, edge - sign * 0.004),
				v2(x - 0.012, edge + sign * 0.02),
				v2(x - 0.014, edge - sign * 0.004),
			}, rgb(196, 184, 96))
		end
	end
	b:forkTail(0.13, 0.085, fin)
	b:pectoral(0.21, -0.02, 0.09, 0.03, fin)
	for x = 0.21, -0.3, -0.04 do
		local top = b:top(x)
		b:stroke({ v2(x, top * 0.88), v2(x - 0.022, top * 0.52), v2(x + 0.004, top * 0.18) }, 0.007, rgb(16, 36, 50))
	end
	for x = 0.16, -0.26, -0.05 do
		b:marks(x, -0.03 + math.sin(x * 40) * 0.006, 0.012, 0.012, rgb(112, 126, 136))
	end
	b:face(0.375, 0.015, 0.052, rgb(196, 204, 196), rgb(90, 108, 118))
end

function builders.Cod(b)
	local colors = { back = rgb(102, 94, 60), side = rgb(158, 148, 104), belly = rgb(232, 226, 202) }
	local fin = rgb(122, 112, 78)
	b:fishBody(0.22, 0.15, colors, 0.08)
	b:edgeFin(0.15, 0.04, { 0.05, 0.065, 0.05 }, fin)
	b:edgeFin(0.0, -0.12, { 0.045, 0.055, 0.045 }, fin)
	b:edgeFin(-0.16, -0.27, { 0.04, 0.045, 0.03 }, fin)
	b:edgeFin(-0.03, -0.14, { 0.04, 0.05, 0.04 }, fin, true)
	b:edgeFin(-0.17, -0.27, { 0.04, 0.04, 0.03 }, fin, true)
	b:forkTail(0.09, 0.012, fin)
	b:pectoral(0.21, -0.03, 0.09, 0.04, fin)
	b:speckle(60, v2(-0.33, 0.36), v2(-0.04, 0.12), v2(0.014, 0.03), rgb(92, 80, 50))
	b:stroke({ v2(0.26, 0.04), v2(0.12, 0.05), v2(-0.06, 0.03), v2(-0.32, 0.005) }, 0.009, rgb(226, 220, 196))
	b:limb(
		Vector3.new(0.43, b:bottom(0.43) + 0.005, 0),
		Vector3.new(0.41, b:bottom(0.43) - 0.05, 0),
		0.009,
		rgb(150, 136, 96),
		"Barbel"
	)
	b:face(0.36, 0.02, 0.042, rgb(190, 176, 120), rgb(110, 100, 70))
end

function builders.Bluegill(b)
	local colors = { back = rgb(58, 76, 58), side = rgb(112, 124, 86), belly = rgb(224, 150, 60) }
	local fin = rgb(82, 92, 70)
	b:fishBody(0.42, 0.13, colors, 0.1)
	local dorsal =
		b:edgeFin(0.13, -0.24, { 0.07, 0.05, 0.075, 0.05, 0.075, 0.055, 0.08, 0.1, 0.11, 0.09 }, fin, false, 0.08)
	b:rays(dorsal[1], { dorsal[4], dorsal[6], dorsal[8], dorsal[10] }, rgb(46, 52, 42))
	b:edgeFin(-0.05, -0.24, { 0.06, 0.08, 0.09, 0.07 }, fin, true, 0.08)
	b:edgeFin(0.08, -0.02, { 0.07, 0.06 }, fin, true)
	b:forkTail(0.15, 0.03, fin, 0.05)
	b:pectoral(0.2, -0.04, 0.15, 0.04, rgb(150, 140, 96), 0.15)
	for _, x in { 0.15, 0.07, -0.01, -0.09, -0.17, -0.24 } do
		b:stroke({ v2(x + 0.01, b:top(x) - 0.02), v2(x - 0.01, -0.06) }, 0.03, rgb(86, 98, 68))
	end
	b:stroke({ v2(0.43, -0.02), v2(0.33, -0.05) }, 0.012, rgb(88, 110, 156))
	b:stroke({ v2(0.43, -0.05), v2(0.34, -0.09) }, 0.012, rgb(88, 110, 156))
	b:marks(0.235, 0.035, 0.065, 0.055, rgb(18, 18, 22))
	b:face(0.38, 0.05, 0.05, rgb(46, 40, 36), rgb(70, 80, 56))
end

function builders.Angelfish(b)
	local colors = { back = rgb(196, 186, 146), side = rgb(216, 216, 206), belly = rgb(238, 238, 232) }
	local fin = rgb(206, 206, 196)
	b:fishBody(0.5, 0.07, colors, 0.12)
	b:fin({ v2(0.16, 0.2), v2(-0.02, 0.42), v2(-0.36, 0.66), v2(-0.26, 0.26), v2(-0.24, 0.1) }, fin, 0.2)
	b:fin({ v2(0.1, -0.2), v2(-0.04, -0.42), v2(-0.36, -0.66), v2(-0.26, -0.26), v2(-0.24, -0.1) }, fin, 0.2)
	b:roundTail(0.13, fin, 0.2)
	for _, side in { 1, -1 } do
		b:limb(
			Vector3.new(0.14, -0.2, side * 0.02),
			Vector3.new(0.0, -0.66, side * 0.03),
			0.008,
			rgb(226, 224, 214),
			"Filament"
		)
	end
	for _, tip in { v2(-0.6, 0.22), v2(-0.6, -0.22) } do
		b:limb(Vector3.new(-0.46, tip.Y * 0.5, 0), Vector3.new(tip.X, tip.Y, 0), 0.006, fin, "Filament")
	end
	local dark = rgb(26, 26, 30)
	b:stroke({ v2(0.33, b:top(0.33) - 0.01), v2(0.33, b:bottom(0.33) + 0.01) }, 0.045, dark)
	b:stroke({ v2(0.1, b:top(0.1) - 0.01), v2(0.08, b:bottom(0.08) + 0.01) }, 0.055, dark)
	b:stroke({ v2(-0.15, b:top(-0.15) - 0.01), v2(-0.17, b:bottom(-0.17) + 0.01) }, 0.045, dark)
	b:rays(v2(0.09, 0.22), { v2(-0.12, 0.5) }, dark)
	b:rays(v2(0.07, -0.22), { v2(-0.12, -0.5) }, dark)
	b:rays(v2(-0.15, 0.17), { v2(-0.3, 0.55) }, dark)
	b:rays(v2(-0.17, -0.17), { v2(-0.3, -0.55) }, dark)
	b:pectoral(0.2, -0.02, 0.09, 0.03, fin, 0.3)
	b:face(0.37, 0.06, 0.05, rgb(196, 70, 54), rgb(170, 170, 160))
end

function builders.ArrowSquid(b)
	local colors = { back = rgb(176, 94, 84), side = rgb(206, 134, 120), belly = rgb(236, 206, 194) }
	b:layered("Mantle", Vector3.new(0.17, 0, 0), Vector3.new(0.6, 0.15, 0.15), colors)
	b:layered("MantleTip", Vector3.new(0.42, 0, 0), Vector3.new(0.2, 0.075, 0.075), colors)
	b:body("Head", Vector3.new(-0.15, 0, 0), Vector3.new(0.14, 0.11, 0.12), colors.side)
	b:ellipsoid("Collar", CFrame.new(-0.11, 0, 0), Vector3.new(0.06, 0.13, 0.135), colors.back)
	local finColor = rgb(214, 152, 136)
	for _, side in { 1, -1 } do
		b:fin(
			{ Vector3.new(0.53, 0, 0), Vector3.new(0.33, 0, side * 0.14), Vector3.new(0.25, 0, side * 0.02) },
			finColor,
			0.12
		)
	end
	b:speckle(70, v2(-0.08, 0.5), v2(-0.07, 0.075), v2(0.007, 0.016), rgb(128, 52, 46))
	b:stroke({ v2(0.48, 0.02), v2(0.0, 0.07) }, 0.006, rgb(150, 70, 62))
	b:eye(-0.15, 0.008, 0.07, rgb(172, 192, 204))
	local armColor = rgb(212, 142, 128)
	for index = 0, 7 do
		local angle = index / 8 * math.pi * 2
		local spread = Vector3.new(0, math.cos(angle), math.sin(angle))
		local root = Vector3.new(-0.2, 0, 0) + spread * 0.035
		local middle = Vector3.new(-0.34, -0.01, 0) + spread * 0.055
		local tip = Vector3.new(-0.47 + math.abs(math.sin(angle)) * 0.03, -0.03, 0) + spread * 0.045
		b:limb(root, middle, 0.028, armColor, "Arm")
		b:limb(middle, tip, 0.017, armColor, "Arm")
		for step = 1, 3 do
			local sucker = root:Lerp(middle, step / 4) - spread * 0.012
			b:ellipsoid("Sucker", CFrame.new(sucker), Vector3.one * 0.008, rgb(238, 210, 196))
		end
	end
	for _, side in { 1, -1 } do
		local root, middle = Vector3.new(-0.2, -0.01, side * 0.015), Vector3.new(-0.42, -0.05, side * 0.04)
		local club = Vector3.new(-0.62, -0.03, side * 0.05)
		b:limb(root, middle, 0.012, armColor, "Tentacle")
		b:limb(middle, club, 0.01, armColor, "Tentacle")
		b:ellipsoid(
			"TentacleClub",
			CFrame.lookAt(club, club + Vector3.xAxis),
			Vector3.new(0.022, 0.026, 0.07),
			armColor
		)
	end
	b.model:SetAttribute("ViewDirection", Vector3.new(0.1, 0.65, 1))
end

function builders.GreyEel(b)
	local back, side, belly = rgb(84, 88, 92), rgb(128, 132, 134), rgb(208, 206, 192)
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
		local length, h = (c - a).Magnitude * 1.9, radius(t)
		b:ellipsoid("Body", frame, Vector3.new(length, h * 2, h * 1.7), side)
		b:ellipsoid("BodyBack", frame + up * h * 0.14, Vector3.new(length * 0.98, h * 1.7, h * 1.72), back)
		b:ellipsoid("BodyBelly", frame - up * h * 0.16, Vector3.new(length * 0.97, h * 1.6, h * 1.71), belly)
		if t > 0.22 then
			table.insert(finTop, { middle + up * h * 0.75, middle + up * (h + 0.03 * (1 - t * 0.4)) })
		end
		if t > 0.42 then
			table.insert(finBottom, { middle - up * h * 0.75, middle - up * (h + 0.026 * (1 - t * 0.4)) })
		end
	end
	local finColor = rgb(110, 112, 108)
	for _, ribbon in { finTop, finBottom } do
		for index = 1, #ribbon - 1 do
			local a, c = ribbon[index], ribbon[index + 1]
			b:fin({ a[1], a[2], c[2], c[1] }, finColor, 0.15)
		end
		local last = ribbon[#ribbon]
		b:fin({ last[1], last[2], spine[#spine] - Vector3.new(0.02, 0, 0) }, finColor, 0.15)
	end
	local headY = spine[1].Y
	b:body("Head", Vector3.new(0.44, headY, 0), Vector3.new(0.14, 0.11, 0.094), side)
	b:body("HeadBack", Vector3.new(0.44, headY + 0.012, 0), Vector3.new(0.135, 0.095, 0.096), back)
	b:eye(0.475, headY + 0.016, 0.026, rgb(150, 150, 120))
	b:stroke({ v2(0.51, headY - 0.008), v2(0.455, headY - 0.022) }, 0.007, rgb(30, 30, 30))
	b:marks(0.385, headY - 0.005, 0.012, 0.03, rgb(54, 56, 58))
	b:pectoral(0.38, headY - 0.01, 0.05, 0.03, finColor, 0.1)
end

function builders.GulfFlounder(b)
	local brown, under = rgb(124, 98, 66), rgb(238, 236, 228)
	b:body("Disc", Vector3.new(0.02, 0, 0), Vector3.new(0.74, 0.46, 0.06), brown)
	b:ellipsoid("Underside", CFrame.new(0.02, 0, -0.008), Vector3.new(0.735, 0.455, 0.056), under)
	b:body("HeadBump", Vector3.new(0.33, 0.03, 0), Vector3.new(0.17, 0.18, 0.05), brown)
	b:ellipsoid("TailStalk", CFrame.new(-0.34, 0, 0), Vector3.new(0.09, 0.1, 0.04), brown)
	local finColor, rayColor = rgb(142, 114, 80), rgb(100, 80, 56)
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
			if b.random(0, 1) > 0.5 then rgb(156, 128, 90) else rgb(92, 70, 46)
		)
	end
	for _, spot in { v2(-0.02, 0.11), v2(-0.02, -0.11), v2(-0.2, 0) } do
		b:mark(spot.X, spot.Y, 1, 0.065, 0.065, rgb(204, 182, 142))
		b:mark(spot.X, spot.Y, 1, 0.042, 0.042, rgb(36, 28, 22), nil, 0.001)
	end
	for _, eye in { v2(0.35, 0.06), v2(0.3, 0.125) } do
		local position, normal = b:surface(eye.X, eye.Y, 1)
		if position and normal then
			local center = position + normal * 0.01
			b:ellipsoid("EyeBulge", CFrame.new(center), Vector3.new(0.045, 0.04, 0.035), brown)
			b:ellipsoid("Eye", CFrame.new(center + normal * 0.012), Vector3.new(0.032, 0.03, 0.02), rgb(206, 176, 90))
			b:ellipsoid("Pupil", CFrame.new(center + normal * 0.018), Vector3.new(0.02, 0.012, 0.014), rgb(14, 14, 14))
		end
	end
	b:mark(0.41, -0.03, 1, 0.07, 0.012, rgb(60, 44, 30), v2(-1, -1.2))
	b.model:SetAttribute("ViewDirection", Vector3.new(0.15, 0.3, 1))
end

function builders.Stingray(b)
	local top, darker, under = rgb(104, 88, 70), rgb(88, 74, 58), rgb(234, 232, 224)
	local half = {
		v2(0.46, 0),
		v2(0.42, 0.08),
		v2(0.34, 0.18),
		v2(0.24, 0.27),
		v2(0.14, 0.31),
		v2(0.04, 0.3),
		v2(-0.06, 0.24),
		v2(-0.13, 0.15),
		v2(-0.17, 0.07),
		v2(-0.18, 0),
	}
	local center = Vector3.new(0.12, 0, 0)
	for _, sign in { 1, -1 } do
		for index = 1, #half - 1 do
			local a, c = half[index], half[index + 1]
			b:triangle(center, Vector3.new(a.X, 0, a.Y * sign), Vector3.new(c.X, 0, c.Y * sign), top)
		end
	end
	local domes = {
		{ Vector3.new(0.13, 0, 0), Vector3.new(0.56, 0.03, 0.54), top },
		{ Vector3.new(0.13, 0.008, 0), Vector3.new(0.46, 0.07, 0.3), top },
		{ Vector3.new(0.07, 0.022, 0), Vector3.new(0.32, 0.05, 0.1), darker },
	}
	for _, dome in domes do
		b:ellipsoid("Disc", CFrame.new(dome[1]), dome[2], dome[3])
	end
	b:ellipsoid("Underside", CFrame.new(0.13, -0.008, 0), Vector3.new(0.56, 0.026, 0.54), under)
	local function height(x: number, z: number): number
		local best = 0.002
		for _, dome in domes do
			local h = dome[2] / 2
			local dx, dz = (x - dome[1].X) / h.X, (z - dome[1].Z) / h.Z
			local remaining = 1 - dx * dx - dz * dz
			if remaining > 0 then
				best = math.max(best, dome[1].Y + h.Y * math.sqrt(remaining))
			end
		end
		return best
	end
	for _ = 1, 54 do
		local x, z = b.random(-0.12, 0.4), b.random(-0.27, 0.27)
		local reach = 0.3 * (1 - math.abs(x - 0.12) / 0.4)
		if math.abs(z) < reach then
			local size = b.random(0.012, 0.032)
			b:ellipsoid(
				"Spot",
				CFrame.new(x, height(x, z) + 0.002, z),
				Vector3.new(size, 0.004, size),
				if b.random(0, 1) > 0.35 then rgb(170, 152, 118) else rgb(66, 54, 42)
			)
		end
	end
	for _, sign in { 1, -1 } do
		b:ellipsoid(
			"Eye",
			CFrame.new(0.3, height(0.3, 0.055 * sign) + 0.008, 0.055 * sign),
			Vector3.new(0.035, 0.028, 0.028),
			rgb(36, 32, 28)
		)
		b:ellipsoid(
			"EyeGlint",
			CFrame.new(0.305, height(0.3, 0.055 * sign) + 0.022, 0.05 * sign),
			Vector3.one * 0.008,
			rgb(255, 255, 255)
		)
		b:ellipsoid(
			"Spiracle",
			CFrame.new(0.255, height(0.255, 0.06 * sign) + 0.002, 0.06 * sign),
			Vector3.new(0.03, 0.006, 0.018),
			rgb(48, 40, 32)
		)
		b:ellipsoid("PelvicFin", CFrame.new(-0.19, 0.004, 0.045 * sign), Vector3.new(0.08, 0.016, 0.05), top)
	end
	local previous = Vector3.new(-0.16, 0.01, 0)
	for index = 1, 7 do
		local t = index / 7
		local point = Vector3.new(-0.16 - t * 0.46, 0.01 + t * 0.01, math.sin(t * math.pi) * 0.03)
		b:limb(previous, point, 0.04 * (1 - t) + 0.006, darker, "Tail")
		previous = point
	end
	b:limb(Vector3.new(-0.3, 0.03, 0.016), Vector3.new(-0.38, 0.036, 0.024), 0.008, rgb(214, 204, 182), "Barb")
	b.model:SetAttribute("ViewDirection", Vector3.new(0.35, 1, 0.55))
end

function builders.Clownfish(b)
	local colors = { back = rgb(222, 92, 20), side = rgb(240, 122, 32), belly = rgb(246, 158, 72) }
	local fin = rgb(236, 112, 30)
	local white, edge = rgb(250, 250, 246), rgb(22, 18, 16)
	b:fishBody(0.36, 0.14, colors, 0.06)
	b:edgeFin(0.12, -0.26, { 0.06, 0.07, 0.06, 0.08, 0.09, 0.08 }, fin)
	b:edgeFin(-0.06, -0.24, { 0.06, 0.08, 0.06 }, fin, true)
	b:edgeFin(0.08, 0, { 0.07, 0.05 }, fin, true)
	b:roundTail(0.13, fin)
	b:pectoral(0.18, -0.04, 0.11, 0.05, fin)
	-- White bands with thin black borders.
	for _, x in { 0.2, -0.02, -0.3 } do
		local width = if x < -0.2 then 0.03 else 0.045
		b:stroke({ v2(x, b:top(x) - 0.008), v2(x - 0.01, b:bottom(x) + 0.008) }, width, white)
		for _, offset in { -1, 1 } do
			local bx = x + offset * (width / 2 + 0.008)
			b:stroke({ v2(bx, b:top(bx) - 0.008), v2(bx - 0.01, b:bottom(bx) + 0.008) }, 0.009, edge)
		end
	end
	b:face(0.38, 0.04, 0.05, rgb(232, 120, 40), edge)
end

function builders.Sardine(b)
	local colors = { back = rgb(40, 96, 112), side = rgb(176, 192, 196), belly = rgb(240, 242, 242) }
	local fin = rgb(150, 164, 166)
	b:fishBody(0.18, 0.1, colors, 0.04)
	b:edgeFin(0.06, -0.05, { 0.06, 0.05, 0.03 }, fin, false, 0.15)
	b:edgeFin(-0.14, -0.22, { 0.03, 0.02 }, fin, true, 0.15)
	b:edgeFin(0, -0.05, { 0.03 }, fin, true, 0.15)
	b:forkTail(0.12, 0.08, fin, 0.1)
	b:pectoral(0.21, -0.04, 0.07, 0.025, fin, 0.15)
	b:stroke({ v2(0.26, 0.02), v2(-0.3, 0.01) }, 0.008, rgb(120, 150, 160))
	for x = 0.18, -0.2, -0.065 do
		b:marks(x, 0.035, 0.016, 0.016, rgb(26, 40, 48))
	end
	b:face(0.37, 0.015, 0.05, rgb(210, 214, 210), rgb(110, 130, 136))
end

function builders.Anchovy(b)
	local colors = { back = rgb(70, 112, 104), side = rgb(196, 204, 196), belly = rgb(236, 238, 232) }
	local fin = rgb(176, 184, 176)
	b:fishBody(0.15, 0.09, colors, 0.02)
	b:edgeFin(0.04, -0.06, { 0.05, 0.04, 0.025 }, fin, false, 0.25)
	b:edgeFin(-0.06, -0.2, { 0.025, 0.025, 0.02 }, fin, true, 0.25)
	b:forkTail(0.11, 0.08, fin, 0.2)
	b:pectoral(0.22, -0.035, 0.06, 0.02, fin, 0.25)
	b:stroke({ v2(0.24, 0), v2(-0.32, 0) }, 0.016, rgb(214, 224, 228))
	-- Rounded snout overhanging a long jaw.
	b:ellipsoid("Snout", CFrame.new(0.47, 0.012, 0), Vector3.new(0.07, 0.05, 0.05), colors.back)
	b:face(0.39, 0.015, 0.058, rgb(200, 206, 200), rgb(130, 140, 134))
	b:stroke({ v2(0.46, -0.012), v2(0.34, -0.028) }, 0.006, rgb(40, 40, 36))
end

function builders.Catfish(b)
	local colors = { back = rgb(70, 74, 78), side = rgb(130, 132, 128), belly = rgb(226, 222, 210) }
	local fin, whisker = rgb(96, 98, 98), rgb(60, 60, 62)
	b:fishBody(0.2, 0.18, colors, 0.12)
	local dorsal = b:edgeFin(0.14, 0.03, { 0.1, 0.07, 0.04 }, fin, false, 0.05)
	b:rays(dorsal[1], { dorsal[3] }, rgb(52, 54, 56))
	b:ellipsoid("AdiposeFin", CFrame.new(-0.22, b:top(-0.22) + 0.006, 0), Vector3.new(0.09, 0.03, 0.012), fin)
	b:edgeFin(-0.04, -0.3, { 0.04, 0.05, 0.05, 0.045, 0.04 }, fin, true)
	b:edgeFin(0.06, 0, { 0.04 }, fin, true)
	b:forkTail(0.11, 0.05, fin)
	b:pectoral(0.24, -0.06, 0.11, 0.035, fin)
	for _, side in { 1, -1 } do
		local bend = Vector3.new(0.36, -0.06, side * 0.14)
		b:limb(Vector3.new(0.46, -0.01, side * 0.035), bend, 0.009, whisker, "Barbel")
		b:limb(bend, Vector3.new(0.22, -0.12, side * 0.17), 0.006, whisker, "Barbel")
		for _, z in { 0.015, 0.04 } do
			local chin = b:bottom(0.44)
			b:limb(
				Vector3.new(0.44, chin + 0.006, side * z),
				Vector3.new(0.41, chin - 0.05, side * z * 1.6),
				0.006,
				rgb(200, 196, 186),
				"Barbel"
			)
		end
	end
	b:face(0.4, 0.02, 0.03, rgb(150, 140, 100), rgb(90, 92, 92))
end

function builders.Pufferfish(b)
	local colors = { back = rgb(150, 132, 76), side = rgb(196, 180, 120), belly = rgb(240, 236, 214) }
	local fin = rgb(190, 170, 110)
	b:layered("Body", Vector3.new(0.06, 0, 0), Vector3.new(0.74, 0.58, 0.54), colors)
	b:layered("TailStalk", Vector3.new(-0.3, 0, 0), Vector3.new(0.18, 0.12, 0.1), colors)
	b:edgeFin(-0.2, -0.27, { 0.06, 0.05 }, fin, false, 0.2)
	b:edgeFin(-0.2, -0.27, { 0.06, 0.05 }, fin, true, 0.2)
	b:roundTail(0.11, fin, 0.15)
	b:pectoral(0.18, 0, 0.08, 0.06, fin, 0.25)
	b:speckle(40, v2(-0.25, 0.38), v2(0, 0.26), v2(0.016, 0.03), rgb(70, 60, 36))
	-- Inflated: short spines stand out all over the body.
	for _ = 1, 60 do
		local x, y = b.random(-0.24, 0.36), b.random(-0.25, 0.25)
		local side = if b.random(0, 1) > 0.5 then 1 else -1
		local position, normal = b:surface(x, y, side)
		if position and normal then
			b:limb(position - normal * 0.004, position + normal * 0.04, 0.007, rgb(226, 218, 186), "Spine")
		end
	end
	b:ellipsoid("Beak", CFrame.new(0.43, -0.04, 0), Vector3.new(0.05, 0.05, 0.07), rgb(232, 226, 200))
	b:face(0.3, 0.07, 0.085, rgb(64, 140, 120), rgb(160, 144, 90))
end

function builders.YellowfinTuna(b)
	local colors = { back = rgb(24, 40, 82), side = rgb(150, 160, 176), belly = rgb(232, 234, 236) }
	local fin, yellow = rgb(40, 52, 84), rgb(242, 196, 40)
	b:fishBody(0.27, 0.2, colors, 0.03)
	b:edgeFin(0.14, 0.02, { 0.08, 0.06, 0.03 }, fin, false, 0.05)
	-- Long yellow sickle fins, the species' trademark.
	b:fin({ v2(0, b:top(0) - 0.008), v2(-0.14, b:top(0) + 0.22), v2(-0.09, b:top(-0.09) - 0.008) }, yellow)
	b:fin(
		{ v2(-0.02, b:bottom(-0.02) + 0.008), v2(-0.16, b:bottom(-0.02) - 0.2), v2(-0.1, b:bottom(-0.1) + 0.008) },
		yellow
	)
	for index = 0, 5 do
		local x = -0.15 - index * 0.03
		for _, below in { false, true } do
			local edge = if below then b:bottom(x) else b:top(x)
			local sign = if below then -1 else 1
			b:fin({
				v2(x + 0.008, edge - sign * 0.004),
				v2(x - 0.012, edge + sign * 0.022),
				v2(x - 0.014, edge - sign * 0.004),
			}, yellow)
		end
	end
	b:forkTail(0.24, 0.18, fin)
	b:pectoral(0.21, 0.01, 0.2, 0.03, fin)
	b:stroke({ v2(0.28, 0.035), v2(0, 0.04), v2(-0.28, 0.012) }, 0.018, yellow)
	for x = 0.1, -0.24, -0.05 do
		b:stroke({ v2(x, -0.03), v2(x - 0.01, b:bottom(x) * 0.7) }, 0.006, rgb(200, 206, 214))
	end
	b:face(0.37, 0.03, 0.05, rgb(180, 170, 120), rgb(70, 80, 100))
end

function builders.Sailfish(b)
	local colors = { back = rgb(28, 50, 96), side = rgb(110, 140, 176), belly = rgb(226, 230, 234) }
	local fin, sail = rgb(34, 56, 104), rgb(40, 72, 150)
	b:fishBody(0.16, 0.1, colors, 0.02)
	local base = b:edgeFin(0.24, -0.16, { 0.2, 0.3, 0.33, 0.32, 0.28, 0.24, 0.18, 0.1 }, sail, false, 0.12)
	for index = 3, #base - 1 do
		local tip = base[index]
		local root = v2(tip.X, b:top(tip.X))
		b:rays(root, { tip }, rgb(24, 40, 90))
		b:finSpot(tip.X + 0.02, root.Y + (tip.Y - root.Y) * b.random(0.3, 0.7), 0.024, rgb(18, 26, 56))
	end
	b:edgeFin(-0.18, -0.25, { 0.04, 0.03 }, fin)
	b:edgeFin(-0.06, -0.2, { 0.08, 0.05, 0.03 }, fin, true)
	for _, side in { 1, -1 } do
		local belly = b:bottom(0.18)
		b:limb(
			Vector3.new(0.18, belly + 0.005, side * 0.01),
			Vector3.new(-0.06, belly - 0.12, side * 0.02),
			0.007,
			fin,
			"Filament"
		)
	end
	b:forkTail(0.2, 0.16, fin)
	b:pectoral(0.22, -0.03, 0.12, 0.025, fin)
	for x = 0.16, -0.26, -0.05 do
		b:stroke({ v2(x, b:top(x) * 0.8), v2(x - 0.01, 0) }, 0.008, rgb(150, 190, 226))
	end
	b:limb(Vector3.new(0.44, 0.005, 0), Vector3.new(0.82, 0, 0), 0.022, colors.back, "Bill")
	b:face(0.36, 0.02, 0.045, rgb(170, 180, 190), rgb(60, 80, 120))
end

function builders.Swordfish(b)
	local colors = { back = rgb(54, 46, 66), side = rgb(126, 118, 132), belly = rgb(214, 208, 204) }
	local fin = rgb(60, 52, 70)
	b:fishBody(0.2, 0.16, colors, 0.02)
	local crest = b:top(0.12)
	b:fin({ v2(0.24, b:top(0.24) - 0.008), v2(0.08, crest + 0.2), v2(0.1, crest + 0.04), v2(0.12, crest - 0.008) }, fin)
	local keel = b:bottom(0)
	b:fin(
		{ v2(0.04, keel + 0.008), v2(-0.08, keel - 0.12), v2(-0.06, keel - 0.03), v2(-0.04, b:bottom(-0.04) + 0.008) },
		fin
	)
	b:edgeFin(-0.24, -0.29, { 0.03 }, fin)
	b:edgeFin(-0.24, -0.29, { 0.03 }, fin, true)
	b:ellipsoid("Keel", CFrame.new(-0.33, 0, 0), Vector3.new(0.08, 0.03, b:top(-0.33) * 1.4), colors.back)
	b:forkTail(0.22, 0.17, fin)
	b:pectoral(0.22, -0.05, 0.14, 0.03, fin)
	-- The flat sword is about a third of the fish's whole length.
	b:ellipsoid("Sword", CFrame.new(0.72, 0.005, 0), Vector3.new(0.58, 0.028, 0.055), rgb(40, 34, 46))
	b:face(0.36, 0.025, 0.065, rgb(60, 70, 90), rgb(80, 70, 90))
end

function builders.Yellowshark(b)
	local colors = { back = rgb(196, 150, 32), side = rgb(232, 196, 70), belly = rgb(246, 238, 210) }
	local fin = rgb(204, 160, 40)
	b:fishBody(0.2, 0.19, colors, 0)
	b:layered("Snout", Vector3.new(0.43, 0.01, 0), Vector3.new(0.16, 0.1, 0.13), colors)
	b:fin({
		v2(0.12, b:top(0.12) - 0.008),
		v2(0, b:top(0) + 0.17),
		v2(-0.03, b:top(0) + 0.15),
		v2(-0.04, b:top(-0.04) - 0.008),
	}, fin)
	b:edgeFin(-0.22, -0.28, { 0.04, 0.025 }, fin)
	b:edgeFin(-0.2, -0.26, { 0.035, 0.02 }, fin, true)
	b:edgeFin(-0.04, -0.1, { 0.04, 0.03 }, fin, true)
	b:pectoral(0.18, -0.06, 0.2, 0.06, fin)
	-- Shark tail: the upper lobe reaches much further than the lower one.
	local stalk = b:top(-0.36)
	local upper, lower = v2(-0.34, stalk * 0.9), v2(-0.34, -stalk * 0.9)
	b:fin({ upper, v2(-0.6, 0.26), v2(-0.56, 0.2), v2(-0.42, 0), lower }, fin)
	b:fin({ lower, v2(-0.44, 0), v2(-0.52, -0.15) }, fin)
	b:speckle(24, v2(-0.3, 0.3), v2(0.02, 0.09), v2(0.015, 0.03), rgb(176, 128, 24))
	for index = 0, 4 do
		local x = 0.27 - index * 0.028
		b:stroke({ v2(x, 0.035), v2(x - 0.008, -0.04) }, 0.007, rgb(150, 110, 24))
	end
	b:stroke({ v2(0.43, -0.035), v2(0.38, -0.055), v2(0.32, -0.06) }, 0.008, rgb(60, 40, 20))
	b:eye(0.4, 0.03, 0.03, rgb(20, 20, 20))
end

function builders.WoodenBranch(b)
	local bark, wood = rgb(91, 61, 36), rgb(184, 145, 91)
	local points = {
		Vector3.new(-0.5, -0.04, 0),
		Vector3.new(-0.18, 0.01, 0.01),
		Vector3.new(0.15, -0.015, 0),
		Vector3.new(0.5, 0.06, -0.025),
	}
	for index = 1, #points - 1 do
		local part = b:limb(points[index], points[index + 1], 0.11 - index * 0.014, bark, "Bark")
		part.Material = Enum.Material.Wood
	end
	for _, twig in
		{
			{ points[2], Vector3.new(-0.02, 0.28, 0.025) },
			{ points[3], Vector3.new(0.3, -0.19, 0.06) },
		}
	do
		local part = b:limb(twig[1], twig[2], 0.045, bark, "Twig")
		part.Material = Enum.Material.Wood
		b:ellipsoid("BrokenTip", CFrame.new(twig[2]), Vector3.one * 0.034, wood)
	end
	for _, index in { 1, #points } do
		local tip = b:part("ExposedWood", "Part", Vector3.new(0.012, 0.065, 0.065), CFrame.new(points[index]), wood)
		tip.Shape = Enum.PartType.Cylinder
	end
	-- Thin ridges give the wet bark a rough, split surface.
	for index = 1, 5 do
		local x = -0.38 + index * 0.13
		b:limb(Vector3.new(x, 0.015, 0.04), Vector3.new(x + 0.09, 0.02, 0.04), 0.009, rgb(62, 43, 27), "BarkSplit")
	end
end

function builders.LeatherBoot(b)
	local leather, dark, sole = rgb(112, 70, 42), rgb(70, 44, 29), rgb(38, 32, 27)
	b:part("Sole", "Part", Vector3.new(0.82, 0.07, 0.32), CFrame.new(0.02, -0.28, 0), sole)
	b:part("Heel", "Part", Vector3.new(0.25, 0.08, 0.3), CFrame.new(-0.23, -0.33, 0), sole)
	b:ellipsoid("Toe", CFrame.new(0.24, -0.15, 0), Vector3.new(0.44, 0.24, 0.33), leather)
	b:ellipsoid("Foot", CFrame.new(-0.02, -0.13, 0), Vector3.new(0.55, 0.28, 0.31), leather)
	b:ellipsoid("Ankle", CFrame.new(-0.21, 0.06, 0), Vector3.new(0.29, 0.48, 0.29), leather)
	-- A dark inset and raised cuff make the boot's open top readable.
	b:part("Opening", "Part", Vector3.new(0.22, 0.018, 0.22), CFrame.new(-0.21, 0.29, 0), rgb(25, 20, 17))
	for _, side in { -1, 1 } do
		b:part("CuffSide", "Part", Vector3.new(0.31, 0.07, 0.035), CFrame.new(-0.21, 0.32, side * 0.135), dark)
		b:part("CuffEnd", "Part", Vector3.new(0.035, 0.07, 0.27), CFrame.new(-0.21 + side * 0.137, 0.32, 0), dark)
		b:limb(
			Vector3.new(-0.3, -0.2, side * 0.15),
			Vector3.new(0.26, -0.22, side * 0.15),
			0.009,
			rgb(164, 125, 81),
			"Stitching"
		)
	end
	for index = 0, 3 do
		local y = -0.02 + index * 0.065
		b:limb(Vector3.new(-0.055, y, -0.075), Vector3.new(-0.055, y + 0.04, 0.075), 0.012, sole, "Lace")
		b:limb(Vector3.new(-0.05, y, 0.075), Vector3.new(-0.05, y + 0.04, -0.075), 0.012, sole, "Lace")
	end
	b:ellipsoid("ToeScuff", CFrame.new(0.39, -0.11, 0.09), Vector3.new(0.06, 0.055, 0.12), rgb(149, 112, 73))
	b.model:SetAttribute("ViewDirection", Vector3.new(0.7, 0.4, 1))
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
}
local UNPAINTED = { Eye = true, Pupil = true, EyeGlint = true, Bone = true, BoneKnob = true, Wound = true }
local ASTRAL_GLOW = rgb(170, 70, 255)
-- The client cycles the hue of every part carrying a RainbowHue attribute.
FishModels.RAINBOW_TAG = "RainbowFish"

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

-- Drifting aurora motes and a faint violet glow from the biggest body part.
local function aurora(model: Model)
	local core: BasePart? = nil
	for _, item in model:GetChildren() do
		if item:IsA("Part") and not UNPAINTED[item.Name] and not GLOWING[item.Name] then
			if not core or item.Size.Magnitude > core.Size.Magnitude then
				core = item
			end
		end
	end
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
	local neon = traits.NeonColor and FishMutations.NeonColors[traits.NeonColor]
	local glow = if set.Astral then ASTRAL_GLOW elseif neon then rgb(neon[1], neon[2], neon[3]) else rgb(255, 255, 255)
	local lit = set.Neon or set.Astral
	local low, size = bounds(model)
	for _, item in model:GetDescendants() do
		if not item:IsA("BasePart") or UNPAINTED[item.Name] then
			continue
		end
		-- Hue runs snout to tail.
		local hue = (1 - (item.Position.X / SCALE - low.X) / math.max(size.X, 0.01)) * 0.85
		local shade = luminance(item.Color)
		if lit and GLOWING[item.Name] then
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
	end
	if set.Rainbow then
		model:AddTag(FishModels.RAINBOW_TAG)
	end
	if set.Astral then
		aurora(model)
	end
	measure(model)
end

function FishModels.has(fishId: string): boolean
	return builders[fishId] ~= nil
end

-- `traits` is a catch record (or anything with its Mutation, NeonColor and
-- Corruptions) to paint the fish with.
function FishModels.create(fishId: string, traits: any?): Model?
	local template = templates[fishId]
	if not template then
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
		local model = builder.model
		measure(model)
		if model:GetAttribute("ViewDirection") == nil then
			model:SetAttribute("ViewDirection", Vector3.new(0.18, 0.16, 1))
		end
		template = model
		templates[fishId] = model
	end
	local model = template:Clone()
	FishModels.mutate(model, traits)
	return model
end

-- Compact display size for the freezer and customer hands.
function FishModels.catchLength(kg: number): number
	local size = math.max(kg, 0.01) ^ (1 / 3)
	-- Smoothly compress record weights while retaining differences between
	-- catches. The longest side stays below the freezer's 3.54-stud ice depth.
	return 0.6 + 2.6 * size / (size + 0.75)
end

-- Held catches keep their weight differences without the freezer's size limit.
-- Big and Huge add a trophy-size boost so rare catches tower over normal ones.
function FishModels.heldLength(kg: number, size: string?): number
	local boost = if size == "Huge" then 3 elseif size == "Big" then 1.5 else 1
	return 1.6 * math.max(kg, 0.01) ^ (1 / 3) * boost
end

local function scaleToLength(model: Model, length: number): Vector3
	local bounds = model:GetAttribute("BoundsSize") :: Vector3
	local scale = length / math.max(bounds.X, bounds.Y, bounds.Z, 0.1)
	model:ScaleTo(scale)
	return bounds * scale
end

function FishModels.scaleCatch(model: Model, kg: number): Vector3
	return scaleToLength(model, FishModels.catchLength(kg))
end

function FishModels.scaleHeldCatch(model: Model, kg: number, size: string?): Vector3
	return scaleToLength(model, FishModels.heldLength(kg, size))
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
