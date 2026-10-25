-- One server clock drives the time of day on every client and the night-only
-- catch rules on the server. It shares the weather's epoch, so a fresh server
-- always opens in the morning.
local DayNight = {}

-- One in-game hour per real minute: a full day takes 24 minutes.
DayNight.SECONDS_PER_HOUR = 60
DayNight.START_HOUR = 10
-- Night, for catch rules, runs from NIGHT_START to NIGHT_END.
DayNight.NIGHT_START = 18
DayNight.NIGHT_END = 6
-- Lighting fades over these twilight windows (hours).
DayNight.DUSK = { 17.5, 19.5 }
DayNight.DAWN = { 4.5, 6.5 }

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Clock hour (0-24) after `elapsed` seconds since the epoch.
function DayNight.clockAt(elapsed: number): number
	return (DayNight.START_HOUR + math.max(0, elapsed) / DayNight.SECONDS_PER_HOUR) % 24
end

-- The current clock hour. A ClockOverride attribute on workspace pins it (Studio previews).
function DayNight.clockTime(serverTime: number?): number
	local override = workspace:GetAttribute("ClockOverride")
	if type(override) == "number" then
		return override % 24
	end
	local time = serverTime or workspace:GetServerTimeNow()
	return DayNight.clockAt(time - (workspace:GetAttribute("WeatherEpoch") or time))
end

function DayNight.isNight(clock: number): boolean
	return clock >= DayNight.NIGHT_START or clock < DayNight.NIGHT_END
end

-- 0 in full daylight, 1 in deep night, easing through dusk and dawn.
function DayNight.darkness(clock: number): number
	local dusk = smoothstep((clock - DayNight.DUSK[1]) / (DayNight.DUSK[2] - DayNight.DUSK[1]))
	local dawn = 1 - smoothstep((clock - DayNight.DAWN[1]) / (DayNight.DAWN[2] - DayNight.DAWN[1]))
	return if clock >= 12 then dusk else dawn
end

return DayNight
