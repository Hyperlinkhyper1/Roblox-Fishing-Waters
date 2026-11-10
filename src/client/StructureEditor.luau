-- Structural tools share BuildMode's camera and pointer handling. The client only
-- draws previews; BuildingService prices, validates and saves every operation.
--
-- Layout (in the spirit of Restaurant Tycoon 3): one dock along the bottom with the
-- editing tools on its left and the category tabs + catalogue on its right, a slim
-- status bar top-left, and the actions for whatever is selected floating next to it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Catalog = require(ReplicatedStorage.Shared.BuildingCatalog)
local Renderer = require(ReplicatedStorage.Shared.BuildingRenderer)
local PaintQueue = require(script.Parent.BuildPaintQueue)
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))

local StructureEditor = {}
local CATEGORIES = { "Wall", "Room", "Door", "Window", "Floor", "Roof" }
-- One tab row: what you place. Furniture's catalogue is filled in by BuildMode.
local TABS = { "Furniture", "Wall", "Room", "Floor", "Door", "Window", "Roof", "Paint" }
local TAB_NAMES = {
	Furniture = "Furniture", Wall = "Walls", Room = "Rooms", Door = "Doors", Window = "Windows",
	Floor = "Floors", Roof = "Roofs", Paint = "Paint",
}
local MENU = {
	Paper = Color3.fromRGB(18, 18, 20), Button = Color3.fromRGB(35, 36, 39), White = Color3.fromRGB(248, 248, 248),
	Blue = Color3.fromRGB(47, 153, 225), BlueBorder = Color3.fromRGB(30, 121, 187),
	Ink = Color3.fromRGB(233, 234, 237), Border = Color3.fromRGB(73, 75, 81),
	Muted = Color3.fromRGB(146, 149, 157), Red = Color3.fromRGB(229, 88, 88),
}
StructureEditor.Colors = MENU
StructureEditor.DOCK_HEIGHT = 156
StructureEditor.DOCK_MARGIN = 12

local function make(class: string, parent: Instance, properties): any
	local item = Instance.new(class)
	for key, value in properties do item[key] = value end
	item.Parent = parent
	return item
end

local function border(item)
	local stroke = item:FindFirstChild("MenuBorder")
	if not stroke then
		stroke = make("UIStroke", item, { Name = "MenuBorder", Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	end
	return stroke
end

function StructureEditor.styleLabel(item, color)
	Theme.text(item, color or MENU.Ink)
	item.TextStrokeTransparency = 1
end

function StructureEditor.stylePanel(item)
	item.BackgroundColor3, item.BackgroundTransparency, item.BorderSizePixel = MENU.Paper, 0, 0
	Theme.corner(item, 6)
	border(item).Color = MENU.Border
end

function StructureEditor.styleButton(item, state)
	local chosen, disabled = state == "Selected", state == "Disabled"
	item.BackgroundColor3 = if chosen then MENU.Blue else MENU.Button
	item.BackgroundTransparency, item.BorderSizePixel = 0, 0
	item.TextColor3 = if chosen then MENU.White elseif disabled then MENU.Muted else MENU.Ink
	item.TextStrokeTransparency, item.Font = 1, Enum.Font.GothamBold
	Theme.corner(item, 4)
	border(item).Color = if chosen then MENU.BlueBorder else MENU.Border
	local caption = item:FindFirstChild("CategoryCaption")
	if caption then caption.TextColor3 = item.TextColor3 end
	for _, child in item:GetChildren() do
		if child:IsA("TextLabel") then child.TextColor3 = item.TextColor3 end
	end
	local icon = item:FindFirstChild("CategoryIcon")
	if icon then
		for _, piece in icon:GetDescendants() do
			if piece:IsA("Frame") then piece.BackgroundColor3 = item.TextColor3 end
		end
	end
end

-- Small 18x18 glyphs drawn from frames, recoloured by styleButton.
function StructureEditor.icon(parent, kind, position)
	local icon = make("Frame", parent, {
		Name = "CategoryIcon", BackgroundTransparency = 1, Position = position or UDim2.fromOffset(9, 6),
		Size = UDim2.fromOffset(18, 18),
	})
	local function block(x, y, width, height, rotation)
		make("Frame", icon, { BackgroundColor3 = MENU.Ink, BorderSizePixel = 0,
			Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, height), Rotation = rotation or 0 })
	end
	if kind == "Wall" then
		for row = 0, 2 do
			block(0, row * 6, if row == 1 then 5 else 8, 4)
			block(if row == 1 then 7 else 10, row * 6, if row == 1 then 11 else 8, 4)
		end
	elseif kind == "Door" then
		block(3, 0, 12, 2); block(3, 0, 2, 18); block(13, 0, 2, 18); block(7, 3, 4, 15)
	elseif kind == "Window" then
		block(0, 0, 18, 2); block(0, 16, 18, 2); block(0, 0, 2, 18); block(16, 0, 2, 18)
		block(8, 0, 2, 18); block(0, 8, 18, 2)
	elseif kind == "Roof" then
		block(0, 6, 11, 3, -35); block(8, 6, 11, 3, 35); block(4, 11, 10, 7)
	elseif kind == "Floor" then
		for row = 0, 2 do for column = 0, 2 do block(column * 6, row * 6, 5, 5) end end
	elseif kind == "Furniture" then -- a chair
		block(3, 0, 3, 18); block(3, 9, 12, 3); block(12, 9, 3, 9)
	elseif kind == "Paint" then -- a roller
		block(1, 1, 14, 5); block(15, 3, 2, 7); block(8, 8, 9, 2); block(8, 8, 2, 10)
	elseif kind == "Select" then -- a selection marquee
		block(0, 0, 6, 2); block(0, 0, 2, 6); block(12, 0, 6, 2); block(16, 0, 2, 6)
		block(0, 16, 6, 2); block(0, 12, 2, 6); block(12, 16, 6, 2); block(16, 12, 2, 6); block(7, 7, 4, 4)
	elseif kind == "Remove" then -- a bin
		block(2, 3, 14, 2); block(6, 0, 6, 2); block(4, 6, 2, 12); block(8, 6, 2, 12); block(12, 6, 2, 12); block(4, 16, 10, 2)
	elseif kind == "Undo" then
		block(3, 7, 14, 3); block(1.5, 4, 7, 3, -45); block(1.5, 10, 7, 3, 45)
	elseif kind == "Redo" then
		block(1, 7, 14, 3); block(9.5, 4, 7, 3, 45); block(9.5, 10, 7, 3, -45)
	else -- Room
		block(0, 0, 18, 3); block(0, 15, 18, 3); block(0, 0, 3, 18); block(15, 0, 3, 18)
	end
	return icon
end

local function copy(entry)
	local result = table.clone(entry)
	if type(entry.Color) == "table" then result.Color = table.clone(entry.Color) end
	return result
end
local function deep(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[key] = deep(child) end
	return result
end

function StructureEditor.new(options)
	local self = {}
	local opened, enabled, pending = false, false, false
	local house, frame, site = nil, CFrame.identity, nil
	local state = nil
	local builtins = {}
	local entriesById = {}
	local tool, material = "Select", "Plaster"
	local section, lastBuildTool = "Furniture", "Wall"
	local color = { 178, 150, 117 }
	local styles = { Wall = "Solid", Floor = "Tile", Roof = "Gable", Window = "Classic", Door = "Open" }
	local rotation = 0
	local level, gridSize = 0, Catalog.GRID
	local selected, moving, reshaping = nil, nil, nil
	local selectedInstance = nil
	local anchor, candidate, invalidReason = nil, nil, nil
	local roomEntries = nil
	local preview, previewKey, highlight = nil, nil, nil
	local highlightedId = nil
	local hiddenHost = {}
	local previewFolder = make("Folder", workspace, { Name = "StructureEditorPreview" })
	local targets, targetRefresh = {}, 0
	local hovered, hoveredInstance, hoverPoint = nil, nil, nil
	local blocked = false
	local showRoofs = false
	local generation = 0
	local statusMessage = ""
	local furnitureHint = ""
	local remote, event
	local paintSession = nil
	local paintSessions = {}
	local accept

	local function label(parent, text, properties)
		local item = make("TextLabel", parent, {
			BackgroundTransparency = 1, Text = text, TextSize = 12, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
		})
		StructureEditor.styleLabel(item)
		for key, value in properties do item[key] = value end
		return item
	end
	local function button(parent, text, properties)
		local item = make("TextButton", parent, {
			Text = text, TextSize = 12, BackgroundColor3 = MENU.Button, BorderSizePixel = 0,
			TextColor3 = MENU.Ink, TextStrokeTransparency = 1, Font = Enum.Font.GothamBold,
		})
		for key, value in properties do item[key] = value end
		StructureEditor.styleButton(item)
		return item
	end
	local function strip(parent, name, y, height)
		local row = make("ScrollingFrame", parent, {
			Name = name, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, height),
			BackgroundTransparency = 1, CanvasSize = UDim2.fromOffset(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X,
			Active = true, BorderSizePixel = 0,
		})
		Theme.scroll(row)
		row.ScrollBarThickness = 3
		row.ScrollBarImageColor3 = MENU.Muted
		make("UIListLayout", row, {
			FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center,
		})
		return row
	end

	-- Bottom dock: tools | tabs + catalogue.
	local panel = make("Frame", options.Gui, {
		Name = "BuildDock", Active = true, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -StructureEditor.DOCK_MARGIN),
		Size = UDim2.new(1, -24, 0, StructureEditor.DOCK_HEIGHT), Visible = false,
	})
	make("UISizeConstraint", panel, { MaxSize = Vector2.new(1040, StructureEditor.DOCK_HEIGHT) })
	StructureEditor.stylePanel(panel)
	local toolGrid = make("Frame", panel, {
		Name = "EditingTools", BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(94, 140),
	})
	make("UIGridLayout", toolGrid, {
		CellSize = UDim2.fromOffset(44, 44), CellPadding = UDim2.fromOffset(6, 4), SortOrder = Enum.SortOrder.LayoutOrder,
	})
	make("Frame", panel, {
		Name = "ToolDivider", BackgroundColor3 = MENU.Border, BorderSizePixel = 0,
		Position = UDim2.fromOffset(112, 10), Size = UDim2.new(0, 1, 1, -20),
	})
	local tabs = make("Frame", panel, {
		Name = "BuildSections", BackgroundTransparency = 1, Position = UDim2.fromOffset(122, 8), Size = UDim2.new(1, -132, 0, 34),
	})
	make("UIListLayout", tabs, {
		FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5),
	})
	local body = make("Frame", panel, {
		Name = "DockBody", BackgroundTransparency = 1, Position = UDim2.fromOffset(122, 50),
		Size = UDim2.new(1, -132, 1, -58), ClipsDescendants = true,
	})
	self.dock, self.body = panel, body

	-- Top-left status bar: cash, floor and grid, and one line of guidance.
	local hud = make("Frame", options.Gui, {
		Name = "BuildHud", Active = true, Position = UDim2.fromOffset(12, 12), Size = UDim2.new(0.5, -24, 0, 62), Visible = false,
	})
	make("UISizeConstraint", hud, { MaxSize = Vector2.new(440, 62) })
	StructureEditor.stylePanel(hud)
	local cash = label(hud, "$—", {
		Name = "BuildCash", Position = UDim2.fromOffset(10, 6), Size = UDim2.fromOffset(104, 26), TextSize = 16,
		Font = Enum.Font.GothamBold, TextWrapped = false,
	})
	local levelBar = make("Frame", hud, {
		Name = "FloorControls", BackgroundTransparency = 1, Position = UDim2.fromOffset(116, 6), Size = UDim2.new(1, -124, 0, 26),
	})
	make("UIListLayout", levelBar, {
		FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	local downButton = button(levelBar, "−", { Name = "FloorDown", LayoutOrder = 1, Size = UDim2.fromOffset(26, 26), TextSize = 16 })
	local levelLabel = label(levelBar, "Floor 1", {
		Name = "FloorLevel", LayoutOrder = 2, Size = UDim2.fromOffset(54, 26), TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false,
	})
	local upButton = button(levelBar, "+", { Name = "FloorUp", LayoutOrder = 3, Size = UDim2.fromOffset(26, 26), TextSize = 16 })
	local gridButton = button(levelBar, "Grid 4.5 [G]", { Name = "GridSize", LayoutOrder = 4, Size = UDim2.fromOffset(98, 26), TextSize = 11 })
	local status = label(hud, "", {
		Name = "BuildStatus", Position = UDim2.fromOffset(10, 36), Size = UDim2.new(1, -20, 0, 20),
		TextSize = 11, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = MENU.Muted,
	})
	self.hud = hud

	-- Floating actions for the selected piece, or the piece being placed.
	local actionBar = make("Frame", options.Gui, {
		Name = "ConstructionActions", Active = true, AnchorPoint = Vector2.new(0.5, 1),
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 40), Visible = false,
	})
	StructureEditor.stylePanel(actionBar)
	make("UIPadding", actionBar, {
		PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 5), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5),
	})
	make("UIListLayout", actionBar, {
		FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	local actionTitle = label(actionBar, "", {
		Name = "SelectionName", LayoutOrder = 0, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 30),
		TextSize = 12, TextWrapped = false,
	})

	local tooltip = label(options.Gui, "", {
		Name = "ConstructionPreviewCost", Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(280, 52),
		Visible = false, BackgroundTransparency = 0.06, BackgroundColor3 = MENU.Paper,
		TextXAlignment = Enum.TextXAlignment.Center, TextSize = 13, ZIndex = 12,
	})
	Theme.corner(tooltip, 6)
	border(tooltip).Color = MENU.Border

	local toolButtons, tabButtons, materialButtons, colorButtons = {}, {}, {}, {}
	local variantCards = {}
	local function toolButton(name, caption, order)
		local item = button(toolGrid, "", { Name = "Tool" .. name, LayoutOrder = order })
		StructureEditor.icon(item, name, UDim2.new(0.5, -9, 0, 6))
		label(item, caption, {
			Name = "CategoryCaption", Position = UDim2.new(0, 0, 1, -17), Size = UDim2.new(1, 0, 0, 14),
			TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false,
		})
		return item
	end
	toolButtons.Select = toolButton("Select", "Select", 1)
	toolButtons.Paint = toolButton("Paint", "Paint", 2)
	toolButtons.Remove = toolButton("Remove", "Delete", 3)
	local undoButton = toolButton("Undo", "Undo", 4)
	undoButton.Name = "UndoBuilding"
	local redoButton = toolButton("Redo", "Redo", 5)
	redoButton.Name = "RedoBuilding"
	local roofsButton = toolButton("Roof", "Roof", 6)
	roofsButton.Name = "ToggleRoof"

	for index, name in TABS do
		local item = button(tabs, "", {
			Name = if name == "Furniture" then "FurnitureTab" elseif name == "Paint" then "DecorateTab" else "Tab" .. name,
			LayoutOrder = index, Size = UDim2.new(1 / #TABS, -5, 1, 0),
		})
		StructureEditor.icon(item, name, UDim2.new(0, 7, 0.5, -9))
		local caption = label(item, TAB_NAMES[name], {
			Name = "CategoryCaption", Position = UDim2.fromOffset(29, 0), Size = UDim2.new(1, -32, 1, 0),
			TextScaled = true, TextWrapped = false,
		})
		make("UITextSizeConstraint", caption, { MaxTextSize = 13, MinTextSize = 7 })
		tabButtons[name] = item
	end

	-- Construction catalogue: tiles with a live thumbnail, name and price.
	local variantStrip = strip(body, "StructureCatalogue", 0, 98)
	for _, kind in CATEGORIES do
		variantCards[kind] = {}
		for index, variant in Catalog.Variants[if kind == "Room" then "Wall" else kind] or {} do
			local card = button(variantStrip, "", {
				Name = "Variant" .. kind .. variant.Id, LayoutOrder = index, Size = UDim2.fromOffset(124, 90), Visible = false,
			})
			local view = make("ViewportFrame", card, {
				Name = "CatalogueThumbnail", BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 3),
				Size = UDim2.fromOffset(116, 56), Active = false,
			})
			label(card, if kind == "Room" then "Room" else variant.Name, {
				Position = UDim2.fromOffset(7, 60), Size = UDim2.new(1, -14, 0, 14), TextSize = 11,
				TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd,
			})
			label(card, string.format("$%d%s", if kind == "Room" then 54 else variant.Price or 0,
				if kind == "Wall" then " / 4.5" elseif kind == "Floor" or kind == "Roof" then " / tile" else ""), {
				Position = UDim2.fromOffset(7, 74), Size = UDim2.new(1, -14, 0, 13), TextSize = 10,
			})
			table.insert(variantCards[kind], { Button = card, View = view, Variant = variant, Started = false })
		end
	end

	-- Paint palette: materials, colours and the whole-house shortcut.
	local palette = make("Frame", body, { Name = "PaintPalette", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local materialStrip = strip(palette, "SurfaceMaterials", 0, 30)
	local colorStrip = strip(palette, "SurfaceColors", 34, 28)
	for index, name in Catalog.Materials do
		materialButtons[name] = button(materialStrip, name:gsub("(%l)(%u)", "%1 %2"), {
			Name = "Material" .. name, LayoutOrder = index, Size = UDim2.fromOffset(98, 26), TextSize = 11,
		})
	end
	for index, swatch in Catalog.Colors do
		local values = swatch.Color
		local item = make("TextButton", colorStrip, {
			Name = "Color" .. swatch.Name, Text = "", LayoutOrder = index,
			Size = UDim2.fromOffset(28, 23), BackgroundColor3 = Color3.fromRGB(values[1], values[2], values[3]),
			BorderSizePixel = 0, AutoButtonColor = true,
		})
		Theme.corner(item, 4)
		make("UIStroke", item, { Name = "SelectedColor", Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.75 })
		colorButtons[item] = swatch
	end
	local hex = make("TextBox", colorStrip, {
		Name = "CustomHexColor", LayoutOrder = 100, Size = UDim2.fromOffset(86, 23),
		Text = "#B29675", PlaceholderText = "#RRGGBB", ClearTextOnFocus = false,
		TextSize = 12, BackgroundColor3 = MENU.Button, BorderSizePixel = 0,
	})
	Theme.text(hex, MENU.Ink)
	hex.TextStrokeTransparency = 1
	Theme.corner(hex, 4)
	make("UIStroke", hex, { Color = MENU.Border, Thickness = 1 })
	local hexApply = button(colorStrip, "Set color", { LayoutOrder = 101, Size = UDim2.fromOffset(76, 23), TextSize = 11 })
	local paintAllButton = button(palette, "Paint all walls", {
		Name = "PaintAllWalls", Position = UDim2.fromOffset(0, 68), Size = UDim2.fromOffset(122, 26), TextSize = 11,
	})
	label(palette, "Click any wall, floor or roof to paint it with this finish.", {
		Name = "PaintHint", Position = UDim2.fromOffset(132, 68), Size = UDim2.new(1, -132, 0, 26), TextSize = 11,
		TextColor3 = MENU.Muted, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local styleButton = button(actionBar, "Rotate [R]", { Name = "RotateStructure", LayoutOrder = 1, Size = UDim2.fromOffset(100, 30) })
	local moveButton = button(actionBar, "Move", { Name = "MoveStructure", LayoutOrder = 2, Size = UDim2.fromOffset(64, 30) })
	local reshapeButton = button(actionBar, "Reshape", { Name = "ReshapeStructure", LayoutOrder = 3, Size = UDim2.fromOffset(78, 30) })
	local finishButton = button(actionBar, "Apply finish", { Name = "ApplyFinish", LayoutOrder = 4, Size = UDim2.fromOffset(96, 30) })
	local deleteButton = button(actionBar, "Delete", { Name = "DeleteStructure", LayoutOrder = 5, Size = UDim2.fromOffset(64, 30) })
	local cancelButton = button(actionBar, "Cancel [X]", { Name = "CancelStructure", LayoutOrder = 6, Size = UDim2.fromOffset(88, 30) })

	local function notify(message)
		statusMessage = message
		if options.Notice then options.Notice(message) end
	end
	local function clearPreview()
		for part, modifier in hiddenHost do if part.Parent then part.LocalTransparencyModifier = modifier end end
		hiddenHost = {}
		if preview then preview:Destroy(); preview = nil end
		previewKey, candidate, invalidReason, roomEntries = nil, nil, nil, nil
		tooltip.Visible = false
	end
	local function clearHighlight()
		if highlight then highlight:Destroy(); highlight = nil end
		highlightedId = nil
	end
	local function entryById(id)
		if not state or not id then return nil end
		return entriesById[id]
	end
	local function customSelection()
		if not selected or not state then return false end
		for _, entry in state.Pieces or {} do if entry.Id == selected then return true end end
		return false
	end
	-- Your own pieces move freely; original full-height walls convert on their first move.
	local function movableSelection()
		if customSelection() then return true end
		local entry = entryById(selected)
		return entry ~= nil and builtins[selected] ~= nil and Catalog.movableOriginal(entry)
	end
	local function setButton(item, active, chosen)
		item.Active, item.Selectable = active, active
		StructureEditor.styleButton(item, if chosen then "Selected" elseif active then "Normal" else "Disabled")
	end
	local function currentTab()
		return if section == "Furniture" then "Furniture" elseif section == "Decorate" then "Paint" else lastBuildTool
	end
	local function refresh()
		panel.Visible, hud.Visible = opened, opened
		local tab = currentTab()
		for name, item in tabButtons do setButton(item, not pending or name == tab, name == tab) end
		variantStrip.Visible = section == "Build"
		palette.Visible = section == "Decorate"
		for kind, cards in variantCards do
			for _, record in cards do
				record.Button.Visible = kind == lastBuildTool and section == "Build"
				setButton(record.Button, not pending, tool == kind and styles[if kind == "Room" then "Wall" else kind] == record.Variant.Style)
				if record.Button.Visible and not record.Started then
					record.Started = true
					Renderer.thumbnail(record.View, {
						Kind = if kind == "Room" then "Wall" else kind, Style = record.Variant.Style,
						Material = record.Variant.Material or (if kind == "Roof" then "RoofShingles" elseif kind == "Floor" then "WoodPlanks" elseif kind == "Window" or kind == "Door" then "Wood" else "Plaster"),
						Color = record.Variant.Color or { 212, 215, 219 }, Level = 0, R = 0,
						X1 = -4.5, Z1 = -4.5, X2 = 4.5, Z2 = 4.5,
					})
				end
			end
		end
		for name, item in toolButtons do setButton(item, not pending, tool == name and moving == nil and reshaping == nil) end
		for name, item in materialButtons do setButton(item, not pending, material == name) end
		for item, swatch in colorButtons do
			local values = swatch.Color
			local chosen = values[1] == color[1] and values[2] == color[2] and values[3] == color[3]
			item.SelectedColor.Transparency = if chosen then 0 else 0.75
		end
		local hasWalls = false
		for _, entry in entriesById do
			if entry.Kind == "Wall" then hasWalls = true; break end
		end
		setButton(paintAllButton, hasWalls and not pending)
		setButton(undoButton, state ~= nil and state.CanUndo == true and not pending)
		setButton(redoButton, state ~= nil and state.CanRedo == true and not pending)
		setButton(roofsButton, true, showRoofs)
		-- Floors and grid matter only while constructing.
		local building = section ~= "Furniture"
		downButton.Visible, levelLabel.Visible, upButton.Visible, gridButton.Visible = building, building, building, section == "Build"
		setButton(downButton, level > 0 and not pending)
		setButton(upButton, level < Catalog.MAX_LEVEL and not pending)
		levelLabel.Text = string.format("Floor %d", level + 1)
		gridButton.Text = string.format("Grid %g [G]", gridSize)
		cash.Text = if state and type(state.Cash) == "number" then "$" .. tostring(state.Cash) else "$—"

		-- Floating action bar.
		local selectedEntry = entryById(selected)
		local placing = tool ~= nil and table.find(CATEGORIES, tool) ~= nil
		local selecting = tool == "Select" and moving == nil and reshaping == nil and selectedEntry ~= nil
		actionBar.Visible = opened and enabled and (placing or selecting)
		local canMove = selecting and movableSelection()
		local kindName = selectedEntry and selectedEntry.Kind or ""
		actionTitle.Text = if moving then "Moving " .. string.lower(kindName ~= "" and kindName or tool)
			elseif reshaping then "Reshaping " .. string.lower(kindName ~= "" and kindName or tool)
			elseif selecting then (if builtins[selected] then "Original " .. string.lower(kindName) else kindName)
			elseif anchor then TAB_NAMES[tool] .. " · click to finish"
			elseif placing then TAB_NAMES[tool] else ""
		styleButton.Visible = placing
		styleButton.Text = string.format("Rotate %d° [R]", rotation * 90)
		moveButton.Visible = canMove
		reshapeButton.Visible = canMove and (kindName == "Wall" or (customSelection() and (kindName == "Floor" or kindName == "Roof")))
		finishButton.Visible = selecting
		deleteButton.Visible = selecting
		cancelButton.Visible = anchor ~= nil or moving ~= nil or reshaping ~= nil or selected ~= nil
		setButton(moveButton, canMove and not pending)
		setButton(reshapeButton, canMove and not pending)
		setButton(finishButton, selectedEntry ~= nil and not pending)
		setButton(deleteButton, selectedEntry ~= nil and not pending)
		deleteButton.TextColor3 = if deleteButton.Active then MENU.Red else MENU.Muted

		status.Text = if pending then "Saving…" elseif statusMessage ~= "" then statusMessage
			elseif section == "Furniture" then furnitureHint
			elseif tool == "Select" then "Click a wall, floor or roof to edit it. Original walls can be moved too."
			elseif tool == "Remove" then "Click anything to delete it. Undo brings it back."
			elseif tool == "Paint" then "Pick a material and colour, then click surfaces to paint them."
			elseif anchor then "Click again to finish. Right-drag pans the camera."
			elseif tool == "Door" or tool == "Window" then "Point at a wall and click to fit the opening."
			else "Click to start, click again to finish."
	end
	local function apply(reset)
		local value = opened and (section ~= "Furniture" or tool == "Select" or tool == "Remove")
		if reset or value ~= enabled then
			anchor, moving, reshaping, selected, selectedInstance = nil, nil, nil, nil, nil
			clearPreview(); clearHighlight()
		end
		enabled = value
		if options.OnModeChanged then options.OnModeChanged(enabled, section, tool) end
		refresh()
	end
	local function setSection(value)
		section = value
		if value == "Build" then tool = lastBuildTool
		elseif value == "Decorate" then tool = "Paint"
		else tool = "Select" end
		statusMessage, targetRefresh = "", 0
		apply(true)
	end
	local function targetIds(data, id)
		local entry = data and data.Builtins and data.Builtins[id]
		local group = entry and entry.Kind == "Roof" and id:match("^(b:.+)/[^/]+$")
		if not group then return { id } end
		local ids = {}
		for key, descriptor in data.Builtins do
			local removed = data.Overrides and data.Overrides[key] and data.Overrides[key].Removed
			if not removed and descriptor.Kind == "Roof" and key:match("^(b:.+)/[^/]+$") == group then table.insert(ids, key) end
		end
		table.sort(ids)
		return ids
	end
	local function sourceEntry(data, id)
		if not data then return nil end
		for _, entry in data.Pieces or {} do if entry.Id == id then return entry end end
		local original = data.Builtins and data.Builtins[id]
		if not original then return nil end
		local override = data.Overrides and data.Overrides[id]
		if override and override.Removed then return nil end
		return { Material = (override and override.Material) or original.Material, Color = (override and override.Color) or original.Color }
	end
	local replayPaint
	local function scheduleReplay(session)
		if session.ReplayQueued or session.Abandoned then return end
		session.ReplayQueued = true
		task.defer(function()
			session.ReplayQueued = false
			if not session.Abandoned then replayPaint(session, false) end
		end)
	end
	local function worldPatch(session, id, patch, optimistic)
		if session.Dirty then
			session.Parts = {}
			for _, part in session.House:GetDescendants() do
				if part:IsA("BasePart") then
					local key = part:GetAttribute("BuildingId")
					if key then session.Parts[key] = session.Parts[key] or {}; table.insert(session.Parts[key], part) end
				end
			end
			session.Dirty = false
		end
		for _, part in session.Parts[id] or {} do
			if not part.Parent or part:GetAttribute("BuildingFixedFinish") then continue end
			if not session.Watching[part] and part.GetPropertyChangedSignal then
				session.Watching[part] = true
				local function changed()
					if session.Queue:busy() then scheduleReplay(session) end
				end
				part:GetPropertyChangedSignal("Color"):Connect(changed)
				part:GetPropertyChangedSignal("Material"):Connect(changed)
			end
			if not session.Snapshots[part] then session.Snapshots[part] = { Material = part.Material, Color = part.Color } end
			local finish = patch or session.Snapshots[part]
			if finish.Material then
				local value = if type(finish.Material) == "string" then Enum.Material[finish.Material] else finish.Material
				if part.Material ~= value then part.Material = value end
			end
			if finish.Color then
				local value = if type(finish.Color) == "table" and finish.Color[1] then Color3.fromRGB(finish.Color[1], finish.Color[2], finish.Color[3]) else finish.Color
				if part.Color ~= value then part.Color = value end
			end
			if optimistic then session.Applied[part] = { Material = part.Material, Color = part.Color }
			elseif patch then session.Snapshots[part] = { Material = part.Material, Color = part.Color } end
		end
	end
	replayPaint = function(session, rebase)
		if session.Abandoned then return end
		local owner = session.House:GetAttribute("OwnerUserId") or (session.House.Parent and session.House.Parent:GetAttribute("OwnerUserId"))
		if Players.LocalPlayer and owner and owner ~= Players.LocalPlayer.UserId then
			-- Release local overrides once. Later replication belongs to the next owner.
			session.Abandoned = true
			for id in session.PendingIds do
				for _, part in session.Parts[id] or {} do
					local snapshot, applied = session.Snapshots[part], session.Applied[part]
					if part.Parent and snapshot and applied then
						if part.Material == applied.Material then part.Material = snapshot.Material end
						if part.Color == applied.Color then part.Color = snapshot.Color end
					end
				end
			end
			return
		end
		if rebase then
			for id in session.Touched do worldPatch(session, id, sourceEntry(session.State, id)) end
		end
		local records = {}
		for _, record in session.Queue.Outstanding do table.insert(records, record) end
		table.sort(records, function(a, b) return a.Serial < b.Serial end)
		for _, record in records do
			for _, id in targetIds(session.State, record.Patch.Id) do
				session.Touched[id] = true
				worldPatch(session, id, record.Patch, true)
				if paintSession == session then
					local entry = entriesById[id]
					if entry then entry.Material, entry.Color = record.Patch.Material, table.clone(record.Patch.Color) end
				end
			end
		end
	end
	accept = function(nextState)
		if type(nextState) ~= "table" then return end
		if paintSession then
			local previous = paintSession.State
			if previous and (nextState.Revision or 0) < (previous.Revision or 0) then return end
			paintSession.State, paintSession.Dirty = nextState, true
		end
		state = deep(nextState)
		builtins, entriesById = {}, {}
		for _, entry in state.Pieces or {} do entriesById[entry.Id] = entry end
		for id, entry in state.Builtins or {} do
			local override = state.Overrides and state.Overrides[id]
			if override and override.Removed then continue end
			local descriptor = copy(entry)
			if override then descriptor.Material, descriptor.Color = override.Material or descriptor.Material, override.Color or descriptor.Color end
			builtins[id], entriesById[id] = descriptor, descriptor
		end
		targetRefresh = 0
		if selected and not entryById(selected) then selected, selectedInstance = nil, nil; clearHighlight() end
		previewKey = nil
		if paintSession then replayPaint(paintSession, true) end
		refresh()
	end
	local function openPaintSession(model, where)
		local session = paintSessions[model]
		if session and session.Site == where and not session.Abandoned then return session end
		session = { House = model, Site = where, State = nil, Touched = {},
			Snapshots = setmetatable({}, { __mode = "k" }), Watching = setmetatable({}, { __mode = "k" }),
			Applied = setmetatable({}, { __mode = "k" }), PendingIds = {}, Parts = {}, Dirty = true }
		session.Queue = PaintQueue.new({
			Send = function(entries)
				if not remote then return { Ok = false, Message = "Building tools are still connecting." } end
				local ok, result = pcall(remote.InvokeServer, remote, "PaintBatch", { Entries = entries }, session.Site)
				if ok and type(result) == "table" then return result end
				local fetched, current = pcall(remote.InvokeServer, remote, "Get", {}, session.Site)
				return { Ok = false, Message = "Painting could not be saved. Please try again.", State = fetched and current and current.State }
			end,
			Changed = function(outstanding)
				session.PendingIds = {}
				for _, record in outstanding do
					for _, id in targetIds(session.State, record.Patch.Id) do session.PendingIds[id] = true end
				end
				replayPaint(session, false)
			end,
			Result = function(result)
				if result and result.State and (not session.State or (result.State.Revision or 0) >= (session.State.Revision or 0)) then session.State = result.State end
				session.Dirty = true
				if paintSession == session and opened and session.State then accept(session.State) else replayPaint(session, true) end
				if not result or result.Ok == false then
					local message = result and result.Message or "Painting could not be saved. Please try again."
					if paintSession == session and opened then notify(message); refresh() elseif options.Notice then options.Notice(message) end
				end
			end,
		})
		if model.DescendantAdded then
			model.DescendantAdded:Connect(function()
				session.Dirty = true
				if session.Queue:busy() then scheduleReplay(session) end
			end)
		end
		paintSessions[model] = session
		return session
	end
	local function paint(id)
		if not paintSession or not state then return end
		local ids = targetIds(paintSession.State, id)
		paintSession.Queue:paint({ Id = ids[1], Material = material, Color = table.clone(color) })
	end
	local function send(action, payload, onSuccess)
		if pending or not opened then return end
		if not remote then notify("Building tools are connecting. Try again shortly."); refresh(); return end
		pending, statusMessage = true, ""
		refresh()
		local token, requestSite = generation, site
		local requestSession = paintSession
		local function dispatch() task.spawn(function()
			local ok, result = pcall(remote.InvokeServer, remote, action, payload, requestSite)
			if token ~= generation then
				if ok and type(result) == "table" and type(result.State) == "table" and requestSession then
					if not requestSession.State or (result.State.Revision or 0) >= (requestSession.State.Revision or 0) then
						requestSession.State = result.State
						if paintSession == requestSession and opened then accept(result.State) end
					end
				end
				return
			end
			pending = false
			if ok and type(result) == "table" then
				if result.State then accept(result.State) end
				if result.Ok == false or result.Success == false then
					notify(result.Message or result.Reason or "This edit could not be saved.")
				elseif onSuccess then onSuccess(result) end
			else
				notify("Building could not be saved. Please try again.")
			end
			refresh()
		end) end
		if paintSession then paintSession.Queue:drain(dispatch) else dispatch() end
	end
	local function changeTool(name)
		if pending then return end
		if table.find(CATEGORIES, name) then section, lastBuildTool = "Build", name
		elseif name == "Paint" then section = "Decorate" end
		if name ~= tool and table.find(CATEGORIES, name) then
			material = if name == "Window" or name == "Door" then "Wood" elseif name == "Roof" then "RoofShingles" elseif name == "Floor" then "WoodPlanks" else "Plaster"
		end
		if name ~= "Select" then selected, selectedInstance = nil, nil; clearHighlight() end
		tool, anchor, moving, reshaping, statusMessage, targetRefresh = name, nil, nil, nil, "", 0
		clearPreview()
		apply(false)
	end
	local function idOf(item)
		local cursor = item
		while cursor and cursor ~= house do
			local id = cursor:GetAttribute("BuildingId")
			if type(id) == "string" then return id, cursor end
			cursor = cursor.Parent
		end
		return nil, nil
	end
	local function pointerPlane(position)
		local camera = workspace.CurrentCamera
		if not camera then return nil end
		local ray = camera:ScreenPointToRay(position.X, position.Y)
		local floorY = Catalog.planeHeight(site, level)
		local normal = frame.UpVector
		local denominator = ray.Direction:Dot(normal)
		if math.abs(denominator) < 1e-5 then return nil end
		local distance = ((frame * Vector3.new(0, floorY, 0)) - ray.Origin):Dot(normal) / denominator
		if distance < 0 then return nil end
		return frame:PointToObjectSpace(ray.Origin + ray.Direction * distance)
	end
	local function overInterface(position)
		local gui = options.Gui
		for _, item in { panel, hud, actionBar, gui:FindFirstChild("BuildNavigation"), gui:FindFirstChild("BuildHelp"),
			gui:FindFirstChild("FurnitureActions"), gui:FindFirstChild("RackEditor") } do
			if item and item.Visible then
				local origin, size = item.AbsolutePosition, item.AbsoluteSize
				if position.X >= origin.X and position.Y >= origin.Y
					and position.X <= origin.X + size.X and position.Y <= origin.Y + size.Y then return true end
			end
		end
		return false
	end
	local function snap(value)
		return Catalog.snap(value, gridSize, site)
	end
	local function nextGrid()
		gridSize = if gridSize == Catalog.GRID then Catalog.GRID / 2
			elseif gridSize == Catalog.GRID / 2 then Catalog.GRID / 4 else Catalog.GRID
		anchor, previewKey = nil, nil
		if options.OnModeChanged then options.OnModeChanged(enabled, section, tool) end
		refresh()
	end
	local function findTarget(position)
		hovered, hoveredInstance, hoverPoint = nil, nil, nil
		local camera = workspace.CurrentCamera
		if not house or not state or not camera then return end
		local now = os.clock()
		if now >= targetRefresh then
			targets = {}
			for _, item in house:GetDescendants() do
				if item:IsA("BasePart") then
					local id = idOf(item)
					local entry = entryById(id)
					if entry and (entry.Level or 0) == level and not item:GetAttribute("BuildingRemoved")
						and ((item.LocalTransparencyModifier or 0) < 0.99 or hiddenHost[item] ~= nil) and (item.Transparency or 0) < 1
						and (self:roofVisible() or entry.Kind ~= "Roof") then table.insert(targets, item) end
				end
			end
			targetRefresh = now + 0.5
		end
		if #targets == 0 then return end
		local ray = camera:ScreenPointToRay(position.X, position.Y)
		local parameters = RaycastParams.new()
		parameters.FilterType = Enum.RaycastFilterType.Include
		parameters.FilterDescendantsInstances = targets
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 1200, parameters)
		if not hit then return end
		local id, instance = idOf(hit.Instance)
		local entry = entryById(id)
		if entry then hovered, hoveredInstance, hoverPoint = entry, instance, frame:PointToObjectSpace(hit.Position) end
	end
	local function selectHovered()
		selected = hovered and hovered.Id or nil
		selectedInstance = hoveredInstance
		clearHighlight()
		if hoveredInstance then
			highlight = make("Highlight", previewFolder, {
				Adornee = hoveredInstance, FillColor = Color3.fromRGB(179, 141, 239), FillTransparency = 0.65,
				OutlineColor = Color3.fromRGB(226, 210, 255), DepthMode = Enum.HighlightDepthMode.Occluded,
			})
		end
		if hovered then
			material = hovered.Material or material
			color = if hovered.Color then table.clone(hovered.Color) else color
			hex.Text = string.format("#%02X%02X%02X", color[1], color[2], color[3])
			if options.OnSelect then options.OnSelect() end
		end
		statusMessage = ""
		refresh()
	end
	local function candidateAt(position)
		local source = moving and entryById(moving)
		local kind = if source then source.Kind else tool
		if kind == "Window" or kind == "Door" then
			if not hovered or hovered.Kind ~= "Wall" or not hoverPoint then return nil, "Point at a wall to fit the opening." end
			local host = Catalog.host(state.Pieces or {}, builtins, hovered.Id)
			if not host then return nil, "Choose a wall." end
			local dx, dz = host.X2 - host.X1, host.Z2 - host.Z1
			local length = math.sqrt(dx * dx + dz * dz)
			if length < 0.01 then return nil, "Choose a longer wall." end
			local along = ((hoverPoint.X - host.X1) * dx + (hoverPoint.Z - host.Z1) * dz) / length
			local entry = if source then copy(source) else {
				Kind = kind, Level = host.Level or level, Material = material, Color = table.clone(color), Style = styles[kind],
			}
			entry.R = rotation
			local width = Catalog.opening(entry)
			local minimum, maximum = width / 2 + 0.2, length - width / 2 - 0.2
			local openingStep = gridSize / 2
			local offset = math.round(along / openingStep) * openingStep
			entry.HostId = host.Id or hovered.Id
			entry.Offset = if maximum >= minimum then math.clamp(offset, minimum, maximum) else length / 2
			return entry
		end
		local point = pointerPlane(position)
		if not point then return nil, "Point inside your plot." end
		local x, z = snap(point.X), snap(point.Z)
		if source then
			local entry = copy(source)
			local cx, cz = (entry.X1 + entry.X2) / 2, (entry.Z1 + entry.Z2) / 2
			if (rotation - (source.R or 0)) % 2 == 1 then
				local dx1, dz1 = entry.X1 - cx, entry.Z1 - cz
				local dx2, dz2 = entry.X2 - cx, entry.Z2 - cz
				entry.X1, entry.Z1, entry.X2, entry.Z2 = cx - dz1, cz + dx1, cx - dz2, cz + dx2
			end
			local dx, dz = math.round((x - cx) / gridSize) * gridSize, math.round((z - cz) / gridSize) * gridSize
			entry.X1, entry.Z1 = entry.X1 + dx, entry.Z1 + dz
			entry.X2, entry.Z2, entry.Level = entry.X2 + dx, entry.Z2 + dz, level
			entry.R = rotation
			return entry
		end
		if kind ~= "Wall" and kind ~= "Room" and kind ~= "Floor" and kind ~= "Roof" then return nil end
		local first = anchor or Vector2.new(x, z)
		local dx, dz = x - first.X, z - first.Y
		if dx == 0 and dz == 0 then dx = gridSize; if kind ~= "Wall" then dz = gridSize end end
		for _ = 1, rotation do dx, dz = -dz, dx end
		x, z = first.X + dx, first.Y + dz
		if kind == "Wall" then
			if math.abs(x - first.X) >= math.abs(z - first.Y) then z = first.Y else x = first.X end
			if x == first.X and z == first.Y then x += gridSize end
		else
			if x == first.X then x += gridSize end
			if z == first.Y then z += gridSize end
		end
		return {
			Kind = if kind == "Room" then "Floor" else kind, X1 = first.X, Z1 = first.Y, X2 = x, Z2 = z, Level = level,
			Material = material, Color = table.clone(color), Style = styles[if kind == "Room" then "Floor" else kind], R = rotation,
		}
	end
	local function room(entry)
		local x1, z1, x2, z2 = entry.X1, entry.Z1, entry.X2, entry.Z2
		local edges = { { x1, z1, x2, z1 }, { x2, z1, x2, z2 }, { x1, z2, x2, z2 }, { x1, z1, x1, z2 } }
		local entries = {}
		for index, edge in edges do
			table.insert(entries, {
				Id = "room-preview-" .. index, Kind = "Wall", X1 = edge[1], Z1 = edge[2], X2 = edge[3], Z2 = edge[4],
				Level = entry.Level, Material = entry.Material, Color = table.clone(entry.Color), Style = styles.Wall, R = entry.R,
			})
		end
		local floor = copy(entry)
		floor.Id = "room-preview-floor"
		table.insert(entries, floor)
		return entries
	end
	-- Keep the floating actions beside the selection, or centred above the dock.
	local function placeActions()
		if not actionBar.Visible then return end
		local camera = workspace.CurrentCamera
		local floor = panel.AbsolutePosition.Y - 10
		local point = nil
		if selectedInstance and selectedInstance.Parent and camera and camera.WorldToScreenPoint
			and moving == nil and reshaping == nil and tool == "Select" then
			local top = selectedInstance.Position + frame.UpVector * (selectedInstance.Size.Y / 2 + 0.5)
			local screen, visible = camera:WorldToScreenPoint(top)
			if visible then point = Vector2.new(screen.X, screen.Y) end
		end
		if point then
			local size = actionBar.AbsoluteSize
			local width = options.Gui.AbsoluteSize.X
			local half = size.X / 2
			actionBar.Position = UDim2.fromOffset(
				math.clamp(point.X, half + 8, math.max(half + 8, width - half - 8)),
				math.clamp(point.Y - 8, size.Y + 80, math.max(size.Y + 80, floor))
			)
		else
			actionBar.Position = UDim2.new(0.5, 0, 0, floor)
		end
	end
	function self:roofVisible()
		return opened and enabled and (showRoofs or tool == "Roof" or level > 0)
	end
	function self:isActive()
		return opened and enabled
	end
	function self:tool()
		return tool
	end
	function self:section()
		return section
	end
	function self:elevation()
		return if opened and enabled then level * Catalog.LEVEL_HEIGHT else 0
	end
	function self:gridSize()
		return gridSize
	end
	-- BuildMode: the pointer is over furniture, so structures should not react to it.
	function self:block(value)
		blocked = value == true
	end
	function self:setHint(text)
		if furnitureHint ~= text then furnitureHint = text; refresh() end
	end
	function self:clearSelection()
		if selected or moving or reshaping then
			selected, selectedInstance, moving, reshaping = nil, nil, nil, nil
			clearPreview(); clearHighlight(); refresh()
		end
	end
	-- Holding furniture pauses the structure tools on the Furniture tab; dropping resumes them.
	function self:suspend()
		if opened and section == "Furniture" and tool ~= nil then tool = nil; apply(false) end
	end
	function self:resume()
		if opened and section == "Furniture" and tool == nil then tool = "Select"; apply(false) end
	end
	function self:step(position)
		if not opened or not enabled then return end
		placeActions()
		if overInterface(position) or blocked then
			clearPreview()
			hovered, hoveredInstance, hoverPoint = nil, nil, nil
			if blocked and not selected and highlightedId then clearHighlight() end
			return
		end
		findTarget(position)
		if tool == "Select" or tool == "Paint" or tool == "Remove" then
			clearPreview()
			if hovered then
				tooltip.Text = if tool == "Paint" then "Paint " .. hovered.Kind
					elseif tool == "Remove" then "Delete " .. hovered.Kind .. " · Undo available"
					elseif builtins[hovered.Id] then "Original " .. string.lower(hovered.Kind) else hovered.Kind
				tooltip.Visible = true
			end
			if not selected and highlightedId ~= (hovered and hovered.Id) then
				clearHighlight()
				if hovered then
					highlightedId = hovered.Id
					highlight = make("Folder", previewFolder, { Name = "SurfacePreviewOutline" })
					for _, part in house:GetDescendants() do
						if part:IsA("BasePart") and part:GetAttribute("BuildingId") == hovered.Id then
							make("Highlight", highlight, { Adornee = part, FillTransparency = 0.93,
								FillColor = if tool == "Remove" then MENU.Red else MENU.Blue,
								OutlineColor = if tool == "Remove" then MENU.Red else MENU.White,
								DepthMode = Enum.HighlightDepthMode.Occluded })
						end
					end
				end
			end
		elseif state then
			local raw, reason = candidateAt(position)
			local entry, normalizeReason
			if raw then entry, normalizeReason = Catalog.normalize(raw) end
			local isRoom = tool == "Room" and not moving and not reshaping
			roomEntries = if entry and isRoom then room(entry) else nil
			local cost = 0
			if entry then
				if roomEntries then
					local checked = table.clone(state.Pieces or {})
					for _, piece in roomEntries do
						reason = reason or Catalog.check(checked, piece, site, builtins)
						cost += Catalog.price(piece)
						table.insert(checked, piece)
					end
				else
					reason = Catalog.check(state.Pieces or {}, entry, site, builtins, moving or reshaping)
					cost = Catalog.price(entry)
				end
				if not moving and not reshaping and cost > (state.Cash or 0) then reason = reason or "You need more cash for this build." end
			else reason = normalizeReason or reason end
			candidate, invalidReason = entry, reason
			local key = if entry then string.format("%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s",
				entry.Kind, tostring(entry.X1), tostring(entry.Z1), tostring(entry.X2), tostring(entry.Z2), tostring(entry.Level),
				tostring(entry.HostId), tostring(entry.Offset), tostring(entry.Style), entry.Material or material,
				tostring(color[1]), tostring(color[2]), tostring(color[3]), tostring(reason), tostring(reshaping or moving)) .. tool .. tostring(entry.R) else "none"
			if key ~= previewKey then
				for part, modifier in hiddenHost do if part.Parent then part.LocalTransparencyModifier = modifier end end
				hiddenHost = {}
				if preview then preview:Destroy(); preview = nil end
				previewKey = key
				if roomEntries then
					preview = make("Model", previewFolder, { Name = "RoomPreview" })
					for _, piece in roomEntries do Renderer.preview(preview, frame, piece, state.Pieces or {}, builtins, reason == nil, site) end
				elseif entry then preview = Renderer.preview(previewFolder, frame, entry, state.Pieces or {}, builtins, reason == nil, site) end
				-- Hide the wall that hosts a new opening, and the original being moved.
				local hide = if entry and entry.HostId and reason == nil then entry.HostId
					elseif (moving or reshaping) and builtins[moving or reshaping] then moving or reshaping else nil
				if hide then
					for _, part in house:GetDescendants() do
						if part:IsA("BasePart") and part:GetAttribute("BuildingId") == hide then
							hiddenHost[part] = part.LocalTransparencyModifier or 0
							part.LocalTransparencyModifier = 1
						end
					end
				end
			end
			tooltip.Text = if reason then reason elseif entry then string.format("%s · $%d\n%s", if isRoom then "Room" else entry.Kind, cost,
				if moving then "Click to move" elseif anchor or tool == "Door" or tool == "Window" then "Click to build" else "Click to start") else ""
			tooltip.Visible = entry ~= nil or reason ~= nil
		end
		local camera = workspace.CurrentCamera
		if camera then
			local size = camera.ViewportSize
			tooltip.Position = UDim2.fromOffset(math.clamp(position.X + 18, 4, math.max(4, size.X - 284)),
				math.clamp(position.Y + 20, 4, math.max(4, panel.AbsolutePosition.Y - 60)))
		end
	end
	function self:click(position)
		if not self:isActive() or (pending and tool ~= "Paint") or overInterface(position) then return end
		statusMessage = ""
		self:step(position)
		if tool == "Select" and not moving and not reshaping then selectHovered(); return end
		if tool == "Paint" or tool == "Remove" then
			if not hovered then return end
			local id = hovered.Id
			if tool == "Paint" then paint(id)
			else send("Remove", { Id = id }) end
			return
		end
		if not moving and tool ~= "Window" and tool ~= "Door" and not anchor then
			local point = pointerPlane(position)
			if point then anchor = Vector2.new(snap(point.X), snap(point.Z)); clearPreview(); refresh(); self:step(position) end
			return
		end
		if invalidReason or not candidate then
			notify(invalidReason or "Choose a valid position."); refresh(); return
		end
		local entry, moveId = copy(candidate), moving or reshaping
		local action = if moveId then "Move" else "Place"
		local payload = if moveId then { Id = moveId, Entry = entry } else { Entries = roomEntries or { entry } }
		send(action, payload, function()
			anchor, moving, reshaping = nil, nil, nil
			clearPreview()
			if moveId then tool = "Select"; selected, selectedInstance = nil, nil; clearHighlight() end
		end)
	end
	local function cancel()
		local back = (moving or reshaping) and "Select"
		anchor, moving, reshaping, selected, selectedInstance, statusMessage = nil, nil, nil, nil, nil, ""
		if back then tool = back end
		clearPreview(); clearHighlight(); refresh()
	end
	local function rotate()
		if tool == nil or not table.find(CATEGORIES, tool) then return end
		rotation = (rotation + 1) % 4
		previewKey = nil
		refresh()
	end
	local function changeLevel(delta)
		if pending then return end
		level = math.clamp(level + delta, 0, Catalog.MAX_LEVEL)
		anchor, previewKey, targetRefresh = nil, nil, 0
		if options.OnModeChanged then options.OnModeChanged(enabled, section, tool) end
		refresh()
	end
	local function toggleRoofs()
		showRoofs, targetRefresh = not showRoofs, 0
		if options.OnModeChanged then options.OnModeChanged(enabled, section, tool) end
		refresh()
	end
	local function beginMove(reshape)
		if not movableSelection() or pending then return end
		local entry = entryById(selected)
		if not entry then return end
		if reshape then reshaping, moving = selected, nil else moving, reshaping = selected, nil end
		anchor, statusMessage = nil, ""
		level, rotation = entry.Level or level, entry.R or 0
		tool = entry.Kind
		if reshape then styles[tool] = entry.Style or styles[tool] end
		if section ~= "Build" then
			section = "Build"
			if table.find(CATEGORIES, entry.Kind) then lastBuildTool = entry.Kind end
		end
		if highlight then clearHighlight() end
		clearPreview()
		apply(false)
	end
	function self:key(input)
		if not self:isActive() or UserInputService:GetFocusedTextBox() then return false end
		local control = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		if control and input.KeyCode == Enum.KeyCode.Z then send("Undo", {}); return true end
		if control and input.KeyCode == Enum.KeyCode.Y then send("Redo", {}); return true end
		if input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.Escape then cancel(); return true end
		if input.KeyCode == Enum.KeyCode.R then rotate(); return true end
		if input.KeyCode == Enum.KeyCode.G then nextGrid(); return true end
		if input.KeyCode == Enum.KeyCode.M and selected and tool == "Select" then beginMove(false); return true end
		if input.KeyCode == Enum.KeyCode.PageUp then changeLevel(1); return true end
		if input.KeyCode == Enum.KeyCode.PageDown then changeLevel(-1); return true end
		if input.KeyCode == Enum.KeyCode.Delete and selected then send("Remove", { Id = selected }); return true end
		return false
	end
	function self:enter(model, houseFrame, where)
		generation += 1
		house, frame, site, opened, pending = model, houseFrame, where, true, false
		paintSession = openPaintSession(model, where)
		state, level, statusMessage, targetRefresh, rotation = nil, 0, "", 0, 0
		setSection("Furniture")
		send("Get", {})
	end
	function self:exit()
		generation += 1
		opened, pending = false, false
		enabled, section, tool = false, "Furniture", "Select"
		anchor, moving, reshaping, selected, selectedInstance, state = nil, nil, nil, nil, nil, nil
		clearPreview(); clearHighlight()
		house, targets = nil, {}
		refresh()
	end
	for name, item in toolButtons do item.Activated:Connect(function() changeTool(name) end) end
	for name, item in tabButtons do
		item.Activated:Connect(function()
			if pending then return end
			if name == "Furniture" then setSection("Furniture")
			elseif name == "Paint" then setSection("Decorate")
			else changeTool(name) end
		end)
	end
	for kind, cards in variantCards do
		for _, record in cards do
			record.Button.Activated:Connect(function()
				if pending then return end
				styles[if kind == "Room" then "Wall" else kind] = record.Variant.Style
				if tool ~= kind then changeTool(kind) end
				if record.Variant.Material then material = record.Variant.Material end
				if record.Variant.Color then color = table.clone(record.Variant.Color) end
				previewKey, statusMessage = nil, ""
				refresh()
			end)
		end
	end
	for name, item in materialButtons do item.Activated:Connect(function() material = name; statusMessage = ""; previewKey = nil; refresh() end) end
	for item, swatch in colorButtons do
		item.Activated:Connect(function()
			color, statusMessage, previewKey = table.clone(swatch.Color), "", nil
			hex.Text = string.format("#%02X%02X%02X", color[1], color[2], color[3])
			refresh()
		end)
	end
	local function applyHex()
		local value = hex.Text:gsub("%s", ""):gsub("^#", "")
		if #value ~= 6 or not value:match("^%x+$") then notify("Enter a color as #RRGGBB, for example #B29675."); refresh(); return end
		color = { tonumber(value:sub(1, 2), 16), tonumber(value:sub(3, 4), 16), tonumber(value:sub(5, 6), 16) }
		hex.Text, statusMessage, previewKey = "#" .. value:upper(), "", nil
		refresh()
	end
	hexApply.Activated:Connect(applyHex)
	hex.FocusLost:Connect(function(enterPressed) if enterPressed then applyHex() end end)
	styleButton.Activated:Connect(rotate)
	cancelButton.Activated:Connect(cancel)
	gridButton.Activated:Connect(nextGrid)
	downButton.Activated:Connect(function() changeLevel(-1) end)
	upButton.Activated:Connect(function() changeLevel(1) end)
	roofsButton.Activated:Connect(toggleRoofs)
	undoButton.Activated:Connect(function() send("Undo", {}) end)
	redoButton.Activated:Connect(function() send("Redo", {}) end)
	finishButton.Activated:Connect(function()
		if selected then paint(selected) end
	end)
	deleteButton.Activated:Connect(function()
		if selected and not pending then send("Remove", { Id = selected }) end
	end)
	paintAllButton.Activated:Connect(function()
		if section ~= "Decorate" or not state then return end
		send("PaintAllWalls", { Material = material, Color = table.clone(color) }, function()
			statusMessage = "All walls painted."
		end)
	end)
	moveButton.Activated:Connect(function() beginMove(false) end)
	reshapeButton.Activated:Connect(function() beginMove(true) end)
	-- Wait outside BuildMode.start so a delayed service does not hold up its UI.
	task.spawn(function()
		local network = ReplicatedStorage:WaitForChild("Building")
		remote, event = network:WaitForChild("Request"), network:WaitForChild("Update")
		event.OnClientEvent:Connect(function(kind, payload, where)
			if kind == "State" and opened and (where or "Home") == (site or "Home") then accept(payload)
			elseif kind == "Notice" and opened then notify(tostring(payload)); refresh() end
		end)
		if opened then send("Get", {}) end
	end)
	refresh()
	return self
end

return StructureEditor
