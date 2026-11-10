-- Draws the townsfolk the server plans (Shared.Pedestrians, PedestrianService).
--
-- Every pedestrian wears a real Roblox avatar: the server publishes a handful of
-- HumanoidDescriptions from real players (ReplicatedStorage.PedestrianAvatars),
-- this client builds one template rig per description and clones it per person.
-- Rigs are local, anchored at the root and non-colliding, moved from the trip and
-- the server clock, so the server replicates nothing per frame. Motion updates
-- drop with distance from the camera:
--   Near  (< 70 studs): stock Roblox walk and idle animations, every frame.
--   Mid   (< 150):      animations stopped (standing pose), 8 updates a second.
--   Far   (< 280):      same, 3 updates a second.
--   Past that, or out of sight in a shop: not drawn and not updated at all.
-- If no avatar could be loaded at all, a two-block stand-in is drawn instead.
-- All moves of a frame go out in one workspace:BulkMoveTo call.
-- Only near avatars cast shadows (a moving caster redraws part of the sun's shadow map),
-- avatars come without layered clothing (Shared.AvatarLite), and a rig hidden for a few
-- seconds goes back to a small per-avatar pool, so memory follows how many are on screen
-- rather than how many people walk the island.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Pedestrians = require(ReplicatedStorage.Shared.Pedestrians)
local AvatarLite = require(ReplicatedStorage.Shared.AvatarLite)

-- Names this module's per-frame work in the MicroProfiler (otherwise it is all "Script_Client").
local function profiled<A...>(label: string, callback: (A...) -> ()): (A...) -> ()
	if not debug.profilebegin then
		return callback -- test runners without the MicroProfiler API
	end
	return function(...: A...)
		debug.profilebegin(label)
		callback(...)
		debug.profileend()
	end
end

local PedestriansClient = {}

local TIERS = Pedestrians.TIERS
local HIDDEN = Pedestrians.HIDDEN
local HIDDEN_CHECK = 0.5 -- how often an undrawn pedestrian is looked at again
local RELEASE_SECONDS = 6 -- an avatar hidden this long goes back to the pool
local POOL_PER_SLOT = 3 -- spare rigs kept per avatar; more are destroyed
local AREA_REACH = 165 * 1.5 + TIERS[#TIERS].exit
-- Roblox's stock R15 animations (the default Animate script's walk and idle)
local WALK_ANIMATION = "rbxassetid://913402848"
local IDLE_ANIMATION = "rbxassetid://507766388"
local WALK_ANIM_SPEED = 6.4 -- studs a second the stock walk is authored for at height scale 1

local SKINS = {
	Color3.fromRGB(255, 219, 172),
	Color3.fromRGB(241, 194, 125),
	Color3.fromRGB(224, 172, 105),
	Color3.fromRGB(198, 134, 66),
	Color3.fromRGB(141, 85, 36),
	Color3.fromRGB(92, 58, 36),
}
local SHIRTS = {
	Color3.fromRGB(236, 236, 228),
	Color3.fromRGB(40, 92, 160),
	Color3.fromRGB(180, 52, 44),
	Color3.fromRGB(56, 120, 70),
	Color3.fromRGB(230, 180, 60),
	Color3.fromRGB(110, 168, 196),
	Color3.fromRGB(60, 60, 66),
	Color3.fromRGB(150, 110, 170),
}
local BAGS = {
	Color3.fromRGB(176, 70, 52), -- Tide & Tackle
	Color3.fromRGB(60, 98, 130), -- Harbour Home
	Color3.fromRGB(222, 206, 170),
	Color3.fromRGB(70, 120, 66),
	Color3.fromRGB(214, 160, 50),
}

type Rig = {
	model: Model,
	root: BasePart, -- the one part BulkMoveTo moves; everything else hangs off it
	lift: number, -- root height above the feet
	fade: { BasePart | Decal },
	shown: boolean,
	alpha: number,
	-- Avatar rigs only
	walk: AnimationTrack?,
	idle: AnimationTrack?,
	mode: string, -- "still", "idle" or "walk"
	heightScale: number,
	bag: BasePart?,
	slot: number?, -- avatar template it was cloned from (pool key)
	shadows: boolean,
}

type Person = {
	config: Configuration,
	seed: number,
	trip: Pedestrians.Trip?,
	tier: number,
	avatar: Rig?,
	standIn: Rig?,
	nextUpdate: number,
	sample: Pedestrians.Sample,
	yaw: number,
	connection: RBXScriptConnection,
	shopConnection: RBXScriptConnection,
	center: Vector3?,
	away: boolean,
	hiddenAt: number?,
}

local started = false
local container: Folder
local people: { [Configuration]: Person } = {}
local nearCount = 0
local moveParts: { BasePart } = {}
local moveFrames: { CFrame } = {}

-- Avatar templates by slot: a Model once built, false if it failed to build.
local templates: { [number]: Model | false } = {}
-- Released avatar rigs by template slot, unparented and ready to reuse.
local pool: { [number]: { Rig } } = {}
local building: { [number]: boolean } = {}
local avatarFolder: Instance? = nil

local function prepareTemplate(model: Model): Model?
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid then
		model:Destroy()
		return nil
	end
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			-- Only the root is anchored, so Motor6Ds and accessory welds still pose the rest
			item.Anchored = item == root
			item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
			item.Massless = true
			-- Off by default; near-tier rigs turn it back on (setShadows)
			item.CastShadow = false
		elseif item:IsA("Script") or item:IsA("LocalScript") or item:IsA("Sound") then
			item:Destroy()
		end
	end
	root.Transparency = 1
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	-- No physics states to run: the rig is placed, never simulated
	humanoid.EvaluateStateMachine = false
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end
	model.PrimaryPart = root
	return model
end

local function buildTemplate(slot: number)
	if templates[slot] ~= nil or building[slot] then
		return
	end
	local description = avatarFolder and avatarFolder:FindFirstChild(tostring(slot))
	if not description or not description:IsA("HumanoidDescription") then
		return -- not published yet; asked again on a later update
	end
	building[slot] = true
	task.spawn(function()
		-- A local copy without layered clothing, even if the server published one with it.
		local lite = AvatarLite.strip(description:Clone())
		local ok, model =
			pcall(Players.CreateHumanoidModelFromDescriptionAsync, Players, lite, Enum.HumanoidRigType.R15)
		lite:Destroy()
		local prepared = if ok and model then prepareTemplate(model) else nil
		templates[slot] = prepared or false
		building[slot] = nil
		if not ok then
			warn("[Pedestrians] Avatar " .. slot .. " failed: " .. tostring(model))
		end
	end)
end

-- The person's own avatar (and its slot), or any built one if theirs failed. Nil while still loading.
local function templateFor(seed: number): (Model?, number?)
	local slot = Pedestrians.avatarSlot(seed)
	local own = templates[slot]
	if own then
		return own, slot
	end
	if own == nil then
		buildTemplate(slot)
		-- A later description must not permanently give this person another
		-- avatar before their own loads: the physical visitor uses this exact slot.
		return nil
	end
	for offset = 1, Pedestrians.AVATAR_COUNT - 1 do
		local otherSlot = (slot + offset - 1) % Pedestrians.AVATAR_COUNT + 1
		local other = templates[otherSlot]
		if other then
			return other, otherSlot
		end
	end
	return nil, nil
end

local function anyTemplateCould(): boolean
	-- True while an avatar might still turn up, so the block stand-in isn't flashed during loading
	if not avatarFolder then
		return true
	end
	for slot = 1, Pedestrians.AVATAR_COUNT do
		if templates[slot] ~= false then
			return true
		end
	end
	return false
end

local function loadTrack(animator: Animator, id: string, priority: Enum.AnimationPriority): AnimationTrack
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local track = animator:LoadAnimation(animation)
	track.Priority = priority
	track.Looped = true
	return track
end

local function buildAvatar(template: Model, slot: number?): Rig
	local model = template:Clone()
	model.Name = "Townsperson"
	local root = model.PrimaryPart :: BasePart
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local fade: { BasePart | Decal } = {}
	for _, item in model:GetDescendants() do
		if (item:IsA("BasePart") and item ~= root) or item:IsA("Decal") then
			table.insert(fade, item)
		end
	end
	local rig: Rig = {
		model = model,
		root = root,
		lift = humanoid.HipHeight + root.Size.Y / 2,
		fade = fade,
		shown = false,
		alpha = 0,
		walk = nil,
		idle = nil,
		mode = "still",
		heightScale = math.max(humanoid.HipHeight / 2, 0.5),
		bag = nil,
		slot = slot,
		shadows = false,
	}
	-- A shopping bag held in the right hand, parented only while carrying one
	local hand = model:FindFirstChild("RightHand")
	if hand and hand:IsA("BasePart") then
		local bag = Instance.new("Part")
		bag.Name = "ShoppingBag"
		bag.Size = Vector3.new(0.95, 1.05, 0.45) * rig.heightScale
		bag.Material = Enum.Material.SmoothPlastic
		bag.Anchored, bag.CanCollide, bag.CanTouch, bag.CanQuery = false, false, false, false
		bag.Massless, bag.CastShadow = true, false
		local weld = Instance.new("Weld")
		weld.Part0, weld.Part1 = hand, bag
		weld.C0 = CFrame.new(0, -hand.Size.Y / 2 - bag.Size.Y / 2 - 0.05, 0)
		weld.Parent = bag
		rig.bag = bag
	end
	return rig
end

local function buildStandIn(seed: number): Rig
	local random = Random.new(seed)
	local scale = random:NextNumber(0.9, 1.08)
	local model = Instance.new("Model")
	model.Name = "Townsperson"
	local function block(size: Vector3, color: Color3, shape: Enum.PartType?): BasePart
		local part = Instance.new("Part")
		part.Size = size * scale
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = false, false, false, false
		part.Massless, part.CastShadow = true, false
		if shape then
			part.Shape = shape
		end
		part.Parent = model
		return part
	end
	local body = block(Vector3.new(2, 4.1, 1), SHIRTS[random:NextInteger(1, #SHIRTS)])
	body.Anchored = true
	local head = block(Vector3.one * 1.25, SKINS[random:NextInteger(1, #SKINS)], Enum.PartType.Ball)
	head.CFrame = body.CFrame * CFrame.new(0, 2.73 * scale, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1, weld.Parent = body, head, head
	return {
		model = model,
		root = body,
		lift = 2.05 * scale,
		fade = { body, head },
		shown = false,
		alpha = 0,
		mode = "still",
		heightScale = scale,
		shadows = false,
	}
end

local function show(rig: Rig?, visible: boolean)
	if rig and rig.shown ~= visible then
		rig.shown = visible
		rig.model.Parent = if visible then container else nil
	end
end

local function setShadows(rig: Rig, on: boolean)
	if rig.shadows == on then
		return
	end
	rig.shadows = on
	for _, item in rig.fade do
		if item:IsA("BasePart") then
			item.CastShadow = on
		end
	end
end

local function setAlpha(rig: Rig, alpha: number)
	if math.abs(rig.alpha - alpha) < 0.04 and not (alpha == 0 and rig.alpha ~= 0) then
		return
	end
	rig.alpha = alpha
	for _, item in rig.fade do
		item.Transparency = alpha
	end
	if rig.bag then
		rig.bag.Transparency = alpha
	end
end

-- "walk", "idle" or "still" (no animation: the default standing pose).
local function setMode(rig: Rig, mode: string)
	if rig.mode == mode then
		return
	end
	rig.mode = mode
	if mode ~= "still" and not rig.walk then
		local humanoid = rig.model:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			return
		end
		rig.walk = loadTrack(animator, WALK_ANIMATION, Enum.AnimationPriority.Movement)
		rig.idle = loadTrack(animator, IDLE_ANIMATION, Enum.AnimationPriority.Idle)
	end
	local walk, idle = rig.walk, rig.idle
	if not walk or not idle then
		return
	end
	if mode == "walk" then
		if not walk.IsPlaying then
			walk:Play(0.2)
		end
		if idle.IsPlaying then
			idle:Stop(0.2)
		end
	elseif mode == "idle" then
		if not idle.IsPlaying then
			idle:Play(0.25)
		end
		if walk.IsPlaying then
			walk:Stop(0.25)
		end
	else
		walk:Stop(0)
		idle:Stop(0)
	end
end

local function queue(part: BasePart, frame: CFrame)
	table.insert(moveParts, part)
	table.insert(moveFrames, frame)
end

local function hideAll(person: Person)
	show(person.avatar, false)
	show(person.standIn, false)
	if person.avatar then
		setMode(person.avatar, "still")
	end
	if person.tier == 1 then
		nearCount -= 1
	end
	person.tier = HIDDEN
end

local function shortestAngle(from: number, to: number): number
	return (to - from + math.pi) % (math.pi * 2) - math.pi
end

-- The rig to draw: the avatar once one exists, the block stand-in only if none ever will.
local function rigFor(person: Person): Rig?
	if person.avatar then
		return person.avatar
	end
	local template, slot = templateFor(person.seed)
	if template then
		local spare = slot and pool[slot]
		person.avatar = if spare and #spare > 0 then table.remove(spare) else buildAvatar(template, slot)
		if person.standIn then
			person.standIn.model:Destroy()
			person.standIn = nil
		end
		return person.avatar
	end
	if anyTemplateCould() then
		return nil
	end
	if not person.standIn then
		person.standIn = buildStandIn(person.seed)
	end
	return person.standIn
end

local function update(person: Person, now: number, dt: number, camera: Vector3)
	local trip = person.trip
	if not trip or person.config:GetAttribute("InShop") then
		hideAll(person)
		person.nextUpdate = now + HIDDEN_CHECK
		return
	end
	local sample = Pedestrians.sample(trip, now, person.sample)
	local position = Vector3.new(sample.x, sample.y, sample.z)
	local tier = Pedestrians.tierFor((position - camera).Magnitude, person.tier)
	if sample.alpha >= 0.999 then
		tier = HIDDEN
	end
	-- Only so many animated avatars at once: later arrivals stand still like the mid tier
	if tier == 1 and person.tier ~= 1 and nearCount >= Pedestrians.NEAR_CAP then
		tier = 2
	end
	local rig = if tier == HIDDEN then nil else rigFor(person)
	if not rig then
		tier = HIDDEN
	end
	if tier ~= person.tier then
		if person.tier == 1 then
			nearCount -= 1
		end
		if tier == 1 then
			nearCount += 1
			-- Arrive facing the right way instead of spinning round
			person.yaw = sample.yaw
		end
		person.tier = tier
	end
	if tier == HIDDEN or not rig then
		show(person.avatar, false)
		show(person.standIn, false)
		if person.avatar then
			setMode(person.avatar, "still")
		end
		-- Still waiting on an avatar to load: look again sooner
		person.nextUpdate = now + (if rig then HIDDEN_CHECK else HIDDEN_CHECK / 2)
		return
	end
	-- Coarse tiers don't fade: they just appear and vanish halfway through
	local visible = tier == 1 or sample.alpha <= 0.5
	show(rig, visible)
	if not visible then
		person.nextUpdate = now + TIERS[tier].interval
		return
	end
	local yaw = sample.yaw
	setShadows(rig, tier == 1)
	if tier == 1 then
		person.yaw += shortestAngle(person.yaw, sample.yaw) * math.min(dt * 9, 1)
		yaw = person.yaw
		setAlpha(rig, sample.alpha)
	else
		person.yaw = sample.yaw
		setAlpha(rig, 0)
	end
	if rig == person.avatar then
		if tier == 1 then
			setMode(rig, if sample.moving then "walk" else "idle")
			if rig.mode == "walk" and rig.walk then
				local speed = trip.speed / (WALK_ANIM_SPEED * rig.heightScale)
				if math.abs(rig.walk.Speed - speed) > 0.02 then
					rig.walk:AdjustSpeed(speed)
				end
			end
		else
			setMode(rig, "still")
		end
		local bag = rig.bag
		if bag then
			local carrying = trip.bag > 0 and tier == 1
			if carrying then
				bag.Color = BAGS[math.clamp(trip.bag, 1, #BAGS)]
				if bag.Parent ~= rig.model then
					bag.Parent = rig.model
				end
			elseif bag.Parent then
				bag.Parent = nil
			end
		end
	end
	queue(rig.root, CFrame.new(position + Vector3.new(0, rig.lift, 0)) * CFrame.Angles(0, yaw, 0))
	person.nextUpdate = now + TIERS[tier].interval
end

local function destroy(person: Person)
	person.connection:Disconnect()
	person.shopConnection:Disconnect()
	if person.tier == 1 then
		nearCount -= 1
	end
	if person.avatar then
		if person.avatar.bag then
			person.avatar.bag:Destroy()
		end
		person.avatar.model:Destroy()
	end
	if person.standIn then
		person.standIn.model:Destroy()
	end
end

local function track(config: Instance)
	if not config:IsA("Configuration") or people[config] then
		return
	end
	local seed = config:GetAttribute("Look")
	local person: Person = {
		config = config,
		seed = if type(seed) == "number" then seed else 1,
		trip = nil,
		tier = HIDDEN,
		avatar = nil,
		standIn = nil,
		nextUpdate = 0,
		sample = { x = 0, y = 0, z = 0, yaw = 0, moving = false, stride = 0, alpha = 0 },
		yaw = 0,
		connection = nil :: any,
		shopConnection = nil :: any,
		center = config:GetAttribute("AreaCenter") :: Vector3?,
		away = false,
		hiddenAt = nil,
	}
	local function refresh()
		person.trip = Pedestrians.decode(config:GetAttribute("Trip") :: string)
		if person.trip then
			local p = person.trip.points
			local n = #p
			-- The culling centre follows each leg of an island-wide journey.
			person.center = Vector3.new((p[1] + p[n - 2]) / 2, (p[2] + p[n - 1]) / 2, (p[3] + p[n]) / 2)
		end
		person.nextUpdate = 0
	end
	person.connection = config:GetAttributeChangedSignal("Trip"):Connect(refresh)
	person.shopConnection = config:GetAttributeChangedSignal("InShop"):Connect(function()
		person.nextUpdate = 0
		if config:GetAttribute("InShop") then hideAll(person) end
	end)
	refresh()
	people[config] = person
end

-- Hands a hidden person's avatar back to the pool (or destroys it if the pool is full).
local function release(person: Person)
	local rig = person.avatar
	if not rig or rig.shown then
		return
	end
	person.avatar = nil
	person.hiddenAt = nil
	setMode(rig, "still")
	setShadows(rig, false)
	if rig.bag then
		rig.bag.Parent = nil
	end
	local slot = rig.slot
	local spare = slot and (pool[slot] or {})
	if slot and spare and #spare < POOL_PER_SLOT then
		pool[slot] = spare
		table.insert(spare, rig)
	else
		if rig.bag then
			rig.bag:Destroy()
		end
		rig.model:Destroy()
	end
end

local function untrack(config: Instance)
	local person = people[config :: Configuration]
	if person then
		people[config :: Configuration] = nil
		destroy(person)
	end
end

function PedestriansClient.start()
	if started then
		return
	end
	started = true
	container = Instance.new("Folder")
	container.Name = "Townsfolk"
	container.Parent = workspace
	local folder = ReplicatedStorage:WaitForChild(Pedestrians.FOLDER)
	folder.ChildAdded:Connect(track)
	folder.ChildRemoved:Connect(untrack)
	for _, config in folder:GetChildren() do
		track(config)
	end

	-- Build the avatar templates as their descriptions arrive, before anyone walks close
	task.spawn(function()
		local avatars = ReplicatedStorage:WaitForChild(Pedestrians.AVATAR_FOLDER, 120)
		if not avatars then
			return
		end
		avatarFolder = avatars
		local function onAdded(child: Instance)
			local slot = tonumber(child.Name)
			if slot then
				buildTemplate(slot)
			end
		end
		avatars.ChildAdded:Connect(onAdded)
		for _, child in avatars:GetChildren() do
			onAdded(child)
		end
	end)

	local townCenter: Vector3? = nil
	local awayUntil = 0
	RunService.Heartbeat:Connect(profiled("Pedestrians", function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local now = workspace:GetServerTimeNow()
		local eye = camera.CFrame.Position
		-- Cull whole neighbourhoods twice a second, including shops outside the plaza.
		if now >= awayUntil then
			awayUntil = now + 0.5
			local saved = folder:GetAttribute("Center")
			townCenter = if typeof(saved) == "Vector3" then saved else townCenter
			for _, person in people do
				local middle = person.center or townCenter
				person.away = middle == nil or (eye - (middle :: Vector3)).Magnitude > AREA_REACH
				if person.away then
					hideAll(person)
				end
				local avatar = person.avatar
				if avatar and not avatar.shown then
					if not person.hiddenAt then
						person.hiddenAt = now
					elseif now - (person.hiddenAt :: number) >= RELEASE_SECONDS then
						release(person)
					end
				else
					person.hiddenAt = nil
				end
			end
		end
		for _, person in people do
			if not person.away and now >= person.nextUpdate then
				update(person, now, dt, eye)
			end
		end
		if #moveParts > 0 then
			workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
			table.clear(moveParts)
			table.clear(moveFrames)
		end
	end))
end

return PedestriansClient
