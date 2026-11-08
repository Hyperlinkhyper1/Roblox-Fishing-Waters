-- The ocean-floor carpet: one small seabed patch per grid cell (48 studs at sea,
-- 24 in the harbour lake). It used to be cloned on the server: ~60k copies and
-- ~700k parts, which took live servers past 6.5 GB and crashed them. Now the
-- server only publishes the patch templates (ReplicatedStorage.SeabedCarpet) and
-- each client builds the cells around its own camera (client/SeabedCarpet).
-- Everything here is deterministic, so every client sees the same floor.
local Biomes = require(script.Parent.Biomes)

local SeabedCarpet = {}
SeabedCarpet.FOLDER = "SeabedCarpet"
SeabedCarpet.CELL = 48
SeabedCarpet.LAKE_CELL = 24
SeabedCarpet.TEMPLATES = 24
-- Style folders, in the order the server builds them.
SeabedCarpet.STYLES = { "normal", "swamp", "tropical", "volcanic", "ice", "open" }

local TAU = math.pi * 2

export type Grid = { id: number, cell: number, min: number, max: number, lake: boolean }

-- The lake grid covers the harbour island's square, the ocean grid the whole map.
function SeabedCarpet.grids(): { Grid }
	return {
		{
			id = 1,
			cell = SeabedCarpet.LAKE_CELL,
			min = -Biomes.Normal.radius,
			max = Biomes.Normal.radius,
			lake = true,
		},
		{ id = 2, cell = SeabedCarpet.CELL, min = Biomes.OceanMin, max = Biomes.OceanMax, lake = false },
	}
end

function SeabedCarpet.encode(points: { Vector2 }): string
	local parts = table.create(#points)
	for index, point in points do
		parts[index] = string.format("%.1f,%.1f", point.X, point.Y)
	end
	return table.concat(parts, ";")
end

function SeabedCarpet.decode(text: string?): { Vector2 }
	local points = {}
	for x, z in string.gmatch(text or "", "(-?[%d%.]+),(-?[%d%.]+)") do
		table.insert(points, Vector2.new(tonumber(x) :: number, tonumber(z) :: number))
	end
	return points
end

-- Point-in-polygon test for the lake outline (X/Z as Vector2 X/Y).
function SeabedCarpet.lakeTest(outline: { Vector2 }): (Vector3) -> boolean
	if #outline < 3 then
		return function()
			return false
		end
	end
	local low, high = outline[1], outline[1]
	for _, point in outline do
		low, high = low:Min(point), high:Max(point)
	end
	return function(position: Vector3): boolean
		if position.X < low.X or position.X > high.X or position.Z < low.Y or position.Z > high.Y then
			return false
		end
		local inside = false
		local previous = outline[#outline]
		for _, point in outline do
			if
				(point.Y > position.Z) ~= (previous.Y > position.Z)
				and position.X < (previous.X - point.X) * (position.Z - point.Y) / (previous.Y - point.Y) + point.X
			then
				inside = not inside
			end
			previous = point
		end
		return inside
	end
end

function SeabedCarpet.key(grid: Grid, cx: number, cz: number): number
	return (grid.id * 1000 + cx + 500) * 1000 + cz + 500
end

-- Cells already holding a full garden (the server still builds those) stay bare.
function SeabedCarpet.occupied(grid: Grid, gardens: { Vector2 }): { [number]: boolean }
	local taken = {}
	for _, position in gardens do
		taken[SeabedCarpet.key(grid, math.floor(position.X / grid.cell), math.floor(position.Y / grid.cell))] = true
	end
	return taken
end

-- Cell indices within `radius` studs (on X/Z) of a point, clamped to the grid.
function SeabedCarpet.range(grid: Grid, x: number, z: number, radius: number): (number, number, number, number)
	local cell = grid.cell
	local first, last = math.floor(grid.min / cell), math.floor((grid.max - 1) / cell)
	return math.max(first, math.floor((x - radius) / cell)),
		math.min(last, math.floor((x + radius) / cell)),
		math.max(first, math.floor((z - radius) / cell)),
		math.min(last, math.floor((z + radius) / cell))
end

function SeabedCarpet.style(position: Vector3): string
	local biome = Biomes.at(position)
	return if biome == Biomes.OpenSea then "open" else biome.id
end

export type Sample = (x: number, z: number) -> (RaycastResult?, boolean)

-- Where the cell's patch goes. `sample(x, z)` returns the ground hit, or nil and
-- whether trying again later might succeed (ground not streamed in yet). Returns
-- the hit and the cell's Random (for the patch choice, scale and turn), or nil and
-- whether to retry.
function SeabedCarpet.plan(
	grid: Grid,
	cx: number,
	cz: number,
	seed: number,
	inLake: (Vector3) -> boolean,
	sample: Sample
): (RaycastResult?, Random?, boolean)
	local cell = grid.cell
	local rng = Random.new(seed + grid.id * 7919 + cx * 100003 + cz * 17)
	local x, z = cx * cell, cz * cell
	local retry = false
	for _ = 1, 3 do
		-- Bounded jitter leaves room between neighbouring copies.
		local px = math.clamp(x + cell * rng:NextNumber(0.25, 0.75), grid.min + 1, grid.max - 1)
		local pz = math.clamp(z + cell * rng:NextNumber(0.25, 0.75), grid.min + 1, grid.max - 1)
		local position = Vector3.new(px, Biomes.WaterLevel - 1, pz)
		if not Biomes.inOceanBounds(position) or inLake(position) ~= grid.lake then
			continue
		end
		local hit, again = sample(px, pz)
		if hit then
			return hit, rng, false
		end
		retry = retry or again
	end
	return nil, nil, retry
end

-- The patch's frame on the sampled ground: tilted onto the slope, turned at random.
function SeabedCarpet.frame(hit: RaycastResult, rng: Random): (CFrame, number, number)
	local normal = hit.Normal
	local right = normal:Cross(Vector3.zAxis).Unit
	local frame = CFrame.fromMatrix(hit.Position, right, normal, right:Cross(normal))
	local template = rng:NextInteger(1, SeabedCarpet.TEMPLATES)
	local scale = rng:NextNumber(0.9, 1.25)
	return frame * CFrame.Angles(0, rng:NextNumber(0, TAU), 0), template, scale
end

return SeabedCarpet
