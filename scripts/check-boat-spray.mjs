// Exercise the production spray controller with recording Roblox primitives.
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = resolve(import.meta.dirname, '..');
const read = (path) => readFileSync(join(root, path), 'utf8');
const primitives = read('scripts/harbour-geometry.luau').split('local CFrame = {}')[0];
const mocks = read('scripts/drydock-geometry.luau').split('local function loadLowPoly()')[0]
  .replace('-- SHARED_PRIMITIVES --', () => primitives);
const source = read('src/client/BoatSpray.luau')
  .replace(/require\(ReplicatedStorage.Shared.(BoatCatalog|Cargo|Biomes|Weather)\)/g, 'dependencies.$1');
const program = read('scripts/boat-spray.luau')
  .replace('-- MOCKS --', () => mocks)
  .replace('-- BOAT_SPRAY --', () => source);
const temporary = mkdtempSync(join(tmpdir(), 'boat-spray-'));
try {
  const target = join(temporary, 'check.luau');
  writeFileSync(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], {
    cwd: root, encoding: 'utf8', timeout: 30000,
  });
  process.stdout.write(result.stdout || '');
  process.stderr.write(result.stderr || '');
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Boat spray checks failed (${result.status})`);
} finally {
  rmSync(temporary, { recursive: true, force: true });
}
