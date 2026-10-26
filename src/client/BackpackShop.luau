local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Backpacks = require(ReplicatedStorage.Shared.BackpackCatalog)
local Cargo = require(ReplicatedStorage.Shared.Cargo)
local Models = require(ReplicatedStorage.Shared.BackpackModels)
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))
local Shop = {}
local started = false
local function make(class, parent, properties)
	local item = Instance.new(class)
	for key, value in properties do
		item[key] = value
	end
	item.Parent = parent
	return item
end

function Shop.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local request = ReplicatedStorage:WaitForChild("BackpackShop")
	local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), {
		Name = "BackpackShop",
		ResetOnSpawn = false,
		DisplayOrder = 29,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local overlay = make("TextButton", gui, {
		Size = UDim2.fromScale(1, 1),
		Text = "",
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.35,
		Visible = false,
		AutoButtonColor = false,
		Modal = true,
	})
	local card = make("Frame", overlay, {
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(540, 580),
	})
	Theme.window(card)
	local scale = make("UIScale", card, {})
	local function label(parent, value, position, size, textSize)
		local item = make("TextLabel", parent, {
			BackgroundTransparency = 1,
			Text = value,
			Position = position,
			Size = size,
			TextSize = textSize,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		Theme.text(item)
		return item
	end
	label(card, "PLAZA BACKPACK STORE", UDim2.fromOffset(20, 16), UDim2.fromOffset(440, 30), 24)
	local status = label(card, "", UDim2.fromOffset(20, 52), UDim2.fromOffset(490, 44), 14)
	label(
		card,
		"Fish use the same shaped tiles as boat cargo. Open Backpack [C], pick up your hand fish, rotate and pack it.",
		UDim2.fromOffset(20, 98),
		UDim2.fromOffset(500, 45),
		14
	)
	local close = make(
		"TextButton",
		card,
		{ Text = "×", TextSize = 24, Position = UDim2.new(1, -48, 0, 12), Size = UDim2.fromOffset(36, 36) }
	)
	Theme.button(close, "Danger")
	local list = make("ScrollingFrame", card, {
		Position = UDim2.fromOffset(18, 154),
		Size = UDim2.new(1, -36, 1, -174),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 5,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	})
	make("UIListLayout", list, { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })
	local rows = {}
	local state = nil
	local pending = false
	local message = ""
	local function render()
		local current = if state then state.BackpackId else "Starter"
		status.Text = if message ~= ""
			then message
			elseif state then string.format(
				"Wallet: $%d · Equipped: %s",
				state.Cash,
				(Backpacks.Items[current] or Backpacks.Items.Starter).Name
			)
			else "Loading your backpack…"
		for id, row in rows do
			local owned = Backpacks.rank(id) <= Backpacks.rank(current)
			local price = Backpacks.Items[id].Price
			row.Active = state ~= nil and not pending and not owned and state.Cash >= price
			row.Text = if pending
				then "Please wait"
				elseif id == current then "Equipped"
				elseif owned then "Owned"
				elseif state and state.Cash < price then "Need $" .. price
				else "Buy · $" .. price
			Theme.button(row, if row.Active then "Normal" else "Disabled")
		end
	end
	local function invoke(action, id)
		if pending then
			return
		end
		pending, message = true, ""
		render()
		task.spawn(function()
			local ok, result = pcall(request.InvokeServer, request, action, id)
			pending = false
			if ok and type(result) == "table" then
				state = result.State or state
				message = result.Message or ""
			else
				message = "Could not reach the backpack store. Try again."
			end
			render()
		end)
	end
	for index, id in Backpacks.Order do
		local item = Backpacks.Items[id]
		local row = make("Frame", list, { Name = id, LayoutOrder = index, Size = UDim2.new(1, -8, 0, 152) })
		Theme.glassPanel(row, true)
		local view = make("ViewportFrame", row, {
			Name = "ModelPreview",
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.fromOffset(116, 132),
			BackgroundColor3 = Color3.fromRGB(25, 34, 35),
			BorderSizePixel = 0,
		})
		Models.show(view, id)
		label(row, item.Name, UDim2.fromOffset(142, 12), UDim2.new(1, -152, 0, 25), 19)
		label(
			row,
			string.format("%d tiles · %d × %d grid", Cargo.capacity(item.Hold), #item.Hold[1], #item.Hold),
			UDim2.fromOffset(142, 40),
			UDim2.new(1, -152, 0, 20),
			14
		)
		label(row, item.Description, UDim2.fromOffset(142, 65), UDim2.new(1, -156, 0, 34), 13)
		local buy = make("TextButton", row, {
			Name = "Buy",
			Position = UDim2.fromOffset(142, 108),
			Size = UDim2.new(1, -158, 0, 32),
			Text = "",
			TextSize = 15,
		})
		Theme.button(buy)
		rows[id] = buy
		buy.Activated:Connect(function()
			if buy.Active and not pending then
				invoke("Buy", id)
			end
		end)
	end
	close.Activated:Connect(function()
		overlay.Visible = false
	end)
	overlay.Activated:Connect(function()
		overlay.Visible = false
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then
			overlay.Visible = false
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if prompt.Name ~= "BrowseBackpacksPrompt" or (who and who ~= player) then
			return
		end
		overlay.Visible = true
		invoke("Get")
	end)
	RunService.RenderStepped:Connect(function()
		if overlay.Visible and workspace.CurrentCamera then
			local viewport = workspace.CurrentCamera.ViewportSize
			scale.Scale = math.min(1, (viewport.X - 24) / 540, (viewport.Y - 32) / 580)
		end
	end)
	render()
end
return Shop
