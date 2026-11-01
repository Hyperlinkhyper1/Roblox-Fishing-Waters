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

-- The admin-only showcase sits far outside the ocean, so nobody waits for it. It runs in its own
-- thread, scheduled before startup, so a startup step that fails or exhausts the script timeout
-- cannot keep it from being built. It waits for the world to finish (or give up) so it does not
-- compete with the harbour, but never longer than two minutes.
task.defer(function()
	local waited = 0
	while
		waited < 120
		and not ReplicatedStorage:GetAttribute("FishingWatersGenerationComplete")
		and not ReplicatedStorage:GetAttribute("FishingWatersGenerationError")
		and not ReplicatedStorage:GetAttribute("FishingWatersStartupError")
	do
		waited += task.wait(1)
	end
	print("[ScaleModels] Building the scale models")
	local built, problem = xpcall(function()
		require(script.ScaleModels).ensure()
	end, debug.traceback)
	if built then
		print("[ScaleModels] Scale models ready")
	else
		warn("[ScaleModels] " .. tostring(problem))
	end
end)

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
		require(script.SharkService).start()
		require(script.FishingService).start()
		require(script.AnglerService).start()
		require(script.SharkLootService).start()
		require(script.CatchService).start()
		require(script.CargoService).start()
		require(script.BoatRefitService).start()
		require(script.TrawlerNetService).start()
		require(script.BackpackService).start()
		require(script.CustomerService).start()
		require(script.KitchenService).start()
		require(script.ChefService).start()
		require(script.CrabCageService).start()
		require(script.MusselNetService).start()
		require(script.FurnitureService).start()
		require(script.RestaurantService).start()
		require(script.CompanyService).start()
		require(script.TutorialService).start()

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
		-- Players are in by now. Each repair gets a fresh resume, and a slow one is named, because
		-- a run of them without a yield exhausted the script timeout and cut startup short.
		local function repair(name: string, run: () -> ())
			task.wait()
			local began = os.clock()
			run()
			if os.clock() - began > 1 then
				print(string.format("[Startup] %s took %.1fs", name, os.clock() - began))
			end
		end
		repair("City", function()
			Map.ensureCity(root)
		end)
		repair("Seabed details", Map.ensureSeabedDetails)
		repair("Boats", function()
			require(script.Map.Mediterranean).ensureBoats(root)
		end)
		repair("Surf", function()
			Harbour.ensureSurf(root, require(ReplicatedStorage.Shared.Biomes).Normal.center)
		end)
		repair("Lod", Map.ensureLod)
		repair("Sign text", Map.ensureSignText)
		task.wait()
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
