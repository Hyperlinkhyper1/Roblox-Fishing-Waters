// Exercise the real sport-cruiser builder with the shared Roblox geometry mock.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const mock = fs.readFileSync(path.join(__dirname, 'shipwright-model.luau'), 'utf8')
  .split('local function loadShipwright()')[0]
  .replace('kind == "WedgePart" or kind == "VehicleSeat"', 'kind == "WedgePart" or kind == "VehicleSeat" or kind == "Seat"');
const source = fs.readFileSync(path.join(root, 'src/server/Speedboat.luau'), 'utf8');
const harness = fs.readFileSync(path.join(__dirname, 'speedboat-model.luau'), 'utf8');
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'speedboat-model-'));
const target = path.join(temporary, 'check.luau');
try {
  fs.writeFileSync(target, mock + harness.replace('-- SPEEDBOAT_SOURCE --', () => source));
  const result = spawnSync(process.env.LUTE || 'lute.exe', ['run', target], { cwd: root, stdio: 'inherit', timeout: 30000 });
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} finally {
  if (fs.existsSync(target)) fs.unlinkSync(target);
  fs.rmdirSync(temporary);
}
