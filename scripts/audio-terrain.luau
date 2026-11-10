-- One-column voxel fixture shared by the audio checks. The real TerrainProbe
-- reads this data, so assertions exercise its material and occupancy handling.
local Region3 = { new = function(low, high) return { low = low, high = high } end }
local voxelReads = 0
local voxelFailure, terrainMissing, terrainRoof = false, false, false
function workspace.Terrain:ReadVoxels(region, resolution)
	voxelReads += 1
	assert(resolution == 4, "Audio reads the native four-stud terrain grid")
	assert(region.high.X - region.low.X == 4 and region.high.Z - region.low.Z == 4,
		"Audio terrain probes read one column at a time")
	if voxelFailure then error("Terrain temporarily unavailable") end
	local materials, occupancies = {}, {}
	for y = region.low.Y, region.high.Y - resolution, resolution do
		local material, occupancy = Enum.Material.Air, 0
		if not terrainMissing then
			if terrainRoof and y == 40 then
				material, occupancy = Enum.Material.Sand, 1
			else
				material, occupancy = materialAt(region.low.X, y, region.low.Z)
			end
		end
		table.insert(materials, { material })
		table.insert(occupancies, { occupancy })
	end
	return { materials }, { occupancies }
end

dependencies.TerrainProbe = (function()
	-- TERRAIN_PROBE --
end)()
