-- Talking to Pirate Cove's crew (Shared.PirateCove): quest givers offer and take in their quests,
-- Gunner Flint sells rods and Quartermaster Bess buys fish. The panel asks the server for what to
-- show and sends every choice back to it; the server decides and saves.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cove = require(Shared:WaitForChild("PirateCove"))
local RodSkins = require(Shared:WaitForChild("RodSkins"))

local Client = {}
local started = false

local GOLD = Color3.fromRGB(255, 205, 64)
local PROMPT = "PirateCoveNpcPrompt"
local WALK_AWAY = 18
local MAX_BUTTONS = 6

local function label(parent: Instance, props): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.TextWrapped = true
	for key, value in props do
		item[key] = value
	end
	Theme.text(item, props.TextColor3)
	item.Font = props.Font or Enum.Font.GothamBold
	item.Parent = parent
	return item
end

local function perks(skinId: string): string
	local skin = RodSkins.Skins[skinId]
	local parts = {}
	if (skin.Reel or 0) > 0 then
		table.insert(parts, string.format("+%g%% reel", skin.Reel * 100))
	end
	if (skin.Size or 0) > 0 then
		table.insert(parts, string.format("+%g%% size", skin.Size * 100))
	end
	return table.concat(parts, " · ")
end

function Client.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local folder = ReplicatedStorage:WaitForChild("PirateCove")
	local remote = folder:WaitForChild("Request") :: RemoteFunction

	local gui = Instance.new("ScreenGui")
	gui.Name = "PirateCove"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 25
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "Dialogue"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -24)
	panel.Size = UDim2.new(0.92, 0, 0, 236)
	panel.Visible = false
	panel.Active = true
	panel.ZIndex = 10
	panel.Parent = gui
	Theme.window(panel)
	local bounds = Instance.new("UISizeConstraint")
	bounds.MaxSize = Vector2.new(660, 236)
	bounds.Parent = panel
	local speaker = label(panel, {
		Name = "Speaker",
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.new(1, -40, 0, 22),
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = GOLD,
		RichText = true,
		ZIndex = 11,
	})
	local line = label(panel, {
		Name = "Line",
		Position = UDim2.fromOffset(20, 42),
		Size = UDim2.new(1, -40, 0, 62),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.GothamMedium,
		ZIndex = 11,
	})
	local status = label(panel, {
		Name = "Status",
		Position = UDim2.fromOffset(20, 106),
		Size = UDim2.new(1, -40, 0, 20),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Colors.Muted,
		Font = Enum.Font.GothamMedium,
		RichText = true,
		ZIndex = 11,
	})
	local options = Instance.new("Frame")
	options.Name = "Options"
	options.BackgroundTransparency = 1
	options.Position = UDim2.new(0, 16, 1, -100)
	options.Size = UDim2.new(1, -32, 0, 86)
	options.ZIndex = 11
	options.Parent = panel
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.CellSize = UDim2.new(1 / 3, -6, 0, 39)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = options

	local buttons: { TextButton } = {}
	local handlers: { [TextButton]: () -> () } = {}
	for i = 1, MAX_BUTTONS do
		local button = Instance.new("TextButton")
		button.Name = "Option" .. i
		button.LayoutOrder = i
		button.TextSize = 13
		button.TextWrapped = true
		button.RichText = true
		button.Visible = false
		button.ZIndex = 12
		button.Parent = options
		Theme.button(button)
		buttons[i] = button
		button.Activated:Connect(function()
			local run = handlers[button]
			if run then
				run()
			end
		end)
	end

	local talking: string? = nil
	local pending = false
	local lorePage = 1

	local function close()
		talking = nil
		panel.Visible = false
	end

	type Option = { text: string, style: string?, run: () -> () }
	local function setOptions(list: { Option })
		for i, button in buttons do
			local option = list[i]
			button.Visible = option ~= nil
			handlers[button] = option and option.run
			if option then
				button.Text = option.text
				Theme.button(button, option.style)
			end
		end
	end

	local render: (string, any, string?) -> ()

	local function send(id: string, action: string, value: any?)
		if pending then
			return
		end
		pending = true
		local ok, result = pcall(remote.InvokeServer, remote, action, id, value)
		pending = false
		if talking ~= id then
			return
		end
		if not ok or type(result) ~= "table" then
			status.Text = "The cove didn't answer. Try again."
			return
		end
		render(id, result.State, result.Message)
	end

	render = function(id: string, view, message: string?)
		local npc = Cove.Npcs[id]
		if not npc or type(view) ~= "table" then
			return
		end
		local bye = { text = "Bye", run = close }
		status.Text = ""
		if npc.Kind == "Lore" then
			local pages = npc.Lore or { npc.Greeting }
			lorePage = math.clamp(lorePage, 1, #pages)
			line.Text = message or pages[lorePage]
			if view.Unlocked then
				status.Text = "His treasure is spent: every gamepass is yours for good."
			elseif view.Found then
				status.Text = "You carry his lost compass rose. Use it from your cargo hold to unlock every gamepass."
			else
				status.Text = "The Ultimate treasure waits in the deep: one cast in a million."
			end
			local list = {}
			if lorePage < #pages then
				table.insert(list, {
					text = "Tell me more",
					style = "Selected",
					run = function()
						lorePage += 1
						render(id, view, nil)
					end,
				})
			end
			table.insert(list, bye)
			setOptions(list)
		elseif npc.Kind == "Buyer" then
			local left = view.SalesLeft or 0
			line.Text = message
				or (
					if left > 0
						then npc.Greeting .. string.format(" I'll take %d more fish today.", left)
						else "We've got enough fish to feed the whole cove today. Come back tomorrow, love!"
				)
			status.Text = string.format(
				"Holding: %s · Backpack: %d fish · Galley needs %d / %d more today",
				if view.Holding then "a fish" else "nothing",
				view.Backpack or 0,
				left,
				Cove.DAILY_SALES
			)
			if left > 0 then
				setOptions({
					{
						text = "Sell held fish",
						style = "Selected",
						run = function()
							send(id, "SellHand")
						end,
					},
					{
						text = "Sell all",
						run = function()
							send(id, "SellAll")
						end,
					},
					bye,
				})
			else
				setOptions({ bye })
			end
		elseif npc.Kind == "Shop" then
			line.Text = message or npc.Greeting
			status.Text = string.format(
				"Second-hand rods in %s wear. Each one is yours to keep.",
				RodSkins.wearState(Cove.ROD_WEAR)
			)
			local list = {}
			for _, rod in Cove.Rods do
				local skin = RodSkins.Skins[rod.SkinId]
				local owned = (view.Owned or {})[rod.SkinId] or 0
				table.insert(list, {
					text = string.format(
						'%s  <font color="#FFCD40">$%d</font>\n<font size="11">%s%s</font>',
						skin.Name,
						rod.Price,
						perks(rod.SkinId),
						if owned > 0 then string.format(" · own %d", owned) else ""
					),
					run = function()
						send(id, "BuyRod", rod.SkinId)
					end,
				})
			end
			table.insert(list, bye)
			setOptions(list)
		else
			local quest = Cove.quest(id, view.Step)
			if view.Finished or not quest then
				line.Text = message or (npc.Greeting .. " You've done everything I asked. Fair winds, friend.")
				setOptions({ bye })
			elseif not view.Accepted then
				line.Text = message or (npc.Greeting .. " " .. quest.Offer)
				status.Text = string.format(
					"<b>%s</b> · %s · Reward $%d, %d XP",
					quest.Title,
					view.Goal or "",
					quest.Cash,
					quest.XP
				)
				setOptions({
					{
						text = "Accept",
						style = "Selected",
						run = function()
							send(id, "Accept")
						end,
					},
					bye,
				})
			else
				local claimText = if quest.Kind == "Catch" then "Claim reward" else "Hand it over"
				line.Text = message or (if view.Ready then quest.Done else quest.Offer)
				status.Text = string.format("<b>%s</b> · %s", quest.Title, view.Goal or "")
				setOptions({
					{
						text = claimText,
						style = if view.Ready then "Selected" else nil,
						run = function()
							send(id, "Claim")
						end,
					},
					bye,
				})
			end
		end
		local title = npc.Name .. '  <font color="#D7D7D7" size="14">' .. npc.Title .. "</font>"
		speaker.Text = title
	end

	local function open(id: string)
		local npc = Cove.Npcs[id]
		if not npc then
			return
		end
		talking = id
		lorePage = 1
		speaker.Text = npc.Name .. '  <font color="#D7D7D7" size="14">' .. npc.Title .. "</font>"
		line.Text = npc.Greeting
		status.Text = ""
		setOptions({ { text = "Bye", run = close } })
		panel.Visible = true
		send(id, "Get")
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == PROMPT then
			local id = prompt:GetAttribute("NpcId")
			if type(id) == "string" then
				open(id)
			end
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if talking and not processed and input.KeyCode == Enum.KeyCode.Escape then
			close()
		end
	end)
	RunService.Heartbeat:Connect(function()
		local id = talking
		if not id then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local position = folder:GetAttribute("Npc_" .. id)
		if not root or (typeof(position) == "Vector3" and (root.Position - position).Magnitude > WALK_AWAY) then
			close()
		end
	end)
end

return Client
