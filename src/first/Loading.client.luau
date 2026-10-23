-- Native-vector ReplicatedFirst screen using the shared game UI theme. Startup readiness stays tied to
-- the completed harbour, initialized gear and solid ground at the assigned dock.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent:WaitForChild("UITheme"))
local FishSkeletonGeometry = require(script.Parent:WaitForChild("FishSkeletonGeometry"))

local player = Players.LocalPlayer
local startedAt = os.clock()
local white = Theme.Colors.Text
local muted = Theme.Colors.Muted

local gui = Instance.new("ScreenGui")
gui.Name = "FishingWatersLoading"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1000
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local screen = Instance.new("Frame")
screen.Name = "Screen"
screen.Size = UDim2.fromScale(1, 1)
screen.BackgroundColor3 = Theme.Colors.Window
screen.BorderSizePixel = 0
screen.Active = true
screen.ClipsDescendants = true
screen.Parent = gui

local function label(parent: Instance, name: string, text: string, size: number, color: Color3): TextLabel
	local item = Instance.new("TextLabel")
	item.Name = name
	item.AnchorPoint = Vector2.new(0.5, 0.5)
	item.Size = UDim2.new(1, 0, 0, 32)
	item.BackgroundTransparency = 1
	Theme.text(item, color)
	item.Text = text
	item.TextColor3 = color
	item.TextSize = size
	item.TextXAlignment = Enum.TextXAlignment.Center
	item.Parent = parent
	return item
end

local content = Instance.new("Frame")
content.Name = "Content"
content.AnchorPoint = Vector2.new(0.5, 0.5)
content.Position = UDim2.fromScale(0.5, 0.45)
content.Size = UDim2.new(1, -48, 0, 280)
local contentBounds = Instance.new("UISizeConstraint")
contentBounds.MaxSize = Vector2.new(720, 280)
contentBounds.Parent = content
Theme.window(content)
content.Parent = screen

-- Draw the SVG's cubic curves natively so the mark stays crisp and appears
-- immediately. The editable SVG lives in assets/ui/fish-skeleton.svg.
local mark = Instance.new("Frame")
mark.Name = "FishSkeletonMark"
mark.AnchorPoint = Vector2.new(0.5, 0.5)
mark.Size = UDim2.fromOffset(FishSkeletonGeometry.width, FishSkeletonGeometry.height)
mark.BackgroundTransparency = 1
mark.Parent = content
local markScale = Instance.new("UIScale")
markScale.Parent = mark

for _, shape in FishSkeletonGeometry.paths do
	local path = Instance.new("Path2D")
	path.Name = shape.name
	path.Color3 = white
	path.Thickness = shape.thickness
	path.Closed = shape.closed
	path.Visible = true
	local points = {}
	for _, point in shape.points do
		table.insert(
			points,
			Path2DControlPoint.new(
				UDim2.fromOffset(point.x, point.y),
				UDim2.fromOffset(point.leftx, point.lefty),
				UDim2.fromOffset(point.rightx, point.righty)
			)
		)
	end
	path:SetControlPoints(points)
	path.Parent = mark
end

local title = label(content, "Title", "Fishing Waters", 56, white)
title.Font = Enum.Font.GothamBold
local status = label(content, "Status", "Loading the waters...", 18, muted)
Theme.text(status, muted)

local activity = Instance.new("Frame")
activity.Name = "Activity"
activity.AnchorPoint = Vector2.new(0.5, 0.5)
activity.Size = UDim2.fromOffset(28, 4)
activity.BackgroundTransparency = 1
activity.Parent = content
local dots = {}
for index = 1, 3 do
	local dot = Instance.new("Frame")
	dot.Name = "Dot" .. index
	dot.Position = UDim2.fromOffset((index - 1) * 12, 0)
	dot.Size = UDim2.fromOffset(4, 4)
	dot.BackgroundColor3 = white
	dot.BackgroundTransparency = 0.5
	dot.BorderSizePixel = 0
	dot.Parent = activity
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
	table.insert(dots, dot)
end

local detail = label(screen, "Detail", "Visit the rod shop to claim your first fishing rod.", 15, muted)
detail.Position = UDim2.fromScale(0.5, 0.855)
detail.Size = UDim2.new(1, -64, 0, 64)
detail.TextWrapped = true

-- The fallback appears only when gear startup is slow or fails and the dock is safe.
local continue = Instance.new("TextButton")
continue.Name = "Continue"
continue.AnchorPoint = Vector2.new(0.5, 0.5)
continue.Size = UDim2.fromOffset(220, 34)
continue.BackgroundTransparency = 1
continue.Font = Enum.Font.SourceSans
continue.Text = "Enter harbour →"
continue.TextSize = 17
continue.TextColor3 = white
continue.Visible = false
continue.Parent = screen
Theme.button(continue, "Selected")

local function resize()
	local width, height = screen.AbsoluteSize.X, screen.AbsoluteSize.Y
	local spacing = math.min(1, height / 600)
	content.Size = UDim2.new(1, -48, 0, 280 * spacing)
	mark.Position = UDim2.new(0.5, 0, 0, 32 * spacing)
	markScale.Scale = spacing * 0.85
	title.Position = UDim2.new(0.5, 0, 0, 111 * spacing)
	title.Size = UDim2.new(1, -36, 0, 72 * spacing)
	title.TextSize = math.clamp(math.min(width / 13, height / 13), 24, 48)
	status.Position = UDim2.new(0.5, 0, 0, 179 * spacing)
	status.TextSize = if width < 600 then 17 else 18
	activity.Position = UDim2.new(0.5, 0, 0, 214 * spacing)
	detail.TextSize = if width < 600 then 14 else 15
	continue.Position = UDim2.new(0.5, 0, 0.45, 158 * spacing)
end

local resizeConnection = screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
gui.Parent = player:WaitForChild("PlayerGui")
resize()
ReplicatedFirst:RemoveDefaultLoadingScreen()

local dismissed = false
local continueConnection = continue.Activated:Connect(function()
	if continue.Visible then
		dismissed = true
	end
end)
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = true
groundParams.RespectCanCollide = true
local tips = {
	"Visit the rod shop to claim your first fishing rod.",
	"Your dock is your own little corner of Gullhaven.",
	"Take a boat out and find a new stretch of shoreline.",
}

while not dismissed do
	local elapsed = os.clock() - startedAt
	-- Reuse the readiness tick for quiet activity; no extra render loop or timer.
	for index, dot in dots do
		dot.BackgroundTransparency = 0.4 + 0.45 * (0.5 + 0.5 * math.sin(elapsed * 3 - index * 0.8))
	end
	local connected = game:IsLoaded()
	local worldReady = ReplicatedStorage:GetAttribute("FishingWatersWorldReady") == true
	local clientReady = player:GetAttribute("FishingWatersClientReady") == true
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local alive = root and humanoid and humanoid.Health > 0
	local ground = false
	if alive and worldReady and player:GetAttribute("FishingWatersSpawnReady") == true then
		groundParams.FilterDescendantsInstances = { character }
		-- Observe actual collidable ground at the assigned spawn instead of
		-- adding a serial streaming request that doesn't prove it arrived.
		ground = workspace:Raycast(
			(root :: BasePart).Position + Vector3.new(0, 2, 0),
			Vector3.new(0, -32, 0),
			groundParams
		) ~= nil
	end
	local safeToEnter = connected and worldReady and alive and ground
	local failed = player:GetAttribute("FishingWatersClientError") == true
	local serverFailed = ReplicatedStorage:GetAttribute("FishingWatersStartupError") == true
	if not connected then
		status.Text = "Connecting to the waters..."
	elseif not worldReady then
		local stage = ReplicatedStorage:GetAttribute("FishingWatersLoadStage")
		status.Text = (if type(stage) == "string" then stage else "Preparing the harbour") .. "..."
	elseif not alive or not ground then
		status.Text = "Finding your dock..."
	elseif not clientReady then
		status.Text = "Loading your fishing gear..."
	else
		status.Text = "Ready."
	end
	continue.Visible = safeToEnter and (failed or elapsed >= 12)
	detail.Text = tips[math.floor(elapsed / 8) % #tips + 1]
	if serverFailed then
		status.Text = "The harbour couldn't start"
		detail.Text = "Please use the Roblox menu to leave and rejoin."
		continue.Visible = false
	elseif failed then
		detail.Text = if safeToEnter
			then "Some gear couldn't load. Enter the harbour, or rejoin to retry."
			else "Some gear couldn't load. Waiting for a safe place to arrive."
	elseif elapsed >= 15 then
		detail.Text = if safeToEnter
			then "Your dock is ready. You can enter while your gear finishes."
			else "Still preparing your arrival. Thanks for hanging in there."
	end
	if safeToEnter and clientReady and not serverFailed then
		break
	end
	task.wait(0.1)
end

player:SetAttribute("FishingWatersLoadingSeconds", os.clock() - startedAt)
continueConnection:Disconnect()
resizeConnection:Disconnect()
-- Fade ordinary UI objects individually; no full-screen offscreen texture.
for _, item in gui:GetDescendants() do
	if item:IsA("GuiObject") then
		local properties = { BackgroundTransparency = 1 }
		if item:IsA("TextLabel") or item:IsA("TextButton") then
			properties.TextTransparency = 1
			properties.TextStrokeTransparency = 1
		end
		TweenService:Create(item, TweenInfo.new(0.25), properties):Play()
	elseif item:IsA("Path2D") then
		TweenService:Create(item, TweenInfo.new(0.25), { Thickness = 0 }):Play()
	elseif item:IsA("UIStroke") then
		TweenService:Create(item, TweenInfo.new(0.25), { Transparency = 1 }):Play()
	end
end
task.wait(0.25)
gui:Destroy()
