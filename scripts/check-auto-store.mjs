import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const read = path => readFile(new URL('../' + path, import.meta.url), 'utf8');
const cargo = await read('src/shared/Cargo.luau');
const data = (await read('src/server/AnglerData.luau')).replace(
  'local Cargo\n', 'local Cargo = Grid\n');
const passes = await read('src/shared/Gamepasses.luau');
let ownership = await read('src/server/GamepassService.luau');
ownership = ownership.replace('require(game:GetService("ReplicatedStorage").Shared.Gamepasses)', 'Passes');
let angler = await read('src/server/AnglerService.luau');
for (const [expression, replacement] of [
  ['script.Parent.BoatService', 'Boats'], ['script.Parent.AnglerData', 'Data'],
  ['script.Parent.GamepassService', 'Ownership'], ['ReplicatedStorage.Shared.Aboard', 'aboard'],
  ['ReplicatedStorage.Shared.BoatCatalog', 'layouts'], ['ReplicatedStorage.Shared.AnglerCatalog', 'catalog'],
  ['ReplicatedStorage.Shared.StaffCatalog', '{}'], ['ReplicatedStorage.Shared.Paths', '{}'],
  ['game:GetService("ReplicatedFirst"):WaitForChild("UITheme")', '{}'],
]) angler = angler.replace('require(' + expression + ')', replacement);

const program = `
local checks = 0
local function check(value, message) checks += 1 assert(value, message) end
local Grid = (function() ${cargo} end)()
local Data = (function() ${data} end)()
local Passes = (function() ${passes} end)()
check(Passes.AutoStore.Id == 3722004182, "Correct pass ID")
local function signal()
 local callbacks = {}
 return { Connect = function(_, fn) table.insert(callbacks, fn) end,
 Fire = function(_, ...) for _, fn in callbacks do fn(...) end end }
end
local players = { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end }
local market = { PromptGamePassPurchaseFinished = signal() }
local queryCount, owns, failure = 0, false, false
function market:UserOwnsGamePassAsync(id, pass)
 queryCount += 1
 check(pass == 3722004182, "Server checks configured pass")
 if failure then error("API unavailable") end
 return owns
end
local game = { GetService = function(_, name)
 return ({ Players = players, MarketplaceService = market, ReplicatedStorage = {} })[name]
end }
local task = { spawn = function(fn, ...) fn(...) end }
local function player(id)
 return { UserId = id, Parent = players, Character = {}, attributes = {},
 SetAttribute = function(self, key, value) self.attributes[key] = value end }
end
local Ownership = (function() ${ownership} end)()
Ownership.start()
local buyer = player(1)
check(not Ownership.ownsAutoStore(buyer), "Non-owner has no benefit")
local count = queryCount
check(not Ownership.ownsAutoStore(buyer) and queryCount == count, "Negative result cached")
market.PromptGamePassPurchaseFinished:Fire(buyer, 99, true)
check(not Ownership.ownsAutoStore(buyer), "Other passes grant nothing")
market.PromptGamePassPurchaseFinished:Fire(buyer, 3722004182, false)
check(not Ownership.ownsAutoStore(buyer), "Cancelled purchase grants nothing")
market.PromptGamePassPurchaseFinished:Fire(buyer, 3722004182, true)
check(Ownership.ownsAutoStore(buyer) and buyer.attributes.OwnsAutoStore, "Purchase enables immediately")
owns = true
local returning = player(2)
check(Ownership.ownsAutoStore(returning), "Existing owner recognized")
owns, failure = false, true
check(not Ownership.ownsAutoStore(player(3)), "API failure grants nothing")
failure = false
local catalog = { Fish = { Test = { AverageKg = 1, RarityDenominator = 10,
 Shapes = { Normal = { "##" } } } }, Mutations = { Normal = {} } }
local layouts = { TestBoat = { Hold = { "#", "#", "#" }, StarterParts = {
 { PartId = "Lantern", X = 1, Y = 1, R = 0 } } } }
local onBoat, active, saveFails = true, true, false
local model = {}
local profile
local Boats = {
 activeBoat = function() if active then return "TestBoat", model end end,
 updateProgress = function(_, transform)
  if saveFails then return false, "Save failed" end
  transform(profile)
  return true, "Saved"
 end,
}
local aboard = function(character, boat) return onBoat and boat == model end
local Angler = (function() ${angler} end)()
local function catch(who)
 return Angler.recordCatch(who, "Test", "Normal", 1, 10, "Normal", {})
end
local nonOwner = player(4)
for _, scenario in {
 { buyer, true, true, true }, { nonOwner, true, true, false },
 { buyer, false, true, false }, { buyer, true, false, false },
} do
 profile = { Angler = Data.decode(nil) }
 onBoat, active = scenario[2], scenario[3]
 local ok, _, stored = catch(scenario[1])
 check(ok and stored == scenario[4], "Owner/aboard/active gate")
 check((profile.Angler.Hand == nil) == scenario[4], "Correct catch destination")
 check(profile.Angler.Stats.TotalCaught == 1 and profile.Angler.Stats.TotalXP == 100, "Catch rewards preserved")
 if stored then
  local items = profile.Angler.Holds.TestBoat
  check(#items == 2 and items[1].PartId == "Lantern", "Kit preserved")
  check(items[2].R % 2 == 1 and items[2].Y == 2, "Rotates into available space")
 end
end
onBoat, active = true, true
profile = { Angler = Data.decode(nil) }
catch(buyer)
local ok, _, stored = catch(buyer)
check(ok and not stored and profile.Angler.Hand ~= nil, "Full hold keeps catch in hand")
check(#profile.Angler.Holds.TestBoat == 2, "Full hold does not overlap or lose fish")
local existing = profile.Angler.Hand
catch(buyer)
check(profile.Angler.Hand.Kg == existing.Kg and #profile.Angler.Holds.TestBoat == 2, "Full hand does not move old fish")
saveFails = true
local before = profile.Angler.Stats.TotalCaught
ok, _, stored = catch(buyer)
check(not ok and not stored and profile.Angler.Stats.TotalCaught == before, "Failed save reports no auto store")
-- Compare with an exhaustive fit oracle across every occupancy of a small irregular hold.
local mask = { ".##", "###", "##." }
local positions = {}
for y, row in mask do for x = 1, #row do if Grid.open(mask, x, y) then table.insert(positions, {x,y}) end end end
for bits = 0, 2 ^ #positions - 1 do
 local items = {}
 for i, p in positions do if bit32.band(bits, 2 ^ (i-1)) ~= 0 then
  table.insert(items, { PartId = "Lantern", X = p[1], Y = p[2], R = 0 })
 end end
 local item = { Fish = { FishId = "Test", Size = "Normal" } }
 local taken = Grid.occupied(items, catalog.Fish)
 local any = false
 for r = 0, 3 do for y = 1, #mask do for x = 1, 3 do
  any = any or Grid.fits(mask, taken, Grid.shape(item, catalog.Fish), x, y, r)
 end end end
 local spot = Grid.bestSpot(mask, items, item, catalog.Fish)
 check((spot ~= nil) == any, "Finds any available orientation")
 if spot then check(Grid.fits(mask, taken, Grid.shape(item, catalog.Fish), spot.X, spot.Y, spot.R), "Placement legal") end
end
print("Auto Store: " .. checks .. " ownership, catch transaction and packing checks passed.")
`;
const folder = await mkdtemp(join(tmpdir(), 'auto-store-'));
try {
 const target = join(folder, 'checks.luau');
 await writeFile(target, program);
 const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { encoding: 'utf8', timeout: 30000 });
 if (result.stdout) process.stdout.write(result.stdout);
 if (result.stderr) process.stderr.write(result.stderr);
 if (result.error) throw result.error;
 if (result.status !== 0) throw new Error('Auto Store checks failed');
} finally { await rm(folder, { recursive: true, force: true }); }
