// Temporary preview of production Kitchen builders; no Roblox runtime required.
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { deflateSync } from 'node:zlib';

const OUT = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(OUT, '../..');
const read = path => readFileSync(join(ROOT, path), 'utf8').replace(/\r\n/g, '\n');
mkdirSync(OUT, {recursive:true});
const primitives = read('scripts/harbour-geometry.luau').split('local CFrame = {}')[0];
let runtime = read('scripts/drydock-geometry.luau').split('local dependencies =')[0]
  .replace('-- SHARED_PRIMITIVES --', primitives);
runtime += '\nlocal dependencies = {LowPoly={}}\n';
runtime += 'dependencies.Props = (function()\n' + read('src/server/Map/Props.luau')
  .replace('require(script.Parent.LowPoly)', 'dependencies.LowPoly') + '\nend)()\n';
runtime += 'local Kitchen = (function()\n' + read('src/server/Map/Kitchen.luau')
  .replace('require(script.Parent.Props)', 'dependencies.Props') + '\nend)()\n';
runtime += 'local Recipes = (function()\n' + read('src/shared/Recipes.luau') + '\nend)()\n';
runtime += String.raw`
local function vectorJson(value)
 return string.format('[%.9g,%.9g,%.9g]', value.X, value.Y, value.Z)
end
local function exportModel(id, model)
 local parts = {}
 for _, part in model:GetDescendants() do
  if not part:IsA('BasePart') then continue end
  local shape = if part.Shape == 'Ball' then 'sphere' elseif part.Shape == 'Cylinder' then 'cylinder' elseif part.ClassName == 'WedgePart' then 'wedge' else 'block'
  local color, frame = part.Color, part.CFrame
  local hex = string.format('#%02x%02x%02x', math.floor(color.R*255+0.5), math.floor(color.G*255+0.5), math.floor(color.B*255+0.5))
  table.insert(parts, string.format('{"n":"%s","s":"%s","p":%s,"z":%s,"r":[%s,%s,%s],"c":"%s","t":%.9g,"m":"%s","solid":%s}', part.Name, shape, vectorJson(part.Position), vectorJson(part.Size), vectorJson(frame.RightVector), vectorJson(frame.UpVector), vectorJson(frame.ZVector), hex, part.Transparency, tostring(part.Material), tostring(part.CanCollide)))
 end
 local _, size = model:GetBoundingBox()
 print(string.format('{"id":"%s","parts":[%s],"boundsSize":%s}',id,table.concat(parts,','),vectorJson(size)))
end
local shelf = Kitchen.buildCase(nil, CFrame.identity)
assert(shelf.Name == 'FoodCase', 'Cooked-food fixture must preserve its saved item ID')
assert(#Kitchen.CASE_SPOTS == 6, 'Cooked-food fixture must retain six inventory slots')
local checks = 0
for _, recipeId in Recipes.Order do
 for _, spot in Kitchen.CASE_SPOTS do
  local dish = Kitchen.buildDish(recipeId, Recipes.Items[recipeId].Look, spot)
  local box, size = dish:GetBoundingBox()
  local low, high = box.Position-size/2, box.Position+size/2
  assert(math.abs(low.Y-spot.Position.Y)<1e-6, recipeId..': dish must rest on slot surface')
  local supported = false
  for _,part in shelf:GetDescendants() do
   if not part:IsA('BasePart') or part.Name ~= 'Shelf' then continue end
   local top = part.Position.Y+part.Size.Y/2
   if math.abs(top-spot.Position.Y)<1e-6 then
    assert(low.X>=part.Position.X-part.Size.X/2 and high.X<=part.Position.X+part.Size.X/2, recipeId..': dish overhangs shelf width')
    assert(low.Z>=part.Position.Z-part.Size.Z/2 and high.Z<=part.Position.Z+part.Size.Z/2, recipeId..': dish overhangs shelf depth')
    supported = true
   elseif part.Position.Y > spot.Position.Y then
    assert(high.Y<part.Position.Y-part.Size.Y/2, recipeId..': dish intersects shelf above')
   end
  end
  assert(supported, recipeId..': missing shelf below display slot')
  checks += 1
  dish:Destroy()
 end
end
print('PASS: '..checks..' recipe/slot combinations rest within shelf bounds and clear the next tier')
exportModel('empty', shelf)
local looks = {'Fillet','Chips','Grilled','Skewers','Sushi','Sashimi'}
for index, spot in Kitchen.CASE_SPOTS do
 local dish = Kitchen.buildDish('Preview'..index, looks[index], spot)
 dish.Name, dish.Parent = 'PreviewDish'..index, shelf
end
exportModel('stocked', shelf)
local slots = {}
for _,spot in Kitchen.CASE_SPOTS do table.insert(slots, vectorJson(spot.Position)) end
print('{"id":"slots","spots":[' .. table.concat(slots,',') .. ']}')
`;
writeFileSync(join(OUT, 'geometry.luau'), runtime);
const output = execFileSync(process.env.LUTE ?? 'C:/Users/ayden/.lute/bin/lute.exe', ['run', join(OUT,'geometry.luau')], {cwd:ROOT,encoding:'utf8',maxBuffer:1<<27});
writeFileSync(join(OUT, 'geometry.jsonl'),output);

// Reuse this repository's dependency-free triangle rasterizer.
const renderSource = read('scripts/render-fish.mjs');
let renderer = renderSource.slice(renderSource.indexOf('// Unit shapes as triangles'), renderSource.indexOf('\nmkdirSync(OUT, { recursive: true });'));
renderer = renderer.replace(/const VIEWS = \[[\s\S]*?\n\];/, `const VIEWS = [
 ['front',[1,0,0],[0,1,0]],
 ['three-quarter',norm([1,0,-0.65]),norm([-0.25,1,-0.4])],
];`).replace('const PANEL = 360;', 'const PANEL = 700;');
renderer += `
for (const line of output.split('\\n')) {
 if(!line.startsWith('{"id"'))continue;
 const model=JSON.parse(line);
 if(!model.parts)continue;
 const tris=worldTriangles(model.parts);
 for(const [name,right,up] of VIEWS){
  const img=Buffer.alloc(PANEL*PANEL*3);
  for(let i=0;i<PANEL*PANEL;i++)img.set([48,57,68],i*3);
  renderPanel(tris,right,up,img,0,0,PANEL);
  writeFileSync(join(OUT,model.id+'-'+name+'.png'),png(PANEL,PANEL,img));
 }
 console.log(model.id+': '+model.parts.length+' parts; bounds '+model.boundsSize.join(' x '));
}
`;
const render = new Function('output','writeFileSync','join','OUT','deflateSync',renderer);
render(output,writeFileSync,join,OUT,deflateSync);
console.log('Saved production geometry and front/three-quarter PNGs in '+OUT);
