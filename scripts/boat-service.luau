-- Real BoatService source runs against recording mocks using check-boats.mjs.
-- This verifies permissions/transactions/lifecycle, not Roblox physics or networking.

local function signal()
	local handlers = {}
	return {
		Connect = function(_, callback)
			local connection = { connected = true }
			function connection:Disconnect()
				self.connected = false
			end
			table.insert(handlers, { callback = callback, connection = connection })
			return connection
		end,
		Fire = function(_, ...)
			for _, handler in handlers do
				if handler.connection.connected then
					handler.callback(...)
				end
			end
		end,
	}
end

local Vector3 = {}
local vectorMeta = {}
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, _kind = "Vector3" }, vectorMeta)
end
function vectorMeta.__add(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
function vectorMeta.__sub(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
function vectorMeta.__mul(a, b)
	return Vector3.new(a.X * b, a.Y * b, a.Z * b)
end
function vectorMeta.__unm(a)
	return Vector3.new(-a.X, -a.Y, -a.Z)
end
function vectorMeta.__index(a, key)
	if key == "Magnitude" then
		return math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z)
	end
	if key == "Unit" then
		return a * (1 / a.Magnitude)
	end
	if key == "Dot" then
		return function(_, b)
			return a.X * b.X + a.Y * b.Y + a.Z * b.Z
		end
	end
	if key == "Cross" then
		return function(_, b)
			return Vector3.new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
		end
	end
	return nil
end
Vector3.zero, Vector3.xAxis, Vector3.zAxis = Vector3.new(), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1)
local Vector2 = {
	new = function(x, y)
		return { X = x, Y = y }
	end,
	zero = { X = 0, Y = 0 },
}
local CFrame = {}
local frameMeta = {}
function CFrame.new(position)
	return setmetatable({
		Position = position or Vector3.zero,
		LookVector = Vector3.new(0, 0, -1),
		RightVector = Vector3.xAxis,
		UpVector = Vector3.new(0, 1, 0),
		_kind = "CFrame",
	}, frameMeta)
end
function frameMeta.__add(frame, offset)
	return CFrame.new(frame.Position + offset)
end
-- Only the identity parked offset is composed; it leaves the pose unchanged.
function frameMeta.__mul(offset, frame)
	assert(offset.identity, "Mock CFrames only compose the identity offset")
	return frame
end
function frameMeta.__index(frame, key)
	if key == "Rotation" then
		return frame
	end
	if key == "PointToObjectSpace" then
		return function(_, point)
			local delta = point - frame.Position
			return Vector3.new(delta:Dot(frame.RightVector), delta:Dot(frame.UpVector), -delta:Dot(frame.LookVector))
		end
	end
	if key == "VectorToWorldSpace" then
		return function(_, vector)
			return frame.RightVector * vector.X + frame.UpVector * vector.Y - frame.LookVector * vector.Z
		end
	end
	if key == "ToOrientation" then
		return function()
			return 0, 0, 0
		end
	end
	return nil
end
function CFrame.Angles(_, yaw)
	local frame = CFrame.new()
	frame.LookVector = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	frame.RightVector = Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
	return frame
end
function CFrame.fromMatrix(position, right, up, back)
	local frame = CFrame.new(position)
	frame.RightVector, frame.UpVector, frame.LookVector = right, up, -back
	return frame
end

local Enum = setmetatable({}, {
	__index = function(self, category)
		local values = setmetatable({}, {
			__index = function(_, value)
				return value
			end,
		})
		rawset(self, category, values)
		return values
	end,
})
local Instance = {}
local methods = {}
function Instance.new(kind)
	local instance = {
		ClassName = kind,
		Name = kind,
		children = {},
		attributes = {},
		signals = {},
		CanCollide = true,
		CollisionGroup = "Default",
		DescendantAdded = signal(),
		Destroying = signal(),
	}
	if kind == "RemoteEvent" then
		instance.OnServerEvent = signal()
		instance.messages = {}
	elseif kind == "TextChatCommand" then
		instance.Triggered = signal()
	end
	return setmetatable(instance, {
		__index = methods,
		__newindex = function(self, key, value)
			if key == "Parent" then
				local old = rawget(self, key)
				if old then
					local index = table.find(old.children, self)
					if index then
						table.remove(old.children, index)
					end
				end
				rawset(self, key, value)
				if value then
					table.insert(value.children, self)
					local ancestor = value
					while ancestor do
						ancestor.DescendantAdded:Fire(self)
						ancestor = ancestor.Parent
					end
				end
			end
			rawset(self, key, value)
		end,
	})
end
function methods:IsA(kind)
	return self.ClassName == kind
		or (kind == "BasePart" and table.find({ "Part", "VehicleSeat", "Seat" }, self.ClassName) ~= nil)
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
function methods:FindFirstChildOfClass(kind)
	for _, child in self.children do
		if child:IsA(kind) then
			return child
		end
	end
	return nil
end
function methods:GetDescendants()
	local result = {}
	for _, child in self.children do
		table.insert(result, child)
		for _, descendant in child:GetDescendants() do
			table.insert(result, descendant)
		end
	end
	return result
end
function methods:PivotTo(frame)
	self.lastPivot = frame
end
function methods:GetPivot()
	return self.lastPivot or CFrame.new()
end
function methods:RequestStreamAroundAsync(position)
	self.streamPosition = position
end
function methods:Sit(humanoid)
	self.Occupant, humanoid.SeatPart = humanoid, self
end
function methods:FindFirstAncestorOfClass(kind)
	local parent = self.Parent
	while parent do
		if parent:IsA(kind) then
			return parent
		end
		parent = parent.Parent
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
function methods:SetAttribute(key, value)
	self.attributes[key] = value
end
function methods:GetAttribute(key)
	return self.attributes[key]
end
function methods:GetPropertyChangedSignal(key)
	if not self.signals[key] then
		self.signals[key] = signal()
	end
	return self.signals[key]
end
function methods:FireClient(player, ...)
	table.insert(self.messages, { player = player, values = { ... } })
end
function methods:Destroy()
	self.Destroying:Fire()
	self.destroyed = true
	local old = self.Parent
	if old then
		local index = table.find(old.children, self)
		if index then
			table.remove(old.children, index)
		end
	end
	rawset(self, "Parent", nil)
end
function methods:SetNetworkOwner(owner)
	assert(not self.Anchored, "Cannot assign ownership to an anchored assembly")
	self.serverOwned = owner == nil
	self.ownerAssignments = (self.ownerAssignments or 0) + 1
end

local workspace = Instance.new("Workspace")
workspace.serverTime = 1000
workspace.Gravity = 196.2
function workspace:GetServerTimeNow()
	return self.serverTime
end
local overlaps = {}
local sightResult = nil
function workspace:Raycast()
	return sightResult
end
function workspace:GetPartBoundsInBox()
	return overlaps
end
local Players = Instance.new("Players")
local TextChatService = Instance.new("TextChatService")
Players.PlayerAdded, Players.PlayerRemoving = signal(), signal()
local playerList = {}
function Players:GetPlayers()
	return playerList
end
function Players:GetPlayerByUserId(userId)
	for _, player in playerList do
		if player.UserId == userId and player.Parent == self then
			return player
		end
	end
	return nil
end
function Players:GetPlayerFromCharacter(character)
	for _, player in playerList do
		if player.Character == character then
			return player
		end
	end
	return nil
end
local tags = {}
local CollectionService = {
	GetTagged = function(_, tag)
		return tags[tag] or {}
	end,
	HasTag = function(_, item, tag)
		return table.find(tags[tag] or {}, item) ~= nil
	end,
}
local store = { data = {}, gets = 0, updates = 0, getFailures = 0, updateFailures = 0 }
function store:GetAsync(key)
	self.gets += 1
	if self.getFailures > 0 then
		self.getFailures -= 1
		error("Load unavailable")
	end
	return self.data[key]
end
function store:UpdateAsync(key, transform)
	self.updates += 1
	if self.beforeUpdate then
		self.beforeUpdate()
	end
	local saved = transform(self.data[key])
	if self.retryTransform then
		-- UpdateAsync may discard and retry a transform with the current stored value.
		saved = transform(self.data[key])
	end
	if self.updateFailures > 0 then
		self.updateFailures -= 1
		error("Commit unavailable")
	end
	self.data[key] = saved
	return saved
end
local DataStoreService = {
	GetDataStore = function()
		return store
	end,
}
local ReplicatedStorage = Instance.new("ReplicatedStorage")
local RunService = {
	IsStudio = function()
		return true
	end,
	Heartbeat = signal(),
}
local ProximityPromptService = { PromptTriggered = signal() }
local services = {
	CollectionService = CollectionService,
	DataStoreService = DataStoreService,
	Players = Players,
	ProximityPromptService = ProximityPromptService,
	ReplicatedStorage = ReplicatedStorage,
	RunService = RunService,
	TextChatService = TextChatService,
}
local game = {
	GetService = function(_, name)
		return services[name]
	end,
}
local now = 100
local delayed = {}
local task = {
	delay = function(seconds, callback)
		table.insert(delayed, { at = now + seconds, callback = callback })
	end,
	wait = function() end,
	spawn = function(callback, ...)
		callback(...)
	end,
	defer = function(callback)
		callback()
	end,
}
local os = {
	time = function()
		return 1792713600
	end,
	clock = function()
		return now
	end,
}
local warnings = {}
local warn = function(message)
	table.insert(warnings, message)
end
local OverlapParams = {
	new = function()
		return {}
	end,
}
local RaycastParams = {
	new = function()
		return {}
	end,
}
local BoatData = (function()
	-- BOAT_DATA_SOURCE --
end)()
local builtBoats = {}
local Rowboat = {
	build = function(frame, anchored)
		assert(not anchored)
		local model = Instance.new("Model")
		model:SetAttribute("DryFloorHeight", 0.4)
		model:SetAttribute("DryFloorHalfBeam", 3.25)
		model:SetAttribute("DryFloorHalfLength", 7.1)
		local root = Instance.new("Part")
		root.AssemblyMass, root.AssemblyLinearVelocity = 100, Vector3.zero
		local rootFrame = CFrame.new(frame.Position + Vector3.new(0, -0.4, 0))
		root.Name, root.CFrame, root.Position, root.Parent = "Root", rootFrame, rootFrame.Position, model
		model.PrimaryPart = root
		local seat = Instance.new("VehicleSeat")
		seat.Name, seat.Parent = "RowerSeat", model
		seat.CFrame = CFrame.new(frame.Position + Vector3.new(0, 0.92, 0.6))
		table.insert(builtBoats, model)
		return model
	end,
}
local FishingBoat = {
	build = function(frame, anchored)
		local model = Rowboat.build(frame, anchored)
		model:SetAttribute("DryFloorHeight", nil)
		model:SetAttribute("DryFloorHalfBeam", nil)
		model:SetAttribute("DryFloorHalfLength", nil)
		model:FindFirstChild("RowerSeat").Name = "HelmSeat"
		for index = 1, 2 do
			local seat = Instance.new("Seat")
			seat.Name, seat.Parent = "PassengerSeat" .. index, model
		end
		model:SetAttribute("BoatId", "FishingBoat")
		return model
	end,
}
local waveHeight, waveNormal = 0, Vector3.new(0, 1, 0)
local waveSampleTime, waveSamplePosition
local parkedRelease
local launchReservations, launchRuns, launchReleases = {}, 0, 0
local launchBlocked, launchFails, duringLaunch = false, false, nil
local DrydockLaunch = {
	reserve = function(shop, player, boatId)
		if launchBlocked or launchReservations[shop] then
			return nil, "Launch busy"
		end
		local reservation = { shop = shop, player = player, boatId = boatId }
		launchReservations[shop] = reservation
		return reservation
	end,
	release = function(reservation)
		launchReleases += 1
		launchReservations[reservation.shop] = nil
	end,
	run = function(reservation, activate)
		launchRuns += 1
		if duringLaunch then
			return duringLaunch(reservation, activate)
		end
		if launchFails then
			error("Animation interrupted")
		end
		return true
	end,
}
local BoatCatalog = (function()
	-- BOAT_CATALOG_SOURCE --
end)()
local collisionGroups = { Default = true, OtherGameplay = true }
local collisionPairs = {}
function workspace:IsCollisionGroupRegistered(name)
	return collisionGroups[name] == true
end
function workspace:RegisterCollisionGroup(name)
	collisionGroups[name] = true
end
function workspace:GetRegisteredCollisionGroups()
	local groups = {}
	for name in collisionGroups do
		table.insert(groups, { name = name })
	end
	return groups
end
function workspace:CollisionGroupSetCollidable(a, b, enabled)
	collisionPairs[a .. ":" .. b], collisionPairs[b .. ":" .. a] = enabled, enabled
end
workspace.Terrain = Instance.new("Terrain")
local collisionMap = Instance.new("Folder")
collisionMap.Name, collisionMap.Parent = "Map", workspace
local island = Instance.new("Model")
island.Parent = collisionMap
local islandGround = Instance.new("Model")
islandGround.Name, islandGround.Parent = "Ground", island
local groundPart = Instance.new("Part")
groundPart.Parent = islandGround
local dockPart = Instance.new("Part")
dockPart.Parent = collisionMap
local BoatLaunchCollision = (function()
	-- BOAT_LAUNCH_COLLISION_SOURCE --
end)()
local dependencies = {
	BoatData = BoatData,
	Rowboat = Rowboat,
	FishingBoat = FishingBoat,
	DrydockLaunch = DrydockLaunch,
	BoatLaunchCollision = BoatLaunchCollision,
	BoatCatalog = BoatCatalog,
	Biomes = { WaterLevel = 0 },
	Weather = {
		Presets = { Clear = {}, LightRain = {}, Rain = {}, Storm = {} },
		sample = function(position, time)
			waveSamplePosition, waveSampleTime = position, time
			return { height = waveHeight, normal = waveNormal }
		end,
		parkedOffset = function(rest, parkedAt, time)
			parkedRelease = { rest = rest, parkedAt = parkedAt, time = time }
			local offset = CFrame.new()
			offset.identity = true
			return offset
		end,
	},
}
local function typeof(value)
	return if type(value) == "table" then value._kind or "table" else type(value)
end
local Service = (function()
	-- BOAT_SERVICE_SOURCE --
end)()

local checks = 0
local function check(condition, message)
	checks += 1
	assert(condition, message)
end
check(BoatData.PRICE == BoatCatalog.Rowboat.Price, "Displayed price and saved purchase price must agree")
local function makePlayer(id, cash, owned)
	local player = Instance.new("Player")
	player.UserId, player.Parent = id, Players
	local character = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name, root.Position, root.Parent = "HumanoidRootPart", Vector3.zero, character
	local humanoid = Instance.new("Humanoid")
	humanoid.Health, humanoid.Parent = 100, character
	player.Character = character
	table.insert(playerList, player)
	if cash ~= nil then
		store.data["Player_" .. id] = { Version = 1, Cash = cash, OwnedBoats = { Rowboat = owned == true } }
	end
	Service.loadPlayer(player)
	return player, root, humanoid
end
local function makePrompt(parent, name, position)
	local control = Instance.new("Part")
	control.Position, control.Parent = position or Vector3.zero, parent
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name, prompt.MaxActivationDistance, prompt.Parent = name, 10, control
	return prompt
end
local shop = Instance.new("Model")
shop.Parent = workspace
tags.BoatShop = { shop }
shop:SetAttribute("InteriorFrame", CFrame.new())
shop:SetAttribute("InteriorSize", Vector3.new(40, 16, 36))
local npc = Instance.new("Model")
npc.Parent = shop
local npcHumanoid = Instance.new("Humanoid")
npcHumanoid.Parent = npc
local buyPrompt = makePrompt(npc, "TalkToShipwrightPrompt")
buyPrompt.Parent.Name = "Head"
buyPrompt.MaxActivationDistance = 8
Service.start()
check(
	groundPart.CollisionGroup == "IslandGround" and workspace.Terrain.CollisionGroup == "IslandGround",
	"Saved island ground and terrain must remain solid during launch grace"
)
check(dockPart.CollisionGroup == "Default", "Dock structures must remain separate from island ground")
local freshGround = Instance.new("Part")
freshGround.Parent = islandGround
check(freshGround.CollisionGroup == "IslandGround", "Later generated island ground must also remain solid")
check(
	collisionPairs["DrydockLaunch:IslandGround"] == true
		and collisionPairs["DrydockLaunch:Default"] == false
		and collisionPairs["DrydockLaunch:DrydockLaunch"] == false
		and collisionPairs["DrydockLaunch:OtherGameplay"] == false,
	"Launch grace must collide only with islands, not players, props or other boats"
)
local feedback = ReplicatedStorage:FindFirstChild("Boating"):FindFirstChild("Feedback")
local request = ReplicatedStorage:FindFirstChild("Boating"):FindFirstChild("Request")
local fresh = makePlayer(1)
check(
	fresh:GetAttribute("Cash") == 0 and fresh:GetAttribute("OwnsRowboat") == false,
	"New players start with $0 and no boat"
)
check(fresh:GetAttribute("BoatDataStatus") == "Ready", "Fresh player profile must load")
local freshStats = fresh:FindFirstChild("leaderstats")
check(
	freshStats and freshStats:FindFirstChild("Level").Value == 1 and freshStats:FindFirstChild("Money").Value == 0,
	"The player list shows a new player's numeric level and money"
)
check(
	freshStats:FindFirstChild("Level"):IsA("IntValue")
		and freshStats:FindFirstChild("Money"):IsA("IntValue")
		and freshStats:FindFirstChild("Level"):FindFirstChild("IsPrimary").Value == true,
	"Level is the primary numeric stat used to rank players"
)
Service.purchase(fresh)
check(store.updates == 0 and fresh:GetAttribute("Cash") == 0, "Insufficient funds must not write or award money")

local rich, richRoot, richHumanoid = makePlayer(2, 1000)
local richStats = rich:FindFirstChild("leaderstats")
local richMoney = richStats:FindFirstChild("Money")
check(richMoney.Value == 1000, "The player list loads the saved wallet balance")
richRoot.Position = Vector3.new(13, 0, 0)
request.OnServerEvent:Fire(rich, "PurchaseRowboat")
check(store.updates == 0, "Remote purchase must validate server-side distance")
richRoot.Position = Vector3.zero
richHumanoid.Health = 0
check(not Service.nearPrompt(rich, buyPrompt), "Dead characters cannot activate purchase or spawn prompts")
Service.purchase(rich)
check(store.updates == 0, "A dead character cannot purchase")
richHumanoid.Health = 100
local messageCount = #feedback.messages
ProximityPromptService.PromptTriggered:Fire(buyPrompt, rich)
check(
	#feedback.messages == messageCount + 1
		and feedback.messages[#feedback.messages].values[1] == "OpenShop"
		and feedback.messages[#feedback.messages].values[2] == shop,
	"Talking to the NPC must open the purchase screen directly with its drydock preview"
)
request.OnServerEvent:Fire(rich, "BrowseRowboat")
check(
	feedback.messages[#feedback.messages].values[1] == "OpenShop",
	"The rowboat conversation choice opens the boat offer"
)
local wall = Instance.new("Part")
sightResult = { Instance = wall }
check(Service.shopPrompt(rich) == nil, "Players cannot talk or buy through walls")
messageCount = #feedback.messages
request.OnServerEvent:Fire(rich, "BrowseRowboat")
ProximityPromptService.PromptTriggered:Fire(buyPrompt, rich)
check(#feedback.messages == messageCount, "Blocked line of sight cannot open dialogue or a boat offer")
sightResult = { Instance = buyPrompt.Parent }
check(Service.shopPrompt(rich) == buyPrompt, "The NPC's own body must not obstruct interaction")
sightResult = nil
shop:SetAttribute("InteriorSize", Vector3.new(1, 16, 36))
richRoot.Position = Vector3.new(2, 0, 0)
check(Service.shopPrompt(rich) == nil, "Standing outside the interior cannot authorize even a nearby NPC interaction")
richRoot.Position = Vector3.zero
shop:SetAttribute("InteriorSize", Vector3.new(40, 16, 36))
npcHumanoid.ClassName = "Part"
check(Service.shopPrompt(rich) == nil, "A counter prop cannot impersonate a humanoid shipwright")
npcHumanoid.ClassName = "Humanoid"
shop.Parent = nil
check(Service.shopPrompt(rich) == nil, "A tagged shop outside Workspace cannot authorize purchases")
shop.Parent = workspace
local before = store.updates
Service.purchase(rich)
check(store.updates == before + 1, "Purchase must use one atomic UpdateAsync")
check(
	store.data.Player_2.Cash == 500 and store.data.Player_2.OwnedBoats.Rowboat,
	"Deduction and ownership must commit together"
)
check(
	rich:GetAttribute("Cash") == 500 and rich:GetAttribute("OwnsRowboat"),
	"Confirmed progress must be mirrored to attributes"
)
check(
	rich:FindFirstChild("leaderstats") == richStats and richStats:FindFirstChild("Money") == richMoney
		and richMoney.Value == 500 and #richStats:GetDescendants() == 3,
	"Purchases update the existing leaderboard values without duplicate stats"
)
Service.purchase(rich)
check(store.updates == before + 1 and rich:GetAttribute("Cash") == 500, "Repeated purchase must not charge twice")
local cashBefore = fresh:GetAttribute("Cash")
request.OnServerEvent:Fire(fresh, "SetCash", 1000000)
check(fresh:GetAttribute("Cash") == cashBefore and store.updates == before + 1, "Remote cannot grant currency")

store.getFailures = 3
local unavailable = makePlayer(3, 1000)
check(unavailable:GetAttribute("BoatDataStatus") == "Unavailable", "Failed load must disable trading")
before = store.updates
Service.purchase(unavailable)
check(
	store.updates == before and store.data.Player_3.Cash == 1000,
	"Unavailable data must never overwrite the saved profile"
)
local failing = makePlayer(4, 900)
store.updateFailures = 1
Service.purchase(failing)
check(
	failing:GetAttribute("Cash") == 900 and not failing:GetAttribute("OwnsRowboat"),
	"Failed commit must not change the profile mirror"
)
check(
	store.data.Player_4.Cash == 900 and not store.data.Player_4.OwnedBoats.Rowboat,
	"Failed commit must not mutate saved input"
)
check(not Service.profiles[failing].busy, "Failed commit must release the purchase guard")
local stale = makePlayer(5, 800)
store.data.Player_5.Cash = 200
Service.purchase(stale)
check(
	stale:GetAttribute("Cash") == 200 and not stale:GetAttribute("OwnsRowboat"),
	"Atomic purchase must use current stored funds rather than stale mirrors"
)
local concurrent = makePlayer(6, 1000)
before = store.updates
store.beforeUpdate = function()
	Service.purchase(concurrent)
end
Service.purchase(concurrent)
store.beforeUpdate = nil
check(
	store.updates == before + 1 and concurrent:GetAttribute("Cash") == 500,
	"Concurrent local purchase must not reenter a busy transaction"
)

local retrying = makePlayer(8, 1000)
store.retryTransform = true
Service.purchase(retrying)
store.retryTransform = false
check(
	retrying:GetAttribute("Cash") == 500 and retrying:GetAttribute("OwnsRowboat"),
	"Retried atomic transforms must charge only once"
)
local corrupt = makePlayer(9, 1000)
store.data.Player_9 = "invalid saved profile"
Service.purchase(corrupt)
check(store.data.Player_9 == "invalid saved profile", "Invalid stored progress must never be overwritten by a purchase")
check(
	corrupt:GetAttribute("Cash") == 1000 and not corrupt:GetAttribute("OwnsRowboat"),
	"Invalid stored progress must not alter the last confirmed mirror"
)
local departing = makePlayer(10, 1000)
store.beforeUpdate = function()
	Players.PlayerRemoving:Fire(departing)
end
Service.purchase(departing)
store.beforeUpdate = nil
check(Service.profiles[departing] == nil, "A purchase returning after departure must not recreate the removed profile")
check(
	departing:GetAttribute("Cash") == 1000 and not departing:GetAttribute("OwnsRowboat"),
	"A completed transaction must not publish to a departed session"
)

local base = Instance.new("Model")
base.Parent = workspace
base:SetAttribute("OwnerUserId", rich.UserId)
base:SetAttribute("BaseId", 1)
rich:SetAttribute("BaseId", 1)
tags.PlayerBase = { base }
local spawnPrompt = makePrompt(base, "SpawnRowboatPrompt")
local marker = Instance.new("Part")
marker.Name, marker.CFrame, marker.Parent = "BoatSpawn", CFrame.new(Vector3.new(0, 0, -50)), base
local other = makePlayer(7, 500, true)
other:SetAttribute("BaseId", 2)
Service.spawnBoat(other, spawnPrompt)
check(#builtBoats == 0, "An owner cannot spawn at another player's dock")
rich:SetAttribute("BaseId", 2)
Service.spawnBoat(rich, spawnPrompt)
check(#builtBoats == 0, "Dock ownership and current player BaseId must both match")
rich:SetAttribute("BaseId", 1)
base:SetAttribute("OwnerUserId", fresh.UserId)
fresh:SetAttribute("BaseId", 1)
Service.spawnBoat(fresh, spawnPrompt)
check(#builtBoats == 0, "A player without ownership cannot spawn a free boat")
base:SetAttribute("OwnerUserId", rich.UserId)
richRoot.Position = Vector3.new(100, 0, 0)
Service.spawnBoat(rich, spawnPrompt)
check(#builtBoats == 0, "Spawning must validate proximity to the actual dock control")
richRoot.Position = Vector3.zero
overlaps = { { CanCollide = true } }
Service.spawnBoat(rich, spawnPrompt)
check(#builtBoats == 0, "Blocked launch water must prevent spawning")
overlaps = {}
Service.spawnBoat(rich, spawnPrompt)
check(#builtBoats == 1 and Service.active[rich] ~= nil, "An owner can launch at their own clear dock")
check(
	(builtBoats[1].PrimaryPart.Position - marker.CFrame.Position - Vector3.new(0, -0.4, 0)).Magnitude < 0.00001
		and builtBoats[1]:GetAttribute("OwnerUserId") == rich.UserId,
	"Launch must use the player's dock marker and ownership"
)
check(builtBoats[1].PrimaryPart.serverOwned, "Spawned boat physics must remain server-owned")
local floatingBoat = Service.active[rich]
local function checkSuspension(boat, label)
	check(
		boat.float.RigidityEnabled == false and boat.heading.RigidityEnabled == false,
		label .. " must respect suspension force and speed limits during deck contacts"
	)
	check(
		boat.float.ForceLimitMode == Enum.ForceLimitMode.PerAxis
			and boat.float.ForceRelativeTo == Enum.ActuatorRelativeTo.World
			and boat.float.MaxAxesForce.X == 0 and boat.float.MaxAxesForce.Z == 0,
		label .. " waterline must never pull sideways against the drive motor"
	)
	check(
		boat.float.ApplyAtCenterOfMass and boat.lift.ApplyAtCenterOfMass
			and boat.lift.RelativeTo == Enum.ActuatorRelativeTo.World
			and boat.lift.Attachment0 == boat.float.Attachment0,
		label .. " vertical support must not apply an off-center or tilted force"
	)
	check(
		(boat.lift.Force - Vector3.new(0, boat.root.AssemblyMass * workspace.Gravity, 0)).Magnitude < 0.00001,
		label .. " soft suspension must support the current assembly weight without sag"
	)
	check(
		boat.float.MaxVelocity > 0 and boat.float.MaxVelocity <= 6
			and boat.heading.MaxAngularVelocity > 0 and boat.heading.MaxAngularVelocity <= 2
			and boat.float.MaxAxesForce.Y > boat.lift.Force.Y
			and boat.float.MaxAxesForce.Y < math.huge
			and boat.heading.MaxTorque > 0 and boat.heading.MaxTorque < math.huge,
		label .. " suspension must have bounded corrections with spare capacity for standing passengers"
	)
end
checkSuspension(floatingBoat, "Dock rowboat")
local function checkParked(boat, label)
	check(boat.parked and boat.root.Anchored and boat.model:GetAttribute("Parked"), label .. " must be a fixed platform")
	check(
		not boat.float.Enabled and not boat.lift.Enabled and not boat.heading.Enabled and not boat.velocity.Enabled,
		label .. " must disable every force controller"
	)
	check(boat.speed == 0 and boat.turn == 0, label .. " must clear stored motion")
	check(boat.model:GetAttribute("RowThrottle") == 0 and boat.model:GetAttribute("RowSteer") == 0, label .. " must stop rowing animation")
end
checkParked(floatingBoat, "New dock boat")
local heldFrame, heldSupport = floatingBoat.root.CFrame, floatingBoat.lift.Force
-- Roblox reports infinite assembly mass for an anchored hull. Idle updates must
-- neither feed infinity to a mover nor reposition the deck to chase waves.
floatingBoat.root.AssemblyMass = math.huge
waveHeight = 1.5
for _ = 1, 300 do RunService.Heartbeat:Fire(1 / 60) end
checkParked(floatingBoat, "Boat while standing on deck")
check(floatingBoat.root.CFrame == heldFrame and floatingBoat.lift.Force == heldSupport, "Idle waves must not move the deck or recalculate support with infinite mass")
floatingBoat.root.AssemblyMass = 100
floatingBoat.seat.Occupant = { Parent = rich.Character }
floatingBoat.throttle, floatingBoat.steer, floatingBoat.lastInput = 0, 0.04, now
RunService.Heartbeat:Fire(1 / 60)
checkParked(floatingBoat, "Neutral helm and analog drift")
floatingBoat.seat.Occupant = { Parent = fresh.Character }
floatingBoat.throttle = 1
RunService.Heartbeat:Fire(1 / 60)
checkParked(floatingBoat, "Unauthorized helm input")
floatingBoat.seat.Occupant = { Parent = rich.Character }
sightResult = { Material = Enum.Material.Water }
RunService.Heartbeat:Fire(1 / 60)
checkSuspension(floatingBoat, "Released rowboat")
check(not floatingBoat.root.Anchored and not floatingBoat.parked and floatingBoat.velocity.Enabled, "Owner input must release the boat and enable driving")
check(floatingBoat.root.ownerAssignments == 2, "Release must explicitly restore server ownership after unanchoring")
check(
	parkedRelease and parkedRelease.rest == heldFrame and parkedRelease.time == workspace.serverTime
		and floatingBoat.model:GetAttribute("ParkedAt") == parkedRelease.parkedAt,
	"Release must start from the pose clients bobbed the parked hull to"
)
check(
	math.abs(floatingBoat.float.Position.Y - 1.1) < 0.00001,
	"A moving boat must follow waves while preserving its root offset"
)
check(
	waveSampleTime == workspace.serverTime and waveSamplePosition == floatingBoat.root.Position,
	"Boat buoyancy must sample the same synchronized wave clock and world position as visible water"
)
waveHeight, waveNormal = -1, Vector3.new(0.25, 1, 0.2).Unit
floatingBoat.yaw = math.pi / 2
floatingBoat.speed, floatingBoat.turn = 0, 0
floatingBoat.steer = 0
floatingBoat.seat.Occupant = { Parent = rich.Character }
floatingBoat.throttle, floatingBoat.lastInput = 1, now
floatingBoat.root.AssemblyMass = 200
sightResult = { Material = Enum.Material.Water }
RunService.Heartbeat:Fire(1 / 60)
checkSuspension(floatingBoat, "Occupied rowboat")
check(
	floatingBoat.float.Position.Y + 0.8 * waveNormal.Y
		- math.abs(floatingBoat.heading.CFrame.RightVector.Y) * 3.25
		- math.abs(floatingBoat.heading.CFrame.LookVector.Y) * 7.1 >= 0.35 - 0.00001,
	"Occupied rowboat must keep its lowest sole corner clear in a trough"
)
check(
	(floatingBoat.heading.CFrame.UpVector - waveNormal).Magnitude < 0.00001
		and math.abs(floatingBoat.heading.CFrame.LookVector:Dot(waveNormal)) < 0.00001,
	"Pitch and roll must follow the sampled wave normal at a turned heading"
)
check(
	math.abs(floatingBoat.velocity.PlaneVelocity.X + BoatCatalog.Rowboat.Acceleration / 60) < 0.00001
		and math.abs(floatingBoat.velocity.PlaneVelocity.Y) < 0.00001,
	"Tilting the hull must preserve gradual horizontal acceleration and heading"
)
floatingBoat.seat.Occupant = nil
floatingBoat.root.AssemblyMass = 100
RunService.Heartbeat:Fire(1 / 60)
checkSuspension(floatingBoat, "Rowboat after dismount")
local originalGravity = workspace.Gravity
workspace.Gravity = 100
RunService.Heartbeat:Fire(1 / 60)
checkSuspension(floatingBoat, "Rowboat with changed gravity")
workspace.Gravity = originalGravity
for _ = 1, 300 do RunService.Heartbeat:Fire(1 / 60) end
checkParked(floatingBoat, "Boat after dismounting and coasting to rest")
check(floatingBoat.root.AssemblyLinearVelocity.Magnitude == 0 and floatingBoat.root.AssemblyAngularVelocity.Magnitude == 0, "Parking must clear residual linear and angular velocity")
floatingBoat.seat.Occupant = { Parent = rich.Character }
floatingBoat.throttle, floatingBoat.steer, floatingBoat.lastInput = 0, 0.5, now
RunService.Heartbeat:Fire(1 / 60)
check(not floatingBoat.parked and floatingBoat.turn > 0, "Steering in place must also release the hull")
floatingBoat.steer = 0
for _ = 1, 300 do RunService.Heartbeat:Fire(1 / 60) end
checkParked(floatingBoat, "Neutral helm after turning")
floatingBoat.seat.Occupant = nil
waveHeight, waveNormal, sightResult = 0, Vector3.new(0, 1, 0), nil
Service.spawnBoat(rich, spawnPrompt)
check(#builtBoats == 1, "Rapid spawn retries must be limited")
now += 5
Service.active[rich].seat.Occupant = { Parent = rich.Character }
Service.spawnBoat(rich, spawnPrompt)
check(#builtBoats == 1 and not builtBoats[1].destroyed, "Occupied boats must not be replaced")
Service.active[rich].seat.Occupant = nil
overlaps = { { CanCollide = true } }
Service.spawnBoat(rich, spawnPrompt)
check(#builtBoats == 1 and not builtBoats[1].destroyed, "Blocked respawn must preserve the player's existing boat")
overlaps = {}
Service.spawnBoat(rich, spawnPrompt)
check(#builtBoats == 2 and builtBoats[1].destroyed, "Respawn must replace the previous boat to enforce one active boat")
Players.PlayerRemoving:Fire(rich)
check(
	builtBoats[2].destroyed and Service.active[rich] == nil and Service.profiles[rich] == nil,
	"Leaving must remove the boat and in-memory profile"
)
check(#feedback.messages > 0, "Rejected and successful actions must provide player feedback")
local rodBuyer = makePlayer(51, 700, true)
before = store.updates
local rodSuccess = Service.purchaseRod(rodBuyer)
check(
	rodSuccess and store.updates == before + 1,
	"Rod ownership must be committed atomically in the existing wallet store"
)
check(
	rodBuyer:GetAttribute("OwnsStarterRod") == true
		and rodBuyer:GetAttribute("Cash") == 700
		and rodBuyer:GetAttribute("OwnsRowboat"),
	"A free rod must preserve cash and existing boats"
)
Service.purchaseRod(rodBuyer)
check(store.updates == before + 1, "Repeated rod purchase requests must not write again")
local rodFailure = makePlayer(52, 1000)
store.updateFailures = 1
local failedRod = Service.purchaseRod(rodFailure)
check(
	not failedRod and rodFailure:GetAttribute("OwnsStarterRod") == false and not store.data.Player_52.OwnedRods,
	"A failed save must never award a rod"
)
check(not Service.profiles[rodFailure].busy, "A failed rod save must release the shared purchase lock")
before = store.updates
local unavailableRod = Service.purchaseRod(unavailable)
check(not unavailableRod and store.updates == before, "Unavailable wallets cannot save rod purchases")
local concurrentRod = makePlayer(53, 1000)
before = store.updates
store.beforeUpdate = function()
	Service.purchase(concurrentRod)
	Service.purchaseRod(concurrentRod)
end
check(Service.purchaseRod(concurrentRod), "First rod transaction must complete")
store.beforeUpdate = nil
check(
	store.updates == before + 1 and concurrentRod:GetAttribute("Cash") == 1000,
	"Boat and rod purchases must share the same reentrancy lock"
)
local rodThenBoat = makePlayer(54, 1000)
check(Service.purchaseRod(rodThenBoat), "Rod transaction must succeed before buying a boat")
Service.purchase(rodThenBoat)
check(
	rodThenBoat:GetAttribute("Cash") == 500
		and rodThenBoat:GetAttribute("OwnsStarterRod")
		and rodThenBoat:GetAttribute("OwnsRowboat"),
	"Buying a boat after a rod must retain both inventories"
)
local rodRetry = makePlayer(55)
store.retryTransform = true
check(Service.purchaseRod(rodRetry), "Retried rod transforms must succeed")
store.retryTransform = false
check(
	rodRetry:GetAttribute("Cash") == 0 and rodRetry:GetAttribute("OwnsStarterRod"),
	"Retried rod transforms must retain free pricing and ownership"
)
local rodCorrupt = makePlayer(56, 700)
store.data.Player_56 = "corrupt"
check(
	not Service.purchaseRod(rodCorrupt) and store.data.Player_56 == "corrupt",
	"Rod purchases must not overwrite corrupt saved data"
)
local rodDeparture = makePlayer(57, 700)
store.beforeUpdate = function()
	Players.PlayerRemoving:Fire(rodDeparture)
end
check(not Service.purchaseRod(rodDeparture), "A departed session must not receive rod ownership publication")
store.beforeUpdate = nil
check(
	not rodDeparture:GetAttribute("OwnsStarterRod") and Service.profiles[rodDeparture] == nil,
	"A returning save must not recreate a departed rod buyer"
)
local admin = makePlayer(2541746813, 700, true)
local setCommand = TextChatService:FindFirstChild("SetCommand")
check(setCommand and setCommand.PrimaryAlias == "/set", "The server must register the /set chat command")
store.data.Player_2541746813.OwnedRods = { StarterRod = true }
local function command(player, message)
	setCommand.Triggered:Fire({ UserId = player.UserId }, message)
end
local weatherMessages = #feedback.messages
fresh.Name, fresh.DisplayName = "hyperlinkhyper", "hyperlinkhyper"
command(fresh, "/set weather Storm")
command(fresh, "/set weather list")
check(
	workspace:GetAttribute("WeatherOverride") == nil and #feedback.messages == weatherMessages,
	"Only hyperlinkhyper's user ID may set or list weather, even if another player spoofs the name"
)
setCommand.Triggered:Fire(nil, "/set weather Storm")
setCommand.Triggered:Fire({ UserId = -999 }, "/set weather Storm")
check(workspace:GetAttribute("WeatherOverride") == nil, "Missing or unknown senders cannot change weather")
before = store.updates
for _, kind in { "Clear", "LightRain", "Rain", "Storm" } do
	command(admin, "/set weather " .. kind)
	check(workspace:GetAttribute("WeatherOverride") == kind, "Each weather preset must be selectable")
end
command(admin, "/SET WEATHER light rain  ")
check(workspace:GetAttribute("WeatherOverride") == "LightRain", "Weather input accepts casing and spaced light rain")
command(admin, "/set weather list")
local weatherNotice = feedback.messages[#feedback.messages]
check(
	weatherNotice.player == admin
		and weatherNotice.values[1] == "Notice"
		and weatherNotice.values[2] == "Weather types: Clear, LightRain, Rain, Storm.",
	"The weather list must privately show every available type"
)
check(workspace:GetAttribute("WeatherOverride") == "LightRain", "Listing weather must preserve the current override")
for _, invalid in { "/set weather", "/set weather snow", "/set weather Storm extra", "/set weather list extra" } do
	command(admin, invalid)
	check(
		workspace:GetAttribute("WeatherOverride") == "LightRain",
		"Invalid weather input must preserve the current override"
	)
end
check(store.updates == before, "Weather commands must work independently of wallet saves")
workspace:SetAttribute("WeatherOverride", nil)
before = store.updates
command(fresh, "/set cash 9999")
check(store.updates == before and fresh:GetAttribute("Cash") == 0, "Only the allowed user ID may set cash")
for _, invalid in
	{
		"/set cash -1",
		"/set cash 1.5",
		"/set cash nan",
		"/set cash inf",
		"/set cash 9007199254740992",
		"/set cash 100 extra",
		"/set cash",
		"/set boats 100",
	}
do
	command(admin, invalid)
end
check(store.updates == before, "Malformed or unsafe amounts must never write the wallet")
command(admin, "/set cash 12345")
check(
	admin:GetAttribute("Cash") == 12345 and store.data.Player_2541746813.Cash == 12345,
	"Set cash must save and publish the exact amount"
)
check(
	admin:GetAttribute("OwnsRowboat") and admin:GetAttribute("OwnsStarterRod"),
	"Set cash must preserve saved boat and rod ownership"
)
command(admin, "/set cash 0")
check(admin:GetAttribute("Cash") == 0, "Zero is a valid exact balance")
store.updateFailures = 1
command(admin, "/set cash 99")
check(
	admin:GetAttribute("Cash") == 0 and store.data.Player_2541746813.Cash == 0,
	"Failed saves must not publish or retain a new balance"
)
before = store.updates
store.beforeUpdate = function()
	command(admin, "/set cash 999")
	Service.purchaseRod(admin)
end
store.retryTransform = true
command(admin, "/set cash 500")
store.beforeUpdate, store.retryTransform = nil, false
check(
	store.updates == before + 1 and admin:GetAttribute("Cash") == 500,
	"Cash changes share the wallet lock and remain exact across transform retries"
)
Service.profiles[admin].status = "Unavailable"
before = store.updates
command(admin, "/set cash 100")
check(store.updates == before, "Unavailable wallets cannot be changed by the command")
Service.profiles[admin].status = "Ready"
store.data.Player_2541746813 = "corrupt"
command(admin, "/set cash 100")
check(
	store.data.Player_2541746813 == "corrupt" and admin:GetAttribute("Cash") == 500,
	"Set cash must never overwrite corrupt saved data"
)
-- New purchase orchestration: the controller is isolated above so existing
-- wallet/physics checks stay independent of the geometry animation harness.
local buyer = makePlayer(80, 1000)
local otherBuyer = makePlayer(81, 1000)
before = store.updates
local runsBefore = launchRuns
launchBlocked = true
Service.purchase(buyer)
launchBlocked = false
check(store.updates == before and not buyer:GetAttribute("OwnsRowboat"), "Blocked launch must reject before charging")
store.updateFailures = 1
local releasesBefore = launchReleases
Service.purchase(buyer)
check(
	launchRuns == runsBefore and launchReleases == releasesBefore + 1 and next(launchReservations) == nil,
	"Save failure must release the bay and never animate or award a boat"
)
check(
	not buyer:GetAttribute("OwnsRowboat") and buyer:GetAttribute("Cash") == 1000,
	"Failed launch purchase must preserve wallet mirrors"
)
before = store.updates
local boatsBefore = #builtBoats
local launchedModel = Rowboat.build(CFrame.new(Vector3.new(0, 0, 100)), false)
local launchFrame = CFrame.new(Vector3.new(0, 0, 100))
duringLaunch = function(reservation, activate)
	check(
		reservation.player == buyer and buyer:GetAttribute("OwnsRowboat"),
		"Ownership must commit before the launch animation"
	)
	Service.purchase(otherBuyer)
	check(
		store.updates == before + 1 and not otherBuyer:GetAttribute("OwnsRowboat"),
		"Another buyer must not pay for an occupied drydock"
	)
	Service.spawnBoat(buyer, spawnPrompt)
	check(Service.active[buyer] == nil, "Plot respawn cannot bypass a launch in progress")
	return activate(buyer, launchFrame, launchedModel)
end
Service.purchase(buyer)
duringLaunch = nil
check(
	store.updates == before + 1 and buyer:GetAttribute("Cash") == 500,
	"Successful drydock purchase must charge exactly once"
)
check(
	Service.active[buyer].model == launchedModel and #builtBoats == boatsBefore + 1,
	"Activation must reuse the purchased display rather than build a second boat"
)
check(
	Service.active[buyer].seat.Occupant == buyer.Character:FindFirstChildOfClass("Humanoid"),
	"Launch must seat the buyer in the actual driving seat"
)
check(
	buyer.Character.lastPivot ~= nil and buyer.streamPosition == launchedModel.PrimaryPart.Position,
	"Boarding must stream the boat and teleport the buyer to it"
)
check(
	launchedModel.PrimaryPart.Anchored == true
		and not Service.active[buyer].seat.Disabled
		and Service.active[buyer].seat.CanTouch,
	"Purchased preview must park afloat with normal seat entry"
)
check(next(launchReservations) == nil, "Completed purchase must release its reservation")
checkSuspension(Service.active[buyer], "Drydock rowboat")
do
	local boat = Service.active[buyer]
	local initialGroup = "Default"
	check(
		boat.root.CollisionGroup == "DrydockLaunch" and boat.launchGraceUntil == now + 10,
		"First drydock launch must apply ten seconds of collision grace"
	)
	check(
		boat.model:GetAttribute("LaunchGraceEndsAt") == workspace.serverTime + 10,
		"Collision grace must publish its exact expiry"
	)
	local latePart = Instance.new("Part")
	latePart.CollisionGroup = "OtherGameplay"
	latePart.Parent = boat.model
	check(latePart.CollisionGroup == "DrydockLaunch", "Parts added during grace must inherit launch filtering")
	boat.throttle, boat.lastInput = 1, now
	sightResult = { Material = Enum.Material.Wood }
	RunService.Heartbeat:Fire(1 / 60)
	check(
		boat.clearWater and math.abs(boat.velocity.PlaneVelocity.Y + BoatCatalog.Rowboat.Acceleration / 60) < 0.00001,
		"A dock or nearby prop must not block driving during collision grace"
	)
	now += 9.99
	boat.lastInput = now
	RunService.Heartbeat:Fire(1 / 60)
	check(boat.root.CollisionGroup == "DrydockLaunch" and boat.clearWater, "Grace must last the full ten seconds")
	now += 0.02
	for _, timer in delayed do
		if timer.at <= now then
			timer.callback()
		end
	end
	boat.lastInput = now
	RunService.Heartbeat:Fire(1 / 60)
	check(
		boat.root.CollisionGroup == initialGroup
			and latePart.CollisionGroup == "OtherGameplay"
			and boat.model:GetAttribute("LaunchGraceEndsAt") == nil,
		"Expiry must restore each part's original collision group"
	)
	check(
		not boat.clearWater and boat.velocity.PlaneVelocity.Y == 0,
		"Normal obstacle handling must resume after expiry"
	)
	local afterGrace = Instance.new("Part")
	afterGrace.Parent = boat.model
	check(afterGrace.CollisionGroup == "Default", "Expiry must disconnect grace filtering for future parts")
	sightResult = nil
end
Service.purchase(buyer)
check(store.updates == before + 1, "Repeated buy must not charge or launch twice")
local interrupted = makePlayer(82, 1000)
launchFails = true
Service.purchase(interrupted)
launchFails = false
check(
	interrupted:GetAttribute("OwnsRowboat") and interrupted:GetAttribute("Cash") == 500,
	"An interrupted launch must retain the saved boat"
)
check(next(launchReservations) == nil, "An interrupted launch must release its bay")
local departedBuyer = makePlayer(83, 1000)
runsBefore = launchRuns
store.beforeUpdate = function()
	Players.PlayerRemoving:Fire(departedBuyer)
end
Service.purchase(departedBuyer)
store.beforeUpdate = nil
check(
	launchRuns == runsBefore and next(launchReservations) == nil,
	"Departure during save must release the drydock without launching"
)
local menuPlayer = makePlayer(91, 1000)
check(
	Service.updateProgress(menuPlayer, function(profile)
		profile.Angler.Settings.MasterVolume = 30
	end),
	"Menu settings commit through the wallet's atomic store"
)
check(store.data.Player_91.Angler.Settings.MasterVolume == 30, "Settings persist in stored output")
local snapshot = Service.getProfile(menuPlayer)
snapshot.Angler.Settings.MasterVolume = 0
check(
	Service.getProfile(menuPlayer).Angler.Settings.MasterVolume == 30,
	"Menu snapshots cannot mutate the live profile"
)
store.retryTransform = true
check(
	Service.updateProgress(menuPlayer, function(profile)
		profile.Angler.Stats.Deaths += 1
	end),
	"Progress retries can commit"
)
store.retryTransform = false
check(store.data.Player_91.Angler.Stats.Deaths == 1, "UpdateAsync retry must not double-count progress")
store.updateFailures = 1
check(not Service.updateProgress(menuPlayer, function(profile)
	profile.Angler.Settings.MasterVolume = 90
end), "Failed settings writes report failure")
check(
	Service.getProfile(menuPlayer).Angler.Settings.MasterVolume == 30
		and store.data.Player_91.Angler.Settings.MasterVolume == 30,
	"Failed writes preserve saved settings and mirrors"
)
check(not Service.profiles[menuPlayer].busy, "Failed menu writes release the shared transaction lock")
Service.profiles[menuPlayer].busy = true
check(not Service.updateProgress(menuPlayer, function()
	error("Must never run while locked")
end), "Menus honor the purchase lock")
Service.profiles[menuPlayer].busy = false
check(
	Service.purchaseRod(menuPlayer) and store.data.Player_91.Angler.Settings.MasterVolume == 30,
	"Equipment purchases preserve menu progress"
)
store.retryTransform = true
check(
	Service.updateProgress(menuPlayer, function(profile)
		profile.Angler.Stats.TotalCaught += 1
		profile.Angler.Stats.TotalXP += 100
		profile.Angler.Stats.CoinsEarned += 250
		profile.Cash += 250
	end),
	"Gameplay awards commit through the same atomic wallet update"
)
store.retryTransform = false
local awarded = store.data.Player_91.Angler
local menuStats = menuPlayer:FindFirstChild("leaderstats")
check(
	menuStats:FindFirstChild("Money").Value == store.data.Player_91.Cash
		and menuStats:FindFirstChild("Level").Value == 1,
	"Committed gameplay earnings update the player list"
)
check(
	menuPlayer:GetAttribute("Level") == 1
		and menuPlayer:GetAttribute("LevelXP") == 100
		and menuPlayer:GetAttribute("LevelXPRequired") == 1000,
	"Server publishes saved XP using the progressive curve for the level bar"
)
check(
	awarded.Stats.TotalXP == 100
		and awarded.Weekly.XP == 100
		and awarded.Weekly.Caught == 1
		and awarded.Weekly.Earned == 250,
	"Saved award and weekly deltas commit once when UpdateAsync retries"
)
store.updateFailures = 1
check(not Service.updateProgress(menuPlayer, function(profile)
	profile.Angler.Stats.TotalXP += 1000
	profile.Cash += 100
end), "Failed XP award reports failure")
check(
	store.data.Player_91.Angler.Stats.TotalXP == 100 and store.data.Player_91.Angler.Weekly.XP == 100,
	"Failed awards change neither lifetime XP nor weekly XP"
)
check(
	menuStats:FindFirstChild("Level").Value == 1
		and menuStats:FindFirstChild("Money").Value == store.data.Player_91.Cash,
	"Failed saves cannot publish uncommitted money or levels on the leaderboard"
)
check(
	Service.updateProgress(menuPlayer, function(profile)
		profile.Angler.Stats.TotalXP += 4400
	end),
	"XP can advance across several levels"
)
check(
	menuPlayer:GetAttribute("Level") == 3
		and menuPlayer:GetAttribute("LevelXP") == 1500
		and menuPlayer:GetAttribute("LevelXPRequired") == 3000,
	"Level bar and saved-profile leaderboard share progressive XP thresholds"
)
check(
	menuPlayer:FindFirstChild("leaderstats") == menuStats and menuStats:FindFirstChild("Level").Value == 3,
	"Saved XP immediately updates the primary player-list ranking stat"
)

-- Fishing boat uses the same saved wallet, but its own inventory and driving spec.
local fisher, fisherRoot, fisherHumanoid = makePlayer(110, 3000, true)
check(
	fisher:GetAttribute("OwnsFishingBoat") == false,
	"Legacy rowboat saves publish missing fishing ownership as false"
)
request.OnServerEvent:Fire(fisher, "BrowseBoat", "FishingBoat")
check(
	feedback.messages[#feedback.messages].values[3] == "FishingBoat",
	"Browsing returns the selected fishing boat for its preview"
)
before = store.updates
for _, badId in { "UnknownBoat", 123, {}, false } do
	request.OnServerEvent:Fire(fisher, "PurchaseBoat", badId)
	request.OnServerEvent:Fire(fisher, "SpawnBoat", badId)
end
check(store.updates == before, "Invalid client boat IDs cannot write to the wallet")
local fisherDisplay = FishingBoat.build(CFrame.new(Vector3.new(0, 0, 100)), false)
for _, piece in fisherDisplay:GetDescendants() do
	if piece:IsA("Seat") or piece:IsA("VehicleSeat") then
		piece.Disabled = true
	end
end
duringLaunch = function(reservation, activate)
	check(reservation.boatId == "FishingBoat", "The selected boat must reserve its own drydock preview")
	return activate(fisher, launchFrame, fisherDisplay)
end
store.retryTransform = true
request.OnServerEvent:Fire(fisher, "PurchaseBoat", "FishingBoat")
store.retryTransform, duringLaunch = false, nil
check(
	fisher:GetAttribute("Cash") == 500 and fisher:GetAttribute("OwnsFishingBoat"),
	"Fishing purchase atomically saves its own $2500 price"
)
check(fisher:GetAttribute("OwnsRowboat"), "Buying the fishing boat retains wooden boat ownership")
local workingFisher = Service.active[fisher]
checkSuspension(workingFisher, "Drydock fishing boat")
check(
	workingFisher.model == fisherDisplay and workingFisher.seat.Name == "HelmSeat",
	"Fishing display becomes the working boat and uses its helm"
)
for _, piece in fisherDisplay:GetDescendants() do
	if piece:IsA("Seat") or piece:IsA("VehicleSeat") then
		check(not piece.Disabled and piece.CanTouch, "All preview seats must become usable after launch")
	end
end
workingFisher.root.AssemblyMass = 230
workingFisher.throttle, workingFisher.lastInput = 1, now
RunService.Heartbeat:Fire(1 / 60)
checkSuspension(workingFisher, "Fishing boat with passengers")
workingFisher.root.AssemblyMass = 100
RunService.Heartbeat:Fire(1 / 60)
checkSuspension(workingFisher, "Fishing boat after passengers leave")
workingFisher.yaw = 0
workingFisher.speed, workingFisher.turn = 0, 0
workingFisher.throttle, workingFisher.steer, workingFisher.lastInput = 1, 0, now
RunService.Heartbeat:Fire(1 / 60)
check(math.abs(workingFisher.velocity.PlaneVelocity.Y + BoatCatalog.FishingBoat.Acceleration / 60) < 0.00001, "Fishing boat starts with bounded acceleration")
for _ = 1, 1200 do
	-- Model a lagging actuator rather than treating requested speed as actual.
	local measured = workingFisher.root.AssemblyLinearVelocity
	local requested = Vector3.new(workingFisher.velocity.PlaneVelocity.X, 0, workingFisher.velocity.PlaneVelocity.Y)
	workingFisher.root.AssemblyLinearVelocity = measured + (requested - measured) * (1 - math.exp(-4 / 60))
	RunService.Heartbeat:Fire(1 / 60)
end
check(-workingFisher.root.AssemblyLinearVelocity.Z > 39.5, "Real service must build faster cruise speed despite actuator lag")
workingFisher.root.AssemblyLinearVelocity = Vector3.new(0, 0, -40)
workingFisher.speed = 40
RunService.Heartbeat:Fire(1 / 60)
check(workingFisher.velocity.PlaneVelocity.Y == -40, "Fishing boat reaches its faster top speed")
workingFisher.throttle = -1
RunService.Heartbeat:Fire(1 / 60)
check(math.abs(workingFisher.velocity.PlaneVelocity.Y + 40 - BoatCatalog.FishingBoat.BrakeDeceleration / 60) < 0.00001, "Reversing brakes before changing direction")
workingFisher.root.AssemblyLinearVelocity = Vector3.zero
workingFisher.speed = 0
RunService.Heartbeat:Fire(1 / 60)
check(math.abs(workingFisher.velocity.PlaneVelocity.Y - BoatCatalog.FishingBoat.Acceleration / 60) < 0.00001, "A stopped hull restarts gently in reverse")
workingFisher.root.AssemblyLinearVelocity = Vector3.new(0, 0, 14)
workingFisher.speed = -14
RunService.Heartbeat:Fire(1 / 60)
check(workingFisher.velocity.PlaneVelocity.Y == 14, "Fishing boat reaches its faster reverse top speed")
workingFisher.throttle, workingFisher.steer = 0, 1
RunService.Heartbeat:Fire(0.1)
check(
	math.abs(workingFisher.yaw - 0.018) < 0.00001,
	"Fishing boat steering responds faster while easing into its reverse turn rate"
)
check(
	workingFisher.velocity.ForceLimitsEnabled == false,
	"Velocity ramp must have enough solver force to overcome water drag"
)
request.OnServerEvent:Fire(otherBuyer, "Row", 1, 1)
check(workingFisher.steer == 1, "Other players cannot send controls to this boat")
workingFisher.seat.Occupant = nil
local passenger = fisherDisplay:FindFirstChild("PassengerSeat1")
passenger.Occupant = { Parent = otherBuyer.Character }
base:SetAttribute("OwnerUserId", fisher.UserId)
fisher:SetAttribute("BaseId", 1)
local boatsBeforeDock = #builtBoats
Service.spawnBoat(fisher, spawnPrompt, "FishingBoat")
check(
	#builtBoats == boatsBeforeDock and not fisherDisplay.destroyed,
	"A passenger must leave before its boat can be replaced"
)
passenger.Occupant = nil
local messagesBeforeDock = #feedback.messages
ProximityPromptService.PromptTriggered:Fire(spawnPrompt, fisher)
check(
	#feedback.messages == messagesBeforeDock + 1 and feedback.messages[#feedback.messages].values[1] == "OpenDock",
	"The owner dock opens a chooser without replacing a boat"
)
request.OnServerEvent:Fire(fisher, "SpawnBoat", "FishingBoat")
local respawnFisher = Service.active[fisher]
checkSuspension(respawnFisher, "Dock fishing boat")
check(
	respawnFisher.model:GetAttribute("BoatId") == "FishingBoat" and fisherDisplay.destroyed,
	"Dock selection respawns the owned fishing boat"
)
check(
	math.abs(respawnFisher.root.Position.Z - (marker.CFrame.Position.Z - 3.8)) < 0.00001,
	"Larger hull spawns farther from the dock to keep the stern clear"
)
now += 5
request.OnServerEvent:Fire(fisher, "SpawnBoat", "Rowboat")
check(
	Service.active[fisher].model:GetAttribute("BoatId") == "Rowboat",
	"Fishing boat owners can still select their wooden boat"
)
now += 5
local unownedFisher = makePlayer(111, 2499, true)
base:SetAttribute("OwnerUserId", unownedFisher.UserId)
unownedFisher:SetAttribute("BaseId", 1)
request.OnServerEvent:Fire(unownedFisher, "SpawnBoat", "FishingBoat")
check(Service.active[unownedFisher] == nil, "Wooden boat ownership cannot authorize a fishing boat spawn")
before = store.updates
request.OnServerEvent:Fire(unownedFisher, "PurchaseBoat", "FishingBoat")
check(
	store.updates == before and unownedFisher:GetAttribute("Cash") == 2499,
	"Insufficient fishing funds are rejected before saving"
)
local staleFisher = makePlayer(112, 3000)
store.data.Player_112.Cash = 2400
Service.purchase(staleFisher, "FishingBoat")
check(
	staleFisher:GetAttribute("Cash") == 2400 and not staleFisher:GetAttribute("OwnsFishingBoat"),
	"Fishing purchase respects current persisted funds"
)
local failedFisher = makePlayer(113, 3000)
store.updateFailures = 1
Service.purchase(failedFisher, "FishingBoat")
check(
	failedFisher:GetAttribute("Cash") == 3000 and not failedFisher:GetAttribute("OwnsFishingBoat"),
	"A failed fishing purchase cannot grant a boat or deduct cash"
)

local occupiedBuyer = makePlayer(114, 3500)
Service.purchase(occupiedBuyer, "FishingBoat")
base:SetAttribute("OwnerUserId", occupiedBuyer.UserId)
occupiedBuyer:SetAttribute("BaseId", 1)
Service.spawnBoat(occupiedBuyer, spawnPrompt, "FishingBoat")
local occupiedHull = Service.active[occupiedBuyer].model
occupiedHull:FindFirstChild("PassengerSeat1").Occupant = { Parent = otherBuyer.Character }
before = store.updates
Service.purchase(occupiedBuyer, "Rowboat")
check(
	store.updates == before and not occupiedHull.destroyed,
	"New purchases cannot replace a boat carrying a passenger"
)
check(
	not occupiedBuyer:GetAttribute("OwnsRowboat") and occupiedBuyer:GetAttribute("Cash") == 1000,
	"Occupied replacement rejection happens before charging"
)

print(
	`Boat service recording-mock checks passed: {checks}. No Roblox runtime, DataStore network, or live physics were exercised.`
)
