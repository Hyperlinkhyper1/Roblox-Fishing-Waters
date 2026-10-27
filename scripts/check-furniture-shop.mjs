// Execute production showroom authorization and purchase handlers with recording doubles.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = path => readFile(join(root, path), 'utf8');
const source = await read('src/server/FurnitureService.luau');
function section(start, end) {
  const first = source.indexOf(start), last = source.indexOf(end, first);
  if (first < 0 || last < 0) throw new Error(`Missing furniture service hook: ${start}`);
  return source.slice(first, last);
}
const shared = await read('scripts/drydock-geometry.luau');
const primitives = (await read('scripts/harbour-geometry.luau')).split('local CFrame = {}')[0];
let program = shared.slice(0, shared.indexOf('local dependencies ='))
  .replace('-- SHARED_PRIMITIVES --', () => primitives);
program += '\nlocal Furniture = (function()\n' + await read('src/shared/FurnitureCatalog.luau') + '\nend)()\n';
program += await read('scripts/furniture-shop.luau');
program = program.replace('-- ROOT_SOURCE --', () => section('local function rootOf(', 'local function notify('))
  .replace('-- HOUSE_SOURCE --', () => section('local function houseOf(', 'local function rootOf('))
  .replace('-- AUTH_SOURCE --', () => section('local function atShop(', 'local function atHome('))
  .replace('-- HOME_SOURCE --', () => section('local function atHome(', 'local function state('))
  .replace('-- PURCHASE_SOURCE --', () => section('local function transact(', 'local function place('))
  .replace('-- PLACEMENT_SOURCE --', () => section('local function place(', 'local function rackPrompt('));
const temporary = await mkdtemp(join(tmpdir(), 'fishing-furniture-shop-'));
try {
  const target = join(temporary, 'shop.luau');
  const moduleRoot = relative(temporary, root).replaceAll('\\', '/');
  await writeFile(target, program.replace('-- ANGLER_DATA_MODULE --', moduleRoot + '/src/server/AnglerData'));
  const result = spawnSync(process.env.LUTE || 'lute.exe', ['run', target], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Furniture shop checks failed (${result.status})`);
} finally {
  if (dirname(resolve(temporary)) !== resolve(tmpdir())) throw new Error('Unexpected temporary directory');
  await rm(temporary, { recursive: true, force: true });
}
