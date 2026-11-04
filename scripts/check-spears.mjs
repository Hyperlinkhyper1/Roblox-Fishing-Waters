// Build every real spear with the shared recording primitives. Checks assembly
// safety and blade geometry; Studio still owns the final rendering/grip check.
// LUAU selects the standalone Luau CLI; otherwise use the project's LUTE runner.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = resolve(import.meta.dirname, '..');
const read = file => readFile(join(root, file), 'utf8');
const folder = await mkdtemp(join(tmpdir(), 'fishing-spears-'));
try {
  const primitives = await read('scripts/rod-physics.luau');
  let program = primitives.slice(0, primitives.indexOf('local function loadDynamics()'))
    .replace('class == "BasePart" and kind == "Part"', 'class == "BasePart" and (kind == "Part" or kind == "WedgePart")');
  const skins = await read('src/shared/SpearSkins.luau');
  const source = (await read('src/shared/Spears.luau'))
    .replace('require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").SpearSkins)', 'SpearSkins');
  program += `\nlocal SpearSkins = (function()\n${skins}\nend)()\nlocal Spears = (function()\n${source}\nend)()\n`;
  program += String.raw`
local checks = 0
local function check(value, message) checks += 1; assert(value, message) end
local function near(a, b) return math.abs(a - b) < 1e-6 end
local ids = { "Starter" }
for _, id in SpearSkins.Crates.SpearCrate.Skins do table.insert(ids, id) end
for _, id in ids do
  local tool = Spears.build(if id == "Starter" then nil else id, 0.2)
  local handle = tool:FindFirstChild("Handle")
  check(tool.Name == "Spear" and tool:GetAttribute("SpearId") == Spears.ID, id .. " tool identity")
  check(tool.RequiresHandle and not tool.CanBeDropped and tags[tool] == "Spear", id .. " equipment settings")
  check(handle and handle.Transparency == 1, id .. " has an invisible equipment root")
  check(handle.CFrame.Position.Magnitude == 0 and handle.CFrame.UpVector.Y == 1, id .. " keeps the combat grip frame")
  check(tool:GetAttribute("SpearSkin") == (if id == "Starter" then nil else id), id .. " skin attribute")
  local parts, welds, heads = {}, {}, {}
  local lo, hi = vector(math.huge, math.huge, math.huge), vector(-math.huge, -math.huge, -math.huge)
  for _, part in tool:GetDescendants() do
    if part:IsA("BasePart") then
      table.insert(parts, part)
      check(not part.Anchored and part.Massless and not part.CanCollide and not part.CanTouch and not part.CanQuery,
        id .. " unsafe physics: " .. part.Name)
      check(part.Size.X >= 0.001 and part.Size.Y >= 0.001 and part.Size.Z >= 0.001, id .. " invalid dimensions")
      check(near(part.CFrame.RightVector.Magnitude, 1) and near(part.CFrame.UpVector.Magnitude, 1)
        and near(part.CFrame.RightVector:Dot(part.CFrame.UpVector), 0), id .. " invalid frame")
      if part.Name == "Spearhead" then table.insert(heads, part) end
      for _, x in { -1, 1 } do for _, y in { -1, 1 } do for _, z in { -1, 1 } do
        local p = part.CFrame.Position + part.CFrame:VectorToWorldSpace(vector(x * part.Size.X / 2, y * part.Size.Y / 2, z * part.Size.Z / 2))
        lo = vector(math.min(lo.X, p.X), math.min(lo.Y, p.Y), math.min(lo.Z, p.Z))
        hi = vector(math.max(hi.X, p.X), math.max(hi.Y, p.Y), math.max(hi.Z, p.Z))
      end end end
      if part ~= handle then
        local c, s, f = part.Color, part.Size, part.CFrame
        print(string.format("GEOMETRY|%s|%s|%s|%s|%.6f,%.6f,%.6f|%.6f,%.6f,%.6f|%.6f,%.6f,%.6f|%.6f,%.6f,%.6f|%.6f,%.6f,%.6f|%.6f,%.6f,%.6f",
          id, part.Name, part.ClassName, part.Shape or "Block", c.R,c.G,c.B, s.X,s.Y,s.Z,
          f.Position.X,f.Position.Y,f.Position.Z, f.RightVector.X,f.RightVector.Y,f.RightVector.Z,
          f.UpVector.X,f.UpVector.Y,f.UpVector.Z, f.ZVector.X,f.ZVector.Y,f.ZVector.Z))
      end
    elseif part.ClassName == "WeldConstraint" then
      check(part.Part0 == handle and part.Part1.Parent == tool, id .. " disconnected weld")
      check(not welds[part.Part1], id .. " duplicate weld")
      welds[part.Part1] = true
    end
  end
  check(#parts <= 65, id .. " exceeds the model part budget")
  for _, part in parts do check(part == handle or welds[part], id .. " loose part: " .. part.Name) end
  check(hi.Y - lo.Y < 5.8 and hi.Y > 3.3 and lo.Y > -2.4, id .. " changes the original reach")
  check(hi.X - lo.X < 1.6, id .. " head is too wide for existing previews")
  check(#heads == 4, id .. " needs four opposed blade quarters")
  -- On a WedgePart the high edge is local +Z. Both upper halves must
  -- terminate on X=0, rather than form the slanted chisel of the old model.
  local upperTips = 0
  for _, part in heads do
    local tip = part.CFrame.Position + part.CFrame:VectorToWorldSpace(vector(0, part.Size.Y / 2, part.Size.Z / 2))
    if tip.Y > 3.3 then
      upperTips += 1
      check(near(tip.X, 0) and near(tip.Z, 0), id .. " blade does not taper to its centerline")
    end
  end
  check(upperTips == 2, id .. " is missing its symmetric point")
  check(tool:FindFirstChild("Shaft").Shape == Enum.PartType.Cylinder, id .. " shaft must be round")
  check(tool:FindFirstChild("Grip") ~= nil, id .. " is missing its wrapped grip")
  print(string.format("%s: %d parts in one assembly; %.2f x %.2f studs", id, #parts, hi.X - lo.X, hi.Y - lo.Y))
end
local fresh, worn = Spears.build("Storm", 0), Spears.build("Storm", 1)
check(fresh:FindFirstChild("Shaft").Color.R ~= worn:FindFirstChild("Shaft").Color.R, "wear changes the finish")
check(fresh:FindFirstChild("HeadSocket").Reflectance > worn:FindFirstChild("HeadSocket").Reflectance, "wear dulls metal")
for _, invalid in { "", "missing" } do
  local tool = Spears.build(invalid)
  check(tool:FindFirstChild("Spearhead") ~= nil and tool:GetAttribute("SpearSkin") == nil, "unknown skin falls back to starter")
end
print(string.format("Spear model checks passed (%d assertions)", checks))
`;
  const target = join(folder, 'spears.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUAU || process.env.LUTE || 'lute',
    process.env.LUAU ? [target] : ['run', target], { cwd: root, encoding: 'utf8', timeout: 30000 });
  const lines = (result.stdout || '').split(/\r?\n/);
  const geometry = lines.filter(line => line.startsWith('GEOMETRY|'));
  process.stdout.write(lines.filter(line => !line.startsWith('GEOMETRY|')).join('\n'));
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Spear model checks failed (${result.status})`);
  const exportIndex = process.argv.indexOf('--geometry');
  if (exportIndex >= 0) {
    await writeFile(resolve(process.argv[exportIndex + 1]), JSON.stringify(geometry.map(line => {
      const [, skin, name, kind, shape, ...vectors] = line.split('|');
      const [color, size, position, right, up, back] = vectors.map(value => value.split(',').map(Number));
      return { skin, name, kind, shape, color, size, position, right, up, back };
    }), null, 2));
  }
} finally {
  if (dirname(resolve(folder)) !== resolve(tmpdir())) throw new Error('Unexpected temporary folder');
  await rm(folder, { recursive: true, force: true });
}
