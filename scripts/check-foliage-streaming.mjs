// Exercise the production foliage controller under island-sized streaming bursts.
import {readFile, writeFile, mkdtemp, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';
import {spawnSync} from 'node:child_process';

const root = resolve(import.meta.dirname, '..');
const read = p => readFile(join(root, p), 'utf8');
const city = await read('scripts/check-city.mjs');
const mocks = city.match(/const mocks = String.raw`([\s\S]*?)`;/)[1];
const foliage = (await read('src/client/SeasonFoliage.luau'))
  .replace('require(ReplicatedStorage.Shared.Seasons)', 'Seasons')
  .replace('require(ReplicatedStorage.Shared.Biomes)', 'Biomes');
const harness = String.raw`
local function event()
  local callbacks = {}
  return {Connect=function(_, f) table.insert(callbacks,f); return {Disconnect=function() end} end,
    Fire=function(_,...) for _,f in table.clone(callbacks) do f(...) end end,
    Wait=function() coroutine.yield() end}
end
local heartbeat, added, removed, changed = event(), event(), event(), event()
local clock, scanCost, reads, writes, snapshots = 0, 0, 0, 0, 0
local os = {clock=function() return clock end}
local oldNewIndex, oldChildren = Inst.__newindex, methods.GetChildren
Inst.__newindex = function(self,key,value)
  if key=='Color' then writes+=1 end
  oldNewIndex(self,key,value)
end
methods.GetChildren = function(self) reads+=1; clock+=scanCost; return oldChildren(self) end
methods.GetDescendants = function() snapshots+=1; error('Foliage must not snapshot whole subtrees') end
function methods:FindFirstAncestorWhichIsA(class)
  local parent = self.Parent
  while parent do if parent:IsA(class) then return parent end; parent=parent.Parent end
end
function C3.__index:ToHSV()
  local max, min = math.max(self.R,self.G,self.B), math.min(self.R,self.G,self.B)
  local delta = max-min
  local h = 0
  if delta>0 then
    if max==self.R then h=((self.G-self.B)/delta)%6
    elseif max==self.G then h=(self.B-self.R)/delta+2 else h=(self.R-self.G)/delta+4 end
    h/=6
  end
  return h, if max==0 then 0 else delta/max, max
end
local season = 'Winter'
local Seasons = {current=function() return season end}
local Biomes = {at=function(p) return {id=if p.X>10000 then 'tropical' else 'temperate'} end}
local terrain = {GetMaterialColor=function() return Color3.fromRGB(60,120,50) end, SetMaterialColor=function() end}
workspace.Terrain = terrain
function workspace:GetAttributeChangedSignal() return changed end
local player = {}
local partAdded, partRemoved = event(), event()
local collection = {
  GetInstanceAddedSignal=function(_, tag) return if tag == 'SeasonFoliagePart' then partAdded else added end,
  GetInstanceRemovedSignal=function(_, tag) return if tag == 'SeasonFoliagePart' then partRemoved else removed end,
}
game.GetService = function(_,name)
  return ({CollectionService=collection, Players={LocalPlayer=player}, RunService={Heartbeat=heartbeat}, ReplicatedStorage={Shared={}}})[name]
end
task.spawn = function(callback)
  local thread=coroutine.create(callback)
  local ok,message=coroutine.resume(thread)
  assert(ok,message)
end
task.wait = function() coroutine.yield() end
local controller = (function()
` + foliage + String.raw`
end)()
local green = Color3.fromRGB(60,120,50)
local function leaf(parent,x)
  local part=Instance.new('Part'); part.Color=green; part.Material=Enum.Material.LeafyGrass
  part.Position=v3(x or 0,20,0); part.Parent=parent
  return part
end
local function isGreen(part) return part.Color.R==green.R and part.Color.G==green.G end
local function tick()
  writes,reads=0,0
  heartbeat:Fire(1/60)
  check(writes<=120 and reads<=120,'All streamed pieces share one count budget')
end
local startup=Instance.new('Model'); startup.Parent=workspace
local existing={}
for i=1,600 do existing[i]=leaf(startup) end
writes,reads=0,0
controller.start()
check(writes==0 and reads==0 and snapshots==0,'Startup only queues work and never snapshots workspace')
tick()
check(writes>0 and writes<600,'Startup foliage is spread across frames')
for i=1,20 do tick() end
for _,part in existing do check(not isGreen(part),'All initial foliage eventually receives the winter tint') end

local arriving={}
for i=1,30 do
  local piece=Instance.new('Model'); piece:AddTag('LodPiece'); piece.Parent=workspace
  local parts={}
  for j=1,50 do parts[j]=leaf(piece) end
  table.insert(arriving,{piece=piece,parts=parts})
end
writes,reads=0,0
for _,record in arriving do added:Fire(record.piece); added:Fire(record.piece) end
check(writes==0 and reads==0,'An entire island arrival does no synchronous descendant work')
local cancelled=arriving[30]
removed:Fire(cancelled.piece); cancelled.piece.Parent=nil
for i=1,70 do tick() end
for i,record in arriving do
  for _,part in record.parts do
    check(isGreen(part)==(i==30),'Only present queued pieces are tinted')
  end
end
cancelled.piece.Parent=workspace
added:Fire(cancelled.piece)
for i=1,4 do tick() end
check(not isGreen(cancelled.parts[1]),'A cancelled piece can queue again on return')

local cityLeaves={}
for i=1,180 do cityLeaves[i]=leaf(workspace); partAdded:Fire(cityLeaves[i]) end
local leaving=cityLeaves[180]
partRemoved:Fire(leaving); leaving.Parent=nil
tick()
check(writes==60 and reads==0,'City foliage streams by part under the shared frame budget')
for i=1,4 do tick() end
check(not isGreen(cityLeaves[179]) and isGreen(leaving),'Queued city leaves tint and departures cancel')

local exemptions=Instance.new('Model'); exemptions:AddTag('LodPiece'); exemptions.Parent=workspace
local tropical=leaf(exemptions,20000)
local exempt=leaf(exemptions); exempt:SetAttribute('SeasonExempt',true)
local tool=Instance.new('Tool'); tool.Parent=exemptions
local held=leaf(tool)
local humanoid=Instance.new('Model'); humanoid.Parent=exemptions
Instance.new('Humanoid').Parent=humanoid
local characterLeaf=leaf(humanoid)
local normal=leaf(exemptions)
added:Fire(exemptions)
for i=1,4 do tick() end
check(isGreen(tropical) and isGreen(exempt) and isGreen(held) and isGreen(characterLeaf),'Tropical, exempt, tool and character colours stay intact')
check(not isGreen(normal),'Ordinary foliage in the same subtree is tinted')

local slow=Instance.new('Model'); slow:AddTag('LodPiece'); slow.Parent=workspace
for i=1,100 do leaf(slow) end
added:Fire(slow)
scanCost=0.0006
tick()
check(reads<=2,'Expensive scans yield at the time budget before the count limit')
scanCost=0
for i=1,5 do tick() end
check(snapshots==0,'Neither initial nor streamed scans allocate descendant snapshots')
_G_print('Foliage streaming: '..checks..' checks passed')
`;
const temp = await mkdtemp(join(tmpdir(), 'foliage-streaming-'));
try {
  const path = join(temp, 'test.luau');
  await writeFile(path, 'local _G_print = print\n' + mocks + harness);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', path], {cwd:root, encoding:'utf8', timeout:30000});
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Foliage streaming check failed');
} finally {
  await rm(temp, {recursive:true, force:true});
}
