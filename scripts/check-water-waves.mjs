// Run the actual swell renderer and shared wave field with recording Roblox mocks.
// This exercises motion, land masks and camera lifecycle, not Studio appearance.
import { readFileSync, writeFileSync, mkdtempSync, unlinkSync, rmdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = (file) => readFileSync(join(root, file), 'utf8');
const primitives = read('scripts/harbour-geometry.luau').split('local CFrame = {}')[0];
const mocks = read('scripts/drydock-geometry.luau').split('local function loadLowPoly()')[0]
  .replace('-- SHARED_PRIMITIVES --', () => primitives);
const quality = read('scripts/water-quality.luau')
  .replace('-- WATER_QUALITY --', () => read('src/client/WaterQuality.luau'));
const source = read('src/client/WaterWaves.luau')
  .replace(/local Biomes = require\(ReplicatedStorage.Shared.Biomes\)/, 'local Biomes = dependencies.Biomes')
  .replace(/local Weather = require\(ReplicatedStorage.Shared.Weather\)/, 'local Weather = dependencies.Weather')
  .replace(/local WaterQuality = require\(script.Parent.WaterQuality\)/, 'local WaterQuality = dependencies.WaterQuality')
  .replace(/local TerrainProbe = require\(script\.Parent\.TerrainProbe\)/, () => `local TerrainProbe = (function()\n${read('src/client/TerrainProbe.luau')
    .replace(/require\(ReplicatedStorage\.Shared\.Biomes\)/, 'dependencies.Biomes')}\nend)()`);
const program = read('scripts/water-waves.luau')
  .replace('-- MOCKS --', () => `${mocks}\n${quality}`)
  .replace('-- BIOMES --', () => read('src/shared/Biomes.luau'))
  .replace('-- WEATHER --', () => read('src/shared/Weather.luau'))
  .replace('-- CLIENT --', () => source);
const temporary = mkdtempSync(join(tmpdir(), 'water-waves-'));
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
