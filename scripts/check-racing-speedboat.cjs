// Run the production racing hull in the shared Roblox recording mock.
// Geometry and assembly checks do not exercise Studio rendering or physics.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/server/RacingSpeedboat.luau'), 'utf8');
const mock = fs.readFileSync(path.join(__dirname, 'shipwright-model.luau'), 'utf8')
  .split('local function loadShipwright()')[0]
  .replace('kind == "WedgePart" or kind == "VehicleSeat"', 'kind == "WedgePart" or kind == "VehicleSeat" or kind == "Seat"');
const program = mock + '\nlocal RacingSpeedboat = (function()\n' + source + '\nend)()\n' + fs.readFileSync(path.join(__dirname, 'racing-speedboat-model.luau'), 'utf8');
const folder = fs.mkdtempSync(path.join(os.tmpdir(), 'racing-speedboat-'));
const target = path.join(folder, 'test.luau');
try {
  fs.writeFileSync(target, program);
  const result = spawnSync(process.env.LUTE || 'lute.exe', ['run', target], { stdio: 'inherit' });
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} finally { fs.unlinkSync(target); fs.rmdirSync(folder); }
