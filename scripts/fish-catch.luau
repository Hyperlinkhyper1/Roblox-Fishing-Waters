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
for _, id in { "Trout", "Stingray", "Pike", "Sunfish", "MidnightCarp", "Crimsonfish", "Glacierfish" } do
	check(table.find(pool.Fish, id), "Main lake lists " .. id)
end
for _, catchPool in Catalog.Pools do
	check(#catchPool.Junk == 3, "All three junk catches are available in " .. catchPool.Name)
	for _, sample in
		{
			{ 0, "WoodenBranch" },
			{ 0.019999, "WoodenBranch" },
			{ 0.02, "LeatherBoot" },
			{ 0.039999, "LeatherBoot" },
			{ 0.04, "Seaweed" },
			{ 0.059999, "Seaweed" },
		}
	do
		local roll = FishCatch.roll(catchPool, Catalog.Fish, Catalog.Rarities, function()
			return sample[1]
		end)
		check(roll.FishId == sample[2], "Each junk catch occupies exactly 2% of the roll")
		check(
			roll.Size == "Normal" and roll.Value == 1 and roll.Difficulty == 0.05,
			"Junk stays cheap, normal-sized and easy to reel"
		)
	end
	for _, boundary in { FishCatch.JUNK_CHANCE, 0.999999 } do
		local id = FishCatch.pickSpecies(catchPool, Catalog.Fish, function()
			return boundary
		end)
		check(table.find(catchPool.Fish, id) ~= nil, "Non-junk rolls still select a fish")
	end
end
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
for _, id in pool.Junk do
	check(math.abs((counts[id] or 0) / rolls - 0.02) < 0.002, "Junk appears in about 2% of catches: " .. id)
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
for _, id in { "Clownfish", "Yellowshark", "GreenSturgeon", "Albacore", "Crimsonfish", "Glacierfish" } do
	check(table.find(sea.Fish, id), "Open sea lists " .. id)
end
-- Only these species live in both the lake and the open sea.
local shared = { Crimsonfish = true, TigerTrout = true, Glacierfish = true }
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
	check(shared[id] or table.find(pool.Fish, id) == nil, "Sea species stay out of the lake: " .. id)
end
for id in shared do
	check(table.find(pool.Fish, id) and table.find(sea.Fish, id), "Shared species are in both pools: " .. id)
end
for _, id in sea.Junk do
	check(seaSeen[id], "Every junk item can be caught at sea: " .. id)
end
check(seaAverage > lakeAverage * 1.5, "Sea catches are worth clearly more on average")

-- Seasons: every pool fish lists its seasons in calendar order; junk bites all year.
local ORDER = { "Spring", "Summer", "Autumn", "Winter" }
local all = { Rain = true, Night = true, Beach = true }
for _, catchPool in Catalog.Pools do
	for _, id in catchPool.Fish do
		local list = Catalog.Fish[id].Seasons
		check(list and #list >= 1 and #list <= 4, id .. " lists its seasons")
		for index = 2, #list do
			check(table.find(ORDER, list[index - 1]) < table.find(ORDER, list[index]), id .. " seasons are in order")
		end
	end
	for _, id in catchPool.Junk do
		check(Catalog.Fish[id].Seasons == nil, id .. " turns up all year")
	end
	check(#catchPool.Fish > 0, catchPool.Name .. " pool itself is untouched")
	for _, season in ORDER do
		local open = FishCatch.inSeason(catchPool, Catalog.Fish, season, all)
		check(#open.Fish > 0 and #open.Junk == #catchPool.Junk, catchPool.Name .. " has fish in " .. season)
		for _, id in open.Fish do
			check(table.find(Catalog.Fish[id].Seasons, season), id .. " only bites in its seasons")
		end
	end
end
local summerOnly = { Fish = { "Trout" }, Junk = { "WoodenBranch" } }
local winter = FishCatch.inSeason(summerOnly, Catalog.Fish, "Winter")
check(#winter.Fish == 0, "Summer fish are gone in winter")
for _ = 1, 200 do
	local roll = FishCatch.roll(winter, Catalog.Fish, Catalog.Rarities, rng)
	check(Catalog.Fish[roll.FishId].Rarity == "Junk", "Out-of-season casts only land junk")
end
local mixed = { Fish = { "Trout", "ShoreCrab" } }
local offSeason = FishCatch.inSeason(mixed, Catalog.Fish, "Autumn")
check(#offSeason.Fish == 1 and offSeason.Fish[1] == "ShoreCrab", "Species without a season stay in every season")
local winterLake = FishCatch.inSeason(pool, Catalog.Fish, "Winter", all)
for _, id in { "Glacierfish", "Lingcod", "Walleye", "MidnightCarp", "TigerTrout" } do
	check(table.find(winterLake.Fish, id), id .. " bites in the winter lake")
end
check(table.find(winterLake.Fish, "Trout") == nil, "Summer-only lake fish are gone in winter")

-- Conditions: rain, night and beach species only bite when that holds.
local conditional = { Fish = { "Tilapia", "RainbowTrout", "MidnightCarp", "Crimsonfish", "Pike" } }
local function bites(season, conditions)
	local open = {}
	for _, id in FishCatch.inSeason(conditional, Catalog.Fish, season, conditions).Fish do
		open[id] = true
	end
	return open
end
local dry = bites("Summer", { Rain = false, Night = false, Beach = false })
check(
	dry.Pike and not dry.Tilapia and not dry.RainbowTrout and not dry.Crimsonfish,
	"Conditional fish need their condition"
)
check(next(bites("Summer", nil)) == "Pike", "Without conditions only unconditional fish bite")
local wet = bites("Summer", { Rain = true })
check(wet.Tilapia and wet.RainbowTrout and not wet.Crimsonfish, "Rain brings tilapia and rainbow trout")
check(bites("Summer", { Beach = true }).Crimsonfish, "Crimsonfish bite at beaches")
check(bites("Autumn", { Night = true }).MidnightCarp, "Midnight carp bite at night")
check(not bites("Summer", { Night = true }).MidnightCarp, "Midnight carp still keep their seasons")

-- Bestiary labels read each season list as one range.
for id, label in
	{
		Trout = "Summer",
		Pike = "Summer–Autumn",
		Herring = "Winter–Spring",
		MidnightCarp = "Autumn–Spring (night)",
		RedSnapper = "Summer–Winter",
		Flounder = "All year",
		Tilapia = "Summer–Autumn (rain)",
		Crimsonfish = "Summer (beach)",
		ShoreCrab = "All year",
	}
do
	check(FishCatch.seasonLabel(Catalog.Fish[id]) == label, id .. " season label is " .. label)
end

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
