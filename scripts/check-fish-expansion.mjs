// The requested expansion must be catchable under real condition combinations
// and expose valid geometry to the existing EditableMesh skin pipeline.
// Geometry doubles cannot establish how Roblox Studio actually renders a fish.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { freezerRuntime } from './freezer-test-runtime.mjs';
import { fishSpeciesSource } from './fish-species.mjs';
import { seasonalFishIds } from './seasonal-fish.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = async (file) => (await readFile(join(root, file), 'utf8')).replace(/\r\n/g, '\n');
const seasonal = process.argv.includes('--seasonal');
const ids = seasonal ? seasonalFishIds : [
  'AtlanticSailfish', 'BlackMarlin', 'BlueMarlin', 'BroadbillSwordfish',
  'LongbillSpearfish', 'StripedMarlin', 'WhiteMarlin', 'BlackGrouper',
  'BlackSeabass', 'CalicoGrouper', 'BroomtailGrouper', 'GiantSeabass',
  'GulfConey', 'Graysby', 'NassauGrouper', 'RedHindGrouper', 'Tripletail',
  'TigerGrouper', 'YellowfinGrouper', 'AlabamaBass', 'YellowBass',
  'PeacockBass', 'RedeyeBass', 'LargemouthBass', 'BlueCatfish',
  'BlackBullhead', 'BrownBullhead', 'GafftopsailCatfish', 'YellowBullhead',
  'WhiteCatfish', 'AuroraRockfish', 'BlackRockfish', 'BlackgillRockfish',
  'Bocaccio', 'CanaryRockfish', 'Cowcod', 'Chilipepper', 'Treefish',
  'YelloweyeRockfish', 'AtlanticSalmon', 'ChinookSalmon', 'CohoSalmon',
  'SockeyeSalmon', 'PinkSalmon',
];

// Share a single species registry between model builders and the catalog. This
// also keeps large expansions inside Luau's compiled register/local limits.
const speciesSource = fishSpeciesSource(root);
const catalogSource = (await read('src/shared/AnglerCatalog.luau'))
  .replace('require(script.Parent.FishSpecies)', 'species');
let runtime = await freezerRuntime();
for (const hook of [
  `local FishSpecies = ${speciesSource}`,
  'local FishMutations = (function()',
  'return Packing, FishModels',
]) {
  if (!runtime.includes(hook)) throw new Error(`Fish expansion harness hook changed: ${hook.slice(0, 70)}`);
}
runtime = runtime
  .replace(`local FishSpecies = ${speciesSource}`, 'local FishSpecies = species')
  .replace('local FishMutations = (function()', `local species = ${speciesSource}\nlocal FishMutations = (function()`)
  .replace('local freezerTestPacking, freezerTestModels =', 'local freezerTestPacking, freezerTestModels, species, Catalog =')
  .replace('return Packing, FishModels', `local Catalog = (function()\n${catalogSource}\nend)()\nreturn Packing, FishModels, species, Catalog`);

const program = runtime + `
local FishCatch = (function()
${await read('src/shared/FishCatch.luau')}
end)()
local Cargo = (function()
${await read('src/shared/Cargo.luau')}
end)()
local requested = { ${ids.map((id) => JSON.stringify(id)).join(', ')} }
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function vector(value)
	return value and finite(value.X) and finite(value.Y) and finite(value.Z)
end
local seasons = { "Spring", "Summer", "Autumn", "Winter" }
local conditionKeys = { Rain = true, Clear = true, Storm = true, Supercell = true,
	BlackHole = true, Day = true, Night = true, Beach = true }

check(#requested == ${seasonal ? 50 : 44}, "The expansion has the expected species count")
local seen, reachable = {}, {}
for _, id in requested do
	check(not seen[id], id .. ": requested exactly once")
	seen[id] = true
	local entry = assert(species[id], id .. ": species module exists")
	local fish = assert(Catalog.Fish[id], id .. ": catalog registration exists")
	check(type(entry.Build) == "function" and freezerTestModels.has(id), id .. ": model builder registered")
	check(finite(fish.MinKg) and finite(fish.AverageKg) and finite(fish.MaxKg)
		and fish.MinKg > 0 and fish.MinKg < fish.AverageKg and fish.AverageKg < fish.MaxKg,
		id .. ": ordered positive weight range")
	check(finite(fish.RarityDenominator) and fish.RarityDenominator >= 1
		and Catalog.Rarities[fish.Rarity] ~= nil and finite(fish.BaseValue) and fish.BaseValue > 0,
		id .. ": valid encounter odds, rarity and value")
	check(entry.Pools and #entry.Pools > 0 and not entry.DropOnly, id .. ": catchable pool assignment")
	if ${seasonal} then
		check(type(entry.ScientificName) == "string" and string.match(entry.ScientificName, "^%u%l+ %l+$") ~= nil
			and fish.ScientificName == entry.ScientificName, id .. ": scientific identity is preserved in catalog")
		check(not table.find(entry.Pools, "OpenSea"), id .. ": habitat is regional, without global inheritance")
		check(#entry.Seasons < 4, id .. ": unavailable for at least one season")
	end
	reachable[id] = {}
	local ownPools = {}
	for _, poolId in entry.Pools do
		check(not ownPools[poolId] and Catalog.Pools[poolId] ~= nil, id .. ": unique valid pool " .. poolId)
		ownPools[poolId] = true
		check(table.find(Catalog.Pools[poolId].Own, id) ~= nil, id .. ": added to assigned pool " .. poolId)
	end
	local previous, present = 0, {}
	check(entry.Seasons and #entry.Seasons > 0, id .. ": explicit season assignment")
	for _, season in entry.Seasons do
		local index = table.find(seasons, season)
		check(index and index > previous, id .. ": unique seasons in calendar order")
		previous, present[season] = index, true
	end
	local starts = 0
	for index, season in seasons do
		if present[season] and not present[seasons[(index - 2) % 4 + 1]] then starts += 1 end
	end
	check(starts <= 1, id .. ": seasons form one contiguous annual run for bestiary labels")
	local requirements = {}
	for _, key in fish.Requires or {} do
		check(conditionKeys[key] and not requirements[key], id .. ": unique supported condition " .. key)
		requirements[key] = true
	end
	check(not (requirements.Day and requirements.Night), id .. ": day and night requirements are compatible")

	local lastArea = 0
	for _, size in { "Normal", "Big", "Huge" } do
		local rows = assert(entry.Shapes[size], id .. ": cargo footprint exists for " .. size)
		check(#rows > 0 and #rows[1] > 0, id .. ": nonempty footprint")
		for _, row in rows do
			check(#row == #rows[1] and string.match(row, "^[.#]+$") ~= nil, id .. ": rectangular valid cargo rows")
		end
		local cells = Cargo.cells(Cargo.shape({ FishId = id, Size = size }, Catalog.Fish))
		check(#cells > 0 and #cells >= lastArea, id .. ": cargo area grows with size")
		lastArea = #cells
		local occupied, visited = {}, {}
		for _, cell in cells do occupied[cell[1] .. ":" .. cell[2]] = true end
		local queue = { cells[1] }
		visited[cells[1][1] .. ":" .. cells[1][2]] = true
		local cursor = 1
		while cursor <= #queue do
			local cell = queue[cursor]
			cursor += 1
			for _, delta in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				local x, y = cell[1] + delta[1], cell[2] + delta[2]
				local key = x .. ":" .. y
				if occupied[key] and not visited[key] then
					visited[key] = true
					table.insert(queue, { x, y })
				end
			end
		end
		check(#queue == #cells, id .. ": cargo footprint is connected")
		for rotation = 0, 3 do
			check(#Cargo.cells(rows, rotation) == #cells, id .. ": cargo rotations preserve area")
		end
		local sizeRoll = if size == "Huge" then 0.001 elseif size == "Big" then 0.03 else 0.5
		for _, sample in { 0, 0.5, 0.999999 } do
			local calls = 0
			local kg, actualSize = FishCatch.rollWeight(fish, function()
				calls += 1
				return if calls == 1 then sizeRoll else sample
			end)
			check(actualSize == size and finite(kg) and kg >= fish.MinKg and kg <= fish.MaxKg,
				id .. ": " .. size .. " weight roll remains within species bounds")
			local value = FishCatch.value(fish, kg, actualSize)
			local difficulty = FishCatch.difficulty(fish, Catalog.Rarities, kg / fish.AverageKg)
			check(finite(value) and value >= 1 and value % 1 == 0 and finite(difficulty)
				and difficulty >= 0.05 and difficulty <= 1, id .. ": valid sell value and fight difficulty")
		end
	end

	local model = assert(freezerTestModels.create(id), id .. ": model builds")
	check(model:GetAttribute("LoftFish") == id, id .. ": smooth mesh species metadata")
	local loft = assert(freezerTestModels.loft(id), id .. ": smooth EditableMesh profile exists")
	check(vector(loft.anchorPosition) and vector(loft.anchorSize)
		and loft.anchorSize.X > 0 and loft.anchorSize.Y > 0 and loft.anchorSize.Z > 0,
		id .. ": finite skin anchor")
	local bounds = model:GetAttribute("BoundsSize")
	check(vector(bounds) and bounds.X > 0 and bounds.Y > 0 and bounds.Z > 0, id .. ": finite positive model bounds")
	local fallbacks, swatches = 0, {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			check(vector(part.Size) and vector(part.Position) and part.Size.X > 0
				and part.Size.Y > 0 and part.Size.Z > 0, id .. ": finite positive part geometry")
			if part:GetAttribute("LoftFallback") then fallbacks += 1 end
			local swatch = part:GetAttribute("LoftSwatch")
			if swatch then swatches[swatch] = true end
		end
	end
	check(fallbacks > 0 and swatches.Back and swatches.Side and swatches.Belly, id .. ": fallback and mutation swatches")
	check(#loft.rings >= 2, id .. ": skin has multiple cross-sections")
	local previousX = math.huge
	for _, ring in loft.rings do
		check(finite(ring.x) and ring.x < previousX and finite(ring.top) and finite(ring.bottom)
			and ring.top > ring.bottom and finite(ring.width) and ring.width > 0,
			id .. ": ordered nondegenerate skin cross-sections")
		previousX = ring.x
		for step = 0, 7 do
			local angle = step * math.pi / 4
			local point = freezerTestModels.loftPoint(ring, angle)
			local normal = freezerTestModels.loftNormal(loft.rings, ring.x, angle)
			check(vector(point) and vector(normal) and math.abs(normal.Magnitude - 1) < 0.0001,
				id .. ": finite skin vertices and unit normals")
		end
	end
	model:Destroy()
end

-- These combinations match CatchConditions.at: a supercell also counts as a
-- storm, while Black Hole weather is rainy. Day and night are exclusive.
local weather = {
	{ name = "Clear", Clear = true },
	{ name = "Rain", Rain = true },
	{ name = "Storm", Rain = true, Storm = true },
	{ name = "Supercell", Rain = true, Storm = true, Supercell = true },
	{ name = "BlackHole", Rain = true, BlackHole = true },
}
local combinations = 0
for poolId, pool in Catalog.Pools do
	check(Catalog.poolAt(pool.Area) == pool, poolId .. ": world area resolves to catch pool")
	for _, season in seasons do
		for _, state in weather do
			for _, night in { false, true } do
				for _, beach in { false, true } do
					local conditions = table.clone(state)
					conditions.Day, conditions.Night, conditions.Beach = not night, night, beach
					local filtered = FishCatch.inSeason(pool, Catalog.Fish, season, conditions)
					combinations += 1
					for _, id in requested do
						local fish = Catalog.Fish[id]
						local allowed = table.find(pool.Fish, id) ~= nil and table.find(fish.Seasons, season) ~= nil
						local weatherRequired, weatherSatisfied = false, false
						for _, key in fish.Requires or {} do
							if FishCatch.WEATHER[key] then
								weatherRequired = true
								if conditions[key] then weatherSatisfied = true end
							elseif not conditions[key] then allowed = false end
						end
						allowed = allowed and (not weatherRequired or weatherSatisfied)
						check((table.find(filtered.Fish, id) ~= nil) == allowed,
							id .. ": correct inclusion/exclusion in " .. poolId .. "/" .. season .. "/" .. state.name
							.. (if night then "/night" else "/day") .. (if beach then "/beach" else "/offshore"))
						if allowed then reachable[id][poolId] = true end
					end
				end
			end
		end
	end
end
for _, id in requested do
	for _, poolId in species[id].Pools do
		check(reachable[id][poolId], id .. ": physically reachable in assigned pool " .. poolId)
	end
	if Catalog.Fish[id].Requires then
		local pool = Catalog.Pools[species[id].Pools[1]]
		local filtered = FishCatch.inSeason(pool, Catalog.Fish, species[id].Seasons[1], nil)
		check(not table.find(filtered.Fish, id), id .. ": required conditions cannot be omitted")
	end
end
print("PASS fish expansion: " .. #requested .. " requested species; " .. combinations
	.. " physical spawn combinations; " .. checks .. " geometry, condition, weight and cargo checks")
print("Geometry doubles only; actual EditableMesh rendering requires Studio play testing.")
`;

const temporaryRoot = resolve(tmpdir());
const temporary = await mkdtemp(join(temporaryRoot, 'fish-expansion-'));
try {
  const target = join(temporary, 'check.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], {
    cwd: root, encoding: 'utf8', timeout: 30000,
  });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Fish expansion checks failed (Lute exit ${result.status})`);
} finally {
  if (dirname(resolve(temporary)) !== temporaryRoot) throw new Error('Unexpected temporary directory');
  await rm(temporary, { recursive: true, force: true });
}
