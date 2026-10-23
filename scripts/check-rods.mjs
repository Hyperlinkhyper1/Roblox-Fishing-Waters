// Construction and local simulation checks with recording Roblox mocks.
// Does not replace Studio verification of the grip, rendering, or replication.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const temporaryRoot = resolve(tmpdir());
const temporary = await mkdtemp(join(temporaryRoot, 'fishing-rods-'));
try {
  let program = await readFile(join(root, 'scripts/rod-physics.luau'), 'utf8');
  for (const [marker, file] of [
    ['ROD_DYNAMICS_SOURCE', 'src/shared/RodDynamics.luau'],
    ['FISHING_ROD_SOURCE', 'src/shared/FishingRod.luau'],
    ['ROD_CLIENT_SOURCE', 'src/client/RodPhysics.luau'],
  ]) {
    let source = await readFile(join(root, file), 'utf8');
    if (marker === 'ROD_CLIENT_SOURCE') source = source.replace('require(ReplicatedStorage.Shared.RodDynamics)', 'dynamics');
    if (!program.includes(`-- ${marker} --`)) throw new Error(`Missing ${marker} hook`);
    program = program.replace(`-- ${marker} --`, source);
  }
  const target = join(temporary, 'rods.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Rod checks failed (Lute exit ${result.status})`);
} finally {
  if (dirname(resolve(temporary)) !== temporaryRoot) throw new Error('Unexpected temporary directory');
  await rm(temporary, { recursive: true, force: true });
}
