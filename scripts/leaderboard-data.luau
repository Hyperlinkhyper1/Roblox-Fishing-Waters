local Data = require("../src/server/AnglerData")
local BoatData = require("../src/server/BoatData")
local fs = require("@lute/fs")
local luau = require("@lute/luau")
local catalogFile = fs.open("src/shared/AnglerCatalog.luau", "r")
local catalogSource = fs.read(catalogFile)
fs.close(catalogFile)
local Catalog = luau.load(luau.compile(catalogSource), "AnglerCatalog", {
	Color3 = { fromRGB = function(...) return { ... } end },
})()
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
-- Monday 2026-10-19 00:00 UTC.
local monday = 1792368000
local expectedXP = { Junk = 5, Common = 50, Uncommon = 100, Rare = 200, Epic = 400, Legendary = 800 }
for id, species in Catalog.Fish do
	local before = Data.decode({ Stats = { TotalXP = 950 } })
	local caught = Data.recordCatch(before, id, "Normal", species.AverageKg, 1, monday, Catalog.Fish, Catalog.Mutations)
	local trackedCatch = Data.trackProgress(before, caught, monday)
	local xp = expectedXP[species.Rarity]
	check(caught.Stats.TotalXP == 950 + xp, "Species awards its rarity XP: " .. id)
	check(trackedCatch.Weekly.XP == xp and trackedCatch.Weekly.Caught == 1, "Weekly XP matches catch reward: " .. id)
	check(before.Stats.TotalXP == 950, "Catch reward preserves previous saved data")
	for _, other in Catalog.Fish do
		if species.Rarity ~= "Junk" and other.Rarity ~= "Junk" and species.RarityDenominator > other.RarityDenominator then
			check(species.CatchXP > other.CatchXP, "Rarer fish always award more XP")
		end
	end
end
for _, invalidXP in { 0, -1, 1.5, math.huge, 0 / 0, "100" } do
	check(not pcall(Data.recordCatch, nil, "Invalid", "Normal", 1, 1, monday,
		{ Invalid = { CatchXP = invalidXP, AverageKg = 1, RarityDenominator = 4 } }, Catalog.Mutations),
		"Invalid XP rewards cannot enter saved progress")
end
check(Data.weekStart(monday) == monday, "Monday starts the new UTC week")
check(Data.weekStart(monday - 1) == monday - 604800, "Sunday belongs to the previous week")
check(Data.weekStart(monday + 604799) == monday, "Last second of week")
check(Data.weekStart(monday + 604800) == monday + 604800, "Exact weekly reset")
check(Data.level(0) == 1 and Data.level(999) == 1 and Data.level(1000) == 2, "Level thresholds")
local previousCost = 0
for level = 1, 100 do
	local threshold, nextThreshold = Data.xpForLevel(level), Data.xpForLevel(level + 1)
	local cost = nextThreshold - threshold
	check(cost > previousCost and cost == level * 1000, "Every successive level costs more XP")
	check(Data.level(threshold) == level and Data.level(nextThreshold - 1) == level, "Exact progressive boundaries")
	check(Data.level(nextThreshold) == level + 1, "Reaching the next threshold levels up")
	previousCost = cost
end
check(Data.level(2000) == 2 and Data.level(3000) == 3 and Data.level(6000) == 4, "Cumulative XP curve")
local level, progressXP, requiredXP = Data.levelProgress(4500)
check(
	level == 3 and progressXP == 1500 and requiredXP == 3000,
	"Level bar uses current-level progress and growing requirement"
)
local savedXP = Data.decode({ Stats = { TotalXP = 4500 } })
check(savedXP.Stats.TotalXP == 4500 and Data.scores(savedXP, monday).Level == 3, "Curve changes preserve earned XP")
for _, levelAtLimit in { 100000, 1000000, 4000000 } do
	local threshold = Data.xpForLevel(levelAtLimit)
	check(
		Data.level(threshold - 1) == levelAtLimit - 1 and Data.level(threshold) == levelAtLimit,
		"Large saved XP stays correct at exact boundaries"
	)
end
local legacy = { Stats = { TotalCaught = 19, CoinsEarned = 900 } }
local scores = Data.scores(legacy, monday)
check(scores.Level == 2 and scores.Caught == 19 and scores.Earned == 900, "Legacy lifetime totals migrate")
check(
	scores.WeeklyXP == 0 and scores.WeeklyCaught == 0 and scores.WeeklyEarned == 0,
	"No historical weekly scores invented"
)
check(legacy.Stats.TotalXP == nil, "Migration never mutates raw records")
local fish = { Trout = { AverageKg = 2, RarityDenominator = 10 } }
local afterCatch = Data.recordCatch(legacy, "Trout", "Normal", 2, 500, monday, fish, { Normal = {} })
local tracked = Data.trackProgress(legacy, afterCatch, monday)
scores = Data.scores(tracked, monday)
check(
	scores.Level == 2 and scores.WeeklyXP == 100 and scores.WeeklyCaught == 1,
	"Catch awards XP and weekly catch atomically"
)
check(scores.WeeklyEarned == 0 and scores.Earned == 900, "Fish value is not earned money before a sale")
local retry = Data.trackProgress(legacy, afterCatch, monday)
check(retry.Weekly.XP == 100 and retry.Weekly.Caught == 1, "Callback retry does not double count")
local earned = Data.decode(tracked)
earned.Stats.CoinsEarned += 125
earned = Data.trackProgress(tracked, earned, monday + 1)
check(earned.Weekly.Earned == 125 and earned.Weekly.XP == 100, "Money awards preserve weekly XP")
local beforePurchase = { Version = 1, Cash = 1000, OwnedBoats = {}, Angler = earned }
local purchase = BoatData.purchase(beforePurchase)
scores = BoatData.leaderboardScores(purchase, monday)
check(
	purchase.Cash == 500 and scores.Earned == 1025 and scores.WeeklyEarned == 125,
	"Spending cannot lower earned rankings"
)
local nextWeek = Data.trackProgress(
	earned,
	Data.recordCatch(earned, "Trout", "Normal", 2, 1, monday + 604800, fish, { Normal = {} }),
	monday + 604800
)
check(
	nextWeek.Weekly.XP == 100 and nextWeek.Weekly.Caught == 1 and nextWeek.Weekly.Earned == 0,
	"First award resets only weekly counters"
)
scores = Data.scores(earned, monday + 604800)
check(
	scores.WeeklyXP == 0 and scores.WeeklyCaught == 0 and scores.WeeklyEarned == 0,
	"Idle players read zero in a new week"
)
check(scores.Earned == 1025 and scores.Caught == 20, "Weekly reset preserves lifetime stats")
local settings = Data.trackProgress(earned, earned, monday + 604800)
check(settings.Weekly.Caught == 0, "Unrelated update after rollover credits no old activity")
for _, raw in
	{
		{ Stats = { TotalXP = -1 } },
		{ Stats = { TotalXP = 0 / 0 } },
		{ Weekly = false },
		{
			Weekly = { Start = monday, XP = -1, Caught = 0, Earned = 0 },
		},
	}
do
	check(not pcall(Data.decode, raw), "Malformed XP/weekly data rejected")
end
print("Leaderboard data: " .. checks .. " checks passed (pure saved-data rules).")
