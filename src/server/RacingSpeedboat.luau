-- Long, low white racing launch with a charcoal cockpit and stern outboard. Waterline origin; local -Z is the bow.
-- The faceted V hull and cockpit sole form one welded, server-driven assembly.
local RacingSpeedboat = { VERSION = 2 }
local WHITE = Color3.fromRGB(237, 241, 246)
local UNDERBODY = Color3.fromRGB(205, 213, 220)
local DECK = Color3.fromRGB(55, 59, 65)
local DARK = Color3.fromRGB(27, 31, 37)
local UPHOLSTERY = Color3.fromRGB(48, 53, 60)
local STITCH = Color3.fromRGB(97, 104, 111)
local GLASS = Color3.fromRGB(62, 83, 99)
local METAL = Color3.fromRGB(122, 139, 151)
local THICKNESS = 0.18

function RacingSpeedboat.build(frame: CFrame, anchored: boolean?): Model
	local isAnchored = anchored == true
	local model = Instance.new("Model")
	model.Name = "RacingSpeedboat"
	model:SetAttribute("ModelVersion", RacingSpeedboat.VERSION)
	model:SetAttribute("HullLength", 30)
	model:SetAttribute("HullBeam", 8)
	model:SetAttribute("PassengerSeats", 3)
	model:SetAttribute("DriverSeat", "HelmSeat")
	model:SetAttribute("DryFloorHeight", 1.1)
	model:SetAttribute("DryFloorHalfBeam", 3.5)
	model:SetAttribute("DryFloorHalfLength", 12.4)

	local root = Instance.new("Part")
	root.Name = "HullRoot"
	root.Size = Vector3.new(5.6, 0.5, 18)
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
		collide: boolean?,
		transparency: number?
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
		finish(first, name, color, nil, collide ~= false)
		first.Transparency = transparency or 0
		local second = Instance.new("WedgePart")
		second.Size = Vector3.new(THICKNESS, height, math.abs(ac:Dot(back)))
		second.CFrame = frame * CFrame.fromMatrix((a + c) / 2 + shift, -right, up, -back)
		finish(second, name, color, nil, collide ~= false)
		second.Transparency = transparency or 0
	end

	local stations = {
		{ z = -13.8, width = 0.12, bottom = 0.08, top = 2.2, keel = 0.05 },
		{ z = -12, width = 1.24, bottom = 0.66, top = 2.14, keel = -0.54 },
		{ z = -9.2, width = 2.55, bottom = 1.8, top = 2.02, keel = -1.05 },
		{ z = -5.7, width = 3.48, bottom = 2.9, top = 1.9, keel = -1.22 },
		{ z = -2.4, width = 3.88, bottom = 3.28, top = 1.82, keel = -1.28 },
		{ z = 3.7, width = 3.9, bottom = 3.32, top = 1.8, keel = -1.25 },
		{ z = 9, width = 3.77, bottom = 3.25, top = 1.84, keel = -1.1 },
		{ z = 12.4, width = 3.45, bottom = 2.85, top = 1.9, keel = -0.85 },
	}
	local function hullPoint(station, side: number, level: number): Vector3
		local bottomY = if station.z < -13 then 0.25 else -0.72
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
			local inside = Vector3.new(0, 0.6, (from.z + to.z) / 2)
			local a, b = hullPoint(from, side, 0), hullPoint(to, side, 0)
			local c, d = hullPoint(to, side, 1), hullPoint(from, side, 1)
			triangle("HullPanel", a, b, c, inside, WHITE)
			triangle("HullPanel", a, c, d, inside, WHITE)
			-- A fine stripe follows the actual sheer instead of widening toward the bow.
			local offset = Vector3.new(side * 0.018, 0, 0)
			a, b = hullPoint(from, side, 0.62) + offset, hullPoint(to, side, 0.62) + offset
			c, d = hullPoint(to, side, 0.70) + offset, hullPoint(from, side, 0.70) + offset
			triangle("HullStripe", a, b, c, inside, DARK, false)
			triangle("HullStripe", a, c, d, inside, DARK, false)
			for band = 0, 1 do
				local a, b = bottomPoint(from, side, band), bottomPoint(to, side, band)
				local c, d = bottomPoint(to, side, band + 1), bottomPoint(from, side, band + 1)
				local inside = Vector3.new(0, 0.8, (from.z + to.z) / 2)
				local name = if band == 0 then "BilgePanel" else "BottomPanel"
				triangle(name, a, b, c, inside, UNDERBODY)
				triangle(name, a, c, d, inside, UNDERBODY)
			end
			beam("Gunwale", hullPoint(from, side, 1), hullPoint(to, side, 1), 0.23, 0.16, WHITE)
			local rub = Vector3.new(side * 0.04, -0.11, 0)
			beam("RubRail", hullPoint(from, side, 1) + rub, hullPoint(to, side, 1) + rub, 0.09, 0.08, DARK)
		end
	end
	for _, station in { stations[1], stations[#stations] } do
		local center = Vector3.new(0, hullPoint(station, 1, 0).Y, station.z)
		local inside = Vector3.new(0, 0.8, 0)
		for _, side in { -1, 1 } do
			local edge, bilge, keel =
				bottomPoint(station, side, 0), bottomPoint(station, side, 1), bottomPoint(station, side, 2)
			triangle("HullEndCap", edge, bilge, keel, inside, UNDERBODY)
			triangle("HullEndCap", edge, keel, center, inside, UNDERBODY)
		end
		if station == stations[1] then
			local left, right = hullPoint(station, -1, 1), hullPoint(station, 1, 1)
			triangle("BowCap", center, left, right, inside, UNDERBODY)
			triangle("BowCap", center, hullPoint(station, -1, 0), left, inside, UNDERBODY)
			triangle("BowCap", center, right, hullPoint(station, 1, 0), inside, UNDERBODY)
		end
	end
	local stern = stations[#stations]
	local sternLeft, sternRight = hullPoint(stern, -1, 0), hullPoint(stern, 1, 0)
	triangle("Transom", sternLeft, sternRight, hullPoint(stern, 1, 1), Vector3.new(0, 0.8, 0), WHITE)
	triangle("Transom", sternLeft, hullPoint(stern, 1, 1), hullPoint(stern, -1, 1), Vector3.new(0, 0.8, 0), WHITE)
	part("TransomTrim", Vector3.new(7.1, 0.5, 0.23), CFrame.new(0, 1.63, 12.4), WHITE)
	part("TransomCap", Vector3.new(7.2, 0.2, 0.3), CFrame.new(0, 1.9, 12.4), WHITE)
	for index = 1, #stations - 1 do
		beam(
			"Keel",
			bottomPoint(stations[index], 1, 2),
			bottomPoint(stations[index + 1], 1, 2),
			0.18,
			0.16,
			UNDERBODY,
			nil,
			true
		)
	end
	part("BowStem", Vector3.new(0.16, 1.95, 0.16), CFrame.new(0, 1.2, -13.8), WHITE)

	-- Continuous planks provide a working bow deck and two clear side walkways.
	local function deckWidth(station): number
		local bottomY = if station.z < -13 then 0.25 else -0.72
		local level = (1.1 - bottomY) / (station.top - bottomY)
		return math.max(0, station.bottom + (station.width - station.bottom) * level - 0.15)
	end
	for i = -6, 6 do
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

	local function quad(
		name: string,
		a: Vector3,
		b: Vector3,
		c: Vector3,
		d: Vector3,
		color: Color3,
		collide: boolean?,
		transparency: number?
	)
		local inside = (a + b + c + d) / 4 - Vector3.new(0, 1, 0)
		triangle(name, a, b, c, inside, color, collide, transparency)
		triangle(name, a, c, d, inside, color, collide, transparency)
	end
	local function stationAt(z: number)
		for index = 1, #stations - 1 do
			local a, b = stations[index], stations[index + 1]
			if z <= b.z then
				local t = math.clamp((z - a.z) / (b.z - a.z), 0, 1)
				return a.width + (b.width - a.width) * t, a.top + (b.top - a.top) * t
			end
		end
		return stations[#stations].width, stations[#stations].top
	end
	local function deckPoint(z: number, fraction: number): Vector3
		local width, top = stationAt(z)
		local x = width * math.abs(fraction)
		local crown = 0
		for index = 1, #stations - 1 do
			local a, b = stations[index], stations[index + 1]
			if z <= b.z then
				local t = math.clamp((z - a.z) / (b.z - a.z), 0, 1)
				-- Match the two actual deck triangles so trim cannot sink into their diagonal.
				crown = if x <= t * b.width then 1 - x / b.width else 1 - t - (x - t * b.width) / a.width
				break
			end
		end
		return Vector3.new(width * fraction, top - 0.045 + crown * 0.12, z)
	end
	-- Crown the foredeck across its beam and follow the curved sheer to the bow.
	for index = 1, 4 do
		local a, b = stations[index].z, stations[index + 1].z
		for _, side in { -1, 1 } do
			quad("Foredeck", deckPoint(a, 0), deckPoint(a, side), deckPoint(b, side), deckPoint(b, 0), WHITE)
		end
	end
	for _, side in { -1, 1 } do
		for _, range in { { -12, -9.2 }, { -9.2, -5.7 }, { -5.7, -3.8 } } do
			local cuts = { range[1], range[2] }
			for index = 1, #stations - 1 do
				local a, b = stations[index], stations[index + 1]
				if range[1] >= a.z and range[1] < b.z then
					for _, fraction in { 0.60, 0.66 } do
						local t = fraction * a.width / (b.width * (1 - fraction) + fraction * a.width)
						local z = a.z + (b.z - a.z) * t
						if z > range[1] and z < range[2] then
							table.insert(cuts, z)
						end
					end
					break
				end
			end
			table.sort(cuts)
			for index = 1, #cuts - 1 do
				local a, b = cuts[index], cuts[index + 1]
				local lift = Vector3.new(0, 0.018, 0)
				quad(
					"BowAccent",
					deckPoint(a, side * 0.60) + lift,
					deckPoint(a, side * 0.66) + lift,
					deckPoint(b, side * 0.66) + lift,
					deckPoint(b, side * 0.60) + lift,
					DARK,
					false
				)
			end
		end
		-- Fitted white side decks hide the hull edges around a recessed dark cockpit.
		for _, range in { { -2.4, 3.7 }, { 3.7, 6.7 } } do
			local a, b = range[1], range[2]
			local wa, ya = stationAt(a)
			local wb, yb = stationAt(b)
			quad(
				"CockpitCoaming",
				Vector3.new(side * 3.03, ya, a),
				Vector3.new(side * wa, ya, a),
				Vector3.new(side * wb, yb, b),
				Vector3.new(side * 3.03, yb, b),
				WHITE
			)
		end
		part("CockpitLiner", Vector3.new(0.12, 0.60, 8.6), CFrame.new(side * 3.04, 1.47, 2.1), DARK)
		part("CockpitTrim", Vector3.new(0.10, 0.10, 8.7), CFrame.new(side * 3.04, 1.86, 2.1), UPHOLSTERY)
		part("CockpitArmrest", Vector3.new(0.22, 0.15, 2), CFrame.new(side * 2.91, 1.68, 2.1), UPHOLSTERY)
	end
	-- Continuous stern deck fits the tapered transom; the sunpad sits in a white surround.
	for _, range in { { 6.7, 9 }, { 9, 12.4 } } do
		local a, b = range[1], range[2]
		for _, side in { -1, 1 } do
			quad("SternDeck", deckPoint(a, 0), deckPoint(a, side), deckPoint(b, side), deckPoint(b, 0), WHITE)
		end
	end
	part("SunpadRecess", Vector3.new(5.45, 0.12, 4.75), CFrame.new(0, 1.99, 9.35), DARK)
	for index = -1, 1 do
		part("SternSunpad", Vector3.new(1.72, 0.19, 4.53), CFrame.new(index * 1.78, 2.12, 9.35), UPHOLSTERY)
		part("SunpadPiping", Vector3.new(1.60, 0.025, 0.035), CFrame.new(index * 1.78, 2.22, 7.25), STITCH)
	end
	part("RearCockpitBulkhead", Vector3.new(5.95, 0.62, 0.16), CFrame.new(0, 1.42, 6.65), DARK)
	part("RearGrabRail", Vector3.new(3.2, 0.09, 0.09), CFrame.new(0, 1.87, 6.54), METAL)

	-- Two swept front panes and triangular quarter windows form a low wraparound screen.
	local lower = { Vector3.new(-3.02, 1.96, -2.1), Vector3.new(0, 2.04, -2.72), Vector3.new(3.02, 1.96, -2.1) }
	local upper = { Vector3.new(-2.66, 3.06, -0.9), Vector3.new(0, 3.16, -1.52), Vector3.new(2.66, 3.06, -0.9) }
	for index = 1, 2 do
		quad("Windshield", lower[index], lower[index + 1], upper[index + 1], upper[index], GLASS, false, 0.28)
		beam("WindshieldHeader", upper[index], upper[index + 1], 0.08, 0.08, DARK)
		beam("WindshieldSill", lower[index], lower[index + 1], 0.13, 0.13, DARK)
	end
	beam("WindshieldMullion", lower[2], upper[2], 0.075, 0.075, DARK)
	for _, index in { 1, 3 } do
		local side = if index == 1 then -1 else 1
		local rear = Vector3.new(side * 2.98, 1.88, 1.40)
		triangle("SideWindow", lower[index], upper[index], rear, Vector3.new(0, 1.9, 0), GLASS, false, 0.30)
		beam("WindowFrame", upper[index], rear, 0.08, 0.08, DARK)
		beam("WindshieldPillar", lower[index], upper[index], 0.10, 0.10, DARK)
	end
	local passengerIndex = 0
	for row, z in { 0.7, 4.6 } do
		for _, side in { -1, 1 } do
			local x = side * 1.49
			part("BucketPedestal", Vector3.new(0.55, 0.31, 0.55), CFrame.new(x, 1.26, z), METAL)
			part("BucketShell", Vector3.new(2.10, 0.24, 1.88), CFrame.new(x, 1.48, z + 0.05), DARK)
			part("BucketCushion", Vector3.new(1.63, 0.26, 1.54), CFrame.new(x, 1.68, z - 0.06), UPHOLSTERY)
			part(
				"BucketBackrest",
				Vector3.new(1.98, 1.34, 0.28),
				CFrame.new(x, 2.12, z + 0.78) * CFrame.Angles(math.rad(12), 0, 0),
				DARK
			)
			part(
				"BucketBackPad",
				Vector3.new(1.52, 1.09, 0.19),
				CFrame.new(x, 2.15, z + 0.59) * CFrame.Angles(math.rad(12), 0, 0),
				UPHOLSTERY
			)
			part("BucketHeadrest", Vector3.new(1.16, 0.28, 0.34), CFrame.new(x, 2.81, z + 0.88), UPHOLSTERY)
			for _, edge in { -1, 1 } do
				part("BucketBolster", Vector3.new(0.22, 0.40, 1.60), CFrame.new(x + edge * 0.91, 1.78, z), DARK)
				part("SeatPiping", Vector3.new(0.025, 0.025, 1.37), CFrame.new(x + edge * 0.71, 1.82, z - 0.05), STITCH)
			end
			local driver = row == 1 and side == 1
			local seat = Instance.new(if driver then "VehicleSeat" else "Seat")
			seat.Size = Vector3.new(1.65, 0.24, 1.5)
			seat.CFrame = frame * CFrame.new(x, 1.87, z)
			seat.Transparency = 1
			if driver then
				seat.HeadsUpDisplay = false
				seat.MaxSpeed, seat.Torque, seat.TurnSpeed = 0, 0, 0
			else
				passengerIndex += 1
			end
			finish(seat, if driver then "HelmSeat" else "PassengerSeat" .. passengerIndex, DARK)
			seat.CanTouch, seat.Disabled = not isAnchored, isAnchored
		end
	end
	-- Sloping dashboard, individual instruments, throttle and three-spoke wheel.
	part("HelmConsole", Vector3.new(2.38, 0.67, 0.80), CFrame.new(1.49, 1.65, -1.30), WHITE)
	part(
		"InstrumentPanel",
		Vector3.new(2.13, 0.53, 0.12),
		CFrame.new(1.49, 2.10, -1.04) * CFrame.Angles(math.rad(18), 0, 0),
		DARK
	)
	for index, x in { 0.86, 1.49, 2.12 } do
		local radius = if index == 2 then 0.28 else 0.21
		local gauge = part(
			"GaugeRim",
			Vector3.new(0.05, radius, radius),
			CFrame.new(x, 2.12, -0.94) * CFrame.Angles(0, math.pi / 2, 0),
			METAL
		)
		gauge.Shape = Enum.PartType.Cylinder
		local dial = part(
			"GaugeFace",
			Vector3.new(0.06, radius * 0.78, radius * 0.78),
			CFrame.new(x, 2.12, -0.90) * CFrame.Angles(0, math.pi / 2, 0),
			DARK
		)
		dial.Shape = Enum.PartType.Cylinder
		beam("GaugeNeedle", Vector3.new(x, 2.12, -0.86), Vector3.new(x + 0.05, 2.19, -0.86), 0.018, 0.018, WHITE)
	end
	part("ThrottleBase", Vector3.new(0.21, 0.32, 0.55), CFrame.new(2.79, 1.70, 0.15), DARK)
	beam("ThrottleLever", Vector3.new(2.79, 1.84, 0.15), Vector3.new(2.79, 2.12, 0.02), 0.06, 0.06, METAL)
	part("ThrottleGrip", Vector3.new(0.16, 0.14, 0.16), CFrame.new(2.79, 2.13, 0.02), DARK)
	local wheelCenter = Vector3.new(1.49, 2.36, -0.37)
	for index = 0, 11 do
		local a, b = index * math.pi / 6, (index + 1) * math.pi / 6
		beam(
			"SteeringWheel",
			wheelCenter + Vector3.new(math.cos(a) * 0.39, math.sin(a) * 0.39, 0),
			wheelCenter + Vector3.new(math.cos(b) * 0.39, math.sin(b) * 0.39, 0),
			0.065,
			0.065,
			DARK
		)
	end
	for index = 0, 2 do
		local a = index * math.pi * 2 / 3
		beam(
			"WheelSpoke",
			wheelCenter,
			wheelCenter + Vector3.new(math.cos(a) * 0.35, math.sin(a) * 0.35, 0),
			0.045,
			0.045,
			METAL
		)
	end

	-- Sculpted outboard cowling, vents, mounting bracket and submerged lower unit.
	part("MotorMount", Vector3.new(1.50, 0.42, 0.80), CFrame.new(0, 1.05, 12.65), METAL)
	part("OutboardCover", Vector3.new(1.65, 1.64, 1.45), CFrame.new(0, 1.46, 13.48), DARK)
	part("OutboardCrown", Vector3.new(1.44, 0.28, 1.23), CFrame.new(0, 2.40, 13.42), UPHOLSTERY)
	part(
		"OutboardFront",
		Vector3.new(1.36, 1.25, 0.28),
		CFrame.new(0, 1.50, 12.65) * CFrame.Angles(math.rad(-12), 0, 0),
		DARK
	)
	for _, side in { -1, 1 } do
		part("OutboardBadge", Vector3.new(0.025, 0.12, 1.05), CFrame.new(side * 0.84, 1.96, 13.48), WHITE)
		for index = 0, 3 do
			part(
				"OutboardVent",
				Vector3.new(0.026, 0.065, 0.50),
				CFrame.new(side * 0.84, 1.45 + index * 0.14, 13.55),
				METAL
			)
		end
		part("MotorBracket", Vector3.new(0.16, 0.78, 0.25), CFrame.new(side * 0.55, 0.68, 12.66), METAL)
	end
	part("OutboardLeg", Vector3.new(0.34, 1.75, 0.67), CFrame.new(0, -0.23, 13.48), DARK)
	part("CavitationPlate", Vector3.new(1.03, 0.07, 1.06), CFrame.new(0, -0.62, 13.55), DARK)
	local hub = part(
		"PropellerHub",
		Vector3.new(0.70, 0.29, 0.29),
		CFrame.new(0, -1.10, 13.88) * CFrame.Angles(0, math.pi / 2, 0),
		METAL
	)
	hub.Shape = Enum.PartType.Cylinder
	for index = 0, 2 do
		local angle = index * math.pi * 2 / 3
		part(
			"PropellerBlade",
			Vector3.new(0.27, 0.73, 0.07),
			CFrame.new(math.sin(angle) * 0.34, -1.10 + math.cos(angle) * 0.34, 14.23) * CFrame.Angles(0, 0, -angle),
			METAL
		)
	end
	for _, side in { -1, 1 } do
		part("SwimPlatform", Vector3.new(2.10, 0.18, 1.18), CFrame.new(side * 2.22, 0.75, 12.95), WHITE, nil, true)
		for index = 0, 3 do
			part(
				"PlatformGrip",
				Vector3.new(1.64, 0.025, 0.08),
				CFrame.new(side * 2.22, 0.855, 12.58 + index * 0.22),
				DECK
			)
		end
		for _, z in { -5.5, 11.8 } do
			local width, top = stationAt(z)
			local x = side * (width - 0.35)
			part("CleatBase", Vector3.new(0.22, 0.06, 0.50), CFrame.new(x, top + 0.06, z), METAL)
			part("DeckCleat", Vector3.new(0.48, 0.08, 0.12), CFrame.new(x, top + 0.16, z), METAL)
		end
		local color = if side < 0 then Color3.fromRGB(211, 61, 53) else Color3.fromRGB(53, 189, 115)
		part("NavigationLightBase", Vector3.new(0.19, 0.10, 0.36), CFrame.new(side * 3.62, 1.98, -2.35), METAL)
		part(
			"NavigationLight",
			Vector3.new(0.12, 0.07, 0.24),
			CFrame.new(side * 3.62, 2.06, -2.35),
			color,
			Enum.Material.Neon
		)
	end
	return model
end

return RacingSpeedboat
