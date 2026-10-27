-- The drydock refit menu. Slowing your own boat over the underwater lift behind
-- the boat shop (or using its prompt) asks the server to lift the hull into the
-- dry basin; the menu opens once it is up, and closing it sets the boat back
-- afloat. Boating brakes the hull meanwhile. The server reserves motors and
-- rudders for the cargo hold, where the player picks their spot, and saves paint;
-- this module only presents what it reports.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Aboard = require(Shared:WaitForChild("Aboard"))
local BoatCatalog = require(Shared:WaitForChild("BoatCatalog"))
local BoatUpgrades = require(Shared:WaitForChild("BoatUpgrades"))
local Cargo = require(Shared:WaitForChild("Cargo"))
local Catalog = require(Shared:WaitForChild("AnglerCatalog"))

local BoatRefit = {}
local started = false

local WIDTH, HEIGHT = 960, 404
local CARD_WIDTH, CARD_HEIGHT, CARD_GAP = 220, 254, 14
local SWATCH, SWATCH_GAP = 42, 8
local GOLD = Color3.fromRGB(244, 196, 76)
local GOOD = Color3.fromRGB(111, 202, 125)
local BAD = Color3.fromRGB(238, 107, 111)
local ACCENTS = {
	Motor = Color3.fromRGB(238, 140, 66),
	Rudder = Color3.fromRGB(86, 196, 232),
	Paint = Color3.fromRGB(196, 120, 240),
	Net = Color3.fromRGB(111, 202, 125),
}
-- Below this speed (studs/s) a boat over the lift counts as pulling in to refit.
local PULL_IN_SPEED = 8
-- Menus that own the screen; the refit menu never opens over them.
local MENUS = { "PlayerMenuOpen", "DrydockScreenOpen", "RodWorkshopOpen" }
local HINT = "Motors and rudders use hold tiles — you pick their spot when fitting. Paint is free. The trawler's net is a permanent fitting."

function BoatRefit.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local remote = ReplicatedStorage:WaitForChild("BoatRefit") :: RemoteFunction
	local cream, muted = Theme.Colors.Text, Theme.Colors.Muted

	local gui = Instance.new("ScreenGui")
	gui.Name = "BoatRefit"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 23
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	local function label(parent: Instance, text: string, position: UDim2, size: UDim2, textSize: number, color: Color3)
		local item = Instance.new("TextLabel")
		item.BackgroundTransparency = 1
		item.Position, item.Size = position, size
		item.Text, item.TextSize = text, textSize
		item.TextWrapped = true
		item.TextXAlignment = Enum.TextXAlignment.Left
		Theme.text(item, color)
		item.Parent = parent
		return item
	end
	local function frame(parent: Instance, name: string, position: UDim2, size: UDim2, color: Color3): Frame
		local item = Instance.new("Frame")
		item.Name = name
		item.Position, item.Size = position, size
		item.BackgroundColor3 = color
		item.BorderSizePixel = 0
		item.Parent = parent
		return item
	end
	local function button(parent: Instance, name: string, position: UDim2, size: UDim2, textSize: number): TextButton
		local item = Instance.new("TextButton")
		item.Name = name
		item.Position, item.Size = position, size
		item.TextSize = textSize
		item.TextWrapped = true
		item.Parent = parent
		Theme.button(item, "Disabled")
		return item
	end

	-- An invisible click-catcher: the harbour stays untinted behind the menu, and
	-- a click outside still puts the boat back in the water.
	local overlay = Instance.new("TextButton")
	overlay.Name = "RefitOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 1
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Visible = false
	overlay.Parent = gui

	local window = Instance.new("Frame")
	window.Name = "BoatRefit"
	window.Active = true
	window.AnchorPoint = Vector2.new(0.5, 1)
	window.Position = UDim2.new(0.5, 0, 1, -16)
	window.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	window.Parent = overlay
	Theme.window(window)
	local scale = Instance.new("UIScale")
	scale.Parent = window

	local header = frame(window, "Header", UDim2.fromOffset(14, 14), UDim2.new(1, -28, 0, 74), Color3.new(1, 1, 1))
	Theme.corner(header, 8)
	local wash = Instance.new("UIGradient")
	wash.Rotation = 90
	wash.Color = ColorSequence.new(Color3.fromRGB(47, 74, 88), Color3.fromRGB(24, 38, 48))
	wash.Parent = header
	label(header, "REFIT DOCK", UDim2.fromOffset(18, 10), UDim2.fromOffset(300, 18), 13, GOLD)
	local boatName = label(header, "", UDim2.fromOffset(18, 30), UDim2.new(1, -280, 0, 32), 24, cream)
	local cargoPanel = frame(header, "Cargo", UDim2.new(1, -244, 0, 14), UDim2.fromOffset(184, 46), Theme.Colors.Inset)
	Theme.panel(cargoPanel, true, 23)
	label(cargoPanel, "FREE CARGO TILES", UDim2.fromOffset(16, 4), UDim2.new(1, -24, 0, 14), 11, muted)
	local cargoValue = label(cargoPanel, "—", UDim2.fromOffset(16, 18), UDim2.new(1, -24, 0, 24), 20, GOOD)
	cargoValue.RichText = true

	local close = Instance.new("TextButton")
	close.Name = "CloseRefit"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -8, 0, 8)
	close.Size = UDim2.fromOffset(34, 34)
	close.Text = "×"
	close.TextSize = 24
	close.ZIndex = 4
	close.Parent = header
	Theme.button(close, "Danger")

	local row = frame(window, "Refits", UDim2.fromOffset(0, 100), UDim2.new(1, 0, 0, CARD_HEIGHT), Color3.new())
	row.BackgroundTransparency = 1
	local left = (WIDTH - CARD_WIDTH * 4 - CARD_GAP * 3) / 2
	local function card(index: number, kind: string, title: string)
		local item = frame(
			row,
			kind,
			UDim2.fromOffset(left + (index - 1) * (CARD_WIDTH + CARD_GAP), 0),
			UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
			Theme.Colors.Panel
		)
		Theme.panel(item, false, 8)
		local stripe = frame(item, "Accent", UDim2.fromScale(0, 0), UDim2.new(1, 0, 0, 6), ACCENTS[kind])
		Theme.corner(stripe, 8)
		local glow = frame(item, "Glow", UDim2.fromOffset(0, 6), UDim2.new(1, 0, 0, 60), ACCENTS[kind])
		glow.BackgroundTransparency = 0.8
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new(0, 1)
		fade.Parent = glow
		label(item, title, UDim2.fromOffset(14, 16), UDim2.new(1, -28, 0, 20), 15, ACCENTS[kind])
		return item, glow
	end

	-- Motors and rudders: count and pips, the stat now and next, fit and remove.
	local views = {}
	for index, kind in BoatUpgrades.Order do
		local upgrade = BoatUpgrades.Kinds[kind]
		local item, glow = card(index, kind, string.upper(upgrade.Plural))
		local count = label(item, "", UDim2.fromOffset(14, 38), UDim2.new(1, -28, 0, 28), 22, cream)
		count.RichText = true
		local description =
			label(item, upgrade.Description, UDim2.fromOffset(14, 66), UDim2.new(1, -28, 0, 32), 12, muted)
		description.Font = Enum.Font.GothamMedium
		description.TextYAlignment = Enum.TextYAlignment.Top
		local pips = {}
		local pipWidth = (CARD_WIDTH - 28 - (upgrade.Max - 1) * 4) / upgrade.Max
		for pip = 1, upgrade.Max do
			local cell = frame(
				item,
				"Pip" .. pip,
				UDim2.fromOffset(14 + (pip - 1) * (pipWidth + 4), 104),
				UDim2.fromOffset(pipWidth, 10),
				Theme.Colors.Inset
			)
			Theme.corner(cell, 3)
			pips[pip] = cell
		end
		local stat = label(item, "", UDim2.fromOffset(14, 122), UDim2.new(1, -28, 0, 18), 13, cream)
		local cost = label(item, "", UDim2.fromOffset(14, 142), UDim2.new(1, -28, 0, 18), 12, muted)
		cost.Font = Enum.Font.GothamMedium
		local fit = button(item, "Fit" .. kind, UDim2.fromOffset(12, 168), UDim2.new(1, -24, 0, 38), 15)
		local remove = button(item, "Remove" .. kind, UDim2.fromOffset(12, 212), UDim2.new(1, -24, 0, 30), 13)
		views[kind] = { glow = glow, count = count, pips = pips, stat = stat, cost = cost, fit = fit, remove = remove }
	end

	-- Paint: the boat's current finish and one swatch per preset.
	local paintCard, paintGlow = card(3, "Paint", "PAINT")
	local paintName = label(paintCard, "", UDim2.fromOffset(14, 38), UDim2.new(1, -28, 0, 28), 20, cream)
	local swatches = {}
	for index, paint in BoatUpgrades.Paints do
		local column, line = (index - 1) % 4, (index - 1) // 4
		local swatch = Instance.new("TextButton")
		swatch.Name = "Paint" .. paint.Id
		swatch.Position = UDim2.fromOffset(14 + column * (SWATCH + SWATCH_GAP), 72 + line * (SWATCH + SWATCH_GAP))
		swatch.Size = UDim2.fromOffset(SWATCH, SWATCH)
		swatch.AutoButtonColor = true
		swatch.BorderSizePixel = 0
		swatch.Text = ""
		swatch.BackgroundColor3 = if paint.RGB
			then Color3.fromRGB(paint.RGB[1], paint.RGB[2], paint.RGB[3])
			else Theme.Colors.Inset
		swatch.Parent = paintCard
		Theme.corner(swatch, 8)
		if not paint.RGB then
			local stock = label(swatch, "STOCK", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 10, muted)
			stock.TextXAlignment = Enum.TextXAlignment.Center
		end
		local ring = Instance.new("UIStroke")
		ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ring.Parent = swatch
		swatches[paint.Id] = { button = swatch, ring = ring, paint = paint }
	end
	local paintHint =
		label(paintCard, "Free · tap a colour", UDim2.fromOffset(14, 224), UDim2.new(1, -28, 0, 18), 12, muted)
	paintHint.Font = Enum.Font.GothamMedium

	-- Fisherman's net: a permanent trawler fitting that never uses hold tiles.
	local netCard, netGlow = card(4, "Net", "FISHERMAN'S NET")
	local netState = label(netCard, "", UDim2.fromOffset(14, 38), UDim2.new(1, -28, 0, 28), 20, cream)
	local netDescription =
		label(netCard, BoatUpgrades.Net.Description, UDim2.fromOffset(14, 66), UDim2.new(1, -28, 0, 38), 12, muted)
	netDescription.Font = Enum.Font.GothamMedium
	netDescription.TextYAlignment = Enum.TextYAlignment.Top
	local netDetail = label(netCard, "", UDim2.fromOffset(14, 106), UDim2.new(1, -28, 0, 30), 12, muted)
	netDetail.Font = Enum.Font.GothamMedium
	local netCost = label(netCard, "", UDim2.fromOffset(14, 138), UDim2.new(1, -28, 0, 28), 12, muted)
	netCost.Font = Enum.Font.GothamMedium
	local netBuy = button(netCard, "BuyNet", UDim2.fromOffset(12, 174), UDim2.new(1, -24, 0, 38), 15)
	local netHint = label(netCard, "Deploy or stow at the helm\nwith the net button or N.", UDim2.fromOffset(14, 216), UDim2.new(1, -28, 0, 30), 12, muted)
	netHint.TextXAlignment = Enum.TextXAlignment.Center
	netHint.Font = Enum.Font.GothamMedium

	local status = label(window, HINT, UDim2.fromOffset(24, HEIGHT - 44), UDim2.new(1, -48, 0, 32), 13, muted)
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.Font = Enum.Font.GothamMedium

	local snapshot: any = nil
	local pending = false
	local lastRequest = -math.huge
	local hovered: string? = nil
	-- True while a fitted part waits for the player to choose its hold tiles;
	-- the refit window hides so the cargo grid has the screen to itself.
	local placing = false
	local restoreToken = 0

	local function setStatus(message: string, color: Color3)
		status.Text, status.TextColor3 = message, color
	end

	local function render()
		local layout = snapshot and snapshot.BoatId and BoatCatalog[snapshot.BoatId]
		local docked = layout ~= nil and snapshot.Lifted == true
		local items = if layout then snapshot.Items or {} else {}
		boatName.Text = if layout then layout.Name else "Sail a boat over the lift"
		local free = if layout then BoatUpgrades.freeTiles(layout, items, Catalog.Fish) else 0
		cargoValue.Text = if layout
			then string.format('%d <font size="14" color="#bdbdbd">/ %d</font>', free, Cargo.capacity(layout.Hold))
			else "—"
		local motors = if layout then BoatUpgrades.count(items, layout, "Motor") else 0
		local rudders = if layout then BoatUpgrades.count(items, layout, "Rudder") else 0
		for _, kind in BoatUpgrades.Order do
			local upgrade, view = BoatUpgrades.Kinds[kind], views[kind]
			local count = if kind == "Motor" then motors else rudders
			local maxed = count >= upgrade.Max
			view.count.Text = string.format('%d <font size="15" color="#9a9a9a">/ %d fitted</font>', count, upgrade.Max)
			for pip, cell in view.pips do
				cell.BackgroundColor3 = if pip <= count then ACCENTS[kind] else Theme.Colors.Inset
			end
			local tiles = if layout then BoatUpgrades.tiles(layout, kind) else 0
			if layout then
				local now = BoatUpgrades.tuned(layout, motors, rudders)
				local nextSpec = BoatUpgrades.tuned(
					layout,
					motors + (if kind == "Motor" then 1 else 0),
					rudders + (if kind == "Rudder" then 1 else 0)
				)
				if kind == "Motor" then
					view.stat.Text = if maxed
						then string.format("Top speed %.0f studs/s", now.ForwardSpeed)
						else string.format(
							"Top speed %.0f → %.0f studs/s",
							now.ForwardSpeed,
							nextSpec.ForwardSpeed
						)
				else
					view.stat.Text = if maxed
						then string.format("Turning %.0f°/s", math.deg(now.TurnRate))
						else string.format(
							"Turning %.0f → %.0f°/s",
							math.deg(now.TurnRate),
							math.deg(nextSpec.TurnRate)
						)
				end
				view.cost.Text = string.format("Uses %d cargo tiles each", tiles)
			else
				view.stat.Text, view.cost.Text = "", ""
			end
			local canFit = docked and not pending and not maxed and free >= tiles
			view.fit.Text = if not layout
				then "NO BOAT"
				elseif maxed then "MAXED OUT"
				elseif free < tiles then string.format("NEEDS %d FREE TILES", tiles)
				else string.format("FIT %s · PICK SPOT", if kind == "Motor" then "MOTOR" else "RUDDER")
			Theme.button(view.fit, if canFit then "Selected" else "Disabled")
			view.fit.Active, view.fit.Selectable, view.fit.AutoButtonColor = canFit, canFit, canFit
			local canRemove = docked and not pending and count > 0
			view.remove.Text = if count > 0 then "TAKE ONE OUT" else "NONE FITTED"
			Theme.button(view.remove, if canRemove then "Normal" else "Disabled")
			view.remove.Active, view.remove.Selectable, view.remove.AutoButtonColor = canRemove, canRemove, canRemove
		end
		local current = if layout then snapshot.Paint or "Factory" else nil
		local shown = BoatUpgrades.paint(hovered or current)
		paintName.Text = if shown then shown.Name else "—"
		paintName.TextColor3 = if hovered and hovered ~= current then muted else cream
		for id, swatch in swatches do
			local selected = id == current
			swatch.ring.Color = if selected then cream else Theme.Colors.Border
			swatch.ring.Thickness = if selected then 3 else 1
			swatch.ring.Transparency = if selected then 0 else 0.35
			swatch.button.Active = docked and not pending
		end
		local net = BoatUpgrades.Net
		local netOwned = snapshot ~= nil and snapshot.NetOwned == true
		local trawler = layout ~= nil and snapshot.BoatId == net.BoatId
		local cash = if snapshot and type(snapshot.Cash) == "number" then snapshot.Cash else 0
		netState.Text = if not layout
			then "—"
			elseif netOwned then "FITTED"
			elseif not trawler then "TRAWLER ONLY"
			else "NOT FITTED"
		netState.TextColor3 = if netOwned then GOOD elseif not layout or not trawler then muted else cream
		netDetail.Text = if not layout
			then ""
			elseif netOwned then "Deploy while underway. Catches common fish, and the odd uncommon."
			elseif not trawler then "Only the teal fishing trawler has the stern gear for this net."
			else "A permanent fitting — it never uses cargo tiles."
		netCost.Text = if not layout
			then ""
			elseif netOwned then "Already fitted to this boat."
			else string.format("$%d one-time · $%d aboard", net.Price, cash)
		local canBuyNet = docked and not pending and trawler and not netOwned and cash >= net.Price
		netBuy.Text = if not layout
			then "NO BOAT"
			elseif not trawler then "TEAL TRAWLER ONLY"
			elseif netOwned then "FITTED"
			elseif cash < net.Price then string.format("NEED $%d MORE", net.Price - cash)
			else string.format("FIT NET · $%d", net.Price)
		Theme.button(netBuy, if canBuyNet then "Selected" else "Disabled")
		netBuy.Active, netBuy.Selectable, netBuy.AutoButtonColor = canBuyNet, canBuyNet, canBuyNet
	end

	local function celebrate(glow: Frame)
		glow.BackgroundTransparency = 0.25
		TweenService:Create(glow, TweenInfo.new(0.8), { BackgroundTransparency = 0.8 }):Play()
	end

	local fetchId = 0
	local function fetch()
		fetchId += 1
		local id = fetchId
		task.spawn(function()
			local ok, result = pcall(remote.InvokeServer, remote, "Get")
			if id == fetchId and ok and type(result) == "table" and type(result.State) == "table" then
				snapshot = result.State
				render()
			end
		end)
	end

	local function send(action: string, key: string, glow: Frame)
		if pending or os.clock() - lastRequest < 0.35 then
			return
		end
		lastRequest, pending = os.clock(), true
		fetchId += 1
		setStatus("The dock crew is working on your boat…", muted)
		render()
		task.spawn(function()
			local ok, result = pcall(remote.InvokeServer, remote, action, key)
			pending = false
			if ok and type(result) == "table" then
				if type(result.State) == "table" then
					snapshot = result.State
				end
				setStatus(tostring(result.Message), if result.Ok then GOOD else BAD)
				if result.Ok then
					if action == "Install" then
						-- The cargo grid takes over so the player can pick the spot.
						placing = true
						overlay.Visible = false
					else
						celebrate(glow)
					end
				end
			else
				setStatus("The drydock didn't answer. Please try again.", BAD)
			end
			render()
		end)
	end

	-- Shown over the boat while the lift moves, and for lift refusals.
	local banner = label(gui, "", UDim2.new(0.5, -220, 0, 96), UDim2.fromOffset(440, 44), 18, cream)
	banner.Name = "LiftNotice"
	banner.TextXAlignment = Enum.TextXAlignment.Center
	banner.BackgroundColor3 = Theme.Colors.Window
	banner.BackgroundTransparency = 0.1
	banner.Visible = false
	Theme.corner(banner, 10)
	local bannerId = 0
	local function notice(message: string?, seconds: number?)
		bannerId += 1
		local id = bannerId
		banner.Text, banner.Visible = message or "", message ~= nil
		if message and seconds then
			task.delay(seconds, function()
				if bannerId == id then
					banner.Visible = false
				end
			end)
		end
	end

	-- BoatRefitOpen holds the helm (see Boating) from the lift request until the
	-- menu is closed again.
	local lifting = false
	local function blocked(): boolean
		for _, name in MENUS do
			if player:GetAttribute(name) then
				return true
			end
		end
		return false
	end
	local function lift()
		if lifting or overlay.Visible or blocked() then
			return
		end
		lifting = true
		player:SetAttribute("BoatRefitOpen", true)
		notice("Lifting your boat out of the water…")
		task.spawn(function()
			local ok, result = pcall(remote.InvokeServer, remote, "Lift")
			lifting = false
			if not ok or type(result) ~= "table" or not result.Ok then
				player:SetAttribute("BoatRefitOpen", false)
				notice(
					if ok and type(result) == "table" then tostring(result.Message) else "The drydock didn't answer.",
					4
				)
				return
			elseif blocked() or not player:GetAttribute("BoatRefitOpen") then
				-- Another menu took the screen, or the boat sailed off, while it rose.
				player:SetAttribute("BoatRefitOpen", false)
				task.spawn(pcall, remote.InvokeServer, remote, "Lower")
				notice(nil)
				return
			end
			notice(nil)
			snapshot = if type(result.State) == "table" then result.State else snapshot
			hovered = nil
			setStatus(HINT, muted)
			overlay.Visible = true
			render()
			window.Position = UDim2.new(0.5, 0, 1, 24)
			TweenService
				:Create(window, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 1, -16) })
				:Play()
		end)
	end
	local function closeRefit()
		-- Drop any scheduled restore; the menu is going away for good.
		restoreToken += 1
		placing = false
		if overlay.Visible or player:GetAttribute("BoatRefitOpen") then
			overlay.Visible = false
			player:SetAttribute("BoatRefitOpen", false)
			notice("Setting your boat back in the water…", 4)
			task.spawn(pcall, remote.InvokeServer, remote, "Lower")
		end
	end
	player:SetAttribute("BoatRefitOpen", false)

	for _, kind in BoatUpgrades.Order do
		local view = views[kind]
		view.fit.Activated:Connect(function()
			if view.fit.Active then
				send("Install", kind, view.glow)
			end
		end)
		view.remove.Activated:Connect(function()
			if view.remove.Active then
				send("Remove", kind, view.glow)
			end
		end)
	end
	netBuy.Activated:Connect(function()
		if netBuy.Active then
			send("BuyNet", "", netGlow)
		end
	end)
	for id, swatch in swatches do
		swatch.button.Activated:Connect(function()
			if swatch.button.Active and id ~= (snapshot and snapshot.Paint) then
				send("Paint", id, paintGlow)
			end
		end)
		swatch.button.MouseEnter:Connect(function()
			hovered = id
			render()
		end)
		swatch.button.MouseLeave:Connect(function()
			if hovered == id then
				hovered = nil
				render()
			end
		end)
	end
	close.Activated:Connect(closeRefit)
	overlay.Activated:Connect(closeRefit)

	-- Fitting a part hides the window while the cargo grid takes the spot, then
	-- brings the window back once the part is placed or put back.
	player:GetAttributeChangedSignal("RefitPending"):Connect(function()
		if player:GetAttribute("RefitPending") ~= nil then
			restoreToken += 1
			placing = true
			overlay.Visible = false
			return
		end
		if not placing then
			return
		end
		restoreToken += 1
		local token = restoreToken
		task.delay(0.3, function()
			if token ~= restoreToken or not placing then
				return
			end
			placing = false
			if
				player:GetAttribute("RefitPending") ~= nil
				or not player:GetAttribute("BoatRefitOpen")
				or overlay.Visible
			then
				return
			end
			overlay.Visible = true
			setStatus(HINT, muted)
			render()
			window.Position = UDim2.new(0.5, 0, 1, 24)
			TweenService
				:Create(window, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 1, -16) })
				:Play()
			fetch()
		end)
	end)
	UserInputService.InputBegan:Connect(function(input)
		-- While a part waits for its tiles, Esc belongs to the cargo grid and
		-- only cancels the placement.
		if player:GetAttribute("RefitPending") ~= nil then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			closeRefit()
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "RefitDockPrompt" then
			lift()
		end
	end)
	-- Any saved change (a fish stowed, a part moved) can change the free tiles.
	player:GetAttributeChangedSignal("AnglerRevision"):Connect(function()
		if overlay.Visible and not pending then
			fetch()
		end
	end)
	for _, name in MENUS do
		player:GetAttributeChangedSignal(name):Connect(function()
			if player:GetAttribute(name) then
				closeRefit()
			end
		end)
	end
	player.CharacterRemoving:Connect(closeRefit)

	local function ownBoat(): Model?
		local id = player:GetAttribute("ActiveBoatId")
		local boats = workspace:FindFirstChild("PlayerBoats")
		local boat = if type(id) == "string" and boats then boats:FindFirstChild(id .. "_" .. player.UserId) else nil
		return if boat and boat:IsA("Model") then boat else nil
	end
	local function slipAround(boat: Model): Instance?
		local root = boat.PrimaryPart
		if root then
			for _, dock in CollectionService:GetTagged("RefitDock") do
				if BoatUpgrades.inSlip(dock, root.Position) then
					return dock
				end
			end
		end
		return nil
	end

	-- Fit the screen, follow the boat over and off the lift and keep the prompt for
	-- the one drydock it floats over.
	local elapsed = 0
	local pulledIn = false
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.2 then
			return
		end
		elapsed = 0
		local camera = workspace.CurrentCamera
		if camera then
			local size = camera.ViewportSize
			scale.Scale = math.max(0.4, math.min(1, (size.X - 24) / WIDTH, size.Y * 0.62 / HEIGHT))
		end
		local character = player.Character
		local boat = ownBoat()
		local dock = if boat and Aboard(character, boat) then slipAround(boat) else nil
		-- A lift busy launching a purchase or carrying another boat stays down.
		local free = dock ~= nil
			and dock:GetAttribute("LaunchingUserId") == nil
			and dock:GetAttribute("LiftingUserId") == nil
		if dock and free and not pulledIn and boat then
			local root = boat.PrimaryPart :: BasePart
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local seat = humanoid and humanoid.SeatPart
			if
				seat
				and seat:IsA("VehicleSeat")
				and seat:IsDescendantOf(boat)
				and root.AssemblyLinearVelocity.Magnitude < PULL_IN_SPEED
			then
				pulledIn = true
				lift()
			end
		elseif not dock then
			pulledIn = false
			if not lifting then
				closeRefit()
			end
		end
		local idle = not overlay.Visible and not lifting and not player:GetAttribute("BoatRefitOpen")
		for _, each in CollectionService:GetTagged("RefitDock") do
			local prompt = each:FindFirstChild("RefitDockPrompt", true)
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.Enabled = each == dock and free and idle
			end
		end
	end)
	render()
end

return BoatRefit
