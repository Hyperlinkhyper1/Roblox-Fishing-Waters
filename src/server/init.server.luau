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

-- A script timeout can't be handled in this thread: its budget stays spent, so the handler's own
-- first call times out too (the error report then names only the handler's line). A watchdog in
-- its own thread notices the startup thread died, flags the error and names the step it was in.
local startupThread = coroutine.running()
local currentStep = "loading modules"
task.defer(function()
	while true do
		task.wait(1)
		if
			ReplicatedStorage:GetAttribute("FishingWatersGenerationComplete")
			or ReplicatedStorage:GetAttribute("FishingWatersGenerationError")
			or ReplicatedStorage:GetAttribute("FishingWatersStartupError")
		then
			return
		end
		if coroutine.status(startupThread) == "dead" then
			if ReplicatedStorage:GetAttribute("FishingWatersWorldReady") then
				ReplicatedStorage:SetAttribute("FishingWatersGenerationError", true)
			else
				ReplicatedStorage:SetAttribute("FishingWatersStartupError", true)
				stage("The harbour could not start", 0)
			end
			task.spawn(error, `[Startup] Startup thread died during step "{currentStep}" (likely a script timeout)`, 0)
			return
		end
	end
end)

local ok, failure = xpcall(function()
	-- Update notices and stale-server admission must work even while the map loads.
	require(script.ServerUpdates).start()
	-- Records memory/uptime so a server that dies (everyone kicked, no script error) gets reported.
	require(script.ServerHealth).start()
	local BaseService = require(script.BaseService)
	local Map = require(script.Map)
	local Harbour = require(script.Map.Harbour)

	-- Roblox kills a thread that runs about 10 s without yielding ("Script timeout: exhausted allowed
	-- execution time"). Run in this thread, one slow step ended all of startup and left the server
	-- unplayable, and the timeout could not even be reported (the handler's first call timed out
	-- too). So each step runs in a thread of its own: if it times out or errors, only that thread
	-- dies. This thread waits on it across frames, so it still has a fresh budget to raise an error
	-- naming the step (it lands in the error report) and to carry on with the next step.
	local function step(name: string, run: () -> ())
		task.wait()
		currentStep = name
		ReplicatedStorage:SetAttribute("FishingWatersStartupStep", name)
		local began = os.clock()
		local finished, problem = false, nil
		local thread = task.defer(function()
			local stepOk, stepError = xpcall(run, debug.traceback)
			problem = if stepOk then nil else stepError
			finished = true
		end)
		while not finished and coroutine.status(thread) ~= "dead" do
			task.wait()
		end
		local seconds = os.clock() - began
		if not finished then
			-- Killed without reaching the line after xpcall: only a script timeout does that
			problem = string.format("script timeout after %.1fs without yielding", seconds)
		end
		if problem then
			task.spawn(error, `[Startup] Step "{name}" failed: {problem}`, 0)
		elseif seconds > 1 then
			print(string.format("[Startup] %s took %.1fs", name, seconds))
		end
	end

	local function openHarbour(root: Folder)
		stage("Getting your dock ready", 0.9)
		step("Streaming", function()
			Map.prepareStreaming(root)
		end)
		step("ChartCatalog", function()
			require(script.Map.ChartCatalog).start(root)
		end)
		step("WeatherService", function()
			require(script.WeatherService).start()
		end)
		-- Install inventory/character listeners and remotes before BaseService spawns players.
		-- Every service also handles players already in game, so the yields between them are safe.
		step("BoatService", function()
			require(script.BoatService).start()
		end)
		step("SharkService", function()
			require(script.SharkService).start()
		end)
		step("FishingService", function()
			require(script.FishingService).start()
		end)
		step("AnglerService", function()
			require(script.AnglerService).start()
		end)
		step("SharkLootService", function()
			require(script.SharkLootService).start()
		end)
		step("CatchService", function()
			require(script.CatchService).start()
		end)
		step("CargoService", function()
			require(script.CargoService).start()
		end)
		step("BoatRefitService", function()
			require(script.BoatRefitService).start()
		end)
		step("BoatFurnitureService", function()
			require(script.BoatFurnitureService).start()
		end)
		step("TrawlerNetService", function()
			require(script.TrawlerNetService).start()
		end)
		step("BackpackService", function()
			require(script.BackpackService).start()
		end)
		step("CustomerService", function()
			require(script.CustomerService).start()
		end)
		step("KitchenService", function()
			require(script.KitchenService).start()
		end)
		step("ChefService", function()
			require(script.ChefService).start()
		end)
		step("CrabCageService", function()
			require(script.CrabCageService).start()
		end)
		step("MusselNetService", function()
			require(script.MusselNetService).start()
		end)
		step("FurnitureService", function()
			require(script.FurnitureService).start()
		end)
		step("BuildingService", function()
			require(script.BuildingService).start()
		end)
		step("RestaurantService", function()
			require(script.RestaurantService).start()
		end)
		step("CompanyService", function()
			require(script.CompanyService).start()
		end)
		step("CompanyIslandService", function()
			require(script.CompanyIslandService).start()
		end)
		step("CompanyIslandPorter", function()
			require(script.CompanyIslandPorter).start()
		end)
		step("TutorialService", function()
			require(script.TutorialService).start()
		end)
		step("PirateCoveService", function()
			require(script.PirateCoveService).start()
		end)
		step("MetroService", function()
			require(script.MetroService).start()
		end)
		step("HalloweenService", function()
			require(script.HalloweenService).start()
		end)
		step("PedestrianService", function()
			require(script.PedestrianService).start()
		end)
		step("OfficeComputerService", function()
			require(script.OfficeComputerService).start()
		end)
		step("StockMarketService", function()
			require(script.StockMarketService).start()
		end)

		step("LeaderboardService", function()
			require(script.LeaderboardService).start(root)
		end)
		step("BaseService", BaseService.start)
		step("OxygenService", function()
			require(script.OxygenService).start()
		end)
		step("DashboardService", function()
			local dashboard = require(script.DashboardService)
			dashboard.setLeaderboardSource(require(script.LeaderboardService).snapshot)
			dashboard.start()
		end)
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
		step("Plaza paving", function()
			Harbour.ensurePlazaPaving(root)
		end)
		step("Boating", function()
			Harbour.ensureBoating(root)
		end)
		step("Fishing", function()
			Harbour.ensureFishing(root)
		end)
		step("Bases", function()
			Harbour.ensureBases(root)
		end)
		step("Metro", function()
			Harbour.ensureMetro(root)
		end)
		step("Company islands", function()
			Map.ensureCompanyIslands(root)
		end)
		openHarbour(root :: Folder)
		-- Players are in by now; cosmetic repairs follow.
		step("City", function()
			Map.ensureCity(root)
		end)
		step("Pirate Cove", function()
			Map.ensurePirateCove(root)
		end)
		step("Seabed details", Map.ensureSeabedDetails)
		step("Boats", function()
			require(script.Map.Mediterranean).ensureBoats(root)
		end)
		step("Surf", function()
			Harbour.ensureSurf(root, require(ReplicatedStorage.Shared.Biomes).Normal.center)
		end)
		step("Lod", Map.ensureLod)
		step("Sign text", Map.ensureSignText)
		task.wait()
	else
		-- The callback runs once the home island, collision, shops and bases
		-- exist, before generating the surrounding islands and distant biomes.
		Map.build(openHarbour, stage, step)
	end
	task.wait()
	Map.animate()
	ReplicatedStorage:SetAttribute("FishingWatersGenerationComplete", true)
end, debug.traceback)

if not ok then
	-- A timeout is raised inside the xpcall, but this thread's budget is still spent: without a
	-- fresh resume the warn below times out too and the real traceback is lost (it reported only
	-- "Line 152").
	task.wait()
	if ReplicatedStorage:GetAttribute("FishingWatersWorldReady") then
		ReplicatedStorage:SetAttribute("FishingWatersGenerationError", true)
	else
		ReplicatedStorage:SetAttribute("FishingWatersStartupError", true)
		stage("The harbour could not start", 0)
	end
	warn(`[Startup] Failed during step "{currentStep}": {failure}`)
end
