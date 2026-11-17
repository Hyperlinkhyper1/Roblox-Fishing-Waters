// Exercise the production tiled LOD sampler with recording geometry mocks.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = resolve(import.meta.dirname, '..');
const city = await readFile(join(root, 'scripts/check-city.mjs'), 'utf8');
const mocks = city.match(/const mocks = String.raw`([\s\S]*?)`;/)[1];
const source = (await readFile(join(root, 'src/server/Map/Lod.luau'), 'utf8'))
  .replace(/return Lod\s*$/, 'Lod._testTiledShell = tiledShell\nreturn Lod\n');
const program = 'local output = print\n' + mocks + String.raw`
local fakeClock, waits = 0, 0
local os = {clock=function() fakeClock += 0.001; return fakeClock end}
task.wait = function() waits += 1 end
local expected, casts, maxFilter = {}, 0, 0
function methods:Spherecast(origin, radius, direction, params)
  casts += 1
  local filter = params.FilterDescendantsInstances
  maxFilter = math.max(maxFilter, #filter)
  for _, part in expected do
    local p, h = part.Position, halfExtent(part)
    if origin.X >= p.X-h.X-radius and origin.X <= p.X+h.X+radius
      and origin.Z >= p.Z-h.Z-radius and origin.Z <= p.Z+h.Z+radius then
      check(table.find(filter, part) ~= nil, 'A potentially intersecting part must be in the cast filter')
    end
  end
  return nil
end
local script = {Parent={LowPoly={}}}
local require = function() return {triangle=function() end} end
local function loadLod()
` + source + String.raw`
end
local Lod = loadLod()
local island = Instance.new('Model'); island.Name = 'Harbour Isle'; island.Parent = workspace
local ground = Instance.new('Model'); ground.Name = 'Ground'; ground.Parent = island
for x = 0, 19 do for z = 0, 19 do
  local part = Instance.new('Part'); part.Size = v3(8, 1, 8)
  part.CFrame = CFrame.new(x * 220, 4, z * 220); part.Parent = ground
  table.insert(expected, part)
end end
local wide = Instance.new('Part'); wide.Size = v3(600, 1, 60)
wide.CFrame = CFrame.new(192, 4, 192); wide.Parent = ground; table.insert(expected, wide)
local shell = Instance.new('Model')
Lod._testTiledShell(shell, island, expected)
check(casts > 0 and maxFilter < #expected / 4, 'Casts use local candidates rather than the whole island')
check(waits > 10, 'Long indexing and sampling work yields repeatedly')
output('LOD spatial sampler: ' .. checks .. ' checks passed; ' .. casts .. ' casts, largest filter ' .. maxFilter .. ', ' .. waits .. ' yields')
`;
const temporary = await mkdtemp(join(tmpdir(), 'lod-spatial-'));
try {
  const path = join(temporary, 'test.luau');
  await writeFile(path, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', path], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.status) {
    const line = Number((result.stderr || '').match(/test\.luau:(\d+):/)?.[1]);
    if (line) process.stderr.write(program.split('\n').slice(line - 2, line + 1).join('\n') + '\n');
  }
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} finally { await rm(temporary, {recursive:true, force:true}); }
