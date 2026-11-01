// Builds the real MscPreziosa model against recording mocks and checks its geometry: the overall
// dimensions match the ship (333.3 m x 37.9 m, 8.65 m draught, mast 66.8 m above the waterline),
// parts stay within Roblox limits and every frame is a proper rotation.
// Pass --preview <file.png> to also render a starboard elevation over a plan view.
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
check(#parts > 1500 and #parts < 14000, "A sensible part count: " .. #parts)
local named = {}
for _, p in parts do named[p.Name] = (named[p.Name] or 0) + 1 end
check(named.Helm == 24, "Twelve lifeboats and tenders a side, each with a helm position")
check((named.Partition or 0) > 500, "Balconies are divided by partitions")
check((named.Slat or 0) > 100, "The funnel is built from slats, not a solid casing")
check((named.Hull or 0) > 1500, "The bow is skinned in triangles, not stacked layers")
check((named.Emblem or 0) > 150, "The MSC stars are built from parts")
-- Per side: the name, the hull logo's MSC and the lettering of three stars; name and port across the stern
check(named.Lettering == 2 * (1 + 1 + 3) + 2, "Every livery sign is placed: " .. tostring(named.Lettering))
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
check(math.abs(top - 66.8) < 0.1, "Mast top is 66.8 m above the waterline")
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
    if p.Transparency < 0.9 then
      local c, s = p.CFrame, p.Size
      local corners = {}
      local shape = if p.ClassName == "WedgePart"
        then { { -1, -1, -1 }, { -1, -1, 1 }, { -1, 1, 1 }, { 1, -1, -1 }, { 1, -1, 1 }, { 1, 1, 1 } }
        else { { -1, -1, -1 }, { -1, -1, 1 }, { -1, 1, -1 }, { -1, 1, 1 }, { 1, -1, -1 }, { 1, -1, 1 }, { 1, 1, -1 }, { 1, 1, 1 } }
      for _, k in shape do
        local w = c * v3(s.X * k[1] / 2, s.Y * k[2] / 2, s.Z * k[3] / 2) - origin
        table.insert(corners, string.format("%.2f,%.2f,%.2f", w.X / S, w.Y / S, w.Z / S))
      end
      print("PART " .. p.Color.R .. "," .. p.Color.G .. "," .. p.Color.B .. "," .. p.Transparency .. "|" .. table.concat(corners, ";"))
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

// Starboard elevation (bow on the right) above a plan view, each part filled as the convex hull of
// its projected corners and drawn back to front.
async function writePreview(partLines) {
  const scale = 4; // pixels per metre
  const width = Math.ceil(345 * scale), side = Math.ceil(80 * scale), plan = Math.ceil(52 * scale);
  const height = side + plan + 20;
  const image = Buffer.alloc(width * height * 3, 0);
  for (let i = 0; i < width * height; i++) image.set([200, 222, 236], i * 3);
  const parts = partLines.map(line => {
    const [head, body] = line.slice(5).split('|');
    const [r, g, b, transparency] = head.split(',').map(Number);
    return { color: [r, g, b], transparency, corners: body.split(';').map(c => c.split(',').map(Number)) };
  });
  const toX = x => (345 - (x + 172.5)) * scale; // the bow (-X) on the right
  const fill = (points, color, alpha, clipTop, clipBottom) => {
    const hull = convexHull(points);
    if (hull.length < 3) return;
    const ys = hull.map(p => p[1]);
    for (let y = Math.max(clipTop, Math.floor(Math.min(...ys))); y <= Math.min(clipBottom, Math.ceil(Math.max(...ys))); y++) {
      let left = Infinity, right = -Infinity;
      for (let i = 0; i < hull.length; i++) {
        const [x1, y1] = hull[i], [x2, y2] = hull[(i + 1) % hull.length];
        if ((y1 <= y + 0.5 && y2 >= y + 0.5) || (y2 <= y + 0.5 && y1 >= y + 0.5)) {
          const x = y1 === y2 ? Math.min(x1, x2) : x1 + (x2 - x1) * (y + 0.5 - y1) / (y2 - y1);
          const xb = y1 === y2 ? Math.max(x1, x2) : x;
          left = Math.min(left, x, xb); right = Math.max(right, x, xb);
        }
      }
      for (let x = Math.max(0, Math.round(left)); x <= Math.min(width - 1, Math.round(right)); x++) {
        const i = (y * width + x) * 3;
        for (let k = 0; k < 3; k++) image[i + k] = Math.round(image[i + k] * (1 - alpha) + color[k] * alpha);
      }
    }
  };
  // Waterline and sea in the elevation
  const waterY = 70 * scale;
  for (let y = waterY; y < side; y++) for (let x = 0; x < width; x++) image.set([60, 110, 140], (y * width + x) * 3);
  const elevation = [...parts].sort((a, b) => Math.max(...a.corners.map(c => c[2])) - Math.max(...b.corners.map(c => c[2])));
  for (const part of elevation) {
    const under = part.corners.every(c => c[1] <= 0.01);
    fill(part.corners.map(c => [toX(c[0]), waterY - c[1] * scale]), part.color, (1 - part.transparency) * (under ? 0.45 : 1), 0, side - 1);
  }
  const planMid = side + 20 + plan / 2;
  const planView = [...parts].sort((a, b) => Math.max(...a.corners.map(c => c[1])) - Math.max(...b.corners.map(c => c[1])));
  for (const part of planView) {
    fill(part.corners.map(c => [toX(c[0]), planMid - c[2] * scale]), part.color, 1 - part.transparency, side + 20, height - 1);
  }
  await writeFile(previewPath, png(width, height, image));
  console.log('Preview written to ' + previewPath);
}

function convexHull(points) {
  const p = points.map(q => [q[0], q[1]]).sort((a, b) => a[0] - b[0] || a[1] - b[1]);
  const cross = (o, a, b) => (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]);
  const lower = [], upper = [];
  for (const q of p) { while (lower.length >= 2 && cross(lower.at(-2), lower.at(-1), q) <= 0) lower.pop(); lower.push(q); }
  for (const q of p.reverse()) { while (upper.length >= 2 && cross(upper.at(-2), upper.at(-1), q) <= 0) upper.pop(); upper.push(q); }
  return lower.slice(0, -1).concat(upper.slice(0, -1));
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
