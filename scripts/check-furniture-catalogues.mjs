// Execute furniture catalogue grouping and real placement ghosts with recording doubles.
import {readFile, writeFile, mkdtemp, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = name => readFile(join(root, name), 'utf8');
const [catalog, build, preview, source] = await Promise.all([
  read('src/shared/FurnitureCatalog.luau'), read('src/client/BuildMode.luau'),
  read('src/client/FurniturePreview.luau'), read('scripts/check-city.mjs'),
]);
const mocks = source.match(/const mocks = String.raw`([\s\S]*?)`;/)?.[1];
if (!mocks) throw new Error('Recording geometry doubles were not found');
const first = build.indexOf('\tlocal function plate(');
const last = build.indexOf('\n\t-- ScreenPointToRay', first);
if (first < 0 || last <= first) throw new Error('Placement preview hooks were not found');
const program = `local output=print
${mocks}
local Furniture=(function()
${catalog}
end)()
local FurniturePreview=(function()
${preview}
end)()
local categories={}
for _,category in Furniture.Categories do categories[category.Id]=true end
for _,id in Furniture.Order do
 check(categories[Furniture.category(id)]==true,'Each furniture type needs a real catalogue')
 check(Furniture.matchesCategory(id,'All'),'All must retain every furniture type')
 local count=0
 for _,category in Furniture.Categories do if category.Id~='All' and Furniture.matchesCategory(id,category.Id) then count+=1 end end
 check(count==1,'Each item belongs to exactly one catalogue')
end
for _,id in Furniture.KitOrder do check(categories[Furniture.category(id)]==true,'Company kit must have a catalogue') end
check(Furniture.matchesCategory('PottedPlant','Plants') and not Furniture.matchesCategory('PottedPlant','Kitchen'),'Plant catalogue must exclude kitchen furniture')
check(Furniture.matchesCategory('GrillStation','Kitchen') and Furniture.matchesCategory('KitchenStorage','Storage'),'Kitchen and storage catalogues must remain separate')

-- The template pivot deliberately differs from the origin; placement must still
-- preserve the builder's local coordinates under both translation and rotation.
function methods:GetPivot() return self._props.Pivot or CFrame.identity end
function methods:PivotTo(frame)
 local delta=frame*self:GetPivot():Inverse()
 for _,item in self:GetDescendants() do if item:IsA('BasePart') then item.CFrame=delta*item.CFrame end end
 self._props.Pivot=frame
end
local function make(class,parent,properties)
 local item=Instance.new(class)
 for key,value in properties do item[key]=value end
 item.Parent=parent
 return item
end
local remotes=make('Folder',workspace,{Name='Furniture'})
local templates=make('Folder',remotes,{Name='Previews'})
local template=make('Model',templates,{Name='PottedPlant',Pivot=CFrame.new(2,2,0)})
local firstFrame=CFrame.new(-0.5,1,0)
local secondFrame=CFrame.new(0.5,2.5,0.2)
make('Part',template,{Name='Pot',CFrame=firstFrame,Size=Vector3.new(2,2,2),Color=Color3.fromRGB(100,80,60),Transparency=0})
make('Part',template,{Name='Leaf',CFrame=secondFrame,Size=Vector3.new(1,3,1),Color=Color3.fromRGB(50,180,80),Transparency=0.65})
local held={ItemId='PottedPlant',R=0}
local site='Company'
local spot={X=9,Z=-9,R=0}
local houseFrame=CFrame.new(150,8,-90)*CFrame.Angles(0,math.pi/2,0)
local preview,ghostParts=nil,{}
local HEIGHTS={}
local rgb=Color3.fromRGB
local ROOM,BLOCKED,FITS=rgb(96,200,120),rgb(226,72,60),rgb(84,192,92)
local function clearPreview() if preview then preview:Destroy() end preview=nil;ghostParts={} end
${build.slice(first,last)}
buildPreview()
updatePreview()
local ghost=preview:FindFirstChild('ItemGhost')
check(ghost and not preview:FindFirstChild('Body'),'The visible ghost must use actual furniture geometry rather than a box')
check(ghost:FindFirstChild('Pot') and ghost:FindFirstChild('Leaf'),'All distinctive furniture parts must be visible in the ghost')
local placedFrame=Furniture.frame(houseFrame,{ItemId=held.ItemId,X=spot.X,Z=spot.Z,R=held.R},site)
check((ghost:FindFirstChild('Pot').Position-(placedFrame*firstFrame).Position).Magnitude<0.001,'Ghost placement must retain builder coordinates instead of shifting by its pivot')
check(ghost:FindFirstChild('Leaf').Transparency==0.65,'Transparent furniture details must remain transparent')
for _,part in preview:GetDescendants() do
 if part:IsA('BasePart') then check(not part.CanCollide and not part.CanQuery and not part.CanTouch,'Ghost geometry must never affect physics or pointer rays') end
end
held.R=1
updatePreview()
placedFrame=Furniture.frame(houseFrame,{ItemId=held.ItemId,X=spot.X,Z=spot.Z,R=held.R},site)
check(ghost==preview:FindFirstChild('ItemGhost'),'R rotation must move the existing ghost without rebuilding it')
check((ghost:FindFirstChild('Pot').Position-(placedFrame*firstFrame).Position).Magnitude<0.001,'R must rotate the complete furniture mesh by a quarter turn')
local outline=preview:FindFirstChild('GhostOutline')
check(outline and outline.OutlineColor.G==FITS.G,'Valid placements must have a green outline')
spot.Reason='Blocked'
updatePreview()
check(outline.OutlineColor.R==BLOCKED.R and preview:FindFirstChild('Access').Color.R==BLOCKED.R,'Invalid placement must change outline and footprint together')
check(preview:FindFirstChild('FacingLeft') and preview:FindFirstChild('FacingRight'),'The ground arrow must show facing direction clearly')
local arrowLocal=placedFrame:PointToObjectSpace(preview:FindFirstChild('FacingArrow').Position)
check(arrowLocal.Y<0.5 and arrowLocal.Z>Furniture.Items.PottedPlant.Depth/2,'Facing arrow must sit on the floor in front of the item')
clearPreview()
check(preview==nil and #ghostParts==0,'Clearing a held item must release its real ghost and color cache')
check(template:FindFirstChild('Pot').Transparency==0,'Preview transparency must never alter authoritative templates')
output('Furniture catalogues: '..checks..' classification, real ghost, rotation, facing, and collision checks passed (recording doubles; no Studio rendering).')
`;
const directory = await mkdtemp(join(tmpdir(), 'furniture-catalogues-'));
try {
  const file = join(directory, 'furniture.luau');
  await writeFile(file, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', file], {cwd:root, encoding:'utf8', timeout:60000});
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Furniture catalogue checks failed (${result.status})`);
} finally { await rm(directory, {recursive:true,force:true}); }
