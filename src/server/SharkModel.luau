-- The attack shark, built from mesh ellipsoids and wedge-pair triangle fins like
-- FishModels: a Ball part is always a sphere, so it cannot give a torpedo body.
-- Model space: the snout points -Z, +Y is up and the origin sits on the water
-- surface, so the dorsal fin and the upper tail lobe cut through the waves.
-- Every visible piece stores its SwimOffset. SwimFlex pieces bend at z = 1.6
-- and SwimTail pieces bend there and again at z = 3.2 (client SharkSwim pivots).
local SharkModel = {}

local FIN = 0.12
local rgb = Color3.fromRGB
local BACK, SIDE, BELLY = rgb(66, 80, 88), rgb(101, 117, 124), rgb(224, 226, 219)
local FIN_COLOR, GILL = rgb(74, 89, 97), rgb(46, 56, 61)
local MOUTH, TOOTH, EYE = rgb(58, 28, 32), rgb(240, 237, 224), rgb(12, 14, 16)

-- Long overlapping body sections from snout to tail stalk: centre, size
-- (width, height, length) and the swim segment that carries them. Each one
-- takes over the outline near a swim joint, so the body narrows smoothly
-- instead of pinching between bulges.
local SECTIONS = {
	{ "Snout", Vector3.new(0, -1.34, -3.95), Vector3.new(1.75, 1.3, 3.7) },
	{ "Body", Vector3.new(0, -1.4, -1.1), Vector3.new(3, 2.45, 6.8) },
	{ "RearBody", Vector3.new(0, -1.37, 2), Vector3.new(1.85, 1.6, 4.6), "SwimFlex" },
	{ "TailStalk", Vector3.new(0, -1.33, 4), Vector3.new(0.8, 0.9, 2.6), "SwimTail" },
}

function SharkModel.build(parent: Instance, frame: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Shark"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.Anchored, root.CanCollide, root.CanTouch, root.CanQuery = true, false, false, false
	root.Parent = model
	model.PrimaryPart = root

	local segment: string? = nil
	local hull: { { c: Vector3, h: Vector3 } } = {}

	local function piece(class: string, name: string, size: Vector3, offset: CFrame, color: Color3): BasePart
		local item = Instance.new(class) :: BasePart
		item.Name = name
		item.Size = size
		item.CFrame = offset
		item.Color = color
		item.Material = Enum.Material.SmoothPlastic
		item.TopSurface, item.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = true, false, false, false
		item:SetAttribute("SwimOffset", offset)
		if segment then
			item:SetAttribute(segment, true)
		end
		item.Parent = model
		return item
	end

	local function ellipsoid(name: string, offset: CFrame, size: Vector3, color: Color3): BasePart
		local item = piece("Part", name, size, offset, color)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = item
		return item
	end

	-- Grey flank with a darker back above and a white belly below.
	local function layered(name: string, center: Vector3, size: Vector3)
		local back, belly = Vector3.new(0, size.Y * 0.12, 0), Vector3.new(0, size.Y * 0.15, 0)
		local layers = {
			{ name, center, size, SIDE },
			{ name .. "Back", center + back, size * Vector3.new(0.97, 0.86, 1), BACK },
			{ name .. "Belly", center - belly, size * Vector3.new(0.95, 0.78, 0.99), BELLY },
		}
		for _, layer in layers do
			table.insert(hull, { c = layer[2], h = layer[3] / 2 })
			ellipsoid(layer[1], CFrame.new(layer[2]), layer[3], layer[4])
		end
	end

	-- Half-width of the body surface at height y and length z.
	local function surfaceX(y: number, z: number): number
		local best = 0
		for _, section in hull do
			local dy, dz = (y - section.c.Y) / section.h.Y, (z - section.c.Z) / section.h.Z
			local remaining = 1 - dy * dy - dz * dz
			if remaining > 0 then
				best = math.max(best, section.h.X * math.sqrt(remaining))
			end
		end
		return best
	end

	-- Two wedges split at the foot of the longest edge's altitude.
	local function triangle(name: string, a: Vector3, b: Vector3, c: Vector3, color: Color3, thickness: number)
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
		piece(
			"WedgePart",
			name,
			Vector3.new(thickness, height, math.abs(ab:Dot(back))),
			CFrame.fromMatrix((a + b) / 2, right, up, back),
			color
		)
		piece(
			"WedgePart",
			name,
			Vector3.new(thickness, height, math.abs(ac:Dot(back))),
			CFrame.fromMatrix((a + c) / 2, -right, up, -back),
			color
		)
	end

	-- Fan triangulation from the first point.
	local function fin(name: string, points: { Vector3 }, color: Color3, thickness: number?)
		for index = 2, #points - 1 do
			triangle(name, points[1], points[index], points[index + 1], color, thickness or FIN)
		end
	end

	for _, section in SECTIONS do
		segment = section[4]
		layered(section[1], section[2], section[3])
	end

	segment = nil
	-- Underslung mouth with a row of teeth along the front of the upper jaw.
	ellipsoid("Mouth", CFrame.new(0, -2.08, -3.5), Vector3.new(1.7, 0.22, 1.15), MOUTH)
	ellipsoid("LowerJaw", CFrame.new(0, -2.25, -3.2), Vector3.new(1.5, 0.28, 1.4), BELLY)
	for _, angle in { -0.75, -0.25, 0.25, 0.75 } do
		local center = Vector3.new(math.sin(angle) * 0.78, -2.06, -3.5 - math.cos(angle) * 0.52)
		local along = Vector3.new(math.cos(angle) * 0.78, 0, math.sin(angle) * 0.52).Unit * 0.08
		fin("Tooth", { center - along, center + along, center + Vector3.new(0, -0.24, 0) }, TOOTH, 0.04)
	end
	for _, side in { -1, 1 } do
		local label = if side < 0 then "Left" else "Right"
		ellipsoid(
			label .. "Eye",
			CFrame.new(side * (surfaceX(-1.12, -3.4) - 0.05), -1.12, -3.4),
			Vector3.new(0.16, 0.27, 0.29),
			EYE
		)
		for index = 0, 4 do
			local z = -2.25 + index * 0.25
			ellipsoid(
				label .. "Gill" .. index + 1,
				CFrame.new(side * (surfaceX(-1.5, z) - 0.03), -1.5, z) * CFrame.Angles(0.12, 0, 0),
				Vector3.new(0.1, 0.95 - index * 0.05, 0.07),
				GILL
			)
		end
		-- Long swept pectoral fins, angled down and back from the lower flank.
		fin(label .. "PectoralFin", {
			Vector3.new(side * 1.2, -1.85, -2.05),
			Vector3.new(side * 2.4, -2.2, -1.2),
			Vector3.new(side * 3.55, -2.75, 0.35),
			Vector3.new(side * 2.45, -2.45, -0.25),
			Vector3.new(side * 1.15, -2.15, -0.95),
		}, FIN_COLOR)
	end
	-- Tall dorsal fin with a concave trailing edge and a free rear tip.
	fin("DorsalFin", {
		Vector3.new(0, -0.35, 0.1),
		Vector3.new(0, -0.3, -1.05),
		Vector3.new(0, 0.75, -0.25),
		Vector3.new(0, 1.55, 0.75),
		Vector3.new(0, 0.45, 0.92),
		Vector3.new(0, -0.15, 1.35),
	}, FIN_COLOR)

	segment = "SwimFlex"
	fin(
		"RearDorsalFin",
		{ Vector3.new(0, -0.8, 2.4), Vector3.new(0, -0.2, 2.85), Vector3.new(0, -0.75, 3.1) },
		FIN_COLOR
	)
	fin("AnalFin", { Vector3.new(0, -1.95, 2.5), Vector3.new(0, -2.5, 3), Vector3.new(0, -1.95, 3.15) }, FIN_COLOR)
	for _, side in { -1, 1 } do
		fin((if side < 0 then "Left" else "Right") .. "PelvicFin", {
			Vector3.new(side * 0.5, -1.95, 1.75),
			Vector3.new(side * 1.35, -2.45, 2.75),
			Vector3.new(side * 0.45, -2.1, 2.45),
		}, FIN_COLOR)
	end

	segment = "SwimTail"
	-- Near-crescent tail: the upper lobe is a little longer than the lower one.
	ellipsoid("CaudalKeel", CFrame.new(0, -1.33, 4.2), Vector3.new(1.05, 0.16, 1.7), BACK)
	fin("Tail", {
		Vector3.new(0, -1.33, 4.4),
		Vector3.new(0, -0.95, 4.55),
		Vector3.new(0, 1.25, 6.35),
		Vector3.new(0, 0.05, 5.55),
		Vector3.new(0, -1.3, 5.2),
		Vector3.new(0, -3.15, 5.95),
		Vector3.new(0, -1.7, 4.6),
	}, FIN_COLOR)

	model:PivotTo(frame)
	model.Parent = parent
	return model
end

return SharkModel
