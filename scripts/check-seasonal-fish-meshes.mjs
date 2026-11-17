// Send every new species' real loft through the real client renderer and its
// EditableMesh/AssetService recording doubles. This does not emulate device budgets.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { freezerRuntime } from './freezer-test-runtime.mjs';
import { seasonalFishIds } from './seasonal-fish.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = async (file) => (await readFile(join(root, file), 'utf8')).replace(/\r\n/g, '\n');
const doubles = (await read('scripts/fish-meshes.luau'))
  .split('local rings = {')[0].replace('-- MOCKS --', '');
const client = (await read('src/client/FishMeshes.luau'))
  .replace('require(ReplicatedStorage.Shared.FishModels)', 'FishModels')
  .replace('require(ReplicatedStorage.Shared.MeshFeatures)', '{ EditableMeshesEnabled = true }')
  .replace('require(script.Parent.EditableMeshBudget)', 'Budget');
const exercise = `
${doubles}
local Budget = (function()
${await read('src/client/EditableMeshBudget.luau')}
end)()
local client = (function()
${client}
end)()
local world = Instance.new("Folder")
local models = {}
for _, id in { ${seasonalFishIds.map(id => JSON.stringify(id)).join(', ')} } do
	local model = assert(FishModels.create(id), id .. ": real model builds")
	model.Parent = world
	table.insert(models, model)
	task.spawn(client.hydrate, model)
	-- Small concurrent batches exercise the lock without exhausting the fixture's
	-- bounded coroutine scheduler with fifty waiting requests at once.
	if #models % 5 == 0 then flush() end
end
flush()
assert(#warnings == 0, table.concat(warnings, "\\n"))
assert(peakDynamic == 1 and liveDynamic == 0, "Species serialize scratch allocations and release them")
assert(allocations == #models and copies == #models * 7, "Each species builds all seven fixed skin bands")
local triangles, vertices = 0, 0
local function finite(n) return n == n and math.abs(n) < math.huge end
for _, model in models do
	local bands, hidden = 0, 0
	for _, part in model:GetDescendants() do
		if part.Name == "LoftSkin" then
			bands += 1
			local mesh = part.mesh
			assert(mesh and mesh.FixedSize and not mesh.destroyed and #mesh.faces > 0,
				model.Name .. ": live fixed mesh has triangles")
			for _, point in mesh.points do
				assert(finite(point.X) and finite(point.Y) and finite(point.Z), model.Name .. ": finite vertices")
			end
			for _, face in mesh.faces do
				local a, b, c = mesh.points[face[1]], mesh.points[face[2]], mesh.points[face[3]]
				assert(a and b and c and (b - a):Cross(c - a).Magnitude > 1e-10,
					model.Name .. ": triangle indexes exist and enclose positive area")
			end
			vertices += #mesh.points
			triangles += #mesh.faces
		elseif part:GetAttribute("LoftFallback") then
			local mesh = part:FindFirstChildOfClass("SpecialMesh")
			assert(mesh and mesh.Scale == Vector3.zero, model.Name .. ": mesh replaces fallback")
			hidden += 1
		end
	end
	assert(bands == 7 and hidden > 0, model.Name .. ": all body bands hydrate")
end
print("PASS " .. #models .. " new fish hydrate through EditableMesh API doubles: "
	.. copies .. " bands, " .. vertices .. " vertices, " .. triangles .. " valid triangles")
print("Recording doubles only; Studio appearance and device memory require play testing.")
`;
const runtime = await freezerRuntime();
const hook = 'return Packing, FishModels';
if (!runtime.includes(hook)) throw new Error('Fish model runtime hook changed');
const temporaryRoot = resolve(tmpdir());
const temporary = await mkdtemp(join(temporaryRoot, 'seasonal-fish-meshes-'));
try {
  const target = join(temporary, 'check.luau');
  await writeFile(target, runtime.replace(hook, () => exercise + '\n' + hook));
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], {
    cwd: root, encoding: 'utf8', timeout: 30000,
  });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Seasonal mesh checks failed (Lute exit ${result.status})`);
} finally {
  if (dirname(resolve(temporary)) !== temporaryRoot) throw new Error('Unexpected temporary directory');
  await rm(temporary, { recursive: true, force: true });
}
