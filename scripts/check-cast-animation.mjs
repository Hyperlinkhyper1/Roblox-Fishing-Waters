import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const temporary = await mkdtemp(join(tmpdir(), 'cast-animation-'));
try {
  const source = await readFile(join(root, 'src/client/CastAnimation.luau'), 'utf8');
  const harness = await readFile(join(root, 'scripts/cast-animation.luau'), 'utf8');
  const target = join(temporary, 'check.luau');
  await writeFile(target, harness.replace('-- CAST_ANIMATION_SOURCE --', () => source));
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Cast animation checks failed (${result.status})`);
} finally {
  await rm(temporary, { recursive: true, force: true });
}
