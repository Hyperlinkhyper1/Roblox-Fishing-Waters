-- NPC fishers keep a quiet server from feeling empty: when few people are online, one or two
-- locals drive small fishing boats around the main island's lake and stop to fish.
--
-- Nothing about them is simulated or replicated per frame. The server (NpcFisherService) finds
-- a water route once, publishes it as a string attribute, and only flips each fisher's Active
-- attribute as people join and leave. Every client draws the boat and the angler itself and
-- poses them from this module's timeline and the shared server clock, so all clients agree
-- on where each boat is without any network traffic.
--
-- Pure Luau with plain numbers (no Roblox types), so scripts/check-npc-fishers.mjs can run it.
local NpcFishers = {}

NpcFishers.FOLDER = "NpcFishers" -- ReplicatedStorage folder: fisher Configurations and the boat template
NpcFishers.TEMPLATE = "BoatTemplate"
NpcFishers.MAX = 2

-- Boat motion (studs, seconds)
NpcFishers.CRUISE_SPEED = 14
NpcFishers.ACCELERATION = 2.5
-- Heading looks this far ahead of and behind the boat along the route, which rounds each
-- corner of the route over about a hull length instead of snapping at the vertex.
NpcFishers.LOOK = 9

-- Time spent at each fishing spot
NpcFishers.FISH_MIN = 45
NpcFishers.FISH_MAX = 85
NpcFishers.CATCH_CHANCE = 0.7

-- Fewer than 3 people: two fishers. Fewer than 6: one. Otherwise the lake has enough boats.
function NpcFishers.countFor(players: number): number
	if players < 3 then
		return 2
	elseif players < 6 then
		return 1
	end
	return 0
end

-- Deterministic value in [0, 1) from up to three integers.
function NpcFishers.hash(a: number, b: number?, c: number?): number
	local h = 2166136
	for _, value in { a, b or 0, c or 0 } do
		h = (h * 31 + math.floor(value) % 1000003) % 2147483647
		h = (h * 48271) % 2147483647
	end
	return h / 2147483647
end

export type Point = { x: number, z: number, stop: boolean }

-- "x,z,s;x,z,s;..." with s = 1 at fishing spots. The route is a closed loop.
function NpcFishers.encode(points: { Point }): string
	local parts = table.create(#points)
	for index, point in points do
		parts[index] = string.format("%.1f,%.1f,%d", point.x, point.z, if point.stop then 1 else 0)
	end
	return table.concat(parts, ";")
end

export type Route = {
	xs: { number },
	zs: { number },
	cum: { number }, -- distance along the loop at each point; cum[n + 1] closes the loop
	length: number,
	stops: { number }, -- distance along the loop of each fishing spot, ascending
}

function NpcFishers.decode(text: string): Route?
	local xs, zs, flags = {}, {}, {}
	for x, z, s in string.gmatch(text, "(-?[%d%.]+),(-?[%d%.]+),(%d)") do
		table.insert(xs, tonumber(x) :: number)
		table.insert(zs, tonumber(z) :: number)
		table.insert(flags, s == "1")
	end
	local count = #xs
	if count < 2 then
		return nil
	end
	local cum, stops = { 0 }, {}
	for index = 1, count do
		local nextIndex = index % count + 1
		local dx, dz = xs[nextIndex] - xs[index], zs[nextIndex] - zs[index]
		cum[index + 1] = cum[index] + math.sqrt(dx * dx + dz * dz)
		if flags[index] then
			table.insert(stops, cum[index])
		end
	end
	local length = cum[count + 1]
	if length <= 1 or #stops == 0 then
		return nil
	end
	return { xs = xs, zs = zs, cum = cum, length = length, stops = stops }
end

-- Point on the closed loop `distance` along it.
function NpcFishers.pointAt(route: Route, distance: number): (number, number)
	local length = route.length
	distance %= length
	local cum = route.cum
	-- Binary search for the segment: cum[low] <= distance < cum[low + 1]
	local low, high = 1, #route.xs
	while low < high do
		local mid = (low + high + 1) // 2
		if cum[mid] <= distance then
			low = mid
		else
			high = mid - 1
		end
	end
	local nextIndex = low % #route.xs + 1
	local span = cum[low + 1] - cum[low]
	local t = if span > 0 then (distance - cum[low]) / span else 0
	local xs, zs = route.xs, route.zs
	return xs[low] + (xs[nextIndex] - xs[low]) * t, zs[low] + (zs[nextIndex] - zs[low]) * t
end

-- Yaw (radians, Roblox convention: 0 faces -Z) of the route around `distance`.
function NpcFishers.headingAt(route: Route, distance: number): number
	local ax, az = NpcFishers.pointAt(route, distance - NpcFishers.LOOK)
	local bx, bz = NpcFishers.pointAt(route, distance + NpcFishers.LOOK)
	return math.atan2(-(bx - ax), -(bz - az))
end

-- Seconds a leg of `length` takes, accelerating from rest to cruise and braking to rest.
function NpcFishers.travelTime(length: number): number
	local v, a = NpcFishers.CRUISE_SPEED, NpcFishers.ACCELERATION
	if length >= v * v / a then
		return 2 * v / a + (length - v * v / a) / v
	end
	return 2 * math.sqrt(length / a)
end

-- Distance covered `t` seconds into a leg of `length` (same profile as travelTime).
function NpcFishers.travelDistance(length: number, t: number): number
	local v, a = NpcFishers.CRUISE_SPEED, NpcFishers.ACCELERATION
	local total = NpcFishers.travelTime(length)
	t = math.clamp(t, 0, total)
	local peak = math.min(v, math.sqrt(length * a))
	local rampTime = peak / a
	local rampDistance = peak * peak / (2 * a)
	if t <= rampTime then
		return 0.5 * a * t * t
	elseif t >= total - rampTime then
		local left = total - t
		return length - 0.5 * a * left * left
	end
	return rampDistance + (t - rampTime) * peak
end

export type Stop = { at: number, fish: number, travel: number, leg: number, start: number }
export type Plan = { stops: { Stop }, period: number }

-- The fisher's loop: at each spot it fishes, then drives to the next one.
function NpcFishers.plan(route: Route, seed: number): Plan
	local stops, clock = {}, 0
	local count = #route.stops
	for index, at in route.stops do
		local nextAt = if index < count then route.stops[index + 1] else route.stops[1] + route.length
		local leg = nextAt - at
		local fish = NpcFishers.FISH_MIN
			+ (NpcFishers.FISH_MAX - NpcFishers.FISH_MIN) * NpcFishers.hash(seed, index, 7)
		local travel = NpcFishers.travelTime(leg)
		table.insert(stops, { at = at, fish = fish, travel = travel, leg = leg, start = clock })
		clock += fish + travel
	end
	return { stops = stops, period = clock }
end

export type State = {
	distance: number, -- along the route
	speed: number, -- studs per second
	fishing: number?, -- seconds since arriving at the current spot, while stopped
	fishDuration: number,
	stop: number, -- index of the current (or last) spot
	loop: number, -- how many times the loop has been completed
}

-- Where the fisher is at `elapsed` seconds since the route was published.
function NpcFishers.state(plan: Plan, elapsed: number): State
	local period = plan.period
	local loop = elapsed // period
	local t = elapsed - loop * period
	local stops = plan.stops
	-- Few spots per loop: a linear scan is cheaper than anything clever.
	local index = #stops
	for i = 2, #stops do
		if stops[i].start > t then
			index = i - 1
			break
		end
	end
	local stop = stops[index]
	local into = t - stop.start
	if into < stop.fish then
		return { distance = stop.at, speed = 0, fishing = into, fishDuration = stop.fish, stop = index, loop = loop }
	end
	local travelled = into - stop.fish
	local distance = NpcFishers.travelDistance(stop.leg, travelled)
	local ahead = NpcFishers.travelDistance(stop.leg, travelled + 0.1)
	return {
		distance = stop.at + distance,
		speed = (ahead - distance) / 0.1,
		fishing = nil,
		fishDuration = stop.fish,
		stop = index,
		loop = loop,
	}
end

-- What the angler is doing `elapsed` seconds into a stop of `duration` seconds, given how
-- long the walk between the helm and the fishing spot takes. Returns the phase and how far
-- through it (0..1). Phases in order:
--   settle, walkOut, turn, windup, cast, wait, bite, reel, stow, walkBack, seated
local SETTLE, TURN, WINDUP, CAST, BITE, REEL, STOW, SEATED = 1, 0.4, 0.45, 0.35, 1.2, 1.6, 0.6, 1
NpcFishers.FLIGHT = 0.9 -- seconds the bobber flies once the rod comes forward

function NpcFishers.activity(elapsed: number, duration: number, walk: number): (string, number)
	local function phase(name: string, start: number, length: number): (string, number)
		return name, math.clamp((elapsed - start) / length, 0, 1)
	end
	local walkOut = SETTLE
	local turn = walkOut + walk
	local windup = turn + TURN
	local cast = windup + WINDUP
	local wait = cast + CAST
	local seated = duration - SEATED
	local walkBack = seated - walk
	local stow = walkBack - STOW
	local reel = stow - REEL
	local bite = reel - BITE
	if elapsed < walkOut then
		return phase("settle", 0, SETTLE)
	elseif elapsed < turn then
		return phase("walkOut", walkOut, walk)
	elseif elapsed < windup then
		return phase("turn", turn, TURN)
	elseif elapsed < cast then
		return phase("windup", windup, WINDUP)
	elseif elapsed < wait then
		return phase("cast", cast, CAST)
	elseif elapsed < bite then
		return phase("wait", wait, math.max(bite - wait, 1e-3))
	elseif elapsed < reel then
		return phase("bite", bite, BITE)
	elseif elapsed < stow then
		return phase("reel", reel, REEL)
	elseif elapsed < walkBack then
		return phase("stow", stow, STOW)
	elseif elapsed < seated then
		return phase("walkBack", walkBack, walk)
	end
	return phase("seated", seated, SEATED)
end

-- Seconds since the cast began (the bobber leaves at the start of "cast"), for the bobber flight.
function NpcFishers.castStart(walk: number): number
	return SETTLE + walk + TURN + WINDUP
end

return NpcFishers
