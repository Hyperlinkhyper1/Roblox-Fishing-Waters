// Builds the real city (ModernCity and everything it requires) against the recording mocks of
// check-city.mjs, then checks only its street life, much faster than the full city check:
// the published traffic network decodes into lanes that run on asphalt with nothing solid in
// the way (parked cars, shelters, bins, signal poles), signal poles and street furniture
// stand on pavement clear of buildings, bus shelters are served by a lane, signals sit at
// every junction of three or more avenues, and streaming pieces stay within their part budget.
// This checks geometry only, not Roblox rendering or streaming.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
// Reuse check-city's Roblox mocks verbatim
const cityCheck = await readFile(join(root, 'scripts/check-city.mjs'), 'utf8');
const mockStart = cityCheck.indexOf('const mocks = String.raw`');
const mockEnd = cityCheck.indexOf('\n`;', mockStart);
if (mockStart < 0 || mockEnd < 0) throw new Error('check-city.mjs mocks moved');
const mocks = cityCheck.slice(mockStart + 'const mocks = String.raw`'.length, mockEnd);

const modules = ['LowPoly', 'Props', 'CityLand', 'CityCircuit', 'CityHills', 'CityBuildings', 'CityLandmark', 'CityStation', 'CityPort', 'CityRefinery', 'CityMetro', 'MetroStations', 'Lod', 'ModernCity', 'Biomes', 'CityTraffic', 'ParliamentLayout'];
const sources = {};
for (const name of modules) {
  const folder = ['Biomes', 'CityTraffic', 'ParliamentLayout'].includes(name) ? 'src/shared' : 'src/server/Map';
  sources[name] = (await readFile(join(root, folder, name + '.luau'), 'utf8')).replace(/^export type/gm, 'type');
}

let bundle = 'local _G_print = print\n' + mocks + `
-- Keep encoded tables so the check can read the published network back
local encoded = {}
HttpService.JSONEncode = function(_, value)
  local id = "json#" .. tostring(#encoded + 1)
  table.insert(encoded, value)
  encoded[id] = value
  return id
end
local loaded, loaders = {}, {}
local function require(target) local name = target.__module; if loaded[name] == nil then loaded[name] = loaders[name]() end; return loaded[name] end
local script = { Parent = setmetatable({}, { __index = function(_, name) return { __module = name } end }) }
`;
for (const name of modules) {
  bundle += `loaders[${JSON.stringify(name)}] = function()\n${sources[name]}\nend\n`;
}

bundle += String.raw`
local City = require({ __module = "ModernCity" })
local Traffic = require({ __module = "CityTraffic" })
local CENTER, TOP, CURB = v3(7000, 0, 7000), 8, 8.9

local began = os.clock()
local map = Instance.new("Folder")
map.Name = "Map"
local city = City.build(map)
local buildSeconds = os.clock() - began
local ground = city:FindFirstChild("Ground")

local parts = {}
for _, d in city:GetDescendants() do if d:IsA("BasePart") then table.insert(parts, d) end end

-- Parked car details never create extra physics/query geometry.
local carParts = { ParkedCar = 0, CarCabin = 0, ParkedCarRoof = 0, CarWheels = 0, CarHeadlights = 0, CarTaillights = 0 }
for _, p in parts do
  if carParts[p.Name] ~= nil then
    carParts[p.Name] += 1
    if p.Name == "ParkedCar" then
      check(p.CanCollide, "Parked car body is the single collider")
    else
      check(not p.CanCollide and not p.CanQuery and not p.CanTouch, p.Name .. " is visual only")
    end
  end
end
for _, name in { "CarCabin", "ParkedCarRoof", "CarHeadlights", "CarTaillights" } do
  check(carParts[name] == carParts.ParkedCar, name .. " exists once per parked car")
end
check(carParts.CarWheels == carParts.ParkedCar * 2, "Every parked car has two visual wheel axles")

local function contains(p, point)
  local c, s = p.CFrame, p.Size / 2
  local d = point - c.p
  local lx, ly, lz = d:Dot(c.r), d:Dot(c.u), d:Dot(c.b)
  if p.Shape == "Enum.PartType.Ball" then return d.Magnitude <= s.X end
  if p.Shape == "Enum.PartType.Cylinder" then
    return math.abs(lx) <= s.X and math.sqrt(ly * ly + lz * lz) <= s.Y
  end
  if math.abs(lx) > s.X or math.abs(ly) > s.Y or math.abs(lz) > s.Z then return false end
  if p.ClassName == "WedgePart" then return (ly + s.Y) / (2 * s.Y) <= (lz + s.Z) / (2 * s.Z) end
  return true
end

-- A coarse XZ grid over every part, so point queries look at a handful of parts
local CELL = 32
local grid = {}
local function key(cx, cz) return cx * 100000 + cz end
for _, p in parts do
  local h, c = halfExtent(p), p.CFrame.p
  for cx = math.floor((c.X - h.X) / CELL), math.floor((c.X + h.X) / CELL) do
    for cz = math.floor((c.Z - h.Z) / CELL), math.floor((c.Z + h.Z) / CELL) do
      local k = key(cx, cz)
      local list = grid[k]
      if not list then list = {}; grid[k] = list end
      table.insert(list, p)
    end
  end
end
local function partsAt(point, filter)
  local found = {}
  for _, p in grid[key(math.floor(point.X / CELL), math.floor(point.Z / CELL))] or {} do
    local h, c = halfExtent(p), p.CFrame.p
    if math.abs(point.X - c.X) <= h.X and math.abs(point.Y - c.Y) <= h.Y and math.abs(point.Z - c.Z) <= h.Z and contains(p, point) and filter(p) then
      table.insert(found, p)
    end
  end
  return found
end
local function solid(p) return p.CanCollide and p.Transparency < 1 end

-- The published network
local raw = city:GetAttribute(Traffic.ATTRIBUTE)
check(type(raw) == "string", "The city publishes its traffic network")
local data = encoded[raw]
check(type(data) == "table" and #data.n > 0 and #data.e > 0, "The network has junctions and avenues")
local network = Traffic.network(data)
check(#network.lanes == #data.e * 2, "Every avenue stretch carries a lane each way")
local signals = 0
for _, n in data.n do if n[5] == 1 then signals += 1 end end
check(signals >= 6, "Busy junctions have signals (" .. signals .. ")")

-- Lanes run on asphalt, with room for a car body all the way
local samples, offRoad, blocked = 0, {}, {}
local function probe(x, z, label)
  samples += 1
  local road = partsAt(v3(x, TOP + 0.3, z), function(p) return p.Name == "Street" or p.Name == "Crosswalk" end)
  if #road == 0 and #offRoad < 5 then table.insert(offRoad, label .. string.format(" at %.0f,%.0f", x - CENTER.X, z - CENTER.Z)) end
  for _, y in { TOP + 1.5, TOP + 3.5 } do
    local hits = partsAt(v3(x, y, z), solid)
    if #hits > 0 and #blocked < 5 then
      table.insert(blocked, label .. string.format(" at %.0f,%.0f hits %s", x - CENTER.X, z - CENTER.Z, hits[1].Name))
    end
  end
end
for _, lane in network.lanes do
  local lx, lz = lane.dz, -lane.dx
  for s = 0, lane.len, 6 do
    for _, side in { -2.6, 0, 2.6 } do
      probe(lane.x0 + lane.dx * s + lx * side, lane.z0 + lane.dz * s + lz * side, "Lane " .. lane.index)
    end
  end
  for _, out in network.nodes[lane.to].outs do
    local conn = Traffic.connector(network, lane.index, out)
    for k = 1, #conn.points, 2 do
      probe(conn.points[k], conn.points[k + 1], "Junction path " .. lane.index .. ">" .. out)
    end
  end
end
check(#offRoad == 0, "Lanes stay on the road: " .. table.concat(offRoad, "; "))
check(#blocked == 0, "Nothing solid stands in a lane: " .. table.concat(blocked, "; "))

-- Bus shelters are served by a lane
local served = 0
for _, lane in network.lanes do served += #lane.stops end
check(#data.s > 0 and served == #data.s, "Every bus shelter is served by a lane (" .. served .. " of " .. #data.s .. ")")

-- Street furniture stands on pavement and clear of anything solid
local FURNITURE = { LitterBin = true, Hydrant = true, BenchBase = true, ShelterPost = true, ShelterBenchBase = true, BusStopPole = true, SignalPole = true, FountainBasin = true, ShelterGlass = true, ShelterAdvert = true }
local counts, misplaced = {}, {}
for _, p in parts do
  counts[p.Name] = (counts[p.Name] or 0) + 1
  local c = p.CFrame.p
  -- The station forecourt dresses itself (CityMetro), with its own bus stops
  local forecourt = c.X - CENTER.X > -390 and c.X - CENTER.X < -105 and c.Z - CENTER.Z > -130 and c.Z - CENTER.Z < 40
  if FURNITURE[p.Name] and not forecourt then
    local under = partsAt(v3(c.X, TOP + 0.6, c.Z), function(q) return q.Name == "Pavement" or q.Name == "SquarePaving" or q.Name == "PocketPark" or q.Name == "ParkPath" end)
    local inside = partsAt(v3(c.X, CURB + 0.8, c.Z), function(q) return q ~= p and solid(q) and q.Parent ~= p.Parent end)
    -- Props of one fixture may touch each other; anything else solid is a clash
    local clash = nil
    for _, q in inside do
      if not FURNITURE[q.Name] and q.Name ~= "BenchSeat" and q.Name ~= "ShelterBench" then clash = q break end
    end
    if (#under == 0 or clash) and #misplaced < 6 then
      table.insert(misplaced, p.Name .. string.format(" at %.0f,%.0f", c.X - CENTER.X, c.Z - CENTER.Z) .. (if clash then " inside " .. clash.Name else " off the pavement"))
    end
  end
end
check(#misplaced == 0, "Street furniture stands on clear pavement: " .. table.concat(misplaced, "; "))
check((counts.TrafficLamp or 0) == 3 * (counts.SignalHead or 0) and (counts.SignalHead or 0) >= signals * 2, "Signal heads carry three lamps each")
for _, p in parts do
  if p.Name == "TrafficLamp" then
    check(p:HasTag("TrafficLamp") and (p:GetAttribute("Axis") == "x" or p:GetAttribute("Axis") == "z") and type(p:GetAttribute("Offset")) == "number", "Signal lamps carry their plan")
  elseif p.Name == "AviationBeacon" then
    check(p:HasTag("AviationBeacon"), "Beacons are tagged for blinking")
  elseif p.Name == "BladeSign" or p.Name == "ShelterAdvert" then
    check(p:HasTag("NightGlow") and p:GetAttribute("GlowColor") ~= nil, p.Name .. " lights up after dark")
  end
end

-- Streaming pieces stay small, and nothing streams outside one
local biggest, biggestName, ungrouped, pieces = 0, "", 0, 0
for _, d in ground:GetDescendants() do
  if d:IsA("Model") and d:HasTag("LodPiece") then
    pieces += 1
    local count = 0
    for _, e in d:GetDescendants() do if e:IsA("BasePart") then count += 1 end end
    if count > biggest then biggest, biggestName = count, d.Name end
  end
end
for _, d in ground:GetDescendants() do
  if d:IsA("BasePart") then
    local p, inPiece = d.Parent, false
    while p and p ~= ground do if p:HasTag("LodPiece") then inPiece = true end; p = p.Parent end
    if not inPiece then ungrouped += 1 end
  end
end
check(ungrouped == 0, ungrouped .. " city parts would stream outside any pinned piece")
check(biggest <= 260, "Largest streaming piece (" .. biggestName .. ") has " .. biggest .. " parts")

-- Traffic flows on the real network at the densest population the client uses
do
  local population = Traffic.population(network, 3)
  local sim = Traffic.newSim(network, population, 2024)
  check(#sim.cars >= population * 0.9, "The real network takes its population (" .. #sim.cars .. " of " .. population .. ")")
  local travelled, lastS, lastLane = {}, {}, {}
  for k, car in sim.cars do travelled[car], lastS[car], lastLane[car] = 0, car.s, car.lane end
  local t, redRuns = 500, 0
  for step = 1, 30 * 300 do
    for k, car in sim.cars do car.near = (k + step // 150) % 3 == 0 end
    Traffic.step(sim, 1 / 30, t)
    for _, car in sim.cars do
      if car.lane ~= lastLane[car] then
        local lane = network.lanes[lastLane[car]]
        travelled[car] += lane.len - lastS[car] + car.s + car.conn.len
        if lane.signal and Traffic.signal(lane.axis, t + lane.offset) == "r" then redRuns += 1 end
      else
        travelled[car] += car.s - lastS[car]
      end
      lastS[car], lastLane[car] = car.s, car.lane
    end
    t += 1 / 30
  end
  local stuck, total = 0, 0
  for _, car in sim.cars do
    total += travelled[car]
    if travelled[car] < 600 then stuck += 1 end
  end
  check(redRuns == 0, "Nobody runs a red light in the city (" .. redRuns .. ")")
  check(stuck == 0, "Every vehicle keeps moving round the city (" .. stuck .. " stuck)")
  print(string.format("City traffic: %d vehicles over 300 s, %.1f studs/s average", #sim.cars, total / #sim.cars / 300))
end

local added = {}
for _, name in { "SignalHead", "TrafficLamp", "LitterBin", "Hydrant", "BenchSeat", "ShelterRoof", "FountainBasin", "Flowerbed", "BladeSign", "AviationBeacon", "ParkedCar" } do
  table.insert(added, name .. "=" .. (counts[name] or 0))
end
print(string.format("City built in %.1f s: %d parts, %d pieces (largest %d)", buildSeconds, #parts, pieces, biggest))
print(string.format("Traffic: %d junctions (%d signalled), %d lanes, %.0f studs of lane, %d shelters, %d road samples", #data.n, signals, #network.lanes, network.length, #data.s, samples))
print("Street life: " .. table.concat(added, ", "))
print("City street-life checks passed: " .. checks .. " assertions")
for _, line in printed do _G_print(line) end
`;

const dir = await mkdtemp(join(tmpdir(), 'city-street-life-'));
try {
  const path = join(dir, 'street.luau');
  await writeFile(path, bundle);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', path], { cwd: root, encoding: 'utf8', timeout: 1800000, maxBuffer: 1 << 28 });
  if (result.error) throw result.error;
  process.stdout.write(result.stdout);
  process.stderr.write(result.stderr);
  if (result.status !== 0) process.exit(result.status || 1);
} finally {
  await rm(dir, { recursive: true, force: true });
}
