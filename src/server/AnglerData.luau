-- Pure, copy-on-write progress stored inside the existing wallet profile.
local Data = {}
-- Required on first use: several test harnesses inline this file's source, where
-- the relative path cannot resolve.
local Cargo
local function cargo()
	if not Cargo then
		Cargo = if script then require(game:GetService("ReplicatedStorage").Shared.Cargo) else require("../shared/Cargo")
	end
	return Cargo
end
local Furniture
local function furniture()
	if not Furniture then
		Furniture = if script
			then require(game:GetService("ReplicatedStorage").Shared.FurnitureCatalog)
			else require("../shared/FurnitureCatalog")
	end
	return Furniture
end
-- Base reward for unconfigured species and migration of old catch totals.
Data.XP_PER_CATCH = 100
Data.XP_LEVEL_STEP = 1000
Data.WEEK_SECONDS = 7 * 24 * 60 * 60
-- Every catch lands in the angler's hand, which holds one fish; a catch made with
-- full hands is released. From the hand a fish goes into a boat's cargo hold or
-- the shop freezer, where customers buy it. Cooler only holds fish saved before
-- the cargo hold existed.
Data.FREEZER_CAPACITY = 4
-- Bought furniture waits in FurnitureStock until build mode places it in the
-- house (Furniture). Storage racks hold overflow fish (Storage) that customers
-- never see; only freezers stock the shop.
Data.RACK_CAPACITY = 8
Data.MAX_HOLD_CELL = 32

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
local function cell(value)
	return number(value, true) and value >= 1 and value <= Data.MAX_HOLD_CELL
end
local function itemValid(item)
	return type(item) == "table"
		and cell(item.X)
		and cell(item.Y)
		and number(item.R, true)
		and item.R <= 3
		and (if item.PartId ~= nil then type(item.PartId) == "string" and item.Fish == nil else recordValid(item.Fish))
end
function Data.validSetting(key, value)
	local default = Data.DefaultSettings[key]
	return default ~= nil
		and (if type(default) == "boolean" then type(value) == "boolean" else number(value, true) and value <= 100)
end
function Data.decode(raw)
	assert(raw == nil or type(raw) == "table", "Invalid angler progress")
	local data = copy(raw or {})
	for _, name in { "Stats", "Settings", "Catches", "Findings", "Titles", "RedeemedCodes", "Cooler", "Freezer", "Holds", "Staff", "FurnitureStock", "Furniture", "Storage" } do
		assert(data[name] == nil or type(data[name]) == "table", "Invalid angler " .. name)
		data[name] = data[name] or {}
	end
	for role, hired in data.Staff do
		assert((role == "Seller" or role == "Porter") and type(hired) == "boolean", "Invalid staff member")
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
	for index, record in data.Storage do
		assert(type(index) == "number" and recordValid(record), "Invalid stored fish")
	end
	for itemId, count in data.FurnitureStock do
		assert(type(itemId) == "string" and number(count, true), "Invalid furniture stock")
	end
	-- Like holds, placement rules are checked when furniture moves, not here.
	for index, entry in data.Furniture do
		assert(
			type(index) == "number"
				and type(entry) == "table"
				and type(entry.ItemId) == "string"
				and type(entry.X) == "number"
				and type(entry.Z) == "number"
				and number(entry.R, true)
				and entry.R <= 3,
			"Invalid furniture"
		)
	end
	assert(data.Hand == nil or recordValid(data.Hand), "Invalid fish in hand")
	-- Placement is checked when items move, not here, so a later hull change can
	-- never make a saved profile unreadable.
	for boatId, items in data.Holds do
		assert(type(boatId) == "string" and type(items) == "table", "Invalid cargo hold")
		for index, item in items do
			assert(type(index) == "number" and itemValid(item), "Invalid cargo")
		end
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
	local catchXP = fish.CatchXP or Data.XP_PER_CATCH
	assert(number(catchXP, true) and catchXP > 0, "Invalid catch XP")
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
	if data.Hand == nil then
		data.Hand = copy(record)
	end
	data.Stats.TotalCaught += 1
	data.Stats.TotalXP += catchXP
	data.Stats.CatchStreak += 1
	data.Stats.HighestCatchStreak = math.max(data.Stats.HighestCatchStreak, data.Stats.CatchStreak)
	for key, field in { HighestValue = "Value", Rarest = "Rarity", Largest = "Kg", RelativeLargest = "Relative" } do
		if not data.Findings[key] or record[field] > data.Findings[key][field] then
			data.Findings[key] = copy(record)
		end
	end
	return data
end

-- A hold that has never been opened starts with the boat's own kit aboard.
function Data.hold(raw, boatId, layout)
	return copy(raw.Holds and raw.Holds[boatId] or layout.StarterParts or {})
end

-- Moves one fish or boat part. `from` is "Hand" or an index into the hold; `to` is
-- "Hand", "Release" (back into the water) or { X, Y, R } in the hold. `layout` is
-- the boat's catalog entry, or nil when no hold is in reach. Returns nil and a
-- player-facing reason when the move is not allowed.
function Data.moveCargo(raw, boatId, layout, from, to, species)
	local data = Data.decode(raw)
	local items = if layout then Data.hold(data, boatId, layout) else nil
	local item, index
	if from == "Hand" then
		if not data.Hand then
			return nil, "Your hands are empty."
		end
		item = { Fish = data.Hand }
	elseif type(from) == "number" and items and items[from] then
		item, index = items[from], from
	elseif type(from) == "number" then
		return nil, if items then "That item is no longer in the hold." else "Your boat's hold is out of reach."
	else
		return nil, "That item can't be moved."
	end
	if to == "Release" or to == "Hand" then
		if item.PartId then
			return nil, "Boat parts stay in the hold."
		elseif to == "Hand" and data.Hand then
			return nil, "Your hands are already full."
		end
		if index then
			table.remove(items, index)
		end
		data.Hand = if to == "Hand" then item.Fish else nil
	elseif type(to) == "table" then
		if not items then
			return nil, "Your boat's hold is out of reach."
		end
		local x, y, r = to.X, to.Y, to.R
		if not (cell(x) and cell(y) and number(r, true) and r <= 3) then
			return nil, "That isn't a spot in the hold."
		end
		local grid = cargo()
		local taken = grid.occupied(items, species, index)
		if not grid.fits(layout.Hold, taken, grid.shape(item, species), x, y, r) then
			return nil, "It doesn't fit there."
		end
		local placed = { Fish = item.Fish, PartId = item.PartId, X = x, Y = y, R = r }
		if index then
			items[index] = placed
		else
			table.insert(items, placed)
			data.Hand = nil
		end
	else
		return nil, "That item can't go there."
	end
	if items then
		data.Holds[boatId] = items
	end
	return Data.decode(data)
end

-- Counted here rather than through the catalog, so inlined test harnesses that
-- never place furniture don't need to resolve it.
local function placed(raw, itemId)
	local count = 0
	for _, entry in raw.Furniture or {} do
		if entry.ItemId == itemId then
			count += 1
		end
	end
	return count
end

-- The built-in freezer plus every placed one.
function Data.freezerCapacity(raw)
	return Data.FREEZER_CAPACITY * (1 + placed(raw, "Freezer"))
end

function Data.storageCapacity(raw)
	return Data.RACK_CAPACITY * placed(raw, "StorageRack")
end


-- Fish still waiting to be stocked: in hand, on storage racks, in the old cooler and in every hold.
function Data.unstocked(raw)
	local count = (if raw.Hand then 1 else 0) + #raw.Cooler + #(raw.Storage or {})
	for _, items in raw.Holds do
		for _, item in items do
			if item.Fish then
				count += 1
			end
		end
	end
	return count
end

-- Places only the carried fish. Cargo stays aboard until individually picked up.
function Data.stockFreezer(raw)
	local data = Data.decode(raw)
	local moved = 0
	if data.Hand and #data.Freezer < Data.freezerCapacity(data) then
		table.insert(data.Freezer, data.Hand)
		data.Hand = nil
		moved += 1
	end
	return data, moved
end

local function sameFish(a, b)
	return a.FishId == b.FishId and a.Kg == b.Kg and a.CaughtAt == b.CaughtAt and a.Value == b.Value
		and a.Mutation == b.Mutation and a.Size == b.Size
end

-- A porter carries a display copy. Only delivery changes the saved inventory,
-- so a disconnect, full freezer or a player moving that fish cannot lose it.
-- With `toStorage` the fish goes onto a storage rack instead of the freezer.
function Data.unloadFish(raw, boatId, index, record, toStorage)
	local data = Data.decode(raw)
	local items = data.Holds[boatId]
	local item = items and items[index]
	local shelf = if toStorage then data.Storage else data.Freezer
	local capacity = if toStorage then Data.storageCapacity(data) else Data.freezerCapacity(data)
	if #shelf >= capacity or not item or not item.Fish or not sameFish(item.Fish, record) then
		return nil
	end
	table.insert(shelf, item.Fish)
	table.remove(items, index)
	return data
end

-- The carried fish goes onto a storage rack.
function Data.storeFish(raw)
	local data = Data.decode(raw)
	if not data.Hand then
		return nil, "Equip a fish from your hotbar first."
	elseif #data.Storage >= Data.storageCapacity(data) then
		return nil,
			if Data.storageCapacity(data) == 0
				then "Place a storage rack in your storage room first."
				else "Your storage racks are full."
	end
	table.insert(data.Storage, data.Hand)
	data.Hand = nil
	return data
end

-- The oldest stored fish goes back into the angler's hand.
function Data.takeStored(raw)
	local data = Data.decode(raw)
	if data.Hand then
		return nil, "Your hands are already full."
	elseif #data.Storage == 0 then
		return nil, "Your storage racks are empty."
	end
	data.Hand = table.remove(data.Storage, 1)
	return data
end

-- A porter moves one stored fish into a freezer with room.
function Data.restockFish(raw, record)
	local data = Data.decode(raw)
	if #data.Freezer >= Data.freezerCapacity(data) then
		return nil
	end
	for index, stored in data.Storage do
		if sameFish(stored, record) then
			table.insert(data.Freezer, table.remove(data.Storage, index))
			return data
		end
	end
	return nil
end

-- The caller charges the price in the same profile transaction.
function Data.buyFurniture(raw, itemId)
	local data = Data.decode(raw)
	if not furniture().Items[itemId] then
		return nil, "That isn't for sale."
	end
	data.FurnitureStock[itemId] = (data.FurnitureStock[itemId] or 0) + 1
	return data
end

-- Places a bought item (`from` is an item id) or moves a placed one (`from` is
-- its index in Furniture).
function Data.placeFurniture(raw, from, x, z, r)
	local data = Data.decode(raw)
	local catalog = furniture()
	local itemId, skip
	if type(from) == "number" then
		local entry = data.Furniture[from]
		if not entry then
			return nil, "That furniture is no longer placed."
		end
		itemId, skip = entry.ItemId, from
	elseif type(from) == "string" and catalog.Items[from] then
		itemId = from
		if (data.FurnitureStock[itemId] or 0) < 1 then
			return nil, "Buy one at the furniture shop first."
		elseif catalog.count(data.Furniture, itemId) >= catalog.Items[itemId].MaxPlaced then
			return nil, string.format("You can place up to %d of those.", catalog.Items[itemId].MaxPlaced)
		end
	else
		return nil, "That isn't furniture."
	end
	local reason = catalog.check(data.Furniture, itemId, x, z, r, skip)
	if reason then
		return nil, reason
	end
	local placed = { ItemId = itemId, X = x, Z = z, R = r }
	if skip then
		data.Furniture[skip] = placed
	else
		data.FurnitureStock[itemId] -= 1
		if data.FurnitureStock[itemId] == 0 then
			data.FurnitureStock[itemId] = nil
		end
		table.insert(data.Furniture, placed)
	end
	return data
end

-- Puts a placed item back in stock, unless the fish it holds would have nowhere to go.
function Data.pickUpFurniture(raw, index)
	local data = Data.decode(raw)
	local entry = type(index) == "number" and data.Furniture[index]
	if not entry then
		return nil, "That furniture is no longer placed."
	end
	table.remove(data.Furniture, index)
	if #data.Freezer > Data.freezerCapacity(data) then
		return nil, "Sell some fish first. They wouldn't fit in your other freezers."
	elseif #data.Storage > Data.storageCapacity(data) then
		return nil, "Take some fish off your racks first."
	end
	data.FurnitureStock[entry.ItemId] = (data.FurnitureStock[entry.ItemId] or 0) + 1
	return data
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
