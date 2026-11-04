-- Blends water colour, fog and colour grading toward whichever biome the camera is in,
-- and shows the area's name when you cross into it. Also runs the day/night clock
-- and darkens every biome's look at night.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local DayNight = require(ReplicatedStorage.Shared.DayNight)
local Weather = require(ReplicatedStorage.Shared.Weather)
local PlayerSettings = require(script.Parent.PlayerSettings)

local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))
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
local FADE = TweenInfo.new(1.5, Enum.EasingStyle.Sine)
local LEAVE_MARGIN = 1.1 -- stay in a biome until this far past its edge, so the title doesn't flicker
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

local function ensure<T>(parent: Instance, className: string): T
	local existing = parent:FindFirstChildOfClass(className)
	if existing then
		return existing :: any
	end
	local created = Instance.new(className)
	created.Parent = parent
	return created :: any
end

local function makeTitle(): TextLabel
	local gui = Instance.new("ScreenGui")
	gui.Name = "AreaTitle"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.2)
	label.Size = UDim2.new(0.8, 0, 0, 60)
	label.BackgroundTransparency = 1
	Theme.text(label)
	label.TextSize = 44
	label.TextColor3 = Theme.Colors.Text
	label.TextStrokeColor3 = Theme.Colors.Black
	label.TextStrokeTransparency = 1
	label.TextTransparency = 1
	label.Parent = gui

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return label
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
	local title = makeTitle()
	local titleToken = 0
	local surfaceAmbient = Lighting.Ambient
	local surfaceFogColor = Lighting.FogColor
	local surfaceFogStart = Lighting.FogStart
	local surfaceFogEnd = Lighting.FogEnd
	local activeTweens: { Tween } = {}

	local function showTitle(text: string)
		titleToken += 1
		local token = titleToken
		title.Text = text
		TweenService:Create(title, FADE, { TextTransparency = 0, TextStrokeTransparency = 0 }):Play()
		task.delay(4, function()
			if token == titleToken then
				TweenService:Create(title, FADE, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			end
		end)
	end

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
				if typeof(target) == "Color3" then
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
		local overcast = math.max(weather.cloudCover, math.clamp(rain / 0.08, 0, 1))
		-- The built-in sky otherwise draws the moon and stars through rain clouds.
		sky.CelestialBodiesShown = celestialBodiesShown and overcast < 0.85 and weather.kind ~= "BlackHole"
		clouds.Enabled = true
		local night = DayNight.darkness(DayNight.clockTime(now))
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
			blend(atmosphere, {
				Offset = Biomes.DistanceFogOffset,
				Color = look.atmosphereColor
					:Lerp(Color3.fromRGB(112, 125, 142), rain * 0.65)
					:Lerp(TWILIGHT_FOG, twilight * 0.45)
					:Lerp(nightFog, night),
				Decay = look.atmosphereDecay
					:Lerp(Color3.fromRGB(55, 64, 82), rain * 0.5)
					:Lerp(TWILIGHT_DECAY, twilight * 0.5)
					:Lerp(NIGHT_DECAY, night),
				-- A touch thicker at night so far scenery dissolves into the dark.
				Density = math.min(0.5, look.density + rain * 0.13 + night * 0.06),
				-- Thin haze on clear nights; a bright haze layer reads as a glowing horizon.
				Haze = (look.haze + rain * 1.8) * (1 - night * 0.7 * (1 - overcast)),
				Glare = (look.glare * (1 - night) + twilight * 0.5) * (1 - rain),
			})
		end
		blend(grading, {
			TintColor = if underwater
				then Color3.fromRGB(215, 240, 255)
				else look.tint
					:Lerp(Color3.fromRGB(177, 193, 215), rain * 0.3)
					:Lerp(Color3.fromRGB(176, 214, 188), cell * 0.45)
					:Lerp(NIGHT_TINT, night * 0.6),
			Brightness = if underwater then 0.06 else 0,
			Saturation = (if underwater then 0.05 else look.saturation - rain * 0.12 - night * 0.15)
				- SATURATION_REDUCTION,
			Contrast = if underwater then 0 else look.contrast + storm * 0.04,
		})
		blend(clouds, {
			Cover = look.cloudCover + (1 - look.cloudCover) * overcast,
			Density = 0.5 + overcast * 0.5,
			Color = look.cloudColor:Lerp(Color3.fromRGB(75, 83, 99), rain * 0.8):Lerp(NIGHT_CLOUDS, night * 0.8),
		})
		blend(Lighting, {
			Ambient = if underwater then Color3.fromRGB(115, 145, 170) else surfaceAmbient,
			OutdoorAmbient = if underwater
				then Color3.fromRGB(145, 175, 200)
				else look.ambient:Lerp(Color3.fromRGB(68, 78, 96), rain * 0.75):Lerp(NIGHT_AMBIENT, night * 0.85),
			Brightness = (if underwater then 2 else 2 - rain * 0.95 - storm * 0.2 - cell * 0.35) * (1 - night * 0.45),
		})
	end

	local current: Biomes.Biome? = nil
	local underwater = false
	local biomeElapsed = 0.5
	local weatherElapsed = 0.5
	local lastClock: number? = nil
	-- Follow the camera (including third-person/free cameras), not the avatar.
	RunService:BindToRenderStep("BiomeAtmosphere", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		local camera = workspace.CurrentCamera
		if not camera then
			PlayerSettings.setUnderwater(false)
			return
		end
		-- Stepped, and only written when the step changes (see DayNight.lightingClock).
		-- Compare with what we wrote: ClockTime reads back rounded.
		local clock = DayNight.lightingClock()
		if clock ~= lastClock then
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
				showTitle(biome.name)
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
	end)
end

return BiomeAtmosphere
