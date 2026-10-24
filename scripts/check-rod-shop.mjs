// Execute the production builders against plaza tackle shop geometry recording mocks.
// These checks do not run Roblox rendering, Humanoid movement, or physics.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const temporaryRoot = resolve(tmpdir());
const temporary = await mkdtemp(join(temporaryRoot, 'fishing-rod-shop-'));
const modules = {
  LOWPOLY: 'src/server/Map/LowPoly.luau',
  PROPS: 'src/server/Map/Props.luau',
  FISHFREEZERGEOMETRY: 'src/server/Map/FishFreezerGeometry.luau',
  FISHFREEZER: 'src/server/Map/FishFreezer.luau',
  IMPORTEDMODEL: 'src/server/Map/ImportedModel.luau',
  SHOPDESKGEOMETRY: 'src/server/Map/ShopDeskGeometry.luau',
  CASHREGISTERGEOMETRY: 'src/server/Map/CashRegisterGeometry.luau',
  SHOPDESK: 'src/server/Map/ShopDesk.luau',
  BASEHOUSE: 'src/server/Map/BaseHouse.luau',
  MEDITERRANEAN: 'src/server/Map/Mediterranean.luau',
  BEACHDETAILS: 'src/server/Map/BeachDetails.luau',
  ROWBOAT: 'src/server/Rowboat.luau',
  FISHINGBOAT: 'src/server/FishingBoat.luau',
  SHIPWRIGHT: 'src/server/Map/Shipwright.luau',
  DRYDOCKINTERIOR: 'src/server/Map/DrydockInterior.luau',
  DRYDOCK: 'src/server/Map/Drydock.luau',
  PLAZAHOUSES: 'src/server/Map/PlazaHouses.luau',
  RODSHOP: 'src/server/Map/RodShop.luau',
  STORAGERACK: 'src/server/Map/StorageRack.luau',
  FURNITURESHOP: 'src/server/Map/FurnitureShop.luau',
  HARBOUR: 'src/server/Map/Harbour.luau',
  BIOMES: 'src/shared/Biomes.luau',
};
try {
  const sharedHarness = await readFile(join(root, 'scripts/drydock-geometry.luau'), 'utf8');
  let program = sharedHarness.slice(0, sharedHarness.indexOf('-- Limit construction to the plaza'))
    + await readFile(join(root, 'scripts/rod-shop-geometry.luau'), 'utf8');
  const primitives = (await readFile(join(root, 'scripts/harbour-geometry.luau'), 'utf8')).split('local CFrame = {}')[0];
  program = program.replace('-- SHARED_PRIMITIVES --', () => primitives);
  for (const [name, path] of Object.entries(modules)) {
    let source = await readFile(join(root, path), 'utf8');
    source = source.replace(/local (\w+) = require\(script\.Parent\.(?:Parent\.)?(\w+)\)/g, 'local $1 = dependencies.$2');
    if (name === 'HARBOUR') {
      if (!/return Harbour\s*$/.test(source)) throw new Error('Harbour return hook changed');
      source = source.replace(/return Harbour\s*$/, `return {
        makeShape = makeShape, coastDistance = coastDistance, heightAt = heightAt,
        buildBase = buildBase, buildPlaza = buildPlaza, buildBeach = buildBeach,
        ensureBoating = Harbour.ensureBoating, ensureDocks = Harbour.ensureDocks,
      }`);
    }
    const marker = `-- ${name}_SOURCE --`;
    if (!program.includes(marker)) throw new Error(`Missing ${name} source marker`);
    program = program.replace(marker, () => source);
  }
  const target = join(temporary, 'geometry.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute.exe', ['run', target], {
    cwd: root, encoding: 'utf8', timeout: 30000,
  });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Tackle shop checks failed (Lute exit ${result.status})`);
} finally {
  if (dirname(resolve(temporary)) !== temporaryRoot) throw new Error('Unexpected temporary directory');
  await rm(temporary, { recursive: true, force: true });
}
