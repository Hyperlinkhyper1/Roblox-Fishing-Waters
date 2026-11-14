-- A two-cell workshop bench for the owner's base. The origin is on the floor at
-- its centre and +Z is the working side. Tools and drawers are dressing; the
-- office PC is opened up here (PcWorkshopService finds the bench by BenchFrame,
-- and its prompts are made on the owner's client).
local Workbench = {}

Workbench.WIDTH = 8.8
Workbench.DEPTH = 4.3
Workbench.HEIGHT = 6.2

local rgb = Color3.fromRGB
local M = Enum.Material
local WOOD = rgb(151, 111, 69)
local PALE_WOOD = rgb(172, 133, 87)
local DARK_WOOD = rgb(100, 71, 46)
local FRAME = rgb(56, 78, 75)
local EDGE = rgb(42, 52, 52)
local STEEL = rgb(144, 151, 149)
local DARK_STEEL = rgb(73, 78, 78)
local BRASS = rgb(162, 132, 74)
local RED = rgb(151, 53, 39)
local RUBBER = rgb(38, 39, 37)
local UP = CFrame.Angles(0, 0, math.pi / 2)
local FRONT = CFrame.Angles(0, math.pi / 2, 0)

local function group(parent: Instance, name: string): Model
	local result = Instance.new("Model")
	result.Name = name
	result.Parent = parent
	return result
end

function Workbench.build(parent: Instance, frame: CFrame): Model
	local root = Instance.new("Model")
	root.Name = "Workbench"
	root:SetAttribute("ModelVersion", 1)
	root:SetAttribute("BenchFrame", frame)
	local function piece(
		folder: Instance,
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material?,
		solid: boolean?,
		shape: Enum.PartType?
	): Part
		local result = Instance.new("Part")
		result.Name = name
		result.Size = size
		result.CFrame = frame * offset
		result.Color = color
		result.Material = material or M.Metal
		result.Shape = shape or Enum.PartType.Block
		result.Anchored = true
		result.CanCollide = solid == true
		result.CanQuery = solid == true
		result.CanTouch = false
		result.CastShadow = solid == true or math.max(size.X, size.Y, size.Z) >= 0.7
		result.TopSurface = Enum.SurfaceType.Smooth
		result.BottomSurface = Enum.SurfaceType.Smooth
		result.Parent = folder
		return result
	end
	local function box(folder: Instance, name: string, size: Vector3, x: number, y: number, z: number, color: Color3, material: Enum.Material?, solid: boolean?): Part
		return piece(folder, name, size, CFrame.new(x, y, z), color, material, solid)
	end
	local function bolt(folder: Instance, x: number, y: number, z: number)
		piece(folder, "BoltHead", Vector3.new(0.035, 0.1, 0.1), CFrame.new(x, y, z) * FRONT, STEEL, M.Metal, false, Enum.PartType.Cylinder)
	end

	local frameParts = group(root, "SteelFrame")
	for _, x in { -3.8, 3.8 } do
		for _, z in { -1.3, 1.3 } do
			box(frameParts, "FootPlate", Vector3.new(0.52, 0.08, 0.52), x, 0.04, z, EDGE, M.Metal, true)
			box(frameParts, "Leg", Vector3.new(0.27, 3.0, 0.27), x, 1.58, z, FRAME, M.Metal, true)
			box(frameParts, "LegCollar", Vector3.new(0.31, 0.16, 0.31), x, 0.22, z, EDGE)
		end
		for _, y in { 0.58, 2.95 } do
			box(frameParts, "EndRail", Vector3.new(0.24, 0.24, 2.7), x, y, 0, FRAME, M.Metal, true)
		end
		piece(frameParts, "EndBrace", Vector3.new(0.12, 2.9, 0.1), CFrame.new(x, 1.7, 0) * CFrame.Angles(0.87, 0, 0), DARK_STEEL)
	end
	for _, z in { -1.3, 1.3 } do
		box(frameParts, "TopApron", Vector3.new(7.6, 0.38, 0.18), 0, 2.96, z, FRAME, M.Metal, true)
		box(frameParts, "ShelfRail", Vector3.new(7.6, 0.2, 0.16), 0, 0.58, z, FRAME, M.Metal, true)
		for _, x in { -3.55, 3.55 } do
			bolt(frameParts, x, 3.0, z + 0.105)
		end
	end

	local timber = group(root, "TimberTop")
	for index = 0, 4 do
		box(timber, "TopPlank", Vector3.new(8.6, 0.3, 0.62), 0, 3.2, -1.12 + index * 0.64, if index % 2 == 0 then WOOD else PALE_WOOD, M.Wood, true)
		for _, x in { -3.8, 3.8 } do
			piece(timber, "RecessedScrew", Vector3.new(0.014, 0.075, 0.075), CFrame.new(x, 3.356, -1.12 + index * 0.64) * UP, DARK_STEEL, M.Metal, false, Enum.PartType.Cylinder)
		end
	end
	box(timber, "FrontEdge", Vector3.new(8.6, 0.32, 0.12), 0, 3.2, 1.8, DARK_WOOD, M.Wood)
	for index = 1, 7 do
		piece(timber, "WornGrain", Vector3.new(0.5 + (index % 3) * 0.23, 0.008, 0.018), CFrame.new(-3.2 + index * 0.82, 3.354, 0.2 + (index % 3) * 0.4) * CFrame.Angles(0, 0.08 * (index % 2), 0), DARK_WOOD, M.Wood)
	end

	local storage = group(root, "Storage")
	for index = 0, 3 do
		box(storage, "ShelfBoard", Vector3.new(7.3, 0.12, 0.57), 0, 0.75, -0.9 + index * 0.6, WOOD, M.Wood, true)
	end
	box(storage, "DrawerCabinet", Vector3.new(2.25, 1.35, 2.35), -2.5, 2.27, 0, EDGE, M.Metal, true)
	for index = 0, 2 do
		local y = 2.71 - index * 0.43
		box(storage, "DrawerFront", Vector3.new(2.13, 0.37, 0.09), -2.5, y, 1.22, FRAME)
		for _, x in { -2.84, -2.16 } do
			box(storage, "HandleMount", Vector3.new(0.07, 0.1, 0.1), x, y, 1.31, STEEL)
		end
		box(storage, "DrawerPull", Vector3.new(0.78, 0.07, 0.07), -2.5, y, 1.39, STEEL)
		box(storage, "LabelHolder", Vector3.new(0.3, 0.12, 0.025), -3.27, y, 1.28, BRASS)
	end
	-- Spare timber and a closed, banded toolbox on the lower shelf.
	for index = 0, 2 do
		piece(storage, "SpareBoard", Vector3.new(3.55 - index * 0.18, 0.14, 0.58), CFrame.new(1.55, 0.88 + index * 0.15, 0.2) * CFrame.Angles(0, (index - 1) * 0.035, 0), if index == 1 then PALE_WOOD else DARK_WOOD, M.Wood)
	end
	box(storage, "Toolbox", Vector3.new(1.9, 0.45, 1.15), -2.45, 1.035, 0.15, RED)
	box(storage, "ToolboxLid", Vector3.new(1.96, 0.12, 1.2), -2.45, 1.32, 0.15, RED)
	for _, x in { -3.0, -1.9 } do
		box(storage, "ToolboxClasp", Vector3.new(0.12, 0.25, 0.04), x, 1.25, 0.75, BRASS)
	end
	box(storage, "ToolboxHandle", Vector3.new(0.65, 0.06, 0.1), -2.45, 1.52, 0.15, RUBBER)
	for _, x in { -2.75, -2.15 } do
		box(storage, "HandleEnd", Vector3.new(0.06, 0.15, 0.1), x, 1.45, 0.15, DARK_STEEL)
	end

	local board = group(root, "ToolBoard")
	box(board, "Backboard", Vector3.new(8.15, 2.55, 0.14), 0, 4.78, -1.78, DARK_WOOD, M.Wood, true)
	for _, x in { -4.18, 4.18 } do
		box(board, "BackboardUpright", Vector3.new(0.17, 3.04, 0.25), x, 4.68, -1.78, FRAME, M.Metal, true)
	end
	for _, y in { 3.5, 6.08 } do
		box(board, "BackboardRim", Vector3.new(8.35, 0.14, 0.22), 0, y, -1.78, FRAME)
	end
	for column = 0, 10 do
		for _, y in { 3.84, 5.7 } do
			piece(board, "PegHole", Vector3.new(0.008, 0.065, 0.065), CFrame.new(-3.65 + column * 0.73, y, -1.704) * FRONT, EDGE, M.SmoothPlastic, false, Enum.PartType.Cylinder)
		end
	end
	for _, x in { -3.2, -1.6, 0, 1.7, 3.25 } do
		box(board, "ToolPeg", Vector3.new(0.065, 0.065, 0.3), x, 5.48, -1.55, STEEL)
	end
	-- Hammer and two screwdrivers, hanging clear of the board.
	box(board, "HammerHandle", Vector3.new(0.16, 1.25, 0.18), -3.2, 4.7, -1.48, WOOD, M.Wood)
	box(board, "HammerHead", Vector3.new(0.8, 0.29, 0.27), -3.2, 5.34, -1.48, DARK_STEEL)
	box(board, "HammerFace", Vector3.new(0.13, 0.36, 0.34), -3.63, 5.34, -1.48, STEEL)
	for index, x in { -2.0, -1.45 } do
		box(board, "ScrewdriverShaft", Vector3.new(0.055, 0.7, 0.055), x, 5.1, -1.48, STEEL)
		box(board, "ScrewdriverGrip", Vector3.new(0.19, 0.5, 0.18), x, 4.52, -1.48, if index == 1 then RED else RUBBER, M.SmoothPlastic)
		box(board, "GripStripe", Vector3.new(0.05, 0.34, 0.015), x, 4.52, -1.382, DARK_STEEL)
	end
	-- Open-ended spanner with a visibly open jaw.
	box(board, "SpannerShaft", Vector3.new(0.17, 1.16, 0.09), 0, 4.8, -1.48, STEEL)
	box(board, "SpannerShoulder", Vector3.new(0.45, 0.16, 0.1), 0, 5.35, -1.48, STEEL)
	for _, x in { -0.19, 0.19 } do
		box(board, "SpannerJaw", Vector3.new(0.11, 0.25, 0.1), x, 5.52, -1.48, STEEL)
	end
	-- Small saw: exposed teeth below the steel blade, timber handle on the right.
	box(board, "SawBlade", Vector3.new(1.45, 0.5, 0.065), 1.32, 4.86, -1.47, STEEL)
	for index = 0, 5 do
		piece(board, "SawTooth", Vector3.new(0.12, 0.12, 0.06), CFrame.new(0.72 + index * 0.22, 4.58, -1.47) * CFrame.Angles(0, 0, math.pi / 4), STEEL)
	end
	box(board, "SawHandleTop", Vector3.new(0.6, 0.13, 0.16), 2.18, 5.13, -1.47, WOOD, M.Wood)
	box(board, "SawHandleBottom", Vector3.new(0.6, 0.13, 0.16), 2.18, 4.62, -1.47, WOOD, M.Wood)
	box(board, "SawHandleGrip", Vector3.new(0.14, 0.46, 0.16), 2.45, 4.88, -1.47, WOOD, M.Wood)
	box(board, "SquareLongEdge", Vector3.new(0.13, 1.34, 0.08), 3.18, 4.88, -1.47, STEEL)
	box(board, "SquareStock", Vector3.new(0.7, 0.22, 0.12), 3.46, 4.28, -1.47, DARK_STEEL)

	local vise = group(root, "BenchVise")
	box(vise, "MountingPlate", Vector3.new(1.0, 0.12, 0.92), 2.95, 3.41, 1.14, DARK_STEEL)
	box(vise, "ViseBody", Vector3.new(0.64, 0.42, 0.72), 2.95, 3.66, 1.18, FRAME)
	box(vise, "SlideRail", Vector3.new(0.32, 0.18, 1.3), 2.95, 3.65, 1.4, STEEL)
	for _, z in { 0.98, 1.69 } do
		box(vise, "JawCasting", Vector3.new(0.98, 0.36, 0.19), 2.95, 3.99, z, FRAME)
		box(vise, "JawPlate", Vector3.new(0.94, 0.19, 0.035), 2.95, 4.06, z + (if z < 1.3 then 0.11 else -0.11), STEEL, M.DiamondPlate)
	end
	piece(vise, "LeadScrew", Vector3.new(0.6, 0.16, 0.16), CFrame.new(2.95, 3.68, 1.78) * FRONT, DARK_STEEL, M.Metal, false, Enum.PartType.Cylinder)
	piece(vise, "ScrewHub", Vector3.new(0.13, 0.28, 0.28), CFrame.new(2.95, 3.68, 2.0) * FRONT, STEEL, M.Metal, false, Enum.PartType.Cylinder)
	box(vise, "SlidingHandle", Vector3.new(0.065, 0.88, 0.065), 2.95, 3.57, 2.0, STEEL)
	for _, y in { 3.11, 4.03 } do
		piece(vise, "HandleStop", Vector3.new(0.12, 0.12, 0.12), CFrame.new(2.95, y, 2.0), DARK_STEEL, M.Metal, false, Enum.PartType.Ball)
	end
	box(vise, "ClampedOffcut", Vector3.new(0.42, 0.5, 0.4), 2.95, 4.18, 1.34, PALE_WOOD, M.Wood)

	local clutter = group(root, "TabletopTools")
	box(clutter, "CuttingMat", Vector3.new(2.15, 0.018, 1.2), -0.15, 3.365, 0.53, rgb(60, 91, 75), M.Fabric)
	for index = 0, 3 do
		box(clutter, "MatGrid", Vector3.new(2.0, 0.005, 0.012), -0.15, 3.377, 0.08 + index * 0.3, rgb(106, 132, 106), M.SmoothPlastic)
	end
	local ruler = CFrame.new(-0.1, 3.4, 0.25) * CFrame.Angles(0, -0.22, 0)
	piece(clutter, "Ruler", Vector3.new(1.5, 0.035, 0.14), ruler, STEEL)
	for index = 0, 6 do
		piece(clutter, "RulerMark", Vector3.new(0.012, 0.006, 0.07), ruler * CFrame.new(-0.6 + index * 0.19, 0.02, 0), EDGE, M.SmoothPlastic)
	end
	piece(clutter, "Pencil", Vector3.new(0.8, 0.055, 0.055), CFrame.new(-0.15, 3.41, 0.82) * CFrame.Angles(0, 0.2, 0), rgb(214, 166, 55), M.Wood)
	box(clutter, "PartsTray", Vector3.new(1.1, 0.08, 0.7), -2.65, 3.4, 0.35, DARK_STEEL)
	for _, z in { 0.02, 0.68 } do
		box(clutter, "TrayRim", Vector3.new(1.1, 0.15, 0.04), -2.65, 3.49, z, STEEL)
	end
	for _, x in { -3.18, -2.12 } do
		box(clutter, "TrayRim", Vector3.new(0.04, 0.15, 0.62), x, 3.49, 0.35, STEEL)
	end
	for index = 0, 3 do
		piece(clutter, "SpareBolt", Vector3.new(0.25, 0.055, 0.055), CFrame.new(-2.95 + index * 0.2, 3.49, 0.22 + (index % 2) * 0.2) * CFrame.Angles(0, index * 0.5, 0), STEEL)
	end
	box(clutter, "Sandpaper", Vector3.new(0.7, 0.025, 0.5), 1.48, 3.37, 0.4, rgb(160, 110, 62), M.Sand)
	box(clutter, "SandingBlock", Vector3.new(0.4, 0.18, 0.24), 1.5, 3.47, 0.4, DARK_WOOD, M.Wood)
	root.Parent = parent
	return root
end

return Workbench
