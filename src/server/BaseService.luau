-- Gives each player one of the harbour bases for as long as they're in the server
-- and makes them spawn on it. Players beyond the number of bases spawn in the plaza.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local BoatService = require(script.Parent.BoatService)

local BASE_TAG = "PlayerBase"

local BaseService = {}

local owned: { [Player]: Model } = {}

local function setBoard(base: Model, text: string)
	local board = base:FindFirstChild("NameBoard")
	if board then
		for _, label in board:GetDescendants() do
			if label:IsA("TextLabel") then
				label.Text = text
			end
		end
	end
end

local function setShopSign(base: Model, value: string)
	local sign = base:FindFirstChild("ShopSign", true)
	local label = sign and sign:FindFirstChildWhichIsA("TextLabel", true)
	if label then
		label.Text = if value ~= "" then value else "FISH & TACKLE  /  " .. string.format("%02d", base:GetAttribute("BaseId") or 1)
	end
end

local function freeBase(): Model?
	local bases = CollectionService:GetTagged(BASE_TAG)
	table.sort(bases, function(a, b)
		return (a:GetAttribute("BaseId") or 0) < (b:GetAttribute("BaseId") or 0)
	end)
	for _, base in bases do
		if base:GetAttribute("OwnerUserId") == 0 then
			return base :: Model
		end
	end
	return nil
end

local function spawnPoint(base: Model): SpawnLocation?
	return base:FindFirstChild("SpawnPoint") :: SpawnLocation?
end

local function harbourSpawn(): SpawnLocation?
	local map = workspace:FindFirstChild("Map")
	return (map and map:FindFirstChild("HarbourSpawn")) :: SpawnLocation?
end

local function claim(player: Player)
	local base = freeBase()
	if not base then
		player.RespawnLocation = harbourSpawn()
		return
	end
	owned[player] = base
	base:SetAttribute("OwnerUserId", player.UserId)
	player:SetAttribute("BaseId", base:GetAttribute("BaseId"))
	setBoard(base, player.DisplayName .. "'s Dock")
	setShopSign(base, "")
	local lastName = nil
	local generation = 0
	local function updateSign()
		if owned[player] ~= base then
			return
		end
		local profile = BoatService.getProfile(player)
		if not profile then
			return
		end
		local name = profile.Angler.ShopSign
		if name == lastName then
			return
		end
		lastName = name
		generation += 1
		local currentGeneration = generation
		if name == "" then
			setShopSign(base, "")
			return
		end
		task.spawn(function()
			local ok, filtered = pcall(function()
				return TextService:FilterStringAsync(name, player.UserId):GetNonChatStringForBroadcastAsync()
			end)
			if ok and owned[player] == base and generation == currentGeneration then
				setShopSign(base, filtered)
			elseif not ok and generation == currentGeneration then
				lastName = nil
			end
		end)
	end
	player:GetAttributeChangedSignal("AnglerRevision"):Connect(updateSign)
	updateSign()
	player.RespawnLocation = spawnPoint(base)
end

local function release(player: Player)
	local base = owned[player]
	if base then
		owned[player] = nil
		base:SetAttribute("OwnerUserId", 0)
		setBoard(base, "Base " .. tostring(base:GetAttribute("BaseId")))
		setShopSign(base, "")
	end
end

-- RespawnLocation normally handles this; moving the character as well covers spawns that
-- happened before the base existed.
local function placeCharacter(player: Player, character: Model)
	player:SetAttribute("FishingWatersSpawnReady", false)
	local base = owned[player]
	local point = if base then spawnPoint(base) else harbourSpawn()
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not point or not root or player.Character ~= character then
		return
	end
	task.wait()
	if player.Character ~= character or not root.Parent then
		return
	end
	if (root.Position - point.Position).Magnitude > 20 then
		character:PivotTo(point.CFrame + Vector3.new(0, 4, 0))
	end
	-- The loader may inspect collision only after the server's final placement.
	-- This also covers plaza spawns when all harbour bases have been claimed.
	player:SetAttribute("FishingWatersSpawnReady", true)
end

local function onPlayer(player: Player)
	player:SetAttribute("FishingWatersSpawnReady", false)
	claim(player)
	player.CharacterAdded:Connect(function(character)
		placeCharacter(player, character)
	end)
	if player.Character then
		task.spawn(placeCharacter, player, player.Character)
	else
		player:LoadCharacter()
	end
end

function BaseService.start()
	Players.PlayerRemoving:Connect(release)
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.CharacterAutoLoads = true
end

return BaseService
