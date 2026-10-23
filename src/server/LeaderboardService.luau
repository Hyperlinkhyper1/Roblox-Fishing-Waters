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

local function indexKey(id, week)
	return id .. ":" .. tostring(week or "AllTime")
end
local function ordered(id, week)
	local key = indexKey(id, week)
	if not stores[key] then
		-- Old level indexes used the flat XP curve and retained higher values
		-- through max writes. Rebuild this index from saved XP on the new curve.
		local name = if id == "Level" then "Level_Progressive_v2" else id
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
	local scores, week = BoatData.leaderboardScores(profile, os.time())
	for _, definition in Boards.Definitions do
		local value = scores[definition.Id]
		local scope = if definition.Weekly then week else nil
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

local function readBoard(definition, week)
	local scope = if definition.Weekly then week else nil
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
		table.insert(entries, { Name = names[userId] or ("Angler " .. row.key), Score = row.value })
	end
	return entries
end

function Service.start(root: Instance)
	if started then
		return
	end
	started = true
	Boards.ensure(root)
	local function bind(player)
		capture(player)
		player:GetAttributeChangedSignal("AnglerRevision"):Connect(function()
			capture(player)
		end)
	end
	Players.PlayerAdded:Connect(bind)
	Players.PlayerRemoving:Connect(capture)
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
		local nextRefresh = 0
		local cached = {}
		while not closing do
			local week = Data.weekStart(os.time())
			if week ~= currentWeek then
				currentWeek, nextRefresh = week, 0
				for _, definition in Boards.Definitions do
					if definition.Weekly then
						cached[definition.Id] = nil
						Boards.render(root, definition.Id, {}, "New week · loading rankings…")
					end
				end
				for _, player in Players:GetPlayers() do
					capture(player)
				end
			end
			if os.clock() >= nextRefresh then
				nextRefresh = os.clock() + 120
				for _, definition in Boards.Definitions do
					local ok, result = pcall(readBoard, definition, week)
					-- A yielding network request must never put last week's rows
					-- back on a board after the UTC boundary.
					if definition.Weekly and Data.weekStart(os.time()) ~= week then
						continue
					end
					if ok then
						cached[definition.Id] = result
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
			task.wait(1)
		end
	end)
	game:BindToClose(function()
		closing = true
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
