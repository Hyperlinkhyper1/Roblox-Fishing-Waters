-- Server-authoritative casting. The server validates each cast, decides when a
-- fish bites, rolls the fish and only awards it after a plausible reel fight.
-- Rod tools carry CastTarget/CastAt/CastPhase so every client can draw the line.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnglerData = require(script.Parent.AnglerData)
local AnglerService = require(script.Parent.AnglerService)
local BoatService = require(script.Parent.BoatService)
local Catalog = require(ReplicatedStorage.Shared.AnglerCatalog)
local FishCatch = require(ReplicatedStorage.Shared.FishCatch)

local CatchService = {}
local MAX_CAST_DISTANCE = 64
local MAX_LINE_LENGTH = 110
local MAX_FIGHT_SECONDS = 150
local BITE_SECONDS = Vector2.new(3, 8)
local casts = {}
local lastRequest = {}
local random = Random.new()
local started = false
local update: RemoteEvent

local function equippedRod(player: Player): (Tool?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("RodId") == "StarterRod" then
			return child, root
		end
	end
	return nil, nil
end

local function send(player: Player, kind: string, payload: any?)
	if player.Parent == Players then
		update:FireClient(player, kind, payload)
	end
end

local function cooler(player: Player)
	local profile = BoatService.getProfile(player)
	return {
		Fish = if profile then profile.Angler.Cooler else {},
		Capacity = AnglerData.COOLER_CAPACITY,
	}
end

local function clear(player: Player, reason: string?)
	local state = casts[player]
	if not state then
		return
	end
	casts[player] = nil
	for _, attribute in { "CastTarget", "CastAt", "CastPhase" } do
		state.tool:SetAttribute(attribute, nil)
	end
	if reason then
		send(player, "Cancelled", reason)
	end
end

local function finite(vector: Vector3): boolean
	return vector == vector and math.abs(vector.X) < 1e6 and math.abs(vector.Y) < 1e6 and math.abs(vector.Z) < 1e6
end

local function waterSurface(player: Player, target: Vector3): Vector3?
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = { player.Character }
	parameters.IgnoreWater = false
	local result = workspace:Raycast(target + Vector3.new(0, 30, 0), Vector3.new(0, -70, 0), parameters)
	if result and result.Instance == workspace.Terrain and result.Material == Enum.Material.Water then
		return result.Position
	end
	return nil
end

local function cast(player: Player, target: any)
	if typeof(target) ~= "Vector3" or not finite(target) or casts[player] then
		return
	end
	if player:GetAttribute("BoatDataStatus") ~= "Ready" then
		send(player, "Cancelled", "Your tackle box is still loading. Try again in a moment.")
		return
	end
	local tool, root = equippedRod(player)
	if not tool or not root then
		return
	end
	local offset = target - root.Position
	if Vector3.new(offset.X, 0, offset.Z).Magnitude > MAX_CAST_DISTANCE + 4 or math.abs(offset.Y) > 60 then
		send(player, "Cancelled", "That's too far to cast.")
		return
	end
	local surface = waterSurface(player, target)
	if not surface then
		send(player, "Cancelled", "Cast into open water.")
		return
	end
	local state = { tool = tool, target = surface, phase = "Waiting" }
	casts[player] = state
	tool:SetAttribute("CastTarget", surface)
	tool:SetAttribute("CastAt", workspace:GetServerTimeNow())
	tool:SetAttribute("CastPhase", "Waiting")
	send(player, "Cast", surface)
	task.delay(random:NextNumber(BITE_SECONDS.X, BITE_SECONDS.Y), function()
		if casts[player] ~= state then
			return
		end
		local pool = Catalog.Pools[Catalog.DefaultPool]
		local roll = FishCatch.roll(pool, Catalog.Fish, Catalog.Rarities, function()
			return random:NextNumber()
		end)
		state.roll, state.phase, state.hookedAt = roll, "Hooked", os.clock()
		tool:SetAttribute("CastPhase", "Hooked")
		send(player, "Bite", { FishId = roll.FishId, Difficulty = roll.Difficulty, Pool = pool.Name })
	end)
end

local function award(player: Player, roll)
	local before = #cooler(player).Fish
	local saved = false
	for attempt = 1, 4 do
		saved = AnglerService.recordCatch(player, roll.FishId, "Normal", roll.Kg, roll.Value, roll.Size)
		if saved or player.Parent ~= Players then
			break
		end
		task.wait(attempt)
	end
	local current = cooler(player)
	send(player, "Caught", {
		FishId = roll.FishId,
		Kg = roll.Kg,
		Size = roll.Size,
		Value = roll.Value,
		Saved = saved,
		Stored = saved and #current.Fish > before,
		Cooler = current,
	})
end

local function reel(player: Player, landed: any)
	local state = casts[player]
	if not state then
		return
	end
	if state.phase == "Waiting" then
		clear(player)
		send(player, "ReeledIn")
		return
	end
	local roll = state.roll
	local elapsed = os.clock() - state.hookedAt
	clear(player)
	if landed ~= true or elapsed < FishCatch.minimumFightSeconds(roll.Difficulty) or elapsed > MAX_FIGHT_SECONDS then
		send(player, "Escaped", roll.FishId)
		return
	end
	task.spawn(award, player, roll)
end

function CatchService.start()
	if started then
		return
	end
	started = true
	local remotes = Instance.new("Folder")
	remotes.Name = "Catch"
	local request = Instance.new("RemoteEvent")
	request.Name, request.Parent = "Request", remotes
	update = Instance.new("RemoteEvent")
	update.Name, update.Parent = "Update", remotes
	remotes.Parent = ReplicatedStorage
	request.OnServerEvent:Connect(function(player, action, value)
		if os.clock() - (lastRequest[player] or -math.huge) < 0.2 then
			return
		end
		lastRequest[player] = os.clock()
		if action == "Cast" then
			cast(player, value)
		elseif action == "Reel" then
			reel(player, value)
		elseif action == "Cooler" then
			send(player, "Cooler", cooler(player))
		end
	end)
	local function bind(player: Player)
		player:GetAttributeChangedSignal("BoatDataStatus"):Connect(function()
			if player:GetAttribute("BoatDataStatus") == "Ready" then
				send(player, "Cooler", cooler(player))
			end
		end)
	end
	Players.PlayerAdded:Connect(bind)
	for _, player in Players:GetPlayers() do
		bind(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		clear(player)
		lastRequest[player] = nil
	end)
	-- Unequipping, dying or walking away from the line ends the cast.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.5 then
			return
		end
		elapsed = 0
		for player, state in casts do
			local tool, root = equippedRod(player)
			if tool ~= state.tool or not root then
				clear(player, "Your line went slack.")
			elseif (root.Position - state.target).Magnitude > MAX_LINE_LENGTH then
				clear(player, "You walked too far and your line snapped.")
			elseif state.phase == "Hooked" and os.clock() - state.hookedAt > MAX_FIGHT_SECONDS then
				clear(player)
				send(player, "Escaped", state.roll.FishId)
			end
		end
	end)
end

return CatchService
