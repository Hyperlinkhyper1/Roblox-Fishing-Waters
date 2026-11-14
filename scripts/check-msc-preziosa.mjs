// Builds the real MscPreziosa model against recording mocks and checks its geometry: the overall
// dimensions match the ship (333.3 m x 37.9 m, 8.65 m draught, 66.8 m from keel to masthead),
// parts stay within Roblox limits and every frame is a proper rotation.
// Pass --preview <file.png> to also render it: a starboard elevation over a plan view in that file,
// and beside it <file>-bow.png, -stern.png, -bow-quarter.png, -stern-quarter.png and -top-quarter.png.
// Add --crop x0,x1 (metres aft of the bow) for close-ups of part of the ship in <file>-crop.png.
// This checks geometry only, not Roblox rendering, physics or streaming.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { deflateSync } from 'node:zlib';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const previewIndex = process.argv.indexOf('--preview');
const previewPath = previewIndex > 0 ? resolve(process.argv[previewIndex + 1]) : null;
const source = await readFile(join(root, 'src/server/MscPreziosa.luau'), 'utf8');

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
local Vector3 = { new = v3, zero = v3(0, 0, 0), one = v3(1, 1, 1), xAxis = v3(1, 0, 0), yAxis = v3(0, 1, 0), zAxis = v3(0, 0, 1) }

-- CFrames as a position and three axis columns
local CF = {}
local function cf(p, x, y, z) return setmetatable({ Position = p, x = x, y = y, z = z }, CF) end
local function rotate(c, v) return c.x * v.X + c.y * v.Y + c.z * v.Z end
CF.__mul = function(a, b)
  if getmetatable(b) == V3 then return a.Position + rotate(a, b) end
  return cf(a.Position + rotate(a, b.Position), rotate(a, b.x), rotate(a, b.y), rotate(a, b.z))
end
local CFrame = {}
function CFrame.new(x, y, z)
  if type(x) == "table" then return cf(x, Vector3.xAxis, Vector3.yAxis, Vector3.zAxis) end
  return cf(v3(x or 0, y or 0, z or 0), Vector3.xAxis, Vector3.yAxis, Vector3.zAxis)
end
function CFrame.fromMatrix(p, x, y, z) return cf(p, x, y, z or x:Cross(y)) end
local function axis(kind, t)
  local c, s = math.cos(t), math.sin(t)
  if kind == "x" then return cf(Vector3.zero, v3(1, 0, 0), v3(0, c, s), v3(0, -s, c)) end
  if kind == "y" then return cf(Vector3.zero, v3(c, 0, -s), v3(0, 1, 0), v3(s, 0, c)) end
  return cf(Vector3.zero, v3(c, s, 0), v3(-s, c, 0), v3(0, 0, 1))
end
function CFrame.Angles(rx, ry, rz) return axis("x", rx) * axis("y", ry) * axis("z", rz) end

local Color3 = { fromRGB = function(r, g, b) return { R = r, G = g, B = b } end }
local Enum = setmetatable({}, { __index = function(_, group)
  return setmetatable({}, { __index = function(_, item) return group .. "." .. item end })
end })
local UDim2 = { fromScale = function(x, y) return { x, y } end }
local UDim = { new = function(s, o) return { s, o } end }
local Vector2 = { new = function(x, y) return { X = x, Y = y } end }
local task = { wait = function() end }

local parts = {}
local Instance = {}
function Instance.new(kind)
  local object = { ClassName = kind, children = {}, attributes = {}, Transparency = 0 }
  function object:SetAttribute(key, value) self.attributes[key] = value end
  function object:GetAttribute(key) return self.attributes[key] end
  return setmetatable(object, { __newindex = function(t, key, value)
    -- Roblox refuses nil for every property but Parent, as a missing argument would pass
    if value == nil and key ~= "Parent" then error("Unable to assign property " .. key .. ": got nil", 2) end
    rawset(t, key, value)
    if key == "Parent" and value and (kind == "Part" or kind == "WedgePart") then table.insert(parts, t) end
  end })
end

local MscPreziosa = (function()
${source}
end)()

local folder = Instance.new("Folder")
local origin = v3(-9500, 0, 0)
local ship = MscPreziosa.build(folder, origin, function() end)
local S = MscPreziosa.STUDS
check(ship.Parent == folder and ship.Name == "MSC Preziosa", "The ship is published into the given folder")
check(ship:GetAttribute("PartCount") == #parts, "PartCount counts every part")
check(#parts > 1500 and #parts < 26000, "A sensible part count: " .. #parts)
local named = {}
for _, p in parts do named[p.Name] = (named[p.Name] or 0) + 1 end
check(named.Helm == 30, "Eleven lifeboats, a rescue boat and three tenders a side, each with a helm position: " .. tostring(named.Helm))
check(named.Davit >= 60, "Every boat hangs from davits")
check((named.BalconyGlass or 0) > 100, "Balconies are open behind glass balustrades")
check((named.Partition or 0) > 500, "Balconies are divided by partitions")
check((named.Slat or 0) > 100, "The funnel is built from slats, not a solid casing")
check((named.Hull or 0) > 1200, "The bow is skinned in triangles, not stacked layers: " .. tostring(named.Hull))
check((named.Emblem or 0) > 150, "The MSC stars are built from parts")
-- Per side: the name on the bow and on the glass screen, the hull logo's MSC and the lettering of
-- three stars; name and port across the stern
check(named.Lettering == 2 * (2 + 1 + 3) + 2, "Every livery sign is placed: " .. tostring(named.Lettering))
for _, p in parts do
  if p.Name == "Lettering" then check(p.Transparency == 1, "Livery plates are invisible") end
end

local lo, hi = v3(math.huge, math.huge, math.huge), v3(-math.huge, -math.huge, -math.huge)
local wideDeck = 0
for _, p in parts do
  local size = p.Size
  check(size.X > 0 and size.Y > 0 and size.Z > 0, p.Name .. " has a positive size")
  check(size.X <= 2048 and size.Y <= 2048 and size.Z <= 2048, p.Name .. " is within the Roblox part size limit")
  local c = p.CFrame
  for _, pair in { { c.x, c.y }, { c.y, c.z }, { c.z, c.x } } do
    check(math.abs(pair[1]:Dot(pair[2])) < 1e-6, p.Name .. " has perpendicular axes")
  end
  for _, a in { c.x, c.y, c.z } do check(math.abs(a.Magnitude - 1) < 1e-6, p.Name .. " has unit axes") end
  check(math.abs(c.x:Cross(c.y):Dot(c.z) - 1) < 1e-6, p.Name .. " has a right-handed frame")
  if p.Transparency < 1 then
    for _, sx in { -0.5, 0.5 } do for _, sy in { -0.5, 0.5 } do for _, sz in { -0.5, 0.5 } do
      local corner = c * v3(size.X * sx, size.Y * sy, size.Z * sz)
      lo = v3(math.min(lo.X, corner.X), math.min(lo.Y, corner.Y), math.min(lo.Z, corner.Z))
      hi = v3(math.max(hi.X, corner.X), math.max(hi.Y, corner.Y), math.max(hi.Z, corner.Z))
    end end end
  end
end
local length, beam = (hi.X - lo.X) / S, (hi.Z - lo.Z) / S
local keel, top = (lo.Y - origin.Y) / S, (hi.Y - origin.Y) / S
print(string.format("Extent: %.1f m long, %.1f m wide (bridge wings), keel %.2f m, top %.2f m, %d parts", length, beam, keel, top, #parts))
check(math.abs(length - 333.3) < 1.5, "Length overall matches 333.3 m")
check(math.abs(beam - 47.2) < 0.5, "Bridge wings reach 47.2 m across")
check(math.abs(keel + 8.65) < 0.05, "Keel sits at the 8.65 m draught")
check(math.abs(top - keel - 66.8) < 0.1, "The masthead is 66.8 m above the keel")
check(math.abs(MscPreziosa.FLOOR[9] - MscPreziosa.FLOOR[8] - 2.78) < 0.05, "Cabin decks are 2.78 m apart")
check(MscPreziosa.FLOOR[15] - MscPreziosa.FLOOR[14] > 3.5, "The pool deck is taller than a cabin deck")
check(math.abs((lo.X - origin.X) / S + 333.3 / 2) < 1, "The bow points -X from the origin amidships")

-- The hull at the waterline: full 37.9 m beam amidships, and the stem well aft of the bow tip
local waterline = MscPreziosa.hullPlan(0)
check(math.abs(MscPreziosa.sample(waterline, 166) - 18.93) < 0.01, "Hull is the full beam amidships at the waterline")
check(waterline[1][1] > 20 and waterline[1][1] < 30, "The raked stem meets the water 20-30 m behind the bow tip")
for deck, pieces in MscPreziosa.PLAN do
  for _, piece in pieces do
    for i = 2, #piece do check(piece[i][1] >= piece[i - 1][1], "Deck " .. deck .. " outline runs aft") end
    for _, point in piece do check(point[2] >= 0 and point[2] <= 23.6, "Deck " .. deck .. " stays within the bridge wings") end
  end
end
-- Decks 8-13 step in over the lifeboats while deck 14 cantilevers out above them
for _, deck in { 8, 9, 10, 11, 12, 13 } do
  check(MscPreziosa.sample(MscPreziosa.PLAN[deck][1], 150) < 13.5, "Deck " .. deck .. " is set back over the lifeboats")
end
check(MscPreziosa.sample(MscPreziosa.PLAN[14][1], 150) > 17.5, "Deck 14 overhangs the lifeboats")

if PREVIEW then
  for _, p in parts do
    if p.Transparency < 0.95 then
      local c, s = p.CFrame, p.Size
      local w = c.Position - origin
      local shape = if p.ClassName == "WedgePart" then "wedge" elseif p.Shape == "PartType.Cylinder" then "cylinder" elseif p.Shape == "PartType.Ball" then "ball" else "box"
      print(string.format("PART %d,%d,%d,%.2f,%s|%.3f,%.3f,%.3f|%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f|%.3f,%.3f,%.3f",
        p.Color.R, p.Color.G, p.Color.B, p.Transparency, shape, w.X / S, w.Y / S, w.Z / S,
        c.x.X, c.x.Y, c.x.Z, c.y.X, c.y.Y, c.y.Z, c.z.X, c.z.Y, c.z.Z, s.X / S, s.Y / S, s.Z / S))
    end
  end
end
print("MSC Preziosa: " .. checks .. " geometry checks passed (recording mocks).")
`;

const folder = await mkdtemp(join(tmpdir(), 'fishing-preziosa-'));
try {
  const target = join(folder, 'checks.luau');
  await writeFile(target, 'local PREVIEW = ' + (previewPath ? 'true' : 'false') + '\n' + program);
  const result = spawnSync('lute', ['run', target], { encoding: 'utf8', maxBuffer: 1 << 28 });
  const output = (result.stdout || '') + (result.stderr || '');
  const lines = output.split(/\r?\n/);
  console.log(lines.filter(line => !line.startsWith('PART ')).join('\n').trim());
  if (result.status !== 0) process.exit(result.status || 1);
  if (previewPath) await writePreview(lines.filter(line => line.startsWith('PART ')));
} finally {
  await rm(folder, { recursive: true, force: true });
}

// Renders the recorded parts with a z-buffer, orthographically. World axes are the model's: the
// bow points -X, Y is up, and the ship's starboard side faces -Z.
async function writePreview(partLines) {
  const meshes = partLines.map(line => mesh(line.slice(5)));
  const cropIndex = process.argv.indexOf('--crop');
  const save = async (suffix, image) => {
    const path = suffix ? previewPath.replace(/\.png$/i, '') + '-' + suffix + '.png' : previewPath;
    await writeFile(path, png(image.width, image.height, image.rgb));
    console.log('Preview written to ' + path);
  };
  const side = render(meshes, { forward: [0, 0, 1], up: [0, 1, 0], scale: 4 });
  const plan = render(meshes, { forward: [0, -1, 0], up: [0, 0, 1], scale: 4, sea: false });
  await save('', stack([side, plan]));
  await save('bow', render(meshes, { forward: [1, 0, 0], up: [0, 1, 0], scale: 9 }));
  await save('stern', render(meshes, { forward: [-1, 0, 0], up: [0, 1, 0], scale: 9 }));
  await save('bow-quarter', render(meshes, { forward: [0.62, -0.3, 0.72], up: [0, 1, 0], scale: 4.4 }));
  await save('stern-quarter', render(meshes, { forward: [-0.6, -0.22, 0.77], up: [0, 1, 0], scale: 4.4 }));
  await save('top-quarter', render(meshes, { forward: [-0.25, -0.62, 0.74], up: [0, 1, 0], scale: 4.4 }));
  if (cropIndex > 0) {
    const [x0, x1] = process.argv[cropIndex + 1].split(',').map(Number);
    const kept = meshes.filter(m => m.centre[0] + 166.65 > x0 - 6 && m.centre[0] + 166.65 < x1 + 6);
    await save('crop', render(kept, { forward: [0, 0, 1], up: [0, 1, 0], scale: 1300 / (x1 - x0 + 12) }));
    await save('crop-quarter', render(kept, { forward: [-0.45, -0.45, 0.77], up: [0, 1, 0], scale: 1100 / (x1 - x0 + 12) }));
  }
}

function cross(a, b) { return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]; }
function dot(a, b) { return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]; }
function unit(a) { const m = Math.hypot(...a) || 1; return [a[0] / m, a[1] / m, a[2] / m]; }

// A part as triangles in world metres
function mesh(text) {
  const [head, position, axes, size] = text.split('|');
  const [r, g, b, transparency, shape] = head.split(',');
  const p = position.split(',').map(Number), a = axes.split(',').map(Number), s = size.split(',').map(Number);
  const place = v => [0, 1, 2].map(k => p[k] + a[k] * v[0] * s[0] / 2 + a[3 + k] * v[1] * s[1] / 2 + a[6 + k] * v[2] * s[2] / 2);
  let local = [], faces = [];
  if (shape === 'wedge') {
    local = [[-1, -1, -1], [-1, -1, 1], [-1, 1, 1], [1, -1, -1], [1, -1, 1], [1, 1, 1]];
    faces = [[0, 1, 4, 3], [1, 2, 5, 4], [0, 3, 5, 2], [0, 1, 2], [3, 4, 5]];
  } else if (shape === 'cylinder' || shape === 'ball') {
    // Both are round in the part's Y-Z plane; a ball is also round along X
    const around = 12, rings = shape === 'ball' ? 6 : 1;
    const least = Math.min(...s);
    for (let i = 0; i <= rings; i++) {
      const t = Math.PI * i / rings;
      const x = shape === 'ball' ? -Math.cos(t) * least / s[0] : i * 2 - 1;
      const ring = shape === 'ball' ? Math.max(Math.sin(t), 0.02) * least : Math.min(s[1], s[2]);
      for (let j = 0; j < around; j++) {
        const u = 2 * Math.PI * j / around;
        local.push([x, Math.cos(u) * ring / s[1], Math.sin(u) * ring / s[2]]);
      }
    }
    for (let i = 0; i < rings; i++) for (let j = 0; j < around; j++) {
      const k = (j + 1) % around;
      faces.push([i * around + j, i * around + k, (i + 1) * around + k, (i + 1) * around + j]);
    }
    if (shape === 'cylinder') faces.push([...Array(around).keys()], [...Array(around).keys()].map(j => around + j));
  } else {
    local = [[-1, -1, -1], [-1, -1, 1], [-1, 1, -1], [-1, 1, 1], [1, -1, -1], [1, -1, 1], [1, 1, -1], [1, 1, 1]];
    faces = [[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]];
  }
  const vertices = local.map(place);
  const triangles = [];
  for (const face of faces) {
    const q = face.map(i => vertices[i]);
    let normal = [0, 0, 0];
    for (let i = 1; i + 1 < q.length && Math.hypot(...normal) < 1e-9; i++) {
      normal = cross(q[i].map((v, k) => v - q[0][k]), q[i + 1].map((v, k) => v - q[0][k]));
    }
    normal = unit(normal);
    const middle = [0, 1, 2].map(k => q.reduce((sum, v) => sum + v[k], 0) / q.length);
    if (dot(normal, middle.map((v, k) => v - p[k])) < 0) normal = normal.map(v => -v);
    for (let i = 1; i + 1 < q.length; i++) triangles.push({ points: [q[0], q[i], q[i + 1]], normal });
  }
  return { color: [Number(r), Number(g), Number(b)], transparency: Number(transparency), triangles, centre: p };
}

function render(meshes, { forward, up, scale, sea = true }) {
  const f = unit(forward), right = unit(cross(f, up)), top = cross(right, f);
  const light = unit([0, 1, 2].map(k => -f[k] * 0.55 + top[k] * 0.75 + right[k] * 0.35));
  let lo = [Infinity, Infinity], hi = [-Infinity, -Infinity];
  for (const m of meshes) for (const t of m.triangles) for (const v of t.points) {
    const x = dot(v, right), y = dot(v, top);
    lo = [Math.min(lo[0], x), Math.min(lo[1], y)]; hi = [Math.max(hi[0], x), Math.max(hi[1], y)];
  }
  const pad = 12;
  const width = Math.ceil((hi[0] - lo[0]) * scale) + 2 * pad, height = Math.ceil((hi[1] - lo[1]) * scale) + 2 * pad;
  const rgb = Buffer.alloc(width * height * 3), depth = new Float32Array(width * height).fill(Infinity);
  for (let i = 0; i < width * height; i++) rgb.set([200, 222, 236], i * 3);
  const draw = (m, t, write) => {
    const shade = 0.55 + 0.45 * Math.max(0, dot(t.normal, light));
    const alpha = 1 - m.transparency;
    const s = t.points.map(v => [(dot(v, right) - lo[0]) * scale + pad, (hi[1] - dot(v, top)) * scale + pad, dot(v, f)]);
    const area = (s[1][0] - s[0][0]) * (s[2][1] - s[0][1]) - (s[2][0] - s[0][0]) * (s[1][1] - s[0][1]);
    if (Math.abs(area) < 1e-9) return;
    const x0 = Math.max(0, Math.floor(Math.min(s[0][0], s[1][0], s[2][0]))), x1 = Math.min(width - 1, Math.ceil(Math.max(s[0][0], s[1][0], s[2][0])));
    const y0 = Math.max(0, Math.floor(Math.min(s[0][1], s[1][1], s[2][1]))), y1 = Math.min(height - 1, Math.ceil(Math.max(s[0][1], s[1][1], s[2][1])));
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
      const px = x + 0.5, py = y + 0.5;
      const w0 = ((s[1][0] - px) * (s[2][1] - py) - (s[2][0] - px) * (s[1][1] - py)) / area;
      const w1 = ((s[2][0] - px) * (s[0][1] - py) - (s[0][0] - px) * (s[2][1] - py)) / area;
      const w2 = 1 - w0 - w1;
      if (w0 < -0.001 || w1 < -0.001 || w2 < -0.001) continue;
      const z = w0 * s[0][2] + w1 * s[1][2] + w2 * s[2][2];
      const i = y * width + x;
      if (z >= depth[i]) continue;
      if (write) depth[i] = z;
      for (let k = 0; k < 3; k++) rgb[i * 3 + k] = Math.round(rgb[i * 3 + k] * (1 - alpha) + m.color[k] * shade * alpha);
    }
  };
  const solid = meshes.filter(m => m.transparency < 0.05), clear = meshes.filter(m => m.transparency >= 0.05);
  for (const m of solid) for (const t of m.triangles) draw(m, t, true);
  if (sea) {
    const water = { color: [60, 110, 140], transparency: 0.35 };
    const c = [[-260, 0, -120], [260, 0, -120], [260, 0, 120], [-260, 0, 120]];
    for (const points of [[c[0], c[1], c[2]], [c[0], c[2], c[3]]]) draw(water, { points, normal: [0, 1, 0] }, false);
    // Seen side on the sea has no area, so tint everything below the waterline instead
    if (Math.abs(f[1]) < 0.01) {
      const line = Math.round(hi[1] * scale + pad);
      for (let y = line; y < height; y++) for (let x = 0; x < width; x++) {
        const i = (y * width + x) * 3;
        for (let k = 0; k < 3; k++) rgb[i + k] = Math.round(rgb[i + k] * 0.45 + water.color[k] * 0.55);
      }
    }
  }
  clear.sort((a, b) => dot(b.centre, f) - dot(a.centre, f));
  for (const m of clear) for (const t of m.triangles) draw(m, t, false);
  return { width, height, rgb };
}

// Images one above the other on the sky colour
function stack(images) {
  const width = Math.max(...images.map(i => i.width)), height = images.reduce((sum, i) => sum + i.height, 0);
  const rgb = Buffer.alloc(width * height * 3);
  for (let i = 0; i < width * height; i++) rgb.set([200, 222, 236], i * 3);
  let y = 0;
  for (const image of images) {
    for (let row = 0; row < image.height; row++) image.rgb.copy(rgb, ((y + row) * width) * 3, row * image.width * 3, (row + 1) * image.width * 3);
    y += image.height;
  }
  return { width, height, rgb };
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
