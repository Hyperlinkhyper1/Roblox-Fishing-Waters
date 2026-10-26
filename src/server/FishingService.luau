-- Server-authorized shop transactions and one restored Tool per rod owner.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoatData = require(script.Parent.BoatData)
local BoatService = require(script.Parent.BoatService)
local FishingRod = require(ReplicatedStorage.Shared.FishingRod)
local RodSkins = require(ReplicatedStorage.Shared.RodSkins)
local BobberSkins = require(ReplicatedStorage.Shared.BobberSkins)
local RodUpgrades = require(ReplicatedStorage.Shared.RodUpgrades)

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

-- Finn wears genuine Roblox Marketplace items, applied by HumanoidDescription.
-- Asset IDs are catalog items, not clothing-template image IDs.
local KEEPER_OUTFIT = {
	Shirt = 733260904, -- Fisherman Shirt
	Pants = 129459077, -- Black Slacks, including black shoes
	Hat = "10714423462", -- Green Fisherman Hat
	Hair = "376548738", -- Brown Charmer Hair
	Skin = Color3.fromRGB(234, 184, 146),
}
local KEEPER_PROMPT = "TalkToRodKeeperPrompt"

local function keeperDescription(): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	description.Name = "RodKeeperAppearance"
	description.Shirt, description.Pants = KEEPER_OUTFIT.Shirt, KEEPER_OUTFIT.Pants
	description.HatAccessory, description.HairAccessory = KEEPER_OUTFIT.Hat, KEEPER_OUTFIT.Hair
	local skin = KEEPER_OUTFIT.Skin
	description.HeadColor, description.TorsoColor = skin, skin
	description.LeftArmColor, description.RightArmColor = skin, skin
	description.LeftLegColor, description.RightLegColor = skin, skin
	description.BodyTypeScale, description.ProportionScale = 0, 0
	return description
end

local function keeperPrompt(head: BasePart)
	local prompt = head:FindFirstChild(KEEPER_PROMPT) :: ProximityPrompt?
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = KEEPER_PROMPT
		prompt.Parent = head
	end
	local p = prompt :: ProximityPrompt
	p.ActionText = "Talk"
	p.ObjectText = "Finn · Rod Keeper"
	-- He stands behind the counter, so the prompt reaches a little further than the till's.
	p.MaxActivationDistance = 11
	p.RequiresLineOfSight = false
	p.HoldDuration = 0
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.UIOffset = Vector2.new(0, -30)
end

-- One anchored keeper per rod hall, built only if a hall arrives without him.
local function staffRodCounter(hall: Instance)
	local frame = hall:GetAttribute("KeeperFrame")
	if typeof(frame) ~= "CFrame" or hall:GetAttribute("KeeperPending") then
		return
	end
	local existing = hall:FindFirstChild("RodKeeper")
	local existingHead = existing and existing:FindFirstChild("Head")
	if existingHead and existingHead:IsA("BasePart") then
		keeperPrompt(existingHead)
		return
	end
	hall:SetAttribute("KeeperPending", true)
	task.spawn(function()
		local description = keeperDescription()
		local ok, keeper =
			pcall(Players.CreateHumanoidModelFromDescriptionAsync, Players, description, Enum.HumanoidRigType.R15)
		description:Destroy()
		if not ok then
			warn("[Fishing] Rod keeper outfit failed to load: " .. tostring(keeper))
			-- A plain body keeps the counter staffed when the catalog is unavailable.
			local plain = Instance.new("HumanoidDescription")
			plain.HeadColor, plain.TorsoColor = KEEPER_OUTFIT.Skin, Color3.fromRGB(70, 120, 90)
			ok, keeper =
				pcall(Players.CreateHumanoidModelFromDescriptionAsync, Players, plain, Enum.HumanoidRigType.R15)
			plain:Destroy()
		end
		hall:SetAttribute("KeeperPending", nil)
		if not ok then
			warn("[Fishing] Rod keeper could not be built: " .. tostring(keeper))
			return
		end
		if not hall.Parent or hall:FindFirstChild("RodKeeper") then
			keeper:Destroy()
			return
		end
		keeper.Name = "RodKeeper"
		keeper:SetAttribute("NpcName", "Finn")
		local head = keeper:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			-- Classic faces are retired from the Marketplace; use the engine's smile.
			local face = head:FindFirstChild("face")
			if not face then
				face = Instance.new("Decal")
				face.Name, face.Parent = "face", head
			end
			if face:IsA("Decal") then
				face.Face, face.Texture = Enum.NormalId.Front, "rbxasset://textures/face.png"
			end
		end
		local humanoid = keeper:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayName = "Finn · Rod Keeper"
			humanoid.NameDisplayDistance = 28
			humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			humanoid.WalkSpeed, humanoid.JumpPower = 0, 0
			humanoid.BreakJointsOnDeath = false
		end
		for _, part in keeper:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = part.Name == "HumanoidRootPart"
				part.CanCollide, part.CanTouch = false, false
				-- The server's sightline check aims at his head; hat and hair must not block it.
				part.CanQuery = part.Name == "Head"
			end
		end
		keeper:PivotTo(frame + Vector3.new(0, keeper:GetExtentsSize().Y / 2, 0))
		keeper.Parent = hall
		if head and head:IsA("BasePart") then
			keeperPrompt(head)
		end
		-- Roblox's stock R15 idle keeps him breathing instead of standing like a statue.
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local idle = Instance.new("Animation")
			idle.AnimationId = "rbxassetid://507766388"
			local loaded, track = pcall(animator.LoadAnimation, animator, idle)
			if loaded then
				track.Looped = true
				track:Play()
			end
		end
	end)
end

local function shopPrompt(player: Player, promptName: string): ProximityPrompt?
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
		local prompt = shop:FindFirstChild(promptName, true)
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

local UPGRADE_FAILURES = {
	UnknownUpgrade = "Finn doesn't offer that upgrade.",
	Maxed = "That upgrade is already maxed out.",
	NoRod = "Your starter rod is still loading. Please try again shortly.",
}

local function upgradeRod(player: Player, stat: any): (boolean, string)
	if not RodUpgrades.valid(stat) then
		return false, UPGRADE_FAILURES.UnknownUpgrade
	end
	local spec = RodUpgrades.Stats[stat]
	local profile = BoatService.getProfile(player)
	if not profile then
		return false, "Your wallet is still loading. Try again in a moment."
	end
	-- Pre-check the cached profile so a rejected request never costs a save.
	local level = RodUpgrades.level(profile.RodUpgrades, stat)
	local outcome = BoatData.upgradeRod(profile, stat)
	if outcome == "InsufficientFunds" then
		local price = RodUpgrades.price(stat, level)
		return false, string.format("You need $%d for %s level %d.", price or 0, spec.Name, level + 1)
	elseif outcome ~= "Upgraded" then
		return false, UPGRADE_FAILURES[outcome] or "That upgrade isn't available."
	end
	local ok, message = BoatService.updateProgress(player, function(current)
		local result = BoatData.upgradeRod(current, stat)
		assert(result == "Upgraded", result)
	end)
	if not ok then
		return false, message
	end
	return true, string.format("%s upgraded to level %d!", spec.Name, level + 1)
end

local CRATE_PROMPT = "OpenRodCratePrompt"
local BOBBER_PROMPT = "OpenBobberCratePrompt"
local CRATE_FAILURES = {
	UnknownCrate = "Finn doesn't have that crate.",
	NoRod = "Your starter rod is still loading. Please try again shortly.",
}

-- Rolls before saving so every UpdateAsync retry awards the same skin.
local function openRodCrate(player: Player, crateId: any, bobber: boolean?): (boolean, string, string?, number?)
	local skins = if bobber then BobberSkins else RodSkins
	local purchase = if bobber then BoatData.openBobberCrate else BoatData.openRodCrate
	if not skins.validCrate(crateId) then
		return false, CRATE_FAILURES.UnknownCrate
	end
	local crate = skins.Crates[crateId]
	local profile = BoatService.getProfile(player)
	if not profile then
		return false, "Your wallet is still loading. Try again in a moment."
	end
	local skinId = skins.roll(crateId, math.random(), math.random())
	-- Pre-check the cached profile so a rejected request never costs a save.
	local outcome = if bobber
		then purchase(profile, crateId, skinId)
		else BoatData.canOpenRodCrate(profile, crateId, skinId)
	if outcome == "InsufficientFunds" then
		return false, string.format("You need $%d to open the %s.", crate.Price, crate.Name)
	elseif outcome ~= "Opened" then
		return false, CRATE_FAILURES[outcome] or "That crate isn't available."
	end
	local serial
	local ok, message = BoatService.updateProgress(player, function(current, reservedSerial)
		local result, awardedSerial = purchase(current, crateId, skinId, reservedSerial)
		assert(result == "Opened", result)
		serial = awardedSerial
	end, if bobber then nil else skinId)
	if not ok then
		return false, message
	end
	return true,
		string.format(
			"You unboxed the %s%s!",
			skins.Skins[skinId].Name,
			if serial then string.format(" · Serial #%06d", serial) else ""
		),
		skinId,
		serial
end

-- "" puts the plain starter rod back on.
local function equipRodSkin(player: Player, skinId: any): (boolean, string)
	local serial
	if type(skinId) == "table" then
		serial = skinId.Serial
		skinId = skinId.SkinId
		if type(serial) ~= "number" or serial < 1 or serial >= 2 ^ 53 or serial % 1 ~= 0 then
			return false, "That skin serial isn't valid."
		end
	end
	local wanted = if skinId == "" then nil else skinId
	if wanted ~= nil and not RodSkins.valid(wanted) then
		return false, "That rod skin doesn't exist."
	end
	if
		(player:GetAttribute("RodSkin") or "") == (wanted or "")
		and (serial == nil or player:GetAttribute("RodSkinSerial") == serial)
	then
		return true, "Already equipped."
	end
	local profile = BoatService.getProfile(player)
	if not profile then
		return false, "Your inventory is still loading. Try again in a moment."
	end
	if BoatData.equipRodSkin(profile, wanted, serial) ~= "Equipped" then
		return false, "You don't own that rod skin yet."
	end
	local ok, message = BoatService.updateProgress(player, function(current)
		local result = BoatData.equipRodSkin(current, wanted, serial)
		assert(result == "Equipped", result)
	end)
	if not ok then
		return false, message
	end
	return true, if wanted then RodSkins.Skins[wanted].Name .. " equipped!" else "Starter rod look equipped."
end

local function equipBobberSkin(player: Player, skinId: any): (boolean, string)
	local wanted = if skinId == "" then nil else skinId
	if wanted ~= nil and not BobberSkins.valid(wanted) then
		return false, "That bobber skin doesn't exist."
	end
	local profile = BoatService.getProfile(player)
	if not profile then
		return false, "Your inventory is still loading. Try again in a moment."
	end
	if BoatData.equipBobberSkin(profile, wanted) ~= "Equipped" then
		return false, "You don't own that bobber skin yet."
	end
	local ok, message = BoatService.updateProgress(player, function(current)
		assert(BoatData.equipBobberSkin(current, wanted) == "Equipped", "Bobber is not owned")
	end)
	if not ok then
		return false, message
	end
	return true, if wanted then BobberSkins.Skins[wanted].Name .. " equipped!" else "Starter bobber equipped."
end

local function claimGroupReward(player: Player, automatic: boolean?)
	local state = states[player]
	if not state or state.groupBusy then
		return
	end
	local profile = BoatService.getProfile(player)
	if not profile then
		if not automatic then
			notify(player, "Your inventory is still loading. Try again shortly.")
		end
		return
	end
	if profile.GroupRodClaimed or (profile.RodSkins and profile.RodSkins[RodSkins.GroupReward]) then
		if not automatic then
			notify(player, "Your Tidebound Rod is already in your equipment bag!")
		end
		return
	end
	if os.clock() - state.lastGroupCheck < 5 then
		if not automatic then
			notify(player, "Please wait a few seconds before checking your group reward again.")
		end
		return
	end
	state.groupBusy, state.lastGroupCheck = true, os.clock()
	local ok, member = pcall(function()
		return player:IsInGroupAsync(RodSkins.GroupId)
	end)
	if states[player] ~= state or player.Parent ~= Players then
		return
	end
	if not ok or not member then
		state.groupBusy = false
		if not automatic then
			notify(
				player,
				if not ok
					then "Group membership couldn't be checked. Please try again."
					else "Join our group to claim! If you just joined, wait a minute and claim again, or rejoin the game."
			)
		end
		return
	end
	local outcome, serial
	local saved, message = BoatService.updateProgress(player, function(current, reservedSerial)
		outcome, serial = BoatData.claimGroupRod(current, reservedSerial)
	end, RodSkins.GroupReward)
	state.groupBusy = false
	if not saved then
		notify(player, message .. " Claim your group rod again from the equipment bag.")
	elseif outcome == "Claimed" then
		notify(
			player,
			string.format(
				"Group reward: Tidebound Rod · Serial #%06d! +7.5%% speed & strength. Find it in your equipment bag.",
				serial
			)
		)
	elseif not automatic then
		notify(player, "Your Tidebound Rod is already in your equipment bag!")
	end
end

local function wantedSkin(player: Player): string
	local skin = player:GetAttribute("RodSkin")
	return if RodSkins.valid(skin) then skin else ""
end

local function ownsRod(player: Player): boolean
	return player:GetAttribute("BoatDataStatus") == "Ready" and player:GetAttribute("OwnsStarterRod") == true
end

local function wantedBobber(player: Player): string
	local skin = player:GetAttribute("BobberSkin")
	return if BobberSkins.valid(skin) then skin else ""
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
	-- A changed skin swaps the whole Tool, keeping it in the hand it was in.
	local wasEquipped = false
	if
		rod
		and (
			(rod:GetAttribute("RodSkin") or "") ~= wantedSkin(player)
			or (rod:GetAttribute("BobberSkin") or "") ~= wantedBobber(player)
		)
	then
		wasEquipped = rod.Parent == character
		rod:Destroy()
		rod = nil
	end
	if not rod then
		local skin = wantedSkin(player)
		local bobber = wantedBobber(player)
		rod = FishingRod.build(if skin ~= "" then skin else nil, if bobber ~= "" then bobber else nil)
		rod:SetAttribute("OwnerUserId", player.UserId)
		rod.Parent = backpack
		local humanoid = (character :: Model):FindFirstChildOfClass("Humanoid")
		if wasEquipped and humanoid then
			humanoid:EquipTool(rod)
		end
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
		notify(player, "Your starter rod is still loading. Please try again shortly.")
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
		lastGroupCheck = -math.huge,
	}
	states[player] = state
	local function checkGroupReward()
		if player:GetAttribute("BoatDataStatus") == "Ready" and not state.groupChecked then
			state.groupChecked = true
			task.spawn(claimGroupReward, player, true)
		end
	end
	table.insert(state.connections, player:GetAttributeChangedSignal("BoatDataStatus"):Connect(checkGroupReward))
	checkGroupReward()
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
	for _, attribute in { "BoatDataStatus", "OwnsStarterRod", "RodSkin", "BobberSkin" } do
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
	request.OnServerEvent:Connect(function(player, action, value)
		if
			action ~= "EquipRod"
			and action ~= "UnequipRod"
			and action ~= "UpgradeRod"
			and action ~= "OpenRodCrate"
			and action ~= "OpenBobberCrate"
			and action ~= "EquipBobberSkin"
			and action ~= "EquipRodSkin"
			and action ~= "ClaimGroupReward"
		then
			return
		end
		local state = states[player]
		if not state or os.clock() - state.lastRequest < 0.5 then
			return
		end
		state.lastRequest = os.clock()
		if action == "ClaimGroupReward" then
			claimGroupReward(player)
		elseif action == "OpenRodCrate" or action == "OpenBobberCrate" then
			local bobber = action == "OpenBobberCrate"
			local resultKind = if bobber then "BobberCrateResult" else "CrateResult"
			if not shopPrompt(player, if bobber then BOBBER_PROMPT else CRATE_PROMPT) then
				feedback:FireClient(player, resultKind, false, "Step up to the matching case stand in the tackle shop.")
				return
			end
			local success, message, skinId, serial = openRodCrate(player, value, bobber)
			if player.Parent == Players then
				feedback:FireClient(player, resultKind, success, message, skinId, serial)
			end
		elseif action == "EquipBobberSkin" then
			local success, message = equipBobberSkin(player, value)
			if player.Parent == Players then
				feedback:FireClient(player, "BobberSkinResult", success, message)
			end
		elseif action == "EquipRodSkin" then
			local success, message = equipRodSkin(player, value)
			if player.Parent == Players then
				feedback:FireClient(player, "SkinResult", success, message)
			end
		elseif action == "UpgradeRod" then
			if not shopPrompt(player, KEEPER_PROMPT) then
				feedback:FireClient(player, "UpgradeResult", false, "Talk to Finn behind the counter to upgrade.")
				return
			end
			local success, message = upgradeRod(player, value)
			if player.Parent == Players then
				feedback:FireClient(player, "UpgradeResult", success, message)
			end
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
		if prompt.Name == KEEPER_PROMPT and shopPrompt(player, KEEPER_PROMPT) == prompt then
			feedback:FireClient(player, "OpenUpgrades")
		elseif prompt.Name == CRATE_PROMPT and shopPrompt(player, CRATE_PROMPT) == prompt then
			feedback:FireClient(player, "OpenCrates")
		elseif prompt.Name == BOBBER_PROMPT and shopPrompt(player, BOBBER_PROMPT) == prompt then
			feedback:FireClient(player, "OpenBobberCrates")
		elseif prompt.Name == "RodStoreDoorPrompt" or prompt.Name == "FurnitureStoreDoorPrompt" then
			walkThroughDoor(player, prompt)
		end
	end)
	CollectionService:GetInstanceAddedSignal("FishingRodShop"):Connect(staffRodCounter)
	for _, hall in CollectionService:GetTagged("FishingRodShop") do
		staffRodCounter(hall)
	end
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
