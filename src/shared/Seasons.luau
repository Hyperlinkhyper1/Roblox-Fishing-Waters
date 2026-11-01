-- The season follows the same server clock as the time of day, so every client
-- agrees on it without any replication. A fresh server always opens in spring.
local DayNight = require(script.Parent.DayNight)

local Seasons = {}

Seasons.ORDER = { "Spring", "Summer", "Autumn", "Winter" }
-- In-game days per season: three 24-minute days, a full year in under five hours.
Seasons.DAYS_PER_SEASON = 3
Seasons.SECONDS_PER_SEASON = Seasons.DAYS_PER_SEASON * 24 * DayNight.SECONDS_PER_HOUR

-- Season name and day within it (1-based) after `elapsed` seconds since the epoch.
function Seasons.at(elapsed: number): (string, number)
	local seasons = math.floor(math.max(0, elapsed) / Seasons.SECONDS_PER_SEASON)
	local within = math.max(0, elapsed) - seasons * Seasons.SECONDS_PER_SEASON
	local day = math.floor(within / (24 * DayNight.SECONDS_PER_HOUR)) + 1
	return Seasons.ORDER[seasons % #Seasons.ORDER + 1], day
end

-- The current season. A SeasonOverride attribute on workspace pins it (admin command, Studio previews).
function Seasons.current(serverTime: number?): (string, number)
	local override = workspace:GetAttribute("SeasonOverride")
	if type(override) == "string" and table.find(Seasons.ORDER, override) then
		return override, 1
	end
	local time = serverTime or workspace:GetServerTimeNow()
	return Seasons.at(time - (workspace:GetAttribute("WeatherEpoch") or time))
end

return Seasons
