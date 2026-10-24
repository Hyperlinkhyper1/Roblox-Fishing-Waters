-- Only included by build-boat-idle-studio.mjs, never by default.project.json.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(script.Parent.ParkedBoats).start()
local player = Players.LocalPlayer
local request = ReplicatedStorage:WaitForChild("Boating"):WaitForChild("Request")
local controls = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
controls:Disable()
local elapsed, sinceInput, sinceJump = 0, 0, 0
RunService.PreSimulation:Connect(function(dt)
	elapsed += dt
	sinceInput += dt
	sinceJump += dt
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local phase = workspace:GetAttribute("BoatRegressionPhase")
	if phase == "Walk" then
		humanoid:Move(Vector3.new(if math.floor(elapsed / 0.25) % 2 == 0 then 1 else -1, 0, 0), false)
	else
		humanoid:Move(Vector3.zero, false)
	end
	if phase == "Jump" and sinceJump > 0.7 then
		sinceJump = 0
		humanoid.Jump = true
	end
	if (phase == "Drive" or phase == "Coast") and humanoid.SeatPart and sinceInput >= 0.1 then
		sinceInput = 0
		request:FireServer("Row", if phase == "Drive" then 1 else 0, 0)
	end
end)

-- Measure on the same client that animates the hull and simulates the character.
-- Server-only checks cannot see a player slipping across this local deck pose.
local idlePhase, idleElapsed, idleStation, idleBoat = nil, 0, nil, nil
local idleSamples, idleContacts, maxSlip = 0, 0, 0
RunService.PostSimulation:Connect(function(dt)
	local phase = workspace:GetAttribute("BoatRegressionPhase")
	if phase ~= "IdleAfterDrive" then
		idlePhase, idleElapsed, idleStation, idleBoat = nil, 0, nil, nil
		return
	end
	if phase ~= idlePhase then
		idlePhase = phase
		idleSamples, idleContacts, maxSlip = 0, 0, 0
	end
	idleElapsed += dt
	if idleElapsed < 1 then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local folder = workspace:FindFirstChild("PlayerBoats")
	local boat = folder and folder:FindFirstChild(workspace:GetAttribute("BoatRegressionBoatName") or "")
	if not humanoid or not root or not boat or not boat.PrimaryPart then return end
	local position = boat.PrimaryPart.CFrame:PointToObjectSpace(root.Position)
	if idleBoat ~= boat then
		idleBoat, idleStation = boat, position
	end
	maxSlip = math.max(maxSlip, Vector2.new(position.X - idleStation.X, position.Z - idleStation.Z).Magnitude)
	idleSamples += 1
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local ground = workspace:Raycast(root.Position, Vector3.new(0, -5, 0), params)
	if ground and ground.Instance:IsDescendantOf(boat) and not humanoid.SeatPart then
		idleContacts += 1
	end
	if idleSamples % 30 == 0 then
		request:FireServer("IdleRegressionSample", idleSamples, idleContacts, maxSlip)
	end
end)
