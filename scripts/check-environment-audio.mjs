// Runs the actual mixer and character lifecycle against recording Roblox mocks.
// Playback quality and asset delivery still require a Studio listening test.
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = (path) => readFileSync(join(root, path), 'utf8');
const primitives = read('scripts/harbour-geometry.luau').split('local CFrame = {}')[0];
const mocks = read('scripts/drydock-geometry.luau').split('local function loadBoatCatalog()')[0]
  .replace('-- SHARED_PRIMITIVES --', () => primitives);
const client = read('src/client/EnvironmentAudio.luau')
  .replace(/require\(ReplicatedStorage\.Shared\.(\w+)\)/g, 'dependencies.$1');
const program = read('scripts/environment-audio.luau')
  .replace('-- MOCKS --', () => mocks)
  .replace('-- CLIENT --', () => client);
const temporary = mkdtempSync(join(tmpdir(), 'environment-audio-'));
try {
  const target = join(temporary, 'check.luau');
  writeFileSync(target, program);
  const result = spawnSync(process.env.LUTE || 'lute.exe', ['run', target], {
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
