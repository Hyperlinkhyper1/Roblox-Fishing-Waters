-- Recorded coastal ambience layered over EnvironmentAudio's synthetic wash: a
-- lapping bed on open water, hull slaps close to the surface, surf where land
-- meets the sea, crickets on shore at night and gulls calling overhead by day.
-- Every asset is a Roblox-licensed ProSoundEffects recording; docs/FISCH_FEEL.md
-- explains the mix and lists spare takes. PlayerSettings routes all of it
-- through the effects mixer.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local DayNight = require(ReplicatedStorage.Shared.DayNight)
local Weather = require(ReplicatedStorage.Shared.Weather)

-- Names this module's per-frame work in the MicroProfiler (otherwise it is all "Script_Client").
local function profiled<A...>(label: string, callback: (A...) -> ()): (A...) -> ()
	if not debug.profilebegin then
		return callback -- test runners without the MicroProfiler API
	end
	return function(...: A...)
		debug.profilebegin(label)
		callback(...)
		debug.profileend()
	end
end

local CoastalAmbience = {}
local started = false
local SAMPLE_INTERVAL = 0.5
local FADE_RATE = 1.5
local LOOPS = {
	SeaLap = "rbxassetid://9116203162", -- Lake Lap, Fair Haven Bay, water movement
	HullLap = "rbxassetid://9113665498", -- Calm Water Lap, slowed, against side of boat
	ShoreSurf = "rbxassetid://9119676800", -- Surf, medium close, moderate air, tide rollup
	Crickets = "rbxassetid://9112762877", -- Crickets and frogs, constant, night
}
local MIX = { SeaLap = 0.24, HullLap = 0.2, ShoreSurf = 0.3, Crickets = 0.1 }
local GULLS = {
	"rbxassetid://9118858259",
	"rbxassetid://9118858279",
	"rbxassetid://9118858265",
}
local GULL_INTERVAL = NumberRange.new(9, 26)
local GULL_DISTANCE = NumberRange.new(35, 80)
local GULL_HEIGHT = NumberRange.new(12, 35)
-- Two staggered rings of terrain probes: the inner ring finds the beach you are
-- standing next to, the outer one hears the coast before you reach it.
local RINGS = { { radius = 45, weight = 1 }, { radius = 110, weight = 0.6 } }
local PROBES_PER_RING = 8

local function loop(parent: Instance, name: string): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = LOOPS[name]
	sound.Looped = true
	sound.Volume = 0
	sound:SetAttribute("AudioCategory", "Effects")
	sound.Parent = parent
	return sound
end

local function fade(sound: Sound, target: number, dt: number)
	sound.Volume += (target - sound.Volume) * (1 - math.exp(-dt * FADE_RATE))
	if target > 0.002 then
		if not sound.IsPlaying then
			-- Start each loop somewhere new so returning to a spot never replays
			-- the same opening seconds.
			sound.TimePosition = math.random() * math.max(sound.TimeLength - 1, 0)
			sound:Play()
		end
	elseif sound.Volume < 0.002 and sound.IsPlaying then
		sound.Volume = 0
		sound:Stop()
	end
end

local function between(range: NumberRange): number
	return range.Min + math.random() * (range.Max - range.Min)
end

function CoastalAmbience.start()
	if started then
		return
	end
	started = true
	local folder = Instance.new("Folder")
	folder.Name = "CoastalAmbience"
	folder.Parent = SoundService
	local loops = {}
	for name in LOOPS do
		loops[name] = loop(folder, name)
	end
	-- Gulls are positional so they wheel around the listener instead of
	-- sitting in the middle of the head.
	local gullAnchor = Instance.new("Attachment")
	gullAnchor.Name = "GullCall"
	gullAnchor.Parent = workspace.Terrain
	local gull = Instance.new("Sound")
	gull.Name = "Gull"
	gull.RollOffMode = Enum.RollOffMode.InverseTapered
	gull.RollOffMinDistance, gull.RollOffMaxDistance = 25, 240
	gull:SetAttribute("AudioCategory", "Effects")
	gull.Parent = gullAnchor
	task.spawn(function()
		local assets = {}
		for _, id in LOOPS do
			table.insert(assets, id)
		end
		for _, id in GULLS do
			table.insert(assets, id)
		end
		pcall(function()
			ContentProvider:PreloadAsync(assets)
		end)
	end)

	local probes = {}
	for index, ring in RINGS do
		for step = 0, PROBES_PER_RING - 1 do
			local angle = (step + (index - 1) * 0.5) / PROBES_PER_RING * math.pi * 2
			table.insert(probes, {
				offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * ring.radius,
				weight = ring.weight,
			})
		end
	end
	local terrainParams = RaycastParams.new()
	terrainParams.FilterType = Enum.RaycastFilterType.Include
	terrainParams.FilterDescendantsInstances = { workspace.Terrain }
	terrainParams.IgnoreWater = false
	local roofParams = RaycastParams.new()
	roofParams.FilterType = Enum.RaycastFilterType.Exclude
	roofParams.IgnoreWater = true
	roofParams.RespectCanCollide = true

	-- 0..1 estimates refreshed every SAMPLE_INTERVAL.
	local land, water, overWater = 0, 0, false
	local sheltered = false
	local state: Weather.State? = nil
	local darkness = 0
	local elapsed = SAMPLE_INTERVAL
	local nextGull = os.clock() + between(GULL_INTERVAL)

	local function sample(position: Vector3)
		local exclusions = { workspace.CurrentCamera }
		for _, other in Players:GetPlayers() do
			if other.Character then
				table.insert(exclusions, other.Character)
			end
		end
		roofParams.FilterDescendantsInstances = exclusions
		sheltered = workspace:Raycast(position, Vector3.new(0, 160, 0), roofParams) ~= nil
		local landWeight, waterWeight = 0, 0
		for _, probe in probes do
			local origin = Vector3.new(position.X, Biomes.WaterLevel + 60, position.Z) + probe.offset
			local hit = workspace:Raycast(origin, Vector3.new(0, -120, 0), terrainParams)
			if hit then
				if hit.Material == Enum.Material.Water then
					waterWeight = math.max(waterWeight, probe.weight)
				elseif hit.Position.Y > Biomes.WaterLevel - 1 then
					landWeight = math.max(landWeight, probe.weight)
				end
			end
		end
		land, water = landWeight, waterWeight
		local below = workspace:Raycast(
			Vector3.new(position.X, Biomes.WaterLevel + 60, position.Z),
			Vector3.new(0, -120, 0),
			terrainParams
		)
		overWater = below ~= nil and below.Material == Enum.Material.Water
		local now = workspace:GetServerTimeNow()
		state = Weather.getState(now, position)
		darkness = DayNight.darkness(DayNight.clockTime(now))
	end

	RunService.Heartbeat:Connect(profiled("CoastalAmbience", function(dt: number)
		local camera = workspace.CurrentCamera
		if not camera then
			for _, sound in loops do
				fade(sound, 0, dt)
			end
			return
		end
		local position = camera.CFrame.Position
		elapsed += dt
		if elapsed >= SAMPLE_INTERVAL then
			elapsed = 0
			sample(position)
		end
		local weather = state
		if not weather then
			return
		end
		local ocean = Biomes.inOceanBounds(position)
		local height = position.Y - Biomes.WaterLevel
		local submerged = ocean and height < 0
		local exposure = if submerged then 0 elseif sheltered then 0.3 else 1
		local lake = Weather.inLake(position)
		local storm = math.max(weather.storm, math.clamp((weather.windSpeed - 6) / 46, 0, 1))
		-- Water layers fade as the camera climbs away from the surface.
		local near = math.clamp(1 - (height - 10) / 90, 0.15, 1)
		local seaWater = if ocean then (if overWater then 1 else water) else 0
		local shore = if ocean then math.min(land * 1.6, 1) * math.min(water * 1.6, 1) else 0

		fade(loops.SeaLap, MIX.SeaLap * seaWater * (1 - shore * 0.4) * near * exposure, dt)
		local hull = math.clamp(1 - (height - 8) / 14, 0, 1) * seaWater
		fade(loops.HullLap, MIX.HullLap * hull * exposure, dt)
		local surf = shore * near * (if lake then 0.45 else 1) * (1 + storm * 0.6)
		fade(loops.ShoreSurf, MIX.ShoreSurf * surf * exposure, dt)
		local crickets = darkness * math.min(land * 1.5, 1) * (1 - weather.rain * 0.7)
		fade(loops.Crickets, MIX.Crickets * crickets * (if submerged then 0 else 1), dt)

		local now = os.clock()
		if now >= nextGull then
			nextGull = now + between(GULL_INTERVAL)
			local calm = weather.rain < 0.3 and storm < 0.35
			if calm and darkness < 0.4 and land > 0 and exposure == 1 and height < 120 then
				local angle = math.random() * math.pi * 2
				local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * between(GULL_DISTANCE)
				gullAnchor.WorldPosition = position + offset + Vector3.yAxis * between(GULL_HEIGHT)
				gull.SoundId = GULLS[math.random(#GULLS)]
				gull.PlaybackSpeed = 0.9 + math.random() * 0.2
				gull.Volume = (0.25 + math.random() * 0.2) * (1 - darkness)
				gull.TimePosition = 0
				gull:Play()
			end
		end
	end))
end

return CoastalAmbience
