-- Collection presentation only. Equipping still goes through FishingService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Catalog = require(ReplicatedStorage.Shared.AnglerCatalog)
local BoatCatalog = require(ReplicatedStorage.Shared.BoatCatalog)
local FishingRod = require(ReplicatedStorage.Shared.FishingRod)
local RodSkins = require(ReplicatedStorage.Shared.RodSkins)

local Bag = {}
local white = Color3.fromRGB(245, 245, 245)
local grey = Color3.fromRGB(170, 173, 175)
local mint = Color3.fromRGB(155, 255, 190)
local edge = Color3.fromRGB(73, 79, 82)
local state = { Category = "Baits", RodQuery = "", ItemQuery = "", Reverse = false, Compact = false, Favorites = {} }

-- Use native square, lightly outlined surfaces instead of the shared metal finish.
local function make(class, parent, props)
	local item = Instance.new(class)
	if item:IsA("GuiObject") then
		item.BorderSizePixel = 0
		item.BackgroundTransparency = 1
	end
	for key, value in props do
		item[key] = value
	end
	item.Parent = parent
	return item
end

local function outline(item, color, thickness)
	local border = item:FindFirstChildOfClass("UIStroke") or make("UIStroke", item, {})
	for key, value in
		{
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = color or edge,
			Thickness = thickness or 1,
			Transparency = 0.2,
		}
	do
		border[key] = value
	end
	return border
end

local function panel(parent, name, position, size)
	local item = make("Frame", parent, {
		Name = name,
		Position = position,
		Size = size,
		BackgroundColor3 = Color3.fromRGB(5, 9, 10),
		BackgroundTransparency = 0.22,
	})
	outline(item)
	return item
end

local function label(parent, value, size, props)
	local item = make("TextLabel", parent, {
		Text = value,
		TextSize = size,
		Font = Enum.Font.SourceSansBold,
		RichText = true,
		TextColor3 = white,
		TextStrokeColor3 = Color3.new(),
		TextStrokeTransparency = 0.25,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	})
	for key, value in props do
		item[key] = value
	end
	return item
end

local function action(parent, name, value, position, size, callback, selected)
	local item = make("TextButton", parent, {
		Name = name,
		Text = value,
		Position = position,
		Size = size,
		Font = Enum.Font.SourceSans,
		TextSize = 21,
		TextColor3 = if selected then mint else white,
		TextStrokeTransparency = 0.7,
		BackgroundColor3 = Color3.fromRGB(13, 17, 17),
		BackgroundTransparency = 0.35,
		AutoButtonColor = true,
	})
	outline(item, if selected then mint else grey)
	item.Activated:Connect(callback)
	return item
end

local function search(parent, name, placeholder, value, position, size)
	local item = make("TextBox", parent, {
		Name = name,
		Text = value,
		PlaceholderText = placeholder,
		ClearTextOnFocus = false,
		Position = position,
		Size = size,
		Font = Enum.Font.SourceSans,
		TextSize = 20,
		TextColor3 = white,
		PlaceholderColor3 = Color3.fromRGB(125, 128, 128),
		TextXAlignment = Enum.TextXAlignment.Right,
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.45,
	})
	outline(item)
	make("UIPadding", item, { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })
	return item
end

local function scrolling(parent, name, position, size, horizontal)
	local body = make("ScrollingFrame", parent, {
		Name = name,
		Position = position,
		Size = size,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = if horizontal then Enum.AutomaticSize.X else Enum.AutomaticSize.Y,
		ScrollingDirection = if horizontal then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = grey,
		ScrollBarImageTransparency = 0.4,
		ClipsDescendants = true,
	})
	make("UIListLayout", body, {
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	})
	return body
end

local function rodPreview(parent, skinId)
	local view = make("ViewportFrame", parent, {
		Name = "RodPreview",
		Position = UDim2.fromScale(0.04, 0.02),
		Size = UDim2.fromScale(0.92, 0.85),
		Ambient = Color3.fromRGB(165, 170, 175),
		LightColor = Color3.fromRGB(255, 241, 216),
		LightDirection = Vector3.new(-1, -1, -2),
	})
	local world = make("WorldModel", view, { Name = "PreviewWorld" })
	local rod = FishingRod.build(skinId)
	-- Preview tools must never join the live rod animation/tag listeners.
	CollectionService:RemoveTag(rod, "FishingRod")
	rod.Enabled = false
	for _, part in rod:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	local model = make("Model", world, { Name = "DisplayRod" })
	rod.Parent = model
	local center, size = model:GetBoundingBox()
	-- Tilt the real rod from lower left to upper right, as in the collection reference.
	model:PivotTo(CFrame.Angles(0, math.rad(-18), math.rad(-13)) * center:Inverse() * model:GetPivot())
	local camera = make("Camera", view, { FieldOfView = 36 })
	local function framePreview()
		local aspect = math.max(0.15, view.AbsoluteSize.X / math.max(1, view.AbsoluteSize.Y))
		local height = size.Y + size.X * 0.25
		local width = size.X + size.Y * 0.25
		local distance = math.max(height, width / aspect) * 0.56 / math.tan(math.rad(18))
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, distance), Vector3.new(0, 0, 0))
	end
	view.CurrentCamera = camera
	view:GetPropertyChangedSignal("AbsoluteSize"):Connect(framePreview)
	framePreview()
end

function Bag.show(parent, profile, player, narrow)
	local root = make("Frame", parent, { Name = "EquipmentCollection", Size = UDim2.fromScale(1, 1) })
	local rods = panel(
		root,
		"FishingRods",
		UDim2.fromOffset(0, 0),
		if narrow then UDim2.new(1, 0, 0.61, -5) else UDim2.new(0.67, -8, 1, 0)
	)
	local items = panel(
		root,
		"ItemCollection",
		if narrow then UDim2.new(0, 0, 0.61, 5) else UDim2.new(0.67, 0, 0, 0),
		if narrow then UDim2.new(0.62, -5, 0.39, -5) else UDim2.new(0.19, -8, 1, 0)
	)
	local rail = scrolling(
		root,
		"EquipmentCategories",
		if narrow then UDim2.new(0.62, 5, 0.61, 5) else UDim2.new(0.86, 0, 0, 48),
		if narrow then UDim2.new(0.38, -5, 0.39, -5) else UDim2.new(0.14, 0, 1, -48),
		false
	)
	rail.ScrollBarThickness = 3
	label(rods, "Fishing Rods", if narrow then 19 else 26, {
		Position = UDim2.fromOffset(12, 7),
		Size = UDim2.new(if narrow then 0.45 else 0.32, -12, 0, 34),
	})
	local owned, available = 0, 0
	for id, info in Catalog.Equipment do
		if info.Kind == "Fishing rod" then
			available += 1
			if profile.OwnedRods[id] then
				owned += 1
			end
		end
	end
	for id in RodSkins.Skins do
		available += 1
		if (profile.RodSkins or {})[id] then
			owned += 1
		end
	end
	label(
		rods,
		string.format("<i>%d%% Unlocked</i>", if available > 0 then math.floor(owned / available * 100) else 0),
		if narrow then 15 else 18,
		{
			Name = "UnlockedCount",
			Position = UDim2.new(if narrow then 0.45 else 0.32, 0, 0, 8),
			Size = UDim2.new(if narrow then 0.3 else 0.28, -4, 0, 30),
		}
	)
	local rodSearch = search(
		rods,
		"SearchRods",
		"Search Rods..",
		state.RodQuery,
		if narrow then UDim2.fromOffset(10, 47) else UDim2.new(0.6, 0, 0, 7),
		if narrow then UDim2.new(1, -64, 0, 32) else UDim2.new(0.4, -54, 0, 34)
	)
	local body = scrolling(
		rods,
		"RodCards",
		UDim2.fromOffset(10, if narrow then 89 else 53),
		UDim2.new(1, -20, 1, if narrow then -99 else -63),
		true
	)
	local fillRods
	local compact = action(
		rods,
		"CardDensity",
		"▦",
		UDim2.new(1, -46, 0, if narrow then 47 else 7),
		UDim2.fromOffset(34, 32),
		function()
			state.Compact = not state.Compact
			fillRods()
		end
	)
	compact.TextSize = 26
	local function empty(body, title, description)
		label(body, "<i>" .. title .. "</i>", 19, {
			Size = UDim2.new(1, -12, 0, 50),
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		label(body, description, 15, {
			Size = UDim2.new(1, -12, 0, 95),
			TextColor3 = grey,
			LayoutOrder = 1,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
	end
	fillRods = function()
		for _, child in body:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
		local ids = {}
		for id, ownedRod in profile.OwnedRods do
			local info = Catalog.Equipment[id]
			if
				ownedRod and string.find(string.lower(info and info.Name or id), string.lower(state.RodQuery), 1, true)
			then
				table.insert(ids, { Key = id, Id = id, Info = info })
			end
		end
		for _, copy in profile.RodSkinCopies or {} do
			local skin = RodSkins.Skins[copy.SkinId]
			local serialText = string.format("Serial #%06d", copy.Serial)
			if
				skin
				and string.find(string.lower(skin.Name .. " " .. serialText), string.lower(state.RodQuery), 1, true)
			then
				table.insert(ids, {
					Key = "Skin:" .. copy.SkinId .. ":" .. copy.Serial,
					Id = copy.SkinId,
					Serial = copy.Serial,
					Info = {
						Name = skin.Name,
						Kind = skin.Rarity .. " skin",
						Description = table.concat(RodSkins.perks(copy.SkinId), " · "),
					},
				})
			end
		end
		table.sort(ids, function(a, b)
			if state.Favorites[a.Key] ~= state.Favorites[b.Key] then
				return state.Favorites[a.Key] == true
			end
			if a.Id == b.Id then
				return (a.Serial or 0) < (b.Serial or 0)
			end
			return a.Id < b.Id
		end)
		if #ids == 0 then
			-- Empty states use a vertical layout instead of horizontal card placement.
			local blank = make("Frame", body, { Name = "EmptyRods", Size = UDim2.new(1, -6, 1, -8) })
			make("UIListLayout", blank, { Padding = UDim.new(0, 8) })
			empty(
				blank,
				if owned == 0 then "Your equipment bag is empty" else "No matching rods",
				if owned == 0
					then "Your starter rod is still loading. Please try again shortly."
					else "Try another rod name."
			)
			return
		end
		for index, entry in ids do
			local id, info, serial = entry.Id, entry.Info, entry.Serial
			local activeSkin = serial ~= nil
				and player:GetAttribute("RodSkin") == id
				and player:GetAttribute("RodSkinSerial") == serial
			local tile = panel(
				body,
				entry.Key,
				UDim2.fromOffset(0, 0),
				UDim2.new(if narrow then 0.86 elseif state.Compact then 0.25 else 1 / 3, -8, 1, -8)
			)
			tile.LayoutOrder = index
			outline(
				tile,
				if activeSkin or (player:GetAttribute("RodEquipped") and id == "StarterRod") then mint else edge,
				2
			)
			if id == "StarterRod" then
				local skin = player:GetAttribute("RodSkin")
				rodPreview(tile, if type(skin) == "string" and skin ~= "" then skin else nil)
			elseif serial then
				rodPreview(tile, id)
			end
			label(
				tile,
				"<i>"
					.. (info and info.Kind or "Fishing rod")
					.. "\n"
					.. (if serial then string.format("Serial #%06d", serial) else "Owned")
					.. "</i>",
				18,
				{
					Name = "RodDetails",
					Position = UDim2.fromOffset(10, 9),
					Size = UDim2.new(1, -52, 0, 56),
					TextColor3 = grey,
					TextYAlignment = Enum.TextYAlignment.Top,
				}
			)
			local favorite = action(
				tile,
				"FavoriteRod",
				if state.Favorites[entry.Key] then "★" else "☆",
				UDim2.new(1, -40, 0, 8),
				UDim2.fromOffset(30, 32),
				function()
					state.Favorites[entry.Key] = not state.Favorites[entry.Key] or nil
					fillRods()
				end,
				state.Favorites[entry.Key]
			)
			favorite.TextSize, favorite.BackgroundTransparency = 30, 1
			label(tile, "<i>[" .. (info and info.Name or id) .. "]</i>", 18, {
				Name = "RodName",
				Position = UDim2.new(0, 8, 1, -134),
				Size = UDim2.new(1, -16, 0, 44),
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			label(tile, "<i>" .. (info and info.Description or "Owned fishing equipment") .. "</i>", 15, {
				Position = UDim2.new(0, 10, 1, -91),
				Size = UDim2.new(1, -20, 0, 43),
				TextColor3 = grey,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			if id == "StarterRod" then
				local equipped = player:GetAttribute("RodEquipped") == true
				local equip = action(
					tile,
					"EquipRod",
					if equipped then "[Equipped · Stow]" else "[Equip]",
					UDim2.new(0, 10, 1, -43),
					UDim2.new(1, -20, 0, 34),
					function()
						if player:GetAttribute("BoatDataStatus") == "Ready" then
							ReplicatedStorage.Fishing.Request:FireServer(
								if player:GetAttribute("RodEquipped") then "UnequipRod" else "EquipRod"
							)
						end
					end,
					true
				)
				equip.TextSize = 20
			elseif serial then
				local equip = action(
					tile,
					"EquipSkin",
					if activeSkin then "[Selected · Remove skin]" else "[Use skin]",
					UDim2.new(0, 10, 1, -43),
					UDim2.new(1, -20, 0, 34),
					function()
						if player:GetAttribute("BoatDataStatus") == "Ready" then
							ReplicatedStorage.Fishing.Request:FireServer(
								"EquipRodSkin",
								if activeSkin then "" else { SkinId = id, Serial = serial }
							)
						end
					end,
					activeSkin
				)
				equip.TextSize = 18
			end
		end
	end
	rodSearch:GetPropertyChangedSignal("Text"):Connect(function()
		state.RodQuery = rodSearch.Text
		fillRods()
	end)
	local itemTitle = label(items, "", if narrow then 23 else 32, {
		Position = UDim2.fromOffset(10, 2),
		Size = UDim2.new(1, -20, 0, 39),
	})
	local itemSearch =
		search(items, "SearchItems", "", state.ItemQuery, UDim2.fromOffset(10, 46), UDim2.new(1, -20, 0, 32))
	local itemBody = scrolling(items, "ItemCards", UDim2.fromOffset(10, 121), UDim2.new(1, -20, 1, -131), false)
	local fillItems
	local sort = action(
		items,
		"SortItems",
		"▾  Name: A–Z",
		UDim2.fromOffset(10, 86),
		UDim2.new(1, -20, 0, 27),
		function()
			state.Reverse = not state.Reverse
			fillItems()
		end
	)
	sort.TextSize, sort.TextXAlignment = 17, Enum.TextXAlignment.Left
	local tabs = {}
	fillItems = function()
		itemTitle.Text = "<i>" .. state.Category .. "</i>"
		itemSearch.PlaceholderText = "Search " .. state.Category .. ".."
		sort.Text = if state.Reverse then "▾  Name: Z–A" else "▾  Name: A–Z"
		for category, tab in tabs do
			tab.TextColor3 = if category == state.Category then mint else white
			tab.BackgroundTransparency = if category == state.Category then 0.18 else 0.4
			tab:FindFirstChildOfClass("UIStroke").Color = if category == state.Category then mint else grey
		end
		for _, child in itemBody:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
		local boats = {}
		if state.Category == "Boats" then
			for id, isOwned in profile.OwnedBoats do
				local info = BoatCatalog[id]
				if
					isOwned
					and string.find(string.lower(info and info.Name or id), string.lower(state.ItemQuery), 1, true)
				then
					table.insert(boats, id)
				end
			end
		end
		table.sort(boats, function(a, b)
			local aName, bName =
				BoatCatalog[a] and BoatCatalog[a].Name or a, BoatCatalog[b] and BoatCatalog[b].Name or b
			return if state.Reverse then aName > bName else aName < bName
		end)
		for index, id in boats do
			local info = BoatCatalog[id]
			local tile = panel(itemBody, "Boat:" .. id, UDim2.fromOffset(0, 0), UDim2.new(1, -7, 0, 160))
			tile.LayoutOrder = index
			label(tile, "<i>[" .. (info and info.Name or id) .. "]</i>", 20, {
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.new(1, -16, 0, 52),
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			label(tile, "Owned\nLaunch from the boat stand on your dock.", 17, {
				Position = UDim2.fromOffset(8, 64),
				Size = UDim2.new(1, -16, 0, 85),
				TextColor3 = grey,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
		end
		if #boats == 0 then
			empty(
				itemBody,
				if state.ItemQuery ~= "" then "No matching items" else "No " .. string.lower(state.Category) .. " yet",
				if state.ItemQuery ~= ""
					then "Try another search."
					elseif state.Category == "Boats" then "Your owned boats appear here."
					else "There are no items in this category to equip."
			)
		end
	end
	itemSearch:GetPropertyChangedSignal("Text"):Connect(function()
		state.ItemQuery = itemSearch.Text
		fillItems()
	end)
	-- Boats retain access to the previously listed owned vessels.
	for index, category in { "Bobbers", "Baits", "Lanterns", "Accessories", "Boats" } do
		tabs[category] = action(
			rail,
			category .. "Category",
			"[" .. category .. "]",
			UDim2.new(0, 0, 0, (index - 1) * (if narrow then 35 else 62)),
			UDim2.new(1, 0, 0, if narrow then 30 else 50),
			function()
				state.Category, state.ItemQuery = category, ""
				itemSearch.Text = ""
				fillItems()
			end,
			category == state.Category
		)
		tabs[category].TextSize = if narrow then 17 else 21
		tabs[category].LayoutOrder = index
		tabs[category].Size = UDim2.new(1, -6, 0, if narrow then 30 else 50)
	end
	fillRods()
	fillItems()
	return root
end

return Bag
