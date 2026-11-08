-- The office PC in your own base house (Map/OfficeDesk). A "Use computer" prompt on the chair sits
-- you down (OfficeComputerService), the camera settles on the monitor, and the tube shows
-- HARBOUR-OS: a green-phosphor home screen with a pixel pointer that follows your mouse. The camera
-- holds still, square on to the glass, so the screen is a ScreenGui laid exactly over the glass's
-- projection each frame (Roblox's SurfaceGui mouse input never reached it, 2026-11-07).
-- Apps open in a window; the first is Harbour Exchange (StockApp). Jump or press EXIT to stand up.
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
local Calendar = require(ReplicatedStorage.Shared.Calendar)
local Stocks = require(ReplicatedStorage.Shared.Stocks)

local OfficeComputer = {}

local BASE_TAG = "PlayerBase"
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
		if CollectionService:HasTag(node, BASE_TAG) then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function refreshPrompts()
	for prompt, base in prompts do
		prompt.Enabled = session == nil and base:GetAttribute("OwnerUserId") == player.UserId
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
	local readyText = "READY. CLICK STOCKS TO OPEN THE EXCHANGE.  JUMP OR EXIT TO STAND UP."

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
	local function openApp(from: GuiObject)
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
		local titleText = RetroUI.text(title, "Title", StockApp.TITLE .. "  -  LIVE MARKET", px(12, 0), px(600, 30), {
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
		setStatus("CONNECTING TO HARBOUR EXCHANGE...")
		task.spawn(function()
			local mounted, app = pcall(StockApp.mount, content, setStatus)
			if not mounted then
				warn("[OfficeComputer] Harbour Exchange failed to start: " .. tostring(app))
				if window == frame then
					RetroUI.text(
						content,
						"Crashed",
						"HARBOUR EXCHANGE HIT AN ERROR.\nCLOSE THE WINDOW AND TRY AGAIN.",
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
			setStatus("PRICES UPDATE EVERY FEW SECONDS. DIVIDENDS PAY EVERY 7 IN-GAME DAYS.")
		end)
	end

	-- Desktop icon: a little framed chart above its name.
	local icon = Instance.new("TextButton")
	icon.Name = "StocksIcon"
	icon.AutoButtonColor = false
	icon.Text = ""
	icon.BackgroundTransparency = 1
	icon.Position = px(40, 36)
	icon.Size = px(120, 118)
	icon.Parent = desktop
	local art = RetroUI.frame(icon, "Art", px(24, 6), px(72, 60), {
		BackgroundTransparency = 0,
		BackgroundColor3 = C.Panel,
	})
	RetroUI.border(art, C.Bright, 2)
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
	local iconLabel = RetroUI.text(icon, "Label", "STOCKS", px(0, 76), px(120, 30), {
		Font = RetroUI.Fonts.Title,
		Size = 14,
		AlignX = Enum.TextXAlignment.Center,
	})
	iconLabel.BackgroundColor3 = C.Bright
	local function paintIcon(hot: boolean)
		iconLabel.BackgroundTransparency = if hot then 0 else 1
		RetroUI.setColor(iconLabel, if hot then C.Screen else C.Bright)
		iconLabel.TextStrokeTransparency = if hot then 1 else 0.88
	end
	RetroUI.hover(icon, paintIcon)
	icon.Activated:Connect(function()
		openApp(art)
	end)

	-- A little welcome note so the desk reads as somebody's office.
	RetroUI.text(
		desktop,
		"Welcome",
		"WELCOME BACK, " .. string.upper(player.DisplayName) .. ".\nTHE MARKET IS OPEN.",
		px(200, 46),
		px(560, 60),
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
local BOOT = {
	"HARBOUR BIOS  V2.1",
	"MEMORY TEST  640K OK",
	"FLOPPY A: ......... READY",
	"FIXED DISK C: ..... 20MB",
	"",
	"LOADING HARBOUR-OS 3.30...",
}

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
		for _, line in BOOT do
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
	prompt.Triggered:Connect(function()
		sitDown(desk)
	end)
	prompt.AncestryChanged:Connect(function()
		if not prompt:IsDescendantOf(workspace) then
			prompts[prompt] = nil
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
	for _, base in CollectionService:GetTagged(BASE_TAG) do
		trackBase(base)
	end
	CollectionService:GetInstanceAddedSignal(BASE_TAG):Connect(trackBase)
end

return OfficeComputer
