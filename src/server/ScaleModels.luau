-- Admin-only showcase of full-size models, reached only with /tp models. It floats in its own patch
-- of sea 4,000 studs west of the map, outside Biomes.inOceanBounds: driven boats stop at the ocean's
-- edge (BoatService), so nothing can sail here and nobody can swim the empty gap.
--
-- Off the pier's east end a pet deck shows pets (PetModels), animated on each client by
-- ShowcasePets.
--
-- The ship streams in pinned pieces: under memory pressure the client throws out everything past
-- StreamingMinRadius, which is the whole ship seen from the pier. Pieces are PersistentPerPlayer,
-- so only an admin who goes there downloads them, and small, so they arrive without a hitch.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local PetModels = require(ReplicatedStorage.Shared.PetModels)
local MscPreziosa = require(script.Parent.MscPreziosa)

local ScaleModels = {}
-- Bump to rebuild a model saved in the place
ScaleModels.VERSION = 9
-- Bump to rebuild the pier (and its pet deck) saved in the place
ScaleModels.PIER_VERSION = 2
ScaleModels.ORIGIN = Vector3.new(-9500, Biomes.WaterLevel, 0)

local Terrain = workspace.Terrain
local WATER_HALF = Vector3.new(1100, 0, 700)
-- Small enough that one tile of water fills well within a frame
local TILE = 256
-- The pier sits off the starboard side amidships, far enough out to take in the whole ship
local PIER = ScaleModels.ORIGIN + Vector3.new(0, 0, 95 * MscPreziosa.STUDS)
local PIECE_PARTS = 200 -- as many parts as one pinned piece may hold (as for the islands)
local PINS_PER_FRAME = 2

local pieces: { Model } = {}
-- Players who went to the models; they keep the pieces pinned until they leave
local visitors: { [Player]: boolean } = {}

local function fillWater()
	local lo, hi = ScaleModels.ORIGIN - WATER_HALF, ScaleModels.ORIGIN + WATER_HALF
	local depth = Biomes.WaterLevel - Biomes.SeaFloor
	for x = lo.X, hi.X - 1, TILE do
		for z = lo.Z, hi.Z - 1, TILE do
			local sx, sz = math.min(TILE, hi.X - x), math.min(TILE, hi.Z - z)
			local cx, cz = x + sx / 2, z + sz / 2
			Terrain:FillBlock(
				CFrame.new(cx, Biomes.WaterLevel - depth / 2, cz),
				Vector3.new(sx, depth, sz),
				Enum.Material.Water
			)
			Terrain:FillBlock(CFrame.new(cx, Biomes.SeaFloor - 4, cz), Vector3.new(sx, 8, sz), Enum.Material.Rock)
			task.wait()
		end
	end
end

local function hasWater(): boolean
	local probe = PIER + Vector3.new(0, -8, 40)
	local region = Region3.new(probe - Vector3.one * 2, probe + Vector3.one * 2):ExpandToGrid(4)
	local ok, voxels = pcall(Terrain.ReadVoxels, Terrain, region, 4)
	return ok and voxels[1][1][1] == Enum.Material.Water
end

local function plank(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Anchored = true
	p.CanTouch = false
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A sign board facing `facing` whose SurfaceGui matches its physical size, so glyphs keep their
-- proportions
local function signBoard(
	parent: Instance,
	name: string,
	size: Vector3,
	center: Vector3,
	facing: Vector3,
	color: Color3,
	text: string,
	textColor: Color3,
	font: Enum.Font
): Part
	local board = plank(parent, name, size, center, color, Enum.Material.SmoothPlastic)
	board.CFrame = CFrame.lookAt(center, center + facing)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(size.X * 40, size.Y * 40)
	gui.LightInfluence = 0.4
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -24, 1, -12)
	label.Position = UDim2.new(0, 12, 0, 6)
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextScaled = true
	label.TextWrapped = false
	label.TextColor3 = textColor
	label.Text = text
	label.Parent = gui
	return board
end

-- The pet deck off the pier's east end: a perch stand with the animated scarlet macaw, its
-- plaque, and room along the deck for more pets. Everything stands on `top` (the deck surface
-- at the deck's centre); visitors come in from the pier, to the west.
local function buildPets(pier: Model, top: Vector3)
	local pets = Instance.new("Model")
	pets.Name = "PetsSection"
	local rgb = Color3.fromRGB
	local wood, dark, cream = rgb(150, 110, 72), rgb(84, 58, 38), rgb(255, 245, 213)
	local teal = rgb(36, 112, 120)
	local function cylinder(name: string, length: number, d: number, frame: CFrame, color: Color3, material: Enum.Material): Part
		local p = plank(pets, name, Vector3.new(length, d, d), frame.Position, color, material)
		p.Shape = Enum.PartType.Cylinder
		p.CFrame = frame
		return p
	end
	local upright = CFrame.Angles(0, 0, math.pi / 2)

	-- Header sign at the far end, facing the pier, striped in the macaw's colours
	local signAt = top + Vector3.new(11.6, 0, 0)
	for _, z in { -4.6, 4.6 } do
		plank(pets, "PetsSignPost", Vector3.new(0.6, 8.6, 0.6), signAt + Vector3.new(0.5, 4.3, z), dark, Enum.Material.Wood)
	end
	signBoard(pets, "PetsSign", Vector3.new(9.8, 2.6, 0.4), signAt + Vector3.new(0, 7, 0), -Vector3.xAxis, teal, "PETS", cream, Enum.Font.FredokaOne)
	for i, color in { rgb(206, 26, 32), rgb(255, 204, 28), rgb(34, 92, 206) } do
		local stripe = plank(pets, "PetsSignStripe", Vector3.new(9.8 / 3, 0.35, 0.42), signAt, color, Enum.Material.SmoothPlastic)
		stripe.CFrame = CFrame.lookAt(signAt + Vector3.new(0, 5.5, (i - 2) * 9.8 / 3), signAt + Vector3.new(-1, 5.5, (i - 2) * 9.8 / 3))
	end

	-- T-perch stand. It faces west (-X) like the macaw, so its local X (the perch bar) runs
	-- across the deck.
	local stand = CFrame.lookAt(top, top - Vector3.xAxis)
	local SCALE = 1.25
	local barRadius = PetModels.PERCH_RADIUS * SCALE
	local barY = 3.9
	cylinder("PerchBase", 0.3, 2.4, stand * CFrame.new(0, 0.15, 0) * upright, dark, Enum.Material.Wood)
	cylinder("PerchPole", 3.75, 0.32, stand * CFrame.new(0, 0.3 + 3.75 / 2, 0) * upright, wood, Enum.Material.Wood)
	cylinder("PerchBar", 2.8, barRadius * 2, stand * CFrame.new(0, barY, 0), wood, Enum.Material.Wood)
	for _, x in { -1.4, 1.4 } do
		local cap = plank(pets, "PerchCap", Vector3.new(0.34, 0.34, 0.34), (stand * Vector3.new(x, barY, 0)), dark, Enum.Material.Wood)
		cap.Shape = Enum.PartType.Ball
	end
	-- Food and water cups hanging under each end of the bar
	for i, x in { -1.05, 1.05 } do
		local cup = stand * CFrame.new(x, barY - 0.38, 0)
		cylinder("PerchCupHanger", 0.3, 0.06, cup * CFrame.new(0, 0.22, 0) * upright, rgb(180, 180, 186), Enum.Material.Metal)
		cylinder("PerchCup", 0.28, 0.5, cup * upright, rgb(200, 200, 206), Enum.Material.Metal)
		if i == 1 then
			local rng = Random.new(512)
			local seeds = { rgb(236, 214, 150), rgb(96, 70, 48), rgb(240, 150, 40), rgb(120, 170, 70) }
			for k = 1, 9 do
				local angle, r = k * 2.4, 0.06 + (k % 3) * 0.05
				local seed = plank(pets, "PerchSeed", Vector3.new(0.09, 0.09, 0.09), (cup * Vector3.new(math.cos(angle) * r, 0.14, math.sin(angle) * r)), seeds[rng:NextInteger(1, #seeds)], Enum.Material.SmoothPlastic)
				seed.Shape = Enum.PartType.Ball
				seed.CastShadow = false
			end
			local slice = plank(pets, "PerchOrange", Vector3.new(0.3, 0.1, 0.18), (cup * Vector3.new(0.06, 0.18, -0.04)), rgb(250, 140, 30), Enum.Material.SmoothPlastic)
			slice.CFrame = cup * CFrame.new(0.06, 0.18, -0.04) * CFrame.Angles(0.3, 0.5, 0)
			slice.CastShadow = false
		else
			local water = cylinder("PerchWater", 0.04, 0.42, cup * CFrame.new(0, 0.1, 0) * upright, rgb(110, 170, 210), Enum.Material.Glass)
			water.Transparency = 0.3
		end
	end
	-- A toy of coloured wooden blocks on a rope
	local toyTop = stand * CFrame.new(-0.6, barY - barRadius, 0)
	cylinder("ToyRope", 0.9, 0.05, toyTop * CFrame.new(0, -0.45, 0) * upright, rgb(214, 190, 140), Enum.Material.Fabric)
	for k, color in { rgb(206, 26, 32), rgb(255, 204, 28), rgb(34, 92, 206) } do
		local block = plank(pets, "ToyBlock", Vector3.new(0.2, 0.2, 0.2), (toyTop * Vector3.new(0, -0.22 - k * 0.22, 0)), color, Enum.Material.Wood)
		block.CFrame = toyTop * CFrame.new(0, -0.22 - k * 0.22, 0) * CFrame.Angles(0, k * 0.6, 0)
		block.CastShadow = false
	end
	PetModels.scarletMacaw(pets, stand * CFrame.new(0, barY + barRadius, 0), SCALE)

	-- Plaque on a lectern in front of the stand, tilted up towards visitors
	local lectern = stand * CFrame.new(0, 0, -2.4)
	plank(pets, "PlaquePost", Vector3.new(0.3, 2.5, 0.3), (lectern * Vector3.new(0, 1.25, 0)), dark, Enum.Material.Wood)
	local plaque = signBoard(pets, "PetPlaque", Vector3.new(2.4, 0.8, 0.12), (lectern * Vector3.new(0, 2.6, 0)), -Vector3.xAxis, dark, "Scarlet Macaw", cream, Enum.Font.FredokaOne)
	plaque.CFrame = lectern * CFrame.new(0, 2.6, 0) * CFrame.Angles(0.6, 0, 0)

	pets.Parent = pier
end

local function buildPier(folder: Folder): Model
	local pier = Instance.new("Model")
	pier.Name = "ModelsPier"
	pier:SetAttribute("PierVersion", ScaleModels.PIER_VERSION)
	local wood, post = Color3.fromRGB(150, 110, 72), Color3.fromRGB(96, 70, 48)
	plank(pier, "PierDeck", Vector3.new(48, 1, 20), PIER + Vector3.new(0, 2, 0), wood, Enum.Material.WoodPlanks)
	for _, x in { -22, 22 } do
		for _, z in { -8, 8 } do
			plank(pier, "PierPost", Vector3.new(1.6, 14, 1.6), PIER + Vector3.new(x, -4, z), post, Enum.Material.Wood)
		end
	end
	plank(pier, "PierRail", Vector3.new(0.6, 3, 20), PIER + Vector3.new(-22, 4, 0), post, Enum.Material.Wood)
	-- The east rail opens onto the pet deck
	for _, z in { -6.5, 6.5 } do
		plank(pier, "PierRail", Vector3.new(0.6, 3, 7), PIER + Vector3.new(22, 4, z), post, Enum.Material.Wood)
	end
	plank(pier, "PierRail", Vector3.new(48, 3, 0.6), PIER + Vector3.new(0, 4, 9.7), post, Enum.Material.Wood)
	-- Pet deck, carrying on east from the pier deck
	local petDeck = PIER + Vector3.new(37, 2, 0)
	plank(pier, "PetDeck", Vector3.new(26, 1, 20), petDeck, wood, Enum.Material.WoodPlanks)
	for _, x in { 36, 49 } do
		for _, z in { -8, 8 } do
			plank(pier, "PierPost", Vector3.new(1.6, 14, 1.6), PIER + Vector3.new(x, -4, z), post, Enum.Material.Wood)
		end
	end
	plank(pier, "PierRail", Vector3.new(0.6, 3, 20), PIER + Vector3.new(49.7, 4, 0), post, Enum.Material.Wood)
	plank(pier, "PierRail", Vector3.new(26, 3, 0.6), PIER + Vector3.new(37, 4, 9.7), post, Enum.Material.Wood)
	buildPets(pier, petDeck + Vector3.new(0, 0.5, 0))
	-- Where /tp models lands, facing the ship
	local arrival = plank(
		pier,
		"ModelsArrival",
		Vector3.new(2, 0.2, 2),
		PIER + Vector3.new(0, 2.6, -4),
		wood,
		Enum.Material.WoodPlanks
	)
	arrival.CFrame = CFrame.lookAt(arrival.Position, arrival.Position - Vector3.zAxis)
	arrival.Transparency = 1
	arrival.CanCollide = false
	arrival.CanQuery = false
	pier.Parent = folder
	return pier
end

local function ensureFolder(): Folder
	local folder = workspace:FindFirstChild("ScaleModels")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ScaleModels"
		folder.Parent = workspace
	end
	return folder
end

-- The pier (with its pet deck) is small and never yields, so /tp models can put it up on the spot
-- when the build has not reached it yet. A pier saved in the place by an older build is replaced.
function ScaleModels.ensurePier(): BasePart
	local folder = ensureFolder()
	local pier = folder:FindFirstChild("ModelsPier")
	if pier and pier:GetAttribute("PierVersion") ~= ScaleModels.PIER_VERSION then
		pier:Destroy()
		pier = nil
	end
	pier = pier or buildPier(folder)
	return pier:FindFirstChild("ModelsArrival") :: BasePart
end

-- Regroups each part of the model's sections into runs along the ship, PIECE_PARTS at most. It runs
-- before the model replicates, because a streaming mode set afterwards makes clients stream it again.
local function cutPieces(model: Model): { Model }
	local cut = {}
	for _, section in model:GetChildren() do
		local parts = {}
		for _, d in section:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
		if section:IsA("BasePart") then
			table.insert(parts, section)
		end
		table.sort(parts, function(a, b)
			return a.Position.X < b.Position.X
		end)
		local holder = if section:IsA("Model") then section else model
		local piece
		for i, part in parts do
			if (i - 1) % PIECE_PARTS == 0 then
				piece = Instance.new("Model")
				piece.Name = section.Name .. "Piece"
				piece.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
				piece.Parent = holder
				table.insert(cut, piece)
			end
			part.Parent = piece
		end
	end
	return cut
end

-- A few pieces a frame, so the ship builds up round the admin instead of freezing the client
local function pin(player: Player, list: { Model })
	task.spawn(function()
		for i, piece in list do
			if not visitors[player] then
				return
			end
			if piece.Parent then
				piece:AddPersistentPlayer(player)
			end
			if i % PINS_PER_FRAME == 0 then
				RunService.Heartbeat:Wait()
			end
		end
	end)
end

-- Called by /tp models. Pinned pieces stay with the player until they leave
function ScaleModels.visit(player: Player)
	if visitors[player] then
		return
	end
	visitors[player] = true
	pin(player, pieces)
end

Players.PlayerRemoving:Connect(function(player)
	visitors[player] = nil
end)

function ScaleModels.ensure(): Folder
	local folder = ensureFolder()
	-- Water and the pier come first, so /tp models works even while (or if) the ship fails to build
	if not hasWater() then
		fillWater()
	end
	ScaleModels.ensurePier()
	local ship = folder:FindFirstChild("MSC Preziosa")
	if not ship or ship:GetAttribute("ModelVersion") ~= ScaleModels.VERSION then
		if ship then
			ship:Destroy()
		end
		-- Built out of the world, so it is cut into pieces before any client sees it
		local built = MscPreziosa.build(ServerStorage, ScaleModels.ORIGIN)
		built:SetAttribute("ModelVersion", ScaleModels.VERSION)
		pieces = cutPieces(built)
		built.Parent = folder
		-- Admins who arrived while it was building
		for player in visitors do
			pin(player, pieces)
		end
	else
		for _, d in ship:GetDescendants() do
			if d:IsA("Model") and d.ModelStreamingMode == Enum.ModelStreamingMode.PersistentPerPlayer then
				table.insert(pieces, d)
			end
		end
	end
	return folder
end

return ScaleModels
