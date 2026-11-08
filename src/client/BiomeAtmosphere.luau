-- Blends water colour, fog and colour grading toward whichever biome the camera is in,
-- runs the day/night clock and darkens every biome's look at night. The area name
-- banner lives in AreaBanner.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local DayNight = require(ReplicatedStorage.Shared.DayNight)
local Weather = require(ReplicatedStorage.Shared.Weather)
local PlayerSettings = require(script.Parent.PlayerSettings)

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

local BiomeAtmosphere = {}

local WEATHER_BLEND = TweenInfo.new(0.65, Enum.EasingStyle.Linear)
local DIVE_BLEND = TweenInfo.new(0.3, Enum.EasingStyle.Sine)
local SATURATION_REDUCTION = 0.1
local UNDERWATER_BLUE = Color3.fromRGB(65, 150, 210)
local UNDERWATER_FOG_COLOR = Color3.fromRGB(32, 96, 128)
local UNDERWATER_VISIBILITY = 10 / 0.28 -- 10 metres in Roblox studs
-- Terrain uses its own underwater fog instead of Lighting.FogEnd. Calibrated in
-- Studio: nearby objects remain visible, while a marker at 36 studs fades out.
local UNDERWATER_TRANSPARENCY = 0.01
local LEAVE_MARGIN = 1.1 -- stay in a biome until this far past its edge, so the look doesn't flicker
-- Deep-night targets each biome's look blends toward. The fog matches the night
-- sky so the horizon doesn't glow as a pale band, and distant islands fade into darkness.
local NIGHT_FOG = Color3.fromRGB(18, 24, 42)
local NIGHT_DECAY = Color3.fromRGB(8, 11, 24)
-- Dusk and dawn warm the far haze, with a glow on the sun's side.
local TWILIGHT_FOG = Color3.fromRGB(226, 156, 124)
local TWILIGHT_DECAY = Color3.fromRGB(118, 70, 78)
local NIGHT_TINT = Color3.fromRGB(188, 204, 255)
local NIGHT_CLOUDS = Color3.fromRGB(38, 44, 64)
local NIGHT_AMBIENT = Color3.fromRGB(44, 54, 86)
-- Sea mist: pale and slightly blue, lit warm by a low sun. It forms over the
-- late night, peaks around dawn and burns off through the morning.
local MIST_COLOR = Color3.fromRGB(206, 214, 220)
local MIST_DECAY = Color3.fromRGB(150, 162, 172)
local SUNSET_CLOUDS = Color3.fromRGB(255, 166, 128)
local GOLDEN_FOG = Color3.fromRGB(236, 206, 160)
-- Humid air keeps the haze up for a while after the rain has stopped (seconds).
local WET_LINGER = 180
-- Fog banks drift across the sea, so mist comes and goes as you sail.
local BANK_SCALE = 1 / 1400
local BANK_DRIFT = 1 / 240
local TAU = math.pi * 2

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- 0 by day; a light mist after dark that thickens towards dawn, gone by ~09:30.
function BiomeAtmosphere.mistAt(clock: number): number
	if clock >= 12 then
		return 0.35 * smoothstep((clock - 19) / 2.5)
	end
	local build = 0.35 + 0.65 * smoothstep((clock - 1.5) / 3.5)
	return build * (1 - smoothstep((clock - 7) / 2.5))
end

-- Patchy fog banks, 0..1, drifting slowly with time.
function BiomeAtmosphere.fogBank(x: number, z: number, time: number): number
	local u, v, t = x * BANK_SCALE, z * BANK_SCALE, time * BANK_DRIFT
	local n = (math.sin(u * 1.3 + t) + math.sin(v * 1.7 - t * 0.8 + 1.7) + math.sin((u + v) * 0.9 + t * 0.5 + 4.1)) / 3
	return smoothstep((n + 0.25) / 0.9)
end

-- Warm low-sun light in the hour or two either side of twilight.
local function goldenHour(clock: number): number
	if clock >= 12 then
		return smoothstep((clock - 15.5) / 1.5) * (1 - smoothstep((clock - 18) / 1))
	end
	return smoothstep((clock - 5.5) / 1) * (1 - smoothstep((clock - 7.5) / 1.5))
end

local function ensure<T>(parent: Instance, className: string): T
	local existing = parent:FindFirstChildOfClass(className)
	if existing then
		return existing :: any
	end
	local created = Instance.new(className)
	created.Parent = parent
	return created :: any
end

function BiomeAtmosphere.start()
	local terrain = workspace.Terrain
	local atmosphere = ensure(Lighting, "Atmosphere") :: Atmosphere
	-- Weather lightning owns a separate effect, regardless of startup order.
	local grading = Lighting:FindFirstChild("BiomeColorGrading") :: ColorCorrectionEffect?
	if not grading then
		grading = Instance.new("ColorCorrectionEffect")
		grading.Name = "BiomeColorGrading"
		grading.Parent = Lighting
	end
	local clouds = ensure(terrain, "Clouds") :: Clouds
	local sky = ensure(Lighting, "Sky") :: Sky
	local celestialBodiesShown = sky.CelestialBodiesShown
	-- A smaller, sharper sun and moon read as far away; the Atmosphere's glare
	-- supplies the glow around the sun. A denser star field for clear nights.
	sky.SunAngularSize = 11
	sky.MoonAngularSize = 9
	sky.StarCount = 4000
	-- Crepuscular rays where the sun breaks through haze and mist, and a soft
	-- bloom on the sun and its glitter on the water. Both are cheap post effects.
	local rays = Lighting:FindFirstChild("SkySunRays") :: SunRaysEffect?
	if not rays then
		rays = Instance.new("SunRaysEffect")
		rays.Name = "SkySunRays"
		rays.Parent = Lighting
	end
	rays.Spread = 0.75
	rays.Intensity = 0.04
	local bloom = Lighting:FindFirstChild("SkyBloom") :: BloomEffect?
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "SkyBloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.5
	bloom.Size = 28
	bloom.Threshold = 1.7
	local wetness, wetClock = 0, os.clock()
	local surfaceAmbient = Lighting.Ambient
	local surfaceFogColor = Lighting.FogColor
	local surfaceFogStart = Lighting.FogStart
	local surfaceFogEnd = Lighting.FogEnd
	local activeTweens: { Tween } = {}

	local function apply(biome: Biomes.Biome, underwater: boolean, transition: TweenInfo)
		for _, tween in activeTweens do
			tween:Cancel()
		end
		table.clear(activeTweens)
		-- This runs every half second. Tweening values that barely moved kept Lighting,
		-- Atmosphere and grading changing on every frame, and each change relights the
		-- scene; drift below these thresholds waits until it adds up.
		local function blend(instance: Instance, properties: { [string]: any })
			local changed = {}
			local any = false
			for name, target in properties do
				local current = (instance :: any)[name]
				local differs
				if typeof(current) ~= typeof(target) then
					differs = true
				elseif typeof(target) == "Color3" then
					differs = math.max(
						math.abs(current.R - target.R),
						math.abs(current.G - target.G),
						math.abs(current.B - target.B)
					) > 1.5 / 255
				elseif type(target) == "number" then
					differs = math.abs(current - target) > 0.004
				else
					differs = current ~= target
				end
				if differs then
					changed[name] = target
					any = true
				end
			end
			if not any then
				return
			end
			local tween = TweenService:Create(instance, transition, changed)
			table.insert(activeTweens, tween)
			tween:Play()
		end
		local look = biome.look
		local now = workspace:GetServerTimeNow()
		local camera = workspace.CurrentCamera
		local weather = Weather.getState(now, if camera then camera.CFrame.Position else Vector3.zero)
		local rain, storm = weather.rain, weather.storm
		local eye = if camera then camera.CFrame.Position else Vector3.new(0, 0, 0)
		-- Reuse one engine Atmosphere and this 2 Hz update. Broad drifting banks
		-- vary visibility without transparent fog meshes or particle overdraw.
		local bank = BiomeAtmosphere.fogBank(eye.X, eye.Z, now)
		-- A marine layer is thick near the water, gradually thinning aloft.
		local fog = (weather.fog or 0) * (0.82 + bank * 0.18)
			* (1 - smoothstep((eye.Y - Biomes.WaterLevel - 35) / 220) * 0.65)
		local overcast = math.max(weather.cloudCover, math.clamp(rain / 0.08, 0, 1))
		-- The built-in sky otherwise draws the moon and stars through rain clouds.
		sky.CelestialBodiesShown = celestialBodiesShown and overcast < 0.85 and fog < 0.35 and weather.kind ~= "BlackHole"
		clouds.Enabled = true
		local clock = DayNight.clockTime(now)
		local night = DayNight.darkness(clock)
		-- Humid air: rises with the rain at once, then thins out over WET_LINGER.
		local wallClock = os.clock()
		wetness = math.max(rain, wetness - (wallClock - wetClock) / WET_LINGER)
		wetClock = wallClock
		-- Rain and wind break the mist up; a storm leaves none.
		local mist = math.max(
			fog,
			BiomeAtmosphere.mistAt(clock) * (0.4 + 0.6 * bank)
				* (1 - storm) * (1 - math.clamp(rain / 0.6, 0, 1) * 0.5)
		)
		local golden = goldenHour(clock) * (1 - overcast)
		-- Light under a supercell turns dim and faintly green.
		local cell = if camera then Weather.supercellCover(camera.CFrame.Position, weather.supercell) else 0
		local blackHole = weather.kind == "BlackHole"
		-- Distance fog is disabled while Atmosphere is in Lighting. Terrain also
		-- has its own underwater fog: set its opacity immediately on entry so the
		-- first submerged frame cannot see through the ocean during a dive tween.
		Lighting.FogColor = if blackHole then Color3.fromRGB(29, 5, 48)
			elseif underwater then UNDERWATER_FOG_COLOR else surfaceFogColor
		Lighting.FogStart = if underwater then 0 else surfaceFogStart
		Lighting.FogEnd = if underwater then UNDERWATER_VISIBILITY else surfaceFogEnd
		atmosphere.Parent = if underwater then nil else Lighting
		local waterColor = if blackHole then Color3.fromRGB(33, 6, 53)
			elseif underwater then UNDERWATER_BLUE else look.waterColor
		if underwater then
			terrain.WaterColor = waterColor
			terrain.WaterTransparency = UNDERWATER_TRANSPARENCY
		else
			blend(terrain, {
				WaterColor = waterColor,
				WaterTransparency = if blackHole then 0.22 else Biomes.SurfaceWaterTransparency,
			})
		end
		terrain.WaterReflectance = Biomes.WaterReflectance
		if blackHole then
			-- The admin event covers every biome, including the water beneath it.
			if not underwater then
				blend(atmosphere, {
					Offset = Biomes.DistanceFogOffset,
					Color = Color3.fromRGB(67, 17, 93),
					Decay = Color3.fromRGB(26, 3, 44),
					Density = 0.46,
					Haze = 3.2,
					Glare = 0,
				})
			end
			blend(grading, {
				TintColor = Color3.fromRGB(177, 108, 233),
				Brightness = if underwater then -0.04 else -0.12,
				Saturation = -0.2 - SATURATION_REDUCTION,
				Contrast = 0.16,
			})
			blend(clouds, { Cover = 1, Density = 0.9, Color = Color3.fromRGB(31, 7, 48) })
			blend(rays, { Intensity = 0 })
			blend(Lighting, {
				Ambient = Color3.fromRGB(39, 15, 61),
				OutdoorAmbient = Color3.fromRGB(47, 18, 68),
				Brightness = 0.45,
			})
			return
		end
		if not underwater then
			-- Peaks halfway through dusk/dawn; clouds hide the sunset.
			local twilight = 4 * night * (1 - night) * (1 - overcast)
			-- Under a night cloud deck the fog lifts toward the clouds instead of a black wall.
			local nightFog = NIGHT_FOG:Lerp(NIGHT_CLOUDS, overcast * 0.6)
			-- Mist glows with whatever light there is: warm at dawn, dim blue at night.
			local mistColor = MIST_COLOR:Lerp(TWILIGHT_FOG, twilight * 0.5):Lerp(nightFog, night * 0.85)
			local density = math.min(
				0.6,
				look.density + rain * 0.13 + (wetness - rain) * 0.08 + night * 0.06 + mist * 0.2
			)
			blend(atmosphere, {
				-- Mist swallows distant silhouettes instead of leaving a hard horizon.
				Offset = Biomes.DistanceFogOffset * (1 - mist * 0.8) * (1 - fog * 0.5),
				Color = look.atmosphereColor
					:Lerp(GOLDEN_FOG, golden * 0.3)
					:Lerp(Color3.fromRGB(112, 125, 142), rain * 0.65)
					:Lerp(TWILIGHT_FOG, twilight * 0.45)
					:Lerp(nightFog, night)
					:Lerp(mistColor, math.max(mist * 0.7, fog * 0.95)),
				Decay = look.atmosphereDecay
					:Lerp(Color3.fromRGB(55, 64, 82), rain * 0.5)
					:Lerp(TWILIGHT_DECAY, twilight * 0.5)
					:Lerp(NIGHT_DECAY, night)
					:Lerp(MIST_DECAY:Lerp(NIGHT_DECAY, night * 0.8), math.max(mist * 0.6, fog * 0.85)),
				-- A touch thicker at night so far scenery dissolves into the dark;
				-- mist and humid post-rain air thicken it most.
				Density = density + (0.7 - density) * fog,
				-- Thin haze on clear nights; a bright haze layer reads as a glowing horizon.
				Haze = (look.haze + rain * 1.8 + (wetness - rain) * 0.9) * (1 - night * 0.7 * (1 - overcast))
					+ mist * 2.4 + fog * 1.4,
				-- A low sun blooms through the mist.
				Glare = (look.glare * (1 - night) + twilight * 0.5 + golden * 0.25 + mist * 0.5 * (1 - night))
					* (1 - rain) * (1 - fog * 0.85),
			})
		end
		-- Rays only where there is a sun to see; mist makes them strongest.
		blend(rays, {
			Intensity = if underwater then 0 else (0.035 + mist * 0.1 + golden * 0.04) * (1 - overcast) * (1 - night),
		})
		blend(grading, {
			TintColor = if underwater
				then Color3.fromRGB(215, 240, 255)
				else look.tint
					:Lerp(Color3.fromRGB(177, 193, 215), rain * 0.3)
					:Lerp(Color3.fromRGB(176, 214, 188), cell * 0.45)
					:Lerp(NIGHT_TINT, night * 0.6),
			Brightness = if underwater then 0.06 else 0,
			Saturation = (if underwater then 0.05 else look.saturation - rain * 0.12 - night * 0.15)
				- SATURATION_REDUCTION - (if underwater then 0 else fog * 0.08),
			Contrast = if underwater then 0 else (look.contrast + storm * 0.04) * (1 - fog) - fog * 0.04,
		})
		-- Fair-weather cover wanders over a quarter of an hour so the sky is never
		-- the same twice; overcast still closes it completely.
		local fairCover = math.clamp(look.cloudCover + 0.1 * math.sin(now * TAU / 900), 0, 1)
		local fairDensity = 0.45 + 0.1 * math.sin(now * TAU / 1300 + 1.3)
		local twilightClouds = 4 * night * (1 - night)
		blend(clouds, {
			Cover = fairCover + (1 - fairCover) * overcast,
			Density = fairDensity + (1 - fairDensity) * overcast,
			-- Sunset lights the cloud undersides orange and pink before night greys them.
			Color = look.cloudColor
				:Lerp(SUNSET_CLOUDS, math.max(twilightClouds * 0.6, golden * 0.2) * (1 - rain))
				:Lerp(Color3.fromRGB(75, 83, 99), rain * 0.8)
				:Lerp(NIGHT_CLOUDS, night * 0.8),
		})
		blend(Lighting, {
			Ambient = if underwater then Color3.fromRGB(115, 145, 170) else surfaceAmbient,
			OutdoorAmbient = if underwater
				then Color3.fromRGB(145, 175, 200)
				else look.ambient:Lerp(Color3.fromRGB(68, 78, 96), rain * 0.75)
					:Lerp(Color3.fromRGB(151, 159, 167), fog * 0.35):Lerp(NIGHT_AMBIENT, night * 0.85),
			Brightness = (if underwater then 2 else 2 - rain * 0.95 - storm * 0.2 - cell * 0.35 - fog * 0.4) * (1 - night * 0.45),
		})
	end

	local current: Biomes.Biome? = nil
	local underwater = false
	local biomeElapsed = 0.5
	local weatherElapsed = 0.5
	local lastClock: number? = nil
	-- Follow the camera (including third-person/free cameras), not the avatar.
	RunService:BindToRenderStep("BiomeAtmosphere", Enum.RenderPriority.Camera.Value + 1, profiled("BiomeAtmosphere", function(dt: number)
		local camera = workspace.CurrentCamera
		if not camera then
			PlayerSettings.setUnderwater(false)
			return
		end
		-- Stepped, and only written when the step changes (see DayNight.lightingClock).
		-- Compare with what we wrote (ClockTime reads back rounded), but also re-assert
		-- when the server's replicated write lands late and pulls the sun back a step.
		local clock = DayNight.lightingClock()
		if clock ~= lastClock or math.abs(Lighting.ClockTime - clock) > 0.001 then
			lastClock = clock
			Lighting.ClockTime = clock
		end
		local position = camera.CFrame.Position
		biomeElapsed += dt
		weatherElapsed += dt
		local biomeChanged = false
		if biomeElapsed >= 0.5 then
			biomeElapsed = 0
			local stay = current and current ~= Biomes.OpenSea and Biomes.depthIn(current, position) < LEAVE_MARGIN
			local biome = if stay then current :: Biomes.Biome else Biomes.at(position)
			if biome ~= current then
				current = biome
				biomeChanged = true
			end
		end
		-- Enter at the surface immediately; only delay the exit slightly to avoid
		-- flickering as the camera skims the waves.
		local inOcean = not Players.LocalPlayer:GetAttribute("MetroRiding") and Biomes.inOceanBounds(position)
			and position.Y > Biomes.SeaFloor
		local submerged = inOcean and position.Y < Biomes.WaterLevel + (if underwater then 0.1 else 0)
		local waterChanged = submerged ~= underwater
		underwater = submerged
		PlayerSettings.setUnderwater(underwater)
		if current and (biomeChanged or waterChanged or weatherElapsed >= 0.5) then
			weatherElapsed = 0
			apply(current, underwater, if waterChanged then DIVE_BLEND else WEATHER_BLEND)
		end
	end))
end

return BiomeAtmosphere
