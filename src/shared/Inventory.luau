-- Display rules only. Entries keep their original source/index through sorting
-- and filtering; the server checks their identity again before changing a save.
local Inventory = {}

function Inventory.expected(item)
	if item.Dish then
		local d = item.Dish
		return { RecipeId = d.RecipeId, FishId = d.FishId, Kg = d.Kg, Value = d.Value, MadeAt = d.MadeAt, Mutation = d.Mutation, NeonColor = d.NeonColor, X = item.X, Y = item.Y }
	end
	local fish = item.Fish or item
	return { FishId = fish.FishId, Kg = fish.Kg, CaughtAt = fish.CaughtAt,
		Mutation = fish.Mutation, Value = fish.Value, Size = fish.Size, NeonColor = fish.NeonColor,
		Corruptions = table.concat(fish.Corruptions or {}, ","), X = item.X, Y = item.Y }
end

function Inventory.matches(item, expected): boolean
	if type(item) ~= "table" or type(expected) ~= "table" then return false end
	if item.Dish then
		local d = item.Dish
		return d.RecipeId == expected.RecipeId and d.FishId == expected.FishId and d.Kg == expected.Kg and d.Value == expected.Value and d.MadeAt == expected.MadeAt and d.Mutation == expected.Mutation and d.NeonColor == expected.NeonColor and item.X == expected.X and item.Y == expected.Y
	end
	local fish = item.Fish or item
	return fish.FishId ~= nil and fish.FishId == expected.FishId and fish.Kg == expected.Kg
		and fish.CaughtAt == expected.CaughtAt and fish.Mutation == expected.Mutation
		and fish.Value == expected.Value and fish.Size == expected.Size and fish.NeonColor == expected.NeonColor
		and table.concat(fish.Corruptions or {}, ",") == expected.Corruptions
		and item.X == expected.X and item.Y == expected.Y
end

function Inventory.entries(state, catalog, cargo, recipes)
	local entries = {}
	local function add(item, source, index)
		local fish = item.Fish
		local dish = item.Dish
		local recipe = dish and recipes and recipes.Items[dish.RecipeId]
		local species = fish and catalog.Fish[fish.FishId]
		local part = item.PartId and cargo.Parts[item.PartId]
		-- Tires keep their Common catch rarity, but belong with other found items.
		local isItem = fish and (fish.FishId == "Tire" or (species and species.Rarity == "Junk"))
		local mutation = fish and fish.Mutation ~= "Normal" and fish.Mutation or ""
		local name = if dish then (if recipe then recipe.Name else dish.RecipeId) elseif species then species.Name elseif part then part.Name else (fish and fish.FishId or "Item")
		table.insert(entries, {
			Item = item, Source = source, Index = index, Name = name,
			Search = string.lower(name .. " " .. mutation .. " " .. source),
			Kind = if fish and not isItem then "Fish" else "Items",
			Locked = item.Locked == true or (fish ~= nil and fish.Locked == true),
			Rarity = if species and catalog.Rarities[species.Rarity] then catalog.Rarities[species.Rarity].Order else -1,
			Worth = if dish then math.floor(dish.Value) elseif fish then math.floor(fish.Value) else 0,
			Order = #entries + 1,
		})
	end
	if state.Hand then add({ Fish = state.Hand, Locked = state.Hand.Locked }, "Hand", "Hand") end
	for index, item in state.Backpack or {} do add(item, "Backpack", index) end
	for index, item in state.Items or {} do add(item, "Boat", index) end
	return entries
end

function Inventory.visible(entries, tab, view, search, sortBy, ascending)
	local result, totalWorth = {}, 0
	local query = string.lower(search:match("^%s*(.-)%s*$"))
	for _, entry in entries do
		local inTab = tab == "All" or entry.Source == tab or (tab == "Backpack" and entry.Source == "Hand")
		local inView = view[entry.Kind] and (not view.Favorites or entry.Locked)
		if inTab and inView and (query == "" or string.find(entry.Search, query, 1, true)) then
			table.insert(result, entry)
			totalWorth += entry.Worth
		end
	end
	if sortBy then
		table.sort(result, function(a, b)
			local av = if sortBy == "Name" then string.lower(a.Name) else a[sortBy]
			local bv = if sortBy == "Name" then string.lower(b.Name) else b[sortBy]
			if av == bv then return a.Order < b.Order end
			return if ascending then av < bv else av > bv
		end)
	end
	return result, totalWorth
end

return Inventory
