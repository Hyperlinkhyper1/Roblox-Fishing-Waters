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
local purchases, builds, failSave = 0, 0, false
local dependencies = {
	BoatService = {
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
		build = function()
			builds += 1
			local tool = Instance.new("Tool")
			tool:SetAttribute("RodId", "StarterRod")
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
local fresh, character, root, humanoid, backpack = makePlayer(1)
Service.start()
flush()
local request = ReplicatedStorage:WaitForChild("Fishing"):WaitForChild("Request")
local feedback = ReplicatedStorage:WaitForChild("Fishing"):WaitForChild("Feedback")
local function send(player, action)
	now += 1
	request.OnServerEvent:Fire(player, action)
	flush()
end
check(rodCount(fresh) == 0 and builds == 0, "Unowned startup must not grant a Tool")
send(fresh, "EquipRod")
check(rodCount(fresh) == 0 and fresh:GetAttribute("RodEquipped") == false, "Unowned remote equip must be rejected")

local beforeMessages = #feedback.messages
root.Position = Vector3.new(0, 7, 0)
ProximityPromptService.PromptTriggered:Fire(prompt, fresh)
send(fresh, "PurchaseRod")
check(purchases == 0 and #feedback.messages == beforeMessages + 1, "Outside interior must neither open nor transact")
root.Position = Vector3.new(11, 0, 0)
send(fresh, "PurchaseRod")
check(purchases == 0, "Inside but beyond prompt range must be rejected")
root.Position = Vector3.zero
sightResult = { Instance = Instance.new("Part") }
send(fresh, "PurchaseRod")
check(purchases == 0, "An occluding wall must block remote purchases")
sightResult = nil
humanoid.Health = 0
send(fresh, "PurchaseRod")
check(purchases == 0, "Dead characters cannot buy")
humanoid.Health = 100
shop.Parent = nil
send(fresh, "PurchaseRod")
check(purchases == 0, "Tagged shops removed from workspace cannot authorize purchases")
shop.Parent = workspace

local foreignPrompt = Instance.new("ProximityPrompt")
foreignPrompt.Name, foreignPrompt.Parent = "BuyFishingRodPrompt", counter
beforeMessages = #feedback.messages
ProximityPromptService.PromptTriggered:Fire(foreignPrompt, fresh)
check(#feedback.messages == beforeMessages, "A different prompt with the same name must not open this shop")
sightResult = { Instance = counter }
ProximityPromptService.PromptTriggered:Fire(prompt, fresh)
check(feedback.messages[#feedback.messages].values[1] == "OpenShop", "A visible interior prompt must open the shop")
sightResult = nil
failSave = true
send(fresh, "PurchaseRod")
check(purchases == 1 and builds == 0 and rodCount(fresh) == 0, "A failed transaction must not grant/equip a rod")
check(fresh:GetAttribute("OwnsStarterRod") == false, "A failed purchase must not mark ownership")
failSave = false
send(fresh, "PurchaseRod")
check(purchases == 2 and builds == 1 and rodCount(fresh) == 1, "A successful purchase grants exactly one Tool")
local rod = character:FindFirstChildOfClass("Tool")
check(rod ~= nil and fresh:GetAttribute("RodEquipped") == true, "Purchase must auto-equip after ownership is confirmed")
check(rod:GetAttribute("OwnerUserId") == fresh.UserId, "Granted Tool must identify its owner")
for _ = 1, 3 do
	send(fresh, "EquipRod")
	send(fresh, "PurchaseRod")
end
check(builds == 1 and rodCount(fresh) == 1, "Repeated equip/purchase must retain the same single Tool")
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
print(
	"Fishing service: " .. checks .. " authorization and lifecycle checks passed (recording mocks; no Roblox runtime)."
)
