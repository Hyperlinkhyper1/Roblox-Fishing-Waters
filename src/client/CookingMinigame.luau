-- Hand-cooking minigame shown inside the Kitchen card. A recipe is a short run of
-- steps from Recipes.Steps: mash (click fast), timing (click while the marker is
-- in the green) and hold (hold, release in the green). Mouse, touch, Space and
-- gamepad A all work. Each step scores 0..1; `finished` gets the average, which
-- the server turns into the dish's grade (Recipes.grade).
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))
local Recipes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Recipes"))

local CookingMinigame = {}

local ACTION = "CookingMinigame"
local INTRO = Recipes.STEP_PAUSE * 0.55
local RESULT = Recipes.STEP_PAUSE - INTRO
local PAD_COLOR = Color3.fromRGB(39, 88, 128)
local PAD_PRESSED = Color3.fromRGB(82, 163, 229)
local BURN = Color3.fromRGB(226, 96, 64)

local function make(class: string, parent: Instance?, props: { [string]: any }): any
	local item = Instance.new(class)
	for key, value in props do
		item[key] = value
	end
	item.Parent = parent
	return item
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local item = make("TextLabel", parent, { BackgroundTransparency = 1, TextWrapped = true })
	Theme.text(item, props.TextColor3)
	for key, value in props do
		item[key] = value
	end
	return item
end

-- Closeness to a zone centre: dead centre is Perfect, anywhere inside is Good.
local function accuracy(position: number, centre: number, width: number): number
	local distance = math.abs(position - centre)
	if distance <= width * 0.2 then
		return 1
	elseif distance <= width / 2 then
		return 0.75
	elseif distance <= width then
		return 0.4
	end
	return 0.15
end

local function verdict(score: number): string
	return if score >= 0.9 then "Perfect!" elseif score >= 0.7 then "Great!" elseif score >= 0.45 then "Good" else "Sloppy…"
end

-- Runs `steps` inside `parent` and returns a function that stops and removes it.
function CookingMinigame.run(parent: GuiObject, steps: { any }, finished: (quality: number) -> ()): () -> ()
	local root = make("TextButton", parent, {
		Name = "CookingMinigame",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
	})
	local heading = label(root, {
		Name = "Step",
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local hint = label(root, {
		Name = "Hint",
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 13,
		Font = Enum.Font.Gotham,
		TextColor3 = Theme.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local bar = make("Frame", root, {
		Name = "Bar",
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 36),
		ClipsDescendants = true,
	})
	Theme.panel(bar, true, 8)
	local fill = make("Frame", bar, {
		Name = "Fill",
		BackgroundColor3 = Theme.Colors.Blue,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	})
	local zone = make("Frame", bar, {
		Name = "Zone",
		BackgroundColor3 = Theme.Colors.Green,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.2, 1),
	})
	make("Frame", zone, {
		Name = "Sweet",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.4, 1),
		BackgroundColor3 = Theme.Colors.Green,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
	})
	local marker = make("Frame", bar, {
		Name = "Marker",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.new(0, 6, 1, 0),
		BackgroundColor3 = Theme.Colors.Text,
		BorderSizePixel = 0,
		ZIndex = 3,
	})
	local clock = make("Frame", root, {
		Name = "Clock",
		Position = UDim2.fromOffset(0, 100),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Theme.Colors.Inset,
		BorderSizePixel = 0,
	})
	Theme.corner(clock, 3)
	local clockFill = make("Frame", clock, {
		Name = "Left",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Muted,
		BorderSizePixel = 0,
	})
	Theme.corner(clockFill, 3)
	local feedback = label(root, {
		Name = "Feedback",
		Position = UDim2.fromOffset(0, 114),
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = 26,
		Text = "",
	})
	local pad = label(root, {
		Name = "Pad",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundTransparency = 0,
		BackgroundColor3 = PAD_COLOR,
		TextSize = 22,
		Text = "",
	})
	Theme.corner(pad, 10)
	make("UIStroke", pad, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Theme.Colors.Border,
		Transparency = 0.35,
	})

	local index = 0
	local step = nil
	local phase = "intro"
	local elapsed = 0
	local scores: { number } = {}
	local clicks, held, gauge = 0, false, 0
	local hits: { number } = {}
	local centre = 0.5
	local alive = true
	local connection: RBXScriptConnection

	local function placeZone(width: number)
		zone.Position = UDim2.fromScale(centre - width / 2, 0)
		zone.Size = UDim2.fromScale(width, 1)
	end
	local function flashPad()
		pad.BackgroundColor3 = PAD_PRESSED
		task.delay(0.07, function()
			if alive and not held then
				pad.BackgroundColor3 = PAD_COLOR
			end
		end)
	end
	local function stop()
		if not alive then
			return
		end
		alive = false
		connection:Disconnect()
		ContextActionService:UnbindAction(ACTION)
		root:Destroy()
	end
	local function finishStep(score: number, text: string?)
		table.insert(scores, score)
		phase, elapsed, held = "result", 0, false
		feedback.Text = text or verdict(score)
		feedback.TextColor3 = if score >= 0.7 then Theme.Colors.Green elseif score >= 0.45 then Theme.Colors.Text else BURN
		pad.BackgroundColor3 = PAD_COLOR
		pad.Text = ""
	end
	local function nextStep()
		index += 1
		step = steps[index]
		if not step then
			local total = 0
			for _, score in scores do
				total += score
			end
			local quality = if #scores > 0 then total / #scores else 0
			phase = "done"
			local grade = Recipes.grade(quality)
			heading.Text = grade.Name .. " dish!"
			hint.Text = "Plating…"
			feedback.Text = ""
			pad.Text = ""
			task.spawn(finished, quality)
			return
		end
		phase, elapsed = "intro", 0
		clicks, held, gauge, hits = 0, false, 0, {}
		heading.Text = string.format("Step %d/%d · %s", index, #steps, step.Text)
		hint.Text = if step.Kind == "Mash"
			then string.format("Click %d times before time runs out!", step.Clicks)
			elseif step.Kind == "Timing" then (if step.Hits > 1
				then string.format("Click while the marker is in the green (%d times).", step.Hits)
				else "Click while the marker is in the green.")
			else "Hold the button, let go when the bar is in the green."
		feedback.Text, feedback.TextColor3 = "Get ready…", Theme.Colors.Muted
		pad.Text = ""
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = Theme.Colors.Blue
		clockFill.Size = UDim2.fromScale(1, 1)
		zone.Visible = step.Kind ~= "Mash"
		marker.Visible = step.Kind ~= "Mash"
		marker.Position = UDim2.fromScale(0, 0)
		if step.Kind == "Timing" then
			centre = 0.25 + math.random() * 0.5
			placeZone(step.Zone)
		elseif step.Kind == "Hold" then
			centre = step.Target
			placeZone(step.Zone)
		end
	end

	local function press()
		if not alive or phase ~= "play" then
			return
		end
		if step.Kind == "Mash" then
			clicks += 1
			flashPad()
			fill.Size = UDim2.fromScale(math.min(1, clicks / step.Clicks), 1)
			if clicks >= step.Clicks then
				finishStep(if elapsed <= step.Time * 0.75 then 1 else 0.8)
			end
		elseif step.Kind == "Timing" then
			local position = marker.Position.X.Scale
			local score = accuracy(position, centre, step.Zone)
			table.insert(hits, score)
			flashPad()
			if #hits >= step.Hits then
				local total = 0
				for _, value in hits do
					total += value
				end
				finishStep(total / #hits)
			else
				feedback.Text = verdict(score)
				feedback.TextColor3 = if score >= 0.7 then Theme.Colors.Green else BURN
				centre = 0.15 + math.random() * 0.7
				placeZone(step.Zone)
			end
		elseif step.Kind == "Hold" then
			held = true
			pad.BackgroundColor3 = PAD_PRESSED
			pad.Text = "Let go in the green!"
		end
	end
	local function release()
		if not alive or phase ~= "play" or not step or step.Kind ~= "Hold" or not held then
			return
		end
		held = false
		pad.BackgroundColor3 = PAD_COLOR
		if gauge < 0.03 then
			pad.Text = "Hold!"
			return
		end
		finishStep(accuracy(gauge, step.Target, step.Zone))
	end

	connection = RunService.RenderStepped:Connect(function(dt: number)
		if not alive or phase == "done" then
			return
		end
		elapsed += dt
		if phase == "intro" then
			if elapsed >= INTRO then
				phase, elapsed = "play", 0
				feedback.Text = ""
				pad.Text = if step.Kind == "Hold" then "Hold!" else "Click!"
			end
			return
		elseif phase == "result" then
			if elapsed >= RESULT then
				nextStep()
			end
			return
		end
		if step.Kind == "Mash" then
			clockFill.Size = UDim2.fromScale(math.max(0, 1 - elapsed / step.Time), 1)
			if elapsed >= step.Time then
				finishStep(0.6 * clicks / step.Clicks, "Too slow!")
			end
		elseif step.Kind == "Timing" then
			local limit = step.Hits * 3
			local sweep = (elapsed * step.Speed) % 2
			marker.Position = UDim2.fromScale(if sweep <= 1 then sweep else 2 - sweep, 0)
			clockFill.Size = UDim2.fromScale(math.max(0, 1 - elapsed / limit), 1)
			if elapsed >= limit then
				local total = 0
				for _, value in hits do
					total += value
				end
				total += 0.15 * (step.Hits - #hits)
				finishStep(total / step.Hits, "Too slow!")
			end
		elseif step.Kind == "Hold" then
			local limit = step.Fill * 3
			clockFill.Size = UDim2.fromScale(math.max(0, 1 - elapsed / limit), 1)
			if held then
				gauge = math.min(1, gauge + dt / step.Fill)
				fill.Size = UDim2.fromScale(gauge, 1)
				marker.Position = UDim2.fromScale(gauge, 0)
				fill.BackgroundColor3 = if gauge > step.Target + step.Zone / 2 then BURN else Theme.Colors.Blue
				if gauge >= 1 then
					finishStep(0.1, "Burnt!")
				end
			elseif elapsed >= limit then
				finishStep(0.15, "Too slow!")
			end
		end
	end)

	root.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			press()
		end
	end)
	root.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			release()
		end
	end)
	-- Leaving the area while holding counts as letting go.
	root.MouseLeave:Connect(release)
	ContextActionService:BindActionAtPriority(ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			press()
		elseif state == Enum.UserInputState.End then
			release()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2)

	nextStep()
	return stop
end

return CookingMinigame
