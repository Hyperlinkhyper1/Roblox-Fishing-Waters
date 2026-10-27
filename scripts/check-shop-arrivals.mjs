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
local register = { Position = 'register' }
local shop = { base = {}, frame = {}, registers = { register }, customers = {}, displayFish = {
  { record = 'fish1', freezer = {} }, { record = 'fish2', freezer = {} }, { record = 'fish3', freezer = {} },
} }
arrive(shop)
assert(#shop.customers == 1 and shop.nextArrival == 125, 'Base arrival remains 25 seconds')
arrive(shop)
assert(#shop.customers == 1, 'Base register allows only one customer')
profile.Angler.Upgrades.SocialMediaAdvertisement = 1
arrive(shop)
assert(#shop.customers == 2 and shop.nextArrival == 118, 'Advertisement adds a queued arrival and 18-second interval')
local first, second = shop.customers[1], shop.customers[2]
assert(first.record ~= second.record, 'Queued customers reserve distinct stock')
assert(waitingForRegister(shop, second) and not waitingForRegister(shop, first), 'Second customer waits for the first')
arrive(shop)
assert(#shop.customers == 2, 'Queue does not grow beyond two per register')
first.leaving = true
assert(not waitingForRegister(shop, second), 'Queue advances when the first customer leaves')
now = 118
arrive(shop)
assert(#shop.customers == 3 and shop.nextArrival == 135, 'Following interval is 17 seconds')
second.active = false
assert(not waitingForRegister(shop, shop.customers[3]), 'Queue advances when the prior customer is inactive')
print('Shop arrivals: base timing, 35-second cadence, stock reservations and register queue passed.')
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
