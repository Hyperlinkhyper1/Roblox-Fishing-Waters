-- A newer running place version announces itself across servers. The durable
-- high-water mark also catches missed messages and servers started from old jobs.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local Service = {}
local started = false
local current = game.PlaceVersion
local latest = current
local restartAt = 0
local checked = false
local closing = false
local store
local subscription
local topic = "FishingWatersVersions_" .. game.PlaceId
local key = tostring(game.PlaceId)
local destinations = {}
local admissions = {}
local transfers = {}
local fallbackCode, fallbackVersion, fallbackCreated
local reserving = false

local function outdated()
	return latest > current or restartAt > 0
end

local function refreshNotice()
	ReplicatedStorage:SetAttribute("FishingWatersServerVersion", current)
	ReplicatedStorage:SetAttribute("FishingWatersLatestVersion", latest)
	ReplicatedStorage:SetAttribute("FishingWatersUpdateAvailable", outdated())
	ReplicatedStorage:SetAttribute("FishingWatersRestartAt", restartAt)
end

local function observe(version)
	if type(version) == "number" and version == version and version < math.huge and version > latest then
		latest = version
		refreshNotice()
	end
end

local function syncVersion()
	local ok, result = pcall(function()
		store = store or DataStoreService:GetDataStore("FishingWatersPlaceVersions_v1")
		if not checked then
			return store:UpdateAsync(key, function(old)
				return math.max(if type(old) == "number" then old else 0, current)
			end)
		end
		return store:GetAsync(key)
	end)
	if ok then
		observe(result)
		checked = true
	else
		warn("[ServerUpdates] Version sync will retry: " .. tostring(result))
	end
end

local function reserveFresh()
	-- Share the fallback amongst arrivals from this server, so friends aren't
	-- each sent to an otherwise empty server. Never reuse it for a later update.
	while reserving do
		task.wait(0.1)
	end
	if fallbackCode and fallbackVersion == latest and os.clock() - fallbackCreated < 120 then
		return fallbackCode
	end
	reserving = true
	local version = latest
	local ok, code = pcall(TeleportService.ReserveServerAsync, TeleportService, game.PlaceId)
	reserving = false
	if not ok then
		error(code)
	end
	fallbackCode, fallbackVersion, fallbackCreated = code, version, os.clock()
	return code
end

local attempt
local function retry(player, state)
	if transfers[player] ~= state or state.waiting or player.Parent ~= Players then
		return
	end
	state.waiting = true
	player:SetAttribute("FishingWatersUpdateStatus", "Retrying")
	task.delay(math.min(30, 5 * state.attempts), function()
		if transfers[player] == state and player.Parent == Players then
			state.waiting = false
			attempt(player, state)
		end
	end)
end

attempt = function(player, state)
	if transfers[player] ~= state or player.Parent ~= Players or closing then
		return
	end
	state.attempts += 1
	local attemptNumber = state.attempts
	player:SetAttribute("FishingWatersUpdateStatus", "Connecting")
	local ok, failure = pcall(function()
		local options = Instance.new("TeleportOptions")
		local destination
		-- Only target a job which has actually reported running the new version.
		-- Ordinary matchmaking could choose the player's friend's old server again.
		if state.attempts <= 2 then
			for jobId, entry in destinations do
				if entry.version >= latest and entry.version > current and os.clock() - entry.seen < 120 then
					destination = jobId
					break
				end
			end
		end
		if destination then
			options.ServerInstanceId = destination
		else
			options.ReservedServerAccessCode = reserveFresh()
		end
		options:SetTeleportData({ FishingWatersUpdateAttempt = attemptNumber })
		-- The player may have left while ReserveServerAsync was yielding.
		if player.Parent == Players and transfers[player] == state then
			TeleportService:TeleportAsync(game.PlaceId, { player }, options)
		end
	end)
	if not ok then
		-- A full/dead fallback needs a new reservation on the next attempt.
		fallbackCode = nil
		warn("[ServerUpdates] Transfer will retry: " .. tostring(failure))
		retry(player, state)
	end
	-- A successful API call is not proof that the player actually left.
	task.delay(45, function()
		if transfers[player] == state and state.attempts == attemptNumber then
			retry(player, state)
		end
	end)
end

local function transfer(player)
	if player.Parent ~= Players or transfers[player] or not outdated() then
		return
	end
	local state = { attempts = 0, waiting = false }
	transfers[player] = state
	player:SetAttribute("FishingWatersUpdateStatus", "Connecting")
	-- Give the replicated notice a moment to render, including during map loading.
	task.delay(2, function()
		attempt(player, state)
	end)
end

local function checkAdmissions()
	if not checked and not outdated() then
		return
	end
	for player in admissions do
		admissions[player] = nil
		if outdated() then
			transfer(player)
		end
	end
end

local function subscribe()
	if subscription then
		return
	end
	local ok, result = pcall(function()
		return MessagingService:SubscribeAsync(topic, function(message)
			local data = message.Data
			if type(data) ~= "table" then
				return
			end
			observe(data.version)
			if
				type(data.jobId) == "string"
				and data.jobId ~= ""
				and data.jobId ~= game.JobId
				and type(data.version) == "number"
				and data.version >= latest
			then
				destinations[data.jobId] = { version = data.version, seen = os.clock() }
			end
			checkAdmissions()
		end)
	end)
	if ok then
		subscription = result
	else
		warn("[ServerUpdates] Subscription will retry: " .. tostring(result))
	end
end

function Service.start()
	if started then
		return
	end
	started = true
	refreshNotice()
	-- Studio must never advertise its version or send players to live servers.
	if RunService:IsStudio() or game.PlaceId == 0 then
		return
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = "JoinUpdatedServer"
	remote.Parent = ReplicatedStorage
	remote.OnServerEvent:Connect(transfer)
	TeleportService.TeleportInitFailed:Connect(function(player, _, _, placeId, options)
		local state = transfers[player]
		if not state or placeId ~= game.PlaceId or not options then
			return
		end
		local data = options:GetTeleportData()
		if type(data) == "table" and data.FishingWatersUpdateAttempt == state.attempts then
			fallbackCode = nil
			retry(player, state)
		end
	end)
	local function joined(player)
		-- Includes FollowUserId/friend joins, invites, and arrivals by teleport.
		admissions[player] = true
		if outdated() then
			checkAdmissions()
		else
			task.spawn(function()
				syncVersion()
				checkAdmissions()
			end)
		end
	end
	Players.PlayerAdded:Connect(joined)
	Players.PlayerRemoving:Connect(function(player)
		admissions[player], transfers[player] = nil, nil
	end)
	game.ServerRestartScheduled:Connect(function(time, source)
		restartAt = time.UnixTimestamp
		ReplicatedStorage:SetAttribute(
			"FishingWatersRestartKind",
			if source == Enum.CloseReason.DeveloperUpdate then "Update" else "Maintenance"
		)
		refreshNotice()
		checkAdmissions()
	end)
	game:BindToClose(function()
		closing = true
		if subscription then
			subscription:Disconnect()
		end
	end)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	task.spawn(function()
		while not closing do
			subscribe()
			syncVersion()
			checkAdmissions()
			local ok, failure = pcall(function()
				MessagingService:PublishAsync(topic, {
					version = current,
					-- Reserved/VIP jobs cannot be joined by ServerInstanceId.
					jobId = if game.PrivateServerId == ""
							and not outdated()
							and #Players:GetPlayers() < Players.MaxPlayers
						then game.JobId
						else "",
				})
			end)
			if not ok then
				warn("[ServerUpdates] Announcement will retry: " .. tostring(failure))
			end
			for jobId, entry in destinations do
				if os.clock() - entry.seen >= 120 or entry.version < latest then
					destinations[jobId] = nil
				end
			end
			task.wait(60)
		end
	end)
end

return Service
