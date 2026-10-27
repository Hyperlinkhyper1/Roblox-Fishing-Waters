// Execute the real menu and preview against recording Roblox mocks.
// These checks cover UI state, selection, camera fitting and delayed replication.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = path => readFile(join(root, path), 'utf8');
const folder = await mkdtemp(join(tmpdir(), 'boat-menu-'));
try {
  const mocks = await read('scripts/player-menu.luau');
  let program = mocks.slice(0, mocks.indexOf('local Theme = (function()')) + await read('scripts/boat-menu.luau');
  const sources = {
    THEME: await read('src/first/UITheme.luau'),
    CATALOG: await read('src/shared/BoatCatalog.luau'),
    PREVIEW: await read('src/client/BoatPreview.luau'),
    CLIENT: (await read('src/client/Boating.luau'))
      .replace('require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))', 'Theme')
      .replace('require(ReplicatedStorage.Shared.BoatCatalog)', 'BoatCatalog')
      .replace('require(ReplicatedStorage.Shared.Weather)', '{ getState = function() return { kind = "Clear" } end }')
      .replace('require(script.Parent.DrydockCamera)', 'DrydockCamera')
      .replace('require(script.Parent.BoatPreview)', 'BoatPreview')
      .replace(
        'require(script.Parent.BoatCamera)',
        '(function() local modes = { "Trailing", "Front", "Cockpit", "Side" }; local index = 1; return { label = function() return modes[index] end, cycle = function() index = index % #modes + 1; return modes[index] end, setActive = function() end, stop = function() end } end)()',
      ),
  };
  for (const [name, source] of Object.entries(sources)) program = program.replace(`-- ${name}_SOURCE --`, () => source);
  const path = join(folder, 'check.luau');
  await writeFile(path, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', path], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Boat menu checks failed (${result.status})`);
} finally {
  await rm(folder, { recursive: true, force: true });
}
