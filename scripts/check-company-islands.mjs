// Execute real map builders and ownership service with recording Roblox doubles.
// This does not simulate Studio rendering, streaming, Humanoids or DataStores.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { renderPreview } from './company-island-preview.mjs';
// --preview out.png also renders the wild and the owned island from above.
const previewAt = process.argv.indexOf('--preview');
const previewPath = previewAt > 0 ? process.argv[previewAt + 1] : null;
const read = path => readFile(path, 'utf8');
const harbourFootprint = Number((await read('src/server/Map/Harbour.luau')).match(/Harbour\.FOOTPRINT = (\d+)/)[1]);
const primitives = (await read('scripts/harbour-geometry.luau')).split('local CFrame = {}')[0];
const mocks = (await read('scripts/drydock-geometry.luau')).split('local function loadBoatCatalog()')[0]
  .replace('-- SHARED_PRIMITIVES --', () => primitives);
const module = async path => (await read(path)).replace(/^local (\w+) = require\(.*$/gm, 'local $1 = dependencies.$1');
let program = mocks + `
UDim2.fromOffset = UDim2.new
local frameIndex = frameMt.__index
function frameMt.__index(self, key)
  if key == "X" or key == "Y" or key == "Z" then return self.Position[key] end
  return frameIndex(self, key)
end
local baseIndex = instanceMt.__index
function instanceMt.__index(self, key)
  return baseIndex(self, key) or self:FindFirstChild(key)
end
local function signal()
  local callbacks = {}
  return { Connect = function(_, callback) table.insert(callbacks, callback) end,
    Fire = function(_, ...) for _, callback in callbacks do callback(...) end end }
end
function instanceMethods:GetAttributeChangedSignal(key)
  self._signals = self._signals or {}
  self._signals[key] = self._signals[key] or signal()
  return self._signals[key]
end
function instanceMethods:FindFirstAncestorOfClass(class)
  local ancestor = self.Parent
  while ancestor do if ancestor:IsA(class) then return ancestor end; ancestor = ancestor.Parent end
end
local pendingSignals = {}
function CollectionService:GetInstanceAddedSignal(tag)
  pendingSignals[tag] = pendingSignals[tag] or signal()
  return pendingSignals[tag]
end
function CollectionService:GetTagged(tag)
  local result = {}
  for _, model in workspace:GetDescendants() do if self:HasTag(model, tag) then table.insert(result, model) end end
  return result
end
local Players = Instance.new("Players")
Players.PlayerAdded, Players.PlayerRemoving = signal(), signal()
function Players:GetPlayers() return self:GetChildren() end
function Players:GetPlayerByUserId(id)
  for _, player in self:GetChildren() do if player.UserId == id then return player end end
end
local ReplicatedStorage = Instance.new("Folder")
local ProximityPromptService = { PromptTriggered = signal() }
local baseService = game.GetService
function game:GetService(name)
  if name == "HttpService" then return {JSONEncode = function(_, data) return "coast:" .. #data end} end
  if name == "Players" then return Players end
  if name == "ReplicatedStorage" then return ReplicatedStorage end
  if name == "ProximityPromptService" then return ProximityPromptService end
  return baseService(self, name)
end
local count = 0
local function check(value, message) count += 1; assert(value, message) end
-- Dressings build in a spawned task; run it at once. Streaming pieces are Studio-only.
task.spawn = function(callback, ...) callback(...) end
local pinned = {}
dependencies.Lod = {pin = function(model) table.insert(pinned, model) end, release = function() end}
`;
for (const [name, path] of Object.entries({
  Layout: 'src/shared/CompanyIslands.luau', LowPoly: 'src/server/Map/LowPoly.luau',
  Props: 'src/server/Map/Props.luau', Kitchen: 'src/server/Map/Kitchen.luau',
  StorageRack: 'src/server/Map/StorageRack.luau', MapIslands: 'src/server/Map/CompanyIslands.luau',
  Access: 'src/server/CompanyIslandAccess.luau', Furniture: 'src/shared/FurnitureCatalog.luau',
})) {
  program += `\nlocal ${name} = (function()\n${await module(path)}\nend)()\ndependencies.${name} = ${name}\n`;
}
// Shared geometry checks for both dressings, used before and after ownership changes.
program += `
local function climb(frame, steps, minimumWidth, label)
  table.sort(steps, function(a,b) return frame:PointToObjectSpace(a.Position).Z < frame:PointToObjectSpace(b.Position).Z end)
  check(#steps == 32, label .. " have thirty-two walking steps")
  local top = 4.4
  for _, part in steps do
    local nextTop = part.Position.Y + part.Size.Y / 2
    check(math.abs(nextTop - top - 0.625) < 0.001 and part.Size.X >= minimumWidth, label .. ": no oversized riser or narrow step")
    top = nextTop
  end
  check(math.abs(top - 24.4) < 0.001, label .. " meet the upper terrace")
end
local function named(root, name)
  local result = {}
  for _, part in root:GetDescendants() do if part.Name == name then table.insert(result, part) end end
  return result
end
-- Every loose part in a model too big for one streaming piece would stream on its own.
local function checkPieces(dressing)
  local function parts(model)
    local n = 0
    for _, d in model:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
    return n
  end
  local function walk(model)
    if parts(model) <= 200 then return end
    for _, child in model:GetChildren() do
      check(not child:IsA("BasePart"), "Big dressing models hold no loose parts: " .. model.Name)
      if child:IsA("Model") then walk(child) end
    end
  end
  walk(dressing)
end
function checkWild(island)
  local frame = island:GetAttribute("IslandFrame")
  local dressing = island:FindFirstChild("Dressing")
  check(dressing and dressing:GetAttribute("Kind") == "Wild" and island:GetAttribute("Dressing") == "Wild", "Unowned islands are plain wild land")
  check(#named(island, "StairTread") == 0 and #named(island, "PlotPad") == 0 and #named(island, "QuayPlank") == 0, "Wild land has no village, quay or plot")
  check(island:FindFirstChild("StorageHouse") == nil and island:FindFirstChild("KitchenHouse") == nil and island:FindFirstChild("OfficeHouse") == nil, "The old company houses are gone")
  check(island:FindFirstChild("SpawnRowboatPrompt", true) == nil, "A free island has no boat launch")
  check(island:FindFirstChild("PropertyBoard") and island:FindFirstChild("BuyCompanyIslandPrompt", true), "The sale board stays on the beach")
  check(island:FindFirstChild("BoatSpawn") and island:FindFirstChild("PlotFurniture"), "Permanent dock marker and furniture holder exist")
  climb(frame, named(dressing, "RoughStep"), 8, "Wild rock steps")
  check(#named(dressing, "JettyPlank") > 10, "Wild land keeps a jetty to land on")
  checkPieces(dressing)
end
function checkVillage(island, owner)
  local frame = island:GetAttribute("IslandFrame")
  local dressing = island:FindFirstChild("Dressing")
  check(dressing and dressing:GetAttribute("Kind") == "Village" and island:GetAttribute("Dressing") == "Village", "Owned islands become a village")
  check(#island:GetChildren() == #({island:FindFirstChild("Ground"), island:FindFirstChild("PropertyBoard"), island:FindFirstChild("PropertySign"), island:FindFirstChild("BoatSpawn"), island:FindFirstChild("PlotFurniture"), dressing}), "One dressing replaces the other")
  check(#named(island, "RoughStep") == 0, "The wild dressing is removed")
  local stairs = dressing:FindFirstChild("TerraceStairs")
  local treads = {}
  for _, part in stairs:GetChildren() do if part.Name == "StairTread" then table.insert(treads, part) end end
  climb(frame, treads, 12, "Stone stairs")
  local plotFrame = island:GetAttribute("PlotFrame")
  check((plotFrame.Position - Layout.plotFrame(island:GetAttribute("IslandId")).Position).Magnitude < 0.001, "The plot frame follows the shared layout")
  local pad = named(dressing, "PlotPad")[1]
  check(pad and math.abs(pad.Position.Y + pad.Size.Y / 2 - plotFrame.Position.Y) < 0.001, "Furniture stands exactly on the empty plot")
  check(pad.Size.X >= Furniture.PLOT[3] - Furniture.PLOT[1] and pad.Size.Z >= Furniture.PLOT[4] - Furniture.PLOT[2], "The pad covers the whole placement area")
  check(math.abs(plotFrame.Position.Y - 24.4 - 0.16) < 0.001, "The plot sits on the terrace")
  -- Nothing solid stands inside the plot apart from its pad: it starts empty.
  for _, part in dressing:GetDescendants() do
    if part:IsA("BasePart") and part.CanCollide and part.Name ~= "PlotPad" then
      local p = plotFrame:PointToObjectSpace(part.Position)
      check(not (p.X > Furniture.PLOT[1] and p.X < Furniture.PLOT[3] and p.Z > Furniture.PLOT[2] and p.Z < Furniture.PLOT[4] and p.Y > -1 and p.Y < 12), "The plot is empty: " .. part.Name)
    end
  end
  -- The walk from the stairs to the gate stays clear.
  for _, part in dressing:GetDescendants() do
    if part:IsA("BasePart") and part.CanCollide then
      for z = 3, Layout.PLOT_Z - 34, 1 do
        local point = part.CFrame:PointToObjectSpace(frame * Vector3.new(0, 27, z))
        check(not (math.abs(point.X) < part.Size.X/2 + 1 and math.abs(point.Y) < part.Size.Y/2 + 2 and math.abs(point.Z) < part.Size.Z/2), "The way from the stairs to the plot gate is clear: " .. part.Name)
      end
    end
  end
  local launch = dressing:FindFirstChild("SpawnRowboatPrompt", true)
  check(island:FindFirstChild("BoatSpawn") and launch, "The village dock has a boat launch")
  check(launch:GetAttribute("OwnerUserId") == owner, "Prompts built with the village know their owner")
  check(#named(dressing, "QuayPlank") > 10 and #named(dressing, "PierPlank") >= 30 and #named(dressing, "WallStone") > 20, "The village has a planked quay, piers and a stone harbour wall")
  check(#dressing:GetDescendants() > 1500, "The village is richly detailed")
  checkPieces(dressing)
  check(pinned[#pinned] == dressing, "Swapped dressings are cut into streaming pieces")
end
`;
// The map's dependency is named Layout; all modules above are production source.
program += `
local map = Instance.new("Folder")
map.Parent = workspace
MapIslands.ensure(map)
check(Layout.COUNT == 15 and #map:GetChildren() == Layout.COUNT, "Every player in the lobby has a company island")
local first = map:FindFirstChild("Company Island 1")
MapIslands.ensure(map)
check(#map:GetChildren() == Layout.COUNT and map:FindFirstChild("Company Island 1") == first, "Baked maps are repaired idempotently")
local reserved = {}
MapIslands.reserve(reserved)
check(#reserved == Layout.COUNT, "All property footprints are reserved before scenery placement")
do
  local desk = MapIslands.buildDesk(Instance.new("Folder"), Furniture.frame(CFrame.identity, { ItemId = "CompanyDesk", X = 0, Z = 0, R = 0 }, "Company"))
  local area = Furniture.footprint("CompanyDesk", 0, 0, 0)
  for _, part in desk:GetDescendants() do
    if part:IsA("BasePart") then
      for _, x in {-0.5, 0.5} do for _, z in {-0.5, 0.5} do
        local corner = part.CFrame * Vector3.new(x * part.Size.X, 0, z * part.Size.Z)
        check(corner.X >= area[1] - 0.01 and corner.X <= area[3] + 0.01 and corner.Z >= area[2] - 0.01 and corner.Z <= area[4] + 0.01, "The company desk fits its placement footprint: " .. part.Name)
      end end
    end
  end
end
local names = {}
for id = 1, Layout.COUNT do
  local island = map:FindFirstChild("Company Island " .. id)
  check(type(Layout.Names[id]) == "string" and Layout.Names[id] ~= "" and not names[Layout.Names[id]], "Every property has a distinct visible name")
  names[Layout.Names[id]] = true
  local frame = island:GetAttribute("IslandFrame")
  check((Vector2.new(frame.X, frame.Z) - Layout.position(id)).Magnitude < 0.001, "Properties use the shared ring layout")
  check(Layout.position(id).Magnitude - Layout.FOOTPRINT > ${harbourFootprint}, "The approach clears Gullhaven's current footprint")
  check(frame.LookVector:Dot((-frame.Position).Unit) > 0.999, "Every company dock faces the main island")
  for other = id + 1, Layout.COUNT do
    check((Layout.position(id) - Layout.position(other)).Magnitude > 2 * Layout.FOOTPRINT, "Property reservations never overlap")
  end
  check(island:GetAttribute("ChartCoast") == "coast:19", "Chart coast is published")
  checkWild(island)
end
-- Old seeded scenery can occupy the new reservations in a Studio bake.
map:FindFirstChild("Company Island " .. Layout.COUNT):Destroy()
local scenery = Instance.new("Model")
scenery.Name, scenery.Parent = "Island", map
local ground = Instance.new("Model")
ground.Name, ground.Parent = "Ground", scenery
Props.part(ground, Vector3.new(30, 10, 30), first:GetAttribute("IslandFrame"), Color3.new(), Enum.Material.Rock)
MapIslands.ensure(map)
check(scenery.Parent == nil and first.Parent == map, "Baked scenery is removed without removing a property")

do
  -- Model the previous six-property Studio bake without introducing duplicate
  -- tagged properties into the live ownership-service world below.
  local baked = Instance.new("Folder")
  local old = {}
  check(MapIslands.VERSION > 1, "The expanded layout must migrate the previous six-property version")
  for id = 1, 6 do
    local island = Instance.new("Model")
    island.Name, island.Parent = "Company Island " .. id, baked
    island:SetAttribute("CompanyIslandVersion", 1)
    island:SetAttribute("IslandId", id)
    local angle = math.rad(-90 + (id - 1) * 60)
    local position = Vector3.new(math.cos(angle) * 1160, 0, math.sin(angle) * 1160)
    island:SetAttribute("IslandFrame", CFrame.lookAt(position, Vector3.zero))
    old[id] = island
  end
  local lod = Instance.new("Model")
  lod.Name, lod.Parent = "Lod", baked
  Props.part(lod, Vector3.new(20, 10, 20), old[1]:GetAttribute("IslandFrame"), Color3.new(), Enum.Material.Rock)
  local harbour = Instance.new("Model")
  harbour.Name, harbour.Parent = "Harbour Isle", baked
  local playerBase = Instance.new("Model")
  playerBase.Name, playerBase.Parent = "PlayerBaseFixture", harbour
  playerBase:SetAttribute("OwnerUserId", 12345)
  CollectionService:AddTag(playerBase, "PlayerBase")
  local distant = Instance.new("Model")
  distant.Name, distant.Parent = "Island", baked
  local distantGround = Instance.new("Model")
  distantGround.Name, distantGround.Parent = "Ground", distant
  Props.part(distantGround, Vector3.new(30, 10, 30), CFrame.new(5000, 0, 5000), Color3.new(), Enum.Material.Rock)
  MapIslands.ensure(baked)
  check(lod.Parent == nil, "Moving the old properties must discard their stale LOD shells")
  check(harbour.Parent == baked and playerBase.Parent == harbour and playerBase:GetAttribute("OwnerUserId") == 12345,
    "Property migration preserves player bases and their ownership")
  check(distant.Parent == baked, "Property migration preserves scenery outside its reservations")
  local migrated = {}
  for id = 1, Layout.COUNT do
    local island = baked:FindFirstChild("Company Island " .. id)
    check(island and island:GetAttribute("CompanyIslandVersion") == MapIslands.VERSION,
      "The old bake expands to every current company property")
    check((island:GetAttribute("IslandFrame").Position - Layout.frame(id).Position).Magnitude < 0.001,
      "Migrated properties use their new shared positions")
    if old[id] then
      check(old[id].Parent == nil and island ~= old[id], "Legacy property geometry is replaced")
      check((old[id]:GetAttribute("IslandFrame").Position - island:GetAttribute("IslandFrame").Position).Magnitude > 100,
        "The original six properties move clear of the enlarged harbour")
    end
    migrated[id] = island
  end
  local currentLod = Instance.new("Model")
  currentLod.Name, currentLod.Parent = "Lod", baked
  local children = #baked:GetChildren()
  MapIslands.ensure(baked)
  check(#baked:GetChildren() == children, "Migrating the expanded bake again adds no duplicates")
  check(currentLod.Parent == baked, "Current-layout LOD geometry survives the idempotent early return")
  for id = 1, Layout.COUNT do
    check(baked:FindFirstChild("Company Island " .. id) == migrated[id], "Current property geometry survives repeated migration")
  end
end

-- Run the production ownership and transaction service.
local clockTime = 1
local os = {clock = function() clockTime += 1; return clockTime end}
task.defer = function(callback) callback() end
local profiles = {}
local notices = {}
function instanceMethods:FireClient(player, kind, value) table.insert(notices, {player, kind, value}) end
local yieldSave, failSave = false, false
dependencies.CompanyIslandAccess = Access
dependencies.CompanyIslands = Layout
dependencies.BoatService = {
  getProfile = function(player) return profiles[player] end,
  updateProgress = function(player, transform)
    if yieldSave then yieldSave = false; coroutine.yield("saving") end
    if failSave or player.Parent ~= Players then return false, "Save failed" end
    transform(profiles[player])
    player:GetAttributeChangedSignal("AnglerRevision"):Fire()
    return true, "Saved"
  end,
}
dependencies.KitchenService = {addPrompts = function(model, frame, key)
  local anchor = Instance.new("Part"); anchor.Name, anchor.Parent = "KitchenPromptAnchor", model
end}
local synced = {}
dependencies.FurnitureService = {refreshKitchenStorage = function() end, syncCompany = function(island) synced[island] = (synced[island] or 0) + 1 end}
`;
program += `\nlocal Service = (function()\n${await module('src/server/CompanyIslandService.luau')}\nend)()\nService.start()\n`;
program += `
local request = ReplicatedStorage:FindFirstChild("CompanyIslands"):FindFirstChild("Request")
local nextId = 100
local function player(cash, company, preferred)
  nextId += 1
  local player = Instance.new("Player")
  player.UserId, player.DisplayName, player.Parent = nextId, "Buyer" .. nextId, Players
  local character = Instance.new("Model")
  local root = Instance.new("Part")
  root.Name, root.Parent = "HumanoidRootPart", character
  local humanoid = Instance.new("Humanoid")
  humanoid.Health, humanoid.Parent = 100, character
  player.Character = character
  profiles[player] = {Cash = cash, Angler = {CompanyIsland = preferred, Storage = {}, KitchenStorage = {Fish = {}}, Paths = {Unlocked = {Company = company}}}}
  Players.PlayerAdded:Fire(player)
  return player
end
local function approach(player, id)
  player.Character:FindFirstChild("HumanoidRootPart").CFrame = map:FindFirstChild("Company Island " .. id):FindFirstChild("PropertyBoard").CFrame
end
local locked = player(100000, false)
approach(locked, 1)
check(not request.OnServerInvoke(locked, "Buy", 1).Ok and profiles[locked].Cash == 100000, "Server enforces the Company unlock")
local poor = player(49999, true)
approach(poor, 1)
check(not request.OnServerInvoke(poor, "Buy", 1).Ok and profiles[poor].Cash == 49999, "Insufficient cash is not charged")
local buyer = player(100000, true)
check(not request.OnServerInvoke(buyer, "Buy", 1).Ok, "Remote purchases require physical proximity")
approach(buyer, 1)
local competitor = player(100000, true)
approach(competitor, 1)
yieldSave = true
local result
local purchase = coroutine.create(function() result = request.OnServerInvoke(buyer, "Buy", 1) end)
check(coroutine.resume(purchase), "First buyer reaches a yielding save")
check(not request.OnServerInvoke(competitor, "Buy", 1).Ok and profiles[competitor].Cash == 100000, "A concurrent buyer cannot steal a reserved island")
check(coroutine.resume(purchase) and result.Ok, "Successful save assigns the reserved island")
check(first:GetAttribute("OwnerUserId") == buyer.UserId and profiles[buyer].Cash == 50000, "Ownership publishes after the charge")
checkVillage(first, buyer.UserId)
check((synced[first] or 0) > 0, "Buying furnishes the plot from the owner's save")
checkWild(map:FindFirstChild("Company Island 2"))
if ${previewPath ? 'true' : 'false'} then
  local function dump(island, tag)
    local frame = island:GetAttribute("IslandFrame")
    for _, part in island:GetDescendants() do
      if part:IsA("BasePart") and (part.Transparency or 0) < 1 then
        local cf, p = part.CFrame, frame:PointToObjectSpace(part.Position)
        local r, u, b = frame:VectorToObjectSpace(cf.RightVector), frame:VectorToObjectSpace(cf.UpVector), frame:VectorToObjectSpace(cf.ZVector)
        local c = part.Color or {R = 0.5, G = 0.5, B = 0.5}
        print(string.format("@P %s %s %.2f %.2f %.2f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.2f %.2f %.2f %.3f %.3f %.3f", tag,
          if part.ClassName == "WedgePart" then "W" else "B", p.X, p.Y, p.Z, r.X, r.Y, r.Z, u.X, u.Y, u.Z, b.X, b.Y, b.Z,
          part.Size.X, part.Size.Y, part.Size.Z, c.R, c.G, c.B))
      end
    end
  end
  dump(map:FindFirstChild("Company Island 2"), "Wild")
  dump(first, "Village")
end
approach(buyer, 2)
check(not request.OnServerInvoke(buyer, "Buy", 2).Ok and profiles[buyer].Cash == 50000, "An owner cannot purchase twice")
local returning = player(0, true, 1)
check(Access.get(returning) and returning:GetAttribute("CompanyIslandId") == 2 and profiles[returning].Cash == 0, "A returning owner gets a free alternative when their preferred island is occupied")
approach(competitor, 3)
failSave = true
check(not request.OnServerInvoke(competitor, "Buy", 3).Ok and profiles[competitor].Cash == 100000, "Failed saves leave cash and ownership unchanged")
failSave = false
check(request.OnServerInvoke(competitor, "Buy", 3).Ok, "A failed save releases the plot reservation")
for id = 4, Layout.COUNT do
  local owner = player(0, true, id)
  check(owner:GetAttribute("CompanyIslandId") == id, "Returning owners allocate the remaining islands without a charge")
end
local waiting = player(0, true, 1)
check(Access.get(waiting) == nil and profiles[waiting].Angler.CompanyIsland == 1, "A full server preserves the paid entitlement")
local released = Access.get(returning)
returning.Parent = nil
Players.PlayerRemoving:Fire(returning)
check(Access.get(waiting) == released, "Waiting owners receive a released island")
check(profiles[returning].Angler.CompanyIsland == 1 and profiles[returning].Cash == 0, "Leaving does not erase paid ownership")
checkVillage(released, waiting.UserId)
check(not Access.ownsPrompt(buyer, released:FindFirstChild("SpawnRowboatPrompt", true)), "Another owner's fixtures are not authorized")
check(Access.ownsPrompt(buyer, first:FindFirstChild("SpawnRowboatPrompt", true)), "Own property fixtures are authorized")
do
  -- A server with free islands turns a released one back into wild land.
  local leaving = Access.get(waiting)
  waiting.Parent = nil
  Players.PlayerRemoving:Fire(waiting)
  check(leaving:GetAttribute("OwnerUserId") == 0, "Leaving frees the island")
  checkWild(leaving)
  local back = player(0, true, 1)
  check(Access.get(back) == leaving, "The next owner gets the freed island")
  checkVillage(leaving, back.UserId)
end
print(string.format("Company islands: %d geometry, access, allocation and purchase-race checks passed.", count))
`;
// AnglerData loads the catalog lazily by relative path, which the bundle can't resolve.
const anglerData = (await read('src/server/AnglerData.luau')).replace('require("../shared/FurnitureCatalog")', 'dependencies.Furniture');
program += `\nlocal Data = (function()\n${anglerData}\nend)()\ndependencies.AnglerData = Data\n`;
program += `
local function fish(at)
  return {FishId="Trout", Mutation="Normal", Kg=2, Value=100, Rarity=10, Relative=1, CaughtAt=at}
end
-- Four racks and the kitchen table placed on the plot, as build mode would.
local plotFrame = first:GetAttribute("PlotFrame")
local placedKit = {
  {ItemId="StorageRack", X=-40.5, Z=18, R=0}, {ItemId="StorageRack", X=-36, Z=18, R=0},
  {ItemId="StorageRack", X=-31.5, Z=18, R=0}, {ItemId="StorageRack", X=-27, Z=18, R=0},
  {ItemId="KitchenStorage", X=27, Z=18, R=0},
}
for _, entry in placedKit do
  check(Furniture.check({}, entry.ItemId, entry.X, entry.Z, entry.R, nil, "Company") == nil, "Kit placements used by the porter are legal")
  local model = Instance.new("Model")
  model.Name, model.Parent = entry.ItemId, first:FindFirstChild("PlotFurniture")
  for key, value in entry do model:SetAttribute(key, value) end
end
local function resetCargo(amount)
  local angler = Data.decode({CompanyIsland=1, Staff={Porter=true}, CompanyFurniture=table.clone(placedKit)})
  angler.Holds.Rowboat = {}
  for i=1,amount do table.insert(angler.Holds.Rowboat, {Fish=fish(i), X=i, Y=1, R=0}) end
  profiles[buyer].Angler = angler
end
local boat = Instance.new("Model")
boat.Parent = workspace
local hull = Instance.new("Part")
hull.Parent, boat.PrimaryPart = boat, hull
local dockFrame = first:GetAttribute("BoatDockFrame")
boat:SetAttribute("PorterPickup", (dockFrame * CFrame.new(30, 4.4, -24)).Position)
dependencies.CompanyService = {mooredAtIsland=function() return "Rowboat", boat end}
dependencies.BoatService.activeBoat = function() return nil, nil end
dependencies.Catalog = {Fish={Trout={Rarity="Common"}}}
dependencies.CustomerService = {npc={bubble=function() end, spawn=function(position)
  local model = Instance.new("Model")
  local root = Instance.new("Part"); root.Name, root.Parent, root.CFrame = "HumanoidRootPart", model, CFrame.new(position)
  local humanoid = Instance.new("Humanoid"); humanoid.Health, humanoid.Parent = 100, model
  return model
end}}
local walked, cancelWalk = 0, false
local visits = {}
dependencies.Navigation = {walk=function(worker, position, allowed)
  check(type(position.X)=="number" and type(position.Y)=="number" and type(position.Z)=="number", "Navigation receives world positions")
  walked += 1
  table.insert(visits, position)
  if cancelWalk then first:SetAttribute("OwnerUserId", 0) end
  if not allowed() then return false end
  worker.root.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
  return true
end}
`;
const porter = (await module('src/server/CompanyIslandPorter.luau')).replace(/return Porter\s*$/, 'return {tick = tick}');
program += `\nlocal Porter = (function()\n${porter}\nend)()\n`;
program += `
resetCargo(8)
local porterState = {}
Porter.tick(first, porterState)
check(#profiles[buyer].Angler.Storage == 6 and #profiles[buyer].Angler.Holds.Rowboat == 2 and walked >= 6, "Porter delivers a bounded load to upper storage through the stair route")
local rackFront = (Furniture.frame(plotFrame, placedKit[1], "Company") * CFrame.new(0, 0, Furniture.Items.StorageRack.Depth / 2 + 1.2)).Position
check((visits[#visits] - rackFront).Magnitude < 0.001, "The porter unloads at the first placed rack")
check(plotFrame:PointToObjectSpace(visits[#visits - 1]).Z < -20, "The porter walks in through the plot gate")
profiles[buyer].Angler.KitchenStorage.Targets.Common = 2
Porter.tick(first, porterState)
check(#profiles[buyer].Angler.Storage == 4 and #profiles[buyer].Angler.KitchenStorage.Fish == 2, "Porter restocks the island kitchen from existing storage")
Porter.tick(first, porterState)
check(#profiles[buyer].Angler.Storage == 6 and #profiles[buyer].Angler.Holds.Rowboat == 0, "Porter empties the remaining cargo without duplicating fish")
resetCargo(1)
cancelWalk = true
Porter.tick(first, porterState)
check(#profiles[buyer].Angler.Holds.Rowboat == 1 and #profiles[buyer].Angler.Storage == 0, "Ownership changes cancel delivery without losing cargo")
first:SetAttribute("OwnerUserId", buyer.UserId)
cancelWalk = false
resetCargo(1)
for i=1,48 do table.insert(profiles[buyer].Angler.Storage, fish(i)) end
Porter.tick(first, porterState)
check(#profiles[buyer].Angler.Holds.Rowboat == 1 and #profiles[buyer].Angler.Storage == 48, "Full storage leaves the catch in its boat")
print("Company porter: physical-route transactions, kitchen restocking, cancellation and capacity passed.")
`;
const boatSource = await read('src/server/BoatService.luau');
program += `
local function nearPrompt(player, prompt) return (player.Character.HumanoidRootPart.Position - prompt.Parent.Position).Magnitude < 14 end
local function notify() end
${boatSource.slice(boatSource.indexOf('local function dockBase('), boatSource.indexOf('local function openDock('))}
local ownPrompt = first:FindFirstChild("SpawnRowboatPrompt", true)
buyer.Character.HumanoidRootPart.CFrame = ownPrompt.Parent.CFrame
competitor.Character.HumanoidRootPart.CFrame = ownPrompt.Parent.CFrame
check(dockBase(buyer, ownPrompt) == first, "Island dock accepts its owner without a harbour BaseId")
check(dockBase(competitor, ownPrompt) == nil, "Island dock rejects another owner")
print("Company dock: production launch permissions passed.")
`;
const kitchenService = (await module('src/server/KitchenService.luau')).replace(/return KitchenService\s*$/, 'return {stationNear = stationNear}');
program += `\nlocal KitchenService = (function()\n${kitchenService}\nend)()\n`;
program += `
do
  -- A placed prep bench, tagged the way FurnitureService builds one.
  local bench = Instance.new("Model")
  bench.Name, bench.Parent = "CompanyPrep", first:FindFirstChild("PlotFurniture")
  local benchFrame = Furniture.frame(plotFrame, {ItemId="CompanyPrep", X=0, Z=9, R=0}, "Company")
  bench:SetAttribute("StationKey", "CompanyPrep1")
  bench:SetAttribute("StationFrame", benchFrame)
  local benchAnchor = Instance.new("Part")
  benchAnchor.Name, benchAnchor.Parent = "KitchenPromptAnchor", bench
end
local station = Access.stations(buyer).CompanyPrep1
check(station and Access.stations(competitor).CompanyPrep1 == nil, "Placed benches belong to their island's owner")
local anchor = station.model:FindFirstChild("KitchenPromptAnchor")
anchor.CFrame = station.frame
buyer.Character.HumanoidRootPart.CFrame = anchor.CFrame
competitor.Character.HumanoidRootPart.CFrame = anchor.CFrame
check(KitchenService.stationNear(buyer, "CompanyPrep1"), "An island owner can use a kitchen even without a harbour base")
check(not KitchenService.stationNear(competitor, "CompanyPrep1"), "Other owners cannot remotely operate this kitchen")
print("Company kitchen: production station proximity and ownership passed.")
`;
const temp = await mkdtemp(join(tmpdir(), 'company-islands-'));
try {
  const target = join(temp, 'check.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], {encoding: 'utf8', timeout: 60000, maxBuffer: 4 * 1024 * 1024});
  const parts = (result.stdout || '').split('\n').filter(line => line.startsWith('@P '));
  if (result.stdout) process.stdout.write(result.stdout.split('\n').filter(line => !line.startsWith('@P ')).join('\n'));
  if (previewPath && result.status === 0) {
    await renderPreview(parts, previewPath);
    console.log('Preview: ' + parts.length + ' parts drawn to ' + previewPath);
  }
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Company island checks failed');
} finally { await rm(temp, {recursive: true, force: true}); }
