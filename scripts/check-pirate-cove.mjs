// Builds the real Pirate Cove island (Map/PirateCove with Islands, Props, Seabed, LowPoly and Lod)
// against check-city's engine mocks and checks where things landed: the crew stand on dry, open
// ground inside the Coral Shallows, the pier reaches the water, buildings don't overlap, and the
// seeded scenery it sits on is cleared. workspace:Raycast is a vertical ray against the recorded
// ground triangles, which is all Islands.surface asks of it.
// Run: node scripts/check-pirate-cove.mjs [--preview plan.png]   (--preview draws a top-down plan)
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { deflateSync } from 'node:zlib';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const previewIndex = process.argv.indexOf('--preview');
const previewPath = previewIndex > 0 ? resolve(process.argv[previewIndex + 1]) : null;
const city = await readFile(join(root, 'scripts/check-city.mjs'), 'utf8');
const mocks = city.match(/const mocks = String\.raw`([\s\S]*?)`;\r?\n/)[1];

const modules = {
  LowPoly: 'src/server/Map/LowPoly.luau',
  Props: 'src/server/Map/Props.luau',
  Islands: 'src/server/Map/Islands.luau',
  Seabed: 'src/server/Map/Seabed.luau',
  Lod: 'src/server/Map/Lod.luau',
  PirateCove: 'src/server/Map/PirateCove.luau',
  Biomes: 'src/shared/Biomes.luau',
  CoveData: 'src/shared/PirateCove.luau',
};
let bundle = mocks + String.raw`
-- A small seeded generator standing in for Roblox's Random.
local Random = {}
function Random.new(seed)
  local state = (seed or 1) % 2147483647
  if state <= 0 then state += 2147483646 end
  local rng = {}
  local function step() state = (state * 16807) % 2147483647; return (state - 1) / 2147483646 end
  function rng:NextNumber(a, b) local t = step(); if a == nil then return t end; return a + (b - a) * t end
  function rng:NextInteger(a, b) return math.min(b, a + math.floor(step() * (b - a + 1))) end
  return rng
end

-- Models pivot on their bounding box centre, as Roblox does without a primary part.
function methods:GetPivot() return (self:GetBoundingBox()) end

local loaded, loaders = {}, {}
local function require(target) local name = target.__module; if loaded[name] == nil then loaded[name] = loaders[name]() end; return loaded[name] end
local script = { Parent = setmetatable({}, { __index = function(_, name) return { __module = name } end }) }
`;
for (const [name, path] of Object.entries(modules)) {
  const source = (await readFile(join(root, path), 'utf8'))
    .replace('require(ReplicatedStorage.Shared.Biomes)', 'require({ __module = "Biomes" })')
    .replace('require(ReplicatedStorage.Shared.PirateCove)', 'require({ __module = "CoveData" })');
  bundle += `loaders[${JSON.stringify(name)}] = function()\n${source}\nend\n`;
}

bundle += String.raw`
-- Ground triangles, recorded as Islands and Seabed lay them; props never count as ground.
local triangles = {}
local LowPoly = require({ __module = "LowPoly" })
local triangle = LowPoly.triangle
LowPoly.triangle = function(a, b, c, inside, color, parent, ...)
  if parent and parent.Name == "Ground" then table.insert(triangles, { a, b, c }) end
  return triangle(a, b, c, inside, color, parent, ...)
end
workspace.Raycast = function(_, origin, direction)
  local best
  for _, t in triangles do
    local a, b, c = t[1], t[2], t[3]
    local d = (b.X - a.X) * (c.Z - a.Z) - (c.X - a.X) * (b.Z - a.Z)
    if math.abs(d) > 1e-9 then
      local u = ((origin.X - a.X) * (c.Z - a.Z) - (c.X - a.X) * (origin.Z - a.Z)) / d
      local v = ((b.X - a.X) * (origin.Z - a.Z) - (origin.X - a.X) * (b.Z - a.Z)) / d
      if u >= -1e-6 and v >= -1e-6 and u + v <= 1 + 1e-6 then
        local y = a.Y + u * (b.Y - a.Y) + v * (c.Y - a.Y)
        if y <= origin.Y and y >= origin.Y + direction.Y and (not best or y > best.Position.Y) then
          local normal = (b - a):Cross(c - a).Unit
          if normal.Y < 0 then normal = -normal end
          best = { Position = v3(origin.X, y, origin.Z), Normal = normal }
        end
      end
    end
  end
  return best
end

local Biomes = require({ __module = "Biomes" })
local Data = require({ __module = "CoveData" })
local Cove = require({ __module = "PirateCove" })
local CENTER = v3(Data.CENTER[1], 0, Data.CENTER[2])

-- A map with seeded scenery on the site (and its shell), plus an island far away.
local map = Instance.new("Folder")
map.Name = "Map"
map.Parent = workspace
local shells = Instance.new("Model")
shells.Name = "Lod"
shells.Parent = map
local tropics = Instance.new("Folder")
tropics.Name = "Coral Shallows"
tropics.Parent = map
local function scenery(x, z, id)
  local isle = Instance.new("Model")
  isle.Name = "Island"
  isle:SetAttribute("Radius", 40)
  isle:SetAttribute("LodId", id)
  local rock = Instance.new("Part")
  rock.CFrame = CFrame.new(x, 5, z)
  rock.Parent = isle
  isle.Parent = tropics
  local shell = Instance.new("Model")
  shell.Name = tostring(id)
  shell.Parent = shells
  return isle
end
local doomed = scenery(CENTER.X + 60, CENTER.Z - 30, 501)
local spared = scenery(CENTER.X + 900, CENTER.Z, 502)

local cove = Cove.build(map)
check(cove.Parent == map and cove.Name == Data.NAME, "The cove is published under the map")
check(cove:GetAttribute("LodRoot") == true and cove:GetAttribute("LodRadial") == true, "The cove is a radial mainland for the LOD system")
check(cove:GetAttribute("CoveVersion") == Cove.VERSION, "The cove records its version")
check(Cove.build(map) == cove, "A current cove is kept, not rebuilt")
check(doomed.Parent == nil and shells:FindFirstChild("501") == nil, "Scenery on the site is cleared with its shell")
check(spared.Parent == tropics and shells:FindFirstChild("502") ~= nil, "Scenery elsewhere is untouched")

-- Climate: the whole island, out to the wreck, is in the Coral Shallows.
local function biome(p) return (Vector2.new(p.X, p.Z) - Biomes.Tropical.center).Magnitude / Biomes.Tropical.radius end
for _, offset in { v3(0, 0, 0), v3(Data.RADIUS, 0, 0), v3(-Data.RADIUS, 0, 0), v3(0, 0, Data.RADIUS), v3(0, 0, -Data.RADIUS - 72), v3(150, 0, -150) } do
  local p = CENTER + offset
  local depth = biome(p)
  local normal = (Vector2.new(p.X, p.Z) - Biomes.Normal.center).Magnitude / Biomes.Normal.radius
  check(depth < 1 and depth < normal, "Pirate Cove is tropical at offset " .. fmt(offset.X) .. "," .. fmt(offset.Z))
end
check((Vector2.new(CENTER.X, CENTER.Z) - Biomes.Tropical.center).Magnitude > 420 * 1.35 + Data.RADIUS * 1.35, "The cove stays clear of the central atoll")

-- Buildings and stalls: where they are, and that none overlap.
local footprints = {}
for _, d in cove:GetDescendants() do
  if d:IsA("Model") and (d.Name == "Tavern" or d.Name == "Shack" or d.Name == "BuyerStall" or d.Name == "RodStall") then
    local frame, size = d:GetBoundingBox()
    table.insert(footprints, { name = d.Name, lo = v3(frame.X - size.X / 2, 0, frame.Z - size.Z / 2), hi = v3(frame.X + size.X / 2, 0, frame.Z + size.Z / 2), top = frame.Y + size.Y / 2 })
  end
end
check(#footprints == 9, "Tavern, six shacks and two stalls are built (" .. #footprints .. ")")
local function inside(f, p, pad)
  return p.X > f.lo.X - pad and p.X < f.hi.X + pad and p.Z > f.lo.Z - pad and p.Z < f.hi.Z + pad
end
for i = 1, #footprints do
  for j = i + 1, #footprints do
    local a, b = footprints[i], footprints[j]
    local overlap = a.lo.X < b.hi.X and b.lo.X < a.hi.X and a.lo.Z < b.hi.Z and b.lo.Z < a.hi.Z
    check(not overlap, string.format("%s (%s..%s, %s..%s) overlaps %s (%s..%s, %s..%s)", a.name, fmt(a.lo.X - CENTER.X), fmt(a.hi.X - CENTER.X), fmt(a.lo.Z - CENTER.Z), fmt(a.hi.Z - CENTER.Z), b.name, fmt(b.lo.X - CENTER.X), fmt(b.hi.X - CENTER.X), fmt(b.lo.Z - CENTER.Z), fmt(b.hi.Z - CENTER.Z)))
  end
end

-- The crew: everyone has dry, open ground (or the pier deck) and none stand inside a building.
local anchors = 0
for id, npc in Data.Npcs do
  local feet
  if type(npc.Spot) == "string" then
    local anchor = cove:GetAttribute("Anchor_" .. npc.Spot)
    check(typeof(anchor) == "CFrame", id .. "'s anchor " .. npc.Spot .. " is set")
    feet = anchor.Position
    anchors += 1
  else
    local hit = workspace:Raycast(CENTER + v3(npc.Spot[1], 300, npc.Spot[2]), v3(0, -400, 0))
    check(hit ~= nil, id .. " has ground under their spot")
    feet = hit.Position
  end
  check(feet.Y > 2, id .. " stands above the water (y " .. fmt(feet.Y) .. ")")
  for _, f in footprints do
    -- Stall keepers stand behind their own counter, inside its canopy.
    local own = (npc.Spot == "BuyerStall" and f.name == "BuyerStall") or (npc.Spot == "RodStall" and f.name == "RodStall")
    if not own then
      check(not inside(f, feet, 0.8), id .. " stands inside the " .. f.name)
    end
  end
end
check(anchors == 4, "Four crew members use named anchors")
local plaza = cove:GetAttribute("Plaza")
check(typeof(plaza) == "Vector3" and plaza.Y > 8, "The plaza sits on the island top")
for _, name in { "BuyerStall", "RodStall" } do
  local anchor = cove:GetAttribute("Anchor_" .. name)
  local toPlaza = (v3(plaza.X, anchor.Y, plaza.Z) - anchor.Position).Unit
  check(anchor.LookVector:Dot(toPlaza) > 0.9, name .. "'s keeper faces the plaza")
end

-- The pier: its keeper stands on the deck, and the far end is over open water.
local pierDeck, docks = nil, 0
for _, d in cove:GetDescendants() do
  if d:IsA("Model") and d.Name == "Dock" then
    docks += 1
    pierDeck = d
  end
end
check(docks == 1, "One pier is built")
local _, pierSize = pierDeck:GetBoundingBox()
local pierFrame = pierDeck:GetBoundingBox()
check(pierSize.Z > 60, "The pier is long (" .. fmt(pierSize.Z) .. ")")
local tip = workspace:Raycast(v3(pierFrame.X, 300, pierFrame.Z - pierSize.Z / 2 + 3), v3(0, -400, 0))
check(tip == nil or tip.Position.Y < -2, "The pier ends over water")
local pier = cove:GetAttribute("Anchor_Pier")
check(math.abs(pier.Y - 3.3) < 0.01 and pier.Z < CENTER.Z - Data.RADIUS * 0.5, "Barnaby stands out on the pier deck")

local parts, wedges = 0, 0
for _, d in cove:GetDescendants() do
  if d:IsA("BasePart") then
    parts += 1
    if d.ClassName == "WedgePart" then wedges += 1 end
  end
end
check(parts < 12000, "The cove stays a sensible size (" .. parts .. " parts)")
print(string.format("Pirate Cove: %d parts (%d wedges), %d ground triangles", parts, wedges, #triangles))
print("Pirate Cove: " .. checks .. " checks passed")
for _, line in printed do _G_print(line) end
if PREVIEW then
  for _, d in cove:GetDescendants() do
    if d:IsA("BasePart") and d.Transparency < 1 then
      local c, s = d.CFrame, d.Size / 2
      local corners
      if d.ClassName == "WedgePart" then
        corners = { c * v3(s.X, -s.Y, -s.Z), c * v3(s.X, -s.Y, s.Z), c * v3(s.X, s.Y, s.Z) }
      else
        corners = { c * v3(-s.X, s.Y, -s.Z), c * v3(s.X, s.Y, -s.Z), c * v3(s.X, s.Y, s.Z), c * v3(-s.X, s.Y, s.Z) }
      end
      local top, pts = -math.huge, {}
      for _, q in corners do top = math.max(top, q.Y); table.insert(pts, fmt(q.X - CENTER.X) .. "," .. fmt(q.Z - CENTER.Z)) end
      local col = d.Color
      -- Only what shows above the waterline.
      if top > 0 then _G_print(string.format("@%s|%d,%d,%d|%s", fmt(top), col.R * 255, col.G * 255, col.B * 255, table.concat(pts, " "))) end
    end
  end
  for id, npc in Data.Npcs do
    local feet = if type(npc.Spot) == "string" then cove:GetAttribute("Anchor_" .. npc.Spot).Position else CENTER + v3(npc.Spot[1], 0, npc.Spot[2])
    local x, z = feet.X - CENTER.X, feet.Z - CENTER.Z
    _G_print(string.format("@999|255,0,255|%s,%s %s,%s %s,%s %s,%s", fmt(x - 1.5), fmt(z - 1.5), fmt(x + 1.5), fmt(z - 1.5), fmt(x + 1.5), fmt(z + 1.5), fmt(x - 1.5), fmt(z + 1.5)))
  end
end
`;

const program = 'local _G_print = print\nlocal PREVIEW = ' + (previewPath ? 'true' : 'false') + '\n' + bundle;
const temporary = await mkdtemp(join(tmpdir(), 'fishing-cove-'));
try {
  const path = join(temporary, 'cove.luau');
  await writeFile(path, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', path], { cwd: root, encoding: 'utf8', timeout: 240000, maxBuffer: 1 << 26 });
  if (result.error) throw result.error;
  const plan = [];
  for (const line of (result.stdout || '').split(/\r?\n/)) {
    if (line.startsWith('@')) plan.push(line.slice(1));
    else if (line) console.log(line);
  }
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.status !== 0) throw new Error('Pirate Cove check failed');
  if (previewPath) {
    await writeFile(previewPath, rasterize(plan));
    console.log('Preview written to ' + previewPath);
  }
} finally {
  if (dirname(temporary) !== resolve(tmpdir())) throw new Error('Unexpected temporary directory');
  await rm(temporary, { recursive: true, force: true });
}

// Scanline-fills each plan polygon (lowest first) onto a 2-px-per-stud PNG centred on the island.
function rasterize(rows) {
  const half = 260, scale = 2, size = half * 2 * scale;
  const pixels = Buffer.alloc(size * size * 3);
  for (let i = 0; i < size * size; i++) pixels.set([40, 150, 160], i * 3);
  rows.sort((a, b) => parseFloat(a) - parseFloat(b));
  for (const row of rows) {
    const [, col, pts] = row.split('|');
    const rgb = col.split(',').map(Number);
    const poly = pts.split(' ').map((p) => p.split(',').map((v) => (Number(v) + half) * scale));
    const ys = poly.map((p) => p[1]);
    for (let y = Math.max(0, Math.floor(Math.min(...ys))); y <= Math.min(size - 1, Math.ceil(Math.max(...ys))); y++) {
      const xs = [];
      for (let i = 0; i < poly.length; i++) {
        const [x1, y1] = poly[i], [x2, y2] = poly[(i + 1) % poly.length];
        if ((y1 <= y + 0.5 && y2 > y + 0.5) || (y2 <= y + 0.5 && y1 > y + 0.5)) xs.push(x1 + ((y + 0.5 - y1) / (y2 - y1)) * (x2 - x1));
      }
      xs.sort((a, b) => a - b);
      for (let k = 0; k + 1 < xs.length; k += 2) {
        for (let x = Math.max(0, Math.round(xs[k])); x < Math.min(size, Math.round(xs[k + 1])); x++) pixels.set(rgb, (y * size + x) * 3);
      }
    }
  }
  const raw = Buffer.alloc(size * (size * 3 + 1));
  for (let y = 0; y < size; y++) pixels.copy(raw, y * (size * 3 + 1) + 1, y * size * 3, (y + 1) * size * 3);
  const table = Array.from({ length: 256 }, (_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
  const crc = (buf) => { let c = 0xffffffff; for (const b of buf) c = table[(c ^ b) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
  const chunk = (type, data) => {
    const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
    const body = Buffer.concat([Buffer.from(type), data]);
    const sum = Buffer.alloc(4); sum.writeUInt32BE(crc(body));
    return Buffer.concat([len, body, sum]);
  };
  const header = Buffer.alloc(13); header.writeUInt32BE(size, 0); header.writeUInt32BE(size, 4); header[8] = 8; header[9] = 2;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', header), chunk('IDAT', deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]);
}
