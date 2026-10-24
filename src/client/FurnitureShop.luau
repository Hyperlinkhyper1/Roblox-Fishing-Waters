-- Harbour Home's catalogue, opened from the sales counter on the plaza. Bought
-- furniture waits in your stock until you place it from build mode at home.
-- Prices and stock come from the server; this window only displays them.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Furniture = require(ReplicatedStorage.Shared.FurnitureCatalog)
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))

local FurnitureShop = {}
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
		Title = "Harbour Home",
		Text = message,
		Duration = 5,
	})
end

function FurnitureShop.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Furniture")
	local request = remotes:WaitForChild("Request") :: RemoteFunction
	local update = remotes:WaitForChild("Update") :: RemoteEvent

	local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), {
		Name = "FurnitureShop",
		ResetOnSpawn = false,
		DisplayOrder = 28,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local overlay = make("TextButton", gui, {
		Name = "ShopOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.4,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
	})
	local card = make("Frame", overlay, {
		Name = "FurnitureCatalogue",
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -28, 0, 470),
	})
	make("UISizeConstraint", card, { MaxSize = Vector2.new(560, 470) })
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
	label(card, "PLAZA · HARBOUR HOME", {
		Position = UDim2.fromOffset(22, 18),
		Size = UDim2.new(1, -90, 0, 18),
		TextSize = 12,
		TextColor3 = Theme.Colors.Muted,
	})
	label(card, "Furniture for your fish shop", {
		Position = UDim2.fromOffset(22, 38),
		Size = UDim2.new(1, -90, 0, 30),
		TextSize = 22,
	})
	local status = label(card, "", {
		Position = UDim2.fromOffset(22, 72),
		Size = UDim2.new(1, -44, 0, 36),
		TextSize = 13,
		TextColor3 = Theme.Colors.Muted,
		Font = Enum.Font.Gotham,
	})
	local close = make("TextButton", card, {
		Name = "CloseShop",
		Position = UDim2.new(1, -52, 0, 12),
		Size = UDim2.fromOffset(38, 38),
		Text = "×",
		TextSize = 28,
		ZIndex = 3,
	})
	Theme.button(close, "Danger")

	local rows = {}
	local state = nil
	local pending = false
	local function render()
		local cash = if state then state.Cash else 0
		status.Text = if not state
			then "Loading your shop…"
			else string.format(
				"Cash $%d · Freezers hold %d fish · Racks hold %d fish\nPress B (or Build) at home to place what you buy.",
				cash,
				state.FreezerCapacity,
				state.StorageCapacity
			)
		for _, id in Furniture.Order do
			local item, row = Furniture.Items[id], rows[id]
			local owned = if state then state.Stock[id] or 0 else 0
			local placed = if state then Furniture.count(state.Placed, id) else 0
			row.detail.Text = string.format(
				"%s\nOnly in the %s · %d placed, %d in stock (max %d placed)",
				item.Description,
				Furniture.RoomNames[item.Room],
				placed,
				owned,
				item.MaxPlaced
			)
			local enabled = state ~= nil and not pending and cash >= item.Price
			row.buy.Text = if pending then "Please wait…" else "Buy · $" .. item.Price
			row.buy.Active, row.buy.AutoButtonColor = enabled, enabled
			Theme.button(row.buy, if enabled then "Selected" else "Disabled")
		end
	end
	for index, id in Furniture.Order do
		local item = Furniture.Items[id]
		local row = make("Frame", card, {
			Name = id .. "Row",
			Position = UDim2.fromOffset(18, 118 + (index - 1) * 112),
			Size = UDim2.new(1, -36, 0, 102),
		})
		Theme.panel(row, true, 8)
		label(row, item.Name, {
			Position = UDim2.fromOffset(14, 10),
			Size = UDim2.new(1, -170, 0, 22),
			TextSize = 17,
		})
		local detail = label(row, "", {
			Position = UDim2.fromOffset(14, 36),
			Size = UDim2.new(1, -170, 0, 60),
			TextSize = 12,
			Font = Enum.Font.Gotham,
			TextColor3 = Theme.Colors.Muted,
		})
		local buy = make("TextButton", row, {
			Name = "Buy" .. id,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(140, 44),
			TextSize = 15,
		})
		buy.Activated:Connect(function()
			if pending or not buy.Active then
				return
			end
			pending = true
			render()
			local ok, result = pcall(request.InvokeServer, request, "Buy", id)
			pending = false
			if ok and type(result) == "table" then
				state = result.State or state
				if result.Message ~= "" then
					notice(result.Message)
				end
			else
				notice("The shop couldn't be reached. Try again.")
			end
			render()
		end)
		rows[id] = { detail = detail, buy = buy }
	end

	local function refresh()
		local ok, result = pcall(request.InvokeServer, request, "Get")
		if ok and type(result) == "table" and result.State then
			state = result.State
		end
		render()
	end
	local function hide()
		overlay.Visible = false
	end
	close.Activated:Connect(hide)
	overlay.Activated:Connect(hide)
	update.OnClientEvent:Connect(function(kind, payload)
		if kind == "State" and type(payload) == "table" then
			state = payload
			render()
		elseif kind == "Notice" and type(payload) == "string" then
			notice(payload)
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who == player and prompt.Name == "BrowseFurniturePrompt" then
			overlay.Visible = true
			render()
			task.spawn(refresh)
		end
	end)
	-- Walking away closes the catalogue.
	task.spawn(function()
		while true do
			task.wait(0.5)
			if overlay.Visible then
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local near = false
				for _, top in game:GetService("CollectionService"):GetTagged("FurnitureShop") do
					if root and top:IsA("BasePart") and (top.Position - root.Position).Magnitude < 20 then
						near = true
					end
				end
				if not near then
					hide()
				end
			end
		end
	end)
	render()
end

return FurnitureShop
