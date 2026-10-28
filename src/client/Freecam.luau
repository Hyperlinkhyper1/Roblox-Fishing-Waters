-- A local, session-only camera that leaves the character in place.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local BoatCamera = require(script.Parent.BoatCamera)

local Freecam = {}
local player = Players.LocalPlayer
local active, started = false, false
local position, yaw, pitch = Vector3.zero, 0, 0
local saved = nil
local touchGui = nil
local touchKeys = {}
local lookTouch = nil
local dragging = false
local moveStick, lookStick = Vector2.zero, Vector2.zero
local gamepadUp, gamepadDown = false, false
local ACTION = "FishingWatersFreecamMovement"

local function blocked()
	return player:GetAttribute("BuildModeOpen")
		or player:GetAttribute("DrydockScreenOpen")
		or player:GetAttribute("RodCrateOpening")
end

local function clearInput()
	table.clear(touchKeys)
	moveStick, lookStick = Vector2.zero, Vector2.zero
	gamepadUp, gamepadDown = false, false
	lookTouch, dragging = nil, false
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

local function makeTouchControls()
	if not UserInputService.TouchEnabled then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn = "FreecamControls", false
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")
	touchGui = gui
	local buttons = {
		{ "W", "▲", 72, -162 },
		{ "A", "◀", 20, -110 },
		{ "S", "▼", 72, -110 },
		{ "D", "▶", 124, -110 },
		{ "E", "Up", -120, -162 },
		{ "Q", "Down", -120, -110 },
	}
	for _, spec in buttons do
		local key, label, x, y = unpack(spec)
		local button = Instance.new("TextButton")
		button.Name, button.Text = key, label
		button.Size = UDim2.fromOffset(48, 48)
		button.Position = UDim2.new(if x < 0 then 1 else 0, x, 1, y)
		button.BackgroundColor3 = Color3.fromRGB(24, 44, 58)
		button.BackgroundTransparency = 0.2
		button.TextColor3 = Color3.new(1, 1, 1)
		button.TextSize = 18
		button.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				touchKeys[key] = true
			end
		end)
		button.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				touchKeys[key] = nil
			end
		end)
	end
end

local function shiftDown(): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

local function turn(delta: Vector2)
	yaw -= delta.X * 0.004
	pitch = math.clamp(pitch - delta.Y * 0.004, -math.rad(89), math.rad(89))
end

local function update(dt: number)
	local camera = workspace.CurrentCamera
	if not camera or blocked() then
		Freecam.stop()
		return
	end
	local menuOpen = player:GetAttribute("PlayerMenuOpen") or UserInputService:GetFocusedTextBox()
	local function down(key: Enum.KeyCode): number
		return if not menuOpen and (UserInputService:IsKeyDown(key) or touchKeys[key.Name]) then 1 else 0
	end
	if not menuOpen then
		yaw -= lookStick.X * dt * 2.2
		pitch = math.clamp(pitch + lookStick.Y * dt * 2.2, -math.rad(89), math.rad(89))
	end
	local rotation = CFrame.fromOrientation(pitch, yaw, 0)
	local x = down(Enum.KeyCode.D) - down(Enum.KeyCode.A) + (if menuOpen then 0 else moveStick.X)
	local y = down(Enum.KeyCode.E)
		- down(Enum.KeyCode.Q)
		+ (if not menuOpen and gamepadUp then 1 else 0)
		- (if not menuOpen and gamepadDown then 1 else 0)
	local z = down(Enum.KeyCode.S) - down(Enum.KeyCode.W) - (if menuOpen then 0 else moveStick.Y)
	local direction = Vector3.new(x, y, z)
	if direction.Magnitude > 1 then
		direction = direction.Unit
	end
	local speed = if shiftDown() then 72 else 32
	local movement = rotation:VectorToWorldSpace(Vector3.new(direction.X, 0, direction.Z)) + Vector3.yAxis * direction.Y
	position += movement * speed * math.min(dt, 0.1)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.new(position) * rotation
	camera.Focus = camera.CFrame * CFrame.new(0, 0, -16)
end

function Freecam.stop()
	if not active then
		return
	end
	active = false
	RunService:UnbindFromRenderStep("FishingWatersFreecam")
	ContextActionService:UnbindAction(ACTION)
	clearInput()
	if touchGui then
		touchGui:Destroy()
		touchGui = nil
	end
	local camera = workspace.CurrentCamera
	if camera and saved then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		camera.CameraSubject = if saved.subject and saved.subject:IsDescendantOf(workspace)
			then saved.subject
			else humanoid
		camera.CameraType = if saved.kind == Enum.CameraType.Scriptable then Enum.CameraType.Custom else saved.kind
		camera.FieldOfView = saved.fov
	end
	saved = nil
	player:SetAttribute("FreecamEnabled", false)
	BoatCamera.refresh()
end

function Freecam.setEnabled(enabled: boolean)
	if not enabled then
		Freecam.stop()
		return
	end
	if active or blocked() then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera or (camera.CameraType == Enum.CameraType.Scriptable and not BoatCamera.isActive()) then
		return
	end
	saved = { kind = camera.CameraType, subject = camera.CameraSubject, fov = camera.FieldOfView }
	position = camera.CFrame.Position
	pitch, yaw = camera.CFrame:ToOrientation()
	active = true
	player:SetAttribute("FreecamEnabled", true)
	camera.CameraType = Enum.CameraType.Scriptable
	ContextActionService:BindActionAtPriority(ACTION, function()
		return Enum.ContextActionResult.Sink
	end, false, 3000, unpack(Enum.PlayerActions:GetEnumItems()))
	makeTouchControls()
	RunService:BindToRenderStep("FishingWatersFreecam", Enum.RenderPriority.Camera.Value + 2, update)
end

function Freecam.start()
	if started then
		return
	end
	started = true
	player:SetAttribute("FreecamEnabled", false)
	UserInputService.InputBegan:Connect(function(input, processed)
		if
			input.KeyCode == Enum.KeyCode.P
			and not processed
			and not UserInputService:GetFocusedTextBox()
			and shiftDown()
		then
			Freecam.setEnabled(not active)
		elseif active and not player:GetAttribute("PlayerMenuOpen") then
			if input.KeyCode == Enum.KeyCode.ButtonR2 then
				gamepadUp = true
			elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
				gamepadDown = true
			elseif not processed and input.UserInputType == Enum.UserInputType.MouseButton2 then
				dragging = true
				UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
			elseif not processed and input.UserInputType == Enum.UserInputType.Touch and not lookTouch then
				lookTouch = input
			end
		end
	end)
	UserInputService.InputChanged:Connect(function(input, processed)
		if not active or player:GetAttribute("PlayerMenuOpen") or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
			turn(Vector2.new(input.Delta.X, input.Delta.Y))
		elseif input == lookTouch then
			turn(Vector2.new(input.Delta.X, input.Delta.Y))
		elseif input.KeyCode == Enum.KeyCode.Thumbstick1 then
			local stick = Vector2.new(input.Position.X, input.Position.Y)
			moveStick = if stick.Magnitude > 0.15 then stick else Vector2.zero
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			local stick = Vector2.new(input.Position.X, input.Position.Y)
			lookStick = if stick.Magnitude > 0.15 then stick else Vector2.zero
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.ButtonR2 then
			gamepadUp = false
		elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
			gamepadDown = false
		elseif dragging and input.UserInputType == Enum.UserInputType.MouseButton2 then
			dragging = false
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		elseif input == lookTouch then
			lookTouch = nil
		end
	end)
	local function clearIfActive()
		if active then
			clearInput()
		end
	end
	UserInputService.WindowFocusReleased:Connect(clearIfActive)
	UserInputService.TextBoxFocused:Connect(clearIfActive)
	player:GetAttributeChangedSignal("PlayerMenuOpen"):Connect(function()
		if active and player:GetAttribute("PlayerMenuOpen") then
			clearInput()
		end
	end)
	player.CharacterAdded:Connect(Freecam.stop)
end

return Freecam
