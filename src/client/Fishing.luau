-- The server owns purchases, inventory and equip state; this module only presents them.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))

local Fishing = {}
local started = false

function Fishing.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Fishing")
	local request = remotes:WaitForChild("Request") :: RemoteEvent
	local feedback = remotes:WaitForChild("Feedback") :: RemoteEvent
	local cream = Theme.Colors.Text
	local muted = Theme.Colors.Muted
	local gold = Theme.Colors.Blue
	local navy = Theme.Colors.Window
	local disabled = Theme.Colors.Panel
	local gui = Instance.new("ScreenGui")
	gui.Name = "Fishing"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 22
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	local function corner(parent: GuiObject, radius: number)
		Theme.corner(parent, math.min(radius, 10))
	end
	local function label(parent: Instance, text: string, y: number, height: number, size: number, color: Color3)
		local item = Instance.new("TextLabel")
		item.BackgroundTransparency = 1
		item.Position = UDim2.fromOffset(26, y)
		item.Size = UDim2.new(1, -52, 0, height)
		item.Font = Enum.Font.Gotham
		item.Text, item.TextSize, item.TextColor3 = text, size, color
		item.TextWrapped = true
		item.TextXAlignment = Enum.TextXAlignment.Left
		Theme.text(item, color)
		item.Parent = parent
		return item
	end
	local function button(parent: Instance, name: string)
		local item = Instance.new("TextButton")
		item.Name = name
		item.BackgroundColor3 = gold
		item.TextColor3 = navy
		item.Font = Enum.Font.GothamBold
		item.TextSize = 16
		item.TextWrapped = true
		item.Parent = parent
		Theme.button(item, "Selected")
		return item
	end

	local equipment = button(gui, "EquipFishingRod")
	equipment.AnchorPoint = Vector2.new(0, 1)
	equipment.Position = UDim2.new(0, 24, 1, -122)
	equipment.Size = UDim2.fromOffset(190, 48)
	equipment.TextSize = 14
	equipment.Visible = false

	local overlay = Instance.new("TextButton")
	overlay.Name = "ShopOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.4
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Visible = false
	overlay.Parent = gui
	local card = Instance.new("Frame")
	card.Name = "FishingRodShop"
	card.Active = true
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(420, 402)
	card.BackgroundColor3 = navy
	card.Parent = overlay
	Theme.window(card)
	local scale = Instance.new("UIScale")
	scale.Parent = card
	label(card, "PLAZA · TACKLE SHOP", 23, 22, 12, cream)
	local title = label(card, "Starter fishing rod", 64, 38, 27, cream)
	title.Font = Enum.Font.GothamBold
	label(
		card,
		"A flexible rod for your first day on the water. Collect it here, then equip it anywhere.",
		114,
		58,
		15,
		muted
	)
	local price = label(card, "FREE · $0", 188, 34, 27, gold)
	Theme.text(price, Theme.Colors.Green)
	local status = label(card, "Loading your inventory…", 238, 60, 14, muted)
	local action = button(card, "ClaimStarterRod")
	action.Position = UDim2.fromOffset(26, 322)
	action.Size = UDim2.new(1, -52, 0, 54)
	local close = Instance.new("TextButton")
	close.Name = "CloseShop"
	close.Position = UDim2.new(1, -49, 0, 13)
	close.Size = UDim2.fromOffset(38, 38)
	close.BackgroundTransparency = 1
	close.Text = "×"
	close.Font = Enum.Font.Gotham
	close.TextColor3 = cream
	close.TextSize = 28
	close.ZIndex = 3
	close.Parent = card
	Theme.button(close, "Danger")

	local toast = Instance.new("TextLabel")
	toast.Name = "FishingNotice"
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -92)
	toast.Size = UDim2.new(0.86, 0, 0, 64)
	toast.BackgroundColor3 = navy
	toast.BackgroundTransparency = 0.06
	toast.TextColor3 = cream
	toast.Font = Enum.Font.GothamMedium
	toast.TextSize = 15
	toast.TextWrapped = true
	toast.Visible = false
	toast.ZIndex = 5
	toast.Parent = gui
	Theme.panel(toast, false, 4)
	Theme.text(toast)
	local toastBounds = Instance.new("UISizeConstraint")
	toastBounds.MaxSize = Vector2.new(560, 64)
	toastBounds.Parent = toast
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
	padding.Parent = toast
	local noticeId = 0
	local function notice(message: string)
		noticeId += 1
		local current = noticeId
		toast.Text, toast.Visible = message, true
		task.delay(6, function()
			if noticeId == current then
				toast.Visible = false
			end
		end)
	end

	local function alive(): boolean
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		return humanoid ~= nil and humanoid.Health > 0
	end
	local function insideShop(): boolean
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return false
		end
		for _, shop in CollectionService:GetTagged("FishingRodShop") do
			local interiorFrame = shop:GetAttribute("InteriorFrame")
			local interiorSize = shop:GetAttribute("InteriorSize")
			if typeof(interiorFrame) == "CFrame" and typeof(interiorSize) == "Vector3" then
				local localPosition = interiorFrame:PointToObjectSpace(root.Position)
				if
					math.abs(localPosition.X) <= interiorSize.X / 2
					and math.abs(localPosition.Y) <= interiorSize.Y / 2
					and math.abs(localPosition.Z) <= interiorSize.Z / 2
				then
					return true
				end
			end
		end
		return false
	end

	local pending: string? = nil
	local pendingId = 0
	local lastRequest = -math.huge
	local function refresh()
		local owned = player:GetAttribute("OwnsStarterRod") == true
		local equipped = player:GetAttribute("RodEquipped") == true
		local dataStatus = player:GetAttribute("BoatDataStatus")
		local ready = dataStatus == "Ready"
		if
			(pending == "PurchaseRod" and owned)
			or (pending == "EquipRod" and equipped)
			or (pending == "UnequipRod" and not equipped)
		then
			pending = nil
		end
		local enabled = ready and alive() and pending == nil
		equipment.Visible = owned and not overlay.Visible and not player:GetAttribute("PlayerMenuOpen")
		equipment.Active, equipment.Selectable, equipment.AutoButtonColor = enabled, enabled, enabled
		Theme.button(equipment, if enabled then "Normal" else "Disabled")
		equipment.Text = if pending
			then "Please wait…"
			elseif equipped then "Stow starter rod"
			else "Equip starter rod"
		action.Active, action.Selectable, action.AutoButtonColor = enabled, enabled, enabled
		Theme.button(action, if enabled then "Selected" else "Disabled")
		action.Text = if pending
			then "Please wait…"
			elseif not owned then "Get starter rod · FREE"
			elseif equipped then "Stow fishing rod"
			else "Equip fishing rod"
		if dataStatus == "Unavailable" then
			status.Text = "Your inventory could not load. Rejoin to try again."
		elseif not ready then
			status.Text = "Loading your inventory…"
		elseif not alive() then
			status.Text = "Respawn to collect or equip your rod."
		elseif pending then
			status.Text = "Waiting for your inventory to update…"
		elseif equipped then
			status.Text = "Equipped. Your rod flexes as you move. Use the equipment button to stow it."
		elseif owned then
			status.Text = "You own this rod. Equip it here or use the equipment button whenever you need it."
		else
			status.Text = "Your first rod is on the house. It will equip automatically when you collect it."
		end
		if ready and player:GetAttribute("WalletSessionOnly") == true then
			status.Text ..= " Studio test: progress resets when the server stops."
		end
	end
	local function send(actionName: string)
		if
			pending
			or os.clock() - lastRequest < 0.55
			or player:GetAttribute("BoatDataStatus") ~= "Ready"
			or not alive()
		then
			return
		end
		lastRequest = os.clock()
		pending, pendingId = actionName, pendingId + 1
		local current = pendingId
		refresh()
		request:FireServer(actionName)
		task.delay(8, function()
			if pendingId == current and pending then
				pending = nil
				refresh()
				notice("Your rod request took too long. Please try again.")
			end
		end)
	end
	local function toggleRod()
		if player:GetAttribute("OwnsStarterRod") == true then
			send(if player:GetAttribute("RodEquipped") == true then "UnequipRod" else "EquipRod")
		end
	end
	local function closeShop()
		overlay.Visible = false
		refresh()
	end
	player:GetAttributeChangedSignal("PlayerMenuOpen"):Connect(function()
		if player:GetAttribute("PlayerMenuOpen") then
			closeShop()
		end
	end)
	close.Activated:Connect(closeShop)
	overlay.Activated:Connect(closeShop)
	equipment.Activated:Connect(toggleRod)
	action.Activated:Connect(function()
		if not overlay.Visible or not insideShop() then
			closeShop()
			return
		end
		if player:GetAttribute("OwnsStarterRod") == true then
			toggleRod()
		else
			send("PurchaseRod")
		end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			closeShop()
		end
	end)
	for _, attribute in { "BoatDataStatus", "OwnsStarterRod", "RodEquipped", "WalletSessionOnly", "PlayerMenuOpen" } do
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	player.CharacterRemoving:Connect(closeShop)
	local function characterAdded(character: Model)
		closeShop()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(closeShop)
			refresh()
		end
	end
	player.CharacterAdded:Connect(characterAdded)
	if player.Character then
		task.spawn(characterAdded, player.Character)
	end
	feedback.OnClientEvent:Connect(function(kind, message)
		if kind == "OpenShop" and alive() and insideShop() and not player:GetAttribute("PlayerMenuOpen") then
			overlay.Visible = true
			refresh()
		elseif kind == "Notice" and type(message) == "string" then
			notice(message)
			-- Let replicated attributes arrive before releasing the pending button.
			local current = pendingId
			task.delay(0.2, function()
				if current == pendingId then
					pending = nil
					refresh()
				end
			end)
		end
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then
			return
		end
		elapsed = 0
		local camera = workspace.CurrentCamera
		if camera then
			scale.Scale =
				math.max(0.25, math.min(1, (camera.ViewportSize.X - 28) / 420, (camera.ViewportSize.Y - 64) / 402))
		end
		-- Leave room for Roblox's movement thumbstick and the central backpack bar.
		equipment.Position = UDim2.new(0, 18, 1, if UserInputService.TouchEnabled then -210 else -90)
		if overlay.Visible and (not alive() or not insideShop()) then
			closeShop()
		end
	end)
	refresh()
end

return Fishing
