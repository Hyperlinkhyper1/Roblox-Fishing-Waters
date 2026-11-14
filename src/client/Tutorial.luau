-- The island tutorial on the client: the guide dialogue, the goal tracker, and the arrows that lead
-- to whoever is next (a marker above the guide plus a 3D arrow beside the player). Progress comes
-- from the TutorialStep/TutorialDone attributes; the server saves a step only after the player
-- finishes talking to the right guide.
--
-- Café companies get the café tour (Shared.CafeTutorial) through the same tracker, dialogue and
-- arrows: Bea in their café, then the coffee machine, the customer at the till and the office PC.
-- It comes first while it is unfinished; café-only companies never see the harbour tour.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))
local Tutorial = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tutorial"))
local CafeTutorial = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CafeTutorial"))
local CafeCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CafeCatalog"))

-- Names this module's per-frame work in the MicroProfiler (otherwise it is all "Script_Client").
local function profiled<A...>(label: string, callback: (A...) -> ()): (A...) -> ()
	if not debug.profilebegin then
		return callback -- test runners without the MicroProfiler API
	end
	return function(...: A...)
		debug.profilebegin(label)
		callback(...)
		debug.profileend()
	end
end

local Client = {}
local started = false

local GOLD = Color3.fromRGB(255, 205, 64)
local PROMPT = "TutorialNpcPrompt"
local CAFE_PROMPT = "CafeMentorPrompt"
local GUIDE_TAG = "TutorialGuide"
local TYPE_SPEED = 70 -- characters per second
local WALK_AWAY = 18 -- studs from the guide before an open dialogue closes
local TURN_RANGE = 14 -- guides turn to face the player inside this distance
local ARROW_HIDE = 14 -- the 3D arrow gives way to the marker this close to the guide
local MARKER_LIFT = 8.5 -- marker height above a guide's feet

local function label(parent: Instance, props): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.TextWrapped = true
	for key, value in props do
		item[key] = value
	end
	Theme.text(item, props.TextColor3)
	item.Font = props.Font or Enum.Font.GothamBold
	item.Parent = parent
	return item
end

-- A flat chevron arrow of neon parts, pointing along its pivot's look vector.
local function arrowModel(): Model
	local model = Instance.new("Model")
	model.Name = "TutorialArrow"
	local function piece(size: Vector3, frame: CFrame): Part
		local part = Instance.new("Part")
		part.Size = size
		part.CFrame = frame
		part.Color = GOLD
		part.Material = Enum.Material.Neon
		part.Anchored = true
		part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
		part.CastShadow = false
		part.Parent = model
		return part
	end
	-- Shaft behind the tip at -z, and two barbs sweeping back from the tip
	piece(Vector3.new(0.5, 0.25, 2.6), CFrame.new(0, 0, 0.2))
	for _, side in { -1, 1 } do
		piece(Vector3.new(0.5, 0.25, 1.7), CFrame.new(side * 0.5, 0, -1) * CFrame.Angles(0, side * math.rad(40), 0))
	end
	model.WorldPivot = CFrame.new()
	return model
end

function Client.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local state = ReplicatedStorage:WaitForChild("Tutorial")
	local remote = state:WaitForChild("Request") :: RemoteEvent
	-- The café tour's remote arrives with CafeTutorialService, after the harbour's.
	local cafeRemote: RemoteEvent? = nil

	-- Which tour the tracker, arrows and Skip button belong to right now.
	local function cafeTour(): boolean
		return player:GetAttribute("BranchCafe") == true
			and player:GetAttribute("CafeTutorialDone") == false
			and type(player:GetAttribute("CafeTutorialStep")) == "number"
	end
	local function harbourTour(): boolean
		local step = player:GetAttribute("TutorialStep")
		return player:GetAttribute("BranchFishing") ~= false
			and player:GetAttribute("TutorialDone") == false
			and type(step) == "number"
			and Tutorial.Steps[step] ~= nil
	end
	local function activeTour(): string?
		if cafeTour() then
			return "Cafe"
		elseif harbourTour() then
			return "Harbour"
		end
		return nil
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "Tutorial"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 24
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	------------------------------------------------------------------------------------------------
	-- Goal tracker

	local tracker = Instance.new("Frame")
	tracker.Name = "Tracker"
	tracker.AnchorPoint = Vector2.new(0.5, 0)
	tracker.Position = UDim2.new(0.5, 0, 0, 8)
	tracker.Size = UDim2.new(0.9, 0, 0, 58)
	tracker.Visible = false
	tracker.Parent = gui
	Theme.glassPanel(tracker)
	Theme.corner(tracker, 8)
	local trackerBounds = Instance.new("UISizeConstraint")
	trackerBounds.MaxSize = Vector2.new(460, 58)
	trackerBounds.Parent = tracker
	local heading = label(tracker, {
		Name = "Heading",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -110, 0, 16),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = GOLD,
		Text = "TUTORIAL",
	})
	local goal = label(tracker, {
		Name = "Goal",
		Position = UDim2.fromOffset(12, 23),
		Size = UDim2.new(1, -110, 0, 30),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.GothamMedium,
	})
	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.AnchorPoint = Vector2.new(1, 0.5)
	skip.Position = UDim2.new(1, -8, 0.5, 0)
	skip.Size = UDim2.fromOffset(88, 30)
	skip.Text = "Skip"
	skip.TextSize = 13
	skip.TextWrapped = true
	skip.Parent = tracker
	Theme.button(skip)
	local confirmSkip = false
	skip.Activated:Connect(function()
		if not confirmSkip then
			confirmSkip = true
			skip.Text = "Sure? Skip"
			Theme.button(skip, "Danger")
			task.delay(4, function()
				if confirmSkip then
					confirmSkip = false
					skip.Text = "Skip"
					Theme.button(skip)
				end
			end)
			return
		end
		confirmSkip = false
		skip.Text = "Skip"
		Theme.button(skip)
		if activeTour() == "Cafe" then
			if cafeRemote then
				cafeRemote:FireServer("Skip")
			end
		else
			remote:FireServer("Skip")
		end
	end)

	------------------------------------------------------------------------------------------------
	-- Toast

	local toast = label(gui, {
		Name = "TutorialNotice",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.new(0.86, 0, 0, 44),
		TextSize = 15,
		Font = Enum.Font.GothamMedium,
		Visible = false,
		ZIndex = 5,
	})
	toast.BackgroundTransparency = 0.06
	Theme.panel(toast, false, 6)
	toast.BackgroundColor3 = Theme.Colors.Window
	local toastBounds = Instance.new("UISizeConstraint")
	toastBounds.MaxSize = Vector2.new(520, 44)
	toastBounds.Parent = toast
	local toastId = 0
	local function notice(message: string)
		toastId += 1
		local current = toastId
		toast.Text, toast.Visible = message, true
		task.delay(6, function()
			if toastId == current then
				toast.Visible = false
			end
		end)
	end

	------------------------------------------------------------------------------------------------
	-- Dialogue

	local dialogue = Instance.new("Frame")
	dialogue.Name = "Dialogue"
	dialogue.AnchorPoint = Vector2.new(0.5, 1)
	dialogue.Position = UDim2.new(0.5, 0, 1, -24)
	dialogue.Size = UDim2.new(0.92, 0, 0, 168)
	dialogue.Visible = false
	dialogue.Active = true
	dialogue.ZIndex = 10
	dialogue.Parent = gui
	Theme.window(dialogue)
	local dialogueBounds = Instance.new("UISizeConstraint")
	dialogueBounds.MaxSize = Vector2.new(640, 168)
	dialogueBounds.Parent = dialogue
	local speaker = label(dialogue, {
		Name = "Speaker",
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.new(1, -40, 0, 22),
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = GOLD,
		RichText = true,
		ZIndex = 11,
	})
	local line = label(dialogue, {
		Name = "Line",
		Position = UDim2.fromOffset(20, 42),
		Size = UDim2.new(1, -40, 1, -98),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.GothamMedium,
		ZIndex = 11,
	})
	local pageCount = label(dialogue, {
		Name = "Page",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -18),
		Size = UDim2.fromOffset(80, 20),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Colors.Muted,
		ZIndex = 11,
	})
	local nextButton = Instance.new("TextButton")
	nextButton.Name = "Next"
	nextButton.AnchorPoint = Vector2.new(1, 1)
	nextButton.Position = UDim2.new(1, -16, 1, -14)
	nextButton.Size = UDim2.fromOffset(120, 36)
	nextButton.TextSize = 16
	nextButton.ZIndex = 11
	nextButton.Parent = dialogue
	Theme.button(nextButton, "Selected")
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 1)
	closeButton.Position = UDim2.new(1, -144, 1, -14)
	closeButton.Size = UDim2.fromOffset(84, 36)
	closeButton.Text = "Bye"
	closeButton.TextSize = 15
	closeButton.ZIndex = 11
	closeButton.Parent = dialogue
	Theme.button(closeButton)

	local talking: { npc: string, cafe: boolean, lines: { string }, page: number, current: boolean, typed: number }? =
		nil
	local typing = 0

	local function closeDialogue()
		talking = nil
		dialogue.Visible = false
	end

	local function showPage()
		local chat = talking
		if not chat then
			return
		end
		local text = chat.lines[chat.page]
		line.Text = text
		line.MaxVisibleGraphemes = 0
		chat.typed = 0
		pageCount.Text = chat.page .. " / " .. #chat.lines
		nextButton.Text = if chat.page < #chat.lines then "Next" else (if chat.current then "Got it!" else "Bye")
		closeButton.Visible = chat.page < #chat.lines
		typing += 1
		local generation = typing
		task.spawn(function()
			local length = utf8.len(text) or #text
			local shown = 0
			while talking == chat and generation == typing and shown < length do
				shown = math.min(length, shown + math.max(1, math.floor(TYPE_SPEED * task.wait())))
				line.MaxVisibleGraphemes = shown
			end
			if generation == typing then
				line.MaxVisibleGraphemes = -1
			end
		end)
	end

	local function advance()
		local chat = talking
		if not chat then
			return
		end
		-- The first press finishes the line being typed.
		if line.MaxVisibleGraphemes ~= -1 then
			typing += 1
			line.MaxVisibleGraphemes = -1
			return
		end
		if chat.page < #chat.lines then
			chat.page += 1
			showPage()
			return
		end
		closeDialogue()
		if chat.current then
			if chat.cafe then
				if cafeRemote then
					cafeRemote:FireServer("Finish")
				end
			else
				remote:FireServer("Finish", chat.npc)
			end
		end
	end

	local function openDialogue(npcId: string)
		local npc = Tutorial.Npcs[npcId]
		if not npc then
			return
		end
		local lines, current =
			Tutorial.dialogue(npcId, player:GetAttribute("TutorialStep"), player:GetAttribute("TutorialDone"))
		if #lines == 0 then
			return
		end
		talking = { npc = npcId, cafe = false, lines = lines, page = 1, current = current, typed = 0 }
		speaker.Text = npc.Name .. '  <font color="#D7D7D7" size="14">' .. npc.Title .. "</font>"
		dialogue.Visible = true
		showPage()
	end

	-- Bea, in the player's own café (the café client hides her prompt in other companies' cafés).
	local function openCafeDialogue()
		local mentor = CafeTutorial.Mentor
		local step = player:GetAttribute("CafeTutorialStep")
		local done = player:GetAttribute("CafeTutorialDone") ~= false or player:GetAttribute("BranchCafe") ~= true
		local lines, current = CafeTutorial.dialogue(if type(step) == "number" then step else nil, done)
		if #lines == 0 then
			return
		end
		talking = { npc = mentor.Id, cafe = true, lines = lines, page = 1, current = current, typed = 0 }
		speaker.Text = mentor.Name .. '  <font color="#D7D7D7" size="14">' .. mentor.Title .. "</font>"
		dialogue.Visible = true
		showPage()
	end

	nextButton.Activated:Connect(advance)
	closeButton.Activated:Connect(closeDialogue)
	dialogue.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			if line.MaxVisibleGraphemes ~= -1 then
				advance()
			end
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not talking or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA then
			advance()
		elseif not processed and input.KeyCode == Enum.KeyCode.Escape then
			closeDialogue()
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == PROMPT and not talking then
			local id = prompt:GetAttribute("NpcId")
			if type(id) == "string" then
				openDialogue(id)
			end
		elseif prompt.Name == CAFE_PROMPT and not talking then
			openCafeDialogue()
		end
	end)

	local function onServer(title: string, kind: any, value: any)
		if kind == "Finished" then
			notice(
				if type(value) == "number" and value > 0
					then title .. " complete! +$" .. value .. " · Type /tutorial to replay it."
					else title .. " complete! Type /tutorial to replay it any time."
			)
		elseif kind == "Notice" and type(value) == "string" then
			closeDialogue()
			notice(value)
		end
	end
	remote.OnClientEvent:Connect(function(kind, value)
		onServer("Tutorial", kind, value)
	end)
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("CafeTutorial")
		local request = folder:WaitForChild("Request") :: RemoteEvent
		cafeRemote = request
		request.OnClientEvent:Connect(function(kind, value)
			onServer("Café tutorial", kind, value)
		end)
	end)

	------------------------------------------------------------------------------------------------
	-- Arrows

	local marker = Instance.new("Part")
	marker.Name = "TutorialMarker"
	marker.Size = Vector3.new(0.2, 0.2, 0.2)
	marker.Transparency = 1
	marker.Anchored = true
	marker.CanCollide, marker.CanQuery, marker.CanTouch = false, false, false
	local markerGui = Instance.new("BillboardGui")
	markerGui.Name = "TutorialMarker"
	markerGui.Size = UDim2.fromOffset(150, 96)
	markerGui.AlwaysOnTop = true
	markerGui.LightInfluence = 0
	markerGui.MaxDistance = math.huge
	markerGui.Adornee = marker
	markerGui.Enabled = false
	markerGui.ResetOnSpawn = false
	-- Billboards only draw from PlayerGui itself, not from inside a ScreenGui.
	markerGui.Parent = gui.Parent
	local markerName = label(markerGui, {
		Name = "Name",
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 15,
		TextColor3 = GOLD,
	})
	local markerDistance = label(markerGui, {
		Name = "Distance",
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 16),
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
	})
	local markerArrow = label(markerGui, {
		Name = "Arrow",
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 60),
		TextSize = 54,
		TextColor3 = GOLD,
		Text = "▼",
	})

	local arrow = arrowModel()

	local function targetId(): string?
		if not harbourTour() then
			return nil
		end
		return Tutorial.Steps[player:GetAttribute("TutorialStep")].Npc
	end

	-- The player's own café plot, if it has streamed in.
	local function myCafe(): Instance?
		local companyId = player:GetAttribute("CompanyId")
		if type(companyId) ~= "string" or companyId == "" then
			return nil
		end
		for _, plot in CollectionService:GetTagged(CafeCatalog.PLOT_TAG) do
			if plot:GetAttribute("CompanyId") == companyId and plot:IsDescendantOf(workspace) then
				return plot
			end
		end
		return nil
	end

	-- The customer waiting at the front of the queue in the player's café (only they have a serve prompt).
	local function waitingCustomer(plot: Instance): BasePart?
		local frame = plot:GetAttribute("CafeFrame")
		local folder = workspace:FindFirstChild("CafeCustomers")
		if typeof(frame) ~= "CFrame" or not folder then
			return nil
		end
		for _, customer in folder:GetChildren() do
			local root = customer:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and root:FindFirstChild("ServeCoffee") then
				if (root.Position - frame.Position).Magnitude < 60 then
					return root
				end
			end
		end
		return nil
	end

	-- What the café tour points at now: (position, marker lift, marker name, goal text).
	local function cafeTarget(): (Vector3?, number, string, string?)
		local index = player:GetAttribute("CafeTutorialStep")
		local count = player:GetAttribute("CafeTutorialCount")
		count = if type(count) == "number" then count else 0
		local step = CafeTutorial.Steps[index]
		if not step then
			return nil, MARKER_LIFT, "", nil
		end
		local goalText = CafeTutorial.goal(index, count)
		local plot = myCafe()
		if not plot then
			return nil, MARKER_LIFT, "", goalText
		end
		local target = step.Target
		if target == "Customer" and player:GetAttribute("CarryingCoffee") ~= true then
			-- Serving needs a cup in hand first.
			target = "CoffeeMachine"
			local needed = step.Count or 1
			goalText = "Brew a coffee at the coffee machine, then serve the customer"
				.. (if needed > 1 then string.format(" (%d/%d)", count, needed) else "")
		end
		local name = CafeTutorial.Targets[target] or ""
		if target == "Mentor" then
			local position = plot:GetAttribute("MentorPosition")
			return if typeof(position) == "Vector3" then position else nil, MARKER_LIFT, name, goalText
		elseif target == "CoffeeMachine" then
			local machine = plot:FindFirstChild("CoffeeMachine", true)
			local body = machine and machine:IsA("Model") and machine.PrimaryPart
			return if body then body.Position else nil, 4, name, goalText
		elseif target == "Customer" then
			local root = waitingCustomer(plot)
			if not root then
				return nil, MARKER_LIFT, name, step.Waiting or goalText
			end
			return root.Position, 5.5, name, goalText
		elseif target == "OfficePc" then
			local desk = plot:FindFirstChild("OfficeDesk", true)
			local chair = desk and desk:FindFirstChild("Chair")
			local seat = chair and chair:FindFirstChild("Seat")
			return if seat and seat:IsA("BasePart") then seat.Position else nil, 6, name, goalText
		end
		return nil, MARKER_LIFT, name, goalText
	end

	local function refreshTracker()
		local tour = activeTour()
		tracker.Visible = tour ~= nil
		if tour == "Cafe" then
			local step = player:GetAttribute("CafeTutorialStep")
			heading.Text = string.format("CAFÉ TUTORIAL  %d / %d", step, #CafeTutorial.Steps)
			local _, _, name, goalText = cafeTarget()
			goal.Text = goalText or ""
			markerName.Text = name
		elseif tour == "Harbour" then
			local step = player:GetAttribute("TutorialStep")
			heading.Text = string.format("TUTORIAL  %d / %d", step, #Tutorial.Steps)
			goal.Text = Tutorial.Steps[step].Goal
			markerName.Text = Tutorial.Npcs[Tutorial.Steps[step].Npc].Name
		end
	end
	for _, attribute in {
		"TutorialStep",
		"TutorialDone",
		"CafeTutorialStep",
		"CafeTutorialDone",
		"CafeTutorialCount",
		"BranchCafe",
		"BranchFishing",
		"CarryingCoffee",
	} do
		player:GetAttributeChangedSignal(attribute):Connect(refreshTracker)
	end
	refreshTracker()

	-- Guides turn their heads (and bodies) to whoever walks up, locally for each player.
	local function turnGuides(root: BasePart, dt: number)
		for _, guide in CollectionService:GetTagged(GUIDE_TAG) do
			local home = guide:GetAttribute("HomeFrame")
			if not guide:IsA("Model") or typeof(home) ~= "CFrame" or not guide:IsDescendantOf(workspace) then
				continue
			end
			local pivot = guide:GetPivot()
			local offset = Vector3.new(root.Position.X - home.X, 0, root.Position.Z - home.Z)
			local wanted = home
			if offset.Magnitude < TURN_RANGE and offset.Magnitude > 0.5 then
				wanted = CFrame.lookAt(home.Position, home.Position + offset)
			end
			if
				pivot.LookVector:Dot(wanted.LookVector) < 0.9995
				or (pivot.Position - home.Position).Magnitude > 0.01
			then
				guide:PivotTo(pivot:Lerp(wanted, math.min(1, dt * 6)))
			end
		end
	end

	local clock = 0
	RunService.RenderStepped:Connect(profiled("Tutorial", function(dt)
		clock += dt
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			markerGui.Enabled = false
			arrow.Parent = nil
			return
		end
		turnGuides(root, dt)

		local chat = talking
		if chat then
			local position
			if chat.cafe then
				local plot = myCafe()
				position = plot and plot:GetAttribute("MentorPosition")
			else
				position = state:GetAttribute("Npc_" .. chat.npc)
			end
			if typeof(position) == "Vector3" and (root.Position - position).Magnitude > WALK_AWAY then
				closeDialogue()
			end
		end

		local position, lift = nil, MARKER_LIFT
		if activeTour() == "Cafe" then
			local name, goalText
			position, lift, name, goalText = cafeTarget()
			-- The café goal follows the queue and the cup in hand, so it can change between attributes.
			if goalText and goal.Text ~= goalText then
				goal.Text = goalText
			end
			if markerName.Text ~= name then
				markerName.Text = name
			end
		else
			local id = targetId()
			position = id and state:GetAttribute("Npc_" .. id)
		end
		if typeof(position) ~= "Vector3" then
			markerGui.Enabled = false
			arrow.Parent = nil
			return
		end
		local bob = math.sin(clock * 4) * 0.6
		marker.CFrame = CFrame.new(position + Vector3.new(0, lift + bob, 0))
		if not marker.Parent then
			marker.Parent = workspace
		end
		local distance = (root.Position - position).Magnitude
		markerDistance.Text = string.format("%d studs", math.floor(distance + 0.5))
		markerArrow.Position = UDim2.fromOffset(0, 32 + bob * 4)
		markerGui.Enabled = not talking

		local flat = Vector3.new(position.X - root.Position.X, 0, position.Z - root.Position.Z)
		if talking or distance < ARROW_HIDE or flat.Magnitude < 1 then
			arrow.Parent = nil
			return
		end
		local direction = flat.Unit
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local feet = root.Position.Y - (if humanoid then humanoid.HipHeight else 2) - root.Size.Y / 2
		local base = Vector3.new(root.Position.X, feet + 0.6 + math.sin(clock * 5) * 0.12, root.Position.Z)
		arrow:PivotTo(CFrame.lookAt(base + direction * 4.2, base + direction * 5.2))
		if not arrow.Parent then
			arrow.Parent = workspace
		end
	end))
end

return Client
