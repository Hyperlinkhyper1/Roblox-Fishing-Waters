// Run the production station and train builders; audit exposed coplanar faces.
import {readFile, writeFile, mkdtemp, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';
import {spawnSync} from 'node:child_process';

const root = resolve(import.meta.dirname, '..');
const read = path => readFile(join(root, path), 'utf8');
const mocks = (await read('scripts/check-city.mjs')).match(/const mocks = String.raw`([\s\S]*?)`;/)[1];
let program = 'local output = print\n' + mocks + String.raw`
local debug = {profilebegin=function() end, profileend=function() end}
function workspace:BulkMoveTo(parts, frames) for i,p in parts do p.CFrame=frames[i] end end
local loaded, loaders = {}, {}
local script = {Parent={LowPoly={Name='LowPoly'},CityMetro={Name='CityMetro'}}}
local function require(target)
  local name=if type(target)=='string' then target else target.Name
  if not loaded[name] then loaded[name]=loaders[name]() end
  return loaded[name]
end
`;
for (const [name, file] of Object.entries({
  LowPoly:'src/server/Map/LowPoly.luau', CityMetro:'src/server/Map/CityMetro.luau',
  MetroStations:'src/server/Map/MetroStations.luau', MetroTrain:'src/shared/MetroTrain.luau',
})) program += `\nloaders[${JSON.stringify(name)}]=function()\n${await read(file)}\nend\n`;
// Reproduce a baked station made before the repair pass was introduced.
const legacyCity = (await read('src/server/Map/CityMetro.luau')).replace('\tCityMetro.ensureSurfaces(metro, origin)\n', '');
program += `\nloaders.CityMetroLegacy=function()\n${legacyCity}\nend\n`;
program += '\n' + await read('scripts/metro-surfaces.luau') + String.raw`
local function audit(root,label)
  local hits=surfaceOverlaps(root)
  local groups={}
  for _,hit in hits do
    local key=hit.a.Name..' / '..hit.b.Name
    groups[key]=(groups[key] or 0)+1
  end
  for key,count in groups do output(label..': '..key..' ('..count..')') end
  output(label..': '..#hits..' exposed coplanar overlaps')
  check(#hits==0,label..' must have no exposed coplanar overlaps')
end
local train,doors=require('MetroTrain').build(workspace,CFrame.identity,false)
for _,open in {0,0.25,0.5,1} do require('MetroTrain').pose(train,doors,CFrame.identity,open); audit(train,'Train '..open) end
local city=Instance.new('Model'); city.Parent=workspace
local CityMetro,Stations=require('CityMetro'),require('MetroStations')
CityMetro.build(city,v3(7000,0,7000),8,{-380,-118,-116,30})
local stop=Stations.ensureCity(city)
audit(stop,'City')
local function geometry(model)
  local result={}
  for _,p in model:GetDescendants() do
    if p:IsA('BasePart') then table.insert(result,{name=p.Name,size=p.Size,frame=p.CFrame,part=p}) end
  end
  return result
end
local function sameGeometry(a,b,label,identity)
  check(#a==#b,label..' retains every part')
  for i,p in a do
    local q=b[i]
    check(p.name==q.name and (p.size-q.size).Magnitude<0.00001 and (p.frame.Position-q.frame.Position).Magnitude<0.00001,label..' matches fresh geometry: '..p.name)
    if identity then check(p.part==q.part,label..' preserves part identity: '..p.name) end
  end
end
local fresh=geometry(stop)
check(Stations.ensureCity(city)==stop,'Fresh station ensure is idempotent')
sameGeometry(fresh,geometry(stop),'Fresh repeated ensure',true)
local function legacy()
  local old=Instance.new('Model'); old.Parent=workspace
  require('CityMetroLegacy').build(old,v3(7000,0,7000),8,{-380,-118,-116,30})
  return old
end
local old=legacy()
local oldMetro=old:FindFirstChild('HafenMitte')
local platforms=oldMetro:FindFirstChild('MetroPlatforms')
local migrated=Stations.ensureCity(old)
check(platforms.Parent==migrated,'Legacy migration keeps the original platform model')
sameGeometry(fresh,geometry(migrated),'Legacy room migration',false)
local baked=legacy()
local repair=CityMetro.ensureSurfaces
CityMetro.ensureSurfaces=function() end
local bakedStop=Stations.ensureCity(baked)
CityMetro.ensureSurfaces=repair
check(#surfaceOverlaps(bakedStop)>200,'Baked fixture reproduces the original city z-fighting')
local captured=geometry(bakedStop)
local dock=bakedStop:FindFirstChild('TrainDock')
check(Stations.ensureCity(baked)==bakedStop,'Baked migration retains the existing stop')
check(bakedStop:FindFirstChild('TrainDock')==dock,'Baked migration preserves service controls')
sameGeometry(fresh,geometry(bakedStop),'Baked migration',false)
for i,p in geometry(bakedStop) do check(p.part==captured[i].part,'Baked repair preserves part identity') end
audit(bakedStop,'Baked city')
local repaired=geometry(bakedStop)
Stations.ensureCity(baked)
sameGeometry(repaired,geometry(bakedStop),'Baked repeated ensure',true)
output('Metro surfaces: '..checks..' geometry and saved-map assertions passed')
`;
const temporary = await mkdtemp(join(tmpdir(), 'metro-surfaces-'));
try {
  const target = join(temporary, 'surfaces.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], {cwd:root, encoding:'utf8', timeout:60000, maxBuffer:1<<22});
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.status) {
    const line = Number((result.stderr || '').match(/surfaces\.luau:(\d+):/)?.[1]);
    if (line) console.error(program.split('\n').slice(line - 3, line + 2).join('\n'));
  }
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} finally {
  await rm(temporary, {recursive:true, force:true});
}
