-- Map streaming must not block shop input or equipment initialization.
--
-- Startup is staged so slow devices spend the loading screen streaming in the world instead of
-- running every client system in the same frame:
--   1. The gear the loading screen waits for starts at once.
--   2. Other gameplay and UI follow, a few modules per frame.
--   3. Systems that only animate or voice the world (water surfaces, sky, wildlife, ambience)
--      start once the loading screen lifts. Nothing they draw or play is visible behind it, but
--      their per-frame work competed with the world streaming in.
local player = game:GetService("Players").LocalPlayer
local modules = {
	"OverlayInset",
	"AdminFly",
	"Leaderboard",
	"ServerUpdates",
	"BiomeAtmosphere",
	"AreaBanner",
	"Lod",
	"Metro",
	"Oxygen",
	"Boating",
	"BoatHealth",
	"BoatRefit",
	"ParkedBoats",
	"DrydockLift",
	"Fishing",
	"RodWorkshop",
	"RodCrates",
	"FishingAudio",
	"Casting",
	"CastAnimation",
	"SpearCombat",
	"CargoHold",
	"BackpackShop",
	"BlackHoleBackpack",
	"MutationEffects",
	"FishMeshes",
	"Sprint",
	"ShopCustomers",
	"FurnitureShop",
	"BuildMode",
	"Kitchen",
	"KitchenStorage",
	"CompanyIslands",
	"CrabCages",
	"MusselNets",
	"OfficeComputer",

	"PlayerMenu",
	"WorldMap",
	"Tutorial",
	"PirateCove",
	"HalloweenParty",
	"RodPhysics",
	"Weather",
	"WeatherRadar",
	"SeasonFoliage",
	"CityNightLights",
	"LightShadows",
	"FrameRateGuard",
}
-- Started once the loading screen is gone (or after LOADING_TIMEOUT if it never reports).
-- Each polls the world every frame and handles whatever already exists when it starts.
local afterLoading = {
	"WaterWaves",
	"SwellSurface",
	"ShoreWaves",
	"SeabedCarpet",
	"VolumetricClouds",
	"SupercellWeather",
	"BlackHoleWeather",
	"AmbientFish",
	"SharkSwim",
	"SharkMeshes",
	"Pedestrians",
	"NpcFishers",
	"BoatAudio",
	"BoatSpray",
	"RowingAnimation",
	"EnvironmentAudio",
	"CoastalAmbience",
	"BackgroundMusic",
}
local required = { Boating = true, Fishing = true, Oxygen = true, RodPhysics = true, PlayerMenu = true }
local REQUIRED_COUNT = 5
-- Most startup work one frame may take before the next module waits for the following frame
local FRAME_BUDGET = 0.008
-- A module that holds the frame this long before its first yield is named in the output
local SLOW_START = 0.05
local LOADING_TIMEOUT = 90

local ready = 0
player:SetAttribute("FishingWatersClientReady", false)
player:SetAttribute("FishingWatersClientError", false)

local function start(name: string)
	local began = os.clock()
	task.spawn(function()
		local success, message = pcall(function()
			require(script[name]).start()
		end)
		if success and required[name] then
			ready += 1
			if ready == REQUIRED_COUNT then
				player:SetAttribute("FishingWatersClientReady", true)
			end
		elseif not success then
			if required[name] then
				player:SetAttribute("FishingWatersClientError", true)
			end
			warn("[Client] Could not start " .. name .. ": " .. tostring(message))
		end
	end)
	-- task.spawn returns at the module's first yield, so this is the time it held the frame
	local held = os.clock() - began
	if held > SLOW_START then
		print(string.format("[Client] %s held startup for %d ms", name, math.floor(held * 1000)))
	end
end

local function startPaced(names: { string })
	local resumed = os.clock()
	for _, name in names do
		if os.clock() - resumed > FRAME_BUDGET then
			task.wait()
			resumed = os.clock()
		end
		start(name)
	end
end

for _, name in modules do
	if required[name] then
		start(name)
	end
end

task.spawn(function()
	local rest = {}
	for _, name in modules do
		if not required[name] then
			table.insert(rest, name)
		end
	end
	startPaced(rest)

	-- ReplicatedFirst/Loading records how long loading took as it lifts the screen
	local deadline = os.clock() + LOADING_TIMEOUT
	while player:GetAttribute("FishingWatersLoadingSeconds") == nil and os.clock() < deadline do
		task.wait(0.25)
	end
	startPaced(afterLoading)
end)
