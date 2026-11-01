-- Admin-only showcase of full-size models, reached only with /tp models. It floats in its own patch
-- of sea 4,000 studs west of the map, outside Biomes.inOceanBounds: driven boats stop at the ocean's
-- edge (BoatService), so nothing can sail here and nobody can swim the empty gap.
--
-- The ship streams in pinned pieces: under memory pressure the client throws out everything past
-- StreamingMinRadius, which is the whole ship seen from the pier. Pieces are PersistentPerPlayer,
-- so only an admin who goes there downloads them, and small, so they arrive without a hitch.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local MscPreziosa = require(script.Parent.MscPreziosa)

local ScaleModels = {}
-- Bump to rebuild a model saved in the place
ScaleModels.VERSION = 8
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

local function buildPier(folder: Folder): Model
	local pier = Instance.new("Model")
	pier.Name = "ModelsPier"
	local wood, post = Color3.fromRGB(150, 110, 72), Color3.fromRGB(96, 70, 48)
	plank(pier, "PierDeck", Vector3.new(48, 1, 20), PIER + Vector3.new(0, 2, 0), wood, Enum.Material.WoodPlanks)
	for _, x in { -22, 22 } do
		for _, z in { -8, 8 } do
			plank(pier, "PierPost", Vector3.new(1.6, 14, 1.6), PIER + Vector3.new(x, -4, z), post, Enum.Material.Wood)
		end
		plank(pier, "PierRail", Vector3.new(0.6, 3, 20), PIER + Vector3.new(x, 4, 0), post, Enum.Material.Wood)
	end
	plank(pier, "PierRail", Vector3.new(48, 3, 0.6), PIER + Vector3.new(0, 4, 9.7), post, Enum.Material.Wood)
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

-- The pier is small and never yields, so /tp models can put it up on the spot when the build
-- has not reached it yet
function ScaleModels.ensurePier(): BasePart
	local folder = ensureFolder()
	local pier = folder:FindFirstChild("ModelsPier") or buildPier(folder)
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
	if not folder:FindFirstChild("ModelsPier") then
		buildPier(folder)
	end
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
