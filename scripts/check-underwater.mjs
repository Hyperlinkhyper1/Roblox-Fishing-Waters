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
local Lighting = { Ambient = Color3.fromRGB(0, 0, 0), objects = {} }
local Terrain = { objects = {} }
function Lighting:FindFirstChildOfClass(class) return self.objects[class] end
function Lighting:FindFirstChild(name) return self.objects[name] end
Terrain.FindFirstChildOfClass = Lighting.FindFirstChildOfClass
local atmosphere, grading, clouds = {}, {}, {}
local lightningGrading = { Brightness = 0.37 }
Lighting.objects.Atmosphere, Lighting.objects.ColorCorrectionEffect = atmosphere, lightningGrading
Lighting.objects.BiomeColorGrading = grading
Terrain.objects.Clouds = clouds
local camera = { CFrame = { Position = { X = 0, Y = 20, Z = 0 } } }
local workspace = { Terrain = Terrain, CurrentCamera = camera }
function workspace:GetServerTimeNow() return 1000 end
local weather = { rain = 0, storm = 0, cloudCover = 0 }
local Weather = { getState = function(time)
  assert(time == 1000, "Atmosphere must use the synchronized weather clock")
  return weather
end }
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
local Client = (function()
${read('src/client/BiomeAtmosphere.luau')
  .replace('require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))', 'Theme')
  .replace('require(ReplicatedStorage.Shared.Biomes)', 'Biomes')
  .replace('require(ReplicatedStorage.Shared.Weather)', 'Weather')}
end)()
local function rgbEqual(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
local function move(x, y, z, dt)
  workspace.CurrentCamera.CFrame.Position = { X = x, Y = y, Z = z }
  render(dt or 1/60)
end
local function clearWater()
  assert(Terrain.WaterTransparency == 0.9, "Nearby underwater scenery must stay clear")
  assert(Terrain.WaterColor.B > Terrain.WaterColor.G and Terrain.WaterColor.G > Terrain.WaterColor.R,
    "Native underwater distance fog must be blue in every biome")
  assert(atmosphere.Density == 0.3 and atmosphere.Offset == 0, "Underwater fog must start at the camera")
  assert(atmosphere.Haze == 0, "Surface haze must not obscure underwater scenery")
  assert(atmosphere.Color.B > atmosphere.Color.G and atmosphere.Decay.B > atmosphere.Decay.R,
    "Underwater fog must be blue")
end
Client.start()
render(1/60)
assert(rgbEqual(Terrain.WaterColor, Biomes.Normal.look.waterColor), "Initial surface biome")
move(0, -5, 0)
clearWater()
local firstDiveTween = pending[#pending]
move(0, -0.02, 0)
clearWater()
assert(pending[#pending] == firstDiveTween, "Surface margin must avoid flickering")
move(0, 5, 0)
assert(firstDiveTween.cancelled, "Rapid resurfacing must cancel the in-flight dive transition")
assert(Terrain.WaterTransparency == 0.55 and grading.Brightness == 0, "Surface clarity and grading restored")
assert(Lighting.Ambient.R == 0, "Surface ambient must be restored")
for _, biome in Biomes.list do
  move(biome.center.X, -8, biome.center.Y, 0.6)
  clearWater()
  move(biome.center.X, 5, biome.center.Y)
  assert(rgbEqual(Terrain.WaterColor, biome.look.waterColor), "Resurfacing must restore the current biome")
  assert(atmosphere.Density == biome.look.density, "Biome haze must return")
end
move(0, -8, 0, 0.6)
move(3700, -8, 300, 0.6)
clearWater()
move(3700, 5, 300)
assert(rgbEqual(Terrain.WaterColor, Biomes.Volcanic.look.waterColor), "Crossing biomes underwater must restore the new biome")
move(Biomes.MapHalfSize + 20, -8, 0, 0.6)
assert(Terrain.WaterTransparency == 0.55, "Below sea level outside the ocean is not underwater")
move(0, Biomes.SeaFloor - 5, 0, 0.6)
assert(Terrain.WaterTransparency == 0.55, "Below the sea floor is not underwater")
workspace.CurrentCamera = nil
render(1/60)
workspace.CurrentCamera = { CFrame = { Position = { X = 0, Y = -8, Z = 0 } } }
render(1/60)
clearWater()
weather = { rain = 1, storm = 1, cloudCover = 1 }
move(0, -8, 0, 0.6)
clearWater()
assert(Lighting.Brightness == 2 and grading.Brightness == 0.06,
  "Storm darkening must preserve underwater clarity and grading")
move(0, 5, 0)
assert(math.abs(Lighting.Brightness - 0.85) < 0.00001,
  "Resurfacing during a storm must restore current weather darkening")
weather = { rain = 0.24, storm = 0, cloudCover = 0.5 }
move(0, 5, 0, 0.6)
assert(math.abs(Lighting.Brightness - (2 - 0.24 * 0.95)) < 0.00001,
  "Weather changes must refresh atmosphere without moving between biomes")
assert(lightningGrading.Brightness == 0.37,
  "Biome/weather grading must leave the separate lightning grading effect untouched")
print("PASS underwater clarity, blue fog, all biomes, rapid transitions, surface margin, ocean bounds, camera replacement and weather transitions")
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
