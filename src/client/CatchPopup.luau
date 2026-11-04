-- The landed-catch popup: the fish pops in over a spinning burst of rays in its
-- rarity colour, bobbing and flopping while the caption slides up beneath it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Catalog = require(ReplicatedStorage.Shared.AnglerCatalog)
local FishModels = require(ReplicatedStorage.Shared.FishModels)
local FishMutations = require(ReplicatedStorage.Shared.FishMutations)

local Popup = {}
Popup.__index = Popup

local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)
local MUTED = rgb(200, 200, 196)
local GOLD = rgb(255, 222, 120)
local GREEN = rgb(110, 224, 130)
local STAGE = Vector2.new(300, 190)
local RAYS = 10 -- Each bar crosses the centre, so this draws twice as many rays.
local RAY_LENGTH = 340
-- CanvasGroup clips its descendants, including the burst during its pop-in overshoot.
local TOP_PADDING = 110
local HOLD_SECONDS = 4.5
local LINE_HEIGHT = 34

local function make(class: string, parent: Instance?, props: { [string]: any }): any
	local item = Instance.new(class)
	for key, value in props do
		item[key] = value
	end
	item.Parent = parent
	return item
end

local function tween(
	item: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	local playing = TweenService:Create(
		item,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goal
	)
	playing:Play()
	return playing
end

local function hex(color: Color3): string
	return "#" .. color:ToHex()
end

local function paint(text: string, color: Color3, bold: boolean?): string
	local inner = if bold then "<b>" .. text .. "</b>" else text
	return string.format('<font color="%s">%s</font>', hex(color), inner)
end

local function formatKg(kg: number): string
	local text = string.format("%.1f", kg)
	return (string.gsub(text, "%.0$", ""))
end

local function article(name: string): string
	return if string.find(string.lower(name), "^[aeiou]") then "an" else "a"
end

function Popup.new(gui: ScreenGui)
	local self = setmetatable({}, Popup)
	self.showId = 0
	local root = make("CanvasGroup", gui, {
		Name = "CatchPopup",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -130),
		Size = UDim2.fromOffset(760, TOP_PADDING + STAGE.Y + LINE_HEIGHT * 3 + 10),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
	})
	self.root = root
	self.rootScale = make("UIScale", root, {})

	local stage = make("Frame", root, {
		Name = "Stage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(380, TOP_PADDING + STAGE.Y / 2),
		Size = UDim2.fromOffset(STAGE.X, STAGE.Y),
		BackgroundTransparency = 1,
	})
	self.stage = stage
	self.stageScale = make("UIScale", stage, { Scale = 0 })

	self.rays = {}
	for index = 1, RAYS do
		local wide = index % 2 == 0
		local ray = make("Frame", stage, {
			Name = "Ray",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(if wide then 30 else 14, if wide then RAY_LENGTH * 0.7 else RAY_LENGTH),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
		})
		make("UIGradient", ray, {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.42, 0.35),
				NumberSequenceKeypoint.new(0.5, 0.05),
				NumberSequenceKeypoint.new(0.58, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			}),
		})
		table.insert(self.rays, ray)
	end

	-- Stacked soft discs stand in for a radial glow behind the fish.
	self.glows = {}
	for _, disc in { { 170, 0.8 }, { 110, 0.62 }, { 60, 0.4 } } do
		local size = disc[1]
		local glow = make("Frame", stage, {
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = disc[2],
			BorderSizePixel = 0,
		})
		make("UICorner", glow, { CornerRadius = UDim.new(1, 0) })
		table.insert(self.glows, { frame = glow, size = size })
	end

	self.sparkles = {}
	for _ = 1, 10 do
		local sparkle = make("Frame", stage, {
			Name = "Sparkle",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(8, 8),
			Rotation = 45,
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			Visible = false,
		})
		table.insert(self.sparkles, sparkle)
	end

	self.viewport = make("ViewportFrame", stage, {
		Name = "Fish",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(STAGE.X, STAGE.Y),
		BackgroundTransparency = 1,
	})

	self.lines = {}
	for index = 1, 3 do
		local label = make("TextLabel", root, {
			Name = "Line" .. index,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(380, TOP_PADDING + STAGE.Y + (index - 1) * LINE_HEIGHT),
			Size = UDim2.new(1, 0, 0, LINE_HEIGHT),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSansSemibold,
			RichText = true,
			Text = "",
			TextColor3 = WHITE,
			TextScaled = true,
			TextTransparency = 1,
		})
		make("UITextSizeConstraint", label, { MaxTextSize = if index == 3 then 22 else 30 })
		local outline = make("UIStroke", label, { Thickness = 2, Color = rgb(12, 14, 24), Transparency = 1 })
		table.insert(self.lines, { label = label, stroke = outline })
	end

	RunService.RenderStepped:Connect(function()
		if root.Visible then
			self:animate(os.clock() - self.shownAt)
		end
	end)
	return self
end

function Popup:animate(t: number)
	local spin = t * self.spinSpeed
	local pulse = 1 + math.sin(t * 3) * 0.06
	for index, ray in self.rays do
		ray.Rotation = spin + (index - 1) * (180 / RAYS)
		ray.BackgroundColor3 = if index % 2 == 0 then self.color else self.color:Lerp(WHITE, 0.55)
	end
	for _, glow in self.glows do
		local size = glow.size * pulse
		glow.frame.Size = UDim2.fromOffset(size, size)
		glow.frame.BackgroundColor3 = self.color:Lerp(WHITE, 0.6)
	end
	-- A quick flop on landing that settles into a lazy bob.
	local flop = math.exp(-t * 2.2)
	self.viewport.Rotation = math.sin(t * 14) * 22 * flop + math.sin(t * 2.1) * 4
	self.viewport.Position = UDim2.new(0.5, 0, 0.5, math.sin(t * 2.6) * 6 - flop * 10)
	local camera = self.camera
	if camera and camera.Parent then
		local angle = math.sin(t * 0.9) * 0.45
		camera.CFrame = CFrame.lookAt(self.focus + CFrame.Angles(0, angle, 0) * self.look * self.distance, self.focus)
	end
	for _, sparkle in self.sparkles do
		local life = (t - sparkle:GetAttribute("Delay")) / 1.1
		sparkle.Visible = life > 0 and life < 1
		if sparkle.Visible then
			local direction = sparkle:GetAttribute("Direction") :: Vector2
			local reach = 40 + 110 * (1 - (1 - life) ^ 2)
			sparkle.Position = UDim2.new(0.5, direction.X * reach, 0.5, direction.Y * reach)
			sparkle.BackgroundTransparency = life
			local size = 10 * (1 - life * 0.6)
			sparkle.Size = UDim2.fromOffset(size, size)
		end
	end
	-- The weight counts up as the caption arrives.
	if self.kg and self.kgLine then
		local shown = self.kg * math.clamp((t - 0.25) / 0.7, 0, 1) ^ 0.5
		self.lines[self.kgLine].label.Text = string.format(self.kgTemplate, formatKg(shown))
	end
end

-- `lines` is a list of rich-text captions; "%s" in the line at `kgLine` is replaced by the weight.
function Popup:show(
	fishId: string,
	traits: any?,
	lines: { string },
	color: Color3,
	rarityOrder: number,
	kg: number?,
	kgLine: number?
)
	self.showId += 1
	local current = self.showId
	local _, fishCamera = FishModels.show(self.viewport, fishId, nil, traits)
	self.camera = fishCamera
	if fishCamera then
		self.focus, self.distance = fishCamera:GetAttribute("Focus"), fishCamera:GetAttribute("Distance")
		self.look = (fishCamera.CFrame.Position - self.focus).Unit
	end
	self.color = color
	self.spinSpeed = 18 + rarityOrder * 7
	-- Lines fill from the bottom so the fish's caption always sits closest to the fish.
	local first = 4 - #lines
	self.kg, self.kgLine, self.kgTemplate = kg, kgLine and kgLine + first - 1, kgLine and lines[kgLine]
	self.shownAt = os.clock()
	for _, sparkle in self.sparkles do
		local angle = math.random() * math.pi * 2
		sparkle:SetAttribute("Direction", Vector2.new(math.cos(angle), math.sin(angle) * 0.7))
		sparkle:SetAttribute("Delay", math.random() * 0.5)
		sparkle.BackgroundColor3 = color:Lerp(WHITE, 0.5)
	end

	local root = self.root
	root.Visible = true
	root.GroupTransparency = 0
	local camera = workspace.CurrentCamera
	local fit = if camera then math.clamp((camera.ViewportSize.X - 24) / root.Size.X.Offset, 0.45, 1) else 1
	self.rootScale.Scale = fit
	self.stageScale.Scale = 0
	tween(self.stageScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	for index, line in self.lines do
		local text = lines[index - first + 1]
		local slot = UDim2.fromOffset(380, TOP_PADDING + STAGE.Y + (index - 1) * LINE_HEIGHT)
		line.label.Text = if text then string.format(text, kg and formatKg(0) or "") else ""
		line.label.TextTransparency, line.stroke.Transparency = 1, 1
		line.label.Position = slot + UDim2.fromOffset(0, 14)
		if text then
			local delay = 0.15 + (index - first) * 0.12
			task.delay(delay, function()
				if self.showId == current then
					tween(line.label, 0.3, { TextTransparency = 0, Position = slot }, Enum.EasingStyle.Back)
					tween(line.stroke, 0.3, { Transparency = 0.2 })
				end
			end)
		end
	end
	local hold = HOLD_SECONDS + rarityOrder * 0.25
	task.delay(hold, function()
		if self.showId ~= current then
			return
		end
		tween(root, 0.35, { GroupTransparency = 1 })
		tween(self.rootScale, 0.35, { Scale = fit * 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.35)
		if self.showId == current then
			root.Visible = false
		end
	end)
end

function Popup:showCatch(payload)
	local fish = Catalog.Fish[payload.FishId]
	local rarity = fish and Catalog.Rarities[fish.Rarity]
	local color = if rarity then rarity.Color else WHITE
	local mutation = FishMutations.label(payload.Mutation, payload.NeonColor)
	local name = (if mutation ~= "" then mutation .. " " else "") .. (if fish then fish.Name else payload.FishId)
	local size = if payload.Size == "Huge"
		then paint("Huge ", GOLD, true)
		elseif payload.Size == "Big" then paint("Big ", GOLD, true)
		else ""
	local lead = article(if payload.Size == "Huge" or payload.Size == "Big" then payload.Size else name)
	local caption = string.format(
		"You just caught %s %s%s at %s",
		lead,
		size,
		paint(name, color, true),
		paint("%s", MUTED, true)
	) .. "kg!"
	if type(payload.Count) == "number" then
		caption ..= " (" .. paint(string.format("×%d", payload.Count), GOLD, true) .. ")"
	end
	local lines = {}
	if payload.Count == 1 then
		table.insert(lines, paint("<i>New species discovered!</i>", GREEN, true))
	end
	table.insert(lines, caption)
	local kgLine = #lines
	local detail = if not payload.Saved
		then "Your catch couldn't be saved. Please try again."
		elseif payload.AutoStored then "Stored in your boat's hold"
		elseif payload.BackpackStored then "Packed into your backpack"
		elseif payload.Stored then "Added to your hotbar"
		else "Your hands and backpack were full, so you released it"
	table.insert(
		lines,
		paint("Worth ", MUTED) .. paint("$" .. tostring(payload.Value), GREEN, true) .. paint("  ·  " .. detail, MUTED)
	)
	self:show(payload.FishId, payload, lines, color, rarity and rarity.Order or 1, payload.Kg, kgLine)
end

return Popup
