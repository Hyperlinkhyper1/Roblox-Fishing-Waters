// Runs the real city traffic rules (src/shared/CityTraffic.luau) on a city-like avenue grid
// with a missing stretch, a dead end and bus shelters, under lute. Checks the signal plan,
// lane geometry, that queued vehicles never overlap or overtake, nobody enters a junction
// on red, buses call at shelters, a player in the road is never driven through, traffic
// keeps flowing at 144, 60 and 20 FPS (all near and all far), and prints the step cost.
// This checks the simulation only, not Roblox rendering.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
// Type exports are only allowed at a module's top level, so drop the keyword when inlining
const traffic = (await readFile(join(root, 'src/shared/CityTraffic.luau'), 'utf8')).replace(/^export type/gm, 'type');

const harness = String.raw`
local Traffic = (function()
${traffic}
end)()
local checks = 0
local function check(ok, message)
	checks += 1
	if not ok then error(message, 2) end
end

-- Signals: one axis at a time, each gets green every cycle, all-red between
local seen = { x = {}, z = {} }
for t = 0, Traffic.CYCLE * 2, 0.05 do
	local x, z = Traffic.signal("x", t), Traffic.signal("z", t)
	check(x == "r" or z == "r", "Only one axis may move at " .. t)
	seen.x[x], seen.z[z] = true, true
end
check(seen.x.g and seen.x.a and seen.z.g and seen.z.a, "Both axes see green and amber")

-- A city-like grid: avenues at these x and z (relative), widths as in ModernCity
local columns = { { -105, 20 }, { 150, 26 }, { 410, 26 }, { 775, 22 }, { 1050, 20 } }
local rows = { { -690, 20 }, { -415, 26 }, { -130, 26 }, { 130, 26 }, { 400, 22 }, { 670, 20 } }
local data = { o = { 7000, 8.5, 7000 }, n = {}, e = {}, s = {} }
local index = {}
local function node(i, j)
	local key = i .. "," .. j
	if not index[key] then
		table.insert(data.n, { columns[i][1], rows[j][1], columns[i][2], rows[j][2], 0, Traffic.junctionOffset(i, j) })
		index[key] = #data.n
	end
	return index[key]
end
local degree = {}
local function link(a, b)
	table.insert(data.e, { a, b })
	degree[a] = (degree[a] or 0) + 1
	degree[b] = (degree[b] or 0) + 1
end
for i = 1, #columns do
	for j = 1, #rows - 1 do
		-- The far east avenue stops short of the last row: a dead end
		if not (i == 5 and j >= 4) then
			link(node(i, j), node(i, j + 1))
		end
	end
end
for j = 1, #rows do
	for i = 1, #columns - 1 do
		-- One stretch of the second row is missing (a plaza)
		if not (j == 2 and i == 2) then
			link(node(i, j), node(i + 1, j))
		end
	end
end
for k, n in data.n do
	if degree[k] >= 3 then n[5] = 1 end
end
-- Shelters on the south kerb of two east-west avenues (westbound lanes)
table.insert(data.s, { 280, -130 + 13 })
table.insert(data.s, { 600, 130 + 13 })
table.insert(data.s, { 280, 400 + 11 })

local network = Traffic.network(data)
check(#network.lanes == #data.e * 2, "Every edge carries a lane each way")
local stops = 0
for _, lane in network.lanes do
	check(lane.len > 30, "Lane " .. lane.index .. " is long enough (" .. lane.len .. ")")
	-- Keep left: the lane centre lies to the left of the avenue's centreline
	local a, b = network.nodes[lane.from], network.nodes[lane.to]
	local side = (lane.x0 - a.x) * lane.dz - (lane.z0 - a.z) * lane.dx
	local width = if lane.axis == "x" then a.wEW else a.wNS
	check(math.abs(side - width / 4) < 1e-6, "Lane " .. lane.index .. " keeps left")
	stops += #lane.stops
	for _, s in lane.stops do
		check(s > 30 and s < lane.len, "Bus stop lies along its lane")
	end
end
check(stops == 3, "Every shelter is served by one lane (" .. stops .. ")")
-- Connectors start and end on their lanes
for _, lane in network.lanes do
	for _, out in network.nodes[lane.to].outs do
		local c = Traffic.connector(network, lane.index, out)
		local o = network.lanes[out]
		check(math.abs(c.points[1] - lane.x1) < 1e-6 and math.abs(c.points[2] - lane.z1) < 1e-6, "Connector starts at the lane end")
		check(math.abs(c.points[#c.points - 1] - o.x0) < 1e-6 and math.abs(c.points[#c.points] - o.z0) < 1e-6, "Connector ends at the next lane")
		check(c.len > 0 and c.len < 80, "Connector length is sensible (" .. c.len .. ")")
	end
end

-- Step cost on its own (no checks allocating in between), every car near and every car far
for _, mode in { "near", "far" } do
	local sim = Traffic.newSim(network, 160, 7)
	for _, car in sim.cars do car.near = mode == "near" end
	for k = 1, 600 do Traffic.step(sim, 1 / 60, 100 + k / 60) end
	local began = os.clock()
	for k = 1, 3000 do Traffic.step(sim, 1 / 60, 200 + k / 60) end
	local ms = (os.clock() - began) / 3000 * 1000
	print(string.format("Step cost, 160 vehicles all %s: %.3f ms", mode, ms))
	check(ms < 1, "One simulation step stays well under a millisecond")
end

local function run(label, fps, seconds, nearMode, population)
	local sim = Traffic.newSim(network, population, 4242)
	check(#sim.cars >= population * 0.9, label .. ": most of the population was placed (" .. #sim.cars .. ")")
	local travelled, lastS, lastLane = {}, {}, {}
	for _, car in sim.cars do
		travelled[car] = 0
		lastS[car], lastLane[car] = car.s, car.lane
	end
	local dt = 1 / fps
	local t = 1000
	local busCalls, redRuns = 0, 0
	local dwelling = {}
	for step = 1, math.floor(seconds * fps) do
		for k, car in sim.cars do
			if nearMode == "near" then car.near = true
			elseif nearMode == "far" then car.near = false
			else car.near = (k + math.floor(step / (fps * 5))) % 2 == 0 end
		end
		Traffic.step(sim, dt, t)
		t += dt
		for laneIndex, queue in sim.queues do
			local lane = network.lanes[laneIndex]
			for k, car in queue do
				check(car.lane == laneIndex, label .. ": car is queued in its own lane")
				check(car.s <= lane.len + 1e-6, label .. ": car never sits past its lane end")
				local ahead = queue[k - 1]
				if ahead then
					check(ahead.s >= car.s - 1e-6, label .. ": queue order matches positions")
					-- Bumper to bumper on the straight part of the lane
					if car.s >= 0 and ahead.s - ahead.length >= 0 then
						check(ahead.s - ahead.length - car.s > -0.05, label .. ": vehicles never overlap (" .. (ahead.s - ahead.length - car.s) .. ")")
					end
				end
			end
		end
		for _, car in sim.cars do
			if car.lane ~= lastLane[car] then
				local lane = network.lanes[lastLane[car]]
				travelled[car] += lane.len - lastS[car] + car.s + car.conn.len
				if lane.signal then
					-- It crossed the stop line during this step
					local state = Traffic.signal(lane.axis, t - dt + lane.offset)
					if state == "r" then redRuns += 1 end
				end
			else
				check(car.s >= lastS[car] - 1e-6, label .. ": vehicles never reverse")
				travelled[car] += car.s - lastS[car]
			end
			lastS[car], lastLane[car] = car.s, car.lane
			if car.kind.stops then
				if car.dwell > 0 and not dwelling[car] then busCalls += 1 end
				dwelling[car] = car.dwell > 0
			end
		end
	end
	check(redRuns == 0, label .. ": nobody enters a junction on red (" .. redRuns .. ")")
	local stuck, slowest, total = 0, math.huge, 0
	for _, car in sim.cars do
		local d = travelled[car]
		total += d
		slowest = math.min(slowest, d)
		if d < seconds * 2 then stuck += 1 end
	end
	check(stuck == 0, label .. ": every vehicle keeps moving (" .. stuck .. " stuck, slowest " .. math.floor(slowest) .. " studs)")
	check(total / #sim.cars > seconds * 8, label .. ": traffic flows at a city pace (" .. math.floor(total / #sim.cars / seconds) .. " studs/s)")
	print(string.format("%s: %d vehicles, %d s at %d FPS, %.1f studs/s average, %d bus calls", label, #sim.cars, seconds, fps, total / #sim.cars / seconds, busCalls))
	return busCalls
end

local calls = run("near 144 FPS", 144, 120, "near", 160)
calls += run("mixed 60 FPS", 60, 240, "mixed", 160)
calls += run("far 20 FPS", 20, 300, "far", 160)
run("sparse 60 FPS", 60, 120, "mixed", 40)
check(calls > 0, "Buses call at shelters")

-- A player standing in a lane is never driven through
do
	local sim = Traffic.newSim(network, 160, 99)
	local lane = network.lanes[1]
	local along = lane.len * 0.6
	local px, pz = lane.x0 + lane.dx * along, lane.z0 + lane.dz * along
	sim.obstacles = { px, pz }
	local behind = {}
	for _, car in sim.cars do
		car.near = true
	end
	for step = 1, 60 * 90 do
		Traffic.step(sim, 1 / 60, 5000 + step / 60)
		for _, car in sim.queues[lane.index] do
			if car.s < along - 4 and not behind[car] then behind[car] = true end
			if behind[car] then
				check(car.s <= along - 2, "A car stops short of the player in the road (" .. car.s - along .. ")")
			end
		end
	end
	local waiting = 0
	for car in behind do
		if car.lane == lane.index then waiting += 1 end
	end
	check(waiting > 0, "Cars queue behind the player")
	-- Once the player steps away the queue moves off again
	local front = sim.queues[lane.index][1]
	local frontS = front and front.s
	sim.obstacles = {}
	for step = 1, 60 * 30 do
		Traffic.step(sim, 1 / 60, 6000 + step / 60)
	end
	local moved = front == nil or front.lane ~= lane.index or front.s > frontS + 20
	check(moved, "Traffic moves off once the road is clear")
end

print("City traffic checks passed: " .. checks .. " assertions")
`;

const dir = await mkdtemp(join(tmpdir(), 'city-traffic-'));
try {
  const path = join(dir, 'traffic.luau');
  await writeFile(path, harness);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', path], { cwd: root, encoding: 'utf8', timeout: 600000, maxBuffer: 1 << 26 });
  if (result.error) throw result.error;
  process.stdout.write(result.stdout);
  process.stderr.write(result.stderr);
  if (result.status !== 0) process.exit(result.status || 1);
  // The modules that build and draw the street life must at least parse
  const modules = ['src/client/CityTraffic.luau', 'src/client/CityNightLights.luau', 'src/server/Map/ModernCity.luau', 'src/server/Map/CityBuildings.luau', 'src/client/init.client.luau'];
  for (const [index, module] of modules.entries()) {
    const compile = join(dir, `compile-${index}.luau`);
    await writeFile(compile, 'do return end\n' + await readFile(join(root, module), 'utf8'));
    const parsed = spawnSync(process.env.LUTE || 'lute', ['run', compile], { cwd: root, encoding: 'utf8', timeout: 60000 });
    if (parsed.status !== 0) {
      process.stderr.write(parsed.stdout + parsed.stderr);
      throw new Error(`${module} does not parse`);
    }
  }
  console.log(`City street-life modules: ${modules.length} files parse`);
} finally {
  await rm(dir, { recursive: true, force: true });
}
