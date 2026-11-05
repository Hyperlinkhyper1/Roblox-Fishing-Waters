// Exercise real fish hydration and shared allocation failures with recording mocks.
import { readFileSync, writeFileSync, mkdtempSync, unlinkSync, rmdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = (file) => readFileSync(join(root, file), 'utf8');
const primitives = read('scripts/harbour-geometry.luau').split('local CFrame = {}')[0];
const mocks = read('scripts/drydock-geometry.luau').split('local function loadLowPoly()')[0]
  .replace('-- SHARED_PRIMITIVES --', () => primitives);
const client = read('src/client/FishMeshes.luau')
  .replace(/local FishModels = require\(ReplicatedStorage.Shared.FishModels\)/, 'local FishModels = dependencies.FishModels')
  .replace(/local MeshFeatures = require\(ReplicatedStorage.Shared.MeshFeatures\)/, 'local MeshFeatures = { EditableMeshesEnabled = true }')
  .replace(/local EditableMeshBudget = require\(script.Parent.EditableMeshBudget\)/, 'local EditableMeshBudget = dependencies.EditableMeshBudget');
const program = read('scripts/fish-meshes.luau')
  .replace('-- MOCKS --', () => mocks)
  .replace('-- BUDGET --', () => read('src/client/EditableMeshBudget.luau'))
  .replace('-- CLIENT --', () => client);
const temporary = mkdtempSync(join(tmpdir(), 'fish-meshes-'));
const target = join(temporary, 'check.luau');
try {
  writeFileSync(target, program);
  const result = spawnSync(process.env.LUTE || 'lute.exe', ['run', target], {
    cwd: root, encoding: 'utf8', timeout: 30000,
  });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} finally {
  unlinkSync(target);
  rmdirSync(temporary);
}
