-- Pirate Cove's crew (Shared.PirateCove): quest givers, Gunner Flint who sells rods outright,
-- Quartermaster Bess who buys fish from your hand and backpack up to DAILY_SALES an in-game day,
-- and old Dreadbeard, who only has a story to tell.
-- The island is built by Map/PirateCove, possibly after this starts (distant generation runs once
-- the harbour is open), so the crew are placed once it exists. Talking happens on the client; every
-- action is checked here against the saved profile and the player standing beside that crew member.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoatData = require(script.Parent.BoatData)
local BoatService = require(script.Parent.BoatService)
local Data = require(script.Parent.AnglerData)
local GuideCostume = require(script.Parent.GuideCostume)
local Catalog = require(ReplicatedStorage.Shared.AnglerCatalog)
local Cove = require(ReplicatedStorage.Shared.PirateCove)
local DayNight = require(ReplicatedStorage.Shared.DayNight)
local RodSkins = require(ReplicatedStorage.Shared.RodSkins)

local Service = {}
local started = false

local PROMPT = "PirateCoveNpcPrompt"
-- The client tutorial turns anything with this tag towards a player who walks up.
local TURN_TAG = "TutorialGuide"

local state: Folder
local crew: Folder
local positions: { [string]: Vector3 } = {}
local busy: { [Player]: boolean } = {}
local lastRequest: { [Player]: number } = {}

local function today(): number
	return Cove.day(DayNight.elapsed())
end

local function rarityOf(fishId: string): string?
	local fish = Catalog.Fish[fishId]
	return fish and fish.Rarity
end

local function fishName(fishId: string?): string?
	local fish = fishId and Catalog.Fish[fishId]
	return fish and fish.Name
end

----------------------------------------------------------------------------------------------------
-- Placing the crew

local function waitForIsland(): Model
	while true do
		local map = workspace:FindFirstChild("Map")
		local island = map and map:FindFirstChild(Cove.NAME)
		if island and island:IsA("Model") and island:GetAttribute("Plaza") then
			return island
		end
		task.wait(2)
	end
end

-- Feet frame for a crew member: a named anchor the island set, or an island-local spot dropped
-- onto the ground and turned towards its Face point (or the plaza).
local function placement(island: Model, npc): CFrame?
	local plaza = island:GetAttribute("Plaza")
	if type(npc.Spot) == "string" then
		local anchor = island:GetAttribute("Anchor_" .. npc.Spot)
		return if typeof(anchor) == "CFrame" then anchor else nil
	end
	local center = Vector3.new(Cove.CENTER[1], 0, Cove.CENTER[2])
	local spot = center + Vector3.new(npc.Spot[1], 0, npc.Spot[2])
	local rays = RaycastParams.new()
	rays.FilterType = Enum.RaycastFilterType.Include
	rays.FilterDescendantsInstances = { island }
	local hit = workspace:Raycast(spot + Vector3.new(0, 200, 0), Vector3.new(0, -260, 0), rays)
	local feet = if hit then hit.Position else spot + Vector3.new(0, 12, 0)
	local look = if type(npc.Face) == "table"
		then center + Vector3.new(npc.Face[1], 0, npc.Face[2])
		elseif typeof(plaza) == "Vector3" then plaza
		else center
	local flat = Vector3.new(look.X, feet.Y, look.Z)
	if (flat - feet).Magnitude < 0.1 then
		return CFrame.new(feet)
	end
	return CFrame.lookAt(feet, flat)
end

local function talkPrompt(head: BasePart, id: string, npc)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT
	prompt.ActionText = if npc.Kind == "Shop" then "Buy rods" elseif npc.Kind == "Buyer" then "Sell fish" else "Talk"
	prompt.ObjectText = npc.Name .. " · " .. npc.Title
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.UIOffset = Vector2.new(0, -30)
	prompt:SetAttribute("NpcId", id)
	prompt.Parent = head
end

local function placeCrew()
	local island = waitForIsland()
	for _, id in Cove.Order do
		local npc = Cove.Npcs[id]
		local frame = placement(island, npc)
		if not frame then
			warn("[PirateCove] No place for " .. npc.Name)
			continue
		end
		positions[id] = frame.Position
		state:SetAttribute("Npc_" .. id, frame.Position)
		task.spawn(function()
			local displayName = npc.Name .. " · " .. npc.Title
			local model = if npc.Outfit.Catalog
				then GuideCostume.spawnCatalog(id, npc.Outfit, displayName, frame, crew)
				else GuideCostume.spawn(id, npc.Outfit, displayName, frame, crew)
			if not model then
				return
			end
			model:AddTag(TURN_TAG)
			local head = model:FindFirstChild("Head")
			if head and head:IsA("BasePart") then
				talkPrompt(head, id, npc)
			end
		end)
	end
end

----------------------------------------------------------------------------------------------------
-- What the client shows

local function questState(angler, id: string)
	local saved = angler.CoveQuests[id] or { Step = 1 }
	local quest = Cove.quest(id, saved.Step)
	if not quest then
		return { Step = saved.Step, Finished = true }
	end
	local caught = if saved.Accepted and saved.Base then angler.Stats.TotalCaught - saved.Base else 0
	local ready = false
	if saved.Accepted then
		if quest.Kind == "Catch" then
			ready = caught >= quest.Count
		else
			ready = Data.deliverFish(angler, function(record)
				return Cove.accepts(quest, record, rarityOf)
			end) ~= nil
		end
	end
	return {
		Step = saved.Step,
		Accepted = saved.Accepted == true,
		Ready = ready,
		Goal = Cove.goal(quest, caught, fishName(quest.FishId)),
	}
end

local function view(player: Player, id: string)
	local profile = BoatService.getProfile(player)
	local npc = Cove.Npcs[id]
	if not profile or not npc then
		return nil
	end
	local angler = profile.Angler
	if npc.Kind == "Lore" then
		return {
			Found = angler.Catches.DreadbeardsTreasure ~= nil,
			Unlocked = angler.TreasureUnlocked == true,
		}
	elseif npc.Kind == "Buyer" then
		local backpack = 0
		for _, item in angler.Backpack do
			if item.Fish and not item.Locked then
				backpack += 1
			end
		end
		return {
			SalesLeft = Cove.salesLeft(angler.CoveSales, today()),
			Holding = angler.Hand ~= nil,
			Backpack = backpack,
		}
	elseif npc.Kind == "Shop" then
		return { Owned = table.clone(profile.RodSkins or {}), Cash = profile.Cash }
	end
	return questState(angler, id)
end

----------------------------------------------------------------------------------------------------
-- Actions

local function near(player: Player, id: string): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local position = positions[id]
	return position ~= nil
		and humanoid ~= nil
		and humanoid.Health > 0
		and root ~= nil
		and root:IsA("BasePart")
		and (root.Position - position).Magnitude <= Cove.TALK_RANGE
end

local function accept(player: Player, id: string): (boolean, string)
	local profile = BoatService.getProfile(player)
	local saved = profile and profile.Angler.CoveQuests[id]
	local quest = Cove.quest(id, saved and saved.Step)
	if not quest then
		return false, "There's nothing more to do here."
	elseif saved and saved.Accepted then
		return true, quest.Title
	end
	local ok, message = BoatService.updateProgress(player, function(current)
		local angler = current.Angler
		local entry = angler.CoveQuests[id] or { Step = 1 }
		entry.Accepted = true
		entry.Base = angler.Stats.TotalCaught
		angler.CoveQuests[id] = entry
	end)
	return ok, if ok then "Quest accepted: " .. quest.Title else message
end

local function claim(player: Player, id: string): (boolean, string)
	local profile = BoatService.getProfile(player)
	if not profile then
		return false, "Your progress is still loading."
	end
	local saved = profile.Angler.CoveQuests[id]
	local step = saved and saved.Step or 1
	local quest = Cove.quest(id, step)
	if not quest or not (saved and saved.Accepted) then
		return false, "Accept the quest first."
	end
	local function matches(record)
		return Cove.accepts(quest, record, rarityOf)
	end
	if quest.Kind == "Catch" then
		if profile.Angler.Stats.TotalCaught - (saved.Base or 0) < quest.Count then
			return false, "You haven't caught enough fish yet."
		end
	elseif not Data.deliverFish(profile.Angler, matches) then
		return false, "You don't have the right fish. Locked fish stay in your backpack."
	end
	local ok, message = BoatService.updateProgress(player, function(current)
		local angler = current.Angler
		local entry = angler.CoveQuests[id]
		-- UpdateAsync may retry; check the stored profile every time.
		assert(entry and entry.Step == step and entry.Accepted, "Quest changed")
		if quest.Kind == "Catch" then
			assert(angler.Stats.TotalCaught - (entry.Base or 0) >= quest.Count, "Not enough fish caught")
		else
			local updated = Data.deliverFish(angler, matches)
			assert(updated, "The fish is gone")
			angler = updated
			current.Angler = angler
		end
		angler.CoveQuests[id] = { Step = step + 1 }
		current.Cash += quest.Cash
		angler.Stats.CoinsEarned += quest.Cash
		angler.Stats.TotalXP += quest.XP
	end)
	if not ok then
		return false, message
	end
	return true, string.format("%s complete! +$%d · +%d XP", quest.Title, quest.Cash, quest.XP)
end

local function sell(player: Player, onlyHand: boolean): (boolean, string)
	local profile = BoatService.getProfile(player)
	if not profile then
		return false, "Your progress is still loading."
	end
	local day = today()
	if Cove.salesLeft(profile.Angler.CoveSales, day) <= 0 then
		return false, "Sorry, love - we've got enough fish to feed the whole cove today. Come back tomorrow!"
	end
	local _, preview = Data.sellToCove(profile.Angler, day, Cove.DAILY_SALES, onlyHand)
	if preview == 0 then
		return false, if onlyHand then "You're not holding a fish." else "You've no fish to sell. Locked fish stay put."
	end
	local sold, earned = 0, 0
	local ok, message = BoatService.updateProgress(player, function(current)
		local updated
		updated, sold, earned = Data.sellToCove(current.Angler, day, Cove.DAILY_SALES, onlyHand)
		current.Angler = updated
		current.Cash += earned
	end)
	if not ok then
		return false, message
	end
	local left = Cove.DAILY_SALES
		- ((BoatService.getProfile(player) or profile).Angler.CoveSales or { Count = 0 }).Count
	return true,
		string.format(
			"Sold %d fish for $%d. %s",
			sold,
			earned,
			if left > 0 then string.format("I'll take %d more today.", left) else "That's all the cove needs today!"
		)
end

local function buyRod(player: Player, skinId: any): (boolean, string)
	local offer
	for _, rod in Cove.Rods do
		if rod.SkinId == skinId then
			offer = rod
		end
	end
	if not offer then
		return false, "Flint doesn't sell that rod."
	end
	local profile = BoatService.getProfile(player)
	if not profile then
		return false, "Your wallet is still loading."
	end
	local preview = BoatData.buyRodSkin(profile, offer.SkinId, offer.Price, Cove.ROD_WEAR)
	if preview == "InsufficientFunds" then
		return false, string.format("You need $%d for the %s.", offer.Price, RodSkins.Skins[offer.SkinId].Name)
	elseif preview ~= "Purchased" then
		return false, "Your rod is still loading. Try again in a moment."
	end
	local ok, message = BoatService.updateProgress(player, function(current, serial)
		local result = BoatData.buyRodSkin(current, offer.SkinId, offer.Price, Cove.ROD_WEAR, serial)
		assert(result == "Purchased", result)
	end, offer.SkinId)
	if not ok then
		return false, message
	end
	return true, "You bought the " .. RodSkins.Skins[offer.SkinId].Name .. "! Equip it from your Equipment Bag."
end

function Service.start()
	if started then
		return
	end
	started = true
	state = Instance.new("Folder")
	state.Name = "PirateCove"
	local remote = Instance.new("RemoteFunction")
	remote.Name = "Request"
	remote.Parent = state
	state.Parent = ReplicatedStorage
	crew = Instance.new("Folder")
	crew.Name = "PirateCoveCrew"
	crew.Parent = workspace

	remote.OnServerInvoke = function(player, action, id, value)
		if type(id) ~= "string" or not Cove.Npcs[id] then
			return { Ok = false, Message = "Nobody here by that name." }
		end
		if action == "Get" then
			return { Ok = true, State = view(player, id) }
		end
		if os.clock() - (lastRequest[player] or -math.huge) < 0.3 or busy[player] then
			return { Ok = false, Message = "One moment...", State = view(player, id) }
		end
		lastRequest[player] = os.clock()
		if not near(player, id) then
			return { Ok = false, Message = "Walk up to " .. Cove.Npcs[id].Name .. " first.", State = view(player, id) }
		end
		local kind = Cove.Npcs[id].Kind
		busy[player] = true
		local ok, outcome = pcall(function()
			if kind == "Quests" and action == "Accept" then
				return table.pack(accept(player, id))
			elseif kind == "Quests" and action == "Claim" then
				return table.pack(claim(player, id))
			elseif kind == "Buyer" and (action == "SellHand" or action == "SellAll") then
				return table.pack(sell(player, action == "SellHand"))
			elseif kind == "Shop" and action == "BuyRod" then
				return table.pack(buyRod(player, value))
			end
			return table.pack(false, "That isn't something they can help with.")
		end)
		busy[player] = nil
		if not ok then
			warn("[PirateCove] " .. tostring(outcome))
			return { Ok = false, Message = "Something went wrong. Try again in a moment.", State = view(player, id) }
		end
		return { Ok = outcome[1], Message = outcome[2], State = view(player, id) }
	end

	Players.PlayerRemoving:Connect(function(player)
		busy[player], lastRequest[player] = nil, nil
	end)
	task.spawn(placeCrew)
end

return Service
