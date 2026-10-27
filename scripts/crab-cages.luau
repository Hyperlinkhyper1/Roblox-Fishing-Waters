-- Pure crab cage checks: buying, placing, soaking, hauling and wearing out, the
-- saved shape in AnglerData and the crab species. No Roblox runtime.
-- Run: lute run scripts/crab-cages.luau
local fs = require("@lute/fs")
local luau = require("@lute/luau")
local Data = require("../src/server/AnglerData")
local CrabCages = require("../src/shared/CrabCages")
local FishCatch = require("../src/shared/FishCatch")
local FishMutations = require("../src/shared/FishMutations")
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
local function wallet(cash, angler)
	return { Cash = cash, Angler = Data.decode(angler) }
end

-- Saved shape: old profiles gain an empty list; malformed cages never load.
local fresh = Data.decode(nil)
check(fresh.CrabCages.Stock == 0 and #fresh.CrabCages.Placed == 0, "Fresh profiles own no cages")
check(Data.decode({ Stats = { TotalCaught = 3 } }).CrabCages.Stock == 0, "Old profiles start without cages")
for _, bad in
	{
		{ CrabCages = "three" },
		{ CrabCages = { Stock = -1, Placed = {} } },
		{ CrabCages = { Stock = 1.5, Placed = {} } },
		{ CrabCages = { Stock = 0 } },
		{ CrabCages = { Stock = 0, Placed = { { X = 0 / 0, Z = 1, Uses = 3, ReadyAt = 10 } } } },
		{ CrabCages = { Stock = 0, Placed = { { X = 1, Z = 1, Uses = 0, ReadyAt = 10 } } } },
		{ CrabCages = { Stock = 0, Placed = { { X = 1, Z = 1, Uses = 2, ReadyAt = "soon" } } } },
		{ CrabCages = { Stock = 0, Placed = { Spot = { X = 1, Z = 1, Uses = 2, ReadyAt = 1 } } } },
	}
do
	check(not pcall(Data.decode, bad), "Malformed crab cages are rejected")
end
local saved = Data.decode({ CrabCages = { Stock = 2, Placed = { { X = -3.5, Z = -20, Uses = 2, ReadyAt = 99 } } } })
check(saved.CrabCages.Stock == 2 and saved.CrabCages.Placed[1].X == -3.5, "Saved cages survive decoding")

-- Buying at Tide & Tackle.
check(CrabCages.PRICE == 35 and CrabCages.USES == 3, "A cage costs $35 and lasts three hauls")
check(CrabCages.buyProblem(wallet(34)) ~= nil, "Too little cash buys no cage")
local buyer = wallet(100)
CrabCages.buy(buyer)
check(
	buyer.Cash == 65 and buyer.Angler.CrabCages.Stock == 1 and buyer.Angler.Stats.CoinsSpent == 35,
	"Buying charges $35 and adds one cage"
)
local hoard = wallet(1e6, { CrabCages = { Stock = CrabCages.MAX_STOCK, Placed = {} } })
check(CrabCages.buyProblem(hoard) ~= nil and not pcall(CrabCages.buy, hoard), "Stock is capped")

-- Soaks last one to three minutes, in whole seconds.
local shortest, longest = math.huge, -math.huge
for _, sample in { 0, 0.25, 0.5, 0.999999 } do
	local soak = CrabCages.soak(function()
		return sample
	end)
	check(soak % 1 == 0, "Soaks are whole seconds")
	shortest, longest = math.min(shortest, soak), math.max(longest, soak)
end
check(shortest == 60 and longest == 180, "A crab crawls in after 1 to 3 minutes")

-- Placing by the dock.
local angler = Data.decode({ CrabCages = { Stock = 2, Placed = {} } })
check(CrabCages.placeProblem(Data.decode(nil), 0, -20) ~= nil, "Placing needs a cage in stock")
for _, spot in { { 0, 10 }, { 0, -60 }, { 30, -20 }, { -30, -20 }, { 0 / 0, -20 } } do
	check(CrabCages.placeProblem(angler, spot[1], spot[2]) ~= nil, "Cages stay in the water by the dock")
end
CrabCages.place(angler, 0.04, -20.06, 1000, 90)
local cage = angler.CrabCages.Placed[1]
check(
	angler.CrabCages.Stock == 1 and cage.X == 0 and cage.Z == -20.1 and cage.Uses == 3 and cage.ReadyAt == 1090,
	"A dropped cage leaves stock, rounds its spot and starts soaking"
)
check(CrabCages.placeProblem(angler, 2, -21) ~= nil, "Cages keep their distance")
check(CrabCages.placeProblem(angler, 6, -20) == nil, "A cage further along is fine")
check(Data.decode(angler).CrabCages.Placed[1].ReadyAt == 1090, "A placed cage saves")
local many = Data.decode({ CrabCages = { Stock = 10, Placed = {} } })
for index = 1, CrabCages.MAX_PLACED do
	CrabCages.place(many, -20 + index * 5, -10, 0, 60)
end
check(CrabCages.placeProblem(many, 0, -30) ~= nil and many.CrabCages.Stock == 4, "Only so many cages go out at once")

-- Hauling, three times, then the cage is gone.
check(CrabCages.collectProblem(angler, 0, -20.1, 1089) ~= nil, "Nothing to haul before the soak ends")
check(CrabCages.collectProblem(angler, 5, -5, 2000) ~= nil, "Unknown cages can't be hauled")
check(CrabCages.remaining(cage, 1080) == 10 and CrabCages.remaining(cage, 1200) == 0, "The countdown stops at 0")
check(
	CrabCages.collect(angler, 0, -20.1, 1090, 120) == 2
		and angler.CrabCages.Placed[1].ReadyAt == 1210
		and angler.Stats.CrabCagesOpened == 1,
	"A haul uses the cage once and starts the next soak"
)
check(CrabCages.collect(angler, 0, -20.1, 1210, 60) == 1, "Second haul")
check(
	CrabCages.collect(angler, 0, -20.1, 1270, 60) == 0 and #angler.CrabCages.Placed == 0,
	"A cage wears out after three hauls"
)
check(angler.Stats.CrabCagesOpened == 3, "Every haul counts towards Crab Cages Opened")
check(not pcall(CrabCages.collect, angler, 0, -20.1, 9999, 60), "A worn-out cage can't be hauled")

-- Crabs: fully defined, only from cages, and a cage pays for itself.
for _, id in CrabCages.Pool.Fish do
	local crab = Catalog.Fish[id]
	check(crab ~= nil and crab.Shapes ~= nil and crab.Shapes.Normal ~= nil, "Crab is fully defined: " .. id)
	check(crab.MinKg < crab.AverageKg and crab.AverageKg < crab.MaxKg, "Normal weight sits inside the range: " .. id)
	for _, pool in Catalog.Pools do
		check(
			table.find(pool.Fish, id) == nil and table.find(pool.Junk or {}, id) == nil,
			"Crabs never bite a line: " .. id
		)
	end
end
local state = 4242
local function rng()
	state = (state * 16807) % 2147483647
	return state / 2147483647
end
local total, seen = 0, {}
local rolls = 30000
for _ = 1, rolls do
	local roll = FishCatch.roll(CrabCages.Pool, Catalog.Fish, Catalog.Rarities, rng)
	check(table.find(CrabCages.Pool.Fish, roll.FishId) ~= nil, "Cages only catch crabs")
	seen[roll.FishId] = (seen[roll.FishId] or 0) + 1
	total += roll.Value
end
check(
	seen.ShoreCrab > seen.BlueCrab and seen.BlueCrab > seen.KingCrab and seen.KingCrab > 0,
	"Shore crabs are commonest and king crabs rarest"
)
local perCage = total / rolls * CrabCages.USES
check(perCage > CrabCages.PRICE * 1.3 and perCage < CrabCages.PRICE * 4, "A cage pays back its price, but modestly")
local caught = Data.recordCatch(nil, "KingCrab", "Normal", 2.6, 60, 1, Catalog.Fish, Catalog.Mutations, "Normal")
check(caught.Hand.FishId == "KingCrab" and caught.Catches.KingCrab.Count == 1, "Crabs land in hand and the bestiary")
local function crabRoll(pick)
	local calls = 0
	return FishMutations.roll(Catalog.Fish.KingCrab, false, function()
		calls += 1
		return if calls == 1 then pick else 0.5
	end, { mutation = CrabCages.MUTATION_BONUS })
end
check(crabRoll(0.008).Mutation ~= "Normal", "Crab bonus allows mutations beyond the fish base chance")
check(crabRoll(0.01).Mutation == "Normal", "Crab base mutation chance stops at 1%")
local traits = { Mutation = "Neon", NeonColor = "Blue" }
local value = FishMutations.value(60, traits.Mutation, traits.Corruptions)
local mutated = Data.recordCatch(nil, "KingCrab", traits.Mutation, 2.6, value, 1, Catalog.Fish, Catalog.Mutations, "Normal", traits)
check(mutated.Hand.Mutation == "Neon" and mutated.Hand.NeonColor == "Blue" and mutated.Hand.Value == 120, "Crab mutation traits and value are saved")

print(string.format("Crab cages: %d checks passed ($%.0f of crab per cage on average).", checks, perCage))
