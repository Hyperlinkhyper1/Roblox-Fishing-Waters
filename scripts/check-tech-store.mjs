// Micro Harbour checks: the pure TechCatalog rules (decode, purchases, installs, licenses and the
// desk look), the store's block in the city grid, and a compile pass over every module the
// store touches. check-tech-store-interior also exercises geometry, occupancy and purchases;
// Roblox rendering and the office PC still need a Studio play test.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = async path => (await readFile(join(root, path), 'utf8')).replaceAll('\r\n', '\n');
const lute = process.env.LUTE || 'lute';
const temporary = await mkdtemp(join(tmpdir(), 'fishing-tech-'));

function run(path, label) {
  const result = spawnSync(lute, ['run', path], { cwd: root, encoding: 'utf8', timeout: 60000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${label} failed (${result.status})`);
}

try {
  const catalog = await read('src/shared/TechCatalog.luau');
  const city = await read('src/server/Map/ModernCity.luau');
  const grab = (startText, endText) => {
    const start = city.indexOf(startText);
    const end = city.indexOf(endText, start);
    if (start < 0 || end < 0) throw new Error(`ModernCity changed near "${startText}"`);
    return city.slice(start, end + endText.length);
  };
  const site = grab('local TECH_STORE_SITE = {', '\nend\n');

  const program = `
local checks = 0
local function check(value, message) checks += 1; if not value then error(message, 2) end end
local Color3 = {}
Color3.__index = Color3
function Color3.fromRGB(r, g, b) return setmetatable({ R = r / 255, G = g / 255, B = b / 255 }, Color3) end
function Color3.new(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3) end
local Enum = setmetatable({}, { __index = function(_, group)
  return setmetatable({}, { __index = function(_, name) return group .. "." .. name end })
end })
local TechCatalog = (function()
${catalog}
end)()

-- Every slot has exactly one free starter, listed first, and every item is in its slot's order.
local listed = {}
for _, slot in TechCatalog.Slots do
  local order = TechCatalog.Order[slot]
  check(order and #order >= 4, slot .. " needs a range of parts")
  check(TechCatalog.Items[order[1]].Price == 0, slot .. " starts with a free part")
  local last = -1
  for _, id in order do
    local item = TechCatalog.Items[id]
    check(item and item.Slot == slot, id .. " belongs to " .. slot)
    check(item.Price > last, slot .. " is sorted cheapest first")
    check(type(item.Name) == "string" and type(item.Spec) == "string", id .. " has a name and spec")
    last = item.Price
    listed[id] = true
  end
end
for id, item in TechCatalog.Items do
  check(listed[id], id .. " is on sale in its slot")
  if item.Slot == "Monitor" then
    local s = item.Screen
    check(s and s.Screen and s.Panel and s.Dim and s.Mid and s.Bright and s.Hot and s.Title and s.Body and s.Bloom, id .. " has a full screen look")
    check(item.Plate and item.Bezel, id .. " dresses the desk monitor")
  elseif item.Slot == "Case" then
    check(item.Look and item.Look.Body and item.Look.Trim and item.Look.Front, id .. " dresses the desk case")
  elseif item.Slot == "CPU" then
    check(item.Badge and item.Clock, id .. " labels the case")
  elseif item.Slot == "RAM" then
    check(type(item.Kilobytes) == "number", id .. " counts in the boot screen")
  elseif item.Slot == "Storage" then
    check(type(item.Drive) == "string", id .. " names drive C:")
  elseif item.Slot == "Cooling" then
    check(item.Light and item.Form, id .. " lights the case and has a cooler shape")
  elseif item.Slot == "PSU" then
    check(type(item.Capacity) == "number" and item.Body, id .. " powers the build")
  elseif item.Slot == "Motherboard" then
    check(item.Pcb and item.Heatsink and item.Tier, id .. " has a board look")
  elseif item.Slot == "GPU" then
    check(item.Tier and item.Shroud, id .. " has a card look")
  end
  check(item.Slot == "Monitor" or item.Slot == "PSU" or type(item.Watts) == "number", id .. " draws power")
end
check(TechCatalog.Licenses.StockExchange and TechCatalog.Licenses.StockExchange.Price > 0, "The trading license is for sale")

-- Fresh and damaged saves fall back to the starter PC without failing.
for _, raw in { nil, 5, "x", {}, { Owned = 4, Equipped = "x", Licenses = false } } do
  local tech = TechCatalog.decode(raw)
  for _, slot in TechCatalog.Slots do
    check(tech.Equipped[slot] == TechCatalog.Defaults[slot], "A new PC has the starter " .. slot)
  end
  check(next(tech.Owned) == nil and next(tech.Licenses) == nil, "A new PC owns nothing extra")
  check(not TechCatalog.hasLicense({ Tech = raw }, "StockExchange"), "Nobody starts licensed")
end
local odd = TechCatalog.decode({
  Owned = { Gone = true, CpuKraken = "yes", Amber14 = true, Mono14 = true },
  Equipped = { CPU = "CpuKraken", Monitor = "Amber14", GPU = "Amber14", RAM = "Ram640" },
  Licenses = { StockExchange = true, Retired = true },
})
check(odd.Owned.Amber14 and not odd.Owned.Gone and not odd.Owned.CpuKraken and not odd.Owned.Mono14, "Only real paid parts stay owned")
check(odd.Equipped.CPU == "Cpu386", "An unowned part is never installed")
check(odd.Equipped.Monitor == "Amber14", "An owned monitor stays installed")
check(odd.Equipped.GPU == "GpuMono", "A part in the wrong slot is never installed")
check(odd.Licenses.StockExchange and not odd.Licenses.Retired, "Only known licenses survive")

-- Buying puts a part in the parts bin (the workbench fits it), and licenses are bought once.
local tech = TechCatalog.decode(nil)
check(TechCatalog.problem(tech, 0, "Item", "Flat24") ~= nil, "Monitors cost money")
check(TechCatalog.problem(tech, 1e9, "Item", "Mono14") ~= nil, "The starter monitor is already owned")
check(TechCatalog.problem(tech, 1e9, "Item", "Nope") ~= nil, "Unknown parts are refused")
check(TechCatalog.problem(tech, 1e9, "Item", 7) ~= nil, "Bad ids are refused")
check(TechCatalog.problem(tech, 1e9, "License", "Nope") ~= nil, "Unknown licenses are refused")
check(TechCatalog.problem(tech, 10000, "Item", "Flat24") == nil, "Exact cash buys a monitor")
check(TechCatalog.buy(tech, "Item", "Flat24") == 10000, "A purchase costs the list price")
check(tech.Equipped.Monitor == "Mono14" and TechCatalog.owns(tech, "Flat24"), "A bought part goes to the parts bin, not into the PC")
check(TechCatalog.problem(tech, 1e9, "Item", "Flat24"):find("workbench"), "Owned parts point at the workbench")
TechCatalog.fit(tech, { Monitor = "Flat24", CPU = "CpuKraken", GPU = "Amber14" })
check(tech.Equipped.Monitor == "Flat24", "Fitting an owned part installs it")
check(tech.Equipped.CPU == "Cpu386" and tech.Equipped.GPU == "GpuMono", "Fitting never installs unowned or wrong-slot parts")
check(TechCatalog.problem(tech, 1e9, "Item", "Flat24") ~= nil, "Parts are bought once")
check(TechCatalog.problem(tech, 4999, "License", "StockExchange") ~= nil, "The license costs $5000")
check(TechCatalog.buy(tech, "License", "StockExchange") == 5000, "Licenses cost their price")
check(TechCatalog.problem(tech, 1e9, "License", "StockExchange") ~= nil, "Licenses are bought once")
tech.Equipped.Monitor = "Mono14"
local saved = TechCatalog.encode(tech)
check(saved.Equipped.Monitor == nil and saved.Owned.Flat24 and saved.Licenses.StockExchange, "Saves keep purchases, not defaults")
local reloaded = TechCatalog.decode(saved)
check(reloaded.Equipped.Monitor == "Mono14" and TechCatalog.owns(reloaded, "Flat24"), "Swapping back keeps the bought monitor")
check(TechCatalog.hasLicense({ Tech = saved }, "StockExchange"), "A saved license unlocks trading")

-- Desk looks, from mirrored attributes (which may be missing).
local base = TechCatalog.deskLook({})
check(base.Badge == "PC 386" and base.Plate == "MONOCHROME 14" and not base.Flat, "Unowned desks show the starter PC")
local fancy = TechCatalog.deskLook({ CPU = "CpuKraken", Case = "CaseGlass", Monitor = "Oled34", Cooling = "RgbLoop", GPU = "bogus" })
check(fancy.Badge == "KRAKEN" and fancy.Glow and fancy.Flat and fancy.Plate == "ABYSS OLED", "Parts dress the desk")
check(fancy.Key ~= base.Key, "A changed PC gets a new look key")
check(TechCatalog.memoryText(640) == "640K" and TechCatalog.memoryText(65536) == "64 MB" and TechCatalog.memoryText(16777216) == "16 GB", "Memory reads like a BIOS")

-- Complete PCs use valid slots and prices, credit owned parts, and survive normal saves.
check(#TechCatalog.PrebuiltOrder == 6, "There are six themed prebuilt PCs")
for _, id in TechCatalog.PrebuiltOrder do
  local build = TechCatalog.Prebuilts[id]
  check(build and build.Name and build.Spec and build.Accent, "Each build has a showroom identity")
  local fresh = TechCatalog.decode(nil)
  check(TechCatalog.prebuiltPrice(fresh, id) == build.Price and build.Price > 0, "Fresh company sees the full PC price")
  for _, slot in TechCatalog.Slots do
    check(TechCatalog.Items[build.Parts[slot]].Slot == slot, "Complete PC has the correct " .. slot)
  end
  check(TechCatalog.problem(fresh, build.Price - 1, "Prebuilt", id) ~= nil, "Complete PCs require the actual total")
  check(TechCatalog.problem(fresh, build.Price, "Prebuilt", id) == nil, "Exact funds buy the complete PC")
  check(TechCatalog.buy(fresh, "Prebuilt", id) == build.Price, "Complete PC charges once")
  check(not TechCatalog.prebuiltInstalled(fresh, id), "Buying a complete PC hands it over instead of installing it")
  TechCatalog.fit(fresh, build.Parts)
  local draw, capacity = TechCatalog.power(build.Parts)
  check(draw <= capacity, id .. " runs on its own power supply")
  local reload = TechCatalog.decode(TechCatalog.encode(fresh))
  check(TechCatalog.prebuiltInstalled(reload, id), "A saved complete PC stays installed")
  check(TechCatalog.prebuiltPrice(reload, id) == 0, "Owned parts are not charged a second time")
end
local partial = TechCatalog.decode({ Owned = { Cpu486 = true } })
check(TechCatalog.prebuiltPrice(partial, "HarbourHome") == 2400, "Existing processor is fully credited")
local starterDraw, starterCapacity = TechCatalog.power(TechCatalog.Defaults)
check(starterDraw <= starterCapacity, "The starter PC runs on the starter power supply")
check(TechCatalog.score(TechCatalog.Defaults) == 0, "The starter PC scores zero")
local best = {}
for slot, order in TechCatalog.Order do best[slot] = order[#order] end
check(TechCatalog.score(best) == 1000, "The best part in every slot scores 1000")
local clean = TechCatalog.sanitize({ CPU = "CpuKraken", GPU = "nope", Case = "Mono14" })
check(clean.CPU == "CpuKraken" and clean.GPU == "GpuMono" and clean.Case == "CaseBeige" and clean.PSU == "Psu200", "Parts lists are cleaned per slot")
check(TechCatalog.problem(partial, 1e9, "Prebuilt", "bogus") ~= nil, "Unknown builds are rejected")

-- The industrial campus faces Harbour Road, clear of the refinery road and container yard.
local CENTER = { X = 7000, Y = 0, Z = 7000 }
local TOP = 8
local Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }
local CFrame = { new = function(p) return setmetatable({ Position = p }, { __mul = function(a) return a end }) end, Angles = function() return {} end }
setmetatable(CENTER, { __add = function(a, b) return { X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z } end })
local City = {}
${site}
local spot = City.techStoreSite()
check(spot.w >= 460 and spot.d >= 360, "Industrial campus accommodates a genuine megastore")
check(TECH_STORE_SITE.x0 > -1230, "Refinery access road remains open to the west")
check(TECH_STORE_SITE.x1 < -653, "CountryRoad remains open to the east")
check(TECH_STORE_SITE.z0 > -117, "Harbour Road and terminal remain clear to the north")
check(spot.cframe.Position.X - CENTER.X < -700, "Megastore moved out of the cafe quarter into the western industrial district")

print("Micro Harbour: " .. checks .. " checks passed (catalog rules and industrial campus)")
`;
  const rules = join(temporary, 'tech.luau');
  await writeFile(rules, program);
  run(rules, 'Micro Harbour checks');

  const modules = [
    'src/shared/TechStoreFixtures.luau', 'src/shared/TechStorePrompts.luau',
    'src/shared/TechStoreLayout.luau', 'src/shared/TechStoreInterior.luau', 'src/client/TechStoreInterior.luau',
    'src/shared/TechCatalog.luau', 'src/server/TechStoreService.luau', 'src/server/Map/TechStore.luau',
    'src/server/Map/OfficeDesk.luau', 'src/server/Map/ModernCity.luau', 'src/server/StockMarketService.luau',
    'src/server/init.server.luau', 'src/client/TechStore.luau', 'src/client/OfficeComputer.luau',
    'src/client/RetroUI.luau', 'src/client/StockApp.luau', 'src/client/init.client.luau',
    'src/shared/PcModel.luau', 'src/server/PcWorkshopService.luau', 'src/client/PcWorkshop.luau',
    'src/server/OfficeComputerService.luau', 'src/server/Map/Workbench.luau',
  ];
  for (const [index, module] of modules.entries()) {
    const path = join(temporary, `compile-${index}.luau`);
    await writeFile(path, 'do return end\n' + await read(module));
    run(path, `Compiling ${module}`);
  }
  console.log(`Micro Harbour modules: ${modules.length} files compile`);
} finally {
  await rm(temporary, { recursive: true, force: true });
}
