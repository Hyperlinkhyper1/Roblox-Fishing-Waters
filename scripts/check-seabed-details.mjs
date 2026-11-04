// Execute production scenery generation with recording geometry/raycast doubles.
// This checks coverage and streaming policy; appearance still needs Studio.
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = path => readFileSync(join(root, path), 'utf8');
const primitives = read('scripts/harbour-geometry.luau').split('local CFrame = {}')[0];
let program = read('scripts/drydock-geometry.luau').split('local dependencies =')[0]
  .replace('-- SHARED_PRIMITIVES --', () => primitives);
program += '\nlocal dependencies = {}\nlocal RaycastParams = { new = function() return {} end }\n';
for (const name of ['Biomes', 'LowPoly', 'Props', 'Harbour', 'Seabed', 'SeabedLife', 'SeabedDetails']) {
  const path = name === 'Biomes' ? 'src/shared/Biomes.luau' : `src/server/Map/${name}.luau`;
  let source = read(path)
    .replace(/require\(script\.Parent\.(\w+)\)/g, 'dependencies.$1')
    .replace('require(ReplicatedStorage.Shared.Biomes)', 'dependencies.Biomes');
  if (name === 'SeabedDetails') {
    source = source.replace(/return SeabedDetails\s*$/, 'return { ensure = SeabedDetails.ensure, sample = sample }');
  }
  program += `\ndependencies.${name} = (function()\n${source}\nend)()\n`;
}
program += read('scripts/seabed-details.luau');
const temporary = mkdtempSync(join(tmpdir(), 'fishing-seabed-'));
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
  if (dirname(resolve(temporary)) !== resolve(tmpdir())) throw new Error('Unexpected temporary directory');
  rmSync(temporary, { recursive: true, force: true });
}
