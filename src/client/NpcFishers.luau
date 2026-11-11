-- Draws the lake's NPC fishers (Shared.NpcFishers, NpcFisherService).
--
-- The server publishes one boat template and each fisher's route; this client clones the boat
-- and a townsperson avatar locally and poses them from the shared timeline and the server
-- clock, so the server replicates nothing per frame and every client sees the same boat in the
-- same place. Kept cheap:
--   * The boat's parts stay welded to its anchored root, so a whole hull moves with one CFrame
--     (and the angler's limbs follow their anchored root through the rig's joints). All moves
--     of a frame go out in one workspace:BulkMoveTo call.
--   * Near the camera (< NEAR) the angler animates, casts and lands fish every frame. Farther
--     out the boat steps every MID_STRIDE frames with the angler holding still and no line.
--     Past DRAW_DISTANCE, or while the fisher is off duty, nothing is drawn or updated.
--   * A boat that has not moved (stopped on the calm lake) is not rewritten.
--   * Nothing collides, is touched or is hit by raycasts, and nothing casts shadows.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NpcFishers = require(Shared.NpcFishers)
local Weather = require(Shared.Weather)
local Biomes = require(Shared.Biomes)
local Pedestrians = require(Shared.Pedestrians)
local AvatarLite = require(Shared.AvatarLite)

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

local NpcFishersClient = {}

local NEAR = 240
local DRAW_DISTANCE = 1100
local MID_STRIDE = 3
local FADE_SECONDS = 1.2
local FADE_STEP = 0.2 -- coarse steps: each transparency write rebuilds the hull's render batch
local MIN_MOVE = 0.004
-- Hidden models wait here, far above the map and outside any camera's draw range.
local PARKED = CFrame.new(0, 25000, 0)
-- Roblox's stock R15 animations (the default Animate script's sit, walk and idle)
local SIT_ANIMATION = "rbxassetid://2506281703"
local WALK_ANIMATION = "rbxassetid://913402848"
local IDLE_ANIMATION = "rbxassetid://507766388"

-- Boat-local layout of Server/FishingBoat: the origin is the waterline, the bow is -Z.
local HULL_HALF_LENGTH, HULL_HALF_BEAM = 22 * 0.4, 9.6 * 0.4
local DECK = 1.1
local HELM_SEAT_TOP = Vector3.new(0, 2.16, 5.9)
-- From the helm out of the wheelhouse door (around the console) to the starboard bow rail.
local WALK_PATH = {
	Vector3.new(0, 0, 5.9),
	Vector3.new(1.1, 0, 5.5),
	Vector3.new(1.1, 0, 3.3),
	Vector3.new(0.5, 0, 2.3),
	Vector3.new(0.5, 0, -0.6),
	Vector3.new(1.6, 0, -4.2),
}
local WALK_SPEED = 5
local FISH_YAW = -math.pi / 2 -- facing starboard (+X)

-- Rod arm pitch at the shoulder, as in CastAnimation: 0 hangs down, pi/2 holds the rod forward,
-- COCKED is the rod behind the head and FOLLOW the follow-through.
local REST, COCKED, FOLLOW = math.pi / 2, 3.3, 0.95
local ROD_LENGTH = 6.5
local BOB_SPEED = 2.2

local walkLength = 0
local walkCumulative = { 0 }
for index = 2, #WALK_PATH do
	walkLength += (WALK_PATH[index] - WALK_PATH[index - 1]).Magnitude
	walkCumulative[index] = walkLength
end
local WALK_SECONDS = walkLength / WALK_SPEED

local function smooth(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end

-- Boat-local position and yaw `along` studs down the walk path.
local function walkPose(along: number): (Vector3, number)
	along = math.clamp(along, 0, walkLength)
	for index = 2, #WALK_PATH do
		if along <= walkCumulative[index] or index == #WALK_PATH then
			local a, b = WALK_PATH[index - 1], WALK_PATH[index]
			local span = walkCumulative[index] - walkCumulative[index - 1]
			local t = if span > 0 then (along - walkCumulative[index - 1]) / span else 1
			local direction = b - a
			return a:Lerp(b, math.clamp(t, 0, 1)), math.atan2(-direction.X, -direction.Z)
		end
	end
	return WALK_PATH[#WALK_PATH], FISH_YAW
end

local function shortestAngle(from: number, to: number): number
	return (to - from + math.pi) % (2 * math.pi) - math.pi
end

type Rig = {
	model: Model,
	root: BasePart,
	shoulder: Motor6D?,
	shoulderC0: CFrame,
	parts: { BasePart },
	standLift: number,
	sitLift: number,
	sit: AnimationTrack?,
	walk: AnimationTrack?,
	idle: AnimationTrack?,
	mode: string,
	angle: number,
}

type Fisher = {
	config: Instance,
	active: boolean,
	routeText: string?,
	route: NpcFishers.Route?,
	plan: NpcFishers.Plan?,
	seed: number,
	epoch: number,
	boat: Model?,
	root: BasePart?,
	rootOffset: CFrame,
	boatParts: { BasePart },
	rig: Rig?,
	rigLoading: boolean,
	rod: BasePart?,
	rodTip: Attachment?,
	bobber: BasePart?,
	line: Beam?,
	fish: BasePart?,
	shown: boolean,
	alpha: number,
	lastFrame: CFrame?,
	lastRig: CFrame?,
	gear: boolean, -- rod, bobber and fish currently placed (not parked)
	phaseOffset: number,
	fadeAt: number, -- os.clock() of the next fade step
}

local started = false
local container: Folder
local folder: Instance
local fishers: { [Instance]: Fisher } = {}
local moveParts: { BasePart } = {}
local moveFrames: { CFrame } = {}

local function queue(part: BasePart, frame: CFrame)
	table.insert(moveParts, part)
	table.insert(moveFrames, frame)
end

local function quietPart(part: BasePart)
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	part.CastShadow = false
	part.Massless = true
end

local function newPart(name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.Anchored = true
	quietPart(part)
	part.CFrame = PARKED
	return part
end

local function setAlpha(fisher: Fisher, alpha: number)
	if fisher.alpha == alpha then
		return
	end
	fisher.alpha = alpha
	for _, part in fisher.boatParts do
		part.LocalTransparencyModifier = alpha
	end
	local rig = fisher.rig
	if rig then
		for _, part in rig.parts do
			part.LocalTransparencyModifier = alpha
		end
	end
	for _, part in { fisher.rod, fisher.bobber, fisher.fish } do
		if part then
			part.LocalTransparencyModifier = alpha
		end
	end
end

-- The hull as one welded assembly: only the root stays anchored, so moving it moves the boat.
local function buildBoat(fisher: Fisher)
	local template = folder:FindFirstChild(NpcFishers.TEMPLATE)
	if not template or not template:IsA("Model") or not template.PrimaryPart then
		return
	end
	local boat = template:Clone()
	boat.Name = "NpcFishingBoat"
	local root = boat.PrimaryPart :: BasePart
	local parts = {}
	for _, item in boat:GetDescendants() do
		if item:IsA("BasePart") then
			quietPart(item)
			item.Anchored = item == root
			table.insert(parts, item)
		elseif item:IsA("Light") then
			item.Shadows = false
		end
	end
	fisher.rootOffset = root.CFrame -- the template was built at the origin
	root.CFrame = PARKED
	boat.Parent = container
	fisher.boat, fisher.root, fisher.boatParts = boat, root, parts

	local rod = newPart("NpcRod", Vector3.new(0.1, 0.1, ROD_LENGTH), Color3.fromRGB(46, 40, 34))
	local tip = Instance.new("Attachment")
	tip.Name = "Tip"
	tip.Position = Vector3.new(0, 0, -ROD_LENGTH / 2)
	tip.Parent = rod
	rod.Transparency = 1
	rod.Parent = boat
	local bobber = newPart("NpcBobber", Vector3.new(0.45, 0.45, 0.45), Color3.fromRGB(214, 58, 46))
	bobber.Shape = Enum.PartType.Ball
	local tie = Instance.new("Attachment")
	tie.Name = "Tie"
	tie.Position = Vector3.new(0, 0.2, 0)
	tie.Parent = bobber
	bobber.Parent = boat
	local line = Instance.new("Beam")
	line.Attachment0, line.Attachment1 = tip, tie
	line.Width0, line.Width1 = 0.035, 0.035
	line.Segments = 8
	line.CurveSize1 = -1.2
	line.FaceCamera = true
	line.Color = ColorSequence.new(Color3.fromRGB(235, 235, 225))
	line.Transparency = NumberSequence.new(0.25)
	line.Enabled = false
	line.Parent = rod
	local fish = newPart("NpcCatch", Vector3.new(0.55, 0.7, 1.9), Color3.fromRGB(150, 168, 160), Enum.Material.SmoothPlastic)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = fish
	fish.Parent = boat
	fisher.rod, fisher.rodTip, fisher.bobber, fisher.line, fisher.fish = rod, tip, bobber, line, fish
	-- Every new part takes the current fade, whatever it was set to before the boat existed.
	local alpha = fisher.alpha
	fisher.alpha = -1
	setAlpha(fisher, alpha)
end

local function loadTrack(animator: Animator, id: string, priority: Enum.AnimationPriority): AnimationTrack
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local track = animator:LoadAnimation(animation)
	track.Priority = priority
	track.Looped = true
	return track
end

-- The angler wears one of the townsfolk avatars (Server/PedestrianService), built locally.
local function buildRig(fisher: Fisher)
	if fisher.rigLoading or fisher.rig then
		return
	end
	fisher.rigLoading = true
	task.spawn(function()
		local avatars = ReplicatedStorage:WaitForChild(Pedestrians.AVATAR_FOLDER, 30)
		local source = avatars and avatars:WaitForChild(tostring(Pedestrians.avatarSlot(fisher.seed)), 30)
		local description = if source and source:IsA("HumanoidDescription")
			then AvatarLite.strip(source:Clone())
			else Instance.new("HumanoidDescription")
		local ok, model =
			pcall(Players.CreateHumanoidModelFromDescriptionAsync, Players, description, Enum.HumanoidRigType.R15)
		description:Destroy()
		local root = ok and model and model:FindFirstChild("HumanoidRootPart")
		local humanoid = ok and model and model:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoid or not fisher.boat then
			if ok and model then
				model:Destroy()
			end
			warn("[NpcFishers] Angler avatar failed: " .. tostring(if ok then "no rig" else model))
			return -- the boat still sails, just without anyone visible aboard
		end
		AvatarLite.stripModel(model)
		local parts = {}
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then
				quietPart(item)
				-- Only the root is anchored, so Motor6Ds and accessory welds still pose the rest
				item.Anchored = item == root
				if item ~= root then
					table.insert(parts, item)
				end
			elseif item:IsA("Script") or item:IsA("LocalScript") or item:IsA("Sound") then
				item:Destroy()
			end
		end
		root.Transparency = 1
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
		humanoid.EvaluateStateMachine = false -- placed, never simulated
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
		animator.Parent = humanoid
		model.PrimaryPart = root
		model.Name = "NpcAngler"
		root.CFrame = PARKED
		model.Parent = fisher.boat

		local shoulder = model:FindFirstChild("RightShoulder", true)
		local hand = model:FindFirstChild("RightHand")
		local rod = fisher.rod
		if hand and hand:IsA("BasePart") and rod then
			-- The rod rises 35 degrees above the forearm, so it points up and out at REST.
			rod.Anchored = false
			local grip = Instance.new("Weld")
			grip.Part0, grip.Part1 = hand, rod
			grip.C0 = CFrame.new(0, -0.2, 0) * CFrame.Angles(math.rad(-55), 0, 0) * CFrame.new(0, 0, -(ROD_LENGTH / 2 - 0.8))
			grip.Parent = rod
			table.insert(parts, rod)
		end
		local scale = math.max(humanoid.HipHeight / 2, 0.5)
		local rig: Rig = {
			model = model,
			root = root,
			shoulder = if shoulder and shoulder:IsA("Motor6D") then shoulder else nil,
			shoulderC0 = if shoulder and shoulder:IsA("Motor6D") then shoulder.C0 else CFrame.identity,
			parts = parts,
			standLift = humanoid.HipHeight + root.Size.Y / 2,
			sitLift = root.Size.Y / 2 + 0.25 * scale,
			sit = loadTrack(animator, SIT_ANIMATION, Enum.AnimationPriority.Core),
			walk = loadTrack(animator, WALK_ANIMATION, Enum.AnimationPriority.Movement),
			idle = loadTrack(animator, IDLE_ANIMATION, Enum.AnimationPriority.Idle),
			mode = "still",
			angle = 0,
		}
		for _, part in parts do
			part.LocalTransparencyModifier = fisher.alpha
		end
		fisher.rig = rig
		fisher.lastRig = nil
	end)
end

local function setMode(rig: Rig, mode: string)
	if rig.mode == mode then
		return
	end
	rig.mode = mode
	for name, track in { sit = rig.sit, walk = rig.walk, idle = rig.idle } do
		if track then
			if name == mode then
				track:Play(0.25)
			elseif track.IsPlaying then
				track:Stop(0.25)
			end
		end
	end
end

local function setArm(rig: Rig, angle: number)
	if rig.shoulder and math.abs(angle - rig.angle) > 0.002 then
		rig.angle = angle
		rig.shoulder.C0 = rig.shoulderC0 * CFrame.Angles(angle, 0, 0)
	end
end

local function parkGear(fisher: Fisher)
	if not fisher.gear then
		return
	end
	fisher.gear = false
	if fisher.line then
		fisher.line.Enabled = false
	end
	if fisher.rod then
		fisher.rod.Transparency = 1
	end
	if fisher.bobber then
		queue(fisher.bobber, PARKED)
	end
	if fisher.fish then
		queue(fisher.fish, PARKED)
	end
end

local function hide(fisher: Fisher)
	if not fisher.shown then
		return
	end
	fisher.shown = false
	fisher.lastFrame, fisher.lastRig = nil, nil
	if fisher.root then
		queue(fisher.root, PARKED)
	end
	local rig = fisher.rig
	if rig then
		queue(rig.root, PARKED)
		setMode(rig, "still")
		setArm(rig, 0)
	end
	parkGear(fisher)
end

local function refresh(fisher: Fisher)
	local config = fisher.config
	fisher.active = config:GetAttribute("Active") == true
	local text = config:GetAttribute("Route")
	local seed = config:GetAttribute("Seed")
	local epoch = config:GetAttribute("Epoch")
	if type(text) ~= "string" or type(seed) ~= "number" or type(epoch) ~= "number" then
		fisher.route, fisher.plan = nil, nil
		return
	end
	fisher.seed, fisher.epoch = seed, epoch
	if text ~= fisher.routeText then
		fisher.routeText = text
		local route = NpcFishers.decode(text)
		fisher.route = route
		fisher.plan = if route then NpcFishers.plan(route, seed) else nil
		fisher.phaseOffset = NpcFishers.hash(seed, 3) * math.pi * 2
	end
end

local function add(config: Instance)
	if not config:IsA("Configuration") or fishers[config] then
		return
	end
	local fisher: Fisher = {
		config = config,
		active = false,
		seed = 0,
		epoch = 0,
		rootOffset = CFrame.identity,
		boatParts = {},
		rigLoading = false,
		shown = false,
		alpha = 0,
		gear = false,
		phaseOffset = 0,
		fadeAt = 0,
	}
	fishers[config] = fisher
	refresh(fisher)
	config.AttributeChanged:Connect(function()
		refresh(fisher)
	end)
end

-- The hull's waterline frame: on the route, riding the lake swell, the bow lifting with speed.
local function hullFrame(fisher: Fisher, state: NpcFishers.State, x: number, z: number, now: number, weather): CFrame
	local route = fisher.route :: NpcFishers.Route
	local yaw = NpcFishers.headingAt(route, state.distance)
	local forward = CFrame.Angles(0, yaw, 0).LookVector
	local wave = Weather.hullSample(Vector3.new(x, 0, z), forward, HULL_HALF_LENGTH, HULL_HALF_BEAM, now, weather, 0)
	local normal = wave.normal
	forward = (forward - normal * forward:Dot(normal)).Unit
	local right = forward:Cross(normal).Unit
	local frame = CFrame.fromMatrix(Vector3.new(x, Biomes.WaterLevel + wave.height, z), right, normal, -forward)
	local planing = math.clamp(state.speed / NpcFishers.CRUISE_SPEED, 0, 1)
	return frame * CFrame.new(0, planing * 0.15, 0) * CFrame.Angles(planing * 0.045, 0, 0)
end

-- Where the angler stands (boat-local), how they move and how their rod arm is raised.
local function anglerPose(rig: Rig, phase: string, progress: number, now: number, nibble: number): (CFrame, string, number)
	local function standing(position: Vector3, yaw: number): CFrame
		return CFrame.new(position + Vector3.new(0, DECK + rig.standLift, 0)) * CFrame.Angles(0, yaw, 0)
	end
	local seated = CFrame.new(HELM_SEAT_TOP + Vector3.new(0, rig.sitLift, 0))
	local spot = WALK_PATH[#WALK_PATH]
	if phase == "walkOut" or phase == "walkBack" then
		local along = (if phase == "walkOut" then progress else 1 - progress) * walkLength
		local position, yaw = walkPose(along)
		if phase == "walkBack" then
			yaw += math.pi
		end
		return standing(position, yaw), "walk", 0
	elseif phase == "turn" then
		local _, walkingYaw = walkPose(walkLength)
		local yaw = walkingYaw + shortestAngle(walkingYaw, FISH_YAW) * smooth(progress)
		return standing(spot, yaw), "idle", REST * smooth(progress)
	elseif phase == "windup" then
		return standing(spot, FISH_YAW), "idle", REST + (COCKED - REST) * smooth(progress)
	elseif phase == "cast" then
		local angle = if progress < 0.45
			then COCKED + (FOLLOW - COCKED) * smooth(progress / 0.45)
			else FOLLOW + (REST - FOLLOW) * smooth((progress - 0.45) / 0.55)
		return standing(spot, FISH_YAW), "idle", angle
	elseif phase == "wait" then
		return standing(spot, FISH_YAW), "idle", REST + math.sin(now * 0.9) * 0.04 + nibble * 0.12
	elseif phase == "bite" then
		return standing(spot, FISH_YAW), "idle", REST + 0.25 + math.sin(progress * math.pi) * 0.45
	elseif phase == "reel" then
		return standing(spot, FISH_YAW), "idle", REST + 0.3 + math.sin(now * 9) * 0.05
	elseif phase == "stow" then
		return standing(spot, FISH_YAW), "idle", (REST + 0.3) * (1 - smooth(progress))
	end
	return seated, "sit", 0
end

local function update(fisher: Fisher, now: number, eye: Vector3?, frameIndex: number, weatherCache)
	local route, plan = fisher.route, fisher.plan
	-- Off duty and already faded out (or never shown): nothing to draw.
	if not route or not plan or (not fisher.active and (fisher.alpha >= 1 or not fisher.shown)) then
		fisher.alpha = if fisher.boat then fisher.alpha else 1
		if fisher.boat then
			setAlpha(fisher, 1)
		end
		hide(fisher)
		return
	end
	local state = NpcFishers.state(plan, math.max(0, now - fisher.epoch))
	local x, z = NpcFishers.pointAt(route, state.distance)
	local distance = if eye then Vector3.new(x - eye.X, -eye.Y, z - eye.Z).Magnitude else 0
	if distance > DRAW_DISTANCE then
		-- Out of sight: switching on or off duty needs no fade.
		setAlpha(fisher, if fisher.active then 0 else 1)
		hide(fisher)
		return
	end
	if not fisher.boat then
		buildBoat(fisher)
		if not fisher.boat then
			return
		end
	end
	if not fisher.rig then
		buildRig(fisher)
	end
	if not fisher.shown and fisher.active and fisher.alpha >= 1 then
		fisher.fadeAt = 0 -- coming on duty in view: fade in from nothing
	end
	-- Fade toward on or off duty in coarse steps.
	local target = if fisher.active then 0 else 1
	local clock = os.clock()
	if fisher.alpha ~= target and clock >= fisher.fadeAt then
		fisher.fadeAt = clock + FADE_SECONDS * FADE_STEP
		setAlpha(fisher, math.clamp(fisher.alpha + math.clamp(target - fisher.alpha, -FADE_STEP, FADE_STEP), 0, 1))
	end
	local near = distance < NEAR
	if fisher.shown and not near and (frameIndex + math.floor(fisher.phaseOffset * 10)) % MID_STRIDE ~= 0 then
		return
	end
	fisher.shown = true

	weatherCache.state = weatherCache.state or Weather.getState(now)
	local frame = hullFrame(fisher, state, x, z, now, weatherCache.state)
	local last = fisher.lastFrame
	if
		not last
		or (last.Position - frame.Position).Magnitude > MIN_MOVE
		or (last.LookVector - frame.LookVector).Magnitude > MIN_MOVE * 0.05
		or (last.UpVector - frame.UpVector).Magnitude > MIN_MOVE * 0.05
	then
		fisher.lastFrame = frame
		queue(fisher.root :: BasePart, frame * fisher.rootOffset)
	end

	local rig = fisher.rig
	if not rig then
		return
	end
	local phase, progress = "seated", 0
	if state.fishing then
		phase, progress = NpcFishers.activity(state.fishing, state.fishDuration, WALK_SECONDS)
	end
	-- Now and then a fish nibbles at the float while the angler waits.
	local nibble = math.max(0, math.sin(now * 0.7 + fisher.phaseOffset)) ^ 24
	local localPose, mode, angle = anglerPose(rig, phase, progress, now, nibble)
	if not near then
		-- Past NEAR the angler holds a pose: no animation, no line.
		mode = if mode == "sit" then "sit" else "still"
		angle = if phase == "wait" or phase == "bite" or phase == "reel" then REST else 0
	end
	local rigFrame = frame * localPose
	local lastRig = fisher.lastRig
	if not lastRig or (lastRig.Position - rigFrame.Position).Magnitude > MIN_MOVE or mode == "walk" then
		fisher.lastRig = rigFrame
		queue(rig.root, rigFrame)
	end
	setMode(rig, mode)
	setArm(rig, angle)

	-- Rod, float, line and catch: only up close, and only from the turn to the stow.
	local holding = phase == "turn"
		or phase == "windup"
		or phase == "cast"
		or phase == "wait"
		or phase == "bite"
		or phase == "reel"
		or phase == "stow"
	local rod, bobber, line, fish, tip = fisher.rod, fisher.bobber, fisher.line, fisher.fish, fisher.rodTip
	if not (rod and bobber and line and fish and tip) then
		return
	end
	if not holding then
		parkGear(fisher)
		return
	end
	fisher.gear = true
	rod.Transparency = 0
	if not near then
		line.Enabled = false
		queue(bobber, PARKED)
		queue(fish, PARKED)
		return
	end
	local castSeconds = (state.fishing :: number) - NpcFishers.castStart(WALK_SECONDS)
	local spot = WALK_PATH[#WALK_PATH]
	local offset = Vector3.new(
		spot.X + 8.5 + NpcFishers.hash(fisher.seed, state.stop, 11) * 3,
		0,
		spot.Z - 1.5 + NpcFishers.hash(fisher.seed, state.stop, 13) * 3
	)
	local landing = frame:PointToWorldSpace(offset)
	landing = Vector3.new(landing.X, Biomes.WaterLevel + 0.1, landing.Z)
	local tipPosition = tip.WorldPosition
	local bob = math.sin(now * BOB_SPEED + fisher.phaseOffset) * 0.06
	local float: Vector3? = nil
	local hooked = false
	if phase == "cast" or (phase == "wait" and castSeconds < NpcFishers.FLIGHT) then
		local t = math.clamp(castSeconds / NpcFishers.FLIGHT, 0, 1)
		float = tipPosition:Lerp(landing, t) + Vector3.new(0, math.sin(t * math.pi) * 4, 0)
	elseif phase == "wait" then
		float = landing + Vector3.new(0, bob - nibble * 0.3, 0)
	elseif phase == "bite" then
		float = landing + Vector3.new(0, -0.35 - math.abs(math.sin(progress * math.pi * 3)) * 0.35, 0)
	elseif phase == "reel" then
		float = landing:Lerp(tipPosition - Vector3.new(0, 1.2, 0), smooth(progress))
			+ Vector3.new(0, math.sin(progress * math.pi) * 1.5, 0)
		hooked = NpcFishers.hash(fisher.seed, state.stop, state.loop) < NpcFishers.CATCH_CHANCE
	end
	if float then
		line.Enabled = true
		queue(bobber, CFrame.new(float))
		if hooked then
			local wiggle = math.sin(now * 18) * 0.5
			queue(fish, CFrame.new(float - Vector3.new(0, 1.1, 0)) * CFrame.Angles(math.pi / 2, wiggle, 0))
		else
			queue(fish, PARKED)
		end
	else
		line.Enabled = false
		queue(bobber, PARKED)
		queue(fish, PARKED)
	end
end

function NpcFishersClient.start()
	if started then
		return
	end
	started = true
	folder = ReplicatedStorage:WaitForChild(NpcFishers.FOLDER)
	container = Instance.new("Folder")
	container.Name = "NpcFishers"
	container.Parent = workspace
	for _, child in folder:GetChildren() do
		add(child)
	end
	folder.ChildAdded:Connect(add)
	folder.ChildRemoved:Connect(function(child)
		local fisher = fishers[child]
		if fisher then
			fishers[child] = nil
			if fisher.boat then
				fisher.boat:Destroy()
			end
		end
	end)

	local frameIndex = 0
	RunService.Heartbeat:Connect(profiled("NpcFishers", function()
		frameIndex += 1
		local camera = workspace.CurrentCamera
		local eye = camera and camera.CFrame.Position
		local now = workspace:GetServerTimeNow()
		local weatherCache = {}
		for _, fisher in fishers do
			update(fisher, now, eye, frameIndex, weatherCache)
		end
		if #moveParts > 0 then
			workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
			table.clear(moveParts)
			table.clear(moveFrames)
		end
	end))
end

return NpcFishersClient
