// Node + Lute recording-mock tests of the real server module. No Roblox runtime.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const lute = process.env.LUTE || 'lute';
const temporaryRoot = resolve(tmpdir());
const temporary = await mkdtemp(join(temporaryRoot, 'fishing-boats-'));
try {
  const anglerData = await readFile(join(root, 'src/server/AnglerData.luau'), 'utf8');
  const catalog = await readFile(join(root, 'src/shared/BoatCatalog.luau'), 'utf8');
  const rodUpgrades = await readFile(join(root, 'src/shared/RodUpgrades.luau'), 'utf8');
  const rodSkins = await readFile(join(root, 'src/shared/RodSkins.luau'), 'utf8');
  const bobberSkins = await readFile(join(root, 'src/shared/BobberSkins.luau'), 'utf8');
  const data = (await readFile(join(root, 'src/server/BoatData.luau'), 'utf8')).replace(
    'local AnglerData = if script then require(script.Parent.AnglerData) else require("./AnglerData")',
    `local AnglerData = (function()\n${anglerData}\nend)()`,
  ).replace(/local RodUpgrades = if script[\s\S]*?"\.\.\/shared\/RodUpgrades"\)/, () => `local RodUpgrades = (function()\n${rodUpgrades}\nend)()`)
    .replace(/local RodSkins = if script[\s\S]*?"\.\.\/shared\/RodSkins"\)/, () => `local RodSkins = (function()\n${rodSkins}\nend)()`)
    .replace(/local BobberSkins = if script[\s\S]*?"\.\.\/shared\/BobberSkins"\)/, () => `local BobberSkins = (function()\n${bobberSkins}\nend)()`)
    .replace(/local BoatCatalog = if script[\s\S]*?(?=\r?\n\r?\nBoatData\.PRICE)/, `local BoatCatalog = (function()\n${catalog}\nend)()`);
  let service = await readFile(join(root, 'src/server/BoatService.luau'), 'utf8');
  const rodSerialSource = (await readFile(join(root, 'src/server/RodSerials.luau'), 'utf8'))
    .replace('if script then require(script.Parent.BoatData) else require("./BoatData")', 'dependencies.BoatData');
  let harness = await readFile(join(root, 'scripts/boat-service.luau'), 'utf8');
  if (process.argv.includes('--crab-cages-only')) {
    const setupEnd = harness.indexOf('local function makePrompt');
    if (setupEnd < 0) throw new Error('Missing wallet setup hook');
    const cageService = await readFile(join(root, 'src/server/CrabCageService.luau'), 'utf8');
    const first = cageService.indexOf('local pendingRolls:');
    const last = cageService.indexOf('function CrabCageService.start()', first);
    if (first < 0 || last < 0) throw new Error('Missing crab collection hooks');
    harness = harness.slice(0, setupEnd)
      .replace('self.updates += 1', `self.updates += 1
        if self.emptyResult then return nil end`)
      + (await readFile(join(root, 'scripts/crab-cage-persistence.luau'), 'utf8'))
        .replace('-- GRID_SOURCE --', await readFile(join(root, 'src/shared/Cargo.luau'), 'utf8'))
        .replace('-- CATALOG_SOURCE --', await readFile(join(root, 'src/shared/AnglerCatalog.luau'), 'utf8'))
        .replace('-- BACKPACK_SOURCE --', await readFile(join(root, 'src/shared/BackpackCatalog.luau'), 'utf8'))
        .replace('-- ANGLER_SOURCE --', anglerData.replace(/local Cargo\r?\n/, 'local Cargo = Grid\n'))
        .replace('-- CRAB_RULES_SOURCE --', await readFile(join(root, 'src/shared/CrabCages.luau'), 'utf8'))
        .replace('-- COLLECT_SOURCE --', cageService.slice(first, last));
  }
  if (process.argv.includes('--inventory-only')) {
    const setupEnd = harness.indexOf('local function makePrompt');
    const casesStart = harness.indexOf('-- Skin copies share the wallet transaction:');
    if (setupEnd < 0 || casesStart < 0) throw new Error('Missing inventory test hooks');
    const casesEnd = harness.indexOf('-- END_SKIN_INVENTORY_CHECKS --', casesStart);
    if (casesEnd < 0) throw new Error('Missing inventory test boundary');
    harness = harness.slice(0, setupEnd) + harness.slice(casesStart, casesEnd)
      + '\nprint("Skin persistence: " .. checks .. " wallet, retry and reload checks passed (recording mocks).")';
  }
  service = service
    .replace('require(script.Parent.RodSerials)', () => `(function()\n${rodSerialSource}\nend)()`)
    .replace(/require\(script.Parent.AdminCommands\)/, '{ start = function() end }')
    .replace(/local BoatData = require\(script.Parent.BoatData\)/, 'local BoatData = dependencies.BoatData')
    .replace(/local Rowboat = require\(script.Parent.Rowboat\)/, 'local Rowboat = dependencies.Rowboat')
    .replace(/local FishingBoat = require\(script.Parent.FishingBoat\)/, 'local FishingBoat = dependencies.FishingBoat')
    .replace(/local Speedboat = require\(script.Parent.Speedboat\)/, 'local Speedboat = dependencies.Speedboat')
    .replace(/local RacingSpeedboat = require\(script.Parent.RacingSpeedboat\)/, 'local RacingSpeedboat = dependencies.RacingSpeedboat')
    .replace(/local PatrolBoat = require\(script.Parent.PatrolBoat\)/, 'local PatrolBoat = dependencies.PatrolBoat')
    .replace(/local Trawler = require\(script.Parent.Trawler\)/, 'local Trawler = dependencies.Trawler')
    .replace(/local DrydockLaunch = require\(script.Parent.DrydockLaunch\)/, 'local DrydockLaunch = dependencies.DrydockLaunch')
    .replace(/local BoatLaunchCollision = require\(script.Parent.BoatLaunchCollision\)/, 'local BoatLaunchCollision = dependencies.BoatLaunchCollision')
    .replace(/local BoatCatalog = require\(ReplicatedStorage.Shared.BoatCatalog\)/, 'local BoatCatalog = dependencies.BoatCatalog')
    .replace(/local BoatMotion = require\(ReplicatedStorage.Shared.BoatMotion\)/, `local BoatMotion = (function()\n${await readFile(join(root, 'src/shared/BoatMotion.luau'), 'utf8')}\nend)()`)
    .replace(/local RodUpgrades = require\(ReplicatedStorage.Shared.RodUpgrades\)/, () => `local RodUpgrades = (function()\n${rodUpgrades}\nend)()`)
    .replace(/local RodSkins = require\(ReplicatedStorage.Shared.RodSkins\)/, () => `local RodSkins = (function()\n${rodSkins}\nend)()`)
    .replace(/local BobberSkins = require\(ReplicatedStorage.Shared.BobberSkins\)/, () => `local BobberSkins = (function()\n${bobberSkins}\nend)()`)
    .replace(/local Biomes = require\(ReplicatedStorage.Shared.Biomes\)/, 'local Biomes = dependencies.Biomes')
    .replace(/local Weather = require\(ReplicatedStorage.Shared.Weather\)/, 'local Weather = dependencies.Weather');
  if (process.argv.includes('--inventory-only')) {
    // Boat rendering is outside these wallet tests; allow new builders in the shared workspace.
    const builders = service.match(/local builders = ([^\n]+)/)?.[1] || '';
    const builderNames = new Set(builders.match(/[A-Za-z_]\w*/g));
    service = service.replace(/local (\w+) = require\(script.Parent.(\w+)\)/g,
      (source, name) => builderNames.has(name) ? 'local ' + name + ' = {}' : source);
  }
  if (!/return BoatService\s*$/.test(service)) throw new Error('BoatService return hook changed');
  service = service.replace(/return BoatService\s*$/, `return {
    start = BoatService.start, loadPlayer = loadPlayer, nearPrompt = nearPrompt,
    shopPrompt = shopPrompt, purchase = purchase, spawnBoat = spawnBoat,
    getProfile = BoatService.getProfile, updateProgress = BoatService.updateProgress,
    profiles = profiles, active = active,
  }`);
  const program = harness
    .replace('-- BOAT_LAUNCH_COLLISION_SOURCE --', await readFile(join(root, 'src/server/BoatLaunchCollision.luau'), 'utf8'))
    .replace('-- BOAT_CATALOG_SOURCE --', await readFile(join(root, 'src/shared/BoatCatalog.luau'), 'utf8'))
    .replace('-- BOAT_DATA_SOURCE --', data)
    .replace('-- BOAT_SERVICE_SOURCE --', service);
  const target = join(temporary, 'boat-service.luau');
  await writeFile(target, program);
  const checks = process.argv.includes('--crab-cages-only') ? [['run', target]] : process.argv.includes('--inventory-only')
    ? [['run', 'scripts/boat-data.luau'], ['run', target]]
    : [['run', 'scripts/boat-data.luau'], ['run', 'scripts/boat-motion.luau'], ['run', target]];
  for (const args of checks) {
    const result = spawnSync(lute, args, { cwd: root, encoding: 'utf8', timeout: 30000 });
    if (result.stdout) process.stdout.write(result.stdout);
    if (result.stderr) process.stderr.write(result.stderr);
    if (result.error) throw result.error;
    if (result.status !== 0) throw new Error(`Boat checks failed (Lute exit ${result.status})`);
  }
} finally {
  if (dirname(resolve(temporary)) !== temporaryRoot) throw new Error('Unexpected temporary directory');
  await rm(temporary, { recursive: true, force: true });
}
