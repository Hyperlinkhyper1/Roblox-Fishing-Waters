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
  const data = (await readFile(join(root, 'src/server/BoatData.luau'), 'utf8')).replace(
    'local AnglerData = if script then require(script.Parent.AnglerData) else require("./AnglerData")',
    `local AnglerData = (function()\n${anglerData}\nend)()`,
  ).replace(/local RodUpgrades = if script[\s\S]*?"\.\.\/shared\/RodUpgrades"\)/, () => `local RodUpgrades = (function()\n${rodUpgrades}\nend)()`)
    .replace(/local BoatCatalog = if script[\s\S]*?(?=\r?\n\r?\nBoatData\.PRICE)/, `local BoatCatalog = (function()\n${catalog}\nend)()`);
  let service = await readFile(join(root, 'src/server/BoatService.luau'), 'utf8');
  const harness = await readFile(join(root, 'scripts/boat-service.luau'), 'utf8');
  service = service
    .replace(/require\(script.Parent.AdminCommands\)/, '{ start = function() end }')
    .replace(/local BoatData = require\(script.Parent.BoatData\)/, 'local BoatData = dependencies.BoatData')
    .replace(/local Rowboat = require\(script.Parent.Rowboat\)/, 'local Rowboat = dependencies.Rowboat')
    .replace(/local FishingBoat = require\(script.Parent.FishingBoat\)/, 'local FishingBoat = dependencies.FishingBoat')
    .replace(/local DrydockLaunch = require\(script.Parent.DrydockLaunch\)/, 'local DrydockLaunch = dependencies.DrydockLaunch')
    .replace(/local BoatLaunchCollision = require\(script.Parent.BoatLaunchCollision\)/, 'local BoatLaunchCollision = dependencies.BoatLaunchCollision')
    .replace(/local BoatCatalog = require\(ReplicatedStorage.Shared.BoatCatalog\)/, 'local BoatCatalog = dependencies.BoatCatalog')
    .replace(/local BoatMotion = require\(ReplicatedStorage.Shared.BoatMotion\)/, `local BoatMotion = (function()\n${await readFile(join(root, 'src/shared/BoatMotion.luau'), 'utf8')}\nend)()`)
    .replace(/local RodUpgrades = require\(ReplicatedStorage.Shared.RodUpgrades\)/, () => `local RodUpgrades = (function()\n${rodUpgrades}\nend)()`)
    .replace(/local Biomes = require\(ReplicatedStorage.Shared.Biomes\)/, 'local Biomes = dependencies.Biomes')
    .replace(/local Weather = require\(ReplicatedStorage.Shared.Weather\)/, 'local Weather = dependencies.Weather');
  if (!/return BoatService\s*$/.test(service)) throw new Error('BoatService return hook changed');
  service = service.replace(/return BoatService\s*$/, `return {
    start = BoatService.start, loadPlayer = loadPlayer, nearPrompt = nearPrompt,
    shopPrompt = shopPrompt, purchase = purchase, spawnBoat = spawnBoat,
    purchaseRod = BoatService.purchaseRod,
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
  for (const args of [['run', 'scripts/boat-data.luau'], ['run', 'scripts/boat-motion.luau'], ['run', target]]) {
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
