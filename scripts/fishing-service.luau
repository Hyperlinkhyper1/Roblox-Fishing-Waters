-- Real FishingService handlers run against an event-driven inventory mock.
-- Parent changes fire ChildAdded/ChildRemoved; deferred work runs after a turn.
local function signal()
	local handlers = {}
	return {
		Connect = function(_, callback)
			local handler = { callback = callback, connected = true }
			table.insert(handlers, handler)
			return {
				Disconnect = function()
					handler.connected = false
				end,
			}
		end,
		Fire = function(_, ...)
			for _, handler in table.clone(handlers) do
				if handler.connected then
					handler.callback(...)
				end
			end
		end,
		Count = function()
			local total = 0
			for _, handler in handlers do
				if handler.connected then
					total += 1
				end
			end
			return total
		end,
	}
end
local Vector3 = {}
local vectorMeta = {}
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, _kind = "Vector3" }, vectorMeta)
end
function vectorMeta.__sub(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
function vectorMeta.__index(a, key)
	if key == "Magnitude" then
		return math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z)
	end
	return nil
end
Vector3.zero = Vector3.new()
local CFrame = {}
function CFrame.new(position)
	return {
		_kind = "CFrame",
		Position = position or Vector3.zero,
		PointToObjectSpace = function(_, point)
			return point - (position or Vector3.zero)
		end,
	}
end
local function typeof(value)
	return if type(value) == "table" then value._kind or "table" else type(value)
end

local Instance = {}
local methods = {}
function Instance.new(kind)
	local instance =
		{ properties = { ClassName = kind, Name = kind }, children = {}, attributes = {}, attributeSignals = {} }
	instance.properties.ChildAdded, instance.properties.ChildRemoved = signal(), signal()
	if kind == "Player" then
		instance.properties.CharacterAdded, instance.properties.CharacterRemoving = signal(), signal()
	elseif kind == "Humanoid" then
		instance.properties.Died = signal()
	elseif kind == "RemoteEvent" then
		instance.properties.OnServerEvent, instance.properties.messages = signal(), {}
	end
	return setmetatable(instance, {
		__index = function(self, key)
			return methods[key] or self.properties[key]
		end,
		__newindex = function(self, key, value)
			local old = self.properties[key]
			if old == value then
				return
			end
			self.properties[key] = value
			if key == "Parent" then
				if old then
					local index = table.find(old.children, self)
					if index then
						table.remove(old.children, index)
					end
					old.ChildRemoved:Fire(self)
				end
				if value then
					table.insert(value.children, self)
					value.ChildAdded:Fire(self)
				end
			end
		end,
	})
end
function methods:IsA(kind)
	return self.ClassName == kind or (kind == "BasePart" and self.ClassName == "Part")
end
function methods:GetChildren()
	return table.clone(self.children)
end
function methods:FindFirstChild(name, recursive)
	for _, child in self.children do
		if child.Name == name then
			return child
		end
		if recursive then
			local found = child:FindFirstChild(name, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function methods:WaitForChild(name)
	return assert(self:FindFirstChild(name), "Missing prepared mock child: " .. name)
end
function methods:FindFirstChildOfClass(kind)
	for _, child in self.children do
		if child:IsA(kind) then
			return child
		end
	end
	return nil
end
function methods:IsDescendantOf(ancestor)
	local parent = self.Parent
	while parent do
		if parent == ancestor then
			return true
		end
		parent = parent.Parent
	end
	return false
end
function methods:GetAttributeChangedSignal(name)
	if not self.attributeSignals[name] then
		self.attributeSignals[name] = signal()
	end
	return self.attributeSignals[name]
end
function methods:SetAttribute(name, value)
	if self.attributes[name] ~= value then
		self.attributes[name] = value
		self:GetAttributeChangedSignal(name):Fire()
	end
end
function methods:GetAttribute(name)
	return self.attributes[name]
end
function methods:Destroy()
	for _, child in self:GetChildren() do
		child:Destroy()
	end
	self.Parent = nil
	self.destroyed = true
end
function methods:FireClient(player, ...)
	table.insert(self.messages, { player = player, values = { ... } })
end
function methods:IsInGroupAsync(groupId)
	assert(groupId == 772704145, "Only the configured group may authorize rewards")
	if self.groupError then
		error("Membership service unavailable")
	end
	return self.groupMember == true
end
function methods:UnequipTools()
	for _, item in self.Parent:GetChildren() do
		if item:IsA("Tool") then
			item.Parent = self.owner:FindFirstChildOfClass("Backpack")
		end
	end
end
function methods:EquipTool(tool)
	self:UnequipTools()
	tool.Parent = self.Parent
end

local deferred = {}
local task = {
	wait = function() end,
	defer = function(callback)
		table.insert(deferred, callback)
	end,
	spawn = function(callback, ...)
		local args = { ... }
		table.insert(deferred, function()
			callback(table.unpack(args))
		end)
	end,
}
local function flush()
	local turns = 0
	while #deferred > 0 do
		turns += 1
		assert(turns < 200, "Deferred inventory synchronization did not settle")
		local callbacks = deferred
		deferred = {}
		for _, callback in callbacks do
			callback()
		end
	end
end
local now = 100
local os = {
	clock = function()
		return now
	end,
}
local Enum = { RaycastFilterType = { Exclude = "Exclude" } }
local Color3 = {
	fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end,
}
local RaycastParams = {
	new = function()
		return {}
	end,
}
local workspace = Instance.new("Workspace")
local sightResult = nil
function workspace:Raycast()
	return sightResult
end
local Players = Instance.new("Players")
Players.PlayerAdded, Players.PlayerRemoving = signal(), signal()
local playerList = {}
function Players:GetPlayers()
	return playerList
end
local tags = {}
local CollectionService = {
	GetTagged = function(_, name)
		return tags[name] or {}
	end,
	GetInstanceAddedSignal = function()
		return signal()
	end,
}
local ReplicatedStorage = Instance.new("ReplicatedStorage")
local ProximityPromptService = { PromptTriggered = signal() }
local services = {
	CollectionService = CollectionService,
	Players = Players,
	ReplicatedStorage = ReplicatedStorage,
	ProximityPromptService = ProximityPromptService,
}
local game = {
	GetService = function(_, name)
		return assert(services[name], name)
	end,
}
local purchases, builds, failSave, upgrades = 0, 0, false, 0
local dependencies = {
	BoatData = {
		upgradeRod = function(profile, stat)
			profile.RodUpgrades[stat] = (profile.RodUpgrades[stat] or 0) + 1
			return "Upgraded"
		end,
	},
	RodUpgrades = {
		Stats = { Speed = { Name = "Reel Speed" } },
		valid = function(stat)
			return stat == "Speed"
		end,
		level = function(levels, stat)
			return levels[stat] or 0
		end,
		price = function()
			return 100
		end,
	},
	BoatService = {
		getProfile = function(player)
			return if player:GetAttribute("BoatDataStatus") == "Ready" then { RodUpgrades = {} } else nil
		end,
		updateProgress = function(_, transform)
			upgrades += 1
			transform({ RodUpgrades = {} })
			return true, "Saved."
		end,
		purchaseRod = function(player)
			purchases += 1
			if player:GetAttribute("BoatDataStatus") ~= "Ready" then
				return false, "Inventory unavailable"
			end
			if failSave then
				return false, "The rod purchase could not be saved."
			end
			player:SetAttribute("OwnsStarterRod", true)
			return true, "Starter rod owned!"
		end,
	},
	FishingRod = {
		build = function(skinId, bobberSkinId)
			builds += 1
			local tool = Instance.new("Tool")
			tool:SetAttribute("RodId", "StarterRod")
			tool:SetAttribute("RodSkin", skinId or "")
			tool:SetAttribute("BobberSkin", bobberSkinId or "")
			return tool
		end,
	},
}
local Service = (function()
	-- FISHING_SERVICE_SOURCE --
end)()

local checks = 0
local function check(condition, message)
	checks += 1
	assert(condition, message)
end
local function makeCharacter(player)
	local character = Instance.new("Model")
	character.Parent = workspace
	local root = Instance.new("Part")
	root.Name, root.Position, root.Parent = "HumanoidRootPart", Vector3.zero, character
	local head = Instance.new("Part")
	head.Name, head.Position, head.Parent = "Head", Vector3.new(0, 2, 0), character
	local humanoid = Instance.new("Humanoid")
	humanoid.Health, humanoid.owner, humanoid.Parent = 100, player, character
	player.Character = character
	return character, root, humanoid
end
local function makePlayer(id, owned, status)
	local player = Instance.new("Player")
	player.UserId, player.Parent = id, Players
	player:SetAttribute("BoatDataStatus", status or "Ready")
	player:SetAttribute("OwnsStarterRod", owned == true)
	local backpack = Instance.new("Backpack")
	backpack.Parent = player
	local character, root, humanoid = makeCharacter(player)
	table.insert(playerList, player)
	return player, character, root, humanoid, backpack
end
local function rodCount(player)
	local total = 0
	for _, container in { player.Character, player:FindFirstChildOfClass("Backpack") } do
		if container then
			for _, item in container:GetChildren() do
				if item:IsA("Tool") and item:GetAttribute("RodId") == "StarterRod" then
					total += 1
				end
			end
		end
	end
	return total
end
local shop = Instance.new("Model")
shop.Parent = workspace
shop:SetAttribute("InteriorFrame", CFrame.new())
shop:SetAttribute("InteriorSize", Vector3.new(40, 12, 40))
tags.FishingRodShop = { shop }
local counter = Instance.new("Part")
counter.Position, counter.Parent = Vector3.zero, shop
local prompt = Instance.new("ProximityPrompt")
prompt.Name, prompt.MaxActivationDistance, prompt.Parent = "BuyFishingRodPrompt", 8, counter
local fresh, character, root, humanoid, backpack = makePlayer(1, true)
Service.start()
flush()
local request = ReplicatedStorage:WaitForChild("Fishing"):WaitForChild("Request")
local feedback = ReplicatedStorage:WaitForChild("Fishing"):WaitForChild("Feedback")
local function send(player, action, value)
	now += 1
	request.OnServerEvent:Fire(player, action, value)
	flush()
end
check(rodCount(fresh) == 1 and builds == 1, "Starting ownership grants exactly one backpack rod")
check(
	backpack:FindFirstChildOfClass("Tool") ~= nil and not fresh:GetAttribute("RodEquipped"),
	"Starter rod begins stowed in inventory"
)
local beforeMessages = #feedback.messages
ProximityPromptService.PromptTriggered:Fire(prompt, fresh)
send(fresh, "PurchaseRod")
check(purchases == 0 and #feedback.messages == beforeMessages, "Removed claim prompt and purchase remote are ignored")
-- Rod upgrades are only sold by Finn: his prompt, in range and in sight.
send(fresh, "UpgradeRod", "Speed")
local result = feedback.messages[#feedback.messages].values
check(upgrades == 0 and result[1] == "UpgradeResult" and result[2] == false, "Upgrades need the rod keeper")
local keeperHead = Instance.new("Part")
keeperHead.Position, keeperHead.Parent = Vector3.new(0, 2, 3), shop
local keeperPrompt = Instance.new("ProximityPrompt")
keeperPrompt.Name, keeperPrompt.MaxActivationDistance, keeperPrompt.Parent = "TalkToRodKeeperPrompt", 11, keeperHead
send(fresh, "UpgradeRod", "Luck")
check(upgrades == 0 and feedback.messages[#feedback.messages].values[2] == false, "Unknown upgrades are rejected")
send(fresh, "UpgradeRod", "Speed")
result = feedback.messages[#feedback.messages].values
check(upgrades == 1 and result[1] == "UpgradeResult" and result[2] == true, "Finn upgrades through the wallet store")
ProximityPromptService.PromptTriggered:Fire(keeperPrompt, fresh)
check(feedback.messages[#feedback.messages].values[1] == "OpenUpgrades", "Talking to Finn opens the upgrades")
keeperHead.Parent = nil

local foreignPrompt = Instance.new("ProximityPrompt")
foreignPrompt.Name, foreignPrompt.Parent = "BuyFishingRodPrompt", counter
beforeMessages = #feedback.messages
ProximityPromptService.PromptTriggered:Fire(foreignPrompt, fresh)
check(#feedback.messages == beforeMessages, "A different prompt with the same name must not open this shop")
sightResult = { Instance = counter }
ProximityPromptService.PromptTriggered:Fire(prompt, fresh)
check(#feedback.messages == beforeMessages, "Old counter prompts cannot open a claim window")
sightResult = nil
send(fresh, "EquipRod")
local rod = character:FindFirstChildOfClass("Tool")
check(rod ~= nil and fresh:GetAttribute("RodEquipped") == true, "Starting rod can be equipped anywhere")
check(rod:GetAttribute("OwnerUserId") == fresh.UserId, "Granted Tool must identify its owner")
for _ = 1, 3 do
	send(fresh, "EquipRod")
	send(fresh, "PurchaseRod")
end
check(builds == 1 and rodCount(fresh) == 1, "Repeated equip and obsolete claims retain one Tool")
local previousPurchases = purchases
request.OnServerEvent:Fire(fresh, "PurchaseRod")
flush()
check(purchases == previousPurchases, "Immediate duplicate requests must respect the server rate limit")
send(fresh, { "PurchaseRod" })
send(fresh, "GrantRod")
check(purchases == previousPurchases and builds == 1, "Unknown and malformed actions must not transact")

send(fresh, "UnequipRod")
check(
	rod.Parent == backpack and fresh:GetAttribute("RodEquipped") == false,
	"Remote stow must move the rod to Backpack"
)
check(builds == 1 and rodCount(fresh) == 1, "Stowing must not create a replacement Tool")

-- Furniture uses the same streamed, faded doorway trip as the tackle shop.
local door = Instance.new("Part")
door.Position, door.Parent = Vector3.zero, workspace
local enterFurniture = Instance.new("ProximityPrompt")
enterFurniture.Name, enterFurniture.MaxActivationDistance, enterFurniture.Parent = "FurnitureStoreDoorPrompt", 9, door
local destination = CFrame.new(Vector3.new(6700, 303.2, 145))
enterFurniture:SetAttribute("TeleportTo", destination)
local streamed
function fresh:RequestStreamAroundAsync(position)
	streamed = position
end
function character:PivotTo(frame)
	self.lastPivot = frame
	root.Position = frame.Position
end
now += 2
ProximityPromptService.PromptTriggered:Fire(enterFurniture, fresh)
check(feedback.messages[#feedback.messages].values[1] == "DoorFade", "Furniture door must fade before moving")
flush()
check(
	streamed == destination.Position and character.lastPivot == destination,
	"Furniture door must stream and enter the showroom"
)
check(root.AssemblyLinearVelocity == Vector3.zero, "Furniture arrival must stop the character's velocity")
check(feedback.messages[#feedback.messages].values[1] == "DoorArrived", "Furniture arrival must lift the fade")
root.Position = Vector3.zero
beforeMessages = #feedback.messages
ProximityPromptService.PromptTriggered:Fire(enterFurniture, fresh)
flush()
check(#feedback.messages == beforeMessages, "Furniture door must respect the trip cooldown")
now += 2
root.Position = Vector3.new(100, 0, 0)
ProximityPromptService.PromptTriggered:Fire(enterFurniture, fresh)
flush()
check(#feedback.messages == beforeMessages, "Distant furniture door activations must be rejected")
root.Position = Vector3.zero
humanoid.SeatPart = Instance.new("Part")
ProximityPromptService.PromptTriggered:Fire(enterFurniture, fresh)
flush()
check(#feedback.messages == beforeMessages, "Seated players must not enter furniture shop")
humanoid.SeatPart = nil
door.Position, root.Position = destination.Position, destination.Position
local returnFrame = CFrame.new(Vector3.zero)
enterFurniture:SetAttribute("TeleportTo", returnFrame)
ProximityPromptService.PromptTriggered:Fire(enterFurniture, fresh)
flush()
check(character.lastPivot == returnFrame and root.Position == Vector3.zero, "Furniture exit must return to the plaza")

humanoid:EquipTool(rod)
flush()
check(fresh:GetAttribute("RodEquipped") == true, "Native Backpack equip must synchronize the attribute")
humanoid:UnequipTools()
flush()
check(fresh:GetAttribute("RodEquipped") == false and builds == 1, "Native stow must synchronize without rebuilding")
local duplicate = dependencies.FishingRod.build()
duplicate.Parent = backpack
flush()
check(duplicate.destroyed == true and rodCount(fresh) == 1, "Inventory reconciliation must remove duplicate rods")

send(fresh, "EquipRod")
humanoid.Health = 0
humanoid.Died:Fire()
flush()
check(fresh:GetAttribute("RodEquipped") == false, "Death must clear the equipped attribute")
local builtBeforeDeath = builds
send(fresh, "EquipRod")
check(
	builds == builtBeforeDeath and fresh:GetAttribute("RodEquipped") == false,
	"Dead owners cannot equip or create new tools"
)
fresh.CharacterRemoving:Fire(character)
fresh.Character = nil
character:Destroy()
backpack:Destroy()
flush()
check(builds == builtBeforeDeath, "Removing a dead character must not award replacements")
local respawnBackpack = Instance.new("Backpack")
respawnBackpack.Parent = fresh
character, root, humanoid = makeCharacter(fresh)
fresh.CharacterAdded:Fire(character)
flush()
check(rodCount(fresh) == 1 and builds == builtBeforeDeath + 1, "Respawn must restore exactly one owned rod")
check(fresh:GetAttribute("RodEquipped") == false, "A respawned rod starts stowed")
check(
	backpack.ChildAdded:Count() == 0 and backpack.ChildRemoved:Count() == 0,
	"Replacing Backpack must detach old listeners"
)

local loading = makePlayer(2, true, "Loading")
Players.PlayerAdded:Fire(loading)
flush()
check(rodCount(loading) == 0, "Ownership without a ready wallet must not restore inventory")
loading:SetAttribute("BoatDataStatus", "Ready")
flush()
check(rodCount(loading) == 1, "Finishing a profile load must restore the owned rod")

-- Queue synchronization, then leave before it executes. No departed state may grant.
local departedBackpack = fresh:FindFirstChildOfClass("Backpack")
local oldCharacter = fresh.Character
local departureBuilds = builds
departedBackpack:FindFirstChildOfClass("Tool"):Destroy()
Players.PlayerRemoving:Fire(fresh)
fresh.Parent = nil
flush()
check(builds == departureBuilds, "Queued synchronization must not recreate tools after departure")
check(
	fresh.CharacterAdded:Count() == 0 and fresh.CharacterRemoving:Count() == 0,
	"Departure must detach character listeners"
)
check(fresh.ChildAdded:Count() == 0, "Departure must detach Backpack replacement listeners")
check(
	oldCharacter.ChildAdded:Count() == 0 and oldCharacter.ChildRemoved:Count() == 0,
	"Departure must detach inventory listeners"
)
check(humanoid.Died:Count() == 0, "Departure must detach death listeners")
check(
	departedBackpack.ChildAdded:Count() == 0 and departedBackpack.ChildRemoved:Count() == 0,
	"Departure must detach Backpack listeners"
)
check(
	fresh:GetAttributeChangedSignal("BoatDataStatus"):Count() == 0
		and fresh:GetAttributeChangedSignal("OwnsStarterRod"):Count() == 0,
	"Departure must detach profile listeners"
)
send(fresh, "PurchaseRod")
check(purchases == previousPurchases, "A departed player's remote cannot transact")
-- Exercise crate and bag remotes against the real saved-inventory rules.
local SkinData = (function()
	-- REAL_BOAT_DATA_SOURCE --
end)()
dependencies.BoatData.openRodCrate = SkinData.openRodCrate
dependencies.BoatData.equipRodSkin = SkinData.equipRodSkin
dependencies.BoatData.claimGroupRod = SkinData.claimGroupRod
dependencies.BoatData.openBobberCrate = SkinData.openBobberCrate
dependencies.BoatData.equipBobberSkin = SkinData.equipBobberSkin
local storedSkins = SkinData.decode(nil)
storedSkins.OwnedRods.StarterRod, storedSkins.Cash = true, 1400
local failSkinSave, skinSaves = false, 0
dependencies.BoatService.getProfile = function()
	return SkinData.decode(storedSkins)
end
dependencies.BoatService.updateProgress = function(player, transform)
	skinSaves += 1
	transform(SkinData.decode(storedSkins)) -- discarded UpdateAsync attempt
	local nextProfile = SkinData.decode(storedSkins)
	transform(nextProfile)
	if failSkinSave then
		return false, "Save failed"
	end
	storedSkins = SkinData.decode(nextProfile)
	player:SetAttribute("RodSkin", storedSkins.EquippedRodSkin or "")
	player:SetAttribute("RodSkinSerial", storedSkins.EquippedRodSkinSerial or 0)
	player:SetAttribute("BobberSkin", storedSkins.EquippedBobberSkin or "")
	return true, "Saved."
end
local cratePrompt = Instance.new("ProximityPrompt")
cratePrompt.Name, cratePrompt.MaxActivationDistance, cratePrompt.Parent = "OpenRodCratePrompt", 8, counter
send(loading, "OpenRodCrate", "TideCrate")
local reward = feedback.messages[#feedback.messages].values
check(
	reward[1] == "CrateResult" and reward[2] == true and reward[5] == 1,
	"Crate feedback includes the committed copy serial"
)
check(#storedSkins.RodSkinCopies == 1 and storedSkins.Cash == 1050, "Remote crate retry awards and charges once")
local skinId = reward[4]
failSkinSave = true
send(loading, "OpenRodCrate", "TideCrate")
reward = feedback.messages[#feedback.messages].values
check(
	reward[2] == false and reward[4] == nil and reward[5] == nil and #storedSkins.RodSkinCopies == 1,
	"Failed crate saves never reveal a reward or serial"
)
failSkinSave = false
storedSkins.RodSkinCopies[2] = { SkinId = skinId, Serial = 2 }
storedSkins.NextRodSkinSerial[skinId] = 3
storedSkins = SkinData.decode(storedSkins)
send(loading, "EquipRodSkin", { SkinId = skinId, Serial = 2 })
check(
	storedSkins.EquippedRodSkinSerial == 2 and feedback.messages[#feedback.messages].values[2] == true,
	"Bag remote selects the requested duplicate"
)
local beforeSkinSaves = skinSaves
for _, value in
	{
		{ SkinId = skinId, Serial = 99 },
		{ SkinId = skinId, Serial = "2" },
		{ SkinId = skinId, Serial = 1.5 },
		{ SkinId = "Bogus", Serial = 2 },
	}
do
	send(loading, "EquipRodSkin", value)
	check(
		feedback.messages[#feedback.messages].values[2] == false and skinSaves == beforeSkinSaves,
		"Forged bag selections are rejected before saving"
	)
end
send(loading, "EquipRodSkin", "")
check(
	storedSkins.EquippedRodSkinSerial == nil and storedSkins.EquippedRodSkin == nil,
	"Bag remote restores the plain rod"
)

storedSkins.Cash = 750
local copiesBeforeNovelty = #storedSkins.RodSkinCopies
send(loading, "OpenRodCrate", "NoveltyCrate")
reward = feedback.messages[#feedback.messages].values
check(reward[1] == "CrateResult" and reward[2] == true, "Novelty Crate succeeds through the shop remote")
check(
	storedSkins.Cash == 0 and #storedSkins.RodSkinCopies == copiesBeforeNovelty + 1,
	"Novelty retry saves one reward and charges $750 once"
)
local noveltyId, noveltySerial = reward[4], reward[5]
send(loading, "EquipRodSkin", { SkinId = noveltyId, Serial = noveltySerial })
check(
	storedSkins.EquippedRodSkin == noveltyId and storedSkins.EquippedRodSkinSerial == noveltySerial,
	"New crate rewards equip through the inventory remote"
)

local copiesBeforeGroup = #storedSkins.RodSkinCopies
local savesBeforeGroup = skinSaves
now += 10
send(loading, "ClaimGroupReward", { GroupId = 1, Member = true })
check(
	#storedSkins.RodSkinCopies == copiesBeforeGroup and skinSaves == savesBeforeGroup,
	"Forged client membership cannot authorize the group reward"
)
loading.groupError = true
now += 10
send(loading, "ClaimGroupReward")
check(skinSaves == savesBeforeGroup and not storedSkins.GroupRodClaimed, "Membership errors never award or save")
loading.groupError, loading.groupMember, failSkinSave = false, true, true
now += 10
send(loading, "ClaimGroupReward")
check(
	not storedSkins.GroupRodClaimed and #storedSkins.RodSkinCopies == copiesBeforeGroup,
	"Failed saves leave the group claim and serial available for retry"
)
failSkinSave = false
now += 10
send(loading, "ClaimGroupReward")
check(
	storedSkins.GroupRodClaimed
		and storedSkins.RodSkins.TideboundRod == 1
		and storedSkins.NextRodSkinSerial.TideboundRod == 2,
	"Retried transaction commits exactly one group rod"
)
check(
	string.find(feedback.messages[#feedback.messages].values[2], "Serial #000001", 1, true),
	"Successful claim reports the committed serial"
)
savesBeforeGroup = skinSaves
now += 10
send(loading, "ClaimGroupReward")
check(
	skinSaves == savesBeforeGroup and #storedSkins.RodSkinCopies == copiesBeforeGroup + 1,
	"Repeated claims never save or award again"
)
storedSkins = SkinData.decode(nil)
local member = makePlayer(777, true, "Loading")
member.groupMember = true
Players.PlayerAdded:Fire(member)
flush()
check(not storedSkins.GroupRodClaimed, "Auto claim waits for inventory readiness")
member:SetAttribute("BoatDataStatus", "Ready")
flush()
check(
	storedSkins.GroupRodClaimed and #storedSkins.RodSkinCopies == 1,
	"Existing group members automatically receive one rod after loading"
)

-- Bobber purchases require their own stand and share the atomic wallet save.
local bobberCounter = Instance.new("Part")
bobberCounter.Position, bobberCounter.Parent = Vector3.new(-15, 0, 0), shop
local bobberPrompt = Instance.new("ProximityPrompt")
bobberPrompt.Name, bobberPrompt.MaxActivationDistance, bobberPrompt.Parent = "OpenBobberCratePrompt", 8, bobberCounter
storedSkins.Cash = 700
local savesBeforeBobbers = skinSaves
send(member, "OpenBobberCrate", "BobberCase")
check(
	skinSaves == savesBeforeBobbers and feedback.messages[#feedback.messages].values[2] == false,
	"Rod stand cannot authorize a distant bobber case purchase"
)
member.Character:FindFirstChild("HumanoidRootPart").Position = bobberCounter.Position
ProximityPromptService.PromptTriggered:Fire(bobberPrompt, member)
check(feedback.messages[#feedback.messages].values[1] == "OpenBobberCrates", "Bobber stand opens its own menu")
send(member, "OpenBobberCrate", "BobberCase")
reward = feedback.messages[#feedback.messages].values
local bobberId = reward[4]
check(
	reward[1] == "BobberCrateResult"
		and reward[2]
		and storedSkins.Cash == 350
		and storedSkins.BobberSkins[bobberId] == 1,
	"Save retries charge $350 and award one bobber"
)
failSkinSave = true
send(member, "OpenBobberCrate", "BobberCase")
check(
	feedback.messages[#feedback.messages].values[2] == false and storedSkins.Cash == 350,
	"A failed bobber save reveals no reward and keeps cash"
)
failSkinSave = false
storedSkins.Cash = 349
savesBeforeBobbers = skinSaves
send(member, "OpenBobberCrate", "BobberCase")
check(
	skinSaves == savesBeforeBobbers and feedback.messages[#feedback.messages].values[2] == false,
	"Insufficient bobber funds do not save"
)
send(member, "OpenBobberCrate", "TideCrate")
check(skinSaves == savesBeforeBobbers, "Bobber remote rejects rod crate ids")
send(member, "EquipBobberSkin", "Bogus")
check(skinSaves == savesBeforeBobbers, "Unknown bobber selection cannot save")
send(member, "EquipBobberSkin", bobberId)
local selectedTool = member:FindFirstChildOfClass("Backpack"):FindFirstChildOfClass("Tool")
check(
	storedSkins.EquippedBobberSkin == bobberId
		and selectedTool:GetAttribute("BobberSkin") == bobberId
		and rodCount(member) == 1,
	"Equipping a bobber rebuilds exactly one rod with the saved selection"
)
send(member, "EquipBobberSkin", "")
check(
	storedSkins.EquippedBobberSkin == nil and storedSkins.BobberSkins[bobberId] == 1,
	"Bobber can be removed without losing its copy"
)

print(
	"Fishing service: " .. checks .. " authorization and lifecycle checks passed (recording mocks; no Roblox runtime)."
)
