-- One server clock drives weather, visible swells and boat buoyancy on every client.
local Weather = {}

export type State = {
	kind: string,
	rain: number,
	storm: number,
	cloudCover: number,
	windSpeed: number,
	windDirection: Vector3,
	waveAmplitude: number,
}

Weather.Presets = {
	Clear = { rain = 0, storm = 0, cloudCover = 0, windSpeed = 6 },
	LightRain = { rain = 0.24, storm = 0, cloudCover = 0.5, windSpeed = 18 },
	Rain = { rain = 0.62, storm = 0, cloudCover = 0.8, windSpeed = 32 },
	Storm = { rain = 1, storm = 1, cloudCover = 1, windSpeed = 52 },
}

-- A full front passes over the islands, with a twenty-second blend at each change.
Weather.Schedule = {
	{ kind = "Clear", duration = 150 },
	{ kind = "LightRain", duration = 150 },
	{ kind = "Rain", duration = 180 },
	{ kind = "Storm", duration = 150 },
	{ kind = "Rain", duration = 120 },
	{ kind = "LightRain", duration = 120 },
	{ kind = "Clear", duration = 150 },
}
Weather.TransitionSeconds = 20
-- Terrain remains the swimming surface. Keep the rowboat's 0.92-stud-high
-- seat above it even in a trough; larger offsets would submerge the benches.
Weather.MaxWaveAmplitude = 0.72
Weather.CycleSeconds = 0
for _, stage in Weather.Schedule do
	Weather.CycleSeconds += stage.duration
end

local TAU = math.pi * 2
local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Harbour.BAY, SCALE and SKETCH_CENTER define the real lake/bay, rather than a
-- circle that would also shelter the sea on the other side of the island.
-- scripts/check-weather.mjs guards these coordinates against map changes.
Weather.BaySketch = {
	{ 350, 1555 },
	{ 450, 1553 },
	{ 550, 1565 },
	{ 650, 1598 },
	{ 760, 1640 },
	{ 850, 1640 },
	{ 950, 1620 },
	{ 1030, 1630 },
	{ 1100, 1668 },
	{ 1170, 1690 },
	{ 1240, 1660 },
	{ 1305, 1585 },
	{ 1345, 1480 },
	{ 1362, 1360 },
	{ 1348, 1262 },
	{ 1290, 1182 },
	{ 1200, 1122 },
	{ 1105, 1090 },
	{ 1045, 1050 },
	{ 1012, 980 },
	{ 985, 902 },
	{ 940, 852 },
	{ 870, 818 },
	{ 760, 820 },
	{ 685, 850 },
	{ 652, 905 },
	{ 663, 1000 },
	{ 680, 1118 },
	{ 660, 1190 },
	{ 600, 1255 },
	{ 520, 1300 },
}
Weather.MouthSketch = { { 290, 1565 }, { 430, 1340 } }
local function sketchPoint(p: { number }): Vector3
	return Vector3.new((p[1] - 870) * 1.05, 0, (p[2] - 1330) * 1.05)
end
local bay = { sketchPoint(Weather.MouthSketch[1]) }
for _, p in Weather.BaySketch do
	table.insert(bay, sketchPoint(p))
end
table.insert(bay, sketchPoint(Weather.MouthSketch[2]))

function Weather.lakeExposure(position: Vector3): number
	-- Main island is centered on Biomes.Normal.center (0, 0).
	if position.X < -620 or position.X > 530 or position.Z < -560 or position.Z > 400 then
		return 1
	end
	local inside = false
	local j = #bay
	for i, a in bay do
		local b = bay[j]
		if
			(a.Z > position.Z) ~= (b.Z > position.Z)
			and position.X < (b.X - a.X) * (position.Z - a.Z) / (b.Z - a.Z) + a.X
		then
			inside = not inside
		end
		j = i
	end
	if not inside then
		return 1
	end
	-- Blend through the western mouth; the inner lake only receives short ripples.
	local mouthA, mouthB = bay[1], bay[#bay]
	local mouth = mouthB - mouthA
	local relative = Vector3.new(position.X, 0, position.Z) - mouthA
	local nearest = mouthA + mouth * math.clamp(relative:Dot(mouth) / mouth:Dot(mouth), 0, 1)
	local distance = (Vector3.new(position.X, 0, position.Z) - nearest).Magnitude
	return 1 - 0.82 * smoothstep(distance / 220)
end

function Weather.getState(serverTime: number?): State
	local time = serverTime or workspace:GetServerTimeNow()
	local epoch = workspace:GetAttribute("WeatherEpoch") or time
	local seed = workspace:GetAttribute("WeatherSeed") or 1847
	local elapsed = math.max(0, time - epoch) % Weather.CycleSeconds
	local index = 1
	while elapsed >= Weather.Schedule[index].duration and index < #Weather.Schedule do
		elapsed -= Weather.Schedule[index].duration
		index += 1
	end
	local stage = Weather.Schedule[index]
	local previous = Weather.Schedule[if index == 1 then #Weather.Schedule else index - 1]
	local target, from = Weather.Presets[stage.kind], Weather.Presets[previous.kind]
	local blend = smoothstep(elapsed / Weather.TransitionSeconds)
	-- Server-only attribute is also useful for Studio weather previews.
	local override = workspace:GetAttribute("WeatherOverride")
	if type(override) == "string" and Weather.Presets[override] then
		target, from, blend = Weather.Presets[override], Weather.Presets[override], 1
	end
	local function mix(key: string): number
		return from[key] + (target[key] - from[key]) * blend
	end
	local gust = 0.94 + 0.06 * math.sin(time * 0.47 + seed)
	local wind = mix("windSpeed") * gust
	local angle = (seed % 360) * math.pi / 180
	return {
		kind = if type(override) == "string" and Weather.Presets[override] then override else stage.kind,
		rain = mix("rain"),
		storm = mix("storm"),
		cloudCover = mix("cloudCover"),
		windSpeed = wind,
		windDirection = Vector3.new(math.cos(angle), 0, math.sin(angle)),
		waveAmplitude = 0.16 + (Weather.MaxWaveAmplitude - 0.16) * (wind / 52) ^ 1.65,
	}
end

-- Fixed frequencies preserve phase when the wind strength changes. Three crossing
-- swells avoid identical, mechanical bobbing for every boat. Weights sum to one.
Weather.components = {
	{ weight = 0.62, wavelength = 76, speed = 12, angle = 0, phase = 0 },
	{ weight = 0.26, wavelength = 43, speed = 8, angle = 0.5, phase = 1.8 },
	{ weight = 0.12, wavelength = 23, speed = 5, angle = -0.7, phase = 4.1 },
}

local function heightAt(position: Vector3, time: number, state: State): (number, number)
	local exposure = Weather.lakeExposure(position)
	local amplitude = state.waveAmplitude * exposure
	local height = 0
	for _, wave in Weather.components do
		local cosine, sine = math.cos(wave.angle), math.sin(wave.angle)
		local direction = state.windDirection
		local x = direction.X * cosine - direction.Z * sine
		local z = direction.X * sine + direction.Z * cosine
		local phase = TAU / wave.wavelength * (position.X * x + position.Z * z - time * wave.speed) + wave.phase
		height += math.sin(phase) * wave.weight * amplitude
	end
	return height, amplitude
end

-- Height is an offset from Biomes.WaterLevel. The finite-difference normal also
-- includes the smooth shelter gradient at the mouth of the lake.
function Weather.sample(position: Vector3, time: number, state: State?)
	local current = state or Weather.getState(time)
	local height, amplitude = heightAt(position, time, current)
	local dx = (
		heightAt(position + Vector3.new(1, 0, 0), time, current)
		- heightAt(position - Vector3.new(1, 0, 0), time, current)
	) / 2
	local dz = (
		heightAt(position + Vector3.new(0, 0, 1), time, current)
		- heightAt(position - Vector3.new(0, 0, 1), time, current)
	) / 2
	return {
		height = height,
		amplitude = amplitude,
		normal = Vector3.new(-dx, 1, -dz).Unit,
		pitch = math.atan(dz),
		roll = -math.atan(dx),
	}
end

-- Cheap height-only variant for the many points in a visible crest.
Weather.heightAt = heightAt

return Weather
