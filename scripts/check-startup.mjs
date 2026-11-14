// Reproduce unpublished DataStore initialization and a client blocked on streamed LOD.
// Executes production Luau against recording mocks; no Roblox runtime.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { patchHarnessRequires } from './harness-requires.mjs';
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
  const saveData = await readFile(join(root, 'src/server/SaveData.luau'), 'utf8');
  const companyProfile = (await readFile(join(root, 'src/server/CompanyProfile.luau'), 'utf8'))
    .replace('if script then require(script.Parent.BoatData) else require("./BoatData")', 'dependencies.BoatData');
  const prices = await readFile(join(root, 'src/server/StockPrices.luau'), 'utf8');
  const boatFurniture = await readFile(join(root, 'src/shared/BoatFurniture.luau'), 'utf8');
  const worth = (await readFile(join(root, 'src/server/CompanyWorth.luau'), 'utf8'))
    .replace('require("../shared/BoatFurniture")', () => `(function()\nlocal Color3 = {fromRGB=function(...) return {...} end}\n${boatFurniture}\nend)()`)
    .replace('require("./StockPrices")', () => `(function()\n${prices}\nend)()`);
  const saves = (await readFile(join(root, 'src/server/SaveService.luau'), 'utf8'))
    .replace('require(script.Parent.SaveData)', 'dependencies.SaveData')
    .replace('require(script.Parent.BoatData)', 'dependencies.BoatData')
    .replace('require(script.Parent.RodSerials)', 'dependencies.RodSerials')
    .replace('require(script.Parent.CompanyWorth)', 'dependencies.CompanyWorth');
  const support = `
game.GameId, game.PlaceId, game.PrivateServerId, game.PrivateServerOwnerId = 123, 456, "", 0
services.TextService = {FilterStringAsync=function(_, name)
  return {GetNonChatStringForBroadcastAsync=function() return name end}
end}
local guid = 0
services.HttpService = {GenerateGUID=function() guid += 1; return "startup-server-" .. guid end}
services.TeleportService = {TeleportInitFailed=signal(), TeleportAsync=function() end}
function Players:GetFriendsAsync() return {IsFinished=true, GetCurrentPage=function() return {} end} end
function methods:GetJoinData() return {} end
function methods:IsFriendsWithAsync() return false end
task.spawn = function(callback, ...)
  local thread = coroutine.create(callback)
  local ok, failure = coroutine.resume(thread, ...)
  assert(ok, failure)
  return thread
end
task.wait = coroutine.yield
dependencies.SaveData = (function()\n${saveData}\nend)()
dependencies.CompanyProfile = (function()\n${companyProfile}\nend)()
dependencies.CompanyWorth = (function()\n${worth}\nend)()
dependencies.RodSerials = (function()\n${rodSerials}\nend)()
dependencies.SaveService = (function()\n${saves}\nend)()
dependencies.CompanyLeaderboardService = { configure = function() end }
`;
  const source = (await readFile(join(root, 'src/server/BoatService.luau'), 'utf8'))
    .replace('require(script.Parent.AdminCommands)', '{ start = function() end }')
    .replace('require(script.Parent.BoatData)', 'dependencies.BoatData')
    .replace('require(script.Parent.SaveData)', 'dependencies.SaveData')
    .replace('require(script.Parent.CompanyWorth)', 'dependencies.CompanyWorth')
    .replace('require(script.Parent.CompanyProfile)', 'dependencies.CompanyProfile')
    .replace('require(script.Parent.SaveService)', 'dependencies.SaveService')
    .replace('require(script.Parent.CompanyLeaderboardService)', 'dependencies.CompanyLeaderboardService')
    .replace('require(script.Parent.AnglerData)', () => `(function()\n${anglerData}\nend)()`)
    .replace('require(script.Parent.RodSerials)', () => `(function()\n${rodSerials}\nend)()`)
    .replace('require(script.Parent.Rowboat)', 'dependencies.Rowboat')
    .replace('require(script.Parent.FishingBoat)', 'dependencies.FishingBoat')
    .replace('require(script.Parent.Speedboat)', 'dependencies.Speedboat')
    .replace('require(script.Parent.PatrolBoat)', 'dependencies.PatrolBoat')
    .replace('require(script.Parent.RacingSpeedboat)', 'dependencies.RacingSpeedboat')
    .replace('require(script.Parent.Trawler)', 'dependencies.Trawler')
    .replace('require(script.Parent.Tugboat)', 'dependencies.Tugboat')
    .replace('require(script.Parent.Hovercraft)', 'dependencies.Hovercraft')
    .replace('require(script.Parent.SmallFerry)', 'dependencies.SmallFerry')
    .replace('require(script.Parent.DrydockLaunch)', 'dependencies.DrydockLaunch')
    .replace('require(script.Parent.BoatLaunchCollision)', 'dependencies.BoatLaunchCollision')
    .replace('require(ReplicatedStorage.Shared.BoatCatalog)', 'dependencies.BoatCatalog')
    .replace('require(ReplicatedStorage.Shared.AnglerCatalog)', 'dependencies.AnglerCatalog')
    .replace('require(ReplicatedStorage.Shared.BoatMotion)', `(function()\n${motion}\nend)()`)
    .replace('require(ReplicatedStorage.Shared.RodUpgrades)', () => `(function()\n${rodUpgrades}\nend)()`)
    .replace('require(ReplicatedStorage.Shared.RodSkins)', () => `(function()\n${rodSkins}\nend)()`)
    .replace('require(ReplicatedStorage.Shared.SpearSkins)', () => `(function()\n${spearSkins}\nend)()`)
    .replace('require(ReplicatedStorage.Shared.BobberSkins)', () => `(function()\n${bobberSkins}\nend)()`)
    .replace('require(ReplicatedStorage.Shared.Biomes)', 'dependencies.Biomes')
    .replace('require(ReplicatedStorage.Shared.Weather)', 'dependencies.Weather')
    .replace('require(ReplicatedStorage.Shared.BoatDrive)', () => `(function()\n${boatDrive}\nend)()`)
    .replace(/return BoatService\s*$/, 'return { start = BoatService.start, loadPlayer = loadPlayer, getProfile = BoatService.getProfile, updateProgress = BoatService.updateProgress }');
  const fixture = harness.slice(0, harness.indexOf('local shop = Instance.new("Model")'));
  for (const mode of ['unpublished', 'published', 'live', 'loading', 'plot-migration']) {
    const setup = support + 'game.GameId = ' + (mode === 'unpublished' ? '0' : '123') + '\n'
      + (mode === 'live' ? 'RunService.IsStudio = function() return false end\n' : '')
      + 'local storeRequests = 0\nDataStoreService.GetDataStore = function() storeRequests += 1; '
      + (['loading', 'plot-migration'].includes(mode) ? 'return store' : 'error("DataStore unavailable")') + ' end\n';
    const assertions = mode === 'unpublished' ? `
Service.start()
local player = startupPlayer(72)
check(storeRequests == 0, "Unpublished Studio must not request a DataStore")
check(player:GetAttribute("BoatDataStatus") == "Selecting" and player:GetAttribute("SaveSelectionRequired"), "New arrivals must choose a save before progress becomes playable")
check(player:GetAttribute("WalletSessionOnly") == true, "Session data must be labeled")
check(ReplicatedStorage:FindFirstChild("Boating") ~= nil, "Wallet startup must create its remotes")
check(not Service.getProfile(player) and not player:GetAttribute("OwnsStarterRod") and not player:GetAttribute("OwnsRowboat"), "Selection must not expose unconfirmed inventory")
local remote = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("SaveRequest")
local created = remote.OnServerInvoke(player, "Create", {Slot=1, Name="Studio Company", Multiplayer=false})
check(created.Ok and #created.Slots == 3, "Studio can create a save using the real selector service")
now += 1
local selected = remote.OnServerInvoke(player, "Select", {OwnerUserId=72, Slot=1})
check(selected.Ok and player:GetAttribute("BoatDataStatus") == "Ready", "Choosing a created Studio save loads playable progress")
check(player:GetAttribute("OwnsStarterRod") and player:GetAttribute("OwnsRowboat") and player:GetAttribute("Cash") == 0, "Starting inventory includes a rod and boat without cash")
Players.PlayerRemoving:Fire(player)
player.Parent = nil
local rejoined = startupPlayer(72)
check(rejoined:GetAttribute("BoatDataStatus") == "Selecting", "Rejoining opens the save selector again")
local continued = remote.OnServerInvoke(rejoined, "Select", {OwnerUserId=72, Slot=1})
check(continued.Ok and rejoined:GetAttribute("OwnsStarterRod") and rejoined:GetAttribute("OwnsRowboat"), "Session ownership must survive selecting the same save after rejoining")
` : mode === 'plot-migration' ? `
local function clone(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, child in value do result[key] = clone(child) end
  return result
end
local function same(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for key, value in a do if not same(value, b[key]) then return false end end
  for key in b do if a[key] == nil then return false end end
  return true
end
local function withoutSaveInfo(profile)
  local result = clone(profile)
  result.SaveInfo = nil
  return result
end
local function oldPlot()
  local profile = dependencies.BoatData.decode(nil)
  profile.Cash = 4321
  profile.OwnedBoats.FishingBoat = true
  profile.Angler.CompanyIsland, profile.Angler.CompanyKit = 4, 1
  profile.Angler.ShopSign = "Old Harbour Fish"
  profile.Angler.Building = {
    Home = {
      NextId = 12,
      Pieces = {{Id="p7", Kind="Wall", X1=-9, Z1=0, X2=9, Z2=0, Level=0, Material="Brick", Color={90,110,130}}},
      Overrides = {["b:Shell/Wall"]={Removed=true}, ["b:Shell/Roof"]={Material="Slate", Color={65,75,85}}},
    },
    Company = {
      NextId = 5,
      Pieces = {{Id="p4", Kind="Floor", X1=-9, Z1=-9, X2=9, Z2=9, Level=1, Material="WoodPlanks", Color={160,140,120}}},
      Overrides = {["b:Company/Wall"]={Removed=true}},
    },
  }
  table.insert(profile.Angler.Furniture, {ItemId="StorageRack", X=-18, Z=-27, R=1, Mode="Tools", Cages=2, Nets=1})
  profile.Angler.CompanyFurniture = {{ItemId="StorageRack", X=9, Z=18, R=3}, {ItemId="CompanyDesk", X=-18, Z=-9, R=2}}
  profile.Angler.FurnitureStock.StorageRack = 3
  profile.Angler.FurnitureStock.CompanyDesk = 1
  -- Normalize pre-existing game schema migrations before taking the saved
  -- snapshot, so this specifically detects changes introduced by save slots.
  profile = dependencies.BoatData.decode(profile)
  profile.PlotMigrationSentinel = {KeepUnknownFields=true, Version=17}
  return profile
end
Service.start()
local remote = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("SaveRequest")
local legacy = oldPlot()
local original = clone(legacy)
store.data.Player_75 = legacy
local owner = startupPlayer(75)
local listed = remote.OnServerInvoke(owner, "List")
check(listed.Ok and listed.Slots[1].Exists, "Existing plot appears as an occupied first save")
check(listed.Slots[1].Name == "Existing plot", "Existing plot is clearly identified in the selector")
check(not listed.Slots[2].Exists and not listed.Slots[3].Exists, "Migrating a plot reserves only its original first slot")
check(store.data.Player_75.SaveInfo and store.data.Player_75.SaveInfo.OwnerUserId == 75 and store.data.Player_75.SaveInfo.Slot == 1, "Listing registers the current plot as a durable creator-owned save")
check(same(withoutSaveInfo(store.data.Player_75), original), "Migration only adds save metadata and preserves all stored plot/profile fields")
check(not Service.getProfile(owner), "Registering a current plot does not start gameplay before selection")
now += 1
check(remote.OnServerInvoke(owner, "Create", {Slot=2, Name="Second plot", Multiplayer=false}).Ok, "Owner can create a second plot beside the migrated first plot")
check(same(withoutSaveInfo(store.data.Player_75), original), "Creating another slot cannot overwrite the current plot")
check(store.data.Player_75_Slot_2.SaveInfo.Slot == 2 and store.data.Player_75_Slot_2.Angler.Building == nil, "New slot has independent plot data")
local migratedInfo = clone(store.data.Player_75.SaveInfo)
now += 1
check(remote.OnServerInvoke(owner, "List").Ok and same(store.data.Player_75.SaveInfo, migratedInfo), "Repeated listing does not rewrite migrated save identity/settings")
Players.PlayerRemoving:Fire(owner)
owner.Parent = nil
local returning = startupPlayer(75)
now += 1
check(remote.OnServerInvoke(returning, "Select", {OwnerUserId=75, Slot=1}).Ok, "Existing plot can be selected after disconnecting and rejoining")
local loaded = Service.getProfile(returning)
check(loaded and same(loaded.Angler.Building, original.Angler.Building), "Rejoining restores custom home/company pieces, stable IDs, shell overrides and finishes")
check(same(loaded.Angler.Furniture, original.Angler.Furniture), "Rejoining restores current home furniture positions, rotations and rack contents")
check(same(loaded.Angler.CompanyFurniture, original.Angler.CompanyFurniture), "Rejoining restores current company furniture positions and rotations")
check(same(loaded.Angler.FurnitureStock, original.Angler.FurnitureStock), "Rejoining restores unplaced furniture stock")
check(loaded.Angler.CompanyIsland == 4 and loaded.Angler.ShopSign == original.Angler.ShopSign, "Rejoining keeps company island entitlement and shop sign")
check(loaded.Cash == 4321 and loaded.OwnedBoats.FishingBoat and loaded.PlotMigrationSentinel.KeepUnknownFields, "Plot migration keeps money, boats and unknown compatible profile fields")

-- The record may change after the selector read but before the metadata
-- transaction starts. Migration must use the latest record in UpdateAsync.
store.data.Player_76 = oldPlot()
local concurrent = startupPlayer(76)
local latest
store.beforeUpdate = function(key)
  if key ~= "Player_76" then return end
  store.beforeUpdate = nil
  store.data.Player_76.Cash = 9876
  store.data.Player_76.Angler.Building.Home.Pieces[1].Color = {20,30,40}
  store.data.Player_76.Angler.CompanyFurniture[1].R = 2
  latest = clone(store.data.Player_76)
end
now += 1
check(remote.OnServerInvoke(concurrent, "List").Ok, "A concurrent legacy plot update still registers successfully")
check(latest and same(withoutSaveInfo(store.data.Player_76), latest), "Migration commits the latest saved plot and wallet instead of a stale read")

store.data.Player_77 = oldPlot()
local protected = clone(store.data.Player_77)
local retrying = startupPlayer(77)
store.updateFailures = 1
now += 1
check(not remote.OnServerInvoke(retrying, "List").Ok, "An unconfirmed migration is reported as a retryable save error")
check(same(store.data.Player_77, protected) and store.data.Player_77_Slot_2 == nil, "Migration failure leaves the original plot intact and never creates a blank replacement")
now += 1
check(remote.OnServerInvoke(retrying, "List").Ok and store.data.Player_77.SaveInfo ~= nil, "The preserved plot can be registered on retry")
check(same(withoutSaveInfo(store.data.Player_77), protected), "Retry preserves the same existing plot contents")
` : mode === 'loading' ? `
Service.start()
local player = startupPlayer(74)
store.data.Player_74 = dependencies.BoatData.decode(nil)
local remote = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("SaveRequest")
local originalGet = store.GetAsync
store.GetAsync = function(self, key) coroutine.yield(); return originalGet(self, key) end
-- A creator's selection reads through its UpdateAsync transaction, so that yields too.
local originalUpdate = store.UpdateAsync
store.UpdateAsync = function(self, ...) coroutine.yield(); return originalUpdate(self, ...) end
local response
local thread = coroutine.create(function() response = remote.OnServerInvoke(player, "Select", {OwnerUserId=74, Slot=1}) end)
check(coroutine.resume(thread), "Selection load starts successfully")
check(player:GetAttribute("BoatDataStatus") == "Selecting", "Player remains behind save selection while saved data yields")
check(not player:GetAttribute("OwnsStarterRod") and not player:GetAttribute("OwnsRowboat"), "Loading must not publish unconfirmed starter ownership")
check(not Service.getProfile(player), "Gameplay cannot read a profile while a save load is pending")
for _ = 1, 10 do if coroutine.status(thread) == "suspended" then check(coroutine.resume(thread), "Pending saved-data request resumes") end end
check(response and response.Ok, "Confirmed saved-data selection succeeds")
check(player:GetAttribute("BoatDataStatus") == "Ready" and player:GetAttribute("OwnsStarterRod") and player:GetAttribute("OwnsRowboat"), "Confirmed selected profiles publish starter ownership")
` : `
Service.start()
local player = startupPlayer(73)
check(storeRequests == 1, "Saved mode must attempt to initialize the real store")
check(player:GetAttribute("BoatDataStatus") == "Selecting", "Storage failures keep the selector available for retry")
check(player:GetAttribute("WalletSessionOnly") == false, "Store failures must not fall back to temporary progress")
check(ReplicatedStorage:FindFirstChild("Boating") ~= nil, "Store initialization failure must not abort service startup")
check(not player:GetAttribute("OwnsStarterRod") and not player:GetAttribute("OwnsRowboat"), "Failed saved storage must never grant ownership")
local remote = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("SaveRequest")
local response = remote.OnServerInvoke(player, "List")
check(response.Ok == false and type(response.Message) == "string", "Storage initialization errors are actionable in the selector")
check(not Service.getProfile(player), "Failed saved storage keeps gameplay transactions unavailable")
`;
    const program = fixture.replace('local Service = (function()', setup + 'local Service = (function()')
      .replace('-- BOAT_LAUNCH_COLLISION_SOURCE --', await readFile(join(root, 'src/server/BoatLaunchCollision.luau'), 'utf8'))
      .replace('-- BOAT_CATALOG_SOURCE --', await readFile(join(root, 'src/shared/BoatCatalog.luau'), 'utf8'))
      .replace('-- BOAT_DATA_SOURCE --', data).replace('-- BOAT_SERVICE_SOURCE --', source)
      + `\nlocal function startupPlayer(id)
  local player = Instance.new("Player")
  player.UserId, player.Name, player.DisplayName, player.Parent = id, "StartupAngler", "Startup Angler", Players
  table.insert(playerList, player)
  Players.PlayerAdded:Fire(player)
  return player
end\n` + assertions + '\nprint("Wallet startup ' + mode + ': " .. checks .. " checks passed")';
    const path = join(temporary, mode + '.luau');
    await writeFile(path, patchHarnessRequires(program, temporary));
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
assert(started.SaveSelection and started.Fishing and started.Boating and started.RodPhysics, "LOD wait must not block save selection or shop/equipment startup")
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
  for (const failedModule of ['SaveSelection', 'Boating', 'Fishing', 'Oxygen', 'RodPhysics', 'PlayerMenu', 'Weather', 'BoatAudio']) {
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
