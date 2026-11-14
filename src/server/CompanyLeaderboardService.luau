-- A company is indexed once by its creator and slot. The saved profile remains
-- authoritative; ordered scores are a repairable, eventually consistent index.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local BoatService = require(script.Parent.BoatService)
local Worth = require(script.Parent.CompanyWorth)
local Boards = require(script.Parent.Map.Leaderboards)

local Service = {}
local wallet, index
local sessionOnly = false
local started, closing, writing = false, false, false
local pending, sessionScores, connections = {}, {}, {}
local snapshot = {}

local function identity(info)
	if type(info) ~= "table" or type(info.OwnerUserId) ~= "number" or info.OwnerUserId % 1 ~= 0
		or type(info.Slot) ~= "number" or info.Slot % 1 ~= 0 or info.Slot < 1 or info.Slot > 3 then
		return nil
	end
	return tostring(info.OwnerUserId) .. "_" .. tostring(info.Slot)
end

local function profileKey(id)
	local owner, slot = id:match("^(%-?%d+)_([123])$")
	if not owner then return nil end
	return "Player_" .. owner .. (if slot == "1" then "" else "_Slot_" .. slot)
end

function Service.configure(profileStore, useSessionOnly: boolean)
	wallet, sessionOnly = profileStore, useSessionOnly
end

local function ordered()
	if not index then
		local prefix = if RunService:IsStudio() then "AnglerBoards_Studio_v1_" else "AnglerBoards_v1_"
		index = DataStoreService:GetOrderedDataStore(prefix .. "Companies", "Current")
	end
	return index
end

function Service.record(profile)
	local id = profile and identity(profile.SaveInfo)
	if id then
		pending[id] = { RetryAt = 0 }
	end
end

local function capture(player)
	Service.record(BoatService.getProfile(player))
end

local function authoritative(id)
	local key = profileKey(id)
	assert(wallet and key, "Company save storage is unavailable")
	local profile = wallet:GetAsync(key)
	if type(profile) ~= "table" or identity(profile.SaveInfo) ~= id then return nil end
	return profile
end

local function writeOne()
	if writing or not wallet then return end
	for id, entry in pending do
		if entry.RetryAt > os.clock() then continue end
		writing = true
		local ok, failure = pcall(function()
			-- Re-read instead of writing a player's possibly older local snapshot.
			-- Values may decrease after spending or selling assets.
			local profile = authoritative(id)
			local score = if profile then Worth.calculate(profile) else 0
			if sessionOnly then
				sessionScores[id] = score
			else
				ordered():SetAsync(id, score)
			end
		end)
		writing = false
		if ok then
			if pending[id] == entry then pending[id] = nil end
		else
			entry.RetryAt = os.clock() + 30
			warn("[Companies] Net-worth indexing will retry: " .. tostring(failure))
		end
		return
	end
end

local function readBoard()
	local candidates = {}
	if sessionOnly then
		for id, score in sessionScores do
			if score > 0 then table.insert(candidates, { key = id, value = score }) end
		end
	else
		-- Read spare candidates so removed companies don't occupy a top-ten row
		-- while their index repair is pending.
		candidates = ordered():GetSortedAsync(false, 50, 1):GetCurrentPage()
	end
	local entries = {}
	for _, candidate in candidates do
		local profile = authoritative(candidate.key)
		if profile then
			local score = Worth.calculate(profile)
			local icon = profile.SaveInfo.Icon
			table.insert(entries, { CompanyId = candidate.key, Name = profile.SaveInfo.Name, Score = score,
				Icon = if type(icon) == "number" and icon > 0 and icon % 1 == 0 then icon else nil })
			if score ~= candidate.value then pending[candidate.key] = pending[candidate.key] or { RetryAt = 0 } end
		else
			pending[candidate.key] = pending[candidate.key] or { RetryAt = 0 }
		end
	end
	table.sort(entries, function(a, b)
		return if a.Score == b.Score then a.CompanyId < b.CompanyId else a.Score > b.Score
	end)
	while #entries > 10 do table.remove(entries) end
	return entries
end

function Service.snapshot()
	local rows = {}
	for _, entry in snapshot do
		table.insert(rows, { companyId = entry.CompanyId, name = entry.Name, score = entry.Score, icon = entry.Icon })
	end
	return rows
end

function Service.start(root: Instance)
	if started then return end
	started = true
	Boards.ensure(root)
	local function watch(player)
		if connections[player] then return end
		connections[player] = player:GetAttributeChangedSignal("AnglerRevision"):Connect(function() capture(player) end)
		capture(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		capture(player)
		if connections[player] then connections[player]:Disconnect(); connections[player] = nil end
	end)
	for _, player in Players:GetPlayers() do watch(player) end
	task.spawn(function()
		local nextCapture, nextRefresh = 0, 0
		while not closing do
			if os.clock() >= nextCapture then
				nextCapture = os.clock() + 30
				for _, player in Players:GetPlayers() do capture(player) end
			end
			writeOne()
			if os.clock() >= nextRefresh then
				nextRefresh = os.clock() + 120
				local ok, entries = pcall(readBoard)
				if ok then snapshot = entries end
				Boards.render(root, "Companies", snapshot, if not ok then "Rankings unavailable · retrying"
					elseif sessionOnly then "STUDIO · THIS SERVER ONLY"
					else "CURRENT NET WORTH · refreshes every 2 minutes")
			end
			task.wait(2)
		end
	end)
	game:BindToClose(function()
		closing = true
		for _, player in Players:GetPlayers() do capture(player) end
		local deadline = os.clock() + 25
		while wallet and next(pending) and os.clock() < deadline do
			writeOne()
			task.wait(0.2)
		end
	end)
end

return Service
