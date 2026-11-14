-- Handling the office PC by hand (server PcWorkshopService). Prompts appear on your own desks
-- (F: pick the PC up / put it down) and on the workbench in your base (put it down, unscrew the
-- case, swap parts, screw it shut, pick it up). While the case is being opened or closed every
-- client animates the screws backing out and the panel lifting off. "Swap parts" frames the
-- camera on the open case and lists the company's parts per slot (Shared.TechCatalog); each
-- swap rebuilds the PC on the bench, so the new part shows up inside it straight away.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local TechCatalog = require(ReplicatedStorage.Shared.TechCatalog)
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))

local PcWorkshop = {}
local started = false

local BASE_TAG = "PlayerBase"
local CAFE_TAG = "CafePlot"
local SCREW_SECONDS = 2.4
local PANEL_WIDTH = 440

local player = Players.LocalPlayer
local remote: RemoteFunction? = nil
local busy = false

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

----------------------------------------------------------------------------------------------------
-- Toast

local toastGui: ScreenGui
local toast: TextLabel
local toastVersion = 0
local function notice(message: string?)
	if not message or message == "" or not toast then
		return
	end
	toastVersion += 1
	local version = toastVersion
	toast.Text = message
	toast.Visible = true
	task.delay(3.5, function()
		if version == toastVersion then
			toast.Visible = false
		end
	end)
end

local function request(action: string, slot: string?, id: string?): (boolean, any)
	if not remote then
		return false, nil
	end
	local ok, result = pcall(remote.InvokeServer, remote, action, slot, id)
	if not ok or type(result) ~= "table" then
		notice("The workshop didn't respond. Try again.")
		return false, nil
	end
	return result.Ok == true, result
end

----------------------------------------------------------------------------------------------------
-- Opening and closing animation

local animating: { [Instance]: boolean } = {}

local function lerp(a: CFrame, b: CFrame, t: number): CFrame
	return a:Lerp(b, t)
end

local function ease(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Plays the screws and the panel of the PC on `bench` over SCREW_SECONDS.
local function animatePanel(bench: Instance, opening: boolean)
	local pc = bench:FindFirstChild("BenchPC")
	local panel = pc and pc:FindFirstChild("AccessPanel")
	if not panel or animating[panel] then
		return
	end
	local closed = panel:GetAttribute("ClosedPivot")
	local aside = panel:GetAttribute("AsidePivot")
	if typeof(closed) ~= "CFrame" or typeof(aside) ~= "CFrame" then
		return
	end
	animating[panel] = true
	local start = if opening then closed else aside
	local lifted = closed * CFrame.new(0, 0.35, 0)
	-- Everything relative to the panel pivot; screws also relative to their own seat.
	local loose: { { part: BasePart, offset: CFrame } } = {}
	local screws: { { seat: CFrame, parts: { { part: BasePart, offset: CFrame } } } } = {}
	for _, child in panel:GetChildren() do
		if child.Name == "CaseScrew" and child:IsA("Model") then
			local head = child:FindFirstChild("ScrewHead")
			if head and head:IsA("BasePart") then
				local seat = CFrame.new(start:PointToObjectSpace(head.Position))
				local entry = { seat = seat, parts = {} }
				for _, part in child:GetDescendants() do
					if part:IsA("BasePart") then
						table.insert(entry.parts, { part = part, offset = (start * seat):ToObjectSpace(part.CFrame) })
					end
				end
				table.insert(screws, entry)
			end
		elseif child:IsA("BasePart") then
			table.insert(loose, { part = child, offset = start:ToObjectSpace(child.CFrame) })
		end
	end
	local screwTime = 1.6
	local began = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - began
		if not panel.Parent or t > SCREW_SECONDS + 0.5 then
			connection:Disconnect()
			animating[panel] = nil
			return
		end
		local pivot, screwOut
		if opening then
			screwOut = function(index: number): number
				return ease((t - (index - 1) * screwTime / #screws) / (screwTime / #screws))
			end
			if t < screwTime then
				pivot = closed
			elseif t < screwTime + 0.25 then
				pivot = lerp(closed, lifted, ease((t - screwTime) / 0.25))
			else
				pivot = lerp(lifted, aside, ease((t - screwTime - 0.25) / 0.5))
			end
		else
			if t < 0.5 then
				pivot = lerp(aside, lifted, ease(t / 0.5))
			elseif t < 0.75 then
				pivot = lerp(lifted, closed, ease((t - 0.5) / 0.25))
			else
				pivot = closed
			end
			screwOut = function(index: number): number
				return 1 - ease((t - 0.75 - (index - 1) * screwTime / #screws) / (screwTime / #screws))
			end
		end
		for _, entry in loose do
			entry.part.CFrame = pivot * entry.offset
		end
		for index, screw in screws do
			local out = screwOut(index)
			local turn = screw.seat * CFrame.new(0, out * 0.14, 0) * CFrame.Angles(0, -out * math.pi * 6, 0)
			for _, piece in screw.parts do
				piece.part.CFrame = pivot * turn * piece.offset
			end
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- Swap window

local ui: {
	gui: ScreenGui,
	card: Frame,
	title: TextLabel,
	status: TextLabel,
	power: Frame,
	powerFill: Frame,
	powerText: TextLabel,
	tabs: { [string]: TextButton },
	list: ScrollingFrame,
	scale: UIScale,
}? = nil
local session: { bench: Instance, slot: string, state: any, camera: { [string]: any }, highlight: Highlight? }? = nil

local function shortSlot(slot: string): string
	local names = { CPU = "CPU", Motherboard = "BOARD", RAM = "RAM", GPU = "GPU", Storage = "DRIVE", Cooling = "COOLER", PSU = "POWER", Case = "CASE", Monitor = "MONITOR" }
	return names[slot] or string.upper(slot)
end

local function closeSwap()
	local current = session
	if not current then
		return
	end
	session = nil
	if current.highlight then
		current.highlight:Destroy()
	end
	local camera = workspace.CurrentCamera
	camera.CameraType = current.camera.CameraType
	camera.FieldOfView = current.camera.FieldOfView
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	if ui then
		ui.gui.Enabled = false
	end
end

local function label(parent: Instance, text: string, position: UDim2, size: UDim2, textSize: number): TextLabel
	local item = make("TextLabel", parent, {
		BackgroundTransparency = 1,
		Text = text,
		Position = position,
		Size = size,
		TextSize = textSize,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	Theme.text(item)
	return item
end

local renderSwap: () -> ()

local function highlightSlot()
	local current = session
	if not current then
		return
	end
	local pc = current.bench:FindFirstChild("BenchPC")
	local target = pc and (if current.slot == "Case" then pc:FindFirstChild("Case") else pc:FindFirstChild(current.slot))
	if not current.highlight or not current.highlight.Parent then
		current.highlight = make("Highlight", ui and ui.gui, {
			FillColor = Color3.fromRGB(82, 163, 229),
			OutlineColor = Color3.fromRGB(150, 210, 255),
			FillTransparency = 0.75,
			OutlineTransparency = 0,
			DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		})
	end
	(current.highlight :: Highlight).Adornee = target
end

local function buildUi()
	local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), {
		Name = "PcWorkshop",
		ResetOnSpawn = false,
		DisplayOrder = 30,
		IgnoreGuiInset = true,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local card = make("Frame", gui, {
		Active = true,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.new(0, PANEL_WIDTH, 0, 600),
	})
	Theme.window(card)
	local scale = make("UIScale", card, {})
	local banner = make("Frame", card, {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -24, 0, 48),
		BackgroundColor3 = Color3.fromRGB(56, 78, 75),
		BorderSizePixel = 0,
	})
	Theme.corner(banner, 8)
	local title = label(banner, "WORKBENCH", UDim2.fromOffset(14, 2), UDim2.new(1, -70, 0, 26), 22)
	title.Font = Enum.Font.GothamBlack
	label(banner, "Swap parts, then screw the case shut", UDim2.fromOffset(14, 26), UDim2.new(1, -70, 0, 18), 12)
	local close = make("TextButton", banner, {
		Text = "Done",
		TextSize = 16,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(70, 34),
	})
	Theme.button(close, "Selected")
	close.Activated:Connect(closeSwap)
	local status = label(card, "", UDim2.fromOffset(18, 66), UDim2.new(1, -36, 0, 34), 13)
	local power = make("Frame", card, {
		Position = UDim2.fromOffset(18, 104),
		Size = UDim2.new(1, -36, 0, 22),
		BackgroundColor3 = Color3.fromRGB(29, 29, 29),
		BorderSizePixel = 0,
	})
	Theme.corner(power, 6)
	local powerFill = make("Frame", power, {
		Size = UDim2.fromScale(0.2, 1),
		BackgroundColor3 = Color3.fromRGB(111, 202, 125),
		BorderSizePixel = 0,
	})
	Theme.corner(powerFill, 6)
	local powerText = label(power, "", UDim2.fromOffset(8, 0), UDim2.new(1, -16, 1, 0), 12)
	powerText.ZIndex = 2
	local tabs = {}
	local grid = make("Frame", card, {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 134),
		Size = UDim2.new(1, -36, 0, 104),
	})
	make("UIGridLayout", grid, {
		CellSize = UDim2.new(1 / 3, -6, 0, 30),
		CellPadding = UDim2.fromOffset(8, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	for index, slot in TechCatalog.Slots do
		local tab = make("TextButton", grid, { Text = shortSlot(slot), TextSize = 13, LayoutOrder = index })
		Theme.button(tab, "Normal")
		tab.Activated:Connect(function()
			if session then
				session.slot = slot
				highlightSlot()
				renderSwap()
			end
		end)
		tabs[slot] = tab
	end
	local list = make("ScrollingFrame", card, {
		Position = UDim2.fromOffset(18, 246),
		Size = UDim2.new(1, -36, 1, -262),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 5,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	})
	make("UIListLayout", list, { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	ui = {
		gui = gui,
		card = card,
		title = title,
		status = status,
		power = power,
		powerFill = powerFill,
		powerText = powerText,
		tabs = tabs,
		list = list,
		scale = scale,
	}
	RunService.RenderStepped:Connect(function()
		if gui.Enabled and workspace.CurrentCamera then
			local view = workspace.CurrentCamera.ViewportSize
			scale.Scale = math.min(1, (view.X * 0.55) / PANEL_WIDTH, (view.Y - 32) / 600)
		end
	end)
end

renderSwap = function()
	local current = session
	if not current or not ui then
		return
	end
	local state = current.state
	local parts = state and state.Parts
	if not parts then
		ui.status.Text = "Loading..."
		return
	end
	ui.title.Text = string.upper(state.Name or "WORKBENCH")
	local draw, capacity = TechCatalog.power(parts)
	ui.powerFill.Size = UDim2.fromScale(math.clamp(draw / capacity, 0.02, 1), 1)
	ui.powerFill.BackgroundColor3 = if draw > capacity
		then Color3.fromRGB(238, 107, 111)
		elseif draw > capacity * 0.8 then Color3.fromRGB(240, 196, 60)
		else Color3.fromRGB(111, 202, 125)
	ui.powerText.Text = string.format("POWER %d / %d W%s   ·   BENCH SCORE %d", draw, capacity, if draw > capacity then "  OVERLOADED!" else "", TechCatalog.score(parts))
	if ui.status:GetAttribute("Sticky") ~= true then
		ui.status.Text = if draw > capacity
			then "This power supply can't keep up. Fit a bigger one so the PC doesn't brown out."
			else "Pick a slot, then a part from your parts bin. Buy more at " .. TechCatalog.STORE_NAME .. "."
	end
	for slot, tab in ui.tabs do
		Theme.button(tab, if slot == current.slot then "Selected" else "Normal")
	end
	for _, child in ui.list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local owned = state.Owned or {}
	for index, id in TechCatalog.Order[current.slot] do
		local item = TechCatalog.Items[id]
		local has = item.Price == 0 or owned[id] == true
		local fitted = parts[current.slot] == id
		local row = make("Frame", ui.list, { LayoutOrder = index, Size = UDim2.new(1, -8, 0, 62) })
		Theme.glassPanel(row, true)
		local name = label(row, item.Name, UDim2.fromOffset(10, 6), UDim2.new(1, -140, 0, 22), 16)
		if not has then
			name.TextColor3 = Theme.Colors.Muted
		end
		local detail = item.Spec
		if item.Capacity then
			detail ..= "  ·  supplies " .. item.Capacity .. " W"
		elseif item.Watts and item.Watts > 0 then
			detail ..= "  ·  draws " .. item.Watts .. " W"
		end
		label(row, detail, UDim2.fromOffset(10, 30), UDim2.new(1, -140, 0, 28), 12).TextColor3 = Theme.Colors.Muted
		local button = make("TextButton", row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(118, 34),
			TextSize = 14,
			Text = if fitted then "Fitted" elseif has then "Fit" else money(item.Price),
		})
		Theme.button(button, if fitted then "Selected" elseif has and not busy then "Normal" else "Disabled")
		button.Activated:Connect(function()
			if fitted or busy then
				return
			end
			if not has then
				notice("Buy " .. item.Name .. " at " .. TechCatalog.STORE_NAME .. " first.")
				return
			end
			busy = true
			renderSwap()
			local _, result = request("Swap", current.slot, id)
			busy = false
			if result then
				if session == current and result.State then
					current.state = result.State
				end
				notice(result.Message)
			end
			task.defer(highlightSlot)
			renderSwap()
		end)
	end
end

local function openSwap(bench: Instance)
	if session then
		return
	end
	if not ui then
		buildUi()
	end
	local camera = workspace.CurrentCamera
	session = {
		bench = bench,
		slot = "GPU",
		state = nil,
		camera = { CameraType = camera.CameraType, FieldOfView = camera.FieldOfView },
	}
	local current = session
	local ok, result = request("Get")
	if session ~= current then
		return
	end
	if not ok or not result.State or result.State.State ~= "Open" then
		closeSwap()
		notice("Unscrew the case first.")
		return
	end
	current.state = result.State
	local ui = ui :: any
	ui.gui.Enabled = true
	-- Look down into the open case, with the PC in the free half of the screen.
	local frame = bench:GetAttribute("BenchFrame")
	local pc = bench:FindFirstChild("BenchPC")
	if typeof(frame) == "CFrame" and pc and pc:IsA("Model") then
		local centre = pc:GetBoundingBox().Position
		local eye = centre + frame.ZVector * 3.4 + Vector3.new(0, 3.6, 0) + frame.RightVector * 0.6
		camera.CameraType = Enum.CameraType.Scriptable
		TweenService:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.lookAt(eye, centre + frame.RightVector * 1.1),
			FieldOfView = 55,
		}):Play()
	end
	highlightSlot()
	renderSwap()
end

----------------------------------------------------------------------------------------------------
-- Prompts

type Spot = { kind: string, holder: Instance, model: Instance, primary: ProximityPrompt, secondary: ProximityPrompt? }
local spots: { [Instance]: Spot } = {}

local function ownsHolder(holder: Instance): boolean
	if CollectionService:HasTag(holder, CAFE_TAG) then
		local companyId = holder:GetAttribute("CompanyId")
		return type(companyId) == "string" and companyId ~= "" and companyId == player:GetAttribute("CompanyId")
	end
	return holder:GetAttribute("OwnerUserId") == player.UserId
end

local function setPrompt(prompt: ProximityPrompt?, enabled: boolean, action: string?, hold: number?)
	if not prompt then
		return
	end
	prompt.Enabled = enabled and not busy
	if action then
		prompt.ActionText = action
	end
	prompt.HoldDuration = hold or 0.4
end

local function refresh()
	local carrying = player:GetAttribute("PcCarry")
	local rig = player:GetAttribute("PcRig")
	for model, spot in spots do
		if not model:IsDescendantOf(workspace) then
			spots[model] = nil
			continue
		end
		local mine = ownsHolder(spot.holder)
		if spot.kind == "Desk" then
			if carrying then
				setPrompt(spot.primary, mine, "Put PC down", 0.5)
			else
				setPrompt(spot.primary, mine and rig == nil and model:GetAttribute("PcAway") ~= true, "Pick up PC", 0.6)
			end
		else
			local state = model:GetAttribute("PcState")
			local ours = model:GetAttribute("PcOwner") == player.UserId
			if not mine then
				setPrompt(spot.primary, false)
				setPrompt(spot.secondary, false)
			elseif state == nil then
				setPrompt(spot.primary, carrying ~= nil, "Put PC on bench", 0.4)
				setPrompt(spot.secondary, false)
			elseif not ours or state == "Opening" or state == "Closing" then
				setPrompt(spot.primary, false)
				setPrompt(spot.secondary, false)
			elseif state == "Closed" then
				setPrompt(spot.primary, true, "Unscrew case", 0.5)
				setPrompt(spot.secondary, true, "Pick up PC", 0.5)
			else
				setPrompt(spot.primary, true, "Swap parts", 0)
				setPrompt(spot.secondary, true, "Screw case shut", 0.5)
			end
		end
	end
end

local function run(action: string)
	if busy then
		return
	end
	busy = true
	refresh()
	local _, result = request(action)
	busy = false
	refresh()
	if result then
		notice(result.Message)
	end
end

local function newPrompt(parent: Instance, object: string, key: Enum.KeyCode, pad: Enum.KeyCode, offset: number): ProximityPrompt
	local prompt = make("ProximityPrompt", parent, {
		Name = "PcWorkshopPrompt",
		ObjectText = object,
		KeyboardKeyCode = key,
		GamepadKeyCode = pad,
		MaxActivationDistance = 8,
		RequiresLineOfSight = false,
		Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton,
		UIOffset = Vector2.new(0, offset),
		Enabled = false,
	})
	return prompt
end

local function anchor(model: Instance, world: CFrame): Attachment?
	local host = model:FindFirstChildWhichIsA("BasePart", true)
	if not host then
		return nil
	end
	return make("Attachment", host, { Name = "PcWorkshopAnchor", WorldCFrame = world })
end

local function trackDesk(desk: Instance, holder: Instance)
	if spots[desk] or not desk:IsA("Model") then
		return
	end
	local frame = desk:GetAttribute("DeskFrame")
	if typeof(frame) ~= "CFrame" then
		return
	end
	local point = anchor(desk, frame * CFrame.new(0.4, 3.9, 0.6))
	if not point then
		return
	end
	local prompt = newPrompt(point, "Office PC", Enum.KeyCode.F, Enum.KeyCode.ButtonY, 0)
	local spot: Spot = { kind = "Desk", holder = holder, model = desk, primary = prompt }
	spots[desk] = spot
	prompt.Triggered:Connect(function()
		run(if player:GetAttribute("PcCarry") then "PlaceDesk" else "PickUpDesk")
	end)
	desk:GetAttributeChangedSignal("PcAway"):Connect(refresh)
	refresh()
end

local function trackBench(bench: Instance, holder: Instance)
	if spots[bench] or not bench:IsA("Model") then
		return
	end
	local frame = bench:GetAttribute("BenchFrame")
	if typeof(frame) ~= "CFrame" then
		return
	end
	local point = anchor(bench, frame * CFrame.new(-0.25, 4.6, 1.7))
	if not point then
		return
	end
	local primary = newPrompt(point, "Workbench", Enum.KeyCode.E, Enum.KeyCode.ButtonX, 0)
	local secondary = newPrompt(point, "Workbench", Enum.KeyCode.F, Enum.KeyCode.ButtonY, 70)
	local spot: Spot = { kind = "Bench", holder = holder, model = bench, primary = primary, secondary = secondary }
	spots[bench] = spot
	primary.Triggered:Connect(function()
		local state = bench:GetAttribute("PcState")
		if state == nil then
			run("PlaceBench")
		elseif state == "Closed" then
			run("Open")
		elseif state == "Open" then
			openSwap(bench)
		end
	end)
	secondary.Triggered:Connect(function()
		local state = bench:GetAttribute("PcState")
		if state == "Closed" then
			run("PickUpBench")
		elseif state == "Open" then
			if session and session.bench == bench then
				closeSwap()
			end
			run("Close")
		end
	end)
	local function stateChanged()
		local state = bench:GetAttribute("PcState")
		if state == "Opening" or state == "Closing" then
			animatePanel(bench, state == "Opening")
		end
		if session and session.bench == bench and state ~= "Open" then
			closeSwap()
		end
		refresh()
	end
	bench:GetAttributeChangedSignal("PcState"):Connect(stateChanged)
	bench:GetAttributeChangedSignal("PcOwner"):Connect(refresh)
	-- After a swap the PC is rebuilt: point the highlight at the new parts.
	bench.ChildAdded:Connect(function(child)
		if child.Name == "BenchPC" and session and session.bench == bench then
			task.defer(highlightSlot)
		end
	end)
	refresh()
end

local function consider(item: Instance, holder: Instance)
	if item.Name == "OfficeDesk" then
		trackDesk(item, holder)
	elseif item.Name == "Workbench" and not CollectionService:HasTag(holder, CAFE_TAG) then
		trackBench(item, holder)
	end
end

local watched: { [Instance]: boolean } = {}
local function watchHolder(holder: Instance)
	if watched[holder] then
		return
	end
	watched[holder] = true
	holder:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh)
	holder:GetAttributeChangedSignal("CompanyId"):Connect(refresh)
	holder.DescendantAdded:Connect(function(item)
		if item.Name == "OfficeDesk" or item.Name == "Workbench" then
			-- Attributes are set before parenting, but give streaming a frame to settle.
			task.defer(consider, item, holder)
		end
	end)
	for _, item in holder:GetDescendants() do
		if item.Name == "OfficeDesk" or item.Name == "Workbench" then
			consider(item, holder)
		end
	end
end

function PcWorkshop.start()
	if started then
		return
	end
	started = true
	toastGui = make("ScreenGui", player:WaitForChild("PlayerGui"), {
		Name = "PcWorkshopToast",
		ResetOnSpawn = false,
		DisplayOrder = 31,
		IgnoreGuiInset = true,
	})
	toast = label(toastGui, "", UDim2.fromScale(0.5, 0.8), UDim2.new(0.6, 0, 0, 48), 16)
	toast.AnchorPoint = Vector2.new(0.5, 0.5)
	toast.TextXAlignment = Enum.TextXAlignment.Center
	toast.BackgroundColor3 = Color3.fromRGB(36, 52, 50)
	toast.BackgroundTransparency = 0.1
	toast.Visible = false
	Theme.corner(toast, 8)
	make("UISizeConstraint", toast, { MaxSize = Vector2.new(620, 64) })

	local folder = ReplicatedStorage:WaitForChild("PcWorkshop", 60)
	if not folder then
		warn("[PcWorkshop] The workshop remote never arrived")
		return
	end
	remote = folder:WaitForChild("Request") :: RemoteFunction
	local event = folder:WaitForChild("Notice") :: RemoteEvent
	event.OnClientEvent:Connect(notice)

	for _, tag in { BASE_TAG, CAFE_TAG } do
		for _, holder in CollectionService:GetTagged(tag) do
			watchHolder(holder)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(watchHolder)
	end
	player:GetAttributeChangedSignal("PcCarry"):Connect(refresh)
	player:GetAttributeChangedSignal("PcRig"):Connect(refresh)
	player:GetAttributeChangedSignal("CompanyId"):Connect(refresh)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then
			closeSwap()
		end
	end)
	player.CharacterRemoving:Connect(closeSwap)
	refresh()
end

return PcWorkshop
