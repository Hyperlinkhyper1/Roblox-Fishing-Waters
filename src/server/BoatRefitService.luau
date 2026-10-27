-- Refits on the drydock lift. Owners sail their launched boat over the underwater
-- cradle behind the boat shop; it lifts the hull into the dry basin, where they
-- fit extra motors and rudders, which are boat parts that take up cargo tiles
-- (see Shared.BoatUpgrades), repaint the hull in a preset colour, or buy the
-- trawler's stern net. Clients only display; every change is checked here against
-- the saved hold and the lift, and BoatService drives the hull with the tuned spec.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnglerData = require(script.Parent.AnglerData)
local BoatService = require(script.Parent.BoatService)
local DrydockLaunch = require(script.Parent.DrydockLaunch)
local TrawlerNetService = require(script.Parent.TrawlerNetService)
local Aboard = require(ReplicatedStorage.Shared.Aboard)
local BoatCatalog = require(ReplicatedStorage.Shared.BoatCatalog)
local BoatUpgrades = require(ReplicatedStorage.Shared.BoatUpgrades)
local Catalog = require(ReplicatedStorage.Shared.AnglerCatalog)

local BoatRefitService = {}
local DOCK_TAG = "RefitDock"
local started = false
local requests = {}

-- Hull facets that can take paint. Decks, cabins, rails and trim keep their colours.
local HULL = {
	HullPanel = true,
	HullPlank = true,
	BilgePanel = true,
	BottomPanel = true,
	HullEndCap = true,
	BowCap = true,
	BowStem = true,
	Transom = true,
	TransomTrim = true,
	TransomCap = true,
}

-- Each facet keeps its builder colour in FactoryColor, so repainting never
-- compounds and the factory finish can always come back. The colour covering the
-- most side panel is the hull's own and takes the paint; stripes keep theirs.
-- Planked hulls change colour board by board, so every plank takes the paint at
-- its own shade.
function BoatRefitService.paint(model: Model, paintId: string?)
	local preset = BoatUpgrades.paint(paintId)
	local rgb = preset and preset.RGB
	local id = if rgb then preset.Id else nil
	if model:GetAttribute("Paint") == id then
		return
	end
	local hull, areas, lightest = {}, {}, 0
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") and HULL[piece.Name] then
			local factory = piece:GetAttribute("FactoryColor")
			if typeof(factory) ~= "Color3" then
				factory = piece.Color
				piece:SetAttribute("FactoryColor", factory)
			end
			table.insert(hull, piece)
			if piece.Name == "HullPanel" then
				local key = factory:ToHex()
				areas[key] = (areas[key] or 0) + piece.Size.Y * piece.Size.Z
			elseif piece.Name == "HullPlank" then
				lightest = math.max(lightest, factory.R + factory.G + factory.B)
			end
		end
	end
	local main, largest = nil, 0
	for key, area in areas do
		if area > largest then
			main, largest = key, area
		end
	end
	local color = if rgb then Color3.fromRGB(rgb[1], rgb[2], rgb[3]) else nil
	for _, piece in hull do
		local factory = piece:GetAttribute("FactoryColor")
		if not color then
			piece.Color = factory
		elseif piece.Name == "HullPlank" and lightest > 0 then
			piece.Color = color:Lerp(Color3.new(), 1 - (factory.R + factory.G + factory.B) / lightest)
		elseif factory:ToHex() == main then
			piece.Color = color
		end
	end
	model:SetAttribute("Paint", id)
end

-- The drydock whose lift the hull floats over, if any.
local function dockUnder(model: Model?): Model?
	local root = model and model.PrimaryPart
	if not root then
		return nil
	end
	for _, dock in CollectionService:GetTagged(DOCK_TAG) do
		if dock:IsA("Model") and dock:IsDescendantOf(workspace) and BoatUpgrades.inSlip(dock, root.Position) then
			return dock
		end
	end
	return nil
end

-- Hulls up on a lift, by owner: { model, lift } (lift is nil while it rises).
local lifted = {}

local function lower(player: Player)
	local entry = lifted[player]
	-- A refit waiting for a spot is dropped with the hull; nothing is saved.
	player:SetAttribute("RefitPending", nil)
	if not entry then
		return
	elseif not entry.lift then
		-- Still rising; it comes back down as soon as it is up.
		entry.cancelled = true
		return
	end
	DrydockLaunch.lower(entry.lift)
	if lifted[player] == entry then
		lifted[player] = nil
	end
end

-- Sails the boat onto the lift: the hull must float over it with its owner aboard.
local function raise(player: Player): (boolean, string)
	local boatId, model = BoatService.activeBoat(player)
	local layout = boatId and BoatCatalog[boatId]
	local dock = dockUnder(model)
	if lifted[player] then
		return false, "Your boat is already on the lift."
	elseif not layout or not model then
		return false, "Launch one of your boats and sail it over the drydock lift."
	elseif not dock then
		return false, "Sail your boat over the drydock lift first."
	elseif not Aboard(player.Character, model) then
		return false, "Climb aboard your boat first."
	end
	local entry = { model = model }
	lifted[player] = entry
	-- The stern net always comes in before the hull leaves the water.
	TrawlerNetService.stow(model)
	local lift, reason = DrydockLaunch.lift(dock, player, model, function(height)
		BoatService.hoist(player, height)
	end)
	if not lift then
		lifted[player] = nil
		return false, reason
	end
	entry.lift = lift
	if entry.cancelled or player.Parent ~= Players or not model.Parent then
		lower(player)
		return false, "The lift went back down."
	end
	-- Set the hull back afloat if it disappears or its owner leaves.
	task.spawn(function()
		while lifted[player] == entry do
			if player.Parent ~= Players or not model.Parent then
				lower(player)
				break
			end
			task.wait(0.5)
		end
	end)
	return true, "Your " .. layout.Name .. " is up on the lift."
end

-- The boat the player may refit: up on the lift with its owner aboard.
local function refitBoat(player: Player): (string?, any, Model?, string?)
	local boatId, model = BoatService.activeBoat(player)
	local layout = boatId and BoatCatalog[boatId]
	local entry = lifted[player]
	if not layout or not model then
		return nil, nil, nil, "Launch one of your boats and sail it over the drydock lift."
	elseif not entry or not entry.lift or entry.model ~= model then
		return nil, nil, nil, "Sail your boat over the drydock lift first."
	elseif not Aboard(player.Character, model) then
		return nil, nil, nil, "Climb aboard your boat first."
	end
	return boatId, layout, model, nil
end

-- The refit dock reserves the part in RefitPending while the player picks its
-- hold spot. Attributes cannot hold tables, so it is a server-owned
-- "BoatId|Kind|PartId" string.
local function pendingRefit(player: Player)
	local value = player:GetAttribute("RefitPending")
	if type(value) ~= "string" then
		return nil
	end
	local boatId, kind, partId = string.match(value, "^([^|]+)|([^|]+)|([^|]+)$")
	if not boatId or (kind ~= "Motor" and kind ~= "Rudder") then
		return nil
	end
	return { BoatId = boatId, Kind = kind, PartId = partId }
end

local function state(player: Player)
	local profile = BoatService.getProfile(player)
	local boatId, model = BoatService.activeBoat(player)
	local layout = boatId and BoatCatalog[boatId]
	if not profile or not layout then
		return { Ready = profile ~= nil }
	end
	local entry = lifted[player]
	local pending = pendingRefit(player)
	local waiting = if pending and pending.BoatId == boatId then pending else nil
	return {
		Ready = true,
		BoatId = boatId,
		Items = AnglerData.hold(profile.Angler, boatId, layout),
		Paint = profile.Angler.BoatPaint[boatId] or "Factory",
		NetOwned = BoatUpgrades.ownsNet(profile.Angler),
		Cash = profile.Cash,
		Pending = waiting,
		Lifted = entry ~= nil and entry.lift ~= nil and entry.model == model,
	}
end

-- Install only reserves the part: the player picks its hold spot themselves in
-- the cargo grid, and CargoService saves it there.
local function beginInstall(player: Player, kind: any): (boolean, string)
	local upgrade = if type(kind) == "string" then BoatUpgrades.Kinds[kind] else nil
	if not upgrade then
		return false, "Choose a motor or a rudder."
	end
	local boatId, layout, _, reason = refitBoat(player)
	local profile = BoatService.getProfile(player)
	if not boatId then
		return false, reason :: string
	elseif not profile then
		return false, "Your progress is still loading. Try again in a moment."
	elseif pendingRefit(player) ~= nil then
		return false, "A part is already waiting for a spot in your hold."
	end
	-- Reject a refit that could never fit before sending the player to the grid.
	local items, failure =
		BoatUpgrades.install(AnglerData.hold(profile.Angler, boatId, layout), layout, kind, Catalog.Fish)
	if not items then
		return false, failure
	end
	local partId = BoatUpgrades.partId(layout, kind)
	-- A string, because attributes cannot hold tables.
	player:SetAttribute("RefitPending", string.format("%s|%s|%s", boatId, kind, partId))
	return true, string.format("Choose where the %s goes in your hold.", string.lower(upgrade.Name))
end

local function remove(player: Player, kind: any): (boolean, string)
	local upgrade = if type(kind) == "string" then BoatUpgrades.Kinds[kind] else nil
	if not upgrade then
		return false, "Choose a motor or a rudder."
	end
	local boatId, layout, _, reason = refitBoat(player)
	local profile = BoatService.getProfile(player)
	if not boatId then
		return false, reason :: string
	elseif not profile then
		return false, "Your progress is still loading. Try again in a moment."
	end
	-- Check the cached profile first so a rejected refit never costs a save.
	local items, failure =
		BoatUpgrades.remove(AnglerData.hold(profile.Angler, boatId, layout), layout, kind, Catalog.Fish)
	if not items then
		return false, failure
	end
	local ok, message = BoatService.updateProgress(player, function(current)
		local updated, problem =
			BoatUpgrades.remove(AnglerData.hold(current.Angler, boatId, layout), layout, kind, Catalog.Fish)
		assert(updated, problem)
		current.Angler.Holds[boatId] = updated
	end)
	if not ok then
		return false, message
	end
	BoatService.refit(player)
	return true, string.format("%s taken out. Its cargo tiles are free again.", upgrade.Name)
end

local function repaint(player: Player, paintId: any): (boolean, string)
	local preset = BoatUpgrades.paint(paintId)
	if not preset then
		return false, "Choose one of the dock's paints."
	end
	local boatId, layout, _, reason = refitBoat(player)
	local profile = BoatService.getProfile(player)
	if not boatId then
		return false, reason :: string
	elseif not profile then
		return false, "Your progress is still loading. Try again in a moment."
	elseif (profile.Angler.BoatPaint[boatId] or "Factory") == preset.Id then
		return false, "Your " .. layout.Name .. " already wears that paint."
	end
	local ok, message = BoatService.updateProgress(player, function(current)
		current.Angler.BoatPaint[boatId] = if preset.RGB then preset.Id else nil
	end)
	if not ok then
		return false, message
	end
	BoatService.refit(player)
	return true,
		if preset.RGB
			then "Your " .. layout.Name .. " is painted " .. string.lower(preset.Name) .. "."
			else "Your " .. layout.Name .. " has its factory finish back."
end

-- The trawler's stern net is a one-time hull fitting. It is deliberately outside
-- the motor/rudder hold system, so it never takes cargo tiles.
local function buyNet(player: Player): (boolean, string)
	local boatId, layout, _, reason = refitBoat(player)
	local profile = BoatService.getProfile(player)
	local net = BoatUpgrades.Net
	if not boatId then
		return false, reason :: string
	elseif not profile then
		return false, "Your progress is still loading. Try again in a moment."
	elseif boatId ~= net.BoatId then
		return false, "The fisherman's net is made for the teal fishing trawler."
	elseif BoatUpgrades.ownsNet(profile.Angler) then
		return false, "Your " .. layout.Name .. " already carries its fisherman's net."
	elseif profile.Cash < net.Price then
		return false, string.format("You need $%d for the fisherman's net.", net.Price)
	end
	local ok, message = BoatService.updateProgress(player, function(current)
		assert(current.Cash >= net.Price, "Net purchase changed while saving")
		assert(not BoatUpgrades.ownsNet(current.Angler), "Net purchase changed while saving")
		current.Cash -= net.Price
		current.Angler.Stats.CoinsSpent += net.Price
		BoatUpgrades.grantNet(current.Angler)
	end)
	if not ok then
		return false, message
	end
	BoatService.refit(player)
	return true, "Fisherman's net fitted. Deploy it with the net button or N while underway."
end

-- Hulls launched from a dock, bought at the drydock or sailed by the hired
-- fisherman all come out painted and tuned.
local function outfit(player: Player, boatId: string, model: Model)
	local layout = BoatCatalog[boatId]
	local profile = BoatService.getProfile(player)
	if not layout or not profile then
		return nil
	end
	BoatRefitService.paint(model, profile.Angler.BoatPaint[boatId])
	TrawlerNetService.dress(player, boatId, model)
	local items = AnglerData.hold(profile.Angler, boatId, layout)
	local motorPartId = BoatUpgrades.partId(layout, "Motor")
	local motors = 0
	for _, item in items do
		if item.PartId == motorPartId then
			motors += 1
		end
	end
	model:SetAttribute("MotorCount", motors)
	return BoatUpgrades.spec(layout, items)
end

function BoatRefitService.start()
	if started then
		return
	end
	started = true
	BoatService.setOutfitter(outfit)
	local remote = Instance.new("RemoteFunction")
	remote.Name = "BoatRefit"
	remote.OnServerInvoke = function(player, action, key)
		if action == "Get" then
			return { Ok = true, Message = "", State = state(player) }
		elseif action == "Lower" then
			-- Always honoured, so closing the menu never strands a hull in the air.
			lower(player)
			return { Ok = true, Message = "", State = state(player) }
		elseif action ~= "Lift" and action ~= "Install" and action ~= "Remove" and action ~= "Paint" and action ~= "BuyNet" then
			return { Ok = false, Message = "That refit is unavailable.", State = state(player) }
		end
		if os.clock() - (requests[player] or -math.huge) < 0.3 then
			return { Ok = false, Message = "Please wait a moment and try again.", State = state(player) }
		end
		requests[player] = os.clock()
		local ok, message
		if action == "Lift" then
			ok, message = raise(player)
		elseif action == "Paint" then
			ok, message = repaint(player, key)
		elseif action == "BuyNet" then
			ok, message = buyNet(player)
		elseif action == "Install" then
			ok, message = beginInstall(player, key)
		else
			ok, message = remove(player, key)
		end
		return { Ok = ok, Message = message, State = state(player) }
	end
	remote.Parent = ReplicatedStorage
	Players.PlayerRemoving:Connect(function(player)
		requests[player] = nil
		lower(player)
	end)
end

return BoatRefitService
