// Exercise production camera fitting and pointer rays with recording Roblox math mocks.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = name => readFile(join(root, name), 'utf8');
const source = await read('src/client/BuildMode.luau');
function section(start, end) {
  const first = source.indexOf(start);
  const last = source.indexOf(end, first);
  if (first < 0 || last < 0) throw new Error(`Missing build camera section: ${start}`);
  return source.slice(first, last);
}
const primitives = (await read('scripts/harbour-geometry.luau')).split('local CFrame = {}')[0];
const frames = (await read('scripts/drydock-geometry.luau')).split('local function typeof')[0]
  .replace('-- SHARED_PRIMITIVES --', primitives);
const program = `${frames}
local Enum = {CameraType = {Scriptable = "Scriptable"}, FieldOfViewMode = {Vertical = "Vertical"}}
local workspace = {}
local panel = {}
local inset = 0
local game = {GetService = function() return {GetGuiInset = function() return Vector2.new(0, inset) end} end}
local houseFrame = CFrame.identity
local FLOOR_Y = 0.16
local Furniture = {GRID = 0.5}
${section('\tlocal function updateCamera()', '\n\tlocal exit')}
${section('\tlocal function pointerSpot(', '\n\tlocal function aim(')}
local checks = 0
for _, size in {{1920, 1080}, {1280, 720}, {844, 390}, {390, 844}, {640, 360}} do
  for _, topInset in {0, 36, 58} do
    for _, rotation in {0, math.pi / 2, math.pi, math.pi * 1.5} do
      inset = topInset
      panel.AbsolutePosition = Vector2.new(12, size[2] - inset - 202)
      houseFrame = CFrame.new(120, 6, -75) * CFrame.Angles(0, rotation, 0)
      -- Replacing CurrentCamera between calls must still update the new instance.
      local camera = {ViewportSize = Vector2.new(size[1], size[2]), FieldOfView = 70}
      workspace.CurrentCamera = camera
      updateCamera()
      assert(camera.CameraType == "Scriptable" and camera.FieldOfView == 50, "Camera ownership lost")
      assert(camera.FieldOfViewMode == "Vertical", "Camera fit must use vertical FOV")
      assert(camera.CFrame.LookVector:Dot(-houseFrame.UpVector) > 0.99999, "Camera must look straight down")
      local focal = size[2] / (2 * math.tan(math.rad(camera.FieldOfView / 2)))
      for _, x in {-23, 23} do
        for _, z in {-15, 15} do
          local corner = houseFrame * Vector3.new(x, FLOOR_Y, z)
          local localPoint = camera.CFrame:PointToObjectSpace(corner)
          local sx = size[1] / 2 + focal * localPoint.X / -localPoint.Z
          local sy = size[2] / 2 - focal * localPoint.Y / -localPoint.Z
          assert(sx >= 0 and sx <= size[1], "House cropped horizontally")
          assert(sy >= inset + 12 and sy <= panel.AbsolutePosition.Y + inset - 12, "House hidden by bar or top inset")
          checks += 1
        end
      end
      function camera:ScreenPointToRay(x, y)
        local direction = self.CFrame:VectorToWorldSpace(Vector3.new((x - size[1] / 2) / focal, -(y - inset - size[2] / 2) / focal, -1))
        return {Origin = self.CFrame.Position, Direction = direction.Unit}
      end
      local point = houseFrame * Vector3.new(8.5, FLOOR_Y, 6)
      local localPoint = camera.CFrame:PointToObjectSpace(point)
      local screen = Vector2.new(size[1] / 2 + focal * localPoint.X / -localPoint.Z,
        inset + size[2] / 2 - focal * localPoint.Y / -localPoint.Z)
      local x, z = pointerSpot(screen)
      assert(x == 8.5 and z == 6, "Placement ray misses pointed floor tile")
      checks += 1
    end
  end
end
workspace.CurrentCamera = nil
updateCamera()
assert(pointerSpot(Vector2.zero) == nil, "Missing camera should be harmless")
print("Build camera: " .. checks .. " framing and pointer checks passed across viewports, insets, rotations and camera replacement (no Studio rendering).")
-- Parse the complete module as well as the exercised functions.
local function parseBuildMode()
${source}
end
`;
const folder = await mkdtemp(join(tmpdir(), 'build-camera-'));
try {
  const target = join(folder, 'camera.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], {cwd: root, encoding: 'utf8', timeout: 30000});
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Build camera checks failed (${result.status})`);
} finally {
  await rm(folder, {recursive: true, force: true});
}
