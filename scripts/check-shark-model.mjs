// Builds the real SharkModel against recording mocks and checks its geometry: no Ball parts (Roblox
// forces those to spheres), smooth mesh ellipsoids, sane frames, the swim segments SharkSwim bends,
// the overall size the spear hit volume assumes, and the dorsal fin breaking the surface.
// Pass --preview <file.png> to also raytrace side, top, three-quarter, front and mid-stroke views.
// This checks geometry only, not Roblox rendering or streaming.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { deflateSync } from 'node:zlib';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const previewIndex = process.argv.indexOf('--preview');
const previewPath = previewIndex > 0 ? resolve(process.argv[previewIndex + 1]) : null;
const source = await readFile(join(root, 'src/server/SharkModel.luau'), 'utf8');
const swim = await readFile(join(root, 'src/client/SharkSwim.luau'), 'utf8');
const pivot = name => {
  const match = swim.match(new RegExp(`local ${name} = CFrame\\.new\\(([^)]*)\\)`));
  if (!match) throw new Error(`SharkSwim ${name} not found`);
  return match[1].split(',').map(Number);
};
const flexPivot = pivot('FLEX_PIVOT'), tailPivot = pivot('TAIL_PIVOT');

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

local parts, segments = {}, { front = 0, SwimFlex = 0, SwimTail = 0 }
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
  local flex, tail = p:GetAttribute("SwimFlex") == true, p:GetAttribute("SwimTail") == true
  check(not (flex and tail), p.Name .. " belongs to one swim segment")
  local segment = if tail then "SwimTail" elseif flex then "SwimFlex" else "front"
  segments[segment] += 1
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
  -- Sections may overlap a joint (hidden inside the neighbour), but each piece sits on its own side.
  local z = offset.Position.Z
  if segment == "front" then check(z < FLEX_Z and zhi < TAIL_Z, p.Name .. " stays ahead of the flex joint") end
  if segment == "SwimFlex" then check(z > FLEX_Z - 0.5 and zhi < TAIL_Z + 1.5, p.Name .. " sits behind the flex joint") end
  if segment == "SwimTail" then check(z > TAIL_Z and zlo > FLEX_Z, p.Name .. " sits behind the tail joint") end
  if PREVIEW then
    local c = offset
    print(string.format("PART %s|%s|%.4f,%.4f,%.4f|%.4f,%.4f,%.4f|%.4f,%.4f,%.4f|%.4f,%.4f,%.4f|%.4f,%.4f,%.4f|%d,%d,%d",
      p.ClassName, segment, size.X, size.Y, size.Z, c.Position.X, c.Position.Y, c.Position.Z,
      c.x.X, c.x.Y, c.x.Z, c.y.X, c.y.Y, c.y.Z, c.z.X, c.z.Y, c.z.Z, p.Color.R, p.Color.G, p.Color.B))
  end
end
print(string.format("Shark: %.2f long (snout %.2f, tail %.2f), %.2f wide, %.2f to %.2f high, %d parts (%d front, %d flex, %d tail)",
  hi.Z - lo.Z, lo.Z, hi.Z, hi.X - lo.X, lo.Y, hi.Y, #parts, segments.front, segments.SwimFlex, segments.SwimTail))
check(#parts <= 90, "Keep the replicated part count modest: " .. #parts)
check(segments.SwimFlex > 0 and segments.SwimTail > 0, "Both bending segments have pieces")
check(lo.Z < -5 and hi.Z > 5.5 and hi.Z - lo.Z < 13, "The shark is about twelve studs long, snout towards -Z")
check(hi.X - lo.X > 6 and hi.X - lo.X < 8, "Pectoral fins span six to eight studs")
check(hi.Y > 1.2, "The dorsal fin and tail lobe break the surface")
check(lo.Y < -2.8, "The lower tail lobe reaches well below the body")
print("Shark model: " .. checks .. " geometry checks passed (recording mocks).")
`;

const folder = await mkdtemp(join(tmpdir(), 'fishing-shark-model-'));
try {
  const target = join(folder, 'checks.luau');
  await writeFile(target, `local PREVIEW = ${previewPath ? 'true' : 'false'}\nlocal FLEX_Z, TAIL_Z = ${flexPivot[2]}, ${tailPivot[2]}\n` + program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { encoding: 'utf8', maxBuffer: 1 << 26 });
  const lines = ((result.stdout || '') + (result.stderr || '')).split(/\r?\n/);
  console.log(lines.filter(line => !line.startsWith('PART ')).join('\n').trim());
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status || 1);
  if (previewPath) await writePreview(lines.filter(line => line.startsWith('PART ')));
} finally {
  await rm(folder, { recursive: true, force: true });
}

// Orthographic raytrace of ellipsoids and wedges, with the water surface tinting what lies below y = 0.
async function writePreview(partLines) {
  const parsed = partLines.map(line => {
    const [kind, segment, ...fields] = line.slice(5).split('|');
    const [size, position, x, y, z, color] = fields.map(field => field.split(',').map(Number));
    return { kind, segment, half: size.map(v => v / 2), position, axes: [x, y, z], color };
  });
  const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
  const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
  const add = (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
  const scale = (a, s) => [a[0] * s, a[1] * s, a[2] * s];
  const norm = a => scale(a, 1 / Math.hypot(...a));
  const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
  // Bend flex and tail pieces about their pivots, as SharkSwim does mid-stroke.
  const bend = (part, flexYaw, tailYaw) => {
    const turn = (p, pivotPoint, yaw) => {
      const c = Math.cos(yaw), s = Math.sin(yaw);
      const r = v => [c * v[0] + s * v[2], v[1], -s * v[0] + c * v[2]];
      return { ...p, position: add(pivotPoint, r(sub(p.position, pivotPoint))), axes: p.axes.map(r) };
    };
    let result = part;
    if (part.segment === 'SwimTail') result = turn(result, tailPivot, tailYaw);
    if (part.segment !== 'front') result = turn(result, flexPivot, flexYaw);
    return result;
  };
  const intersect = (part, origin, direction) => {
    const local = sub(origin, part.position);
    const o = part.axes.map(a => dot(a, local)), d = part.axes.map(a => dot(a, direction));
    if (part.kind === 'Part') {
      const os = o.map((v, i) => v / part.half[i]), ds = d.map((v, i) => v / part.half[i]);
      const a = dot(ds, ds), b = 2 * dot(os, ds), c = dot(os, os) - 1;
      const disc = b * b - 4 * a * c;
      if (disc < 0) return null;
      const t = (-b - Math.sqrt(disc)) / (2 * a);
      if (t < 0) return null;
      const p = add(os, scale(ds, t)).map((v, i) => v / part.half[i]);
      return { t, normal: norm(add(add(scale(part.axes[0], p[0]), scale(part.axes[1], p[1])), scale(part.axes[2], p[2]))) };
    }
    // Wedge: |x| <= hx, y >= -hy, z <= hz and the slope y/hy - z/hz <= 0.
    const [hx, hy, hz] = part.half;
    const planes = [[[1, 0, 0], hx], [[-1, 0, 0], hx], [[0, -1, 0], hy], [[0, 0, 1], hz], [norm([0, 1 / hy, -1 / hz]), 0]];
    let near = -Infinity, far = Infinity, normal = null;
    for (const [n, offset] of planes) {
      const denominator = dot(n, d), distance = offset - dot(n, o);
      if (Math.abs(denominator) < 1e-12) { if (distance < 0) return null; continue; }
      const t = distance / denominator;
      if (denominator < 0) { if (t > near) { near = t; normal = n; } } else far = Math.min(far, t);
      if (near > far) return null;
    }
    if (!normal || near < 0) return null;
    return { t: near, normal: norm(add(add(scale(part.axes[0], normal[0]), scale(part.axes[1], normal[1])), scale(part.axes[2], normal[2]))) };
  };
  const panel = 480, pixelsPerStud = 34;
  const views = [
    { title: 'side', forward: [1, 0, 0], up: [0, 1, 0], center: [0, -0.9, 0.4] },
    { title: 'top', forward: [0, -1, 0], up: [0, 0, -1], center: [0, 0, 0.4] },
    { title: 'front three-quarter', forward: [0.75, -0.5, 1], up: [0, 1, 0], center: [0, -1.1, 0.2] },
    { title: 'rear three-quarter low', forward: [-0.9, 0.25, -1], up: [0, 1, 0], center: [0, -1.1, 0.2] },
    { title: 'front', forward: [0, -0.15, 1], up: [0, 1, 0], center: [0, -1, 0] },
    { title: 'top mid-stroke', forward: [0, -1, 0], up: [0, 0, -1], center: [0, 0, 0.4], flex: 0.15, tail: 0.3 },
  ];
  const width = panel * 2, height = Math.round(panel * 0.68) * 3, panelHeight = height / 3;
  const image = Buffer.alloc(width * height * 3);
  const light = norm([-0.4, 1, -0.5]);
  views.forEach((view, index) => {
    const parts = view.flex ? parsed.map(p => bend(p, view.flex, view.tail)) : parsed;
    const forward = norm(view.forward);
    const right = norm(cross(forward, view.up));
    const up = cross(right, forward);
    const left = (index % 2) * panel, top = Math.floor(index / 2) * panelHeight;
    for (let py = 0; py < panelHeight; py++) for (let px = 0; px < panel; px++) {
      const u = (px - panel / 2) / pixelsPerStud, v = (panelHeight / 2 - py) / pixelsPerStud;
      const origin = add(add(add(view.center, scale(forward, -40)), scale(right, u)), scale(up, v));
      let best = null, bestPart = null;
      for (const part of parts) {
        const hit = intersect(part, origin, forward);
        if (hit && (!best || hit.t < best.t)) { best = hit; bestPart = part; }
      }
      let color = [196, 214, 226];
      if (best) {
        const normal = dot(best.normal, forward) > 0 ? scale(best.normal, -1) : best.normal;
        const shade = 0.42 + 0.58 * Math.max(0, dot(normal, light));
        color = bestPart.color.map(c => c * shade);
        const point = add(origin, scale(forward, best.t));
        // Seen from above, water dims what is under the surface.
        if (point[1] < 0 && forward[1] < -0.1) {
          const keep = Math.exp(point[1] * 0.22);
          color = color.map((c, k) => c * keep + [38, 92, 118][k] * (1 - keep));
        }
      }
      const waterline = Math.abs(dot(add(origin, scale(forward, 40)), [0, 1, 0])) < 0.5 / pixelsPerStud;
      if (waterline && Math.abs(forward[1]) < 0.3) color = [40, 110, 160];
      image.set(color.map(Math.round), ((top + py) * width + left + px) * 3);
    }
  });
  await writeFile(previewPath, png(width, height, image));
  console.log('Preview written to ' + previewPath + ' (' + views.map(v => v.title).join(', ') + ')');
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
