-- Left-side navigation and data-backed collection screens. Gameplay remains server-owned.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Gamepasses = require(ReplicatedStorage.Shared.Gamepasses)
local Catalog = require(ReplicatedStorage.Shared.AnglerCatalog)
local StaffCatalog = require(ReplicatedStorage.Shared.StaffCatalog)
local BoatCatalog = require(ReplicatedStorage.Shared.BoatCatalog)
local Paths = require(ReplicatedStorage.Shared.Paths)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local FishModels = require(ReplicatedStorage.Shared.FishModels)
local Settings = require(script.Parent.PlayerSettings)
local StaffPreview = require(script.Parent.StaffPreview)
local EquipmentBag = require(script.Parent:WaitForChild("EquipmentBag"))
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))
local Menu = {}
local started = false
local ink = Theme.Colors.Text
local paper = Theme.Colors.Panel
local cream = Theme.Colors.Text
local navy = Theme.Colors.Window
local muted = Theme.Colors.Muted
local gold = Theme.Colors.Blue
local green = Theme.Colors.Green
local Book = {
	Paper = Color3.fromRGB(209, 196, 168),
	Page = Color3.fromRGB(230, 219, 194),
	Ink = Color3.fromRGB(51, 43, 32),
	Edge = Color3.fromRGB(133, 115, 80),
	Leather = Color3.fromRGB(102, 35, 36),
	Bestiary = Color3.fromRGB(43, 83, 68),
	Gold = Color3.fromRGB(225, 192, 119),
}

local function isGlass(item)
	while item do
		if item:GetAttribute("GlassSurface") then
			return true
		end
		item = item.Parent
	end
	return false
end

local function styleGlassItem(item, state)
	if not isGlass(item) then
		return
	end
	if item:IsA("TextButton") then
		Theme.glassButton(item, state)
	elseif item:IsA("TextLabel") or item:IsA("TextBox") then
		Theme.text(item, if item.TextColor3 == muted then Color3.fromRGB(178, 178, 178) else cream)
		if item:IsA("TextBox") then
			Theme.glassPanel(item, true)
		end
	elseif item:IsA("Frame") and item.BackgroundTransparency ~= 1 then
		Theme.glassPanel(item)
	elseif item:IsA("ScrollingFrame") then
		item.ScrollBarThickness = 6
		item.ScrollBarImageColor3 = Color3.fromRGB(156, 156, 156)
		item.ScrollBarImageTransparency = 0.25
	end
end

local function styleBookItem(item)
	local ancestor = item.Parent
	while ancestor and not ancestor:GetAttribute("BookSurface") do
		ancestor = ancestor.Parent
	end
	if not ancestor then
		return
	end
	if item:IsA("TextLabel") or item:IsA("TextBox") then
		item.Font = Enum.Font.Garamond
		item.TextColor3 = Book.Ink
		item.TextStrokeTransparency = 1
		if item:IsA("TextBox") then
			item.BackgroundColor3 = Book.Page
			item.PlaceholderColor3 = Book.Leather
		end
	elseif item:IsA("TextButton") and item:FindFirstChild("ThemeFace") then
		local selected = item.ThemeFace:GetAttribute("Finish") == "Selected"
		item.ThemeFace.ThemeFinish.Color =
			ColorSequence.new(if selected then Book.Gold else Book.Page, if selected then Book.Edge else Book.Paper)
		item.ThemeBorder.Color = Book.Edge
		item.ThemeCaption.Font = Enum.Font.Garamond
		item.ThemeCaption.TextColor3 = Book.Ink
		item.ThemeCaption.TextStrokeTransparency = 1
	elseif item:IsA("ScrollingFrame") then
		item.ScrollBarImageColor3 = Book.Edge
		item.ScrollBarThickness = 6
	elseif item:IsA("Frame") or item:IsA("ImageLabel") then
		if item.BackgroundTransparency ~= 1 then
			item.BackgroundColor3 = Book.Page
		end
	end
	local border = item:FindFirstChild("ThemeBorder")
	if border then
		border.Color = Book.Edge
		border.Transparency = 0.6
	end
end

local function make(class, parent, props)
	local instance = Instance.new(class)
	for key, value in props do
		instance[key] = value
	end
	if class == "TextLabel" or class == "TextBox" then
		Theme.text(instance, instance.TextColor3)
	elseif (class == "Frame" or class == "ImageLabel") and props.BackgroundTransparency ~= 1 then
		Theme.panel(instance, class == "ImageLabel")
	end
	if class == "ScrollingFrame" then
		Theme.scroll(instance)
	end
	instance.Parent = parent
	styleBookItem(instance)
	styleGlassItem(instance)
	return instance
end
local function decoration(parent, name, color, position, size)
	local item = make("Frame", parent, {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		Active = false,
	})
	item.BackgroundColor3, item.BackgroundTransparency = color, 0
	return item
end

-- Native GUI geometry keeps the book sharp at every resolution, without an
-- uploaded texture. Decorations deliberately bypass the shared metal UI theme.
local function bookPart(parent, name, color, position, size, radius)
	local part = decoration(parent, name, color, position, size)
	if radius then
		Theme.corner(part, radius)
	end
	return part
end

local function paperFinish(part, reverse)
	local gradient = Instance.new("UIGradient")
	gradient.Name = "PaperLight"
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(171, 153, 120)),
		ColorSequenceKeypoint.new(0.12, Color3.fromRGB(224, 212, 185)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(238, 228, 205)),
		ColorSequenceKeypoint.new(0.9, Color3.fromRGB(222, 209, 182)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(158, 137, 103)),
	})
	gradient.Rotation = if reverse then 180 else 0
	part.BackgroundColor3 = Color3.new(1, 1, 1)
	gradient.Parent = part
end

local function bookButton(item, selected)
	Theme.button(item, if selected then "Selected" else "Normal")
	local cover = if item.Name == "Bestiary" then Book.Bestiary else Book.Leather
	item.BackgroundColor3 = cover
	Theme.corner(item, 4)
	Theme.corner(item.ThemeFace, 4)
	item.ThemeFace.ThemeFinish.Rotation = 0
	item.ThemeFace.ThemeFinish.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, cover:Lerp(Book.Ink, 0.65)),
		ColorSequenceKeypoint.new(0.09, cover),
		ColorSequenceKeypoint.new(0.13, cover:Lerp(Book.Ink, 0.5)),
		ColorSequenceKeypoint.new(0.19, cover:Lerp(Book.Gold, if selected then 0.24 else 0.12)),
		ColorSequenceKeypoint.new(0.7, cover),
		ColorSequenceKeypoint.new(1, cover:Lerp(Book.Ink, 0.3)),
	})
	item.ThemeBorder.Color = Book.Gold
	item.ThemeBorder.Transparency = if selected then 0.2 else 0.55
	item.ThemeBorder.Thickness = 1
	item.ThemeCaption.Font = Enum.Font.Garamond
	item.ThemeCaption.TextColor3 = Book.Gold
	item.ThemeCaption.TextStrokeTransparency = 1
	item.ThemeCaption.Position = UDim2.fromOffset(28, -2)
	item.ThemeCaption.Size = UDim2.new(1, -44, 1, -4)
	local grain = item.ThemeFace:FindFirstChild("BookGrain")
	if not grain then
		grain = Instance.new("Frame")
		grain.Name = "BookGrain"
		grain.BackgroundTransparency = 1
		grain.BorderSizePixel = 0
		grain.Size = UDim2.fromScale(1, 1)
		grain.ClipsDescendants = true
		grain.Active = false
		grain.ZIndex = item.ThemeFace.ZIndex
		grain.Parent = item.ThemeFace

		-- A fixed seed keeps the leather grain stable when selection refreshes.
		local seed = if item.Name == "Bestiary" then 413 else 829
		local function nextUnit()
			seed = (seed * 48271) % 2147483647
			return seed / 2147483647
		end
		for index = 1, 64 do
			local fleck = Instance.new("Frame")
			fleck.Name = "GrainFleck" .. index
			fleck.BorderSizePixel = 0
			fleck.BackgroundColor3 = if index % 3 == 0 then Book.Gold else Book.Paper
			fleck.BackgroundTransparency = if index % 4 == 0 then 0.94 else 0.97
			fleck.Position = UDim2.fromScale(nextUnit(), nextUnit())
			fleck.Size = UDim2.fromScale(0.004 + nextUnit() * 0.009, 0.018 + nextUnit() * 0.04)
			fleck.Rotation = math.floor(nextUnit() * 70) - 35
			fleck.Active = false
			fleck.ZIndex = grain.ZIndex
			fleck.Parent = grain
		end
		for index = 1, 11 do
			local grainLine = Instance.new("Frame")
			grainLine.Name = "GrainLine" .. index
			grainLine.BorderSizePixel = 0
			grainLine.BackgroundColor3 = Book.Ink
			grainLine.BackgroundTransparency = 0.95
			grainLine.Position = UDim2.fromScale(0.08 + nextUnit() * 0.84, nextUnit())
			grainLine.Size = UDim2.fromScale(0.035 + nextUnit() * 0.09, 0.008)
			grainLine.Rotation = math.floor(nextUnit() * 24) - 12
			grainLine.Active = false
			grainLine.ZIndex = grain.ZIndex
			grainLine.Parent = grain
		end
	end
	if not item.ThemeFace:FindFirstChild("BookSpine") then
		local face = item.ThemeFace
		decoration(face, "BookSpine", cover:Lerp(Book.Ink, 0.7), UDim2.fromOffset(5, 1), UDim2.new(0, 9, 1, -6))
		decoration(face, "SpineHighlight", Book.Edge, UDim2.fromOffset(15, 2), UDim2.new(0, 1, 1, -8)).BackgroundTransparency =
			0.25
		local pages = decoration(face, "PageEdges", Book.Paper, UDim2.new(0, 19, 1, -6), UDim2.new(1, -23, 0, 4))
		for index = 1, 2 do
			decoration(
				pages,
				"PageLine" .. index,
				Book.Edge,
				UDim2.fromOffset(1, index * 2 - 1),
				UDim2.new(1, -1, 0, 1)
			).BackgroundTransparency =
				0.5
		end
		decoration(face, "PageForeEdge", Book.Page, UDim2.new(1, -4, 0, 6), UDim2.new(0, 2, 1, -12))
		for _, y in { 8, 15, 34, 41 } do
			decoration(face, "SpineBand" .. y, Book.Gold, UDim2.fromOffset(4, y), UDim2.fromOffset(11, 1)).BackgroundTransparency =
				0.22
		end
		local tooling = bookPart(face, "CoverTooling", cover, UDim2.fromOffset(22, 5), UDim2.new(1, -31, 1, -15), 2)
		tooling.BackgroundTransparency = 1
		local border = Instance.new("UIStroke")
		border.Name = "EmbossedBorder"
		border.Color, border.Thickness, border.Transparency = Book.Gold, 1, 0.65
		border.Parent = tooling
		for _, x in { 0, 1 } do
			for _, y in { 0, 1 } do
				local corner = bookPart(
					tooling,
					"GoldCorner" .. x .. y,
					Book.Gold,
					UDim2.new(x, if x == 0 then 3 else -3, y, if y == 0 then 3 else -3),
					UDim2.fromOffset(3, 3)
				)
				corner.AnchorPoint = Vector2.new(0.5, 0.5)
				corner.Rotation = 45
				corner.BackgroundTransparency = 0.25
			end
		end
		local ribbon = decoration(
			face,
			"Bookmark",
			if item.Name == "Bestiary" then Book.Gold else Book.Bestiary,
			UDim2.new(1, -22, 1, -13),
			UDim2.fromOffset(7, 11)
		)
		ribbon.BackgroundTransparency = 0.12
	end
end
-- A separate face lets the black background fade without fading the label or icon.
local function navIcon(face, name)
	local icon = decoration(face, "NavIcon", cream, UDim2.new(0, 11, 0.5, -11), UDim2.fromOffset(22, 22))
	icon.BackgroundTransparency = 1
	local function line(label, x, y, width, rotation)
		local part = decoration(icon, label, cream, UDim2.fromOffset(x, y), UDim2.fromOffset(width, 2))
		part.AnchorPoint = Vector2.new(0.5, 0.5)
		part.Rotation = rotation or 0
		Theme.corner(part, 1)
		return part
	end
	local function outline(label, x, y, width, height, radius)
		local part = decoration(icon, label, cream, UDim2.fromOffset(x, y), UDim2.fromOffset(width, height))
		part.BackgroundTransparency = 1
		Theme.corner(part, radius or 2)
		local stroke = Instance.new("UIStroke")
		stroke.Color, stroke.Thickness, stroke.Transparency = cream, 1.5, 0.08
		stroke.Parent = part
		return part
	end
	if name == "Home" then
		line("RoofLeft", 6, 6, 13, -42)
		line("RoofRight", 16, 6, 13, 42)
		line("WallLeft", 3, 14, 12, 90)
		line("WallRight", 19, 14, 12, 90)
		line("Floor", 11, 20, 16)
		outline("Door", 8, 12, 6, 8, 1)
	elseif name == "Equipmentbag" then
		outline("Bag", 3, 7, 16, 13, 3)
		outline("Handle", 7, 2, 8, 6, 2)
		line("Pocket", 11, 13, 8)
		line("Clasp", 11, 15, 3, 90)
	elseif name == "Settings" then
		for index, y in { 4, 11, 18 } do
			line("Track" .. index, 11, y, 20)
			local knob = decoration(
				icon,
				"Knob" .. index,
				cream,
				UDim2.fromOffset(if index == 2 then 14 else 6, y),
				UDim2.fromOffset(4, 6)
			)
			knob.AnchorPoint = Vector2.new(0.5, 0.5)
			Theme.corner(knob, 2)
		end
	elseif name == "Shop" then
		outline("ShoppingBag", 3, 6, 16, 15, 2)
		outline("Handle", 7, 1, 8, 10, 4)
	end
end

local function navButton(item, selected)
	Theme.button(item, if selected then "Selected" else "Normal")
	item.BackgroundTransparency = 1
	item.AutoButtonColor = false
	item.TextScaled = true
	item.TextWrapped = false
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.ThemeBorder.Transparency = 1
	Theme.corner(item, 6)
	local face = item.ThemeFace
	Theme.corner(face, 6)
	face.BackgroundColor3 = Color3.new()
	face.BackgroundTransparency = 0
	face.ThemeFinish.Rotation = 0
	face.ThemeFinish.Color = ColorSequence.new(Color3.new(), Color3.new())
	face.ThemeFinish.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.35, 0.06),
		NumberSequenceKeypoint.new(0.72, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	local caption = item.ThemeCaption
	caption.Font = Enum.Font.GothamMedium
	caption.TextColor3 = cream
	caption.TextStrokeTransparency = 1
	caption.TextXAlignment = Enum.TextXAlignment.Left
	caption.Position = UDim2.fromOffset(44, 0)
	caption.Size = UDim2.new(1, -48, 1, 0)
	caption.TextScaled = true
	if not caption:FindFirstChild("CaptionSize") then
		local size = Instance.new("UITextSizeConstraint")
		size.Name = "CaptionSize"
		size.MinTextSize, size.MaxTextSize = 11, 14
		size.Parent = caption
	end
	if not face:FindFirstChild("NavIcon") then
		navIcon(face, item.Name)
	end
	-- Focus is visible for both pointer and controller navigation. Preserve the
	-- fade by changing only the left-side accent and caption brightness.
	local accent = face:FindFirstChild("FocusAccent")
	if not accent then
		accent = decoration(face, "FocusAccent", cream, UDim2.new(0, 0, 0.5, -9), UDim2.fromOffset(2, 18))
		Theme.corner(accent, 1)
		local hovered, focused = false, false
		local function update()
			local highlighted = hovered or focused or face:GetAttribute("Finish") == "Selected"
			accent.BackgroundTransparency = if highlighted then 0.1 else 1
			caption.TextTransparency = if highlighted then 0 else 0.12
		end
		item.MouseEnter:Connect(function()
			hovered = true
			update()
		end)
		item.MouseLeave:Connect(function()
			hovered = false
			update()
		end)
		item.SelectionGained:Connect(function()
			focused = true
			update()
		end)
		item.SelectionLost:Connect(function()
			focused = false
			update()
		end)
		item.Parent:GetPropertyChangedSignal("Visible"):Connect(function()
			if not item.Parent.Visible then
				hovered, focused = false, false
			end
			update()
		end)
		face:GetAttributeChangedSignal("Finish"):Connect(update)
		update()
	end
end
local function round(parent, radius)
	Theme.corner(
		parent,
		if isGlass(parent) then 1 elseif parent:IsA("TextButton") then 10 else math.min(radius or 2, 4)
	)
end
local function text(parent, value, size, color, props)
	local item = make("TextLabel", parent, {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size or 16,
		Font = Enum.Font.Gotham,
		TextColor3 = color or cream,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 28),
	})
	for key, setting in props or {} do
		item[key] = setting
	end
	Theme.text(item, color or cream)
	styleBookItem(item)
	styleGlassItem(item)
	return item
end
local function button(parent, value, callback, props)
	local item = make("TextButton", parent, {
		BackgroundColor3 = navy,
		Text = value,
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextColor3 = cream,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 44),
		AutoButtonColor = true,
	})
	for key, setting in props or {} do
		item[key] = setting
	end
	local state = if item.BackgroundColor3 == gold or item.BackgroundColor3 == green then "Selected" else "Normal"
	Theme.button(item, state)
	styleBookItem(item)
	styleGlassItem(item, state)
	item.Activated:Connect(callback)
	return item
end
local function list(parent, gap)
	return make("UIListLayout", parent, { Padding = UDim.new(0, gap or 10), SortOrder = Enum.SortOrder.LayoutOrder })
end
local function scroll(parent, props)
	local item = make("ScrollingFrame", parent, {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = gold,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	})
	for key, value in props or {} do
		item[key] = value
	end
	return item
end
local function input(parent, placeholder)
	local item = make("TextBox", parent, {
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = Color3.fromRGB(15, 26, 29),
		Text = "",
		PlaceholderText = placeholder,
		PlaceholderColor3 = muted,
		TextColor3 = cream,
		Font = Enum.Font.Gotham,
		TextSize = 16,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	Theme.panel(item, true, 2)
	Theme.text(item)
	styleBookItem(item)
	styleGlassItem(item)
	make("UIPadding", item, { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) })
	return item
end
local function empty(parent, title, description, color)
	text(
		parent,
		title,
		22,
		color or cream,
		{ Position = UDim2.new(0.06, 0, 0, 64), Size = UDim2.new(0.88, 0, 0, 68), Font = Enum.Font.GothamBold }
	)
	text(parent, description, 16, color or muted, {
		Position = UDim2.new(0.06, 0, 0, 140),
		Size = UDim2.new(0.88, 0, 0, 110),
		TextYAlignment = Enum.TextYAlignment.Top,
	})
end
local function commas(value)
	local formatted = tostring(value or 0)
	local count
	repeat
		formatted, count = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return formatted
end
-- "Red Neon Albino": the catalog name with the neon colour worked in.
local function mutationName(record)
	local mutation = Catalog.Mutations[record.Mutation]
	local name = mutation and mutation.Name or record.Mutation
	return if record.NeonColor then (string.gsub(name, "Neon", record.NeonColor .. " Neon")) else name
end
local function fishName(record)
	local fish = Catalog.Fish[record.FishId]
	return (if record.Mutation ~= "Normal" then mutationName(record) .. " " else "")
		.. (fish and fish.Name or record.FishId)
end
-- Silhouettes are drawn as flat ink, so undiscovered fish keep their shape secret-ish.
local function picture(parent, id, props, silhouette, traits)
	local species = Catalog.Fish[id]
	local holder = make("Frame", parent, {
		BackgroundColor3 = Color3.fromRGB(113, 128, 111),
		BackgroundTransparency = 0.65,
		Size = UDim2.new(1, 0, 0, 78),
		BorderSizePixel = 0,
	})
	for key, value in props or {} do
		holder[key] = value
	end
	round(holder, 7)
	local surface = parent
	while surface and not surface:GetAttribute("BookSurface") do
		surface = surface.Parent
	end
	if surface and holder.BackgroundTransparency ~= 1 then
		holder.BackgroundColor3 = Color3.fromRGB(159, 151, 115)
		holder.BackgroundTransparency = 0
		Theme.corner(holder, 1)
		local wash = Instance.new("UIGradient")
		wash.Color = ColorSequence.new(Color3.fromRGB(231, 223, 191), Color3.fromRGB(145, 139, 113))
		wash.Rotation = 90
		wash.Parent = holder
	end
	if species and species.Image and species.Image ~= "" then
		make("ImageLabel", holder, {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = species.Image,
			ImageColor3 = if silhouette then Book.Ink else Color3.new(1, 1, 1),
			ScaleType = Enum.ScaleType.Fit,
		})
	elseif species and FishModels and FishModels.has(id) then
		local view = make("ViewportFrame", holder, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
		if silhouette then
			view.ImageColor3 = Book.Ink
		end
		FishModels.show(view, id, silhouette, traits)
	else
		text(
			holder,
			if silhouette then "?" elseif species then species.Name else "No catch yet",
			14,
			ink,
			{ Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center }
		)
	end
	return holder
end

function Menu.start()
	if started then
		return
	end
	started = true
	Settings.start()
	local player = Players.LocalPlayer
	local remote = ReplicatedStorage:WaitForChild("AnglerMenu") :: RemoteFunction
	local profile = nil
	local active = nil
	local settingTab, journalTab = "Performance", "Stats"
	local homeTab = "Paths"
	local freezerCapacity, pantryCapacity = 0, 0
	local busy = false
	local render
	local narrow = false
	-- Kept outside render so progress refreshes don't snap the book back to page one.
	local bestiaryPage, bestiaryQuery = 1, ""
	local journalCollapsed = {}
	local turnBestiary
	local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), {
		Name = "PlayerMenu",
		ResetOnSpawn = false,
		DisplayOrder = 30,
		-- Cover the world behind the Roblox top bar when a menu is open.
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local sidebar = make("Frame", gui, {
		Name = "LeftNavigation",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0.45, -162),
		Size = UDim2.fromOffset(172, 334),
	})
	list(sidebar, 8)
	local function refreshNavigation()
		sidebar.Visible = active == nil and player:GetAttribute("DrydockScreenOpen") ~= true
		if not sidebar.Visible and GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(sidebar) then
			GuiService.SelectedObject = nil
		end
	end
	player:GetAttributeChangedSignal("DrydockScreenOpen"):Connect(refreshNavigation)
	refreshNavigation()
	local overlay = make("TextButton", gui, {
		Name = "MenuOverlay",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.35,
		Visible = false,
	})
	local card = make("Frame", overlay, {
		Name = "MenuWindow",
		Active = true,
		BackgroundColor3 = navy,
		BackgroundTransparency = 0.04,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -28, 1, -28),
	})
	make("UISizeConstraint", card, { MaxSize = Vector2.new(1020, 680) })
	Theme.window(card)
	local bookChrome = make("Frame", card, {
		Name = "BookChrome",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	})
	local shadow = bookPart(bookChrome, "BookShadow", Color3.new(), UDim2.fromOffset(5, 12), UDim2.new(1, 8, 1, 0), 14)
	shadow.BackgroundTransparency = 0.55
	local leatherCover =
		bookPart(bookChrome, "LeatherCover", Book.Leather, UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), 9)
	local leaves = {}
	for _, side in { 0, 1 } do
		for layer = 4, 1, -1 do
			bookPart(
				bookChrome,
				"PageEdges" .. side .. layer,
				if layer % 2 == 0 then Book.Edge else Book.Paper,
				UDim2.new(side * 0.5, 18 + layer * 2, 0, 14 + layer * 2),
				UDim2.new(0.5, -40, 1, -36),
				20
			)
		end
		local page = bookPart(
			bookChrome,
			if side == 0 then "LeftLeaf" else "RightLeaf",
			Book.Page,
			UDim2.new(side * 0.5, if side == 0 then 18 else -3, 0, 12),
			UDim2.new(0.5, -15, 1, -34),
			26
		)
		paperFinish(page, side == 1)
		leaves[side + 1] = page
		-- Sparse fibers and edge marks suggest worn paper without competing with text.
		for index = 1, 28 do
			local fiber = bookPart(
				page,
				"PaperFiber" .. index,
				Book.Edge,
				UDim2.fromScale(0.06 + ((index * 37) % 89) / 100, 0.03 + ((index * 23) % 93) / 100),
				UDim2.fromOffset(2 + index % 4, 1)
			)
			fiber.BackgroundTransparency = 0.88
		end
		for _, y in { 0, 1 } do
			bookPart(
				page,
				"MarginRule" .. y,
				Book.Edge,
				UDim2.new(0, 26, y, if y == 0 then 69 else -24),
				UDim2.new(1, -58, 0, 1)
			)
		end
	end
	local binding =
		bookPart(bookChrome, "CenterBinding", Book.Ink, UDim2.new(0.5, -18, 0, 22), UDim2.new(0, 36, 1, -53), 18)
	local gutter = Instance.new("UIGradient")
	gutter.Color = ColorSequence.new(Book.Paper, Book.Ink)
	gutter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	gutter.Parent = binding
	for index = 1, 12 do
		local loop = bookPart(
			binding,
			"BindingLoop" .. index,
			Book.Ink,
			UDim2.new(0.5, -22, (index - 0.5) / 12, -5),
			UDim2.fromOffset(44, 10),
			5
		)
		loop.Rotation = -5
		local highlight =
			bookPart(loop, "ThreadHighlight", Book.Edge, UDim2.fromOffset(3, 1), UDim2.new(1, -6, 0, 2), 1)
		highlight.BackgroundTransparency = 0.45
	end
	for _, point in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		local corner = bookPart(
			bookChrome,
			"BrassCorner",
			Book.Gold,
			UDim2.new(point.X, if point.X == 0 then 3 else -3, point.Y, if point.Y == 0 then 3 else -3),
			UDim2.fromOffset(13, 13),
			2
		)
		corner.AnchorPoint = point
	end
	bookPart(bookChrome, "RibbonBookmark", Book.Bestiary, UDim2.new(1, -88, 0, 0), UDim2.fromOffset(18, 38))
	local heading = text(card, "", 26, cream, {
		Position = UDim2.fromOffset(60, 8),
		Size = UDim2.new(1, -120, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local subtitle = text(card, "", 13, muted, { Position = UDim2.fromOffset(24, 53), Size = UDim2.new(1, -48, 0, 34) })
	local content = make("Frame", card, {
		Name = "Content",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(20, 98),
		Size = UDim2.new(1, -40, 1, -142),
	})
	local notice = text(
		card,
		"",
		13,
		gold,
		{ Name = "MenuStatus", Position = UDim2.new(0, 24, 1, -37), Size = UDim2.new(1, -48, 0, 30) }
	)
	local navButtons = {}
	local layoutWindow
	local function refreshSelection()
		for name, item in navButtons do
			if name == "Bestiary" or name == "Journal" then
				bookButton(item, name == active)
			else
				navButton(item, name == active)
			end
		end
	end
	local function close()
		if active == "Home" then
			content:ClearAllChildren()
		end
		active = nil
		overlay.Visible = false
		player:SetAttribute("PlayerMenuOpen", false)
		refreshSelection()
		if layoutWindow then
			layoutWindow()
		end
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(card) then
			GuiService.SelectedObject = nil
		end
	end
	local closeButton = button(
		card,
		"×",
		close,
		{ Name = "CloseMenu", Position = UDim2.new(1, -53, 0, 12), Size = UDim2.fromOffset(40, 40), TextSize = 28 }
	)
	Theme.button(closeButton, "Danger")
	overlay.Activated:Connect(close)
	local nextRequestAt = 0
	local function request(action, key, value)
		if busy then
			return
		end
		busy = true
		notice.Text = if action == "Get" then "Loading your progress…" else "Saving…"
		task.spawn(function()
			local delay = nextRequestAt - os.clock()
			if delay > 0 then
				task.wait(delay)
			end
			local ok, result = pcall(function()
				return remote:InvokeServer(action, key, value)
			end)
			nextRequestAt = os.clock() + 0.3
			busy = false
			if ok and type(result) == "table" then
				freezerCapacity = result.FreezerCapacity or freezerCapacity
				pantryCapacity = result.PantryCapacity or pantryCapacity
				if result.Profile then
					profile = result.Profile
					Settings.apply(profile.Angler.Settings)
				end
				notice.Text = result.Message or ""
			else
				notice.Text = "Could not reach your progress. Close and reopen to try again."
			end
			if player:GetAttribute("WalletSessionOnly") and notice.Text == "" then
				notice.Text = "Studio session · progress resets when this server stops."
			end
			if active then
				render()
			end
		end)
	end
	local function bestiary()
		-- One species per page: a two-page spread on wide screens, a single page when narrow.
		local spread = if narrow then 1 else 2
		local pages = {}
		for side = 1, spread do
			pages[side] = make("Frame", content, {
				Name = "BestiaryPage" .. side,
				BackgroundTransparency = 1,
				Position = if narrow
					then UDim2.fromOffset(12, 0)
					elseif side == 1 then UDim2.fromOffset(14, 0)
					else UDim2.new(0.5, 34, 0, 0),
				Size = if narrow then UDim2.new(1, -24, 1, 0) else UDim2.new(0.5, -48, 1, 0),
			})
		end
		local function label(parent, value, size, props, fade)
			local item = text(parent, value, size, Book.Ink, props)
			item.TextColor3 = Book.Ink
			item.TextTransparency = fade or 0
			return item
		end
		local function rule(parent, position, width)
			local line = decoration(parent, "Rule", Book.Edge, position, UDim2.fromOffset(width, 1))
			line.AnchorPoint = Vector2.new(0.5, 0.5)
			line.BackgroundTransparency = 0.35
			return line
		end

		-- The search field is ink on the page: no box, only a ruled line to write on.
		local search = input(pages[1], "Search the bestiary…")
		search.BackgroundTransparency = 1
		search.Size = UDim2.new(1, 0, 0, 34)
		search.Text = bestiaryQuery
		search.TextSize = 17
		search.PlaceholderColor3 = Book.Edge
		search:FindFirstChild("ThemeBorder").Enabled = false
		local searchLine = decoration(search, "SearchLine", Book.Edge, UDim2.new(0, -12, 1, -1), UDim2.new(1, 24, 0, 1))
		searchLine.BackgroundTransparency = 0.4
		search.Focused:Connect(function()
			searchLine.BackgroundColor3, searchLine.BackgroundTransparency = Book.Ink, 0
		end)
		search.FocusLost:Connect(function()
			searchLine.BackgroundColor3, searchLine.BackgroundTransparency = Book.Edge, 0.4
		end)

		local all = {}
		local discovered = 0
		for id in Catalog.Fish do
			table.insert(all, id)
			local entry = profile.Angler.Catches[id]
			if entry and (entry.Count or 0) > 0 then
				discovered += 1
			end
		end
		table.sort(all, function(a, b)
			local rankA = (Catalog.Rarities[Catalog.Fish[a].Rarity] or {}).Order or 0
			local rankB = (Catalog.Rarities[Catalog.Fish[b].Rarity] or {}).Order or 0
			if rankA ~= rankB then
				return rankA < rankB
			end
			return Catalog.Fish[a].Name < Catalog.Fish[b].Name
		end)
		local number = {}
		for index, id in all do
			number[id] = index
		end
		if not narrow then
			label(pages[2], string.format("FIELD NOTES   ·   %d of %d discovered", discovered, #all), 14, {
				Size = UDim2.new(1, 0, 0, 34),
				TextXAlignment = Enum.TextXAlignment.Center,
			}, 0.25)
		end

		local sheets, footers = {}, {}
		for side, page in pages do
			sheets[side] = make("Frame", page, {
				Name = "Sheet",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 50),
				Size = UDim2.new(1, 0, 1, -94),
			})
			footers[side] = make("Frame", page, {
				Name = "Footer",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 0, 1, -38),
				Size = UDim2.new(1, 0, 0, 30),
			})
		end

		local function entryPage(sheet, id)
			local species = Catalog.Fish[id]
			local entry = profile.Angler.Catches[id]
			local known = entry ~= nil and (entry.Count or 0) > 0
			local rarity = Catalog.Rarities[species.Rarity]
			local tag = label(
				sheet,
				string.format("No. %02d", number[id])
					.. (if known then "   ·   " .. string.upper(rarity and rarity.Name or species.Rarity) else ""),
				13,
				{
					Size = UDim2.new(1, 0, 0, 20),
					TextXAlignment = Enum.TextXAlignment.Center,
				},
				0.15
			)
			tag.TextColor3 = Book.Leather

			-- A double-ruled plate, like an engraving tipped into a field guide.
			local plate = make("Frame", sheet, {
				Name = "Plate",
				BackgroundTransparency = 1,
				Position = UDim2.new(0.07, 0, 0, 28),
				Size = UDim2.new(0.86, 0, 0.4, 0),
			})
			plate.BackgroundColor3, plate.BackgroundTransparency = Book.Edge, if known then 0.86 else 0.9
			Theme.corner(plate, 2)
			local outer = Instance.new("UIStroke")
			outer.Color, outer.Transparency, outer.Thickness = Book.Edge, 0.25, 1
			outer.Parent = plate
			local inner = make("Frame", plate, {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(5, 5),
				Size = UDim2.new(1, -10, 1, -10),
			})
			local innerStroke = Instance.new("UIStroke")
			innerStroke.Color, innerStroke.Transparency, innerStroke.Thickness = Book.Edge, 0.6, 1
			innerStroke.Parent = inner
			local art = picture(inner, id, {
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.05, 0.06),
				Size = UDim2.fromScale(0.9, 0.88),
			}, not known)
			local artEdge = art:FindFirstChild("ThemeBorder")
			if artEdge then
				artEdge.Enabled = false
			end

			label(sheet, if known then species.Name else "Undiscovered", 30, {
				Position = UDim2.new(0, 0, 0.4, 38),
				Size = UDim2.new(1, 0, 0, 36),
				TextXAlignment = Enum.TextXAlignment.Center,
			}, if known then 0 else 0.45)
			rule(sheet, UDim2.new(0.5, -44, 0.4, 84), 70)
			rule(sheet, UDim2.new(0.5, 44, 0.4, 84), 70)
			local diamond =
				decoration(sheet, "Ornament", Book.Leather, UDim2.new(0.5, 0, 0.4, 84), UDim2.fromOffset(6, 6))
			diamond.AnchorPoint, diamond.Rotation = Vector2.new(0.5, 0.5), 45

			local stats = {
				{ "CAUGHT", if known then tostring(entry.Count) else "—" },
				{ "BIGGEST", if known then string.format("%.2f kg", entry.BiggestKg) else "—" },
				{ "SIZE RANGE", if known then string.format("%g–%g kg", species.MinKg, species.MaxKg) else "—" },
			}
			for column, stat in stats do
				local x = (column - 1) / #stats
				label(sheet, stat[1], 12, {
					Position = UDim2.new(x, 0, 0.4, 98),
					Size = UDim2.new(1 / #stats, 0, 0, 16),
					TextXAlignment = Enum.TextXAlignment.Center,
				}, 0.4)
				label(sheet, stat[2], 20, {
					Position = UDim2.new(x, 0, 0.4, 114),
					Size = UDim2.new(1 / #stats, 0, 0, 26),
					TextXAlignment = Enum.TextXAlignment.Center,
				})
				if column > 1 then
					local divider =
						decoration(sheet, "StatDivider", Book.Edge, UDim2.new(x, 0, 0.4, 102), UDim2.fromOffset(1, 34))
					divider.BackgroundTransparency = 0.6
				end
			end

			if not known then
				label(sheet, "Land one of these to fill in this page.", 15, {
					Position = UDim2.new(0.1, 0, 0.4, 158),
					Size = UDim2.new(0.8, 0, 0, 44),
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Top,
				}, 0.4)
				return
			end
			local mutationNames = {}
			for mutation, count in entry.Mutations or {} do
				local info = Catalog.Mutations[mutation]
				table.insert(mutationNames, (info and info.Name or mutation) .. " ×" .. count)
			end
			table.sort(mutationNames)
			label(sheet, "MUTATIONS", 12, {
				Position = UDim2.new(0, 0, 0.4, 154),
				Size = UDim2.new(1, 0, 0, 16),
				TextXAlignment = Enum.TextXAlignment.Center,
			}, 0.4)
			local notes =
				scroll(sheet, { Position = UDim2.new(0.08, 0, 0.4, 172), Size = UDim2.new(0.84, 0, 0.6, -172) })
			label(
				notes,
				if #mutationNames > 0 then table.concat(mutationNames, "   ·   ") else "None recorded yet",
				15,
				{
					Size = UDim2.new(1, -8, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Top,
				},
				0.1
			)
		end

		local function pageButton(parent, value, alignment, onActivated)
			local item = make("TextButton", parent, {
				Name = "PageTurn",
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = value,
				Font = Enum.Font.Garamond,
				TextSize = 18,
				TextColor3 = Book.Leather,
				TextXAlignment = alignment,
				Position = if alignment == Enum.TextXAlignment.Left then UDim2.new() else UDim2.new(1, -110, 0, 0),
				Size = UDim2.new(0, 110, 1, 0),
			})
			item.MouseEnter:Connect(function()
				item.TextColor3 = Book.Ink
			end)
			item.MouseLeave:Connect(function()
				item.TextColor3 = Book.Leather
			end)
			item.Activated:Connect(onActivated)
			return item
		end

		local fill
		local spreads = 1
		turnBestiary = function(step)
			local target = math.clamp(bestiaryPage + step, 1, spreads)
			if target ~= bestiaryPage then
				bestiaryPage = target
				fill()
			end
		end
		fill = function()
			local query = string.lower(bestiaryQuery)
			local ids = {}
			for _, id in all do
				local entry = profile.Angler.Catches[id]
				if query == "" then
					table.insert(ids, id)
				elseif entry and (entry.Count or 0) > 0 then
					-- Only discovered pages are searchable, so search can't spoil a species.
					local haystack = Catalog.Fish[id].Name
					for mutation in entry.Mutations or {} do
						local info = Catalog.Mutations[mutation]
						haystack ..= " " .. (info and info.Name or mutation)
					end
					if string.find(string.lower(haystack), query, 1, true) then
						table.insert(ids, id)
					end
				end
			end
			spreads = math.max(1, math.ceil(#ids / spread))
			bestiaryPage = math.clamp(bestiaryPage, 1, spreads)
			for side = 1, spread do
				sheets[side]:ClearAllChildren()
				footers[side]:ClearAllChildren()
			end
			if #ids == 0 then
				local blank = if next(Catalog.Fish)
					then "No discovered fish match that search."
					else "New species will appear here as they are added."
				label(sheets[1], blank, 18, {
					Position = UDim2.fromScale(0.1, 0.3),
					Size = UDim2.new(0.8, 0, 0, 60),
					TextXAlignment = Enum.TextXAlignment.Center,
				}, 0.35)
				return
			end
			local first = (bestiaryPage - 1) * spread
			for side = 1, spread do
				local index = first + side
				if ids[index] then
					entryPage(sheets[side], ids[index])
					label(footers[side], tostring(index), 14, {
						Size = UDim2.fromScale(1, 1),
						TextXAlignment = Enum.TextXAlignment.Center,
					}, 0.45)
				end
			end
			if bestiaryPage > 1 then
				pageButton(footers[1], "‹  Previous", Enum.TextXAlignment.Left, function()
					turnBestiary(-1)
				end)
			end
			if bestiaryPage < spreads then
				pageButton(footers[spread], "Next  ›", Enum.TextXAlignment.Right, function()
					turnBestiary(1)
				end)
			end
		end
		search:GetPropertyChangedSignal("Text"):Connect(function()
			if search.Text ~= bestiaryQuery then
				bestiaryQuery, bestiaryPage = search.Text, 1
				fill()
			end
		end)
		fill()
	end
	local function equipment()
		EquipmentBag.show(content, profile, player, card.AbsoluteSize.X < 1000)
	end
	local function journal()
		-- A hand-lettered field journal: profile and stats on the left, findings on the right.
		local hand = Enum.Font.PatrickHand
		local frameInk = Color3.fromRGB(104, 92, 70)
		local function write(parent, value, size, props, color, font)
			local item = text(parent, value, size, Book.Ink, props)
			item.Font = font or hand
			item.TextColor3 = color or Book.Ink
			return item
		end
		local function box(parent, name, color, position, size, radius, strokeColor, thickness)
			local item = decoration(parent, name, color, position, size)
			if radius then
				Theme.corner(item, radius)
			end
			if strokeColor then
				local stroke = Instance.new("UIStroke")
				stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				stroke.Color, stroke.Thickness = strokeColor, thickness or 2
				stroke.Parent = item
			end
			return item
		end
		local function rule(parent, y)
			local line = decoration(parent, "Rule", Book.Ink, UDim2.fromOffset(0, y), UDim2.new(1, 0, 0, 2))
			line.BackgroundTransparency = 0.55
		end

		local book = if narrow then scroll(content) else content
		local left = make("Frame", book, {
			Name = "JournalStatsPage",
			BackgroundTransparency = 1,
			Position = if narrow then UDim2.new() else UDim2.fromOffset(14, 0),
			Size = if narrow then UDim2.new(1, -8, 0, 600) else UDim2.new(0.5, -44, 1, 0),
		})
		local right = make("Frame", book, {
			Name = "JournalFindingsPage",
			BackgroundTransparency = 1,
			Position = if narrow then UDim2.fromOffset(0, 618) else UDim2.new(0.5, 30, 0, 0),
			Size = if narrow then UDim2.new(1, -8, 0, 560) else UDim2.new(0.5, -44, 1, 0),
		})

		-- Title: the inked check box doubles as the close control, like a ticked-off page.
		rule(left, 0)
		local tick = make("TextButton", left, {
			Name = "CloseJournal",
			Text = "✕",
			Font = hand,
			TextSize = 24,
			TextColor3 = Book.Leather,
			AutoButtonColor = false,
			BackgroundColor3 = Book.Paper,
			BackgroundTransparency = 0.4,
			Position = UDim2.fromOffset(6, 12),
			Size = UDim2.fromOffset(30, 30),
		})
		local tickStroke = Instance.new("UIStroke")
		tickStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		tickStroke.Color, tickStroke.Thickness = Book.Ink, 2
		tickStroke.Parent = tick
		tick.MouseEnter:Connect(function()
			tick.TextColor3 = Book.Ink
		end)
		tick.MouseLeave:Connect(function()
			tick.TextColor3 = Book.Leather
		end)
		tick.Activated:Connect(close)
		write(left, "Angler's Journal", 34, { Position = UDim2.fromOffset(48, 6), Size = UDim2.new(1, -54, 0, 44) })
		rule(left, 54)

		local avatar = make("ImageLabel", left, {
			Name = "Portrait",
			BackgroundColor3 = Book.Paper,
			Position = UDim2.fromOffset(6, 68),
			Size = UDim2.fromOffset(80, 80),
		})
		avatar.BackgroundColor3 = Color3.fromRGB(196, 184, 156)
		avatar.ThemeBorder.Color, avatar.ThemeBorder.Thickness, avatar.ThemeBorder.Transparency = frameInk, 3, 0
		task.spawn(function()
			local ok, image = pcall(function()
				return Players:GetUserThumbnailAsync(
					player.UserId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size150x150
				)
			end)
			if ok and avatar.Parent then
				avatar.Image = image
			end
		end)
		write(left, player.DisplayName, 26, {
			Position = UDim2.fromOffset(100, 74),
			Size = UDim2.new(1, -184, 0, 32),
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
		})
		write(left, "Lv. " .. (player:GetAttribute("Level") or 1), 26, {
			Position = UDim2.new(1, -84, 0, 74),
			Size = UDim2.fromOffset(80, 32),
			TextXAlignment = Enum.TextXAlignment.Right,
		}, Color3.fromRGB(150, 118, 52))
		write(left, "@" .. player.Name, 15, {
			Position = UDim2.fromOffset(100, 106),
			Size = UDim2.new(1, -104, 0, 22),
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
		}, nil, Enum.Font.RobotoMono)
		rule(left, 160)

		local search = make("TextBox", left, {
			Name = "JournalSearch",
			Text = "",
			PlaceholderText = "Search...",
			ClearTextOnFocus = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 20,
			Position = UDim2.fromOffset(0, 174),
			Size = UDim2.new(0.5, -8, 0, 34),
		})
		search.Font, search.TextColor3, search.PlaceholderColor3 = hand, Book.Ink, Book.Edge
		search.BackgroundColor3, search.BackgroundTransparency = Color3.fromRGB(214, 200, 160), 0
		Theme.corner(search, 10)
		local searchStroke = Instance.new("UIStroke")
		searchStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		searchStroke.Color, searchStroke.Thickness = Book.Edge, 2
		searchStroke.Parent = search
		make("UIPadding", search, { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) })

		-- Segmented Stats / Achievements switch.
		local toggle =
			box(left, "JournalTabs", Book.Paper, UDim2.new(0.5, 8, 0, 174), UDim2.new(0.5, -8, 0, 34), 17, Book.Edge, 2)
		local tabButtons = {}
		local fill
		local function refreshTabs()
			for tab, item in tabButtons do
				item.BackgroundTransparency = if tab == journalTab then 0 else 1
				item.TextSize = if tab == journalTab then 21 else 17
			end
		end
		for index, tab in { "Stats", "Achievements" } do
			local item = make("TextButton", toggle, {
				Name = tab .. "Tab",
				Text = tab,
				Font = hand,
				TextColor3 = Book.Ink,
				AutoButtonColor = false,
				BackgroundColor3 = Color3.fromRGB(252, 234, 192),
				Position = UDim2.new((index - 1) * 0.5, 2, 0, 2),
				Size = UDim2.new(0.5, -4, 1, -4),
			})
			Theme.corner(item, 15)
			item.Activated:Connect(function()
				if journalTab ~= tab then
					journalTab = tab
					refreshTabs()
					fill()
				end
			end)
			tabButtons[tab] = item
		end
		refreshTabs()

		local ledger = box(
			left,
			"StatsLedger",
			Color3.fromRGB(226, 215, 190),
			UDim2.fromOffset(0, 220),
			UDim2.new(1, 0, 1, -224),
			2,
			frameInk,
			3
		)
		local rows = scroll(ledger, {
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(1, -8, 1, -8),
		})
		rows.ScrollBarImageColor3, rows.ScrollBarThickness = frameInk, 6
		list(rows, 0)

		fill = function()
			for _, child in rows:GetChildren() do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
			local stats = profile.Angler.Stats
			local entries
			if journalTab == "Stats" then
				local discovered = 0
				for _, entry in profile.Angler.Catches do
					if entry.Count > 0 then
						discovered += 1
					end
				end
				entries = {
					{ "Astral Anomalies Activated", stats.AstralAnomaliesActivated },
					{
						"Bestiary Pages Completed",
						stats.BestiaryPagesCompleted,
						{
							{ "Limited Bestiaries Completed", stats.LimitedBestiariesCompleted },
							{ "Permanent Bestiaries Completed", stats.PermanentBestiariesCompleted },
						},
					},
					{ "Fish Caught", stats.TotalCaught, { { "Species Discovered", discovered } } },
					{ "Catch Streak", stats.CatchStreak, { { "Highest Catch Streak", stats.HighestCatchStreak } } },
					{
						"Treasure Chests Opened",
						stats.TreasureChestsOpened,
						{ { "Sunken Chests Opened", stats.SunkenChestsOpened } },
					},
					{
						"Coins",
						profile.Cash,
						{
							{ "Lifetime Coins Earned", stats.CoinsEarned },
							{ "Lifetime Coins Spent", stats.CoinsSpent },
						},
					},
					{ "Crab Cages Opened", stats.CrabCagesOpened },
					{ "Deaths", stats.Deaths },
				}
			else
				local function goal(target)
					return if stats.TotalCaught >= target
						then "Complete"
						else commas(stats.TotalCaught) .. " / " .. commas(target)
				end
				entries = {
					{ "First Catch", goal(1) },
					{ "Getting the Hang of It", goal(10) },
					{ "Seasoned Angler", goal(100) },
				}
			end

			local query = string.lower(search.Text)
			local function matches(entry)
				return string.find(string.lower(entry[1]), query, 1, true) ~= nil
			end
			local shown = 0
			local function row(entry, child, children)
				shown += 1
				local line = decoration(rows, "Row", Book.Edge, UDim2.new(), UDim2.new(1, -8, 0, 28))
				line.LayoutOrder = shown
				line.BackgroundTransparency = if shown % 2 == 0 then 0.8 else 1
				local x = if child then 30 else 6
				if child then
					local thread =
						decoration(line, "TreeLine", Book.Edge, UDim2.fromOffset(15, 0), UDim2.new(0, 1, 1, 0))
					thread.BackgroundTransparency = 0.25
				end
				local marker = if children
					then (if journalCollapsed[entry[1]] and query == "" then "▼" else "▲")
					else "•"
				write(line, marker, if children then 13 else 20, {
					Position = UDim2.fromOffset(x, 0),
					Size = UDim2.new(0, 14, 1, 0),
					TextXAlignment = Enum.TextXAlignment.Center,
				})
				write(line, entry[1], 20, {
					Position = UDim2.fromOffset(x + 20, 0),
					Size = UDim2.new(0.72, -(x + 20), 1, 0),
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextWrapped = false,
				})
				write(line, if type(entry[2]) == "number" then commas(entry[2]) else tostring(entry[2] or 0), 20, {
					Position = UDim2.fromScale(0.72, 0),
					Size = UDim2.new(0.28, -8, 1, 0),
					TextXAlignment = Enum.TextXAlignment.Right,
				})
				if children then
					local hit = make("TextButton", line, {
						Name = "Collapse",
						Text = "",
						BackgroundTransparency = 1,
						AutoButtonColor = false,
						Size = UDim2.fromScale(1, 1),
					})
					hit.Activated:Connect(function()
						journalCollapsed[entry[1]] = not journalCollapsed[entry[1]] or nil
						fill()
					end)
				end
			end
			for _, entry in entries do
				local children = {}
				for _, child in entry[3] or {} do
					if query == "" or matches(entry) or matches(child) then
						table.insert(children, child)
					end
				end
				if query ~= "" and not matches(entry) and #children == 0 then
					continue
				end
				row(entry, false, if entry[3] then children else nil)
				if query ~= "" or not journalCollapsed[entry[1]] then
					for _, child in children do
						row(child, true)
					end
				end
			end
			if shown == 0 then
				write(rows, "Nothing written about that yet.", 20, {
					Size = UDim2.new(1, -8, 0, 40),
					TextXAlignment = Enum.TextXAlignment.Center,
					TextTransparency = 0.4,
				})
			end
		end
		search:GetPropertyChangedSignal("Text"):Connect(fill)
		fill()

		-- Findings: a double-ruled panel of specimen cards.
		local panel = box(
			right,
			"FindingsPanel",
			Color3.fromRGB(226, 215, 190),
			UDim2.new(),
			UDim2.fromScale(1, 1),
			2,
			frameInk,
			3
		)
		box(panel, "InnerRule", Color3.new(), UDim2.fromOffset(5, 5), UDim2.new(1, -10, 1, -10), 1, frameInk, 1).BackgroundTransparency =
			1
		write(panel, "FINDINGS", 30, {
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.new(1, 0, 0, 36),
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		local shelf = scroll(panel, { Position = UDim2.fromOffset(14, 46), Size = UDim2.new(1, -20, 1, -54) })
		shelf.ScrollBarImageColor3, shelf.ScrollBarThickness = frameInk, 6

		local findings = profile.Angler.Findings
		local mostId, mostCount = nil, 0
		for id, entry in profile.Angler.Catches do
			if entry.Count > mostCount then
				mostId, mostCount = id, entry.Count
			end
		end
		local function richName(record)
			local fish = Catalog.Fish[record.FishId]
			local prefix = if record.Mutation and record.Mutation ~= "Normal" then mutationName(record) .. " " else ""
			return prefix .. '<font color="#A6D8F2">' .. (fish and fish.Name or record.FishId) .. "</font>"
		end
		local cards = {
			{
				"Highest Value",
				findings.HighestValue,
				function(r)
					return "$" .. commas(math.floor(r.Value + 0.5))
				end,
			},
			{
				"Rarest",
				findings.Rarest,
				function(r)
					return "1 in " .. commas(r.Rarity)
				end,
			},
			{
				"Most Caught",
				mostId and { FishId = mostId, Mutation = "Normal" },
				function()
					return commas(mostCount) .. " Caught"
				end,
			},
			{
				"Largest",
				findings.Largest,
				function(r)
					return string.format("%.2f kg", r.Kg)
				end,
			},
			{
				"Relative Largest",
				findings.RelativeLargest,
				function(r)
					return string.format("%.2f kg (%.2f×)", r.Kg, r.Relative)
				end,
			},
		}
		local cardHeight = 128
		for i, entry in cards do
			local full = i == 1
			local x = if full or i % 2 == 0 then 0 else 0.5
			local y = if full then 0 else (cardHeight + 46) * (1 + math.floor((i - 2) / 2))
			local slot = make("Frame", shelf, {
				Name = entry[1]:gsub(" ", ""),
				BackgroundTransparency = 1,
				Position = UDim2.new(x, if full or x == 0 then 0 else 6, 0, y),
				Size = UDim2.new(if full then 1 else 0.5, if full then -10 else -16, 0, cardHeight + 34),
			})
			write(slot, "—  " .. entry[1] .. "  —", if #entry[1] > 12 then 17 else 20, {
				Size = UDim2.new(1, 0, 0, 26),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextWrapped = false,
			})
			local plate = box(
				slot,
				"Specimen",
				Color3.new(1, 1, 1),
				UDim2.fromOffset(2, 32),
				UDim2.new(1, -4, 0, cardHeight),
				2,
				Color3.fromRGB(88, 80, 58),
				3
			)
			local wash = Instance.new("UIGradient")
			wash.Color = ColorSequence.new(Color3.fromRGB(176, 166, 128), Color3.fromRGB(118, 110, 82))
			wash.Rotation = 90
			wash.Parent = plate
			local r = entry[2]
			if r then
				local art = picture(plate, r.FishId, {
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.15, 0.18),
					Size = UDim2.fromScale(0.7, 0.62),
				}, nil, r)
				local artEdge = art:FindFirstChild("ThemeBorder")
				if artEdge then
					artEdge.Enabled = false
				end
			end
			for _, caption in
				{
					{ if r then richName(r) else "No catch yet", UDim2.fromOffset(8, 4) },
					{ if r then entry[3](r) else "", UDim2.new(0, 8, 1, -28) },
				}
			do
				local label = write(plate, caption[1], 19, {
					Position = caption[2],
					Size = UDim2.new(1, -16, 0, 24),
					RichText = true,
					TextWrapped = false,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}, Color3.new(1, 1, 1))
				label.TextStrokeColor3, label.TextStrokeTransparency = Color3.fromRGB(40, 34, 24), 0.55
			end
		end
	end
	-- Home ▸ Paths: the business road from fish shop to company. Stage rules live in
	-- Shared.Paths; this only draws them from the saved profile.
	local function paths(body, nextOrder)
		local state = Paths.state(profile.Angler)
		local choices = Paths.choices(profile)
		local function auto(class, parent, props)
			props.BackgroundTransparency = props.BackgroundTransparency or 1
			props.AutomaticSize = Enum.AutomaticSize.Y
			return make(class, parent, props)
		end
		local function stack(parent, gap)
			make("UIListLayout", parent, {
				Padding = UDim.new(0, gap),
				SortOrder = Enum.SortOrder.LayoutOrder,
			})
		end
		local function wrapped(parent, value, size, color, layoutOrder, props)
			local item = text(parent, value, size, color, {
				LayoutOrder = layoutOrder,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextYAlignment = Enum.TextYAlignment.Top,
			})
			for key, setting in props or {} do
				item[key] = setting
			end
			return item
		end
		local function goalRow(parent, goal, layoutOrder)
			local current, target = Paths.goalProgress(goal, profile)
			local done = current >= target
			local row = make("Frame", parent, {
				Name = "Goal",
				BackgroundTransparency = 1,
				LayoutOrder = layoutOrder,
				Size = UDim2.new(1, 0, 0, 40),
			})
			text(row, (if done then "✓  " else "○  ") .. Paths.goalText(goal), 14, if done then green else cream, {
				Size = UDim2.new(1, -110, 0, 22),
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextWrapped = false,
			})
			local count = if goal.Money
				then "$" .. commas(current) .. " / $" .. commas(target)
				elseif target > 1 then commas(current) .. " / " .. commas(target)
				else (if done then "Done" else "Not yet")
			text(row, count, 12, muted, {
				Position = UDim2.new(1, -108, 0, 2),
				Size = UDim2.fromOffset(108, 20),
				TextXAlignment = Enum.TextXAlignment.Right,
			})
			local track = decoration(row, "GoalTrack", Theme.Colors.Inset, UDim2.fromOffset(0, 28), UDim2.new(1, 0, 0, 6))
			Theme.corner(track, 3)
			local fill = decoration(track, "GoalFill", if done then green else gold, UDim2.new(), UDim2.fromScale(math.clamp(current / target, 0, 1), 1))
			Theme.corner(fill, 3)
		end
		local function stageCard(parent, id, number, layoutOrder, width)
			local stage = Paths.Stages[id]
			local completed = state.Completed[id] == true
			local current = state.Active == id
			local progress = Paths.progress(profile, id)
			local available = table.find(choices, id) ~= nil
			local card = auto("Frame", parent, {
				Name = id .. "Stage",
				BackgroundTransparency = 0,
				BackgroundColor3 = paper,
				LayoutOrder = layoutOrder,
				Size = width or UDim2.new(1, -10, 0, 0),
			})
			make("UIPadding", card, {
				PaddingTop = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 14),
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 14),
			})
			stack(card, 8)
			local header = make("Frame", card, {
				Name = "Header",
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 48),
			})
			local node = decoration(
				header,
				"StageNode",
				if completed then green elseif current then gold elseif available then cream else Theme.Colors.Inset,
				UDim2.fromOffset(0, 2),
				UDim2.fromOffset(44, 44)
			)
			Theme.corner(node, 22)
			text(node, if completed then "✓" else tostring(number), 20, if completed or current or available then navy else muted, {
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				Font = Enum.Font.GothamBold,
			})
			text(header, stage.Name, 19, cream, {
				Position = UDim2.fromOffset(56, 0),
				Size = UDim2.new(1, -150, 0, 26),
				Font = Enum.Font.GothamBold,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextWrapped = false,
			})
			text(header, stage.Tagline, 12, muted, {
				Position = UDim2.fromOffset(56, 26),
				Size = UDim2.new(1, -150, 0, 18),
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextWrapped = false,
			})
			local badge = if completed
				then "Completed"
				elseif current then math.floor(progress * 100) .. "%"
				elseif available then "$" .. commas(stage.Price)
				else "Locked"
			text(header, badge, if current then 22 else 13, if completed then green elseif current then gold else muted, {
				Position = UDim2.new(1, -92, 0, 6),
				Size = UDim2.fromOffset(92, 30),
				TextXAlignment = Enum.TextXAlignment.Right,
				Font = Enum.Font.GothamBold,
			})
			wrapped(card, stage.Description, 13, muted, 2)
			if current or completed then
				wrapped(card, "Unlocked: " .. table.concat(stage.Features, " · "), 12, cream, 3)
			end
			if current then
				local track = decoration(card, "StageTrack", Theme.Colors.Inset, UDim2.new(), UDim2.new(1, 0, 0, 10))
				track.LayoutOrder = 4
				Theme.corner(track, 5)
				local fill = decoration(track, "StageFill", if progress >= 1 then green else gold, UDim2.new(), UDim2.fromScale(progress, 1))
				Theme.corner(fill, 5)
				for index, goal in stage.Goals do
					goalRow(card, goal, 4 + index)
				end
				if progress >= 1 and #choices == 0 and Paths.finished(profile) then
					wrapped(card, "Every path is complete. Your business runs on all fronts!", 14, green, 20)
				elseif progress >= 1 then
					wrapped(card, "Stage complete! Choose your next path below.", 14, green, 20)
				end
			elseif available then
				local afford = profile.Cash >= stage.Price
				local choose = button(card, if afford then "Open " .. stage.Name .. " · $" .. commas(stage.Price) else "$" .. commas(stage.Price - profile.Cash) .. " more needed", function()
					if afford then
						request("ChoosePath", id)
					end
				end, {
					Name = "Choose" .. id,
					LayoutOrder = 20,
					Size = UDim2.new(1, 0, 0, 42),
					Active = afford,
					AutoButtonColor = afford,
					BackgroundColor3 = if afford then gold else navy,
				})
				Theme.glassButton(choose, if afford then "Selected" else "Disabled")
				choose.Selectable = afford
			elseif not completed then
				local needs = {}
				for _, required in stage.Requires do
					table.insert(needs, Paths.Stages[required].Name)
				end
				wrapped(card, "Opens after " .. table.concat(needs, " and ") .. " reaches 100%.", 12, muted, 20)
			end
			return card
		end
		local function road(layoutOrder)
			local segment = make("Frame", body, {
				Name = "Road",
				BackgroundTransparency = 1,
				LayoutOrder = layoutOrder,
				Size = UDim2.new(1, -10, 0, 18),
			})
			local strip = decoration(segment, "RoadStrip", Theme.Colors.Border, UDim2.fromOffset(34, 0), UDim2.new(0, 4, 1, 0))
			strip.BackgroundTransparency = 0.4
		end

		wrapped(
			body,
			"Grow your business one stage at a time. Stages stack, so everything you unlock keeps working. "
				.. "Reach 100% on your current stage to buy the next one.",
			14,
			muted,
			nextOrder()
		)
		-- The fork after the Supermarket: whichever branch was chosen comes first.
		local first, second = "Restaurant", "Company"
		if state.Unlocked.Company and not state.Unlocked.Restaurant then
			first, second = "Company", "Restaurant"
		end
		local forked = not state.Unlocked.Restaurant and not state.Unlocked.Company
		for index, id in { "Fishshop", "Supermarket" } do
			if index > 1 then
				road(nextOrder())
			end
			stageCard(body, id, index, nextOrder())
		end
		road(nextOrder())
		if forked then
			wrapped(body, "Choose a branch. The other one opens once your choice reaches 100%.", 13, gold, nextOrder(), {
				Font = Enum.Font.GothamBold,
			})
			local fork = auto("Frame", body, {
				Name = "PathFork",
				LayoutOrder = nextOrder(),
				Size = UDim2.new(1, -10, 0, 0),
			})
			make("UIListLayout", fork, {
				FillDirection = if narrow then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			})
			for index, id in { first, second } do
				stageCard(fork, id, 3, index, if narrow then UDim2.new(1, 0, 0, 0) else UDim2.new(0.5, -5, 0, 0))
			end
		else
			stageCard(body, first, 3, nextOrder())
			road(nextOrder())
			stageCard(body, second, 4, nextOrder())
		end
	end
	local function home()
		text(content, "AVAILABLE CASH", 11, muted, { Size = UDim2.new(1, 0, 0, 18) })
		text(content, "$" .. commas(profile.Cash), 22, cream, {
			Position = UDim2.fromOffset(0, 20),
			Size = UDim2.new(1, 0, 0, 28),
			Font = Enum.Font.GothamBold,
		})
		local tabNames = { "Paths", "Staff", "Upgrades", "Overview", "Achievements" }
		local tabRows = math.ceil(#tabNames / 2)
		local tabs = make("Frame", content, {
			Name = "HomeTabs",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 64),
			Size = if narrow then UDim2.new(1, 0, 0, tabRows * 48) else UDim2.new(0, 200, 1, -64),
		})
		for index, name in tabNames do
			button(tabs, name, function()
				homeTab = name
				render()
			end, {
				Name = name .. "Tab",
				TextSize = if narrow then 13 else 18,
				Position = if narrow
					then UDim2.new((index - 1) % 2 / 2, 0, 0, math.floor((index - 1) / 2) * 48)
					else UDim2.fromOffset(0, (index - 1) * 66),
				Size = if narrow then UDim2.new(0.5, -4, 0, 44) else UDim2.new(1, -10, 0, 56),
				BackgroundColor3 = if homeTab == name then gold else paper,
			})
		end
		local bodyTop = 64 + tabRows * 48 + 10
		local body = scroll(content, {
			Name = "HomeBody",
			Position = if narrow then UDim2.fromOffset(0, bodyTop) else UDim2.fromOffset(220, 64),
			Size = if narrow then UDim2.new(1, 0, 1, -bodyTop) else UDim2.new(1, -220, 1, -64),
		})
		list(body, 12)
		make("UIPadding", body, { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 12) })
		local order = 0
		local function line(value, size, color, height)
			order += 1
			return text(body, value, size, color, {
				LayoutOrder = order,
				Size = UDim2.new(1, -10, 0, height or 32),
			})
		end
		line(homeTab, 24, cream, 38).Font = Enum.Font.GothamBold
		if homeTab == "Paths" then
			paths(body, function()
				order += 1
				return order
			end)
		elseif homeTab == "Staff" then
			local hiredCount = 0
			for _, id in StaffCatalog.Order do
				if profile.Angler.Staff and profile.Angler.Staff[id] then
					hiredCount += 1
				end
			end
			line(string.format("Your crew · %d/%d hired", hiredCount, #StaffCatalog.Order), 15, cream, 26)
			line(
				"Meet your crew. Pay once to hire; they return whenever you join.",
				14,
				muted,
				if narrow then 58 else 42
			)
			for _, id in StaffCatalog.Order do
				local role = StaffCatalog.Roles[id]
				local hired = profile.Angler.Staff and profile.Angler.Staff[id] == true
				order += 1
				local row = make("Frame", body, {
					Name = id .. "Staff",
					BackgroundColor3 = paper,
					BorderSizePixel = 0,
					Size = UDim2.new(1, -10, 0, if narrow then 442 else 264),
					LayoutOrder = order,
				})
				local portrait = make("Frame", row, {
					Name = id .. "Portrait",
					BackgroundColor3 = navy,
					Position = UDim2.fromOffset(14, 14),
					Size = if narrow then UDim2.new(1, -28, 0, 202) else UDim2.fromOffset(156, 236),
				})
				local view = make("ViewportFrame", portrait, {
					Name = id .. "Preview",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, -42),
				})
				local loading = text(portrait, "Loading preview…", 13, muted, {
					Name = "PreviewStatus",
					Position = UDim2.fromOffset(8, 8),
					Size = UDim2.new(1, -16, 1, -58),
					TextXAlignment = Enum.TextXAlignment.Center,
				})
				local turn = StaffPreview.show(view, id, loading)
				for _, direction in { -1, 1 } do
					button(portrait, if direction == -1 then "‹" else "›", function()
						turn(direction)
					end, {
						Name = id .. (if direction == -1 then "TurnLeft" else "TurnRight"),
						Position = if direction == -1 then UDim2.new(0, 6, 1, -42) else UDim2.new(1, -50, 1, -42),
						Size = UDim2.fromOffset(44, 38),
						TextSize = 26,
					})
				end
				text(portrait, "Turn", 11, muted, {
					Position = UDim2.new(0, 50, 1, -42),
					Size = UDim2.new(1, -100, 0, 38),
					TextXAlignment = Enum.TextXAlignment.Center,
				})
				local left = if narrow then 14 else 188
				local inset = left + 14
				text(row, role.Name .. (if hired then " · Hired" else ""), 19, if hired then green else cream, {
					Position = UDim2.fromOffset(left, if narrow then 230 else 14),
					Size = UDim2.new(1, -inset, 0, 28),
					Font = Enum.Font.GothamBold,
				})
				text(row, role.Description, 14, muted, {
					Position = UDim2.fromOffset(left, if narrow then 266 else 52),
					Size = UDim2.new(1, -inset, 0, if narrow then 66 else 86),
					TextYAlignment = Enum.TextYAlignment.Top,
				})
				local afford = profile.Cash >= role.Price
				local locked = role.Requires ~= nil and not Paths.unlocked(profile, role.Requires)
				local assigned = profile.Angler.FishermanBoat
				text(row, "Permanent hire · $" .. commas(role.Price), 14, cream, {
					Position = UDim2.fromOffset(left, if narrow then 336 else 148),
					Size = UDim2.new(1, -inset, 0, 24),
				})
				text(
					row,
					if locked
						then "Unlocks with " .. Paths.Stages[role.Requires].Name .. " (Paths tab)"
						elseif hired and id == "Fisherman" then (if assigned and BoatCatalog[assigned]
							then "Sails your " .. BoatCatalog[assigned].Name .. ". Pick another boat below."
							else "Choose the boat he takes out:")
						elseif hired then "Part of your crew"
						elseif afford then "One payment. No daily wages."
						else "$" .. commas(role.Price - profile.Cash) .. " more needed",
					12,
					if hired and id == "Fisherman" and not assigned then gold else muted,
					{
						Position = UDim2.fromOffset(left, if narrow then 362 else 176),
						Size = UDim2.new(1, -inset, 0, 24),
					}
				)
				local boats = {}
				for boatId in BoatCatalog do
					if profile.OwnedBoats[boatId] then
						table.insert(boats, boatId)
					end
				end
				table.sort(boats, function(a, b)
					return BoatCatalog[a].Price < BoatCatalog[b].Price
				end)
				if hired and id == "Fisherman" and #boats > 0 then
					-- One button per owned boat; the assigned one is highlighted.
					for index, boatId in boats do
						local chosen = assigned == boatId
						local pick = button(row, BoatCatalog[boatId].Name, function()
							if not chosen then
								request("AssignBoat", boatId)
							end
						end, {
							Name = "Assign" .. boatId,
							Position = UDim2.new((index - 1) / #boats, left + (index - 1) * -inset / #boats + 2, 1, -54),
							Size = UDim2.new(1 / #boats, -inset / #boats - 4, 0, 40),
							TextSize = 14,
							BackgroundColor3 = if chosen then green else gold,
						})
						Theme.glassButton(pick, if chosen then "Disabled" else "Selected")
					end
				else
					local enabled = not hired and afford and not locked
					local hire = button(
						row,
						if hired and id == "Fisherman"
							then "Buy a boat at the drydock first"
							elseif hired then "Hired"
							elseif locked then "Locked"
							else "Hire · $" .. commas(role.Price),
						function()
							if enabled then
								request("HireStaff", id)
							end
						end,
						{
							Name = "Hire" .. id,
							Position = UDim2.new(0, left, 1, -54),
							Size = UDim2.new(1, -inset, 0, 40),
							Active = enabled,
							AutoButtonColor = enabled,
							BackgroundColor3 = if hired then green elseif enabled then gold else navy,
						}
					)
					Theme.glassButton(hire, if enabled then "Selected" else "Disabled")
					hire.Selectable = enabled
				end
			end
		elseif homeTab == "Overview" then
			local stock, totalValue = {}, 0
			local function add(records, location)
				for _, record in records do
					table.insert(stock, { Record = record, Location = location })
					totalValue += math.max(1, math.floor(record.Value))
				end
			end
			local data = profile.Angler
			add(data.Freezer, "Freezer · Ready to sell")
			add(data.Storage or {}, "Storage rack")

			if data.Hand then
				add({ data.Hand }, "In hand")
			end
			add(data.Cooler, "Legacy cooler")
			local boats = {}
			for id in data.Holds do
				table.insert(boats, id)
			end
			table.sort(boats)
			for _, id in boats do
				local fish = {}
				for _, item in data.Holds[id] do
					if item.Fish then
						table.insert(fish, item.Fish)
					end
				end
				add(fish, (BoatCatalog[id] and BoatCatalog[id].Name or id) .. " · Cargo hold")
			end
			line(string.format("%d fish in stock · $%s total value", #stock, commas(totalValue)), 16, gold, 44)
			line(
				string.format(
					"Freezer %d/%d · %d fish waiting to be stocked",
					#data.Freezer,
					freezerCapacity,
					#stock - #data.Freezer
				),
				14,
				muted,
				44
			)
			if Paths.unlocked(profile, "Supermarket") then
				local dishValue = 0
				for _, dish in data.Pantry or {} do
					dishValue += math.floor(dish.Value)
				end
				local cooking = 0
				for _ in data.Kitchen or {} do
					cooking += 1
				end
				line(
					string.format(
						"Kitchen pass %d/%d dishes · $%s · %d cooking",
						#(data.Pantry or {}),
						pantryCapacity,
						commas(dishValue),
						cooking
					),
					14,
					muted,
					30
				)
				for _, dish in data.Pantry or {} do
					local recipe = Recipes.Items[dish.RecipeId]
					line(
						string.format("%s · $%s", if recipe then recipe.Name else dish.RecipeId, commas(math.floor(dish.Value))),
						14,
						cream,
						26
					)
				end
			end
			if #stock == 0 then
				line("No fish in stock yet. Bring your next catch home to fill the freezer.", 16, muted, 80)
			end
			for _, item in stock do
				local record = item.Record
				order += 1
				local stockCard = make("Frame", body, {
					Name = "StockItem",
					BackgroundColor3 = paper,
					Size = UDim2.new(1, -10, 0, 108),
					LayoutOrder = order,
				})
				text(stockCard, fishName(record), 17, cream, {
					Position = UDim2.fromOffset(14, 10),
					Size = UDim2.new(1, -28, 0, 28),
				})
				text(
					stockCard,
					string.format("%.2f kg · $%s", record.Kg, commas(math.max(1, math.floor(record.Value)))),
					14,
					cream,
					{
						Position = UDim2.fromOffset(14, 42),
						Size = UDim2.new(1, -28, 0, 24),
					}
				)
				text(stockCard, item.Location, 12, muted, {
					Position = UDim2.fromOffset(14, 72),
					Size = UDim2.new(1, -28, 0, 26),
				})
			end
		else
			line(if homeTab == "Upgrades" then "No upgrades yet." else "No achievements yet.", 18, muted, 56)
			line(
				if homeTab == "Upgrades"
					then "Future home improvements will appear here."
					else "Your future milestones will appear here.",
				14,
				muted,
				56
			)
		end
	end
	local function settings()
		local function settingsOutline(item)
			item.ThemeBorder.Color = Color3.fromRGB(122, 122, 122)
			item.ThemeBorder.Transparency = 0.35
			item.ThemeBorder.Thickness = 1
		end
		local function settingsButton(parent, value, callback, props)
			local item = button(parent, value, callback, props)
			if not (props and props.Size) then
				item.Size = UDim2.new(1, -8, 0, 44)
			end
			settingsOutline(item)
			return item
		end
		local tabs = make(
			"Frame",
			content,
			{ BackgroundTransparency = 1, Size = if narrow then UDim2.new(1, 0, 0, 44) else UDim2.new(0, 200, 1, 0) }
		)
		for i, name in { "Performance", "Audio", "Codes", "Titles" } do
			settingsButton(tabs, name, function()
				settingTab = name
				render()
			end, {
				Name = name .. "Tab",
				TextSize = if narrow then 12 else 18,
				-- Keep the full stroke inside Content's clipping boundary on both layouts.
				Position = if narrow then UDim2.new((i - 1) / 4, 2, 0, 2) else UDim2.fromOffset(2, (i - 1) * 66 + 2),
				Size = if narrow then UDim2.new(0.25, -4, 0, 40) else UDim2.new(1, -12, 0, 56),
				BackgroundColor3 = if settingTab == name then gold else Theme.Colors.Panel,
				TextColor3 = if settingTab == name then navy else cream,
			})
		end
		local body = scroll(content, {
			Position = if narrow then UDim2.fromOffset(0, 56) else UDim2.fromOffset(220, 0),
			Size = if narrow then UDim2.new(1, 0, 1, -56) else UDim2.new(1, -220, 1, 0),
		})
		-- Leave room for the outlines along the scrolling area's edges.
		make("UIPadding", body, {
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 2),
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
		})
		list(body, 12)
		text(
			body,
			settingTab,
			24,
			cream,
			{ Font = Enum.Font.GothamBold, Size = UDim2.new(1, 0, 0, 42), LayoutOrder = 0 }
		)
		local function settingRow(key, name, description)
			local value = profile.Angler.Settings[key]
			local row = make("Frame", body, {
				BackgroundColor3 = Theme.Colors.Panel,
				BorderSizePixel = 0,
				Size = UDim2.new(1, -8, 0, 128),
				LayoutOrder = 1,
			})
			round(row)
			settingsOutline(row)
			text(
				row,
				name,
				18,
				cream,
				{ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 28), Font = Enum.Font.GothamBold }
			)
			text(row, description, 13, muted, { Position = UDim2.fromOffset(14, 39), Size = UDim2.new(1, -28, 0, 36) })
			if type(value) == "boolean" then
				settingsButton(row, if value then "On" else "Off", function()
					request("Setting", key, not value)
				end, {
					Name = key,
					Position = UDim2.new(1, -104, 1, -44),
					Size = UDim2.fromOffset(90, 34),
					BackgroundColor3 = if value then green else navy,
					TextColor3 = if value then navy else cream,
				})
			else
				settingsButton(row, "−", function()
					request("Setting", key, math.max(0, value - 10))
				end, { Name = key .. "Down", Position = UDim2.new(1, -184, 1, -44), Size = UDim2.fromOffset(40, 34) })
				text(row, value .. "%", 16, gold, {
					Position = UDim2.new(1, -140, 1, -44),
					Size = UDim2.fromOffset(76, 34),
					TextXAlignment = Enum.TextXAlignment.Center,
				})
				settingsButton(row, "+", function()
					request("Setting", key, math.min(100, value + 10))
				end, { Name = key .. "Up", Position = UDim2.new(1, -54, 1, -44), Size = UDim2.fromOffset(40, 34) })
			end
		end
		if settingTab == "Performance" then
			settingRow("Shadows", "Shadows", "Disable global shadows to reduce graphics work.")
			settingRow("WeatherEffects", "Weather effects", "Show rain, wind particles, and lightning flashes.")
		elseif settingTab == "Audio" then
			settingRow("MasterVolume", "Master volume", "Overall game audio.")
			settingRow("MusicVolume", "Music", "Volume for music tracks.")
			settingRow("EffectsVolume", "Sound effects", "Weather and other game sound effects.")
		elseif settingTab == "Codes" then
			text(
				body,
				"Enter a code to claim its reward. There are no active codes yet.",
				15,
				muted,
				{ Size = UDim2.new(1, -8, 0, 66) }
			)
			local field = input(body, "Enter code…")
			field.Name = "CodeInput"
			field.Size = UDim2.new(1, -8, 0, 42)
			settingsOutline(field)
			settingsButton(body, "Redeem code", function()
				request("Code", field.Text)
			end, { BackgroundColor3 = gold, TextColor3 = navy })
		elseif settingTab == "Titles" then
			text(body, "Choose a title you have unlocked.", 15, muted, { Size = UDim2.new(1, -8, 0, 40) })
			settingsButton(
				body,
				if profile.Angler.EquippedTitle == "" then "No title · Selected" else "Remove title",
				function()
					request("Title", "")
				end
			)
			local unlocked = 0
			for id, owned in profile.Angler.Titles do
				local title = Catalog.Titles[id]
				if owned and title then
					unlocked += 1
					settingsButton(
						body,
						title.Name .. (if profile.Angler.EquippedTitle == id then " · Selected" else ""),
						function()
							request("Title", id)
						end
					)
				end
			end
			if unlocked == 0 then
				text(body, "No titles unlocked yet.", 16, muted, { Size = UDim2.new(1, -8, 0, 60) })
			end
		end
	end
	render = function()
		content:ClearAllChildren()
		local isBook = active == "Bestiary" or active == "Journal"
		local glass = active == "Home" or active == "Settings" or active == "Equipment bag" or active == "Shop"
		card:SetAttribute("BookSurface", isBook)
		card:SetAttribute("GlassSurface", glass)
		bookChrome.Visible = isBook
		binding.Visible = isBook and card.AbsoluteSize.X >= 680
		card.BackgroundColor3 = if isBook then (if active == "Bestiary" then Book.Bestiary else Book.Leather) else navy
		leatherCover.BackgroundColor3 = card.BackgroundColor3
		Theme.button(closeButton, "Danger")
		if isBook then
			styleBookItem(closeButton)
		end
		card.ThemeBorder.Color = if isBook then Book.Edge else Theme.Colors.Border
		card.ThemeInnerRim.Visible = not isBook
		for index = 1, 4 do
			card["ThemeBolt" .. index].Visible = not isBook and not glass
		end
		if not glass then
			Theme.window(card)
			card.BackgroundColor3 = if isBook
				then (if active == "Bestiary" then Book.Bestiary else Book.Leather)
				else navy
			card.BackgroundTransparency = 0
			closeButton.ThemeFace.BackgroundTransparency = 0
			card.ThemeBorder.Color = if isBook then Book.Edge else Theme.Colors.Border
			local texture = card:FindFirstChild("GlassTexture")
			if texture then
				texture.Visible = false
			end
		else
			Theme.glassWindow(card)
			Theme.glassButton(closeButton, "Danger")
		end
		overlay.BackgroundTransparency = if glass then 0.65 else 0.35
		for _, label in { heading, subtitle, notice } do
			Theme.text(label, if label == heading then cream elseif label == notice then gold else muted)
			styleBookItem(label)
			styleGlassItem(label)
		end
		refreshSelection()
		if layoutWindow then
			layoutWindow()
		end
		if not active then
			return
		end
		heading.Text = if active == "Settings"
			then "Select your settings"
			elseif active == "Journal" then "Your fishing journal"
			else active
		subtitle.Text = ({
			Home = "Manage your staff, stock and home base.",
			Bestiary = "Every species. Every mutation. Every personal best.",
			["Equipment bag"] = "The equipment you own, ready for your next trip.",
			Journal = "Your story on the water, one catch at a time.",
			Settings = "Make yourself at home on the water.",
			Shop = "The Fishing Waters Robux shop.",
		})[active]
		if active == "Shop" then
			text(
				content,
				"Auto Store",
				24,
				cream,
				{ Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 36) }
			)
			text(
				content,
				"Automatically packs caught fish into your ship's hold while you are aboard your own ship. Tries every rotation for a snug fit. If the hold is full, the fish stays in your hand.",
				16,
				muted,
				{
					Position = UDim2.fromOffset(8, 50),
					Size = UDim2.new(1, -16, 0, 130),
					TextWrapped = true,
				}
			)
			local owned = player:GetAttribute("OwnsAutoStore") == true
			button(content, if owned then "Owned" else "Buy Auto Store · Robux", function()
				if player:GetAttribute("OwnsAutoStore") == true then
					return
				end
				local ok = pcall(function()
					MarketplaceService:PromptGamePassPurchase(player, Gamepasses.AutoStore.Id)
				end)
				if not ok then
					notice.Text = "The purchase prompt could not open. Please try again."
				end
			end, { Position = UDim2.fromOffset(8, 194), Size = UDim2.new(1, -16, 0, 48) })
		elseif not profile then
			empty(
				content,
				"Your progress is loading",
				"Your collection and settings will appear once your saved progress is available."
			)
		elseif active == "Home" then
			home()
		elseif active == "Bestiary" then
			bestiary()
		elseif active == "Equipment bag" then
			equipment()
		elseif active == "Journal" then
			journal()
		elseif active == "Settings" then
			settings()
		end
	end
	player:GetAttributeChangedSignal("OwnsAutoStore"):Connect(function()
		if active == "Shop" then
			render()
		end
	end)
	for index, name in { "Bestiary", "Journal", "Home", "Equipment bag", "Settings", "Shop" } do
		navButtons[name] = button(sidebar, name, function()
			if player:GetAttribute("DrydockScreenOpen") then
				return
			end
			if active == name then
				close()
				return
			end
			active = name
			overlay.Visible = true
			player:SetAttribute("PlayerMenuOpen", true)
			render()
			request("Get")
			if UserInputService.GamepadEnabled then
				GuiService.SelectedObject = if closeButton.Visible then closeButton else nil
			end
		end, {
			Name = name:gsub(" ", ""),
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, if name == "Bestiary" or name == "Journal" then 52 else 46),
			BackgroundTransparency = 0,
			TextSize = 14,
		})
	end
	refreshSelection()
	UserInputService.InputBegan:Connect(function(event)
		if overlay.Visible and (event.KeyCode == Enum.KeyCode.Escape or event.KeyCode == Enum.KeyCode.ButtonB) then
			close()
		elseif
			overlay.Visible
			and active == "Bestiary"
			and turnBestiary
			and not UserInputService:GetFocusedTextBox()
		then
			local step = ({
				[Enum.KeyCode.Left] = -1,
				[Enum.KeyCode.Right] = 1,
				[Enum.KeyCode.ButtonL1] = -1,
				[Enum.KeyCode.ButtonR1] = 1,
			})[event.KeyCode]
			if step then
				turnBestiary(step)
			end
		end
	end)
	local refreshToken = 0
	local function scheduleRefresh()
		refreshToken += 1
		local token = refreshToken
		task.delay(0.4, function()
			if token ~= refreshToken then
				return
			end
			if busy then
				scheduleRefresh()
				return
			end
			if player:GetAttribute("BoatDataStatus") == "Ready" then
				request("Get")
			end
		end)
	end
	player:GetAttributeChangedSignal("AnglerRevision"):Connect(scheduleRefresh)
	player:GetAttributeChangedSignal("BoatDataStatus"):Connect(scheduleRefresh)
	player:GetAttributeChangedSignal("RodEquipped"):Connect(function()
		if active == "Equipment bag" then
			render()
		end
	end)
	player.CharacterRemoving:Connect(close)
	layoutWindow = function()
		narrow = card.AbsoluteSize.X < 680
		local isBook = active == "Bestiary" or active == "Journal"
		-- The journal letters its own title and close box onto the page.
		local isJournal = active == "Journal"
		local isEquipment = active == "Equipment bag"
		card:FindFirstChildOfClass("UISizeConstraint").MaxSize = if isEquipment
			then Vector2.new(1480, 700)
			else Vector2.new(1020, 680)
		heading.Visible, subtitle.Visible, closeButton.Visible =
			not isJournal and not isEquipment, not isJournal and not isEquipment, not isJournal
		content.Position = if isEquipment
			then UDim2.fromOffset(12, 12)
			elseif isJournal then UDim2.fromOffset(20, 34)
			else UDim2.fromOffset(20, 98)
		content.Size = if isEquipment
			then UDim2.new(1, -24, 1, -54)
			elseif isJournal then UDim2.new(1, -40, 1, -80)
			else UDim2.new(1, -40, 1, -142)
		for _, leaf in leaves do
			leaf.MarginRule0.Visible, leaf.MarginRule1.Visible = not isJournal, not isJournal
		end
		binding.Visible = isBook and not narrow
		leaves[1].Visible = not narrow
		leaves[2].Position = if narrow then UDim2.fromOffset(18, 12) else UDim2.new(0.5, -3, 0, 12)
		leaves[2].Size = if narrow then UDim2.new(1, -36, 1, -34) else UDim2.new(0.5, -15, 1, -34)
		heading.Position = if isBook then UDim2.fromOffset(48, 22) else UDim2.fromOffset(60, 8)
		heading.Size = if isBook
			then UDim2.new(if narrow then 1 else 0.5, if narrow then -100 else -78, 0, 32)
			else UDim2.new(1, -120, 0, 36)
		heading.TextXAlignment = if isBook then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
		subtitle.Position = if isBook then UDim2.fromOffset(48, 54) else UDim2.fromOffset(24, 53)
		subtitle.Size = if isBook
			then UDim2.new(if narrow then 1 else 0.5, if narrow then -100 else -78, 0, 26)
			else UDim2.new(1, -48, 0, 34)
		subtitle.TextSize = if isBook then 12 else 13
		sidebar.Size = UDim2.fromOffset(if gui.AbsoluteSize.X < 680 then 144 else 172, 334)
		for _, item in navButtons do
			item.TextSize = if item.Name == "Bestiary" or item.Name == "Journal" then 20 else 14
		end
		refreshNavigation()
	end
	card:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		layoutWindow()
		if active then
			render()
		end
	end)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutWindow)
	layoutWindow()
	scheduleRefresh()
end
return Menu
