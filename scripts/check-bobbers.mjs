// Exercise real hanging/floating geometry using the existing recording primitives.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const folder = await mkdtemp(join(tmpdir(), 'fishing-bobbers-'));
const read = path => readFile(join(root, path), 'utf8');
try {
  const primitives = await read('scripts/rod-physics.luau');
  let program = primitives.slice(0, primitives.indexOf('local function loadDynamics()'))
    .replace('class == "BasePart" and kind == "Part"', 'class == "BasePart" and (kind == "Part" or kind == "WedgePart")');
  program += await read('scripts/bobber-models.luau');
  for (const [marker, path] of [
    ['SKINS', 'src/shared/BobberSkins.luau'], ['BOBBER', 'src/shared/FishingBobber.luau'],
    ['ROD', 'src/shared/FishingRod.luau'], ['CASTING', 'src/client/Casting.luau'],
  ]) {
    let source = await read(path);
    source = source.replace('require(script.Parent.BobberSkins)', 'BobberSkins')
      .replace('require(script.Parent.FishingBobber)', 'FishingBobber')
      .replace('require(ReplicatedStorage.Shared.FishingBobber)', 'FishingBobber')
      .replace(/require\(script.Parent.(?:CastAnimation|FishingAudio|ReelMinigame)\)/g, '{}');
    if (marker === 'CASTING') source = source.replace(/return Casting\s*$/, 'return {newLine = newLine, updateLine = updateLine, setBuiltInBobber = setBuiltInBobber, destroyLine = destroyLine}');
    program = program.replace(`-- ${marker}_SOURCE --`, () => source);
  }
  const path = join(folder, 'bobbers.luau');
  await writeFile(path, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', path], {cwd: root, encoding: 'utf8', timeout: 30000});
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Bobber geometry checks failed (${result.status})`);
} finally {
  if (dirname(resolve(folder)) !== resolve(tmpdir())) throw new Error('Unexpected temporary folder');
  await rm(folder, {recursive: true, force: true});
}
