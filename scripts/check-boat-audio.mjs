import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const temporaryRoot = resolve(tmpdir());
const temporary = await mkdtemp(join(temporaryRoot, 'boat-audio-'));
try {
  const source = (await readFile(join(root, 'src/client/BoatAudio.luau'), 'utf8'))
    .replace('require(ReplicatedStorage.Shared.BoatCatalog)', 'catalog');
  const catalog = await readFile(join(root, 'src/shared/BoatCatalog.luau'), 'utf8');
  const harness = await readFile(join(root, 'scripts/boat-audio.luau'), 'utf8');
  const target = join(temporary, 'check.luau');
  await writeFile(target, harness
    .replace('-- BOAT_CATALOG_SOURCE --', () => catalog)
    .replace('-- BOAT_AUDIO_SOURCE --', () => source));
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Boat audio checks failed (${result.status})`);
} finally {
  if (dirname(resolve(temporary)) !== temporaryRoot) throw new Error('Unexpected temporary directory');
  await rm(temporary, { recursive: true, force: true });
}
