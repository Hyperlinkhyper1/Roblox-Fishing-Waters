// Run production station, train, schedule and service code against geometry/event mocks.
// Reuse the city's Roblox math/Instance mocks without building the entire city.
import {readFile, writeFile, mkdtemp, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';
import {spawnSync} from 'node:child_process';

const root = resolve(import.meta.dirname, '..');
const read = path => readFile(join(root, path), 'utf8');
const previewIndex = process.argv.indexOf('--preview');
const previewPath = previewIndex < 0 ? null : resolve(process.argv[previewIndex + 1]);
const cityCheck = await read('scripts/check-city.mjs');
const mocks = cityCheck.match(/const mocks = String.raw`([\s\S]*?)`;/)[1];
const files = {
  LowPoly: 'src/server/Map/LowPoly.luau',
  CityMetro: 'src/server/Map/CityMetro.luau',
  MetroSchedule: 'src/shared/MetroSchedule.luau', MetroTrain: 'src/shared/MetroTrain.luau',
  MetroStations: 'src/server/Map/MetroStations.luau', MetroService: 'src/server/MetroService.luau', Biomes: 'src/shared/Biomes.luau', MetroClient: 'src/client/Metro.luau',
};
let program = 'local output = print\nlocal PREVIEW = ' + Boolean(previewPath) + '\n' + mocks + String.raw`
local now = 10
local debug = {profilebegin=function() end, profileend=function() end}
CF.__eq = function(a,b) return a.p==b.p and a.r==b.r and a.u==b.u and a.b==b.b end
local bulkCalls, bulkParts = 0, 0
function workspace:BulkMoveTo(parts, frames, mode)
  check(mode==Enum.BulkMoveMode.FireCFrameChanged,'Train movement only fires CFrame changes')
  check(#parts==#frames,'Every moved part has a frame')
  bulkCalls, bulkParts = bulkCalls+1, #parts
  for index,part in parts do part.CFrame=frames[index] end
end
local function signal()
  local callbacks = {}
  return {
    Connect=function(_, callback) callbacks[callback]=true; return {Disconnect=function() callbacks[callback]=nil end} end,
    Fire=function(_, ...) for callback in table.clone(callbacks) do callback(...) end end,
  }
end
local oldIndex = Inst.__index
Inst.__index = function(self, key) return oldIndex(self, key) or self:FindFirstChild(key) end
function methods:FindFirstChildOfClass(class) return self:FindFirstChildWhichIsA(class) end
function methods:PivotTo(frame)
  local before = self.WorldPivot or CFrame.identity
  local delta = frame * before:Inverse()
  for _, p in self:GetDescendants() do if p:IsA('BasePart') then p.CFrame = delta * p.CFrame end end
  self.WorldPivot = frame
end
function methods:AddPersistentPlayer(player) self._pins = self._pins or {}; self._pins[player] = true end
function methods:RemovePersistentPlayer(player) if self._pins then self._pins[player] = nil end end
function workspace:GetServerTimeNow() return now end
local pending = {}
task.spawn = function(callback) table.insert(pending, callback) end
local function flush() local work = pending; pending = {}; for _, callback in work do callback() end end
local collection = {added=signal(), removed=signal(), tagged={}}
function collection:GetInstanceAddedSignal() return self.added end
function collection:GetInstanceRemovedSignal() return self.removed end
function collection:GetTagged() return self.tagged end
local heartbeat = signal()
local players = {PlayerRemoving=signal(), list={}}
function players:GetPlayers() return self.list end
local replicated = Instance.new('ReplicatedStorage')
local shared = Instance.new('Folder'); shared.Name='Shared'; shared.Parent=replicated
for _, name in {'MetroSchedule', 'MetroTrain'} do local m=Instance.new('ModuleScript'); m.Name=name; m.Parent=shared end
game.GetService = function(_, name)
  if name=='CollectionService' then return collection elseif name=='Players' then return players
  elseif name=='RunService' then return {Heartbeat=heartbeat} elseif name=='ReplicatedStorage' then return replicated end
  return {}
end
local messages = {}
function methods:FireClient(player, action, data) table.insert(messages, {player=player, action=action, data=data}) end
local loaded, loaders = {}, {}
local script = {Parent={LowPoly={Name='LowPoly'},CityMetro={Name='CityMetro'}}}
local function require(target)
  local name = if type(target)=='string' then target else target.Name
  if loaded[name]==nil then loaded[name]=loaders[name]() end
  return loaded[name]
end
`;
for (const [name, file] of Object.entries(files)) program += `\nloaders[${JSON.stringify(name)}] = function()\n${await read(file)}\nend\n`;
program += '\n' + await read('scripts/metro-surfaces.luau') + '\n';
// Parse the client modules too, without pretending a mock can verify their rendering.
for (const file of ['src/client/Lod.luau', 'src/client/BiomeAtmosphere.luau', 'src/server/OxygenService.luau', 'src/server/Map/PlazaHouses.luau']) {
  program += `\nlocal function syntaxOnly()\n${await read(file)}\nend\n`;
}
if (process.argv.includes('--performance-only')) {
  program += '\n' + await read('scripts/metro-performance.luau') + '\n';
} else {
program += String.raw`
local Schedule, Train, Stations, Biomes = require('MetroSchedule'), require('MetroTrain'), require('MetroStations'), require('Biomes')
for t=0, 180, 0.25 do
  local a,b=Schedule.state(t),Schedule.state(t+Schedule.PERIOD)
  check(math.abs(a.offset-b.offset)<0.001 and a.doors==b.doors and a.boarding==b.boarding, 'Exactly one period between trains')
  check(a.doors>=0 and a.doors<=1, 'Doors remain in their animation range')
end
check(not Schedule.state(2.9).boarding and Schedule.state(3).boarding and not Schedule.state(24).boarding, 'Boarding is limited to open doors')
check(Schedule.state(26).offset==0 and Schedule.state(28.99).offset>240 and Schedule.state(29).offset==-250 and Schedule.state(31).offset==0, 'Departure, tunnel and arrival positions')
check(Schedule.RIDE==5, 'A metro ride takes 5 seconds')
check(Schedule.inside(v3(-11,3,-2)) and not Schedule.inside(v3(-11,3,-6)) and not Schedule.inside(v3(90,3,0)), 'Only carriage interiors contain riders')

local home=Instance.new('Model'); home.Name='Harbour Isle'; home.Parent=workspace
local ground=Instance.new('Model'); ground.Name='Ground'; ground.Parent=home
local plaza=Instance.new('Model'); plaza.Name='Plaza'; plaza.Parent=home
local frame=CFrame.new(0,5.92,-565.25)
local function slab(parent, size, offset)
  local p=Instance.new('Part'); p.Size=size; p.CFrame=frame*CFrame.new(offset); p.Parent=parent; return p
end
slab(ground,v3(300,4,220),v3(30,-2.92,-20))
slab(plaza,v3(116,0.6,116),v3(0,-0.42,0))
local LowPoly=require('LowPoly')
LowPoly.triangle(frame*v3(80,-0.92,-28),frame*v3(106,2.5,-28),frame*v3(106,2.5,-8),frame*v3(88,-40,-18),Color3.new(0.4,0.6,0.3),ground,Enum.Material.Grass)
local legacy=Instance.new('Model'); legacy.Name='GullhavenMetro'; legacy:SetAttribute('MetroVersion',1); legacy.Parent=home
local harbour=Stations.ensureHarbour(home,plaza,frame)
local function triangleContains(part,x,z)
  local h=part.Size/2
  local edge=if part.CFrame.RightVector.Y>0 then h.X else -h.X
  local a,b,c=frame:PointToObjectSpace(part.CFrame*v3(edge,-h.Y,-h.Z)),frame:PointToObjectSpace(part.CFrame*v3(edge,-h.Y,h.Z)),frame:PointToObjectSpace(part.CFrame*v3(edge,h.Y,h.Z))
  local function side(u,v) return (x-u.X)*(v.Z-u.Z)-(z-u.Z)*(v.X-u.X) end
  local sa,sb,sc=side(a,b),side(b,c),side(c,a)
  return math.min(sa,sb,sc)>=-0.001 or math.max(sa,sb,sc)<=0.001
end
for x=80.25,105.25,1 do for z=-27.75,-8.75,1 do
  local present=false
  for _,p in ground:GetDescendants() do if p:IsA('WedgePart') and triangleContains(p,x,z) then present=true; break end end
  local expected=z<=-28+(x-80)*20/26 and not (x<96.2 and z>-24.6 and z<-11.4)
  check(present==expected,'Clipped hillside keeps all terrain outside the shaft')
end end
local function blocked(x,y,z)
  local point=frame*v3(x,y,z)
  for _, p in home:GetDescendants() do
    if p:IsA('BasePart') and p.CanCollide then
      local q,h=p.CFrame:PointToObjectSpace(point),p.Size/2
      if math.abs(q.X)<h.X-0.001 and math.abs(q.Y)<h.Y-0.001 and math.abs(q.Z)<h.Z-0.001 then return p end
    end
  end
end
for k=1,36 do
  local x,y=80+(k-0.5)*1.35,-k*0.8
  check(blocked(x,y-0.1,-18)~=nil,'Stair tread '..k..' exists')
  for _,z in {-22.5,-18,-13.5} do
    for dy=0.2,6,0.4 do check(not blocked(x,y+dy,z),'Continuous stair headroom '..k) end
  end
  if x>96.2 then
    local roof
    for dy=7,16,0.2 do roof=blocked(x,y+dy,-18); if roof then break end end
    check(roof and roof.Material~=Enum.Material.Grass,'Covered stairs have a solid lining, not exposed grass '..k)
  end
end
for x=61.5,79.5,1 do for _,z in {-22.5,-18,-13.5} do
  for y=0.2,6.2,0.5 do check(not blocked(x,y,z),'The pavilion approach stays clear') end
end end
for _, x in {129,133,141,146} do check(blocked(x,-29,-18) and not blocked(x,-23,-18),'Landing connects to the platform') end
check(blocked(74,-0.2,-18)~=nil and blocked(25,-0.3,-40)~=nil,'Recessed entrance and restored plaza have floors')
check(harbour.MetroEntranceSign.Position.X>60,'Entrance is behind the east housing row')
for _,p in harbour:GetChildren() do
  if p.Name=='DepartureBoard' and p.Position.Y>frame.Position.Y then
    local c,h=frame:PointToObjectSpace(p.Position),p.Size/2
    check(c.Z-h.Z>-12.5 and c.Z+h.Z<-11.5,'Entrance countdown is mounted on the side wall')
  end
end
local count=#home:GetDescendants()
check(Stations.ensureHarbour(home,plaza,frame)==harbour and #home:GetDescendants()==count,'Station repair is idempotent')
local replacementGround=slab(ground,v3(4,4,4),v3(84,-2.92,-18))
check(Stations.ensureHarbour(home,plaza,frame)==harbour and not replacementGround.Parent,'Regenerated ground is cut around an existing station')
local formerFloor=harbour.FormerEntrancePaving
harbour:SetAttribute('MetroVersion',2)
harbour=Stations.ensureHarbour(home,plaza,frame)
check(harbour.FormerEntrancePaving==formerFloor,'Upgrading v2 preserves the old plaza repair')
check(#home:GetDescendants()==count,'Upgrading adds no duplicate plaza fills or station parts')
local clean=Instance.new('Model'); clean.Name='Harbour Isle'; clean.Parent=workspace
local old=Instance.new('Model'); old.Name='GullhavenMetro'; old:SetAttribute('MetroVersion',2); old.Parent=clean
local upgraded=Stations.ensureHarbour(clean,nil,frame)
check(not upgraded.FormerEntrancePaving and not upgraded.FormerEntranceGround,'A v2 map with intact paving receives no overlapping restoration slabs')
clean:Destroy()
for _,p in harbour:GetDescendants() do
  if p:IsA('BasePart') then
    check(p.Size.X>0 and p.Size.Y>0 and p.Size.Z>0,'Valid station part size '..p.Name)
    if p.Position.Y<0 and p.Name~='FormerEntranceGround' and p.Name~='FormerEntrancePaving' then
      check(not Biomes.inOceanBounds(p.Position),'Station remains dry '..p.Name)
    end
  end
end
local train, doors=Train.build(harbour,harbour.TrainDock.CFrame,false)
local dock=harbour.TrainDock.CFrame
-- Test the passenger passage as a volume, including any new decorative parts.
-- Bounds are measured in train space so the station's rotation cannot hide a blockage.
local function trainBounds(part)
  local localFrame=dock:ToObjectSpace(part.CFrame)
  local half=part.Size/2
  local r,u,b=localFrame.RightVector,localFrame.UpVector,localFrame.ZVector
  local extent=v3(
    math.abs(r.X)*half.X+math.abs(u.X)*half.Y+math.abs(b.X)*half.Z,
    math.abs(r.Y)*half.X+math.abs(u.Y)*half.Y+math.abs(b.Y)*half.Z,
    math.abs(r.Z)*half.X+math.abs(u.Z)*half.Y+math.abs(b.Z)*half.Z)
  return {part=part,lo=localFrame.Position-extent,hi=localFrame.Position+extent}
end
local function passageClear(parts,label)
  local entrances=0
  for _,cx in {-46,0,46} do
    for _,dx in {-11,11} do
      for _,side in {-1,1} do
        entrances+=1
        local x=cx+dx
        local lo=v3(x-2.3,0.15,if side<0 then -6.2 else 1)
        local hi=v3(x+2.3,7.15,if side<0 then -1 else 6.2)
        for _,bounds in parts do
          local intersects=bounds.hi.X>lo.X+0.0001 and bounds.lo.X<hi.X-0.0001
            and bounds.hi.Y>lo.Y+0.0001 and bounds.lo.Y<hi.Y-0.0001
            and bounds.hi.Z>lo.Z+0.0001 and bounds.lo.Z<hi.Z-0.0001
          check(not intersects,label..' keeps entrance '..entrances..' clear of '..bounds.part.Name)
        end
      end
    end
  end
  check(entrances==12,label..' covers every entrance on both sides of all three cars')
end
local hull=Train.build(workspace,dock,true)
local hullBounds,hullParts={},0
for _,part in hull:GetDescendants() do
  if part:IsA('BasePart') then
    hullParts+=1
    check(part.Transparency==1 and part.Anchored and not part.CanTouch,'Server hull stays invisible, anchored and touch-free: '..part.Name)
    -- MetroService disables SlidingDoor collisions while passengers can board.
    if part.Name~='SlidingDoor' then table.insert(hullBounds,trainBounds(part)) end
  end
end
check(hullParts>0 and hullParts<120,'The server replicates a lightweight hull rather than decorative train geometry')
passageClear(hullBounds,'Boarding collision hull')
hull:Destroy()
for _,part in train:GetDescendants() do
  if part:IsA('BasePart') then
    check(not part.CanCollide and not part.CanQuery and not part.CanTouch,'Client visuals never obstruct physics or queries: '..part.Name)
  end
end
local function audit(root, label)
  local overlaps=surfaceOverlaps(root)
  for i, hit in overlaps do
    if i<=10 then output(label..': '..hit.a.Name..' / '..hit.b.Name..' area '..string.format('%.3f',hit.area)) end
  end
  output(label..': '..#overlaps..' exposed coplanar overlaps')
  check(#overlaps==0,label..' must have no exposed coplanar overlaps')
  return #overlaps
end
audit(train,'Train closed')
check(audit(harbour,'Harbour')==0,'Gullhaven station has no exposed coplanar surfaces')
check(#train:GetDescendants()>250,'Three-car train has an interior and detailed exterior')
local originals, doorByPart = {}, {}
for _,part in train:GetDescendants() do if part:IsA('BasePart') then originals[part]=dock:ToObjectSpace(part.CFrame) end end
for _,door in doors do doorByPart[door.part]=door end
Train.pose(train,doors,harbour.TrainDock.CFrame,1)
audit(train,'Train open')
local openBounds={}
for _,part in train:GetDescendants() do
  if part:IsA('BasePart') and part.Transparency<1 then table.insert(openBounds,trainBounds(part)) end
end
passageClear(openBounds,'Fully open train')
check((harbour.TrainDock.CFrame:ToObjectSpace(doors[1].part.CFrame).Position-doors[1].closed.Position).Magnitude>2,'Doors slide clear of the entrance')
check(bulkCalls==1 and bulkParts==#doors,'Opening parked doors only moves door panels and glass')
Train.pose(train,doors,dock*CFrame.new(),1)
check(bulkCalls==1,'An unchanged pose does no engine work')
local travelled=dock*CFrame.new(123,0,-8)*CFrame.Angles(0,0.6,0)
Train.pose(train,doors,travelled,0.4)
check(bulkCalls==2 and bulkParts>#doors,'A moving train batches the body and doors into one call')
for part,closed in originals do
  local door=doorByPart[part]
  local expected=travelled*closed*(if door then CFrame.new(door.direction*0.4*2.7,0,0) else CFrame.identity)
  check((part.Position-expected.Position).Magnitude<0.0001 and (part.CFrame.RightVector-expected.RightVector).Magnitude<0.0001,'Moving preserves part geometry and door offsets: '..part.Name)
end
Train.pose(train,doors,travelled,0.8)
check(bulkCalls==3 and bulkParts==#doors,'Doors can animate without moving a stopped body')
Train.pose(train,doors,dock,1)
if PREVIEW then
  for _,p in harbour:GetDescendants() do
    if p:IsA('BasePart') and p.Transparency<0.9 then
      local points={}
      for _,x in {-0.5,0.5} do for _,y in {-0.5,0.5} do for _,z in {-0.5,0.5} do
        local q=frame:PointToObjectSpace(p.CFrame*v3(x*p.Size.X,y*p.Size.Y,z*p.Size.Z))
        table.insert(points,string.format('%.3f,%.3f,%.3f',q.X,q.Y,q.Z))
      end end end
      output('@'..p.Name..'|'..string.format('%d,%d,%d',p.Color.R*255,p.Color.G*255,p.Color.B*255)..'|'..table.concat(points,' '))
    end
  end
end
train:Destroy()
local city=Instance.new('Model'); city.Name='Modern City'; city.Parent=workspace
require('CityMetro').build(city,v3(7000,0,7000),8,{-380,-118,-116,30})
local metro=city:FindFirstChild('HafenMitte')
local oldTrain=metro:FindFirstChild('MetroTrain')
local rooms=metro:FindFirstChild('MetroPlatforms')
local town=Stations.ensureCity(city)
audit(town,'City')
check(oldTrain.Parent==nil and rooms.Parent==town,'Legacy train is replaced and destination floor is pinned with the stop')
check(Stations.ensureCity(city)==town and rooms.Parent==town,'Harbour detail upgrades preserve migrated city station rooms')

local function passenger(name,stop)
  local p=Instance.new('Player'); p.Name=name; p.Parent=workspace; table.insert(players.list,p)
  local c=Instance.new('Model'); c.Parent=workspace; p.Character=c
  local h=Instance.new('Humanoid'); h.Health=100; h.AutoRotate=true; h.Parent=c
  local r=Instance.new('Part'); r.Name='HumanoidRootPart'; r.Parent=c; r.Anchored=false
  c.WorldPivot=CFrame.identity; c:PivotTo(stop.Boarding.CFrame)
  function p:RequestStreamAroundAsync() if self.streamHook then self.streamHook() end end
  return p,c,h,r
end
for _, stop in {harbour,town} do stop.Boarding.MetroBoardPrompt.Triggered=signal() end
collection.tagged={harbour}
local service=require('MetroService'); service.start(); service.start()
local function tick(t) now=t; heartbeat:Fire(0.1) end
local p,c,h,r=passenger('Outbound',harbour)
local q,qc,qh,qr=passenger('Inbound',town)
local leave,lc,lh,lr=passenger('Walks back out',harbour)
tick(10)
check(not harbour.Boarding.MetroBoardPrompt.Enabled,'No service before both termini exist')
collection.added:Fire(town); tick(10)
check(harbour.Boarding.MetroBoardPrompt.Enabled and town.Boarding.MetroBoardPrompt.Enabled,'Both doors share the schedule')
c:PivotTo(CFrame.new(500,0,0)); harbour.Boarding.MetroBoardPrompt.Triggered:Fire(p)
check(r.Position.X==500,'Remote prompt exploits are rejected')
c:PivotTo(harbour.Boarding.CFrame); h.Health=0; harbour.Boarding.MetroBoardPrompt.Triggered:Fire(p); h.Health=100
check(not Schedule.inside(harbour.TrainDock.CFrame:PointToObjectSpace(r.Position)),'Dead players cannot board')
harbour.Boarding.MetroBoardPrompt.Triggered:Fire(p)
check(Schedule.inside(harbour.TrainDock.CFrame:PointToObjectSpace(r.Position)) and not p:GetAttribute('MetroRiding'),'Prompt enters the train and waits for departure')
qc:PivotTo(town.TrainDock.CFrame*CFrame.new(11,3.5,-2))
lc:PivotTo(harbour.TrainDock.CFrame*CFrame.new(-11,3.5,-2)); lc:PivotTo(harbour.Arrival.CFrame)
tick(24)
check(not leave:GetAttribute('MetroRiding') and not lr.Anchored,'Walking out before door closure cancels boarding')
check(p:GetAttribute('MetroRiding') and q:GetAttribute('MetroRiding') and r.Anchored and qr.Anchored,'Walking and prompt riders depart together in opposite directions')
check(not harbour.Boarding.MetroBoardPrompt.Enabled,'Boarding stops when doors close')
local before=r.Position; tick(27.5)
check((r.Position-before).Magnitude>20,'Passengers travel with the departing train')
tick(28)
check((r.Position-town.TrainDock.Position).Magnitude>1000,'A transfer waits for destination streaming')
flush(); tick(28.5)
check((r.Position-town.TrainDock.Position).Magnitude<400 and (qr.Position-harbour.TrainDock.Position).Magnitude<400,'Opposing trains transfer together during the tunnel animation')
check(town._pins[p] and harbour._pins[q],'Both arriving platforms are pinned before transfer')
tick(32)
check(not r.Anchored and h.AutoRotate and not p:GetAttribute('MetroRiding'),'Arrival restores movement')
check((r.Position-town.Arrival.Position).Magnitude<0.01 and (qr.Position-harbour.Arrival.Position).Magnitude<0.01,'Both directions unload onto the destination platform')
lc:PivotTo(harbour.TrainDock.CFrame*CFrame.new(11,3.5,-2))
qc:PivotTo(harbour.TrainDock.CFrame*CFrame.new(-11,3.5,-2)); tick(53)
check(qr.Anchored,'The next service captures another passenger')
lh.Health=0
q.Character=Instance.new('Model'); q.Character.Parent=workspace; tick(54); flush()
check(not qr.Anchored and not q:GetAttribute('MetroRiding'),'Respawn cancels the captured avatar and releases its anchor')
check(not lr.Anchored and not leave:GetAttribute('MetroRiding'),'Death also releases the train anchor')
tick(61); c:PivotTo(town.TrainDock.CFrame*CFrame.new(-11,3.5,-2)); tick(82); flush()
check(r.Anchored,'Return trip boards normally')
harbour.Parent=nil; collection.removed:Fire(harbour)
check(not r.Anchored and not p:GetAttribute('MetroRiding') and (r.Position-town.Arrival.Position).Magnitude<0.01,'Station removal recovers riders to the surviving platform')
check(not harbour.Boarding.MetroBoardPrompt.Enabled,'Removed platforms cannot accept boarding')

harbour.Parent=home; collection.added:Fire(harbour); tick(90)
c:PivotTo(town.TrainDock.CFrame*CFrame.new(11,3.5,-2)); tick(111)
town.Parent=nil; collection.removed:Fire(town); tick(112)
check(r.Anchored,'A removed source keeps its passenger safe while the destination streams')
flush()
check(not r.Anchored and (r.Position-harbour.Arrival.Position).Magnitude<0.01,'Recovery waits for the surviving destination floor')
town.Parent=city; collection.added:Fire(town)

-- Exercise the actual client controller, including streaming a stop back in mid-cycle.
players.LocalPlayer=p
local playerGui=Instance.new('PlayerGui'); playerGui.Name='PlayerGui'; playerGui.Parent=p
p.CharacterRemoving=signal()
function methods:WaitForChild(name) return assert(self:FindFirstChild(name),'Missing mock child '..name) end
local render
local clientHeartbeat=signal()
local renderService={Heartbeat=clientHeartbeat,BindToRenderStep=function(_,name,priority,callback) check(priority>200,'Metro camera follows the default camera'); render=callback end}
Enum.RenderPriority.Camera={Value=200}
local previousServices=game.GetService
game.GetService=function(self,name) return if name=='RunService' then renderService else previousServices(self,name) end
local transit=replicated.MetroTransit
transit.Ride.OnClientEvent=signal()
collection.tagged={town,harbour}
local camera=Instance.new('Camera'); camera.CFrame=CFrame.new(7000,-30,6900)
camera.CameraType=Enum.CameraType.Custom; camera.FieldOfView=74; camera.CameraSubject=h
workspace.CurrentCamera=camera
require('MetroClient').start()
now=84; transit:SetAttribute('Ready',true); render()
check(#workspace.MetroVisuals:GetChildren()==0,'Rendering and streamed stop registration never build trains')
clientHeartbeat:Fire(); flush()
check(#workspace.MetroVisuals:GetChildren()==1,'Only the nearby train is built during Heartbeat')
clientHeartbeat:Fire(); flush(); render()
check(#workspace.MetroVisuals:GetChildren()==1,'Preloading a distant station does not build its train')
local visual=workspace.MetroVisuals:GetChildren()[1]
check(visual and visual.Parent==workspace.MetroVisuals,'Train remains registered in the world')
local payload={origin='Hafen Mitte',destination='Gullhaven',dock=town.TrainDock.CFrame,departure=82,arrival=90}
now=82
transit.Ride.OnClientEvent:Fire('Depart',payload); render()
check(camera.CameraType==Enum.CameraType.Scriptable and playerGui.MetroJourney.Enabled,'Departure starts the ride camera and route animation')
local cover=playerGui.MetroJourney:GetChildren()[1]
check(cover.BackgroundTransparency==1,'The fade starts while the doors close')
now=83; render()
check(cover.BackgroundTransparency==0.5,'The departure fade progresses before movement')
for t=84,86.75,0.25 do
  now=t; render()
  check(cover.BackgroundTransparency==0,'The map is fully hidden from the first movement through transfer')
end
check(visual.Parent==workspace.MetroVisuals,'Tunnel transition does not reparent the train')
transit.Ride.OnClientEvent:Fire('Transfer',{dock=harbour.TrainDock.CFrame})
now=87; render()
check(cover.BackgroundTransparency==0,'The clock wrap cannot reveal the map during arrival')
check((camera.CFrame.Position-harbour.TrainDock.Position).Magnitude<400,'Arrival camera uses the destination train and the shared clock')
clientHeartbeat:Fire(); flush(); render()
check(#workspace.MetroVisuals:GetChildren()==2,'Destination train builds when the camera transfers there')
now=89.9; render()
check(cover.BackgroundTransparency==0,'The screen stays dark until the server confirms arrival')
transit.Ride.OnClientEvent:Fire('Arrive')
check(camera.CameraType==Enum.CameraType.Custom and camera.FieldOfView==74 and not playerGui.MetroJourney.Enabled,'Arrival restores the original camera and dismisses the journey')
transit.Ride.OnClientEvent:Fire('Depart',payload)
check(cover.BackgroundTransparency==0,'A delayed departure packet starts fully covered before rendering')
render(); p.CharacterRemoving:Fire()
check(camera.CameraType==Enum.CameraType.Custom and not playerGui.MetroJourney.Enabled,'Respawn also restores the client camera')
for _,line in printed do output(line) end
output('Metro: '..checks..' schedule, geometry and passenger checks passed')
`;
}
const temporary = await mkdtemp(join(tmpdir(), 'fishing-metro-'));
try {
  const target = join(temporary, 'metro.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], {cwd:root, encoding:'utf8', timeout:120000, maxBuffer:1<<22});
  const parts = [];
  for (const line of (result.stdout || '').split(/\r?\n/)) {
    if (line.startsWith('@')) {
      const [name, color, points] = line.slice(1).split('|');
      parts.push({name, color:color.split(',').map(Number), points:points.split(' ').map(p=>p.split(',').map(Number))});
    } else if (line) console.log(line);
  }
  if (previewPath) await writeFile(previewPath, JSON.stringify(parts));
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.status) {
    const line = Number((result.stderr || '').match(/metro\.luau:(\d+):/)?.[1]);
    if (line) console.error(program.split('\n').slice(line - 3, line + 2).join('\n'));
  }
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} finally {
  await rm(temporary, {recursive:true, force:true});
}
