// Builds real HullDamage shark bites against mock hull planes and checks the marks: every
// piece lies flat on the face it was cast onto (thickness along the normal, on the outside),
// a thin plank shows the hole from inside too, invisible helpers are passed through, pieces
// are welded, cosmetic-only and anchored like their plank, and old bites make way past the cap.
// This checks geometry only, not Roblox rendering or replication.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const source = await readFile(join(root, 'src/server/HullDamage.luau'), 'utf8');

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
V3.__mul = function(a, b)
  if type(a) == "number" then return v3(b.X * a, b.Y * a, b.Z * a) end
  return v3(a.X * b, a.Y * b, a.Z * b)
end
V3.__div = function(a, b) return v3(a.X / b, a.Y / b, a.Z / b) end
function v3methods:Dot(b) return self.X * b.X + self.Y * b.Y + self.Z * b.Z end
function v3methods:Cross(b) return v3(self.Y * b.Z - self.Z * b.Y, self.Z * b.X - self.X * b.Z, self.X * b.Y - self.Y * b.X) end
local Vector3 = { new = v3 }

local CF = {}
local function cf(p, x, y, z) return setmetatable({ Position = p, XVector = x, YVector = y, ZVector = z, LookVector = z * -1 }, CF) end
CF.__mul = function(a, b) return a.Position + a.XVector * b.X + a.YVector * b.Y + a.ZVector * b.Z end
local CFrame = {}
function CFrame.fromMatrix(p, x, y, z)
  check(math.abs(x.Magnitude - 1) < 1e-6 and math.abs(y.Magnitude - 1) < 1e-6 and math.abs(z.Magnitude - 1) < 1e-6, "fromMatrix needs unit axes")
  check(math.abs(x:Dot(y)) < 1e-6 and math.abs(x:Dot(z)) < 1e-6 and math.abs(y:Dot(z)) < 1e-6, "fromMatrix needs orthogonal axes")
  check((x:Cross(y) - z).Magnitude < 1e-6, "fromMatrix needs a right-handed frame")
  return cf(p, x, y, z)
end
local identity = cf(v3(), v3(1, 0, 0), v3(0, 1, 0), v3(0, 0, 1))

local Color3 = {}
local C3 = { __index = {} }
function Color3.fromRGB(r, g, b) return setmetatable({ R = r / 255, G = g / 255, B = b / 255 }, C3) end
function C3.__index:Lerp(o, t) return setmetatable({ R = self.R + (o.R - self.R) * t, G = self.G + (o.G - self.G) * t, B = self.B + (o.B - self.B) * t }, C3) end
local Enum = setmetatable({}, { __index = function(_, group)
  return setmetatable({}, { __index = function(_, name) return group .. "." .. name end })
end })
local seed = 12345
local Random = { new = function() return { NextNumber = function(_, low, high)
  seed = (seed * 1103515245 + 12345) % 2147483648
  local t = seed / 2147483648
  if low == nil then return t end
  return low + (high - low) * t
end } end }
local RaycastParams = { new = function() return {} end }

local created = {}
local methods = {}
local function new(class)
  local props = { ClassName = class, children = {}, attributes = {} }
  local object
  object = setmetatable({}, {
    __index = function(_, key) if props[key] ~= nil then return props[key] end return methods[key] end,
    __newindex = function(_, key, value)
      if key == "Parent" then
        if props.Parent then
          local list = props.Parent.children
          for index, child in list do if child == object then table.remove(list, index) break end end
        end
        props.Parent = value
        if value then table.insert(value.children, object) end
      else
        props[key] = value
      end
    end,
  })
  table.insert(created, object)
  return object
end
function methods:IsA(name)
  if name == "BasePart" then return self.ClassName == "Part" or self.ClassName == "WedgePart" or self.ClassName == "Seat" end
  return self.ClassName == name
end
function methods:GetChildren() return table.clone(self.children) end
function methods:FindFirstChild(name) for _, child in self.children do if child.Name == name then return child end end return nil end
function methods:FindFirstChildOfClass(class) for _, child in self.children do if child.ClassName == class then return child end end return nil end
function methods:SetAttribute(name, value) self.attributes[name] = value end
function methods:GetAttribute(name) return self.attributes[name] end
function methods:Destroy() self.Parent = nil; self.destroyed = true end
local Instance = { new = new }

-- Hull faces are bounded planes. A ray hits a face only travelling against its normal,
-- like the outside of a plank from the sea or its inside from the deck.
local planes = {}
local function plane(part, point, normal, along, halfAlong, halfUp)
  table.insert(planes, { part = part, point = point, normal = normal.Unit, along = along.Unit, up = normal.Unit:Cross(along.Unit), halfAlong = halfAlong, halfUp = halfUp })
end
local casts = 0
local workspace = {}
function workspace:Raycast(origin, direction, params)
  casts += 1
  check(params.FilterType == "RaycastFilterType.Include", "Hull rays must only see the boat")
  local best
  for _, face in planes do
    local approach = direction:Dot(face.normal)
    if approach < 0 then
      local t = (face.point - origin):Dot(face.normal) / approach
      if t >= 0 and t <= 1 then
        local position = origin + direction * t
        local offset = position - face.point
        if math.abs(offset:Dot(face.along)) <= face.halfAlong and math.abs(offset:Dot(face.up)) <= face.halfUp then
          if not best or t < best.t then
            best = { t = t, Instance = face.part, Position = position, Normal = face.normal, Distance = direction.Magnitude * t }
          end
        end
      end
    end
  end
  return best
end

local HullDamage = (function()
-- HULL_DAMAGE_SOURCE --
end)()

local function part(class, name, props)
  local p = new(class)
  p.Name = name
  p.Transparency, p.Anchored, p.Material = 0, false, "Material.Wood"
  p.Color = Color3.fromRGB(94, 78, 65)
  for key, value in props or {} do p[key] = value end
  return p
end

local function boat()
  table.clear(planes)
  local model = new("Model")
  model:SetAttribute("HullLength", 14)
  model:SetAttribute("HullBeam", 6)
  local rootPart = part("Part", "HullRoot", { Transparency = 1, Size = v3(3, 0.5, 8), CFrame = identity })
  rootPart.Parent = model
  model.PrimaryPart = rootPart
  return model, rootPart
end

local function corners(piece)
  local s, list = piece.Size, {}
  for _, x in { -1, 1 } do for _, y in { -1, 1 } do for _, z in { -1, 1 } do
    table.insert(list, piece.CFrame * v3(x * s.X / 2, y * s.Y / 2, z * s.Z / 2))
  end end end
  return list
end

local function pieces(bite)
  local list = {}
  for _, piece in bite:GetChildren() do
    if piece:IsA("BasePart") then table.insert(list, piece) end
  end
  return list
end

-- Checks every piece sits within (0, 0.1] outside the face it is on, welded to that plank.
local function checkFlat(bite, plank, faceFor, hitPoint)
  local counts = {}
  for _, piece in pieces(bite) do
    counts[piece.Name] = (counts[piece.Name] or 0) + 1
    check(piece.CanCollide == false and piece.CanTouch == false and piece.CanQuery == false, piece.Name .. " must be cosmetic only")
    check(piece.Massless == true and piece.CastShadow == false, piece.Name .. " must not weigh down or shade the hull")
    local weld = piece:FindFirstChildOfClass("WeldConstraint")
    check(weld and weld.Part1 == piece and weld.Part0 == plank, piece.Name .. " must be welded to the plank it marks")
    check(piece.Anchored == weld.Part0.Anchored, piece.Name .. " must anchor like its plank")
    local face = faceFor(piece)
    for _, corner in corners(piece) do
      local height = (corner - face.point):Dot(face.normal)
      check(height > -1e-6 and height <= 0.1, piece.Name .. " must lie flat just outside its face (" .. height .. ")")
      check((corner - hitPoint).Magnitude < 5, piece.Name .. " must stay near the bite")
    end
  end
  return counts
end

-- A thin vertical plank side, with a transparent helper box the ray must pass through.
do
  local model, rootPart = boat()
  local plank = part("Part", "HullPlank")
  plank.Parent = model
  plane(plank, v3(3, 0.8, 0), v3(1, 0, 0), v3(0, 0, -1), 7, 1.4)
  plane(plank, v3(2.86, 0.8, 0), v3(-1, 0, 0), v3(0, 0, -1), 7, 1.4)
  local helper = part("Part", "Collision", { Transparency = 1 })
  plane(helper, v3(4, 0.8, 0), v3(1, 0, 0), v3(0, 0, -1), 7, 2)
  local bench = part("Seat", "Bench")
  plane(bench, v3(5, 0.8, 0), v3(1, 0, 0), v3(0, 0, -1), 0.5, 2)
  local bite = HullDamage.bite(model, v3(9, 0, 0.2), v3(-1, 0, 0))
  check(bite and bite.Parent and bite.Parent.Name == HullDamage.FOLDER and bite.Parent.Parent == model, "A bite should be filed under the boat's HullDamage folder")
  local outer = { point = v3(3, 0, 0), normal = v3(1, 0, 0) }
  local inner = { point = v3(2.86, 0, 0), normal = v3(-1, 0, 0) }
  local innerPieces = 0
  for _, piece in pieces(bite) do
    if piece.CFrame.Position.X < 2.93 then innerPieces += 1 end
  end
  check(innerPieces == 1, "A thin plank should show the hole from inside (" .. innerPieces .. ")")
  local counts = checkFlat(bite, plank, function(piece)
    return if piece.CFrame.Position.X < 2.93 then inner else outer
  end, v3(3, 0.6, 0.2))
  check(counts.BiteHole == 4, "Expected a ragged three-disc breach plus its inside (" .. tostring(counts.BiteHole) .. ")")
  check(counts.BiteTooth == 20, "Expected ten triangular tooth punctures (" .. tostring(counts.BiteTooth) .. ")")
  check(counts.BiteSplinter == 12, "Expected six splinters around the breach (" .. tostring(counts.BiteSplinter) .. ")")
  check(counts.BiteGouge == 18, "Expected three two-tone gouges of three segments (" .. tostring(counts.BiteGouge) .. ")")
  for _, piece in pieces(bite) do
    if piece.Name == "BiteHole" then check(piece.Shape == "PartType.Cylinder", "Breach discs must be cylinders") end
  end
  -- Past the cap the oldest bite makes way.
  for _ = 1, HullDamage.MAX_BITES + 3 do
    check(HullDamage.bite(model, v3(9, 0, math.random() * 6 - 3), v3(-1, 0, 0)), "Every bite on the side should land")
  end
  local folder = model:FindFirstChild(HullDamage.FOLDER)
  local orders = {}
  for _, child in folder:GetChildren() do table.insert(orders, child:GetAttribute("Order")) end
  table.sort(orders)
  check(#orders == HullDamage.MAX_BITES and orders[1] == 5 and orders[#orders] == HullDamage.MAX_BITES + 4, "Only the newest bites should remain")
  -- A shark facing away from the hull marks nothing.
  check(HullDamage.bite(model, v3(9, 0, 0), v3(1, 0, 0)) == nil, "A lunge that misses the hull must not mark it")
  check(HullDamage.bite(model, v3(9, 0, 0), v3(0, 1, 0)) == nil, "A vertical direction must not mark the hull")
end

-- A flared, anchored (parked) hull side on the port bow: marks follow its tilt.
do
  local model = boat()
  local plank = part("WedgePart", "HullPanel", { Anchored = true, Material = "Material.SmoothPlastic", Color = Color3.fromRGB(200, 40, 40) })
  plank.Parent = model
  local normal = v3(-math.cos(math.rad(25)), math.sin(math.rad(25)), 0.2).Unit
  local along = v3(0, 0, -1)
  along = (along - normal * along:Dot(normal)).Unit
  plane(plank, v3(-3, 0.8, -2), normal, along, 8, 2)
  local bite = HullDamage.bite(model, v3(-10, 0, -1), v3(1, 0, -0.1))
  check(bite, "A bite should land on a flared bow")
  local counts = checkFlat(bite, plank, function() return { point = v3(-3, 0.8, -2), normal = normal } end, v3(-3, 0.8, -1))
  check(counts.BiteHole == 3, "A solid panel shows no inside hole (" .. tostring(counts.BiteHole) .. ")")
  for _, piece in pieces(bite) do
    if piece.Name == "BiteSplinter" then
      check(piece.Material == "Material.SmoothPlastic" and piece.Color.R + piece.Color.G + piece.Color.B > plank.Color.R + plank.Color.G + plank.Color.B + 0.4, "Non-wood hulls should crack to bare, pale edges")
    end
  end
end

print(("Hull damage: %d checks passed (%d raycasts)."):format(checks, casts))
`;

const temporary = await mkdtemp(join(tmpdir(), 'fishing-hull-damage-'));
try {
  const target = join(temporary, 'hull-damage.luau');
  await writeFile(target, program.replace('-- HULL_DAMAGE_SOURCE --', source.replace(/\r\n/g, '\n')));
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { cwd: root, encoding: 'utf8' });
  process.stdout.write(result.stdout || '');
  process.stderr.write(result.stderr || '');
  if (result.error) throw result.error;
  if (result.status !== 0) process.exitCode = result.status || 1;
} finally {
  await rm(temporary, { recursive: true, force: true });
}
