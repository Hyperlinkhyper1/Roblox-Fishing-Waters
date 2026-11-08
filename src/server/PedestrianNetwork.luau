-- One sparse walking grid over the harbour's actual roads, lanes, piazza and
-- public paths. Only cells near those surfaces are queried; no island-wide
-- rectangular terrain scan, and no physics queries while pedestrians travel.
local Grid = require(script.Parent.PedestrianGrid)
local Network = {}
local CELL = 3
local DIRECTIONS = { {1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {-1, 1}, {1, -1}, {-1, -1} }

function Network.build(map: Instance, businesses)
	local yieldAt = os.clock()
	local function pause()
		if os.clock() - yieldAt > 0.004 then
			task.wait()
			yieldAt = os.clock()
		end
	end
	local island = if map.Name == "Harbour Isle" then map else nil
	if not island then
		for _, item in map:GetDescendants() do
			if item.Name == "Harbour Isle" then island = item; break end
		end
	end
	local village = island and island:FindFirstChild("Village")
	if not village then return nil end
	local surfaces = {}
	local function rectangle(frame: CFrame, width: number, length: number)
		local region = { frame = frame, halfX = width / 2, halfZ = length / 2 }
		table.insert(surfaces, region)
		return region
	end
	local function surface(part: Instance)
		if not part:IsA("BasePart") then return end
		local size = part.Size
		if size.Y <= 1 and size.X >= 4 and size.Z > 0.5 then
			rectangle(part.CFrame + Vector3.new(0, size.Y / 2, 0), size.X, size.Z)
		elseif part:IsA("Part") and part.Shape == Enum.PartType.Cylinder and size.X <= 1 and size.Y >= 4 then
			-- Props.cylinder lies with its local X axis upright.
			table.insert(surfaces, { frame = CFrame.new(part.Position + Vector3.new(0, size.X / 2, 0)), radius = size.Y / 2 })
		end
	end
	for _, name in { "Road", "Lane", "CrossStreets" } do
		local group = village:FindFirstChild(name)
		if group then for _, part in group:GetDescendants() do surface(part) end end
	end
	for _, item in village:GetChildren() do
		if string.sub(item.Name, 1, 9) == "BaseTrack" then
			for _, part in item:GetDescendants() do surface(part) end
		elseif item:IsA("BasePart") and item.Material == Enum.Material.Pebble then
			-- The public footpath to the lighthouse.
			surface(item)
		end
	end
	local plaza = village:FindFirstChild("Plaza")
	if plaza then
		for _, part in plaza:GetChildren() do
			if part:IsA("BasePart") and part.Size.Y <= 1 and part.Size.X > 100 and part.Size.Z > 100 then surface(part) end
		end
	end
	for _, business in businesses do
		-- A supported forecourt connects the real street to the shop doorway.
		local p = business.position
		local startZ = math.min(52, p.Z)
		local region = rectangle(business.frame * CFrame.new(p.X, -0.1, (startZ + p.Z) / 2), 7.5, math.abs(p.Z - startZ) + 4)
		region.doorFrame, region.limitZ = business.frame, p.Z + 0.8
	end
	if #surfaces == 0 then return nil end
	local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
	for _, region in surfaces do
		local extentX, extentZ = region.radius or region.halfX, region.radius or region.halfZ
		for _, sx in {-1, 1} do
			for _, sz in {-1, 1} do
				local p = region.frame:PointToWorldSpace(Vector3.new(sx * extentX, 0, sz * extentZ))
				minX, maxX = math.min(minX, p.X - 3), math.max(maxX, p.X + 3)
				minZ, maxZ = math.min(minZ, p.Z - 3), math.max(maxZ, p.Z + 3)
			end
		end
	end
	minX, minZ = math.floor(minX / CELL) * CELL, math.floor(minZ / CELL) * CELL
	local scan = {
		cols = math.ceil((maxX - minX) / CELL), rows = math.ceil((maxZ - minZ) / CELL),
		cell = CELL, originX = minX, originZ = minZ, maxStep = 1.1,
		walk = {}, height = {}, cost = {},
	}
	local candidates = {}
	for _, region in surfaces do
		local ex, ez = region.radius or region.halfX, region.radius or region.halfZ
		local radius = math.sqrt(ex * ex + ez * ez) + 3
		local middle = region.frame.Position
		-- Project the rectangle's four corners, avoiding a large bounding square
		-- for long, narrow road segments.
		local lx, hx, lz, hz = middle.X - radius, middle.X + radius, middle.Z - radius, middle.Z + radius
		if not region.radius then
			lx, hx, lz, hz = math.huge, -math.huge, math.huge, -math.huge
			for _, sx in {-1, 1} do for _, sz in {-1, 1} do
				local p = region.frame:PointToWorldSpace(Vector3.new(sx * (ex + 2), 0, sz * (ez + 2)))
				lx, hx, lz, hz = math.min(lx, p.X), math.max(hx, p.X), math.min(lz, p.Z), math.max(hz, p.Z)
			end end
		end
		for row = math.max(0, math.floor((lz - minZ) / CELL)), math.min(scan.rows - 1, math.ceil((hz - minZ) / CELL)) do
			for col = math.max(0, math.floor((lx - minX) / CELL)), math.min(scan.cols - 1, math.ceil((hx - minX) / CELL)) do
				local cell = Grid.index(scan, col, row)
				local x, z = Grid.center(scan, cell)
				local p = region.frame:PointToObjectSpace(Vector3.new(x, middle.Y, z))
				local inside = if region.radius then p.X*p.X + p.Z*p.Z <= (region.radius + 1)^2
					else math.abs(p.X) <= ex + 0.5 and math.abs(p.Z) <= ez + 2
				if inside and region.doorFrame then
					inside = region.doorFrame:PointToObjectSpace(Vector3.new(x, middle.Y, z)).Z <= region.limitZ
				end
				if inside then candidates[cell] = math.max(candidates[cell] or -math.huge, middle.Y) end
			end
			pause()
		end
	end
	local ignore: { Instance } = {}
	local physical = workspace:FindFirstChild("ShopCustomers")
	if physical then table.insert(ignore, physical) end
	for _, player in game:GetService("Players"):GetPlayers() do
		if player.Character then table.insert(ignore, player.Character) end
	end
	local rays, overlap = RaycastParams.new(), OverlapParams.new()
	rays.FilterType, overlap.FilterType = Enum.RaycastFilterType.Exclude, Enum.RaycastFilterType.Exclude
	rays.FilterDescendantsInstances, overlap.FilterDescendantsInstances = ignore, ignore
	rays.RespectCanCollide, rays.IgnoreWater = true, false
	overlap.RespectCanCollide, overlap.MaxParts = true, 1
	local cells = {}
	for cell, expected in candidates do
		local x, z = Grid.center(scan, cell)
		local hit = workspace:Raycast(Vector3.new(x, expected + 2, z), Vector3.new(0, -5, 0), rays)
		if hit and hit.Material ~= Enum.Material.Water and hit.Normal.Y > 0.75 and math.abs(hit.Position.Y - expected) <= 1.1 then
			local y = hit.Position.Y
			if #workspace:GetPartBoundsInBox(CFrame.new(x, y + 3.05, z), Vector3.new(2.5, 4.9, 2.5), overlap) == 0 then
				scan.walk[cell], scan.height[cell], scan.cost[cell] = true, y, 1
				table.insert(cells, cell)
			end
		end
		pause()
	end
	-- Components prevent a random destination across water or an actual broken
	-- road. Every destination is reachable from the pedestrian's present cell.
	local componentOf, components = {}, {}
	for _, seed in cells do
		if componentOf[seed] then continue end
		local group = { seed }
		local id = #components + 1
		componentOf[seed] = id
		local head = 1
		while head <= #group do
			local at = group[head]
			head += 1
			for _, d in DIRECTIONS do
				local to = Grid.step(scan, at, d[1], d[2])
				if to and not componentOf[to] then
					componentOf[to] = id
					table.insert(group, to)
				end
			end
			if head % 128 == 0 then pause() end
		end
		table.insert(components, group)
	end
	-- A disconnected paving sliver is usable for an approach but must never
	-- seed a walker whose only possible journey is a few steps back and forth.
	local travelling = {}
	for _, group in components do
		local lowX, highX, lowZ, highZ = math.huge, -math.huge, math.huge, -math.huge
		for _, cell in group do
			local x, z = Grid.center(scan, cell)
			lowX, highX, lowZ, highZ = math.min(lowX, x), math.max(highX, x), math.min(lowZ, z), math.max(highZ, z)
		end
		if (highX - lowX)^2 + (highZ - lowZ)^2 >= 120^2 then
			table.move(group, 1, #group, #travelling + 1, travelling)
		end
	end
	return { grid = scan, cells = travelling, componentOf = componentOf, components = components, island = island }
end

function Network.point(network, cell: number): Vector3
	local x, z = Grid.center(network.grid, cell)
	return Vector3.new(x, network.grid.height[cell], z)
end

return Network
