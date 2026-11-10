// Reproduce unpublished DataStore initialization and a client blocked on streamed LOD.
// Executes production Luau against recording mocks; no Roblox runtime.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const temporary = await mkdtemp(join(tmpdir(), 'fishing-startup-'));
try {
  const anglerData = await readFile(join(root, 'src/server/AnglerData.luau'), 'utf8');
  const catalog = await readFile(join(root, 'src/shared/BoatCatalog.luau'), 'utf8');
  const motion = await readFile(join(root, 'src/shared/BoatMotion.luau'), 'utf8');
  // BoatDrive borrows Biomes, BoatMotion and Weather from BoatService's own locals.
  const boatDrive = (await readFile(join(root, 'src/shared/BoatDrive.luau'), 'utf8')).replace(/^local \w+ = require\(script\.Parent\.\w+\)\r?\n/gm, '');
  const rodUpgrades = await readFile(join(root, 'src/shared/RodUpgrades.luau'), 'utf8');
  const rodSkins = await readFile(join(root, 'src/shared/RodSkins.luau'), 'utf8');
  const spearSkins = await readFile(join(root, 'src/shared/SpearSkins.luau'), 'utf8');
  const bobberSkins = await readFile(join(root, 'src/shared/BobberSkins.luau'), 'utf8');
  const baitSource = await readFile(join(root, 'src/shared/Bait.luau'), 'utf8');
  const data = (await readFile(join(root, 'src/server/BoatData.luau'), 'utf8')).replace(
    'local AnglerData = if script then require(script.Parent.AnglerData) else require("./AnglerData")',
    `local AnglerData = (function()\n${anglerData}\nend)()`,
  ).replace(/local RodUpgrades = if script[\s\S]*?"\.\.\/shared\/RodUpgrades"\)/, () => `local RodUpgrades = (function()\n${rodUpgrades}\nend)()`)
    .replace(/local RodSkins = if script[\s\S]*?"\.\.\/shared\/RodSkins"\)/, () => `local RodSkins = (function()\n${rodSkins}\nend)()`)
    .replace(/local SpearSkins = if script[\s\S]*?"\.\.\/shared\/SpearSkins"\)/, () => `local SpearSkins = (function()\n${spearSkins}\nend)()`)
    .replace(/local BobberSkins = if script[\s\S]*?"\.\.\/shared\/BobberSkins"\)/, () => `local BobberSkins = (function()\n${bobberSkins}\nend)()`)
    .replace(/local Bait = if script[\s\S]*?"\.\.\/shared\/Bait"\)/, () => `local Bait = (function()\n${baitSource}\nend)()`)
    .replace(/local BoatCatalog = if script[\s\S]*?(?=\r?\n\r?\nBoatData\.PRICE)/, `local BoatCatalog = (function()\n${catalog}\nend)()`);
  const harness = await readFile(join(root, 'scripts/boat-service.luau'), 'utf8');
  const rodSerials = (await readFile(join(root, 'src/server/RodSerials.luau'), 'utf8'))
    .replace('if script then require(script.Parent.BoatData) else require("./BoatData")', 'dependencies.BoatData');
  const source = (await readFile(join(root, 'src/server/BoatService.luau'), 'utf8'))
    .replace('require(script.Parent.AdminCommands)', '{ start = function() end }')
    .replace('require(script.Parent.BoatData)', 'dependencies.BoatData')
    .replace('require(script.Parent.RodSerials)', () => `(function()\n${rodSerials}\nend)()`)
    .replace('require(script.Parent.Rowboat)', 'dependencies.Rowboat')
    .replace('require(script.Parent.FishingBoat)', 'dependencies.FishingBoat')
    .replace('require(script.Parent.Speedboat)', 'dependencies.Speedboat')
    .replace('require(script.Parent.PatrolBoat)', 'dependencies.PatrolBoat')
    .replace('require(script.Parent.RacingSpeedboat)', 'dependencies.RacingSpeedboat')
    .replace('require(script.Parent.Trawler)', 'dependencies.Trawler')
    .replace('require(script.Parent.Tugboat)', 'dependencies.Tugboat')
    .replace('require(script.Parent.Hovercraft)', 'dependencies.Hovercraft')
    .replace('require(script.Parent.DrydockLaunch)', 'dependencies.DrydockLaunch')
    .replace('require(script.Parent.BoatLaunchCollision)', 'dependencies.BoatLaunchCollision')
    .replace('require(ReplicatedStorage.Shared.BoatCatalog)', 'dependencies.BoatCatalog')
    .replace('require(ReplicatedStorage.Shared.BoatMotion)', `(function()\n${motion}\nend)()`)
    .replace('require(ReplicatedStorage.Shared.RodUpgrades)', () => `(function()\n${rodUpgrades}\nend)()`)
    .replace('require(ReplicatedStorage.Shared.RodSkins)', () => `(function()\n${rodSkins}\nend)()`)
    .replace('require(ReplicatedStorage.Shared.SpearSkins)', () => `(function()\n${spearSkins}\nend)()`)
    .replace('require(ReplicatedStorage.Shared.BobberSkins)', () => `(function()\n${bobberSkins}\nend)()`)
    .replace('require(ReplicatedStorage.Shared.Biomes)', 'dependencies.Biomes')
    .replace('require(ReplicatedStorage.Shared.Weather)', 'dependencies.Weather')
    .replace('require(ReplicatedStorage.Shared.BoatDrive)', () => `(function()\n${boatDrive}\nend)()`)
    .replace(/return BoatService\s*$/, 'return { start = BoatService.start, loadPlayer = loadPlayer }');
  const fixture = harness.slice(0, harness.indexOf('local shop = Instance.new("Model")'));
  for (const mode of ['unpublished', 'published', 'live', 'loading']) {
    const setup = 'game.GameId = ' + (mode === 'unpublished' ? '0' : '123') + '\n'
      + (mode === 'live' ? 'RunService.IsStudio = function() return false end\n' : '')
      + 'local storeRequests = 0\nDataStoreService.GetDataStore = function() storeRequests += 1; '
      + (mode === 'loading' ? 'return store' : 'error("DataStore unavailable")') + ' end\n';
    const assertions = mode === 'unpublished' ? `
Service.start()
local player = makePlayer(72)
check(storeRequests == 0, "Unpublished Studio must not request a DataStore")
check(player:GetAttribute("BoatDataStatus") == "Ready", "Studio session wallet must become usable")
check(player:GetAttribute("WalletSessionOnly") == true, "Session data must be labeled")
check(ReplicatedStorage:FindFirstChild("Boating") ~= nil, "Wallet startup must create its remotes")
check(player:GetAttribute("OwnsStarterRod") and player:GetAttribute("OwnsRowboat") and player:GetAttribute("Cash") == 0, "Starting inventory includes a rod and boat without cash")
Players.PlayerRemoving:Fire(player)
local rejoined = makePlayer(72)
check(rejoined:GetAttribute("OwnsStarterRod") and rejoined:GetAttribute("OwnsRowboat"), "Session ownership must survive rejoining this server")
` : mode === 'loading' ? `
Service.start()
local player = Instance.new("Player")
player.UserId, player.Parent = 74, Players
store.GetAsync = function() coroutine.yield(); return nil end
local thread = coroutine.create(function() Service.loadPlayer(player) end)
check(coroutine.resume(thread), "Loading starts successfully")
check(player:GetAttribute("BoatDataStatus") == "Loading", "Player remains loading while the store yields")
check(not player:GetAttribute("OwnsStarterRod") and not player:GetAttribute("OwnsRowboat"), "Loading must not publish unconfirmed starter ownership")
check(coroutine.resume(thread), "Loading finishes successfully")
check(player:GetAttribute("BoatDataStatus") == "Ready" and player:GetAttribute("OwnsStarterRod") and player:GetAttribute("OwnsRowboat"), "Confirmed new profiles publish starter ownership")
` : `
Service.start()
local player = makePlayer(73)
check(storeRequests == 1, "Saved mode must attempt to initialize the real store")
check(player:GetAttribute("BoatDataStatus") == "Unavailable", "Store failure must disable saved transactions")
check(player:GetAttribute("WalletSessionOnly") == false, "Store failures must not fall back to temporary progress")
check(ReplicatedStorage:FindFirstChild("Boating") ~= nil, "Store initialization failure must not abort service startup")
check(not player:GetAttribute("OwnsStarterRod") and not player:GetAttribute("OwnsRowboat"), "Failed saved storage must never grant ownership")
`;
    const program = fixture.replace('local Service = (function()', setup + 'local Service = (function()')
      .replace('-- BOAT_LAUNCH_COLLISION_SOURCE --', await readFile(join(root, 'src/server/BoatLaunchCollision.luau'), 'utf8'))
      .replace('-- BOAT_CATALOG_SOURCE --', await readFile(join(root, 'src/shared/BoatCatalog.luau'), 'utf8'))
      .replace('-- BOAT_DATA_SOURCE --', data).replace('-- BOAT_SERVICE_SOURCE --', source)
      + assertions + '\nprint("Wallet startup ' + mode + ': " .. checks .. " checks passed")';
    const path = join(temporary, mode + '.luau');
    await writeFile(path, program);
    run(path);
  }
  const client = await readFile(join(root, 'src/client/init.client.luau'), 'utf8');
  const program = `
local attributes, started, threads = {}, {}, {}
local player = {
  SetAttribute = function(_, key, value) attributes[key] = value end,
  GetAttribute = function(_, key) return attributes[key] end,
}
local game = {GetService = function() return {LocalPlayer = player} end}
local script = setmetatable({}, {__index = function(_, name) return name end})
local task = {spawn = function(callback)
  local thread = coroutine.create(callback)
  table.insert(threads, thread)
  assert(coroutine.resume(thread))
end, wait = function() coroutine.yield() end}
local require = function(name)
  return {start = function()
    if name == "Lod" then coroutine.yield() end
    started[name] = true
  end}
end
local warn = function(message) error(message) end
local function resumeAll()
  for _, thread in threads do
    if coroutine.status(thread) == "suspended" then assert(coroutine.resume(thread)) end
  end
end
` + client + `
assert(started.Fishing and started.Boating and started.RodPhysics, "LOD wait must not block shop/equipment startup")
assert(attributes.FishingWatersClientReady, "Optional LOD must not trap the loading screen")
-- Gameplay startup is paced across frames; let it finish
for _ = 1, 100 do resumeAll() end
assert(started.Weather and started.BuildMode and started.LightShadows, "Paced gameplay startup must finish while loading")
assert(not started.WaterWaves and not started.VolumetricClouds and not started.AmbientFish and not started.BackgroundMusic,
  "World animation must wait for the loading screen to lift")
assert(attributes.FishingWatersClientReady, "Delayed visual service must preserve client readiness")
attributes.FishingWatersLoadingSeconds = 4
for _ = 1, 100 do resumeAll() end
assert(started.WaterWaves and started.SwellSurface and started.VolumetricClouds and started.SupercellWeather
  and started.AmbientFish and started.Pedestrians and started.BackgroundMusic, "World animation must start once loading lifts")
print("Client startup: gear first, gameplay paced, world animation after the loading screen")
`;
  const path = join(temporary, 'client.luau');
  await writeFile(path, program);
  run(path);
  // A required module failure must surface to the loader; optional visuals may fail independently.
  for (const failedModule of ['Boating', 'Fishing', 'Oxygen', 'RodPhysics', 'PlayerMenu', 'Weather', 'BoatAudio']) {
    const critical = !['Weather', 'BoatAudio'].includes(failedModule);
    const failureProgram = `
local attributes, warnings = {FishingWatersLoadingSeconds = 1}, {}
local player = {
  SetAttribute = function(_, key, value) attributes[key] = value end,
  GetAttribute = function(_, key) return attributes[key] end,
}
local game = {GetService = function() return {LocalPlayer = player} end}
local script = setmetatable({}, {__index = function(_, name) return name end})
local task = {spawn = function(callback) callback() end, wait = function() end}
local require = function(name)
  if name == "${failedModule}" then error("fixture module unavailable") end
  return {start = function() end}
end
local warn = function(message) table.insert(warnings, message) end
` + client + `
assert(#warnings == 1, "Startup failure must be reported once")
assert(attributes.FishingWatersClientError == ${critical}, "Only required module failures should show gear failure")
assert(attributes.FishingWatersClientReady == ${!critical}, "Optional failure must preserve readiness; required failure must not claim success")
print("Client failure ${failedModule}: readiness and error reporting passed")
`;
    const failedPath = join(temporary, 'client-failure-' + failedModule + '.luau');
    await writeFile(failedPath, failureProgram);
    run(failedPath);
  }
  function run(path) {
    const result = spawnSync(process.env.LUTE || 'lute', ['run', path], {cwd: root, encoding: 'utf8', timeout: 30000});
    if (result.stdout) process.stdout.write(result.stdout);
    if (result.stderr) process.stderr.write(result.stderr);
    if (result.error) throw result.error;
    if (result.status !== 0) throw new Error('Startup regression failed: ' + path);
  }
} finally {
  if (dirname(temporary) !== resolve(tmpdir())) throw new Error('Unexpected temporary directory');
  await rm(temporary, {recursive: true, force: true});
}
