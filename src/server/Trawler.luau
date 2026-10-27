-- Traditional teal stern trawler. Waterline origin; local -Z is the bow.
-- One welded assembly, with a continuous deck and a walk-in forward wheelhouse.
local Trawler = { VERSION = 1 }

local V, F, rgb = Vector3.new, CFrame.new, Color3.fromRGB
local M = Enum.Material
local TEAL = rgb(65, 140, 143)
local TEAL_DARK = rgb(43, 96, 99)
local CREAM = rgb(232, 230, 210)
local WHITE = rgb(241, 239, 222)
local BROWN = rgb(100, 69, 53)
local ANTIFOUL = rgb(66, 49, 47)
local DECK = rgb(143, 134, 109)
local DARK = rgb(37, 43, 42)
local STEEL = rgb(163, 171, 160)
local ROPE = rgb(183, 161, 115)
local NET = rgb(69, 112, 83)
local GLASS = rgb(67, 99, 105)
local ORANGE = rgb(220, 113, 48)
local LAMP = rgb(255, 235, 190)

function Trawler.build(frame: CFrame, anchored: boolean?): Model
	local isAnchored = anchored == true
	local model = Instance.new("Model")
	model.Name = "Trawler"
	model:SetAttribute("ModelVersion", Trawler.VERSION)
	model:SetAttribute("HullLength", 44)
	model:SetAttribute("HullBeam", 14.8)
	model:SetAttribute("PassengerSeats", 2)
	model:SetAttribute("DriverSeat", "HelmSeat")
	model:SetAttribute("DryFloorHeight", 1.45)
	model:SetAttribute("DryFloorHalfBeam", 6.45)
	model:SetAttribute("DryFloorHalfLength", 21.7)

	local root = Instance.new("Part")
	root.Name, root.Size, root.CFrame = "HullRoot", V(9, 0.6, 32), frame * F(0, -0.4, 0)
	root.Transparency, root.Anchored = 1, isAnchored
	root.CanCollide, root.CanTouch = false, false
	root.RootPriority = 127
	root.CustomPhysicalProperties = PhysicalProperties.new(1.4, 0.45, 0.05, 100, 100)
	root.Parent, model.PrimaryPart = model, root

	local function finish(p: BasePart, name: string, color: Color3, material: Enum.Material?, collide: boolean?)
		p.Name, p.Anchored, p.Massless = name, isAnchored, true
		p.CanCollide, p.CanTouch = collide == true, false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Color, p.Material = color, material or M.SmoothPlastic
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = root, p, p
		return p
	end
	local function part(
		name: string,
		size: Vector3,
		cf: CFrame,
		color: Color3,
		material: Enum.Material?,
		collide: boolean?
	): Part
		local p = Instance.new("Part")
		p.Size, p.CFrame = size, frame * cf
		finish(p, name, color, material, collide)
		return p
	end
	local function beam(
		name: string,
		a: Vector3,
		b: Vector3,
		width: number,
		color: Color3,
		material: Enum.Material?
	): Part
		-- fromMatrix also supports vertical lines, for which lookAt's default up is parallel.
		local back = (a - b).Unit
		local reference = if math.abs(back.Y) > 0.98 then V(1, 0, 0) else V(0, 1, 0)
		local right = reference:Cross(back).Unit
		return part(
			name,
			V(width, width, (b - a).Magnitude),
			CFrame.fromMatrix((a + b) / 2, right, back:Cross(right), back),
			color,
			material
		)
	end
	local function cylinder(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
		local p = part(name, size, cf, color, material)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	local function ring(
		name: string,
		center: Vector3,
		radius: number,
		thickness: number,
		axis: string,
		color: Color3,
		segments: number?
	)
		local count = segments or 12
		local function point(angle)
			local a, b = math.cos(angle) * radius, math.sin(angle) * radius
			return center + (if axis == "X" then V(0, a, b) elseif axis == "Y" then V(a, 0, b) else V(a, b, 0))
		end
		for i = 0, count - 1 do
			beam(name, point(i * math.pi * 2 / count), point((i + 1) * math.pi * 2 / count), thickness, color)
		end
	end
	local function triangle(name: string, a: Vector3, b: Vector3, c: Vector3, inside: Vector3, color: Color3)
		local ab, ac, bc = b - a, c - a, c - b
		local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
		if abd > acd and abd > bcd then
			c, a = a, c
		elseif acd > bcd and acd > abd then
			a, b = b, a
		end
		ab, ac, bc = b - a, c - a, c - b
		local right, back = ac:Cross(ab).Unit, bc.Unit
		local up = bc:Cross(right).Unit
		local height = math.abs(ab:Dot(up))
		local normal = if right:Dot((a + b + c) / 3 - inside) >= 0 then right else -right
		local shift = -normal * 0.09
		for _, spec in
			{
				{ (a + b) / 2, right, back, math.abs(ab:Dot(back)) },
				{ (a + c) / 2, -right, -back, math.abs(ac:Dot(back)) },
			}
		do
			local p = Instance.new("WedgePart")
			p.Size = V(0.18, height, spec[4])
			p.CFrame = frame * CFrame.fromMatrix(spec[1] + shift, spec[2], up, spec[3])
			finish(p, name, color, nil, true)
		end
	end
	local function quad(name, a, b, c, d, color, inside)
		triangle(name, a, b, c, inside or V(0, 1, 0), color)
		triangle(name, a, c, d, inside or V(0, 1, 0), color)
	end

	-- Round-bilged working hull: fine raised bow, broad shoulders and a full transom.
	local stations = {
		{ z = -22, w = 0.20, b = 0.12, top = 4.2, keel = -0.15, chine = 0.25 },
		{ z = -19, w = 3.3, b = 1.7, top = 3.95, keel = -1.4, chine = -0.35 },
		{ z = -14, w = 5.9, b = 4.3, top = 3.55, keel = -2.4, chine = -0.65 },
		{ z = -7, w = 7.25, b = 5.9, top = 3.15, keel = -2.85, chine = -0.75 },
		{ z = 3, w = 7.25, b = 6.15, top = 3.0, keel = -2.85, chine = -0.75 },
		{ z = 13, w = 7.0, b = 5.95, top = 3.0, keel = -2.55, chine = -0.75 },
		{ z = 21.8, w = 6.15, b = 5.1, top = 3.1, keel = -1.95, chine = -0.65 },
	}
	local function edge(s, side, t)
		return V(side * (s.b + (s.w - s.b) * t), s.chine + (s.top - s.chine) * t, s.z)
	end
	local function bottom(s, side, level)
		if level == 0 then
			return edge(s, side, 0)
		elseif level == 1 then
			return V(side * s.b * 0.56, s.keel + (s.chine - s.keel) * 0.34, s.z)
		end
		return V(0, s.keel, s.z)
	end
	for _, side in { -1, 1 } do
		for i = 1, #stations - 1 do
			local a, b = stations[i], stations[i + 1]
			for _, band in { { 0, 0.21, WHITE }, { 0.21, 1, TEAL } } do
				quad(
					"HullPanel",
					edge(a, side, band[1]),
					edge(b, side, band[1]),
					edge(b, side, band[2]),
					edge(a, side, band[2]),
					band[3]
				)
			end
			for level = 0, 1 do
				quad(
					if level == 0 then "BilgePanel" else "BottomPanel",
					bottom(a, side, level),
					bottom(b, side, level),
					bottom(b, side, level + 1),
					bottom(a, side, level + 1),
					ANTIFOUL
				)
			end
			beam("Gunwale", edge(a, side, 1), edge(b, side, 1), 0.22, CREAM)
			local offset = V(side * 0.11, 0, 0)
			beam("SheerStripe", edge(a, side, 0.78) + offset, edge(b, side, 0.78) + offset, 0.085, WHITE)
			beam("RubbingStrake", edge(a, side, 0.53) + offset, edge(b, side, 0.53) + offset, 0.16, TEAL_DARK)
		end
	end
	for _, s in { stations[1], stations[#stations] } do
		quad("Transom", edge(s, -1, 0), edge(s, 1, 0), edge(s, 1, 0.21), edge(s, -1, 0.21), WHITE)
		quad("Transom", edge(s, -1, 0.21), edge(s, 1, 0.21), edge(s, 1, 1), edge(s, -1, 1), TEAL)
		for _, side in { -1, 1 } do
			triangle("HullEndCap", bottom(s, side, 0), bottom(s, side, 1), bottom(s, side, 2), V(0, 1, 0), ANTIFOUL)
			triangle("HullEndCap", bottom(s, side, 0), bottom(s, side, 2), V(0, s.chine, s.z), V(0, 1, 0), ANTIFOUL)
		end
	end
	beam("TransomCap", edge(stations[#stations], -1, 1), edge(stations[#stations], 1, 1), 0.25, CREAM)
	for i = 1, #stations - 1 do
		beam("Keel", bottom(stations[i], 1, 2), bottom(stations[i + 1], 1, 2), 0.25, ANTIFOUL)
	end

	-- Individual flush planks follow the narrowing hull; no deck overhangs the bow.
	local function deckWidth(s)
		return s.b + (s.w - s.b) * (1.45 - s.chine) / (s.top - s.chine) - 0.18
	end
	for i = -10, 10 do
		local outside = (math.abs(i) + 0.5) * 0.6
		local startZ, endZ = stations[1].z, stations[#stations].z - 0.15
		for j = 1, #stations - 1 do
			local a, b = stations[j], stations[j + 1]
			local wa, wb = deckWidth(a), deckWidth(b)
			if wa < outside and wb >= outside then
				startZ = a.z + (b.z - a.z) * (outside - wa) / (wb - wa)
			elseif wa >= outside and wb < outside then
				endZ = a.z + (b.z - a.z) * (outside - wa) / (wb - wa)
			end
		end
		part("WorkingDeck", V(0.6, 0.24, endZ - startZ), F(i * 0.6, 1.33, (startZ + endZ) / 2), DECK, M.Wood, true)
	end
	for _, side in { -1, 1 } do
		for _, z in { -10, -3, 4, 11, 18 } do
			part("BulwarkRib", V(0.16, 1.4, 0.18), F(side * (if z == 18 then 5.88 else 6.35), 2.2, z), CREAM, M.Metal)
		end
		for _, z in { 0, 10, 17.8 } do
			part("Scupper", V(0.07, 0.2, 0.76), F(side * (if z > 15 then 6.25 else 6.76), 0.52, z), DARK)
		end
	end

	-- Brown lower cabin and cream upper window frames, with an open aft doorway.
	part("CabinFrontLower", V(6.8, 3.2, 0.22), F(0, 3.05, -12.15), BROWN, M.Wood, true)
	for _, side in { -1, 1 } do
		part("CabinSideLower", V(0.22, 3.2, 8.9), F(side * 3.3, 3.05, -7.7), BROWN, M.Wood, true)
		part("CabinSideHeader", V(0.26, 0.42, 9.5), F(side * 3.3, 8.04, -7.85), CREAM, nil, true)
		part("CabinSill", V(0.34, 0.17, 9.12), F(side * 3.3, 4.7, -7.7), CREAM)
		for _, z in { -11.98, -8.98, -6.0, -3.3 } do
			part("CabinWindowPost", V(0.28, 3.12, 0.2), F(side * 3.3, 6.26, z), CREAM, nil, true)
		end
		for _, z in { -10.48, -7.48, -4.65 } do
			local glass = part(
				"CabinSideWindow",
				V(0.09, 2.92, if z == -4.65 then 2.48 else 2.76),
				F(side * 3.3, 6.26, z),
				GLASS,
				nil,
				true
			)
			glass.Transparency = 0.3
		end
		-- Tongue-and-groove cladding and contrasting corner boards.
		for z = -11.6, -3.6, 0.8 do
			part("CabinCladdingSeam", V(0.025, 2.95, 0.025), F(side * 3.421, 3.02, z), ANTIFOUL)
		end
		part("CabinRearPanel", V(1.95, 6.35, 0.22), F(side * 2.36, 4.625, -3.25), BROWN, M.Wood, true)
		local rearGlass = part("CabinRearWindow", V(1.32, 2.36, 0.09), F(side * 2.36, 6.25, -3.38), GLASS)
		rearGlass.Transparency = 0.22
		part("DoorJamb", V(0.14, 6.35, 0.3), F(side * 1.33, 4.625, -3.25), CREAM, nil, true)
		beam("CabinGrabRail", V(side * 3.6, 3.0, -5.3), V(side * 3.6, 4.6, -5.3), 0.11, STEEL, M.Metal)
	end
	part("DoorHeader", V(6.8, 0.5, 0.3), F(0, 8.04, -3.25), CREAM, nil, true)
	-- Raked front glazing, black seals, paired windscreens and tiny wipers.
	local front = F(0, 6.28, -12.43) * CFrame.Angles(math.rad(-10), 0, 0)
	for _, x in { -3.3, -1.1, 1.1, 3.3 } do
		part("WindscreenMullion", V(0.17, 3.24, 0.18), front * F(x, 0, 0), CREAM, nil, true)
	end
	for _, x in { -2.2, 0, 2.2 } do
		part("WindscreenSeal", V(2.05, 3.07, 0.09), front * F(x, 0, 0.015), DARK)
		local window = part("Windscreen", V(1.89, 2.91, 0.12), front * F(x, 0, -0.065), GLASS, nil, true)
		window.Transparency = 0.27
		part("WiperArm", V(0.055, 1.43, 0.045), front * F(x + 0.3, -0.48, -0.15) * CFrame.Angles(0, 0, -0.3), DARK)
	end
	part("CabinRoof", V(7.65, 0.33, 10.25), F(0, 8.42, -8.0), CREAM, nil, true)
	part("RoofFascia", V(7.82, 0.16, 10.4), F(0, 8.24, -8.0), WHITE)
	for _, x in { -2.5, 0, 2.5 } do
		part("RoofSeam", V(0.045, 0.045, 9.9), F(x, 8.61, -8.0), WHITE)
	end

	part("HelmConsole", V(3.0, 1.3, 1.2), F(0, 2.1, -10.65), TEAL_DARK)
	part("ConsoleTop", V(3.22, 0.18, 1.36), F(0, 2.85, -10.65), BROWN, M.Wood)
	part("InstrumentPanel", V(2.6, 0.68, 0.12), F(0, 3.27, -10.0), DARK)
	for _, x in { -0.92, -0.45, 0.05 } do
		cylinder("GaugeBezel", V(0.08, 0.34, 0.34), F(x, 3.3, -9.9) * CFrame.Angles(0, math.pi / 2, 0), STEEL, M.Metal)
		cylinder("GaugeFace", V(0.09, 0.26, 0.26), F(x, 3.3, -9.85) * CFrame.Angles(0, math.pi / 2, 0), CREAM)
		part("GaugeNeedle", V(0.025, 0.1, 0.02), F(x + 0.02, 3.33, -9.79) * CFrame.Angles(0, 0, -0.5), DARK)
	end
	part("FishfinderFrame", V(0.65, 0.51, 0.16), F(0.83, 3.38, -9.93), DARK)
	part("FishfinderScreen", V(0.51, 0.35, 0.025), F(0.83, 3.38, -9.83), rgb(72, 152, 123), M.Neon)
	beam("ThrottleLever", V(1.15, 2.97, -9.7), V(1.15, 3.45, -9.9), 0.075, STEEL)
	part("ThrottleGrip", V(0.19, 0.14, 0.22), F(1.15, 3.45, -9.9), DARK)
	ring("HelmWheel", V(0, 3.35, -9.6), 0.55, 0.095, "Z", BROWN)
	for i = 0, 3 do
		local a = i * math.pi / 2
		beam("HelmSpoke", V(0, 3.35, -9.6), V(math.cos(a) * 0.5, 3.35 + math.sin(a) * 0.5, -9.6), 0.065, STEEL)
	end
	part("HelmPedestal", V(0.48, 0.8, 0.48), F(0, 1.85, -7.8), DARK)
	part("HelmCushion", V(2.0, 0.25, 1.65), F(0, 2.38, -7.8), BROWN)
	part("HelmBack", V(2.0, 1.3, 0.22), F(0, 3.12, -7.02), BROWN)
	local helm = Instance.new("VehicleSeat")
	helm.Size, helm.CFrame = V(2.0, 0.24, 1.65), frame * F(0, 2.42, -7.8)
	helm.Transparency, helm.HeadsUpDisplay = 1, false
	helm.MaxSpeed, helm.Torque, helm.TurnSpeed = 0, 0, 0
	finish(helm, "HelmSeat", BROWN)
	helm.CanTouch, helm.Disabled = not isAnchored, isAnchored
	-- Two aft fishing seats leave the center of the working deck open.
	for _, side in { -1, 1 } do
		part("PassengerPedestal", V(0.42, 0.75, 0.42), F(side * 4.65, 1.85, 0.1), TEAL_DARK)
		part("PassengerCushion", V(1.9, 0.24, 1.5), F(side * 4.65, 2.3, 0.1), CREAM)
		part("PassengerBack", V(1.9, 1.0, 0.2), F(side * 4.65, 2.91, -0.58), BROWN)
		local seat = Instance.new("Seat")
		seat.Size = V(1.9, 0.24, 1.5)
		seat.CFrame = frame * F(side * 4.65, 2.35, 0.1) * CFrame.Angles(0, math.pi, 0)
		seat.Transparency = 1
		finish(seat, if side < 0 then "FishingSeatPort" else "FishingSeatStarboard", CREAM)
		seat.CanTouch, seat.Disabled = not isAnchored, isAnchored
	end

	-- Stainless foredeck rails follow the raised bow's sheer.
	for _, side in { -1, 1 } do
		local points = {
			V(side * 0.25, 5.45, -21.6),
			V(side * 3.15, 5.2, -18.8),
			V(side * 5.65, 4.85, -13.8),
			V(side * 6.8, 4.45, -8.3),
		}
		for i, p in points do
			beam("BowRailPost", p - V(0, 1.3, 0), p, 0.11, STEEL, M.Metal)
			if i > 1 then
				beam("BowRail", points[i - 1], p, 0.11, STEEL, M.Metal)
				beam("BowMidRail", points[i - 1] - V(0, 0.63, 0), p - V(0, 0.63, 0), 0.07, STEEL)
			end
		end
		for _, z in { -15.2, 2.3, 18.7 } do
			local x = side * (if z < -10 then 4.3 elseif z > 15 then 5.95 else 6.9)
			part("CleatFoot", V(0.5, 0.16, 0.7), F(x, 3.14, z), STEEL, M.Metal)
			part("MooringCleat", V(0.24, 0.22, 1.05), F(x, 3.31, z), STEEL, M.Metal)
		end
	end
	cylinder("AnchorWindlass", V(1.6, 0.75, 0.75), F(0, 1.95, -17.2), TEAL_DARK, M.Metal)
	part("AnchorChainBed", V(0.3, 0.13, 3.3), F(0, 1.55, -19.05), DARK)
	for z = -20.4, -17.8, 0.32 do
		ring("AnchorChainLink", V(0, 1.65, z), 0.12, 0.045, "Y", STEEL, 6)
	end

	-- Hollow tire fenders hang clear of the hull; pale rope lashings and tread bands.
	for _, side in { -1, 1 } do
		for _, z in { -6.5, 4, 15.5 } do
			local x = side * (if z > 10 then 7.06 else 7.43)
			local center = V(x, 0.95, z)
			ring("TireFender", center, 0.81, 0.3, "X", DARK, 14)
			ring("TireSidewall", center + V(side * 0.17, 0, 0), 0.74, 0.1, "X", ANTIFOUL, 14)
			beam("FenderLashing", center + V(0, 0.8, 0), V(x - side * 0.35, 3.2, z + 0.12), 0.055, ROPE)
		end
	end
	-- Short cream rubbing pads break up the long teal sides like the reference.
	for _, side in { -1, 1 } do
		for _, z in { -1.5, 8.7, 18.2 } do
			part("HullRubbingPad", V(0.16, 0.43, 0.95), F(side * (if z > 15 then 6.55 else 7.05), 1.66, z), CREAM)
		end
	end

	-- Stern A-frame with diagonal bracing, sheaves, a forward boom and taut stays.
	for _, side in { -1, 1 } do
		beam("GantryLeg", V(side * 5.1, 1.5, 16.3), V(side * 4.15, 12.65, 16.3), 0.35, CREAM, M.Metal)
		beam("GantryBrace", V(side * 5.0, 2.2, 19.8), V(side * 4.15, 11.9, 16.3), 0.2, STEEL, M.Metal)
		part("GantryFoot", V(0.85, 0.16, 1.05), F(side * 5.1, 1.55, 16.3), TEAL_DARK, M.Metal)
		beam("GantryStay", V(side * 4.15, 12.5, 16.3), V(side * 5.9, 3.1, 5.0), 0.045, STEEL)
		cylinder("GantrySheave", V(0.25, 0.66, 0.66), F(side * 3.35, 12.7, 16.3), DARK, M.Metal)
	end
	beam("GantryCrossbar", V(-4.5, 12.7, 16.3), V(4.5, 12.7, 16.3), 0.38, CREAM, M.Metal)
	beam("GantryTopRail", V(-4.15, 13.55, 16.3), V(4.15, 13.55, 16.3), 0.1, STEEL)
	for _, x in { -4.15, 0, 4.15 } do
		beam("GantryGuardPost", V(x, 12.7, 16.3), V(x, 13.55, 16.3), 0.1, STEEL)
	end
	beam("TrawlBoom", V(0, 11.7, 16.3), V(0, 8.7, 5.2), 0.26, CREAM, M.Metal)
	beam("BoomStay", V(0, 13.2, 16.3), V(0, 8.7, 5.2), 0.045, STEEL)
	beam("TrawlCable", V(0, 8.7, 5.2), V(-2.7, 5.1, 7.8), 0.045, DARK)
	cylinder("BoomPulley", V(0.25, 0.55, 0.55), F(0, 8.65, 5.2), DARK, M.Metal)

	-- Green net drum, flanged cheeks, motor, visible wound net and hand controls.
	for _, x in { -4.65, -0.75 } do
		part("WinchPedestal", V(0.4, 1.35, 1.65), F(x, 2.12, 8.3), TEAL_DARK, M.Metal)
		cylinder("DrumFlange", V(0.18, 3.5, 3.5), F(x, 3.9, 8.3), CREAM, M.Metal)
		cylinder("DrumHub", V(0.3, 0.5, 0.5), F(x, 3.9, 8.3), STEEL, M.Metal)
	end
	cylinder("NetDrum", V(3.7, 3.15, 3.15), F(-2.7, 3.9, 8.3), NET)
	for x = -4.4, -1.0, 0.25 do
		ring("WoundNetRib", V(x, 3.9, 8.3), 1.59, 0.055, "X", TEAL_DARK, 12)
	end
	for i = 0, 9 do
		local a = i * math.pi / 5
		beam(
			"WoundNetStrand",
			V(-4.45, 3.9 + math.cos(a) * 1.61, 8.3 + math.sin(a) * 1.61),
			V(-0.95, 3.9 + math.cos(a + 0.5) * 1.61, 8.3 + math.sin(a + 0.5) * 1.61),
			0.045,
			ROPE
		)
	end
	cylinder("WinchMotor", V(0.85, 0.85, 0.85), F(-5.05, 2.7, 8.3), TEAL_DARK, M.Metal)
	part("WinchControlBox", V(0.6, 0.75, 0.45), F(-0.75, 2.58, 6.9), STEEL, M.Metal)
	beam("WinchLever", V(-0.75, 2.9, 6.9), V(-0.75, 3.45, 6.75), 0.065, DARK)
	-- Stowed lattice net is attached to the port quarter, clear of the passage.
	for i = 0, 7 do
		local z = 12.0 + i * 0.64
		beam("StowedNetMesh", V(-5.6, 1.6, z), V(-2.9, 2.6, z + 1.8), 0.055, NET)
		beam("StowedNetMesh", V(-5.6, 2.6, z + 1.8), V(-2.9, 1.6, z), 0.055, NET)
	end
	for _, z in { 12.2, 13.6, 15.0 } do
		local float = part("NetFloat", V(0.4, 0.52, 0.4), F(-5.55, 2.8, z), ORANGE)
		float.Shape = Enum.PartType.Ball
	end
	-- Flat cargo hatches with hinges and recessed handles.
	for _, z in { 2.5, 13.3 } do
		part("CargoHatchRim", V(3.0, 0.09, 2.5), F(0.65, 1.5, z), STEEL, M.Metal)
		part("CargoHatch", V(2.72, 0.07, 2.22), F(0.65, 1.58, z), TEAL_DARK, M.DiamondPlate)
		for _, x in { -0.3, 1.6 } do
			part("HatchHinge", V(0.32, 0.08, 0.18), F(x, 1.65, z - 1.1), STEEL)
		end
		part("HatchHandle", V(0.6, 0.05, 0.16), F(0.65, 1.64, z + 0.65), DARK)
	end
	for _, z in { 9.8, 12.0 } do
		part("FishCrate", V(1.7, 0.95, 1.55), F(4.9, 1.95, z), BROWN, M.Wood)
		part("CrateRim", V(1.82, 0.13, 1.67), F(4.9, 2.48, z), ROPE, M.Wood)
		for dz = -0.55, 0.55, 0.36 do
			part("CrateSlat", V(1.74, 0.08, 0.09), F(4.9, 2.55, z + dz), DECK)
		end
	end
	for i = 0, 2 do
		ring("RopeCoil", V(4.65, 1.58 + i * 0.06, 16.5), 0.5 + i * 0.16, 0.1, "Y", ROPE)
	end
	-- Stern boards, bollards and a center boarding gap with a short ladder.
	for x = -4.8, 4.8, 0.8 do
		part("TransomPlankSeam", V(0.025, 2.2, 0.025), F(x, 1.96, 21.91), TEAL_DARK)
	end
	for _, x in { -1.35, 1.35 } do
		beam("BoardingLadderRail", V(x, -0.1, 22.0), V(x, 3.3, 22.0), 0.12, STEEL, M.Metal)
	end
	for _, y in { 0.3, 1.1, 1.9, 2.7 } do
		part("BoardingRung", V(2.7, 0.16, 0.32), F(0, y, 22.0), STEEL, M.Metal, true)
	end

	-- Radar, swept mast, aerials, horn, exhaust and navigation lamps.
	part("RadarPedestal", V(0.65, 0.65, 0.65), F(0.7, 8.94, -10.1), TEAL_DARK)
	part("RadarScanner", V(2.65, 0.2, 0.65), F(0.7, 9.38, -10.1), CREAM)
	beam("Foremast", V(-0.6, 8.6, -7.0), V(-0.6, 15.6, -9.8), 0.17, CREAM, M.Metal)
	beam("MastAerial", V(-0.6, 15.6, -9.8), V(-0.6, 18.3, -10.9), 0.035, STEEL)
	beam("RadioAerial", V(2.2, 8.6, -5.0), V(2.2, 12.2, -5.15), 0.045, STEEL)
	beam("MastCrossbar", V(-2.2, 13.3, -8.9), V(1.0, 13.3, -8.9), 0.13, CREAM)
	for _, side in { -1, 1 } do
		beam("MastStay", V(-0.6, 15.4, -9.7), V(side * 3.2, 8.6, -4.3), 0.025, STEEL)
	end
	cylinder("ExhaustStack", V(1.1, 0.45, 0.45), F(-2.25, 9.1, -4.6) * CFrame.Angles(0, 0, math.pi / 2), DARK, M.Metal)
	part("ExhaustCap", V(0.65, 0.15, 0.55), F(-2.25, 9.72, -4.6), DARK)
	cylinder("RoofHorn", V(0.85, 0.28, 0.28), F(2.3, 8.92, -10.8) * CFrame.Angles(0, math.pi / 2, 0), STEEL, M.Metal)
	part("MastLamp", V(0.25, 0.3, 0.25), F(-0.6, 15.7, -9.8), LAMP, M.Neon)
	for _, side in { -1, 1 } do
		part("NavigationLampHousing", V(0.5, 0.35, 0.6), F(side * 3.65, 8.62, -9.1), TEAL_DARK)
		part(
			"NavigationLamp",
			V(0.25, 0.22, 0.3),
			F(side * 3.72, 8.8, -9.1),
			if side < 0 then rgb(218, 53, 44) else rgb(65, 194, 95),
			M.Neon
		)
		part("HeadlightHousing", V(0.7, 0.6, 0.6), F(side * 2.3, 8.92, -12.6), TEAL_DARK, M.Metal)
		local lens = part("HeadlightLens", V(0.53, 0.4, 0.055), F(side * 2.3, 8.92, -12.93), LAMP, M.Neon)
		local light = Instance.new("SpotLight")
		light.Name, light.Face = "Headlight", Enum.NormalId.Front
		light.Color, light.Range, light.Brightness, light.Angle = LAMP, 60, 1.2, 65
		light.Shadows, light.Parent = false, lens
	end
	for _, z in { -3.0, 16.3 } do
		local p = part("DeckWorkLamp", V(0.7, 0.24, 0.55), F(0, if z < 0 then 8.0 else 12.4, z), LAMP, M.Neon)
		local light = Instance.new("PointLight")
		light.Name, light.Color, light.Range, light.Brightness = "DeckLight", LAMP, 22, 0.65
		light.Shadows, light.Parent = false, p
	end
	-- Lifebuoy on the aft cabin wall with four white bindings.
	ring("LifeRing", V(2.3, 3.4, -3.07), 0.65, 0.22, "Z", ORANGE)
	for i = 0, 3 do
		local a = i * math.pi / 2
		part(
			"LifeRingBinding",
			V(0.23, 0.28, 0.24),
			F(2.3 + math.cos(a) * 0.65, 3.4 + math.sin(a) * 0.65, -3.06) * CFrame.Angles(0, 0, a),
			WHITE
		)
	end

	-- Painted registration boards follow the flared shoulders so no lettering sinks into the plating.
	for _, side in { -1, 1 } do
		local plate = part(
			"RegistrationPlate",
			V(0.09, 0.55, 3.5),
			F(side * 6.30, 2.6, -10.9) * CFrame.Angles(0, side * math.rad(11), -side * math.rad(20)),
			WHITE
		)
		local gui = Instance.new("SurfaceGui")
		gui.Name, gui.Face = "Registration", if side < 0 then Enum.NormalId.Left else Enum.NormalId.Right
		gui.SizingMode, gui.PixelsPerStud = Enum.SurfaceGuiSizingMode.PixelsPerStud, 70
		gui.Parent = plate
		local label = Instance.new("TextLabel")
		label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		label.Text, label.TextColor3, label.Font, label.TextScaled = "FW 463346", DARK, Enum.Font.GothamBold, true
		label.Parent = gui
	end
	-- Underwater single screw, shaft and rudder complete the drydock silhouette.
	cylinder("PropellerShaft", V(3.0, 0.16, 0.16), F(0, -1.65, 19.7) * CFrame.Angles(0, math.pi / 2, 0), STEEL, M.Metal)
	cylinder("PropellerHub", V(0.65, 0.4, 0.4), F(0, -1.65, 20.5) * CFrame.Angles(0, math.pi / 2, 0), ROPE, M.Metal)
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3
		part(
			"PropellerBlade",
			V(0.4, 0.95, 0.14),
			F(math.sin(a) * 0.48, -1.65 + math.cos(a) * 0.48, 20.5) * CFrame.Angles(0, 0, -a),
			ROPE,
			M.Metal
		)
	end
	part("Rudder", V(0.18, 1.8, 1.05), F(0, -1.5, 21.3), ANTIFOUL, M.Metal)
	return model
end

return Trawler
