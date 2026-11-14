-- Everything in the parliament that is only looked at: furniture, finishes, ornament, lights
-- and the chambers' Aura. Built locally, zone by zone (client/Parliament), with no physics or
-- Seats: those stay authoritative on the server.
--
-- Two looks from one plan. Detailed builds every piece from several shapes. Performance
-- (`lite`) draws each piece of furniture as a single block and leaves out the finishes,
-- ornament, most lights and the Aura.
--
-- Stacked surfaces keep at least 0.06 studs apart and ring segments alternate in height, so no
-- two parts share a visible face (scripts/check-parliament looks for coplanar faces).
local Layout = require(script.Parent.ParliamentLayout)
local Parties = require(script.Parent.Parties)
local Interior = {}
local V, F, A, rgb, M = Vector3.new, CFrame.new, CFrame.Angles, Color3.fromRGB, Enum.Material
local rad, pi = math.rad, math.pi
local LIFT = Layout.RING_LIFT
-- Dark woods, warm stone, deep carpets and brass.
local OAK, WALNUT, DARKWOOD = rgb(138, 98, 60), rgb(84, 56, 36), rgb(58, 38, 25)
local STONE, CEILING = rgb(172, 160, 140), rgb(104, 84, 62)
local MARBLE_DARK, MARBLE_LIGHT = rgb(66, 58, 52), rgb(182, 170, 148)
local RED, BLUE, GREEN, TEAL = rgb(112, 32, 36), rgb(38, 72, 132), rgb(40, 70, 56), rgb(30, 92, 98)
local GOLD, BRONZE, DARK, BLACK = rgb(186, 146, 70), rgb(96, 76, 54), rgb(36, 40, 44), rgb(20, 22, 24)
local CREAM, WHITE, STEEL, GLASS = rgb(214, 204, 182), rgb(222, 220, 212), rgb(132, 136, 138), rgb(140, 170, 176)
local LEAF, SOIL, SCREEN = rgb(70, 104, 70), rgb(58, 46, 36), rgb(28, 40, 50)
local WARM = rgb(255, 212, 158)
local BOOKS = { rgb(110, 40, 38), rgb(40, 62, 92), rgb(52, 84, 62), rgb(132, 104, 56), rgb(76, 56, 86) }
local ART = { rgb(76, 98, 118), rgb(130, 84, 62), rgb(84, 110, 82), rgb(150, 122, 74), rgb(96, 74, 104), rgb(58, 80, 100) }
local UP = A(0, 0, pi / 2) -- stands a cylinder on its end

-- Tools every zone builds with. `dynamic` collects the pieces the client keeps updating.
function Interior.context(base: CFrame, checkpoint: (() -> ())?, lite: boolean?)
	local ctx = {
		lite = lite == true,
		dynamic = { Labels = {}, BellLamps = {}, VoteLights = {}, SeatBoard = nil :: any },
		folder = nil :: Instance?,
	}
	function ctx.group(name: string): Model
		local model = Instance.new("Model")
		model.Name, model.Parent = name, ctx.folder
		return model
	end
	function ctx.part(folder, name, size, frame, color, material, shape)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame = name, size, base * frame
		p.Color, p.Material = color, material or M.SmoothPlastic
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if shape then
			p.Shape = shape
		end
		p.Parent = folder
		if checkpoint then
			checkpoint()
		end
		return p
	end
	-- Text on a thin board, readable from the board's +Z side.
	function ctx.sign(folder, text, frame, width, height, tint, background, name, distance)
		local board = ctx.part(folder, name or "Sign", V(width, height, 0.06), frame, background or DARK)
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.SizingMode, gui.PixelsPerStud = Enum.NormalId.Back, Enum.SurfaceGuiSizingMode.PixelsPerStud, 40
		gui.MaxDistance, gui.LightInfluence = distance or 40, 0.3
		local label = Instance.new("TextLabel")
		label.Size, label.Position = UDim2.fromScale(0.92, 0.8), UDim2.fromScale(0.04, 0.1)
		label.BackgroundTransparency, label.TextScaled, label.TextWrapped = 1, true, true
		label.Font, label.TextColor3, label.Text = Enum.Font.Garamond, tint or CREAM, text
		label.Parent, gui.Parent = gui, board
		return label, board
	end
	-- A warm light. Detailed: a glass fixture and a light. Performance: only the essential
	-- ones, as a plain block with its light.
	function ctx.light(folder, frame, range, brightness, essential, kind)
		if ctx.lite and not essential then
			return nil
		end
		local head = ctx.part(folder, "LightFixture", V(1.4, 0.5, 1.4), frame, WARM, M.Glass, if ctx.lite then nil else Enum.PartType.Ball)
		head.Transparency = 0.15
		local light = Instance.new(kind or "PointLight")
		light.Range, light.Brightness, light.Color, light.Shadows = range, brightness or 0.7, WARM, false
		if light:IsA("SpotLight") then
			light.Face, light.Angle = Enum.NormalId.Bottom, 70
		end
		light.Parent = head
		return head
	end
	-- `count` tangent segments of a ring, every other one lifted by LIFT (in y, or in radius
	-- for vertical rings) so overlapping corners never share a face.
	function ctx.ring(folder, name, from, to, count, inner, outer, y0, y1, color, material, centre, radial)
		local step = (to - from) / count
		local made = {}
		local origin = centre or Layout.Focus
		for index = 1, count do
			local angle = from + (index - 0.5) * step
			local lift = if index % 2 == 0 then LIFT else 0
			local width = 2 * outer * math.tan(rad(math.abs(step) / 2)) + 0.05
			local radius = (inner + outer) / 2 + (if radial then lift else 0)
			local a = rad(angle)
			local frame = F(origin.X + math.sin(a) * radius, (y0 + y1) / 2 + (if radial then 0 else lift), origin.Z + math.cos(a) * radius) * A(0, a, 0)
			table.insert(made, ctx.part(folder, name, V(width, y1 - y0, outer - inner), frame, color, material))
		end
		return made
	end
	return ctx
end

---------------------------------------------------------------------------------------------------
-- The furniture kit. A frame is on the floor; a seated person at it looks along -Z.
-- Wall pieces (shelves, screens, paintings, counters) show their front on +Z.

local function kit(ctx)
	local K, P, lite = {}, ctx.part, ctx.lite
	local function block(folder, name, size, frame, color, material)
		return P(folder, name, size, frame * F(0, size.Y / 2, 0), color, material)
	end
	K.block = block

	function K.chair(folder, frame, color, trim, special)
		if lite then
			return block(folder, "SeatBlock", V(2.1, if special then 5.2 else 4.2, 2.1), frame, color, M.Fabric)
		end
		local width, back = if special then 2.8 else 2.15, if special then 3.8 else 2.6
		trim = trim or DARKWOOD
		P(folder, "ChairPedestal", V(0.32, 1.3, 0.32), frame * F(0, 0.8, 0), trim, M.Metal)
		P(folder, "ChairFoot", V(width * 0.8, 0.12, 1.6), frame * F(0, 0.16, 0), trim, M.Metal)
		local cushion = P(folder, "SeatCushion", V(width, 0.45, 2.1), frame * F(0, 1.65, 0), color, M.Fabric)
		P(folder, "ChairBackShell", V(width + 0.1, back, 0.35), frame * F(0, 1.8 + back / 2, 0.92), trim, M.Wood)
		P(folder, "ChairBackCushion", V(width - 0.14, back - 0.2, 0.25), frame * F(0, 1.8 + back / 2, 0.68), color, M.Fabric)
		for _, side in { -1, 1 } do
			P(folder, "Armrest", V(0.18, 0.22, 1.7), frame * F(side * (width / 2 + 0.06), 2.5, 0.1), trim, M.Wood)
		end
		return cushion
	end
	function K.stool(folder, frame, color)
		if lite then
			return block(folder, "StoolBlock", V(1.4, 2.4, 1.4), frame, color, M.Fabric)
		end
		P(folder, "StoolSeat", V(0.35, 1.5, 1.5), frame * F(0, 2.2, 0) * UP, color, M.Fabric, Enum.PartType.Cylinder)
		P(folder, "StoolPost", V(1.9, 0.25, 0.25), frame * F(0, 1.05, 0) * UP, STEEL, M.Metal, Enum.PartType.Cylinder)
		P(folder, "StoolFoot", V(0.12, 1.3, 1.3), frame * F(0, 0.06, 0) * UP, STEEL, M.Metal, Enum.PartType.Cylinder)
	end
	function K.microphone(folder, frame)
		if lite then
			return
		end
		P(folder, "MicrophoneBase", V(0.38, 0.1, 0.3), frame * F(0, 0.05, 0), DARK, M.Metal)
		P(folder, "MicrophoneStem", V(0.07, 0.75, 0.07), frame * F(0, 0.42, 0) * A(-0.3, 0, 0), DARK, M.Metal)
		P(folder, "MicrophoneHead", V(0.19, 0.2, 0.32), frame * F(0, 0.8, -0.12), DARK)
	end
	-- A long table; its length runs along the frame's X. The top is 3 studs up.
	function K.table(folder, frame, length, width, color, inlay)
		if lite then
			return block(folder, "TableBlock", V(length, 3, width), frame, color or OAK, M.Wood)
		end
		P(folder, "TableTop", V(length, 0.3, width), frame * F(0, 2.85, 0), color or OAK, M.Wood)
		if inlay then
			P(folder, "TableInlay", V(length - 1.2, 0.06, width * 0.42), frame * F(0, 3.03, 0), inlay, M.Fabric)
		end
		for _, side in { -1, 1 } do
			P(folder, "TableBase", V(1.5, 2.7, width * 0.5), frame * F(side * (length / 2 - 1.7), 1.35, 0), DARKWOOD, M.Wood)
		end
	end
	function K.round(folder, frame, diameter, color)
		if lite then
			return block(folder, "TableBlock", V(diameter * 0.8, 3, diameter * 0.8), frame, color or OAK, M.Wood)
		end
		P(folder, "RoundTableTop", V(0.25, diameter, diameter), frame * F(0, 2.875, 0) * UP, color or OAK, M.Wood, Enum.PartType.Cylinder)
		P(folder, "RoundTablePost", V(2.6, 0.35, 0.35), frame * F(0, 1.45, 0) * UP, DARKWOOD, M.Metal, Enum.PartType.Cylinder)
		P(folder, "RoundTableFoot", V(0.15, diameter * 0.55, diameter * 0.55), frame * F(0, 0.08, 0) * UP, DARKWOOD, M.Metal, Enum.PartType.Cylinder)
	end
	-- Things on a table top at height `top` (3 for K.table), placed in the frame's plane.
	function K.papers(folder, frame, top)
		if lite then
			return
		end
		P(folder, "Papers", V(0.75, 0.06, 0.95), frame * F(0, top + 0.03, 0) * A(0, 0.2, 0), CREAM)
	end
	function K.glass(folder, frame, top)
		if lite then
			return
		end
		P(folder, "WaterGlass", V(0.5, 0.32, 0.32), frame * F(0, top + 0.25, 0) * UP, GLASS, M.Glass, Enum.PartType.Cylinder)
	end
	-- A work desk in front of a seated person, with its monitor.
	function K.desk(folder, frame, width, color)
		local d = frame * F(0, 0, -2)
		if lite then
			return block(folder, "DeskBlock", V(width, 3, 1.7), d, color or OAK, M.Wood)
		end
		P(folder, "DeskTop", V(width, 0.2, 1.7), d * F(0, 2.9, 0), color or OAK, M.Wood)
		P(folder, "DeskPanel", V(width - 0.3, 2.2, 0.12), d * F(0, 1.6, -0.7), color or OAK, M.Wood)
		for _, side in { -1, 1 } do
			P(folder, "DeskSide", V(0.15, 2.8, 1.6), d * F(side * (width / 2 - 0.1), 1.4, 0), DARKWOOD, M.Wood)
		end
		P(folder, "Monitor", V(1.7, 1.05, 0.1), d * F(0, 3.85, -0.45), SCREEN, M.Glass)
		P(folder, "MonitorStand", V(0.15, 0.5, 0.15), d * F(0, 3.25, -0.45), DARK, M.Metal)
		P(folder, "Keyboard", V(1.2, 0.06, 0.4), d * F(0, 3.03, 0.25), DARK)
		P(folder, "Papers", V(0.6, 0.06, 0.8), d * F(width / 2 - 0.6, 3.03, 0.2), CREAM)
	end
	function K.sofa(folder, frame, width, color)
		if lite then
			return block(folder, "SofaBlock", V(width, 2.7, 2.4), frame * F(0, 0, 0.3), color, M.Fabric)
		end
		P(folder, "SofaBase", V(width, 1.1, 2.3), frame * F(0, 0.75, 0.2), color, M.Fabric)
		P(folder, "SofaCushion", V(width - 1, 0.4, 1.9), frame * F(0, 1.5, 0.05), color:Lerp(WHITE, 0.15), M.Fabric)
		P(folder, "SofaBack", V(width, 2, 0.6), frame * F(0, 2, 1.15), color, M.Fabric)
		for _, side in { -1, 1 } do
			P(folder, "SofaArm", V(0.5, 1.7, 2.3), frame * F(side * (width / 2 - 0.25), 1.35, 0.2), color, M.Fabric)
		end
	end
	function K.plant(folder, frame, height)
		if lite then
			return
		end
		P(folder, "PlanterPot", V(1.6, 1.8, 1.8), frame * F(0, 0.8, 0) * UP, BRONZE, M.Metal, Enum.PartType.Cylinder)
		P(folder, "PlanterSoil", V(0.1, 1.6, 1.6), frame * F(0, 1.62, 0) * UP, SOIL, M.Ground, Enum.PartType.Cylinder)
		P(folder, "PlantStem", V(0.22, height * 0.55, 0.22), frame * F(0, 1.6 + height * 0.27, 0), WALNUT, M.Wood)
		P(folder, "PlantCrown", V(height * 0.6, height * 0.6, height * 0.6), frame * F(0, 1.6 + height * 0.7, 0), LEAF, M.Grass, Enum.PartType.Ball)
		P(folder, "PlantCrown", V(height * 0.4, height * 0.4, height * 0.4), frame * F(0.3, 1.6 + height * 0.98, 0.2), LEAF:Lerp(WHITE, 0.1), M.Grass, Enum.PartType.Ball)
	end
	-- Bookcase with its back on the frame's XY plane.
	function K.shelf(folder, frame, width, height)
		if lite then
			return block(folder, "ShelfBlock", V(width, height, 1.2), frame * F(0, 0, 0.7), WALNUT, M.Wood)
		end
		P(folder, "ShelfBack", V(width, height, 0.15), frame * F(0, height / 2, 0.175), DARKWOOD, M.Wood)
		for _, side in { -1, 1 } do
			P(folder, "ShelfSide", V(0.2, height, 1.25), frame * F(side * (width / 2 - 0.1), height / 2, 0.725), WALNUT, M.Wood)
		end
		local rows = math.max(1, math.floor(height / 1.8))
		for row = 1, rows do
			local y = (row - 1) * (height / rows)
			P(folder, "ShelfBoard", V(width - 0.4, 0.12, 1.1), frame * F(0, y + 0.16, 0.8), WALNUT, M.Wood)
			P(folder, "BookRow", V(width - 1, 1.15, 0.7), frame * F(((row % 3) - 1) * 0.2, y + 0.82, 0.65), BOOKS[(row + math.floor(width)) % #BOOKS + 1])
		end
	end
	function K.painting(folder, frame, width, height, tint)
		if lite then
			return
		end
		P(folder, "PictureFrame", V(width + 0.5, height + 0.5, 0.16), frame * F(0, 0, 0.18), GOLD, M.Metal)
		P(folder, "PictureCanvas", V(width, height, 0.1), frame * F(0, 0, 0.3), tint, M.Fabric)
		P(folder, "PictureSky", V(width, height * 0.38, 0.06), frame * F(0, height * 0.31, 0.38), tint:Lerp(CREAM, 0.4), M.Fabric)
	end
	function K.counter(folder, frame, length, color)
		if lite then
			return block(folder, "CounterBlock", V(length, 3.4, 2.2), frame, color or WALNUT, M.Wood)
		end
		P(folder, "CounterBody", V(length, 3.1, 2), frame * F(0, 1.55, 0), color or WALNUT, M.Wood)
		P(folder, "CounterTop", V(length + 0.3, 0.25, 2.4), frame * F(0, 3.225, 0), MARBLE_LIGHT, M.Marble)
		P(folder, "CounterKick", V(length - 0.2, 0.3, 0.1), frame * F(0, 0.15, 1.08), BLACK, M.Metal)
	end
	function K.bench(folder, frame, length, color)
		if lite then
			return block(folder, "BenchBlock", V(length, 1.75, 1.6), frame, color or RED, M.Fabric)
		end
		P(folder, "BenchCushion", V(length, 0.35, 1.6), frame * F(0, 1.58, 0), color or RED, M.Fabric)
		P(folder, "BenchFrame", V(length + 0.2, 0.25, 1.75), frame * F(0, 1.27, 0), DARKWOOD, M.Wood)
		for _, side in { -1, 1 } do
			P(folder, "BenchLeg", V(0.3, 1.14, 1.4), frame * F(side * (length / 2 - 0.5), 0.57, 0), DARKWOOD, M.Wood)
		end
	end
	-- A dark screen in a frame; returns its label so the client can write on it.
	function K.screen(folder, frame, width, height, text, name)
		if not lite then
			P(folder, "ScreenBezel", V(width + 0.4, height + 0.4, 0.22), frame * F(0, 0, 0.11), BLACK, M.Metal)
		end
		local label = ctx.sign(folder, text or "", frame * F(0, 0, 0.28), width, height, CREAM, SCREEN, name or "Screen", 120)
		label.Font = Enum.Font.GothamBold
		return label
	end
	function K.machine(folder, frame, color, glow)
		if lite then
			return block(folder, "MachineBlock", V(2.6, 5.6, 2.2), frame, color, M.Metal)
		end
		P(folder, "MachineBody", V(2.6, 5.6, 2.2), frame * F(0, 2.8, 0), color, M.Metal)
		P(folder, "MachinePanel", V(1.7, 2.6, 0.06), frame * F(-0.3, 3.6, 1.16), glow or SCREEN, M.Glass)
		P(folder, "MachineSlot", V(1.7, 0.5, 0.08), frame * F(-0.3, 1.1, 1.16), BLACK)
		P(folder, "MachineKeys", V(0.4, 1.2, 0.06), frame * F(0.95, 3.4, 1.16), STEEL, M.Metal)
	end
	function K.statue(folder, frame, tint)
		if lite then
			return
		end
		P(folder, "StatuePlinth", V(2.6, 3, 2.6), frame * F(0, 1.5, 0), MARBLE_LIGHT, M.Marble)
		P(folder, "StatuePlinthCap", V(3, 0.3, 3), frame * F(0, 3.15, 0), MARBLE_LIGHT, M.Marble)
		P(folder, "StatueBody", V(4.4, 1.4, 1.4), frame * F(0, 5.5, 0) * UP, tint or BRONZE, M.Metal, Enum.PartType.Cylinder)
		P(folder, "StatueShoulders", V(2.4, 0.7, 1), frame * F(0, 7.4, 0), tint or BRONZE, M.Metal)
		P(folder, "StatueHead", V(1.1, 1.1, 1.1), frame * F(0, 8.4, 0), tint or BRONZE, M.Metal, Enum.PartType.Ball)
	end
	function K.flag(folder, frame, tints)
		if lite then
			return
		end
		P(folder, "FlagBase", V(0.3, 1.2, 1.2), frame * F(0, 0.15, 0) * UP, GOLD, M.Metal, Enum.PartType.Cylinder)
		P(folder, "FlagPole", V(8.6, 0.16, 0.16), frame * F(0, 4.5, 0) * UP, GOLD, M.Metal, Enum.PartType.Cylinder)
		for index, tint in tints do
			P(folder, "FlagCloth", V(0.08, 3 / #tints, 2.4), frame * F(0, 8.3 - (index - 0.5) * 3 / #tints, 1.3), tint, M.Fabric)
		end
	end
	-- A hanging ring of glowing segments: the chambers' chandeliers and halos.
	function K.halo(folder, frame, radius, count, tint, drop)
		for index = 1, count do
			local angle = (index - 0.5) * 2 * pi / count
			local lift = if index % 2 == 0 then LIFT else 0
			local spot = frame * A(0, angle, 0) * F(0, lift, radius)
			P(folder, "HaloSegment", V(2 * radius * math.tan(pi / count) + 0.05, 0.3, 0.3), spot, tint, M.Glass)
			if drop and index % 4 == 0 then
				P(folder, "HaloRod", V(0.08, drop, 0.08), spot * F(0, drop / 2 + 0.15, 0), GOLD, M.Metal)
			end
		end
	end
	function K.chandelier(folder, frame, radius, drop, range, essential)
		if not lite then
			K.halo(folder, frame, radius, 12, WARM, drop)
			K.halo(folder, frame * F(0, -1.3, 0), radius * 0.6, 8, WARM)
			P(folder, "ChandelierCore", V(1.2, 1.2, 1.2), frame * F(0, -0.6, 0), GOLD, M.Metal, Enum.PartType.Ball)
		end
		if range > 0 then
			return ctx.light(folder, frame * F(0, -2.2, 0), range, 0.85, essential)
		end
		return nil
	end
	function K.clock(folder, frame)
		if lite then
			return
		end
		P(folder, "ClockRim", V(0.12, 2.5, 2.5), frame * F(0, 0, 0.06) * A(0, pi / 2, 0), GOLD, M.Metal, Enum.PartType.Cylinder)
		P(folder, "ClockFace", V(0.12, 2.2, 2.2), frame * F(0, 0, 0.16) * A(0, pi / 2, 0), CREAM, M.SmoothPlastic, Enum.PartType.Cylinder)
		P(folder, "ClockHand", V(0.12, 0.85, 0.06), frame * F(0, 0.35, 0.26), BLACK)
		P(folder, "ClockHand", V(0.6, 0.1, 0.06), frame * F(0.25, 0, 0.34), BLACK)
	end
	return K
end

local function at(room, u, y, w, facing)
	return room.Frame * F(u, y, w) * A(0, rad(facing or 0), 0)
end
local function ofRoom(room, role)
	local list = {}
	for _, entry in room.Spots do
		if entry.Role == role or (role == nil and entry.Kind == "Sit" and entry.Role == nil) then
			table.insert(list, entry)
		end
	end
	return list
end
-- Where a wing room's walls are, in its own u/w frame, and how high its ceiling is.
local function walls(room)
	local zf0 = room.Z0 + (if room.Z0 <= Layout.InnerNorth + 0.01 then 0 elseif room.Z0 == Layout.Senate.Z1 then 0.5 else 0.4)
	local zf1 = room.Z1 - (if room.Z1 >= Layout.StairZ then Layout.Wall / 2 else 0.4)
	local zc = room.Centre.Z
	local a, b = zf0 - zc, zf1 - zc
	if room.Side < 0 then
		a, b = -a, -b
	end
	local top = if room.Floor == Layout.Floors - 1 then Layout.Roof else room.Y + Layout.Storey - 1
	return { U = Layout.RoomHalfU, WLo = math.min(a, b), WHi = math.max(a, b), Ceiling = top - room.Y }
end

---------------------------------------------------------------------------------------------------
-- Wing rooms, one builder per kind.

local rooms = {}

-- Floor, wood wainscot, ceiling and one warm light. Every room has these.
local function roomShell(ctx, K, room, folder, floorColor, floorMaterial, panel)
	local P = ctx.part
	local w = walls(room)
	local depth, length = 2 * w.U - 0.2, w.WHi - w.WLo - 0.2
	local mid = (w.WLo + w.WHi) / 2
	ctx.light(folder, at(room, 0, w.Ceiling - 2.2, mid), 34, 0.75, true)
	if ctx.lite then
		return w
	end
	P(folder, "RoomFloor", V(depth, 0.06, length), at(room, 0, 0.05, mid), floorColor or rgb(98, 70, 46), floorMaterial or M.WoodPlanks)
	P(folder, "RoomCeiling", V(depth, 0.1, length), at(room, 0, w.Ceiling - 0.15, mid), CEILING, M.Wood)
	P(folder, "CeilingRose", V(0.12, 3.2, 3.2), at(room, 0, w.Ceiling - 0.26, mid) * UP, GOLD, M.Metal, Enum.PartType.Cylinder)
	P(folder, "LampDrop", V(0.1, 1.6, 0.1), at(room, 0, w.Ceiling - 1.15, mid), GOLD, M.Metal)
	local wood = panel or WALNUT
	-- The corridor side has the door; panel either side of it.
	local doors = {}
	for _, z in room.Doors do
		local offset = z - room.Centre.Z
		table.insert(doors, if room.Side < 0 then -offset else offset)
	end
	table.sort(doors)
	local from = w.WLo + 0.1
	for _, d in doors do
		if d - Layout.Door / 2 - from > 0.5 then
			P(folder, "Wainscot", V(0.2, 4.5, d - Layout.Door / 2 - from), at(room, -w.U + 0.2, 2.35, (from + d - Layout.Door / 2) / 2), wood, M.Wood)
		end
		from = d + Layout.Door / 2
	end
	if w.WHi - 0.1 - from > 0.5 then
		P(folder, "Wainscot", V(0.2, 4.5, w.WHi - 0.1 - from), at(room, -w.U + 0.2, 2.35, (from + w.WHi - 0.1) / 2), wood, M.Wood)
	end
	for _, side in { -1, 1 } do
		local face = if side < 0 then w.WLo else w.WHi
		P(folder, "Wainscot", V(depth - 0.6, 4.5, 0.2), at(room, 0, 2.35, face - side * 0.2), wood, M.Wood)
		P(folder, "PictureRail", V(depth - 0.6, 0.2, 0.2), at(room, 0, 9, face - side * 0.2), GOLD, M.Metal)
	end
	P(folder, "Radiator", V(0.5, 2, length - 6), at(room, w.U - 0.45, 1.1, mid), DARK, M.Metal)
	return w
end

local function meetingRoom(ctx, K, room, folder, color, inlay)
	local plan = room.Table
	K.table(folder, at(room, plan.U, 0, plan.W, 90), plan.LU, plan.LW, OAK, inlay)
	for _, entry in room.Spots do
		if entry.Role == "Lounge" then
			K.chair(folder, entry.Frame, color:Lerp(WHITE, 0.2), WALNUT)
		elseif entry.Kind == "Sit" then
			K.chair(folder, entry.Frame, color, if entry.Role == "Chair" then GOLD else DARKWOOD, entry.Role == "Chair")
			local top = F(entry.Position.X, room.Y, entry.Position.Z) * entry.Frame.Rotation * F(0, 0, -2.4)
			K.papers(folder, top * F(-0.4, 0, 0), 3)
			K.glass(folder, top * F(0.7, 0, 0.2), 3)
			if entry.Role == "Chair" then
				K.microphone(folder, top * F(0, 3, -0.2))
			end
		end
	end
end

function rooms.Committee(ctx, K, room, folder)
	local w = roomShell(ctx, K, room, folder, rgb(44, 58, 84), M.Carpet)
	local h = room.Horseshoe
	-- The horseshoe: a long base by the windows and two arms reaching towards the door.
	K.table(folder, at(room, h.BaseU, 0, 0, 90), 2 * (h.ArmW + h.Depth / 2), h.Depth, OAK)
	for _, side in { -1, 1 } do
		local armLength = h.BaseU - h.Depth / 2 - h.ArmFrom
		K.table(folder, at(room, h.ArmFrom + armLength / 2, 0, side * h.ArmW, 0), armLength, h.Depth, OAK)
	end
	for _, entry in room.Spots do
		if entry.Role == "Public" then
			K.chair(folder, entry.Frame, rgb(80, 64, 52), DARKWOOD)
		elseif entry.Role == "Witness" then
			K.chair(folder, entry.Frame, BLUE, DARKWOOD)
		elseif entry.Kind == "Sit" then
			K.chair(folder, entry.Frame, BLUE, if entry.Role == "Chair" then GOLD else DARKWOOD, entry.Role == "Chair")
			local top = F(entry.Position.X, room.Y, entry.Position.Z) * entry.Frame.Rotation * F(0, 0, -2.4)
			K.microphone(folder, top * F(0.5, 3, -0.1))
			K.papers(folder, top * F(-0.4, 0, 0.1), 3)
		end
	end
	K.table(folder, at(room, -5, 0, 0, 90), 3.4, 1.6, WALNUT)
	K.microphone(folder, at(room, -5, 3, 0))
	if ctx.lite then
		return
	end
	K.screen(folder, at(room, -w.U + 0.3, 7.8, -5.5, 90), 7, 4)
	K.screen(folder, at(room, -w.U + 0.3, 7.8, 5.5, 90), 7, 4)
	K.painting(folder, at(room, 0, 7.4, w.WLo + 0.2, 0), 7, 4.4, ART[(#room.Name % #ART) + 1])
	K.painting(folder, at(room, 0, 7.4, w.WHi - 0.2, 180), 7, 4.4, ART[(#room.Name + 2) % #ART + 1])
	K.flag(folder, at(room, 10.4, 0, w.WLo + 1.6, -90), { rgb(174, 42, 49), WHITE, BLUE })
	K.plant(folder, at(room, 10.6, 0, w.WHi - 1.6), 4.6)
	K.clock(folder, at(room, 0, 11.4, w.WHi - 0.2, 180))
end

function rooms.Fractie(ctx, K, room, folder)
	local party = Parties.List[room.Party]
	local w = roomShell(ctx, K, room, folder, party.Color:Lerp(BLACK, 0.55), M.Carpet)
	meetingRoom(ctx, K, room, folder, party.Color:Lerp(BLACK, 0.2), party.Color:Lerp(BLACK, 0.35))
	local _, banner = ctx.sign(folder, string.upper(party.Name), at(room, 0, 10.4, w.WLo + 0.2, 0), 11, 2.4, WHITE, party.Color:Lerp(BLACK, 0.15), "PartyBanner", 60)
	banner.Material = M.Fabric
	if ctx.lite then
		return
	end
	K.flag(folder, at(room, 10.4, 0, w.WLo + 1.6, -90), { party.Color, CREAM, party.Color })
	K.shelf(folder, at(room, -6, 0, w.WHi - 0.2, 180), 7, 8)
	K.round(folder, at(room, -10.2, 0, 0), 2.4, WALNUT)
	K.plant(folder, at(room, 10.6, 0, w.WHi - 1.6), 4.4)
	K.painting(folder, at(room, 4, 7.4, w.WHi - 0.2, 180), 6, 4, ART[room.Party])
	K.machine(folder, at(room, -w.U + 1.6, 0, w.WLo + 2, -90), DARK, party.Color:Lerp(BLACK, 0.3))
end

function rooms.Voting(ctx, K, room, folder)
	local P = ctx.part
	local w = roomShell(ctx, K, room, folder, rgb(88, 44, 36), M.Carpet)
	for _, booth in room.Booths do
		if ctx.lite then
			P(folder, "BoothBlock", V(2.8, 6.6, 3.2), booth * F(0.2, 3.3, 0), CREAM)
		else
			P(folder, "BoothBack", V(0.15, 6.6, 3.4), booth * F(1.4, 3.3, 0), CREAM, M.Wood)
			for _, side in { -1, 1 } do
				P(folder, "BoothSide", V(2.8, 6.6, 0.15), booth * F(0.1, 3.3, side * 1.62), CREAM, M.Wood)
			end
			P(folder, "BoothShelf", V(1.2, 0.15, 3.05), booth * F(0.7, 3.4, 0), OAK, M.Wood)
			P(folder, "BoothBallot", V(0.7, 0.06, 1), booth * F(0.6, 3.51, -0.2), CREAM)
			P(folder, "BoothPencil", V(0.08, 0.08, 0.7), booth * F(0.65, 3.52, 0.8), RED)
			P(folder, "BoothCurtain", V(0.1, 3.4, 3.05), booth * F(-1.2, 4.9, 0), RED, M.Fabric)
			P(folder, "BoothRail", V(0.12, 0.12, 3.1), booth * F(-1.2, 6.68, 0), GOLD, M.Metal)
		end
	end
	local box = room.BallotBox
	if ctx.lite then
		P(folder, "BallotBoxBlock", V(2, 3.4, 2), box * F(0, 1.7, 0), RED)
	else
		P(folder, "BallotBox", V(2, 3, 2), box * F(0, 1.5, 0), RED, M.Metal)
		P(folder, "BallotBoxLid", V(2.2, 0.3, 2.2), box * F(0, 3.15, 0), BLACK, M.Metal)
		P(folder, "BallotSlot", V(1.2, 0.06, 0.25), box * F(0, 3.33, 0), CREAM)
	end
	local desk = room.OfficialTable
	K.table(folder, at(room, desk.U, 0, desk.W, 0), 6.4, 2.2, OAK, RED)
	for _, entry in ofRoom(room, "Official") do
		K.chair(folder, entry.Frame, RED, DARKWOOD)
	end
	if ctx.lite then
		return
	end
	P(folder, "RegisterBook", V(1.4, 0.12, 1), at(room, desk.U - 1.2, 3.06, desk.W), BLACK)
	for stack = 0, 2 do
		P(folder, "BallotStack", V(0.8, 0.3, 1.1), at(room, desk.U + 0.6 + stack * 0.9, 3.15, desk.W), CREAM)
	end
	for index = 0, 3 do
		P(folder, "QueuePost", V(2.8, 0.25, 0.25), at(room, -7 + index * 3, 1.4, 1.5) * UP, GOLD, M.Metal, Enum.PartType.Cylinder)
		if index < 3 then
			P(folder, "QueueRope", V(2.75, 0.12, 0.12), at(room, -5.5 + index * 3, 2.5, 1.5), RED, M.Fabric)
		end
	end
	K.flag(folder, at(room, -10.4, 0, w.WHi - 1.6, 90), { rgb(174, 42, 49), WHITE, BLUE })
	K.plant(folder, at(room, -10.6, 0, w.WLo + 1.6), 4.4)
end

function rooms.Exhibition(ctx, K, room, folder)
	local P = ctx.part
	local w = roomShell(ctx, K, room, folder, MARBLE_DARK, M.Marble, DARKWOOD)
	for index, display in room.Displays do
		local frame = at(room, display[1], 0, display[2])
		if ctx.lite then
			P(folder, "DisplayBlock", V(2.6, 5.4, 2.6), frame * F(0, 2.7, 0), CREAM)
		else
			P(folder, "DisplayPlinth", V(2.6, 3, 2.6), frame * F(0, 1.5, 0), MARBLE_LIGHT, M.Marble)
			local case = P(folder, "DisplayGlass", V(2.4, 2.4, 2.4), frame * F(0, 4.26, 0), GLASS, M.Glass)
			case.Transparency = 0.75
			if index == 1 then
				P(folder, "ExhibitGavel", V(0.4, 0.4, 1.4), frame * F(0, 3.35, 0) * A(0, 0.6, 0), WALNUT, M.Wood)
			elseif index == 2 then
				P(folder, "ExhibitCrown", V(0.7, 1.1, 1.1), frame * F(0, 3.45, 0) * UP, GOLD, M.Metal, Enum.PartType.Cylinder)
			elseif index == 3 then
				P(folder, "ExhibitCharter", V(1.6, 0.06, 1.2), frame * F(0, 3.1, 0) * A(0, 0.3, 0), CREAM)
			else
				P(folder, "ExhibitBell", V(0.9, 1, 1), frame * F(0, 3.55, 0) * UP, GOLD, M.Metal, Enum.PartType.Cylinder)
			end
		end
	end
	-- A model of the building itself in the middle of the room.
	local model = at(room, 0, 0, 0)
	if ctx.lite then
		P(folder, "ScaleModelBlock", V(5, 4, 4.6), model * F(0, 2, 0), CREAM)
		return
	end
	P(folder, "ModelTable", V(5.6, 2.6, 5), model * F(0, 1.3, 0), WALNUT, M.Wood)
	P(folder, "ModelGround", V(5.2, 0.12, 4.6), model * F(0, 2.66, 0), rgb(150, 142, 128))
	for _, side in { -1, 1 } do
		P(folder, "ModelWing", V(1, 0.8, 3.6), model * F(side * 2, 3.12, -0.2), CREAM)
	end
	P(folder, "ModelDrum", V(1, 2.6, 2.6), model * F(0, 3.2, -0.2) * UP, CREAM, M.SmoothPlastic, Enum.PartType.Cylinder)
	local cap = P(folder, "ModelDome", V(2.4, 2.4, 2.4), model * F(0, 3.8, -0.2), GLASS, M.Glass, Enum.PartType.Ball)
	cap.Transparency = 0.35
	for index = 0, 2 do
		K.painting(folder, at(room, -6 + index * 6, 7.4, w.WLo + 0.2, 0), 4.4, 3.2, ART[index + 1])
		K.painting(folder, at(room, -6 + index * 6, 7.4, w.WHi - 0.2, 180), 4.4, 3.2, ART[index + 4])
	end
	K.bench(folder, at(room, -9, 0, 0, 90), 6, RED)
	K.plant(folder, at(room, 10.6, 0, 0), 4.6)
end

function rooms.Restaurant(ctx, K, room, folder)
	local P = ctx.part
	local w = roomShell(ctx, K, room, folder, rgb(86, 56, 40), M.WoodPlanks)
	ctx.light(folder, at(room, 0, w.Ceiling - 2.2, -14), 30, 0.65)
	ctx.light(folder, at(room, 0, w.Ceiling - 2.2, 14), 30, 0.65)
	for index, desk in room.Tables do
		local frame = at(room, desk.U, 0, desk.W)
		K.round(folder, frame, 3.2, CREAM)
		if not ctx.lite then
			P(folder, "TableVase", V(0.5, 0.3, 0.3), frame * F(0, 3.25, 0) * UP, GLASS, M.Glass, Enum.PartType.Cylinder)
			P(folder, "TableFlower", V(0.35, 0.35, 0.35), frame * F(0, 3.62, 0), if index % 2 == 0 then RED else GOLD, M.SmoothPlastic, Enum.PartType.Ball)
			for _, offset in { { 0.9, 0 }, { -0.9, 0 }, { 0, 0.9 }, { 0, -0.9 } } do
				P(folder, "Plate", V(0.06, 0.75, 0.75), frame * F(offset[1], 3.03, offset[2]) * UP, WHITE, M.SmoothPlastic, Enum.PartType.Cylinder)
			end
		end
	end
	for _, entry in ofRoom(room) do
		K.chair(folder, entry.Frame, RED, WALNUT)
	end
	-- The buffet runs along the kitchen wall.
	K.counter(folder, at(room, 0, 0, w.WLo + 1.4, 0), 16, WALNUT)
	if ctx.lite then
		return
	end
	local dishes = { rgb(204, 160, 82), rgb(110, 140, 80), rgb(176, 86, 60), rgb(222, 206, 170), rgb(88, 62, 46), rgb(200, 180, 110) }
	for index, tint in dishes do
		P(folder, "BuffetTray", V(1.7, 0.25, 1.2), at(room, -6.6 + (index - 1) * 2.6, 3.475, w.WLo + 1.4), STEEL, M.Metal)
		P(folder, "BuffetFood", V(1.5, 0.2, 1), at(room, -6.6 + (index - 1) * 2.6, 3.6, w.WLo + 1.4), tint)
	end
	K.counter(folder, at(room, 10.2, 0, w.WLo + 5, 90), 3.4, OAK)
	P(folder, "CashRegister", V(1.1, 0.9, 1), at(room, 10.2, 3.8, w.WLo + 5), BLACK, M.Metal)
	for index = 0, 2 do
		K.painting(folder, at(room, -w.U + 0.2, 7.6, -14 + index * 14, 90), 6, 3.8, ART[index + 2])
	end
	for _, wz in { -8, 8, 20 } do
		K.plant(folder, at(room, 10.8, 0, wz), 4.6)
	end
	K.machine(folder, at(room, -w.U + 1.6, 0, w.WHi - 1.6, -90), rgb(104, 40, 40), WARM)
end

function rooms.Kitchen(ctx, K, room, folder)
	local P = ctx.part
	local w = roomShell(ctx, K, room, folder, rgb(160, 158, 150), M.Marble, STEEL)
	for _, side in { -1, 1 } do
		K.counter(folder, at(room, 0, 0, side * (w.WHi - 1.4), if side < 0 then 0 else 180), 16, STEEL)
	end
	K.counter(folder, at(room, 10.4, 0, 1, -90), 10, STEEL)
	K.machine(folder, at(room, -w.U + 1.6, 0, w.WLo + 4, -90), WHITE, GLASS)
	K.machine(folder, at(room, -w.U + 1.6, 0, w.WHi - 4, -90), STEEL, GLASS)
	if ctx.lite then
		return
	end
	for index = 0, 3 do
		local hob = at(room, -4.5 + index * 2, 3.41, w.WLo + 1.4)
		P(folder, "Hob", V(0.06, 1.1, 1.1), hob * UP, BLACK, M.Metal, Enum.PartType.Cylinder)
		P(folder, "CookingPot", V(0.8, 1, 1), hob * F(0, 0.45, 0) * UP, STEEL, M.Metal, Enum.PartType.Cylinder)
	end
	P(folder, "ExtractorHood", V(8, 1.4, 2.4), at(room, -1.5, 9.6, w.WLo + 1.4), STEEL, M.Metal)
	P(folder, "Sink", V(2.4, 0.2, 1.4), at(room, 5, 3.45, w.WHi - 1.4), rgb(100, 106, 110), M.Metal)
	for index = 0, 4 do
		P(folder, "ChoppingBoard", V(1.2, 0.12, 0.8), at(room, -5.5 + index * 2, 3.41, w.WHi - 1.4), OAK, M.Wood)
	end
	for index = 0, 2 do
		P(folder, "Crate", V(1.6, 1.2, 1.2), at(room, 10.4, 3.95, -2 + index * 2.4), rgb(86, 116, 132))
	end
end

function rooms.Mail(ctx, K, room, folder)
	local P = ctx.part
	local w = roomShell(ctx, K, room, folder)
	K.counter(folder, at(room, 3.4, 0, 0, -90), 12, OAK)
	K.shelf(folder, at(room, 0, 0, w.WLo + 0.2, 0), 8, 8.4)
	K.shelf(folder, at(room, 0, 0, w.WHi - 0.2, 180), 8, 8.4)
	if ctx.lite then
		return
	end
	for rack = 0, 1 do
		local wz = if rack == 0 then -6.5 else 6.5
		P(folder, "CoatRail", V(0.14, 0.14, 7), at(room, 9.4, 6.4, wz), STEEL, M.Metal)
		for _, dz in { -3.4, 3.4 } do
			P(folder, "CoatRailPost", V(0.14, 6.4, 0.14), at(room, 9.4, 3.2, wz + dz), STEEL, M.Metal)
		end
		for index = 0, 5 do
			P(folder, "Coat", V(0.9, 3.2, 0.7), at(room, 9.4, 4.6, wz - 2.6 + index * 1.04), ({ DARK, BLACK, rgb(82, 68, 52), rgb(38, 48, 76) })[(index + rack) % 4 + 1], M.Fabric)
		end
	end
	for index = 0, 3 do
		P(folder, "Parcel", V(1.2, 0.9, 1.2), at(room, -9.5 + (index % 2) * 1.6, 0.45 + math.floor(index / 2) * 0.9, w.WLo + 2.5), rgb(160, 126, 88))
	end
	P(folder, "ServiceBell", V(0.3, 0.5, 0.5), at(room, 2.6, 3.5, 2) * UP, GOLD, M.Metal, Enum.PartType.Cylinder)
end

function rooms.Press(ctx, K, room, folder)
	local P = ctx.part
	local w = roomShell(ctx, K, room, folder, rgb(40, 50, 72), M.Carpet)
	local _, backdrop = ctx.sign(folder, "", at(room, 11, 6.6, 0, -90), 14, 9, CREAM, BLUE, "PressBackdrop")
	backdrop.Material = M.Fabric
	local speaker = ofRoom(room, "Speaker")[1]
	if ctx.lite then
		P(folder, "LecternBlock", V(2.2, 4, 1.6), speaker.Frame * F(0, 2, -1.6), OAK, M.Wood)
	else
		P(folder, "Lectern", V(2.2, 3.6, 1.4), speaker.Frame * F(0, 1.8, -1.6), OAK, M.Wood)
		P(folder, "LecternTop", V(2.6, 0.2, 1.8), speaker.Frame * F(0, 3.75, -1.6) * A(-0.2, 0, 0), DARK, M.Metal)
		P(folder, "LecternCrest", V(1.2, 1.2, 0.08), speaker.Frame * F(0, 2.2, -2.36), GOLD, M.Metal)
		for index = -2, 2 do
			K.microphone(folder, speaker.Frame * F(index * 0.4, 3.9, -2) * A(0, pi, 0))
		end
	end
	for _, entry in ofRoom(room, "Journalist") do
		K.chair(folder, entry.Frame, rgb(70, 72, 78), DARK)
	end
	if ctx.lite then
		return
	end
	for _, entry in ofRoom(room, "Camera") do
		local frame = entry.Frame * F(0, 0, -1.8)
		for leg = 0, 2 do
			P(folder, "TripodLeg", V(0.12, 4.4, 0.12), frame * A(0, leg * 2.1, 0) * F(0, 2.1, 0.5) * A(0.24, 0, 0), BLACK, M.Metal)
		end
		P(folder, "CameraBody", V(0.9, 1, 2), frame * F(0, 4.8, 0), BLACK, M.Metal)
	end
	for _, side in { -1, 1 } do
		P(folder, "StudioLightStand", V(0.15, 8, 0.15), at(room, 6, 4, side * (w.WHi - 2)), BLACK, M.Metal)
		P(folder, "StudioLight", V(1.4, 1, 0.5), at(room, 6.2, 8.2, side * (w.WHi - 2.2)) * A(0, side * 0.6, 0), WARM, M.Glass)
	end
end

function rooms.Library(ctx, K, room, folder)
	local P = ctx.part
	local w = roomShell(ctx, K, room, folder, rgb(78, 40, 36), M.Carpet, DARKWOOD)
	for _, u in { -8, 0, 8 } do
		K.shelf(folder, at(room, u, 0, w.WLo + 0.2, 0), 7, 12.6)
		K.shelf(folder, at(room, u, 0, w.WHi - 0.2, 180), 7, 12.6)
	end
	for _, desk in room.Tables do
		K.table(folder, at(room, desk.U, 0, desk.W, 0), 8, 2.4, WALNUT, GREEN)
		if not ctx.lite then
			for _, u in { -2.4, 2.4 } do
				P(folder, "BankersLampStem", V(0.12, 0.8, 0.12), at(room, desk.U + u, 3.5, desk.W), GOLD, M.Metal)
				P(folder, "BankersLampShade", V(1.1, 0.35, 0.5), at(room, desk.U + u, 4.05, desk.W), rgb(40, 110, 80), M.Glass)
			end
		end
	end
	for _, entry in room.Spots do
		if entry.Kind == "Sit" and entry.Role == nil then
			K.chair(folder, entry.Frame, GREEN, WALNUT)
		end
	end
	local librarian = ofRoom(room, "Librarian")[1]
	K.chair(folder, librarian.Frame, GREEN, WALNUT)
	K.desk(folder, librarian.Frame, 4.2, WALNUT)
	if ctx.lite then
		return
	end
	-- The cast-iron spiral stair the reading room is known for.
	local spiral = at(room, 7.4, 0, 0)
	P(folder, "SpiralPost", V(12.6, 0.5, 0.5), spiral * F(0, 6.3, 0) * UP, rgb(34, 60, 50), M.Metal, Enum.PartType.Cylinder)
	for stepIndex = 0, 17 do
		P(folder, "SpiralStep", V(0.5, 0.16, 2), spiral * A(0, stepIndex * 0.52, 0) * F(0, 0.5 + stepIndex * 0.66, 1.1), rgb(34, 60, 50), M.Metal)
	end
	P(folder, "Globe", V(1.6, 1.6, 1.6), at(room, -9.6, 3.4, 6), rgb(60, 96, 120), M.SmoothPlastic, Enum.PartType.Ball)
	P(folder, "GlobeStand", V(2.6, 0.5, 0.5), at(room, -9.6, 1.3, 6) * UP, WALNUT, M.Wood, Enum.PartType.Cylinder)
end

function rooms.Cafe(ctx, K, room, folder)
	local P = ctx.part
	local w = roomShell(ctx, K, room, folder, rgb(92, 62, 42), M.WoodPlanks)
	K.counter(folder, at(room, 9, 0, 0, -90), 18, WALNUT)
	for _, entry in ofRoom(room, "Stool") do
		K.stool(folder, entry.Frame, RED)
	end
	for _, desk in room.Tables do
		K.round(folder, at(room, desk.U, 0, desk.W), 2.4, WALNUT)
		if not ctx.lite then
			P(folder, "CoffeeCup", V(0.3, 0.3, 0.3), at(room, desk.U - 0.5, 3.15, desk.W + 0.3), WHITE)
			P(folder, "CoffeeCup", V(0.3, 0.3, 0.3), at(room, desk.U + 0.5, 3.15, desk.W - 0.2), WHITE)
		end
	end
	for _, entry in ofRoom(room) do
		K.chair(folder, entry.Frame, rgb(110, 76, 48), WALNUT)
	end
	if ctx.lite then
		return
	end
	P(folder, "EspressoMachine", V(2.4, 1.6, 1.4), at(room, 9.4, 4.15, -5), STEEL, M.Metal)
	local cakes = P(folder, "CakeDisplay", V(1.6, 1.4, 3), at(room, 9, 4.1, 4.4), GLASS, M.Glass)
	cakes.Transparency = 0.6
	for index = 0, 4 do
		P(folder, "PendantLamp", V(0.8, 0.8, 0.8), at(room, 7, 9.4, -7.5 + index * 3.75), WARM, M.Glass, Enum.PartType.Ball)
		P(folder, "PendantCord", V(0.06, w.Ceiling - 9.8, 0.06), at(room, 7, 9.4 + (w.Ceiling - 9.4) / 2, -7.5 + index * 3.75), BLACK)
	end
	K.painting(folder, at(room, -3, 7, w.WLo + 0.2, 0), 5, 3.4, ART[4])
	K.painting(folder, at(room, -3, 7, w.WHi - 0.2, 180), 5, 3.4, ART[1])
	K.sofa(folder, at(room, -10.6, 0, 0, -90), 5.6, rgb(110, 76, 48))
end

function rooms.Security(ctx, K, room, folder)
	local P = ctx.part
	local w = roomShell(ctx, K, room, folder, rgb(52, 56, 62), M.Carpet, DARK)
	for _, entry in ofRoom(room, "Guard") do
		K.chair(folder, entry.Frame, DARK)
		K.desk(folder, entry.Frame, 4, DARK)
	end
	if ctx.lite then
		return
	end
	for column = 0, 3 do
		P(folder, "SecurityMonitor", V(0.15, 2.6, 3.2), at(room, 8.8, 4.4, -5 + column * 3.4) * A(0, 0, 0.15), ({ rgb(48, 86, 106), rgb(50, 98, 80), rgb(64, 76, 108), rgb(40, 70, 88) })[column + 1], M.Glass)
	end
	for index = 0, 5 do
		P(folder, "Locker", V(1.5, 6.6, 1.4), at(room, -9 + index * 1.6, 3.3, w.WLo + 0.95), if index % 2 == 0 then STEEL else rgb(110, 118, 124), M.Metal)
	end
	K.counter(folder, at(room, -6, 0, w.WHi - 1.4, 180), 6, DARK)
end

function rooms.Council(ctx, K, room, folder)
	local P = ctx.part
	local w = roomShell(ctx, K, room, folder, rgb(70, 36, 40), M.Carpet, DARKWOOD)
	local c = Layout.Council
	K.table(folder, F(c.Table), c.Length, c.Width, OAK, GREEN)
	for _, entry in Layout.Seats do
		if entry.Room ~= "Council" then
			continue
		end
		local station = ctx.group(entry.Id .. "Furniture")
		station:SetAttribute("SeatId", entry.Id)
		K.chair(station, entry.Frame, GREEN, if entry.Special then GOLD else DARKWOOD, entry.Special)
		local top = F(entry.Position.X, c.Table.Y, entry.Position.Z) * entry.Frame.Rotation * F(0, 0, if entry.Special then -2.6 else -2.4)
		if entry.Special and not ctx.lite then
			P(station, "ChairpersonGoldCrest", V(0.9, 0.75, 0.08), entry.Frame * F(0, 4.85, 0.5), GOLD, M.Metal)
		end
		K.microphone(station, top * F(0, 3, -0.1))
		K.papers(station, top * F(-0.8, 0, 0.2), 3)
		K.glass(station, top * F(0.8, 0, 0.3), 3)
	end
	if ctx.lite then
		return
	end
	K.chandelier(folder, F(c.Table + V(0, w.Ceiling - 3, 0)), 3.6, 2.2, 0, false)
	K.painting(folder, at(room, -w.U + 0.2, 7.4, -6, 90), 4, 5, ART[5])
	K.painting(folder, at(room, -w.U + 0.2, 7.4, 6, 90), 4, 5, ART[2])
	K.flag(folder, at(room, 10.4, 0, w.WLo + 1.6, -90), { rgb(174, 42, 49), WHITE, BLUE })
	K.flag(folder, at(room, 10.4, 0, w.WHi - 1.6, -90), { rgb(226, 120, 30) })
	K.counter(folder, at(room, -9.6, 0, w.WHi - 2, 90), 4.6, WALNUT)
end

function rooms.Speaker(ctx, K, room, folder)
	local w = roomShell(ctx, K, room, folder, rgb(36, 54, 90), M.Carpet, DARKWOOD)
	local chair = ofRoom(room, "Speaker")[1]
	K.chair(folder, chair.Frame, BLUE, GOLD, true)
	K.desk(folder, chair.Frame, 5.6, WALNUT)
	local plan = room.Table
	K.table(folder, at(room, plan.U, 0, plan.W, 0), plan.LU, plan.LW, OAK, BLUE)
	for _, entry in room.Spots do
		if entry.Role == nil and entry.Kind == "Sit" then
			K.chair(folder, entry.Frame, BLUE)
		elseif entry.Role == "Clerk" then
			K.chair(folder, entry.Frame, rgb(70, 72, 78))
			K.desk(folder, entry.Frame, 3.4, OAK)
		end
	end
	if ctx.lite then
		return
	end
	K.shelf(folder, at(room, 0, 0, w.WHi - 0.2, 180), 9, 9)
	K.sofa(folder, at(room, -9.6, 0, 8, -90), 6, BLUE)
	K.painting(folder, at(room, -w.U + 0.2, 7.4, -6, 90), 4, 5, ART[6])
	K.flag(folder, at(room, 10.4, 0, w.WLo + 1.6, -90), { rgb(174, 42, 49), WHITE, BLUE })
	K.plant(folder, at(room, 10.6, 0, w.WHi - 1.6), 4.6)
	K.clock(folder, at(room, 0, 11.4, w.WLo + 0.2, 0))
end

function rooms.Lounge(ctx, K, room, folder)
	local P = ctx.part
	local w = roomShell(ctx, K, room, folder, rgb(70, 48, 70), M.Carpet, DARKWOOD)
	for _, sofa in room.Sofas do
		K.sofa(folder, at(room, sofa.U, 0, sofa.W, sofa.Facing), 7, rgb(104, 64, 54))
	end
	K.table(folder, at(room, -3.5, 0, 0, 90), 5, 2.6, WALNUT)
	K.counter(folder, at(room, -7, 0, w.WLo + 1.4, 0), 6, WALNUT)
	if ctx.lite then
		return
	end
	K.screen(folder, at(room, -w.U + 0.3, 7, 0, 90), 9, 5)
	K.shelf(folder, at(room, 4, 0, w.WLo + 0.2, 0), 7, 8)
	-- A grand piano for late sittings.
	local piano = at(room, 6, 0, w.WHi - 5, 30)
	P(folder, "PianoBody", V(4.4, 1, 5), piano * F(0, 3, 0), BLACK, M.SmoothPlastic)
	P(folder, "PianoLid", V(4.2, 0.12, 4.6), piano * F(-0.9, 4.6, 0) * A(0, 0, 0.7), BLACK, M.SmoothPlastic)
	P(folder, "PianoKeys", V(3.8, 0.12, 0.7), piano * F(0, 3.1, -2.7), WHITE)
	for _, leg in { { -1.8, -2 }, { 1.8, -2 }, { 0, 2 } } do
		P(folder, "PianoLeg", V(0.3, 2.5, 0.3), piano * F(leg[1], 1.25, leg[2]), BLACK)
	end
	K.plant(folder, at(room, -10.6, 0, w.WHi - 1.6), 5)
end

function rooms.Office(ctx, K, room, folder)
	local P = ctx.part
	local w = roomShell(ctx, K, room, folder, rgb(60, 66, 72), M.Carpet)
	for _, entry in ofRoom(room, "Clerk") do
		K.chair(folder, entry.Frame, TEAL)
		K.desk(folder, entry.Frame, 4, OAK)
	end
	if ctx.lite then
		return
	end
	for index = 0, 6 do
		P(folder, "FilingCabinet", V(1.6, 4.4, 1.4), at(room, -7 + index * 2, 2.2, w.WLo + 0.95), STEEL, M.Metal)
	end
	K.machine(folder, at(room, 10, 0, w.WHi - 1.6, -90), WHITE, GLASS)
	K.plant(folder, at(room, 0, 0, w.WHi - 1.6), 4.4)
end

---------------------------------------------------------------------------------------------------
-- The chambers

-- One member's place: chair, a slice of the curved desk row, screen, vote light, microphone.
local function memberStation(ctx, K, entry, color, trim, spacing)
	local P = ctx.part
	local station = ctx.group(entry.Id .. "Furniture")
	station:SetAttribute("SeatId", entry.Id)
	K.chair(station, entry.Frame, color, trim)
	local desk = entry.Frame * F(0, 2.85, -2.15)
	local index = tonumber(entry.Id:match("%d+")) or 0
	local lift = if index % 2 == 0 then 0.08 else 0
	local width = if spacing then 2 * (entry.Radius - 2.15 + 0.65) * math.tan(rad(spacing / 2)) + 0.04 else 2.35
	if ctx.lite then
		P(station, "DeskBlock", V(width, 2.9, 1.3), desk * F(0, -1.34 + lift, 0), OAK, M.Wood)
		return
	end
	P(station, "OakMemberDesk", V(width, 0.22, 1.3), desk * F(0, lift, 0), OAK, M.Wood)
	P(station, "DeskFront", V(width - 0.04, 2.6, 0.12), desk * F(0, -1.42, -0.55), WALNUT, M.Wood)
	P(station, "DeskScreen", V(0.95, 0.55, 0.08), desk * F(-0.5, 0.45 + lift, -0.3) * A(-0.3, 0, 0), SCREEN, M.Glass)
	ctx.dynamic.VoteLights[entry.Id] = P(station, "VoteLight", V(0.6, 0.06, 0.15), desk * F(-0.45, 0.14 + lift, 0.42), DARK)
	K.microphone(station, desk * F(0.68, 0.11 + lift, -0.3))
end

-- What makes a chamber feel like one: shafts of light, drifting gold dust and a glowing halo.
local function aura(ctx, K, name, centre, height, radius, tint)
	local P = ctx.part
	local model = ctx.group("Aura")
	model:SetAttribute("Aura", name)
	local source = P(model, "AuraSource", V(1, 1, 1), F(centre + V(0, height, 0)), tint)
	source.Transparency = 1
	local floor = P(model, "AuraFloor", V(1, 1, 1), F(centre + V(0, 0.6, 0)), tint)
	floor.Transparency = 1
	for index = 1, 8 do
		local angle = index * pi / 4
		local top, bottom = Instance.new("Attachment"), Instance.new("Attachment")
		top.Position = V(math.sin(angle) * radius * 0.3, 0, math.cos(angle) * radius * 0.3)
		bottom.Position = V(math.sin(angle + 0.4) * radius * 0.8, 0, math.cos(angle + 0.4) * radius * 0.8)
		top.Parent, bottom.Parent = source, floor
		local beam = Instance.new("Beam")
		beam.Name = "AuraLightShaft"
		beam.Attachment0, beam.Attachment1 = top, bottom
		beam.Width0, beam.Width1, beam.FaceCamera, beam.Segments = 3, radius * 0.5, true, 1
		beam.Color, beam.LightEmission, beam.LightInfluence = ColorSequence.new(tint), 1, 0
		beam.Transparency = NumberSequence.new(0.82, 0.98)
		beam.Parent = source
	end
	local cloud = P(model, "AuraDustField", V(radius * 2, 1, radius * 2), F(centre + V(0, height * 0.7, 0)), tint)
	cloud.Transparency = 1
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "AuraDust"
	dust.Rate, dust.Lifetime, dust.Speed = 8, NumberRange.new(10, 16), NumberRange.new(0.3, 0.9)
	dust.EmissionDirection, dust.SpreadAngle = Enum.NormalId.Bottom, Vector2.new(25, 25)
	dust.Size, dust.Transparency = NumberSequence.new(0.16, 0.05), NumberSequence.new(0.35, 1)
	dust.Color, dust.LightEmission, dust.LightInfluence = ColorSequence.new(tint), 0.9, 0
	dust.Parent = cloud
	local glow = Instance.new("PointLight")
	glow.Name, glow.Range, glow.Brightness, glow.Color, glow.Shadows = "AuraGlow", 50, 0.6, tint, false
	glow.Parent = floor
	K.halo(model, F(centre + V(0, height * 0.55, 0)), radius * 0.55, 24, tint, height * 0.4)
	K.halo(model, F(centre + V(0, height * 0.62, 0)), radius * 0.32, 16, WARM)
	return model
end

local function plenary(ctx, K)
	local P = ctx.part
	local focus = Layout.Focus
	local spacing = {}
	for row, count in Layout.Rows do
		spacing[row] = (Layout.Sectors[1][2] - Layout.Sectors[1][1]) / (count / 3 - 1)
	end
	for _, entry in Layout.Seats do
		if entry.Role == "Member" then
			memberStation(ctx, K, entry, BLUE, DARKWOOD, spacing[entry.Row])
		elseif entry.Role == "Minister" then
			local box = Layout.VakK
			memberStation(ctx, K, entry, TEAL, GOLD, (box.To - box.From) / (box.Counts[entry.Row] - 1))
		end
	end
	local speaker = Layout.SeatById.Speaker
	local presiding = ctx.group("PresidingPlatformDetails")
	local chair = ctx.group("SpeakerFurniture")
	chair:SetAttribute("SeatId", "Speaker")
	K.chair(chair, speaker.Frame, BLUE, GOLD, true)
	local dais, z = Layout.Dais, Layout.Speaker.Z
	local h = dais.Height
	if ctx.lite then
		P(presiding, "SpeakerDeskBlock", V(16, 4, 2.6), F(0, h + 2, z + 3), OAK, M.Wood)
		P(presiding, "LecternBlock", V(4.4, 3.8, 3), F(0, 1.9, focus.Z - 6), OAK, M.Wood)
	else
		P(presiding, "SpeakerDesk", V(16, 3.6, 2.4), F(0, h + 1.8, z + 3), OAK, M.Wood)
		P(presiding, "SpeakerDeskTop", V(16.6, 0.25, 2.9), F(0, h + 3.725, z + 3), MARBLE_LIGHT, M.Marble)
		P(presiding, "SpeakerDeskCrest", V(3, 1.8, 0.12), F(0, h + 1.9, z + 4.26), GOLD, M.Metal)
		P(presiding, "DaisFascia", V(2 * dais.X, h - 0.1, 0.12), F(0, h / 2, dais.Z1 + 0.06), DARKWOOD, M.Wood)
		for _, x in { -5, 5 } do
			K.chair(presiding, F(x, h, z) * A(0, pi, 0), BLUE, DARKWOOD)
		end
		P(presiding, "ClerkBench", V(12, 2.8, 2.2), F(0, 1.4, dais.Z1 + 1.6), OAK, M.Wood)
		P(presiding, "ClerkBenchTop", V(12.4, 0.2, 2.6), F(0, 2.9, dais.Z1 + 1.6), MARBLE_LIGHT, M.Marble)
		P(presiding, "DebateLectern", V(4.2, 3.5, 2.4), F(0, 1.75, focus.Z - 6), OAK, M.Wood)
		P(presiding, "LecternTop", V(4.8, 0.25, 3), F(0, 3.65, focus.Z - 6) * A(-0.15, 0, 0), DARK, M.Metal)
		P(presiding, "LecternCrest", V(1.6, 1.6, 0.1), F(0, 1.9, focus.Z - 4.75), GOLD, M.Metal)
		K.microphone(presiding, F(0, 3.75, focus.Z - 6.6) * A(0, pi, 0))
		K.microphone(presiding, F(0, h + 3.85, z + 2.4))
		P(presiding, "BellStand", V(0.3, 1.1, 0.3), Layout.Bell * F(0, -1.05, 0), DARK, M.Metal)
		-- The interruption microphones in front of the benches.
		for _, degrees in { -62, -37, 37, 62 } do
			local stand = Layout.facing(degrees, 15)
			P(presiding, "InterruptionMicStand", V(0.14, 4, 0.14), stand * F(0, 2.1, 0), DARK, M.Metal)
			P(presiding, "InterruptionMicHead", V(0.3, 0.3, 0.6), stand * F(0, 4.25, -0.2), DARK)
			P(presiding, "InterruptionMicFoot", V(0.1, 1.1, 1.1), stand * F(0, 0.05, 0) * UP, DARK, M.Metal, Enum.PartType.Cylinder)
		end
		P(presiding, "DispatchBox", V(1.6, 0.8, 1.1), Layout.facing(Layout.VakK.From + 2, Layout.VakK.Radii[1] - 4.6, 0.4), RED, M.Fabric)
		-- Clerks and stenographers face the government across the floor.
		for index = 0, 2 do
			local frame = Layout.facing(-110 - index * 9, 27)
			K.chair(presiding, frame, rgb(70, 72, 78))
			K.desk(presiding, frame, 3, OAK)
		end
	end

	local walls_ = ctx.group("PlenaryWallDetails")
	for _, side in { -1, 1 } do
		local board = K.screen(walls_, Layout.facing(180 + side * 34, Layout.DrumRadius - 0.6, 28) * A(0, pi, 0), 12, 6, "", "VoteBoard")
		ctx.dynamic.Labels[if side < 0 then "VoteBoardWest" else "VoteBoardEast"] = board
	end
	-- The great blue wall behind the Speaker, with the national arms.
	ctx.ring(walls_, "SpeakerBlueWall", 156, 204, 6, Layout.DrumRadius - 0.45, Layout.DrumRadius - 0.15, 0, Layout.Ceiling - 0.4, rgb(30, 60, 118), M.Fabric, nil, true)
	if not ctx.lite then
		P(walls_, "NationalArms", V(0.3, 9, 9), Layout.facing(180, Layout.DrumRadius - 0.75, 30) * A(0, pi / 2, 0), GOLD, M.Metal, Enum.PartType.Cylinder)
		P(walls_, "NationalArmsShield", V(4.4, 5.4, 0.3), Layout.facing(180, Layout.DrumRadius - 1.1, 30), rgb(30, 60, 118), M.SmoothPlastic)
		for _, dx in { -1.3, 0, 1.3 } do
			P(walls_, "ArmsLion", V(0.7, 3, 0.2), Layout.facing(180, Layout.DrumRadius - 1.4, 30) * F(dx, 0, 0), GOLD, M.Metal)
		end
		for _, offset in { -18, 18 } do
			P(walls_, "BlueWallGoldLine", V(0.3, Layout.Ceiling - 6, 0.12), Layout.facing(180 + offset, Layout.DrumRadius - 0.65, (Layout.Ceiling - 6) / 2 + 3), GOLD, M.Metal)
			K.flag(walls_, Layout.facing(180 + offset * 0.6, Layout.DrumRadius - 3, dais.Height) * A(0, pi, 0), { rgb(174, 42, 49), WHITE, BLUE })
		end
		-- Oak below the gallery, oak slats on warm plaster above it.
		local panels = ctx.group("PlenaryOakPanels")
		local doorAngles = { 30, -30, 90, -90, 180 }
		for index = 0, 47 do
			local degrees = index * 7.5 + 3.75
			local signed = if degrees > 180 then degrees - 360 else degrees
			if math.abs(signed) > 157 then
				continue
			end
			local nearDoor = false
			for _, door in doorAngles do
				if math.abs(signed - door) < 6 then
					nearDoor = true
				end
			end
			local lift = if index % 2 == 0 then 0 else LIFT
			if not nearDoor then
				P(panels, "OakWallPanel", V(2 * Layout.DrumRadius * math.tan(rad(3.75)) - 0.3, 14, 0.2), Layout.facing(degrees, Layout.DrumRadius - 0.2 - lift, 8.5), if index % 2 == 0 then OAK else OAK:Lerp(WALNUT, 0.25), M.Wood)
			end
			if math.abs(signed) < 150 then
				P(panels, "OakAcousticSlat", V(1.2, 30, 0.25), Layout.facing(degrees, Layout.DrumRadius - 0.3, 37), OAK, M.Wood)
			end
		end
		local trim = ctx.group("PlenaryCeilingTrim")
		ctx.ring(trim, "CeilingCoffer", 0, 360, 24, Layout.Oculus + 1, 28, Layout.Ceiling - 0.35, Layout.Ceiling - 0.15, DARKWOOD, M.Wood)
		ctx.ring(trim, "CeilingCoffer", 0, 360, 24, 28, 46, Layout.Ceiling - 0.35, Layout.Ceiling - 0.15, CEILING, M.Wood)
		ctx.ring(trim, "CeilingCoffer", 0, 360, 24, 46, Layout.DrumRadius - 0.6, Layout.Ceiling - 0.35, Layout.Ceiling - 0.15, DARKWOOD, M.Wood)
		ctx.ring(trim, "OculusRim", 0, 360, 24, Layout.Oculus - 0.4, Layout.Oculus + 1, Layout.Ceiling - 0.9, Layout.Ceiling + 0.5, GOLD, M.Metal)
		for index = 0, 23 do
			local degrees = index * 15 + 7.5
			P(trim, "CeilingRib", V(0.6, 0.5, Layout.DrumRadius - Layout.Oculus - 2), Layout.facing(degrees, (Layout.DrumRadius + Layout.Oculus) / 2, Layout.Ceiling - 0.7), GOLD, M.Metal)
		end
		local well = ctx.group("PlenaryWell")
		P(well, "WellMedallion", V(0.08, 18, 18), F(focus + V(0, 0.07, 0)) * UP, rgb(30, 52, 92), M.Marble, Enum.PartType.Cylinder)
		ctx.ring(well, "WellMedallionRing", 0, 360, 24, 7, 7.6, 0.11, 0.19, GOLD, M.Metal)
		P(well, "CompassBar", V(0.6, 0.08, 12), F(focus + V(0, 0.15, 0)), GOLD, M.Metal)
		P(well, "CompassBar", V(12, 0.08, 0.6), F(focus + V(0, 0.23, 0)), GOLD, M.Metal)
		for _, degrees in Layout.Aisles do
			for row = 2, #Layout.Rows do
				P(well, "AisleStepEdge", V(5, 0.06, 0.2), Layout.facing(degrees, Layout.rowRadius(row) - 2.4, Layout.rowRise(row) + 0.06), GOLD, M.Metal)
			end
		end
	end
	-- Warm spotlights in the ceiling ring light the benches; the oculus does the rest.
	local lights = ctx.group("PlenaryLights")
	for index = 0, 7 do
		local degrees = index * 45 + 22.5
		ctx.light(lights, Layout.facing(degrees, 34, Layout.Ceiling - 1.2), 64, 1.1, index % 2 == 0, "SpotLight")
	end
	ctx.light(lights, F(focus + V(0, 12, 0)), 40, 0.5, true)
	if not ctx.lite then
		aura(ctx, K, "House of Representatives", focus, 60, 30, rgb(255, 222, 150))
	end
end

local function tribune(ctx, K)
	local P = ctx.part
	local seats = ctx.group("TribuneSeating")
	local upholstery = rgb(110, 46, 44)
	for _, entry in Layout.Seats do
		if entry.Room == "Tribune" then
			if ctx.lite then
				P(seats, "SeatBlock", V(2.1, 3.4, 1.8), entry.Frame * F(0, 1.7, 0), upholstery, M.Fabric)
			else
				P(seats, "SeatCushion", V(2.15, 0.45, 2.1), entry.Frame * F(0, 1.65, 0), upholstery, M.Fabric)
				P(seats, "TribuneSeatBack", V(2.15, 2.2, 0.3), entry.Frame * F(0, 2.95, 0.9), upholstery, M.Fabric)
				P(seats, "TribuneSeatBase", V(1.9, 1.4, 1.6), entry.Frame * F(0, 0.7, 0.1), DARKWOOD, M.Wood)
			end
		end
	end
	if ctx.lite then
		return
	end
	local ringSpec = Layout.Tribune
	local spans = (ringSpec.To - ringSpec.From) / 15
	local detail = ctx.group("TribuneDetails")
	ctx.ring(detail, "TribuneHandrail", ringSpec.From, ringSpec.To, spans, ringSpec.Inner - 0.1, ringSpec.Inner + 0.4, ringSpec.Y + 3.5, ringSpec.Y + 3.75, GOLD, M.Metal)
	ctx.ring(detail, "TribuneFascia", ringSpec.From, ringSpec.To, spans, ringSpec.Inner - 0.3, ringSpec.Inner - 0.1, ringSpec.Y - 2.6, ringSpec.Y - 0.2, DARKWOOD, M.Wood, nil, true)
	ctx.ring(detail, "TribuneCarpet", ringSpec.From, ringSpec.To, spans, ringSpec.Inner + 0.4, Layout.DrumRadius - 0.3, ringSpec.Y + 0.02, ringSpec.Y + 0.08, rgb(84, 40, 40), M.Carpet)
	for _, degrees in { 126, 138, -126, -138 } do
		local frame = Layout.facing(degrees, 58.5, ringSpec.Y)
		K.chair(detail, frame, rgb(70, 72, 78))
		K.desk(detail, frame, 3.4, DARKWOOD)
	end
end

local function senate(ctx, K)
	local P = ctx.part
	local s = Layout.Senate
	local leather = rgb(126, 38, 40)
	for _, entry in Layout.Seats do
		if entry.Role == "Senator" then
			local station = ctx.group(entry.Id .. "Furniture")
			station:SetAttribute("SeatId", entry.Id)
			K.chair(station, entry.Frame, leather, WALNUT)
			local desk = entry.Frame * F(0, 2.75, -1.85)
			if ctx.lite then
				P(station, "DeskBlock", V(s.Spacing, 2.8, 0.9), desk * F(0, -1.3, 0), WALNUT, M.Wood)
			else
				P(station, "SenateDeskTop", V(s.Spacing, 0.2, 0.95), desk, WALNUT, M.Wood)
				P(station, "SenateDeskFront", V(s.Spacing, 2.6, 0.12), desk * F(0, -1.4, -0.4), DARKWOOD, M.Wood)
				P(station, "SenatePapers", V(0.7, 0.06, 0.6), desk * F(0.4, 0.13, 0), CREAM)
				P(station, "SenateInkwell", V(0.25, 0.25, 0.25), desk * F(-0.8, 0.225, 0.1), GOLD, M.Metal)
			end
		end
	end
	local president = Layout.SeatById.SenatePresident
	local d = s.Dais
	local dais = ctx.group("SenatePresidentDetails")
	local throne = ctx.group("SenatePresidentFurniture")
	throne:SetAttribute("SeatId", "SenatePresident")
	K.chair(throne, president.Frame, leather, GOLD, true)
	local deskZ = president.Position.Z + 3
	if ctx.lite then
		P(dais, "PresidentDeskBlock", V(9, 4.2, 1.8), F(s.X, s.Y + d[4] + 2.1, deskZ), WALNUT, M.Wood)
		ctx.light(dais, F(s.X, 44, -60), 50, 0.8, true)
		return
	end
	P(dais, "PresidentDesk", V(9, 3.2, 1.4), F(s.X, s.Y + d[4] + 1.6, deskZ), WALNUT, M.Wood)
	P(dais, "PresidentDeskTop", V(9.6, 0.25, 1.8), F(s.X, s.Y + d[4] + 3.325, deskZ), MARBLE_LIGHT, M.Marble)
	P(dais, "PresidentCrest", V(2.2, 1.6, 0.12), F(s.X, s.Y + d[4] + 1.7, deskZ + 0.76), GOLD, M.Metal)
	K.microphone(dais, F(s.X, s.Y + d[4] + 3.45, deskZ - 0.2) * A(0, pi, 0))
	-- The canopy over the President's chair.
	for _, x in { -3.6, 3.6 } do
		P(dais, "CanopyPost", V(13, 0.5, 0.5), F(s.X + x, s.Y + d[4] + 6.5, d[1] + 0.8) * UP, GOLD, M.Metal, Enum.PartType.Cylinder)
	end
	P(dais, "CanopyRoof", V(8.8, 0.5, 3), F(s.X, s.Y + d[4] + 13.25, d[1] + 1.8), leather, M.Fabric)
	P(dais, "CanopyValance", V(8.8, 1.4, 0.2), F(s.X, s.Y + d[4] + 12.3, d[1] + 3.2), leather, M.Fabric)
	P(dais, "CanopyGoldTrim", V(9, 0.3, 0.3), F(s.X, s.Y + d[4] + 11.45, d[1] + 3.2), GOLD, M.Metal)
	P(dais, "CanopyDrape", V(7.6, 12, 0.2), F(s.X, s.Y + d[4] + 6.2, d[1] + 0.3), leather:Lerp(BLACK, 0.25), M.Fabric)
	for _, x in { -7.5, 7.5 } do
		local frame = F(s.X + x, s.Y, president.Position.Z) * A(0, pi, 0)
		K.chair(dais, frame, leather, WALNUT)
		K.desk(dais, frame, 3, WALNUT)
	end
	local wallParts = ctx.group("SenateWallDetails")
	local floorY = s.Y
	P(wallParts, "SenateParquet", V(Layout.OuterFace - Layout.InnerFace - 0.4, 0.06, s.Z1 - s.Z0 - 0.9), F(s.X, floorY + 0.05, (s.Z0 + s.Z1) / 2), rgb(92, 60, 38), M.WoodPlanks)
	P(wallParts, "SenateAisleRunner", V(4.4, 0.06, s.Z1 - s.Z0 - 12), F(s.X, floorY + 0.11, (s.Z0 + s.Z1) / 2 + 3), leather:Lerp(BLACK, 0.2), M.Carpet)
	-- Dark wainscot all round, paintings above it on the inner wall.
	local east, west = -Layout.InnerFace - 0.2, -Layout.OuterFace + 0.2
	P(wallParts, "SenateWainscot", V(0.2, 7, s.Z1 - s.Z0 - 1.4), F(east, floorY + 3.6, (s.Z0 + s.Z1) / 2), DARKWOOD, M.Wood)
	P(wallParts, "SenateWainscot", V(0.2, 2.8, s.Z1 - s.Z0 - 1.4), F(west, floorY + 1.5, (s.Z0 + s.Z1) / 2), DARKWOOD, M.Wood)
	for index = 0, 5 do
		local z = -86 + index * 11
		if math.abs(z - (d[2] + 1.7)) > 6 then
			K.painting(wallParts, F(east, floorY + 13, z) * A(0, -pi / 2, 0), 7, 8, ART[index + 1])
		end
	end
	P(wallParts, "SenateNorthPanel", V(Layout.OuterFace - Layout.InnerFace - 1, 9, 0.2), F(s.X, floorY + 4.6, s.Z0 + 0.2), DARKWOOD, M.Wood)
	-- The painted ceiling: coffers in gilt frames, three chandeliers below it.
	local ceiling = ctx.group("SenateCeiling")
	for row = 0, 5 do
		for column = 0, 2 do
			local x, z = s.X - 11 + column * 11, -90 + row * 11
			P(ceiling, "CofferGilt", V(10, 0.12, 10), F(x, Layout.Roof - 0.16, z), GOLD, M.Metal)
			P(ceiling, "CeilingCoffer", V(8.6, 0.12, 8.6), F(x, Layout.Roof - 0.3, z), ART[(row * 3 + column) % #ART + 1]:Lerp(CREAM, 0.3), M.Fabric)
		end
	end
	for _, z in { -80, -62, -44 } do
		K.chandelier(ceiling, F(s.X, 42, z), 3, 11.6, 34, z == -62)
	end
	local gallery = ctx.group("SenateGallery")
	for index = 0, 6 do
		K.bench(gallery, F(-102 + index * 4.6, 2 * Layout.Storey, s.Gallery + 3.6), 3.8, leather:Lerp(BLACK, 0.2))
	end
	P(gallery, "GalleryGoldRail", V(Layout.OuterFace - Layout.InnerFace - 0.2, 0.25, 0.4), F(s.X, 2 * Layout.Storey + 3.65, s.Gallery - 0.15), GOLD, M.Metal)
	aura(ctx, K, "Senate", V(s.X, s.Y, -62), 32, 16, rgb(255, 226, 170))
end

---------------------------------------------------------------------------------------------------
-- Halls, corridors and stairs

local function statenhal(ctx, K)
	local P = ctx.part
	local hall = ctx.group("StatenhalDetails")
	-- The seat board: one bar per party, filled by the client.
	do
		local board = P(hall, "SeatBoard", V(26, 12, 0.3), Layout.facing(0, Layout.DrumOuter + 0.45, 27) * A(0, pi, 0), SCREEN, M.Glass)
		local gui = Instance.new("SurfaceGui")
		gui.Name, gui.Face, gui.SizingMode, gui.PixelsPerStud = "SeatBoardGui", Enum.NormalId.Back, Enum.SurfaceGuiSizingMode.PixelsPerStud, 24
		gui.MaxDistance, gui.LightInfluence = 160, 0
		local title = Instance.new("TextLabel")
		title.Name, title.BackgroundTransparency, title.TextScaled = "Title", 1, true
		title.Size, title.Position = UDim2.fromScale(0.9, 0.12), UDim2.fromScale(0.05, 0.04)
		title.Font, title.TextColor3, title.Text = Enum.Font.GothamBold, CREAM, "SEATS IN THE HOUSE"
		title.Parent = gui
		local fills, counts = {}, {}
		for index, party in Parties.List do
			local y = 0.19 + (index - 1) * 0.115
			local name = Instance.new("TextLabel")
			name.BackgroundTransparency, name.TextScaled, name.TextXAlignment = 1, true, Enum.TextXAlignment.Right
			name.Size, name.Position = UDim2.fromScale(0.3, 0.08), UDim2.fromScale(0.03, y)
			name.Font, name.TextColor3, name.Text = Enum.Font.Gotham, CREAM, party.Name
			name.Parent = gui
			local track = Instance.new("Frame")
			track.BackgroundColor3, track.BorderSizePixel = BLACK, 0
			track.Size, track.Position = UDim2.fromScale(0.5, 0.07), UDim2.fromScale(0.36, y + 0.005)
			track.Parent = gui
			local fill = Instance.new("Frame")
			fill.Name, fill.BackgroundColor3, fill.BorderSizePixel = party.Id, party.Color, 0
			fill.Size = UDim2.fromScale(1 / #Parties.List, 1)
			fill.Parent = track
			local count = Instance.new("TextLabel")
			count.Name, count.BackgroundTransparency, count.TextScaled = party.Id, 1, true
			count.Size, count.Position = UDim2.fromScale(0.1, 0.08), UDim2.fromScale(0.87, y)
			count.Font, count.TextColor3, count.Text = Enum.Font.GothamBold, CREAM, "25"
			count.Parent = gui
			fills[party.Id], counts[party.Id] = fill, count
		end
		local footer = Instance.new("TextLabel")
		footer.Name, footer.BackgroundTransparency, footer.TextScaled = "Footer", 1, true
		footer.Size, footer.Position = UDim2.fromScale(0.9, 0.1), UDim2.fromScale(0.05, 0.88)
		footer.Font, footer.TextColor3, footer.Text = Enum.Font.Gotham, GOLD, ""
		footer.Parent = gui
		gui.Parent = board
		ctx.dynamic.SeatBoard = { Fills = fills, Counts = counts, Footer = footer }
		if not ctx.lite then
			P(hall, "SeatBoardFrame", V(27, 13, 0.2), Layout.facing(0, Layout.DrumOuter + 0.2, 27), DARKWOOD, M.Wood)
		end
	end
	for _, degrees in { -24, 0, 24 } do
		K.chandelier(hall, Layout.facing(degrees, 80, 42), 5, 10.4, 50, degrees == 0)
	end
	if ctx.lite then
		return
	end
	for _, x in { -3, 3 } do
		P(hall, "ReceptionMonitor", V(1.8, 1.1, 0.1), Layout.Reception * F(x, 4.2, -0.6), SCREEN, M.Glass)
	end
	P(hall, "ReceptionTop", V(13.6, 0.25, 3.5), Layout.Reception * F(0, 3.325, 0), MARBLE_LIGHT, M.Marble)
	-- Brass bands following the curve of the hall, and a star at the door.
	local floor = ctx.group("StatenhalFloor")
	ctx.ring(floor, "BrassInlay", -42, 42, 14, 71.6, 72.2, 0.03, 0.09, GOLD, M.Metal)
	ctx.ring(floor, "MarbleBand", -42, 42, 14, 92, 95.4, 0.03, 0.09, MARBLE_LIGHT, M.Marble)
	P(floor, "EntranceRunner", V(6, 0.06, 18), F(0, 0.05, 63), RED, M.Carpet)
	P(floor, "EntranceStar", V(0.8, 0.06, 9), F(0, 0.05, 77) * A(0, pi / 4, 0), GOLD, M.Metal)
	P(floor, "EntranceStar", V(0.8, 0.06, 9), F(0, 0.12, 77) * A(0, -pi / 4, 0), GOLD, M.Metal)
	local gates = ctx.group("StatenhalSecurity")
	for _, x in { -8.4, -4.2, 4.2, 8.4 } do
		P(gates, "SecurityGateArch", V(0.4, 7.4, 1.4), F(x - 0.9, 3.7, 70), STEEL, M.Metal)
		P(gates, "SecurityGateArch", V(0.4, 7.4, 1.4), F(x + 0.9, 3.7, 70), STEEL, M.Metal)
		P(gates, "SecurityGateHead", V(2.2, 0.4, 1.4), F(x, 7.6, 70), STEEL, M.Metal)
	end
	local decor = ctx.group("StatenhalDecor")
	local hc = Layout.HallColumns
	for _, degrees in hc.Angles do
		local base = Layout.facing(degrees, hc.Radius)
		P(decor, "ColumnBase", V(1.2, 4.2, 4.2), base * F(0, 0.6, 0) * UP, MARBLE_LIGHT, M.Marble, Enum.PartType.Cylinder)
		P(decor, "ColumnCapital", V(1.4, 4.4, 4.4), base * F(0, Layout.Roof - 1, 0) * UP, GOLD, M.Metal, Enum.PartType.Cylinder)
	end
	for index, degrees in { -33, -11, 11, 33 } do
		K.statue(decor, Layout.facing(degrees, 94.6) * A(0, pi, 0), if index % 2 == 0 then BRONZE else rgb(150, 144, 132))
	end
	for _, degrees in { -24, 8, 24 } do
		K.bench(decor, Layout.facing(degrees, 73.5), 6, RED)
	end
	for index, party in Parties.List do
		local degrees = -12.5 + (index - 1) * 5
		K.flag(decor, Layout.facing(degrees, Layout.DrumOuter + 2.6) * A(0, pi / 2, 0), { party.Color })
	end
	-- Pilasters and bronze portals on the chamber's wall, coffers on the ceiling.
	for degrees = -52.5, 52.5, 15 do
		P(decor, "DrumPilaster", V(1.6, Layout.Roof - 0.4, 0.6), Layout.facing(degrees, Layout.DrumOuter + 0.4, Layout.Roof / 2 - 0.2), STONE, M.Limestone)
	end
	for _, degrees in { -30, 30 } do
		local door = Layout.facing(degrees, Layout.DrumOuter + 0.45)
		for _, side in { -1, 1 } do
			P(decor, "PortalJamb", V(1, 14, 0.7), door * F(side * 4.6, 7, 0), BRONZE, M.Metal)
		end
		P(decor, "PortalHead", V(10.2, 1.4, 0.7), door * F(0, 14.4, 0), BRONZE, M.Metal)
	end
	local ceiling = ctx.group("StatenhalCeiling")
	ctx.ring(ceiling, "HallCoffer", -44, 44, 12, Layout.DrumOuter + 1, 80, Layout.Roof - 0.35, Layout.Roof - 0.15, CEILING, M.Wood)
	ctx.ring(ceiling, "HallCoffer", -44, 44, 12, 80, Layout.HallRadius - 1, Layout.Roof - 0.35, Layout.Roof - 0.15, CEILING:Lerp(BLACK, 0.2), M.Wood)
	for degrees = -44, 44, 8 do
		P(ceiling, "HallCeilingRib", V(0.6, 0.5, 30), Layout.facing(degrees, 81, Layout.Roof - 0.75), GOLD, M.Metal)
	end
	-- Dark wainscot along the wing walls facing the hall.
	for _, side in { -1, 1 } do
		P(decor, "HallWainscot", V(0.2, 6, 38), F(side * (Layout.WingInner - Layout.Wall / 2 - 0.2), 3.1, -1), DARKWOOD, M.Wood)
		K.painting(decor, F(side * (Layout.WingInner - Layout.Wall / 2 - 0.2), 12, 12) * A(0, -side * pi / 2, 0), 9, 7, ART[if side < 0 then 2 else 5])
	end
end

local function wandelgang(ctx, K)
	local P = ctx.part
	local lobby = ctx.group("WandelgangDetails")
	local inner = Layout.WingInner - Layout.Wall / 2
	for floor = 0, 2 do
		local y = floor * Layout.Storey
		local ceilingY = if floor == 2 then Layout.Roof else y + Layout.Storey - 1
		ctx.light(lobby, F(0, ceilingY - 2.2, Layout.RearDoorZ), 40, 0.75, true)
		if ctx.lite then
			continue
		end
		ctx.light(lobby, F(-44, ceilingY - 2.2, Layout.RearDoorZ), 26, 0.55)
		ctx.light(lobby, F(44, ceilingY - 2.2, Layout.RearDoorZ), 26, 0.55)
		P(lobby, "LobbyRunner", V(2 * inner - 4, 0.06, 5), F(0, y + 0.05, Layout.RearDoorZ), RED, M.Carpet)
		for index = 0, 6 do
			local x = -54 + index * 18
			K.painting(lobby, F(x, y + 8, Layout.InnerNorth + 0.2), 5, 6.2, ART[(index + floor) % #ART + 1])
		end
		P(lobby, "LobbyWainscot", V(2 * inner - 0.4, 4.5, 0.2), F(0, y + 2.35, Layout.InnerNorth + 0.2), DARKWOOD, M.Wood)
		K.bench(lobby, F(-27, y, Layout.InnerNorth + 2.4), 6, RED)
		K.bench(lobby, F(27, y, Layout.InnerNorth + 2.4), 6, RED)
		if floor > 0 then
			P(lobby, "GalleryGoldRail", V(2 * inner - 0.4, 0.25, 0.4), F(0, y + 3.65, Layout.RearZ - 0.15), GOLD, M.Metal)
		end
	end
	if ctx.lite then
		return
	end
	for _, x in { -36, 36 } do
		K.statue(lobby, F(x, 0, Layout.RearZ + 3), BRONZE)
	end
	-- The two tall courts beside the chamber become palm courts under their skylights.
	for _, side in { -1, 1 } do
		local court = ctx.group(if side < 0 then "WestPalmCourt" else "EastPalmCourt")
		for index, spot in { { 48, -66 }, { 58, -52 }, { 40, -74 }, { 60, -32 } } do
			local frame = F(side * spot[1], 0, spot[2])
			P(court, "PalmTub", V(1.8, 2.8, 2.8), frame * F(0, 0.9, 0) * UP, BRONZE, M.Metal, Enum.PartType.Cylinder)
			P(court, "PalmTrunk", V(14 + index * 3, 0.7, 0.7), frame * F(0, 8.8 + index * 1.5, 0) * UP, WALNUT, M.Wood, Enum.PartType.Cylinder)
			for leaf = 0, 5 do
				P(court, "PalmFrond", V(1, 0.15, 6), frame * F(0, 16 + index * 3, 0) * A(0, leaf * pi / 3, 0) * A(-0.5, 0, 0) * F(0, 0, 2.7), LEAF, M.Grass)
			end
		end
	end
end

local function corridorZone(ctx, K, side, floor)
	local P = ctx.part
	local y = floor * Layout.Storey
	local group = ctx.group("CorridorDetails")
	local senate = Layout.senateFloor(side, floor)
	local north = if senate then Layout.Senate.Z1 + 0.5 else Layout.InnerNorth
	local south = Layout.StairZ - Layout.Wall / 2
	local inner, wallX = Layout.InnerFace, Layout.RoomWall - 0.5
	local ceilingY = if floor == Layout.Floors - 1 then Layout.Roof else y + Layout.Storey - 1
	local mid = (north + south) / 2
	ctx.light(group, F(side * Layout.CorridorX, ceilingY - 2, mid), 40, 0.7, true)
	-- Door plaques: the only text in the corridors.
	for _, room in Layout.Rooms do
		if room.Side == side and room.Floor == floor and room.Doors then
			local title = room.Name
			if room.Party then
				title = Parties.List[room.Party].Name
			end
			for _, z in room.Doors do
				local plaque = F(side * (wallX - 0.08), y + 6.4, z + Layout.Door / 2 + 1.6) * A(0, -side * pi / 2, 0)
				ctx.sign(group, title, plaque, 2.6, 0.8, DARKWOOD, GOLD, "DoorPlaque", 30)
			end
		end
	end
	-- The division bell's lamps: they flash while the bell rings.
	for _, z in { 20, north + 4 } do
		local lamp = P(group, "BellLamp", V(0.5, 0.9, 0.9), F(side * (inner + 0.3), y + 10, z), rgb(110, 88, 56), M.SmoothPlastic, Enum.PartType.Cylinder)
		table.insert(ctx.dynamic.BellLamps, lamp)
	end
	if ctx.lite then
		return
	end
	ctx.light(group, F(side * Layout.CorridorX, ceilingY - 2, mid - 40), 26, 0.5)
	ctx.light(group, F(side * Layout.CorridorX, ceilingY - 2, mid + 40), 26, 0.5)
	local width = wallX - inner - 0.2
	P(group, "CorridorParquet", V(width, 0.06, south - north - 0.2), F(side * (inner + wallX) / 2, y + 0.05, mid), rgb(96, 64, 40), M.WoodPlanks)
	P(group, "CorridorRunner", V(4, 0.06, south - north - 4), F(side * Layout.CorridorX, y + 0.11, mid), RED, M.Carpet)
	P(group, "CorridorCeiling", V(width, 0.1, south - north - 0.2), F(side * (inner + wallX) / 2, ceilingY - 0.15, mid), CEILING, M.Wood)
	-- Wainscot along the corridor wall, broken by the doors and their frames.
	local doors = {}
	for _, room in Layout.Rooms do
		if room.Side == side and room.Floor == floor and room.Doors then
			for _, z in room.Doors do
				table.insert(doors, { z - Layout.Door / 2 - 0.6, z + Layout.Door / 2 + 0.6 })
				for _, dz in { -1, 1 } do
					P(group, "DoorJamb", V(0.4, Layout.DoorHeight + 0.4, 0.6), F(side * (wallX - 0.2), y + Layout.DoorHeight / 2 + 0.2, z + dz * (Layout.Door / 2 + 0.3)), DARKWOOD, M.Wood)
				end
				P(group, "DoorHead", V(0.4, 0.8, Layout.Door + 1.2), F(side * (wallX - 0.2), y + Layout.DoorHeight + 0.4, z), DARKWOOD, M.Wood)
			end
		end
	end
	table.sort(doors, function(a, b)
		return a[1] < b[1]
	end)
	local cursor = north + 0.1
	for _, span in doors do
		if span[1] - cursor > 0.5 then
			P(group, "Wainscot", V(0.2, 4.5, span[1] - cursor), F(side * (wallX - 0.1), y + 2.35, (cursor + span[1]) / 2), WALNUT, M.Wood)
		end
		cursor = span[2]
	end
	if south - 0.1 - cursor > 0.5 then
		P(group, "Wainscot", V(0.2, 4.5, south - 0.1 - cursor), F(side * (wallX - 0.1), y + 2.35, (cursor + south - 0.1) / 2), WALNUT, M.Wood)
	end
	for index, z in { north + 10, -40, -2, 18 } do
		if z > north + 4 and math.abs(z - Layout.SideDoorZ) > 8 and math.abs(z - Layout.RearDoorZ) > 8 then
			if index % 2 == 0 then
				K.painting(group, F(side * (inner + 0.1), y + 7.4, z) * A(0, side * pi / 2, 0), 5, 4, ART[(index + floor * 2) % #ART + 1])
			else
				K.bench(group, F(side * (inner + 1.2), y, z) * A(0, pi / 2, 0), 5, if floor == 0 then RED else BLUE)
			end
		end
	end
	K.plant(group, F(side * (inner + 1.6), y, south - 2.4), 4.4)
end

local function stairZone(ctx, K, side)
	local P = ctx.part
	local group = ctx.group("StairDetails")
	local st = Layout.Stair
	K.chandelier(group, F(side * st.B, 44, (st.Low + st.High) / 2), 3, 9.6, 46, true)
	if ctx.lite then
		return
	end
	local treads = ctx.group("StairTreads")
	local rise, run = Layout.Storey / 2, st.High - st.Low
	local steps = 12
	for level = 0, 1 do
		local y = level * Layout.Storey
		for tread = 0, steps - 1 do
			local top = (tread + 1) * rise / steps
			local depth = run / steps
			P(treads, "StairTread", V(st.Width - 0.6, top + 0.02, depth), F(side * st.A, y + top / 2 - 0.01, st.Low + (tread + 0.5) * depth), MARBLE_LIGHT, M.Marble)
			P(treads, "StairTread", V(st.Width - 0.6, top + 0.02, depth), F(side * st.B, y + rise + top / 2 - 0.01, st.High - (tread + 0.5) * depth), MARBLE_LIGHT, M.Marble)
		end
		local pitch = math.atan2(rise, run)
		local length = math.sqrt(run * run + rise * rise)
		for _, x in { st.A - st.Width / 2 + 0.2, st.A + st.Width / 2 - 0.2 } do
			P(group, "StairHandrail", V(0.2, 0.2, length), F(side * x, y + rise / 2 + 3.4, (st.Low + st.High) / 2) * A(-pitch, 0, 0), GOLD, M.Metal)
		end
		for _, x in { st.B - st.Width / 2 + 0.2, st.B + st.Width / 2 - 0.2 } do
			P(group, "StairHandrail", V(0.2, 0.2, length), F(side * x, y + rise * 1.5 + 3.4, (st.Low + st.High) / 2) * A(pitch, 0, 0), GOLD, M.Metal)
		end
	end
	for floor = 0, 2 do
		K.plant(group, F(side * 73, floor * Layout.Storey, Layout.InnerFront - 2), 4.6)
	end
end

---------------------------------------------------------------------------------------------------
-- The outside: ornament on the facade, the dome's ribs, the roof gardens and the forecourt.

local function exterior(ctx, K)
	local P = ctx.part
	if ctx.lite then
		return
	end
	local columns = ctx.group("PorticoOrnament")
	local count = 14
	local span = math.deg(math.asin(66 / Layout.ColumnRadius))
	for index = 0, count - 1 do
		local frame = Layout.facing(-span + index * 2 * span / (count - 1), Layout.ColumnRadius)
		P(columns, "ColumnPlinth", V(4.2, 0.6, 4.2), frame * F(0, 0.3, 0), STONE, M.Marble)
		P(columns, "ColumnBase", V(1, 3.8, 3.8), frame * F(0, 1.1, 0) * UP, STONE, M.Marble, Enum.PartType.Cylinder)
		P(columns, "ColumnCapital", V(1.2, 3.9, 3.9), frame * F(0, Layout.Roof - 1.2, 0) * UP, STONE, M.Marble, Enum.PartType.Cylinder)
		P(columns, "ColumnAbacus", V(4.2, 0.5, 4.2), frame * F(0, Layout.Roof - 0.35, 0), STONE, M.Marble)
	end
	local frieze = ctx.group("PorticoFrieze")
	ctx.ring(frieze, "GoldFrieze", -Layout.HallSpan - 2, Layout.HallSpan + 2, 15, Layout.ColumnRadius + 3.1, Layout.ColumnRadius + 3.3, Layout.Roof + 1.2, Layout.Roof + 1.6, GOLD, M.Metal)
	-- Bronze mullions in every window bay.
	local mullions = ctx.group("FacadeMullions")
	for _, sx in { -1, 1 } do
		for z = Layout.North + 12, Layout.WingFront - 8, 12 do
			P(mullions, "FacadeMullion", V(0.3, 48, 0.4), F(sx * (Layout.HalfWidth + 0.25), 27, z), BRONZE, M.Metal)
		end
	end
	for x = -96, 96, 12 do
		P(mullions, "FacadeMullion", V(0.4, 48, 0.3), F(x, 27, Layout.North - 0.25), BRONZE, M.Metal)
	end
	-- The dome: bronze ribs over every seam and a gilded ring at each band.
	local ribs = ctx.group("DomeRibs")
	local latitudes = { 0, 20, 40, 60, 78 }
	for band = 1, #latitudes - 1 do
		local a0, a1 = rad(latitudes[band]), rad(latitudes[band + 1])
		local r0, y0 = Layout.DomeRadius * math.cos(a0), Layout.DomeRise * math.sin(a0)
		local r1, y1 = Layout.DomeRadius * math.cos(a1), Layout.DomeRise * math.sin(a1)
		local length = math.sqrt((r1 - r0) ^ 2 + (y1 - y0) ^ 2) + 0.3
		local tilt = math.atan2(r1 - r0, y1 - y0)
		for index = 0, 23 do
			P(ribs, "DomeRib", V(0.6, length, 0.6), Layout.facing(index * 15 + 7.5, (r0 + r1) / 2 + 0.45, Layout.DrumTop + (y0 + y1) / 2) * A(tilt, 0, 0), BRONZE, M.Metal)
		end
		if band > 1 then
			ctx.ring(ribs, "DomeRing", 0, 360, 24, r0 + 0.2, r0 + 0.7, Layout.DrumTop + y0 - 0.2, Layout.DrumTop + y0 + 0.2, GOLD, M.Metal)
		end
	end
	local drum = ctx.group("DrumOrnament")
	for index = 0, 23 do
		P(drum, "DrumPilaster", V(1.4, Layout.ClerestoryTop - Layout.Roof - 2, 0.8), Layout.facing(index * 15 + 7.5, Layout.DrumOuter + 0.5, (Layout.ClerestoryTop + Layout.Roof + 2) / 2), STONE, M.Marble)
	end
	-- Roof gardens on both wings.
	local roofTop = Layout.Roof + 1.5
	for _, side in { -1, 1 } do
		local garden = ctx.group(if side < 0 then "WestRoofGarden" else "EastRoofGarden")
		for index = 0, 6 do
			local frame = F(side * (78 + (index % 2) * 20), roofTop, -86 + index * 23)
			P(garden, "RoofTreeTub", V(3.4, 1.6, 3.4), frame * F(0, 0.8, 0), STONE, M.Concrete)
			P(garden, "RoofTreeTrunk", V(0.6, 4.4, 0.6), frame * F(0, 3.8, 0), WALNUT, M.Wood)
			P(garden, "RoofTreeCrown", V(6.4, 5.4, 6.4), frame * F(0, 7.6, 0), LEAF, M.Grass, Enum.PartType.Ball)
		end
		for index = 0, 4 do
			P(garden, "RoofHedge", V(1.6, 1.8, 20), F(side * 104, roofTop + 0.9, -82 + index * 32), rgb(62, 92, 64), M.Grass)
			P(garden, "RoofPath", V(5, 0.08, 26), F(side * 88, roofTop + 0.04, -82 + index * 32), rgb(176, 166, 148), M.Concrete)
		end
	end
	-- The forecourt: fountain jets in the pool, lamps beside it.
	local court = ctx.group("ForecourtDetails")
	local ground = -0.6
	local poolMid = Layout.Front + 29
	for index = 0, 4 do
		local jet = P(court, "FountainJet", V(3.6 + (index % 2), 0.4, 0.4), F(-16 + index * 8, ground + 2.2, poolMid) * UP, WHITE, M.Glass, Enum.PartType.Cylinder)
		jet.Transparency = 0.45
		P(court, "FountainNozzle", V(0.4, 0.7, 0.7), F(-16 + index * 8, ground + 0.5, poolMid) * UP, BRONZE, M.Metal, Enum.PartType.Cylinder)
	end
	for _, side in { -1, 1 } do
		for index = 0, 3 do
			local frame = F(side * 29, ground, Layout.Front + 19 + index * 7)
			P(court, "BollardLamp", V(0.6, 2.6, 0.6), frame * F(0, 1.3, 0), DARK, M.Metal)
			P(court, "BollardGlow", V(0.5, 0.4, 0.5), frame * F(0, 2.8, 0), WARM, M.Glass)
		end
	end
end

---------------------------------------------------------------------------------------------------

-- Every zone: where it is (for nearest-first building) and whether it shows from the square.
function Interior.zones()
	local zones = {
		{ Name = "Exterior", Centre = V(0, 30, 80), Outside = true, Build = exterior },
		{ Name = "Statenhal", Centre = V(0, 0, 70), Outside = true, Build = statenhal },
		{ Name = "TweedeKamer", Centre = Layout.Focus, Build = plenary },
		{ Name = "Tribune", Centre = Layout.Focus + V(0, Layout.Storey, 0), Build = tribune },
		{ Name = "EersteKamer", Centre = V(Layout.Senate.X, Layout.Storey, -60), Build = senate },
		{ Name = "Wandelgang", Centre = V(0, 0, -90), Build = wandelgang },
	}
	for _, side in { -1, 1 } do
		local wing = if side < 0 then "West" else "East"
		table.insert(zones, { Name = wing .. "Stairs", Centre = V(side * 92, 18, 48), Build = function(ctx, K)
			stairZone(ctx, K, side)
		end })
		for floor = 0, 2 do
			table.insert(zones, { Name = wing .. "Corridor" .. floor, Centre = V(side * Layout.CorridorX, floor * Layout.Storey, -30), Build = function(ctx, K)
				corridorZone(ctx, K, side, floor)
			end })
		end
	end
	for _, room in Layout.Rooms do
		local builder = rooms[room.Kind]
		if builder and room.Frame then
			table.insert(zones, { Name = "Room" .. room.Id, Centre = room.Centre, Room = room.Id, Build = function(ctx, K)
				builder(ctx, K, room, ctx.group(room.Id .. "Furnishings"))
			end })
		end
	end
	return zones
end

-- Builds one zone into its own folder under `parent`.
function Interior.buildZone(ctx, parent: Instance, zone)
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = zone.Name, parent
	ctx.folder = folder
	ctx.kit = ctx.kit or kit(ctx)
	zone.Build(ctx, ctx.kit)
	return folder
end

-- Builds everything at once (checks and previews); the client paces zones itself.
function Interior.build(parent: Instance, base: CFrame, checkpoint: (() -> ())?, options)
	local ctx = Interior.context(base, checkpoint, options and options.Performance)
	for _, zone in Interior.zones() do
		if not options or not options.Only or options.Only(zone) then
			Interior.buildZone(ctx, parent, zone)
		end
	end
	return ctx
end
return Interior
