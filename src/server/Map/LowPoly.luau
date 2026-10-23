-- Flat-shaded geometry built from WedgeParts. Every triangle is two wedges,
-- which is what gives the map its faceted, Dredge-like look.

local LowPoly = {}

local THICKNESS = 0.6

local function wedge(color: Color3, material: Enum.Material): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.CanTouch = false
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Material = material
	w.Color = color
	return w
end

-- `inside` is any point behind the face; the wedges' thickness is pushed toward it
-- so the visible surface sits exactly on the triangle.
function LowPoly.triangle(
	a: Vector3,
	b: Vector3,
	c: Vector3,
	inside: Vector3,
	color: Color3,
	parent: Instance,
	material: Enum.Material?,
	thickness: number?
)
	if (b - a):Cross(c - a).Magnitude < 0.01 then
		return
	end

	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b

	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))

	local normal = if right:Dot((a + b + c) / 3 - inside) >= 0 then right else -right
	local depth = thickness or THICKNESS
	local shift = -normal * (depth / 2)
	local mat = material or Enum.Material.SmoothPlastic

	local w1 = wedge(color, mat)
	w1.Size = Vector3.new(depth, height, math.abs(ab:Dot(back)))
	w1.CFrame = CFrame.fromMatrix((a + b) / 2 + shift, right, up, back)
	w1.Parent = parent

	local w2 = wedge(color, mat)
	w2.Size = Vector3.new(depth, height, math.abs(ac:Dot(back)))
	w2.CFrame = CFrame.fromMatrix((a + c) / 2 + shift, -right, up, -back)
	w2.Parent = parent
end

-- Open-bottomed pyramid over a ring of base points (in order around the ring).
function LowPoly.pyramid(
	base: { Vector3 },
	apex: Vector3,
	color: Color3,
	parent: Instance,
	material: Enum.Material?,
	inside: Vector3?
)
	local centroid = Vector3.zero
	for _, p in base do
		centroid += p
	end
	centroid /= #base
	local core = inside or centroid:Lerp(apex, 0.3)
	for i = 1, #base do
		LowPoly.triangle(base[i], base[i % #base + 1], apex, core, color, parent, material)
	end
end

-- Faceted rock: two pyramids sharing a jittered ring.
function LowPoly.boulder(
	center: Vector3,
	radius: number,
	rng: Random,
	color: Color3,
	parent: Instance,
	material: Enum.Material?
)
	local ring = {}
	local sides = rng:NextInteger(5, 6)
	for i = 1, sides do
		local a = (i + rng:NextNumber(-0.25, 0.25)) / sides * math.pi * 2
		local r = radius * rng:NextNumber(0.8, 1.15)
		ring[i] = center + Vector3.new(math.cos(a) * r, rng:NextNumber(-0.25, 0.25) * radius, math.sin(a) * r)
	end
	local top = center
		+ Vector3.new(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0.7, 1.1), rng:NextNumber(-0.3, 0.3)) * radius
	local bottom = center - Vector3.new(0, radius * 0.7, 0)
	LowPoly.pyramid(ring, top, color, parent, material, center)
	LowPoly.pyramid(ring, bottom, color, parent, material, center)
end

return LowPoly
