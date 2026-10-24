-- Server-authorized shop transactions and one restored Tool per rod owner.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoatService = require(script.Parent.BoatService)
local FishingRod = require(ReplicatedStorage.Shared.FishingRod)

local FishingService = {}
local states = {}
local started = false
local feedback: RemoteEvent

local function notify(player: Player, message: string)
	if player.Parent == Players then
		feedback:FireClient(player, "Notice", message)
	end
end

local function livingCharacter(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil, nil
	end
	return character, humanoid, root
end

local function shopPrompt(player: Player): ProximityPrompt?
	local character, _, root = livingCharacter(player)
	if not character or not root then
		return nil
	end
	for _, shop in CollectionService:GetTagged("FishingRodShop") do
		if not shop:IsDescendantOf(workspace) then
			continue
		end
		local frame, size = shop:GetAttribute("InteriorFrame"), shop:GetAttribute("InteriorSize")
		if typeof(frame) ~= "CFrame" or typeof(size) ~= "Vector3" then
			continue
		end
		local position = frame:PointToObjectSpace(root.Position)
		if
			math.abs(position.X) > size.X / 2
			or math.abs(position.Y) > size.Y / 2
			or math.abs(position.Z) > size.Z / 2
		then
			continue
		end
		local prompt = shop:FindFirstChild("BuyFishingRodPrompt", true)
		local part = prompt and prompt.Parent
		if not prompt or not prompt:IsA("ProximityPrompt") or not part or not part:IsA("BasePart") then
			continue
		end
		if (root.Position - part.Position).Magnitude > prompt.MaxActivationDistance + 2 then
			continue
		end
		local parameters = RaycastParams.new()
		parameters.FilterType = Enum.RaycastFilterType.Exclude
		parameters.FilterDescendantsInstances = { character }
		local head = character:FindFirstChild("Head")
		local eye = if head and head:IsA("BasePart") then head.Position else root.Position
		local result = workspace:Raycast(eye, part.Position - eye, parameters)
		if not result or result.Instance == part then
			return prompt
		end
	end
	return nil
end

-- Shop street doors and exits lead between the plaza and their interiors,
-- which stand away from the map. Stream the far side in before moving the character.
local function walkThroughDoor(player: Player, prompt: ProximityPrompt)
	local destination = prompt:GetAttribute("TeleportTo")
	local character, humanoid, root = livingCharacter(player)
	local door = prompt.Parent
	local state = states[player]
	if
		typeof(destination) ~= "CFrame"
		or not character
		or not humanoid
		or not root
		or humanoid.SeatPart
		or not state
		or not door
		or not door:IsA("BasePart")
		or (root.Position - door.Position).Magnitude > prompt.MaxActivationDistance + 4
		or os.clock() - state.lastDoor < 1.5
	then
		return
	end
	local trip = os.clock()
	state.lastDoor = trip
	feedback:FireClient(player, "DoorFade", trip)
	task.spawn(function()
		pcall(player.RequestStreamAroundAsync, player, destination.Position, 4)
		task.wait(0.25)
		if states[player] == state and character.Parent and humanoid.Health > 0 then
			character:PivotTo(destination)
			root.AssemblyLinearVelocity = Vector3.zero
		end
		-- Sent even when the move was skipped, so the client's fade always lifts.
		feedback:FireClient(player, "DoorArrived", trip)
	end)
end

local function ownsRod(player: Player): boolean
	return player:GetAttribute("BoatDataStatus") == "Ready" and player:GetAttribute("OwnsStarterRod") == true
end

local function ensureTool(player: Player): Tool?
	local character = livingCharacter(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not ownsRod(player) or not character or not backpack then
		player:SetAttribute("RodEquipped", false)
		return nil
	end
	local rod: Tool? = nil
	-- Prefer the equipped instance. Repeated requests never duplicate a Tool.
	for _, container in { character, backpack } do
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("RodId") == "StarterRod" then
				if rod then
					child:Destroy()
				else
					rod = child
				end
			end
		end
	end
	if not rod then
		rod = FishingRod.build()
		rod:SetAttribute("OwnerUserId", player.UserId)
		rod.Parent = backpack
	end
	player:SetAttribute("RodEquipped", rod.Parent == character)
	return rod
end

local function equip(player: Player)
	local character, humanoid = livingCharacter(player)
	if not character or not humanoid then
		return
	end
	local rod = ensureTool(player)
	if rod then
		humanoid:EquipTool(rod)
		player:SetAttribute("RodEquipped", rod.Parent == character)
	else
		notify(player, "Visit the plaza tackle shop to get your free starter rod first.")
	end
end

local function disconnect(connections)
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function bindPlayer(player: Player)
	if states[player] then
		return
	end
	local state = {
		connections = {},
		characterConnections = {},
		backpackConnections = {},
		queued = false,
		lastRequest = -math.huge,
		lastDoor = -math.huge,
	}
	states[player] = state
	player:SetAttribute("RodEquipped", false)
	local function scheduleSync()
		if state.queued then
			return
		end
		state.queued = true
		task.defer(function()
			state.queued = false
			if states[player] == state and player.Parent == Players then
				ensureTool(player)
			end
		end)
	end
	local function bindBackpack(backpack: Instance)
		disconnect(state.backpackConnections)
		table.insert(state.backpackConnections, backpack.ChildAdded:Connect(scheduleSync))
		table.insert(state.backpackConnections, backpack.ChildRemoved:Connect(scheduleSync))
		scheduleSync()
	end
	local function bindCharacter(character: Model)
		disconnect(state.characterConnections)
		player:SetAttribute("RodEquipped", false)
		table.insert(state.characterConnections, character.ChildAdded:Connect(scheduleSync))
		table.insert(state.characterConnections, character.ChildRemoved:Connect(scheduleSync))
		task.spawn(function()
			local humanoid = character:WaitForChild("Humanoid", 10)
			character:WaitForChild("HumanoidRootPart", 10)
			if states[player] ~= state or player.Character ~= character then
				return
			end
			if humanoid and humanoid:IsA("Humanoid") then
				table.insert(
					state.characterConnections,
					humanoid.Died:Connect(function()
						player:SetAttribute("RodEquipped", false)
					end)
				)
			end
			scheduleSync()
		end)
	end
	for _, attribute in { "BoatDataStatus", "OwnsStarterRod" } do
		table.insert(state.connections, player:GetAttributeChangedSignal(attribute):Connect(scheduleSync))
	end
	table.insert(state.connections, player.CharacterAdded:Connect(bindCharacter))
	table.insert(
		state.connections,
		player.CharacterRemoving:Connect(function()
			disconnect(state.characterConnections)
			player:SetAttribute("RodEquipped", false)
		end)
	)
	table.insert(
		state.connections,
		player.ChildAdded:Connect(function(child)
			if child:IsA("Backpack") then
				bindBackpack(child)
			end
		end)
	)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		bindBackpack(backpack)
	end
	if player.Character then
		bindCharacter(player.Character)
	end
end

function FishingService.start()
	if started then
		return
	end
	started = true
	local remotes = Instance.new("Folder")
	remotes.Name, remotes.Parent = "Fishing", ReplicatedStorage
	local request = Instance.new("RemoteEvent")
	request.Name, request.Parent = "Request", remotes
	feedback = Instance.new("RemoteEvent")
	feedback.Name, feedback.Parent = "Feedback", remotes
	request.OnServerEvent:Connect(function(player, action)
		if action ~= "PurchaseRod" and action ~= "EquipRod" and action ~= "UnequipRod" then
			return
		end
		local state = states[player]
		if not state or os.clock() - state.lastRequest < 0.5 then
			return
		end
		state.lastRequest = os.clock()
		if action == "PurchaseRod" then
			if not shopPrompt(player) then
				notify(player, "Step inside the plaza tackle shop and approach the counter to buy a rod.")
				return
			end
			local success, message = BoatService.purchaseRod(player)
			if success and states[player] == state then
				equip(player)
				message = "Starter rod owned! Equip it from your backpack or the rod button."
			end
			notify(player, message)
		elseif action == "EquipRod" then
			equip(player)
		else
			local character, humanoid = livingCharacter(player)
			local rod = character and character:FindFirstChildOfClass("Tool")
			if humanoid and rod and rod:GetAttribute("RodId") == "StarterRod" then
				humanoid:UnequipTools()
				player:SetAttribute("RodEquipped", false)
			end
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name == "BuyFishingRodPrompt" and shopPrompt(player) == prompt then
			feedback:FireClient(player, "OpenShop")
		elseif prompt.Name == "RodStoreDoorPrompt" or prompt.Name == "FurnitureStoreDoorPrompt" then
			walkThroughDoor(player, prompt)
		end
	end)
	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(function(player)
		local state = states[player]
		states[player] = nil
		if state then
			disconnect(state.connections)
			disconnect(state.characterConnections)
			disconnect(state.backpackConnections)
		end
	end)
	for _, player in Players:GetPlayers() do
		bindPlayer(player)
	end
end

return FishingService
