-- The owner's starting office furniture in a base house: a worn wooden desk,
-- a tweed swivel chair and a yellowed late-80s desktop PC (flat case with the
-- CRT on top, a heavy keyboard, a ball mouse and some floppies). The owner can
-- sit down and use the PC (client OfficeComputer, server OfficeComputerService):
-- the chair carries a hidden Seat and rolls up to the desk while it is used.
--
-- Desk-local frame: origin on the floor under the middle of the desk, +Z is the
-- side the owner sits on (the desk's back meets the office's back wall).
local OfficeDesk = {}
local VERSION = 2

-- Where the chair stands, desk-local: left a little askew when free, square in
-- front of the monitor while someone sits at the computer.
local CHAIR_FREE = CFrame.new(0.15, 0, 2.7) * CFrame.Angles(0, 0.22, 0)
local CHAIR_SEATED = CFrame.new(-0.6, 0, 2.1)

local rgb = Color3.fromRGB
local M = Enum.Material

local VENEER = rgb(120, 82, 52)
local VENEER_DARK = rgb(78, 53, 35)
local BRASS = rgb(168, 136, 70)
local BEIGE = rgb(204, 192, 160) -- case plastic gone yellow with age
local BEIGE_LIGHT = rgb(214, 204, 175)
local BEIGE_DARK = rgb(176, 164, 133)
local FACEPLATE = rgb(188, 176, 145)
local CHARCOAL = rgb(44, 42, 40)
local SLOT = rgb(18, 17, 16)
local KEY_LIGHT = rgb(218, 211, 192)
local KEY_DARK = rgb(156, 150, 138)
local SCREEN = rgb(14, 26, 18)
local PHOSPHOR = rgb(110, 255, 140)
local TWEED = rgb(102, 78, 60)
local TWEED_WORN = rgb(124, 98, 76)
local BLACK_PLASTIC = rgb(32, 31, 33)
local CHROME = rgb(152, 152, 148)
local CABLE = rgb(58, 56, 52)

local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis along Y
local FACING = CFrame.Angles(0, math.pi / 2, 0) -- cylinder axis along Z

local DESK_W, DESK_D, DESK_H = 6.6, 3.1, 2.9
local TOP_T = 0.16

local function make(
	kind: string,
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	solid: boolean?
): BasePart
	local piece: BasePart
	if kind == "Wedge" then
		piece = Instance.new("WedgePart")
	else
		local part = Instance.new("Part")
		if kind == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		elseif kind == "Ball" then
			part.Shape = Enum.PartType.Ball
		end
		piece = part
	end
	piece.Name = name
	piece.Anchored = true
	piece.CanTouch = false
	piece.CanCollide = solid == true
	piece.CanQuery = solid == true
	-- Only the larger pieces throw shadows; keycaps and LEDs would just add cost.
	piece.CastShadow = solid == true or math.max(size.X, size.Y, size.Z) >= 0.6
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Material = material or M.SmoothPlastic
	piece.Color = color
	piece.Size = size
	piece.CFrame = cframe
	piece.Parent = parent
	return piece
end

local function group(parent: Instance, name: string): Model
	local result = Instance.new("Model")
	result.Name = name
	result.Parent = parent
	return result
end

-- Text printed on the part's local +Z face.
local function label(
	part: BasePart,
	text: string,
	color: Color3,
	font: Enum.Font,
	glow: boolean?,
	align: Enum.TextXAlignment?
): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(part.Size.X * 200, part.Size.Y * 200)
	gui.LightInfluence = if glow then 0 else 1
	gui.Parent = part
	local line = Instance.new("TextLabel")
	line.BackgroundTransparency = 1
	line.Size = UDim2.new(1, -12, 1, -8)
	line.Position = UDim2.new(0, 6, 0, 4)
	line.Font = font
	line.Text = text
	line.TextColor3 = color
	-- Scaled, never wrapped: multi-line text keeps its own line breaks.
	line.TextScaled = true
	line.TextWrapped = false
	line.TextXAlignment = align or Enum.TextXAlignment.Center
	line.TextYAlignment = if align == Enum.TextXAlignment.Left
		then Enum.TextYAlignment.Top
		else Enum.TextYAlignment.Center
	if glow then
		-- A faint same-colour stroke reads as phosphor bloom.
		line.TextStrokeColor3 = color
		line.TextStrokeTransparency = 0.85
	end
	line.Parent = gui
	return line
end

-- A cable laid through `points` (frame-local { x, y, z }), one straight run per
-- segment, each lengthened by its thickness so the bends stay closed.
local function cable(parent: Instance, frame: CFrame, points: { { number } }, thickness: number, color: Color3)
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local flat = math.sqrt(dx * dx + dz * dz)
		local length = math.sqrt(flat * flat + dy * dy)
		make(
			"Part",
			parent,
			"Cable",
			Vector3.new(thickness, thickness, length + thickness),
			frame
				* CFrame.new((a[1] + b[1]) / 2, (a[2] + b[2]) / 2, (a[3] + b[3]) / 2)
				* CFrame.Angles(0, math.atan2(dx, dz), 0)
				* CFrame.Angles(math.atan2(-dy, flat), 0, 0),
			color,
			M.Rubber
		)
	end
end

local function buildDesk(root: Model, frame: CFrame)
	local desk = group(root, "Desk")
	local function at(x: number, y: number, z: number): CFrame
		return frame * CFrame.new(x, y, z)
	end
	make(
		"Part",
		desk,
		"DeskTop",
		Vector3.new(DESK_W, TOP_T, DESK_D),
		at(0, DESK_H - TOP_T / 2, 0),
		VENEER,
		M.Wood,
		true
	)
	make(
		"Part",
		desk,
		"DeskEdge",
		Vector3.new(DESK_W + 0.04, 0.08, 0.06),
		at(0, DESK_H - TOP_T - 0.04, DESK_D / 2 - 0.01),
		VENEER_DARK,
		M.Wood
	)

	-- Drawer pedestal on the owner's right.
	local pedL, pedR = 1.15, DESK_W / 2 - 0.12
	local pedW, pedX = pedR - pedL, (pedL + pedR) / 2
	local pedBack, pedFront = -DESK_D / 2 + 0.1, DESK_D / 2 - 0.12
	local pedBottom, pedTop = 0.14, DESK_H - TOP_T
	make(
		"Part",
		desk,
		"Pedestal",
		Vector3.new(pedW, pedTop - pedBottom, pedFront - pedBack),
		at(pedX, (pedBottom + pedTop) / 2, (pedBack + pedFront) / 2),
		VENEER_DARK,
		M.Wood,
		true
	)
	make(
		"Part",
		desk,
		"PedestalPlinth",
		Vector3.new(pedW - 0.12, pedBottom, pedFront - pedBack - 0.16),
		at(pedX, pedBottom / 2, (pedBack + pedFront) / 2 - 0.04),
		CHARCOAL,
		M.Wood,
		true
	)
	local top = pedTop
	for index, height in { 0.62, 0.78, pedTop - pedBottom - 1.4 } do
		local y = top - height / 2
		make(
			"Part",
			desk,
			"DrawerFront",
			Vector3.new(pedW - 0.08, height - 0.06, 0.06),
			at(pedX, y, pedFront + 0.03),
			VENEER,
			M.Wood
		)
		local handleY = if index == 3 then top - 0.3 else y
		for _, side in { -1, 1 } do
			make(
				"Part",
				desk,
				"HandlePost",
				Vector3.new(0.05, 0.05, 0.07),
				at(pedX + side * 0.27, handleY, pedFront + 0.095),
				BRASS,
				M.Metal
			)
		end
		make(
			"Part",
			desk,
			"DrawerHandle",
			Vector3.new(0.64, 0.05, 0.05),
			at(pedX, handleY, pedFront + 0.145),
			BRASS,
			M.Metal
		)
		if index == 1 then
			make(
				"Cylinder",
				desk,
				"KeyEscutcheon",
				Vector3.new(0.02, 0.08, 0.08),
				at(pedX, top - 0.09, pedFront + 0.07) * FACING,
				BRASS,
				M.Metal
			)
			make("Part", desk, "Keyhole", Vector3.new(0.014, 0.036, 0.01), at(pedX, top - 0.09, pedFront + 0.083), SLOT)
		elseif index == 3 then
			make(
				"Part",
				desk,
				"LabelHolder",
				Vector3.new(0.42, 0.2, 0.02),
				at(pedX, top - 0.56, pedFront + 0.07),
				BRASS,
				M.Metal
			)
			make(
				"Part",
				desk,
				"LabelCard",
				Vector3.new(0.36, 0.14, 0.012),
				at(pedX, top - 0.56, pedFront + 0.082),
				rgb(232, 224, 200)
			)
		end
		top -= height
	end

	-- Panel leg on the left, modesty panel at the back, pencil drawer between.
	local legX = -DESK_W / 2 + 0.19
	make(
		"Part",
		desk,
		"LegPanel",
		Vector3.new(0.14, pedTop, DESK_D - 0.2),
		at(legX, pedTop / 2, 0),
		VENEER,
		M.Wood,
		true
	)
	make("Part", desk, "LegFoot", Vector3.new(0.18, 0.08, DESK_D - 0.16), at(legX, 0.04, 0), VENEER_DARK, M.Wood)
	local innerL = legX + 0.07
	make(
		"Part",
		desk,
		"ModestyPanel",
		Vector3.new(pedL - innerL, 1.5, 0.06),
		at((innerL + pedL) / 2, pedTop - 0.75, -DESK_D / 2 + 0.25),
		VENEER_DARK,
		M.Wood,
		true
	)
	local drawerX, drawerW = (innerL + pedL) / 2, pedL - innerL - 0.09
	make(
		"Part",
		desk,
		"PencilDrawerBox",
		Vector3.new(drawerW, 0.3, 2.4),
		at(drawerX, pedTop - 0.17, pedFront - 1.2),
		VENEER_DARK,
		M.Wood
	)
	make(
		"Part",
		desk,
		"PencilDrawer",
		Vector3.new(drawerW, 0.3, 0.06),
		at(drawerX, pedTop - 0.17, pedFront + 0.03),
		VENEER,
		M.Wood
	)
	make(
		"Part",
		desk,
		"PencilDrawerPull",
		Vector3.new(0.5, 0.04, 0.05),
		at(drawerX, pedTop - 0.27, pedFront + 0.085),
		BRASS,
		M.Metal
	)

	-- Green leather blotter under the keyboard, with darker leather ends.
	local blotterX, blotterZ, blotterW, blotterD = -0.5, 0.98, 3.6, 1.0
	make(
		"Part",
		desk,
		"Blotter",
		Vector3.new(blotterW, 0.02, blotterD),
		at(blotterX, DESK_H + 0.01, blotterZ),
		rgb(42, 74, 54),
		M.Leather
	)
	for _, side in { -1, 1 } do
		make(
			"Part",
			desk,
			"BlotterEnd",
			Vector3.new(0.18, 0.026, blotterD + 0.02),
			at(blotterX + side * (blotterW / 2 - 0.08), DESK_H + 0.013, blotterZ),
			rgb(70, 44, 30),
			M.Leather
		)
	end
end

-- Flat desktop case, origin on the desk under its middle, front +Z.
local CASE_W, CASE_H, CASE_D = 2.5, 0.6, 1.9
local function buildCase(root: Model, frame: CFrame)
	local case = group(root, "SystemUnit")
	local function at(x: number, y: number, z: number): CFrame
		return frame * CFrame.new(x, y, z)
	end
	for _, x in { -1.1, 1.1 } do
		for _, z in { -0.8, 0.8 } do
			make("Part", case, "Foot", Vector3.new(0.16, 0.04, 0.16), at(x, 0.02, z), CHARCOAL, M.Rubber)
		end
	end
	local bodyD = CASE_D - 0.08
	make("Part", case, "Body", Vector3.new(CASE_W, CASE_H, bodyD), at(0, 0.04 + CASE_H / 2, -0.04), BEIGE)
	make("Part", case, "LidSeam", Vector3.new(CASE_W + 0.024, 0.025, bodyD + 0.012), at(0, 0.52, -0.046), BEIGE_DARK)
	make(
		"Part",
		case,
		"Bezel",
		Vector3.new(CASE_W + 0.02, CASE_H + 0.02, 0.08),
		at(0, 0.34, CASE_D / 2 - 0.04),
		rgb(198, 186, 155)
	)
	local fz = CASE_D / 2 -- bezel front

	-- 5.25" drive with its turn latch closed across the slot.
	make("Part", case, "FloppyDrive525", Vector3.new(1.02, 0.34, 0.03), at(-0.62, 0.38, fz + 0.015), FACEPLATE)
	make("Part", case, "DiskSlot", Vector3.new(0.82, 0.045, 0.01), at(-0.62, 0.4, fz + 0.035), SLOT)
	make("Part", case, "DriveLatch", Vector3.new(0.07, 0.26, 0.05), at(-0.62, 0.4, fz + 0.055), CHARCOAL)
	make("Part", case, "DriveLight", Vector3.new(0.06, 0.03, 0.02), at(-1.0, 0.27, fz + 0.04), rgb(110, 24, 22))
	-- 3.5" drive.
	make("Part", case, "FloppyDrive35", Vector3.new(0.6, 0.2, 0.03), at(0.2, 0.35, fz + 0.015), FACEPLATE)
	make("Part", case, "DiskSlot", Vector3.new(0.42, 0.03, 0.01), at(0.2, 0.38, fz + 0.035), SLOT)
	make("Part", case, "EjectButton", Vector3.new(0.1, 0.05, 0.03), at(0.38, 0.3, fz + 0.04), BEIGE_DARK)
	make("Part", case, "DriveLight", Vector3.new(0.04, 0.02, 0.02), at(0.0, 0.3, fz + 0.04), rgb(30, 86, 40))
	-- Control panel: clock-speed readout, turbo and reset, key lock, status lights.
	local readout = make("Part", case, "SpeedReadout", Vector3.new(0.26, 0.14, 0.02), at(0.9, 0.52, fz + 0.01), SLOT)
	label(readout, "33", rgb(255, 60, 40), Enum.Font.Code, true)
	make("Part", case, "TurboButton", Vector3.new(0.12, 0.07, 0.04), at(0.68, 0.36, fz + 0.02), BEIGE_DARK)
	make("Part", case, "ResetButton", Vector3.new(0.08, 0.05, 0.035), at(0.84, 0.36, fz + 0.018), BEIGE_DARK)
	make("Cylinder", case, "KeyLock", Vector3.new(0.03, 0.1, 0.1), at(1.06, 0.36, fz + 0.015) * FACING, CHROME, M.Metal)
	make("Part", case, "KeySlot", Vector3.new(0.015, 0.05, 0.01), at(1.06, 0.36, fz + 0.032), SLOT)
	for index, light in
		{
			{ rgb(90, 230, 110), M.Neon }, -- power
			{ rgb(110, 70, 22), M.SmoothPlastic }, -- disk, idle
			{ rgb(240, 196, 60), M.Neon }, -- turbo
		}
	do
		make(
			"Part",
			case,
			"StatusLight",
			Vector3.new(0.05, 0.025, 0.02),
			at(0.56 + index * 0.15, 0.22, fz + 0.01),
			light[1],
			light[2]
		)
	end
	for row = 0, 3 do
		make("Part", case, "FrontVent", Vector3.new(1.0, 0.018, 0.008), at(0.5, 0.08 + row * 0.028, fz + 0.004), SLOT)
	end
	local badge = make("Part", case, "Badge", Vector3.new(0.5, 0.09, 0.012), at(-0.85, 0.13, fz + 0.006), CHARCOAL)
	label(badge, "PC 386", BEIGE_LIGHT, Enum.Font.GothamBold)
	-- Big red mains switch on the right flank, slots down the left.
	make("Part", case, "SwitchHousing", Vector3.new(0.02, 0.22, 0.32), at(CASE_W / 2 + 0.01, 0.34, -0.6), BEIGE_DARK)
	make(
		"Part",
		case,
		"PowerSwitch",
		Vector3.new(0.04, 0.16, 0.12),
		at(CASE_W / 2 + 0.03, 0.34, -0.6) * CFrame.Angles(0, 0, 0.15),
		rgb(168, 40, 32)
	)
	for index = 0, 5 do
		make(
			"Part",
			case,
			"SideVent",
			Vector3.new(0.01, 0.3, 0.03),
			at(-CASE_W / 2 - 0.003, 0.32, -0.7 + index * 0.08),
			SLOT
		)
	end
	-- Back panel: expansion brackets, fan grille and sockets.
	local bz = -CASE_D / 2
	for index = 0, 6 do
		make(
			"Part",
			case,
			"SlotBracket",
			Vector3.new(0.07, 0.42, 0.015),
			at(-1.05 + index * 0.11, 0.32, bz - 0.008),
			CHROME,
			M.Metal
		)
	end
	make(
		"Cylinder",
		case,
		"FanGrille",
		Vector3.new(0.02, 0.36, 0.36),
		at(0.78, 0.36, bz - 0.01) * FACING,
		CHARCOAL,
		M.Metal
	)
	for _, bar in { Vector3.new(0.34, 0.02, 0.012), Vector3.new(0.02, 0.34, 0.012), Vector3.new(0.24, 0.02, 0.012) } do
		make(
			"Part",
			case,
			"GrilleBar",
			bar,
			at(0.78, if bar.X == 0.24 then 0.46 else 0.36, bz - 0.022),
			CHROME,
			M.Metal
		)
	end
	make("Part", case, "MainsSocket", Vector3.new(0.16, 0.1, 0.02), at(0.36, 0.18, bz - 0.01), SLOT)
	make("Part", case, "VideoPlug", Vector3.new(0.2, 0.07, 0.04), at(-0.2, 0.18, bz - 0.02), CHARCOAL)
end

-- 14" monochrome CRT, origin on the case lid under the front of the bezel.
local function buildMonitor(root: Model, frame: CFrame)
	local monitor = group(root, "Monitor")
	local function at(x: number, y: number, z: number): CFrame
		return frame * CFrame.new(x, y, z)
	end
	make("Cylinder", monitor, "SwivelBase", Vector3.new(0.06, 1.1, 1.1), at(0, 0.03, -0.5) * UPRIGHT, BEIGE_DARK)
	make("Part", monitor, "SwivelNeck", Vector3.new(0.5, 0.22, 0.5), at(0, 0.14, -0.5), BEIGE_DARK)

	local sy = 1.06 -- bezel centre height
	local openY, openW, openH = sy + 0.1, 1.56, 1.2
	-- Bezel frame around a real opening, so the glass sits recessed.
	make("Part", monitor, "BezelTop", Vector3.new(2.0, 0.16, 0.16), at(0, sy + 0.78, 0), BEIGE_LIGHT)
	make("Part", monitor, "BezelChin", Vector3.new(2.0, 0.36, 0.16), at(0, sy - 0.68, 0), BEIGE_LIGHT)
	for _, side in { -1, 1 } do
		make("Part", monitor, "BezelSide", Vector3.new(0.22, openH, 0.16), at(side * 0.89, openY, 0), BEIGE_LIGHT)
	end
	local surround = rgb(118, 112, 98)
	for _, side in { -1, 1 } do
		make(
			"Part",
			monitor,
			"ScreenSurround",
			Vector3.new(openW, 0.06, 0.12),
			at(0, openY + side * (openH / 2 - 0.03), -0.02),
			surround
		)
		make(
			"Part",
			monitor,
			"ScreenSurround",
			Vector3.new(0.06, openH - 0.12, 0.12),
			at(side * (openW / 2 - 0.03), openY, -0.02),
			surround
		)
	end
	local glass =
		make("Part", monitor, "ScreenGlass", Vector3.new(openW - 0.12, openH - 0.12, 0.04), at(0, openY, -0.06), SCREEN)
	glass.Reflectance = 0.06
	-- The tube face bulges out of the flat glass, like a real CRT.
	local bulge =
		make("Part", monitor, "ScreenCurve", Vector3.new(openW - 0.12, openH - 0.12, 0.12), at(0, openY, -0.06), SCREEN)
	bulge.Reflectance = 0.12
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = bulge
	label(
		bulge,
		"HARBOUR-DOS  Version 3.30\n(C) Copyright 1989\n\nC:\\>dir\n ACCOUNTS   <DIR>\n STAFF      <DIR>\n LEDGER     WK1\n TIDES      EXE\n\nC:\\>_",
		PHOSPHOR,
		Enum.Font.Code,
		true,
		Enum.TextXAlignment.Left
	)

	-- Chin: model plate, contrast and brightness knobs, power button and lamp.
	local plate =
		make("Part", monitor, "ModelPlate", Vector3.new(0.62, 0.09, 0.01), at(-0.55, sy - 0.68, 0.085), CHARCOAL)
	label(plate, "MONOCHROME 14", BEIGE_LIGHT, Enum.Font.GothamBold)
	for _, x in { 0.22, 0.38 } do
		make("Cylinder", monitor, "Knob", Vector3.new(0.06, 0.11, 0.11), at(x, sy - 0.68, 0.11) * FACING, CHARCOAL)
	end
	make("Part", monitor, "PowerButton", Vector3.new(0.16, 0.12, 0.04), at(0.74, sy - 0.68, 0.1), BEIGE_DARK)
	make(
		"Part",
		monitor,
		"PowerLight",
		Vector3.new(0.05, 0.03, 0.02),
		at(0.56, sy - 0.68, 0.09),
		rgb(90, 230, 110),
		M.Neon
	)
	-- Somebody's reminder, stuck over the corner of the screen.
	local note = make(
		"Part",
		monitor,
		"StickyNote",
		Vector3.new(0.27, 0.27, 0.01),
		at(0.8, sy + 0.66, 0.086) * CFrame.Angles(0, 0, -0.12),
		rgb(250, 228, 110)
	)
	label(note, "back up\nfriday!", rgb(40, 52, 120), Enum.Font.IndieFlower)

	-- Stepped tube housing tapering to the rear, with vent slots on top.
	local steps = {
		{ Vector3.new(1.9, 1.62, 0.45), 0, -0.305 },
		{ Vector3.new(1.6, 1.34, 0.36), -0.04, -0.71 },
		{ Vector3.new(1.28, 1.06, 0.3), -0.07, -1.04 },
	}
	for _, step in steps do
		local size, dy, z = step[1], step[2], step[3]
		make("Part", monitor, "Housing", size, at(0, sy + dy, z), BEIGE)
		local slots = math.floor(size.Z / 0.07)
		for index = 1, slots - 1 do
			make(
				"Part",
				monitor,
				"TopVent",
				Vector3.new(size.X * 0.62, 0.012, 0.03),
				at(0, sy + dy + size.Y / 2 + 0.003, z - size.Z / 2 + index * 0.07),
				SLOT
			)
		end
	end
	make("Part", monitor, "RearCap", Vector3.new(0.98, 0.78, 0.1), at(0, sy - 0.09, -1.24), BEIGE_DARK)
end

-- Heavy buckling-spring style keyboard, origin on the desk under its middle.
local U, KEY_GAP = 0.098, 0.016
local ROW_Z = { fn = -0.28, num = -0.14, q = -0.042, a = 0.056, z = 0.154, sp = 0.252 }
local function keys(count: number, token: string): { string }
	local result = {}
	for _ = 1, count do
		table.insert(result, token)
	end
	return result
end
local function join(...: { string }): { string }
	local result = {}
	for _, list in { ... } do
		for _, token in list do
			table.insert(result, token)
		end
	end
	return result
end
-- "1.5" a light key 1.5 wide, "d2" a dark key 2 wide, "_1" a gap one key wide.
local MAIN_ROWS = {
	fn = join({ "d1", "_1" }, keys(4, "1"), { "_0.5" }, keys(4, "1"), { "_0.5" }, keys(4, "1")),
	num = join(keys(13, "1"), { "d2" }),
	q = join({ "d1.5" }, keys(12, "1"), { "1.5" }),
	a = join({ "d1.75" }, keys(11, "1"), { "d2.25" }),
	z = join({ "d2.25" }, keys(10, "1"), { "d2.75" }),
	sp = { "d1.5", "_1", "d1.5", "7", "d1.5", "_1", "d1.5" },
}
local NAV_ROWS = {
	fn = keys(3, "d1"),
	num = keys(3, "d1"),
	q = keys(3, "d1"),
	z = { "_1", "d1" },
	sp = keys(3, "d1"),
}
local PAD_ROWS = {
	num = keys(4, "d1"),
	q = keys(3, "1"),
	a = keys(3, "1"),
	z = keys(3, "1"),
	sp = { "2", "1" },
}
local function buildKeyboard(root: Model, frame: CFrame)
	local keyboard = group(root, "Keyboard")
	local width, depth = 2.45, 0.85
	make("Part", keyboard, "Base", Vector3.new(width, 0.12, depth), frame * CFrame.new(0, 0.06, 0), BEIGE)
	-- Rises toward the monitor (-Z), like the register's key slope.
	make(
		"Wedge",
		keyboard,
		"Slope",
		Vector3.new(width, 0.1, depth),
		frame * CFrame.new(0, 0.17, 0) * CFrame.Angles(0, math.pi, 0),
		BEIGE
	)
	local slope = frame * CFrame.new(0, 0.17, 0) * CFrame.Angles(math.atan2(0.1, depth), 0, 0)
	local function cap(x: number, z: number, wide: number, deep: number, dark: boolean)
		make(
			"Part",
			keyboard,
			"Key",
			Vector3.new(wide * U - KEY_GAP, 0.07, deep * U - KEY_GAP),
			slope * CFrame.new(x, 0.035, z),
			if dark then KEY_DARK else KEY_LIGHT
		)
	end
	local function block(rows, left: number)
		for rowName, tokens in rows do
			local cursor = left
			for _, token in tokens do
				local gap = string.sub(token, 1, 1) == "_"
				local dark = string.sub(token, 1, 1) == "d"
				local wide = tonumber(if gap or dark then string.sub(token, 2) else token) :: number
				if not gap then
					cap(cursor + wide * U / 2, ROW_Z[rowName], wide, 1, dark)
				end
				cursor += wide * U
			end
		end
	end
	local mainLeft = -1.12
	local navLeft = mainLeft + 15.25 * U
	local padLeft = navLeft + 3.25 * U
	block(MAIN_ROWS, mainLeft)
	block(NAV_ROWS, navLeft)
	block(PAD_ROWS, padLeft)
	-- Tall numpad + and Enter.
	cap(padLeft + 3.5 * U, (ROW_Z.q + ROW_Z.a) / 2, 1, 2, false)
	cap(padLeft + 3.5 * U, (ROW_Z.z + ROW_Z.sp) / 2, 1, 2, true)
	-- Lock lights over the numpad (Num Lock on) and a maker's strip top left.
	make(
		"Part",
		keyboard,
		"LightPanel",
		Vector3.new(0.38, 0.006, 0.07),
		slope * CFrame.new(padLeft + 2 * U, 0.003, ROW_Z.fn),
		CHARCOAL
	)
	for index, x in { 0.8, 2, 3.2 } do
		make(
			"Part",
			keyboard,
			"LockLight",
			Vector3.new(0.035, 0.012, 0.025),
			slope * CFrame.new(padLeft + x * U, 0.006, ROW_Z.fn),
			if index == 1 then rgb(90, 230, 110) else rgb(26, 60, 32),
			if index == 1 then M.Neon else M.SmoothPlastic
		)
	end
	make("Part", keyboard, "Badge", Vector3.new(0.3, 0.008, 0.04), slope * CFrame.new(-0.9, 0.004, -0.375), CHARCOAL)
end

-- Boxy two-button ball mouse, origin on the pad under its middle, buttons at -Z.
local function buildMouse(root: Model, frame: CFrame)
	local mouse = group(root, "Mouse")
	make("Part", mouse, "Body", Vector3.new(0.32, 0.1, 0.52), frame * CFrame.new(0, 0.05, 0), BEIGE)
	make("Wedge", mouse, "Palm", Vector3.new(0.32, 0.05, 0.32), frame * CFrame.new(0, 0.125, 0.1), BEIGE)
	for _, side in { -1, 1 } do
		make(
			"Part",
			mouse,
			"Button",
			Vector3.new(0.145, 0.015, 0.19),
			frame * CFrame.new(side * 0.08, 0.1075, -0.155),
			BEIGE_DARK
		)
	end
end

local function buildComputer(root: Model, frame: CFrame)
	local computer = group(root, "Computer")
	local caseFrame = frame * CFrame.new(-0.6, DESK_H, -0.5)
	buildCase(computer, caseFrame)
	buildMonitor(computer, caseFrame * CFrame.new(0, 0.64, 0.8))
	local top = DESK_H + 0.02 -- blotter surface
	buildKeyboard(computer, frame * CFrame.new(-0.6, top, 0.98) * CFrame.Angles(0, 0.03, 0))
	make(
		"Part",
		computer,
		"MousePad",
		Vector3.new(0.9, 0.02, 0.78),
		frame * CFrame.new(1.9, DESK_H + 0.01, 0.95),
		rgb(38, 52, 88),
		M.Fabric
	)
	buildMouse(computer, frame * CFrame.new(1.85, top, 0.98) * CFrame.Angles(0, -0.12, 0))

	local cables = group(computer, "Cables")
	-- Monitor lead down the back of the tube to the video port.
	cable(
		cables,
		caseFrame,
		{
			{ -0.2, 1.35, -0.46 },
			{ -0.2, 1.2, -0.55 },
			{ -0.2, 0.67, -0.55 },
			{ -0.2, 0.67, -0.99 },
			{ -0.2, 0.2, -0.99 },
		},
		0.05,
		CABLE
	)
	-- Keyboard lead around the left of the case; mouse tail around the right.
	local y = DESK_H + 0.045
	cable(
		cables,
		frame,
		{ { -1.5, y, 0.56 }, { -1.75, y, 0.5 }, { -1.98, y, 0.25 }, { -2.0, y, -0.9 }, { -1.6, y, -1.48 } },
		0.05,
		rgb(150, 144, 128)
	)
	cable(
		cables,
		frame,
		{
			{ 1.88, y, 0.72 },
			{ 1.75, y, 0.35 },
			{ 1.35, y, -0.05 },
			{ 0.95, y, -0.55 },
			{ 0.75, y, -1.0 },
			{ 0.66, y, -1.2 },
		},
		0.04,
		rgb(150, 144, 128)
	)
	-- Mains lead dropping down the gap between the desk and the wall.
	cable(cables, caseFrame, { { 0.36, 0.18, -1.0 }, { 0.36, 0.1, -1.065 }, { 0.36, -2.88, -1.065 } }, 0.04, CABLE)
end

local function floppy(parent: Instance, frame: CFrame, color: Color3)
	make("Part", parent, "Floppy", Vector3.new(0.38, 0.38, 0.035), frame, color)
	make("Part", parent, "Shutter", Vector3.new(0.17, 0.13, 0.045), frame * CFrame.new(0.02, 0.125, 0), CHROME, M.Metal)
	make(
		"Part",
		parent,
		"DiskLabel",
		Vector3.new(0.3, 0.17, 0.042),
		frame * CFrame.new(0, -0.08, 0),
		rgb(236, 232, 218)
	)
end

local function buildClutter(root: Model, frame: CFrame)
	local clutter = group(root, "Clutter")
	-- Box of 3.5" diskettes.
	local box = frame * CFrame.new(-2.65, DESK_H, -0.75) * CFrame.Angles(0, 0.25, 0)
	local smoke = rgb(60, 62, 66)
	make("Part", clutter, "DiskBoxBase", Vector3.new(0.5, 0.04, 0.6), box * CFrame.new(0, 0.02, 0), smoke)
	for _, side in { -1, 1 } do
		make(
			"Part",
			clutter,
			"DiskBoxWall",
			Vector3.new(0.5, 0.22, 0.03),
			box * CFrame.new(0, 0.13, side * 0.285),
			smoke
		)
		make(
			"Part",
			clutter,
			"DiskBoxWall",
			Vector3.new(0.03, 0.22, 0.54),
			box * CFrame.new(side * 0.235, 0.13, 0),
			smoke
		)
	end
	local colors =
		{ rgb(30, 30, 34), rgb(38, 70, 140), rgb(150, 36, 36), rgb(30, 30, 34), rgb(120, 120, 124), rgb(36, 96, 60) }
	for index, color in colors do
		floppy(
			clutter,
			box * CFrame.new(0, 0.23, -0.22 + (index - 1) * 0.085) * CFrame.Angles(-0.18 + index * 0.025, 0, 0),
			color
		)
	end
	-- One left out on the desk.
	floppy(
		clutter,
		frame * CFrame.new(-2.62, DESK_H + 0.018, 0.75) * CFrame.Angles(0, 0.45, 0) * CFrame.Angles(-math.pi / 2, 0, 0),
		rgb(38, 70, 140)
	)

	-- Coffee mug.
	local mug = frame * CFrame.new(2.55, DESK_H, -0.85)
	local cream = rgb(232, 226, 210)
	make("Cylinder", clutter, "Mug", Vector3.new(0.3, 0.26, 0.26), mug * CFrame.new(0, 0.15, 0) * UPRIGHT, cream)
	make(
		"Cylinder",
		clutter,
		"Coffee",
		Vector3.new(0.01, 0.22, 0.22),
		mug * CFrame.new(0, 0.27, 0) * UPRIGHT,
		rgb(54, 32, 20)
	)
	make("Part", clutter, "MugHandle", Vector3.new(0.04, 0.18, 0.05), mug * CFrame.new(0.19, 0.15, 0), cream)
	for _, y in { 0.06, 0.24 } do
		make("Part", clutter, "MugHandle", Vector3.new(0.08, 0.04, 0.05), mug * CFrame.new(0.155, y, 0), cream)
	end
end

-- Worn tweed swivel chair, origin on the floor under the seat, facing -Z.
local function buildChair(root: Model, frame: CFrame)
	local chair = group(root, "Chair")
	local function at(x: number, y: number, z: number): CFrame
		return frame * CFrame.new(x, y, z)
	end
	make("Cylinder", chair, "Hub", Vector3.new(0.18, 0.34, 0.34), at(0, 0.3, 0) * UPRIGHT, BLACK_PLASTIC)
	for index = 0, 4 do
		local spoke = frame * CFrame.Angles(0, index * 2 * math.pi / 5 + 0.3, 0)
		make(
			"Part",
			chair,
			"BaseLeg",
			Vector3.new(0.14, 0.1, 0.95),
			spoke * CFrame.new(0, 0.27, 0.55) * CFrame.Angles(0.06, 0, 0),
			BLACK_PLASTIC
		)
		make("Part", chair, "CasterFork", Vector3.new(0.1, 0.12, 0.1), spoke * CFrame.new(0, 0.18, 1.0), BLACK_PLASTIC)
		make(
			"Cylinder",
			chair,
			"Caster",
			Vector3.new(0.1, 0.18, 0.18),
			spoke * CFrame.new(0, 0.09, 1.06),
			CHARCOAL,
			M.Rubber
		)
	end
	make("Cylinder", chair, "ColumnShroud", Vector3.new(0.55, 0.26, 0.26), at(0, 0.62, 0) * UPRIGHT, BLACK_PLASTIC)
	make("Cylinder", chair, "GasColumn", Vector3.new(0.48, 0.15, 0.15), at(0, 1.13, 0) * UPRIGHT, CHROME, M.Metal)
	make("Part", chair, "TiltMechanism", Vector3.new(0.7, 0.12, 0.7), at(0, 1.41, 0), BLACK_PLASTIC, M.Metal)
	make("Part", chair, "HeightLever", Vector3.new(0.5, 0.04, 0.04), at(0.55, 1.4, -0.15), BLACK_PLASTIC, M.Metal)
	make("Ball", chair, "LeverKnob", Vector3.new(0.1, 0.1, 0.1), at(0.82, 1.4, -0.15), BLACK_PLASTIC)

	make("Part", chair, "SeatShell", Vector3.new(1.55, 0.08, 1.5), at(0, 1.51, 0), BLACK_PLASTIC)
	make("Part", chair, "SeatCushion", Vector3.new(1.6, 0.28, 1.45), at(0, 1.69, 0), TWEED, M.Fabric, true)
	for _, side in { -1, 1 } do
		make("Cylinder", chair, "SeatRoll", Vector3.new(1.6, 0.28, 0.28), at(0, 1.69, side * 0.725), TWEED, M.Fabric)
	end
	-- Rubbed shiny where years of sitting wore the weave down.
	make("Part", chair, "WornPatch", Vector3.new(0.7, 0.02, 0.6), at(0, 1.832, 0.05), TWEED_WORN, M.Fabric)
	-- Hidden seat the server sits the owner in. CanTouch is off so nobody sits
	-- down just by walking into the chair.
	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Anchored = true
	seat.CanCollide = false
	seat.CanTouch = false
	seat.CanQuery = false
	seat.CastShadow = false
	seat.Transparency = 1
	seat.Size = Vector3.new(1.4, 0.2, 1.3)
	seat.CFrame = at(0, 1.73, 0)
	seat.Parent = chair

	make("Part", chair, "BackSpine", Vector3.new(0.3, 0.1, 0.75), at(0, 1.45, 0.65), BLACK_PLASTIC, M.Metal)
	make("Part", chair, "BackUpright", Vector3.new(0.3, 1.0, 0.1), at(0, 1.95, 1.0), BLACK_PLASTIC, M.Metal)
	local back = frame * CFrame.new(0, 2.95, 0.98) * CFrame.Angles(0.12, 0, 0)
	make("Part", chair, "BackShell", Vector3.new(1.5, 1.5, 0.12), back * CFrame.new(0, 0, 0.12), BLACK_PLASTIC)
	make(
		"Part",
		chair,
		"BackCushion",
		Vector3.new(1.46, 1.3, 0.24),
		back * CFrame.new(0, 0, -0.06),
		TWEED,
		M.Fabric,
		true
	)
	for _, side in { -1, 1 } do
		make(
			"Cylinder",
			chair,
			"BackRoll",
			Vector3.new(1.46, 0.24, 0.24),
			back * CFrame.new(0, side * 0.65, -0.06),
			TWEED,
			M.Fabric
		)
	end
	make(
		"Part",
		chair,
		"LumbarSeam",
		Vector3.new(1.47, 0.03, 0.25),
		back * CFrame.new(0, -0.25, -0.06),
		rgb(78, 58, 44),
		M.Fabric
	)

	for _, side in { -1, 1 } do
		make(
			"Part",
			chair,
			"ArmBracket",
			Vector3.new(0.55, 0.06, 0.18),
			at(side * 0.78, 1.46, 0.05),
			BLACK_PLASTIC,
			M.Metal
		)
		make("Part", chair, "ArmPost", Vector3.new(0.12, 0.9, 0.18), at(side * 1.0, 1.88, 0.05), BLACK_PLASTIC)
		make(
			"Part",
			chair,
			"ArmPad",
			Vector3.new(0.26, 0.1, 0.95),
			at(side * 1.0, 2.38, -0.05),
			rgb(46, 43, 41),
			M.Leather
		)
	end
end

function OfficeDesk.build(parent: Instance, frame: CFrame): Model
	local root = Instance.new("Model")
	root.Name = "OfficeDesk"
	root:SetAttribute("ModelVersion", VERSION)
	root:SetAttribute("DeskFrame", frame)
	root:SetAttribute("ChairAt", frame * CHAIR_FREE)
	buildDesk(root, frame)
	buildComputer(root, frame)
	buildClutter(root, frame)
	-- Pulled out from the desk and left a little askew.
	buildChair(root, frame * CHAIR_FREE)
	root.Parent = parent
	return root
end

-- Rolls the chair (and its seat) up to the monitor, or back out askew.
function OfficeDesk.moveChair(root: Instance, seated: boolean)
	local deskFrame = root:GetAttribute("DeskFrame")
	local current = root:GetAttribute("ChairAt")
	local chair = root:FindFirstChild("Chair")
	if typeof(deskFrame) ~= "CFrame" or typeof(current) ~= "CFrame" or not chair then
		return
	end
	local target = deskFrame * (if seated then CHAIR_SEATED else CHAIR_FREE)
	local delta = target * current:Inverse()
	for _, part in chair:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = delta * part.CFrame
		end
	end
	root:SetAttribute("ChairAt", target)
end

-- Dresses the desk in its company's PC (TechStoreService builds `look` from Shared.TechCatalog):
-- the system unit and monitor are rebuilt by Shared.PcModel (passed in, so this module keeps no
-- dependencies) from the parts list. A desktop case sits under its monitor; a tower or showcase
-- stands to the right of a monitor on its own stand. While the PC is away (carried, or on the
-- workbench: PcWorkshopService) only the monitor stays, showing NO SIGNAL, and the desk is
-- marked PcAway so nobody can sit down at it.
export type Look = {
	Key: string,
	Parts: { [string]: string },
	Form: string,
	Away: boolean?,
}

-- Where the system unit stands on the desk, desk-local.
function OfficeDesk.caseFrame(deskFrame: CFrame, form: string): CFrame
	if form == "Desktop" then
		return deskFrame * CFrame.new(-0.6, DESK_H, -0.5)
	end
	return deskFrame * CFrame.new(if form == "Showcase" then 1.62 else 1.45, DESK_H, -0.5)
end

function OfficeDesk.dress(root: Instance, look: Look, PcModel: any)
	local key = look.Key .. (if look.Away then "|away" else "")
	if root:GetAttribute("TechLook") == key then
		return
	end
	local computer = root:FindFirstChild("Computer")
	local frame = root:GetAttribute("DeskFrame")
	if not computer or typeof(frame) ~= "CFrame" then
		return
	end
	root:SetAttribute("TechLook", key)
	root:SetAttribute("PcAway", look.Away == true)
	for _, name in { "SystemUnit", "Monitor", "Cables", "Rig" } do
		local old = computer:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local rig = group(computer, "Rig")
	local desktop = look.Form == "Desktop"
	local caseFrame = OfficeDesk.caseFrame(frame, look.Form)
	local monitorFrame
	if desktop and not look.Away then
		monitorFrame = caseFrame * CFrame.new(0, PcModel.size(look.Parts.Case).Y, 0.8)
	elseif desktop then
		monitorFrame = caseFrame * CFrame.new(0, 0, 0.8)
	else
		monitorFrame = frame * CFrame.new(-0.75, DESK_H, 0.2)
	end
	if not look.Away then
		PcModel.build(rig, caseFrame, look.Parts, { Name = "SystemUnit" })
	end
	PcModel.buildMonitor(rig, monitorFrame, look.Parts.Monitor, { Name = "Monitor", Away = look.Away })

	-- Keyboard and mouse leads to the back of the desk; monitor and mains leads to the PC.
	local cables = group(rig, "Cables")
	local y = DESK_H + 0.045
	local lead = rgb(150, 144, 128)
	cable(cables, frame, { { -1.5, y, 0.56 }, { -1.75, y, 0.5 }, { -1.98, y, 0.25 }, { -2.0, y, -0.9 }, { -1.6, y, -1.48 } }, 0.05, lead)
	cable(cables, frame, { { 1.88, y, 0.72 }, { 1.75, y, 0.35 }, { 1.35, y, -0.05 }, { 0.95, y, -0.55 }, { 0.75, y, -1.0 }, { 0.66, y, -1.2 } }, 0.04, lead)
	if look.Away then
		return
	end
	if desktop then
		cable(cables, caseFrame, { { -0.2, 1.35, -0.46 }, { -0.2, 1.2, -0.55 }, { -0.2, 0.69, -0.55 }, { -0.2, 0.69, -0.99 }, { -0.2, 0.2, -0.99 } }, 0.05, CABLE)
		cable(cables, caseFrame, { { 0.5, 0.18, -1.0 }, { 0.5, 0.1, -1.065 }, { 0.5, -2.88, -1.065 } }, 0.04, CABLE)
	else
		local monitorBack = frame:PointToObjectSpace((monitorFrame * CFrame.new(0, 0.5, -0.6)).Position)
		local caseBack = frame:PointToObjectSpace((caseFrame * CFrame.new(0, 1.6, -1.0)).Position)
		cable(cables, frame, {
			{ monitorBack.X, monitorBack.Y, monitorBack.Z },
			{ monitorBack.X, y, -1.3 },
			{ caseBack.X, y, -1.3 },
			{ caseBack.X, caseBack.Y, caseBack.Z },
		}, 0.05, CABLE)
		cable(cables, caseFrame, { { 0, 0.32, -1.0 }, { 0, 0.2, -1.04 }, { 0, -2.88, -1.04 } }, 0.04, CABLE)
	end
end

OfficeDesk.WIDTH = DESK_W
OfficeDesk.DEPTH = DESK_D
OfficeDesk.HEIGHT = DESK_H
-- Against the middle of the office's back wall (house-local z = 2.25, 0.55
-- thick), on the office floor boards (top at 0.18).
function OfficeDesk.frame(houseFrame: CFrame): CFrame
	return houseFrame * CFrame.new(-15.75, 0.18, 2.525 + 0.05 + DESK_D / 2)
end

function OfficeDesk.ensure(house: Model, houseFrame: CFrame)
	local office = house:FindFirstChild("Office")
	if not office then
		return
	end
	local existing = office:FindFirstChild("OfficeDesk")
	if existing and existing:GetAttribute("ModelVersion") == VERSION then
		return
	end
	if existing then
		existing:Destroy()
	end
	OfficeDesk.build(office, OfficeDesk.frame(houseFrame))
end

return OfficeDesk
