-- Townsfolk walking the harbour village.
--
-- The server plans each pedestrian's next trip (a walking path, then a stop:
-- browse a stall, step into a shop, pause at the fountain, or leave town) and
-- publishes it as one string attribute. Every client turns that trip into a
-- position from the synchronised server clock, so nothing streams per frame:
-- a pedestrian costs one small attribute write per trip, and clients decide
-- locally how much detail and how many motion updates it deserves.
--
-- Pure maths on plain numbers (no Roblox types), so it runs under lute too.
local Pedestrians = {}

Pedestrians.FOLDER = "Pedestrians"
Pedestrians.FADE_SECONDS = 0.8
-- How far a pedestrian walks on through a doorway while fading out.
Pedestrians.DOOR_DEPTH = 2.4

-- Detail tiers by distance from the camera. Each tier has an enter distance and
-- a slightly larger exit distance so a pedestrian on the boundary doesn't flicker
-- between models. `interval` is how often its motion is updated (0 = every frame).
Pedestrians.TIERS = {
	{ name = "Near", enter = 70, exit = 78, interval = 0 },
	{ name = "Mid", enter = 150, exit = 162, interval = 1 / 8 },
	{ name = "Far", enter = 280, exit = 300, interval = 1 / 3 },
}
-- Past the last tier a pedestrian isn't drawn or updated at all.
Pedestrians.HIDDEN = #Pedestrians.TIERS + 1
-- At most this many animated avatars at once; the rest stand still like the mid tier.
Pedestrians.NEAR_CAP = 14

-- Townsfolk wear real Roblox avatars. The server fills this folder with
-- HumanoidDescriptions named "1".."AVATAR_COUNT"; a pedestrian's look seed picks its slot.
Pedestrians.AVATAR_FOLDER = "PedestrianAvatars"
Pedestrians.AVATAR_COUNT = 18

-- A single crowd travels around the island, with extra traffic for occupied shops.
Pedestrians.BASE_POPULATION = 64
Pedestrians.MAX_VISITORS = 16

function Pedestrians.islandPopulation(clock: number, rain: number, shops: number): number
	local daytime = Pedestrians.BASE_POPULATION + 4 * math.clamp(shops, 0, 15)
	return math.max(8, math.ceil(daytime * Pedestrians.activity(clock) * Pedestrians.weatherFactor(rain)))
end

function Pedestrians.avatarSlot(seed: number): number
	return math.floor(seed) % Pedestrians.AVATAR_COUNT + 1
end

export type Trip = {
	start: number,
	speed: number,
	emerge: boolean, -- fades in at the first point (out of a doorway, or arriving in town)
	leave: boolean, -- removed by the server once the stop ends
	stop: string, -- "n" none, "p" pause, "b" browse, "e" enter a doorway, "x" vanish where it stands
	stopSeconds: number,
	yaw: number?, -- facing at the stop (into the doorway for "e")
	bag: number, -- 0 empty-handed, otherwise a shop bag colour index
	points: { number }, -- x, y, z triples; y is the ground under the feet
	lengths: { number }, -- cumulative distance at each point
	total: number,
}

export type Sample = {
	x: number,
	y: number,
	z: number,
	yaw: number,
	moving: boolean,
	stride: number, -- distance walked, for limb swing that never slides
	alpha: number, -- 0 fully visible, 1 gone
}

local function round(value: number, step: number): number
	return math.floor(value / step + 0.5) * step
end

local function flatAngle(dx: number, dz: number): number?
	if dx * dx + dz * dz < 1e-6 then
		return nil
	end
	-- Yaw of a CFrame whose look vector (-Z) points along (dx, dz)
	return math.atan2(-dx, -dz)
end
Pedestrians.flatAngle = flatAngle

function Pedestrians.encode(trip: {
	start: number,
	speed: number,
	emerge: boolean?,
	leave: boolean?,
	stop: string?,
	stopSeconds: number?,
	yaw: number?,
	bag: number?,
	points: { number },
}): string
	local flags = (if trip.emerge then "E" else "") .. (if trip.leave then "L" else "")
	local header = string.format(
		"%.2f;%.2f;%s;%s;%.1f;%s;%d",
		trip.start,
		trip.speed,
		flags,
		trip.stop or "n",
		trip.stopSeconds or 0,
		if trip.yaw then string.format("%.2f", trip.yaw) else "",
		trip.bag or 0
	)
	local parts = { header }
	local points = trip.points
	for i = 1, #points, 3 do
		table.insert(
			parts,
			string.format("%.1f,%.1f,%.1f", round(points[i], 0.1), round(points[i + 1], 0.1), round(points[i + 2], 0.1))
		)
	end
	return table.concat(parts, "|")
end

function Pedestrians.decode(text: string): Trip?
	if type(text) ~= "string" or text == "" then
		return nil
	end
	local fields = string.split(text, "|")
	local header = string.split(fields[1], ";")
	if #header < 7 then
		return nil
	end
	local start, speed = tonumber(header[1]), tonumber(header[2])
	if not start or not speed or speed <= 0 then
		return nil
	end
	local points, lengths = {}, {}
	local total = 0
	for i = 2, #fields do
		local xyz = string.split(fields[i], ",")
		local x, y, z = tonumber(xyz[1]), tonumber(xyz[2]), tonumber(xyz[3])
		if x and y and z then
			local n = #points
			if n >= 3 then
				local dx, dy, dz = x - points[n - 2], y - points[n - 1], z - points[n]
				total += math.sqrt(dx * dx + dy * dy + dz * dz)
			end
			table.insert(points, x)
			table.insert(points, y)
			table.insert(points, z)
			table.insert(lengths, total)
		end
	end
	if #points < 3 then
		return nil
	end
	local flags = header[3]
	return {
		start = start,
		speed = speed,
		emerge = string.find(flags, "E", 1, true) ~= nil,
		leave = string.find(flags, "L", 1, true) ~= nil,
		stop = header[4],
		stopSeconds = tonumber(header[5]) or 0,
		yaw = tonumber(header[6]),
		bag = tonumber(header[7]) or 0,
		points = points,
		lengths = lengths,
		total = total,
	}
end

-- Seconds from the trip's start until its stop is over: when the server plans the next one.
function Pedestrians.duration(trip: { total: number, speed: number, stop: string, stopSeconds: number }): number
	local walk = trip.total / trip.speed
	local fade = if trip.stop == "e" or trip.stop == "x" then Pedestrians.FADE_SECONDS else 0
	return walk + math.max(trip.stopSeconds, fade)
end

-- Length of a flat x, y, z path.
function Pedestrians.pathLength(points: { number }): number
	local total = 0
	for i = 4, #points, 3 do
		local dx, dy, dz = points[i] - points[i - 3], points[i + 1] - points[i - 2], points[i + 2] - points[i - 1]
		total += math.sqrt(dx * dx + dy * dy + dz * dz)
	end
	return total
end

local function segmentYaw(points: { number }, i: number): number?
	-- Heading of the segment that starts at point i (1-based point index)
	local a = (i - 1) * 3
	local b = i * 3
	if b + 3 > #points then
		return nil
	end
	return flatAngle(points[b + 1] - points[a + 1], points[b + 3] - points[a + 3])
end

local function lastYaw(points: { number }): number
	for i = #points // 3 - 1, 1, -1 do
		local yaw = segmentYaw(points, i)
		if yaw then
			return yaw
		end
	end
	return 0
end

local function firstYaw(points: { number }): number
	for i = 1, #points // 3 - 1 do
		local yaw = segmentYaw(points, i)
		if yaw then
			return yaw
		end
	end
	return 0
end

-- Where the pedestrian is at server time `now`, which way it faces and how visible it is.
function Pedestrians.sample(trip: Trip, now: number, out: Sample?): Sample
	local result: Sample = out
		or { x = 0, y = 0, z = 0, yaw = 0, moving = false, stride = 0, alpha = 0 }
	local points = trip.points
	local t = now - trip.start
	local fade = Pedestrians.FADE_SECONDS
	result.moving = false
	result.alpha = 0
	if t < 0 then
		-- Planned ahead: wait at the first point (still inside the doorway if it emerges)
		result.x, result.y, result.z = points[1], points[2], points[3]
		result.yaw = firstYaw(points)
		result.stride = 0
		result.alpha = if trip.emerge then 1 else 0
		return result
	end
	if trip.emerge and t < fade then
		result.alpha = 1 - t / fade
	end
	local walked = t * trip.speed
	if walked < trip.total then
		local lengths = trip.lengths
		-- Binary search for the segment holding `walked`
		local lo, hi = 1, #lengths
		while hi - lo > 1 do
			local mid = (lo + hi) // 2
			if lengths[mid] <= walked then
				lo = mid
			else
				hi = mid
			end
		end
		local span = lengths[hi] - lengths[lo]
		local f = if span > 0 then (walked - lengths[lo]) / span else 0
		local a, b = (lo - 1) * 3, (hi - 1) * 3
		result.x = points[a + 1] + (points[b + 1] - points[a + 1]) * f
		result.y = points[a + 2] + (points[b + 2] - points[a + 2]) * f
		result.z = points[a + 3] + (points[b + 3] - points[a + 3]) * f
		result.yaw = flatAngle(points[b + 1] - points[a + 1], points[b + 3] - points[a + 3]) or lastYaw(points)
		result.moving = true
		result.stride = walked
		return result
	end
	-- At the end of the path: the stop
	local n = #points
	result.x, result.y, result.z = points[n - 2], points[n - 1], points[n]
	result.stride = trip.total
	local since = t - trip.total / trip.speed
	if trip.stop == "e" then
		local yaw = trip.yaw or lastYaw(points)
		result.yaw = yaw
		local f = math.min(since / fade, 1)
		-- Step on through the doorway while fading out
		local depth = Pedestrians.DOOR_DEPTH * f
		result.x -= math.sin(yaw) * depth
		result.z -= math.cos(yaw) * depth
		result.moving = f < 1
		result.stride = trip.total + depth
		result.alpha = math.max(result.alpha, f)
	elseif trip.stop == "x" then
		result.yaw = lastYaw(points)
		result.alpha = math.max(result.alpha, math.min(since / fade, 1))
	else
		result.yaw = trip.yaw or lastYaw(points)
	end
	return result
end

-- Which detail tier a pedestrian `distance` studs away belongs in, given the tier it is in now.
function Pedestrians.tierFor(distance: number, current: number): number
	local tiers = Pedestrians.TIERS
	for index, tier in tiers do
		-- Staying in (or moving out to) a tier uses the wider exit distance
		local limit = if current <= index then tier.exit else tier.enter
		if distance <= limit then
			return index
		end
	end
	return Pedestrians.HIDDEN
end

-- How busy the streets are (0-1) at a clock hour: quiet at night, full through the day.
function Pedestrians.activity(clock: number): number
	local function ramp(a: number, b: number, value: number): number
		return math.clamp((value - a) / (b - a), 0, 1)
	end
	if clock < 12 then
		return 0.15 + 0.85 * ramp(5.5, 8.5, clock)
	end
	return 0.15 + 0.85 * (1 - ramp(17.5, 22, clock))
end

-- Fewer people out in the rain.
function Pedestrians.weatherFactor(rain: number): number
	return 1 - 0.65 * math.clamp(rain, 0, 1)
end

return Pedestrians
