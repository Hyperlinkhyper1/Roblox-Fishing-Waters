// Builds the real city against check-city's recording mocks and runs only check-city's Grand
// Prix circuit block (sliced out verbatim, so the two never drift apart). Much faster than the
// full city check, which scans every solid in the city for its other assertions.
// This checks geometry only, not Roblox rendering or streaming.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const cityCheck = (await readFile(join(root, 'scripts/check-city.mjs'), 'utf8')).replace(/\r\n/g, '\n');
function slice(startMarker, endMarker) {
  const start = cityCheck.indexOf(startMarker);
  const end = cityCheck.indexOf(endMarker, start + startMarker.length);
  if (start < 0 || end < 0) throw new Error('check-city.mjs moved: ' + startMarker);
  return [start, end];
}
const [mockStart, mockEnd] = slice('const mocks = String.raw`', '\n`;');
const mocks = cityCheck.slice(mockStart + 'const mocks = String.raw`'.length, mockEnd);
const [circuitStart, circuitEnd] = slice('-- The Grand Prix circuit cut into the foot of the south range', '\n-- The metro:');
const circuitChecks = cityCheck.slice(circuitStart, circuitEnd);

const modules = ['LowPoly', 'Props', 'CityLand', 'CityCircuit', 'CityHills', 'CityBuildings', 'CityLandmark', 'CityStation', 'CityPort', 'CityRefinery', 'CityMetro', 'MetroStations', 'Lod', 'ModernCity', 'Biomes', 'ParliamentLayout'];
const sources = {};
for (const name of modules) {
  const folder = ['Biomes', 'ParliamentLayout'].includes(name) ? 'src/shared' : 'src/server/Map';
  sources[name] = (await readFile(join(root, folder, name + '.luau'), 'utf8')).replace(/^export type/gm, 'type');
}

let bundle = 'local _G_print = print\n' + mocks + `
local loaded, loaders = {}, {}
local function require(target) local name = target.__module; if loaded[name] == nil then loaded[name] = loaders[name]() end; return loaded[name] end
local script = { Parent = setmetatable({}, { __index = function(_, name) return { __module = name } end }) }
`;
for (const name of modules) {
  bundle += `loaders[${JSON.stringify(name)}] = function()\n${sources[name]}\nend\n`;
}

bundle += String.raw`
local City = require({ __module = "ModernCity" })
local CENTER, TOP = v3(7000, 0, 7000), 8
local began = os.clock()
local map = Instance.new("Folder")
map.Name = "Map"
local city = City.build(map)
local buildSeconds = os.clock() - began
local ground = city:FindFirstChild("Ground")

local function contains(p, point)
  local c, s = p.CFrame, p.Size / 2
  local d = point - c.p
  local lx, ly, lz = d:Dot(c.r), d:Dot(c.u), d:Dot(c.b)
  if p.Shape == "Enum.PartType.Ball" then return d.Magnitude <= s.X end
  if math.abs(lx) > s.X or math.abs(ly) > s.Y or math.abs(lz) > s.Z then return false end
  if p.ClassName == "WedgePart" then return (ly + s.Y) / (2 * s.Y) <= (lz + s.Z) / (2 * s.Z) end
  return true
end

local CityHills = require({ __module = "CityHills" })
local CityCircuit = require({ __module = "CityCircuit" })
local EDGE = CityHills.EDGE
local dressing = {}
for _, model in ground:GetChildren() do
  if model.Name == "HillSlope" then
    for _, p in model:GetDescendants() do
      if p:IsA("BasePart") and not p:GetAttribute("LodKeep") then table.insert(dressing, p) end
    end
  end
end

` + circuitChecks + String.raw`

print(string.format("City built in %.1f s", buildSeconds))
print("Circuit checks passed: " .. checks .. " assertions")
for _, line in printed do _G_print(line) end
`;

const dir = await mkdtemp(join(tmpdir(), 'city-circuit-'));
try {
  const path = join(dir, 'circuit.luau');
  await writeFile(path, bundle);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', path], { cwd: root, encoding: 'utf8', timeout: 1800000, maxBuffer: 1 << 28 });
  if (result.error) throw result.error;
  process.stdout.write(result.stdout);
  process.stderr.write(result.stderr);
  if (result.status !== 0) process.exit(result.status || 1);
} finally {
  await rm(dir, { recursive: true, force: true });
}
