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

local Theme = require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))
local BiomeAtmosphere = {}

local WEATHER_BLEND = TweenInfo.new(0.65, Enum.EasingStyle.Linear)
local DIVE_BLEND = TweenInfo.new(0.3, Enum.EasingStyle.Sine)
local UNDERWATER_BLUE = Color3.fromRGB(65, 150, 210)
local UNDERWATER_FOG_DEEP = Color3.fromRGB(20, 70, 115)
local UNDERWATER_FOG_DENSITY = 0.3
local FADE = TweenInfo.new(1.5, Enum.EasingStyle.Sine)
local LEAVE_MARGIN = 1.1 -- stay in a biome until this far past its edge, so the title doesn't flicker
-- Deep-night targets each biome's look blends toward.
local NIGHT_FOG = Color3.fromRGB(28, 36, 60)
local NIGHT_DECAY = Color3.fromRGB(16, 20, 38)
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
	local title = makeTitle()
	local titleToken = 0
	local surfaceAmbient = Lighting.Ambient
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
		local function blend(instance: Instance, properties: { [string]: any })
			local tween = TweenService:Create(instance, transition, properties)
			table.insert(activeTweens, tween)
			tween:Play()
		end
		local look = biome.look
		local now = workspace:GetServerTimeNow()
		local weather = Weather.getState(now)
		local rain, storm = weather.rain, weather.storm
		local night = DayNight.darkness(DayNight.clockTime(now))
		-- Terrain water keeps nearby scenery clear, while the Atmosphere below adds a
		-- blue fog that swallows distant objects.
		blend(terrain, {
			WaterColor = if underwater then UNDERWATER_BLUE else look.waterColor,
			WaterTransparency = if underwater then 0.9 else 0.55,
		})
		blend(atmosphere, {
			-- Underwater fog starts at the camera; surface haze (sky glow) stays off.
			Offset = if underwater then 0 else Biomes.DistanceFogOffset,
			Color = if underwater
				then UNDERWATER_BLUE
				else look.atmosphereColor:Lerp(Color3.fromRGB(112, 125, 142), rain * 0.65):Lerp(NIGHT_FOG, night * 0.8),
			Decay = if underwater
				then UNDERWATER_FOG_DEEP
				else look.atmosphereDecay:Lerp(Color3.fromRGB(55, 64, 82), rain * 0.5):Lerp(NIGHT_DECAY, night * 0.8),
			Density = if underwater
				then UNDERWATER_FOG_DENSITY
				else math.min(0.5, look.density + rain * 0.13),
			Haze = if underwater then 0 else (look.haze + rain * 1.8) * (1 - night * 0.5),
			Glare = if underwater then 0 else look.glare * (1 - rain) * (1 - night),
		})
		blend(grading, {
			TintColor = if underwater
				then Color3.fromRGB(215, 240, 255)
				else look.tint:Lerp(Color3.fromRGB(177, 193, 215), rain * 0.3):Lerp(NIGHT_TINT, night * 0.6),
			Brightness = if underwater then 0.06 else 0,
			Saturation = if underwater then 0.05 else look.saturation - rain * 0.12 - night * 0.15,
			Contrast = if underwater then 0 else look.contrast + storm * 0.04,
		})
		blend(clouds, {
			Cover = look.cloudCover + (1 - look.cloudCover) * weather.cloudCover,
			Density = 0.5 + weather.cloudCover * 0.4,
			Color = look.cloudColor:Lerp(Color3.fromRGB(75, 83, 99), rain * 0.8):Lerp(NIGHT_CLOUDS, night * 0.8),
		})
		blend(Lighting, {
			Ambient = if underwater then Color3.fromRGB(115, 145, 170) else surfaceAmbient,
			OutdoorAmbient = if underwater
				then Color3.fromRGB(145, 175, 200)
				else look.ambient:Lerp(Color3.fromRGB(68, 78, 96), rain * 0.75):Lerp(NIGHT_AMBIENT, night * 0.85),
			Brightness = (if underwater then 2 else 2 - rain * 0.95 - storm * 0.2) * (1 - night * 0.45),
		})
	end

	local current: Biomes.Biome? = nil
	local underwater = false
	local biomeElapsed = 0.5
	local weatherElapsed = 0.5
	-- Follow the camera (including third-person/free cameras), not the avatar.
	RunService:BindToRenderStep("BiomeAtmosphere", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		Lighting.ClockTime = DayNight.clockTime()
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
		-- A small surface margin avoids flickering as the camera skims the waves.
		local inOcean = math.abs(position.X) < Biomes.MapHalfSize
			and math.abs(position.Z) < Biomes.MapHalfSize
			and position.Y > Biomes.SeaFloor
		local submerged = inOcean and position.Y < Biomes.WaterLevel + (if underwater then 0.1 else -0.1)
		local waterChanged = submerged ~= underwater
		underwater = submerged
		if current and (biomeChanged or waterChanged or weatherElapsed >= 0.5) then
			weatherElapsed = 0
			apply(current, underwater, if waterChanged then DIVE_BLEND else WEATHER_BLEND)
		end
	end)
end

return BiomeAtmosphere
