// The office PC workshop: the real PcWorkshopService, OfficeDesk.dress, Workbench and PcModel run
// against check-city's recording Roblox doubles. Covers picking the PC up off the desk, the desk
// going dark, putting it on the bench, unscrewing, swapping parts, screwing shut, carrying it back
// and the save changing; a store PC being handed over and dropped on death; and that every case
// fits on the desk and on the bench (with its panel aside). Not covered: Studio rendering, welds
// under physics, the client prompts/animation and the swap window (need a play test).
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = resolve(import.meta.dirname, '..');
const read = async p => (await readFile(join(root, p), 'utf8')).replaceAll('\r\n', '\n');
const city = await read('scripts/check-city.mjs');
const mocks = city.match(/const mocks = String.raw`([\s\S]*?)`;/)[1];
const swap = (source, pairs) => {
  for (const [from, to] of pairs) {
    if (!source.includes(from)) throw new Error('Source changed near: ' + from);
    source = source.replace(from, to);
  }
  return source;
};
const catalog = await read('src/shared/TechCatalog.luau');
const pcModel = swap(await read('src/shared/PcModel.luau'), [['require(script.Parent.TechCatalog)', 'TechCatalog']]);
const desk = await read('src/server/Map/OfficeDesk.luau');
const bench = await read('src/server/Map/Workbench.luau');
const service = swap(await read('src/server/PcWorkshopService.luau'), [
  ['game:GetService("CollectionService")', 'CollectionService'],
  ['game:GetService("Players")', 'Players'],
  ['game:GetService("ReplicatedStorage")', 'ReplicatedStorage'],
  ['require(script.Parent.BoatService)', 'BoatService'],
  ['require(ReplicatedStorage.Shared.PcModel)', 'PcModel'],
  ['require(ReplicatedStorage.Shared.TechCatalog)', 'TechCatalog'],
]);

const program = 'local output = print;' + mocks + String.raw`
local function signal()
  local callbacks = {}
  return { Connect = function(_, f) table.insert(callbacks, f); return { Disconnect = function() end } end,
    Fire = function(_, ...) for _, f in callbacks do f(...) end end }
end
local delayed = {}
task.delay = function(_, f) table.insert(delayed, f) end
task.spawn = function() end -- the bench-follow loop never ends; not run here
local function runDelayed() local list = delayed; delayed = {}; for _, f in list do f() end end

local TechCatalog = (function()
${catalog}
end)()
local PcModel = (function()
${pcModel}
end)()
local OfficeDesk = (function()
${desk}
end)()
local Workbench = (function()
${bench}
end)()

-- World: one base with the office desk and the workbench, one player standing in it.
local Players = { GetPlayers = function(self) return { self.player } end, PlayerAdded = signal(), PlayerRemoving = signal() }
local tagged = {}
local CollectionService = { GetTagged = function(_, tag) return tagged[tag] or {} end, HasTag = function() return false end }
local ReplicatedStorage = Instance.new("ReplicatedStorage")
local base = Instance.new("Model"); base:SetAttribute("OwnerUserId", 7); base.Parent = workspace
tagged.PlayerBase = { base }
local office = Instance.new("Folder"); office.Name = "Office"; office.Parent = base
local deskFrame = CFrame.new(100, 0.18, 50) * CFrame.Angles(0, 0.4, 0)
local deskModel = OfficeDesk.build(office, deskFrame)
local benchFrame = CFrame.new(140, 0.16, 20) * CFrame.Angles(0, -0.9, 0)
local benchModel = Workbench.build(base, benchFrame)
check(benchModel:GetAttribute("BenchFrame") == benchFrame, "The workbench records its frame for the workshop")

local attrs, notices = {}, {}
local character = Instance.new("Model"); character.Parent = workspace
local rootPart = Instance.new("Part"); rootPart.Name = "HumanoidRootPart"; rootPart.Parent = character
local hand = Instance.new("Part"); hand.Name = "RightHand"; hand.Size = Vector3.new(0.3, 0.3, 0.3); hand.Parent = character
local humanoid = Instance.new("Humanoid"); humanoid.Health = 100; humanoid.Parent = character
humanoid.UnequipTools = function() end
local player = { UserId = 7, Parent = Players, Character = character, CharacterRemoving = signal(),
  SetAttribute = function(_, k, v) attrs[k] = v end, GetAttribute = function(_, k) return attrs[k] end }
Players.player = player
local profile = { Cash = 0, Tech = { Owned = {}, Equipped = {} } }
local commits = 0
local BoatService = { getProfile = function() return profile end,
  updateProgress = function(_, change) change(profile); commits += 1; return true end }

local Service = (function()
${service}
end)()
local function dressDesk()
  local equipped = TechCatalog.decode(profile.Tech).Equipped
  local look = TechCatalog.deskLook(equipped)
  look.Away = Service.isAway(base)
  OfficeDesk.dress(deskModel, look, PcModel)
end
Service.start({ changed = function() dressDesk() end })
local folder = ReplicatedStorage:FindFirstChild("PcWorkshop")
local remote = folder:FindFirstChild("Request")
local noticeEvent = folder:FindFirstChild("Notice")
noticeEvent.FireClient = function(_, _, message) table.insert(notices, message) end
local clock = 0
os = { clock = function() clock += 1; return clock end }
local function act(action, slot, id) return remote.OnServerInvoke(player, action, slot, id) end
local function standAtDesk() rootPart.CFrame = deskFrame * CFrame.new(0, 3, 2.5) end
local function standAtBench() rootPart.CFrame = benchFrame * CFrame.new(0, 3, 3) end
local function find(parent, name) return parent:FindFirstChild(name, true) end
local function screenText(model)
  local screen = find(model, "ScreenCurve")
  local gui = screen and screen:FindFirstChild("Label")
  local line = gui and gui:FindFirstChildOfClass("TextLabel")
  return line and line.Text or ""
end

-- The starter desk is dressed by PcModel: a desktop with its monitor on top.
dressDesk()
check(find(deskModel, "Rig") and find(deskModel, "SystemUnit"), "The desk shows the company's PC")
check(not deskModel:GetAttribute("PcAway"), "A fresh desk has its PC")
check(screenText(deskModel):find("HARBOUR"), "The starter monitor shows the DOS prompt")

-- Pick it up.
rootPart.CFrame = deskFrame * CFrame.new(0, 3, 40)
check(not act("PickUpDesk").Ok, "Picking up needs you at your desk")
standAtDesk()
local picked = act("PickUpDesk")
check(picked.Ok and attrs.PcCarry == "Desk" and attrs.PcRig == "Carried", "Picking the PC up off the desk carries it")
local carried = character:FindFirstChild("CarriedPC")
check(carried ~= nil, "The carried PC is in the player's arms")
local welds, unanchored = 0, 0
for _, part in carried:GetDescendants() do
  if part:IsA("BasePart") then
    check(not part.Anchored and part.Massless and not part.CanCollide, "Carried parts ride on the player")
    unanchored += 1
    local weld = part:FindFirstChildOfClass("WeldConstraint")
    if weld and weld.Part0 == rootPart then welds += 1 end
  end
end
check(unanchored > 0 and welds == unanchored, "Every carried part is welded to the player")
check(deskModel:GetAttribute("PcAway") == true and not find(deskModel, "SystemUnit"), "The desk is empty while the PC is away")
check(screenText(deskModel):find("NO SIGNAL"), "The monitor says NO SIGNAL")
check(not act("PickUpDesk").Ok, "Hands are full")
check(not Service.canReceive(player), "Nobody is handed a store PC on top of it")

-- Onto the bench and open it.
check(not act("PlaceBench").Ok, "The bench needs you standing at it")
standAtBench()
check(act("PlaceBench").Ok and benchModel:GetAttribute("PcState") == "Closed" and benchModel:GetAttribute("PcOwner") == 7, "The PC goes on the bench, closed")
check(not character:FindFirstChild("CarriedPC") and benchModel:FindFirstChild("BenchPC"), "The PC moved from the arms to the bench")
check(not act("Swap", "GPU", "GpuMono").Ok, "Parts can't be swapped through a closed case")
check(not act("Close").Ok, "A closed case can't be closed")
check(act("Open").Ok and benchModel:GetAttribute("PcState") == "Opening", "Unscrewing starts")
check(character:FindFirstChild("WorkshopScrewdriver"), "A screwdriver is in hand while unscrewing")
check(not act("PickUpBench").Ok and not act("Swap", "GPU", "GpuMono").Ok, "Nothing else happens mid-unscrew")
runDelayed()
check(benchModel:GetAttribute("PcState") == "Open" and not character:FindFirstChild("WorkshopScrewdriver"), "The case is open and the screwdriver put away")
local pc = benchModel:FindFirstChild("BenchPC")
local panel = pc:FindFirstChild("AccessPanel")
check(panel.WorldPivot == panel:GetAttribute("AsidePivot"), "The panel leans aside once off")
check(pc:FindFirstChild("GPU") and pc:FindFirstChild("Motherboard"), "The open PC shows its insides")

-- Swap parts: only owned ones, and the bench PC changes.
check(not act("Swap", "GPU", "GpuTsunami").Ok, "Unowned parts can't be fitted")
check(not act("Swap", "GPU", "Mono14").Ok, "Parts only go in their own slot")
profile.Tech.Owned = { GpuTsunami = true, CaseGlass = true, Psu1600 = true, CoolChiller = true }
check(act("Swap", "GPU", "GpuTsunami").Ok, "An owned card is fitted")
pc = benchModel:FindFirstChild("BenchPC")
check(find(pc, "CardGlow") ~= nil, "The new card shows up in the PC")
check(act("Swap", "Case", "CaseGlass").Ok and act("Swap", "Cooling", "CoolChiller").Ok and act("Swap", "PSU", "Psu1600").Ok, "Case, cooler and power supply swap")
pc = benchModel:FindFirstChild("BenchPC")
check(pc:GetAttribute("CaseForm") == "Tower" and find(pc, "ChillerBlock") and find(pc, "SideGlass"), "The rebuilt PC is a glass tower with the chiller")
check(pc:FindFirstChild("AccessPanel").WorldPivot == pc:FindFirstChild("AccessPanel"):GetAttribute("AsidePivot"), "The panel stays aside after a swap")
local state = act("Get").State
check(state.Parts.GPU == "GpuTsunami" and state.Where == "Bench" and state.State == "Open", "The client sees the bench build")
check(TechCatalog.decode(profile.Tech).Equipped.GPU == "GpuMono", "Nothing is saved until the PC is back on a desk")

-- Close, carry back, put down.
check(not act("PickUpBench").Ok, "An open PC can't be picked up")
check(act("Close").Ok and benchModel:GetAttribute("PcState") == "Closing", "Screwing shut starts")
runDelayed()
check(benchModel:GetAttribute("PcState") == "Closed", "The case is shut")
pc = benchModel:FindFirstChild("BenchPC")
check(pc:FindFirstChild("AccessPanel").WorldPivot == pc:FindFirstChild("AccessPanel"):GetAttribute("ClosedPivot"), "The panel is back on")
check(act("PickUpBench").Ok and attrs.PcCarry == "Desk" and benchModel:GetAttribute("PcState") == nil, "Picking it up clears the bench")
check(not benchModel:FindFirstChild("BenchPC") and character:FindFirstChild("CarriedPC"), "The PC is back in the player's arms")
check(not act("PlaceDesk").Ok, "Putting down needs you at the desk")
standAtDesk()
local before = commits
check(act("PlaceDesk").Ok and commits == before + 1 and attrs.PcCarry == nil and attrs.PcRig == nil, "Putting the PC down saves it")
local saved = TechCatalog.decode(profile.Tech).Equipped
check(saved.GPU == "GpuTsunami" and saved.Case == "CaseGlass" and saved.Cooling == "CoolChiller" and saved.PSU == "Psu1600", "The desk PC has the new parts")
check(not deskModel:GetAttribute("PcAway") and not character:FindFirstChild("CarriedPC"), "The desk has its PC again")
local unit = find(deskModel, "SystemUnit")
check(unit and unit:GetAttribute("CaseForm") == "Tower" and find(unit, "CardGlow"), "The desk shows the glass tower with the new card")

-- A complete PC from the store, dropped when its carrier dies.
check(Service.canReceive(player), "Empty hands can take a store PC")
check(Service.giveFromShop(player, TechCatalog.Prebuilts.KrakenUltra.Parts, "Kraken Ultra") and attrs.PcCarry == "Shop", "The store hands the PC over")
check(not deskModel:GetAttribute("PcAway"), "Carrying a new PC leaves the old one on the desk")
check(not Service.giveFromShop(player, TechCatalog.Prebuilts.HarbourHome.Parts, "Harbour Home"), "One PC at a time")
player.CharacterRemoving:Fire()
check(attrs.PcCarry == nil and #notices > 0 and notices[#notices]:find("for free"), "A dropped store PC can be picked up again for free")

-- Every case fits the desk, and on the bench with its panel leaning aside.
local function within(model, frame, x0, x1, y0, y1, z0, z1, what)
  for _, part in model:GetDescendants() do
    if part:IsA("BasePart") then
      local s = part.Size / 2
      for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
        local p = frame:PointToObjectSpace(part.CFrame * Vector3.new(sx * s.X, sy * s.Y, sz * s.Z))
        check(p.X >= x0 - 0.03 and p.X <= x1 + 0.03 and p.Y >= y0 - 0.03 and p.Y <= y1 + 0.03 and p.Z >= z0 - 0.03 and p.Z <= z1 + 0.03,
          what .. ": " .. part.Name .. string.format(" at %.2f %.2f %.2f", p.X, p.Y, p.Z))
      end end end
    end
  end
end
local deskParts = 0
for _, caseId in TechCatalog.Order.Case do
  for _, monitorId in TechCatalog.Order.Monitor do
    local parts = table.clone(TechCatalog.Prebuilts.KrakenUltra.Parts)
    parts.Case, parts.Monitor = caseId, monitorId
    local look = TechCatalog.deskLook(parts)
    OfficeDesk.dress(deskModel, look, PcModel)
    local rig = find(deskModel, "Rig")
    within(find(rig, "SystemUnit"), deskFrame, -OfficeDesk.WIDTH / 2, OfficeDesk.WIDTH / 2, OfficeDesk.HEIGHT - 0.05, 6, -OfficeDesk.DEPTH / 2, OfficeDesk.DEPTH / 2, caseId .. " on the desk")
    within(find(rig, "Monitor"), deskFrame, -OfficeDesk.WIDTH / 2, OfficeDesk.WIDTH / 2, OfficeDesk.HEIGHT - 0.05, 6, -OfficeDesk.DEPTH / 2, OfficeDesk.DEPTH / 2, monitorId .. " on the desk")
    -- The tower must not stand in the monitor.
    if look.Form ~= "Desktop" then
      local _, size = find(rig, "Monitor"):GetBoundingBox()
      local monitorCentre = deskFrame:PointToObjectSpace(find(rig, "Monitor"):GetBoundingBox().Position)
      local caseCentre = deskFrame:PointToObjectSpace(find(rig, "SystemUnit"):GetBoundingBox().Position)
      local info = PcModel.caseInfo(caseId)
      check(caseCentre.X - info.W / 2 >= monitorCentre.X + 0.5 * (if monitorId == "Oled34" then 3.3 else 2.32) - 0.25, caseId .. " stands clear of " .. monitorId)
      _ = size
    end
    for _, p in rig:GetDescendants() do if p:IsA("BasePart") then deskParts += 1 end end
  end
  -- On the bench, open, with its panel aside: on the bench top and inside its footprint.
  local benchPc = PcModel.build(workspace, PcModel.restFrame(caseId, benchFrame * CFrame.new(-0.25, 3.385, 0.3)),
    { Case = caseId, GPU = "GpuTsunami", Cooling = "RgbLoop" },
    { Open = true, PanelAside = PcModel.asideFrame(caseId, benchFrame * CFrame.new(1.75, 3.37, -1.12)), Interior = true })
  within(benchPc, benchFrame, -Workbench.WIDTH / 2, Workbench.WIDTH / 2, 3.3, Workbench.HEIGHT, -Workbench.DEPTH / 2, Workbench.DEPTH / 2, caseId .. " on the bench")
  benchPc:Destroy()
end
output(string.format("PC workshop: %d checks passed (carry, bench, screws, swaps, save, store hand-over, desk and bench fit for %d cases)", checks, #TechCatalog.Order.Case))
`;

const temp = await mkdtemp(join(tmpdir(), 'pc-workshop-'));
try {
  const path = join(temp, 'check.luau');
  await writeFile(path, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', path], { cwd: root, encoding: 'utf8', timeout: 120000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('PC workshop check failed');
} finally {
  await rm(temp, { recursive: true, force: true });
}
