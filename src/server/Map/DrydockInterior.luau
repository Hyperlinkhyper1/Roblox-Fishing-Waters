-- Fixed, hand-placed workshop dressing. Coordinates share Drydock's floor frame:
-- the walking surface is Y=2, the repair basin is on the left, and visitors
-- approach the counter from -Z. Small details never participate in physics.
local Props = require(script.Parent.Props)

local Interior = {}
local VERSION = 1
local rgb, V, A = Color3.fromRGB, Vector3.new, CFrame.Angles
local M = Enum.Material
local STEEL = rgb(47, 58, 64)
local SILVER = rgb(169, 181, 182)
local BLACK = rgb(29, 35, 37)
local TEAL = rgb(46, 96, 105)
local RED = rgb(164, 62, 45)
local YELLOW = rgb(232, 184, 48)
local CREAM = rgb(234, 225, 196)
local WOOD = rgb(139, 104, 65)
local ROPE = rgb(171, 145, 99)
local RUST = rgb(115, 71, 46)

function Interior.ensure(shop: Model, frame: CFrame)
	local existing = shop:FindFirstChild("InteriorDetails")
	if existing and existing:GetAttribute("DetailVersion") == VERSION then
		return
	end
	if existing then
		existing:Destroy()
	end
	-- Replace the original block-shaped tools and gas bottle on baked maps too.
	for _, item in shop:GetChildren() do
		if table.find({ "HangingWrench", "WrenchJaw", "WeldingCylinder", "CylinderValve" }, item.Name) then
			item:Destroy()
		end
	end
	local root = Instance.new("Model")
	root.Name = "InteriorDetails"
	root.Parent = shop
	local parent: Model = root
	local function group(name: string)
		local model = Instance.new("Model")
		model.Name, model.Parent = name, root
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		parent = model
	end
	local function p(
		name: string,
		size: Vector3,
		x: number,
		y: number,
		z: number,
		color: Color3,
		material: Enum.Material?,
		spin: CFrame?
	): Part
		local item =
			Props.part(parent, size, frame * CFrame.new(x, y, z) * (spin or CFrame.new()), color, material or M.Metal)
		item.Name = name
		item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
		item.CastShadow = size.X * size.Y * size.Z > 0.12
		return item
	end
	local function solid(item: Part): Part
		item.CanCollide, item.CanQuery = true, true
		return item
	end
	local function rod(
		name: string,
		a: Vector3,
		b: Vector3,
		diameter: number,
		color: Color3,
		material: Enum.Material?
	): Part
		local delta = b - a
		local spin =
			CFrame.lookAt((a + b) / 2, b, if math.abs(delta.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis)
		local item = p(name, V(delta.Magnitude, diameter, diameter), 0, 0, 0, color, material)
		item.Shape = Enum.PartType.Cylinder
		item.CFrame = frame * spin * A(0, math.pi / 2, 0)
		return item
	end
	local function ring(
		name: string,
		center: Vector3,
		radius: number,
		thickness: number,
		color: Color3,
		orientation: CFrame?,
		segments: number?
	)
		local basis = CFrame.new(center) * (orientation or CFrame.new())
		local count = segments or 12
		for i = 1, count do
			local a, b = (i - 1) * math.pi * 2 / count, i * math.pi * 2 / count
			rod(
				name,
				basis * V(math.cos(a) * radius, math.sin(a) * radius, 0),
				basis * V(math.cos(b) * radius, math.sin(b) * radius, 0),
				thickness,
				color,
				if color == ROPE
					then M.Fabric
					elseif color == SILVER or color == YELLOW then M.Metal
					else M.SmoothPlastic
			)
		end
	end
	local function sign(
		name: string,
		text: string,
		x: number,
		y: number,
		z: number,
		width: number,
		height: number,
		background: Color3,
		ink: Color3?,
		spin: CFrame?
	)
		local panel = p(name, V(width, height, 0.09), x, y, z, background, M.SmoothPlastic, spin)
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.SizingMode, gui.PixelsPerStud = Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, 44
		gui.Parent = panel
		local label = Instance.new("TextLabel")
		label.Size, label.Position = UDim2.fromScale(0.9, 0.86), UDim2.fromScale(0.05, 0.07)
		label.BackgroundTransparency = 1
		label.Text, label.TextColor3 = text, ink or CREAM
		label.Font, label.TextScaled = Enum.Font.GothamBold, true
		label.Parent = gui
		return panel
	end
	local function gauge(name: string, x: number, y: number, z: number, radius: number, needleAngle: number)
		rod(name .. "Rim", V(x, y, z - 0.05), V(x, y, z + 0.1), radius * 2, SILVER)
		rod(name .. "Face", V(x, y, z - 0.07), V(x, y, z - 0.1), radius * 1.7, CREAM)
		for i = 0, 6 do
			local angle = math.rad(30 + i * 40)
			p(
				name .. "Tick",
				V(0.035, radius * 0.2, 0.025),
				x + math.sin(angle) * radius * 0.65,
				y + math.cos(angle) * radius * 0.65,
				z - 0.12,
				BLACK,
				nil,
				A(0, 0, -angle)
			)
		end
		p(name .. "Needle", V(0.04, radius * 1.1, 0.025), x, y, z - 0.14, RED, nil, A(0, 0, needleAngle))
	end
	local function hose(name: string, points: { Vector3 }, diameter: number, color: Color3)
		for i = 2, #points do
			rod(name, points[i - 1], points[i], diameter, color, M.SmoothPlastic)
		end
	end

	-- The existing bench becomes a fitted tool station with drawers, a perforated
	-- board, recognizable hand tools, vise hardware, and a repair in progress.
	group("ToolStation")
	for _, x in { 10.9, 16.1 } do
		p("BenchDrawerCabinet", V(2.1, 2.3, 2.4), x, 3.6, 9, TEAL)
		for y = 2.9, 4.4, 0.5 do
			p("BenchDrawer", V(1.94, 0.41, 0.12), x, y, 7.75, STEEL)
			p("DrawerPull", V(0.85, 0.09, 0.16), x, y + 0.02, 7.64, SILVER)
		end
	end
	p("BenchLowerShelf", V(7.2, 0.16, 2.4), 13.5, 2.55, 9, WOOD, M.WoodPlanks)
	p("BenchTimberTop", V(8.2, 0.18, 3.1), 13.5, 5.43, 9, WOOD, M.WoodPlanks)
	for _, x in { 9.3, 17.7 } do
		p("PegboardFrame", V(0.14, 4.2, 0.2), x, 7.5, 10.26, SILVER)
	end
	for _, y in { 5.42, 9.58 } do
		p("PegboardFrame", V(8.5, 0.14, 0.2), 13.5, y, 10.26, SILVER)
	end
	for x = 9.8, 17.2, 0.55 do
		for y = 5.85, 9.2, 0.55 do
			p("PegboardHole", V(0.065, 0.065, 0.018), x, y, 10.337, BLACK)
		end
	end
	for i = 1, 4 do
		local x, length = 9.7 + i * 0.7, 1 + i * 0.2
		rod("SpannerShaft", V(x, 8.75, 10.07), V(x, 8.75 - length, 10.07), 0.14, SILVER)
		for _, side in { -1, 1 } do
			p("SpannerOpenJaw", V(0.13, 0.34, 0.16), x + side * 0.18, 8.89, 10.07, SILVER, nil, A(0, 0, -side * 0.22))
		end
		ring("SpannerBoxEnd", V(x, 8.66 - length, 10.07), 0.17, 0.09, SILVER, nil, 6)
		p("ToolPeg", V(0.08, 0.08, 0.28), x, 8.87, 10.19, BLACK)
	end
	for i = 1, 3 do
		local x = 13.4 + i * 0.55
		rod("ScrewdriverShaft", V(x, 7.1, 10.03), V(x, 8.05, 10.03), 0.065, SILVER)
		rod("ScrewdriverHandle", V(x, 8.05, 10.03), V(x, 8.65, 10.03), 0.22, if i == 2 then YELLOW else RED)
	end
	p("HangingHammerHandle", V(0.14, 1.6, 0.18), 16.15, 8, 10.03, WOOD, M.Wood)
	p("HangingHammerHead", V(0.9, 0.3, 0.3), 16.15, 8.75, 10.03, SILVER)
	p("HandsawBlade", V(1.85, 0.6, 0.08), 13.65, 6.45, 10.06, SILVER, nil, A(0, 0, -0.12))
	p("HandsawHandle", V(0.55, 0.75, 0.15), 14.82, 6.53, 10.05, WOOD, M.Wood)
	for x = 12.8, 14.4, 0.18 do
		p("SawTooth", V(0.12, 0.12, 0.08), x, 6.08 - (x - 13.65) * 0.12, 10.06, SILVER, nil, A(0, 0, math.pi / 4))
	end
	rod("ViseThread", V(15.1, 5.86, 8.25), V(16.5, 5.86, 8.25), 0.14, SILVER)
	rod("ViseCrank", V(16.6, 5.47, 8.25), V(16.6, 6.25, 8.25), 0.1, BLACK)
	for i = 1, 7 do
		p("ViseScrewThread", V(0.035, 0.22, 0.22), 15.45 + i * 0.11, 5.86, 8.25, BLACK)
	end
	p("RepairTimber", V(1.75, 0.15, 0.75), 15.8, 6.4, 8.8, WOOD, M.Wood, A(0, 0.12, 0))
	p("BenchCuttingMat", V(2.5, 0.04, 1.9), 12.6, 5.55, 8.7, rgb(46, 83, 72), M.SmoothPlastic)
	for x = 11.6, 13.6, 0.4 do
		p("CuttingMatGrid", V(0.018, 0.012, 1.7), x, 5.578, 8.7, rgb(108, 137, 111))
	end
	p("BenchPlaneBody", V(0.55, 0.3, 1.1), 12.1, 5.75, 8.55, STEEL, nil, A(0, -0.3, 0))
	p("BenchPlaneGrip", V(0.15, 0.38, 0.25), 12.1, 6.03, 8.8, WOOD, M.Wood)
	rod("GlueBottle", V(10, 5.55, 9.3), V(10, 6.12, 9.3), 0.38, CREAM)
	p("GlueNozzle", V(0.12, 0.22, 0.12), 10, 6.22, 9.3, RED)
	p("FoldedShopRag", V(0.75, 0.08, 0.6), 14.6, 5.56, 9.4, rgb(120, 148, 143), M.Fabric, A(0, 0.3, 0))
	for i = 1, 5 do
		p("TimberOffcut", V(0.3, 0.13, 1.1 + i * 0.1), 11.9 + i * 0.45, 2.72, 9.1, WOOD, M.Wood, A(0, i * 0.12, 0))
	end
	sign("ToolStationLabel", "HAND TOOLS  /  RETURN AFTER USE", 13.5, 9.88, 10.18, 7.6, 0.45, TEAL)

	group("PartsStores")
	local binLabels = { "BOLTS", "CLEATS", "HINGES", "FITTINGS" }
	for level = 0, 2 do
		local shelfY = 2.3 + level * 3.5
		for i = 1, 4 do
			local x = 5 + i * 3
			sign("PartsBinLabel", binLabels[i], x, shelfY + 0.65, 16.56, 1.65, 0.38, CREAM, BLACK)
			-- Visible contents sit above the original open storage-bin rims.
			for k = 1, 3 do
				local px = x - 0.62 + k * 0.3
				if i == 1 then
					rod("StoredBolt", V(px, shelfY + 1.14, 17.1), V(px + 0.15, shelfY + 1.48, 17.65), 0.12, SILVER)
				elseif i == 2 then
					p("StoredCleat", V(0.5, 0.12, 0.2), px, shelfY + 1.36, 17.5, SILVER, nil, A(0, k * 0.35, 0))
				else
					p(
						"StoredFitting",
						V(0.3, 0.3, 0.35),
						px,
						shelfY + 1.35,
						17.4,
						if i == 3 then SILVER else RUST,
						nil,
						A(0, k * 0.4, 0.2)
					)
				end
			end
		end
	end
	for _, x in { 6, 18.7 } do
		for y = 2.8, 9.8, 0.6 do
			p("RackAdjustmentSlot", V(0.08, 0.18, 0.025), x, y, 17.23, BLACK)
		end
	end
	sign("StoresHeader", "MARINE PARTS  /  STORES", 12.3, 11, 17.45, 12, 0.85, TEAL)
	-- Spare shaft, flanged pipe sections, and a strapped service crate.
	rod("SparePropShaft", V(6.8, 10.05, 17.7), V(17.5, 10.05, 17.7), 0.18, SILVER)
	for _, x in { 7.5, 10.5, 13.5, 16.5 } do
		p("ShaftRackSaddle", V(0.35, 0.35, 1), x, 9.7, 17.65, BLACK)
	end
	solid(p("ServiceCrate", V(2.2, 1.9, 2.1), 18.9, 2.95, -9.9, WOOD, M.WoodPlanks))
	for _, x in { 18.15, 19.65 } do
		p("CrateStrapping", V(0.1, 1.94, 2.13), x, 2.95, -9.9, STEEL)
	end
	sign("CrateStamp", "MARINE\nSPARES", 18.9, 3.05, -10.98, 1.25, 0.8, WOOD, BLACK)

	group("WeldingBay")
	-- A two-bottle trolley replaces the single square placeholder cylinder.
	solid(p("WeldingCartBase", V(2.3, 0.22, 2.2), 18.35, 2.4, 12.9, STEEL, M.DiamondPlate))
	for _, x in { 17.35, 19.35 } do
		rod("WeldingCartWheel", V(x - 0.12, 2.4, 13.45), V(x + 0.12, 2.4, 13.45), 0.64, BLACK)
		rod("WeldingCartHandle", V(x, 2.5, 13.65), V(x, 6.25, 13.65), 0.14, STEEL)
	end
	rod("WeldingCartGrip", V(17.35, 6.25, 13.65), V(19.35, 6.25, 13.65), 0.16, BLACK)
	for i = 1, 2 do
		local x, height = 17.7 + (i - 1) * 1.2, if i == 1 then 3.5 else 2.9
		local top = 2.55 + height
		solid(rod("GasBottle", V(x, 2.55, 12.9), V(x, top, 12.9), 0.88, if i == 1 then TEAL else RED))
		rod("GasBottleShoulder", V(x, top, 12.9), V(x, top + 0.22, 12.9), 0.57, SILVER)
		rod("GasBottleValve", V(x, top + 0.2, 12.9), V(x, top + 0.53, 12.9), 0.16, ROPE)
		p("GasValveWheel", V(0.5, 0.08, 0.38), x, top + 0.55, 12.9, RED)
		gauge("Regulator", x, top + 0.25, 12.5, 0.22, -0.65)
		p("CylinderRetainingStrap", V(1.1, 0.16, 1.02), x, 4.7, 12.9, BLACK)
	end
	solid(p("WelderCabinet", V(1.6, 1.6, 2.1), 19, 2.98, 8.1, RED))
	p("WelderTopHandle", V(0.9, 0.15, 0.15), 19, 3.99, 8.1, BLACK)
	for i = 1, 5 do
		p("WelderVent", V(0.9, 0.07, 0.03), 19, 2.5 + i * 0.18, 7.03, BLACK)
	end
	rod("WelderDial", V(18.6, 3.42, 7.01), V(18.6, 3.42, 6.9), 0.24, BLACK)
	sign("WelderReadout", "135 A", 19.25, 3.45, 6.98, 0.5, 0.25, BLACK, YELLOW)
	ring("WeldingHoseCoil", V(19.2, 5.35, 12.05), 0.65, 0.12, BLACK)
	hose(
		"WeldingLead",
		{ V(19, 2.7, 7), V(18.5, 2.14, 6.6), V(17.7, 2.14, 7.2), V(17.7, 4.2, 9.6), V(17, 5.55, 9.5) },
		0.11,
		BLACK
	)
	p("WeldingTorchHandle", V(0.16, 0.16, 0.7), 17, 5.65, 9.3, BLACK)
	rod("WeldingTorchNozzle", V(17, 5.65, 8.95), V(16.8, 5.65, 8.65), 0.09, ROPE)
	p("WeldingMaskShell", V(0.75, 0.95, 0.5), 17.1, 6.15, 9.55, BLACK, M.SmoothPlastic, A(-0.25, 0.15, 0))
	p("WeldingMaskLens", V(0.52, 0.26, 0.04), 17.1, 6.24, 9.23, rgb(56, 94, 85), M.Glass)
	sign(
		"WeldingSafety",
		"WELDING AREA\nEYE PROTECTION REQUIRED",
		19.95,
		8.1,
		12.7,
		3.4,
		1.6,
		YELLOW,
		BLACK,
		A(0, math.pi / 2, 0)
	)

	group("MachiningAndToolCart")
	solid(p("DrillPressBase", V(2.2, 0.24, 2.3), 19, 2.15, 1.7, STEEL))
	rod("DrillPressColumn", V(19, 2.25, 2.5), V(19, 7.2, 2.5), 0.3, SILVER)
	p("DrillPressTable", V(1.9, 0.18, 1.9), 19, 4.55, 1.7, STEEL)
	for _, x in { 18.5, 19.5 } do
		p("DrillTableSlot", V(0.09, 0.02, 1.5), x, 4.65, 1.7, BLACK)
	end
	p("DrillPressHead", V(1.15, 0.85, 1.8), 19, 6.7, 1.8, TEAL)
	p("DrillBeltCover", V(1.3, 0.28, 2.35), 19, 7.24, 2.1, TEAL)
	rod("DrillMotor", V(19, 6, 2.8), V(19, 7, 2.8), 0.8, BLACK)
	rod("DrillChuck", V(19, 5.8, 1.35), V(19, 6.35, 1.35), 0.3, SILVER)
	rod("DrillBit", V(19, 4.95, 1.35), V(19, 5.8, 1.35), 0.08, BLACK)
	p("DrillWorkpiece", V(1.1, 0.12, 0.8), 19, 4.72, 1.45, WOOD, M.Wood)
	for i = 1, 3 do
		local angle = i * math.pi * 2 / 3
		rod(
			"DrillFeedHandle",
			V(18.32, 6.4, 2),
			V(18.32, 6.4 + math.sin(angle) * 0.65, 2 + math.cos(angle) * 0.65),
			0.08,
			SILVER
		)
		rod(
			"DrillFeedGrip",
			V(18.32, 6.4 + math.sin(angle) * 0.6, 2 + math.cos(angle) * 0.6),
			V(18.32, 6.4 + math.sin(angle) * 0.8, 2 + math.cos(angle) * 0.8),
			0.18,
			BLACK
		)
	end
	sign(
		"DrillPressLabel",
		"BENCH DRILL\nCLAMP WORK BEFORE DRILLING",
		19.95,
		9.1,
		2.4,
		3.9,
		1.1,
		TEAL,
		CREAM,
		A(0, math.pi / 2, 0)
	)
	solid(p("RollingToolCabinet", V(2.5, 2.1, 1.6), 14.1, 3.4, 13.2, RED))
	for _, x in { 13.1, 15.1 } do
		for _, z in { 12.6, 13.8 } do
			rod("ToolCartCastor", V(x - 0.1, 2.22, z), V(x + 0.1, 2.22, z), 0.42, BLACK)
		end
	end
	for y = 2.7, 4.1, 0.35 do
		p("ToolCartDrawer", V(2.24, 0.27, 0.1), 14.1, y, 12.35, RED)
		p("ToolCartDrawerHandle", V(1.6, 0.06, 0.1), 14.1, y + 0.03, 12.24, SILVER)
	end
	p("ToolCartRubberTop", V(2.6, 0.08, 1.7), 14.1, 4.5, 13.2, BLACK)
	for i = 1, 6 do
		rod(
			"SocketSet",
			V(13.15 + i * 0.26, 4.56, 13.5),
			V(13.15 + i * 0.26, 4.78 + i * 0.03, 13.5),
			0.15 + i * 0.014,
			SILVER
		)
	end
	rod("SocketRail", V(13.25, 4.57, 13.5), V(14.9, 4.57, 13.5), 0.08, STEEL)
	p("RatchetHandle", V(1.1, 0.09, 0.15), 14.1, 4.6, 12.9, SILVER, nil, A(0, 0.2, 0))
	rod("RatchetHead", V(14.65, 4.57, 12.8), V(14.65, 4.69, 12.8), 0.3, SILVER)

	group("CompressorAndServices")
	-- Left-rear wall equipment is tucked outboard of the basin-side walking lane.
	solid(rod("CompressorTank", V(-19, 3.05, 8.6), V(-19, 3.05, 12.1), 1.55, TEAL))
	for _, z in { 9.1, 11.6 } do
		p("CompressorFoot", V(1.7, 0.45, 0.45), -19, 2.23, z, BLACK)
	end
	p("CompressorMotor", V(0.95, 0.65, 1.3), -19, 4.12, 10.65, STEEL)
	for z = 10.1, 11.2, 0.18 do
		p("CompressorCoolingFin", V(1.1, 0.08, 0.08), -19, 4.37, z, SILVER)
	end
	gauge("AirPressure", -18.8, 4.55, 9.65, 0.3, 0.65)
	rod("AirOutlet", V(-18.8, 3.9, 9.8), V(-18.8, 4.3, 9.8), 0.13, ROPE)
	ring("AirHoseReel", V(-20, 6.7, 11.2), 0.9, 0.16, YELLOW, A(0, math.pi / 2, 0))
	ring("AirHose", V(-19.82, 6.7, 11.2), 0.65, 0.11, BLACK, A(0, math.pi / 2, 0))
	hose("AirHoseTail", { V(-19.8, 6.1, 11.2), V(-19.6, 5.2, 11.6), V(-19, 4.15, 11.8) }, 0.11, BLACK)
	-- Overhead mains, elbows, clamps, and downpipes make the shell feel serviced.
	for _, side in { -1, 1 } do
		local x = side * 19.8
		rod("ServiceAirMain", V(x, 10.65, -17), V(x, 10.65, 17.5), 0.2, TEAL)
		rod("ElectricalConduit", V(x, 11.2, -17), V(x, 11.2, 17.5), 0.1, SILVER)
		for z = -16, 16, 4 do
			p("PipeWallBracket", V(0.65, 0.1, 0.5), x, 10.48, z, STEEL)
			p("PipeClamp", V(0.1, 0.36, 0.35), x, 10.65, z, SILVER)
		end
	end
	rod("RearServiceMain", V(-19.8, 10.65, 18.5), V(19.8, 10.65, 18.5), 0.2, TEAL)
	for _, x in { -19.8, 19.8 } do
		rod("ServiceMainElbow", V(x, 10.65, 17.5), V(x, 10.65, 18.5), 0.23, TEAL)
	end
	rod("CompressorRiser", V(-19.8, 4, 9), V(-19.8, 10.65, 9), 0.17, TEAL)
	rod("AirTapDrop", V(19.8, 10.65, 5), V(19.8, 5.1, 5), 0.15, TEAL)
	ring("IsolationValve", V(-19.55, 5.3, 9), 0.32, 0.09, RED, A(0, math.pi / 2, 0), 8)
	solid(p("ElectricalCabinet", V(0.75, 3, 2.6), -19.9, 6.7, -13.7, STEEL))
	p("ElectricalDoor", V(0.07, 2.75, 2.38), -19.48, 6.7, -13.7, rgb(112, 126, 125))
	p("CabinetLatch", V(0.18, 0.7, 0.1), -19.36, 6.5, -12.95, BLACK)
	sign("ElectricalWarning", "DANGER\nHIGH VOLTAGE", -19.39, 7.1, -13.8, 1.7, 1, YELLOW, BLACK, A(0, -math.pi / 2, 0))
	rod("CabinetConduit", V(-19.9, 8.2, -13.7), V(-19.9, 11.2, -13.7), 0.14, SILVER)
	-- Rear extractor: deep housing, circular guard, hub and six pitched blades.
	p("ExtractorHousing", V(3.4, 3.1, 0.45), 0.7, 11.5, 18.7, STEEL)
	rod("ExtractorRecess", V(0.7, 11.5, 18.37), V(0.7, 11.5, 18.55), 2.7, BLACK)
	for i = 1, 6 do
		local angle = i * math.pi / 3
		p(
			"ExtractorBlade",
			V(0.44, 1.1, 0.13),
			0.7 + math.sin(angle) * 0.62,
			11.5 + math.cos(angle) * 0.62,
			18.23,
			SILVER,
			nil,
			A(0, 0, -angle + 0.35)
		)
	end
	rod("ExtractorHub", V(0.7, 11.5, 18.07), V(0.7, 11.5, 18.3), 0.46, TEAL)
	ring("ExtractorGuard", V(0.7, 11.5, 18.03), 1.34, 0.09, SILVER)
	for i = -2, 2 do
		p("ExtractorGuardBar", V(2.4, 0.035, 0.035), 0.7, 11.5 + i * 0.37, 17.96, SILVER)
	end

	group("TimberAndRigging")
	-- Vertical wall racks keep the narrow west catwalk usable.
	for _, z in { -7, 3.6 } do
		p("TimberRackUpright", V(0.3, 6, 0.3), -20, 5, z, STEEL)
		for _, y in { 3, 5.25, 7.5 } do
			p("TimberRackArm", V(1.7, 0.16, 0.3), -19.3, y, z, STEEL)
			p("TimberRackLip", V(0.12, 0.35, 0.3), -18.5, y + 0.16, z, STEEL)
		end
	end
	for level = 0, 2 do
		for i = 1, 3 do
			p(
				"SeasonedBoatTimber",
				V(0.36, 0.22, 10.5 - i * 0.5),
				-19.85 + i * 0.43,
				3.2 + level * 2.25,
				-1.7 + i * 0.2,
				if i == 2 then rgb(176, 139, 86) else WOOD,
				M.Wood
			)
		end
	end
	sign(
		"TimberRackLabel",
		"SEASONED OAK  /  HULL REPAIRS",
		-19.98,
		9,
		-1.5,
		6.8,
		0.65,
		TEAL,
		CREAM,
		A(0, -math.pi / 2, 0)
	)
	for i = 1, 3 do
		local x = -11.8 + (i - 1) * 2.4
		p("OarRackHook", V(0.55, 0.18, 0.65), x, 5.25, 18.5, STEEL)
		rod("SpareOarShaft", V(x, 3.2, 18.3), V(x, 9, 18.3), 0.16, WOOD, M.Wood)
		p("SpareOarBlade", V(0.65, 1.65, 0.16), x, 9.45, 18.3, CREAM, M.Wood)
		p("OarBladePaint", V(0.67, 0.3, 0.18), x, 9.8, 18.3, TEAL)
	end
	for i = 1, 2 do
		local x = -3.6 + (i - 1) * 2.1
		p("RopeHanger", V(0.8, 0.18, 0.65), x, 6.8, 18.45, STEEL)
		for layer = 1, 3 do
			ring("HangingMooringRope", V(x, 5.9, 18.1 - layer * 0.11), 0.78 - layer * 0.09, 0.12, ROPE)
		end
		hose("RopeLooseEnd", { V(x + 0.3, 5.2, 17.85), V(x + 0.2, 4.5, 17.85), V(x + 0.45, 4.2, 17.85) }, 0.1, ROPE)
	end
	solid(p("RiggingChest", V(3.5, 1.65, 2.1), -17.7, 2.83, 16.8, WOOD, M.WoodPlanks))
	p("ChestLid", V(3.65, 0.15, 2.22), -17.7, 3.73, 16.8, WOOD, M.Wood)
	for _, x in { -18.9, -16.5 } do
		p("ChestIronBand", V(0.16, 1.7, 2.14), x, 2.85, 16.8, STEEL)
	end
	sign("RiggingChestLabel", "RIGGING", -17.7, 3, 15.7, 1.8, 0.5, STEEL)
	-- A spare propeller is a workshop landmark, mounted above the stores.
	rod("PropellerDisplayHub", V(19.8, 7.1, -2), V(19.3, 7.1, -2), 0.65, ROPE)
	for i = 1, 3 do
		local angle = i * math.pi * 2 / 3
		p(
			"SparePropellerBlade",
			V(0.14, 1.55, 0.72),
			19.38,
			7.1 + math.cos(angle) * 0.8,
			-2 + math.sin(angle) * 0.8,
			ROPE,
			nil,
			A(angle, 0, 0)
		)
	end
	sign(
		"PropellerLabel",
		"RECONDITIONED\nMARINE PROPELLERS",
		19.9,
		9.2,
		-2,
		4.4,
		0.9,
		TEAL,
		CREAM,
		A(0, math.pi / 2, 0)
	)

	group("ShipwrightOffice")
	-- A little planning desk against the front wall, facing into the workshop.
	solid(p("PlanningDesk", V(5, 0.26, 2.6), 16.3, 4.7, -17.3, WOOD, M.WoodPlanks))
	for _, x in { 14.15, 18.45 } do
		p("PlanningDeskLeg", V(0.25, 2.6, 2.2), x, 3.3, -17.3, STEEL)
	end
	p("DeskDrawer", V(2.2, 0.7, 2.2), 17.5, 4.16, -17.3, TEAL)
	p("DeskDrawerPull", V(0.8, 0.1, 0.15), 17.5, 4.18, -16.12, SILVER)
	p("BlueprintSheet", V(2.6, 0.025, 1.65), 15.7, 4.85, -17.2, rgb(54, 95, 128), M.SmoothPlastic)
	for _, side in { -1, 1 } do
		hose("BlueprintHullLines", {
			V(15.7, 4.87, -17.9),
			V(15.7 + side * 0.65, 4.87, -17.55),
			V(15.7 + side * 0.75, 4.87, -16.65),
			V(15.7, 4.87, -16.5),
		}, 0.025, CREAM)
	end
	for z = -17.6, -16.7, 0.3 do
		p("BlueprintFrameLines", V(1.15, 0.012, 0.02), 15.7, 4.88, z, CREAM)
	end
	for _, z in { -18.03, -16.4 } do
		rod("BlueprintRolledEdge", V(14.4, 4.9, z), V(17, 4.9, z), 0.12, CREAM)
	end
	p("DeskLedger", V(0.9, 0.14, 1.15), 18.05, 4.91, -17.4, BLACK, M.Fabric, A(0, -0.2, 0))
	rod("DeskPencil", V(16.8, 4.91, -16.55), V(17.45, 4.91, -16.9), 0.045, YELLOW)
	rod("EnamelMug", V(18.15, 4.86, -16.55), V(18.15, 5.25, -16.55), 0.38, CREAM)
	rod("MugCoffee", V(18.15, 5.252, -16.55), V(18.15, 5.27, -16.55), 0.3, rgb(63, 42, 30))
	ring("MugHandle", V(18.43, 5.06, -16.55), 0.14, 0.065, CREAM, nil, 8)
	-- Noticeboard on the inward-facing side of the front wall.
	p("JobBoardFrame", V(6.5, 3.8, 0.18), 14.8, 8, -18.9, WOOD, M.Wood)
	p("JobBoardCork", V(6.2, 3.5, 0.08), 14.8, 8, -18.76, rgb(127, 99, 66), M.Wood)
	for i, entry in
		{
			"JOB 014\nHULL RESEAL\nIN PROGRESS",
			"JOB 015\nENGINE SERVICE\nAWAITING PARTS",
			"TIDE TABLE\nCHECK BEFORE\nLAUNCH",
		}
	do
		local x = 12.65 + i * 1.1
		sign("PinnedJobSheet", entry, x, 8, -18.66, 0.98, 1.8, CREAM, BLACK, A(0, math.pi, 0))
		p("NoticeboardPin", V(0.09, 0.09, 0.06), x, 8.77, -18.55, RED)
	end
	sign("JobBoardHeader", "SHIPWRIGHT  /  WORK ORDERS", 14.8, 9.39, -18.64, 5.6, 0.5, TEAL, CREAM, A(0, math.pi, 0))
	-- Counter detail stays behind its visitor edge and leaves the NPC visible.
	p("CounterLedger", V(1.1, 0.1, 0.85), 10.2, 4.84, -3.9, CREAM, M.SmoothPlastic, A(0, 0.15, 0))
	p("CounterPen", V(0.7, 0.05, 0.05), 10.3, 4.91, -3.95, BLACK, nil, A(0, 0.3, 0))
	rod("CounterBellBase", V(14.5, 4.79, -4.1), V(14.5, 4.88, -4.1), 0.68, BLACK)
	rod("CounterBell", V(14.5, 4.88, -4.1), V(14.5, 5.15, -4.1), 0.48, ROPE)
	rod("BellPlunger", V(14.5, 5.15, -4.1), V(14.5, 5.27, -4.1), 0.13, BLACK)
	sign(
		"CounterOpeningHours",
		"REPAIRS & BOAT SALES\nOPEN DAILY",
		10.5,
		11.1,
		-18.85,
		5.3,
		1.3,
		TEAL,
		CREAM,
		A(0, math.pi, 0)
	)

	group("SafetyStation")
	-- Safety equipment is concentrated on the entry wall, clear of the stairs.
	p("SafetyStationBackboard", V(6.2, 5.7, 0.18), -14, 6.8, -18.85, rgb(221, 210, 174))
	sign("SafetyStationHeader", "WORKSHOP SAFETY", -14, 9.15, -18.65, 5.8, 0.65, TEAL, CREAM, A(0, math.pi, 0))
	p("FirstAidCase", V(1.65, 1.3, 0.4), -12.2, 7.4, -18.42, rgb(57, 119, 87))
	p("FirstAidCross", V(0.9, 0.24, 0.04), -12.2, 7.4, -18.19, CREAM)
	p("FirstAidCross", V(0.24, 0.9, 0.04), -12.2, 7.4, -18.18, CREAM)
	rod("FireExtinguisher", V(-15.7, 4.25, -18.15), V(-15.7, 6.1, -18.15), 0.65, RED)
	p("ExtinguisherLever", V(0.5, 0.12, 0.18), -15.7, 6.35, -18.15, BLACK)
	rod("ExtinguisherNeck", V(-15.7, 6.1, -18.15), V(-15.7, 6.35, -18.15), 0.2, SILVER)
	p("ExtinguisherLabel", V(0.46, 0.65, 0.045), -15.7, 5.25, -17.81, CREAM)
	hose("ExtinguisherHose", { V(-15.5, 6.27, -18.1), V(-15.12, 6.05, -18.1), V(-15.05, 4.9, -18.1) }, 0.09, BLACK)
	sign("ExtinguisherSign", "FIRE", -15.7, 7.4, -18.37, 1.35, 0.55, RED, CREAM, A(0, math.pi, 0))
	sign(
		"SafetyRules",
		"WEAR EYE PROTECTION\nKEEP WALKWAYS CLEAR\nNO SMOKING",
		-13.1,
		5.4,
		-18.36,
		2.6,
		1.55,
		STEEL,
		CREAM,
		A(0, math.pi, 0)
	)
	-- Orange life ring is assembled as an open ring, with four cream bindings.
	ring("Lifebuoy", V(-9, 8, -18.35), 1, 0.28, rgb(219, 105, 45))
	for i = 0, 3 do
		local angle = i * math.pi / 2
		p(
			"LifebuoyBinding",
			V(0.37, 0.32, 0.33),
			-9 + math.sin(angle),
			8 + math.cos(angle),
			-18.35,
			CREAM,
			nil,
			A(0, 0, -angle)
		)
	end
	ring("LifebuoyGrabRope", V(-9, 8, -18.35), 1.31, 0.065, ROPE)
	sign("LifebuoyLabel", "RESCUE EQUIPMENT", -9, 6.2, -18.54, 3, 0.5, TEAL, CREAM, A(0, math.pi, 0))
	-- Recessed-looking mat and aisle markings sit on top of the actual floor.
	p("EntranceRubberMat", V(9, 0.025, 3), 0, 2.02, -17, BLACK, M.SmoothPlastic)
	for x = -4, 4, 0.5 do
		p("EntranceMatRib", V(0.08, 0.014, 2.7), x, 2.04, -17, rgb(66, 70, 66))
	end

	group("CraneAndLightingDetails")
	for _, x in { -15, 2 } do
		for _, y in { 12.02, 12.62 } do
			p("CraneRunwayFlange", V(0.85, 0.12, 30), x, y, 0, YELLOW)
		end
		for _, z in { -12, 0, 12 } do
			p("RunwaySupportPlate", V(1.2, 0.16, 1.1), x, 11.8, z, STEEL)
		end
		for _, z in { 2.35, 3.65 } do
			rod("GantryEndTruckWheel", V(x - 0.22, 12.95, z), V(x + 0.22, 12.95, z), 0.56, BLACK)
		end
	end
	for _, y in { 12.62, 13.62 } do
		p("GantryBeamFlange", V(19, 0.12, 1.45), -6.5, y, 3, YELLOW)
	end
	for x = -14, 1, 1.5 do
		p("CraneBeamBolt", V(0.16, 0.16, 0.07), x, 13.25, 2.4, BLACK)
	end
	hose(
		"HoistPowerCable",
		{ V(1.8, 13.2, -14), V(1.8, 13.05, -9), V(1.8, 12.7, -7), V(1.8, 13.05, -5), V(1.8, 13.05, 2), V(-6, 13.05, 3) },
		0.1,
		BLACK
	)
	rod("CranePendantCable", V(1, 12.3, 3), V(1, 5.7, 3), 0.08, BLACK)
	p("CranePendant", V(0.5, 1.25, 0.35), 1, 5.12, 3, YELLOW)
	for i = 1, 3 do
		rod("PendantButton", V(1, 5.55 - i * 0.3, 2.8), V(1, 5.55 - i * 0.3, 2.75), 0.16, if i == 1 then RED else BLACK)
	end
	-- Diffusers and wire hangers enrich the existing lights without adding lights.
	for _, x in { -15.5, 13 } do
		for _, z in { -10, 8 } do
			for _, dx in { -1.15, 1.15 } do
				rod("LightSuspension", V(x + dx, 11.95, z), V(x + dx, 13.8, z), 0.045, BLACK)
			end
			for dx = -1.3, 1.3, 0.65 do
				p("LightGuard", V(0.055, 0.24, 1.1), x + dx, 11.7, z, STEEL)
			end
		end
	end
	for _, x in { -20, 20 } do
		for _, z in { -18.5, 0, 18.5 } do
			p("ColumnGusset", V(1.5, 1.1, 0.16), x, 13.6, z, STEEL)
			for _, dx in { -0.45, 0.45 } do
				p("GussetRivet", V(0.12, 0.12, 0.1), x + dx, 13.6, z - 0.14, SILVER)
			end
		end
	end

	group("FloorAndBasinDetails")
	-- Seams and patches sit above the walkway only; the repair basin stays hollow.
	for z = -15, 15, 6 do
		p("ConcreteExpansionJoint", V(20, 0.012, 0.035), 10.5, 2.013, z, rgb(101, 110, 105))
		p("ConcreteExpansionJoint", V(6.5, 0.012, 0.035), -17.5, 2.013, z, rgb(101, 110, 105))
	end
	for _, x in { 2.2, 7.6 } do
		for z = -12, 13, 4 do
			p("AislePaint", V(0.12, 0.018, 2.2), x, 2.026, z, YELLOW)
		end
	end
	for i, spec in { V(17.8, 0, 7), V(-18.8, 0, 11.2), V(14, 0, 10.8), V(-16.7, 0, 16) } do
		for k = 1, 3 do
			local stain = p(
				"WorkshopOilWear",
				V(0.5 + k * 0.4, 0.009, 0.35 + k * 0.25),
				spec.X + k * 0.18,
				2.022 + k * 0.002,
				spec.Z,
				rgb(76, 82, 71),
				M.SmoothPlastic,
				A(0, i * 0.7 + k * 0.2, 0)
			)
			stain.Transparency = 0.65
		end
	end
	for i = 1, 9 do
		p(
			"WoodShaving",
			V(0.08, 0.03, 0.25 + i % 3 * 0.1),
			11 + (i * 0.57) % 5.5,
			2.04,
			7.05 + (i * 0.37) % 0.4,
			WOOD,
			M.Wood,
			A(0, i * 0.8, 0)
		)
	end
	-- Basin wall service pipe, flanges, drain sump, and repair identification.
	rod("BasinDrainPipe", V(-12.95, 0.85, -7.5), V(-12.95, 0.85, 10.5), 0.18, RUST)
	for z = -7, 9, 4 do
		rod("BasinPipeFlange", V(-12.95, 0.85, z - 0.07), V(-12.95, 0.85, z + 0.07), 0.35, STEEL)
	end
	p("BasinSumpGrate", V(1.6, 0.05, 1.5), -11.2, 0.34, 10, BLACK, M.DiamondPlate)
	for x = -11.8, -10.6, 0.2 do
		p("SumpGrateBar", V(0.07, 0.03, 1.3), x, 0.38, 10, SILVER)
	end
	sign("RepairBayNumber", "01\nHULL REPAIR", -7, 10.9, 18.4, 5, 1.5, TEAL)
	sign("BasinWarning", "CAUTION  /  OPEN REPAIR PIT", -7, 2.015, -10.9, 7, 0.8, YELLOW, BLACK, A(math.pi / 2, 0, 0))
	-- Commit after construction so an interrupted build is repaired on next ensure.
	root:SetAttribute("DetailVersion", VERSION)
end

return Interior
