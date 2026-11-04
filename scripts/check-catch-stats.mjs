import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { freezerRuntime, injectFreezer } from './freezer-test-runtime.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = path => readFile(join(root, path), 'utf8');
const source = injectFreezer(await read('src/server/AnglerData.luau'));
// Run the saved-profile catch assertions independently of boat purchase checks.
const existing = await read('scripts/angler-data.luau');
const start = existing.indexOf('local checks = 0');
const end = existing.indexOf('c.Findings.HighestValue.Kg = 999');
if (start < 0 || end < start) throw Error('Catch-stat assertion boundaries changed');
let program = await freezerRuntime() + '\nlocal Data = (function()\n' + source + '\nend)()\n' + existing.slice(start, end);
for (const path of ['src/client/PlayerMenu.luau', 'src/client/Casting.luau', 'src/server/AnglerService.luau', 'src/server/CatchService.luau']) {
  program += '\nlocal function syntaxCheck()\n' + await read(path) + '\nend\n';
}
program += '\nprint("Catch statistics: " .. checks .. " checks passed; changed modules compile")\n';
const folder = await mkdtemp(join(tmpdir(), 'catch-stats-'));
try {
  const target = join(folder, 'check.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw Error('Catch statistics checks failed (' + result.status + ')');
} finally {
  await rm(folder, { recursive: true, force: true });
}
