// Execute construction rules and geometry against production Luau with recording Roblox doubles.
// `--static` checks module wiring only and deliberately does not claim runtime verification.
import assert from 'node:assert/strict';
import {readFile, writeFile, mkdtemp, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = path => readFile(join(root, path), 'utf8');
const files = {
  catalog: 'src/shared/BuildingCatalog.luau', renderer: 'src/shared/BuildingRenderer.luau',
  service: 'src/server/BuildingService.luau', editor: 'src/client/StructureEditor.luau',
  data: 'src/server/AnglerData.luau', server: 'src/server/init.server.luau',
  build: 'src/client/BuildMode.luau', rules: 'scripts/building.luau',
  geometry: 'scripts/building-geometry.luau', cityMocks: 'scripts/check-city.mjs',
};
const sources = Object.fromEntries(await Promise.all(Object.entries(files).map(async ([name,path]) => [name,await read(path)])));
assert.match(sources.server, /require\(script\.BuildingService\)\.start\(\)/, 'Server must start the construction service');
assert.match(sources.data, /Building/, 'Angler profiles must retain construction saves');
assert.match(sources.build, /StructureEditor/, 'Build mode must expose structural editing');
assert.match(sources.service, /OwnerUserId/, 'Construction service must resolve plot ownership');
assert.match(sources.service, /updateProgress/, 'Building transactions must use persistent profile updates');
for (const action of ['Place','Paint','Remove','Move','Undo','Redo']) {
  assert(sources.service.includes(`"${action}"`) || sources.service.includes(`'${action}'`), `Server action missing: ${action}`);
}
assert.match(sources.renderer, /BuildingId/, 'Geometry needs stable structural selection IDs');
assert.match(sources.renderer, /CanCollide/, 'Structural rendering must manage physical walls');
assert.match(sources.editor, /InvokeServer/, 'Editor must submit authoritative requests');
console.log('Building module wiring: server startup, persistence, client integration, and editing actions present.');
if (process.argv.includes('--static')) {
  console.log('Static checks only; Luau behavior and Studio visuals were not executed.');
  process.exit(0);
}

let program = `local Building = (function()\n${sources.catalog}\nend)()\n`;
program += sources.rules.replace("local Building = require('../src/shared/BuildingCatalog')", '');
const mocks = sources.cityMocks.match(/const mocks = String.raw`([\s\S]*?)`;/)?.[1];
assert(mocks, 'Geometry recording doubles were not found');
program += '\nlocal output = print\n' + mocks;
program += '\nlocal Renderer = (function()\n' + sources.renderer.replace('local Catalog = require(script.Parent.BuildingCatalog)', 'local Catalog = Building') + '\nend)()\n';
program += sources.geometry.replace("local Building = require('../src/shared/BuildingCatalog')", '').replace("local Renderer = require('../src/shared/BuildingRenderer')", '');
const gridStart = sources.build.indexOf('\tlocal function showGrid()');
const gridEnd = sources.build.indexOf('\n\t\tif site == "Company" then', gridStart);
assert(gridStart >= 0 && gridEnd > gridStart, 'Construction grid branch was not found');
program += `\ndo
local houseFrame=CFrame.new(100,5,-200)*CFrame.Angles(0,math.pi/2,0)
local floorY,site,grid=0.16,nil,nil
local spacing,height=4.5,24
local structures={isActive=function() return true end,gridSize=function() return spacing end,elevation=function() return height end}
local BaseGrid={CELL_SIZE=4.5}
local rgb=Color3.fromRGB
local function make(class,parent,properties)
 local item=Instance.new(class)
 for key,value in properties do item[key]=value end
 item.Parent=parent
 return item
end
${sources.build.slice(gridStart,gridEnd)}
end
showGrid()
check(#grid:GetChildren()==41,'Home and shop construction grid must align with their half-cell borders')
for _,line in grid:GetChildren() do
 check(math.abs(houseFrame:PointToObjectSpace(line.Position).Y-24.32)<0.001,'Construction grid must follow the selected floor above its finish')
 check(not line.CanCollide and not line.CanQuery and not line.CanTouch,'Construction grid must leave physics and pointer rays unchanged')
end
grid:Destroy();spacing=2.25;showGrid()
check(#grid:GetChildren()==78,'Changing grid size must redraw the construction lattice')
grid:Destroy();site='Company';floorY=0;spacing=4.5;height=12;showGrid()
check(#grid:GetChildren()==40,'Company construction grid must use its full plot bounds')
grid:Destroy()
for _,where in {'Home','Company'} do
 site=if where=='Home' then nil else where
 floorY=if site=='Company' then 0 else 0.16
 for _,size in {4.5,2.25,1.125} do
  spacing=size
  showGrid()
  local columns,rows={},{}
  for _,line in grid:GetChildren() do
   local p=houseFrame:PointToObjectSpace(line.Position)
   if line.Size.X<0.04 then columns[string.format('%.4f',p.X)]=true end
   if line.Size.Z<0.04 then rows[string.format('%.4f',p.Z)]=true end
   check(math.abs(p.Y-Building.planeHeight(site,height/Building.LEVEL_HEIGHT))<0.001,'Every visible grid line must use the same projection plane as drawing')
  end
  for _,area in Building.Bounds[where] do
   local x=Building.snap(area[1]+2.3*size,size,site)
   local z=Building.snap(area[2]+2.3*size,size,site)
   check(columns[string.format('%.4f',x)]==true and rows[string.format('%.4f',z)]==true,'Both snapped wall axes must coincide with rendered lines at every spacing and site')
   check(math.abs(Building.snap(x+0.49*size,size,site)-x)<0.001,'Nearest-line snapping must preserve the selected grid node')
  end
  grid:Destroy()
 end
end
end\n`;
program += '\noutput("Building geometry: " .. checks .. " cutout, restoration, preview, and structural selection checks passed (recording doubles; no Studio rendering).")\n';
// Parsing the complete modules catches syntax errors outside paths covered by the rule tests.
for (const name of ['renderer','service','editor','build']) program += `\nlocal function parse_${name}()\n${sources[name]}\nend\n`;
const folder = await mkdtemp(join(tmpdir(), 'building-checks-'));
try {
  const target = join(folder, 'building.luau');
  await writeFile(target, program);
  const runtime = process.env.LUTE || 'lute';
  const result = spawnSync(runtime, ['run',target], {cwd:root,encoding:'utf8',timeout:60000,maxBuffer:4*1024*1024});
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw new Error(`Could not execute ${runtime}: ${result.error.message}. Set LUTE to the installed Lute executable.`, {cause:result.error});
  if (result.status !== 0) throw new Error(`Building runtime checks failed (${result.status})`);
  const saved = spawnSync(runtime, ['run',join(root,'scripts/building-persistence.luau')], {cwd:root,encoding:'utf8',timeout:60000,maxBuffer:4*1024*1024});
  if (saved.stdout) process.stdout.write(saved.stdout);
  if (saved.stderr) process.stderr.write(saved.stderr);
  if (saved.error) throw saved.error;
  if (saved.status !== 0) throw new Error(`Building persistence checks failed (${saved.status})`);
} finally {
  await rm(folder,{recursive:true,force:true});
}
