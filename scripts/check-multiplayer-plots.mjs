// Executes expanded-property preparation against the actual harbour/base/road
// builders. Geometry doubles do not replace Studio rendering or live physics.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
const root = resolve(import.meta.dirname, '..');
const read = path => readFile(join(root, path), 'utf8');
const temporary = await mkdtemp(join(tmpdir(), 'multiplayer-plots-'));
try {
  const existing = await read('scripts/drydock-geometry.luau');
  let program = existing.slice(0, existing.indexOf('local checks, failures ='));
  const primitives = (await read('scripts/harbour-geometry.luau')).split('local CFrame = {}')[0];
  program = program.replace('-- SHARED_PRIMITIVES --', () => primitives);
  const catalog = await read('scripts/check-drydock.mjs');
  for (const [, name, path] of catalog.matchAll(/^\s+(\w+): '([^']+)'/gm)) {
    if (!program.includes(`-- ${name}_SOURCE --`)) continue;
    let source = (await read(path))
      .replace(/local (\w+) = require\(script\.Parent\.(?:Parent\.)?(\w+)\)/g, 'local $1 = dependencies.$2')
      .replace(/local (\w+) = require\(ReplicatedStorage\.Shared\.(\w+)\)/g, 'local $1 = dependencies.$2')
      .replace(/local (\w+) = require\(game:GetService\("ReplicatedStorage"\)\.Shared\.(\w+)\)/g, 'local $1 = dependencies.$2');
    if (name === 'HARBOUR') {
      // Preserve all road/house/scenery builders and the real height evaluator;
      // omit only the expensive triangulated island ground mesh in this audit.
      const ground = source.indexOf('local function buildGround(');
      const paths = source.indexOf('\nlocal function resample(', ground);
      source = source.slice(0, ground) + 'local function buildGround() end\n' + source.slice(paths);
      const streetsStart = source.indexOf('\tlocal keepOut = {', source.indexOf('function Harbour.build('));
      const streetsEnd = source.indexOf('\n\t-- Dirt tracks', streetsStart);
      const streets = source.slice(streetsStart, streetsEnd);
      source = source.replaceAll('require(game:GetService("ReplicatedStorage").Shared.Biomes)', 'dependencies.Biomes')
      .replace(/return Harbour\s*$/, `
Harbour.makeShape = makeShape
Harbour.heightAt = heightAt
Harbour.shoreAt = shoreAt
Harbour.testAnchors = BASES
Harbour.buildBase = buildBase
Harbour.rerouteShopRoads = rerouteShopRoads
Harbour.testBuildStreets = function(shape, village, spots, plaza, lighthouse)
${streets}
end
return Harbour`);
    }
    program = program.replace(`-- ${name}_SOURCE --`, () => source);
  }
  const layout = await read('src/shared/MultiplayerPlots.luau');
  let service = (await read('src/server/MultiplayerPlots.luau'))
    .replace('require(game:GetService("ReplicatedStorage").Shared.MultiplayerPlots)', 'Layout');
  if (process.argv.includes('--debug')) service = service.replace('if scenery then remove[scenery] = true else return nil end',
    'if scenery then remove[scenery] = true else print("Blocked base",base:GetAttribute("BaseId"),part:GetFullName(),frame:PointToObjectSpace(part.Position)); return nil end');
  program += (await read('scripts/multiplayer-plots.luau'))
    .replace('-- LAYOUT_SOURCE --', () => layout)
    .replace('-- SERVICE_SOURCE --', () => service);
  const path = join(temporary, 'check.luau');
  await writeFile(path, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', path], { cwd: root, encoding: 'utf8', timeout: 60000, maxBuffer: 8 * 1024 * 1024 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Multiplayer plot checks failed (${result.status})`);
} finally {
  await rm(temporary, { recursive: true, force: true });
}
