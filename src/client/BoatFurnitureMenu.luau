-- Boat furniture at the drydock refit dock: the catalog (opened from the refit
-- menu's FURNITURE button while the hull is up on the lift) and free placement on
-- the hull's decks. A ghost follows the pointer over your own boat; R turns it,
-- click (or PLACE on touch) saves it. Arrange picks placed pieces up to move them
-- or put them back in your store. Without the Boat Customization pass the catalog
-- shows the pass instead. The server checks and saves everything; this module
-- only previews (see BoatFurnitureService).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoatCatalog = require(Shared:WaitForChild("BoatCatalog"))
local BoatFurniture = require(Shared:WaitForChild("BoatFurniture"))
local Gamepasses = require(Shared:WaitForChild("Gamepasses"))

local BoatFurnitureMenu = {}
local started = false
local api: any = nil

local WIDTH, HEIGHT = 960, 430
local CARD_W, CARD_H = 172, 214
local GOLD = Color3.fromRGB(244, 196, 76)
local GOOD = Color3.fromRGB(111, 202, 125)
local BAD = Color3.fromRGB(238, 107, 111)
local ACCENT = Color3.fromRGB(255, 205, 120)
local PLACE_HINT = "Move over your deck · R turn (Shift+R back) · Click place · Esc cancel"
local PICK_HINT = "Click a piece on your boat to pick it up · Esc back"
local MOVE_HINT = "Move it · R turn · Click put down · X put in store · Esc cancel"

function BoatFurnitureMenu.isOpen(): boolean
	return api ~= nil and api.isOpen()
end

function BoatFurnitureMenu.open(onBack: () -> ())
	if api then
		api.open(onBack)
	end
end

function BoatFurnitureMenu.close()
	if api then
		api.close()
	end
end

function BoatFurnitureMenu.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local remote = ReplicatedStorage:WaitForChild("BoatFurniture") :: RemoteFunction
	local cream, muted = Theme.Colors.Text, Theme.Colors.Muted

	local gui = Instance.new("ScreenGui")
	gui.Name = "BoatFurniture"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 24
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
	local function button(parent: Instance, name: string, text: string, position: UDim2, size: UDim2, textSize: number)
		local item = Instance.new("TextButton")
		item.Name = name
		item.Position, item.Size = position, size
		item.Text, item.TextSize = text, textSize
		item.TextWrapped = true
		item.Parent = parent
		Theme.button(item, "Normal")
		return item
	end
	local function enable(item: TextButton, on: boolean, style: string?)
		Theme.button(item, if on then (style or "Normal") else "Disabled")
		item.Active, item.Selectable, item.AutoButtonColor = on, on, on
	end

	-- Catalog window ---------------------------------------------------------
	local window = Instance.new("Frame")
	window.Name = "BoatFurniture"
	window.Active = true
	window.AnchorPoint = Vector2.new(0.5, 1)
	window.Position = UDim2.new(0.5, 0, 1, -16)
	window.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	window.Visible = false
	window.Parent = gui
	Theme.window(window)
	local scale = Instance.new("UIScale")
	scale.Parent = window

	local header = frame(window, "Header", UDim2.fromOffset(14, 14), UDim2.new(1, -28, 0, 64), Color3.new(1, 1, 1))
	Theme.corner(header, 8)
	local wash = Instance.new("UIGradient")
	wash.Rotation = 90
	wash.Color = ColorSequence.new(Color3.fromRGB(42, 70, 96), Color3.fromRGB(22, 36, 50))
	wash.Parent = header
	label(header, "BOAT FURNITURE", UDim2.fromOffset(18, 8), UDim2.fromOffset(300, 18), 13, GOLD)
	local boatName = label(header, "", UDim2.fromOffset(18, 26), UDim2.fromOffset(330, 30), 22, cream)
	local counts = label(header, "", UDim2.new(1, -470, 0, 10), UDim2.fromOffset(170, 44), 15, cream)
	counts.RichText = true
	counts.TextXAlignment = Enum.TextXAlignment.Right
	local arrange = button(header, "ArrangeFurniture", "ARRANGE", UDim2.new(1, -284, 0, 12), UDim2.fromOffset(130, 40), 14)
	local back = button(header, "BackToRefit", "‹ REFITS", UDim2.new(1, -146, 0, 12), UDim2.fromOffset(132, 40), 14)

	local chips = frame(window, "Categories", UDim2.fromOffset(14, 86), UDim2.new(1, -28, 0, 30), Color3.new())
	chips.BackgroundTransparency = 1
	local chipList = Instance.new("UIListLayout")
	chipList.FillDirection = Enum.FillDirection.Horizontal
	chipList.Padding = UDim.new(0, 6)
	chipList.Parent = chips
	local chipButtons = {}
	local category = "All"

	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Items"
	grid.Position = UDim2.fromOffset(14, 124)
	grid.Size = UDim2.new(1, -28, 1, -174)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.Parent = window
	pcall(Theme.scroll, grid)
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(CARD_W, CARD_H)
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingTop = UDim.new(0, 2)
	padding.Parent = grid

	local status = label(window, "", UDim2.fromOffset(24, HEIGHT - 42), UDim2.new(1, -48, 0, 30), 13, muted)
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.Font = Enum.Font.GothamMedium

	-- Pass lock: covers the catalog for players without the gamepass.
	local lock = frame(window, "PassLock", UDim2.fromOffset(14, 86), UDim2.new(1, -28, 1, -136), Color3.fromRGB(16, 26, 38))
	lock.BackgroundTransparency = 0.08
	lock.ZIndex = 5
	Theme.corner(lock, 10)
	local lockTitle = label(lock, "BOAT CUSTOMIZATION PASS", UDim2.new(0, 0, 0, 34), UDim2.new(1, 0, 0, 32), 26, ACCENT)
	lockTitle.TextXAlignment = Enum.TextXAlignment.Center
	lockTitle.ZIndex = 6
	local lockText = label(
		lock,
		string.format(
			"Unlock %d pieces of boat furniture — deck chairs, lanterns, palms, a hot tub and more — and place them anywhere on your decks. Furniture costs in-game cash and moves between all your boats.",
			#BoatFurniture.Order
		),
		UDim2.new(0.5, -300, 0, 78),
		UDim2.fromOffset(600, 70),
		15,
		cream
	)
	lockText.TextXAlignment = Enum.TextXAlignment.Center
	lockText.ZIndex = 6
	local unlock = button(lock, "UnlockBoatCustomization", "GET THE PASS", UDim2.new(0.5, -120, 0, 162), UDim2.fromOffset(240, 48), 18)
	unlock.ZIndex = 6
	Theme.button(unlock, "Selected")
	local lockShowcase = frame(lock, "Showcase", UDim2.new(0.5, -270, 0, 216), UDim2.fromOffset(540, 0), Color3.new())
	lockShowcase.BackgroundTransparency = 1

	-- Placement bar ----------------------------------------------------------
	local bar = Instance.new("Frame")
	bar.Name = "FurniturePlacement"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -20)
	bar.Size = UDim2.fromOffset(640, 108)
	bar.Visible = false
	bar.Parent = gui
	Theme.window(bar)
	local barScale = Instance.new("UIScale")
	barScale.Parent = bar
	local barTitle = label(bar, "", UDim2.fromOffset(16, 8), UDim2.new(1, -32, 0, 22), 17, cream)
	local barHint = label(bar, PLACE_HINT, UDim2.fromOffset(16, 30), UDim2.new(1, -32, 0, 20), 12, muted)
	barHint.Font = Enum.Font.GothamMedium
	local rotate = button(bar, "RotateFurniture", "TURN ↻", UDim2.fromOffset(16, 58), UDim2.fromOffset(140, 38), 14)
	local confirm = button(bar, "PlaceFurniture", "PLACE", UDim2.fromOffset(166, 58), UDim2.fromOffset(150, 38), 15)
	local storeButton = button(bar, "StoreFurniture", "PUT IN STORE", UDim2.fromOffset(326, 58), UDim2.fromOffset(150, 38), 14)
	local cancel = button(bar, "CancelFurniture", "CANCEL", UDim2.fromOffset(486, 58), UDim2.fromOffset(138, 38), 14)
	Theme.button(cancel, "Danger")

	-- State --------------------------------------------------------------------
	local snapshot: any = nil
	local onBack: (() -> ())? = nil
	local busy = false
	local lastRequest = -math.huge
	-- Placement: nil, or { kind = "place" | "pick" | "move", id, index, r }
	local mode: any = nil
	local ghost: Model? = nil
	local highlight: Highlight? = nil
	local hoverHighlight: Highlight? = nil
	local pointer: Vector2? = nil
	local aim: any = nil -- last ghost spot: { x, y, z, r, valid }
	local hidden: Model? = nil -- the placed piece being moved, hidden locally

	local function setStatus(message: string, color: Color3?)
		status.Text = message
		status.TextColor3 = color or muted
		if bar.Visible then
			barHint.Text = message
			barHint.TextColor3 = color or muted
		end
	end

	local function ownBoat(): (Model?, BasePart?)
		local id = player:GetAttribute("ActiveBoatId")
		local boats = workspace:FindFirstChild("PlayerBoats")
		local boat = if type(id) == "string" and boats then boats:FindFirstChild(id .. "_" .. player.UserId) else nil
		if boat and boat:IsA("Model") and boat.PrimaryPart then
			return boat, boat.PrimaryPart
		end
		return nil, nil
	end

	local function layoutNow()
		local boatId = snapshot and snapshot.BoatId
		return if boatId then BoatCatalog[boatId] else nil
	end

	-- Cards ----------------------------------------------------------------------
	local cards = {}
	local previewsBuilt = false
	for index, itemId in BoatFurniture.Order do
		local item = BoatFurniture.Items[itemId]
		local card = frame(grid, itemId, UDim2.new(), UDim2.new(), Theme.Colors.Panel)
		card.LayoutOrder = index
		Theme.panel(card, false, 8)
		local view = Instance.new("ViewportFrame")
		view.Name = "Preview"
		view.Position = UDim2.fromOffset(6, 6)
		view.Size = UDim2.new(1, -12, 0, 98)
		view.BackgroundColor3 = Theme.Colors.Inset
		view.BackgroundTransparency = 0.2
		view.Ambient = Color3.fromRGB(170, 170, 170)
		view.LightColor = Color3.fromRGB(255, 244, 228)
		view.LightDirection = Vector3.new(-0.4, -1, 0.6)
		view.Parent = card
		Theme.corner(view, 6)
		local name = label(card, item.Name, UDim2.fromOffset(10, 108), UDim2.new(1, -20, 0, 18), 14, cream)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local info = label(card, "", UDim2.fromOffset(10, 126), UDim2.new(1, -20, 0, 34), 11, muted)
		info.Font = Enum.Font.GothamMedium
		info.TextYAlignment = Enum.TextYAlignment.Top
		info.RichText = true
		local buy = button(card, "Buy" .. itemId, "", UDim2.fromOffset(8, 166), UDim2.new(0.5, -11, 0, 38), 13)
		local place = button(card, "Place" .. itemId, "PLACE", UDim2.new(0.5, 3, 0, 166), UDim2.new(0.5, -11, 0, 38), 13)
		cards[itemId] = { card = card, view = view, info = info, buy = buy, place = place }
	end

	local function buildPreviews()
		if previewsBuilt then
			return
		end
		previewsBuilt = true
		for itemId, card in cards do
			pcall(BoatFurniture.preview, card.view, itemId)
		end
		-- A row of showcase pieces on the pass lock.
		for index, itemId in { "DeckChair", "PalmPlanter", "HotTub", "StandingLantern", "FightingChair" } do
			local view = Instance.new("ViewportFrame")
			view.BackgroundTransparency = 1
			view.Position = UDim2.fromOffset((index - 1) * 108, 0)
			view.Size = UDim2.fromOffset(104, 104)
			view.ZIndex = 6
			view.Ambient = Color3.fromRGB(170, 170, 170)
			view.Parent = lockShowcase
			pcall(BoatFurniture.preview, view, itemId)
		end
		lockShowcase.Size = UDim2.fromOffset(540, 104)
	end

	for _, entry in BoatFurniture.Categories do
		local chip = button(chips, "Category" .. entry.Id, entry.Name, UDim2.new(), UDim2.fromOffset(98, 30), 12)
		chipButtons[entry.Id] = chip
		chip.Activated:Connect(function()
			category = entry.Id
			api.render()
		end)
	end

	local function render()
		local layoutSpec = layoutNow()
		local owns = snapshot ~= nil and snapshot.Owns == true
		local stock = (snapshot and snapshot.Stock) or {}
		local placed = (snapshot and snapshot.Placed) or {}
		local limit = (snapshot and snapshot.Limit) or 0
		local cash = if snapshot and type(snapshot.Cash) == "number" then snapshot.Cash else 0
		boatName.Text = if layoutSpec then layoutSpec.Name else "Put a boat up on the lift"
		counts.Text = if layoutSpec
			then string.format(
				'%d <font color="#9a9a9a">/ %d placed</font>\n<font color="#9ad08f">$%d</font>',
				#placed,
				limit,
				cash
			)
			else ""
		lock.Visible = snapshot ~= nil and not owns
		enable(arrange, owns and layoutSpec ~= nil and #placed > 0 and not busy)
		enable(back, true)
		for id, chip in chipButtons do
			Theme.button(chip, if id == category then "Selected" else "Normal")
		end
		local full = #placed >= limit
		for itemId, card in cards do
			local item = BoatFurniture.Items[itemId]
			card.card.Visible = BoatFurniture.matchesCategory(itemId, category)
			local have = stock[itemId] or 0
			local aboard = 0
			for _, entry in placed do
				if entry.Id == itemId then
					aboard += 1
				end
			end
			card.info.Text = string.format(
				'<font color="#9ad08f">%d in store</font>%s\n%s',
				have,
				if aboard > 0 then string.format(" · %d aboard", aboard) else "",
				item.Description
			)
			local canBuy = owns and not busy and cash >= item.Price
			card.buy.Text = if cash >= item.Price or not owns
				then string.format("BUY $%d", item.Price)
				else string.format("$%d", item.Price)
			enable(card.buy, canBuy, "Selected")
			local canPlace = owns and not busy and layoutSpec ~= nil and have > 0 and not full
			card.place.Text = if full and have > 0 then "BOAT FULL" else "PLACE"
			enable(card.place, canPlace)
		end
	end

	local fetchId = 0
	local function fetch()
		fetchId += 1
		local id = fetchId
		task.spawn(function()
			local ok, result = pcall(remote.InvokeServer, remote, "Get")
			if id == fetchId and ok and type(result) == "table" and type(result.State) == "table" then
				snapshot = result.State
				render()
			end
		end)
	end

	-- Sends an action; `done(ok)` runs after the server answers.
	local function send(action: string, args: any, done: ((boolean) -> ())?)
		if busy or os.clock() - lastRequest < 0.3 then
			return
		end
		busy, lastRequest = true, os.clock()
		fetchId += 1
		render()
		task.spawn(function()
			local ok, result = pcall(remote.InvokeServer, remote, action, args)
			busy = false
			local success = ok and type(result) == "table" and result.Ok == true
			if ok and type(result) == "table" then
				if type(result.State) == "table" then
					snapshot = result.State
				end
				setStatus(tostring(result.Message), if success then GOOD else BAD)
			else
				setStatus("The drydock didn't answer. Please try again.", BAD)
			end
			render()
			if done then
				done(success)
			end
		end)
	end

	-- Placement ----------------------------------------------------------------
	local function hullParts(boat: Model): { Instance }
		local furniture = boat:FindFirstChild("Furniture")
		local parts = {}
		for _, piece in boat:GetDescendants() do
			if piece:IsA("BasePart") and piece ~= boat.PrimaryPart and not (furniture and piece:IsDescendantOf(furniture)) then
				table.insert(parts, piece)
			end
		end
		return parts
	end

	local function setHidden(model: Model?)
		if hidden and hidden ~= model then
			for _, piece in hidden:GetDescendants() do
				if piece:IsA("BasePart") then
					piece.LocalTransparencyModifier = 0
				end
			end
		end
		hidden = model
		if model then
			for _, piece in model:GetDescendants() do
				if piece:IsA("BasePart") then
					piece.LocalTransparencyModifier = 1
				end
			end
		end
	end

	local function clearGhost()
		if ghost then
			ghost:Destroy()
			ghost = nil
		end
		highlight = nil
		aim = nil
	end

	local function makeGhost(itemId: string)
		clearGhost()
		local camera = workspace.CurrentCamera
		ghost = BoatFurniture.build(camera, CFrame.new(0, -10000, 0), itemId, { ghost = true })
		if ghost then
			local glow = Instance.new("Highlight")
			glow.DepthMode = Enum.HighlightDepthMode.Occluded
			glow.FillTransparency = 0.55
			glow.OutlineTransparency = 0.2
			glow.Parent = ghost
			highlight = glow
		end
	end

	local hullCache: { Instance } = {}
	local hullAt = 0
	local function exitPlacement(reopen: boolean)
		mode = nil
		clearGhost()
		setHidden(nil)
		if hoverHighlight then
			hoverHighlight.Adornee = nil
		end
		bar.Visible = false
		pointer = nil
		if reopen and onBack ~= nil then
			window.Visible = true
			render()
		end
	end

	local function updateBar()
		if not mode then
			return
		end
		local item = mode.id and BoatFurniture.Items[mode.id]
		barTitle.Text = if mode.kind == "pick"
			then "Arrange your furniture"
			elseif mode.kind == "move" then "Moving: " .. item.Name
			else "Placing: " .. item.Name
		barHint.Text = if mode.kind == "pick" then PICK_HINT elseif mode.kind == "move" then MOVE_HINT else PLACE_HINT
		barHint.TextColor3 = muted
		rotate.Visible = mode.kind ~= "pick"
		confirm.Visible = mode.kind ~= "pick"
		confirm.Text = if mode.kind == "move" then "PUT DOWN" else "PLACE"
		storeButton.Visible = mode.kind == "move"
	end

	local function enterPlacement(kind: string, itemId: string?, index: number?, r: number?)
		window.Visible = false
		mode = { kind = kind, id = itemId, index = index, r = r or 0 }
		hullAt = 0
		if itemId then
			makeGhost(itemId)
		else
			clearGhost()
		end
		bar.Visible = true
		updateBar()
	end

	local function commit()
		if not mode or busy then
			return
		end
		if mode.kind == "pick" then
			return
		end
		if not aim or not aim.valid then
			setStatus(if aim and aim.reason then aim.reason else "Point at a free spot on your deck.", BAD)
			return
		end
		local args = { Id = mode.id, Index = mode.index, X = aim.x, Y = aim.y, Z = aim.z, R = aim.r }
		local current = mode
		send(if current.kind == "move" then "Move" else "Place", args, function(ok)
			if mode ~= current then
				return
			end
			if not ok then
				return
			end
			-- Keep placing while more of the same piece waits in the store.
			local left = snapshot and snapshot.Stock and snapshot.Stock[current.id] or 0
			local room = snapshot and #(snapshot.Placed or {}) < (snapshot.Limit or 0)
			if current.kind == "place" and left > 0 and room then
				barTitle.Text = string.format("Placing: %s (%d left)", BoatFurniture.Items[current.id].Name, left)
				return
			end
			exitPlacement(true)
		end)
	end

	local function storePicked()
		if not mode or mode.kind ~= "move" or busy then
			return
		end
		send("Store", { Index = mode.index }, function(ok)
			if ok then
				exitPlacement(true)
			end
		end)
	end

	local function turn(by: number)
		if mode and mode.kind ~= "pick" then
			mode.r = (mode.r + by) % 360
		end
	end

	-- The placed piece under the pointer, in arrange mode.
	local function pieceAt(screen: Vector2): (Model?, number?)
		local boat = ownBoat()
		local furniture = boat and boat:FindFirstChild("Furniture")
		local camera = workspace.CurrentCamera
		if not furniture or not camera then
			return nil, nil
		end
		local ray = camera:ViewportPointToRay(screen.X, screen.Y)
		local parameters = RaycastParams.new()
		parameters.FilterType = Enum.RaycastFilterType.Include
		parameters.FilterDescendantsInstances = { furniture }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, parameters)
		local node = hit and hit.Instance
		while node and node ~= furniture do
			if node:IsA("Model") and type(node:GetAttribute("Index")) == "number" then
				return node, node:GetAttribute("Index")
			end
			node = node.Parent
		end
		return nil, nil
	end

	local function pick(screen: Vector2)
		local model, index = pieceAt(screen)
		if not model or not index then
			return
		end
		local entry
		for _, each in (snapshot and snapshot.Placed) or {} do
			if each.Index == index then
				entry = each
			end
		end
		if not entry then
			return
		end
		if hoverHighlight then
			hoverHighlight.Adornee = nil
		end
		setHidden(model)
		enterPlacement("move", entry.Id, index, entry.R)
	end

	local function pointerPosition(): Vector2?
		if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
			return pointer
		end
		return UserInputService:GetMouseLocation()
	end

	hoverHighlight = Instance.new("Highlight")
	hoverHighlight.FillTransparency = 0.7
	hoverHighlight.FillColor = ACCENT
	hoverHighlight.OutlineColor = ACCENT
	hoverHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hoverHighlight.Parent = gui

	RunService.RenderStepped:Connect(function()
		if not mode then
			return
		end
		local boat, root = ownBoat()
		local camera = workspace.CurrentCamera
		local screen = pointerPosition()
		if not boat or not root or not camera then
			return
		end
		if mode.kind == "pick" then
			local model = if screen then pieceAt(screen) else nil
			hoverHighlight.Adornee = model
			return
		end
		if not ghost then
			return
		end
		if os.clock() - hullAt > 1 then
			hullCache = hullParts(boat)
			hullAt = os.clock()
		end
		local valid, reason = false, "Point at your boat's deck."
		local spot = aim
		if screen then
			local ray = camera:ViewportPointToRay(screen.X, screen.Y)
			local parameters = RaycastParams.new()
			parameters.FilterType = Enum.RaycastFilterType.Include
			parameters.FilterDescendantsInstances = hullCache
			local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, parameters)
			if hit then
				local up = root.CFrame.UpVector
				local at = root.CFrame:PointToObjectSpace(hit.Position)
				spot = {
					x = BoatFurniture.snap(at.X),
					y = math.round(at.Y * 20) / 20,
					z = BoatFurniture.snap(at.Z),
					r = BoatFurniture.snapRotation(mode.r),
				}
				if hit.Normal:Dot(up) <= 0.6 then
					reason = "That's not flat deck."
				else
					local problem = BoatFurniture.check(layoutNow(), mode.id, spot.x, spot.y, spot.z, spot.r)
					local placed = snapshot and #(snapshot.Placed or {}) or 0
					if problem then
						reason = problem
					elseif mode.kind == "place" and snapshot and placed >= (snapshot.Limit or 0) then
						reason = "Your boat is full. Store a piece first."
					else
						valid, reason = true, nil
					end
				end
			elseif spot then
				spot = table.clone(spot)
				spot.r = BoatFurniture.snapRotation(mode.r)
			end
		end
		if spot then
			spot.valid, spot.reason = valid, reason
			aim = spot
			ghost:PivotTo(root.CFrame * BoatFurniture.localFrame({ X = spot.x, Y = spot.y, Z = spot.z, R = spot.r }))
		end
		if highlight then
			local color = if valid then GOOD else BAD
			highlight.FillColor, highlight.OutlineColor = color, color
		end
		enable(confirm, valid and not busy, "Selected")
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not mode and not window.Visible then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.Escape or key == Enum.KeyCode.ButtonB then
			-- Deferred: the refit menu's own Esc handler runs in this same dispatch
			-- and must still see the furniture menu open, or it lowers the boat.
			if mode then
				task.defer(exitPlacement, true)
			elseif window.Visible then
				task.defer(api.back)
			end
			return
		end
		if not mode or processed then
			return
		end
		if key == Enum.KeyCode.R then
			local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
				or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
			turn(if shift then -BoatFurniture.ROTATION_STEP else BoatFurniture.ROTATION_STEP)
		elseif key == Enum.KeyCode.X or key == Enum.KeyCode.Delete then
			storePicked()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			local screen = UserInputService:GetMouseLocation()
			if mode.kind == "pick" then
				pick(screen)
			else
				commit()
			end
		elseif input.UserInputType == Enum.UserInputType.Touch then
			pointer = Vector2.new(input.Position.X, input.Position.Y)
			if mode.kind == "pick" then
				pick(pointer)
			end
		end
	end)
	UserInputService.InputChanged:Connect(function(input, processed)
		if mode and not processed and input.UserInputType == Enum.UserInputType.Touch then
			pointer = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	rotate.Activated:Connect(function()
		turn(45)
	end)
	confirm.Activated:Connect(commit)
	storeButton.Activated:Connect(storePicked)
	cancel.Activated:Connect(function()
		exitPlacement(true)
	end)
	arrange.Activated:Connect(function()
		if arrange.Active then
			enterPlacement("pick")
		end
	end)
	unlock.Activated:Connect(function()
		pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, Gamepasses.BoatCustomization.Id)
	end)
	for itemId, card in cards do
		card.buy.Activated:Connect(function()
			if card.buy.Active then
				send("Buy", itemId)
			end
		end)
		card.place.Activated:Connect(function()
			if card.place.Active then
				setStatus("", muted)
				enterPlacement("place", itemId, nil, 0)
			end
		end)
	end

	player:GetAttributeChangedSignal("OwnsBoatCustomization"):Connect(function()
		if window.Visible then
			fetch()
		end
	end)
	-- Any save (cash spent elsewhere, the hull re-dressed) refreshes the numbers.
	player:GetAttributeChangedSignal("AnglerRevision"):Connect(function()
		if (window.Visible or mode) and not busy then
			fetch()
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
			local size = camera.ViewportSize
			scale.Scale = math.max(0.4, math.min(1, (size.X - 24) / WIDTH, size.Y * 0.66 / HEIGHT))
			barScale.Scale = math.max(0.5, math.min(1, (size.X - 24) / 640))
		end
	end)

	api = {}
	api.render = render
	function api.isOpen()
		return window.Visible or mode ~= nil
	end
	function api.open(callback)
		onBack = callback
		buildPreviews()
		exitPlacement(false)
		category = category or "All"
		setStatus("Buy furniture with cash, then place it anywhere on your decks.", muted)
		window.Visible = true
		render()
		fetch()
	end
	function api.close()
		exitPlacement(false)
		window.Visible = false
		onBack = nil
	end
	function api.back()
		local callback = onBack
		api.close()
		if callback then
			callback()
		end
	end
	back.Activated:Connect(api.back)
end

return BoatFurnitureMenu
