-- Publishes the lake's NPC fishers (see Shared.NpcFishers for how they work).
--
-- Once, after the harbour opens, this finds open water in the main island's lake on a grid:
-- every cell is probed for Terrain water at the surface, enough depth beneath it, and nothing
-- built over or beside it (docks, pilings, moorings). Fishing spots are picked in the most open
-- water, and A* over the grid joins them into one closed loop per fisher. The loops go out as
-- string attributes, with one boat template; each client builds and moves the boats itself.
-- After that the only work here is setting each fisher's Active attribute when the player
-- count changes, so the fishers cost the server nothing per frame and send nothing per frame.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NpcFishers = require(Shared.NpcFishers)
local Biomes = require(Shared.Biomes)
local Weather = require(Shared.Weather)
local FishingBoat = require(script.Parent.FishingBoat)

local NpcFisherService = {}

local CELL = 12 -- grid spacing in studs
local MIN_DEPTH = 5 -- water depth a cell needs under the hull
local CLEAR_HALF = 10 -- half size of the box around a cell that must be free of built parts
-- Lake bounds (Weather.inLake's own early-out box), shrunk a little: the outline is the shore.
local MIN_X, MAX_X, MIN_Z, MAX_Z = -610, 520, -550, 390
local SPOT_COUNT = 10 -- fishing spots over both fishers
local SPOT_SPACING = 90 -- studs between any two spots
local SPOT_CLEARANCE = 4 -- cells of open water a spot needs on every side, at best
local PATH_CLEARANCE = 2 -- cells of open water a straightened route keeps from anything
local APPLY_DELAY = 4 -- seconds a player count must hold before fishers appear or leave
local WORK_BUDGET = 0.006 -- seconds of route search per frame
local started = false

-- The lake grid: cell key -> distance (in cells) to the nearest unusable cell, for usable cells.
type Grid = { columns: number, rows: number, clear: { [number]: number } }

local function key(column: number, row: number, columns: number): number
	return row * columns + column
end

local function cellPosition(column: number, row: number): (number, number)
	return MIN_X + column * CELL, MIN_Z + row * CELL
end

local resumed = os.clock()
local function pace()
	if os.clock() - resumed > WORK_BUDGET then
		task.wait()
		resumed = os.clock()
	end
end

-- Things a probe must look through: boats come and go, sharks swim, characters walk.
local function ignoredInstances(): { Instance }
	local ignored = {}
	for _, name in { "PlayerBoats", "Sharks", NpcFishers.FOLDER } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(ignored, folder)
		end
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignored, player.Character)
		end
	end
	return ignored
end

-- Invisible non-colliding volumes (area triggers and the like) are not obstacles.
local function isPhantom(part: Instance): boolean
	return part:IsA("BasePart") and not part.CanCollide and part.Transparency >= 0.95
end

local function makeProbe()
	local ignored = ignoredInstances()
	local waterParams = RaycastParams.new()
	waterParams.FilterType = Enum.RaycastFilterType.Exclude
	waterParams.FilterDescendantsInstances = ignored
	waterParams.IgnoreWater = false
	local bedParams = RaycastParams.new()
	bedParams.FilterType = Enum.RaycastFilterType.Exclude
	bedParams.FilterDescendantsInstances = ignored
	bedParams.IgnoreWater = true
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = ignored
	local level = Biomes.WaterLevel
	local terrain = workspace.Terrain

	-- Casts, looking through phantom volumes (each one found is skipped for the rest of the scan).
	local function cast(origin: Vector3, direction: Vector3, params: RaycastParams): RaycastResult?
		for _ = 1, 6 do
			local hit = workspace:Raycast(origin, direction, params)
			if not hit or not isPhantom(hit.Instance) then
				return hit
			end
			params:AddToFilter(hit.Instance)
		end
		return nil
	end

	-- Terrain water at the surface with nothing built over it, and deep enough beneath.
	local function wet(x: number, z: number): boolean
		local surface = cast(Vector3.new(x, level + 80, z), Vector3.new(0, -160, 0), waterParams)
		if
			not surface
			or surface.Instance ~= terrain
			or surface.Material ~= Enum.Material.Water
			or math.abs(surface.Position.Y - level) > 3
		then
			return false
		end
		local bed = cast(Vector3.new(x, level - 0.5, z), Vector3.new(0, -80, 0), bedParams)
		return not bed or bed.Position.Y < level - MIN_DEPTH
	end

	-- No solid or visible part in the hull's way around this point.
	local function open(x: number, z: number): boolean
		local box = CFrame.new(x, level + 4, z)
		for _, part in workspace:GetPartBoundsInBox(box, Vector3.new(CLEAR_HALF * 2, 12, CLEAR_HALF * 2), overlap) do
			if not isPhantom(part) then
				return false
			end
		end
		return true
	end

	return wet, open
end

local function buildGrid(): Grid
	local columns = math.floor((MAX_X - MIN_X) / CELL) + 1
	local rows = math.floor((MAX_Z - MIN_Z) / CELL) + 1
	local wet, open = makeProbe()
	local water: { [number]: boolean } = {}
	for row = 0, rows - 1 do
		for column = 0, columns - 1 do
			local x, z = cellPosition(column, row)
			if Weather.inLake(Vector3.new(x, 0, z)) and wet(x, z) then
				water[key(column, row, columns)] = true
			end
			pace()
		end
	end
	-- A usable cell has water on all eight neighbours too (so the hull's whole width floats)
	-- and nothing built in the box around it.
	local usable: { [number]: boolean } = {}
	for row = 1, rows - 2 do
		for column = 1, columns - 2 do
			local k = key(column, row, columns)
			if water[k] then
				local ok = true
				for dz = -1, 1 do
					for dx = -1, 1 do
						if not water[key(column + dx, row + dz, columns)] then
							ok = false
						end
					end
				end
				if ok then
					local x, z = cellPosition(column, row)
					ok = open(x, z)
					pace()
				end
				if ok then
					usable[k] = true
				end
			end
		end
	end
	-- Distance (in cells) from each usable cell to the nearest unusable one: breadth first from
	-- the edge inward. Spots go where it is largest, and routes keep away from the edge.
	local clear: { [number]: number } = {}
	local frontier = {}
	for k in usable do
		local column, row = k % columns, k // columns
		for _, offset in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			if not usable[key(column + offset[1], row + offset[2], columns)] then
				clear[k] = 1
				table.insert(frontier, k)
				break
			end
		end
	end
	local depth = 1
	while #frontier > 0 do
		depth += 1
		local nextFrontier = {}
		for _, k in frontier do
			local column, row = k % columns, k // columns
			for _, offset in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				local neighbour = key(column + offset[1], row + offset[2], columns)
				if usable[neighbour] and not clear[neighbour] then
					clear[neighbour] = depth
					table.insert(nextFrontier, neighbour)
				end
			end
		end
		frontier = nextFrontier
		pace()
	end
	return { columns = columns, rows = rows, clear = clear }
end

-- The connected body of open water holding the most cells (one disconnected pond is useless).
local function largestBody(grid: Grid): { [number]: boolean }
	local seen: { [number]: boolean } = {}
	local best: { [number]: boolean } = {}
	local bestCount = 0
	for start in grid.clear do
		if seen[start] then
			continue
		end
		local body, count, queue, head = {}, 0, { start }, 1
		seen[start] = true
		while queue[head] do
			local k = queue[head]
			head += 1
			body[k] = true
			count += 1
			local column, row = k % grid.columns, k // grid.columns
			for _, offset in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				local neighbour = key(column + offset[1], row + offset[2], grid.columns)
				if grid.clear[neighbour] and not seen[neighbour] then
					seen[neighbour] = true
					table.insert(queue, neighbour)
				end
			end
		end
		if count > bestCount then
			best, bestCount = body, count
		end
		pace()
	end
	return best
end

-- Farthest-point picks across the most open water, at least SPOT_SPACING apart.
local function pickSpots(grid: Grid, body: { [number]: boolean }, random: Random): { number }
	for clearance = SPOT_CLEARANCE, 2, -1 do
		local candidates = {}
		for k in body do
			if grid.clear[k] >= clearance then
				table.insert(candidates, k)
			end
		end
		table.sort(candidates) -- pairs order is not stable; keep the pick seedable
		if #candidates < 2 then
			continue
		end
		local spots = { candidates[random:NextInteger(1, #candidates)] }
		local nearest: { [number]: number } = {}
		while #spots < SPOT_COUNT do
			local last = spots[#spots]
			local lx, lz = cellPosition(last % grid.columns, last // grid.columns)
			local bestK, bestDistance = nil, SPOT_SPACING
			for _, k in candidates do
				local x, z = cellPosition(k % grid.columns, k // grid.columns)
				local d = math.min(nearest[k] or math.huge, math.sqrt((x - lx) ^ 2 + (z - lz) ^ 2))
				nearest[k] = d
				if d > bestDistance then
					bestK, bestDistance = k, d
				end
			end
			if not bestK then
				break
			end
			table.insert(spots, bestK)
		end
		if #spots >= 2 then
			return spots
		end
	end
	return {}
end

-- A* between two cells over the open water, preferring cells farther from the edge.
local function findPath(grid: Grid, body: { [number]: boolean }, from: number, to: number): { number }?
	local columns = grid.columns
	local tx, tz = to % columns, to // columns
	local function estimate(k: number): number
		local dx, dz = math.abs(k % columns - tx), math.abs(k // columns - tz)
		return math.max(dx, dz) + 0.414 * math.min(dx, dz)
	end
	local open, cost, cameFrom, closed = { from }, { [from] = 0 }, {}, {}
	local score = { [from] = estimate(from) }
	local steps = 0
	while #open > 0 do
		local bestIndex = 1
		for i = 2, #open do
			if score[open[i]] < score[open[bestIndex]] then
				bestIndex = i
			end
		end
		local current = open[bestIndex]
		open[bestIndex] = open[#open]
		open[#open] = nil
		if current == to then
			local path = { current }
			while cameFrom[current] do
				current = cameFrom[current]
				table.insert(path, 1, current)
			end
			return path
		end
		closed[current] = true
		local column, row = current % columns, current // columns
		for dz = -1, 1 do
			for dx = -1, 1 do
				if dx == 0 and dz == 0 then
					continue
				end
				local neighbour = key(column + dx, row + dz, columns)
				if not body[neighbour] or closed[neighbour] then
					continue
				end
				-- No cutting a diagonal past a blocked corner.
				if dx ~= 0 and dz ~= 0 and (not body[key(column + dx, row, columns)] or not body[key(column, row + dz, columns)]) then
					continue
				end
				local step = (if dx ~= 0 and dz ~= 0 then 1.414 else 1) * (1 + 2 / grid.clear[neighbour])
				local total = cost[current] + step
				if total < (cost[neighbour] or math.huge) then
					if not cost[neighbour] then
						table.insert(open, neighbour)
					end
					cost[neighbour] = total
					score[neighbour] = total + estimate(neighbour)
					cameFrom[neighbour] = current
				end
			end
		end
		steps += 1
		if steps % 64 == 0 then
			pace()
		end
	end
	return nil
end

-- True if the straight line between two cells stays PATH_CLEARANCE cells from any edge.
local function lineOfSight(grid: Grid, a: number, b: number): boolean
	local columns = grid.columns
	local ax, az = a % columns, a // columns
	local bx, bz = b % columns, b // columns
	local samples = math.ceil(math.max(math.abs(bx - ax), math.abs(bz - az)) * 3)
	for i = 0, samples do
		local t = if samples > 0 then i / samples else 0
		local c = math.round(ax + (bx - ax) * t)
		local r = math.round(az + (bz - az) * t)
		local clearance = grid.clear[key(c, r, columns)]
		if not clearance or clearance < math.min(PATH_CLEARANCE, grid.clear[a], grid.clear[b]) then
			return false
		end
	end
	return true
end

-- Drops every path cell the route can skip in a straight line (string pulling).
local function straighten(grid: Grid, path: { number }): { number }
	local kept = { path[1] }
	local anchor = 1
	while anchor < #path do
		local farthest = anchor + 1
		for candidate = #path, anchor + 2, -1 do
			if lineOfSight(grid, path[anchor], path[candidate]) then
				farthest = candidate
				break
			end
		end
		table.insert(kept, path[farthest])
		anchor = farthest
		pace()
	end
	return kept
end

-- A closed loop through `spots` in order, as route points with the spots flagged.
local function buildRoute(grid: Grid, body: { [number]: boolean }, spots: { number }): { NpcFishers.Point }?
	local points = {}
	for index, spot in spots do
		local nextSpot = spots[index % #spots + 1]
		local path = findPath(grid, body, spot, nextSpot)
		if not path then
			return nil
		end
		path = straighten(grid, path)
		-- The last cell is the next leg's first, so it is left for that leg.
		for i = 1, #path - 1 do
			local x, z = cellPosition(path[i] % grid.columns, path[i] // grid.columns)
			table.insert(points, { x = x, z = z, stop = i == 1 })
		end
	end
	return points
end

-- Splits the spots into one group per fisher, each a run of neighbours around the lake, and
-- orders each group so its loop sweeps around rather than zig-zagging.
local function groupSpots(grid: Grid, spots: { number }, groups: number): { { number } }
	local cx, cz = 0, 0
	for _, k in spots do
		local x, z = cellPosition(k % grid.columns, k // grid.columns)
		cx += x / #spots
		cz += z / #spots
	end
	local sorted = table.clone(spots)
	local angles = {}
	for _, k in sorted do
		local x, z = cellPosition(k % grid.columns, k // grid.columns)
		angles[k] = math.atan2(z - cz, x - cx)
	end
	table.sort(sorted, function(a, b)
		return angles[a] < angles[b]
	end)
	if groups <= 1 or #sorted < 4 then
		return { sorted }
	end
	local result = {}
	local size = math.ceil(#sorted / groups)
	for g = 1, groups do
		local group = table.move(sorted, (g - 1) * size + 1, math.min(g * size, #sorted), 1, {})
		if #group >= 2 then
			table.insert(result, group)
		end
	end
	return result
end

local function publish(folder: Folder)
	local began = os.clock()
	local grid = buildGrid()
	local body = largestBody(grid)
	local random = Random.new(20261111)
	local spots = pickSpots(grid, body, random)
	if #spots < 2 then
		warn("[NpcFishers] No open water found in the lake; fishers stay home")
		return
	end
	local routes = {}
	for _, group in groupSpots(grid, spots, NpcFishers.MAX) do
		local route = buildRoute(grid, body, group)
		if route then
			table.insert(routes, NpcFishers.encode(route))
		end
	end
	if #routes == 0 then
		warn("[NpcFishers] Could not join the fishing spots by water; fishers stay home")
		return
	end
	local now = workspace:GetServerTimeNow()
	for index = 1, NpcFishers.MAX do
		local fisher = folder:FindFirstChild("Fisher" .. index) or Instance.new("Configuration")
		fisher.Name = "Fisher" .. index
		-- With one route only, the second fisher runs it half a lap behind the first.
		local route = routes[(index - 1) % #routes + 1]
		local seed = index * 7919
		local behind = 0
		if index > #routes then
			local decoded = NpcFishers.decode(route)
			behind = if decoded then NpcFishers.plan(decoded, seed).period / 2 else 0
		end
		fisher:SetAttribute("Route", route)
		fisher:SetAttribute("Seed", seed)
		fisher:SetAttribute("Epoch", now - behind - index * 23)
		if fisher:GetAttribute("Active") == nil then
			fisher:SetAttribute("Active", false)
		end
		fisher.Parent = folder
	end
	print(
		string.format(
			"[NpcFishers] %d spots on %d route(s) in %.1fs",
			#spots,
			#routes,
			os.clock() - began
		)
	)
end

-- A local copy of the small fishing boat for every client to clone: anchored, seats disabled.
local function publishTemplate(folder: Folder)
	if folder:FindFirstChild(NpcFishers.TEMPLATE) then
		return
	end
	local boat = FishingBoat.build(CFrame.identity, true)
	for _, item in boat:GetDescendants() do
		if item:IsA("Seat") or item:IsA("VehicleSeat") then
			item.Disabled = true
		end
		if item:IsA("BasePart") then
			item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
		elseif item:IsA("ClickDetector") or item:IsA("ProximityPrompt") or item:IsA("BaseScript") then
			item:Destroy()
		end
	end
	boat.Name = NpcFishers.TEMPLATE
	boat.Parent = folder
end

function NpcFisherService.start()
	if started then
		return
	end
	started = true
	local folder = ReplicatedStorage:FindFirstChild(NpcFishers.FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = NpcFishers.FOLDER
		folder.Parent = ReplicatedStorage
	end
	publishTemplate(folder)

	local function apply()
		local count = NpcFishers.countFor(#Players:GetPlayers())
		for index = 1, NpcFishers.MAX do
			local fisher = folder:FindFirstChild("Fisher" .. index)
			if fisher then
				fisher:SetAttribute("Active", index <= count)
			end
		end
	end
	-- Coalesce joins and leaves: a count has to hold for APPLY_DELAY before boats come or go,
	-- so someone rejoining does not make a boat blink out and back.
	local pending = 0
	local function schedule()
		pending += 1
		local ticket = pending
		task.delay(APPLY_DELAY, function()
			if ticket == pending then
				apply()
			end
		end)
	end
	Players.PlayerAdded:Connect(schedule)
	Players.PlayerRemoving:Connect(schedule)

	-- The scan reads the finished harbour, so it waits for the world to open; the harbour's
	-- own startup is never held up by it.
	task.spawn(function()
		while not ReplicatedStorage:GetAttribute("FishingWatersWorldReady") do
			task.wait(1)
		end
		task.wait(5)
		local ok, problem = xpcall(publish, debug.traceback, folder)
		if not ok then
			warn("[NpcFishers] " .. tostring(problem))
			return
		end
		apply()
	end)
end

return NpcFisherService
