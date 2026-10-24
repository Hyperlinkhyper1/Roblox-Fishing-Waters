-- Gives each player one of the harbour bases for as long as they're in the server
-- and makes them spawn on it. Players beyond the number of bases spawn in the plaza.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BASE_TAG = "PlayerBase"
local HOME_COOLDOWN = 5

local BaseService = {}

local owned: { [Player]: Model } = {}
local lastHome: { [Player]: number } = {}

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
	player.RespawnLocation = spawnPoint(base)
end

local function release(player: Player)
	lastHome[player] = nil
	local base = owned[player]
	if base then
		owned[player] = nil
		base:SetAttribute("OwnerUserId", 0)
		setBoard(base, "Base " .. tostring(base:GetAttribute("BaseId")))
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

-- The menu's Home button. The server picks the destination, so a client can only
-- ever ask to return to its own dock (or the plaza when every base is taken).
local function goHome(player: Player)
	if os.clock() - (lastHome[player] or -math.huge) < HOME_COOLDOWN then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local base = owned[player]
	local point = if base then spawnPoint(base) else harbourSpawn()
	if not character or not humanoid or humanoid.Health <= 0 or not point then
		return
	end
	lastHome[player] = os.clock()
	-- Leave any boat seat first, or the seat weld would drag the boat along.
	local seat = humanoid.SeatPart
	local weld = seat and seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
	humanoid.Sit = false
	character:PivotTo(point.CFrame + Vector3.new(0, 4, 0))
end

function BaseService.start()
	local home = Instance.new("RemoteEvent")
	home.Name, home.Parent = "GoHome", ReplicatedStorage
	home.OnServerEvent:Connect(goHome)
	Players.PlayerRemoving:Connect(release)
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.CharacterAutoLoads = true
end

return BaseService
