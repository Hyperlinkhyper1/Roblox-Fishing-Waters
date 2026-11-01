-- The Halloween party on the client: the guests' speech bubbles (now and then on their own, and
-- whenever someone talks to one), the floating ghosts and the giant pumpkin bobbing, bats circling
-- the square, and the orange fireworks over the fountain at the midnight into 1 November.
-- The server builds the party (src/server/HalloweenService.luau); the fireworks run off the shared
-- calendar, so every client starts them at the same moment.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Calendar = require(Shared:WaitForChild("Calendar"))
local Halloween = require(Shared:WaitForChild("Halloween"))

local Client = {}
local started = false

local GUEST_TAG = "HalloweenGuest"
local BOB_TAG = "HalloweenBob"
local PROMPT = "HalloweenGuestPrompt"
local GESTURES = {
	"rbxassetid://507770239", -- wave
	"rbxassetid://507770818", -- laugh
	"rbxassetid://507770453", -- point
	"rbxassetid://507770677", -- cheer
}
local CHEER = "rbxassetid://507770677"
local BUBBLE_SECONDS = 4.5
local CHATTER_RANGE = 80 -- studs from the camera within which guests chat on their own
local TALK_SECONDS = 6 -- a guest faces whoever talked to them this long
local SHOW_RANGE = 2500 -- studs from the plaza within which the fireworks are drawn
local BATS = 12
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local WHOOSH = "rbxasset://sounds/Rocket whoosh 01.wav"

local player = Players.LocalPlayer
local rng = Random.new()
local bubbles: { [Model]: BillboardGui } = {}
local quietUntil: { [Model]: number } = {}
local bobBase: { [Model]: CFrame } = {}
local tracks: { [Model]: { [string]: AnimationTrack } } = {}

local function head(guest: Model): BasePart?
	local found = guest:FindFirstChild("Head")
	return if found and found:IsA("BasePart") then found else nil
end

local function playGesture(guest: Model, id: string)
	if guest:GetAttribute("Dancer") then
		return
	end
	local humanoid = guest:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local cache = tracks[guest] or {}
	tracks[guest] = cache
	local track = cache[id]
	if not track then
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, loaded = pcall(animator.LoadAnimation, animator, animation)
		if not ok then
			return
		end
		track = loaded
		track.Priority = Enum.AnimationPriority.Action
		cache[id] = track
	end
	track:Play(0.2)
end

local function say(guest: Model, text: string)
	local top = head(guest)
	if not top then
		return
	end
	if bubbles[guest] then
		bubbles[guest]:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "HalloweenBubble"
	gui.Adornee = top
	gui.Size = UDim2.fromOffset(220, 70)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	gui.MaxDistance = CHATTER_RANGE
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.fromScale(0.5, 1)
	frame.Size = UDim2.fromScale(1, 1)
	frame.AutomaticSize = Enum.AutomaticSize.None
	frame.BackgroundColor3 = Color3.fromRGB(34, 22, 40)
	frame.BackgroundTransparency = 0.1
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 140, 30)
	stroke.Thickness = 2
	stroke.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
	padding.Parent = frame
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = Color3.fromRGB(255, 226, 180)
	label.Text = text
	label.Parent = frame
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 18
	limit.Parent = label
	gui.Parent = top
	bubbles[guest] = gui
	task.delay(BUBBLE_SECONDS, function()
		if bubbles[guest] == gui then
			bubbles[guest] = nil
		end
		gui:Destroy()
	end)
end

local function fireworksOn(): boolean
	return Halloween.phase(Calendar.now()) == "Fireworks"
end

local function line(): string
	local list = if fireworksOn() then Halloween.FIREWORK_LINES else Halloween.LINES
	return list[rng:NextInteger(1, #list)]
end

local function speak(guest: Model)
	quietUntil[guest] = os.clock() + BUBBLE_SECONDS + rng:NextNumber(4, 12)
	say(guest, line())
	playGesture(guest, if fireworksOn() then CHEER else GESTURES[rng:NextInteger(1, #GESTURES)])
end

-- Someone walked up and pressed Talk: the guest turns to them, answers and turns back later.
local function talkTo(guest: Model)
	local root = guest:FindFirstChild("HumanoidRootPart")
	local character = player.Character
	local mine = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and mine and mine:IsA("BasePart") then
		local from = root.Position
		local target = Vector3.new(mine.Position.X, from.Y, mine.Position.Z)
		if (target - from).Magnitude > 0.1 then
			guest:PivotTo(CFrame.lookAt(from, target))
		end
		local home = guest:GetAttribute("HomeFrame")
		local token = os.clock()
		guest:SetAttribute("TalkToken", token)
		task.delay(TALK_SECONDS, function()
			if guest.Parent and guest:GetAttribute("TalkToken") == token and typeof(home) == "CFrame" then
				guest:PivotTo(home)
			end
		end)
	end
	speak(guest)
end

local function chatter()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local near = {}
	for _, guest in CollectionService:GetTagged(GUEST_TAG) do
		local top = guest:IsA("Model") and head(guest)
		if
			top
			and (top.Position - camera.CFrame.Position).Magnitude < CHATTER_RANGE
			and (quietUntil[guest] or 0) < os.clock()
		then
			table.insert(near, guest)
		end
	end
	if #near > 0 then
		speak(near[rng:NextInteger(1, #near)])
	end
end

-- Bats: little black flapping shapes circling the giant pumpkin while the party is up.
local function batModel(): Model
	local model = Instance.new("Model")
	model.Name = "HalloweenBat"
	local function piece(size: Vector3, frame: CFrame, name: string): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = frame
		part.Color = Color3.fromRGB(20, 16, 24)
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
		part.CastShadow = false
		part.Parent = model
		return part
	end
	local body = piece(Vector3.new(0.5, 0.45, 0.9), CFrame.new(), "Body")
	piece(Vector3.new(1.3, 0.08, 0.7), CFrame.new(-0.85, 0, 0), "LeftWing")
	piece(Vector3.new(1.3, 0.08, 0.7), CFrame.new(0.85, 0, 0), "RightWing")
	model.PrimaryPart = body
	return model
end

local bats: { { model: Model, radius: number, height: number, speed: number, phase: number } } = {}
local batFolder: Folder?

local function clearBats()
	if batFolder then
		batFolder:Destroy()
		batFolder = nil
	end
	table.clear(bats)
end

local function updateBats(plaza: CFrame?, now: number)
	local party = workspace:FindFirstChild("HalloweenParty")
	if not party or not plaza then
		clearBats()
		return
	end
	if not batFolder then
		local folder = Instance.new("Folder")
		folder.Name = "HalloweenBats"
		folder.Parent = workspace
		batFolder = folder
		for _ = 1, BATS do
			local model = batModel()
			model.Parent = folder
			table.insert(bats, {
				model = model,
				radius = rng:NextNumber(10, 30),
				height = rng:NextNumber(20, 34),
				speed = rng:NextNumber(0.35, 0.7) * (if rng:NextNumber() < 0.5 then -1 else 1),
				phase = rng:NextNumber(0, math.pi * 2),
			})
		end
	end
	for _, bat in bats do
		local angle = bat.phase + now * bat.speed
		local position = plaza
			* Vector3.new(
				math.cos(angle) * bat.radius,
				bat.height + math.sin(now * 1.7 + bat.phase) * 2,
				math.sin(angle) * bat.radius
			)
		local ahead = angle + 0.1 * math.sign(bat.speed)
		local toward = plaza * Vector3.new(math.cos(ahead) * bat.radius, bat.height, math.sin(ahead) * bat.radius)
		local frame = CFrame.lookAt(position, Vector3.new(toward.X, position.Y, toward.Z))
		local flap = math.sin(now * 18 + bat.phase) * 0.7
		local model = bat.model
		local body = model.PrimaryPart :: BasePart
		body.CFrame = frame
		local left, right = model:FindFirstChild("LeftWing") :: BasePart, model:FindFirstChild("RightWing") :: BasePart
		left.CFrame = frame * CFrame.Angles(0, 0, -flap) * CFrame.new(-0.85, 0, 0)
		right.CFrame = frame * CFrame.Angles(0, 0, flap) * CFrame.new(0.85, 0, 0)
	end
end

local function updateBobbing(now: number)
	for _, item in CollectionService:GetTagged(BOB_TAG) do
		if item:IsA("Model") and item.PrimaryPart then
			local base = bobBase[item]
			if not base then
				base = item:GetPivot()
				bobBase[item] = base
			end
			local phase = item:GetAttribute("BobPhase") or 0
			item:PivotTo(
				base
					* CFrame.new(0, math.sin(now * 1.3 + phase) * 1.2, 0)
					* CFrame.Angles(0, math.sin(now * 0.4 + phase) * 0.3, 0)
			)
		end
	end
end

-- Fireworks ---------------------------------------------------------------------------------------

local fireworksFolder: Folder?

local function burstColor(): Color3
	local rgbValues = Halloween.FIREWORK_COLORS[rng:NextInteger(1, #Halloween.FIREWORK_COLORS)]
	return Color3.fromRGB(rgbValues[1], rgbValues[2], rgbValues[3])
end

local function anchoredPart(name: string, position: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(0.4, 0.4, 0.4)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	part.CastShadow = false
	part.CFrame = CFrame.new(position)
	part.Parent = fireworksFolder
	return part
end

local function burst(position: Vector3, finale: boolean)
	local color = burstColor()
	local holder = anchoredPart("Burst", position)
	local style = rng:NextInteger(1, 3)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARKLE
	sparks.Color = ColorSequence.new(color, color:Lerp(Color3.fromRGB(255, 60, 0), 0.5))
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Brightness = 3
	sparks.Rate = 0
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.4),
		NumberSequenceKeypoint.new(0.7, 0.9),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.75, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	if style == 1 then -- peony: a round shell
		sparks.Speed = NumberRange.new(38, 44)
		sparks.Drag = 2.2
		sparks.Acceleration = Vector3.new(0, -10, 0)
		sparks.Lifetime = NumberRange.new(1.6, 2.2)
	elseif style == 2 then -- willow: long drooping trails
		sparks.Speed = NumberRange.new(26, 34)
		sparks.Drag = 1.4
		sparks.Acceleration = Vector3.new(0, -16, 0)
		sparks.Lifetime = NumberRange.new(2.6, 3.4)
	else -- chrysanthemum: fast, crackling
		sparks.Speed = NumberRange.new(48, 60)
		sparks.Drag = 3
		sparks.Acceleration = Vector3.new(0, -6, 0)
		sparks.Lifetime = NumberRange.new(1.1, 1.6)
		sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	end
	sparks.Parent = holder
	sparks:Emit(if finale then 160 else 120)
	local flash = Instance.new("PointLight")
	flash.Color = color
	flash.Range = 60
	flash.Brightness = 6
	flash.Shadows = false
	flash.Parent = holder
	local boom = Instance.new("Explosion")
	boom.Position = position
	boom.BlastRadius = 0
	boom.BlastPressure = 0
	boom.DestroyJointRadiusPercent = 0
	boom.Visible = false
	boom.Parent = holder
	task.spawn(function()
		for step = 1, 10 do
			task.wait(0.05)
			flash.Brightness = 6 * (1 - step / 10)
		end
		flash:Destroy()
	end)
	task.delay(5, function()
		holder:Destroy()
	end)
end

local function launch(plaza: CFrame, finale: boolean)
	local angle, radius = rng:NextNumber(0, math.pi * 2), rng:NextNumber(4, 30)
	local from = plaza * Vector3.new(math.cos(angle) * radius, 0.5, math.sin(angle) * radius)
	local apex = from + Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(60, 95), rng:NextNumber(-10, 10))
	local rocket = anchoredPart("Rocket", from)
	rocket.Transparency = 0
	rocket.Material = Enum.Material.Neon
	rocket.Color = Color3.fromRGB(255, 200, 120)
	rocket.Size = Vector3.new(0.35, 0.35, 0.35)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.15, 0), Vector3.new(0, -0.15, 0)
	a0.Parent, a1.Parent = rocket, rocket
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.5
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 190, 100), Color3.fromRGB(255, 90, 0))
	trail.Transparency = NumberSequence.new(0, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.FaceCamera = true
	trail.Parent = rocket
	local whoosh = Instance.new("Sound")
	whoosh.SoundId = WHOOSH
	whoosh.Volume = 0.35
	whoosh.PlaybackSpeed = rng:NextNumber(0.9, 1.2)
	whoosh.RollOffMaxDistance = 600
	whoosh.Parent = rocket
	whoosh:Play()
	local duration = rng:NextNumber(1.1, 1.7)
	local began = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local t = math.min((os.clock() - began) / duration, 1)
		local eased = 1 - (1 - t) * (1 - t)
		rocket.CFrame = CFrame.new(from:Lerp(apex, eased))
		if t >= 1 then
			connection:Disconnect()
			burst(rocket.Position, finale)
			rocket.Transparency = 1
			task.delay(trail.Lifetime, function()
				rocket:Destroy()
			end)
		end
	end)
end

local nextLaunch = 0

local function updateFireworks(plaza: CFrame?)
	local date = Calendar.now()
	local on = Halloween.phase(date) == "Fireworks" and plaza ~= nil
	if not on then
		if fireworksFolder and #fireworksFolder:GetChildren() == 0 then
			fireworksFolder:Destroy()
			fireworksFolder = nil
		end
		return
	end
	local camera = workspace.CurrentCamera
	if not camera or (camera.CFrame.Position - (plaza :: CFrame).Position).Magnitude > SHOW_RANGE then
		return
	end
	if not fireworksFolder then
		local folder = Instance.new("Folder")
		folder.Name = "HalloweenFireworks"
		folder.Parent = workspace
		fireworksFolder = folder
	end
	local now = os.clock()
	if now < nextLaunch then
		return
	end
	local finale = date.Hour >= Halloween.FIREWORKS_HOURS - Halloween.FINALE_HOURS
	launch(plaza :: CFrame, finale)
	if finale and rng:NextNumber() < 0.5 then
		launch(plaza :: CFrame, true)
	end
	nextLaunch = now + if finale then rng:NextNumber(0.08, 0.22) else rng:NextNumber(0.35, 0.95)
end

function Client.start()
	if started then
		return
	end
	started = true
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name ~= PROMPT then
			return
		end
		local guest = prompt:FindFirstAncestorWhichIsA("Model")
		if guest and guest:HasTag(GUEST_TAG) then
			talkTo(guest)
		end
	end)
	CollectionService:GetInstanceRemovedSignal(GUEST_TAG):Connect(function(guest)
		quietUntil[guest] = nil
		tracks[guest] = nil
		if bubbles[guest] then
			bubbles[guest]:Destroy()
			bubbles[guest] = nil
		end
	end)
	CollectionService:GetInstanceRemovedSignal(BOB_TAG):Connect(function(item)
		bobBase[item] = nil
	end)
	local nextChatter = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local plaza = workspace:GetAttribute("HalloweenPlaza")
		local frame = if typeof(plaza) == "CFrame" then plaza else nil
		updateBobbing(now)
		updateBats(frame, now)
		updateFireworks(frame)
		if now >= nextChatter then
			nextChatter = now + rng:NextNumber(1.2, 2.6)
			chatter()
		end
	end)
end

return Client
