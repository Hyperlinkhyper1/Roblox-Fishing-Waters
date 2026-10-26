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
	rainPotential: number,
	stormPotential: number,
	cloudPotential: number,
	windPotential: number,
	systems: { any },
}

Weather.Presets = {
	Clear = { rain = 0, storm = 0, cloudCover = 0, windSpeed = 6 },
	LightRain = { rain = 0.24, storm = 0, cloudCover = 0.5, windSpeed = 18 },
	Rain = { rain = 0.62, storm = 0, cloudCover = 0.8, windSpeed = 32 },
	Storm = { rain = 1, storm = 1, cloudCover = 1, windSpeed = 52 },
	-- Admin-only event: deliberately absent from the automatic forecast.
	BlackHole = { rain = 0.28, storm = 0, cloudCover = 1, windSpeed = 26 },
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
-- Exposed storm cores have up to nine studs of crest-to-trough swell.
-- The lake shelter and boat dry-floor clearance keep harbour travel manageable.
Weather.MaxWaveAmplitude = 4.5
Weather.RadarHalfSize = 5200
Weather.BlackHoleRadius = 250
Weather.RadarResolution = 29
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
	return Vector3.new((p[1] - 870) * 0.85, 0, (p[2] - 1330) * 0.85)
end
local bay = { sketchPoint(Weather.MouthSketch[1]) }
for _, p in Weather.BaySketch do
	table.insert(bay, sketchPoint(p))
end
table.insert(bay, sketchPoint(Weather.MouthSketch[2]))

-- True inside the main island's lake/bay outline, mouth included.
function Weather.inLake(position: Vector3): boolean
	-- Main island is centered on Biomes.Normal.center (0, 0).
	if position.X < -620 or position.X > 530 or position.Z < -560 or position.Z > 400 then
		return false
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
	return inside
end

function Weather.lakeExposure(position: Vector3): number
	-- Keep the field continuous just outside the bay too. A ribbon spans several
	-- samples: a hard polygon cutoff made its ends and normals jump at headlands.
	if position.X < -660 or position.X > 570 or position.Z < -600 or position.Z > 440 then
		return 1
	end
	-- Blend through the western mouth; the inner lake only receives short ripples.
	local mouthA, mouthB = bay[1], bay[#bay]
	local mouth = mouthB - mouthA
	local relative = Vector3.new(position.X, 0, position.Z) - mouthA
	local nearest = mouthA + mouth * math.clamp(relative:Dot(mouth) / mouth:Dot(mouth), 0, 1)
	local distance = (Vector3.new(position.X, 0, position.Z) - nearest).Magnitude
	local shelter = 0.82 * smoothstep(distance / 220)
	if not Weather.inLake(position) then
		local boundaryDistanceSquared = math.huge
		local previous = bay[#bay]
		for _, current in bay do
			local dx, dz = current.X - previous.X, current.Z - previous.Z
			local x, z = position.X - previous.X, position.Z - previous.Z
			local t = math.clamp((x * dx + z * dz) / (dx * dx + dz * dz), 0, 1)
			x, z = x - dx * t, z - dz * t
			boundaryDistanceSquared = math.min(boundaryDistanceSquared, x * x + z * z)
			previous = current
		end
		shelter *= 1 - smoothstep(math.sqrt(boundaryDistanceSquared) / 40)
	end
	return 1 - shelter
end

-- Broad rain bands contain compact storm cores. Their paths never wrap across
-- the map: slow orbital drift and growth let fronts arrive and fade smoothly.
function Weather.getSystems(time: number)
	local seed = workspace:GetAttribute("WeatherSeed") or 1847
	local epoch = workspace:GetAttribute("WeatherEpoch") or time
	local elapsed = time - epoch
	local systems = {}
	for index = 1, 5 do
		local phase = seed * 0.017 + index * 2.39996
		local age = elapsed * (0.00065 + index * 0.00008)
		local angle = phase * 0.31
		table.insert(systems, {
			x = math.sin(phase + age) * 3900,
			z = math.cos(phase * 1.3 + age * 0.83) * 3900,
			cosine = math.cos(angle),
			sine = math.sin(angle),
			radiusX = if index == 1 then 4200 else 1200 + index * 180,
			radiusZ = if index == 1 then 850 else 950 + index * 100,
			strength = 0.72 + 0.28 * math.sin(phase + age * 1.7) ^ 2,
		})
	end
	return systems
end

local function localConditions(position: Vector3, state: State): (number, number, number, number)
	local coverage, core = 0, 0
	for _, system in state.systems do
		local dx, dz = position.X - system.x, position.Z - system.z
		local u = (dx * system.cosine + dz * system.sine) / system.radiusX
		local v = (-dx * system.sine + dz * system.cosine) / system.radiusZ
		local distance = u * u + v * v
		coverage = math.max(coverage, math.exp(-distance * 1.2) * system.strength)
		core = math.max(core, math.exp(-distance * 4.5) * system.strength)
	end
	local rain = state.rainPotential * smoothstep(coverage / 0.85)
	local storm = math.max(state.stormPotential, state.rainPotential * 0.75) * smoothstep(core / 0.85)
	local cloud = math.clamp(state.cloudPotential * (0.2 + coverage * 0.8), 0, 1)
	local wind = 6 + (state.windPotential - 6) * (0.16 + coverage * 0.5 + core * 0.34)
	return rain, storm, cloud, wind
end

local function waveAmplitude(wind: number): number
	return 0.3 + (Weather.MaxWaveAmplitude - 0.3) * math.clamp(wind / 52, 0, 1) ^ 1.65
end

-- Only the authenticated dashboard bridge supplies an event center. A bare
-- weather override cannot activate an event or grant event mutations.
function Weather.blackHolePosition(): Vector3?
	if workspace:GetAttribute("WeatherOverride") ~= "BlackHole" then
		return nil
	end
	local position = workspace:GetAttribute("BlackHolePosition")
	if
		typeof(position) ~= "Vector3"
		or position.X ~= position.X
		or position.Y ~= position.Y
		or position.Z ~= position.Z
		or math.abs(position.X) > Weather.RadarHalfSize
		or math.abs(position.Z) > Weather.RadarHalfSize
		or math.abs(position.Y) > 10000
	then
		return nil
	end
	return position
end

-- Catches use their server-validated fishing position, never the player's
-- camera or a client-reported mutation flag. Distance is across the surface.
function Weather.mutationContext(position: Vector3)
	local center = Weather.blackHolePosition()
	if not center then
		return nil
	end
	local dx, dz = position.X - center.X, position.Z - center.Z
	return { corrupted = true, voidTouched = dx * dx + dz * dz <= Weather.BlackHoleRadius ^ 2 }
end

function Weather.getState(serverTime: number?, position: Vector3?): State
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
	if override == "BlackHole" and not Weather.blackHolePosition() then
		override = nil
	end
	if type(override) == "string" and Weather.Presets[override] then
		target, from, blend = Weather.Presets[override], Weather.Presets[override], 1
	end
	local function mix(key: string): number
		return from[key] + (target[key] - from[key]) * blend
	end
	local gust = 0.94 + 0.06 * math.sin(time * 0.47 + seed)
	local wind = mix("windSpeed") * gust
	local angle = (seed % 360) * math.pi / 180
	local state = {
		kind = if type(override) == "string" and Weather.Presets[override] then override else stage.kind,
		rain = mix("rain"),
		storm = mix("storm"),
		cloudCover = mix("cloudCover"),
		windSpeed = wind,
		windDirection = Vector3.new(math.cos(angle), 0, math.sin(angle)),
		-- Even a calm sea keeps a gentle, visible swell under idle hulls.
		waveAmplitude = waveAmplitude(wind),
		rainPotential = mix("rain"),
		stormPotential = mix("storm"),
		cloudPotential = mix("cloudCover"),
		windPotential = wind,
		systems = Weather.getSystems(time),
	}
	if position then
		state.rain, state.storm, state.cloudCover, state.windSpeed = localConditions(position, state)
		state.waveAmplitude = waveAmplitude(state.windSpeed) * Weather.lakeExposure(position) ^ 2
		state.kind = if override == "BlackHole"
			then "BlackHole"
			elseif state.storm > 0.38 then "Storm"
			elseif state.rain > 0.4 then "Rain"
			elseif state.rain > 0.06 then "LightRain"
			else "Clear"
	end
	return state
end

-- Fixed frequencies preserve phase when the wind strength changes. Three crossing
-- swells avoid identical, mechanical bobbing for every boat. Weights sum to one.
Weather.components = {
	{ weight = 0.62, wavelength = 110, speed = 12, angle = 0, phase = 0 },
	{ weight = 0.26, wavelength = 65, speed = 8, angle = 0.5, phase = 1.8 },
	{ weight = 0.12, wavelength = 34, speed = 5, angle = -0.7, phase = 4.1 },
}

local function heightAt(position: Vector3, time: number, state: State): (number, number)
	local _, _, _, wind = localConditions(position, state)
	local amplitude = waveAmplitude(wind) * Weather.lakeExposure(position) ^ 2
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

-- A compact measured grid, row-major from northwest to southeast. The admin
-- radar displays these samples instead of inventing its own weather shapes.
function Weather.radar(time: number)
	local state = Weather.getState(time)
	local cells = {}
	local peakRain, peakStorm, peakWind, peakWave = 0, 0, 0, 0
	local function rounded(value: number): number
		return math.round(value * 100) / 100
	end
	for row = 0, Weather.RadarResolution - 1 do
		for column = 0, Weather.RadarResolution - 1 do
			local position = Vector3.new(
				-Weather.RadarHalfSize + column * Weather.RadarHalfSize * 2 / (Weather.RadarResolution - 1),
				0,
				-Weather.RadarHalfSize + row * Weather.RadarHalfSize * 2 / (Weather.RadarResolution - 1)
			)
			local rain, storm, _, wind = localConditions(position, state)
			local amplitude = waveAmplitude(wind) * Weather.lakeExposure(position) ^ 2
			table.insert(cells, { rounded(rain), rounded(storm), rounded(wind), rounded(amplitude) })
			peakRain, peakStorm = math.max(peakRain, rain), math.max(peakStorm, storm)
			peakWind, peakWave = math.max(peakWind, wind), math.max(peakWave, amplitude)
		end
	end
	return {
		version = 1,
		resolution = Weather.RadarResolution,
		halfSize = Weather.RadarHalfSize,
		cells = cells,
		peakRain = rounded(peakRain),
		peakStorm = rounded(peakStorm),
		peakWind = rounded(peakWind),
		peakWave = rounded(peakWave),
	}
end

-- Parked hulls stay anchored on the server. This world-space transform carries a
-- hull from the pose it parked in (at parkedAt) to the same swell's pose now, so
-- every client bobs it identically and the server can release it without a snap.
function Weather.parkedOffset(
	rest: CFrame,
	parkedAt: number,
	now: number,
	floorHeight: number?,
	halfBeam: number?,
	halfLength: number?,
	waterlineOffset: Vector3?
): CFrame
	local from = Weather.sample(rest.Position, parkedAt)
	local to = Weather.sample(rest.Position, now)
	-- Match the driven hull's dry-floor clamp even while it is anchored.
	local function dryHeight(sample): number
		if not floorHeight or not halfBeam or not halfLength then
			return sample.height
		end
		local normal = sample.normal
		local forward = (rest.LookVector - normal * rest.LookVector:Dot(normal)).Unit
		local right = forward:Cross(normal).Unit
		local lowestFloor = floorHeight * normal.Y - math.abs(right.Y) * halfBeam - math.abs(forward.Y) * halfLength
		return math.max(sample.height, 0.35 - lowestFloor)
	end
	local axis = from.normal:Cross(to.normal)
	local tilt = if axis.Magnitude > 1e-6
		then CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(from.normal:Dot(to.normal), -1, 1)))
		else CFrame.identity
	local pivot = rest.Position
	local offset = CFrame.new(pivot + Vector3.new(0, dryHeight(to) - dryHeight(from), 0)) * tilt * CFrame.new(-pivot)
	if floorHeight and halfBeam and halfLength and waterlineOffset then
		-- A newly launched hull may start level rather than at the sampled wave
		-- pose. Clamp its actual transformed deck as well as the relative swell.
		local pose = offset * rest
		local center = pose:PointToWorldSpace(Vector3.new(0, floorHeight, 0) - waterlineOffset)
		local lowest = center.Y - math.abs(pose.RightVector.Y) * halfBeam - math.abs(pose.LookVector.Y) * halfLength
		offset = CFrame.new(0, math.max(0, 0.35 - lowest), 0) * offset
	end
	return offset
end

return Weather
