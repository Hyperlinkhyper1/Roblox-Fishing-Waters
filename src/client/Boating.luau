-- Drydock shop and owner-only dock prompts. Cash and ownership come from the server.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))
local BoatCatalog = require(ReplicatedStorage.Shared.BoatCatalog)
local Weather = require(ReplicatedStorage.Shared.Weather)
local DrydockCamera = require(script.Parent.DrydockCamera)
local BoatPreview = require(script.Parent.BoatPreview)
local BoatCamera = require(script.Parent.BoatCamera)

local Boating = {}

function Boating.start()
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Boating")
	local request = remotes:WaitForChild("Request") :: RemoteEvent
	local feedback = remotes:WaitForChild("Feedback") :: RemoteEvent
	local netRemote = ReplicatedStorage:WaitForChild("TrawlerNet") :: RemoteEvent
	local boatIds = {}
	for id in BoatCatalog do
		table.insert(boatIds, id)
	end
	table.sort(boatIds, function(a, b)
		return BoatCatalog[a].Price < BoatCatalog[b].Price
	end)
	local selectedBoatId = "Rowboat"
	local selectedDockBoatId = "Rowboat"
	local spec = BoatCatalog.Rowboat
	local previewShop: Model? = nil
	local dockBase: Instance? = nil
	local isLaunching = false
	local cream = Theme.Colors.Text
	local muted = Theme.Colors.Muted
	local gold = Theme.Colors.Blue
	local navy = Theme.Colors.Window
	local gui = Instance.new("ScreenGui")
	gui.Name = "Boating"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	local function corner(parent: GuiObject, radius: number)
		Theme.corner(parent, math.min(radius, 10))
	end
	local function label(
		parent: Instance,
		text: string,
		position: UDim2,
		size: UDim2,
		fontSize: number,
		color: Color3
	): TextLabel
		local item = Instance.new("TextLabel")
		item.BackgroundTransparency = 1
		item.Position, item.Size = position, size
		item.Font = Enum.Font.Gotham
		item.Text, item.TextSize, item.TextColor3 = text, fontSize, color
		item.TextXAlignment = Enum.TextXAlignment.Left
		item.TextWrapped = true
		Theme.text(item, color)
		item.Parent = parent
		return item
	end
	local wallet = Instance.new("Frame")
	wallet.Name = "Wallet"
	wallet.AnchorPoint = Vector2.new(0, 1)
	wallet.Position = UDim2.new(0, 24, 1, -22)
	wallet.Size = UDim2.fromOffset(244, 82)
	wallet.BackgroundTransparency = 1
	wallet.Parent = gui
	local weatherIcon = Instance.new("Frame")
	weatherIcon.Name = "WeatherIcon"
	weatherIcon.Position = UDim2.fromOffset(0, -44)
	weatherIcon.Size = UDim2.fromOffset(38, 36)
	weatherIcon.BackgroundTransparency = 1
	weatherIcon.Visible = false
	weatherIcon.ZIndex = 2
	weatherIcon.Parent = wallet
	local function weatherPart(name: string, x: number, y: number, width: number, height: number, color: Color3)
		local part = Instance.new("Frame")
		part.Name = name
		part.Position = UDim2.fromOffset(x, y)
		part.Size = UDim2.fromOffset(width, height)
		part.BackgroundColor3 = color
		part.BorderSizePixel = 0
		part.ZIndex = 2
		part.Parent = weatherIcon
		Theme.corner(part, 999)
		return part
	end
	-- Native shapes keep the small HUD icon independent of image downloads.
	local cloudColor = Color3.fromRGB(234, 240, 247)
	local clouds = {
		weatherPart("CloudLeft", 2, 9, 17, 17, cloudColor),
		weatherPart("CloudTop", 11, 2, 21, 24, cloudColor),
		weatherPart("CloudRight", 24, 12, 14, 14, cloudColor),
		weatherPart("CloudBase", 10, 17, 21, 9, cloudColor),
	}
	local voidRing = weatherPart("BlackHoleRing", 2, 1, 34, 34, Color3.fromRGB(177, 68, 255))
	local voidCore = weatherPart("BlackHoleCore", 7, 6, 24, 24, Color3.new(0, 0, 0))
	voidCore.ZIndex = 3
	local drops = {}
	for index = 1, 4 do
		local drop = weatherPart("Rain" .. index, 5 + (index - 1) * 8, 28, 2, 7, Color3.fromRGB(137, 204, 255))
		drop.Rotation = 25
		drops[index] = drop
	end
	-- A narrow funnel under the cloud marks a supercell.
	local funnel = weatherPart("Funnel", 16, 24, 6, 12, Color3.fromRGB(150, 160, 156))
	local lightning =
		label(weatherIcon, "ϟ", UDim2.fromOffset(21, 17), UDim2.fromOffset(17, 22), 25, Color3.fromRGB(255, 219, 109))
	lightning.Name = "Lightning"
	lightning.ZIndex = 3
	local currentWeather: string? = nil
	local function refreshWeather()
		local root = player.Character and player.Character.PrimaryPart
		local kind = Weather.getState(nil, if root then root.Position else Vector3.zero).kind
		if kind == currentWeather then
			return
		end
		currentWeather = kind
		local blackHole = kind == "BlackHole"
		local supercell = kind == "Supercell"
		weatherIcon.Visible = blackHole or supercell or kind == "LightRain" or kind == "Rain" or kind == "Storm"
		voidRing.Visible, voidCore.Visible = blackHole, blackHole
		for _, cloud in clouds do
			cloud.Visible = not blackHole
			cloud.BackgroundColor3 = if supercell then Color3.fromRGB(112, 128, 122) else cloudColor
		end
		funnel.Visible = supercell
		lightning.Visible = kind == "Storm" or supercell
		for index, drop in drops do
			drop.Visible = not blackHole
				and (
					if kind == "Storm"
						then index <= 2
						elseif supercell then index == 1
						else kind == "Rain" or index % 2 == 1
				)
		end
	end
	refreshWeather()
	-- Keep the original floating money/level HUD, independent of the menu theme.
	for index = 1, 32 do
		local fraction = index / 32
		local halo = Instance.new("Frame")
		halo.Name = "BackdropFade" .. index
		halo.AnchorPoint = Vector2.new(0.5, 0.5)
		halo.Position = UDim2.new(0.42, 0, 0.5, 0)
		halo.Size = UDim2.fromOffset(390 - fraction * 210, 210 - fraction * 130)
		halo.BackgroundColor3 = Color3.new(0, 0, 0)
		halo.BackgroundTransparency = 1 - math.sin(fraction * math.pi) * 0.036
		halo.BorderSizePixel = 0
		halo.Parent = wallet
		Theme.corner(halo, 999)
	end
	local cash =
		label(wallet, "—", UDim2.fromOffset(0, 0), UDim2.fromOffset(244, 46), 36, Color3.fromRGB(255, 249, 205))
	cash.ZIndex = 2
	cash.Font = Enum.Font.GothamBold
	cash.FontFace = Font.new(cash.FontFace.Family, Enum.FontWeight.Bold, Enum.FontStyle.Italic)
	cash.TextStrokeTransparency = 0.8
	cash.TextWrapped = false
	cash.TextScaled = true
	local textBounds = Instance.new("UITextSizeConstraint")
	textBounds.MaxTextSize = 36
	textBounds.Parent = cash

	local levelBar = Instance.new("Frame")
	levelBar.Name = "LevelBar"
	levelBar.Position = UDim2.fromOffset(0, 54)
	levelBar.Size = UDim2.fromOffset(232, 24)
	levelBar.BackgroundColor3 = Color3.fromRGB(18, 22, 23)
	levelBar.BackgroundTransparency = 0.25
	levelBar.BorderSizePixel = 0
	levelBar.ZIndex = 2
	levelBar.ClipsDescendants = true
	levelBar.Parent = wallet
	Theme.corner(levelBar, 12)
	local fill = Instance.new("Frame")
	fill.Name = "Progress"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(226, 185, 112)
	fill.BackgroundTransparency = 0.15
	fill.BorderSizePixel = 0
	fill.ZIndex = 2
	fill.Parent = levelBar
	Theme.corner(fill, 12)
	local levelText =
		label(levelBar, "Level 1", UDim2.fromOffset(10, 0), UDim2.new(1, -20, 1, 0), 13, Color3.fromRGB(247, 238, 216))
	levelText.Font = Enum.Font.GothamBold
	levelText.TextStrokeTransparency = 1
	levelText.TextXAlignment = Enum.TextXAlignment.Center
	levelText.ZIndex = 3

	local function refreshLevel()
		-- Presentation only: progression is supplied by server-owned player attributes.
		local level = player:GetAttribute("Level") or 1
		local xp = player:GetAttribute("LevelXP") or 0
		local requiredXP = player:GetAttribute("LevelXPRequired") or 100
		fill.Size = UDim2.fromScale(math.clamp(xp / math.max(1, requiredXP), 0, 1), 1)
		levelText.Text = "Level " .. tostring(level)
	end
	for _, attribute in { "Level", "LevelXP", "LevelXPRequired" } do
		player:GetAttributeChangedSignal(attribute):Connect(refreshLevel)
	end
	refreshLevel()

	local controlledBoat: Model? = nil
	local lightsToggle = Instance.new("TextButton")
	lightsToggle.Name = "ToggleBoatLights"
	lightsToggle.Position = UDim2.new(1, -126, 1, -192)
	lightsToggle.Size = UDim2.fromOffset(112, 38)
	lightsToggle.Text = "Lights ON [L]"
	lightsToggle.TextSize = 12
	lightsToggle.Visible = false
	lightsToggle.Parent = gui
	Theme.button(lightsToggle, "Selected")
	local previousLightsOn: boolean? = nil
	local cameraToggle = Instance.new("TextButton")
	cameraToggle.Name = "CycleBoatCamera"
	cameraToggle.Position = UDim2.new(1, -126, 1, -238)
	cameraToggle.Size = UDim2.fromOffset(112, 38)
	cameraToggle.TextSize = 11
	cameraToggle.TextWrapped = true
	cameraToggle.Text = "Camera [V]\n" .. BoatCamera.label()
	cameraToggle.Visible = false
	cameraToggle.Parent = gui
	Theme.button(cameraToggle, "Normal")
	local netToggle = Instance.new("TextButton")
	netToggle.Name = "ToggleTrawlerNet"
	netToggle.Position = UDim2.new(1, -126, 1, -146)
	netToggle.Size = UDim2.fromOffset(112, 38)
	netToggle.Text = "Net IN [N]"
	netToggle.TextSize = 12
	netToggle.Visible = false
	netToggle.Parent = gui
	Theme.button(netToggle, "Normal")
	local previousNetDeployed: boolean? = nil

	local overlay = Instance.new("TextButton")
	overlay.Name = "ShopOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 1
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Visible = false
	overlay.Parent = gui
	local card = Instance.new("Frame")
	card.Name = "DrydockShop"
	card.Active = true
	card.AnchorPoint = Vector2.new(0, 0.5)
	card.Position = UDim2.new(0, 20, 0.5, 0)
	card.Size = UDim2.fromOffset(380, 500)
	card.BackgroundColor3 = navy
	card.Parent = overlay
	Theme.window(card)
	local scale = Instance.new("UIScale")
	scale.Parent = card
	local product = Instance.new("Frame")
	product.Name = "BoatOffer"
	product.Size = UDim2.fromScale(1, 1)
	product.BackgroundTransparency = 1
	product.Parent = card
	label(product, "DRYDOCK · SHIP PREVIEW", UDim2.fromOffset(24, 23), UDim2.fromOffset(276, 22), 12, cream)
	local title = label(product, spec.Name, UDim2.fromOffset(24, 61), UDim2.fromOffset(332, 38), 27, cream)
	title.Font = Enum.Font.GothamBold
	local description = label(
		product,
		"Inspect your boat on the slipway. After purchase, we lower it into the water and put you aboard.",
		UDim2.fromOffset(24, 155),
		UDim2.fromOffset(332, 43),
		14,
		muted
	)
	local tabs = Instance.new("ScrollingFrame")
	tabs.Name = "BoatTabs"
	tabs.Position, tabs.Size = UDim2.fromOffset(24, 105), UDim2.fromOffset(332, 46)
	tabs.BackgroundTransparency, tabs.BorderSizePixel = 1, 0
	tabs.ScrollBarThickness = 3
	tabs.ScrollingDirection = Enum.ScrollingDirection.X
	tabs.CanvasSize = UDim2.fromOffset(#boatIds * 114, 0)
	tabs.Parent = product
	local boatTabs = {}
	for index, boatId in boatIds do
		local tab = Instance.new("TextButton")
		tab.Name = "Select" .. boatId
		tab.Position = UDim2.fromOffset((index - 1) * 114, 0)
		tab.Size = UDim2.fromOffset(106, 42)
		tab.TextWrapped = true
		tab.Text = if boatId == "Rowboat"
			then "Rowboat"
			elseif boatId == "FishingBoat" then "Fishing boat"
			elseif boatId == "Speedboat" then "Speedboat"
			elseif boatId == "RacingSpeedboat" then "Racing"
			elseif boatId == "Trawler" then "Fishing trawler"
			else "Patrol cruiser"
		tab.Font, tab.TextSize = Enum.Font.GothamBold, 12
		tab.Parent = tabs
		Theme.button(tab)
		boatTabs[boatId] = tab
		tab.Activated:Connect(function()
			if not isLaunching then
				request:FireServer("BrowseBoat", boatId)
			end
		end)
	end
	local statValues = {}
	for index, statName in { "Forward speed", "Reverse speed", "Turning", "Hull / seats" } do
		label(product, statName, UDim2.fromOffset(24, 208 + (index - 1) * 28), UDim2.fromOffset(154, 25), 14, muted)
		local value =
			label(product, "", UDim2.fromOffset(178, 208 + (index - 1) * 28), UDim2.fromOffset(178, 25), 14, cream)
		value.TextXAlignment = Enum.TextXAlignment.Right
		statValues[index] = value
	end
	local price =
		label(product, "$" .. tostring(spec.Price), UDim2.fromOffset(24, 329), UDim2.fromOffset(130, 35), 29, gold)
	Theme.text(price, Theme.Colors.Green)
	local balance = label(product, "Your cash: $0", UDim2.fromOffset(154, 329), UDim2.fromOffset(202, 35), 14, cream)
	balance.TextXAlignment = Enum.TextXAlignment.Right
	local status = label(product, "", UDim2.fromOffset(24, 373), UDim2.fromOffset(332, 46), 14, muted)
	local buy = Instance.new("TextButton")
	buy.Name = "BuyBoat"
	buy.Position = UDim2.fromOffset(24, 428)
	buy.Size = UDim2.fromOffset(332, 48)
	buy.Font = Enum.Font.GothamBold
	buy.TextSize = 16
	buy.TextColor3 = navy
	buy.BackgroundColor3 = gold
	buy.Parent = product
	Theme.button(buy, "Selected")
	local close = Instance.new("TextButton")
	close.Name = "CloseShop"
	close.Position = UDim2.new(1, -52, 0, 13)
	close.Size = UDim2.fromOffset(40, 40)
	close.BackgroundTransparency = 1
	close.Text = "×"
	close.Font = Enum.Font.Gotham
	close.TextColor3 = cream
	close.TextSize = 28
	close.Parent = card
	Theme.button(close, "Danger")

	local dialogue = Instance.new("Frame")
	dialogue.Name = "ShipwrightDialogue"
	dialogue.Size = UDim2.fromScale(1, 1)
	dialogue.BackgroundTransparency = 1
	dialogue.Visible = false
	dialogue.Parent = card
	label(dialogue, "MARA · SHIPWRIGHT", UDim2.fromOffset(24, 23), UDim2.fromOffset(276, 22), 12, cream)
	local greetingTitle =
		label(dialogue, "Welcome to the drydock.", UDim2.fromOffset(24, 65), UDim2.fromOffset(332, 68), 25, cream)
	greetingTitle.Font = Enum.Font.GothamBold
	local greeting = label(dialogue, "", UDim2.fromOffset(24, 150), UDim2.fromOffset(332, 130), 17, cream)
	greeting.TextYAlignment = Enum.TextYAlignment.Top
	local browse = Instance.new("TextButton")
	browse.Name = "BrowseBoats"
	browse.Position = UDim2.fromOffset(24, 325)
	browse.Size = UDim2.fromOffset(332, 51)
	browse.BackgroundColor3 = gold
	browse.TextColor3 = navy
	browse.Text = "Show me the boats"
	browse.Font = Enum.Font.GothamBold
	browse.TextSize = 16
	browse.Parent = dialogue
	Theme.button(browse, "Selected")
	local leave = Instance.new("TextButton")
	leave.Name = "LeaveConversation"
	leave.Position = UDim2.fromOffset(24, 400)
	leave.Size = UDim2.fromOffset(332, 42)
	leave.BackgroundTransparency = 1
	leave.TextColor3 = muted
	leave.Text = "Maybe later"
	leave.Font = Enum.Font.Gotham
	leave.TextSize = 15
	leave.Parent = dialogue
	Theme.button(leave)
	local dock = Instance.new("Frame")
	dock.Name = "DockBoatChooser"
	dock.Size = UDim2.fromScale(1, 1)
	dock.BackgroundTransparency = 1
	dock.Visible = false
	dock.Parent = card
	label(dock, "HOME DOCK  /  YOUR FLEET", UDim2.fromOffset(24, 20), UDim2.fromOffset(280, 20), 12, gold)
	local dockTitle = label(dock, "Ready to set sail?", UDim2.fromOffset(24, 47), UDim2.fromOffset(332, 38), 28, cream)
	dockTitle.Font = Enum.Font.GothamBold
	local dockDescription = label(
		dock,
		"Choose a boat from your fleet and launch it at your dock.",
		UDim2.fromOffset(24, 85),
		UDim2.fromOffset(740, 28),
		14,
		muted
	)
	local previewPanel = Instance.new("Frame")
	previewPanel.Name = "BoatPreviewPanel"
	previewPanel.ClipsDescendants = true
	previewPanel.Parent = dock
	Theme.glassPanel(previewPanel, true)
	previewPanel.BackgroundColor3 = Color3.new(1, 1, 1)
	previewPanel.BackgroundTransparency = 0
	local previewWash = Instance.new("UIGradient")
	previewWash.Color = ColorSequence.new(Color3.fromRGB(47, 74, 88), Color3.fromRGB(13, 22, 31))
	previewWash.Rotation = 90
	previewWash.Parent = previewPanel
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "SelectedBoatModel"
	viewport.Size = UDim2.new(1, -24, 1, -56)
	viewport.Position = UDim2.fromOffset(12, 12)
	viewport.BackgroundTransparency = 1
	viewport.Parent = previewPanel
	local previewStatus = label(previewPanel, "", UDim2.fromOffset(16, 12), UDim2.new(1, -32, 1, -56), 16, muted)
	previewStatus.TextXAlignment = Enum.TextXAlignment.Center
	local previewHint = label(
		previewPanel,
		"Drag to rotate  ·  3D preview",
		UDim2.new(0, 16, 1, -36),
		UDim2.new(1, -32, 0, 24),
		12,
		muted
	)
	previewHint.TextXAlignment = Enum.TextXAlignment.Center
	local dockPreview = BoatPreview.new(viewport, remotes, previewStatus)
	local dockBoatName = label(dock, "", UDim2.fromOffset(478, 126), UDim2.fromOffset(298, 30), 20, cream)
	local fleetLabel = label(dock, "YOUR BOATS", UDim2.fromOffset(478, 168), UDim2.fromOffset(298, 20), 11, muted)
	local fleet = Instance.new("ScrollingFrame")
	fleet.Name = "FleetChoices"
	fleet.BackgroundTransparency, fleet.BorderSizePixel = 1, 0
	fleet.ScrollBarThickness = 4
	fleet.CanvasSize = UDim2.fromOffset(0, #boatIds * 48)
	fleet.ScrollingDirection = Enum.ScrollingDirection.Y
	fleet.Parent = dock
	local dockChoices = {}
	for _, boatId in boatIds do
		local choice = Instance.new("TextButton")
		choice.Name = "Launch" .. boatId
		choice.Size = UDim2.fromOffset(298, 44)
		choice.Font, choice.TextSize = Enum.Font.GothamBold, 14
		choice.TextWrapped = true
		choice.Parent = fleet
		Theme.glassButton(choice)
		dockChoices[boatId] = choice
	end
	local dockStats = Instance.new("Frame")
	dockStats.Name = "SelectedBoatStats"
	dockStats.BackgroundTransparency = 1
	dockStats.Parent = dock
	local dockStatValues = {}
	for index, name in { "STUDS / S", "SEATS", "CARGO SLOTS" } do
		local stat = Instance.new("Frame")
		stat.Position = UDim2.new((index - 1) / 3, 0, 0, 0)
		stat.Size = UDim2.new(1 / 3, -6, 1, 0)
		stat.Parent = dockStats
		Theme.glassPanel(stat, true)
		local value = label(stat, "—", UDim2.fromOffset(4, 8), UDim2.new(1, -8, 0, 25), 19, cream)
		value.TextXAlignment = Enum.TextXAlignment.Center
		dockStatValues[index] = value
		local caption = label(stat, name, UDim2.fromOffset(4, 36), UDim2.new(1, -8, 0, 18), 10, muted)
		caption.TextXAlignment = Enum.TextXAlignment.Center
	end
	local dockStatus = label(dock, "", UDim2.fromOffset(24, 484), UDim2.fromOffset(430, 48), 13, muted)
	local launch = Instance.new("TextButton")
	launch.Name = "LaunchSelectedBoat"
	launch.Font, launch.TextSize = Enum.Font.GothamBold, 16
	launch.Parent = dock
	Theme.glassButton(launch, "Selected")
	local function layoutDock(compact: boolean)
		card.Size = UDim2.fromOffset(if compact then 400 else 800, if compact then 774 else 560)
		dockDescription.Size = UDim2.fromOffset(if compact then 352 else 740, 28)
		dockDescription.TextSize = if compact then 12 else 14
		previewPanel.Position = UDim2.fromOffset(24, 126)
		previewPanel.Size = UDim2.fromOffset(if compact then 352 else 430, if compact then 238 else 342)
		dockBoatName.Position = UDim2.fromOffset(if compact then 24 else 478, if compact then 376 else 126)
		dockBoatName.Size = UDim2.fromOffset(if compact then 352 else 298, 30)
		fleetLabel.Position = UDim2.fromOffset(if compact then 24 else 478, if compact then 409 else 168)
		fleet.Position = UDim2.fromOffset(if compact then 24 else 478, if compact then 434 else 198)
		fleet.Size = UDim2.fromOffset(if compact then 352 else 298, 156)
		for index, boatId in boatIds do
			local choice = dockChoices[boatId]
			choice.Position = UDim2.fromOffset(0, (index - 1) * 48)
			choice.Size = UDim2.fromOffset(if compact then 342 else 288, 44)
		end
		dockStats.Position = UDim2.fromOffset(if compact then 24 else 478, if compact then 598 else 366)
		dockStats.Size = UDim2.fromOffset(if compact then 358 else 304, 62)
		dockStatus.Position = UDim2.fromOffset(24, if compact then 668 else 484)
		dockStatus.Size = UDim2.fromOffset(if compact then 352 else 430, if compact then 28 else 48)
		launch.Position = UDim2.fromOffset(if compact then 24 else 478, if compact then 710 else 478)
		launch.Size = UDim2.fromOffset(if compact then 352 else 298, if compact then 48 else 56)
	end
	local layoutSize = Vector2.zero
	local layoutIsDock = false
	local function layoutMenu()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local size = camera.ViewportSize
		if size == layoutSize and dock.Visible == layoutIsDock then
			return
		end
		layoutSize, layoutIsDock = size, dock.Visible
		overlay.BackgroundTransparency = if dock.Visible then 0.35 else 1
		local portrait = size.X < size.Y * 1.2
		if dock.Visible then
			layoutDock(size.X < 700 or portrait)
			card.AnchorPoint = Vector2.new(0.5, 0.5)
			card.Position = UDim2.fromScale(0.5, 0.5)
			scale.Scale = math.min(1, (size.X - 32) / card.Size.X.Offset, (size.Y - 32) / card.Size.Y.Offset)
		else
			card.Size = UDim2.fromOffset(380, 500)
			card.AnchorPoint = if portrait then Vector2.new(0.5, 1) else Vector2.new(0, 0.5)
			card.Position = if portrait then UDim2.new(0.5, 0, 1, -16) else UDim2.new(0, 20, 0.5, 0)
			scale.Scale = math.min(1, (size.X - 32) / 380, (size.Y * (if portrait then 0.48 else 0.88)) / 500)
		end
	end
	local function refreshDockPreview()
		if not overlay.Visible or not dock.Visible then
			dockPreview.show(nil)
			return
		end
		local dataStatus = player:GetAttribute("BoatDataStatus")
		local ready = dataStatus == "Ready"
		local owned = player:GetAttribute("Owns" .. selectedDockBoatId) == true
		dockPreview.show(if ready and owned then selectedDockBoatId else nil)
		if not ready or not owned then
			previewStatus.Visible = true
			previewStatus.Text = if dataStatus == "Unavailable"
				then "Fleet unavailable"
				elseif not ready then "Loading your fleet…"
				else "Buy your first boat from Mara\nat the shipyard."
		end
	end
	dock:GetPropertyChangedSignal("Visible"):Connect(function()
		layoutMenu()
		refreshDockPreview()
	end)
	close.ZIndex = 3
	browse.Activated:Connect(function()
		request:FireServer("BrowseBoat", selectedBoatId)
	end)
	leave.Activated:Connect(function()
		overlay.Visible = false
	end)
	-- Every dismissal path (buttons, distance, Escape and respawn) restores camera.
	overlay:GetPropertyChangedSignal("Visible"):Connect(function()
		player:SetAttribute("DrydockScreenOpen", overlay.Visible or isLaunching)
		if overlay.Visible then
			layoutMenu()
		end
		refreshDockPreview()
		if not overlay.Visible and not isLaunching then
			previewShop = nil
			dockBase = nil
			DrydockCamera.stop()
		end
	end)
	player:SetAttribute("DrydockScreenOpen", false)
	player.CharacterAdded:Connect(function()
		overlay.Visible = false
		BoatCamera.stop()
		if not isLaunching then
			DrydockCamera.stop()
		end
	end)

	local toast = Instance.new("TextLabel")
	toast.Name = "BoatNotice"
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -88)
	toast.Size = UDim2.new(0.86, 0, 0, 66)
	toast.BackgroundColor3 = navy
	toast.BackgroundTransparency = 0.06
	toast.TextColor3 = cream
	toast.Font = Enum.Font.GothamMedium
	toast.TextSize = 15
	toast.TextWrapped = true
	toast.Visible = false
	toast.ZIndex = 5
	toast.Parent = gui
	Theme.panel(toast, false, 4)
	Theme.text(toast)
	local toastBounds = Instance.new("UISizeConstraint")
	toastBounds.MaxSize = Vector2.new(580, 66)
	toastBounds.Parent = toast
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
	padding.Parent = toast
	local noticeId = 0
	local function notice(message: string)
		noticeId += 1
		local current = noticeId
		toast.Text, toast.Visible = message, true
		task.delay(6, function()
			if noticeId == current then
				toast.Visible = false
			end
		end)
	end
	local function refresh()
		local amount = player:GetAttribute("Cash") or 0
		local dataStatus = player:GetAttribute("BoatDataStatus")
		local owned = player:GetAttribute("Owns" .. selectedBoatId) == true
		local ready = dataStatus == "Ready"
		local ownsAnyBoat = false
		for _, id in boatIds do
			if player:GetAttribute("Owns" .. id) == true then
				ownsAnyBoat = true
			end
		end
		greeting.Text = if ownsAnyBoat
			then "Welcome back! Browse our boats, or launch a boat you already own from the boat stand on your own dock."
			else "Looking for your first boat? Start with the wooden rowboat, or step up to a bigger, faster fishing boat. We'll lower your purchase into the water and put you aboard."
		title.Text = spec.Name
		description.Text = if selectedBoatId == "RacingSpeedboat"
			then "Our fastest boat with the sharpest turns. Four cockpit seats and 49 cargo tiles: 15 fewer than the fishing boat."
			elseif
				selectedBoatId == "Trawler"
			then "A traditional teal fishing trawler with a sheltered forward wheelhouse, stern gantry, net drum and two fishing seats. Cruise at 70 studs/s with 104 cargo tiles."
			elseif
				selectedBoatId == "PatrolBoat"
			then "A long gray patrol cruiser with a wheelhouse for two, stern benches for two more, 128 cargo tiles and more speed. Pivots easily in harbour; turns a little wider than the Bluewater speedboat at speed."
			elseif
				selectedBoatId == "Speedboat"
			then "A blue-and-white sport cruiser with more speed, sharper turns and the same 64 cargo tiles as the fishing boat."
			elseif
				selectedBoatId == "FishingBoat"
			then "A bigger hull, a sheltered wheelhouse and room for three. Cruise faster to your next fishing spot."
			else "A simple wooden boat for your first trips. Inspect the hull before we lower it into the water."
		statValues[1].Text = tostring(spec.ForwardSpeed) .. " studs/s"
		statValues[2].Text = tostring(spec.ReverseSpeed) .. " studs/s"
		statValues[3].Text = string.format("%.0f°/s", math.deg(spec.TurnRate))
		statValues[4].Text = tostring(spec.Length)
			.. " × "
			.. tostring(spec.Beam)
			.. " studs / "
			.. tostring(spec.Seats)
		price.Text = "$" .. tostring(spec.Price)
		for boatId, tab in boatTabs do
			Theme.button(tab, if boatId == selectedBoatId then "Selected" else nil)
		end
		local formatted = tostring(amount):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
		cash.Text = if ready then formatted .. " $" else "—"
		balance.Text = if ready then "Your cash: $" .. tostring(amount) else "Wallet unavailable"
		local occupied = previewShop and previewShop:GetAttribute("LaunchingUserId") ~= nil
		buy.Active = ready and not owned and amount >= spec.Price and not occupied and not isLaunching
		buy.Selectable = buy.Active
		buy.AutoButtonColor = buy.Active
		Theme.button(buy, if buy.Active then "Selected" else "Disabled")
		buy.Text = if owned
			then "Boat owned"
			elseif occupied then "Drydock busy"
			else "Buy & launch · $" .. tostring(spec.Price)
		if dataStatus == "Unavailable" then
			status.Text = "Wallet could not load. Rejoin to try again."
		elseif not ready then
			status.Text = "Loading your wallet…"
		elseif owned then
			status.Text = "Owned! Use the boat stand at your own dock to spawn it."
		elseif occupied then
			status.Text = "Another boat is launching. The drydock will be ready shortly."
		elseif amount < spec.Price then
			status.Text = "You need $" .. tostring(spec.Price - amount) .. " more to buy this boat."
		else
			status.Text = "Includes launch and automatic boarding. Sail this boat to your own plot."
		end
		if player:GetAttribute("Owns" .. selectedDockBoatId) ~= true then
			for _, boatId in boatIds do
				if player:GetAttribute("Owns" .. boatId) == true then
					selectedDockBoatId = boatId
					break
				end
			end
		end
		for _, boatId in boatIds do
			local choice, boatSpec = dockChoices[boatId], BoatCatalog[boatId]
			local boatOwned = player:GetAttribute("Owns" .. boatId) == true
			choice.Active, choice.Selectable = ready and boatOwned, ready and boatOwned
			choice.Text = (if boatOwned and boatId == selectedDockBoatId then "✓  " else "")
				.. boatSpec.Name
				.. "\n"
				.. (
					if not ready
						then "Loading…"
						elseif boatOwned then "Owned · ready to launch"
						else "Available at the shipyard · $" .. tostring(boatSpec.Price)
				)
			Theme.glassButton(
				choice,
				if not ready or not boatOwned
					then "Disabled"
					elseif boatId == selectedDockBoatId then "Selected"
					else nil
			)
		end
		local dockSpec = BoatCatalog[selectedDockBoatId]
		dockBoatName.Text = if ownsAnyBoat then dockSpec.Name else "Your fleet starts here"
		local cargoSlots = 0
		for _, row in dockSpec.Hold do
			local _, count = row:gsub("#", "")
			cargoSlots += count
		end
		dockStatValues[1].Text = if ownsAnyBoat then tostring(dockSpec.ForwardSpeed) else "—"
		dockStatValues[2].Text = if ownsAnyBoat then tostring(dockSpec.Seats) else "—"
		dockStatValues[3].Text = if ownsAnyBoat then tostring(cargoSlots) else "—"
		previewHint.Visible = ownsAnyBoat and ready
		refreshDockPreview()
		launch.Active = ready and player:GetAttribute("Owns" .. selectedDockBoatId) == true and not isLaunching
		launch.Selectable, launch.AutoButtonColor = launch.Active, launch.Active
		Theme.glassButton(launch, if launch.Active then "Selected" else "Disabled")
		launch.Text = if dataStatus == "Unavailable"
			then "Fleet unavailable"
			elseif not ready then "Loading boats…"
			elseif ownsAnyBoat then "Launch boat  →"
			else "No boats owned"
		dockStatus.Text = if dataStatus == "Unavailable"
			then "Your boats could not load. Rejoin to try again."
			elseif not ready then "Loading your boats…"
			elseif not ownsAnyBoat then "Visit Mara at the shipyard to buy your first boat."
			else "Launching replaces your current boat. Your new boat will be waiting at this dock."
	end
	for _, id in boatIds do
		player:GetAttributeChangedSignal("Owns" .. id):Connect(refresh)
	end
	for _, attribute in { "Cash", "BoatDataStatus" } do
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	for boatId, choice in dockChoices do
		choice.Activated:Connect(function()
			if not choice.Active then
				return
			end
			selectedDockBoatId = boatId
			refresh()
		end)
	end
	launch.Activated:Connect(function()
		if launch.Active then
			request:FireServer("SpawnBoat", selectedDockBoatId)
			overlay.Visible = false
		end
	end)
	refresh()
	player:GetAttributeChangedSignal("PlayerMenuOpen"):Connect(function()
		if player:GetAttribute("PlayerMenuOpen") then
			overlay.Visible = false
		end
	end)
	close.Activated:Connect(function()
		overlay.Visible = false
	end)
	overlay.Activated:Connect(function()
		overlay.Visible = false
	end)
	buy.Activated:Connect(function()
		if buy.Active then
			request:FireServer("PurchaseBoat", selectedBoatId)
		end
	end)
	local function toggleLights()
		if
			controlledBoat
			and lightsToggle.Visible
			and not overlay.Visible
			and not player:GetAttribute("PlayerMenuOpen")
		then
			request:FireServer("ToggleLights")
		end
	end
	lightsToggle.Activated:Connect(toggleLights)
	local function toggleCamera()
		if
			controlledBoat
			and cameraToggle.Visible
			and not overlay.Visible
			and not player:GetAttribute("PlayerMenuOpen")
		then
			BoatCamera.cycle()
			cameraToggle.Text = "Camera [V]\n" .. BoatCamera.label()
		end
	end
	cameraToggle.Activated:Connect(toggleCamera)
	local function toggleNet()
		if
			controlledBoat
			and netToggle.Visible
			and not overlay.Visible
			and not player:GetAttribute("PlayerMenuOpen")
		then
			netRemote:FireServer("Toggle")
		end
	end
	netToggle.Activated:Connect(toggleNet)
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			overlay.Visible = false
		elseif input.KeyCode == Enum.KeyCode.L and not processed and not UserInputService:GetFocusedTextBox() then
			toggleLights()
		elseif input.KeyCode == Enum.KeyCode.V and not processed and not UserInputService:GetFocusedTextBox() then
			toggleCamera()
		elseif input.KeyCode == Enum.KeyCode.N and not processed and not UserInputService:GetFocusedTextBox() then
			toggleNet()
		end
	end)
	feedback.OnClientEvent:Connect(function(kind, message, boatId)
		if
			(kind == "OpenDialogue" or kind == "OpenShop" or kind == "OpenDock")
			and player:GetAttribute("PlayerMenuOpen")
		then
			return
		end
		if kind == "OpenDialogue" then
			if isLaunching then
				return
			end
			DrydockCamera.stop()
			previewShop = nil
			dockBase = nil
			refresh()
			dialogue.Visible, product.Visible, dock.Visible = true, false, false
			overlay.Visible = true
		elseif kind == "OpenShop" then
			if isLaunching then
				return
			end
			previewShop = message
			dockBase = nil
			selectedBoatId = if type(boatId) == "string" and BoatCatalog[boatId] then boatId else "Rowboat"
			spec = BoatCatalog[selectedBoatId]
			refresh()
			dialogue.Visible, product.Visible, dock.Visible = false, true, false
			overlay.Visible = true
			if previewShop then
				DrydockCamera.show(previewShop, false, selectedBoatId)
			end
		elseif kind == "OpenDock" then
			if isLaunching or typeof(message) ~= "Instance" or message:GetAttribute("OwnerUserId") ~= player.UserId then
				return
			end
			DrydockCamera.stop()
			previewShop, dockBase = nil, message
			refresh()
			dialogue.Visible, product.Visible, dock.Visible = false, false, true
			overlay.Visible = true
		elseif kind == "LaunchStarted" then
			isLaunching = true
			player:SetAttribute("DrydockScreenOpen", true)
			previewShop = message
			dockBase = nil
			overlay.Visible = false
			if previewShop then
				DrydockCamera.show(previewShop, true, boatId)
			end
			local launchingSpec = if type(boatId) == "string" then BoatCatalog[boatId] else spec
			notice("Lowering your " .. string.lower((launchingSpec or spec).Name) .. " into the water…")
		elseif kind == "LaunchFinished" then
			isLaunching = false
			player:SetAttribute("DrydockScreenOpen", overlay.Visible)
			previewShop = nil
			DrydockCamera.stop()
		elseif kind == "CommandNotice" and type(message) == "string" then
			local channels = TextChatService:FindFirstChild("TextChannels")
			local channel = channels and (channels:FindFirstChild("RBXSystem") or channels:FindFirstChild("RBXGeneral"))
			if channel then
				local escaped = message:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
				channel:DisplaySystemMessage(escaped)
			else
				notice(message)
			end
		elseif kind == "Notice" and type(message) == "string" then
			notice(message)
		end
	end)
	netRemote.OnClientEvent:Connect(function(kind, fishName, kg, value)
		if kind == "Catch" and type(fishName) == "string" then
			notice(string.format("Your net caught a %s · %.2f kg · $%d", fishName, tonumber(kg) or 0, tonumber(value) or 0))
		elseif kind == "Notice" and type(fishName) == "string" then
			notice(fishName)
		end
	end)

	local tracked = {}
	local function trackBase(base: Instance)
		if tracked[base] then
			return
		end
		local prompts: { [ProximityPrompt]: boolean } = {}
		local function add(descendant: Instance)
			if descendant:IsA("ProximityPrompt") and descendant.Name == "SpawnRowboatPrompt" then
				prompts[descendant] = true
				descendant.Enabled = base:GetAttribute("OwnerUserId") == player.UserId
			end
		end
		local function update()
			local owned = base:GetAttribute("OwnerUserId") == player.UserId
			for prompt in prompts do
				prompt.Enabled = owned
			end
		end
		local connections = {
			base:GetAttributeChangedSignal("OwnerUserId"):Connect(update),
			base.DescendantAdded:Connect(add),
			base.DescendantRemoving:Connect(function(descendant)
				prompts[descendant] = nil
			end),
		}
		tracked[base] = connections
		-- Streaming can deliver thousands of house parts. Scan once, then inspect
		-- only the instance arriving rather than rescanning the whole base each time.
		for _, descendant in base:GetDescendants() do
			add(descendant)
		end
	end
	for _, base in CollectionService:GetTagged("PlayerBase") do
		trackBase(base)
	end
	CollectionService:GetInstanceAddedSignal("PlayerBase"):Connect(trackBase)
	CollectionService:GetInstanceRemovedSignal("PlayerBase"):Connect(function(base)
		for _, connection in tracked[base] or {} do
			connection:Disconnect()
		end
		tracked[base] = nil
	end)

	local sinceInput, sinceShopCheck = 0, 0
	local sentThrottle: number?, sentSteer: number? = nil, nil
	local previousSeat: VehicleSeat? = nil
	local sinceWeatherCheck = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceWeatherCheck += dt
		if sinceWeatherCheck >= 0.5 then
			sinceWeatherCheck = 0
			refreshWeather()
		end
		local camera = workspace.CurrentCamera
		if overlay.Visible and camera then
			layoutMenu()
			if dock.Visible then
				dockPreview.step(dt)
			end
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		local boatModel = seat and seat.Parent
		local drivenBoatId = boatModel and boatModel:GetAttribute("BoatId")
		local drivenSpec = if type(drivenBoatId) == "string" then BoatCatalog[drivenBoatId] else BoatCatalog.Rowboat
		local ownSeat = seat
			and seat:IsA("VehicleSeat")
			and drivenSpec ~= nil
			and seat.Name == (drivenSpec.DriverSeat or "RowerSeat")
			and boatModel:GetAttribute("OwnerUserId") == player.UserId
		controlledBoat = if ownSeat then boatModel else nil
		local helmVisible = controlledBoat ~= nil
			and not overlay.Visible
			and not isLaunching
			and not player:GetAttribute("PlayerMenuOpen")
		lightsToggle.Visible = helmVisible
		local cameraAllowed = helmVisible
			and not player:GetAttribute("BuildModeOpen")
			and not player:GetAttribute("RodCrateOpening")
		cameraToggle.Visible = cameraAllowed
		BoatCamera.setActive(if cameraAllowed then controlledBoat else nil, if cameraAllowed then seat else nil)
		local netAllowed = helmVisible
			and controlledBoat ~= nil
			and controlledBoat:GetAttribute("BoatId") == "Trawler"
			and controlledBoat:GetAttribute("NetOwned") == true
			and not player:GetAttribute("BoatRefitOpen")
		netToggle.Visible = netAllowed
		local netDeployed = netAllowed and controlledBoat:GetAttribute("NetDeployed") == true
		if netDeployed ~= previousNetDeployed then
			previousNetDeployed = netDeployed
			netToggle.Text = if netDeployed then "Net OUT [N]" else "Net IN [N]"
			Theme.button(netToggle, if netDeployed then "Selected" else "Normal")
		end
		local lightsOn = controlledBoat ~= nil and controlledBoat:GetAttribute("LightsEnabled") ~= false
		if lightsOn ~= previousLightsOn then
			previousLightsOn = lightsOn
			lightsToggle.Text = if lightsOn then "Lights ON [L]" else "Lights OFF [L]"
			Theme.button(lightsToggle, if lightsOn then "Selected" else "Normal")
		end
		if ownSeat then
			if seat ~= previousSeat then
				notice(
					(if drivenBoatId ~= "Rowboat" then "Steer" else "Row")
						.. " with movement controls (WASD / arrows). Jump to leave the boat."
				)
			end
			sinceInput += dt
			-- Presses, releases and direction reversals bypass the analog rate cap.
			-- Repeat held input so the server's input timeout never releases the helm.
			local throttle, steer = seat.ThrottleFloat, seat.SteerFloat
			local hull = boatModel.PrimaryPart
			if player:GetAttribute("BoatRefitOpen") and hull then
				-- The refit dock brakes the boat to a stop while its menu is open.
				local speed = hull.AssemblyLinearVelocity:Dot(hull.CFrame.LookVector)
				throttle, steer = if speed > 1 then -1 elseif speed < -1 then 1 else 0, 0
			end
			local changed = throttle ~= sentThrottle or steer ~= sentSteer
			local directionChanged = seat ~= previousSeat
				or (sentThrottle ~= nil and math.sign(throttle) ~= math.sign(sentThrottle))
				or (sentSteer ~= nil and math.sign(steer) ~= math.sign(sentSteer))
			if (changed and (directionChanged or sinceInput >= 1 / 30)) or sinceInput >= 0.1 then
				sinceInput = 0
				sentThrottle, sentSteer = throttle, steer
				request:FireServer("Row", throttle, steer)
			end
			previousSeat = seat
		else
			previousSeat, sinceInput = nil, 0
			sentThrottle, sentSteer = nil, nil
		end
		sinceShopCheck += dt
		if overlay.Visible and sinceShopCheck > 0.4 then
			sinceShopCheck = 0
			refresh()
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local nearby = false
			if dockBase then
				local prompt = dockBase:FindFirstChild("SpawnRowboatPrompt", true)
				nearby = dockBase:GetAttribute("OwnerUserId") == player.UserId
					and root ~= nil
					and prompt ~= nil
					and prompt.Parent:IsA("BasePart")
					and (root.Position - prompt.Parent.Position).Magnitude <= prompt.MaxActivationDistance + 2
			else
				for _, shop in CollectionService:GetTagged("BoatShop") do
					local prompt = shop:FindFirstChild("TalkToShipwrightPrompt", true)
					if root and prompt and prompt.Parent:IsA("BasePart") then
						nearby = nearby
							or (root.Position - prompt.Parent.Position).Magnitude
								<= prompt.MaxActivationDistance + 2
					end
				end
			end
			if not nearby then
				overlay.Visible = false
			end
		end
	end)
end

return Boating
