// Run src/server/ServerHealth.luau against a fake clock, Stats and MemoryStore:
// dead-server detection, single reporter per death, memory alarms, freezes,
// clean-shutdown cleanup.
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = path => readFileSync(join(root, path), 'utf8');
const module = read('src/server/ServerHealth.luau');
const source = read('scripts/server-health.luau').replaceAll('-- SERVER_HEALTH --', () => module);
const temporary = mkdtempSync(join(tmpdir(), 'server-health-'));
try {
  const path = join(temporary, 'check.luau');
  writeFileSync(path, source);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', path], {
    cwd: root, encoding: 'utf8', timeout: 30000,
  });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} finally {
  if (dirname(temporary) !== resolve(tmpdir())) throw new Error('Unexpected temporary directory');
  rmSync(temporary, { recursive: true, force: true });
}
