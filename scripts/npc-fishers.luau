-- Exercises Shared.NpcFishers: the player-count rule, route encoding, and that every client's
-- timeline moves the boat smoothly (no jumps, stops at rest, angler phases in order).
local NpcFishers = (function()
-- NPC_FISHERS_SOURCE --
end)()

local failures = 0
local function check(condition: boolean, message: string)
	if not condition then
		failures += 1
		print("FAIL: " .. message)
	end
end

-- Fewer than 3 players: two fishers; fewer than 6: one; otherwise none.
for players, expected in { [0] = 2, [1] = 2, [2] = 2, [3] = 1, [4] = 1, [5] = 1, [6] = 0, [7] = 0, [20] = 0 } do
	check(NpcFishers.countFor(players) == expected, `countFor({players}) should be {expected}`)
end

-- A 200 x 100 rectangle with spots at two corners.
local points = {
	{ x = 0, z = 0, stop = true },
	{ x = 200, z = 0, stop = false },
	{ x = 200, z = 100, stop = true },
	{ x = 0, z = 100, stop = false },
}
local route = NpcFishers.decode(NpcFishers.encode(points))
assert(route, "route should decode")
check(math.abs(route.length - 600) < 1e-6, "loop length should be 600, got " .. route.length)
check(#route.stops == 2 and route.stops[1] == 0 and route.stops[2] == 300, "spots at 0 and 300")
check(NpcFishers.decode("") == nil and NpcFishers.decode("1,2,0") == nil, "degenerate routes are rejected")
check(NpcFishers.decode("0,0,0;10,0,0") == nil, "a route needs a fishing spot")

local x, z = NpcFishers.pointAt(route, 650)
check(math.abs(x - 50) < 1e-6 and math.abs(z) < 1e-6, "pointAt wraps around the loop")
x, z = NpcFishers.pointAt(route, 250)
check(math.abs(x - 200) < 1e-6 and math.abs(z - 50) < 1e-6, "pointAt on the second side")
-- Heading east (+X) is yaw -pi/2 in Roblox's convention.
check(math.abs(NpcFishers.headingAt(route, 100) + math.pi / 2) < 1e-6, "heading along +X")
check(math.abs(NpcFishers.headingAt(route, 250)) - math.pi < 1e-6, "heading along +Z")

-- The speed profile: rest to rest, monotonic, never above cruise.
for _, length in { 3, 20, 39.2, 78.4, 300 } do
	local total = NpcFishers.travelTime(length)
	check(math.abs(NpcFishers.travelDistance(length, total) - length) < 1e-6, `leg {length} ends at its length`)
	check(NpcFishers.travelDistance(length, 0) == 0, `leg {length} starts at 0`)
	local previous = 0
	for i = 1, 400 do
		local d = NpcFishers.travelDistance(length, total * i / 400)
		local speed = (d - previous) / (total / 400)
		check(d >= previous - 1e-9, `leg {length} never goes backwards`)
		check(speed <= NpcFishers.CRUISE_SPEED + 0.05, `leg {length} stays under cruise speed ({speed})`)
		previous = d
	end
end

-- Over two full loops the boat never jumps, and it is at rest while fishing.
local plan = NpcFishers.plan(route, 7919)
check(#plan.stops == 2, "one plan stop per spot")
local expectedPeriod = 0
for _, stop in plan.stops do
	check(stop.fish >= NpcFishers.FISH_MIN and stop.fish <= NpcFishers.FISH_MAX, "fishing time in range")
	expectedPeriod += stop.fish + stop.travel
end
check(math.abs(plan.period - expectedPeriod) < 1e-6, "period is the sum of the stops")
local dt = 0.05
local last = NpcFishers.state(plan, 0)
local lastX, lastZ = NpcFishers.pointAt(route, last.distance)
local fishingSeen, travelSeen = false, false
for i = 1, math.ceil(plan.period * 2 / dt) do
	local state = NpcFishers.state(plan, i * dt)
	local sx, sz = NpcFishers.pointAt(route, state.distance)
	local moved = math.sqrt((sx - lastX) ^ 2 + (sz - lastZ) ^ 2)
	check(moved <= NpcFishers.CRUISE_SPEED * dt + 1e-3, string.format("no jump at t=%.2f (moved %.3f)", i * dt, moved))
	if state.fishing then
		fishingSeen = true
		check(state.speed == 0, "at rest while fishing")
		check(state.fishing >= 0 and state.fishing <= state.fishDuration, "fishing time within the stop")
	else
		travelSeen = true
	end
	lastX, lastZ = sx, sz
end
check(fishingSeen and travelSeen, "the loop both fishes and travels")
check(NpcFishers.state(plan, plan.period * 3 + 1).loop == 3, "loop count")

-- Angler phases come in order and every fishing stop leaves real waiting time.
local order = { "settle", "walkOut", "turn", "windup", "cast", "wait", "bite", "reel", "stow", "walkBack", "seated" }
local rank = {}
for index, name in order do
	rank[name] = index
end
for _, duration in { NpcFishers.FISH_MIN, 60, NpcFishers.FISH_MAX } do
	local walk = 3.2
	local previousRank = 0
	local waitSeconds = 0
	for i = 0, math.floor(duration / 0.01) do
		local phase, progress = NpcFishers.activity(i * 0.01, duration, walk)
		check(rank[phase] ~= nil, "known phase " .. phase)
		check(rank[phase] >= previousRank, `phases in order at {i * 0.01} of {duration}`)
		check(progress >= 0 and progress <= 1, "phase progress within 0..1")
		previousRank = rank[phase]
		if phase == "wait" then
			waitSeconds += 0.01
		end
	end
	check(previousRank == rank.seated, "the angler is back at the helm before leaving")
	check(waitSeconds > 20, `at least 20 s with the float out (got {waitSeconds})`)
	local castStart = NpcFishers.castStart(walk)
	check(NpcFishers.activity(castStart + 0.01, duration, walk) == "cast", "castStart is the cast")
end

if failures > 0 then
	print(`{failures} NPC fisher check(s) failed`)
	error("npc fisher checks failed")
end
print("NPC fisher checks passed")
