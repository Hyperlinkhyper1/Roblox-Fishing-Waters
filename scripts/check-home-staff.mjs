import { freezerRuntime, injectFreezer } from './freezer-test-runtime.mjs';
// Executes production worker transactions with recording world/store doubles.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const source = await readFile(join(root, 'src/server/CustomerService.luau'), 'utf8');
function section(start, end) {
  const first = source.indexOf(start);
  const last = source.indexOf(end, first);
  if (first < 0 || last < 0) throw new Error(`Missing worker section: ${start}`);
  return source.slice(first, last);
}
let program = await readFile(join(root, 'scripts/home-staff.luau'), 'utf8');
program = program.replace('-- DATA_SOURCE --', injectFreezer(await readFile(join(root, 'src/server/AnglerData.luau'), 'utf8')))
  .replace('-- STAFF_SOURCE --', await readFile(join(root, 'src/shared/StaffCatalog.luau'), 'utf8'))
  .replace('-- SELL_SOURCE --', section('local function sell(', 'local function removeStaff('))
  .replace('-- PORTER_SOURCE --', section('local function dockedBoat(', 'local function ensureStaff('));
program = await freezerRuntime() + program;
const folder = await mkdtemp(join(tmpdir(), 'home-staff-'));
try {
  const target = join(folder, 'workers.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Worker checks failed (${result.status})`);
} finally {
  if (dirname(folder) !== resolve(tmpdir())) throw new Error('Unexpected temporary directory');
  await rm(folder, { recursive: true, force: true });
}
