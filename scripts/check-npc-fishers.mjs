// Runs the shared NPC fisher timeline (player-count rule, routes, boat and angler motion).
// The lake route search and the drawn boats still need a Studio check.
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = (path) => readFileSync(join(root, path), 'utf8');
const program = read('scripts/npc-fishers.luau')
  .replace('-- NPC_FISHERS_SOURCE --', () => read('src/shared/NpcFishers.luau'));
const temporary = mkdtempSync(join(tmpdir(), 'npc-fishers-'));
try {
  const target = join(temporary, 'check.luau');
  writeFileSync(target, program);
  // LUAU points at a plain luau binary; otherwise lute, like the other checks.
  const [command, args] = process.env.LUAU
    ? [process.env.LUAU, [target]]
    : [process.env.LUTE || 'lute', ['run', target]];
  const result = spawnSync(command, args, { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} finally {
  rmSync(temporary, { recursive: true, force: true });
}
