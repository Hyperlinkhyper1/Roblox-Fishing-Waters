-- The in-game calendar: one date per in-game day (24 real minutes) over a 365-day year of real
-- months, so a year takes about six real days. It counts from DayNight's fixed epoch, so every
-- server shows the same date and holidays such as Halloween arrive everywhere at once.
local DayNight = require(script.Parent.DayNight)

local Calendar = {}

Calendar.MONTHS = {
	"January",
	"February",
	"March",
	"April",
	"May",
	"June",
	"July",
	"August",
	"September",
	"October",
	"November",
	"December",
}
Calendar.DAYS_IN_MONTH = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
Calendar.DAYS_PER_YEAR = 365
Calendar.SECONDS_PER_DAY = 24 * DayNight.SECONDS_PER_HOUR

export type Date = {
	Year: number, -- 1-based
	Month: number, -- 1-12
	Day: number, -- 1-based day of the month
	DayOfYear: number, -- 1-365
	Hour: number, -- 0-24, the clock without any ClockOverride
}

-- The date `elapsed` in-game seconds after the epoch.
function Calendar.at(elapsed: number): Date
	local days = math.floor(elapsed / Calendar.SECONDS_PER_DAY)
	local years = math.floor(days / Calendar.DAYS_PER_YEAR)
	local dayOfYear = days - years * Calendar.DAYS_PER_YEAR + 1
	local month, day = 1, dayOfYear
	while day > Calendar.DAYS_IN_MONTH[month] do
		day -= Calendar.DAYS_IN_MONTH[month]
		month += 1
	end
	return {
		Year = years + 1,
		Month = month,
		Day = day,
		DayOfYear = dayOfYear,
		Hour = (elapsed - days * Calendar.SECONDS_PER_DAY) / DayNight.SECONDS_PER_HOUR,
	}
end

-- Today's date on the shared clock.
function Calendar.now(serverTime: number?): Date
	return Calendar.at(DayNight.elapsed(serverTime))
end

-- In-game seconds since the epoch at `hour` o'clock on that day.
function Calendar.elapsedAt(year: number, month: number, day: number, hour: number): number
	local dayOfYear = day
	for earlier = 1, month - 1 do
		dayOfYear += Calendar.DAYS_IN_MONTH[earlier]
	end
	local days = (year - 1) * Calendar.DAYS_PER_YEAR + dayOfYear - 1
	return days * Calendar.SECONDS_PER_DAY + hour * DayNight.SECONDS_PER_HOUR
end

-- "31 October", or "31 Oct" when short.
function Calendar.format(date: Date, short: boolean?): string
	local month = Calendar.MONTHS[date.Month]
	return string.format("%d %s", date.Day, if short then month:sub(1, 3) else month)
end

local function monthNamed(name: string): number?
	name = name:lower()
	if #name < 3 then
		return nil
	end
	for index, month in Calendar.MONTHS do
		if month:lower():sub(1, #name) == name then
			return index
		end
	end
	return nil
end

-- Reads "10-31", "10/31", "31 oct" or "october 31", optionally followed by "23:50".
-- Returns month, day and hour (nil when no time was given), or nil when it is not a real date.
function Calendar.parse(text: string): (number?, number?, number?)
	text = text:lower():gsub("^%s+", ""):gsub("%s+$", "")
	local datePart, hours, minutes = text:match("^(.-)%s+(%d%d?):(%d%d)$")
	if not datePart then
		datePart = text
	end
	local month, day
	local a, b = datePart:match("^(%d%d?)%s*[-/]%s*(%d%d?)$")
	if a then
		month, day = tonumber(a), tonumber(b)
	else
		local number, name = datePart:match("^(%d%d?)%s+(%a+)$")
		if not number then
			name, number = datePart:match("^(%a+)%s+(%d%d?)$")
		end
		month, day = if name then monthNamed(name) else nil, tonumber(number)
	end
	if not month or not day or month < 1 or month > 12 or day < 1 or day > Calendar.DAYS_IN_MONTH[month] then
		return nil, nil, nil
	end
	local hour
	if hours then
		local h, m = tonumber(hours) :: number, tonumber(minutes) :: number
		if h > 23 or m > 59 then
			return nil, nil, nil
		end
		hour = h + m / 60
	end
	return month, day, hour
end

return Calendar
