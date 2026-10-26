// Execute production startup/map code against recording mocks. These checks cover
// readiness and streaming policy, not Studio physics, replication, or join timing.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const temporary = await mkdtemp(join(tmpdir(), 'fishing-world-startup-'));
const prelude = `
local events, checks = {}, 0
local function record(event) table.insert(events, event) end
local function check(value, message) checks += 1; assert(value, message) end
local function index(event)
  for i, value in events do if value == event then return i end end
  return math.huge
end
local methods = {}
local instanceMt = {
  __index = function(self, key)
    if key == "Parent" then return rawget(self, "_parent") end
    return methods[key]
  end,
  __newindex = function(self, key, value)
    if key == "Parent" then
      local old = rawget(self, "_parent")
      if old then
        local at = table.find(old._children, self)
        if at then table.remove(old._children, at) end
      end
      rawset(self, "_parent", value)
      if value then table.insert(value._children, self) end
    else rawset(self, key, value) end
  end,
}
local Instance = {new = function(class)
  return setmetatable({ClassName=class, _children={}, _attributes={},
    ChildAdded={Connect=function() return {Disconnect=function() end} end}}, instanceMt)
end}
function methods:IsA(class)
  return self.ClassName == class or (class == "BasePart" and self.ClassName == "SpawnLocation")
end
function methods:GetChildren() return table.clone(self._children) end
function methods:GetDescendants()
  local found = {}
  for _, child in self._children do
    table.insert(found, child)
    for _, descendant in child:GetDescendants() do table.insert(found, descendant) end
  end
  return found
end
function methods:FindFirstChild(name)
  for _, child in self._children do if child.Name == name then return child end end
end
function methods:FindFirstChildOfClass(class)
  for _, child in self._children do if child:IsA(class) then return child end end
end
function methods:SetAttribute(key, value) self._attributes[key] = value end
function methods:GetAttribute(key) return self._attributes[key] end
function methods:Destroy() self.Parent = nil end
local function object(class, name, parent)
  local item = Instance.new(class); item.Name = name; item.Parent = parent; return item
end
local Enum = setmetatable({}, {__index = function(self, key)
  local values = setmetatable({}, {__index = function(_, value) return value end})
  rawset(self, key, values); return values
end})
local Color3 = {fromRGB = function(...) return {...} end}
local Vector3 = {new = function(x,y,z) return {X=x,Y=y,Z=z} end}
local CFrame = {new = function(...) return {...} end}
local Random = {new = function(seed) return {seed=seed} end}
local task = {wait=function() record("yield") end}
local workspace = object("Workspace", "Workspace")
workspace.Terrain = object("Terrain", "Terrain", workspace)
function workspace.Terrain:Clear() record("clear") end
function workspace.Terrain:FillBlock() record("ocean-tile") end
function workspace.Terrain:SetMaterialColor() end
local ReplicatedStorage = object("ReplicatedStorage", "ReplicatedStorage")
ReplicatedStorage.Shared = {Biomes="Biomes"}
local Lighting = object("Lighting", "Lighting")
local Players = {CharacterAutoLoads=true}
local game = {GetService=function(_, name)
  return ({Players=Players, ReplicatedStorage=ReplicatedStorage, Lighting=Lighting})[name]
end}
local warn = function() record("warning") end
local look = {}
local Biomes = {MapHalfSize=8, WaterLevel=0, SeaFloor=-64, Seed=1847}
for _, name in {"Normal", "Swamp", "Tropical", "Volcanic", "Ice", "OpenSea"} do
  Biomes[name] = {name=name, center={}, look=look}
end
Biomes.list = {Biomes.Normal, Biomes.Swamp, Biomes.Tropical, Biomes.Volcanic, Biomes.Ice}
`;

try {
  const map = (await readFile(join(root, 'src/server/Map/init.luau'), 'utf8'))
    .replace('require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))', '{}')
    .replace('require(ReplicatedStorage.Shared.Biomes)', 'Biomes')
    .replace(/require\(script\.(\w+)\)/g, 'dependencies.$1');
  await run('map', prelude + `
local dependencies = {}
dependencies.Seabed = {shelf=function() record("shelf") end}
dependencies.SeabedDetails = {ensure=function() record("seabed") end}
dependencies.Lod = {build=function() record("lod") end, prepareStreaming=function() end}
dependencies.Regions = {normal=function(ctx, ready)
  check(ctx.rng.seed == Biomes.Seed + 1, "Harbour must retain its seeded RNG")
  record("harbour-built")
  ready({})
  record("normal-scenery")
end}
for _, name in {"swamp", "tropical", "volcanic", "ice", "openSea"} do
  dependencies.Regions[name] = function() record(name) end
end
local Map = (function()
${map}
end)()
local root = Map.build(function(folder)
  check(folder:FindFirstChild("HarbourSpawn") ~= nil, "Safe fallback spawn must exist before readiness")
  check(index("ocean-tile") < index("harbour-built"), "Ocean must precede playable harbour")
  check(index("normal-scenery") == math.huge, "Surrounding islands must not gate readiness")
  record("ready")
end, function() end)
for _, name in {"normal-scenery", "swamp", "tropical", "volcanic", "ice", "openSea", "seabed", "lod"} do
  check(index("ready") < index(name) and index(name) < math.huge, "Retain deferred world feature " .. name)
end
events = {}
Map.build()
check(index("lod") < math.huge, "Studio bake without a callback must still finish the full world")
check(root.Parent == nil, "Explicit rebuild must replace the previous map")
print("Map startup: " .. checks .. " checks passed")
`);

  const regions = await readFile(join(root, 'src/server/Map/Regions.luau'), 'utf8');
  const normal = regions.match(/function Regions\.normal\([\s\S]*?\nend/)[0];
  await run('normal-region', prelude + `
local Regions = {}
local Harbour = {FOOTPRINT=820, build=function() record("harbour-built"); return "spawn" end}
local NORMAL = {land={}, rock={}}
local function archipelago() record("archipelago"); return {} end
local function forest() end
local function scatterOn() end
${normal}
local ctx = {rng={}, folder={}, biome=Biomes.Normal, placed={}}
local spawn = Regions.normal(ctx, function(point)
  check(point == "spawn", "Readiness must use the harbour's real spawn")
  check(#ctx.placed == 1 and ctx.placed[1].radius == 820, "Reserve harbour footprint before continuation")
  check(index("archipelago") == math.huge, "Readiness must precede surrounding island generation")
  record("ready")
end)
check(spawn == "spawn" and index("ready") < index("archipelago"), "Full normal region must retain spawn and scenery")
print("Normal region: " .. checks .. " checks passed")
`);

  const lod = (await readFile(join(root, 'src/server/Map/Lod.luau'), 'utf8'))
    .replace('require(script.Parent.LowPoly)', '{}');
  await run('lod', prelude + `
local Lod = (function()
${lod}
end)()
local map = object("Folder", "Map", workspace)
local biome = object("Folder", "Normal", map)
local harbour = object("Model", "Harbour Isle", biome)
object("Model", "Ground", harbour)
harbour.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
local island = object("Model", "Distant Island", biome)
object("Model", "Ground", island)
local shells = object("Model", "Lod", map)
Lod.build(map)
check(harbour.ModelStreamingMode == Enum.ModelStreamingMode.Default, "Even baked atomic harbour must stream nearby parts independently")
check(island.ModelStreamingMode == Enum.ModelStreamingMode.Default, "Islands must stream in pieces, never as one frame-freezing atomic unit")
check(map:FindFirstChild("Lod") == shells, "Existing baked shells must remain intact")
check(shells.ModelStreamingMode == Enum.ModelStreamingMode.Persistent, "Baked shells must never stream out/reload")
print("Baked streaming policy: " .. checks .. " checks passed")
`);

  const server = await readFile(join(root, 'src/server/init.server.luau'), 'utf8');
  for (const mode of ['generated', 'baked', 'critical-error', 'require-error', 'distant-error']) {
    await run('server-' + mode, prelude + `
local mode = "${mode}"
local root
if mode == "baked" then
  root = object("Folder", "Map", workspace)
  object("SpawnLocation", "HarbourSpawn", root)
end
local modules = {Biomes=Biomes}
local script = {Map={moduleName="Map", Harbour="Harbour", Mediterranean="Mediterranean"}, BaseService="BaseService",
  BoatService="BoatService", FishingService="FishingService", WeatherService="WeatherService",
  AnglerService="AnglerService", LeaderboardService="LeaderboardService"}
local function ready() return ReplicatedStorage:GetAttribute("FishingWatersWorldReady") == true end
for _, name in {"BaseService", "BoatService", "FishingService", "WeatherService", "AnglerService", "LeaderboardService", "AnglerService", "LeaderboardService"} do
  modules[name] = {start=function()
    check(not ready(), "Services must start before world readiness")
    if name == "BaseService" then
      check(index("BoatService") < math.huge and index("FishingService") < math.huge, "Install inventory listeners before characters spawn")
      check(index("LeaderboardService") < math.huge, "Install plaza boards on generated and baked maps before spawning")
      check(root:FindFirstChild("HarbourSpawn") ~= nil, "Never spawn without safe ground")
      Players.CharacterAutoLoads = true
    end
    record(name)
  end}
end
local function cosmetic(name)
  check(ready(), name .. " must not delay the playable harbour")
  record(name)
end
modules.Harbour = {}
for _, name in {"ensurePlazaPaving", "ensureBoating", "ensureFishing", "ensureBases"} do
  modules.Harbour[name] = function()
    check(not Players.CharacterAutoLoads and not ready(), "Complete gameplay repairs before spawning: " .. name)
    record(name)
  end
end
modules.Harbour.ensureSurf = function() cosmetic("surf") end
modules.Mediterranean = {ensureBoats=function() cosmetic("decorative-boats") end}
modules.Map = {
  prepareStreaming=function() check(not ready(), "Fix harbour streaming before readiness"); record("streaming") end,
  ensureSeabedDetails=function() cosmetic("seabed") end,
  ensureLod=function() cosmetic("lod") end,
  ensureSignText=function() cosmetic("signs") end,
  animate=function() cosmetic("animate") end,
  build=function(callback, onStage)
    check(not Players.CharacterAutoLoads, "Disable auto-spawn before runtime generation")
    if mode == "critical-error" then error("mock generation failure") end
    root = object("Folder", "Map", workspace)
    object("SpawnLocation", "HarbourSpawn", root)
    record("harbour-built")
    onStage("Building harbour", 0.25)
    callback(root)
    cosmetic("distant-world")
    if mode == "distant-error" then error("mock distant scenery failure") end
  end,
}
local require = function(module)
  if mode == "require-error" then error("mock module import failure") end
  return modules[if type(module) == "table" then module.moduleName else module]
end
${server}
if mode == "critical-error" or mode == "require-error" then
  check(not ready() and not Players.CharacterAutoLoads, "Critical failure must keep unsafe characters blocked")
  check(ReplicatedStorage:GetAttribute("FishingWatersStartupError"), "Critical failure must reach the loading screen")
  check(not ReplicatedStorage:GetAttribute("FishingWatersGenerationComplete"), "Failed generation cannot be complete")
elseif mode == "distant-error" then
  check(ready() and Players.CharacterAutoLoads, "A distant scenery error must not revoke a usable harbour")
  check(ReplicatedStorage:GetAttribute("FishingWatersGenerationError"), "Report incomplete distant generation")
  check(not ReplicatedStorage:GetAttribute("FishingWatersStartupError"), "A distant failure is not a harbour startup failure")
else
  check(ready() and Players.CharacterAutoLoads, "Completed harbour must become playable")
  check(ReplicatedStorage:GetAttribute("FishingWatersGenerationComplete"), "Full generation must finish")
  check(ReplicatedStorage:GetAttribute("FishingWatersLoadProgress") == 1, "Server progress must finish")
  if mode == "generated" then
    check(index("ensureBases") == math.huge and index("ensureBoating") == math.huge, "Fresh builders must avoid duplicate legacy repairs")
  else
    for _, name in {"ensurePlazaPaving", "ensureBoating", "ensureFishing", "ensureBases"} do
      check(index(name) < index("BaseService"), "Retain required baked-map migration " .. name)
    end
  end
end
print("Server startup ${mode}: " .. checks .. " checks passed")
`);
  }

  const baseService = await readFile(join(root, 'src/server/BaseService.luau'), 'utf8');
  for (const withBase of [true, false]) {
    await run('spawn-' + (withBase ? 'base' : 'plaza'), prelude + `
local threads = {}
task.wait = function() coroutine.yield() end
task.spawn = function(callback, ...)
  local thread = coroutine.create(callback)
  table.insert(threads, thread)
  assert(coroutine.resume(thread, ...))
end
local function resumePlacement()
  for _, thread in threads do
    if coroutine.status(thread) == "suspended" then assert(coroutine.resume(thread)) end
  end
end
local function signal()
  local callbacks = {}
  return {
    Connect=function(_, callback) table.insert(callbacks, callback) end,
    Fire=function(_, ...)
      for _, callback in callbacks do task.spawn(callback, ...) end
    end,
  }
end
local positionMt = {__sub=function(a, b) return {Magnitude=math.abs(a.X - b.X)} end}
local function position(x) return setmetatable({X=x}, positionMt) end
local map = object("Folder", "Map", workspace)
local fallback = object("SpawnLocation", "HarbourSpawn", map)
fallback.Position = position(100)
fallback.CFrame = setmetatable({Position=fallback.Position}, {__add=function(frame) return frame end})
local base = object("Model", "Base", map)
base:SetAttribute("BaseId", 1)
base:SetAttribute("OwnerUserId", 0)
local point = object("SpawnLocation", "SpawnPoint", base)
point.Position = position(200)
point.CFrame = setmetatable({Position=point.Position}, {__add=function(frame) return frame end})
local player = object("Player", "Player")
player.UserId, player.DisplayName = 42, "Tester"
player.CharacterAdded = signal()
local function character()
  local item = object("Model", "Character", workspace)
  local root = object("BasePart", "HumanoidRootPart", item)
  root.Position = position(0)
  function item:WaitForChild(name) return self:FindFirstChild(name) end
  function item:PivotTo(frame) root.Position = frame.Position; record("relocated") end
  return item
end
player.Character = character()
Players.PlayerAdded, Players.PlayerRemoving = signal(), signal()
function Players:GetPlayers() return {player} end
local CollectionService = {GetTagged=function() return ${withBase ? '{base}' : '{}'} end}
game.GetService = function(_, name)
  return ({Players=Players, CollectionService=CollectionService})[name]
end
local Service = (function()
${baseService}
end)()
Service.start()
local expected = ${withBase ? 'point' : 'fallback'}
check(player.RespawnLocation == expected, "Choose the ${withBase ? 'claimed base' : 'fallback plaza'} explicitly")
check(player:GetAttribute("FishingWatersSpawnReady") == false, "Root arrival must not precede final spawn readiness")
check(index("relocated") == math.huge, "Placement must still be pending during the initial yield")
resumePlacement()
check(player:GetAttribute("FishingWatersSpawnReady") == true, "Final placement must release the loader")
check(player.Character:FindFirstChild("HumanoidRootPart").Position == expected.Position, "Relocate to the actual selected spawn")
local stale = character()
player.Character = stale
player.CharacterAdded:Fire(stale)
check(player:GetAttribute("FishingWatersSpawnReady") == false, "Respawn must reset the placement handshake")
player.Character = character()
resumePlacement()
check(player:GetAttribute("FishingWatersSpawnReady") == false, "A stale character must never release a replacement character")
player.CharacterAdded:Fire(player.Character)
resumePlacement()
check(player:GetAttribute("FishingWatersSpawnReady") == true, "The replacement's own placement must release it")
print("Server spawn ${withBase ? 'base' : 'plaza'}: " .. checks .. " checks passed")
`);
  }
} finally {
  if (dirname(temporary) !== resolve(tmpdir())) throw new Error('Unexpected temporary directory');
  await rm(temporary, {recursive: true, force: true});
}

function run(name, source) {
  const path = join(temporary, name + '.luau');
  // All harness inputs come from repository source and fixed mocks.
  return writeFile(path, source).then(() => {
    const result = spawnSync(process.env.LUTE || 'lute', ['run', path], {
      cwd: root, encoding: 'utf8', timeout: 30000,
    });
    if (result.stdout) process.stdout.write(result.stdout);
    if (result.stderr) process.stderr.write(result.stderr);
    if (result.error) throw result.error;
    if (result.status !== 0) throw new Error('World startup regression failed: ' + name);
  });
}
