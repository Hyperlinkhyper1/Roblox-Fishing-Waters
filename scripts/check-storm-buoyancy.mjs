// Exercise the shared parked transform with tall swells and real deck extents.
import { readFileSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const vectors = read('scripts/harbour-geometry.luau').split('local CFrame = {}')[0];
const mocks = read('scripts/drydock-geometry.luau').split('local function loadLowPoly()')[0]
  .replace('-- SHARED_PRIMITIVES --', () => vectors);
const program = mocks + `
function CFrame.fromAxisAngle(axis, angle)
  local function rotate(v)
    return v * math.cos(angle) + axis:Cross(v) * math.sin(angle) + axis * axis:Dot(v) * (1 - math.cos(angle))
  end
  return CFrame.fromMatrix(Vector3.zero, rotate(Vector3.xAxis), rotate(Vector3.yAxis), rotate(Vector3.zAxis))
end
workspace = Instance.new('Folder')
workspace:SetAttribute('WeatherEpoch', 0)
workspace:SetAttribute('WeatherSeed', 888)
workspace:SetAttribute('WeatherOverride', 'Storm')
local Weather = (function() ${read('src/shared/Weather.luau')} end)()
local checks = 0
local function check(value, message) checks += 1 assert(value, message) end
for _, deck in { { height = 0.4, beam = 3.25, length = 7.1 }, { height = 1.1, beam = 4.2, length = 10.85 } } do
 for _, newlyLaunched in { false, true } do
  for heading = 0, 7 do
    local time, position = 1000, Vector3.new(1500, 0, 0)
    local initial = Weather.sample(position, time)
    local flat = CFrame.Angles(0, heading * math.pi / 4, 0)
    local forward = (flat.LookVector - initial.normal * flat.LookVector:Dot(initial.normal)).Unit
    local right = forward:Cross(initial.normal).Unit
    local floor = deck.height * initial.normal.Y - math.abs(right.Y) * deck.beam - math.abs(forward.Y) * deck.length
    local surface = math.max(initial.height, 0.35 - floor)
    local rest = CFrame.fromMatrix(position + Vector3.new(0, surface - 0.4 * initial.normal.Y, 0), right, initial.normal, -forward)
    if newlyLaunched then rest = CFrame.new(position + Vector3.new(0, -0.4, 0)) * flat end
    local smallest, largest = math.huge, -math.huge
    for frame = 0, 1800 do
      local now = time + frame / 30
      local offset = Weather.parkedOffset(rest, time, now, deck.height, deck.beam, deck.length, Vector3.new(0, -0.4, 0))
      local pose = offset * rest
      if frame == 0 then check((pose.Position - rest.Position).Magnitude < 1e-6, 'Parking must begin at the existing pose') end
      smallest, largest = math.min(smallest, pose.Position.Y), math.max(largest, pose.Position.Y)
      for _, x in { -deck.beam, deck.beam } do
        for _, z in { -deck.length, deck.length } do
          local corner = pose:PointToWorldSpace(Vector3.new(x, deck.height + 0.4, z))
          check(corner.Y > 0.28, 'Parked deck must stay above the flat swimming surface during tall storm troughs: ' .. corner.Y)
        end
      end
      check(pose.UpVector.Y > 0.85, 'Tall seas must not overturn anchored hulls')
    end
    check(largest - smallest > 0.8, 'Dry-floor clearance must preserve visible swell motion')
  end
 end
end
print('PASS ' .. checks .. ' tall-storm parked-deck clearance, heading and continuous-motion checks')
`;
const directory = mkdtempSync(join(tmpdir(), 'storm-buoyancy-'));
try {
  const path = join(directory, 'checks.luau');
  writeFileSync(path, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', path], { encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} finally {
  rmSync(directory, { recursive: true, force: true });
}
