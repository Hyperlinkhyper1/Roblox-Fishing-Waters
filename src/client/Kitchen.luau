-- Recipe picker for the Supermarket path's kitchen stations. Pressing Cook at a
-- station lists what it can make from the fish you carry; the server checks the
-- fish, the station and the recipe again before anything cooks.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))

local Kitchen = {}
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
		Title = "Kitchen",
		Text = message,
		Duration = 5,
	})
end

function Kitchen.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Kitchen")
	local request = remotes:WaitForChild("Request") :: RemoteFunction
	local update = remotes:WaitForChild("Update") :: RemoteEvent

	local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), {
		Name = "KitchenRecipes",
		ResetOnSpawn = false,
		DisplayOrder = 28,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local overlay = make("TextButton", gui, {
		Name = "KitchenOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.45,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
	})
	local card = make("Frame", overlay, {
		Name = "RecipeCard",
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -28, 0, 380),
	})
	make("UISizeConstraint", card, { MaxSize = Vector2.new(520, 380) })
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
	local title = label(card, "Kitchen", {
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
		Name = "CloseKitchen",
		Position = UDim2.new(1, -52, 0, 12),
		Size = UDim2.fromOffset(38, 38),
		Text = "×",
		TextSize = 28,
		ZIndex = 3,
	})
	Theme.button(close, "Danger")
	local list = make("ScrollingFrame", card, {
		Name = "Recipes",
		Position = UDim2.fromOffset(18, 100),
		Size = UDim2.new(1, -36, 1, -116),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	})
	Theme.scroll(list)
	make("UIListLayout", list, { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) })

	local stationKey: string? = nil
	local activePrompt: ProximityPrompt? = nil
	local options = nil
	local pending = false
	local render
	local function hide()
		overlay.Visible = false
		stationKey, activePrompt, options = nil, nil, nil
	end
	local function cook(recipeId: string)
		if pending or not stationKey then
			return
		end
		pending = true
		render()
		local ok, result = pcall(request.InvokeServer, request, "Cook", stationKey, recipeId)
		pending = false
		if ok and type(result) == "table" then
			if result.Message ~= "" then
				notice(result.Message)
			end
			if result.Ok then
				hide()
				return
			end
			options = result.Options or options
		else
			notice("The kitchen couldn't be reached. Try again.")
		end
		render()
	end
	render = function()
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		if not options then
			title.Text = "Kitchen"
			status.Text = "Checking the station…"
			return
		end
		title.Text = options.Station
		status.Text = if options.Fish
			then string.format(
				"Carrying a %s %s ($%d) · Kitchen pass %d/%d dishes",
				options.Rarity or "",
				options.Fish,
				options.FishValue or 0,
				options.Pantry,
				options.PantryCapacity
			)
			else "Take a fish from your freezer (F) or boat, equip it and come back to cook."
		for index, recipe in options.Recipes do
			local row = make("Frame", list, {
				Name = recipe.Id .. "Recipe",
				LayoutOrder = index,
				Size = UDim2.new(1, -10, 0, 74),
			})
			Theme.panel(row, true, 8)
			label(row, recipe.Name, {
				Position = UDim2.fromOffset(12, 8),
				Size = UDim2.new(1, -170, 0, 22),
				TextSize = 16,
			})
			label(row, recipe.Problem or string.format("Sells for $%d · ready in %ds", recipe.Value or 0, recipe.Seconds), {
				Position = UDim2.fromOffset(12, 32),
				Size = UDim2.new(1, -170, 0, 36),
				TextSize = 12,
				Font = Enum.Font.Gotham,
				TextColor3 = if recipe.Problem then Theme.Colors.Muted else Theme.Colors.Green,
			})
			local enabled = recipe.Problem == nil and not pending
			local button = make("TextButton", row, {
				Name = "Cook" .. recipe.Id,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(140, 42),
				TextSize = 15,
				Text = if pending then "Please wait…" else recipe.MinRarity .. "+ · Cook",
				Active = enabled,
				AutoButtonColor = enabled,
			})
			Theme.button(button, if enabled then "Selected" else "Disabled")
			button.Activated:Connect(function()
				if enabled then
					cook(recipe.Id)
				end
			end)
		end
	end
	close.Activated:Connect(hide)
	overlay.Activated:Connect(hide)
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			hide()
		end
	end)
	player.CharacterRemoving:Connect(hide)
	update.OnClientEvent:Connect(function(kind, payload)
		if kind == "Notice" and type(payload) == "string" then
			notice(payload)
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		local key = prompt:GetAttribute("StationKey")
		if who ~= player or prompt.Name ~= "CookPrompt" or type(key) ~= "string" then
			return
		end
		stationKey, activePrompt, options = key, prompt, nil
		overlay.Visible = true
		render()
		task.spawn(function()
			local ok, result = pcall(request.InvokeServer, request, "Options", key)
			if stationKey ~= key then
				return
			end
			if ok and type(result) == "table" and result.Options then
				options = result.Options
			elseif ok and type(result) == "table" and result.Message ~= "" then
				notice(result.Message)
				hide()
				return
			end
			render()
		end)
	end)
	-- Walking away from the station closes the picker.
	task.spawn(function()
		while true do
			task.wait(0.5)
			if overlay.Visible then
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local anchor = activePrompt and activePrompt.Parent
				if not (root and anchor and anchor:IsA("BasePart") and (anchor.Position - root.Position).Magnitude <= 10) then
					hide()
				end
			end
		end
	end)
end

return Kitchen
