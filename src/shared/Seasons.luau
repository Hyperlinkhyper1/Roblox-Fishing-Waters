-- The season follows the in-game calendar's months (meteorological seasons: spring is March to
-- May), so every server and client agrees on it without any replication.
local Calendar = require(script.Parent.Calendar)

local Seasons = {}

Seasons.ORDER = { "Spring", "Summer", "Autumn", "Winter" }
-- The season of each month, January first.
Seasons.OF_MONTH = {
	"Winter",
	"Winter",
	"Spring",
	"Spring",
	"Spring",
	"Summer",
	"Summer",
	"Summer",
	"Autumn",
	"Autumn",
	"Autumn",
	"Winter",
}

-- Season name and day within it (1-based) on a calendar date.
function Seasons.of(date: Calendar.Date): (string, number)
	local season = Seasons.OF_MONTH[date.Month]
	local day, month = date.Day, date.Month
	while true do
		local previous = if month == 1 then 12 else month - 1
		if Seasons.OF_MONTH[previous] ~= season then
			break
		end
		month = previous
		day += Calendar.DAYS_IN_MONTH[month]
	end
	return season, day
end

-- Season name and day within it after `elapsed` in-game seconds since the epoch.
function Seasons.at(elapsed: number): (string, number)
	return Seasons.of(Calendar.at(elapsed))
end

-- The current season. A SeasonOverride attribute on workspace pins it (admin command, Studio previews).
function Seasons.current(serverTime: number?): (string, number)
	local override = workspace:GetAttribute("SeasonOverride")
	if type(override) == "string" and table.find(Seasons.ORDER, override) then
		return override, 1
	end
	return Seasons.of(Calendar.now(serverTime))
end

return Seasons
