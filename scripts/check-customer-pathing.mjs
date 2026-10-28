// Executes the production customer route follower against recording engine
// mocks. This does not validate the real Roblox navmesh or house collision.
import { readFileSync, writeFileSync, mkdtempSync, unlinkSync, rmdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = (file) => readFileSync(join(root, file), 'utf8');
const source = read('src/server/CustomerService.luau');
function section(start, end) {
  const first = source.indexOf(start);
  const last = source.indexOf(end, first);
  if (first < 0 || last < 0) throw new Error(`Missing customer path section: ${start}`);
  return source.slice(first, last);
}
const program = read('scripts/customer-pathing.luau')
  .replace('-- PATH_CONSTANTS --', () => section('-- R15-sized agent.', '-- Full-depth row'))
  .replace('-- WALK_SOURCE --', () => section('local function alive(customer)', 'local function face('));
const temporary = mkdtempSync(join(tmpdir(), 'customer-pathing-'));
const target = join(temporary, 'check.luau');
try {
  writeFileSync(target, program);
  const result = spawnSync(process.env.LUTE || 'lute.exe', ['run', target], {
    cwd: root, encoding: 'utf8', timeout: 30000,
  });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} finally {
  unlinkSync(target);
  rmdirSync(temporary);
}
