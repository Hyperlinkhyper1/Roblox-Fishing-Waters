-- Pure catch rules for the trawler's purchased stern net. The net only lands
-- common fish and the occasional uncommon one, so the rarity tiers above
-- Uncommon are filtered out before the roll. Shared by the server (which rolls
-- and awards) and the saved-data tests (which drive it with fixed RNG values).
local FishCatch = if script then require(script.Parent.FishCatch) else require("./FishCatch")

local TrawlerNet = {}

TrawlerNet.MinSpeed = 6 -- studs/s: the hull must be underway for the net to fish
TrawlerNet.MinSeconds = 2.8
TrawlerNet.MaxSeconds = 5.2
TrawlerNet.UncommonChance = 0.2

-- Common and uncommon species in a catch pool, in catalog order.
function TrawlerNet.candidates(pool, species)
	local common, uncommon = {}, {}
	for _, id in pool.Fish or {} do
		local fish = species[id]
		if fish then
			if fish.Rarity == "Common" then
				table.insert(common, id)
			elseif fish.Rarity == "Uncommon" then
				table.insert(uncommon, id)
			end
		end
	end
	return common, uncommon
end

-- One species from the pool: uncommon with UncommonChance, common otherwise.
-- A pool with no common fish still falls back to the uncommon ones.
function TrawlerNet.pickSpecies(pool, species, rng: () -> number): string?
	local common, uncommon = TrawlerNet.candidates(pool, species)
	local bag = if #uncommon > 0 and rng() < TrawlerNet.UncommonChance
		then uncommon
		elseif #common > 0 then common
		else uncommon
	if #bag == 0 then
		return nil
	end
	return bag[math.floor(rng() * #bag) + 1]
end

-- A net catch is an ordinary fish record, but it never enters the hand or the
-- backpack. `rarities` supplies the difficulty tier for a plausible record.
function TrawlerNet.roll(pool, species, rarities, rng: () -> number)
	local id = TrawlerNet.pickSpecies(pool, species, rng)
	if not id then
		return nil
	end
	local fish = species[id]
	local kg, size = FishCatch.rollWeight(fish, rng)
	local relative = kg / fish.AverageKg
	return {
		FishId = id,
		Kg = kg,
		Size = size,
		Value = FishCatch.value(fish, kg, size),
		Relative = relative,
		Difficulty = FishCatch.difficulty(fish, rarities, relative),
	}
end

-- Seconds until the next net catch.
function TrawlerNet.nextInterval(rng: () -> number): number
	return TrawlerNet.MinSeconds + (TrawlerNet.MaxSeconds - TrawlerNet.MinSeconds) * rng()
end

return TrawlerNet
