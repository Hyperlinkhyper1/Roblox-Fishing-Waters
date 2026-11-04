// Exercise the production baked-harbour migration with recording Roblox doubles.
// The expensive scenery builder is replaced; drydock/harbour checks cover its geometry.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = path => readFile(join(root, path), 'utf8');
const primitives = (await read('scripts/harbour-geometry.luau')).split('local CFrame = {}')[0];
const mocks = (await read('scripts/drydock-geometry.luau')).split('local function loadBoatCatalog()')[0]
  .replace('-- SHARED_PRIMITIVES --', () => primitives);
let source = await read('src/server/Map/Harbour.luau');
source = source.replace(/^local (\w+) = require\(.*$/gm, 'local $1 = dependencies.$1');
source = source.replaceAll('require(game:GetService("ReplicatedStorage").Shared.Biomes)', 'dependencies.Biomes');
if (!/return Harbour\s*$/.test(source)) throw new Error('Harbour return hook changed');
source = source.replace(/return Harbour\s*$/, 'Harbour.testShape = makeShape; Harbour.testAnchors = BASES; return Harbour');
const program = mocks + `
local frameIndex = frameMt.__index
function frameMt.__index(self, key)
  if key == "X" or key == "Y" or key == "Z" then return self.Position[key] end
  return frameIndex(self, key)
end
local originalTypeof = typeof
typeof = function(value)
  if type(value) == "table" and getmetatable(value) == getmetatable(Vector2.zero) then return "Vector2" end
  return originalTypeof(value)
end
dependencies.Props = {pick = function() end}
dependencies.Biomes = (function()
${await read('src/shared/Biomes.luau')}
end)()
local Harbour = (function()
${source}
end)()
local checks = 0
local function check(value, message)
  checks += 1
  assert(value, message)
end
local function sameVector(actual, expected)
  return (actual - expected).Magnitude < 0.0001
end
check(Harbour.BASE_COUNT == 15 and #Harbour.testAnchors == 15, "The production layout supplies fifteen bases")
local center = Vector2.new(250, -350)
local shape = Harbour.testShape(center)
local plaza = shape.toWorld({870, 665})
check(sameVector(plaza, center + Vector2.new(0, -565.25)), "Expansion preserves the plaza and metro world anchor")
for _, point in shape.coast do
  check((point - center).Magnitude < Harbour.FOOTPRINT, "The placement footprint contains the expanded coastline")
end
local recordedSeed, buildCalls = nil, 0
local randomNew = Random.new
function Random.new(seed)
  recordedSeed = seed
  return randomNew(seed)
end
local function baseFolder(island, count)
  local bases = Instance.new("Folder")
  bases.Name, bases.Parent = "Bases", island
  for id = 1, count do
    local base = Instance.new("Model")
    base.Name, base.Parent = "Base" .. id, bases
    base:SetAttribute("BaseId", id)
    base:SetAttribute("OwnerUserId", 0)
    CollectionService:AddTag(base, Harbour.BASE_TAG)
  end
  return bases
end
function Harbour.build(parent, rng, buildCenter)
  buildCalls += 1
  check(parent:FindFirstChild("Harbour Isle") == nil, "The obsolete harbour is removed before rebuilding")
  check(rng ~= nil and recordedSeed == dependencies.Biomes.Seed + 1, "Migration uses the normal biome's generation seed")
  check(sameVector(buildCenter, center), "Migration preserves the baked harbour's center")
  local island = Instance.new("Model")
  island.Name, island.Parent = "Harbour Isle", parent
  island:SetAttribute("HarbourLayoutVersion", Harbour.LAYOUT_VERSION)
  island:SetAttribute("LayoutCenter", buildCenter)
  baseFolder(island, Harbour.BASE_COUNT)
  return CFrame.new(buildCenter.X, 8.5, buildCenter.Y - 531.25)
end
local map = Instance.new("Folder")
map.Name, map.Parent = "Map", workspace
local normal = Instance.new("Folder")
normal.Name, normal.Parent = "Gullhaven Sound", map
local old = Instance.new("Model")
old.Name, old.Parent = "Harbour Isle", normal
baseFolder(old, 6)
local drydock = Instance.new("Model")
drydock.Name, drydock.Parent = "Drydock", old
local footprint = Instance.new("Part")
footprint.Name, footprint.Parent = "ShopFootprint", drydock
footprint.CFrame = CFrame.new(center.X, 5, plaza.Y + 82)
local publicSpawn = Instance.new("SpawnLocation")
publicSpawn.Name, publicSpawn.Parent = "HarbourSpawn", map
publicSpawn.CFrame = CFrame.new(9000, 9000, 9000)
local function scenery(radius, offset, name)
  local island = Instance.new("Model")
  island.Name, island.Parent = name or "Island", normal
  island:SetAttribute("Radius", radius)
  local ground = Instance.new("Model")
  ground.Name, ground.Parent = "Ground", island
  local part = Instance.new("Part")
  part.Size = Vector3.new(2 * radius, 10, 2 * radius)
  part.CFrame = CFrame.new(center.X + offset.X, 0, center.Y + offset.Y)
  part.Parent = ground
  return island
end
local tiny = scenery(30, Vector2.new(1700, 100))
local intersecting = scenery(150, Vector2.new(1100, 0))
local large = scenery(150, Vector2.new(1900, 200))
local distant = scenery(30, Vector2.new(2600, 0))
local company = scenery(108, Vector2.new(950, 0), "Company Island 1")
company:SetAttribute("CompanyIslandVersion", 1)
local shells = Instance.new("Model")
shells.Name, shells.Parent = "Lod", map
Harbour.ensureCapacity(map)
local upgraded = normal:FindFirstChild("Harbour Isle")
check(buildCalls == 1 and old.Parent == nil and upgraded ~= old, "A six-base bake receives the replacement harbour")
check(#upgraded:FindFirstChild("Bases"):GetChildren() == 15, "All fifteen slots exist before services claim them")
check(sameVector(publicSpawn.Position, Vector3.new(center.X, 8.5, center.Y - 531.25)), "The public spawn is refreshed from the new harbour")
check(tiny.Parent == nil and intersecting.Parent == nil, "Tiny nearby and intersecting scenery is removed")
check(large.Parent == normal and distant.Parent == normal, "Substantial and distant islands are retained")
check(company.Parent == normal, "Company properties are retained")
check(shells.Parent == nil and map:FindFirstChild("Lod") == nil, "Obsolete LOD shells are removed for the deferred rebuild")
check(map:GetAttribute("HarbourRoomVersion") == Harbour.LAYOUT_VERSION, "Room cleanup is versioned")
local rebuiltShells = Instance.new("Model")
rebuiltShells.Name, rebuiltShells.Parent = "Lod", map
Harbour.ensureCapacity(map)
check(buildCalls == 1 and normal:FindFirstChild("Harbour Isle") == upgraded, "A current harbour is not rebuilt twice")
check(rebuiltShells.Parent == map, "A repeated repair keeps rebuilt LOD shells")
check(large.Parent == normal and distant.Parent == normal and company.Parent == normal, "Repeated repair retains unrelated islands")
-- An incomplete bake must be repaired even when its version marker is current.
upgraded:FindFirstChild("Bases"):FindFirstChild("Base15"):Destroy()
Harbour.ensureCapacity(map)
check(buildCalls == 2 and upgraded.Parent == nil, "A missing slot is repaired despite a current layout version")
check(#normal:FindFirstChild("Harbour Isle"):FindFirstChild("Bases"):GetChildren() == 15, "The repaired layout again has fifteen slots")
check(rebuiltShells.Parent == nil, "Repairing incomplete geometry invalidates its old shells")
-- Counting children alone must not accept duplicate or misidentified slots.
local misidentified = normal:FindFirstChild("Harbour Isle")
local misidentifiedBases = misidentified:FindFirstChild("Bases")
misidentifiedBases:FindFirstChild("Base15"):SetAttribute("BaseId", 14)
check(#misidentifiedBases:GetChildren() == 15, "The malformed fixture retains fifteen children")
Harbour.ensureCapacity(map)
check(buildCalls == 3 and misidentified.Parent == nil, "A duplicate base ID forces repair despite the correct child count")
local correctedBases = normal:FindFirstChild("Harbour Isle"):FindFirstChild("Bases")
check(#correctedBases:GetChildren() == 15 and correctedBases:FindFirstChild("Base15"):GetAttribute("BaseId") == 15, "Repair restores all fifteen correctly identified slots")
print(string.format("Harbour layout: %d capacity, migration, placement and idempotence checks passed.", checks))
`;
const temporaryRoot = resolve(tmpdir());
const temporary = await mkdtemp(join(temporaryRoot, 'harbour-layout-'));
try {
  const target = join(temporary, 'check.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute.exe', ['run', target], {
    cwd: root, encoding: 'utf8', timeout: 30000, maxBuffer: 4 * 1024 * 1024,
  });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Harbour layout checks failed');
} finally {
  if (dirname(resolve(temporary)) !== temporaryRoot) throw new Error('Unexpected temporary directory');
  await rm(temporary, {recursive: true, force: true});
}
