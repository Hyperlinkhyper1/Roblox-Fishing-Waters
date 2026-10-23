// Execute the production loading screen with a deterministic Roblox scheduler.
// This verifies readiness and cleanup behavior, not native Roblox rendering.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const treeOption = process.argv.indexOf('--tree');
const treePath = treeOption < 0 ? null : process.argv[treeOption + 1];
if (treeOption >= 0 && !treePath) throw new Error('--tree requires an output path');
const mobileOption = process.argv.indexOf('--mobile-tree');
const mobilePath = mobileOption < 0 ? null : process.argv[mobileOption + 1];
if (mobileOption >= 0 && !mobilePath) throw new Error('--mobile-tree requires an output path');
const temporary = await mkdtemp(join(tmpdir(), 'fishing-loading-'));
try {
  const [source, harness, geometry, theme] = await Promise.all([
    readFile(join(root, 'src/first/Loading.client.luau'), 'utf8'),
    readFile(join(root, 'scripts/loading-screen.luau'), 'utf8'),
    readFile(join(root, 'src/first/FishSkeletonGeometry.luau'), 'utf8'),
    readFile(join(root, 'src/first/UITheme.luau'), 'utf8'),
  ]);
  const geometryImport = 'local FishSkeletonGeometry = require(script.Parent:WaitForChild("FishSkeletonGeometry"))';
  if (source.split(geometryImport).length !== 2) {
    throw new Error('Expected exactly one explicit loading-screen geometry import');
  }
  const boundSource = source.replace('require(script.Parent:WaitForChild("UITheme"))', 'Theme').replace(geometryImport, '-- Pure geometry module is bound by the harness.');
  const target = join(temporary, 'check.luau');
  await writeFile(target, harness
    .replace('-- UI_THEME --', () => theme)
    .replace('-- FISH_SKELETON_GEOMETRY --', () => geometry)
    .replace('-- LOADING_SOURCE --', () => boundSource));
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], {
    cwd: root, encoding: 'utf8', timeout: 30000,
  });
  for (const line of (result.stdout || '').split(/\r?\n/)) {
    if (line.startsWith('LOADING_MOBILE_TREE ')) {
      if (mobilePath) await writeFile(resolve(mobilePath), JSON.stringify(JSON.parse(line.slice(20)), null, 2));
    } else if (line.startsWith('LOADING_TREE ')) {
      if (treePath) await writeFile(resolve(treePath), JSON.stringify(JSON.parse(line.slice(13)), null, 2));
    } else if (line) process.stdout.write(line + '\n');
  }
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Loading-screen regression failed');
  if (treePath) process.stdout.write('Loading UI tree exported to ' + resolve(treePath) + '\n');
  if (mobilePath) process.stdout.write('Compact loading UI tree exported to ' + resolve(mobilePath) + '\n');
} finally {
  if (dirname(temporary) !== resolve(tmpdir())) throw new Error('Unexpected temporary directory');
  await rm(temporary, { recursive: true, force: true });
}
