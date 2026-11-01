-- What holds at a fishing spot right now, for species with a Requires key in
-- AnglerCatalog. The server passes the result to FishCatch.inSeason.
local DayNight = require(script.Parent.DayNight)
local Weather = require(script.Parent.Weather)

local CatchConditions = {}

-- Light rain and heavier (Weather.getState's LightRain threshold) count as rain.
CatchConditions.RAIN = 0.06
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
	return {
		Rain = Weather.getState(serverTime, position).rain > CatchConditions.RAIN,
		Night = DayNight.isNight(DayNight.clockTime(serverTime)),
		Beach = sandyShallow(position),
	}
end

return CatchConditions
