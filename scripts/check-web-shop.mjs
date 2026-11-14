// HARBOUR DIRECT checks: the pure Shared.WebShop rules (orders, rack space, instant delivery,
// van delivery, refunds and the saved shape), that its prices match Tide & Tackle and its
// license is on sale, and a compile pass over every module the web shop touches. The van, the
// parcels and the PC app still need a Studio play test.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = async path => (await readFile(join(root, path), 'utf8')).replaceAll('\r\n', '\n');
const lute = process.env.LUTE || 'lute';
const temporary = await mkdtemp(join(tmpdir(), 'fishing-webshop-'));

function run(path, label) {
  const result = spawnSync(lute, ['run', path], { cwd: root, encoding: 'utf8', timeout: 60000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${label} failed (${result.status})`);
}

const module = source => `(function()\n${source}\nend)()`;

try {
  const program = `
local checks = 0
local function check(value, message) checks += 1; if not value then error(message, 2) end end
local Color3 = { fromRGB = function(r, g, b) return { r, g, b } end, new = function() return {} end }
local Enum = setmetatable({}, { __index = function(_, group)
  return setmetatable({}, { __index = function(_, name) return group .. "." .. name end })
end })
local WebShop = ${module(await read('src/shared/WebShop.luau'))}
local CrabCages = ${module(await read('src/shared/CrabCages.luau'))}
local MusselNets = ${module(await read('src/shared/MusselNets.luau'))}
local TechCatalog = ${module(await read('src/shared/TechCatalog.luau'))}

-- Catalog: Tide & Tackle prices and limits, and a license on sale for the app.
check(WebShop.Items.CrabCage.Price == CrabCages.PRICE, "Crab cages cost what Tide & Tackle charges")
check(WebShop.Items.MusselNet.Price == MusselNets.PRICE, "Mussel nets cost what Tide & Tackle charges")
check(WebShop.MAX_CARRIED == CrabCages.MAX_STOCK and WebShop.MAX_CARRIED == MusselNets.MAX_STOCK, "Carried stock limit matches")
check(#WebShop.Order == 2, "Both tools are listed")
for _, id in WebShop.Order do check(WebShop.Items[id], id .. " is in the catalog") end
local license = TechCatalog.Licenses[WebShop.LICENSE]
check(license and license.App == "WebShop" and license.Price > 0, "The web shop license exists")
check(table.find(TechCatalog.LicenseOrder, WebShop.LICENSE), "The web shop license is on the counter")
check(WebShop.DELIVERY_SECONDS == 300, "Vans take five minutes")
check(WebShop.price("CrabCage", 3) == 105 and WebShop.price("CrabCage", 3, true) == 158, "Instant costs 50% extra, rounded up")
check(WebShop.price("MusselNet", 2, true) == 375, "Instant mussel nets")

local function rack(mode, cages, nets)
  return { ItemId = "StorageRack", X = 0, Z = 0, R = 0, Mode = mode, Cages = cages, Nets = nets }
end
local function company(cash, furniture)
  return {
    Cash = cash,
    Angler = {
      Furniture = furniture,
      CrabCages = { Stock = 0, Placed = {} },
      MusselNets = { Stock = 0, Placed = {} },
      Stats = { CoinsSpent = 0 },
    },
  }
end

-- Rack space only counts tools racks.
local p = company(10000, { rack(nil), rack("Tools", 2, 1), { ItemId = "Freezer" }, rack("Tools") })
local free, total = WebShop.rackSpace(p.Angler)
check(free == 21 and total == 24, "Two tools racks: 21 of 24 slots free")
check(WebShop.orderProblem(company(1000, { rack(nil) }), "CrabCage", 1, false):find("Tools mode"), "No tools rack, no order")
check(WebShop.orderProblem(p, "Bait", 1, false), "Unknown items are refused")
check(WebShop.orderProblem(p, "CrabCage", 0, false) and WebShop.orderProblem(p, "CrabCage", 1.5, false), "Counts are whole and positive")
check(WebShop.orderProblem(p, "CrabCage", 22, false), "Orders must fit the racks")
check(WebShop.orderProblem(company(30, { rack("Tools") }), "CrabCage", 1, false):find("costs"), "Orders must be affordable")
check(WebShop.orderProblem(company(35, { rack("Tools") }), "CrabCage", 1, true), "Instant needs the markup too")

-- A normal order: paid now, saved with its due time, reserving rack space.
local order, instant = WebShop.order(p, "CrabCage", 6, false, 1000)
check(order and not instant and order.DueAt == 1300 and order.Paid == 210, "Order queued five minutes out")
check(p.Cash == 9790 and p.Angler.Stats.CoinsSpent == 210, "Order is paid up front")
check(p.Angler.Furniture[2].Cages == 2, "Racks wait for the van")
check(WebShop.available(p) == 15, "Pending orders hold their rack space")
local shop = WebShop.decode(p.WebShop)
check(#shop.Orders == 1 and shop.NextId == 2, "The order is saved")

-- Instant: straight onto the racks, filling them in placement order.
local _, done = WebShop.order(p, "MusselNet", 10, true, 1010)
check(done and done.Instant and done.Racked == 10 and done.Refund == 0, "Instant lands on the racks")
check(p.Angler.Furniture[2].Nets == 10 and p.Angler.Furniture[4].Nets == 1, "Racks fill in order")
check(p.Cash == 9790 - 1875, "Instant charged with markup")
check(WebShop.available(p) == 5, "Instant uses up free space")
check(#WebShop.decode(p.WebShop).Orders == 1, "Instant orders are never queued")

-- The van arrives: order removed, cages racked, and it can't be delivered twice.
local delivery = WebShop.deliver(p, order.Id)
check(delivery.Racked == 6 and delivery.Carried == 0 and delivery.Refund == 0, "Van unloads onto the racks")
check(p.Angler.Furniture[4].Cages == 6, "Cages fill the rack with room")
check(p.WebShop == nil, "Nothing pending, nothing saved")
check(not pcall(WebShop.deliver, p, order.Id), "A delivery only lands once")
check(WebShop.describe(delivery):find("6 crab cages are on your tools racks"), "Arrival notice reads well")

-- Racks moved before the van came: carried stock, then a refund for the rest.
local q = company(10000, { rack("Tools") })
local big = WebShop.order(q, "CrabCage", 12, false, 0)
q.Angler.Furniture[1].Nets = 10 -- someone filled the rack meanwhile
q.Angler.CrabCages.Stock = 24
local spill = WebShop.deliver(q, big.Id)
check(spill.Racked == 2 and spill.Carried == 1 and spill.Refund == 315, "Overflow is carried, then refunded")
check(q.Cash == 10000 - 420 + 315 and q.Angler.Stats.CoinsSpent == 105, "Refund returns the cash")
check(WebShop.describe(spill):find("refunded"), "Refund is mentioned")

-- Order limits.
local r = company(100000, { rack("Tools"), rack("Tools"), rack("Tools"), rack("Tools"), rack("Tools") })
for index = 1, WebShop.MAX_ORDERS do WebShop.order(r, "CrabCage", 1, false, index) end
check(WebShop.orderProblem(r, "CrabCage", 1, false):find("on the way"), "Only a few vans at once")
check(WebShop.orderProblem(r, "CrabCage", 1, true) == nil, "Instant is still allowed")
check(WebShop.orderProblem(r, "CrabCage", WebShop.MAX_PER_ORDER + 1, true), "Per-order cap")

-- Decoding is forgiving and sorted by due time.
local decoded = WebShop.decode({ NextId = 3, Orders = {
  { Id = 7, Item = "MusselNet", Count = 2, Paid = 250, DueAt = 900 },
  { Id = 4, Item = "CrabCage", Count = 1, Paid = 35, DueAt = 500 },
  { Id = 5, Item = "Gold", Count = 1, Paid = 1, DueAt = 1 },
  { Id = 6, Item = "CrabCage", Count = -1, Paid = 1, DueAt = 1 },
  "junk",
} })
check(#decoded.Orders == 2 and decoded.Orders[1].Id == 4 and decoded.NextId == 8, "Bad orders dropped, ids stay unique")
check(#WebShop.decode(nil).Orders == 0 and #WebShop.decode("x").Orders == 0, "Missing shop is empty")

print("Harbour Direct: " .. checks .. " checks passed (orders, racks, vans and refunds)")
`;
  const rules = join(temporary, 'webshop.luau');
  await writeFile(rules, program);
  run(rules, 'Harbour Direct checks');

  const modules = [
    'src/shared/WebShop.luau', 'src/shared/TechCatalog.luau', 'src/server/WebShopService.luau',
    'src/server/Map/DeliveryVan.luau', 'src/server/init.server.luau', 'src/client/WebShopApp.luau',
    'src/client/OfficeComputer.luau', 'src/client/init.client.luau',
  ];
  for (const [index, path] of modules.entries()) {
    const file = join(temporary, `compile-${index}.luau`);
    await writeFile(file, 'do return end\n' + await read(path));
    run(file, `Compiling ${path}`);
  }
  console.log(`Harbour Direct modules: ${modules.length} files compile`);
} finally {
  await rm(temporary, { recursive: true, force: true });
}
