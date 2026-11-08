-- Full-screen dim overlays (shop/kitchen/workshop backdrops) live in ScreenGuis that keep
-- IgnoreGuiInset off so their content sits below the Roblox top bar. That leaves the top-bar
-- strip undimmed. Instead of moving every overlay (which would shift its centred card), this
-- gives each one a child strip above it that mirrors its colour and transparency.
local Players = game:GetService("Players")

local OverlayInset = {}

local COVER_NAME = "InsetCover"
local COVER_HEIGHT = 400 -- taller than any top bar; the part above the screen is never drawn
local FULL = UDim2.fromScale(1, 1)
local ORIGIN = UDim2.new()

local covered: { [GuiObject]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function isOverlay(object: Instance): boolean
	if not object:IsA("GuiObject") then
		return false
	end
	local screen = object.Parent
	if not (screen and screen:IsA("ScreenGui")) or screen.IgnoreGuiInset then
		return false
	end
	if object.Size ~= FULL or object.Position ~= ORIGIN or object.AnchorPoint ~= Vector2.zero then
		return false
	end
	local colour = object.BackgroundColor3
	return colour.R + colour.G + colour.B < 0.3
end

local function cover(overlay: GuiObject)
	if covered[overlay] or overlay:FindFirstChild(COVER_NAME) then
		return
	end
	covered[overlay] = true
	local strip = Instance.new("Frame")
	strip.Name = COVER_NAME
	strip.BorderSizePixel = 0
	strip.Active = overlay.Active
	strip.Position = UDim2.new(0, 0, 0, -COVER_HEIGHT)
	strip.Size = UDim2.new(1, 0, 0, COVER_HEIGHT)
	local function sync()
		strip.BackgroundColor3 = overlay.BackgroundColor3
		strip.BackgroundTransparency = overlay.BackgroundTransparency
		strip.ZIndex = overlay.ZIndex
	end
	sync()
	overlay:GetPropertyChangedSignal("BackgroundColor3"):Connect(sync)
	overlay:GetPropertyChangedSignal("BackgroundTransparency"):Connect(sync)
	overlay:GetPropertyChangedSignal("ZIndex"):Connect(sync)
	strip.Parent = overlay
end

local function check(object: Instance)
	-- Deferred so properties set right after parenting are in place.
	task.defer(function()
		if object.Parent and isOverlay(object) then
			cover(object :: GuiObject)
		end
	end)
end

function OverlayInset.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local function watchScreen(screen: Instance)
		if not screen:IsA("ScreenGui") then
			return
		end
		for _, child in screen:GetChildren() do
			check(child)
		end
		screen.ChildAdded:Connect(check)
	end
	for _, screen in playerGui:GetChildren() do
		watchScreen(screen)
	end
	playerGui.ChildAdded:Connect(function(screen)
		task.defer(watchScreen, screen)
	end)
end

return OverlayInset
