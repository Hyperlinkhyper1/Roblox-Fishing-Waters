// Run the real VolumetricClouds and SupercellWeather client modules against
// minimal Roblox mocks: no clouds outside the supercell, its rain deck, funnels and toggles.
// Recording mocks only; how the sky looks still needs Studio.
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const scratch = mkdtempSync(join(tmpdir(), 'fishing-sky-'));
const read = f => readFileSync(join(root, f), 'utf8');
const strip = s => s
  .replace(/local Players = game:GetService\("Players"\)\r?\n/, '')
  .replace(/local ReplicatedStorage = game:GetService\("ReplicatedStorage"\)\r?\n/, '')
  .replace(/local RunService = game:GetService\("RunService"\)\r?\n/, '')
  .replace('require(ReplicatedStorage.Shared.Biomes)', 'Biomes')
  .replace('require(ReplicatedStorage.Shared.Weather)', 'Weather')
  .replace('require(script.Parent.VolumetricClouds)', 'Clouds');

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
function Vector3.new(x, y, z) assert(x == x and y == y and z == z, "NaN vector") return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V) end
Vector3.zero, Vector3.one = Vector3.new(0,0,0), Vector3.new(1,1,1)
Vector3.xAxis, Vector3.yAxis, Vector3.zAxis = Vector3.new(1,0,0), Vector3.new(0,1,0), Vector3.new(0,0,1)
function V.__add(a, b) return Vector3.new(a.X+b.X, a.Y+b.Y, a.Z+b.Z) end
function V.__sub(a, b) return Vector3.new(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end
function V.__unm(a) return Vector3.new(-a.X, -a.Y, -a.Z) end
function V.__mul(a, b)
  if type(a) == "number" then a, b = b, a end
  if isV(b) then return Vector3.new(a.X*b.X, a.Y*b.Y, a.Z*b.Z) end
  return Vector3.new(a.X*b, a.Y*b, a.Z*b)
end
function V.__div(a, b)
  if isV(b) then return Vector3.new(a.X/b.X, a.Y/b.Y, a.Z/b.Z) end
  return Vector3.new(a.X/b, a.Y/b, a.Z/b)
end
function V.Dot(a, b) return a.X*b.X + a.Y*b.Y + a.Z*b.Z end
function V.Cross(a, b) return Vector3.new(a.Y*b.Z - a.Z*b.Y, a.Z*b.X - a.X*b.Z, a.X*b.Y - a.Y*b.X) end
function V.Lerp(a, b, t) return a + (b - a) * t end
local function typeof(x) if isV(x) then return "Vector3" end return type(x) end

local C = {}
C.__index = function(c, k)
  if k == "Position" then return c.p
  elseif k == "LookVector" then return Vector3.new(-c.m[3], -c.m[6], -c.m[9])
  end
  return C[k]
end
local function cf(p, m) return setmetatable({ p = p, m = m }, C) end
local I = { 1,0,0, 0,1,0, 0,0,1 }
local function mul(a, b)
  local r = {}
  for i = 0, 2 do for j = 1, 3 do
    r[i*3+j] = a[i*3+1]*b[j] + a[i*3+2]*b[3+j] + a[i*3+3]*b[6+j]
  end end
  return r
end
local function apply(m, v) return Vector3.new(m[1]*v.X+m[2]*v.Y+m[3]*v.Z, m[4]*v.X+m[5]*v.Y+m[6]*v.Z, m[7]*v.X+m[8]*v.Y+m[9]*v.Z) end
function C.__mul(a, b)
  if isV(b) then return a.p + apply(a.m, b) end
  return cf(a.p + apply(a.m, b.p), mul(a.m, b.m))
end
CFrame = {}
function CFrame.new(x, y, z) if isV(x) then return cf(x, I) end return cf(Vector3.new(x or 0, y or 0, z or 0), I) end
CFrame.identity = CFrame.new()
function CFrame.Angles(rx, ry, rz)
  local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
  local X = { 1,0,0, 0,cx,-sx, 0,sx,cx }
  local Y = { cy,0,sy, 0,1,0, -sy,0,cy }
  local Z = { cz,-sz,0, sz,cz,0, 0,0,1 }
  return cf(Vector3.zero, mul(mul(X, Y), Z))
end
function CFrame.lookAt(a, b)
  local f = (b - a).Unit
  local r = f:Cross(Vector3.yAxis).Unit
  local u = r:Cross(f)
  return cf(a, { r.X, u.X, -f.X, r.Y, u.Y, -f.Y, r.Z, u.Z, -f.Z })
end

local Col = {}
Col.__index = Col
Color3 = {}
function Color3.fromRGB(r, g, b) return setmetatable({ R = r/255, G = g/255, B = b/255 }, Col) end
function Col.Lerp(a, b, t) return setmetatable({ R = a.R+(b.R-a.R)*t, G = a.G+(b.G-a.G)*t, B = a.B+(b.B-a.B)*t }, Col) end
local function pass(name) return { new = function(...) return { kind = name, ... } end } end
NumberSequence, NumberSequenceKeypoint, ColorSequence, NumberRange = pass("NS"), pass("NSK"), pass("CS"), pass("NR")
ColorSequenceKeypoint = pass("CSK")
Vector2 = { new = function(x, y) return { X = x, Y = y } end }
local auto = setmetatable({}, { __index = function(t, k) local v = setmetatable({}, { __index = function(_, k2) return k .. "." .. k2 end }) t[k] = v return v end })
Enum = auto

local created, alive = {}, 0
Instance = { new = function(class)
  local object = { ClassName = class, Transparency = 0, Enabled = true }
  function object:Destroy() self.destroyed = true alive -= 1 end
  function object:SetAttribute(k, v) self.attributes = self.attributes or {} self.attributes[k] = v end
  function object:GetAttribute(k) return self.attributes and self.attributes[k] end
  function object:Emit(n) self.emitted = (self.emitted or 0) + n end
  table.insert(created, object)
  alive += 1
  return object
end }
Random = { new = function(seed)
  local state = (seed % 2147483646) + 1
  local function nxt() state = (state * 48271) % 2147483647 return state / 2147483647 end
  return {
    NextNumber = function(_, a, b) return a + (b - a) * nxt() end,
    NextInteger = function(_, a, b) return a + math.floor((b - a + 1) * nxt()) end,
  }
end }

local now = 500000
local attributes = { WeatherEpoch = now - 2000, WeatherSeed = 4242 }
local moves, movedParts = 0, 0
workspace = {
  CurrentCamera = { CFrame = CFrame.new(0, 8, 0) },
  GetServerTimeNow = function() return now end,
  GetAttribute = function(_, k) return attributes[k] end,
  BulkMoveTo = function(_, parts, frames, mode)
    assert(#parts == #frames and #parts > 0, "BulkMoveTo pairs parts with frames")
    for i, part in parts do assert(not part.destroyed, "moves only live parts") part.CFrame = frames[i] end
    moves += 1
    movedParts += #parts
  end,
}
local playerAttributes = { WeatherEffectsEnabled = true, VolumetricCloudsEnabled = true }
local Players = { LocalPlayer = { GetAttribute = function(_, k) return playerAttributes[k] end } }
local heartbeat, render = {}, {}
local RunService = {
  Heartbeat = { Connect = function(_, f) table.insert(heartbeat, f) end },
  RenderStepped = { Connect = function(_, f) table.insert(render, f) end },
}
local Biomes = { WaterLevel = 0 }
local Weather = (function()
${read('src/shared/Weather.luau')}
end)()
local Clouds = (function()
${strip(read('src/client/VolumetricClouds.luau'))}
end)()
local Supercell = (function()
${strip(read('src/client/SupercellWeather.luau'))}
end)()
Clouds.start()
Supercell.start()
Clouds.start()
assert(#render == 2 and #heartbeat == 0, "Repeated startup keeps one supercell deck and one supercell renderer")
local function frames(n, dt)
  for _ = 1, n do
    now += dt
    for _, f in heartbeat do f(dt) end
    for _, f in render do f(dt) end
  end
end
local function gone(o)
  while o do
    if type(o) ~= "table" then return false end
    if o.destroyed then return true end
    o = o.Parent
  end
  return false
end
local function count(predicate)
  local n = 0
  for _, o in created do if not gone(o) and predicate(o) then n += 1 end end
  return n
end

-- No distant cloud field any more: clear skies and ordinary rain build nothing.
-- The sky there is Terrain.Clouds + Atmosphere (BiomeAtmosphere).
local function cloudObjects()
  return count(function(o)
    return o.Name == "RainCloudTile" or o.Name == "Billows" or o.Name == "VolumetricClouds"
      or (o.ClassName == "Model" and type(o.Name) == "string" and o.Name:match("Cloud$") ~= nil)
  end)
end
attributes.WeatherOverride = "Clear"
frames(150, 1/30)
assert(cloudObjects() == 0, "Clear skies build no volumetric clouds")
assert(count(function(o) return o.Name == "Tornado" or o.Name == "Supercell" end) == 0, "No supercell in clear weather")
for _, kind in { "LightRain", "Rain", "Storm" } do
  attributes.WeatherOverride = kind
  for _, position in { Vector3.new(0, 8, 0), Vector3.new(-5000, 8, 5000), Vector3.new(123, 600, -456) } do
    workspace.CurrentCamera.CFrame = CFrame.new(position)
    frames(20, 1/60)
    assert(cloudObjects() == 0, "Ordinary " .. kind .. " uses Terrain clouds, not volumetric ones")
  end
end
workspace.CurrentCamera.CFrame = CFrame.new(0, 8, 0)
print("PASS no volumetric clouds outside the supercell")

local function assertCovered(position, label)
  for _, o in created do
    if o.Name == "RainCloudBody" and not gone(o) and o.CFrame and o.Transparency < 0.1 then
      local center = o.CFrame.Position
      local x, z = (position.X - center.X) / (o.Size.X/2), (position.Z - center.Z) / (o.Size.Z/2)
      if center.Y - o.Size.Y/2 > position.Y and x*x + z*z < 1 then return o end
    end
  end
  error("Supercell rain must have an opaque volumetric cloud directly overhead: " .. label)
end
local function renderOnly()
  now += 1/144
  for _, f in render do f(1/144) end
end
-- Under the supercell no settling time or teleport may leave its rain uncovered.
attributes.WeatherOverride = "Supercell"
attributes.SupercellPosition = Vector3.new(0, 0, 0)
attributes.SupercellSince = now - 60
local function cellCenter()
  local cell = Weather.supercell(now)
  return Vector3.new(cell.position.X, 8, cell.position.Z)
end
for _, seed in { 17, 1847, 999983 } do
  attributes.WeatherSeed = seed
  for _, offset in { Vector3.new(0, 0, 0), Vector3.new(300, 0, -200), Vector3.new(-250, 592, 180) } do
    local position = cellCenter() + offset
    workspace.CurrentCamera.CFrame = CFrame.new(position)
    renderOnly()
    assertCovered(position, "supercell seed " .. seed .. " on its first frame / after teleport")
  end
  for _, delta in { -0.01, 0.01 } do
    local position = Vector3.new(180 + delta, 8, 180 + delta)
    workspace.CurrentCamera.CFrame = CFrame.new(position)
    renderOnly()
    assertCovered(position, "diagonal grid corner under the supercell")
  end
end
attributes.WeatherSeed = 4242
workspace.CurrentCamera.CFrame = CFrame.new(cellCenter())
frames(180, 1/60)
local covered = assertCovered(workspace.CurrentCamera.CFrame.Position, "detailed supercell rain")
local tileParts, darkest, brightest, billows, scud, wisps = 0, 1, 0, nil, nil, nil
for _, o in created do
  if o.Parent == covered.Parent and not gone(o) and o.ClassName == "Part" then
    tileParts += 1
    assert(not o.CanCollide and not o.CanTouch and not o.CanQuery, "Rain clouds cannot block precipitation rays or gameplay")
    if o.Transparency < 1 then
      darkest, brightest = math.min(darkest, o.Color.R), math.max(brightest, o.Color.R)
    end
    if o.Name == "RainCloudScud" then scud = o end
    for _, emitter in created do
      if emitter.Parent == o and not gone(emitter) then
        if emitter.Name == "CloudWisps" then wisps = emitter end
        if emitter.Name == "Billows" and o.Name == "RainCloudBillows" then billows = emitter end
      end
    end
  end
end
assert(tileParts <= 6, "A rain tile is a handful of parts, not dozens of spheres: " .. tileParts)
assert(brightest - darkest > 0.15, "The deck keeps visible depth shading")
assert(billows and billows.Enabled and billows.LockedToPart and (billows.emitted or 0) > 0,
  "A lumpy billowed underside hangs below the deck and rides along with it")
assert(scud and wisps and wisps.Enabled and wisps.Texture == "rbxasset://textures/particles/smoke_main.dds",
  "Lower scud and soft textured wisps break up the cloud underside")
assert(count(function(o) return o.Name == "RainCloudTile" end) <= 36, "The local cloud pool stays bounded")

-- Camera and avatar can be far apart under the storm; both need a deck.
local root = { Position = cellCenter() + Vector3.new(150, 0, 150) }
Players.LocalPlayer.Character = { FindFirstChild = function(_, name) return if name == "HumanoidRootPart" then root else nil end }
workspace.CurrentCamera.CFrame = CFrame.new(cellCenter() + Vector3.new(-200, 0, 100))
renderOnly()
assertCovered(root.Position, "avatar away from the camera")
assertCovered(workspace.CurrentCamera.CFrame.Position, "free camera away from the avatar")
for _, detailed in { false, true, false } do
  playerAttributes.VolumetricCloudsEnabled = detailed
  playerAttributes.WeatherEffectsEnabled = false
  renderOnly()
  local body = assertCovered(root.Position, "graphics toggle never removes the supercell deck")
  assert(body.CastShadow == false, "The rain deck never casts shadows, at any graphics level")
end
Players.LocalPlayer.Character = nil
playerAttributes.VolumetricCloudsEnabled, playerAttributes.WeatherEffectsEnabled = true, true
workspace.CurrentCamera = nil
renderOnly()
assert(count(function(o) return o.Name == "RainCloudTile" end) == 0, "Camera loss cleans up the rain deck")
workspace.CurrentCamera = { CFrame = CFrame.new(cellCenter()) }
renderOnly()
assertCovered(workspace.CurrentCamera.CFrame.Position, "camera recovery under the supercell")
-- Leaving the storm fades the deck away.
workspace.CurrentCamera.CFrame = CFrame.new(8000, 8, 8000)
frames(400, 1/60)
assert(count(function(o) return o.Name == "RainCloudTile" end) == 0, "Leaving the supercell removes its deck")
attributes.WeatherOverride = "Clear"
frames(60, 1/60)
print("PASS supercell rain deck: overhead coverage, teleports, grid corners, detached cameras, low graphics and cleanup")
workspace.CurrentCamera.CFrame = CFrame.new(0, 8, 0)

-- Forced supercell over the camera: tower + funnels.
-- Keep the deterministic tornado window independent of the coverage replay.
now = 500000
attributes.WeatherOverride = "Supercell"
attributes.SupercellPosition = Vector3.new(0, 0, 0)
attributes.SupercellSince = now
local seenFunnel, maxFunnels = false, 0
for _ = 1, 90 do
  frames(30, 1/30)
  local funnels = count(function(o) return o.Name == "Tornado" end)
  maxFunnels = math.max(maxFunnels, funnels)
  if funnels > 0 then seenFunnel = true end
end
assert(count(function(o) return o.Name == "Supercell" end) == 1, "One supercell structure")
local tower, stormParts, stormBillows = nil, 0, 0
for _, o in created do
  if gone(o) or not o.Parent then continue end
  if o.ClassName == "Part" and o.Parent.Name == "Supercell" then
    stormParts += 1
    if o.Name == "TowerLower" then tower = o end
  elseif o.Name == "Billows" and o.Parent.Parent and o.Parent.Parent.Name == "Supercell" then
    stormBillows += 1
    assert(o.LockedToPart and o.Enabled, "Storm billows ride with the moving, turning storm")
  end
end
assert(tower and tower.Transparency == 0, "Supercell tower is visible and opaque")
assert(stormParts <= 10 and stormBillows >= 6, "The supercell is a few cores wrapped in billows: " .. stormParts .. " parts")
before = tower.CFrame.Position
local moveCount = moves
frames(6, 1/144)
assert(moves >= moveCount + 1, "The supercell moves at a capped rate on high refresh displays")
assert(seenFunnel, "A forced supercell drops a visible tornado")
local tornadoes = Weather.tornadoes(now)
print("funnels max", maxFunnels, "active", #tornadoes)
do
  local segments, funnelBillows, bands = 0, 0, 0
  for _, o in created do
    if not gone(o) then
      if o.Name == "FunnelSegment" then segments += 1 end
      if o.Name == "Billows" and o.Parent and o.Parent.Name == "FunnelSegment" then
        funnelBillows += 1
        assert(o.LockedToPart, "Funnel billows turn with their spinning segment")
        assert(o.Size[1][2][2] <= 100, "Funnel billows stay within the particle size limit")
      end
      if o.Name == "SpiralBand" then bands += 1 end
    end
  end
  assert(segments == funnelBillows and segments <= 7 * math.max(1, #tornadoes), "Funnels are a short stack of billowed segments")
  assert(bands == 0, "Rotation shows through the billows; no beam bands")
end
local kinds = {}
for _, o in created do
  if o.ClassName == "Model" and not o.destroyed and o.Name then kinds[o.Name] = (kinds[o.Name] or 0) + 1 end
end
for k, v in kinds do print("model", k, v) end
do
  -- The supercell sky keeps a bounded billow budget.
  local budget = 0
  for _, o in created do
    if not gone(o) and o.Name == "Billows" and o.Enabled then budget += o:GetAttribute("Billows") or 0 end
  end
  print("live billows", budget)
  assert(budget < 1500, "The whole sky keeps a bounded number of billows: " .. budget)
end

-- Mobile: lightweight mandatory rain deck, simpler supercell.
playerAttributes.VolumetricCloudsEnabled = false
frames(60, 1/30)
assert(count(function(o) return o.Name == "CloudPuff" and o.Parent ~= nil and not o.destroyed and o.ClassName == "Part" and o.CastShadow == true end) == 0, "Mobile sky casts no cloud shadows")
assertCovered(workspace.CurrentCamera.CFrame.Position, "mobile supercell")
-- Weather effects off clears funnels; the mandatory rainy sky stays overhead.
playerAttributes.WeatherEffectsEnabled = false
frames(10, 1/30)
assert(count(function(o) return o.Name == "Supercell" or o.Name == "Tornado" end) == 0, "Toggle clears the supercell")
assertCovered(workspace.CurrentCamera.CFrame.Position, "rain deck with weather effects off")
attributes.WeatherOverride = "Clear"
playerAttributes.WeatherEffectsEnabled, playerAttributes.VolumetricCloudsEnabled = true, true
frames(200, 1/30)
assert(count(function(o) return o.Name == "Supercell" end) == 0, "Clear weather has no supercell")
print("PASS forced supercell with tornado funnel, mobile detail and weather toggle cleanup")
`;
const target = join(scratch, 'sky-smoke.luau');
writeFileSync(target, program);
const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { cwd: root, encoding: 'utf8', timeout: 120000 });
rmSync(scratch, { recursive: true, force: true });
process.stdout.write(result.stdout || '');
process.stderr.write(result.stderr || '');
process.exit(result.status ?? 1);
