-- Shared tile inventory for your backpack, your hand, and your launched boat.
-- The backpack is reachable everywhere; the boat tab requires being aboard. Click a fish to pick it up, turn it with R or
-- right-click while holding, then click the hull to drop it. Right-click a packed fish to lock it. Boat parts rearrange the same way
-- but stay aboard. The server re-checks every move; this view only previews.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Aboard = require(ReplicatedStorage.Shared.Aboard)
local BoatCatalog = require(ReplicatedStorage.Shared.BoatCatalog)
local Backpacks = require(ReplicatedStorage.Shared.BackpackCatalog)
local Cargo = require(ReplicatedStorage.Shared.Cargo)
local Catalog = require(ReplicatedStorage.Shared.AnglerCatalog)
local FishCatch = require(ReplicatedStorage.Shared.FishCatch)
local FishModels = require(ReplicatedStorage.Shared.FishModels)
local FishMutations = require(ReplicatedStorage.Shared.FishMutations)

local CargoHold = {}
local rgb = Color3.fromRGB
local INK = rgb(10, 10, 10)
local HULL = rgb(26, 23, 20)
local HEADER = rgb(92, 36, 34)
local BRONZE = rgb(150, 118, 72)
local CELL_EMPTY = rgb(16, 16, 16)
local DECK = rgb(74, 54, 36)
local RIM = rgb(36, 26, 18)
local CELL_EDGE = rgb(70, 64, 56)
local PART = rgb(96, 100, 104)
local FITS = rgb(84, 192, 92)
local BLOCKED = rgb(226, 72, 60)
local WHITE = rgb(240, 240, 236)
local MUTED = rgb(170, 170, 164)
local CELL = 40
local GAP = 4
local STEP = CELL + GAP
local PAD = 16
local GRID_TOP = 248
-- The boat-only bulk action sits between the tabs and the hold grid.
local MOVE_TOP = 242
local BOAT_GRID_TOP = 284
-- How far the hull planking reaches past the outer cells, and its darker rim.
local DECK_PAD = 6
local RIM_PAD = 10
local started = false

local function make(class: string, parent: Instance?, props: { [string]: any }): any
	local item = Instance.new(class)
	for key, value in props do
		item[key] = value
	end
	item.Parent = parent
	return item
end

local function round(item: GuiObject, radius: number?)
	make("UICorner", item, { CornerRadius = if radius then UDim.new(0, radius) else UDim.new(1, 0) })
end

local function stroke(item: GuiObject, color: Color3, thickness: number)
	return make("UIStroke", item, {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function text(parent: Instance, value: string, props: { [string]: any }): TextLabel
	local label = make("TextLabel", parent, {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = value,
		TextColor3 = WHITE,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	for key, item in props do
		label[key] = item
	end
	return label
end

local function button(parent: Instance, caption: string, props: { [string]: any }): TextButton
	local item = make("TextButton", parent, {
		AutoButtonColor = true,
		BackgroundColor3 = INK,
		Font = Enum.Font.GothamBold,
		Text = caption,
		TextColor3 = WHITE,
		TextSize = 14,
	})
	for key, value in props do
		item[key] = value
	end
	round(item, 4)
	stroke(item, BRONZE, 2)
	return item
end

local function fishKey(record): string
	return string.format("%s|%s|%s", tostring(record.FishId), tostring(record.Kg), tostring(record.CaughtAt))
end

local function itemKey(item): string
	return if item.PartId then string.format("%s@%d,%d", item.PartId, item.X, item.Y) else fishKey(item.Fish)
end

local function shapeOf(item): { string }
	return Cargo.shape(item, Catalog.Fish)
end

-- Draws an item's filled cells inside its rotated bounding box, with the fish
-- model (or the part's name) on top. Returns the box and its cell squares.
local function drawItem(parent: Instance, item, rotation: number): (Frame, { Frame }, ViewportFrame?)
	local cells, width, height = Cargo.cells(shapeOf(item), rotation)
	local box = make("Frame", parent, {
		Name = "Item",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width * STEP - GAP, height * STEP - GAP),
	})
	local species = item.Fish and Catalog.Fish[item.Fish.FishId]
	local rarity = species and Catalog.Rarities[species.Rarity]
	local tint = if item.PartId then PART elseif rarity then rarity.Color else MUTED
	local squares = {}
	for _, cell in cells do
		local square = make("Frame", box, {
			Position = UDim2.fromOffset(cell[1] * STEP, cell[2] * STEP),
			Size = UDim2.fromOffset(CELL, CELL),
			BackgroundColor3 = tint,
			BackgroundTransparency = if item.PartId then 0.15 else 0.62,
			BorderSizePixel = 0,
		})
		round(square, 3)
		table.insert(squares, square)
	end
	local view
	if item.Fish then
		view = make("ViewportFrame", box, {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 2,
		})
		local _, camera = FishModels.show(view, item.Fish.FishId, nil, item.Fish)
		if camera and rotation % 4 ~= 0 then
			-- Rolling the camera turns the fish clockwise with its footprint.
			camera.CFrame *= CFrame.Angles(0, 0, rotation * math.pi / 2)
		end
		if item.Locked then
			text(box, "🔒", {
				Name = "LockIcon",
				Position = UDim2.fromOffset(3, 2),
				Size = UDim2.fromOffset(20, 20),
				TextSize = 16,
				TextStrokeTransparency = 0.2,
				ZIndex = 4,
			})
		end
		text(box, FishCatch.formatKg(item.Fish.Kg), {
			Position = UDim2.new(0, 3, 1, -13),
			Size = UDim2.new(1, -6, 0, 12),
			TextSize = 10,
			Font = Enum.Font.GothamBold,
			TextStrokeTransparency = 0.2,
			ZIndex = 3,
		})
	else
		local part = Cargo.Parts[item.PartId]
		text(box, string.upper(if part then part.Name else item.PartId), {
			Size = UDim2.fromScale(1, 1),
			TextSize = 10,
			Font = Enum.Font.GothamBlack,
			TextColor3 = rgb(226, 226, 220),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 2,
		})
	end
	return box, squares, view
end

function CargoHold.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Cargo")
	local request = remotes:WaitForChild("Request") :: RemoteFunction
	local update = remotes:WaitForChild("Update") :: RemoteEvent

	-- Draw over the full screen; pointer conversion still needs the GUI inset.
	local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), {
		Name = "Cargo",
		ResetOnSpawn = false,
		DisplayOrder = 23,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local toggle = button(gui, "Backpack [C]", {
		Name = "OpenCargo",
		Position = UDim2.new(1, -126, 1, -100),
		Size = UDim2.fromOffset(112, 38),
		TextSize = 14,
	})
	local handDot = make("Frame", toggle, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -3, 0, 3),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = FITS,
		BorderSizePixel = 0,
		Visible = false,
	})
	round(handDot)

	local panel = make("Frame", gui, {
		Name = "CargoPanel",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -20, 0.5, -24),
		Size = UDim2.fromOffset(352, 420),
		BackgroundColor3 = HULL,
		BorderSizePixel = 0,
		Active = true,
		Visible = false,
	})
	round(panel, 4)
	stroke(panel, BRONZE, 3)
	local scale = make("UIScale", panel, {})
	local header = make("Frame", panel, {
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = HEADER,
		BorderSizePixel = 0,
	})
	round(header, 4)
	text(header, "CARGO", {
		Position = UDim2.fromOffset(PAD, 7),
		Size = UDim2.new(1, -PAD * 2 - 40, 0, 24),
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
	})
	local subtitle = text(header, "", {
		Position = UDim2.fromOffset(PAD, 32),
		Size = UDim2.new(1, -PAD * 2, 0, 18),
		TextSize = 13,
		TextColor3 = rgb(226, 206, 196),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local close = make("TextButton", header, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(32, 32),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "×",
		TextColor3 = WHITE,
		TextSize = 28,
	})

	-- The single-fish hand slot and its actions.
	text(panel, "IN HAND", {
		Position = UDim2.fromOffset(PAD, 70),
		Size = UDim2.fromOffset(120, 16),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = MUTED,
	})
	local handSlot = make("TextButton", panel, {
		Name = "Hand",
		AutoButtonColor = false,
		Text = "",
		Position = UDim2.fromOffset(PAD, 90),
		Size = UDim2.fromOffset(100, 100),
		BackgroundColor3 = CELL_EMPTY,
		BorderSizePixel = 0,
	})
	round(handSlot, 4)
	local handStroke = stroke(handSlot, CELL_EDGE, 2)
	local handView = make("ViewportFrame", handSlot, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = false,
	})
	local handEmpty = text(handSlot, "Empty", {
		Size = UDim2.fromScale(1, 1),
		TextColor3 = MUTED,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local handName = text(panel, "", {
		Position = UDim2.fromOffset(PAD + 114, 90),
		Size = UDim2.new(1, -(PAD * 2 + 114), 0, 20),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local handInfo = text(panel, "", {
		Position = UDim2.fromOffset(PAD + 114, 112),
		Size = UDim2.new(1, -(PAD * 2 + 114), 0, 32),
		TextSize = 12,
		TextColor3 = MUTED,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local rotate = button(panel, "Rotate [R]", {
		Position = UDim2.fromOffset(PAD + 114, 154),
		Size = UDim2.fromOffset(96, 34),
		TextSize = 13,
	})
	local release = button(panel, "Release", {
		Position = UDim2.fromOffset(PAD + 218, 154),
		Size = UDim2.fromOffset(84, 34),
		TextSize = 13,
	})

	-- The hold: empty cells, placed items, the held item's ghost and one hit area
	-- on top that turns clicks into grid cells.
	local grid = make("Frame", panel, {
		Name = "Hold",
		Position = UDim2.fromOffset(PAD, GRID_TOP),
		BackgroundTransparency = 1,
	})
	local function layer(zIndex: number): Frame
		return make("Frame", grid, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = zIndex })
	end
	local rimLayer, deckLayer, cellLayer = layer(1), layer(2), layer(3)
	local itemLayer, ghostLayer = layer(4), layer(5)
	local hit = make("TextButton", grid, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 6,
	})
	local noBoat = text(panel, "Climb aboard your own launched boat to use its hold.", {
		Position = UDim2.fromOffset(PAD, GRID_TOP),
		Size = UDim2.new(1, -PAD * 2, 0, 90),
		TextColor3 = MUTED,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local footer = text(panel, "", {
		Position = UDim2.new(0, PAD, 1, -48),
		Size = UDim2.new(1, -PAD * 2, 0, 38),
		TextSize = 12,
		TextColor3 = MUTED,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	local backpackTab =
		button(panel, "Backpack", { Position = UDim2.fromOffset(PAD, 204), Size = UDim2.fromOffset(142, 30) })
	local boatTab =
		button(panel, "Boat hold", { Position = UDim2.fromOffset(PAD + 152, 204), Size = UDim2.fromOffset(142, 30) })
	local moveAll = button(panel, "Move all to backpack", {
		Position = UDim2.fromOffset(PAD, MOVE_TOP),
		Size = UDim2.new(1, -PAD * 2, 0, 30),
		TextSize = 13,
		Visible = false,
	})
	local container = "Backpack"
	local state = {
		Hand = nil,
		BoatId = nil,
		Items = {},
		Backpack = {},
		BackpackId = "Starter",
		Pending = nil,
		Freezer = 0,
		FreezerUsage = 0,
	}
	-- holding = { from = "Hand" | hold index | "Draft", item, r }
	local holding = nil
	-- A motor or rudder reserved at the refit dock, waiting for the player to
	-- choose its tiles. The server owns the reservation; this is its view.
	local draft = nil
	local cancelDraft
	local pending = false
	local lastRequest = -math.huge
	local touchPoint = nil
	local open = false
	local aboard = false
	local builtFor = nil
	-- What the hand slot and the item layer currently show. Every save on the server
	-- refreshes this view (each sale, each coin), and rebuilding every fish model in
	-- its viewport each time was a recurring frame spike, even with the panel shut.
	local drawnHand: string? = nil
	local drawnItems: string? = nil
	local ghost, ghostSquares, ghostView = nil, {}, nil
	local lastAnchor = nil
	local noticeUntil = 0
	local lastHand = ""
	-- The first state (possibly a fish saved in hand last session) never pops the panel open.
	local seeded = false

	local function layout()
		if container == "Backpack" then
			return Backpacks.Items[state.BackpackId] or Backpacks.Items.Starter
		end
		return if aboard and state.BoatId then BoatCatalog[state.BoatId] else nil
	end

	local function contents()
		return if container == "Backpack" then state.Backpack else state.Items
	end

	local render
	local function flash(message: string, color: Color3?)
		noticeUntil = os.clock() + 3
		footer.Text, footer.TextColor3 = message, color or BLOCKED
		task.delay(3.05, function()
			render()
		end)
	end

	local function gridPoint(input: InputObject?): Vector2
		local point
		if input and input.UserInputType == Enum.UserInputType.Touch then
			-- InputObject positions already use the Core UI coordinate system.
			point = Vector2.new(input.Position.X, input.Position.Y)
		elseif not input and UserInputService:GetLastInputType() == Enum.UserInputType.Touch and touchPoint then
			point = touchPoint
		else
			-- Mouse location is in screen coordinates, unlike AbsolutePosition.
			point = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
		end
		return (point - grid.AbsolutePosition) / scale.Scale
	end

	local function anchor(input: InputObject?): (number, number)
		local point = gridPoint(input)
		local _, width, height = Cargo.cells(shapeOf(holding.item), holding.r)
		return math.floor(point.X / STEP - width / 2 + 0.5) + 1, math.floor(point.Y / STEP - height / 2 + 0.5) + 1
	end

	local function takenFor()
		return Cargo.occupied(contents(), Catalog.Fish, if type(holding.from) == "number" then holding.from else nil)
	end

	local function buildGhost()
		if ghost then
			ghost:Destroy()
		end
		ghost, ghostSquares, ghostView, lastAnchor = nil, {}, nil, nil
		if holding and layout() then
			ghost, ghostSquares, ghostView = drawItem(ghostLayer, holding.item, holding.r)
			if ghostView then
				ghostView.ImageTransparency = 0.25
			end
		end
	end

	local function setOpen(value: boolean)
		-- Closing while a refit waits for a spot puts the part back at the dock.
		if not value and draft then
			if not pending then
				cancelDraft(true)
			end
			return
		end
		open = value
		if not open then
			holding = nil
			buildGhost()
		end
		render()
	end

	render = function()
		local spec = layout()
		local handKey = if state.Hand then fishKey(state.Hand) else ""
		if seeded and handKey ~= "" and handKey ~= lastHand and not open then
			-- A fresh catch opens inventory so it can be stowed straight away.
			open = true
		end
		lastHand = handKey
		panel.Visible = open
		toggle.Visible = true
		backpackTab.TextColor3 = if container == "Backpack" then FITS else WHITE
		boatTab.TextColor3 = if container == "Boat" then FITS else MUTED
		boatTab.Text = if aboard then "Boat hold" else "Boat · aboard only"
		handDot.Visible = state.Hand ~= nil

		-- Header line.
		local used, total = 0, 0
		if spec then
			total = Cargo.capacity(spec.Hold)
			for _, item in contents() do
				used += #Cargo.cells(shapeOf(item))
			end
		end
		subtitle.Text = (if spec then string.format("%s · %d/%d cells", spec.Name, used, total) else "No boat")
			.. string.format("  ·  Freezer %d fish · %d%% used", state.Freezer or 0, state.FreezerUsage or 0)

		-- Hand slot.
		local hand = state.Hand
		local handHeld = holding ~= nil and holding.from == "Hand"
		local fittingDraft = draft ~= nil and holding ~= nil and holding.from == "Draft"
		local handDrawing = if open
			then (if hand then fishKey(hand) else "") .. (if fittingDraft then "|" .. draft.PartId else "")
			else nil
		local redrawHand = handDrawing ~= nil and handDrawing ~= drawnHand
		if redrawHand then
			drawnHand = handDrawing
			for _, child in handView:GetChildren() do
				child:Destroy()
			end
		end
		handEmpty.Visible = hand == nil
		if fittingDraft then
			local part = Cargo.Parts[draft.PartId]
			handEmpty.Text = string.upper(if part then part.Name else draft.PartId)
		else
			handEmpty.Text = "Empty"
		end
		if hand then
			if redrawHand then
				FishModels.show(handView, hand.FishId, nil, hand)
			end
			local species = Catalog.Fish[hand.FishId]
			local rarity = species and Catalog.Rarities[species.Rarity]
			handStroke.Color = if rarity then rarity.Color else CELL_EDGE
			local mutation = FishMutations.label(hand.Mutation, hand.NeonColor)
			handName.Text = (if mutation ~= "" then mutation .. " " else "")
				.. (if species then species.Name else hand.FishId)
				.. (if hand.Size == "Huge" then "  HUGE" elseif hand.Size == "Big" then "  BIG" else "")
			handInfo.Text = string.format(
				"%s · $%d · takes %d cells",
				FishCatch.formatKg(hand.Kg),
				math.floor(hand.Value),
				#Cargo.cells(shapeOf(hand))
			)
		elseif fittingDraft then
			local part = Cargo.Parts[draft.PartId]
			handStroke.Color = PART
			handName.Text = if part then part.Name else draft.PartId
			handInfo.Text = string.format("Pick a spot in the hold · takes %d cells", #Cargo.cells(shapeOf(draft)))
		else
			handStroke.Color = CELL_EDGE
			handName.Text = ""
			handInfo.Text = "Stow the fish in your hand to make room for your next catch."
		end
		handView.ImageTransparency = if handHeld then 0.7 else 0
		local holdingFish = holding ~= nil and holding.item.Fish ~= nil
		release.TextTransparency = if holdingFish then 0 else 0.6
		rotate.TextTransparency = if holding then 0 else 0.6

		-- Hold grid.
		noBoat.Visible = spec == nil
		grid.Visible = spec ~= nil
		moveAll.Visible = container == "Boat" and spec ~= nil
		local areaWidth, areaHeight = 300, 90
		if spec then
			local columns = 0
			for _, row in spec.Hold do
				columns = math.max(columns, #row)
			end
			areaWidth, areaHeight = columns * STEP - GAP, #spec.Hold * STEP - GAP
			local layoutKey = container
				.. ":"
				.. tostring(if container == "Backpack" then state.BackpackId else state.BoatId)
			if builtFor ~= layoutKey then
				builtFor = layoutKey
				for _, container in { rimLayer, deckLayer, cellLayer } do
					for _, child in container:GetChildren() do
						child:Destroy()
					end
				end
				for y, row in spec.Hold do
					for x = 1, #row do
						if Cargo.open(spec.Hold, x, y) then
							-- Overlapping planks per cell merge into the hull silhouette.
							for _, plank in { { rimLayer, RIM, RIM_PAD }, { deckLayer, DECK, DECK_PAD } } do
								local tile = make("Frame", plank[1], {
									Position = UDim2.fromOffset((x - 1) * STEP - plank[3], (y - 1) * STEP - plank[3]),
									Size = UDim2.fromOffset(CELL + plank[3] * 2, CELL + plank[3] * 2),
									BackgroundColor3 = plank[2],
									BorderSizePixel = 0,
								})
								round(tile, plank[3])
							end
							local cell = make("Frame", cellLayer, {
								Position = UDim2.fromOffset((x - 1) * STEP, (y - 1) * STEP),
								Size = UDim2.fromOffset(CELL, CELL),
								BackgroundColor3 = CELL_EMPTY,
								BorderSizePixel = 0,
							})
							round(cell, 3)
							stroke(cell, CELL_EDGE, 1)
						end
					end
				end
			end
			local drawing = { layoutKey, if holding then tostring(holding.from) else "" }
			for _, item in contents() do
				table.insert(
					drawing,
					string.format(
						"%s:%s,%s,%s,%s",
						itemKey(item),
						tostring(item.X),
						tostring(item.Y),
						tostring(item.R),
						tostring(item.Locked)
					)
				)
			end
			local itemsKey = if open then table.concat(drawing, ";") else nil
			local redrawItems = itemsKey ~= nil and itemsKey ~= drawnItems
			if redrawItems then
				drawnItems = itemsKey
				for _, child in itemLayer:GetChildren() do
					child:Destroy()
				end
			end
			for index, item in if redrawItems then contents() else {} do
				local box, squares, view = drawItem(itemLayer, item, item.R)
				box.Position = UDim2.fromOffset((item.X - 1) * STEP, (item.Y - 1) * STEP)
				if holding and holding.from == index then
					for _, square in squares do
						square.BackgroundTransparency = 0.88
					end
					if view then
						view.ImageTransparency = 0.75
					end
				end
			end
		end
		local panelWidth = math.max(areaWidth, 320) + PAD * 2
		local gridTop = if container == "Boat" then BOAT_GRID_TOP else GRID_TOP
		grid.Size = UDim2.fromOffset(areaWidth, areaHeight)
		grid.Position = UDim2.fromOffset(math.floor((panelWidth - areaWidth) / 2), gridTop)
		noBoat.Position = UDim2.fromOffset(PAD, gridTop)
		panel.Size = UDim2.fromOffset(panelWidth, gridTop + areaHeight + 62)
		if os.clock() >= noticeUntil then
			if draft and holding and holding.from == "Draft" then
				local part = Cargo.Parts[draft.PartId]
				footer.TextColor3 = FITS
				footer.Text = string.format(
					"Click a tile to fit the %s · R or Rotate to turn · Esc to cancel",
					string.lower(if part then part.Name else draft.PartId)
				)
			else
				footer.TextColor3 = MUTED
				footer.Text = if holding
					then "Click a tile to pack · R or Rotate to turn · Esc to cancel"
					else if container == "Backpack"
						then "Right-click a fish to lock it · Unlocked fish go to the freezer"
						else "Use Move all to fill your backpack, or take a fish in hand for the freezer."
			end
		end
	end

	local function applyState(next)
		if type(next) ~= "table" then
			return
		end
		state = next
		state.Backpack = if type(state.Backpack) == "table" then state.Backpack else {}
		state.Items = if type(state.Items) == "table" then state.Items else {}
		-- Drop whatever is held if the server moved or removed it meanwhile.
		if holding and holding.from ~= "Draft" then
			local source = if holding.from == "Hand"
				then state.Hand and { Fish = state.Hand }
				else contents()[holding.from]
			if not source or itemKey(source) ~= itemKey(holding.item) then
				holding = nil
			end
		end
		-- A reserved refit opens the boat hold with the part under the cursor.
		local nextDraft = if type(state.Pending) == "table" and type(state.Pending.PartId) == "string"
			then state.Pending
			else nil
		if nextDraft then
			local changed = draft == nil or draft.BoatId ~= nextDraft.BoatId or draft.PartId ~= nextDraft.PartId
			draft = nextDraft
			if changed or not holding or holding.from ~= "Draft" then
				container = "Boat"
				open = true
				holding = { from = "Draft", item = { PartId = nextDraft.PartId }, r = 0 }
			end
		elseif draft then
			draft = nil
			if holding and holding.from == "Draft" then
				holding = nil
			end
		end
		buildGhost()
		render()
		seeded = true
	end

	-- Mirrors the server's move so the hold answers instantly; the reply replaces it.
	local function predict(from, to)
		local next = table.clone(state)
		local items = table.clone(contents())
		if container == "Backpack" then
			next.Backpack = items
		else
			next.Items = items
		end
		local item = if from == "Hand" then { Fish = state.Hand } else items[from]
		if not item or (from == "Hand" and not state.Hand) then
			return state
		end
		if type(to) == "table" then
			local placed =
				{ Fish = item.Fish, PartId = item.PartId, Locked = item.Locked, X = to.X, Y = to.Y, R = to.R }
			if from == "Hand" then
				table.insert(items, placed)
				next.Hand = nil
			else
				items[from] = placed
			end
		else
			if from ~= "Hand" then
				table.remove(items, from)
			end
			if to == "Hand" then
				next.Hand = item.Fish
			elseif from == "Hand" then
				next.Hand = nil
			end
		end
		return next
	end

	local function invokeCargo(action, ...)
		-- Space requests from the previous response so the server's rate limit
		-- cannot reject a quick follow-up, regardless of network latency.
		local delay = 0.21 - (os.clock() - lastRequest)
		if delay > 0 then
			task.wait(delay)
		end
		local ok, response = pcall(request.InvokeServer, request, action, ...)
		lastRequest = os.clock()
		return ok, response
	end

	local function send(from, to)
		if pending then
			return
		end
		local previous = state
		local targetContainer = container
		pending = true
		holding = nil
		applyState(predict(from, to))
		task.spawn(function()
			local ok, response = invokeCargo("Move", from, to, targetContainer)
			pending = false
			if ok and type(response) == "table" then
				applyState(response.State or previous)
				if not response.Ok and type(response.Message) == "string" and response.Message ~= "" then
					flash(response.Message)
				end
			else
				applyState(previous)
				flash("Couldn't reach your hold. Try again.")
			end
		end)
	end

	local function placeDraft(x: number, y: number, r: number)
		if pending or not draft then
			return
		end
		pending = true
		local previous = state
		task.spawn(function()
			local ok, response = invokeCargo("Place", x, y, r)
			pending = false
			if ok and type(response) == "table" then
				applyState(response.State or previous)
				if response.Ok then
					draft = nil
					if holding and holding.from == "Draft" then
						holding = nil
					end
					buildGhost()
					setOpen(false)
				elseif type(response.Message) == "string" and response.Message ~= "" then
					flash(response.Message)
				end
			else
				applyState(previous)
				flash("Couldn't reach your hold. Try again.")
			end
		end)
	end

	-- Puts the reserved part back at the dock, then optionally closes the panel.
	cancelDraft = function(closeAfter: boolean)
		if pending or not draft then
			return
		end
		pending = true
		local previous = state
		holding = nil
		buildGhost()
		render()
		task.spawn(function()
			local ok, response = invokeCargo("CancelPlace")
			pending = false
			if ok and type(response) == "table" then
				applyState(response.State or previous)
				if response.Ok then
					draft = nil
					if holding and holding.from == "Draft" then
						holding = nil
					end
					buildGhost()
					if closeAfter then
						setOpen(false)
					else
						render()
					end
				else
					flash(response.Message or "Couldn't cancel that refit.")
				end
			else
				applyState(previous)
				flash("Couldn't reach the dock. Try again.")
			end
		end)
	end

	local function pickUp(from, item, rotation: number)
		if pending then
			return
		end
		holding = { from = from, item = item, r = rotation }
		if from == "Hand" and UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
			touchPoint = nil
		end
		buildGhost()
		render()
	end

	local function cancel()
		if holding then
			holding = nil
			buildGhost()
			render()
		end
	end

	local function turn()
		if holding then
			holding.r = (holding.r + 1) % 4
			buildGhost()
			render()
		end
	end

	local function trackTouch(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			touchPoint = Vector2.new(input.Position.X, input.Position.Y)
		end
	end
	hit.InputBegan:Connect(trackTouch)
	hit.InputChanged:Connect(trackTouch)
	hit.Activated:Connect(function(input)
		local spec = layout()
		if not spec or pending then
			return
		end
		if holding then
			local x, y = anchor(input)
			if holding.from == "Draft" then
				if Cargo.fits(spec.Hold, takenFor(), shapeOf(holding.item), x, y, holding.r) then
					placeDraft(x, y, holding.r)
				else
					flash("It doesn't fit there.")
				end
				return
			end
			if Cargo.fits(spec.Hold, takenFor(), shapeOf(holding.item), x, y, holding.r) then
				send(holding.from, { X = x, Y = y, R = holding.r })
			else
				flash("It doesn't fit there.")
			end
			return
		end
		local point = gridPoint(input)
		local index = Cargo.at(
			Cargo.occupied(contents(), Catalog.Fish),
			math.floor(point.X / STEP) + 1,
			math.floor(point.Y / STEP) + 1
		)
		local item = index and contents()[index]
		if item then
			pickUp(index, item, item.R)
		end
	end)
	hit.MouseButton2Click:Connect(function()
		if holding then
			turn()
			return
		end
		if pending or container ~= "Backpack" then
			return
		end
		local point = gridPoint()
		local index = Cargo.at(
			Cargo.occupied(contents(), Catalog.Fish),
			math.floor(point.X / STEP) + 1,
			math.floor(point.Y / STEP) + 1
		)
		local item = index and contents()[index]
		if not item or not item.Fish then
			return
		end
		pending = true
		local expected =
			{ X = item.X, Y = item.Y, FishId = item.Fish.FishId, Kg = item.Fish.Kg, CaughtAt = item.Fish.CaughtAt }
		task.spawn(function()
			local ok, response = invokeCargo("Lock", index, not item.Locked, expected)
			pending = false
			if ok and type(response) == "table" then
				applyState(response.State or state)
				if not response.Ok then
					flash(response.Message or "Couldn't lock that fish.")
				end
			else
				flash("Couldn't reach your backpack. Try again.")
			end
		end)
	end)
	handSlot.Activated:Connect(function()
		if holding and holding.from == "Draft" then
			setOpen(false)
		elseif holding and holding.from == "Hand" then
			cancel()
		elseif holding then
			if holding.item.PartId then
				flash("Boat parts stay in the hold.")
			elseif state.Hand then
				flash("Your hands are already full.")
			else
				send(holding.from, "Hand")
			end
		elseif state.Hand then
			pickUp("Hand", { Fish = state.Hand }, 0)
		end
	end)
	release.Activated:Connect(function()
		if holding and holding.from == "Draft" then
			flash("Place the part in the hold first.")
		elseif holding and holding.item.Fish then
			send(holding.from, "Release")
		elseif holding then
			flash("Boat parts stay in the hold.")
		else
			flash("Pick up a fish first, then release it.")
		end
	end)
	rotate.Activated:Connect(turn)
	moveAll.Activated:Connect(function()
		if draft then
			flash("Place the reserved part in the hold first.")
			return
		elseif pending or container ~= "Boat" then
			return
		end
		pending = true
		task.spawn(function()
			local ok, response = invokeCargo("MoveAll")
			pending = false
			if ok and type(response) == "table" then
				applyState(response.State or state)
				if type(response.Message) == "string" and response.Message ~= "" then
					flash(response.Message, if response.Ok then FITS else BLOCKED)
				end
			else
				flash("Couldn't reach your hold. Try again.")
			end
		end)
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)
	local function switchContainer(value)
		if pending then
			return
		elseif draft then
			flash("Place the reserved part in the hold first.")
			return
		end
		if value == "Boat" and not aboard then
			flash("Climb aboard your boat to use its hold.")
			return
		end
		holding = nil
		container = value
		buildGhost()
		render()
	end
	backpackTab.Activated:Connect(function()
		switchContainer("Backpack")
	end)
	boatTab.Activated:Connect(function()
		switchContainer("Boat")
	end)
	toggle.Activated:Connect(function()
		setOpen(not open)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.C then
			setOpen(not open)
		elseif open and input.KeyCode == Enum.KeyCode.R then
			turn()
		elseif open and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
			if draft then
				setOpen(false)
			else
				cancel()
			end
		end
	end)

	-- Aboard means sitting in or standing on your own launched boat.
	local nextCheck = 0
	RunService.Heartbeat:Connect(function()
		if os.clock() < nextCheck then
			return
		end
		nextCheck = os.clock() + 0.2
		local boatId = player:GetAttribute("ActiveBoatId")
		local boats = workspace:FindFirstChild("PlayerBoats")
		local boat = if type(boatId) == "string" and boats
			then boats:FindFirstChild(boatId .. "_" .. player.UserId)
			else nil
		local now = Aboard(player.Character, boat)
		if now ~= aboard then
			aboard = now
			if not now and container == "Boat" then
				container = "Backpack"
				holding = nil
				draft = nil
				buildGhost()
			end
			setOpen(open)
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not open then
			return
		end
		local camera = workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize
			scale.Scale = math.clamp(
				math.min((viewport.X - 40) / panel.Size.X.Offset, (viewport.Y - 150) / panel.Size.Y.Offset),
				0.2,
				1
			)
		end
		if ghost and holding then
			ghost.Visible = UserInputService:GetLastInputType() ~= Enum.UserInputType.Touch or touchPoint ~= nil
			local x, y = anchor()
			ghost.Position = UDim2.fromOffset((x - 1) * STEP, (y - 1) * STEP)
			local spot = x * 1000 + y
			if spot ~= lastAnchor then
				lastAnchor = spot
				local spec = layout()
				local fits = spec ~= nil and Cargo.fits(spec.Hold, takenFor(), shapeOf(holding.item), x, y, holding.r)
				for _, square in ghostSquares do
					square.BackgroundColor3 = if fits then FITS else BLOCKED
					square.BackgroundTransparency = 0.35
				end
			end
		end
	end)

	update.OnClientEvent:Connect(function(next)
		if not pending then
			applyState(next)
		end
	end)
	local ok, response = pcall(request.InvokeServer, request, "Get")
	if ok and type(response) == "table" and response.State then
		applyState(response.State)
	else
		render()
	end
end

return CargoHold
