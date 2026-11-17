// Build the four real island cities and exercise dense generated/baked island ground.
// Checks atomic replication budgets and geometry preservation, not rendered frame times.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = resolve(import.meta.dirname, '..');
const cityCheck = await readFile(join(root, 'scripts/check-city.mjs'), 'utf8');
const mocks = cityCheck.match(/const mocks = String.raw`([\s\S]*?)`;/)[1];
const names = ['LowPoly', 'Props', 'CityLand', 'CityBuildings', 'SmallCityBuilders', 'CityDetail', 'Lod', 'SmallCities', 'Biomes', 'Seabed', 'Islands'];
let code = 'local output = print\n' + mocks + String.raw`
-- The shared geometry doubles use string enum tokens. Serialization needs their names.
for _, category in {"Material", "PartType"} do
  Enum[category] = setmetatable({}, {__index=function(self, name)
    local value = {Name=name}; rawset(self, name, value); return value
  end})
end
local oldInstIndex = Inst.__index
Inst.__index = function(self, key)
  local value = oldInstIndex(self, key)
  if (key == "Material" or key == "Shape") and type(value) == "string" then
    return Enum[if key == "Material" then "Material" else "PartType"][value:match("[^.]+$")]
  end
  return value
end
local oldCFIndex = CF.__index
CF.__index = function(c, key)
  if key == "GetComponents" then return function(self)
    return self.p.X,self.p.Y,self.p.Z,self.r.X,self.u.X,self.b.X,self.r.Y,self.u.Y,self.b.Y,self.r.Z,self.u.Z,self.b.Z
  end end
  return oldCFIndex(c, key)
end
local savedDescriptions = {}
HttpService.JSONEncode = function(_, value) table.insert(savedDescriptions, value); return tostring(#savedDescriptions) end
local baseGetService = game.GetService
game.GetService = function(self, name)
  if name == "ReplicatedStorage" then return {Shared={Biomes={__module="Biomes"}}} end
  return baseGetService(self, name)
end
local Random = {new=function(seed)
  local state = seed
  local function nextValue() state = (state * 16807) % 2147483647; return (state - 1) / 2147483646 end
  return {
    NextNumber=function(_, a, b) local n = nextValue(); return if a == nil then n else a + (b-a)*n end,
    NextInteger=function(_, a, b) return a + math.floor(nextValue() * (b-a+1)) end,
  }
end}
local loaded, loaders = {}, {}
local function require(target)
  local name = target.__module
  if loaded[name] == nil then loaded[name] = loaders[name]() end
  return loaded[name]
end
local script = {Parent=setmetatable({}, {__index=function(_, name) return {__module=name} end})}
`;
for (const name of names) {
  const folder = name === 'Biomes' ? 'src/shared' : 'src/server/Map';
  code += `loaders[${JSON.stringify(name)}] = function()\n${await readFile(join(root, folder, name + '.luau'), 'utf8')}\nend\n`;
}
code += String.raw`
local Lod = require({__module="Lod"})
local Cities = require({__module="SmallCities"})
local CityDetail = require({__module="CityDetail"})
local prepareDetail = CityDetail.prepare
local detailEnabled, reductions = true, {}
local function countParts(model)
  local count = 0
  for _, d in model:GetDescendants() do if d:IsA("BasePart") then count += 1 end end
  return count
end
CityDetail.prepare = function(city)
  if not detailEnabled then return end
  local before = countParts(city)
  prepareDetail(city)
  reductions[city] = (reductions[city] or 0) + before - countParts(city)
end
local world = Instance.new("Folder"); world.Name = "Map"; world.Parent = workspace
local biome = Instance.new("Folder"); biome.Name = "Normal"; biome.Parent = world
local function island()
  local model = Instance.new("Model"); model.Name = "Island"; model.Parent = biome
  local ground = Instance.new("Model"); ground.Name = "Ground"; ground.Parent = model
  return model, ground
end
local ids = {}
local function verify(model, label)
  local count, largest, parts = 0, 0, 0
  for _, d in model:GetDescendants() do
    if d:IsA("Model") and d:HasTag("LodPiece") then
      count += 1
      local n = 0
      for _, child in d:GetDescendants() do if child:IsA("BasePart") then n += 1 end end
      check(n <= 200, label .. " atomic piece contains " .. n .. " parts")
      check(d.ModelStreamingMode == Enum.ModelStreamingMode.PersistentPerPlayer, label .. " piece is pinnable")
      local id = d:GetAttribute("PieceId")
      check(type(id) == "number" and not ids[id], "Every piece has a unique live id")
      ids[id] = true
      largest = math.max(largest, n)
    elseif d:IsA("BasePart") then
      parts += 1
      local parent, boundaries = d.Parent, 0
      while parent and parent ~= model do
        if parent:IsA("Model") and parent.ModelStreamingMode ~= Enum.ModelStreamingMode.Default then boundaries += 1 end
        parent = parent.Parent
      end
      check(boundaries == 1, label .. " ground part has exactly one atomic boundary")
    end
  end
  check(count > 0 and parts > 0, label .. " has pinned ground")
  output(label .. ": " .. parts .. " parts, " .. count .. " pieces, largest " .. largest)
  return count
end
local function fill(container, n)
  local originals = {}
  for i = 1, n do
    local part = Instance.new("WedgePart")
    part.Name = "Wedge"
    part.CFrame = CFrame.new(i % 7, i % 31, i % 11)
    part.Size = Vector3.new(5 + i % 4, 2, 9)
    part.Parent = container
    originals[part] = {part.CFrame, part.Size, part.Color, part.Material}
  end
  return originals
end
local function unchanged(originals, parent)
  for part, properties in originals do
    check(part:IsDescendantOf(parent), "Splitting keeps every original part")
    check(part.CFrame == properties[1] and part.Size == properties[2]
      and part.Color == properties[3] and part.Material == properties[4], "Splitting preserves geometry and appearance")
  end
end

local dense, ground = island()
local originals = fill(ground, 721)
Lod.prepareIsland(dense)
unchanged(originals, dense)
check(verify(dense, "Dense generated island") == 4, "Dense island is split into bounded arrivals")

local baked, bakedGround = island()
local old = Instance.new("Model"); old.Name = "GroundChunk"; old.Parent = bakedGround
old.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
old:AddTag("LodPiece"); old:SetAttribute("PieceId", 999999)
local bakedOriginals = fill(old, 701)
Lod.prepareIsland(baked)
check(old.Parent == bakedGround and not old:HasTag("LodPiece") and old:GetAttribute("PieceId") == nil
  and old.ModelStreamingMode == Enum.ModelStreamingMode.Default, "Baked oversized boundary is removed without deleting its container")
unchanged(bakedOriginals, baked)
check(verify(baked, "Dense baked island") == 4, "Baked oversized chunks migrate to the same arrival budget")

-- Real island geometry, including the nine-ring submerged apron, can be much denser
-- than a 96-stud spatial bin suggests. Exercise the sizes/shapes used by Regions.
local Islands = require({__module="Islands"})
local largestUnbounded = 0
for index, spec in {
  {8, 20, "stack"}, {16, 34, "stack"}, {22, 1.6, "mound"}, {40, 55, "peak"},
  {120, 60, "plateau"}, {340, 9, "mound"}, {420, 7, "atoll"},
  {440, 240, "volcano"}, {360, 40, "plateau"},
} do
  local model = Islands.build({position=Vector2.new(48, 48), radius=spec[1], height=spec[2],
    shape=spec[3], rng=Random.new(1847 + index),
    palette={top=Color3.fromRGB(98,116,78), cliff=Color3.fromRGB(120,118,116), shore=Color3.fromRGB(186,172,138)}})
  model.Parent = biome
  local bins, originalParts = {}, {}
  for _, part in model:GetDescendants() do
    if part:IsA("BasePart") then
      local key = math.floor(part.Position.X / 96) .. "," .. math.floor(part.Position.Z / 96)
      bins[key] = (bins[key] or 0) + 1
      largestUnbounded = math.max(largestUnbounded, bins[key])
      originalParts[part] = {part.CFrame, part.Size, part.Color, part.Material}
    end
  end
  Lod.prepareIsland(model)
  unchanged(originalParts, model)
  verify(model, "Generated " .. spec[3] .. " radius " .. spec[1])
end
check(largestUnbounded > 200, "Real island geometry reproduces oversized spatial bins")
output("Largest original 96-stud island bin: " .. largestUnbounded .. " parts")

Cities.ensure(world)
local cityBlocks = { Brambleport = 33, Northwick = 30, Westhaven = 37, Riverton = 40 }
local function verifyCity(city, label)
  verify(city, label)
  local buildings, deferred, protected = 0, 0, 0
  for _, d in city:GetDescendants() do
    if d:IsA("Model") and d:HasTag("CityDetail") then
      if d.Name:match("^CityBlock%d+$") then buildings += 1 end
      local parts = 0
      for _, x in d:GetDescendants() do if x:IsA("BasePart") then parts += 1 end end
      if parts > 0 then
        check(d:HasTag("LodPiece"), d.Name .. " building core and facade metadata share one streaming lifetime")
      else
        for _, x in d:GetDescendants() do
          if x:IsA("Model") and x.Name == "GroundChunk" then
            check(not x:HasTag("LodPiece") and x:GetAttribute("PieceId") == nil, d.Name .. " releases stale empty chunk boundaries")
          end
        end
      end
      local data = savedDescriptions[tonumber(d:GetAttribute("CityDetailData"))]
      check(type(data) == "table" and #data > 0, "Each facade has a complete compact description")
      for _, record in data do
        deferred += 1
        check(type(record[20]) == "string" and type(record[21]) == "string", "Facade material and shape names survive serialization")
      end
    elseif d:IsA("Part") and #d:GetChildren() > 0 then
      protected += 1
    end
  end
  check(buildings == cityBlocks[city.Name], city.Name .. " building cores retain their signs and lights")
  check(protected >= 18, "Building cores keep at least " .. protected .. " protected light and sign parts")
  check(reductions[city] == deferred and deferred > 1400, "Facade migration removes only described cosmetic parts")
  output(label .. ": " .. deferred .. " facade parts deferred, " .. countParts(city) .. " replicated parts remain")
end
for _, site in Cities.Sites do verifyCity(assert(world:FindFirstChild(site.name)), site.name) end

-- Reproduce the saved/current-version path: first build and split the former full
-- geometry, then run the same ensure call after the facade migration is available.
local bakedWorld = Instance.new("Folder"); bakedWorld.Name = "BakedMap"; bakedWorld.Parent = workspace
detailEnabled = false
Cities.ensure(bakedWorld)
Lod.prepareStreaming(bakedWorld)
local oldChunks = {}
for _, d in bakedWorld:GetDescendants() do
  if d:IsA("Model") and d.Name:match("^CityBlock%d+$") then
    for _, child in d:GetDescendants() do
      if child:IsA("Model") and child.Name == "GroundChunk" then table.insert(oldChunks, child) end
    end
  end
end
check(#oldChunks > 0, "Saved fixture has already-split building chunks")
detailEnabled = true
Cities.ensure(bakedWorld)
for _, chunk in oldChunks do
  check(chunk.Parent ~= nil and not chunk:HasTag("LodPiece") and chunk:GetAttribute("PieceId") == nil
    and chunk.ModelStreamingMode == Enum.ModelStreamingMode.Default,
    "Saved building chunks keep hierarchy and release stale piece boundaries (parent=" .. tostring(chunk.Parent ~= nil)
      .. ", piece=" .. tostring(chunk:HasTag("LodPiece")) .. ", id=" .. tostring(chunk:GetAttribute("PieceId")) .. ")")
end
for _, site in Cities.Sites do verifyCity(assert(bakedWorld:FindFirstChild(site.name)), "Saved " .. site.name) end
local bakedDescendants, bakedReductions = #bakedWorld:GetDescendants(), 0
for _, site in Cities.Sites do bakedReductions += reductions[bakedWorld:FindFirstChild(site.name)] end
Cities.ensure(bakedWorld)
check(#bakedWorld:GetDescendants() == bakedDescendants, "Repeated saved-city migration is idempotent")
local afterReductions = 0
for _, site in Cities.Sites do afterReductions += reductions[bakedWorld:FindFirstChild(site.name)] end
check(afterReductions == bakedReductions, "Repeated migration removes no additional geometry")

local authored = Instance.new("Model"); authored.Name = "CityBuilding99"; authored:AddTag("CityDetail")
local interior = Instance.new("Model"); interior.Name = "IndependentInterior"; interior.Parent = authored
fill(interior, 3)
Lod.pin(interior)
local interiorId = interior:GetAttribute("PieceId")
Lod.pin(authored)
check(not authored:HasTag("LodPiece") and authored.ModelStreamingMode == Enum.ModelStreamingMode.Default,
  "Prepared models with independent authored interiors are not promoted")
check(interior:GetAttribute("PieceId") == interiorId and interior.ModelStreamingMode == Enum.ModelStreamingMode.PersistentPerPlayer,
  "Independent authored interior boundaries are preserved")
local oversized = Instance.new("Model"); oversized.Name = "CityBuilding100"; oversized:AddTag("CityDetail")
fill(oversized, 201)
Lod.pin(oversized)
check(not oversized:HasTag("LodPiece"), "Prepared building promotion never exceeds its atomic part budget")
local descendants = #world:GetDescendants()
local function pieceSnapshot()
  local found = {}
  for _, d in world:GetDescendants() do if d:HasTag("LodPiece") then found[d] = d:GetAttribute("PieceId") end end
  return found
end
local snapshot = pieceSnapshot()
Lod.prepareStreaming(world)
Lod.prepareStreaming(world)
check(#world:GetDescendants() == descendants, "Repeated startup preparation does not add chunks")
for piece, id in snapshot do check(piece:GetAttribute("PieceId") == id, "Repeated preparation keeps ids stable") end

local swapped = Instance.new("Model"); swapped.Name = "Ground"
local swappedOriginals = fill(swapped, 403)
Lod.pinGround(swapped)
unchanged(swappedOriginals, swapped)
check(verify(swapped, "Replacement company ground") == 3, "Live replacement ground uses the same budget")
output("Travel streaming: " .. checks .. " checks passed")
`;
const temp = await mkdtemp(join(tmpdir(), 'fishing-travel-streaming-'));
try {
  const file = join(temp, 'travel.luau');
  await writeFile(file, code);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', file], {cwd: root, encoding: 'utf8', timeout: 120000});
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Travel streaming checks failed');
} finally {
  await rm(temp, {recursive: true, force: true});
}
