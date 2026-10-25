-- Pure mutation-rule checks against the real catalog. No Roblox runtime.
local fs = require("@lute/fs")
local luau = require("@lute/luau")
local Data = require("../src/server/AnglerData")
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
local state = 4242
local function rng()
	state = (state * 16807) % 2147483647
	return state / 2147483647
end

-- Worth follows the requested bonuses: +100% neon, +150% albino, +200% rainbow,
-- +1000% astral, the listed combos, and +150% per corrupted part on top.
local function near(a, b)
	return math.abs(a - b) < 1e-9
end
for key, multiplier in
	{
		Normal = 1,
		Neon = 2,
		Albino = 2.5,
		Rainbow = 3,
		Astral = 11,
		["Neon+Albino"] = 6,
		["Rainbow+Neon"] = 7,
		["Astral+Rainbow"] = 21,
	}
do
	check(near(FishMutations.multiplier(key), multiplier), key .. " worth multiplier")
end
check(near(FishMutations.multiplier("Corrupted", { "Tail" }), 2.5), "One corrupted part adds 150%")
check(near(FishMutations.multiplier("Corrupted", { "Tail", "Bone", "Eye" }), 5.5), "Corrupted parts stack")
check(near(FishMutations.multiplier("Corrupted+Rainbow+Neon", { "Fin", "Eye" }), 10), "Corruption stacks on combos")
check(FishMutations.value(10, "Neon") == 20 and FishMutations.value(1, "Normal") == 1, "Value rounds the multiplied worth")

-- Every rollable key is in the catalog with a rarity matching its odds.
local keys = FishMutations.keys()
check(#keys == 15, "Seven colour outcomes, each optionally corrupted, plus plain corruption")
local listed = 0
for key in Catalog.Mutations do
	listed += 1
end
check(listed == #keys + 1, "Catalog lists every key plus Normal")
for _, key in keys do
	local entry = Catalog.Mutations[key]
	check(entry ~= nil, key .. " is in the catalog")
	check(FishMutations.key(FishMutations.parts(key)) == key, key .. " is canonical")
	local expected = 1 / FishMutations.chance(key, FishMutations.parts(key).Astral == true)
	check(math.abs(entry.RarityMultiplier - expected) <= 1, key .. " rarity matches its odds")
	check(entry.Name == FishMutations.label(key), key .. " catalog name matches its label")
end
for _, night in { false, true } do
	local total = 0
	for _, key in keys do
		total += FishMutations.chance(key, night)
	end
	check(math.abs(total - FishMutations.CHANCE) < 1e-12, "Mutation chances add up to 0.5%")
end

-- Rolled odds.
local trout = Catalog.Fish.Trout
check(trout and trout.Rarity ~= "Junk", "Trout is a fish")
local junkId = Catalog.Pools[Catalog.DefaultPool].Junk[1]
local ROLLS = 3000000
for _, night in { false, true } do
	local mutated, astral, counts = 0, 0, {}
	for _ = 1, ROLLS do
		local traits = FishMutations.roll(trout, night, rng)
		local set = FishMutations.parts(traits.Mutation)
		if traits.Mutation ~= "Normal" then
			mutated += 1
			counts[traits.Mutation] = (counts[traits.Mutation] or 0) + 1
			check(Catalog.Mutations[traits.Mutation] ~= nil, "Rolled key is catalogued")
		end
		if set.Astral then
			astral += 1
		end
		check((traits.NeonColor ~= nil) == (set.Neon == true and not set.Rainbow), "Neon colour only on plain neon")
		check(not traits.NeonColor or FishMutations.NeonColors[traits.NeonColor], "Neon colour is a variant")
		check((traits.Corruptions ~= nil) == (set.Corrupted == true), "Corrupted fish list their parts")
		if traits.Corruptions then
			local seen = {}
			for _, part in traits.Corruptions do
				check(table.find(FishMutations.Corruptions, part) and not seen[part], "Corrupted parts are distinct kinds")
				seen[part] = true
			end
		end
	end
	local rate = mutated / ROLLS
	check(math.abs(rate - 0.005) < 0.0004, string.format("About 0.5%% mutate (%.4f%%)", rate * 100))
	if night then
		check(math.abs(astral / ROLLS - 1 / 1500) < 0.00012, "Astral is about 1 in 1500 at night")
	else
		check(astral == 0, "Astral never surfaces by day")
	end
	check((counts.Neon or 0) > (counts.Albino or 0) and (counts.Albino or 0) > (counts.Rainbow or 0), "Neon is most common")
	print(string.format(
		"%s: %.3f%% mutated, astral 1 in %s, neon %d, albino %d, rainbow %d",
		if night then "Night" else "Day",
		rate * 100,
		if astral > 0 then string.format("%.0f", ROLLS / astral) else "never",
		counts.Neon or 0,
		counts.Albino or 0,
		counts.Rainbow or 0
	))
end
for _ = 1, 20000 do
	check(FishMutations.roll(Catalog.Fish[junkId], true, rng).Mutation == "Normal", "Junk never mutates")
end
check(FishMutations.label("Corrupted+Neon+Albino", "Red") == "Corrupted Red Neon Albino", "Label names the neon colour")

-- Saved catches keep their traits and reject malformed ones.
local species = { Trout = { AverageKg = 2, RarityDenominator = 10 } }
local traits = { NeonColor = "Blue", Corruptions = { "Tail", "Eye" } }
local caught = Data.recordCatch(nil, "Trout", "Corrupted+Neon", 3, 70, 100, species, Catalog.Mutations, nil, traits)
traits.Corruptions[1] = "Bone"
check(caught.Hand.NeonColor == "Blue" and caught.Hand.Corruptions[1] == "Tail", "Traits are saved by copy")
check(caught.Hand.Rarity == 10 * Catalog.Mutations["Corrupted+Neon"].RarityMultiplier, "Mutation rarity counts")
check(caught.Catches.Trout.Mutations["Corrupted+Neon"] == 1, "Bestiary counts the combined key")
check(Data.decode(caught).Hand.Corruptions[2] == "Eye", "Traits survive a reload")
local plain = Data.recordCatch(nil, "Trout", "Normal", 3, 30, 100, species, Catalog.Mutations)
check(plain.Hand.NeonColor == nil and plain.Hand.Corruptions == nil, "Normal fish carry no traits")
local bad = Data.decode(caught)
bad.Hand.Corruptions = { 5 }
check(not pcall(Data.decode, bad), "Malformed corruptions are rejected")
bad.Hand.Corruptions, bad.Hand.NeonColor = nil, 3
check(not pcall(Data.decode, bad), "Malformed neon colour is rejected")
check(
	not pcall(Data.recordCatch, nil, "Trout", "Neon+Rainbow", 3, 30, 100, species, Catalog.Mutations),
	"Non-canonical keys are rejected"
)

print(string.format("Fish mutations: %d checks passed (pure data; no Roblox runtime).", checks))
