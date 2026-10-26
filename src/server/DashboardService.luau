-- Reports this server's players and weather to the luma admin dashboard
-- (sync.luma-app.cc/admin, Fishing Waters project) and applies what the
-- operator set there: a weather override and gamepass grants. Game servers
-- can't be called into, so both ride back on the heartbeat's response.
-- Needs Allow HTTP Requests and the LumaDashboardKey secret; without them it
-- warns once and stays off.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Passes = require(ReplicatedStorage.Shared.Gamepasses)
local Weather = require(ReplicatedStorage.Shared.Weather)
local GamepassService = require(script.Parent.GamepassService)

local Service = {}
local URL = "https://sync.luma-app.cc/api/v1/fishing-waters/heartbeat"
local SECRET_NAME = "LumaDashboardKey"
local started = false
local jobId = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false):sub(1, 8)
local startedAt = os.time()
local joinedAt = {}
local interval = 15
local soon = false
local appliedWeatherVersion = 0
local failures = 0

local function payload(closing: boolean?)
	if closing then
		return { jobId = jobId, closing = true }
	end
	local players = {}
	for _, player in Players:GetPlayers() do
		local entry = {
			userId = player.UserId,
			name = player.Name,
			displayName = player.DisplayName,
			joinedAt = joinedAt[player] or startedAt,
		}
		local root = player.Character and player.Character.PrimaryPart
		if root then
			entry.x = math.round(root.Position.X)
			entry.z = math.round(root.Position.Z)
		end
		table.insert(players, entry)
	end

	local now = workspace:GetServerTimeNow()
	local state = Weather.getState(now)
	local epoch = workspace:GetAttribute("WeatherEpoch") or now
	local override = workspace:GetAttribute("WeatherOverride")
	local blackHole = Weather.blackHolePosition()
	local kinds, schedule, passes = {}, {}, {}
	for kind in Weather.Presets do
		table.insert(kinds, kind)
	end
	-- Calmest first, so the dashboard's weather buttons read in order.
	table.sort(kinds, function(a, b)
		local pa, pb = Weather.Presets[a], Weather.Presets[b]
		local sa = pa.rain + pa.storm + (if a == "BlackHole" then 10 else 0)
		local sb = pb.rain + pb.storm + (if b == "BlackHole" then 10 else 0)
		return if sa == sb then a < b else sa < sb
	end)
	for _, stage in Weather.Schedule do
		table.insert(schedule, { kind = stage.kind, duration = stage.duration })
	end
	for key, pass in Passes do
		table.insert(passes, { key = key, name = pass.Name, id = pass.Id })
	end
	table.sort(passes, function(a, b)
		return a.name < b.name
	end)

	return {
		jobId = jobId,
		placeVersion = game.PlaceVersion,
		privateServer = game.PrivateServerId ~= "",
		studio = RunService:IsStudio(),
		startedAt = startedAt,
		players = players,
		weather = {
			kind = state.kind,
			blackHole = if blackHole
				then { x = blackHole.X, z = blackHole.Z, radius = Weather.BlackHoleRadius }
				else nil,
			override = if type(override) == "string" then override else nil,
			rain = state.rain,
			storm = state.storm,
			cloudCover = state.cloudCover,
			windSpeed = state.windSpeed,
			windAngle = math.deg(math.atan2(state.windDirection.Z, state.windDirection.X)),
			waveAmplitude = state.waveAmplitude,
			seed = workspace:GetAttribute("WeatherSeed"),
			cycleElapsed = math.max(0, now - epoch) % Weather.CycleSeconds,
			maxWaveAmplitude = Weather.MaxWaveAmplitude,
			radar = Weather.radar(now),
		},
		kinds = kinds,
		schedule = schedule,
		passes = passes,
	}
end

local function apply(reply)
	if type(reply.intervalSeconds) == "number" then
		interval = math.clamp(reply.intervalSeconds, 5, 120)
	end
	-- Only a change made on the dashboard touches the weather, so /set weather
	-- in chat still works until the operator picks something there.
	local version = reply.weatherVersion
	if type(version) == "number" and version > appliedWeatherVersion then
		local kind = reply.weatherOverride
		local center
		local valid = true
		if kind == "BlackHole" then
			local point = reply.blackHole
			valid = type(point) == "table"
				and type(point.x) == "number"
				and type(point.z) == "number"
				and point.x == point.x
				and point.z == point.z
				and math.abs(point.x) <= Weather.RadarHalfSize
				and math.abs(point.z) <= Weather.RadarHalfSize
			if valid then
				center = Vector3.new(point.x, Biomes.WaterLevel, point.z)
			end
		end
		if valid then
			appliedWeatherVersion = version
			workspace:SetAttribute("BlackHolePosition", center)
			workspace:SetAttribute(
				"WeatherOverride",
				if type(kind) == "string" and Weather.Presets[kind] then kind else nil
			)
		end
	end
	if type(reply.grants) == "table" then
		GamepassService.setDashboardGrants(reply.grants)
	end
end

local function send(secret, closing: boolean?): boolean
	local ok, response = pcall(HttpService.RequestAsync, HttpService, {
		Url = URL,
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json", ["X-Fishing-Waters-Key"] = secret },
		Body = HttpService:JSONEncode(payload(closing)),
	})
	local problem
	if not ok then
		problem = tostring(response)
	elseif not response.Success then
		problem = "HTTP " .. response.StatusCode
	elseif not closing then
		local decoded, reply = pcall(HttpService.JSONDecode, HttpService, response.Body)
		if decoded and type(reply) == "table" then
			apply(reply)
		else
			problem = "unreadable reply"
		end
	end
	if problem then
		-- The first failure and then one in twenty, so an outage can't flood the log.
		if failures % 20 == 0 then
			warn("[Dashboard] Heartbeat failed: " .. problem)
		end
		failures += 1
		return false
	end
	failures = 0
	return true
end

function Service.start()
	if started then
		return
	end
	started = true
	local ok, secret = pcall(HttpService.GetSecret, HttpService, SECRET_NAME)
	if not ok then
		warn("[Dashboard] No " .. SECRET_NAME .. " secret; the admin dashboard won't see this server.")
		return
	end
	for _, player in Players:GetPlayers() do
		joinedAt[player] = os.time()
	end
	-- Joins and leaves report within a second instead of waiting a full interval,
	-- so a grant reaches a player who just joined straight away.
	Players.PlayerAdded:Connect(function(player)
		joinedAt[player] = os.time()
		soon = true
	end)
	Players.PlayerRemoving:Connect(function(player)
		joinedAt[player] = nil
		soon = true
	end)
	game:BindToClose(function()
		send(secret, true)
	end)
	task.spawn(function()
		while true do
			send(secret)
			local waited = 0
			while waited < interval and not soon do
				waited += task.wait(1)
			end
			soon = false
		end
	end)
end

return Service
