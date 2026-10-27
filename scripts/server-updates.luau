local checks = 0
local function check(condition, message)
	checks += 1
	assert(condition, message)
end
local now, queue, records, listeners = 0, {}, {}, {}
local function signal()
	local handlers = {}
	return {
		Connect = function(_, fn)
			table.insert(handlers, fn)
			return { Disconnect = function() local i = table.find(handlers, fn); if i then table.remove(handlers, i) end end }
		end,
		Fire = function(_, ...)
			for _, fn in table.clone(handlers) do fn(...) end
		end,
	}
end
local function schedule(delay, thread)
	table.insert(queue, { at = now + delay, thread = thread })
end
local task = {}
function task.delay(delay, fn) schedule(delay, coroutine.create(fn)) end
function task.spawn(fn) task.delay(0, fn) end
function task.wait(delay) coroutine.yield(delay or 0.1) end
local function advance(seconds)
	local target = now + seconds
	local iterations = 0
	while true do
		local index, earliest = nil, math.huge
		for i, entry in queue do if entry.at < earliest then index, earliest = i, entry.at end end
		if not index or earliest > target then break end
		now = earliest
		local entry = table.remove(queue, index)
		local ok, delay = coroutine.resume(entry.thread)
		assert(ok, delay)
		if coroutine.status(entry.thread) ~= "dead" then schedule(delay, entry.thread) end
		iterations += 1
		assert(iterations < 10000, "Scheduler runaway")
	end
	now = target
end
local methods = {}
local function object(class)
	return setmetatable({ ClassName = class, attrs = {}, signals = {}, children = {}, OnServerEvent = signal(), Activated = signal() }, { __index = methods })
end
function methods:SetAttribute(name, value)
	self.attrs[name] = value
	self:GetAttributeChangedSignal(name):Fire()
end
function methods:GetAttribute(name) return self.attrs[name] end
function methods:GetAttributeChangedSignal(name)
	self.signals[name] = self.signals[name] or signal()
	return self.signals[name]
end
function methods:SetTeleportData(data) self.data = data end
function methods:GetTeleportData() return self.data end
function methods:FindFirstChild(name)
	for _, item in self.children do if item.Name == name then return item end end
end
function methods:WaitForChild(name) return self:FindFirstChild(name) end
local function attach(parent, child) child.Parent = parent; table.insert(parent.children, child); return child end
local function makeServer(version, options)
	options = options or {}
	local s = { calls = {}, reserves = 0, warnings = {}, reads = 0, writes = 0, subscriptions = 0 }
	local Players = { PlayerAdded = signal(), PlayerRemoving = signal(), MaxPlayers = 12, list = {} }
	function Players:GetPlayers() return table.clone(self.list) end
	s.players = Players
	s.storage = object("ReplicatedStorage")
	local ReplicatedStorage = s.storage
	local Instance = { new = function(class)
		local item = object(class)
		-- Production sets Parent directly; register only the remote for assertions.
		if class == "RemoteEvent" then s.remote = item end
		return item
	end }
	local TeleportService = { TeleportInitFailed = signal() }
	s.teleports = TeleportService
	function TeleportService:ReserveServerAsync()
		s.reserves += 1
		if s.reserveFailure then error("Reservation unavailable") end
		return "secret-" .. version .. "-" .. s.reserves
	end
	function TeleportService:TeleportAsync(placeId, players, teleportOptions)
		table.insert(s.calls, { player = players[1], options = teleportOptions, placeId = placeId })
		if s.throwTeleport then error("Teleport unavailable") end
	end
	local DataStoreService = {}
	function DataStoreService:GetDataStore()
		if s.storageFailure then error("Store unavailable") end
		return {
			UpdateAsync = function(_, key, fn) s.writes += 1; records[key] = fn(records[key]); return records[key] end,
			GetAsync = function(_, key) s.reads += 1; if s.storageFailure then error("Read unavailable") end; return records[key] end,
		}
	end
	local MessagingService = {}
	function MessagingService:SubscribeAsync(topic, fn)
		s.subscriptions += 1
		if s.busFailure then error("Bus unavailable") end
		listeners[topic] = listeners[topic] or {}
		listeners[topic][s] = fn
		return { Disconnect = function() listeners[topic][s] = nil end }
	end
	function MessagingService:PublishAsync(topic, data)
		if s.busFailure then error("Bus unavailable") end
		for server, fn in listeners[topic] or {} do if not server.busFailure then fn({ Data = data }) end end
	end
	local RunService = { IsStudio = function() return options.studio == true end }
	local os = { clock = function() return now end }
	local warn = function(msg) table.insert(s.warnings, msg) end
	local Enum = { CloseReason = { DeveloperUpdate = "Update", RobloxMaintenance = "Maintenance" } }
	local game = {
		PlaceVersion = version, PlaceId = options.placeId or 100, JobId = "job-" .. version,
		PrivateServerId = options.privateId or "", ServerRestartScheduled = signal(),
	}
	s.game = game
	function game:GetService(name)
		return ({ Players = Players, ReplicatedStorage = ReplicatedStorage, TeleportService = TeleportService,
			DataStoreService = DataStoreService, MessagingService = MessagingService, RunService = RunService })[name]
	end
	function game:BindToClose(fn) s.close = fn end
	function s.join(id)
		local player = object("Player")
		player.UserId = id
		player.FollowUserId = 999 -- Every fixture join follows a friend in this job.
		player.Parent = Players
		table.insert(Players.list, player)
		Players.PlayerAdded:Fire(player)
		return player
	end
	function s.leave(player)
		Players.PlayerRemoving:Fire(player)
		player.Parent = nil
		table.remove(Players.list, table.find(Players.list, player))
	end
	s.service = (function()
		-- SERVER_SOURCE --
	end)()
	return s
end

local old = makeServer(10)
old.service.start()
old.service.start()
advance(0)
local existing = old.join(1)
advance(0)
check(old.writes == 1 and old.subscriptions == 1, "Start is idempotent; one high-water write")
check(not old.storage:GetAttribute("FishingWatersUpdateAvailable"), "Current server has no update banner")

local fresh = makeServer(11)
fresh.service.start()
advance(0)
check(records["100"] == 11, "New server registers its place version")
check(old.storage:GetAttribute("FishingWatersUpdateAvailable"), "New version immediately notifies old servers")
advance(3)
check(#old.calls == 0 and existing:GetAttribute("FishingWatersUpdateStatus") == nil, "Existing players may continue playing")
local friend = old.join(2)
old.remote.OnServerEvent:Fire(friend)
advance(2)
check(#old.calls == 1, "Friend join automatically transfers; repeated requests do not duplicate")
check(old.calls[1].options.ServerInstanceId == "job-11", "Target the newer public job explicitly")
check(old.calls[1].options.ReservedServerAccessCode == nil, "Public transfer has no conflicting options")
fresh.remote.OnServerEvent:Fire(fresh.join(3))
advance(3)
check(#fresh.calls == 0, "Clients cannot transfer from current servers through the update remote")

local failureOptions = object("TeleportOptions")
failureOptions:SetTeleportData(old.calls[1].options:GetTeleportData())
old.teleports.TeleportInitFailed:Fire(friend, "Full", "full", 100, failureOptions)
check(friend:GetAttribute("FishingWatersUpdateStatus") == "Retrying", "Async failure is visible to client")
advance(5)
check(#old.calls == 2, "Async failure retries automatically")
local secondOptions = object("TeleportOptions")
secondOptions:SetTeleportData(old.calls[2].options:GetTeleportData())
old.teleports.TeleportInitFailed:Fire(friend, "Full", "full", 100, secondOptions)
advance(10)
check(#old.calls == 3 and old.calls[3].options.ReservedServerAccessCode ~= nil, "Repeated public failure creates a fresh reserved server")
check(old.calls[3].options.ServerInstanceId == nil, "Fresh fallback avoids normal matchmaking and conflicting options")
old.teleports.TeleportInitFailed:Fire(friend, "Failure", "late", 100, failureOptions)
check(friend:GetAttribute("FishingWatersUpdateStatus") == "Connecting", "Late failures from earlier attempts do not schedule another retry")
old.leave(friend)
advance(50)
check(#old.calls == 3, "Leaving cancels retries and timeout watchdogs")

old.remote.OnServerEvent:Fire(existing)
advance(2)
check(#old.calls == 4, "Existing player can choose Join updated server")
old.leave(existing)

local missed = makeServer(9)
missed.busFailure = true
local arrival = missed.join(4)
missed.service.start()
advance(2)
check(arrival:GetAttribute("FishingWatersUpdateStatus") == "Connecting", "Initial joins detect persistent latest version even with messaging down")
check(#missed.calls == 1 and missed.calls[1].options.ReservedServerAccessCode ~= nil, "Unknown new job creates a fresh server instead of matchmaking")
check(records["100"] == 11, "Old startup cannot downgrade the latest version")
missed.leave(arrival)
records["100"] = 12
advance(61)
check(old.storage:GetAttribute("FishingWatersLatestVersion") == 12, "Polling recovers missed update announcements")

local private = makeServer(13, { privateId = "vip" })
private.service.start()
advance(0)
local privateFriend = old.join(5)
advance(2)
check(old.calls[#old.calls].options.ReservedServerAccessCode ~= nil, "VIP/reserved jobs are never targeted by job ID")
old.leave(privateFriend)

local broken = makeServer(8)
broken.storageFailure = true
broken.service.start()
advance(0)
local newArrival = broken.join(6)
broken.throwTeleport = true
listeners["FishingWatersVersions_100"][broken]({ Data = { version = 13, jobId = "" } })
advance(2)
check(newArrival:GetAttribute("FishingWatersUpdateStatus") == "Retrying", "Synchronous teleport failure schedules retry")
local count = #broken.calls
broken.throwTeleport = false
advance(5)
check(#broken.calls == count + 1, "Synchronous failure recovers automatically")
count = #broken.calls
advance(45 + 10)
check(#broken.calls == count + 1, "Watchdog retries a teleport which never departs or reports failure")
broken.leave(newArrival)

local scheduled = makeServer(20, { placeId = 200 })
scheduled.service.start()
advance(0)
local beforeRestart = scheduled.join(7)
advance(0)
scheduled.game.ServerRestartScheduled:Fire({ UnixTimestamp = 500 }, "Update")
check(scheduled.storage:GetAttribute("FishingWatersUpdateAvailable"), "Scheduled publish restart displays update notice without a newer running job")
check(beforeRestart:GetAttribute("FishingWatersUpdateStatus") == nil, "Scheduled restart doesn't prematurely transfer existing players")
local restartFriend = scheduled.join(8)
advance(2)
check(#scheduled.calls == 1 and scheduled.calls[1].options.ReservedServerAccessCode ~= nil, "Friend joins during scheduled restart go to fresh servers")
scheduled.leave(restartFriend)
scheduled.game.ServerRestartScheduled:Fire({ UnixTimestamp = 600 }, "Maintenance")
check(scheduled.storage:GetAttribute("FishingWatersRestartKind") == "Maintenance", "Maintenance has its own notice wording")

local studio = makeServer(999, { studio = true })
studio.service.start()
advance(0)
check(studio.writes == 0 and studio.remote == nil and #studio.calls == 0, "Studio cannot touch live version data or teleports")
check(records["100"] == 13, "Studio cannot poison live version high-water mark")

-- The actual client renders retained attributes even if the update predates UI startup.
do
	local Players = { LocalPlayer = object("Player") }
	local player = Players.LocalPlayer
	local playerGui = attach(player, object("PlayerGui")); playerGui.Name = "PlayerGui"
	local ReplicatedStorage = old.storage
	local sent = 0
	local remote = attach(ReplicatedStorage, object("RemoteEvent")); remote.Name = "JoinUpdatedServer"
	function remote:FireServer() sent += 1 end
	local created = {}
	local Instance = { new = function(class) local item = object(class); table.insert(created, item); return item end }
	local Vector2 = { new = function(...) return {...} end }
	local UDim2 = { new = function(...) return {...} end, fromOffset = function(...) return {...} end }
	local Enum = { ZIndexBehavior = { Sibling = "Sibling" } }
	local Theme = { Colors = {}, panel = function() end, text = function() end, button = function() end }
	local game = { GetService = function(_, name) return ({Players = Players, ReplicatedStorage = ReplicatedStorage})[name] end }
	local client = (function()
		-- CLIENT_SOURCE --
	end)()
	client.start()
	client.start()
	local gui, button
	for _, item in created do
		if item.ClassName == "ScreenGui" then gui = item end
		if item.ClassName == "TextButton" then button = item end
	end
	check(gui.Enabled and gui.DisplayOrder > 1000 and not gui.ResetOnSpawn, "Late client gets persistent update banner above loading screen")
	button.Activated:Fire()
	check(sent == 1, "Update button requests a server-owned transfer")
	player:SetAttribute("FishingWatersUpdateStatus", "Retrying")
	button.Activated:Fire()
	check(sent == 1 and not button.Active, "Pending transfer disables repeated button requests")
	check(string.find(button.Text, "retrying") ~= nil, "Client displays retry state")
end
print("Server updates: " .. checks .. " checks passed")
