-- Only included by build-boat-idle-studio.mjs, never by default.project.json.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
