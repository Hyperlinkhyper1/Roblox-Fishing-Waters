-- Map streaming must not block shop input or equipment initialization.
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
	"BoatAudio",
	"BoatSpray",
	"EnvironmentAudio",
	"CoastalAmbience",
	"BackgroundMusic",
	"ParkedBoats",
	"DrydockLift",
	"Pedestrians",
	"Fishing",
	"RodWorkshop",
	"RodCrates",
	"FishingAudio",
	"Casting",
	"CastAnimation",
	"SpearCombat",
	"SharkSwim",
	"AmbientFish",
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
	"RowingAnimation",
	"ShoreWaves",
	"Weather",
	"BlackHoleWeather",
	"VolumetricClouds",
	"SupercellWeather",
	"WeatherRadar",
	"WaterWaves",
	"SwellSurface",
	"SeabedCarpet",
	"SeasonFoliage",
	"CityNightLights",
	"LightShadows",
}
local required = { Boating = true, Fishing = true, Oxygen = true, RodPhysics = true, PlayerMenu = true }
local ready = 0
player:SetAttribute("FishingWatersClientReady", false)
player:SetAttribute("FishingWatersClientError", false)
for _, name in modules do
	task.spawn(function()
		local success, message = pcall(function()
			require(script[name]).start()
		end)
		if success and required[name] then
			ready += 1
			if ready == 5 then
				player:SetAttribute("FishingWatersClientReady", true)
			end
		elseif not success then
			if required[name] then
				player:SetAttribute("FishingWatersClientError", true)
			end
			warn("[Client] Could not start " .. name .. ": " .. tostring(message))
		end
	end)
end
