// Run the real scenery builders and saved-map migration against recording mocks.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
const primitive = read('scripts/harbour-geometry.luau').split('local CFrame = {}')[0];
const mocks = read('scripts/drydock-geometry.luau').split('local function loadLowPoly()')[0]
  .replace('-- SHARED_PRIMITIVES --', () => primitive);
let source = read('scripts/house-collision-geometry.luau').replace('-- MOCKS --', () => mocks);
for (const name of ['LowPoly', 'Props', 'Mediterranean', 'PlazaHouses']) {
  const production = read(`src/server/Map/${name}.luau`)
    .replace(/require\(script\.Parent\.(\w+)\)/g, 'dependencies.$1');
  source = source.replace(`-- ${name} --`, () => production);
}
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'house-collision-'));
try {
  const target = path.join(temporary, 'test.luau');
  fs.writeFileSync(target, source);
  const result = spawnSync(process.env.LUTE || 'lute.exe', ['run', target], {
    cwd: root, encoding: 'utf8', timeout: 60000, maxBuffer: 4 * 1024 * 1024,
  });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} finally {
  fs.rmSync(temporary, { recursive: true });
}
