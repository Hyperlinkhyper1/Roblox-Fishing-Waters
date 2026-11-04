// Run the real scenery repair against all fifteen production dock orientations.
// Recording geometry verifies placement; Roblox physics still needs Studio play.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = path => readFile(join(root, path), 'utf8');
const primitives = (await read('scripts/harbour-geometry.luau')).split('local CFrame = {}')[0];
const mocks = (await read('scripts/drydock-geometry.luau')).split('local function loadBoatCatalog()')[0]
  .replace('-- SHARED_PRIMITIVES --', () => primitives);
const source = (await read('src/server/Map/Harbour.luau'))
  .replace(/^local (\w+) = require\(.*$/gm, 'local $1 = dependencies.$1')
  .replaceAll('require(game:GetService("ReplicatedStorage").Shared.Biomes)', 'dependencies.Biomes')
  .replace(/return Harbour\s*$/, 'return {repair = Harbour.ensureBaseBoatClearance, shape = makeShape, shore = shoreAt, anchors = BASES, distance = coastDistance}');
const program = mocks + `
local originalTypeof = typeof
typeof = function(value)
  if type(value) == "table" and getmetatable(value) == getmetatable(Vector2.zero) then return "Vector2" end
  return originalTypeof(value)
end
dependencies.Props = {pick = function() end}
dependencies.Biomes = (function()
${await read('src/shared/Biomes.luau')}
end)()
local Harbour = (function()
${source}
end)()
local catalog = (function()
${await read('src/shared/BoatCatalog.luau')}
end)()
local checks = 0
local function check(value, message)
  checks += 1
  assert(value, message)
end
local map = Instance.new("Folder")
map.Name, map.Parent = "Map", workspace
local island = Instance.new("Model")
island.Name, island.Parent = "Harbour Isle", map
local center = dependencies.Biomes.Normal.center
island:SetAttribute("LayoutCenter", center)
-- Old base-one migration flags must not suppress the all-base repair.
island:SetAttribute("BaseOneRedBoatRemoved", true)
island:SetAttribute("BaseOneFrontBoatRemoved", true)
local shape = Harbour.shape(center)
local bases, boats = Instance.new("Folder"), Instance.new("Model")
bases.Name, bases.Parent = "Bases", island
boats.Name, boats.Parent = "Boats", island
local frames, fixtures = {}, {}
local function boatAt(parent, frame, legacy)
  local model = Instance.new("Model")
  model.Name, model.Parent = "Boat", parent
  local floor = Instance.new("Part")
  floor.Name = if legacy then "Part" else "BoatFloor"
  floor.Size, floor.CFrame, floor.Anchored = Vector3.new(5, 0.4, 16), frame, true
  floor.Parent = model
  local mast = Instance.new("Part")
  mast.Size, mast.CFrame, mast.Anchored = Vector3.new(0.4, 8, 0.4), frame * CFrame.new(0, 4, 2), true
  mast.Parent = model
  return model
end
for id, anchor in Harbour.anchors do
  local shore, out = Harbour.shore(shape, shape.toWorld(anchor))
  local position = Vector3.new(shore.X, 0, shore.Y)
  local frame = CFrame.lookAt(position, position + Vector3.new(out.X, 0, out.Y))
  table.insert(frames, frame)
  local base = Instance.new("Model")
  base.Name, base.Parent = "Base" .. id, bases
  base:SetAttribute("BoatDockFrame", frame)
  -- Most block a large hull's bow, beyond the original radial shore exclusion.
  -- One overlaps the lane only by its hull edge and one has an unnamed legacy floor.
  local localFrame = if id == 2 then CFrame.new(42, 0, -75) else CFrame.new(0, 0, -85)
  table.insert(fixtures, boatAt(boats, frame * localFrame, id == 3))
end
local shop = Instance.new("Model")
shop.Name, shop.Parent = "Drydock", island
local launch = frames[1] * CFrame.new(90, 0, -90)
shop:SetAttribute("LaunchWaterFrame", launch)
table.insert(fixtures, boatAt(boats, launch, false))
local distant = boatAt(boats, CFrame.new(center.X - 1200, 0, center.Y), false)
local distantBefore = distant:GetPivot()
local playerBoats = Instance.new("Folder")
playerBoats.Name, playerBoats.Parent = "PlayerBoats", workspace
local owned = boatAt(playerBoats, frames[1] * CFrame.new(0, 0, -70), false)
local ownedBefore = owned:GetPivot()
local before, relatives = {}, {}
for _, boat in fixtures do
  before[boat] = boat:GetPivot()
  relatives[boat] = boat:GetChildren()[1].CFrame:ToObjectSpace(boat:GetChildren()[2].CFrame)
end
Harbour.repair(map)
for _, boat in fixtures do
  local box, size = boat:GetBoundingBox()
  local radius = Vector2.new(size.X, size.Z).Magnitude / 2
  check(boat.Parent == boats and (boat:GetPivot().Position - before[boat].Position).Magnitude > 1, "Obstructing scenery is moved and retained")
  check(Harbour.distance(shape, Vector2.new(box.Position.X, box.Position.Z)) <= -(radius + 16), "The entire boat stays in clear water")
  for _, frame in frames do
    local p = frame:PointToObjectSpace(box.Position)
    check(math.abs(p.X) >= 35 + radius or p.Z <= -140 - radius or p.Z >= 20 + radius, "Every berth and departure lane remains open")
    for id, spec in catalog do
      local extra = math.max(0, (spec.Length - catalog.Rowboat.Length) / 2)
      local spawn = frame * CFrame.new(0, 0, -52 - extra)
      local p = spawn:PointToObjectSpace(box.Position)
      check(math.abs(p.X) > math.max(11, spec.Beam + 2) / 2 + radius or math.abs(p.Z) > (spec.Length + 1) / 2 + radius, "Scenery clears the spawn volume for " .. id)
    end
  end
  local p = launch:PointToObjectSpace(box.Position)
  check(math.abs(p.X) >= 45 + radius or p.Z <= -70 - radius or p.Z >= 55 + radius, "Relocated scenery clears the drydock too")
  local pieces = boat:GetChildren()
  local relative = pieces[1].CFrame:ToObjectSpace(pieces[2].CFrame)
  check((relative.Position - relatives[boat].Position).Magnitude < 0.0001, "Whole-boat movement preserves the mast and floor layout")
  check((boat:GetPivot().RightVector - before[boat].RightVector).Magnitude < 0.0001, "Whole-boat movement preserves rotation")
end
check((distant:GetPivot().Position - distantBefore.Position).Magnitude < 0.0001, "Unobstructing scenery stays in place")
check((owned:GetPivot().Position - ownedBefore.Position).Magnitude < 0.0001, "Player boats stay in place")
local repaired = {}
for _, boat in fixtures do repaired[boat] = boat:GetPivot().Position end
Harbour.repair(island)
for _, boat in fixtures do
  check((boat:GetPivot().Position - repaired[boat]).Magnitude < 0.0001, "Repeated startup repairs are idempotent")
end
print(string.format("Base boat clearance: %d geometry and migration checks passed.", checks))
`;
const temporary = await mkdtemp(join(tmpdir(), 'base-boat-clearance-'));
try {
  const target = join(temporary, 'check.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute.exe', ['run', target], {
    cwd: root, encoding: 'utf8', timeout: 30000, maxBuffer: 4 * 1024 * 1024,
  });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Base boat clearance checks failed');
} finally {
  await rm(temporary, { recursive: true, force: true });
}
