local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Set this before requiring generators/services, which may yield while loading.
-- Characters must never arrive on an empty or partly repaired home island.
Players.CharacterAutoLoads = false
ReplicatedStorage:SetAttribute("FishingWatersWorldReady", false)
ReplicatedStorage:SetAttribute("FishingWatersGenerationComplete", false)
ReplicatedStorage:SetAttribute("FishingWatersStartupError", false)
ReplicatedStorage:SetAttribute("FishingWatersGenerationError", false)

local started = os.clock()
local function stage(message: string, progress: number)
	ReplicatedStorage:SetAttribute("FishingWatersLoadStage", message)
	ReplicatedStorage:SetAttribute("FishingWatersLoadProgress", progress)
end
stage("Preparing your harbour", 0.02)

local ok, failure = xpcall(function()
	-- Update notices and stale-server admission must work even while the map loads.
	require(script.ServerUpdates).start()
	local BaseService = require(script.BaseService)
	local Map = require(script.Map)
	local Harbour = require(script.Map.Harbour)

	local function openHarbour(root: Folder)
		stage("Getting your dock ready", 0.9)
		Map.prepareStreaming(root)
		require(script.Map.ChartCatalog).start(root)
		require(script.WeatherService).start()
		-- Install inventory/character listeners and remotes before BaseService spawns players.
		require(script.BoatService).start()
		require(script.FishingService).start()
		require(script.AnglerService).start()
		require(script.CatchService).start()
		require(script.CargoService).start()
		require(script.BoatRefitService).start()
		require(script.TrawlerNetService).start()
		require(script.BackpackService).start()
		require(script.CustomerService).start()
		require(script.KitchenService).start()
		require(script.CrabCageService).start()
		require(script.MusselNetService).start()
		require(script.FurnitureService).start()
		require(script.RestaurantService).start()
		require(script.CompanyService).start()

		require(script.LeaderboardService).start(root)
		BaseService.start()
		require(script.OxygenService).start()
		require(script.DashboardService).start()
		stage("Your harbour is ready", 1)
		ReplicatedStorage:SetAttribute("FishingWatersStartupSeconds", os.clock() - started)
		ReplicatedStorage:SetAttribute("FishingWatersWorldReady", true)
		print(
			string.format(
				"[Startup] Harbour playable in %.1fs; distant scenery may continue loading",
				os.clock() - started
			)
		)
	end

	local root = workspace:FindFirstChild("Map")
	if root then
		-- A baked map needs only gameplay repairs before spawning. Cosmetic
		-- migrations and distant LOD/seabed work can run after the harbour opens.
		stage("Preparing your dock", 0.35)
		Harbour.ensurePlazaPaving(root)
		Harbour.ensureBoating(root)
		Harbour.ensureFishing(root)
		Harbour.ensureBases(root)
		openHarbour(root :: Folder)
		task.wait()
		Map.ensureSeabedDetails()
		require(script.Map.Mediterranean).ensureBoats(root)
		Harbour.ensureSurf(root, require(ReplicatedStorage.Shared.Biomes).Normal.center)
		Map.ensureLod()
		Map.ensureSignText()
	else
		-- The callback runs once the home island, collision, shops and bases
		-- exist, before generating the surrounding islands and distant biomes.
		Map.build(openHarbour, stage)
	end
	Map.animate()
	ReplicatedStorage:SetAttribute("FishingWatersGenerationComplete", true)
end, debug.traceback)

if not ok then
	if ReplicatedStorage:GetAttribute("FishingWatersWorldReady") then
		ReplicatedStorage:SetAttribute("FishingWatersGenerationError", true)
	else
		ReplicatedStorage:SetAttribute("FishingWatersStartupError", true)
		stage("The harbour could not start", 0)
	end
	warn("[Startup] " .. tostring(failure))
end
