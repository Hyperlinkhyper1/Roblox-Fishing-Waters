// Build the real city and industrial megastore to check geography and relocation together.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { resolve, join } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = resolve(import.meta.dirname, '..');
const read = path => readFile(join(root, path), 'utf8');
const mocks = (await read('scripts/check-city.mjs')).match(/const mocks = String.raw`([\s\S]*?)`;/)[1];
const names = ['LowPoly', 'Props', 'CityLand', 'CityCircuit', 'CityHills', 'CityBuildings',
  'CityLandmark', 'CityStation', 'CityPort', 'CityRefinery', 'CityMetro', 'MetroStations',
  'Lod', 'ModernCity', 'Biomes', 'ParliamentLayout', 'TechCatalog', 'TechStoreLayout', 'TechStoreFixtures', 'TechStore'];
const shared = new Set(['Biomes', 'ParliamentLayout', 'TechCatalog', 'TechStoreLayout', 'TechStoreFixtures']);
let program = 'local output = print\n' + mocks + String.raw`
local function token(name)
  return setmetatable({ __module = name }, { __index = function(_, key)
    if key == 'WaitForChild' then return function(_, child) return token(child) end end
    return token(key)
  end })
end
local oldGetService = game.GetService
game.GetService = function(self, name)
  if name == 'ReplicatedStorage' or name == 'ReplicatedFirst' then return token(name) end
  return oldGetService(self, name)
end
local loaded, loaders = {}, {}
local function require(target)
  if not loaded[target.__module] then loaded[target.__module] = loaders[target.__module]() end
  return loaded[target.__module]
end
local script = token('script')
loaders.UITheme = function() return { text = function() end } end
`;
for (const name of names) {
  program += `loaders.${name} = function()\n${await read(`src/${shared.has(name) ? 'shared' : 'server/Map'}/${name}.luau`)}\nend\n`;
}
program += String.raw`
local City, Land = require(token('ModernCity')), require(token('CityLand'))
local Store = require(token('TechStore'))
local Layout = require(token('TechStoreLayout'))
local map = Instance.new('Folder'); map.Parent = workspace
local city = City.build(map)
local site = City.techStoreSite()
local rect = City.TECH_STORE_SITE
local coast = Land.roughen(City.COAST, 110, 22)
check(Land.fits(coast, (rect.x0 + rect.x1)/2, (rect.z0 + rect.z1)/2, site.w, site.d, 20),
  'The whole industrial campus is on solid mainland, away from the coast')
check(rect.x0 > require(token('CityRefinery')).GATE_X + 10, 'Refinery road remains outside the campus')
local blockers, oldLot, road, access = {}, false, nil, nil
for _, part in city:GetDescendants() do
  if not part:IsA('BasePart') then continue end
  local pos, h = part.Position - v3(7000, 0, 7000), halfExtent(part)
  if part.Name == 'Pavement' and math.abs(pos.X - 277.5) < 1 and math.abs(pos.Z - 177.5) < 1 then oldLot = true end
  if part.Name == 'HarbourRoad' then road = part end
  if part.Name == 'IndustrialRetailAccess' then access = part end
  if part.Transparency < 1 and pos.Y + h.Y > 9.1
    and pos.X + h.X > rect.x0 and pos.X - h.X < rect.x1
    and pos.Z + h.Z > rect.z0 and pos.Z - h.Z < rect.z1 then
    table.insert(blockers, part.Name)
  end
end
check(#blockers == 0, 'No trees, buildings, refinery equipment or dock props intersect the campus: ' .. table.concat(blockers, ', '))
check(oldLot, 'The old cafe-quarter store block is restored to the city')
check(road and access, 'Harbour Road and the retail driveway are built')
check(math.abs((road.Position.Z + road.Size.Z/2) - (access.Position.Z - access.Size.Z/2)) < 0.01,
  'Driveway joins Harbour Road without a gap')
check(math.abs((access.Position.Z + access.Size.Z/2) - (7000 + rect.z0)) < 0.01,
  'Driveway reaches the megastore lot without a gap')
local old = Instance.new('Model'); old.Name = Store.NAME; old:SetAttribute('StoreVersion', 3); old.Parent = map
local store = Store.ensure(map)
check(old.Parent == nil and store:GetAttribute('StoreVersion') == Store.VERSION, 'Existing stores migrate to the new megastore')
local frame = store:GetAttribute('StoreFrame')
check(math.abs(frame.Position.X - 6025) < 0.01 and math.abs(frame.Position.Z - 7068) < 0.01,
  'Store is actually placed on the industrial campus')
local entrance = frame * v3(0, 3.3, Layout.Z1 + 5)
check(entrance.Z < frame.Position.Z, 'Entrance faces north towards Harbour Road and the terminal')
output('Micro Harbour district: ' .. checks .. ' checks passed (real city, land, road access, scenery clearance and old-store migration)')
`;
const temporary = await mkdtemp(join(tmpdir(), 'tech-district-'));
try {
  const target = join(temporary, 'check.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { cwd: root, encoding: 'utf8', timeout: 60000, maxBuffer: 1 << 24 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Micro Harbour district check failed');
} finally {
  await rm(temporary, { recursive: true, force: true });
}
