// Production inventory rules, transactions, remotes and UI with recording doubles.
// Run with LUTE pointing to Lute or Lune. This does not replace Studio rendering.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const read = async path => (await readFile(new URL('../' + path, import.meta.url), 'utf8')).replace(/\r\n/g, '\n');
const files = ['src/shared/Cargo.luau', 'src/shared/Inventory.luau', 'src/shared/BackpackCatalog.luau',
  'src/server/AnglerData.luau', 'src/server/CargoService.luau', 'src/client/CargoHold.luau'];
const sources = await Promise.all(files.map(read));
let harness = await read('scripts/inventory.luau');
const worker = await read('src/server/CustomerService.luau');
const workerStart = worker.indexOf('\tlocal function cargo(id: string)');
const workerEnd = worker.indexOf('\n\tlocal shelf = {}', workerStart);
if (workerStart < 0 || workerEnd < 0) throw new Error('Missing porter cargo selection');
harness = harness.replace('-- WORKER_CARGO_SOURCE --', () => worker.slice(workerStart, workerEnd));
const names = ['GRID', 'INVENTORY', 'BACKPACKS', 'DATA', 'SERVER', 'CLIENT'];
const dependencies = {
  'ReplicatedStorage.Shared.Cargo': 'Grid', 'ReplicatedStorage.Shared.Inventory': 'Inventory',
  'ReplicatedStorage.Shared.BackpackCatalog': 'Backpacks', 'ReplicatedStorage.Shared.BoatCatalog': 'BoatCatalog',
  'ReplicatedStorage.Shared.AnglerCatalog': 'Catalog', 'ReplicatedStorage.Shared.Aboard': 'function() return aboard end',
  'ReplicatedStorage.Shared.FishCatch': '{formatKg=function(kg) return tostring(kg) .. "kg" end}',
  'ReplicatedStorage.Shared.FishModels': '{show=function() previews += 1 return nil end}',
  'ReplicatedStorage.Shared.FishMutations': '(function()\n' + await read('src/shared/FishMutations.luau') + '\nend)()',
  'ReplicatedStorage.Shared.Gamepasses': '{AutoStore={Id=3722004182}}',
  'script.Parent.AnglerData': 'Data', 'script.Parent.BoatService': 'Boats',
  'script.Parent.GamepassService': '{ownsAutoStore=function() return owns end}',
};
for (let i = 0; i < sources.length; i++) {
  let source = sources[i];
  if (names[i] === 'DATA') source = source.replace('local Cargo\n', 'local Cargo = Grid\n')
    .replace('local FreezerPacking, FreezerModels', 'local FreezerPacking = {layout=function() return {}, true, 0 end}\nlocal FreezerModels = {}');
  for (const [expression, replacement] of Object.entries(dependencies)) {
    source = source.replaceAll('require(' + expression + ')', replacement);
  }
  harness = harness.replace('-- ' + names[i] + '_SOURCE --', () => source);
}
const folder = await mkdtemp(join(tmpdir(), 'fishing-inventory-'));
try {
  const target = join(folder, 'checks.luau');
  await writeFile(target, harness);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Inventory checks failed (${result.status})`);
} finally {
  await rm(folder, { recursive: true, force: true });
}
