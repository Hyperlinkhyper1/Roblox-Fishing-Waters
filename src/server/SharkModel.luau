-- The attack shark. Its real skin is a smooth triangle mesh (Shared.SharkShape)
-- that each client builds with EditableMesh (client SharkMeshes), because
-- EditableMesh never replicates. The server builds a stand-in body from mesh
-- ellipsoids and wedge fins, tagged SharkFallback, which clients replace with
-- the skin and which stays visible wherever meshes are unavailable. Eyes, gills,
-- mouth and teeth sit on the skin's surface and are always shown.
-- Model space: the snout points -Z, +Y is up and the origin sits on the water
-- surface, so the dorsal fin and the upper tail lobe cut through the waves.
-- Pieces are designed in SharkShape's design units and built SCALE times larger.
-- Every visible piece stores its SwimOffset and its SwimSegment (SharkShape
-- joints, 0 = head), which client SharkSwim bends in turn.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharkShape = require(ReplicatedStorage:WaitForChild("Shared").SharkShape)

local SharkModel = {}

local FIN = 0.12
local rgb = Color3.fromRGB
local function palette(name: string): Color3
	local c = SharkShape.COLORS[name]
	return rgb(c[1], c[2], c[3])
end
local BACK, SIDE, BELLY = palette("Back"), palette("Line"), palette("Belly")
local FIN_COLOR, GILL = BACK, rgb(36, 43, 49)
local MOUTH, TOOTH, EYE = rgb(70, 26, 32), rgb(244, 241, 230), rgb(8, 9, 11)

-- Stand-in body: long overlapping ellipsoid sections from snout to tail stalk
-- (centre and size as width, height, length), roughly following SharkShape's
-- profile.
local SECTIONS = {
	{ "Snout", Vector3.new(0, -1.2, -4.4), Vector3.new(1.3, 1.1, 2.6) },
	{ "Head", Vector3.new(0, -1.28, -3.1), Vector3.new(2.1, 1.8, 4) },
	{ "Body", Vector3.new(0, -1.42, -0.95), Vector3.new(3, 2.6, 6.9) },
	{ "RearBody", Vector3.new(0, -1.38, 2.1), Vector3.new(1.7, 1.55, 4) },
	{ "TailStalk", Vector3.new(0, -1.33, 4.05), Vector3.new(0.7, 0.82, 2.3) },
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

	local fallback = false
	local scale = SharkShape.SCALE

	local function piece(class: string, name: string, size: Vector3, offset: CFrame, color: Color3): BasePart
		local item = Instance.new(class) :: BasePart
		item.Name = name
		-- Scale the design-unit placement into studs, keeping its rotation.
		offset = CFrame.new(offset.Position * scale) * offset.Rotation
		item.Size = size * scale
		item.CFrame = offset
		item.Color = color
		item.Material = Enum.Material.SmoothPlastic
		item.TopSurface, item.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = true, false, false, false
		item:SetAttribute("SwimOffset", offset)
		item:SetAttribute("SwimSegment", SharkShape.segmentAt(offset.Position.Z / scale))
		if fallback then
			item:SetAttribute("SharkFallback", true)
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
			ellipsoid(layer[1], CFrame.new(layer[2]), layer[3], layer[4])
		end
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

	fallback = true
	for _, section in SECTIONS do
		layered(section[1], section[2], section[3])
	end
	for _, side in { -1, 1 } do
		-- Long swept pectoral fins, angled down and back from the lower flank.
		fin((if side < 0 then "Left" else "Right") .. "PectoralFin", {
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
	ellipsoid("CaudalKeel", CFrame.new(0, -1.33, 4.3), Vector3.new(0.88, 0.14, 1.9), BACK)
	fin("Tail", {
		Vector3.new(0, -1.33, 4.4),
		Vector3.new(0, -0.95, 4.55),
		Vector3.new(0, 1.25, 6.35),
		Vector3.new(0, 0.05, 5.55),
		Vector3.new(0, -1.3, 5.2),
		Vector3.new(0, -3.15, 5.95),
		Vector3.new(0, -1.7, 4.6),
	}, FIN_COLOR)

	-- The stand-in mouth; the skin has its own hinged jaw and teeth.
	-- Underslung mouth: a dark gape set into the underside, pitched to follow
	-- it, with the pale lower jaw bulging just behind so only a crescent of
	-- gape shows at the front.
	local pitch = math.atan((SharkShape.bottomY(-3.9) - SharkShape.bottomY(-3.0)) / 0.9)
	local mouthZ = -3.5
	ellipsoid(
		"Mouth",
		CFrame.new(0, SharkShape.bottomY(mouthZ) + 0.06, mouthZ) * CFrame.Angles(pitch, 0, 0),
		Vector3.new(1.5, 0.22, 1.25),
		MOUTH
	)
	ellipsoid(
		"LowerJaw",
		CFrame.new(0, SharkShape.bottomY(-3.18) + 0.05, -3.18) * CFrame.Angles(pitch, 0, 0),
		Vector3.new(1.38, 0.26, 1.25),
		BELLY
	)
	-- Teeth hang from the front edge of the gape on an elliptical arc
	-- (half-widths rx across, rz along the body).
	for index = -3, 3 do
		local angle = index * 0.34
		local x, z = math.sin(angle) * 0.6, mouthZ - 0.12 - math.cos(angle) * 0.44
		local length = 0.17 - math.abs(index) * 0.018
		local base = SharkShape.undersideY(z, x) + 0.03
		local outward = Vector3.new(math.sin(angle) * 0.44, 0, -math.cos(angle) * 0.6).Unit
		piece(
			"WedgePart",
			"Tooth",
			Vector3.new(0.04, length, 0.1),
			CFrame.fromMatrix(Vector3.new(x, base - length / 2, z), outward, Vector3.new(0, 1, 0))
				* CFrame.Angles(math.pi, 0, 0),
			TOOTH
		)
	end
	-- Details on the skin's surface, shown with either body.
	fallback = false
	for _, side in { -1, 1 } do
		local label = if side < 0 then "Left" else "Right"
		-- Small, flat black eyes set well forward, just above the mouth line.
		local eyeZ = -3.6
		local _, _, _, eyeAxis = SharkShape.section(eyeZ)
		local eyeY = eyeAxis + 0.18
		ellipsoid(
			label .. "Eye",
			CFrame.new(side * (SharkShape.surfaceX(eyeZ, eyeY) - 0.025), eyeY, eyeZ),
			Vector3.new(0.12, 0.22, 0.25),
			EYE
		)
		-- Five gill slits, raked back and shortening towards the pectoral fin.
		for index = 0, 4 do
			local z = -2.5 + index * 0.25
			local _, _, _, axis = SharkShape.section(z)
			local y = axis - 0.12
			ellipsoid(
				label .. "Gill" .. index + 1,
				CFrame.new(side * (SharkShape.surfaceX(z, y) - 0.035), y, z) * CFrame.Angles(0.18, 0, 0),
				Vector3.new(0.09, 1.1 - index * 0.07, 0.065),
				GILL
			)
		end
	end

	model:PivotTo(frame)
	model.Parent = parent
	return model
end

return SharkModel
