-- Pure catch rules shared by the server (which rolls and awards) and the client
-- (which only presents). Every roll takes a uniform [0, 1) source so tests can
-- drive it without Roblox's Random.
local FishCatch = {}

FishCatch.JUNK_CHANCE = 0.04 -- 2% each for the branch and boot, in every stocked pool.
FishCatch.BIG_CHANCE = 0.06
FishCatch.HUGE_CHANCE = 0.012
FishCatch.START_PROGRESS = 0.3
-- Each new zone starts away from the needle, so a real hit needs travel time.
FishCatch.SECONDS_PER_HIT = 0.15

export type Roll = {
	FishId: string,
	Kg: number,
	Size: string, -- "Normal", "Big" or "Huge"
	Value: number,
	Relative: number,
	Difficulty: number,
}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function FishCatch.pickSpecies(pool, species, rng: () -> number): string
	local pick = rng()
	if pool.Junk and #pool.Junk > 0 then
		if pick < FishCatch.JUNK_CHANCE then
			return pool.Junk[math.floor(pick / FishCatch.JUNK_CHANCE * #pool.Junk) + 1]
		end
		-- Keep the existing relative fish odds within the remaining 96%.
		pick = (pick - FishCatch.JUNK_CHANCE) / (1 - FishCatch.JUNK_CHANCE)
	end
	local total = 0
	for _, id in pool.Fish do
		total += 1 / species[id].RarityDenominator
	end
	pick *= total
	for _, id in pool.Fish do
		pick -= 1 / species[id].RarityDenominator
		if pick < 0 then
			return id
		end
	end
	return pool.Fish[#pool.Fish]
end

-- Most fish cluster around the species average; a few are big and a rare few
-- approach the species record weight.
function FishCatch.rollWeight(fish, rng: () -> number): (number, string)
	local average, minimum, maximum = fish.AverageKg, fish.MinKg, fish.MaxKg
	if fish.Rarity == "Junk" then
		return math.floor(lerp(minimum, maximum, rng()) * 100 + 0.5) / 100, "Normal"
	end
	local roll = rng()
	local kg, size
	if roll < FishCatch.HUGE_CHANCE then
		local floor = math.min(average * 3, maximum)
		kg, size = floor + (maximum - floor) * rng() ^ 2, "Huge"
	elseif roll < FishCatch.HUGE_CHANCE + FishCatch.BIG_CHANCE then
		kg, size = average * lerp(1.7, 3, rng()), "Big"
	else
		-- Box-Muller normal sample, applied in log space so weights stay positive.
		local z = math.sqrt(-2 * math.log(math.max(rng(), 1e-9))) * math.cos(2 * math.pi * rng())
		kg, size = math.clamp(average * math.exp(z * 0.22), minimum, average * 1.7), "Normal"
	end
	kg = math.max(0.01, math.floor(math.clamp(kg, minimum, maximum) * 100 + 0.5) / 100)
	return kg, size
end

function FishCatch.value(fish, kg: number, size: string): number
	if fish.Rarity == "Junk" then
		return fish.BaseValue
	end
	local worth = fish.BaseValue * (kg / fish.AverageKg) ^ 0.9 * (if size == "Huge" then 1.5 else 1)
	return math.max(1, math.floor(worth + 0.5))
end

-- 0 is a lazy minnow, 1 is the hardest fight in the game. Rarity sets the base;
-- heavier-than-average fish fight noticeably harder.
function FishCatch.difficulty(fish, rarities, relative: number): number
	if fish.Rarity == "Junk" then
		return rarities.Junk.Difficulty
	end
	local base = rarities[fish.Rarity].Difficulty + (fish.Fight or 0)
	local sizeBonus = if relative >= 1
		then math.min(0.26, 0.14 * math.log(relative, 2))
		else math.max(-0.06, 0.1 * math.log(relative, 2))
	return math.clamp(base + sizeBonus, 0.05, 1)
end

function FishCatch.roll(pool, species, rarities, rng: () -> number): Roll
	local id = FishCatch.pickSpecies(pool, species, rng)
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

-- Reel minigame tuning. Progress starts at START_PROGRESS; reaching 1 lands the
-- fish and reaching 0 lets it escape.
function FishCatch.tuning(difficulty: number)
	local d = math.clamp(difficulty, 0, 1)
	return {
		needleSpeed = lerp(0.55, 1.65, d), -- arc lengths per second
		zoneSize = lerp(0.3, 0.09, d), -- fraction of the arc
		zoneDrift = if d > 0.45 then lerp(0, 0.38, (d - 0.45) / 0.55) else 0,
		erratic = d > 0.72,
		gain = lerp(0.25, 0.12, d),
		missPenalty = lerp(0.1, 0.2, d),
		drain = lerp(0.012, 0.045, d), -- progress lost per second
	}
end

function FishCatch.minimumFightSeconds(difficulty: number): number
	local hits = math.ceil((1 - FishCatch.START_PROGRESS) / FishCatch.tuning(difficulty).gain)
	return hits * FishCatch.SECONDS_PER_HIT
end

local titles = {
	Junk = "SOMETHING ON THE LINE",
	Common = "RIPPLING WATER",
	Uncommon = "DISTURBED WATER",
	Rare = "CHURNING WATER",
	Epic = "VIOLENT WATER",
	Legendary = "RAGING WATER",
}
function FishCatch.title(fish): string
	return titles[fish.Rarity] or "DISTURBED WATER"
end

function FishCatch.strength(difficulty: number): string
	return if difficulty < 0.25
		then "Weak"
		elseif difficulty < 0.45 then "Medium"
		elseif difficulty < 0.65 then "Strong"
		elseif difficulty < 0.85 then "Fierce"
		else "Monstrous"
end

function FishCatch.formatKg(kg: number): string
	return if kg >= 100 then string.format("%.0f kg", kg) else string.format("%.2f kg", kg)
end

return FishCatch
