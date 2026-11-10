-- Empty player-base shell. Local +Z is the front; the deck is y=0.
-- The house holds the kitchen (Processing), the owner's office in the
-- kitchen's front-left corner, and the storage room; customers shop in a
-- separate building across the road (the "Shop" model, built in the same
-- house-local frame). The same builder is used for fresh plots and upgrades
-- to a saved map.
local BaseGrid = require(game:GetService("ReplicatedStorage").Shared.BaseGrid)
local CollectionService = game:GetService("CollectionService")
local Props = require(script.Parent.Props)

local BaseHouse = {}
local VERSION = 13
-- Scale the original shell around its house-local origin to the grid edges.
local SCALE_X = (BaseGrid.HALF_WIDTH * 2) / 46
local SCALE_Z = (BaseGrid.HALF_LENGTH * 2) / 30
local LIGHTING_VERSION = 3
-- Shadow-casting lights tagged with this are budgeted per client (client/LightShadows).
local SHADOW_LIGHT_TAG = "ShadowLight"
local AWNING_VERSION = 1
local SURFACE_VERSION = 1

local function repairOverlappingSurfaces(house: Model)
	if house:GetAttribute("SurfaceVersion") == SURFACE_VERSION then
		return
	end
	local shell = house:FindFirstChild("Shell")
	if not shell then
		return
	end
	local step = shell:FindFirstChild("EntranceStep")
	if step and step:IsA("BasePart") then
		step.CFrame *= CFrame.new(0, -0.02, 0)
	end
	for _, name in { "OfficeDoorLintel", "LobbyDoorLintel" } do
		local lintel = shell:FindFirstChild(name)
		if lintel and lintel:IsA("BasePart") then
			-- Keep the top fixed while lifting the underside above the wood header.
			lintel.Size -= Vector3.new(0, 0.04, 0)
			lintel.CFrame *= CFrame.new(0, 0.02, 0)
		end
	end
	house:SetAttribute("SurfaceVersion", SURFACE_VERSION)
end
-- The shop's walls: front (facing the house), back and sides, all on grid borders.
local SHOP_FRONT, SHOP_BACK = BaseGrid.SHOP_FRONT, BaseGrid.SHOP_BACK
local SHOP_MID = (SHOP_FRONT + SHOP_BACK) / 2
local SHOP_HALF = BaseGrid.HALF_WIDTH
local rgb = Color3.fromRGB
local M = Enum.Material
local PLASTER = rgb(230, 222, 199)
local STONE = rgb(168, 156, 130)
local WOOD = rgb(124, 88, 55)
local DARK_WOOD = rgb(67, 48, 35)
local IRON = rgb(43, 53, 57)
local CREAM = rgb(247, 235, 204)
local TILE = rgb(194, 207, 197)
local TERRACOTTA = rgb(164, 75, 46)

local function model(parent: Instance, name: string): Model
	local result = Instance.new("Model")
	result.Name = name
	result.Parent = parent
	return result
end

-- Furnish saved shells in place, keeping lamps attached to the ceiling ties.
local function ensureLights(house: Model, frame: CFrame)
	for roomName, positions in
		{
			Shop = { Vector3.new(-15, 0, SHOP_MID), Vector3.new(0, 0, SHOP_MID), Vector3.new(15, 0, SHOP_MID) },
			Processing = {
				Vector3.new(-16, 0, -10),
				Vector3.new(-4, 0, -10),
				Vector3.new(-16, 0, 10),
				Vector3.new(-4, 0, 10),
			},
			Storage = { Vector3.new(8, 0, -10), Vector3.new(18, 0, -10), Vector3.new(8, 0, 10), Vector3.new(18, 0, 10) },
		}
	do
		local room = house:FindFirstChild(roomName)
		if not room then
			continue
		end
		local existing = room:FindFirstChild("CeilingLights")
		if existing and existing:GetAttribute("LayoutVersion") == LIGHTING_VERSION then
			-- Saved pendants predate the tag that hands their shadows to client/LightShadows.
			for _, item in existing:GetDescendants() do
				if item:IsA("PointLight") and item.Shadows then
					CollectionService:AddTag(item, SHADOW_LIGHT_TAG)
				end
			end
			continue
		end
		if existing then
			existing:Destroy()
		end
		local lights = model(room, "CeilingLights")
		lights:SetAttribute("LayoutVersion", LIGHTING_VERSION)
		for index, position in positions do
			local fixture = model(lights, "Pendant" .. index)
			local function piece(name: string, size: Vector3, y: number, color: Color3, material: Enum.Material): Part
				local result = Props.part(fixture, size, frame * CFrame.new(position.X, y, position.Z), color, material)
				result.Name = name
				result.CanCollide, result.CanQuery = false, false
				return result
			end
			piece("CeilingMount", Vector3.new(0.65, 0.12, 0.65), 10.82, IRON, M.Metal)
			piece("HangingCord", Vector3.new(0.08, 1.36, 0.08), 10.08, IRON, M.Metal)
			piece("LampShade", Vector3.new(1.8, 0.3, 1.8), 9.25, IRON, M.Metal)
			local bulb = piece("LampGlobe", Vector3.new(0.7, 0.7, 0.7), 8.85, rgb(240, 226, 200), M.SmoothPlastic)
			bulb.Shape = Enum.PartType.Ball
			local glow = Instance.new("PointLight")
			glow.Name = "InteriorLight"
			glow.Color = rgb(255, 237, 209)
			-- Soft interior fill; walls and the shade contain the light instead
			-- of letting every pendant illuminate the outside of the house.
			glow.Brightness = 0.45
			glow.Range = 18
			glow.Shadows = true
			glow.Enabled = true
			-- Every base has 11 of these: clients keep shadows only on the few nearest the camera.
			CollectionService:AddTag(glow, SHADOW_LIGHT_TAG)
			glow.Parent = bulb
		end
	end
end

-- Exterior dressing on the house shell: stone base course and corner quoins,
-- flower boxes, shutters and folded-back doors at the rear, a tiled porch
-- canopy, lanterns, planters, gable vents, downpipes and a kitchen chimney.
-- Everything is decorative (no collision or queries), so walking routes and
-- NPC navigation are unchanged. Saved houses receive it in place, versioned.
-- Part names avoid Wall/Window/Door/Roof/Floor so the building editor does not
-- capture them as structural pieces.
local EXTERIOR_VERSION = 1
local FLOWER_COLORS = { rgb(222, 72, 86), rgb(250, 206, 84), rgb(244, 242, 236), rgb(188, 110, 214), rgb(250, 140, 60) }

local function ensureExterior(house: Model, frame: CFrame, accent: Color3)
	local existing = house:FindFirstChild("Exterior")
	if existing and existing:GetAttribute("LayoutVersion") == EXTERIOR_VERSION then
		return
	end
	if existing then
		existing:Destroy()
	end
	local exterior = model(house, "Exterior")
	exterior:SetAttribute("LayoutVersion", EXTERIOR_VERSION)
	local hx, hz = BaseGrid.HALF_WIDTH, BaseGrid.HALF_LENGTH
	local face = 0.325 -- half the shell's wall thickness
	local plinthOut = 0.41 * SCALE_X -- outer face of the side plinths
	local quoinColor = rgb(186, 174, 147)
	local leafGreen, darkLeaf = rgb(76, 122, 62), rgb(58, 96, 50)

	local function decorate(item: Instance)
		for _, piece in if item:IsA("BasePart") then { item } else item:GetDescendants() do
			if piece:IsA("BasePart") then
				piece.CanCollide, piece.CanQuery, piece.CanTouch = false, false, false
			end
		end
	end
	-- `at` is a house-local frame; returns the placed decorative part.
	local function piece(group: Instance, name: string, size: Vector3, at: CFrame, color: Color3, material: Enum.Material): Part
		local result = Props.part(group, size, frame * at, color, material)
		result.Name = name
		decorate(result)
		return result
	end
	local function glow(part: BasePart, range: number)
		local light = Instance.new("PointLight")
		light.Name = "LanternLight"
		light.Color = rgb(255, 214, 150)
		light.Range = range
		light.Brightness = 0.8
		light.Shadows = false
		light.Parent = part
	end
	-- Each end wall as a frame on its outer face, local +Z pointing outdoors.
	-- `u` runs along the wall; on the rear wall u = -x.
	local function endFace(s: number): CFrame
		return CFrame.new(0, 0, s * (hz + face)) * (if s > 0 then CFrame.identity else CFrame.Angles(0, math.pi, 0))
	end
	local function sideFace(sx: number): CFrame
		return CFrame.new(sx * (hx + face), 0, 0) * CFrame.Angles(0, sx * math.pi / 2, 0)
	end

	local front, rear = endFace(1), endFace(-1)
	local frontDoorHalf, rearDoorHalf = 10.5 / 2, 3 * SCALE_X
	local rearDoorX = -BaseGrid.CELL_SIZE / 2
	local windowX = 13 * SCALE_X
	local walls = {
		{ s = 1, at = front, doorX = 0, doorHalf = frontDoorHalf, windowHalf = 5 * SCALE_X, bottom = 3 },
		{ s = -1, at = rear, doorX = rearDoorX, doorHalf = rearDoorHalf, windowHalf = 3.5 * SCALE_X, bottom = 4 },
	}

	-- Stone base course along both end walls, broken by the doorways and
	-- meeting the side plinths at the corners.
	local course = model(exterior, "BaseCourse")
	for _, spec in walls do
		local doorU = spec.s * spec.doorX
		local doorLow, doorHigh = doorU - spec.doorHalf - 0.4, doorU + spec.doorHalf + 0.4
		for _, span in { { -(hx + plinthOut), doorLow }, { doorHigh, hx + plinthOut } } do
			local length = span[2] - span[1]
			piece(course, "StoneCourse", Vector3.new(length, 0.8, 0.2), spec.at * CFrame.new((span[1] + span[2]) / 2, 0.4, 0.1), STONE, M.Slate)
		end
	end

	-- Alternating long and short quoin stones wrapping all four corners.
	local quoins = model(exterior, "Quoins")
	for _, sx in { -1, 1 } do
		for _, s in { -1, 1 } do
			local endAt, sideAt = endFace(s), sideFace(sx)
			-- u of this corner's edge on each face.
			local endEdge, sideEdge = s * sx * (hx + face + 0.14), -sx * s * (hz + face)
			for row = 0, 5 do
				local y = 1.5 + row * 1.55
				local endLength = if row % 2 == 0 then 1.7 else 1
				local sideLength = if row % 2 == 0 then 1 else 1.7
				local endDir, sideDir = -math.sign(endEdge), -math.sign(sideEdge)
				piece(quoins, "Quoin", Vector3.new(endLength, 1.35, 0.14), endAt * CFrame.new(endEdge + endDir * endLength / 2, y, 0.07), quoinColor, M.Slate)
				piece(quoins, "Quoin", Vector3.new(sideLength, 1.35, 0.14), sideAt * CFrame.new(sideEdge + sideDir * sideLength / 2, y, 0.07), quoinColor, M.Slate)
			end
		end
	end

	-- Flower boxes on brackets below every window sill.
	local boxes = model(exterior, "FlowerBoxes")
	local flowerIndex = 0
	for _, spec in walls do
		for _, wx in { -windowX, windowX } do
			local u = spec.s * wx
			local width = 2 * spec.windowHalf - 0.8
			local top = spec.bottom - 0.24
			local box = model(boxes, "FlowerBox")
			piece(box, "Planter", Vector3.new(width, 0.75, 0.85), spec.at * CFrame.new(u, top - 0.375, 0.75), WOOD, M.WoodPlanks)
			piece(box, "PlanterTrim", Vector3.new(width + 0.14, 0.12, 0.95), spec.at * CFrame.new(u, top - 0.02, 0.75), accent, M.Wood)
			piece(box, "Foliage", Vector3.new(width - 0.3, 0.42, 0.66), spec.at * CFrame.new(u, top + 0.17, 0.78), leafGreen, M.Grass)
			for _, side in { -1, 1 } do
				piece(box, "PlanterBracket", Vector3.new(0.2, 0.55, 0.6), spec.at * CFrame.new(u + side * (width / 2 - 0.8), top - 1.0, 0.32), DARK_WOOD, M.Wood)
			end
			local count = math.max(3, math.floor(width / 1.15))
			for index = 1, count do
				flowerIndex += 1
				local bloom = piece(
					box,
					"Bloom",
					Vector3.new(0.42, 0.42, 0.42),
					spec.at * CFrame.new(u - width / 2 + (index - 0.5) * width / count, top + 0.45 + (index % 2) * 0.08, 0.7 + (index % 2) * 0.16),
					FLOWER_COLORS[(flowerIndex - 1) % #FLOWER_COLORS + 1],
					M.SmoothPlastic
				)
				bloom.Shape = Enum.PartType.Ball
				bloom.CastShadow = false
			end
		end
	end

	-- The rear (quay-side) door: open shutters on its windows, plank doors
	-- folded back against the wall and a tiled canopy on carved brackets.
	local porch = model(exterior, "RearPorch")
	local rearHalf = 3.5 * SCALE_X
	for _, wx in { -windowX, windowX } do
		for _, side in { -1, 1 } do
			piece(porch, "Shutter", Vector3.new(1.4, 4.9, 0.25), rear * CFrame.new(-wx + side * (rearHalf + 0.8), 6.15, 0.55) * CFrame.Angles(0, side * 0.22, 0), accent, M.WoodPlanks)
		end
	end
	local doorU = -rearDoorX
	for _, side in { -1, 1 } do
		local hinge = doorU + side * (rearDoorHalf + 0.35)
		local center = hinge + side * 1.4
		piece(porch, "PlankLeaf", Vector3.new(2.8, 7.9, 0.18), rear * CFrame.new(center, 4.15, 0.1), accent, M.WoodPlanks)
		for _, y in { 1.4, 6.9 } do
			piece(porch, "StrapHinge", Vector3.new(2.1, 0.18, 0.06), rear * CFrame.new(hinge + side * 1.05, y, 0.22), IRON, M.Metal)
		end
	end
	local tilt, depth, canopyWidth = 0.2, 2.4, 2 * rearDoorHalf + 2
	local canopyAt = rear * CFrame.new(doorU, 9.75, depth / 2) * CFrame.Angles(tilt, 0, 0)
	piece(porch, "PorchCanopy", Vector3.new(canopyWidth, 0.3, depth), canopyAt, TERRACOTTA, M.RoofShingles)
	for course = 0, 3 do
		piece(porch, "CanopyTiles", Vector3.new(canopyWidth + 0.05, 0.12, 0.14), canopyAt * CFrame.new(0, 0.2, -depth / 2 + 0.3 + course * 0.6), rgb(191, 96, 60), M.Brick)
	end
	piece(porch, "CanopyFascia", Vector3.new(canopyWidth + 0.1, 0.4, 0.14), canopyAt * CFrame.new(0, -0.1, depth / 2), CREAM, M.Wood)
	piece(porch, "CanopyFlashing", Vector3.new(canopyWidth + 0.2, 0.3, 0.2), rear * CFrame.new(doorU, 10.1, 0.1), STONE, M.Slate)
	for _, side in { -1, 1 } do
		local u = doorU + side * (canopyWidth / 2 - 0.5)
		piece(porch, "CanopyBracket", Vector3.new(0.3, 1.5, 0.22), rear * CFrame.new(u, 9.05, 0.11), DARK_WOOD, M.Wood)
		local strut = Props.beam(porch, (frame * rear * CFrame.new(u, 8.45, 0.2)).Position, (frame * rear * CFrame.new(u, 9.45, 1.9)).Position, 0.22, DARK_WOOD, 0.22, M.Wood)
		strut.Name = "CanopyStrut"
		decorate(strut)
		-- A lantern hangs under each end of the canopy.
		local lanternU = doorU + side * 3
		local underside = 9.75 - (1.5 - depth / 2) * math.sin(tilt) - 0.15
		piece(porch, "LanternChain", Vector3.new(0.08, underside - 9.0, 0.08), rear * CFrame.new(lanternU, (underside + 9.0) / 2, 1.5), IRON, M.Metal)
		piece(porch, "LanternCap", Vector3.new(0.7, 0.14, 0.7), rear * CFrame.new(lanternU, 8.95, 1.5), IRON, M.Metal)
		local body = piece(porch, "LanternGlass", Vector3.new(0.5, 0.75, 0.5), rear * CFrame.new(lanternU, 8.5, 1.5), rgb(255, 212, 140), M.Neon)
		body.CastShadow = false
		glow(body, 12)
		piece(porch, "LanternBase", Vector3.new(0.6, 0.12, 0.6), rear * CFrame.new(lanternU, 8.07, 1.5), IRON, M.Metal)
	end
	piece(porch, "WelcomeMat", Vector3.new(3.2, 0.04, 1.6), rear * CFrame.new(doorU, 0.17, 1.2), rgb(150, 118, 76), M.Fabric)

	-- Wall lanterns either side of the front door, under the awning.
	local frontLamps = model(exterior, "FrontLanterns")
	for _, side in { -1, 1 } do
		local u = side * (frontDoorHalf + 0.85)
		piece(frontLamps, "LanternPlate", Vector3.new(0.35, 0.7, 0.12), front * CFrame.new(u, 7.0, 0.06), IRON, M.Metal)
		piece(frontLamps, "LanternArm", Vector3.new(0.12, 0.12, 0.6), front * CFrame.new(u, 7.1, 0.4), IRON, M.Metal)
		piece(frontLamps, "LanternCap", Vector3.new(0.65, 0.12, 0.65), front * CFrame.new(u, 6.96, 0.65), IRON, M.Metal)
		local body = piece(frontLamps, "LanternGlass", Vector3.new(0.48, 0.68, 0.48), front * CFrame.new(u, 6.56, 0.65), rgb(255, 212, 140), M.Neon)
		body.CastShadow = false
		glow(body, 12)
	end

	-- Terracotta pots with clipped shrubs beside both doors.
	local pots = model(exterior, "Planters")
	for _, spot in {
		{ at = rear, u = doorU - 7.35 }, -- house x ≈ 5.1, beside one folded door leaf
		{ at = rear, u = doorU + 7.25 }, -- house x ≈ -9.5, beside the other
		{ at = front, u = -7.1 },
		{ at = front, u = 7.1 },
	} do
		local base = spot.at * CFrame.new(spot.u, 0, 0.95)
		local upright = CFrame.Angles(0, 0, math.pi / 2)
		local pot = model(pots, "Pot")
		piece(pot, "PotBody", Vector3.new(1.2, 1.25, 1.25), base * CFrame.new(0, 0.6, 0) * upright, TERRACOTTA, M.Slate).Shape = Enum.PartType.Cylinder
		piece(pot, "PotRim", Vector3.new(0.22, 1.5, 1.5), base * CFrame.new(0, 1.25, 0) * upright, rgb(186, 94, 60), M.Slate).Shape = Enum.PartType.Cylinder
		piece(pot, "Shrub", Vector3.new(1.5, 1.5, 1.5), base * CFrame.new(0, 1.95, 0), leafGreen, M.Grass).Shape = Enum.PartType.Ball
		piece(pot, "Shrub", Vector3.new(0.95, 0.95, 0.95), base * CFrame.new(0.25, 2.55, -0.1), darkLeaf, M.Grass).Shape = Enum.PartType.Ball
	end

	-- Louvred vents high in both gables.
	local vents = model(exterior, "GableVents")
	for _, at in { front, rear } do
		piece(vents, "VentFrame", Vector3.new(2.5, 1.6, 0.1), at * CFrame.new(0, 14.0, 0.05), CREAM, M.Wood)
		piece(vents, "VentShadow", Vector3.new(2.1, 1.25, 0.06), at * CFrame.new(0, 14.0, 0.11), DARK_WOOD, M.SmoothPlastic)
		for _, y in { 13.6, 14.0, 14.4 } do
			piece(vents, "VentSlat", Vector3.new(2.1, 0.12, 0.22), at * CFrame.new(0, y, 0.2) * CFrame.Angles(0.5, 0, 0), CREAM, M.Wood)
		end
	end

	-- Downpipes at all four corners, each with a gutter outlet, wall clips and
	-- a shoe; the shell already has the pipe at the back-left corner.
	local pipes = model(exterior, "Downpipes")
	local pipeX, pipeZ = 23.7 * SCALE_X, 13 * SCALE_Z
	for _, sx in { -1, 1 } do
		for _, s in { -1, 1 } do
			local x, z = sx * pipeX, s * pipeZ
			if not (sx < 0 and s < 0) then
				piece(pipes, "Downpipe", Vector3.new(0.24, 10.8, 0.24), CFrame.new(x, 5.8, z), IRON, M.Metal)
			end
			piece(pipes, "PipeOutlet", Vector3.new(0.8, 0.24, 0.24), CFrame.new(x + sx * 0.3, 11.3, z), IRON, M.Metal)
			piece(pipes, "PipeShoe", Vector3.new(0.6, 0.24, 0.3), CFrame.new(x + sx * 0.2, 0.42, z), IRON, M.Metal)
			for _, y in { 3.5, 8.0 } do
				local clipLength = math.abs(x) - (hx + face)
				piece(pipes, "PipeClip", Vector3.new(clipLength, 0.14, 0.14), CFrame.new(sx * (hx + face + clipLength / 2), y, z), IRON, M.Metal)
			end
		end
	end

	-- A rendered kitchen chimney rising through the rear of the left roof slope.
	-- Its base sits inside the slope's thickness, so it never shows indoors.
	local chimney = model(exterior, "Chimney")
	local pitch = math.atan2(4.8, 24)
	local slopeCenter, half = 12 * SCALE_X, 0.225 / math.cos(pitch)
	local function roofTop(x: number): number
		return 14.05 + half - math.tan(pitch) * (math.abs(x) - slopeCenter)
	end
	local cx, cz, cw, cd = -6.5, -8.5, 2, 2.4
	local bottom = roofTop(math.abs(cx) + cw / 2) - 0.03
	local stackTop = 19.2
	piece(chimney, "ChimneyStack", Vector3.new(cw, stackTop - bottom, cd), CFrame.new(cx, (stackTop + bottom) / 2, cz), PLASTER, M.Plaster)
	piece(chimney, "ChimneyBand", Vector3.new(cw + 0.3, 0.3, cd + 0.3), CFrame.new(cx, stackTop + 0.15, cz), STONE, M.Slate)
	piece(chimney, "ChimneyFlue", Vector3.new(cw - 0.8, 0.75, cd - 0.9), CFrame.new(cx, stackTop + 0.67, cz), rgb(30, 26, 24), M.Slate)
	for _, dx in { -1, 1 } do
		for _, dz in { -1, 1 } do
			piece(chimney, "ChimneyPier", Vector3.new(0.35, 0.75, 0.35), CFrame.new(cx + dx * (cw / 2 - 0.2), stackTop + 0.67, cz + dz * (cd / 2 - 0.2)), PLASTER, M.Plaster)
		end
	end
	piece(chimney, "ChimneyHood", Vector3.new(cw + 0.5, 0.25, cd + 0.5), CFrame.new(cx, stackTop + 1.17, cz), TERRACOTTA, M.RoofShingles)
	piece(chimney, "ChimneyCrest", Vector3.new(0.45, 0.22, cd + 0.6), CFrame.new(cx, stackTop + 1.4, cz), rgb(195, 101, 66), M.Brick)

	-- Maritime touches on the quay side: a life ring and crossed oars.
	local ring = Props.lifeRing(exterior, frame * rear * CFrame.new(-(hx - 3.3), 5.6, 0.3))
	decorate(ring)
	local oars = model(exterior, "CrossedOars")
	for _, side in { -1, 1 } do
		local tiltAt = rear * CFrame.new(hx - 3.4, 5.8, 0.2) * CFrame.Angles(0, 0, side * 0.42)
		piece(oars, "OarShaft", Vector3.new(0.16, 6.2, 0.12), tiltAt, WOOD, M.Wood)
		piece(oars, "OarBlade", Vector3.new(0.6, 1.6, 0.08), tiltAt * CFrame.new(0, -2.7, 0.02), accent, M.WoodPlanks)
	end
	piece(oars, "OarPeg", Vector3.new(0.3, 0.3, 0.3), rear * CFrame.new(hx - 3.4, 5.8, 0.3), DARK_WOOD, M.Wood)
end

-- A sign board whose SurfaceGui matches its physical size, so glyphs keep their proportions.
local function signText(board: BasePart, face: Enum.NormalId, value: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(board.Size.X * 20, board.Size.Y * 20)
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -24, 1, -12)
	label.Position = UDim2.new(0, 12, 0, 6)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextWrapped = false
	label.TextColor3 = CREAM
	label.Text = value
	label.Parent = gui
end

-- The customer shop across the road. House-local coordinates, unscaled: the
-- floor plan is the former front shop room turned to face the house, one row
-- deeper, so its freezer, counter and entrance aisle keep their places.
local function buildShop(house: Model, frame: CFrame, accent: Color3, index: number): Model
	local shop = model(house, "Shop")
	shop:SetAttribute("RoomType", "Shop")
	local shell = model(shop, "ShopShell")
	local function block(
		group: Instance,
		name: string,
		size: Vector3,
		x: number,
		y: number,
		z: number,
		color: Color3,
		material: Enum.Material?,
		rotation: CFrame?,
		decorative: boolean?
	): Part
		local piece = Props.part(group, size, frame * CFrame.new(x, y, z) * (rotation or CFrame.identity), color, material)
		piece.Name = name
		if decorative then
			piece.CanCollide = false
			piece.CanQuery = false
		end
		return piece
	end
	local depth = SHOP_BACK - SHOP_FRONT
	-- The village ground is ~0.9 below the house floor; a stone footing carries
	-- the shop floor at the same height as the house, so furniture and the
	-- navigation grid share one floor level.
	block(shell, "ShopFoundation", Vector3.new(2 * SHOP_HALF + 0.8, 1.2, depth + 0.8), 0, -0.6, SHOP_MID, STONE, M.Slate)
	block(shop, "ShopFloor", Vector3.new(2 * SHOP_HALF, 0.16, depth), 0, 0.08, SHOP_MID, WOOD, M.WoodPlanks)
	-- A paved forecourt from the far kerb up to the door, above the road's own top.
	block(shell, "ShopForecourt", Vector3.new(2 * SHOP_HALF + 3.5, 0.6, 4.75), 0, -0.4, SHOP_FRONT - 2.375, STONE, M.Cobblestone)
	block(shell, "ShopEntranceStep", Vector3.new(8.5, 0.25, 1.35), 0, -0.095, SHOP_FRONT - 0.675, STONE, M.Slate)
	-- Zebra crossing over the ring road on the line of the base's dirt track.
	for stripe = 0, 6 do
		block(shell, "Crosswalk", Vector3.new(6, 0.05, 1), 0, -0.165, 46 + stripe * 2, CREAM, M.SmoothPlastic, nil, true)
	end

	type Opening = { x: number, width: number, bottom: number, top: number }
	local function wall(z: number, openings: { Opening }, name: string)
		local cursor = -SHOP_HALF
		local function piece(suffix: string, width: number, height: number, x: number, y: number)
			block(shell, name .. suffix, Vector3.new(width, height, 0.65), x, y, z, PLASTER, M.Plaster)
		end
		for _, opening in openings do
			local left, right = opening.x - opening.width / 2, opening.x + opening.width / 2
			if left > cursor then
				piece("", left - cursor, 11.5, (cursor + left) / 2, 5.75)
			end
			if opening.bottom > 0 then
				piece("SillWall", opening.width, opening.bottom, opening.x, opening.bottom / 2)
			end
			piece("Lintel", opening.width, 11.5 - opening.top, opening.x, (11.5 + opening.top) / 2)
			cursor = right
		end
		if cursor < SHOP_HALF then
			piece("", SHOP_HALF - cursor, 11.5, (cursor + SHOP_HALF) / 2, 5.75)
		end
	end
	local frontWindows = { -14, 14 }
	wall(SHOP_FRONT, {
		{ x = -14, width = 10.5, bottom = 3, top = 8.7 },
		{ x = 0, width = 7.5, bottom = 0, top = 8.8 },
		{ x = 14, width = 10.5, bottom = 3, top = 8.7 },
	}, "ShopFrontWall")
	wall(SHOP_BACK, {
		{ x = -12, width = 6, bottom = 4, top = 8.3 },
		{ x = 12, width = 6, bottom = 4, top = 8.3 },
	}, "ShopBackWall")
	for _, x in { -SHOP_HALF, SHOP_HALF } do
		block(shell, "ShopSideWall", Vector3.new(0.65, 11.5, depth + 0.65), x, 5.75, SHOP_MID, PLASTER, M.Plaster)
		block(shell, "ShopSidePlinth", Vector3.new(0.82, 0.75, depth + 0.65), x, 0.5, SHOP_MID, STONE, M.Slate)
		for _, z in { SHOP_FRONT, SHOP_BACK } do
			block(shell, "ShopCornerPost", Vector3.new(0.9, 11.5, 0.9), x, 5.75, z, WOOD, M.Wood)
		end
	end

	-- Divided windows with stone sills, like the house; the front pair has open shutters.
	for _, spec in {
		{ z = SHOP_FRONT, xs = frontWindows, width = 10.5, bottom = 3, top = 8.7, outward = -1 },
		{ z = SHOP_BACK, xs = { -12, 12 }, width = 6, bottom = 4, top = 8.3, outward = 1 },
	} do
		local width, bottom, top = spec.width, spec.bottom, spec.top
		for _, x in spec.xs do
			local glass = block(shell, "WindowGlass", Vector3.new(width, top - bottom, 0.12), x, (bottom + top) / 2, spec.z, rgb(105, 165, 175), M.SmoothPlastic, nil, true)
			glass.Transparency = 0.68
			for _, dx in { -width / 2, 0, width / 2 } do
				block(shell, "WindowMullion", Vector3.new(0.16, top - bottom + 0.2, 0.32), x + dx, (bottom + top) / 2, spec.z, CREAM, M.Wood, nil, true)
			end
			for _, y in { bottom, (bottom + top) / 2, top } do
				block(shell, "WindowRail", Vector3.new(width, 0.17, 0.32), x, y, spec.z, CREAM, M.Wood, nil, true)
			end
			block(shell, "StoneSill", Vector3.new(width + 0.6, 0.24, 1.15), x, bottom - 0.1, spec.z, STONE, M.Slate, nil, true)
			if spec.outward < 0 then
				for _, side in { -1, 1 } do
					block(shell, "OpenShutter", Vector3.new(1.7, 5.7, 0.3), x + side * (width / 2 + 0.95), 5.85, spec.z - 0.65, accent, M.WoodPlanks, CFrame.Angles(0, -side * 0.22, 0), true)
				end
			end
		end
	end
	for _, side in { -1, 1 } do
		block(shell, "DoorJamb", Vector3.new(0.34, 8.8, 0.9), side * (7.5 / 2 + 0.14), 4.4, SHOP_FRONT, WOOD, M.Wood)
	end
	block(shell, "DoorHeader", Vector3.new(7.5 + 0.6, 0.3, 0.9), 0, 8.95, SHOP_FRONT, WOOD, M.Wood)

	-- Terracotta roof pitched front to back, with gables over the side walls.
	local rise, run = 3.2, depth / 2
	local pitch = math.atan2(rise, run)
	local slope = math.sqrt(rise * rise + run * run) + 1.2
	for _, side in { -1, 1 } do
		-- side -1 is the front slope, falling toward the road.
		local eaveZ = SHOP_MID + side * run
		local centerZ = (eaveZ + SHOP_MID) / 2 + side * 0.6 * math.cos(pitch)
		local centerY = 11.7 + rise / 2 + 0.25 - 0.6 * math.sin(pitch)
		block(shell, "ShopRoofSlope", Vector3.new(2 * SHOP_HALF + 1.8, 0.45, slope), 0, centerY, centerZ, TERRACOTTA, M.RoofShingles, CFrame.Angles(side * pitch, 0, 0))
		block(shell, "ShopRainGutter", Vector3.new(2 * SHOP_HALF + 2, 0.35, 0.4), 0, 11.6, eaveZ + side * 1.3, IRON, M.Metal, nil, true)
		block(shell, "ShopEavesBeam", Vector3.new(2 * SHOP_HALF + 1, 0.55, 0.5), 0, 11.4, eaveZ, DARK_WOOD, M.Wood)
	end
	block(shell, "ShopRidgeCap", Vector3.new(2 * SHOP_HALF + 2, 0.55, 0.8), 0, 11.7 + rise + 0.3, SHOP_MID, rgb(195, 101, 66), M.Brick)
	for _, x in { -SHOP_HALF, SHOP_HALF } do
		for row = 0, 5 do
			local height = (row + 0.5) * rise / 6
			block(shell, "ShopGable", Vector3.new(0.65, rise / 6 + 0.05, math.max(0.6, depth * (1 - height / rise))), x, 11.5 + height, SHOP_MID, PLASTER, M.Plaster)
		end
	end
	for _, x in { -15, 0, 15 } do
		block(shell, "ShopCeilingTie", Vector3.new(0.4, 0.45, depth), x, 11.1, SHOP_MID, DARK_WOOD, M.Wood)
	end

	-- The owner's shop name over the door; BaseService writes custom names here.
	local sign = block(shell, "ShopSign", Vector3.new(20, 1.8, 0.16), 0, 10.3, SHOP_FRONT - 0.5, IRON, M.WoodPlanks, nil, true)
	signText(sign, Enum.NormalId.Front, "FISH & TACKLE  /  " .. string.format("%02d", index))
	-- Striped canvas awning over the entrance, rising out toward the road.
	for stripe = -5, 5 do
		local color = if stripe % 2 == 0 then accent else CREAM
		block(shell, "AwningStripe", Vector3.new(1.776, 0.15, 3.78), stripe * 1.776, 9.2, SHOP_FRONT - 2.1, color, M.Fabric, CFrame.Angles(0.12, 0, 0), true)
		block(shell, "AwningValance", Vector3.new(1.776, 0.5, 0.12), stripe * 1.776, 8.8, SHOP_FRONT - 3.94, color, M.Fabric, nil, true)
	end
	return shop
end

function BaseHouse.build(parent: Instance, frame: CFrame, accent: Color3, index: number): Model
	local house = model(parent, "BaseHouse")
	house:SetAttribute("LayoutVersion", VERSION)
	house:SetAttribute("AwningVersion", AWNING_VERSION)
	house:SetAttribute("BaseId", index)
	house:SetAttribute("HouseFrame", frame)
	house:SetAttribute("GridCellSize", BaseGrid.CELL_SIZE)
	house:SetAttribute("GridColumns", BaseGrid.COLUMNS)
	house:SetAttribute("GridRows", BaseGrid.ROWS)
	local shell = model(house, "Shell")
	local processing = model(house, "Processing")
	local storage = model(house, "Storage")
	processing:SetAttribute("RoomType", "Processing")
	storage:SetAttribute("RoomType", "Storage")

	local function block(
		group: Instance,
		name: string,
		size: Vector3,
		x: number,
		y: number,
		z: number,
		color: Color3,
		material: Enum.Material?,
		rotation: CFrame?,
		decorative: boolean?
	): Part
		-- Interior walls use house-local coordinates directly; their centerlines
		-- sit on grid boundaries rather than being stretched with the shell.
		local interior = string.find(name, "^StorePartition") ~= nil
			or string.find(name, "^StorePassage") ~= nil
			or string.find(name, "^Office") ~= nil
			or string.find(name, "^Lobby") ~= nil
		local sx = if interior then 1 else SCALE_X
		local sz = if interior then 1 else SCALE_Z
		local piece =
			Props.part(
				group,
				Vector3.new(size.X * sx, size.Y, size.Z * sz),
				frame * CFrame.new(x * sx, y, z * sz) * (rotation or CFrame.identity),
				color,
				material
			)
		piece.Name = name
		if decorative then
			piece.CanCollide = false
			piece.CanQuery = false
		end
		return piece
	end
	local function text(
		group: Instance,
		name: string,
		value: string,
		x: number,
		y: number,
		z: number,
		width: number,
		height: number,
		back: boolean?
	)
		local board = block(group, name, Vector3.new(width, height, 0.16), x, y, z, IRON, M.WoodPlanks, nil, true)
		signText(board, if back then Enum.NormalId.Front else Enum.NormalId.Back, value)
	end
	-- The kitchen and storage floors meet beneath the partition centerline, so
	-- there are no gaps even in the doorways. Convert back through the shell scale.
	local splitX = BaseGrid.CELL_SIZE / 2
	local width, length = BaseGrid.HALF_WIDTH, BaseGrid.HALF_LENGTH
	local kitchenFloor = block(processing, "WashableFloor", Vector3.new((width + splitX) / SCALE_X, 0.16, 2 * length / SCALE_Z), (-width + splitX) / (2 * SCALE_X), 0.08, 0, TILE, M.CeramicTiles)
	block(storage, "StoreFloor", Vector3.new((width - splitX) / SCALE_X, 0.16, 2 * length / SCALE_Z), (width + splitX) / (2 * SCALE_X), 0.08, 0, rgb(148, 135, 111), M.Concrete)

	-- Wall openings are actual gaps. Windows have thin panes, never a solid hut core.
	type Opening = { x: number, width: number, bottom: number, top: number }
	local function wall(z: number, openings: { Opening }, name: string)
		local halfWidth = 23
		local cursor = -halfWidth
		for _, opening in openings do
			local left, right = opening.x - opening.width / 2, opening.x + opening.width / 2
			if left > cursor then
				block(
					shell,
					name,
					Vector3.new(left - cursor, 11.5, 0.65),
					(cursor + left) / 2,
					5.75,
					z,
					PLASTER,
					M.Plaster
				)
			end
			if opening.bottom > 0 then
				block(
					shell,
					name .. "SillWall",
					Vector3.new(opening.width, opening.bottom, 0.65),
					opening.x,
					opening.bottom / 2,
					z,
					PLASTER,
					M.Plaster
				)
			end
			block(
				shell,
				name .. "Lintel",
				Vector3.new(opening.width, 11.5 - opening.top, 0.65),
				opening.x,
				(11.5 + opening.top) / 2,
				z,
				PLASTER,
				M.Plaster
			)
			cursor = right
		end
		if cursor < halfWidth then
			block(shell, name, Vector3.new(halfWidth - cursor, 11.5, 0.65), (cursor + halfWidth) / 2, 5.75, z, PLASTER, M.Plaster)
		end
	end
	-- The front doorway sits on the house centerline and opens into the shared
	-- vestibule between the kitchen and stores.
	local doorX, doorWidth = 0, 10.5 / SCALE_X
	-- The rear door opens into the kitchen, clear of the storage partition.
	local rearDoorX = -BaseGrid.CELL_SIZE / 2 / SCALE_X
	wall(15, {
		{ x = -13, width = 10, bottom = 3, top = 8.7 },
		{ x = doorX, width = doorWidth, bottom = 0, top = 8.8 },
		{ x = 13, width = 10, bottom = 3, top = 8.7 },
	}, "FrontWall")
	wall(-15, {
		{ x = -13, width = 7, bottom = 4, top = 8.3 },
		{ x = rearDoorX, width = 6, bottom = 0, top = 8.5 },
		{ x = 13, width = 7, bottom = 4, top = 8.3 },
	}, "RearWall")
	for _, x in { -23, 23 } do
		block(shell, "SideWall", Vector3.new(0.65, 11.5, 30), x, 5.75, 0, PLASTER, M.Plaster)
		block(shell, "SidePlinth", Vector3.new(0.82, 0.75, 30), x, 0.5, 0, STONE, M.Slate)
		block(shell, "EavesBeam", Vector3.new(0.5, 0.55, 32.5), x, 11.4, 0, DARK_WOOD, M.Wood)
		for _, z in { -14.4, 0.5, 14.4 } do
			block(shell, "TimberPost", Vector3.new(0.9, 10.8, 0.9), x * 0.97, 5.4, z, WOOD, M.Wood)
		end
	end
	-- Kitchen/storage divider and its two-cell-wide cross passage, both aligned
	-- to cell boundaries. The wider opening leaves room to turn through the grid.
	-- Stop at the lobby's back wall; storage connects to the kitchen here.
	local passageBack, passageFront = -2.5 * BaseGrid.CELL_SIZE, -0.5 * BaseGrid.CELL_SIZE
	block(shell, "StorePartitionRear", Vector3.new(0.55, 11.5, passageBack + length), splitX, 5.75, (passageBack - length) / 2, PLASTER, M.Plaster)
	local dividerFront = 1.5 * BaseGrid.CELL_SIZE
	block(shell, "StorePartitionFront", Vector3.new(0.55, 11.5, dividerFront - passageFront), splitX, 5.75, (dividerFront + passageFront) / 2, PLASTER, M.Plaster)
	block(shell, "StorePassageLintel", Vector3.new(0.55, 3, passageFront - passageBack), splitX, 10, (passageFront + passageBack) / 2, PLASTER, M.Plaster)

	-- Enclose the front entrance. The lobby's east wall sits beyond the entire
	-- exterior doorway, with a doorway into storage opposite the office door.
	local lobbyBack, lobbyEast = dividerFront, 1.5 * BaseGrid.CELL_SIZE
	local lobbyDoorLow, lobbyDoorHigh, lobbyDoorTop = 2 * BaseGrid.CELL_SIZE, 3 * BaseGrid.CELL_SIZE, 8.5
	local lobbyWest = -1.5 * BaseGrid.CELL_SIZE
	block(shell, "LobbyFloor", Vector3.new(lobbyEast - lobbyWest, 0.02, length - lobbyBack), (lobbyWest + lobbyEast) / 2, 0.17, (lobbyBack + length) / 2, WOOD, M.WoodPlanks, nil, true)
	block(shell, "LobbyBackWall", Vector3.new(lobbyEast - lobbyWest, 11.5, 0.55), (lobbyWest + lobbyEast) / 2, 5.75, lobbyBack, PLASTER, M.Plaster)
	block(shell, "LobbyEastWallRear", Vector3.new(0.55, 11.5, lobbyDoorLow - lobbyBack), lobbyEast, 5.75, (lobbyBack + lobbyDoorLow) / 2, PLASTER, M.Plaster)
	block(shell, "LobbyEastWallFront", Vector3.new(0.55, 11.5, length - lobbyDoorHigh), lobbyEast, 5.75, (lobbyDoorHigh + length) / 2, PLASTER, M.Plaster)
	block(shell, "LobbyDoorLintel", Vector3.new(0.55, 11.5 - lobbyDoorTop, lobbyDoorHigh - lobbyDoorLow), lobbyEast, (11.5 + lobbyDoorTop) / 2, (lobbyDoorLow + lobbyDoorHigh) / 2, PLASTER, M.Plaster)
	for _, z in { lobbyDoorLow, lobbyDoorHigh } do
		block(shell, "LobbyDoorJamb", Vector3.new(0.9, lobbyDoorTop, 0.28), lobbyEast, lobbyDoorTop / 2, z, WOOD, M.Wood)
	end
	block(shell, "LobbyDoorHeader", Vector3.new(0.9, 0.3, lobbyDoorHigh - lobbyDoorLow + 0.6), lobbyEast, lobbyDoorTop + 0.15, (lobbyDoorLow + lobbyDoorHigh) / 2, WOOD, M.Wood)

	-- The office fills the kitchen's front-left corner. Its back and east walls
	-- meet the exterior shell and leave a doorway facing the entrance vestibule.
	local office = model(house, "Office")
	office:SetAttribute("RoomType", "Office")
	local officeBack, officeEast = 0.5 * BaseGrid.CELL_SIZE, -1.5 * BaseGrid.CELL_SIZE
	local officeDoorZ, officeDoorWidth, officeDoorTop = 2.5 * BaseGrid.CELL_SIZE, BaseGrid.CELL_SIZE, 8.5
	local doorLow, doorHigh = officeDoorZ - officeDoorWidth / 2, officeDoorZ + officeDoorWidth / 2
	block(
		office,
		"OfficeFloor",
		Vector3.new(width + officeEast, 0.02, length - officeBack),
		(-width + officeEast) / 2,
		0.17,
		(length + officeBack) / 2,
		WOOD,
		M.WoodPlanks,
		nil,
		true
	)
	block(
		shell,
		"OfficeBackWall",
		Vector3.new(width + officeEast, 11.5, 0.55),
		(-width + officeEast) / 2,
		5.75,
		officeBack,
		PLASTER,
		M.Plaster
	)
	block(
		shell,
		"OfficeEastWallRear",
		Vector3.new(0.55, 11.5, doorLow - officeBack),
		officeEast,
		5.75,
		(officeBack + doorLow) / 2,
		PLASTER,
		M.Plaster
	)
	block(
		shell,
		"OfficeEastWallFront",
		Vector3.new(0.55, 11.5, length - doorHigh),
		officeEast,
		5.75,
		(doorHigh + length) / 2,
		PLASTER,
		M.Plaster
	)
	block(
		shell,
		"OfficeDoorLintel",
		Vector3.new(0.55, 11.5 - officeDoorTop, officeDoorWidth),
		officeEast,
		(11.5 + officeDoorTop) / 2,
		officeDoorZ,
		PLASTER,
		M.Plaster
	)
	for _, z in { doorLow, doorHigh } do
		block(shell, "OfficeDoorJamb", Vector3.new(0.9, officeDoorTop, 0.28), officeEast, officeDoorTop / 2, z, WOOD, M.Wood)
	end
	block(
		shell,
		"OfficeDoorHeader",
		Vector3.new(0.9, 0.3, officeDoorWidth + 0.6),
		officeEast,
		officeDoorTop + 0.15,
		officeDoorZ,
		WOOD,
		M.Wood
	)
	local officeSign = block(
		office,
		"OfficeSign",
		Vector3.new(3.5, 0.8, 0.16),
		officeEast + 0.34,
		7.8,
		officeDoorZ,
		IRON,
		M.WoodPlanks,
		CFrame.Angles(0, math.pi / 2, 0),
		true
	)
	signText(officeSign, Enum.NormalId.Back, "OFFICE")
	-- The desk, the shop's freezer and its till are the owner's furniture
	-- (FurnitureService, AnglerData.FIXTURES), so build mode can move them.

	-- Recessed windows, divided lights, deep stone sills, and opened shutters.
	-- Avoid refractive Glass so the sea remains visible through the glazing.
	for _, z in { -15, 15 } do
		local front = z > 0
		local width = if front then 10 else 7
		local bottom, top = if front then 3 else 4, if front then 8.7 else 8.3
		for _, x in { -13, 13 } do
			local glass = block(
				shell,
				"WindowGlass",
				Vector3.new(width, top - bottom, 0.12),
				x,
				(bottom + top) / 2,
				z,
				rgb(105, 165, 175),
				M.SmoothPlastic,
				nil,
				true
			)
			glass.Transparency = 0.68
			for _, dx in { -width / 2, 0, width / 2 } do
				block(
					shell,
					"WindowMullion",
					Vector3.new(0.16, top - bottom + 0.2, 0.32),
					x + dx,
					(bottom + top) / 2,
					z,
					CREAM,
					M.Wood,
					nil,
					true
				)
			end
			for _, y in { bottom, (bottom + top) / 2, top } do
				block(shell, "WindowRail", Vector3.new(width, 0.17, 0.32), x, y, z, CREAM, M.Wood, nil, true)
			end
			block(
				shell,
				"StoneSill",
				Vector3.new(width + 0.6, 0.24, 1.15),
				x,
				bottom - 0.1,
				z,
				STONE,
				M.Slate,
				nil,
				true
			)
			if front then
				for _, side in { -1, 1 } do
					if x > 0 and side < 0 then
						-- This shutter would swing across the storage doorway.
						continue
					end
					block(
						shell,
						"OpenShutter",
						Vector3.new(1.7, 5.7, 0.3),
						x + side * 6,
						5.85,
						z + 0.65,
						accent,
						M.WoodPlanks,
						CFrame.Angles(0, side * 0.22, 0),
						true
					)
				end
			end
		end
	end
	for _, z in { 15, -15 } do
		local x, openingWidth = if z > 0 then doorX else rearDoorX, if z > 0 then doorWidth else 6
		for _, side in { -1, 1 } do
			block(shell, "DoorJamb", Vector3.new(0.28, 8.7, 0.9), x + side * (openingWidth / 2 + 0.16), 4.35, z, WOOD, M.Wood)
		end
		block(shell, "DoorHeader", Vector3.new(openingWidth + 0.6, 0.3, 0.9), x, 8.85, z, WOOD, M.Wood)
	end
	block(shell, "EntranceStep", Vector3.new(doorWidth, 0.2, 1.8), doorX, 0.06, 15.6, STONE, M.Slate)
	block(shell, "FrontApproachStep", Vector3.new(doorWidth, 0.4, 2.2), doorX, -0.45, 17.6, STONE, M.Slate)
	block(shell, "RearLanding", Vector3.new(7, 0.3, 3.2), rearDoorX, 0, -16.2, STONE, M.Slate)
	block(shell, "RearStep", Vector3.new(7, 0.4, 1.8), rearDoorX, -0.45, -18.2, STONE, M.Slate)

	-- Pitched terracotta roof, separate rafters, tile courses, ridge caps and gutters.
	local pitch = math.atan2(4.8, 24)
	for _, side in { -1, 1 } do
		local tilt = CFrame.Angles(0, 0, -side * pitch)
		block(shell, "RoofSlope", Vector3.new(24.5, 0.45, 33), side * 12, 14.05, 0, TERRACOTTA, M.RoofShingles, tilt)
		for course = 0, 11 do
			local x = (course + 0.5) * 2
			block(
				shell,
				"TileCourse",
				Vector3.new(0.16, 0.18, 33.1),
				side * x,
				16.68 - x * 0.2,
				0,
				rgb(191, 96, 60),
				M.Brick,
				tilt,
				true
			)
		end
		block(shell, "RainGutter", Vector3.new(0.4, 0.35, 33.4), side * 24.1, 11.6, 0, IRON, M.Metal, nil, true)
	end
	block(shell, "RidgeCap", Vector3.new(0.8, 0.55, 33.4), 0, 16.55, 0, rgb(195, 101, 66), M.Brick)
	for _, z in { -15, 15 } do
		for row = 0, 7 do
			block(shell, "Gable", Vector3.new(45.5 - row * 5.7, 0.6, 0.65), 0, 11.55 + row * 0.6, z, PLASTER, M.Plaster)
		end
		for _, side in { -1, 1 } do
			block(
				shell,
				"BargeBoard",
				Vector3.new(24.5, 0.4, 0.6),
				side * 12,
				14.05,
				z + math.sign(z) * 1.3,
				CREAM,
				M.Wood,
				CFrame.Angles(0, 0, -side * pitch),
				true
			)
		end
	end
	for _, z in { -10, 0, 10 } do
		block(shell, "CeilingTie", Vector3.new(45, 0.45, 0.4), 0, 11.1, z, DARK_WOOD, M.Wood)
	end
	block(shell, "Downpipe", Vector3.new(0.22, 10.8, 0.22), -23.7, 5.8, -13, IRON, M.Metal, nil, true)
	text(shell, "HouseSign", "KITCHEN & STORES  /  " .. string.format("%02d", index), 0, 10.45, 15.5, 20, 1.8)
	-- Striped canvas awning above the open entrance.
	for stripe = -5, 5 do
		block(
			shell,
			"AwningStripe",
			Vector3.new(1.65, 0.15, 3.6),
			doorX + stripe * 1.65,
			9.2,
			17,
			if stripe % 2 == 0 then accent else CREAM,
			M.Fabric,
			CFrame.Angles(0.12, 0, 0),
			true
		)
		block(
			shell,
			"AwningValance",
			Vector3.new(1.65, 0.5, 0.12),
			doorX + stripe * 1.65,
			8.8,
			18.75,
			if stripe % 2 == 0 then accent else CREAM,
			M.Fabric,
			nil,
			true
		)
	end

	-- The structural floor is the queryable reference for the plot, not an invisible blocker.
	house.PrimaryPart = kitchenFloor
	repairOverlappingSurfaces(house)
	buildShop(house, frame, accent, index)
	ensureLights(house, frame)
	ensureExterior(house, frame, accent)
	Props.simplifyHouseCollision(house)
	return house
end

-- Leave ownership and all boating objects intact when upgrading a baked plot.
function BaseHouse.ensure(base: Model)
	-- Saved plots may already have the current house but still show the old circle.
	local savedPad = base:FindFirstChild("ClaimPad")
	if savedPad and savedPad:IsA("BasePart") then
		for _, child in base:GetChildren() do
			if
				child:IsA("BasePart")
				and (
					child == savedPad
					or (
						child:IsA("Part")
						and child.Shape == Enum.PartType.Cylinder
						and (child.Position - savedPad.Position).Magnitude < 0.5
						and child.Size.Y > 10
					)
				)
			then
				child.Transparency = 1
				child.CanCollide = false
				child.CanTouch = false
				child.CanQuery = false
			end
		end
	end
	local existing = base:FindFirstChild("BaseHouse")
	if existing and existing:GetAttribute("LayoutVersion") == VERSION then
		repairOverlappingSurfaces(existing)
		-- Earlier shells tilted the canvas upward at its outer edge, leaving it
		-- detached from the valance. Repair the saved pieces without rebuilding.
		if existing:GetAttribute("AwningVersion") ~= AWNING_VERSION then
			local shell = existing:FindFirstChild("Shell")
			if shell then
				for _, piece in shell:GetChildren() do
					if piece:IsA("BasePart") and piece.Name == "AwningStripe" then
						piece.CFrame *= CFrame.Angles(0.24, 0, 0)
					end
				end
				existing:SetAttribute("AwningVersion", AWNING_VERSION)
			end
		end
		local sign = existing:FindFirstChild("ShopSign", true)
		local gui = sign and sign:FindFirstChildWhichIsA("SurfaceGui")
		if gui then
			gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
			gui.CanvasSize = Vector2.new(sign.Size.X * 20, sign.Size.Y * 20)
			local label = gui:FindFirstChildWhichIsA("TextLabel", true)
			if label then
				label.TextScaled = true
				label.TextWrapped = false
				label.Size = UDim2.new(1, -24, 1, -12)
				label.Position = UDim2.fromOffset(12, 6)
			end
		end
		local shop = existing:FindFirstChild("Shop")
		local houseFrame = existing:GetAttribute("HouseFrame")
		if shop and shop:IsA("Model") and typeof(houseFrame) == "CFrame" then
			-- Saved maps still hold the old built-in fixtures; they are furniture now.
			local office = existing:FindFirstChild("Office")
			for _, fixture in { shop:FindFirstChild("FishFreezer"), shop:FindFirstChild("ShopDesk"), office and office:FindFirstChild("OfficeDesk") } do
				if fixture then
					fixture:Destroy()
				end
			end
			ensureLights(existing, houseFrame)
		end
		if typeof(houseFrame) == "CFrame" then
			-- The front shutters carry the plot's accent colour.
			local shutter = existing:FindFirstChild("Shell") and existing.Shell:FindFirstChild("OpenShutter")
			local accent = if shutter and shutter:IsA("BasePart") then shutter.Color else rgb(40, 120, 156)
			ensureExterior(existing, houseFrame, accent)
		end
		Props.simplifyHouseCollision(existing)
		return
	end
	local dockFrame = base:GetAttribute("BoatDockFrame")
	local spawn = base:FindFirstChild("SpawnPoint")
	if typeof(dockFrame) ~= "CFrame" and spawn and spawn:IsA("SpawnLocation") then
		-- Original Harbour spawn: cf(-26,4,6.1). Recover before moving it.
		dockFrame = spawn.CFrame * CFrame.new(-4, -6.1, -26)
		base:SetAttribute("BoatDockFrame", dockFrame)
	end
	if typeof(dockFrame) ~= "CFrame" then
		return
	end
	local claim = base:FindFirstChild("ClaimPad")
	local accent = if claim and claim:IsA("BasePart") then claim.Color else rgb(40, 120, 156)
	if existing then
		existing:Destroy()
	end
	for _, child in base:GetChildren() do
		if child.Name == "Hut" or child.Name == "FishRack" or child.Name == "Bench" then
			child:Destroy()
		end
	end
	local frame = dockFrame :: CFrame
	BaseHouse.build(base, frame * CFrame.new(0, 5.9, 43), accent, base:GetAttribute("BaseId") or 1)
	if spawn and spawn:IsA("SpawnLocation") then
		spawn.CFrame = frame * CFrame.new(4, 6.1, 20)
	end
	if claim and claim:IsA("BasePart") then
		-- Keep the original claim ring and pad together on the clear front apron.
		local oldPosition = claim.Position
		local newPosition = (frame * CFrame.new(-12, 6.05, 21)).Position
		for _, child in base:GetChildren() do
			if
				child:IsA("Part")
				and child.Shape == Enum.PartType.Cylinder
				and child ~= claim
				and (child.Position - oldPosition).Magnitude < 0.5
				and child.Size.Y > 10
			then
				child.CFrame += newPosition - oldPosition
			end
		end
		claim.CFrame += newPosition - oldPosition
	end
end

return BaseHouse
