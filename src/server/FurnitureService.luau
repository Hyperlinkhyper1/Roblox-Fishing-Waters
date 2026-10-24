-- Furniture bought at the plaza shop and placed in a base house from build mode.
-- Clients only preview placements; every purchase and move is checked against the
-- saved profile here. Placed items are rebuilt from the owner's profile, so a base
-- always shows its current owner's furniture and nobody else's.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnglerData = require(script.Parent.AnglerData)
local BoatService = require(script.Parent.BoatService)
local CargoService = require(script.Parent.CargoService)
local FishFreezer = require(script.Parent.Map.FishFreezer)
local ShopDesk = require(script.Parent.Map.ShopDesk)
local StorageRack = require(script.Parent.Map.StorageRack)
local Furniture = require(ReplicatedStorage.Shared.FurnitureCatalog)

local FurnitureService = {}
local BASE_TAG = "PlayerBase"
local SHOP_TAG = "FurnitureShop"
local OWNER_PROMPT_TAG = "ShopOwnerPrompt"
local HOME_DISTANCE = 90
local started = false
local requests = {}
local busy: { [Player]: boolean } = {}
local update: RemoteEvent

local function ownerOf(base: Model): Player?
	local userId = base:GetAttribute("OwnerUserId")
	return if type(userId) == "number" and userId ~= 0 then Players:GetPlayerByUserId(userId) else nil
end

local function houseOf(base: Model): (Model?, CFrame?)
	local house = base:FindFirstChild("BaseHouse")
	local frame = house and house:GetAttribute("HouseFrame")
	if house and house:IsA("Model") and typeof(frame) == "CFrame" then
		return house, frame
	end
	return nil, nil
end

local function baseOf(player: Player): Model?
	for _, base in CollectionService:GetTagged(BASE_TAG) do
		if base:GetAttribute("OwnerUserId") == player.UserId then
			return base
		end
	end
	return nil
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function near(player: Player, position: Vector3, distance: number): boolean
	local root = rootOf(player)
	return root ~= nil and (root.Position - position).Magnitude <= distance
end

local function notify(player: Player, message: string)
	if player.Parent == Players then
		update:FireClient(player, "Notice", message)
	end
end

local function atShop(player: Player, itemId: string): boolean
	local root = rootOf(player)
	if not root then return false end
	for _, hall in CollectionService:GetTagged("FurnitureShowroom") do
		if not hall:IsDescendantOf(workspace) then continue end
		local frame, size = hall:GetAttribute("InteriorFrame"), hall:GetAttribute("InteriorSize")
		if typeof(frame) ~= "CFrame" or typeof(size) ~= "Vector3" then continue end
		local p = frame:PointToObjectSpace(root.Position)
		if math.abs(p.X) > size.X / 2 or math.abs(p.Y) > size.Y / 2 or math.abs(p.Z) > size.Z / 2 then
			continue
		end
		for _, prompt in hall:GetDescendants() do
			if not prompt:IsA("ProximityPrompt") or prompt.Name ~= "BrowseFurniturePrompt" or not prompt.Enabled then
				continue
			end
			local displayItem = prompt:GetAttribute("ItemId")
			local anchor = prompt.Parent
			if (displayItem == nil or displayItem == itemId) and anchor and anchor:IsA("BasePart")
				and near(player, anchor.Position, prompt.MaxActivationDistance + 2) then
				return true
			end
		end
	end
	return false
end

local function atHome(player: Player): boolean
	local base = baseOf(player)
	local _, frame = if base then houseOf(base) else nil
	return frame ~= nil and near(player, frame.Position, HOME_DISTANCE)
end

local function state(player: Player)
	local profile = BoatService.getProfile(player)
	if not profile then
		return nil
	end
	local data = profile.Angler
	return {
		Cash = profile.Cash,
		Stock = data.FurnitureStock,
		Placed = data.Furniture,
		Freezer = #data.Freezer,
		FreezerCapacity = AnglerData.freezerCapacity(data),
		Storage = #data.Storage,
		StorageCapacity = AnglerData.storageCapacity(data),
		BaseId = player:GetAttribute("BaseId"),
	}
end

local function ownerPrompt(parent: Instance, name: string, action: string, object: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 6
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	CollectionService:AddTag(prompt, OWNER_PROMPT_TAG)
	prompt.Parent = parent
	return prompt
end

local function promptAnchor(parent: Instance, cframe: CFrame): Part
	local anchor = Instance.new("Part")
	anchor.Name = "PromptAnchor"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency, anchor.Anchored = 1, true
	anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = false, false, false
	anchor.CFrame = cframe
	anchor.Parent = parent
	return anchor
end

local function key(entry): string
	return string.format("%s|%s|%s|%d", entry.ItemId, tostring(entry.X), tostring(entry.Z), entry.R)
end

local function buildItem(parent: Model, houseFrame: CFrame, entry, userId: number): Model?
	local frame = Furniture.frame(houseFrame, entry)
	local model
	if entry.ItemId == "Freezer" then
		model = FishFreezer.build(parent, frame)
		local anchor = promptAnchor(model, frame * CFrame.new(0, FishFreezer.HEIGHT * 0.7, FishFreezer.DEPTH / 2))
		-- CustomerService handles every freezer prompt in a base the same way.
		ownerPrompt(anchor, "StockFreezerPrompt", "Place fish", "Freezer"):SetAttribute("OwnerUserId", userId)
	elseif entry.ItemId == "Register" then
		model = ShopDesk.build(parent, frame)
	elseif entry.ItemId == "StorageRack" then
		model = StorageRack.build(parent, frame)
		local anchor = promptAnchor(model, frame * CFrame.new(0, 3, StorageRack.DEPTH / 2 + 0.3))
		ownerPrompt(anchor, "StoreFishPrompt", "Store fish", "Storage rack"):SetAttribute("OwnerUserId", userId)
		local take = ownerPrompt(anchor, "TakeStoredFishPrompt", "Take fish", "Storage rack")
		take.KeyboardKeyCode, take.GamepadKeyCode = Enum.KeyCode.F, Enum.KeyCode.ButtonY
		take:SetAttribute("OwnerUserId", userId)
		model.Parent = parent
	else
		return nil
	end
	model.Name = entry.ItemId
	model:SetAttribute("FurnitureKey", key(entry))
	model:SetAttribute("ItemId", entry.ItemId)
	model:SetAttribute("X", entry.X)
	model:SetAttribute("Z", entry.Z)
	model:SetAttribute("R", entry.R)
	return model
end

-- Rebuilds only what changed, so prompts and fish displays on untouched items survive.
local function sync(base: Model)
	local house, houseFrame = houseOf(base)
	if not house or not houseFrame then
		return
	end
	local folder = house:FindFirstChild("Furniture")
	if not folder then
		folder = Instance.new("Model")
		folder.Name = "Furniture"
		folder.Parent = house
	end
	local owner = ownerOf(base)
	local profile = owner and BoatService.getProfile(owner)
	local wanted = {}
	if profile then
		for _, entry in profile.Angler.Furniture do
			wanted[key(entry)] = entry
		end
	end
	local present = {}
	for _, child in folder:GetChildren() do
		local childKey = child:GetAttribute("FurnitureKey")
		if not wanted[childKey] or present[childKey] or child:GetAttribute("OwnerUserId") ~= (owner and owner.UserId) then
			child:Destroy()
		else
			present[childKey] = child
		end
	end
	for entryKey, entry in wanted do
		if not present[entryKey] and owner then
			local model = buildItem(folder, houseFrame, entry, owner.UserId)
			if model then
				model:SetAttribute("OwnerUserId", owner.UserId)
				present[entryKey] = model
			end
		end
	end
	-- Racks fill in placement order, eight crates each.
	local stored = if profile then #profile.Angler.Storage else 0
	local capacity = if profile then AnglerData.storageCapacity(profile.Angler) else 0
	for _, entry in if profile then profile.Angler.Furniture else {} do
		local model = present[key(entry)]
		if entry.ItemId == "StorageRack" and model then
			StorageRack.fill(model, Furniture.frame(houseFrame, entry), math.min(stored, StorageRack.CRATES))
			stored = math.max(0, stored - StorageRack.CRATES)
			for _, prompt in model:GetDescendants() do
				if prompt:IsA("ProximityPrompt") then
					prompt.ObjectText = string.format("Storage · %d/%d fish", #profile.Angler.Storage, capacity)
				end
			end
		end
	end
end

local function syncPlayer(player: Player)
	local base = baseOf(player)
	if base then
		sync(base)
	end
end

local function transact(player: Player, transform): (boolean, string)
	if busy[player] then
		return false, "Please wait a moment and try again."
	end
	busy[player] = true
	local ok, message = BoatService.updateProgress(player, transform)
	busy[player] = nil
	if ok then
		syncPlayer(player)
	end
	return ok, message
end

-- Pre-checks the cached profile so a rejected request never costs a save.
local function run(player: Player, change): (boolean, string)
	local profile = BoatService.getProfile(player)
	if not profile then
		return false, "Your progress is still loading. Try again in a moment."
	end
	local _, reason = change(profile)
	if reason then
		return false, reason
	end
	return transact(player, function(current)
		local _, failure = change(current)
		assert(not failure, failure)
	end)
end

local function buy(player: Player, itemId: any): (boolean, string)
	local item = if type(itemId) == "string" then Furniture.Items[itemId] else nil
	if not item then
		return false, "That isn't for sale."
	elseif not atShop(player, itemId) then
		return false, "Step inside Harbour Home and approach a display or the counter to buy furniture."
	end
	local ok, message = run(player, function(profile)
		if profile.Cash < item.Price then
			return nil, string.format("You need $%d for a %s.", item.Price, string.lower(item.Name))
		end
		local data, reason = AnglerData.buyFurniture(profile.Angler, itemId)
		if not data then
			return nil, reason
		end
		profile.Cash -= item.Price
		data.Stats.CoinsSpent += item.Price
		profile.Angler = data
		return data
	end)
	if ok then
		message = item.Name .. " bought! Open build mode at home to place it."
	end
	return ok, message
end

local function place(player: Player, from: any, x: any, z: any, r: any): (boolean, string)
	if type(from) ~= "string" and not (type(from) == "number" and from % 1 == 0) then
		return false, "That isn't furniture."
	elseif type(x) ~= "number" or type(z) ~= "number" or type(r) ~= "number" then
		return false, "That isn't a spot in your house."
	elseif not atHome(player) then
		return false, "Go home to arrange your furniture."
	end
	return run(player, function(profile)
		local data, reason = AnglerData.placeFurniture(profile.Angler, from, x, z, r)
		if data then
			profile.Angler = data
		end
		return data, reason
	end)
end

local function pickUp(player: Player, index: any): (boolean, string)
	if not atHome(player) then
		return false, "Go home to arrange your furniture."
	end
	return run(player, function(profile)
		local data, reason = AnglerData.pickUpFurniture(profile.Angler, index)
		if data then
			profile.Angler = data
		end
		return data, reason
	end)
end

local function rackPrompt(player: Player, prompt: ProximityPrompt)
	local base = baseOf(player)
	if not base or not prompt:IsDescendantOf(base) or not near(player, prompt.Parent.Position, prompt.MaxActivationDistance + 2) then
		return
	end
	local store = prompt.Name == "StoreFishPrompt"
	local profile = BoatService.getProfile(player)
	if not profile then
		return
	elseif store and not CargoService.isCarrying(player, profile.Angler.Hand) then
		notify(player, "Equip a fish from your hotbar and carry it to the rack.")
		return
	end
	local ok, message = run(player, function(current)
		if store and not CargoService.isCarrying(player, current.Angler.Hand) then
			return nil, "Carry a fish to the rack first."
		end
		local data, reason = (if store then AnglerData.storeFish else AnglerData.takeStored)(current.Angler)
		if data then
			current.Angler = data
		end
		return data, reason
	end)
	notify(
		player,
		if not ok then message
			elseif store then "Stored one fish on your rack."
			else "Took a fish off the rack. Carry it to a freezer to sell it."
	)
end

-- A plain shopkeeper stands behind each sales counter.
local function staffCounter(top: Instance)
	local shop = top.Parent
	local frame = shop and shop:GetAttribute("KeeperFrame")
	if not shop or typeof(frame) ~= "CFrame" or shop:FindFirstChild("Shopkeeper") then
		return
	end
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = Color3.fromRGB(204, 142, 105)
	description.LeftArmColor, description.RightArmColor = description.HeadColor, description.HeadColor
	description.TorsoColor = Color3.fromRGB(64, 140, 120)
	description.LeftLegColor, description.RightLegColor = Color3.fromRGB(70, 62, 54), Color3.fromRGB(70, 62, 54)
	local ok, keeper = pcall(Players.CreateHumanoidModelFromDescription, Players, description, Enum.HumanoidRigType.R15)
	description:Destroy()
	if not ok then
		warn("[Furniture] Shopkeeper: " .. tostring(keeper))
		return
	end
	keeper.Name = "Shopkeeper"
	local humanoid = keeper:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local root = keeper:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = true
	end
	keeper:PivotTo(frame + Vector3.new(0, keeper:GetExtentsSize().Y / 2, 0))
	keeper.Parent = shop
end

function FurnitureService.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceAddedSignal(SHOP_TAG):Connect(function(top)
		task.spawn(staffCounter, top)
	end)
	for _, top in CollectionService:GetTagged(SHOP_TAG) do
		task.spawn(staffCounter, top)
	end
	local remotes = Instance.new("Folder")
	remotes.Name = "Furniture"
	local request = Instance.new("RemoteFunction")
	request.Name, request.Parent = "Request", remotes
	update = Instance.new("RemoteEvent")
	update.Name, update.Parent = "Update", remotes
	remotes.Parent = ReplicatedStorage
	request.OnServerInvoke = function(player, action, a, b, c, d)
		if action == "Get" then
			return { Ok = true, Message = "", State = state(player) }
		end
		if os.clock() - (requests[player] or -math.huge) < 0.25 then
			return { Ok = false, Message = "Please wait a moment and try again.", State = state(player) }
		end
		requests[player] = os.clock()
		local ok, message
		if action == "Buy" then
			ok, message = buy(player, a)
		elseif action == "Place" or action == "Move" then
			ok, message = place(player, a, b, c, d)
		elseif action == "PickUp" then
			ok, message = pickUp(player, a)
		else
			ok, message = false, "That furniture action is unavailable."
		end
		return { Ok = ok, Message = message, State = state(player) }
	end
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name == "StoreFishPrompt" or prompt.Name == "TakeStoredFishPrompt" then
			task.spawn(rackPrompt, player, prompt)
		end
	end)
	local function bind(player: Player)
		player:GetAttributeChangedSignal("AnglerRevision"):Connect(function()
			syncPlayer(player)
			update:FireClient(player, "State", state(player))
		end)
	end
	Players.PlayerAdded:Connect(bind)
	for _, player in Players:GetPlayers() do
		bind(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		requests[player], busy[player] = nil, nil
	end)
	local function watch(base: Instance)
		if base:IsA("Model") then
			base:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
				sync(base)
			end)
			sync(base)
		end
	end
	CollectionService:GetInstanceAddedSignal(BASE_TAG):Connect(watch)
	for _, base in CollectionService:GetTagged(BASE_TAG) do
		watch(base)
	end
end

return FurnitureService
