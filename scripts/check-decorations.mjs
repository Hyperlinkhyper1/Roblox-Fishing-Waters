// Exercise actual decoration builders and both server rendering paths using recording mocks.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = path => readFile(join(root, path), 'utf8');
const shared = await read('scripts/drydock-geometry.luau');
const primitives = (await read('scripts/harbour-geometry.luau')).split('local CFrame = {}')[0];
const service = await read('src/server/FurnitureService.luau');
function section(start, end) {
  const first = service.indexOf(start), last = service.indexOf(end, first);
  if (first < 0 || last < 0) throw new Error('Missing furniture service hook: ' + start);
  return service.slice(first, last);
}
let program = shared.slice(0, shared.indexOf('local dependencies =')).replace('-- SHARED_PRIMITIVES --', () => primitives);
// The shared geometry mock accepts arbitrary enum names, unlike Roblox. Keep
// the materials used by these models explicit so invalid names fail at startup.
program += `
Enum.Material = setmetatable({}, {__index = function(_, name)
  local valid = {Wood=true, Concrete=true, Grass=true, Fabric=true, WoodPlanks=true,
    Metal=true, Slate=true, Glass=true, SmoothPlastic=true, Neon=true, Ice=true,
    Sand=true, Ground=true}
  assert(valid[name], "Unknown decoration material: " .. name)
  return name
end})
`;
program += '\nlocal Furniture = (function()\n' + await read('src/shared/FurnitureCatalog.luau') + '\nend)()\n';
program += '\nlocal Decorations = (function()\n' + await read('src/server/Map/Decorations.luau') + '\nend)()\n';
program += (await read('scripts/decorations.luau'))
  .replace('-- BUILD_SOURCE --', () => section('local function key(', '-- Rebuilds only what changed'))
  .replace('-- PREVIEWS_SOURCE --', () => section('local function buildPreviews(', 'function FurnitureService.start()'));
const temporary = await mkdtemp(join(tmpdir(), 'fishing-decorations-'));
try {
  const target = join(temporary, 'decorations.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute.exe', ['run', target], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Decoration checks failed (' + result.status + ')');
} finally {
  if (dirname(resolve(temporary)) !== resolve(tmpdir())) throw new Error('Unexpected temporary directory');
  await rm(temporary, { recursive: true, force: true });
}
