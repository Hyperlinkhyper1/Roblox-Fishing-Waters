-- Hold Shift to move faster while on foot.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Sprint = {}
local SPRINT_SPEED = 24
local started = false
local shiftHeld = false
local humanoid: Humanoid? = nil
local normalSpeed = 16

local function applySpeed()
	local currentHumanoid = humanoid
	if not currentHumanoid or currentHumanoid.Health <= 0 then
		return
	end
	currentHumanoid.WalkSpeed = if shiftHeld and not currentHumanoid.Sit then SPRINT_SPEED else normalSpeed
end

local function bindCharacter(character: Model)
	humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	normalSpeed = humanoid.WalkSpeed
	humanoid.Seated:Connect(applySpeed)
	humanoid.Died:Connect(function()
		shiftHeld = false
	end)
	applySpeed()
end

function Sprint.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(bindCharacter)
	player.CharacterRemoving:Connect(function()
		shiftHeld = false
		humanoid = nil
	end)
	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			shiftHeld = true
			applySpeed()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			shiftHeld = false
			applySpeed()
		end
	end)
end

return Sprint
