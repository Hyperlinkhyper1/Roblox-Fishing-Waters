-- Camera-local ambience and positional player splashes. PlayerSettings routes
-- every sound through the effects mixer, including sounds created after spawn.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Weather = require(ReplicatedStorage.Shared.Weather)

local EnvironmentAudio = {}
local started = false
local SAMPLE_INTERVAL = 0.4
-- Roblox's bundled character audio needs no uploaded/private audio permissions.
local WIND = "rbxasset://sounds/action_falling.mp3"
local SPLASH = "rbxasset://sounds/impact_water.mp3"
local SWIM = "rbxasset://sounds/action_swim.mp3"
-- Roblox Creator Store / Pro Sound Effects: beach waves, surf, seaside.
-- https://create.roblox.com/store/asset/9114586981/Giant-Splash-3-SFX
local SURF = "rbxassetid://9114586981"
local WATER_PROBES = {
	Vector3.zero,
	Vector3.new(32, 0, 0),
	Vector3.new(-32, 0, 0),
	Vector3.new(0, 0, 32),
	Vector3.new(0, 0, -32),
	Vector3.new(80, 0, 0),
	Vector3.new(-80, 0, 0),
	Vector3.new(0, 0, 80),
	Vector3.new(0, 0, -80),
	Vector3.new(56, 0, 56),
	Vector3.new(-56, 0, 56),
	Vector3.new(56, 0, -56),
	Vector3.new(-56, 0, -56),
}

local function sound(parent: Instance, name: string, id: string, looped: boolean): Sound
	local result = Instance.new("Sound")
	result.Name = name
	result.SoundId = id
	result.Looped = looped
	result.Volume = 0
	result:SetAttribute("AudioCategory", "Effects")
	result.Parent = parent
	return result
end

local function fade(loop: Sound, target: number, dt: number)
	loop.Volume += (target - loop.Volume) * (1 - math.exp(-dt * 3))
	if target > 0.001 then
		if not loop.IsPlaying then
			loop:Play()
		end
	elseif loop.Volume < 0.001 then
		loop.Volume = 0
		if loop.IsPlaying then
			loop:Stop()
		end
	end
end

local function inOcean(position: Vector3): boolean
	return math.abs(position.X) < Biomes.MapHalfSize
		and math.abs(position.Z) < Biomes.MapHalfSize
		and position.Y > Biomes.SeaFloor
end

function EnvironmentAudio.start()
	if started then
		return
	end
	started = true
	local ambience = Instance.new("Folder")
	ambience.Name = "EnvironmentAudio"
	ambience.Parent = SoundService
	local waves = sound(ambience, "OceanWaves", SURF, true)
	local wind = sound(ambience, "CoastalWind", WIND, true)
	wind.PlaybackSpeed = 0.85
	local underwater = sound(ambience, "UnderwaterWash", SURF, true)
	underwater.PlaybackSpeed = 0.7
	local muffled = Instance.new("EqualizerSoundEffect")
	muffled.LowGain, muffled.MidGain, muffled.HighGain = 2, -18, -40
	muffled.Parent = underwater
	-- Preload asynchronously so the loading screen never waits on audio delivery.
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ SURF, WIND, SPLASH, SWIM })
		end)
	end)

	local terrainParams = RaycastParams.new()
	terrainParams.FilterType = Enum.RaycastFilterType.Include
	terrainParams.FilterDescendantsInstances = { workspace.Terrain }
	terrainParams.IgnoreWater = false
	local roofParams = RaycastParams.new()
	roofParams.FilterType = Enum.RaycastFilterType.Exclude
	roofParams.IgnoreWater = true
	roofParams.RespectCanCollide = true
	local elapsed = SAMPLE_INTERVAL
	local waterNear = 0
	local sheltered = false
	local submerged = false
	local lastCamera: Camera? = nil
	local lastPosition: Vector3? = nil

	-- Terrain-only shoreline probes still find water beneath docks and boats.
	-- Keep this bounded and independent of the number of streamed shore parts.
	RunService.Heartbeat:Connect(function(dt: number)
		local camera = workspace.CurrentCamera
		if not camera then
			for _, loop in { waves, wind, underwater } do
				loop.Volume = 0
				loop:Stop()
			end
			lastCamera = nil
			return
		end
		local position = camera.CFrame.Position
		local ocean = inOcean(position)
		submerged = ocean and position.Y < Biomes.WaterLevel + (if submerged then 0.15 else -0.15)
		elapsed += dt
		if camera ~= lastCamera or (lastPosition and (position - lastPosition).Magnitude > 24) then
			elapsed = SAMPLE_INTERVAL
		end
		if elapsed >= SAMPLE_INTERVAL then
			elapsed = 0
			lastCamera, lastPosition = camera, position
			local exclusions = { camera }
			for _, other in Players:GetPlayers() do
				if other.Character then
					table.insert(exclusions, other.Character)
				end
			end
			roofParams.FilterDescendantsInstances = exclusions
			sheltered = workspace:Raycast(position, Vector3.new(0, 160, 0), roofParams) ~= nil
			waterNear = 0
			if ocean then
				for _, offset in WATER_PROBES do
					local origin = Vector3.new(position.X, Biomes.WaterLevel + 8, position.Z) + offset
					local hit = workspace:Raycast(origin, Vector3.new(0, -16, 0), terrainParams)
					if hit and hit.Material == Enum.Material.Water then
						local distance = (position - hit.Position).Magnitude
						waterNear = math.max(waterNear, math.clamp(1 - distance / 130, 0, 1))
					end
				end
			end
		end
		local now = workspace:GetServerTimeNow()
		local state = Weather.getState(now, position)
		local strength = math.clamp((state.windSpeed - 6) / 46, 0, 1)
		local exposure = if submerged then 0.025 elseif sheltered then 0.22 else 1
		local lake = Weather.inLake(position)
		local gust = 0.88 + math.sin(now * 0.31) * 0.08 + math.sin(now * 0.73) * 0.04
		local waveVolume = waterNear * (if lake then 0.22 else 0.34) * (1 + strength * 0.65)
		local windVolume = (0.14 + strength * 0.46) * gust * (if lake then 0.8 else 1)
		fade(waves, waveVolume * exposure, dt)
		fade(wind, windVolume * exposure * (if ocean then 1 else 0), dt)
		fade(underwater, if submerged then 0.32 else 0, dt)
	end)

	-- The default controller rewrites swimming volume every frame and makes
	-- ordinary jump splashes nearly inaudible. Own the two water cues, using the
	-- same bundled audio, and silence their defaults so the controllers cannot
	-- fight over volume or play a second splash.
	local characters = {}
	local function remove(character: Model)
		local record = characters[character]
		if record then
			for _, item in record.owned do
				item:Destroy()
			end
			for cue, id in record.muted do
				if cue.Parent and cue.SoundId == "" then
					cue.SoundId = id
				end
			end
			characters[character] = nil
		end
	end
	local function add(character: Model)
		if characters[character] then
			return
		end
		characters[character] =
			{ owned = {}, muted = {}, initialized = false, wet = false, lastSplash = -math.huge, lastDown = 0 }
	end
	local function watch(other: Player)
		other.CharacterAdded:Connect(add)
		other.CharacterRemoving:Connect(remove)
		if other.Character then
			add(other.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(other)
		if other.Character then
			remove(other.Character)
		end
	end)
	for _, other in Players:GetPlayers() do
		watch(other)
	end
	RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock()
		local camera = workspace.CurrentCamera
		for character, record in characters do
			local root = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not root or not root:IsA("BasePart") or not humanoid then
				continue
			end
			-- Default character sounds can arrive after the streamed root part.
			for name, id in { Splash = SPLASH, Swimming = SWIM } do
				local existing = root:FindFirstChild(name)
				local current = record[name]
				if existing and existing:IsA("Sound") then
					if record.muted[existing] == nil then
						record.muted[existing] = existing.SoundId
						existing.SoundId = ""
					end
				end
				if not current or current.Parent ~= root then
					current = sound(root, "Water" .. name, id, name == "Swimming")
					current.RollOffMode = Enum.RollOffMode.InverseTapered
					current.RollOffMinDistance, current.RollOffMaxDistance = 12, 100
					table.insert(record.owned, current)
					record[name] = current
				end
			end
			local position = root.Position
			local velocity = root.AssemblyLinearVelocity
			local swimming = humanoid:GetState() == Enum.HumanoidStateType.Swimming
			local alive = humanoid.Health > 0
			-- Let Terrain/Humanoid confirm contact instead of assuming everything
			-- below sea level is water (boat cabins and dry floors can be there).
			local stillSubmerged = record.wet
				and position.Y < Biomes.WaterLevel - 0.2
				and humanoid.FloorMaterial == Enum.Material.Air
			local wet = alive and humanoid.SeatPart == nil and inOcean(position) and (swimming or stillSubmerged)
			local near = camera ~= nil and (camera.CFrame.Position - position).Magnitude < 110
			if record.initialized and wet and not record.wet and near and now - record.lastSplash > 0.65 then
				local impact = math.clamp(math.max(record.lastDown, -velocity.Y) / 65, 0, 1)
				record.Splash.Volume = 0.5 + impact * 0.5
				record.Splash.PlaybackSpeed = 1.08 - impact * 0.2
				record.Splash.TimePosition = 0
				record.Splash:Play()
				record.lastSplash = now
			end
			local speed = velocity.Magnitude
			local moving = wet and swimming and near and (speed > 1 or humanoid.MoveDirection.Magnitude > 0.05)
			record.Swimming.PlaybackSpeed = 1.15 + math.clamp(speed / 20, 0, 0.5)
			fade(record.Swimming, if moving then 0.22 + math.clamp(speed / 32, 0, 0.3) else 0, dt)
			record.wet, record.initialized, record.lastDown = wet, true, math.max(0, -velocity.Y)
		end
	end)
end

return EnvironmentAudio
