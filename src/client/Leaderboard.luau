local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Theme = require(ReplicatedFirst:WaitForChild("UITheme"))
local FishingRanks = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FishingRanks"))

local Leaderboard = {}

local function label(parent, text, position, size, alignment)
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Position = position
	item.Size = size
	item.Text = text
	item.TextSize = 14
	item.Font = Enum.Font.GothamMedium
	item.TextColor3 = Color3.fromRGB(242, 242, 245)
	item.TextXAlignment = alignment or Enum.TextXAlignment.Left
	item.TextTruncate = Enum.TextTruncate.AtEnd
	item.Parent = parent
	return item
end

local function formatMoney(value)
	local amount = tonumber(value)
	if not amount then
		return "—"
	end
	local absolute = math.abs(amount)
	for _, suffix in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e4, "K" } } do
		if absolute >= suffix[1] then
			local divisor = if suffix[2] == "K" then 1e3 else suffix[1]
			local abbreviated = string.format("%.1f", amount / divisor):gsub("%.0$", "")
			return abbreviated .. suffix[2]
		end
	end
	local digits = tostring(math.floor(absolute))
	while true do
		local formatted, replacements = digits:gsub("^(%d+)(%d%d%d)", "%1,%2")
		digits = formatted
		if replacements == 0 then
			break
		end
	end
	return (if amount < 0 then "-" else "") .. digits
end

-- Use the same proportional columns in the header and each player row.
local function columns(parent, playerText, moneyText, levelText, bestiaryText, header)
	local playerName = label(parent, playerText, UDim2.fromScale(0, 0), UDim2.new(0.44, -4, 1, 0))
	local money = label(parent, moneyText, UDim2.fromScale(0.44, 0), UDim2.new(0.18, 0, 1, 0), Enum.TextXAlignment.Center)
	local level = label(parent, levelText, UDim2.fromScale(0.62, 0), UDim2.new(0.15, 0, 1, 0), Enum.TextXAlignment.Center)
	local bestiary = label(parent, bestiaryText, UDim2.fromScale(0.77, 0), UDim2.new(0.23, 0, 1, 0), Enum.TextXAlignment.Center)
	if header then
		for _, item in { playerName, money, level, bestiary } do
			item.TextSize = 12
			item.Font = Enum.Font.Gotham
			item.TextColor3 = Color3.fromRGB(177, 176, 188)
		end
	end
	return playerName, money, level, bestiary
end

function Leaderboard.start()
	local localPlayer = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "CustomLeaderboard"
	gui.ResetOnSpawn = false
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local toggle = Instance.new("TextButton")
	toggle.Name = "Toggle"
	toggle.AnchorPoint = Vector2.new(1, 0)
	toggle.Position = UDim2.new(1, -12, 0, 8)
	toggle.Size = UDim2.fromOffset(100, 32)
	toggle.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	toggle.BorderSizePixel = 0
	toggle.Text = "Players"
	toggle.TextColor3 = Color3.fromRGB(242, 242, 245)
	toggle.Font = Enum.Font.GothamMedium
	toggle.TextSize = 14
	Theme.corner(toggle, 8)
	toggle.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "PlayerList"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -12, 0, 8)
	panel.Size = UDim2.new(0.9, 0, 0.86, 0)
	panel.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	panel.BorderSizePixel = 0
	Theme.corner(panel, 8)
	panel.Parent = gui
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(480, 670)
	constraint.Parent = panel

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Position = UDim2.fromOffset(5, 0)
	close.Size = UDim2.fromOffset(30, 26)
	close.BackgroundTransparency = 1
	close.Text = "×"
	close.Font = Enum.Font.Gotham
	close.TextSize = 24
	close.TextColor3 = Color3.fromRGB(245, 245, 245)
	close.Parent = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Position = UDim2.fromOffset(15, 25)
	header.Size = UDim2.new(1, -30, 0, 20)
	header.BackgroundTransparency = 1
	header.Parent = panel
	columns(header, "People", "Money", "Level", "Bestiary", true)

	local list = Instance.new("ScrollingFrame")
	list.Name = "Rows"
	list.Position = UDim2.fromOffset(15, 48)
	list.Size = UDim2.new(1, -30, 1, -55)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = Color3.fromRGB(45, 45, 49)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local expanded = true
	local function updateVisibility()
		local available = localPlayer:GetAttribute("BuildModeOpen") ~= true
		toggle.Visible = available and not expanded
		panel.Visible = available and expanded
	end
	toggle.Activated:Connect(function()
		expanded = true
		updateVisibility()
	end)
	close.Activated:Connect(function()
		expanded = false
		updateVisibility()
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Tab and not UserInputService:GetFocusedTextBox() then
			expanded = not expanded
			updateVisibility()
		end
	end)
	localPlayer:GetAttributeChangedSignal("BuildModeOpen"):Connect(updateVisibility)
	updateVisibility()

	local entries = {}
	local function updateOrder()
		local sorted = {}
		for player in entries do
			table.insert(sorted, player)
		end
		table.sort(sorted, function(a, b)
			local aMoney = entries[a].moneyValue or -math.huge
			local bMoney = entries[b].moneyValue or -math.huge
			if aMoney ~= bMoney then
				return aMoney > bMoney
			end
			return a.Name:lower() < b.Name:lower()
		end)
		for index, player in sorted do
			entries[player].row.LayoutOrder = index
		end
	end

	local function addPlayer(player)
		if entries[player] then
			return
		end
		local row = Instance.new("Frame")
		row.Name = tostring(player.UserId)
		row.Size = UDim2.new(1, 0, 0, 50)
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Parent = list
		local name, money, level, bestiary = columns(row, player.DisplayName, "—", "—", "—")
		local entry = { row = row, connections = {}, statsConnections = {} }
		entries[player] = entry
		local function refreshLevel()
			local value = tonumber(player:GetAttribute("Level"))
			level.Text = if value then tostring(value) else "—"
			name.TextColor3 = FishingRanks.forLevel(value or 0).Color
		end
		local function refreshBestiary()
			local value = tonumber(player:GetAttribute("BestiaryPercent"))
			bestiary.Text = if value then string.format("%d%%", math.clamp(math.floor(value + 0.5), 0, 100)) else "—"
		end
		local function bindStats()
			for _, connection in entry.statsConnections do
				connection:Disconnect()
			end
			table.clear(entry.statsConnections)
			local stats = player:FindFirstChild("leaderstats")
			local moneyValue = stats and stats:FindFirstChild("Money")
			local function refreshMoney()
				entry.moneyValue = if moneyValue and moneyValue:IsA("ValueBase") then tonumber(moneyValue.Value) else nil
				money.Text = formatMoney(entry.moneyValue)
				updateOrder()
			end
			if stats then
				table.insert(entry.statsConnections, stats.ChildAdded:Connect(bindStats))
				table.insert(entry.statsConnections, stats.ChildRemoved:Connect(bindStats))
			end
			if moneyValue and moneyValue:IsA("ValueBase") then
				table.insert(entry.statsConnections, moneyValue.Changed:Connect(refreshMoney))
			end
			refreshMoney()
		end
		table.insert(entry.connections, player:GetAttributeChangedSignal("Level"):Connect(refreshLevel))
		table.insert(entry.connections, player:GetAttributeChangedSignal("BestiaryPercent"):Connect(refreshBestiary))
		table.insert(
			entry.connections,
			player:GetPropertyChangedSignal("DisplayName"):Connect(function()
				name.Text = player.DisplayName
			end)
		)
		table.insert(
			entry.connections,
			player.ChildAdded:Connect(function(child)
				if child.Name == "leaderstats" then
					bindStats()
				end
			end)
		)
		table.insert(
			entry.connections,
			player.ChildRemoved:Connect(function(child)
				if child.Name == "leaderstats" then
					bindStats()
				end
			end)
		)
		bindStats()
		refreshLevel()
		refreshBestiary()
	end

	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(function(player)
		local entry = entries[player]
		if not entry then
			return
		end
		entries[player] = nil
		for _, connection in entry.connections do
			connection:Disconnect()
		end
		for _, connection in entry.statsConnections do
			connection:Disconnect()
		end
		entry.row:Destroy()
		updateOrder()
	end)
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end

	-- CoreGui can be unavailable during early startup.
	task.spawn(function()
		for _ = 1, 20 do
			local success = pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false)
			if success then
				return
			end
			task.wait(0.5)
		end
		warn("[Leaderboard] Could not disable the default player list")
	end)
end

return Leaderboard
