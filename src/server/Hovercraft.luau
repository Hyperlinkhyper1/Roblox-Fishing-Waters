-- Navy skirted hovercraft with a ducted stern fan. Waterline origin; local -Z is the bow.
-- The octagonal skirt, red deck rim and open cockpit form one welded, server-driven assembly.
local Hovercraft = {}
local NAVY = Color3.fromRGB(37, 52, 66)
local STRIPE = Color3.fromRGB(96, 112, 124)
local RED = Color3.fromRGB(122, 34, 44)
local LIGHT = Color3.fromRGB(196, 199, 202)
local GRAY = Color3.fromRGB(134, 139, 144)
local FLOOR = Color3.fromRGB(46, 49, 54)
local SEAT = Color3.fromRGB(28, 29, 33)
local BLADE = Color3.fromRGB(30, 40, 52)
local THICKNESS = 0.18

function Hovercraft.build(frame: CFrame, anchored: boolean?): Model
	local isAnchored = anchored == true
	local model = Instance.new("Model")
	model.Name = "Hovercraft"
	model:SetAttribute("HullLength", 22)
	model:SetAttribute("HullBeam", 10.4)
	model:SetAttribute("PassengerSeats", 2)
	model:SetAttribute("DriverSeat", "HelmSeat")
	model:SetAttribute("DryFloorHeight", 1.1)
	model:SetAttribute("DryFloorHalfBeam", 2.9)
	model:SetAttribute("DryFloorHalfLength", 8.7)

	local root = Instance.new("Part")
	root.Name = "HullRoot"
	root.Size = Vector3.new(5.6, 0.5, 14)
	root.CFrame = frame * CFrame.new(0, -0.4, 0)
	root.Transparency = 1
	root.Anchored = isAnchored
	root.CanCollide = false
	root.CanTouch = false
	root.RootPriority = 127
	root.CustomPhysicalProperties = PhysicalProperties.new(1.4, 0.45, 0.05, 100, 100)
	root.Parent = model
	model.PrimaryPart = root

	local function finish(p: BasePart, name: string, color: Color3, material: Enum.Material?, collide: boolean?)
		p.Name = name
		p.Anchored = isAnchored
		p.CanCollide = collide == true
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Massless = true
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
		return p
	end

	local function part(
		name: string,
		size: Vector3,
		localFrame: CFrame,
		color: Color3,
		material: Enum.Material?,
		collide: boolean?
	): Part
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = frame * localFrame
		finish(p, name, color, material, collide)
		return p
	end

	local function beam(
		name: string,
		a: Vector3,
		b: Vector3,
		width: number,
		depth: number,
		color: Color3,
		material: Enum.Material?,
		collide: boolean?
	): Part
		return part(
			name,
			Vector3.new(width, depth, (b - a).Magnitude),
			CFrame.lookAt((a + b) / 2, b),
			color,
			material,
			collide
		)
	end

	-- Thin facets form an open hull; there is no solid collision box through it.
	local function triangle(
		name: string,
		a: Vector3,
		b: Vector3,
		c: Vector3,
		inside: Vector3,
		color: Color3,
		material: Enum.Material?
	)
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
		local shift = -normal * THICKNESS / 2
		local first = Instance.new("WedgePart")
		first.Size = Vector3.new(THICKNESS, height, math.abs(ab:Dot(back)))
		first.CFrame = frame * CFrame.fromMatrix((a + b) / 2 + shift, right, up, back)
		finish(first, name, color, material, true)
		local second = Instance.new("WedgePart")
		second.Size = Vector3.new(THICKNESS, height, math.abs(ac:Dot(back)))
		second.CFrame = frame * CFrame.fromMatrix((a + c) / 2 + shift, -right, up, -back)
		finish(second, name, color, material, true)
	end

	-- Plan outline: a long chamfered bow and short stern corners, shrunk by inset.
	local function outline(inset: number, y: number): { Vector3 }
		local halfLength, halfBeam = 11 - inset, 5.2 - inset
		return {
			Vector3.new(-(halfBeam - 2.4), y, -halfLength),
			Vector3.new(halfBeam - 2.4, y, -halfLength),
			Vector3.new(halfBeam, y, -halfLength + 3.6),
			Vector3.new(halfBeam, y, halfLength - 1.4),
			Vector3.new(halfBeam - 1.4, y, halfLength),
			Vector3.new(-(halfBeam - 1.4), y, halfLength),
			Vector3.new(-halfBeam, y, halfLength - 1.4),
			Vector3.new(-halfBeam, y, -halfLength + 3.6),
		}
	end
	local function band(
		name: string,
		lower: { Vector3 },
		upper: { Vector3 },
		color: Color3,
		inside: Vector3,
		material: Enum.Material?
	)
		for index = 1, #lower do
			local nextIndex = index % #lower + 1
			local a, b = lower[index], lower[nextIndex]
			local c, d = upper[nextIndex], upper[index]
			triangle(name, a, b, c, inside, color, material)
			triangle(name, a, c, d, inside, color, material)
		end
	end

	-- The inflated skirt bulges out at its pale rub stripe and tucks under to a flat base.
	local rings = {
		outline(0.9, -0.6),
		outline(0.15, 0.3),
		outline(0, 1.05),
		outline(0.3, 1.9),
		outline(1.0, 2.3),
	}
	local skirtCenter = Vector3.new(0, 0.9, 0)
	band("HullPanel", rings[1], rings[2], NAVY, skirtCenter)
	band("HullPanel", rings[2], rings[3], STRIPE, skirtCenter)
	band("HullPanel", rings[3], rings[4], NAVY, skirtCenter)
	band("HullPanel", rings[4], rings[5], NAVY, skirtCenter)
	local base = Vector3.new(0, -0.6, 0)
	for index, point in rings[1] do
		triangle("BottomPanel", base, point, rings[1][index % #rings[1] + 1], Vector3.new(0, 1, 0), NAVY)
	end

	-- Red rim around the deck, then pale inner walls down to the diamond-plate floor.
	local rimInner = outline(1.7, 2.45)
	band("DeckRim", rings[5], rimInner, RED, Vector3.new(0, -2, 0))
	local floorEdge = outline(2.3, 1.1)
	band("InnerWall", rimInner, floorEdge, LIGHT, Vector3.new(0, 4, 0))
	local floorCenter = Vector3.new(0, 1.1, 0)
	for index, point in floorEdge do
		triangle(
			"WorkingDeck",
			floorCenter,
			point,
			floorEdge[index % #floorEdge + 1],
			Vector3.new(0, -1, 0),
			FLOOR,
			Enum.Material.DiamondPlate
		)
	end

	-- Raised engine deck and side lockers carry the fan above the open cockpit.
	part("EngineDeck", Vector3.new(5.6, 1.1, 3.0), CFrame.new(0, 1.65, 7.1), LIGHT, nil, true)
	local ramp = Instance.new("WedgePart")
	ramp.Size = Vector3.new(5.6, 1.1, 1.0)
	ramp.CFrame = frame * CFrame.new(0, 1.65, 5.1)
	finish(ramp, "EngineDeckRamp", LIGHT, nil, true)
	for _, side in { -1, 1 } do
		part("SideLocker", Vector3.new(1.0, 0.8, 3.4), CFrame.new(side * 2.4, 1.5, 3.4), LIGHT, nil, true)
		part("SideLockerLid", Vector3.new(1.05, 0.08, 3.45), CFrame.new(side * 2.4, 1.94, 3.4), GRAY)
	end

	-- Ducted fan: a sixteen-segment shroud, three pitched blades and twin rudder vanes.
	local fanCenter = Vector3.new(0, 5.55, 7.6)
	local radius = 3.1
	local segments = 16
	for index = 0, segments - 1 do
		local angle = (index + 0.5) * math.pi * 2 / segments
		local offset = Vector3.new(math.cos(angle), math.sin(angle), 0) * radius
		part(
			"FanShroud",
			Vector3.new(0.45, 2 * radius * math.tan(math.pi / segments) + 0.08, 1.4),
			CFrame.new(fanCenter + offset) * CFrame.Angles(0, 0, angle),
			GRAY,
			nil,
			true
		)
	end
	local hub =
		part("FanHub", Vector3.new(0.9, 0.85, 0.85), CFrame.new(fanCenter) * CFrame.Angles(0, math.pi / 2, 0), GRAY)
	hub.Shape = Enum.PartType.Cylinder
	for index = 0, 2 do
		local angle = index * math.pi * 2 / 3 + math.pi / 2
		local direction = Vector3.new(math.cos(angle), math.sin(angle), 0)
		part(
			"FanBlade",
			Vector3.new(0.55, 2.4, 0.1),
			CFrame.new(fanCenter + direction * 1.55)
				* CFrame.Angles(0, 0, angle - math.pi / 2)
				* CFrame.Angles(0, 0.4, 0),
			BLADE
		)
	end
	part("FanMount", Vector3.new(1.8, 0.35, 1.4), CFrame.new(0, 2.35, 7.6), GRAY)
	for _, side in { -1, 1 } do
		part("FanStrut", Vector3.new(0.35, 1.6, 0.35), CFrame.new(side * 2.6, 2.95, 7.6), GRAY)
		part("RudderVane", Vector3.new(0.12, 5.0, 0.9), CFrame.new(side * 1.2, 4.7, 8.85), GRAY)
	end
	beam("RudderBar", Vector3.new(-1.2, 2.8, 8.85), Vector3.new(1.2, 2.8, 8.85), 0.14, 0.14, GRAY)

	-- Three bucket seats abreast: the driver in the middle behind a small dash.
	local function bucket(name: string, x: number, z: number, driver: boolean)
		part(name .. "Base", Vector3.new(1.5, 0.5, 1.5), CFrame.new(x, 1.45, z), SEAT)
		part(name .. "Back", Vector3.new(1.5, 1.5, 0.3), CFrame.new(x, 2.3, z + 0.65), SEAT)
		part(name .. "Accent", Vector3.new(1.3, 0.5, 0.06), CFrame.new(x, 2.75, z + 0.48), RED)
		local seat = Instance.new(if driver then "VehicleSeat" else "Seat") :: Seat | VehicleSeat
		seat.Size = Vector3.new(1.5, 0.24, 1.5)
		seat.CFrame = frame * CFrame.new(x, 1.75, z)
		seat.Transparency = 1
		if seat:IsA("VehicleSeat") then
			seat.HeadsUpDisplay = false
			seat.MaxSpeed, seat.Torque, seat.TurnSpeed = 0, 0, 0
		end
		finish(seat, name, SEAT)
		seat.CanTouch = not isAnchored
		seat.Disabled = isAnchored
	end
	bucket("HelmSeat", 0, -0.6, true)
	bucket("PassengerSeatPort", -1.9, 0.2, false)
	bucket("PassengerSeatStarboard", 1.9, 0.2, false)
	part("Dash", Vector3.new(2.0, 0.9, 0.6), CFrame.new(0, 1.55, -2.6), GRAY)
	part("DashPanel", Vector3.new(1.7, 0.3, 0.08), CFrame.new(0, 1.85, -2.27), FLOOR)
	beam("Handlebar", Vector3.new(-0.7, 2.25, -2.15), Vector3.new(0.7, 2.25, -2.15), 0.12, 0.12, SEAT)
	part("HandlebarStem", Vector3.new(0.14, 0.4, 0.14), CFrame.new(0, 2.05, -2.25), SEAT)

	-- Twin bow lamps sit on the rim and light the way ahead.
	local lampColor = Color3.fromRGB(239, 247, 255)
	for _, side in { -1, 1 } do
		part(
			"HeadlightHousing",
			Vector3.new(0.7, 0.36, 0.5),
			CFrame.new(side * 1.5, 2.6, -9.75),
			SEAT,
			Enum.Material.Metal
		)
		local lens = part(
			"HeadlightLens",
			Vector3.new(0.54, 0.24, 0.06),
			CFrame.new(side * 1.5, 2.6, -10.03),
			lampColor,
			Enum.Material.Neon
		)
		lens.CastShadow = false
		local headlight = Instance.new("SpotLight")
		headlight.Name = "Headlight"
		headlight.Face = Enum.NormalId.Front
		headlight.Color, headlight.Range, headlight.Brightness, headlight.Angle = lampColor, 45, 1.2, 65
		headlight.Shadows = false
		headlight.Parent = lens
	end
	return model
end

return Hovercraft
