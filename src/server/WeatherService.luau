-- Replicate a small deterministic forecast, never per-frame rain or wave instances.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
		local state = Weather.getState(workspace:GetServerTimeNow())
		workspace.GlobalWind = state.windDirection * state.windSpeed
		workspace:SetAttribute("WeatherKind", state.kind)
		workspace:SetAttribute("WeatherRain", state.rain)
		workspace:SetAttribute("WeatherWindSpeed", state.windSpeed)
	end
	update(0)
	RunService.Heartbeat:Connect(update)
end

return WeatherService
