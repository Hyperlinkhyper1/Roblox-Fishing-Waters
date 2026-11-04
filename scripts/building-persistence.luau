-- Check construction survives the real angler and whole-profile decoders.
local Data=require('../src/server/AnglerData')
local BoatData=require('../src/server/BoatData')
local checks=0
local function check(value,message) assert(value,message); checks+=1 end
local raw={Home={NextId=12,Pieces={{Id='p7',Kind='Wall',X1=-9,Z1=0,X2=9,Z2=0,Level=0,Material='Brick',Color={90,110,130}}},Overrides={['b:Shell/Wall']={Removed=true}}},Company={NextId=5,Pieces={{Id='p4',Kind='Floor',X1=-9,Z1=-9,X2=9,Z2=9,Level=1,Material='WoodPlanks',Color={160,140,120}}},Overrides={}}}
local angler=Data.decode({Building=raw})
check(angler.Building.Home.Pieces[1].Id=='p7','Angler decode lost the custom home wall')
check(angler.Building.Company.Pieces[1].Level==1,'Angler decode lost the company floor level')
check(angler.Building.Home.Overrides['b:Shell/Wall'].Removed,'Angler decode lost a removed original wall')
check(angler.Building.Home.NextId==12,'Angler decode must preserve the next stable ID')
check(angler.Building.Home.Pieces[1]~=raw.Home.Pieces[1],'Angler decode must isolate live profile tables')
local profile=BoatData.decode({Version=1,Cash=700,OwnedBoats={},Angler=angler})
check(profile.Cash==700,'Construction decode changed the wallet')
check(profile.Angler.Building.Home.Pieces[1].Material=='Brick','Whole-profile decode lost the wall finish')
check(profile.Angler.Building.Company.Pieces[1].Kind=='Floor','Whole-profile decode lost independent company construction')
check(profile.Angler.Building.Home.Overrides['b:Shell/Wall'].Removed,'Whole-profile decode lost original shell edits')
profile.Angler.Building.Home.Pieces[1].Color[1]=0
check(angler.Building.Home.Pieces[1].Color[1]==90 and raw.Home.Pieces[1].Color[1]==90,'Whole-profile decoder aliased saved construction')
check(Data.decode(nil).Building==nil,'Legacy players must not receive edits to their original shells')
check(#Data.decode({Building={Home={Pieces={{Kind='Unknown'}}}}}).Building.Home.Pieces==0,'Malformed construction survived angler decode')
print('Building persistence: '..checks..' production angler/profile round-trip checks passed.')
