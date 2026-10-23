-- Camera-local precipitation keeps the whole ocean affordable. The shared clock
-- drives intensity and lightning, so every player sees the same passing weather.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Weather = require(ReplicatedStorage.Shared.Weather)

local WeatherController = {}
local started = false
local CELL_SIZE = 22
local RAIN_HEIGHT = 28
local UPDATE_INTERVAL = 0.2
local LIGHTNING_INTERVAL = 9
-- Roblox Creator Store: Rain Effect by Roblox; thunder by Pro Sound Effects.
local RAIN_SOUND = "rbxassetid://1516791621"
local THUNDER_SOUND = "rbxassetid://9120018088"
local STREAK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

type RainCell = {
	part: Part,
	emitter: ParticleEmitter,
	offset: Vector3,
	open: boolean,
}

local function emitterPart(name: string, size: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = parent
	return part
end

local function streak(name: string, parent: Part): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Enabled = false
	emitter.Texture = STREAK_TEXTURE
	emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	-- VelocityParallel rotates the texture axes; negative squash stretches along
	-- movement. This uses a bundled engine texture, without an uploaded image.
	emitter.Squash = NumberSequence.new(-3)
	emitter.LightInfluence = 0.65
	emitter.LightEmission = 0.08
	emitter.Color = ColorSequence.new(Color3.fromRGB(195, 215, 225))
	emitter.Rotation = NumberRange.new(0)
	emitter.RotSpeed = NumberRange.new(0)
	emitter.VelocityInheritance = 0
	emitter.LockedToPart = false
	emitter.Parent = parent
	return emitter
end

local function hash(value: number): number
	local result = math.sin(value * 127.1 + 311.7) * 43758.5453
	return result - math.floor(result)
end

local function soundId(attribute: string, defaultId: string): string
	local override = workspace:GetAttribute(attribute)
	if type(override) == "number" and override > 0 and override < math.huge then
		return "rbxassetid://" .. tostring(math.floor(override))
	elseif type(override) == "string" and string.match(override, "^rbxassetid://%d+$") then
		return override
	end
	return defaultId
end

function WeatherController.start()
	if started then
		return
	end
	started = true
	local effects = Instance.new("Folder")
	effects.Name = "WeatherEffects"
	effects.Parent = workspace
	local cells: { RainCell } = {}
	for x = -1, 1 do
		for z = -1, 1 do
			local part = emitterPart("RainCell", Vector3.new(CELL_SIZE, 0.1, CELL_SIZE), effects)
			local emitter = streak("Rain", part)
			emitter.EmissionDirection = Enum.NormalId.Bottom
			emitter.SpreadAngle = Vector2.new(2, 2)
			emitter.Size = NumberSequence.new(0.11)
			emitter.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.08, 0.42),
				NumberSequenceKeypoint.new(0.86, 0.52),
				NumberSequenceKeypoint.new(1, 1),
			})
			table.insert(
				cells,
				{ part = part, emitter = emitter, offset = Vector3.new(x * CELL_SIZE, 0, z * CELL_SIZE), open = false }
			)
		end
	end
	local windPart = emitterPart("WindField", Vector3.new(78, 24, 1), effects)
	local wind = streak("WindStreaks", windPart)
	wind.EmissionDirection = Enum.NormalId.Front
	wind.SpreadAngle = Vector2.new(3, 2)
	wind.Squash = NumberSequence.new(-5)
	wind.Size = NumberSequence.new(0.16)
	wind.Lifetime = NumberRange.new(1.6, 2.2)
	wind.Color = ColorSequence.new(Color3.fromRGB(220, 232, 232))

	-- Own effect rather than competing with biome/daylight lighting properties.
	local flash = Instance.new("ColorCorrectionEffect")
	flash.Name = "WeatherLightning"
	flash.Enabled = false
	flash.Parent = Lighting
	local thunder = Instance.new("Sound")
	thunder.Name = "WeatherThunder"
	thunder.SoundId = soundId("WeatherThunderSoundId", THUNDER_SOUND)
	thunder.Volume = 0.5
	thunder.Parent = SoundService
	local rainSound = Instance.new("Sound")
	rainSound.Name = "WeatherRain"
	rainSound.SoundId = soundId("WeatherRainSoundId", RAIN_SOUND)
	rainSound.Looped = true
	rainSound.Volume = 0
	rainSound.Parent = SoundService

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true
	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Exclude
	groundParams.IgnoreWater = false
	local player = Players.LocalPlayer
	local lastCharacter: Model? = nil
	local sheltered = true
	local hidden = true
	local elapsed = UPDATE_INTERVAL
	local lastBucket: number? = nil
	local strikeTime = math.huge
	local struck = true
	local flashTime = -math.huge
	local thunderToken = 0
	local previousStorm = 0
	local currentSkyFraction = 0

	local function hide()
		for _, cell in cells do
			cell.emitter.Enabled = false
			cell.emitter:Clear()
		end
		wind.Enabled = false
		wind:Clear()
	end

	RunService:BindToRenderStep("WeatherEffects", Enum.RenderPriority.Camera.Value + 2, function(dt: number)
		local camera = workspace.CurrentCamera
		if not camera then
			rainSound.Volume = 0
			if rainSound.IsPlaying then
				rainSound:Stop()
			end
			if not hidden then
				hide()
				hidden = true
				thunderToken += 1
			end
			flash.Enabled = false
			return
		end
		local now = workspace:GetServerTimeNow()
		local state = Weather.getState(now)
		local effectsEnabled = player:GetAttribute("WeatherEffectsEnabled") ~= false
		local position = camera.CFrame.Position
		local submerged = math.abs(position.X) < Biomes.MapHalfSize
			and math.abs(position.Z) < Biomes.MapHalfSize
			and position.Y > Biomes.SeaFloor
			and position.Y < Biomes.WaterLevel - 0.15
		local character = player.Character
		if character ~= lastCharacter then
			lastCharacter = character
			local exclusions: { Instance } = { effects }
			if character then
				table.insert(exclusions, character)
			end
			rayParams.FilterDescendantsInstances = exclusions
			groundParams.FilterDescendantsInstances = exclusions
			elapsed = UPDATE_INTERVAL
		end
		for _, cell in cells do
			cell.part.Position = position + cell.offset + Vector3.new(0, RAIN_HEIGHT, 0)
		end
		local windDirection = state.windDirection
		local windCenter = position + Vector3.new(0, 4, 0)
		windPart.CFrame = CFrame.lookAt(windCenter - windDirection * 23, windCenter)
		elapsed += dt
		if elapsed >= UPDATE_INTERVAL then
			elapsed = 0
			-- Hide the whole field under a roof to prevent adjacent emitters from
			-- drifting through it. Per-cell tests also clip its outdoor edges.
			sheltered = workspace:Raycast(position + Vector3.new(0, 0.15, 0), Vector3.new(0, 160, 0), rayParams) ~= nil
			local openCells = 0
			local rainSpeed = 70 + state.rain * 28
			for _, cell in cells do
				local center = position + cell.offset
				cell.open = not sheltered
					and not submerged
					and workspace:Raycast(center + Vector3.new(0, 0.15, 0), Vector3.new(0, 160, 0), rayParams)
						== nil
				if cell.open then
					openCells += 1
				end
				local emitter = cell.emitter
				emitter.Rate = 84 * state.rain
				emitter.Speed = NumberRange.new(rainSpeed * 0.94, rainSpeed)
				emitter.Acceleration = windDirection * state.windSpeed * 1.5
				-- End rain at terrain, water, or the nearest solid surface, rather
				-- than letting droplets continue below the lake and house floors.
				local ground = if cell.open
					then workspace:Raycast(cell.part.Position, Vector3.new(0, -256, 0), groundParams)
					else nil
				local groundY = if ground then ground.Position.Y else Biomes.WaterLevel
				local lifetime = math.clamp((cell.part.Position.Y - groundY) / rainSpeed, 0.06, 1.25)
				emitter.Lifetime = NumberRange.new(lifetime * 0.86, lifetime)
				emitter.Enabled = effectsEnabled and cell.open and state.rain > 0.01
				if not cell.open then
					emitter:Clear()
				end
			end
			currentSkyFraction = openCells / #cells
			local windStrength = math.clamp((state.windSpeed - 6) / 46, 0, 1)
			wind.Speed = NumberRange.new(math.max(12, state.windSpeed * 0.85), math.max(14, state.windSpeed * 1.1))
			wind.Rate = 4 + windStrength * 27
			wind.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.2, 0.88 - windStrength * 0.2),
				NumberSequenceKeypoint.new(0.75, 0.91 - windStrength * 0.13),
				NumberSequenceKeypoint.new(1, 1),
			})
			wind.Enabled = effectsEnabled and not sheltered and not submerged
		end
		local shouldHide = sheltered or submerged or not effectsEnabled
		if shouldHide and not hidden then
			hide()
		elseif hidden and not shouldHide then
			elapsed = UPDATE_INTERVAL
		end
		hidden = shouldHide

		-- Keep audio independent of the particle-performance toggle. Fade the same
		-- loop with the forecast instead of restarting it as rainfall changes.
		local rainId = soundId("WeatherRainSoundId", RAIN_SOUND)
		if rainSound.SoundId ~= rainId then
			rainSound:Stop()
			rainSound.SoundId = rainId
		end
		local exposure = if submerged then 0.08 elseif sheltered then 0.3 else 1
		local targetVolume = state.rain * 0.55 * exposure
		rainSound.Volume += (targetVolume - rainSound.Volume) * (1 - math.exp(-dt * 3))
		if targetVolume > 0.001 then
			if not rainSound.IsPlaying then
				rainSound:Play()
			end
		elseif rainSound.Volume < 0.001 then
			rainSound.Volume = 0
			if rainSound.IsPlaying then
				rainSound:Stop()
			end
		end

		if state.storm <= 0.1 and previousStorm > 0.1 then
			thunderToken += 1
			thunder:Stop()
		end
		previousStorm = state.storm
		local bucket = math.floor(now / LIGHTNING_INTERVAL)
		if bucket ~= lastBucket then
			lastBucket = bucket
			local seed = workspace:GetAttribute("WeatherSeed") or 1
			if type(seed) ~= "number" then
				seed = 1
			end
			strikeTime = bucket * LIGHTNING_INTERVAL + 1 + hash(bucket + seed) * 4
			struck = strikeTime < now or hash(bucket * 3 + seed) > 0.35 + state.storm * 0.6
		end
		if not struck and now >= strikeTime then
			struck = true
			if state.storm > 0.15 then
				flashTime = now
				thunderToken += 1
				local token = thunderToken
				local strength = state.storm
				task.delay(1.1 + hash(bucket * 7) * 2.6, function()
					if token == thunderToken and Weather.getState(workspace:GetServerTimeNow()).storm > 0.1 then
						thunder.SoundId = soundId("WeatherThunderSoundId", THUNDER_SOUND)
						thunder.Volume = (0.22 + strength * 0.43) * (0.45 + currentSkyFraction * 0.55)
						thunder:Play()
					end
				end)
			end
		end
		local age = now - flashTime
		local pulse = if age < 0.08
			then 1 - age / 0.08
			elseif age > 0.15 and age < 0.27 then (1 - (age - 0.15) / 0.12) * 0.7
			else 0
		flash.Enabled = effectsEnabled and pulse > 0 and state.storm > 0.1 and not submerged
		flash.Brightness = pulse * (0.12 + state.storm * 0.2)
	end)
end

return WeatherController
