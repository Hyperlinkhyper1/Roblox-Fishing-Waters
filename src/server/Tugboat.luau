-- Stocky black harbour tug. Waterline origin; local -Z is the bow.
-- Thick segmented rubber fender, green decks, a white deckhouse and a tall
-- all-round wheelhouse reached by stairs from the aft deck.
local Tugboat = { VERSION = 1 }

local V, F, rgb = Vector3.new, CFrame.new, Color3.fromRGB
local M = Enum.Material
local BLACK = rgb(34, 36, 38)
local BOOT = rgb(196, 72, 44)
local ANTIFOUL = rgb(132, 44, 36)
local WHITE = rgb(236, 238, 233)
local DECK = rgb(68, 150, 86)
local RAIL = rgb(52, 128, 74)
local RUBBER = rgb(62, 62, 64)
local RUBBER_DARK = rgb(44, 44, 46)
local GLASS = rgb(38, 72, 62)
local VISOR = rgb(30, 64, 58)
local YELLOW = rgb(232, 184, 46)
local ORANGE = rgb(226, 110, 40)
local STEEL = rgb(168, 172, 168)
local GRAY = rgb(146, 151, 149)
local DARK = rgb(30, 32, 34)
local LAMP = rgb(255, 235, 190)

local DECK_TOP = 1.6
local BRIDGE_TOP = 4.45
local ROOF_Y = 11.0

function Tugboat.build(frame: CFrame, anchored: boolean?): Model
	local isAnchored = anchored == true
	local model = Instance.new("Model")
	model.Name = "Tugboat"
	model:SetAttribute("ModelVersion", Tugboat.VERSION)
	model:SetAttribute("HullLength", 30)
	model:SetAttribute("HullBeam", 13.4)
	model:SetAttribute("PassengerSeats", 2)
	model:SetAttribute("DriverSeat", "HelmSeat")
	model:SetAttribute("DryFloorHeight", DECK_TOP)
	model:SetAttribute("DryFloorHalfBeam", 5.6)
	model:SetAttribute("DryFloorHalfLength", 14.6)

	local root = Instance.new("Part")
	root.Name, root.Size, root.CFrame = "HullRoot", V(9, 0.6, 22), frame * F(0, -0.4, 0)
	root.Transparency, root.Anchored = 1, isAnchored
	root.CanCollide, root.CanTouch = false, false
	root.RootPriority = 127
	root.CustomPhysicalProperties = PhysicalProperties.new(1.6, 0.45, 0.05, 100, 100)
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
		material: Enum.Material?,
		collide: boolean?
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
			material,
			collide
		)
	end
	local function cylinder(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
		local p = part(name, size, cf, color, material)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	-- A round bar from a to b; cylinders run along their local X axis.
	local function tube(name: string, a: Vector3, b: Vector3, diameter: number, color: Color3, collide: boolean?): Part
		local along = (b - a).Unit
		local reference = if math.abs(along.Y) > 0.98 then V(0, 0, 1) else V(0, 1, 0)
		local up = (reference - along * reference:Dot(along)).Unit
		local p = part(
			name,
			V((b - a).Magnitude, diameter, diameter),
			CFrame.fromMatrix((a + b) / 2, along, up, along:Cross(up)),
			color,
			nil,
			collide
		)
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

	-- Short, beamy push-tug hull: blunt rounded bow, parallel sides and a wide stern.
	local stations = {
		{ z = -15, w = 2.4, b = 1.3, top = 3.7, keel = -0.2, chine = 0.35 },
		{ z = -13.6, w = 4.6, b = 3.0, top = 3.55, keel = -1.3, chine = -0.3 },
		{ z = -11, w = 5.8, b = 4.6, top = 3.4, keel = -2.3, chine = -0.65 },
		{ z = -6, w = 6.3, b = 5.4, top = 3.3, keel = -2.7, chine = -0.75 },
		{ z = 5, w = 6.3, b = 5.4, top = 3.3, keel = -2.6, chine = -0.75 },
		{ z = 11.5, w = 6.0, b = 5.0, top = 3.35, keel = -1.9, chine = -0.65 },
		{ z = 15, w = 5.3, b = 4.0, top = 3.45, keel = -1.0, chine = -0.45 },
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
	local function deckT(s)
		return (DECK_TOP - s.chine) / (s.top - s.chine)
	end
	local function inset(p: Vector3, side: number, amount: number)
		return p - V(side * amount, 0, 0)
	end
	for _, side in { -1, 1 } do
		for i = 1, #stations - 1 do
			local a, b = stations[i], stations[i + 1]
			-- Red boot-top at the waterline, black topsides above.
			for _, band in { { 0, 0.2, BOOT }, { 0.2, 1, BLACK } } do
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
			-- White inner bulwark from the deck up to the rail.
			quad(
				"BulwarkLining",
				inset(edge(a, side, deckT(a)), side, 0.22),
				inset(edge(b, side, deckT(b)), side, 0.22),
				inset(edge(b, side, 1), side, 0.22),
				inset(edge(a, side, 1), side, 0.22),
				WHITE,
				V(0, 2.4, (a.z + b.z) / 2)
			)
			beam("Gunwale", edge(a, side, 1), edge(b, side, 1), 0.26, BLACK)
		end
	end
	for index, s in { stations[1], stations[#stations] } do
		quad("Transom", edge(s, -1, 0), edge(s, 1, 0), edge(s, 1, 0.2), edge(s, -1, 0.2), BOOT)
		quad("Transom", edge(s, -1, 0.2), edge(s, 1, 0.2), edge(s, 1, 1), edge(s, -1, 1), BLACK)
		local inward = V(0, 0, if index == 1 then 0.22 else -0.22)
		quad(
			"BulwarkLining",
			edge(s, -1, deckT(s)) + inward,
			edge(s, 1, deckT(s)) + inward,
			edge(s, 1, 1) + inward,
			edge(s, -1, 1) + inward,
			WHITE,
			V(0, 2.4, 0)
		)
		beam("Gunwale", edge(s, -1, 1), edge(s, 1, 1), 0.26, BLACK)
		for _, side in { -1, 1 } do
			triangle("HullEndCap", bottom(s, side, 0), bottom(s, side, 1), bottom(s, side, 2), V(0, 1, 0), ANTIFOUL)
			triangle("HullEndCap", bottom(s, side, 0), bottom(s, side, 2), V(0, s.chine, s.z), V(0, 1, 0), ANTIFOUL)
		end
	end
	for i = 1, #stations - 1 do
		beam("Keel", bottom(stations[i], 1, 2), bottom(stations[i + 1], 1, 2), 0.3, ANTIFOUL)
	end

	-- Green steel deck strips follow the hull's taper at both ends.
	local function deckWidth(s)
		return s.b + (s.w - s.b) * deckT(s) - 0.3
	end
	local STRIP = 0.65
	for i = -8, 8 do
		local outside = (math.abs(i) + 0.5) * STRIP
		local startZ, endZ = stations[1].z + 0.3, stations[#stations].z - 0.3
		for j = 1, #stations - 1 do
			local a, b = stations[j], stations[j + 1]
			local wa, wb = deckWidth(a), deckWidth(b)
			if wa < outside and wb >= outside then
				startZ = a.z + (b.z - a.z) * (outside - wa) / (wb - wa)
			elseif wa >= outside and wb < outside then
				endZ = a.z + (b.z - a.z) * (outside - wa) / (wb - wa)
			end
		end
		part(
			"WorkingDeck",
			V(STRIP, 0.24, endZ - startZ),
			F(i * STRIP, DECK_TOP - 0.12, (startZ + endZ) / 2),
			DECK,
			nil,
			true
		)
	end
	for _, side in { -1, 1 } do
		for _, z in { -8, 0, 8.5 } do
			part("Scupper", V(0.07, 0.22, 0.8), F(side * 6.12, 1.75, z), DARK)
		end
	end

	-- Segmented rubber fender wraps the whole sheer, like a ring of tyres pressed flat.
	local FENDER_T = 0.84
	local function fenderRun(points: { Vector3 }, diameter: number)
		local index = 0
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			local length = (b - a).Magnitude
			local pieces = math.max(1, math.round(length / 1.25))
			for k = 0, pieces - 1 do
				local from = a:Lerp(b, k / pieces)
				local to = a:Lerp(b, (k + 1) / pieces)
				local gap = (to - from).Unit * 0.05
				index += 1
				tube("Fender", from + gap, to - gap, diameter, if index % 2 == 0 then RUBBER else RUBBER_DARK)
			end
		end
	end
	for _, side in { -1, 1 } do
		local run = {}
		for _, s in stations do
			table.insert(run, edge(s, side, FENDER_T) + V(side * 0.42, 0, 0))
		end
		fenderRun(run, 1.0)
	end
	for index, s in { stations[1], stations[#stations] } do
		local out = if index == 1 then -0.42 else 0.42
		local y = s.chine + (s.top - s.chine) * FENDER_T
		local w = s.b + (s.w - s.b) * FENDER_T + 0.42
		fenderRun({ V(-w, y, s.z + out), V(w, y, s.z + out) }, 1.0)
	end
	-- Heavy pudding fender on the blunt bow for pushing.
	for _, y in { 2.05, 1.05 } do
		tube("BowFender", V(-2.0, y, -15.55), V(2.0, y, -15.55), 1.15, RUBBER_DARK)
	end
	for _, x in { -1.25, 0, 1.25 } do
		beam("FenderChain", V(x, 3.6, -15.1), V(x, 2.55, -15.6), 0.07, STEEL, M.Metal)
	end

	-- White deckhouse: the bridge deck is its roof.
	part(
		"Deckhouse",
		V(7.4, BRIDGE_TOP - 0.25 - DECK_TOP, 11.5),
		F(0, (DECK_TOP + BRIDGE_TOP - 0.25) / 2, -2.25),
		WHITE,
		nil,
		true
	)
	part("BridgeDeck", V(7.9, 0.25, 11.9), F(0, BRIDGE_TOP - 0.125, -2.25), DECK, nil, true)
	part("BridgeDeckEdge", V(8.0, 0.12, 12.0), F(0, BRIDGE_TOP - 0.31, -2.25), WHITE)
	for _, side in { -1, 1 } do
		for _, z in { -6.2, -3.6, -1.0, 1.6 } do
			cylinder("Porthole", V(0.1, 0.62, 0.62), F(side * 3.72, 3.15, z), STEEL, M.Metal)
			cylinder("PortholeGlass", V(0.12, 0.46, 0.46), F(side * 3.73, 3.15, z), GLASS)
		end
		-- Lifebuoys on the deckhouse sides with four white bindings.
		ring("LifeRing", V(side * 3.82, 2.9, 2.8), 0.62, 0.2, "X", ORANGE)
		for i = 0, 3 do
			local a = i * math.pi / 2
			part(
				"LifeRingBinding",
				V(0.22, 0.26, 0.24),
				F(side * 3.83, 2.9 + math.cos(a) * 0.62, 2.8 + math.sin(a) * 0.62) * CFrame.Angles(a, 0, 0),
				WHITE
			)
		end
	end
	part("DeckhouseDoor", V(1.3, 2.3, 0.08), F(-2.2, 2.8, 3.54), WHITE)
	part("DoorHandle", V(0.22, 0.08, 0.1), F(-1.75, 2.75, 3.6), DARK)

	-- Stairs from the aft deck up to the bridge deck, on the centerline.
	local STEPS = 7
	local rise = (BRIDGE_TOP - DECK_TOP) / STEPS
	local run = 0.75
	for i = 1, STEPS do
		local top = DECK_TOP + i * rise
		local z = 3.7 + (STEPS - i + 0.5) * run
		part("StairStep", V(2.4, top - DECK_TOP, run), F(0, (DECK_TOP + top) / 2, z), DECK, M.DiamondPlate, true)
		part("StairNosing", V(2.42, 0.06, 0.1), F(0, top + 0.02, z - run / 2 + 0.05), YELLOW)
	end
	for _, x in { -1.3, 1.3 } do
		local low, high = V(x, DECK_TOP + 1.1, 3.7 + STEPS * run), V(x, BRIDGE_TOP + 1.1, 3.7)
		beam("StairHandrail", low, high, 0.1, STEEL, M.Metal)
		beam("StairPost", low - V(0, 1.1, 0), low, 0.1, STEEL, M.Metal)
		beam("StairStringer", low - V(0, 1.0, 0), high - V(0, 1.0, 0), 0.2, WHITE)
	end

	-- Bridge deck railing; the aft edge leaves the stairwell open.
	local function railRun(a: Vector3, b: Vector3)
		beam("BridgeRail", a + V(0, 1.1, 0), b + V(0, 1.1, 0), 0.12, RAIL, M.Metal, true)
		beam("BridgeMidRail", a + V(0, 0.55, 0), b + V(0, 0.55, 0), 0.08, RAIL, M.Metal)
		local length = (b - a).Magnitude
		local posts = math.max(1, math.round(length / 1.6))
		for k = 0, posts do
			local p = a:Lerp(b, k / posts)
			beam("BridgeRailPost", p, p + V(0, 1.1, 0), 0.1, RAIL, M.Metal)
		end
	end
	local y0 = BRIDGE_TOP
	railRun(V(-3.85, y0, -8.1), V(3.85, y0, -8.1))
	railRun(V(-3.85, y0, -8.1), V(-3.85, y0, 3.6))
	railRun(V(3.85, y0, -8.1), V(3.85, y0, 3.6))
	railRun(V(-3.85, y0, 3.6), V(-1.35, y0, 3.6))
	railRun(V(1.35, y0, 3.6), V(3.85, y0, 3.6))

	-- Tall wheelhouse with tinted glass on every side and an aft doorway.
	local FRONT, AFT, HALF = -7.2, -1.2, 3.1
	local SILL, HEAD = 7.2, 10.6
	local midZ, depth = (FRONT + AFT) / 2, AFT - FRONT
	local lowerH, glassH = SILL - BRIDGE_TOP, HEAD - SILL
	part("WheelhouseFrontLower", V(HALF * 2, lowerH, 0.24), F(0, BRIDGE_TOP + lowerH / 2, FRONT), WHITE, nil, true)
	part(
		"WheelhouseHeader",
		V(HALF * 2 + 0.24, ROOF_Y - HEAD, 0.26),
		F(0, (HEAD + ROOF_Y) / 2, FRONT),
		WHITE,
		nil,
		true
	)
	part("WheelhouseHeader", V(HALF * 2 + 0.24, ROOF_Y - HEAD, 0.26), F(0, (HEAD + ROOF_Y) / 2, AFT), WHITE, nil, true)
	for _, x in { -HALF, -1.03, 1.03, HALF } do
		part("WindowPost", V(0.22, glassH, 0.26), F(x, (SILL + HEAD) / 2, FRONT), WHITE, nil, true)
	end
	for _, x in { -2.07, 0, 2.07 } do
		local pane =
			part("WheelhouseWindow", V(1.84, glassH, 0.1), F(x, (SILL + HEAD) / 2, FRONT - 0.02), GLASS, nil, true)
		pane.Transparency = 0.32
		part("WiperArm", V(0.05, 1.3, 0.04), F(x + 0.3, SILL + 0.7, FRONT - 0.1) * CFrame.Angles(0, 0, -0.3), DARK)
	end
	for _, side in { -1, 1 } do
		local x = side * HALF
		part("WheelhouseSideLower", V(0.24, lowerH, depth), F(x, BRIDGE_TOP + lowerH / 2, midZ), WHITE, nil, true)
		part("WheelhouseHeader", V(0.26, ROOF_Y - HEAD, depth), F(x, (HEAD + ROOF_Y) / 2, midZ), WHITE, nil, true)
		for _, z in { FRONT, midZ, AFT } do
			part("WindowPost", V(0.26, glassH, 0.22), F(x, (SILL + HEAD) / 2, z), WHITE, nil, true)
		end
		for _, z in { (FRONT + midZ) / 2, (midZ + AFT) / 2 } do
			local pane =
				part("WheelhouseWindow", V(0.1, glassH, depth / 2 - 0.22), F(x, (SILL + HEAD) / 2, z), GLASS, nil, true)
			pane.Transparency = 0.32
		end
		-- Aft wall panels either side of the 2.2-stud doorway.
		local panelX = side * (HALF + 1.1) / 2
		local panelW = HALF - 1.1
		part("WheelhouseAftLower", V(panelW, lowerH, 0.24), F(panelX, BRIDGE_TOP + lowerH / 2, AFT), WHITE, nil, true)
		local pane = part(
			"WheelhouseWindow",
			V(panelW - 0.2, glassH, 0.1),
			F(panelX, (SILL + HEAD) / 2, AFT + 0.02),
			GLASS,
			nil,
			true
		)
		pane.Transparency = 0.32
		part(
			"DoorJamb",
			V(0.16, HEAD - BRIDGE_TOP, 0.3),
			F(side * 1.18, (BRIDGE_TOP + HEAD) / 2, AFT),
			WHITE,
			nil,
			true
		)
		-- Painted name board on each side below the windows.
		local board = part("NameBoard", V(0.06, 0.55, 3.2), F(side * (HALF + 0.14), SILL - 0.6, midZ), WHITE)
		local gui = Instance.new("SurfaceGui")
		gui.Name, gui.Face = "Name", if side < 0 then Enum.NormalId.Left else Enum.NormalId.Right
		gui.SizingMode, gui.PixelsPerStud = Enum.SurfaceGuiSizingMode.PixelsPerStud, 70
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		label.Text, label.TextColor3, label.Font, label.TextScaled = "FW TUG 17", DARK, Enum.Font.GothamBold, true
		label.Parent = gui
	end
	part("WheelhouseRoof", V(HALF * 2 + 0.8, 0.3, depth + 0.8), F(0, ROOF_Y + 0.15, midZ), WHITE, nil, true)
	part("RoofVisor", V(HALF * 2 + 1.0, 0.4, depth + 1.0), F(0, ROOF_Y - 0.1, midZ), VISOR)
	part("WheelhouseFloor", V(HALF * 2 - 0.2, 0.06, depth - 0.2), F(0, BRIDGE_TOP + 0.03, midZ), DARK, M.Wood)

	-- Helm: console, joystick levers and screens, with the driver facing forward.
	part("HelmConsole", V(4.2, 1.3, 1.0), F(0, BRIDGE_TOP + 0.65, FRONT + 0.8), VISOR)
	part("ConsoleTop", V(4.4, 0.16, 1.15), F(0, BRIDGE_TOP + 1.38, FRONT + 0.8), DARK)
	for _, x in { -1.2, 1.2 } do
		part(
			"ConsoleScreen",
			V(1.1, 0.7, 0.08),
			F(x, BRIDGE_TOP + 1.85, FRONT + 0.45) * CFrame.Angles(math.rad(-15), 0, 0),
			DARK
		)
		part(
			"ScreenGlow",
			V(0.95, 0.56, 0.02),
			F(x, BRIDGE_TOP + 1.85, FRONT + 0.5) * CFrame.Angles(math.rad(-15), 0, 0),
			rgb(72, 152, 123),
			M.Neon
		)
	end
	for _, x in { -0.35, 0.35 } do
		beam("ThrusterLever", V(x, BRIDGE_TOP + 1.45, FRONT + 1.05), V(x, BRIDGE_TOP + 1.95, FRONT + 1.15), 0.08, STEEL)
		part("LeverGrip", V(0.2, 0.2, 0.2), F(x, BRIDGE_TOP + 1.97, FRONT + 1.15), ORANGE)
	end
	local seatZ = FRONT + 2.6
	part("HelmPedestal", V(0.5, 0.6, 0.5), F(0, BRIDGE_TOP + 0.3, seatZ), DARK)
	part("HelmCushion", V(2.0, 0.25, 1.6), F(0, BRIDGE_TOP + 0.72, seatZ), DARK)
	part("HelmBack", V(2.0, 1.4, 0.22), F(0, BRIDGE_TOP + 1.5, seatZ + 0.8), DARK)
	local helm = Instance.new("VehicleSeat")
	helm.Size, helm.CFrame = V(2.0, 0.24, 1.6), frame * F(0, BRIDGE_TOP + 0.76, seatZ)
	helm.Transparency, helm.HeadsUpDisplay = 1, false
	helm.MaxSpeed, helm.Torque, helm.TurnSpeed = 0, 0, 0
	finish(helm, "HelmSeat", DARK)
	helm.CanTouch, helm.Disabled = not isAnchored, isAnchored

	-- Two crew seats on the aft deck, facing the stern.
	for _, side in { -1, 1 } do
		part("PassengerPedestal", V(0.42, 0.7, 0.42), F(side * 4.3, DECK_TOP + 0.35, 9.4), DARK)
		part("PassengerCushion", V(1.8, 0.24, 1.5), F(side * 4.3, DECK_TOP + 0.75, 9.4), WHITE)
		part("PassengerBack", V(1.8, 1.0, 0.2), F(side * 4.3, DECK_TOP + 1.35, 8.7), DARK)
		local seat = Instance.new("Seat")
		seat.Size = V(1.8, 0.24, 1.5)
		seat.CFrame = frame * F(side * 4.3, DECK_TOP + 0.8, 9.4) * CFrame.Angles(0, math.pi, 0)
		seat.Transparency = 1
		finish(seat, if side < 0 then "FishingSeatPort" else "FishingSeatStarboard", WHITE)
		seat.CanTouch, seat.Disabled = not isAnchored, isAnchored
	end

	-- Exhaust casings at the aft corners of the bridge deck.
	for _, side in { -1, 1 } do
		part("ExhaustCasing", V(1.3, 2.6, 1.4), F(side * 2.85, BRIDGE_TOP + 1.3, 2.5), WHITE, nil, true)
		cylinder(
			"ExhaustPipe",
			V(1.6, 0.5, 0.5),
			F(side * 2.85, BRIDGE_TOP + 3.4, 2.5) * CFrame.Angles(0, 0, math.pi / 2),
			DARK,
			M.Metal
		)
		part("ExhaustCap", V(0.7, 0.12, 0.7), F(side * 2.85, BRIDGE_TOP + 4.25, 2.5), DARK)
	end
	-- Inflatable liferaft canisters in cradles beside the wheelhouse.
	for _, side in { -1, 1 } do
		part("LiferaftCradle", V(0.9, 0.2, 1.4), F(side * 3.2, BRIDGE_TOP + 0.1, 0.4), STEEL, M.Metal)
		cylinder(
			"Liferaft",
			V(1.5, 0.85, 0.85),
			F(side * 3.2, BRIDGE_TOP + 0.6, 0.4) * CFrame.Angles(0, math.pi / 2, 0),
			WHITE
		)
		part("LiferaftStrap", V(0.9, 0.9, 0.1), F(side * 3.2, BRIDGE_TOP + 0.6, 0.4), ORANGE)
	end

	-- Yellow machinery box and its black vent on the starboard aft deck.
	part("MachineryBox", V(1.9, 2.1, 2.2), F(4.25, DECK_TOP + 1.05, 5.4), YELLOW, nil, true)
	part("MachineryVent", V(1.5, 0.7, 1.7), F(4.25, DECK_TOP + 2.45, 5.4), DARK)
	for dz = -0.6, 0.6, 0.3 do
		part("VentLouvre", V(0.04, 0.4, 0.1), F(3.29, DECK_TOP + 1.45, 5.4 + dz), DARK)
	end

	-- Foredeck towing winch with flanged drum, motor and bow bitts.
	cylinder("WinchDrum", V(2.8, 1.5, 1.5), F(0, DECK_TOP + 1.0, -10.2), GRAY, M.Metal)
	for _, x in { -1.5, 1.5 } do
		cylinder("WinchFlange", V(0.16, 2.1, 2.1), F(x, DECK_TOP + 1.0, -10.2), STEEL, M.Metal)
		part("WinchFrame", V(0.35, 1.1, 1.6), F(x * 1.18, DECK_TOP + 0.55, -10.2), GRAY, M.Metal)
	end
	part("WinchMotor", V(1.2, 1.1, 1.3), F(-2.45, DECK_TOP + 0.55, -10.2), GRAY, M.Metal)
	ring("WoundTowline", V(0, DECK_TOP + 1.0, -10.2), 0.78, 0.09, "X", rgb(214, 196, 150), 12)
	for _, x in { -2.2, 2.2 } do
		for _, dz in { -0.35, 0.35 } do
			cylinder(
				"BowBitt",
				V(0.9, 0.42, 0.42),
				F(x, DECK_TOP + 0.45, -12.6 + dz) * CFrame.Angles(0, 0, math.pi / 2),
				BLACK,
				M.Metal
			)
		end
	end
	part("BowFairlead", V(1.4, 0.4, 0.6), F(0, 3.85, -14.8), BLACK, M.Metal)

	-- Aft towing bitt, stern pins and a coiled towline.
	for _, x in { -0.8, 0.8 } do
		cylinder(
			"TowBitt",
			V(1.3, 0.55, 0.55),
			F(x, DECK_TOP + 0.65, 12.4) * CFrame.Angles(0, 0, math.pi / 2),
			BLACK,
			M.Metal
		)
	end
	beam("TowBittBar", V(-1.2, DECK_TOP + 0.9, 12.4), V(1.2, DECK_TOP + 0.9, 12.4), 0.22, BLACK, M.Metal)
	for _, x in { -1.1, 1.1 } do
		cylinder(
			"TowingPin",
			V(2.0, 0.3, 0.3),
			F(x, DECK_TOP + 1.0, 14.2) * CFrame.Angles(0, 0, math.pi / 2),
			YELLOW,
			M.Metal
		)
	end
	for i = 0, 2 do
		ring("RopeCoil", V(-3.6, DECK_TOP + 0.08 + i * 0.07, 12.2), 0.5 + i * 0.16, 0.1, "Y", rgb(214, 196, 150))
	end

	-- Mast, radar, searchlight, horn and navigation lamps.
	local roofTop = ROOF_Y + 0.3
	beam("Mast", V(0, roofTop, -3.2), V(0, roofTop + 6.8, -3.2), 0.24, YELLOW, M.Metal)
	beam("MastCrossbar", V(-2.0, roofTop + 4.8, -3.2), V(2.0, roofTop + 4.8, -3.2), 0.14, WHITE, M.Metal)
	beam("MastCrossbar", V(-1.2, roofTop + 2.6, -3.2), V(1.2, roofTop + 2.6, -3.2), 0.14, WHITE, M.Metal)
	for _, side in { -1, 1 } do
		beam("MastStay", V(0, roofTop + 4.6, -3.2), V(side * 3.0, roofTop, -1.8), 0.035, STEEL)
		part("SignalLamp", V(0.22, 0.28, 0.22), F(side * 1.9, roofTop + 5.05, -3.2), LAMP, M.Neon)
	end
	part("MastLamp", V(0.26, 0.32, 0.26), F(0, roofTop + 6.95, -3.2), LAMP, M.Neon)
	beam("Aerial", V(0.6, roofTop, -1.6), V(0.6, roofTop + 4.2, -1.65), 0.045, STEEL)
	beam("Aerial", V(-1.8, roofTop, -1.8), V(-1.8, roofTop + 3.0, -1.85), 0.045, STEEL)
	part("Pennant", V(0.04, 0.5, 0.8), F(2.0, roofTop + 4.45, -2.8), ORANGE)
	part("RadarPedestal", V(0.6, 0.6, 0.6), F(0, roofTop + 0.3, -5.6), VISOR)
	part("RadarScanner", V(3.0, 0.2, 0.55), F(0, roofTop + 0.72, -5.6), WHITE)
	cylinder(
		"Searchlight",
		V(0.7, 0.6, 0.6),
		F(-2.0, roofTop + 0.4, -6.4) * CFrame.Angles(0, math.pi / 2, 0),
		DARK,
		M.Metal
	)
	cylinder(
		"RoofHorn",
		V(0.8, 0.26, 0.26),
		F(2.0, roofTop + 0.25, -6.4) * CFrame.Angles(0, math.pi / 2, 0),
		STEEL,
		M.Metal
	)
	for _, side in { -1, 1 } do
		part("NavigationLampHousing", V(0.45, 0.35, 0.6), F(side * (HALF + 0.3), SILL - 0.1, FRONT + 0.6), VISOR)
		part(
			"NavigationLamp",
			V(0.22, 0.22, 0.3),
			F(side * (HALF + 0.42), SILL - 0.1, FRONT + 0.6),
			if side < 0 then rgb(218, 53, 44) else rgb(65, 194, 95),
			M.Neon
		)
		part("HeadlightHousing", V(0.7, 0.55, 0.55), F(side * 2.2, ROOF_Y - 0.55, FRONT - 0.45), DARK, M.Metal)
		local lens =
			part("HeadlightLens", V(0.52, 0.38, 0.05), F(side * 2.2, ROOF_Y - 0.55, FRONT - 0.74), LAMP, M.Neon)
		local light = Instance.new("SpotLight")
		light.Name, light.Face = "Headlight", Enum.NormalId.Front
		light.Color, light.Range, light.Brightness, light.Angle = LAMP, 60, 1.2, 65
		light.Shadows, light.Parent = false, lens
	end
	local workLamp = part("DeckWorkLamp", V(0.7, 0.24, 0.5), F(0, ROOF_Y - 0.35, AFT + 0.5), LAMP, M.Neon)
	local deckLight = Instance.new("PointLight")
	deckLight.Name, deckLight.Color, deckLight.Range, deckLight.Brightness = "DeckLight", LAMP, 24, 0.7
	deckLight.Shadows, deckLight.Parent = false, workLamp

	-- Twin azimuth thrusters under the stern and a short skeg.
	part("Skeg", V(0.3, 1.0, 6.0), F(0, -2.9, 2.0), ANTIFOUL, M.Metal)
	for _, side in { -1, 1 } do
		local x = side * 2.4
		cylinder(
			"ThrusterLeg",
			V(1.2, 0.5, 0.5),
			F(x, -1.9, 11.4) * CFrame.Angles(0, 0, math.pi / 2),
			ANTIFOUL,
			M.Metal
		)
		ring("ThrusterNozzle", V(x, -2.75, 11.4), 0.72, 0.22, "Z", ANTIFOUL, 10)
		cylinder(
			"PropellerHub",
			V(0.6, 0.36, 0.36),
			F(x, -2.75, 11.4) * CFrame.Angles(0, math.pi / 2, 0),
			YELLOW,
			M.Metal
		)
		for i = 0, 3 do
			local a = i * math.pi / 2 + side * 0.4
			part(
				"PropellerBlade",
				V(0.36, 0.62, 0.12),
				F(x + math.sin(a) * 0.34, -2.75 + math.cos(a) * 0.34, 11.4) * CFrame.Angles(0, 0, -a),
				YELLOW,
				M.Metal
			)
		end
	end
	return model
end

return Tugboat
