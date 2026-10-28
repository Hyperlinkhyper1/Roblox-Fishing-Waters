// Run the real VolumetricClouds and SupercellWeather client modules against
// minimal Roblox mocks: cloud field, forced supercell, funnels and toggles.
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
assert(#render == 3 and #heartbeat == 1, "Repeated startup keeps one canopy, one distant sky and one supercell renderer")
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

-- Clear forecast stage: fair-weather clouds only, no supercell.
attributes.WeatherOverride = "Clear"
frames(1, 1/60)
assert(count(function(o) return o.ClassName == "Model" and o.Name == "FairCloud" end) <= 2,
  "Initial sky creation is spread across frames")
frames(150, 1/30)
local function billowsOf(model)
  local list = {}
  for _, o in created do
    if o.Name == "Billows" and not gone(o) and o.Parent and o.Parent.Parent == model then table.insert(list, o) end
  end
  return list
end
local fair, fairParts, fairBillows = 0, 0, 0
for _, o in created do
  if o.ClassName == "Model" and o.Name == "FairCloud" and not gone(o) then
    fair += 1
    for _, p in created do
      if p.ClassName == "Part" and p.Parent == o and not gone(p) then
        fairParts += 1
        assert(p.CFrame and p.CFrame.p.Y > 300, "Clouds float at altitude")
        assert(p.Transparency == 1, "Fair clouds are soft billows, never solid spheres")
        assert(not p.CanCollide and not p.CanTouch and not p.CanQuery and not p.CastShadow, "Billow anchors are inert")
      end
    end
    for _, e in billowsOf(o) do
      fairBillows += 1
      assert(e.Enabled and (e.emitted or 0) > 0, "A placed cloud starts its billows and fills half at once")
      assert(e.Texture == "rbxasset://textures/particles/smoke_main.dds", "Billows use the soft smoke texture")
    end
  end
end
assert(fair > 10, "Clear skies still hold fair-weather cumulus: " .. fair)
assert(fairParts <= fair * 2 and fairBillows == fairParts,
  "Each fair cloud is two billow anchors: " .. fairParts .. " parts for " .. fair .. " clouds")
assert(count(function(o) return o.Name == "Tornado" end) == 0, "No tornado in clear weather")
print("clear clouds", fair, "parts", fairParts)

local sample, sampleCloud
for _, o in created do
  if o.ClassName == "Part" and o.Parent and o.Parent.Name == "FairCloud" and not gone(o)
    and Vector3.new(o.CFrame.Position.X, 0, o.CFrame.Position.Z).Magnitude < 1500 then
    sample, sampleCloud = o, o.Parent
    break
  end
end
assert(sample, "A visible fair cloud is available for motion checks")
local layers, darkest, brightest, largest = 0, 1, 0, 0
for _, e in billowsOf(sampleCloud) do
  layers += 1
  local keys = e.Color[1]
  darkest, brightest = math.min(darkest, keys[1][2].R), math.max(brightest, keys[2][2].R)
  largest = math.max(largest, e.Size[1][2][2])
end
assert(layers >= 2, "Clouds have a flat base and a billowing body")
assert(brightest - darkest > 0.12, "Shaded bases and brighter billows remain distinct")
assert(largest <= 100, "Billow sprites stay within the particle size limit")
local sampleEmitter = billowsOf(sampleCloud)[1]
local steadyTransparency = sampleEmitter.Transparency
-- Clouds hold still: once placed, a settled sky moves no parts at all. Moving
-- thousands of huge puffs each frame caused Octree and shadow-map spikes.
local function stillFor(n, dt, renderOnly)
  local before, movedBefore = sample.CFrame.Position, movedParts
  for _ = 1, n do
    if renderOnly then
      now += dt
      for _, f in render do f(dt) end
    else
      frames(1, dt)
    end
  end
  return (sample.CFrame.Position - before).Magnitude == 0, movedParts - movedBefore
end
for _, dt in { 1/60, 1/144, 1/30, 0.011, 0.024 } do
  local still, moved = stillFor(20, dt, false)
  assert(still, "Clouds stay where they were built at every frame rate")
  assert(moved == 0, "A settled clear sky moves no parts between frames: " .. moved)
  assert(sampleEmitter.Transparency == steadyTransparency, "A settled sky never rewrites billow transparency")
end
assert(stillFor(20, 1/144, true), "Render-only frames leave the sky in place")

-- Moving far away retires the old field: it stops billowing and its last puffs
-- dissolve where they are before the model goes.
workspace.CurrentCamera.CFrame = CFrame.new(10000, 8, 0)
frames(40, 1/60)
assert(not sampleEmitter.Enabled and not gone(sample), "Outgoing clouds dissolve instead of disappearing")
assert(stillFor(10, 1/60, false), "Retiring clouds dissolve where they are")
workspace.CurrentCamera.CFrame = CFrame.new(0, 8, 0)
frames(200, 1/30)
assert(not gone(sample), "A retired cloud keeps its model while its last billows fade")
frames(400, 1/30)
assert(gone(sample), "Retired cloud models are cleaned up")
print("PASS billowed clouds, bounded builds, frame-rate independent stillness, stable billows and dissolving retirement")

local function assertCovered(position, label)
  for _, o in created do
    if o.Name == "RainCloudBody" and not gone(o) and o.CFrame and o.Transparency < 0.1 then
      local center = o.CFrame.Position
      local x, z = (position.X - center.X) / (o.Size.X/2), (position.Z - center.Z) / (o.Size.Z/2)
      if center.Y - o.Size.Y/2 > position.Y and x*x + z*z < 1 then return o end
    end
  end
  error("Rain must have an opaque volumetric cloud directly overhead: " .. label)
end
local function renderOnly()
  now += 1/144
  for _, f in render do f(1/144) end
end
-- No Heartbeat, settling time or random grid occupancy may leave rain uncovered.
for _, seed in { 17, 1847, 999983 } do
  attributes.WeatherSeed = seed
  for _, kind in { "LightRain", "Rain", "Storm", "Supercell" } do
    attributes.WeatherOverride = kind
    attributes.SupercellSince = now - 60
    for _, position in {
      Vector3.new(0, 8, 0), Vector3.new(-5000, 8, 5000), Vector3.new(5000, 8, -5000), Vector3.new(123, 600, -456),
    } do
      workspace.CurrentCamera.CFrame = CFrame.new(position)
      renderOnly()
      assertCovered(position, kind .. " seed " .. seed .. " on its first frame / after teleport")
    end
    local drift = Weather.getState(now).windDirection * 7 * (now - attributes.WeatherEpoch)
    for _, delta in { -0.01, 0.01 } do
      local position = Vector3.new(drift.X + 180 + delta, 8, drift.Z + 180 + delta)
      workspace.CurrentCamera.CFrame = CFrame.new(position)
      renderOnly()
      assertCovered(position, "diagonal grid corner / " .. kind)
    end
  end
end
attributes.WeatherSeed, attributes.WeatherOverride = 4242, "Rain"
workspace.CurrentCamera.CFrame = CFrame.new(0, 8, 0)
frames(180, 1/60)
local covered = assertCovered(workspace.CurrentCamera.CFrame.Position, "detailed rain")
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
local scudBefore = scud.CFrame.Position
renderOnly()
assert((scud.CFrame.Position - scudBefore).Magnitude == 0, "The settled rain deck holds still between frames")
assert(count(function(o) return o.Name == "RainCloudTile" end) <= 36, "The local cloud pool stays bounded")

-- Camera and avatar can be far apart; both wet locations need coverage.
local root = { Position = Vector3.new(-3500, 8, 3500) }
Players.LocalPlayer.Character = { FindFirstChild = function(_, name) return if name == "HumanoidRootPart" then root else nil end }
workspace.CurrentCamera.CFrame = CFrame.new(3500, 8, -3500)
renderOnly()
assertCovered(root.Position, "avatar away from the camera")
assertCovered(workspace.CurrentCamera.CFrame.Position, "free camera away from the avatar")
for _, detailed in { false, true, false } do
  playerAttributes.VolumetricCloudsEnabled = detailed
  playerAttributes.WeatherEffectsEnabled = false
  renderOnly()
  local body = assertCovered(root.Position, "graphics toggle never removes the rain deck")
  assertCovered(workspace.CurrentCamera.CFrame.Position, "low graphics camera")
  assert(body.CastShadow == false, "The moving rain deck never casts shadows, at any graphics level")
end
for frame = 1, 100 do
  root.Position = Vector3.new(frame * 1200, 8, frame * -600)
  workspace.CurrentCamera.CFrame = CFrame.new(root.Position + Vector3.new(0, 0, 20))
  renderOnly()
  assertCovered(root.Position, "rapid travel frame " .. frame)
  assert(count(function(o) return o.Name == "RainCloudTile" end) <= 36, "Rapid travel cannot leak cloud tiles")
end
Players.LocalPlayer.Character = nil
playerAttributes.VolumetricCloudsEnabled, playerAttributes.WeatherEffectsEnabled = true, true
workspace.CurrentCamera = nil
renderOnly()
assert(count(function(o) return o.Name == "RainCloudTile" end) == 0, "Camera loss cleans up the local rain deck")
workspace.CurrentCamera = { CFrame = CFrame.new(0, 8, 0) }
renderOnly()
assertCovered(workspace.CurrentCamera.CFrame.Position, "camera recovery in rain")
-- A naturally arriving rain band needs the same guarantee as an admin preset.
attributes.WeatherOverride = nil
now = attributes.WeatherEpoch + 480
local naturalWet
for x = -5000, 5000, 500 do
  for z = -5000, 5000, 500 do
    local point = Vector3.new(x, 8, z)
    if Weather.getState(now, point).rain > 0.01 then naturalWet = point break end
  end
  if naturalWet then break end
end
assert(naturalWet, "Natural forecast has a rain band for this integration check")
workspace.CurrentCamera.CFrame = CFrame.new(naturalWet)
renderOnly()
assertCovered(naturalWet, "natural rain band")
attributes.WeatherOverride = "Clear"
frames(260, 1/60)
assert(count(function(o) return o.Name == "RainCloudTile" end) == 0, "Clear weather fades and removes the rain deck")
print("PASS guaranteed overhead volume in all rain, seeds, grid corners, teleports, high ground, natural fronts, detached cameras and low graphics; detailed billows/scud/wisps and bounded cleanup")
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
frames(1, 1/144)
assert(moves >= moveCount + 1, "The supercell still moves on a high refresh rate frame")
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
  -- Storm decks: no moving shadow casters, and only nearby clouds carry lobes.
  local eye = workspace.CurrentCamera.CFrame.Position
  local stormParts, budget = 0, 0
  for _, o in created do
    if not gone(o) and o.Parent and (o.Parent.Name == "NimbostratusCloud" or o.Parent.Name == "CumulonimbusCloud") then
      if o.ClassName == "Part" then
        stormParts += 1
        assert(o.CastShadow == false, "Rain-bearing clouds cast no shadows")
      end
    end
    if not gone(o) and o.Name == "Billows" and o.Enabled then budget += o:GetAttribute("Billows") or 0 end
  end
  print("storm parts", stormParts, "live billows", budget)
  assert(stormParts > 0 and stormParts < 600, "A storm sky stays within a few hundred parts: " .. stormParts)
  assert(budget < 4000, "The whole sky keeps a bounded number of billows: " .. budget)
end

-- Mobile: lightweight mandatory rain deck, no distant field, simpler supercell.
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
print("PASS volumetric cloud field, forced supercell with tornado funnel, mobile detail and weather toggle cleanup")
`;
const target = join(scratch, 'sky-smoke.luau');
writeFileSync(target, program);
const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { cwd: root, encoding: 'utf8', timeout: 120000 });
rmSync(scratch, { recursive: true, force: true });
process.stdout.write(result.stdout || '');
process.stderr.write(result.stderr || '');
process.exit(result.status ?? 1);
