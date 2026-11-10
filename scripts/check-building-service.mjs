// Exercise the production remote and wallet flow with deterministic Roblox doubles.
import {readFile, writeFile, mkdtemp, rm} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';
const root=resolve(import.meta.dirname,'..');
const [catalog,furniture,source,furnitureService,angler]=await Promise.all(['src/shared/BuildingCatalog.luau','src/shared/FurnitureCatalog.luau','src/server/BuildingService.luau','src/server/FurnitureService.luau','src/server/AnglerData.luau'].map(p=>readFile(join(root,p),'utf8')));
const service=source.replace(/^local (\w+) = require\(.*$/gm,'local $1 = dependencies.$1');
const placement=furnitureService.slice(furnitureService.indexOf('local function place(player:'),furnitureService.indexOf('\nlocal function pickUp(',furnitureService.indexOf('local function place(player:')))
 .replace('require(script.Parent.BuildingService)','Service');
const placeData=angler.slice(angler.indexOf('function Data.placeFurniture('),angler.indexOf('\n-- Puts a placed item back',angler.indexOf('function Data.placeFurniture(')));
const program=`
local function copy(value)
 if type(value)~="table" then return value end
 local result={}; for key,child in value do result[key]=copy(child) end; return result
end
local function signal()
 local callbacks={}
 return {Connect=function(_,callback) table.insert(callbacks,callback); return {Disconnect=function() end} end,
 Fire=function(_,...) for _,callback in callbacks do callback(...) end end}
end
local vmt={}
function vmt.__sub(a,b) return setmetatable({X=a.X-b.X,Y=a.Y-b.Y,Z=a.Z-b.Z},vmt) end
function vmt.__index(v,key) if key=="Magnitude" then return math.sqrt(v.X^2+v.Y^2+v.Z^2) end end
local function vector(x,y,z) return setmetatable({X=x,Y=y,Z=z},vmt) end
local function frame(x,y,z) return {__type="CFrame",Position=vector(x,y,z)} end
local function typeof(value) return if type(value)=="table" then value.__type or "table" else type(value) end
local methods={}
local instanceMt={}
function instanceMt.__index(self,key)
 if key=="Parent" then return rawget(self,"_parent") end
 return methods[key] or rawget(self,key)
end
function instanceMt.__newindex(self,key,value)
 if key~="Parent" then rawset(self,key,value);return end
 local old=rawget(self,"_parent")
 if old then for i,child in old._children do if child==self then table.remove(old._children,i);break end end end
 rawset(self,"_parent",value)
 if value then table.insert(value._children,self) end
end
local Instance={}
function Instance.new(class)
 return setmetatable({ClassName=class,Name=class,_children={},_attributes={},_signals={},DescendantAdded=signal(),Destroying=signal()},instanceMt)
end
function methods:IsA(class) return self.ClassName==class or class=="Instance" or (class=="BasePart" and self.ClassName=="Part") end
function methods:IsDescendantOf(ancestor) local p=self.Parent;while p do if p==ancestor then return true end;p=p.Parent end;return false end
function methods:GetChildren() return table.clone(self._children) end
function methods:GetDescendants() local result={};for _,c in self._children do table.insert(result,c);for _,d in c:GetDescendants() do table.insert(result,d) end end;return result end
function methods:FindFirstChild(name) for _,c in self._children do if c.Name==name then return c end end end
function methods:FindFirstChildOfClass(class) for _,c in self._children do if c:IsA(class) then return c end end end
function methods:GetAttribute(name) return self._attributes[name] end
function methods:GetAttributeChangedSignal(name) self._signals[name]=self._signals[name] or signal();return self._signals[name] end
function methods:SetAttribute(name,value) self._attributes[name]=value;self:GetAttributeChangedSignal(name):Fire() end
local workspace=Instance.new("Workspace")
local Players=Instance.new("Players");Players.PlayerAdded,Players.PlayerRemoving=signal(),signal()
function Players:GetPlayers() return self:GetChildren() end
function Players:GetPlayerByUserId(id) for _,p in self:GetChildren() do if p.UserId==id then return p end end end
local ReplicatedStorage=Instance.new("Folder")
local tagged,tagSignals={},{}
local CollectionService={}
function CollectionService:GetTagged(tag) return tagged[tag] or {} end
function CollectionService:GetInstanceAddedSignal(tag) tagSignals[tag]=tagSignals[tag] or signal();return tagSignals[tag] end
local game={GetService=function(_,name) return ({Players=Players,ReplicatedStorage=ReplicatedStorage,CollectionService=CollectionService})[name] end}
local sent={}
function methods:FireClient(player,...) table.insert(sent,{Player=player,Args={...}}) end
local clock=0
local os={clock=function() return clock end}
local task={defer=function(callback) callback() end}
local Building=(function() ${catalog} end)()
local Furniture=(function() ${furniture} end)()
local player=Instance.new("Player");player.UserId=1;player.Parent=Players
player.Character=Instance.new("Model")
local humanoid=Instance.new("Humanoid");humanoid.Health=100;humanoid.Parent=player.Character
local characterRoot=Instance.new("Part");characterRoot.Name="HumanoidRootPart";characterRoot.Position=vector(0,0,0);characterRoot.Parent=player.Character
local base=Instance.new("Model");base.Name="PlayerBase";base:SetAttribute("OwnerUserId",1);base.Parent=workspace
local house=Instance.new("Model");house.Name="BaseHouse";house:SetAttribute("HouseFrame",frame(0,0,0));house.Parent=base
local company=Instance.new("Model");company.Name="CompanyIsland";company:SetAttribute("OwnerUserId",1);company:SetAttribute("PlotFrame",frame(0,0,0));company.Parent=workspace
tagged.PlayerBase={base};tagged.CompanyIsland={company}
local builtins={ ["b:testwall"]={Id="b:testwall",Kind="Wall",X1=9,Z1=-1,X2=18,Z2=-1,Level=0,BaseY=0.16,Height=11.5,Material="Plaster",Color={235,229,211}} }
local profile={Cash=1000,Angler={Furniture={},CompanyFurniture={},Coins=77}}
local saves,failSave,race=0,false,nil
local BoatService={}
function BoatService.getProfile(_) return copy(profile) end
function BoatService.updateProgress(_,transform)
 saves+=1
 if failSave then return false,"Save unavailable." end
 if race then local callback=race;race=nil;callback(profile) end
 local nextProfile=copy(profile)
 local ok,reason=pcall(transform,nextProfile)
 if not ok then return false,"Concurrent change rejected." end
 if nextProfile.Angler.Building then nextProfile.Angler.Building=Building.decode(nextProfile.Angler.Building) end
 profile=nextProfile
 player:SetAttribute("AnglerRevision",(player:GetAttribute("AnglerRevision") or 0)+1)
 return true,"Saved."
end
local rendered={}
local Renderer={capture=function(model) return if model==house then copy(builtins) else {} end,
 sync=function(model,_,site,data) rendered[model]={Data=copy(data),Cash=profile.Cash,Site=site} end}
local dependencies={BoatService=BoatService,Building=Building,Renderer=Renderer,Furniture=Furniture}
local Service=(function() ${service} end)()
Service.start()
local request=ReplicatedStorage:FindFirstChild("Building"):FindFirstChild("Request")
local checks=0
local function check(value,message) checks+=1;assert(value,message) end
local function invoke(action,payload,site)
 clock+=1
 return request.OnServerInvoke(player,action,payload,site)
end
local function wall(x1,z1,x2,z2)
 return {Kind="Wall",X1=x1,Z1=z1,X2=x2,Z2=z2,Level=0,Material="Brick",Color={100,120,140}}
end
local before=invoke("Get")
check(before.Ok and before.State.Cash==1000 and #before.State.Pieces==0,"Legacy profiles start with empty structural state")
check(before.State.Builtins["b:testwall"]~=nil,"Existing building descriptors reach the editor")
local result=invoke("Place",{Entries={wall(9,-5,18,-5)}})
check(result.Ok and #result.State.Pieces==1 and result.State.Pieces[1].Id=="p1","Placement commits a stable ID")
check(profile.Cash==976 and profile.Angler.Coins==77,"Server pricing debits wallet and preserves other progress")
check(#rendered[house].Data.Pieces==1 and rendered[house].Cash==976,"Renderer sees committed wallet data")
check(result.State.CanUndo and not result.State.CanRedo,"Successful edits create undo history")
profile.Cash+=113;profile.Angler.Coins=93
result=invoke("Undo",{})
check(result.Ok and #result.State.Pieces==0 and profile.Cash==1113,"Undo refunds the original debit without discarding unrelated earnings")
check(profile.Angler.Coins==93 and result.State.CanRedo,"Undo preserves non-building profile changes")
result=invoke("Redo",{})
check(result.Ok and #result.State.Pieces==1 and profile.Cash==1089,"Redo recharges the original debit")
local selected=result.State.Pieces[1].Id
result=invoke("Paint",{Id=selected,Material="WoodPlanks",Color={24,25,29}})
check(result.Ok and result.State.Pieces[1].Material=="WoodPlanks" and profile.Cash==1089,"Painting is persisted without charging again")
result=invoke("Place",{Entries={{Kind="Window",HostId=selected,Offset=4.5,Material="Wood",Color={246,246,242}}}})
check(result.Ok and #result.State.Pieces==2 and profile.Cash==1044,"Windows attach to a saved wall and use server pricing")
result=invoke("Remove",{Id=selected})
check(result.Ok and #result.State.Pieces==0 and profile.Cash==1044,"Removing a wall removes its attached openings without minting cash")
result=invoke("Undo",{})
check(result.Ok and #result.State.Pieces==2,"Undo restores a wall and its openings together")
local saveCount=saves
result=invoke("Place",{Entries={wall(9,-1,18,-1)}})
check(not result.Ok and saves==saveCount,"A wall cannot duplicate a surviving original wall")
-- Original full-height walls convert into custom pieces when moved.
local moveCash=profile.Cash
result=invoke("Place",{Entries={{Kind="Window",HostId="b:testwall",Offset=4.5,Material="Wood",Color={246,246,242}}}})
check(result.Ok,"Windows can be added to an original wall")
local windowCash=profile.Cash
builtins["b:testwall"].BaseY=6
result=invoke("Move",{Id="b:testwall",Entry=wall(9,-3,18,-3)})
check(not result.Ok and profile.Cash==windowCash,"Partial original wall sections cannot be moved")
builtins["b:testwall"].BaseY=0.16
result=invoke("Move",{Id="b:testwall",Entry=wall(9,-3,18,-3)})
local movedHome=profile.Angler.Building.Home
local converted=movedHome.Pieces[#movedHome.Pieces]
check(result.Ok and movedHome.Overrides["b:testwall"] and movedHome.Overrides["b:testwall"].Removed
 and converted.Kind=="Wall" and converted.Z1==-3 and converted.Id:match("^p%d+$")~=nil,
 "Moving an original wall hides it and saves an equivalent custom wall")
check(profile.Cash==windowCash,"Moving an original wall to the same length is free")
local rehosted=false
for _,piece in movedHome.Pieces do if piece.Kind=="Window" and piece.HostId==converted.Id then rehosted=true end end
check(rehosted,"Openings added to an original wall move with it")
result=invoke("Undo",{})
local restored=profile.Angler.Building.Home.Overrides["b:testwall"]
check(result.Ok and not (restored and restored.Removed),"One undo restores the original wall")
result=invoke("Undo",{})
check(result.Ok and profile.Cash==moveCash,"Undo removes the added window and refunds it")
result=invoke("Paint",{Id="b:testwall",Material="Marble",Color={200,201,202}})
check(result.Ok and profile.Angler.Building.Home.Overrides["b:testwall"].Material=="Marble","Original surfaces persist as overrides")
result=invoke("Remove",{Id="b:testwall"})
check(result.Ok and profile.Angler.Building.Home.Overrides["b:testwall"].Removed,"Original surface removal persists")
result=invoke("Place",{Entries={wall(9,-1,18,-1)}})
check(result.Ok,"A removed original wall may be replaced")
local oldCount=#profile.Angler.Building.Home.Pieces
local oldCash=profile.Cash
failSave=true
result=invoke("Place",{Entries={wall(9,-9,18,-9)}})
failSave=false
check(not result.Ok and #profile.Angler.Building.Home.Pieces==oldCount and profile.Cash==oldCash,"A rejected save never commits geometry or cash")
characterRoot.Position=vector(500,0,0)
saveCount=saves
result=invoke("Remove",{Id=selected})
check(not result.Ok and saves==saveCount,"Distant owners cannot edit")
characterRoot.Position=vector(0,0,0)
base:SetAttribute("OwnerUserId",2)
result=invoke("Remove",{Id=selected})
check(not result.Ok and #rendered[house].Data.Pieces==0,"Ownership release restores the uncustomized shell")
base:SetAttribute("OwnerUserId",1)
result=invoke("Place",{Entries={wall(9,-13,18,-13)}},"Company")
check(result.Ok and #profile.Angler.Building.Company.Pieces==1 and #profile.Angler.Building.Home.Pieces==oldCount,"Home and company structures save independently")
saveCount=saves
result=invoke("Place",{Entries={wall(9,-17,18,-17)}},"SomeoneElse")
check(not result.Ok and saves==saveCount,"Unknown plots reject before saving")
result=invoke("Place",{Entries={wall(9,-17,18,-17)}},"Company")
clock-=0.9
result=request.OnServerInvoke(player,"Remove",{Id="p1"},"Company")
check(not result.Ok,"Remote write requests are rate limited")
clock+=0.9
race=function(current) current.Cash=0 end
result=invoke("Place",{Entries={wall(9,-21,18,-21)}},"Company")
check(not result.Ok and #profile.Angler.Building.Company.Pieces==2 and profile.Cash==0,"Pricing is rechecked against the newest atomic wallet state")
profile.Cash=500
race=function() characterRoot.Position=vector(500,0,0) end
result=invoke("Place",{Entries={wall(9,-25,18,-25)}},"Company")
check(not result.Ok and #profile.Angler.Building.Company.Pieces==2,"Property distance is rechecked inside the transaction")
characterRoot.Position=vector(0,0,0)
local item={ItemId="PottedPlant",X=9,Z=-13.5,R=0}
local body=Furniture.body(item.ItemId,item.X,item.Z,item.R)
local blocking=wall((body[1]+body[3])/2,body[2]-2,(body[1]+body[3])/2,body[4]+2)
profile.Angler.CompanyFurniture={item}
result=invoke("Place",{Entries={blocking}},"Company")
check(not result.Ok,"New walls cannot pass through saved furniture")
profile.Angler.CompanyFurniture={}
profile.Angler.Building.Company.Pieces={Building.normalize(blocking)}
profile.Angler.Building.Company.Pieces[1].Id="p20"
check(Service.furnitureProblem(player,item,"Company",profile)~=nil,"Furniture placement cannot enter custom walls")
result=invoke("Get",nil,"Company")
check(not result.State.CanUndo and not result.State.CanRedo,"External structural changes invalidate stale undo snapshots")
local function furniturePlacement()
 local Data={decode=copy}
 local function furniture() return Furniture end
 local function siteList(data,site) return if site=="Company" then data.CompanyFurniture else data.Furniture end
 ${placeData}
 local AnglerData=Data
 local function siteProblem() return nil end
 local function run(p,change)
  local nextProfile=BoatService.getProfile(p)
  local _,reason=change(nextProfile)
  if reason then return false,reason end
  return BoatService.updateProgress(p,function(current)
   local changed,failure=change(current);assert(changed,failure)
  end)
 end
 ${placement}
 return place
end
local tryFurniture=furniturePlacement()
profile.Angler.CompanyIsland=1;profile.Angler.Paths={Unlocked={}};profile.Angler.FurnitureStock={PottedPlant=1}
saveCount=saves
local furnitureOk=tryFurniture(player,"PottedPlant",item.X,item.Z,item.R,"Company")
check(not furnitureOk and saves==saveCount and profile.Angler.FurnitureStock.PottedPlant==1 and #profile.Angler.CompanyFurniture==0,"FurnitureService rejects custom-wall collisions without saving or consuming stock")
profile.Angler.Building.Company.Pieces={}
furnitureOk=tryFurniture(player,"PottedPlant",item.X,item.Z,item.R,"Company")
check(furnitureOk and profile.Angler.FurnitureStock.PottedPlant==nil and #profile.Angler.CompanyFurniture==1,"FurnitureService still places owned furniture when the custom wall is removed")
local stairs={Kind="Stairs",X1=9,Z1=-18,X2=13.5,Z2=-9,Level=0,Style="North",Material="WoodPlanks",Color={128,88,54}}
saveCount=saves
result=invoke("Place",{Entries={stairs}},"Company")
check(not result.Ok and saves==saveCount,"Removed staircases must not be available through direct placement requests")
profile.Angler.CompanyFurniture={}
local legacyStairs=assert(Building.normalize(stairs));legacyStairs.Id="p200"
profile.Angler.Building.Company={NextId=201,Pieces={legacyStairs},Overrides={}}
result=invoke("Get",nil,"Company")
check(#result.State.Pieces==1 and result.State.Pieces[1].Kind=="Stairs","Existing saved staircases must survive removal of the new-placement tool")
check(Service.furnitureProblem(player,item,"Company",profile)~=nil,"FurnitureService also protects staircase footprints")
result=invoke("Paint",{Id="p200",Material="Marble",Color={200,201,202}},"Company")
check(result.Ok and result.State.Pieces[1].Material=="Marble","An existing staircase must remain editable without losing saved geometry")
result=invoke("Undo",{},"Company")
check(result.Ok and #result.State.Pieces==1 and result.State.Pieces[1].Material=="WoodPlanks" and profile.Cash==500,"Undo of a legacy staircase finish must preserve its geometry and wallet")
result=invoke("Redo",{},"Company")
check(result.Ok and result.State.Pieces[1].Id=="p200" and profile.Cash==500,"Redo of an existing staircase finish preserves its stable ID without a new purchase")
local invalidStair=copy(stairs);invalidStair.Level=3
saveCount=saves
result=invoke("Place",{Entries={invalidStair}},"Company")
check(not result.Ok and saves==saveCount,"A fourth-floor staircase cannot lead to a nonexistent fifth floor")
local roofA="b:Shell_1/RoofSlope_1"
local roofB="b:Shell_1/TileCourse_1"
local shopRoof="b:Shop_1/ShopShell_1/RoofSlope_1"
for _,id in {roofA,roofB,shopRoof} do
 builtins[id]={Id=id,Kind="Roof",X1=-24,Z1=-15,X2=24,Z2=15,Level=0,Material="RoofShingles",Color={160,80,45}}
end
result=invoke("Paint",{Id=roofA,Material="Slate",Color={30,40,50}})
local edits=profile.Angler.Building.Home.Overrides
check(result.Ok and edits[roofA].Material=="Slate" and edits[roofB].Material=="Slate" and edits[shopRoof]==nil,"Painting an original roof finishes every roof component in its shell only")
result=invoke("Remove",{Id=roofA})
edits=profile.Angler.Building.Home.Overrides
check(result.Ok and edits[roofA].Removed and edits[roofB].Removed and edits[shopRoof]==nil,"Removing an original roof removes slopes and details together without changing the shop roof")
result=invoke("Undo",{})
edits=profile.Angler.Building.Home.Overrides
check(result.Ok and not edits[roofA].Removed and not edits[roofB].Removed and edits[roofA].Material=="Slate" and edits[roofB].Material=="Slate","One undo restores the entire original roof with its previous finish")

-- One bounded paint transaction commits a rapid stroke atomically.
local batchWallet=profile.Cash
saveCount=saves
result=invoke("PaintBatch",{Entries={{Id=selected,Material="Metal",Color={90,100,110}},{Id=roofA,Material="Brick",Color={120,130,140}}}})
check(result.Ok and saves==saveCount+1 and profile.Cash==batchWallet,"A paint batch must use one atomic save without charging construction prices")
local paintedWall
for _,entry in result.State.Pieces do if entry.Id==selected then paintedWall=entry end end
check(paintedWall and paintedWall.Material=="Metal" and paintedWall.Color[1]==90,"A paint batch must persist custom wall finishes")
edits=profile.Angler.Building.Home.Overrides
check(edits[roofA].Material=="Brick" and edits[roofB].Material=="Brick" and edits[shopRoof]==nil,"Paint batches must retain whole-roof grouping without leaking to other buildings")
result=invoke("Undo",{})
local priorWall
for _,entry in result.State.Pieces do if entry.Id==selected then priorWall=entry end end
check(result.Ok and priorWall.Material=="WoodPlanks" and result.State.Overrides[roofA].Material=="Slate","One undo must reverse the entire saved paint stroke")
result=invoke("Redo",{})
check(result.Ok and result.State.Overrides[roofA].Material=="Brick","A paint stroke must be redoable")
saveCount=saves
result=invoke("PaintBatch",{Entries={{Id=selected,Material="Wood",Color={1,2,3}},{Id="p_missing",Material="Brick",Color={4,5,6}}}})
check(not result.Ok and saves==saveCount,"An invalid paint target must reject the whole batch before saving")
local retained
for _,entry in profile.Angler.Building.Home.Pieces do if entry.Id==selected then retained=entry end end
check(retained.Material=="Metal" and retained.Color[1]==90,"Rejecting one paint target must leave earlier batch entries unapplied")
result=invoke("PaintBatch",{Entries={{Id=selected,Material="Wood",Color={1,2,3}},{Id=roofA,Material="Brick",Color={999,5,6}}}})
check(not result.Ok and saves==saveCount,"Invalid appearance must reject an entire paint stroke atomically")
local hugeBatch={}
for index=1,65 do hugeBatch[index]={Id=selected,Material="Brick",Color={index,2,3}} end
result=invoke("PaintBatch",{Entries=hugeBatch})
check(not result.Ok and saves==saveCount,"One remote paint packet must never exceed 64 target changes")
failSave=true
result=invoke("PaintBatch",{Entries={{Id=selected,Material="Wood",Color={1,2,3}}}})
failSave=false
check(not result.Ok and profile.Cash==batchWallet,"A failed paint save must not debit the wallet or commit an optimistic finish")

-- Bulk painting resolves every wall on the property as one saved history item.
local bulkWall=assert(Building.normalize(wall(9,-5,18,-5)));bulkWall.Id="p1"
local upperWall=copy(bulkWall);upperWall.Id="p2";upperWall.Level=1
local opening=assert(Building.normalize({Kind="Window",HostId="p1",Offset=4.5,Material="Wood",Color={246,246,242}}));opening.Id="p3"
profile.Angler.Building.Home={NextId=4,Pieces={bulkWall,upperWall,opening},Overrides={
 ["b:testwall"]={Removed=true},[roofA]={Material="Slate",Color={30,40,50}}
}}
local gableA,gableB="b:Shell_1/Gable_1","b:Shell_1/Gable_8"
builtins[gableA]={Id=gableA,Kind="Roof",X1=-22,Z1=-15,X2=22,Z2=-14,Level=0,Material="Plaster",Color={235,229,211}}
builtins[gableB]={Id=gableB,Kind="Roof",X1=-3,Z1=15,X2=3,Z2=16,Level=0,Material="Plaster",Color={235,229,211}}
for index=1,70 do
 local id="b:bulk"..index
 builtins[id]={Id=id,Kind="Wall",X1=-18,Z1=9,X2=-9,Z2=9,Level=index%2,Material="Plaster",Color={235,229,211}}
end
local companyBefore=copy(profile.Angler.Building.Company)
local bulkCash=profile.Cash
saveCount=saves
result=invoke("PaintAllWalls",{Material="Marble",Color={17,34,51}})
check(result.Ok and saves==saveCount+1 and profile.Cash==bulkCash,"Painting all walls must use one free atomic save even above 64 surfaces")
for _,entry in result.State.Pieces do
 if entry.Kind=="Wall" then
  check(entry.Material=="Marble" and entry.Color[1]==17 and entry.Color[2]==34 and entry.Color[3]==51,"Bulk paint must cover custom walls on every floor")
 else check(entry.Material=="Wood" and entry.HostId=="p1","Bulk wall painting must preserve attached window finishes and geometry") end
end
for index=1,70 do
 local finish=result.State.Overrides["b:bulk"..index]
 check(finish and finish.Material=="Marble" and finish.Color[3]==51,"Bulk paint must cover all surviving original wall sections")
end
check(result.State.Overrides["b:testwall"].Removed and result.State.Overrides["b:testwall"].Material==nil,"Bulk painting must never restore removed walls")
check(result.State.Overrides[roofA].Material=="Slate" and result.State.Overrides[shopRoof]==nil,"Bulk painting must preserve roofs and their finishes")
check(result.State.Overrides[roofB]==nil,"Painting gables must not spread to the rest of their roof group")
for _,id in {gableA,gableB} do
 local finish=result.State.Overrides[id]
 check(finish and finish.Material=="Marble" and finish.Color[3]==51,"Bulk paint must cover the plaster gable triangles under the roof")
end
check(profile.Angler.Building.Company.Pieces[1].Material==companyBefore.Pieces[1].Material,"Painting home walls must leave the company property untouched")
saveCount=saves
result=invoke("PaintAllWalls",{Material="Marble",Color={17,34,51}})
check(result.Ok and saves==saveCount,"Repeating an identical bulk finish must avoid another save or undo item")
result=invoke("Undo",{})
check(result.Ok and result.State.Pieces[1].Material=="Brick" and result.State.Pieces[2].Material=="Brick"
 and result.State.Overrides["b:bulk1"]==nil and result.State.Overrides["b:bulk70"]==nil and profile.Cash==bulkCash,"One undo must restore every wall's prior finish without changing cash")
result=invoke("Redo",{})
check(result.Ok and result.State.Pieces[1].Material=="Marble" and result.State.Overrides["b:bulk70"].Color[3]==51,"One redo must reapply the entire bulk wall finish")
saveCount=saves
for _,finish in {{Material="Invalid",Color={1,2,3}},{Material="Brick",Color={999,2,3}}} do
 result=invoke("PaintAllWalls",finish)
 check(not result.Ok and saves==saveCount and profile.Angler.Building.Home.Pieces[1].Material=="Marble","Invalid bulk finishes must reject without applying partial changes")
end
failSave=true
result=invoke("PaintAllWalls",{Material="Metal",Color={1,2,3}})
failSave=false
check(not result.Ok and profile.Angler.Building.Home.Pieces[1].Material=="Marble" and profile.Cash==bulkCash,"Failed bulk saves must preserve every saved finish and the wallet")
profile.Angler.Building.Company={NextId=3,Pieces={bulkWall,upperWall},Overrides={}}
result=invoke("PaintAllWalls",{Material="Metal",Color={1,2,3}},"Company")
check(result.Ok and result.State.Pieces[1].Material=="Metal" and result.State.Pieces[2].Material=="Metal"
 and profile.Angler.Building.Home.Pieces[1].Material=="Marble","Company bulk paint must affect only company walls")
profile.Angler.Building.Company={NextId=1,Pieces={},Overrides={}}
saveCount=saves
result=invoke("PaintAllWalls",{Material="Brick",Color={1,2,3}},"Company")
check(not result.Ok and saves==saveCount,"A property without walls must reject bulk paint without saving")
print("Building service: "..checks.." ownership, transaction, persistence, price, history and collision checks passed (no Studio/DataStore).")
`;
const folder=await mkdtemp(join(tmpdir(),'building-service-'));
try {
 const target=join(folder,'service.luau');await writeFile(target,program);
 const result=spawnSync(process.env.LUAU || process.env.LUTE || 'luau',[...(process.env.LUTE&&!process.env.LUAU?['run']:[]),target],{cwd:root,encoding:'utf8',timeout:30000});
 if(result.stdout)process.stdout.write(result.stdout);if(result.stderr)process.stderr.write(result.stderr);
 if(result.error)throw result.error;if(result.status!==0)throw new Error('Building service checks failed ('+result.status+')');
} finally {await rm(folder,{recursive:true,force:true});}
