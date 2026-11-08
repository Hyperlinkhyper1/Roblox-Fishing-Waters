// Run the production arrival and register queue logic against a small deterministic shop.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const source = await readFile(join(root, 'src/server/CustomerService.luau'), 'utf8');
function section(start, end) {
  const a = source.indexOf(start), b = source.indexOf(end, a);
  if (a < 0 || b < 0) throw new Error('Missing customer section: ' + start);
  return source.slice(a, b);
}
const catalog = await readFile(join(root, 'src/shared/ShopUpgrades.luau'), 'utf8');
const restaurantSource = await readFile(join(root, 'src/server/RestaurantService.luau'), 'utf8');
const restaurantArrival = restaurantSource.slice(restaurantSource.indexOf('local function arrive('), restaurantSource.indexOf('local function register('));
const program = `
local ShopUpgrades = (function()
${catalog}
end)()
local now = 100
local os = { clock = function() return now end }
local ARRIVAL_SECONDS = 25
local task = { spawn = function(_) end }
local random = { NextInteger = function(_, a, _) return a end }
local profile = { Angler = { Upgrades = {}, Freezer = { 1, 2, 3 }, Pantry = {} } }
local BoatService = { getProfile = function(_) return profile end }
local ownerOf = function(_) return true end
local ShopDesk = { frame = function(_) return nil end }
local function fixtureFrames(shop) return shop.registers end
local function recordKey(record) return record end
local function dishKey(record) return record end
local function visit() end
local function finish() end
${section('local function waitingForRegister(', 'local function visit(')}
${section('local function arrive(', 'local function registerShop(')}
local guest = { valid = function() return true end }
local register = { Position = 'register' }
local shop = { nextArrival = 0, base = {}, frame = {}, registers = { register }, customers = {}, displayFish = {
  { record = 'fish1', freezer = {} }, { record = 'fish2', freezer = {} }, { record = 'fish3', freezer = {} },
} }
assert(not arrive(shop) and #shop.customers == 0, 'A timer cannot create a customer without a pedestrian')
assert(not arrive(shop, { valid = function() return false end }), 'Departed pedestrians cannot enter')
assert(arrive(shop, guest), 'An existing passer-by may enter')
assert(shop.customers[1].guest == guest, 'The visitor keeps the original pedestrian identity')
assert(#shop.customers == 1 and shop.nextArrival == 125, 'Base cooldown remains 25 seconds')
arrive(shop, guest)
assert(#shop.customers == 1, 'A passer-by cannot bypass the arrival cooldown')
now = 125
arrive(shop, guest)
assert(#shop.customers == 1, 'Base register allows only one customer')
profile.Angler.Upgrades.SocialMediaAdvertisement = 1
arrive(shop, guest)
assert(#shop.customers == 2 and shop.nextArrival == 143, 'Advertisement adds a queued arrival and 18-second cooldown')
local first, second = shop.customers[1], shop.customers[2]
assert(first.items[1].record ~= second.items[1].record, 'Queued customers reserve distinct stock')
assert(waitingForRegister(shop, second) and not waitingForRegister(shop, first), 'Second customer waits for the first')
now = 143
arrive(shop, guest)
assert(#shop.customers == 2, 'Queue does not grow beyond two per register')
first.leaving = true
assert(not waitingForRegister(shop, second), 'Queue advances when the first customer leaves')
arrive(shop, guest)
assert(#shop.customers == 3 and shop.nextArrival == 160, 'Following cooldown is 17 seconds')
second.active = false
assert(not waitingForRegister(shop, shop.customers[3]), 'Queue advances when the prior customer is inactive')
profile.Angler.Upgrades.Baskets = 1
local basketShop = { nextArrival = 0, base = {}, frame = {}, registers = { register }, customers = {}, displayFish = shop.displayFish }
arrive(basketShop, guest)
assert(#basketShop.customers[1].items == 3, 'Baskets reserve up to three displayed items')
now = basketShop.nextArrival
arrive(basketShop, guest)
assert(#basketShop.customers == 1, 'Reserved basket stock cannot be selected twice')
local lockedShop = { nextArrival = 0, base = {}, frame = {}, registers = { register }, customers = {}, displayFish = {
  { record = { Locked = true }, freezer = {} },
} }
assert(not arrive(lockedShop, guest) and #lockedShop.customers == 0, 'Locked stock never attracts a purchase')
print('Shop arrivals: required pedestrian, cooldown, advertisement, stock reservations, locked fish and register queue passed.')
do
  local isOpen = true
  local function profileOf() return true, {} end
  local function open() return isOpen end
  local seats = { { seat = 'one', table = {} }, { seat = 'two', table = {} } }
  local function freeSeats(restaurant)
    local free = {}
    for _, choice in seats do if not restaurant.seated[choice.seat] then table.insert(free, choice) end end
    return free
  end
  local function chooseOrder() return 'GrilledFish' end
  ${restaurantArrival}
  local restaurant = { base = {}, nextArrival = 0, diners = {}, seated = {} }
  assert(not arrive(restaurant), 'Restaurant timers also cannot invent diners')
  assert(arrive(restaurant, guest) and restaurant.diners[1].guest == guest, 'An existing passer-by can dine')
  assert(not arrive(restaurant, guest), 'Restaurant retains its arrival cooldown')
  now = restaurant.nextArrival
  assert(arrive(restaurant, guest), 'A second passer-by can book the next free seat')
  now = restaurant.nextArrival
  assert(not arrive(restaurant, guest), 'Occupied seats cannot be double-booked')
  isOpen = false
  assert(not arrive(restaurant, guest), 'Closed restaurants reject passers-by')
  print('Restaurant arrivals: required pedestrian, cooldown, seat reservations and closed business passed.')
end
`;
const folder = await mkdtemp(join(tmpdir(), 'shop-arrivals-'));
try {
  const target = join(folder, 'arrivals.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Arrival checks failed (' + result.status + ')');
} finally {
  if (dirname(folder) !== resolve(tmpdir())) throw new Error('Unexpected temporary directory');
  await rm(folder, { recursive: true, force: true });
}
