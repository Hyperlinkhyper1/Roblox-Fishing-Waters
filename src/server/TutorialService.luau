-- The island tutorial: guides round the home plaza, each wearing one of Roblox's own free avatar
-- characters, and each player's saved progress through them. Talking happens on the client; the
-- server only checks the player stood beside the right guide before saving the next step.
-- /tutorial restarts the tour for anyone.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Tutorial = require(ReplicatedStorage.Shared.Tutorial)
local BoatService = require(script.Parent.BoatService)
local PlazaHouses = require(script.Parent.Map.PlazaHouses)

local Service = {}
local started = false

local PROMPT = "TutorialNpcPrompt"
local GUIDE_TAG = "TutorialGuide"
local IDLE_ANIMATION = "rbxassetid://507766388" -- Roblox's stock R15 idle
local SKIN = Color3.fromRGB(224, 173, 132)

local remote: RemoteEvent
local state: Folder
local guides: Folder
-- Feet position of each guide, set as soon as the spot is chosen so arrows work before the model loads.
local positions: { [string]: Vector3 } = {}
local busy: { [Player]: boolean } = {}

local function homePlaza(): (Model?, CFrame?)
	local map = workspace:FindFirstChild("Map")
	if not map then
		return nil, nil
	end
	for _, plaza in map:GetDescendants() do
		-- Other islands have piazzas too; the harbour's is the one with the Drydock.
		if plaza:IsA("Model") and plaza.Name == "Plaza" and plaza:FindFirstChild("Drydock") then
			local frame = PlazaHouses.pavingFrame(plaza)
			if frame then
				return plaza, frame
			end
		end
	end
	return nil, nil
end

-- The frame a guide's Spots are measured in, at ground level, or nil when that shop is missing.
local function anchorFrame(plaza: Model, plazaFrame: CFrame, anchor: string?): CFrame?
	if anchor == nil then
		return plazaFrame
	elseif anchor == "BackpackCounter" then
		local shop = plaza:FindFirstChild("BackpackShop")
		local counter = shop and shop:FindFirstChild("Counter")
		if counter and counter:IsA("BasePart") then
			return counter.CFrame * CFrame.new(0, -counter.Size.Y / 2, 0)
		end
	elseif anchor == "RodShopDoor" or anchor == "FurnitureShopDoor" then
		local shop = plaza:FindFirstChild(if anchor == "RodShopDoor" then "FishingRodShop" else "FurnitureShop")
		local exit = shop and shop:GetAttribute("ExitFrame")
		if typeof(exit) == "CFrame" then
			-- ExitFrame is where a character's root lands outside the door, facing out of it.
			return exit * CFrame.new(0, -3.2, 0)
		end
	end
	return nil
end

local function exclusions(): { Instance }
	local list: { Instance } = { guides }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

-- Ground under a spot, if it is open paving: no prop in the way and nothing (a balcony,
-- an awning) overhead that would catch the ray first.
local function openGround(position: Vector3): Vector3?
	local ignore = exclusions()
	local rays = RaycastParams.new()
	rays.FilterType = Enum.RaycastFilterType.Exclude
	rays.FilterDescendantsInstances = ignore
	rays.RespectCanCollide = true
	local hit = workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -14, 0), rays)
	if not hit or math.abs(hit.Position.Y - position.Y) > 2.5 then
		return nil
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = ignore
	overlap.RespectCanCollide = true
	local box = CFrame.new(hit.Position + Vector3.new(0, 3.2, 0))
	if #workspace:GetPartBoundsInBox(box, Vector3.new(2.6, 4.6, 2.6), overlap) > 0 then
		return nil
	end
	return hit.Position
end

-- The first clear spot, falling back to the first listed one so a guide always appears.
local function placement(plaza: Model, plazaFrame: CFrame, npc): CFrame
	local space = anchorFrame(plaza, plazaFrame, npc.Anchor)
	local spots = npc.Spots
	if not space then
		space, spots = plazaFrame, npc.Fallback or npc.Spots
	end
	local frame = space :: CFrame
	local chosen
	for _, spot in spots do
		chosen = openGround(frame * Vector3.new(spot[1], 0, spot[2]))
		if chosen then
			break
		end
	end
	if not chosen then
		local first = frame * Vector3.new(spots[1][1], 0, spots[1][2])
		local rays = RaycastParams.new()
		rays.FilterType = Enum.RaycastFilterType.Exclude
		rays.FilterDescendantsInstances = exclusions()
		local hit = workspace:Raycast(first + Vector3.new(0, 6, 0), Vector3.new(0, -14, 0), rays)
		chosen = if hit then hit.Position else first
	end
	local look = frame * Vector3.new(npc.Face[1], 0, npc.Face[2])
	local flat = Vector3.new(look.X, chosen.Y, look.Z)
	if (flat - chosen).Magnitude < 0.1 then
		return CFrame.new(chosen)
	end
	return CFrame.lookAt(chosen, flat)
end

local function outfitModel(npc): Model?
	local loaded, description = pcall(Players.GetHumanoidDescriptionFromOutfitId, Players, npc.OutfitId)
	if loaded then
		local ok, model =
			pcall(Players.CreateHumanoidModelFromDescriptionAsync, Players, description, Enum.HumanoidRigType.R15)
		description:Destroy()
		if ok then
			return model
		end
		warn("[Tutorial] " .. npc.Name .. "'s outfit could not be built: " .. tostring(model))
	else
		warn("[Tutorial] " .. npc.Name .. "'s outfit could not load: " .. tostring(description))
	end
	-- A plain body keeps the guide on the plaza when the Marketplace is unavailable.
	local plain = Instance.new("HumanoidDescription")
	plain.HeadColor, plain.LeftArmColor, plain.RightArmColor = SKIN, SKIN, SKIN
	plain.TorsoColor = Color3.fromRGB(56, 133, 193)
	plain.LeftLegColor, plain.RightLegColor = Color3.fromRGB(60, 60, 70), Color3.fromRGB(60, 60, 70)
	local ok, model = pcall(Players.CreateHumanoidModelFromDescriptionAsync, Players, plain, Enum.HumanoidRigType.R15)
	plain:Destroy()
	if ok then
		return model
	end
	warn("[Tutorial] " .. npc.Name .. " could not be built: " .. tostring(model))
	return nil
end

local function talkPrompt(head: BasePart, id: string, npc)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT
	prompt.ActionText = "Talk"
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

local function buildGuide(id: string, npc, frame: CFrame)
	local model = outfitModel(npc)
	if not model then
		return
	end
	model.Name = id
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("NpcId", id)
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		-- Classic outfits bring a face decal and dynamic heads bring FaceControls; anything else
		-- gets the engine's built-in smile, like the other locals.
		if not head:FindFirstChildOfClass("Decal") and not head:FindFirstChildOfClass("FaceControls") then
			local face = Instance.new("Decal")
			face.Name, face.Face, face.Texture = "face", Enum.NormalId.Front, "rbxasset://textures/face.png"
			face.Parent = head
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = npc.Name .. " · " .. npc.Title
		humanoid.NameDisplayDistance = 40
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.WalkSpeed, humanoid.JumpPower = 0, 0
		humanoid.BreakJointsOnDeath = false
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = part.Name == "HumanoidRootPart"
			part.CanCollide, part.CanTouch = false, false
			part.CanQuery = part.Name == "Head"
		end
	end
	model:PivotTo(frame + Vector3.new(0, model:GetExtentsSize().Y / 2, 0))
	-- Clients turn a guide towards whoever walks up and back to this frame afterwards.
	model:SetAttribute("HomeFrame", model:GetPivot())
	model.Parent = guides
	model:AddTag(GUIDE_TAG)
	if head and head:IsA("BasePart") then
		talkPrompt(head, id, npc)
	end
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local idle = Instance.new("Animation")
		idle.AnimationId = IDLE_ANIMATION
		local loaded, track = pcall(animator.LoadAnimation, animator, idle)
		if loaded then
			track.Looped = true
			track:Play()
		end
	end
end

local function placeGuides()
	local plaza, plazaFrame = homePlaza()
	if not plaza or not plazaFrame then
		warn("[Tutorial] The harbour plaza is missing; tutorial guides were not placed.")
		return
	end
	for _, id in Tutorial.Order do
		local npc = Tutorial.Npcs[id]
		local frame = placement(plaza, plazaFrame, npc)
		positions[id] = frame.Position
		state:SetAttribute("Npc_" .. id, frame.Position)
		-- Outfit requests yield; load every guide at once.
		task.spawn(buildGuide, id, npc, frame)
	end
end

local function publishState(player: Player): boolean
	local profile = BoatService.getProfile(player)
	if not profile then
		return false
	end
	local angler = profile.Angler
	local step = math.clamp(angler.TutorialStep, 1, #Tutorial.Steps)
	-- A save from a longer future tour counts as finished rather than stranding the player.
	local done = angler.TutorialDone or angler.TutorialStep > #Tutorial.Steps
	player:SetAttribute("TutorialStep", step)
	player:SetAttribute("TutorialDone", done)
	return true
end

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
		and (root.Position - position).Magnitude <= Tutorial.TALK_RANGE
end

-- Runs one saved change at a time per player, then republishes the attributes.
local function change(player: Player, transform: (any) -> ()): boolean
	if busy[player] then
		return false
	end
	busy[player] = true
	local ok = BoatService.updateProgress(player, transform)
	busy[player] = nil
	if ok then
		publishState(player)
	end
	return ok
end

local function finish(player: Player, id: string)
	if not near(player, id) then
		return
	end
	local finished, reward = false, 0
	local ok = change(player, function(profile)
		local angler = profile.Angler
		-- UpdateAsync may retry the transform; recompute from the stored profile every time.
		finished, reward = false, 0
		local step, done = Tutorial.advance(angler.TutorialStep, angler.TutorialDone, id)
		if not step then
			return
		end
		angler.TutorialStep, angler.TutorialDone = step, done
		finished = done
		if done and not angler.TutorialRewarded then
			angler.TutorialRewarded = true
			reward = Tutorial.REWARD
			profile.Cash += reward
		end
	end)
	if ok and finished then
		remote:FireClient(player, "Finished", reward)
	end
end

local function restart(player: Player)
	local ok = change(player, function(profile)
		profile.Angler.TutorialStep, profile.Angler.TutorialDone = 1, false
	end)
	remote:FireClient(
		player,
		"Notice",
		if ok
			then "Tutorial restarted! Follow the arrow to Captain Wren."
			else "The tutorial could not restart right now. Try again in a moment."
	)
end

local function onPlayer(player: Player)
	if publishState(player) then
		return
	end
	-- Profiles load after joining; read the tutorial fields once they arrive.
	local connection
	connection = player:GetAttributeChangedSignal("AnglerRevision"):Connect(function()
		if publishState(player) then
			connection:Disconnect()
		end
	end)
end

function Service.start()
	if started then
		return
	end
	started = true
	state = Instance.new("Folder")
	state.Name = "Tutorial"
	remote = Instance.new("RemoteEvent")
	remote.Name = "Request"
	remote.Parent = state
	state.Parent = ReplicatedStorage
	guides = Instance.new("Folder")
	guides.Name = "TutorialGuides"
	guides.Parent = workspace

	remote.OnServerEvent:Connect(function(player, action, id)
		if action == "Finish" and type(id) == "string" and Tutorial.Npcs[id] then
			finish(player, id)
		elseif action == "Skip" then
			change(player, function(profile)
				profile.Angler.TutorialDone = true
			end)
		end
	end)

	local command = Instance.new("TextChatCommand")
	command.Name = "TutorialCommand"
	command.PrimaryAlias = "/tutorial"
	command.AutocompleteVisible = true
	command.Triggered:Connect(function(source)
		local player = source and Players:GetPlayerByUserId(source.UserId)
		if player then
			restart(player)
		end
	end)
	command.Parent = TextChatService

	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	placeGuides()
end

return Service
