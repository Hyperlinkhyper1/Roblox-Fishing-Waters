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

return TerrainProbe
