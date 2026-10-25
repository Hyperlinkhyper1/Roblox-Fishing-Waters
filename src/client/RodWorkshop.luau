-- Finn's rod upgrade counter in Tide & Tackle. The server charges, saves and
-- publishes levels as RodUpgrade<Stat> attributes; this module only presents them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))
local RodUpgrades = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RodUpgrades"))

local RodWorkshop = {}
local started = false

local WIDTH, HEIGHT = 640, 452
local CARD_WIDTH, CARD_GAP = 188, 14
local GOLD = Color3.fromRGB(244, 196, 76)
local AFFORD = Color3.fromRGB(111, 202, 125)
local SHORT = Color3.fromRGB(238, 107, 111)
local ACCENTS = {
	Speed = Color3.fromRGB(86, 196, 232),
	Strength = Color3.fromRGB(238, 120, 84),
	Luck = Color3.fromRGB(196, 120, 240),
}
local GREETINGS = {
	"Ahoy! Bring me coin and I'll tune that rod till it sings.",
	"Every level costs a bit more, but the fish never stop getting bigger.",
	"Rarity Luck's my finest work. Pricey, mind you, but legends bite for it.",
	"A faster reel means fewer fish slipping the hook. Trust old Finn.",
}

local function commas(value: number): string
	local text = tostring(math.floor(value))
	while true do
		local replaced, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		text = replaced
		if count == 0 then
			return text
		end
	end
end

function RodWorkshop.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Fishing")
	local request = remotes:WaitForChild("Request") :: RemoteEvent
	local feedback = remotes:WaitForChild("Feedback") :: RemoteEvent
	local cream, muted = Theme.Colors.Text, Theme.Colors.Muted

	local gui = Instance.new("ScreenGui")
	gui.Name = "RodWorkshop"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 23
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	local function label(parent: Instance, text: string, position: UDim2, size: UDim2, textSize: number, color: Color3)
		local item = Instance.new("TextLabel")
		item.BackgroundTransparency = 1
		item.Position, item.Size = position, size
		item.Text, item.TextSize = text, textSize
		item.TextWrapped = true
		item.TextXAlignment = Enum.TextXAlignment.Left
		Theme.text(item, color)
		item.Parent = parent
		return item
	end
	local function frame(parent: Instance, name: string, position: UDim2, size: UDim2, color: Color3): Frame
		local item = Instance.new("Frame")
		item.Name = name
		item.Position, item.Size = position, size
		item.BackgroundColor3 = color
		item.BorderSizePixel = 0
		item.Parent = parent
		return item
	end
	local function gradient(parent: Instance, top: Color3, bottom: Color3)
		local fill = Instance.new("UIGradient")
		fill.Rotation = 90
		fill.Color = ColorSequence.new(top, bottom)
		fill.Parent = parent
		return fill
	end

	local overlay = Instance.new("TextButton")
	overlay.Name = "WorkshopOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.45
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Visible = false
	overlay.Parent = gui

	local window = Instance.new("Frame")
	window.Name = "RodUpgrades"
	window.Active = true
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	window.Parent = overlay
	Theme.window(window)
	local scale = Instance.new("UIScale")
	scale.Parent = window

	-- Header: Finn's badge, his line of dialogue and the angler's wallet.
	local header = frame(window, "Header", UDim2.fromOffset(14, 14), UDim2.new(1, -28, 0, 112), Color3.new(1, 1, 1))
	Theme.corner(header, 8)
	gradient(header, Color3.fromRGB(38, 92, 104), Color3.fromRGB(24, 52, 66))
	local badge =
		frame(header, "Badge", UDim2.fromOffset(16, 16), UDim2.fromOffset(80, 80), Color3.fromRGB(250, 236, 200))
	Theme.corner(badge, 40)
	local badgeRing = Instance.new("UIStroke")
	badgeRing.Color, badgeRing.Thickness = GOLD, 3
	badgeRing.Parent = badge
	local initial = label(badge, "F", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 42, Color3.fromRGB(38, 92, 104))
	initial.TextXAlignment = Enum.TextXAlignment.Center
	initial.TextStrokeTransparency = 1
	label(header, "FINN · ROD KEEPER", UDim2.fromOffset(112, 14), UDim2.fromOffset(300, 18), 13, GOLD)
	label(header, "Rod upgrades", UDim2.fromOffset(112, 32), UDim2.fromOffset(300, 32), 26, cream)
	local speech = label(header, "", UDim2.fromOffset(112, 66), UDim2.new(1, -300, 0, 38), 14, muted)
	speech.Font = Enum.Font.GothamMedium
	speech.TextYAlignment = Enum.TextYAlignment.Top
	local wallet = frame(header, "Wallet", UDim2.new(1, -168, 0, 22), UDim2.fromOffset(150, 46), Theme.Colors.Inset)
	Theme.panel(wallet, true, 23)
	label(wallet, "WALLET", UDim2.fromOffset(16, 4), UDim2.new(1, -24, 0, 14), 11, muted)
	local cash = label(wallet, "$0", UDim2.fromOffset(16, 18), UDim2.new(1, -24, 0, 24), 20, AFFORD)

	local close = Instance.new("TextButton")
	close.Name = "CloseWorkshop"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -6, 0, 6)
	close.Size = UDim2.fromOffset(34, 34)
	close.Text = "×"
	close.TextSize = 24
	close.ZIndex = 4
	close.Parent = header
	Theme.button(close, "Danger")

	-- One card per stat: accent stripe, level pips, effect now and next, buy button.
	local cards = {}
	local row = frame(window, "Upgrades", UDim2.fromOffset(0, 140), UDim2.new(1, 0, 0, 252), Color3.new())
	row.BackgroundTransparency = 1
	local rowWidth = CARD_WIDTH * #RodUpgrades.Order + CARD_GAP * (#RodUpgrades.Order - 1)
	for index, stat in RodUpgrades.Order do
		local spec = RodUpgrades.Stats[stat]
		local x = (WIDTH - rowWidth) / 2 + (index - 1) * (CARD_WIDTH + CARD_GAP)
		local card = frame(row, stat, UDim2.fromOffset(x, 0), UDim2.fromOffset(CARD_WIDTH, 252), Theme.Colors.Panel)
		Theme.panel(card, false, 8)
		local stripe = frame(card, "Accent", UDim2.fromScale(0, 0), UDim2.new(1, 0, 0, 6), ACCENTS[stat])
		Theme.corner(stripe, 8)
		local glow = frame(card, "Glow", UDim2.fromOffset(0, 6), UDim2.new(1, 0, 0, 60), ACCENTS[stat])
		glow.BackgroundTransparency = 0.8
		local fade = gradient(glow, Color3.new(1, 1, 1), Color3.new(1, 1, 1))
		fade.Transparency = NumberSequence.new(0, 1)
		label(card, string.upper(spec.Name), UDim2.fromOffset(14, 16), UDim2.new(1, -28, 0, 20), 15, ACCENTS[stat])
		local level = label(card, "", UDim2.fromOffset(14, 38), UDim2.new(1, -28, 0, 30), 24, cream)
		local description = label(card, spec.Description, UDim2.fromOffset(14, 70), UDim2.new(1, -28, 0, 44), 12, muted)
		description.Font = Enum.Font.GothamMedium
		description.TextYAlignment = Enum.TextYAlignment.Top
		local pips = {}
		local pipWidth = (CARD_WIDTH - 28 - (spec.MaxLevel - 1) * 3) / spec.MaxLevel
		for pip = 1, spec.MaxLevel do
			local cell = frame(
				card,
				"Pip" .. pip,
				UDim2.fromOffset(14 + (pip - 1) * (pipWidth + 3), 120),
				UDim2.fromOffset(pipWidth, 10),
				Theme.Colors.Inset
			)
			Theme.corner(cell, 3)
			pips[pip] = cell
		end
		local now = label(card, "", UDim2.fromOffset(14, 140), UDim2.new(1, -28, 0, 18), 13, cream)
		local nextEffect = label(card, "", UDim2.fromOffset(14, 158), UDim2.new(1, -28, 0, 18), 13, AFFORD)
		local buy = Instance.new("TextButton")
		buy.Name = "Upgrade" .. stat
		buy.Position = UDim2.new(0, 12, 1, -64)
		buy.Size = UDim2.new(1, -24, 0, 52)
		buy.TextSize = 16
		buy.TextWrapped = true
		buy.RichText = true
		buy.Parent = card
		Theme.button(buy, "Selected")
		cards[stat] = {
			card = card,
			level = level,
			pips = pips,
			now = now,
			nextEffect = nextEffect,
			buy = buy,
			glow = glow,
		}
	end

	local status = label(window, "", UDim2.fromOffset(24, HEIGHT - 50), UDim2.new(1, -48, 0, 32), 14, muted)
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.Font = Enum.Font.GothamMedium

	local pending: string? = nil
	local pendingId = 0
	local lastRequest = -math.huge
	local keeperHead: BasePart? = nil

	local function levelOf(stat: string): number
		local value = player:GetAttribute(RodUpgrades.attribute(stat))
		return if type(value) == "number" then value else 0
	end

	local function refresh()
		local money = player:GetAttribute("Cash")
		money = if type(money) == "number" then money else 0
		cash.Text = "$" .. commas(money)
		local ready = player:GetAttribute("BoatDataStatus") == "Ready"
		local ownsRod = player:GetAttribute("OwnsStarterRod") == true
		for _, stat in RodUpgrades.Order do
			local spec = RodUpgrades.Stats[stat]
			local view = cards[stat]
			local current = levelOf(stat)
			local price = RodUpgrades.price(stat, current)
			view.level.Text = string.format('Lv %d <font size="15" color="#9a9a9a">/ %d</font>', current, spec.MaxLevel)
			view.level.RichText = true
			for pip, cell in view.pips do
				cell.BackgroundColor3 = if pip <= current then ACCENTS[stat] else Theme.Colors.Inset
			end
			view.now.Text = if current > 0 then "Now: " .. RodUpgrades.effect(stat, current) else "Now: stock rod"
			local enabled = false
			if not price then
				view.nextEffect.Text = "Fully upgraded!"
				view.nextEffect.TextColor3 = GOLD
				view.buy.Text = "MAXED OUT"
				Theme.button(view.buy, "Disabled")
			else
				view.nextEffect.Text = "Next: " .. RodUpgrades.effect(stat, current + 1)
				view.nextEffect.TextColor3 = AFFORD
				local afford = money >= price
				enabled = ready and ownsRod and afford and pending == nil
				local priceColor = if afford then "#a6f0b2" else "#ff9a9d"
				view.buy.Text = if pending == stat
					then "Upgrading…"
					else string.format('UPGRADE\n<font color="%s">$%s</font>', priceColor, commas(price))
				Theme.button(view.buy, if enabled then "Selected" elseif pending == stat then "Normal" else "Disabled")
			end
			view.buy.Active, view.buy.Selectable, view.buy.AutoButtonColor = enabled, enabled, enabled
		end
		if not ready then
			status.Text = "Loading your wallet…"
			status.TextColor3 = muted
		elseif not ownsRod then
			status.Text = "Collect your free starter rod at the counter first, then Finn can upgrade it."
			status.TextColor3 = muted
		end
	end

	local function setStatus(message: string, color: Color3)
		status.Text, status.TextColor3 = message, color
	end

	local function open()
		if overlay.Visible then
			return
		end
		speech.Text = "“" .. GREETINGS[math.random(#GREETINGS)] .. "”"
		setStatus("Upgrades apply from your next cast.", muted)
		refresh()
		overlay.Visible = true
		player:SetAttribute("RodWorkshopOpen", true)
		scale.Scale = scale:GetAttribute("Fit") or 1
		window.Position = UDim2.new(0.5, 0, 0.5, 24)
		TweenService
			:Create(window, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.5) })
			:Play()
	end
	local function closeWorkshop()
		if overlay.Visible then
			overlay.Visible = false
			player:SetAttribute("RodWorkshopOpen", false)
		end
	end

	local function celebrate(stat: string)
		local view = cards[stat]
		if not view then
			return
		end
		view.glow.BackgroundTransparency = 0.25
		TweenService:Create(view.glow, TweenInfo.new(0.8), { BackgroundTransparency = 0.8 }):Play()
		local pip = view.pips[levelOf(stat)]
		if pip then
			pip.Size = UDim2.fromOffset(pip.Size.X.Offset, 16)
			pip.Position = UDim2.fromOffset(pip.Position.X.Offset, 117)
			TweenService:Create(pip, TweenInfo.new(0.35, Enum.EasingStyle.Back), {
				Size = UDim2.fromOffset(pip.Size.X.Offset, 10),
				Position = UDim2.fromOffset(pip.Position.X.Offset, 120),
			}):Play()
		end
	end

	for _, stat in RodUpgrades.Order do
		cards[stat].buy.Activated:Connect(function()
			if pending or not cards[stat].buy.Active or os.clock() - lastRequest < 0.5 then
				return
			end
			lastRequest = os.clock()
			pending, pendingId = stat, pendingId + 1
			local current = pendingId
			setStatus("Finn is working on your rod…", muted)
			refresh()
			request:FireServer("UpgradeRod", stat)
			task.delay(8, function()
				if pendingId == current and pending then
					pending = nil
					setStatus("The upgrade took too long. Please try again.", SHORT)
					refresh()
				end
			end)
		end)
	end
	close.Activated:Connect(closeWorkshop)
	overlay.Activated:Connect(closeWorkshop)
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			closeWorkshop()
		end
	end)

	feedback.OnClientEvent:Connect(function(kind, a, b)
		if kind == "OpenUpgrades" and not player:GetAttribute("PlayerMenuOpen") then
			local hall = workspace:FindFirstChild("Interiors")
			local keeper = hall and hall:FindFirstChild("RodKeeper", true)
			local head = keeper and keeper:FindFirstChild("Head")
			keeperHead = if head and head:IsA("BasePart") then head else nil
			open()
		elseif kind == "UpgradeResult" and type(b) == "string" then
			local stat = pending
			pending = nil
			-- Let the replicated level and wallet arrive before redrawing the card.
			task.delay(0.15, function()
				refresh()
				if a == true and stat then
					celebrate(stat)
				end
			end)
			setStatus(b, if a == true then AFFORD else SHORT)
		end
	end)
	local watched = { "Cash", "BoatDataStatus", "OwnsStarterRod" }
	for _, stat in RodUpgrades.Order do
		table.insert(watched, RodUpgrades.attribute(stat))
	end
	for _, attribute in watched do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if overlay.Visible then
				refresh()
			end
		end)
	end
	player:GetAttributeChangedSignal("PlayerMenuOpen"):Connect(function()
		if player:GetAttribute("PlayerMenuOpen") then
			closeWorkshop()
		end
	end)
	player.CharacterRemoving:Connect(closeWorkshop)

	-- Fit small screens, and close once the angler walks away from the counter.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then
			return
		end
		elapsed = 0
		local camera = workspace.CurrentCamera
		if camera then
			local fit =
				math.max(0.3, math.min(1, (camera.ViewportSize.X - 24) / WIDTH, (camera.ViewportSize.Y - 60) / HEIGHT))
			scale:SetAttribute("Fit", fit)
			scale.Scale = fit
		end
		if overlay.Visible then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if
				not root
				or not root:IsA("BasePart")
				or (keeperHead and (root.Position - keeperHead.Position).Magnitude > 18)
			then
				closeWorkshop()
			end
		end
	end)
	refresh()
end

return RodWorkshop
