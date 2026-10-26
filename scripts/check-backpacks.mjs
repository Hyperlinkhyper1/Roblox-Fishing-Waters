import { freezerRuntime, injectFreezer } from './freezer-test-runtime.mjs';
// Exercise production backpack modules against Roblox recording doubles.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
const read = async p => (await readFile(new URL('../' + p, import.meta.url), 'utf8')).replace(/\r\n/g, '\n');
const primitives = (await read('scripts/harbour-geometry.luau')).split('local CFrame = {}')[0];
const mocks = (await read('scripts/drydock-geometry.luau')).split('local function loadLowPoly()')[0].replace('-- SHARED_PRIMITIVES --', () => primitives);
const replacements = {
 'script.Parent.BackpackCatalog': 'Backpacks', 'ReplicatedStorage.Shared.BackpackModels': 'Models',
 'ReplicatedStorage.Shared.BackpackCatalog': 'Backpacks', 'ReplicatedStorage.Shared.Cargo': 'Grid',
 'script.Parent.PlazaHouses': 'PlazaHouses', 'script.Parent.Props': 'Props',
 'script.Parent.BoatService': 'Boats', 'script.Parent.AnglerData': 'Data',
 'ReplicatedStorage.Shared.Aboard': 'function() return aboard end',
 'ReplicatedStorage.Shared.BoatCatalog': 'BoatCatalog', 'ReplicatedStorage.Shared.AnglerCatalog': 'Catalog',
 'ReplicatedStorage.Shared.FishCatch': '{formatKg=tostring}', 'ReplicatedStorage.Shared.FishModels': '{show=function() end}', 'ReplicatedStorage.Shared.FishMutations': '{label=function() return "" end}',
 'game:GetService("ReplicatedFirst"):WaitForChild("UITheme")': 'Theme',
};
function inject(source) { for (const [key,value] of Object.entries(replacements)) source = source.replaceAll('require(' + key + ')', value); return source; }
let program = mocks + await read('scripts/backpacks.luau');
for (const [marker,path] of Object.entries({ GRID:'src/shared/Cargo.luau', BAGS:'src/shared/BackpackCatalog.luau', MODELS:'src/shared/BackpackModels.luau', DATA:'src/server/AnglerData.luau', PROPS:'src/server/Map/Props.luau', BUILDER:'src/server/Map/BackpackShop.luau', SERVICE:'src/server/BackpackService.luau', CARGO_SERVICE:'src/server/CargoService.luau', CLIENT_CARGO:'src/client/CargoHold.luau', CLIENT_SHOP:'src/client/BackpackShop.luau' })) {
 let source = await read(path);
 if (marker === 'DATA') {
  source = source.replace('local Cargo\n','local Cargo = Grid\n');
  source = source.replace('local FreezerPacking, FreezerModels', 'local FreezerPacking = (function()\n' + await read('src/shared/FreezerPacking.luau') + '\nend)()\nlocal FreezerModels = {catchBounds=function() return Vector3.new(1,1,1) end}');
 }
 if (marker === 'PROPS') source = source.replace('require(script.Parent.LowPoly)', '{}');
 program = program.replace('-- ' + marker + '_SOURCE --', () => inject(source));
}
const folder = await mkdtemp(join(tmpdir(), 'fishing-backpacks-'));
try {
 const target = join(folder,'check.luau'); await writeFile(target,await freezerRuntime() + program);
 const result = spawnSync(process.env.LUTE || 'lute',['run',target],{encoding:'utf8',timeout:30000});
 if(result.stdout) process.stdout.write(result.stdout); if(result.stderr) process.stderr.write(result.stderr);
 if(result.error) throw result.error; if(result.status !== 0) throw new Error('Backpack checks failed');
} finally { await rm(folder,{recursive:true,force:true}); }
