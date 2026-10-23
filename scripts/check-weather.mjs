// Execute the real shared forecast/wave field and server service in Lute.
// These checks cover numerical behavior and replication, not Studio rendering/physics.
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = file => readFileSync(join(root, file), 'utf8');
const shared = read('src/shared/Weather.luau');
const harbour = read('src/server/Map/Harbour.luau');
const coordinates = text => [...text.matchAll(/\{\s*(\d+)\s*,\s*(\d+)\s*\}/g)].map(m => [Number(m[1]), Number(m[2])]);
const baySource = harbour.match(/local BAY = \{([\s\S]*?)\n\}/)?.[1];
const weatherBay = shared.match(/Weather.BaySketch = \{([\s\S]*?)\n\}/)?.[1];
assert.ok(baySource && weatherBay, 'Lake boundary must be defined explicitly');
assert.deepEqual(coordinates(weatherBay), coordinates(baySource), 'Weather shelter must follow the actual Harbour lake');
const outer = coordinates(harbour.match(/local OUTER = \{([\s\S]*?)\n\}/)[1]);
const mouth = coordinates(shared.match(/Weather.MouthSketch = (\{[^\n]*\})/)[1]);
assert.deepEqual(mouth, [outer.at(-1), outer[0]], 'Shelter must include the full cove between both headlands');
assert.match(harbour, /local SCALE = 1\.05\b/);
assert.match(harbour, /local SKETCH_CENTER = Vector2.new\(870, 1330\)/);
assert.match(read('src/shared/Biomes.luau'), /Biomes.Normal = \{[\s\S]*?center = Vector2.new\(0, 0\)/);
console.log('PASS lake boundary matches the actual main-island coastline');

const vectors = read('scripts/harbour-geometry.luau').split('local CFrame = {}')[0]
  .replace('local state = seed', 'local state = seed or 1847');
const service = read('src/server/WeatherService.luau').replace('require(ReplicatedStorage.Shared.Weather)', 'Weather');
const program = vectors + `
Vector3.yAxis = Vector3.new(0, 1, 0)
local now = 100000
local attributes = { WeatherEpoch = now, WeatherSeed = 1847 }
local workspace = {
  GetServerTimeNow = function() return now end,
  GetAttribute = function(_, key) return attributes[key] end,
  SetAttribute = function(_, key, value) attributes[key] = value end,
}
local Weather = (function()
${shared}
end)()
local function close(a, b, epsilon)
  assert(math.abs(a - b) < (epsilon or 1e-6), tostring(a) .. ' ~= ' .. tostring(b))
end
local previousWind, previousWave = 0, 0
for _, kind in { 'Clear', 'LightRain', 'Rain', 'Storm' } do
  attributes.WeatherOverride = kind
  local state = Weather.getState(now)
  assert(state.kind == kind and state.windSpeed > previousWind and state.waveAmplitude > previousWave,
    'Rain severity must increase both wind strength and wave height')
  assert(state.rain >= 0 and state.rain <= 1 and state.storm >= 0 and state.storm <= 1)
  assert(state.waveAmplitude <= 0.72, 'Storm troughs must not submerge the small rowboat bench')
  close(state.windDirection.Magnitude, 1)
  close(state.windDirection.Y, 0)
  previousWind, previousWave = state.windSpeed, state.waveAmplitude
end
print('PASS clear, light rain, rain and storm have increasing wind and waves')

attributes.WeatherOverride = nil
local walked, found = 0, {}
for _, stage in Weather.Schedule do
  local time = attributes.WeatherEpoch + walked + Weather.TransitionSeconds + 1
  local state = Weather.getState(time)
  assert(state.kind == stage.kind, 'Schedule must reach every condition')
  close(state.rain, Weather.Presets[stage.kind].rain)
  found[state.kind] = true
  if walked > 0 then
    local a = Weather.getState(attributes.WeatherEpoch + walked - 0.001)
    local b = Weather.getState(attributes.WeatherEpoch + walked + 0.001)
    assert(math.abs(a.windSpeed - b.windSpeed) < 0.002 and math.abs(a.rain - b.rain) < 0.001,
      'Weather transitions must not snap')
  end
  walked += stage.duration
end
assert(found.Clear and found.LightRain and found.Rain and found.Storm)
local last = Weather.getState(attributes.WeatherEpoch + Weather.CycleSeconds - 0.001)
local first = Weather.getState(attributes.WeatherEpoch + Weather.CycleSeconds + 0.001)
assert(math.abs(last.windSpeed - first.windSpeed) < 0.002, 'Cycle wrap must be continuous')
attributes.WeatherOverride = 'bad input'
assert(Weather.getState(now).kind == 'Clear', 'Unknown preview must safely use forecast')
attributes.WeatherOverride = 'Storm'
print('PASS complete forecast, smooth front transitions, cycle wrap and invalid preview fallback')

local lake, sea = Vector3.new(0, 0, 0), Vector3.new(1800, 0, 1800)
close(Weather.lakeExposure(lake), 0.18)
close(Weather.lakeExposure(sea), 1)
close(Weather.lakeExposure(Vector3.new(-650, 0, 0)), 1)
close(Weather.lakeExposure(Vector3.new(0, 0, -950)), 1)
local mouth = Vector3.new(((290 + 430) / 2 - 870) * 1.05, 0, ((1565 + 1340) / 2 - 1330) * 1.05)
local mouthExposure = Weather.lakeExposure(mouth)
assert(mouthExposure > 0.99, 'Bay mouth must join the open ocean without a wave wall')
local state = Weather.getState(now)
local lakeEnergy, seaEnergy = 0, 0
local lakeMax, seaMax = 0, 0
for step = 0, 1200 do
  local time = now + step / 10
  for _, point in { lake, sea, mouth } do
    local sample = Weather.sample(point, time, state)
    local cheapHeight, amplitude = Weather.heightAt(point, time, state)
    close(sample.height, cheapHeight)
    close(sample.amplitude, amplitude)
    close(sample.normal.Magnitude, 1)
    assert(sample.normal.Y > 0.85 and math.abs(sample.height) <= sample.amplitude + 1e-6,
      'Waves must remain bounded and cannot flip boats')
    assert(sample.height == sample.height and sample.pitch == sample.pitch and sample.roll == sample.roll)
    close(sample.height, Weather.sample(point, time, state).height)
  end
  local a = Weather.sample(lake, time, state)
  local b = Weather.sample(sea, time, state)
  lakeEnergy += a.height ^ 2
  seaEnergy += b.height ^ 2
  lakeMax = math.max(lakeMax, math.abs(a.height))
  seaMax = math.max(seaMax, math.abs(b.height))
end
assert(lakeEnergy < seaEnergy * 0.08 and lakeMax < seaMax * 0.3, 'Lake must have much lower waves')
print('PASS sheltered lake vs exposed sea, continuous mouth, deterministic synchronized height and bounded normals')

local callbacks = {}
local RunService = { Heartbeat = { Connect = function(_, callback) table.insert(callbacks, callback) end } }
local game = { GetService = function(_, name) return if name == 'RunService' then RunService else {} end }
local Service = (function()
${service}
end)()
attributes.WeatherOverride = nil
Service.start()
Service.start()
assert(#callbacks == 1, 'Repeated startup must not duplicate weather')
close(attributes.WeatherEpoch, now)
assert(type(attributes.WeatherSeed) == 'number' and attributes.WeatherKind == 'Clear')
for _, kind in { 'LightRain', 'Rain', 'Storm' } do
  attributes.WeatherOverride = kind
  now += 1
  callbacks[1](1)
  local state = Weather.getState(now)
  assert(attributes.WeatherKind == kind)
  close(attributes.WeatherRain, state.rain)
  close(attributes.WeatherWindSpeed, state.windSpeed)
  close(workspace.GlobalWind.Magnitude, state.windSpeed)
end
print('PASS single authoritative forecast, replicated state and global wind')
`;
const temporary = mkdtempSync(join(tmpdir(), 'fishing-weather-'));
try {
  const target = join(temporary, 'check.luau');
  writeFileSync(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} finally {
  rmSync(temporary, { recursive: true, force: true });
}
