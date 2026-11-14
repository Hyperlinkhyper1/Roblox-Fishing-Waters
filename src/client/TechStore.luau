-- Micro Harbour: hold E at physical product displays to buy/install; information terminals
-- also compare the catalog and reinstall owned parts. The detailed showroom exists only
-- while the local player is inside (TechStoreInterior).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TechCatalog = require(ReplicatedStorage.Shared.TechCatalog)
local Interior = require(script.Parent.TechStoreInterior)
local ProductPrompts = require(ReplicatedStorage.Shared.TechStorePrompts)
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))

local TechStore = {}
local started = false

local WIDTH, HEIGHT = 620, 600
local RED = Color3.fromRGB(204, 22, 34)
local NAVY = Color3.fromRGB(20, 36, 82)
local COMPONENT_SLOTS = { "CPU", "Motherboard", "RAM", "GPU", "Storage", "Cooling", "PSU", "Case" }
local SLOT_TABS = { CPU = "CPU", Motherboard = "BOARD", RAM = "RAM", GPU = "GPU", Storage = "DRIVES", Cooling = "COOLING", PSU = "POWER", Case = "CASE" }

local function make(class: string, parent: Instance?, properties: { [string]: any }): any
	local item = Instance.new(class)
	for key, value in properties do
		item[key] = value
	end
	item.Parent = parent
	return item
end

local function money(amount: number): string
	local text = tostring(math.floor(amount))
	while true do
		local nextText, count = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
		text = nextText
		if count == 0 then
			break
		end
	end
	return "$" .. text
end

function TechStore.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local request = ReplicatedStorage:WaitForChild("TechStore", 60)
	if not request then
		warn("[TechStore] The store remote never arrived")
		return
	end
	local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), {
		Name = "TechStore",
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
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
	})
	Theme.window(card)
	local scale = make("UIScale", card, {})
	local function label(parent: Instance, value: string, position: UDim2, size: UDim2, textSize: number): TextLabel
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

	-- Red store banner across the top, like the sign over the doors.
	local banner = make("Frame", card, {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -24, 0, 54),
		BackgroundColor3 = RED,
		BorderSizePixel = 0,
	})
	Theme.corner(banner, 8)
	local title = label(banner, TechCatalog.STORE_NAME, UDim2.fromOffset(16, 4), UDim2.new(1, -80, 0, 30), 26)
	title.Font = Enum.Font.GothamBlack
	local strap = label(banner, "COMPUTERS · PARTS · MONITORS · LICENSES", UDim2.fromOffset(16, 31), UDim2.new(1, -80, 0, 18), 12)
	strap.TextColor3 = Color3.fromRGB(255, 220, 220)
	local close = make("TextButton", banner, {
		Text = "×",
		TextSize = 24,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -9, 0.5, 0),
		Size = UDim2.fromOffset(36, 36),
	})
	Theme.button(close, "Danger")

	local status = label(card, "", UDim2.fromOffset(20, 72), UDim2.new(1, -40, 0, 36), 14)

	local tabs: { [string]: TextButton } = {}
	local slotTabs: { [string]: TextButton } = {}
	local department = "Components"
	local slotFilter = "CPU"
	for index, name in TechCatalog.Departments do
		local tab = make("TextButton", card, {
			Text = string.upper(name),
			TextSize = 15,
			Position = UDim2.new((index - 1) / 3, if index == 1 then 18 else 6, 0, 112),
			Size = UDim2.new(1 / 3, if index == 2 then -12 else -24, 0, 34),
		})
		tabs[name] = tab
	end
	local slotBar = make("Frame", card, {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 152),
		Size = UDim2.new(1, -36, 0, 28),
	})
	make("UIListLayout", slotBar, {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	for index, slot in COMPONENT_SLOTS do
		slotTabs[slot] = make("TextButton", slotBar, {
			Text = SLOT_TABS[slot],
			TextSize = 11,
			LayoutOrder = index,
			Size = UDim2.new(1 / #COMPONENT_SLOTS, -5, 1, 0),
		})
	end

	local list = make("ScrollingFrame", card, {
		Position = UDim2.fromOffset(18, 188),
		Size = UDim2.new(1, -36, 1, -206),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 5,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	})
	make("UIListLayout", list, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })

	local state: any = nil
	local pending = false
	local message = ""
	local productPrompts = {}
	local inStore = false
	local visit = 0
	local toastVersion = 0
	local toast = label(gui, "", UDim2.fromScale(0.5, 0.87), UDim2.new(0.86, 0, 0, 64), 17)
	toast.AnchorPoint = Vector2.new(0.5, 0.5)
	toast.TextXAlignment = Enum.TextXAlignment.Center
	toast.BackgroundColor3, toast.BackgroundTransparency = NAVY, 0.08
	toast.Visible = false
	Theme.corner(toast, 8)
	make("UISizeConstraint", toast, { MaxSize = Vector2.new(700, 80) })
	local function refreshProducts()
		for prompt, entry in productPrompts do
			if not prompt.Parent then productPrompts[prompt] = nil; continue end
			ProductPrompts.update(prompt, entry, state, pending, money)
		end
	end

	-- A small picture of the screen a monitor gives the office PC.
	local function screenPreview(parent: Instance, screen)
		local view = make("Frame", parent, {
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.fromOffset(112, 74),
			BackgroundColor3 = screen.Screen,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		})
		make("UIStroke", view, { Color = Color3.fromRGB(20, 20, 22), Thickness = 4 })
		local bar = make("Frame", view, {
			Size = UDim2.new(1, 0, 0, 14),
			BackgroundColor3 = screen.Bright,
			BorderSizePixel = 0,
		})
		make("TextLabel", bar, {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -6, 1, 0),
			Position = UDim2.fromOffset(4, 0),
			Text = "HARBOUR-OS",
			TextSize = 10,
			Font = screen.Title,
			TextColor3 = screen.Screen,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		make("TextLabel", view, {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(6, 18),
			Size = UDim2.new(1, -12, 1, -22),
			Text = "STOCKS  ▲2.4%\nBRANCHES\nREADY_",
			TextSize = 11,
			Font = screen.Body,
			TextColor3 = screen.Bright,
			TextStrokeColor3 = screen.Bright,
			TextStrokeTransparency = screen.Bloom,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		local accent = make("Frame", view, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -6, 1, -6),
			Size = UDim2.fromOffset(24, 10),
			BackgroundColor3 = screen.Hot,
			BorderSizePixel = 0,
		})
		accent.BackgroundTransparency = 0.1
		if screen.Scanlines then
			for y = 0, 72, 3 do
				make("Frame", view, {
					Position = UDim2.fromOffset(0, y),
					Size = UDim2.new(1, 0, 0, 1),
					BackgroundColor3 = Color3.new(),
					BackgroundTransparency = screen.Scanlines,
					BorderSizePixel = 0,
				})
			end
		end
	end

	-- A swatch of colour, or a slot initial, for parts.
	local function partBadge(parent: Instance, item)
		local swatch = make("Frame", parent, {
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.fromOffset(74, 74),
			BackgroundColor3 = if item.Look then item.Look.Body elseif item.Light then item.Light:Lerp(Color3.new(), 0.55) else NAVY,
			BorderSizePixel = 0,
		})
		Theme.corner(swatch, 8)
		local text = label(swatch, SLOT_TABS[item.Slot] or "", UDim2.new(), UDim2.fromScale(1, 1), 13)
		text.TextXAlignment = Enum.TextXAlignment.Center
		if item.Light then
			make("Frame", swatch, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -8),
				Size = UDim2.new(1, -20, 0, 5),
				BackgroundColor3 = item.Light,
				BorderSizePixel = 0,
			})
		end
	end

	local function invoke(action: string, kind: string?, id: string?)
		if pending then
			return
		end
		pending, message = true, ""
		refreshProducts()
		TechStore.render()
		local requestVisit = visit
		task.spawn(function()
			local ok, result = pcall(request.InvokeServer, request, action, kind, id)
			pending = false
			if requestVisit ~= visit then
				refreshProducts()
				if inStore then invoke("Get") end
				return
			end
			if ok and type(result) == "table" then
				state = result.State or state
				message = result.Message or ""
			else
				message = "Could not reach the store. Try again."
			end
			refreshProducts()
			if action ~= "Get" and inStore then
				toastVersion += 1
				local version = toastVersion
				toast.Text, toast.Visible = message, true
				task.delay(4, function()
					if version == toastVersion then toast.Visible = false end
				end)
			end
			TechStore.render()
		end)
	end

	local function row(index: number, height: number): Frame
		local frame = make("Frame", list, { LayoutOrder = index, Size = UDim2.new(1, -8, 0, height) })
		Theme.glassPanel(frame, true)
		return frame
	end

	local function actionButton(parent: Instance, text: string, enabled: boolean, onClick: () -> ())
		local button = make("TextButton", parent, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -10, 1, -10),
			Size = UDim2.fromOffset(170, 32),
			Text = text,
			TextSize = 15,
		})
		Theme.button(button, if enabled then "Normal" else "Disabled")
		button.Activated:Connect(function()
			if enabled and not pending then
				onClick()
			end
		end)
		return button
	end

	function TechStore.render()
		for name, tab in tabs do
			Theme.button(tab, if name == department then "Selected" else "Normal")
		end
		slotBar.Visible = department == "Components"
		for slot, tab in slotTabs do
			Theme.button(tab, if slot == slotFilter then "Selected" else "Normal")
		end
		list.Position = UDim2.fromOffset(18, if department == "Components" then 188 else 152)
		list.Size = UDim2.new(1, -36, 1, if department == "Components" then -206 else -170)
		status.Text = if message ~= ""
			then message
			elseif state then "Wallet: " .. money(state.Cash) .. " · Parts go to your parts bin: fit them at the workbench in your base."
			else "Loading your company…"
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local cash = if state then state.Cash else 0
		if department == "Licenses" then
			for index, id in TechCatalog.LicenseOrder do
				local license = TechCatalog.Licenses[id]
				local frame = row(index, 110)
				local seal = make("Frame", frame, {
					Position = UDim2.fromOffset(10, 10),
					Size = UDim2.fromOffset(74, 90),
					BackgroundColor3 = Color3.fromRGB(250, 246, 230),
					BorderSizePixel = 0,
				})
				Theme.corner(seal, 4)
				local stamp = make("Frame", seal, {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.62),
					Size = UDim2.fromOffset(34, 34),
					BackgroundColor3 = RED,
					BorderSizePixel = 0,
				})
				Theme.corner(stamp, 17)
				local word = label(seal, "LICENSE", UDim2.fromOffset(0, 6), UDim2.new(1, 0, 0, 16), 11)
				word.TextXAlignment = Enum.TextXAlignment.Center
				word.TextColor3 = NAVY
				word.TextStrokeTransparency = 1
				label(frame, license.Name, UDim2.fromOffset(98, 10), UDim2.new(1, -110, 0, 24), 18)
				label(frame, license.Spec, UDim2.fromOffset(98, 36), UDim2.new(1, -110, 0, 20), 13)
				local owned = state and state.Licenses[id]
				actionButton(
					frame,
					if owned then "Licensed" else "Hold E at display",
					false,
					function()
						invoke("Buy", "License", id)
					end
				)
			end
			return
		end
		local slot = if department == "Monitors" then "Monitor" else slotFilter
		for index, id in TechCatalog.Order[slot] do
			local item = TechCatalog.Items[id]
			local frame = row(index, 94)
			if item.Screen then
				screenPreview(frame, item.Screen)
			else
				partBadge(frame, item)
			end
			local textX = if item.Screen then 136 else 98
			label(frame, item.Name, UDim2.fromOffset(textX, 10), UDim2.new(1, -textX - 10, 0, 24), 18)
			label(frame, item.Spec, UDim2.fromOffset(textX, 34), UDim2.new(1, -textX - 190, 0, 34), 13)
			local owned = state and TechCatalog.owns({ Owned = state.Owned, Equipped = state.Equipped, Licenses = state.Licenses }, id)
			local installed = state and state.Equipped[slot] == id
			local text, enabled, action
			if pending then
				text, enabled = "Please wait", false
			elseif installed then
				text, enabled = "In your PC", false
			elseif owned then
				text, enabled = "In parts bin", false
			elseif cash < item.Price then
				text, enabled = "Need " .. money(item.Price), false
			else
				text, enabled = "Hold E at display", false
			end
			actionButton(frame, text, state ~= nil and enabled, function()
				invoke(action, "Item", id)
			end)
		end
	end

	for name, tab in tabs do
		tab.Activated:Connect(function()
			department = name
			message = ""
			TechStore.render()
		end)
	end
	for slot, tab in slotTabs do
		tab.Activated:Connect(function()
			slotFilter = slot
			message = ""
			TechStore.render()
		end)
	end
	local function hide()
		overlay.Visible = false
	end
	Interior.start(function(prompt, entry)
		if not inStore then visit += 1 end
		inStore = true
		productPrompts[prompt] = entry
		refreshProducts()
		if not state and not pending then invoke("Get") end
	end, function()
		visit += 1
		inStore = false
		table.clear(productPrompts)
		state = nil
		toastVersion += 1
		toast.Visible = false
		hide()
	end)
	local refreshQueued = false
	player:GetAttributeChangedSignal("AnglerRevision"):Connect(function()
		if not inStore or refreshQueued then return end
		refreshQueued = true
		task.delay(0.35, function()
			refreshQueued = false
			if inStore and not pending then invoke("Get") end
		end)
	end)
	close.Activated:Connect(hide)
	overlay.Activated:Connect(hide)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then
			hide()
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		local entry = productPrompts[prompt]
		if entry and (not who or who == player) then
			invoke("Buy", entry.Kind, entry.Id)
			return
		end
		if prompt.Name ~= TechCatalog.PROMPT_NAME or (who and who ~= player) then
			return
		end
		local wanted = prompt.Parent and prompt.Parent:GetAttribute("Department")
		if type(wanted) == "string" and table.find(TechCatalog.Departments, wanted) then
			department = wanted
		end
		overlay.Visible = true
		invoke("Get")
	end)
	RunService.RenderStepped:Connect(function()
		if overlay.Visible and workspace.CurrentCamera then
			local viewport = workspace.CurrentCamera.ViewportSize
			scale.Scale = math.min(1, (viewport.X - 24) / WIDTH, (viewport.Y - 32) / HEIGHT)
		end
	end)
	TechStore.render()
end

return TechStore
