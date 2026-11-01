-- One server clock drives the time of day on every client and the night-only
-- catch rules on the server. It runs off one fixed epoch rather than each server's
-- start, so every server shares the same hour and the same calendar date (Calendar).
local DayNight = {}

-- One in-game hour per real minute: a full day takes 24 minutes.
DayNight.SECONDS_PER_HOUR = 60
-- In-game midnight on 1 January of year 1: 2026-01-01 00:00 UTC.
DayNight.EPOCH = 1767225600
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

-- In-game seconds since the epoch. A CalendarOffset attribute on workspace shifts the whole
-- calendar (the admin /set date command), and the clock keeps running from there.
function DayNight.elapsed(serverTime: number?): number
	local offset = workspace:GetAttribute("CalendarOffset")
	return (serverTime or workspace:GetServerTimeNow()) - DayNight.EPOCH + (if type(offset) == "number" then offset else 0)
end

-- Clock hour (0-24) after `elapsed` seconds since the epoch, which fell at midnight.
function DayNight.clockAt(elapsed: number): number
	return (elapsed / DayNight.SECONDS_PER_HOUR) % 24
end

-- The current clock hour. A ClockOverride attribute on workspace pins it (Studio previews).
function DayNight.clockTime(serverTime: number?): number
	local override = workspace:GetAttribute("ClockOverride")
	if type(override) == "number" then
		return override % 24
	end
	return DayNight.clockAt(DayNight.elapsed(serverTime))
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
