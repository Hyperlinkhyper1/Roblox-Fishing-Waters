// Run production cooking lifecycle rules and dish builders. Geometry uses the
// repository's recording Roblox doubles; this does not replace a Studio playtest.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = path => readFile(join(root, path), 'utf8');
function run(target) {
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], {
    cwd: root, encoding: 'utf8', timeout: 30000, maxBuffer: 4 * 1024 * 1024,
  });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Cooking checks failed (${result.status})`);
}
run(join(root, 'scripts/cooking-recipes.luau'));

const primitives = (await read('scripts/harbour-geometry.luau')).split('local CFrame = {}')[0];
let program = (await read('scripts/drydock-geometry.luau')).split('local function loadBoatCatalog()')[0]
  .replace('-- SHARED_PRIMITIVES --', () => primitives);
for (const [name, path] of Object.entries({
  LowPoly: 'src/server/Map/LowPoly.luau', Props: 'src/server/Map/Props.luau',
  Kitchen: 'src/server/Map/Kitchen.luau', Recipes: 'src/shared/Recipes.luau',
})) {
  const source = (await read(path)).replace(/^local (\w+) = require\(.*$/gm, 'local $1 = dependencies.$1');
  program += `\nlocal ${name} = (function()\n${source}\nend)()\ndependencies.${name} = ${name}\n`;
}
program += `
local checks, maxParts = 0, 0
local function check(condition, message) checks += 1; assert(condition, message) end
local function near(a, b) return (a - b).Magnitude < 0.00001 end
local signatures = {}
for _, id in Recipes.Order do
  local recipe = Recipes.Items[id]
  local reference = Kitchen.buildDish(id, recipe.Look, CFrame.identity)
  local referenceParts = reference:GetDescendants()
  check(#referenceParts >= 5 and #referenceParts <= 32, id .. " has visible food within its part budget")
  maxParts = math.max(maxParts, #referenceParts)
  local signature = {}
  for _, part in referenceParts do
    table.insert(signature, string.format("%s:%.3f:%.3f:%.3f:%.3f:%.3f:%.3f", part.Name,
      part.Size.X, part.Size.Y, part.Size.Z, part.Color.R, part.Color.G, part.Color.B))
  end
  local joined = table.concat(signature, "|")
  check(not signatures[joined], id .. " has a distinct appearance from " .. tostring(signatures[joined]))
  signatures[joined] = id
  for _, frame in { CFrame.identity, CFrame.new(170, 12, -45) * CFrame.Angles(0, 0.73, 0) } do
    local model = Kitchen.buildDish(id, recipe.Look, frame)
    check(model:GetAttribute("RecipeId") == id, id .. " keeps its recipe identity")
    local parts = model:GetDescendants()
    check(#parts == #referenceParts, id .. " preserves detail when placed")
    for index, part in parts do
      check(part:IsA("BasePart") and part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery,
        id .. "/" .. part.Name .. " is inert decoration")
      check(part.Size.X > 0 and part.Size.Y > 0 and part.Size.Z > 0, id .. " has positive part dimensions")
      local localPosition = frame:PointToObjectSpace(part.Position)
      check(near(localPosition, referenceParts[index].Position), id .. " follows the station's translated and rotated frame")
      check(math.abs(localPosition.X) <= 1 and math.abs(localPosition.Z) <= 1 and localPosition.Y >= 0 and localPosition.Y <= 1,
        id .. " fits a dish spot")
    end
  end
end
print(string.format("Cooking dish models: %d geometry checks passed across %d distinct dishes, maximum %d parts (recording doubles).",
  checks, #Recipes.Order, maxParts))
`;
const temporary = await mkdtemp(join(tmpdir(), 'fishing-cooking-'));
try {
  const target = join(temporary, 'dishes.luau');
  await writeFile(target, program);
  run(target);
} finally {
  if (dirname(resolve(temporary)) !== resolve(tmpdir())) throw new Error('Unexpected temporary directory');
  await rm(temporary, { recursive: true, force: true });
}
