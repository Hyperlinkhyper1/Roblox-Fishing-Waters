// Execute cosmetic production modules against geometry-recording mocks.
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = file => readFileSync(join(root, file), 'utf8');
const primitives = read('scripts/harbour-geometry.luau').split('local CFrame = {}')[0];
const mocks = read('scripts/drydock-geometry.luau').split('local function loadLowPoly()')[0]
  .replace('-- SHARED_PRIMITIVES --', () => primitives);
const world = read('src/client/BlackHoleWeather.luau')
  .replace('require(ReplicatedStorage.Shared.Weather)', 'Weather');
const fish = read('src/shared/FishModels.luau')
  .replace('require(script.Parent.FishMutations)', 'FishMutations');
const effects = read('src/client/MutationEffects.luau')
  .replace('require(ReplicatedStorage.Shared.FishModels)', 'FishModels');
const program = mocks + `
Vector3.one = Vector3.new(1,1,1)
local originalIndex = instanceMt.__newindex
function instanceMt.__newindex(self, key, value)
  if key == 'Position' then self._props.CFrame = CFrame.new(value)
  else originalIndex(self, key, value) end
end
function instanceMethods:AddTag(tag) self._tags[tag] = true end
function instanceMethods:HasTag(tag) return self._tags[tag] == true end
local workspace = Instance.new('Folder')
local now, center, enabled = 0, nil, true
workspace.CurrentCamera = { CFrame = CFrame.new(0,40,300) }
function workspace:GetServerTimeNow() return now end
local callbacks = {}
local run = { RenderStepped = { Connect = function(_, callback) table.insert(callbacks, callback) end } }
local taggedFish = {}
local collection = {
  GetInstanceRemovedSignal = function() return { Connect = function() end } end,
  GetTagged = function(_, tag)
    local result = {}
    for _, item in taggedFish do if item:HasTag(tag) then table.insert(result, item) end end
    return result
  end,
}
local services = {
  Players = { LocalPlayer = { GetAttribute = function() return enabled end } },
  ReplicatedStorage = {}, RunService = run, CollectionService = collection,
}
game.GetService = function(_, key) return services[key] end
local Weather = { BlackHoleRadius = 250, blackHolePosition = function() return center end }
local World = (function() ${world} end)()
local function step()
  now += 0.1
  for _, callback in callbacks do callback(0.1) end
end
World.start(); World.start()
assert(#callbacks == 1, 'Black hole start is idempotent')
step()
assert(#workspace:GetChildren() == 0, 'Inactive weather allocates no world effects')
center = Vector3.new(100,0,-200)
step()
local model = workspace:FindFirstChild('BlackHoleWeatherEffects')
assert(model, 'The event creates its singularity')
local count = #model:GetDescendants()
local horizon = model:FindFirstChild('EventHorizon')
assert(horizon.Position.X == 100 and horizon.Position.Z == -200, 'The hole follows the selected location')
for _, item in model:GetDescendants() do
  if item:IsA('BasePart') then
    assert(item.Anchored and not item.CanCollide and not item.CanQuery and not item.CanTouch,
      'Cosmetic parts cannot interfere with boats, casts or shoreline raycasts')
  end
end
local origin = model:FindFirstChild('VortexOrigin')
local point = origin:FindFirstChild('VortexPoint1')
local first = point.Position
for _ = 1,50 do step() end
assert((point.Position - first).Magnitude > 0.001, 'The singularity lens animates')
assert(#model:GetDescendants() == count, 'Animation never allocates more instances')
center = Vector3.new(-500,0,600); step()
assert(horizon.Position.X == -500 and horizon.Position.Z == 600, 'Relocating uses the same bounded effect')
enabled = false; step()
assert(#workspace:GetChildren() == 0, 'Performance toggle cleans up the event geometry')
enabled = true; step()
assert(workspace:FindFirstChild('BlackHoleWeatherEffects'), 'Re-enabling restores the active event')
center = nil; step()
assert(#workspace:GetChildren() == 0, 'Ending the event destroys all world effects')
print('PASS black-hole location, bounded/idempotent animation, cosmetic physics, toggle and end cleanup')
local FishMutations = { parts = function(key)
  local set = {}
  for token in string.gmatch(key or '', '[^+]+') do set[token] = true end
  return set
end }
local FishModels = (function() ${fish} end)()
local black = Instance.new('Model'); black.Name = 'VoidTest'; black.Parent = workspace
for index, name in {'Body','Eye','Bone','Wound','Fin'} do
  local item = Instance.new('Part'); item.Name = name
  item.Size = Vector3.new(if index == 1 then 4 else 0.4, 1, 0.5)
  item.Color = Color3.new(1,1,1); item.Transparency = 0.5
  item.Parent = black
end
FishModels.mutate(black, {Mutation = 'Corrupted+VoidTouched+Rainbow+Astral', Corruptions = {}})
assert(black:HasTag(FishModels.VOID_TAG) and not black:HasTag(FishModels.RAINBOW_TAG), 'Void owns the appearance of colour combinations')
local lens
for _, item in black:GetDescendants() do
  if item:IsA('BasePart') then
    assert(item.Color.R == 0 and item.Color.G == 0 and item.Color.B == 0 and item.Transparency == 0,
      'Every fish part is opaque black, including eyes, wounds and bones')
    assert(item:GetAttribute('RainbowHue') == nil, 'Rainbow does not repaint void fish')
  elseif item:IsA('Attachment') then lens = item end
end
assert(lens, 'Void fish has a distortion lens')
table.insert(taggedFish, black)
local MutationEffects = (function() ${effects} end)()
MutationEffects.start()
local before = lens.Position
step()
assert((before - lens.Position).Magnitude == 0, 'Distant fish keep a still lens without animation work')
workspace.CurrentCamera.CFrame = CFrame.new(0,4,10)
step()
assert((before - lens.Position).Magnitude > 0.001, 'Void lens ripples around its fish')
local body = black:FindFirstChild('Body')
local small = (lens.Position - body:GetAttribute('VoidAuraCenter')).Magnitude
body.Size = body.Size * 3
step()
assert(lens.Position.Magnitude > small * 2, 'Distortion scales with trophy fish')
print('PASS opaque-black combined mutations, eyes/bones/wounds, animated distortion and trophy scaling')
local windy = Instance.new('Model'); windy.Name = 'WindyTest'; windy.Parent = workspace
for index, name in {'Body','Eye','Fin'} do
  local item = Instance.new('Part'); item.Name = name
  item.Size = Vector3.new(if index == 1 then 4 else 0.4, 1, 0.5)
  item.Color = Color3.new(0.2, 0.4, 0.3)
  item.Parent = windy
end
windy:SetAttribute('BoundsCenter', Vector3.new(0, 0, 0)); windy:SetAttribute('BoundsSize', Vector3.new(4, 1, 0.5))
FishModels.mutate(windy, {Mutation = 'Windy'})
local streaks, gusts = 0, 0
for _, item in windy:GetDescendants() do
  if item:IsA('ParticleEmitter') then
    assert(item.Parent == windy:FindFirstChild('Body'), 'Wind particles ride the body')
    if item.Name == 'WindyStreaks' then streaks += 1 elseif item.Name == 'WindyGusts' then gusts += 1 end
  end
end
assert(streaks == 1 and gusts == 1, 'Windy fish trail wind streaks and gusts')
local eye, fin, body = windy:FindFirstChild('Eye'), windy:FindFirstChild('Fin'), windy:FindFirstChild('Body')
assert(eye.Color.R == 0.2 and eye.Color.G == 0.4, 'Eyes keep their colour')
assert(body.Color.B > 0.3 and body.Color.B < 0.5 and body.Transparency == 0, 'The body takes only a faint sheen')
assert(fin.Transparency > 0 and fin.Transparency < 0.2, 'Fins turn slightly see-through')
print('PASS windy fish: faint sheen, translucent fins, wind particles, untouched eyes')
`;
const temporary = mkdtempSync(join(tmpdir(), 'blackhole-visuals-'));
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
