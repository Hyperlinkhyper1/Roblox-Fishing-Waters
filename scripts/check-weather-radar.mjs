// Run the real WeatherRadar client renderer and the furniture yard rules against
// minimal Roblox mocks: the screen only exists near the camera, land and rain
// paint as merged runs, an unchanged picture writes nothing, and the radar sits
// in the yard only. Recording mocks only; how it looks still needs Studio.
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const scratch = mkdtempSync(join(tmpdir(), 'fishing-radar-'));
const read = f => readFileSync(join(root, f), 'utf8');
const radar = read('src/client/WeatherRadar.luau')
  .replace(/local (\w+) = game:GetService\("\w+"\)\r?\n/g, '')
  .replace('require(ReplicatedStorage.Shared.Biomes)', 'Biomes')
  .replace('require(ReplicatedStorage.Shared.Weather)', 'Weather');

const program = `
local V = {}
V.__index = function(v, k)
  if k == "Magnitude" then return math.sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z)
  elseif k == "Unit" then local m = math.sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z) return Vector3.new(v.X/m, v.Y/m, v.Z/m)
  end
  return V[k]
end
local function isV(x) return type(x) == "table" and getmetatable(x) == V end
Vector3 = {}
function Vector3.new(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V) end
Vector3.zero, Vector3.one, Vector3.yAxis = Vector3.new(0, 0, 0), Vector3.new(1, 1, 1), Vector3.new(0, 1, 0)
function V.__add(a, b) return Vector3.new(a.X+b.X, a.Y+b.Y, a.Z+b.Z) end
function V.__sub(a, b) return Vector3.new(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end
function V.__mul(a, b)
  if type(a) == "number" then a, b = b, a end
  if isV(b) then return Vector3.new(a.X*b.X, a.Y*b.Y, a.Z*b.Z) end
  return Vector3.new(a.X*b, a.Y*b, a.Z*b)
end
function V.Dot(a, b) return a.X*b.X + a.Y*b.Y + a.Z*b.Z end
function V.Cross(a, b) return Vector3.new(a.Y*b.Z - a.Z*b.Y, a.Z*b.X - a.X*b.Z, a.X*b.Y - a.Y*b.X) end
local function typeof(x) if isV(x) then return "Vector3" end return type(x) end
local V2 = {}
V2.__index = V2
Vector2 = {}
function Vector2.new(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, V2) end
Vector2.zero = Vector2.new(0, 0)
function V2.__add(a, b) return Vector2.new(a.X+b.X, a.Y+b.Y) end
function V2.__div(a, b) return Vector2.new(a.X/b, a.Y/b) end
function V2.Lerp(a, b, t) return Vector2.new(a.X+(b.X-a.X)*t, a.Y+(b.Y-a.Y)*t) end
CFrame = { identity = {} }
local Col = { __tostring = function(c) return c.R .. "," .. c.G .. "," .. c.B end }
Color3 = { fromRGB = function(r, g, b) return setmetatable({ R = r/255, G = g/255, B = b/255 }, Col) end }
UDim2 = {
  fromScale = function(x, y) return { sx = x, sy = y } end,
  fromOffset = function(x, y) return { ox = x, oy = y } end,
  new = function(a, b, c, d) return { a, b, c, d } end,
}
UDim = { new = function(a, b) return { a, b } end }
Enum = setmetatable({}, { __index = function(t, k)
  local v = setmetatable({}, { __index = function(_, k2) return k .. "." .. k2 end }) t[k] = v return v end })

local writes = 0
local Inst = {}
Inst.__index = function(self, k)
  local v = rawget(self, "_p")[k]
  if v ~= nil then return v end
  return Inst[k]
end
Inst.__newindex = function(self, k, v)
  local p = rawget(self, "_p")
  if k == "Parent" then
    local old = p.Parent
    if old then
      local list = rawget(old, "_c")
      for i, c in list do if c == self then table.remove(list, i) break end end
    end
    if v then table.insert(rawget(v, "_c"), self) end
  end
  p[k] = v
  writes += 1
end
function Inst:GetChildren() return table.clone(rawget(self, "_c")) end
function Inst:ClearAllChildren() for _, c in self:GetChildren() do c:Destroy() end end
function Inst:Destroy() self.Parent = nil rawget(self, "_p").destroyed = true end
function Inst:IsA(class) return self.ClassName == class or (class == "BasePart" and self.ClassName == "Part") end
function Inst:IsDescendantOf(ancestor)
  local node = self.Parent
  while node do if node == ancestor then return true end node = node.Parent end
  return false
end
function Inst:GetAttribute(k) return rawget(self, "_a")[k] end
function Inst:SetAttribute(k, v) rawget(self, "_a")[k] = v end
local function new(class) return setmetatable({ _p = { ClassName = class, Visible = true }, _c = {}, _a = {} }, Inst) end
Instance = { new = new }
local function signal()
  local handlers = {}
  return { Connect = function(_, f) table.insert(handlers, f) end, fire = function(...) for _, f in handlers do f(...) end end }
end
local function descendants(node, list)
  list = list or {}
  for _, child in rawget(node, "_c") do table.insert(list, child) descendants(child, list) end
  return list
end

local now = 800000
local attributes = { WeatherEpoch = now - 2000, WeatherSeed = 4242, WeatherOverride = "Clear" }
workspace = new("Workspace")
workspace.CurrentCamera = { CFrame = { Position = Vector3.new(0, 10, 0) } }
rawget(workspace, "_p").GetServerTimeNow = function() return now end
rawget(workspace, "_p").GetAttribute = function(_, k) return attributes[k] end

local delayed = {}
task = { spawn = function(f, ...) f(...) end, delay = function(_, f) table.insert(delayed, f) end }
local function flushDelays() local list = delayed delayed = {} for _, f in list do f() end end
local chart = new("Folder")
chart.ChildAdded, chart.ChildRemoved = signal(), signal()
local ReplicatedStorage = { WaitForChild = function(_, name) assert(name == "IslandChart") return chart end }
local HttpService = { JSONDecode = function(_, value) return value end }
local tagged, added, removed = {}, signal(), signal()
local CollectionService = {
  GetTagged = function() return table.clone(tagged) end,
  GetInstanceAddedSignal = function() return added end,
  GetInstanceRemovedSignal = function() return removed end,
}
local heartbeat = signal()
local RunService = { Heartbeat = heartbeat }
local Biomes = { at = function() return { id = "normal" } end }
local Weather = (function()
${read('src/shared/Weather.luau')}
end)()
local Radar = (function()
${radar}
end)()
local Furniture = (function()
${read('src/shared/FurnitureCatalog.luau')}
end)()

local function step(seconds)
  for _ = 1, math.ceil(seconds / 0.25) do now += 0.25 heartbeat.fire(0.25) end
end

-- A radar table at a base on the bay shore, tagged before the client starts,
-- plus a template in ReplicatedStorage that must never get a screen.
local base = Vector3.new(120, 6, 260)
local screen = new("Part")
screen.Position = base
screen.CFrame = { Position = base, RightVector = Vector3.new(1, 0, 0) }
screen.Parent = workspace
table.insert(tagged, screen)
local template = new("Part")
template.Position = base
template.CFrame = screen.CFrame
template.Parent = new("Folder")
table.insert(tagged, template)
Radar.start()
Radar.start()
local function guiOf(part)
  for _, child in part:GetChildren() do if child.Name == "WeatherRadarGui" then return child end end
  return nil
end

workspace.CurrentCamera.CFrame = { Position = base + Vector3.new(0, 0, 200) }
step(1)
assert(guiOf(screen) == nil, "A distant radar builds no screen")
workspace.CurrentCamera.CFrame = { Position = base + Vector3.new(0, 2, 6) }
step(1)
local gui = guiOf(screen)
assert(gui and gui.Face == "NormalId.Top" and gui.LightInfluence == 0, "A nearby radar gets a glowing top-face screen")
assert(gui.MaxDistance and gui.MaxDistance <= 100, "The screen stops rendering from afar")
assert(guiOf(template) == nil, "Templates outside the workspace never get a screen")

-- Land: one island west of the table arrives on the chart.
local island = new("StringValue")
island.Name = "Island"
island.Value = { { base.X - 900, base.Z - 300 }, { base.X - 300, base.Z - 300 }, { base.X - 300, base.Z + 300 }, { base.X - 900, base.Z + 300 } }
island.Parent = chart
chart.ChildAdded.fire(island)
flushDelays()
step(2)
local landFrames, rainFrames, cells = 0, 0, 0
local land, rain
for _, child in gui:GetChildren() do
  if child.Name == "Land" then land = child elseif child.Name == "Rain" then rain = child end
end
landFrames = #land:GetChildren()
-- 40 cells across: about 1250 inside the disc, painted as a few runs per row.
assert(landFrames > 40 and landFrames < 300, "Land paints as merged runs, not one frame per cell: " .. landFrames)
local green = 0
for _, frame in land:GetChildren() do if tostring(frame.BackgroundColor3) == tostring(Color3.fromRGB(98, 164, 74)) then green += 1 end end
assert(green > 0, "The island shows as land")
for _, frame in rain:GetChildren() do if frame.Visible then rainFrames += 1 end end
assert(rainFrames == 0, "Clear weather shows no rain")
print("land runs", landFrames)

-- A forced supercell over the table: a full reflectivity blob, still merged.
attributes.WeatherOverride = "Supercell"
attributes.SupercellPosition = Vector3.new(base.X, 0, base.Z)
attributes.SupercellSince = now - 120
step(2)
local visible, colors = 0, {}
for _, frame in rain:GetChildren() do
  if frame.Visible then visible += 1 colors[tostring(frame.BackgroundColor3)] = true end
end
assert(visible > 20 and visible < 600, "A supercell paints as merged rain runs: " .. visible)
-- The Supercell preset rains everywhere (yellow); the cell itself brings the red and pink core.
assert(colors[tostring(Color3.fromRGB(248, 196, 220))] and colors[tostring(Color3.fromRGB(222, 44, 34))]
  and colors[tostring(Color3.fromRGB(236, 214, 46))], "The storm shows its core inside the surrounding rain")
print("supercell runs", visible)

-- A uniform preset: the picture settles, and an unchanged picture writes nothing.
attributes.WeatherOverride = "Rain"
step(2)
local before = writes
step(3)
assert(writes == before, "An unchanged radar picture touches no instances: " .. (writes - before))
local pooled = #rain:GetChildren()
attributes.WeatherOverride = "Clear"
step(2)
for _, frame in rain:GetChildren() do assert(not frame.Visible, "Clearing hides every rain run") end
assert(#rain:GetChildren() == pooled, "Rain runs are pooled, not rebuilt")

-- Walking away removes the screen; a removed tag never comes back.
workspace.CurrentCamera.CFrame = { Position = base + Vector3.new(0, 0, 300) }
step(1)
assert(guiOf(screen) == nil and gui.destroyed, "Leaving the table removes its screen")
removed.fire(screen)
workspace.CurrentCamera.CFrame = { Position = base + Vector3.new(0, 2, 6) }
step(1)
assert(guiOf(screen) == nil, "An untagged radar stays dark")
print("PASS radar screen lifetime, merged land and rain runs, idle refresh and pooled frames")

-- The radar is yard furniture: on the deck behind the house, never indoors or in the way.
local radar = Furniture.Items.WeatherRadar
assert(radar and radar.Room == "Yard" and table.find(Furniture.Order, "WeatherRadar"), "The radar is in the catalogue")
assert(Furniture.check({}, "WeatherRadar", 10, -22, 0) == nil, "The open yard takes a radar")
assert(Furniture.check({}, "WeatherRadar", 0, 8, 0) ~= nil, "A radar can't go inside the shop")
assert(Furniture.check({}, "WeatherRadar", 1, -24, 0) ~= nil, "The walk from the back door stays clear")
assert(Furniture.check({}, "WeatherRadar", 20, -25, 0) ~= nil, "The crates and barrels stay where they are")
assert(Furniture.check({}, "WeatherRadar", 17, -31, 0) ~= nil, "The gangway head stays clear")
assert(Furniture.check({}, "Freezer", 10, -22, 0) ~= nil, "Indoor furniture can't go in the yard")
assert(Furniture.floor("WeatherRadar") == 0 and Furniture.floor("Freezer") == 0.16, "Yard items stand on the deck")
local yard = Furniture.Rooms.Yard
for name, room in Furniture.Rooms do
  if name ~= "Yard" then
    assert(not (yard[1] < room[3] and yard[3] > room[1] and yard[2] < room[4] and yard[4] > room[2]),
      "The yard never overlaps a room: " .. name)
  end
end
print("PASS weather radar yard rules")
`;
const target = join(scratch, 'radar.luau');
writeFileSync(target, program);
const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { cwd: root, encoding: 'utf8', timeout: 120000 });
rmSync(scratch, { recursive: true, force: true });
process.stdout.write(result.stdout || '');
process.stderr.write(result.stderr || '');
process.exit(result.status ?? 1);
