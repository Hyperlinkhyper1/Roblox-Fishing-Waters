// Builds the real SharkModel against recording mocks and checks its geometry: no Ball parts (Roblox
// forces those to spheres), smooth mesh ellipsoids, sane frames, the swim segments SharkSwim bends,
// the overall size the spear hit volume assumes, and the dorsal fin breaking the surface.
// It also builds SharkShape's mesh skin (what clients render with EditableMesh) and checks its
// swim segments, jaw, normals, winding and size. Pass --preview <file.png> to rasterize side,
// top, three-quarter, open-jaw and mid-stroke views of the skin with the surface details, or add
// --fallback to see the ellipsoid stand-in instead. Geometry only, not Roblox rendering.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { deflateSync } from 'node:zlib';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const previewIndex = process.argv.indexOf('--preview');
const previewPath = previewIndex > 0 ? resolve(process.argv[previewIndex + 1]) : null;
const fallbackView = process.argv.includes('--fallback');
const shape = await readFile(join(root, 'src/shared/SharkShape.luau'), 'utf8');
const requireShape = /local ReplicatedStorage = game:GetService\("ReplicatedStorage"\)\r?\nlocal SharkShape = require\(ReplicatedStorage:WaitForChild\("Shared"\)\.SharkShape\)/;
const modelSource = await readFile(join(root, 'src/server/SharkModel.luau'), 'utf8');
if (!requireShape.test(modelSource)) throw new Error('SharkModel no longer requires SharkShape the expected way');
const source = modelSource.replace(requireShape, () => 'local SharkShape = SHARK_SHAPE');

const program = String.raw`
local checks = 0
local function check(value, message) checks += 1; if not value then error(message, 2) end end

local V3 = {}
local function v3(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end
local v3methods = {}
V3.__index = function(a, key)
  if key == "Magnitude" then return math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z) end
  if key == "Unit" then local m = math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z); return v3(a.X / m, a.Y / m, a.Z / m) end
  return v3methods[key]
end
V3.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3.__mul = function(a, b)
  if type(a) == "number" then return v3(b.X * a, b.Y * a, b.Z * a) end
  if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
  return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b) return v3(a.X / b, a.Y / b, a.Z / b) end
function v3methods:Dot(b) return self.X * b.X + self.Y * b.Y + self.Z * b.Z end
function v3methods:Cross(b) return v3(self.Y * b.Z - self.Z * b.Y, self.Z * b.X - self.X * b.Z, self.X * b.Y - self.Y * b.X) end
local Vector3 = { new = v3 }

local CF = {}
local function cf(p, x, y, z) return setmetatable({ Position = p, x = x, y = y, z = z }, CF) end
CF.__index = function(c, key)
  if key == "Rotation" then return cf(v3(), c.x, c.y, c.z) end
end
local function rotate(c, v) return c.x * v.X + c.y * v.Y + c.z * v.Z end
CF.__mul = function(a, b)
  if getmetatable(b) == V3 then return a.Position + rotate(a, b) end
  return cf(a.Position + rotate(a, b.Position), rotate(a, b.x), rotate(a, b.y), rotate(a, b.z))
end
local CFrame = {}
local X, Y, Z = v3(1, 0, 0), v3(0, 1, 0), v3(0, 0, 1)
function CFrame.new(x, y, z)
  if type(x) == "table" then return cf(x, X, Y, Z) end
  return cf(v3(x or 0, y or 0, z or 0), X, Y, Z)
end
function CFrame.fromMatrix(p, x, y, z) return cf(p, x, y, z or x:Cross(y)) end
local function axis(kind, t)
  local c, s = math.cos(t), math.sin(t)
  if kind == "x" then return cf(v3(), v3(1, 0, 0), v3(0, c, s), v3(0, -s, c)) end
  if kind == "y" then return cf(v3(), v3(c, 0, -s), v3(0, 1, 0), v3(s, 0, c)) end
  return cf(v3(), v3(c, s, 0), v3(-s, c, 0), v3(0, 0, 1))
end
function CFrame.Angles(rx, ry, rz) return axis("x", rx) * axis("y", ry) * axis("z", rz) end
local function near(a, b) return (a.Position - b.Position).Magnitude < 1e-6 and (a.x - b.x).Magnitude < 1e-6
  and (a.y - b.y).Magnitude < 1e-6 and (a.z - b.z).Magnitude < 1e-6 end

local Color3 = { fromRGB = function(r, g, b) return { R = r, G = g, B = b } end }
local Enum = setmetatable({}, { __index = function(_, group)
  return setmetatable({}, { __index = function(_, item) return group .. "." .. item end })
end })

local Instance = {}
function Instance.new(kind)
  local object = { ClassName = kind, children = {}, attributes = {}, Transparency = 0, CFrame = CFrame.new() }
  function object:SetAttribute(key, value) self.attributes[key] = value end
  function object:GetAttribute(key) return self.attributes[key] end
  function object:PivotTo(target)
    local inverse = self.PrimaryPart.CFrame
    check(near(inverse, CFrame.new()), "The model is built around an identity root")
    for _, child in self.children do child.CFrame = target * child.CFrame end
  end
  return setmetatable(object, { __newindex = function(t, key, value)
    rawset(t, key, value)
    if key == "Parent" and value then table.insert(value.children, t) end
  end })
end

local SHARK_SHAPE = (function()
${shape}
end)()
local SharkModel = (function()
${source}
end)()

local folder = Instance.new("Folder")
local spawn = CFrame.new(40, 0.5, -20) * CFrame.Angles(0, 0.7, 0)
local shark = SharkModel.build(folder, spawn)
check(shark.Parent == folder and shark.Name == "Shark", "The shark is published into the given folder")
check(shark.ModelStreamingMode == "ModelStreamingMode.Atomic", "The shark streams atomically")
local root = shark.PrimaryPart
check(root and root.Name == "Root" and root.Transparency == 1 and root.Parent == shark, "An invisible root is the primary part")
check(near(root.CFrame, spawn), "The root is pivoted to the spawn frame")

local parts, segments = {}, {}
local SCALE = SHARK_SHAPE.SCALE
local JOINT_COUNT = #SHARK_SHAPE.JOINTS
local lo, hi = v3(math.huge, math.huge, math.huge), v3(-math.huge, -math.huge, -math.huge)
for _, p in shark.children do
  check(p.ClassName == "Part" or p.ClassName == "WedgePart", p.Name .. " is a part")
  check(p.Shape == nil, p.Name .. " must not use a Ball shape (Roblox makes every Ball a sphere)")
  check(p.CanCollide == false and p.CanTouch == false and p.CanQuery == false and p.Anchored, p.Name .. " is anchored and inert")
  if p == root then continue end
  table.insert(parts, p)
  if p.ClassName == "Part" then
    local mesh = p.children[1]
    check(mesh and mesh.ClassName == "SpecialMesh" and mesh.MeshType == "MeshType.Sphere", p.Name .. " is a mesh ellipsoid")
  end
  local offset = p:GetAttribute("SwimOffset")
  check(offset and near(p.CFrame, spawn * offset), p.Name .. " stores its offset from the root")
  local segment = p:GetAttribute("SwimSegment")
  check(type(segment) == "number" and segment >= 0 and segment <= JOINT_COUNT, p.Name .. " has a swim segment")
  check(segment == SHARK_SHAPE.segmentAt(offset.Position.Z / SCALE), p.Name .. " rides the segment it sits in")
  segments[segment] = (segments[segment] or 0) + 1
  local size = p.Size
  check(size.X > 0 and size.Y > 0 and size.Z > 0, p.Name .. " has a positive size")
  for _, pair in { { offset.x, offset.y }, { offset.y, offset.z }, { offset.z, offset.x } } do
    check(math.abs(pair[1]:Dot(pair[2])) < 1e-6, p.Name .. " has perpendicular axes")
  end
  check(math.abs(offset.x:Cross(offset.y):Dot(offset.z) - 1) < 1e-6, p.Name .. " has a right-handed unit frame")
  local zlo, zhi = math.huge, -math.huge
  for _, sx in { -0.5, 0.5 } do for _, sy in { -0.5, 0.5 } do for _, sz in { -0.5, 0.5 } do
    -- Ellipsoids fill about half of their box; the box is fine for extents of fins and the body.
    local scale = if p.ClassName == "Part" then 0.82 else 1
    local corner = offset * v3(size.X * sx * scale, size.Y * sy * scale, size.Z * sz * scale)
    lo = v3(math.min(lo.X, corner.X), math.min(lo.Y, corner.Y), math.min(lo.Z, corner.Z))
    hi = v3(math.max(hi.X, corner.X), math.max(hi.Y, corner.Y), math.max(hi.Z, corner.Z))
    zlo, zhi = math.min(zlo, corner.Z), math.max(zhi, corner.Z)
  end end end
  if PREVIEW then
    local c = offset
    print(string.format("PART %s|%s|%s|%.4f,%.4f,%.4f|%.4f,%.4f,%.4f|%.4f,%.4f,%.4f|%.4f,%.4f,%.4f|%.4f,%.4f,%.4f|%d,%d,%d",
      p.ClassName, segment, if p:GetAttribute("SharkFallback") then "fallback" else "detail", size.X, size.Y, size.Z, c.Position.X, c.Position.Y, c.Position.Z,
      c.x.X, c.x.Y, c.x.Z, c.y.X, c.y.Y, c.y.Z, c.z.X, c.z.Y, c.z.Z, p.Color.R, p.Color.G, p.Color.B))
  end
end
print(string.format("Stand-in: %.2f long (snout %.2f, tail %.2f), %.2f wide, %.2f to %.2f high, %d parts",
  hi.Z - lo.Z, lo.Z, hi.Z, hi.X - lo.X, lo.Y, hi.Y, #parts))
check(#parts <= 90, "Keep the replicated part count modest: " .. #parts)
check(segments[0] and segments[JOINT_COUNT], "The head and the tail segment both carry pieces")
check(lo.Z < -5 * SCALE and hi.Z > 5.5 * SCALE and hi.Z - lo.Z < 13 * SCALE, "The shark is about twelve design units long, snout towards -Z")
check(hi.X - lo.X > 6 * SCALE and hi.X - lo.X < 8 * SCALE, "Pectoral fins span six to eight design units")
check(hi.Y > 1.2 * SCALE, "The dorsal fin and tail lobe break the surface")
check(lo.Y < -2.8 * SCALE, "The lower tail lobe reaches well below the body")
local fallbackCount = 0
for _, p in parts do if p:GetAttribute("SharkFallback") then fallbackCount += 1 end end
check(fallbackCount > 20 and fallbackCount < #parts, "Body and fins are tagged as the fallback; details are not")

-- The mesh skin clients build.
local meshes = SHARK_SHAPE.build()
check(#meshes == (JOINT_COUNT + 1) * 3 + 3, "Three colour bands per swim segment, the mouth roof and two jaw meshes")
local ranges = {}
for _, segment in SHARK_SHAPE.SEGMENTS do ranges[segment.index] = segment end
local jawMeshes, roofMeshes = 0, 0
local totalTriangles = 0
local mlo, mhi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
for _, mesh in meshes do
  local label = mesh.segment .. "/" .. mesh.band .. (if mesh.jaw then "/jaw" else "")
  if mesh.jaw then jawMeshes += 1 end
  if mesh.band == "Mouth" and not mesh.jaw then roofMeshes += 1 end
  local range = ranges[mesh.segment]
  check(range ~= nil, label .. " belongs to a swim segment")
  check(SHARK_SHAPE.COLORS[mesh.band] ~= nil, label .. " has a palette colour")
  check(#mesh.triangles > 50, label .. " has triangles")
  check(#mesh.positions == #mesh.normals, label .. " has one normal per vertex")
  totalTriangles += #mesh.triangles
  for index, p in mesh.positions do
    local n = mesh.normals[index]
    for axis = 1, 3 do
      check(p[axis] == p[axis] and math.abs(p[axis]) < 20, label .. " positions are finite")
      mlo[axis], mhi[axis] = math.min(mlo[axis], p[axis]), math.max(mhi[axis], p[axis])
    end
    check(math.abs(n[1] * n[1] + n[2] * n[2] + n[3] * n[3] - 1) < 1e-6, label .. " normals are unit length")
    -- Fins hang off their segment a little; nothing reaches far past a neighbour.
    local z = p[3] / SCALE
    check(z > range.low - 1.6 and z < range.high + 1.6, label .. " stays around its segment")
    if mesh.jaw then check(z < -2.5 and z > -4.3 and p[2] / SCALE < -1.6, label .. " sits under the head") end
  end
  for _, tri in mesh.triangles do
    local a, b, c = mesh.positions[tri[1]], mesh.positions[tri[2]], mesh.positions[tri[3]]
    local e1 = { b[1] - a[1], b[2] - a[2], b[3] - a[3] }
    local e2 = { c[1] - a[1], c[2] - a[2], c[3] - a[3] }
    local face = { e1[2] * e2[3] - e1[3] * e2[2], e1[3] * e2[1] - e1[1] * e2[3], e1[1] * e2[2] - e1[2] * e2[1] }
    local sum = { 0, 0, 0 }
    for _, v in tri do for axis = 1, 3 do sum[axis] += mesh.normals[v][axis] end end
    check(face[1] * sum[1] + face[2] * sum[2] + face[3] * sum[3] > 0, label .. " triangles are wound outward")
  end
  if PREVIEW then
    print("MESH " .. mesh.segment .. " " .. mesh.band .. " " .. (if mesh.jaw then "jaw" else "body"))
    for index, p in mesh.positions do
      local n = mesh.normals[index]
      print(string.format("V %.4f,%.4f,%.4f,%.4f,%.4f,%.4f", p[1], p[2], p[3], n[1], n[2], n[3]))
    end
    for _, tri in mesh.triangles do print(string.format("T %d,%d,%d", tri[1], tri[2], tri[3])) end
  end
end
-- Hull normals point away from the body axis (bands without fins or teeth;
-- the recessed roof of the mouth faces down into the mouth instead).
local inward = 0
for _, hull in meshes do
  if hull.band ~= "Back" and hull.band ~= "Mouth" and not hull.jaw and not (hull.band == "Belly" and hull.segment == 0) then
    for index, world in hull.positions do
      local p = { world[1] / SCALE, world[2] / SCALE, world[3] / SCALE }
      if math.abs(p[1]) > 0.05 and p[3] > -5.4 then
        local _, _, _, axis = SHARK_SHAPE.section(p[3])
        local n = hull.normals[index]
        if n[1] * p[1] + n[2] * (p[2] - axis) < 0 then inward += 1 end
      end
    end
  end
end
check(inward == 0, "Hull normals face outward: " .. inward .. " point inward")
check(jawMeshes == 2 and roofMeshes == 1, "One mouth roof and a two-part jaw")
check(totalTriangles < 20000, "Keep the skin's triangle count modest: " .. totalTriangles)
check(mlo[3] < -5.4 * SCALE and mhi[3] > 6 * SCALE and mhi[3] - mlo[3] < 13 * SCALE, "The skin is about twelve design units long")
check(mhi[1] - mlo[1] > 6.5 * SCALE and mhi[1] - mlo[1] < 8 * SCALE, "Skin pectoral fins span six and a half to eight design units")
check(mhi[2] > 1.2 * SCALE and mlo[2] < -2.8 * SCALE, "The skin's dorsal fin breaks the surface and the lower lobe hangs deep")
-- The joints sit on the body axis from front to back; the jaw hinge is above the mouth's back edge.
local joints = SHARK_SHAPE.joints()
for index, joint in joints do
  check(joint.amplitude > 0 and joint.amplitude < 0.5, "Joint " .. index .. " bends a sane amount")
  if index > 1 then check(joint.pivot[3] > joints[index - 1].pivot[3] and joint.amplitude >= joints[index - 1].amplitude, "Joints run head to tail, stronger towards the tail") end
  if PREVIEW then print(string.format("JOINT %.4f,%.4f,%.4f,%.4f,%.4f", joint.pivot[1], joint.pivot[2], joint.pivot[3], joint.amplitude, joint.lag)) end
end
local hinge = SHARK_SHAPE.jawPivot()
check(hinge[3] / SCALE > -3.2 and hinge[3] / SCALE < -2.5, "The jaw hinges just behind the mouth")
if PREVIEW then print(string.format("JAW %.4f,%.4f,%.4f,%.4f", hinge[1], hinge[2], hinge[3], SHARK_SHAPE.JAW_OPEN)) end
print(string.format("Skin: %d triangles in %d meshes, %.2f studs long, %.2f wide, %.2f to %.2f high",
  totalTriangles, #meshes, mhi[3] - mlo[3], mhi[1] - mlo[1], mlo[2], mhi[2]))
print("Shark model: " .. checks .. " geometry checks passed (recording mocks).")
`;

const folder = await mkdtemp(join(tmpdir(), 'fishing-shark-model-'));
try {
  const target = join(folder, 'checks.luau');
  await writeFile(target, `local PREVIEW = ${previewPath ? 'true' : 'false'}\n` + program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { encoding: 'utf8', maxBuffer: 1 << 26 });
  const lines = ((result.stdout || '') + (result.stderr || '')).split(/\r?\n/);
  const isData = line => /^(PART|MESH|V|T|JOINT|JAW) /.test(line);
  console.log(lines.filter(line => !isData(line)).join('\n').trim());
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status || 1);
  if (previewPath) await writePreview(lines.filter(isData));
} finally {
  await rm(folder, { recursive: true, force: true });
}

// Z-buffered rasterizer for the skin triangles and the surface-detail parts (ellipsoids and
// wedges tessellated), with smooth shading, a highlight and water tinting below y = 0.
async function writePreview(dataLines) {
  const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
  const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
  const add = (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
  const scale = (a, s) => [a[0] * s, a[1] * s, a[2] * s];
  const norm = a => scale(a, 1 / (Math.hypot(...a) || 1));
  const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
  const palette = { Back: [66, 78, 88], Line: [142, 149, 151], Belly: [228, 229, 223], Mouth: [92, 32, 40] };
  for (const name of Object.keys(palette)) {
    const match = shape.match(new RegExp(name + ' = \\{ (\\d+), (\\d+), (\\d+) \\}'));
    if (match) palette[name] = match.slice(1).map(Number);
  }
  // Triangles: { p: [a, b, c], n: [na, nb, nc], color, segment }.
  const triangles = [];
  const joints = [];
  let jawHinge = null;
  let mesh = null;
  const flushMesh = () => {
    if (!mesh) return;
    for (const [a, b, c] of mesh.tris) {
      triangles.push({ p: [mesh.v[a - 1].p, mesh.v[b - 1].p, mesh.v[c - 1].p], n: [mesh.v[a - 1].n, mesh.v[b - 1].n, mesh.v[c - 1].n], color: palette[mesh.band], segment: mesh.segment, jaw: mesh.jaw });
    }
  };
  for (const line of dataLines) {
    if (line.startsWith('MESH ')) {
      flushMesh();
      const [, segment, band, kind] = line.split(' ');
      mesh = fallbackView ? null : { segment: Number(segment), band, jaw: kind === 'jaw', v: [], tris: [] };
    } else if (line.startsWith('JOINT ')) {
      const f = line.slice(6).split(',').map(Number);
      joints.push({ pivot: f.slice(0, 3), amplitude: f[3], lag: f[4] });
    } else if (line.startsWith('JAW ')) {
      const f = line.slice(4).split(',').map(Number);
      jawHinge = { pivot: f.slice(0, 3), open: f[3] };
    } else if (line.startsWith('V ') && mesh) {
      const f = line.slice(2).split(',').map(Number);
      mesh.v.push({ p: f.slice(0, 3), n: f.slice(3, 6) });
    } else if (line.startsWith('T ') && mesh) {
      mesh.tris.push(line.slice(2).split(',').map(Number));
    } else if (line.startsWith('PART ')) {
      const [kind, segmentText, role, ...fields] = line.slice(5).split('|');
      const segment = Number(segmentText);
      if (role === 'fallback' && !fallbackView) continue;
      const [size, position, x, y, z, color] = fields.map(field => field.split(',').map(Number));
      const half = size.map(v => v / 2), axes = [x, y, z];
      const world = l => add(position, add(add(scale(x, l[0]), scale(y, l[1])), scale(z, l[2])));
      const worldN = l => norm(add(add(scale(x, l[0]), scale(y, l[1])), scale(z, l[2])));
      if (kind === 'Part') {
        const rows = 14, cols = 22, grid = [];
        for (let i = 0; i <= rows; i++) {
          const row = [];
          for (let j = 0; j <= cols; j++) {
            const th = Math.PI * i / rows, ph = 2 * Math.PI * j / cols;
            const u = [Math.sin(th) * Math.cos(ph), Math.cos(th), Math.sin(th) * Math.sin(ph)];
            row.push({ p: world(u.map((c, k) => c * half[k])), n: worldN(u.map((c, k) => c / half[k])) });
          }
          grid.push(row);
        }
        for (let i = 0; i < rows; i++) for (let j = 0; j < cols; j++) {
          const a = grid[i][j], b = grid[i + 1][j], c = grid[i + 1][j + 1], d = grid[i][j + 1];
          triangles.push({ p: [a.p, b.p, c.p], n: [a.n, b.n, c.n], color, segment });
          triangles.push({ p: [a.p, c.p, d.p], n: [a.n, c.n, d.n], color, segment });
        }
      } else {
        const [hx, hy, hz] = half;
        const A = [-hx, -hy, -hz], B = [hx, -hy, -hz], C = [-hx, -hy, hz], D = [hx, -hy, hz], E = [-hx, hy, hz], F = [hx, hy, hz];
        const quad = (q, n) => {
          const pts = q.map(world), nn = worldN(n);
          triangles.push({ p: [pts[0], pts[1], pts[2]], n: [nn, nn, nn], color, segment });
          if (pts[3]) triangles.push({ p: [pts[0], pts[2], pts[3]], n: [nn, nn, nn], color, segment });
        };
        quad([A, B, D, C], [0, -1, 0]); quad([C, D, F, E], [0, 0, 1]);
        quad([A, B, F, E], [0, 1 / hy, -1 / hz]); quad([A, C, E], [-1, 0, 0]); quad([B, D, F], [1, 0, 0]);
      }
    }
  }
  flushMesh();
  // Bend each joint about its pivot (tail-most first) and open the jaw, as SharkSwim does.
  const yawAbout = (v, pivotPoint, yaw) => {
    const c = Math.cos(yaw), s = Math.sin(yaw);
    const r = q => [c * q[0] + s * q[2], q[1], -s * q[0] + c * q[2]];
    return { p: add(pivotPoint, r(sub(v.p, pivotPoint))), n: r(v.n) };
  };
  const pitchAbout = (v, pivotPoint, angle) => {
    const c = Math.cos(angle), s = Math.sin(angle);
    const r = q => [q[0], c * q[1] - s * q[2], s * q[1] + c * q[2]];
    return { p: add(pivotPoint, r(sub(v.p, pivotPoint))), n: r(v.n) };
  };
  const posed = (tri, wave, jawOpen) => {
    const out = { ...tri, p: [], n: [] };
    for (let k = 0; k < 3; k++) {
      let v = { p: tri.p[k], n: tri.n[k] };
      if (tri.jaw && jawHinge) v = pitchAbout(v, jawHinge.pivot, -jawOpen);
      for (let j = wave === null ? 0 : Math.min(tri.segment || 0, joints.length); j >= 1; j--) {
        const joint = joints[j - 1];
        v = yawAbout(v, joint.pivot, Math.sin(wave - joint.lag) * joint.amplitude * 1.4);
      }
      out.p.push(v.p); out.n.push(v.n);
    }
    return out;
  };
  const S = Number((shape.match(/SharkShape\.SCALE = ([\d.]+)/) || [0, 1])[1]);
  const views = [
    { title: 'side', forward: [1, 0, 0], up: [0, 1, 0], center: [0, -0.9 * S, 0.4 * S], zoom: 34 / S },
    { title: 'top', forward: [0, -1, 0], up: [0, 0, -1], center: [0, 0, 0.4 * S], zoom: 34 / S },
    { title: 'front three-quarter, hunting', forward: [0.75, -0.45, 1], up: [0, 1, 0], center: [0, -1.1 * S, 0.2 * S], zoom: 34 / S, jaw: 0.3 },
    { title: 'head, jaw closed', forward: [0.8, 0.2, 0.75], up: [0, 1, 0], center: [0, -1.7 * S, -3.6 * S], zoom: 80 / S },
    { title: 'head, biting (jaw wide)', forward: [0.8, 0.2, 0.75], up: [0, 1, 0], center: [0, -2 * S, -3.6 * S], zoom: 80 / S, jaw: 1 },
    { title: 'top mid-stroke', forward: [0, -1, 0], up: [0, 0, -1], center: [0, 0, 0.4 * S], zoom: 34 / S, wave: 2.4 },
  ];
  const ss = 2, panel = 480, panelHeight = Math.round(panel * 0.68);
  const width = panel * 2, height = panelHeight * 3;
  const image = Buffer.alloc(width * height * 3);
  const light = norm([-0.4, 1, -0.5]);
  views.forEach((view, index) => {
    const jawOpen = view.jaw === 1 && jawHinge ? jawHinge.open : (view.jaw || 0);
    const tris = view.wave || jawOpen ? triangles.map(t => posed(t, view.wave ?? null, jawOpen)) : triangles;
    const forward = norm(view.forward), right = norm(cross(forward, view.up)), up = cross(right, forward);
    const W = panel * ss, H = panelHeight * ss, k = view.zoom * ss;
    const depth = new Float64Array(W * H).fill(Infinity);
    const color = new Float64Array(W * H * 3);
    for (let i = 0; i < W * H; i++) color.set([196, 214, 226], i * 3);
    const project = p => { const d = sub(p, view.center); return [W / 2 + dot(d, right) * k, H / 2 - dot(d, up) * k, dot(d, forward)]; };
    const halfway = norm(sub(light, forward));
    for (const tri of tris) {
      const s = tri.p.map(project);
      const minX = Math.max(0, Math.floor(Math.min(s[0][0], s[1][0], s[2][0]))), maxX = Math.min(W - 1, Math.ceil(Math.max(s[0][0], s[1][0], s[2][0])));
      const minY = Math.max(0, Math.floor(Math.min(s[0][1], s[1][1], s[2][1]))), maxY = Math.min(H - 1, Math.ceil(Math.max(s[0][1], s[1][1], s[2][1])));
      const area = (s[1][0] - s[0][0]) * (s[2][1] - s[0][1]) - (s[2][0] - s[0][0]) * (s[1][1] - s[0][1]);
      if (Math.abs(area) < 1e-9) continue;
      for (let py = minY; py <= maxY; py++) for (let px = minX; px <= maxX; px++) {
        const x = px + 0.5, y = py + 0.5;
        const w0 = ((s[1][0] - x) * (s[2][1] - y) - (s[2][0] - x) * (s[1][1] - y)) / area;
        const w1 = ((s[2][0] - x) * (s[0][1] - y) - (s[0][0] - x) * (s[2][1] - y)) / area;
        const w2 = 1 - w0 - w1;
        if (w0 < 0 || w1 < 0 || w2 < 0) continue;
        const z = w0 * s[0][2] + w1 * s[1][2] + w2 * s[2][2];
        const at = py * W + px;
        if (z >= depth[at]) continue;
        depth[at] = z;
        let n = norm(add(add(scale(tri.n[0], w0), scale(tri.n[1], w1)), scale(tri.n[2], w2)));
        if (dot(n, forward) > 0) n = scale(n, -1);
        const diffuse = Math.max(0, dot(n, light));
        const spec = Math.pow(Math.max(0, dot(n, halfway)), 40) * 0.25;
        let c = tri.color.map(v => v * (0.38 + 0.62 * diffuse) + 255 * spec);
        const world = add(add(scale(tri.p[0], w0), scale(tri.p[1], w1)), scale(tri.p[2], w2));
        if (world[1] < 0 && forward[1] < -0.1) {
          const keep = Math.exp(world[1] * 0.22);
          c = c.map((v, q) => v * keep + [38, 92, 118][q] * (1 - keep));
        }
        color.set(c, at * 3);
      }
    }
    const left = (index % 2) * panel, top = Math.floor(index / 2) * panelHeight;
    for (let py = 0; py < panelHeight; py++) for (let px = 0; px < panel; px++) {
      const sum = [0, 0, 0];
      for (let a = 0; a < ss; a++) for (let b = 0; b < ss; b++) {
        const at = ((py * ss + a) * W + px * ss + b) * 3;
        sum[0] += color[at]; sum[1] += color[at + 1]; sum[2] += color[at + 2];
      }
      const v = (panelHeight / 2 - py) / view.zoom;
      let c = sum.map(t => Math.min(255, Math.round(t / (ss * ss))));
      const waterline = Math.abs(dot(add(view.center, scale(up, v)), [0, 1, 0])) < 0.5 / view.zoom && Math.abs(forward[1]) < 0.3;
      if (waterline && c[0] === 196 && c[1] === 214) c = [40, 110, 160];
      image.set(c, ((top + py) * width + left + px) * 3);
    }
  });
  await writeFile(previewPath, png(width, height, image));
  console.log('Preview written to ' + previewPath + ' (' + (fallbackView ? 'fallback body' : 'mesh skin') + ': ' + views.map(v => v.title).join(', ') + ')');
}

function png(width, height, rgb) {
  const raw = Buffer.alloc((width * 3 + 1) * height);
  for (let y = 0; y < height; y++) rgb.copy(raw, y * (width * 3 + 1) + 1, y * width * 3, (y + 1) * width * 3);
  const crcTable = Array.from({ length: 256 }, (_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
  const crc = buffer => { let c = 0xffffffff; for (const byte of buffer) c = crcTable[(c ^ byte) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
  const chunk = (type, data) => {
    const body = Buffer.concat([Buffer.from(type), data]);
    const out = Buffer.alloc(body.length + 8);
    out.writeUInt32BE(data.length, 0); body.copy(out, 4); out.writeUInt32BE(crc(body), body.length + 4);
    return out;
  };
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0); header.writeUInt32BE(height, 4); header.set([8, 2, 0, 0, 0], 8);
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', header), chunk('IDAT', deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]);
}
