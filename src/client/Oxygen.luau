-- Bottom HUD breath meter.  The server supplies the state; this module only
-- presents it and fades the local screen before the server respawns the player.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Oxygen = {}
local started = false

local BUBBLE_COUNT = 12
local BAR_FADE = TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local BLACKOUT_FADE = TweenInfo.new(1.15, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
local RETURN_FADE = TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local function rounded(item: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = item
end

function Oxygen.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "OxygenHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Centered directly above Roblox's bottom inventory/hotbar.
	local meter = Instance.new("Frame")
	meter.Name = "OxygenBar"
	meter.AnchorPoint = Vector2.new(0.5, 1)
	meter.Position = UDim2.new(0.5, 0, 1, -124)
	meter.Size = UDim2.fromOffset(330, 44)
	meter.BackgroundColor3 = Color3.fromRGB(6, 24, 43)
	meter.BackgroundTransparency = 1
	meter.BorderSizePixel = 0
	meter.Visible = false
	meter.Parent = gui
	rounded(meter, 12)
	local meterStroke = Instance.new("UIStroke")
	meterStroke.Color = Color3.fromRGB(102, 206, 255)
	meterStroke.Thickness = 1.5
	meterStroke.Transparency = 1
	meterStroke.Parent = meter

	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.BackgroundTransparency = 1
	caption.Position = UDim2.fromOffset(13, 0)
	caption.Size = UDim2.fromOffset(54, 44)
	caption.Font = Enum.Font.GothamBold
	caption.Text = "O₂"
	caption.TextSize = 20
	caption.TextColor3 = Color3.fromRGB(197, 242, 255)
	caption.TextTransparency = 1
	caption.TextXAlignment = Enum.TextXAlignment.Left
	caption.ZIndex = 2
	caption.Parent = meter

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromOffset(60, 10)
	track.Size = UDim2.new(1, -130, 0, 24)
	track.BackgroundColor3 = Color3.fromRGB(10, 54, 83)
	track.BackgroundTransparency = 1
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Parent = meter
	rounded(track, 9)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(34, 167, 237)
	fill.BackgroundTransparency = 1
	fill.BorderSizePixel = 0
	fill.ClipsDescendants = true
	fill.Parent = track
	rounded(fill, 9)
	local shine = Instance.new("UIGradient")
	shine.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(83, 210, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 111, 205)),
	})
	shine.Rotation = 90
	shine.Parent = fill

	local remaining = Instance.new("TextLabel")
	remaining.Name = "Remaining"
	remaining.BackgroundTransparency = 1
	remaining.AnchorPoint = Vector2.new(1, 0.5)
	remaining.Position = UDim2.new(1, -12, 0.5, 0)
	remaining.Size = UDim2.fromOffset(48, 30)
	remaining.Font = Enum.Font.GothamBold
	remaining.Text = "100%"
	remaining.TextSize = 14
	remaining.TextColor3 = Color3.fromRGB(197, 242, 255)
	remaining.TextTransparency = 1
	remaining.TextXAlignment = Enum.TextXAlignment.Right
	remaining.ZIndex = 2
	remaining.Parent = meter

	-- Lightweight circular highlights create visible, gently rising bubbles in
	-- the blue fill without depending on an uploaded image asset.
	local bubbles = {}
	for index = 1, BUBBLE_COUNT do
		local bubble = Instance.new("Frame")
		local size = 3 + (index % 4) * 1.5
		bubble.Name = "Bubble"
		bubble.AnchorPoint = Vector2.new(0.5, 0.5)
		bubble.Size = UDim2.fromOffset(size, size)
		bubble.BackgroundColor3 = Color3.fromRGB(220, 249, 255)
		bubble.BackgroundTransparency = 0.34
		bubble.BorderSizePixel = 0
		bubble.ZIndex = 2
		bubble.Parent = fill
		rounded(bubble, 20)
		table.insert(bubbles, {
			item = bubble,
			x = ((index * 37) % 97 + 2) / 100,
			phase = index / BUBBLE_COUNT,
			speed = 0.16 + (index % 3) * 0.035,
		})
	end

	local blackout = Instance.new("Frame")
	blackout.Name = "OxygenBlackout"
	blackout.Size = UDim2.fromScale(1, 1)
	blackout.BackgroundColor3 = Color3.new(0, 0, 0)
	blackout.BackgroundTransparency = 1
	blackout.BorderSizePixel = 0
	blackout.ZIndex = 100
	blackout.Parent = gui

	local barTween: Tween? = nil
	local blackoutTween: Tween? = nil
	local shown = false
	local function setMeterVisible(visible: boolean)
		if visible == shown then
			return
		end
		shown = visible
		if barTween then
			barTween:Cancel()
		end
		if visible then
			meter.Visible = true
			barTween = TweenService:Create(meter, BAR_FADE, { BackgroundTransparency = 0.08 })
			barTween:Play()
			TweenService:Create(meterStroke, BAR_FADE, { Transparency = 0.15 }):Play()
			TweenService:Create(track, BAR_FADE, { BackgroundTransparency = 0.18 }):Play()
			TweenService:Create(fill, BAR_FADE, { BackgroundTransparency = 0 }):Play()
			TweenService:Create(caption, BAR_FADE, { TextTransparency = 0 }):Play()
			TweenService:Create(remaining, BAR_FADE, { TextTransparency = 0 }):Play()
		else
			barTween = TweenService:Create(meter, BAR_FADE, { BackgroundTransparency = 1 })
			barTween:Play()
			TweenService:Create(meterStroke, BAR_FADE, { Transparency = 1 }):Play()
			TweenService:Create(track, BAR_FADE, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(fill, BAR_FADE, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(caption, BAR_FADE, { TextTransparency = 1 }):Play()
			TweenService:Create(remaining, BAR_FADE, { TextTransparency = 1 }):Play()
			task.delay(BAR_FADE.Time, function()
				if not shown then
					meter.Visible = false
				end
			end)
		end
	end

	local function refresh()
		local oxygen = math.clamp(player:GetAttribute("Oxygen") or 1, 0, 1)
		fill.Size = UDim2.new(oxygen, 0, 1, 0)
		remaining.Text = string.format("%d%%", math.ceil(oxygen * 100))
		setMeterVisible(player:GetAttribute("Underwater") == true and player:GetAttribute("OxygenBlackout") ~= true)
	end

	local function setBlackout(active: boolean)
		if blackoutTween then
			blackoutTween:Cancel()
		end
		blackoutTween = TweenService:Create(blackout, if active then BLACKOUT_FADE else RETURN_FADE, {
			BackgroundTransparency = if active then 0 else 1,
		})
		blackoutTween:Play()
	end

	player:GetAttributeChangedSignal("Oxygen"):Connect(refresh)
	player:GetAttributeChangedSignal("Underwater"):Connect(refresh)
	player:GetAttributeChangedSignal("OxygenBlackout"):Connect(function()
		local blackingOut = player:GetAttribute("OxygenBlackout") == true
		setBlackout(blackingOut)
		refresh()
	end)
	refresh()
	setBlackout(player:GetAttribute("OxygenBlackout") == true)

	local bubbleTime = 0
	RunService.RenderStepped:Connect(function(dt)
		if not shown then
			return
		end
		bubbleTime += dt
		for _, bubble in bubbles do
			local rise = (bubble.phase + bubbleTime * bubble.speed) % 1
			bubble.item.Position = UDim2.fromScale(bubble.x + math.sin(bubbleTime + bubble.phase * 8) * 0.025, 1.08 - rise * 1.16)
		end
	end)
end

return Oxygen
