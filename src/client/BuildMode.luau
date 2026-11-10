-- Build mode: at home, press B (or the Build button) for an angled building view
-- with the roof hidden. On your company island it opens over the island's fenced
-- plot instead (site "Company"), where the island's kit and decorations go. Pan with WASD / arrows or right-drag, hold Q / E to turn,
-- and scroll to zoom.
-- Pick bought furniture from the bottom bar, turn it
-- with R and click a floor spot to place it; click placed furniture to move it or
-- pick it back up. Allowed rooms glow green while you hold an item. The preview
-- uses the shared placement rules, and the server re-checks every placement.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Furniture = require(ReplicatedStorage.Shared.FurnitureCatalog)
local BaseGrid = require(ReplicatedStorage.Shared.BaseGrid)
local Building = require(ReplicatedStorage.Shared.BuildingCatalog)
local FurniturePreview = require(script.Parent.FurniturePreview)
local StructureEditor = require(script.Parent.StructureEditor)
local Freecam = require(script.Parent.Freecam)
local KitchenStorage = require(script.Parent.KitchenStorage)
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))

local BuildMode = {}
local rgb = Color3.fromRGB
local FITS = rgb(84, 192, 92)
local BLOCKED = rgb(226, 72, 60)
local ROOM = rgb(96, 200, 120)
local HOME_DISTANCE = 110
local COMPANY_DISTANCE = 150
-- Everything above the doorway lintels: roof, gables, ceiling ties and pendant lamps.
local ROOF_HEIGHT = 8.4
local FLOOR_Y = 0.16
local HEIGHTS = {
	Freezer = 4,
	Register = 3,
	StorageRack = 6.6,
	FoodCase = 4.3,
	FoodShelf = 6.1,
	GrillStation = 7.6,
	Smoker = 8.1,
	SushiBar = 6.5,
	KitchenStorage = 4.3,
	DiningTable = 3.4,
	WeatherRadar = 4.4,
	CompanyPrep = 4.2,
	CompanyDesk = 4.7,
	PrepBench = 4.2,
	OfficeDesk = 4.8,
}
-- The furniture cards: everything sold, then the company island kit and the
-- house's own fixtures (shown once picked up).
local ITEMS = table.clone(Furniture.Order)
table.move(Furniture.KitOrder, 1, #Furniture.KitOrder, #ITEMS + 1, ITEMS)
table.move(Furniture.FixtureOrder, 1, #Furniture.FixtureOrder, #ITEMS + 1, ITEMS)
local CAMERA_PITCH = math.rad(55)
local TURN_SPEED = math.rad(90)
local TURN_RESPONSE = 12
local TURN_KEYS = {
	[Enum.KeyCode.Q] = -1,
	[Enum.KeyCode.E] = 1,
}
local PAN_LIMIT = Vector2.new(38, 100)
local PAN_KEYS = {
	[Enum.KeyCode.W] = Vector2.new(0, -1),
	[Enum.KeyCode.Up] = Vector2.new(0, -1),
	[Enum.KeyCode.S] = Vector2.new(0, 1),
	[Enum.KeyCode.Down] = Vector2.new(0, 1),
	[Enum.KeyCode.A] = Vector2.new(-1, 0),
	[Enum.KeyCode.Left] = Vector2.new(-1, 0),
	[Enum.KeyCode.D] = Vector2.new(1, 0),
	[Enum.KeyCode.Right] = Vector2.new(1, 0),
}
local started = false

local function make(class: string, parent: Instance?, props: { [string]: any }): any
	local item = Instance.new(class)
	for key, value in props do
		item[key] = value
	end
	item.Parent = parent
	return item
end

local function notice(message: string)
	pcall(StarterGui.SetCore, StarterGui, "SendNotification", {
		Title = "Build mode",
		Text = message,
		Duration = 4,
	})
end

function BuildMode.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Furniture")
	local request = remotes:WaitForChild("Request") :: RemoteFunction
	local update = remotes:WaitForChild("Update") :: RemoteEvent

	local state = nil
	local active = false
	local house: Model? = nil -- the base house, or the company island on its plot
	local houseFrame = CFrame.identity
	local site: string? = nil -- nil at home, "Company" on the island plot
	local floorY = FLOOR_Y
	local hidden: { [BasePart]: number } = {}
	local roofConnection: RBXScriptConnection? = nil
	local frozen = nil
	local held = nil -- { ItemId, From (item id or placed index), R }
	local selected: number? = nil
	local editingRack = false
	local spot = nil -- { X, Z, Reason }
	local pending = false
	local saved = nil
	local preview: Model? = nil
	local highlight: Highlight? = nil
	local grid: Folder? = nil
	local pan = Vector2.zero
	local zoom = 1
	local cameraDistance = 60
	local panKeys = {}
	local turnKeys = {}
	local yaw, turnVelocity = 0, 0
	local dragging = false
	local dragPosition: Vector2? = nil
	local touch: InputObject? = nil
	local touchStart = Vector2.zero
	local touchDragged = false
	local structures = nil
	local ghostParts = {}

	-- HUD, laid out like Restaurant Tycoon 3: StructureEditor owns the bottom dock
	-- (tools on the left, category tabs and catalogue on the right) and the status bar.
	-- Furniture fills the dock's catalogue on its Furniture tab; the actions for the
	-- selected item float beside it; camera buttons and Done sit top-right.
	local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), {
		Name = "BuildMode",
		ResetOnSpawn = false,
		DisplayOrder = 24,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local toggle = make("TextButton", gui, {
		Name = "OpenBuildMode",
		Text = "Build [B]",
		TextSize = 16,
		Position = UDim2.new(1, -126, 1, -146),
		Size = UDim2.fromOffset(112, 38),
		Visible = false,
	})
	Theme.button(toggle)
	local onStructureMode, onStructureSelect
	structures = StructureEditor.new({
		Gui = gui,
		Notice = notice,
		OnModeChanged = function(...)
			if onStructureMode then onStructureMode(...) end
		end,
		OnSelect = function()
			if onStructureSelect then onStructureSelect() end
		end,
	})
	local MENU = StructureEditor.Colors
	local DOCK_TOP = StructureEditor.DOCK_HEIGHT + StructureEditor.DOCK_MARGIN
	local panel = structures.dock
	local furniturePane = make("Frame", structures.body, {
		Name = "FurnitureCatalogue",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	})
	local function label(parent: Instance, text: string, props: { [string]: any }): TextLabel
		local item = make("TextLabel", parent, {
			BackgroundTransparency = 1,
			Text = text,
			TextSize = 14,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		StructureEditor.styleLabel(item)
		for key, value in props do
			if key == "TextColor3" and value == Theme.Colors.Muted then value = MENU.Muted end
			item[key] = value
		end
		return item
	end
	local function button(parent: Instance, text: string, props: { [string]: any }): TextButton
		local item = make("TextButton", parent, { Text = text, TextSize = 14 })
		for key, value in props do
			item[key] = value
		end
		StructureEditor.styleButton(item)
		return item
	end
	local function horizontalStrip(parent: Instance, name: string, y: number, height: number): ScrollingFrame
		local strip = make("ScrollingFrame", parent, {
			Name = name,
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, height),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromOffset(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			ScrollingDirection = Enum.ScrollingDirection.X,
			Active = true,
		})
		Theme.scroll(strip)
		strip.ScrollBarThickness = 3
		strip.ScrollBarImageColor3 = MENU.Muted
		make("UIListLayout", strip, {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		})
		return strip
	end
	-- The status line lives in the top-left bar (StructureEditor:setHint).
	local hint = { Text = "" }
	-- Catalogue chips: All plus every group you own unplaced stock in.
	local categoryStrip = horizontalStrip(furniturePane, "FurnitureCategories", 0, 24)
	local catalogue = horizontalStrip(furniturePane, "Placeables", 28, 70)
	local category = "All"
	local categoryButtons = {}
	for index, entry in Furniture.Categories do
		local chip = button(categoryStrip, entry.Name, {
			Name = "Category" .. entry.Id,
			LayoutOrder = index,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 22),
			TextSize = 11,
		})
		make("UIPadding", chip, { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) })
		categoryButtons[entry.Id] = chip
	end
	local inventoryTitle = categoryButtons.All
	local itemButtons = {}
	local stockLabels = {}
	local itemViews, previewStarted = {}, {}
	for index, id in ITEMS do
		local card = button(catalogue, "", {
			Name = "Hold" .. id,
			LayoutOrder = index,
			Size = UDim2.fromOffset(112, 66),
			Visible = false,
		})
		itemButtons[id] = card
		local view = make("ViewportFrame", card, {
			Name = "FurnitureThumbnail",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(4, 2),
			Size = UDim2.fromOffset(104, 38),
			Active = false,
			ZIndex = 2,
		})
		itemViews[id] = view
		label(card, Furniture.Items[id].Name, {
			Position = UDim2.fromOffset(6, 40),
			Size = UDim2.new(1, -12, 0, 13),
			TextSize = 11,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 3,
		})
		stockLabels[id] = label(card, "", {
			Position = UDim2.fromOffset(6, 52),
			Size = UDim2.new(1, -12, 0, 12),
			TextSize = 10,
			ZIndex = 3,
			TextColor3 = Theme.Colors.Muted,
		})
	end
	local emptyInventory = label(furniturePane, "Loading your furniture…", {
		Name = "EmptyInventory",
		Position = UDim2.fromOffset(4, 30),
		Size = UDim2.new(1, -8, 0, 60),
		TextSize = 13,
		TextColor3 = Theme.Colors.Muted,
	})
	-- Floating actions for the selected or held furniture.
	local actions = make("Frame", gui, {
		Name = "FurnitureActions",
		Active = true,
		AnchorPoint = Vector2.new(0.5, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		Visible = false,
	})
	StructureEditor.stylePanel(actions)
	make("UIPadding", actions, {
		PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 5), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5),
	})
	make("UIListLayout", actions, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 5),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	local selectionName = label(actions, "", {
		Name = "SelectionName",
		LayoutOrder = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		TextSize = 12,
		TextWrapped = false,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	local rotate = button(actions, "Rotate [R]", {
		Name = "Rotate",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(92, 30),
		TextSize = 12,
	})
	local move = button(actions, "Move", {
		Name = "MoveSelected",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(64, 30),
		TextSize = 12,
	})
	local pickUp = button(actions, "Pick up", {
		Name = "PickUpSelected",
		LayoutOrder = 4,
		Size = UDim2.fromOffset(72, 30),
		TextSize = 12,
	})
	local editRack = button(actions, "Edit rack", { Name = "EditRack", LayoutOrder = 2, Size = UDim2.fromOffset(96, 30), TextSize = 12 })
	local cancel = button(actions, "Cancel [X]", {
		Name = "Cancel",
		LayoutOrder = 5,
		Size = UDim2.fromOffset(88, 30),
		TextSize = 12,
	})
	local rackEditor = make("Frame", gui, {
		Name = "RackEditor", Active = true, AnchorPoint = Vector2.new(1, 1),
		-- Sits just above the right end of the dock.
		Position = UDim2.new(1, -12, 1, -(DOCK_TOP + 12)), Size = UDim2.new(1, -24, 0, 164), Visible = false,
	})
	make("UISizeConstraint", rackEditor, { MaxSize = Vector2.new(400, 164) })
	StructureEditor.stylePanel(rackEditor)
	label(rackEditor, "Edit storage rack", { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 24), TextSize = 16 })
	local rackStatus = label(rackEditor, "", { Position = UDim2.fromOffset(12, 35), Size = UDim2.new(1, -24, 0, 28), TextSize = 12, TextColor3 = Theme.Colors.Muted })
	local rackMode = button(rackEditor, "Mode: Fish", { Name = "RackMode", Position = UDim2.fromOffset(12, 66), Size = UDim2.new(1, -24, 0, 32) })
	local addCage = button(rackEditor, "+ Cage", { Name = "RackAddCage", Position = UDim2.new(0, 12, 0, 108), Size = UDim2.new(0.25, -15, 0, 36), TextSize = 12 })
	local takeCage = button(rackEditor, "− Cage", { Name = "RackTakeCage", Position = UDim2.new(0.25, 4, 0, 108), Size = UDim2.new(0.25, -15, 0, 36), TextSize = 12 })
	local addNet = button(rackEditor, "+ Net", { Name = "RackAddNet", Position = UDim2.new(0.5, -4, 0, 108), Size = UDim2.new(0.25, -15, 0, 36), TextSize = 12 })
	local takeNet = button(rackEditor, "− Net", { Name = "RackTakeNet", Position = UDim2.new(0.75, -12, 0, 108), Size = UDim2.new(0.25, -15, 0, 36), TextSize = 12 })
	-- Top-right: help, camera and Done.
	local navigation = make("Frame", gui, {
		Name = "BuildNavigation",
		Active = true,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(296, 48),
		Visible = false,
	})
	StructureEditor.stylePanel(navigation)
	make("UIPadding", navigation, { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) })
	make("UIListLayout", navigation, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
	})
	local helpToggle = button(navigation, "?", {
		Name = "BuildHelpToggle",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(34, 34),
		TextSize = 16,
	})
	local zoomOut = button(navigation, "−", {
		Name = "ZoomOut",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(34, 34),
		TextSize = 18,
	})
	local zoomIn = button(navigation, "+", {
		Name = "ZoomIn",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(34, 34),
		TextSize = 18,
	})
	local recenter = button(navigation, "Home", {
		Name = "RecenterView",
		LayoutOrder = 4,
		Size = UDim2.fromOffset(60, 34),
		TextSize = 12,
	})
	local done = button(navigation, "Done [B]", {
		Name = "ExitBuildMode",
		LayoutOrder = 5,
		Size = UDim2.fromOffset(96, 34),
	})
	done.BackgroundColor3, done.TextColor3 = MENU.Red, MENU.White
	local helpPanel = make("Frame", gui, {
		Name = "BuildHelp",
		Active = true,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 66),
		Size = UDim2.fromOffset(296, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
	})
	StructureEditor.stylePanel(helpPanel)
	make("UIPadding", helpPanel, {
		PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
	})
	label(
		helpPanel,
		if UserInputService.TouchEnabled
			then "Drag: pan the camera\nTap: select or place\n− / +: zoom · Home: recenter"
			else "WASD / arrows or right-drag: pan\nQ / E: turn · Wheel: zoom · Home: recenter\nR: rotate · M: move · Del: delete · X / Esc: cancel\nG: grid size · Page Up / Down: floor\nCtrl+Z / Ctrl+Y: undo / redo · B: done",
		{
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = 12,
		}
	)

	local function ownHouse(): (Model?, CFrame?)
		for _, base in CollectionService:GetTagged("PlayerBase") do
			if base:GetAttribute("OwnerUserId") == player.UserId then
				local model = base:FindFirstChild("BaseHouse")
				local frame = model and model:GetAttribute("HouseFrame")
				if model and model:IsA("Model") and typeof(frame) == "CFrame" then
					return model, frame
				end
			end
		end
		return nil, nil
	end
	-- The site build mode would open on here: (model, frame, site), nearest plot first.
	local function currentSite(): (Model?, CFrame?, string?)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			return nil, nil, nil
		end
		for _, island in CollectionService:GetTagged("CompanyIsland") do
			local frame = island:GetAttribute("PlotFrame")
			if
				island:IsA("Model")
				and island:GetAttribute("OwnerUserId") == player.UserId
				and typeof(frame) == "CFrame"
				and (root.Position - frame.Position).Magnitude <= COMPANY_DISTANCE
			then
				return island, frame, "Company"
			end
		end
		local model, frame = ownHouse()
		if model and frame and (root.Position - frame.Position).Magnitude <= HOME_DISTANCE then
			return model, frame, nil
		end
		return nil, nil, nil
	end
	local function atHome(): boolean
		local model = currentSite()
		return model ~= nil
	end
	-- Placed furniture on the open site.
	local function placed()
		if not state then
			return {}
		end
		return (if site == "Company" then state.CompanyPlaced else state.Placed) or {}
	end
	local function furnitureFolder(): Instance?
		return house and house:FindFirstChild(if site == "Company" then "PlotFurniture" else "Furniture")
	end

	local function setButton(item: TextButton, text: string, enabled: boolean, chosen: boolean?)
		item.Text = text
		item.Active = enabled
		item.Selectable = enabled
		StructureEditor.styleButton(item, if chosen then "Selected" elseif enabled then "Normal" else "Disabled")
	end
	local function render()
		local total = 0
		local counts = {}
		for _, id in ITEMS do
			local stock = if state and Furniture.allowedOn(id, site) then state.Stock[id] or 0 else 0
			if stock > 0 then
				local group = Furniture.category(id)
				counts[group] = (counts[group] or 0) + stock
			end
		end
		if category ~= "All" and not counts[category] then category = "All" end
		for _, id in ITEMS do
			local item = Furniture.Items[id]
			local stock = if state and Furniture.allowedOn(id, site) then state.Stock[id] or 0 else 0
			local full = state ~= nil and Furniture.count(placed(), id) >= item.MaxPlaced
			total += stock
			itemButtons[id].Visible = stock > 0 and Furniture.matchesCategory(id, category)
			itemButtons[id].Selectable = stock > 0 and not full and not pending
			stockLabels[id].Text = string.format("%d unplaced", stock)
			if stock > 0 and not previewStarted[id] then
				previewStarted[id] = true
				FurniturePreview.show(itemViews[id], remotes, id)
			end
			setButton(itemButtons[id], "", stock > 0 and not full and not pending, held ~= nil and held.From == id)
		end
		inventoryTitle.Text = string.format("All · %d", total)
		for _, entry in Furniture.Categories do
			local chip = categoryButtons[entry.Id]
			local count = if entry.Id == "All" then total else counts[entry.Id] or 0
			chip.Visible = entry.Id == "All" or count > 0
			setButton(chip, string.format("%s · %d", entry.Name, count), true, category == entry.Id)
		end
		emptyInventory.Visible = total == 0
		emptyInventory.Text = if not state
			then "Loading your furniture…"
			elseif site == "Company"
			then "Nothing to place here. Racks, kitchen storage, the radar and decorations from Harbour Home can go on your plot."
			else "No unplaced furniture. Buy items at Harbour Home, or pick up furniture in your house."
		local rack = selected and placed()[selected]
		local choosing = rack ~= nil and held == nil
		setButton(rotate, "Rotate [R]", held ~= nil or (choosing and not pending))
		setButton(cancel, "Cancel [X]", held ~= nil or selected ~= nil)
		move.Visible, pickUp.Visible = choosing, choosing
		setButton(move, "Move", choosing and not pending)
		-- The last freezer, till and the office desk can only be moved (AnglerData.pickUpFurniture).
		local keep = rack and Furniture.Items[rack.ItemId] and Furniture.Items[rack.ItemId].Keep
		local kept = keep ~= nil and Furniture.count(placed(), rack.ItemId) <= 1
		setButton(pickUp, "Pick up", choosing and not pending and not kept)
		local shown = if held then Furniture.Items[held.ItemId] elseif rack then Furniture.Items[rack.ItemId] else nil
		selectionName.Text = if shown then (if held then "Placing " .. string.lower(shown.Name) else shown.Name) else ""
		local isRack = rack and rack.ItemId == "StorageRack" and held == nil
		local isKitchen = rack and rack.ItemId == "KitchenStorage" and held == nil
		editRack.Visible = not not (isRack or isKitchen)
		setButton(editRack, if isKitchen then "Edit storage" elseif editingRack then "Close editor" else "Edit rack", not pending)
		rackEditor.Visible = active and not not isRack and editingRack
		rackStatus.Text = if isRack and rack.Mode == "Tools"
			then string.format("Stored: %d cages, %d nets / 12 · Carrying: %d cages, %d nets", rack.Cages or 0, rack.Nets or 0, state.CageStock or 0, state.NetStock or 0)
			else "Fish storage · Switch mode to store cages and nets."
		setButton(rackMode, if isRack and rack.Mode == "Tools" then "Mode: Tools" else "Mode: Fish", not pending)
		for _, item in { addCage, takeCage, addNet, takeNet } do
			item.Visible = not not (isRack and rack.Mode == "Tools")
			setButton(item, item.Text, not pending)
		end
		if held then
			local item = Furniture.Items[held.ItemId]
			hint.Text = if spot and spot.Reason
				then spot.Reason
				else string.format("Place your %s: %s.", string.lower(item.Name), if site == "Company" then "inside the plot's fence" else Furniture.roomNames(held.ItemId))
		elseif selected and placed()[selected] then
			local entry = placed()[selected]
			if entry.ItemId == "StorageRack" then
				hint.Text = if entry.Mode == "Tools" then string.format("Tools rack: %d cages, %d nets / 12. Carrying: %d cages, %d nets. Level 4 porters place stored tools.", entry.Cages or 0, entry.Nets or 0, state.CageStock or 0, state.NetStock or 0) else "Storage rack selected. Click Edit rack to choose its mode."
			elseif entry.ItemId == "KitchenStorage" then
				hint.Text = "Kitchen storage selected. Click Edit storage to choose which fish wait on the ice."
			else
				local item = Furniture.Items[entry.ItemId]
				hint.Text = if item.Keep and Furniture.count(placed(), entry.ItemId) <= 1
					then item.Name .. " selected. You can move it; " .. string.lower(string.sub(item.Keep, 1, 1)) .. string.sub(item.Keep, 2)
					else item.Name .. " selected. Move it or pick it up."
			end
		elseif state and state.PendingWallMigration then
			hint.Text = "Some furniture needs room near the new walls. Move or pick up furniture to make space."
		elseif site == "Company" then
			hint.Text = "Furnish your company plot from the catalogue. Click anything placed to move, rotate or remove it."
		else
			hint.Text = "Pick furniture from the catalogue. Click anything placed to move, rotate or remove it."
		end
		if structures then structures:setHint(hint.Text) end
	end

	local function clearPreview()
		ghostParts = {}
		if preview then
			preview:Destroy()
			preview = nil
		end
	end
	local function setHighlight(model: Instance?)
		if highlight then
			highlight:Destroy()
			highlight = nil
		end
		if model then
			highlight = make("Highlight", model, {
				FillColor = rgb(240, 200, 90),
				FillTransparency = 0.6,
				OutlineColor = rgb(255, 230, 150),
			})
		end
	end
	local function placedModel(index: number): Model?
		local entry = placed()[index]
		local folder = furnitureFolder()
		if not entry or not folder then
			return nil
		end
		for _, model in folder:GetChildren() do
			if
				model:GetAttribute("ItemId") == entry.ItemId
				and model:GetAttribute("X") == entry.X
				and model:GetAttribute("Z") == entry.Z
				and model:GetAttribute("R") == entry.R
			then
				return model
			end
		end
		return nil
	end
	local function choose(index: number?)
		if selected ~= index then editingRack = false end
		selected = index
		-- One selection at a time: furniture or a building piece.
		if index and structures then structures:clearSelection() end
		setHighlight(if index then placedModel(index) else nil)
		render()
	end

	-- Local-only parts: the held item's ghost and the rooms it may go in.
	local function plate(parent: Instance, area: { number }, y: number, color: Color3, transparency: number): Part
		return make("Part", parent, {
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Material = Enum.Material.SmoothPlastic,
			Color = color,
			Transparency = transparency,
			Size = Vector3.new(area[3] - area[1], 0.08, area[4] - area[2]),
			CFrame = houseFrame * CFrame.new((area[1] + area[3]) / 2, y, (area[2] + area[4]) / 2),
		})
	end
	local function buildPreview()
		clearPreview()
		if not held then
			return
		end
		local model = make("Model", nil, { Name = "FurniturePreview" })
		local item = Furniture.Items[held.ItemId]
		-- Yard items sit on the quay deck, a step below the house floor.
		local floor = Furniture.floor(held.ItemId, site)
		if site == "Company" then
			plate(model, Furniture.PLOT, floor + 0.05, ROOM, 0.75).Name = "AllowedRoom"
			for _, area in Furniture.PlotBlocked do
				plate(model, area, floor + 0.07, BLOCKED, 0.8).Name = "KeepClear"
			end
		end
		for _, roomId in if site == "Company" then {} else Furniture.allowedRooms(held.ItemId) do
			local room = Furniture.Rooms[roomId]
			plate(model, room, floor + 0.05, ROOM, 0.75).Name = "AllowedRoom"
			for _, area in Furniture.blocked(held.ItemId) do
				-- Only show keep-clear zones in the allowed rooms.
				if area[1] < room[3] and area[3] > room[1] and area[2] < room[4] and area[4] > room[2] then
					plate(model, area, floor + 0.07, BLOCKED, 0.8).Name = "KeepClear"
				end
			end
		end
		local height = HEIGHTS[held.ItemId] or 3
		local ghost = FurniturePreview.clone(remotes, held.ItemId)
		if ghost then
			ghost.Name = "ItemGhost"
			ghost:SetAttribute("TemplatePivot", ghost:GetPivot())
			for _, part in ghost:GetDescendants() do
				if part:IsA("BasePart") then
					table.insert(ghostParts, { Part = part, Color = part.Color })
					part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
					part.Transparency = math.max(0.3, part.Transparency)
				elseif part:IsA("ProximityPrompt") or part:IsA("LayerCollector") or part:IsA("Light") or part:IsA("ParticleEmitter")
					or part:IsA("Beam") or part:IsA("Trail") then
					part.Enabled = false
				end
			end
			ghost.Parent = model
			make("Highlight", model, {
				Name = "GhostOutline", Adornee = ghost, FillTransparency = 0.94, OutlineTransparency = 0,
				DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
			})
		else
			-- The authoritative templates may still be arriving on a fresh join.
			make("Part", model, {
				Name = "Body", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
				Material = Enum.Material.SmoothPlastic, Transparency = 0.7, Size = Vector3.new(item.Width, height, item.Depth),
			})
		end
		-- The grid cells the item fills, and the strips people stand in beside them.
		make("Part", model, {
			Name = "Access",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.6,
			Size = Vector3.new(1, 0.1, 1),
		})
		for index = 1, #Furniture.access(held.ItemId, 0, 0, 0) do
			make("Part", model, {
				Name = "Clearance" .. index,
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
				Material = Enum.Material.SmoothPlastic,
				Transparency = 0.85,
				Size = Vector3.new(1, 0.06, 1),
			})
		end
		-- An arrow on the access side shows which way the item faces.
		make("Part", model, {
			Name = "FacingArrow",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Material = Enum.Material.Neon,
			Color = rgb(250, 240, 200),
			Size = Vector3.new(0.5, 0.12, math.max(item.Front, 1) * 0.8),
		})
		for _, side in { -1, 1 } do
			make("Part", model, {
				Name = if side == -1 then "FacingLeft" else "FacingRight", Anchored = true, CanCollide = false,
				CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon,
				Color = rgb(250, 240, 200), Size = Vector3.new(0.16, 0.12, 0.8),
			})
		end
		model.Parent = workspace
		preview = model
	end
	local function updatePreview()
		if not preview or not held or not spot then
			return
		end
		local item = Furniture.Items[held.ItemId]
		local frame = Furniture.frame(houseFrame, { ItemId = held.ItemId, X = spot.X, Z = spot.Z, R = held.R }, site)
		local color = if spot.Reason then BLOCKED else FITS
		local height = HEIGHTS[held.ItemId] or 3
		local body = preview:FindFirstChild("Body") :: BasePart?
		local ghost = preview:FindFirstChild("ItemGhost") :: Model?
		local access = preview:FindFirstChild("Access") :: BasePart
		local arrow = preview:FindFirstChild("FacingArrow") :: BasePart
		access.Color = color
		if body then
			body.Color = color
			body.CFrame = frame * CFrame.new(0, height / 2, 0)
		end
		if ghost then
			ghost:PivotTo(frame * ghost:GetAttribute("TemplatePivot"))
			for _, entry in ghostParts do entry.Part.Color = entry.Color:Lerp(color, 0.18) end
			local outline = preview:FindFirstChild("GhostOutline") :: Highlight
			outline.OutlineColor, outline.FillColor = color, color
		end
		local floor = Furniture.floor(held.ItemId, site)
		local function lay(part: BasePart, area: { number }, y: number)
			part.Size = Vector3.new(area[3] - area[1] - 0.1, part.Size.Y, area[4] - area[2] - 0.1)
			part.CFrame = houseFrame * CFrame.new((area[1] + area[3]) / 2, floor + y, (area[2] + area[4]) / 2)
		end
		lay(access, Furniture.footprint(held.ItemId, spot.X, spot.Z, held.R) :: { number }, 0.12)
		for index, strip in Furniture.access(held.ItemId, spot.X, spot.Z, held.R) do
			local clearance = preview:FindFirstChild("Clearance" .. index) :: BasePart?
			if clearance then
				clearance.Color = color
				lay(clearance, strip, 0.1)
			end
		end
		local arrowZ = item.Depth / 2 + 0.85
		arrow.Size = Vector3.new(0.16, 0.12, 1.25)
		arrow.CFrame = frame * CFrame.new(0, 0.22, arrowZ)
		for _, side in { -1, 1 } do
			local wing = preview:FindFirstChild(if side == -1 then "FacingLeft" else "FacingRight") :: BasePart
			wing.CFrame = frame * CFrame.new(side * 0.24, 0.22, arrowZ + 0.35) * CFrame.Angles(0, side * math.rad(45), 0)
		end
	end

	-- ScreenPointToRay expects coordinates below the top bar, like InputObject.Position.
	-- GetMouseLocation includes that inset; normalize it for previews and clicks alike.
	local function mousePosition(): Vector2
		return UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
	end

	-- Intersect the pointer with the floor, also used for drag-to-pan at any zoom.
	local function pointerFloor(position: Vector2): Vector3?
		local camera = workspace.CurrentCamera
		if not camera then
			return nil
		end
		local ray = camera:ScreenPointToRay(position.X, position.Y)
		local elevation = if structures and structures:isActive() then structures:elevation() else 0
		local pointerY = if structures and structures:isActive()
			then Building.planeHeight(site, elevation / Building.LEVEL_HEIGHT) else floorY
		local floor = houseFrame * CFrame.new(0, pointerY, 0)
		local normal = houseFrame.UpVector
		local denominator = ray.Direction:Dot(normal)
		if math.abs(denominator) < 1e-4 then
			return nil
		end
		local t = (floor.Position - ray.Origin):Dot(normal) / denominator
		if t < 0 then
			return nil
		end
		return houseFrame:PointToObjectSpace(ray.Origin + ray.Direction * t)
	end
	local function pointerSpot(position: Vector2)
		local point = pointerFloor(position)
		if not point then
			return nil
		end
		if held then
			-- Snap the middle of the item's cells to the pointer, so a 1x2 item
			-- covers the two cells nearest it rather than hanging off one end.
			local area = Furniture.footprint(held.ItemId, 0, 0, held.R) :: { number }
			return BaseGrid.snap(point.X - (area[1] + area[3]) / 2), BaseGrid.snap(point.Z - (area[2] + area[4]) / 2)
		end
		return BaseGrid.snap(point.X), BaseGrid.snap(point.Z)
	end
	local function aim(position: Vector2)
		if not held or not state then
			return
		end
		local x, z = pointerSpot(position)
		if not x then
			return
		end
		local skip = if type(held.From) == "number" then held.From else nil
		local reason = Furniture.check(placed(), held.ItemId, x, z, held.R, skip, site)
		if spot and spot.X == x and spot.Z == z and spot.R == held.R and spot.Reason == reason then return end
		spot = { X = x, Z = z, R = held.R, Reason = reason }
		updatePreview()
		render()
	end

	local function hold(itemId: string, from: any, r: number)
		held = { ItemId = itemId, From = from, R = r }
		spot = nil
		buildPreview()
		aim(mousePosition())
		render()
	end
	local function drop()
		held, spot = nil, nil
		clearPreview()
		render()
	end
	-- Stop holding furniture and give the Select tool back to the structure editor.
	local function release()
		drop()
		choose(nil)
		if structures then structures:resume() end
	end
	-- The placed furniture under the pointer, if any.
	local function furnitureAt(position: Vector2): number?
		local camera = workspace.CurrentCamera
		local folder = furnitureFolder()
		if not camera or not folder or not state then
			return nil
		end
		local ray = camera:ScreenPointToRay(position.X, position.Y)
		local parameters = RaycastParams.new()
		parameters.FilterType = Enum.RaycastFilterType.Include
		parameters.FilterDescendantsInstances = { folder }
		local reach = (ray.Origin - houseFrame.Position).Magnitude + 80
		local hit = workspace:Raycast(ray.Origin, ray.Direction * reach, parameters)
		local model = hit and hit.Instance
		while model and model.Parent ~= folder do
			model = model.Parent
		end
		if not model then
			return nil
		end
		for index, entry in placed() do
			if
				model:GetAttribute("ItemId") == entry.ItemId
				and model:GetAttribute("X") == entry.X
				and model:GetAttribute("Z") == entry.Z
				and model:GetAttribute("R") == entry.R
			then
				return index
			end
		end
		return nil
	end

	local function send(action: string, ...): boolean
		pending = true
		render()
		local ok, result = pcall(request.InvokeServer, request, action, ...)
		pending = false
		if ok and type(result) == "table" then
			state = result.State or state
			if not result.Ok and result.Message ~= "" then
				notice(result.Message)
			end
			render()
			return result.Ok == true
		end
		notice("Your furniture couldn't be saved. Try again.")
		render()
		return false
	end
	-- Turn placed furniture a quarter in place, like the catalogue preview's R.
	local function rotateSelected()
		local entry = selected and placed()[selected]
		if not entry or pending then
			return
		end
		local index, r = selected, (entry.R + 1) % 4
		local reason = Furniture.check(placed(), entry.ItemId, entry.X, entry.Z, r, index, site)
		if reason then
			notice(reason)
			return
		end
		if send("Move", index, entry.X, entry.Z, r, site) then
			choose(if placed()[index] then index else nil)
		end
	end
	local function pickUpFurniture(index: number)
		if not pending and send("PickUp", index, site) then
			choose(nil)
		end
	end

	local function placeHeld()
		if not held or not spot or pending then
			return
		end
		if spot.Reason then
			notice(spot.Reason)
			return
		end
		local action = if type(held.From) == "number" then "Move" else "Place"
		if send(action, held.From, spot.X, spot.Z, held.R, site) then
			release()
		end
	end

	local function clickFurniture(position: Vector2)
		choose(furnitureAt(position))
	end

	local function hideRoofPart(part: Instance)
		if not house or not part:IsA("BasePart") then
			return
		end
		local folder = house:FindFirstChild("Furniture")
		if folder and part:IsDescendantOf(folder) then
			return
		end
		if site == "Company" then
			local construction = house:FindFirstChild("BuildingPieces")
			if not construction or not part:IsDescendantOf(construction) then return end
		end
		if houseFrame:PointToObjectSpace(part.Position).Y > ROOF_HEIGHT then
			if hidden[part] == nil then
				hidden[part] = part.LocalTransparencyModifier
			end
			part.LocalTransparencyModifier = 1
		end
	end
	local function hideRoof()
		if not house or (structures and structures:roofVisible()) then
			return
		end
		-- On an island only constructed overhead pieces need hiding.
		if site == "Company" and not house:FindFirstChild("BuildingPieces") then
			return
		end
		if not roofConnection then
			local watched = house
			roofConnection = house.DescendantAdded:Connect(function(part)
				-- Streamed parts can arrive before their frame; the periodic pass also
				-- catches late properties and reapplies hiding after replication updates.
				task.defer(function()
					if active and house == watched and part:IsDescendantOf(watched) then
						hideRoofPart(part)
					end
				end)
			end)
		end
		for _, part in house:GetDescendants() do
			hideRoofPart(part)
		end
	end
	local function showRoof()
		if roofConnection then
			roofConnection:Disconnect()
			roofConnection = nil
		end
		for part, modifier in hidden do
			if part.Parent then
				part.LocalTransparencyModifier = modifier
			end
		end
		hidden = {}
	end
	local function showGrid()
		local folder = make("Folder", workspace, { Name = "BuildGrid" })
		grid = folder
		if structures and structures:isActive() and structures:section() ~= "Furniture" then
			local size = structures:gridSize()
			local offset = Building.gridOffset(site)
			local elevation = Building.planeHeight(site, structures:elevation() / Building.LEVEL_HEIGHT)
			local function line(x: number, z: number, width: number, depth: number)
				make("Part", folder, {
					Name = "ConstructionGrid", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
					CastShadow = false, Size = Vector3.new(width, 0.025, depth),
					CFrame = houseFrame * CFrame.new(x, elevation, z),
					Color = rgb(184, 150, 222), Material = Enum.Material.SmoothPlastic, Transparency = 0.35,
				})
			end
			for _, area in Building.Bounds[site or "Home"] do
				for column = math.ceil((area[1] - offset) / size), math.floor((area[3] - offset) / size) do
					line(column * size + offset, (area[2] + area[4]) / 2, 0.035, area[4] - area[2])
				end
				for row = math.ceil((area[2] - offset) / size), math.floor((area[4] - offset) / size) do
					line((area[1] + area[3]) / 2, row * size + offset, area[3] - area[1], 0.035)
				end
			end
			return
		end
		if site == "Company" then
			-- Cell boundaries sit halfway between the snap points, clipped to the plot.
			local area, half = Furniture.PLOT, BaseGrid.CELL_SIZE / 2
			for x = area[1] + half, area[3], BaseGrid.CELL_SIZE do
				plate(folder, { x - 0.02, area[2], x + 0.02, area[4] }, floorY + 0.13, rgb(235, 245, 255), 0.3)
			end
			for z = area[2] + half, area[4], BaseGrid.CELL_SIZE do
				plate(folder, { area[1], z - 0.02, area[3], z + 0.02 }, floorY + 0.13, rgb(235, 245, 255), 0.3)
			end
			return
		end
		-- Draw the cell boundaries, not the centers used to snap furniture.
		local halfWidth, halfLength = BaseGrid.HALF_WIDTH, BaseGrid.HALF_LENGTH
		for column = 0, BaseGrid.COLUMNS do
			local x = -halfWidth + column * BaseGrid.CELL_SIZE
			plate(folder, { x - 0.012, -halfLength, x + 0.012, halfLength }, FLOOR_Y + 0.13, rgb(235, 245, 255), 0.3)
		end
		for row = 0, BaseGrid.ROWS do
			local z = -halfLength + row * BaseGrid.CELL_SIZE
			plate(folder, { -halfWidth, z - 0.012, halfWidth, z + 0.012 }, FLOOR_Y + 0.13, rgb(235, 245, 255), 0.3)
		end
		-- Project the same grid onto the actual walking surfaces outside. Include
		-- only structural floors, ramps and decks: furniture, boats and roofs do
		-- not turn into grid surfaces, and gaps between piers remain empty.
		local base = house and house.Parent
		if not base then return end
		local surfaces = {}
		local surfaceNames = {
			DiningFloor = true, RearLanding = true, RearStep = true,
			EntranceStep = true, FrontApproachStep = true,
			-- The shop building across the street.
			ShopFloor = true, ShopEntranceStep = true, ShopForecourt = true,
		}
		for _, part in base:GetDescendants() do
			if part:IsA("BasePart") and part.CanQuery and (
				surfaceNames[part.Name]
				or (part.Name == "DeckSurface" and part.Parent and (part.Parent.Name == "Dock" or part.Parent.Name == "DockLink"))
				or ((part.Name == "DockRamp" or part.Name == "QuayLanding") and part:FindFirstAncestor("DockAccess"))
				or (part.Parent == base and part.Size.X >= 45 and part.Size.Z >= 40)
				or (part.Name == "Step" and part.Parent and part.Parent.Name == "BeachStairs")
			) then
				table.insert(surfaces, part)
			end
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = surfaces
		params.RespectCanCollide = true
		local up = houseFrame.UpVector
		local samples = {}
		local function sample(x: number, z: number): Vector3?
			local key = string.format("%.3f:%.3f", x, z)
			if samples[key] ~= nil then return samples[key] or nil end
			local origin = houseFrame:PointToWorldSpace(Vector3.new(x, 0.8, z))
			local hit = workspace:Raycast(origin, up * -8, params)
			if hit and hit.Normal:Dot(up) >= 0.7 and hit.Material ~= Enum.Material.Water then
				local point = hit.Position + up * 0.13
				samples[key] = point
				return point
			end
			samples[key] = false
			return nil
		end
		local function line(x1: number, z1: number, x2: number, z2: number, depth: number)
			-- The house already has its own uninterrupted overlay. Five samples
			-- also prevent a line from spanning water or a sudden height change.
			local mx, mz = (x1 + x2) / 2, (z1 + z2) / 2
			if math.abs(mx) < halfWidth and math.abs(mz) < halfLength then return end
			local points, count = {}, 0
			for index = 0, 4 do
				local t = index / 4
				local point = sample(x1 + (x2 - x1) * t, z1 + (z2 - z1) * t)
				points[index + 1] = point
				if point then count += 1 end
			end
			if count == 0 then return end
			local first, last = points[1], points[5]
			local continuous = count == 5
			if continuous then
				for index = 2, 4 do
					if (points[index] - first:Lerp(last, (index - 1) / 4)).Magnitude > 0.15 then
						continuous = false
						break
					end
				end
			end
			if not continuous then
				-- Clip edges and steps to smaller pieces, instead of connecting a
				-- line across a water gap or floating it above a stair tread.
				if depth < 3 then
					line(x1, z1, mx, mz, depth + 1)
					line(mx, mz, x2, z2, depth + 1)
				end
				return
			end
			local length = (last - first).Magnitude
			if length < 0.01 then return end
			make("Part", folder, {
				Name = "GroundGridLine", Anchored = true, CanCollide = false,
				CanQuery = false, CanTouch = false, CastShadow = false,
				Material = Enum.Material.SmoothPlastic, Color = rgb(235, 245, 255), Transparency = 0.3,
				Size = Vector3.new(0.024, 0.08, length),
				CFrame = CFrame.lookAt((first + last) / 2, last, up),
			})
		end
		local size = BaseGrid.CELL_SIZE
		for column = BaseGrid.BASE_MIN_COLUMN, BaseGrid.BASE_MAX_COLUMN + 1 do
			local x = -halfWidth + (column - 1) * size
			for row = BaseGrid.BASE_MIN_ROW, BaseGrid.BASE_MAX_ROW do
				local z = -halfLength + (row - 1) * size
				line(x, z, x, z + size, 0)
			end
		end
		for row = BaseGrid.BASE_MIN_ROW, BaseGrid.BASE_MAX_ROW + 1 do
			local z = -halfLength + (row - 1) * size
			for column = BaseGrid.BASE_MIN_COLUMN, BaseGrid.BASE_MAX_COLUMN do
				local x = -halfWidth + (column - 1) * size
				line(x, z, x + size, z, 0)
			end
		end
	end

	local function panBy(delta: Vector2)
		local limit = if site == "Company" then Vector2.new(60, 40) else PAN_LIMIT
		pan = Vector2.new(
			math.clamp(pan.X + delta.X, -limit.X, limit.X),
			math.clamp(pan.Y + delta.Y, -limit.Y, limit.Y)
		)
	end
	local function dragView(from: Vector2, to: Vector2)
		local first, last = pointerFloor(from), pointerFloor(to)
		if first and last then
			panBy(Vector2.new(first.X - last.X, first.Z - last.Z))
		end
	end
	local function changeZoom(steps: number)
		zoom = math.clamp(zoom * 0.85 ^ steps, 0.45, 2.5)
	end
	local function clearNavigation()
		table.clear(panKeys)
		table.clear(turnKeys)
		turnVelocity = 0
		dragging, dragPosition, touch = false, nil, nil
		touchDragged = false
	end
	local function cameraInput(_, inputState: Enum.UserInputState, input: InputObject)
		if inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			panKeys[input.KeyCode] = nil
			turnKeys[input.KeyCode] = nil
		elseif inputState == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
			panKeys[input.KeyCode] = PAN_KEYS[input.KeyCode]
			turnKeys[input.KeyCode] = TURN_KEYS[input.KeyCode]
		end
		-- Consume movement and jumping before Roblox can move the character.
		return if UserInputService:GetFocusedTextBox()
			then Enum.ContextActionResult.Pass
			else Enum.ContextActionResult.Sink
	end

	local function freezeCharacter(): boolean
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
			return false
		end
		if humanoid.SeatPart then
			notice("Leave your seat before entering build mode.")
			return false
		end
		frozen = { Root = root, Anchored = root.Anchored, Humanoid = humanoid, AutoRotate = humanoid.AutoRotate }
		humanoid:Move(Vector3.zero)
		humanoid.AutoRotate = false
		root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
		root.Anchored = true
		return true
	end
	local function releaseCharacter()
		if not frozen then
			return
		end
		if frozen.Root.Parent then
			frozen.Root.Anchored = frozen.Anchored
		end
		if frozen.Humanoid.Parent then
			frozen.Humanoid.AutoRotate = frozen.AutoRotate
		end
		frozen = nil
	end

	local function controls(enabled: boolean)
		pcall(function()
			local scripts = player:FindFirstChild("PlayerScripts")
			local playerModule = scripts and scripts:FindFirstChild("PlayerModule")
			if not playerModule or not playerModule:IsA("ModuleScript") then
				return
			end
			local module = require(playerModule)
			local playerControls = module:GetControls()
			if enabled then
				playerControls:Enable()
			else
				playerControls:Disable()
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid:Move(Vector3.zero)
				end
			end
		end)
	end

	local hotbarBefore: boolean? = nil
	local function hideHotbar()
		if hotbarBefore == nil then
			local ok, enabled = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack)
			hotbarBefore = if ok then enabled else true
		end
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)
	end
	local function restoreHotbar()
		if hotbarBefore ~= nil then
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, hotbarBefore)
			hotbarBefore = nil
		end
	end

	-- Every frame: outline furniture under the Select / Delete tools (and keep the
	-- structure tools from reacting through it), and float the furniture actions
	-- above the selected item, or centred above the dock while placing.
	local hoverModel: Model? = nil
	local hoverHighlight: Highlight? = nil
	local function placeActions()
		local position = if touch then Vector2.new(touch.Position.X, touch.Position.Y) else mousePosition()
		local tool = structures and structures:tool()
		local over = nil
		if active and not held and structures and structures:isActive() and (tool == "Select" or tool == "Remove") then
			local index = furnitureAt(position)
			over = if index then placedModel(index) else nil
		end
		if structures then structures:block(over ~= nil) end
		if over ~= hoverModel or (hoverHighlight and not hoverHighlight.Parent) then
			if hoverHighlight then
				hoverHighlight:Destroy()
				hoverHighlight = nil
			end
			hoverModel = over
			if over and not (highlight and highlight.Parent == over) then
				hoverHighlight = make("Highlight", over, {
					Name = "FurnitureHover",
					FillColor = if tool == "Remove" then BLOCKED else MENU.Blue,
					FillTransparency = 0.88,
					OutlineColor = if tool == "Remove" then BLOCKED else MENU.White,
					DepthMode = Enum.HighlightDepthMode.Occluded,
				})
			end
		end
		actions.Visible = active and (held ~= nil or (selected ~= nil and placed()[selected] ~= nil))
		if not actions.Visible then
			return
		end
		local camera = workspace.CurrentCamera
		local floor = panel.AbsolutePosition.Y - 10
		local model = if not held and selected then placedModel(selected) else nil
		local point = nil
		if model and camera then
			local box, size = model:GetBoundingBox()
			local screen, visible = camera:WorldToScreenPoint(box.Position + houseFrame.UpVector * (size.Y / 2 + 0.5))
			if visible then
				point = Vector2.new(screen.X, screen.Y)
			end
		end
		if point then
			local size = actions.AbsoluteSize
			local half = size.X / 2
			local width = gui.AbsoluteSize.X
			actions.Position = UDim2.fromOffset(
				math.clamp(point.X, half + 8, math.max(half + 8, width - half - 8)),
				math.clamp(point.Y - 8, size.Y + 72, math.max(size.Y + 72, floor))
			)
		else
			actions.Position = UDim2.new(0.5, 0, 0, floor)
		end
	end

	local function updateCamera(dt: number?)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 50
		camera.FieldOfViewMode = Enum.FieldOfViewMode.Vertical
		local viewport = camera.ViewportSize
		if viewport.X <= 0 or viewport.Y <= 0 then
			return
		end
		local inset = GuiService:GetGuiInset()
		local top = navigation.AbsolutePosition.Y + navigation.AbsoluteSize.Y + inset.Y + 12
		local bottom = panel.AbsolutePosition.Y + inset.Y - 12
		local focal = viewport.Y / (2 * math.tan(math.rad(camera.FieldOfView / 2)))
		local halfArea = math.max(1, bottom - top) / (2 * focal)
		local upper, lower = (viewport.Y / 2 - top) / focal, (viewport.Y / 2 - bottom) / focal
		local step = math.clamp(dt or 0, 0, 0.1)
		if not UserInputService:GetFocusedTextBox() then
			local turn = 0
			for _, direction in turnKeys do
				turn += direction
			end
			local targetVelocity = turn * TURN_SPEED
			local blend = 1 - math.exp(-TURN_RESPONSE * step)
			-- Integrate the eased speed so turning feels the same at different frame rates.
			yaw = (yaw + targetVelocity * step + (turnVelocity - targetVelocity) * blend / TURN_RESPONSE)
				% (2 * math.pi)
			turnVelocity += (targetVelocity - turnVelocity) * blend
		end
		local sinYaw, cosYaw = math.sin(yaw), math.cos(yaw)
		local back =
			Vector3.new(sinYaw * math.cos(CAMERA_PITCH), math.sin(CAMERA_PITCH), cosYaw * math.cos(CAMERA_PITCH))
		local orientation = CFrame.lookAt(Vector3.zero, -back)
		-- Fit the floor AND room walls in the viewport between the two toolbars.
		-- Perspective depth matters here: the near corners need more room.
		local distance = 18
		local fitHeight = if structures and structures:isActive() and structures:section() ~= "Furniture" then 18 else ROOF_HEIGHT
		local fitX, fitZ = if site == "Company" then 34 else 26, if site == "Company" then 24 else 18
		for _, x in { -fitX, fitX } do
			for _, z in { -fitZ, fitZ } do
				for _, y in { 0, fitHeight } do
					local point = orientation:PointToObjectSpace(Vector3.new(x, y, z))
					distance = math.max(
						distance,
						math.abs(point.X) * focal / (viewport.X / 2 - 12) + point.Z,
						(point.Y + upper * point.Z) / halfArea,
						(-point.Y - lower * point.Z) / halfArea
					)
				end
			end
		end
		cameraDistance = math.max(18, distance * zoom)
		if not UserInputService:GetFocusedTextBox() then
			local direction = Vector2.zero
			for _, axis in panKeys do
				direction += axis
			end
			if direction.Magnitude > 0 then
				local axis = direction.Unit
				local floorDirection =
					Vector2.new(axis.X * cosYaw + axis.Y * sinYaw, -axis.X * sinYaw + axis.Y * cosYaw)
				panBy(floorDirection * math.min(cameraDistance, 100) * 0.45 * step)
			end
		end
		local elevation = if structures and structures:isActive() then structures:elevation() else 0
		local center = houseFrame * Vector3.new(pan.X, floorY + elevation, pan.Y)
		local worldOrientation = houseFrame * orientation
		local shift = ((top + bottom) / 2 - viewport.Y / 2) * cameraDistance / focal
		local target = center + worldOrientation.UpVector * shift
		camera.CFrame =
			CFrame.lookAt(target + houseFrame:VectorToWorldSpace(back) * cameraDistance, target, houseFrame.UpVector)
		camera.Focus = CFrame.new(center)
		-- A stationary pointer must still track its floor tile as the camera moves.
		if held then
			aim(if touch then Vector2.new(touch.Position.X, touch.Position.Y) else mousePosition())
		end
		if structures then
			structures:step(if touch then Vector2.new(touch.Position.X, touch.Position.Y) else mousePosition())
		end
		if placeActions then
			placeActions()
		end
	end

	local exit
	local function enter()
		if active or not atHome() then
			if not active then
				notice("Go home to your base, or to your company island's plot, to use build mode.")
			end
			return
		end
		local model, frame, where = currentSite()
		local camera = workspace.CurrentCamera
		if not camera or not model or not frame then
			return
		end
		if not freezeCharacter() then
			return
		end
		Freecam.stop()
		active, house, houseFrame, site = true, model, frame, where
		floorY = if where == "Company" then 0 else FLOOR_Y
		clearNavigation()
		pan, zoom, yaw = Vector2.zero, 1, 0
		saved = {
			Type = camera.CameraType,
			FieldOfView = camera.FieldOfView,
			FieldOfViewMode = camera.FieldOfViewMode,
			Frame = camera.CFrame,
			Focus = camera.Focus,
		}
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 50
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		controls(false)
		hideHotbar()
		ContextActionService:BindActionAtPriority(
			"FurnitureBuildMovement",
			cameraInput,
			false,
			Enum.ContextActionPriority.High.Value + 1,
			Enum.KeyCode.W,
			Enum.KeyCode.A,
			Enum.KeyCode.S,
			Enum.KeyCode.D,
			Enum.KeyCode.Up,
			Enum.KeyCode.Down,
			Enum.KeyCode.Left,
			Enum.KeyCode.Right,
			Enum.KeyCode.Q,
			Enum.KeyCode.E,
			Enum.KeyCode.Space
		)
		for key, axis in PAN_KEYS do
			if UserInputService:IsKeyDown(key) then
				panKeys[key] = axis
			end
		end
		for key, direction in TURN_KEYS do
			if UserInputService:IsKeyDown(key) then
				turnKeys[key] = direction
			end
		end
		hideRoof()
		showGrid()
		panel.Visible, navigation.Visible, toggle.Visible = true, true, false
		structures:enter(model, frame, where)
		player:SetAttribute("BuildModeOpen", true)
		updateCamera()
		RunService:BindToRenderStep("FurnitureBuildCamera", Enum.RenderPriority.Camera.Value + 1, updateCamera)
		render()
		task.spawn(function()
			local ok, result = pcall(request.InvokeServer, request, "Get")
			if ok and type(result) == "table" and result.State then
				state = result.State
				render()
			end
		end)
	end
	function exit()
		if not active then
			return
		end
		active = false
		structures:exit()
		clearNavigation()
		ContextActionService:UnbindAction("FurnitureBuildMovement")
		drop()
		choose(nil)
		RunService:UnbindFromRenderStep("FurnitureBuildCamera")
		showRoof()
		if grid then
			grid:Destroy()
			grid = nil
		end
		local camera = workspace.CurrentCamera
		if saved and camera then
			camera.CameraType = saved.Type
			camera.FieldOfViewMode = saved.FieldOfViewMode
			camera.FieldOfView = saved.FieldOfView
			camera.CFrame = saved.Frame
			camera.Focus = saved.Focus
		end
		-- Never restore a snapshot of the pointer: a lock or hidden icon captured on entry
		-- can outlive whatever set it and strand the cursor. The camera re-locks if it needs to.
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		releaseCharacter()
		controls(true)
		restoreHotbar()
		panel.Visible, navigation.Visible, helpPanel.Visible, actions.Visible = false, false, false, false
		if hoverHighlight then
			hoverHighlight:Destroy()
			hoverHighlight, hoverModel = nil, nil
		end
		player:SetAttribute("BuildModeOpen", false)
	end
	-- Tab and tool changes from the dock. Switching tabs drops anything held; picking
	-- a placement or paint tool clears the furniture selection.
	local furnitureSection = "Furniture"
	onStructureMode = function(enabled, section, tool)
		local changed = section ~= furnitureSection
		furnitureSection = section
		if changed or (enabled and held) then
			drop()
		end
		if changed or (tool ~= nil and tool ~= "Select") then
			choose(nil)
			editingRack, rackEditor.Visible = false, false
		end
		furniturePane.Visible = section == "Furniture"
		if structures and structures:roofVisible() then showRoof() else hideRoof() end
		if active and structures then
			if grid then grid:Destroy(); grid = nil end
			showGrid()
		end
	end
	onStructureSelect = function()
		choose(nil)
	end
	for id, item in itemButtons do
		item.Activated:Connect(function()
			if active and item.Active then
				choose(nil)
				structures:suspend()
				hold(id, id, if held then held.R else 0)
			end
		end)
	end
	for id, chip in categoryButtons do
		chip.Activated:Connect(function()
			category = id
			catalogue.CanvasPosition = Vector2.zero
			render()
		end)
	end
	rotate.Activated:Connect(function()
		if held then
			held.R = (held.R + 1) % 4
			aim(mousePosition())
		else
			rotateSelected()
		end
	end)
	cancel.Activated:Connect(release)
	move.Activated:Connect(function()
		local entry = selected and placed()[selected]
		if entry and not pending then
			structures:suspend()
			hold(entry.ItemId, selected, entry.R)
		end
	end)
	pickUp.Activated:Connect(function()
		if selected then pickUpFurniture(selected) end
	end)
	helpToggle.Activated:Connect(function()
		helpPanel.Visible = not helpPanel.Visible
		setButton(helpToggle, "?", true, helpPanel.Visible)
	end)
	editRack.Activated:Connect(function()
		if selected and not pending then
			local entry = placed()[selected]
			if entry and entry.ItemId == "KitchenStorage" then
				KitchenStorage.open()
				return
			end
			editingRack = not editingRack
			render()
		end
	end)
	for item, action in { [rackMode] = "Mode", [addCage] = "AddCage", [takeCage] = "TakeCage", [addNet] = "AddNet", [takeNet] = "TakeNet" } do
		item.Activated:Connect(function()
			if selected and not pending then send("EditRack", selected, action, site) end
		end)
	end
	done.Activated:Connect(exit)
	toggle.Activated:Connect(enter)
	zoomIn.Activated:Connect(function()
		changeZoom(1)
	end)
	zoomOut.Activated:Connect(function()
		changeZoom(-1)
	end)
	recenter.Activated:Connect(function()
		pan, zoom, yaw, turnVelocity = Vector2.zero, 1, 0, 0
	end)
	UserInputService.WindowFocusReleased:Connect(clearNavigation)
	UserInputService.TextBoxFocused:Connect(clearNavigation)
	GuiService.MenuOpened:Connect(clearNavigation)

	local function clickWorld(position: Vector2)
		if held then
			aim(position)
			placeHeld()
		elseif structures and structures:isActive() then
			-- Select and Delete work on furniture and building pieces alike.
			local tool = structures:tool()
			if tool == "Select" or tool == "Remove" then
				local index = furnitureAt(position)
				if index then
					if tool == "Remove" then pickUpFurniture(index) else choose(index) end
					return
				end
				choose(nil)
			end
			structures:click(position)
		else
			clickFurniture(position)
		end
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.B then
			if active then
				exit()
			else
				enter()
			end
		elseif not active then
			return
		elseif (input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.Escape) and (held or selected) then
			-- Cancel furniture first; the structure tools also clear their own state.
			release()
			if structures then structures:key(input) end
		elseif input.KeyCode == Enum.KeyCode.R and held then
			held.R = (held.R + 1) % 4
			aim(mousePosition())
		elseif input.KeyCode == Enum.KeyCode.R and selected and placed()[selected] then
			rotateSelected()
		elseif input.KeyCode == Enum.KeyCode.M and selected and placed()[selected] and not held and not pending then
			local entry = placed()[selected]
			structures:suspend()
			hold(entry.ItemId, selected, entry.R)
		elseif input.KeyCode == Enum.KeyCode.Delete and selected and placed()[selected] and not held then
			pickUpFurniture(selected)
		elseif structures and structures:key(input) then
			return
		elseif input.KeyCode == Enum.KeyCode.X then
			drop()
			choose(nil)
		elseif input.KeyCode == Enum.KeyCode.Home then
			pan, zoom, yaw, turnVelocity = Vector2.zero, 1, 0, 0
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			dragging = true
			dragPosition = mousePosition()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			clickWorld(mousePosition())
		elseif input.UserInputType == Enum.UserInputType.Touch and not touch then
			touch = input
			touchStart = Vector2.new(input.Position.X, input.Position.Y)
			dragPosition, touchDragged = touchStart, false
		end
	end)
	UserInputService.InputChanged:Connect(function(input, processed)
		if not active then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
			changeZoom(input.Position.Z)
		elseif dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local position = mousePosition()
			if dragPosition then
				dragView(dragPosition, position)
			end
			dragPosition = position
		elseif input == touch then
			local position = Vector2.new(input.Position.X, input.Position.Y)
			if (position - touchStart).Magnitude > 8 then
				touchDragged = true
			end
			if touchDragged and dragPosition then
				dragView(dragPosition, position)
			end
			dragPosition = position
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			dragging, dragPosition = false, nil
		elseif input == touch then
			if active and not touchDragged and input.UserInputState ~= Enum.UserInputState.Cancel then
				clickWorld(Vector2.new(input.Position.X, input.Position.Y))
			end
			touch, dragPosition = nil, nil
			touchDragged = false
		end
	end)
	update.OnClientEvent:Connect(function(kind, payload)
		if kind == "State" and type(payload) == "table" then
			state = payload
			if selected then
				choose(if placed()[selected] then selected else nil)
			end
			render()
		end
	end)
	-- Respawning or leaving home ends build mode; the toggle shows only at home.
	player.CharacterAdded:Connect(exit)
	player.CharacterRemoving:Connect(exit)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local home = atHome()
			toggle.Visible = home and not active
			if active then
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if not home or not humanoid or humanoid.Health <= 0 then
					exit()
				else
					hideHotbar()
					hideRoof()
					-- Furniture rebuilt by the server since the last check keeps its highlight.
					if selected and highlight and not highlight.Parent then
						setHighlight(placedModel(selected))
					end
				end
			end
		end
	end)
end

return BuildMode
