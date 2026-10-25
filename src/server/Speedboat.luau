-- Blue-and-white sport cruiser. Waterline origin; local -Z is the bow.
-- The faceted V hull and cockpit sole form one welded, server-driven assembly.
local Speedboat = {}
local WHITE = Color3.fromRGB(237, 241, 246)
local BLUE = Color3.fromRGB(8, 113, 166)
local DECK = Color3.fromRGB(185, 204, 212)
local DARK = Color3.fromRGB(40, 51, 61)
local GLASS = Color3.fromRGB(62, 83, 99)
local METAL = Color3.fromRGB(122, 139, 151)
local THICKNESS = 0.18

function Speedboat.build(frame: CFrame, anchored: boolean?): Model
	local isAnchored = anchored == true
	local model = Instance.new("Model")
	model.Name = "Speedboat"
	model:SetAttribute("HullLength", 24)
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
			for _, band in { { 0, 0.68, BLUE }, { 0.68, 1, WHITE } } do
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
				triangle(name, a, b, c, inside, BLUE)
				triangle(name, a, c, d, inside, BLUE)
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
			triangle("HullEndCap", edge, bilge, keel, inside, BLUE)
			triangle("HullEndCap", edge, keel, center, inside, BLUE)
		end
		if station == stations[1] then
			local left, right = hullPoint(station, -1, 1), hullPoint(station, 1, 1)
			triangle("BowCap", center, left, right, inside, BLUE)
			triangle("BowCap", center, hullPoint(station, -1, 0), left, inside, BLUE)
			triangle("BowCap", center, right, hullPoint(station, 1, 0), inside, BLUE)
		end
	end
	local stern = stations[#stations]
	local sternLeft, sternRight = hullPoint(stern, -1, 0), hullPoint(stern, 1, 0)
	triangle("Transom", sternLeft, sternRight, hullPoint(stern, 1, 1), Vector3.new(0, 0.8, 0), WHITE)
	triangle("Transom", sternLeft, hullPoint(stern, 1, 1), hullPoint(stern, -1, 1), Vector3.new(0, 0.8, 0), WHITE)
	part("TransomTrim", Vector3.new(7.4, 0.5, 0.23), CFrame.new(0, 2.04, 10.8), WHITE)
	part("TransomCap", Vector3.new(7.5, 0.2, 0.3), CFrame.new(0, 2.3, 10.8), WHITE)
	for index = 1, #stations - 1 do
		beam(
			"Keel",
			bottomPoint(stations[index], 1, 2),
			bottomPoint(stations[index + 1], 1, 2),
			0.18,
			0.16,
			BLUE,
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
			Enum.Material.SmoothPlastic,
			true
		)
	end

	-- Fitted bow deck closes the forward hull while leaving the cockpit open.
	for index = 1, 3 do
		local a, b = stations[index], stations[index + 1]
		local centerA = Vector3.new(0, a.top - 0.12, a.z)
		local centerB = Vector3.new(0, b.top - 0.12, b.z)
		for _, side in { -1, 1 } do
			local edgeA = hullPoint(a, side, 1) - Vector3.new(0, 0.12, 0)
			local edgeB = hullPoint(b, side, 1) - Vector3.new(0, 0.12, 0)
			-- End the foredeck ahead of the helm, rather than covering the cockpit.
			if index == 3 then
				centerB = Vector3.new(0, 2.08, -0.8)
				edgeB = Vector3.new(side * 4.65, 2.08, -0.8)
			end
			triangle("Foredeck", centerA, edgeA, edgeB, Vector3.new(0, 0, -4), WHITE)
			triangle("Foredeck", centerA, edgeB, centerB, Vector3.new(0, 0, -4), WHITE)
		end
	end
	part("DeckStripe", Vector3.new(1.3, 0.035, 5.5), CFrame.new(0, 2.105, -3.6), BLUE)
	part("ForedeckHatchRim", Vector3.new(2.05, 0.12, 1.65), CFrame.new(0, 2.19, -4.6), METAL)
	part("ForedeckHatch", Vector3.new(1.8, 0.14, 1.4), CFrame.new(0, 2.26, -4.6), DARK)

	-- Swept windshield: dark glazing, white frame, and small triangular sides.
	local screenBottom = Vector3.new(0, 2.28, -0.7)
	local screenTop = Vector3.new(0, 4.15, 1.25)
	local windshield = beam("Windshield", screenBottom, screenTop, 6.0, 0.12, GLASS)
	windshield.Transparency = 0.2
	beam("WindshieldHeader", screenTop + Vector3.new(-3.1, 0, 0), screenTop + Vector3.new(3.1, 0, 0), 0.2, 0.2, WHITE)
	beam(
		"WindshieldSill",
		screenBottom + Vector3.new(-3.1, 0, 0),
		screenBottom + Vector3.new(3.1, 0, 0),
		0.24,
		0.24,
		WHITE
	)
	beam("WindshieldMullion", screenBottom, screenTop, 0.18, 0.18, WHITE)
	for _, side in { -1, 1 } do
		local front = screenBottom + Vector3.new(side * 3.1, 0, 0)
		local top = screenTop + Vector3.new(side * 3.1, 0, 0)
		local rear = Vector3.new(side * 3.1, 2.28, 3.0)
		beam("WindshieldPillar", front, top, 0.24, 0.24, WHITE)
		beam("WindowRearFrame", top, rear, 0.2, 0.2, WHITE)
		triangle("SideWindow", front, top, rear, Vector3.new(0, 2.4, 1), GLASS)
		part("CockpitCoaming", Vector3.new(0.35, 0.28, 9.8), CFrame.new(side * 3.3, 2.3, 5.85), WHITE)
		-- Round portholes with a pale rim along the blue hull.
		for _, z in { -2.8, 3.7, 8.1 } do
			local width = 0
			for index = 1, #stations - 1 do
				local a, b = stations[index], stations[index + 1]
				if z >= a.z and z <= b.z then
					local function widthAt(station)
						return station.bottom + (station.width - station.bottom) * (0.85 + 0.72) / (station.top + 0.72)
					end
					width = widthAt(a) + (widthAt(b) - widthAt(a)) * (z - a.z) / (b.z - a.z)
					break
				end
			end
			local rim =
				part("PortholeRim", Vector3.new(0.12, 0.65, 0.65), CFrame.new(side * (width + 0.045), 0.85, z), WHITE)
			rim.Shape = Enum.PartType.Cylinder
			local glass =
				part("PortholeGlass", Vector3.new(0.14, 0.43, 0.43), CFrame.new(side * (width + 0.11), 0.85, z), DARK)
			glass.Shape = Enum.PartType.Cylinder
		end
		-- Low rails follow the pointed bow and stop before the boarding cockpit.
		local railPoints = {
			Vector3.new(side * 0.22, 3.7, -10.5),
			Vector3.new(side * 3.15, 3.3, -8.0),
			Vector3.new(side * 4.4, 3.0, -3.5),
			Vector3.new(side * 4.4, 3.0, -0.9),
		}
		for index, point in railPoints do
			part("BowRailPost", Vector3.new(0.09, 0.75, 0.09), CFrame.new(point - Vector3.new(0, 0.375, 0)), METAL)
			if index > 1 then
				beam("BowRail", railPoints[index - 1], point, 0.1, 0.1, METAL)
			end
		end
		part("SternCushion", Vector3.new(2.15, 0.28, 1.6), CFrame.new(side * 1.6, 1.72, 8.5), BLUE)
		part("SternBackrest", Vector3.new(2.15, 0.95, 0.25), CFrame.new(side * 1.6, 2.24, 9.25), WHITE)
		local passenger = Instance.new("Seat")
		passenger.Size = Vector3.new(2.15, 0.24, 1.6)
		passenger.CFrame = frame * CFrame.new(side * 1.6, 1.87, 8.5)
		passenger.Transparency = 1
		finish(passenger, "PassengerSeat" .. (if side < 0 then "Port" else "Starboard"), BLUE)
		passenger.CanTouch = not isAnchored
		passenger.Disabled = isAnchored
	end

	part("HelmPedestal", Vector3.new(0.5, 0.7, 0.5), CFrame.new(1.6, 1.45, 4.3), METAL)
	part("HelmCushion", Vector3.new(1.8, 0.3, 1.6), CFrame.new(1.6, 1.95, 4.3), BLUE)
	part("HelmBackrest", Vector3.new(1.8, 1.2, 0.25), CFrame.new(1.6, 2.5, 5.0), WHITE)
	local helm = Instance.new("VehicleSeat")
	helm.Size = Vector3.new(1.8, 0.24, 1.6)
	helm.CFrame = frame * CFrame.new(1.6, 2.1, 4.3)
	helm.Transparency = 1
	helm.HeadsUpDisplay = false
	helm.MaxSpeed, helm.Torque, helm.TurnSpeed = 0, 0, 0
	finish(helm, "HelmSeat", BLUE)
	helm.CanTouch = not isAnchored
	helm.Disabled = isAnchored
	part("HelmConsole", Vector3.new(2.3, 1.1, 0.7), CFrame.new(1.6, 1.75, 2.25), WHITE)
	part("InstrumentPanel", Vector3.new(1.9, 0.35, 0.12), CFrame.new(1.6, 2.48, 2.65), DARK)
	local wheelCenter = Vector3.new(1.6, 2.9, 2.95)
	for i = 0, 7 do
		local a, b = i * math.pi / 4, (i + 1) * math.pi / 4
		beam(
			"SteeringWheel",
			wheelCenter + Vector3.new(math.cos(a) * 0.42, math.sin(a) * 0.42, 0),
			wheelCenter + Vector3.new(math.cos(b) * 0.42, math.sin(b) * 0.42, 0),
			0.08,
			0.08,
			DARK
		)
	end
	for i = 0, 2 do
		local angle = i * math.pi * 2 / 3
		beam(
			"WheelSpoke",
			wheelCenter,
			wheelCenter + Vector3.new(math.cos(angle) * 0.4, math.sin(angle) * 0.4, 0),
			0.06,
			0.06,
			METAL
		)
	end
	part("EngineCover", Vector3.new(2.1, 0.55, 1.5), CFrame.new(0, 1.4, 10), WHITE)
	part("SwimPlatform", Vector3.new(5.8, 0.18, 0.8), CFrame.new(0, 0.65, 11.2), WHITE, nil, true)
	for _, x in { -1.7, 1.7 } do
		part("SternCleat", Vector3.new(0.65, 0.12, 0.18), CFrame.new(x, 2.44, 10.3), METAL)
	end
	return model
end

return Speedboat
