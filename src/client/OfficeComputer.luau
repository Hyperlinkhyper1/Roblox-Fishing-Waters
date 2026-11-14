-- The office PC in your own base house (Map/OfficeDesk). A "Use computer" prompt on the chair sits
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
local BranchApp = require(script.Parent.BranchApp)
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
					"PARTS, MONITORS AND LICENSES: " .. TechCatalog.STORE_NAME .. ", BY THE CAFE QUARTER.",
					px(24, 446),
					px(720, 24),
					{ Size = 15, Color = C.Mid }
				)
				return { destroy = function() end }
			end,
		},
		Branches = {
			Name = "COMPANY BRANCHES",
			Title = BranchApp.TITLE .. "  -  " .. BranchApp.SUBTITLE,
			Connecting = "CONTACTING THE BRANCH OFFICE...",
			Ready = BranchApp.READY,
			mount = BranchApp.mount,
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
					"%s NEEDS A %s (%s).\nBUY ONE AT THE SOFTWARE & LICENSES DESK IN %s,\nTHE COMPUTER STORE BY THE CAFE QUARTER IN THE CITY.",
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

	-- BRANCHES: a little shopfront with a striped awning.
	local shop = desktopIcon("BranchesIcon", "BRANCHES", 180, APPS.Branches)
	for index = 0, 5 do
		RetroUI.frame(shop, "Stripe", px(8 + index * 9.3, 10), px(9.3, 10), {
			BackgroundTransparency = 0,
			BackgroundColor3 = if index % 2 == 0 then C.Hot else C.Dim,
		})
	end
	RetroUI.frame(shop, "Window", px(10, 26), px(22, 18), { BackgroundTransparency = 0, BackgroundColor3 = C.Mid })
	RetroUI.frame(shop, "Door", px(40, 26), px(14, 28), { BackgroundTransparency = 0, BackgroundColor3 = C.Bright })

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
