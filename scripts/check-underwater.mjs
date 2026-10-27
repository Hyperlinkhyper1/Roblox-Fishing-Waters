// Executes production camera/biome transitions with engine mocks, not Studio rendering.
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = (path) => readFileSync(join(root, path), 'utf8');
const program = `
local colorMethods = {}
function colorMethods:Lerp(other, alpha)
  return setmetatable({
    R = self.R + (other.R - self.R) * alpha,
    G = self.G + (other.G - self.G) * alpha,
    B = self.B + (other.B - self.B) * alpha,
  }, { __index = colorMethods })
end
local Color3 = { fromRGB = function(r, g, b)
  return setmetatable({ R = r, G = g, B = b }, { __index = colorMethods })
end }
local vector = {}
vector.__sub = function(a, b)
  local x, y = a.X - b.X, a.Y - b.Y
  return { Magnitude = math.sqrt(x*x + y*y) }
end
local Vector2 = { new = function(x, y) return setmetatable({ X = x, Y = y }, vector) end }
local UDim2 = { new = function(...) return {...} end, fromScale = function(...) return {...} end }
local Enum = {
  Material = {}, EasingStyle = { Sine = "Sine", Linear = "Linear" }, Font = { Garamond = "Garamond", GothamBold = "GothamBold" },
  RenderPriority = { Camera = { Value = 200 } },
}
local TweenInfo = { new = function(time) return { Time = time } end }
local Instance = { new = function(class)
  return { ClassName = class }
end }
local Lighting = {
  Ambient = Color3.fromRGB(0, 0, 0), objects = {},
  FogColor = Color3.fromRGB(190, 195, 200), FogStart = 50, FogEnd = 100000,
}
local surfaceFogColor = Lighting.FogColor
local Terrain = { objects = {} }
function Lighting:FindFirstChildOfClass(class) return self.objects[class] end
function Lighting:FindFirstChild(name) return self.objects[name] end
Terrain.FindFirstChildOfClass = Lighting.FindFirstChildOfClass
local atmosphere, grading, clouds = {}, {}, {}
local sky = { CelestialBodiesShown = true }
Lighting.objects.Sky = sky
local lightningGrading = { Brightness = 0.37 }
Lighting.objects.Atmosphere, Lighting.objects.ColorCorrectionEffect = atmosphere, lightningGrading
Lighting.objects.BiomeColorGrading = grading
Terrain.objects.Clouds = clouds
local camera = { CFrame = { Position = { X = 0, Y = 20, Z = 0 } } }
local workspace = { Terrain = Terrain, CurrentCamera = camera }
function workspace:GetServerTimeNow() return 1000 end
local attributes = { WeatherEpoch = 1000 }
function workspace:GetAttribute(name) return attributes[name] end
local weather = { rain = 0, storm = 0, cloudCover = 0 }
local Weather = { getState = function(time)
  assert(time == 1000, "Atmosphere must use the synchronized weather clock")
  return weather
end, supercellCover = function() return 0 end }
local task = { delay = function() end }
local pending, render = {}, nil
local TweenService = {}
function TweenService:Create(target, info, properties)
  local tween = { target = target, info = info, properties = properties }
  function tween:Play()
    for key, value in self.properties do self.target[key] = value end
    table.insert(pending, self)
  end
  function tween:Cancel() self.cancelled = true end
  return tween
end
local RunService = {}
function RunService:BindToRenderStep(_, priority, callback)
  assert(priority > Enum.RenderPriority.Camera.Value, "Effects must follow the current frame's camera")
  render = callback
end
local services = {
  Lighting = Lighting, TweenService = TweenService, RunService = RunService,
  ReplicatedStorage = { Shared = {} },
  Players = { LocalPlayer = { WaitForChild = function() return {} end } },
}
local game = { GetService = function(_, name) return services[name] end }
local Biomes = (function()
${read('src/shared/Biomes.luau')}
end)()
local Theme = (function()
${read('src/first/UITheme.luau')}
end)()
local DayNight = (function()
${read('src/shared/DayNight.luau')}
end)()
local Client = (function()
${read('src/client/BiomeAtmosphere.luau')
  .replace('require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))', 'Theme')
  .replace('require(ReplicatedStorage.Shared.Biomes)', 'Biomes')
  .replace('require(ReplicatedStorage.Shared.Weather)', 'Weather')
  .replace('require(ReplicatedStorage.Shared.DayNight)', 'DayNight')}
end)()
local function rgbEqual(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
local function move(x, y, z, dt)
  workspace.CurrentCamera.CFrame.Position = { X = x, Y = y, Z = z }
  render(dt or 1/60)
end
local function underwaterFog()
  assert(Terrain.WaterTransparency > 0 and Terrain.WaterTransparency <= 0.01,
    "Terrain's native underwater fog must limit visibility too; Lighting fog alone does not affect submerged terrain")
  assert(Terrain.WaterColor.B > Terrain.WaterColor.G and Terrain.WaterColor.G > Terrain.WaterColor.R,
    "Underwater water colour must be blue in every biome")
  assert(atmosphere.Parent == nil, "Atmosphere must leave Lighting so distance fog can render")
  assert(Lighting.FogStart == 0, "Thick underwater fog must start at the camera")
  assert(math.abs(Lighting.FogEnd * 0.28 - 10) < 0.00001,
    "Underwater fog must be fully opaque at 10 metres")
  assert(Lighting.FogColor.B > Lighting.FogColor.G and Lighting.FogColor.G > Lighting.FogColor.R,
    "Underwater fog must be blue")
end
local function surfaceFog()
  assert(atmosphere.Parent == Lighting, "Surface atmosphere must return after leaving water")
  assert(Lighting.FogStart == 50 and Lighting.FogEnd == 100000 and rgbEqual(Lighting.FogColor, surfaceFogColor),
    "Leaving water must restore the original distance fog settings")
end
Client.start()
render(1/60)
surfaceFog()
assert(rgbEqual(Terrain.WaterColor, Biomes.Normal.look.waterColor), "Initial surface biome")
move(0, -5, 0)
underwaterFog()
local firstDiveTween = pending[#pending]
move(0, -0.02, 0)
underwaterFog()
assert(pending[#pending] == firstDiveTween, "Surface margin must avoid flickering")
move(0, 5, 0)
surfaceFog()
assert(firstDiveTween.cancelled, "Rapid resurfacing must cancel the in-flight dive transition")
assert(Terrain.WaterTransparency == 0.3 and grading.Brightness == 0, "Surface clarity and grading restored")
assert(Lighting.Ambient.R == 0, "Surface ambient must be restored")
for _, biome in Biomes.list do
  move(biome.center.X, -8, biome.center.Y, 0.6)
  underwaterFog()
  move(biome.center.X, 5, biome.center.Y)
  surfaceFog()
  assert(rgbEqual(Terrain.WaterColor, biome.look.waterColor), "Resurfacing must restore the current biome")
  assert(atmosphere.Density == biome.look.density, "Biome haze must return")
end
move(0, -8, 0, 0.6)
move(3700, -8, 300, 0.6)
underwaterFog()
move(3700, 5, 300)
surfaceFog()
assert(rgbEqual(Terrain.WaterColor, Biomes.Volcanic.look.waterColor), "Crossing biomes underwater must restore the new biome")
move(Biomes.MapHalfSize + 20, -8, 0, 0.6)
surfaceFog()
assert(Terrain.WaterTransparency == 0.3, "Below sea level outside the ocean is not underwater")
move(0, Biomes.SeaFloor - 5, 0, 0.6)
surfaceFog()
assert(Terrain.WaterTransparency == 0.3, "Below the sea floor is not underwater")
workspace.CurrentCamera = nil
render(1/60)
workspace.CurrentCamera = { CFrame = { Position = { X = 0, Y = -8, Z = 0 } } }
render(1/60)
underwaterFog()
weather = { rain = 1, storm = 1, cloudCover = 1 }
move(0, -8, 0, 0.6)
underwaterFog()
assert(Lighting.Brightness == 2 and grading.Brightness == 0.06,
  "Storm darkening must preserve underwater clarity and grading")
move(0, 5, 0)
surfaceFog()
assert(math.abs(Lighting.Brightness - 0.85) < 0.00001,
  "Resurfacing during a storm must restore current weather darkening")
weather = { rain = 0.24, storm = 0, cloudCover = 0.5 }
move(0, 5, 0, 0.6)
assert(math.abs(Lighting.Brightness - (2 - 0.24 * 0.95)) < 0.00001,
  "Weather changes must refresh atmosphere without moving between biomes")
assert(lightningGrading.Brightness == 0.37,
  "Biome/weather grading must leave the separate lightning grading effect untouched")
print("PASS 10-metre underwater fog, atmosphere/fog restoration, all biomes, rapid transitions, surface margin, ocean bounds, camera replacement and weather transitions")
assert(Lighting.ClockTime == DayNight.START_HOUR, "Clients run the shared clock")
weather = { rain = 0, storm = 0, cloudCover = 0 }
move(0, 5, 0, 0.6)
local dayAmbient, dayBrightness, dayFog = Lighting.OutdoorAmbient, Lighting.Brightness, atmosphere.Color
attributes.ClockOverride = 23
move(0, 5, 0, 0.6)
assert(Lighting.ClockTime == 23, "Clock override reaches Lighting")
assert(sky.CelestialBodiesShown, "Clear nights retain their moon and stars")
local function sum(c) return c.R + c.G + c.B end
assert(Lighting.Brightness < dayBrightness and sum(Lighting.OutdoorAmbient) < sum(dayAmbient)
  and sum(atmosphere.Color) < sum(dayFog), "Night darkens the light, ambient and fog")
for _, condition in {
  { rain = 0.24, storm = 0, cloudCover = 0.5 },
  { rain = 0.62, storm = 0, cloudCover = 0.8 },
  { rain = 1, storm = 1, cloudCover = 1 },
  { kind = 'Supercell', rain = 0.5, storm = 0.35, cloudCover = 0.95 },
} do
  weather = condition
  move(0, 5, 0, 0.6)
  assert(not sky.CelestialBodiesShown and clouds.Cover == 1 and clouds.Density == 1 and clouds.Enabled,
    "Rain, storms and supercells obscure the night sky with a continuous cloud deck")
  assert(atmosphere.Haze >= Biomes.Normal.look.haze + weather.rain * 1.8 - 0.00001,
    "Night must not halve the wet-weather haze")
end
weather = { rain = 0, storm = 0, cloudCover = 0 }
move(0, 5, 0, 0.6)
assert(sky.CelestialBodiesShown, "Clearing weather restores the moon and stars")
print("PASS overcast rain/storm/supercell nights, hidden celestial bodies and clear-sky restoration")
attributes.ClockOverride = 12
move(0, 5, 0, 0.6)
assert(Lighting.Brightness == dayBrightness and rgbEqual(Lighting.OutdoorAmbient, dayAmbient), "Daylight returns")
attributes.ClockOverride = nil
print("PASS day/night: shared clock, darker nights, daylight restored")
weather = { kind = 'BlackHole', rain = 0, storm = 0, cloudCover = 1 }
move(0, 5, 0, 0.6)
assert(Lighting.Brightness == 0.45 and grading.Brightness < 0,
  'Black-hole weather darkens daylight throughout every biome')
assert(Terrain.WaterColor.B > Terrain.WaterColor.R and Terrain.WaterColor.R > Terrain.WaterColor.G,
  'Black-hole weather turns the ocean purple')
move(3700, -8, 300, 0.6)
assert(atmosphere.Parent == nil and math.abs(Lighting.FogEnd - 10 / 0.28) < 0.00001,
  'Black-hole weather preserves short underwater visibility')
assert(Terrain.WaterColor.R > Terrain.WaterColor.G, 'The void palette reaches underwater biomes')
weather = { rain = 0, storm = 0, cloudCover = 0 }
move(0, 5, 0, 0.6)
surfaceFog()
assert(rgbEqual(Terrain.WaterColor, Biomes.Normal.look.waterColor) and grading.Brightness == 0,
  'Ending black-hole weather restores the current biome and ordinary grading')
print('PASS black-hole purple/dark atmosphere, underwater visibility and normal-weather restoration')
`;
const temporary = mkdtempSync(join(tmpdir(), 'fishing-underwater-'));
try {
  const target = join(temporary, 'check.luau');
  writeFileSync(target, program);
  const result = spawnSync(process.env.LUTE || 'lute.exe', ['run', target], {
    cwd: root, encoding: 'utf8', timeout: 30000,
  });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} finally {
  rmSync(temporary, { recursive: true, force: true });
}
