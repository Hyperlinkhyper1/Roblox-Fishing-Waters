-- The Restaurant path's dining room: an extension built onto the back of a base
-- house, behind the processing room, plus the dining tables placed inside it.
-- Positions are house-local studs (BaseHouse "HouseFrame"; floor y=0.16).
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

-- The walls follow the same 4.5-stud grid borders as the main house.
local LEFT, RIGHT = -24.75, -6.75
local BACK, FRONT = -33.75, -15.75
local HEIGHT = 9
DiningRoom.VERSION = 2
-- The west entrance opens onto the quay; the enlarged rear edge is close to
-- the water and would not provide a supported approach for diners.
DiningRoom.DOOR = Vector3.new(LEFT, 0.16, -27)
DiningRoom.ARRIVAL = Vector3.new(-27.1, 0.16, -27)
DiningRoom.INSIDE = Vector3.new(-22.5, 0.16, -27)
local DOOR_WIDTH = 6.5

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

	-- A side wall along z with a window opening between zA and zB. The west
	-- wall also has an open entrance reached from the quay.
	local function sideWall(x: number, name: string, entrance: boolean?)
		local zA, zB = -23.5, -19
		if entrance then
			local doorA, doorB = DiningRoom.DOOR.Z - DOOR_WIDTH / 2, DiningRoom.DOOR.Z + DOOR_WIDTH / 2
			block(name, Vector3.new(0.6, HEIGHT, doorA - BACK), x, HEIGHT / 2, (BACK + doorA) / 2, PLASTER, M.Plaster)
			block(name, Vector3.new(0.6, HEIGHT, zA - doorB), x, HEIGHT / 2, (doorB + zA) / 2, PLASTER, M.Plaster)
			block("DoorLintel", Vector3.new(0.6, HEIGHT - 7.6, DOOR_WIDTH), x, (HEIGHT + 7.6) / 2, DiningRoom.DOOR.Z, PLASTER, M.Plaster)
			-- The jambs stand just inside the opening and the step stops at the wall line. Faces
			-- that share a plane (jamb and wall end, step and dining floor) z-fight.
			for _, side in { -1, 1 } do
				block("DoorJamb", Vector3.new(0.8, 7.6, 0.28), x, 3.8, DiningRoom.DOOR.Z + side * (DOOR_WIDTH / 2 - 0.14), WOOD, M.Wood)
			end
			block("DoorStep", Vector3.new(1.4, 0.2, DOOR_WIDTH + 1), LEFT - 0.7, 0.06, DiningRoom.DOOR.Z, STONE, M.Slate)
		else
			block(name, Vector3.new(0.6, HEIGHT, zA - BACK), x, HEIGHT / 2, (BACK + zA) / 2, PLASTER, M.Plaster)
		end
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
	sideWall(LEFT, "DiningWestWall", true)
	sideWall(RIGHT, "DiningEastWall")
	block("DiningBackWall", Vector3.new(width + 0.6, HEIGHT, 0.6), cx, HEIGHT / 2, BACK, PLASTER, M.Plaster)

	-- Flat roof hidden in build mode (above the lintels), with a terracotta edge.
	block("DiningRoof", Vector3.new(width + 1.2, 0.5, depth + 0.8), cx, HEIGHT + 0.25, cz - 0.2, rgb(118, 106, 92), M.Concrete)
	for _, z in { BACK - 0.5, FRONT + 0.1 } do
		block("RoofTrim", Vector3.new(width + 1.4, 0.4, 0.4), cx, HEIGHT + 0.65, z, TERRACOTTA, M.Brick, true)
	end
	for _, x in { LEFT - 0.5, RIGHT + 0.5 } do
		block("RoofTrim", Vector3.new(0.4, 0.4, depth + 1), x, HEIGHT + 0.65, cz - 0.2, TERRACOTTA, M.Brick, true)
	end

	-- Name board over the door, facing the quay.
	local board = block("RestaurantSign", Vector3.new(0.16, 1.1, 7), LEFT - 0.1, 8.2, DiningRoom.DOOR.Z, IRON, M.WoodPlanks, true)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Left
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
		-- Shadows are budgeted per client to the lights nearest the camera (client/LightShadows).
		game:GetService("CollectionService"):AddTag(glow, "ShadowLight")
		glow.Parent = shade
	end
	-- A long kitchen pass shelf under the processing room's rear window.
	block("PassShelf", Vector3.new(7.6, 0.2, 1), -13, 3.9, FRONT - 0.5, WOOD, M.WoodPlanks)
	room.Parent = parent
	return room
end

DiningRoom.TABLE_TOP = 2.6
DiningRoom.SEAT_OFFSET = 2.5
-- Each table seats two diners facing each other, one at each end (local ±Z).
-- Table and chairs fill a 1x2 block of grid cells (FurnitureCatalog).
function DiningRoom.buildTable(parent: Instance, frame: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "DiningTable"
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
		local result = Props.part(model, size, frame * offset, color, material)
		result.Name = name
		return result
	end
	local function decorative(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
		local result = piece(name, size, offset, color, material)
		result.CanCollide, result.CanQuery = false, false
		return result
	end
	local top = DiningRoom.TABLE_TOP
	piece("TableTop", Vector3.new(3.6, 0.18, 2.6), CFrame.new(0, top - 0.09, 0), WOOD, M.Wood)
	decorative("TableApron", Vector3.new(3.3, 0.3, 2.3), CFrame.new(0, top - 0.33, 0), DARK_WOOD, M.Wood)
	decorative("TableRunner", Vector3.new(1.1, 0.03, 2.66), CFrame.new(0, top + 0.01, 0), LINEN, M.Fabric)
	for _, x in { -1.5, 1.5 } do
		for _, z in { -1.05, 1.05 } do
			piece("TableLeg", Vector3.new(0.22, top - 0.18, 0.22), CFrame.new(x, (top - 0.18) / 2, z), DARK_WOOD, M.Wood)
		end
	end
	-- A candle and a small vase of flowers between the place settings.
	local candle = Props.cylinder(model, (frame * CFrame.new(-0.6, top + 0.25, 0)).Position, 0.45, 0.16, CREAM, M.SmoothPlastic)
	candle.Name, candle.CanCollide = "Candle", false
	local flame = decorative("CandleFlame", Vector3.new(0.08, 0.14, 0.08), CFrame.new(-0.6, top + 0.55, 0), rgb(255, 196, 90), M.Neon)
	local glow = Instance.new("PointLight")
	glow.Color, glow.Brightness, glow.Range = rgb(255, 196, 120), 0.35, 5
	glow.Parent = flame
	local vase = Props.cylinder(model, (frame * CFrame.new(0.6, top + 0.22, 0)).Position, 0.4, 0.26, TERRACOTTA, M.SmoothPlastic)
	vase.Name, vase.CanCollide = "Vase", false
	for index, color in { rgb(228, 88, 92), rgb(250, 214, 96), rgb(236, 236, 248) } do
		local bloom = decorative("Bloom", Vector3.new(0.18, 0.18, 0.18), CFrame.new(0.6 + (index - 2) * 0.1, top + 0.52 + (index % 2) * 0.06, (index - 2) * 0.06), color, M.Fabric)
		bloom.Shape = Enum.PartType.Ball
	end
	for index, side in { 1, -1 } do
		local z = side * DiningRoom.SEAT_OFFSET
		-- Cutlery either side of the spot where the dish is served.
		for _, x in { -0.55, 0.55 } do
			decorative("Cutlery", Vector3.new(0.06, 0.02, 0.5), CFrame.new(x, top + 0.02, side * 0.65), rgb(196, 200, 204), M.Metal)
		end
		decorative("Napkin", Vector3.new(0.3, 0.03, 0.4), CFrame.new(-0.75, top + 0.02, side * 0.65), rgb(70, 110, 140), M.Fabric)
		local seat = Instance.new("Seat")
		seat.Name = "DinerSeat" .. index
		seat.Size = Vector3.new(1.5, 0.3, 1.5)
		seat.Anchored = true
		seat.TopSurface, seat.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		seat.Color, seat.Material = WOOD, M.Wood
		-- Faces the table.
		seat.CFrame = frame * CFrame.new(0, 1.55, z) * CFrame.Angles(0, if side > 0 then 0 else math.pi, 0)
		seat:SetAttribute("PlateOffset", Vector3.new(0, top + 0.02, side * 0.6))
		seat.Parent = model
		decorative("SeatCushion", Vector3.new(1.3, 0.1, 1.3), CFrame.new(0, 1.75, z), rgb(150, 60, 50), M.Fabric)
		-- A slatted back between two posts.
		for _, x in { -0.66, 0.66 } do
			piece("ChairPost", Vector3.new(0.16, 1.9, 0.16), CFrame.new(x, 2.4, z + side * 0.67), DARK_WOOD, M.Wood)
		end
		piece("ChairBackRail", Vector3.new(1.5, 0.3, 0.16), CFrame.new(0, 3.2, z + side * 0.67), DARK_WOOD, M.Wood)
		for _, x in { -0.3, 0, 0.3 } do
			piece("ChairSlat", Vector3.new(0.14, 1.15, 0.1), CFrame.new(x, 2.45, z + side * 0.67), WOOD, M.Wood)
		end
		for _, x in { -0.6, 0.6 } do
			for _, dz in { -0.6, 0.6 } do
				piece("ChairLeg", Vector3.new(0.16, 1.4, 0.16), CFrame.new(x, 0.7, z + dz), DARK_WOOD, M.Wood)
			end
		end
	end
	return model
end

return DiningRoom
