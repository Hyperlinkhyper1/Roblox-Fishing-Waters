-- Map streaming must not block shop input or equipment initialization.
local player = game:GetService("Players").LocalPlayer
local modules = {
	"AdminFly",
	"Leaderboard",
	"ServerUpdates",
	"BiomeAtmosphere",
	"Lod",
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
	"MutationEffects",
	"Sprint",
	"ShopCustomers",
	"FurnitureShop",
	"BuildMode",
	"Kitchen",
	"KitchenStorage",
	"CrabCages",
	"MusselNets",

	"PlayerMenu",
	"WorldMap",
	"Tutorial",
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
	"SeasonFoliage",
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
