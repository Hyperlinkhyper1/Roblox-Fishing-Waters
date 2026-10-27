// Production sign canvas and saved-map regression checks; no Roblox rendering.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = path => readFile(join(root, path), 'utf8');
const shared = await read('scripts/drydock-geometry.luau');
const primitives = (await read('scripts/harbour-geometry.luau')).split('local CFrame = {}')[0];
let program = shared.slice(0, shared.indexOf('local checks, failures'))
  .replace('-- SHARED_PRIMITIVES --', () => primitives);
// Supply SurfaceGui defaults so omitted sizing modes reproduce stretched canvases.
const defaults = `
local originalNew = Instance.new
function Instance.new(class)
  local item = originalNew(class)
  if class == "SurfaceGui" then
    item.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    item.CanvasSize = Vector2.new(800, 600)
    item.PixelsPerStud = 50
    item.Face = Enum.NormalId.Front
  end
  return item
end
function instanceMethods:FindFirstChildWhichIsA(class, recursive)
  for _, child in (if recursive then self:GetDescendants() else self:GetChildren()) do
    if child:IsA(class) then return child end
  end
  return nil
end
`;
program = program.replace('local function loadLowPoly()', defaults + '\nlocal function loadLowPoly()');
const modules = {
  LOWPOLY: 'src/server/Map/LowPoly.luau', PROPS: 'src/server/Map/Props.luau',
  FISHFREEZERGEOMETRY: 'src/server/Map/FishFreezerGeometry.luau',
  FISHFREEZER: 'src/server/Map/FishFreezer.luau',
  IMPORTEDMODEL: 'src/server/Map/ImportedModel.luau',
  SHOPDESKGEOMETRY: 'src/server/Map/ShopDeskGeometry.luau',
  CASHREGISTERGEOMETRY: 'src/server/Map/CashRegisterGeometry.luau',
  SHOPDESK: 'src/server/Map/ShopDesk.luau',
  BASEHOUSE: 'src/server/Map/BaseHouse.luau', MEDITERRANEAN: 'src/server/Map/Mediterranean.luau',
  BEACHDETAILS: 'src/server/Map/BeachDetails.luau', ROWBOAT: 'src/server/Rowboat.luau',
  FISHINGBOAT: 'src/server/FishingBoat.luau',
  SHIPWRIGHT: 'src/server/Map/Shipwright.luau',
  DRYDOCKINTERIOR: 'src/server/Map/DrydockInterior.luau', DRYDOCK: 'src/server/Map/Drydock.luau',
  PLAZAHOUSES: 'src/server/Map/PlazaHouses.luau', RODSHOP: 'src/server/Map/RodShop.luau',
  STORAGERACK: 'src/server/Map/StorageRack.luau', CARGO: 'src/shared/Cargo.luau',
  BACKPACKCATALOG: 'src/shared/BackpackCatalog.luau', BACKPACKMODELS: 'src/shared/BackpackModels.luau',
  BACKPACKSHOP: 'src/server/Map/BackpackShop.luau', KITCHEN: 'src/server/Map/Kitchen.luau',
  DININGROOM: 'src/server/Map/DiningRoom.luau', FURNITURESHOP: 'src/server/Map/FurnitureShop.luau', HARBOUR: 'src/server/Map/Harbour.luau',
  FURNITURECATALOG: 'src/shared/FurnitureCatalog.luau',
  BIOMES: 'src/shared/Biomes.luau',
};
for (const [name, path] of Object.entries(modules)) {
  let source = (await read(path)).replace(/local (\w+) = require\(script\.Parent\.(?:Parent\.)?(\w+)\)/g, 'local $1 = dependencies.$2');
  source = source.replace(/local (\w+) = require\(ReplicatedStorage\.Shared\.(\w+)\)/g, 'local $1 = dependencies.$2');
  if (name === 'HARBOUR') source = source.replace(/return Harbour\s*$/, 'return { makeShape = makeShape, heightAt = heightAt, buildBase = buildBase, buildPlaza = buildPlaza }');
  const marker = '-- ' + name + '_SOURCE --';
  if (!program.includes(marker)) throw new Error('Missing source hook: ' + name);
  program = program.replace(marker, () => source);
}
const map = (await read('src/server/Map/init.luau'))
  .replace(/local (\w+) = require\([^\n]+\)/g, 'local $1 = dependencies.$1')
  .replace(/game:GetService\("(?:Lighting|ReplicatedStorage)"\)/g, '{}');
program += '\ndependencies.Theme = (function()\n' + await read('src/first/UITheme.luau') + '\nend)()\n';
program += '\nlocal function loadMap()\n' + map + '\nend\nlocal Map = loadMap()\n';
program += await read('scripts/sign-text.luau');
const startup = await read('src/server/init.server.luau');
if (!(startup.indexOf('Map.ensureSignText()') > startup.indexOf('.ensureBases(workspace.Map)')))
  throw new Error('Saved-map sign repair must run after map upgrades');
const temporary = await mkdtemp(join(tmpdir(), 'fishing-signs-'));
try {
  const target = join(temporary, 'signs.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute.exe', ['run', target], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Sign checks failed: ' + result.status);
} finally {
  await rm(temporary, { recursive: true, force: true });
}
