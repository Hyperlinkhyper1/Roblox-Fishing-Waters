-- ServerHealth with a fake clock, scheduler, Stats and MemoryStore sorted map.
-- Run through scripts/check-server-health.mjs, which inlines the module.
local passed = 0
local function check(condition, message)
	if not condition then
		error("FAILED: " .. message, 2)
	end
	passed += 1
end

local now = 1_000_000
local clock = 0
local os = setmetatable({
	time = function()
		return math.floor(now + clock)
	end,
	clock = function()
		return clock
	end,
}, { __index = _G.os })

local reports, warnings, prints = {}, {}, {}
local function error(message)
	table.insert(reports, tostring(message))
end
local function warn(message)
	table.insert(warnings, tostring(message))
end
local function print(message)
	table.insert(prints, tostring(message))
end

-- Scheduler: task.wait yields the running coroutine until the fake clock passes its wake time.
local sleeping, deferred = {}, {}
local task = {}
function task.spawn(callback, ...)
	local thread = coroutine.create(callback)
	local ok, problem = coroutine.resume(thread, ...)
	assert(ok, problem)
	return thread
end
function task.defer(callback, ...)
	table.insert(deferred, { callback, table.pack(...) })
end
function task.wait(seconds)
	table.insert(sleeping, { thread = coroutine.running(), wake = clock + (seconds or 0) })
	coroutine.yield()
	return seconds
end
local function advance(seconds)
	local target = clock + seconds
	while true do
		local soonest
		for index, entry in sleeping do
			if entry.wake <= target and (not soonest or entry.wake < sleeping[soonest].wake) then
				soonest = index
			end
		end
		if not soonest then
			break
		end
		local entry = table.remove(sleeping, soonest)
		clock = math.max(clock, entry.wake)
		local ok, problem = coroutine.resume(entry.thread)
		assert(ok, problem)
	end
	clock = target
	local queue = deferred
	deferred = {}
	for _, item in queue do
		item[1](table.unpack(item[2], 1, item[2].n))
	end
end

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in value do
		result[key] = copy(item)
	end
	return result
end

local store = {}
local sortedMap = {}
function sortedMap:SetAsync(key, value)
	store[key] = copy(value)
	return true
end
function sortedMap:GetAsync(key)
	return copy(store[key])
end
function sortedMap:RemoveAsync(key)
	store[key] = nil
end
function sortedMap:UpdateAsync(key, transform)
	local result = transform(copy(store[key]))
	if result == nil then
		return nil
	end
	store[key] = copy(result)
	return copy(result)
end
function sortedMap:GetRangeAsync()
	local entries = {}
	for key, value in store do
		table.insert(entries, { key = key, value = copy(value) })
	end
	table.sort(entries, function(a, b)
		return a.key < b.key
	end)
	return entries
end

local memory = 1800
local heartbeat
local closeHandler
local players = { {}, {}, {} }
local services = {
	Players = {
		MaxPlayers = 12,
		GetPlayers = function()
			return players
		end,
	},
	RunService = {
		IsStudio = function()
			return false
		end,
		Heartbeat = {
			Connect = function(_, callback)
				heartbeat = callback
			end,
		},
	},
	Stats = {
		InstanceCount = 250000,
		PrimitivesCount = 120000,
		MovingPrimitivesCount = 40,
		GetTotalMemoryUsageMb = function()
			return memory
		end,
		GetMemoryUsageMbForTag = function(_, tag)
			return ({ PhysicsParts = memory * 0.3, LuaHeap = 200, Instances = 400, TerrainVoxels = 0.2 })[tag.Name] or 0
		end,
	},
	MemoryStoreService = {
		GetSortedMap = function(_, name)
			assert(name == "FishingWatersServerHealth_v1")
			return sortedMap
		end,
	},
}
local game = {
	PlaceId = 123,
	PlaceVersion = 442,
	JobId = "job-live",
	GetService = function(_, name)
		return assert(services[name], name)
	end,
	BindToClose = function(_, callback)
		closeHandler = callback
	end,
}
local function enumItems(names)
	local items = {}
	for _, name in names do
		table.insert(items, { Name = name })
	end
	return {
		GetEnumItems = function()
			return items
		end,
	}
end
local Enum = {
	DeveloperMemoryTag = enumItems({ "Instances", "LuaHeap", "PhysicsParts", "TerrainVoxels" }),
	SortDirection = { Ascending = "Ascending" },
	CloseReason = {},
}
for _, name in { "Unknown", "ServerEmpty", "OutOfMemory", "RobloxMaintenance", "DeveloperShutdown" } do
	Enum.CloseReason[name] = { Name = name, IsEnumItem = true }
end
local function typeof(value)
	return if type(value) == "table" and value.IsEnumItem then "EnumItem" else type(value)
end

local Service = (function()
	-- SERVER_HEALTH --
end)()

local function countReports(pattern)
	local count = 0
	for _, message in reports do
		if message:find(pattern, 1, true) then
			count += 1
		end
	end
	return count
end

-- Dead servers left behind: one stale, one already claimed by another server, one still alive.
store["job-dead"] = {
	version = 441,
	seen = now - 1200,
	uptime = 3 * 3600 + 720,
	memory = 6100,
	peak = 6150,
	settled = 2900,
	players = 11,
	maxPlayers = 12,
	instances = 410000,
	primitives = 200000,
	moving = 90,
	worstFrame = 0.8,
	top = "PhysicsParts 1800",
}
store["job-claimed"] = { version = 441, seen = now - 1200, reported = "job-other", uptime = 60, memory = 100 }
store["job-alive"] = { version = 442, seen = now - 20, uptime = 60, memory = 100 }

Service.start()
check(heartbeat ~= nil and closeHandler ~= nil, "Watches frames and clean shutdowns")
advance(30)
check(store["job-live"] ~= nil and store["job-live"].memory == 1800, "Saves its own health record on the first sample")
check(store["job-live"].players == 3 and store["job-live"].version == 442, "Record carries players and version")
check(#prints == 1 and prints[1]:find("1800 MB", 1, true) ~= nil, "Logs the first sample")
check(#reports == 0, "Nothing reported before the first scan")

advance(30)
check(countReports("died without shutting down") == 1, "Reports the stale server exactly once")
check(store["job-dead"] == nil, "Removes the reported record")
local dead = reports[1]
check(
	dead:find("6100 MB", 1, true) and dead:find("peak 6150", 1, true) and dead:find("at 10 min 2900", 1, true),
	"Death report has memory figures"
)
check(
	dead:find("up 3h12m", 1, true) and dead:find("11/12 players", 1, true) and dead:find("v441", 1, true),
	"Death report has uptime, players, version"
)
check(
	store["job-claimed"] ~= nil and store["job-claimed"].reported == "job-other",
	"Leaves another server's claim alone"
)
check(store["job-alive"] ~= nil, "Leaves live servers alone")

-- Nobody refreshes the "alive" fixture, so it would go stale from here on.
store["job-alive"] = nil
-- A claim race: another server claims between our read and our update.
store["job-race"] = { version = 441, seen = now + clock - 1000, uptime = 60, memory = 100 }
local update = sortedMap.UpdateAsync
sortedMap.UpdateAsync = function(self, key, transform)
	if key == "job-race" then
		store[key].reported = "job-other"
	end
	return update(self, key, transform)
end
advance(300)
sortedMap.UpdateAsync = update
check(countReports("died without shutting down") == 1, "A record claimed mid-update is not reported twice")
check(store["job-race"] ~= nil, "The other server's claimed record is left for it")

memory = 3400
advance(30)
check(countReports("memory is high") == 1, "Reports memory past 3000 MB")
memory = 3700
advance(60)
check(countReports("memory is high") == 1, "Does not repeat within the same 1000 MB step")
memory = 5200
advance(30)
check(countReports("memory is high") == 2, "Reports the next step")
memory = 5900
advance(30)
check(countReports("memory is high") == 2, "Skips steps already passed")

advance(600)
check(store["job-live"].settled > 0, "Remembers memory ten minutes in")
check(store["job-live"].peak == 5900, "Tracks peak memory")

heartbeat(0.2)
check(countReports("froze") == 0, "Normal frames are quiet")
heartbeat(7.5)
advance(0)
check(countReports("froze for 7.5s") == 1, "Reports a long freeze")
heartbeat(8)
advance(0)
check(countReports("froze") == 1, "Rate-limits freeze reports")
advance(30)
check(store["job-live"].worstFrame == 8, "Record keeps the worst frame")
check(Service.describe():find("5900 MB", 1, true) ~= nil, "describe() for /health")

-- Roblox shuts this server down with players in it: reported now and kept for the next server.
closeHandler(Enum.CloseReason.OutOfMemory)
check(countReports("shutting down with players in it (reason: OutOfMemory)") == 1, "Reports its own forced shutdown")
check(store["job-live"] ~= nil and store["job-live"].closed == "OutOfMemory", "Leaves a closed record behind")
local before = #reports
advance(600)
check(#reports == before, "Stops sampling after shutdown")

-- The next server reports that shutdown once, then closes empty without a trace.
game.JobId = "job-next"
local Next = (function()
	-- SERVER_HEALTH --
end)()
Next.start()
advance(60)
check(
	countReports("Roblox shut a server down with players in it (reason: OutOfMemory)") == 1,
	"Next server reports the forced shutdown"
)
check(store["job-live"] == nil, "Removes the reported shutdown record")
local shutdown = reports[#reports]
check(
	shutdown:find("5900 MB", 1, true) ~= nil and shutdown:find("3/12 players", 1, true) ~= nil,
	"Shutdown report has memory and players"
)
advance(600)
check(countReports("Roblox shut a server down") == 1, "Reports a shutdown only once")
before = #reports
closeHandler(Enum.CloseReason.ServerEmpty)
check(store["job-next"] == nil and #reports == before, "An empty server closing is routine")

-- No reason given: decided by whether players are still in the server.
game.JobId = "job-quiet"
memory = 1500
local Quiet = (function()
	-- SERVER_HEALTH --
end)()
Quiet.start()
advance(30)
players = {}
closeHandler(nil)
check(store["job-quiet"] == nil and #reports == before, "No reason and no players is a clean close")
players = { {} }

-- Studio never touches the MemoryStore.
services.RunService.IsStudio = function()
	return true
end
store = {}
local Studio = (function()
	-- SERVER_HEALTH --
end)()
Studio.start()
advance(90)
check(next(store) == nil, "Studio keeps no crash records")

print = _G.print
print(string.format("Server health: %d checks passed", passed))
