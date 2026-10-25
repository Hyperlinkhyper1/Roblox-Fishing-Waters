-- Rod upgrades sold by Finn at the Tide & Tackle counter. Each stat has its own
-- level; every level costs more than the last. The server charges and saves
-- levels; FishCatch applies the boosts on both sides so the fight and the
-- server's plausibility check always agree.
local RodUpgrades = {}

RodUpgrades.Order = { "Speed", "Strength", "Luck" }
RodUpgrades.Stats = {
	Speed = {
		Name = "Reel Speed",
		Description = "Every hit in the reel fight pulls the fish in further.",
		MaxLevel = 10,
		BasePrice = 120,
		Growth = 1.45,
	},
	Strength = {
		Name = "Line Strength",
		Description = "A tougher line hooks big and huge fish more often.",
		MaxLevel = 10,
		BasePrice = 200,
		Growth = 1.5,
	},
	Luck = {
		Name = "Rarity Luck",
		Description = "Rare, epic and legendary fish take your bait more often.",
		MaxLevel = 10,
		BasePrice = 500,
		Growth = 1.6,
	},
}

local REEL_PER_LEVEL = 0.07 -- +7% progress per hit
local SIZE_PER_LEVEL = 0.15 -- +15% big and huge chance
local LUCK_PER_LEVEL = 0.03 -- flattens the rarity curve

function RodUpgrades.attribute(stat: string): string
	return "RodUpgrade" .. stat
end

function RodUpgrades.valid(stat: any): boolean
	return type(stat) == "string" and RodUpgrades.Stats[stat] ~= nil
end

-- Cost of buying the level after `level`, or nil once the stat is maxed.
function RodUpgrades.price(stat: string, level: number): number?
	local spec = RodUpgrades.Stats[stat]
	if not spec or level >= spec.MaxLevel then
		return nil
	end
	return math.floor(spec.BasePrice * spec.Growth ^ level / 5 + 0.5) * 5
end

-- Missing or malformed levels count as 0, so old saves and tests need no migration.
function RodUpgrades.level(levels: any, stat: string): number
	local value = type(levels) == "table" and levels[stat]
	local spec = RodUpgrades.Stats[stat]
	if type(value) ~= "number" or value % 1 ~= 0 or not spec then
		return 0
	end
	return math.clamp(value, 0, spec.MaxLevel)
end

export type Boosts = { reel: number, size: number, luck: number }

function RodUpgrades.boosts(levels: any): Boosts
	return {
		reel = 1 + REEL_PER_LEVEL * RodUpgrades.level(levels, "Speed"),
		size = 1 + SIZE_PER_LEVEL * RodUpgrades.level(levels, "Strength"),
		luck = LUCK_PER_LEVEL * RodUpgrades.level(levels, "Luck"),
	}
end

-- Short player-facing summary of what a level gives.
function RodUpgrades.effect(stat: string, level: number): string
	if stat == "Speed" then
		return string.format("+%d%% reel per hit", math.floor(REEL_PER_LEVEL * level * 100 + 0.5))
	elseif stat == "Strength" then
		return string.format("+%d%% big fish chance", math.floor(SIZE_PER_LEVEL * level * 100 + 0.5))
	end
	return string.format("+%d%% rare fish luck", math.floor(LUCK_PER_LEVEL * level * 100 + 0.5))
end

return RodUpgrades
