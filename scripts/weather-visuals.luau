-- Run with node scripts/check-weather-visuals.mjs. Production client source is
-- inserted below; these mocks test lifecycle and intensity, not live rendering.
-- MOCKS --

NumberRange = {
	new = function(low, high)
		return { Min = low, Max = high or low }
	end,
}
NumberSequence = {
	new = function(...)
		return { Values = { ... } }
	end,
}
local NumberSequenceKeypoint = {
	new = function(time, value)
		return { Time = time, Value = value }
	end,
}
local RaycastParams = {
	new = function()
		return {}
	end,
}
Enum.RenderPriority = { Camera = { Value = 200 } }
local originalNewIndex = instanceMt.__newindex
function instanceMt.__newindex(self, key, value)
	if key == "Position" then
		self._props.CFrame = CFrame.new(value)
	else
		originalNewIndex(self, key, value)
	end
end

function instanceMethods:Clear()
	self.ClearCount = (self.ClearCount or 0) + 1
end
function instanceMethods:Play()
	self.PlayCount = (self.PlayCount or 0) + 1
	self.IsPlaying = true
end
function instanceMethods:Stop()
	self.StopCount = (self.StopCount or 0) + 1
	self.IsPlaying = false
end

workspace = Instance.new("Folder")
workspace.Name = "Workspace"
local now = 0
function workspace:GetServerTimeNow()
	return now
end
local roof = false
local raycasts = 0
function workspace:Raycast(origin, direction, _params)
	raycasts += 1
	if direction.Y > 0 then
		return if roof then { Position = origin + Vector3.new(0, 5, 0) } else nil
	end
	return { Position = Vector3.new(origin.X, 0, origin.Z) }
end
local camera = { CFrame = CFrame.new(0, 8, 0) }
workspace.CurrentCamera = camera
workspace:SetAttribute("WeatherSeed", 1847)

local lighting = Instance.new("Folder")
local sounds = Instance.new("Folder")
local weatherEnabled = true
local players = {
	LocalPlayer = {
		Character = Instance.new("Model"),
		GetAttribute = function(_, key)
			return if key == "WeatherEffectsEnabled" then weatherEnabled else nil
		end,
	},
}
local callbacks = {}
local bindCount = 0
local runService = {}
function runService:BindToRenderStep(name, _priority, callback)
	bindCount += 1
	callbacks[name] = callback
end
local services =
	{ Lighting = lighting, SoundService = sounds, Players = players, RunService = runService, ReplicatedStorage = {} }
game.GetService = function(_, name)
	return services[name]
end
local delayed = {}
local task = {
	delay = function(delay, callback)
		table.insert(delayed, { at = now + delay, callback = callback })
	end,
}
local state = { rain = 0, storm = 0, windSpeed = 6, windDirection = Vector3.new(1, 0, 0) }
dependencies.Biomes = { MapHalfSize = 5200, SeaFloor = -64, WaterLevel = 0 }
dependencies.Weather = {
	getState = function()
		return state
	end,
}

local function loadClient()
	-- CLIENT --
end
local Client = loadClient()
local function step(dt)
	now += dt
	callbacks.WeatherEffects(dt)
	for index = #delayed, 1, -1 do
		if delayed[index].at <= now then
			local callback = delayed[index].callback
			table.remove(delayed, index)
			callback()
		end
	end
end

Client.start()
Client.start()
assert(bindCount == 1, "Repeated startup must not duplicate the render loop")
local effects = workspace:FindFirstChild("WeatherEffects")
local wind = effects:FindFirstChild("WindField"):FindFirstChild("WindStreaks")
local rain = {}
for _, item in effects:GetDescendants() do
	if item.Name == "Rain" then
		table.insert(rain, item)
	end
end
assert(#rain == 9 and #effects:GetChildren() == 10, "Weather must use a bounded, camera-local field")
step(0.2)
assert(wind.Enabled and wind.Speed.Min == 12, "Clear weather must retain gentle wind streaks")
for _, emitter in rain do
	assert(not emitter.Enabled, "Clear weather must not rain")
end
local clearWindRate = wind.Rate
local rainSound = sounds:FindFirstChild("WeatherRain")
assert(
	rainSound.SoundId == "rbxassetid://1516791621" and rainSound.Looped,
	"Rain must loop the stock Roblox rain asset"
)
assert(rainSound.Volume == 0 and not rainSound.IsPlaying, "Clear weather must keep rain audio silent")
state.rain, state.windSpeed = 0.3, 18
step(0.2)
local lightRainVolume = rainSound.Volume
assert(rainSound.IsPlaying and lightRainVolume > 0, "Light rain must start audible rainfall")
local lightRainRate, lightWindRate = rain[1].Rate, wind.Rate
for _, emitter in rain do
	assert(
		emitter.Enabled and emitter.Rate > 0 and emitter.Lifetime.Max < 0.6,
		"Light rain must fall and end at the water"
	)
end
assert(lightWindRate > clearWindRate, "Light rain must strengthen visible wind")
state.rain, state.windSpeed = 1, 52
step(0.2)
assert(
	rainSound.Volume > lightRainVolume and rainSound.PlayCount == 1,
	"Heavier rain must grow louder without restarting the loop"
)
assert(
	rain[1].Rate > lightRainRate and wind.Rate > lightWindRate and wind.Speed.Min > 40,
	"Worse weather must increase rain and wind amount and wind speed"
)
assert(rain[1].Acceleration.X > 70, "Heavy rain must drift with stronger wind")
print("PASS bounded/idempotent weather startup, rain intensity, wind speed and water-limited lifetime")

roof = true
local outdoorRainVolume = rainSound.Volume
step(0.2)
assert(rainSound.Volume < outdoorRainVolume and rainSound.IsPlaying, "Shelter must soften the rain audio")
assert(not wind.Enabled, "Shelter must suppress indoor wind streaks")
for _, emitter in rain do
	assert(not emitter.Enabled and emitter.ClearCount > 0, "Shelter must clear rain before it passes through a roof")
end
roof = false
camera.CFrame = CFrame.new(0, -2, 0)
local shelteredRainVolume = rainSound.Volume
step(0.2)
assert(rainSound.Volume < shelteredRainVolume, "Diving must further soften rain audio")
assert(not wind.Enabled and not rain[1].Enabled, "Submerged cameras must not show rain or wind")
camera.CFrame = CFrame.new(100, 12, 20)
step(0.2)
assert(wind.Enabled and rain[1].Enabled, "Weather must recover outdoors after diving")
step(1 / 60) -- settle the immediate resample after the camera leaves shelter
local firstPosition = rain[1].Parent.Position
camera.CFrame = CFrame.new(110, 12, 20)
local raysBefore = raycasts
step(1 / 60)
assert(rain[1].Parent.Position.X - firstPosition.X == 10, "Rain must follow the camera every frame")
assert(raycasts == raysBefore, "Roof raycasts must be throttled separately from camera motion")
workspace.CurrentCamera = nil
step(0.2)
assert(not rainSound.IsPlaying and rainSound.Volume == 0, "Missing camera must stop rain audio")
assert(not wind.Enabled and not rain[1].Enabled, "Missing camera must disable all weather particles")
workspace.CurrentCamera = camera
step(0.2)
assert(rainSound.IsPlaying, "Camera recovery must restore rain audio")
local count = #effects:GetDescendants()
for _ = 1, 120 do
	step(1 / 60)
end
assert(#effects:GetDescendants() == count, "Animation must reuse emitters rather than allocating each frame")
print("PASS roof shelter, underwater suppression, camera following/loss/recovery and bounded animation allocation")

local flash = lighting:FindFirstChild("WeatherLightning")
weatherEnabled = false
step(0.2)
assert(rainSound.IsPlaying and rainSound.Volume > 0, "Disabling weather visuals must preserve weather audio")
assert(not wind.Enabled and not rain[1].Enabled and not flash.Enabled, "Performance setting disables weather visuals")
assert(state.rain == 1 and state.windSpeed == 52, "Visual settings must preserve shared weather")
weatherEnabled = true
step(0.2)
assert(wind.Enabled and rain[1].Enabled, "Enabling weather restores current rain and wind")
print("PASS persistent performance toggle hides and restores weather visuals")
local thunder = sounds:FindFirstChild("WeatherThunder")
assert(thunder.SoundId == "rbxassetid://9120018088", "Thunder must use the configured verified asset")
state.storm = 1
local flashed = false
for _ = 1, 1200 do
	step(0.05)
	if flash.Enabled then
		flashed = true
		break
	end
end
assert(flashed and #delayed == 1, "Storms must flash and queue delayed thunder")
assert(not thunder.PlayCount, "Thunder must follow lightning after a delay")
state.storm = 0
step(0.2)
step(5)
assert(not thunder.PlayCount and not flash.Enabled, "Clearing weather must cancel pending thunder and flashes")
state.storm = 1
workspace:SetAttribute("WeatherThunderSoundId", "rbxassetid://123456")
for _ = 1, 1200 do
	step(0.05)
	if #delayed > 0 then
		break
	end
end
assert(#delayed == 1, "Later storms must recover lightning after cancellation")
step(4)
assert(
	thunder.PlayCount == 1 and thunder.SoundId == "rbxassetid://123456",
	"Delayed thunder must play once and honor the sound override"
)
print("PASS storm lightning, delayed thunder, clear-weather cancellation and sound override")
state.rain, state.storm = 0, 0
step(5)
assert(not rainSound.IsPlaying and rainSound.Volume == 0, "Clear weather must fade out and stop rain audio")
workspace:SetAttribute("WeatherRainSoundId", 123456)
state.rain = 0.5
step(0.2)
assert(rainSound.IsPlaying and rainSound.SoundId == "rbxassetid://123456", "Rain must honor numeric audio overrides")
workspace:SetAttribute("WeatherRainSoundId", "invalid")
step(0.2)
assert(
	rainSound.IsPlaying and rainSound.SoundId == "rbxassetid://1516791621",
	"Invalid rain overrides must restore stock audio"
)
assert(#sounds:GetChildren() == 2, "Weather must reuse its two sound instances")
print("PASS stock rain loop, intensity, shelter/diving, camera recovery, clear-weather fade and audio override")
