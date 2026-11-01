// Run the production collision setup against recording instance and world doubles.
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = path => readFileSync(join(root, path), 'utf8');
const source = read('src/server/CustomerService.luau');
if (!source.includes('NpcCollision.bind(model)')) throw new Error('NPC factory must bind collision filtering');
const program = read('scripts/npc-collision.luau').replace('-- NPC_COLLISION_SOURCE --', () => read('src/server/NpcCollision.luau'));
const folder = mkdtempSync(join(tmpdir(), 'npc-collision-'));
try {
  const target = join(folder, 'check.luau');
  writeFileSync(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('NPC collision checks failed');
} finally {
  rmSync(folder, { recursive: true, force: true });
}
