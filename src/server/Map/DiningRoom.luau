-- The Restaurant path's dining room: an extension built onto the back of a base
-- house, behind the processing room, plus the dining tables placed inside it.
-- Positions are house-local studs (BaseHouse "HouseFrame"; floor y=0.16, rear wall z=-15).
local Props = require(script.Parent.Props)

local DiningRoom = {}
local rgb = Color3.fromRGB
local M = Enum.Material
local PLASTER = rgb(236, 226, 204)
local STONE = rgb(168, 156, 130)
local WOOD = rgb(124, 88, 55)
local DARK_WOOD = rgb(67, 48, 35)
local IRON = rgb(43, 53, 57)
local CREAM = rgb(247, 235, 204)
local TERRACOTTA = rgb(164, 75, 46)
local LINEN = rgb(244, 240, 228)

local LEFT, RIGHT = -23, -5.5
local BACK, FRONT = -30, -15.33
local HEIGHT = 9
DiningRoom.VERSION = 1
-- Diners arrive along the quay and walk in through this doorway (house-local).
DiningRoom.DOOR = Vector3.new(-13, 0.16, -30)
DiningRoom.ARRIVAL = Vector3.new(-13, 0.16, -32.4)
DiningRoom.INSIDE = Vector3.new(-13, 0.16, -27.4)
local DOOR_WIDTH = 5

function DiningRoom.build(parent: Instance, frame: CFrame): Model
	local room = Instance.new("Model")
	room.Name = "Dining"
	room:SetAttribute("RoomType", "Dining")
	room:SetAttribute("LayoutVersion", DiningRoom.VERSION)
	local function block(name: string, size: Vector3, x: number, y: number, z: number, color: Color3, material: Enum.Material?, decorative: boolean?): Part
		local piece = Props.part(room, size, frame * CFrame.new(x, y, z), color, material)
		piece.Name = name
		if decorative then
			piece.CanCollide, piece.CanQuery = false, false
		end
		return piece
	end
	local width, depth = RIGHT - LEFT, FRONT - BACK
	local cx, cz = (LEFT + RIGHT) / 2, (BACK + FRONT) / 2
	block("DiningFloor", Vector3.new(width, 0.16, depth), cx, 0.08, cz, rgb(150, 104, 66), M.WoodPlanks)
	block("Plinth", Vector3.new(width + 0.4, 0.5, 0.8), cx, 0.25, BACK - 0.2, STONE, M.Slate)

	-- A side wall along z with a window opening between zA and zB.
	local function sideWall(x: number, name: string)
		local zA, zB = -25.5, -19
		block(name, Vector3.new(0.6, HEIGHT, zA - BACK), x, HEIGHT / 2, (BACK + zA) / 2, PLASTER, M.Plaster)
		block(name, Vector3.new(0.6, HEIGHT, FRONT - zB), x, HEIGHT / 2, (zB + FRONT) / 2, PLASTER, M.Plaster)
		block(name .. "Sill", Vector3.new(0.6, 3, zB - zA), x, 1.5, (zA + zB) / 2, PLASTER, M.Plaster)
		block(name .. "Lintel", Vector3.new(0.6, 2, zB - zA), x, HEIGHT - 1, (zA + zB) / 2, PLASTER, M.Plaster)
		local glass = block(name .. "Glass", Vector3.new(0.12, 4, zB - zA), x, 5, (zA + zB) / 2, rgb(105, 165, 175), M.SmoothPlastic, true)
		glass.Transparency = 0.68
		for _, y in { 3, 5, 7 } do
			block(name .. "Rail", Vector3.new(0.3, 0.16, zB - zA), x, y, (zA + zB) / 2, CREAM, M.Wood, true)
		end
		block(name .. "Mullion", Vector3.new(0.3, 4, 0.16), x, 5, (zA + zB) / 2, CREAM, M.Wood, true)
	end
	sideWall(LEFT, "DiningWestWall")
	sideWall(RIGHT, "DiningEastWall")
	-- Water-side wall with the guests' doorway.
	local doorLeft, doorRight = DiningRoom.DOOR.X - DOOR_WIDTH / 2, DiningRoom.DOOR.X + DOOR_WIDTH / 2
	block("DiningBackWall", Vector3.new(doorLeft - LEFT + 0.3, HEIGHT, 0.6), (LEFT - 0.3 + doorLeft) / 2, HEIGHT / 2, BACK + 0.3, PLASTER, M.Plaster)
	block("DiningBackWall", Vector3.new(RIGHT + 0.3 - doorRight, HEIGHT, 0.6), (doorRight + RIGHT + 0.3) / 2, HEIGHT / 2, BACK + 0.3, PLASTER, M.Plaster)
	block("DoorLintel", Vector3.new(DOOR_WIDTH, HEIGHT - 7.6, 0.6), DiningRoom.DOOR.X, (HEIGHT + 7.6) / 2, BACK + 0.3, PLASTER, M.Plaster)
	for _, side in { -1, 1 } do
		block("DoorJamb", Vector3.new(0.28, 7.6, 0.8), DiningRoom.DOOR.X + side * (DOOR_WIDTH / 2 + 0.14), 3.8, BACK + 0.3, WOOD, M.Wood)
	end
	block("DoorStep", Vector3.new(DOOR_WIDTH + 1, 0.2, 1.6), DiningRoom.DOOR.X, 0.06, BACK - 0.6, STONE, M.Slate)

	-- Flat roof hidden in build mode (above the lintels), with a terracotta edge.
	block("DiningRoof", Vector3.new(width + 1.2, 0.5, depth + 0.8), cx, HEIGHT + 0.25, cz - 0.2, rgb(118, 106, 92), M.Concrete)
	for _, z in { BACK - 0.5, FRONT + 0.1 } do
		block("RoofTrim", Vector3.new(width + 1.4, 0.4, 0.4), cx, HEIGHT + 0.65, z, TERRACOTTA, M.Brick, true)
	end
	for _, x in { LEFT - 0.5, RIGHT + 0.5 } do
		block("RoofTrim", Vector3.new(0.4, 0.4, depth + 1), x, HEIGHT + 0.65, cz - 0.2, TERRACOTTA, M.Brick, true)
	end

	-- Name board over the door, facing the quay.
	local board = block("RestaurantSign", Vector3.new(7, 1.1, 0.16), DiningRoom.DOOR.X, 8.2, BACK - 0.1, IRON, M.WoodPlanks, true)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(420, 66)
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -20, 1, -8)
	label.Position = UDim2.fromOffset(10, 4)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Garamond
	label.TextScaled = true
	label.TextColor3 = CREAM
	label.Text = "RESTAURANT"
	label.Parent = gui

	-- Warm pendant lamps over the tables.
	for index, position in { Vector3.new(-17.5, 0, -22), Vector3.new(-10.5, 0, -22) } do
		local shade = block("DiningLamp" .. index, Vector3.new(1.6, 0.35, 1.6), position.X, 8.1, position.Z, DARK_WOOD, M.Wood, true)
		block("DiningLampCord" .. index, Vector3.new(0.08, 0.8, 0.08), position.X, 8.7, position.Z, IRON, M.Metal, true)
		local glow = Instance.new("PointLight")
		glow.Color, glow.Brightness, glow.Range, glow.Shadows = rgb(255, 226, 180), 0.55, 18, true
		glow.Parent = shade
	end
	-- A long kitchen pass shelf under the processing room's rear window.
	block("PassShelf", Vector3.new(7.6, 0.2, 1), -13, 3.9, FRONT - 0.5, WOOD, M.WoodPlanks)
	room.Parent = parent
	return room
end

DiningRoom.TABLE_TOP = 2.6
DiningRoom.SEAT_OFFSET = 2.15
-- Each table seats two diners, one on each long side (local ±Z).
function DiningRoom.buildTable(parent: Instance, frame: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "DiningTable"
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
		local result = Props.part(model, size, frame * offset, color, material)
		result.Name = name
		return result
	end
	piece("TableTop", Vector3.new(4, 0.18, 2.6), CFrame.new(0, DiningRoom.TABLE_TOP - 0.09, 0), WOOD, M.Wood)
	local cloth = piece("TableCloth", Vector3.new(4.1, 0.04, 1.2), CFrame.new(0, DiningRoom.TABLE_TOP + 0.01, 0), LINEN, M.Fabric)
	cloth.CanCollide = false
	for _, x in { -1.75, 1.75 } do
		for _, z in { -1.05, 1.05 } do
			piece("TableLeg", Vector3.new(0.22, DiningRoom.TABLE_TOP - 0.18, 0.22), CFrame.new(x, (DiningRoom.TABLE_TOP - 0.18) / 2, z), DARK_WOOD, M.Wood)
		end
	end
	local candle = Props.cylinder(model, (frame * CFrame.new(0, DiningRoom.TABLE_TOP + 0.25, 0)).Position, 0.45, 0.16, CREAM, M.SmoothPlastic)
	candle.Name, candle.CanCollide = "Candle", false
	for index, side in { 1, -1 } do
		local z = side * DiningRoom.SEAT_OFFSET
		local seat = Instance.new("Seat")
		seat.Name = "DinerSeat" .. index
		seat.Size = Vector3.new(1.5, 0.3, 1.5)
		seat.Anchored = true
		seat.TopSurface, seat.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		seat.Color, seat.Material = WOOD, M.Wood
		-- Faces the table.
		seat.CFrame = frame * CFrame.new(0, 1.55, z) * CFrame.Angles(0, if side > 0 then 0 else math.pi, 0)
		seat:SetAttribute("PlateOffset", Vector3.new(0, DiningRoom.TABLE_TOP + 0.02, side * 0.6))
		seat.Parent = model
		piece("ChairBack", Vector3.new(1.5, 1.8, 0.18), CFrame.new(0, 2.5, z + side * 0.7), DARK_WOOD, M.Wood)
		for _, x in { -0.6, 0.6 } do
			for _, dz in { -0.6, 0.6 } do
				piece("ChairLeg", Vector3.new(0.16, 1.4, 0.16), CFrame.new(x, 0.7, z + dz), DARK_WOOD, M.Wood)
			end
		end
	end
	return model
end

return DiningRoom
