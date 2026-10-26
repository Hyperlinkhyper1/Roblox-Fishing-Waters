-- Plaza purchases use the same wallet transaction as all other progress.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BoatService = require(script.Parent.BoatService)
local Backpacks = require(ReplicatedStorage.Shared.BackpackCatalog)
local Models = require(ReplicatedStorage.Shared.BackpackModels)
local Service = {}
local started = false
local requests = {}

local function atShop(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	for _, shop in CollectionService:GetTagged("BackpackShop") do
		local counter = shop:FindFirstChild("Counter")
		local prompt = counter and counter:FindFirstChild("BrowseBackpacksPrompt")
		if
			shop:IsDescendantOf(workspace)
			and prompt
			and prompt.Enabled
			and (root.Position - counter.Position).Magnitude <= prompt.MaxActivationDistance + 2
		then
			return true
		end
	end
	return false
end

local function state(player)
	local profile = BoatService.getProfile(player)
	return if profile then { Cash = profile.Cash, BackpackId = profile.Angler.BackpackId } else nil
end

local function problem(profile, id)
	local item = if type(id) == "string" then Backpacks.Items[id] else nil
	if not item then
		return "Choose a backpack from the store."
	end
	if Backpacks.rank(id) <= Backpacks.rank(profile.Angler.BackpackId) then
		return "You already have this backpack or a larger one."
	end
	if profile.Cash < item.Price then
		return "You need $" .. item.Price .. " for this backpack."
	end
	return nil
end

local function syncAppearance(player, force)
	local profile = BoatService.getProfile(player)
	local character = player.Character
	if not profile or not character then
		return
	end
	local id = profile.Angler.BackpackId
	if not Backpacks.Items[id] then
		id = "Starter"
	end
	local existing = character:FindFirstChild("FishingBackpack")
	if not force and existing and existing:GetAttribute("BackpackId") == id then
		return
	end
	Models.wear(character, id)
end

function Service.start()
	if started then
		return
	end
	started = true
	local remote = Instance.new("RemoteFunction")
	remote.Name, remote.Parent = "BackpackShop", ReplicatedStorage
	remote.OnServerInvoke = function(player, action, id)
		if os.clock() - (requests[player] or -math.huge) < 0.25 then
			return { Ok = false, Message = "Please wait a moment.", State = state(player) }
		end
		requests[player] = os.clock()
		local profile = BoatService.getProfile(player)
		if not profile then
			return { Ok = false, Message = "Your backpack is still loading." }
		end
		if action == "Get" then
			return { Ok = true, State = state(player) }
		end
		if action ~= "Buy" then
			return { Ok = false, Message = "That action is unavailable." }
		end
		if not atShop(player) then
			return { Ok = false, Message = "Visit the backpack store at the plaza." }
		end
		local failure = problem(profile, id)
		if failure then
			return { Ok = false, Message = failure, State = state(player) }
		end
		local ok, message = BoatService.updateProgress(player, function(current)
			assert(atShop(player), "Visit the backpack store at the plaza.")
			local reason = problem(current, id)
			assert(not reason, reason)
			local item = Backpacks.Items[id]
			current.Cash -= item.Price
			current.Angler.Stats.CoinsSpent += item.Price
			current.Angler.BackpackId = id
		end)
		if ok then
			syncAppearance(player)
		end
		return {
			Ok = ok,
			Message = if ok
				then Backpacks.Items[id].Name .. " purchased! Open Backpack [C] to pack your fish."
				else message,
			State = state(player),
		}
	end
	local function bind(player)
		player:GetAttributeChangedSignal("AnglerRevision"):Connect(function()
			syncAppearance(player)
		end)
		player.CharacterAppearanceLoaded:Connect(function()
			syncAppearance(player, true)
		end)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if not humanoid then
				return
			end
			character:WaitForChild(if humanoid.RigType == Enum.HumanoidRigType.R15 then "UpperTorso" else "Torso", 10)
			if player.Character == character then
				syncAppearance(player, true)
			end
		end)
		if player.Character then
			syncAppearance(player)
		end
	end
	Players.PlayerAdded:Connect(bind)
	for _, player in Players:GetPlayers() do
		bind(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		requests[player] = nil
	end)
end
return Service
