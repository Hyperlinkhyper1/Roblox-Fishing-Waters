// Execute production server/client modules with a deterministic cross-server bus,
// persistent version store, clock, joins, and both teleport failure paths.
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = path => readFileSync(join(root, path), 'utf8');
const source = read('scripts/server-updates.luau')
  .replace('-- SERVER_SOURCE --', () => read('src/server/ServerUpdates.luau'))
  .replace('-- CLIENT_SOURCE --', () => read('src/client/ServerUpdates.luau')
    .replace('require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))', 'Theme'));
const temporary = mkdtempSync(join(tmpdir(), 'server-updates-'));
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
