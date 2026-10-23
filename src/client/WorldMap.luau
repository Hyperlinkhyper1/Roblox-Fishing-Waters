-- North-up sea chart. Only the player marker updates while the chart is open.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Biomes = require(ReplicatedStorage.Shared.Biomes)
local WorldMap = {}
local started = false
local ink = Color3.fromRGB(79, 54, 32)
local paper = Color3.fromRGB(224, 199, 144)
local seaInk = Color3.fromRGB(115, 127, 110)

local function make(class, parent, props)
	local item = Instance.new(class)
	for key, value in props do
		item[key] = value
	end
	item.Parent = parent
	return item
end

local function label(parent, value, position, size, textSize)
	return make("TextLabel", parent, {
		BackgroundTransparency = 1,
		Text = value,
		Position = position,
		Size = size,
		TextColor3 = ink,
		Font = Enum.Font.Antique,
		TextSize = textSize or 18,
		TextWrapped = true,
		ZIndex = 5,
	})
end

local function line(parent, a, b, color, thickness, zIndex)
	local delta = b - a
	return make("Frame", parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale((a.X + b.X) / 2, (a.Y + b.Y) / 2),
		Size = UDim2.new(delta.Magnitude, 0, 0, thickness or 1),
		Rotation = math.deg(math.atan2(delta.Y, delta.X)),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = zIndex or 2,
	})
end

function WorldMap.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local half = Biomes.MapHalfSize * 1.06
	local function project(x, z)
		return Vector2.new(0.5 + x / (half * 2), 0.5 + z / (half * 2))
	end
	local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), {
		Name = "WorldMap",
		ResetOnSpawn = false,
		DisplayOrder = 45,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local open = make("TextButton", gui, {
		Name = "OpenChart",
		Text = "Map [M]",
		Font = Enum.Font.Antique,
		TextSize = 19,
		TextColor3 = ink,
		BackgroundColor3 = paper,
		BorderColor3 = ink,
		Position = UDim2.new(1, -126, 1, -54),
		Size = UDim2.fromOffset(112, 38),
	})
	local overlay = make("TextButton", gui, {
		Name = "ChartOverlay",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	})
	local chart = make("TextButton", overlay, {
		Name = "Parchment",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = paper,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.94),
	})
	make("UIAspectRatioConstraint", chart, { AspectRatio = 1 })
	make("UISizeConstraint", chart, { MaxSize = Vector2.new(850, 850) })
	make("UIStroke", chart, { Color = ink, Thickness = 3 })
	make("UIGradient", chart, {
		Rotation = 28,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(166, 128, 77)),
			ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 245, 218)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(255, 245, 218)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(166, 128, 77)),
		}),
	})
	label(chart, "FISHING WATERS", UDim2.fromScale(0.12, 0.015), UDim2.fromScale(0.76, 0.055), 26)
	label(chart, "~ A mariner's chart of the five seas ~", UDim2.fromScale(0.12, 0.07), UDim2.fromScale(0.76, 0.04), 15)
	local close = make("TextButton", chart, {
		Name = "CloseChart",
		Text = "X",
		Font = Enum.Font.Antique,
		TextSize = 22,
		TextColor3 = ink,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -48, 0, 8),
		Size = UDim2.fromOffset(40, 40),
		ZIndex = 10,
	})
	local canvas = make("Frame", chart, {
		Name = "SeaChart",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.05, 0.12),
		Size = UDim2.fromScale(0.9, 0.78),
	})
	-- Keep world X/Z at identical scales at every viewport size.
	make("UIAspectRatioConstraint", canvas, { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height })
	canvas.AnchorPoint = Vector2.new(0.5, 0)
	canvas.Position = UDim2.fromScale(0.5, 0.12)
	make("UIStroke", canvas, { Color = ink, Thickness = 1, Transparency = 0.45 })
	for i = 1, 7 do
		line(canvas, Vector2.new(i / 8, 0), Vector2.new(i / 8, 1), seaInk).BackgroundTransparency = 0.78
		line(canvas, Vector2.new(0, i / 8), Vector2.new(1, i / 8), seaInk).BackgroundTransparency = 0.78
	end
	for _, biome in Biomes.list do
		local p = project(biome.center.X, biome.center.Y)
		label(canvas, biome.name, UDim2.fromScale(p.X - 0.16, p.Y - 0.105), UDim2.fromScale(0.32, 0.055), 17)
	end
	label(canvas, "N\n✦\nS", UDim2.fromScale(0.82, 0.02), UDim2.fromScale(0.15, 0.15), 20)
	label(canvas, "W         E", UDim2.fromScale(0.79, 0.065), UDim2.fromScale(0.21, 0.055), 14)
	label(canvas, "OPEN WATERS", UDim2.fromScale(0.02, 0.87), UDim2.fromScale(0.28, 0.05), 16)
	local status =
		label(chart, "Charting the islands...", UDim2.fromScale(0.06, 0.915), UDim2.fromScale(0.88, 0.035), 15)
	label(
		chart,
		"Red arrow: you  •  North is up  •  M / Esc to fold",
		UDim2.fromScale(0.06, 0.955),
		UDim2.fromScale(0.88, 0.03),
		14
	)
	local marker = label(canvas, "▲", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(24, 24), 24)
	marker.Name = "PlayerPosition"
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.TextColor3 = Color3.fromRGB(165, 43, 31)
	marker.TextStrokeColor3 = paper
	marker.TextStrokeTransparency = 0
	marker.ZIndex = 10
	marker.Visible = false
	local count = 0
	local function update()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		marker.Visible = root ~= nil
		if root then
			local p = project(root.Position.X, root.Position.Z)
			marker.Position = UDim2.fromScale(math.clamp(p.X, 0.015, 0.985), math.clamp(p.Y, 0.015, 0.985))
			local look = root.CFrame.LookVector
			marker.Rotation = math.deg(math.atan2(look.X, -look.Z))
			status.Text = string.format(
				"%s  ·  X %d / Z %d  ·  %d islands%s",
				Biomes.at(root.Position).name,
				math.round(root.Position.X),
				math.round(root.Position.Z),
				count,
				if p.X < 0 or p.X > 1 or p.Y < 0 or p.Y > 1 then "  ·  Beyond chart edge" else ""
			)
		else
			status.Text = "Waiting for your character..."
		end
		if not ReplicatedStorage:GetAttribute("FishingWatersGenerationComplete") then
			status.Text ..= "  ·  Charting..."
		end
	end
	local connection
	local function setOpen(value)
		if value and (player:GetAttribute("PlayerMenuOpen") or player:GetAttribute("DrydockScreenOpen")) then
			return
		end
		overlay.Visible = value
		player:SetAttribute("WorldMapOpen", value)
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if value then
			update()
			local elapsed = 0
			connection = RunService.Heartbeat:Connect(function(dt)
				elapsed += dt
				if elapsed >= 0.1 then
					elapsed = 0
					update()
				end
			end)
		end
	end
	open.Activated:Connect(function()
		setOpen(not overlay.Visible)
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)
	overlay.Activated:Connect(function()
		setOpen(false)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.M and not processed then
			setOpen(not overlay.Visible)
		elseif overlay.Visible and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
			setOpen(false)
		end
	end)
	for _, attribute in { "PlayerMenuOpen", "DrydockScreenOpen" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if player:GetAttribute(attribute) then
				setOpen(false)
			end
			open.Visible = not player:GetAttribute("PlayerMenuOpen") and not player:GetAttribute("DrydockScreenOpen")
		end)
	end
	-- Records arrive progressively during generation and include every offshore rock.
	task.spawn(function()
		local catalog = ReplicatedStorage:WaitForChild("IslandChart")
		local rendered = {}
		local function draw(record)
			if not record:IsA("StringValue") or rendered[record] then
				return
			end
			local success, coast = pcall(HttpService.JSONDecode, HttpService, record.Value)
			if not success or #coast < 3 then
				return
			end
			local holder =
				make("Frame", canvas, { Name = record.Name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
			rendered[record] = holder
			count += 1
			local center = Vector2.zero
			for _, point in coast do
				center += project(point[1], point[2])
			end
			center /= #coast
			for i, point in coast do
				local nextPoint = coast[i % #coast + 1]
				local a, b = project(point[1], point[2]), project(nextPoint[1], nextPoint[2])
				line(holder, a, b, ink, 1.3, 3)
				if record:GetAttribute("Atoll") then
					line(holder, center:Lerp(a, 0.65), center:Lerp(b, 0.65), ink, 1, 3)
				end
			end
			record.Destroying:Connect(function()
				holder:Destroy()
				rendered[record] = nil
				count -= 1
			end)
		end
		catalog.ChildAdded:Connect(draw)
		for _, record in catalog:GetChildren() do
			draw(record)
		end
	end)
end

return WorldMap
