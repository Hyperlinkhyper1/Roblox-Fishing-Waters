-- The hooked-fish panel: a needle sweeps one of two arc gauges and every Pull
-- inside the green zone reels the fish closer to the surface. Rarer and heavier
-- fish sweep faster, shrink and drift the zone, and pull back harder. The same
-- panel shows the landed catch.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Catalog = require(ReplicatedStorage.Shared.AnglerCatalog)
local FishCatch = require(ReplicatedStorage.Shared.FishCatch)
local FishModels = require(ReplicatedStorage.Shared.FishModels)
local FishMutations = require(ReplicatedStorage.Shared.FishMutations)
local FishingAudio = require(script.Parent.FishingAudio)

local Reel = {}
Reel.__index = Reel

local rgb = Color3.fromRGB
local INK = rgb(10, 10, 10)
local BRONZE = rgb(150, 118, 72)
local BRONZE_DIM = rgb(78, 62, 42)
local TRACK = rgb(112, 36, 32)
local TRACK_DIM = rgb(54, 24, 22)
local ZONE = rgb(84, 192, 92)
local WHITE = rgb(240, 240, 236)
local MUTED = rgb(170, 170, 164)
local PANEL_SIZE = Vector2.new(560, 250)
local CENTER = Vector2.new(190, 135)
local RADIUS = 100
local THICKNESS = 16
local SEGMENTS = 28
-- Screen angles in degrees, clockwise from +X (y points down).
local GAUGES = { { 200, 320 }, { 340, 440 } }

local function make(class: string, parent: Instance?, props: { [string]: any }): any
	local item = Instance.new(class)
	for key, value in props do
		item[key] = value
	end
	item.Parent = parent
	return item
end

local function round(item: GuiObject, radius: number?)
	make("UICorner", item, { CornerRadius = if radius then UDim.new(0, radius) else UDim.new(1, 0) })
end

local function stroke(item: GuiObject, color: Color3, thickness: number, name: string?)
	return make("UIStroke", item, {
		Name = name or "Stroke",
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function text(parent: Instance, value: string, props: { [string]: any }): TextLabel
	local label = make("TextLabel", parent, {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = value,
		TextColor3 = WHITE,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	for key, item in props do
		label[key] = item
	end
	return label
end

local function arcPoint(angle: number, radius: number): Vector2
	local radians = math.rad(angle)
	return CENTER + Vector2.new(math.cos(radians), math.sin(radians)) * radius
end

local function buildGauge(parent: Instance, from: number, to: number)
	local gauge = { from = from, to = to, segments = {}, rims = {} }
	local length = math.rad(to - from) * RADIUS / SEGMENTS
	for index = 1, SEGMENTS do
		local angle = from + (to - from) * (index - 0.5) / SEGMENTS
		local point = arcPoint(angle, RADIUS)
		local rim = make("Frame", parent, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(point.X, point.Y),
			Size = UDim2.fromOffset(length + 2, THICKNESS + 6),
			Rotation = angle + 90,
			BackgroundColor3 = BRONZE,
			BorderSizePixel = 0,
			ZIndex = 2,
		})
		local segment = make("Frame", parent, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(point.X, point.Y),
			Size = UDim2.fromOffset(length + 1.5, THICKNESS),
			Rotation = angle + 90,
			BackgroundColor3 = TRACK,
			BorderSizePixel = 0,
			ZIndex = 3,
		})
		table.insert(gauge.rims, rim)
		table.insert(gauge.segments, { frame = segment, t = (index - 0.5) / SEGMENTS })
	end
	-- Rounded caps close both ends of the track.
	for _, angle in { from, to } do
		local point = arcPoint(angle, RADIUS)
		local cap = make("Frame", parent, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(point.X, point.Y),
			Size = UDim2.fromOffset(THICKNESS + 6, THICKNESS + 6),
			BackgroundColor3 = BRONZE,
			BorderSizePixel = 0,
			ZIndex = 2,
		})
		round(cap)
		table.insert(gauge.rims, cap)
	end
	return gauge
end

function Reel.new(gui: ScreenGui)
	local self = setmetatable({}, Reel)
	self.random = Random.new()
	local root = make("Frame", gui, {
		Name = "ReelMinigame",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
		BackgroundTransparency = 1,
		Visible = false,
	})
	self.root = root
	self.scale = make("UIScale", root, {})

	local panel = make("Frame", root, {
		Name = "Panel",
		Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Active = true,
	})
	round(panel, 4)
	self.panelStroke = stroke(panel, BRONZE, 3)
	local rim = make("Frame", panel, {
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		BackgroundTransparency = 1,
	})
	round(rim, 2)
	stroke(rim, BRONZE_DIM, 1)
	self.panel = panel

	-- Fight view.
	local fight = make("Frame", panel, { Name = "Fight", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	self.fightView = fight
	local meterTop, meterBottom = 40, 214
	self.meterTop, self.meterBottom = meterTop, meterBottom
	make("Frame", fight, {
		Position = UDim2.fromOffset(33, meterTop - 14),
		Size = UDim2.fromOffset(2, meterBottom - meterTop + 22),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	})
	for y = meterTop + 12, meterBottom - 6, 16 do
		make("Frame", fight, {
			Position = UDim2.fromOffset(36, y),
			Size = UDim2.fromOffset(6, 1),
			BackgroundColor3 = MUTED,
			BorderSizePixel = 0,
		})
	end
	local ring = make("Frame", fight, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(34, meterTop - 20),
		Size = UDim2.fromOffset(13, 13),
		BackgroundTransparency = 1,
	})
	round(ring)
	stroke(ring, rgb(226, 170, 140), 2)
	for index, width in { 30, 22 } do
		make("Frame", fight, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(34, meterTop - 6 + index * 4),
			Size = UDim2.fromOffset(width, 2),
			BackgroundColor3 = rgb(70, 140, 214),
			BorderSizePixel = 0,
		})
	end
	make("Frame", fight, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(34, meterBottom + 14),
		Size = UDim2.fromOffset(9, 9),
		Rotation = 45,
		BackgroundColor3 = rgb(226, 170, 140),
		BorderSizePixel = 0,
	})
	local marker = make("Frame", fight, {
		Name = "FishMarker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 4,
	})
	round(marker)
	self.markerStroke = stroke(marker, INK, 2)
	make("Frame", marker, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(6, 6),
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		ZIndex = 5,
	})
	self.marker = marker

	self.silhouette = make("ViewportFrame", fight, {
		Name = "FishSilhouette",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(CENTER.X, CENTER.Y),
		Size = UDim2.fromOffset(160, 150),
		BackgroundTransparency = 1,
		ImageColor3 = WHITE,
		ZIndex = 2,
	})
	self.gauges = {}
	for _, range in GAUGES do
		table.insert(self.gauges, buildGauge(fight, range[1], range[2]))
	end
	local needle = make("Frame", fight, {
		Name = "Needle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(THICKNESS + 18, 5),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 6,
	})
	stroke(needle, INK, 1.5)
	self.needle = needle
	local tip = make("Frame", fight, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(11, 11),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 6,
	})
	stroke(tip, INK, 1.5)
	self.needleTip = tip

	self.title = text(fight, "DISTURBED WATER", {
		Position = UDim2.fromOffset(320, 20),
		Size = UDim2.fromOffset(222, 42),
		Font = Enum.Font.Oswald,
		TextScaled = true,
	})
	make("UITextSizeConstraint", self.title, { MaxTextSize = 36 })
	make("Frame", fight, {
		Position = UDim2.fromOffset(320, 66),
		Size = UDim2.fromOffset(222, 2),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	})
	self.strength = text(
		fight,
		"Strength: Medium",
		{ Position = UDim2.fromOffset(320, 78), Size = UDim2.fromOffset(222, 24), TextSize = 18 }
	)
	local tag = make("Frame", fight, {
		Position = UDim2.fromOffset(320, 110),
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = rgb(36, 40, 98),
		BorderSizePixel = 0,
	})
	round(tag, 3)
	make("UIPadding", tag, { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) })
	self.place = text(tag, "MAIN LAKE", {
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
	})
	self.hint = text(fight, "Pull when the needle is in the green.", {
		Position = UDim2.fromOffset(320, 140),
		Size = UDim2.fromOffset(222, 32),
		TextSize = 13,
		TextColor3 = MUTED,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local pull = make("TextButton", fight, {
		Name = "Pull",
		Position = UDim2.fromOffset(320, 180),
		Size = UDim2.fromOffset(200, 46),
		BackgroundColor3 = rgb(26, 26, 26),
		AutoButtonColor = true,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		Text = "Pull",
		TextColor3 = WHITE,
		TextSize = 22,
	})
	round(pull, 3)
	self.pullStroke = stroke(pull, WHITE, 2)
	local key = make("TextLabel", pull, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = WHITE,
		Font = Enum.Font.GothamBold,
		Text = "F",
		TextColor3 = INK,
		TextSize = 15,
		Visible = UserInputService.KeyboardEnabled,
	})
	round(key, 5)
	pull.Activated:Connect(function()
		self:pull()
	end)

	-- Catch view.
	local result = make(
		"Frame",
		panel,
		{ Name = "Result", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }
	)
	self.result = result
	self.trophy = make("ViewportFrame", result, {
		Name = "Fish",
		Position = UDim2.fromOffset(18, 18),
		Size = UDim2.fromOffset(290, PANEL_SIZE.Y - 36),
		BackgroundTransparency = 1,
	})
	self.resultTitle = text(result, "", {
		Position = UDim2.fromOffset(320, 20),
		Size = UDim2.fromOffset(222, 42),
		Font = Enum.Font.Oswald,
		TextScaled = true,
	})
	make("UITextSizeConstraint", self.resultTitle, { MaxTextSize = 36 })
	make("Frame", result, {
		Position = UDim2.fromOffset(320, 66),
		Size = UDim2.fromOffset(222, 2),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	})
	local badges = make("Frame", result, {
		Position = UDim2.fromOffset(320, 78),
		Size = UDim2.fromOffset(222, 24),
		BackgroundTransparency = 1,
	})
	make("UIListLayout", badges, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) })
	local function badge(name: string)
		local frame = make("Frame", badges, {
			Name = name,
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			BorderSizePixel = 0,
		})
		round(frame, 3)
		make("UIPadding", frame, { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) })
		local label = text(frame, "", {
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = INK,
		})
		return frame, label
	end
	self.rarityBadge, self.rarityLabel = badge("Rarity")
	self.sizeBadge, self.sizeLabel = badge("Size")
	self.weight = text(result, "", {
		Position = UDim2.fromOffset(320, 112),
		Size = UDim2.fromOffset(222, 28),
		TextSize = 22,
		Font = Enum.Font.GothamBold,
	})
	self.worth = text(result, "", {
		Position = UDim2.fromOffset(320, 142),
		Size = UDim2.fromOffset(222, 28),
		TextSize = 22,
		Font = Enum.Font.GothamBold,
		TextColor3 = rgb(111, 202, 125),
	})
	self.footer = text(result, "", {
		Position = UDim2.fromOffset(320, 180),
		Size = UDim2.fromOffset(222, 44),
		TextSize = 13,
		TextColor3 = MUTED,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	UserInputService.InputBegan:Connect(function(input, processed)
		if
			not processed
			and (
				input.KeyCode == Enum.KeyCode.F
				or input.KeyCode == Enum.KeyCode.ButtonX
				or input.KeyCode == Enum.KeyCode.ButtonR2
			)
		then
			self:pull()
		end
	end)
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if camera and root.Visible then
			local viewport = camera.ViewportSize
			self.scale.Scale = math.clamp(
				math.min((viewport.X - 24) / root.Size.X.Offset, (viewport.Y - 30) / root.Size.Y.Offset),
				0.3,
				1
			)
		end
	end)
	return self
end

function Reel:refreshVisibility()
	local panelShown = self.state ~= nil or self.showingResult
	self.panel.Visible = panelShown
	self.root.Visible = panelShown
end

function Reel:newRound()
	local state = self.state
	state.gauge = if state.gauge == 1 then 2 else 1
	state.t, state.direction = 0, 1
	-- The zone always starts ahead of the needle, so every hit takes travel time.
	state.zone = self.random:NextNumber(0.3, 1 - state.tuning.zoneSize)
	state.zoneDirection = if self.random:NextNumber() < 0.5 then -1 else 1
end

function Reel:pull()
	local state = self.state
	if not state or state.result or os.clock() < state.lockUntil then
		return
	end
	if state.t >= state.zone and state.t <= state.zone + state.tuning.zoneSize then
		state.progress += state.tuning.gain
		state.flash, state.flashColor = 0.25, ZONE
		state.lockUntil = os.clock() + 0.12
		state.jolt = 1
		FishingAudio.pull()
		self:newRound()
	else
		state.progress -= state.tuning.missPenalty
		state.flash, state.flashColor = 0.35, rgb(226, 72, 60)
		state.lockUntil = os.clock() + 0.4
		state.shake = 0.3
		FishingAudio.miss()
	end
end

function Reel:abort()
	if self.state and not self.state.result then
		self.state.result = "Aborted"
	end
end

function Reel:render(state, dt: number)
	local now = os.clock()
	for index, gauge in self.gauges do
		local active = index == state.gauge
		for _, rimFrame in gauge.rims do
			rimFrame.BackgroundColor3 = if active then BRONZE else BRONZE_DIM
		end
		for _, segment in gauge.segments do
			local inZone = active and segment.t >= state.zone and segment.t <= state.zone + state.tuning.zoneSize
			segment.frame.BackgroundColor3 = if inZone then ZONE elseif active then TRACK else TRACK_DIM
		end
	end
	local gauge = self.gauges[state.gauge]
	local shake = if state.shake > 0 then math.sin(now * 90) * 4 * state.shake / 0.3 else 0
	local angle = gauge.from + (gauge.to - gauge.from) * state.t + shake
	local point = arcPoint(angle, RADIUS)
	self.needle.Position = UDim2.fromOffset(point.X, point.Y)
	self.needle.Rotation = angle
	local outer = arcPoint(angle, RADIUS + THICKNESS / 2 + 12)
	self.needleTip.Position = UDim2.fromOffset(outer.X, outer.Y)
	self.needleTip.Rotation = angle + 45
	local y = self.meterBottom + (self.meterTop - self.meterBottom) * math.clamp(state.progress, 0, 1)
	self.marker.Position = UDim2.fromOffset(34 + math.sin(now * 9) * 1.5, y)
	local flash = math.clamp(state.flash / 0.25, 0, 1)
	self.panelStroke.Color = BRONZE:Lerp(state.flashColor, flash)
	self.markerStroke.Color = INK:Lerp(state.flashColor, flash)
	self.pullStroke.Color = if now < state.lockUntil and state.flashColor ~= ZONE then rgb(120, 120, 116) else WHITE
	local camera = state.camera
	if camera then
		local focus, distance = camera:GetAttribute("Focus"), camera:GetAttribute("Distance")
		local thrash = 0.08 + state.difficulty * 0.16
		local yaw = math.sin(now * (5 + state.difficulty * 6)) * thrash + state.jolt * 0.35
		local pitch = math.cos(now * 3.3) * thrash * 0.4
		local direction = (CFrame.Angles(pitch, yaw, 0) * state.view).Unit
		camera.CFrame = CFrame.lookAt(focus + direction * distance, focus)
	end
	state.jolt = math.max(0, state.jolt - dt * 4)
end

-- Yields until the fight ends: "Landed", "Escaped" or "Aborted".
-- reelBoost is the server's Reel Speed upgrade for this cast.
function Reel:fight(fishId: string, difficulty: number, placeName: string?, reelBoost: number?): string
	self:abort()
	local fish = Catalog.Fish[fishId]
	local state = {
		tuning = FishCatch.tuning(difficulty, if type(reelBoost) == "number" then reelBoost else nil),
		difficulty = difficulty,
		progress = FishCatch.START_PROGRESS,
		gauge = 2,
		t = 0,
		direction = 1,
		zone = 0.5,
		zoneDirection = 1,
		lockUntil = 0,
		flash = 0,
		flashColor = ZONE,
		shake = 0,
		jolt = 0,
		seed = self.random:NextNumber(0, 10),
	}
	self.state = state
	self:newRound()
	self.showingResult = false
	self.result.Visible, self.fightView.Visible = false, true
	self.title.Text = if fish then FishCatch.title(fish) else "DISTURBED WATER"
	self.strength.Text = "Strength: " .. FishCatch.strength(difficulty)
	self.place.Text = string.upper(placeName or "Main Lake")
	local model, camera = FishModels.show(self.silhouette, fishId, true)
	if model and camera then
		state.camera = camera
		state.view = (model:GetAttribute("ViewDirection") :: Vector3).Unit
	end
	self:refreshVisibility()
	while not state.result do
		local dt = math.min(RunService.RenderStepped:Wait(), 0.1)
		local tuning = state.tuning
		local speed = tuning.needleSpeed
		if tuning.erratic then
			speed *= 1 + 0.45 * math.sin(os.clock() * 3.1 + state.seed) * math.sin(os.clock() * 1.7)
		end
		state.t += state.direction * speed * dt
		if state.t > 1 then
			state.t, state.direction = 2 - state.t, -1
		elseif state.t < 0 then
			state.t, state.direction = -state.t, 1
		end
		if tuning.zoneDrift > 0 then
			state.zone += state.zoneDirection * tuning.zoneDrift * dt
			local maximum = 1 - tuning.zoneSize
			if state.zone > maximum then
				state.zone, state.zoneDirection = maximum, -1
			elseif state.zone < 0 then
				state.zone, state.zoneDirection = 0, 1
			end
		end
		state.progress -= tuning.drain * dt
		state.flash = math.max(0, state.flash - dt)
		state.shake = math.max(0, state.shake - dt)
		if state.progress >= 1 then
			state.result = "Landed"
		elseif state.progress <= 0 then
			state.result = "Escaped"
		end
		self:render(state, dt)
	end
	if self.state == state then
		self.state = nil
	end
	self:refreshVisibility()
	return state.result
end

local resultId = 0
local function holdResult(self, seconds: number)
	resultId += 1
	local current = resultId
	self.showingResult = true
	self.fightView.Visible, self.result.Visible = false, true
	self:refreshVisibility()
	task.delay(seconds, function()
		if resultId == current and self.showingResult then
			self.showingResult = false
			self:refreshVisibility()
		end
	end)
end

function Reel:showCatch(payload)
	if self.state then
		return
	end
	local fish = Catalog.Fish[payload.FishId]
	local rarity = fish and Catalog.Rarities[fish.Rarity]
	FishModels.show(self.trophy, payload.FishId, nil, payload)
	local mutation = FishMutations.label(payload.Mutation, payload.NeonColor)
	self.resultTitle.Text =
		string.upper((if mutation ~= "" then mutation .. " " else "") .. (if fish then fish.Name else payload.FishId))
	self.rarityBadge.Visible = rarity ~= nil
	if rarity then
		self.rarityBadge.BackgroundColor3 = rarity.Color
		self.rarityLabel.Text = string.upper(rarity.Name)
	end
	self.sizeBadge.Visible = payload.Size == "Huge" or payload.Size == "Big"
	self.sizeBadge.BackgroundColor3 = if payload.Size == "Huge" then rgb(255, 196, 70) else rgb(220, 220, 214)
	self.sizeLabel.Text = if payload.Size == "Huge" then "HUGE!" else "BIG"
	self.weight.Text = FishCatch.formatKg(payload.Kg)
	local multiplier = FishMutations.multiplier(payload.Mutation, payload.Corruptions)
	self.worth.Text = "Worth $"
		.. tostring(payload.Value)
		.. (if multiplier > 1 then string.format("  (×%g mutation)", multiplier) else "")
	self.footer.Text = if not payload.Saved
		then "Your catch couldn't be saved. Please try again."
		elseif payload.AutoStored then "Auto Store placed your catch in your boat's hold."
		elseif payload.Stored then "Added to your hotbar. Stow it in your boat's hold or take it to your freezer."
		else "Your hands were full, so you released it. It still counts in your bestiary."
	holdResult(self, 5)
	local spin = resultId
	local camera = self.trophy.CurrentCamera
	if camera then
		task.spawn(function()
			local focus, distance = camera:GetAttribute("Focus"), camera:GetAttribute("Distance")
			local look = (camera.CFrame.Position - focus).Unit
			local started = os.clock()
			while resultId == spin and self.showingResult and camera.Parent do
				local angle = math.sin((os.clock() - started) * 0.9) * 0.5
				camera.CFrame = CFrame.lookAt(focus + CFrame.Angles(0, angle, 0) * look * distance, focus)
				RunService.RenderStepped:Wait()
			end
		end)
	end
end

function Reel:showMessage(title: string, message: string)
	if self.state then
		return
	end
	for _, child in self.trophy:GetChildren() do
		child:Destroy()
	end
	self.resultTitle.Text = title
	self.rarityBadge.Visible, self.sizeBadge.Visible = false, false
	self.weight.Text, self.worth.Text = "", ""
	self.footer.Text = message
	holdResult(self, 2.5)
end

return Reel
