// Exercise compact building descriptions and the client work budget with Roblox mocks.
import {readFile, writeFile, mkdtemp, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';
import {spawnSync} from 'node:child_process';
const root = resolve(import.meta.dirname, '..');
const read = p => readFile(join(root, p), 'utf8');
const city = await read('scripts/check-city.mjs');
const mocks = city.match(/const mocks = String.raw`([\s\S]*?)`;/)[1];
const server = await read('src/server/Map/CityDetail.luau');
const client = await read('src/client/CityDetail.luau');
const harness = String.raw`
local oldCFIndex = CF.__index
CF.__index = function(c, key)
  if key == 'GetComponents' then return function(self)
    return self.p.X,self.p.Y,self.p.Z,self.r.X,self.u.X,self.b.X,self.r.Y,self.u.Y,self.b.Y,self.r.Z,self.u.Z,self.b.Z
  end end
  return oldCFIndex(c,key)
end
local saved = {}
HttpService.JSONEncode = function(_, value) table.insert(saved,value); return tostring(#saved) end
HttpService.JSONDecode = function(_, raw) return saved[tonumber(raw)] end
local function event()
  local callbacks = {}
  return {Connect=function(_,f) table.insert(callbacks,f); return {Disconnect=function() end} end,
    Fire=function(_,...) for _,f in callbacks do f(...) end end}
end
local heartbeat, added, removed = event(), event(), event()
local tagged = {}
local collection = {GetInstanceAddedSignal=function() return added end, GetInstanceRemovedSignal=function() return removed end,
  GetTagged=function() return tagged end}
local riding = false
local clock = 0
local os = {clock=function() return clock end}
local player = {Character=Instance.new('Model'), GetAttribute=function(_, name) return name=='MetroRiding' and riding end}
local root = Instance.new('Part'); root.Name='HumanoidRootPart'; root.Parent=player.Character
local originalGetService = game.GetService
game.GetService = function(self,name)
  if name=='CollectionService' then return collection end
  if name=='Players' then return {LocalPlayer=player} end
  if name=='RunService' then return {Heartbeat=heartbeat} end
  return originalGetService(self,name)
end
local server = (function()
` + server + String.raw`
end)()
local client = (function()
` + client + String.raw`
end)()
local city=Instance.new('Model'); city.Parent=workspace
local ground=Instance.new('Model'); ground.Name='Ground'; ground.Parent=city
local model=Instance.new('Model'); model.Name='CityBlock17'; model.Parent=ground
local body=Instance.new('Part'); body.Name='Body'; body.Parent=model
for i=1,13 do
  local p=Instance.new('Part'); p.Name='Decoration'..i; p.CanCollide=false; p.CanQuery=false; p.Material={Name='Glass'}; p.Shape={Name='Block'}
  p.Reflectance=0; p.CastShadow=false; p.Parent=model
  if i==1 then p:AddTag('NightGlow'); p:SetAttribute('GlowColor',Color3.new(1,0.5,0.2)); p:SetAttribute('GlowAt',0.4) end
end
local complex=Instance.new('Part'); complex.CanCollide=false; complex.Parent=model
Instance.new('SpotLight').Parent=complex
local station=Instance.new('Model'); station.Name='CityMetroStop'; station.Parent=city
local tracks=Instance.new('Model'); tracks.Name='MetroTracks'; tracks.Parent=station
local rail=Instance.new('Part'); rail.Name='Rail'; rail.CanCollide=false; rail.CanQuery=false
rail.Material={Name='Metal'}; rail.Shape={Name='Block'}; rail.Reflectance=0; rail.CastShadow=false; rail.Parent=tracks
local control=Instance.new('Part'); control.Name='Control'; control.CanCollide=false; control.CanQuery=true; control.Parent=tracks
server.prepare(city)
check(body.Parent==model and complex.Parent==model,'Collision and parts with children remain on server')
check(#saved==2 and #saved[1]==13 and model:HasTag('CityDetail'),'Decorations encoded and tagged')
check(rail.Parent==nil and control.Parent==tracks and tracks:HasTag('CityDetail'), 'Station dressing is deferred while queryable controls remain')
check(tracks:GetAttribute('CityDetailAnchor')~=nil, 'Station detail retains a position after its decoration is removed')
check(#model:GetChildren()==2,'Only the core and complex part remain')
server.prepare(city)
check(#saved==2,'Migration is idempotent')
table.insert(tagged,model)
control.Parent=nil -- even a room with no remaining parts can locate its local detail
table.insert(tagged,tracks)
client.start()
riding=true
heartbeat:Fire(1/60)
check(model:FindFirstChild('CityLocalDetail')==nil,'Detail construction is paused during the ride')
riding=false
heartbeat:Fire(1/60)
clock=7.9
heartbeat:Fire(1/60)
check(model:FindFirstChild('CityLocalDetail')==nil,'Detail waits while city streaming settles')
clock=8.1
heartbeat:Fire(1/60)
local folder=model:FindFirstChild('CityLocalDetail')
check(folder~=nil and #folder:GetChildren()<=6 and #folder:GetChildren()>0,'One frame creates at most six decorations')
for i=1,15 do heartbeat:Fire(1/60) end
check(#folder:GetChildren()==13,'All nearby detail is eventually reconstructed')
check(tracks:FindFirstChild('CityLocalDetail')~=nil,'An empty station room rebuilds detail using its anchor')
local glow=folder:FindFirstChild('Decoration1')
check(glow:HasTag('NightGlow') and glow:GetAttribute('GlowAt')==0.4,'Night lighting metadata survives')
removed:Fire(model)
check(folder.Parent==nil,'Local detail is cleaned up when the building streams out')
_G_print('City detail: migration, lighting, work budget and stream-out checks passed')
`;
const temp = await mkdtemp(join(tmpdir(), 'city-detail-'));
try {
 const path=join(temp,'test.luau'); await writeFile(path,'local _G_print = print\n'+mocks+harness);
 const result=spawnSync(process.env.LUTE || 'lute',['run',path],{cwd:root,encoding:'utf8',timeout:30000});
 if(result.stdout) process.stdout.write(result.stdout); if(result.stderr) process.stderr.write(result.stderr);
 if(result.error) throw result.error; if(result.status!==0) throw new Error('City detail check failed');
} finally { await rm(temp,{recursive:true,force:true}); }
