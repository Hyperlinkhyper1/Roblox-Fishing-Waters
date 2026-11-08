-- "Now entering" title when the player crosses into a named area (Shared.Areas): the area name
-- alone, in the UI theme font with a dark stroke, fading in near the top of the screen and out
-- again (the original biome-title look). Follows the character (the camera when there is none),
-- holds still while riding the metro, and waits for the loading screen before the first one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Areas = require(ReplicatedStorage.Shared.Areas)
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))

local AreaBanner = {}

local CHECK_EVERY = 0.4
local HOLD = 4
local FADE = TweenInfo.new(1.5, Enum.EasingStyle.Sine)

function AreaBanner.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "AreaBanner"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	local title = Instance.new("TextLabel")
	title.Name = "AreaName"
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.2)
	title.Size = UDim2.new(0.8, 0, 0, 60)
	title.BackgroundTransparency = 1
	Theme.text(title)
	title.TextSize = 44
	title.TextColor3 = Theme.Colors.Text
	title.TextStrokeColor3 = Theme.Colors.Black
	title.TextStrokeTransparency = 1
	title.TextTransparency = 1
	title.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")

	local token = 0
	local function show(area: Areas.Area)
		token += 1
		local mine = token
		title.Text = area.name
		TweenService:Create(title, FADE, { TextTransparency = 0, TextStrokeTransparency = 0 }):Play()
		task.delay(HOLD, function()
			if mine == token then
				TweenService:Create(title, FADE, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			end
		end)
	end
	AreaBanner.show = show

	local function position(): Vector3?
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			return root.Position
		end
		local camera = workspace.CurrentCamera
		return camera and camera.CFrame.Position
	end

	local current: Areas.Area? = nil
	local elapsed = CHECK_EVERY
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < CHECK_EVERY then
			return
		end
		elapsed = 0
		-- The first banner waits until the loading screen has gone; the metro tunnel runs
		-- under open water, so the area holds until the ride ends.
		if player:GetAttribute("FishingWatersLoadingSeconds") == nil or player:GetAttribute("MetroRiding") then
			return
		end
		local at = position()
		if not at then
			return
		end
		local area = Areas.at(at, current)
		if area ~= current then
			local previous = current
			current = area
			if Areas.announces(previous, area) then
				show(area)
			end
		end
	end)
end

return AreaBanner
