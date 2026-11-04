-- Compact breath meter beside the avatar. The server supplies the state; this module only
-- presents it and fades the local screen before the server respawns the player.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CharacterMeter = require(script.Parent.CharacterMeter)

local Oxygen = {}
local started = false

local BUBBLE_COUNT = 4
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

	-- Match the cast meter, on the avatar's left side.
	local meter = Instance.new("Frame")
	meter.Name = "OxygenBar"
	meter.Size = UDim2.fromOffset(14, 180)
	meter.BackgroundColor3 = Color3.fromRGB(6, 24, 43)
	meter.BackgroundTransparency = 1
	meter.BorderSizePixel = 0
	meter.Visible = false
	meter.Parent = gui
	rounded(meter, 2)
	local meterStroke = Instance.new("UIStroke")
	meterStroke.Color = Color3.fromRGB(102, 206, 255)
	meterStroke.Thickness = 1.5
	meterStroke.Transparency = 1
	meterStroke.Parent = meter

	local caption = Instance.new("CanvasGroup")
	caption.Name = "Caption"
	caption.BackgroundTransparency = 1
	caption.BorderSizePixel = 0
	caption.AnchorPoint = Vector2.new(0.5, 0)
	caption.Position = UDim2.new(0.5, 0, 1, 7)
	caption.Size = UDim2.fromOffset(34, 22)
	caption.GroupTransparency = 1
	caption.ZIndex = 2
	caption.Parent = meter
	-- Three circles form a bubble icon without an uploaded image.
	for index, bubble in { { 19, 5, 8 }, { 11, 12, 6 }, { 22, 17, 4 } } do
		local dot = Instance.new("Frame")
		dot.Name = "BubbleIcon" .. index
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromOffset(bubble[1], bubble[2])
		dot.Size = UDim2.fromOffset(bubble[3], bubble[3])
		dot.BackgroundColor3 = Color3.fromRGB(164, 221, 255)
		dot.BorderSizePixel = 0
		dot.Parent = caption
		rounded(dot, 10)
	end

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromOffset(1, 1)
	track.Size = UDim2.new(1, -2, 1, -2)
	track.BackgroundColor3 = Color3.fromRGB(10, 54, 83)
	track.BackgroundTransparency = 1
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Parent = meter
	rounded(track, 1)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.fromScale(0, 1)
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(34, 167, 237)
	fill.BackgroundTransparency = 1
	fill.BorderSizePixel = 0
	fill.ClipsDescendants = true
	fill.Parent = track
	rounded(fill, 1)
	local shine = Instance.new("UIGradient")
	shine.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(195, 234, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(64, 125, 166)),
	})
	shine.Rotation = 90
	shine.Parent = fill

	local remaining = Instance.new("TextLabel")
	remaining.Name = "Remaining"
	remaining.BackgroundTransparency = 1
	remaining.AnchorPoint = Vector2.new(0.5, 1)
	remaining.Position = UDim2.new(0.5, 0, 0, -5)
	remaining.Size = UDim2.fromOffset(48, 18)
	remaining.Font = Enum.Font.GothamBold
	remaining.Text = "100%"
	remaining.TextSize = 11
	remaining.TextColor3 = Color3.fromRGB(197, 242, 255)
	remaining.TextTransparency = 1
	remaining.TextStrokeTransparency = 0.4
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
			TweenService:Create(caption, BAR_FADE, { GroupTransparency = 0 }):Play()
			TweenService:Create(remaining, BAR_FADE, { TextTransparency = 0 }):Play()
		else
			barTween = TweenService:Create(meter, BAR_FADE, { BackgroundTransparency = 1 })
			barTween:Play()
			TweenService:Create(meterStroke, BAR_FADE, { Transparency = 1 }):Play()
			TweenService:Create(track, BAR_FADE, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(fill, BAR_FADE, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(caption, BAR_FADE, { GroupTransparency = 1 }):Play()
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
		fill.Size = UDim2.fromScale(1, oxygen)
		remaining.Text = string.format("%d%%", math.ceil(oxygen * 100))
		local low = oxygen <= 0.2
		fill.BackgroundColor3 = if low then Color3.fromRGB(255, 117, 91) else Color3.fromRGB(255, 255, 255)
		remaining.TextColor3 = if low then Color3.fromRGB(255, 151, 126) else Color3.fromRGB(197, 242, 255)
		meterStroke.Color = if low then Color3.fromRGB(255, 117, 91) else Color3.fromRGB(55, 133, 174)
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
		local onScreen = CharacterMeter.position(meter, player, -1)
		if shown then
			meter.Visible = onScreen
		end
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
