// Run the full street service on deterministic streets, including rotated blocks.
// This tests server decisions/lifecycle, not Roblox rendering or live navmeshes.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = path => readFile(join(root, path), 'utf8');
const sources = await Promise.all([
  read('src/server/StreetPedestrians.luau'), read('src/shared/Pedestrians.luau'),
  read('src/server/PedestrianGrid.luau'), read('scripts/street-pedestrians.luau'),
  read('src/server/CustomerService.luau'), read('src/client/Pedestrians.luau'),
  read('src/server/PedestrianNetwork.luau'),
  read('scripts/pedestrian-shopping-fixture.luau'),
  read('scripts/pedestrian-harbour-fixture.luau'), read('src/server/Map/Harbour.luau'),
  read('scripts/harbour-geometry.luau'),
]);
function section(source, start, end) {
  const a = source.indexOf(start), b = source.indexOf(end, a);
  if (a < 0 || b < 0) throw new Error(`Missing section: ${start}`);
  return source.slice(a, b);
}
const service = sources[0]
  .replace('require(ReplicatedStorage.Shared.Pedestrians)', 'dependencies.Pedestrians')
  .replace('require(ReplicatedStorage.Shared.DayNight)', 'dependencies.DayNight')
  .replace('require(ReplicatedStorage.Shared.Weather)', 'dependencies.Weather')
  .replace('require(script.Parent.PedestrianGrid)', 'dependencies.Grid');
const network = sources[6].replace('require(script.Parent.PedestrianGrid)', 'dependencies.Grid');
const realRoads = section(sources[9], 'local road = buildRoad(shape, village, "Road"', '-- Dirt tracks from each base');
const layoutHook = `function Harbour.pedestrianLayout(village)
  local shape = makeShape(Vector2.new(0, 0))
  local plaza, lighthouse = shape.toWorld(PLAZA), shape.toWorld(LIGHTHOUSE)
  local spots = {}
  local keepOut = { { position = plaza, radius = PLAZA_HALF + 2 }, { position = lighthouse, radius = 26 } }
  ${realRoads}
  local square = Instance.new("Model"); square.Name, square.Parent = "Plaza", village
  Props.part(square, Vector3.new(116, 0.6, 116), CFrame.new(plaza.X, 5.5, plaza.Y), nil, M.Limestone)
  local frames = {}
  for _, anchor in BASES do
    local shore, toWater = shoreAt(shape, shape.toWorld(anchor))
    local origin = Vector3.new(shore.X, 0, shore.Y)
    table.insert(frames, CFrame.lookAt(origin, origin + Vector3.new(toWater.X, 0, toWater.Y)) * CFrame.new(0, 5.9, 43))
  end
  return frames
end
return Harbour`;
const harbourSource = sources[9].replace(/^local (\w+) = require\(.*$/gm, 'local $1 = dependencies.$1')
  .replace(/return Harbour\s*$/, layoutHook);
const harbour = sources[8]
  .replace('-- VECTOR_TYPES --', () => sources[10].slice(sources[10].indexOf('local function vectorType('), sources[10].indexOf('local Vector2 = vectorType(2)')))
  .replace('-- HARBOUR_SOURCE --', () => harbourSource);
const shopping = sources[7]
  .replace('-- REAL_RETURN --', () => section(sources[4], 'local function returnPedestrian(', '-- Returns the fish'))
  .replace('-- REAL_DOORS --', () => section(sources[4], '-- House-local doorway approach points.', 'local function face('))
  .replace('-- REAL_FINISH --', () => section(sources[4], 'local function leave(', 'local function waitingForRegister('))
  .replace('-- REAL_VISIT --', () => section(sources[4], 'local function waitingForRegister(', 'local function sell('))
  .replace('-- REAL_SELL --', () => section(sources[4], 'local function sell(', 'local function removeStaff('))
  .replace('-- REAL_ARRIVE --', () => section(sources[4], 'local function arrive(', 'local function registerShop('));
const program = sources[3]
  .replace('-- PEDESTRIANS --', () => sources[1])
  .replace('-- GRID --', () => sources[2])
  .replace('-- SHOP_INTEGRATION --', () => shopping)
  .replace('-- HARBOUR_LAYOUT --', () => harbour)
  .replace('-- NETWORK --', () => network)
  .replace('-- STREETS --', () => service.replace('require(script.Parent.PedestrianNetwork)', 'dependencies.Network'))
  .replace('-- AVATAR_CACHE --', () => section(sources[4], 'local function pedestrianModel(', 'local function spawnCustomer('))
  .replace('-- CLIENT_SHOW --', () => section(sources[5], 'local function show(', 'local function setAlpha('))
  .replace('-- CLIENT_HIDE --', () => section(sources[5], 'local function hideAll(', 'local function shortestAngle('))
  .replace('-- CLIENT_TRACK --', () => section(sources[5], 'local function destroy(person:', 'function PedestriansClient.start('));
const temporary = await mkdtemp(join(tmpdir(), 'street-pedestrians-'));
try {
  const target = join(temporary, 'check.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], {
    cwd: root, encoding: 'utf8', timeout: 180000,
  });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Street checks failed (${result.status})`);
} finally {
  if (dirname(temporary) !== resolve(tmpdir())) throw new Error('Unexpected temporary directory');
  await rm(temporary, { recursive: true, force: true });
}
