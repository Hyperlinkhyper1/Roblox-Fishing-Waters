// Exercise production catalog uniforms and shared rig finishing.
// Live asset rendering still needs Roblox Studio.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const source = await readFile(join(root, 'src/shared/StaffCatalog.luau'), 'utf8');
const harness = await readFile(join(root, 'scripts/shipwright-model.luau'), 'utf8');
const boundary = harness.indexOf('local function loadShipwright()');
if (boundary < 0) throw new Error('Missing Roblox mock boundary');
const mock = harness.slice(0, boundary);
const program = mock + '\nlocal Staff = (function()\n' + source + '\nend)()\n' + `
local checks = 0
local function check(value, message)
  checks += 1
  assert(value, message)
end
local seller, porter = Staff.description("Seller"), Staff.description("Porter")
check(seller.Shirt ~= porter.Shirt and seller.Pants ~= porter.Pants, "Roles have distinct, coordinated uniforms")
for _, role in Staff.Order do
  local description = Staff.description(role)
  check(description.Shirt > 0 and description.Pants > 0, "Each worker has real catalog clothing")
  check(description.HeadColor == description.LeftArmColor and description.LeftArmColor == description.RightArmColor,
    "Exposed skin uses one natural skin tone")
  check(description.BodyTypeScale == 0 and description.ProportionScale == 0 and description.HeightScale == 1,
    "Workers share standard classic R15 proportions")
  local shirt = description.Shirt
  description.Shirt = 0
  description:Destroy()
  check(Staff.description(role).Shirt == shirt, "Callers own independent descriptions")
  local model, head = Instance.new("Model"), Instance.new("Part")
  head.Name, head.Parent = "Head", model
  Staff.finishModel(model)
  local face = head:FindFirstChild("face")
  check(face and face.Texture == "rbxasset://textures/face.png", "Workers show the built-in friendly face")
  Staff.finishModel(model)
  check(head:FindFirstChild("face") == face and #head.children == 1, "Finishing a rig does not duplicate its face")
end
check(seller.HairAccessory ~= "" and seller.HatAccessory == "", "Seller wears neat hair without overlapping headwear")
check(porter.HatAccessory ~= "" and porter.HairAccessory == "", "Porter wears a work beanie without hair clipping")
check(not pcall(Staff.description, "Unknown"), "Unknown roles are rejected")
print("Staff appearance: " .. checks .. " uniform and rig checks passed (Roblox doubles).")
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
