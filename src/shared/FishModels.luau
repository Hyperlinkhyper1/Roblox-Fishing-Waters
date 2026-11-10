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
	local section = { c = center, h = size / 2 }
	table.insert(self.sections, section)
	return self:ellipsoid(name, CFrame.new(center), size, color, transparency), section
end

local function sameColors(a, b): boolean
	return a == b or (a.side == b.side and a.back == b.back and a.belly == b.belly)
end

-- Main colour with a darker back and paler belly layer offset above and below.
-- While a fishBody skin is still open, layers in the body's own colours (a
-- snout, hump or jaw) join the smooth skin instead of staying spheres.
function Builder:layered(name: string, center: Vector3, size: Vector3, colors)
	local side, sideSection = self:body(name, center, size, colors.side)
	local back, backSection = self:body(
		name .. "Back",
		center + Vector3.new(0, size.Y * 0.12, 0),
		size * Vector3.new(0.985, 0.86, 1.012),
		colors.back
	)
	local belly, bellySection = self:body(
		name .. "Belly",
		center - Vector3.new(0, size.Y * 0.14, 0),
		size * Vector3.new(0.97, 0.8, 1.006),
		colors.belly
	)
	local open = self.skinOpen
	if open and sameColors(open.colors, colors) then
		for _, part in { side, back, belly } do
			table.insert(open.parts, part)
		end
		for _, section in { sideSection, backSection, bellySection } do
			table.insert(open.sections, section)
		end
		open.swatches = open.swatches or { Side = side, Back = back, Belly = belly }
	end
	return side, back, belly
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

-- Sections the smooth skin replaces are skipped while it is in use (the carp
-- clears `loft` briefly to lay its scale discs on the spheres underneath).
local function solid(self, section): boolean
	return not (section.skin and self.loft)
end

-- Outermost body surface at (x, y) on one side (+1 or -1), with its normal.
function Builder:surface(x: number, y: number, side: number): (Vector3?, Vector3?)
	self:finishSkin()
	local bestPoint: Vector3?, bestNormal: Vector3? = nil, nil
	local bestZ = -1
	if self.loft then
		local ring = loftRing(self.loft, x)
		if ring and ring.top > ring.bottom then
			local c = (y - (ring.top + ring.bottom) / 2) / ((ring.top - ring.bottom) / 2)
			if math.abs(c) < 1 then
				local angle = math.acos(c) * side
				local point = loftPoint(ring, angle)
				bestPoint, bestNormal = point, loftNormal(self.loft, x, angle)
				bestZ = point.Z * side
			end
		end
	end
	local best: Ellipsoid? = nil
	for _, section in self.sections do
		if not solid(self, section) then
			continue
		end
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
		return bestPoint, bestNormal
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
	self:finishSkin()
	local best = 0
	if self.loft then
		local ring = loftRing(self.loft, x)
		best = if ring then math.max(ring.top, 0) else 0
	end
	for _, section in self.sections do
		local dx = (x - section.c.X) / section.h.X
		if dx * dx < 1 and solid(self, section) then
			best = math.max(best, section.c.Y + section.h.Y * math.sqrt(1 - dx * dx))
		end
	end
	return best
end

function Builder:bottom(x: number): number
	self:finishSkin()
	local best = 0
	if self.loft then
		local ring = loftRing(self.loft, x)
		best = if ring then math.min(ring.bottom, 0) else 0
	end
	for _, section in self.sections do
		local dx = (x - section.c.X) / section.h.X
		if dx * dx < 1 and solid(self, section) then
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

-- Shared bony-fish body: head, chest, rear body and tail stalk. It gets a
-- smooth skin (see Builder:smoothSkin) through the envelope of these spheres
-- and any same-coloured layers added before the first surface query.
function Builder:fishBody(depth: number, width: number, colors, headDrop: number?)
	local drop = headDrop or 0.05
	self:beginSkin(colors)
	self:layered("Chest", Vector3.new(0.1, 0, 0), Vector3.new(0.6, depth, width), colors)
	self:layered("Head", Vector3.new(0.29, -depth * drop, 0), Vector3.new(0.38, depth * 0.8, width * 0.9), colors)
	self:layered("Rear", Vector3.new(-0.13, 0, 0), Vector3.new(0.42, depth * 0.72, width * 0.78), colors)
	self:layered("TailStalk", Vector3.new(-0.29, 0, 0), Vector3.new(0.2, depth * 0.3, width * 0.42), colors)
end

-- Loft rings through hand-tuned { x, top, bottom, half width } stations.
local function stationRings(stations: { { number } }): { Ring }
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
	return rings
end

-- Loft rings hugging the outside of a set of axis-aligned ellipsoids, snout
-- first. `extra` ({ front, back, at }) adds a shape the spheres don't describe
-- (the eel's waving tube): at(x) returns its top, bottom and half width. Rings crowd towards both tips so they close smoothly,
-- and creases where two spheres meet are filled so the skin reads as one body.
local function envelopeRings(sections: { Ellipsoid }, extra: any?): { Ring }
	local front, back = -math.huge, math.huge
	for _, section in sections do
		front = math.max(front, section.c.X + section.h.X)
		back = math.min(back, section.c.X - section.h.X)
	end
	if extra then
		front, back = math.max(front, extra.front), math.min(back, extra.back)
	end
	local span = front - back
	local count = math.clamp(math.ceil(span * 100), 40, 160)
	local rings: { Ring } = {}
	for index = 1, count - 1 do
		local x = front - span * (1 - math.cos(math.pi * index / count)) / 2
		local top, bottom, width = -math.huge, math.huge, 0
		for _, section in sections do
			local dx = (x - section.c.X) / section.h.X
			if dx * dx < 1 then
				local s = math.sqrt(1 - dx * dx)
				top = math.max(top, section.c.Y + section.h.Y * s)
				bottom = math.min(bottom, section.c.Y - section.h.Y * s)
				width = math.max(width, math.abs(section.c.Z) + section.h.Z * s)
			end
		end
		if extra then
			local t, b, w = extra.at(x)
			if t then
				top, bottom, width = math.max(top, t), math.min(bottom, b :: number), math.max(width, w :: number)
			end
		end
		if top > bottom then
			table.insert(rings, { x = x, top = top, bottom = bottom, width = width })
		end
	end
	for _ = 1, 3 do
		local smoothed = {}
		for index, ring in rings do
			local a, c = rings[index - 1], rings[index + 1]
			if a and c then
				smoothed[index] = {
					x = ring.x,
					top = math.max(ring.top, (a.top + 2 * ring.top + c.top) / 4),
					bottom = math.min(ring.bottom, (a.bottom + 2 * ring.bottom + c.bottom) / 4),
					width = math.max(ring.width, (a.width + 2 * ring.width + c.width) / 4),
				}
			else
				smoothed[index] = ring
			end
		end
		rings = smoothed
	end
	return rings
end

-- Replaces sphere bodies with one smooth skin. EditableMesh never replicates,
-- so the spheres are still built: servers and the wiki see them, and
-- FishMeshes hides them (`parts`) on each client once the skin exists. The
-- `swatches` (Side, Back, Belly) lend the skin their colours, so mutations
-- that repaint parts repaint the skin too. Markings, eyes and fins placed
-- afterwards follow the skin's surface. `mode` "flat" paints the +Z face from
-- Side and the -Z face from Belly (flatfish) instead of back-to-belly bands.
function Builder:smoothSkin(rings: { Ring }, parts: { BasePart }, swatches, sections: { Ellipsoid }?, mode: string?)
	self.skinDone, self.skinOpen = true, nil
	if #rings < 2 or not swatches or not swatches.Side then
		return
	end
	for _, section in sections or {} do
		section.skin = true
	end
	for _, part in parts do
		part:SetAttribute("LoftFallback", true)
	end
	for name, part in swatches do
		part:SetAttribute("LoftSwatch", name)
	end
	self.loft = rings
	local anchor = swatches.Side
	lofts[self.model.Name] = { rings = rings, anchorPosition = anchor.Position, anchorSize = anchor.Size, mode = mode }
	self.model:SetAttribute("LoftFish", self.model.Name)
	self.model:AddTag(FishModels.LOFT_TAG)
end

-- Opens a smooth skin: b:layered calls in these `colors` join it until the
-- first surface query (or b:finishSkin()), which lofts it round their spheres.
function Builder:beginSkin(colors)
	if not self.skinDone and not self.skinOpen then
		self.skinOpen = { colors = colors, parts = {}, sections = {} }
	end
end

-- Ring helpers for custom bodies (species modules can't reach the locals):
-- b:smoothSkin(b:envelope({ section, ... }), parts, { Side = p, Back = p, Belly = p }, sections)
-- where sections are the second values b:body returns.
function Builder:envelope(sections: { Ellipsoid }, extra: any?): { Ring }
	return envelopeRings(sections, extra)
end

function Builder:stations(stations: { { number } }): { Ring }
	return stationRings(stations)
end

-- Closes the fishBody skin opened earlier: called on the first surface query
-- and after every builder, so later layers stay separate spheres.
function Builder:finishSkin(stations: { { number } }?)
	local open = self.skinOpen
	if not open or self.skinDone then
		return
	end
	local rings = if stations then stationRings(stations) else envelopeRings(open.sections)
	self:smoothSkin(rings, open.parts, open.swatches, open.sections)
end

-- fishBody with a hand-tuned profile ({ x, top, bottom, half width }
-- stations, snout first) instead of the spheres' envelope.
function Builder:loftBody(stations: { { number } }, colors, depth: number, width: number, headDrop: number?)
	self:fishBody(depth, width, colors, headDrop)
	self:finishSkin(stations)
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
-- The smooth skin follows `p.stations` or the default carp profile.
local function carp(b, p)
	local colors, fin = p.colors, p.fin
	b:loftBody(p.stations or CARP_STATIONS, colors, 0.29, 0.16, 0.08)
	b:edgeFin(0.11, -0.22, { 0.095, 0.07, 0.05, 0.045, 0.04, 0.035 }, fin, false, 0.05)
	b:edgeFin(-0.12, -0.22, { 0.07, 0.05 }, fin, true)
	b:edgeFin(0.02, -0.06, { 0.06, 0.05 }, fin, true)
	b:forkTail(0.15, 0.05, fin)
	b:pectoral(0.2, -0.08, 0.1, 0.04, fin)
	-- Scale discs belong to the sphere body, where they hide its seams, so they
	-- are laid on its spheres and hidden with it. On the smooth skin they read
	-- as studs; its back-to-belly bands carry the colour instead.
	local loft = b.loft
	local existing = {}
	for _, item in b.model:GetChildren() do
		existing[item] = true
	end
	b.loft = nil
	local row = 0
	for y = -0.1, 0.105, 0.04 do
		row += 1
		for x = 0.2 - (row % 2) * 0.022, -0.32, -0.045 do
			b:marks(x, y, 0.036, 0.03, if (row + math.floor(x * 40)) % 3 == 0 then p.scale else p.scaleAlt)
		end
	end
	b.loft = loft
	if loft then
		for _, item in b.model:GetChildren() do
			if not existing[item] then
				item:SetAttribute("LoftFallback", true)
			end
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
	b:ellipsoid("Lips", CFrame.new(0.5, -0.035, 0), Vector3.new(0.04, 0.035, 0.055), p.lips)
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
	local tube, firstBelly = {}, nil
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
		table.insert(tube, b:ellipsoid("Body", frame, Vector3.new(length, h * 2, h * 1.7), side))
		table.insert(tube, b:ellipsoid("BodyBack", frame + up * h * 0.14, Vector3.new(length * 0.98, h * 1.7, h * 1.72), back))
		local bellyPart = b:ellipsoid("BodyBelly", frame - up * h * 0.16, Vector3.new(length * 0.97, h * 1.6, h * 1.71), belly)
		table.insert(tube, bellyPart)
		firstBelly = firstBelly or bellyPart
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
	local head, headSection = b:body("Head", Vector3.new(0.43, headY, 0), Vector3.new(0.17, 0.1, 0.088), side)
	local headBack, headBackSection =
		b:body("HeadBack", Vector3.new(0.43, headY + 0.012, 0), Vector3.new(0.165, 0.085, 0.09), back)
	local snout, snoutSection = b:body("Snout", Vector3.new(0.5, headY - 0.004, 0), Vector3.new(0.08, 0.05, 0.052), back)
	-- One smooth skin over the head and the waving tube (whose sections are
	-- angled, so the tube is described directly), narrowing to the tail tip.
	local heads = { headSection, headBackSection, snoutSection }
	local rings = envelopeRings(heads, {
		front = 0.5,
		back = -0.52,
		at = function(x: number)
			local t = 0.5 - x
			if t < 0 then
				return nil
			end
			local h = radius(math.min(t, 1)) * math.sqrt(math.clamp((1.02 - t) / 0.06, 0, 1))
			local y = 0.035 * math.sin(t * math.pi * 2.2)
			return y + h, y - h, h * 0.86
		end,
	})
	table.insert(tube, head)
	table.insert(tube, headBack)
	table.insert(tube, snout)
	b:smoothSkin(rings, tube, { Side = head, Back = headBack, Belly = firstBelly }, heads)
	b:eye(0.475, headY + 0.016, p.eyeSize or 0.026, p.iris)
	b:stroke({ v2(0.51, headY - 0.008), v2(0.455, headY - 0.022) }, 0.007, rgb(30, 30, 30))
	b:marks(0.385, headY - 0.005, 0.012, 0.03, back:Lerp(rgb(0, 0, 0), 0.35))
	b:pectoral(0.38, headY - 0.01, 0.05, 0.03, finColor, 0.1)
end

-- Flatfish lying on its blind side with both eyes up; `p` is the palette and
-- p.ocelli (optional) are the eye-spot positions.
local function flatfish(b, p)
	local brown, under = p.top, p.under
	local disc, discSection = b:body("Disc", Vector3.new(0.02, 0, 0), Vector3.new(0.74, 0.46, 0.06), brown)
	local underside = b:ellipsoid("Underside", CFrame.new(0.02, 0, -0.008), Vector3.new(0.735, 0.455, 0.056), under)
	local bump, bumpSection = b:body("HeadBump", Vector3.new(0.33, 0.03, 0), Vector3.new(0.17, 0.18, 0.05), brown)
	local stalk = b:ellipsoid("TailStalk", CFrame.new(-0.34, 0, 0), Vector3.new(0.09, 0.1, 0.04), brown)
	-- Smooth skin: eyed (+Z) face from the Disc, blind face from the Underside.
	local stalkSection = { c = Vector3.new(-0.34, 0, 0), h = Vector3.new(0.045, 0.05, 0.02) }
	b:smoothSkin(
		envelopeRings({ discSection, bumpSection, stalkSection }),
		{ disc, underside, bump, stalk },
		{ Side = disc, Belly = underside },
		{ discSection, bumpSection },
		"flat"
	)
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

-- Nescio Fih cross-sections, snout first: { x, top, bottom, half width }. A
-- pointed shark's head on a thin neck, a hunched body, broad hips for the legs
-- and a long tail narrowing into the paddle.
local NESCIO_STATIONS = {
	{ 0.502, -0.04, -0.046, 0.003 },
	{ 0.494, -0.026, -0.054, 0.01 },
	{ 0.478, -0.01, -0.061, 0.017 },
	{ 0.455, 0.006, -0.066, 0.023 },
	{ 0.425, 0.022, -0.069, 0.028 },
	{ 0.395, 0.034, -0.069, 0.032 },
	{ 0.365, 0.04, -0.065, 0.034 },
	{ 0.335, 0.041, -0.057, 0.033 },
	{ 0.305, 0.04, -0.048, 0.03 },
	{ 0.275, 0.047, -0.049, 0.032 },
	{ 0.235, 0.06, -0.056, 0.039 },
	{ 0.185, 0.075, -0.063, 0.046 },
	{ 0.125, 0.086, -0.068, 0.051 },
	{ 0.065, 0.09, -0.07, 0.053 },
	{ 0.005, 0.085, -0.07, 0.054 },
	{ -0.045, 0.074, -0.066, 0.056 },
	{ -0.095, 0.06, -0.057, 0.051 },
	{ -0.145, 0.044, -0.045, 0.041 },
	{ -0.2, 0.031, -0.036, 0.031 },
	{ -0.26, 0.021, -0.029, 0.023 },
	{ -0.32, 0.013, -0.023, 0.016 },
	{ -0.38, 0.007, -0.019, 0.011 },
	{ -0.43, 0.002, -0.016, 0.007 },
	{ -0.47, -0.003, -0.013, 0.0035 },
}

-- A smooth tapered tube through `points` (fish lengths): long overlapping
-- ellipsoids along a Catmull-Rom curve, the radius running through `radii`
-- (one per point). Each piece is appended to `samples` (for hair) when given.
local function fleshTube(b, points: { Vector3 }, radii: { number }, color: Color3, name: string, samples: { any }?)
	local count = #points
	local path = {}
	for index = 1, count - 1 do
		local p0, p1 = points[math.max(index - 1, 1)], points[index]
		local p2, p3 = points[index + 1], points[math.min(index + 2, count)]
		local thinnest = math.min(radii[index], radii[index + 1])
		local steps = math.max(2, math.ceil((p2 - p1).Magnitude / math.max(thinnest * 0.7, 0.008)))
		for step = 0, steps - 1 do
			local t = step / steps
			table.insert(path, {
				Vector3.new(
					catmull(p0.X, p1.X, p2.X, p3.X, t),
					catmull(p0.Y, p1.Y, p2.Y, p3.Y, t),
					catmull(p0.Z, p1.Z, p2.Z, p3.Z, t)
				),
				radii[index] + (radii[index + 1] - radii[index]) * t,
			})
		end
	end
	table.insert(path, { points[count], radii[count] })
	for index = 1, #path - 1 do
		local a, c = path[index], path[index + 1]
		local delta = c[1] - a[1]
		local length = delta.Magnitude
		if length > 1e-5 then
			local radius = (a[2] + c[2]) / 2
			local middle = (a[1] + c[1]) / 2
			local up = if math.abs(delta.Unit.Y) > 0.98 then Vector3.xAxis else Vector3.yAxis
			local frame = CFrame.lookAt(middle, c[1], up) * CFrame.Angles(0, math.pi / 2, 0)
			b:ellipsoid(name, frame, Vector3.new(length * 3.2, radius * 2, radius * 2), color)
			if samples then
				table.insert(samples, { point = middle, radius = radius, along = delta.Unit })
			end
		end
	end
	b:ellipsoid(name, CFrame.new(points[1]), Vector3.one * radii[1] * 2, color)
	b:ellipsoid(name, CFrame.new(points[count]), Vector3.one * radii[count] * 2, color)
end

-- The Nescio Fih: a pale, blotchy thing with a pointed shark's head, a hunched
-- body, two frog-like hind legs folded under it and a long paddle tail.
-- `p.hairy` grows a coat of brown hair over it (the Hairy Nescio Fih).
local function nescio(b, p)
	local colors = p.colors or { back = rgb(232, 200, 186), side = rgb(242, 216, 202), belly = rgb(248, 230, 220) }
	local flesh, joint = p.flesh or rgb(240, 212, 198), rgb(237, 196, 182)
	local fold, blush = rgb(220, 170, 156), rgb(226, 160, 146)
	-- Sphere stand-ins for servers and clients without EditableMesh; the
	-- smooth skin follows NESCIO_STATIONS on top of them.
	b:beginSkin(colors)
	b:layered("Chest", Vector3.new(0.12, 0.01, 0), Vector3.new(0.32, 0.158, 0.106), colors)
	b:layered("Head", Vector3.new(0.41, -0.016, 0), Vector3.new(0.17, 0.104, 0.066), colors)
	b:layered("Snout", Vector3.new(0.47, -0.034, 0), Vector3.new(0.07, 0.046, 0.032), colors)
	b:layered("Neck", Vector3.new(0.3, -0.004, 0), Vector3.new(0.1, 0.088, 0.062), colors)
	b:layered("Hips", Vector3.new(-0.05, 0.004, 0), Vector3.new(0.17, 0.138, 0.112), colors)
	b:layered("Rear", Vector3.new(-0.19, -0.003, 0), Vector3.new(0.18, 0.07, 0.064), colors)
	b:layered("TailStalk", Vector3.new(-0.33, -0.006, 0), Vector3.new(0.17, 0.032, 0.028), colors)
	b:layered("TailTip", Vector3.new(-0.43, -0.008, 0), Vector3.new(0.09, 0.018, 0.013), colors)
	b:finishSkin(NESCIO_STATIONS)

	-- Legs: a muscular haunch, thigh forward to the knee, shin back to the
	-- heel, a long foot and four splayed toes with pads and pale nails.
	local legSamples = {}
	local nail = rgb(226, 206, 196)
	for _, s in { 1, -1 } do
		local hip = Vector3.new(-0.04, -0.02, s * 0.04)
		local knee = Vector3.new(0.06, -0.1, s * 0.105)
		local ankle = Vector3.new(-0.06, -0.14, s * 0.11)
		local ball = Vector3.new(0.025, -0.162, s * 0.114)
		local haunch = CFrame.new(-0.015, -0.04, s * 0.05) * CFrame.Angles(0, 0, math.rad(-32))
		b:ellipsoid("Haunch", haunch, Vector3.new(0.12, 0.08, 0.06), flesh)
		local thighMid, shinMid = Vector3.new(0.005, -0.07, s * 0.085), Vector3.new(0.005, -0.122, s * 0.11)
		fleshTube(b, { hip, thighMid, knee }, { 0.04, 0.032, 0.02 }, flesh, "Thigh", legSamples)
		fleshTube(b, { knee, shinMid, ankle }, { 0.019, 0.015, 0.011 }, flesh, "Shin", legSamples)
		fleshTube(b, { ankle, Vector3.new(-0.02, -0.156, s * 0.112), ball }, { 0.012, 0.0095, 0.009 }, flesh, "Foot")
		local kneeCap = knee + Vector3.new(0.004, 0.001, s * 0.002)
		b:ellipsoid("Knee", CFrame.new(kneeCap), Vector3.new(0.042, 0.038, 0.038), joint)
		b:ellipsoid("Heel", CFrame.new(ankle + Vector3.new(-0.006, -0.002, 0)), Vector3.new(0.03, 0.027, 0.025), joint)
		for index, spread in { -0.46, -0.15, 0.15, 0.46 } do
			local yaw = spread * s
			local direction = Vector3.new(math.cos(yaw), -0.08, math.sin(yaw)).Unit
			local length = ({ 0.036, 0.048, 0.05, 0.04 })[index]
			local base = ball + direction * 0.004
			local middle = base + direction * length * 0.5 + Vector3.new(0, 0.002, 0)
			local tip = base + direction * length
			fleshTube(b, { base, middle, tip }, { 0.0066, 0.0054, 0.0046 }, flesh, "Toe")
			b:ellipsoid("Knuckle", CFrame.new(middle), Vector3.one * 0.0124, joint)
			b:ellipsoid("ToePad", CFrame.new(tip + Vector3.new(0, -0.001, 0)), Vector3.new(0.013, 0.0105, 0.012), joint)
			local nailAt = tip + direction * 0.002 + Vector3.new(0, 0.0036, 0)
			local nailFrame = CFrame.lookAt(nailAt, tip + direction, Vector3.yAxis)
			b:ellipsoid("Nail", nailFrame * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(0.008, 0.0028, 0.0066), nail)
		end
	end

	-- Small fleshy flaps where a fish keeps its pectoral fins.
	b:pectoral(0.215, -0.03, 0.055, 0.024, flesh, 0.05)

	-- The paddle: a leaf-shaped fin wrapping the end of the tail, with rays.
	local paddle, ray = rgb(236, 198, 184), rgb(214, 168, 154)
	local function base(x: number): (number, number)
		if x < -0.462 then
			return -0.008, -0.008
		end
		return b:top(x) - 0.003, b:bottom(x) + 0.003
	end
	local tip = v2(-0.502, -0.008)
	for _, upper in { true, false } do
		local strip = {}
		for index = 0, 8 do
			local x = -0.27 - index * (0.2 / 8)
			local t = (-0.27 - x) / 0.232
			local height = 0.032 * math.sin(math.pi * t ^ 1.4) * (if upper then 1 else 0.82)
			local top, bottom = base(x)
			local rim = if upper then top + height else bottom - height
			table.insert(strip, { v2(x, if upper then top else bottom), v2(x, rim) })
		end
		for index = 1, #strip - 1 do
			local a, c = strip[index], strip[index + 1]
			b:fin({ a[1], a[2], c[2], c[1] }, paddle, 0.08)
			if index % 2 == 1 then
				b:limb(Vector3.new(a[1].X, a[1].Y, 0), Vector3.new(a[2].X - 0.006, a[2].Y, 0), 0.003, ray, "FinRay")
			end
		end
		local last = strip[#strip]
		b:fin({ last[1], last[2], tip }, paddle, 0.08)
	end

	-- Face: a small black eye in a pink lid, nostrils, a long thin smile with a
	-- pale lip and three faint gill slits behind the head.
	local eyeX, eyeY = 0.41, 0.012
	local function crease(points: { Vector2 }, width: number, color: Color3)
		for index = 1, #points - 1 do
			local a, c = points[index], points[index + 1]
			local delta = c - a
			local steps = math.max(1, math.ceil(delta.Magnitude / 0.011))
			for step = 0, steps - 1 do
				local point = a + delta * ((step + 0.5) / steps)
				b:marks(point.X, point.Y, delta.Magnitude / steps * 1.35, width, color, delta)
			end
		end
	end
	b:marks(eyeX, eyeY, 0.026, 0.02, blush)
	b:eye(eyeX, eyeY, 0.015, rgb(16, 12, 12))
	crease({ v2(0.434, 0.026), v2(0.41, 0.03), v2(0.39, 0.027) }, 0.003, fold)
	b:marks(0.485, -0.026, 0.0075, 0.0038, rgb(124, 70, 66), v2(1, 0.35))
	local smile = { v2(0.493, -0.044), v2(0.46, -0.054), v2(0.42, -0.056), v2(0.386, -0.052), v2(0.368, -0.044) }
	crease(smile, 0.0035, rgb(150, 82, 78))
	local lip = {}
	for index, point in smile do
		lip[index] = point + v2(0, 0.0045)
	end
	crease(lip, 0.0028, rgb(250, 224, 214))
	crease({ v2(0.47, -0.06), v2(0.43, -0.064), v2(0.395, -0.063) }, 0.0028, fold)
	for index = 0, 2 do
		local x = 0.336 - index * 0.012
		crease({ v2(x + 0.003, 0.016), v2(x - 0.002, -0.006), v2(x + 0.002, -0.028) }, 0.003, rgb(222, 170, 158))
	end
	crease({ v2(0.292, 0.036), v2(0.286, 0), v2(0.29, -0.04) }, 0.004, rgb(228, 174, 162))
	-- Throat and hip creases.
	for index = 0, 2 do
		local y = -0.038 - index * 0.004
		crease({ v2(0.318, y), v2(0.296, y - 0.003), v2(0.272, y - 0.002) }, 0.0024, fold)
	end
	for index = 0, 2 do
		local x = -0.075 - index * 0.012
		crease({ v2(x + 0.004, 0.028), v2(x - 0.004, -0.006), v2(x, -0.042) }, 0.0024, fold)
	end

	-- Bumps of the spine down the back.
	for index = 0, 20 do
		local x = 0.27 - index * 0.028
		local size = math.clamp(b:top(x) / 0.07, 0.3, 1)
		b:ellipsoid(
			"Vertebra",
			CFrame.new(x, b:top(x) - 0.003 * size, 0),
			Vector3.new(0.016, 0.008, 0.013) * size,
			colors.back:Lerp(rgb(160, 110, 100), 0.08)
		)
	end

	-- Soft, uneven blotches: each one a few overlapping skewed discs, faintly
	-- pinker or paler than the skin, plus a scatter of small rosy freckles.
	local function blotches(count: number, low: number, high: number, color: Color3)
		for _ = 1, count do
			local x, y = b.random(-0.3, 0.44), b.random(-0.06, 0.08)
			local size = b.random(low, high)
			for _ = 1, 2 do
				local px, py = x + b.random(-0.5, 0.5) * size, y + b.random(-0.35, 0.35) * size
				if py < b:top(px) - size * 0.35 and py > b:bottom(px) + size * 0.35 then
					local heading = v2(b.random(0.2, 1), b.random(-0.6, 0.6))
					b:marks(px, py, size * b.random(0.7, 1.15), size * b.random(0.4, 0.75), color, heading)
				end
			end
		end
	end
	blotches(11, 0.03, 0.06, rgb(237, 204, 190))
	blotches(7, 0.02, 0.04, rgb(245, 222, 209))
	blotches(8, 0.012, 0.024, rgb(232, 188, 174))
	b:speckle(18, v2(-0.26, 0.36), v2(-0.05, 0.07), v2(0.004, 0.008), blush)

	if p.hairy then
		local shades = { rgb(84, 62, 46), rgb(104, 78, 56), rgb(66, 48, 36), rgb(122, 94, 68), rgb(92, 70, 50) }
		local function shade(): Color3
			return shades[math.clamp(math.floor(b.random(1, #shades + 1)), 1, #shades)]
		end
		local function jitter(amount: number): Vector3
			return Vector3.new(b.random(-amount, amount), b.random(-amount, amount), b.random(-amount, amount))
		end
		-- A flat lock of hair rooted at `root`, lying along `direction` with
		-- its broad side against the skin (`normal`).
		local function lock(root: Vector3, direction: Vector3, normal: Vector3, length: number, width: number)
			local up = normal - direction * normal:Dot(direction)
			up = if up.Magnitude > 1e-4 then up.Unit else Vector3.yAxis
			local center = root + direction * length * 0.42 - up * 0.0015
			b:ellipsoid("Hair", CFrame.fromMatrix(center, direction, up), Vector3.new(length, 0.0045, width), shade())
		end
		local back, down = Vector3.new(-1, 0, 0), Vector3.new(0, -1, 0)
		local x = 0.37
		while x > -0.3 do
			local column = x + b.random(-0.004, 0.004)
			local top, bottom = b:top(column), b:bottom(column)
			local middle, half = (top + bottom) / 2, (top - bottom) / 2
			local head = column > 0.3
			local spacing = if head then 0.016 else 0.021
			local count = math.max(2, math.floor(math.pi * half * 1.15 / spacing))
			-- Short fuzz on the head, a thick shaggy coat over the body.
			local length = if head then 0.024 elseif column > 0.24 then 0.038 else 0.052
			local width = if head then 0.011 else 0.017
			for index = 0, count - 1 do
				local angle = math.pi * (0.05 + 0.92 * (index + b.random(0.15, 0.85)) / count)
				local y = middle + half * math.cos(angle) * 0.97
				local nearEye = (v2(column, y) - v2(eyeX, eyeY)).Magnitude < 0.024
				-- The face stays bare: fuzz only over the crown and behind the jaw.
				local bareFace = head and (column > 0.44 or angle > math.pi * 0.5)
				if not nearEye and not bareFace then
					for _, side in { 1, -1 } do
						local point, normal = b:surface(column, y, side)
						if point and normal then
							local direction = (normal * 0.3 + back * 0.9 + down * 0.25 + jitter(0.15)).Unit
							lock(point, direction, normal, length * b.random(0.8, 1.25), width * b.random(0.8, 1.2))
						end
					end
				end
			end
			x -= if head then 0.016 else 0.02
		end
		-- A long mane drooping along the spine.
		for index = 0, 24 do
			local column = 0.3 - index * 0.024
			local root = Vector3.new(column, b:top(column) - 0.004, b.random(-0.006, 0.006))
			local direction = (Vector3.new(-0.7, 0.45, 0) + jitter(0.2)).Unit
			local length = 0.055 * math.clamp(b:top(column) / 0.06, 0.45, 1.15)
			local bend = root + direction * length * 0.55
			local color = shade()
			b:limb(root, bend, 0.009, color, "Hair")
			b:limb(bend, bend + (direction + Vector3.new(-0.3, -0.75, 0)).Unit * length * 0.5, 0.007, color, "Hair")
		end
		-- Shaggy thighs and shins.
		for _, sample in legSamples do
			local along = sample.along
			local sideways = along:Cross(Vector3.yAxis)
			sideways = if sideways.Magnitude > 1e-4 then sideways.Unit else Vector3.zAxis
			local under = sideways:Cross(along).Unit
			for turn = 0, 2 do
				local angle = turn * 2.1 + b.random(-0.5, 0.5)
				local normal = (sideways * math.cos(angle) + under * math.sin(angle)).Unit
				local root = sample.point + normal * sample.radius * 0.8
				local direction = (normal * 0.35 + Vector3.new(-0.3, -0.8, 0) + jitter(0.2)).Unit
				lock(root, direction, normal, b.random(0.026, 0.038), b.random(0.011, 0.015))
			end
		end
	end
	b.model:SetAttribute("ViewDirection", Vector3.new(0.45, 0.3, 1))
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
	nescio = nescio,
}
for id, fish in FishSpecies do
	local build = fish.Build
	if build then
		builders[id] = function(b)
			build(b, kit)
			b:finishSkin()
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

-- A species' optional LengthScale: long-bodied fish (sturgeons, billfish...)
-- read far too small from weight alone, so they draw this much longer.
local function lengthScale(fishId: string?): number
	local species = fishId and FishSpecies[fishId]
	local scale = species and species.LengthScale
	return if type(scale) == "number" and scale > 0 then scale else 1
end
FishModels.lengthScale = lengthScale

-- Compact display size for the freezer and customer hands.
function FishModels.catchLength(kg: number, fishId: string?): number
	-- Crab weights cluster tightly, so a stronger curve makes their differences
	-- visible while still keeping even a record crab within the freezer.
	local exponent = if fishId and crabSpecies[fishId] then 0.65 else 1 / 3
	-- LengthScale goes in before the compression so it can't break the freezer cap.
	local size = math.max(kg, 0.01) ^ exponent * lengthScale(fishId)
	-- Smoothly compress record weights while retaining differences between
	-- catches. The longest side stays below the freezer's 3.54-stud ice depth.
	return 0.6 + 2.6 * size / (size + 0.75)
end

-- Held catches are sized by weight, regardless of their size label. Big and
-- Huge catches already weigh more, so an extra visual multiplier would make
-- the displayed weight inconsistent with the model.
function FishModels.heldLength(kg: number, size: string?, fishId: string?): number
	local weight = math.max(kg, 0.01)
	if fishId and crabSpecies[fishId] then
		return CRAB_HELD_BASE * weight ^ CRAB_HELD_EXPONENT
	end
	return 1.6 * weight ^ (1 / 3) * lengthScale(fishId)
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
