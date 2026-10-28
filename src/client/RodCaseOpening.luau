-- The paid case remains in the player's inventory until the server opens it.
-- This screen only animates a reward that the server has already awarded.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local FishingRod = require(Shared:WaitForChild("FishingRod"))
local RodSkins = require(Shared:WaitForChild("RodSkins"))

local RodCaseOpening = {}

function RodCaseOpening.create(overlay, onOpen, onBack)
	local panel = Instance.new("Frame")
	panel.Name = "RodCaseOpening"
	panel.Active = true
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(760, 470)
	panel.Visible = false
	panel.Parent = overlay
	Theme.window(panel)
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local function label(parent, name, text, pos, size, textSize, color)
		local item = Instance.new("TextLabel")
		item.Name = name
		item.BackgroundTransparency = 1
		item.Position, item.Size = pos, size
		item.Text, item.TextSize = text, textSize
		item.TextWrapped = true
		item.TextXAlignment = Enum.TextXAlignment.Center
		Theme.text(item, color or Theme.Colors.Text)
		item.Parent = parent
		return item
	end
	local function button(name, text, pos, size)
		local item = Instance.new("TextButton")
		item.Name, item.Text = name, text
		item.Position, item.Size = pos, size
		item.TextSize = 16
		item.Parent = panel
		Theme.button(item, "Selected")
		return item
	end
	local title = label(panel, "Title", "", UDim2.fromOffset(32, 20), UDim2.new(1, -64, 0, 36), 25)
	local subtitle =
		label(panel, "Subtitle", "", UDim2.fromOffset(32, 58), UDim2.new(1, -64, 0, 30), 14, Theme.Colors.Muted)
	local reel = Instance.new("Frame")
	reel.Name = "Reel"
	reel.Position = UDim2.fromOffset(28, 120)
	reel.Size = UDim2.new(1, -56, 0, 180)
	reel.BackgroundColor3 = Theme.Colors.Inset
	reel.ClipsDescendants = true
	reel.BorderSizePixel = 0
	reel.Parent = panel
	Theme.corner(reel, 8)
	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.fromOffset(30 * 164, 180)
	strip.Parent = reel
	local marker = Instance.new("Frame")
	marker.Name = "Marker"
	marker.AnchorPoint = Vector2.new(0.5, 0)
	marker.Position = UDim2.fromScale(0.5, 0)
	marker.Size = UDim2.new(0, 3, 1, 0)
	marker.BackgroundColor3 = Color3.fromRGB(244, 196, 76)
	marker.BorderSizePixel = 0
	marker.ZIndex = 3
	marker.Parent = reel
	local inspect = Instance.new("ViewportFrame")
	inspect.Name = "InspectRod"
	inspect.Position = UDim2.fromOffset(28, 98)
	inspect.Size = UDim2.new(1, -56, 0, 220)
	inspect.BackgroundColor3 = Theme.Colors.Inset
	inspect.BorderSizePixel = 0
	inspect.Ambient = Color3.fromRGB(175, 180, 190)
	inspect.LightColor = Color3.fromRGB(255, 241, 216)
	inspect.LightDirection = Vector3.new(-1, -1, -2)
	inspect.Visible = false
	inspect.Active = true
	inspect.Parent = panel
	Theme.corner(inspect, 8)
	local description =
		label(panel, "Description", "", UDim2.fromOffset(28, 320), UDim2.new(1, -56, 0, 52), 14, Theme.Colors.Muted)
	local open = button("OpenCase", "OPEN CASE", UDim2.new(0.5, -110, 1, -66), UDim2.fromOffset(220, 42))
	local back = button("Back", "BACK", UDim2.fromOffset(24, 1), UDim2.fromOffset(100, 35))
	back.Position = UDim2.new(0, 24, 1, -62)
	local currentId, busy = nil, false
	local generation = 0
	local displayModel, basePivot = nil, nil
	local angle = 0
	local dragging = false
	local lastX = 0

	local function clearInspect()
		for _, child in inspect:GetChildren() do
			if child:IsA("WorldModel") or child:IsA("Camera") then
				child:Destroy()
			end
		end
		displayModel, basePivot = nil, nil
	end
	local function inspectReward(reward)
		clearInspect()
		local world = Instance.new("WorldModel")
		world.Parent = inspect
		local rod = FishingRod.build(reward.SkinId, nil, reward.Wear)
		CollectionService:RemoveTag(rod, "FishingRod")
		rod.Enabled = false
		local model = Instance.new("Model")
		model.Name = "Reward"
		model.Parent = world
		for _, part in rod:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
		rod.Parent = model
		local center, size = model:GetBoundingBox()
		model:PivotTo(CFrame.Angles(0, math.rad(-12), math.rad(-75)) * center:Inverse() * model:GetPivot())
		local camera = Instance.new("Camera")
		camera.FieldOfView = 30
		camera.Parent = inspect
		inspect.CurrentCamera = camera
		local aspect = math.max(0.5, inspect.AbsoluteSize.X / math.max(1, inspect.AbsoluteSize.Y))
		local distance = math.max(math.max(size.X, size.Y) * 0.65 / aspect, size.Z) / math.tan(math.rad(15))
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, distance), Vector3.zero)
		displayModel, basePivot, angle = model, model:GetPivot(), 0
	end
	local function makeReel(crateId, winner)
		strip:ClearAllChildren()
		local crate = RodSkins.Crates[crateId]
		for i = 1, 30 do
			local skinId = if i == 26 and winner then winner else crate.Skins[math.random(1, #crate.Skins)]
			local rarity = RodSkins.rarity(skinId, crateId)
			local rgb = RodSkins.Rarities[rarity].Color
			local color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
			local card = Instance.new("Frame")
			card.Name = "Item" .. i
			card.Position = UDim2.fromOffset((i - 1) * 164 + 4, 12)
			card.Size = UDim2.fromOffset(156, 156)
			card.BackgroundColor3 = Theme.Colors.Panel
			card.BorderSizePixel = 0
			card.Parent = strip
			Theme.corner(card, 6)
			local bar = Instance.new("Frame")
			bar.Size = UDim2.new(1, 0, 0, 5)
			bar.BackgroundColor3 = color
			bar.BorderSizePixel = 0
			bar.Parent = card

			local thumbnail = Instance.new("ViewportFrame")
			thumbnail.Name = "Rod"
			thumbnail.Position = UDim2.fromOffset(6, 10)
			thumbnail.Size = UDim2.new(1, -12, 0, 65)
			thumbnail.BackgroundTransparency = 1
			thumbnail.Ambient = Color3.fromRGB(165, 170, 175)
			thumbnail.LightColor = Color3.fromRGB(255, 241, 216)
			thumbnail.LightDirection = Vector3.new(-1, -1, -2)
			thumbnail.Parent = card
			local world = Instance.new("WorldModel")
			world.Parent = thumbnail
			local rod = FishingRod.build(skinId)
			CollectionService:RemoveTag(rod, "FishingRod")
			rod.Enabled = false
			local model = Instance.new("Model")
			model.Parent = world
			for _, part in rod:GetDescendants() do
				if part:IsA("BasePart") then
					part.Anchored = true
				end
			end
			rod.Parent = model
			local center, size = model:GetBoundingBox()
			model:PivotTo(CFrame.Angles(0, math.rad(-12), math.rad(-75)) * center:Inverse() * model:GetPivot())
			local camera = Instance.new("Camera")
			camera.FieldOfView = 30
			camera.Parent = thumbnail
			thumbnail.CurrentCamera = camera
			local distance = math.max(math.max(size.X, size.Y) * 0.65 / (144 / 65), size.Z) / math.tan(math.rad(15))
			camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, distance), Vector3.zero)
			label(card, "Name", RodSkins.Skins[skinId].Name, UDim2.fromOffset(8, 76), UDim2.new(1, -16, 0, 38), 15)
			label(card, "Rarity", string.upper(rarity), UDim2.fromOffset(5, 120), UDim2.new(1, -10, 0, 24), 12, color)
		end
		strip.Position = UDim2.fromOffset(0, 0)
	end
	local api = {}
	function api.show(crateId, count)
		generation += 1
		currentId, busy = crateId, false
		panel.Visible, reel.Visible, inspect.Visible = true, true, false
		clearInspect()
		makeReel(crateId)
		title.TextColor3 = Theme.Colors.Text
		title.Text = RodSkins.Crates[crateId].Name
		subtitle.Text = string.format("YOU OWN %d  ·  NO KEY REQUIRED", count)
		description.Text = "Open your case to reveal one rod skin. Its wear affects its appearance and bonuses."
		open.Text = "OPEN CASE"
		open.Active, open.Selectable = count > 0, count > 0
		Theme.button(open, if count > 0 then "Selected" else "Disabled")
		back.Text = "BACK"
	end
	function api.hide()
		generation += 1
		panel.Visible, busy = false, false
		dragging = false
		clearInspect()
	end
	function api.setPending()
		busy = true
		open.Active, open.Selectable = false, false
		open.Text = "OPENING…"
		Theme.button(open, "Disabled")
		return generation
	end
	function api.isPending(token)
		return panel.Visible and busy and generation == token
	end
	function api.failed(message, count)
		busy = false
		subtitle.Text = message
		open.Text = "OPEN CASE"
		open.Active, open.Selectable = count > 0, count > 0
		Theme.button(open, if count > 0 then "Selected" else "Disabled")
	end
	function api.reveal(reward)
		generation += 1
		local run = generation
		busy = true
		makeReel(currentId, reward.SkinId)
		subtitle.Text = "UNBOXING…"
		open.Text = "OPENING…"
		local endX = 704 / 2 - (25 * 164 + 82)
		local animation = TweenService:Create(
			strip,
			TweenInfo.new(5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Position = UDim2.fromOffset(endX, 0) }
		)
		animation:Play()
		task.delay(5.3, function()
			if generation ~= run or not panel.Visible then
				return
			end
			busy = false
			reel.Visible, inspect.Visible = false, true
			inspectReward(reward)
			local rarity = RodSkins.rarity(reward.SkinId, currentId)
			local rgb = RodSkins.Rarities[rarity].Color
			title.Text = RodSkins.Skins[reward.SkinId].Name
			title.TextColor3 = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
			subtitle.Text = string.upper(rarity)
				.. (if reward.Serial then string.format("  ·  #%06d", reward.Serial) else "")
			local wear = if type(reward.Wear) == "number" then reward.Wear else 0.2
			local wearName = RodSkins.wearState(wear)
			description.Text = string.format(
				"%s  ·  Wear %.4f\n%s\nDrag to rotate",
				wearName,
				wear,
				table.concat(RodSkins.perks(reward.SkinId, wear), "   ·   ")
			)
			open.Text = "DONE"
			open.Active, open.Selectable = true, true
			Theme.button(open, "Selected")
			back.Text = "BACK"
		end)
	end
	open.Activated:Connect(function()
		if busy or not open.Active then
			return
		end
		if inspect.Visible then
			title.TextColor3 = Theme.Colors.Text
			onBack()
		else
			onOpen(currentId)
		end
	end)
	back.Activated:Connect(function()
		if not busy then
			title.TextColor3 = Theme.Colors.Text
			onBack()
		end
	end)
	inspect.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging, lastX = true, input.Position.X
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			angle += (input.Position.X - lastX) * 0.01
			lastX = input.Position.X
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)
	RunService.RenderStepped:Connect(function()
		if displayModel and basePivot and panel.Visible then
			displayModel:PivotTo(CFrame.Angles(0, angle, 0) * basePivot)
		end
		local camera = workspace.CurrentCamera
		if camera and panel.Visible then
			scale.Scale =
				math.max(0.3, math.min(1, (camera.ViewportSize.X - 24) / 760, (camera.ViewportSize.Y - 40) / 470))
		end
	end)
	return api
end

return RodCaseOpening
