// Builds the boats in the project's recording mock, then checks refit paint and
// the drydock lift sequence. Run: node scripts/check-boat-refit.mjs.
// Construction checks only: not Roblox rendering, physics or the refit menu.
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const read = path => readFileSync(join(root, path), 'utf8');
const wrap = (name, body) => `local function load${name}()\n${body}\nend\nlocal ${name} = load${name}()\n`;
const deps = source => source.replace(/local (\w+) = require\([^\n]+\)/g, 'local $1 = dependencies.$1');
const prelude = read('scripts/shipwright-model.luau').split('local function loadShipwright()')[0]
  .replace('kind == "WedgePart" or kind == "VehicleSeat"', 'kind == "WedgePart" or kind == "VehicleSeat" or kind == "Seat"');
const harness = read('scripts/boat-refit.luau');
if (!harness.includes('-- MODULES --')) throw new Error('Missing boat refit harness module marker');
const [setup, checks] = harness.split('-- MODULES --');
let program = prelude + setup;
for (const boat of ['Rowboat', 'FishingBoat', 'Speedboat', 'RacingSpeedboat', 'PatrolBoat', 'Trawler']) {
  // The cooler's click handlers need signals the recording mock doesn't have.
  program += wrap(boat, deps(read(`src/server/${boat}.luau`)).replace(
    'function Rowboat.ensureCoolerInteraction(model: Model)',
    'function Rowboat.ensureCoolerInteraction(model: Model) do return end'));
  program += `dependencies.${boat} = ${boat}\n`;
}
const cargo = read('src/shared/Cargo.luau');
program += wrap('BoatUpgrades', read('src/shared/BoatUpgrades.luau')
  .replace(/local Cargo = [^\n]+/, () => `local Cargo = (function()\n${cargo}\nend)()`));
program += 'dependencies.BoatUpgrades = BoatUpgrades\n';
program += wrap('Refit', deps(read('src/server/BoatRefitService.luau')));
program += wrap('DrydockLaunch', deps(read('src/server/DrydockLaunch.luau')));
program += checks;

const temporary = mkdtempSync(join(tmpdir(), 'boat-refit-'));
try {
  const target = join(temporary, 'check.luau');
  writeFileSync(target, program);
  const result = spawnSync(process.env.LUTE || 'lute.exe', ['run', target], { cwd: root, stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Boat refit checks failed (Lute exit ${result.status})`);
} finally {
  rmSync(temporary, { recursive: true, force: true });
}
