import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = resolve(import.meta.dirname, '..');
const temporary = await mkdtemp(join(tmpdir(), 'fishing-shark-swim-'));
try {
  const requireShape = 'require(ReplicatedStorage:WaitForChild("Shared").SharkShape)';
  const source = await readFile(join(root, 'src/client/SharkSwim.luau'), 'utf8');
  const shape = await readFile(join(root, 'src/shared/SharkShape.luau'), 'utf8');
  const harness = await readFile(join(root, 'scripts/shark-swim.luau'), 'utf8');
  if (!harness.includes('-- SHARK_SWIM_SOURCE --') || !harness.includes('-- SHARK_SHAPE_SOURCE --') || !source.includes(requireShape)) {
    throw new Error('Shark swim test hook changed');
  }
  const target = join(temporary, 'shark-swim.luau');
  await writeFile(target, harness
    .replace('-- SHARK_SHAPE_SOURCE --', () => shape)
    .replace('-- SHARK_SWIM_SOURCE --', () => source.replace(requireShape, 'SHARK_SHAPE')));
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { cwd: root, encoding: 'utf8' });
  process.stdout.write(result.stdout || '');
  process.stderr.write(result.stderr || '');
  if (result.error) throw result.error;
  if (result.status !== 0) process.exitCode = result.status || 1;
} finally {
  await rm(temporary, { recursive: true, force: true });
}
