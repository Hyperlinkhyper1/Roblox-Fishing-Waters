local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))
local Islands = {}
local started = false

local function make(class, parent, properties)
	local item = Instance.new(class)
	for key, value in properties do item[key] = value end
	item.Parent = parent
	return item
end

local function notice(message)
	pcall(StarterGui.SetCore, StarterGui, "SendNotification", { Title = "Company Islands", Text = message, Duration = 6 })
end

function Islands.start()
	if started then return end
	started = true
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("CompanyIslands")
	local request = remotes:WaitForChild("Request") :: RemoteFunction
	local update = remotes:WaitForChild("Update") :: RemoteEvent
	local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), { Name = "CompanyIslandPurchase", ResetOnSpawn = false, DisplayOrder = 30 })
	local overlay = make("TextButton", gui, { Size = UDim2.fromScale(1, 1), Text = "", BackgroundColor3 = Color3.new(), BackgroundTransparency = 0.4, Visible = false, AutoButtonColor = false })
	local card = make("Frame", overlay, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.85), Active = true })
	make("UISizeConstraint", card, { MaxSize = Vector2.new(530, 360) })
	Theme.window(card)
	local function label(name, text, y, height, size, color)
		local result = make("TextLabel", card, { Name = name, Text = text, BackgroundTransparency = 1, Position = UDim2.new(0, 22, y, 0), Size = UDim2.new(1, -44, height, 0), TextSize = size, TextWrapped = true, Font = Enum.Font.GothamMedium })
		Theme.text(result, color)
		return result
	end
	local heading = label("IslandName", "Company island", 0.05, 0.12, 27)
	label("Description", "A private fishing company, above the water.", 0.19, 0.08, 15, Theme.Colors.Muted)
	label("Includes", "LOWER QUAY\nLarge dock with two long piers and boat launch\n\nUPPER VILLAGE\nStorage house · kitchen house · company office", 0.3, 0.35, 16)
	local status = label("PurchaseStatus", "", 0.66, 0.12, 14, Theme.Colors.Muted)
	local buy = make("TextButton", card, { Name = "ConfirmPurchase", Position = UDim2.new(0.36, 0, 0.82, 0), Size = UDim2.new(0.59, 0, 0.12, 0), Text = "Buy island — $50,000", TextSize = 16 })
	local cancel = make("TextButton", card, { Position = UDim2.new(0.05, 0, 0.82, 0), Size = UDim2.new(0.26, 0, 0.12, 0), Text = "Close", TextSize = 16 })
	Theme.button(cancel)
	local selected, busy, generation = nil, false, 0
	local function close()
		generation += 1
		overlay.Visible = false
		player:SetAttribute("CompanyIslandScreenOpen", false)
		if GuiService.SelectedObject == buy or GuiService.SelectedObject == cancel then GuiService.SelectedObject = nil end
	end
	local function show(island)
		if player:GetAttribute("PlayerMenuOpen") or player:GetAttribute("DrydockScreenOpen") then return end
		generation += 1
		selected = island
		heading.Text = island.Name
		status.Text = island.Problem or "Includes 48 storage slots and two prep benches."
		buy.Active = island.Problem == nil and not busy
		Theme.button(buy, if buy.Active then nil else "Disabled")
		overlay.Visible = true
		player:SetAttribute("CompanyIslandScreenOpen", true)
		if UserInputService.GamepadEnabled then GuiService.SelectedObject = if buy.Active then buy else cancel end
	end
	buy.Activated:Connect(function()
		if busy or not selected or not buy.Active then return end
		busy, buy.Active = true, false
		Theme.button(buy, "Disabled")
		status.Text = "Saving your island purchase…"
		local token = generation
		local ok, result = pcall(request.InvokeServer, request, "Buy", selected.Id)
		busy = false
		local message = if ok and result then result.Message else "The purchase could not be completed. Please try again."
		if ok and result and result.Ok then
			close()
			notice(message)
		elseif generation == token and overlay.Visible then
			status.Text = message
			buy.Active = true
			Theme.button(buy)
		end
	end)
	cancel.Activated:Connect(close)
	overlay.Activated:Connect(close)
	player.CharacterRemoving:Connect(close)
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then close() end
	end)
	update.OnClientEvent:Connect(function(kind, value)
		if kind == "Inspect" then show(value) elseif kind == "Notice" then notice(value) end
	end)
end

return Islands
