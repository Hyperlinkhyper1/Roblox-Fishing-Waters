-- Run: lute run scripts/cast-timing.luau. Pure timing and catch-odds checks.
local CastTiming = require("../src/shared/CastTiming")
local FishCatch = require("../src/shared/FishCatch")
local fs = require("@lute/fs")
local luau = require("@lute/luau")

local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

for _, sample in { { 0, 0 }, { 0.5, 0.5 }, { 1, 1 }, { 1.5, 0.5 }, { 2, 0 }, { 3, 1 } } do
	check(math.abs(CastTiming.strength(sample[1]) - sample[2]) < 1e-6, "Power rises and falls with held time")
end
for _, elapsed in { 0.94, 1, 1.06, 2.94, 3.06 } do
	check(CastTiming.isPerfect(elapsed), "The top margin works on both sides of each peak")
end
for _, elapsed in { 0, 0.939, 1.061, 1.5, 2, 2.939 } do
	check(not CastTiming.isPerfect(elapsed), "Holding past the peak does not stay perfect")
end
check(CastTiming.validRelease(1, 1.12), "Normal network jitter is allowed")
check(not CastTiming.validRelease(1, 0.1), "An instant cast cannot claim a full charge")
check(not CastTiming.validRelease(1, 2), "A stale charge cannot claim a different release")
check(not CastTiming.validRelease(nil, 1), "A release without timing cannot earn luck")
for _, value in { false, true, "1", {}, -1, math.huge, 0 / 0, 31 } do
	check(not CastTiming.validRelease(value, 1), "Malformed release durations cannot earn luck")
end
check(not CastTiming.validRelease(1, -1), "A missing server charge cannot be simulated by a negative duration")

-- Exercise the real rarity formula with an upgraded rod's existing luck.
local species = {
	Common = { Rarity = "Common", RarityDenominator = 1 },
	Rare = { Rarity = "Rare", RarityDenominator = 1000 },
}
local pool = { Fish = { "Common", "Rare" } }
local function rng()
	return 0.985
end
check(FishCatch.pickSpecies(pool, species, rng, 0.3) == "Common", "Baseline upgrade luck keeps the ordinary roll")
check(
	FishCatch.pickSpecies(pool, species, rng, 0.3 + CastTiming.PerfectLuck) == "Rare",
	"Adding the perfect bonus to upgrade luck can select a rarer fish"
)

for _, path in {
	"src/shared/CastTiming.luau",
	"src/client/CharacterMeter.luau",
	"src/client/Casting.luau",
	"src/client/Oxygen.luau",
	"src/server/CatchService.luau",
} do
	local file = fs.open(path, "r")
	local source = fs.read(file)
	fs.close(file)
	luau.compile(source)
	check(true, path .. " compiles")
end
print(string.format("Cast timing: %d checks passed (pure rules and syntax; no Studio rendering/networking).", checks))
