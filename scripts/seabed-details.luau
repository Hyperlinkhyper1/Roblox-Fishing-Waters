local Biomes, Details = dependencies.Biomes, dependencies.SeabedDetails
local Carpet, CarpetClient = dependencies.SeabedCarpet, dependencies.SeabedCarpetClient
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

-- The floor carpet is no longer cloned on the server (~700k parts crashed live servers):
-- only its templates are published, and each client builds the cells near its camera.
check(#copies == 0, 'The server must not clone the floor carpet')
local published = replicatedStorage:FindFirstChild(Carpet.FOLDER)
check(published ~= nil, 'Carpet templates must be published in ReplicatedStorage')
check(published:GetAttribute('Version') == details:GetAttribute('Version'), 'Published carpet carries the scenery version')
check(type(published:GetAttribute('Seed')) == 'number', 'Published carpet carries its seed')
local templateParts = 0
for _, id in Carpet.STYLES do
	local folder = published:FindFirstChild(id)
	check(folder ~= nil, 'Every style publishes templates: ' .. id)
	for index = 1, Carpet.TEMPLATES do
		local template = folder:FindFirstChild(tostring(index))
		check(template ~= nil and template:IsA('Model'), 'Templates are numbered models')
		local parts = 0
		for _, part in template:GetDescendants() do
			if part:IsA('BasePart') then
				parts += 1
				check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery and not part.CastShadow,
					'Every carpet part must be static, non-interactive and shadow-free')
			end
		end
		check(parts > 0, 'Templates must contain visible geometry')
		templateParts += parts
	end
end
check(templateParts < 4000, 'Published templates stay small: ' .. templateParts)
local lakeOutline = Carpet.decode(published:FindFirstChild('Lake').Value)
local gardenPoints = Carpet.decode(published:FindFirstChild('Gardens').Value)
check(#lakeOutline >= 3, 'The lake outline is published')
check(#gardenPoints > 500, 'Garden cells are published so the carpet leaves them bare')
local encoded = Carpet.decode(Carpet.encode({ Vector2.new(-12.25, 40), Vector2.new(7, -3.5) }))
check(#encoded == 2 and math.abs(encoded[1].X + 12.25) < 0.06 and encoded[2].Y == -3.5, 'Point lists round-trip')

-- Whole-ocean coverage with the shared cell rules and the production ground acceptance
local inLake = Carpet.lakeTest(lakeOutline)
local seed = published:GetAttribute('Seed')
local oceanCount, lakeCount, cityCount, slopedCount, bareCount = 0, 0, 0, 0, 0
local function serverSample(x, z)
	return Details.sample(params, x, z), false
end
for _, grid in Carpet.grids() do
	local taken = Carpet.occupied(grid, gardenPoints)
	local x0, x1, z0, z1 = Carpet.range(grid, 0, 0, 1e6)
	for cx = x0, x1 do
		for cz = z0, z1 do
			if taken[Carpet.key(grid, cx, cz)] then
				bareCount += 1
				continue
			end
			local hit, rng = Carpet.plan(grid, cx, cz, seed, inLake, serverSample)
			if hit then
				local frame, template, scale = Carpet.frame(hit, rng)
				local point = frame.Position
				check(Biomes.inOceanBounds(point) and point.Y < Biomes.WaterLevel - 8, 'All floor copies must sit on underwater ground')
				check(scale >= 0.9 and scale <= 1.25, 'Copied patches must retain a modest scale')
				check(template >= 1 and template <= Carpet.TEMPLATES, 'Patch choice stays within the templates')
				check(math.floor(point.X / grid.cell) == cx and math.floor(point.Z / grid.cell) == cz, 'A patch stays inside its own cell')
				check(published:FindFirstChild(Carpet.style(point)) ~= nil, 'Every floor style has templates')
				if grid.lake then lakeCount += 1 else oceanCount += 1 end
				if point.X > Biomes.MapHalfSize or point.Z > Biomes.MapHalfSize then cityCount += 1 end
				if point.Y == -30 then
					slopedCount += 1
					check((frame.UpVector - incline).Magnitude < 0.00001, 'Copies must tilt onto the sampled slope')
				end
			end
		end
	end
end
check(oceanCount > 45000, 'Denser scenery must cover the whole ocean')
check(lakeCount > 700, 'The whole lake bottom needs its own denser coverage')
check(cityCount > 5000, 'Scenery must reach the southeast city approaches')
check(slopedCount > 0, 'Scenery must follow underwater island slopes')
check(bareCount > 0, 'Garden cells stay bare')
local hitA, rngA = Carpet.plan(Carpet.grids()[2], 40, -12, seed, inLake, serverSample)
local hitB, rngB = Carpet.plan(Carpet.grids()[2], 40, -12, seed, inLake, serverSample)
local _, templateA, scaleA = Carpet.frame(hitA, rngA)
local _, templateB, scaleB = Carpet.frame(hitB, rngB)
check(templateA == templateB and scaleA == scaleB, 'Every client builds the same patch in a cell')

-- Client tracker: only cells near the camera exist, far ones are dropped, misses retry.
local built, destroyed = 0, 0
local function place(style, template, frame, scale)
	built += 1
	return { Destroy = function() destroyed += 1 end, frame = frame }
end
local misses = {}
local function clientSample(x, z)
	local key = math.floor(x / 48) .. ',' .. math.floor(z / 48)
	if misses[key] then
		misses[key] -= 1
		if misses[key] <= 0 then misses[key] = nil end
		return nil, true -- not streamed in yet
	end
	return Details.sample(params, x, z), false
end
local update, cells = CarpetClient.tracker({ seed = seed, lake = lakeOutline, gardens = gardenPoints }, clientSample, place)
local function boundedUpdate(position, time)
	local beforeBuilt, beforeDestroyed, beforeRays = built, destroyed, rays
	local attempts = update(position, time)
	check(attempts <= 2 and built - beforeBuilt <= 2, 'A frame must not batch more than two patch probes/clones')
	check(rays - beforeRays <= 6, 'A frame must not burst through more than two three-position cell probes')
	check(destroyed - beforeDestroyed <= 2, 'A frame must not remove more than two old patches')
end
local camera = Vector3.new(2600, 20, 2600)
misses['54,54'] = 5
local now = 0
for _ = 1, 200 do
	now += 0.2
	boundedUpdate(camera, now)
end
local live = 0
for _, entry in cells do
	if entry.model then
		live += 1
		check(math.abs(entry.x - camera.X) <= 420 and math.abs(entry.z - camera.Z) <= 420, 'Only cells near the camera are built')
	end
end
check(live > 150 and live < 260, 'The camera gets a full neighbourhood of patches: ' .. live)
local retried = cells[Carpet.key(Carpet.grids()[2], 54, 54)]
check(retried ~= nil and retried.model ~= nil, 'A cell whose ground streamed in late is built on retry')
local before = built
boundedUpdate(camera, now + 1)
check(built == before, 'A settled neighbourhood builds nothing more')
camera = Vector3.new(-2600, 20, -2600)
boundedUpdate(camera, now)
check(destroyed <= 2, 'Teleport cleanup is spread across frames instead of destroying the whole old neighbourhood')
for _ = 1, 200 do
	now += 0.2
	boundedUpdate(camera, now)
end
check(destroyed >= live, 'Cells left behind are removed')
local liveAfter = 0
for _, entry in cells do
	if entry.model then liveAfter += 1 end
end
check(liveAfter < 300, 'The client keeps only the current neighbourhood: ' .. liveAfter)

-- Sustained boating at different frame rates must fill new rows while keeping
-- departures bounded. These clocks isolate operation limits from runner speed.
local trackerData = { seed = seed, lake = lakeOutline, gardens = gardenPoints }
for _, fps in { 30, 60, 144 } do
	local placed, removed = 0, 0
	local drive, neighborhood = CarpetClient.tracker(trackerData, clientSample, function()
		placed += 1
		return { Destroy = function() removed += 1 end }
	end, function() return 0 end)
	local position = Vector3.new(2600, 20, 2600)
	for frame = 1, fps * 15 do
		-- Five seconds to fill, then travel at 100 studs/sec for ten seconds.
		position = Vector3.new(2600 + math.max(0, frame / fps - 5) * 100, 20, 2600)
		local beforePlaced, beforeRemoved = placed, removed
		check(drive(position, frame / fps) <= 2, 'Boating probes stay bounded at ' .. fps .. ' FPS')
		check(placed - beforePlaced <= 2 and removed - beforeRemoved <= 2,
			'Boating clone/removal work stays bounded at ' .. fps .. ' FPS')
	end
	local nearby, stale = 0, 0
	for _, entry in neighborhood do
		if entry.model then
			nearby += 1
			if math.abs(entry.x - position.X) > entry.keep then stale += 1 end
		end
	end
	check(nearby > 150 and nearby < 350, 'Moving boats keep a full, bounded carpet at ' .. fps .. ' FPS: ' .. nearby)
	check(stale <= 4, 'Incremental cleanup keeps up with sustained travel at ' .. fps .. ' FPS: ' .. stale)
	check(removed > 100, 'Sustained travel releases old patches at ' .. fps .. ' FPS')
end

-- A slow clone or removal can use the entire time allowance by itself. No second
-- operation follows it in that frame, even though the hard count cap allows two.
local workClock, slowCopies, slowRemovals = 0, 0, 0
local slow = CarpetClient.tracker(trackerData, clientSample, function()
	slowCopies += 1
	workClock += 0.002
	return { Destroy = function() slowRemovals += 1; workClock += 0.002 end }
end, function() return workClock end)
for frame = 1, 250 do
	local beforeCopies = slowCopies
	slow(Vector3.new(2600, 20, 2600), frame / 60)
	check(slowCopies - beforeCopies <= 1, 'An expensive clone ends this frame\'s carpet work')
end
check(slowCopies > 150, 'A constrained device still fills its neighbourhood over time')
local beforeSlowCopies, beforeSlowRemovals = slowCopies, slowRemovals
slow(Vector3.new(-2600, 20, -2600), 5)
check(slowRemovals - beforeSlowRemovals == 1 and slowCopies == beforeSlowCopies,
	'An expensive teleport removal ends the frame before any clone work')

local beforeRays, beforeCopies, beforeTiles = rays, #copies, #sandTiles
Details.ensure(root)
check(rays == beforeRays and #copies == beforeCopies and #sandTiles == beforeTiles,
	'Refreshing current scenery and sand must be idempotent')
check(replicatedStorage:FindFirstChild(Carpet.FOLDER) == published, 'Current templates are kept')
-- A baked map with current scenery but no published templates (a fresh server) republishes them
published:Destroy()
Details.ensure(root)
local republished = replicatedStorage:FindFirstChild(Carpet.FOLDER)
check(republished ~= nil and #Carpet.decode(republished:FindFirstChild('Gardens').Value) == #gardenPoints,
	'Baked scenery republishes the templates with its own garden cells')
check(rays == beforeRays, 'Republishing casts no rays')
print(`Seabed scenery: {checks} checks passed; {oceanCount} ocean, {lakeCount} lake, {cityCount} city-approach cells (client-built); {templateParts} template parts on the server`)
