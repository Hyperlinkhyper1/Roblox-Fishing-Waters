-- Kitchen storage configuration GUI. Opened from the "Configure" prompt on a
-- placed kitchen storage counter. The owner picks how many fish of each rarity
-- (max 8 total) should wait on the ice bed for cooking; targets are sent to the
-- server which moves eligible fish from the freezer and storage racks onto the
-- prep table. Pure UI: the server re-validates every target.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Furniture = require(ReplicatedStorage.Shared.FurnitureCatalog)
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))

local KitchenStorage = {}
local started = false

local RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local CAPACITY = Furniture.KITCHEN_STORAGE_CAPACITY

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
		Title = "Kitchen Storage",
		Text = message,
		Duration = 5,
	})
end

function KitchenStorage.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("KitchenStorage")
	local request = remotes:WaitForChild("Request") :: RemoteFunction

	local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), {
		Name = "KitchenStorageGui",
		ResetOnSpawn = false,
		DisplayOrder = 28,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local overlay = make("TextButton", gui, {
		Name = "StorageOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.45,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
	})
	local card = make("Frame", overlay, {
		Name = "StorageCard",
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -28, 0, 420),
	})
	make("UISizeConstraint", card, { MaxSize = Vector2.new(520, 420) })
	Theme.window(card)

	local function label(parent: Instance, text: string, props: { [string]: any }): TextLabel
		local item = make("TextLabel", parent, {
			BackgroundTransparency = 1,
			Text = text,
			TextSize = 15,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		Theme.text(item, props.TextColor3)
		for key, value in props do
			item[key] = value
		end
		return item
	end

	local title = label(card, "Kitchen Storage", {
		Position = UDim2.fromOffset(22, 18),
		Size = UDim2.new(1, -90, 0, 30),
		TextSize = 22,
	})
	local status = label(card, "", {
		Position = UDim2.fromOffset(22, 52),
		Size = UDim2.new(1, -44, 0, 40),
		TextSize = 13,
		Font = Enum.Font.Gotham,
		TextColor3 = Theme.Colors.Muted,
	})
	local close = make("TextButton", card, {
		Name = "CloseStorage",
		Position = UDim2.new(1, -52, 0, 12),
		Size = UDim2.fromOffset(38, 38),
		Text = "×",
		TextSize = 28,
		ZIndex = 3,
	})
	Theme.button(close, "Danger")

	local list = make("ScrollingFrame", card, {
		Name = "Rarities",
		Position = UDim2.fromOffset(18, 100),
		Size = UDim2.new(1, -36, 1, -176),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	})
	Theme.scroll(list)
	make("UIListLayout", list, { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) })

	local totalBar = make("Frame", card, {
		Name = "TotalBar",
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -36, 0, 26),
		BackgroundTransparency = 1,
	})
	Theme.panel(totalBar, true, 8)
	local totalLabel = label(totalBar, "", {
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -140, 0, 18),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local setTargets = make("TextButton", card, {
		Name = "SetTargets",
		Position = UDim2.new(1, -152, 1, -34),
		Size = UDim2.fromOffset(140, 38),
		TextSize = 15,
		Text = "Set Targets",
	})
	Theme.button(setTargets)

	local rows = {} -- [rarity] = { frame, countLabel, minus, plus, availableLabel }
	local targets: { [string]: number } = {}
	local available: { [string]: number } = {}
	local pending = false

	local function render()
		local total = 0
		for _, rarity in RARITIES do
			total += targets[rarity] or 0
		end
		totalLabel.Text = string.format("Total: %d/%d fish", total, CAPACITY)
		local overCap = total > CAPACITY
		totalLabel.TextColor3 = if overCap then Color3.fromRGB(238, 107, 111) else Theme.Colors.Text

		for _, rarity in RARITIES do
			local row = rows[rarity]
			if not row then
				continue
			end
			local count = targets[rarity] or 0
			row.countLabel.Text = tostring(count)
			row.availableLabel.Text = string.format("Available: %d", available[rarity] or 0)
			row.minus.Active = count > 0 and not pending
			row.minus.AutoButtonColor = row.minus.Active
			Theme.button(row.minus, if row.minus.Active then "Normal" else "Disabled")
			row.plus.Active = count < (available[rarity] or 0) and not overCap and not pending
			row.plus.AutoButtonColor = row.plus.Active
			Theme.button(row.plus, if row.plus.Active then "Normal" else "Disabled")
		end

		status.Text = string.format(
			"Pick how many fish of each rarity should wait on the ice. %d/%d placed.",
			total,
			CAPACITY
		)
		setTargets.Active = not pending and total > 0 and total <= CAPACITY
		setTargets.AutoButtonColor = setTargets.Active
		Theme.button(setTargets, if setTargets.Active then "Selected" else "Disabled")
	end

	local function adjust(rarity: string, delta: number)
		if pending then
			return
		end
		local count = (targets[rarity] or 0) + delta
		count = math.clamp(count, 0, available[rarity] or 0)
		targets[rarity] = count
		render()
	end

	for index, rarity in RARITIES do
		local catalog = require(ReplicatedStorage.Shared.AnglerCatalog)
		local color = catalog.Rarities[rarity].Color
		local row = make("Frame", list, {
			Name = rarity .. "Row",
			LayoutOrder = index,
			Size = UDim2.new(1, -10, 0, 64),
		})
		Theme.panel(row, true, 8)

		local rarityLabel = label(row, rarity, {
			Position = UDim2.fromOffset(14, 10),
			Size = UDim2.new(0, 96, 0, 20),
			TextSize = 16,
			TextColor3 = color,
		})
		local availableLabel = label(row, "", {
			Position = UDim2.fromOffset(14, 34),
			Size = UDim2.new(0, 96, 0, 16),
			TextSize = 12,
			Font = Enum.Font.Gotham,
			TextColor3 = Theme.Colors.Muted,
			Name = rarity .. "Available",
		})

		local minus = make("TextButton", row, {
			Name = "Minus" .. rarity,
			Position = UDim2.new(0.5, -74, 0.5, 0),
			Size = UDim2.fromOffset(32, 32),
			Text = "−",
			TextSize = 20,
		})
		Theme.button(minus)
		local countLabel = make("TextLabel", row, {
			Name = "Count" .. rarity,
			Position = UDim2.new(0.5, -16, 0.5, 0),
			Size = UDim2.fromOffset(32, 32),
			Text = "0",
			TextSize = 18,
			Font = Enum.Font.GothamBold,
		})
		Theme.text(countLabel)
		countLabel.BackgroundTransparency = 1
		countLabel.BorderSizePixel = 0
		local plus = make("TextButton", row, {
			Name = "Plus" .. rarity,
			Position = UDim2.new(0.5, 42, 0.5, 0),
			Size = UDim2.fromOffset(32, 32),
			Text = "+",
			TextSize = 20,
		})
		Theme.button(plus)

		minus.Activated:Connect(function()
			adjust(rarity, -1)
		end)
		plus.Activated:Connect(function()
			adjust(rarity, 1)
		end)

		rows[rarity] = {
			frame = row,
			countLabel = countLabel,
			availableLabel = availableLabel,
			minus = minus,
			plus = plus,
		}
	end

	local function fetch()
		local ok, result = pcall(request.InvokeServer, request, "Get")
		if not ok or type(result) ~= "table" or not result.Ok then
			notice("Couldn't load kitchen storage. Try again.")
			return
		end
		available = result.Available or {}
		targets = {}
		for _, rarity in RARITIES do
			targets[rarity] = (result.Targets or {})[rarity] or 0
		end
		render()
	end

	local function setTargetsPressed()
		if pending then
			return
		end
		local total = 0
		for _, c in pairs(targets) do
			total += c
		end
		if total == 0 then
			notice("Pick at least one fish.")
			return
		end
		if total > CAPACITY then
			notice("Kitchen storage can hold at most " .. CAPACITY .. " fish.")
			return
		end
		pending = true
		render()
		local ok, result = pcall(request.InvokeServer, request, "SetTargets", targets)
		pending = false
		if ok and type(result) == "table" then
			if result.Message ~= "" then
				notice(result.Message)
			end
			if result.Ok then
				hide()
				return
			end
		else
			notice("The kitchen storage couldn't be reached. Try again.")
		end
		render()
	end

	setTargets.Activated:Connect(setTargetsPressed)

	local function hide()
		overlay.Visible = false
	end
	close.Activated:Connect(hide)
	overlay.Activated:Connect(hide)
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			hide()
		end
	end)
	player.CharacterRemoving:Connect(hide)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player or prompt.Name ~= "KitchenStorageGuiPrompt" then
			return
		end
		fetch()
		overlay.Visible = true
		render()
	end)
end

return KitchenStorage
