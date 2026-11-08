-- Server crash recorder. When a live server dies (everyone is disconnected at
-- once) Roblox records no script error, so nothing explains it. Every server
-- keeps a small health record (memory, players, uptime, worst frame) in a
-- MemoryStore under its JobId and removes it when it shuts down cleanly. A
-- record that stops updating without being removed belongs to a server that
-- died; the next server to notice reports it with error(), so it lands in the
-- Creator Hub error report with the numbers that explain it.
--
-- The same samples are printed to the server log every few minutes, and high
-- memory or a long freeze is reported while the server is still alive.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local MemoryStoreService = game:GetService("MemoryStoreService")

local Service = {}

local SAMPLE_SECONDS = 30
local LOG_EVERY = 10 -- samples (5 minutes)
local RECORD_EVERY = 2 -- samples (1 minute)
local SCAN_SECONDS = 300
-- A record not refreshed for this long belongs to a dead server.
local STALE_SECONDS = 300
local RECORD_LIFETIME = 3 * 24 * 3600
-- Memory alarms fire once per step crossed.
local ALARM_FROM_MB = 3000
local ALARM_STEP_MB = 1000
local FREEZE_SECONDS = 5
local TOP_TAGS = 6

local started = false
local closing = false
local startedAt = os.time()
local startedClock = os.clock()
local peakMemory = 0
local settledMemory: number? = nil -- memory ten minutes in, after the map settled
local worstFrame = 0 -- since the last sample
local worstFrameEver = 0
local nextAlarm = ALARM_FROM_MB
local lastFreezeReport = -math.huge
local lastSample: { [string]: any }? = nil
local map

local function report(message: string)
	task.spawn(error, message, 0)
end

local function uptime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours, minutes = seconds // 3600, seconds // 60 % 60
	return if hours > 0 then string.format("%dh%02dm", hours, minutes) else string.format("%dm", minutes)
end

local function topTags(): string
	local tags = {}
	for _, tag in Enum.DeveloperMemoryTag:GetEnumItems() do
		local ok, mb = pcall(Stats.GetMemoryUsageMbForTag, Stats, tag)
		if ok and type(mb) == "number" and mb >= 1 then
			table.insert(tags, { name = tag.Name, mb = mb })
		end
	end
	table.sort(tags, function(a, b)
		return a.mb > b.mb
	end)
	local parts = {}
	for i = 1, math.min(TOP_TAGS, #tags) do
		table.insert(parts, string.format("%s %d", tags[i].name, math.round(tags[i].mb)))
	end
	return table.concat(parts, ", ")
end

local function stat(name: string): number
	local ok, value = pcall(function()
		return (Stats :: any)[name]
	end)
	return if ok and type(value) == "number" then value else -1
end

local function sample(): { [string]: any }
	local memory = math.round(Stats:GetTotalMemoryUsageMb())
	peakMemory = math.max(peakMemory, memory)
	local up = os.clock() - startedClock
	if not settledMemory and up >= 600 then
		settledMemory = memory
	end
	return {
		version = game.PlaceVersion,
		started = startedAt,
		seen = os.time(),
		uptime = math.floor(up),
		memory = memory,
		peak = peakMemory,
		settled = settledMemory or 0,
		players = #Players:GetPlayers(),
		maxPlayers = Players.MaxPlayers,
		instances = stat("InstanceCount"),
		primitives = stat("PrimitivesCount"),
		moving = stat("MovingPrimitivesCount"),
		worstFrame = math.round(worstFrameEver * 10) / 10,
		top = topTags(),
	}
end

local function describe(record: { [string]: any }): string
	return string.format(
		"v%s, up %s, %d/%d players, memory %d MB (peak %d, at 10 min %d), %d instances, %d parts (%d moving), worst frame %.1fs. Top memory MB: %s",
		tostring(record.version),
		uptime(record.uptime or 0),
		record.players or 0,
		record.maxPlayers or 0,
		record.memory or 0,
		record.peak or 0,
		record.settled or 0,
		record.instances or 0,
		record.primitives or 0,
		record.moving or 0,
		record.worstFrame or 0,
		tostring(record.top or "?")
	)
end

local function save(record)
	if not map or closing then
		return
	end
	local ok, problem = pcall(map.SetAsync, map, game.JobId, record, RECORD_LIFETIME)
	if not ok then
		warn("[Health] Could not save the health record: " .. tostring(problem))
	end
end

-- A record left behind is either stale (the server died without running
-- BindToClose) or marked `closed` with the reason Roblox gave when it shut the
-- server down with players still in it (out of memory, maintenance, a manual
-- shutdown). UpdateAsync claims a record so two live servers never report the
-- same one.
local function leftBehind(record, now: number): boolean
	return type(record) == "table"
		and type(record.seen) == "number"
		and not record.reported
		and (record.closed ~= nil or now - record.seen > STALE_SECONDS)
end
local function scan()
	if not map then
		return
	end
	local ok, entries = pcall(map.GetRangeAsync, map, Enum.SortDirection.Ascending, 100)
	if not ok or type(entries) ~= "table" then
		return
	end
	local now = os.time()
	for _, entry in entries do
		local value = entry.value
		if entry.key ~= game.JobId and leftBehind(value, now) then
			-- The transform runs again if another server wrote meanwhile; it cancels
			-- (returns nil, so UpdateAsync returns nil) once the record is claimed.
			local ok, stored = pcall(function()
				return map:UpdateAsync(entry.key, function(old)
					if not leftBehind(old, os.time()) then
						return nil
					end
					old.reported = game.JobId
					return old
				end, 600)
			end)
			if ok and type(stored) == "table" and stored.reported == game.JobId then
				pcall(map.RemoveAsync, map, entry.key)
				if stored.closed then
					report(
						string.format(
							"[Health] Roblox shut a server down with players in it (reason: %s): %s",
							tostring(stored.closed),
							describe(stored)
						)
					)
				else
					report(
						string.format(
							"[Health] A server died without shutting down (everyone was disconnected). Last check-in %s before it was noticed: %s",
							uptime(now - stored.seen),
							describe(stored)
						)
					)
				end
			end
		end
	end
end

function Service.latest(): { [string]: any }?
	return lastSample
end

function Service.describe(): string
	return describe(lastSample or sample())
end

function Service.start()
	if started then
		return
	end
	started = true

	RunService.Heartbeat:Connect(function(dt)
		if dt > worstFrame then
			worstFrame = dt
			worstFrameEver = math.max(worstFrameEver, dt)
		end
		if dt >= FREEZE_SECONDS and os.clock() - lastFreezeReport > 60 then
			lastFreezeReport = os.clock()
			task.defer(function()
				report(string.format("[Health] Server froze for %.1fs: %s", dt, describe(sample())))
			end)
		end
	end)

	local live = not RunService:IsStudio() and game.PlaceId ~= 0
	if live then
		local ok, result = pcall(MemoryStoreService.GetSortedMap, MemoryStoreService, "FishingWatersServerHealth_v1")
		if ok then
			map = result
		else
			warn("[Health] Crash records unavailable: " .. tostring(result))
		end
		-- Roblox passes the close reason. An empty server closing is routine; any
		-- other reason (OutOfMemory, RobloxMaintenance, DeveloperShutdown, ...) kicked
		-- everyone, so it is reported now and left for the next server to report too,
		-- in case this server's own error never reaches the error report.
		game:BindToClose(function(reason)
			local name = if typeof(reason) == "EnumItem" then reason.Name else "Unknown"
			-- Players may already be leaving during a real shutdown, so the player count
			-- only decides when Roblox gave no reason.
			local empty = name == "ServerEmpty" or (name == "Unknown" and #Players:GetPlayers() == 0)
			if not empty then
				local record = sample()
				record.closed = name
				report(
					string.format(
						"[Health] Server shutting down with players in it (reason: %s): %s",
						name,
						describe(record)
					)
				)
				if map then
					pcall(map.SetAsync, map, game.JobId, record, RECORD_LIFETIME)
				end
			elseif map then
				pcall(map.RemoveAsync, map, game.JobId)
			end
			closing = true
		end)
	end

	task.spawn(function()
		local count = 0
		local lastScan = os.clock() - SCAN_SECONDS + 60
		while not closing do
			task.wait(SAMPLE_SECONDS)
			count += 1
			local record = sample()
			lastSample = record
			if count % RECORD_EVERY == 0 or count == 1 then
				save(record)
			end
			if count % LOG_EVERY == 0 or count == 1 then
				print(string.format("[Health] %s (worst frame last 30s %.2fs)", describe(record), worstFrame))
			end
			if record.memory >= nextAlarm then
				report("[Health] Server memory is high: " .. describe(record))
				while nextAlarm <= record.memory do
					nextAlarm += ALARM_STEP_MB
				end
			end
			worstFrame = 0
			if os.clock() - lastScan >= SCAN_SECONDS then
				lastScan = os.clock()
				scan()
			end
		end
	end)
end

return Service
