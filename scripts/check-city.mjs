// Builds the real distant city (ModernCity, CityLand, CityPort, CityRefinery, CityMetro,
// CityBuildings, the station and landmark, Props and the server Lod) against recording mocks,
// then checks its geography: the estuary stays navigable, buildings stand on land, the hills
// behind the city meet the mainland without a step and dress their facets exactly, the metro
// is walkable from the plaza to both platforms and stays inside its dry pocket, parts stay
// within Roblox limits, streaming pieces stay small and the distant shell comes in
// ground-counted tiles.
// Pass --preview <file.html> to also write a top-down plan of the result.
// This checks geometry only, not Roblox rendering, physics or streaming.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const previewIndex = process.argv.indexOf('--preview');
const previewPath = previewIndex > 0 ? resolve(process.argv[previewIndex + 1]) : null;
const modules = ['LowPoly', 'Props', 'CityLand', 'CityCircuit', 'CityHills', 'CityBuildings', 'CityLandmark', 'CityStation', 'CityPort', 'CityRefinery', 'CityMetro', 'MetroStations', 'Lod', 'ModernCity', 'Biomes'];
const sources = {};
for (const name of modules) {
  const folder = name === 'Biomes' ? 'src/shared' : 'src/server/Map';
  sources[name] = await readFile(join(root, folder, name + '.luau'), 'utf8');
}

const mocks = String.raw`
local checks = 0
local function check(value, message) checks += 1; if not value then error(message, 2) end end
local function fmt(x) return string.format("%.1f", x) end

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
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3.__type = "Vector3"
function v3methods:Dot(b) return self.X * b.X + self.Y * b.Y + self.Z * b.Z end
function v3methods:Cross(b) return v3(self.Y * b.Z - self.Z * b.Y, self.Z * b.X - self.X * b.Z, self.X * b.Y - self.Y * b.X) end
function v3methods:Lerp(b, t) return self + (b - self) * t end
local Vector3 = { new = v3, zero = v3(0, 0, 0), one = v3(1, 1, 1), xAxis = v3(1, 0, 0), yAxis = v3(0, 1, 0), zAxis = v3(0, 0, 1) }

local V2 = {}
local function v2(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, V2) end
V2.__index = function(a, key) if key == "Magnitude" then return math.sqrt(a.X * a.X + a.Y * a.Y) end end
V2.__sub = function(a, b) return v2(a.X - b.X, a.Y - b.Y) end
V2.__add = function(a, b) return v2(a.X + b.X, a.Y + b.Y) end
local Vector2 = { new = v2 }

local CF = {}
local function cf(p, r, u, b) return setmetatable({ p = p, r = r, u = u, b = b }, CF) end
local function rotate(c, v) return c.r * v.X + c.u * v.Y + c.b * v.Z end
CF.__index = function(c, key)
  if key == "Position" then return c.p end
  if key == "X" then return c.p.X elseif key == "Y" then return c.p.Y elseif key == "Z" then return c.p.Z end
  if key == "RightVector" or key == "XVector" then return c.r end
  if key == "UpVector" or key == "YVector" then return c.u end
  if key == "LookVector" then return -c.b end
  if key == "ZVector" then return c.b end
  if key == "Rotation" then return cf(Vector3.zero, c.r, c.u, c.b) end
  if key == "PointToWorldSpace" then return function(self, v) return self.p + rotate(self, v) end end
  if key == "VectorToWorldSpace" then return function(self, v) return rotate(self, v) end end
  if key == "PointToObjectSpace" then return function(self, v) local d = v - self.p; return v3(d:Dot(self.r), d:Dot(self.u), d:Dot(self.b)) end end
  if key == "Inverse" then return function(self)
    local r, u, b = v3(self.r.X, self.u.X, self.b.X), v3(self.r.Y, self.u.Y, self.b.Y), v3(self.r.Z, self.u.Z, self.b.Z)
    local inv = cf(Vector3.zero, r, u, b)
    return cf(-rotate(inv, self.p), r, u, b)
  end end
  if key == "ToObjectSpace" then return function(self, other) return self:Inverse() * other end end
end
CF.__mul = function(a, b)
  if getmetatable(b) == V3 then return a.p + rotate(a, b) end
  return cf(a.p + rotate(a, b.p), rotate(a, b.r), rotate(a, b.u), rotate(a, b.b))
end
CF.__add = function(a, v) return cf(a.p + v, a.r, a.u, a.b) end
CF.__sub = function(a, v) return cf(a.p - v, a.r, a.u, a.b) end
CF.__type = "CFrame"
local CFrame = {}
function CFrame.new(x, y, z)
  local p = if type(x) == "table" then x else v3(x or 0, y or 0, z or 0)
  return cf(p, Vector3.xAxis, Vector3.yAxis, Vector3.zAxis)
end
function CFrame.fromMatrix(p, r, u, b) return cf(p, r, u, b or r:Cross(u).Unit) end
function CFrame.Angles(x, y, z)
  local cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
  local rx = cf(Vector3.zero, v3(1, 0, 0), v3(0, cx, sx), v3(0, -sx, cx))
  local ry = cf(Vector3.zero, v3(cy, 0, -sy), v3(0, 1, 0), v3(sy, 0, cy))
  local rz = cf(Vector3.zero, v3(cz, sz, 0), v3(-sz, cz, 0), v3(0, 0, 1))
  return rx * ry * rz
end
function CFrame.lookAt(at, target, up)
  local look = (target - at).Unit
  local right = look:Cross(up or Vector3.yAxis)
  if right.Magnitude < 1e-6 then right = look:Cross(Vector3.zAxis) end
  right = right.Unit
  return cf(at, right, right:Cross(look), -look)
end
CFrame.identity = CFrame.new()

local C3 = { __type = "Color3" }
C3.__index = { Lerp = function(a, b, t) return setmetatable({ R = a.R + (b.R - a.R) * t, G = a.G + (b.G - a.G) * t, B = a.B + (b.B - a.B) * t }, C3) end }
local Color3 = {}
function Color3.new(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3) end
function Color3.fromRGB(r, g, b) return Color3.new(r / 255, g / 255, b / 255) end
function Color3.fromHSV(h, s, v) return Color3.new(v, v, v) end

local Enum = setmetatable({}, { __index = function(self, category)
  local values = setmetatable({}, { __index = function(t, name) local token = "Enum." .. category .. "." .. name; rawset(t, name, token); return token end })
  rawset(self, category, values)
  return values
end })

local function typeof(value)
  local mt = getmetatable(value)
  if type(mt) == "table" and mt.__type then return mt.__type end
  return type(value)
end

local function signal() return { Connect = function() return { Disconnect = function() end } end } end
local BASEPART = { Part = true, WedgePart = true, UnionOperation = true, MeshPart = true, TrussPart = true, CornerWedgePart = true }
local Inst = {}
local methods = {}
local nextId = 0
local function newInstance(class)
  nextId += 1
  local self = setmetatable({ _class = class, _props = { Name = class, ClassName = class }, _children = {}, _attrs = {}, _tags = {}, _id = nextId }, Inst)
  if BASEPART[class] then
    self._props.Size = v3(4, 1, 2)
    self._props.CFrame = CFrame.new()
    self._props.Transparency = 0
    self._props.CanCollide = true
    self._props.CanQuery = true
    self._props.Shape = "Enum.PartType.Block"
    self._props.Color = Color3.new(0.6, 0.6, 0.6)
    self._props.Material = "Enum.Material.Plastic"
  end
  if class == "Model" then self._props.ModelStreamingMode = "Enum.ModelStreamingMode.Default" end
  return self
end
Inst.__index = function(self, key)
  local m = methods[key]
  if m then return m end
  if key == "Position" then return self._props.CFrame.p end
  if key == "Parent" then return self._parent end
  if key == "ChildAdded" or key == "DescendantAdded" or key == "Destroying" or key == "AncestryChanged" then return signal() end
  local v = self._props[key]
  if v ~= nil then return v end
  return nil
end
Inst.__newindex = function(self, key, value)
  if key == "Parent" then
    if self._parent then
      local list = self._parent._children
      for i, c in list do if c == self then table.remove(list, i) break end end
    end
    self._parent = value
    if value then table.insert(value._children, self) end
  elseif key == "Position" then
    local c = self._props.CFrame or CFrame.new()
    self._props.CFrame = cf(value, c.r, c.u, c.b)
  else
    self._props[key] = value
  end
end
Inst.__type = "Instance"
function methods:IsA(class)
  if class == "BasePart" then return BASEPART[self._class] == true end
  if class == "PVInstance" then return BASEPART[self._class] == true or self._class == "Model" end
  return self._class == class
end
function methods:GetChildren() return table.clone(self._children) end
function methods:GetDescendants()
  local out = {}
  local function walk(i) for _, c in i._children do table.insert(out, c); walk(c) end end
  walk(self)
  return out
end
function methods:FindFirstChild(name, recursive)
  for _, c in (if recursive then self:GetDescendants() else self._children) do if c._props.Name == name then return c end end
  return nil
end
function methods:FindFirstChildWhichIsA(class, recursive)
  for _, c in (if recursive then self:GetDescendants() else self._children) do if c:IsA(class) then return c end end
  return nil
end
function methods:FindFirstChildOfClass(class)
  for _, c in self._children do if c._class == class then return c end end
  return nil
end
function methods:SetAttribute(k, v) self._attrs[k] = v end
function methods:GetAttribute(k) return self._attrs[k] end
function methods:GetAttributes() return table.clone(self._attrs) end
function methods:AddTag(tag) self._tags[tag] = true end
function methods:RemoveTag(tag) self._tags[tag] = nil end
function methods:HasTag(tag) return self._tags[tag] == true end
function methods:GetAttributeChangedSignal() return signal() end
function methods:Destroy() self.Parent = nil; self._destroyed = true end
function methods:ClearAllChildren() for _, c in self:GetChildren() do c.Parent = nil end end
function methods:IsDescendantOf(a) local p = self._parent; while p do if p == a then return true end; p = p._parent end; return false end
function methods:Clone()
  local copy = newInstance(self._class)
  for k, v in self._props do copy._props[k] = v end
  for k, v in self._attrs do copy._attrs[k] = v end
  for k, v in self._tags do copy._tags[k] = v end
  for _, c in self._children do c:Clone().Parent = copy end
  return copy
end
local function halfExtent(p)
  local c, s = p._props.CFrame, p._props.Size / 2
  return v3(
    math.abs(c.r.X) * s.X + math.abs(c.u.X) * s.Y + math.abs(c.b.X) * s.Z,
    math.abs(c.r.Y) * s.X + math.abs(c.u.Y) * s.Y + math.abs(c.b.Y) * s.Z,
    math.abs(c.r.Z) * s.X + math.abs(c.u.Z) * s.Y + math.abs(c.b.Z) * s.Z)
end
function methods:GetBoundingBox()
  local lo, hi = v3(math.huge, math.huge, math.huge), v3(-math.huge, -math.huge, -math.huge)
  for _, d in self:GetDescendants() do
    if d:IsA("BasePart") then
      local p, h = d._props.CFrame.p, halfExtent(d)
      lo = v3(math.min(lo.X, p.X - h.X), math.min(lo.Y, p.Y - h.Y), math.min(lo.Z, p.Z - h.Z))
      hi = v3(math.max(hi.X, p.X + h.X), math.max(hi.Y, p.Y + h.Y), math.max(hi.Z, p.Z + h.Z))
    end
  end
  return CFrame.new((lo + hi) / 2), hi - lo
end
local Instance = { new = newInstance }
local UDim2 = { new = function(...) return { ... } end, fromScale = function(...) return { ... } end, fromOffset = function(...) return { ... } end }
local ColorSequence = { new = function(...) return { ... } end }
local NumberSequence = { new = function(...) return { ... } end }
local NumberRange = { new = function(...) return { ... } end }
local UDim = { new = function(...) return { ... } end }

local unions = 0
local GeometryService = {}
function GeometryService:UnionAsync(first, others, options)
  unions += 1
  local union = newInstance("UnionOperation")
  union._props.CFrame = first._props.CFrame
  union._props.Size = first._props.Size
  union._attrs.Members = 1 + #others
  return { union }
end
local function encode(value)
  if type(value) == "table" then
    local out = {}
    for _, v in value do table.insert(out, encode(v)) end
    return "[" .. table.concat(out, ",") .. "]"
  end
  return tostring(value)
end
local HttpService = { JSONEncode = function(_, value) return encode(value) end }
local game = { GetService = function(_, name)
  if name == "HttpService" then return HttpService end
  if name == "GeometryService" then return GeometryService end
  return {}
end }
local workspace = newInstance("Workspace")
local printed = {}
local function print(...) local line = table.concat({ ... }, " "); table.insert(printed, line) end
local function warn(...) table.insert(printed, "WARN " .. table.concat({ ... }, " ")) end
local task = { wait = function() end, spawn = function(f, ...) f(...) end, defer = function(f, ...) f(...) end }
local RaycastParams = { new = function() return {} end }
`;

let bundle = mocks + '\nlocal loaded, loaders = {}, {}\nlocal function require(target) local name = target.__module; if loaded[name] == nil then loaded[name] = loaders[name]() end; return loaded[name] end\n';
bundle += 'local script = { Parent = setmetatable({}, { __index = function(_, name) return { __module = name } end }) }\n';
for (const name of modules) {
  bundle += `loaders[${JSON.stringify(name)}] = function()\n${sources[name]}\nend\n`;
}

bundle += String.raw`
local City = require({ __module = "ModernCity" })
local CityLand = require({ __module = "CityLand" })
local CityPort = require({ __module = "CityPort" })
local Lod = require({ __module = "Lod" })
local CENTER, TOP = v3(7000, 0, 7000), 8

local map = Instance.new("Folder")
map.Name = "Map"
local city = City.build(map)
check(city.Parent == map and city.Name == "Modern City", "City is published under the map")
check(city:GetAttribute("LodRoot") == true and city:GetAttribute("LodStamp") == "city" .. City.VERSION, "City is marked as a mainland for the LOD system")
local ground = city:FindFirstChild("Ground")
check(ground ~= nil, "Everything visible sits under the city's Ground model")
check(city:FindFirstChild("CityArrival") ~= nil, "The /tp city arrival point is a direct child of the city")

local parts = {}
for _, d in city:GetDescendants() do if d:IsA("BasePart") then table.insert(parts, d) end end
for _, p in parts do
  local s = p.Size
  check(s.X > 0 and s.Y > 0 and s.Z > 0 and s.X <= 2048 and s.Y <= 2048 and s.Z <= 2048, "Part " .. p.Name .. " size is within Roblox limits")
end

-- Exact containment for blocks, wedges and balls, so diagonal coast wedges are not mistaken for their bounding boxes
local function contains(p, point)
  local c, s = p.CFrame, p.Size / 2
  local d = point - c.p
  local lx, ly, lz = d:Dot(c.r), d:Dot(c.u), d:Dot(c.b)
  if p.Shape == "Enum.PartType.Ball" then return d.Magnitude <= s.X end
  if math.abs(lx) > s.X or math.abs(ly) > s.Y or math.abs(lz) > s.Z then return false end
  if p.ClassName == "WedgePart" then return (ly + s.Y) / (2 * s.Y) <= (lz + s.Z) / (2 * s.Z) end
  return true
end
local solids = {}
for _, p in parts do if p.CanCollide and p.Transparency < 1 then table.insert(solids, p) end end
local function blockedAt(point)
  for _, p in solids do
    local h, c = halfExtent(p), p.CFrame.p
    if math.abs(point.X - c.X) <= h.X and math.abs(point.Y - c.Y) <= h.Y and math.abs(point.Z - c.Z) <= h.Z and contains(p, point) then return p end
  end
  return nil
end

-- The channel stays open from the sea to the marina
local channel = CityPort.CHANNEL
local samples = 0
local approach = { { channel[1][1] - 120, channel[1][2] - 260 } }
for _, point in channel do table.insert(approach, point) end
for i = 1, #approach - 1 do
  local a, b = approach[i], approach[i + 1]
  local dx, dz = b[1] - a[1], b[2] - a[2]
  local length = math.sqrt(dx * dx + dz * dz)
  local nx, nz = -dz / length, dx / length
  for t = 0, 1, 12 / length do
    for _, offset in { -55, 0, 55 } do
      for _, y in { 0.5, 5 } do
        samples += 1
        local x, z = a[1] + dx * t + nx * offset, a[2] + dz * t + nz * offset
        local hit = blockedAt(CENTER + v3(x, y, z))
        check(hit == nil, "Channel blocked at " .. fmt(x) .. "," .. fmt(z) .. " by " .. (hit and hit.Name or ""))
      end
    end
  end
end
-- And the head basin in front of the marina pontoons
for x = CityPort.WEST_QUAY + 15, CityPort.EAST_QUAY - 15, 10 do
  check(blockedAt(CENTER + v3(x, 1, -300)) == nil, "Head basin is open water at x " .. x)
end
-- The eastern docks: every slip is open water from the basin to its back wall, and every
-- jetty is a walkable quay all the way out to its head
local docks = CityPort.DOCKS
local slips = CityPort.slips()
check(#CityPort.JETTIES >= 4 and #slips == #CityPort.JETTIES + 1, "Eastern docks have " .. #CityPort.JETTIES .. " jetties and " .. #slips .. " slips")
for index, slip in slips do
  check(slip[2] - slip[1] >= 70, "Slip " .. index .. " is wide enough for a ship")
  for x = docks.x0 - 20, docks.back - 8, 8 do
    for _, z in { slip[1] + 8, (slip[1] + slip[2]) / 2, slip[2] - 8 } do
      check(blockedAt(CENTER + v3(x, 1, z)) == nil, "Slip " .. index .. " is open water at " .. fmt(x) .. "," .. fmt(z))
    end
  end
end
for index, jetty in CityPort.JETTIES do
  local z = (jetty[1] + jetty[2]) / 2
  for _, x in { docks.x0 + 3, (docks.x0 + docks.back) / 2, docks.back - 3 } do
    check(blockedAt(CENTER + v3(x, TOP + 0.2, jetty[1] + 4)) ~= nil, "Jetty " .. index .. " has a quay to stand on at x " .. x)
  end
  local hit = blockedAt(CENTER + v3(docks.x0 + 8, TOP + 3, z))
  check(hit == nil, "Jetty " .. index .. " head is clear to walk to" .. (if hit then " (" .. hit.Name .. ")" else ""))
end
-- Off the north end of the container terminal the estuary stays wide, right across to the east bank
for x = CityPort.WEST_QUAY + 15, -260, 10 do
  for _, z in { -900, -800 } do
    check(blockedAt(CENTER + v3(x, 1, z)) == nil, "Estuary is open water off the terminal at " .. fmt(x) .. "," .. fmt(z))
  end
end
-- The cruise branch is open water from its mouth to its head, with a quay along each side
local basin = CityPort.CRUISE_BASIN
check(basin.z1 - basin.z0 >= 250 and basin.x1 - basin.x0 >= 400, "Cruise branch is big enough for liners")
for x = basin.x0, basin.x1 - 12, 10 do
  for _, z in { basin.z0 + 12, (basin.z0 + basin.z1) / 2, basin.z1 - 12 } do
    local hit = blockedAt(CENTER + v3(x, 1, z))
    check(hit == nil, "Cruise branch is open water at " .. fmt(x) .. "," .. fmt(z) .. (if hit then " (" .. hit.Name .. ")" else ""))
  end
end
for x = basin.x0 + 30, basin.x1 - 10, 20 do
  check(blockedAt(CENTER + v3(x, TOP + 0.2, basin.z0 - 6)) ~= nil, "North cruise quay has ground at x " .. x)
  check(blockedAt(CENTER + v3(x, TOP + 0.2, basin.z1 + 6)) ~= nil, "South cruise quay has ground at x " .. x)
end
local towers = 0
for _, p in parts do if p.Name == "BoardingTower" then towers += 1 end end
check(towers == 8, "Cruise berths have " .. towers .. " boarding towers")
local bollards = 0
for _, p in parts do if p.Name == "MooringBollard" then bollards += 1 end end
check(bollards > 80, "Berths are lined with " .. bollards .. " bollards")

-- Buildings stand on land, clear of the water
local coast = CityLand.roughen(City.COAST, 110, 22)
local buildings = 0
for _, d in ground:GetDescendants() do
  if d:IsA("Model") and d:GetAttribute("LodColor") and (d.Name:match("^CityBlock") or d.Name:match("^CityBuilding") or d.Name:match("^DockWarehouse") or d.Name == "House") then
    buildings += 1
    local frame, size = d:GetBoundingBox()
    for _, corner in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
      local x = frame.X - CENTER.X + corner[1] * size.X / 2
      local z = frame.Z - CENTER.Z + corner[2] * size.Z / 2
      check(CityLand.inside(coast, x, z), d.Name .. " overhangs the water at " .. fmt(x) .. "," .. fmt(z))
    end
    check(frame.Y - size.Y / 2 >= TOP - 1, d.Name .. " does not sink into the ground")
  end
end
check(buildings > 150, "The city is dense: " .. buildings .. " buildings")

-- Walkable ground under the arrival point, the station forecourt and the marina gangways
local arrival = city:FindFirstChild("CityArrival")
check(blockedAt(arrival.Position - v3(0, 0.5, 0)) ~= nil, "Arrival point stands on solid pavement")
local gangways = 0
for _, p in parts do
  if p.Name == "Gangway" then
    gangways += 1
    local rise = math.abs(p.CFrame.LookVector.Y)
    check(rise < math.sin(math.rad(30)), "Gangway is a walkable slope")
    check(blockedAt(p.CFrame.p + p.CFrame.LookVector * (p.Size.Z / 2 + 2) - v3(0, 0.5, 0)) ~= nil, "Gangway lands on the quay")
  end
end
check(gangways == 2, "Two gangways lead up from the marina")
-- Land surface is level with the quays
check(blockedAt(CENTER + v3(-1000, TOP - 0.2, 300)) ~= nil and blockedAt(CENTER + v3(-1000, TOP + 0.4, 300)) == nil, "Countryside ground is at the walkable height")
check(blockedAt(CENTER + v3(-600, 2, -1000)) == nil, "Open water in the middle of the estuary")

-- The hills behind the city
local CityHills = require({ __module = "CityHills" })
local CityCircuit = require({ __module = "CityCircuit" })
local EDGE = CityHills.EDGE
local facets, dressing, hillTop = {}, {}, -math.huge
for _, model in ground:GetChildren() do
  if model.Name == "HillSlope" then
    for _, p in model:GetDescendants() do
      if p:IsA("BasePart") then
        if p:GetAttribute("LodKeep") then
          table.insert(facets, p)
          hillTop = math.max(hillTop, p.CFrame.p.Y)
        else
          table.insert(dressing, p)
        end
        check(p.CFrame.p.X - CENTER.X > EDGE - 3 or p.CFrame.p.Z - CENTER.Z > EDGE - 3, p.Name .. " of the hills stays off the mainland")
      end
    end
  end
end
check(#facets > 3000 and hillTop > 200, "Hills have " .. #facets .. " facets rising to " .. fmt(hillTop))
check(#facets % 2 == 0, "Every hill facet is a whole triangle")
local function facetAt(point)
  for _, p in facets do
    local h, c = halfExtent(p), p.CFrame.p
    if math.abs(point.X - c.X) <= h.X and math.abs(point.Y - c.Y) <= h.Y and math.abs(point.Z - c.Z) <= h.Z and contains(p, point) then return p end
  end
  return nil
end
-- No step where the mainland ends and the hills begin
for x = -1150, 1170, 37 do
  local y = CityHills.surface(x, EDGE + 1)
  check(math.abs(y - TOP) < 1.5, "South foothills start level with the land at x " .. x .. " (" .. fmt(y) .. ")")
  check(blockedAt(CENTER + v3(x, TOP - 0.3, EDGE - 1)) ~= nil and facetAt(CENTER + v3(x, y - 0.3, EDGE + 1)) ~= nil, "South edge is solid on both sides at x " .. x)
end
for z = -1100, 1170, 37 do
  local y = CityHills.surface(EDGE + 1, z)
  check(math.abs(y - TOP) < 1.5, "East foothills start level with the land at z " .. z .. " (" .. fmt(y) .. ")")
  check(blockedAt(CENTER + v3(EDGE - 1, TOP - 0.3, z)) ~= nil and facetAt(CENTER + v3(EDGE + 1, y - 0.3, z)) ~= nil, "East edge is solid on both sides at z " .. z)
end
-- CityHills.surface is the ground you stand on
local probes = 0
-- Off the grid lines, where neighbouring facets meet at a crease
for x = -1100.5, 1800, 83 do
  for z = -1000.5, 1800, 83 do
    if CityHills.covers(x, z) and not CityCircuit.covered(x, z) then
      probes += 1
      local y = CityHills.surface(x, z)
      check(facetAt(CENTER + v3(x, y - 0.3, z)) ~= nil and facetAt(CENTER + v3(x, y + 0.3, z)) == nil, "Hill surface is the facet at " .. x .. "," .. z .. " (" .. fmt(y) .. ")")
    end
  end
end
check(probes > 200, probes .. " hill surface probes")
check(CityHills.surface(-1225, 1300) < 0 and CityHills.surface(1300, -1170) < 0, "Both tips of the range run down into the sea")
-- The track climbs from the suburbs to the mast at a walkable pitch, on the ground
local trackParts, steepest = 0, 0
for _, model in ground:GetChildren() do
  if model.Name == "HillTrack" then
    for _, p in model:GetChildren() do
      if p.Name == "HillTrack" then
        trackParts += 1
        local c = p.CFrame.p
        steepest = math.max(steepest, math.abs(p.CFrame.LookVector.Y))
        local y = CityHills.surface(c.X - CENTER.X, c.Z - CENTER.Z)
        check(c.Y > y - 0.2 and c.Y < y + 1, "Track rests on the ground at " .. fmt(c.X - CENTER.X) .. "," .. fmt(c.Z - CENTER.Z))
      end
    end
  end
end
check(trackParts > 80 and steepest < math.sin(math.rad(32)), trackParts .. " track pieces, steepest pitch " .. fmt(math.deg(math.asin(steepest))) .. " degrees")
local track = CityHills.TRACK
check(track[1][1] < 1120 and math.abs(track[1][2] - 1110) < 7, "Track starts on the last suburb road")
check(track[#track][1] == CityHills.SUMMIT[1] and track[#track][2] == CityHills.SUMMIT[2], "Track ends at the summit")
local summit = ground:FindFirstChild("HillSummit")
check(summit ~= nil and summit:FindFirstChild("RadioMast") ~= nil and summit:FindFirstChild("MastLight") ~= nil, "A radio mast stands on the summit")
-- Trees, hedges and tors stand on the facets
local hillTrees, hedges, sheep, tors = 0, 0, 0, 0
for _, p in dressing do
  local c, y = p.CFrame.p, CityHills.surface(p.CFrame.p.X - CENTER.X, p.CFrame.p.Z - CENTER.Z)
  if p.Name == "TreeTrunk" or p.Name == "PineTrunk" then
    hillTrees += 1
    local bottom = c.Y - p.Size.Y / 2
    check(bottom <= y and bottom > y - 3, p.Name .. " is rooted in the hillside at " .. fmt(c.X - CENTER.X) .. "," .. fmt(c.Z - CENTER.Z))
  elseif p.Name == "Hedgerow" then
    hedges += 1
    check(math.abs(c.Y - 1 - y) < 0.3, "Hedgerow follows the ground")
  elseif p.Name == "Sheep" then
    sheep += 1
  elseif p.Name == "Tor" then
    tors += 1
  end
end
check(hillTrees > 300 and hedges > 60 and sheep > 20 and tors > 6, "Hills are dressed: " .. hillTrees .. " trees, " .. hedges .. " hedges, " .. sheep .. " sheep, " .. tors .. " tor slabs")

-- The Grand Prix circuit cut into the foot of the south range
do
  local laps = CityCircuit.samples()
  local HALF = CityCircuit.WIDTH / 2
  check(CityCircuit.LENGTH > 2800, "Circuit lap is " .. CityCircuit.LENGTH .. " studs")
  local circuitParts, asphalt = {}, {}
  for _, model in ground:GetChildren() do
    local name = model.Name
    if name:match("^Circuit") or name == "PitBuilding" or name == "Paddock" or name:match("Grandstand$") then
      check(model:HasTag("LodPiece"), name .. " is a streaming piece")
      for _, p in model:GetDescendants() do
        if p:IsA("BasePart") then
          table.insert(circuitParts, p)
          if name == "CircuitTrack" then table.insert(asphalt, p) end
        end
      end
    end
  end
  local function asphaltAt(point)
    for _, p in asphalt do
      local h, c = halfExtent(p), p.CFrame.p
      if math.abs(point.X - c.X) <= h.X and math.abs(point.Y - c.Y) <= h.Y and math.abs(point.Z - c.Z) <= h.Z and contains(p, point) then return p end
    end
    return nil
  end
  local function across(s, o) return s[1] - s[8] * o, s[2] + s[7] * o end
  local steepest, lowest, highest, worstLip = 0, math.huge, -math.huge, 0
  for k, s in laps do
    local nxt = laps[k % #laps + 1]
    local run = math.sqrt((nxt[1] - s[1]) ^ 2 + (nxt[2] - s[2]) ^ 2)
    check(run > 1.9 and run < 2.1, "Circuit centreline is continuous at sample " .. k)
    steepest = math.max(steepest, math.abs(nxt[3] - s[3]) / run)
    lowest, highest = math.min(lowest, s[3]), math.max(highest, s[3])
    -- All of it, run-off included, on the hills and well back from the mainland edge
    for _, o in { -(HALF + s[4] + 2), HALF + s[5] + 2 } do
      local x, z = across(s, o)
      check(z > EDGE + 55 and CityHills.covers(x, z), "Circuit stays on the hills at " .. fmt(x) .. "," .. fmt(z))
    end
    -- The ground stays under the road all the way across
    for _, o in { -HALF, -HALF / 2, 0, HALF / 2, HALF } do
      local x, z = across(s, o)
      local y = CityHills.surface(x, z)
      check(y < s[3] - 0.3, "Ground stays under the road at " .. fmt(x) .. "," .. fmt(z) .. " (" .. fmt(y) .. " vs " .. fmt(s[3]) .. ")")
      if math.abs(o) == HALF then worstLip = math.max(worstLip, s[3] - y) end
    end
  end
  check(steepest < 0.115, "Circuit gradient peaks at " .. fmt(steepest * 100) .. "%")
  check(highest - lowest > 60, "Circuit climbs " .. fmt(highest - lowest) .. " studs from its lowest to its highest point")
  check(worstLip < 3, "The 3-stud asphalt slab reaches the ground at every edge (worst gap " .. fmt(worstLip) .. ")")
  -- The asphalt is one continuous solid surface at the circuit's level. Probes sit part way
  -- between samples and off the centre, so none lands exactly on a seam between facets.
  for k = 1, #laps, 5 do
    local s, n = laps[k], laps[k % #laps + 1]
    local mid = {}
    for i = 1, 8 do mid[i] = s[i] + (n[i] - s[i]) * 0.37 end
    for _, o in { -HALF + 1.3, 0.7, HALF - 1.3 } do
      local x, z = across(mid, o)
      local p = CENTER + v3(x, mid[3] - 0.15, z)
      check(asphaltAt(p) ~= nil, "Asphalt under foot at " .. fmt(x) .. "," .. fmt(z))
      check(asphaltAt(p + v3(0, 0.4, 0)) == nil, "Road surface is at the circuit level at " .. fmt(x) .. "," .. fmt(z))
    end
  end
  local function centreDistance(x, z)
    local best = math.huge
    for _, s in laps do best = math.min(best, (s[1] - x) ^ 2 + (s[2] - z) ^ 2) end
    return math.sqrt(best)
  end
  local count = {}
  local keep, red, white = 0, 0, 0
  for _, p in circuitParts do
    count[p.Name] = (count[p.Name] or 0) + 1
    local c = p.CFrame.p - CENTER
    if p.Name == "Kerb" then
      if p.Color.R > 0.7 and p.Color.G < 0.3 then red += 1 elseif p.Color.G > 0.8 then white += 1 end
    elseif p.Name == "BarrierPost" then
      local y = CityHills.surface(c.X, c.Z)
      local bottom = p.CFrame.p.Y - p.Size.Y / 2
      check(bottom < y and bottom > y - 1.5, "Barrier post stands on the ground at " .. fmt(c.X) .. "," .. fmt(c.Z))
      check(centreDistance(c.X, c.Z) > HALF + 3, "Barrier stands off the track at " .. fmt(c.X) .. "," .. fmt(c.Z))
    elseif p.Name == "StandStep" then
      local y = CityHills.surface(c.X, c.Z)
      check(p.CFrame.p.Y - p.Size.Y / 2 < y, "Grandstand step reaches the ground at " .. fmt(c.X) .. "," .. fmt(c.Z))
      check((CityCircuit.level(c.X, c.Z)) > 0, "Grandstand stands off the circuit at " .. fmt(c.X) .. "," .. fmt(c.Z))
    elseif p.Name == "BridgeTower" then
      check(centreDistance(c.X, c.Z) > HALF + 8, "Footbridge towers stand off the track")
    elseif p.Name == "PitLane" then
      local top = p.CFrame.p.Y + p.Size.Y / 2
      check(math.abs(top - CityCircuit.startLevel(c.X)) < 0.1, "Pit lane is level with the start straight at x " .. fmt(c.X))
    end
    if p:GetAttribute("LodKeep") then keep += 1 end
  end
  check(red > 150 and white > 150, "Corners have red and white kerbs (" .. red .. "/" .. white .. ")")
  check((count.BarrierPost or 0) > 150 and (count.Armco or 0) > 200, "Armco lines the run-off (" .. (count.Armco or 0) .. " rails)")
  check(#asphalt > 400 and keep == #asphalt, "All " .. #asphalt .. " asphalt facets stand in the distant shell")
  check(count.StartLight == 5 and count.GridSlot == 12 and count.RaceControl == 1, "Start line has its lights, grid and race control")
  check(count.GarageWall == 26 and count.TeamBoard == 25 and (count.Transporter or 0) >= 8, "Pit building has 25 garages and the paddock its transporters")
  check((count.StandStep or 0) > 60 and count.BridgeDeck == 1 and (count.Wedge or 0) == 0, "Grandstands and the footbridge are built")
  -- The paddock road climbs from the last suburb road between the houses
  local road = ground:FindFirstChild("Paddock"):FindFirstChild("PaddockRoad")
  local look = road.CFrame.LookVector
  local low, high = road.CFrame.p - look * (road.Size.Z / 2), road.CFrame.p + look * (road.Size.Z / 2)
  if low.Y > high.Y then low, high = high, low end
  check(low.Z - CENTER.Z < 1118 and math.abs(low.Y + 0.3 - (TOP + 0.2)) < 0.3, "Paddock road starts on the last suburb road")
  check(high.Z - CENTER.Z > CityCircuit.PADDOCK_NORTH and math.abs(high.Y + 0.3 - CityCircuit.startLevel(CityCircuit.ACCESS_X)) < 0.3, "Paddock road reaches the paddock")
  check(math.abs(look.Y) < math.sin(math.rad(20)), "Paddock road is a drivable slope")
  for _, d in ground:GetDescendants() do
    if d.Name == "House" then
      local c = d.CFrame.p - CENTER
      check(math.abs(c.X - CityCircuit.ACCESS_X) > 14 or c.Z < 1110, "No house stands on the paddock road")
    end
  end
  -- Nothing of the hills grows or grazes on the circuit
  for _, p in dressing do
    if p.Name == "TreeTrunk" or p.Name == "PineTrunk" or p.Name == "Sheep" or p.Name == "Hedgerow" or p.Name == "Farmhouse" or p.Name == "Tor" then
      local c = p.CFrame.p - CENTER
      check(CityCircuit.clearance(c.X, c.Z) > 0, p.Name .. " keeps off the circuit at " .. fmt(c.X) .. "," .. fmt(c.Z))
    end
  end
  -- The farm track up to the mast keeps well clear of it
  for _, point in CityHills.TRACK do
    check(CityCircuit.clearance(point[1], point[2]) > 60, "Farm track keeps clear of the circuit")
  end
  print("Circuit: " .. CityCircuit.LENGTH .. " studs, " .. #circuitParts .. " parts, level " .. fmt(lowest) .. " to " .. fmt(highest) .. ", steepest " .. fmt(steepest * 100) .. "%, widest edge gap " .. fmt(worstLip))
end

-- The metro: walkable from the plaza down to both platforms, and dry
local CityMetro = require({ __module = "CityMetro" })
local Biomes = require({ __module = "Biomes" })
local function solidAt(x, y, z) return blockedAt(CENTER + v3(x, y, z)) ~= nil end
local function clearAt(x, y, z) return blockedAt(CENTER + v3(x, y, z)) == nil end
check(solidAt(-236, 8.4, 3) and clearAt(-236, 11, 3), "Escalator top landing is plaza level")
for _, x in { -228, -214, -200 } do
  -- Down the fixed stair: a tread under foot and headroom above it
  local y
  for probe = 9, -13, -0.1 do if solidAt(x, probe, 3) then y = probe; break end end
  check(y ~= nil and clearAt(x, y + 1, 3) and clearAt(x, y + 6, 3), "Fixed stair has a tread and headroom at x " .. x)
end
for _, spot in { { -250, 0, "ticket hall" }, { -250, -40, "barrier line paid side" }, { -250, -80, "footbridge" }, { -300, -57, "south platform" }, { -300, -105, "north platform" }, { -280, 5, "stairwell foot" } } do
  local y = if spot[3]:match("platform") then -34 else -12
  check(solidAt(spot[1], y - 0.3, spot[2]) and clearAt(spot[1], y + 1, spot[2]) and clearAt(spot[1], y + 5.5, spot[2]), "Metro " .. spot[3] .. " has floor and headroom")
end
for _, gx in { -274.5, -253.5, -225.5 } do
  check(clearAt(gx, -10, -30), "Ticket gate at x " .. gx .. " lets people through")
end
check(not clearAt(-300, -10, -30), "Barrier line is closed between the gates and the walls")
-- Bridge stairs: every tread a single step below the last
for _, stair in { { -1, -54 }, { 1, -108 } } do
  local last = -12
  for k = 0, 21 do
    local x = -250 + stair[1] * (6 + k * 1.6 + 0.8)
    local y
    for probe = -11, -35, -0.05 do if solidAt(x, probe, stair[2]) then y = probe; break end end
    check(y ~= nil and last - y > 0.8 and last - y < 1.2, "Bridge stair step " .. k .. " is one step down")
    last = y
  end
  check(last < -33.5 and last > -34.5, "Bridge stair lands on the platform")
end
for _, p in parts do
  if p.Name == "EscalatorRamp" then
    check(math.abs(p.CFrame.LookVector.Y) <= math.sin(math.rad(31)), "Escalator ramp is walkable")
  end
end
local pocket = Biomes.DryPockets[1]
local metroParts = 0
for _, d in ground:GetDescendants() do
  if d:IsA("Model") and d:GetAttribute("LodSkip") then
    for _, p in d:GetDescendants() do
      if p:IsA("BasePart") then
        metroParts += 1
        local h, c = halfExtent(p), p.CFrame.p
        check(c.X - h.X >= pocket.min.X - 0.01 and c.X + h.X <= pocket.max.X + 0.01 and c.Z - h.Z >= pocket.min.Z - 0.01 and c.Z + h.Z <= pocket.max.Z + 0.01 and c.Y - h.Y >= pocket.min.Y, p.Name .. " sits inside the metro's dry pocket")
      end
    end
  end
end
check(metroParts > 400, "The metro is detailed: " .. metroParts .. " parts below ground")
local hole = CityMetro.HOLE
check(not Biomes.inOceanBounds(CENTER + v3(-250, -30, -80)) and Biomes.inOceanBounds(CENTER + v3(-600, -5, -1000)), "Only the metro pocket is exempt from being underwater")
check(hole[1] >= pocket.min.X - CENTER.X and hole[2] <= pocket.max.X - CENTER.X and hole[3] >= pocket.min.Z - CENTER.Z and hole[4] <= pocket.max.Z - CENTER.Z, "The land slab opening is inside the dry pocket")
-- The land slab leaves the opening clear, and the forecourt closes it over
local slabInHole = 0
for _, p in parts do
  if p.ClassName == "WedgePart" and p.Parent == ground then
    local c = p.CFrame.p - CENTER
    if c.X > hole[1] + 2 and c.X < hole[2] - 2 and c.Z > hole[3] + 2 and c.Z < hole[4] - 2 then slabInHole += 1 end
  end
end
check(slabInHole == 0, slabInHole .. " land wedges fill the metro opening")
check(solidAt(-150, 8.5, -60) and solidAt(-370, 8.5, -110), "Forecourt covers the opening")

-- The refinery stands well back from the estuary, on land
local CityRefinery = require({ __module = "CityRefinery" })
local site = CityRefinery.SITE
for _, corner in { { site.x0, site.z0 }, { site.x1, site.z0 }, { site.x0, site.z1 }, { site.x1, site.z1 } } do
  check(CityLand.inside(coast, corner[1], corner[2]) and CityLand.edgeDistance(coast, corner[1], corner[2]) > 30, "Refinery corner " .. corner[1] .. "," .. corner[2] .. " is inland")
end
check(site.x1 < CityPort.WEST_QUAY - 400, "Refinery sits behind the container terminal")

-- Streaming pieces stay small; the city is split before it is first replicated
local pieces, biggest, biggestName, ungrouped = 0, 0, "", 0
for _, d in ground:GetDescendants() do
  if d:IsA("Model") and d:HasTag("LodPiece") then
    check(d:GetAttribute("PieceId") ~= nil and d.ModelStreamingMode == "Enum.ModelStreamingMode.PersistentPerPlayer", d.Name .. " is a pinned streaming piece")
    pieces += 1
    local count = 0
    for _, e in d:GetDescendants() do if e:IsA("BasePart") then count += 1 end end
    if count > biggest then biggest, biggestName = count, d.Name end
  end
end
for _, d in ground:GetDescendants() do
  if d:IsA("BasePart") then
    local p, inPiece = d.Parent, false
    while p and p ~= ground do if p:HasTag("LodPiece") then inPiece = true end; p = p.Parent end
    if not inPiece then ungrouped += 1 end
  end
end
check(ungrouped == 0, ungrouped .. " city parts would stream outside any pinned piece")
check(biggest <= 260, "Largest streaming piece (" .. biggestName .. ") has " .. biggest .. " parts")

-- Distant shell: tiled, one union per tile, each tile waiting on the ground under it
Lod.build(map)
local shells = map:FindFirstChild("Lod")
check(shells ~= nil, "Shell container is built")
local id = city:GetAttribute("LodId")
check(id ~= nil, "City gets an LOD id")
local shell = shells:FindFirstChild(tostring(id))
check(shell ~= nil and shell:GetAttribute("TileSize") ~= nil and shell:GetAttribute("LodStamp") == city:GetAttribute("LodStamp"), "City shell is tiled and stamped")
local tiles, waiting = 0, 0
for _, tile in shell:GetChildren() do
  tiles += 1
  local members = tile:GetChildren()
  check(#members == 1, "Shell tile " .. tile.Name .. " is merged into one part")
  if (tile:GetAttribute("Ground") or 0) > 0 then waiting += 1 end
  for _, p in tile:GetDescendants() do
    if p:IsA("BasePart") then check(p.CanCollide == false and p.CanQuery == false, "Shell parts are inert") end
  end
end
check(tiles > 40 and waiting == tiles, "Every one of " .. tiles .. " shell tiles waits for real ground under it (" .. waiting .. ")")
do
  local size, ox, oz = shell:GetAttribute("TileSize"), shell:GetAttribute("TileOriginX"), shell:GetAttribute("TileOriginZ")
  for _, spot in { CityHills.SUMMIT, { 1600, 0 }, { 0, 1500 } } do
    local key = math.floor((CENTER.X + spot[1] - ox) / size) .. "," .. math.floor((CENTER.Z + spot[2] - oz) / size)
    check(shell:FindFirstChild(key) ~= nil, "The distant shell shows the hills at " .. spot[1] .. "," .. spot[2])
  end
end

-- A baked map keeps a current shell, and rebuilds it once the city changes
local before = shell
Lod.build(map)
check(shells:FindFirstChild(tostring(id)) == before, "A current baked shell is kept")
city:SetAttribute("LodStamp", "city-next")
Lod.build(map)
local rebuilt = shells:FindFirstChild(tostring(id))
check(rebuilt ~= before and before.Parent == nil and rebuilt:GetAttribute("LodStamp") == "city-next", "A stale city shell is rebuilt")
city:SetAttribute("LodId", nil)
Lod.build(map)
check(city:GetAttribute("LodId") ~= nil and shells:FindFirstChild(tostring(city:GetAttribute("LodId"))) ~= nil, "A city without an id gets one and a shell")

-- Summary
local groups = {}
for _, p in parts do
  local top = p
  while top.Parent and top.Parent ~= ground and top.Parent ~= city do top = top.Parent end
  local key = top.Name
  groups[key] = (groups[key] or 0) + 1
end
local keys = {}
for k in groups do table.insert(keys, k) end
table.sort(keys, function(a, b) return groups[a] > groups[b] end)
local trees = 0
for _, p in parts do if p.Name == "TreeCrown" then trees += 1 end end
local summary = { "trees=" .. trees }
for i = 1, math.min(10, #keys) do table.insert(summary, keys[i] .. "=" .. groups[keys[i]]) end
print("City: " .. #parts .. " parts, " .. buildings .. " buildings, " .. pieces .. " pieces (largest " .. biggest .. "), " .. tiles .. " shell tiles, " .. samples .. " channel samples")
print("Parts by group: " .. table.concat(summary, ", "))
-- The new home terminus cuts existing slabs rather than covering the entrance.
local Stations = require({ __module = "MetroStations" })
Stations.ensureCity(city)
check(city:FindFirstChild("CityMetroStop") ~= nil, "City gets a return boarding point")
Stations.ensureCity(city)
local home = newInstance("Model"); home.Name = "Harbour Isle"; home.Parent = workspace
local homeGround = newInstance("Model"); homeGround.Name = "Ground"; homeGround.Parent = home
local plaza = newInstance("Model"); plaza.Name = "Plaza"; plaza.Parent = home
local homeFrame = CFrame.new(0, 5.92, -565.25)
local function homeSlab(parent, size, offset)
  local p = newInstance("Part"); p.Size = size; p.CFrame = homeFrame * CFrame.new(offset); p.Parent = parent
  return p
end
homeSlab(homeGround, v3(200, 4, 160), v3(0, -2.92, -20))
homeSlab(plaza, v3(116, 0.6, 116), v3(0, -0.42, 0))
homeSlab(plaza, v3(1.4, 0.12, 116), v3(24, -0.06, 0))
local station = Stations.ensureHarbour(home, plaza, homeFrame)
local function homeBlocked(x, y, z)
  local world = homeFrame * v3(x, y, z)
  for _, p in home:GetDescendants() do
    if p:IsA("BasePart") and p.CanCollide then
      local q, h = p.CFrame:PointToObjectSpace(world), p.Size / 2
      if math.abs(q.X) < h.X - 0.001 and math.abs(q.Y) < h.Y - 0.001 and math.abs(q.Z) < h.Z - 0.001 then return p end
    end
  end
  return nil
end
for k = 1, 36 do
  local y, x = -k * 0.8, 80 + (k - 0.5) * 1.35
  check(homeBlocked(x, y - 0.1, -18) ~= nil, "Home stair " .. k .. " has a tread")
  for dy = 0.2, 6, 0.4 do
    check(homeBlocked(x, y + dy, -18) == nil, "Home stair " .. k .. " has continuous headroom")
  end
end
for _, spot in { {129, -18}, {133, -18}, {141, -18}, {145, -40}, {145, 20} } do
  check(homeBlocked(spot[1], -29, spot[2]) ~= nil and homeBlocked(spot[1], -23, spot[2]) == nil, "Home platform and stair landing are connected")
end
check(homeBlocked(15, -1, -40) ~= nil, "Ground alongside the stair is retained")
local count = #home:GetDescendants()
check(Stations.ensureHarbour(home, plaza, homeFrame) == station and #home:GetDescendants() == count, "Baked home upgrade is idempotent")
for _, p in station:GetDescendants() do
  if p:IsA("BasePart") and p.Position.Y < 0 then
    check(not Biomes.inOceanBounds(p.Position), "Home station is inside its dry pocket: " .. p.Name)
  end
end
check(not Biomes.inOceanBounds(homeFrame * v3(141, -20, -71)) and Biomes.inOceanBounds(homeFrame * v3(190, -20, -71)), "Only the station pocket is dry")
print("City and metro: " .. checks .. " checks passed")

if PREVIEW then
  local out = {}
  for _, p in parts do
    local top = p.CFrame.p.Y + halfExtent(p).Y
    if top > -2 and p.Transparency < 1 then
      local c, s = p.CFrame, p.Size / 2
      local corners
      if p.ClassName == "WedgePart" then
        corners = { c * v3(s.X, -s.Y, -s.Z), c * v3(s.X, -s.Y, s.Z), c * v3(s.X, s.Y, s.Z) }
      else
        local h, o = halfExtent(p), c.p
        corners = { v3(o.X - h.X, 0, o.Z - h.Z), v3(o.X + h.X, 0, o.Z - h.Z), v3(o.X + h.X, 0, o.Z + h.Z), v3(o.X - h.X, 0, o.Z + h.Z) }
      end
      local pts = {}
      for _, q in corners do table.insert(pts, fmt(q.X - CENTER.X) .. "," .. fmt(q.Z - CENTER.Z)) end
      local col = p.Color
      table.insert(out, string.format("%s|%d,%d,%d|%s", fmt(top), col.R * 255, col.G * 255, col.B * 255, table.concat(pts, " ")))
    end
  end
  table.sort(out, function(a, b) return tonumber(a:match("^[^|]+")) < tonumber(b:match("^[^|]+")) end)
  for _, line in out do print("@" .. line) end
end
for _, line in printed do _G_print(line) end
`;

const program = 'local _G_print = print\nlocal PREVIEW = ' + (previewPath ? 'true' : 'false') + '\n' + bundle;
const temporary = await mkdtemp(join(tmpdir(), 'fishing-city-'));
try {
  const path = join(temporary, 'city.luau');
  await writeFile(path, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', path], { cwd: root, encoding: 'utf8', timeout: 240000, maxBuffer: 1 << 28 });
  if (result.error) throw result.error;
  const lines = (result.stdout || '').split(/\r?\n/);
  const plan = [];
  for (const line of lines) {
    if (line.startsWith('@')) plan.push(line.slice(1));
    else if (line) console.log(line);
  }
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.status !== 0) throw new Error('City check failed');
  if (previewPath) {
    const html = `<!doctype html><meta charset="utf-8"><title>City plan</title><style>body{margin:0;background:#3a6c8c}canvas{display:block}</style><canvas id="c" width="1400" height="1500"></canvas><script>
const rows = ${JSON.stringify(plan)};
const c = document.getElementById('c'), g = c.getContext('2d');
const minX = -1700, minZ = -1850, scale = 0.47;
for (const row of rows) {
  const [top, col, pts] = row.split('|');
  g.fillStyle = 'rgb(' + col + ')';
  g.beginPath();
  pts.split(' ').forEach((p, i) => { const [x, z] = p.split(',').map(Number); const px = (x - minX) * scale, pz = (z - minZ) * scale; i ? g.lineTo(px, pz) : g.moveTo(px, pz); });
  g.closePath(); g.fill();
}
</script>`;
    await writeFile(previewPath, html);
    console.log('Preview written to ' + previewPath);
  }
} finally {
  if (dirname(temporary) !== resolve(tmpdir())) throw new Error('Unexpected temporary directory');
  await rm(temporary, { recursive: true, force: true });
}
