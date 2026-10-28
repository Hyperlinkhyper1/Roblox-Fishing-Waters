-- Pure, copy-on-write progress stored inside the existing wallet profile.
local Data = {}
-- Required on first use: several test harnesses inline this file's source, where
-- the relative path cannot resolve.
local Cargo
local function cargo()
	if not Cargo then
		Cargo = if script
			then require(game:GetService("ReplicatedStorage").Shared.Cargo)
			else require("../shared/Cargo")
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
local Recipes
local function recipes()
	if not Recipes then
		Recipes = if script
			then require(game:GetService("ReplicatedStorage").Shared.Recipes)
			else require("../shared/Recipes")
	end
	return Recipes
end
local Paths
local function paths()
	if not Paths then
		Paths = if script
			then require(game:GetService("ReplicatedStorage").Shared.Paths)
			else require("../shared/Paths")
	end
	return Paths
end
-- Base reward for unconfigured species and migration of old catch totals.
Data.XP_PER_CATCH = 100
Data.XP_LEVEL_STEP = 1000
Data.WEEK_SECONDS = 7 * 24 * 60 * 60
-- Catches land in the angler's hand, which holds one fish; with full hands,
-- gameplay packs the next catch into the backpack when it fits. From the hand,
-- fish go into a boat's cargo hold or the shop freezer. Cooler holds fish saved before
-- the cargo hold existed.
local FreezerPacking, FreezerModels
local function freezerModules()
	if not FreezerPacking then
		local shared = game:GetService("ReplicatedStorage").Shared
		FreezerPacking = require(shared.FreezerPacking)
		FreezerModels = require(shared.FishModels)
	end
	return FreezerPacking, FreezerModels
end
-- Bought furniture waits in FurnitureStock until build mode places it in the
-- house (Furniture). Storage racks hold overflow fish (Storage) that customers
-- never see; only freezers stock the shop.
Data.RACK_CAPACITY = 12
-- Cooked dishes (Supermarket path) wait on the kitchen pass, which holds this many;
-- every placed food display case shows as many again to shop customers.
Data.PANTRY_CAPACITY = 6
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
	MusselNetsOpened = 0,
	-- Business paths (Shared.Paths) count these per stage.
	FishSold = 0,
	FoodCooked = 0,
	FoodSold = 0,
	DinersServed = 0,
	FishermanCatches = 0,
}
local STAFF_ROLES = { Seller = true, Porter = true, Fisherman = true }

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
local function corruptionsValid(list)
	if type(list) ~= "table" or #list == 0 or #list > 8 then
		return false
	end
	for index, name in list do
		if type(index) ~= "number" or type(name) ~= "string" then
			return false
		end
	end
	return true
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
		and (record.NeonColor == nil or type(record.NeonColor) == "string")
		and (record.Corruptions == nil or corruptionsValid(record.Corruptions))
end
-- A cooked dish keeps its source fish's identity so it can be shown and told apart.
local function dishValid(dish)
	return type(dish) == "table"
		and type(dish.RecipeId) == "string"
		and type(dish.FishId) == "string"
		and type(dish.Mutation) == "string"
		and number(dish.Kg, false)
		and number(dish.Value, false)
		and number(dish.MadeAt, true)
		and (dish.NeonColor == nil or type(dish.NeonColor) == "string")
end
local function flags(map)
	if type(map) ~= "table" then
		return false
	end
	for key, value in map do
		if type(key) ~= "string" or type(value) ~= "boolean" then
			return false
		end
	end
	return true
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
		and (item.Locked == nil or type(item.Locked) == "boolean")
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
	assert(data.ShopSign == nil or (type(data.ShopSign) == "string" and #data.ShopSign <= 96), "Invalid shop sign")
	data.ShopSign = data.ShopSign or ""
	for _, name in
		{
			"Stats",
			"Settings",
			"Catches",
			"Findings",
			"Titles",
			"RedeemedCodes",
			"Cooler",
			"Freezer",
			"Holds",
			"Backpack",
			"Staff",
			"FurnitureStock",
			"Furniture",
			"Storage",
			"Pantry",
			"Kitchen",
			"KitchenStorage",
			"Upgrades",
			"BoatPaint",
			"BoatUpgrades",
		}
	do
		assert(data[name] == nil or type(data[name]) == "table", "Invalid angler " .. name)
		data[name] = data[name] or {}
	end
	for role, hired in data.Staff do
		assert(STAFF_ROLES[role] and type(hired) == "boolean", "Invalid staff member")
	end
	assert(data.FishermanBoat == nil or type(data.FishermanBoat) == "string", "Invalid fisherman boat")
	for index, dish in data.Pantry do
		assert(type(index) == "number" and dishValid(dish), "Invalid dish")
	end
	for key, job in data.Kitchen do
		assert(
			type(key) == "string" and type(job) == "table" and dishValid(job.Dish) and number(job.ReadyAt, true),
			"Invalid kitchen job"
		)
	end
	data.KitchenStorage = data.KitchenStorage or { Targets = {}, Fish = {} }
	assert(type(data.KitchenStorage) == "table", "Invalid kitchen storage")
	data.KitchenStorage.Targets = data.KitchenStorage.Targets or {}
	data.KitchenStorage.Fish = data.KitchenStorage.Fish or {}
	assert(type(data.KitchenStorage.Targets) == "table" and type(data.KitchenStorage.Fish) == "table", "Invalid kitchen storage")
	for rarity, count in data.KitchenStorage.Targets do
		assert(type(rarity) == "string" and number(count, true) and count >= 0, "Invalid kitchen storage target")
	end
	for index, record in data.KitchenStorage.Fish do
		assert(type(index) == "number" and recordValid(record), "Invalid kitchen storage fish")
	end
	for id, level in data.Upgrades do
		assert(type(id) == "string" and number(level, true), "Invalid upgrade")
	end
	-- Refit dock paint per boat id (Shared.BoatUpgrades.Paints); unknown ids paint nothing.
	for boatId, paint in data.BoatPaint do
		assert(type(boatId) == "string" and type(paint) == "string", "Invalid boat paint")
	end
	-- Permanent hull fittings per boat id (for example the trawler's stern net).
	for boatId, upgrades in data.BoatUpgrades do
		assert(type(boatId) == "string" and type(upgrades) == "table", "Invalid boat upgrades")
		for id, owned in upgrades do
			assert(type(id) == "string" and type(owned) == "boolean", "Invalid boat upgrade")
		end
	end
	-- Profiles from before paths start as a fish shop; their lifetime stats count
	-- towards it, since its baseline is empty.
	if data.Paths == nil then
		data.Paths = { Active = "Fishshop", Unlocked = { Fishshop = true }, Completed = {}, Baseline = {} }
	end
	local path = data.Paths
	assert(
		type(path) == "table"
			and type(path.Active) == "string"
			and flags(path.Unlocked)
			and flags(path.Completed)
			and type(path.Baseline) == "table"
			and path.Unlocked[path.Active] == true,
		"Invalid path progress"
	)
	path.SkipCredits = if path.SkipCredits == nil then 0 else path.SkipCredits
	path.SkipReceipts = if path.SkipReceipts == nil then {} else path.SkipReceipts
	assert(number(path.SkipCredits, true) and flags(path.SkipReceipts), "Invalid path skips")
	assert(path.SkipTarget == nil or type(path.SkipTarget) == "string", "Invalid path skip target")
	for stat, value in path.Baseline do
		assert(type(stat) == "string" and number(value, true), "Invalid path baseline")
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
	-- Crab cages wait in Stock until dropped by the dock; Placed spots are dock-local
	-- studs (Shared.CrabCages holds the rules, which are checked when cages move).
	if data.CrabCages == nil then
		data.CrabCages = { Stock = 0, Placed = {} }
	end
	local cages = data.CrabCages
	assert(type(cages) == "table" and number(cages.Stock, true) and type(cages.Placed) == "table", "Invalid crab cages")
	for index, cage in cages.Placed do
		assert(
			type(index) == "number"
				and type(cage) == "table"
				and type(cage.X) == "number"
				and cage.X == cage.X
				and type(cage.Z) == "number"
				and cage.Z == cage.Z
				and number(cage.Uses, true)
				and cage.Uses >= 1
				and number(cage.ReadyAt, true),
			"Invalid crab cage"
		)
	end
	if data.MusselNets == nil then
		data.MusselNets = { Stock = 0, Placed = {} }
	end
	local nets = data.MusselNets
	assert(type(nets) == "table" and number(nets.Stock, true) and type(nets.Placed) == "table", "Invalid mussel nets")
	for index, net in nets.Placed do
		assert(type(index) == "number" and type(net) == "table" and type(net.X) == "number" and net.X == net.X
			and type(net.Z) == "number" and net.Z == net.Z and number(net.Uses, true) and net.Uses >= 1
			and number(net.ReadyAt, true), "Invalid mussel net")
	end
	data.BackpackId = data.BackpackId or "Starter"
	assert(type(data.BackpackId) == "string", "Invalid backpack")
	for index, item in data.Backpack do
		assert(type(index) == "number" and itemValid(item) and item.PartId == nil, "Invalid backpack fish")
	end
	-- Preserve the old 12-cell starter grid when it already contains saved fish.
	if data.BackpackVersion == nil and data.BackpackId == "Starter" and #data.Backpack > 0 then
		data.BackpackId = "Cooler"
	end
	data.BackpackVersion = 2
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
	if data.Holds.PatrolBoat and data.PatrolHoldVersion ~= 3 then
		local boatCatalog = if script
			then require(game:GetService("ReplicatedStorage").Shared.BoatCatalog)
			else require("../shared/BoatCatalog")
		local fishCatalog = if script
			then require(game:GetService("ReplicatedStorage").Shared.AnglerCatalog)
			else require("../shared/AnglerCatalog")
		Data.migratePatrolHold(data, boatCatalog.PatrolBoat, fishCatalog.Fish)
	elseif not data.Holds.PatrolBoat then
		data.PatrolHoldVersion = 3
	end
	return data
end
-- `traits` carries the mutation's NeonColor and Corruptions, when it has them.
local function catchRecord(fishId, mutation, kg, value, caughtAt, species, mutations, size, traits)
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
		NeonColor = traits and traits.NeonColor,
		Corruptions = traits and copy(traits.Corruptions),
	}
	assert(recordValid(record), "Invalid catch")
	return record
end

-- A cast is possible while the hand is empty or the backpack has an open tile.
function Data.hasCatchSpace(raw, backpackLayout, species)
	if not raw.Hand then
		return true
	end
	local grid = cargo()
	local taken = grid.occupied(raw.Backpack, species)
	for y, row in backpackLayout.Hold do
		for x = 1, #row do
			if grid.open(backpackLayout.Hold, x, y) and not grid.at(taken, x, y) then
				return true
			end
		end
	end
	return false
end

-- Shared bestiary, streak, XP and findings bookkeeping for every landed fish.
-- `record` is always a fresh record owned by this transaction.
local function registerCatch(data, record, species)
	local entry = data.Catches[record.FishId] or { Count = 0, BiggestKg = 0, Mutations = {} }
	data.Catches[record.FishId] = entry
	entry.Count += 1
	entry.BiggestKg = math.max(entry.BiggestKg, record.Kg)
	entry.Mutations[record.Mutation] = (entry.Mutations[record.Mutation] or 0) + 1
	local catchXP = species[record.FishId].CatchXP or Data.XP_PER_CATCH
	assert(number(catchXP, true) and catchXP > 0, "Invalid catch XP")
	data.Stats.TotalCaught += 1
	data.Stats.TotalXP += catchXP
	data.Stats.CatchStreak += 1
	data.Stats.HighestCatchStreak = math.max(data.Stats.HighestCatchStreak, data.Stats.CatchStreak)
	for key, field in { HighestValue = "Value", Rarest = "Rarity", Largest = "Kg", RelativeLargest = "Relative" } do
		if not data.Findings[key] or record[field] > data.Findings[key][field] then
			data.Findings[key] = copy(record)
		end
	end
end

-- Gameplay supplies the owned backpack layout. Returns the catch's destination
-- so identical fish already in hand cannot be mistaken for the new catch.
function Data.recordCatch(raw, fishId, mutation, kg, value, caughtAt, species, mutations, size, traits, backpackLayout)
	assert(type(fishId) == "string" and species[fishId], "Unknown fish")
	local record = catchRecord(fishId, mutation, kg, value, caughtAt, species, mutations, size, traits)
	local data = Data.decode(raw)
	registerCatch(data, record, species)
	local destination = "Released"
	if data.Hand == nil then
		data.Hand = copy(record)
		destination = "Hand"
	elseif backpackLayout then
		local spot = cargo().bestSpot(backpackLayout.Hold, data.Backpack, { Fish = record }, species)
		if spot then
			table.insert(data.Backpack, { Fish = copy(record), X = spot.X, Y = spot.Y, R = spot.R })
			destination = "Backpack"
		end
	end
	return data, destination
end

-- Repack an old wide patrol hold once. Install the larger engine first, then
-- pack large fish before small ones. Overflow stays recoverable on storage racks.
function Data.migratePatrolHold(data, layout, species)
	local grid = cargo()
	local items = copy(layout.StarterParts)
	local fish = {}
	-- Preserve paid upgrades from the previous hold before packing fish.
	if data.PatrolHoldVersion == 2 then
		local starters = {}
		for _, part in layout.StarterParts do
			starters[part.PartId] = (starters[part.PartId] or 0) + 1
		end
		for _, item in data.Holds.PatrolBoat do
			if item.PartId then
				if (starters[item.PartId] or 0) > 0 then
					starters[item.PartId] -= 1
				else
					local spot = grid.bestSpot(layout.Hold, items, item, species)
					assert(spot, "Patrol upgrade does not fit in migrated hold")
					table.insert(items, { PartId = item.PartId, X = spot.X, Y = spot.Y, R = spot.R })
				end
			end
		end
	end
	for index, item in data.Holds.PatrolBoat do
		if item.Fish then
			table.insert(fish, { Item = item, Index = index, Area = #grid.cells(grid.shape(item, species)) })
		end
	end
	table.sort(fish, function(a, b)
		return if a.Area == b.Area then a.Index < b.Index else a.Area > b.Area
	end)
	for _, entry in fish do
		local item = entry.Item
		local spot = grid.bestSpot(layout.Hold, items, item, species)
		if spot then
			table.insert(items, { Fish = item.Fish, X = spot.X, Y = spot.Y, R = spot.R })
		else
			table.insert(data.Storage, item.Fish)
		end
	end
	data.Holds.PatrolBoat = items
	data.PatrolHoldVersion = layout.HoldVersion
end

-- A hold that has never been opened starts with the boat's own kit aboard.
function Data.hold(raw, boatId, layout)
	return copy(raw.Holds and raw.Holds[boatId] or layout.StarterParts or {})
end

-- Moves one fish or boat part. `from` is "Hand" or an index into the hold; `to` is
-- "Hand", "Release" (back into the water) or { X, Y, R } in the hold. `layout` is
-- the boat's catalog entry, or nil when no hold is in reach. Returns nil and a
-- player-facing reason when the move is not allowed. With backpack=true, the
-- same placement rules operate on Backpack using its catalog layout.
function Data.moveCargo(raw, boatId, layout, from, to, species, backpack)
	local data = Data.decode(raw)
	local items = if backpack then data.Backpack elseif layout then Data.hold(data, boatId, layout) else nil
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
		if to == "Hand" then
			data.Hand = item.Fish
		elseif from == "Hand" then
			data.Hand = nil
		end
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
		local placed = { Fish = item.Fish, PartId = item.PartId, Locked = item.Locked, X = x, Y = y, R = r }
		if index then
			items[index] = placed
		else
			table.insert(items, placed)
			data.Hand = nil
		end
	else
		return nil, "That item can't go there."
	end
	if backpack then
		data.Backpack = items
	elseif items then
		data.Holds[boatId] = items
	end
	return Data.decode(data)
end

-- Places a newly fitted boat part at the exact hold spot the player picked.
-- The caller has already checked the upgrade limit; this only enforces the grid.
function Data.placePart(raw, boatId, layout, partId, x, y, r, species)
	local data = Data.decode(raw)
	local grid = cargo()
	local part = grid.Parts[partId]
	local items = Data.hold(data, boatId, layout)
	if not part then
		return nil, "That boat part is not available."
	elseif not (cell(x) and cell(y) and number(r, true) and r <= 3) then
		return nil, "That isn't a spot in the hold."
	end
	local taken = grid.occupied(items, species)
	if not grid.fits(layout.Hold, taken, part.Shape, x, y, r) then
		return nil, "It doesn't fit there."
	end
	table.insert(items, { PartId = partId, X = x, Y = y, R = r })
	data.Holds[boatId] = items
	return Data.decode(data)
end

-- Packs every fish from the boat hold that fits into the backpack, largest first,
-- and leaves boat parts and any fish that no longer fit behind. Returns nil and a
-- player-facing reason when nothing could be moved.
function Data.moveAllToBackpack(raw, boatId, layout, backpackLayout, species)
	local data = Data.decode(raw)
	local items = Data.hold(data, boatId, layout)
	local backpack = data.Backpack or {}
	local grid = cargo()
	local fish = {}
	for index, item in items do
		if item.Fish then
			table.insert(fish, { Item = item, Index = index, Area = #grid.cells(grid.shape(item, species)) })
		end
	end
	if #fish == 0 then
		return nil, "Your boat's hold has no fish to move."
	end
	table.sort(fish, function(a, b)
		return if a.Area == b.Area then a.Index < b.Index else a.Area > b.Area
	end)
	local taken = {}
	for _, entry in fish do
		local spot = grid.bestSpot(backpackLayout.Hold, backpack, { Fish = entry.Item.Fish }, species)
		if spot then
			table.insert(backpack, {
				Fish = entry.Item.Fish,
				Locked = entry.Item.Locked,
				X = spot.X,
				Y = spot.Y,
				R = spot.R,
			})
			taken[entry.Item] = true
		end
	end
	local moved = 0
	local remaining = {}
	for _, item in items do
		if taken[item] then
			moved += 1
		else
			table.insert(remaining, item)
		end
	end
	if moved == 0 then
		return nil, "No room in your backpack for those fish."
	end
	data.Backpack = backpack
	data.Holds[boatId] = remaining
	return Data.decode(data), moved
end

-- Locking is specific to the fish's current backpack entry.
function Data.setBackpackLock(raw, index, locked, expected)
	local data = Data.decode(raw)
	local item = data.Backpack[index]
	if
		not item
		or type(locked) ~= "boolean"
		or type(expected) ~= "table"
		or item.X ~= expected.X
		or item.Y ~= expected.Y
		or item.Fish.FishId ~= expected.FishId
		or item.Fish.Kg ~= expected.Kg
		or item.Fish.CaughtAt ~= expected.CaughtAt
	then
		return nil, "That fish is no longer in that backpack spot."
	end
	item.Locked = if locked then true else nil
	return data
end

-- Called within the catch's save, so the fish never needs a second transaction.
function Data.autoStore(raw, boatId, layout, species)
	if not raw.Hand or not layout then
		return raw, false
	end
	local items = Data.hold(raw, boatId, layout)
	local placement = cargo().bestSpot(layout.Hold, items, { Fish = raw.Hand }, species)
	if not placement then
		return raw, false
	end
	local moved = Data.moveCargo(raw, boatId, layout, "Hand", placement, species)
	return moved or raw, moved ~= nil
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

-- The built-in cooler and every placed cooler share one packing rule.
function Data.freezerCount(raw)
	return 1 + placed(raw, "Freezer")
end

local freezerLayouts = setmetatable({}, { __mode = "k" })
function Data.freezerLayout(raw, extra)
	local packing, models = freezerModules()
	local count = Data.freezerCount(raw)
	local frozen = raw.Freezer or {}
	local cached = freezerLayouts[frozen]
	if not extra and cached and cached.Count == count and cached.Length == #frozen then
		return cached.Layout, cached.Fits, cached.Used
	end
	local records = table.clone(frozen)
	if extra then
		table.insert(records, extra)
	end
	local layout, fits, used = packing.layout(records, count, models.catchBounds)
	if not extra then
		freezerLayouts[frozen] = { Count = count, Length = #frozen, Layout = layout, Fits = fits, Used = used }
	end
	return layout, fits, used
end

function Data.canFreeze(raw, record)
	local _, fits = Data.freezerLayout(raw, record)
	return fits
end

function Data.freezerUsage(raw)
	local _, fits, used = Data.freezerLayout(raw)
	return if fits then math.clamp(math.floor(used * 100 + 0.5), 0, 100) else 100
end

function Data.storageCapacity(raw)
	return Data.RACK_CAPACITY * placed(raw, "StorageRack")
end

-- Fish still waiting to be stocked: hand, backpack, racks, old cooler and holds.
function Data.unstocked(raw)
	local count = (if raw.Hand then 1 else 0) + #raw.Cooler + #(raw.Storage or {}) + #(raw.Backpack or {})
	for _, items in raw.Holds do
		for _, item in items do
			if item.Fish then
				count += 1
			end
		end
	end
	return count
end

-- Stock the equipped hand fish and every unlocked backpack fish that fits.
function Data.stockFreezer(raw, includeHand)
	local data = Data.decode(raw)
	local moved = 0
	if includeHand ~= false and data.Hand and Data.canFreeze(data, data.Hand) then
		table.insert(data.Freezer, data.Hand)
		data.Hand = nil
		moved += 1
	end
	local index = 1
	while index <= #data.Backpack do
		local item = data.Backpack[index]
		if not item.Locked and Data.canFreeze(data, item.Fish) then
			table.insert(data.Freezer, item.Fish)
			table.remove(data.Backpack, index)
			moved += 1
		else
			index += 1
		end
	end
	return data, moved
end

local function sameFish(a, b)
	return a.FishId == b.FishId
		and a.Kg == b.Kg
		and a.CaughtAt == b.CaughtAt
		and a.Value == b.Value
		and a.Mutation == b.Mutation
		and a.Size == b.Size
end

-- A porter carries a display copy. Only delivery changes the saved inventory,
-- so a disconnect, full freezer or a player moving that fish cannot lose it.
-- With `toStorage` the fish goes onto a storage rack instead of the freezer.
function Data.unloadFish(raw, boatId, index, record, toStorage)
	local data = Data.decode(raw)
	local items = data.Holds[boatId]
	local item = items and items[index]
	local shelf = if toStorage then data.Storage else data.Freezer
	if not item or not item.Fish or not sameFish(item.Fish, record) then
		return nil
	end
	if
		(toStorage and #shelf >= Data.storageCapacity(data)) or (not toStorage and not Data.canFreeze(data, item.Fish))
	then
		return nil
	end
	table.insert(shelf, item.Fish)
	table.remove(items, index)
	return data
end

function Data.unloadFishToKitchenStorage(raw, boatId, index, record, catalogFish)
	local data = Data.decode(raw)
	local items = data.Holds[boatId]
	local item = items and items[index]
	if not item or not item.Fish or not sameFish(item.Fish, record) then
		return nil
	end
	if not Data.canKitchenStorageAccept(data, item.Fish, catalogFish) then
		return nil
	end
	table.insert(data.KitchenStorage.Fish, item.Fish)
	table.remove(items, index)
	return data
end

function Data.restockFishToKitchenStorage(raw, record, catalogFish)
	local data = Data.decode(raw)
	for index, stored in data.Storage do
		if sameFish(stored, record) then
			if not Data.canKitchenStorageAccept(data, stored, catalogFish) then
				return nil
			end
			table.remove(data.Storage, index)
			table.insert(data.KitchenStorage.Fish, stored)
			return data
		end
	end
	return nil
end

-- The carried fish and every unlocked backpack fish go onto the storage racks
-- until they are full, like stocking a freezer.
function Data.storeFish(raw, includeHand)
	local data = Data.decode(raw)
	local capacity = Data.storageCapacity(data)
	local moved = 0
	if includeHand ~= false and data.Hand then
		if capacity == 0 then
			return nil, "Place a storage rack in your storage room first."
		elseif #data.Storage >= capacity then
			return nil, "Your storage racks are full."
		end
		table.insert(data.Storage, data.Hand)
		data.Hand = nil
		moved += 1
	end
	local index = 1
	while index <= #data.Backpack and #data.Storage < capacity do
		local item = data.Backpack[index]
		if not item.Locked then
			table.insert(data.Storage, item.Fish)
			table.remove(data.Backpack, index)
			moved += 1
		else
			index += 1
		end
	end
	if moved == 0 then
		if capacity == 0 then
			return nil, "Place a storage rack in your storage room first."
		elseif #data.Storage >= capacity then
			return nil, "Your storage racks are full."
		end
		for _, item in data.Backpack do
			if item.Locked then
				return nil, "Your backpack fish are locked. Right-click a fish to unlock it."
			end
		end
		return nil, "Equip a fish from your hotbar first."
	end
	return data, moved
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
	if not Data.canFreeze(data, record) then
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
	local locked = catalog.locked(itemId, data.Paths.Unlocked)
	if locked then
		return nil, locked
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
	if entry.ItemId == "Freezer" and not Data.canFreeze(data) then
		return nil, "Sell some fish first. They wouldn't fit in your other freezers."
	elseif #data.Storage > Data.storageCapacity(data) then
		return nil, "Take some fish off your racks first."
	elseif #data.Pantry > Data.pantryCapacity(data) then
		return nil, "Sell some dishes first. They wouldn't fit in your other display cases."
	elseif entry.ItemId == "KitchenStorage" and #data.KitchenStorage.Fish > 0 then
		return nil, "Take the fish off your kitchen storage table first."
	elseif data.Kitchen[entry.ItemId] then
		return nil, "Collect the dish on this station first."
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
			data.Stats.FishSold += 1
			return data, price
		end
	end
	return nil, 0
end

-- The kitchen pass plus every placed food display case.
function Data.pantryCapacity(raw)
	return Data.PANTRY_CAPACITY * (1 + placed(raw, "FoodCase"))
end

-- Takes one particular frozen fish (one no customer is holding) into the empty hand.
function Data.takeFrozen(raw, record)
	local data = Data.decode(raw)
	if data.Hand then
		return nil, "Your hands are already full."
	end
	for index, frozen in data.Freezer do
		if sameFish(frozen, record) then
			data.Hand = table.remove(data.Freezer, index)
			return data
		end
	end
	return nil, "That fish is no longer in your freezer."
end

function Data.sameDish(a, b)
	return a.RecipeId == b.RecipeId
		and a.FishId == b.FishId
		and a.Kg == b.Kg
		and a.Value == b.Value
		and a.MadeAt == b.MadeAt
end

-- Starts cooking the carried fish at a kitchen station. `key` is a built-in bench key
-- or a station's furniture id; `species` is AnglerCatalog.Fish (for the fish's rarity).
-- The fish leaves the hand now and the dish is saved on the station, so it is never lost.
function Data.startCooking(raw, key, recipeId, species, now)
	local data = Data.decode(raw)
	local book = recipes()
	local station = type(key) == "string" and book.stationOf(key)
	if not paths().unlocked(data, "Supermarket") then
		return nil, "Cooking unlocks with the Supermarket path."
	elseif not station then
		return nil, "That isn't a kitchen station."
	elseif not book.BuiltIn[key] and placed(data, key) == 0 then
		return nil, "Place that station in your processing room first."
	elseif data.Kitchen[key] then
		return nil, "This station is already in use."
	elseif not data.Hand then
		return nil, "Carry a fish to the station first."
	end
	local fish = data.Hand
	local problem = book.problem(recipeId, station, species[fish.FishId] and species[fish.FishId].Rarity)
	if problem then
		return nil, problem
	end
	data.Kitchen[key] = {
		Dish = {
			RecipeId = recipeId,
			FishId = fish.FishId,
			Mutation = fish.Mutation,
			Kg = fish.Kg,
			Value = book.value(recipeId, fish.Value),
			MadeAt = now,
			NeonColor = fish.NeonColor,
		},
		ReadyAt = now + book.Items[recipeId].Seconds,
	}
	data.Hand = nil
	return data
end

-- A finished dish goes from its station onto the kitchen pass.
function Data.collectDish(raw, key, now)
	local data = Data.decode(raw)
	local job = type(key) == "string" and data.Kitchen[key]
	if not job then
		return nil, "Nothing is cooking here."
	elseif now < job.ReadyAt then
		return nil, "It's still cooking."
	elseif #data.Pantry >= Data.pantryCapacity(data) then
		return nil, "Your kitchen pass is full. Sell some dishes or place another food display case."
	end
	table.insert(data.Pantry, job.Dish)
	data.Kitchen[key] = nil
	data.Stats.FoodCooked += 1
	return data
end

-- A customer or diner pays for one dish. `multiplier` is 1 in the shop and the
-- restaurant markup for diners; `stat` is the counter the sale adds to.
function Data.sellDish(raw, dish, multiplier, stat)
	local data = Data.decode(raw)
	for index, stocked in data.Pantry do
		if Data.sameDish(stocked, dish) then
			table.remove(data.Pantry, index)
			local price = math.max(1, math.floor(stocked.Value * multiplier))
			data.Stats.CoinsEarned += price
			data.Stats[stat] += 1
			return data, price
		end
	end
	return nil, 0
end

-- Unlocks the next path. The caller checks Shared.Paths.chooseProblem and charges
-- the price in the same profile transaction. The finished stage stays completed and
-- the new one counts its stat goals from here.
function Data.choosePath(raw, stageId, stage)
	local data = Data.decode(raw)
	local path = data.Paths
	path.Completed[path.Active] = true
	path.Unlocked[stageId] = true
	path.Active = stageId
	path.Baseline = copy(data.Stats)
	for itemId, count in stage.Grants or {} do
		data.FurnitureStock[itemId] = (data.FurnitureStock[itemId] or 0) + count
	end
	return Data.decode(data)
end

-- Receipt and credit commit together in the wallet transaction, once per purchase.
function Data.grantPathSkip(raw, purchaseId)
	assert(type(purchaseId) == "string" and #purchaseId > 0, "Invalid path skip receipt")
	local data = Data.decode(raw)
	if not data.Paths.SkipReceipts[purchaseId] then
		data.Paths.SkipReceipts[purchaseId] = true
		data.Paths.SkipCredits += 1
	end
	return Data.decode(data)
end

-- The caller validates Paths.skipProblem against the whole current wallet first.
function Data.usePathSkip(raw, stageId)
	local data = Data.decode(raw)
	local path = data.Paths
	assert(path.Active == stageId and not path.Completed[stageId], "Path already finished or changed")
	assert(path.SkipCredits > 0, "No purchased quest skip available")
	path.SkipCredits -= 1
	path.Completed[stageId] = true
	path.SkipTarget = nil
	return Data.decode(data)
end

-- Stows one fish the hired fisherman landed into his boat's hold. Returns nil when
-- the hold has no room left for it.
function Data.fishermanCatch(raw, boatId, layout, roll, caughtAt, species, mutations)
	local data = Data.decode(raw)
	local traits = roll.Traits or {}
	local mutation = traits.Mutation or "Normal"
	local record =
		catchRecord(roll.FishId, mutation, roll.Kg, roll.Value, caughtAt, species, mutations, roll.Size, traits)
	local items = Data.hold(data, boatId, layout)
	local placement = cargo().bestSpot(layout.Hold, items, { Fish = record }, species)
	if not placement then
		return nil
	end
	table.insert(items, { Fish = record, X = placement.X, Y = placement.Y, R = placement.R })
	data.Holds[boatId] = items
	data.Stats.FishermanCatches += 1
	return Data.decode(data)
end

-- The trawler's stern net lands fish straight into the hold, but they still
-- count in the bestiary, XP and findings like any other catch. Returns nil when
-- the hold has no room, so a full boat never awards the fish.
function Data.netCatch(raw, boatId, layout, roll, caughtAt, species, mutations)
	local data = Data.decode(raw)
	local traits = roll.Traits or {}
	local mutation = traits.Mutation or "Normal"
	local record =
		catchRecord(roll.FishId, mutation, roll.Kg, roll.Value, caughtAt, species, mutations, roll.Size, traits)
	local items = Data.hold(data, boatId, layout)
	local placement = cargo().bestSpot(layout.Hold, items, { Fish = record }, species)
	if not placement then
		return nil
	end
	table.insert(items, { Fish = record, X = placement.X, Y = placement.Y, R = placement.R })
	data.Holds[boatId] = items
	registerCatch(data, record, species)
	return Data.decode(data)
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
Data.KITCHEN_STORAGE_CAPACITY = 8

function Data.setKitchenStorageTargets(raw, targets)
	local data = Data.decode(raw)
	local total = 0
	local clean = {}
	for _, rarity in { "Common", "Uncommon", "Rare", "Epic", "Legendary" } do
		local count = tonumber(targets and targets[rarity]) or 0
		count = math.max(0, math.floor(count))
		clean[rarity] = count
		total += count
	end
	if total > Data.KITCHEN_STORAGE_CAPACITY then
		return nil, "Kitchen storage can hold at most " .. Data.KITCHEN_STORAGE_CAPACITY .. " fish."
	end
	data.KitchenStorage.Targets = clean
	return data
end

function Data.takeKitchenStorageFish(raw, fishIndex)
	local data = Data.decode(raw)
	if data.Hand then
		return nil, "Your hands are already full."
	end
	local count = #data.KitchenStorage.Fish
	if count == 0 then
		return nil, "Kitchen storage is empty."
	end
	local idx = fishIndex or count
	local fish = table.remove(data.KitchenStorage.Fish, idx)
	if not fish then
		return nil, "That fish is no longer in kitchen storage."
	end
	data.Hand = fish
	return data, fish
end

function Data.neededKitchenStorage(data, catalogFish)
	local targets = data.KitchenStorage.Targets or {}
	local current = {}
	for _, fish in data.KitchenStorage.Fish or {} do
		local spec = catalogFish and catalogFish[fish.FishId]
		local r = spec and spec.Rarity or "Common"
		current[r] = (current[r] or 0) + 1
	end
	local needed = {}
	local totalCurrent = #(data.KitchenStorage.Fish or {})
	local totalRoom = math.max(0, Data.KITCHEN_STORAGE_CAPACITY - totalCurrent)
	for _, rarity in { "Common", "Uncommon", "Rare", "Epic", "Legendary" } do
		local target = targets[rarity] or 0
		local have = current[rarity] or 0
		if target > have and totalRoom > 0 then
			needed[rarity] = math.min(target - have, totalRoom)
		else
			needed[rarity] = 0
		end
	end
	return needed, totalRoom
end

function Data.canKitchenStorageAccept(data, record, catalogFish)
	if not record then
		return false
	end
	local needed, totalRoom = Data.neededKitchenStorage(data, catalogFish)
	if totalRoom <= 0 then
		return false
	end
	local spec = catalogFish and catalogFish[record.FishId]
	local rarity = spec and spec.Rarity or "Common"
	return (needed[rarity] or 0) > 0
end

function Data.addKitchenStorageFish(raw, record, catalogFish)
	local data = Data.decode(raw)
	if not Data.canKitchenStorageAccept(data, record, catalogFish) then
		return nil, "Kitchen storage cannot accept that fish."
	end
	table.insert(data.KitchenStorage.Fish, record)
	return data
end

function Data.stockKitchenStorageFromStock(raw, catalogFish)
	local data = Data.decode(raw)
	local moved = 0
	local function checkAndMove(list)
		local i = 1
		while i <= #list do
			local record = list[i]
			if Data.canKitchenStorageAccept(data, record, catalogFish) then
				table.remove(list, i)
				table.insert(data.KitchenStorage.Fish, record)
				moved += 1
			else
				i += 1
			end
		end
	end
	checkAndMove(data.Freezer)
	checkAndMove(data.Storage)
	return data, moved
end

return Data
