-- Gray coastal patrol cruiser inspired by a long-bow, rear-wheelhouse launch.
-- Waterline origin; local -Z is the bow.
-- The faceted V hull and cockpit sole form one welded, server-driven assembly.
local PatrolBoat = {}
local LIGHT_GRAY = Color3.fromRGB(182, 185, 188)
local HULL_GRAY = Color3.fromRGB(94, 98, 103)
local DECK = Color3.fromRGB(121, 125, 129)
local DARK = Color3.fromRGB(43, 46, 50)
local GLASS = Color3.fromRGB(63, 73, 80)
local METAL = Color3.fromRGB(154, 158, 162)
local LAMP = Color3.fromRGB(236, 238, 240)
local PORT_LAMP = Color3.fromRGB(214, 48, 44)
local STARBOARD_LAMP = Color3.fromRGB(52, 196, 92)
local STROBE = Color3.fromRGB(46, 112, 235)
local THICKNESS = 0.18
-- Match the reference cruiser's scale beside a standard player avatar.
-- Scale around the waterline so previews and launched boats sit at the same height.
local SCALE = 1.5
-- The wheelhouse spans these stations; the foredeck runs up to its front wall.
local CABIN_FRONT = 4
local CABIN_REAR = 12.6

function PatrolBoat.build(frame: CFrame, anchored: boolean?): Model
	local isAnchored = anchored == true
	local model = Instance.new("Model")
	model.Name = "PatrolBoat"
	model:SetAttribute("HullLength", 42 * SCALE)
	model:SetAttribute("HullBeam", 12 * SCALE)
	model:SetAttribute("PassengerSeats", 2)
	model:SetAttribute("DriverSeat", "HelmSeat")
	model:SetAttribute("DryFloorHeight", 1.1 * SCALE)
	model:SetAttribute("DryFloorHalfBeam", 5.4 * SCALE)
	model:SetAttribute("DryFloorHalfLength", 21 * SCALE)

	local function scaledFrame(localFrame: CFrame): CFrame
		return frame
			* CFrame.fromMatrix(
				localFrame.Position * SCALE,
				localFrame.RightVector,
				localFrame.UpVector,
				localFrame.ZVector
			)
	end

	local root = Instance.new("Part")
	root.Name = "HullRoot"
	root.Size = Vector3.new(7, 0.5, 28) * SCALE
	root.CFrame = scaledFrame(CFrame.new(0, -0.4, 0))
	root.Transparency = 1
	root.Anchored = isAnchored
	root.CanCollide = false
	root.CanTouch = false
	root.RootPriority = 127
	root.CustomPhysicalProperties = PhysicalProperties.new(1.4, 0.45, 0.05, 100, 100)
	root.Parent = model
	model.PrimaryPart = root

	local function finish(p: BasePart, name: string, color: Color3, material: Enum.Material?, collide: boolean?)
		p.Size *= SCALE
		p.CFrame = scaledFrame(frame:ToObjectSpace(p.CFrame))
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

	-- A long, fine entry flares into a full-beam midsection; chine is the
	-- height where the topsides meet the bilge.
	local stations = {
		{ z = -22, width = 0.18, bottom = 0.12, top = 3.35, keel = -0.05, chine = 0.25 },
		{ z = -18.3, width = 2.4, bottom = 1.5, top = 3.1, keel = -1, chine = -0.3 },
		{ z = -13, width = 4.35, bottom = 3.45, top = 2.85, keel = -1.6, chine = -0.62 },
		{ z = -6, width = 5.85, bottom = 4.85, top = 2.6, keel = -1.85, chine = -0.72 },
		{ z = 6, width = 5.9, bottom = 4.95, top = 2.5, keel = -1.85, chine = -0.72 },
		{ z = 14, width = 5.7, bottom = 5.1, top = 2.5, keel = -1.55, chine = -0.72 },
		{ z = 19, width = 5.3, bottom = 4.75, top = 2.5, keel = -1.1, chine = -0.72 },
	}
	local function hullPoint(station, side: number, level: number): Vector3
		return Vector3.new(
			side * (station.bottom + (station.width - station.bottom) * level),
			station.chine + (station.top - station.chine) * level,
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
			for _, band in { { 0, 0.68, HULL_GRAY }, { 0.68, 1, LIGHT_GRAY } } do
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
				triangle(name, a, b, c, inside, HULL_GRAY)
				triangle(name, a, c, d, inside, HULL_GRAY)
			end
			beam("Gunwale", hullPoint(from, side, 1), hullPoint(to, side, 1), 0.3, 0.24, DARK)
			-- A dark fender strake marks the two-tone seam along the topsides.
			local strake = Vector3.new(side * 0.1, 0, 0)
			beam("RubRail", hullPoint(from, side, 0.68) + strake, hullPoint(to, side, 0.68) + strake, 0.26, 0.28, DARK)
		end
	end
	for _, station in { stations[1], stations[#stations] } do
		local center = Vector3.new(0, hullPoint(station, 1, 0).Y, station.z)
		local inside = Vector3.new(0, 0.8, 0)
		for _, side in { -1, 1 } do
			local edge, bilge, keel =
				bottomPoint(station, side, 0), bottomPoint(station, side, 1), bottomPoint(station, side, 2)
			triangle("HullEndCap", edge, bilge, keel, inside, HULL_GRAY)
			triangle("HullEndCap", edge, keel, center, inside, HULL_GRAY)
		end
		if station == stations[1] then
			local left, right = hullPoint(station, -1, 1), hullPoint(station, 1, 1)
			triangle("BowCap", center, left, right, inside, HULL_GRAY)
			triangle("BowCap", center, hullPoint(station, -1, 0), left, inside, HULL_GRAY)
			triangle("BowCap", center, right, hullPoint(station, 1, 0), inside, HULL_GRAY)
		end
	end
	local stern = stations[#stations]
	local sternLeft, sternRight = hullPoint(stern, -1, 0), hullPoint(stern, 1, 0)
	triangle("Transom", sternLeft, sternRight, hullPoint(stern, 1, 1), Vector3.new(0, 0.8, 0), LIGHT_GRAY)
	triangle("Transom", sternLeft, hullPoint(stern, 1, 1), hullPoint(stern, -1, 1), Vector3.new(0, 0.8, 0), LIGHT_GRAY)
	part("TransomTrim", Vector3.new(10.5, 0.5, 0.23), CFrame.new(0, 2.24, stern.z), LIGHT_GRAY)
	part("TransomCap", Vector3.new(10.6, 0.2, 0.3), CFrame.new(0, 2.5, stern.z), LIGHT_GRAY)
	for _, side in { -1, 1 } do
		part("ExhaustPort", Vector3.new(0.7, 0.35, 0.12), CFrame.new(side * 3.2, 1.3, stern.z + 0.08), DARK)
		part("PlatformBracket", Vector3.new(0.3, 0.5, 0.85), CFrame.new(side * 3.6, 0.3, stern.z + 0.43), DARK)
	end
	-- Low swim platform and transom step for boarding from the water. The transom
	-- and platform stay ahead of the drydock headwall when previewed on the slip.
	part("SwimPlatform", Vector3.new(9.4, 0.3, 0.95), CFrame.new(0, 0.7, stern.z + 0.475), DECK, nil, true)
	part("TransomStep", Vector3.new(2.2, 0.3, 0.55), CFrame.new(0, 1.75, stern.z + 0.3), DECK, nil, true)
	for index = 1, #stations - 1 do
		beam(
			"Keel",
			bottomPoint(stations[index], 1, 2),
			bottomPoint(stations[index + 1], 1, 2),
			0.18,
			0.16,
			HULL_GRAY,
			nil,
			true
		)
	end
	local bow = stations[1]
	part(
		"BowStem",
		Vector3.new(0.3, bow.top - bow.chine, 0.25),
		CFrame.new(0, (bow.top + bow.chine) / 2, bow.z),
		LIGHT_GRAY
	)
	part("BowAnchor", Vector3.new(0.55, 0.65, 0.2), CFrame.new(0, 2.45, bow.z - 0.12), DARK)

	-- A flat, uninterrupted sole keeps the stern entrance and side decks walkable.
	local function deckWidth(s)
		return s.bottom + (s.width - s.bottom) * (1.1 - s.chine) / (s.top - s.chine) - 0.1
	end
	for i = -9, 9 do
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
			nil,
			true
		)
	end

	-- Long pointed foredeck, with the low angular center housing in the reference.
	for index = 1, 4 do
		local a, b = stations[index], stations[index + 1]
		local endZ = math.min(b.z, CABIN_FRONT - 0.12)
		local t = (endZ - a.z) / (b.z - a.z)
		local endWidth = a.width + (b.width - a.width) * t
		local endY = a.top + (b.top - a.top) * t - 0.12
		local centerA, centerB = Vector3.new(0, a.top - 0.12, a.z), Vector3.new(0, endY, endZ)
		for _, side in { -1, 1 } do
			local edgeA = hullPoint(a, side, 1) - Vector3.new(0, 0.12, 0)
			local edgeB = Vector3.new(side * endWidth, endY, endZ)
			triangle("Foredeck", centerA, edgeA, edgeB, Vector3.new(0, 0, -5), DECK)
			triangle("Foredeck", centerA, edgeB, centerB, Vector3.new(0, 0, -5), DECK)
		end
	end
	local housing = {
		{ z = -15, w = 0.75, y = 3.2 },
		{ z = -6.5, w = 2.6, y = 4.25 },
		{ z = CABIN_FRONT, w = 3.35, y = 4.25 },
	}
	for i = 1, #housing - 1 do
		local a, b = housing[i], housing[i + 1]
		local al, ar = Vector3.new(-a.w, a.y, a.z), Vector3.new(a.w, a.y, a.z)
		local bl, br = Vector3.new(-b.w, b.y, b.z), Vector3.new(b.w, b.y, b.z)
		triangle("RaisedBowHousing", al, ar, br, Vector3.new(0, 2, 0), LIGHT_GRAY)
		triangle("RaisedBowHousing", al, br, bl, Vector3.new(0, 2, 0), LIGHT_GRAY)
		for _, side in { -1, 1 } do
			local topA, topB = Vector3.new(side * a.w, a.y, a.z), Vector3.new(side * b.w, b.y, b.z)
			local lowA, lowB = Vector3.new(side * a.w, 2.38, a.z), Vector3.new(side * b.w, 2.38, b.z)
			triangle("BowHousingSide", topA, lowA, lowB, Vector3.new(0, 2, 0), LIGHT_GRAY)
			triangle("BowHousingSide", topA, lowB, topB, Vector3.new(0, 2, 0), LIGHT_GRAY)
		end
	end
	local nose = housing[1]
	part(
		"HousingNose",
		Vector3.new(nose.w * 2, nose.y - 2.38, 0.18),
		CFrame.new(0, (nose.y + 2.38) / 2, nose.z),
		LIGHT_GRAY,
		nil,
		true
	)
	part("ForedeckHatchRim", Vector3.new(2.5, 0.1, 2), CFrame.new(0, 4.32, -1), METAL)
	part("ForedeckHatch", Vector3.new(2.2, 0.12, 1.7), CFrame.new(0, 4.4, -1), DARK)
	-- Anchor gear sits on the narrow bow ahead of the housing.
	part("AnchorWindlass", Vector3.new(0.9, 0.5, 0.9), CFrame.new(0, 3.2, -17.8), DARK)
	part("WindlassDrum", Vector3.new(1.5, 0.3, 0.3), CFrame.new(0, 3.35, -17.8), METAL)
	part("BowCleat", Vector3.new(0.7, 0.15, 0.2), CFrame.new(0, 3.18, -20.3), METAL)
	-- Low bow rack follows the slope ahead of the cabin.
	for _, side in { -1, 1 } do
		beam("BowRackLeg", Vector3.new(side * 2.1, 4.3, -4), Vector3.new(side * 2.6, 5.5, 0.5), 0.12, 0.12, DARK)
	end
	for _, z in { -4, -1.75, 0.5 } do
		local alpha = (z + 4) / 4.5
		beam(
			"BowRackCrossbar",
			Vector3.new(-2.1 - alpha * 0.5, 4.3 + alpha * 1.2, z),
			Vector3.new(2.1 + alpha * 0.5, 4.3 + alpha * 1.2, z),
			0.12,
			0.12,
			DARK
		)
	end

	-- Rear wheelhouse: broad slanted windshield, side windows, open rear doorway.
	local windshieldTop = CABIN_FRONT + 0.85
	part("CabinFrontLower", Vector3.new(6.7, 2.9, 0.24), CFrame.new(0, 2.55, CABIN_FRONT), LIGHT_GRAY, nil, true)
	local pillars = {}
	for i = 0, 3 do
		pillars[i + 1] = windshieldTop + (CABIN_REAR - windshieldTop) * i / 3
	end
	for _, side in { -1, 1 } do
		part(
			"CabinSideLower",
			Vector3.new(0.24, 2.9, CABIN_REAR - CABIN_FRONT),
			CFrame.new(side * 3.35, 2.55, (CABIN_FRONT + CABIN_REAR) / 2),
			LIGHT_GRAY,
			nil,
			true
		)
		part(
			"CabinSideHeader",
			Vector3.new(0.28, 0.35, CABIN_REAR - windshieldTop),
			CFrame.new(side * 3.35, 6.3, (windshieldTop + CABIN_REAR) / 2),
			LIGHT_GRAY,
			nil,
			true
		)
		-- Closes the triangle between the raked windshield pillar and the side wall.
		local quarter = Instance.new("WedgePart")
		quarter.Size = Vector3.new(0.24, 2.1, windshieldTop - CABIN_FRONT)
		quarter.CFrame = frame * CFrame.new(side * 3.35, 5.1, (CABIN_FRONT + windshieldTop) / 2)
		finish(quarter, "CabinQuarterPanel", LIGHT_GRAY, nil, true)
		for i = 1, 3 do
			local window = part(
				"CabinSideWindow",
				Vector3.new(0.12, 2.1, pillars[i + 1] - pillars[i] - 0.24),
				CFrame.new(side * 3.35, 5.08, (pillars[i] + pillars[i + 1]) / 2),
				GLASS,
				nil,
				true
			)
			window.Transparency = 0.25
		end
		for _, z in pillars do
			part(
				"CabinWindowPillar",
				Vector3.new(0.28, 2.3, 0.22),
				CFrame.new(side * 3.35, 5.1, z),
				LIGHT_GRAY,
				nil,
				true
			)
		end
		part(
			"CabinRearWall",
			Vector3.new(1.95, 5.15, 0.24),
			CFrame.new(side * 2.425, 3.675, CABIN_REAR),
			LIGHT_GRAY,
			nil,
			true
		)
		local bottom, top =
			Vector3.new(side * 1.68, 4.05, CABIN_FRONT - 0.05), Vector3.new(side * 1.68, 6.15, windshieldTop)
		local window = beam("Windshield", bottom, top, 3.05, 0.12, GLASS, nil, true)
		window.Transparency = 0.22
		beam(
			"WindshieldPillar",
			Vector3.new(side * 3.3, 4.05, CABIN_FRONT - 0.05),
			Vector3.new(side * 3.3, 6.15, windshieldTop),
			0.25,
			0.25,
			LIGHT_GRAY,
			nil,
			true
		)
		beam(
			"RoofGrabRail",
			Vector3.new(side * 3.45, 6.9, windshieldTop + 0.6),
			Vector3.new(side * 3.45, 6.9, CABIN_REAR - 0.4),
			0.1,
			0.1,
			METAL
		)
		-- Running lights: red to port, green to starboard.
		local navLight = part(
			if side < 0 then "PortNavLight" else "StarboardNavLight",
			Vector3.new(0.14, 0.3, 0.5),
			CFrame.new(side * 3.5, 4.3, CABIN_FRONT + 0.5),
			if side < 0 then PORT_LAMP else STARBOARD_LAMP,
			Enum.Material.Neon
		)
		navLight.CastShadow = false
	end
	beam(
		"WindshieldMullion",
		Vector3.new(0, 4.05, CABIN_FRONT - 0.05),
		Vector3.new(0, 6.15, windshieldTop),
		0.22,
		0.22,
		LIGHT_GRAY,
		nil,
		true
	)
	part("RearDoorHeader", Vector3.new(2.9, 0.3, 0.26), CFrame.new(0, 6.25, CABIN_REAR), LIGHT_GRAY, nil, true)
	local roofFront, roofRear = windshieldTop - 0.45, CABIN_REAR + 0.6
	part(
		"CabinRoof",
		Vector3.new(7.35, 0.3, roofRear - roofFront),
		CFrame.new(0, 6.55, (roofFront + roofRear) / 2),
		HULL_GRAY,
		nil,
		true
	)
	part("RoofVent", Vector3.new(1.3, 0.65, 1.2), CFrame.new(0, 7.02, 9.4), DARK)
	part("VentCap", Vector3.new(1.7, 0.2, 1.6), CFrame.new(0, 7.45, 9.4), METAL)
	-- Patrol light bar across the windshield header.
	part("LightBar", Vector3.new(3.4, 0.24, 0.4), CFrame.new(0, 6.82, roofFront + 0.35), DARK)
	for _, side in { -1, 1 } do
		local strobe = part(
			"LightBarStrobe",
			Vector3.new(1.1, 0.2, 0.42),
			CFrame.new(side * 0.95, 6.98, roofFront + 0.35),
			STROBE,
			Enum.Material.Neon
		)
		strobe.CastShadow = false
	end
	part("SearchlightBase", Vector3.new(0.35, 0.2, 0.35), CFrame.new(-2.3, 6.8, roofFront + 0.9), DARK)
	part("Searchlight", Vector3.new(0.7, 0.5, 0.8), CFrame.new(-2.3, 7.15, roofFront + 0.9), METAL)
	local lens = part(
		"SearchlightLens",
		Vector3.new(0.55, 0.38, 0.06),
		CFrame.new(-2.3, 7.15, roofFront + 0.47),
		LAMP,
		Enum.Material.Neon
	)
	lens.CastShadow = false
	-- Radar mast near the back of the roof, with whip antennas at the corners.
	local radarZ = CABIN_REAR - 1
	part("RadarMast", Vector3.new(0.3, 1.4, 0.3), CFrame.new(0, 7.4, radarZ), DARK)
	part("RadarPedestal", Vector3.new(0.7, 0.3, 0.7), CFrame.new(0, 8.1, radarZ), DARK)
	part("RadarArray", Vector3.new(3.4, 0.22, 0.4), CFrame.new(0, 8.36, radarZ), LIGHT_GRAY)
	local masthead =
		part("MastheadLight", Vector3.new(0.25, 0.25, 0.25), CFrame.new(0, 8.6, radarZ), LAMP, Enum.Material.Neon)
	masthead.CastShadow = false
	part("Antenna", Vector3.new(0.08, 2.7, 0.08), CFrame.new(-2.9, 8.05, CABIN_REAR), DARK)
	part("Antenna", Vector3.new(0.08, 2, 0.08), CFrame.new(2.9, 7.7, CABIN_REAR), DARK)

	-- The starboard helm is the only seat in the wheelhouse.
	local consoleZ = CABIN_FRONT + 1.8
	local seatZ = CABIN_FRONT + 4.1
	part("HelmConsole", Vector3.new(2.35, 1.1, 0.8), CFrame.new(1.3, 2.5, consoleZ), HULL_GRAY)
	part("InstrumentPanel", Vector3.new(2, 0.55, 0.12), CFrame.new(1.3, 3.17, consoleZ + 0.44), DARK)
	local wheelCenter = Vector3.new(1.3, 3.25, consoleZ + 0.8)
	for i = 0, 7 do
		local a, b = i * math.pi / 4, (i + 1) * math.pi / 4
		beam(
			"SteeringWheel",
			wheelCenter + Vector3.new(math.cos(a) * 0.44, math.sin(a) * 0.44, 0),
			wheelCenter + Vector3.new(math.cos(b) * 0.44, math.sin(b) * 0.44, 0),
			0.08,
			0.08,
			DARK
		)
	end
	part("HelmPedestal", Vector3.new(0.6, 0.8, 0.6), CFrame.new(1.3, 1.5, seatZ), METAL)
	part("HelmCushion", Vector3.new(1.9, 0.3, 1.5), CFrame.new(1.3, 2.05, seatZ), DARK)
	part("HelmBackrest", Vector3.new(1.9, 1.2, 0.22), CFrame.new(1.3, 2.7, seatZ + 0.7), DARK)
	local helm = Instance.new("VehicleSeat")
	helm.Size, helm.CFrame = Vector3.new(1.9, 0.24, 1.5), frame * CFrame.new(1.3, 2.2, seatZ)
	helm.Transparency, helm.HeadsUpDisplay = 1, false
	helm.MaxSpeed, helm.Torque, helm.TurnSpeed = 0, 0, 0
	finish(helm, "HelmSeat", DARK)
	helm.CanTouch, helm.Disabled = not isAnchored, isAnchored
	part("NavConsole", Vector3.new(1.7, 1.1, 0.8), CFrame.new(-2.15, 2.5, consoleZ), HULL_GRAY)
	part("ChartDisplay", Vector3.new(1.4, 0.5, 0.12), CFrame.new(-2.15, 3.17, consoleZ + 0.44), DARK)

	-- Open aft cockpit with forward-facing benches and a transom boarding gate.
	local benchZ = CABIN_REAR + 2.4
	for _, side in { -1, 1 } do
		-- Steps up from the side decks onto the raised foredeck.
		part(
			"ForedeckStep",
			Vector3.new(2, 0.6, 0.8),
			CFrame.new(side * 4.55, 1.45, CABIN_FRONT + 0.4),
			DECK,
			nil,
			true
		)
		part("SternSeatCushion", Vector3.new(2.2, 0.3, 1.7), CFrame.new(side * 3.1, 1.9, benchZ), DARK)
		part("SternSeatBack", Vector3.new(2.2, 1.1, 0.22), CFrame.new(side * 3.1, 2.6, benchZ + 0.75), HULL_GRAY)
		local seat = Instance.new("Seat")
		seat.Size, seat.CFrame = Vector3.new(2.2, 0.24, 1.7), frame * CFrame.new(side * 3.1, 2.05, benchZ)
		seat.Transparency = 1
		finish(seat, "PassengerSeat" .. (if side < 0 then "Port" else "Starboard"), DARK)
		seat.CanTouch, seat.Disabled = not isAnchored, isAnchored
		local points = {
			Vector3.new(side * 0.3, 4.2, -21.6),
			Vector3.new(side * 2.25, 3.95, -18.1),
			Vector3.new(side * 4.15, 3.7, -12.9),
			Vector3.new(side * 5.6, 3.45, -6),
			Vector3.new(side * 5.65, 3.4, CABIN_FRONT - 1),
		}
		for i, point in points do
			part("BowRailPost", Vector3.new(0.1, 0.85, 0.1), CFrame.new(point - Vector3.new(0, 0.425, 0)), METAL)
			if i > 1 then
				beam("BowRail", points[i - 1], point, 0.1, 0.1, METAL)
			end
		end
		local railFront, railRear = CABIN_REAR + 0.2, stern.z - 0.3
		for _, z in { railFront, (railFront + railRear) / 2, railRear } do
			part("SternRailPost", Vector3.new(0.12, 1.6, 0.12), CFrame.new(side * 5.15, 3.3, z), METAL)
		end
		beam(
			"SternRail",
			Vector3.new(side * 5.15, 4.1, railFront),
			Vector3.new(side * 5.15, 4.1, railRear),
			0.12,
			0.12,
			METAL
		)
		-- The transom rail leaves a center gate above the boarding step.
		beam(
			"TransomRail",
			Vector3.new(side * 5.15, 4.1, railRear),
			Vector3.new(side * 1.3, 4.1, railRear),
			0.12,
			0.12,
			METAL
		)
		part("TransomGatePost", Vector3.new(0.12, 1.6, 0.12), CFrame.new(side * 1.3, 3.3, railRear), METAL)
		part("SternCleat", Vector3.new(0.9, 0.15, 0.22), CFrame.new(side * 5.25, 2.62, stern.z - 0.9), METAL)
		part("MidshipCleat", Vector3.new(0.9, 0.15, 0.22), CFrame.new(side * 5.6, 2.72, 0), METAL)
		part("EngineVent", Vector3.new(0.15, 0.7, 2), CFrame.new(side * 5.55, 1.65, benchZ + 0.4), DARK)
	end
	local sternLight =
		part("SternLight", Vector3.new(0.3, 0.25, 0.3), CFrame.new(0, 2.72, stern.z - 0.1), LAMP, Enum.Material.Neon)
	sternLight.CastShadow = false
	for _, z in { stern.z - 2.6, stern.z - 1.5 } do
		part("CargoHatchRim", Vector3.new(3, 0.12, 0.9), CFrame.new(0, 1.16, z), METAL)
		part("CargoHatch", Vector3.new(2.8, 0.1, 0.7), CFrame.new(0, 1.27, z), HULL_GRAY)
	end
	return model
end

return PatrolBoat
