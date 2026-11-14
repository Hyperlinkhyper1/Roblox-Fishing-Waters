// Executes the production net-worth and leaderboard code against deterministic
// saves and recording UI. Native Studio rendering and live DataStores are separate.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = path => readFile(join(root, path), 'utf8');
const temporary = await mkdtemp(join(tmpdir(), 'fishing-companies-'));
function run(path) {
  const result = spawnSync(process.env.LUTE || 'lute', ['run', path], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Company checks failed (${result.status})`);
}
try {
  const sharedPath = relative(temporary, join(root, 'src/shared')).replaceAll('\\', '/');
  const serverPath = relative(temporary, join(root, 'src/server')).replaceAll('\\', '/');
  const boatFurniture = await read('src/shared/BoatFurniture.luau');
  const worth = (await read('src/server/CompanyWorth.luau'))
    .replace('require("../shared/BoatFurniture")', 'BoatFurniture')
    .replaceAll('require("../shared/', `require("${sharedPath}/`)
    .replace('require("./StockPrices")', `require("${serverPath}/StockPrices")`);
  const worthProgram = (await read('scripts/company-worth.luau'))
    .replace('local Worth = require("../src/server/CompanyWorth")', () => `local Color3 = { fromRGB = function(...) return {...} end }\nlocal BoatFurniture = (function()\n${boatFurniture}\nend)()\nlocal Worth = (function()\n${worth}\nend)()`)
    .replace('local BoatFurniture = require("../src/shared/BoatFurniture")', '')
    .replaceAll('require("../src/shared/', `require("${sharedPath}/`)
    .replaceAll('require("../src/server/', `require("${serverPath}/`);
  const worthPath = join(temporary, 'worth.luau');
  await writeFile(worthPath, worthProgram);
  run(worthPath);
  const source = (await read('src/server/CompanyLeaderboardService.luau'))
    .replace('require(script.Parent.BoatService)', 'BoatService')
    .replace('require(script.Parent.CompanyWorth)', 'Worth')
    .replace('require(script.Parent.Map.Leaderboards)', 'Boards')
    .replace(/return Service\s*$/, 'Service.writeOne=writeOne; Service.readBoard=readBoard; Service.pending=pending; return Service');
  const servicePath = join(temporary, 'service.luau');
  await writeFile(servicePath, (await read('scripts/company-leaderboard-service.luau')).replace('-- SOURCE --', () => source));
  run(servicePath);
  const mocks = await read('scripts/player-menu.luau');
  const readTheme = await read('src/first/UITheme.luau');
  const readRanks = await read('src/shared/FishingRanks.luau');
  const client = (await read('src/client/Leaderboard.luau'))
    .replace('require(ReplicatedFirst:WaitForChild("UITheme"))', 'Theme')
    .replace('require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FishingRanks"))', 'FishingRanks');
  const clientPath = join(temporary, 'client.luau');
  const program = mocks.slice(0, mocks.indexOf('local Theme = (function()'))
    + (await read('scripts/company-leaderboard-client.luau'))
      .replace('-- THEME --', () => readTheme)
      .replace('-- RANKS --', () => readRanks)
      .replace('-- CLIENT --', () => client);
  await writeFile(clientPath, program);
  run(clientPath);
} finally {
  if (dirname(temporary) !== resolve(tmpdir())) throw new Error('Unexpected temporary path');
  await rm(temporary, { recursive: true, force: true });
}
