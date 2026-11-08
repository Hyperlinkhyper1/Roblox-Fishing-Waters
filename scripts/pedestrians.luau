-- Townsfolk rules: trip encoding and sampling, detail tiers, street activity, and
-- the walkable grid's flood fill, A* and smoothing. No Roblox runtime; the
-- service and client are only syntax-checked here (they need Studio).
-- Run: lute run scripts/pedestrians.luau
local fs = require("@lute/fs")
local luau = require("@lute/luau")

local checks = 0
local function check(condition: boolean, message: string)
	assert(condition, message)
	checks += 1
end
local function read(path: string): string
	local file = fs.open(path, "r")
	local source = fs.read(file)
	fs.close(file)
	return source
end
local function load(path: string)
	local ok, chunk = pcall(luau.load, luau.compile(read(path)), path, setmetatable({}, { __index = _G }))
	check(ok, `{path} compiles: {chunk}`)
	return chunk
end

for _, path in { "src/server/PedestrianService.luau", "src/server/StreetPedestrians.luau", "src/server/PedestrianNetwork.luau", "src/server/CustomerService.luau", "src/server/RestaurantService.luau", "src/client/Pedestrians.luau" } do
	load(path)
end
local Pedestrians = load("src/shared/Pedestrians.luau")()
local Grid = load("src/server/PedestrianGrid.luau")()

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-3)
end

-- Encoding round trip
local text = Pedestrians.encode({
	start = 1762534567.25,
	speed = 4.5,
	emerge = true,
	leave = false,
	stop = "e",
	stopSeconds = 20,
	yaw = 1.25,
	bag = 2,
	points = { 0, 5, 0, 10, 5, 0, 10, 6, 10 },
})
local trip = Pedestrians.decode(text)
check(trip ~= nil, "Trip decodes")
check(near(trip.start, 1762534567.25), "Start survives encoding")
check(trip.emerge and not trip.leave, "Flags survive encoding")
check(trip.stop == "e" and near(trip.stopSeconds, 20) and near(trip.yaw, 1.25) and trip.bag == 2, "Stop survives encoding")
check(#trip.points == 9 and near(trip.total, 10 + math.sqrt(101)), "Points and length survive encoding")
check(Pedestrians.decode("") == nil and Pedestrians.decode("junk") == nil, "Bad trips decode to nil")
local noYaw = Pedestrians.decode(Pedestrians.encode({ start = 1, speed = 2, points = { 0, 0, 0 } }))
check(noYaw and noYaw.yaw == nil and noYaw.stop == "n" and noYaw.total == 0, "Single-point trip without a yaw")

-- Sampling
local s = Pedestrians.sample(trip, trip.start - 1)
check(s.alpha == 1 and s.x == 0 and s.z == 0, "Before an emerging trip starts it is still inside")
s = Pedestrians.sample(trip, trip.start + Pedestrians.FADE_SECONDS / 2)
check(near(s.alpha, 0.5) and s.moving, "Fades in while walking out")
s = Pedestrians.sample(trip, trip.start + 1)
check(near(s.x, 4.5) and near(s.z, 0) and s.alpha == 0, "Walks along the first segment at its speed")
-- Facing +X: look vector (-sin yaw, -cos yaw) = (1, 0)
check(near(-math.sin(s.yaw), 1) and near(-math.cos(s.yaw), 0, 1e-6), "Faces along the path")
check(near(s.stride, 4.5), "Stride is distance walked")
local walkTime = trip.total / trip.speed
s = Pedestrians.sample(trip, trip.start + walkTime + Pedestrians.FADE_SECONDS / 2)
check(near(s.alpha, 0.5) and s.moving, "Fades out stepping through the doorway")
check(near(s.x, 10 - math.sin(1.25) * Pedestrians.DOOR_DEPTH / 2), "Steps in along the stop yaw")
s = Pedestrians.sample(trip, trip.start + walkTime + 5)
check(s.alpha == 1 and not s.moving, "Gone inside the shop")
check(near(Pedestrians.duration(trip), walkTime + 20), "Duration covers walk and dwell")

local pause = Pedestrians.decode(Pedestrians.encode({ start = 0, speed = 5, stop = "b", stopSeconds = 8, yaw = 0.5, points = { 0, 0, 0, 5, 0, 0 } }))
s = Pedestrians.sample(pause, 3)
check(s.alpha == 0 and not s.moving and near(s.yaw, 0.5) and s.x == 5, "Browses facing the counter")
local vanish = Pedestrians.decode(Pedestrians.encode({ start = 0, speed = 5, stop = "x", points = { 0, 0, 0, 5, 0, 0 } }))
check(near(Pedestrians.duration(vanish), 1 + Pedestrians.FADE_SECONDS), "Vanishing includes its fade")
check(Pedestrians.sample(vanish, 1 + Pedestrians.FADE_SECONDS).alpha == 1, "Vanished at the edge")

-- Tiers with hysteresis
local hidden = Pedestrians.HIDDEN
check(Pedestrians.tierFor(10, hidden) == 1, "Close is near")
check(Pedestrians.tierFor(74, 1) == 1 and Pedestrians.tierFor(74, 2) == 2, "Near boundary keeps the current tier")
check(Pedestrians.tierFor(155, 2) == 2 and Pedestrians.tierFor(155, 3) == 3, "Mid boundary keeps the current tier")
check(Pedestrians.tierFor(290, 3) == 3 and Pedestrians.tierFor(290, hidden) == hidden, "Far boundary keeps the current tier")
check(Pedestrians.tierFor(1000, 1) == hidden, "Very far is not drawn")
for i = 2, #Pedestrians.TIERS do
	check(Pedestrians.TIERS[i].interval >= Pedestrians.TIERS[i - 1].interval, "Further tiers update less often")
end

-- Activity
check(Pedestrians.activity(13) == 1 and Pedestrians.activity(2) < 0.2, "Busy by day, quiet at night")
check(Pedestrians.weatherFactor(1) < Pedestrians.weatherFactor(0), "Rain thins the crowd")
check(Pedestrians.islandPopulation(12, 0, 1) == 68 and Pedestrians.islandPopulation(2, 0, 1) == 11, "An island-wide crowd is busy by day and quiet at night")
check(Pedestrians.islandPopulation(20, 0, 1) < Pedestrians.islandPopulation(12, 0, 1), "Traffic falls during dusk")
check(Pedestrians.islandPopulation(12, 1, 1) < Pedestrians.islandPopulation(12, 0, 1), "Rain thins the crowd")

-- Avatars: every look seed lands on a published slot, and seeds spread over all of them
local slotsSeen, slotsOk = {}, true
for seed = 1, 400 do
	local slot = Pedestrians.avatarSlot(seed * 7919)
	slotsOk = slotsOk and slot >= 1 and slot <= Pedestrians.AVATAR_COUNT and slot % 1 == 0
	slotsSeen[slot] = true
end
local spread = 0
for _ in slotsSeen do
	spread += 1
end
check(slotsOk, "Avatar slots stay within the published descriptions")
check(spread == Pedestrians.AVATAR_COUNT, "Look seeds use every avatar slot")

-- Grid: a 20x20 square with a wall at column 10 broken by a gap at row 15,
-- a raised roof island and a grass strip.
local g = Grid.new(20, 20, 2, 0, 0, 1.1)
for r = 0, 19 do
	for c = 0, 19 do
		local i = Grid.index(g, c, r)
		g.walk[i] = c ~= 10 or r == 15
		g.height[i] = 0
	end
end
for r = 2, 4 do
	for c = 2, 4 do
		g.height[Grid.index(g, c, r)] = 8
	end
end
local open = Grid.keepConnected(g, Grid.index(g, 0, 19))
check(not g.walk[Grid.index(g, 3, 3)], "Raised roof drops out of the walkable set")
check(open == 400 - 19 - 9, "Everything else stays connected")
local from, to = Grid.index(g, 2, 10), Grid.index(g, 17, 10)
local path = Grid.findPath(g, from, to)
check(path ~= nil and path[1] == from and path[#path] == to, "Finds a route through the gap")
local throughGap = false
for _, i in path do
	local c, r = Grid.coords(g, i)
	check(c ~= 10 or r == 15, "Route never crosses the wall")
	throughGap = throughGap or (c == 10 and r == 15)
end
check(throughGap, "Route uses the gap")
local smooth = Grid.smooth(g, path)
check(#smooth < #path and smooth[1] == from and smooth[#smooth] == to, "Smoothing drops staircase corners")
for i = 2, #smooth do
	check(Grid.lineClear(g, smooth[i - 1], smooth[i], 1), "Every smoothed leg is clear")
end
local noisy = Grid.findPath(g, from, to, 1234, 0.35)
check(noisy and noisy[#noisy] == to, "Noisy costs still arrive")
check(Grid.nearest(g, 21, 21, 3) == Grid.index(g, 9, 10) or Grid.nearest(g, 21, 21, 3) == Grid.index(g, 11, 10), "Nearest skips the wall")
check(Grid.findPath(g, from, Grid.index(g, 3, 3)) == nil, "No route to the roof")
local pts = Grid.points(g, { from })
check(#pts == 3 and pts[1] == 5 and pts[3] == 21, "Cell centres in world space")

-- Paving is preferred over grass when the detour is short
local h = Grid.new(12, 5, 2, 0, 0, 1.1)
for r = 0, 4 do
	for c = 0, 11 do
		local i = Grid.index(h, c, r)
		h.walk[i] = true
		h.cost[i] = if r == 2 then 2.2 else 1
	end
end
local grassy = Grid.findPath(h, Grid.index(h, 0, 2), Grid.index(h, 11, 2))
local onGrass = 0
for _, i in grassy do
	local _, r = Grid.coords(h, i)
	if r == 2 then
		onGrass += 1
	end
end
check(onGrass < #grassy / 2, "Routes keep to paving beside a grass strip")

print(`pedestrians: {checks} checks passed`)
