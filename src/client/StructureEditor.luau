-- Structural tools share BuildMode's camera and pointer handling. The client only
-- draws previews; BuildingService prices, validates and saves every operation.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Catalog = require(ReplicatedStorage.Shared.BuildingCatalog)
local Renderer = require(ReplicatedStorage.Shared.BuildingRenderer)
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))

local StructureEditor = {}
local CATEGORIES = { "Wall", "Room", "Door", "Window", "Floor", "Roof", "Stairs" }
local CATEGORY_NAMES = { Wall = "Walls", Room = "Rooms", Door = "Doors", Window = "Windows", Floor = "Floors", Roof = "Roofs", Stairs = "Stairs" }
local MENU = {
	Paper = Color3.fromRGB(18, 18, 20), Button = Color3.fromRGB(35, 36, 39), White = Color3.fromRGB(248, 248, 248),
	Blue = Color3.fromRGB(47, 153, 225), BlueBorder = Color3.fromRGB(30, 121, 187),
	Ink = Color3.fromRGB(233, 234, 237), Border = Color3.fromRGB(73, 75, 81),
	Muted = Color3.fromRGB(146, 149, 157), Red = Color3.fromRGB(229, 88, 88),
}
local STYLES = {
	Roof = { "Gable", "Flat", "Shed" }, Stairs = { "North", "East", "South", "West" },
	Window = { "Picture", "Classic" }, Door = { "Open", "Panel" },
}

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

local function copy(entry)
	local result = table.clone(entry)
	if type(entry.Color) == "table" then result.Color = table.clone(entry.Color) end
	return result
end

function StructureEditor.new(options)
	local self = {}
	local opened, enabled, pending = false, false, false
	local house, frame, site = nil, CFrame.identity, nil
	local state = nil
	local builtins = {}
	local entriesById = {}
	local tool, material = "Wall", "Plaster"
	local section, lastBuildTool = "Furniture", "Wall"
	local color = { 178, 150, 117 }
	local styles = { Roof = "Gable", Stairs = "North", Window = "Picture", Door = "Open" }
	local level, gridSize = 0, Catalog.GRID
	local selected, moving, reshaping = nil, nil, nil
	local anchor, candidate, invalidReason = nil, nil, nil
	local roomEntries = nil
	local preview, previewKey, highlight = nil, nil, nil
	local previewFolder = make("Folder", workspace, { Name = "StructureEditorPreview" })
	local targets, targetRefresh = {}, 0
	local hovered, hoveredInstance, hoverPoint = nil, nil, nil
	local showRoofs = false
	local generation = 0
	local statusMessage = ""
	local remote, event

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
	local function categoryIcon(parent, kind)
		local icon = make("Frame", parent, {
			Name = "CategoryIcon", BackgroundTransparency = 1, Position = UDim2.fromOffset(9, 6), Size = UDim2.fromOffset(18, 18),
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
			block(0, 6, 11, 3, -35); block(8, 6, 11, 3, 35)
		elseif kind == "Stairs" then
			for index = 0, 3 do block(index * 4, 13 - index * 4, 6, 5 + index * 4) end
		elseif kind == "Floor" then
			for row = 0, 2 do for column = 0, 2 do block(column * 6, row * 6, 5, 5) end end
		else
			block(0, 0, 18, 3); block(0, 15, 18, 3); block(0, 0, 3, 18); block(15, 0, 3, 18)
		end
	end
	local function strip(parent, name, y, height)
		local row = make("ScrollingFrame", parent, {
			Name = name, Position = UDim2.fromOffset(12, y), Size = UDim2.new(1, -24, 0, height),
			BackgroundTransparency = 1, CanvasSize = UDim2.fromOffset(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X,
			Active = true, BorderSizePixel = 0,
		})
		Theme.scroll(row)
		row.ScrollBarThickness = 3
		row.ScrollBarImageColor3 = MENU.Muted
		make("UIListLayout", row, {
			FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		})
		return row
	end
	local panel = make("Frame", options.Gui, {
		Name = "StructureTools", Active = true, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -24, 0, 190), Visible = false,
	})
	make("UISizeConstraint", panel, { MaxSize = Vector2.new(1020, 190) })
	StructureEditor.stylePanel(panel)
	local status = label(panel, "Choose a building tool", {
		Name = "BuildStatus", Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -250, 0, 28),
		TextSize = 12, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local done = button(panel, "Done [B]", {
		Name = "FinishBuilding", Position = UDim2.new(1, -98, 0, 5), Size = UDim2.fromOffset(86, 28),
	})
	done.BackgroundColor3, done.TextColor3, done.MenuBorder.Color = MENU.Red, MENU.White, MENU.Red
	local undoButton = button(panel, "Undo", {
		Name = "UndoBuilding", Position = UDim2.new(1, -230, 0, 5), Size = UDim2.fromOffset(60, 28),
	})
	local redoButton = button(panel, "Redo", {
		Name = "RedoBuilding", Position = UDim2.new(1, -164, 0, 5), Size = UDim2.fromOffset(60, 28),
	})
	local toolStrip = strip(panel, "ConstructionTools", 39, 33)
	local editStrip = strip(panel, "EditingTools", 39, 33)
	local materialStrip = strip(panel, "SurfaceMaterials", 77, 31)
	local colorStrip = strip(panel, "SurfaceColors", 112, 28)
	local actionStrip = strip(panel, "ConstructionActions", 147, 34)
	local tabs = make("Frame", options.Gui, {
		Name = "BuildSections", Active = true, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -210), Size = UDim2.new(1, -24, 0, 34),
		BackgroundTransparency = 1, Visible = false,
	})
	make("UISizeConstraint", tabs, { MaxSize = Vector2.new(456, 34) })
	local furnitureTab = button(tabs, "Furniture", { Name = "FurnitureTab", Size = UDim2.new(1 / 3, -4, 1, 0), TextSize = 15 })
	local decorateTab = button(tabs, "Decorate", { Name = "DecorateTab", Position = UDim2.new(1 / 3, 2, 0, 0), Size = UDim2.new(1 / 3, -4, 1, 0), TextSize = 15 })
	local structureTab = button(tabs, "Build", { Name = "BuildTab", Position = UDim2.new(2 / 3, 4, 0, 0), Size = UDim2.new(1 / 3, -4, 1, 0), TextSize = 15 })
	local tooltip = label(options.Gui, "", {
		Name = "ConstructionPreviewCost", Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(280, 52),
		Visible = false, BackgroundTransparency = 0.06, BackgroundColor3 = MENU.Paper,
		TextXAlignment = Enum.TextXAlignment.Center, TextSize = 13, ZIndex = 12,
	})
	Theme.corner(tooltip, 6)
	border(tooltip).Color = MENU.Border
	local toolButtons, materialButtons, colorButtons = {}, {}, {}
	for index, name in CATEGORIES do
		toolButtons[name] = button(toolStrip, CATEGORY_NAMES[name], {
			Name = "Tool" .. name, LayoutOrder = index, Size = UDim2.fromOffset(if name == "Window" then 116 else 106, 29),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		toolButtons[name].TextTransparency = 1
		label(toolButtons[name], CATEGORY_NAMES[name], {
			Name = "CategoryCaption", Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -38, 1, 0),
			TextSize = 12,
		})
		categoryIcon(toolButtons[name], name)
	end
	for index, name in { "Select", "Paint", "Remove" } do
		toolButtons[name] = button(actionStrip, name, {
			Name = "Tool" .. name, LayoutOrder = index - 10, Size = UDim2.fromOffset(76, 28),
		})
	end
	for index, name in Catalog.Materials do
		materialButtons[name] = button(materialStrip, name:gsub("(%l)(%u)", "%1 %2"), {
			Name = "Material" .. name, LayoutOrder = index, Size = UDim2.fromOffset(106, 26),
		})
	end
	for index, swatch in Catalog.Colors do
		local values = swatch.Color
		local item = make("TextButton", colorStrip, {
			Name = "Color" .. swatch.Name, Text = "", LayoutOrder = index,
			Size = UDim2.fromOffset(30, 23), BackgroundColor3 = Color3.fromRGB(values[1], values[2], values[3]),
			BorderSizePixel = 0, AutoButtonColor = true,
		})
		Theme.corner(item, 4)
		make("UIStroke", item, { Name = "SelectedColor", Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.75 })
		colorButtons[item] = swatch
	end
	local hex = make("TextBox", colorStrip, {
		Name = "CustomHexColor", LayoutOrder = 100, Size = UDim2.fromOffset(92, 23),
		Text = "#B29675", PlaceholderText = "#RRGGBB", ClearTextOnFocus = false,
		TextSize = 12, BackgroundColor3 = MENU.Button, BorderSizePixel = 0,
	})
	Theme.text(hex, MENU.Ink)
	hex.TextStrokeTransparency = 1
	Theme.corner(hex, 4)
	make("UIStroke", hex, { Color = MENU.Border, Thickness = 1 })
	local hexApply = button(colorStrip, "Set color", { LayoutOrder = 101, Size = UDim2.fromOffset(80, 23) })
	local styleButton = button(actionStrip, "Style: Gable [R]", { LayoutOrder = 1, Size = UDim2.fromOffset(142, 28) })
	local moveButton = button(actionStrip, "Move", { LayoutOrder = 2, Size = UDim2.fromOffset(70, 28) })
	local reshapeButton = button(actionStrip, "Reshape", { LayoutOrder = 3, Size = UDim2.fromOffset(82, 28) })
	local finishButton = button(actionStrip, "Apply finish", { LayoutOrder = 4, Size = UDim2.fromOffset(100, 28) })
	local gridButton = button(actionStrip, "Grid: 4.5 [G]", { LayoutOrder = 7, Size = UDim2.fromOffset(104, 28) })
	local downButton = button(actionStrip, "Floor −", { LayoutOrder = 8, Size = UDim2.fromOffset(76, 28) })
	local upButton = button(actionStrip, "Floor +", { LayoutOrder = 9, Size = UDim2.fromOffset(76, 28) })
	local roofsButton = button(actionStrip, "Show roof", { LayoutOrder = 10, Size = UDim2.fromOffset(100, 28) })
	local cancelButton = button(actionStrip, "Cancel [X]", { LayoutOrder = 11, Size = UDim2.fromOffset(92, 28) })

	local function notify(message)
		statusMessage = message
		if options.Notice then options.Notice(message) end
	end
	local function clearPreview()
		if preview then preview:Destroy(); preview = nil end
		previewKey, candidate, invalidReason, roomEntries = nil, nil, nil, nil
		tooltip.Visible = false
	end
	local function clearHighlight()
		if highlight then highlight:Destroy(); highlight = nil end
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
	local function setButton(item, active, chosen)
		item.Active, item.Selectable = active, active
		StructureEditor.styleButton(item, if chosen then "Selected" elseif active then "Normal" else "Disabled")
	end
	local function refresh()
		panel.Visible, tabs.Visible = opened and enabled, opened
		setButton(furnitureTab, true, section == "Furniture")
		setButton(decorateTab, true, section == "Decorate")
		setButton(structureTab, true, section == "Build")
		toolStrip.Visible, editStrip.Visible = section == "Build", section == "Decorate"
		for _, name in { "Select", "Paint", "Remove" } do
			toolButtons[name].Parent = if section == "Decorate" then editStrip else actionStrip
		end
		for name, item in toolButtons do setButton(item, not pending, tool == name) end
		for name, item in materialButtons do setButton(item, not pending, material == name) end
		for item, swatch in colorButtons do
			local values = swatch.Color
			local chosen = values[1] == color[1] and values[2] == color[2] and values[3] == color[3]
			item.SelectedColor.Transparency = if chosen then 0 else 0.75
		end
		local selectedEntry = entryById(selected)
		local selecting = tool == "Select" and moving == nil and reshaping == nil
		moveButton.Visible = selecting and customSelection() and selectedEntry ~= nil
		reshapeButton.Visible = moveButton.Visible and (selectedEntry.Kind == "Wall" or selectedEntry.Kind == "Floor"
			or selectedEntry.Kind == "Roof" or selectedEntry.Kind == "Stairs")
		finishButton.Visible = selecting and selectedEntry ~= nil
		cancelButton.Visible = anchor ~= nil or moving ~= nil or reshaping ~= nil or selected ~= nil
		gridButton.Visible = section == "Build"
		setButton(moveButton, customSelection() and selectedEntry ~= nil and not pending, moving ~= nil)
		setButton(reshapeButton, customSelection() and selectedEntry ~= nil
			and (selectedEntry.Kind == "Wall" or selectedEntry.Kind == "Floor" or selectedEntry.Kind == "Roof" or selectedEntry.Kind == "Stairs") and not pending, reshaping ~= nil)
		setButton(finishButton, selectedEntry ~= nil and not pending)
		setButton(undoButton, state ~= nil and state.CanUndo == true and not pending)
		setButton(redoButton, state ~= nil and state.CanRedo == true and not pending)
		setButton(downButton, level > 0 and not pending)
		setButton(upButton, level < Catalog.MAX_LEVEL and not pending)
		styleButton.Visible = STYLES[tool] ~= nil
		styleButton.Text = "Style: " .. (styles[tool] or "") .. " [R]"
		gridButton.Text = string.format("Grid: %g [G]", gridSize)
		roofsButton.Text = if showRoofs then "Hide roof" else "Show roof"
		status.Text = if pending then "Saving…" elseif statusMessage ~= "" then statusMessage
			else string.format("%s · Floor %d · $%s", section, level + 1, if state then tostring(state.Cash) else "—")
	end
	local function setEnabled(value)
		enabled = value
		anchor, moving, reshaping, selected = nil, nil, nil, nil
		clearPreview(); clearHighlight()
		if options.OnModeChanged then options.OnModeChanged(value) end
		refresh()
	end
	local function setSection(value)
		section = value
		if value == "Build" then tool = lastBuildTool
		elseif value == "Decorate" then tool = "Paint" end
		statusMessage, targetRefresh = "", 0
		setEnabled(value ~= "Furniture")
	end
	local function accept(nextState)
		if type(nextState) ~= "table" then return end
		state = nextState
		builtins, entriesById = {}, {}
		for _, entry in nextState.Pieces or {} do entriesById[entry.Id] = entry end
		for id, entry in nextState.Builtins or {} do
			local override = nextState.Overrides and nextState.Overrides[id]
			if override and override.Removed then continue end
			local descriptor = copy(entry)
			if override then descriptor.Material, descriptor.Color = override.Material or descriptor.Material, override.Color or descriptor.Color end
			builtins[id], entriesById[id] = descriptor, descriptor
		end
		targetRefresh = 0
		if selected and not entryById(selected) then selected = nil; clearHighlight() end
		previewKey = nil
		refresh()
	end
	local function send(action, payload, onSuccess)
		if pending or not opened then return end
		if not remote then notify("Building tools are connecting. Try again shortly."); refresh(); return end
		pending, statusMessage = true, ""
		refresh()
		local token, requestSite = generation, site
		task.spawn(function()
			local ok, result = pcall(remote.InvokeServer, remote, action, payload, requestSite)
			if token ~= generation then return end
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
		end)
	end
	local function changeTool(name)
		if pending then return end
		if table.find(CATEGORIES, name) then section, lastBuildTool = "Build", name
		elseif name == "Paint" then section = "Decorate" end
		tool, anchor, moving, reshaping, statusMessage, targetRefresh = name, nil, nil, nil, "", 0
		clearPreview()
		if options.OnModeChanged then options.OnModeChanged(enabled) end
		refresh()
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
		for _, item in { panel, tabs, options.Gui:FindFirstChild("BuildNavigation") } do
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
		if options.OnModeChanged then options.OnModeChanged(enabled) end
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
						and (item.LocalTransparencyModifier or 0) < 0.99 and (item.Transparency or 0) < 1
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
			statusMessage = hovered.Kind .. " selected."
		else statusMessage = "" end
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
			local dx, dz = math.round((x - cx) / gridSize) * gridSize, math.round((z - cz) / gridSize) * gridSize
			entry.X1, entry.Z1 = entry.X1 + dx, entry.Z1 + dz
			entry.X2, entry.Z2, entry.Level = entry.X2 + dx, entry.Z2 + dz, level
			return entry
		end
		if kind ~= "Wall" and kind ~= "Room" and kind ~= "Floor" and kind ~= "Roof" and kind ~= "Stairs" then return nil end
		local first = anchor or Vector2.new(x, z)
		if kind == "Wall" then
			if math.abs(x - first.X) >= math.abs(z - first.Y) then z = first.Y else x = first.X end
			if x == first.X and z == first.Y then x += gridSize end
		else
			if x == first.X then x += gridSize end
			if z == first.Y then z += gridSize end
		end
		return {
			Kind = if kind == "Room" then "Floor" else kind, X1 = first.X, Z1 = first.Y, X2 = x, Z2 = z, Level = level,
			Material = material, Color = table.clone(color), Style = styles[kind],
		}
	end
	local function room(entry)
		local x1, z1, x2, z2 = entry.X1, entry.Z1, entry.X2, entry.Z2
		local edges = { { x1, z1, x2, z1 }, { x2, z1, x2, z2 }, { x1, z2, x2, z2 }, { x1, z1, x1, z2 } }
		local entries = {}
		for index, edge in edges do
			table.insert(entries, {
				Id = "room-preview-" .. index, Kind = "Wall", X1 = edge[1], Z1 = edge[2], X2 = edge[3], Z2 = edge[4],
				Level = entry.Level, Material = entry.Material, Color = table.clone(entry.Color),
			})
		end
		local floor = copy(entry)
		floor.Id = "room-preview-floor"
		table.insert(entries, floor)
		return entries
	end
	function self:roofVisible()
		return opened and enabled and (showRoofs or tool == "Roof" or level > 0)
	end
	function self:isActive()
		return opened and enabled
	end
	function self:elevation()
		return if opened and enabled then level * Catalog.LEVEL_HEIGHT else 0
	end
	function self:gridSize()
		return gridSize
	end
	function self:step(position)
		if not opened or not enabled then return end
		if overInterface(position) then clearPreview(); return end
		findTarget(position)
		if tool == "Select" or tool == "Paint" or tool == "Remove" then
			clearPreview()
			if hovered then
				tooltip.Text = if tool == "Paint" then "Paint " .. hovered.Kind
					elseif tool == "Remove" then "Remove " .. hovered.Kind .. " · Undo available" else hovered.Kind
				tooltip.Visible = true
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
				tostring(color[1]), tostring(color[2]), tostring(color[3]), tostring(reason), tostring(reshaping or moving)) .. tool else "none"
			if key ~= previewKey then
				if preview then preview:Destroy(); preview = nil end
				previewKey = key
				if roomEntries then
					preview = make("Model", previewFolder, { Name = "RoomPreview" })
					for _, piece in roomEntries do Renderer.preview(preview, frame, piece, state.Pieces or {}, builtins, reason == nil, site) end
				elseif entry then preview = Renderer.preview(previewFolder, frame, entry, state.Pieces or {}, builtins, reason == nil, site) end
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
		if not self:isActive() or pending or overInterface(position) then return end
		statusMessage = ""
		self:step(position)
		if tool == "Select" and not moving and not reshaping then selectHovered(); return end
		if tool == "Paint" or tool == "Remove" then
			if not hovered then return end
			local id = hovered.Id
			if tool == "Paint" then send("Paint", { Id = id, Material = material, Color = table.clone(color) })
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
			if moveId then tool = "Select" end
		end)
	end
	local function cancel()
		anchor, moving, reshaping, selected, statusMessage = nil, nil, nil, nil, ""
		clearPreview(); clearHighlight(); refresh()
	end
	local function cycleStyle()
		local list = STYLES[tool]
		if not list then return end
		local index = table.find(list, styles[tool]) or 1
		styles[tool] = list[index % #list + 1]
		previewKey = nil
		refresh()
	end
	local function changeLevel(delta)
		if pending then return end
		level = math.clamp(level + delta, 0, Catalog.MAX_LEVEL)
		anchor, previewKey, targetRefresh = nil, nil, 0
		if options.OnModeChanged then options.OnModeChanged(enabled) end
		refresh()
	end
	function self:key(input)
		if not self:isActive() or UserInputService:GetFocusedTextBox() then return false end
		local control = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		if control and input.KeyCode == Enum.KeyCode.Z then send("Undo", {}); return true end
		if control and input.KeyCode == Enum.KeyCode.Y then send("Redo", {}); return true end
		if input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.Escape then cancel(); return true end
		if input.KeyCode == Enum.KeyCode.R then cycleStyle(); return true end
		if input.KeyCode == Enum.KeyCode.G then nextGrid(); return true end
		if input.KeyCode == Enum.KeyCode.PageUp then changeLevel(1); return true end
		if input.KeyCode == Enum.KeyCode.PageDown then changeLevel(-1); return true end
		if input.KeyCode == Enum.KeyCode.Delete and selected then send("Remove", { Id = selected }); return true end
		return false
	end
	function self:enter(model, houseFrame, where)
		generation += 1
		house, frame, site, opened, pending = model, houseFrame, where, true, false
		state, level, statusMessage, targetRefresh = nil, 0, "", 0
		setSection("Furniture")
		send("Get", {})
	end
	function self:exit()
		generation += 1
		opened, pending = false, false
		enabled, section = false, "Furniture"
		anchor, moving, reshaping, selected, state = nil, nil, nil, nil, nil
		clearPreview(); clearHighlight()
		house, targets = nil, {}
		refresh()
	end
	for name, item in toolButtons do item.Activated:Connect(function() changeTool(name) end) end
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
	furnitureTab.Activated:Connect(function() setSection("Furniture") end)
	decorateTab.Activated:Connect(function() setSection("Decorate") end)
	structureTab.Activated:Connect(function() setSection("Build") end)
	done.Activated:Connect(function() if options.OnExit then options.OnExit() end end)
	styleButton.Activated:Connect(cycleStyle)
	cancelButton.Activated:Connect(cancel)
	gridButton.Activated:Connect(nextGrid)
	downButton.Activated:Connect(function() changeLevel(-1) end)
	upButton.Activated:Connect(function() changeLevel(1) end)
	roofsButton.Activated:Connect(function()
		showRoofs, targetRefresh = not showRoofs, 0
		if options.OnModeChanged then options.OnModeChanged(enabled) end
		refresh()
	end)
	undoButton.Activated:Connect(function() send("Undo", {}) end)
	redoButton.Activated:Connect(function() send("Redo", {}) end)
	finishButton.Activated:Connect(function()
		if selected then send("Paint", { Id = selected, Material = material, Color = table.clone(color) }) end
	end)
	moveButton.Activated:Connect(function()
		if not customSelection() or pending then return end
		moving, reshaping, anchor, statusMessage = selected, nil, nil, ""
		local entry = entryById(selected)
		if entry then level = entry.Level or level; tool = entry.Kind end
		clearPreview(); refresh()
	end)
	reshapeButton.Activated:Connect(function()
		if not customSelection() or pending then return end
		local entry = entryById(selected)
		if not entry then return end
		reshaping, moving, anchor, tool, level, statusMessage = selected, nil, nil, entry.Kind, entry.Level or level, ""
		styles[tool] = entry.Style or styles[tool]
		clearPreview(); refresh()
	end)
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
