// Build every catalog species with the existing geometry doubles. No Studio rendering claims.
import { writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { freezerRuntime } from './freezer-test-runtime.mjs';
import { fishSpeciesSource } from './fish-species.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const temporaryRoot = resolve(tmpdir());
const temporary = await mkdtemp(join(temporaryRoot, 'fish-models-'));
try {
  const program = await freezerRuntime() + `
local species = ${fishSpeciesSource(root)}
local count = 0
for id in species do
	assert(freezerTestModels.has(id), id .. ": catalog species needs a model builder")
	local model = assert(freezerTestModels.create(id), id .. ": builder must return a model")
	local bounds = model:GetAttribute("BoundsSize")
	assert(bounds and bounds.X > 0 and bounds.X < math.huge
		and bounds.Y > 0 and bounds.Y < math.huge
		and bounds.Z > 0 and bounds.Z < math.huge, id .. ": model needs finite, positive bounds")
	local visible = false
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			local mesh = part:FindFirstChildOfClass("SpecialMesh")
			-- The geometry doubles omit SpecialMesh's engine default Scale of (1, 1, 1).
			assert(not mesh or mesh.Scale == nil or mesh.Scale.Magnitude > 0,
				id .. ": original geometry must remain visible without EditableMesh")
			visible = true
		end
	end
	assert(visible, id .. ": catch must contain visible geometry without EditableMesh")
	model:Destroy()
	count += 1
end
print("PASS all " .. count .. " catalog species build visible models without EditableMesh")
print("Geometry doubles only; actual rendering requires Studio play testing.")
`;
  const target = join(temporary, 'fish-models.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], {
    cwd: root, encoding: 'utf8', timeout: 30000,
  });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Fish model checks failed (Lute exit ${result.status})`);
} finally {
  if (dirname(resolve(temporary)) !== temporaryRoot) throw new Error('Unexpected temporary directory');
  await rm(temporary, { recursive: true, force: true });
}
