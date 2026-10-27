-- The angler's hand, backpack, and launched boat's cargo hold. The backpack is
-- reachable everywhere; the boat hold is only reachable while aboard. Clients only
-- preview placements; every move is checked against the saved profile here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnglerData = require(script.Parent.AnglerData)
local BoatService = require(script.Parent.BoatService)
local Aboard = require(ReplicatedStorage.Shared.Aboard)
local BoatCatalog = require(ReplicatedStorage.Shared.BoatCatalog)
local Backpacks = require(ReplicatedStorage.Shared.BackpackCatalog)
local Cargo = require(ReplicatedStorage.Shared.Cargo)
local Catalog = require(ReplicatedStorage.Shared.AnglerCatalog)
local FishCatch = require(ReplicatedStorage.Shared.FishCatch)
local FishModels = require(ReplicatedStorage.Shared.FishModels)
local FishMutations = require(ReplicatedStorage.Shared.FishMutations)

local CargoService = {}
local started = false
local requests = {}
local update: RemoteEvent

-- The refit dock reserves a motor or rudder in RefitPending while the player
-- picks its hold spot. Attributes cannot hold tables, so the reservation is a
-- server-owned "BoatId|Kind|PartId" string.
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

local function boatInReach(player: Player): (string?, any?, boolean)
	local boatId, model = BoatService.activeBoat(player)
	local layout = boatId and BoatCatalog[boatId]
	if not layout or not model then
		return nil, nil, false
	end
	return boatId, layout, Aboard(player.Character, model)
end

local function state(player: Player)
	local profile = BoatService.getProfile(player)
	if not profile then
		return nil
	end
	local boatId, layout, near = boatInReach(player)
	local pending = pendingRefit(player)
	if not pending or pending.BoatId ~= boatId or not near then
		pending = nil
	end
	return {
		Hand = profile.Angler.Hand,
		BackpackId = profile.Angler.BackpackId,
		Backpack = profile.Angler.Backpack,
		BoatId = boatId,
		Items = if layout then AnglerData.hold(profile.Angler, boatId, layout) else {},
		Pending = if pending then { BoatId = pending.BoatId, Kind = pending.Kind, PartId = pending.PartId } else nil,
		Freezer = #profile.Angler.Freezer,
		FreezerUsage = AnglerData.freezerUsage(profile.Angler),
	}
end

local function fishKey(record): string
	return string.format("%s|%s|%s", tostring(record.FishId), tostring(record.Kg), tostring(record.CaughtAt))
end

-- A hotbar fish must actually be equipped to place it in the freezer.
function CargoService.isCarrying(player: Player, record): boolean
	local character = player.Character
	if not character or not record then
		return false
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("CargoFish") == fishKey(record) then
			return true
		end
	end
	return false
end

local function buildFishTool(record): Tool
	local species = Catalog.Fish[record.FishId]
	local tool = Instance.new("Tool")
	local mutation = FishMutations.label(record.Mutation, record.NeonColor)
	tool.Name = (if mutation ~= "" then mutation .. " " else "")
		.. (if species then species.Name else record.FishId)
		.. (if record.Size == "Huge" then " (Huge)" elseif record.Size == "Big" then " (Big)" else "")
	tool.ToolTip = string.format(
		"%s · $%d · stow it in your backpack, aboard or in your freezer",
		FishCatch.formatKg(record.Kg),
		math.floor(record.Value)
	)
	tool.CanBeDropped = false
	tool.Grip = CFrame.Angles(0, math.rad(180), 0)
	tool:SetAttribute("CargoFish", fishKey(record))
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.4, 0.4)
	handle.Transparency = 1
	handle.CanCollide, handle.CanTouch, handle.CanQuery = false, false, false
	handle.Massless = true
	handle.Parent = tool
	local model = FishModels.create(record.FishId, record)
	if model then
		FishModels.scaleHeldCatch(model, record.Kg, record.Size)
		handle.CFrame = model:GetPivot()
		for _, piece in model:GetDescendants() do
			if piece:IsA("BasePart") then
				piece.Anchored, piece.Massless = false, true
				piece.CanCollide, piece.CanTouch, piece.CanQuery = false, false, false
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1 = handle, piece
				weld.Parent = piece
			end
		end
		model.Parent = tool
	end
	return tool
end

-- Keeps exactly one hotbar Tool for the fish in hand, rebuilt only when it changes.
local function syncTool(player: Player)
	local profile = BoatService.getProfile(player)
	if not profile then
		return
	end
	local hand = profile.Angler.Hand
	local wanted = if hand then fishKey(hand) else nil
	local backpack = player:FindFirstChildOfClass("Backpack")
	local kept = false
	for _, container in { player.Character, backpack } do
		if not container then
			continue
		end
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("CargoFish") ~= nil then
				if child:GetAttribute("CargoFish") == wanted and not kept then
					kept = true
				else
					child:Destroy()
				end
			end
		end
	end
	if hand and not kept and backpack then
		buildFishTool(hand).Parent = backpack
	end
end

function CargoService.push(player: Player)
	if player.Parent == Players then
		syncTool(player)
		update:FireClient(player, state(player))
	end
end

local function spot(value: any)
	if type(value) ~= "table" then
		return nil
	end
	local x, y, r = value.X, value.Y, value.R
	if type(x) ~= "number" or type(y) ~= "number" or type(r) ~= "number" then
		return nil
	end
	return { X = x, Y = y, R = r }
end

local function move(player: Player, from: any, to: any, container: any): (boolean, string)
	if container ~= nil and container ~= "Boat" and container ~= "Backpack" then
		return false, "Choose your backpack or boat hold."
	end
	local backpack = container == "Backpack"
	if from ~= "Hand" and not (type(from) == "number" and from % 1 == 0 and from >= 1 and from <= 256) then
		return false, "That item can't be moved."
	end
	if to ~= "Hand" and to ~= "Release" then
		to = spot(to)
		if not to then
			return false, "That isn't a spot in the hold."
		end
	end
	local profile = BoatService.getProfile(player)
	if not profile then
		return false, "Your cargo is still loading. Try again in a moment."
	end
	local boatId, layout, near = boatInReach(player)
	local usesHold = from ~= "Hand" or type(to) == "table"
	if usesHold and not backpack and not near then
		return false, if layout then "Climb aboard your boat to use its hold." else "Launch your boat to use its hold."
	end
	if not near then
		layout = nil
	end
	if backpack then
		boatId = nil
		layout = Backpacks.Items[profile.Angler.BackpackId] or Backpacks.Items.Starter
	end
	-- Check the cached profile first so a rejected move never costs a save.
	local data, reason = AnglerData.moveCargo(profile.Angler, boatId, layout, from, to, Catalog.Fish, backpack)
	if not data then
		return false, reason
	end
	return BoatService.updateProgress(player, function(current)
		local moved, failure = AnglerData.moveCargo(current.Angler, boatId, layout, from, to, Catalog.Fish, backpack)
		assert(moved, failure)
		current.Angler = moved
	end)
end

local function moveAll(player: Player): (boolean, string)
	local profile = BoatService.getProfile(player)
	if not profile then
		return false, "Your cargo is still loading. Try again in a moment."
	end
	local boatId, layout, near = boatInReach(player)
	if not layout then
		return false, "Launch your boat to use its hold."
	end
	if not near then
		return false, "Climb aboard your boat to use its hold."
	end
	local backpackLayout = Backpacks.Items[profile.Angler.BackpackId] or Backpacks.Items.Starter
	local data, count = AnglerData.moveAllToBackpack(profile.Angler, boatId, layout, backpackLayout, Catalog.Fish)
	if not data then
		-- On failure the second value is the player-facing reason instead of a count.
		return false, count
	end
	local ok, message = BoatService.updateProgress(player, function(current)
		local updated, failure =
			AnglerData.moveAllToBackpack(current.Angler, boatId, layout, backpackLayout, Catalog.Fish)
		assert(updated, failure)
		current.Angler = updated
	end)
	if not ok then
		return false, message
	end
	return true, string.format("Moved %d fish into your backpack.", count)
end

-- The refit dock reserves a motor or rudder in RefitPending; the player picks
-- where it sits in the hold, and this saves that exact placement.
local function placeRefit(player: Player, x: any, y: any, r: any): (boolean, string)
	local pending = pendingRefit(player)
	if not pending then
		return false, "Choose a motor or rudder at the dock first."
	end
	local profile = BoatService.getProfile(player)
	if not profile then
		return false, "Your cargo is still loading. Try again in a moment."
	end
	local boatId, layout, near = boatInReach(player)
	if not layout then
		return false, "Launch your boat to use its hold."
	elseif not near then
		return false, "Climb aboard your boat to use its hold."
	elseif pending.BoatId ~= boatId then
		return false, "That refit belongs to another boat."
	elseif not Cargo.Parts[pending.PartId] then
		return false, "That boat part is not available."
	end
	local data, reason = AnglerData.placePart(profile.Angler, boatId, layout, pending.PartId, x, y, r, Catalog.Fish)
	if not data then
		return false, reason
	end
	-- Clear before saving so the revision pushes during the save cannot re-arm
	-- placement; put it back if the save fails.
	local encoded = player:GetAttribute("RefitPending")
	player:SetAttribute("RefitPending", nil)
	local ok, message = BoatService.updateProgress(player, function(current)
		local updated, failure =
			AnglerData.placePart(current.Angler, boatId, layout, pending.PartId, x, y, r, Catalog.Fish)
		assert(updated, failure)
		current.Angler = updated
	end)
	if not ok then
		player:SetAttribute("RefitPending", encoded)
		return false, message
	end
	BoatService.refit(player)
	return true,
		if pending.Kind == "Motor"
			then "Extra motor fitted! Your " .. layout.Name .. " is faster now."
			else "Rudder fitted! Your " .. layout.Name .. " turns sharper now."
end

local function cancelRefit(player: Player): (boolean, string)
	if player:GetAttribute("RefitPending") == nil then
		return true, ""
	end
	player:SetAttribute("RefitPending", nil)
	return true, "Refit cancelled. Nothing was changed."
end

local function lockBackpack(player: Player, index: any, locked: any, expected: any): (boolean, string)
	if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > 256 or type(locked) ~= "boolean" then
		return false, "Choose a fish in your backpack."
	end
	local profile = BoatService.getProfile(player)
	if not profile then
		return false, "Your cargo is still loading. Try again in a moment."
	end
	local data, reason = AnglerData.setBackpackLock(profile.Angler, index, locked, expected)
	if not data then
		return false, reason
	end
	return BoatService.updateProgress(player, function(current)
		local updated, failure = AnglerData.setBackpackLock(current.Angler, index, locked, expected)
		assert(updated, failure)
		current.Angler = updated
	end)
end

function CargoService.start()
	if started then
		return
	end
	started = true
	local remotes = Instance.new("Folder")
	remotes.Name = "Cargo"
	local request = Instance.new("RemoteFunction")
	request.Name, request.Parent = "Request", remotes
	update = Instance.new("RemoteEvent")
	update.Name, update.Parent = "Update", remotes
	remotes.Parent = ReplicatedStorage
	request.OnServerInvoke = function(player, action, a, b, c)
		if action == "Get" then
			return { Ok = true, Message = "", State = state(player) }
		elseif
			action ~= "Move"
			and action ~= "Lock"
			and action ~= "MoveAll"
			and action ~= "Place"
			and action ~= "CancelPlace"
		then
			return { Ok = false, Message = "That cargo action is unavailable.", State = state(player) }
		end
		if os.clock() - (requests[player] or -math.huge) < 0.2 then
			return { Ok = false, Message = "Please wait a moment and try again.", State = state(player) }
		end
		requests[player] = os.clock()
		local ok, message
		if action == "Lock" then
			ok, message = lockBackpack(player, a, b, c)
		elseif action == "MoveAll" then
			ok, message = moveAll(player)
		elseif action == "Place" then
			ok, message = placeRefit(player, a, b, c)
		elseif action == "CancelPlace" then
			ok, message = cancelRefit(player)
		else
			ok, message = move(player, a, b, c)
		end
		return { Ok = ok, Message = message, State = state(player) }
	end
	-- Every saved change and every launch or docking refreshes the client's view.
	local function bind(player: Player)
		player:GetAttributeChangedSignal("AnglerRevision"):Connect(function()
			CargoService.push(player)
		end)
		player:GetAttributeChangedSignal("ActiveBoatId"):Connect(function()
			CargoService.push(player)
		end)
		-- Fitting a motor or rudder at the dock opens the hold placement view.
		player:GetAttributeChangedSignal("RefitPending"):Connect(function()
			CargoService.push(player)
		end)
		-- Respawning empties the Backpack, so hand the fish back.
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			if player.Character == character then
				syncTool(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(bind)
	for _, player in Players:GetPlayers() do
		bind(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		requests[player] = nil
	end)
end

return CargoService
