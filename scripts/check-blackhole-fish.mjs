// Real catch and model behavior under recording doubles; Studio validates rendering.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { freezerRuntime } from './freezer-test-runtime.mjs';
import { fishSpeciesSource } from './fish-species.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = async (file) => (await readFile(join(root, file), 'utf8')).replace(/\r\n/g, '\n');
const speciesSource = fishSpeciesSource(root);
const catalogSource = (await read('src/shared/AnglerCatalog.luau'))
  .replace('require(script.Parent.FishSpecies)', 'species');
let runtime = await freezerRuntime();
for (const hook of [
  `local FishSpecies = ${speciesSource}`,
  'local FishMutations = (function()',
  'return Packing, FishModels',
]) {
  if (!runtime.includes(hook)) throw new Error(`Black hole fish harness hook changed: ${hook.slice(0, 70)}`);
}
runtime = runtime
  .replace(`local FishSpecies = ${speciesSource}`, 'local FishSpecies = species')
  .replace('local FishMutations = (function()', `local species = ${speciesSource}\nlocal FishMutations = (function()`)
  .replace('local freezerTestPacking, freezerTestModels =', 'local freezerTestPacking, freezerTestModels, species, Catalog =')
  .replace('return Packing, FishModels', `local Catalog = (function()\n${catalogSource}\nend)()\nreturn Packing, FishModels, species, Catalog`);

const program = runtime + `
local FishCatch = (function()
${await read('src/shared/FishCatch.luau')}
end)()
local Cargo = (function()
${await read('src/shared/Cargo.luau')}
end)()
local requested = { "VoidlightAngler", "EclipseRay", "Riftmaw", "SingularitySerpent" }
local special, checks, combinations = {}, 0, 0
local function check(value, message)
  checks += 1
  assert(value, message)
end
local function finite(value)
  return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function vector(value)
  return value and finite(value.X) and finite(value.Y) and finite(value.Z)
end
local function black(color)
  return color.R == 0 and color.G == 0 and color.B == 0
end
local function purple(color)
  return color.R > 0.25 and color.B > 0.4 and color.G < color.R and color.G < color.B
end
local seasons = { "Spring", "Summer", "Autumn", "Winter" }
local ordinaryWeather = {
  { name = "Clear", Clear = true },
  { name = "Rain", Rain = true },
  { name = "Storm", Rain = true, Storm = true },
  { name = "Supercell", Rain = true, Storm = true, Supercell = true },
  { name = "Foggy", Clear = true, Foggy = true },
  { name = "Event ended", Rain = true, BlackHole = false },
  { name = "No weather flags" },
}

for _, id in requested do
  special[id] = true
  local entry = assert(species[id], id .. ": species module exists")
  local fish = assert(Catalog.Fish[id], id .. ": catalog registration exists")
  check(type(entry.Build) == "function" and freezerTestModels.has(id), id .. ": model builder registered")
  check(finite(fish.MinKg) and finite(fish.AverageKg) and finite(fish.MaxKg)
    and fish.MinKg > 0 and fish.MinKg < fish.AverageKg and fish.AverageKg < fish.MaxKg,
    id .. ": ordered positive weight range")
  check(Catalog.Rarities[fish.Rarity] ~= nil and finite(fish.RarityDenominator)
    and fish.RarityDenominator >= 1 and finite(fish.BaseValue) and fish.BaseValue > 0,
    id .. ": valid rarity, odds and value")
  check(not fish.DropOnly and entry.Pools and table.find(entry.Pools, "OpenSea") ~= nil,
    id .. ": assigned to inherited Open Sea catch pool")
  check(string.find(FishCatch.seasonLabel(fish), "black hole", 1, true) ~= nil,
    id .. ": bestiary exposes event requirement")

  local lastArea = 0
  for _, size in { "Normal", "Big", "Huge" } do
    local rows = assert(entry.Shapes[size], id .. ": cargo footprint exists for " .. size)
    check(#rows > 0 and #rows[1] > 0, id .. ": nonempty cargo footprint")
    for _, row in rows do
      check(#row == #rows[1] and string.match(row, "^[.#]+$") ~= nil,
        id .. ": rectangular valid cargo rows")
    end
    local cells = Cargo.cells(Cargo.shape({ FishId = id, Size = size }, Catalog.Fish))
    check(#cells > lastArea, id .. ": cargo area grows for " .. size)
    lastArea = #cells
    local occupied, visited = {}, {}
    for _, cell in cells do occupied[cell[1] .. ":" .. cell[2]] = true end
    local queue = { cells[1] }
    visited[cells[1][1] .. ":" .. cells[1][2]] = true
    local cursor = 1
    while cursor <= #queue do
      local cell = queue[cursor]
      cursor += 1
      for _, delta in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
        local x, y = cell[1] + delta[1], cell[2] + delta[2]
        local key = x .. ":" .. y
        if occupied[key] and not visited[key] then
          visited[key] = true
          table.insert(queue, { x, y })
        end
      end
    end
    check(#queue == #cells, id .. ": connected cargo footprint")
    for rotation = 0, 3 do
      check(#Cargo.cells(rows, rotation) == #cells, id .. ": cargo rotations preserve area")
    end
    local initialRoll = if size == "Huge" then 0.001 elseif size == "Big" then 0.03 else 0.5
    for _, sample in { 0, 0.5, 0.999999 } do
      local calls = 0
      local kg, actualSize = FishCatch.rollWeight(fish, function()
        calls += 1
        return if calls == 1 then initialRoll else sample
      end)
      check(actualSize == size and finite(kg) and kg >= fish.MinKg and kg <= fish.MaxKg,
        id .. ": valid weight for " .. size)
      local value = FishCatch.value(fish, kg, actualSize)
      local difficulty = FishCatch.difficulty(fish, Catalog.Rarities, kg / fish.AverageKg)
      check(finite(value) and value >= 1 and value % 1 == 0 and finite(difficulty)
        and difficulty >= 0.05 and difficulty <= 1, id .. ": valid sale value and fight difficulty")
    end
  end

  local plain = assert(freezerTestModels.create(id), id .. ": model builds")
  local bounds = plain:GetAttribute("BoundsSize")
  check(vector(bounds) and bounds.X > 0 and bounds.Y > 0 and bounds.Z > 0,
    id .. ": finite positive bounds")
  local accents, darkBody, translucent = 0, 0, {}
  for _, part in plain:GetDescendants() do
    if not part:IsA("BasePart") then continue end
    check(vector(part.Size) and vector(part.Position) and part.Size.X > 0
      and part.Size.Y > 0 and part.Size.Z > 0
      and vector(part.CFrame.RightVector) and vector(part.CFrame.UpVector) and vector(part.CFrame.ZVector),
      id .. ": finite positive part geometry")
    local mesh = part:FindFirstChildOfClass("SpecialMesh")
    check(not mesh or mesh.Scale == nil or mesh.Scale.Magnitude > 0,
      id .. ": fallback geometry remains visible without EditableMesh")
    if part:GetAttribute("BlackHoleAccent") then
      check(part.Material == "Neon" and purple(part.Color) and part.Transparency < 1,
        id .. ": intrinsic accent is visible neon purple")
      accents += 1
      if part.Transparency > 0 then translucent[part.Name] = part.Transparency end
    elseif part.Transparency < 1 and part.Color.R < 0.25 and part.Color.G < 0.2 and part.Color.B < 0.35 then
      darkBody += 1
    end
  end
  check(accents > 0 and darkBody > 0, id .. ": purple neon accents contrast with dark body")
  plain:Destroy()
  for _, mutation in { "VoidTouched", "Corrupted+VoidTouched" } do
    local model = assert(freezerTestModels.create(id, { Mutation = mutation, Corruptions = { "Eye" } }))
    local preserved = 0
    for _, part in model:GetDescendants() do
      if not part:IsA("BasePart") then continue end
      if part:GetAttribute("BlackHoleAccent") then
        check(part.Material == "Neon" and purple(part.Color),
          id .. ": " .. mutation .. " preserves intrinsic purple glow")
        if translucent[part.Name] then
          check(part.Transparency == translucent[part.Name], id .. ": event finish preserves translucent glow")
        end
        preserved += 1
      else
        check(black(part.Color) and part.Material == "SmoothPlastic",
          id .. ": " .. mutation .. " blackens other geometry")
      end
    end
    check(preserved == accents, id .. ": event mutation retains every intrinsic accent")
    model:Destroy()
  end
end

-- Existing species keep their completely black Void Touched finish.
for _, mutation in { "VoidTouched", "Corrupted+VoidTouched" } do
  local model = assert(freezerTestModels.create("Cod", { Mutation = mutation, Corruptions = { "Eye" } }))
  for _, part in model:GetDescendants() do
    if part:IsA("BasePart") then
      check(black(part.Color) and part.Material == "SmoothPlastic",
        "Ordinary fish keep black " .. mutation .. " appearance")
    end
  end
  model:Destroy()
end

for poolId, pool in Catalog.Pools do
  for _, id in requested do
    check(table.find(pool.Fish, id) ~= nil, id .. ": available through inheritance in " .. poolId)
  end
  for _, season in seasons do
    for _, night in { false, true } do
      for _, beach in { false, true } do
        local event = { BlackHole = true, Rain = true, Day = not night, Night = night, Beach = beach }
        local during = FishCatch.inSeason(pool, Catalog.Fish, season, event)
        for _, id in requested do
          check(table.find(during.Fish, id) ~= nil, id .. ": catchable during event in " .. poolId .. "/" .. season)
        end
        for _, state in ordinaryWeather do
          local conditions = table.clone(state)
          conditions.Day, conditions.Night, conditions.Beach = not night, night, beach
          local filtered = FishCatch.inSeason(pool, Catalog.Fish, season, conditions)
          combinations += 1
          for _, id in requested do
            check(table.find(filtered.Fish, id) == nil,
              id .. ": excluded for " .. poolId .. "/" .. season .. "/" .. state.name)
          end
          for _, pick in { 0, 0.01, 0.06, 0.5, 0.99, 0.999999 } do
            local caught = FishCatch.pickSpecies(filtered, Catalog.Fish, function() return pick end)
            check(not special[caught], poolId .. ": weighted picker cannot return event fish after filtering")
          end
        end
        local missing = FishCatch.inSeason(pool, Catalog.Fish, season, nil)
        for _, id in requested do
          check(table.find(missing.Fish, id) == nil, id .. ": unavailable when catch conditions are missing")
        end
      end
    end
  end
end

-- A controlled stocked pool proves that each fish is reachable during the event
-- and the actual picker falls back to junk before and immediately after it.
for _, id in requested do
  local pool = { Fish = { id }, Junk = { "WoodenBranch" } }
  for _, season in seasons do
    local active = FishCatch.inSeason(pool, Catalog.Fish, season, { BlackHole = true, Rain = true })
    check(FishCatch.pickSpecies(active, Catalog.Fish, function() return 0.5 end) == id,
      id .. ": reachable through actual picker during event")
    for _, conditions in { {}, { BlackHole = false, Rain = true } } do
      local inactive = FishCatch.inSeason(pool, Catalog.Fish, season, conditions)
      check(FishCatch.pickSpecies(inactive, Catalog.Fish, function() return 0.5 end) == "WoodenBranch",
        id .. ": cannot be picked before or after event")
    end
  end
end
print("PASS black hole fish: " .. #requested .. " species; " .. combinations
  .. " ordinary-weather combinations; " .. checks .. " spawn, cargo, geometry and mutation checks")
print("Geometry doubles only; final appearance and device budgets require Studio play testing.")
`;

const temporaryRoot = resolve(tmpdir());
const temporary = await mkdtemp(join(temporaryRoot, 'blackhole-fish-'));
try {
  const target = join(temporary, 'check.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], {
    cwd: root, encoding: 'utf8', timeout: 30000,
  });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Black hole fish checks failed (Lute exit ${result.status})`);
} finally {
  if (dirname(resolve(temporary)) !== temporaryRoot) throw new Error('Unexpected temporary directory');
  await rm(temporary, { recursive: true, force: true });
}
