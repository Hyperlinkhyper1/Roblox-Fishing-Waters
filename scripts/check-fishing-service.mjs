// Recording mocks execute the real service's remote and lifecycle handlers.
// This checks authorization and inventory behavior, not Roblox physics/networking.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const lute = process.env.LUTE || 'lute';
const temporaryRoot = resolve(tmpdir());
const temporary = await mkdtemp(join(temporaryRoot, 'fishing-service-'));
try {
  let source = await readFile(join(root, 'src/server/FishingService.luau'), 'utf8');
  const harness = await readFile(join(root, 'scripts/fishing-service.luau'), 'utf8');
  const skinSources = {};
  for (const [name, location] of [['AnglerData', 'server'], ['RodUpgrades', 'shared'], ['RodSkins', 'shared'], ['BobberSkins', 'shared'], ['BoatCatalog', 'shared']]) {
    skinSources[name] = await readFile(join(root, 'src', location, name + '.luau'), 'utf8');
  }

  let skinData = await readFile(join(root, 'src/server/BoatData.luau'), 'utf8');
  skinData = skinData.replace('local AnglerData = if script then require(script.Parent.AnglerData) else require("./AnglerData")',
    () => `local AnglerData = (function()\n${skinSources.AnglerData}\nend)()`);
  for (const name of ['RodUpgrades', 'RodSkins', 'BobberSkins', 'BoatCatalog']) {
    const start = skinData.indexOf('local ' + name + ' = if script');
    const end = skinData.indexOf('\n', skinData.indexOf('else require(', start));
    if (start < 0 || end < 0) throw new Error('Missing data dependency: ' + name);
    skinData = skinData.slice(0, start) + `local ${name} = (function()\n${skinSources[name]}\nend)()` + skinData.slice(end);
  }

  for (const [hook, replacement] of [
    ['local BoatService = require(script.Parent.BoatService)', 'local BoatService = dependencies.BoatService'],
    ['local FishingRod = require(ReplicatedStorage.Shared.FishingRod)', 'local FishingRod = dependencies.FishingRod'],
    ['local BoatData = require(script.Parent.BoatData)', 'local BoatData = dependencies.BoatData'],
    ['local RodUpgrades = require(ReplicatedStorage.Shared.RodUpgrades)', 'local RodUpgrades = dependencies.RodUpgrades'],
    ['local RodSkins = require(ReplicatedStorage.Shared.RodSkins)', `local RodSkins = (function()\n${await readFile(join(root, 'src/shared/RodSkins.luau'), 'utf8')}\nend)()`],
    ['local BobberSkins = require(ReplicatedStorage.Shared.BobberSkins)', `local BobberSkins = (function()\n${skinSources.BobberSkins}\nend)()`],
    ['local CrabCages = require(ReplicatedStorage.Shared.CrabCages)', `local CrabCages = (function()\n${await readFile(join(root, 'src/shared/CrabCages.luau'), 'utf8')}\nend)()`],
  ]) {
    if (!source.includes(hook)) throw new Error(`FishingService dependency hook changed: ${hook}`);
    source = source.replace(hook, replacement);
  }
  if (!/return FishingService\s*$/.test(source)) throw new Error('FishingService return hook changed');
  const target = join(temporary, 'fishing-service.luau');
  await writeFile(target, harness.replace('-- FISHING_SERVICE_SOURCE --', source).replace('-- REAL_BOAT_DATA_SOURCE --', () => skinData));
  const result = spawnSync(lute, ['run', target], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Fishing service checks failed (Lute exit ${result.status})`);
} finally {
  if (dirname(resolve(temporary)) !== temporaryRoot) throw new Error('Unexpected temporary directory');
  await rm(temporary, { recursive: true, force: true });
}
