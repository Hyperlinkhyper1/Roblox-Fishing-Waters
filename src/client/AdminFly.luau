local Players = game:GetService("Players")
local Admin = require(game:GetService("ReplicatedStorage").Shared.Admin)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Fly = {}
local player = Players.LocalPlayer
local started = false
local character, humanoid, root, velocity
local previousPlatformStand = false

local function stop()
	if velocity then
		velocity:Destroy()
		velocity = nil
	end
	if root and root.Parent then
		root.AssemblyLinearVelocity = Vector3.zero
	end
	if humanoid and humanoid.Parent then
		humanoid.PlatformStand = previousPlatformStand
	end
	character, humanoid, root = nil, nil, nil
end

local function update()
	local current = player.Character
	if not player:GetAttribute("AdminFlyEnabled") or not current then
		if character then stop() end
		return
	end
	if character ~= current or not humanoid or not humanoid.Parent or not root or not root.Parent or humanoid.Health <= 0 then
		if character then stop() end
		local nextHumanoid = current:FindFirstChildOfClass("Humanoid")
		local nextRoot = current:FindFirstChild("HumanoidRootPart")
		if not nextHumanoid or nextHumanoid.Health <= 0 or not nextRoot then return end
		character, humanoid, root = current, nextHumanoid, nextRoot
		previousPlatformStand = humanoid.PlatformStand
		humanoid.Sit = false
		humanoid.PlatformStand = true
		velocity = Instance.new("BodyVelocity")
		velocity.Name = "AdminFlightVelocity"
		velocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		velocity.Velocity = Vector3.zero
		velocity.Parent = root
	end
	local direction = Vector3.zero
	if not UserInputService:GetFocusedTextBox() then
		direction = humanoid.MoveDirection
		local up = UserInputService:IsKeyDown(Enum.KeyCode.Space)
		local down = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		direction += Vector3.new(0, (if up then 1 else 0) - (if down then 1 else 0), 0)
	end
	if direction.Magnitude > 1 then direction = direction.Unit end
	velocity.Velocity = direction * (player:GetAttribute("AdminFlySpeed") or 50)
end

function Fly.start()
	if started or not Admin.isAdmin(player) then return end
	started = true
	RunService.Heartbeat:Connect(update)
end

return Fly
