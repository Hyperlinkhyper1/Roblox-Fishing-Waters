local Biomes, Details = dependencies.Biomes, dependencies.SeabedDetails
local checks = 0
local function check(condition, message)
	checks += 1
	assert(condition, message)
end

local rays, yields = 0, 0
local forcedHit = nil
local incline = Vector3.new(0.3, math.sqrt(0.91), 0)
function workspace:Raycast(origin, direction, params)
	rays += 1
	check(params.IgnoreWater, 'Scenery rays must ignore water')
	check(origin.Y >= 600 and direction.Y < -600, 'Sample from above islands, not from inside land')
	if forcedHit then return forcedHit end
	local y = if origin.X > 6500 and origin.X < 7100 and origin.Z > 6500 and origin.Z < 7100 then 12
		elseif origin.X > 500 and origin.X < 700 and math.abs(origin.Z) < 200 then -30
		else Biomes.SeaFloor
	return {
		Position = Vector3.new(origin.X, y, origin.Z),
		Normal = if y == -30 then incline else Vector3.yAxis,
	}
end
function workspace.Terrain:SetMaterialColor() end
local sandTiles = {}
function workspace.Terrain:FillBlock(frame, size, material)
	table.insert(sandTiles, { frame = frame, size = size, material = material })
end
function workspace.Terrain:IsA(class) return class == 'Terrain' end

local params = RaycastParams.new()
params.IgnoreWater = true
for _, rejected in {
	{ Position = Vector3.new(0, 3, 0), Normal = Vector3.yAxis },
	{ Position = Vector3.new(0, -5, 0), Normal = Vector3.yAxis },
	{ Position = Vector3.new(0, -20, 0), Normal = Vector3.new(0.8, 0.6, 0) },
	{ Position = Vector3.new(-6000, -64, -6000), Normal = Vector3.yAxis },
	{ Position = Vector3.new(6750, -20, 6950), Normal = Vector3.yAxis },
} do
	forcedHit = rejected
	check(Details.sample(params, rejected.Position.X, rejected.Position.Z) == nil,
		'Land, shallow water, cliffs, outside-ocean positions and dry rooms must remain clear')
end
forcedHit = { Position = Vector3.new(600, -30, 0), Normal = incline }
check(Details.sample(params, 600, 0) == forcedHit, 'Gentle underwater slopes must accept scenery')
forcedHit = nil

local copies, templates, sinceYield, maxBatch = {}, {}, 0, 0
-- Retain template geometry and record its clones without expanding hundreds of
-- thousands of mock parts. Placement and scale remain the real generator's calls.
function instanceMethods:Clone()
	if not templates[self] then
		local parts = 0
		for _, part in self:GetDescendants() do
			if part:IsA('BasePart') then
				parts += 1
				check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery and not part.CastShadow,
					'Every cloned scenery part must be static, non-interactive and shadow-free')
			end
		end
		check(parts > 0, 'Templates must contain visible geometry')
		check(self.ModelStreamingMode == Enum.ModelStreamingMode.Atomic, 'Templates must stream independently')
		templates[self] = parts
	end
	local copy = Instance.new('Model')
	copy.Name = self.Name
	copy.ModelStreamingMode = self.ModelStreamingMode
	copy._props.RecordedCopy = true
	table.insert(copies, copy)
	sinceYield += 1
	maxBatch = math.max(maxBatch, sinceYield)
	return copy
end
local originalScale, originalPivot = instanceMethods.ScaleTo, instanceMethods.PivotTo
function instanceMethods:ScaleTo(scale)
	if self.RecordedCopy then self._props.ModelScale = scale else originalScale(self, scale) end
end
function instanceMethods:PivotTo(target)
	if self.RecordedCopy then self._props.PlacedFrame = target else originalPivot(self, target) end
end
function task.wait()
	yields += 1
	sinceYield = 0
end

local root = Instance.new('Folder')
local old = Instance.new('Folder')
old.Name = 'SeabedDetails'
old:SetAttribute('Version', 4)
old.Parent = root
local retained = Instance.new('Model')
retained.Name = 'PlayerFurniture'
retained.Parent = root
Details.ensure(root)
local details = root:FindFirstChild('SeabedDetails')
check(details and details ~= old and old.Parent == nil, 'Older baked scenery must be replaced')
check(retained.Parent == root, 'Refreshing scenery must preserve unrelated map contents')
check(details:GetAttribute('Version') > 4, 'Baked maps must save the new scenery version')

local sandArea = 0
for _, tile in sandTiles do
	check(tile.material == Enum.Material.Sand, 'The full deep floor must use sand')
	check(tile.frame.Position.Y + tile.size.Y / 2 == Biomes.SeaFloor and tile.size.Y == 8,
		'Sand must preserve ocean depth and stay below raised biome shelves')
	check(tile.size.X <= 1024 and tile.size.Z <= 1024, 'Terrain repairs must use bounded tiles')
	sandArea += tile.size.X * tile.size.Z
end
local half, edge, start = Biomes.MapHalfSize, Biomes.OceanMax, Biomes.CityOceanStart
check(sandArea == (half * 2)^2 + (edge - half) * (edge - start) + (half - start) * (edge - half),
	'Sand must cover the original ocean and city extension exactly once')
for _, point in {
	Vector2.new(-5199, -5199), Vector2.new(5000, -5000), Vector2.new(3000, 3000),
	Vector2.new(8199, 8199), Vector2.new(4300, 6000), Vector2.new(6000, 4300),
	Vector2.new(-6000, 6000), Vector2.new(6000, -6000),
} do
	local covered = 0
	for _, tile in sandTiles do
		local p, size = tile.frame.Position, tile.size
		if point.X >= p.X - size.X / 2 and point.X < p.X + size.X / 2
			and point.Y >= p.Z - size.Z / 2 and point.Y < p.Z + size.Z / 2 then
			covered += 1
		end
	end
	check(covered == (if Biomes.inOceanBounds(Vector3.new(point.X, -64, point.Y)) then 1 else 0),
		'Sand must reach distant ocean edges without filling the empty outer corners')
end

local remoteGardens = 0
for _, object in details:GetDescendants() do
	if object:IsA('Model') and object.Name == 'SeabedGarden' then
		for _, part in object:GetDescendants() do
			if part:IsA('BasePart') then
				if part.Position.X > half or part.Position.Z > half then remoteGardens += 1 end
				break
			end
		end
	end
end
check(remoteGardens > 20, 'Full gardens, including coral and sand drifts, must reach the city approaches')

local oceanCount, lakeCount, cityCount, slopedCount = 0, 0, 0, 0
local cells = {}
for _, copy in copies do
	local frame = copy.PlacedFrame
	local point = frame.Position
	check(Biomes.inOceanBounds(point) and point.Y < Biomes.WaterLevel - 8, 'All floor copies must sit on underwater ground')
	check(copy.ModelScale >= 0.9 and copy.ModelScale <= 1.25, 'Copied patches must retain a modest scale')
	local lake = copy.Parent.Name == 'LakeFloor'
	local cell = if lake then 24 else 48
	local key = tostring(lake) .. ':' .. math.floor(point.X / cell) .. ',' .. math.floor(point.Z / cell)
	check(not cells[key], 'Each grid cell must contain at most one filler patch')
	cells[key] = true
	if lake then lakeCount += 1 else oceanCount += 1 end
	if point.X > Biomes.MapHalfSize or point.Z > Biomes.MapHalfSize then cityCount += 1 end
	if point.Y == -30 then
		slopedCount += 1
		check((frame.UpVector - incline).Magnitude < 0.00001, 'Copies must tilt onto the sampled slope')
	end
end
check(oceanCount > 45000, 'Denser scenery must cover the whole ocean')
check(lakeCount > 700, 'The whole lake bottom needs its own denser coverage')
check(cityCount > 5000, 'Scenery must reach the southeast city approaches')
check(slopedCount > 0, 'Scenery must follow underwater island slopes')
check(maxBatch <= 40 and yields > 1000, 'Generation must yield between small batches of clones')
local beforeRays, beforeCopies, beforeTiles = rays, #copies, #sandTiles
Details.ensure(root)
check(rays == beforeRays and #copies == beforeCopies and #sandTiles == beforeTiles,
	'Refreshing current scenery and sand must be idempotent')
print(`Seabed scenery: {checks} checks passed; {oceanCount} ocean, {lakeCount} lake, {cityCount} city-approach copies`)
