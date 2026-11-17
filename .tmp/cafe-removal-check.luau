assert(loadstring([====[-- The island tutorial on the client: the guide dialogue, the goal tracker, and the arrows that lead
-- to whoever is next (a marker above the guide plus a 3D arrow beside the player). Progress comes
-- from the TutorialStep/TutorialDone attributes; the server saves a step only after the player
-- finishes talking to the right guide.
--
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))
local Tutorial = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tutorial"))

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
	local function harbourTour(): boolean
		local step = player:GetAttribute("TutorialStep")
		return player:GetAttribute("BranchFishing") ~= false
			and player:GetAttribute("TutorialDone") == false
			and type(step) == "number"
			and Tutorial.Steps[step] ~= nil
	end
	local function activeTour(): string?
		if harbourTour() then
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
		remote:FireServer("Skip")
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

	local talking: { npc: string, lines: { string }, page: number, current: boolean, typed: number }? =
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
			remote:FireServer("Finish", chat.npc)
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
		talking = { npc = npcId, lines = lines, page = 1, current = current, typed = 0 }
		speaker.Text = npc.Name .. '  <font color="#D7D7D7" size="14">' .. npc.Title .. "</font>"
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

	local function refreshTracker()
		local tour = activeTour()
		tracker.Visible = tour ~= nil
		if tour == "Harbour" then
			local step = player:GetAttribute("TutorialStep")
			heading.Text = string.format("TUTORIAL  %d / %d", step, #Tutorial.Steps)
			goal.Text = Tutorial.Steps[step].Goal
			markerName.Text = Tutorial.Npcs[Tutorial.Steps[step].Npc].Name
		end
	end
	for _, attribute in {
		"TutorialStep",
		"TutorialDone",
		"BranchFishing",
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
			local position = state:GetAttribute("Npc_" .. chat.npc)
			if typeof(position) == "Vector3" and (root.Position - position).Magnitude > WALK_AWAY then
				closeDialogue()
			end
		end

		local id = targetId()
		local position, lift = id and state:GetAttribute("Npc_" .. id), MARKER_LIFT
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
]====], 'src/client/Tutorial.luau'))
assert(loadstring([====[-- The office PC in your own base house (Map/OfficeDesk). A "Use computer" prompt on the chair sits
-- you down (OfficeComputerService), the camera settles on the monitor, and the tube shows
-- HARBOUR-OS: a green-phosphor home screen with a pixel pointer that follows your mouse. The camera
-- holds still, square on to the glass, so the screen is a ScreenGui laid exactly over the glass's
-- projection each frame (Roblox's SurfaceGui mouse input never reached it, 2026-11-07).
-- Apps open in a window: Harbour Exchange (StockApp), Company Branches (BranchApp), the
-- Harbour Direct web shop (WebShopApp) and MY PC.
-- The same PC stands in each café's staff room (Map/CafePlots), usable by the café company's
-- members. What the company bought at Micro Harbour (Shared.TechCatalog, mirrored onto the
-- player as Tech<Slot> / License<Id> attributes) shows here: the monitor sets the screen's
-- colours, fonts and scanlines, the parts fill the boot screen and MY PC, and STOCKS stays
-- locked until the company owns a trading license (WEB SHOP until it owns a web shop license).
-- Jump or press EXIT to stand up.
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local RetroUI = require(script.Parent.RetroUI)
local StockApp = require(script.Parent.StockApp)
local WebShopApp = require(script.Parent.WebShopApp)
local Calendar = require(ReplicatedStorage.Shared.Calendar)
local Stocks = require(ReplicatedStorage.Shared.Stocks)
local TechCatalog = require(ReplicatedStorage.Shared.TechCatalog)

local OfficeComputer = {}

local BASE_TAG = "PlayerBase"
local CAFE_TAG = "CafePlot" -- café staff rooms (Shared.CafeCatalog.PLOT_TAG)
local PROMPT_NAME = "OfficeComputerPrompt"
local GUI_NAME = "OfficeComputerScreen"
-- Narrow field of view so the tube fills the view without fisheye.
local FOV = 40
-- Share of the view the glass fills (the rest shows the beige bezel).
local FILL = 0.86

local C = RetroUI.Colors
local px = UDim2.fromOffset

local player = Players.LocalPlayer

type Session = {
	Desk: Model,
	Seat: Seat,
	Screen: BasePart,
	Gui: ScreenGui,
	Connections: { RBXScriptConnection },
	App: { destroy: () -> () }?,
	Saved: { [string]: any },
	HiddenGuis: { LayerCollector },
	ScreenLabels: { SurfaceGui },
	Hidden: { BasePart | Decal },
}

local session: Session? = nil
local busy = false
local prompts: { [ProximityPrompt]: Instance } = {}
local promptDesks: { [ProximityPrompt]: Instance } = {}

local function notice(message: string)
	pcall(StarterGui.SetCore, StarterGui, "SendNotification", {
		Title = "Office PC",
		Text = message,
		Duration = 4,
	})
end

local function requestServer(action: string): (boolean, string?)
	local folder = ReplicatedStorage:FindFirstChild("OfficeComputer")
	local remote = folder and folder:FindFirstChild("Request")
	if not remote or not remote:IsA("RemoteFunction") then
		return false, "The computer isn't ready yet."
	end
	local ok, result = pcall(remote.InvokeServer, remote, action)
	if not ok or type(result) ~= "table" then
		return false, "The computer didn't respond. Try again."
	end
	return result.Ok == true, result.Message
end

local function ownerBase(desk: Instance): Instance?
	local node = desk.Parent
	while node and node ~= workspace do
		if CollectionService:HasTag(node, BASE_TAG) or CollectionService:HasTag(node, CAFE_TAG) then
			return node
		end
		node = node.Parent
	end
	return nil
end

-- A harbour base's PC belongs to its owner; a café's staff-room PC to its whole company.
local function canUse(base: Instance): boolean
	if CollectionService:HasTag(base, CAFE_TAG) then
		local companyId = base:GetAttribute("CompanyId")
		return type(companyId) == "string" and companyId ~= "" and companyId == player:GetAttribute("CompanyId")
	end
	return base:GetAttribute("OwnerUserId") == player.UserId
end

local function installed(slot: string)
	return TechCatalog.installed(slot, player:GetAttribute(TechCatalog.slotAttribute(slot)))
end

local function licensed(id: string): boolean
	return player:GetAttribute(TechCatalog.licenseAttribute(id)) == true
end

local function refreshPrompts()
	for prompt, base in prompts do
		local desk = promptDesks[prompt]
		prompt.Enabled = session == nil and canUse(base) and not (desk and desk:GetAttribute("PcAway") == true)
	end
end

----------------------------------------------------------------------------------------------------
-- Camera and seat

local function cameraTarget(screen: BasePart): CFrame
	local camera = workspace.CurrentCamera
	local view = camera.ViewportSize
	local aspect = view.X / math.max(view.Y, 1)
	local tanHalf = math.tan(math.rad(FOV / 2))
	local height, width = screen.Size.Y / FILL, screen.Size.X / FILL
	local distance = math.max(height / 2 / tanHalf, width / 2 / (tanHalf * aspect))
	local face = screen.CFrame * CFrame.new(0, 0, screen.Size.Z / 2)
	return CFrame.lookAt((face * CFrame.new(0, 0, distance)).Position, face.Position, screen.CFrame.UpVector)
end

-- The glass's rectangle on screen (viewport pixels): top-left corner and size.
local function screenRect(screen: BasePart): (Vector2, Vector2)
	local camera = workspace.CurrentCamera
	local face = screen.CFrame * CFrame.new(0, 0, screen.Size.Z / 2)
	local halfX, halfY = screen.Size.X / 2, screen.Size.Y / 2
	local low, high = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
	for _, corner in { Vector3.new(-halfX, halfY, 0), Vector3.new(halfX, -halfY, 0) } do
		local point = camera:WorldToViewportPoint((face * CFrame.new(corner)).Position)
		low = Vector2.new(math.min(low.X, point.X), math.min(low.Y, point.Y))
		high = Vector2.new(math.max(high.X, point.X), math.max(high.Y, point.Y))
	end
	return low, high - low
end

----------------------------------------------------------------------------------------------------
-- HARBOUR-OS

local function buildDesktop(root: Frame, current: Session, leave: () -> ())
	local status: TextLabel
	local function setStatus(text: string)
		status.Text = text
	end

	-- Menu bar in inverse video.
	local bar = RetroUI.frame(root, "MenuBar", px(0, 0), px(800, 34), {
		BackgroundTransparency = 0,
		BackgroundColor3 = C.Bright,
	})
	local logo = RetroUI.text(bar, "Logo", "HARBOUR-OS", px(14, 0), px(260, 34), {
		Font = RetroUI.Fonts.Title,
		Size = 16,
		Color = C.Screen,
	})
	logo.TextStrokeTransparency = 1
	local clock = RetroUI.text(bar, "Clock", "", px(380, 0), px(406, 34), {
		Size = 20,
		Color = C.Screen,
		AlignX = Enum.TextXAlignment.Right,
	})
	clock.TextStrokeTransparency = 1
	local function paintClock()
		local date = Calendar.now()
		local hour = math.floor(date.Hour)
		local minute = math.floor((date.Hour - hour) * 60)
		clock.Text = string.format(
			"%s  %02d:%02d   %s",
			string.upper(Calendar.format(date, true)),
			hour,
			minute,
			Stocks.money(player:GetAttribute("Cash") or 0)
		)
	end
	paintClock()

	-- Status line and the way out.
	RetroUI.rule(root, "StatusRule", px(0, 564), UDim.new(1, 0), C.Mid)
	status = RetroUI.text(root, "Status", "", px(14, 568), px(640, 30), { Size = 16, Color = C.Mid })
	RetroUI.button(root, "Exit", "EXIT", px(686, 568), px(100, 28), leave, { Font = RetroUI.Fonts.Title, Size = 14 })

	local desktop = RetroUI.frame(root, "Desktop", px(0, 36), px(800, 526))
	local window: Frame? = nil
	local readyText = "READY. CLICK AN APP TO OPEN IT.  JUMP OR EXIT TO STAND UP."
	-- Desktop apps: each mounts into the window's content frame and returns { destroy }.
	local APPS = {
		Stocks = {
			Name = "HARBOUR EXCHANGE",
			Title = StockApp.TITLE .. "  -  LIVE MARKET",
			Connecting = "CONNECTING TO HARBOUR EXCHANGE...",
			Ready = "PRICES UPDATE EVERY FEW SECONDS. DIVIDENDS PAY EVERY 7 IN-GAME DAYS.",
			mount = StockApp.mount,
			License = "StockExchange",
			LockNote = "SHARES YOU ALREADY OWN KEEP PAYING DIVIDENDS.",
		},
		WebShop = {
			Name = "WEB SHOP",
			Title = WebShopApp.TITLE .. "  -  " .. WebShopApp.SUBTITLE,
			Connecting = "DIALING UP " .. WebShopApp.TITLE .. "...",
			Ready = WebShopApp.READY,
			mount = WebShopApp.mount,
			License = "WebShop",
			LockNote = "UNTIL THEN, CAGES AND NETS ARE SOLD AT TIDE & TACKLE.",
		},
		System = {
			Name = "MY PC",
			Title = "MY PC  -  SYSTEM INFORMATION",
			Connecting = "READING HARDWARE...",
			Ready = "BUY PARTS AT " .. TechCatalog.STORE_NAME .. ", FIT THEM AT YOUR WORKBENCH.",
			mount = function(content: Frame)
				RetroUI.text(content, "Heading", "THIS COMPUTER", px(24, 14), px(720, 32), {
					Font = RetroUI.Fonts.Title,
					Size = 18,
					Color = C.Hot,
				})
				local row = math.min(50, math.floor(352 / #TechCatalog.Slots))
				for index, slot in TechCatalog.Slots do
					local item = installed(slot)
					local y = 56 + (index - 1) * row
					RetroUI.text(content, "Slot", string.upper(TechCatalog.SlotNames[slot]), px(24, y), px(190, 20), {
						Size = 15,
						Color = C.Mid,
					})
					RetroUI.text(content, "Part", string.upper(item.Name), px(220, y), px(530, 20), { Size = 18 })
					RetroUI.text(content, "Spec", string.upper(item.Spec), px(220, y + 19), px(530, 16), {
						Size = 13,
						Color = C.Mid,
					})
					RetroUI.rule(content, "Rule", px(24, y + row - 3), UDim.new(0, 720), C.Dim)
				end
				local owned = {}
				for _, id in TechCatalog.LicenseOrder do
					if licensed(id) then
						table.insert(owned, string.upper(TechCatalog.Licenses[id].Name))
					end
				end
				RetroUI.text(
					content,
					"Licenses",
					"LICENSES: " .. (if #owned > 0 then table.concat(owned, ", ") else "NONE"),
					px(24, 416),
					px(720, 24),
					{ Size = 18 }
				)
				RetroUI.text(
					content,
					"Upgrade",
					"PARTS, MONITORS AND LICENSES: " .. TechCatalog.STORE_NAME .. ", IN THE INDUSTRIAL DISTRICT.",
					px(24, 446),
					px(720, 24),
					{ Size = 15, Color = C.Mid }
				)
				return { destroy = function() end }
			end,
		},
	}

	local function closeWindow()
		if current.App then
			current.App.destroy()
			current.App = nil
		end
		if window then
			window:Destroy()
			window = nil
		end
		setStatus(readyText)
	end

	-- Classic zoom rectangle from the icon out to the window, then the window itself.
	local function openApp(from: GuiObject, spec)
		if window then
			return
		end
		-- Absolute sizes are scaled screen pixels; convert back to canvas pixels.
		local scale = math.max(root.AbsoluteSize.X / RetroUI.WIDTH, 1e-3)
		local start = (from.AbsolutePosition - root.AbsolutePosition) / scale
		local size = from.AbsoluteSize / scale
		local zoom = RetroUI.frame(root, "Zoom", px(start.X, start.Y), px(size.X, size.Y), {
			ZIndex = 40,
		})
		RetroUI.border(zoom, C.Hot, 2)
		local tween = TweenService:Create(zoom, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = px(16, 44),
			Size = px(768, 516),
		})
		tween:Play()
		tween.Completed:Wait()
		zoom:Destroy()
		if session ~= current or window then
			return
		end
		local frame = RetroUI.frame(root, "Window", px(16, 44), px(768, 516), {
			BackgroundTransparency = 0,
			BackgroundColor3 = C.Screen,
			ZIndex = 5,
		})
		RetroUI.border(frame, C.Bright, 2)
		window = frame
		local title = RetroUI.frame(frame, "TitleBar", px(0, 0), px(768, 30), {
			BackgroundTransparency = 0,
			BackgroundColor3 = C.Bright,
		})
		local titleText = RetroUI.text(title, "Title", spec.Title, px(12, 0), px(600, 30), {
			Font = RetroUI.Fonts.Title,
			Size = 14,
			Color = C.Screen,
		})
		titleText.TextStrokeTransparency = 1
		-- Close box: dark on the bright title bar, inverted under the pointer.
		local close = Instance.new("TextButton")
		close.Name = "Close"
		close.AutoButtonColor = false
		close.Text = "X"
		close.Font = RetroUI.Fonts.Title
		close.TextSize = 16
		close.BackgroundColor3 = C.Screen
		close.BackgroundTransparency = 1
		close.BorderSizePixel = 0
		close.Position = px(722, 0)
		close.Size = px(46, 30)
		close.Parent = title
		RetroUI.setColor(close, C.Screen)
		close.TextStrokeTransparency = 1
		RetroUI.hover(close, function(hot)
			close.BackgroundTransparency = if hot then 0 else 1
			RetroUI.setColor(close, if hot then C.Bright else C.Screen)
		end)
		close.Activated:Connect(closeWindow)
		local content = RetroUI.frame(frame, "Content", px(0, 30), px(768, 486))
		-- Licensed apps show a lock screen until the company owns the license.
		local license = spec.License and TechCatalog.Licenses[spec.License]
		if license and not licensed(spec.License) then
			titleText.Text = spec.Name .. "  -  LICENSE REQUIRED"
			local lock = RetroUI.frame(content, "Padlock", px(344, 60), px(80, 90))
			local shackle = RetroUI.frame(lock, "Shackle", px(14, 0), px(52, 52))
			RetroUI.border(shackle, C.Hot, 8)
			RetroUI.frame(lock, "Body", px(0, 34), px(80, 56), { BackgroundTransparency = 0, BackgroundColor3 = C.Hot })
			RetroUI.frame(lock, "Keyhole", px(34, 50), px(12, 22), { BackgroundTransparency = 0, BackgroundColor3 = C.Screen })
			RetroUI.text(content, "Locked", "LICENSE REQUIRED", px(0, 176), px(768, 40), {
				Font = RetroUI.Fonts.Title,
				Size = 26,
				Color = C.Hot,
				AlignX = Enum.TextXAlignment.Center,
			})
			RetroUI.text(
				content,
				"Explain",
				string.format(
					"%s NEEDS A %s (%s).\nBUY ONE AT THE SOFTWARE & LICENSES DESK IN %s,\nTHE COMPUTER STORE IN THE INDUSTRIAL DISTRICT IN THE CITY.",
					spec.Name,
					string.upper(license.Name),
					Stocks.money(license.Price),
					TechCatalog.STORE_NAME
				),
				px(40, 230),
				px(688, 110),
				{ Size = 18, Wrap = true, AlignX = Enum.TextXAlignment.Center }
			)
			if spec.LockNote then
				RetroUI.text(content, "LockNote", spec.LockNote, px(0, 360), px(768, 24), {
					Size = 15,
					Color = C.Mid,
					AlignX = Enum.TextXAlignment.Center,
				})
			end
			setStatus("! LICENSE REQUIRED. VISIT " .. TechCatalog.STORE_NAME .. " IN THE CITY.")
			return
		end
		setStatus(spec.Connecting)
		task.spawn(function()
			local mounted, app = pcall(spec.mount, content, setStatus)
			if not mounted then
				warn("[OfficeComputer] " .. spec.Name .. " failed to start: " .. tostring(app))
				if window == frame then
					RetroUI.text(
						content,
						"Crashed",
						spec.Name .. " HIT AN ERROR.\nCLOSE THE WINDOW AND TRY AGAIN.",
						px(0, 0),
						UDim2.fromScale(1, 1),
						{
							AlignX = Enum.TextXAlignment.Center,
							Wrap = true,
							Size = 22,
						}
					)
					setStatus("! THE APP COULD NOT START.")
				end
				return
			end
			if session ~= current or window ~= frame then
				app.destroy()
				return
			end
			current.App = app
			setStatus(spec.Ready)
		end)
	end

	-- Desktop icons: a little framed picture above the app's name.
	local function desktopIcon(name: string, label: string, x: number, spec, y: number?): Frame
		local icon = Instance.new("TextButton")
		icon.Name = name
		icon.AutoButtonColor = false
		icon.Text = ""
		icon.BackgroundTransparency = 1
		icon.Position = px(x, y or 36)
		icon.Size = px(120, 118)
		icon.Parent = desktop
		local art = RetroUI.frame(icon, "Art", px(24, 6), px(72, 60), {
			BackgroundTransparency = 0,
			BackgroundColor3 = C.Panel,
		})
		RetroUI.border(art, C.Bright, 2)
		local iconLabel = RetroUI.text(icon, "Label", label, px(0, 76), px(120, 30), {
			Font = RetroUI.Fonts.Title,
			Size = 14,
			AlignX = Enum.TextXAlignment.Center,
		})
		iconLabel.BackgroundColor3 = C.Bright
		RetroUI.hover(icon, function(hot: boolean)
			iconLabel.BackgroundTransparency = if hot then 0 else 1
			RetroUI.setColor(iconLabel, if hot then C.Screen else C.Bright)
			iconLabel.TextStrokeTransparency = if hot then 1 else RetroUI.Style.Bloom
		end)
		icon.Activated:Connect(function()
			openApp(art, spec)
		end)
		return art
	end

	-- STOCKS: a rising chart.
	local art = desktopIcon("StocksIcon", "STOCKS", 40, APPS.Stocks)
	local points = { 44, 38, 40, 28, 32, 20, 24, 12 }
	for index = 1, #points - 1 do
		local a = Vector2.new(6 + (index - 1) * 8.5, points[index])
		local b = Vector2.new(6 + index * 8.5, points[index + 1])
		local delta = b - a
		local middle = (a + b) / 2
		RetroUI.frame(art, "Line", px(middle.X, middle.Y), px(delta.Magnitude + 1, 3), {
			BackgroundTransparency = 0,
			BackgroundColor3 = C.Hot,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = math.deg(math.atan2(delta.Y, delta.X)),
		})
	end
	RetroUI.text(
		art,
		"Dollar",
		"$",
		px(48, 34),
		px(20, 22),
		{ Font = RetroUI.Fonts.Title, Size = 14, Color = C.Bright }
	)
	if not licensed("StockExchange") then
		-- A little padlock in the corner until the trading license is bought.
		local badge = RetroUI.frame(art, "Lock", px(50, 2), px(18, 20))
		local loop = RetroUI.frame(badge, "Shackle", px(4, 0), px(10, 10))
		RetroUI.border(loop, C.Hot, 2)
		RetroUI.frame(badge, "Body", px(0, 7), px(18, 13), { BackgroundTransparency = 0, BackgroundColor3 = C.Hot })
	end

	-- WEB SHOP: a shopping cart, padlocked until the web shop license is bought.
	local cart = desktopIcon("WebShopIcon", "WEB SHOP", 180, APPS.WebShop, 170)
	RetroUI.frame(cart, "Handle", px(6, 10), px(10, 3), { BackgroundTransparency = 0, BackgroundColor3 = C.Bright })
	RetroUI.frame(cart, "Basket", px(14, 14), px(44, 22), { BackgroundTransparency = 0, BackgroundColor3 = C.Mid })
	for index = 0, 2 do
		RetroUI.frame(cart, "Slat", px(20 + index * 12, 17), px(3, 16), { BackgroundTransparency = 0, BackgroundColor3 = C.Screen })
	end
	RetroUI.frame(cart, "Frame", px(18, 38), px(38, 3), { BackgroundTransparency = 0, BackgroundColor3 = C.Bright })
	for _, x in { 20, 48 } do
		RetroUI.frame(cart, "Wheel", px(x, 44), px(7, 7), { BackgroundTransparency = 0, BackgroundColor3 = C.Hot })
	end
	if not licensed("WebShop") then
		local badge = RetroUI.frame(cart, "Lock", px(50, 2), px(18, 20))
		local loop = RetroUI.frame(badge, "Shackle", px(4, 0), px(10, 10))
		RetroUI.border(loop, C.Hot, 2)
		RetroUI.frame(badge, "Body", px(0, 7), px(18, 13), { BackgroundTransparency = 0, BackgroundColor3 = C.Hot })
	end

	-- MY PC: a monitor with a tower beside it.
	local system = desktopIcon("SystemIcon", "MY PC", 40, APPS.System, 170)
	RetroUI.frame(system, "Monitor", px(8, 10), px(36, 28), { BackgroundTransparency = 0, BackgroundColor3 = C.Mid })
	RetroUI.frame(system, "Glass", px(12, 14), px(28, 20), { BackgroundTransparency = 0, BackgroundColor3 = C.Screen })
	RetroUI.frame(system, "Stand", px(20, 38), px(12, 8), { BackgroundTransparency = 0, BackgroundColor3 = C.Mid })
	RetroUI.frame(system, "Tower", px(50, 8), px(14, 44), { BackgroundTransparency = 0, BackgroundColor3 = C.Bright })
	RetroUI.frame(system, "Light", px(54, 14), px(6, 3), { BackgroundTransparency = 0, BackgroundColor3 = C.Hot })

	-- A little welcome note so the desk reads as somebody's office.
	RetroUI.text(
		desktop,
		"Welcome",
		"WELCOME BACK, " .. string.upper(player.DisplayName) .. ".\nTHE MARKET IS OPEN.",
		px(330, 46),
		px(440, 60),
		{ Size = 20, Color = C.Mid, Wrap = true, AlignY = Enum.TextYAlignment.Top }
	)

	setStatus(readyText)
	local sinceClock = 0
	table.insert(
		current.Connections,
		RunService.Heartbeat:Connect(function(step)
			sinceClock += step
			if sinceClock >= 1 then
				sinceClock = 0
				paintClock()
			end
		end)
	)
end

-- A short power-on self test, typed out line by line. Any click skips it.
-- The lines follow the company's parts (Shared.TechCatalog).
local function bootLines(): { string }
	local cpu = installed("CPU")
	return {
		"HARBOUR BIOS  V2.1",
		"CPU: " .. string.upper(cpu.Name) .. "  " .. string.upper(cpu.Spec),
		"MEMORY TEST  " .. TechCatalog.memoryText(installed("RAM").Kilobytes) .. " OK",
		"BOARD: " .. string.upper(installed("Motherboard").Name),
		"VIDEO: " .. string.upper(installed("GPU").Name),
		"POWER: " .. string.upper(installed("PSU").Spec),
		"FLOPPY A: ......... READY",
		"FIXED DISK C: ..... " .. installed("Storage").Drive,
		"",
		"LOADING HARBOUR-OS 3.30...",
	}
end

local function boot(root: Frame, current: Session, finished: () -> ())
	local screen = RetroUI.frame(root, "Boot", px(0, 0), px(800, 600), {
		BackgroundTransparency = 0,
		BackgroundColor3 = C.Screen,
		ZIndex = 30,
	})
	local text = RetroUI.text(screen, "Text", "", px(40, 40), px(720, 400), {
		Size = 22,
		Wrap = true,
		AlignY = Enum.TextYAlignment.Top,
	})
	text.ZIndex = 30
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		screen:Destroy()
		finished()
	end
	local skip = Instance.new("TextButton")
	skip.BackgroundTransparency = 1
	skip.Text = ""
	skip.Size = UDim2.fromScale(1, 1)
	skip.ZIndex = 31
	skip.Parent = screen
	skip.Activated:Connect(finish)
	task.spawn(function()
		local shown = {}
		for _, line in bootLines() do
			if done or session ~= current then
				return
			end
			table.insert(shown, line)
			text.Text = table.concat(shown, "\n") .. "_"
			task.wait(0.14)
		end
		task.wait(0.2)
		if session == current then
			finish()
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- Sitting down and getting up

local function leave(requestStand: boolean)
	local current = session
	if not current then
		return
	end
	session = nil
	for _, connection in current.Connections do
		connection:Disconnect()
	end
	pcall(RunService.UnbindFromRenderStep, RunService, "OfficeComputerView")
	RetroUI.setHovered(nil)
	if current.App then
		current.App.destroy()
	end
	current.Gui:Destroy()
	for _, label in current.ScreenLabels do
		if label.Parent then
			label.Enabled = true
		end
	end
	for _, item in current.Hidden do
		if item.Parent then
			item.LocalTransparencyModifier = 0
		end
	end
	for _, gui in current.HiddenGuis do
		if gui.Parent then
			gui.Enabled = true
		end
	end
	local saved = current.Saved
	UserInputService.MouseIconEnabled = saved.MouseIcon
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, saved.Backpack)
	local camera = workspace.CurrentCamera
	camera.FieldOfView = saved.FieldOfView
	camera.CameraType = saved.CameraType
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	refreshPrompts()
	if requestStand then
		task.spawn(requestServer, "Stand")
	end
end

local function enter(desk: Model)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local chair = desk:FindFirstChild("Chair")
	local seat = chair and chair:FindFirstChild("Seat")
	local screen = desk:FindFirstChild("ScreenCurve", true)
	if not humanoid or not seat or not seat:IsA("Seat") or not screen or not screen:IsA("BasePart") then
		task.spawn(requestServer, "Stand")
		return
	end
	local camera = workspace.CurrentCamera
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	local ok, backpack = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack)
	local gui = Instance.new("ScreenGui")
	gui.Name = GUI_NAME
	gui.IgnoreGuiInset = true -- same pixel space as WorldToViewportPoint and GetMouseLocation
	gui.DisplayOrder = 50
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false -- shown once the camera has settled on the glass

	local current: Session = {
		Desk = desk,
		Seat = seat,
		Screen = screen,
		Gui = gui,
		Connections = {},
		App = nil,
		Saved = {
			CameraType = camera.CameraType,
			FieldOfView = camera.FieldOfView,
			MouseIcon = UserInputService.MouseIconEnabled,
			Backpack = if ok then backpack else true,
		},
		HiddenGuis = {},
		ScreenLabels = {},
		Hidden = {},
	}
	session = current
	refreshPrompts()

	-- Nothing else on screen while you're at the computer.
	for _, item in playerGui:GetChildren() do
		if item:IsA("ScreenGui") and item.Enabled then
			item.Enabled = false
			table.insert(current.HiddenGuis, item)
		end
	end
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)
	-- The camera sits where your head is; hide your own character so it can't clip the view.
	for _, item in character:GetDescendants() do
		if item:IsA("BasePart") or item:IsA("Decal") then
			table.insert(current.Hidden, item)
		end
	end

	camera.CameraType = Enum.CameraType.Scriptable
	local target = cameraTarget(screen)
	local glide = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	TweenService:Create(camera, glide, { CFrame = target, FieldOfView = FOV }):Play()
	task.delay(0.72, function()
		if session == current then
			target = cameraTarget(screen)
			camera.CFrame = target
		end
	end)
	table.insert(
		current.Connections,
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			target = cameraTarget(screen)
			camera.CFrame = target
		end)
	)

	-- The monitor the company owns sets the whole screen's look.
	RetroUI.applyScreen(installed("Monitor").Screen)
	local root = RetroUI.frame(gui, "Root", px(0, 0), px(RetroUI.WIDTH, RetroUI.HEIGHT), {
		BackgroundTransparency = 0,
		BackgroundColor3 = C.Screen,
		ClipsDescendants = true,
	})
	local rootScale = Instance.new("UIScale")
	rootScale.Parent = root
	RetroUI.scanlines(root)
	local pointer = RetroUI.cursor(root, 2)
	pointer.Visible = false
	gui.Parent = playerGui

	-- Lay the canvas over the glass (it only moves if the window is resized). `corner` is the
	-- canvas's top-left in full-viewport pixels: the space of WorldToViewportPoint,
	-- GetMouseLocation and Position in this IgnoreGuiInset gui.
	local corner = Vector2.zero
	local function fit()
		local low, size = screenRect(screen)
		rootScale.Scale = math.max(size.X / RetroUI.WIDTH, 1e-3)
		corner = Vector2.new(math.floor(low.X + 0.5), math.floor(low.Y + 0.5))
		root.Position = px(corner.X, corner.Y)
	end

	-- GetGuiObjectsAtPosition and AbsolutePosition don't agree on whether the top bar counts
	-- (assuming they did put the highlight a top-bar height above the pointer, 2026-11-07). An
	-- invisible probe in the canvas corner tells which shift makes a hit test land on it; a wrong
	-- shift lands a whole top bar off the canvas.
	local probe = RetroUI.frame(root, "HitProbe", px(2, 2), px(6, 6))
	RetroUI.ignoreHover(probe)
	local queryShift = Vector2.zero
	local sinceProbe = math.huge
	local function calibrate()
		local inset = GuiService:GetGuiInset()
		local spot = probe.AbsolutePosition + probe.AbsoluteSize / 2
		for _, shift in { queryShift, Vector2.zero, inset, -inset } do
			local at = spot + shift
			for _, object in playerGui:GetGuiObjectsAtPosition(at.X, at.Y) do
				if object == probe then
					queryShift = shift
					return
				end
			end
		end
	end

	local mouse = UserInputService.MouseEnabled
	if mouse then
		UserInputService.MouseIconEnabled = false
	end
	RunService:BindToRenderStep("OfficeComputerView", Enum.RenderPriority.Camera.Value + 1, function()
		if session ~= current then
			return
		end
		for _, item in current.Hidden do
			item.LocalTransparencyModifier = 1
		end
		fit()
		if not (mouse and gui.Enabled) then
			return
		end
		-- Measured against `corner`, never root.AbsolutePosition: AbsolutePosition is in GUI space,
		-- which starts below the top bar even in an IgnoreGuiInset gui, and using it drew the
		-- pointer a top-bar height below the real mouse (2026-11-07).
		local at = UserInputService:GetMouseLocation()
		local point = (at - corner) / rootScale.Scale
		local inside = point.X >= 0 and point.Y >= 0 and point.X < RetroUI.WIDTH and point.Y < RetroUI.HEIGHT
		pointer.Visible = inside
		-- Off the glass, show the real cursor so it never just vanishes.
		if UserInputService.MouseIconEnabled == inside then
			UserInputService.MouseIconEnabled = not inside
		end
		if not inside then
			RetroUI.setHovered(nil)
			return
		end
		pointer.Position = px(point.X, point.Y)
		-- Hover follows the drawn pointer exactly: the pointer's spot in AbsolutePosition space,
		-- moved into GetGuiObjectsAtPosition's space by the probed shift.
		local absAt = root.AbsolutePosition + point * rootScale.Scale
		sinceProbe += 1
		if sinceProbe >= 30 then
			sinceProbe = 0
			calibrate()
		end
		local queryAt = absAt + queryShift
		local under = playerGui:GetGuiObjectsAtPosition(queryAt.X, queryAt.Y)
		RetroUI.setHovered(RetroUI.hoverTarget(under, absAt))
	end)

	-- Once the camera has arrived: swap the idle DOS prompt for HARBOUR-OS and boot.
	task.delay(0.75, function()
		if session ~= current then
			return
		end
		for _, item in screen:GetChildren() do
			if item:IsA("SurfaceGui") and item.Enabled then
				item.Enabled = false
				table.insert(current.ScreenLabels, item)
			end
		end
		fit()
		gui.Enabled = true
		boot(root, current, function()
			buildDesktop(root, current, function()
				leave(true)
			end)
		end)
	end)

	-- Standing up by any other route (jumping, the server releasing the seat, dying) closes the PC.
	local seatedOnce = humanoid.SeatPart == seat
	table.insert(
		current.Connections,
		humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
			if humanoid.SeatPart == seat then
				seatedOnce = true
			elseif seatedOnce then
				leave(false)
			end
		end)
	)
	table.insert(
		current.Connections,
		humanoid.Died:Connect(function()
			leave(false)
		end)
	)
	table.insert(
		current.Connections,
		player.CharacterRemoving:Connect(function()
			leave(false)
		end)
	)
	task.delay(3, function()
		if session == current and not seatedOnce then
			leave(true)
		end
	end)
end

local function sitDown(desk: Model)
	if session or busy then
		return
	end
	busy = true
	refreshPrompts()
	local ok, message = requestServer("Sit")
	busy = false
	if ok then
		enter(desk)
	else
		refreshPrompts()
		notice(message or "You can't use this computer right now.")
	end
end

----------------------------------------------------------------------------------------------------
-- Finding desks

local function addPrompt(desk: Model, base: Instance, cushion: BasePart)
	if cushion:FindFirstChild(PROMPT_NAME) then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = "Use computer"
	prompt.ObjectText = "Office PC"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = cushion
	prompts[prompt] = base
	promptDesks[prompt] = desk
	prompt.Triggered:Connect(function()
		sitDown(desk)
	end)
	prompt.AncestryChanged:Connect(function()
		if not prompt:IsDescendantOf(workspace) then
			prompts[prompt] = nil
			promptDesks[prompt] = nil
		end
	end)
	refreshPrompts()
end

local tracked: { [Instance]: boolean } = {}
local function trackDesk(desk: Instance)
	if tracked[desk] or not desk:IsA("Model") then
		return
	end
	local base = ownerBase(desk)
	if not base then
		return
	end
	tracked[desk] = true
	-- The PC can be carried off to the workbench (PcWorkshopService).
	desk:GetAttributeChangedSignal("PcAway"):Connect(refreshPrompts)
	local function consider(item: Instance)
		if item.Name == "SeatCushion" and item:IsA("BasePart") and item.Parent and item.Parent.Name == "Chair" then
			addPrompt(desk, base, item)
		end
	end
	-- Streaming may deliver (and re-deliver) the chair after the desk model arrives.
	desk.DescendantAdded:Connect(consider)
	for _, item in desk:GetDescendants() do
		consider(item)
	end
	desk.AncestryChanged:Connect(function()
		if not desk:IsDescendantOf(workspace) then
			tracked[desk] = nil
		end
	end)
end

local watchedBases: { [Instance]: boolean } = {}
local function trackBase(base: Instance)
	if watchedBases[base] then
		return
	end
	watchedBases[base] = true
	base:GetAttributeChangedSignal("OwnerUserId"):Connect(refreshPrompts)
	base:GetAttributeChangedSignal("CompanyId"):Connect(refreshPrompts)
	base.DescendantAdded:Connect(function(item)
		if item.Name == "OfficeDesk" then
			trackDesk(item)
		end
	end)
	local desk = base:FindFirstChild("OfficeDesk", true)
	if desk then
		trackDesk(desk)
	end
end

function OfficeComputer.start()
	for _, tag in { BASE_TAG, CAFE_TAG } do
		for _, base in CollectionService:GetTagged(tag) do
			trackBase(base)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(trackBase)
	end
	player:GetAttributeChangedSignal("CompanyId"):Connect(refreshPrompts)
end

return OfficeComputer
]====], 'src/client/OfficeComputer.luau'))
assert(loadstring([====[-- Owner saves use three slots. Joining a friend's company never consumes one.
-- This screen mounts before character/gear readiness so first arrival can choose a save.
-- Behind it the camera slowly circles the main island under a blur, so the
-- selector reads as a title screen instead of a grey box.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))
local Branches = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Branches"))

local Service = {}
local started = false

-- The harbour bay sits at the Gullhaven Sound biome centre (world origin).
-- High enough to clear the inland hills on every side of the orbit.
local PANORAMA_FOCUS = Vector3.new(0, 10, 0)
local PANORAMA_RADIUS = 640
local PANORAMA_HEIGHT = 300
local PANORAMA_SPEED = 0.018 -- radians per second; one lap is about six minutes
local PANORAMA_BLUR = 14
-- Roblox's own top bar is 58 px tall; used until GuiService reports its inset.
local DEFAULT_TOPBAR = 58

local SLOT_HEIGHT, SLOT_GAP = 128, 10
local COMPANY_HEIGHT, COMPANY_GAP = 132, 10
local LIST_TOP = 4 -- keeps the first card's border and focus ring inside the list

local function text(parent, name, value, position, size, fontSize, muted)
	local label = Instance.new("TextLabel")
	label.Name, label.Text = name, value
	label.BackgroundTransparency = 1
	label.Position, label.Size = position, size
	label.TextSize = fontSize or 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	Theme.text(label, if muted then Theme.Colors.Muted else nil)
	label.Parent = parent
	return label
end

local function style(item, state)
	Theme.glassButton(item, state)
end

local function button(parent, name, value, position, size, callback, state)
	local item = Instance.new("TextButton")
	item.Name, item.Text = name, value
	item.Position, item.Size = position, size
	item.TextSize, item.Selectable = 15, true
	item:SetAttribute("SaveButtonStyle", state or "Normal")
	style(item, state)
	item.Parent = parent
	item.Activated:Connect(callback)
	return item
end

local function scroll(parent, name, position, size)
	local frame = Instance.new("ScrollingFrame")
	frame.Name, frame.Position, frame.Size = name, position, size
	frame.BackgroundTransparency = 1
	frame.CanvasSize = UDim2.fromOffset(0, 0)
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	Theme.scroll(frame)
	frame.ScrollBarThickness = 6
	frame.ScrollBarImageColor3 = Theme.Colors.Border
	frame.Parent = parent
	return frame
end

local function money(value)
	local amount = tostring(math.floor(tonumber(value) or 0))
	local formatted = string.reverse(amount):gsub("(%d%d%d)", "%1,")
	return "$" .. string.reverse(formatted):gsub("^,", "")
end

-- Mirrors SaveData.cleanIcon closely enough for a live preview; the server
-- validates and normalises what is actually saved.
local function iconId(value)
	if type(value) == "number" then return if value > 0 and value % 1 == 0 then value else nil end
	if type(value) ~= "string" then return nil end
	local trimmed = string.match(value, "^%s*(.-)%s*$")
	local digits = string.match(trimmed, "^(%d+)$")
		or string.match(trimmed, "rbxassetid://(%d+)")
		or string.match(trimmed, "[?&]id=(%d+)")
		or string.match(trimmed, "/(%d+)/?[^/]*$")
		or string.match(trimmed, "/(%d+)/")
	local id = digits and #digits <= 16 and tonumber(digits)
	return if id and id > 0 then id else nil
end

-- Asset thumbnails render both decals and images from the same ID.
local function iconImage(id)
	return if id then "rbxthumb://type=Asset&id=" .. tostring(id) .. "&w=150&h=150" else ""
end

-- A square company badge: the chosen icon, or the company's first letter.
local function badge(parent, name, position, size, id, fallback)
	local tile = Instance.new("ImageLabel")
	tile.Name = name
	tile.Position, tile.Size = position, UDim2.fromOffset(size, size)
	tile.BackgroundColor3 = Color3.fromRGB(20, 34, 48)
	tile.BackgroundTransparency = 0
	tile.BorderSizePixel = 0
	tile.ScaleType = Enum.ScaleType.Crop
	tile.Image = iconImage(id)
	Theme.corner(tile, 8)
	local stroke = Instance.new("UIStroke")
	stroke.Name, stroke.Color, stroke.Transparency, stroke.Thickness = "ThemeBorder", Theme.Colors.Border, 0.45, 1
	stroke.Parent = tile
	local letter = text(tile, "Initial", fallback or "", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), math.floor(size * 0.46), true)
	letter.TextXAlignment = Enum.TextXAlignment.Center
	letter.Visible = id == nil
	tile.Parent = parent
	return tile
end

local function initial(name)
	local first = type(name) == "string" and string.match(name, "[%w]") or nil
	return if first then string.upper(first) else "?"
end

function Service.start()
	if started then return end
	started = true
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "SaveSelection"
	gui.ResetOnSpawn, gui.IgnoreGuiInset = false, true
	gui.DisplayOrder = 1001
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- Opaque until the island has streamed in behind it, then a dark tint over
	-- the blurred panorama.
	local backdrop = Instance.new("Frame")
	backdrop.Name, backdrop.Size = "Backdrop", UDim2.fromScale(1, 1)
	backdrop.BorderSizePixel, backdrop.Active = 0, true
	backdrop.BackgroundColor3 = Color3.fromRGB(9, 15, 22)
	backdrop.BackgroundTransparency = 0
	backdrop.Parent = gui
	local shade = Instance.new("Frame")
	shade.Name, shade.Size = "Shade", UDim2.fromScale(1, 1)
	shade.BorderSizePixel, shade.BackgroundColor3 = 0, Color3.fromRGB(0, 0, 0)
	shade.BackgroundTransparency = 0
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.45, 0.85),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	fade.Parent = shade
	shade.Parent = backdrop

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.new(1, -32, 1, -32)
	Theme.glassWindow(window)
	window.BackgroundTransparency = 0.16
	window.Parent = backdrop
	local bounds = Instance.new("UISizeConstraint")
	bounds.MaxSize = Vector2.new(1060, 720)
	bounds.Parent = window
	local title = text(window, "Title", "Choose your save", UDim2.fromOffset(24, 18), UDim2.new(1, -180, 0, 34), 27)
	local subtitle = text(window, "Subtitle", "Your company, your crew, one shared wallet.", UDim2.fromOffset(24, 55), UDim2.new(1, -180, 0, 22), 14, true)
	local body = Instance.new("Frame")
	body.Name, body.BackgroundTransparency = "Body", 1
	body.Position, body.Size = UDim2.fromOffset(24, 100), UDim2.new(1, -48, 1, -164)
	body.Parent = window
	local own = Instance.new("Frame")
	own.Name = "OwnSaves"
	Theme.glassPanel(own, true)
	own.Parent = body
	text(own, "Heading", "YOUR SAVES · 3 SLOTS", UDim2.fromOffset(14, 10), UDim2.new(1, -28, 0, 24), 15)
	local slotsScroll = scroll(own, "Slots", UDim2.fromOffset(10, 40), UDim2.new(1, -16, 1, -48))
	local side = Instance.new("Frame")
	side.Name = "Companies"
	Theme.glassPanel(side, true)
	side.Parent = body
	text(side, "Heading", "FRIENDS' COMPANIES", UDim2.fromOffset(14, 10), UDim2.new(1, -28, 0, 24), 15)
	local sideHelp = text(side, "Help", "Join here without using a save slot.", UDim2.fromOffset(14, 35), UDim2.new(1, -28, 0, 36), 13, true)
	sideHelp.TextWrapped, sideHelp.TextTruncate = true, Enum.TextTruncate.None
	local companiesScroll = scroll(side, "CompanyList", UDim2.fromOffset(10, 76), UDim2.new(1, -16, 1, -84))
	local status = text(window, "Status", "Loading your saves…", UDim2.new(0, 24, 1, -54), UDim2.new(1, -48, 0, 40), 14, true)
	status.TextWrapped, status.TextTruncate = true, Enum.TextTruncate.None

	local busy, entering, loaded = false, false, false
	local remote, modal
	local data = { Slots = {}, Companies = {} }
	local refresh, render, openSettings
	local firstButton

	-- Panorama -------------------------------------------------------------
	local panorama = {}
	local function stopPanorama()
		if panorama.connection then panorama.connection:Disconnect() end
		if panorama.blur then panorama.blur:Destroy() end
		local camera = panorama.camera
		if camera and camera.CameraType == Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Custom
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then camera.CameraSubject = humanoid end
		end
		panorama = {}
	end
	local function startPanorama()
		local camera = workspace.CurrentCamera
		if panorama.connection or not camera then return end
		panorama.camera = camera
		local blur = Instance.new("BlurEffect")
		blur.Name, blur.Size = "SaveSelectionBlur", PANORAMA_BLUR
		blur.Parent = camera
		panorama.blur = blur
		camera.CameraType = Enum.CameraType.Scriptable
		local angle = panorama.angle or 0.9
		panorama.connection = RunService.RenderStepped:Connect(function(dt)
			angle += dt * PANORAMA_SPEED
			panorama.angle = angle
			local eye = PANORAMA_FOCUS + Vector3.new(math.cos(angle) * PANORAMA_RADIUS, PANORAMA_HEIGHT, math.sin(angle) * PANORAMA_RADIUS)
			camera.CFrame = CFrame.lookAt(eye, PANORAMA_FOCUS)
		end)
		if panorama.streamed or panorama.streaming then return end
		panorama.streaming = true
		-- Without a character nothing streams in; ask for the island explicitly.
		task.spawn(function()
			pcall(player.RequestStreamAroundAsync, player, PANORAMA_FOCUS, 8)
			panorama.streaming, panorama.streamed = false, true
			if gui.Enabled then
				backdrop.BackgroundTransparency = 0.62
				shade.BackgroundTransparency = 0
			end
		end)
	end

	-- Visibility and layout -----------------------------------------------
	local function selectionRequired()
		return player:GetAttribute("SaveSelectionRequired") ~= false
			and player:GetAttribute("BoatDataStatus") ~= "Ready"
	end

	-- A picked save hands the screen to the loading screen at once, instead of
	-- after the server confirms (which waits for the harbour on a fresh server).
	-- A failed pick clears this and brings the selector back.
	local function setOpening(value)
		player:SetAttribute("SaveSelectionOpening", if value then true else nil)
	end

	local function visibility()
		gui.Enabled = selectionRequired() and player:GetAttribute("SaveSelectionOpening") ~= true
		if not gui.Enabled then
			stopPanorama()
			if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
				GuiService.SelectedObject = nil
			end
		else
			startPanorama()
			if UserInputService.GamepadEnabled and not GuiService.SelectedObject and firstButton then
				GuiService.SelectedObject = firstButton
			end
		end
	end

	local function setBusy(value)
		busy = value
		for _, item in gui:GetDescendants() do
			if item:IsA("TextButton") then
				local enabled = not value and item:GetAttribute("SaveButtonStyle") ~= "Disabled"
				item.Active, item.Selectable = enabled, enabled
				style(item, if value then "Disabled" else item:GetAttribute("SaveButtonStyle"))
			end
		end
	end

	local function showError(message)
		status.Text = message
		local errorLabel = modal and modal:FindFirstChild("Error", true)
		if errorLabel then errorLabel.Text = message end
	end

	local function request(action, payload)
		if busy or entering then return nil end
		if not remote then
			showError("Connecting to saved data. Please try again shortly.")
			return nil
		end
		setBusy(true)
		local ok, response = pcall(remote.InvokeServer, remote, action, payload)
		setBusy(false)
		if not ok or type(response) ~= "table" or response.Ok ~= true then
			showError(if ok and type(response) == "table" and type(response.Message) == "string"
				then response.Message else "Could not reach your saves. Press Refresh to retry.")
			return nil
		end
		return response
	end

	local function closeModal()
		if modal then modal:Destroy(); modal = nil end
		if UserInputService.GamepadEnabled then GuiService.SelectedObject = firstButton end
	end

	local function selectSave(entry)
		if busy or entering then return end
		local opening = "Opening " .. tostring(entry.Name or "your save") .. "…"
		status.Text = opening
		-- Saves list while the harbour is still building; entering waits for it.
		local waiting = true
		task.delay(1.5, function()
			while waiting and gui.Enabled do
				if ReplicatedStorage:GetAttribute("FishingWatersWorldReady") ~= true then
					local stage = ReplicatedStorage:GetAttribute("FishingWatersLoadStage")
					status.Text = opening .. " " .. (if type(stage) == "string" then stage else "Preparing the harbour") .. "…"
				end
				task.wait(0.5)
			end
		end)
		if remote then setOpening(true) end
		local response = request("Select", { OwnerUserId = entry.OwnerUserId or player.UserId, Slot = entry.Slot })
		waiting = false
		if response then
			entering = response.Entering == true
			if entering then
				setBusy(true)
				status.Text = "Opening your save. Your crew can play here together."
			end
		end
		if not entering then setOpening(false) end
	end

	local function card(parent, name, y, height)
		local frame = Instance.new("Frame")
		frame.Name, frame.Position, frame.Size = name, UDim2.fromOffset(2, y), UDim2.new(1, -12, 0, height)
		Theme.panel(frame, false, 8)
		frame.BackgroundColor3 = Color3.fromRGB(38, 44, 52)
		frame.BackgroundTransparency = 0.15
		frame.Parent = parent
		return frame
	end

	render = function()
		if modal then return end
		local focused = GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui)
		slotsScroll:ClearAllChildren()
		companiesScroll:ClearAllChildren()
		firstButton = nil
		local slotsById = {}
		for _, entry in data.Slots or {} do slotsById[entry.Slot] = entry end
		for slot = 1, 3 do
			local y = LIST_TOP + (slot - 1) * (SLOT_HEIGHT + SLOT_GAP)
			local frame = card(slotsScroll, "Slot" .. slot, y, SLOT_HEIGHT)
			if not loaded then
				-- Placeholder while the first list is in flight.
				badge(frame, "Icon", UDim2.fromOffset(12, 12), 64, nil, "")
				text(frame, "SlotNumber", "SAVE " .. slot, UDim2.fromOffset(88, 12), UDim2.new(1, -100, 0, 18), 12, true)
				text(frame, "SaveName", "Loading…", UDim2.fromOffset(88, 31), UDim2.new(1, -100, 0, 25), 19, true)
				continue
			end
			local entry = slotsById[slot] or { Slot = slot, OwnerUserId = player.UserId, Exists = false }
			local exists = entry.Exists == true or (entry.Exists ~= false and entry.Name ~= nil)
			badge(frame, "Icon", UDim2.fromOffset(12, 12), 64, exists and iconId(entry.Icon) or nil, if exists then initial(entry.Name) else "+")
			local tag = if not exists then "SAVE " .. slot .. " · EMPTY"
				elseif entry.Multiplayer then "SAVE " .. slot .. " · COMPANY"
				else "SAVE " .. slot .. " · SOLO"
			text(frame, "SlotNumber", tag, UDim2.fromOffset(88, 11), UDim2.new(1, -100, 0, 18), 12, true)
			text(frame, "SaveName", if exists then entry.Name or "Untitled save" else "Start a new adventure", UDim2.fromOffset(88, 29), UDim2.new(1, -100, 0, 25), 20)
			local kind = if exists then Branches.label(entry.Branches) else nil
			local summary = if not exists then "Fishing company · solo or with up to four friends."
				elseif entry.Multiplayer then string.format("%s · %d/5 members · %s net worth", kind, entry.MemberCount or 1, money(entry.NetWorth))
				else string.format("%s · solo · %s net worth", kind, money(entry.NetWorth))
			text(frame, "Details", summary, UDim2.fromOffset(88, 55), UDim2.new(1, -100, 0, 20), 13, true)
			local primary = button(frame, if exists then "Play" else "Create", if exists then "Play" else "Create save", UDim2.new(0, 12, 1, -44), UDim2.new(if exists then 0.62 else 1, if exists then -18 else -24, 0, 34), function()
				if busy or entering then return end
				if exists then selectSave(entry) else openSettings(entry, true) end
			end, "Selected")
			firstButton = firstButton or primary
			if exists then
				button(frame, "Settings", "Settings", UDim2.new(0.62, 0, 1, -44), UDim2.new(0.38, -12, 0, 34), function()
					if not busy and not entering then openSettings(entry, false) end
				end)
			end
		end
		slotsScroll.CanvasSize = UDim2.fromOffset(0, LIST_TOP + 3 * (SLOT_HEIGHT + SLOT_GAP))
		local companies = data.Companies or {}
		for index, entry in companies do
			local y = LIST_TOP + (index - 1) * (COMPANY_HEIGHT + COMPANY_GAP)
			local frame = card(companiesScroll, "Company" .. index, y, COMPANY_HEIGHT)
			badge(frame, "Icon", UDim2.fromOffset(12, 12), 56, iconId(entry.Icon), initial(entry.Name))
			text(frame, "Name", entry.Name or "Friend's company", UDim2.fromOffset(80, 10), UDim2.new(1, -92, 0, 24), 18)
			local ownerName = entry.OwnerName or ("User " .. tostring(entry.OwnerUserId))
			text(frame, "Owner", "Created by " .. ownerName, UDim2.fromOffset(80, 35), UDim2.new(1, -92, 0, 18), 12, true)
			text(frame, "Details", string.format("%s · %d/5 members · %s net worth", Branches.label(entry.Branches), entry.MemberCount or 1, money(entry.NetWorth)), UDim2.fromOffset(80, 54), UDim2.new(1, -92, 0, 18), 12, true)
			local member = entry.IsMember == true
			for _, person in entry.Members or {} do
				if person.UserId == player.UserId then member = true end
			end
			local full = (entry.MemberCount or 1) >= 5 and not member
			local join = button(frame, "Join", if full then "Company full" elseif member then "Continue company" else "Join company", UDim2.new(0, 12, 1, -46), UDim2.new(1, -24, 0, 34), function()
				if not full then selectSave(entry) end
			end, if full then "Disabled" else "Selected")
			join.Active, join.Selectable = not full, not full
		end
		if #companies == 0 then
			local empty = text(companiesScroll, "Empty", if not loaded or data.FriendsLoading then "Finding your friends' companies…" else "No companies to join yet. A friend can enable Multiplayer in their save settings; their company will appear here, even while they are offline.", UDim2.fromOffset(6, 8), UDim2.new(1, -22, 0, 128), 14, true)
			empty.TextWrapped, empty.TextTruncate, empty.TextYAlignment = true, Enum.TextTruncate.None, Enum.TextYAlignment.Top
		end
		companiesScroll.CanvasSize = UDim2.fromOffset(0, LIST_TOP + math.max(144, #companies * (COMPANY_HEIGHT + COMPANY_GAP)))
		if busy or entering then setBusy(true) end
		if focused or UserInputService.GamepadEnabled then GuiService.SelectedObject = firstButton end
	end

	refresh = function()
		if not gui.Enabled or modal or busy or entering then return end
		local response = request("List")
		if not response then return end
		data, loaded = response, true
		render()
		status.Text = if response.SessionOnly then "Studio session: saves last for this server session."
			elseif response.FriendsLoading then "Your saves are ready. Finding friends' companies…"
			else "Only the creator uses a slot. Companies share progress and money, with five members maximum."
	end

	local function acceptChange(response, message)
		closeModal()
		-- Create/settings already include fresh lists. A second request would hit
		-- the server's admission limit and leave the just-edited card stale.
		if type(response.Slots) == "table" then
			data, loaded = response, true
			render()
		else
			task.delay(0.6, refresh)
		end
		status.Text = message
	end

	openSettings = function(entry, creating)
		closeModal()
		modal = Instance.new("Frame")
		modal.Name, modal.Size, modal.BackgroundTransparency = "SaveSettings", UDim2.fromScale(1, 1), 0.35
		modal.BackgroundColor3, modal.Active = Theme.Colors.Black, true
		modal.ZIndex, modal.Parent = 10, backdrop
		local panel = Instance.new("Frame")
		panel.Name, panel.AnchorPoint = "Panel", Vector2.new(0.5, 0.5)
		panel.Position, panel.Size = window.Position, UDim2.new(1, -32, 1, -48 - (window:GetAttribute("TopInset") or 0))
		panel.ZIndex = 11
		Theme.window(panel)
		panel.Parent = modal
		local limit = Instance.new("UISizeConstraint")
		limit.MaxSize, limit.Parent = Vector2.new(560, 660), panel
		local heading = text(panel, "Heading", if creating then "Create save " .. entry.Slot else "Save settings", UDim2.fromOffset(22, 16), UDim2.new(1, -44, 0, 32), 23)
		heading.ZIndex = 12
		local content = scroll(panel, "SettingsContent", UDim2.fromOffset(20, 58), UDim2.new(1, -40, 1, -184))
		content.ZIndex = 12
		text(content, "NameLabel", "Save / company name", UDim2.fromOffset(2, 0), UDim2.new(1, -18, 0, 26), 15)
		local nameInput = Instance.new("TextBox")
		nameInput.Name, nameInput.Text = "SaveName", entry.Name or ("Save " .. entry.Slot)
		nameInput.PlaceholderText = "Name your save"
		nameInput.ClearTextOnFocus, nameInput.MultiLine = false, false
		nameInput.Position, nameInput.Size = UDim2.fromOffset(2, 32), UDim2.new(1, -18, 0, 42)
		nameInput.TextSize, nameInput.TextXAlignment = 18, Enum.TextXAlignment.Center
		Theme.panel(nameInput, true)
		Theme.text(nameInput)
		nameInput.Parent = content

		-- Company icon: any Roblox decal or image ID, previewed as it is typed.
		text(content, "IconLabel", "Company icon (optional)", UDim2.fromOffset(2, 88), UDim2.new(1, -18, 0, 26), 15)
		local preview = badge(content, "IconPreview", UDim2.fromOffset(2, 120), 56, iconId(entry.Icon), initial(entry.Name))
		local iconInput = Instance.new("TextBox")
		iconInput.Name, iconInput.Text = "IconId", if entry.Icon then tostring(entry.Icon) else ""
		iconInput.PlaceholderText = "Decal or image ID"
		iconInput.ClearTextOnFocus, iconInput.MultiLine = false, false
		iconInput.Position, iconInput.Size = UDim2.fromOffset(70, 127), UDim2.new(1, -86, 0, 42)
		iconInput.TextSize, iconInput.TextXAlignment = 17, Enum.TextXAlignment.Center
		Theme.panel(iconInput, true)
		Theme.text(iconInput)
		iconInput.Parent = content
		local iconHelp = text(content, "IconHelp", "Paste a decal or image ID, or its Creator Store link. Leave empty for no icon.", UDim2.fromOffset(2, 182), UDim2.new(1, -18, 0, 36), 13, true)
		iconHelp.TextWrapped, iconHelp.TextTruncate, iconHelp.TextYAlignment = true, Enum.TextTruncate.None, Enum.TextYAlignment.Top
		local function updatePreview()
			local id = iconId(iconInput.Text)
			preview.Image = iconImage(id)
			preview.Initial.Visible = id == nil
			preview.Initial.Text = initial(nameInput.Text)
		end
		iconInput:GetPropertyChangedSignal("Text"):Connect(updatePreview)
		nameInput:GetPropertyChangedSignal("Text"):Connect(updatePreview)

		local companyType = "Fishing"
		local top = 230

		local multiplayer = entry.Multiplayer == true
		local toggle
		local function toggleText()
			toggle.Text = "Multiplayer: " .. (if multiplayer then "ON" else "OFF")
			toggle:SetAttribute("SaveButtonStyle", if multiplayer then "Selected" else "Normal")
			style(toggle, toggle:GetAttribute("SaveButtonStyle"))
		end
		toggle = button(content, "Multiplayer", "", UDim2.fromOffset(2, top), UDim2.new(1, -18, 0, 42), function()
			if busy or entering then return end
			multiplayer = not multiplayer
			toggleText()
		end)
		toggleText()
		local hint = text(content, "MultiplayerHelp", "ON: Roblox friends can join while you are offline. Up to five members share this save and its wallet. The save name is the company name.", UDim2.fromOffset(2, top + 52), UDim2.new(1, -18, 0, 70), 14, true)
		hint.TextWrapped, hint.TextTruncate, hint.TextYAlignment = true, Enum.TextTruncate.None, Enum.TextYAlignment.Top
		local y = top + 132
		if not creating then
			text(content, "MembersHeading", "COMPANY MEMBERS", UDim2.fromOffset(2, y), UDim2.new(1, -18, 0, 24), 15)
			y += 32
			local members = entry.Members or { { UserId = player.UserId, Name = player.Name } }
			for _, member in members do
				local memberId = member.UserId
				local owner = memberId == player.UserId
				text(content, "Member" .. tostring(memberId), (member.Name or ("User " .. tostring(memberId))) .. (if owner then " · Creator" else ""), UDim2.fromOffset(2, y), UDim2.new(1, if owner then -18 else -110, 0, 36), 14, true)
				if not owner then
					button(content, "Remove" .. tostring(memberId), "Remove", UDim2.new(1, -104, 0, y), UDim2.fromOffset(88, 34), function()
						local response = request("Settings", { Slot = entry.Slot, Name = entry.Name, Multiplayer = entry.Multiplayer == true, RemoveUserId = memberId })
						if response then acceptChange(response, "Company member removed.") end
					end, "Danger")
				end
				y += 44
			end
		end
		content.CanvasSize = UDim2.fromOffset(0, y + 8)
		local errorLabel = text(panel, "Error", "", UDim2.new(0, 22, 1, -116), UDim2.new(1, -44, 0, 48), 13, true)
		errorLabel.TextWrapped, errorLabel.TextTruncate, errorLabel.ZIndex = true, Enum.TextTruncate.None, 12
		local function submit()
			if busy or entering then return end
			local response = request(if creating then "Create" else "Settings", {
				Slot = entry.Slot, Name = nameInput.Text, Multiplayer = multiplayer, Icon = iconInput.Text,
				Company = if creating then companyType else nil,
			})
			if response then
				acceptChange(response, if creating then "Save created. Press Play when you are ready." else "Save settings updated.")
			end
		end
		local cancel = button(panel, "Cancel", "Cancel", UDim2.new(0, 22, 1, -60), UDim2.new(0.5, -30, 0, 40), function()
			if not busy then closeModal() end
		end)
		local save = button(panel, "Save", if creating then "Create save" else "Save settings", UDim2.new(0.5, 8, 1, -60), UDim2.new(0.5, -30, 0, 40), submit, "Selected")
		cancel.ZIndex, save.ZIndex = 12, 12
		nameInput.FocusLost:Connect(function(enterPressed) if enterPressed then submit() end end)
		if UserInputService.GamepadEnabled then GuiService.SelectedObject = toggle end
	end

	local refreshButton = button(window, "Refresh", "Refresh", UDim2.new(1, -128, 0, 22), UDim2.fromOffset(104, 34), function()
		if not entering then refresh() end
	end)
	-- Keep the window clear of Roblox's top bar (menu, chat and other core
	-- buttons draw over IgnoreGuiInset screens).
	local function topInset()
		local ok, inset = pcall(function() return GuiService.TopbarInset end)
		if ok and typeof(inset) == "Rect" and inset.Max.Y > 0 then return inset.Max.Y end
		return DEFAULT_TOPBAR
	end
	local function resize()
		local size = backdrop.AbsoluteSize
		local narrow = size.X < 760
		local margin = if narrow then 8 else 16
		local top = topInset()
		window:SetAttribute("TopInset", top)
		title.TextSize = if narrow then 21 else 27
		subtitle.Text = if narrow then "Three saves. Five members per company." else "Your company, your crew, one shared wallet."
		window.Position = UDim2.new(0.5, 0, 0.5, top / 2)
		window.Size = UDim2.new(1, -margin * 2, 1, -margin * 2 - top)
		refreshButton.Size = UDim2.fromOffset(if narrow then 88 else 104, 34)
		refreshButton.Position = UDim2.new(1, if narrow then -104 else -128, 0, 22)
		body.Position, body.Size = UDim2.fromOffset(if narrow then 16 else 24, 100), UDim2.new(1, if narrow then -32 else -48, 1, -164)
		own.Position, own.Size = UDim2.fromScale(0, 0), if narrow then UDim2.new(1, 0, 0.56, -6) else UDim2.new(0.59, -8, 1, 0)
		side.Position, side.Size = if narrow then UDim2.new(0, 0, 0.56, 6) else UDim2.new(0.59, 8, 0, 0), if narrow then UDim2.new(1, 0, 0.44, -6) else UDim2.new(0.41, -8, 1, 0)
		if modal and modal:FindFirstChild("Panel") then
			modal.Panel.Position = window.Position
			modal.Panel.Size = UDim2.new(1, -32, 1, -48 - top)
		end
	end
	backdrop:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	pcall(function() GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(resize) end)
	player:GetAttributeChangedSignal("SaveSelectionRequired"):Connect(function()
		entering = false
		setBusy(false)
		if selectionRequired() then setOpening(false) end
		visibility()
		if gui.Enabled and loaded then task.spawn(refresh) end
	end)
	player:GetAttributeChangedSignal("BoatDataStatus"):Connect(visibility)
	player:GetAttributeChangedSignal("SaveSelectionOpening"):Connect(visibility)
	local function teleportState()
		if player:GetAttribute("SaveTeleporting") == true then
			entering = true
			setBusy(true)
			status.Text = "Joining your company server…"
		elseif entering and selectionRequired() then
			entering = false
			setBusy(false)
			setOpening(false)
			status.Text = "The company server could not be reached. Please try joining again."
		end
	end
	player:GetAttributeChangedSignal("SaveTeleporting"):Connect(teleportState)
	-- A failed Roblox teleport restores selection without requiring a rejoin.
	player:GetAttributeChangedSignal("SaveSelectionError"):Connect(function()
		local message = player:GetAttribute("SaveSelectionError")
		if type(message) == "string" and message ~= "" then
			entering = false
			setBusy(false)
			setOpening(false)
			status.Text = message
		end
	end)
	render()
	gui.Parent = player:WaitForChild("PlayerGui")
	resize()
	visibility()
	teleportState()
	player:SetAttribute("SaveSelectionMounted", true)
	task.spawn(function()
		remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SaveRequest")
		refresh()
	end)
	-- Retry the first list quickly; afterwards refresh company availability.
	local function poll()
		if gui.Parent == nil then return end
		if gui.Enabled then refresh() end
		task.delay(if loaded then 15 else 2, poll)
	end
	task.delay(if loaded then 15 else 2, poll)
end

return Service
]====], 'src/client/SaveSelection.luau'))
assert(loadstring([====[-- Gives each player one of the harbour bases for as long as they're in the server
-- and makes them spawn on it. Players beyond the number of bases spawn in the plaza.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local BoatService = require(script.Parent.BoatService)

local BASE_TAG = "PlayerBase"

local BaseService = {}

local owned: { [Player]: Model } = {}

local function setBoard(base: Model, text: string)
	local board = base:FindFirstChild("NameBoard")
	if board then
		for _, label in board:GetDescendants() do
			if label:IsA("TextLabel") then
				label.Text = text
			end
		end
	end
end

local function setShopSign(base: Model, value: string)
	local sign = base:FindFirstChild("ShopSign", true)
	local label = sign and sign:FindFirstChildWhichIsA("TextLabel", true)
	if label then
		label.Text = if value ~= "" then value else "FISH & TACKLE  /  " .. string.format("%02d", base:GetAttribute("BaseId") or 1)
	end
end

local function freeBase(expanded: boolean): Model?
	local bases = CollectionService:GetTagged(BASE_TAG)
	table.sort(bases, function(a, b)
		return (a:GetAttribute("BaseId") or 0) < (b:GetAttribute("BaseId") or 0)
	end)
	for _, base in bases do
		if base:GetAttribute("OwnerUserId") == 0 and (not expanded or base:GetAttribute("MultiplayerPlot") == true) then
			return base :: Model
		end
	end
	return nil
end

local function spawnPoint(base: Model): SpawnLocation?
	return base:FindFirstChild("SpawnPoint") :: SpawnLocation?
end

local function harbourSpawn(): SpawnLocation?
	local map = workspace:FindFirstChild("Map")
	return (map and map:FindFirstChild("HarbourSpawn")) :: SpawnLocation?
end

local function claim(player: Player)
	local profile = BoatService.getProfile(player)
	local info = profile and profile.SaveInfo
	local expanded = info ~= nil and (info.PlotExpanded == true or info.Multiplayer == true)
	local base = freeBase(expanded)
	if not base then
		player.RespawnLocation = harbourSpawn()
		return
	end
	owned[player] = base
	player:SetAttribute("MultiplayerPlot", expanded and base:GetAttribute("MultiplayerPlot") == true)
	base:SetAttribute("OwnerUserId", player.UserId)
	player:SetAttribute("BaseId", base:GetAttribute("BaseId"))
	setBoard(base, player.DisplayName .. "'s Dock")
	setShopSign(base, "")
	local lastName = nil
	local generation = 0
	local function updateSign()
		if owned[player] ~= base then
			return
		end
		local profile = BoatService.getProfile(player)
		if not profile then
			return
		end
		local name = profile.Angler.ShopSign
		if name == lastName then
			return
		end
		lastName = name
		generation += 1
		local currentGeneration = generation
		if name == "" then
			setShopSign(base, "")
			return
		end
		task.spawn(function()
			local ok, filtered = pcall(function()
				return TextService:FilterStringAsync(name, player.UserId):GetNonChatStringForBroadcastAsync()
			end)
			if ok and owned[player] == base and generation == currentGeneration then
				setShopSign(base, filtered)
			elseif not ok and generation == currentGeneration then
				lastName = nil
			end
		end)
	end
	player:GetAttributeChangedSignal("AnglerRevision"):Connect(updateSign)
	updateSign()
	player.RespawnLocation = spawnPoint(base)
end

local function release(player: Player)
	local base = owned[player]
	if base then
		owned[player] = nil
		base:SetAttribute("OwnerUserId", 0)
		setBoard(base, "Base " .. tostring(base:GetAttribute("BaseId")))
		setShopSign(base, "")
	end
end

-- RespawnLocation normally handles this; moving the character as well covers spawns that
-- happened before the base existed.
local function placeCharacter(player: Player, character: Model)
	player:SetAttribute("FishingWatersSpawnReady", false)
	local base = owned[player]
	local point = if base then spawnPoint(base) else harbourSpawn()
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not point or not root or player.Character ~= character then
		return
	end
	task.wait()
	if player.Character ~= character or not root.Parent then
		return
	end
	if (root.Position - point.Position).Magnitude > 20 then
		character:PivotTo(point.CFrame + Vector3.new(0, 4, 0))
	end
	-- The loader may inspect collision only after the server's final placement.
	-- This also covers plaza spawns when all harbour bases have been claimed.
	player:SetAttribute("FishingWatersSpawnReady", true)
end

local function onPlayer(player: Player)
	player:SetAttribute("FishingWatersSpawnReady", false)
	local entered = false
	local function enterSave()
		if entered or player.Parent ~= Players or player:GetAttribute("BoatDataStatus") ~= "Ready" then return end
		entered = true
		claim(player)
		if not player.Character then player:LoadCharacter() end
	end
	player.CharacterAdded:Connect(function(character)
		task.spawn(placeCharacter, player, character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.Died:Once(function()
				task.delay(Players.RespawnTime, function()
					if player.Parent == Players and player:GetAttribute("BoatDataStatus") == "Ready" and player.Character == character then
						player:LoadCharacter()
					end
				end)
			end)
		end
	end)
	if player.Character then
		task.spawn(placeCharacter, player, player.Character)
	end
	player:GetAttributeChangedSignal("BoatDataStatus"):Connect(enterSave)
	enterSave()
end

function BaseService.start()
	Players.PlayerRemoving:Connect(release)
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	-- Save selection precedes spawning. Respawns are handled above so Roblox
	-- cannot automatically create a playable character behind the selector.
	Players.CharacterAutoLoads = false
end

return BaseService
]====], 'src/server/BaseService.luau'))
assert(loadstring([====[-- Server-owned wallet transactions, dock permissions, and one active boat per player.
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local BoatData = require(script.Parent.BoatData)
local SaveData = require(script.Parent.SaveData)
local CompanyWorth = require(script.Parent.CompanyWorth)
local CompanyProfile = require(script.Parent.CompanyProfile)
local SaveService = require(script.Parent.SaveService)
local AnglerData = require(script.Parent.AnglerData)
local RodSerials = require(script.Parent.RodSerials)
local AdminCommands = require(script.Parent.AdminCommands)
local Rowboat = require(script.Parent.Rowboat)
local FishingBoat = require(script.Parent.FishingBoat)
local Speedboat = require(script.Parent.Speedboat)
local RacingSpeedboat = require(script.Parent.RacingSpeedboat)
local PatrolBoat = require(script.Parent.PatrolBoat)
local Trawler = require(script.Parent.Trawler)
local Tugboat = require(script.Parent.Tugboat)
local Hovercraft = require(script.Parent.Hovercraft)
local SmallFerry = require(script.Parent.SmallFerry)
local DrydockLaunch = require(script.Parent.DrydockLaunch)
local BoatLaunchCollision = require(script.Parent.BoatLaunchCollision)
local BoatCatalog = require(ReplicatedStorage.Shared.BoatCatalog)
local AnglerCatalog = require(ReplicatedStorage.Shared.AnglerCatalog)
local BoatMotion = require(ReplicatedStorage.Shared.BoatMotion)
local RodSkins = require(ReplicatedStorage.Shared.RodSkins)
local SpearSkins = require(ReplicatedStorage.Shared.SpearSkins)
local BobberSkins = require(ReplicatedStorage.Shared.BobberSkins)
local RodUpgrades = require(ReplicatedStorage.Shared.RodUpgrades)
local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Weather = require(ReplicatedStorage.Shared.Weather)
local BoatDrive = require(ReplicatedStorage.Shared.BoatDrive)
local builders = {
	Rowboat = Rowboat,
	FishingBoat = FishingBoat,
	Speedboat = Speedboat,
	PatrolBoat = PatrolBoat,
	RacingSpeedboat = RacingSpeedboat,
	Trawler = Trawler,
	Tugboat = Tugboat,
	Hovercraft = Hovercraft,
	SmallFerry = SmallFerry,
}

local BoatService = {}
local profiles = {}
local saveQueues = {}
local active = {}
local requests = {}
local spawnTimes = {}
local launching = {}
local launchPurchased
local boatLock: ((Player, string) -> string?)? = nil
local outfitter: ((Player, string, Model) -> any)? = nil
local started = false
local Admin = require(ReplicatedStorage.Shared.Admin)
-- Studio tests use their own store; failed loads never overwrite saved data.
local studioSession = RunService:IsStudio() and game.GameId == 0
local store
if studioSession then
	-- Unpublished places cannot access DataStores. Keep test progress in this
	-- server only; never substitute defaults for a failed published save/load.
	local records = {}
	store = {
		GetAsync = function(_, key)
			return records[key]
		end,
		UpdateAsync = function(_, key, transform)
			local saved = transform(records[key])
			records[key] = saved
			return saved
		end,
	}
else
	local success, result = pcall(function()
		return DataStoreService:GetDataStore(
			if RunService:IsStudio() then "WalletAndBoats_Studio_v1" else "WalletAndBoats_v1"
		)
	end)
	if success then
		store = result
	else
		warn("[Wallet] Could not initialize saved data: " .. tostring(result))
	end
end
local feedback: RemoteEvent

local function notify(player: Player, message: string)
	if player.Parent == Players then
		feedback:FireClient(player, "Notice", message)
	end
end

local function publishOne(player: Player, state)
	player:SetAttribute("WalletSessionOnly", studioSession)
	player:SetAttribute("BoatDataStatus", state.status)
	local info = if state.status == "Ready" then state.profile.SaveInfo else nil
	player:SetAttribute("ActiveSaveOwnerId", if info then info.OwnerUserId else nil)
	player:SetAttribute("ActiveSaveSlot", if info then info.Slot else nil)
	player:SetAttribute("CompanyId", if info then SaveData.id(info.OwnerUserId, info.Slot) else nil)
	player:SetAttribute("CompanyName", if info then info.Name else nil)
	player:SetAttribute("CompanyIcon", if info then info.Icon else nil)
	player:SetAttribute("CompanyMultiplayer", if info then info.Multiplayer else false)
	player:SetAttribute("CompanyNetWorth", if info then state.netWorth or CompanyWorth.calculate(state.profile) else nil)
	player:SetAttribute("Cash", state.profile.Cash)
	player:SetAttribute("BranchFishing", state.status == "Ready")
	for id in BoatCatalog do
		player:SetAttribute("Owns" .. id, state.status == "Ready" and state.profile.OwnedBoats[id] == true)
		player:SetAttribute("BoatLocked" .. id, BoatData.pathLocked(state.profile, id))
	end
	player:SetAttribute("OwnsStarterRod", state.status == "Ready" and state.profile.OwnedRods.StarterRod == true)
	player:SetAttribute("OwnsBasicSpear", state.status == "Ready" and state.profile.OwnedSpears.BasicSpear == true)
	for _, stat in RodUpgrades.Order do
		player:SetAttribute(RodUpgrades.attribute(stat), RodUpgrades.level(state.profile.RodUpgrades, stat))
	end
	for id in RodSkins.Skins do
		player:SetAttribute("RodSkinCount" .. id, state.profile.RodSkins[id] or 0)
	end
	for id in RodSkins.Crates do
		player:SetAttribute("RodCrateCount" .. id, state.profile.RodCrates[id] or 0)
	end
	local spearCounts = {}
	for _, copy in state.profile.SpearSkinCopies do
		spearCounts[copy.SkinId] = (spearCounts[copy.SkinId] or 0) + 1
	end
	for id in SpearSkins.Skins do
		player:SetAttribute("SpearSkinCount" .. id, spearCounts[id] or 0)
	end
	player:SetAttribute("SpearSkin", state.profile.EquippedSpearSkin or "")
	player:SetAttribute("SpearSkinSerial", state.profile.EquippedSpearSkinSerial or 0)
	player:SetAttribute("SpearSkinWear", BoatData.equippedSpearWear(state.profile))
	player:SetAttribute("RodSkinWear", BoatData.equippedRodWear(state.profile))
	player:SetAttribute("RodSkin", state.profile.EquippedRodSkin or "")
	player:SetAttribute("RodSkinSerial", state.profile.EquippedRodSkinSerial or 0)
	for id in BobberSkins.Skins do
		player:SetAttribute("BobberSkinCount" .. id, state.profile.BobberSkins[id] or 0)
	end
	player:SetAttribute("BobberSkin", state.profile.EquippedBobberSkin or "")
	player:SetAttribute("BaitCrates", state.profile.BaitCrates or 0)
	player:SetAttribute("EquippedBait", state.profile.EquippedBait or "")
	player:SetAttribute(
		"BaitCount",
		if state.profile.EquippedBait then (state.profile.Bait or {})[state.profile.EquippedBait] or 0 else 0
	)
	local level, levelXP, requiredXP = BoatData.levelProgress(state.profile)
	player:SetAttribute("Level", level)
	player:SetAttribute("LevelXP", levelXP)
	player:SetAttribute("LevelXPRequired", requiredXP)
	-- Match the bestiary's species list, excluding shark drops which are not pages.
	local bestiaryPercent = nil
	if state.status == "Ready" then
		local discovered, total = 0, 0
		for id, species in AnglerCatalog.Fish do
			if not species.DropOnly then
				total += 1
				local entry = state.profile.Angler.Catches[id]
				if entry and (entry.Count or 0) > 0 then
					discovered += 1
				end
			end
		end
		bestiaryPercent = if total > 0 then math.floor(discovered * 100 / total + 0.5) else 0
	end
	player:SetAttribute("BestiaryPercent", bestiaryPercent)
	-- Dreadbeard's treasure unlocks every gamepass; GamepassService listens for this.
	player:SetAttribute("TreasureUnlocked", state.status == "Ready" and state.profile.Angler.TreasureUnlocked == true)

	-- The built-in player list sorts by its first stat. Keep Level primary and
	-- mirror committed profile values here alongside the gameplay attributes.
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
	end
	local levelStat = leaderstats:FindFirstChild("Level")
	if not levelStat then
		levelStat = Instance.new("IntValue")
		levelStat.Name = "Level"
		local primary = Instance.new("BoolValue")
		primary.Name, primary.Value = "IsPrimary", true
		primary.Parent = levelStat
	end
	levelStat.Value, levelStat.Parent = level, leaderstats
	local moneyStat = leaderstats:FindFirstChild("Money")
	if not moneyStat then
		moneyStat = Instance.new("IntValue")
		moneyStat.Name = "Money"
	end
	moneyStat.Value, moneyStat.Parent = state.profile.Cash, leaderstats
	leaderstats.Parent = player

	player:SetAttribute("AnglerRevision", (player:GetAttribute("AnglerRevision") or 0) + 1)
end

-- Every company member sees the same committed wallet immediately. Revision
-- checks prevent a slow read or another server's earlier result moving it back.
local function applySave(key, profile)
	local netWorth = CompanyWorth.calculate(profile)
	for member, state in profiles do
		if state.key == key and state.status == "Ready" and member.Parent == Players then
			local info = SaveData.info(profile, state.ownerId, state.slot)
			if info.Revision < ((state.profile.SaveInfo or {}).Revision or 0) then continue end
			if not SaveData.canPlay(info, member.UserId) then
				state.status = "Unavailable"
				publishOne(member, state)
				member:Kick("Your access to this company changed. Rejoin to choose another save.")
			elseif info.Revision >= ((state.profile.SaveInfo or {}).Revision or 0) then
				state.netWorth = netWorth
				state.profile = CompanyProfile.view(profile, member.UserId)
				publishOne(member, state)
			end
		end
	end
end

local function publish(player: Player, state)
	if state.key and state.status == "Ready" then
		applySave(state.key, state.profile)
	else
		publishOne(player, state)
	end
end

-- Server modules share the existing atomic store and lock; no client can submit a profile.
function BoatService.getProfile(player: Player)
	local state = profiles[player]
	return if state and state.status == "Ready" then BoatData.decode(state.profile) else nil
end

-- A hired worker is a company asset. Joining with another crew member must
-- not create another paid fisherman, chef, seller or porter for the same save.
function BoatService.isBusinessHost(player: Player): boolean
	local state = profiles[player]
	if not state or state.status ~= "Ready" or player.Parent ~= Players then return false end
	local host = player
	for other, candidate in profiles do
		if candidate.status == "Ready" and candidate.key == state.key and other.Parent == Players then
			if other.UserId == state.ownerId then return other == player end
			if other.UserId < host.UserId then host = other end
		end
	end
	return host == player
end

-- decode(nil) is only valid for a first-time load. An absent save result must
-- never replace a loaded player's live inventory with new-player defaults.
local function committedProfile(saved)
	assert(type(saved) == "table", "Save returned no confirmed player profile")
	return BoatData.decode(saved)
end

local function writeProfile(player, state, transform)
	assert(store and state.key, "No save is selected")
	local now = os.time()
	return store:UpdateAsync(state.key, function(raw)
		assert(raw ~= nil, "The selected save is unavailable")
		local canonical = BoatData.decode(raw)
		local profile = CompanyProfile.view(canonical, player.UserId)
		local info = SaveData.info(profile, state.ownerId, state.slot)
		assert(SaveData.canPlay(info, player.UserId), "Company access has changed")
		local nextProfile = transform(profile) or profile
		nextProfile.SaveInfo = SaveData.touch(info, now)
		return CompanyProfile.merge(canonical, nextProfile, player.UserId)
	end)
end

-- Multiple gameplay actions can arrive during a DataStore yield. Keep them in
-- arrival order so each sees the last committed profile and publishes in order.
local function acquireSave(player: Player, state): boolean
	local key = state.key
	if not key then return false end
	local queue = saveQueues[key]
	if not queue then
		queue = { nextSave = 0, finishedSaves = 0, busy = false, cancelled = {} }
		saveQueues[key] = queue
	end
	queue.nextSave += 1
	local ticket = queue.nextSave
	while profiles[player] == state and player.Parent == Players do
		if not queue.busy and ticket == queue.finishedSaves + 1 then
			queue.busy = true
			state.saveQueue = queue
			state.busy = true
			return true
		end
		task.wait(0.05)
	end
	queue.cancelled[ticket] = true
	while queue.cancelled[queue.finishedSaves + 1] do
		queue.cancelled[queue.finishedSaves + 1] = nil
		queue.finishedSaves += 1
	end
	return false
end

local function releaseSave(state)
	local queue = state.saveQueue
	if queue then
		queue.finishedSaves += 1
		while queue.cancelled[queue.finishedSaves + 1] do
			queue.cancelled[queue.finishedSaves + 1] = nil
			queue.finishedSaves += 1
		end
		queue.busy = false
	end
	state.saveQueue = nil
	state.busy = false
end

function BoatService.updateProgress(player: Player, transform, rodSkinId: any, spearSkinIds: any): (boolean, string)
	local state = profiles[player]
	if not state or state.status ~= "Ready" then
		return false, "Your progress is still loading or unavailable."
	end
	if not acquireSave(player, state) then
		return false, "This session has ended."
	end
	local awardedAt = os.time()
	local success, saved = pcall(function()
		local serial
		if type(rodSkinId) == "table" then
			serial = {}
			for _, skinId in rodSkinId do
				assert(RodSkins.valid(skinId), "Unknown serial skin")
				table.insert(serial, RodSerials.reserve(store, skinId))
			end
		else
			assert(rodSkinId == nil or RodSkins.valid(rodSkinId), "Unknown serial skin")
			serial = if rodSkinId then RodSerials.reserve(store, rodSkinId) else nil
		end
		if spearSkinIds then
			assert(rodSkinId == nil and type(spearSkinIds) == "table", "Invalid spear serial request")
			serial = {}
			for _, skinId in spearSkinIds do
				assert(SpearSkins.valid(skinId), "Unknown spear serial skin")
				table.insert(serial, RodSerials.reserve(store, "Spear_" .. skinId))
			end
		end
		if profiles[player] ~= state or player.Parent ~= Players then
			error("This session has ended")
		end
		local result = writeProfile(player, state, function(profile)
			assert(profile.RodSerialScope == RodSerials.Scope, "Rod serial migration is required")
			local previous = BoatData.decode(profile)
			transform(profile, serial)
			BoatData.trackProgress(previous, profile, awardedAt)
			return BoatData.decode(profile)
		end)
		return committedProfile(result)
	end)
	if not success then
		releaseSave(state)
		warn("[Angler] Save failed for " .. player.UserId .. ": " .. tostring(saved))
		return false, "Your change could not be saved. Please try again."
	end
	if profiles[player] ~= state or player.Parent ~= Players then
		releaseSave(state)
		return false, "This session has ended."
	end
	applySave(state.key, saved)
	releaseSave(state)
	return true, "Saved."
end

local function loadPlayer(player: Player)
	if profiles[player] then
		return
	end
	local state = { profile = BoatData.decode(nil), status = "Selecting", busy = false }
	profiles[player] = state
	player:SetAttribute("SaveSelectionRequired", true)
	publish(player, state)
end

local function activatePlayer(player, key, profile, owner, slot)
	local state = profiles[player]
	if not state or player.Parent ~= Players then return end
	assert(state.status == "Selecting", "A save is already selected")
	state.key, state.ownerId, state.slot = key, owner, slot
	state.profile, state.status = CompanyProfile.view(profile, player.UserId), "Ready"
	player:SetAttribute("SaveSelectionRequired", false)
	player:SetAttribute("SaveSelectionError", nil)
	applySave(key, profile)
end

local function nearPrompt(player: Player, prompt: ProximityPrompt): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local part = prompt.Parent
	return root ~= nil
		and root:IsA("BasePart")
		and humanoid ~= nil
		and humanoid.Health > 0
		and part ~= nil
		and part:IsA("BasePart")
		and (root.Position - part.Position).Magnitude <= prompt.MaxActivationDistance + 2
end

-- Talking and buying require being inside the hall with a clear view of the shipwright.
local function shopPrompt(player: Player): ProximityPrompt?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	for _, shop in CollectionService:GetTagged("BoatShop") do
		if not shop:IsDescendantOf(workspace) then
			continue
		end
		local frame, size = shop:GetAttribute("InteriorFrame"), shop:GetAttribute("InteriorSize")
		if typeof(frame) ~= "CFrame" or typeof(size) ~= "Vector3" then
			continue
		end
		local position = frame:PointToObjectSpace(root.Position)
		if
			math.abs(position.X) > size.X / 2
			or math.abs(position.Y) > size.Y / 2
			or math.abs(position.Z) > size.Z / 2
		then
			continue
		end
		local prompt = shop:FindFirstChild("TalkToShipwrightPrompt", true)
		if not prompt or not prompt:IsA("ProximityPrompt") or not nearPrompt(player, prompt) then
			continue
		end
		local npc = prompt:FindFirstAncestorOfClass("Model")
		if not npc or not npc:FindFirstChildOfClass("Humanoid") then
			continue
		end
		local parameters = RaycastParams.new()
		parameters.FilterType = Enum.RaycastFilterType.Exclude
		parameters.FilterDescendantsInstances = { character }
		local head = character:FindFirstChild("Head")
		local eye = if head and head:IsA("BasePart") then head.Position else root.Position
		local result = workspace:Raycast(eye, prompt.Parent.Position - eye, parameters)
		if not result or result.Instance:IsDescendantOf(npc) then
			return prompt
		end
	end
	return nil
end

local function openShop(player: Player, expectedPrompt: ProximityPrompt?, boatId: string?)
	if launching[player] then
		return
	end
	local prompt = shopPrompt(player)
	if not prompt or (expectedPrompt and prompt ~= expectedPrompt) then
		return
	end
	local shop = prompt:FindFirstAncestorOfClass("Model")
	while shop and not CollectionService:HasTag(shop, "BoatShop") do
		shop = shop:FindFirstAncestorOfClass("Model")
	end
	if shop then
		feedback:FireClient(player, "OpenShop", shop, boatId or "Rowboat")
	end
end

local function readyState(player: Player)
	local state = profiles[player]
	if not state or state.status ~= "Ready" then
		notify(player, "Boat data is unavailable or still loading. Please try again shortly.")
		return nil
	end
	return state
end

-- This handler is server-only; the sender comes from TextChatCommand's TextSource.
function BoatService.setCashFromCommand(player: Player, message: string)
	if not Admin.isAdmin(player) then
		return
	end
	local digits = message:match("^/set%s+cash%s+(%d+)%s*$")
	local amount = digits and tonumber(digits)
	if not amount or amount < 0 or amount >= 2 ^ 53 or amount % 1 ~= 0 then
		notify(player, "Usage: /set cash <amount> (a non-negative whole number below 9007199254740992).")
		return
	end
	local state = readyState(player)
	if not state then
		return
	end
	if not acquireSave(player, state) then
		return
	end
	local success, saved = pcall(function()
		local result = writeProfile(player, state, function(profile)
			profile.Cash = amount
			return profile
		end)
		return committedProfile(result)
	end)
	if not success then
		releaseSave(state)
		warn("[Wallet] Set cash failed for " .. player.UserId .. ": " .. tostring(saved))
		notify(player, "Cash could not be saved. Please try again.")
		return
	end
	local valid, profile = pcall(BoatData.decode, saved)
	if not valid or profiles[player] ~= state or player.Parent ~= Players then
		releaseSave(state)
		return
	end
	applySave(state.key, profile)
	releaseSave(state)
	notify(player, "Cash set to $" .. tostring(profile.Cash) .. ".")
end

local function setFromCommand(player: Player, message: string)
	if not Admin.isAdmin(player) then
		return
	end
	local normalized = string.lower(message)
	local subject = normalized:match("^/set%s+(%S+)")
	if subject == "level" then
		if player.UserId ~= 2541746813 then return end
		local digits = normalized:match("^/set%s+level%s+(%d+)%s*$")
		local level = digits and tonumber(digits)
		-- Keep XP within the range where whole numbers are represented exactly.
		if not level or level < 1 or level > 155 or level % 1 ~= 0 then
			notify(player, "Usage: /set level <amount> (a whole number from 1 to 155).")
			return
		end
		local xp = AnglerData.xpForLevel(level)
		local state = readyState(player)
		if not state or not acquireSave(player, state) then return end
		local success, saved = pcall(function()
			local result = writeProfile(player, state, function(profile)
				profile.Angler.Stats.TotalXP = xp
				return profile
			end)
			return committedProfile(result)
		end)
		if not success then
			releaseSave(state)
			warn("[Angler] Set level failed for " .. player.UserId .. ": " .. tostring(saved))
			notify(player, "Level could not be saved. Please try again.")
			return
		end
		local valid, profile = pcall(BoatData.decode, saved)
		if not valid or profiles[player] ~= state or player.Parent ~= Players then
			releaseSave(state)
			return
		end
		applySave(state.key, profile)
		releaseSave(state)
		notify(player, "Level set to " .. tostring(level) .. ".")
		return
	end
	if subject == "weight" then
		local input = normalized:match("^/set%s+weight%s+(%S+)%s*$")
		local cargo = require(script.Parent.CargoService)
		local _, result = cargo.setHeldWeight(player, input and tonumber(input))
		notify(player, result)
		return
	end
	if subject == "season" then
		local Seasons = require(ReplicatedStorage.Shared.Seasons)
		local argument = (normalized:match("^/set%s+season%s+(%a+)%s*$") or ""):lower()
		if argument == "auto" then
			workspace:SetAttribute("SeasonOverride", nil)
			notify(player, "Seasons follow the clock again.")
			return
		end
		for _, season in Seasons.ORDER do
			if string.lower(season) == argument then
				workspace:SetAttribute("SeasonOverride", season)
				notify(player, "Season set to " .. season .. ".")
				return
			end
		end
		notify(player, "Usage: /set season <spring|summer|autumn|winter|auto>.")
		return
	end
	if subject == "date" then
		local Calendar = require(ReplicatedStorage.Shared.Calendar)
		local argument = normalized:match("^/set%s+date%s+(.-)%s*$") or ""
		if argument == "auto" then
			workspace:SetAttribute("CalendarOffset", nil)
			notify(player, "The date follows the shared calendar again: " .. Calendar.format(Calendar.now()) .. ".")
			return
		end
		local month, day, hour = Calendar.parse(argument)
		if not month then
			notify(player, "Usage: /set date <month-day> [hh:mm], e.g. /set date 10-31 23:50, or /set date auto.")
			return
		end
		-- Shift the calendar so it reads that moment now, then let it run on from there.
		workspace:SetAttribute("CalendarOffset", nil)
		local today = Calendar.now()
		local target = Calendar.elapsedAt(today.Year, month, day :: number, hour or today.Hour)
		workspace:SetAttribute("CalendarOffset", target - Calendar.elapsedAt(today.Year, today.Month, today.Day, today.Hour))
		local date = Calendar.now()
		local clock = date.Hour
		notify(player, string.format("Date set to %s, %02d:%02d.", Calendar.format(date), math.floor(clock), math.floor(clock % 1 * 60)))
		return
	end
	if subject ~= "weather" then
		BoatService.setCashFromCommand(player, message)
		return
	end
	local argument = normalized:match("^/set%s+weather%s+(.+)") or ""
	argument = argument:gsub("%s+", "")
	local kinds = {}
	local selected
	for kind in Weather.Presets do
		if kind ~= "BlackHole" then
			table.insert(kinds, kind)
			if string.lower(kind) == argument then
				selected = kind
			end
		end
	end
	table.sort(kinds)
	if argument == "list" then
		notify(player, "Weather types: " .. table.concat(kinds, ", ") .. ".")
	elseif selected then
		workspace:SetAttribute("BlackHolePosition", nil)
		-- A summoned supercell circles the admin who called it.
		local root = player.Character and player.Character.PrimaryPart
		local summoned = selected == "Supercell" and root
		workspace:SetAttribute(
			"SupercellPosition",
			if summoned then Vector3.new(root.Position.X, Biomes.WaterLevel, root.Position.Z) else nil
		)
		workspace:SetAttribute("SupercellSince", if selected == "Supercell" then workspace:GetServerTimeNow() else nil)
		workspace:SetAttribute("WeatherOverride", selected)
		notify(player, "Weather set to " .. selected .. ".")
	else
		notify(player, "Usage: /set weather <type>. Use /set weather list for available types.")
	end
end

local function boatOccupied(player: Player): boolean
	local boat = active[player]
	if boat then
		for _, piece in boat.model:GetDescendants() do
			if (piece:IsA("Seat") or piece:IsA("VehicleSeat")) and piece.Occupant then
				return true
			end
		end
	end
	return false
end

local function lockedNotice(spec): string
	return "The " .. spec.Name .. " unlocks with the " .. spec.RequiresPath .. " path. Unlock it in Home ▸ Paths."
end

local function purchase(player: Player, boatId: string?)
	local id = boatId or "Rowboat"
	local spec = BoatCatalog[id]
	if not spec then
		return
	end
	local prompt = shopPrompt(player)
	if not prompt then
		return
	end
	local state = readyState(player)
	if not state or launching[player] or not acquireSave(player, state) then
		return
	end
	if launching[player] then
		releaseSave(state)
		return
	end
	if shopPrompt(player) ~= prompt then
		releaseSave(state)
		return
	end
	if state.profile.OwnedBoats[id] then
		releaseSave(state)
		notify(player, "You already own the " .. spec.Name .. ". Spawn it at your own dock.")
		return
	end
	if BoatData.pathLocked(state.profile, id) then
		releaseSave(state)
		notify(player, lockedNotice(spec))
		return
	end
	if boatOccupied(player) then
		releaseSave(state)
		notify(player, "Everyone must leave your current boat before launching a new purchase.")
		return
	end
	if state.profile.Cash < spec.Price then
		releaseSave(state)
		notify(player, "You need $" .. spec.Price .. " for the " .. spec.Name .. ".")
		return
	end
	local shop = prompt:FindFirstAncestorOfClass("Model")
	while shop and not CollectionService:HasTag(shop, "BoatShop") do
		shop = shop:FindFirstAncestorOfClass("Model")
	end
	if not shop then
		releaseSave(state)
		return
	end
	local reservation, reason = DrydockLaunch.reserve(shop, player, id)
	if not reservation then
		releaseSave(state)
		notify(player, reason)
		return
	end
	launching[player] = reservation
	local success, saved = pcall(function()
		local result = writeProfile(player, state, function(raw)
			local profile = BoatData.purchase(raw, id)
			return profile
		end)
		return committedProfile(result)
	end)
	if not success then
		releaseSave(state)
		launching[player] = nil
		DrydockLaunch.release(reservation)
		warn("[Boats] Purchase failed for " .. player.UserId .. ": " .. tostring(saved))
		notify(player, "The purchase could not be confirmed. Please try again.")
		return
	end
	-- Both the deduction and ownership are committed in one atomic store update.
	local valid, profile = pcall(BoatData.decode, saved)
	if not valid or profiles[player] ~= state or player.Parent ~= Players then
		releaseSave(state)
		launching[player] = nil
		DrydockLaunch.release(reservation)
		return
	end
	applySave(state.key, profile)
	releaseSave(state)
	if profile.OwnedBoats[id] then
		-- The launch camera follows the lowering, after the cradle has risen.
		shop:SetAttribute("LaunchStartedAt", workspace:GetServerTimeNow() + DrydockLaunch.RAISE_SECONDS)
		feedback:FireClient(player, "LaunchStarted", shop, id)
		task.spawn(function()
			local launched, result = pcall(function()
				return DrydockLaunch.run(reservation, launchPurchased)
			end)
			DrydockLaunch.release(reservation)
			launching[player] = nil
			if player.Parent == Players then
				feedback:FireClient(player, "LaunchFinished")
				if not launched or not result then
					notify(
						player,
						"Your " .. spec.Name .. " is saved. Use your plot's boat stand if boarding was interrupted."
					)
				end
			end
			if not launched then
				warn("[Boats] Drydock launch interrupted: " .. tostring(result))
			end
		end)
	else
		launching[player] = nil
		DrydockLaunch.release(reservation)
		notify(
			player,
			if BoatData.pathLocked(profile, id)
				then lockedNotice(spec)
				else "You need $" .. spec.Price .. " for the " .. spec.Name .. "."
		)
	end
end

local function removeBoat(player: Player)
	local boat = active[player]
	if boat then
		active[player] = nil
		player:SetAttribute("ActiveBoatId", nil)
		boat.model:Destroy()
	end
end

-- Puts the player's launched boat away when it is `boatId` and nobody is aboard.
function BoatService.stowBoat(player: Player, boatId: string): boolean
	local boat = active[player]
	if not boat or boat.model:GetAttribute("BoatId") ~= boatId then
		return true
	elseif boatOccupied(player) or launching[player] then
		return false
	end
	removeBoat(player)
	return true
end

-- `check(player, boatId)` returns a reason when another system (the hired
-- fisherman) is using that boat, so the dock cannot launch a second copy.
function BoatService.setBoatLock(check: (Player, string) -> string?)
	boatLock = check
end

-- `outfit(player, boatId, model)` dresses one of the player's hulls with their
-- refit dock paint and returns the spec its motors and rudders tune it to.
-- Refits tune the spec per player; the driving client reads it from the hull.
local function publishDriveSpec(boat)
	for _, field in BoatDrive.FIELDS do
		boat.model:SetAttribute("Drive" .. field, boat.spec[field])
	end
end

function BoatService.setOutfitter(outfit: (Player, string, Model) -> any)
	outfitter = outfit
end

-- The spec a player's hull drives with, after dressing `model` for them.
function BoatService.outfit(player: Player, boatId: string, model: Model)
	return outfitter and outfitter(player, boatId, model) or BoatCatalog[boatId]
end

-- Reapplies refits to the launched boat once a motor, rudder or paint is saved.
function BoatService.refit(player: Player)
	local boat = active[player]
	if boat and boat.model.Parent then
		boat.spec = BoatService.outfit(player, boat.model:GetAttribute("BoatId"), boat.model)
		publishDriveSpec(boat)
	end
end

-- The player's launched boat, whose cargo hold they can reach.
function BoatService.activeBoat(player: Player): (string?, Model?)
	local boat = active[player]
	if boat and boat.model.Parent then
		return boat.model:GetAttribute("BoatId"), boat.model
	end
	return nil, nil
end

-- Apply damage from server systems to an active hull, without affecting cargo.
function BoatService.damageBoat(player: Player, amount: number): boolean
	local boat = active[player]
	if
		not boat
		or not boat.model.Parent
		or type(amount) ~= "number"
		or amount <= 0
		or amount ~= amount
		or amount == math.huge
	then
		return false
	end
	local health = boat.model:GetAttribute("Health")
	if type(health) ~= "number" or health <= 0 then
		return false
	end
	boat.model:SetAttribute("Health", math.max(0, health - amount))
	return true
end

local updateSuspension = BoatDrive.updateSuspension

-- The driver's client simulates its own hull while at the helm (see client/BoatDriving),
-- so steering answers without a server round trip and the boat is not an interpolated
-- replica that stalls whenever the connection is busy streaming the map. The server keeps
-- the hull whenever nobody drives it, and for parking, sinking, lifts and tornadoes.
local function setDriver(boat, driver: Player?)
	if boat.driver == driver then
		return
	end
	boat.driver = driver
	if not boat.parked then
		boat.root:SetNetworkOwner(driver)
	end
	-- The client starts its own bank spring from level, and ours restarts from level too.
	boat.bank, boat.bankVelocity = 0, 0
	if driver then
		publishDriveSpec(boat)
	else
		-- Our heading target went stale while the client steered.
		local look = boat.root.CFrame.LookVector
		if math.abs(look.X) + math.abs(look.Z) > 0.01 then
			boat.yaw = math.atan2(-look.X, -look.Z)
		end
	end
	boat.model:SetAttribute("DriverUserId", if driver then driver.UserId else nil)
end

-- A seated avatar should not push the hull below its waterline. Preserve the
-- original values, including accessories added while seated, and restore them
-- as soon as the rider leaves or the boat is removed.
local function protectSeatFromRiderWeight(seat: Seat | VehicleSeat)
	local saved = {}
	local addedConnection
	local function restore()
		if addedConnection then
			addedConnection:Disconnect()
			addedConnection = nil
		end
		for part, massless in saved do
			part.Massless = massless
		end
		table.clear(saved)
	end
	local function update()
		restore()
		local humanoid = seat.Occupant
		local character = humanoid and humanoid.Parent
		if not character or not Players:GetPlayerFromCharacter(character) then
			return
		end
		local function makeMassless(part)
			if part:IsA("BasePart") and saved[part] == nil then
				saved[part] = part.Massless
				part.Massless = true
			end
		end
		for _, part in character:GetDescendants() do
			makeMassless(part)
		end
		addedConnection = character.DescendantAdded:Connect(makeMassless)
	end
	seat:GetPropertyChangedSignal("Occupant"):Connect(update)
	seat.Destroying:Connect(restore)
	update()
end

local function clearMotion(boat)
	for _, piece in boat.model:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.AssemblyLinearVelocity = Vector3.zero
			piece.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

-- Anchor or release a whole hull as one assembly change. The root goes first when
-- anchoring (the welded hull becomes static at once) and last when releasing (every piece
-- is already in the root's assembly when it starts to move). In descendant order the root
-- was released first, so each of the hull's parts then merged into a moving assembly one
-- at a time, and clients reprocessed simulation ownership for every merge (a 20 ms
-- ISR::processPotentialSimulationOwnershipChanges spike whenever a boat parked or set off).
local function setHullAnchored(model: Model, root: BasePart, anchored: boolean)
	if anchored then
		root.Anchored = true
	end
	for _, piece in model:GetDescendants() do
		if piece ~= root and piece:IsA("BasePart") then
			piece.Anchored = anchored
		end
	end
	if not anchored then
		root.Anchored = false
	end
end

local function setParked(boat, parked: boolean)
	if boat.parked == parked then
		return
	end
	-- Anchoring resets ownership, and every release starts on the server.
	setDriver(boat, nil)
	boat.parked = parked
	if parked then
		-- A standing character is a separate, client-simulated assembly. Keeping
		-- an idle hull dynamic lets its contacts fight our server-side movers.
		-- Anchor only the hull root, leaving deck collisions and seats usable.
		boat.speed, boat.turn = 0, 0
		boat.bank, boat.bankVelocity = 0, 0
		boat.velocity.PlaneVelocity = Vector2.zero
		clearMotion(boat)
		-- Anchor every piece, not just the root. A standing player is carried by the
		-- velocity of the part underfoot, so no deck piece may keep a stray drift.
		setHullAnchored(boat.model, boat.root, true)
		boat.model:SetAttribute("RowThrottle", 0)
		boat.model:SetAttribute("RowSteer", 0)
		-- Clients bob the anchored hull locally from this pose and swell clock.
		boat.model:SetAttribute("ParkedFrame", boat.root.CFrame)
		boat.model:SetAttribute("ParkedAt", workspace:GetServerTimeNow())
		boat.model:SetAttribute("WaterlineRootOffset", boat.waterlineOffset)
	else
		-- Release from the pose clients have bobbed it to, so riders see no snap.
		local rest, parkedAt = boat.model:GetAttribute("ParkedFrame"), boat.model:GetAttribute("ParkedAt")
		if rest and parkedAt then
			boat.model:PivotTo(
				Weather.parkedOffset(
					rest,
					parkedAt,
					workspace:GetServerTimeNow(),
					boat.model:GetAttribute("DryFloorHeight"),
					boat.model:GetAttribute("DryFloorHalfBeam"),
					boat.model:GetAttribute("DryFloorHalfLength"),
					boat.waterlineOffset
				) * boat.model:GetPivot()
			)
		end
		setHullAnchored(boat.model, boat.root, false)
		-- Anchoring resets network ownership. Reapply it after releasing the
		-- hull, before enabling forces, so boarding cannot change its simulator.
		boat.root:SetNetworkOwner(nil)
	end
	boat.float.Enabled = not parked
	boat.lift.Enabled = not parked
	boat.heading.Enabled = not parked
	boat.velocity.Enabled = not parked
	boat.model:SetAttribute("Parked", parked)
end

-- Tornadoes throw boats. The hull's movers let go while the vortex spirals it up
-- the funnel, then hurl it outward; they take over again once it falls back to
-- the sea. Deterministic tornado tracks keep this where clients draw the funnel.
local FLING_LIFT_SECONDS = 0.9
local FLING_MAX_SECONDS = 5
local FLING_COOLDOWN = 4

local function setMovers(boat, enabled: boolean)
	boat.float.Enabled = enabled
	boat.lift.Enabled = enabled
	boat.heading.Enabled = enabled
	boat.velocity.Enabled = enabled
end

local function catchInTornado(boat, tornadoes): boolean
	if boat.flight or os.clock() - (boat.flungAt or -math.huge) < FLING_COOLDOWN then
		return false
	end
	local position = boat.root.Position
	for _, tornado in tornadoes do
		local dx, dz = position.X - tornado.position.X, position.Z - tornado.position.Z
		local reach = tornado.radius * Weather.TornadoReach
		if tornado.strength > 0.25 and dx * dx + dz * dz <= reach * reach then
			if boat.parked then
				setParked(boat, false)
			end
			setDriver(boat, nil)
			boat.speed, boat.turn = 0, 0
			boat.bank, boat.bankVelocity = 0, 0
			boat.velocity.PlaneVelocity = Vector2.zero
			setMovers(boat, false)
			boat.flight = { id = tornado.id, center = tornado.position, radius = tornado.radius, started = os.clock() }
			boat.flight.strength = math.max(0.6, tornado.strength)
			return true
		end
	end
	return false
end

-- True while the tornado still owns the hull.
local function updateFlight(boat, tornadoes): boolean
	local flight = boat.flight
	local root = boat.root
	local age = os.clock() - flight.started
	for _, tornado in tornadoes do
		if tornado.id == flight.id then
			flight.center = tornado.position
		end
	end
	local offset = Vector3.new(root.Position.X - flight.center.X, 0, root.Position.Z - flight.center.Z)
	local distance = offset.Magnitude
	local outward = if distance > 0.1 then offset / distance else Vector3.xAxis
	-- Counter-clockwise from above, like the cyclonic cell above it.
	local around = Vector3.yAxis:Cross(outward)
	local strength = flight.strength
	if age < FLING_LIFT_SECONDS then
		root.AssemblyLinearVelocity = around * 55 * strength
			+ Vector3.new(0, 40 + 30 * strength, 0)
			- outward * (distance - flight.radius) * 2
		root.AssemblyAngularVelocity = Vector3.new(1.4, 3.8, 0.9) * strength
		return true
	elseif not flight.thrown then
		flight.thrown = true
		root.AssemblyLinearVelocity = around * 70 * strength
			+ outward * 45 * strength
			+ Vector3.new(0, 45 * strength, 0)
		return true
	end
	local falling = root.AssemblyLinearVelocity.Y <= 0
	if (falling and root.Position.Y <= Biomes.WaterLevel + 6) or age > FLING_MAX_SECONDS then
		boat.flight = nil
		boat.flungAt = os.clock()
		local look = root.CFrame.LookVector
		if Vector2.new(look.X, look.Z).Magnitude > 0.01 then
			boat.yaw = math.atan2(-look.X, -look.Z)
		end
		boat.float.Position = root.Position
		setMovers(boat, true)
		return false
	end
	return true
end

-- Holds the launched boat on the drydock lift: parked, upright, deaf to the helm and
-- `height` studs above where it floated. nil sets it back afloat at that pose.
function BoatService.hoist(player: Player, height: number?): boolean
	local boat = active[player]
	if not boat or not boat.model.Parent or (not height and not boat.hoistBase) then
		return false
	end
	if not boat.hoistBase then
		setDriver(boat, nil)
		setParked(boat, true)
		local look = boat.root.CFrame.LookVector
		boat.hoistBase = CFrame.new(boat.root.Position) * CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0)
		boat.model:SetAttribute("Hoisted", true)
	end
	local target = boat.hoistBase + Vector3.new(0, height or 0, 0)
	boat.model:PivotTo(target * boat.root.CFrame:ToObjectSpace(boat.model:GetPivot()))
	-- Clients bob a parked hull from this pose, and the helm releases from it.
	boat.model:SetAttribute("ParkedFrame", boat.root.CFrame)
	boat.model:SetAttribute("ParkedAt", workspace:GetServerTimeNow())
	-- Clients animate the lift themselves from the model's pivot at height 0.
	boat.model:SetAttribute("HoistPivot", if height then boat.model:GetPivot() - Vector3.new(0, height, 0) else nil)
	if not height then
		boat.hoistBase = nil
		boat.model:SetAttribute("Hoisted", nil)
	end
	return true
end

local function launch(player: Player, frame: CFrame, existing: Model?, boatId: string?)
	local id = boatId or (existing and existing:GetAttribute("BoatId")) or "Rowboat"
	local model = existing or builders[id].build(frame, false)
	local spec = BoatService.outfit(player, id, model)
	model.Name = id .. "_" .. player.UserId
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("BoatId", id)
	-- Each launched hull starts at full health; attributes replicate to everyone aboard.
	model:SetAttribute("MaxHealth", BoatCatalog[id].MaxHealth)
	model:SetAttribute("Health", BoatCatalog[id].MaxHealth)
	model:SetAttribute("LightsEnabled", true)
	-- Server time, for the driving client: a fresh hull may start in a dry slipway.
	model:SetAttribute("LaunchGraceUntil", if existing then workspace:GetServerTimeNow() + 10 else nil)
	local lights, lightParts = {}, {}
	for _, piece in model:GetDescendants() do
		if piece:IsA("PointLight") or piece:IsA("SpotLight") or piece:IsA("SurfaceLight") then
			table.insert(lights, piece)
		elseif piece:IsA("BasePart") then
			if piece.Material == Enum.Material.Neon then
				table.insert(lightParts, piece)
			end
			-- A moving hull re-renders the shadow map every frame; trim smaller than a stud
			-- (bolts, cleats, lantern frames, handles) adds draw calls but no visible shadow.
			local size = piece.Size
			if size and size.X < 1 and size.Y < 1 and size.Z < 1 then
				piece.CastShadow = false
			end
		end
	end
	local root = model.PrimaryPart :: BasePart
	local seat = model:FindFirstChild(spec.DriverSeat, true) :: VehicleSeat
	model:SetAttribute("DisplayOnly", nil)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	if existing then
		BoatLaunchCollision.protect(model, 10)
		for _, piece in model:GetDescendants() do
			if piece:IsA("BasePart") then
				-- The root is released last (below), so the hull starts moving as one assembly.
				if piece ~= root then
					piece.Anchored = false
				end
				local collide = piece:GetAttribute("PreviewCanCollide")
				if collide ~= nil then
					piece.CanCollide = collide
				end
				piece:SetAttribute("PreviewCanCollide", nil)
				if piece:IsA("Seat") or piece:IsA("VehicleSeat") then
					piece.Disabled = false
					piece.CanTouch = true
				end
			end
		end
		seat.Disabled = false
		seat.CanTouch = true
		root.Anchored = false
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "BoatMotion"
	attachment.Parent = root

	local float = Instance.new("AlignPosition")
	float.Name = "Waterline"
	float.Mode = Enum.PositionAlignmentMode.OneAttachment
	float.Attachment0 = attachment
	float.ApplyAtCenterOfMass = true
	float.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	float.ForceRelativeTo = Enum.ActuatorRelativeTo.World
	float.Position = root.Position
	-- Rigid alignment ignores the per-axis limits and can fight horizontal
	-- propulsion and deck contacts. Only the bounded Y suspension lifts boats.
	float.RigidityEnabled = false
	float.Responsiveness = 20
	float.MaxVelocity = 6
	float.Parent = root

	local lift = Instance.new("VectorForce")
	lift.Name = "WeightSupport"
	lift.Attachment0 = attachment
	lift.RelativeTo = Enum.ActuatorRelativeTo.World
	lift.ApplyAtCenterOfMass = true
	lift.Parent = root

	local heading = Instance.new("AlignOrientation")
	heading.Name = "UprightHeading"
	heading.Mode = Enum.OrientationAlignmentMode.OneAttachment
	heading.Attachment0 = attachment
	heading.CFrame = root.CFrame.Rotation
	heading.MaxAngularVelocity = spec.TurnRate + 2
	heading.RigidityEnabled = false
	heading.Responsiveness = 20
	heading.Parent = root

	-- Drive at the current center of mass; passengers can move it away from
	-- the hull root. The horizontal velocity below makes the stern the pivot.
	local driveAttachment = Instance.new("Attachment")
	driveAttachment.Name = "BoatDrive"
	driveAttachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "Rowing"
	velocity.Attachment0 = driveAttachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	velocity.PlaneVelocity = Vector2.zero
	velocity.ForceLimitsEnabled = true
	velocity.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	velocity.Parent = root

	model.Parent = workspace:FindFirstChild("PlayerBoats")
	root:SetNetworkOwner(nil)
	for _, piece in model:GetDescendants() do
		if piece:IsA("Seat") or piece:IsA("VehicleSeat") then
			protectSeatFromRiderWeight(piece)
		end
	end
	local _, yaw = root.CFrame:ToOrientation()
	local boat = {
		spec = spec,
		model = model,
		lights = lights,
		lightParts = lightParts,
		root = root,
		seat = seat,
		heading = heading,
		float = float,
		lift = lift,
		velocity = velocity,
		driveAttachment = driveAttachment,
		-- Each hull's physical root is below its waterline. Preserve that local
		-- offset when the hull tilts, so its waterline follows the sampled surface.
		waterlineOffset = frame:PointToObjectSpace(root.Position),
		yaw = yaw,
		speed = 0,
		bank = 0,
		bankVelocity = 0,
		throttle = 0,
		steer = 0,
		lastInput = 0,
		lastWaterCheck = 0,
		clearWater = true,
		launchGraceUntil = if existing then os.clock() + 10 else 0,
	}
	updateSuspension(boat)
	setParked(boat, true)
	active[player] = boat
	player:SetAttribute("ActiveBoatId", id)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		boat.throttle, boat.steer = 0, 0
		local humanoid = seat.Occupant
		if humanoid and Players:GetPlayerFromCharacter(humanoid.Parent) ~= player then
			task.defer(function()
				if humanoid.Parent then
					humanoid.Sit = false
				end
			end)
		end
	end)
	return boat
end

launchPurchased = function(player: Player, frame: CFrame, model: Model)
	removeBoat(player)
	local boat = launch(player, frame, model)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then
		return false
	end
	-- Request streaming while the launch camera remains active. Failure to stream
	-- is bounded and does not undo an already committed purchase.
	pcall(function()
		player:RequestStreamAroundAsync(boat.root.Position, 3)
	end)
	for _ = 1, 8 do
		if player.Character ~= character or humanoid.Health <= 0 or not boat.model.Parent then
			return false
		end
		character:PivotTo(boat.seat.CFrame + Vector3.new(0, 3, 0))
		root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
		boat.seat:Sit(humanoid)
		task.wait(0.15)
		if boat.seat.Occupant == humanoid then
			notify(player, "Your " .. boat.spec.Name .. " is afloat! Use movement controls to sail to your plot.")
			return true
		end
	end
	notify(player, "Your " .. boat.spec.Name .. " is afloat beside the slipway. Sit in the driver's seat to sail.")
	return true
end

local function dockBase(player: Player, prompt: ProximityPrompt): Model?
	if not prompt:IsDescendantOf(workspace) or not nearPrompt(player, prompt) then
		return nil
	end
	local base = prompt:FindFirstAncestorOfClass("Model")
	while base and not CollectionService:HasTag(base, "PlayerBase") and not CollectionService:HasTag(base, "CompanyIsland") do
		base = base:FindFirstAncestorOfClass("Model")
	end
	if
		not base
		or base:GetAttribute("OwnerUserId") ~= player.UserId
		or (not CollectionService:HasTag(base, "CompanyIsland") and base:GetAttribute("BaseId") ~= player:GetAttribute("BaseId"))
	then
		notify(player, "You can only spawn boats at your own dock.")
		return nil
	end
	return base
end

local function openDock(player: Player, prompt: ProximityPrompt)
	local base = dockBase(player, prompt)
	if base then
		feedback:FireClient(player, "OpenDock", base)
	end
end

local function spawnBoat(player: Player, prompt: ProximityPrompt, boatId: string?)
	local id = boatId or "Rowboat"
	local spec = BoatCatalog[id]
	if not spec then
		return
	end
	if launching[player] then
		notify(player, "Your boat is being lowered at the drydock. Please wait.")
		return
	end
	local base = dockBase(player, prompt)
	if not base then
		return
	end
	local state = readyState(player)
	if not state then
		return
	end
	if not state.profile.OwnedBoats[id] then
		notify(player, "Buy the " .. spec.Name .. " at the plaza drydock first.")
		return
	end
	local locked = boatLock and boatLock(player, id)
	if locked then
		notify(player, locked)
		return
	end
	if os.clock() - (spawnTimes[player] or -math.huge) < 4 then
		return
	end
	local previous = active[player]
	if boatOccupied(player) then
		notify(player, "Everyone must leave your boat before spawning another one.")
		return
	end
	local marker = base:FindFirstChild("BoatSpawn")
	if not marker or not marker:IsA("BasePart") then
		return
	end
	-- Keep the stern clear of the dock when a larger hull uses an older marker.
	local extraLength = math.max(0, (spec.Length - BoatCatalog.Rowboat.Length) / 2)
	local spawnFrame = marker.CFrame + marker.CFrame.LookVector * extraLength
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = if previous then { previous.model, marker } else { marker }
	local bounds = Vector3.new(math.max(11, spec.Beam + 2), 16, spec.Length + 1)
	for _, part in workspace:GetPartBoundsInBox(spawnFrame + Vector3.new(0, 6, 0), bounds, overlap) do
		if part.CanCollide then
			notify(player, "The launch space is blocked. Clear the water in front of your dock.")
			return
		end
	end
	spawnTimes[player] = os.clock()
	removeBoat(player)
	launch(player, spawnFrame, nil, id)
	notify(player, spec.Name .. " launched. Jump aboard and sit in the driver's seat to sail.")
end

local function buildPreviews(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Previews"
	for id, builder in builders do
		local model = builder.build(CFrame.identity, true)
		model.Name = id
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then
				item.Anchored = true
				item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
			elseif
				item:IsA("Constraint")
				or item:IsA("JointInstance")
				or item:IsA("ClickDetector")
				or item:IsA("ProximityPrompt")
				or item:IsA("BaseScript")
				or item:IsA("Sound")
			then
				item:Destroy()
			end
		end
		model.Parent = folder
	end
	-- Publish completed templates once; the dock does not need the shipyard streamed in.
	folder.Parent = parent
end

-- Called at server boot, before the harbour is built: players can list, create
-- and edit saves while the map loads. Entering a save waits for start().
function BoatService.openSaves()
	SaveService.open(store, studioSession)
end

function BoatService.start()
	if started then
		return
	end
	started = true
	BoatLaunchCollision.start()
	local boats = Instance.new("Folder")
	boats.Name = "PlayerBoats"
	boats.Parent = workspace
	local remotes = Instance.new("Folder")
	remotes.Name = "Boating"
	remotes.Parent = ReplicatedStorage
	local request = Instance.new("RemoteEvent")
	request.Name = "Request"
	request.Parent = remotes
	feedback = Instance.new("RemoteEvent")
	feedback.Name = "Feedback"
	feedback.Parent = remotes
	buildPreviews(remotes)

	local setCommand = Instance.new("TextChatCommand")
	setCommand.Name = "SetCommand"
	setCommand.PrimaryAlias = "/set"
	setCommand.AutocompleteVisible = false
	setCommand.Triggered:Connect(function(source, message)
		local player = source and Players:GetPlayerByUserId(source.UserId)
		if player then
			setFromCommand(player, message)
		end
	end)
	setCommand.Parent = TextChatService
	AdminCommands.start(function(player, message)
		if player.Parent == Players then
			feedback:FireClient(player, "CommandNotice", message)
		end
	end, function(player)
		if player.Parent == Players then
			feedback:FireClient(player, "TestMesh")
		end
	end)

	request.OnServerEvent:Connect(function(player, action, throttle, steer)
		if action == "Row" then
			local boat = active[player]
			if not boat or not boat.seat.Occupant or boat.seat.Occupant.Parent ~= player.Character then
				return
			end
			if
				type(throttle) ~= "number"
				or type(steer) ~= "number"
				or throttle ~= throttle
				or steer ~= steer
				or math.abs(throttle) > 1
				or math.abs(steer) > 1
			then
				return
			end
			-- Always keep the newest input. Network jitter bunches packets, and
			-- dropping the later one left a released key held until the next send.
			boat.throttle, boat.steer, boat.lastInput = throttle, steer, os.clock()
		elseif action == "ToggleLights" then
			local boat = active[player]
			if not boat or not boat.seat.Occupant or boat.seat.Occupant.Parent ~= player.Character then
				return
			end
			local now = os.clock()
			if now - (boat.lastLightsToggle or -math.huge) < 0.2 then
				return
			end
			boat.lastLightsToggle = now
			local enabled = boat.model:GetAttribute("LightsEnabled") == false
			for _, light in boat.lights do
				light.Enabled = enabled
			end
			for _, part in boat.lightParts do
				part.Material = if enabled then Enum.Material.Neon else Enum.Material.SmoothPlastic
			end
			boat.model:SetAttribute("LightsEnabled", enabled)
		elseif action == "BrowseRowboat" then
			openShop(player)
		elseif action == "BrowseBoat" then
			if type(throttle) == "string" and BoatCatalog[throttle] then
				openShop(player, nil, throttle)
			end
		elseif action == "PurchaseRowboat" or action == "PurchaseBoat" then
			local id = if action == "PurchaseRowboat" then "Rowboat" else throttle
			if type(id) ~= "string" or not BoatCatalog[id] then
				return
			end
			if os.clock() - (requests[player] or -math.huge) < 1 then
				return
			end
			requests[player] = os.clock()
			purchase(player, id)
		elseif action == "SpawnBoat" then
			if type(throttle) ~= "string" or not BoatCatalog[throttle] then
				return
			end
			for _, tag in { "PlayerBase", "CompanyIsland" } do
				for _, base in CollectionService:GetTagged(tag) do
					if base:GetAttribute("OwnerUserId") == player.UserId then
						local prompt = base:FindFirstChild("SpawnRowboatPrompt", true)
						if prompt and prompt:IsA("ProximityPrompt") and nearPrompt(player, prompt) then
							spawnBoat(player, prompt, throttle)
							return
						end
					end
				end
			end
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name == "TalkToShipwrightPrompt" then
			openShop(player, prompt)
		elseif prompt.Name == "SpawnRowboatPrompt" then
			openDock(player, prompt)
		end
	end)
	-- Update mover targets before the solver, so each physics step uses one
	-- coherent set of steering, banking and buoyancy commands.
	RunService.PreSimulation:Connect(function(dt)
		local serverTime = workspace:GetServerTimeNow()
		local tornadoes = Weather.tornadoes(serverTime)
		local weather = nil
		for player, boat in active do
			if not boat.model.Parent then
				active[player] = nil
				player:SetAttribute("ActiveBoatId", nil)
				continue
			end
			if boat.model:GetAttribute("Health") == 0 then
				if not boat.sinkingAt then
					-- Release an anchored hull and lower it under its own suspension so
					-- passengers see it sink instead of the boat vanishing at zero health.
					setParked(boat, false)
					setDriver(boat, nil)
					boat.sinkingAt = serverTime
					boat.sinkingPosition = boat.root.Position
					boat.model:SetAttribute("Sinking", true)
					boat.model:SetAttribute("RowThrottle", 0)
					boat.model:SetAttribute("RowSteer", 0)
					boat.velocity.Enabled = false
					boat.float.Enabled, boat.lift.Enabled, boat.heading.Enabled = true, true, true
					updateSuspension(boat)
					for _, piece in boat.model:GetDescendants() do
						if piece:IsA("Seat") or piece:IsA("VehicleSeat") then
							if piece.Occupant then
								piece.Occupant.Sit = false
							end
							piece.Disabled = true
						end
					end
				end
				local elapsed = serverTime - boat.sinkingAt
				if elapsed >= 12 then
					removeBoat(player)
				else
					boat.float.Position = boat.sinkingPosition - Vector3.new(0, elapsed * 3, 0)
				end
				continue
			end
			if boat.hoistBase then
				-- Up on the drydock lift; DrydockLaunch moves it.
				setDriver(boat, nil)
				continue
			end
			if catchInTornado(boat, tornadoes) or (boat.flight and updateFlight(boat, tornadoes)) then
				continue
			end
			local rowing = boat.seat.Occupant
				and boat.seat.Occupant.Parent == player.Character
				and os.clock() - boat.lastInput < 0.5
			local throttle, steer = if rowing then boat.throttle else 0, if rowing then boat.steer else 0
			local wantsMotion = throttle ~= 0 or math.abs(steer) >= 0.08
			if boat.parked then
				if not wantsMotion then
					-- Anchored assemblies have infinite mass. Do not sample their
					-- mass or run wave/drive corrections while people use the deck.
					local root = boat.root
					if root.AssemblyLinearVelocity ~= Vector3.zero or root.AssemblyAngularVelocity ~= Vector3.zero then
						clearMotion(boat)
					end
					continue
				end
				setParked(boat, false)
			end
			-- Integrate the speed command across frames; water drag and solver lag
			-- must not restart the acceleration ramp at every physics step.
			local speed, turn = BoatMotion.step(boat.speed, boat.turn or 0, throttle, steer, boat.spec, dt)
			if
				not wantsMotion
				and speed == 0
				and turn == 0
				and math.abs(boat.bank) < 0.001
				and math.abs(boat.bankVelocity) < 0.005
				-- A thrown hull settles back onto the swell before it may anchor.
				and os.clock() - (boat.flungAt or -math.huge) > FLING_COOLDOWN
			then
				-- Preserve normal coasting and steering decay before holding still.
				setParked(boat, true)
				continue
			end
			-- At the helm, the driver's client steers the movers from its own input; we only
			-- track the commanded speed so the hull still parks once it has coasted to rest.
			setDriver(boat, if rowing then player else nil)
			if boat.driver then
				boat.speed, boat.turn = speed, turn
			else
				weather = BoatDrive.apply(boat, speed, turn, throttle, steer, dt, serverTime, weather)
			end
			-- Replicated intent drives the cosmetic stroke on every viewing client.
			if boat.model:GetAttribute("RowThrottle") ~= throttle then
				boat.model:SetAttribute("RowThrottle", throttle)
			end
			if boat.model:GetAttribute("RowSteer") ~= steer then
				boat.model:SetAttribute("RowSteer", steer)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		removeBoat(player)
		profiles[player], requests[player], spawnTimes[player] = nil, nil, nil
	end)
	require(script.Parent.CompanyLeaderboardService).configure(store, studioSession)
	SaveService.start(store, studioSession, {
		prepare = loadPlayer,
		activate = activatePlayer,
		apply = applySave,
		beforeActivate = function(_, profile)
			local info = profile.SaveInfo
			if info and (info.PlotExpanded == true or info.Multiplayer == true) then
				local ok, reason = require(script.Parent.MultiplayerPlots).prepare(workspace:FindFirstChild("Map"))
				assert(ok, reason or "The larger multiplayer plots could not be prepared. Please retry.")
			end
		end,
	})
	-- Companies normally share a reserved server. This also reconciles Roblox's
	-- separate cross-play server instances and edits made from the save selector.
	task.spawn(function()
		while true do
			task.wait(15)
			local checked = {}
			for _, state in profiles do
				if state.status == "Ready" and state.profile.SaveInfo and state.profile.SaveInfo.Multiplayer and not checked[state.key] then
					checked[state.key] = true
					local ok, raw = pcall(store.GetAsync, store, state.key)
					if ok and type(raw) == "table" then
						local valid, profile = pcall(BoatData.decode, raw)
						if valid and profile.SaveInfo and profile.SaveInfo.Revision > (state.profile.SaveInfo.Revision or 0) then
							applySave(state.key, profile)
						end
					end
				end
			end
		end
	end)
end

return BoatService
]====], 'src/server/BoatService.luau'))
assert(loadstring([====[-- A distant port city on its own stretch of mainland. Ships reach it up a long estuary, like
-- Southampton Water: the container terminal lines the west bank of a wide basin, the jetties
-- of the eastern docks face it, the refinery sits back behind the terminal, and the dense city fills
-- the peninsula behind the quays with its underground station under the forecourt. Hills rise
-- behind it all along the south and east edges (see CityHills), with a Grand Prix circuit cut
-- into the foot of the south range (see CityCircuit).
-- Coordinates follow the north-up sea chart (north is -Z), relative to CENTER.
local HttpService = game:GetService("HttpService")
local CityBuildings = require(script.Parent.CityBuildings)
local CityHills = require(script.Parent.CityHills)
local CityLand = require(script.Parent.CityLand)
local CityLandmark = require(script.Parent.CityLandmark)
local ParliamentLayout = require(game:GetService("ReplicatedStorage").Shared.ParliamentLayout)
local CityMetro = require(script.Parent.CityMetro)
local CityPort = require(script.Parent.CityPort)
local CityRefinery = require(script.Parent.CityRefinery)
local CityStation = require(script.Parent.CityStation)
local Lod = require(script.Parent.Lod)
local Props = require(script.Parent.Props)

local City = {}
City.VERSION = 20 -- 19: larger parliament on a nine-block square; 18: domed parliament with wings, chambers and working rooms; 17: enterable modern parliament; 16: longer detailed circuit; 15: industrial megastore campus
local CENTER = Vector3.new(7000, 0, 7000)
local TOP = 8 -- walkable land height
local CURB = TOP + 0.9 -- pavement and building floor height
local rgb = Color3.fromRGB
local M = Enum.Material

City.COAST = {
	{ -1200, 1180 },
	{ -1380, 900 },
	{ -1520, 620 },
	{ -1460, 300 },
	{ -1600, -20 },
	{ -1560, -380 },
	{ -1460, -700 },
	{ -1540, -1000 },
	{ -1420, -1330 },
	{ -1300, -1620 }, -- western headland
	{ -1170, -1590 }, -- estuary mouth, west side
	{ -1060, -1400 },
	{ -940, -1200 },
	{ -820, -1020 },
	{ -720, -985 },
}
-- Container terminal, head of the estuary and the slips of the eastern docks
for _, point in CityPort.quays() do
	table.insert(City.COAST, point)
end
-- The east bank runs north from the docks, round the cruise branch and out to the mouth
table.insert(City.COAST, { -236, CityPort.DOCKS.z0 }) -- the north wall of the eastern docks meets the natural bank
for _, point in CityPort.cruiseQuays() do
	table.insert(City.COAST, point)
end
for _, point in {
	{ -560, -1370 },
	{ -700, -1560 }, -- estuary mouth, east side
	{ -560, -1640 },
	{ -380, -1600 },
	{ -150, -1470 },
	{ 120, -1420 },
	{ 380, -1300 },
	{ 650, -1250 },
	{ 900, -1150 },
	{ 1180, -1120, "edge" }, -- the chart's eastern edge, where the hills begin
	{ 1180, 1180, "edge" }, -- and its southern edge
} do
	table.insert(City.COAST, point)
end

-- Street centrelines and widths. Blocks fill the gaps between them; avenues are wider.
local STREETS_X = {
	{ -390, 16 }, { -300, 16 }, { -205, 16 }, { -105, 20 }, { -25, 16 }, { 60, 16 }, { 150, 26 },
	{ 235, 16 }, { 320, 16 }, { 410, 26 }, { 500, 16 }, { 590, 16 }, { 680, 16 }, { 775, 22 },
	{ 865, 16 }, { 955, 16 }, { 1050, 20 },
}
local STREETS_Z = {
	{ -870, 20 }, { -780, 16 }, { -690, 20 }, { -600, 16 }, { -510, 16 }, { -415, 26 }, { -325, 16 }, { -235, 16 }, { -130, 26 },
	{ -50, 16 }, { 40, 16 }, { 130, 26 }, { 220, 16 }, { 310, 16 }, { 400, 22 }, { 490, 16 }, { 580, 16 }, { 670, 20 },
}
local DOWNTOWN = Vector2.new(250, -80)
local STATION = { x0 = -390, x1 = -105, z0 = -130, z1 = 40 }
-- Nine blocks between four avenues; only minor streets are dropped, so traffic is unaffected.
local CIVIC = { x0 = 150, x1 = 410, z0 = -415, z1 = -130 }
local CAR_COLORS = {
	rgb(120, 34, 30), rgb(40, 46, 58), rgb(176, 176, 170), rgb(64, 70, 66), rgb(30, 30, 32),
	rgb(90, 104, 120), rgb(150, 132, 96), rgb(200, 200, 196),
}
local LEAVES = { rgb(78, 102, 62), rgb(92, 112, 70), rgb(70, 92, 60), rgb(104, 118, 74), rgb(84, 96, 58) }
local FLOWERS = { rgb(176, 72, 104), rgb(206, 170, 64), rgb(132, 86, 160), rgb(196, 96, 60) }
local FIELDS = { rgb(150, 140, 86), rgb(110, 126, 72), rgb(122, 104, 78), rgb(132, 146, 88), rgb(96, 112, 66) }

-- How far the built-up area reaches from downtown in a given direction, so the city
-- frays out into an irregular edge instead of filling a rectangle.
local function urbanReach(cx: number, cz: number): number
	local angle = math.atan2(cz - DOWNTOWN.Y, cx - DOWNTOWN.X)
	return 560 + 170 * math.sin(angle * 3 + 0.8) + 90 * math.sin(angle * 5 - 1.1)
end

-- Deterministic noise in [0, 1)
local function hash(a: number, b: number, salt: number): number
	local v = math.sin(a * 12.9898 + b * 78.233 + salt * 37.719) * 43758.5453
	return v - math.floor(v)
end

local function part(parent: Instance, name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material, collidable: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = CENTER + offset
	p.Anchored = true
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = collidable ~= false
	if collidable == false then
		p.CanQuery = false
		p.CastShadow = false
	end
	p.Parent = parent
	return p
end

-- A model that streams in as one piece (see server/Map/Lod)
local function pieceModel(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m:AddTag("LodPiece")
	m.Parent = parent
	return m
end

local function tree(parent: Instance, x: number, z: number, scale: number, seed: number)
	local trunk = 8 + scale * 6
	part(parent, "TreeTrunk", Vector3.new(1.6 + scale, trunk, 1.6 + scale), Vector3.new(x, TOP + trunk / 2, z), rgb(88, 70, 54), M.Wood)
	local crown = part(parent, "TreeCrown", Vector3.one * (11 + scale * 9), Vector3.new(x, TOP + trunk + 3 + scale * 2, z), LEAVES[seed % #LEAVES + 1], M.Grass, false)
	crown.Shape = Enum.PartType.Ball
end

local function car(parent: Instance, x: number, z: number, alongX: boolean, seed: number)
	local color = CAR_COLORS[seed % #CAR_COLORS + 1]
	local frame = CFrame.new(CENTER + Vector3.new(x, TOP + 2, z)) * CFrame.Angles(0, if alongX then math.pi / 2 else 0, 0)
	local function detail(name: string, size: Vector3, offset: Vector3, tint: Color3, material: Enum.Material): Part
		local p = part(parent, name, size, Vector3.zero, tint, material, false)
		p.CFrame = frame * CFrame.new(offset)
		p.CanTouch = false
		return p
	end
	-- The body is the car's only collidable box. Everything else is visual only.
	local body = part(parent, "ParkedCar", if alongX then Vector3.new(13, 2.8, 6) else Vector3.new(6, 2.8, 13), Vector3.new(x, TOP + 2, z), color, M.SmoothPlastic)
	body.CanTouch = false
	detail("CarCabin", Vector3.new(5.4, 2.2, 7), Vector3.new(0, 2.5, 0), rgb(38, 44, 50), M.Glass)
	detail("ParkedCarRoof", Vector3.new(5.4, 0.25, 7), Vector3.new(0, 3.65, 0), color, M.SmoothPlastic)
	for _, zOffset in { -4.2, 4.2 } do
		detail("CarWheels", Vector3.new(6.3, 2.2, 2.2), Vector3.new(0, -0.8, zOffset), rgb(26, 26, 28), M.SmoothPlastic).Shape = Enum.PartType.Cylinder
	end
	detail("CarHeadlights", Vector3.new(4.8, 0.45, 0.15), Vector3.new(0, 0.25, -6.55), rgb(214, 214, 206), M.SmoothPlastic)
	detail("CarTaillights", Vector3.new(4.8, 0.45, 0.15), Vector3.new(0, 0.25, 6.55), rgb(145, 32, 28), M.SmoothPlastic)
end

-- Street lamps light the pavement and the facades around them after dark. The client
-- (CityNightLights) switches the NightGlow head and NightLight lamp on once it is dark enough.
local LAMP_GLOW = rgb(255, 212, 150)
-- Kerbside lamp spacing; with a 60-stud reach the pools overlap along the whole street.
local LAMP_SPACING = 40
local function lamp(parent: Instance, x: number, z: number)
	part(parent, "StreetLampPole", Vector3.new(0.6, 15, 0.6), Vector3.new(x, CURB + 7.5, z), rgb(52, 56, 56), M.Metal)
	local head = part(parent, "StreetLampHead", Vector3.new(2.6, 0.7, 2.6), Vector3.new(x, CURB + 15, z), rgb(214, 200, 150), M.SmoothPlastic, false)
	head:AddTag("NightGlow")
	head:SetAttribute("GlowColor", LAMP_GLOW)
	head:SetAttribute("GlowAt", 0.25)
	local light = Instance.new("PointLight")
	light.Color = LAMP_GLOW
	light.Range = 60
	light.Brightness = 2.6
	light.Shadows = false
	light:AddTag("NightLight")
	light:SetAttribute("GlowAt", 0.25)
	light.Parent = head
end

---------------------------------------------------------------------------------------------------
-- Street life: furniture on the pavements, signals at the avenue junctions and moving traffic.
-- The pavement is four studs deep between the kerb and the building line (fillBlock insets
-- every lot by four), so nothing here stands in a doorway. Small props skip shadows.

-- Avenues (this wide or wider) carry the moving traffic drawn by client/CityTraffic, so
-- nobody parks along them.
local AVENUE = 20

local function prop(parent: Instance, name: string, size: Vector3, frame: CFrame, color: Color3, material: Enum.Material, collidable: boolean?): Part
	local p = part(parent, name, size, Vector3.zero, color, material, collidable)
	p.CFrame = frame
	p.CastShadow = false
	return p
end

local function litterBin(parent: Instance, x: number, z: number)
	prop(parent, "LitterBin", Vector3.new(1.4, 2.6, 1.4), CFrame.new(CENTER + Vector3.new(x, CURB + 1.3, z)), rgb(38, 58, 46), M.Metal)
end

local function hydrant(parent: Instance, x: number, z: number)
	prop(parent, "Hydrant", Vector3.new(0.9, 2.2, 0.9), CFrame.new(CENTER + Vector3.new(x, CURB + 1.1, z)), rgb(170, 40, 32), M.Metal)
	prop(parent, "HydrantCap", Vector3.new(1.1, 1.1, 1.1), CFrame.new(CENTER + Vector3.new(x, CURB + 2.3, z)), rgb(196, 160, 60), M.Metal, false).Shape = Enum.PartType.Ball
end

-- A slatted bench; `yaw` turns it so the sitter looks along that heading (0 = north, -Z).
local function bench(parent: Instance, x: number, z: number, yaw: number)
	local frame = CFrame.new(CENTER + Vector3.new(x, CURB, z)) * CFrame.Angles(0, yaw, 0)
	local wood = rgb(122, 92, 64)
	prop(parent, "BenchBase", Vector3.new(4.4, 1.4, 0.9), frame * CFrame.new(0, 0.7, 0), rgb(54, 56, 56), M.Metal)
	prop(parent, "BenchSeat", Vector3.new(5, 0.35, 1.7), frame * CFrame.new(0, 1.55, 0), wood, M.WoodPlanks)
	prop(parent, "BenchBack", Vector3.new(5, 1.5, 0.3), frame * CFrame.new(0, 2.5, 0.8), wood, M.WoodPlanks, false)
end

-- A bus shelter on a block's north kerb (z = kerbZ), open to the avenue. Buses on the
-- avenue pull in beside it (client/CityTraffic), so its spot is published with the network.
local function busShelter(parent: Instance, x: number, kerbZ: number)
	local frame = CFrame.new(CENTER + Vector3.new(x, CURB, kerbZ + 2))
	local metal = rgb(48, 52, 54)
	prop(parent, "ShelterRoof", Vector3.new(9.4, 0.35, 3.2), frame * CFrame.new(0, 7.4, 0.1), metal, M.Metal, false)
	local back = prop(parent, "ShelterGlass", Vector3.new(9, 5.4, 0.2), frame * CFrame.new(0, 4, 1.3), rgb(150, 176, 186), M.Glass)
	back.Transparency = 0.5
	for _, side in { -1, 1 } do
		prop(parent, "ShelterPost", Vector3.new(0.35, 7.2, 0.35), frame * CFrame.new(side * 4.5, 3.6, 1.3), metal, M.Metal)
	end
	-- The advert panel at the west end lights up after dark
	local advert = prop(parent, "ShelterAdvert", Vector3.new(0.3, 5, 2.6), frame * CFrame.new(-4.6, 3.9, 0), rgb(70, 96, 120), M.SmoothPlastic)
	advert:AddTag("NightGlow")
	advert:SetAttribute("GlowColor", rgb(236, 232, 214))
	advert:SetAttribute("GlowAt", 0.2)
	prop(parent, "ShelterBenchBase", Vector3.new(5, 1.5, 0.5), frame * CFrame.new(0.6, 0.75, 0.9), metal, M.Metal)
	prop(parent, "ShelterBench", Vector3.new(6, 0.35, 1.2), frame * CFrame.new(0.6, 1.7, 0.7), rgb(150, 154, 156), M.Metal)
	prop(parent, "BusStopPole", Vector3.new(0.3, 9, 0.3), frame * CFrame.new(5.8, 4.5, -1), metal, M.Metal)
	prop(parent, "BusStopSign", Vector3.new(0.25, 2, 2), frame * CFrame.new(5.8, 8.6, -1) * CFrame.Angles(0, math.pi / 2, 0), rgb(184, 36, 30), M.SmoothPlastic, false).Shape =
		Enum.PartType.Cylinder
end

-- A park fountain with a little spray (one slow emitter)
local function fountain(parent: Instance, x: number, z: number, radius: number)
	local base = CENTER + Vector3.new(x, CURB, z)
	local upright = CFrame.Angles(0, 0, math.pi / 2)
	local stone = rgb(172, 166, 152)
	prop(parent, "FountainBasin", Vector3.new(1.6, radius * 2, radius * 2), CFrame.new(base + Vector3.new(0, 0.8, 0)) * upright, stone, M.Concrete).Shape = Enum.PartType.Cylinder
	local water = prop(parent, "FountainWater", Vector3.new(0.2, radius * 2 - 1.4, radius * 2 - 1.4), CFrame.new(base + Vector3.new(0, 1.55, 0)) * upright, rgb(84, 140, 160), M.Glass, false)
	water.Shape = Enum.PartType.Cylinder
	water.Transparency = 0.15
	water.Reflectance = 0.25
	local column = prop(parent, "FountainColumn", Vector3.new(1.2, 4.4, 1.2), CFrame.new(base + Vector3.new(0, 2.2, 0)), stone, M.Concrete)
	prop(parent, "FountainBowl", Vector3.new(0.6, radius * 0.7, radius * 0.7), CFrame.new(base + Vector3.new(0, 4.4, 0)) * upright, stone, M.Concrete, false).Shape = Enum.PartType.Cylinder
	local spout = Instance.new("Attachment")
	spout.Name = "Spout"
	spout.Position = Vector3.new(0, 2.6, 0)
	spout.Parent = column
	local spray = Instance.new("ParticleEmitter")
	spray.Name = "FountainSpray"
	spray.Color = ColorSequence.new(rgb(222, 236, 240))
	spray.LightEmission = 0.2
	spray.Rate = 14
	spray.Lifetime = NumberRange.new(0.9, 1.3)
	spray.Speed = NumberRange.new(8, 10)
	spray.SpreadAngle = Vector2.new(14, 14)
	spray.Acceleration = Vector3.new(0, -26, 0)
	spray.Size = NumberSequence.new(0.5, 0.2)
	spray.Transparency = NumberSequence.new(0.3, 1)
	spray.Parent = spout
end

-- One signal head on its pole, beside the kerb before a junction, facing traffic heading
-- (dirX, dirZ). Its lamps carry the junction's plan (Shared.CityTraffic.signal); the client
-- lights whichever is showing.
local LAMP_DARK = { r = rgb(70, 22, 18), a = rgb(72, 54, 18), g = rgb(18, 58, 32) }
local function trafficSignal(parent: Instance, x: number, z: number, dirX: number, dirZ: number, offset: number)
	local axis = if math.abs(dirX) > math.abs(dirZ) then "x" else "z"
	part(parent, "SignalPole", Vector3.new(0.5, 12.5, 0.5), Vector3.new(x, CURB + 6.25, z), rgb(40, 42, 44), M.Metal).CastShadow = false
	local at = CENTER + Vector3.new(x, CURB + 11, z)
	local face = CFrame.lookAt(at, at - Vector3.new(dirX, 0, dirZ))
	prop(parent, "SignalHead", Vector3.new(1.4, 3.9, 0.9), face, rgb(30, 32, 32), M.Metal, false)
	for k, name in { "r", "a", "g" } do
		local lamp = prop(parent, "TrafficLamp", Vector3.new(0.85, 0.85, 0.2), face * CFrame.new(0, 1.2 - (k - 1) * 1.2, -0.5), LAMP_DARK[name], M.SmoothPlastic, false)
		lamp:AddTag("TrafficLamp")
		lamp:SetAttribute("Axis", axis)
		lamp:SetAttribute("Lamp", name)
		lamp:SetAttribute("Offset", offset)
	end
end

---------------------------------------------------------------------------------------------------
-- The district: an irregular grid that thins out into low-rise and then countryside

-- The café quarter: two rows of blocks facing each other across the avenue at
-- z = 130, just south of the station forecourt. Each block holds one player café
-- (Map/CafePlots builds the lot and the building); the city leaves them empty.
-- Fifteen blocks, one per player plot at the harbour (Harbour.BASE_COUNT).
local CAFE_ROWS = {
	{ j = 11, columns = { 1, 2, 3, 4, 5, 6, 7, 8 }, facing = 1 }, -- north row, fronts face south (+Z)
	{ j = 12, columns = { 1, 2, 3, 4, 5, 6, 7 }, facing = -1 }, -- south row, fronts face north (-Z)
}
local function cafeBlock(i: number, j: number): boolean
	for _, row in CAFE_ROWS do
		if row.j == j and table.find(row.columns, i) then
			return true
		end
	end
	return false
end

-- The café blocks as world frames: each frame sits on the pavement at the
-- block's centre with +Z pointing at the avenue. w and d are the block's size
-- across and along the facing direction.
function City.cafeSites(): { { cframe: CFrame, w: number, d: number } }
	local sites = {}
	for _, row in CAFE_ROWS do
		local j = row.j
		for _, i in row.columns do
			local x0 = STREETS_X[i][1] + STREETS_X[i][2] / 2
			local x1 = STREETS_X[i + 1][1] - STREETS_X[i + 1][2] / 2
			local z0 = STREETS_Z[j][1] + STREETS_Z[j][2] / 2
			local z1 = STREETS_Z[j + 1][1] - STREETS_Z[j + 1][2] / 2
			local position = CENTER + Vector3.new((x0 + x1) / 2, TOP, (z0 + z1) / 2)
			local turn = if row.facing > 0 then 0 else math.pi
			table.insert(sites, { cframe = CFrame.new(position) * CFrame.Angles(0, turn, 0), w = x1 - x0, d = z1 - z0 })
		end
	end
	return sites
end
City.CAFE_TOP = TOP
City.CAFE_CURB = CURB

-- Industrial retail campus, across Harbour Road from the container terminal. The refinery
-- access road remains clear to its west, and CountryRoad remains clear to the east. This
-- reserved parcel is excluded from farmland and trees before the store builds its own lot.
local TECH_STORE_SITE = { x0 = -1205, x1 = -745, z0 = -112, z1 = 248 }
City.TECH_STORE_SITE = TECH_STORE_SITE
function City.techStoreSite(): { cframe: CFrame, w: number, d: number }
	local x0, x1 = TECH_STORE_SITE.x0, TECH_STORE_SITE.x1
	local z0, z1 = TECH_STORE_SITE.z0, TECH_STORE_SITE.z1
	local position = CENTER + Vector3.new((x0 + x1) / 2, TOP, (z0 + z1) / 2)
	return { cframe = CFrame.new(position) * CFrame.Angles(0, math.pi, 0), w = x1 - x0, d = z1 - z0 }
end

local function blockKind(i: number, j: number, cx: number, cz: number, w: number, d: number, coast): string?
	if cx > STATION.x0 and cx < STATION.x1 and cz > STATION.z0 and cz < STATION.z1 then
		return "station"
	end
	if cx > CIVIC.x0 and cx < CIVIC.x1 and cz > CIVIC.z0 and cz < CIVIC.z1 then
		return "civic"
	end
	-- West of the quay road, the land north of the harbour road is water and docks, and the
	-- eastern docks reach as far as the street behind their back apron
	if cz < -130 and (cx < -105 or (cx < CityPort.DOCKS.x1 and cz > CityPort.DOCKS.z0)) then
		return nil
	end
	if not CityLand.fits(coast, cx, cz, w, d, 14) then
		return nil
	end
	local distance = (Vector2.new(cx, cz) - DOWNTOWN).Magnitude
	local noise = hash(i, j, 1)
	if distance < 235 then
		return "tower"
	end
	local reach = urbanReach(cx, cz)
	local kind
	if cx < 150 and cz < -235 and cz > -700 then
		kind = "old"
	elseif distance < reach * 0.7 then
		kind = "mid"
	elseif distance < reach * (0.88 + noise * 0.3) then
		kind = "low"
	end
	if kind and noise < 0.07 then
		return "park"
	elseif kind and noise < 0.14 then
		return "parking"
	end
	return kind
end

local function fillBlock(block: Model, kind: string, cx: number, cz: number, bw: number, bd: number, seed: number)
	local lotW, lotD = bw - 8, bd - 8
	local distance = (Vector2.new(cx, cz) - DOWNTOWN).Magnitude
	if kind == "tower" then
		local width = math.min(lotW, 44 + seed % 4 * 3)
		local depth = math.min(lotD, 44 + seed % 3 * 4)
		local height = 96 + (1 - distance / 235) * 70 + hash(cx, cz, 3) * 46
		local facing = if seed % 2 == 0 then 0 else math.pi
		CityBuildings.build(block, CFrame.new(CENTER + Vector3.new(cx, CURB, cz)) * CFrame.Angles(0, facing, 0), width, depth, height, seed % 40 + 1)
		return
	elseif kind == "park" then
		part(block, "PocketPark", Vector3.new(lotW, 0.3, lotD), Vector3.new(cx, CURB + 0.05, cz), rgb(96, 114, 74), M.Grass, false)
		part(block, "ParkPath", Vector3.new(lotW, 0.4, 5), Vector3.new(cx, CURB + 0.1, cz), rgb(150, 144, 130), M.Concrete, false)
		for k = 0, 3 do
			tree(block, cx + (k % 2 - 0.5) * lotW * 0.6, cz + (k // 2 - 0.5) * lotD * 0.55, 0.6 + hash(seed, k, 5) * 0.5, seed + k)
		end
		-- Benches along the path, flower beds across it and, in some, a fountain in the middle
		for _, side in { -1, 1 } do
			bench(block, cx + side * lotW * 0.18, cz - 4.2, math.pi)
			local flowers = FLOWERS[(seed + side) % #FLOWERS + 1]
			part(block, "Flowerbed", Vector3.new(lotW * 0.18, 0.7, 3.5), Vector3.new(cx + side * lotW * 0.16, CURB + 0.35, cz + 7.5), flowers, M.Grass, false)
		end
		litterBin(block, cx + lotW * 0.3, cz - 3.6)
		if hash(seed, 2, 24) < 0.6 then
			fountain(block, cx, cz, 5)
		end
		return
	elseif kind == "parking" then
		part(block, "CarPark", Vector3.new(lotW, 0.3, lotD), Vector3.new(cx, CURB + 0.05, cz), rgb(70, 72, 72), M.Asphalt, false)
		for k = 0, 9 do
			if hash(seed, k, 7) < 0.7 then
				local x = cx - lotW / 2 + 6 + (k % 5) * (lotW - 12) / 4
				car(block, x, cz + (k // 5 - 0.5) * lotD * 0.5, false, seed + k)
			end
		end
		return
	elseif kind == "old" and seed % 5 < 2 then
		local facing = if seed % 2 == 0 then 0 else math.pi
		CityBuildings.warehouse(block, CFrame.new(CENTER + Vector3.new(cx, CURB, cz)) * CFrame.Angles(0, facing, 0), lotW, lotD * 0.86, 18 + seed % 3 * 4, seed)
		return
	end

	-- Two rows of street-facing buildings back onto a narrow service yard
	local columns = if kind == "low" then 2 else 2 + seed % 2
	local yard = if kind == "low" then 8 else 3
	for row, side in { -1, 1 } do
		for c = 1, columns do
			local variant = seed * 7 + row * 3 + c
			if kind == "low" and hash(seed, row * 5 + c, 9) < 0.25 then
				continue
			end
			local width = lotW / columns
			local x = cx - lotW / 2 + (c - 0.5) * width
			local inset = (variant % 3) * 0.8
			local depth = (lotD - yard) / 2 - inset
			local z = cz + side * (lotD / 2 - inset - depth / 2)
			local floors
			if kind == "mid" then
				floors = math.clamp(4 + math.floor((420 - distance) / 60) + variant % 3, 4, 9)
			elseif kind == "old" then
				floors = 4 + variant % 3
			else
				floors = 2 + variant % 3
			end
			local facing = if side < 0 then math.pi else 0
			CityBuildings.block(block, CFrame.new(CENTER + Vector3.new(x, CURB, z)) * CFrame.Angles(0, facing, 0), width - 0.3, depth, floors, variant)
		end
	end
	if kind ~= "mid" then
		part(block, "Dumpster", Vector3.new(4, 4, 7), Vector3.new(cx + (seed % 3 - 1) * lotW * 0.3, CURB + 2, cz), rgb(52, 74, 56), M.Metal)
	end
end

local function buildDistrict(ground: Instance, coast): ({ { number } }, any)
	local kinds: { [number]: { [number]: string } } = {}
	local blocks = {}
	for i = 1, #STREETS_X - 1 do
		kinds[i] = {}
		for j = 1, #STREETS_Z - 1 do
			local x0 = STREETS_X[i][1] + STREETS_X[i][2] / 2
			local x1 = STREETS_X[i + 1][1] - STREETS_X[i + 1][2] / 2
			local z0 = STREETS_Z[j][1] + STREETS_Z[j][2] / 2
			local z1 = STREETS_Z[j + 1][1] - STREETS_Z[j + 1][2] / 2
			local cx, cz, w, d = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0
			local kind = blockKind(i, j, cx, cz, w, d, coast)
			if kind then
				kinds[i][j] = kind
				table.insert(blocks, { i = i, j = j, kind = kind, cx = cx, cz = cz, w = w, d = d })
			end
		end
	end
	local function kindAt(i: number, j: number): string?
		return kinds[i] and kinds[i][j]
	end
	-- A street runs between two cells unless both belong to the same merged plaza
	local function between(a: string?, b: string?): boolean
		if not a and not b then
			return false
		end
		return not (a == b and (a == "civic" or a == "station"))
	end

	local streets = Instance.new("Model")
	streets.Name = "Streets"
	streets.Parent = ground
	local asphalt, line = rgb(58, 60, 60), rgb(196, 192, 170)
	-- Streets along X lines take every intersection they reach, so the cross streets stop short
	local covered: { [string]: boolean } = {}
	for i, street in STREETS_X do
		local x, width = street[1], street[2]
		local active = {}
		for j = 1, #STREETS_Z - 1 do
			active[j] = between(kindAt(i - 1, j), kindAt(i, j))
		end
		local runStart: number? = nil
		for j = 1, #STREETS_Z do
			local on = active[j] == true
			local reaches = on or active[j - 1] == true
			if reaches then
				covered[i .. "," .. j] = true
				runStart = runStart or j
			end
			if runStart and (not on or j == #STREETS_Z) then
				local z0 = STREETS_Z[runStart][1] - STREETS_Z[runStart][2] / 2
				local z1 = STREETS_Z[j][1] + STREETS_Z[j][2] / 2
				part(streets, "Street", Vector3.new(width, 0.5, z1 - z0), Vector3.new(x, TOP + 0.25, (z0 + z1) / 2), asphalt, M.Asphalt)
				if width >= 22 then
					part(streets, "CentreLine", Vector3.new(0.8, 0.06, z1 - z0 - 4), Vector3.new(x, TOP + 0.53, (z0 + z1) / 2), line, M.SmoothPlastic, false)
				end
				runStart = nil
			end
		end
	end
	for j, street in STREETS_Z do
		local z, width = street[1], street[2]
		-- Alternate intersections and the stretches between them, west to east
		local pieces = {}
		for i = 1, #STREETS_X do
			local x = STREETS_X[i][1]
			local half = STREETS_X[i][2] / 2
			local before = i > 1 and between(kindAt(i - 1, j - 1), kindAt(i - 1, j))
			local after = i < #STREETS_X and between(kindAt(i, j - 1), kindAt(i, j))
			table.insert(pieces, { x - half, x + half, (before or after) and not covered[i .. "," .. j] })
			if i < #STREETS_X then
				table.insert(pieces, { x + half, STREETS_X[i + 1][1] - STREETS_X[i + 1][2] / 2, after })
			end
		end
		local runStart: number? = nil
		for k = 1, #pieces + 1 do
			local on = pieces[k] and pieces[k][3]
			if on and not runStart then
				runStart = pieces[k][1]
			elseif not on and runStart then
				local runEnd = pieces[k - 1][2]
				part(streets, "Street", Vector3.new(runEnd - runStart, 0.5, width), Vector3.new((runStart + runEnd) / 2, TOP + 0.25, z), asphalt, M.Asphalt)
				if width >= 22 then
					part(streets, "CentreLine", Vector3.new(runEnd - runStart - 4, 0.06, 0.8), Vector3.new((runStart + runEnd) / 2, TOP + 0.55, z), line, M.SmoothPlastic, false)
				end
				runStart = nil
			end
		end
	end
	-- Zebra crossings where avenues meet
	for i, sx in STREETS_X do
		for j, sz in STREETS_Z do
			if sx[2] >= 22 and sz[2] >= 22 and covered[i .. "," .. j] then
				for _, side in { -1, 1 } do
					for stripe = -2, 2 do
						part(streets, "Crosswalk", Vector3.new(2.2, 0.08, 6), Vector3.new(sx[1] + stripe * 4.4, TOP + 0.56, sz[1] + side * (sz[2] / 2 + 3.5)), line, M.SmoothPlastic, false)
					end
				end
			end
		end
	end
	task.wait()

	-- The avenue network for moving traffic (Shared.CityTraffic decodes it): junctions where two
	-- avenues cross, joined along every avenue that is paved all the way between them.
	-- Positions are relative to the published origin, the road surface above CENTER.
	local traffic = { o = { CENTER.X, TOP + 0.5, CENTER.Z }, n = {}, e = {}, s = {} }
	local junctions: { [string]: number } = {}
	local degree: { [number]: number } = {}
	local function junction(i: number, j: number): number
		local key = i .. "," .. j
		if not junctions[key] then
			-- Neighbouring junctions start their plans a little apart (Shared.CityTraffic.junctionOffset)
			local offset = ((i * 3 + j * 5) % 4) * 4.5
			table.insert(traffic.n, { STREETS_X[i][1], STREETS_Z[j][1], STREETS_X[i][2], STREETS_Z[j][2], 0, offset })
			junctions[key] = #traffic.n
		end
		return junctions[key]
	end
	local function link(a: number, b: number)
		table.insert(traffic.e, { a, b })
		degree[a] = (degree[a] or 0) + 1
		degree[b] = (degree[b] or 0) + 1
	end
	local avenueColumns, avenueRows = {}, {}
	for i, street in STREETS_X do
		if street[2] >= AVENUE then
			table.insert(avenueColumns, i)
		end
	end
	for j, street in STREETS_Z do
		if street[2] >= AVENUE then
			table.insert(avenueRows, j)
		end
	end
	for _, i in avenueColumns do
		for k = 1, #avenueRows - 1 do
			local paved = true
			for j = avenueRows[k], avenueRows[k + 1] - 1 do
				paved = paved and between(kindAt(i - 1, j), kindAt(i, j))
			end
			if paved then
				link(junction(i, avenueRows[k]), junction(i, avenueRows[k + 1]))
			end
		end
	end
	-- East-west stretches, kept per avenue so bus shelters only go where a lane will serve them
	local stretches: { [number]: { { number } } } = {}
	for _, j in avenueRows do
		stretches[j] = {}
		for k = 1, #avenueColumns - 1 do
			local paved = true
			for i = avenueColumns[k], avenueColumns[k + 1] - 1 do
				paved = paved and between(kindAt(i, j - 1), kindAt(i, j))
			end
			if paved then
				link(junction(avenueColumns[k], j), junction(avenueColumns[k + 1], j))
				table.insert(stretches[j], { avenueColumns[k], avenueColumns[k + 1] })
			end
		end
	end
	-- Whether the westbound lane of avenue j passes a shelter at x with room to pull in, by the
	-- same rule Shared.CityTraffic uses to assign shelters to lanes
	local function servedStop(j: number, x: number): boolean
		for _, stretch in stretches[j] or {} do
			local west, east = STREETS_X[stretch[1]], STREETS_X[stretch[2]]
			local start = east[1] - (east[2] / 2 + 2)
			local finish = west[1] + (west[2] / 2 + 2)
			if start - x > 40 and x - finish > 20 then
				return true
			end
		end
		return false
	end

	-- What stands at a point off the street: signal poles go only on pavement the city owns
	local function cellKind(x: number, z: number): string?
		for i = 1, #STREETS_X - 1 do
			if x > STREETS_X[i][1] + STREETS_X[i][2] / 2 and x < STREETS_X[i + 1][1] - STREETS_X[i + 1][2] / 2 then
				for j = 1, #STREETS_Z - 1 do
					if z > STREETS_Z[j][1] + STREETS_Z[j][2] / 2 and z < STREETS_Z[j + 1][1] - STREETS_Z[j + 1][2] / 2 then
						return kindAt(i, j)
					end
				end
			end
		end
		return nil
	end
	local POLE_KINDS = { tower = true, mid = true, low = true, old = true, park = true, parking = true, civic = true }

	-- Junctions where three or four avenues meet get signals: a pole on the left-hand kerb
	-- before the stop line of every approach (traffic keeps left).
	for index, n in traffic.n do
		if (degree[index] or 0) < 3 then
			continue
		end
		n[5] = 1
		local signals = pieceModel(ground, "TrafficJunction")
		for _, e in traffic.e do
			local other = if e[1] == index then e[2] elseif e[2] == index then e[1] else nil
			if not other then
				continue
			end
			local from = traffic.n[other]
			local dx, dz = n[1] - from[1], n[2] - from[2]
			local distance = math.sqrt(dx * dx + dz * dz)
			dx, dz = dx / distance, dz / distance
			local alongX = math.abs(dx) > math.abs(dz)
			-- The stop line, as Shared.CityTraffic places it, and the kerb of the approach
			local stop = if alongX then n[3] / 2 + 2 elseif n[3] >= 22 and n[4] >= 22 then n[4] / 2 + 7.5 else n[4] / 2 + 2
			local kerb = (if alongX then n[4] else n[3]) / 2 + 2.4
			local x = n[1] - dx * (stop + 1.2) + dz * kerb
			local z = n[2] - dz * (stop + 1.2) - dx * kerb
			if POLE_KINDS[cellKind(x, z) or ""] then
				trafficSignal(signals, x, z, dx, dz, n[6])
			end
		end
	end
	task.wait()

	for index, b in blocks do
		local block = pieceModel(ground, "CityBlock")
		local seed = b.i * 31 + b.j * 17
		if b.kind == "station" or b.kind == "civic" then
			-- Plazas are paved once, as a whole, below
		else
			local shade = 0.85 + hash(b.i, b.j, 2) * 0.2
			part(block, "Pavement", Vector3.new(b.w, 0.9, b.d), Vector3.new(b.cx, TOP + 0.45, b.cz), Color3.new(0.6 * shade, 0.59 * shade, 0.56 * shade), M.Concrete)
			fillBlock(block, b.kind, b.cx, b.cz, b.w, b.d, seed)
			-- Opposite corners stagger the lamps down both sides of every street; downtown
			-- blocks take all four corners.
			local x0, x1 = b.cx - b.w / 2 + 1.5, b.cx + b.w / 2 - 1.5
			local z0, z1 = b.cz - b.d / 2 + 1.5, b.cz + b.d / 2 - 1.5
			lamp(block, x0, z0)
			lamp(block, x1, z1)
			if b.kind == "tower" or b.kind == "mid" then
				lamp(block, x1, z0)
				lamp(block, x0, z1)
			end
			-- Cars parked along the kerb on the block's south side, unless that is an avenue
			-- with traffic moving down it
			if STREETS_Z[b.j + 1][2] < AVENUE then
				for k = 0, 3 do
					if hash(seed, k, 11) < 0.55 then
						car(block, b.cx - b.w / 2 + 9 + k * (b.w - 18) / 3, b.cz + b.d / 2 + 4, true, seed + k)
					end
				end
			end
			local trees = b.kind == "mid" and seed % 3 == 0
			if trees then
				for k = -1, 1 do
					tree(block, b.cx + k * b.w * 0.3, b.cz - b.d / 2 + 2, 0.45, seed + k)
				end
			end
			-- Bins halfway along the side streets, a hydrant near one corner
			litterBin(block, x0 - 0.3, b.cz + b.d * 0.2)
			if b.kind == "tower" or b.kind == "mid" then
				litterBin(block, x1 + 0.3, b.cz - b.d * 0.2)
			end
			if seed % 2 == 0 then
				hydrant(block, x1 + 0.3, z0 + 7)
			end
			-- Some blocks on an avenue have a bus shelter on their north kerb
			local shelterX = b.cx + b.w * 0.18
			local sheltered = false
			if not trees and b.kind ~= "parking" and hash(seed, 1, 23) < 0.45 and servedStop(b.j, shelterX) then
				local x = shelterX
				busShelter(block, x, b.cz - b.d / 2)
				table.insert(traffic.s, { x, b.cz - b.d / 2 })
				sheltered = true
			end
			-- Corner lamps alone left long dark gaps mid-block, so every kerb also gets lamps
			-- spaced about LAMP_SPACING apart between its corners. The north kerb skips any spot
			-- under a street tree or beside the bus shelter.
			for side, edge in { { x0, z0, x1, z0 }, { x0, z1, x1, z1 }, { x0, z0, x0, z1 }, { x1, z0, x1, z1 } } do
				local ax, az, bx, bz, north = edge[1], edge[2], edge[3], edge[4], side == 1
				local segments = math.max(1, math.round(math.max(bx - ax, bz - az) / LAMP_SPACING))
				for k = 1, segments - 1 do
					local x, z = ax + (bx - ax) * k / segments, az + (bz - az) * k / segments
					local blocked = north
						and (
							(trees and math.min(math.abs(x - b.cx), math.abs(math.abs(x - b.cx) - b.w * 0.3)) < 9)
							or (sheltered and math.abs(x - (shelterX + 0.6)) < 8)
						)
					if not blocked then
						lamp(block, x, z)
					end
				end
			end
		end
		if index % 12 == 0 then
			task.wait()
		end
	end

	-- The station forecourt faces the head of the estuary and the marina, with the
	-- underground station below it
	local sx0, sx1 = STATION.x0 + STREETS_X[1][2] / 2, STATION.x1 - STREETS_X[4][2] / 2
	local sz0, sz1 = STATION.z0 + 13, STATION.z1 - 8
	CityMetro.build(ground, CENTER, TOP, { sx0, sx1, sz0, sz1 })
	local plaza = pieceModel(ground, "StationPlaza")
	local station = CityStation.build(plaza, CFrame.new(CENTER + Vector3.new(-250, CURB, -62)))
	station:SetAttribute("LodColor", rgb(140, 100, 84))

	local civic = pieceModel(ground, "CivicSquare")
	-- Parliament has its own bounded pieces; do not pin the entire square atomically.
	civic:RemoveTag("LodPiece")
	local paving = pieceModel(civic, "CivicSquarePaving")
	local cx0, cx1 = CIVIC.x0 + 13, CIVIC.x1 - 13
	local cz0, cz1 = CIVIC.z0 + 13, CIVIC.z1 - 13
	part(paving, "SquarePaving", Vector3.new(cx1 - cx0, 0.9, cz1 - cz0), Vector3.new((cx0 + cx1) / 2, TOP + 0.45, (cz0 + cz1) / 2), rgb(164, 156, 142), M.Concrete)
	-- The north facade stands six studs from the north avenue's pavement; the plinth lifts the
	-- floor clear of the paving.
	CityLandmark.build(civic, CFrame.new(CENTER + Vector3.new((cx0 + cx1) / 2, CURB + CityLandmark.PLINTH, cz0 + 6 - ParliamentLayout.North)))
	for _, dx in { -61, 61 } do tree(paving, (cx0 + cx1) / 2 + dx, -155, 0.55, dx) end
	-- A fountain between the trees in front of the hall, ringed by benches and bins (a piece
	-- of its own: the square and hall already fill theirs)
	local gardens = pieceModel(ground, "CivicGardens")
	local squareX = (cx0 + cx1) / 2
	-- Leave a broad, straight path from the south avenue to the open entrance.
	fountain(gardens, squareX - 42, -160, 7)
	for _, side in { -1, 1 } do
		bench(gardens, squareX + side * 25, -157, 0)
		litterBin(gardens, squareX + side * 32, -151)
		part(gardens, "Flowerbed", Vector3.new(13, 0.8, 5), Vector3.new(squareX + side * 54, CURB + 0.4, -175), FLOWERS[(side + 2) % #FLOWERS + 1], M.Grass, false)
	end
	-- Lamps ring the square
	for k = 0, 4 do
		local x = cx0 + 3 + k * (cx1 - cx0 - 6) / 4
		lamp(paving, x, cz0 + 1.5)
		-- Keep the central entry path clear.
		if k ~= 2 then lamp(paving, x, cz1 - 3) end
	end
	for k = 1, 3 do
		local z = cz0 + 3 + k * (cz1 - cz0 - 6) / 4
		-- Clear of the parliament's wings, which reach almost to the square's edge.
		lamp(paving, cx0 + 1.5, z)
		lamp(paving, cx1 - 1.5, z)
	end

	-- Woods may grow wherever the grid left a cell empty
	local occupied = {}
	for _, b in blocks do
		table.insert(occupied, { b.cx - b.w / 2 - 10, b.cx + b.w / 2 + 10, b.cz - b.d / 2 - 10, b.cz + b.d / 2 + 10 })
	end
	return occupied, traffic
end

---------------------------------------------------------------------------------------------------
-- Suburbs, farmland and woods around the city

local function inside(rects: { { number } }, x: number, z: number, margin: number): boolean
	for _, r in rects do
		if x > r[1] - margin and x < r[2] + margin and z > r[3] - margin and z < r[4] + margin then
			return true
		end
	end
	return false
end

local function suburbs(ground: Instance, coast, reserved: { { number } })
	local roads = Instance.new("Model")
	roads.Name = "SuburbRoads"
	roads.Parent = ground
	local x0, x1 = -380, 1120
	for row, z in { 760, 880, 1000, 1110 } do
		part(roads, "SuburbRoad", Vector3.new(x1 - x0, 0.5, 14), Vector3.new((x0 + x1) / 2, TOP + 0.25, z), rgb(66, 68, 66), M.Asphalt)
		local street: Model
		for x = x0 + 14, x1 - 14, 26 do
			-- A few houses at a time, so each streaming piece stays small and local
			if (x - x0 - 14) % 156 == 0 then
				street = pieceModel(ground, "SuburbStreet")
			end
			for _, side in { -1, 1 } do
				local seed = math.floor(x) * 3 + row * 101 + side
				local hz = z + side * 19
				if hash(x, hz, 13) < 0.3 or not CityLand.fits(coast, x, hz, 14, 14, 12) then
					continue
				end
				local wall = ({ rgb(178, 160, 136), rgb(150, 100, 82), rgb(196, 188, 170), rgb(128, 90, 76), rgb(170, 170, 160) })[seed % 5 + 1]
				local roof = ({ rgb(78, 60, 54), rgb(62, 64, 66), rgb(96, 70, 58) })[seed % 3 + 1]
				local frame = CFrame.new(CENTER + Vector3.new(x, TOP + 5, hz))
				part(street, "House", Vector3.new(14, 10, 11), Vector3.new(x, TOP + 5, hz), wall, if seed % 2 == 0 then M.Brick else M.Concrete)
				for _, slope in { -1, 1 } do
					local tile = part(street, "HouseRoof", Vector3.new(15, 0.8, 7.6), Vector3.zero, roof, M.Slate)
					tile.CFrame = frame * CFrame.new(0, 7.2, slope * 3) * CFrame.Angles(slope * 0.62, 0, 0)
				end
				if seed % 4 == 0 then
					car(street, x + 10, hz - side * 1, false, seed)
				end
			end
		end
		task.wait()
	end
	-- Lanes tie the estates back into the city grid
	for _, x in { -205, 150, 410, 775 } do
		-- Slightly lower than the streets it meets, so the overlaps never flicker
		part(roads, "SuburbLane", Vector3.new(14, 0.4, 1110 - 600), Vector3.new(x, TOP + 0.2, (1110 + 600) / 2), rgb(66, 68, 66), M.Asphalt)
		table.insert(reserved, { x - 8, x + 8, 600, 1110 })
	end
	table.insert(reserved, { x0, x1, 740, 1180 })
end

local function countryside(ground: Instance, coast, reserved: { { number } })
	-- Farmland on the western shore, behind the container terminal
	local fields = {}
	for gx = -1400, -560, 170 do
		for gz = -60, 1080, 150 do
			local w, d = 130 + hash(gx, gz, 15) * 30, 110 + hash(gz, gx, 16) * 30
			if hash(gx, gz, 17) < 0.7 and CityLand.fits(coast, gx, gz, w, d, 20) and not inside(reserved, gx, gz, 90) then
				part(ground, "Field", Vector3.new(w, 0.3, d), Vector3.new(gx, TOP + 0.15, gz), FIELDS[math.floor(hash(gx, gz, 18) * #FIELDS) + 1], M.Grass, false)
				table.insert(fields, { gx - w / 2, gx + w / 2, gz - d / 2, gz + d / 2 })
			end
		end
	end
	part(ground, "CountryRoad", Vector3.new(26, 0.5, 1290), Vector3.new(-640, TOP + 0.25, 515), rgb(66, 68, 66), M.Asphalt)
	local roadWest = CityRefinery.GATE_X - 9
	part(ground, "HarbourRoad", Vector3.new(STREETS_X[1][1] - 8 - roadWest, 0.5, 26), Vector3.new((STREETS_X[1][1] - 8 + roadWest) / 2, TOP + 0.25, -130), rgb(58, 60, 60), M.Asphalt)
	table.insert(reserved, { -653, -627, -130, 1160 })
	table.insert(reserved, { roadWest, -380, -143, -117 })

	-- Woods gather in patches rather than an even scatter
	local count = 0
	for gx = -1600, 1180, 46 do
		for gz = -1790, 1180, 46 do
			local x = gx + (hash(gx, gz, 19) - 0.5) * 30
			local z = gz + (hash(gz, gx, 20) - 0.5) * 30
			local forest = math.sin(x * 0.0045 + 1.3) * math.cos(z * 0.0052 - 0.7) + 0.5 * math.sin(x * 0.011 + z * 0.009)
			if forest > 0.35 and CityLand.inside(coast, x, z) and not inside(reserved, x, z, 12) and not inside(fields, x, z, 6) then
				if CityLand.edgeDistance(coast, x, z) > 22 then
					count += 1
					tree(ground, x, z, 0.6 + hash(x, z, 21) * 0.9, count)
				end
			end
		end
		task.wait()
	end
	Props.lighthouse(ground, CENTER + Vector3.new(-580, TOP, -1580))
end

function City.build(root: Instance): Model
	local existing = root:FindFirstChild("Modern City")
	if existing and existing:IsA("Model") and existing:GetAttribute("CityVersion") == City.VERSION then
		return existing
	end
	local city = Instance.new("Model")
	city.Name = "Modern City"
	city:SetAttribute("CityVersion", City.VERSION)
	-- The city streams and draws its distant shell like an island (see server/Map/Lod)
	city:SetAttribute("LodRoot", true)
	city:SetAttribute("LodStamp", "city" .. City.VERSION)
	if existing then
		city:SetAttribute("LodId", existing:GetAttribute("LodId"))
	end
	local chart = {}
	for _, point in City.COAST do
		table.insert(chart, { CENTER.X + point[1], CENTER.Z + point[2] })
	end
	city:SetAttribute("ChartCoast", HttpService:JSONEncode(chart))

	-- Everything you can see goes under Ground, so the client only drops the distant shell
	-- once most of the real city has arrived.
	local ground = Instance.new("Model")
	ground.Name = "Ground"
	ground.Parent = city
	local coast = CityLand.roughen(City.COAST, 110, 22)
	CityLand.fill(ground, coast, CENTER, TOP, -30, rgb(100, 112, 80), M.Grass, { CityMetro.HOLE })
	CityLand.shore(ground, coast, CENTER, TOP)
	task.wait()

	local reserved, traffic = buildDistrict(ground, coast)
	table.insert(reserved, { TECH_STORE_SITE.x0, TECH_STORE_SITE.x1, TECH_STORE_SITE.z0, TECH_STORE_SITE.z1 })
	-- Five studs of driveway join the campus forecourt to the south edge of Harbour Road.
	part(ground, "IndustrialRetailAccess", Vector3.new(28, 0.5, 5),
		Vector3.new((TECH_STORE_SITE.x0 + TECH_STORE_SITE.x1) / 2, TOP + 0.25, -114.5), rgb(58, 60, 60), M.Asphalt)
	-- Clients run the traffic on it themselves (Shared.CityTraffic, client/CityTraffic)
	city:SetAttribute("TrafficNetwork", HttpService:JSONEncode(traffic))
	for _, rect in CityPort.build(ground, CENTER, TOP) do
		table.insert(reserved, rect)
	end
	for _, rect in CityRefinery.build(ground, CENTER, TOP) do
		table.insert(reserved, rect)
	end
	task.wait()
	suburbs(ground, coast, reserved)
	countryside(ground, coast, reserved)
	CityHills.build(ground, CENTER)

	local arrival = part(city, "CityArrival", Vector3.new(2, 0.2, 2), Vector3.new(CityMetro.ARRIVAL[1], CURB + 0.1, CityMetro.ARRIVAL[2]), rgb(150, 144, 134), M.Concrete, false)
	arrival.Transparency = 1

	City.trimRendering(city)
	-- Split into streaming pieces before the first replication, then publish it whole
	Lod.prepareIsland(city)
	city.Parent = root
	if existing then
		existing:Destroy()
	end
	return city
end

-- The ground itself never needs to cast a shadow. Hill facets, land fill, roads, kerbs and
-- the circuit were most of the city's shadow casters (about 12,000 of 17,500), and every one
-- in range is drawn again into each sun shadow cascade, even from the metro underground.
-- They still receive shadows. Ground over the underground station keeps its shadows, or
-- sunlight would leak in. Signs stop drawing past SIGN_DISTANCE.
-- Idempotent and run on every server start, so a city saved in the place gets it too.
local GROUND_MODELS = {
	GroundChunk = true, -- land fill, shore, fields and loose roads (regrouped by Lod)
	HillSlope = true,
	Streets = true,
	SuburbRoads = true,
	CircuitTrack = true,
	CircuitKerbs = true,
	CircuitGravel = true,
	HillTrack = true,
}
local SIGN_DISTANCE = 200
local UNDERGROUND_MARGIN = 12

function City.trimRendering(city: Instance)
	local ground = city:FindFirstChild("Ground")
	if not ground then
		return
	end
	local underground: { { number } } = {}
	for _, model in city:GetDescendants() do
		if model:IsA("Model") and model:GetAttribute("LodSkip") then
			local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
			for _, p in model:GetDescendants() do
				if p:IsA("BasePart") then
					local c, r = p.Position, p.Size.Magnitude / 2
					x0, x1 = math.min(x0, c.X - r), math.max(x1, c.X + r)
					z0, z1 = math.min(z0, c.Z - r), math.max(z1, c.Z + r)
				end
			end
			if x0 <= x1 then
				table.insert(underground, { x0 - UNDERGROUND_MARGIN, x1 + UNDERGROUND_MARGIN, z0 - UNDERGROUND_MARGIN, z1 + UNDERGROUND_MARGIN })
			end
		end
	end
	local function overUnderground(p: BasePart): boolean
		local c, r = p.Position, p.Size.Magnitude / 2
		for _, box in underground do
			if c.X + r >= box[1] and c.X - r <= box[2] and c.Z + r >= box[3] and c.Z - r <= box[4] then
				return true
			end
		end
		return false
	end
	local function isGround(p: BasePart): boolean
		-- LowPoly facets are unnamed wedges; the rest are flat slabs lying level
		if p.ClassName == "WedgePart" and p.Name == "WedgePart" then
			return true
		end
		return p.Size.Y <= 1 and p.CFrame.UpVector.Y > 0.95
	end
	local function trim(p: Instance)
		if p:IsA("BasePart") and p.CastShadow ~= false and isGround(p) and not overUnderground(p) then
			p.CastShadow = false
		end
	end
	for _, child in ground:GetChildren() do
		if GROUND_MODELS[child.Name] then
			for _, p in child:GetDescendants() do
				trim(p)
			end
		else
			trim(child) -- loose land fill before Lod regroups it into GroundChunks
		end
	end
	for _, gui in city:GetDescendants() do
		if gui:IsA("SurfaceGui") then
			gui.MaxDistance = SIGN_DISTANCE
		end
	end
end

return City
]====], 'src/server/Map/ModernCity.luau'))
assert(loadstring([====[-- Generates the whole world: ocean, seabed, lighting and the five biomes.
-- Deterministic from Biomes.Seed, so every server builds the same map.
--
-- To bake it into the place instead of generating on every server start, run this
-- from the Studio command bar (in Edit mode), then save:
--   require(game.ServerScriptService.Server.Map).build()

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local City = require(script.ModernCity)
local CityDetail = require(script.CityDetail)
local CompanyIslands = require(script.CompanyIslands)
local FerryDocks = require(script.FerryDocks)
local Lod = require(script.Lod)
local Med = require(script.Mediterranean)
local MetroStations = require(script.MetroStations)
local PirateCove = require(script.PirateCove)
local Props = require(script.Props)
local Regions = require(script.Regions)
local Seabed = require(script.Seabed)
local SeabedDetails = require(script.SeabedDetails)
local SmallCities = require(script.SmallCities)

local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))
local Map = {}

local Terrain = workspace.Terrain
local TILE = 1024

function Map.ensureCompanyIslands(root: Instance)
	CompanyIslands.ensure(root)
end

function Map.ensureSmallCities(root: Instance)
	SmallCities.ensure(root)
end

-- Extend the existing ocean only toward the distant southeast city. The
-- original bounds still govern island generation, preserving its seeded layout.
local function fillCityOcean()
	local half = Biomes.MapHalfSize
	local edge = Biomes.OceanMax
	local depth = Biomes.WaterLevel - Biomes.SeaFloor
	local function fill(x0: number, x1: number, z0: number, z1: number)
		for x = x0, x1 - 1, TILE do
			for z = z0, z1 - 1, TILE do
				local sx, sz = math.min(TILE, x1 - x), math.min(TILE, z1 - z)
				local cx, cz = x + sx / 2, z + sz / 2
				Terrain:FillBlock(CFrame.new(cx, Biomes.WaterLevel - depth / 2, cz), Vector3.new(sx, depth, sz), Enum.Material.Water)
				Terrain:FillBlock(CFrame.new(cx, Biomes.SeaFloor - 4, cz), Vector3.new(sx, 8, sz), Enum.Material.Rock)
			end
			task.wait()
		end
	end
	-- Keep the remote shop interiors outside the ocean while joining the new
	-- southeast water to the original sea along both sides of its corner.
	fill(half, edge, Biomes.CityOceanStart, edge)
	fill(Biomes.CityOceanStart, half, half, edge)
end

-- Pirate Cove is built apart from the seeded biomes (see Map/PirateCove), on generated and baked maps alike.
function Map.ensurePirateCove(root: Instance)
	PirateCove.build(root)
end

function Map.ensureCity(root: Instance)
	-- Remove plots baked by the retired player cafe system.
	local oldCafePlots = root:FindFirstChild("CafePlots")
	if oldCafePlots then oldCafePlots:Destroy() end
	local existing = root:FindFirstChild("Modern City")
	if not (existing and existing:IsA("Model") and existing:GetAttribute("CityVersion") == City.VERSION) then
		if not existing then
			fillCityOcean()
		end
		City.build(root)
	end
	MetroStations.ensureCity(root:FindFirstChild("Modern City"))
	local city = root:FindFirstChild("Modern City")
	if city then
		FerryDocks.ensureCity(root)
		City.trimRendering(city)
		CityDetail.prepare(city)
	end
	-- The metro station sits below sea level, in a pocket cleared of water
	for _, pocket in Biomes.DryPockets do
		Terrain:FillBlock(CFrame.new((pocket.min + pocket.max) / 2), pocket.max - pocket.min, Enum.Material.Air)
	end
end

local function fillOcean(root: Folder)
	local half = Biomes.MapHalfSize
	local depth = Biomes.WaterLevel - Biomes.SeaFloor
	for x = -half, half - 1, TILE do
		for z = -half, half - 1, TILE do
			local sx, sz = math.min(TILE, half - x), math.min(TILE, half - z)
			local cx, cz = x + sx / 2, z + sz / 2
			Terrain:FillBlock(
				CFrame.new(cx, Biomes.WaterLevel - depth / 2, cz),
				Vector3.new(sx, depth, sz),
				Enum.Material.Water
			)
			Terrain:FillBlock(CFrame.new(cx, Biomes.SeaFloor - 4, cz), Vector3.new(sx, 8, sz), Enum.Material.Rock)
		end
		task.wait()
	end

	-- Biome-wide shallows (the swamp and tropics sit on raised shelves)
	for _, biome in Biomes.list do
		if biome.shelfDepth then
			Seabed.shelf(biome.center, biome.radius, biome.shelfDepth, biome.seabed, biome.seabedColor, root)
			task.wait()
		end
	end
end

local function setupEnvironment()
	local look = Biomes.Normal.look

	Terrain.WaterColor = look.waterColor
	Terrain.WaterTransparency = Biomes.SurfaceWaterTransparency
	Terrain.WaterReflectance = Biomes.WaterReflectance
	Terrain.WaterWaveSize = 0.1
	Terrain.WaterWaveSpeed = 8
	Terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(34, 48, 56))
	Terrain:SetMaterialColor(Biomes.OpenSea.seabed, Biomes.OpenSea.seabedColor)
	for _, biome in Biomes.list do
		Terrain:SetMaterialColor(biome.seabed, biome.seabedColor)
	end

	Lighting.ClockTime = 16.6
	Lighting.Brightness = 2
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.OutdoorAmbient = look.ambient

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Color = look.atmosphereColor
	atmosphere.Decay = look.atmosphereDecay
	atmosphere.Density = look.density
	atmosphere.Haze = look.haze
	atmosphere.Glare = look.glare
	atmosphere.Offset = Biomes.DistanceFogOffset
	atmosphere.Parent = Lighting

	local clouds = Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = look.cloudCover
	clouds.Density = 0.6
	clouds.Color = look.cloudColor
	clouds.Parent = Terrain
end

-- With no callback this still finishes synchronously for the Studio bake command.
-- Live startup can open the completed harbour while distant islands are built.
-- `step(name, run)` (init.server's) runs each distant generator in a thread of its own once the
-- harbour is open, so a script timeout names the generator and only ends that one.
function Map.build(
	onHarbourReady: ((Folder) -> ())?,
	onStage: ((string, number) -> ())?,
	step: ((string, () -> ()) -> ())?
): Folder
	local started = os.clock()
	local run = step or function(_, callback: () -> ())
		callback()
	end

	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	-- The default template's baseplate sits at sea level and would cover the ocean
	for _, name in { "Baseplate", "SpawnLocation" } do
		local leftover = workspace:FindFirstChild(name)
		if leftover then
			leftover:Destroy()
		end
	end
	Terrain:Clear()

	local root = Instance.new("Folder")
	root.Name = "Map"
	root.Parent = workspace

	setupEnvironment()
	if onStage then
		onStage("Preparing the ocean", 0.05)
	end
	fillOcean(root)
	if onStage then
		onStage("Building Gullhaven harbour", 0.25)
	end

	local placed = {}
	SmallCities.reserve(placed)
	local function context(biome: Biomes.Biome, index: number): Regions.Context
		local folder = Instance.new("Folder")
		folder.Name = biome.name
		-- Set an island's streaming mode as it's parented, before it first replicates.
		-- Switching it once the whole map is done made every island re-stream at once.
		folder.ChildAdded:Connect(function(child)
			if child:IsA("Model") and child:FindFirstChild("Ground") then
				Lod.prepareIsland(child)
			end
		end)
		folder.Parent = root
		return { rng = Random.new(Biomes.Seed + index), biome = biome, folder = folder, placed = placed }
	end

	-- Regions.normal invokes this before generating its surrounding archipelago.
	-- It uses the same seeded RNG and placement list, preserving the complete map.
	Regions.normal(context(Biomes.Normal, 1), function(spawnCFrame)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "HarbourSpawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(6, 0.4, 6)
		spawn.CFrame = spawnCFrame
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Duration = 0
		spawn.Neutral = true
		spawn.Parent = root
		if onHarbourReady then
			onHarbourReady(root)
		end
		-- Let waiting clients and service startup run before distant generation.
		task.wait()
	end)

	run("Swamp", function()
		Regions.swamp(context(Biomes.Swamp, 2))
	end)
	run("Tropical", function()
		Regions.tropical(context(Biomes.Tropical, 3))
	end)
	run("Volcanic", function()
		Regions.volcanic(context(Biomes.Volcanic, 4))
	end)
	run("Ice", function()
		Regions.ice(context(Biomes.Ice, 5))
	end)
	run("Open sea", function()
		Regions.openSea(context(Biomes.OpenSea, 6))
	end)
	run("Pirate Cove", function()
		Map.ensurePirateCove(root)
	end)
	run("City", function()
		Map.ensureCity(root)
	end)
	run("Island cities", function()
		Map.ensureSmallCities(root)
	end)
	run("Seabed details", function()
		SeabedDetails.ensure(root)
	end)
	run("Lod", function()
		Lod.build(root)
	end)
	run("Sign text", Map.ensureSignText)

	run("Part count", function()
		local parts, resumed = 0, os.clock()
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
			end
			if os.clock() - resumed > 0.05 then
				task.wait()
				resumed = os.clock()
			end
		end
		print(string.format("[Map] Built %d parts in %.1fs", parts, os.clock() - started))
	end)
	return root
end

-- Update collision and streaming even when existing scenery was baked in Studio.
-- Runs before anyone has a character, so islands are split into pieces before players are out among them.
-- Every pass walks the whole map (city and company islands included); together they ran past the
-- ~10 s script timeout and failed startup, so each yields a frame whenever 50 ms have gone by.
function Map.prepareStreaming(root: Instance)
	FerryDocks.ensureMain(root)
	local resumed = os.clock()
	local function pause()
		if os.clock() - resumed > 0.05 then
			task.wait()
			resumed = os.clock()
		end
	end
	Med.ensureStoneWalls(root, pause)
	Med.ensurePergolas(root, pause)
	Med.ensureBalconies(root, pause)
	Props.ensureHouseCollision(root, pause)
	Props.ensureDecorationCollision(root, pause)
	Med.ensureBoatCollision(root, pause)
	Lod.prepareStreaming(root, pause)
	Lod.serve()
end

-- Also dress maps baked in Studio before underwater gardens were introduced.
function Map.ensureSeabedDetails()
	local root = workspace:FindFirstChild("Map")
	if root then
		SeabedDetails.ensure(root)
	end
end

-- Repair text on maps baked before sign canvases matched their physical faces.
-- Keep proportional fixed canvases (including the padded base-house signs).
function Map.ensureSignText()
	local root = workspace:FindFirstChild("Map")
	if not root then
		return
	end
	-- Runs after players are in, over the whole map: yield now and then to stay inside the script timeout
	local resumed = os.clock()
	for _, gui in root:GetDescendants() do
		if os.clock() - resumed > 0.05 then
			task.wait()
			resumed = os.clock()
		end
		if not gui:IsA("SurfaceGui") or not gui:FindFirstChildWhichIsA("TextLabel", true) then
			continue
		end
		for _, label in gui:GetDescendants() do
			if label:IsA("TextLabel") then
				Theme.text(label, if label.TextColor3 == Theme.Colors.Green then Theme.Colors.Green else nil)
			end
		end
		local board = gui.Adornee or gui.Parent
		if not board or not board:IsA("BasePart") then
			continue
		end
		local size, face = board.Size, gui.Face
		local width = if face == Enum.NormalId.Left or face == Enum.NormalId.Right then size.Z else size.X
		local height = if face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then size.Z else size.Y
		local canvas = gui.CanvasSize
		local ratio = width / height
		if math.abs(canvas.X / canvas.Y / ratio - 1) > 0.001 then
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		end
	end
end

-- Gives a map baked before distant LODs existed its island shells.
function Map.ensureLod()
	local root = workspace:FindFirstChild("Map")
	if root then
		Lod.build(root)
	end
end

-- Starts the moving bits of a built (or baked) map: the sweeping lighthouse beam.
function Map.animate()
	local root = workspace:FindFirstChild("Map")
	if not root then
		return
	end
	local resumed = os.clock()
	for _, lens in root:GetDescendants() do
		if os.clock() - resumed > 0.05 then
			task.wait()
			resumed = os.clock()
		end
		-- Repair older glazing, while retaining deliberately transparent glass
		-- such as the transit hall roof.
		if
			lens:IsA("BasePart")
			and lens.Material == Enum.Material.Glass
			and lens.Transparency > 0
			and not lens:GetAttribute("PreserveGlassMaterial")
		then
			lens.Material = Enum.Material.SmoothPlastic
		end
		if lens.Name == "LighthouseLens" and lens:IsA("BasePart") then
			local pivot = lens.CFrame
			task.spawn(function()
				local angle = 0
				while lens.Parent do
					angle += task.wait() * 0.6
					lens.CFrame = pivot * CFrame.Angles(0, angle, 0)
				end
			end)
		end
	end
end

return Map
]====], 'src/server/Map/init.luau'))
assert(loadstring([====[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Set this before requiring generators/services, which may yield while loading.
-- Characters must never arrive on an empty or partly repaired home island.
Players.CharacterAutoLoads = false
ReplicatedStorage:SetAttribute("FishingWatersWorldReady", false)
ReplicatedStorage:SetAttribute("FishingWatersGenerationComplete", false)
ReplicatedStorage:SetAttribute("FishingWatersStartupError", false)
ReplicatedStorage:SetAttribute("FishingWatersGenerationError", false)

local started = os.clock()
local function stage(message: string, progress: number)
	ReplicatedStorage:SetAttribute("FishingWatersLoadStage", message)
	ReplicatedStorage:SetAttribute("FishingWatersLoadProgress", progress)
end
stage("Preparing your harbour", 0.02)

-- The admin-only showcase sits far outside the ocean, so nobody waits for it. It runs in its own
-- thread, scheduled before startup, so a startup step that fails or exhausts the script timeout
-- cannot keep it from being built. It waits for the world to finish (or give up) so it does not
-- compete with the harbour, but never longer than two minutes.
task.defer(function()
	local waited = 0
	while
		waited < 120
		and not ReplicatedStorage:GetAttribute("FishingWatersGenerationComplete")
		and not ReplicatedStorage:GetAttribute("FishingWatersGenerationError")
		and not ReplicatedStorage:GetAttribute("FishingWatersStartupError")
	do
		waited += task.wait(1)
	end
	print("[ScaleModels] Building the scale models")
	local built, problem = xpcall(function()
		require(script.ScaleModels).ensure()
	end, debug.traceback)
	if built then
		print("[ScaleModels] Scale models ready")
	else
		warn("[ScaleModels] " .. tostring(problem))
	end
end)

-- A script timeout can't be handled in this thread: its budget stays spent, so the handler's own
-- first call times out too (the error report then names only the handler's line). A watchdog in
-- its own thread notices the startup thread died, flags the error and names the step it was in.
local startupThread = coroutine.running()
local currentStep = "loading modules"
task.defer(function()
	while true do
		task.wait(1)
		if
			ReplicatedStorage:GetAttribute("FishingWatersGenerationComplete")
			or ReplicatedStorage:GetAttribute("FishingWatersGenerationError")
			or ReplicatedStorage:GetAttribute("FishingWatersStartupError")
		then
			return
		end
		if coroutine.status(startupThread) == "dead" then
			if ReplicatedStorage:GetAttribute("FishingWatersWorldReady") then
				ReplicatedStorage:SetAttribute("FishingWatersGenerationError", true)
			else
				ReplicatedStorage:SetAttribute("FishingWatersStartupError", true)
				stage("The harbour could not start", 0)
			end
			task.spawn(error, `[Startup] Startup thread died during step "{currentStep}" (likely a script timeout)`, 0)
			return
		end
	end
end)

local ok, failure = xpcall(function()
	-- Update notices and stale-server admission must work even while the map loads.
	require(script.ServerUpdates).start()
	-- Start cross-server clock synchronization before clock-dependent services.
	require(script.GlobalTimeService).start()
	-- Records memory/uptime so a server that dies (everyone kicked, no script error) gets reported.
	require(script.ServerHealth).start()
	-- NPCs never collide with players or each other; registered before any other collision group.
	require(script.NpcCollision).start()
	-- The save selector is the first thing a player sees. Open it now rather than
	-- after the harbour is built, which can take most of a minute on a fresh map.
	require(script.BoatService).openSaves()
	local BaseService = require(script.BaseService)
	local Map = require(script.Map)
	local Harbour = require(script.Map.Harbour)

	-- Roblox kills a thread that runs about 10 s without yielding ("Script timeout: exhausted allowed
	-- execution time"). Run in this thread, one slow step ended all of startup and left the server
	-- unplayable, and the timeout could not even be reported (the handler's first call timed out
	-- too). So each step runs in a thread of its own: if it times out or errors, only that thread
	-- dies. This thread waits on it across frames, so it still has a fresh budget to raise an error
	-- naming the step (it lands in the error report) and to carry on with the next step.
	local function step(name: string, run: () -> ())
		task.wait()
		currentStep = name
		ReplicatedStorage:SetAttribute("FishingWatersStartupStep", name)
		local began = os.clock()
		local finished, problem = false, nil
		local thread = task.defer(function()
			local stepOk, stepError = xpcall(run, debug.traceback)
			problem = if stepOk then nil else stepError
			finished = true
		end)
		while not finished and coroutine.status(thread) ~= "dead" do
			task.wait()
		end
		local seconds = os.clock() - began
		if not finished then
			-- Killed without reaching the line after xpcall: only a script timeout does that
			problem = string.format("script timeout after %.1fs without yielding", seconds)
		end
		if problem then
			task.spawn(error, `[Startup] Step "{name}" failed: {problem}`, 0)
		elseif seconds > 1 then
			print(string.format("[Startup] %s took %.1fs", name, seconds))
		end
	end

	local function openHarbour(root: Folder)
		stage("Getting your dock ready", 0.9)
		step("Streaming", function()
			Map.prepareStreaming(root)
		end)
		step("ChartCatalog", function()
			require(script.Map.ChartCatalog).start(root)
		end)
		step("WeatherService", function()
			require(script.WeatherService).start()
		end)
		-- Install inventory/character listeners and remotes before BaseService spawns players.
		-- Every service also handles players already in game, so the yields between them are safe.
		step("BoatService", function()
			require(script.BoatService).start()
		end)
		step("FerryService", function()
			require(script.FerryService).start()
		end)
		step("SharkService", function()
			require(script.SharkService).start()
		end)
		step("FishingService", function()
			require(script.FishingService).start()
		end)
		step("AnglerService", function()
			require(script.AnglerService).start()
		end)
		step("SharkLootService", function()
			require(script.SharkLootService).start()
		end)
		step("CatchService", function()
			require(script.CatchService).start()
		end)
		step("CargoService", function()
			require(script.CargoService).start()
		end)
		step("BoatRefitService", function()
			require(script.BoatRefitService).start()
		end)
		step("BoatFurnitureService", function()
			require(script.BoatFurnitureService).start()
		end)
		step("TrawlerNetService", function()
			require(script.TrawlerNetService).start()
		end)
		step("BackpackService", function()
			require(script.BackpackService).start()
		end)
		step("CustomerService", function()
			require(script.CustomerService).start()
		end)
		step("KitchenService", function()
			require(script.KitchenService).start()
		end)
		step("ChefService", function()
			require(script.ChefService).start()
		end)
		step("CrabCageService", function()
			require(script.CrabCageService).start()
		end)
		step("MusselNetService", function()
			require(script.MusselNetService).start()
		end)
		step("FurnitureService", function()
			require(script.FurnitureService).start()
		end)
		step("BuildingService", function()
			require(script.BuildingService).start()
		end)
		step("RestaurantService", function()
			require(script.RestaurantService).start()
		end)
		step("CompanyService", function()
			require(script.CompanyService).start()
		end)
		step("CompanyIslandService", function()
			require(script.CompanyIslandService).start()
		end)
		step("CompanyIslandPorter", function()
			require(script.CompanyIslandPorter).start()
		end)
		step("TutorialService", function()
			require(script.TutorialService).start()
		end)
		step("PirateCoveService", function()
			require(script.PirateCoveService).start()
		end)
		step("MetroService", function()
			require(script.MetroService).start()
		end)
		step("HalloweenService", function()
			require(script.HalloweenService).start()
		end)
		step("PedestrianService", function()
			require(script.PedestrianService).start()
		end)
		-- Lake fishers for quiet servers; their route search waits until the harbour is open.
		step("NpcFisherService", function()
			require(script.NpcFisherService).start()
		end)
		step("OfficeComputerService", function()
			require(script.OfficeComputerService).start()
		end)
		step("StockMarketService", function()
			require(script.StockMarketService).start()
		end)
		-- Game-wide elections, the governing party's policy and the parliament's division bell.
		step("ElectionService", function()
			require(script.ElectionService).start()
		end)
		-- HARBOUR DIRECT, the office PC web shop and delivery vans.
		step("WebShopService", function()
			require(script.WebShopService).start()
		end)
		-- Micro Harbour, the industrial district's computer megastore (it paves its own campus).
		step("TechStoreService", function()
			require(script.TechStoreService).start(root)
		end)

		step("LeaderboardService", function()
			require(script.LeaderboardService).start(root)
		end)
		step("CompanyLeaderboardService", function()
			require(script.CompanyLeaderboardService).start(root)
		end)
		step("BaseService", BaseService.start)
		step("OxygenService", function()
			require(script.OxygenService).start()
		end)
		step("DashboardService", function()
			local dashboard = require(script.DashboardService)
			dashboard.setLeaderboardSource(require(script.LeaderboardService).snapshot)
			dashboard.start()
		end)
		stage("Your harbour is ready", 1)
		ReplicatedStorage:SetAttribute("FishingWatersStartupSeconds", os.clock() - started)
		ReplicatedStorage:SetAttribute("FishingWatersWorldReady", true)
		print(
			string.format(
				"[Startup] Harbour playable in %.1fs; distant scenery may continue loading",
				os.clock() - started
			)
		)
	end

	local root = workspace:FindFirstChild("Map")
	if root then
		-- A baked map needs only gameplay repairs before spawning. Cosmetic
		-- migrations and distant LOD/seabed work can run after the harbour opens.
		stage("Preparing your dock", 0.35)
		step("Plaza paving", function()
			Harbour.ensurePlazaPaving(root)
		end)
		step("Boating", function()
			Harbour.ensureBoating(root)
		end)
		step("Fishing", function()
			Harbour.ensureFishing(root)
		end)
		step("Bases", function()
			Harbour.ensureBases(root)
		end)
		step("Metro", function()
			Harbour.ensureMetro(root)
		end)
		step("Company islands", function()
			Map.ensureCompanyIslands(root)
		end)
		openHarbour(root :: Folder)
		-- Players are in by now; cosmetic repairs follow.
		step("City", function()
			Map.ensureCity(root)
		end)
		step("Island cities", function()
			Map.ensureSmallCities(root)
		end)
		step("Pirate Cove", function()
			Map.ensurePirateCove(root)
		end)
		step("Seabed details", Map.ensureSeabedDetails)
		step("Boats", function()
			require(script.Map.Mediterranean).ensureBoats(root)
		end)
		step("Surf", function()
			Harbour.ensureSurf(root, require(ReplicatedStorage.Shared.Biomes).Normal.center)
		end)
		step("Lod", Map.ensureLod)
		step("Sign text", Map.ensureSignText)
		task.wait()
	else
		-- The callback runs once the home island, collision, shops and bases
		-- exist, before generating the surrounding islands and distant biomes.
		Map.build(openHarbour, stage, step)
	end
	task.wait()
	Map.animate()
	ReplicatedStorage:SetAttribute("FishingWatersGenerationComplete", true)
end, debug.traceback)

if not ok then
	-- A timeout is raised inside the xpcall, but this thread's budget is still spent: without a
	-- fresh resume the warn below times out too and the real traceback is lost (it reported only
	-- "Line 152").
	task.wait()
	if ReplicatedStorage:GetAttribute("FishingWatersWorldReady") then
		ReplicatedStorage:SetAttribute("FishingWatersGenerationError", true)
	else
		ReplicatedStorage:SetAttribute("FishingWatersStartupError", true)
		stage("The harbour could not start", 0)
	end
	warn(`[Startup] Failed during step "{currentStep}": {failure}`)
end
]====], 'src/server/init.server.luau'))
assert(loadstring([====[-- Company branches. A save starts as one type of company (chosen when it is
-- created) and can buy the other branch later on the office PC's BRANCHES app.
-- Profiles saved before branches existed have no Branches field: they are
-- fishing companies, so every existing player stays on the fishing branch.
local Branches = {}

Branches.ORDER = { "Fishing" }
Branches.DEFAULT = "Fishing"

Branches.Info = {
	Fishing = {
		Name = "Fishing",
		Title = "Fishing branch",
		-- Paid by a café company that wants to fish as well.
		Price = 5000,
		Blurb = "A dock and fish shop at Gullhaven harbour. Catch fish and sell them.",
	},
}

function Branches.valid(id: any): boolean
	return type(id) == "string" and Branches.Info[id] ~= nil
end

-- Validates a saved Branches table. nil means a legacy fishing company.
function Branches.normalize(raw: any): { [string]: boolean }
	if raw == nil then
		return { Fishing = true }
	end
	assert(type(raw) == "table", "Invalid company branches")
	local result, any = {}, false
	for id, owned in raw do
		assert(type(id) == "string" and type(owned) == "boolean", "Invalid company branch")
		-- Branches removed from the game are dropped rather than failing the save.
		if owned and Branches.Info[id] then
			result[id] = true
			any = true
		end
	end
	if not any then
		result.Fishing = true
	end
	return result
end

function Branches.starting(kind: any): { [string]: boolean }
	assert(kind == nil or Branches.valid(kind), "Choose a fishing company.")
	return { [kind or Branches.DEFAULT] = true }
end

function Branches.has(profile: any, id: string): boolean
	local raw = if type(profile) == "table" then profile.Branches else nil
	local ok, branches = pcall(Branches.normalize, raw)
	return ok and branches[id] == true
end

-- "Fishing", "Café" or "Fishing + Café", in ORDER.
function Branches.label(raw: any): string
	local ok, branches = pcall(Branches.normalize, raw)
	if not ok then
		branches = { Fishing = true }
	end
	local names = {}
	for _, id in Branches.ORDER do
		if branches[id] then
			table.insert(names, Branches.Info[id].Name)
		end
	end
	return table.concat(names, " + ")
end

-- Pure purchase rule, run inside the profile transaction.
function Branches.buy(profile: any, id: any)
	assert(Branches.valid(id), "Unknown branch.")
	local branches = Branches.normalize(profile.Branches)
	assert(not branches[id], "Your company already has the " .. Branches.Info[id].Title .. ".")
	local price = Branches.Info[id].Price
	assert(profile.Cash >= price, "You need " .. tostring(price) .. " cash for the " .. Branches.Info[id].Title .. ".")
	profile.Cash -= price
	branches[id] = true
	profile.Branches = branches
	return profile
end

return Branches
]====], 'src/shared/Branches.luau'))
local branches = (assert(loadstring([====[-- Company branches. A save starts as one type of company (chosen when it is
-- created) and can buy the other branch later on the office PC's BRANCHES app.
-- Profiles saved before branches existed have no Branches field: they are
-- fishing companies, so every existing player stays on the fishing branch.
local Branches = {}

Branches.ORDER = { "Fishing" }
Branches.DEFAULT = "Fishing"

Branches.Info = {
	Fishing = {
		Name = "Fishing",
		Title = "Fishing branch",
		-- Paid by a café company that wants to fish as well.
		Price = 5000,
		Blurb = "A dock and fish shop at Gullhaven harbour. Catch fish and sell them.",
	},
}

function Branches.valid(id: any): boolean
	return type(id) == "string" and Branches.Info[id] ~= nil
end

-- Validates a saved Branches table. nil means a legacy fishing company.
function Branches.normalize(raw: any): { [string]: boolean }
	if raw == nil then
		return { Fishing = true }
	end
	assert(type(raw) == "table", "Invalid company branches")
	local result, any = {}, false
	for id, owned in raw do
		assert(type(id) == "string" and type(owned) == "boolean", "Invalid company branch")
		-- Branches removed from the game are dropped rather than failing the save.
		if owned and Branches.Info[id] then
			result[id] = true
			any = true
		end
	end
	if not any then
		result.Fishing = true
	end
	return result
end

function Branches.starting(kind: any): { [string]: boolean }
	assert(kind == nil or Branches.valid(kind), "Choose a fishing company.")
	return { [kind or Branches.DEFAULT] = true }
end

function Branches.has(profile: any, id: string): boolean
	local raw = if type(profile) == "table" then profile.Branches else nil
	local ok, branches = pcall(Branches.normalize, raw)
	return ok and branches[id] == true
end

-- "Fishing", "Café" or "Fishing + Café", in ORDER.
function Branches.label(raw: any): string
	local ok, branches = pcall(Branches.normalize, raw)
	if not ok then
		branches = { Fishing = true }
	end
	local names = {}
	for _, id in Branches.ORDER do
		if branches[id] then
			table.insert(names, Branches.Info[id].Name)
		end
	end
	return table.concat(names, " + ")
end

-- Pure purchase rule, run inside the profile transaction.
function Branches.buy(profile: any, id: any)
	assert(Branches.valid(id), "Unknown branch.")
	local branches = Branches.normalize(profile.Branches)
	assert(not branches[id], "Your company already has the " .. Branches.Info[id].Title .. ".")
	local price = Branches.Info[id].Price
	assert(profile.Cash >= price, "You need " .. tostring(price) .. " cash for the " .. Branches.Info[id].Title .. ".")
	profile.Cash -= price
	branches[id] = true
	profile.Branches = branches
	return profile
end

return Branches
]====])))()
assert(branches.normalize({Cafe=true}).Fishing == true)
assert(branches.label({Cafe=true}) == "Fishing")
assert(not branches.valid("Cafe"))
print("Syntax and legacy cafe-only migration checks passed")