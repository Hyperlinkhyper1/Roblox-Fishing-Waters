// Café and company-branch checks: pure branch/save rules, the café layout in the
// city's blocks, and a compile pass over every café module. Customers, prompts
// and the PC app still need a Studio play test.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = async path => (await readFile(join(root, path), 'utf8')).replaceAll('\r\n', '\n');
const lute = process.env.LUTE || 'lute';
const temporary = await mkdtemp(join(tmpdir(), 'fishing-cafe-'));

function run(path, label) {
  const result = spawnSync(lute, ['run', path], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${label} failed (${result.status})`);
}

try {
  // Street tables and café sites come from the real ModernCity source.
  const city = await read('src/server/Map/ModernCity.luau');
  const grab = (startText, endText) => {
    const start = city.indexOf(startText);
    const end = city.indexOf(endText, start);
    if (start < 0 || end < 0) throw new Error(`ModernCity changed near "${startText}"`);
    return city.slice(start, end + endText.length);
  };
  const streets = grab('local STREETS_X = {', '\n}\n') + grab('local STREETS_Z = {', '\n}\n');
  const sites = grab('local CAFE_ROWS = {', 'City.CAFE_CURB = CURB');
  const harbour = await read('src/server/Map/Harbour.luau');
  const bases = harbour.slice(harbour.indexOf('local BASES = {'), harbour.indexOf('\n}\n', harbour.indexOf('local BASES = {')) + 3);
  const cityPrelude = `local City = {}\nlocal CENTER = Vector3.new(7000, 0, 7000)\nlocal TOP, CURB = 8, 8.9\n${streets}\n${sites}\n`
    + `local function CAFE_SITES() return City.cafeSites() end\n${bases}\nlocal HARBOUR_BASES = #BASES\n`;

  const program = cityPrelude + (await read('scripts/cafe.luau'))
    .replace('-- BRANCHES_SOURCE --', await read('src/shared/Branches.luau'))
    .replace('-- SAVE_DATA_SOURCE --', await read('src/server/SaveData.luau'))
    .replace('-- CAFE_CATALOG_SOURCE --', await read('src/shared/CafeCatalog.luau'));
  // lute has Vector3 and CFrame only through its Roblox-like mocks: provide tiny ones.
  const math3d = `
local Vector3 = {}
Vector3.__index = Vector3
function Vector3.new(x, y, z) return setmetatable({X = x or 0, Y = y or 0, Z = z or 0}, Vector3) end
Vector3.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vector3.__index = function(v, key)
  if key == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
  return rawget(Vector3, key)
end
local CFrame = {}
CFrame.__index = CFrame
function CFrame.new(position) return setmetatable({Position = position}, CFrame) end
function CFrame.Angles() return setmetatable({Position = Vector3.new()}, CFrame) end
CFrame.__mul = function(a, b) return CFrame.new(a.Position + b.Position) end
`;
  const rules = join(temporary, 'cafe.luau');
  await writeFile(rules, math3d + program);
  run(rules, 'Café checks');

  // Every changed or new module must at least parse.
  const modules = [
    'src/shared/Branches.luau', 'src/shared/CafeCatalog.luau',
    'src/server/CafeService.luau', 'src/server/BranchService.luau', 'src/server/Map/CafePlots.luau',
    'src/server/Map/ModernCity.luau', 'src/server/BaseService.luau', 'src/server/OfficeComputerService.luau',
    'src/server/SaveService.luau', 'src/server/SaveData.luau', 'src/server/BoatData.luau',
    'src/server/BoatService.luau', 'src/server/CatchService.luau', 'src/server/init.server.luau',
    'src/client/Cafe.luau', 'src/client/BranchApp.luau', 'src/client/OfficeComputer.luau',
    'src/client/SaveSelection.luau', 'src/client/init.client.luau',
  ];
  for (const [index, module] of modules.entries()) {
    const path = join(temporary, `compile-${index}.luau`);
    await writeFile(path, 'do return end\n' + await read(module));
    run(path, `Compiling ${module}`);
  }
  console.log(`Café modules: ${modules.length} files compile`);
} finally {
  await rm(temporary, { recursive: true, force: true });
}
