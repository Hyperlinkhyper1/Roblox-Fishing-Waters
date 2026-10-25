-- Fishing notices and the shared shop doorway fade.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))

local Fishing = {}
local started = false

function Fishing.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Fishing")
	local feedback = remotes:WaitForChild("Feedback") :: RemoteEvent
	local cream = Theme.Colors.Text
	local navy = Theme.Colors.Window
	local gui = Instance.new("ScreenGui")
	gui.Name = "Fishing"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 22
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	local toast = Instance.new("TextLabel")
	toast.Name = "FishingNotice"
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -92)
	toast.Size = UDim2.new(0.86, 0, 0, 64)
	toast.BackgroundColor3 = navy
	toast.BackgroundTransparency = 0.06
	toast.TextColor3 = cream
	toast.Font = Enum.Font.GothamMedium
	toast.TextSize = 15
	toast.TextWrapped = true
	toast.Visible = false
	toast.ZIndex = 5
	toast.Parent = gui
	Theme.panel(toast, false, 4)
	Theme.text(toast)
	local toastBounds = Instance.new("UISizeConstraint")
	toastBounds.MaxSize = Vector2.new(560, 64)
	toastBounds.Parent = toast
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
	padding.Parent = toast
	local noticeId = 0
	local function notice(message: string)
		noticeId += 1
		local current = noticeId
		toast.Text, toast.Visible = message, true
		task.delay(6, function()
			if noticeId == current then
				toast.Visible = false
			end
		end)
	end

	-- Covers the jump between a shop's street door and its interior, which is built away from the map.
	-- Its own top layer, so it hides the HUD and reaches under the top bar.
	local fadeGui = Instance.new("ScreenGui")
	fadeGui.Name = "DoorFadeLayer"
	fadeGui.IgnoreGuiInset = true
	fadeGui.DisplayOrder = 100
	fadeGui.ResetOnSpawn = false
	fadeGui.Parent = player:WaitForChild("PlayerGui")
	local fade = Instance.new("Frame")
	fade.Name = "DoorFade"
	fade.Size = UDim2.fromScale(1, 1)
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BackgroundTransparency = 1
	fade.BorderSizePixel = 0
	fade.Parent = fadeGui
	-- Each trip is tagged by the server, so a late signal from an earlier trip can't lift this fade.
	local fadeTrip: number? = nil
	local function fadeOut()
		fadeTrip = nil
		TweenService:Create(fade, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
	end
	local function fadeIn(trip: number)
		fadeTrip = trip
		TweenService:Create(fade, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
		-- Failsafe: lift the fade if the arrival signal never comes, so the screen can't stay black.
		task.delay(15, function()
			if fadeTrip == trip then
				fadeOut()
			end
		end)
	end
	feedback.OnClientEvent:Connect(function(kind, message)
		if kind == "DoorFade" and typeof(message) == "number" then
			fadeIn(message)
		elseif kind == "DoorArrived" and message == fadeTrip then
			fadeOut()
		elseif kind == "Notice" and typeof(message) == "string" then
			notice(message)
		end
	end)
end

return Fishing
