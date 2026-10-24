// Exercise production uniforms with the existing recording Roblox mock.
// Covers construction and attachment safety; rendering needs Roblox Studio.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const harness = await readFile(join(root, 'scripts/shipwright-model.luau'), 'utf8');
const boundary = harness.indexOf('local function loadShipwright()');
if (boundary < 0) throw new Error('Missing Roblox mock boundary');
const mock = harness.slice(0, boundary).replace(
  'return vector(a.X * b, a.Y * b, a.Z * b)',
  'if type(b) == "table" then return vector(a.X * b.X, a.Y * b.Y, a.Z * b.Z) end\n\treturn vector(a.X * b, a.Y * b, a.Z * b)',
);
const source = await readFile(join(root, 'src/shared/StaffCatalog.luau'), 'utf8');
const program = mock + '\nlocal Staff = (function()\n' + source + '\nend)()\n' + `
local checks = 0
local function check(value, message)
  checks += 1
  assert(value, message)
end
for _, role in Staff.Order do
  for _, scale in { 1, 1.3 } do
    local model = Instance.new("Model")
    function model:GetChildren() return self.children end
    local names = { "HumanoidRootPart", "Head", "UpperTorso", "LowerTorso" }
    for _, side in { "Left", "Right" } do
      for _, limb in { "UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot" } do
        table.insert(names, side .. limb)
      end
    end
    for _, name in names do
      local part = Instance.new("Part")
      part.Name = name
      part.Size = Vector3.new(2, 1, 1) * scale
      part.CFrame = CFrame.new(20, 5, -10) * CFrame.Angles(0, math.pi / 2, 0)
      part.Parent = model
    end
    local root = model:FindFirstChild("HumanoidRootPart")
    root.Transparency = 1
    local description = Staff.description(role)
    check(description.HeadColor[1] > 0 and description.LeftArmColor[1] > 0, "Explicit skin tones")
    Staff.applyAppearance(model, role)
    check(root.Color == nil and root.Transparency == 1, "Invisible root preserved")
    check(model:FindFirstChild("Head").Color == description.HeadColor, "Head matches avatar description")
    check(model:FindFirstChild("LeftHand").Color == description.LeftArmColor, "Hands retain skin tone")
    check(model:FindFirstChild("LeftUpperLeg").Color == description.LeftLegColor, "Trousers match avatar description")
    local face = model:FindFirstChild("Head"):FindFirstChild("face")
    check(face and face.Texture == "rbxasset://textures/face.png", "Readable built-in face")
    local uniform = model:FindFirstChild("StaffUniform")
    local parts = 0
    for _, part in uniform.children do
      parts += 1
      check(not part.Anchored and part.Massless, "Uniform must not anchor or weigh down worker")
      check(not part.CanCollide and not part.CanTouch and not part.CanQuery, "Uniform cannot block gameplay")
      local weld = part:FindFirstChildOfClass("WeldConstraint")
      check(weld and weld.Part1 == part and weld.Part0.Parent == model, "Every detail follows a body joint")
      check(part.Size.X > 0 and part.Size.Y > 0 and part.Size.Z > 0, "Valid scaled dimensions")
    end
    check(parts > 0, "Role has visible clothing")
    check(uniform:FindFirstChild(if role == "Seller" then "ApronBib" else "WorkVest") ~= nil, "Distinct role outfit")
    Staff.applyAppearance(model, role)
    check(model:FindFirstChild("Head"):FindFirstChild("face") == face, "Preserve existing face")
    local count = 0
    for _, child in model.children do
      if child.Name == "StaffUniform" then count += 1 end
    end
    check(count == 1 and #model:FindFirstChild("StaffUniform").children == parts, "Reapplying does not duplicate clothing")
  end
end
check(not pcall(Staff.description, "Unknown"), "Reject unknown roles")
print("Staff appearance: " .. checks .. " construction checks passed (Roblox doubles).")
`;
const folder = await mkdtemp(join(tmpdir(), 'staff-appearance-'));
try {
  const target = join(folder, 'appearance.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Staff appearance checks failed');
} finally {
  await rm(folder, { recursive: true, force: true });
}
