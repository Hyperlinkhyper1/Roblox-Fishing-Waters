-- What holds at a fishing spot right now (weather, time of day, terrain), for species with Requires keys in
-- Shared.Fish, and which area (pool) the spot is in. The server passes `at` to FishCatch.inSeason
-- and `area` to AnglerCatalog.poolAt.
local Biomes = require(script.Parent.Biomes)
local DayNight = require(script.Parent.DayNight)
local Weather = require(script.Parent.Weather)

local CatchConditions = {}

-- Light rain and heavier (Weather.getState's LightRain threshold) count as rain.
CatchConditions.RAIN = 0.06
-- Storm strength where Weather.getState starts calling a spot "Storm".
CatchConditions.STORM = 0.38
-- A beach is sand terrain this close below the water at or around the spot.
CatchConditions.BEACH_DEPTH = 10
CatchConditions.BEACH_REACH = 12

local function sandyShallow(position: Vector3): boolean
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Include
	parameters.FilterDescendantsInstances = { workspace.Terrain }
	parameters.IgnoreWater = true
	local reach = CatchConditions.BEACH_REACH
	for _, offset in
		{
			Vector3.zero,
			Vector3.new(reach, 0, 0),
			Vector3.new(-reach, 0, 0),
			Vector3.new(0, 0, reach),
			Vector3.new(0, 0, -reach),
		}
	do
		local origin = position + offset + Vector3.new(0, 4, 0)
		local result = workspace:Raycast(origin, Vector3.new(0, -(CatchConditions.BEACH_DEPTH + 4), 0), parameters)
		if result and result.Material == Enum.Material.Sand then
			return true
		end
	end
	return false
end

function CatchConditions.at(position: Vector3, serverTime: number?): { [string]: boolean }
	local weather = Weather.getState(serverTime, position)
	local rain = weather.rain > CatchConditions.RAIN
	local night = DayNight.isNight(DayNight.clockTime(serverTime))
	return {
		Rain = rain,
		Clear = not rain and weather.storm < CatchConditions.STORM,
		-- A supercell overhead counts as a storm too.
		Storm = weather.storm > CatchConditions.STORM or weather.kind == "Supercell",
		Night = night,
		Day = not night,
		Beach = sandyShallow(position),
	}
end

-- "lake" inside the main island's sheltered bay, otherwise the Shared.Biomes id there.
function CatchConditions.area(position: Vector3): string
	return if Weather.inLake(position) then "lake" else Biomes.at(position).id
end

return CatchConditions
