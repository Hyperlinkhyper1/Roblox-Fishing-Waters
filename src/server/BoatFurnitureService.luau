-- Boat furniture at the drydock refit dock. Owners of the Boat Customization pass
-- buy decor with cash (it waits in a stock shared by all their boats) and place
-- it freely on the decks of the boat they have up on the lift. Clients only
-- preview; every purchase and placement is checked here against Shared.
-- BoatFurniture, the lift and a ray down onto the hull, then saved and rebuilt on
-- the hull through BoatService.refit (BoatRefitService's outfitter dresses it).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoatRefitService = require(script.Parent.BoatRefitService)
local BoatService = require(script.Parent.BoatService)
local GamepassService = require(script.Parent.GamepassService)
local BoatCatalog = require(ReplicatedStorage.Shared.BoatCatalog)
local BoatFurniture = require(ReplicatedStorage.Shared.BoatFurniture)

local BoatFurnitureService = {}
local started = false
local requests = {}
-- How far above and below a saved height the ray looks for the deck.
local DECK_ABOVE, DECK_BELOW = 0.75, 1

local function stockOf(angler, itemId: string): number
	local count = angler.BoatFurnitureStock[itemId]
	return if type(count) == "number" then count else 0
end

local function state(player: Player)
	local profile = BoatService.getProfile(player)
	if not profile then
		return { Ready = false }
	end
	local angler = profile.Angler
	local boatId = BoatService.activeBoat(player)
	local layout = boatId and BoatCatalog[boatId]
	local stock = {}
	for itemId, count in angler.BoatFurnitureStock do
		if BoatFurniture.Items[itemId] and type(count) == "number" and count > 0 then
			stock[itemId] = count
		end
	end
	local placed = {}
	for index, entry in (boatId and angler.BoatFurniture[boatId]) or {} do
		if BoatFurniture.entryShape(entry) and BoatFurniture.Items[entry.Id] then
			table.insert(placed, { Index = index, Id = entry.Id, X = entry.X, Y = entry.Y, Z = entry.Z, R = entry.R })
		end
	end
	return {
		Ready = true,
		Owns = player:GetAttribute("OwnsBoatCustomization") == true,
		BoatId = if layout then boatId else nil,
		Limit = if layout then BoatFurniture.limit(layout) else 0,
		Placed = placed,
		Stock = stock,
		Cash = profile.Cash,
	}
end

-- Whether a hull deck lies right under the spot (furniture never stands on air or
-- on other furniture).
local function onDeck(model: Model, x: number, y: number, z: number): boolean
	local root = model.PrimaryPart
	if not root then
		return false
	end
	local furniture = model:FindFirstChild("Furniture")
	local hull = {}
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") and piece ~= root and not (furniture and piece:IsDescendantOf(furniture)) then
			table.insert(hull, piece)
		end
	end
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Include
	parameters.FilterDescendantsInstances = hull
	local up = root.CFrame.UpVector
	local origin = root.CFrame:PointToWorldSpace(Vector3.new(x, y + DECK_ABOVE, z))
	local hit = workspace:Raycast(origin, -up * (DECK_ABOVE + DECK_BELOW), parameters)
	return hit ~= nil and hit.Normal:Dot(up) > 0.6
end

-- The lifted boat and its saved pieces, or nil and a reason.
local function editable(player: Player): (string?, any, Model?, string?)
	if not GamepassService.ownsBoatCustomization(player) then
		return nil, nil, nil, "Boat furniture needs the Boat Customization pass."
	end
	local boatId, layout, model, reason = BoatRefitService.refitBoat(player)
	if not boatId then
		return nil, nil, nil, reason
	end
	return boatId, layout, model, nil
end

local function buy(player: Player, itemId: any): (boolean, string)
	local item = type(itemId) == "string" and BoatFurniture.Items[itemId]
	local profile = BoatService.getProfile(player)
	if not item then
		return false, "Choose a piece of furniture."
	elseif not GamepassService.ownsBoatCustomization(player) then
		return false, "Boat furniture needs the Boat Customization pass."
	elseif not profile then
		return false, "Your progress is still loading. Try again in a moment."
	elseif stockOf(profile.Angler, itemId) >= BoatFurniture.MAX_STOCK then
		return false, "Your furniture store is full of those."
	elseif profile.Cash < item.Price then
		return false, string.format("You need $%d for the %s.", item.Price, string.lower(item.Name))
	end
	local ok, message = BoatService.updateProgress(player, function(current)
		assert(current.Cash >= item.Price, "Furniture purchase changed while saving")
		current.Cash -= item.Price
		current.Angler.Stats.CoinsSpent += item.Price
		current.Angler.BoatFurnitureStock[itemId] = stockOf(current.Angler, itemId) + 1
	end)
	if not ok then
		return false, message
	end
	return true, string.format("Bought a %s. Place it on your boat.", string.lower(item.Name))
end

local function where(args: any): (number?, number?, number?, number?)
	if type(args) ~= "table" then
		return nil
	end
	local x, y, z, r = args.X, args.Y, args.Z, args.R
	if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" or type(r) ~= "number" then
		return nil
	end
	return BoatFurniture.snap(x), math.round(y * 20) / 20, BoatFurniture.snap(z), BoatFurniture.snapRotation(r)
end

local function place(player: Player, args: any): (boolean, string)
	local itemId = type(args) == "table" and args.Id
	local item = type(itemId) == "string" and BoatFurniture.Items[itemId]
	local x, y, z, r = where(args)
	local boatId, layout, model, reason = editable(player)
	local profile = BoatService.getProfile(player)
	if not item then
		return false, "Choose a piece of furniture."
	elseif not boatId then
		return false, reason :: string
	elseif not profile then
		return false, "Your progress is still loading. Try again in a moment."
	elseif not x then
		return false, "That spot isn't on your boat."
	elseif stockOf(profile.Angler, itemId) < 1 then
		return false, "Buy one first."
	end
	local entries = profile.Angler.BoatFurniture[boatId] or {}
	local limit = BoatFurniture.limit(layout)
	if BoatFurniture.placed(entries) >= limit then
		return false, string.format("Your %s holds %d pieces. Store one first.", layout.Name, limit)
	end
	local problem = BoatFurniture.check(layout, itemId, x, y, z, r)
	if problem then
		return false, problem
	elseif not onDeck(model :: Model, x :: number, y :: number, z :: number) then
		return false, "Place it on one of your boat's decks."
	end
	local ok, message = BoatService.updateProgress(player, function(current)
		local angler = current.Angler
		assert(stockOf(angler, itemId) >= 1, "Furniture stock changed while saving")
		local list = angler.BoatFurniture[boatId] or {}
		assert(BoatFurniture.placed(list) < limit, "Furniture changed while saving")
		angler.BoatFurnitureStock[itemId] = stockOf(angler, itemId) - 1
		if angler.BoatFurnitureStock[itemId] <= 0 then
			angler.BoatFurnitureStock[itemId] = nil
		end
		table.insert(list, { Id = itemId, X = x, Y = y, Z = z, R = r })
		angler.BoatFurniture[boatId] = list
	end)
	if not ok then
		return false, message
	end
	BoatService.refit(player)
	return true, item.Name .. " placed."
end

local function entryAt(profile, boatId: string, index: any)
	local list = profile.Angler.BoatFurniture[boatId]
	local entry = type(index) == "number" and list and list[index]
	if entry and BoatFurniture.entryShape(entry) and BoatFurniture.Items[entry.Id] then
		return entry
	end
	return nil
end

local function move(player: Player, args: any): (boolean, string)
	local index = type(args) == "table" and args.Index
	local x, y, z, r = where(args)
	local boatId, layout, model, reason = editable(player)
	local profile = BoatService.getProfile(player)
	if not boatId then
		return false, reason :: string
	elseif not profile then
		return false, "Your progress is still loading. Try again in a moment."
	end
	local entry = entryAt(profile, boatId, index)
	if not entry then
		return false, "That piece isn't on this boat any more."
	elseif not x then
		return false, "That spot isn't on your boat."
	end
	local problem = BoatFurniture.check(layout, entry.Id, x, y, z, r)
	if problem then
		return false, problem
	elseif not onDeck(model :: Model, x :: number, y :: number, z :: number) then
		return false, "Place it on one of your boat's decks."
	end
	local itemId = entry.Id
	local ok, message = BoatService.updateProgress(player, function(current)
		local saved = entryAt(current, boatId, index)
		assert(saved and saved.Id == itemId, "Furniture changed while saving")
		saved.X, saved.Y, saved.Z, saved.R = x, y, z, r
	end)
	if not ok then
		return false, message
	end
	BoatService.refit(player)
	return true, BoatFurniture.Items[itemId].Name .. " moved."
end

-- Takes a piece off the lifted boat and back into the stock. Allowed without the
-- pass, so nothing bought is ever stuck aboard.
local function store(player: Player, args: any): (boolean, string)
	local index = type(args) == "table" and args.Index
	local boatId, _, _, reason = BoatRefitService.refitBoat(player)
	local profile = BoatService.getProfile(player)
	if not boatId then
		return false, reason :: string
	elseif not profile then
		return false, "Your progress is still loading. Try again in a moment."
	end
	local entry = entryAt(profile, boatId, index)
	if not entry then
		return false, "That piece isn't on this boat any more."
	end
	local itemId = entry.Id
	local ok, message = BoatService.updateProgress(player, function(current)
		local list = current.Angler.BoatFurniture[boatId]
		local saved = entryAt(current, boatId, index)
		assert(saved and saved.Id == itemId, "Furniture changed while saving")
		table.remove(list, index)
		current.Angler.BoatFurnitureStock[itemId] = math.min(stockOf(current.Angler, itemId) + 1, BoatFurniture.MAX_STOCK)
	end)
	if not ok then
		return false, message
	end
	BoatService.refit(player)
	return true, BoatFurniture.Items[itemId].Name .. " stored. Place it again any time."
end

local ACTIONS = { Buy = buy, Place = place, Move = move, Store = store }

function BoatFurnitureService.start()
	if started then
		return
	end
	started = true
	local remote = Instance.new("RemoteFunction")
	remote.Name = "BoatFurniture"
	remote.OnServerInvoke = function(player, action, args)
		if action == "Get" then
			-- Warms the pass cache so the menu shows the right lock state.
			GamepassService.ownsBoatCustomization(player)
			return { Ok = true, Message = "", State = state(player) }
		end
		local handler = type(action) == "string" and ACTIONS[action]
		if not handler then
			return { Ok = false, Message = "That isn't available.", State = state(player) }
		end
		if os.clock() - (requests[player] or -math.huge) < 0.25 then
			return { Ok = false, Message = "Please wait a moment and try again.", State = state(player) }
		end
		requests[player] = os.clock()
		local ok, message = handler(player, args)
		return { Ok = ok, Message = message, State = state(player) }
	end
	remote.Parent = ReplicatedStorage
	Players.PlayerRemoving:Connect(function(player)
		requests[player] = nil
	end)
end

return BoatFurnitureService
