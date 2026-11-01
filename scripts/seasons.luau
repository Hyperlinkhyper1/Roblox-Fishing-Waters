-- Pure season checks: the clock's season order, day count and admin override, and
-- the foliage tints for each season. No Roblox runtime.
-- Run: lute run scripts/seasons.luau
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
env.CALENDAR = Calendar
local seasonsSource = read("src/shared/Seasons.luau"):gsub("require%(script%.Parent%.Calendar%)", "CALENDAR")
local Seasons = luau.load(luau.compile(seasonsSource), "Seasons", env)()

-- Seasons follow the calendar's months; every server reads the same date off the fixed epoch.
local function at(month: number, day: number, hour: number?)
	now = DayNight.EPOCH + Calendar.elapsedAt(3, month, day, hour or 12)
end
at(1, 1, 0)
local season, day = Seasons.current()
check(season == "Winter" and day == 32, "1 January is the 32nd day of winter")
at(3, 1)
season, day = Seasons.current()
check(season == "Spring" and day == 1, "Spring starts on 1 March")
at(5, 31)
season, day = Seasons.current()
check(season == "Spring" and day == 92, "Spring runs to the end of May")
local order = {}
for _, month in { 3, 6, 9, 12, 1 } do
	at(month, 1)
	table.insert(order, (Seasons.current()))
end
check(table.concat(order, ",") == "Spring,Summer,Autumn,Winter,Winter", "Seasons follow the months and wrap through the new year")
at(10, 31, 23.5)
check((Seasons.current()) == "Autumn", "Halloween is in autumn")
attributes.SeasonOverride = "Winter"
check((Seasons.current()) == "Winter", "The override pins the season")
attributes.SeasonOverride = "Monsoon"
check((Seasons.current()) == "Autumn", "An unknown override is ignored")
attributes.SeasonOverride = nil

-- Foliage tints, against a tiny Color3 mock.
local Color3 = {}
Color3.__index = Color3
function Color3.fromRGB(r, g, b)
	return setmetatable({ R = r / 255, G = g / 255, B = b / 255 }, Color3)
end
function Color3:Lerp(other, t)
	return setmetatable(
		{
			R = self.R + (other.R - self.R) * t,
			G = self.G + (other.G - self.G) * t,
			B = self.B + (other.B - self.B) * t,
		},
		Color3
	)
end
local foliageSource = read("src/client/SeasonFoliage.luau")
	:gsub('game:GetService%("%a+"%)', "{}")
	:gsub("require%(ReplicatedStorage%.Shared%.Seasons%)", "{}")
local SeasonFoliage = luau.load(
	luau.compile(foliageSource),
	"SeasonFoliage",
	setmetatable(
		{ Color3 = Color3, Enum = {
			Material = { Grass = "Grass", LeafyGrass = "LeafyGrass" },
		} },
		{ __index = _G }
	)
)()
local leafGreen = Color3.fromRGB(60, 120, 50)
local summer = SeasonFoliage.tint(leafGreen, "Summer", false, 0)
check(summer == leafGreen, "Summer keeps the colours the map was built with")
local autumn = SeasonFoliage.tint(leafGreen, "Autumn", false, 0)
check(autumn.R > autumn.G and autumn.R > leafGreen.R, "Autumn leaves turn orange-red")
local seeds = {}
for seed = 0, 3 do
	local tinted = SeasonFoliage.tint(leafGreen, "Autumn", false, seed)
	seeds[string.format("%.3f", tinted.R + tinted.G * 10)] = true
end
local distinct = 0
for _ in seeds do
	distinct += 1
end
check(distinct == 4, "Neighbouring leaves get different autumn colours")
local snow = SeasonFoliage.tint(leafGreen, "Winter", true, 0)
check(snow.R > 0.75 and snow.G > 0.75 and snow.B > 0.75, "Winter lawns are snow-covered")
local frost = SeasonFoliage.tint(leafGreen, "Winter", false, 0)
check(frost.R < snow.R and frost.G > leafGreen.G, "Winter trees are frosted but not buried")
local spring = SeasonFoliage.tint(leafGreen, "Spring", false, 0)
check(spring.G > leafGreen.G, "Spring leaves are a fresher green")

print("Seasons: " .. checks .. " checks passed")
