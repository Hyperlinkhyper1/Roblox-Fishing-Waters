// Run the production island-city builder with the same geometry doubles as the city checks.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const cityCheck = await readFile(join(root, 'scripts/check-city.mjs'), 'utf8');
const mocks = cityCheck.match(/const mocks = String\.raw`([\s\S]*?)`;/)[1];
const names = ['LowPoly', 'Props', 'CityLand', 'CityBuildings', 'SmallCities'];
let code = 'local _G_print = print\n' + mocks + `
local Random = {new = function(seed)
  local state = seed
  local function nextValue() state = (state * 16807) % 2147483647; return (state - 1) / 2147483646 end
  return {
    NextNumber = function(_, a, b) local n = nextValue(); return if a == nil then n else a + (b-a)*n end,
    NextInteger = function(_, a, b) return a + math.floor(nextValue() * (b-a+1)) end,
  }
end}
local loaded, loaders = {}, {}
local function require(target) local name = target.__module; if loaded[name] == nil then loaded[name] = loaders[name]() end; return loaded[name] end
local script = { Parent = setmetatable({}, { __index = function(_, name) return { __module = name } end }) }
loaders.Lod = function() return {prepareIsland=function() end} end
`;
for (const name of names) code += `loaders[${JSON.stringify(name)}] = function()\n${await readFile(join(root, 'src/server/Map', name + '.luau'), 'utf8')}\nend\n`;
code += `loaders.CompanyLayout = function()\n${await readFile(join(root, 'src/shared/CompanyIslands.luau'), 'utf8')}\nend\n`;
code += String.raw`
local Cities = require({__module="SmallCities"})
local companies = require({__module="CompanyLayout"})
local land = require({__module="CityLand"})
local root = Instance.new("Folder")
local scenery = Instance.new("Folder"); scenery.Parent = root
local function oldIsland(x, z)
  local island = Instance.new("Model"); island.Name = "Island"; island.Parent = scenery
  local ground = Instance.new("Model"); ground.Name = "Ground"; ground.Parent = island
  local piece = Instance.new("Part"); piece.Size = Vector3.new(80, 10, 80); piece.CFrame = CFrame.new(x, 0, z); piece.Parent = ground
  return island
end
local overlapping = oldIsland(Cities.Sites[1].x, Cities.Sites[1].z)
local distant = oldIsland(0, 0)
local reserved = {}
Cities.reserve(reserved)
check(#Cities.Sites == 4 and #reserved == 4, "Exactly four city sites are reserved")
for i, site in Cities.Sites do
  check(math.abs(site.x) + Cities.CLEARANCE < 5200 and math.abs(site.z) + Cities.CLEARANCE < 5200, "City and berth fit in the existing ocean")
  check(math.sqrt(site.x^2 + site.z^2) > 2700, "City is clear of the home and company islands")
  for _, company in companies.Sites do
    local angle = math.rad(company[1])
    local x, z = math.cos(angle) * company[2], math.sin(angle) * company[2]
    check(math.sqrt((site.x-x)^2 + (site.z-z)^2) > Cities.CLEARANCE + companies.FOOTPRINT, "City is clear of every company property")
  end
  for _, anchor in {{-3750,-1000,340}, {-1200,3000,420}, {3300,1300,440}, {1000,-3800,360}, {-650,2150,400}} do
    check(math.sqrt((site.x-anchor[1])^2 + (site.z-anchor[2])^2) > Cities.CLEARANCE + anchor[3], "City is clear of a major biome or Pirate Cove")
  end
  for j = 1, i-1 do
    local other = Cities.Sites[j]
    check(math.sqrt((site.x-other.x)^2 + (site.z-other.z)^2) > 2*Cities.CLEARANCE, "City islands are separated")
  end
end
Cities.ensure(root)
check(overlapping.Parent == nil and distant.Parent == scenery, "Migration removes overlapping scenery and preserves distant islands")
for _, site in Cities.Sites do
  local city = root:FindFirstChild(site.name)
  check(city ~= nil and city:GetAttribute("ChartCoast") ~= nil and city:GetAttribute("ChartLabel") == site.name, "Each city has a charted island")
  local ground = city:FindFirstChild("Ground")
  local port = ground:FindFirstChild("IndustrialPort")
  check(port and port:FindFirstChild("CargoPier") and port:FindFirstChild("Warehouses") and port:FindFirstChild("CargoCrane"), "Each city has a working-looking industrial dock")
  local pier, apron = port:FindFirstChild("CargoPier"), port:FindFirstChild("PortApron")
  check(pier.Position.Z + pier.Size.Z / 2 >= site.z - 300 and pier.Position.Z - pier.Size.Z / 2 < site.z - 300
    and apron.Position.Z - apron.Size.Z / 2 <= site.z - 300,
    "Pier crosses the quay and meets the port apron")
  local blocks, warehouses, cranes, containers = 0, 0, 0, 0
  for _, item in ground:GetDescendants() do
    if item:GetAttribute("CityBuildingVariant") then blocks += 1 end
    if item.Name == "Warehouse" then warehouses += 1 end
    if item.Name == "CargoCrane" then cranes += 1 end
    if item.Name == "ShippingContainer" then containers += 1 end
  end
  check(blocks == 9 and warehouses == 3 and cranes == 2 and containers >= 10, "City blocks and industrial details are present")
  local _, bounds = ground:GetBoundingBox()
  check(bounds.X < 1100 and bounds.Z < 1100, "City is much smaller than the main city's mainland")
end
local before = #root:GetDescendants()
Cities.ensure(root)
check(#root:GetDescendants() == before, "Baked city migration is idempotent")
_G_print("Island cities: " .. checks .. " geography, geometry and migration checks passed")
`;
const temp = await mkdtemp(join(tmpdir(), 'fishing-small-cities-'));
try {
  const file = join(temp, 'cities.luau');
  await writeFile(file, code);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', file], {cwd: root, encoding: 'utf8', timeout: 120000});
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Island city checks failed');
} finally {
  await rm(temp, {recursive: true, force: true});
}
