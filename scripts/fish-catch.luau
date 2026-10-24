-- Pure catch-rule checks against the real species catalog. No Roblox runtime.
local fs = require("@lute/fs")
local luau = require("@lute/luau")
local FishCatch = require("../src/shared/FishCatch")
local file = fs.open("src/shared/AnglerCatalog.luau", "r")
local source = fs.read(file)
fs.close(file)
-- The catalog only needs Color3 for rarity colours.
local Color3 = {
	fromRGB = function(...)
		return { ... }
	end,
}
local Catalog = luau.load(luau.compile(source), "AnglerCatalog", { Color3 = Color3 })()

local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local state = 12345
local function rng()
	state = (state * 16807) % 2147483647
	return state / 2147483647
end

local pool = Catalog.Pools[Catalog.DefaultPool]
check(#pool.Fish == 10, "Main lake lists all ten species")
local counts, sizes, tiers = {}, { Normal = 0, Big = 0, Huge = 0 }, {}
local hardest, easiest = 0, 1
local rolls = 200000
for _ = 1, rolls do
	local roll = FishCatch.roll(pool, Catalog.Fish, Catalog.Rarities, rng)
	local fish = Catalog.Fish[roll.FishId]
	check(roll.Kg >= fish.MinKg and roll.Kg <= fish.MaxKg, "Weight stays inside the species range")
	check(roll.Value >= 1 and roll.Value % 1 == 0, "Value is whole cash")
	check(roll.Difficulty >= 0.05 and roll.Difficulty <= 1, "Difficulty is bounded")
	counts[roll.FishId] = (counts[roll.FishId] or 0) + 1
	sizes[roll.Size] += 1
	tiers[fish.Rarity] = (tiers[fish.Rarity] or 0) + 1
	hardest, easiest = math.max(hardest, roll.Difficulty), math.min(easiest, roll.Difficulty)
end
for _, id in pool.Fish do
	check((counts[id] or 0) > 0, "Every species can be caught: " .. id)
end
check(tiers.Common > tiers.Uncommon and tiers.Uncommon > tiers.Rare, "Commoner tiers appear more often")
check(tiers.Rare > tiers.Epic and tiers.Epic > tiers.Legendary, "Rarer tiers appear less often")
check(sizes.Huge > 0 and sizes.Huge < sizes.Big and sizes.Big < sizes.Normal, "HUGE fish are the rarest size")
local stingray, trout = Catalog.Fish.Stingray, Catalog.Fish.Trout
check(
	FishCatch.difficulty(stingray, Catalog.Rarities, 1) > FishCatch.difficulty(trout, Catalog.Rarities, 1),
	"Legendary fish fight harder than common fish"
)
check(
	FishCatch.difficulty(trout, Catalog.Rarities, 5) > FishCatch.difficulty(trout, Catalog.Rarities, 1),
	"Huge fish fight harder than average ones"
)
check(FishCatch.value(trout, 6, "Huge") > FishCatch.value(trout, 1.2, "Normal") * 5, "Huge fish are worth far more")
local easy, hard = FishCatch.tuning(0.1), FishCatch.tuning(1)
check(hard.needleSpeed > easy.needleSpeed and hard.zoneSize < easy.zoneSize, "Hard fights sweep faster with less green")
check(hard.gain < easy.gain and hard.drain > easy.drain and hard.erratic, "Hard fights need more hits and pull back")
check(FishCatch.minimumFightSeconds(1) > FishCatch.minimumFightSeconds(0), "Harder fights take longer to land")

-- Open sea: its own species, still clustered around a normal weight, worth more.
local sea = Catalog.Pools.OpenSea
check(sea and #sea.Fish == 9, "Open sea lists all nine species")
local function averageValue(fishPool)
	local total, seen = 0, {}
	for _ = 1, 50000 do
		local roll = FishCatch.roll(fishPool, Catalog.Fish, Catalog.Rarities, rng)
		total += roll.Value
		seen[roll.FishId] = true
	end
	return total / 50000, seen
end
local lakeAverage = averageValue(pool)
local seaAverage, seaSeen = averageValue(sea)
for _, id in sea.Fish do
	local fish = Catalog.Fish[id]
	check(fish ~= nil and fish.Shapes ~= nil, "Sea species is fully defined: " .. id)
	check(fish.MinKg < fish.AverageKg and fish.AverageKg < fish.MaxKg, "Normal weight sits inside the range: " .. id)
	check(seaSeen[id], "Every sea species can be caught: " .. id)
	check(table.find(pool.Fish, id) == nil, "Sea species stay out of the lake: " .. id)
end
check(seaAverage > lakeAverage * 1.5, "Sea catches are worth clearly more on average")

local function percent(value)
	return string.format("%.2f%%", value / rolls * 100)
end
print(
	string.format(
		"Catch odds: Common %s, Uncommon %s, Rare %s, Epic %s, Legendary %s | Big %s, HUGE %s | difficulty %.2f-%.2f",
		percent(tiers.Common),
		percent(tiers.Uncommon),
		percent(tiers.Rare),
		percent(tiers.Epic),
		percent(tiers.Legendary),
		percent(sizes.Big),
		percent(sizes.Huge),
		easiest,
		hardest
	)
)
print(string.format("Average catch value: lake $%.1f, open sea $%.1f", lakeAverage, seaAverage))
print("Fish catch rules: " .. checks .. " checks passed (pure data; no Roblox runtime).")
