-- Pure, copy-on-write progress stored inside the existing wallet profile.
local Data = {}
Data.XP_PER_CATCH = 100
Data.XP_LEVEL_STEP = 1000
Data.WEEK_SECONDS = 7 * 24 * 60 * 60
-- Caught fish wait in the cooler until stocked in the shop freezer; a full cooler
-- releases new catches. Shop customers buy fish out of the freezer.
Data.COOLER_CAPACITY = 60
Data.FREEZER_CAPACITY = 120

-- Unix epoch was a Thursday; offset to a Monday at 00:00 UTC.
function Data.weekStart(now)
	return math.floor((now + 3 * 86400) / Data.WEEK_SECONDS) * Data.WEEK_SECONDS - 3 * 86400
end

-- Advancing from level L costs L * 1000 XP: 1000, 2000, 3000, ...
function Data.xpForLevel(level)
	return Data.XP_LEVEL_STEP * ((level - 1) * level / 2)
end

function Data.level(xp)
	local level = math.floor((1 + math.sqrt(1 + 8 * xp / Data.XP_LEVEL_STEP)) / 2)
	-- Keep exact thresholds correct if the square root rounds at large totals.
	if xp < Data.xpForLevel(level) then
		level -= 1
	elseif xp >= Data.xpForLevel(level + 1) then
		level += 1
	end
	return level
end

function Data.levelProgress(xp)
	local level = Data.level(xp)
	return level, xp - Data.xpForLevel(level), level * Data.XP_LEVEL_STEP
end
Data.DefaultSettings =
	{ Shadows = true, WeatherEffects = true, MasterVolume = 100, MusicVolume = 100, EffectsVolume = 100 }
local defaults = {
	TotalCaught = 0,
	CatchStreak = 0,
	HighestCatchStreak = 0,
	CoinsEarned = 0,
	CoinsSpent = 0,
	Deaths = 0,
	AstralAnomaliesActivated = 0,
	BestiaryPagesCompleted = 0,
	LimitedBestiariesCompleted = 0,
	PermanentBestiariesCompleted = 0,
	TreasureChestsOpened = 0,
	SunkenChestsOpened = 0,
	CrabCagesOpened = 0,
}

local function number(value, integer)
	return type(value) == "number" and value >= 0 and value < 2 ^ 53 and (not integer or value % 1 == 0)
end
local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in value do
		result[key] = copy(item)
	end
	return result
end
local function recordValid(record)
	return type(record) == "table"
		and type(record.FishId) == "string"
		and type(record.Mutation) == "string"
		and number(record.Kg, false)
		and record.Kg > 0
		and number(record.Value, false)
		and number(record.Rarity, false)
		and record.Rarity >= 1
		and number(record.Relative, false)
		and number(record.CaughtAt, true)
		and (record.Size == nil or type(record.Size) == "string")
end
function Data.validSetting(key, value)
	local default = Data.DefaultSettings[key]
	return default ~= nil
		and (if type(default) == "boolean" then type(value) == "boolean" else number(value, true) and value <= 100)
end
function Data.decode(raw)
	assert(raw == nil or type(raw) == "table", "Invalid angler progress")
	local data = copy(raw or {})
	for _, name in { "Stats", "Settings", "Catches", "Findings", "Titles", "RedeemedCodes", "Cooler", "Freezer" } do
		assert(data[name] == nil or type(data[name]) == "table", "Invalid angler " .. name)
		data[name] = data[name] or {}
	end
	for key, value in defaults do
		if data.Stats[key] == nil then
			data.Stats[key] = value
		end
		assert(number(data.Stats[key], true), "Invalid statistic " .. key)
	end
	-- Legacy catches receive their lifetime XP without crediting the current week.
	if data.Stats.TotalXP == nil then
		data.Stats.TotalXP = data.Stats.TotalCaught * Data.XP_PER_CATCH
	end
	assert(number(data.Stats.TotalXP, true), "Invalid total XP")
	if data.Weekly ~= nil then
		assert(type(data.Weekly) == "table", "Invalid weekly progress")
		assert(number(data.Weekly.Start, true), "Invalid week start")
		for _, key in { "XP", "Caught", "Earned" } do
			assert(number(data.Weekly[key], true), "Invalid weekly " .. key)
		end
	end
	for key, value in Data.DefaultSettings do
		if data.Settings[key] == nil then
			data.Settings[key] = value
		end
		assert(Data.validSetting(key, data.Settings[key]), "Invalid setting " .. key)
	end
	for id, entry in data.Catches do
		assert(type(id) == "string" and type(entry) == "table", "Invalid fish entry")
		assert(number(entry.Count, true) and number(entry.BiggestKg, false), "Invalid catch totals")
		assert(type(entry.Mutations) == "table", "Invalid mutations")
		for mutation, count in entry.Mutations do
			assert(type(mutation) == "string" and number(count, true), "Invalid mutation count")
		end
	end
	for _, record in data.Findings do
		assert(recordValid(record), "Invalid finding")
	end
	for index, record in data.Cooler do
		assert(type(index) == "number" and recordValid(record), "Invalid cooler fish")
	end
	for index, record in data.Freezer do
		assert(type(index) == "number" and recordValid(record), "Invalid freezer fish")
	end
	for _, name in { "Titles", "RedeemedCodes" } do
		for id, owned in data[name] do
			assert(type(id) == "string" and type(owned) == "boolean", "Invalid unlock")
		end
	end
	if data.EquippedTitle == nil then
		data.EquippedTitle = ""
	end
	assert(type(data.EquippedTitle) == "string", "Invalid equipped title")
	return data
end
function Data.recordCatch(raw, fishId, mutation, kg, value, caughtAt, species, mutations, size)
	assert(type(fishId) == "string" and species[fishId], "Unknown fish")
	assert(type(mutation) == "string" and mutations[mutation], "Unknown mutation")
	local fish = species[fishId]
	assert(number(fish.AverageKg, false) and fish.AverageKg > 0, "Invalid fish average weight")
	assert(number(fish.RarityDenominator, false) and fish.RarityDenominator >= 1, "Invalid fish rarity")
	local rarityMultiplier = mutations[mutation].RarityMultiplier or 1
	assert(number(rarityMultiplier, false) and rarityMultiplier >= 1, "Invalid mutation rarity")
	local record = {
		FishId = fishId,
		Mutation = mutation,
		Kg = kg,
		Value = value,
		CaughtAt = caughtAt,
		Rarity = fish.RarityDenominator * rarityMultiplier,
		Relative = kg / fish.AverageKg,
		Size = size,
	}
	assert(recordValid(record), "Invalid catch")
	local data = Data.decode(raw)
	local entry = data.Catches[fishId] or { Count = 0, BiggestKg = 0, Mutations = {} }
	data.Catches[fishId] = entry
	entry.Count += 1
	entry.BiggestKg = math.max(entry.BiggestKg, kg)
	entry.Mutations[mutation] = (entry.Mutations[mutation] or 0) + 1
	if #data.Cooler < Data.COOLER_CAPACITY then
		table.insert(data.Cooler, copy(record))
	end
	data.Stats.TotalCaught += 1
	data.Stats.TotalXP += Data.XP_PER_CATCH
	data.Stats.CatchStreak += 1
	data.Stats.HighestCatchStreak = math.max(data.Stats.HighestCatchStreak, data.Stats.CatchStreak)
	for key, field in { HighestValue = "Value", Rarest = "Rarity", Largest = "Kg", RelativeLargest = "Relative" } do
		if not data.Findings[key] or record[field] > data.Findings[key][field] then
			data.Findings[key] = copy(record)
		end
	end
	return data
end

-- Moves cooler fish into the shop freezer, oldest first, until the freezer is full.
function Data.stockFreezer(raw)
	local data = Data.decode(raw)
	local moved = 0
	while #data.Cooler > 0 and #data.Freezer < Data.FREEZER_CAPACITY do
		table.insert(data.Freezer, table.remove(data.Cooler, 1))
		moved += 1
	end
	return data, moved
end

local function sameFish(a, b)
	return a.FishId == b.FishId and a.Kg == b.Kg and a.CaughtAt == b.CaughtAt and a.Value == b.Value
end

-- A customer pays the fish's value. Returns nil when that fish is no longer frozen;
-- the caller credits Cash in the same profile transaction.
function Data.sellFrozen(raw, record)
	local data = Data.decode(raw)
	for index, frozen in data.Freezer do
		if sameFish(frozen, record) then
			table.remove(data.Freezer, index)
			local price = math.max(1, math.floor(frozen.Value))
			data.Stats.CoinsEarned += price
			return data, price
		end
	end
	return nil, 0
end

-- Run inside the same wallet UpdateAsync as the award. Retried callbacks derive
-- deltas from the saved record, never from an in-memory leaderboard snapshot.
function Data.trackProgress(previous, current, now)
	local before = Data.decode(previous)
	local data = Data.decode(current)
	local start = Data.weekStart(now)
	local weekly = if before.Weekly and before.Weekly.Start == start
		then copy(before.Weekly)
		else { Start = start, XP = 0, Caught = 0, Earned = 0 }
	for weeklyKey, stat in { XP = "TotalXP", Caught = "TotalCaught", Earned = "CoinsEarned" } do
		weekly[weeklyKey] += math.max(0, data.Stats[stat] - before.Stats[stat])
	end
	data.Weekly = weekly
	return Data.decode(data)
end

function Data.scores(raw, now)
	local data = Data.decode(raw)
	local start = Data.weekStart(now)
	local weekly = if data.Weekly and data.Weekly.Start == start then data.Weekly else {}
	return {
		Level = Data.level(data.Stats.TotalXP),
		Caught = data.Stats.TotalCaught,
		Earned = data.Stats.CoinsEarned,
		WeeklyXP = weekly.XP or 0,
		WeeklyCaught = weekly.Caught or 0,
		WeeklyEarned = weekly.Earned or 0,
	},
		start
end
return Data
