-- Hold to charge a cast, release to throw. The server owns the cast, the bite
-- and the fish; this module aims, plays the reel minigame and draws the line.
-- Every client draws every rod's bobber from the tool's replicated Cast*
-- attributes, so other anglers' lines look the same without per-frame remotes.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CastAnimation = require(script.Parent.CastAnimation)
local FishingAudio = require(script.Parent.FishingAudio)
local Reel = require(script.Parent.ReelMinigame)
local FishingBobber = require(ReplicatedStorage.Shared.FishingBobber)

local Casting = {}
local CHARGE_SECONDS = 1
local MIN_CAST, MAX_CAST = 10, 58
local LINE_COLOR = Color3.fromRGB(232, 234, 214)
local started = false

local function shape(name: string, class: string, size: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new(class) :: Part
	part.Name = name
	part.Size, part.Color = size, color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
	part.CastShadow = false
	part.Parent = parent
	return part
end

-- One floating bobber, line and splash per cast rod, local to this client.
local function newLine(tool: Tool)
	local folder = Instance.new("Folder")
	folder.Name = "CastLine"
	local bobber = shape("Bobber", "Part", Vector3.new(0.34, 0.34, 0.34), Color3.fromRGB(199, 73, 59), folder)
	bobber.Shape = Enum.PartType.Ball
	local band = shape("Band", "Part", Vector3.new(0.1, 0.35, 0.35), Color3.fromRGB(244, 235, 203), folder)
	band.Shape = Enum.PartType.Cylinder
	local stem = shape("Stem", "Part", Vector3.new(0.24, 0.05, 0.05), Color3.fromRGB(36, 42, 43), folder)
	stem.Shape = Enum.PartType.Cylinder
	local customBobber: Model? = nil
	local skin = tool:GetAttribute("BobberSkin")
	if type(skin) == "string" and skin ~= "" then
		bobber.Transparency, band.Transparency, stem.Transparency = 1, 1, 1
		customBobber = FishingBobber.build(skin)
		customBobber:ScaleTo(1.45)
		for _, part in customBobber:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
		customBobber.Parent = folder
	end
	local terrain = workspace.Terrain
	local from, to, splashPoint = Instance.new("Attachment"), Instance.new("Attachment"), Instance.new("Attachment")
	from.Name, to.Name, splashPoint.Name = "CastLineTip", "CastLineBobber", "CastSplash"
	from.Parent, to.Parent, splashPoint.Parent = terrain, terrain, terrain
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = from, to
	beam.Width0, beam.Width1 = 0.035, 0.035
	beam.Color = ColorSequence.new(LINE_COLOR)
	beam.Transparency = NumberSequence.new(0.15)
	beam.FaceCamera, beam.Segments = true, 14
	beam.Parent = folder
	local splash = Instance.new("ParticleEmitter")
	splash.Texture = "rbxasset://textures/particles/smoke_main.dds"
	splash.Color = ColorSequence.new(Color3.fromRGB(236, 246, 248))
	splash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.3) })
	splash.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	splash.Lifetime = NumberRange.new(0.35, 0.7)
	splash.Speed = NumberRange.new(5, 10)
	splash.SpreadAngle = Vector2.new(40, 40)
	splash.Acceleration = Vector3.new(0, -32, 0)
	splash.Rate = 0
	splash.LightEmission = 0.25
	splash.Parent = splashPoint
	folder.Parent = workspace
	return {
		tool = tool,
		folder = folder,
		bobber = bobber,
		band = band,
		stem = stem,
		customBobber = customBobber,
		from = from,
		to = to,
		splashPoint = splashPoint,
		splash = splash,
		beam = beam,
		start = nil :: Vector3?,
		late = false,
		landed = false,
		nextNibble = os.clock() + math.random() * 2 + 1,
		nibble = 0,
		nextSplash = 0,
	}
end

local function setBuiltInBobber(tool: Tool, visible: boolean)
	for _, name in { "RodBobber", "BobberBand", "BobberStem" } do
		local part = tool:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.LocalTransparencyModifier = if visible then 0 else 1
			for _, detail in part:GetDescendants() do
				if detail:IsA("BasePart") then
					detail.LocalTransparencyModifier = if visible then 0 else 1
				end
			end
		end
	end
	local hanging = tool:FindFirstChild("HangingLine")
	if hanging and hanging:IsA("Beam") then
		hanging.Enabled = visible
	end
end

local function destroyLine(line)
	line.folder:Destroy()
	line.from:Destroy()
	line.to:Destroy()
	line.splashPoint:Destroy()
	if line.tool.Parent then
		setBuiltInBobber(line.tool, true)
	end
end

local function updateLine(line, target: Vector3, castAt: number, phase: string, now: number)
	local tip = line.tool:FindFirstChild("RodTip", true)
	local tipPosition = if tip and tip:IsA("Attachment") then tip.WorldPosition else target
	local distance = (Vector3.new(target.X, 0, target.Z) - Vector3.new(tipPosition.X, 0, tipPosition.Z)).Magnitude
	local flight = 0.3 + distance / 55
	local progress = (workspace:GetServerTimeNow() - castAt) / flight
	local position
	if not line.start then
		-- Late arrivals (or streamed-in rods) skip straight to the floating bobber.
		line.late = progress >= 1
		line.start = if progress < 1 then tipPosition else target
	end
	if progress < 1 and not line.landed then
		local a = math.clamp(progress, 0, 1)
		position = line.start:Lerp(target, a) + Vector3.yAxis * (3 + distance * 0.25) * 4 * a * (1 - a)
	else
		if not line.landed then
			line.landed = true
			line.splashPoint.WorldPosition = target
			line.splash:Emit(14)
			if not line.late then
				FishingAudio.splash(target)
			end
		end
		local float = math.sin(now * 2.3) * 0.05
		if phase == "Hooked" then
			local jitter = Vector3.new(math.noise(now * 3, 1) * 0.6, 0, math.noise(now * 3, 7) * 0.6)
			position = target + jitter + Vector3.new(0, -0.18 + math.sin(now * 15) * 0.13, 0)
			if now >= line.nextSplash then
				line.nextSplash = now + 0.22
				line.splashPoint.WorldPosition = position
				line.splash:Emit(3)
			end
		else
			if now >= line.nextNibble then
				line.nextNibble = now + 1.4 + math.random() * 2.6
				line.nibble = now
			end
			local dip = if now - line.nibble < 0.18 then -0.14 else 0
			position = target + Vector3.new(0, 0.08 + float + dip, 0)
		end
	end
	local frame = CFrame.new(position)
	line.bobber.CFrame = frame
	line.band.CFrame = frame * CFrame.new(0, -0.03, 0) * CFrame.Angles(0, 0, math.pi / 2)
	line.stem.CFrame = frame * CFrame.new(0, 0.26, 0) * CFrame.Angles(0, 0, math.pi / 2)
	if line.customBobber then
		line.customBobber:PivotTo(frame)
	end
	-- Attachment X axes point down: slack line sags from the tip and drops into the bobber.
	local down = CFrame.fromMatrix(Vector3.zero, -Vector3.yAxis, Vector3.xAxis)
	line.from.WorldCFrame = down + tipPosition
	line.to.WorldCFrame = down + (position + Vector3.new(0, 0.38, 0))
	local slack = if phase == "Hooked" or not line.landed then 0 else math.min(distance * 0.12, 6)
	line.beam.CurveSize0, line.beam.CurveSize1 = slack, slack * 0.3
end

function Casting.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Catch")
	local request = remotes:WaitForChild("Request") :: RemoteEvent
	local update = remotes:WaitForChild("Update") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "Catching"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 21
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local reel = Reel.new(gui)

	-- Small prompt shown while a rod is in hand.
	local hud = Instance.new("Frame")
	hud.Name = "CastHint"
	hud.AnchorPoint = Vector2.new(0.5, 1)
	hud.Position = UDim2.new(0.5, 0, 1, -96)
	hud.Size = UDim2.fromOffset(340, 34)
	hud.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	hud.BackgroundTransparency = 0.25
	hud.BorderSizePixel = 0
	hud.Visible = false
	hud.Parent = gui
	local hudCorner = Instance.new("UICorner")
	hudCorner.CornerRadius = UDim.new(0, 6)
	hudCorner.Parent = hud
	local power = Instance.new("Frame")
	power.Name = "Power"
	power.Size = UDim2.fromScale(0, 1)
	power.BackgroundColor3 = Color3.fromRGB(84, 192, 92)
	power.BackgroundTransparency = 0.35
	power.BorderSizePixel = 0
	power.Parent = hud
	local powerCorner = hudCorner:Clone()
	powerCorner.Parent = power
	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromOffset(12, 0)
	hint.Size = UDim2.new(1, -24, 1, 0)
	hint.Font = Enum.Font.GothamMedium
	hint.TextSize = 14
	hint.TextColor3 = Color3.fromRGB(240, 240, 236)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextTruncate = Enum.TextTruncate.AtEnd
	hint.ZIndex = 2
	hint.Parent = hud

	local phase = "Idle" -- Idle, Charging, Sent, Waiting, Fighting
	local chargeStarted = 0
	local sentAt = 0
	local rod: Tool? = nil
	local rodConnections = {}

	local noticeText, noticeUntil = "", 0
	local function refreshHud()
		hud.Visible = rod ~= nil and phase ~= "Fighting"
		power.Visible = phase == "Charging"
		if phase == "Charging" then
			hint.Text = "Release to cast"
		elseif phase == "Sent" then
			hint.Text = "Casting…"
		elseif phase == "Waiting" then
			hint.Text = "Waiting for a bite… click to reel in"
		elseif os.clock() < noticeUntil then
			hint.Text = noticeText
		else
			hint.Text = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
				then "Hold the screen to cast"
				else "Hold click to cast, release to throw"
		end
	end
	local function notice(message: string)
		noticeText, noticeUntil = message, os.clock() + 2.5
		refreshHud()
		task.delay(2.6, refreshHud)
	end

	local function root(): BasePart?
		local character = player.Character
		local part = character and character:FindFirstChild("HumanoidRootPart")
		return if part and part:IsA("BasePart") then part else nil
	end

	local function findWater(strength: number): Vector3?
		local body = root()
		local camera = workspace.CurrentCamera
		if not body or not camera then
			return nil
		end
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.05 then
			flat = body.CFrame.LookVector * Vector3.new(1, 0, 1)
		end
		flat = flat.Unit
		local parameters = RaycastParams.new()
		parameters.FilterType = Enum.RaycastFilterType.Exclude
		parameters.FilterDescendantsInstances = { player.Character :: Instance }
		parameters.IgnoreWater = false
		local distance = MIN_CAST + (MAX_CAST - MIN_CAST) * strength
		while distance >= 6 do
			local point = body.Position + flat * distance
			local result = workspace:Raycast(
				Vector3.new(point.X, body.Position.Y + 25, point.Z),
				Vector3.new(0, -80, 0),
				parameters
			)
			if result and result.Instance == workspace.Terrain and result.Material == Enum.Material.Water then
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid and not humanoid.Sit then
					body.CFrame = CFrame.lookAt(body.Position, body.Position + flat)
				end
				return result.Position
			end
			distance -= 4
		end
		return nil
	end

	local function charge(): number
		return math.clamp((os.clock() - chargeStarted) / CHARGE_SECONDS, 0, 1)
	end

	local function fight(info)
		phase = "Fighting"
		refreshHud()
		local outcome = reel:fight(info.FishId, info.Difficulty, info.Pool, info.ReelBoost)
		if phase == "Fighting" then
			phase = "Idle"
		end
		if outcome == "Aborted" then
			refreshHud()
			return
		end
		request:FireServer("Reel", outcome == "Landed")
		if outcome == "Landed" then
			reel:showMessage("REELING IT IN…", "Bringing your catch aboard.")
		else
			FishingAudio.fail()
			reel:showMessage("IT GOT AWAY", "The fish slipped the hook. Cast again!")
		end
		refreshHud()
	end

	local function press()
		if not rod then
			return
		end
		if phase == "Idle" then
			if player:GetAttribute("PlayerMenuOpen") or player:GetAttribute("RodCrateOpening") then
				return
			end
			phase, chargeStarted = "Charging", os.clock()
			CastAnimation.windUp(rod)
		elseif phase == "Waiting" then
			request:FireServer("Reel", false)
		elseif phase == "Fighting" then
			reel:pull()
		end
		refreshHud()
	end

	local function release()
		if phase ~= "Charging" then
			return
		end
		local strength = charge()
		local target = findWater(strength)
		if not target then
			if rod then
				CastAnimation.cancel(rod)
			end
			phase = "Idle"
			refreshHud()
			notice("Aim at open water to cast.")
			return
		end
		FishingAudio.cast(strength)
		if rod then
			CastAnimation.swing(rod)
		end
		phase, sentAt = "Sent", os.clock()
		request:FireServer("Cast", target)
		refreshHud()
	end

	local function unbindRod()
		for _, connection in rodConnections do
			connection:Disconnect()
		end
		table.clear(rodConnections)
		if rod and phase == "Charging" then
			CastAnimation.cancel(rod)
		end
		rod = nil
		if phase == "Fighting" then
			reel:abort()
		end
		phase = "Idle"
		refreshHud()
	end
	local function bindRod(tool: Tool)
		if rod == tool then
			return
		end
		unbindRod()
		rod = tool
		table.insert(rodConnections, tool.Activated:Connect(press))
		table.insert(rodConnections, tool.Deactivated:Connect(release))
		table.insert(rodConnections, tool.Unequipped:Connect(unbindRod))
		table.insert(
			rodConnections,
			tool.AncestryChanged:Connect(function()
				if tool.Parent ~= player.Character then
					unbindRod()
				end
			end)
		)
		refreshHud()
	end
	local function watchCharacter(character: Model)
		unbindRod()
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and child:GetAttribute("RodId") == "StarterRod" then
				bindRod(child)
			end
		end)
		for _, child in character:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("RodId") == "StarterRod" then
				bindRod(child)
			end
		end
	end
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end

	update.OnClientEvent:Connect(function(kind, payload)
		if kind == "Cast" then
			if phase == "Sent" then
				phase = "Waiting"
			end
		elseif kind == "Bite" and type(payload) == "table" and rod then
			local target = rod:GetAttribute("CastTarget")
			FishingAudio.bite(if typeof(target) == "Vector3" then target else nil)
			task.spawn(fight, payload)
		elseif kind == "Cancelled" then
			reel:abort()
			phase = "Idle"
			if type(payload) == "string" then
				notice(payload)
			end
		elseif kind == "ReeledIn" then
			phase = "Idle"
		elseif kind == "Escaped" then
			-- Also covers a fight the server timed out or could not verify.
			if phase == "Fighting" then
				reel:abort()
				phase = "Idle"
			end
			FishingAudio.fail()
			reel:showMessage("IT GOT AWAY", "The fish slipped the hook. Cast again!")
		elseif kind == "Caught" and type(payload) == "table" then
			FishingAudio.catch()
			reel:showCatch(payload)
		end
		refreshHud()
	end)
	local lines = {}
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if phase == "Charging" then
			power.Size = UDim2.fromScale(charge(), 1)
		elseif phase == "Sent" and now - sentAt > 4 then
			phase = "Idle"
			refreshHud()
		end
		for _, tool in CollectionService:GetTagged("FishingRod") do
			local target, castAt, castPhase =
				tool:GetAttribute("CastTarget"), tool:GetAttribute("CastAt"), tool:GetAttribute("CastPhase")
			local line = lines[tool]
			local holder = tool.Parent
			local active = typeof(target) == "Vector3"
				and type(castAt) == "number"
				and holder ~= nil
				and holder:IsA("Model")
				and holder:IsDescendantOf(workspace)
			if active and not line then
				line = newLine(tool)
				lines[tool] = line
				setBuiltInBobber(tool, false)
			end
			if line then
				if active then
					updateLine(line, target, castAt, castPhase, now)
				else
					destroyLine(line)
					lines[tool] = nil
				end
			end
		end
		for tool, line in lines do
			if not tool:IsDescendantOf(game) then
				destroyLine(line)
				lines[tool] = nil
			end
		end
	end)
	refreshHud()
end

return Casting
