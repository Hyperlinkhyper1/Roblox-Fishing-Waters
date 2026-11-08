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
		-- Coarse (every in-game quarter hour): clients step the sun themselves, this
		-- only keeps loading players close without replicating ClockTime 4x a second.
		Lighting.ClockTime = math.floor(DayNight.clockTime(now) * 4) / 4
		-- Rain and wind drift continuously; rounded, most quarter-second ticks write the
		-- same value, which Roblox does not replicate (GlobalWind also redraws grass/particles).
		local wind = state.windDirection * state.windSpeed
		if (workspace.GlobalWind - wind).Magnitude > 0.05 then
			workspace.GlobalWind = wind
		end
		workspace:SetAttribute("WeatherKind", state.kind)
		workspace:SetAttribute("WeatherRain", math.round(state.rain * 100) / 100)
		workspace:SetAttribute("WeatherFog", math.round(state.fog * 100) / 100)
		workspace:SetAttribute("WeatherWindSpeed", math.round(state.windSpeed * 20) / 20)
	end
	update(0)
	RunService.Heartbeat:Connect(update)
end

return WeatherService
