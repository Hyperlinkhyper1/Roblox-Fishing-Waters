-- Mussel nets bought at Tide & Tackle are placed by the owner's dock. The server
-- saves their positions, timers and uses, and awards each harvest atomically.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnglerData = require(script.Parent.AnglerData)
local BoatService = require(script.Parent.BoatService)
local Props = require(script.Parent.Map.Props)
local BackpackCatalog = require(ReplicatedStorage.Shared.BackpackCatalog)
local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Catalog = require(ReplicatedStorage.Shared.AnglerCatalog)
local MusselNets = require(ReplicatedStorage.Shared.MusselNets)
local DayNight = require(ReplicatedStorage.Shared.DayNight)
local FishCatch = require(ReplicatedStorage.Shared.FishCatch)
local FishModels = require(ReplicatedStorage.Shared.FishModels)
local FishMutations = require(ReplicatedStorage.Shared.FishMutations)
local Weather = require(ReplicatedStorage.Shared.Weather)
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))

local MusselNetService = {}
local BASE_TAG = "PlayerBase"
local OWNER_PROMPT_TAG = "ShopOwnerPrompt"
-- Placed cage models; the client bobs their floats.
local CAGE_TAG = "MusselNet"
local TOOL_ATTRIBUTE = "MusselNetTool"
local PROMPT_NAME = "PullMusselNetPrompt"
local TOOL_SCALE = 0.45
local READY = Color3.fromRGB(111, 202, 125)
local SOAKING = Color3.fromRGB(250, 214, 64)
local started = false
local update: RemoteEvent
local requests: { [Player]: number } = {}
local busy: { [Player]: boolean } = {}
local random = Random.new()

local function ownerOf(base: Model): Player?
	local userId = base:GetAttribute("OwnerUserId")
	return if type(userId) == "number" and userId ~= 0 then Players:GetPlayerByUserId(userId) else nil
end

local function baseOf(player: Player): Model?
	for _, base in CollectionService:GetTagged(BASE_TAG) do
		if base:GetAttribute("OwnerUserId") == player.UserId and base:IsA("Model") then
			return base
		end
	end
	return nil
end

local function dockFrame(base: Model): CFrame?
	local frame = base:GetAttribute("BoatDockFrame")
	return if typeof(frame) == "CFrame" then frame else nil
end

local function notify(player: Player, message: string)
	if player.Parent == Players and message ~= "" then
		update:FireClient(player, "Notice", message)
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	return root
end

local function formatSeconds(seconds: number): string
	return if seconds >= 60 then string.format("%d:%02d", seconds // 60, seconds % 60) else seconds .. "s"
end

-- The cage's base sits under the water so its float rides on the surface. The
-- client's placement preview builds the same frame. Every cage faces along the
-- dock; a per-spot turn made the preview spin as the pointer crossed spots.
local function cageFrame(dock: CFrame, x: number, z: number): CFrame
	local spot = dock * Vector3.new(x, 0, z)
	return CFrame.new(spot.X, Biomes.WaterLevel - Props.MUSSEL_NET_WATERLINE, spot.Z) * dock.Rotation
end

local function key(x: number, z: number): string
	return string.format("%.1f|%.1f", x, z)
end

-- A short burst of spray where a cage goes in or comes up.
local function splash(position: Vector3)
	local spray = Instance.new("Part")
	spray.Name = "MusselNetSplash"
	spray.Size = Vector3.one
	spray.Transparency, spray.Anchored = 1, true
	spray.CanCollide, spray.CanQuery, spray.CanTouch = false, false, false
	spray.CFrame = CFrame.new(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(222, 240, 246))
	emitter.Transparency = NumberSequence.new(0.15, 1)
	emitter.Size = NumberSequence.new(0.4, 0.1)
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(6, 11)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.Acceleration = Vector3.new(0, -32, 0)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rate = 90
	emitter.Parent = spray
	spray.Parent = workspace
	task.delay(0.25, function()
		emitter.Rate = 0
	end)
	Debris:AddItem(spray, 2)
end

----------------------------------------------------------------------------------------------------
-- The hotbar cage

local function buildTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Mussel Net"
	tool.CanBeDropped = false
	tool.Grip = CFrame.Angles(0, math.rad(180), 0)
	tool:SetAttribute(TOOL_ATTRIBUTE, true)
	-- The client's placement preview sizes and sinks its copy of the cage with these.
	tool:SetAttribute("CageSize", Props.MUSSEL_NET_SIZE)
	tool:SetAttribute("CageScale", TOOL_SCALE)
	tool:SetAttribute("Waterline", Props.MUSSEL_NET_WATERLINE)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.4, 0.4)
	handle.Transparency = 1
	handle.CanCollide, handle.CanTouch, handle.CanQuery = false, false, false
	handle.Massless = true
	handle.Parent = tool
	local model = Props.musselNet(tool, CFrame.new(), false)
	model.Name = "CageModel"
	model:ScaleTo(TOOL_SCALE)
	-- Carried by the shackle on its bridle, so the cage hangs below the hand.
	handle.CFrame = CFrame.new(0, (Props.MUSSEL_NET_SIZE.Y + 0.47) * TOOL_SCALE, 0)
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.Anchored, piece.Massless = false, true
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = handle, piece
			weld.Parent = piece
		end
	end
	return tool
end

-- Keeps exactly one cage Tool while any cages are in stock; its name shows the count.
local function syncTool(player: Player)
	local profile = BoatService.getProfile(player)
	if not profile then
		return
	end
	local stock = profile.Angler.MusselNets.Stock
	local backpack = player:FindFirstChildOfClass("Backpack")
	local kept: Tool? = nil
	for _, container in { player.Character, backpack } do
		if not container then
			continue
		end
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute(TOOL_ATTRIBUTE) then
				if stock > 0 and not kept then
					kept = child
				else
					child:Destroy()
				end
			end
		end
	end
	if stock > 0 and not kept and backpack then
		kept = buildTool()
		kept.Parent = backpack
	end
	if kept then
		kept.Name = if stock > 1 then string.format("Mussel Net x%d", stock) else "Mussel Net"
		kept.ToolTip = string.format("%d in stock · click the water by your dock to drop one", stock)
	end
end

local function holdingCage(player: Player): boolean
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool:GetAttribute(TOOL_ATTRIBUTE) == true
end

----------------------------------------------------------------------------------------------------
-- Cages in the water

local function cageFolder(base: Model): Folder
	local folder = base:FindFirstChild("MusselNets")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "MusselNets"
		folder.Parent = base
	end
	return folder :: Folder
end

local function buildCage(folder: Folder, dock: CFrame, cage, userId: number): Model
	local frame = cageFrame(dock, cage.X, cage.Z)
	local model = Props.musselNet(folder, frame, true)
	model:SetAttribute("X", cage.X)
	model:SetAttribute("Z", cage.Z)
	model:SetAttribute("OwnerUserId", userId)
	model:SetAttribute("CageFrame", frame)
	local anchor = Instance.new("Part")
	anchor.Name = "CagePromptAnchor"
	anchor.Size = Vector3.one
	anchor.Transparency, anchor.Anchored = 1, true
	anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = false, false, false
	anchor.CFrame = frame * CFrame.new(0, Props.MUSSEL_NET_SIZE.Y + 0.6, 0)
	anchor.Parent = model
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = "Pull up"
	prompt.ObjectText = "Mussel Net"
	prompt.HoldDuration = 0.6
	-- Reaches down from the pier to anywhere the cage could have been dropped from it.
	prompt.MaxActivationDistance = MusselNets.REACH + 4
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	-- Owners' clients show it only while a crab is in (see ShopCustomers).
	prompt:SetAttribute("OwnerUserId", userId)
	prompt:SetAttribute("Available", false)
	CollectionService:AddTag(prompt, OWNER_PROMPT_TAG)
	prompt.Parent = anchor
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CageStatus"
	billboard.Size = UDim2.fromOffset(200, 42)
	billboard.StudsOffset = Vector3.new(0, 1.8, 0)
	billboard.MaxDistance = 60
	billboard.Parent = anchor
	for _, row in { { "State", 0, 24, 16 }, { "Uses", 24, 18, 13 } } do
		local label = Instance.new("TextLabel")
		label.Name = row[1]
		label.Position, label.Size = UDim2.fromOffset(0, row[2]), UDim2.new(1, 0, 0, row[3])
		label.BackgroundTransparency = 1
		label.TextSize, label.Text = row[4], ""
		Theme.text(label)
		label.Parent = billboard
	end
	CollectionService:AddTag(model, CAGE_TAG)
	return model
end

-- The prompt, billboard and flag follow the saved net.
local function refreshCage(model: Model, cage, now: number)
	local remaining = MusselNets.remaining(cage, now)
	local ready = remaining <= 0
	local anchor = model:FindFirstChild("CagePromptAnchor")
	local prompt = anchor and anchor:FindFirstChild(PROMPT_NAME)
	if prompt then
		prompt:SetAttribute("Available", ready)
	end
	local billboard = anchor and anchor:FindFirstChild("CageStatus")
	local state = billboard and billboard:FindFirstChild("State") :: TextLabel?
	local uses = billboard and billboard:FindFirstChild("Uses") :: TextLabel?
	if state and uses then
		state.Text = if ready then "Ready to harvest!" else "Soaking · " .. formatSeconds(remaining)
		state.TextColor3 = if ready then READY else Theme.Colors.Text
		uses.Text = string.format("%d of %d hauls left", cage.Uses, MusselNets.USES)
	end
	if model:GetAttribute("Ready") == ready then
		return
	end
	model:SetAttribute("Ready", ready)
	local float = model:FindFirstChild("Float")
	local flag = float and float:FindFirstChild("Flag")
	if flag and flag:IsA("BasePart") then
		flag.Color = if ready then READY else SOAKING
	end
end

-- The owner's saved cages, decoded again only when their profile has changed:
-- the countdown below asks every second.
local placedCache: { [Player]: { revision: any, placed: { any }? } } = {}
local function placedOf(player: Player): { any }?
	local revision = player:GetAttribute("AnglerRevision")
	local cached = placedCache[player]
	if not cached or cached.revision ~= revision then
		local profile = BoatService.getProfile(player)
		cached = { revision = revision, placed = profile and profile.Angler.MusselNets.Placed }
		placedCache[player] = cached
	end
	return cached.placed
end

-- Matches the base's cage models to its owner's saved cages.
local function refreshBase(base: Model)
	local owner = ownerOf(base)
	local placed = owner and placedOf(owner)
	local dock = dockFrame(base)
	local wanted = {}
	if owner and placed and dock then
		for _, cage in placed do
			wanted[key(cage.X, cage.Z)] = cage
		end
	end
	local folder = base:FindFirstChild("MusselNets")
	if not folder and not next(wanted) then
		return
	end
	folder = folder or cageFolder(base)
	local now = os.time()
	local shown = {}
	for _, model in folder:GetChildren() do
		local x, z = model:GetAttribute("X"), model:GetAttribute("Z")
		local spot = if type(x) == "number" and type(z) == "number" then key(x, z) else ""
		local cage = wanted[spot]
		if model:IsA("Model") and cage and not shown[spot] and model:GetAttribute("OwnerUserId") == owner.UserId then
			shown[spot] = true
			refreshCage(model, cage, now)
		else
			model:Destroy()
		end
	end
	for spot, cage in wanted do
		if not shown[spot] then
			refreshCage(buildCage(folder, dock :: CFrame, cage, owner.UserId), cage, now)
		end
	end
end

local function refreshPlayer(player: Player)
	syncTool(player)
	local base = baseOf(player)
	if base then
		refreshBase(base)
	end
end

----------------------------------------------------------------------------------------------------
-- Dropping and pulling up

local function openWater(position: Vector3, ignore: { Instance }): boolean
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = ignore
	parameters.IgnoreWater = false
	local result = workspace:Raycast(
		Vector3.new(position.X, Biomes.WaterLevel + 12, position.Z),
		Vector3.new(0, -24, 0),
		parameters
	)
	return result ~= nil and result.Instance == workspace.Terrain and result.Material == Enum.Material.Water
end

local function place(player: Player, target: any): (boolean, string)
	if
		typeof(target) ~= "Vector3"
		or target ~= target
		or math.abs(target.X) > 1e6
		or math.abs(target.Y) > 1e6
		or math.abs(target.Z) > 1e6
	then
		return false, ""
	end
	local profile = BoatService.getProfile(player)
	if not profile then
		return false, "Your progress is still loading. Try again in a moment."
	end
	local base = baseOf(player)
	local dock = base and dockFrame(base)
	if not base or not dock then
		return false, "You need a dock of your own to set mussel nets."
	end
	local root = rootOf(player)
	if not root or not holdingCage(player) then
		return false, "Equip a mussel net from your hotbar first."
	end
	local reach = target - root.Position
	if Vector3.new(reach.X, 0, reach.Z).Magnitude > MusselNets.REACH + 2 then
		return false, "That's too far away. Walk to the edge of your pier."
	end
	local spot = dock:PointToObjectSpace(target)
	local x, z = MusselNets.round(spot.X), MusselNets.round(spot.Z)
	local problem = MusselNets.placeProblem(profile.Angler, x, z)
	if problem then
		return false, problem
	end
	-- The whole footprint and the float must sit in open water, clear of piers,
	-- pilings, the quay and moored boats.
	local frame = cageFrame(dock, x, z)
	local ignore = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	for _, point in MusselNets.footprint(Props.MUSSEL_NET_SIZE) do
		if not openWater(frame * point, ignore) then
			return false, "Drop it into open water, clear of the piers."
		end
	end
	local now = os.time()
	local soak = MusselNets.soak(function()
		return random:NextNumber()
	end)
	busy[player] = true
	local ok, message = BoatService.updateProgress(player, function(current)
		MusselNets.place(current.Angler, x, z, now, soak)
	end)
	busy[player] = nil
	if not ok then
		return false, message
	end
	splash(Vector3.new(frame.X, Biomes.WaterLevel, frame.Z))
	refreshPlayer(player)
	return true, "Mussel net set! Harvest it in 3-5 minutes."
end

-- Keep a blocked harvest until it can be claimed; destroyed models drop out.
local pendingRolls: { [Instance]: any } = setmetatable({}, { __mode = "k" }) :: any

local function collect(player: Player, prompt: ProximityPrompt)
	local anchor = prompt.Parent
	local model = anchor and anchor.Parent
	local base = baseOf(player)
	if
		not anchor
		or not anchor:IsA("BasePart")
		or not model
		or not CollectionService:HasTag(model, CAGE_TAG)
		or model:GetAttribute("OwnerUserId") ~= player.UserId
		or not base
		or not model:IsDescendantOf(base)
	then
		return
	end
	local root = rootOf(player)
	if not root or (root.Position - anchor.Position).Magnitude > prompt.MaxActivationDistance + 3 then
		return
	end
	local x, z = model:GetAttribute("X"), model:GetAttribute("Z")
	local profile = BoatService.getProfile(player)
	if type(x) ~= "number" or type(z) ~= "number" or not profile then
		return
	end
	local now = os.time()
	local problem = MusselNets.collectProblem(profile.Angler, x, z, now)
	if problem then
		notify(player, problem)
		return
	end
	local backpack = BackpackCatalog.Items[profile.Angler.BackpackId] or BackpackCatalog.Items.Starter
	-- Roll once so a blocked harvest or save retry cannot reroll the catches.
	local function rng()
		return random:NextNumber()
	end
	local rolls = pendingRolls[model]
	if not rolls then
		rolls = {}
		local pool = { Fish = table.clone(MusselNets.Pool.Fish) }
		local count = random:NextInteger(MusselNets.MIN_HARVEST, MusselNets.MAX_HARVEST)
		for _ = 1, count do
			local roll = FishCatch.roll(pool, Catalog.Fish, Catalog.Rarities, rng)
			table.remove(pool.Fish, table.find(pool.Fish, roll.FishId))
			roll.Traits = FishMutations.roll(
				Catalog.Fish[roll.FishId],
				DayNight.isNight(DayNight.clockTime()),
				rng,
				nil,
				Weather.mutationContext(anchor.Position)
			)
			roll.Value = FishMutations.value(roll.Value, roll.Traits.Mutation, roll.Traits.Corruptions)
			table.insert(rolls, roll)
		end
		pendingRolls[model] = rolls
	end
	local noRoom = "Clear your hands or backpack to make room for the whole harvest."
	local function award(angler, layout)
		local destinations = {}
		for _, roll in rolls do
			local destination
			angler, destination = AnglerData.recordCatch(
				angler,
				roll.FishId,
				roll.Traits.Mutation,
				roll.Kg,
				roll.Value,
				now,
				Catalog.Fish,
				Catalog.Mutations,
				roll.Size,
				roll.Traits,
				layout
			)
			if destination == "Released" then
				return nil
			end
			table.insert(destinations, destination)
		end
		return angler, destinations
	end
	if not award(profile.Angler, backpack) then
		notify(player, noRoom)
		return
	end
	local soak = MusselNets.soak(rng)
	local left, destinations = 0, nil
	local blocked = false
	busy[player] = true
	local ok, message = BoatService.updateProgress(player, function(current)
		local layout = BackpackCatalog.Items[current.Angler.BackpackId] or BackpackCatalog.Items.Starter
		local awarded
		awarded, destinations = award(current.Angler, layout)
		blocked = awarded == nil
		assert(not blocked, noRoom)
		current.Angler = awarded
		left = MusselNets.collect(current.Angler, x, z, now, soak)
	end)
	busy[player] = nil
	if not ok then
		notify(player, if blocked then noRoom else message)
		return
	end
	pendingRolls[model] = nil
	local frame = model:GetAttribute("CageFrame")
	if typeof(frame) == "CFrame" then
		splash(Vector3.new(frame.X, Biomes.WaterLevel, frame.Z))
	end
	refreshPlayer(player)
	local catch = ReplicatedStorage:FindFirstChild("Catch")
	local reveal = catch and catch:FindFirstChild("Update")
	if reveal and reveal:IsA("RemoteEvent") then
		local roll = rolls[1]
		reveal:FireClient(player, "Caught", {
			FishId = roll.FishId,
			Kg = roll.Kg,
			Size = roll.Size,
			Value = roll.Value,
			Mutation = roll.Traits.Mutation,
			NeonColor = roll.Traits.NeonColor,
			Corruptions = roll.Traits.Corruptions,
			Saved = true,
			AutoStored = false,
			BackpackStored = destinations[1] == "Backpack",
			Stored = destinations[1] == "Hand",
		})
	end
	local names = {}
	for _, roll in rolls do
		table.insert(names, Catalog.Fish[roll.FishId].Name)
	end
	notify(player, "Harvested: " .. table.concat(names, ", ") .. ".")
	if left == 0 then
		notify(player, "That was the net's last harvest. Buy another at Tide & Tackle.")
	end
end

function MusselNetService.start()
	if started then
		return
	end
	started = true
	local remotes = Instance.new("Folder")
	remotes.Name = "MusselNets"
	local request = Instance.new("RemoteEvent")
	request.Name, request.Parent = "Request", remotes
	update = Instance.new("RemoteEvent")
	update.Name, update.Parent = "Update", remotes
	remotes.Parent = ReplicatedStorage
	request.OnServerEvent:Connect(function(player, action, target)
		if action ~= "Place" or busy[player] or os.clock() - (requests[player] or -math.huge) < 0.5 then
			return
		end
		requests[player] = os.clock()
		local _, message = place(player, target)
		notify(player, message)
	end)
	ProximityPromptService.PromptTriggered:Connect(function(triggered, player)
		if triggered.Name == PROMPT_NAME and not busy[player] then
			task.spawn(collect, player, triggered)
		end
	end)
	local function watchPlayer(player: Player)
		player:GetAttributeChangedSignal("AnglerRevision"):Connect(function()
			refreshPlayer(player)
		end)
		-- Respawning empties the Backpack, so hand the cages back.
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			if player.Character == character then
				syncTool(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		requests[player], busy[player], placedCache[player] = nil, nil, nil
	end)
	local function watchBase(base: Instance)
		if base:IsA("Model") then
			base:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
				refreshBase(base)
			end)
			refreshBase(base)
		end
	end
	CollectionService:GetInstanceAddedSignal(BASE_TAG):Connect(watchBase)
	for _, base in CollectionService:GetTagged(BASE_TAG) do
		watchBase(base)
	end
	-- Countdowns tick once a second.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, base in CollectionService:GetTagged(BASE_TAG) do
				if base:IsA("Model") and ownerOf(base) then
					local ok, failure = pcall(refreshBase, base)
					if not ok then
						warn("[MusselNets] " .. tostring(failure))
					end
				end
			end
		end
	end)
end

return MusselNetService
