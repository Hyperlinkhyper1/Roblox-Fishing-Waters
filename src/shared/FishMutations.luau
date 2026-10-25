-- Pure mutation rules shared by the server (which rolls and prices) and every
-- model builder (which paints). A record's Mutation is a "+"-joined key such as
-- "Corrupted+Rainbow+Neon"; Neon catches also carry NeonColor and Corrupted ones
-- carry Corruptions, the list of extra body parts. Rolls take a uniform [0, 1)
-- source so tests can drive them without Roblox's Random.
local FishMutations = {}

-- Chance that a catch carries any mutation at all, Astral included.
FishMutations.CHANCE = 0.005
-- Astral only surfaces at night (DayNight.isNight), at this share of every night catch.
FishMutations.ASTRAL_CHANCE = 1 / 1500
FishMutations.ASTRAL_RAINBOW_CHANCE = 0.15
-- Any other mutation can also come out corrupted.
FishMutations.CORRUPTED_EXTRA_CHANCE = 0.1
-- Each corrupted part beyond the first.
FishMutations.EXTRA_CORRUPTION_CHANCE = 0.25
FishMutations.CORRUPTED_BONUS = 1.5

-- Display and key order.
FishMutations.Order = { "Corrupted", "Astral", "Rainbow", "Neon", "Albino" }

-- Every colour outcome with its share of the non-Astral mutation chance and the
-- worth it adds (1 = +100%).
FishMutations.Outcomes = {
	{ Key = "Neon", Weight = 46, Bonus = 1 },
	{ Key = "Albino", Weight = 20, Bonus = 1.5 },
	{ Key = "Corrupted", Weight = 14, Bonus = 0 },
	{ Key = "Rainbow", Weight = 10, Bonus = 2 },
	{ Key = "Neon+Albino", Weight = 6, Bonus = 5 },
	{ Key = "Rainbow+Neon", Weight = 4, Bonus = 6 },
}
FishMutations.AstralOutcomes = {
	Astral = 10,
	["Astral+Rainbow"] = 20,
}

FishMutations.NeonColors = {
	Red = { 255, 46, 58 },
	Orange = { 255, 136, 24 },
	Yellow = { 255, 232, 40 },
	Green = { 40, 255, 96 },
	Blue = { 36, 140, 255 },
	Purple = { 170, 60, 255 },
	Rose = { 255, 80, 170 },
	White = { 245, 248, 255 },
}
FishMutations.NeonColorOrder = { "Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Rose", "White" }
FishMutations.Corruptions = { "Tail", "Eye", "Fin", "Bone" }

local totalWeight = 0
for _, outcome in FishMutations.Outcomes do
	totalWeight += outcome.Weight
end

function FishMutations.parts(key: string?): { [string]: boolean }
	local set = {}
	if key and key ~= "Normal" then
		for name in string.gmatch(key, "[^+]+") do
			set[name] = true
		end
	end
	return set
end

-- Canonical key for a set of mutation names; "Normal" when empty.
function FishMutations.key(set: { [string]: boolean }): string
	local names = {}
	for _, name in FishMutations.Order do
		if set[name] then
			table.insert(names, name)
		end
	end
	return if #names > 0 then table.concat(names, "+") else "Normal"
end

local function colourBonus(set): number
	local plain = table.clone(set)
	plain.Corrupted = nil
	local key = FishMutations.key(plain)
	if FishMutations.AstralOutcomes[key] then
		return FishMutations.AstralOutcomes[key]
	end
	for _, outcome in FishMutations.Outcomes do
		if outcome.Key == key then
			return outcome.Bonus
		end
	end
	return 0
end

-- Worth multiplier: colour bonus plus CORRUPTED_BONUS for every corrupted part.
function FishMutations.multiplier(key: string?, corruptions: { string }?): number
	local set = FishMutations.parts(key)
	local bonus = colourBonus(set)
	if set.Corrupted then
		bonus += FishMutations.CORRUPTED_BONUS * math.max(1, if corruptions then #corruptions else 1)
	end
	return 1 + bonus
end

function FishMutations.value(value: number, key: string?, corruptions: { string }?): number
	return math.max(1, math.floor(value * FishMutations.multiplier(key, corruptions) + 0.5))
end

-- Chance that one catch comes out with exactly this key (any corruption count).
function FishMutations.chance(key: string, night: boolean): number
	local set = FishMutations.parts(key)
	if not next(set) then
		return 1 - FishMutations.CHANCE
	end
	local corrupted = set.Corrupted
	set.Corrupted = nil
	local colour = FishMutations.key(set)
	local astral = if night then FishMutations.ASTRAL_CHANCE else 0
	if colour == "Normal" then
		-- Plain corruption is its own outcome, never an add-on.
		return (FishMutations.CHANCE - astral) * 14 / totalWeight
	end
	local base
	if colour == "Astral" then
		base = astral * (1 - FishMutations.ASTRAL_RAINBOW_CHANCE)
	elseif colour == "Astral+Rainbow" then
		base = astral * FishMutations.ASTRAL_RAINBOW_CHANCE
	else
		base = 0
		for _, outcome in FishMutations.Outcomes do
			if outcome.Key == colour then
				base = (FishMutations.CHANCE - astral) * outcome.Weight / totalWeight
			end
		end
	end
	return base * (if corrupted then FishMutations.CORRUPTED_EXTRA_CHANCE else 1 - FishMutations.CORRUPTED_EXTRA_CHANCE)
end

local function rollCorruptions(rng: () -> number): { string }
	local pool = table.clone(FishMutations.Corruptions)
	local picked = {}
	repeat
		table.insert(picked, table.remove(pool, math.floor(rng() * #pool) + 1))
	until #pool == 0 or rng() >= FishMutations.EXTRA_CORRUPTION_CHANCE
	return picked
end

export type Traits = { Mutation: string, NeonColor: string?, Corruptions: { string }? }

-- Junk never mutates.
function FishMutations.roll(fish, night: boolean, rng: () -> number): Traits
	local pick = rng()
	if fish.Rarity == "Junk" or pick >= FishMutations.CHANCE then
		return { Mutation = "Normal" }
	end
	local key
	if night and pick < FishMutations.ASTRAL_CHANCE then
		key = if rng() < FishMutations.ASTRAL_RAINBOW_CHANCE then "Astral+Rainbow" else "Astral"
	else
		local weight = rng() * totalWeight
		for _, outcome in FishMutations.Outcomes do
			weight -= outcome.Weight
			key = outcome.Key
			if weight < 0 then
				break
			end
		end
	end
	local set = FishMutations.parts(key)
	if not set.Corrupted and rng() < FishMutations.CORRUPTED_EXTRA_CHANCE then
		set.Corrupted = true
	end
	local traits: Traits = { Mutation = FishMutations.key(set) }
	-- Rainbow paints over any neon colour, so it never gets one.
	if set.Neon and not set.Rainbow then
		local order = FishMutations.NeonColorOrder
		traits.NeonColor = order[math.floor(rng() * #order) + 1]
	end
	if set.Corrupted then
		traits.Corruptions = rollCorruptions(rng)
	end
	return traits
end

-- Every key a roll can produce.
function FishMutations.keys(): { string }
	local keys = {}
	local colours = { "Astral", "Astral+Rainbow" }
	for _, outcome in FishMutations.Outcomes do
		if outcome.Key ~= "Corrupted" then
			table.insert(colours, outcome.Key)
		end
	end
	table.insert(keys, "Corrupted")
	for _, colour in colours do
		table.insert(keys, colour)
		local set = FishMutations.parts(colour)
		set.Corrupted = true
		table.insert(keys, FishMutations.key(set))
	end
	return keys
end

-- "Red Neon Albino", "Corrupted Rainbow Neon", or "" for a normal fish.
function FishMutations.label(key: string?, neonColor: string?): string
	local set = FishMutations.parts(key)
	local names = {}
	for _, name in FishMutations.Order do
		if set[name] then
			table.insert(names, if name == "Neon" and neonColor then neonColor .. " Neon" else name)
		end
	end
	return table.concat(names, " ")
end

return FishMutations
