from pathlib import Path

def edit(p, f):
 p=Path(p); s=p.read_text(encoding='utf-8'); t=f(s); assert t!=s,p; p.write_text(t,encoding='utf-8',newline='')
def cut(s,a,b):
 i=s.index(a); j=s.index(b,i); return s[:i]+s[j:]
def rep(s,a,b):
 assert a in s,a; return s.replace(a,b,1)
edit('src/server/init.server.luau',lambda s:cut(s,'\t\tstep("CafeService", function()','\t\tstep("WebShopService", function()'))
edit('src/client/init.client.luau',lambda s:rep(s,'\t"Cafe",\n',''))
edit('src/server/BaseService.luau',lambda s:cut(cut(cut(s,'-- Companies without the fishing branch','local function claim(player: Player)'), '\tif profile and not fishes(profile) then','\tlocal info = profile and profile.SaveInfo'), '\t-- A café company that buys the fishing branch','\tenterSave()'))
def boat(s):
 s=cut(s,'\t-- Company branches (Shared.Branches','\tplayer:SetAttribute("CafeTutorialDone", not (ready and hasCafe) or cafeDone)\n')
 s=rep(s,'\tplayer:SetAttribute("CafeTutorialDone", not (ready and hasCafe) or cafeDone)\n','\tplayer:SetAttribute("BranchFishing", ready)\n')
 return s
edit('src/server/BoatService.luau',boat)
edit('src/shared/Branches.luau',lambda s:rep(rep(s,'Branches.ORDER = { "Fishing", "Cafe" }','Branches.ORDER = { "Fishing" }'), '\tCafe = {\n\t\tName = "Café",\n\t\tTitle = "Café branch",\n\t\t-- Paid by a fishing company that wants to open a café as well.\n\t\tPrice = 7500,\n\t\tBlurb = "A one-floor café in the city. Brew coffee for customers for cash and XP.",\n\t},\n',''))
edit('src/server/SaveData.luau',lambda s:rep(rep(s,'SaveData.COMPANY_TYPES = { Fishing = true, Cafe = true }','SaveData.COMPANY_TYPES = { Fishing = true }'),'Choose a fishing company or a café.','Choose a fishing company.'))
def save(s):
 s=rep(s,'Fishing company or café · solo or with up to four friends.','Fishing company · solo or with up to four friends.')
 return cut(s,'\t\t-- The company type is picked once','\n\t\tlocal function submit') if False else rep(cut(s,'\t\t-- The company type is picked once','\t\tlocal function submit') ,'', '')
# retain the rest of the creation form after the company selector
edit('src/client/SaveSelection.luau',lambda s:rep(cut(s,'\t\t-- The company type is picked once','\n\t\tlocal ',) if False else s,'Fishing company or café · solo or with up to four friends.','Fishing company · solo or with up to four friends.'))
p=Path('src/client/SaveSelection.luau'); s=p.read_text(encoding='utf-8'); a=s.index('\t\t-- The company type is picked once'); b=s.index('\n\t\tend',s.index('\t\t\tpaintTypes()',a))+len('\n\t\tend'); s=s[:a]+'\t\tlocal companyType = "Fishing"\n\t\tlocal top = 230'+s[b:]; p.write_text(s,encoding='utf-8',newline='')
def office(s):
 s=rep(s,'local BranchApp = require(script.Parent.BranchApp)\n','')
 s=cut(s,'\t\tBranches = {','\t}\n\n\tlocal function closeWindow')
 s=cut(s,'\t-- BRANCHES: a little shopfront','\t-- STOCKS: a rising chart.')
 return s.replace('BY THE CAFE QUARTER','IN THE INDUSTRIAL DISTRICT').replace('BY THE CAFE QUARTER IN THE CITY','IN THE INDUSTRIAL DISTRICT')
edit('src/client/OfficeComputer.luau',office)
def city(s):
 s=rep(s,'City.VERSION = 19','City.VERSION = 20')
 s=rep(s,'\tif cafeBlock(i, j) then\n\t\treturn "cafe"\n\tend\n','')
 s=rep(s,'\t\telseif b.kind == "cafe" then\n\t\t\t-- Map/CafePlots paves and builds these blocks\n','')
 return s
edit('src/server/Map/ModernCity.luau',city)
