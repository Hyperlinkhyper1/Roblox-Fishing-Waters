-- Saved profiles are authoritative. Ordered stores are retryable, monotonic
-- indexes, so retries/rejoins never add a score twice or replace it with an older one.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local BoatService = require(script.Parent.BoatService)
local BoatData = require(script.Parent.BoatData)
local Data = require(script.Parent.AnglerData)
local Boards = require(script.Parent.Map.Leaderboards)
local Service = {}
local started = false
local sessionOnly = RunService:IsStudio() and game.GameId == 0
local prefix = if RunService:IsStudio() then "AnglerBoards_Studio_v1_" else "AnglerBoards_v1_"
local pending, written, stores, names, sessions = {}, {}, {}, {}, {}
local closing, writing = false, false
-- Ranked like the noticeboards but shown on the luma website only, where a
-- switch flips every board between all time, this month and this week.
local WebOnly = {
	{ Id = "Playtime", Title = "MOST TIME PLAYED", Unit = "SECONDS", Weekly = false },
	{ Id = "WeeklyPlaytime", Title = "TIME PLAYED THIS WEEK", Unit = "SECONDS", Weekly = true },
	{ Id = "MonthlyXP", Title = "MOST XP THIS MONTH", Unit = "XP", Monthly = true },
	{ Id = "MonthlyCaught", Title = "FISH THIS MONTH", Unit = "FISH", Monthly = true },
	{ Id = "MonthlyEarned", Title = "MONEY THIS MONTH", Unit = "$", Monthly = true },
	{ Id = "MonthlyPlaytime", Title = "TIME PLAYED THIS MONTH", Unit = "SECONDS", Monthly = true },
}
-- Web-only boards are read half as often as the noticeboards, keeping
-- GetSortedAsync well inside its per-server budget.
local WEB_REFRESH = 240
local tracked = table.clone(Boards.Definitions)
for _, definition in WebOnly do
	table.insert(tracked, definition)
end
-- Latest global top ten per board, which DashboardService sends to the website.
local snapshots = {}
-- Seconds in game are banked into the saved profile this often.
local PLAYTIME_FLUSH = 60
local playSince = {}

-- Weekly boards are scoped by the week's Monday, monthly ones by the 1st.
local function scopeOf(definition, week, month)
	return if definition.Weekly then week elseif definition.Monthly then month else nil
end

local function indexKey(id, week)
	return id .. ":" .. tostring(week or "AllTime")
end
local function ordered(id, week)
	local key = indexKey(id, week)
	if not stores[key] then
		-- Max writes retain old level scores, so rebuild from saved XP whenever
		-- the progression curve changes.
		local name = if id == "Level" then "Level_Exponential_v3" else id
		stores[key] = DataStoreService:GetOrderedDataStore(prefix .. name, tostring(week or "AllTime"))
	end
	return stores[key]
end

local function capture(player)
	local profile = BoatService.getProfile(player)
	if not profile then
		return
	end
	names[player.UserId] = player.Name
	local scores, week, month = BoatData.leaderboardScores(profile, os.time())
	for _, definition in tracked do
		local value = scores[definition.Id] or 0
		local scope = scopeOf(definition, week, month)
		local key = indexKey(definition.Id, scope) .. ":" .. player.UserId
		if value > (written[key] or 0) then
			local previous = pending[key]
			pending[key] = {
				Id = definition.Id,
				Week = scope,
				UserId = player.UserId,
				Value = math.max(value, if previous then previous.Value else 0),
				RetryAt = 0,
			}
		end
	end
end

local function writeOne()
	if writing then
		return
	end
	for key, entry in pending do
		if entry.RetryAt > os.clock() then
			continue
		end
		writing = true
		local ok, failure = pcall(function()
			if sessionOnly then
				local board = indexKey(entry.Id, entry.Week)
				sessions[board] = sessions[board] or {}
				sessions[board][entry.UserId] = math.max(sessions[board][entry.UserId] or 0, entry.Value)
			else
				ordered(entry.Id, entry.Week):UpdateAsync(tostring(entry.UserId), function(old)
					return math.max(old or 0, entry.Value)
				end)
			end
		end)
		writing = false
		if ok then
			written[key] = math.max(written[key] or 0, entry.Value)
			if pending[key] == entry then
				pending[key] = nil
			end
		else
			entry.RetryAt = os.clock() + 30
			warn("[Leaderboards] Score sync will retry: " .. tostring(failure))
		end
		return
	end
end

local function readBoard(definition, week, month)
	local scope = scopeOf(definition, week, month)
	local rows
	if sessionOnly then
		rows = {}
		for userId, score in sessions[indexKey(definition.Id, scope)] or {} do
			table.insert(rows, { key = tostring(userId), value = score })
		end
		table.sort(rows, function(a, b)
			return if a.value == b.value then tonumber(a.key) < tonumber(b.key) else a.value > b.value
		end)
	else
		rows = ordered(definition.Id, scope):GetSortedAsync(false, 10, 1):GetCurrentPage()
	end
	local entries = {}
	for rank = 1, math.min(10, #rows) do
		local row = rows[rank]
		local userId = tonumber(row.key)
		if not names[userId] then
			local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
			if ok then
				names[userId] = name
			end
		end
		table.insert(entries, { UserId = userId, Name = names[userId] or ("Angler " .. row.key), Score = row.value })
	end
	return entries
end

local function remember(definition, week, month, entries)
	local rows = {}
	for _, entry in entries do
		table.insert(rows, { userId = entry.UserId, name = entry.Name, score = entry.Score })
	end
	snapshots[definition.Id] = {
		readAt = os.time(),
		week = if definition.Weekly then week else nil,
		month = if definition.Monthly then month else nil,
		rows = rows,
	}
end

-- True once the UTC week or month a board was read for has ended, so a slow
-- read never puts last period's rows back after the boundary.
local function stale(definition, week, month)
	local now = os.time()
	return (definition.Weekly and Data.weekStart(now) ~= week)
		or (definition.Monthly and Data.monthStart(now) ~= month)
		or false
end

-- Banks the seconds since the last flush. A failed save keeps them for the
-- next try; seconds after the last flush are lost when the player leaves.
local function creditPlaytime(player)
	local since = playSince[player]
	local now = os.time()
	if not since or now - since < 1 then
		return
	end
	local seconds = now - since
	playSince[player] = now
	local ok = BoatService.updateProgress(player, function(profile)
		profile.Angler.Stats.PlaySeconds += seconds
	end)
	if not ok and playSince[player] == now then
		playSince[player] = since
	end
end

-- Every board's latest global top ten as this server read it, for the website.
function Service.snapshot()
	if sessionOnly then
		return nil
	end
	return table.clone(snapshots)
end

function Service.start(root: Instance)
	if started then
		return
	end
	started = true
	Boards.ensure(root)
	local function bind(player)
		playSince[player] = playSince[player] or os.time()
		capture(player)
		player:GetAttributeChangedSignal("AnglerRevision"):Connect(function()
			capture(player)
		end)
	end
	Players.PlayerAdded:Connect(bind)
	Players.PlayerRemoving:Connect(function(player)
		playSince[player] = nil
		capture(player)
	end)
	for _, player in Players:GetPlayers() do
		bind(player)
	end
	-- Scale writes with player count, reserving headroom in both server and
	-- experience budgets. Coalesce repeated awards while a write is pending.
	task.spawn(function()
		while not closing do
			writeOne()
			local count = math.max(1, #Players:GetPlayers())
			local perMinute = math.min(30 + 5 * count, 20 * count) * 0.8
			task.wait(math.max(0.15, 60 / perMinute))
		end
	end)
	task.spawn(function()
		local currentWeek = Data.weekStart(os.time())
		local currentMonth = Data.monthStart(os.time())
		local nextRefresh, nextWebRefresh = 0, 0
		local cached = {}
		while not closing do
			local week = Data.weekStart(os.time())
			local month = Data.monthStart(os.time())
			if week ~= currentWeek or month ~= currentMonth then
				local newWeek = week ~= currentWeek
				currentWeek, currentMonth, nextRefresh, nextWebRefresh = week, month, 0, 0
				for _, definition in tracked do
					if (newWeek and definition.Weekly) or definition.Monthly then
						snapshots[definition.Id] = nil
					end
				end
				if newWeek then
					for _, definition in Boards.Definitions do
						if definition.Weekly then
							cached[definition.Id] = nil
							Boards.render(root, definition.Id, {}, "New week · loading rankings…")
						end
					end
				end
				for _, player in Players:GetPlayers() do
					capture(player)
				end
			end
			if os.clock() >= nextRefresh then
				nextRefresh = os.clock() + 120
				for _, definition in Boards.Definitions do
					local ok, result = pcall(readBoard, definition, week, month)
					-- A yielding network request must never put last week's rows
					-- back on a board after the UTC boundary.
					if stale(definition, week, month) then
						continue
					end
					if ok then
						cached[definition.Id] = result
						remember(definition, week, month, result)
					end
					local status = if not ok
						then "Rankings unavailable · retrying"
						elseif sessionOnly then "STUDIO · THIS SERVER ONLY"
						elseif #result == 0 then "No scores yet · be the first!"
						else "GLOBAL TOP 10 · refreshes every 2 minutes"
					Boards.render(root, definition.Id, cached[definition.Id] or {}, status)
					task.wait(1)
				end
			end
			if os.clock() >= nextWebRefresh then
				nextWebRefresh = os.clock() + WEB_REFRESH
				for _, definition in WebOnly do
					local ok, result = pcall(readBoard, definition, week, month)
					if ok and not stale(definition, week, month) then
						remember(definition, week, month, result)
					end
				end
			end
			task.wait(1)
		end
	end)
	task.spawn(function()
		while not closing do
			task.wait(PLAYTIME_FLUSH)
			for _, player in Players:GetPlayers() do
				if closing then
					break
				end
				creditPlaytime(player)
			end
		end
	end)
	game:BindToClose(function()
		closing = true
		for _, player in Players:GetPlayers() do
			creditPlaytime(player)
		end
		for _, player in Players:GetPlayers() do
			capture(player)
		end
		local deadline = os.clock() + 25
		while next(pending) and os.clock() < deadline do
			writeOne()
			task.wait(0.2)
		end
	end)
end

return Service
