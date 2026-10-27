-- Rod and bobber cases in Tide & Tackle share the same catalog-driven window.
-- The server rolls, charges and saves; this module presents owned skins and
-- plays the unboxing reveal at the matching stand.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local FishingRod = require(Shared:WaitForChild("FishingRod"))
local RodSkins = require(Shared:WaitForChild("RodSkins"))
local BobberSkins = require(Shared:WaitForChild("BobberSkins"))
local FishingBobber = require(Shared:WaitForChild("FishingBobber"))
local CrateReveal = require(script.Parent:WaitForChild("RodCrateReveal"))

local RodCrates = {}
local started = false

local WIDTH, HEIGHT = 760, 658
local CARD_WIDTH, CARD_HEIGHT, CARD_GAP = 170, 200, 10
local GOLD = Color3.fromRGB(244, 196, 76)
local AFFORD = Color3.fromRGB(111, 202, 125)
local SHORT = Color3.fromRGB(238, 107, 111)

local function rarityColor(rarity: string): Color3
	local rgb = RodSkins.Rarities[rarity].Color
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function hex(color: Color3): string
	return string.format(
		"#%02x%02x%02x",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

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

local function percent(chance: number): string
	local value = chance * 100
	return if value >= 1
		then string.format("%g%%", math.floor(value * 100 + 0.5) / 100)
		else string.format("%.2g%%", value)
end

-- A still, anchored copy of the real skin, so the card shows exactly what the angler will hold.
local function preview(parent: GuiObject, skinId: string, bobber: boolean)
	local view = Instance.new("ViewportFrame")
	view.Name = "SkinPreview"
	view.BackgroundTransparency = 1
	view.Position = UDim2.fromOffset(6, 10)
	view.Size = UDim2.new(1, -12, 0, 78)
	view.Ambient = Color3.fromRGB(165, 170, 175)
	view.LightColor = Color3.fromRGB(255, 241, 216)
	view.LightDirection = Vector3.new(-1, -1, -2)
	view.Parent = parent
	local world = Instance.new("WorldModel")
	world.Parent = view
	local rod = if bobber then FishingBobber.build(skinId) else FishingRod.build(skinId)
	-- Preview tools must never join the live rod animation/tag listeners.
	if not bobber then
		CollectionService:RemoveTag(rod, "FishingRod")
		rod.Enabled = false
	end
	local model = Instance.new("Model")
	model.Name = "DisplayRod"
	model.Parent = world
	for _, part in rod:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	rod.Parent = model
	-- Lay the rod on its side, butt to the left.
	local center, size = model:GetBoundingBox()
	model:PivotTo(
		CFrame.Angles(0, math.rad(-12), if bobber then 0 else math.rad(-75)) * center:Inverse() * model:GetPivot()
	)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = view
	view.CurrentCamera = camera
	local function frame()
		local aspect = math.max(0.5, view.AbsoluteSize.X / math.max(1, view.AbsoluteSize.Y))
		local length = math.max(size.X, size.Y) * (if bobber then 1.3 else 1)
		local distance = math.max(length * 0.62 / aspect, if bobber then length * 0.62 else 0, size.Z)
			/ math.tan(math.rad(15))
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, distance), Vector3.zero)
	end
	view:GetPropertyChangedSignal("AbsoluteSize"):Connect(frame)
	frame()
end

local function startShop(RodSkins, bobber: boolean)
	local kind = if bobber then "Bobber" else "Rod"
	local openAction = "Open" .. kind .. "Crate"
	local equipAction = "Equip" .. kind .. "Skin"
	local openEvent = if bobber then "OpenBobberCrates" else "OpenCrates"
	local resultEvent = if bobber then "BobberCrateResult" else "CrateResult"
	local skinEvent = if bobber then "BobberSkinResult" else "SkinResult"
	local skinAttribute = kind .. "Skin"
	local countAttribute = kind .. "SkinCount"
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Fishing")
	local request = remotes:WaitForChild("Request") :: RemoteEvent
	local feedback = remotes:WaitForChild("Feedback") :: RemoteEvent
	local cream, muted = Theme.Colors.Text, Theme.Colors.Muted
	local crateId = RodSkins.CrateOrder[1]
	local crate = RodSkins.Crates[crateId]

	local gui = Instance.new("ScreenGui")
	gui.Name = kind .. "Crates"
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
	local function button(parent: Instance, name: string, text: string, position: UDim2, size: UDim2): TextButton
		local item = Instance.new("TextButton")
		item.Name = name
		item.Position, item.Size = position, size
		item.Text = text
		item.TextSize = 14
		item.TextWrapped = true
		item.RichText = true
		item.Parent = parent
		Theme.button(item, "Selected")
		return item
	end

	local overlay = Instance.new("TextButton")
	overlay.Name = "CrateOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.45
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Visible = false
	overlay.Parent = gui

	local window = Instance.new("Frame")
	window.Name = kind .. "CrateWindow"
	window.Active = true
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	window.Parent = overlay
	Theme.window(window)
	local scale = Instance.new("UIScale")
	scale.Parent = window

	-- Header: crate name, odds summary and the angler's wallet.
	local header = frame(window, "Header", UDim2.fromOffset(14, 14), UDim2.new(1, -28, 0, 96), Color3.new(1, 1, 1))
	Theme.corner(header, 8)
	gradient(header, Color3.fromRGB(86, 52, 120), Color3.fromRGB(40, 26, 66))
	label(
		header,
		"TIDE & TACKLE · " .. (if bobber then "BOBBERS" else "ROD CRATES"),
		UDim2.fromOffset(18, 12),
		UDim2.fromOffset(360, 18),
		13,
		GOLD
	)
	local title = label(header, crate.Name, UDim2.fromOffset(18, 30), UDim2.fromOffset(360, 32), 26, cream)
	local oddsLine = label(header, "", UDim2.fromOffset(18, 64), UDim2.new(1, -220, 0, 20), 13, muted)
	oddsLine.RichText = true
	oddsLine.Font = Enum.Font.GothamMedium
	local wallet = frame(header, "Wallet", UDim2.new(1, -196, 0, 24), UDim2.fromOffset(150, 46), Theme.Colors.Inset)
	Theme.panel(wallet, true, 23)
	label(wallet, "WALLET", UDim2.fromOffset(16, 4), UDim2.new(1, -24, 0, 14), 11, muted)
	local cash = label(wallet, "$0", UDim2.fromOffset(16, 18), UDim2.new(1, -24, 0, 24), 20, AFFORD)

	local close = Instance.new("TextButton")
	close.Name = "CloseCrates"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -6, 0, 6)
	close.Size = UDim2.fromOffset(34, 34)
	close.Text = "×"
	close.TextSize = 24
	close.ZIndex = 4
	close.Parent = header
	Theme.button(close, "Danger")

	-- Each crate has its own reward grid; selecting a tab also changes the purchase.
	local tabs = frame(window, "CrateTabs", UDim2.fromOffset(14, 122), UDim2.new(1, -28, 0, 32), Color3.new())
	tabs.BackgroundTransparency = 1
	local crateViews = {}
	for crateIndex, optionId in RodSkins.CrateOrder do
		local option = RodSkins.Crates[optionId]
		local tab = button(
			tabs,
			"Select" .. optionId,
			string.format("%s · $%s", option.Name, commas(option.Price)),
			UDim2.new((crateIndex - 1) / #RodSkins.CrateOrder, 0, 0, 0),
			UDim2.new(1 / #RodSkins.CrateOrder, -8, 1, 0)
		)
		local cards = {}
		local grid = frame(
			window,
			"Skins" .. optionId,
			UDim2.fromOffset(14, 164),
			UDim2.new(1, -28, 0, CARD_HEIGHT * 2 + CARD_GAP),
			Color3.new()
		)
		grid.BackgroundTransparency = 1
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
		layout.CellPadding = UDim2.fromOffset(CARD_GAP, CARD_GAP)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		for index, skinId in option.Skins do
			local skin = RodSkins.Skins[skinId]
			local skinRarity = RodSkins.rarity(skinId, optionId)
			local color = rarityColor(skinRarity)
			local card = frame(grid, skinId, UDim2.new(), UDim2.new(), Theme.Colors.Panel)
			card.LayoutOrder = index
			Theme.panel(card, false, 8)
			local stripe = frame(card, "Accent", UDim2.fromScale(0, 0), UDim2.new(1, 0, 0, 5), color)
			Theme.corner(stripe, 8)
			local glow = frame(card, "Glow", UDim2.fromOffset(0, 5), UDim2.new(1, 0, 0, 80), color)
			glow.BackgroundTransparency = 0.85
			local fade = gradient(glow, Color3.new(1, 1, 1), Color3.new(1, 1, 1))
			fade.Transparency = NumberSequence.new(0, 1)
			preview(card, skinId, bobber)
			label(card, skin.Name, UDim2.fromOffset(10, 88), UDim2.new(1, -20, 0, 20), 15, cream)
			local rarity = label(
				card,
				string.format("%s · %s", string.upper(skinRarity), percent(RodSkins.chance(optionId, skinId))),
				UDim2.fromOffset(10, 107),
				UDim2.new(1, -20, 0, 14),
				11,
				color
			)
			rarity.Font = Enum.Font.GothamBold
			local perks = label(
				card,
				table.concat(RodSkins.perks(skinId), "\n"),
				UDim2.fromOffset(10, 123),
				UDim2.new(1, -20, 0, 40),
				11,
				muted
			)
			perks.Font = Enum.Font.GothamMedium
			perks.TextYAlignment = Enum.TextYAlignment.Top
			local equip = button(card, "Equip" .. skinId, "", UDim2.new(0, 8, 1, -34), UDim2.new(1, -16, 0, 28))
			cards[skinId] = { card = card, glow = glow, equip = equip }
		end
		crateViews[optionId] = { tab = tab, grid = grid, cards = cards }
	end

	local footer = frame(window, "Footer", UDim2.new(0, 14, 1, -84), UDim2.new(1, -28, 0, 70), Color3.new())
	footer.BackgroundTransparency = 1
	local status = label(footer, "", UDim2.fromOffset(0, 0), UDim2.new(1, -414, 0, 36), 13, muted)
	status.Font = Enum.Font.GothamMedium
	status.TextYAlignment = Enum.TextYAlignment.Top
	local plain = button(
		footer,
		"UseStarterLook",
		if bobber then "Use starter bobber" else "Use starter rod look",
		UDim2.fromOffset(0, 40),
		UDim2.fromOffset(200, 28)
	)
	local opens = {}
	for index, count in { 1, 3, 10 } do
		local open = button(
			footer,
			if count == 1 then openAction else openAction .. count,
			"",
			UDim2.new(1, -402 + (index - 1) * 136, 0, 4),
			UDim2.fromOffset(130, 60)
		)
		open.TextSize = 15
		opens[count] = open
	end

	local results =
		frame(overlay, "CrateResults", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(480, 410), Theme.Colors.Inset)
	results.AnchorPoint = Vector2.new(0.5, 0.5)
	results.Visible = false
	results.ZIndex = 10
	Theme.panel(results, true, 8)
	local resultsScale = Instance.new("UIScale")
	resultsScale.Parent = results
	local resultsTitle = label(results, "YOUR REWARDS", UDim2.fromOffset(20, 12), UDim2.new(1, -40, 0, 30), 22, cream)
	resultsTitle.ZIndex = 11
	local resultsText = label(results, "", UDim2.fromOffset(20, 48), UDim2.new(1, -40, 0, 302), 16, cream)
	resultsText.RichText = true
	resultsText.TextYAlignment = Enum.TextYAlignment.Top
	resultsText.ZIndex = 11
	local resultsClose = button(results, "CloseResults", "DONE", UDim2.new(0.5, -90, 1, -48), UDim2.fromOffset(180, 36))
	resultsClose.ZIndex = 11

	-- A small reward caption stays outside the closed menu during the shop animation.
	local reveal =
		frame(gui, "RewardCaption", UDim2.new(0.5, 0, 1, -32), UDim2.fromOffset(520, 116), Theme.Colors.Inset)
	reveal.AnchorPoint = Vector2.new(0.5, 1)
	reveal.BackgroundTransparency = 0.2
	reveal.Visible = false
	reveal.ZIndex = 6
	Theme.corner(reveal, 8)
	local rewardScale = Instance.new("UIScale")
	rewardScale.Parent = reveal
	local revealName = label(reveal, "", UDim2.fromOffset(16, 8), UDim2.new(1, -32, 0, 32), 26, cream)
	revealName.TextXAlignment = Enum.TextXAlignment.Center
	revealName.ZIndex = 7
	local revealRarity = label(reveal, "", UDim2.fromOffset(16, 41), UDim2.new(1, -32, 0, 20), 14, muted)
	revealRarity.TextXAlignment = Enum.TextXAlignment.Center
	revealRarity.Font = Enum.Font.GothamBold
	revealRarity.ZIndex = 7
	local revealPerks = label(reveal, "", UDim2.fromOffset(16, 66), UDim2.new(1, -32, 0, 44), 13, muted)
	revealPerks.TextXAlignment = Enum.TextXAlignment.Center
	revealPerks.TextYAlignment = Enum.TextYAlignment.Top
	revealPerks.ZIndex = 7
	local revealRing = Instance.new("UIStroke")
	revealRing.Thickness = 3
	revealRing.Color = GOLD
	revealRing.Parent = reveal

	local pending: string? = nil
	local pendingId = 0
	local lastRequest = -math.huge
	local revealing = false
	local stopReveal: (() -> ())? = nil
	local standPart: BasePart? = nil

	local function owned(skinId: string): number
		local value = player:GetAttribute(countAttribute .. skinId)
		return if type(value) == "number" then value else 0
	end
	local function setStatus(message: string, color: Color3)
		status.Text, status.TextColor3 = message, color
	end

	local function refresh()
		local money = player:GetAttribute("Cash")
		money = if type(money) == "number" then money else 0
		cash.Text = "$" .. commas(money)
		local ready = player:GetAttribute("BoatDataStatus") == "Ready"
		local ownsRod = player:GetAttribute("OwnsStarterRod") == true
		local equipped = player:GetAttribute(skinAttribute)
		local idle = ready and pending == nil and not revealing
		title.Text = crate.Name
		local odds = {}
		for _, rarity in RodSkins.RarityOrder do
			table.insert(
				odds,
				string.format(
					'<font color="%s">%s %s</font>',
					hex(rarityColor(rarity)),
					rarity,
					percent(crate.Odds[rarity])
				)
			)
		end
		oddsLine.Text = table.concat(odds, "  ·  ")
		for optionId, view in crateViews do
			view.grid.Visible = optionId == crateId
			Theme.button(view.tab, if optionId == crateId then "Selected" else "Normal")
			view.tab.Active, view.tab.Selectable = idle, idle
		end
		for skinId, view in crateViews[crateId].cards do
			local count = owned(skinId)
			local active = equipped == skinId
			local enabled = idle and count > 0 and not active
			view.equip.Text = if count == 0
				then "Not owned"
				elseif active then "EQUIPPED"
				elseif count > 1 then string.format('Equip  <font color="#bdbdbd">×%d</font>', count)
				else "Equip"
			Theme.button(view.equip, if active then "Normal" elseif enabled then "Selected" else "Disabled")
			view.equip.Active, view.equip.Selectable, view.equip.AutoButtonColor = enabled, enabled, enabled
			local stroke = view.card:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if active then GOLD else Theme.Colors.Border
			end
		end
		local plainEnabled = idle and type(equipped) == "string" and equipped ~= ""
		Theme.button(plain, if plainEnabled then "Selected" else "Disabled")
		plain.Active, plain.Selectable, plain.AutoButtonColor = plainEnabled, plainEnabled, plainEnabled
		for count, open in opens do
			local afford = money >= crate.Price * count
			local openEnabled = idle and ownsRod and afford
			open.Text = if pending == openAction or revealing
				then "Opening…"
				else string.format(
					'OPEN %d×\n<font color="%s">$%s</font>',
					count,
					if afford then "#a6f0b2" else "#ff9a9d",
					commas(crate.Price * count)
				)
			Theme.button(open, if openEnabled then "Selected" else "Disabled")
			open.Active, open.Selectable, open.AutoButtonColor = openEnabled, openEnabled, openEnabled
		end
		if not ready then
			setStatus("Loading your wallet…", muted)
		elseif not ownsRod then
			setStatus("Your starter rod is still loading. Please try again shortly.", muted)
		end
	end

	local function openWindow()
		if
			overlay.Visible
			or revealing
			or pending == openAction
			or player:GetAttribute("RodCratesOpen")
			or player:GetAttribute("RodCrateOpening")
		then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if
			not root
			or not root:IsA("BasePart")
			or not standPart
			or not standPart:IsDescendantOf(workspace)
			or (root.Position - standPart.Position).Magnitude > 18
			or player:GetAttribute("PlayerMenuOpen")
		then
			return
		end
		setStatus(
			if bobber
				then "Equip one bobber for small luck and mutation boosts. Duplicate copies do not stack perks."
				else "Each skin adds its stats on top of Finn's upgrades. Duplicates stack as spares.",
			muted
		)
		reveal.Visible = false
		refresh()
		overlay.Visible = true
		player:SetAttribute("RodCratesOpen", true)
		scale.Scale = scale:GetAttribute("Fit") or 1
		window.Position = UDim2.new(0.5, 0, 0.5, 24)
		TweenService
			:Create(window, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.5) })
			:Play()
	end
	local function closeWindow()
		if overlay.Visible then
			overlay.Visible = false
			results.Visible = false
			window.Visible = true
			player:SetAttribute("RodCratesOpen", false)
		end
	end

	local function send(action: string, value: any)
		if pending or revealing or os.clock() - lastRequest < 0.5 then
			return
		end
		lastRequest = os.clock()
		pending, pendingId = action, pendingId + 1
		local current = pendingId
		refresh()
		if action == openAction then
			closeWindow()
			player:SetAttribute("RodCrateOpening", true)
		end
		request:FireServer(action, value)
		task.delay(if action == openAction and type(value) == "table" then 60 else 8, function()
			if pendingId == current and pending then
				pending = nil
				if action == openAction then
					player:SetAttribute("RodCrateOpening", false)
					openWindow()
				end
				setStatus("That took too long. Please try again.", SHORT)
				refresh()
			end
		end)
	end

	-- Only animate the actual skin after the server has charged and saved it.
	local function play(skinId: string, message: string, serial: number?, rewards: any?)
		if stopReveal then
			stopReveal()
		end
		closeWindow()
		revealing = true
		player:SetAttribute("RodCrateOpening", true)
		refresh()
		local skin = RodSkins.Skins[skinId]
		local skinRarity = RodSkins.rarity(skinId, crateId)
		local final = rarityColor(skinRarity)
		local function showReward()
			reveal.Visible = true
			revealName.Text = skin.Name
			revealName.TextColor3 = final
			revealRarity.Text = string.upper(skinRarity)
				.. (if serial then string.format(" · Serial #%06d", serial) else "")
			revealRarity.TextColor3 = final
			revealPerks.Text = table.concat(RodSkins.perks(skinId), "   ·   ")
			revealRing.Color = final
			setStatus(message, AFFORD)
		end
		local function finish()
			reveal.Visible = false
			revealing = false
			stopReveal = nil
			player:SetAttribute("RodCrateOpening", false)
			refresh()
			local view = crateViews[crateId].cards[skinId]
			if view then
				view.glow.BackgroundTransparency = 0.2
				TweenService:Create(view.glow, TweenInfo.new(1), { BackgroundTransparency = 0.85 }):Play()
			end
			if rewards then
				local lines = {}
				for _, reward in rewards do
					local rarity = RodSkins.rarity(reward.SkinId, crateId)
					table.insert(
						lines,
						string.format(
							'<font color="%s">%s</font>%s',
							hex(rarityColor(rarity)),
							RodSkins.Skins[reward.SkinId].Name,
							if reward.Serial then string.format(" · #%06d", reward.Serial) else ""
						)
					)
				end
				resultsText.Text = table.concat(lines, "\n")
				overlay.Visible = true
				window.Visible = false
				results.Visible = true
				player:SetAttribute("RodCratesOpen", true)
			end
		end
		stopReveal = CrateReveal.play(
			standPart,
			skinId,
			showReward,
			finish,
			if bobber
				then function()
					return FishingBobber.build(skinId)
				end
				else nil
		)
		if not stopReveal then
			-- The stand may have streamed away while the save was in flight.
			showReward()
			local cancelled = false
			stopReveal = function()
				if not cancelled then
					cancelled = true
					finish()
				end
			end
			task.delay(3, function()
				if not cancelled then
					cancelled = true
					finish()
				end
			end)
		end
	end

	for count, open in opens do
		open.Activated:Connect(function()
			if open.Active then
				setStatus("Finn is prying the lid off…", muted)
				send(openAction, if count == 1 then crateId else { CrateId = crateId, Count = count })
			end
		end)
	end
	resultsClose.Activated:Connect(function()
		results.Visible = false
		window.Visible = true
		closeWindow()
	end)
	plain.Activated:Connect(function()
		if plain.Active then
			send(equipAction, "")
		end
	end)
	for optionId, crateView in crateViews do
		crateView.tab.Activated:Connect(function()
			if pending or revealing or optionId == crateId then
				return
			end
			crateId, crate = optionId, RodSkins.Crates[optionId]
			setStatus(crate.Description, muted)
			refresh()
		end)
		for skinId, view in crateView.cards do
			view.equip.Activated:Connect(function()
				if view.equip.Active then
					send(equipAction, skinId)
				end
			end)
		end
	end
	close.Activated:Connect(closeWindow)
	overlay.Activated:Connect(function()
		if not revealing then
			closeWindow()
		end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			closeWindow()
		end
	end)

	feedback.OnClientEvent:Connect(function(kind, a, b, c, d)
		if kind == openEvent and not player:GetAttribute("PlayerMenuOpen") then
			local hall = workspace:FindFirstChild("Interiors")
			local stand = hall and hall:FindFirstChild(openAction .. "Prompt", true)
			standPart = if stand and stand.Parent and stand.Parent:IsA("BasePart") then stand.Parent else nil
			openWindow()
		elseif kind == resultEvent and type(b) == "string" then
			pending = nil
			if a == true and type(c) == "table" and #c > 0 and RodSkins.valid(c[1].SkinId) then
				play(c[1].SkinId, b, c[1].Serial, c)
			elseif a == true and RodSkins.valid(c) then
				play(c, b, if type(d) == "number" then d else nil)
			else
				player:SetAttribute("RodCrateOpening", false)
				openWindow()
				setStatus(b, SHORT)
				task.delay(0.15, refresh)
			end
		elseif kind == skinEvent and type(b) == "string" then
			pending = nil
			setStatus(b, if a == true then AFFORD else SHORT)
			task.delay(0.15, refresh)
		end
	end)
	local watched = { "Cash", "BoatDataStatus", "OwnsStarterRod", skinAttribute }
	for skinId in RodSkins.Skins do
		table.insert(watched, countAttribute .. skinId)
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
			closeWindow()
			if stopReveal then
				stopReveal()
			end
		end
	end)
	player.CharacterRemoving:Connect(function()
		closeWindow()
		pending = nil
		player:SetAttribute("RodCrateOpening", false)
		if stopReveal then
			stopReveal()
		end
	end)

	-- Fit small screens, and close once the angler walks away from the stand.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then
			return
		end
		elapsed = 0
		local camera = workspace.CurrentCamera
		if camera then
			resultsScale.Scale = math.min(1, (camera.ViewportSize.X - 24) / 480, (camera.ViewportSize.Y - 60) / 410)
			rewardScale.Scale = math.min(1, math.max(0.3, (camera.ViewportSize.X - 24) / 520))
			local fit =
				math.max(0.3, math.min(1, (camera.ViewportSize.X - 24) / WIDTH, (camera.ViewportSize.Y - 60) / HEIGHT))
			scale:SetAttribute("Fit", fit)
			scale.Scale = fit
		end
		if overlay.Visible and not revealing then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if
				not root
				or not root:IsA("BasePart")
				or (standPart and (root.Position - standPart.Position).Magnitude > 18)
			then
				closeWindow()
			end
		end
	end)
	refresh()
end

function RodCrates.start()
	if started then
		return
	end
	started = true
	startShop(RodSkins, false)
	startShop(BobberSkins, true)
end

return RodCrates
