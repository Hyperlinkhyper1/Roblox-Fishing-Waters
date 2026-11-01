-- The in-game calendar and the Halloween party rules: dates off the shared epoch, the admin date
-- parser and offset, the party/fireworks window, and the guest data. No Roblox runtime.
-- Run: lute run scripts/halloween.luau
local fs = require("@lute/fs")
local luau = require("@lute/luau")

local checks = 0
local function check(condition: boolean, message: string)
	assert(condition, message)
	checks += 1
end
local function read(path: string): string
	local file = fs.open(path, "r")
	local source = fs.read(file)
	fs.close(file)
	return source
end

local attributes: { [string]: any } = {}
local now = 0
local workspace = {
	GetAttribute = function(_, name)
		return attributes[name]
	end,
	GetServerTimeNow = function()
		return now
	end,
}
local env = setmetatable({ workspace = workspace }, { __index = _G })
local DayNight = luau.load(luau.compile(read("src/shared/DayNight.luau")), "DayNight", env)()
env.DAYNIGHT = DayNight
local calendarSource = read("src/shared/Calendar.luau"):gsub("require%(script%.Parent%.DayNight%)", "DAYNIGHT")
local Calendar = luau.load(luau.compile(calendarSource), "Calendar", env)()
local Halloween = luau.load(luau.compile(read("src/shared/Halloween.luau")), "Halloween", env)()

-- Calendar
local total = 0
for _, days in Calendar.DAYS_IN_MONTH do
	total += days
end
check(total == Calendar.DAYS_PER_YEAR, "The months add up to the year")
now = DayNight.EPOCH
local date = Calendar.now()
check(
	date.Year == 1 and date.Month == 1 and date.Day == 1 and date.Hour == 0,
	"The epoch is midnight on 1 January, year 1"
)
check(DayNight.clockTime() == 0, "The clock reads midnight at the epoch")
now = DayNight.EPOCH + Calendar.SECONDS_PER_DAY * 31 + 90
date = Calendar.now()
check(date.Month == 2 and date.Day == 1 and math.abs(date.Hour - 1.5) < 1e-9, "Day 32 is 1 February")
check(math.abs(DayNight.clockTime() - date.Hour) < 1e-9, "The clock and the calendar agree on the hour")
check(Calendar.SECONDS_PER_DAY == 24 * DayNight.SECONDS_PER_HOUR, "A date lasts one in-game day")
for _, case in { { 1, 1, 1, 0 }, { 7, 10, 31, 23.75 }, { 50, 12, 31, 12 }, { 3, 2, 28, 6 } } do
	local back = Calendar.at(Calendar.elapsedAt(case[1], case[2], case[3], case[4]))
	check(
		back.Year == case[1] and back.Month == case[2] and back.Day == case[3] and math.abs(back.Hour - case[4]) < 1e-9,
		"elapsedAt and at round-trip " .. table.concat(case, "/")
	)
end
local newYear = Calendar.at(Calendar.elapsedAt(4, 12, 31, 23.99) + 60)
check(newYear.Year == 5 and newYear.Month == 1 and newYear.Day == 1, "31 December rolls over into a new year")
check(Calendar.format(Calendar.at(Calendar.elapsedAt(1, 10, 31, 0))) == "31 October", "Dates read day then month")
check(
	Calendar.format(Calendar.at(Calendar.elapsedAt(1, 11, 1, 0)), true) == "1 Nov",
	"Short dates abbreviate the month"
)
local secondsPerYear = Calendar.DAYS_PER_YEAR * Calendar.SECONDS_PER_DAY
check(secondsPerYear / 3600 > 140 and secondsPerYear / 3600 < 150, "A year takes about six real days")

-- Two servers started at different times read the same date: there is no per-server epoch.
attributes.WeatherEpoch = DayNight.EPOCH + 12345
now = DayNight.EPOCH + 999999
local first = Calendar.now()
attributes.WeatherEpoch = now
local second = Calendar.now()
check(first.DayOfYear == second.DayOfYear and first.Hour == second.Hour, "The date ignores the server's own start")

-- Admin date parsing and the calendar offset
local month, day, hour = Calendar.parse("10-31")
check(month == 10 and day == 31 and hour == nil, "Parses month-day")
month, day, hour = Calendar.parse("10/31 23:50")
check(month == 10 and day == 31 and math.abs((hour :: number) - (23 + 50 / 60)) < 1e-9, "Parses month/day with a time")
month, day = Calendar.parse("31 oct")
check(month == 10 and day == 31, "Parses day and month name")
month, day = Calendar.parse("October 31")
check(month == 10 and day == 31, "Parses month name and day")
check(Calendar.parse("2-30") == nil, "Rejects 30 February")
check(Calendar.parse("13-01") == nil, "Rejects month 13")
check(Calendar.parse("10-31 24:00") == nil, "Rejects 24:00")
check(Calendar.parse("oc 31") == nil, "Rejects a two-letter month")
check(Calendar.parse("auto") == nil, "Leaves words alone")

now = DayNight.EPOCH + Calendar.elapsedAt(9, 4, 12, 8)
local today = Calendar.now()
local target = Calendar.elapsedAt(today.Year, 10, 31, 23 + 50 / 60)
attributes.CalendarOffset = target - Calendar.elapsedAt(today.Year, today.Month, today.Day, today.Hour)
date = Calendar.now()
check(
	date.Month == 10 and date.Day == 31 and math.abs(date.Hour - (23 + 50 / 60)) < 1e-6,
	"The offset jumps the calendar"
)
check(math.abs(DayNight.clockTime() - date.Hour) < 1e-6, "The clock jumps with the calendar")
now += 11 * DayNight.SECONDS_PER_HOUR / 60
date = Calendar.now()
check(date.Month == 11 and date.Day == 1 and date.Hour < 0.1, "Time keeps running past midnight after a jump")
attributes.CalendarOffset = "nonsense"
check(Calendar.now().Month == 4, "A non-number offset is ignored")
attributes.CalendarOffset = nil

-- Party window
local function phaseAt(m: number, d: number, h: number): string?
	return Halloween.phase(Calendar.at(Calendar.elapsedAt(2, m, d, h)))
end
check(phaseAt(10, 30, 23.99) == nil, "No party on 30 October")
check(phaseAt(10, 31, 0) == "Party", "The party opens at midnight on 31 October")
check(phaseAt(10, 31, 23.99) == "Party", "The party lasts all of 31 October")
check(phaseAt(11, 1, 0) == "Fireworks", "Fireworks start at the midnight into 1 November")
check(phaseAt(11, 1, Halloween.FIREWORKS_HOURS - 0.01) == "Fireworks", "Fireworks last their window")
check(phaseAt(11, 1, Halloween.FIREWORKS_HOURS) == nil, "The party is over after the fireworks")
check(phaseAt(6, 15, 12) == nil, "No party in June")
check(Halloween.FINALE_HOURS < Halloween.FIREWORKS_HOURS, "The finale fits inside the show")

-- A spawned event applies to the current day, expires at midnight, and does not change the date.
now = DayNight.EPOCH + Calendar.elapsedAt(2, 6, 15, 12)
attributes.CalendarOffset = nil
local spawnedDate = Calendar.now()
check(not Halloween.partyActive(spawnedDate), "A normal June day has no Halloween party")
attributes.HalloweenEventDay = (spawnedDate.Year - 1) * Calendar.DAYS_PER_YEAR + spawnedDate.DayOfYear
attributes.HalloweenEventEnds = now + (24 - spawnedDate.Hour) * DayNight.SECONDS_PER_HOUR
check(Halloween.forcedToday(spawnedDate) and Halloween.partyActive(spawnedDate), "The spawned party is active")
now += 12 * DayNight.SECONDS_PER_HOUR
check(not Halloween.forcedToday(Calendar.now()), "The spawned party ends at midnight")
now -= DayNight.SECONDS_PER_HOUR
attributes.CalendarOffset = Calendar.SECONDS_PER_DAY
check(not Halloween.forcedToday(Calendar.now()), "Changing to a different date ends the spawned party")
attributes.CalendarOffset = nil
attributes.HalloweenEventDay = nil
attributes.HalloweenEventEnds = nil
check(Halloween.partyActive(Calendar.at(Calendar.elapsedAt(2, 10, 31, 12))), "The scheduled party still works")

-- Guest data
local slots = {
	HatAccessory = true,
	HairAccessory = true,
	FaceAccessory = true,
	NeckAccessory = true,
	ShouldersAccessory = true,
	FrontAccessory = true,
	BackAccessory = true,
	WaistAccessory = true,
}
for _, name in Halloween.COSTUME_ORDER do
	local set = Halloween.COSTUMES[name]
	check(set ~= nil, name .. " is a costume")
	for slot, ids in set do
		if slot == "HideHair" then
			continue
		end
		check(slots[slot] == true, name .. "." .. slot .. " is a HumanoidDescription accessory property")
		check(type(ids) == "table" and #ids > 0, name .. "." .. slot .. " lists asset ids")
		for _, id in ids do
			check(type(id) == "number" and id > 0 and id % 1 == 0, name .. " asset ids are whole numbers")
		end
	end
end
local count = 0
for _ in Halloween.COSTUMES do
	count += 1
end
check(count == #Halloween.COSTUME_ORDER, "Every costume is in the order list")
for _, list in { Halloween.COSTUME_BUNDLES, Halloween.TOWNSFOLK_BUNDLES } do
	check(#list >= 8, "Plenty of different outfits")
	local seen = {}
	for _, id in list do
		check(type(id) == "number" and not seen[id], "Outfit ids are numbers without repeats")
		seen[id] = true
	end
end
check(#Halloween.NAMES >= Halloween.GUESTS, "Enough names for every guest")
check(#Halloween.LINES >= 20 and #Halloween.FIREWORK_LINES >= 5, "Guests have plenty to say")
for _, color in Halloween.FIREWORK_COLORS do
	check(color[1] == 255 and color[2] >= 80 and color[2] <= 200 and color[3] <= 90, "Fireworks are orange")
end

-- Every changed Roblox-side file still compiles.
for _, path in
	{
		"src/server/HalloweenService.luau",
		"src/server/AdminCommands.luau",
		"src/shared/MutationContext.luau",
		"src/client/HalloweenParty.luau",
		"src/client/Boating.luau",
		"src/server/BoatService.luau",
		"src/shared/Seasons.luau",
	}
do
	local ok, problem = pcall(luau.load, luau.compile(read(path)), path, {})
	check(ok, path .. " compiles: " .. tostring(problem))
end

print("Halloween: " .. checks .. " checks passed")
