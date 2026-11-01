// Run the real shark loop against a deterministic, lightweight Roblox mock.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = resolve(import.meta.dirname, '..');
const temporary = await mkdtemp(join(tmpdir(), 'fishing-sharks-'));
try {
  let service = await readFile(join(root, 'src/server/SharkService.luau'), 'utf8');
  service = service.replace(/local Shared = ReplicatedStorage:WaitForChild\("Shared"\)[\s\S]*?local BoatService = require\(script.Parent.BoatService\)/,
    'local Biomes, DayNight, Weather, SpearSkins, HullDamage, BoatService = dependencies.Biomes, dependencies.DayNight, dependencies.Weather, dependencies.SpearSkins, dependencies.HullDamage, dependencies.BoatService');
  service = service.replace('local SharkModel = require(script.Parent.SharkModel)', 'local SharkModel = dependencies.SharkModel');
  const harness = await readFile(join(root, 'scripts/shark-service.luau'), 'utf8');
  const skins = await readFile(join(root, 'src/shared/SpearSkins.luau'), 'utf8');
  if (!harness.includes('-- SHARK_SERVICE_SOURCE --') || service.includes('require(script')) {
    throw new Error('Shark service test hook changed');
  }
  const target = join(temporary, 'shark-service.luau');
  await writeFile(target, harness.replace('-- SPEAR_SKINS_SOURCE --', skins).replace('-- SHARK_SERVICE_SOURCE --', service));
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { cwd: root, encoding: 'utf8' });
  process.stdout.write(result.stdout || '');
  process.stderr.write(result.stderr || '');
  if (result.error) throw result.error;
  if (result.status !== 0) process.exitCode = result.status || 1;
} finally {
  await rm(temporary, { recursive: true, force: true });
}
