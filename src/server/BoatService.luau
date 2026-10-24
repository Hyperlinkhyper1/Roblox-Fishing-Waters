-- Server-owned wallet transactions, dock permissions, and one active boat per player.
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local BoatData = require(script.Parent.BoatData)
local Rowboat = require(script.Parent.Rowboat)
local FishingBoat = require(script.Parent.FishingBoat)
local DrydockLaunch = require(script.Parent.DrydockLaunch)
local BoatLaunchCollision = require(script.Parent.BoatLaunchCollision)
local BoatCatalog = require(ReplicatedStorage.Shared.BoatCatalog)
local BoatMotion = require(ReplicatedStorage.Shared.BoatMotion)
local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Weather = require(ReplicatedStorage.Shared.Weather)
local builders = { Rowboat = Rowboat, FishingBoat = FishingBoat }

local BoatService = {}
local profiles = {}
local active = {}
local requests = {}
local spawnTimes = {}
local launching = {}
local launchPurchased
local started = false
local COMMAND_USER_ID = 2541746813 -- hyperlinkhyper
-- Studio tests use their own store; failed loads never overwrite saved data.
local studioSession = RunService:IsStudio() and game.GameId == 0
local store
if studioSession then
	-- Unpublished places cannot access DataStores. Keep test progress in this
	-- server only; never substitute defaults for a failed published save/load.
	local records = {}
	store = {
		GetAsync = function(_, key)
			return records[key]
		end,
		UpdateAsync = function(_, key, transform)
			local saved = transform(records[key])
			records[key] = saved
			return saved
		end,
	}
else
	local success, result = pcall(function()
		return DataStoreService:GetDataStore(
			if RunService:IsStudio() then "WalletAndBoats_Studio_v1" else "WalletAndBoats_v1"
		)
	end)
	if success then
		store = result
	else
		warn("[Wallet] Could not initialize saved data: " .. tostring(result))
	end
end
local feedback: RemoteEvent

local function notify(player: Player, message: string)
	if player.Parent == Players then
		feedback:FireClient(player, "Notice", message)
	end
end

local function publish(player: Player, state)
	player:SetAttribute("WalletSessionOnly", studioSession)
	player:SetAttribute("BoatDataStatus", state.status)
	player:SetAttribute("Cash", state.profile.Cash)
	for id in BoatCatalog do
		player:SetAttribute("Owns" .. id, state.profile.OwnedBoats[id] == true)
	end
	player:SetAttribute("OwnsStarterRod", state.profile.OwnedRods.StarterRod == true)
	local level, levelXP, requiredXP = BoatData.levelProgress(state.profile)
	player:SetAttribute("Level", level)
	player:SetAttribute("LevelXP", levelXP)
	player:SetAttribute("LevelXPRequired", requiredXP)

	-- The built-in player list sorts by its first stat. Keep Level primary and
	-- mirror committed profile values here alongside the gameplay attributes.
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
	end
	local levelStat = leaderstats:FindFirstChild("Level")
	if not levelStat then
		levelStat = Instance.new("IntValue")
		levelStat.Name = "Level"
		local primary = Instance.new("BoolValue")
		primary.Name, primary.Value = "IsPrimary", true
		primary.Parent = levelStat
	end
	levelStat.Value, levelStat.Parent = level, leaderstats
	local moneyStat = leaderstats:FindFirstChild("Money")
	if not moneyStat then
		moneyStat = Instance.new("IntValue")
		moneyStat.Name = "Money"
	end
	moneyStat.Value, moneyStat.Parent = state.profile.Cash, leaderstats
	leaderstats.Parent = player

	player:SetAttribute("AnglerRevision", (player:GetAttribute("AnglerRevision") or 0) + 1)
end

-- Server modules share the existing atomic store and lock; no client can submit a profile.
function BoatService.getProfile(player: Player)
	local state = profiles[player]
	return if state and state.status == "Ready" then BoatData.decode(state.profile) else nil
end

function BoatService.updateProgress(player: Player, transform): (boolean, string)
	local state = profiles[player]
	if not state or state.status ~= "Ready" then
		return false, "Your progress is still loading or unavailable."
	end
	if state.busy then
		return false, "Another change is being saved. Please try again."
	end
	state.busy = true
	local awardedAt = os.time()
	local success, saved = pcall(function()
		return store:UpdateAsync("Player_" .. player.UserId, function(raw)
			local profile = BoatData.decode(raw)
			local previous = BoatData.decode(profile)
			transform(profile)
			BoatData.trackProgress(previous, profile, awardedAt)
			return BoatData.decode(profile)
		end)
	end)
	state.busy = false
	if not success then
		warn("[Angler] Save failed for " .. player.UserId .. ": " .. tostring(saved))
		return false, "Your change could not be saved. Please try again."
	end
	if profiles[player] ~= state or player.Parent ~= Players then
		return false, "This session has ended."
	end
	state.profile = BoatData.decode(saved)
	publish(player, state)
	return true, "Saved."
end

local function loadPlayer(player: Player)
	if profiles[player] then
		return
	end
	local state = { profile = BoatData.decode(nil), status = "Loading", busy = false }
	profiles[player] = state
	publish(player, state)
	for attempt = 1, 3 do
		local success, result = pcall(function()
			return BoatData.decode(store:GetAsync("Player_" .. player.UserId))
		end)
		if profiles[player] ~= state then
			return
		end
		if success then
			state.profile, state.status = result, "Ready"
			publish(player, state)
			return
		end
		warn("[Boats] Could not load player " .. player.UserId .. ": " .. tostring(result))
		if attempt < 3 then
			task.wait(attempt)
		end
	end
	state.status = "Unavailable"
	publish(player, state)
	notify(player, "Boat data could not load. Rejoin to try again.")
end

local function nearPrompt(player: Player, prompt: ProximityPrompt): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local part = prompt.Parent
	return root ~= nil
		and root:IsA("BasePart")
		and humanoid ~= nil
		and humanoid.Health > 0
		and part ~= nil
		and part:IsA("BasePart")
		and (root.Position - part.Position).Magnitude <= prompt.MaxActivationDistance + 2
end

-- Talking and buying require being inside the hall with a clear view of the shipwright.
local function shopPrompt(player: Player): ProximityPrompt?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	for _, shop in CollectionService:GetTagged("BoatShop") do
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
		local prompt = shop:FindFirstChild("TalkToShipwrightPrompt", true)
		if not prompt or not prompt:IsA("ProximityPrompt") or not nearPrompt(player, prompt) then
			continue
		end
		local npc = prompt:FindFirstAncestorOfClass("Model")
		if not npc or not npc:FindFirstChildOfClass("Humanoid") then
			continue
		end
		local parameters = RaycastParams.new()
		parameters.FilterType = Enum.RaycastFilterType.Exclude
		parameters.FilterDescendantsInstances = { character }
		local head = character:FindFirstChild("Head")
		local eye = if head and head:IsA("BasePart") then head.Position else root.Position
		local result = workspace:Raycast(eye, prompt.Parent.Position - eye, parameters)
		if not result or result.Instance:IsDescendantOf(npc) then
			return prompt
		end
	end
	return nil
end

local function openShop(player: Player, expectedPrompt: ProximityPrompt?, boatId: string?)
	if launching[player] then
		return
	end
	local prompt = shopPrompt(player)
	if not prompt or (expectedPrompt and prompt ~= expectedPrompt) then
		return
	end
	local shop = prompt:FindFirstAncestorOfClass("Model")
	while shop and not CollectionService:HasTag(shop, "BoatShop") do
		shop = shop:FindFirstAncestorOfClass("Model")
	end
	if shop then
		feedback:FireClient(player, "OpenShop", shop, boatId or "Rowboat")
	end
end

local function readyState(player: Player)
	local state = profiles[player]
	if not state or state.status ~= "Ready" then
		notify(player, "Boat data is unavailable or still loading. Please try again shortly.")
		return nil
	end
	return state
end

-- This handler is server-only; the sender comes from TextChatCommand's TextSource.
function BoatService.setCashFromCommand(player: Player, message: string)
	if player.UserId ~= COMMAND_USER_ID then
		return
	end
	local digits = message:match("^/set%s+cash%s+(%d+)%s*$")
	local amount = digits and tonumber(digits)
	if not amount or amount < 0 or amount >= 2 ^ 53 or amount % 1 ~= 0 then
		notify(player, "Usage: /set cash <amount> (a non-negative whole number below 9007199254740992).")
		return
	end
	local state = readyState(player)
	if not state then
		return
	end
	if state.busy then
		notify(player, "Another wallet change is being saved. Please try again shortly.")
		return
	end
	state.busy = true
	local success, saved = pcall(function()
		return store:UpdateAsync("Player_" .. player.UserId, function(raw)
			local profile = BoatData.decode(raw)
			profile.Cash = amount
			return profile
		end)
	end)
	state.busy = false
	if not success then
		warn("[Wallet] Set cash failed for " .. player.UserId .. ": " .. tostring(saved))
		notify(player, "Cash could not be saved. Please try again.")
		return
	end
	local valid, profile = pcall(BoatData.decode, saved)
	if not valid or profiles[player] ~= state or player.Parent ~= Players then
		return
	end
	state.profile = profile
	publish(player, state)
	notify(player, "Cash set to $" .. tostring(profile.Cash) .. ".")
end

local function setFromCommand(player: Player, message: string)
	if player.UserId ~= COMMAND_USER_ID then
		return
	end
	local normalized = string.lower(message)
	local subject = normalized:match("^/set%s+(%S+)")
	if subject ~= "weather" then
		BoatService.setCashFromCommand(player, message)
		return
	end
	local argument = normalized:match("^/set%s+weather%s+(.+)") or ""
	argument = argument:gsub("%s+", "")
	local kinds = {}
	local selected
	for kind in Weather.Presets do
		table.insert(kinds, kind)
		if string.lower(kind) == argument then
			selected = kind
		end
	end
	table.sort(kinds)
	if argument == "list" then
		notify(player, "Weather types: " .. table.concat(kinds, ", ") .. ".")
	elseif selected then
		workspace:SetAttribute("WeatherOverride", selected)
		notify(player, "Weather set to " .. selected .. ".")
	else
		notify(player, "Usage: /set weather <type>. Use /set weather list for available types.")
	end
end

local function boatOccupied(player: Player): boolean
	local boat = active[player]
	if boat then
		for _, piece in boat.model:GetDescendants() do
			if (piece:IsA("Seat") or piece:IsA("VehicleSeat")) and piece.Occupant then
				return true
			end
		end
	end
	return false
end

local function purchase(player: Player, boatId: string?)
	local id = boatId or "Rowboat"
	local spec = BoatCatalog[id]
	if not spec then
		return
	end
	local prompt = shopPrompt(player)
	if not prompt then
		return
	end
	local state = readyState(player)
	if not state or state.busy or launching[player] then
		return
	end
	if state.profile.OwnedBoats[id] then
		notify(player, "You already own the " .. spec.Name .. ". Spawn it at your own dock.")
		return
	end
	if boatOccupied(player) then
		notify(player, "Everyone must leave your current boat before launching a new purchase.")
		return
	end
	if state.profile.Cash < spec.Price then
		notify(player, "You need $" .. spec.Price .. " for the " .. spec.Name .. ".")
		return
	end
	local shop = prompt:FindFirstAncestorOfClass("Model")
	while shop and not CollectionService:HasTag(shop, "BoatShop") do
		shop = shop:FindFirstAncestorOfClass("Model")
	end
	if not shop then
		return
	end
	local reservation, reason = DrydockLaunch.reserve(shop, player, id)
	if not reservation then
		notify(player, reason)
		return
	end
	launching[player] = reservation
	state.busy = true
	local success, saved = pcall(function()
		return store:UpdateAsync("Player_" .. player.UserId, function(raw)
			local profile = BoatData.purchase(raw, id)
			return profile
		end)
	end)
	state.busy = false
	if not success then
		launching[player] = nil
		DrydockLaunch.release(reservation)
		warn("[Boats] Purchase failed for " .. player.UserId .. ": " .. tostring(saved))
		notify(player, "The purchase could not be confirmed. Please try again.")
		return
	end
	-- Both the deduction and ownership are committed in one atomic store update.
	local valid, profile = pcall(BoatData.decode, saved)
	if not valid or profiles[player] ~= state or player.Parent ~= Players then
		launching[player] = nil
		DrydockLaunch.release(reservation)
		return
	end
	state.profile = profile
	publish(player, state)
	if profile.OwnedBoats[id] then
		shop:SetAttribute("LaunchStartedAt", workspace:GetServerTimeNow())
		feedback:FireClient(player, "LaunchStarted", shop, id)
		task.spawn(function()
			local launched, result = pcall(function()
				return DrydockLaunch.run(reservation, launchPurchased)
			end)
			DrydockLaunch.release(reservation)
			launching[player] = nil
			if player.Parent == Players then
				feedback:FireClient(player, "LaunchFinished")
				if not launched or not result then
					notify(
						player,
						"Your " .. spec.Name .. " is saved. Use your plot's boat stand if boarding was interrupted."
					)
				end
			end
			if not launched then
				warn("[Boats] Drydock launch interrupted: " .. tostring(result))
			end
		end)
	else
		launching[player] = nil
		DrydockLaunch.release(reservation)
		notify(player, "You need $" .. spec.Price .. " for the " .. spec.Name .. ".")
	end
end

-- The fishing shop shares this wallet and transaction lock. Keeping all purchases
-- in this store prevents one shop from overwriting another shop's inventory.
function BoatService.purchaseRod(player: Player): (boolean, string)
	local state = profiles[player]
	if not state or state.status ~= "Ready" then
		return false, "Your wallet is still loading or unavailable. Please try again shortly."
	end
	if state.busy then
		return false, "Another purchase is being saved. Please try again shortly."
	end
	if state.profile.OwnedRods.StarterRod then
		return true, "You already own the starter rod."
	end
	state.busy = true
	local success, saved = pcall(function()
		return store:UpdateAsync("Player_" .. player.UserId, function(raw)
			local profile = BoatData.purchaseRod(raw)
			return profile
		end)
	end)
	state.busy = false
	if not success then
		warn("[Fishing] Purchase failed for " .. player.UserId .. ": " .. tostring(saved))
		return false, "The rod purchase could not be saved. Please try again."
	end
	local valid, profile = pcall(BoatData.decode, saved)
	if not valid or profiles[player] ~= state or player.Parent ~= Players then
		return false, "The rod purchase could not be confirmed for this session."
	end
	state.profile = profile
	publish(player, state)
	if not profile.OwnedRods.StarterRod then
		return false, "You do not have enough cash for this rod."
	end
	return true, "Starter rod owned!"
end

local function removeBoat(player: Player)
	local boat = active[player]
	if boat then
		active[player] = nil
		player:SetAttribute("ActiveBoatId", nil)
		boat.model:Destroy()
	end
end

-- The player's launched boat, whose cargo hold they can reach.
function BoatService.activeBoat(player: Player): (string?, Model?)
	local boat = active[player]
	if boat and boat.model.Parent then
		return boat.model:GetAttribute("BoatId"), boat.model
	end
	return nil, nil
end

local function waterAhead(boat, direction: Vector3): boolean
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = { boat.model }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(excluded, player.Character)
		end
	end
	parameters.FilterDescendantsInstances = excluded
	parameters.IgnoreWater = false
	local position = boat.root.Position + direction * (boat.spec.Length / 2 + 2)
	local result = workspace:Raycast(
		Vector3.new(position.X, Biomes.WaterLevel + 14, position.Z),
		Vector3.new(0, -32, 0),
		parameters
	)
	return result ~= nil and result.Material == Enum.Material.Water
end

local function updateSuspension(boat)
	local mass = boat.root.AssemblyMass
	local gravity = workspace.Gravity
	-- Cancel the assembly's weight separately so soft alignment does not need
	-- a permanent height error to hold up the hull and its seated passengers.
	boat.lift.Force = Vector3.new(0, mass * gravity, 0)
	boat.float.MaxAxesForce = Vector3.new(0, mass * (gravity + 100) * 4, 0)
	boat.heading.MaxTorque = mass * (gravity + 100) * boat.spec.Length * 2
end

local function clearMotion(boat)
	for _, piece in boat.model:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.AssemblyLinearVelocity = Vector3.zero
			piece.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function setParked(boat, parked: boolean)
	if boat.parked == parked then
		return
	end
	boat.parked = parked
	if parked then
		-- A standing character is a separate, client-simulated assembly. Keeping
		-- an idle hull dynamic lets its contacts fight our server-side movers.
		-- Anchor only the hull root, leaving deck collisions and seats usable.
		boat.speed, boat.turn = 0, 0
		boat.velocity.PlaneVelocity = Vector2.zero
		clearMotion(boat)
		-- Anchor every piece, not just the root. A standing player is carried by the
		-- velocity of the part underfoot, so no deck piece may keep a stray drift.
		for _, piece in boat.model:GetDescendants() do
			if piece:IsA("BasePart") then
				piece.Anchored = true
			end
		end
		boat.model:SetAttribute("RowThrottle", 0)
		boat.model:SetAttribute("RowSteer", 0)
		-- Clients bob the anchored hull locally from this pose and swell clock.
		boat.model:SetAttribute("ParkedFrame", boat.root.CFrame)
		boat.model:SetAttribute("ParkedAt", workspace:GetServerTimeNow())
	else
		-- Release from the pose clients have bobbed it to, so riders see no snap.
		local rest, parkedAt = boat.model:GetAttribute("ParkedFrame"), boat.model:GetAttribute("ParkedAt")
		if rest and parkedAt then
			boat.model:PivotTo(
				Weather.parkedOffset(rest, parkedAt, workspace:GetServerTimeNow()) * boat.model:GetPivot()
			)
		end
		for _, piece in boat.model:GetDescendants() do
			if piece:IsA("BasePart") then
				piece.Anchored = false
			end
		end
		-- Anchoring resets network ownership. Reapply it after releasing the
		-- hull, before enabling forces, so boarding cannot change its simulator.
		boat.root:SetNetworkOwner(nil)
	end
	boat.float.Enabled = not parked
	boat.lift.Enabled = not parked
	boat.heading.Enabled = not parked
	boat.velocity.Enabled = not parked
	boat.model:SetAttribute("Parked", parked)
end

local function launch(player: Player, frame: CFrame, existing: Model?, boatId: string?)
	local id = boatId or (existing and existing:GetAttribute("BoatId")) or "Rowboat"
	local spec = BoatCatalog[id]
	local model = existing or builders[id].build(frame, false)
	model.Name = id .. "_" .. player.UserId
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("BoatId", id)
	local root = model.PrimaryPart :: BasePart
	local seat = model:FindFirstChild(spec.DriverSeat, true) :: VehicleSeat
	model:SetAttribute("DisplayOnly", nil)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	if existing then
		BoatLaunchCollision.protect(model, 10)
		for _, piece in model:GetDescendants() do
			if piece:IsA("BasePart") then
				piece.Anchored = false
				local collide = piece:GetAttribute("PreviewCanCollide")
				if collide ~= nil then
					piece.CanCollide = collide
				end
				piece:SetAttribute("PreviewCanCollide", nil)
				if piece:IsA("Seat") or piece:IsA("VehicleSeat") then
					piece.Disabled = false
					piece.CanTouch = true
				end
			end
		end
		seat.Disabled = false
		seat.CanTouch = true
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "BoatMotion"
	attachment.Parent = root

	local float = Instance.new("AlignPosition")
	float.Name = "Waterline"
	float.Mode = Enum.PositionAlignmentMode.OneAttachment
	float.Attachment0 = attachment
	float.ApplyAtCenterOfMass = true
	float.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	float.ForceRelativeTo = Enum.ActuatorRelativeTo.World
	float.Position = root.Position
	-- Rigid alignment ignores the per-axis limits and can fight horizontal
	-- propulsion and deck contacts. Only the bounded Y suspension lifts boats.
	float.RigidityEnabled = false
	float.Responsiveness = 20
	float.MaxVelocity = 6
	float.Parent = root

	local lift = Instance.new("VectorForce")
	lift.Name = "WeightSupport"
	lift.Attachment0 = attachment
	lift.RelativeTo = Enum.ActuatorRelativeTo.World
	lift.ApplyAtCenterOfMass = true
	lift.Parent = root

	local heading = Instance.new("AlignOrientation")
	heading.Name = "UprightHeading"
	heading.Mode = Enum.OrientationAlignmentMode.OneAttachment
	heading.Attachment0 = attachment
	heading.CFrame = root.CFrame.Rotation
	heading.MaxAngularVelocity = 2
	heading.RigidityEnabled = false
	heading.Responsiveness = 10
	heading.Parent = root

	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "Rowing"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	velocity.PlaneVelocity = Vector2.zero
	-- Acceleration is limited by the velocity ramp, not by starving the solver
	-- of the force it needs to overcome terrain-water drag and passengers.
	velocity.ForceLimitsEnabled = false
	velocity.Parent = root

	model.Parent = workspace:FindFirstChild("PlayerBoats")
	root:SetNetworkOwner(nil)
	local _, yaw = root.CFrame:ToOrientation()
	local boat = {
		spec = spec,
		model = model,
		root = root,
		seat = seat,
		heading = heading,
		float = float,
		lift = lift,
		velocity = velocity,
		-- Each hull's physical root is below its waterline. Preserve that local
		-- offset when the hull tilts, so its waterline follows the sampled surface.
		waterlineOffset = frame:PointToObjectSpace(root.Position),
		yaw = yaw,
		speed = 0,
		throttle = 0,
		steer = 0,
		lastInput = 0,
		lastWaterCheck = 0,
		clearWater = true,
		launchGraceUntil = if existing then os.clock() + 10 else 0,
	}
	updateSuspension(boat)
	setParked(boat, true)
	active[player] = boat
	player:SetAttribute("ActiveBoatId", id)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		boat.throttle, boat.steer = 0, 0
		local humanoid = seat.Occupant
		if humanoid and Players:GetPlayerFromCharacter(humanoid.Parent) ~= player then
			task.defer(function()
				if humanoid.Parent then
					humanoid.Sit = false
				end
			end)
		end
	end)
	return boat
end

launchPurchased = function(player: Player, frame: CFrame, model: Model)
	removeBoat(player)
	local boat = launch(player, frame, model)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then
		return false
	end
	-- Request streaming while the launch camera remains active. Failure to stream
	-- is bounded and does not undo an already committed purchase.
	pcall(function()
		player:RequestStreamAroundAsync(boat.root.Position, 3)
	end)
	for _ = 1, 8 do
		if player.Character ~= character or humanoid.Health <= 0 or not boat.model.Parent then
			return false
		end
		character:PivotTo(boat.seat.CFrame + Vector3.new(0, 3, 0))
		root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
		boat.seat:Sit(humanoid)
		task.wait(0.15)
		if boat.seat.Occupant == humanoid then
			notify(player, "Your " .. boat.spec.Name .. " is afloat! Use movement controls to sail to your plot.")
			return true
		end
	end
	notify(player, "Your " .. boat.spec.Name .. " is afloat beside the slipway. Sit in the driver's seat to sail.")
	return true
end

local function dockBase(player: Player, prompt: ProximityPrompt): Model?
	if not prompt:IsDescendantOf(workspace) or not nearPrompt(player, prompt) then
		return nil
	end
	local base = prompt:FindFirstAncestorOfClass("Model")
	while base and not CollectionService:HasTag(base, "PlayerBase") do
		base = base:FindFirstAncestorOfClass("Model")
	end
	if
		not base
		or base:GetAttribute("OwnerUserId") ~= player.UserId
		or base:GetAttribute("BaseId") ~= player:GetAttribute("BaseId")
	then
		notify(player, "You can only spawn boats at your own dock.")
		return nil
	end
	return base
end

local function openDock(player: Player, prompt: ProximityPrompt)
	local base = dockBase(player, prompt)
	if base then
		feedback:FireClient(player, "OpenDock", base)
	end
end

local function spawnBoat(player: Player, prompt: ProximityPrompt, boatId: string?)
	local id = boatId or "Rowboat"
	local spec = BoatCatalog[id]
	if not spec then
		return
	end
	if launching[player] then
		notify(player, "Your boat is being lowered at the drydock. Please wait.")
		return
	end
	local base = dockBase(player, prompt)
	if not base then
		return
	end
	local state = readyState(player)
	if not state then
		return
	end
	if not state.profile.OwnedBoats[id] then
		notify(player, "Buy the " .. spec.Name .. " at the plaza drydock first.")
		return
	end
	if os.clock() - (spawnTimes[player] or -math.huge) < 4 then
		return
	end
	local previous = active[player]
	if boatOccupied(player) then
		notify(player, "Everyone must leave your boat before spawning another one.")
		return
	end
	local marker = base:FindFirstChild("BoatSpawn")
	if not marker or not marker:IsA("BasePart") then
		return
	end
	-- Keep the stern clear of the dock when a larger hull uses an older marker.
	local extraLength = math.max(0, (spec.Length - BoatCatalog.Rowboat.Length) / 2)
	local spawnFrame = marker.CFrame + marker.CFrame.LookVector * extraLength
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = if previous then { previous.model, marker } else { marker }
	local bounds = Vector3.new(math.max(11, spec.Beam + 2), 16, spec.Length + 1)
	for _, part in workspace:GetPartBoundsInBox(spawnFrame + Vector3.new(0, 6, 0), bounds, overlap) do
		if part.CanCollide then
			notify(player, "The launch space is blocked. Clear the water in front of your dock.")
			return
		end
	end
	spawnTimes[player] = os.clock()
	removeBoat(player)
	launch(player, spawnFrame, nil, id)
	notify(player, spec.Name .. " launched. Jump aboard and sit in the driver's seat to sail.")
end

function BoatService.start()
	if started then
		return
	end
	started = true
	BoatLaunchCollision.start()
	local boats = Instance.new("Folder")
	boats.Name = "PlayerBoats"
	boats.Parent = workspace
	local remotes = Instance.new("Folder")
	remotes.Name = "Boating"
	remotes.Parent = ReplicatedStorage
	local request = Instance.new("RemoteEvent")
	request.Name = "Request"
	request.Parent = remotes
	feedback = Instance.new("RemoteEvent")
	feedback.Name = "Feedback"
	feedback.Parent = remotes

	local setCommand = Instance.new("TextChatCommand")
	setCommand.Name = "SetCommand"
	setCommand.PrimaryAlias = "/set"
	setCommand.AutocompleteVisible = false
	setCommand.Triggered:Connect(function(source, message)
		local player = source and Players:GetPlayerByUserId(source.UserId)
		if player then
			setFromCommand(player, message)
		end
	end)
	setCommand.Parent = TextChatService

	request.OnServerEvent:Connect(function(player, action, throttle, steer)
		if action == "Row" then
			local boat = active[player]
			if not boat or not boat.seat.Occupant or boat.seat.Occupant.Parent ~= player.Character then
				return
			end
			if
				type(throttle) ~= "number"
				or type(steer) ~= "number"
				or throttle ~= throttle
				or steer ~= steer
				or math.abs(throttle) > 1
				or math.abs(steer) > 1
			then
				return
			end
			if os.clock() - boat.lastInput < 0.06 then
				return
			end
			boat.throttle, boat.steer, boat.lastInput = throttle, steer, os.clock()
		elseif action == "BrowseRowboat" then
			openShop(player)
		elseif action == "BrowseBoat" then
			if type(throttle) == "string" and BoatCatalog[throttle] then
				openShop(player, nil, throttle)
			end
		elseif action == "PurchaseRowboat" or action == "PurchaseBoat" then
			local id = if action == "PurchaseRowboat" then "Rowboat" else throttle
			if type(id) ~= "string" or not BoatCatalog[id] then
				return
			end
			if os.clock() - (requests[player] or -math.huge) < 1 then
				return
			end
			requests[player] = os.clock()
			purchase(player, id)
		elseif action == "SpawnBoat" then
			if type(throttle) ~= "string" or not BoatCatalog[throttle] then
				return
			end
			for _, base in CollectionService:GetTagged("PlayerBase") do
				if base:GetAttribute("OwnerUserId") == player.UserId then
					local prompt = base:FindFirstChild("SpawnRowboatPrompt", true)
					if prompt and prompt:IsA("ProximityPrompt") then
						spawnBoat(player, prompt, throttle)
					end
					break
				end
			end
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name == "TalkToShipwrightPrompt" then
			openShop(player, prompt)
		elseif prompt.Name == "SpawnRowboatPrompt" then
			openDock(player, prompt)
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		local serverTime = workspace:GetServerTimeNow()
		for player, boat in active do
			if not boat.model.Parent then
				active[player] = nil
				player:SetAttribute("ActiveBoatId", nil)
				continue
			end
			local rowing = boat.seat.Occupant
				and boat.seat.Occupant.Parent == player.Character
				and os.clock() - boat.lastInput < 0.5
			local throttle, steer = if rowing then boat.throttle else 0, if rowing then boat.steer else 0
			local wantsMotion = throttle ~= 0 or math.abs(steer) >= 0.08
			if boat.parked then
				if not wantsMotion then
					-- Anchored assemblies have infinite mass. Do not sample their
					-- mass or run wave/drive corrections while people use the deck.
					local root = boat.root
					if root.AssemblyLinearVelocity ~= Vector3.zero or root.AssemblyAngularVelocity ~= Vector3.zero then
						clearMotion(boat)
					end
					continue
				end
				setParked(boat, false)
			end
			-- Integrate the speed command across frames; water drag and solver lag
			-- must not restart the acceleration ramp at every physics step.
			local speed, turn = BoatMotion.step(boat.speed, boat.turn or 0, throttle, steer, boat.spec, dt)
			if not wantsMotion and speed == 0 and turn == 0 then
				-- Preserve normal coasting and steering decay before holding still.
				setParked(boat, true)
				continue
			end
			boat.turn = turn
			-- Like a real boat (or car), reversing mirrors the steering direction.
			boat.yaw -= turn * (if speed < 0 then -1 else 1) * math.min(dt, 0.1)
			-- Seat welds change assembly mass when passengers board or leave.
			updateSuspension(boat)
			local wave = Weather.sample(boat.root.Position, serverTime)
			local flatHeading = CFrame.Angles(0, boat.yaw, 0)
			-- Project the chosen heading onto the wave plane. Sampling a shared
			-- normal keeps pitch and roll correct at every heading, including
			-- when the same hull moves between the sheltered lake and open sea.
			local normal = wave.normal
			local forward = flatHeading.LookVector
			forward = (forward - normal * forward:Dot(normal)).Unit
			local right = forward:Cross(normal).Unit
			local surfaceFrame = CFrame.fromMatrix(Vector3.zero, right, normal, -forward)
			boat.heading.CFrame = surfaceFrame
			local rootOffset = surfaceFrame:VectorToWorldSpace(boat.waterlineOffset)
			local surfaceHeight = Biomes.WaterLevel + wave.height
			local floorHeight = boat.model:GetAttribute("DryFloorHeight")
			if floorHeight then
				-- The terrain swimming surface stays flat while the boat follows swells.
				-- Keep even the lowest tilted corner of the sole above its ripples.
				local lowestFloor = floorHeight * normal.Y
					- math.abs(right.Y) * boat.model:GetAttribute("DryFloorHalfBeam")
					- math.abs(forward.Y) * boat.model:GetAttribute("DryFloorHalfLength")
				surfaceHeight = math.max(surfaceHeight, Biomes.WaterLevel + 0.35 - lowestFloor)
			end
			boat.float.Position =
				Vector3.new(boat.root.Position.X, surfaceHeight + rootOffset.Y, boat.root.Position.Z)
			local direction = flatHeading.LookVector * (if speed < 0 then -1 else 1)
			if os.clock() < boat.launchGraceUntil then
				boat.clearWater = true
			elseif (math.abs(speed) > 0.1 or throttle ~= 0) and os.clock() - boat.lastWaterCheck > 0.15 then
				boat.clearWater, boat.lastWaterCheck = waterAhead(boat, direction), os.clock()
			end
			if not boat.clearWater then
				speed = 0
			end
			boat.speed = speed
			-- Replicated intent drives the cosmetic stroke on every viewing client.
			if boat.model:GetAttribute("RowThrottle") ~= throttle then
				boat.model:SetAttribute("RowThrottle", throttle)
			end
			if boat.model:GetAttribute("RowSteer") ~= steer then
				boat.model:SetAttribute("RowSteer", steer)
			end
			local movement = flatHeading.LookVector * speed
			boat.velocity.PlaneVelocity = Vector2.new(movement.X, movement.Z)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		removeBoat(player)
		profiles[player], requests[player], spawnTimes[player] = nil, nil, nil
	end)
	Players.PlayerAdded:Connect(loadPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end
end

return BoatService
