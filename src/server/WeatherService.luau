-- Replicate a small deterministic forecast, never per-frame rain or wave instances.
-- The same epoch drives the time of day; clients animate it every frame, the
-- server only keeps Lighting close for players still loading in.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DayNight = require(ReplicatedStorage.Shared.DayNight)
local Weather = require(ReplicatedStorage.Shared.Weather)
local WeatherService = {}
local started = false

function WeatherService.start()
	if started then
		return
	end
	started = true
	workspace:SetAttribute("WeatherEpoch", workspace:GetServerTimeNow())
	workspace:SetAttribute("WeatherSeed", Random.new():NextInteger(1, 1000000))
	local elapsed = 1
	local function update(dt: number)
		elapsed += dt
		if elapsed < 0.25 then
			return
		end
		elapsed %= 0.25
		local now = workspace:GetServerTimeNow()
		local state = Weather.getState(now)
		Lighting.ClockTime = DayNight.clockTime(now)
		workspace.GlobalWind = state.windDirection * state.windSpeed
		workspace:SetAttribute("WeatherKind", state.kind)
		workspace:SetAttribute("WeatherRain", state.rain)
		workspace:SetAttribute("WeatherWindSpeed", state.windSpeed)
	end
	update(0)
	RunService.Heartbeat:Connect(update)
end

return WeatherService
