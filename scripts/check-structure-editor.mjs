// Execute the production editor with UI/network doubles; this does not render Studio UI.
import {readFile, writeFile, mkdtemp, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = name => readFile(join(root, name), 'utf8');
const [catalog, editor, queue, fixture] = await Promise.all([
  read('src/shared/BuildingCatalog.luau'), read('src/client/StructureEditor.luau'), read('src/client/BuildPaintQueue.luau'), read('scripts/structure-editor.luau'),
]);
const program = fixture.replace('-- BUILDING_CATALOG --', catalog).replace('-- BUILD_PAINT_QUEUE --', queue).replace('-- STRUCTURE_EDITOR --', editor);
const directory = await mkdtemp(join(tmpdir(), 'structure-editor-check-'));
try {
  const target = join(directory, 'editor.luau');
  await writeFile(target, program);
  const runtime = process.env.LUTE || 'lute';
  const result = spawnSync(runtime, ['run', target], {cwd: root, encoding: 'utf8', timeout: 60000, maxBuffer: 4 * 1024 * 1024});
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw new Error(`Could not execute ${runtime}: ${result.error.message}. Set LUTE to an installed runtime.`);
  if (result.status !== 0) throw new Error(`Structure editor checks failed (${result.status})`);
} finally {
  await rm(directory, {recursive: true, force: true});
}
