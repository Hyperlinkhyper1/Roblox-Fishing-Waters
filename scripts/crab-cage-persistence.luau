-- Production collection + wallet transactions with saved cages across rejoins.
-- Run: node scripts/check-boats.mjs --crab-cages-only
local Grid = (function()
	-- GRID_SOURCE --
end)()
local Species = (function()
	local Color3 = {
		fromRGB = function(...)
			return { ... }
		end,
	}
	-- CATALOG_SOURCE --
end)()
local AnglerData = (function()
	-- ANGLER_SOURCE --
end)()
local CrabCages = (function()
	-- CRAB_RULES_SOURCE --
end)()
local Catalog = {
	Fish = {
		ShoreCrab = { AverageKg = 1, RarityDenominator = 2, CatchXP = 100 },
		KingCrab = Species.Fish.KingCrab,
	},
	Mutations = { Normal = {} },
}
local BackpackCatalog = (function()
	-- BACKPACK_SOURCE --
end)()
local nextRoll = { FishId = "ShoreCrab", Kg = 1, Value = 20, Size = "Normal" }
local rollCount = 0
local FishCatch = {
	roll = function()
		rollCount += 1
		return nextRoll
	end,
}
local BoatService = Service
local busy = {}
local random = {
	NextNumber = function()
		return 0.5
	end,
}
local notices, refreshes = {}, 0
local function notify(_, message)
	table.insert(notices, message)
end
local function refreshPlayer(_)
	refreshes += 1
end
local function splash(_) end
local base = Instance.new("Model")
local function baseOf(_)
	return base
end
local function rootOf(player)
	return player.Character:FindFirstChild("HumanoidRootPart")
end
function CollectionService:HasTag(_, _)
	return true
end
local model = Instance.new("Model")
model.Parent = base
model:SetAttribute("X", -5)
model:SetAttribute("Z", -20)
function model:IsDescendantOf(other)
	return other == base
end
local anchor = Instance.new("Part")
anchor.Position, anchor.Parent = Vector3.zero, model
local prompt = Instance.new("ProximityPrompt")
prompt.MaxActivationDistance, prompt.Parent = 20, anchor
-- COLLECT_SOURCE --

local player = makePlayer(99201, 4321, true)
model:SetAttribute("OwnerUserId", player.UserId)
check(
	Service.updateProgress(player, function(profile)
		profile.Angler.Stats.TotalXP = 5000
		profile.Angler.Settings.MasterVolume = 35
		profile.Angler.CrabCages = {
			Stock = 4,
			Placed = {
				{ X = -5, Z = -20, Uses = 3, ReadyAt = 1 },
				{ X = 5, Z = -20, Uses = 1, ReadyAt = 2 },
			},
		}
	end),
	"Seed saved progress and two traps"
)
Service.profiles[player] = nil
Service.loadPlayer(player)
local revision = player:GetAttribute("AnglerRevision")

-- A successful pcall with no returned value used to decode as a brand-new player.
store.emptyResult = true
collect(player, prompt)
store.emptyResult = false
local profile = Service.getProfile(player)
check(profile.Cash == 4321 and profile.OwnedBoats.Rowboat, "Empty save result preserves cash and boats")
check(
	profile.Angler.Stats.TotalXP == 5000 and profile.Angler.Settings.MasterVolume == 35,
	"Empty save result preserves stats and settings"
)
check(
	#profile.Angler.CrabCages.Placed == 2 and profile.Angler.CrabCages.Stock == 4,
	"Empty save result cannot clear restored cages or stock"
)
check(
	player:GetAttribute("AnglerRevision") == revision and refreshes == 0,
	"An unconfirmed save never publishes defaults or refreshes cages"
)
check(#notices == 1 and not busy[player], "Unconfirmed haul reports failure and releases the cage lock")

store.updateFailures = 1
collect(player, prompt)
check(
	Service.getProfile(player).Angler.CrabCages.Placed[1].Uses == 3
		and Service.getProfile(player).Angler.Hand == nil
		and player:GetAttribute("AnglerRevision") == revision
		and not busy[player],
	"Thrown save failures preserve the profile and release the cage lock"
)

store.retryTransform = true
collect(player, prompt)
store.retryTransform = false
profile = Service.getProfile(player)
check(
	profile.Angler.Hand.FishId == "ShoreCrab" and profile.Angler.Stats.CrabCagesOpened == 1,
	"A retried haul awards one crab and one haul"
)
check(
	#profile.Angler.CrabCages.Placed == 2 and profile.Angler.CrabCages.Placed[1].Uses == 2,
	"Collecting after rejoining keeps every cage and consumes one use"
)
check(
	profile.Angler.CrabCages.Placed[2].Uses == 1 and profile.Angler.CrabCages.Placed[2].ReadyAt == 2,
	"Collecting leaves the other cage untouched"
)
check(
	profile.Cash == 4321 and profile.Angler.Stats.TotalXP == 5100 and profile.OwnedBoats.Rowboat,
	"Successful haul preserves the rest of the profile"
)
Service.profiles[player] = nil
Service.loadPlayer(player)
check(Service.getProfile(player).Angler.CrabCages.Placed[1].Uses == 2, "The collected trap survives another rejoin")
check(
	Service.updateProgress(player, function(current)
		current.Angler.Hand = nil
	end),
	"Make room for the second crab"
)
model:SetAttribute("X", 5)
collect(player, prompt)
profile = Service.getProfile(player)
check(
	#profile.Angler.CrabCages.Placed == 1
		and profile.Angler.CrabCages.Placed[1].X == -5
		and profile.Angler.CrabCages.Placed[1].Uses == 2,
	"A last haul removes only the exhausted cage, keeping the other saved trap"
)
check(
	profile.Angler.Stats.CrabCagesOpened == 2 and profile.Cash == 4321,
	"The second haul preserves cash and records exactly one additional haul"
)
-- A king crab must fit its whole shape, and a blocked haul must remain claimable.
local warning = "this is a big one, clear your hands to grab this one"
local held =
	AnglerData.recordCatch(nil, "ShoreCrab", "Normal", 1, 20, 7, Catalog.Fish, Catalog.Mutations, "Normal").Hand
local function seedHaul(backpackId, items, hand, size)
	pendingRolls[model] = nil
	model:SetAttribute("X", -5)
	nextRoll = { FishId = "KingCrab", Kg = 2.6, Value = 60, Size = size or "Normal" }
	check(
		Service.updateProgress(player, function(current)
			current.Angler.BackpackId = backpackId
			current.Angler.Backpack = items or {}
			current.Angler.Hand = hand
			current.Angler.CrabCages.Placed = { { X = -5, Z = -20, Uses = 1, ReadyAt = 1 } }
		end),
		"Seed a ready king crab haul"
	)
end

for _, scenario in
	{
		{ Bag = "Starter" }, -- Only four tiles even when empty.
		{ Bag = "Satchel", Items = { { Fish = held, X = 1, Y = 1, R = 0 } } }, -- Five free tiles.
		{ Bag = "Tackle", Items = { { Fish = held, X = 1, Y = 2, R = 0 }, { Fish = held, X = 2, Y = 3, R = 0 } } }, -- Six fragmented tiles.
		{ Bag = "Satchel", Size = "Huge" }, -- Size-specific footprint.
	}
do
	seedHaul(scenario.Bag, scenario.Items, held, scenario.Size)
	local before = Service.getProfile(player).Angler
	local updates, rolls = store.updates, rollCount
	collect(player, prompt)
	collect(player, prompt)
	local after = Service.getProfile(player).Angler
	check(notices[#notices] == warning, "A crab that cannot fit asks the player to clear their hands")
	check(store.updates == updates and rollCount == rolls + 1, "Blocked retries neither save nor reroll the crab")
	check(
		after.Hand.FishId == held.FishId and #after.Backpack == #(scenario.Items or {}),
		"Blocked hauls preserve existing catches"
	)
	check(
		after.CrabCages.Placed[1].Uses == 1 and after.CrabCages.Placed[1].ReadyAt == 1,
		"Blocked final hauls keep the cage ready"
	)
	check(
		after.Stats.TotalCaught == before.Stats.TotalCaught and after.Stats.TotalXP == before.Stats.TotalXP,
		"Blocked hauls award no catch or XP"
	)
	check(
		Service.updateProgress(player, function(current)
			current.Angler.Hand = nil
		end),
		"Clear the player's hands"
	)
	nextRoll = { FishId = "ShoreCrab", Kg = 1, Value = 20, Size = "Normal" }
	collect(player, prompt)
	after = Service.getProfile(player).Angler
	check(
		after.Hand.FishId == "KingCrab" and after.Hand.Size == (scenario.Size or "Normal"),
		"Clearing hands claims the same king crab"
	)
	check(
		rollCount == rolls + 1 and #after.CrabCages.Placed == 0,
		"A successful retry consumes the final use exactly once"
	)
end

seedHaul("Satchel", nil, held)
collect(player, prompt)
profile = Service.getProfile(player)
check(
	profile.Angler.Hand.FishId == "ShoreCrab" and profile.Angler.Backpack[1].Fish.FishId == "KingCrab",
	"A king crab still auto-packs when its rotated shape fits"
)

-- Storage can change between the initial fit check and the saved transaction.
seedHaul("Starter", nil, nil)
store.beforeUpdate = function(key)
	store.data[key].Angler.Hand = held
end
collect(player, prompt)
store.beforeUpdate = nil
check(
	notices[#notices] == warning and not busy[player],
	"A transaction that loses room gives the warning and releases the lock"
)
check(
	store.data["Player_" .. player.UserId].Angler.CrabCages.Placed[1].Uses == 1,
	"Losing room during a save cannot consume the crab"
)
check(
	store.data["Player_" .. player.UserId].Angler.Hand.FishId == "ShoreCrab",
	"Losing room during a save preserves the occupied hand"
)
print("Crab cage persistence: " .. checks .. " checks passed (recording mocks).")
