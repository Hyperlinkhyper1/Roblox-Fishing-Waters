-- A small working fisher, shared by the drydock display and owned boats.
-- The supplied frame is the waterline and local -Z points toward the bow.
-- Only the hull, deck, and wheelhouse walls collide; equipment stays decorative.

local FishingBoat = {}

local WHITE = Color3.fromRGB(224, 229, 215)
local CREAM = Color3.fromRGB(239, 222, 179)
local TEAL = Color3.fromRGB(47, 103, 96)
local DECK = Color3.fromRGB(98, 123, 109)
local DARK = Color3.fromRGB(38, 47, 43)
local ROOF = Color3.fromRGB(119, 65, 47)
local WOOD = Color3.fromRGB(145, 111, 73)
local ROPE = Color3.fromRGB(188, 171, 128)
local ORANGE = Color3.fromRGB(220, 109, 49)
local GLASS = Color3.fromRGB(103, 159, 169)
local METAL = Color3.fromRGB(145, 155, 146)
local THICKNESS = 0.18

function FishingBoat.build(frame: CFrame, anchored: boolean?): Model
	local isAnchored = anchored == true
	local model = Instance.new("Model")
	model.Name = "FishingBoat"
	model:SetAttribute("HullLength", 22)
	model:SetAttribute("HullBeam", 9.6)
	model:SetAttribute("PassengerSeats", 2)
	model:SetAttribute("DriverSeat", "HelmSeat")
	model:SetAttribute("DryFloorHeight", 1.1)
	model:SetAttribute("DryFloorHalfBeam", 4.2)
	model:SetAttribute("DryFloorHalfLength", 10.85)

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
	local function triangle(name: string, a: Vector3, b: Vector3, c: Vector3, inside: Vector3, color: Color3)
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
		finish(first, name, color, nil, true)
		local second = Instance.new("WedgePart")
		second.Size = Vector3.new(THICKNESS, height, math.abs(ac:Dot(back)))
		second.CFrame = frame * CFrame.fromMatrix((a + c) / 2 + shift, -right, up, -back)
		finish(second, name, color, nil, true)
	end

	local stations = {
		{ z = -10.85, width = 0.18, bottom = 0.12, top = 3.0, keel = -0.05 },
		{ z = -8.0, width = 3.3, bottom = 1.8, top = 2.55, keel = -1.3 },
		{ z = -3.5, width = 4.65, bottom = 3.95, top = 2.2, keel = -1.5 },
		{ z = 3.5, width = 4.65, bottom = 3.95, top = 2.2, keel = -1.5 },
		{ z = 8.5, width = 4.4, bottom = 4.1, top = 2.2, keel = -1.25 },
		{ z = 10.8, width = 3.65, bottom = 2.8, top = 2.3, keel = -0.95 },
	}
	local function hullPoint(station, side: number, level: number): Vector3
		local bottomY = if station.z < -10 then 0.25 else -0.72
		return Vector3.new(
			side * (station.bottom + (station.width - station.bottom) * level),
			bottomY + (station.top - bottomY) * level,
			station.z
		)
	end
	-- Each cross-section curves inward through the bilge to the center keel.
	-- These panels close the underside all the way from bow to transom.
	local function bottomPoint(station, side: number, level: number): Vector3
		if level == 0 then
			return hullPoint(station, side, 0)
		elseif level == 1 then
			local edge = hullPoint(station, side, 0)
			return Vector3.new(side * station.bottom * 0.52, station.keel + (edge.Y - station.keel) * 0.42, station.z)
		end
		return Vector3.new(0, station.keel, station.z)
	end
	for _, side in { -1, 1 } do
		for i = 1, #stations - 1 do
			local from, to = stations[i], stations[i + 1]
			for _, band in { { 0, 0.79, WHITE }, { 0.79, 1, TEAL } } do
				local a, b = hullPoint(from, side, band[1]), hullPoint(to, side, band[1])
				local c, d = hullPoint(to, side, band[2]), hullPoint(from, side, band[2])
				local inside = Vector3.new(0, 0.8, (from.z + to.z) / 2)
				triangle("HullPanel", a, b, c, inside, band[3])
				triangle("HullPanel", a, c, d, inside, band[3])
			end
			for band = 0, 1 do
				local a, b = bottomPoint(from, side, band), bottomPoint(to, side, band)
				local c, d = bottomPoint(to, side, band + 1), bottomPoint(from, side, band + 1)
				local inside = Vector3.new(0, 0.8, (from.z + to.z) / 2)
				local name = if band == 0 then "BilgePanel" else "BottomPanel"
				triangle(name, a, b, c, inside, WHITE)
				triangle(name, a, c, d, inside, WHITE)
			end
			beam("Gunwale", hullPoint(from, side, 1), hullPoint(to, side, 1), 0.3, 0.24, DARK)
		end
	end
	for _, station in { stations[1], stations[#stations] } do
		local center = Vector3.new(0, hullPoint(station, 1, 0).Y, station.z)
		local inside = Vector3.new(0, 0.8, 0)
		for _, side in { -1, 1 } do
			local edge, bilge, keel =
				bottomPoint(station, side, 0), bottomPoint(station, side, 1), bottomPoint(station, side, 2)
			triangle("HullEndCap", edge, bilge, keel, inside, WHITE)
			triangle("HullEndCap", edge, keel, center, inside, WHITE)
		end
		if station == stations[1] then
			local left, right = hullPoint(station, -1, 1), hullPoint(station, 1, 1)
			triangle("BowCap", center, left, right, inside, WHITE)
			triangle("BowCap", center, hullPoint(station, -1, 0), left, inside, WHITE)
			triangle("BowCap", center, right, hullPoint(station, 1, 0), inside, WHITE)
		end
	end
	local stern = stations[#stations]
	local sternLeft, sternRight = hullPoint(stern, -1, 0), hullPoint(stern, 1, 0)
	triangle("Transom", sternLeft, sternRight, hullPoint(stern, 1, 1), Vector3.new(0, 0.8, 0), WHITE)
	triangle("Transom", sternLeft, hullPoint(stern, 1, 1), hullPoint(stern, -1, 1), Vector3.new(0, 0.8, 0), WHITE)
	part("TransomTrim", Vector3.new(7.4, 0.5, 0.23), CFrame.new(0, 2.04, 10.8), TEAL)
	part("TransomCap", Vector3.new(7.5, 0.2, 0.3), CFrame.new(0, 2.3, 10.8), DARK)
	for index = 1, #stations - 1 do
		beam(
			"Keel",
			bottomPoint(stations[index], 1, 2),
			bottomPoint(stations[index + 1], 1, 2),
			0.18,
			0.16,
			TEAL,
			nil,
			true
		)
	end
	part("BowStem", Vector3.new(0.3, 2.85, 0.25), CFrame.new(0, 1.625, -10.85), WHITE)

	-- Continuous planks provide a working bow deck and two clear side walkways.
	local function deckWidth(station): number
		local bottomY = if station.z < -10 then 0.25 else -0.72
		local level = (1.1 - bottomY) / (station.top - bottomY)
		return math.max(0, station.bottom + (station.width - station.bottom) * level - 0.15)
	end
	for i = -7, 7 do
		local outside = (math.abs(i) + 0.5) * 0.55
		local startZ, endZ = stations[1].z, stations[#stations].z - 0.15
		for index = 1, #stations - 1 do
			local a, b = stations[index], stations[index + 1]
			local fromWidth, toWidth = deckWidth(a), deckWidth(b)
			if fromWidth < outside and toWidth >= outside then
				startZ = a.z + (b.z - a.z) * (outside - fromWidth) / (toWidth - fromWidth)
			elseif fromWidth >= outside and toWidth < outside then
				endZ = a.z + (b.z - a.z) * (outside - fromWidth) / (toWidth - fromWidth)
			end
		end
		part(
			"WorkingDeck",
			Vector3.new(0.55, 0.22, endZ - startZ),
			CFrame.new(i * 0.55, 0.99, (startZ + endZ) / 2),
			DECK,
			Enum.Material.Wood,
			true
		)
	end

	-- Cream wheelhouse near the stern. The 2.6-stud front opening reaches the
	-- same level deck without a doorstep; the helm controls do not obstruct it.
	-- Transparent SmoothPlastic keeps terrain water visible through the windows;
	-- refractive Glass hides water and other transparent effects behind it.
	part("CabinBackLower", Vector3.new(4.2, 2.35, 0.24), CFrame.new(0, 2.275, 7.8), CREAM, nil, true)
	part("CabinBackHeader", Vector3.new(4.2, 0.55, 0.24), CFrame.new(0, 6.525, 7.8), CREAM, nil, true)
	for _, side in { -1, 1 } do
		part("CabinSideLower", Vector3.new(0.24, 2.35, 4.8), CFrame.new(side * 1.98, 2.275, 5.4), CREAM, nil, true)
		part("CabinSideHeader", Vector3.new(0.24, 0.55, 4.8), CFrame.new(side * 1.98, 6.525, 5.4), CREAM, nil, true)
		part("CabinFrontJamb", Vector3.new(0.8, 2.35, 0.24), CFrame.new(side * 1.7, 2.275, 3.0), CREAM, nil, true)
		part("CabinFrontHeader", Vector3.new(0.8, 0.55, 0.24), CFrame.new(side * 1.7, 6.525, 3.0), CREAM, nil, true)
		local frontGlass = part(
			"CabinFrontWindow",
			Vector3.new(0.58, 2.55, 0.12),
			CFrame.new(side * 1.7, 4.825, 3.0),
			GLASS,
			Enum.Material.SmoothPlastic,
			true
		)
		frontGlass.Transparency = 0.28
		part("CabinCorner", Vector3.new(0.25, 2.85, 0.25), CFrame.new(side * 1.98, 4.825, 7.8), CREAM, nil, true)
		for _, z in { 4.2, 6.6 } do
			local glass = part(
				"CabinSideWindow",
				Vector3.new(0.12, 2.55, 2.12),
				CFrame.new(side * 1.98, 4.825, z),
				GLASS,
				Enum.Material.SmoothPlastic,
				true
			)
			glass.Transparency = 0.28
		end
		part("WindowMullion", Vector3.new(0.29, 2.85, 0.2), CFrame.new(side * 1.98, 4.825, 5.4), CREAM, nil, true)
		part("WindowSill", Vector3.new(0.36, 0.15, 4.95), CFrame.new(side * 1.98, 3.48, 5.4), TEAL)
		local rearGlass = part(
			"CabinRearWindow",
			Vector3.new(1.67, 2.55, 0.12),
			CFrame.new(side * 0.97, 4.825, 7.8),
			GLASS,
			Enum.Material.SmoothPlastic,
			true
		)
		rearGlass.Transparency = 0.28
	end
	part("CabinRearMullion", Vector3.new(0.2, 2.85, 0.26), CFrame.new(0, 4.825, 7.8), CREAM, nil, true)
	part("DoorHeader", Vector3.new(2.6, 0.2, 0.24), CFrame.new(0, 6.7, 3.0), CREAM, nil, true)
	part("CabinRoof", Vector3.new(4.85, 0.32, 5.65), CFrame.new(0, 6.96, 5.35), ROOF, nil, true)
	part("RoofEdge", Vector3.new(4.95, 0.12, 5.76), CFrame.new(0, 6.82, 5.35), DARK)
	part("RoofRidge", Vector3.new(0.14, 0.1, 5.45), CFrame.new(0, 7.16, 5.35), WOOD)
	for _, x in { -1.6, -0.8, 0.8, 1.6 } do
		part("RoofSeam", Vector3.new(0.035, 0.035, 5.45), CFrame.new(x, 7.135, 5.35), Color3.fromRGB(94, 51, 39))
	end

	part("HelmPedestal", Vector3.new(0.55, 0.8, 0.55), CFrame.new(0, 1.5, 5.9), DARK)
	part("HelmCushion", Vector3.new(1.85, 0.25, 1.3), CFrame.new(0, 1.99, 5.9), ROOF)
	part("HelmBack", Vector3.new(1.85, 1.25, 0.2), CFrame.new(0, 2.67, 6.5), ROOF)
	local helm = Instance.new("VehicleSeat")
	helm.Size = Vector3.new(1.85, 0.24, 1.3)
	helm.CFrame = frame * CFrame.new(0, 2.04, 5.9)
	helm.Transparency = 1
	helm.HeadsUpDisplay = false
	helm.MaxSpeed = 0
	helm.Torque = 0
	helm.TurnSpeed = 0
	finish(helm, "HelmSeat", ROOF, nil, false)
	helm.CanTouch = not isAnchored
	helm.Disabled = isAnchored
	part("HelmConsole", Vector3.new(1.5, 1.0, 0.75), CFrame.new(0, 2.1, 4.25), TEAL)
	part("ConsoleTop", Vector3.new(1.65, 0.13, 0.86), CFrame.new(0, 2.67, 4.25), WOOD)
	part("InstrumentPanel", Vector3.new(1.2, 0.3, 0.1), CFrame.new(0, 2.95, 4.6), DARK)
	for _, x in { -0.33, 0.33 } do
		local gauge = part(
			"HelmGauge",
			Vector3.new(0.05, 0.26, 0.26),
			CFrame.new(x, 2.95, 4.67) * CFrame.Angles(0, math.pi / 2, 0),
			CREAM
		)
		gauge.Shape = Enum.PartType.Cylinder
	end
	local wheelCenter = Vector3.new(0, 3.05, 4.85)
	for i = 0, 7 do
		local a, b = i * math.pi / 4, (i + 1) * math.pi / 4
		beam(
			"SteeringWheel",
			wheelCenter + Vector3.new(math.cos(a) * 0.48, math.sin(a) * 0.48, 0),
			wheelCenter + Vector3.new(math.cos(b) * 0.48, math.sin(b) * 0.48, 0),
			0.1,
			0.1,
			WOOD
		)
	end
	for i = 0, 2 do
		local angle = i * math.pi * 2 / 3
		beam(
			"WheelSpoke",
			wheelCenter,
			wheelCenter + Vector3.new(math.cos(angle) * 0.45, math.sin(angle) * 0.45, 0),
			0.07,
			0.07,
			METAL
		)
	end

	-- Two usable fishing seats leave a broad lane down the middle of the bow.
	for _, side in { -1, 1 } do
		part("FishingSeatPedestal", Vector3.new(0.35, 0.68, 0.35), CFrame.new(side * 2.35, 1.44, -1.5), DARK)
		part("FishingSeatCushion", Vector3.new(1.6, 0.22, 1.3), CFrame.new(side * 2.35, 1.86, -1.5), CREAM)
		part("FishingSeatBack", Vector3.new(1.6, 0.85, 0.17), CFrame.new(side * 2.35, 2.36, -0.88), TEAL)
		local passenger = Instance.new("Seat")
		passenger.Size = Vector3.new(1.6, 0.24, 1.3)
		passenger.CFrame = frame * CFrame.new(side * 2.35, 1.9, -1.5)
		passenger.Transparency = 1
		finish(passenger, "FishingSeat" .. (if side < 0 then "Port" else "Starboard"), CREAM, nil, false)
		passenger.CanTouch = not isAnchored
		passenger.Disabled = isAnchored
	end

	-- Hanging rubber fenders and their pale lashings give the working hull scale.
	for _, side in { -1, 1 } do
		for _, z in { -3.7, 1.2, 6.8 } do
			local x = side * (if z == 6.8 then 4.54 else 4.7)
			local fender = part("RubberFender", Vector3.new(0.4, 1.25, 1.25), CFrame.new(x, 1.22, z), DARK)
			fender.Shape = Enum.PartType.Cylinder
			local inset = part("FenderInset", Vector3.new(0.415, 0.54, 0.54), CFrame.new(x, 1.22, z), TEAL)
			inset.Shape = Enum.PartType.Cylinder
			beam("FenderRope", Vector3.new(x, 1.75, z), Vector3.new(x - side * 0.2, 2.35, z + 0.15), 0.055, 0.055, ROPE)
		end
	end

	-- Low-profile equipment sits against the sides, clear of the central route.
	for _, spec in { { -2.8, -5.65 }, { -2.65, -4.15 } } do
		local x, z = spec[1], spec[2]
		part("FishCrate", Vector3.new(1.5, 0.85, 1.2), CFrame.new(x, 1.54, z), WOOD, Enum.Material.Wood)
		part("CrateRim", Vector3.new(1.62, 0.12, 1.32), CFrame.new(x, 2.01, z), CREAM, Enum.Material.Wood)
		for _, dz in { -0.4, 0, 0.4 } do
			part("CrateSlat", Vector3.new(1.54, 0.06, 0.11), CFrame.new(x, 1.96, z + dz), DARK)
		end
	end
	local ropeCenter = Vector3.new(2.65, 1.24, -5.2)
	for ring = 0, 1 do
		local radius = 0.54 + ring * 0.15
		for i = 0, 9 do
			local a, b = i * math.pi / 5, (i + 1) * math.pi / 5
			beam(
				"CoiledRope",
				ropeCenter + Vector3.new(math.cos(a) * radius, ring * 0.06, math.sin(a) * radius),
				ropeCenter + Vector3.new(math.cos(b) * radius, ring * 0.06, math.sin(b) * radius),
				0.1,
				0.1,
				ROPE
			)
		end
	end
	for _, side in { -1, 1 } do
		part("BowCleat", Vector3.new(0.7, 0.12, 0.2), CFrame.new(side * 1.8, 2.5, -8.1), METAL)
		part("BowCleatFoot", Vector3.new(0.18, 0.25, 0.18), CFrame.new(side * 1.8, 2.35, -8.1), METAL)
		local a, b = Vector3.new(side * 3.8, 1.3, -3.0), Vector3.new(side * 4.25, 5.6, -5.7)
		beam("FishingRod", a, b, 0.055, 0.055, DARK)
		beam("RodGrip", a, a:Lerp(b, 0.18), 0.13, 0.13, WOOD)
		beam("FishingLine", b, Vector3.new(side * 4.15, 0.45, -6.0), 0.018, 0.018, ROPE)
	end
	for _, spec in { { 2.85, 8.7, ORANGE }, { 3.45, 8.4, CREAM }, { 3.0, 9.3, ORANGE } } do
		local buoy = part("FishingBuoy", Vector3.new(0.66, 0.95, 0.66), CFrame.new(spec[1], 1.62, spec[2]), spec[3])
		buoy.Shape = Enum.PartType.Ball
		part("BuoyHandle", Vector3.new(0.12, 0.23, 0.12), CFrame.new(spec[1], 2.18, spec[2]), DARK)
	end

	-- The wheelhouse roof, mast, boom, and safety ring establish the silhouette.
	part("Mast", Vector3.new(0.17, 5.4, 0.17), CFrame.new(0, 9.8, 4.4), WOOD)
	part("MastCrossbar", Vector3.new(4.6, 0.12, 0.12), CFrame.new(0, 11.25, 4.4), WOOD)
	beam("MastBoom", Vector3.new(0, 9.1, 4.4), Vector3.new(0, 8.0, -0.8), 0.13, 0.13, WOOD)
	for _, side in { -1, 1 } do
		beam("MastRigging", Vector3.new(0, 12.3, 4.4), Vector3.new(side * 3.65, 2.3, 8.8), 0.035, 0.035, ROPE)
	end
	beam("BoomRigging", Vector3.new(0, 11.6, 4.4), Vector3.new(0, 8.0, -0.8), 0.035, 0.035, ROPE)
	part("NavigationLamp", Vector3.new(0.23, 0.28, 0.23), CFrame.new(0, 12.6, 4.4), CREAM, Enum.Material.Neon)
	part("Vent", Vector3.new(0.42, 0.85, 0.42), CFrame.new(1.18, 7.52, 6.3), DARK, Enum.Material.Metal)
	part("VentCap", Vector3.new(0.63, 0.12, 0.63), CFrame.new(1.18, 8.0, 6.3), METAL, Enum.Material.Metal)
	local ringCenter = Vector3.new(0, 4.8, 8.0)
	for i = 0, 11 do
		local a, b = i * math.pi / 6, (i + 1) * math.pi / 6
		beam(
			"LifeRing",
			ringCenter + Vector3.new(math.cos(a) * 0.72, math.sin(a) * 0.72, 0),
			ringCenter + Vector3.new(math.cos(b) * 0.72, math.sin(b) * 0.72, 0),
			0.2,
			0.2,
			if i % 3 == 0 then CREAM else ORANGE
		)
	end

	-- A warm bow lantern keeps the working-boat look alongside electric lighting.
	local lanternBase = Vector3.new(0, 2.6, -8.5)
	local lanternColor = Color3.fromRGB(255, 218, 151)
	part("LanternStand", Vector3.new(0.16, 1.44, 0.16), CFrame.new(0, 1.82, -8.5), DARK, Enum.Material.Metal)
	part("LanternFoot", Vector3.new(0.52, 0.12, 0.52), CFrame.new(lanternBase), DARK, Enum.Material.Metal)
	local lantern = part(
		"LanternGlass",
		Vector3.new(0.36, 0.58, 0.36),
		CFrame.new(lanternBase + Vector3.new(0, 0.35, 0)),
		lanternColor,
		Enum.Material.Neon
	)
	part(
		"LanternCap",
		Vector3.new(0.52, 0.12, 0.52),
		CFrame.new(lanternBase + Vector3.new(0, 0.7, 0)),
		DARK,
		Enum.Material.Metal
	)
	for _, x in { -0.22, 0.22 } do
		part(
			"LanternFrame",
			Vector3.new(0.05, 0.6, 0.05),
			CFrame.new(lanternBase + Vector3.new(x, 0.35, 0)),
			DARK,
			Enum.Material.Metal
		)
	end
	part(
		"LanternHandle",
		Vector3.new(0.12, 0.24, 0.06),
		CFrame.new(lanternBase + Vector3.new(0, 0.88, 0)),
		DARK,
		Enum.Material.Metal
	)
	local lanternLight = Instance.new("PointLight")
	lanternLight.Name = "LanternLight"
	lanternLight.Color, lanternLight.Range, lanternLight.Brightness = lanternColor, 10, 0.6
	lanternLight.Shadows = false
	lanternLight.Parent = lantern

	local lampColor = Color3.fromRGB(255, 244, 219)
	local ceiling =
		part("CabinLight", Vector3.new(0.8, 0.12, 0.55), CFrame.new(0, 6.72, 5.4), lampColor, Enum.Material.Neon)
	local deckLight = Instance.new("PointLight")
	deckLight.Name = "DeckLight"
	deckLight.Color, deckLight.Range, deckLight.Brightness = lampColor, 18, 0.6
	deckLight.Shadows = false
	deckLight.Parent = ceiling
	-- Keep the lamps above the bow sides, with beams pointing along local -Z.
	for _, side in { -1, 1 } do
		part(
			"HeadlightStand",
			Vector3.new(0.16, 1.4, 0.16),
			CFrame.new(side * 1.15, 1.8, -8.7),
			DARK,
			Enum.Material.Metal
		)
		part(
			"HeadlightHousing",
			Vector3.new(0.7, 0.5, 0.55),
			CFrame.new(side * 1.15, 2.75, -8.7),
			DARK,
			Enum.Material.Metal
		)
		local lens = part(
			"HeadlightLens",
			Vector3.new(0.54, 0.34, 0.06),
			CFrame.new(side * 1.15, 2.75, -9.01),
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

return FishingBoat
