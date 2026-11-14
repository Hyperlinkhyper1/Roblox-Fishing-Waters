// Execute the real workbench builder and furniture dispatch with recording Roblox doubles.
// This validates emitted geometry and placement wiring, not Studio rendering or physics.
import {readFile, writeFile, mkdtemp, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = name => readFile(join(root, name), 'utf8');
const [shared, harbour, service, catalog, workbench, harness] = await Promise.all([
  read('scripts/drydock-geometry.luau'), read('scripts/harbour-geometry.luau'),
  read('src/server/FurnitureService.luau'), read('src/shared/FurnitureCatalog.luau'),
  read('src/server/Map/Workbench.luau'), read('scripts/workbench-geometry.luau'),
]);
if (!service.includes('require(script.Parent.Map.Workbench)')) {
  throw new Error('FurnitureService must load the actual workbench builder');
}
function section(start, end) {
  const first = service.indexOf(start), last = service.indexOf(end, first);
  if (first < 0 || last < first) throw new Error('Missing furniture hook: ' + start);
  return service.slice(first, last);
}
let program = shared.slice(0, shared.indexOf('local dependencies ='))
  .replace('-- SHARED_PRIMITIVES --', () => harbour.split('local CFrame = {}')[0]);
program += '\nlocal Furniture = (function()\n' + catalog + '\nend)()\n';
program += '\nlocal Workbench = (function()\n' + workbench + '\nend)()\n';
program += harness
  .replace('-- BUILD_SOURCE --', () => section('local function key(', '-- Rebuilds only what changed'))
  .replace('-- PREVIEWS_SOURCE --', () => section('local function buildPreviews(', 'function FurnitureService.start()'));
const temporary = await mkdtemp(join(tmpdir(), 'fishing-workbench-'));
try {
  const target = join(temporary, 'workbench.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute.exe', ['run', target], {
    cwd: root, encoding: 'utf8', timeout: 30000,
  });
  const output = result.stdout || '';
  const records = output.split(/\r?\n/).filter(line => line.startsWith('@WORKBENCH '));
  process.stdout.write(output.split(/\r?\n/).filter(line => !line.startsWith('@WORKBENCH ')).join('\n'));
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Workbench geometry checks failed (' + result.status + ')');
  const dumpIndex = process.argv.indexOf('--dump');
  if (dumpIndex >= 0) {
    if (!process.argv[dumpIndex + 1]) throw new Error('--dump requires a JSON path');
    const parts = records.map(line => {
      const [, name, shape, ...numbers] = line.split(' ');
      const n = numbers.map(Number);
      return {name, shape, position: n.slice(0, 3), right: n.slice(3, 6), up: n.slice(6, 9),
        back: n.slice(9, 12), size: n.slice(12, 15), color: n.slice(15, 18)};
    });
    await writeFile(resolve(process.argv[dumpIndex + 1]), JSON.stringify(parts));
  }
} finally {
  if (dirname(resolve(temporary)) !== resolve(tmpdir())) throw new Error('Unexpected temporary directory');
  await rm(temporary, {recursive: true, force: true});
}
