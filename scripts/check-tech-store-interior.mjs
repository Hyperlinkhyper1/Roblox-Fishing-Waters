// Real showroom geometry, occupancy lifecycle and server purchases with recording Roblox mocks.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = resolve(import.meta.dirname, '..');
const read = p => readFile(join(root, p), 'utf8');
const city = await read('scripts/check-city.mjs');
const mocks = city.match(/const mocks = String.raw`([\s\S]*?)`;/)[1];
const sources = {
  TechCatalog: 'src/shared/TechCatalog.luau', TechStoreLayout: 'src/shared/TechStoreLayout.luau',
  TechStoreFixtures: 'src/shared/TechStoreFixtures.luau', TechStorePrompts: 'src/shared/TechStorePrompts.luau',
  TechStoreInterior: 'src/shared/TechStoreInterior.luau', TechStore: 'src/server/Map/TechStore.luau',
  Renderer: 'src/client/TechStoreInterior.luau', Service: 'src/server/TechStoreService.luau',
  PcModel: 'src/shared/PcModel.luau',
};
let bundle = 'local output = print\n' + mocks + String.raw`
local clock = 0
local os = { clock = function() return clock end }
local function event()
  local callbacks = {}
  return { Connect = function(_, callback) table.insert(callbacks, callback); return { Disconnect = function() end } end,
    Fire = function(_, ...) for _, callback in callbacks do callback(...) end end }
end
local heartbeat, added, removed = event(), event(), event()
local player = Instance.new('Player')
player.Character = Instance.new('Model')
local rootPart = Instance.new('Part'); rootPart.Name = 'HumanoidRootPart'; rootPart.Parent = player.Character
local humanoid = Instance.new('Humanoid'); humanoid.Health = 100; humanoid.Parent = player.Character
local tagged = {}
local collection = {
  GetInstanceAddedSignal = function() return added end, GetInstanceRemovedSignal = function() return removed end,
  GetTagged = function(_, tag) return if tag == 'TechStore' then tagged else {} end,
  HasTag = function(_, model, tag) return model:HasTag(tag) end,
}
local rs = Instance.new('ReplicatedStorage')
local function token(name)
  return setmetatable({ __module = name }, { __index = function(_, child)
    if child == 'WaitForChild' then return function(_, wanted) return token(wanted) end end
    return token(child)
  end })
end
rs.Shared = token('Shared')
game.GetService = function(_, name)
  if name == 'ReplicatedStorage' then return rs end
  if name == 'ReplicatedFirst' then return token(name) end
  if name == 'CollectionService' then return collection end
  if name == 'RunService' then return { Heartbeat = heartbeat } end
  if name == 'Players' then return { LocalPlayer = player, GetPlayers = function() return { player } end,
    PlayerAdded = event(), PlayerRemoving = event() } end
  error('Unexpected service ' .. name)
end
local loaded, loaders = {}, {}
local function require(target)
  local name = target.__module
  if not loaded[name] then loaded[name] = loaders[name]() end
  return loaded[name]
end
local script = token('script')
local site = { cframe = CFrame.new(450, 8, 650) * CFrame.Angles(0, math.pi, 0), w = 460, d = 360 }
loaders.ModernCity = function() return { CAFE_CURB = 8.9, CAFE_TOP = 8, techStoreSite = function() return site end } end
loaders.UITheme = function() return { text = function() end } end
loaders.OfficeDesk = function() return { dress = function() end } end
local handed, carrying = {}, false
loaders.PcWorkshopService = function() return {
  start = function() end, isAway = function() return false end,
  canReceive = function() return not carrying, 'Your hands are full.' end,
  giveFromShop = function(_, parts, name) table.insert(handed, { Parts = parts, Name = name }); return true end,
} end
local profile = { Cash = 100000, Angler = { Stats = { CoinsSpent = 0 } } }
local commits = 0
loaders.BoatService = function() return { getProfile = function() return profile end,
  updateProgress = function(_, change) change(profile); commits += 1; return true end } end
-- Do not run the service's never-ending desk-dressing task in this synchronous harness.
task.spawn = function() end
`;
for (const [name, path] of Object.entries(sources)) {
  bundle += `loaders.${name} = function()\n${await read(path)}\nend\n`;
}
bundle += String.raw`
local Catalog = require(token('TechCatalog'))
local Layout = require(token('TechStoreLayout'))
local Geometry = require(token('TechStoreInterior'))
local Store = require(token('TechStore'))
local Renderer = require(token('Renderer'))
local Service = require(token('Service'))
local Presentation = require(token('TechStorePrompts'))
local map = Instance.new('Folder'); map.Parent = workspace
local store = Store.ensure(map); table.insert(tagged, store)
local frame = store:GetAttribute('StoreFrame')
check(store:GetAttribute('StoreVersion') >= 4, 'Old stores are rebuilt')
check(Store.ensure(map) == store, 'Current store is reused')
check(store:GetAttribute('District') == 'Industrial District', 'Store is marked as industrial')
check((Layout.X1 - Layout.X0) * (Layout.Z1 - Layout.Z0) >= 80000, 'Megastore has at least 80000 square studs of shopping floor')
local count, serverParts, permanentParts, outsideRacks, outsideDesks = 0, 0, 0, 0, 0
local permanent = store:FindFirstChild('StoreFixtures')
check(permanent ~= nil, 'Bare fixtures belong to the streamed store, independent of occupancy')
local firstRack
for _, p in store:GetDescendants() do
  if p:IsA('BasePart') then
    serverParts += 1
    if p:IsDescendantOf(permanent) then
      permanentParts += 1
      check(not p.CanCollide and not p.CanTouch and not p.CanQuery and not p.CastShadow, 'Bare fixture detail has no extra collision or shadow cost')
    end
    if p.Name == 'RackPlinth' then outsideRacks += 1; firstRack = firstRack or p; check(p.Transparency == 0, 'Rack frames are visible outside') end
    if p.Name == 'PrebuiltDemoDesk' then outsideDesks += 1 end
    check(p.Size.X > 0 and p.Size.Y > 0 and p.Size.Z > 0, 'Server part has valid dimensions: ' .. p.Name)
    local pos, h = site.cframe:PointToObjectSpace(p.Position), halfExtent(p)
    check(math.abs(pos.X) + h.X <= site.w / 2 + 0.01 and math.abs(pos.Z) + h.Z <= site.d / 2 + 0.01,
      'Exterior stays on its reserved city block: ' .. p.Name)
  end
  check(p.Name ~= 'PriceTag' and p.Name ~= 'StockBox' and p.Name ~= 'BulkStockCarton'
    and p.Name ~= 'PrebuiltGlassFront' and p.Name ~= 'LiveMonitorScreen' and p.Name ~= Layout.PromptName,
    'Sale contents and purchase prompts never replicate outside')
end
check(serverParts - permanentParts < 450 and permanentParts < 1200, 'Bare fixtures and shell stay within their part budgets')
check(outsideRacks == 18 and outsideDesks == 6, 'All racks and display tables are present before entry')
local fixtures = {}
for _, p in store:FindFirstChild('InteriorCollision'):GetChildren() do
  if p:IsA('BasePart') and p.CanCollide then table.insert(fixtures,p) end
end
local function overlaps(a,b)
  local delta = b.Position-a.Position
  for _, axis in {a.CFrame.RightVector,a.CFrame.ZVector,b.CFrame.RightVector,b.CFrame.ZVector} do
    local ra=math.abs(axis:Dot(a.CFrame.RightVector))*a.Size.X/2+math.abs(axis:Dot(a.CFrame.ZVector))*a.Size.Z/2
    local rb=math.abs(axis:Dot(b.CFrame.RightVector))*b.Size.X/2+math.abs(axis:Dot(b.CFrame.ZVector))*b.Size.Z/2
    if math.abs(delta:Dot(axis)) >= ra+rb-0.01 then return false end
  end
  return true
end
for i=1,#fixtures do
  for j=i+1,#fixtures do
    check(not overlaps(fixtures[i],fixtures[j]),'Fixtures never intersect: '..fixtures[i].Name..' / '..fixtures[j].Name)
  end
end
local walkParts = {}
for _, p in store:GetDescendants() do
  if p:IsA('BasePart') and p.CanCollide then table.insert(walkParts,p) end
end
local function solidAt(point)
  for _, p in walkParts do
    local localPos = p.CFrame:PointToObjectSpace(point)
    if math.abs(localPos.X) < p.Size.X / 2 + 0.8 and math.abs(localPos.Z) < p.Size.Z / 2 + 0.8
      and math.abs(localPos.Y) < p.Size.Y / 2 then return p end
  end
  return nil
end
for z = Layout.Z1 - 14, 180, 1 do check(not solidAt(frame * v3(0, 3.3, z)), 'Entrance stays walkable') end
local pathSamples = 0
for _, route in Layout.Paths do
  for index = 1, #route.Points - 1 do
    local a, b = route.Points[index], route.Points[index + 1]
    local d = b - a
    local across = v3(d.Z, 0, -d.X).Unit
    local steps = math.ceil(d.Magnitude / 2)
    for step = 0, steps do
      for _, offset in { -route.Width / 2 + 1.2, 0, route.Width / 2 - 1.2 } do
        local p = a:Lerp(b, step / steps) + across * offset + v3(0, 3.3, 0)
        local blocker = solidAt(frame * p)
        check(not blocker, route.Name .. ' stays clear at ' .. p.X .. ',' .. p.Z .. ': ' .. (blocker and blocker.Name or ''))
        pathSamples += 1
      end
    end
  end
end
local rotated = 0
for _, department in Layout.Departments do if department.Turn ~= 0 then rotated += 1 end end
check(rotated == 3, 'Three departments run across the others to alternate the aisle orientation')

local ids = {}
for _, entry in Layout.Displays do
  local key = entry.Kind .. ':' .. entry.Id
  check(not ids[key], 'No duplicate product display'); ids[key] = true
  local standing = (frame * entry.PromptFrame * CFrame.new(0, 0, 1.6)).Position
  check(not solidAt(standing), 'Player can stand at ' .. entry.Id)
  check(Layout.nearProduct(frame, standing, entry.Kind, entry.Id), 'Product is reachable at its price tag')
  check(not Layout.nearProduct(frame, frame * v3(0, 3, Layout.Z1 + 5), entry.Kind, entry.Id), 'Outside cannot buy')
end
for id in Catalog.Items do count += 1; check(ids['Item:' .. id], 'Every catalog item is displayed: ' .. id) end
for id in Catalog.Licenses do count += 1; check(ids['License:' .. id], 'Every license is displayed: ' .. id) end
for id in Catalog.Prebuilts do count += 1; check(ids['Prebuilt:' .. id], 'Every complete PC is displayed: ' .. id) end
check(#Layout.Displays == count, 'Exactly one display per product')
-- Flood the real collision at avatar width: all price tags must connect back to the
-- entrance, including the rotated rack interiors and the narrow office-PC display bay.
local step = 2
local x0, z0 = Layout.X0 + 2, Layout.Z0 + 2
local cols = math.floor((Layout.X1 - 2 - x0) / step)
local rows = math.floor((Layout.Z1 - 2 - z0) / step)
local clear, reached, queue = {}, {}, {}
local function key(x, z) return z * (cols + 1) + x end
local function visit(x, z)
  if x < 0 or x > cols or z < 0 or z > rows then return end
  local k = key(x,z)
  if reached[k] then return end
  if clear[k] == nil then clear[k] = solidAt(frame * v3(x0 + x * step, 3.3, z0 + z * step)) == nil end
  if clear[k] then reached[k] = true; table.insert(queue, {x,z}) end
end
visit(math.floor((0-x0)/step+0.5), math.floor((66-z0)/step+0.5))
local head = 1
while head <= #queue do
  local p = queue[head]; head += 1
  visit(p[1]-1,p[2]); visit(p[1]+1,p[2]); visit(p[1],p[2]-1); visit(p[1],p[2]+1)
end
for _, entry in Layout.Displays do
  local stand = (entry.PromptFrame * CFrame.new(0,0,1.6)).Position
  local x = math.floor((stand.X-x0)/step+0.5)
  local z = math.floor((stand.Z-z0)/step+0.5)
  check(reached[key(x,z)], 'Entrance route reaches the actual display: '..entry.Id)
end
check(not Layout.inside(frame, frame * v3(0, Layout.Height + 3, 0)), 'Roof is outside')
check(not Layout.inside(frame, frame * v3(0, -4, 0)), 'Under floor is outside')
check(not Layout.inside(frame, frame * v3(0, 3, Layout.Z1)), 'Door threshold counts as outside')

local products, exits = {}, 0
Renderer.start(function(prompt, entry) products[entry.Kind .. ':' .. entry.Id] = prompt end, function() exits += 1 end)
rootPart.Position = frame * v3(0, 3.3, Layout.Z1 + 5)
heartbeat:Fire()
check(not store:FindFirstChild('LocalTechInterior'), 'Walking past creates zero interior geometry')
check(firstRack:IsDescendantOf(store) and firstRack.Transparency == 0, 'Walking past keeps the empty rack visible')
rootPart.Position = frame * v3(0, 3.3, Layout.Z1 - 8)
heartbeat:Fire()
local folder = store:FindFirstChild('LocalTechInterior')
check(folder and #folder:GetChildren() > 0 and #folder:GetChildren() <= 12, 'Entry builds at most twelve parts per frame')
rootPart.Position = frame * v3(0, 3.3, Layout.Z1 + 2)
heartbeat:Fire()
check(not folder.Parent and not store:FindFirstChild('LocalTechInterior') and exits == 1, 'Leaving cancels a partial build')
check(firstRack:IsDescendantOf(store) and firstRack.Transparency == 0, 'Cancelling contents never unloads the rack')
for _ = 1, 5 do heartbeat:Fire() end
check(not store:FindFirstChild('LocalTechInterior'), 'Cancelled builder cannot repopulate outside')
rootPart.Position = frame * v3(0, 3.3, Layout.Z1 - 8)
for _ = 1, 400 do heartbeat:Fire() end
folder = store:FindFirstChild('LocalTechInterior')
local detailParts, prompts, lights = 0, 0, 0
local completeTowers, demoMonitors, samples = 0, 0, 0
for _, p in folder:GetDescendants() do
  if p:IsA('BasePart') then
    detailParts += 1
    check(not p.CanCollide and not p.CanTouch and not p.CanQuery and not p.CastShadow, 'Detail has no physics or shadow cost')
    check(p.Size.X > 0 and p.Size.Y > 0 and p.Size.Z > 0, 'Detail has valid dimensions')
    check(p.Name ~= 'PrebuiltDemoDesk' and p.Name ~= 'RackPlinth', 'Local contents do not duplicate permanent furniture')
  elseif p:IsA('Model') and p.Name == 'PrebuiltPC' then completeTowers += 1
  elseif p:IsA('Model') and p.Name == 'PrebuiltMonitor' then demoMonitors += 1
  elseif p:IsA('Model') and p.Name == 'Sample' then samples += 1
  elseif p:IsA('PointLight') then lights += 1; check(not p.Shadows, 'Interior lights have no shadows')
  elseif p:IsA('ProximityPrompt') then
    prompts += 1
    check(p.HoldDuration == 0.8 and p.KeyboardKeyCode == Enum.KeyCode.E, 'All products use hold E')
    check(p.GamepadKeyCode == Enum.KeyCode.ButtonX, 'Controller purchase is supported')
    check(p.Style == Enum.ProximityPromptStyle.Default and p.UIOffset.Y == -70, 'Native E prompt is explicitly shown above the shelf tag')
  end
end
check(completeTowers == 6 and demoMonitors == 6 and outsideDesks == 6, 'Complete PC contents are on permanent demo islands')
local itemCount = 0
for _ in Catalog.Items do itemCount += 1 end
check(samples == itemCount, 'Every part on sale has a real PcModel sample on its shelf')
check(prompts == count and lights == 0 and detailParts > 2000, 'Only merchandise and its purchase prompts load on entry')
for key in ids do check(products[key] ~= nil, 'Prompt binds to the exact product') end
-- Regression from the in-game screenshot: the included stock fan used to have no E button.
local shown = Catalog.decode(nil)
local function money(value) return '$'..value end
local stockPrompt = products['Item:FanStock']
local stockEntry = Layout.product('Item','FanStock')
Presentation.update(stockPrompt,stockEntry,shown,false,money)
check(stockPrompt.Enabled and stockPrompt.ActionText == 'Installed / included', 'Included stock fan keeps a visible E prompt')
local towerPrompt = products['Item:FanTower']
local towerEntry = Layout.product('Item','FanTower')
Presentation.update(towerPrompt,towerEntry,shown,false,money)
check(towerPrompt.Enabled and towerPrompt.ActionText == 'Buy $400', 'Paid upgrade shows its actual buy price')
Catalog.buy(shown,'Item','FanTower')
Presentation.update(stockPrompt,stockEntry,shown,false,money)
Presentation.update(towerPrompt,towerEntry,shown,false,money)
check(stockPrompt.Enabled and stockPrompt.ActionText == 'Installed / included', 'Buying a part does not swap it in at the store')
check(towerPrompt.Enabled and towerPrompt.ActionText == 'Owned / fit at workbench', 'Owned parts point at the workbench')
Catalog.fit(shown, { Cooling = 'FanTower' })
Presentation.update(stockPrompt,stockEntry,shown,false,money)
Presentation.update(towerPrompt,towerEntry,shown,false,money)
check(stockPrompt.Enabled and stockPrompt.ActionText == 'Owned / fit at workbench', 'A swapped-out starter stays discoverable')
check(towerPrompt.Enabled and towerPrompt.ActionText == 'Already installed', 'Installed paid parts keep a visible E prompt')
Presentation.update(towerPrompt,towerEntry,shown,true,money)
check(not towerPrompt.Enabled, 'Only an in-flight request temporarily hides the prompt')
Presentation.update(towerPrompt,towerEntry,shown,false,money)
check(towerPrompt.Enabled, 'Prompt returns after a request completes')
shown.Licenses.WebShop = true
local licensePrompt = products['License:WebShop']
Presentation.update(licensePrompt,Layout.product('License','WebShop'),shown,false,money)
check(licensePrompt.Enabled and licensePrompt.ActionText == 'Already licensed', 'Owned licenses remain discoverable')
Catalog.buy(shown,'Prebuilt','HarbourHome')
local buildPrompt = products['Prebuilt:HarbourHome']
Presentation.update(buildPrompt,Layout.product('Prebuilt','HarbourHome'),shown,false,money)
check(buildPrompt.Enabled and buildPrompt.ActionText == 'Take home (parts owned)', 'Owned complete PCs can be picked up again')
humanoid.Health = 0; heartbeat:Fire()
check(not folder.Parent, 'Death unloads the interior')
check(firstRack:IsDescendantOf(store) and firstRack.Transparency == 0, 'Death removes contents without removing the racks')
humanoid.Health = 100; heartbeat:Fire()
folder = store:FindFirstChild('LocalTechInterior')
player.Character = nil; heartbeat:Fire()
check(not folder.Parent, 'Missing character unloads the interior')
player.Character = Instance.new('Model'); rootPart.Parent = player.Character; humanoid.Parent = player.Character
heartbeat:Fire(); folder = store:FindFirstChild('LocalTechInterior')
removed:Fire(store)
check(not folder.Parent, 'Stream-out cleans up local geometry')
heartbeat:Fire(); check(not store:FindFirstChild('LocalTechInterior'), 'Removed stores never resume')
added:Fire(store); heartbeat:Fire()
check(store:FindFirstChild('LocalTechInterior'), 'Stream-in can build again')
-- Simulate an expensive registration. The time budget stops before twelve parts.
rootPart.Position = frame * v3(0, 3.3, Layout.Z1 + 4); heartbeat:Fire()
local originalNew = Instance.new
Instance.new = function(class)
  if class == 'Part' then clock += 0.002 end
  return originalNew(class)
end
rootPart.Position = frame * v3(0, 3.3, Layout.Z1 - 8); heartbeat:Fire()
folder = store:FindFirstChild('LocalTechInterior')
check(#folder:GetChildren() == 1, 'Expensive creation stops at the frame time budget')
Instance.new = originalNew

-- Tags can precede their frame attribute during streaming.
removed:Fire(store)
store:SetAttribute('StoreFrame', nil); added:Fire(store); heartbeat:Fire()
check(not store:FindFirstChild('LocalTechInterior'), 'Missing streaming attributes do not build in the wrong place')
store:SetAttribute('StoreFrame', frame); heartbeat:Fire()
check(store:FindFirstChild('LocalTechInterior'), 'Late streaming frame recovers')

Service.start(map)
local remote = rs:FindFirstChild('TechStore')
local function buy(kind, id) clock += 1; return remote.OnServerInvoke(player, 'Buy', kind, id) end
rootPart.Position = frame * v3(0, 3.3, Layout.Z1 + 5)
check(not buy('Item', 'Cpu486').Ok and commits == 0, 'Remote purchase outside is refused')
local cpu = Layout.product('Item', 'Cpu486')
rootPart.Position = (frame * cpu.PromptFrame * CFrame.new(0, 0, 1.6)).Position
check(not buy('Item', 'GpuTsunami').Ok and commits == 0, 'Wrong rack cannot buy another product')
profile.Cash = 600
check(buy('Item', 'Cpu486').Ok and profile.Cash == 0 and commits == 1, 'Hold-E purchase charges actual catalog price')
check(profile.Tech.Owned.Cpu486 and profile.Tech.Equipped.CPU == nil, 'Purchase saves ownership into the parts bin')
check(player:GetAttribute('TechCPU') == 'Cpu386', 'The office PC keeps its processor until the workbench swaps it')
clock += 1
check(remote.OnServerInvoke(player, 'Equip', 'Item', 'Cpu486').Message:find('workbench'), 'The store no longer installs parts')
check(not buy('Item', 'Cpu486').Ok and commits == 1, 'Owned item cannot be charged twice')
humanoid.Health = 0
check(not buy('Item', 'Cpu486').Ok, 'Dead players cannot buy')
humanoid.Health = 100
check(not buy('Item', {}).Ok, 'Malformed product ids are refused')
local license = Layout.product('License', 'WebShop')
rootPart.Position = (frame * license.PromptFrame * CFrame.new(0, 0, 1.6)).Position
check(not buy('License', 'WebShop').Ok and commits == 1, 'Insufficient funds do not change the save')
profile.Cash = 3500
check(buy('License', 'WebShop').Ok and profile.Tech.Licenses.WebShop and profile.Cash == 0, 'Physical license display unlocks the real app')
rootPart.Position = frame * v3(26, 3.3, Layout.Z1 + 0.05)
check(not buy('License', 'WebShop').Ok, 'Nearby exterior position fails the inside check')
local prebuilt = Layout.product('Prebuilt', 'HarbourHome')
check(not buy('Prebuilt', 'HarbourHome').Ok, 'A prebuilt cannot be purchased from outside')
rootPart.Position = (frame * cpu.PromptFrame * CFrame.new(0,0,1.6)).Position
check(not buy('Prebuilt', 'HarbourHome').Ok, 'A prebuilt cannot be purchased from a component rack')
rootPart.Position = (frame * prebuilt.PromptFrame * CFrame.new(0,0,1.6)).Position
local quote = Catalog.prebuiltPrice(Catalog.decode(profile.Tech), 'HarbourHome')
check(quote == 2400, 'Already-owned processor is credited against the complete PC')
profile.Cash = quote - 1
local before = commits
check(not buy('Prebuilt', 'HarbourHome').Ok and commits == before, 'Insufficient funds cannot partially buy a build')
profile.Cash = quote
check(buy('Prebuilt', 'HarbourHome').Ok and profile.Cash == 0, 'Hold E buys the complete PC for the remaining price')
local purchased = Catalog.decode(profile.Tech)
check(not Catalog.prebuiltInstalled(purchased, 'HarbourHome'), 'A complete PC is carried home, not installed at the till')
check(#handed == 1 and handed[1].Name == 'Harbour Home', 'The complete PC is handed to the buyer')
for slot, id in Catalog.Prebuilts.HarbourHome.Parts do
  check(Catalog.owns(purchased, id) and handed[1].Parts[slot] == id, 'Complete PC parts are owned and in the handed-over PC: '..slot)
end
check(purchased.Licenses.WebShop, 'Buying a PC preserves existing licenses')
carrying = true
local full = buy('Prebuilt', 'HarbourHome')
check(not full.Ok and #handed == 1, 'Nobody is handed a second PC while their hands are full')
carrying = false
check(buy('Prebuilt', 'HarbourHome').Ok and profile.Cash == 0 and #handed == 2, 'Owned complete PCs can be picked up again for free')
check(not buy('Prebuilt', 'bogus').Ok, 'Unknown complete PCs are refused')
output(string.format('Micro Harbour interior: %d checks passed; %d products, %d local detail parts, %d server parts, %d route samples', checks, count, detailParts, serverParts, pathSamples))

`;
const temp = await mkdtemp(join(tmpdir(), 'tech-interior-'));
try {
  const path = join(temp, 'check.luau');
  await writeFile(path, bundle);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', path], { cwd: root, encoding: 'utf8', timeout: 60000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Micro Harbour interior check failed');
} finally {
  await rm(temp, { recursive: true, force: true });
}
