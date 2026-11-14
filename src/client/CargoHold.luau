-- Card inventory for the backpack, hand and active boat. Capacity is independent
-- of the card layout; all saves, ownership and access are checked by the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local MarketplaceService = game:GetService("MarketplaceService")
local StarterGui = game:GetService("StarterGui")
local Aboard = require(ReplicatedStorage.Shared.Aboard)
local BoatCatalog = require(ReplicatedStorage.Shared.BoatCatalog)
local Backpacks = require(ReplicatedStorage.Shared.BackpackCatalog)
local Cargo = require(ReplicatedStorage.Shared.Cargo)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Bait = require(ReplicatedStorage.Shared.Bait)
local Passes = require(ReplicatedStorage.Shared.Gamepasses)
local Catalog = require(ReplicatedStorage.Shared.AnglerCatalog)
local FishCatch = require(ReplicatedStorage.Shared.FishCatch)
local FishModels = require(ReplicatedStorage.Shared.FishModels)
local FishMutations = require(ReplicatedStorage.Shared.FishMutations)

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
local CargoHold = {}
local rgb = Color3.fromRGB
local INK, HULL, EDGE = rgb(18, 19, 23), rgb(5, 6, 8), rgb(48, 49, 55)
local WHITE, MUTED = rgb(240, 240, 236), rgb(150, 152, 158)
local GOLD, CREAM, CYAN = rgb(255, 226, 128), rgb(226, 218, 196), rgb(110, 228, 240)
local VIOLET, MINT, AMBER, RED = rgb(178, 142, 255), rgb(150, 230, 140), rgb(255, 176, 96), rgb(255, 82, 82)
local WIDTH, HEIGHT, LEFT, CONTENT = 1180, 500, 176, 832
local MIN_HEIGHT = 400 -- shortest panel the fixed side columns still fit in
local CARD, CARD_HEIGHT, GAP = 98, 98, 6
local HOTBAR_CLEARANCE = 90
local started = false
local function make(class: string, parent: Instance?, props: { [string]: any }): any
	local item = Instance.new(class)
	for key, value in props do
		item[key] = value
	end
	item.Parent = parent
	return item
end

local function round(item: GuiObject, radius: number?)
	make("UICorner", item, { CornerRadius = if radius then UDim.new(0, radius) else UDim.new(1, 0) })
end

local function stroke(item: GuiObject, color: Color3, thickness: number)
	return make("UIStroke", item, {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function text(parent: Instance, value: string, props: { [string]: any }): TextLabel
	local label = make("TextLabel", parent, {
		BackgroundTransparency = 1,
		Font = Enum.Font.BuilderSansMedium,
		Text = value,
		TextColor3 = WHITE,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	for key, item in props do
		label[key] = item
	end
	return label
end

-- Short accent strokes in each corner, like a targeting frame.
local function brackets(item: GuiObject, color: Color3)
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		for _, size in { UDim2.fromOffset(7, 2), UDim2.fromOffset(2, 7) } do
			make("Frame", item, {
				Name = "Bracket",
				AnchorPoint = corner,
				Position = UDim2.fromScale(corner.X, corner.Y),
				Size = size,
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				ZIndex = 2,
			})
		end
	end
end

local function button(parent: Instance, caption: string, props: { [string]: any }, accent: Color3?): TextButton
	local item = make("TextButton", parent, {
		AutoButtonColor = true,
		BackgroundColor3 = INK,
		Font = Enum.Font.BuilderSansBold,
		Text = caption,
		TextColor3 = accent or WHITE,
		TextSize = 15,
	})
	item.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic)
	for key, value in props do
		item[key] = value
	end
	round(item, 2)
	stroke(item, EDGE, 1)
	brackets(item, accent or MUTED)
	return item
end

-- Small pictograms are drawn as strokes on a colored circular badge. They do
-- not depend on platform-specific emoji or uploaded image assets.
local MUTATION_ICONS = {
	Corrupted = { { {2,2,10,10}, {10,2,2,10}, {6,2,6,10} } },
	VoidTouched = { { {2,6,4,2}, {4,2,8,2}, {8,2,10,6}, {10,6,8,10}, {8,10,4,10}, {4,10,2,6}, {6,4,6,8} } },
	Windy = { { {1,4,9,4}, {9,4,10,2}, {1,7,10,7}, {10,7,9,9} } },
	Ascended = { { {2,5,6,1}, {6,1,10,5}, {6,1,6,10}, {2,10,10,10} } },
	Floral = { { {6,1,6,11}, {1,6,11,6}, {3,3,9,9}, {9,3,3,9} } },
	Snowy = { { {6,1,6,11}, {1,3,11,9}, {1,9,11,3}, {4,2,6,4}, {8,2,6,4} } },
	Tryhard = { { {2,2,10,10}, {10,2,2,10}, {1,3,4,3}, {8,3,11,3}, {1,10,3,10}, {9,10,11,10} } },
	JackOFish = { { {3,3,9,3}, {9,3,11,6}, {11,6,9,10}, {9,10,3,10}, {3,10,1,6}, {1,6,3,3}, {6,3,7,1}, {3,6,4,6}, {8,6,9,6}, {4,8,8,8} } },
	JacksPet = { { {2,5,3,9}, {3,9,9,9}, {9,9,10,5}, {10,5,8,2}, {8,2,6,4}, {6,4,4,2}, {4,2,2,5}, {4,6,4,6}, {8,6,8,6} } },
	ZeusStruck = { { {7,1,3,6}, {3,6,6,6}, {6,6,5,11}, {5,11,10,5}, {10,5,7,5}, {7,5,7,1} } },
	Nightmare = { { {1,6,4,3}, {4,3,8,3}, {8,3,11,6}, {11,6,8,9}, {8,9,4,9}, {4,9,1,6}, {6,4,6,8} } },
	Obsidian = { { {6,1,10,4}, {10,4,9,9}, {9,9,6,11}, {6,11,2,8}, {2,8,2,4}, {2,4,6,1}, {6,1,6,11}, {2,4,10,4} } },
	Gusty = { { {1,3,8,3}, {8,3,10,5}, {10,5,8,7}, {8,7,5,7}, {1,6,6,6}, {1,9,7,9} } },
	Astral = { { {6,1,6,11}, {1,6,11,6}, {3,3,9,9}, {9,3,3,9} } },
	Rainbow = { { {1,9,2,5}, {2,5,5,2}, {5,2,8,2}, {8,2,11,5}, {11,5,11,9}, {3,9,4,6}, {4,6,6,5}, {6,5,8,6}, {8,6,9,9} } },
	Neon = { { {1,8,3,8}, {3,8,4,3}, {4,3,6,3}, {6,3,6,9}, {6,9,8,9}, {8,9,9,4}, {9,4,11,4} } },
	Albino = { { {1,6,4,3}, {4,3,8,3}, {8,3,11,6}, {11,6,8,9}, {8,9,4,9}, {4,9,1,6}, {5,6,5,6} } },
}

local function mutationBadge(parent: Instance, record)
	if not record or not record.Mutation or record.Mutation == "Normal" then
		return
	end
	local index = 0
	for name in string.gmatch(record.Mutation, "[^+]+") do
		-- Badge colours are shared with the coloured mutation names (FishMutations.Colors).
		local strokes = (MUTATION_ICONS[name] or { { {2,6,10,6}, {6,2,6,10} } })[1]
		local base = FishMutations.Colors[name]
		local color = if base then rgb(base[1], base[2], base[3]) else MUTED
		local neon = name == "Neon" and FishMutations.NeonColors[record.NeonColor or ""]
		if neon then
			color = rgb(neon[1], neon[2], neon[3])
			-- Keep the white pictogram visible on especially pale neon colors.
			if color.R * 0.299 + color.G * 0.587 + color.B * 0.114 > 0.8 then
				color = color:Lerp(INK, 0.35)
			end
		end
		local badge = make("Frame", parent, {
			Name = "MutationIcon",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -2 - (index % 2) * 17, 0, 2 + math.floor(index / 2) * 17),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 4,
		})
		round(badge)
		for lineIndex, line in strokes do
			local dx, dy = line[3] - line[1], line[4] - line[2]
			local rainbow = FishMutations.RainbowColors[(lineIndex - 1) % #FishMutations.RainbowColors + 1]
			local mark = make("Frame", badge, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(2 + (line[1] + line[3]) / 2, 2 + (line[2] + line[4]) / 2),
				Size = UDim2.fromOffset(math.max(1.5, math.sqrt(dx * dx + dy * dy)), 1.5),
				Rotation = math.deg(math.atan2(dy, dx)),
				BackgroundColor3 = if name == "Rainbow" then rgb(rainbow[1], rainbow[2], rainbow[3]) else WHITE,
				BorderSizePixel = 0,
				ZIndex = 5,
			})
			round(mark)
		end
		index += 1
	end
end

-- RichText card title: the coloured mutation label before the plain name.
local function fishTitle(entry): string
	local name = string.gsub(string.gsub(string.gsub(entry.Name, "&", "&amp;"), "<", "&lt;"), ">", "&gt;")
	local fish = entry.Item and entry.Item.Fish
	local mutation = if fish then FishMutations.richLabel(fish.Mutation, fish.NeonColor) else ""
	return if mutation ~= "" then mutation .. " " .. name else name
end

-- Fit every bounds corner after rolling the camera, including perspective depth.
-- Use the tile dimensions because the preview may not be parented/on screen yet.
local function fitTileFish(model: Model, camera: Camera, width: number, height: number, rotation: number)
	local center = model:GetAttribute("BoundsCenter") :: Vector3
	local half = (model:GetAttribute("BoundsSize") :: Vector3) / 2
	local orientation = camera.CFrame.Rotation * CFrame.Angles(0, 0, rotation * math.pi / 2)
	local tanY = math.tan(math.rad(camera.FieldOfView / 2))
	local tanX = tanY * width / height
	local distance = 0.1
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local corner = orientation:VectorToObjectSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
				distance = math.max(distance, corner.Z + math.max(math.abs(corner.X) / tanX, math.abs(corner.Y) / tanY) * 1.05)
			end
		end
	end
	camera.CFrame = CFrame.new(center - orientation.LookVector * distance) * orientation
	camera:SetAttribute("Distance", distance)
end

function CargoHold.start()
	if started then return end
	started = true
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Cargo")
	local request = remotes:WaitForChild("Request") :: RemoteFunction
	local update = remotes:WaitForChild("Update") :: RemoteEvent
	local state = { Backpack = {}, Items = {}, BackpackId = "Starter", AutoStore = true }
	local open, pending, aboard = false, false, false
	local tab, sortBy, ascending = "Backpack", nil, true
	local view = { Fish = true, Items = true, Favorites = false }
	local selected, signature = nil, nil
	local lastRequest = -math.huge
	local render, setOpen, send
	local cards = {}
	local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), {
		Name = "Cargo", ResetOnSpawn = false, DisplayOrder = 23,
		IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local toggle = button(gui, "Inventory [`]", {
		Name = "OpenCargo", Position = UDim2.new(1, -150, 1, -100), Size = UDim2.fromOffset(136, 38),
	}, GOLD)
	local shade = make("Frame", gui, {
		Name = "InventoryShade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, Visible = false,
	})
	local panel = make("Frame", shade, {
		Name = "InventoryPanel", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -HOTBAR_CLEARANCE),
		Size = UDim2.fromOffset(WIDTH, HEIGHT), BackgroundColor3 = HULL,
		BackgroundTransparency = 0.08, BorderSizePixel = 0, Active = true,
	})
	round(panel, 3)
	stroke(panel, EDGE, 1)
	local scale = make("UIScale", panel, { Scale = 1 })
	-- Height-dependent children are positioned by applyHeight (assigned once they exist).
	local applyHeight: (number) -> () = function() end
	local panelHeight = HEIGHT
	local function updateLayout()
		local camera = workspace.CurrentCamera
		if not camera then return end
		local size = camera.ViewportSize
		-- Shrink the hotbar gap and side margins on small screens so the panel keeps more room.
		local clearance = math.min(HOTBAR_CLEARANCE, size.Y * 0.17)
		local availableHeight = math.max(1, size.Y - clearance - 12)
		-- Scale down only as far as needed to fit the narrowest layout; the item list absorbs any
		-- remaining height difference instead of shrinking every label.
		local fit = math.min(1, (size.X - 16) / WIDTH, availableHeight / MIN_HEIGHT)
		scale.Scale = math.max(0.01, fit)
		panel.Position = UDim2.new(0.5, 0, 1, -clearance)
		local height = math.clamp(math.floor(availableHeight / scale.Scale), MIN_HEIGHT, HEIGHT)
		if height ~= panelHeight then
			panelHeight = height
			applyHeight(height)
		end
	end
	updateLayout()
	text(panel, "Inventory", { Position = UDim2.fromOffset(20, 12), Size = UDim2.fromOffset(150, 36),
		TextSize = 25, Font = Enum.Font.BuilderSansBold, TextColor3 = GOLD })
	local tabs = {}
	for index, name in { "Backpack", "Boat", "All" } do
		local control = button(panel, name, { Name = name .. "Tab", Position = UDim2.fromOffset(LEFT + (index - 1) * 154, 14),
			Size = UDim2.fromOffset(146, 32) }, if name == "Boat" then VIOLET else CYAN)
		tabs[name] = control
		control.Activated:Connect(function()
			tab, selected = name, nil
			render()
		end)
	end
	local close = button(panel, "X", { Name = "CloseInventory", Position = UDim2.new(1, -54, 0, 14),
		Size = UDim2.fromOffset(34, 34), TextSize = 20 }, RED)
	local summary = text(panel, "Loading inventory…", { Name = "InventoryCount", Position = UDim2.fromOffset(LEFT, 54),
		Size = UDim2.fromOffset(560, 28), TextSize = 19, TextColor3 = GOLD })
	local searchBox = make("TextBox", panel, { Name = "SearchInput", Position = UDim2.fromOffset(LEFT + CONTENT - 252, 54),
		Size = UDim2.fromOffset(196, 32), BackgroundColor3 = INK, Text = "", PlaceholderText = "Search inventory…",
		PlaceholderColor3 = MUTED, TextColor3 = WHITE, TextSize = 15, Font = Enum.Font.BuilderSans,
		ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, Visible = false })
	make("UIPadding", searchBox, { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })
	stroke(searchBox, EDGE, 1)
	local search = button(panel, "Search", { Name = "Search", Position = UDim2.fromOffset(LEFT + CONTENT - 108, 54),
		Size = UDim2.fromOffset(108, 32) }, MUTED)
	local list = make("ScrollingFrame", panel, { Name = "InventoryItems", Position = UDim2.fromOffset(LEFT, 94),
		Size = UDim2.fromOffset(CONTENT, 306), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0), ScrollBarThickness = 4, ScrollBarImageColor3 = MUTED,
		ScrollingDirection = Enum.ScrollingDirection.Y, ClipsDescendants = true })
	local empty = text(panel, "", { Name = "EmptyInventory", Position = UDim2.fromOffset(LEFT + 30, 180),
		Size = UDim2.fromOffset(CONTENT - 60, 130), TextSize = 18, TextColor3 = MUTED,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center })
	local capacity = text(panel, "", { Name = "Capacity", Position = UDim2.fromOffset(LEFT, 84),
		Size = UDim2.fromOffset(CONTENT, 8), TextSize = 11, TextColor3 = MUTED })
	local function sideTitle(caption, x, y)
		text(panel, caption, { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(136, 28),
			TextSize = 21, Font = Enum.Font.BuilderSansBold, TextXAlignment = Enum.TextXAlignment.Center })
		make("Frame", panel, { Position = UDim2.fromOffset(x + 6, y + 31), Size = UDim2.fromOffset(124, 2),
			BackgroundColor3 = WHITE, BorderSizePixel = 0 })
	end
	sideTitle("Auto Store", 20, 54)
	local autoStore = button(panel, "", { Name = "AutoStore", Position = UDim2.fromOffset(20, 98), Size = UDim2.fromOffset(136, 32) }, MINT)
	text(panel, "Automatically stow catches aboard your boat.", { Position = UDim2.fromOffset(22, 138),
		Size = UDim2.fromOffset(132, 42), TextSize = 12, TextColor3 = MUTED, TextWrapped = true })
	sideTitle("Sort By", 20, 196)
	local sortButtons = {}
	for index, spec in { { "Off", "Sorting: Off", CYAN }, { "Rarity", "Rarity", AMBER }, { "Worth", "Worth", MINT }, { "Name", "ABC order", VIOLET } } do
		local control = button(panel, spec[2], { Name = "Sort" .. spec[1], Position = UDim2.fromOffset(20, 238 + (index - 1) * 36),
			Size = UDim2.fromOffset(136, 32), TextSize = 14 }, spec[3])
		sortButtons[spec[1]] = control
		control.Activated:Connect(function()
			if spec[1] == "Off" then
				sortBy = if sortBy then nil else "Rarity"
				ascending = false
			elseif sortBy == spec[1] then ascending = not ascending
			else sortBy, ascending = spec[1], spec[1] == "Name" end
			list.CanvasPosition = Vector2.zero
			render()
		end)
	end
	sideTitle("View", 1026, 54)
	local viewButtons = {}
	for index, spec in { { "Fish", "Fish" }, { "Items", "Items" }, { "Favorites", "Favorites" } } do
		local control = make("TextButton", panel, { Name = "View" .. spec[1], Text = "", BackgroundTransparency = 1,
			Position = UDim2.fromOffset(1024, 100 + (index - 1) * 38), Size = UDim2.fromOffset(142, 34) })
		local track = make("Frame", control, { Position = UDim2.fromOffset(0, 7), Size = UDim2.fromOffset(44, 20),
			BackgroundColor3 = MINT, BorderSizePixel = 0 })
		round(track)
		local knob = make("Frame", track, { Position = UDim2.fromOffset(24, -1), Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = CREAM, BorderSizePixel = 0 })
		round(knob)
		stroke(knob, WHITE, 1)
		text(control, spec[2], { Position = UDim2.fromOffset(52, 0), Size = UDim2.fromOffset(94, 34), TextSize = 16 })
		viewButtons[spec[1]] = { Track = track, Knob = knob }
		control.Activated:Connect(function()
			view[spec[1]] = not view[spec[1]]
			list.CanvasPosition = Vector2.zero
			render()
		end)
	end
	text(panel, "Select a card for actions.\nRight-click a fish to favorite it.", { Position = UDim2.fromOffset(1026, 230),
		Size = UDim2.fromOffset(134, 66), TextSize = 12, TextColor3 = MUTED, TextWrapped = true })
	local detail = text(panel, "Select an item", { Name = "SelectedItem", Position = UDim2.fromOffset(LEFT, 404),
		Size = UDim2.fromOffset(CONTENT, 24), TextSize = 15, RichText = true, TextTruncate = Enum.TextTruncate.AtEnd })
	local actions = {}
	for index, spec in { { "Hand", "Take in hand", CYAN }, { "Backpack", "To backpack", CYAN },
		{ "Boat", "To boat", VIOLET }, { "Favorite", "Favorite", GOLD }, { "Release", "Release", RED },
		{ "Use", "Use", GOLD }, { "Pantry", "Stock dish", MINT } } do
		local control = button(panel, spec[2], { Name = "Action" .. spec[1], Position = UDim2.fromOffset(LEFT + (index - 1) * 139, 432),
			Size = UDim2.fromOffset(131, 32), TextSize = 13, Visible = false }, spec[3])
		actions[spec[1]] = control
	end
	-- Bait crates live on the profile (not in the hold); they're shown here as a
	-- card too, and opened through the same server action as the equipment bag.
	local openCrate = button(panel, "Open crate", { Name = "ActionOpenCrate", Position = UDim2.fromOffset(LEFT, 432),
		Size = UDim2.fromOffset(131, 32), TextSize = 13, Visible = false }, GOLD)
	local crateSelected = false
	local bulk = button(panel, "Boat → backpack", { Name = "MoveAll", Position = UDim2.fromOffset(1026, 346),
		Size = UDim2.fromOffset(136, 36), TextSize = 13, Visible = false }, MINT)
	local fitPart = button(panel, "Fit reserved part", { Name = "FitPart", Position = UDim2.fromOffset(LEFT, 432),
		Size = UDim2.fromOffset(194, 32), Visible = false }, MINT)
	local cancelPart = button(panel, "Cancel refit", { Name = "CancelRefit", Position = UDim2.fromOffset(LEFT + 208, 432),
		Size = UDim2.fromOffset(150, 32), Visible = false }, RED)
	local worth = text(panel, "Total worth: $0", { Name = "TotalWorth", Position = UDim2.new(1, -330, 1, -30),
		Size = UDim2.fromOffset(310, 24), TextSize = 18, Font = Enum.Font.BuilderSansBold,
		TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Right })
	local notice = text(panel, "", { Name = "InventoryNotice", Position = UDim2.fromOffset(LEFT, HEIGHT - 30),
		Size = UDim2.fromOffset(620, 24), TextSize = 12, TextColor3 = MUTED, TextTruncate = Enum.TextTruncate.AtEnd })
	-- Offsets below match the original 500px layout; everything below the item list follows the bottom edge.
	applyHeight = function(height: number)
		local extra = height - HEIGHT
		panel.Size = UDim2.fromOffset(WIDTH, height)
		list.Size = UDim2.fromOffset(CONTENT, 306 + extra)
		empty.Position = UDim2.fromOffset(LEFT + 30, 180 + extra / 2)
		detail.Position = UDim2.fromOffset(LEFT, 404 + extra)
		for index, control in { actions.Hand, actions.Backpack, actions.Boat, actions.Favorite, actions.Release } do
			control.Position = UDim2.fromOffset(LEFT + (index - 1) * 139, 432 + extra)
		end
		actions.Pantry.Position = UDim2.fromOffset(LEFT, 432 + extra)
		openCrate.Position = UDim2.fromOffset(LEFT, 432 + extra)
		fitPart.Position = UDim2.fromOffset(LEFT, 432 + extra)
		cancelPart.Position = UDim2.fromOffset(LEFT + 208, 432 + extra)
		notice.Position = UDim2.fromOffset(LEFT, height - 30)
	end
	applyHeight(panelHeight)
	local function money(amount)
		local value = tostring(math.floor(amount))
		local formatted = value:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
		return "$" .. formatted
	end
	local function entryId(entry)
		return entry.Source .. ":" .. tostring(entry.Index)
	end
	local function refreshPreviews()
		if not open then return end
		local top = list.CanvasPosition.Y
		for _, card in cards do
			local visible = card.Y + CARD_HEIGHT >= top and card.Y <= top + list.Size.Y.Offset
			if visible and not card.Preview and card.Entry.Item and card.Entry.Item.Fish then
				local fish = card.Entry.Item.Fish
				local viewport = make("ViewportFrame", card.Button, { Position = UDim2.fromOffset(2, 9),
					Size = UDim2.fromOffset(CARD - 4, 58), BackgroundTransparency = 1, ZIndex = 1, Active = false })
				local model, camera = FishModels.show(viewport, fish.FishId, nil, fish)
				if model and camera then fitTileFish(model, camera, CARD - 4, 58, 0) end
				card.Preview = viewport
			elseif not visible and card.Preview then
				card.Preview:Destroy()
				card.Preview = nil
			end
		end
	end
	local function payload(entry)
		return { Source = entry.Source, Index = entry.Index, BoatId = state.BoatId,
			Expected = Inventory.expected(entry.Item) }
	end
	local function favorite(entry)
		if pending or not entry or not entry.Item or not entry.Item.Fish then return end
		local data = payload(entry)
		data.Locked = not entry.Locked
		send("InventoryLock", data)
	end
	local function applyState(nextState)
		if type(nextState) ~= "table" then return end
		local oldPending = state.Pending
		if nextState.BoatId ~= state.BoatId then selected, signature = nil, nil end
		state = nextState
		if state.Pending and not oldPending then
			tab, selected = "Boat", nil
			setOpen(true)
		end
		render()
	end
	send = function(action, ...)
		if pending then return end
		pending = true
		local args = table.pack(...)
		notice.Text, notice.TextColor3 = "Updating inventory…", MUTED
		render()
		task.spawn(function()
			local delay = 0.22 - (os.clock() - lastRequest)
			if delay > 0 then task.wait(delay) end
			local ok, response = pcall(request.InvokeServer, request, action, table.unpack(args, 1, args.n))
			lastRequest, pending = os.clock(), false
			if ok and type(response) == "table" then
				applyState(response.State)
				if response.Ok and (action == "Place" or action == "CancelPlace") then setOpen(false) end
				notice.Text = if response.Message ~= "" then response.Message else (if response.Ok then "Inventory updated." else "Please try again.")
				notice.TextColor3 = if response.Ok then MINT else RED
			else
				notice.Text, notice.TextColor3 = "Couldn't reach your inventory. Try again.", RED
			end
			render()
		end)
	end
	render = function()
		local owned = player:GetAttribute("OwnsAutoStore") == true
		autoStore.Text = if not owned then "Buy gamepass" elseif state.AutoStore ~= false then "ON" else "OFF"
		autoStore.TextColor3 = if owned and state.AutoStore ~= false then MINT else MUTED
		for name, control in tabs do
			control.BackgroundColor3 = if tab == name then rgb(34, 39, 44) else INK
			control.TextTransparency = if tab == name then 0 else 0.3
		end
		for name, control in sortButtons do
			control.Text = if name == "Off" then (if sortBy then "Sorting: On" else "Sorting: Off")
				else (if sortBy == name then (if ascending then "↑ " else "↓ ") else "")
					.. (if name == "Name" then "ABC order" else name)
			control.BackgroundColor3 = if sortBy == name then rgb(34, 39, 44) else INK
		end
		for name, control in viewButtons do
			control.Track.BackgroundColor3 = if view[name] then rgb(0, 184, 80) else EDGE
			control.Knob.Position = UDim2.fromOffset(if view[name] then 24 else -1, -1)
		end
		bulk.Visible = open and aboard and tab ~= "Backpack" and not state.Pending
		if not open then return end
		local entries = Inventory.entries(state, Catalog, Cargo, Recipes)
		local filtered, totalWorth = Inventory.visible(entries, tab, view, searchBox.Text, sortBy, ascending)
		worth.Text = "Total worth: " .. money(totalWorth)
		local crates = player:GetAttribute("BaitCrates")
		crates = if type(crates) == "number" then crates else 0
		local query = string.lower(searchBox.Text:match("^%s*(.-)%s*$"))
		local showCrate = crates > 0 and tab ~= "Boat" and view.Items and not view.Favorites
			and string.find(string.lower(Bait.Crate.Name), query, 1, true) ~= nil
		local slots = if showCrate then 1 else 0
		if not showCrate then crateSelected = false end
		summary.Text = string.format("%d shown · %d total items", #filtered + slots, #entries + (if crates > 0 then 1 else 0))
		-- Black Hole Backpack owners carry an infinite hold over any saved pack.
		local backpack = Backpacks.layoutFor(player, state.BackpackId)
		local boat = state.BoatId and BoatCatalog[state.BoatId]
		local packTotal = Cargo.capacity(backpack.Hold)
		local packSpace = string.format("Backpack %d / %s space", Cargo.used(state.Backpack or {}, Catalog.Fish), if packTotal == math.huge then "∞" else tostring(packTotal))
		local boatSpace = if boat then string.format("Boat %d / %d space", Cargo.used(state.Items or {}, Catalog.Fish), Cargo.capacity(boat.Hold)) else "No boat launched"
		capacity.Text = if tab == "Backpack" then packSpace elseif tab == "Boat" then boatSpace else packSpace .. "    ·    " .. boatSpace
		empty.Visible = #filtered + slots == 0
		empty.Text = if tab == "Boat" and not boat then "Launch a boat to see its inventory."
			elseif view.Favorites then "No favorites match these filters.\nSelect a fish and choose Favorite."
			else "No items match these filters."
		local parts = { "crate|" .. tostring(if showCrate then crates else 0) }
		for _, entry in filtered do
			local fish = entry.Item and entry.Item.Fish
			table.insert(parts, tostring(entryId(entry)) .. "|" .. entry.Name .. "|" .. tostring(entry.Locked) .. "|"
				.. (if fish then fish.FishId .. "|" .. tostring(fish.Size) .. "|" .. tostring(fish.Kg) .. "|" .. tostring(fish.CaughtAt) .. "|" .. fish.Mutation .. "|"
					.. tostring(fish.Value) .. "|" .. tostring(fish.NeonColor) .. "|" .. table.concat(fish.Corruptions or {}, ",") else ""))
		end
		local nextSignature = table.concat(parts, ";")
		if signature ~= nextSignature then
			signature = nextSignature
			for _, card in cards do card.Button:Destroy() end
			cards = {}
			if showCrate then
				local tile = make("TextButton", list, { Name = "BaitCrateCard", Text = "", AutoButtonColor = false,
					Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(CARD, CARD_HEIGHT),
					BackgroundColor3 = INK, BorderSizePixel = 0 })
				local outline = stroke(tile, EDGE, 1)
				make("UIGradient", tile, { Rotation = 90, Color = ColorSequence.new(INK, GOLD:Lerp(HULL, 0.6)) })
				make("Frame", tile, { Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 2),
					BackgroundColor3 = GOLD, BorderSizePixel = 0, ZIndex = 3 })
				-- A small drawn crate: wooden box with a lid band and cross slats.
				local box = make("Frame", tile, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12),
					Size = UDim2.fromOffset(40, 30), BackgroundColor3 = rgb(150, 104, 58), BorderSizePixel = 0, ZIndex = 2 })
				round(box, 3)
				stroke(box, rgb(92, 60, 30), 2)
				make("Frame", box, { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 7),
					BackgroundColor3 = rgb(116, 78, 42), BorderSizePixel = 0, ZIndex = 2 })
				for _, rotation in { 34, -34 } do
					make("Frame", box, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 3),
						Size = UDim2.fromOffset(40, 3), Rotation = rotation, BackgroundColor3 = rgb(116, 78, 42),
						BorderSizePixel = 0, ZIndex = 2 })
				end
				text(tile, Bait.Crate.Name, { Name = "FishName", Position = UDim2.fromOffset(4, 44),
					Size = UDim2.fromOffset(CARD - 8, 32), TextSize = 13, TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3, ZIndex = 3 })
				text(tile, "×" .. crates, { Position = UDim2.fromOffset(4, CARD_HEIGHT - 19), Size = UDim2.fromOffset(CARD - 8, 16),
					TextSize = 11, TextColor3 = CREAM, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3 })
				table.insert(cards, { Button = tile, Outline = outline, Entry = { Source = "BaitCrate", Index = 0, Crate = true }, Y = 0 })
				tile.Activated:Connect(function() selected, crateSelected = nil, true render() end)
			end
			for position, entry in filtered do
				local index = position + slots
				local x, y = ((index - 1) % 8) * (CARD + GAP), math.floor((index - 1) / 8) * (CARD_HEIGHT + GAP)
				local fish = entry.Item and entry.Item.Fish
				local species = fish and Catalog.Fish[fish.FishId]
				local rarity = species and Catalog.Rarities[species.Rarity]
				local tint = if rarity then rarity.Color else VIOLET
				local tile = make("TextButton", list, { Name = "InventoryCard", Text = "", AutoButtonColor = false,
					Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(CARD, CARD_HEIGHT),
					BackgroundColor3 = INK, BorderSizePixel = 0 })
				local outline = stroke(tile, EDGE, 1)
				make("UIGradient", tile, { Rotation = 90, Color = ColorSequence.new(INK, tint:Lerp(HULL, 0.6)) })
				make("Frame", tile, { Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 2),
					BackgroundColor3 = tint, BorderSizePixel = 0, ZIndex = 3 })
				-- "Corrupted Tiger Trout": each mutation word in its own colour; long
				-- stacked mutations shrink to fit the card instead of spilling out.
				local nameLabel = text(tile, fishTitle(entry), { Name = "FishName", Position = UDim2.fromOffset(4, 44),
					Size = UDim2.fromOffset(CARD - 8, 32), RichText = true, TextScaled = true,
					TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
					TextStrokeTransparency = 0.3, ZIndex = 3 })
				make("UITextSizeConstraint", nameLabel, { MaxTextSize = 13, MinTextSize = 7 })
				text(tile, if fish then FishCatch.formatKg(fish.Kg) elseif entry.Item.Dish then "Dish" else "Fitted", {
					Position = UDim2.fromOffset(4, CARD_HEIGHT - 19), Size = UDim2.fromOffset(CARD - 8, 16),
					TextSize = 11, TextColor3 = CREAM, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3 })
				text(tile, if entry.Source == "Hand" then "IN HAND" elseif entry.Source == "Boat" then "BOAT" else "", {
					Position = UDim2.fromOffset(4, 3), Size = UDim2.fromOffset(64, 12), TextSize = 9, TextColor3 = CYAN, ZIndex = 3 })
				if entry.Locked then
					text(tile, "★", { Name = "LockIcon", Position = UDim2.fromOffset(3, 17), Size = UDim2.fromOffset(20, 20),
						TextColor3 = GOLD, TextSize = 18, ZIndex = 4 })
				end
				if fish then mutationBadge(tile, fish)
				else
					text(tile, "⚙", { Position = UDim2.fromOffset(0, 8),
						Size = UDim2.fromOffset(CARD, 46), TextSize = 32, TextColor3 = tint, TextXAlignment = Enum.TextXAlignment.Center })
				end
				table.insert(cards, { Button = tile, Outline = outline, Entry = entry, Y = y })
				tile.Activated:Connect(function() selected, crateSelected = entry, false render() end)
				tile.MouseButton2Click:Connect(function() if entry.Item.Fish then selected, crateSelected = entry, false favorite(entry) end end)
			end
			list.CanvasSize = UDim2.fromOffset(0, math.ceil((#filtered + slots) / 8) * (CARD_HEIGHT + GAP))
		end
		local nextSelected = nil
		for _, entry in filtered do
			if selected and entryId(entry) == entryId(selected) and Inventory.matches(entry.Item, Inventory.expected(selected.Item)) then
				nextSelected = entry
			end
		end
		selected = nextSelected
		for _, card in cards do
			card.Outline.Color = if (if card.Entry.Crate then crateSelected else selected and entryId(card.Entry) == entryId(selected))
				then GOLD else EDGE
		end
		local fish = selected and selected.Item and selected.Item.Fish
		local species = fish and Catalog.Fish[fish.FishId]
		local secret = species ~= nil and species.Secret == true
		local reserved = state.Pending ~= nil
		for name, control in actions do
			control.Visible = (if name == "Pantry" then selected ~= nil and selected.Item.Dish ~= nil else fish ~= nil) and not reserved
			control.Active = not pending
			if name == "Hand" then
				control.Visible = control.Visible and selected.Source ~= "Hand"
				control.Text = if state.Hand then "Replace in hand" else "Take in hand"
			elseif name == "Backpack" then control.Visible = control.Visible and selected.Source ~= "Backpack"
			elseif name == "Boat" then control.Visible = control.Visible and selected.Source ~= "Boat" and aboard
			elseif name == "Favorite" then
				control.Visible = control.Visible and not secret
				control.Text = if selected and selected.Locked then "Unfavorite" else "Favorite"
			elseif name == "Release" then control.Visible = control.Visible and not selected.Locked
			elseif name == "Use" then
				control.Visible = control.Visible and secret
					and (selected.Source ~= "Boat" or aboard)
					and player:GetAttribute("TreasureUnlocked") ~= true
			end
		end
		fitPart.Visible, cancelPart.Visible = reserved, reserved
		openCrate.Visible = crateSelected and not reserved
		openCrate.Active = not pending
		detail.Text = if reserved then "Reserved boat fitting · confirm to use cargo space."
			elseif crateSelected then string.format("%s ×%d · %d–%d bait of one kind · bait goes to your equipment bag",
				Bait.Crate.Name, crates, Bait.Crate.MinBait, Bait.Crate.MaxBait)
			elseif fish then string.format("%s · %s · %s · %d space · %s%s", fishTitle(selected),
				FishCatch.formatKg(fish.Kg), if secret then "Priceless" else money(fish.Value),
				Cargo.space(selected.Item, Catalog.Fish), selected.Source,
				if secret then " · Secret" elseif selected.Locked then " · Favorite" else "")
			elseif selected then selected.Name .. " · Installed boat fitting"
			else (if tab == "Boat" and not aboard then "Climb aboard your boat to transfer fish." else "Select an item")
		refreshPreviews()
	end
	-- Roblox's core backpack binds the grave key as a core action, which outranks
	-- our sink, so the vanilla expanded inventory opened alongside ours. Disabling
	-- the Backpack CoreGui while ours is open closes and unbinds it; the numbered
	-- hotbar comes back on close (deferred, so the closing keypress can't reopen it).
	local coreBackpackBefore: boolean? = nil
	local function suppressCoreBackpack(suppress: boolean)
		if suppress then
			if coreBackpackBefore == nil then
				local ok, enabled = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack)
				coreBackpackBefore = if ok then enabled else true
			end
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)
		elseif coreBackpackBefore ~= nil then
			local restore = coreBackpackBefore
			coreBackpackBefore = nil
			task.defer(function()
				if not open then pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, restore) end
			end)
		end
	end
	setOpen = function(value)
		if value then updateLayout() end
		open, shade.Visible = value, value
		suppressCoreBackpack(value)
		toggle.Visible = not value
		player:SetAttribute("InventoryOpen", value)
		if not value then
			searchBox:ReleaseFocus()
			for _, card in cards do card.Button:Destroy() end
			cards, signature = {}, nil
			if state.Pending and not pending then send("CancelPlace") end
		else render() end
	end
	for name, control in actions do
		control.Activated:Connect(function()
			if not selected or pending then return end
			if name == "Favorite" then
				favorite(selected)
			elseif name == "Use" then
				send("UseTreasure", payload(selected))
			else
				local data = payload(selected)
				data.Destination = name
				send("InventoryMove", data)
			end
		end)
	end
	autoStore.Activated:Connect(function()
		if player:GetAttribute("OwnsAutoStore") ~= true then
			local ok = pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, Passes.AutoStore.Id)
			if not ok then notice.Text = "Couldn't open the purchase screen. Try again." end
		else send("AutoStore", state.AutoStore == false) end
	end)
	openCrate.Activated:Connect(function()
		local fishing = ReplicatedStorage:FindFirstChild("Fishing")
		local fishingRequest = fishing and fishing:FindFirstChild("Request")
		if pending or not crateSelected or not fishingRequest or player:GetAttribute("BoatDataStatus") ~= "Ready" then return end
		notice.Text, notice.TextColor3 = "Opening bait crate…", MUTED
		fishingRequest:FireServer("OpenBaitCrate")
	end)
	task.spawn(function()
		local fishingFeedback = ReplicatedStorage:WaitForChild("Fishing"):WaitForChild("Feedback") :: RemoteEvent
		fishingFeedback.OnClientEvent:Connect(function(kind, success, message)
			if kind == "BaitOpenResult" and type(message) == "string" then
				notice.Text, notice.TextColor3 = message, if success == true then MINT else RED
			end
		end)
	end)
	player:GetAttributeChangedSignal("BaitCrates"):Connect(function() render() end)
	bulk.Activated:Connect(function() send("MoveAll") end)
	fitPart.Activated:Connect(function() send("Place", 1, 1, 0) end)
	cancelPart.Activated:Connect(function() send("CancelPlace") end)
	search.Activated:Connect(function()
		searchBox.Visible = not searchBox.Visible
		summary.Size = UDim2.fromOffset(if searchBox.Visible then CONTENT - 268 else 560, 28)
		search.Position = UDim2.fromOffset(LEFT + CONTENT - (if searchBox.Visible then 48 else 108), 54)
		search.Size = UDim2.fromOffset(if searchBox.Visible then 48 else 108, 32)
		search.Text = if searchBox.Visible then "×" else "Search"
		if searchBox.Visible then searchBox:CaptureFocus() else searchBox.Text = "" searchBox:ReleaseFocus() end
	end)
	searchBox:GetPropertyChangedSignal("Text"):Connect(function() list.CanvasPosition = Vector2.zero render() end)
	list:GetPropertyChangedSignal("CanvasPosition"):Connect(refreshPreviews)
	close.Activated:Connect(function() setOpen(false) end)
	toggle.Activated:Connect(function() setOpen(not open) end)
	-- Sink the grave key before Roblox's default expanded backpack handles it;
	-- the standard numbered hotbar remains available for equipped tools.
	ContextActionService:BindActionAtPriority("ToggleInventory", function(_, inputState)
		if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		if inputState == Enum.UserInputState.Begin then setOpen(not open) end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.Backquote)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and open and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
			setOpen(false)
		end
	end)
	player:GetAttributeChangedSignal("OwnsAutoStore"):Connect(function() render() end)
	player:GetAttributeChangedSignal("OwnsBlackHoleBackpack"):Connect(function() render() end)
	player:GetAttributeChangedSignal("TreasureUnlocked"):Connect(function() render() end)
	local nextCheck = 0
	RunService.Heartbeat:Connect(profiled("CargoHold", function()
		if os.clock() < nextCheck then return end
		nextCheck = os.clock() + 0.25
		local id = player:GetAttribute("ActiveBoatId")
		local boats = workspace:FindFirstChild("PlayerBoats")
		local model = if type(id) == "string" and boats then boats:FindFirstChild(id .. "_" .. player.UserId) else nil
		local now = Aboard(player.Character, model)
		if now ~= aboard then aboard = now render() elseif open then render() end
	end))
	RunService.RenderStepped:Connect(profiled("CargoHold/2", function()
		if open then updateLayout() end
	end))
	update.OnClientEvent:Connect(applyState)
	local ok, response = pcall(request.InvokeServer, request, "Get")
	if ok and type(response) == "table" then applyState(response.State) else render() end
end

return CargoHold
