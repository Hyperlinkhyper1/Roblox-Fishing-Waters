-- Pure rod upgrade checks: prices, saved levels, the wallet transaction and the
-- catch boosts. Run: lute run scripts/rod-upgrades.luau. No Roblox runtime.
local fs = require("@lute/fs")
local luau = require("@lute/luau")
local BoatData = require("../src/server/BoatData")
local FishCatch = require("../src/shared/FishCatch")
local RodUpgrades = require("../src/shared/RodUpgrades")
local file = fs.open("src/shared/AnglerCatalog.luau", "r")
local source = fs.read(file)
fs.close(file)
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

-- Every level costs more than the last, and Rarity Luck is always the priciest.
for _, stat in RodUpgrades.Order do
	local spec = RodUpgrades.Stats[stat]
	local previous = 0
	for level = 0, spec.MaxLevel - 1 do
		local price = RodUpgrades.price(stat, level)
		check(price ~= nil and price > previous and price % 5 == 0, stat .. " prices must climb in $5 steps")
		previous = price :: number
	end
	check(RodUpgrades.price(stat, spec.MaxLevel) == nil, stat .. " must stop at its max level")
end
for level = 0, 9 do
	local luck = RodUpgrades.price("Luck", level) :: number
	check(
		luck > (RodUpgrades.price("Speed", level) :: number) and luck > (RodUpgrades.price("Strength", level) :: number),
		"Rarity Luck must be the most expensive upgrade at every level"
	)
end

-- Saved levels: old profiles migrate, malformed ones are rejected.
local fresh = BoatData.decode(nil)
check(next(fresh.RodUpgrades) == nil, "New profiles start with a stock rod")
local legacy = BoatData.decode({ Version = 1, Cash = 0, OwnedBoats = {} })
check(type(legacy.RodUpgrades) == "table", "Profiles saved before upgrades must load")
for _, bad in { { Speed = -1 }, { Speed = 1.5 }, { Bogus = 1 }, { Speed = "2" } } do
	check(
		not pcall(BoatData.decode, { Version = 1, Cash = 0, OwnedBoats = {}, RodUpgrades = bad }),
		"Malformed upgrade levels must be rejected"
	)
end
check(
	BoatData.decode({ Version = 1, Cash = 0, OwnedBoats = {}, RodUpgrades = { Speed = 40 } }).RodUpgrades.Speed == 10,
	"Levels above the cap are clamped"
)

-- The transaction charges the current level's price and saves the next level.
local profile = BoatData.decode({ Version = 1, Cash = 100000, OwnedBoats = {}, OwnedRods = {} })
check(BoatData.upgradeRod(profile, "Speed") == "NoRod", "Upgrades need the starter rod")
profile.OwnedRods.StarterRod = true
check(BoatData.upgradeRod(profile, "Nope") == "UnknownUpgrade", "Unknown stats are rejected")
local cash = profile.Cash
check(BoatData.upgradeRod(profile, "Luck") == "Upgraded", "Affordable upgrades succeed")
check(profile.RodUpgrades.Luck == 1, "The new level is saved")
check(cash - profile.Cash == RodUpgrades.price("Luck", 0), "The level's price is charged")
check(profile.Angler.Stats.CoinsSpent == RodUpgrades.price("Luck", 0), "Spending is tracked")
profile.Cash = (RodUpgrades.price("Luck", 1) :: number) - 1
cash = profile.Cash
check(BoatData.upgradeRod(profile, "Luck") == "InsufficientFunds", "Short wallets are refused")
check(profile.Cash == cash and profile.RodUpgrades.Luck == 1, "A refused upgrade changes nothing")
profile.Cash, profile.RodUpgrades.Speed = 10 ^ 9, 10
check(BoatData.upgradeRod(profile, "Speed") == "Maxed", "Maxed stats cannot be bought again")
check(BoatData.decode(profile).RodUpgrades.Luck == 1, "Upgraded profiles round-trip")

-- Boosts: a stock rod rolls exactly as before; upgrades shift the odds.
local stock = RodUpgrades.boosts(nil)
check(stock.reel == 1 and stock.size == 1 and stock.luck == 0, "Stock rods have no boost")
local maxed = RodUpgrades.boosts({ Speed = 10, Strength = 10, Luck = 10 })
check(
	FishCatch.minimumFightSeconds(0.7, maxed.reel) < FishCatch.minimumFightSeconds(0.7),
	"Reel Speed shortens the fight"
)
check(FishCatch.tuning(0.5, maxed.reel).gain > FishCatch.tuning(0.5).gain, "Reel Speed adds progress per hit")

local function sample(boosts, seed)
	local random = Random and Random.new(seed)
	local state = seed
	local function rng()
		if random then
			return random:NextNumber()
		end
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	local pool = Catalog.Pools.OpenSea
	local rare, big, total = 0, 0, 60000
	for _ = 1, total do
		local roll = FishCatch.roll(pool, Catalog.Fish, Catalog.Rarities, rng, boosts)
		local rarity = Catalog.Fish[roll.FishId].Rarity
		if rarity == "Rare" or rarity == "Epic" or rarity == "Legendary" then
			rare += 1
		end
		if roll.Size ~= "Normal" then
			big += 1
		end
	end
	return rare / total, big / total
end
local stockRare, stockBig = sample(nil, 7)
local luckRare = sample(RodUpgrades.boosts({ Luck = 10 }), 7)
local _, strongBig = sample(RodUpgrades.boosts({ Strength = 10 }), 7)
check(luckRare > stockRare * 1.3, "Rarity Luck must noticeably raise rare catches")
check(strongBig > stockBig * 1.8, "Line Strength must noticeably raise big catches")

print(
	string.format(
		"Rod upgrades: %d checks passed. Rare+ %.1f%% -> %.1f%% at max luck; big/huge %.1f%% -> %.1f%% at max strength.",
		checks,
		stockRare * 100,
		luckRare * 100,
		stockBig * 100,
		strongBig * 100
	)
)
