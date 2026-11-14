-- Builds a PC from its parts (Shared.TechCatalog): the system unit with everything inside it,
-- and the monitor. The same geometry is the office PC on the desk (Map/OfficeDesk.dress), the PC
-- a player carries and the one opened up on the workbench (PcWorkshopService), and the product
-- displays at Micro Harbour (Shared.TechStoreInterior, via `component` and a part factory).
--
-- Case-local frame: origin on the surface under the middle of the case, +Z is the front. A
-- "Desktop" case lies flat and its lid (the access panel) lifts off the top; a "Tower" or
-- "Showcase" stands up with the motherboard on its -X wall and a screwed side panel on +X.
-- The access panel is the child model "AccessPanel" (with four "CaseScrew" models); its pivot's
-- +Y is the panel's outward normal. Each component is a child model named by its slot, so the
-- workbench can highlight it.
local Catalog = require(script.Parent.TechCatalog)

local PcModel = {}

local rgb = Color3.fromRGB
local M = Enum.Material

local DARK = rgb(24, 24, 28)
local BLACK = rgb(0, 0, 0)
local WHITE = rgb(255, 255, 255)
local HOLE = rgb(12, 12, 14)
local STEEL = rgb(150, 156, 164)
local CHROME = rgb(176, 178, 182)
local GOLD = rgb(214, 172, 74)
local COPPER = rgb(190, 110, 70)
local PCB_GREEN = rgb(30, 92, 56)
local CHIP = rgb(28, 28, 32)
local GLASS = rgb(160, 195, 218)
local RUBBER = rgb(34, 34, 36)
local SLOT_BLACK = rgb(18, 17, 16)
local ICE = rgb(214, 236, 248)
local RGB_CYCLE = { rgb(255, 80, 155), rgb(80, 170, 255), rgb(120, 255, 160), rgb(255, 200, 60) }

local FORMS = {
	Desktop = { W = 2.5, H = 0.66, D = 1.9 },
	Tower = { W = 0.95, H = 2.2, D = 2.0 },
	Showcase = { W = 1.35, H = 1.95, D = 2.0 },
}

local UP = CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis along Y
local ALONG_Z = CFrame.Angles(0, math.pi / 2, 0) -- cylinder axis along Z

export type Make = (Instance, string, Vector3, CFrame, Color3, Enum.Material?, Enum.PartType?) -> BasePart

local function defaultMake(
	folder: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = math.max(size.X, size.Y, size.Z) >= 0.6
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = material or M.SmoothPlastic
	part.Color = color
	part.Size = size
	part.CFrame = cframe
	if shape then
		part.Shape = shape
	end
	part.Parent = folder
	return part
end

-- Places parts in model-local coordinates (studs at scale 1) around a world origin.
type Kit = {
	at: (CFrame) -> CFrame,
	part: (Instance, string, Vector3, CFrame, Color3, Enum.Material?, Enum.PartType?) -> BasePart,
	scale: number,
}
local function kit(origin: CFrame, scale: number?, make: Make?): Kit
	local s = scale or 1
	local create = make or defaultMake
	local result = {} :: any
	result.scale = s
	function result.at(cframe: CFrame): CFrame
		return origin * CFrame.new(cframe.Position * s) * cframe.Rotation
	end
	function result.part(folder, name, size, cframe, color, material, shape)
		return create(folder, name, size * s, result.at(cframe), color, material, shape)
	end
	return result
end

local function group(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

local function box(K: Kit, folder: Instance, name: string, frame: CFrame, x: number, y: number, z: number, sx: number, sy: number, sz: number, color: Color3, material: Enum.Material?): BasePart
	return K.part(folder, name, Vector3.new(math.max(sx, 0.005), math.max(sy, 0.005), math.max(sz, 0.005)), frame * CFrame.new(x, y, z), color, material)
end

-- A cylinder `length` long along the frame's axis ("X", "Y" or "Z").
local function cylinder(K: Kit, folder: Instance, name: string, frame: CFrame, x: number, y: number, z: number, length: number, diameter: number, axis: string, color: Color3, material: Enum.Material?): BasePart
	local turn = if axis == "Y" then UP elseif axis == "Z" then ALONG_Z else CFrame.identity
	return K.part(folder, name, Vector3.new(math.max(length, 0.005), diameter, diameter), frame * CFrame.new(x, y, z) * turn, color, material, Enum.PartType.Cylinder)
end

-- A frame at `position` whose +Y points along `direction`.
local function facing(position: Vector3, direction: Vector3, reference: Vector3?): CFrame
	local y = direction.Unit
	local ref = reference or Vector3.new(0, 1, 0)
	if math.abs(y:Dot(ref.Unit)) > 0.98 then
		ref = if math.abs(y.X) < 0.9 then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
	end
	local x = y:Cross(ref).Unit
	local z = x:Cross(y)
	return CFrame.fromMatrix(position, x, y, z)
end

-- A cable laid through model-local points, one straight run per segment.
local function cable(K: Kit, folder: Instance, points: { Vector3 }, thickness: number, color: Color3, material: Enum.Material?)
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local delta = b - a
		local length = delta.Magnitude
		if length > 0.01 then
			local up = if math.abs(delta.Unit.Y) > 0.98 then Vector3.new(0, 0, 1) else Vector3.new(0, 1, 0)
			K.part(folder, "Cable", Vector3.new(thickness, thickness, length + thickness), CFrame.lookAt((a + b) / 2, b, up), color, material or M.SmoothPlastic)
		end
	end
end

local FACES = {
	Top = Enum.NormalId.Top,
	Front = Enum.NormalId.Back, -- the part's +Z face
	Right = Enum.NormalId.Right,
	Left = Enum.NormalId.Left,
}

-- Text printed on one face of a part.
local function label(part: BasePart, text: string, color: Color3, face: string?, font: Enum.Font?, glow: boolean?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label"
	gui.Face = FACES[face or "Front"]
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 120
	gui.LightInfluence = if glow then 0 else 1
	gui.MaxDistance = 80
	local line = Instance.new("TextLabel")
	line.BackgroundTransparency = 1
	line.Size = UDim2.fromScale(1, 1)
	line.Font = font or Enum.Font.GothamBold
	line.Text = text
	line.TextColor3 = color
	line.TextScaled = true
	line.TextWrapped = false
	if glow then
		line.TextStrokeColor3 = color
		line.TextStrokeTransparency = 0.85
	end
	line.Parent = gui
	gui.Parent = part
end

local function glass(part: BasePart, transparency: number?)
	part.Material = M.Glass
	part.Transparency = transparency or 0.6
	part.CastShadow = false
	part:SetAttribute("PreserveGlassMaterial", true)
end

-- A square fan, its +Y face toward the viewer (`frame`'s Y is the airflow).
local function fan(K: Kit, folder: Instance, frame: CFrame, size: number, thick: number, light: Color3?, housing: Color3?)
	box(K, folder, "FanHousing", frame, 0, 0, 0, size, thick, size, housing or DARK, M.SmoothPlastic)
	cylinder(K, folder, "FanRing", frame, 0, 0, 0, thick + 0.006, size * 0.94, "Y", light or HOLE, if light then M.Neon else M.SmoothPlastic)
	if light then
		cylinder(K, folder, "FanThroat", frame, 0, 0, 0, thick + 0.01, size * 0.84, "Y", HOLE)
	end
	for index = 0, 4 do
		K.part(
			folder,
			"FanBlade",
			Vector3.new(size * 0.34, 0.01, size * 0.13),
			frame * CFrame.Angles(0, index * math.pi * 2 / 5, 0) * CFrame.new(size * 0.22, thick / 2 + 0.008, 0) * CFrame.Angles(0.4, 0, 0),
			if light then rgb(220, 224, 232) else rgb(44, 44, 50)
		)
	end
	cylinder(K, folder, "FanHub", frame, 0, thick / 2 + 0.012, 0, 0.022, size * 0.28, "Y", light or rgb(36, 36, 42), if light then M.Neon else M.SmoothPlastic)
end

----------------------------------------------------------------------------------------------------
-- Case geometry

export type CaseInfo = { Form: string, W: number, H: number, D: number, Look: any, Id: string }

function PcModel.caseInfo(caseId: any): CaseInfo
	local item = Catalog.installed("Case", caseId)
	local dims = FORMS[item.Look.Form]
	return { Form = item.Look.Form, W = dims.W, H = dims.H, D = dims.D, Look = item.Look, Id = item.Id }
end

-- Where everything sits inside each kind of case (model-local frames).
type Layout = {
	Board: CFrame, -- X along the board's width (toward the front), Y out of the board, Z toward its top
	BW: number,
	BH: number,
	Depth: number, -- free space in front of the board
	Psu: CFrame, -- +Y the label side, +Z the plug side
	PsuSize: Vector3,
	Drive: CFrame, -- floor of the drive cage, front +Z
	Ssd: CFrame,
	Radiator: CFrame, -- X along its length, Y toward the fans
	RadLength: number,
	RadWidth: number,
	Reservoir: CFrame, -- Y along its axis
	Exit: Vector3, -- where hoses leave through the back
	Fans: { { CFrame | number } },
}

local function layoutOf(info: CaseInfo): Layout
	local W, H, D = info.W, info.H, info.D
	if info.Form == "Desktop" then
		return {
			Board = CFrame.fromMatrix(Vector3.new(-0.36, 0.08, -0.32), Vector3.new(-1, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, -1)),
			BW = 1.52,
			BH = 1.08,
			Depth = H - 0.15,
			Psu = CFrame.fromMatrix(Vector3.new(0.87, 0.08 + 0.22, -0.52), Vector3.new(-1, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, -1)),
			PsuSize = Vector3.new(0.6, 0.44, 0.74),
			Drive = CFrame.new(-0.66, 0.08, 0.52),
			Ssd = CFrame.new(0.66, 0.08, 0.22),
			Radiator = CFrame.fromMatrix(Vector3.new(0.4, 0.37, 0.8), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, 1, 0)),
			RadLength = 0.92,
			RadWidth = 0.4,
			Reservoir = CFrame.new(0.45, 0.33, 0.5) * CFrame.Angles(0, 0, -math.pi / 2),
			Exit = Vector3.new(0.2, 0.36, -D / 2),
			Fans = {},
		}
	end
	local showcase = info.Form == "Showcase"
	local boardY = if showcase then 1.18 else 1.27
	local fans = {}
	if info.Look.Mesh or info.Look.GlassFront or info.Look.Window == "Full" then
		for _, y in (if showcase then { 1.45, 0.95 } else { 1.6, 1.0 }) do
			table.insert(fans, { facing(Vector3.new(0, y, D / 2 - 0.13), Vector3.new(0, 0, -1)), if showcase then 0.62 else 0.6 })
		end
	end
	table.insert(fans, { facing(Vector3.new(0.06, if showcase then 1.6 else 1.72, -D / 2 + 0.09), Vector3.new(0, 0, -1)), 0.5 })
	return {
		Board = CFrame.fromMatrix(Vector3.new(-W / 2 + 0.06, boardY, -0.18), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), Vector3.new(0, 1, 0)),
		BW = 1.5,
		BH = if showcase then 1.32 else 1.45,
		Depth = math.min(W - 0.16, 0.95),
		Psu = CFrame.fromMatrix(Vector3.new(if showcase then -W / 2 + 0.5 else 0, 0.11 + 0.21, -0.5), Vector3.new(0, 1, 0), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1)),
		PsuSize = Vector3.new(0.42, if showcase then 0.8 else W - 0.16, 0.86),
		Drive = CFrame.new(if showcase then 0.25 else 0, 0.11, 0.45),
		Ssd = CFrame.new(if showcase then 0.35 else 0.06, 0.54, -0.5),
		Radiator = CFrame.fromMatrix(Vector3.new(0.04, H - 0.11, -0.12), Vector3.new(0, 0, 1), Vector3.new(0, -1, 0), Vector3.new(1, 0, 0)),
		RadLength = 1.1,
		RadWidth = if showcase then 0.62 else 0.5,
		Reservoir = CFrame.new(if showcase then 0.3 else 0.14, 1.12, 0.66),
		Exit = Vector3.new(0.1, 1.45, -D / 2),
		Fans = fans,
	}
end

-- The access panel's pivot in case-local coordinates (+Y its outward normal).
function PcModel.panelPivot(caseId: any): CFrame
	local info = PcModel.caseInfo(caseId)
	if info.Form == "Desktop" then
		return CFrame.new(0, info.H, -0.03)
	end
	return CFrame.new(info.W / 2, info.H / 2, 0) * CFrame.Angles(0, 0, -math.pi / 2)
end

-- The case frame that puts its access side up on `surface` (a tower lies on its tray side),
-- centred over the surface point with its front toward the surface's +Z.
function PcModel.restFrame(caseId: any, surface: CFrame): CFrame
	local info = PcModel.caseInfo(caseId)
	if info.Form == "Desktop" then
		return surface
	end
	return surface * CFrame.new(0, info.W / 2 + 0.02, 0) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.new(0, -info.H / 2, 0)
end

-- A removed access panel leaning back against something, its lower edge on `base`'s point.
function PcModel.asideFrame(caseId: any, base: CFrame): CFrame
	local info = PcModel.caseInfo(caseId)
	local lean = 0.22
	local span = info.D - 0.08
	local lift = span / 2 * math.cos(lean) + (if info.Form == "Desktop" then info.H * math.sin(lean) else 0.03) + 0.01
	return base * CFrame.fromMatrix(
		Vector3.new(0, lift, 0),
		Vector3.new(1, 0, 0),
		Vector3.new(0, math.sin(lean), math.cos(lean)),
		Vector3.new(0, -math.cos(lean), math.sin(lean))
	)
end

----------------------------------------------------------------------------------------------------
-- Components (board coordinates: a across the board toward its front edge, b toward its top,
-- both -0.5..0.5; n out of the board in studs)

type Ctx = { K: Kit, L: Layout, u: number, k: number }

local function onBoard(ctx: Ctx, a: number, b: number, n: number): CFrame
	return ctx.L.Board * CFrame.new(a * ctx.L.BW, n, b * ctx.L.BH)
end

local function buildMotherboard(ctx: Ctx, folder: Instance, item)
	local K, L, u, k = ctx.K, ctx.L, ctx.u, ctx.k
	local tier = item.Tier
	local board = L.Board
	box(K, folder, "BoardPCB", board, 0, 0.015, 0, L.BW, 0.03, L.BH, item.Pcb)
	-- Brass standoff screws in the corners.
	for _, a in { -0.45, 0.45 } do
		for _, b in { -0.45, 0.45 } do
			cylinder(K, folder, "Standoff", onBoard(ctx, a, b, 0.035), 0, 0, 0, 0.012, 0.05 * u, "Y", GOLD, M.Metal)
		end
	end
	-- Rear I/O: a plastic shroud on modern boards, bare connectors on old ones.
	if tier >= 3 then
		local shroud = box(K, folder, "IoShroud", onBoard(ctx, -0.44, 0.27, 0.03 + 0.08 * k), 0, 0, 0, 0.14 * u, 0.16 * k, 0.46 * u, if item.Armour then item.Heatsink:Lerp(DARK, 0.4) else DARK, M.Metal)
		if item.Rgb then
			box(K, folder, "IoGlow", onBoard(ctx, -0.37, 0.27, 0.03 + 0.08 * k), 0, 0, 0, 0.012, 0.12 * k, 0.4 * u, item.Rgb, M.Neon)
		end
		label(shroud, string.upper(string.match(item.Name, "^(%S+)") or ""), item.Heatsink, "Right")
	else
		cylinder(K, folder, "KeyboardDin", onBoard(ctx, -0.46, 0.38, 0.07), 0, 0, 0, 0.1 * u, 0.1 * u, "X", SLOT_BLACK)
		box(K, folder, "IoHeader", onBoard(ctx, -0.45, 0.18, 0.05), 0, 0, 0, 0.08 * u, 0.06, 0.24 * u, SLOT_BLACK)
	end
	-- Power-stage heatsinks around the socket.
	if tier >= 2 then
		local finColor = item.Heatsink
		box(K, folder, "VrmHeatsink", onBoard(ctx, -0.14, 0.44, 0.03 + 0.05 * k), 0, 0, 0, 0.5 * u, 0.1 * k, 0.08 * u, finColor, M.Metal)
		box(K, folder, "VrmHeatsink", onBoard(ctx, -0.36, 0.2, 0.03 + 0.05 * k), 0, 0, 0, 0.08 * u, 0.1 * k, 0.38 * u, finColor, M.Metal)
	end
	-- Socket frame, then capacitors around it.
	box(K, folder, "Socket", onBoard(ctx, -0.12, 0.25, 0.04), 0, 0, 0, 0.32 * u, 0.02, 0.32 * u, if tier >= 3 then CHROME else rgb(220, 214, 190), M.Metal)
	for index = 0, (if tier <= 2 then 5 else 3) do
		local a = -0.3 + index * 0.06
		cylinder(K, folder, "Capacitor", onBoard(ctx, a, 0.07, 0.03 + 0.04 * k), 0, 0, 0, 0.08 * k, 0.05 * u, "Y", if tier <= 2 then rgb(40, 60, 120) else rgb(60, 60, 66), M.Metal)
	end
	-- Memory slots to the front of the socket.
	local ramSlots = if tier >= 3 then 4 else 2
	for index = 1, ramSlots do
		local a = 0.16 + (index - 1) * 0.07 * u / L.BW * 1.5
		box(K, folder, "RamSlot", onBoard(ctx, a, 0.22, 0.045), 0, 0, 0, 0.028 * u, 0.03, 0.55 * u, if index % 2 == 0 then rgb(60, 60, 66) else SLOT_BLACK)
	end
	-- Expansion slots below it: long black ISA slots on the old board.
	for index, b in (if tier == 1 then { -0.05, -0.17, -0.29, -0.41 } else { -0.05, -0.2, -0.35 }) do
		local reinforced = tier >= 4 and index == 1
		box(K, folder, "ExpansionSlot", onBoard(ctx, -0.1, b, 0.045), 0, 0, 0, (if tier == 1 then 0.78 else 0.6) * L.BW, 0.035, 0.035 * u, if reinforced then item.Heatsink elseif tier == 1 then SLOT_BLACK else rgb(220, 220, 224), if reinforced then M.Metal else nil)
	end
	-- Chipset heatsink, 24-pin power socket and the clock battery.
	box(K, folder, "ChipsetHeatsink", onBoard(ctx, 0.2, -0.26, 0.03 + 0.03 * k), 0, 0, 0, 0.22 * u, 0.06 * k, 0.22 * u, item.Heatsink, M.Metal)
	if item.Rgb then
		box(K, folder, "ChipsetGlow", onBoard(ctx, 0.2, -0.26, 0.03 + 0.065 * k), 0, 0, 0, 0.2 * u, 0.008, 0.02 * u, item.Rgb, M.Neon)
	end
	box(K, folder, "PowerSocket", onBoard(ctx, 0.47, 0.1, 0.03 + 0.045 * k), 0, 0, 0, 0.07 * u, 0.09 * k, 0.22 * u, if tier >= 3 then DARK else rgb(232, 228, 214))
	cylinder(K, folder, "ClockBattery", onBoard(ctx, 0.3, -0.42, 0.04), 0, 0, 0, 0.02, 0.1 * u, "Y", CHROME, M.Metal)
	-- Armoured boards hide the lower half under a plate with a light line.
	if item.Armour then
		local plate = box(K, folder, "BoardArmour", onBoard(ctx, 0.12, -0.27, 0.03 + 0.09 * k), 0, 0, 0, 0.6 * L.BW, 0.025, 0.34 * L.BH, item.Heatsink:Lerp(DARK, 0.55), M.Metal)
		label(plate, "KRAKEN", item.Heatsink, "Top", Enum.Font.GothamBlack)
	end
	if item.Rgb then
		box(K, folder, "BoardGlow", onBoard(ctx, 0.49, -0.1, 0.04), 0, 0, 0, 0.015, 0.02, 0.6 * L.BH, item.Rgb, M.Neon)
	end
end

local function buildCpu(ctx: Ctx, folder: Instance, item)
	local K, u = ctx.K, ctx.u
	local chip = box(K, folder, "Processor", onBoard(ctx, -0.12, 0.25, 0.062), 0, 0, 0, 0.22 * u, 0.025, 0.22 * u, if item.Tier <= 2 then rgb(90, 90, 96) else item.Lid, M.Metal)
	label(chip, item.Badge, rgb(30, 30, 34), "Top", Enum.Font.GothamBold)
end

-- The CPU cooler. `base` sits on top of the chip (+Y away from the board, X across the board).
local function buildCooler(ctx: Ctx, folder: Instance, item, base: CFrame)
	local K, L, u, k = ctx.K, ctx.L, ctx.u, ctx.k
	local form = item.Form
	local light = item.Light
	local tall = math.min(0.55 * k, L.Depth - 0.12)
	if form == "Stock" then
		box(K, folder, "HeatsinkBase", base, 0, 0.03, 0, 0.3 * u, 0.06, 0.3 * u, STEEL, M.Metal)
		for index = -2, 2 do
			box(K, folder, "HeatsinkFin", base, index * 0.06 * u, 0.09, 0, 0.012, 0.08, 0.3 * u, STEEL, M.Metal)
		end
		fan(K, folder, base * CFrame.new(0, 0.16, 0), 0.28 * u, 0.05, nil)
	elseif form == "Tower" or form == "Twin" then
		box(K, folder, "CoolerBase", base, 0, 0.025, 0, 0.2 * u, 0.05, 0.2 * u, COPPER, M.Metal)
		local stacks = if form == "Twin" then { -0.13 * u, 0.13 * u } else { 0 }
		for _, x in stacks do
			for _, z in { -0.05, 0.05 } do
				cylinder(K, folder, "HeatPipe", base, x, 0.05 + tall / 2, z * u, tall, 0.025, "Y", COPPER, M.Metal)
			end
			local fins = 9
			for index = 0, fins - 1 do
				box(K, folder, "CoolerFin", base, x, 0.14 + index * (tall - 0.14) / (fins - 1), 0, 0.15 * u, 0.012, 0.44 * u, rgb(196, 200, 206), M.Metal)
			end
			box(K, folder, "CoolerCap", base, x, tall + 0.02, 0, 0.16 * u, 0.03, 0.45 * u, DARK, M.Metal)
			box(K, folder, "CoolerCapGlow", base, x, tall + 0.036, 0, 0.12 * u, 0.006, 0.02, light, M.Neon)
		end
		local fanY = 0.14 + (tall - 0.14) / 2
		local fanSize = math.min(0.44 * u, tall - 0.06)
		fan(K, folder, base * facing(Vector3.new((stacks[#stacks] + 0.11 * u), fanY, 0), Vector3.new(1, 0, 0)), fanSize, 0.06, nil, rgb(40, 44, 52))
		if form == "Twin" then
			fan(K, folder, base * facing(Vector3.new(0, fanY, 0), Vector3.new(1, 0, 0)), fanSize, 0.06, nil, rgb(40, 44, 52))
		end
	elseif form == "Aio" or form == "Loop" then
		local radiator = L.Radiator
		local length, width = L.RadLength, L.RadWidth
		box(K, folder, "Radiator", radiator, 0, 0, 0, length, 0.07, width, rgb(30, 30, 34), M.Metal)
		for _, side in { -1, 1 } do
			box(K, folder, "RadiatorTank", radiator, side * (length / 2 - 0.035), 0, 0, 0.07, 0.09, width + 0.02, rgb(42, 42, 48), M.Metal)
		end
		local count = if length >= 1 then 2 else 2
		local fanSize = math.min(width - 0.04, length / count - 0.04)
		for index = 1, count do
			local x = -length / 2 + (index - 0.5) * length / count
			fan(K, folder, radiator * CFrame.new(x, 0.07, 0), fanSize, 0.05, light)
		end
		local inlet = (radiator * CFrame.new(-length / 2 + 0.05, 0.04, 0.08)).Position
		local outlet = (radiator * CFrame.new(-length / 2 + 0.05, 0.04, -0.08)).Position
		if form == "Aio" then
			local pump = base * CFrame.new(0, 0.06, 0)
			cylinder(K, folder, "PumpBlock", pump, 0, 0, 0, 0.11, 0.25 * u, "Y", DARK, M.Metal)
			cylinder(K, folder, "PumpRing", pump, 0, 0.035, 0, 0.05, 0.26 * u, "Y", light, M.Neon)
			local cap = cylinder(K, folder, "PumpCap", pump, 0, 0.065, 0, 0.012, 0.2 * u, "Y", rgb(16, 16, 18), M.Glass)
			cap.Transparency = 0
			local from1 = (pump * CFrame.new(0.12 * u, 0.02, 0.05 * u)).Position
			local from2 = (pump * CFrame.new(0.12 * u, 0.02, -0.05 * u)).Position
			local bow = (pump * CFrame.new(0.35, 0.22, 0)).Position
			cable(K, folder, { from1, bow + Vector3.new(0, 0, 0.04), inlet }, 0.045, RUBBER)
			cable(K, folder, { from2, bow - Vector3.new(0, 0, 0.04), outlet }, 0.045, RUBBER)
		else
			local block = base * CFrame.new(0, 0.05, 0)
			local shell = box(K, folder, "WaterBlock", block, 0, 0, 0, 0.27 * u, 0.09, 0.27 * u, rgb(220, 230, 240))
			glass(shell, 0.45)
			box(K, folder, "WaterBlockCoolant", block, 0, 0, 0, 0.2 * u, 0.05, 0.2 * u, light, M.Neon)
			box(K, folder, "WaterBlockTop", block, 0, 0.05, 0, 0.2 * u, 0.012, 0.06 * u, CHROME, M.Metal)
			local reservoir = L.Reservoir
			local tube = cylinder(K, folder, "Reservoir", reservoir, 0, 0, 0, 0.62, 0.2, "Y", rgb(220, 230, 240))
			glass(tube, 0.4)
			cylinder(K, folder, "ReservoirCoolant", reservoir, 0, -0.04, 0, 0.5, 0.15, "Y", light, M.Neon)
			for _, y in { -0.33, 0.33 } do
				cylinder(K, folder, "ReservoirCap", reservoir, 0, y, 0, 0.05, 0.22, "Y", DARK, M.Metal)
			end
			local resTop = (reservoir * CFrame.new(0, 0.34, 0)).Position
			local resBottom = (reservoir * CFrame.new(0, -0.34, 0)).Position
			local blockA = (block * CFrame.new(0.14 * u, 0.02, 0.06 * u)).Position
			local blockB = (block * CFrame.new(0.14 * u, 0.02, -0.06 * u)).Position
			local corner = Vector3.new(resBottom.X, blockA.Y, resBottom.Z)
			cable(K, folder, { blockA, Vector3.new(blockA.X, blockA.Y, corner.Z):Lerp(corner, 0.5), corner, resBottom }, 0.04, light, M.Neon)
			cable(K, folder, { resTop, Vector3.new(resTop.X, inlet.Y, resTop.Z), inlet }, 0.04, light, M.Neon)
			cable(K, folder, { outlet, Vector3.new(outlet.X, blockB.Y + 0.15, outlet.Z), Vector3.new(blockB.X, blockB.Y + 0.15, blockB.Z), blockB }, 0.04, light, M.Neon)
		end
	elseif form == "Chiller" then
		local block = base * CFrame.new(0, 0.12 * k + 0.02, 0)
		box(K, folder, "ChillerFrost", base, 0, 0.006, 0, 0.44 * u, 0.012, 0.44 * u, ICE, M.Ice)
		box(K, folder, "ChillerBlock", block, 0, 0, 0, 0.34 * u, 0.24 * k, 0.34 * u, rgb(36, 40, 50), M.Metal)
		box(K, folder, "ChillerRing", block, 0, 0.06 * k, 0, 0.35 * u, 0.03, 0.35 * u, light, M.Neon)
		box(K, folder, "ChillerIce", block, 0, 0.12 * k + 0.02, 0, 0.36 * u, 0.05, 0.36 * u, ICE, M.Ice)
		for _, z in { -0.08, 0.08 } do
			local from = (block * CFrame.new(-0.17 * u, 0, z * u)).Position
			local exit = L.Exit + Vector3.new(0, z, 0)
			local mid = from:Lerp(exit, 0.5) + (L.Board.UpVector * 0.18)
			cable(K, folder, { from, mid, exit }, 0.085, rgb(20, 22, 26), M.Fabric)
		end
	end
end

local function ramStick(ctx: Ctx, folder: Instance, item, frame: CFrame, index: number)
	-- `frame`: origin at the stick's slot, +Y out of the board, Z along the stick, X its thickness.
	local K, u, k = ctx.K, ctx.u, ctx.k
	local height = (if item.Tall then 0.22 else 0.16) * k
	local length = 0.5 * u
	box(K, folder, "RamPCB", frame, 0, height / 2, 0, 0.014, height, length, PCB_GREEN)
	box(K, folder, "RamContacts", frame, 0, 0.012, 0, 0.016, 0.02, length * 0.92, GOLD, M.Metal)
	if item.Tall then
		for _, side in { -1, 1 } do
			box(K, folder, "RamSpreader", frame, side * 0.012, height / 2 + 0.01, 0, 0.008, height - 0.01, length - 0.02, item.Spreader, M.Metal)
		end
		box(K, folder, "RamTop", frame, 0, height + 0.012, 0, 0.032, 0.025, length - 0.02, if item.Rgb then RGB_CYCLE[(index - 1) % #RGB_CYCLE + 1] else item.Spreader:Lerp(DARK, 0.3), if item.Rgb then M.Neon else M.Metal)
	else
		for chip = -1, 1 do
			for _, side in { -1, 1 } do
				box(K, folder, "RamChip", frame, side * 0.011, height * 0.55, chip * length * 0.3, 0.008, height * 0.4, length * 0.22, CHIP)
			end
		end
	end
end

local function buildRam(ctx: Ctx, folder: Instance, item, slots: number)
	local L, u = ctx.L, ctx.u
	for index = 1, math.min(item.Sticks, slots) do
		local a = 0.16 + (index - 1) * 0.07 * u / L.BW * 1.5
		ramStick(ctx, folder, item, onBoard(ctx, a, 0.22, 0.06), index)
	end
end

-- The graphics card. `slot`: origin at the slot, +Y out of the board, X along the card (rear
-- bracket at -X), Z toward the board's top (the card hangs toward -Z).
local GPU_SIZES = {
	{ 0.55, 0.3, 0.03 },
	{ 0.7, 0.34, 0.05 },
	{ 0.95, 0.4, 0.12 },
	{ 1.1, 0.44, 0.15 },
	{ 1.3, 0.5, 0.2 },
	{ 1.42, 0.56, 0.27 },
}
local function gpuCard(ctx: Ctx, folder: Instance, item, slot: CFrame, maxLength: number?)
	local K, L, u, k = ctx.K, ctx.L, ctx.u, ctx.k
	local size = GPU_SIZES[item.Tier]
	local length = math.min(size[1] * u, maxLength or math.huge)
	local height = math.min(size[2] * k, L.Depth - 0.08)
	local thick = size[3] * u
	local card = slot * CFrame.new(length / 2, 0, 0)
	local top = 0.04 + height
	box(K, folder, "CardPCB", card, 0, 0.04 + height / 2, -0.01, length, height, 0.018, if item.Tier <= 2 then item.Shroud else rgb(26, 30, 34))
	box(K, folder, "CardFingers", card, -length * 0.1, 0.025, -0.01, length * 0.5, 0.03, 0.02, GOLD, M.Metal)
	-- Steel bracket with its ports at the back of the case.
	box(K, folder, "CardBracket", card, -length / 2 - 0.012, 0.04 + height / 2, -thick / 2, 0.02, height + 0.06, math.max(thick, 0.06), STEEL, M.Metal)
	for port = 0, 2 do
		box(K, folder, "CardPort", card, -length / 2 - 0.024, 0.1 + port * height * 0.25, -thick / 2, 0.012, 0.05, math.max(thick * 0.5, 0.03), DARK)
	end
	if item.Tier <= 2 then
		for index = 0, item.Tier + 1 do
			box(K, folder, "CardChip", card, -length * 0.3 + index * length * 0.18, 0.04 + height * 0.55, -0.026, length * 0.12, height * 0.3, 0.014, CHIP)
		end
		if item.Tier == 2 then
			box(K, folder, "CardHeatsink", card, length * 0.15, 0.04 + height * 0.5, -0.04, length * 0.22, height * 0.4, 0.04, STEEL, M.Metal)
		end
		return
	end
	local shroudDepth = thick - 0.025
	box(K, folder, "CardShroud", card, 0, 0.04 + height * 0.48, -0.02 - shroudDepth / 2, length * 0.97, height * 0.92, shroudDepth, item.Shroud, M.Metal)
	local fans = item.Fans or 1
	local fanSize = math.min(height * 0.84, length / fans * 0.92)
	for index = 1, fans do
		local x = -length / 2 + (index - 0.5) * length / fans
		fan(K, folder, card * facing(Vector3.new(x, 0.04 + height * 0.48, -0.02 - shroudDepth - 0.012), Vector3.new(0, 0, -1)), fanSize, 0.024, item.Glow, item.Shroud:Lerp(DARK, 0.5))
	end
	if item.Tier >= 4 then
		local plate = box(K, folder, "CardBackplate", card, 0, 0.04 + height / 2, 0.006, length * 0.98, height * 0.95, 0.012, rgb(40, 42, 48), M.Metal)
		label(plate, string.upper(item.Name), rgb(210, 214, 222), "Front")
		box(K, folder, "CardPower", card, length * 0.32, top + 0.02, -thick / 2, 0.12 * u, 0.04, math.min(0.06, thick), DARK)
	end
	local edge = box(K, folder, "CardEdge", card, 0, top - 0.004, -thick / 2, length * 0.97, 0.012, thick * 0.9, item.Shroud:Lerp(DARK, 0.25), M.Metal)
	label(edge, string.upper(item.Name), if item.Glow then item.Glow else rgb(220, 220, 226), "Top", Enum.Font.GothamBlack, item.Glow ~= nil)
	if item.Glow then
		box(K, folder, "CardGlow", card, length * 0.3, top + 0.006, -thick / 2, length * 0.3, 0.006, thick * 0.5, item.Glow, M.Neon)
	end
end

local function buildGpu(ctx: Ctx, folder: Instance, item)
	local L = ctx.L
	gpuCard(ctx, folder, item, L.Board * CFrame.new(-0.5 * L.BW + 0.03, 0.03, -0.05 * L.BH), L.BW * 0.97)
end

-- Drives lie flat on `frame` (+Y up, front +Z).
local function driveModel(ctx: Ctx, folder: Instance, item, frame: CFrame)
	local K = ctx.K
	if item.Form == "Bay525" then
		box(K, folder, "DriveBody", frame, 0, 0.15, 0, 0.6, 0.28, 0.72, rgb(128, 132, 136), M.Metal)
		box(K, folder, "DriveFace", frame, 0, 0.15, 0.37, 0.62, 0.29, 0.03, rgb(40, 40, 42))
		local sticker = box(K, folder, "DriveLabel", frame, 0, 0.292, -0.05, 0.34, 0.006, 0.26, rgb(236, 232, 218))
		label(sticker, item.Drive, rgb(40, 40, 120), "Top", Enum.Font.Code)
	elseif item.Form == "Hdd" then
		for _, x in { -0.24, 0.24 } do
			box(K, folder, "DriveRail", frame, x, 0.03, 0, 0.03, 0.06, 0.62, DARK, M.Metal)
		end
		box(K, folder, "DriveBase", frame, 0, 0.05, 0, 0.42, 0.07, 0.58, rgb(40, 44, 40), M.Metal)
		box(K, folder, "DriveLid", frame, 0, 0.095, 0, 0.42, 0.02, 0.58, rgb(196, 200, 206), M.Metal)
		local sticker = box(K, folder, "DriveLabel", frame, 0, 0.107, 0.04, 0.26, 0.004, 0.24, rgb(236, 236, 240))
		label(sticker, item.Drive, rgb(30, 30, 40), "Top")
	elseif item.Form == "Ssd" then
		box(K, folder, "SsdBody", frame, 0, 0.02, 0, 0.3, 0.035, 0.42, rgb(30, 32, 40), M.Metal)
		local sticker = box(K, folder, "SsdLabel", frame, 0, 0.039, 0, 0.24, 0.004, 0.3, rgb(60, 130, 220))
		label(sticker, item.Drive, rgb(255, 255, 255), "Top")
	end
end

local function buildStorage(ctx: Ctx, folder: Instance, item)
	local K, L, u = ctx.K, ctx.L, ctx.u
	if item.Form == "M2" then
		local at = onBoard(ctx, -0.02, -0.13, 0.04)
		box(K, folder, "M2Stick", at, 0, 0, 0, 0.32 * u, 0.012, 0.09 * u, rgb(24, 26, 30))
		for index = -1, 1 do
			box(K, folder, "M2Chip", at, index * 0.09 * u, 0.01, 0, 0.07 * u, 0.01, 0.07 * u, CHIP)
		end
		if item.Heatsink then
			local cover = box(K, folder, "M2Heatsink", at, 0, 0.03, 0, 0.34 * u, 0.04, 0.1 * u, rgb(170, 176, 186), M.Metal)
			label(cover, item.Drive, DARK, "Top")
		end
		return
	end
	driveModel(ctx, folder, item, if item.Form == "Ssd" then L.Ssd else L.Drive)
	-- Data cable from the drive to the board.
	local from = ((if item.Form == "Ssd" then L.Ssd else L.Drive) * CFrame.new(0.1, 0.12, -0.3)).Position
	local to = onBoard(ctx, 0.48, -0.32, 0.05).Position
	cable(K, folder, { from, from:Lerp(to, 0.5) + L.Board.UpVector * 0.1, to }, if item.Form == "Bay525" then 0.03 else 0.02, if item.Form == "Bay525" then rgb(170, 170, 176) else rgb(200, 40, 40))
end

-- Power supply on `frame` (+Y the label side, +Z the plug side, -X the fan).
local function psuModel(ctx: Ctx, folder: Instance, item, frame: CFrame, size: Vector3)
	local K = ctx.K
	box(K, folder, "PsuBody", frame, 0, 0, 0, size.X, size.Y, size.Z, item.Body, M.Metal)
	cylinder(K, folder, "PsuFanGrille", frame, -size.X / 2 - 0.004, 0, 0, 0.012, math.min(size.Y, size.Z) * 0.8, "X", DARK, M.Metal)
	for _, offset in { -0.12, 0, 0.12 } do
		box(K, folder, "PsuGrilleBar", frame, -size.X / 2 - 0.012, offset * size.Y, 0, 0.008, 0.012, math.min(size.Y, size.Z) * 0.8, CHROME, M.Metal)
	end
	local plate = box(K, folder, "PsuLabel", frame, 0, size.Y / 2 + 0.004, 0, size.X * 0.7, 0.008, size.Z * 0.55, item.Accent or rgb(220, 220, 214))
	label(plate, tostring(item.Capacity) .. " W", if item.Accent then DARK else rgb(30, 30, 30), "Top", Enum.Font.GothamBlack)
	if item.Accent then
		box(K, folder, "PsuStripe", frame, 0, size.Y / 2 + 0.003, size.Z * 0.38, size.X * 0.9, 0.006, 0.03, item.Accent, if item.Rgb then M.Neon else M.Metal)
		box(K, folder, "PsuStripe", frame, 0, size.Y / 2 + 0.003, -size.Z * 0.38, size.X * 0.9, 0.006, 0.03, item.Accent, if item.Rgb then M.Neon else M.Metal)
	end
	box(K, folder, "PsuSocket", frame, 0.06, 0.1 * size.Y, size.Z / 2 + 0.006, 0.12, 0.1, 0.012, DARK)
	box(K, folder, "PsuSwitch", frame, -0.1, 0.1 * size.Y, size.Z / 2 + 0.008, 0.05, 0.08, 0.016, rgb(160, 30, 30))
	if item.Capacity >= 750 then
		for index = 0, 2 do
			box(K, folder, "PsuModularPort", frame, -0.08 + index * 0.08, 0, -size.Z / 2 - 0.006, 0.06, 0.12, 0.012, SLOT_BLACK)
		end
	end
end

local function buildPsu(ctx: Ctx, folder: Instance, item, gpu)
	local K, L = ctx.K, ctx.L
	psuModel(ctx, folder, item, L.Psu, L.PsuSize)
	local sleeve = if item.Rgb then item.Accent elseif item.Capacity >= 750 then rgb(30, 30, 34) else rgb(200, 60, 40)
	local from = (L.Psu * CFrame.new(0, L.PsuSize.Y * 0.3, -L.PsuSize.Z / 2)).Position
	local to = onBoard(ctx, 0.5, 0.1, 0.07).Position
	cable(K, folder, { from, from:Lerp(to, 0.5) + L.Board.UpVector * 0.2, to }, 0.06, sleeve, if item.Capacity >= 750 then M.Fabric else nil)
	if gpu.Tier >= 4 then
		local size = GPU_SIZES[gpu.Tier]
		local length = math.min(size[1] * ctx.u, L.BW * 0.97)
		local height = math.min(size[2] * ctx.k, L.Depth - 0.08)
		local plug = (L.Board * CFrame.new(-0.5 * L.BW + 0.03 + length / 2 + length * 0.32, 0.03 + 0.04 + height + 0.04, -0.05 * L.BH - size[3] * ctx.u / 2)).Position
		cable(K, folder, { (L.Psu * CFrame.new(L.PsuSize.X * 0.2, L.PsuSize.Y * 0.3, -L.PsuSize.Z / 2)).Position, plug + L.Board.UpVector * 0.08, plug }, 0.04, sleeve, M.Fabric)
	end
end

----------------------------------------------------------------------------------------------------
-- Case shells

local function screw(K: Kit, folder: Instance, position: Vector3, normal: Vector3, thumb: boolean)
	local model = group(folder, "CaseScrew")
	local frame = facing(position, normal)
	cylinder(K, model, "ScrewHead", frame, 0, 0.018, 0, 0.036, if thumb then 0.1 else 0.075, "Y", if thumb then rgb(40, 40, 44) else CHROME, M.Metal)
	if thumb then
		cylinder(K, model, "ScrewKnurl", frame, 0, 0.026, 0, 0.022, 0.11, "Y", rgb(70, 70, 76), M.Metal)
	end
	box(K, model, "ScrewSlot", frame, 0, 0.038, 0, 0.055, 0.006, 0.012, HOLE)
	box(K, model, "ScrewSlot", frame, 0, 0.038, 0, 0.012, 0.006, 0.055, HOLE)
end

local function desktopShell(K: Kit, chassis: Instance, panel: Instance, info: CaseInfo, parts, P: Kit)
	local W, H, D = info.W, info.H, info.D
	local look = info.Look
	local cpu = Catalog.installed("CPU", parts.CPU)
	local cooler = Catalog.installed("Cooling", parts.Cooling)
	local F = CFrame.identity
	for _, x in { -1.1, 1.1 } do
		for _, z in { -0.8, 0.8 } do
			box(K, chassis, "Foot", F, x, 0.02, z, 0.16, 0.04, 0.16, RUBBER, M.Rubber)
		end
	end
	box(K, chassis, "FloorTray", F, 0, 0.058, -0.02, W - 0.04, 0.036, D - 0.1, look.Trim, M.Metal)
	local fz = D / 2
	box(K, chassis, "Bezel", F, 0, 0.35, fz - 0.04, W + 0.02, 0.62, 0.08, look.Front)
	local plate = look.Front:Lerp(DARK, 0.06)
	box(K, chassis, "FloppyDrive525", F, -0.62, 0.38, fz + 0.015, 1.02, 0.34, 0.03, plate)
	box(K, chassis, "DiskSlot", F, -0.62, 0.4, fz + 0.035, 0.82, 0.045, 0.01, SLOT_BLACK)
	box(K, chassis, "DriveLatch", F, -0.62, 0.4, fz + 0.055, 0.07, 0.26, 0.05, rgb(44, 42, 40))
	box(K, chassis, "FloppyDrive35", F, 0.2, 0.35, fz + 0.015, 0.6, 0.2, 0.03, plate)
	box(K, chassis, "DiskSlot", F, 0.2, 0.38, fz + 0.035, 0.42, 0.03, 0.01, SLOT_BLACK)
	box(K, chassis, "EjectButton", F, 0.38, 0.3, fz + 0.04, 0.1, 0.05, 0.03, look.Trim)
	local readout = box(K, chassis, "SpeedReadout", F, 0.9, 0.52, fz + 0.01, 0.26, 0.14, 0.02, SLOT_BLACK)
	label(readout, cpu.Clock, rgb(255, 60, 40), "Front", Enum.Font.Code, true)
	box(K, chassis, "TurboButton", F, 0.68, 0.36, fz + 0.02, 0.12, 0.07, 0.04, look.Trim)
	box(K, chassis, "ResetButton", F, 0.84, 0.36, fz + 0.018, 0.08, 0.05, 0.035, look.Trim)
	cylinder(K, chassis, "KeyLock", F, 1.06, 0.36, fz + 0.015, 0.03, 0.1, "Z", CHROME, M.Metal)
	for index, light in { { cooler.Light, M.Neon }, { rgb(110, 70, 22), M.SmoothPlastic }, { rgb(240, 196, 60), M.Neon } } do
		box(K, chassis, "StatusLight", F, 0.56 + index * 0.15, 0.22, fz + 0.01, 0.05, 0.025, 0.02, light[1], light[2])
	end
	for row = 0, 3 do
		box(K, chassis, "FrontVent", F, 0.5, 0.08 + row * 0.028, fz + 0.004, 1.0, 0.018, 0.008, SLOT_BLACK)
	end
	local badge = box(K, chassis, "Badge", F, -0.85, 0.13, fz + 0.006, 0.5, 0.09, 0.012, rgb(44, 42, 40))
	label(badge, cpu.Badge, look.Front:Lerp(WHITE, 0.3), "Front")
	-- Back panel: card brackets, fan grille over the power supply, mains socket.
	local bz = -D / 2
	box(K, chassis, "BackPanel", F, 0, 0.36, bz + 0.02, W - 0.02, 0.58, 0.04, look.Trim, M.Metal)
	for index = 0, 6 do
		box(K, chassis, "SlotBracket", F, -1.05 + index * 0.11, 0.32, bz - 0.008, 0.07, 0.42, 0.015, CHROME, M.Metal)
	end
	cylinder(K, chassis, "FanGrille", F, 0.87, 0.32, bz - 0.01, 0.02, 0.36, "Z", rgb(44, 42, 40), M.Metal)
	box(K, chassis, "MainsSocket", F, 0.5, 0.18, bz - 0.01, 0.16, 0.1, 0.02, SLOT_BLACK)
	-- The lid: top and both sides in one piece, screwed down at the corners.
	box(P, panel, "LidTop", F, 0, H - 0.02, -0.03, W + 0.03, 0.04, D - 0.1, look.Body)
	for _, side in { -1, 1 } do
		box(P, panel, "LidSide", F, side * (W / 2 + 0.005), 0.36, -0.03, 0.035, 0.58, D - 0.1, look.Body)
		box(P, panel, "LidSeam", F, side * (W / 2 + 0.008), 0.085, -0.03, 0.04, 0.025, D - 0.1, look.Trim)
	end
	for index = 0, 5 do
		box(P, panel, "SideVent", F, -W / 2 - 0.022, 0.34, -0.7 + index * 0.08, 0.01, 0.3, 0.03, SLOT_BLACK)
	end
	box(P, panel, "PowerSwitch", F, W / 2 + 0.03, 0.34, -0.6, 0.04, 0.16, 0.12, rgb(168, 40, 32))
	for _, x in { -1.1, 1.1 } do
		for _, z in { -0.82, 0.76 } do
			screw(P, panel, Vector3.new(x, H, z), Vector3.new(0, 1, 0), false)
		end
	end
end

local function towerShell(K: Kit, chassis: Instance, panel: Instance, info: CaseInfo, parts, P: Kit, L: Layout)
	local W, H, D = info.W, info.H, info.D
	local look = info.Look
	local showcase = info.Form == "Showcase"
	local cpu = Catalog.installed("CPU", parts.CPU)
	local cooler = Catalog.installed("Cooling", parts.Cooling)
	local light = cooler.Light
	local F = CFrame.identity
	for _, x in { -W / 2 + 0.14, W / 2 - 0.14 } do
		for _, z in { -D / 2 + 0.22, D / 2 - 0.22 } do
			box(K, chassis, "Foot", F, x, 0.03, z, 0.16, 0.06, 0.3, RUBBER, M.Rubber)
		end
	end
	box(K, chassis, "BasePlate", F, 0, 0.085, 0, W, 0.05, D, look.Trim, M.Metal)
	box(K, chassis, "TopPlate", F, 0, H - 0.03, 0, W, 0.06, D, look.Body, M.Metal)
	box(K, chassis, "TopVent", F, 0.02, H + 0.002, -0.2, W * 0.62, 0.006, D * 0.5, look.Trim:Lerp(HOLE, 0.5))
	box(K, chassis, "TrayWall", F, -W / 2 + 0.02, H / 2 + 0.02, 0, 0.04, H - 0.14, D - 0.02, look.Body, M.Metal)
	-- Rear: I/O shield, card slot covers, exhaust grille and the power supply's socket.
	local rz = -D / 2
	box(K, chassis, "RearPanel", F, 0.01, H / 2 + 0.02, rz + 0.02, W - 0.06, H - 0.14, 0.04, look.Trim, M.Metal)
	local io = L.Board * CFrame.new(-0.5 * L.BW, 0.12, 0.3 * L.BH)
	box(K, chassis, "IoShield", CFrame.new(io.Position.X, io.Position.Y, rz - 0.004), 0, 0, 0, 0.16, 0.44, 0.012, rgb(150, 150, 156), M.Metal)
	for index = 0, 3 do
		local slotY = (L.Board * CFrame.new(0, 0, (-0.05 - index * 0.15) * L.BH)).Position.Y
		box(K, chassis, "SlotCover", F, -0.08, slotY - 0.06, rz - 0.004, 0.4, 0.06, 0.012, CHROME, M.Metal)
	end
	box(K, chassis, "PsuPlate", F, (L.Psu.Position.X), 0.32, rz - 0.004, math.min(W - 0.12, L.PsuSize.Y), 0.4, 0.012, DARK)
	-- Front: a light strip with the readout and power button on top, the badge at the foot.
	local fz = D / 2
	box(K, chassis, "FrontIoStrip", F, 0, H - 0.15, fz - 0.04, W, 0.18, 0.09, look.Front)
	local readout = box(K, chassis, "SpeedReadout", F, -W * 0.22, H - 0.15, fz + 0.006, 0.26, 0.1, 0.012, SLOT_BLACK)
	label(readout, cpu.Clock, rgb(255, 60, 40), "Front", Enum.Font.Code, true)
	cylinder(K, chassis, "PowerButton", F, W * 0.22, H - 0.15, fz + 0.01, 0.03, 0.11, "Z", look.Trim, M.Metal)
	cylinder(K, chassis, "StatusLight", F, W * 0.22, H - 0.15, fz + 0.022, 0.006, 0.05, "Z", light, M.Neon)
	box(K, chassis, "FrontFoot", F, 0, 0.18, fz - 0.04, W, 0.14, 0.09, look.Front)
	local badge = box(K, chassis, "Badge", F, 0, 0.18, fz + 0.006, math.min(0.5, W - 0.2), 0.08, 0.012, rgb(30, 30, 34))
	label(badge, cpu.Badge, rgb(230, 230, 236), "Front")
	local middle = H - 0.24 - 0.25
	local middleY = 0.25 + middle / 2
	if look.GlassFront then
		local pane = box(K, chassis, "FrontGlass", F, 0, middleY, fz - 0.02, W - 0.04, middle, 0.03, GLASS)
		glass(pane, 0.55)
		for _, side in { -1, 1 } do
			box(K, chassis, "FrontPost", F, side * (W / 2 - 0.02), middleY, fz - 0.04, 0.04, middle, 0.09, look.Trim, M.Metal)
		end
	else
		box(K, chassis, "FrontPanel", F, 0, middleY, fz - 0.04, W, middle, 0.08, look.Front)
		if look.Mesh then
			box(K, chassis, "FrontMesh", F, 0, middleY, fz + 0.002, W - 0.16, middle - 0.1, 0.006, rgb(14, 16, 18), M.Fabric)
			for row = 1, 10 do
				box(K, chassis, "MeshLine", F, 0, 0.3 + row * (middle - 0.1) / 11, fz + 0.006, W - 0.16, 0.012, 0.004, look.Trim:Lerp(rgb(80, 90, 100), 0.4))
			end
		else
			for row = 0, 5 do
				box(K, chassis, "FrontGroove", F, 0, 0.42 + row * 0.08, fz + 0.002, W - 0.2, 0.014, 0.006, look.Trim)
			end
		end
	end
	-- Case fans: lit in glowing cases.
	for _, entry in L.Fans do
		fan(K, chassis, entry[1] :: CFrame, entry[2] :: number, 0.06, if look.Glow then light else nil, if look.Body.R + look.Body.G > 1.4 then rgb(220, 222, 226) else DARK)
	end
	if look.Glow then
		box(K, chassis, "GlowStrip", F, 0.02, H - 0.08, fz - 0.12, W - 0.12, 0.025, 0.025, light, M.Neon)
		for _, side in { -1, 1 } do
			box(K, chassis, "GlowStrip", F, side * (W / 2 - 0.07), H / 2, fz - 0.12, 0.025, H - 0.5, 0.025, light, M.Neon)
		end
	end
	if showcase then
		for _, x in { -W / 2 + 0.03, W / 2 - 0.03 } do
			for _, z in { -D / 2 + 0.03, D / 2 - 0.03 } do
				box(K, chassis, "CornerPost", F, x, H / 2, z, 0.06, H - 0.1, 0.06, look.Trim, M.Metal)
			end
		end
		box(K, chassis, "PsuShroud", F, 0, 0.58, 0, W - 0.1, 0.04, D - 0.1, look.Body, M.Metal)
		box(K, chassis, "ShroudGlow", F, 0, 0.603, D / 2 - 0.1, W - 0.16, 0.008, 0.03, light, M.Neon)
	end
	-- Side panel on +X: solid steel, steel with a window, or glass in a thin frame.
	local px = W / 2 + 0.018
	if look.Window == "None" then
		box(P, panel, "SidePanel", F, px, H / 2, 0, 0.035, H - 0.1, D - 0.06, look.Body, M.Metal)
		for index = 0, 5 do
			box(P, panel, "SideVent", F, px + 0.02, 0.5, 0.25 + index * 0.08, 0.006, 0.4, 0.03, HOLE)
		end
	elseif look.Window == "Small" then
		local top, bottom, front, back = H - 0.25, 1.0, 0.45, -0.8
		box(P, panel, "SidePanel", F, px, (bottom + 0.05) / 2, 0, 0.035, bottom - 0.05, D - 0.06, look.Body, M.Metal)
		box(P, panel, "SidePanel", F, px, (top + H - 0.05) / 2, 0, 0.035, H - 0.05 - top, D - 0.06, look.Body, M.Metal)
		box(P, panel, "SidePanel", F, px, (bottom + top) / 2, (front + D / 2 - 0.03) / 2, 0.035, top - bottom, D / 2 - 0.03 - front, look.Body, M.Metal)
		box(P, panel, "SidePanel", F, px, (bottom + top) / 2, (back - D / 2 + 0.03) / 2, 0.035, top - bottom, back + D / 2 - 0.03, look.Body, M.Metal)
		local pane = box(P, panel, "SideGlass", F, px + 0.004, (bottom + top) / 2, (front + back) / 2, 0.02, top - bottom + 0.04, front - back + 0.04, GLASS)
		glass(pane, 0.5)
	else
		local pane = box(P, panel, "SideGlass", F, px, H / 2, 0, 0.022, H - 0.16, D - 0.12, GLASS)
		glass(pane, if showcase then 0.62 else 0.55)
		for _, y in { 0.075, H - 0.075 } do
			box(P, panel, "SideFrame", F, px, y, 0, 0.03, 0.05, D - 0.06, look.Trim, M.Metal)
		end
		for _, z in { -D / 2 + 0.055, D / 2 - 0.055 } do
			box(P, panel, "SideFrame", F, px, H / 2, z, 0.03, H - 0.1, 0.05, look.Trim, M.Metal)
		end
	end
	for _, y in { 0.2, H - 0.2 } do
		for _, z in { -D / 2 + 0.12, D / 2 - 0.12 } do
			screw(P, panel, Vector3.new(W / 2 + 0.035, y, z), Vector3.new(1, 0, 0), true)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Public builders

export type BuildOptions = {
	Name: string?,
	Scale: number?,
	Make: Make?,
	Open: boolean?, -- the access panel lies at PanelAside instead of on the case
	PanelAside: CFrame?, -- world pivot for a removed panel
	Interior: boolean?, -- build the insides even behind a closed solid case
}

-- The system unit for `parts` at `frame` (world). Returns the model.
function PcModel.build(parent: Instance, frame: CFrame, parts: any, options: BuildOptions?): Model
	local opts: BuildOptions = options or {}
	local clean = Catalog.sanitize(parts)
	local info = PcModel.caseInfo(clean.Case)
	local scale = opts.Scale or 1
	local K = kit(frame, scale, opts.Make)
	local root = Instance.new("Model")
	root.Name = opts.Name or "SystemUnit"
	root:SetAttribute("CaseForm", info.Form)
	root.WorldPivot = frame
	-- Parented first, so a builder that yields between parts (the store) shows progress.
	root.Parent = parent
	local chassis = group(root, "Case")
	local panel = group(root, "AccessPanel")
	local closedPivot = K.at(PcModel.panelPivot(clean.Case))
	local asidePivot = opts.PanelAside or closedPivot
	local open = opts.Open == true and opts.PanelAside ~= nil
	-- Panel parts are placed so their pivot lands on the aside frame when the case is open.
	local panelOrigin = if open then asidePivot * closedPivot:Inverse() * frame else frame
	local P = kit(panelOrigin, scale, opts.Make)
	panel:SetAttribute("ClosedPivot", closedPivot)
	panel:SetAttribute("AsidePivot", asidePivot)
	panel.WorldPivot = if open then asidePivot else closedPivot
	local L = layoutOf(info)
	if info.Form == "Desktop" then
		desktopShell(K, chassis, panel, info, clean, P)
	else
		towerShell(K, chassis, panel, info, clean, P, L)
	end
	local seeInside = open or opts.Interior == true or info.Look.Window ~= "None" or info.Look.Mesh == true
	if seeInside then
		local ctx: Ctx = { K = K, L = L, u = L.BH / 1.45, k = math.min(L.Depth, 0.81) / 0.81 }
		local board = Catalog.Items[clean.Motherboard]
		buildMotherboard(ctx, group(root, "Motherboard"), board)
		buildCpu(ctx, group(root, "CPU"), Catalog.Items[clean.CPU])
		buildCooler(ctx, group(root, "Cooling"), Catalog.Items[clean.Cooling], onBoard(ctx, -0.12, 0.25, 0.075))
		buildRam(ctx, group(root, "RAM"), Catalog.Items[clean.RAM], if board.Tier >= 3 then 4 else 2)
		local gpu = Catalog.Items[clean.GPU]
		buildGpu(ctx, group(root, "GPU"), gpu)
		buildStorage(ctx, group(root, "Storage"), Catalog.Items[clean.Storage])
		buildPsu(ctx, group(root, "PSU"), Catalog.Items[clean.PSU], gpu)
	end
	return root
end

-- Size of the system unit (case-local extents) for carrying and placing.
function PcModel.size(caseId: any): Vector3
	local info = PcModel.caseInfo(caseId)
	return Vector3.new(info.W, info.H, info.D)
end

local CRT_SCALE = { [14] = 1, [15] = 1.07, [17] = 1.16 }

local function idleText(item, away: boolean): string
	if away then
		return "\n\n      NO SIGNAL\n\n   CHECK CABLE"
	elseif item.Flat then
		return "HARBOUR-OS 3.30\n\n  STOCKS   BRANCHES\n  WEB SHOP   MY PC\n\nREADY_"
	end
	return "HARBOUR-DOS  Version 3.30\n(C) Copyright 1989\n\nC:\\>dir\n ACCOUNTS   <DIR>\n STAFF      <DIR>\n LEDGER     WK1\n TIDES      EXE\n\nC:\\>_"
end

export type MonitorOptions = { Name: string?, Scale: number?, Make: Make?, Away: boolean? }

-- The monitor, origin on the surface under the front of its bezel, facing +Z. Its glass is
-- the part "ScreenCurve" (+Z face toward the viewer) the office PC lays its screen over.
function PcModel.buildMonitor(parent: Instance, frame: CFrame, monitorId: any, options: MonitorOptions?): Model
	local opts: MonitorOptions = options or {}
	local item = Catalog.installed("Monitor", monitorId)
	local root = Instance.new("Model")
	root.Name = opts.Name or "Monitor"
	root.WorldPivot = frame
	root.Parent = parent
	local away = opts.Away == true
	local screen = item.Screen
	local bezel = item.Bezel
	local housing = bezel:Lerp(BLACK, 0.12)
	local textColor = if away then screen.Mid else screen.Bright
	local F = CFrame.identity
	if not item.Flat then
		local f = CRT_SCALE[item.Inches] or 1
		local K = kit(frame, (opts.Scale or 1) * f, opts.Make)
		cylinder(K, root, "SwivelBase", F, 0, 0.03, -0.5, 0.06, 1.1, "Y", housing)
		box(K, root, "SwivelNeck", F, 0, 0.14, -0.5, 0.5, 0.22, 0.5, housing)
		local sy = 1.06
		local openY, openW, openH = sy + 0.1, 1.56, 1.2
		box(K, root, "BezelTop", F, 0, sy + 0.78, 0, 2.0, 0.16, 0.16, bezel)
		box(K, root, "BezelChin", F, 0, sy - 0.68, 0, 2.0, 0.36, 0.16, bezel)
		for _, side in { -1, 1 } do
			box(K, root, "BezelSide", F, side * 0.89, openY, 0, 0.22, openH, 0.16, bezel)
			box(K, root, "ScreenSurround", F, 0, openY + side * (openH / 2 - 0.03), -0.02, openW, 0.06, 0.12, bezel:Lerp(DARK, 0.45))
			box(K, root, "ScreenSurround", F, side * (openW / 2 - 0.03), openY, -0.02, 0.06, openH - 0.12, 0.12, bezel:Lerp(DARK, 0.45))
		end
		local glassPart = box(K, root, "ScreenGlass", F, 0, openY, -0.06, openW - 0.12, openH - 0.12, 0.04, screen.Screen)
		glassPart.Reflectance = 0.06
		local bulge = box(K, root, "ScreenCurve", F, 0, openY, -0.06, openW - 0.12, openH - 0.12, 0.12, screen.Screen)
		bulge.Reflectance = 0.12
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = bulge
		label(bulge, idleText(item, away), textColor, "Front", screen.Body, true)
		local line = (bulge:FindFirstChild("Label") :: SurfaceGui):FindFirstChildOfClass("TextLabel") :: TextLabel
		line.TextXAlignment = if away then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
		line.TextYAlignment = Enum.TextYAlignment.Top
		line.Size = UDim2.new(1, -12, 1, -8)
		line.Position = UDim2.fromOffset(6, 4)
		local plate = box(K, root, "ModelPlate", F, -0.55, sy - 0.68, 0.085, 0.62, 0.09, 0.01, rgb(44, 42, 40))
		label(plate, item.Plate, bezel:Lerp(WHITE, 0.4), "Front")
		for _, x in { 0.22, 0.38 } do
			cylinder(K, root, "Knob", F, x, sy - 0.68, 0.11, 0.06, 0.11, "Z", rgb(44, 42, 40))
		end
		box(K, root, "PowerButton", F, 0.74, sy - 0.68, 0.1, 0.16, 0.12, 0.04, housing)
		box(K, root, "PowerLight", F, 0.56, sy - 0.68, 0.09, 0.05, 0.03, 0.02, if away then rgb(240, 170, 40) else rgb(90, 230, 110), M.Neon)
		if item.Inches == 14 then
			local note = K.part(root, "StickyNote", Vector3.new(0.27, 0.27, 0.01), F * CFrame.new(0.8, sy + 0.66, 0.086) * CFrame.Angles(0, 0, -0.12), rgb(250, 228, 110))
			label(note, "back up\nfriday!", rgb(40, 52, 120), "Front", Enum.Font.IndieFlower)
		end
		for _, step in { { Vector3.new(1.9, 1.62, 0.45), 0, -0.305 }, { Vector3.new(1.6, 1.34, 0.36), -0.04, -0.71 }, { Vector3.new(1.28, 1.06, 0.3), -0.07, -1.04 } } do
			local size, dy, z = step[1] :: Vector3, step[2] :: number, step[3] :: number
			box(K, root, "Housing", F, 0, sy + dy, z, size.X, size.Y, size.Z, housing)
			for index = 1, math.floor(size.Z / 0.07) - 1 do
				box(K, root, "TopVent", F, 0, sy + dy + size.Y / 2 + 0.003, z - size.Z / 2 + index * 0.07, size.X * 0.62, 0.012, 0.03, SLOT_BLACK)
			end
		end
		box(K, root, "RearCap", F, 0, sy - 0.09, -1.24, 0.98, 0.78, 0.1, housing:Lerp(DARK, 0.1))
	else
		local K = kit(frame, opts.Scale or 1, opts.Make)
		local wide = item.Ultrawide == true
		local w, h = if wide then 3.3 else 2.5, if wide then 1.42 else 1.5
		local cy = 0.42 + h / 2
		box(K, root, "StandFoot", F, 0, 0.02, -0.35, if wide then 1.3 else 0.9, 0.04, 0.6, bezel:Lerp(rgb(120, 120, 126), 0.3), M.Metal)
		box(K, root, "StandNeck", F, 0, cy / 2 + 0.05, -0.42, 0.14, cy, 0.08, bezel:Lerp(rgb(120, 120, 126), 0.3), M.Metal)
		box(K, root, "Panel", F, 0, cy, -0.12, w, h, 0.08, bezel)
		box(K, root, "PanelBack", F, 0, cy, -0.2, w * 0.6, h * 0.6, 0.1, bezel:Lerp(DARK, 0.2))
		local panel = box(K, root, "ScreenCurve", F, 0, cy + 0.03, -0.075, w - 0.08, h - 0.14, 0.012, screen.Screen)
		panel.Reflectance = 0.05
		label(panel, idleText(item, away), textColor, "Front", screen.Body, true)
		local line = (panel:FindFirstChild("Label") :: SurfaceGui):FindFirstChildOfClass("TextLabel") :: TextLabel
		line.TextXAlignment = if away then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
		line.TextYAlignment = Enum.TextYAlignment.Top
		local plate = box(K, root, "ModelPlate", F, 0, cy - h / 2 + 0.04, -0.075, 0.6, 0.05, 0.01, bezel)
		label(plate, item.Plate, rgb(170, 170, 180), "Front")
		box(K, root, "PowerLight", F, w / 2 - 0.12, cy - h / 2 + 0.04, -0.075, 0.04, 0.02, 0.012, if away then rgb(240, 170, 40) else screen.Hot, M.Neon)
		if wide then
			box(K, root, "BackGlow", F, 0, cy, -0.255, w * 0.5, 0.03, 0.02, screen.Hot, M.Neon)
		end
	end
	return root
end

-- One product on its own, standing on `frame`'s XZ plane and facing +Z, for shop displays.
function PcModel.component(parent: Instance, frame: CFrame, id: string, options: BuildOptions?): Model
	local opts: BuildOptions = options or {}
	local item = Catalog.Items[id]
	local slot = item.Slot
	if slot == "Case" then
		local parts = table.clone(Catalog.Defaults)
		parts.Case = id
		parts.Cooling = if item.Look.Glow then "RgbLoop" else "FanTower"
		parts.GPU = if item.Look.Glow then "GpuSwell" else "GpuReef"
		parts.RAM = if item.Look.Glow then "Ram128G" else "Ram16G"
		parts.Motherboard = if item.Look.Glow then "MbRiptide" else "MbReef"
		parts.PSU = "Psu750"
		parts.Storage = "Ssd2T"
		return PcModel.build(parent, frame, parts, { Name = opts.Name or "Component", Scale = opts.Scale, Make = opts.Make })
	elseif slot == "Monitor" then
		return PcModel.buildMonitor(parent, frame, id, { Name = opts.Name or "Component", Scale = opts.Scale, Make = opts.Make })
	end
	local K = kit(frame, opts.Scale, opts.Make)
	local root = Instance.new("Model")
	root.Name = opts.Name or "Component"
	root.WorldPivot = frame
	root.Parent = parent
	local F = CFrame.identity
	-- A board standing up facing the viewer: X across, Y toward the viewer, Z up.
	local standing = CFrame.fromMatrix(Vector3.new(0, 0.76, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0))
	local L: Layout = {
		Board = standing,
		BW = 1.5,
		BH = 1.45,
		Depth = 0.81,
		Psu = CFrame.identity,
		PsuSize = Vector3.new(0.42, 0.8, 0.86),
		Drive = CFrame.identity,
		Ssd = CFrame.identity,
		Radiator = CFrame.fromMatrix(Vector3.new(0, 0.62, -0.42), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, -1, 0)),
		RadLength = 1.1,
		RadWidth = 0.5,
		Reservoir = CFrame.new(0.7, 0.36, 0.05),
		Exit = Vector3.new(0, 0.06, -0.6),
		Fans = {},
	}
	local ctx: Ctx = { K = K, L = L, u = 1, k = 1 }
	if slot == "Motherboard" then
		buildMotherboard(ctx, root, item)
		box(K, root, "DisplayStand", F, 0, 0.02, -0.05, 1.2, 0.04, 0.4, DARK, M.Metal)
	elseif slot == "CPU" then
		local chip = CFrame.new(0, 0.16, 0) * CFrame.Angles(math.pi / 2, 0, 0)
		box(K, root, "ProcessorSubstrate", chip, 0, 0, 0, 0.26, 0.02, 0.26, rgb(30, 110, 76))
		local lid = box(K, root, "ProcessorLid", chip, 0, 0.02, 0, 0.2, 0.025, 0.2, item.Lid, M.Metal)
		label(lid, item.Badge .. "\n" .. item.Clock, rgb(40, 40, 46), "Top", Enum.Font.GothamBold)
		for pin = -4, 4 do
			box(K, root, "GoldPin", chip, pin * 0.026, -0.016, 0.12, 0.008, 0.012, 0.02, GOLD, M.Metal)
		end
		box(K, root, "DisplayStand", F, 0, 0.01, -0.02, 0.32, 0.02, 0.14, DARK, M.Metal)
	elseif slot == "RAM" then
		for index = 1, math.min(item.Sticks, 2) do
			local stick = CFrame.fromMatrix(Vector3.new(0, 0.02, (index - 1.5) * 0.12), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0), Vector3.new(-1, 0, 0))
			ramStick(ctx, root, item, stick, index)
		end
		box(K, root, "DisplayStand", F, 0, 0.01, 0, 0.6, 0.02, 0.32, DARK, M.Metal)
	elseif slot == "GPU" then
		local size = GPU_SIZES[item.Tier]
		local slotFrame = CFrame.fromMatrix(Vector3.new(size[1] / 2, 0, -size[3] / 2), Vector3.new(-1, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, -1))
		gpuCard(ctx, root, item, slotFrame)
	elseif slot == "Storage" then
		if item.Form == "M2" then
			local at = CFrame.new(0, 0.12, 0) * CFrame.Angles(math.pi / 2, 0, 0)
			box(K, root, "M2Stick", at, 0, 0, 0, 0.32, 0.012, 0.09, rgb(24, 26, 30))
			for index = -1, 1 do
				box(K, root, "M2Chip", at, index * 0.09, 0.01, 0, 0.07, 0.01, 0.07, CHIP)
			end
			if item.Heatsink then
				local cover = box(K, root, "M2Heatsink", at, 0, 0.03, 0, 0.34, 0.04, 0.1, rgb(170, 176, 186), M.Metal)
				label(cover, item.Drive, DARK, "Top")
			end
			box(K, root, "DisplayStand", F, 0, 0.01, -0.03, 0.4, 0.02, 0.12, DARK, M.Metal)
		else
			local depth = if item.Form == "Bay525" then 0.75 elseif item.Form == "Hdd" then 0.62 else 0.42
			driveModel(ctx, root, item, CFrame.new(0, depth / 2 + 0.02, -0.08) * CFrame.Angles(math.pi / 2, 0, 0))
			box(K, root, "DisplayStand", F, 0, 0.01, -0.05, 0.7, 0.02, 0.3, DARK, M.Metal)
		end
	elseif slot == "Cooling" then
		box(K, root, "DisplaySocket", F, 0, 0.03, 0, 0.5, 0.06, 0.5, rgb(30, 110, 76))
		buildCooler(ctx, root, item, CFrame.new(0, 0.06, 0) * CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, 1), Vector3.new(0, 1, 0), Vector3.new(-1, 0, 0)))
	elseif slot == "PSU" then
		psuModel(ctx, root, item, CFrame.fromMatrix(Vector3.new(0, 0.21, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0)), L.PsuSize)
	end
	return root
end

return PcModel
