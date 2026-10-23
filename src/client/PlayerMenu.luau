-- Left-side navigation and data-backed collection screens. Gameplay remains server-owned.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Catalog = require(ReplicatedStorage.Shared.AnglerCatalog)
local Settings = require(script.Parent.PlayerSettings)
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
	return instance
end
local function round(parent, radius)
	Theme.corner(parent, if parent:IsA("TextButton") then 10 else math.min(radius or 2, 4))
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
	Theme.button(item, if item.BackgroundColor3 == gold or item.BackgroundColor3 == green then "Selected" else "Normal")
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
local function fishName(record)
	local fish = Catalog.Fish[record.FishId]
	local mutation = Catalog.Mutations[record.Mutation]
	return (if record.Mutation ~= "Normal" then (mutation and mutation.Name or record.Mutation) .. " " else "")
		.. (fish and fish.Name or record.FishId)
end
local function picture(parent, id, props)
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
	if species and species.Image and species.Image ~= "" then
		make("ImageLabel", holder, {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = species.Image,
			ScaleType = Enum.ScaleType.Fit,
		})
	else
		text(
			holder,
			if species then species.Name else "No catch yet",
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
	local busy = false
	local render
	local narrow = false
	local gui = make(
		"ScreenGui",
		player:WaitForChild("PlayerGui"),
		{ Name = "PlayerMenu", ResetOnSpawn = false, DisplayOrder = 30, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }
	)
	local sidebar = make("Frame", gui, {
		Name = "LeftNavigation",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0.45, -135),
		Size = UDim2.fromOffset(148, 280),
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
			Theme.button(item, if name == active then "Selected" else "Normal")
		end
	end
	local function close()
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
		local search = input(content, "Search fish or mutations…")
		local body = scroll(content, { Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 1, -54) })
		local emptyState = make(
			"Frame",
			content,
			{ BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 1, -54) }
		)
		local grid = make("UIGridLayout", body, {
			CellSize = UDim2.new(if narrow then 1 else 0.5, -8, 0, 240),
			CellPadding = UDim2.fromOffset(8, 12),
			SortOrder = Enum.SortOrder.Name,
		})
		local function fill()
			for _, child in body:GetChildren() do
				if child ~= grid then
					child:Destroy()
				end
			end
			local found = 0
			local query = string.lower(search.Text)
			for id, species in Catalog.Fish do
				local entry = profile.Angler.Catches[id]
				local mutationNames = {}
				for mutation, count in (entry and entry.Mutations or {}) do
					local info = Catalog.Mutations[mutation]
					table.insert(mutationNames, (info and info.Name or mutation) .. " ×" .. count)
				end
				table.sort(mutationNames)
				local mutations = table.concat(mutationNames, ", ")
				if query ~= "" and not string.find(string.lower(species.Name .. " " .. mutations), query, 1, true) then
					continue
				end
				found += 1
				local tile = make("Frame", body, { Name = species.Name, BackgroundColor3 = paper, BorderSizePixel = 0 })
				round(tile)
				picture(tile, id, { Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 0, 86) })
				text(tile, species.Name, 19, ink, {
					Position = UDim2.fromOffset(14, 104),
					Size = UDim2.new(1, -28, 0, 26),
					Font = Enum.Font.GothamBold,
				})
				text(
					tile,
					string.format(
						"%d caught   ·   Biggest: %s",
						entry and entry.Count or 0,
						if entry then string.format("%.2f kg", entry.BiggestKg) else "—"
					),
					14,
					ink,
					{ Position = UDim2.fromOffset(14, 137), Size = UDim2.new(1, -28, 0, 30) }
				)
				local mutationScroll = scroll(tile)
				mutationScroll.Position = UDim2.fromOffset(14, 173)
				mutationScroll.Size = UDim2.new(1, -28, 0, 55)
				mutationScroll.ScrollBarImageColor3 = Theme.Colors.Inset
				text(
					mutationScroll,
					"Mutations: " .. (if mutations ~= "" then mutations else "None caught yet"),
					13,
					ink,
					{
						Size = UDim2.new(1, -8, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						TextYAlignment = Enum.TextYAlignment.Top,
					}
				)
			end
			if found == 0 then
				emptyState:ClearAllChildren()
				empty(
					emptyState,
					if next(Catalog.Fish) then "No matching fish" else "A bestiary waiting to be written",
					if next(Catalog.Fish)
						then "Try another search."
						else "New fish species will appear here as they are added. Your catches will record each mutation, total caught, and biggest weight in kg."
				)
			end
			emptyState.Visible, body.Visible = found == 0, found > 0
		end
		search:GetPropertyChangedSignal("Text"):Connect(fill)
		fill()
	end
	local function equipment()
		local body = scroll(content)
		list(body, 12)
		local count = 0
		local ids = {}
		for id, owned in profile.OwnedRods do
			if owned then
				table.insert(ids, id)
			end
		end
		for id, owned in profile.OwnedBoats do
			if owned then
				table.insert(ids, "Boat:" .. id)
			end
		end
		table.sort(ids)
		for _, id in ids do
			count += 1
			local info = Catalog.Equipment[id]
			local isBoat = string.sub(id, 1, 5) == "Boat:"
			local tile = make("Frame", body, {
				Name = id,
				BackgroundColor3 = Theme.Colors.Panel,
				Size = UDim2.new(1, -8, 0, if narrow then 168 else 116),
				BorderSizePixel = 0,
			})
			round(tile)
			text(tile, info and info.Name or (if isBoat then string.sub(id, 6) else id), 21, cream, {
				Position = UDim2.fromOffset(16, 10),
				Size = UDim2.new(1, if narrow then -32 else -215, 0, 32),
				Font = Enum.Font.GothamBold,
			})
			text(
				tile,
				if isBoat
					then "Boat · Spawn at the boat stand on your dock."
					else (info and info.Description or "Owned fishing equipment"),
				14,
				muted,
				{ Position = UDim2.fromOffset(16, 49), Size = UDim2.new(1, if narrow then -32 else -215, 0, 50) }
			)
			if id == "StarterRod" then
				button(tile, if player:GetAttribute("RodEquipped") then "Stow rod" else "Equip rod", function()
					if player:GetAttribute("BoatDataStatus") == "Ready" then
						ReplicatedStorage.Fishing.Request:FireServer(
							if player:GetAttribute("RodEquipped") then "UnequipRod" else "EquipRod"
						)
					end
				end, {
					Position = if narrow then UDim2.fromOffset(16, 110) else UDim2.new(1, -184, 0, 36),
					Size = UDim2.fromOffset(168, 42),
					BackgroundColor3 = gold,
					TextColor3 = navy,
				})
			end
		end
		if count == 0 then
			empty(
				content,
				"Your equipment bag is empty",
				"Visit the plaza tackle shop to collect your free starter fishing rod. Every rod you own will appear here."
			)
		end
	end
	local function journal()
		local book = scroll(content)
		local left = make("Frame", book, {
			Name = "JournalStatsPage",
			BackgroundColor3 = paper,
			BorderSizePixel = 0,
			Size = if narrow then UDim2.new(1, -8, 0, 500) else UDim2.new(0.49, -6, 0, 510),
		})
		round(left, 8)
		local right = make("Frame", book, {
			Name = "JournalFindingsPage",
			BackgroundColor3 = paper,
			BorderSizePixel = 0,
			Position = if narrow then UDim2.fromOffset(0, 514) else UDim2.new(0.51, 0, 0, 0),
			Size = if narrow then UDim2.new(1, -8, 0, 548) else UDim2.new(0.49, -6, 0, 548),
		})
		round(right, 8)
		if not narrow then
			for y = 24, 510, 40 do
				local binding = make("Frame", book, {
					BackgroundColor3 = ink,
					Position = UDim2.new(0.49, -4, 0, y),
					Size = UDim2.new(0.02, 10, 0, 7),
					BorderSizePixel = 0,
					ZIndex = 2,
				})
				round(binding, 4)
			end
		end
		text(
			left,
			"ANGLER'S JOURNAL",
			21,
			ink,
			{ Position = UDim2.fromOffset(18, 14), Size = UDim2.new(1, -36, 0, 32), Font = Enum.Font.GothamBold }
		)
		local avatar = make("ImageLabel", left, {
			BackgroundColor3 = Color3.fromRGB(181, 172, 146),
			Position = UDim2.fromOffset(18, 58),
			Size = UDim2.fromOffset(68, 68),
		})
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
		text(
			left,
			player.DisplayName,
			17,
			ink,
			{ Position = UDim2.fromOffset(98, 57), Size = UDim2.new(1, -112, 0, 36), Font = Enum.Font.GothamBold }
		)
		text(
			left,
			"@" .. player.Name,
			13,
			ink,
			{ Position = UDim2.fromOffset(98, 96), Size = UDim2.new(1, -112, 0, 26) }
		)
		local search = input(left, "Search journal…")
		search.Position, search.Size = UDim2.fromOffset(18, 143), UDim2.new(1, -36, 0, 36)
		local rows = scroll(left, {
			Position = UDim2.fromOffset(18, 237),
			Size = UDim2.new(1, -36, 1, -250),
			ScrollBarImageColor3 = Theme.Colors.Inset,
		})
		list(rows, 3)
		local function fill()
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
					{ "Astral anomalies activated", stats.AstralAnomaliesActivated },
					{ "Bestiary pages completed", stats.BestiaryPagesCompleted },
					{ "Limited bestiaries completed", stats.LimitedBestiariesCompleted },
					{ "Permanent bestiaries completed", stats.PermanentBestiariesCompleted },
					{ "Fish caught", stats.TotalCaught },
					{ "Fish species discovered", discovered },
					{ "Catch streak", stats.CatchStreak },
					{ "Highest catch streak", stats.HighestCatchStreak },
					{ "Treasure chests opened", stats.TreasureChestsOpened },
					{ "Sunken chests opened", stats.SunkenChestsOpened },
					{ "Coins", profile.Cash },
					{ "Lifetime coins earned", stats.CoinsEarned },
					{ "Lifetime coins spent", stats.CoinsSpent },
					{ "Crab cages opened", stats.CrabCagesOpened },
					{ "Deaths", stats.Deaths },
				}
			else
				entries = {
					{ "First catch", if stats.TotalCaught >= 1 then "Complete" else "0 / 1" },
					{
						"Getting the hang of it",
						if stats.TotalCaught >= 10 then "Complete" else stats.TotalCaught .. " / 10",
					},
					{
						"Seasoned angler",
						if stats.TotalCaught >= 100 then "Complete" else stats.TotalCaught .. " / 100",
					},
				}
			end
			for i, entry in entries do
				if not string.find(string.lower(entry[1]), string.lower(search.Text), 1, true) then
					continue
				end
				local row = make("Frame", rows, {
					BackgroundColor3 = ink,
					BackgroundTransparency = 0,
					Size = UDim2.new(1, -6, 0, 42),
					LayoutOrder = i,
					BorderSizePixel = 0,
				})
				text(row, entry[1], 14, ink, { Position = UDim2.fromOffset(5, 0), Size = UDim2.new(0.7, -5, 1, 0) })
				text(row, tostring(entry[2]), 14, ink, {
					Position = UDim2.fromScale(0.7, 0),
					Size = UDim2.new(0.3, -6, 1, 0),
					TextXAlignment = Enum.TextXAlignment.Right,
					Font = Enum.Font.GothamBold,
				})
			end
		end
		for index, tab in { "Stats", "Achievements" } do
			button(left, tab, function()
				journalTab = tab
				render()
			end, {
				BackgroundColor3 = if journalTab == tab then gold else Theme.Colors.Panel,
				TextColor3 = ink,
				TextSize = 13,
				Position = UDim2.new((index - 1) * 0.5, if index == 1 then 18 else 3, 0, 188),
				Size = UDim2.new(0.5, -21, 0, 36),
			})
		end
		search:GetPropertyChangedSignal("Text"):Connect(fill)
		fill()
		text(right, "FINDINGS", 21, ink, {
			Position = UDim2.fromOffset(18, 14),
			Size = UDim2.new(1, -36, 0, 32),
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		local findings = profile.Angler.Findings
		local mostId, mostCount = nil, 0
		for id, entry in profile.Angler.Catches do
			if entry.Count > mostCount then
				mostId, mostCount = id, entry.Count
			end
		end
		local cards = {
			{
				"Highest value",
				findings.HighestValue,
				function(r)
					return string.format("$%.0f", r.Value)
				end,
			},
			{
				"Rarest",
				findings.Rarest,
				function(r)
					return "1 in " .. r.Rarity .. " · " .. os.date("!%b %d, %Y", r.CaughtAt)
				end,
			},
			{
				"Most caught",
				mostId and { FishId = mostId, Mutation = "Normal" },
				function()
					return mostCount .. " caught"
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
				"Relative largest",
				findings.RelativeLargest,
				function(r)
					return string.format("%.2f kg · %.2f× average", r.Kg, r.Relative)
				end,
			},
		}
		for i, entry in cards do
			local full = i == 1
			local x = if full or i % 2 == 0 then 0 else 0.5
			local y = if full then 58 else 222 + math.floor((i - 2) / 2) * 157
			local tile = make("Frame", right, {
				BackgroundTransparency = 1,
				Position = UDim2.new(x, 14, 0, y),
				Size = UDim2.new(if full then 1 else 0.5, -28, 0, 149),
			})
			text(tile, entry[1], 14, ink, {
				Size = UDim2.new(1, 0, 0, 24),
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			local r = entry[2]
			picture(tile, r and r.FishId, { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 65) })
			text(tile, if r then fishName(r) else "—", 13, ink, {
				Position = UDim2.fromOffset(0, 97),
				Size = UDim2.new(1, 0, 0, 24),
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			text(tile, if r then entry[3](r) else "No catch yet", 12, ink, {
				Position = UDim2.fromOffset(0, 124),
				Size = UDim2.new(1, 0, 0, 24),
				TextXAlignment = Enum.TextXAlignment.Center,
			})
		end
	end
	local function settings()
		local tabs = make(
			"Frame",
			content,
			{ BackgroundTransparency = 1, Size = if narrow then UDim2.new(1, 0, 0, 44) else UDim2.new(0, 200, 1, 0) }
		)
		for i, name in { "Performance", "Audio", "Codes", "Titles" } do
			button(tabs, name, function()
				settingTab = name
				render()
			end, {
				Name = name .. "Tab",
				TextSize = if narrow then 12 else 18,
				Position = if narrow then UDim2.new((i - 1) / 4, 0, 0, 0) else UDim2.fromOffset(0, (i - 1) * 66),
				Size = if narrow then UDim2.new(0.25, -4, 0, 40) else UDim2.new(1, -10, 0, 56),
				BackgroundColor3 = if settingTab == name then gold else Theme.Colors.Panel,
				TextColor3 = if settingTab == name then navy else cream,
			})
		end
		local body = scroll(content, {
			Position = if narrow then UDim2.fromOffset(0, 56) else UDim2.fromOffset(220, 0),
			Size = if narrow then UDim2.new(1, 0, 1, -56) else UDim2.new(1, -220, 1, 0),
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
			text(
				row,
				name,
				18,
				cream,
				{ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 28), Font = Enum.Font.GothamBold }
			)
			text(row, description, 13, muted, { Position = UDim2.fromOffset(14, 39), Size = UDim2.new(1, -28, 0, 36) })
			if type(value) == "boolean" then
				button(row, if value then "On" else "Off", function()
					request("Setting", key, not value)
				end, {
					Name = key,
					Position = UDim2.new(1, -104, 1, -44),
					Size = UDim2.fromOffset(90, 34),
					BackgroundColor3 = if value then green else navy,
					TextColor3 = if value then navy else cream,
				})
			else
				button(row, "−", function()
					request("Setting", key, math.max(0, value - 10))
				end, { Name = key .. "Down", Position = UDim2.new(1, -184, 1, -44), Size = UDim2.fromOffset(40, 34) })
				text(row, value .. "%", 16, gold, {
					Position = UDim2.new(1, -140, 1, -44),
					Size = UDim2.fromOffset(76, 34),
					TextXAlignment = Enum.TextXAlignment.Center,
				})
				button(row, "+", function()
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
			button(body, "Redeem code", function()
				request("Code", field.Text)
			end, { BackgroundColor3 = gold, TextColor3 = navy })
		elseif settingTab == "Titles" then
			text(body, "Choose a title you have unlocked.", 15, muted, { Size = UDim2.new(1, -8, 0, 40) })
			button(
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
					button(
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
			Bestiary = "Every species. Every mutation. Every personal best.",
			["Equipment bag"] = "The equipment you own, ready for your next trip.",
			Journal = "Your story on the water, one catch at a time.",
			Settings = "Make yourself at home on the water.",
			Shop = "The Fishing Waters Robux shop.",
		})[active]
		if active == "Shop" then
			empty(content, "Nothing in the shop yet", "Robux items will appear here when they are added.")
		elseif not profile then
			empty(
				content,
				"Your progress is loading",
				"Your collection and settings will appear once your saved progress is available."
			)
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
	for index, name in { "Bestiary", "Equipment bag", "Journal", "Settings", "Shop" } do
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
				GuiService.SelectedObject = closeButton
			end
		end, {
			Name = name:gsub(" ", ""),
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundTransparency = 0,
			TextSize = 14,
		})
	end
	UserInputService.InputBegan:Connect(function(event)
		if overlay.Visible and (event.KeyCode == Enum.KeyCode.Escape or event.KeyCode == Enum.KeyCode.ButtonB) then
			close()
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
		sidebar.Size = UDim2.fromOffset(if gui.AbsoluteSize.X < 680 then 116 else 148, 280)
		for _, item in navButtons do
			item.TextSize = 16
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
