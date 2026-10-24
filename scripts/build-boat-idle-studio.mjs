// Build an isolated, unpublished Studio playtest using the production modules.
// Usage: node scripts/build-boat-idle-studio.mjs <output-directory>, then F5 in Studio.
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
if (!process.argv[2]) throw new Error('Supply a directory for the isolated test place');
const output = resolve(process.argv[2]);
await mkdir(output, { recursive: true });
let source = await readFile(join(root, 'src/server/BoatService.luau'), 'utf8');
if (!/return BoatService\s*$/.test(source)) throw new Error('BoatService return hook changed');
// Only this test copy exposes launch/state; the shipped module keeps its API.
source = source.replace(/return BoatService\s*$/, 'return { start = BoatService.start, launch = launch, active = active }');
await writeFile(join(output, 'BoatService.luau'), source);
const server = { $className: 'ServerScriptService', BoatService: { $path: join(output, 'BoatService.luau') } };
for (const name of ['BoatData', 'AnglerData', 'Rowboat', 'FishingBoat', 'DrydockLaunch', 'BoatLaunchCollision']) {
  server[name] = { $path: join(root, `src/server/${name}.luau`) };
}
server.Regression = { $path: join(root, 'scripts/boat-idle-studio.server.luau') };
const project = {
  name: 'Boat Idle Regression',
  tree: {
    $className: 'DataModel',
    ReplicatedStorage: { Shared: { $path: join(root, 'src/shared') } },
    ServerScriptService: server,
    StarterPlayer: { StarterPlayerScripts: {
      Regression: { $path: join(root, 'scripts/boat-idle-studio.client.luau') },
      ParkedBoats: { $path: join(root, 'src/client/ParkedBoats.luau') },
    } },
    Workspace: { $properties: { StreamingEnabled: false } },
  },
};
const projectPath = join(output, 'test.project.json');
await writeFile(projectPath, JSON.stringify(project, null, 2));
const result = spawnSync('rojo', ['build', projectPath, '-o', join(output, 'BoatIdleRegression.rbxlx')], { encoding: 'utf8' });
if (result.stdout) process.stdout.write(result.stdout);
if (result.stderr) process.stderr.write(result.stderr);
if (result.error) throw result.error;
if (result.status !== 0) throw new Error('Could not build Studio regression place');
