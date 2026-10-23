-- MODE --
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local Data = (function()
	-- DATA_SOURCE --
end)()
local Boards = (function()
	-- DEFINITIONS_SOURCE --
	return Boards
end)()
local now = 1792368000
local os = {
	time = function()
		return now
	end,
	clock = function()
		return now
	end,
}
local threads = {}
local task = {
	spawn = function(fn)
		table.insert(threads, coroutine.create(fn))
	end,
	wait = function()
		coroutine.yield()
	end,
}
local warnings = {}
local warn = function(message)
	table.insert(warnings, message)
end
local function signal()
	local handlers = {}
	return {
		Connect = function(_, fn)
			table.insert(handlers, fn)
		end,
		Fire = function(_, ...)
			for _, fn in handlers do
				fn(...)
			end
		end,
	}
end
local revision = signal()
local player = {
	UserId = 101,
	Name = "FirstAngler",
	GetAttributeChangedSignal = function()
		return revision
	end,
}
local profiles = {}
local fresh = Data.decode(nil)
local earned = Data.decode(nil)
earned.Stats.TotalXP, earned.Stats.TotalCaught, earned.Stats.CoinsEarned = 1500, 15, 2000
profiles[player] = { Angler = Data.trackProgress(fresh, earned, now) }
local BoatService = {
	getProfile = function(p)
		return profiles[p]
	end,
}
local BoatData = {
	leaderboardScores = function(profile, time)
		return Data.scores(profile.Angler, time)
	end,
}
local Players = {
	PlayerAdded = signal(),
	PlayerRemoving = signal(),
	GetPlayers = function()
		return { player }
	end,
	GetNameFromUserIdAsync = function(_, id)
		return "Offline" .. id
	end,
}
local records, storeRequests, writes, reads = {}, 0, 0, 0
local storePrefix = if mode == "studio" then "AnglerBoards_Studio_v1_" else "AnglerBoards_v1_"
-- Simulate a score saved using the former flat curve.
records[storePrefix .. "Level:AllTime"] = { ["101"] = 99 }
local failWrite, failRead = false, false
local DataStoreService = {}
function DataStoreService:GetOrderedDataStore(name, scope)
	storeRequests += 1
	check(mode ~= "unpublished", "Unpublished Studio must not access real stores")
	check(
		name:find(if mode == "studio" then "AnglerBoards_Studio_v1_" else "AnglerBoards_v1_", 1, true) == 1,
		"Studio data isolated from live"
	)
	local key = name .. ":" .. scope
	records[key] = records[key] or {}
	local record = records[key]
	return {
		UpdateAsync = function(_, userId, transform)
			writes += 1
			if failWrite then
				error("simulated write outage")
			end
			local a, b = transform(record[userId]), transform(record[userId])
			check(a == b, "Retried index callbacks must be idempotent")
			record[userId] = b
		end,
		GetSortedAsync = function(_, ascending, size, minimum)
			reads += 1
			if failRead then
				error("simulated read outage")
			end
			check(ascending == false and size == 10 and minimum == 1, "Global top ten descending; no zero activity")
			local rows = {}
			for id, score in record do
				if score >= minimum then
					table.insert(rows, { key = id, value = score })
				end
			end
			table.sort(rows, function(a, b)
				return a.value > b.value
			end)
			return {
				GetCurrentPage = function()
					return rows
				end,
			}
		end,
	}
end
local rendered = {}
function Boards.ensure() end
function Boards.render(_, id, rows, status)
	rendered[id] = { Rows = rows, Status = status }
end
local services = {
	Players = Players,
	DataStoreService = DataStoreService,
	RunService = {
		IsStudio = function()
			return mode ~= "live"
		end,
	},
}
local closeCallback
local game = {
	GameId = if mode == "unpublished" then 0 else 123,
	GetService = function(_, name)
		return services[name]
	end,
	BindToClose = function(_, fn)
		closeCallback = fn
	end,
}
local Service = (function()
	-- SERVICE_SOURCE --
end)()
Service.start({})
check(#threads == 2 and closeCallback ~= nil, "Starts background sync and refresh without blocking harbour")
Service.start({})
check(#threads == 2, "Startup idempotent")
local function drain()
	for _ = 1, 30 do
		if next(Service.pending) == nil then
			return
		end
		Service.writeOne()
	end
	check(false, "Pending writes should drain")
end
if mode ~= "unpublished" then
	failWrite = true
	Service.writeOne()
	check(next(Service.pending) ~= nil and #warnings == 1, "Failed index writes remain queued")
	failWrite = false
	now += 31
end
drain()
for _, definition in Boards.Definitions do
	local rows = Service.readBoard(definition, Data.weekStart(now))
	check(#rows == 1 and rows[1].Name == "FirstAngler", "Each ranking reads saved progress")
	if definition.Id == "Level" then
		check(rows[1].Score == 2, "Old flat-curve indexes cannot retain inflated level rankings")
	end
end
local afterWrites = writes
revision:Fire()
drain()
check(writes == afterWrites, "Unchanged profile does not consume more index writes")
local saved = Data.decode(profiles[player].Angler)
local nextValue = Data.decode(saved)
nextValue.Stats.CoinsEarned += 100
profiles[player].Angler = Data.trackProgress(saved, nextValue, now)
revision:Fire()
drain()
check(
	Service.readBoard(Boards.Definitions[6], Data.weekStart(now))[1].Score == 2100,
	"Progress revisions update weekly earnings"
)
if mode ~= "unpublished" then
	local prefix = if mode == "studio" then "AnglerBoards_Studio_v1_" else "AnglerBoards_v1_"
	records[prefix .. "Earned:AllTime"]["101"] = 9000
	profiles[player].Angler.Stats.CoinsEarned += 1
	Service.capture(player)
	drain()
	check(records[prefix .. "Earned:AllTime"]["101"] == 9000, "Older server snapshot cannot lower a global score")
	-- Add an offline player to prove these boards query global indexes.
	records[prefix .. "Earned:AllTime"]["202"] = 10000
	local rows = Service.readBoard(Boards.Definitions[5], Data.weekStart(now))
	check(rows[1].Name == "Offline202" and rows[1].Score == 10000, "Offline global leader appears above online player")
else
	check(storeRequests == 0, "Unpublished test session stays entirely local")
end
local function refresh(steps)
	for _ = 1, steps do
		local ok, message = coroutine.resume(threads[2])
		assert(ok, message)
	end
end
refresh(8)
check(rendered.WeeklyEarned and #rendered.WeeklyEarned.Rows == 1, "Background refresh paints weekly entries")
if mode ~= "unpublished" then
	failRead = true
	now += 121
	refresh(8)
	check(
		#rendered.WeeklyEarned.Rows == 1 and rendered.WeeklyEarned.Status:find("unavailable"),
		"Read failures preserve cached rows and show failure"
	)
end
now = 1792368000 + 604800
refresh(9)
check(#rendered.WeeklyEarned.Rows == 0, "Week rollover clears previous rows even during storage outage")
if mode ~= "unpublished" then
	failRead = false
end
check(#Service.readBoard(Boards.Definitions[6], Data.weekStart(now)) == 0, "New week has separate global index")
check(#Service.readBoard(Boards.Definitions[6], Data.weekStart(now) - 604800) == 1, "Previous week remains isolated")
local beforeRemoval = next(Service.pending)
Players.PlayerRemoving:Fire(player)
check(next(Service.pending) == beforeRemoval, "Departure does not invent new scores")
print("Leaderboard service " .. mode .. ": " .. checks .. " checks passed (mock stores and scheduler).")
