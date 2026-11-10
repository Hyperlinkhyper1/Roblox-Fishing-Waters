-- Terrain questions answered from voxels instead of raycasts.
--
-- A raycast that touches a terrain chunk this client has never queried makes the engine
-- build that chunk's collision shape first (RaycastTerrain > generateShape > buildKDTree in
-- the MicroProfiler): tens of milliseconds in one frame, and render loops probing new water
-- around a moving camera hit fresh chunks constantly. ReadVoxels reads the streamed voxel
-- grid directly and never builds collision, so per-frame probes go through here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Biomes = require(ReplicatedStorage.Shared.Biomes)

local TerrainProbe = {}

local RESOLUTION = 4
local terrain = workspace.Terrain
local AIR, WATER = Enum.Material.Air, Enum.Material.Water

local function cell(value: number): number
	return math.floor(value / RESOLUTION) * RESOLUTION
end

-- One voxel column at (x, z) from y `low` up to `high`, top-down: (materials, occupancies,
-- top of the column) or nil when the read fails.
local function column(x: number, z: number, low: number, high: number)
	local x0, z0 = cell(x), cell(z)
	local y0, y1 = cell(low), cell(high) + RESOLUTION
	local ok, materials, occupancies = pcall(function()
		return terrain:ReadVoxels(
			Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x0 + RESOLUTION, y1, z0 + RESOLUTION)),
			RESOLUTION
		)
	end)
	if not ok or not materials then
		return nil
	end
	return materials[1], occupancies[1], y1
end

-- Approximate the top terrain surface in a vertical range, to four-stud voxel
-- precision. Audio only needs water/land and roof presence; casting rays for
-- those estimates builds collision for fresh chunks as the listener travels.
-- Missing streamed terrain (air) and failed reads both return nil.
function TerrainProbe.surfaceAt(
	x: number, z: number, low: number, high: number, ignoreWater: boolean?
): (Enum.Material?, number?)
	local materials, occupancies, top = column(x, z, low, high)
	if not materials then
		return nil, nil
	end
	for index = #materials, 1, -1 do
		local material = materials[index][1]
		if material ~= AIR and not (ignoreWater and material == WATER) then
			local base = top - (#materials - index + 1) * RESOLUTION
			local height = base + RESOLUTION * occupancies[index][1]
			if height >= low then
				return material, math.min(height, high)
			end
		end
	end
	return nil, nil
end

-- True when the voxel just under the calm surface at (x, z) is water.
function TerrainProbe.isWater(x: number, z: number): boolean
	local y = Biomes.WaterLevel - RESOLUTION / 2
	local materials = column(x, z, y, y)
	return materials ~= nil and materials[1][1] == WATER
end

-- Height of the first solid voxel below the surface at (x, z), scanning down to `bottom`.
-- Returns nil when the surface itself isn't water (dry land, outside the streamed area).
function TerrainProbe.floorBelow(x: number, z: number, bottom: number): number?
	local surface = Biomes.WaterLevel - RESOLUTION / 2
	local materials, occupancies, top = column(x, z, bottom, surface)
	if not materials then
		return nil
	end
	local cells = materials[1] and #materials or 0
	if cells == 0 then
		return nil
	end
	-- Index 1 is the bottom cell; walk from the top down.
	if materials[cells][1] ~= WATER then
		return nil
	end
	for index = cells - 1, 1, -1 do
		local material = materials[index][1]
		if material ~= WATER and material ~= AIR then
			-- Occupancy approximates how far the smooth surface rises within the cell.
			local base = top - (cells - index + 1) * RESOLUTION
			return base + RESOLUTION * occupancies[index][1]
		end
	end
	return bottom
end

-- The seabed under (x, z) from one 3x3-column voxel read: (floor height, surface normal from
-- the neighbouring columns, surface) where surface is "water" (floor found or scanned down to
-- `bottom`), "land" (solid terrain at the waterline) or "unknown" (air there: not streamed in).
-- The floor is nil unless the surface is water and solid ground lies above `bottom`.
function TerrainProbe.seabed(x: number, z: number, bottom: number): (number?, Vector3?, string)
	local surface = Biomes.WaterLevel - RESOLUTION / 2
	local x0, z0 = cell(x) - RESOLUTION, cell(z) - RESOLUTION
	local y0, y1 = cell(bottom), cell(surface) + RESOLUTION
	local ok, materials, occupancies = pcall(function()
		return terrain:ReadVoxels(
			Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x0 + 3 * RESOLUTION, y1, z0 + 3 * RESOLUTION)),
			RESOLUTION
		)
	end)
	if not ok or not materials or not materials[2] or not materials[2][1] then
		return nil, nil, "unknown"
	end
	local cells = #materials[2]
	local top = materials[2][cells][2]
	if top == AIR then
		return nil, nil, "unknown"
	elseif top ~= WATER then
		return nil, nil, "land"
	end
	local function floorAt(ix: number, iz: number): number?
		local column = materials[ix]
		if not column then
			return nil
		end
		for index = cells - 1, 1, -1 do
			local material = column[index][iz]
			if material ~= WATER and material ~= AIR then
				return y1 - (cells - index + 1) * RESOLUTION + RESOLUTION * occupancies[ix][index][iz]
			end
		end
		return nil
	end
	local floor = floorAt(2, 2)
	if not floor then
		return nil, nil, "water"
	end
	local left, right = floorAt(1, 2) or floor, floorAt(3, 2) or floor
	local back, front = floorAt(2, 1) or floor, floorAt(2, 3) or floor
	-- Heights 2 cells apart: normal ∝ (-dh/dx, 1, -dh/dz)
	local normal = Vector3.new(left - right, 2 * RESOLUTION, back - front).Unit
	return floor, normal, "water"
end

return TerrainProbe
