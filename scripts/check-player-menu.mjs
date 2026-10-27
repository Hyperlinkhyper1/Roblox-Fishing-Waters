import { freezerRuntime, injectFreezer } from './freezer-test-runtime.mjs';
// Execute actual menu/service code with recording UI/remotes. No Studio rendering claims.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const folder = await mkdtemp(join(tmpdir(), 'fishing-menu-'));
try {
  const shopUpgrades = await readFile(join(root, 'src/shared/ShopUpgrades.luau'), 'utf8');
  const rodSkins = await readFile(join(root, 'src/shared/RodSkins.luau'), 'utf8');
  const bobberSkins = await readFile(join(root, 'src/shared/BobberSkins.luau'), 'utf8');
  const bobberModel = (await readFile(join(root, 'src/shared/FishingBobber.luau'), 'utf8'))
    .replace('require(script.Parent.BobberSkins)', () => `(function() ${bobberSkins} end)()`);
  let program = await readFile(join(root, 'scripts/player-menu.luau'), 'utf8');
  if (process.argv.includes('--paths-only')) {
    program = program.slice(0, program.indexOf('Menu.start()'))
      + await readFile(join(root, 'scripts/path-skip.luau'), 'utf8');
    program = program.replace('-- PATH_RULES --', await readFile(join(root, 'src/shared/Paths.luau'), 'utf8'));
  }
  if (process.argv.includes('--service-only')) {
    program = program.slice(0, program.indexOf('local thunder ='))
      + '\nprint("Angler service: " .. checks .. " rank, respawn, title and remote checks passed (recording mocks).")';
  }
  if (process.argv.includes('--bag-only')) {
    const setupEnd = program.indexOf('player:SetAttribute("DrydockScreenOpen", true)');
    const bagStart = program.indexOf('-- BAG_CHECKS_START');
    const bagEnd = program.indexOf('open("Journal")', bagStart);
    if (setupEnd < 0 || bagStart < 0 || bagEnd < 0) throw new Error('Missing bag test hooks');
    program = program.slice(0, setupEnd) + program.slice(bagStart, bagEnd)
      + '\nprint("Equipment bag: " .. checks .. " desktop/mobile inventory and serial checks passed (recording mocks).")';
  }
  if (process.argv.includes('--shop-only')) {
    program = program.slice(0, program.indexOf('Menu.start()')) + `
Menu.start()
advance(1)
local gui = playerGui.PlayerMenu
local sidebar, card = gui.LeftNavigation, gui.MenuOverlay.MenuWindow
local content = card.Content
local function click(value)
 for _, item in content:GetDescendants() do
  if item:IsA("TextButton") and item.Text == value then item.Activated:Fire() return end
 end
 error("Missing shop button: " .. value)
end
for _, width in {1020, 362} do
 player:SetAttribute("OwnsAutoStore", false)
 card.AbsoluteSize = Vector2.new(width, 600)
 now += 1
 sidebar.Shop.Activated:Fire()
 check(gui.MenuOverlay.Visible, "Shop opens")
 local before = #passPrompts
 click("Buy Auto Store · Robux")
 check(#passPrompts == before + 1 and passPrompts[#passPrompts][2] == 3722004182, "Configured purchase prompt")
 player:SetAttribute("OwnsAutoStore", true)
 click("Owned")
 check(#passPrompts == before + 1, "Owned pass does not prompt again")
 card.CloseMenu.Activated:Fire()
end
print("Auto Store shop: " .. checks .. " desktop/mobile UI checks passed (recording mocks).")
`;
  }
  if (process.argv.includes('--home-only')) {
    program = program.slice(0, program.indexOf('Menu.start()'))
      + await readFile(join(root, 'scripts/home-menu.luau'), 'utf8');
  }
  if (process.argv.includes('--equipment-only')) {
    program = program.slice(0, program.indexOf('Menu.start()'))
      + await readFile(join(root, 'scripts/equipment-bag.luau'), 'utf8');
  }
  if (process.argv.includes('--bobbers-only')) {
    program = program.slice(0, program.indexOf('Menu.start()'))
      + await readFile(join(root, 'scripts/bobber-bag.luau'), 'utf8');
  }
  if (process.argv.includes('--settings-only')) {
    program = program.slice(0, program.indexOf('Menu.start()')) + `
Menu.start()
advance(1)
local gui = playerGui.PlayerMenu
local sidebar, card = gui.LeftNavigation, gui.MenuOverlay.MenuWindow
local content = card.Content
local function click(name)
  local item = assert(content:FindFirstChild(name, true), "Missing settings control: " .. name)
  now += 1
  item.Activated:Fire()
end
for _, width in {1020, 362} do
  card.AbsoluteSize = Vector2.new(width, 600)
  sidebar.Settings.Activated:Fire()
  check(gui.MenuOverlay.Visible and #content:GetChildren() > 0, "Settings opens with content")
  check(sidebar.Equipmentbag.ThemeFace.NavIcon:FindFirstChild("Bag") ~= nil, "Equipment bag icon matches its generated name")
  click("PerformanceTab")
  click("Shadows")
  check(not profile.Angler.Settings.Shadows, "Shadows toggle saves")
  check(not Lighting.GlobalShadows, "Manual shadows toggle applies to lighting")
  advance(1)
  check(not Lighting.GlobalShadows and content:FindFirstChild("Shadows", true).Text == "Off", "Profile refresh preserves manual shadows and the displayed value")
  failSave = true
  click("Shadows")
  check(not Lighting.GlobalShadows, "Failed setting save does not change session performance")
  failSave = false
  click("Shadows")
  click("WeatherEffects")
  check(player:GetAttribute("WeatherEffectsEnabled") == false, "Manual weather toggle applies")
  advance(1)
  check(player:GetAttribute("WeatherEffectsEnabled") == false, "Profile refresh preserves manual weather")
  click("WeatherEffects")
  click("AudioTab")
  local before = profile.Angler.Settings.MasterVolume
  click("MasterVolumeDown")
  check(profile.Angler.Settings.MasterVolume == before - 10, "Audio volume saves")
  click("CodesTab")
  check(content:FindFirstChild("CodeInput", true) ~= nil, "Codes input renders")
  click("TitlesTab")
  check(#content:GetChildren() > 0, "Titles renders")
  card.CloseMenu.Activated:Fire()
  check(not gui.MenuOverlay.Visible and sidebar.Visible, "Close restores navigation")
end
print("Settings: " .. checks .. " data, mixer and desktop/mobile menu checks passed (recording mocks).")
`;
  }
  for (const [marker, file] of [
    ['DATA', 'src/server/AnglerData.luau'], ['CATALOG', 'src/shared/AnglerCatalog.luau'],
    ['STAFF', 'src/shared/StaffCatalog.luau'], ['BOAT', 'src/shared/BoatCatalog.luau'],
    ['THEME', 'src/first/UITheme.luau'], ['PREVIEW', 'src/client/StaffPreview.luau'], ['BAG', 'src/client/EquipmentBag.luau'], ['MENU', 'src/client/PlayerMenu.luau'], ['SETTINGS', 'src/client/PlayerSettings.luau'], ['SERVICE', 'src/server/AnglerService.luau'],
  ]) {
    let source = await readFile(join(root, file), 'utf8');
    if (marker === 'DATA') source = injectFreezer(source);
    source = source.replace(/require\(ReplicatedStorage.Shared.AnglerCatalog\)/g, 'Catalog')
      .replace(/require\(ReplicatedStorage.Shared.BackpackCatalog\)/g, `(function() ${await readFile(join(root, 'src/shared/BackpackCatalog.luau'), 'utf8')} end)()`)
      .replace(/require\(ReplicatedStorage.Shared.Gamepasses\)/g, `(function() ${await readFile(join(root, 'src/shared/Gamepasses.luau'), 'utf8')} end)()`)
      .replace(/require\(script.Parent.GamepassService\)/g, '{ start = function() end, ownsAutoStore = function() return false end }')
      .replace(/require\(ReplicatedStorage.Shared.Aboard\)/g, 'function() return false end')
      .replace(/require\(ReplicatedStorage.Shared.StaffCatalog\)/g, 'StaffCatalog')
      .replace(/require\(ReplicatedStorage.Shared.ShopUpgrades\)/g, () => `(function() ${shopUpgrades} end)()`)
      .replace(/require\(game:GetService\("ReplicatedStorage"\).Shared.StaffCatalog\)/g, 'StaffCatalog')
      .replace(/require\(script.Parent.StaffPreview\)/g, 'StaffPreview')
      .replace(/require\(script.Parent:WaitForChild\("EquipmentBag"\)\)/g, 'EquipmentBag')
      .replace(/require\(ReplicatedStorage.Shared.FishingRod\)/g, 'FishingRod')
      .replace(/require\(ReplicatedStorage.Shared.RodSkins\)/g, () => `(function() ${rodSkins} end)()`)
      .replace(/require\(ReplicatedStorage.Shared.BobberSkins\)/g, () => `(function() ${bobberSkins} end)()`)
      .replace(/require\(ReplicatedStorage.Shared.FishingBobber\)/g, () => `(function() ${bobberModel} end)()`)
      .replace(/require\(ReplicatedStorage.Shared.BoatCatalog\)/g, 'BoatCatalog')
      .replace(/require\(ReplicatedStorage.Shared.FishModels\)/g, 'nil')
      .replace(/require\(script.Parent.PlayerSettings\)/g, 'Settings')
      .replace(/require\(game:GetService\("ReplicatedFirst"\):WaitForChild\("UITheme"\)\)/g, 'Theme')
      .replace(/require\(script.Parent.BoatService\)/g, 'BoatService')
      .replace(/require\(script.Parent.AnglerData\)/g, 'Data');
    for (const pure of ['Paths', 'Recipes', 'FishingRanks']) {
      const inlined = `(function() ${await readFile(join(root, `src/shared/${pure}.luau`), 'utf8')} end)()`;
      source = source.replace(new RegExp(`require\\(ReplicatedStorage.Shared.${pure}\\)`, 'g'), () => inlined);
    }
    program = program.replace(`-- ${marker}_SOURCE --`, source);
  }
  let shops = '';
  for (const name of ['Boating', 'Fishing']) {
    let source = await readFile(join(root, 'src/client/' + name + '.luau'), 'utf8');
    source = source.replace('require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))', 'Theme')
      .replace('require(ReplicatedStorage.Shared.BoatCatalog)', 'BoatCatalog')
      .replace('require(ReplicatedStorage.Shared.Weather)', '{ getState = function() return { kind = "Clear" } end }')
      .replace('require(script.Parent.DrydockCamera)', 'BoatCamera');
    if (name === 'Boating') {
      source = source.replace(/return Boating\s*$/, 'Boating.start()');
    } else {
      const stop = source.indexOf('\n\tlocal noticeId = 0');
      if (stop < 0) throw new Error('Missing shop construction hook: ' + name);
      source = source.slice(0, stop) + '\nend\n' + name + '.start()';
    }
    shops += '\ndo\n' + source + '\nend\n';
  }
  const boatCatalog = await readFile(join(root, 'src/shared/BoatCatalog.luau'), 'utf8');
  program = program.replace('-- SHOP_UI_CHECKS --', 'local BoatCatalog = (function()\n' + boatCatalog + '\nend)()\n'
    + `local Font = { new = function(family, weight, style) return {Family=family, Weight=weight, Style=style} end }
local nativeTypeof = typeof
local function typeof(value)
  return if type(value) == "table" and value.ClassName then "Instance" else nativeTypeof(value)
end
local boatActions, cameraViews, cameraStops = {}, {}, 0
local BoatCamera = {
  show = function(shop, launching, boatId) table.insert(cameraViews, {shop, launching, boatId}) end,
  stop = function() cameraStops += 1 end,
}
local heartbeat = signal()
local workspace = {}
services.CollectionService = {
  GetTagged = function() return {} end,
  GetInstanceAddedSignal = function() return signal() end,
  GetInstanceRemovedSignal = function() return signal() end,
}
services.RunService = { Heartbeat = heartbeat }
for _, name in {"Boating", "Fishing"} do
  local folder = ReplicatedStorage:FindFirstChild(name) or Instance.new("Folder")
  folder.Name, folder.Parent = name, ReplicatedStorage
  for _, key in {"Request", "Feedback"} do
    if not folder:FindFirstChild(key) then
      local event = Instance.new("RemoteEvent")
      event.Name, event.Parent = key, folder
    end
  end
end
ReplicatedStorage.Boating.Feedback.OnClientEvent = signal()
function ReplicatedStorage.Boating.Request:FireServer(...) table.insert(boatActions, {...}) end
`
    + shops + '\nfor _, name in {"Boating", "Fishing"} do\nlocal screen = playerGui:WaitForChild(name)\nlocal overlay = screen:WaitForChild("ShopOverlay")\nlocal window = overlay:FindFirstChildOfClass("Frame")\ncheck(window:FindFirstChild("ThemeInnerRim") ~= nil, "Shop must use the shared framed window")\ncheck(window.CloseShop.ThemeFace:GetAttribute("Finish") == "Danger", "Shop close button must be red")\nfor _, item in screen:GetDescendants() do if item:IsA("TextLabel") and not (screen:FindFirstChild("Wallet") and item:IsDescendantOf(screen.Wallet)) then check(item.Font == Enum.Font.GothamBold and item.TextStrokeTransparency == 0, "Every themed shop caption uses the shared outlined typography") end end\nend\nprint("Shop UI: both production shops, dialogue, equipment control and notices use the shared theme (recording mocks).")'
    + `
local boatScreen = playerGui.Boating
local boatOverlay = boatScreen.ShopOverlay
local boatWindow = boatOverlay.DrydockShop
local offer, chooser = boatWindow.BoatOffer, boatWindow.DockBoatChooser
local feedback = ReplicatedStorage.Boating.Feedback.OnClientEvent
local shop = Instance.new("Model")
local function hasText(parent, expected)
  for _, child in parent:GetDescendants() do
    if child:IsA("TextLabel") and string.find(child.Text, expected, 1, true) then return true end
  end
  return false
end
player:SetAttribute("Cash", 1000)
feedback:Fire("OpenShop", shop)
check(offer.Visible and offer.BuyBoat.Active and hasText(offer, "Wooden rowboat"), "Default boat shop retains the wooden rowboat")
offer.SelectFishingBoat.Activated:Fire()
check(boatActions[#boatActions][1] == "BrowseBoat" and boatActions[#boatActions][2] == "FishingBoat", "Fishing boat selector requests its own server preview")
feedback:Fire("OpenShop", shop, "FishingBoat")
check(hasText(offer, "Small fishing boat") and hasText(offer, "24 studs/s") and hasText(offer, "$2500"), "Switching preview updates fishing boat name, speed and price")
check(not offer.BuyBoat.Active and hasText(offer, "1500 more"), "Fishing boat purchase requires its higher price")
check(cameraViews[#cameraViews][3] == "FishingBoat", "Fishing boat preview targets its own display berth")
player:SetAttribute("Cash", 3000)
check(offer.BuyBoat.Active, "Buying becomes available when enough cash arrives")
offer.BuyBoat.Activated:Fire()
check(boatActions[#boatActions][1] == "PurchaseBoat" and boatActions[#boatActions][2] == "FishingBoat", "Purchase submits the selected fishing boat ID")
player:SetAttribute("OwnsFishingBoat", true)
check(not offer.BuyBoat.Active and offer.BuyBoat.Text == "Boat owned", "Owned fishing boats cannot be bought twice")
feedback:Fire("OpenShop", shop, "Rowboat")
check(offer.BuyBoat.Active and hasText(offer, "14 studs/s"), "Owning fishing boat does not hide or lock unowned rowboat")
player:SetAttribute("OwnsRowboat", true)
local ownBase = Instance.new("Model")
ownBase:SetAttribute("OwnerUserId", player.UserId)
local otherBase = Instance.new("Model")
otherBase:SetAttribute("OwnerUserId", player.UserId + 1)
boatWindow.CloseShop.Activated:Fire()
feedback:Fire("OpenDock", otherBase)
check(not boatOverlay.Visible, "Another player's dock cannot open the boat chooser")
feedback:Fire("OpenDock", ownBase)
check(boatOverlay.Visible and chooser.Visible and chooser.LaunchRowboat.Visible and chooser.LaunchFishingBoat.Visible, "Owner dock offers both individually owned boats")
workspace.CurrentCamera = { ViewportSize = Vector2.new(390, 844) }
heartbeat:Fire(0.01)
check(boatWindow:FindFirstChildOfClass("UIScale").Scale > 0.9 and boatWindow.AnchorPoint.Y == 0.5, "Phone dock chooser stays readable and centered without a preview camera")
workspace.CurrentCamera = nil
chooser.LaunchFishingBoat.Activated:Fire()
chooser.LaunchSelectedBoat.Activated:Fire()
check(boatActions[#boatActions][1] == "SpawnBoat" and boatActions[#boatActions][2] == "FishingBoat" and not boatOverlay.Visible, "Dock chooser launches fishing boat and dismisses")
feedback:Fire("OpenDock", ownBase)
chooser.LaunchRowboat.Activated:Fire()
chooser.LaunchSelectedBoat.Activated:Fire()
check(boatActions[#boatActions][2] == "Rowboat", "Previously purchased rowboat remains available to relaunch")
player:SetAttribute("OwnsRowboat", false)
feedback:Fire("OpenDock", ownBase)
check(not chooser.LaunchRowboat.Visible and chooser.LaunchFishingBoat.Visible, "Chooser lists only boats the player owns")
player:SetAttribute("BoatDataStatus", "Unavailable")
check(not chooser.LaunchSelectedBoat.Active, "Unavailable boat data disables dock launch")
player:SetAttribute("BoatDataStatus", "Ready")
boatWindow.CloseShop.Activated:Fire()
for _, boatId in {"Rowboat", "FishingBoat"} do
  local boat = Instance.new("Model")
  boat:SetAttribute("BoatId", boatId)
  boat:SetAttribute("OwnerUserId", player.UserId)
  local helm = Instance.new("VehicleSeat")
  helm.Name, helm.Parent = BoatCatalog[boatId].DriverSeat, boat
  helm.ThrottleFloat, helm.SteerFloat = 0.5, -0.3
  humanoid.SeatPart = helm
  heartbeat:Fire(0.1)
  check(boatActions[#boatActions][1] == "Row" and boatActions[#boatActions][2] == 0.5, "Both boat driver seats send movement controls")
end
local before = #boatActions
humanoid.SeatPart.Parent:SetAttribute("OwnerUserId", player.UserId + 1)
heartbeat:Fire(0.1)
check(#boatActions == before, "Other players' boat seats cannot send owner driving input")
humanoid.SeatPart = nil
feedback:Fire("LaunchStarted", shop, "FishingBoat")
check(cameraViews[#cameraViews][2] and cameraViews[#cameraViews][3] == "FishingBoat", "Purchased fishing boat receives its launch camera framing")
check(hasText(boatScreen, "small fishing boat into the water"), "Launch notice identifies the selected boat")
feedback:Fire("LaunchFinished")
check(not player:GetAttribute("DrydockScreenOpen") and cameraStops > 0, "Finishing the launch restores camera and fishing screen state")
print("Boat selection UI: preview, funds, purchases, separate ownership, dock chooser and both driver seats passed (recording mocks).")
`);
  const target = join(folder, 'menu.luau');
  await writeFile(target, await freezerRuntime() + program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Menu checks failed (${result.status})`);
} finally {
  if (dirname(folder) !== resolve(tmpdir())) throw new Error('Unexpected temporary directory');
  await rm(folder, { recursive: true, force: true });
}
