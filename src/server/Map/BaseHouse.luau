-- Empty player-base shell. Local +Z is the front; the deck is y=0.
-- The same builder is used for fresh plots and upgrades to a saved map.
local Props = require(script.Parent.Props)
local FishFreezer = require(script.Parent.FishFreezer)
local ShopDesk = require(script.Parent.ShopDesk)

local BaseHouse = {}
local VERSION = 4
local LIGHTING_VERSION = 2
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
			Shop = { Vector3.new(-15, 0, 10), Vector3.new(0, 0, 10), Vector3.new(15, 0, 10) },
			Processing = { Vector3.new(-16, 0, -10), Vector3.new(-4, 0, -10) },
			Storage = { Vector3.new(8, 0, -10), Vector3.new(18, 0, -10) },
		}
	do
		local room = house:FindFirstChild(roomName)
		if not room then
			continue
		end
		local existing = room:FindFirstChild("CeilingLights")
		if existing and existing:GetAttribute("LayoutVersion") == LIGHTING_VERSION then
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
			glow.Parent = bulb
		end
	end
end

function BaseHouse.build(parent: Instance, frame: CFrame, accent: Color3, index: number): Model
	local house = model(parent, "BaseHouse")
	house:SetAttribute("LayoutVersion", VERSION)
	house:SetAttribute("BaseId", index)
	house:SetAttribute("HouseFrame", frame)
	local shell = model(house, "Shell")
	local shop = model(house, "Shop")
	local processing = model(house, "Processing")
	local storage = model(house, "Storage")
	shop:SetAttribute("RoomType", "Shop")
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
		local piece =
			Props.part(group, size, frame * CFrame.new(x, y, z) * (rotation or CFrame.identity), color, material)
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
		local gui = Instance.new("SurfaceGui")
		gui.Face = if back then Enum.NormalId.Front else Enum.NormalId.Back
		-- Match the canvas to the physical board so glyphs retain their proportions.
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(math.round(width * 20), math.round(height * 20))
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
	-- Preserve the original room floors and connecting passage.
	local shopFloor = block(shop, "ShopFloor", Vector3.new(45.3, 0.16, 14), 0, 0.08, 7.65, WOOD, M.WoodPlanks)
	block(processing, "WashableFloor", Vector3.new(25.3, 0.16, 15.3), -10, 0.08, -7, TILE, M.CeramicTiles)
	block(storage, "StoreFloor", Vector3.new(19.3, 0.16, 15.3), 13, 0.08, -7, rgb(148, 135, 111), M.Concrete)
	block(shell, "PassageFloor", Vector3.new(0.7, 0.16, 6), 3, 0.08, -7, TILE, M.CeramicTiles)

	-- Wall openings are actual gaps. Windows have thin panes, never a solid hut core.
	type Opening = { x: number, width: number, bottom: number, top: number }
	local function wall(z: number, openings: { Opening }, name: string)
		local cursor = -23
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
		if cursor < 23 then
			block(shell, name, Vector3.new(23 - cursor, 11.5, 0.65), (cursor + 23) / 2, 5.75, z, PLASTER, M.Plaster)
		end
	end
	wall(15, {
		{ x = -13, width = 10, bottom = 3, top = 8.7 },
		{ x = 0, width = 7, bottom = 0, top = 8.8 },
		{ x = 13, width = 10, bottom = 3, top = 8.7 },
	}, "FrontWall")
	wall(-15, {
		{ x = -13, width = 7, bottom = 4, top = 8.3 },
		{ x = 0, width = 6, bottom = 0, top = 8.5 },
		{ x = 13, width = 7, bottom = 4, top = 8.3 },
	}, "RearWall")
	wall(1, {
		{ x = -10, width = 6, bottom = 0, top = 8.5 },
		{ x = 12, width = 6, bottom = 0, top = 8.5 },
	}, "RoomPartition")
	for _, x in { -23, 23 } do
		block(shell, "SideWall", Vector3.new(0.65, 11.5, 30), x, 5.75, 0, PLASTER, M.Plaster)
		block(shell, "SidePlinth", Vector3.new(0.82, 0.75, 30), x, 0.5, 0, STONE, M.Slate)
		block(shell, "EavesBeam", Vector3.new(0.5, 0.55, 32.5), x, 11.4, 0, DARK_WOOD, M.Wood)
		for _, z in { -14.4, 0.5, 14.4 } do
			block(shell, "TimberPost", Vector3.new(0.9, 10.8, 0.9), x * 0.97, 5.4, z, WOOD, M.Wood)
		end
	end
	-- Rear room divider, with a six-stud cross passage at z=-7.
	block(shell, "StorePartitionRear", Vector3.new(0.55, 11.5, 5), 3, 5.75, -12.5, PLASTER, M.Plaster)
	block(shell, "StorePartitionFront", Vector3.new(0.55, 11.5, 5), 3, 5.75, -1.5, PLASTER, M.Plaster)
	block(shell, "StorePassageLintel", Vector3.new(0.55, 3, 6), 3, 10, -7, PLASTER, M.Plaster)

	-- Recessed shop windows, divided lights, deep stone sills, and opened shutters.
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
		local doorWidth = if z > 0 then 7 else 6
		for _, side in { -1, 1 } do
			block(shell, "DoorJamb", Vector3.new(0.28, 8.7, 0.9), side * (doorWidth / 2 + 0.16), 4.35, z, WOOD, M.Wood)
		end
		block(shell, "DoorHeader", Vector3.new(doorWidth + 0.6, 0.3, 0.9), 0, 8.85, z, WOOD, M.Wood)
	end
	block(shell, "EntranceStep", Vector3.new(7, 0.2, 1.8), 0, 0.06, 15.6, STONE, M.Slate)
	block(shell, "FrontApproachStep", Vector3.new(7, 0.4, 2.2), 0, -0.45, 17.6, STONE, M.Slate)
	block(shell, "RearLanding", Vector3.new(7, 0.3, 2.6), 0, 0, -16.2, STONE, M.Slate)
	block(shell, "RearStep", Vector3.new(7, 0.4, 1.8), 0, -0.45, -18.2, STONE, M.Slate)

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
	text(shell, "ShopSign", "FISH & TACKLE  /  " .. string.format("%02d", index), 0, 10.45, 15.5, 20, 1.8)
	-- Striped canvas awning above the open entrance.
	for stripe = -5, 5 do
		block(
			shell,
			"AwningStripe",
			Vector3.new(1.65, 0.15, 3.6),
			stripe * 1.65,
			9.2,
			17,
			if stripe % 2 == 0 then accent else CREAM,
			M.Fabric,
			CFrame.Angles(-0.12, 0, 0),
			true
		)
		block(
			shell,
			"AwningValance",
			Vector3.new(1.65, 0.5, 0.12),
			stripe * 1.65,
			8.8,
			18.75,
			if stripe % 2 == 0 then accent else CREAM,
			M.Fabric,
			nil,
			true
		)
	end

	-- The structural floor is the queryable reference for the plot, not an invisible blocker.
	house.PrimaryPart = shopFloor
	FishFreezer.ensure(shop, frame)
	ShopDesk.ensure(shop, frame)
	ensureLights(house, frame)
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
		local sign = existing:FindFirstChild("ShopSign", true)
		local gui = sign and sign:FindFirstChildWhichIsA("SurfaceGui")
		if gui then
			gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
			gui.CanvasSize = Vector2.new(400, 36)
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
			FishFreezer.ensure(shop, houseFrame)
			ShopDesk.ensure(shop, houseFrame)
			ensureLights(existing, houseFrame)
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
