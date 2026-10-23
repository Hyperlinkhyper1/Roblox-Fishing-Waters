-- Generates the whole world: ocean, seabed, lighting and the five biomes.
-- Deterministic from Biomes.Seed, so every server builds the same map.
--
-- To bake it into the place instead of generating on every server start, run this
-- from the Studio command bar (in Edit mode), then save:
--   require(game.ServerScriptService.Server.Map).build()

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Lod = require(script.Lod)
local Regions = require(script.Regions)
local Seabed = require(script.Seabed)
local SeabedDetails = require(script.SeabedDetails)

local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))
local Map = {}

local Terrain = workspace.Terrain
local TILE = 1024

local function fillOcean(root: Folder)
	local half = Biomes.MapHalfSize
	local depth = Biomes.WaterLevel - Biomes.SeaFloor
	for x = -half, half - 1, TILE do
		for z = -half, half - 1, TILE do
			local sx, sz = math.min(TILE, half - x), math.min(TILE, half - z)
			local cx, cz = x + sx / 2, z + sz / 2
			Terrain:FillBlock(
				CFrame.new(cx, Biomes.WaterLevel - depth / 2, cz),
				Vector3.new(sx, depth, sz),
				Enum.Material.Water
			)
			Terrain:FillBlock(CFrame.new(cx, Biomes.SeaFloor - 4, cz), Vector3.new(sx, 8, sz), Enum.Material.Rock)
		end
		task.wait()
	end

	-- Biome-wide shallows (the swamp and tropics sit on raised shelves)
	for _, biome in Biomes.list do
		if biome.shelfDepth then
			Seabed.shelf(biome.center, biome.radius, biome.shelfDepth, biome.seabed, biome.seabedColor, root)
			task.wait()
		end
	end
end

local function setupEnvironment()
	local look = Biomes.Normal.look

	Terrain.WaterColor = look.waterColor
	Terrain.WaterTransparency = 0.55
	Terrain.WaterReflectance = 0.2
	Terrain.WaterWaveSize = 0.1
	Terrain.WaterWaveSpeed = 8
	Terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(34, 48, 56))
	Terrain:SetMaterialColor(Biomes.OpenSea.seabed, Biomes.OpenSea.seabedColor)
	for _, biome in Biomes.list do
		Terrain:SetMaterialColor(biome.seabed, biome.seabedColor)
	end

	Lighting.ClockTime = 16.6
	Lighting.Brightness = 2
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.OutdoorAmbient = look.ambient

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Color = look.atmosphereColor
	atmosphere.Decay = look.atmosphereDecay
	atmosphere.Density = look.density
	atmosphere.Haze = look.haze
	atmosphere.Glare = look.glare
	atmosphere.Offset = Biomes.DistanceFogOffset
	atmosphere.Parent = Lighting

	local clouds = Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = look.cloudCover
	clouds.Density = 0.6
	clouds.Color = look.cloudColor
	clouds.Parent = Terrain
end

-- With no callback this still finishes synchronously for the Studio bake command.
-- Live startup can open the completed harbour while distant islands are built.
function Map.build(onHarbourReady: ((Folder) -> ())?, onStage: ((string, number) -> ())?): Folder
	local started = os.clock()

	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	-- The default template's baseplate sits at sea level and would cover the ocean
	for _, name in { "Baseplate", "SpawnLocation" } do
		local leftover = workspace:FindFirstChild(name)
		if leftover then
			leftover:Destroy()
		end
	end
	Terrain:Clear()

	local root = Instance.new("Folder")
	root.Name = "Map"
	root.Parent = workspace

	setupEnvironment()
	if onStage then
		onStage("Preparing the ocean", 0.05)
	end
	fillOcean(root)
	if onStage then
		onStage("Building Gullhaven harbour", 0.25)
	end

	local placed = {}
	local function context(biome: Biomes.Biome, index: number): Regions.Context
		local folder = Instance.new("Folder")
		folder.Name = biome.name
		-- Set an island's streaming mode as it's parented, before it first replicates.
		-- Switching it once the whole map is done made every island re-stream at once.
		folder.ChildAdded:Connect(function(child)
			if child:IsA("Model") and child:FindFirstChild("Ground") then
				Lod.prepareIsland(child)
			end
		end)
		folder.Parent = root
		return { rng = Random.new(Biomes.Seed + index), biome = biome, folder = folder, placed = placed }
	end

	-- Regions.normal invokes this before generating its surrounding archipelago.
	-- It uses the same seeded RNG and placement list, preserving the complete map.
	Regions.normal(context(Biomes.Normal, 1), function(spawnCFrame)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "HarbourSpawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(6, 0.4, 6)
		spawn.CFrame = spawnCFrame
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Duration = 0
		spawn.Neutral = true
		spawn.Parent = root
		if onHarbourReady then
			onHarbourReady(root)
		end
		-- Let waiting clients and service startup run before distant generation.
		task.wait()
	end)

	Regions.swamp(context(Biomes.Swamp, 2))
	Regions.tropical(context(Biomes.Tropical, 3))
	Regions.volcanic(context(Biomes.Volcanic, 4))
	Regions.ice(context(Biomes.Ice, 5))
	Regions.openSea(context(Biomes.OpenSea, 6))
	SeabedDetails.ensure(root)
	Lod.build(root)
	Map.ensureSignText()

	local parts = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	print(string.format("[Map] Built %d parts in %.1fs", parts, os.clock() - started))
	return root
end

-- Update the streaming policy even when existing shells were baked in Studio.
function Map.prepareStreaming(root: Instance)
	Lod.prepareStreaming(root)
end

-- Also dress maps baked in Studio before underwater gardens were introduced.
function Map.ensureSeabedDetails()
	local root = workspace:FindFirstChild("Map")
	if root then
		SeabedDetails.ensure(root)
	end
end

-- Repair text on maps baked before sign canvases matched their physical faces.
-- Keep proportional fixed canvases (including the padded base-house signs).
function Map.ensureSignText()
	local root = workspace:FindFirstChild("Map")
	if not root then
		return
	end
	for _, gui in root:GetDescendants() do
		if not gui:IsA("SurfaceGui") or not gui:FindFirstChildWhichIsA("TextLabel", true) then
			continue
		end
		for _, label in gui:GetDescendants() do
			if label:IsA("TextLabel") then
				Theme.text(label, if label.TextColor3 == Theme.Colors.Green then Theme.Colors.Green else nil)
			end
		end
		local board = gui.Adornee or gui.Parent
		if not board or not board:IsA("BasePart") then
			continue
		end
		local size, face = board.Size, gui.Face
		local width = if face == Enum.NormalId.Left or face == Enum.NormalId.Right then size.Z else size.X
		local height = if face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then size.Z else size.Y
		local canvas = gui.CanvasSize
		local ratio = width / height
		if math.abs(canvas.X / canvas.Y / ratio - 1) > 0.001 then
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		end
	end
end

-- Gives a map baked before distant LODs existed its island shells.
function Map.ensureLod()
	local root = workspace:FindFirstChild("Map")
	if root then
		Lod.build(root)
	end
end

-- Starts the moving bits of a built (or baked) map: the sweeping lighthouse beam.
function Map.animate()
	local root = workspace:FindFirstChild("Map")
	if not root then
		return
	end
	for _, lens in root:GetDescendants() do
		-- Repair glazing already baked into saved maps, including current layouts
		-- whose builders correctly reuse their existing models at startup.
		if lens:IsA("BasePart") and lens.Material == Enum.Material.Glass and lens.Transparency > 0 then
			lens.Material = Enum.Material.SmoothPlastic
		end
		if lens.Name == "LighthouseLens" and lens:IsA("BasePart") then
			local pivot = lens.CFrame
			task.spawn(function()
				local angle = 0
				while lens.Parent do
					angle += task.wait() * 0.6
					lens.CFrame = pivot * CFrame.Angles(0, angle, 0)
				end
			end)
		end
	end
end

return Map
