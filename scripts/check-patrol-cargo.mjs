// Exercise the actual grid, catalog and saved-data migration without Studio.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const read = path => readFile(new URL('../' + path, import.meta.url), 'utf8');
const [cargo, boats, catalog, source] = await Promise.all([
  read('src/shared/Cargo.luau'), read('src/shared/BoatCatalog.luau'),
  read('src/shared/AnglerCatalog.luau'), read('src/server/AnglerData.luau'),
]);
const data = source.replace('local Cargo\n', 'local Cargo = Grid\n')
  .replace('require("../shared/BoatCatalog")', 'Boats')
  .replace('require("../shared/AnglerCatalog")', 'Catalog');
const program = `
local Color3 = { fromRGB = function(...) return {...} end }
local Grid = (function() ${cargo} end)()
local Boats = (function() ${boats} end)()
local Catalog = (function() ${catalog} end)()
local Data = (function() ${data} end)()
local spec = Boats.PatrolBoat
local _, width, height = Grid.cells(spec.Hold)
assert(width == 8 and height == 15 and Grid.capacity(spec.Hold) == 90, "Long, narrow 90-cell hold")
local function valid(items)
  for index, item in items do
    assert(Grid.fits(spec.Hold, Grid.occupied(items, Catalog.Fish, index),
      Grid.shape(item, Catalog.Fish), item.X, item.Y, item.R), "Cargo overlaps or leaves hull")
  end
end
valid(spec.StarterParts)
local upgraded = Data.decode(nil)
upgraded.PatrolHoldVersion = 2
upgraded.Holds.PatrolBoat = {
  {PartId = "PatrolEngine", X = 3, Y = 17, R = 0},
  {PartId = "Lantern", X = 4, Y = 1, R = 0},
  {PartId = "PatrolEngine", X = 1, Y = 9, R = 0},
  {PartId = "PatrolEngine", X = 4, Y = 9, R = 0},
  {PartId = "PatrolEngine", X = 1, Y = 13, R = 0},
  {PartId = "Rudder", X = 7, Y = 9, R = 0},
  {PartId = "Rudder", X = 8, Y = 9, R = 0},
  {PartId = "Rudder", X = 7, Y = 11, R = 0},
}
local upgradedAfter = Data.decode(upgraded)
valid(upgradedAfter.Holds.PatrolBoat)
assert(#upgradedAfter.Holds.PatrolBoat == 8, "Paid upgrades survive migration")
assert(#Grid.cells(Grid.shape(spec.StarterParts[1], {})) == 12, "Patrol engine occupies twelve cells")
assert(#Grid.cells(Grid.Parts.Engine.Shape) == 4, "Other boats retain four-cell engines")
local oldMask = {}
for _, row in Boats.Speedboat.Hold do
  table.insert(oldMask, (row:gsub(".", function(tile) return tile .. tile end)))
end
local oldKit = {{PartId = "Engine", X = 6, Y = 11, R = 0}, {PartId = "Lantern", X = 7, Y = 1, R = 0}}
local raw = Data.decode(nil)
raw.PatrolHoldVersion = nil
raw.Holds.PatrolBoat = oldKit
local occupied = Grid.occupied(oldKit, {})
local count = 0
for y, row in oldMask do
  for x = 1, #row do
    if Grid.open(oldMask, x, y) and not Grid.at(occupied, x, y) then
      count += 1
      local caught = Data.recordCatch(nil, "Test", "Normal", 1, 10, count,
        {Test = {AverageKg = 1, RarityDenominator = 1}}, {Normal = {}})
      table.insert(oldKit, {Fish = caught.Hand, X = x, Y = y, R = 0})
    end
  end
end
assert(count == 123, "Full old hold fixture")
local migrated = Data.decode(raw)
valid(migrated.Holds.PatrolBoat)
assert(#migrated.Storage == 46 and #migrated.Holds.PatrolBoat == 79, "Full hold overflow preserved in storage")
assert(raw.PatrolHoldVersion == nil and #raw.Storage == 0 and oldKit[1].PartId == "Engine", "Migration copies saved input")
local seen = {}
for _, item in migrated.Holds.PatrolBoat do
  if item.Fish then
    assert(not seen[item.Fish.CaughtAt], "Duplicate fish")
    seen[item.Fish.CaughtAt] = true
  end
end
for _, fish in migrated.Storage do
  assert(not seen[fish.CaughtAt], "Duplicate overflow fish")
  seen[fish.CaughtAt] = true
end
for id = 1, count do assert(seen[id], "Migration lost a fish") end
local again = Data.decode(migrated)
assert(#again.Storage == 46 and again.PatrolHoldVersion == 3, "Migration runs once")
for index, item in migrated.Holds.PatrolBoat do
  local saved = again.Holds.PatrolBoat[index]
  assert(saved.X == item.X and saved.Y == item.Y and saved.R == item.R and saved.PartId == item.PartId, "Reload rearranged cargo")
end
local fresh = Data.decode(nil)
local rearranged = Data.moveCargo(fresh, "PatrolBoat", spec, 1, {X = 2, Y = 12, R = 1}, Catalog.Fish)
assert(rearranged and rearranged.Holds.PatrolBoat[1].Y == 12 and rearranged.Holds.PatrolBoat[1].R == 1,
  "First move preserves larger engine placement and rotation")
valid(rearranged.Holds.PatrolBoat)
local mixed = Data.decode(nil)
mixed.PatrolHoldVersion = nil
mixed.Holds.PatrolBoat = {{PartId = "Engine", X = 6, Y = 11, R = 0}, {PartId = "Lantern", X = 7, Y = 1, R = 0}}
local fishCount = 0
for id, fish in Catalog.Fish do
  if fishCount >= 12 then break end
  local caught = Data.recordCatch(nil, id, "Normal", fish.AverageKg, 10, fishCount + 1,
    Catalog.Fish, Catalog.Mutations, "Huge")
  local item = {Fish = caught.Hand}
  local spot = Grid.bestSpot(oldMask, mixed.Holds.PatrolBoat, item, Catalog.Fish)
  if spot then
    item.X, item.Y, item.R = spot.X, spot.Y, spot.R
    table.insert(mixed.Holds.PatrolBoat, item)
    fishCount += 1
  end
end
assert(fishCount > 3, "Mixed species fixture")
local packed = Data.decode(mixed)
valid(packed.Holds.PatrolBoat)
assert(#packed.Holds.PatrolBoat - 2 + #packed.Storage == fishCount, "Mixed large fish preserved")
local recovered = Data.takeStored(migrated)
assert(recovered and recovered.Hand and #recovered.Storage == 45, "Overflow remains recoverable")
print("Patrol cargo: dimensions, engine, full saved-hold migration, overflow, reload and rotation checks passed.")
`;
const temporary = await mkdtemp(join(tmpdir(), 'patrol-cargo-'));
try {
  const target = join(temporary, 'check.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { stdio: 'inherit', timeout: 30000 });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Patrol cargo checks failed');
} finally {
  await rm(temporary, { recursive: true, force: true });
}
