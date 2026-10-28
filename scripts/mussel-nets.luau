-- Production net collection and wallet transactions with recording mocks.
-- Run: node scripts/check-boats.mjs --mussel-nets-only
local Grid = (function()
	-- GRID_SOURCE --
end)()
local Catalog = (function()
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
local MusselNets = (function()
	-- NET_RULES_SOURCE --
end)()
local FishCatch = (function()
	-- FISH_CATCH_SOURCE --
end)()
local FishMutations = (function()
	-- MUTATION_SOURCE --
end)()
local BackpackCatalog = (function()
	-- BACKPACK_SOURCE --
end)()
local BoatService = Service
local DayNight = {
	clockTime = function()
		return 12
	end,
	isNight = function()
		return false
	end,
}
local Weather = {
	mutationContext = function()
		return nil
	end,
}
local random = {
	NextNumber = function()
		return 0.5
	end,
	NextInteger = function()
		return 5
	end,
}
local busy, notices = {}, {}
local function notify(_, message)
	table.insert(notices, message)
end
local function refreshPlayer(_) end
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

local old = AnglerData.decode({ Stats = { TotalCaught = 3 } })
check(old.MusselNets.Stock == 0 and #old.MusselNets.Placed == 0, "Old profiles gain empty nets")
check(
	not pcall(AnglerData.decode, { MusselNets = { Stock = 0, Placed = { { X = 0, Z = 0, Uses = 0, ReadyAt = 1 } } } }),
	"Malformed saved nets are rejected"
)
check(MusselNets.PRICE == 125 and MusselNets.USES == 5, "Price and uses")
check(MusselNets.soak(function()
	return 0
end) == 180 and MusselNets.soak(function()
	return 0.999999
end) == 300, "Soak bounds")
for _, id in MusselNets.Pool.Fish do
	local fish = Catalog.Fish[id]
	check(fish and fish.Rarity ~= "Junk", "Net catches can have sizes and mutations")
	local _, size = FishCatch.rollWeight(fish, function()
		return 0
	end)
	check(size == "Huge", "Every species can roll huge")
	local traits = FishMutations.roll(fish, false, function()
		return 0
	end)
	check(traits.Mutation ~= "Normal", "Every species can mutate")
end
local player = makePlayer(99202, 4321, true)
model:SetAttribute("OwnerUserId", player.UserId)
check(
	Service.updateProgress(player, function(current)
		MusselNets.buy(current)
		MusselNets.place(current.Angler, -5, -20, 0, 1)
	end),
	"Buy and place a net"
)
local initial = Service.getProfile(player)
check(initial.Cash == 4196 and initial.Angler.MusselNets.Placed[1].Uses == 5, "Purchase and placement saved")
check(
	MusselNets.placeProblem(
		{ MusselNets = { Stock = 1, Placed = {} }, CrabCages = { Placed = { { X = -5, Z = -20 } } } },
		-5,
		-20
	) ~= nil,
	"Nets cannot overlap cages"
)
Service.profiles[player] = nil
Service.loadPlayer(player)
check(Service.getProfile(player).Angler.MusselNets.Placed[1].Uses == 5, "Placed net survives reload")
-- Fill the hand: five distinct normal items cannot fit the four-cell starter bag.
local held =
	AnglerData.recordCatch(nil, "BlueMussel", "Normal", 0.12, 9, 1, Catalog.Fish, Catalog.Mutations, "Normal").Hand
check(
	Service.updateProgress(player, function(current)
		current.Angler.Hand = held
	end),
	"Occupy hands"
)
collect(player, prompt)
local before = Service.getProfile(player).Angler
check(before.MusselNets.Placed[1].Uses == 5 and #before.Backpack == 0, "Full harvest is retained when it cannot fit")
local rolls = pendingRolls[model]
check(#rolls == 5, "Five catches rolled")
local seen = {}
for _, roll in rolls do
	check(not seen[roll.FishId], "Each catch in a harvest is distinct")
	seen[roll.FishId] = true
end
collect(player, prompt)
check(pendingRolls[model] == rolls, "Blocked retry retains the same catches")
check(
	Service.updateProgress(player, function(current)
		current.Angler.Hand = nil
	end),
	"Clear hands"
)
store.emptyResult = true
collect(player, prompt)
store.emptyResult = false
check(
	Service.getProfile(player).Angler.MusselNets.Placed[1].Uses == 5 and pendingRolls[model] == rolls,
	"Unconfirmed save retains harvest and uses"
)
store.retryTransform = true
collect(player, prompt)
store.retryTransform = false
local after = Service.getProfile(player).Angler
check(
	after.Hand ~= nil and #after.Backpack == 4 and after.Stats.TotalCaught == 5,
	"All five catches awarded once on retry"
)
check(after.MusselNets.Placed[1].Uses == 4 and after.Stats.MusselNetsOpened == 1, "One use consumed")
Service.profiles[player] = nil
Service.loadPlayer(player)
after = Service.getProfile(player).Angler
check(after.MusselNets.Placed[1].Uses == 4 and #after.Backpack == 4, "Harvest survives reload")
print("Mussel nets: " .. checks .. " checks passed (recording mocks).")
