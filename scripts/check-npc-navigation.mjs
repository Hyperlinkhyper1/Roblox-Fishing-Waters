// Execute the production navigator against a simulated Humanoid and path service.
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = file => readFileSync(join(root, file), 'utf8');
const customerSource = read('src/server/CustomerService.luau');
const walkStart = customerSource.indexOf('local function walk(customer,');
const walkEnd = customerSource.indexOf('\nlocal function face(', walkStart);
if (!customerSource.includes('require(script.Parent.NpcNavigation)') || walkStart < 0 || walkEnd < 0) {
  throw new Error('CustomerService must use the shared NPC navigator');
}
const program = read('scripts/npc-navigation.luau')
  .replace('-- BASE_GRID_SOURCE --', () => read('src/shared/BaseGrid.luau'))
  .replace('-- NAVIGATION_SOURCE --', () => read('src/server/NpcNavigation.luau'))
  .replace('-- CUSTOMER_WALK_SOURCE --', () => customerSource.slice(walkStart, walkEnd));
const temporary = mkdtempSync(join(tmpdir(), 'npc-navigation-'));
try {
  const target = join(temporary, 'check.luau');
  writeFileSync(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], {
    cwd: root, encoding: 'utf8', timeout: 30000,
  });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} finally {
  rmSync(temporary, { recursive: true, force: true });
}
