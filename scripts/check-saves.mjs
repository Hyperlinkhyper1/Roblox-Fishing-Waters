// Execute save selection, ownership and company routing against recording Roblox
// mocks. These checks do not replace live DataStore/friendship/teleport testing.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const temporary = await mkdtemp(join(tmpdir(), 'fishing-saves-'));
try {
  let source = await readFile(join(root, 'src/server/SaveService.luau'), 'utf8');
  for (const name of ['SaveData', 'BoatData', 'RodSerials', 'CompanyWorth']) {
    source = source.replace(`require(script.Parent.${name})`, `dependencies.${name}`);
  }
  const rules = await readFile(join(root, 'src/server/SaveData.luau'), 'utf8');
  const harness = (await readFile(join(root, 'scripts/save-service.luau'), 'utf8'))
    .replace('-- SAVE_DATA_SOURCE --', () => rules)
    .replace('-- SAVE_SERVICE_SOURCE --', () => source);
  const path = join(temporary, 'check.luau');
  await writeFile(path, harness);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', path], {
    cwd: root, encoding: 'utf8', timeout: 30000,
  });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Save service checks failed (${result.status})`);
} finally {
  await rm(temporary, { recursive: true, force: true });
}
