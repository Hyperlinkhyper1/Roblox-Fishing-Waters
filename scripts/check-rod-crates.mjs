// Execute the real crate client and reveal with recording Roblox mocks.
// Camera rendering and the feel of the animation still need Studio.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const temporaryRoot = resolve(tmpdir());
const folder = await mkdtemp(join(temporaryRoot, 'fishing-crates-'));
const read = (path) => readFile(join(root, path), 'utf8');
try {
  const physics = await read('scripts/rod-physics.luau');
  const menu = await read('scripts/player-menu.luau');
  const bobberSkins = await read('src/shared/BobberSkins.luau');
  const sources = {
    FISHING_ROD: (await read('src/shared/FishingRod.luau'))
      .replace('require(script.Parent.RodSkins)', '{ DefaultWear = 0.2 }'),
    REVEAL: (await read('src/client/RodCrateReveal.luau'))
      .replace('require(ReplicatedStorage.Shared.FishingRod)', 'rodFactory')
      .replace('require(script.Parent.Freecam)', '{ stop = function() end }'),
    THEME: await read('src/first/UITheme.luau'),
    SKINS: await read('src/shared/RodSkins.luau'),
    CASE: (await read('src/client/RodCaseOpening.luau'))
      .replace('require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))', 'Theme')
      .replace('require(Shared:WaitForChild("FishingRod"))', 'FishingRod')
      .replace('require(Shared:WaitForChild("RodSkins"))', 'RodSkins'),
    CLIENT: (await read('src/client/RodCrates.luau'))
      .replace('require(game:GetService("ReplicatedFirst"):WaitForChild("UITheme"))', 'Theme')
      .replace('require(Shared:WaitForChild("FishingRod"))', 'FishingRod')
      .replace('require(Shared:WaitForChild("RodSkins"))', 'RodSkins')
      .replace('require(Shared:WaitForChild("BobberSkins"))', () => `(function()\n${bobberSkins}\nend)()`)
      .replace('require(Shared:WaitForChild("FishingBobber"))', 'FishingRod')
      .replace('require(script.Parent:WaitForChild("RodCrateReveal"))', 'CrateReveal')
      .replace('require(script.Parent:WaitForChild("RodCaseOpening"))', 'RodCaseOpening'),
  };
  for (const [name, prefix] of [
    ['reveal', physics.slice(0, physics.indexOf('local function loadDynamics()'))],
    ['ui', menu.slice(0, menu.indexOf('local Theme = (function()'))],
  ]) {
    let program = prefix + await read(`scripts/rod-crates-${name}.luau`);
    for (const [marker, source] of Object.entries(sources)) {
      program = program.replace(`-- ${marker}_SOURCE --`, () => source);
    }
    const path = join(folder, `${name}.luau`);
    await writeFile(path, program);
    const result = spawnSync(process.env.LUTE || 'lute', ['run', path], {
      cwd: root, encoding: 'utf8', timeout: 30000,
    });
    if (result.stdout) process.stdout.write(result.stdout);
    if (result.stderr) process.stderr.write(result.stderr);
    if (result.error) throw result.error;
    if (result.status !== 0) throw new Error(`Crate ${name} checks failed (${result.status})`);
  }
} finally {
  if (dirname(resolve(folder)) !== temporaryRoot) throw new Error('Unexpected temporary directory');
  await rm(folder, { recursive: true, force: true });
}
