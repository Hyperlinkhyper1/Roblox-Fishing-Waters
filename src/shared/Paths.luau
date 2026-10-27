-- Business paths shown on the Home ▸ Paths tab. A player starts as a fish shop and
-- grows the business one stage at a time; stages stack, so every earlier stage keeps
-- working. The active stage must reach 100% (every goal done) before the next one
-- can be bought. Pure: no Roblox services, so the server, the menu and the saved-data
-- tests all read the same rules. See docs/PATHS.md for adding goals and stages.
local Paths = {}

-- Road order. A stage's Requires must all be completed before it can be chosen, so
-- Restaurant and Company both open after Supermarket and the player picks one first.
Paths.Order = { "Fishshop", "Supermarket", "Restaurant", "Company" }
Paths.FIRST = "Fishshop"
Paths.SKIP_PRODUCT_ID = 3722698836

-- Goal kinds (see docs/PATHS.md):
--   Stat      Stats[Stat] gained since the stage started reaches Target.
--   Staff     Staff[Role] is hired.
--   Furniture at least Target of Item are placed in the house.
--   Boat      the boat Boat is owned.
--   Upgrade   Angler.Upgrades[Upgrade] is at least Target (home upgrades, once added).
--   RodUpgrade the rod stat Upgrade is at least level Target.
Paths.Stages = {
	Fishshop = {
		Name = "Fish Shop",
		Tagline = "Where it all begins",
		Description = "Sell the raw fish you catch from your freezer to walk-in customers.",
		Price = 0,
		Requires = {},
		Features = { "Sell raw fish from your freezers", "Hire a Seller and a Porter" },
		Goals = {
			{ Kind = "Stat", Stat = "FishSold", Target = 25, Text = "Sell %d fish to customers" },
			{ Kind = "Stat", Stat = "CoinsEarned", Target = 2500, Money = true, Text = "Earn $%s" },
			{ Kind = "Staff", Role = "Seller", Text = "Hire a Seller" },
			{ Kind = "Staff", Role = "Porter", Text = "Hire a Porter" },
		},
	},
	Supermarket = {
		Name = "Fish Supermarket",
		Tagline = "Raw fish and ready meals",
		Description = "Cook fish into dishes on the kitchen benches in your processing room. "
			.. "Customers buy dishes from food display cases as well as raw fish.",
		Price = 5000,
		Requires = { "Fishshop" },
		Features = {
			"Two prep benches in your processing room",
			"Buy grill, smokehouse and sushi stations for pricier recipes",
			"Food display cases sell dishes in the shop",
		},
		-- Given once when the stage is bought, waiting in build mode.
		Grants = { FoodCase = 1 },
		Goals = {
			{ Kind = "Stat", Stat = "FoodCooked", Target = 20, Text = "Cook %d dishes" },
			{ Kind = "Stat", Stat = "FoodSold", Target = 15, Text = "Sell %d dishes in your shop" },
			{ Kind = "Furniture", Item = "FoodCase", Target = 1, Text = "Place a food display case" },
			{ Kind = "Furniture", Item = "GrillStation", Target = 1, Text = "Set up a grill station" },
			{ Kind = "Stat", Stat = "CoinsEarned", Target = 10000, Money = true, Text = "Earn $%s" },
		},
	},
	Restaurant = {
		Name = "The Restaurant",
		Tagline = "Fine dining by the water",
		Description = "A dining room opens behind your house. Diners sit down, order one specific "
			.. "dish and pay more than shop prices when you serve it.",
		Price = 15000,
		Requires = { "Supermarket" },
		Features = { "A dining room extension behind your house", "Diners pay 1.5x for the dish they order" },
		Grants = { DiningTable = 2 },
		Goals = {
			{ Kind = "Stat", Stat = "DinersServed", Target = 25, Text = "Serve %d diners" },
			{ Kind = "Furniture", Item = "DiningTable", Target = 4, Text = "Place %d dining tables" },
			{ Kind = "Furniture", Item = "SushiBar", Target = 1, Text = "Set up a sushi bar" },
			{ Kind = "Stat", Stat = "CoinsEarned", Target = 25000, Money = true, Text = "Earn $%s" },
		},
	},
	Company = {
		Name = "The Company",
		Tagline = "Let the crew do the fishing",
		Description = "Hire a fisherman who takes one of your boats onto the water and fishes on his own. "
			.. "He brings the catch home for your porter to unload.",
		Price = 20000,
		Requires = { "Supermarket" },
		Features = { "Hire a fisherman", "Assign him one of your boats" },
		Goals = {
			{ Kind = "Staff", Role = "Fisherman", Text = "Hire a Fisherman" },
			{ Kind = "Stat", Stat = "FishermanCatches", Target = 50, Text = "Your fisherman lands %d fish" },
			{ Kind = "Boat", Boat = "FishingBoat", Text = "Own a small fishing boat" },
			{ Kind = "Stat", Stat = "CoinsEarned", Target = 40000, Money = true, Text = "Earn $%s" },
		},
	},
}

local function commas(value: number): string
	local text = tostring(math.floor(value))
	while true do
		local replaced, count = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
		text = replaced
		if count == 0 then
			return text
		end
	end
end

-- The saved path state, filled in for profiles from before paths existed.
function Paths.state(angler)
	local saved = angler and angler.Paths
	return {
		Active = if saved and saved.Active then saved.Active else Paths.FIRST,
		Unlocked = if saved and saved.Unlocked then saved.Unlocked else { [Paths.FIRST] = true },
		Completed = if saved and saved.Completed then saved.Completed else {},
		Baseline = if saved and saved.Baseline then saved.Baseline else {},
		SkipCredits = if saved and saved.SkipCredits then saved.SkipCredits else 0,
	}
end

-- Accepts a whole wallet profile or just its Angler table.
local function anglerOf(profile)
	return if profile and profile.Angler then profile.Angler else profile
end

function Paths.unlocked(profile, stageId: string): boolean
	return Paths.state(anglerOf(profile)).Unlocked[stageId] == true
end

function Paths.goalText(goal): string
	local target = goal.Target or 1
	return string.format(goal.Text, if goal.Money then commas(target) else tostring(target))
end

-- Current and target counts for one goal of the active stage.
function Paths.goalProgress(goal, profile): (number, number)
	local angler = anglerOf(profile)
	local state = Paths.state(angler)
	local target = goal.Target or 1
	local current = 0
	if goal.Kind == "Stat" then
		local stats = angler and angler.Stats or {}
		current = (stats[goal.Stat] or 0) - (state.Baseline[goal.Stat] or 0)
	elseif goal.Kind == "Staff" then
		current = if angler and angler.Staff and angler.Staff[goal.Role] then 1 else 0
	elseif goal.Kind == "Furniture" then
		for _, entry in angler and angler.Furniture or {} do
			if entry.ItemId == goal.Item then
				current += 1
			end
		end
	elseif goal.Kind == "Boat" then
		current = if profile and profile.OwnedBoats and profile.OwnedBoats[goal.Boat] then 1 else 0
	elseif goal.Kind == "Upgrade" then
		current = angler and angler.Upgrades and angler.Upgrades[goal.Upgrade] or 0
	elseif goal.Kind == "RodUpgrade" then
		current = profile and profile.RodUpgrades and profile.RodUpgrades[goal.Upgrade] or 0
	end
	return math.clamp(current, 0, target), target
end

-- 0..1 for a stage: completed stages are 1, locked ones 0 and the active one the
-- average of its goals, so it is exactly 1 only when every goal is done.
function Paths.progress(profile, stageId: string): number
	local state = Paths.state(anglerOf(profile))
	if state.Completed[stageId] then
		return 1
	elseif state.Active ~= stageId then
		return 0
	end
	local goals = Paths.Stages[stageId].Goals
	if #goals == 0 then
		return 1
	end
	local total = 0
	for _, goal in goals do
		local current, target = Paths.goalProgress(goal, profile)
		total += if current >= target then 1 else current / target
	end
	local average = total / #goals
	-- Rounding must never show 100% while a goal is still open.
	for _, goal in goals do
		local current, target = Paths.goalProgress(goal, profile)
		if current < target then
			return math.min(average, 0.99)
		end
	end
	return 1
end

-- Potential next stages, including while the current quests are unfinished.
function Paths.nextStages(profile): { string }
	local state = Paths.state(anglerOf(profile))
	local result = {}
	for _, id in Paths.Order do
		if not state.Unlocked[id] then
			local ready = true
			for _, required in Paths.Stages[id].Requires do
				if required ~= state.Active and not state.Completed[required] then
					ready = false
				end
			end
			if ready then
				table.insert(result, id)
			end
		end
	end
	return result
end

-- Stages that can be chosen once the active one is finished or skipped.
function Paths.choices(profile): { string }
	local state = Paths.state(anglerOf(profile))
	return if Paths.progress(profile, state.Active) >= 1 then Paths.nextStages(profile) else {}
end

function Paths.skipProblem(profile, stageId: any): string?
	local state = Paths.state(anglerOf(profile))
	if type(stageId) ~= "string" or stageId ~= state.Active then
		return "Your active path changed. Reopen the Paths tab."
	elseif Paths.progress(profile, stageId) >= 1 then
		return "These quests are already complete. You still need money to open the next path."
	elseif #Paths.nextStages(profile) == 0 then
		return "There are no more path levels to unlock."
	end
	return nil
end

function Paths.skipWarning(profile): string
	local prices = {}
	for _, id in Paths.nextStages(profile) do
		table.insert(prices, Paths.Stages[id].Name .. ": $" .. commas(Paths.Stages[id].Price))
	end
	return "Warning: this skips quests only. You still need in-game money to open the next path"
		.. (if #prices > 0 then " (" .. table.concat(prices, " or ") .. ")." else ".")
end

-- nil when `stageId` can be bought now, otherwise a player-facing reason.
function Paths.chooseProblem(profile, stageId: any): string?
	local stage = if type(stageId) == "string" then Paths.Stages[stageId] else nil
	if not stage then
		return "Choose a path from the Paths tab."
	end
	local state = Paths.state(anglerOf(profile))
	if state.Unlocked[stageId] then
		return "You already run " .. stage.Name .. "."
	elseif Paths.progress(profile, state.Active) < 1 then
		return "Finish " .. Paths.Stages[state.Active].Name .. " to 100% first."
	elseif not table.find(Paths.choices(profile), stageId) then
		return stage.Name .. " isn't open yet."
	elseif (profile.Cash or 0) < stage.Price then
		return "You need $" .. commas(stage.Price) .. " for " .. stage.Name .. "."
	end
	return nil
end

-- Every stage is unlocked and the last one is finished.
function Paths.finished(profile): boolean
	local state = Paths.state(anglerOf(profile))
	for _, id in Paths.Order do
		if not state.Unlocked[id] then
			return false
		end
	end
	return Paths.progress(profile, state.Active) >= 1
end

Paths.commas = commas

return Paths
