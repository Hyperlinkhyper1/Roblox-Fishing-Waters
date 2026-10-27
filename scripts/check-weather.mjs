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
assert.match(harbour, /local SCALE = 0\.85\b/);
assert.match(harbour, /local SKETCH_CENTER = Vector2.new\(870, 1330\)/);
assert.match(read('src/shared/Biomes.luau'), /Biomes.Normal = \{[\s\S]*?center = Vector2.new\(0, 0\)/);
console.log('PASS lake boundary matches the actual main-island coastline');

const vectors = read('scripts/harbour-geometry.luau').split('local CFrame = {}')[0]
  .replace('local state = seed', 'local state = seed or 1847');
const service = read('src/server/WeatherService.luau').replace('require(ReplicatedStorage.Shared.Weather)', 'Weather')
  .replace('require(ReplicatedStorage.Shared.DayNight)', 'DayNight');
const dayNight = read('src/shared/DayNight.luau');
const program = vectors + `
Vector3.yAxis = Vector3.new(0, 1, 0)
local now = 100000
local attributes = { WeatherEpoch = now, WeatherSeed = 1847 }
local workspace = {
  GetServerTimeNow = function() return now end,
  GetAttribute = function(_, key) return attributes[key] end,
  SetAttribute = function(_, key, value) attributes[key] = value end,
}
local function typeof(value)
  return if type(value) == 'table' and value.X ~= nil and value.Y ~= nil and value.Z ~= nil then 'Vector3' else type(value)
end
local Weather = (function()
${shared}
end)()
local function close(a, b, epsilon)
  assert(math.abs(a - b) < (epsilon or 1e-6), tostring(a) .. ' ~= ' .. tostring(b))
end
for _, stage in Weather.Schedule do
  assert(stage.kind ~= 'BlackHole', 'The admin-only event can never occur in the forecast')
end
attributes.WeatherOverride = 'BlackHole'
assert(Weather.getState(now).kind ~= 'BlackHole' and Weather.mutationContext(Vector3.zero) == nil, 'Missing center cannot activate the event')
attributes.BlackHolePosition = Vector3.new(100, 0, -200)
assert(Weather.getState(now).kind == 'BlackHole', 'Valid dashboard override activates the event')
assert(Weather.getState(now, Vector3.new(-5000, 0, 5000)).kind == 'BlackHole', 'Event weather is global even outside local rain bands')
local edge = Weather.mutationContext(Vector3.new(350, 100, -200))
assert(edge.corrupted and edge.voidTouched, 'Void Touched includes the radius boundary and ignores fishing height')
local far = Weather.mutationContext(Vector3.new(351, 0, -200))
assert(far.corrupted and not far.voidTouched, 'Distant fishing still guarantees corruption without Void Touched')
for _, point in { Vector3.new(5201, 0, 0), Vector3.new(0 / 0, 0, 0), Vector3.new(0, math.huge, 0), false } do
  attributes.BlackHolePosition = point
  assert(Weather.blackHolePosition() == nil, 'Malformed or off-map event centers are ignored')
end
attributes.BlackHolePosition = Vector3.new(100, 0, -200)
attributes.WeatherOverride = nil
assert(Weather.mutationContext(Vector3.zero) == nil, 'Ending the event immediately disables mutation guarantees')
attributes.BlackHolePosition = nil
print('PASS admin-only BlackHole forecast, validated center, global weather and location-aware mutation context')

-- Natural supercells: rare, only around the storm stage, continuous, and the
-- same answer everywhere (integer hashing, no sin-based randomness).
for _, stage in Weather.Schedule do
  assert(stage.kind ~= 'Supercell', 'Supercells are not a fixed forecast stage')
end
local cycles, stormy = 600, 0
local window = Weather.SupercellWindow
assert(window[1] == 300 and window[2] == 750, 'Supercells live from the rain before the storm to the rain after it')
local sampleCell, sampleTime
for cycle = 0, cycles - 1 do
  local start = attributes.WeatherEpoch + cycle * Weather.CycleSeconds
  assert(Weather.supercell(start + window[1] - 1) == nil and Weather.supercell(start + window[2] + 1) == nil,
    'No supercell outside its window')
  local middle = Weather.supercell(start + (window[1] + window[2]) / 2)
  if middle then
    stormy += 1
    assert(middle.strength > 0.99 and not middle.forced, 'A natural cell peaks mid-window')
    assert(math.abs(middle.position.X) <= 1800 and math.abs(middle.position.Z) <= 1800, 'Its track crosses near the islands')
    sampleCell, sampleTime = sampleCell or middle, sampleTime or start + (window[1] + window[2]) / 2
    local a, b = Weather.supercell(start + window[1] + 30), Weather.supercell(start + window[1] + 30.05)
    assert((a.position - b.position).Magnitude < 1 and math.abs(a.strength - b.strength) < 0.01, 'Cells move and grow smoothly')
  else
    assert(Weather.supercell(start + window[1] + 10) == nil, 'A cycle either grows a cell or stays without one')
  end
end
assert(math.abs(stormy / cycles - Weather.SupercellChance) < 0.04, 'About one cycle in six grows a supercell: ' .. stormy)
local under = Weather.getState(sampleTime, sampleCell.position)
assert(under.kind == 'Supercell' and under.windSpeed > 55 and under.storm > 0.99, 'Under the cell it is a violent local storm')
local farAway = sampleCell.position + Vector3.new(4000, 0, 0)
assert(Weather.getState(sampleTime, farAway).kind ~= 'Supercell', 'Supercell weather stays local')
now = sampleTime
local windy = Weather.mutationContext(sampleCell.position + Vector3.new(0, 30, 0))
assert(windy and windy.windy and not windy.corrupted, 'Fishing under the cell can turn catches windy')
assert(Weather.mutationContext(sampleCell.position + Vector3.new(Weather.SupercellRadius, 0, 0)) == nil, 'Beyond its core there is no windy chance')
attributes.WeatherOverride = 'Storm'
assert(Weather.supercell(sampleTime) == nil and Weather.mutationContext(sampleCell.position) == nil, 'Any other override clears natural cells')
attributes.WeatherOverride = nil

-- Tornadoes hang under the rear flank, ramp in and out and move continuously.
local spotted, peak = 0, 0
for cycle = 0, cycles - 1 do
  local start = attributes.WeatherEpoch + cycle * Weather.CycleSeconds
  if Weather.supercell(start + 525) then
    for t = start + window[1], start + window[2], 2 do
      local cell = Weather.supercell(t)
      for _, tornado in Weather.tornadoes(t) do
        spotted += 1
        peak = math.max(peak, tornado.strength)
        assert(tornado.strength >= 0 and tornado.strength <= 1 and tornado.radius >= 22 and tornado.radius <= 42)
        assert((tornado.position - cell.position).Magnitude < Weather.SupercellCoreRadius, 'Tornadoes touch down under the cell')
        local later = Weather.tornadoes(t + 0.05)
        for _, next in later do
          if next.id == tornado.id then
            assert((next.position - tornado.position).Magnitude < 1.5 and math.abs(next.strength - tornado.strength) < 0.05,
              'A tornado never jumps')
          end
        end
      end
    end
    if spotted > 200 then break end
  end
end
assert(spotted > 0 and peak > 0.95, 'Natural supercells drop full-strength tornadoes')
assert(#Weather.tornadoes(attributes.WeatherEpoch + 10) == 0 or Weather.supercell(attributes.WeatherEpoch + 10), 'No tornado without a cell')

-- A forced cell circles the summoned spot and keeps producing tornadoes.
attributes.WeatherOverride = 'Supercell'
attributes.SupercellPosition = Vector3.new(400, 0, -300)
attributes.SupercellSince = sampleTime
local forced = Weather.supercell(sampleTime + 600)
assert(forced.forced and forced.strength == 1, 'A forced cell is fully grown after its ramp')
close((forced.position - Vector3.new(400, 0, -300)).Magnitude, Weather.ForcedSupercellOrbit, 1e-6)
assert(Weather.getState(sampleTime + 600).kind == 'Supercell', 'The override is reported globally')
local forcedTornadoes = 0
for t = sampleTime + 30, sampleTime + 1800, 5 do
  forcedTornadoes += #Weather.tornadoes(t)
end
assert(forcedTornadoes > 50, 'A forced supercell keeps dropping tornadoes')
attributes.SupercellPosition = Vector3.new(0 / 0, 0, 0)
close((Weather.supercell(sampleTime + 600).position).Magnitude, Weather.ForcedSupercellOrbit, 1e-6)
attributes.WeatherOverride, attributes.SupercellPosition, attributes.SupercellSince = nil, nil, nil
now = 100000
print('PASS rare deterministic supercells, local Supercell weather, windy mutation zone, tornadoes and forced cells')
local previousWind, previousWave = 0, 0
for _, kind in { 'Clear', 'LightRain', 'Rain', 'Storm' } do
  attributes.WeatherOverride = kind
  local state = Weather.getState(now)
  assert(state.kind == kind and state.windSpeed > previousWind and state.waveAmplitude > previousWave,
    'Rain severity must increase both wind strength and wave height')
  assert(state.rain >= 0 and state.rain <= 1 and state.storm >= 0 and state.storm <= 1)
  assert(state.waveAmplitude <= Weather.MaxWaveAmplitude and Weather.MaxWaveAmplitude == 4.5, 'Exposed seas allow taller, bounded storm swells')
  close(state.windDirection.Magnitude, 1)
  close(state.windDirection.Y, 0)
  previousWind, previousWave = state.windSpeed, state.waveAmplitude
end
print('PASS clear, light rain, rain and storm have increasing wind and waves')

-- Explicit presets must not disappear in a regional front's clear gap.
for _, seed in { 17, 1847, 999983 } do
  attributes.WeatherSeed = seed
  for _, kind in { 'Clear', 'LightRain', 'Rain', 'Storm' } do
    attributes.WeatherOverride = kind
    local preset = Weather.getState(now)
    for _, point in { Vector3.zero, Vector3.new(1800, 0, 1800), Vector3.new(-5000, 0, 5000) } do
      local localState = Weather.getState(now, point)
      assert(localState.kind == kind, 'Selected weather must reach every player')
      close(localState.rain, preset.rain)
      close(localState.storm, preset.storm)
      close(localState.windSpeed, preset.windSpeed)
      close(Weather.sample(point, now).amplitude, localState.waveAmplitude)
      if kind ~= 'Clear' then
        assert(localState.cloudCover == 1, 'Every rain preset needs full overcast')
      end
      if not Weather.inLake(point) then close(localState.waveAmplitude, preset.waveAmplitude) end
    end
  end
  attributes.WeatherOverride = 'Supercell'
  attributes.SupercellPosition, attributes.SupercellSince = Vector3.zero, now - 60
  for _, point in { Vector3.zero, Vector3.new(-5000, 0, 5000) } do
    local localState = Weather.getState(now, point)
    assert(localState.kind == 'Supercell' and localState.rain >= 0.5 and localState.windSpeed > 29,
      'Forced supercells keep a rainy, windy backdrop beyond the rotating core')
    assert(localState.cloudCover == 1, 'Supercell skies remain overcast')
  end
end
attributes.WeatherSeed = 1847
attributes.SupercellPosition, attributes.SupercellSince = nil, nil
print('PASS selected rain, storm and supercell retain precipitation, overcast, wind and synchronized waves across the map')

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
local mouth = Vector3.new(((290 + 430) / 2 - 870) * 0.85, 0, ((1565 + 1340) / 2 - 1330) * 0.85)
local mouthExposure = Weather.lakeExposure(mouth)
assert(mouthExposure > 0.99, 'Bay mouth must join the open ocean without a wave wall')
local state = Weather.getState(now)
-- Check both sides of every bay edge, including the headlands at the mouth.
local boundary = { Weather.MouthSketch[1] }
for _, point in Weather.BaySketch do table.insert(boundary, point) end
table.insert(boundary, Weather.MouthSketch[2])
local function world(point)
  return Vector3.new((point[1] - 870) * 0.85, 0, (point[2] - 1330) * 0.85)
end
local previous = world(boundary[#boundary])
for _, point in boundary do
  local current = world(point)
  local edge = current - previous
  local normal = Vector3.new(-edge.Z, 0, edge.X).Unit
  for _, fraction in { 0.1, 0.5, 0.9 } do
    local center = previous:Lerp(current, fraction)
    local a, b = center - normal * 0.05, center + normal * 0.05
    assert(math.abs(Weather.lakeExposure(a) - Weather.lakeExposure(b)) < 0.002,
      'Shelter must remain continuous across the whole bay boundary')
    for _, time in { now, now + 3, now + 7 } do
      local first, second = Weather.sample(a, time, state), Weather.sample(b, time, state)
      assert(math.abs(first.height - second.height) < 0.03 and (first.normal - second.normal).Magnitude < 0.03,
        'Adjacent headland samples must not snap wave height or tilt')
    end
  end
  previous = current
end
print('PASS continuous bay-edge heights and normals at the actual island scale')
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

-- The same timestamp produces clear gaps, rain bands and harsh storm cores.
-- Regional variation belongs to the natural forecast, not an explicit preset.
attributes.WeatherOverride = nil
now = attributes.WeatherEpoch + 480
local minimumRain, maximumRain, maximumWave = 1, 0, 0
local roughPosition
for x = -5000, 5000, 250 do
  for z = -5000, 5000, 250 do
    local point = Vector3.new(x, 0, z)
    local localState = Weather.getState(now, point)
    minimumRain = math.min(minimumRain, localState.rain)
    maximumRain = math.max(maximumRain, localState.rain)
    if localState.waveAmplitude > maximumWave then
      maximumWave, roughPosition = localState.waveAmplitude, point
    end
    close(Weather.sample(point, now, localState).amplitude, localState.waveAmplitude)
    local sea = Weather.sample(point, now)
    assert(sea.normal.Y > 0.85 and sea.amplitude <= Weather.MaxWaveAmplitude)
    close(sea.height, Weather.sample(point, now, localState).height)
  end
end
assert(minimumRain < 0.08 and maximumRain > 0.9 and maximumWave > 3.5,
  'Storms must have clear gaps and harsh cores with much higher exposed waves')
local a = Weather.getState(now, roughPosition)
local b = Weather.getState(now + 0.01, roughPosition + Vector3.new(0.01, 0, 0))
assert(math.abs(a.rain - b.rain) < 0.001 and math.abs(a.waveAmplitude - b.waveAmplitude) < 0.002,
  'Moving fronts and travel across them must remain continuous')
local moved = false
for _, system in Weather.getSystems(now) do
  local point = Vector3.new(system.x, 0, system.z)
  local before = Weather.getState(now, point)
  local after = Weather.getState(now + 300, point)
  if math.abs(before.rain - after.rain) > 0.05 then moved = true end
end
assert(moved, 'Fronts must move and evolve rather than remain painted on the map')
local radar = Weather.radar(now)
assert(radar.version == 1 and #radar.cells == radar.resolution ^ 2 and radar.peakWave > 3.5)
for index, cell in radar.cells do
  local column, row = (index - 1) % radar.resolution, math.floor((index - 1) / radar.resolution)
  local point = Vector3.new(-radar.halfSize + column * radar.halfSize * 2 / (radar.resolution - 1), 0,
    -radar.halfSize + row * radar.halfSize * 2 / (radar.resolution - 1))
  local measured = Weather.getState(now, point)
  assert(math.abs(cell[1] - measured.rain) <= 0.0051 and math.abs(cell[2] - measured.storm) <= 0.0051)
  assert(math.abs(cell[3] - measured.windSpeed) <= 0.0051 and math.abs(cell[4] - measured.waveAmplitude) <= 0.0051)
end
attributes.WeatherOverride = 'Clear'
assert(Weather.radar(now).peakRain == 0 and Weather.radar(now).peakStorm == 0)
print('PASS regional severity, tall storm seas, smooth moving fronts and radar parity with game samples')

local callbacks = {}
local RunService = { Heartbeat = { Connect = function(_, callback) table.insert(callbacks, callback) end } }
local Lighting = {}
local game = { GetService = function(_, name) return if name == 'RunService' then RunService elseif name == 'Lighting' then Lighting else {} end }
local DayNight = (function()
${dayNight}
end)()
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

attributes.WeatherOverride = nil
close(DayNight.clockTime(attributes.WeatherEpoch), DayNight.START_HOUR)
now = attributes.WeatherEpoch + (22 - DayNight.START_HOUR) * DayNight.SECONDS_PER_HOUR
callbacks[1](1)
close(Lighting.ClockTime, 22)
assert(DayNight.isNight(Lighting.ClockTime) and DayNight.darkness(Lighting.ClockTime) == 1, 'Late evening is full night')
now = attributes.WeatherEpoch + 24 * DayNight.SECONDS_PER_HOUR
close(DayNight.clockTime(now), DayNight.START_HOUR)
assert(not DayNight.isNight(13) and DayNight.darkness(13) == 0, 'Afternoon is full day')
assert(DayNight.isNight(18) and DayNight.isNight(5.9) and not DayNight.isNight(6), 'Night runs 18:00 to 06:00')
local last = DayNight.darkness(0)
for step = 1, 24 * 60 do
  local clock = step / 60
  local dark = DayNight.darkness(clock % 24)
  assert(dark >= 0 and dark <= 1 and math.abs(dark - last) < 0.02, 'Twilight must fade, not snap')
  last = dark
end
attributes.ClockOverride = 23
close(DayNight.clockTime(now), 23)
attributes.ClockOverride = nil
print('PASS day/night clock: shared epoch, night window, smooth twilight and Studio override')
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
