from pathlib import Path
p=Path('src/client/Tutorial.luau'); s=p.read_text(encoding='utf-8')
def cut(a,b):
 global s
 i=s.index(a); j=s.index(b,i); s=s[:i]+s[j:]
def rep(a,b):
 global s
 assert a in s,a; s=s.replace(a,b,1)
for line in ['local CafeTutorial = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CafeTutorial"))\n','local CafeCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CafeCatalog"))\n','local CAFE_PROMPT = "CafeMentorPrompt"\n']:
 rep(line,'')
cut('\t-- The café tour\'s remote arrives','\tlocal function harbourTour()')
rep('\t\tif cafeTour() then\n\t\t\treturn "Cafe"\n\t\telseif harbourTour() then','\t\tif harbourTour() then')
cut('\t\tif activeTour() == "Cafe" then\n\t\t\tif cafeRemote','\n\tend)')
rep('\t\tTheme.button(skip)\n\n\tend)','\t\tTheme.button(skip)\n\t\tremote:FireServer("Skip")\n\tend)')
rep('\t\t\tif chat.cafe then\n\t\t\t\tif cafeRemote then\n\t\t\t\t\tcafeRemote:FireServer("Finish")\n\t\t\t\tend\n\t\t\telse\n\t\t\t\tremote:FireServer("Finish", chat.npc)\n\t\t\tend','\t\t\tremote:FireServer("Finish", chat.npc)')
cut('\t-- Bea, in the player\'s own café','\tnextButton.Activated:Connect(advance)')
rep('\t\telseif prompt.Name == CAFE_PROMPT and not talking then\n\t\t\topenCafeDialogue()\n','')
cut('\ttask.spawn(function()\n\t\tlocal folder = ReplicatedStorage:WaitForChild("CafeTutorial")','\n\t------------------------------------------------------------------------------------------------\n\t-- Arrows')
cut('\t-- The player\'s own café plot','\tlocal function refreshTracker()')
cut('\t\tif tour == "Cafe" then','\t\telseif tour == "Harbour" then')
rep('\t\telseif tour == "Harbour" then','\t\tif tour == "Harbour" then')
for a in ['CafeTutorialStep','CafeTutorialDone','CafeTutorialCount','BranchCafe','CarryingCoffee']:
 rep('\t\t"'+a+'",\n','')
rep('\t\t\tlocal position\n\t\t\tif chat.cafe then\n\t\t\t\tlocal plot = myCafe()\n\t\t\t\tposition = plot and plot:GetAttribute("MentorPosition")\n\t\t\telse\n\t\t\t\tposition = state:GetAttribute("Npc_" .. chat.npc)\n\t\t\tend','\t\t\tlocal position = state:GetAttribute("Npc_" .. chat.npc)')
cut('\t\tif activeTour() == "Cafe" then','\t\tif typeof(position) ~= "Vector3" then')
rep('\t\tlocal position, lift = nil, MARKER_LIFT\n\t\tif typeof(position)', '\t\tlocal id = targetId()\n\t\tlocal position, lift = id and state:GetAttribute("Npc_" .. id), MARKER_LIFT\n\t\tif typeof(position)')
p.write_text(s,encoding='utf-8',newline='')
