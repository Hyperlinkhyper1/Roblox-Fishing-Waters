import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { Script, runInNewContext } from 'node:vm';

const source = readFileSync('C:/Users/ayden/Files/Intellij-Programs/luma-app/server/lib/admin_projects.dart', 'utf8');
const script = source.match(/static const fishingWatersScript = r'''([\s\S]*?)''';/)[1];
new Script(script);
const icons = script.slice(script.indexOf('  function ico('), script.indexOf('  function esc('));
const render = script.slice(script.indexOf('  function renderWeather()'), script.indexOf('  function renderForecast(s)'));
const elements = new Map();
const element = id => {
  if (!elements.has(id)) elements.set(id, { dataset: {}, querySelectorAll: () => [], setAttribute() {} });
  return elements.get(id);
};
const weather = {
  kind: 'Foggy', fog: 1, rain: 0, storm: 0, cloudCover: 0.9,
  windSpeed: 4, windAngle: 0, waveAmplitude: 0.3,
  radar: { peakRain: 0, peakStorm: 0, peakWind: 4, peakWave: 0.3 },
};
const state = {
  servers: [{ jobId: 'test', players: [], seenAt: 0, weather }],
  weather: { kinds: ['Clear', 'Foggy', 'Rain', 'Storm'], override: 'Foggy' },
};
const context = {
  state, $: element, server: () => state.servers[0], choosingKind: () => null,
  esc: String, label: s => s || 'Auto', compass: () => 'N', bearingOf: () => 0,
  ago: () => 'now', shortJob: s => s, renderLocations() {}, renderForecast() {},
};
runInNewContext(icons + render + '\nrenderWeather();', context);
assert.match(element('fwNow').innerHTML, /Foggy/);
assert.match(element('fwNow').innerHTML, /Marine fog/);
assert.match(element('fwNow').innerHTML, /100%/);
assert.match(element('fwNow').innerHTML, /M3 7h18M6 12h12M3 17h18/);
assert.match(element('fwKinds').innerHTML, /data-kind="Foggy"/);
weather.kind = 'Clear'; weather.fog = 0; state.weather.override = null;
runInNewContext('renderWeather();', context);
assert.match(element('fwNow').innerHTML, /Clear/);
assert.doesNotMatch(element('fwNow').innerHTML, /Marine fog/);
console.log('PASS admin JavaScript syntax, dry-radar Foggy status, fog icon, fog meter, selection and clearing');
