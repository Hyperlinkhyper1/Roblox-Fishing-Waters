-- Walkable-ground grid for the townsfolk: flood fill, A* and path smoothing.
--
-- PedestrianService fills the grid once from raycasts over the town; after that
-- every route is planned here on plain arrays, with no physics queries. Pure Luau
-- (no Roblox types) so lute harnesses can drive it with hand-made grids.
local Grid = {}

export type Grid = {
	cols: number,
	rows: number,
	cell: number,
	originX: number,
	originZ: number,
	walk: { boolean }, -- index = c + r * cols + 1, with c and r from 0
	height: { number }, -- ground height of each walkable cell
	cost: { number }, -- per-stud cost multiplier: paving 1, grass and sand more
	maxStep: number, -- largest height change between neighbouring cells
}

local SQRT2 = math.sqrt(2)
local NEIGHBOURS = {
	{ 1, 0, 1 },
	{ -1, 0, 1 },
	{ 0, 1, 1 },
	{ 0, -1, 1 },
	{ 1, 1, SQRT2 },
	{ 1, -1, SQRT2 },
	{ -1, 1, SQRT2 },
	{ -1, -1, SQRT2 },
}

function Grid.new(cols: number, rows: number, cell: number, originX: number, originZ: number, maxStep: number?): Grid
	local walk, height, cost = table.create(cols * rows, false), table.create(cols * rows, 0), table.create(cols * rows, 1)
	return {
		cols = cols,
		rows = rows,
		cell = cell,
		originX = originX,
		originZ = originZ,
		walk = walk,
		height = height,
		cost = cost,
		maxStep = maxStep or 1.2,
	}
end

function Grid.index(grid: Grid, c: number, r: number): number
	return c + r * grid.cols + 1
end

function Grid.coords(grid: Grid, index: number): (number, number)
	local i = index - 1
	return i % grid.cols, i // grid.cols
end

-- World x, z at the middle of a cell.
function Grid.center(grid: Grid, index: number): (number, number)
	local c, r = Grid.coords(grid, index)
	return grid.originX + (c + 0.5) * grid.cell, grid.originZ + (r + 0.5) * grid.cell
end

function Grid.cellAt(grid: Grid, x: number, z: number): number?
	local c = math.floor((x - grid.originX) / grid.cell)
	local r = math.floor((z - grid.originZ) / grid.cell)
	if c < 0 or r < 0 or c >= grid.cols or r >= grid.rows then
		return nil
	end
	return Grid.index(grid, c, r)
end

local function linked(grid: Grid, a: number, b: number): boolean
	return grid.walk[b] and math.abs(grid.height[a] - grid.height[b]) <= grid.maxStep
end

-- Neighbour of `index` by (dc, dr) a pedestrian can step to, or nil. Diagonal
-- steps need both side cells open so routes never clip a corner.
local function step(grid: Grid, index: number, dc: number, dr: number): number?
	local c, r = Grid.coords(grid, index)
	local nc, nr = c + dc, r + dr
	if nc < 0 or nr < 0 or nc >= grid.cols or nr >= grid.rows then
		return nil
	end
	local target = Grid.index(grid, nc, nr)
	if not linked(grid, index, target) then
		return nil
	end
	if dc ~= 0 and dr ~= 0 then
		local side1, side2 = Grid.index(grid, nc, r), Grid.index(grid, c, nr)
		if not linked(grid, index, side1) or not linked(grid, index, side2) then
			return nil
		end
	end
	return target
end
Grid.step = step

-- Close every walkable cell that can't be reached from `seed` (roofs, courtyards,
-- shop interiors). Returns how many cells stay open.
function Grid.keepConnected(grid: Grid, seed: number, pause: (() -> ())?): number
	local reached = {}
	local queue = { seed }
	reached[seed] = true
	local head = 1
	while head <= #queue do
		local index = queue[head]
		head += 1
		for _, n in NEIGHBOURS do
			if n[3] == 1 then
				local nextIndex = step(grid, index, n[1], n[2])
				if nextIndex and not reached[nextIndex] then
					reached[nextIndex] = true
					table.insert(queue, nextIndex)
				end
			end
		end
		if pause and head % 2000 == 0 then
			pause()
		end
	end
	for index = 1, grid.cols * grid.rows do
		if grid.walk[index] and not reached[index] then
			grid.walk[index] = false
		end
	end
	return #queue
end

-- Nearest open cell to a world point within `reach` studs.
function Grid.nearest(grid: Grid, x: number, z: number, reach: number): number?
	local cell = grid.cell
	local c0 = math.floor((x - grid.originX) / cell)
	local r0 = math.floor((z - grid.originZ) / cell)
	local span = math.ceil(reach / cell)
	local best, bestDistance = nil, reach * reach
	for dr = -span, span do
		for dc = -span, span do
			local c, r = c0 + dc, r0 + dr
			if c >= 0 and r >= 0 and c < grid.cols and r < grid.rows then
				local index = Grid.index(grid, c, r)
				if grid.walk[index] then
					local cx, cz = grid.originX + (c + 0.5) * cell, grid.originZ + (r + 0.5) * cell
					local d = (cx - x) ^ 2 + (cz - z) ^ 2
					if d <= bestDistance then
						best, bestDistance = index, d
					end
				end
			end
		end
	end
	return best
end

-- Binary min-heap of cell indices keyed by f-score.
local function push(heap: { number }, score: { number }, index: number)
	table.insert(heap, index)
	local i = #heap
	while i > 1 do
		local parent = i // 2
		if score[heap[parent]] <= score[index] then
			break
		end
		heap[i] = heap[parent]
		i = parent
	end
	heap[i] = index
end

local function pop(heap: { number }, score: { number }): number
	local top = heap[1]
	local last = table.remove(heap) :: number
	local n = #heap
	if n > 0 then
		local i = 1
		while true do
			local child = i * 2
			if child > n then
				break
			end
			if child < n and score[heap[child + 1]] < score[heap[child]] then
				child += 1
			end
			if score[heap[child]] >= score[last] then
				break
			end
			heap[i] = heap[child]
			i = child
		end
		heap[i] = last
	end
	return top
end

-- Cheap per-cell noise in [0, 1) so two trips between the same places don't
-- always follow the identical line.
local function jitter(index: number, seed: number): number
	local h = bit32.bxor(index * 374761393, seed * 668265263)
	-- Keep products under 2^53 so the low bits survive as exact integers
	h = bit32.band(bit32.bxor(h, bit32.rshift(h, 13)), 0xfffff) * 1274126177
	return bit32.band(bit32.rshift(h, 7), 0xffff) / 0x10000
end

-- Cheapest route from cell `from` to cell `to` as a list of cell indices, or nil.
-- `noise` (0-1) roughens the costs with `seed` so routes vary a little.
function Grid.findPath(grid: Grid, from: number, to: number, seed: number?, noise: number?): { number }?
	if not grid.walk[from] or not grid.walk[to] then
		return nil
	end
	if from == to then
		return { from }
	end
	local cell = grid.cell
	local tc, tr = Grid.coords(grid, to)
	local function heuristic(index: number): number
		local c, r = Grid.coords(grid, index)
		local dx, dz = math.abs(c - tc), math.abs(r - tr)
		return (math.max(dx, dz) + (SQRT2 - 1) * math.min(dx, dz)) * cell
	end
	local g: { [number]: number } = { [from] = 0 }
	local f: { [number]: number } = { [from] = heuristic(from) }
	local cameFrom: { [number]: number } = {}
	local closed: { [number]: boolean } = {}
	local heap = {}
	push(heap, f, from)
	local amount = noise or 0
	local s = seed or 0
	local expanded = 0
	while #heap > 0 do
		local current = pop(heap, f)
		if current == to then
			local path = { current }
			while cameFrom[current] do
				current = cameFrom[current]
				table.insert(path, current)
			end
			-- Reverse in place
			local n = #path
			for i = 1, n // 2 do
				path[i], path[n - i + 1] = path[n - i + 1], path[i]
			end
			return path
		end
		if not closed[current] then
			closed[current] = true
			expanded += 1
			if expanded > grid.cols * grid.rows then
				return nil
			end
			for _, n in NEIGHBOURS do
				local nextIndex = step(grid, current, n[1], n[2])
				if nextIndex and not closed[nextIndex] then
					local weight = (grid.cost[current] + grid.cost[nextIndex]) * 0.5
					if amount > 0 then
						weight *= 1 + amount * jitter(nextIndex, s)
					end
					local tentative = g[current] + n[3] * cell * weight
					if g[nextIndex] == nil or tentative < g[nextIndex] then
						g[nextIndex] = tentative
						f[nextIndex] = tentative + heuristic(nextIndex)
						cameFrom[nextIndex] = current
						push(heap, f, nextIndex)
					end
				end
			end
		end
	end
	return nil
end

-- True when a straight walk from cell a to cell b stays on open cells no
-- dearer than `maxCost`, with ground close to a straight ramp between them.
function Grid.lineClear(grid: Grid, a: number, b: number, maxCost: number): boolean
	local ax, az = Grid.center(grid, a)
	local bx, bz = Grid.center(grid, b)
	local ha, hb = grid.height[a], grid.height[b]
	local length = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
	local samples = math.max(1, math.ceil(length / (grid.cell * 0.25)))
	-- Check a body's width either side of the line, not just its centre
	local nx, nz = 0, 0
	if length > 0 then
		nx, nz = -(bz - az) / length * grid.cell * 0.45, (bx - ax) / length * grid.cell * 0.45
	end
	local previous = a
	for i = 1, samples do
		local t = i / samples
		local x, z = ax + (bx - ax) * t, az + (bz - az) * t
		local expected = ha + (hb - ha) * t
		for side = -1, 1 do
			local index = Grid.cellAt(grid, x + nx * side, z + nz * side)
			if not index or not grid.walk[index] or grid.cost[index] > maxCost then
				return false
			end
			if math.abs(grid.height[index] - expected) > 0.6 then
				return false
			end
		end
		local centre = Grid.cellAt(grid, x, z) :: number
		if centre ~= previous then
			if math.abs(grid.height[centre] - grid.height[previous]) > grid.maxStep then
				return false
			end
			previous = centre
		end
	end
	return true
end

-- Drop the grid's staircase corners: keep only the cells where a straight line
-- can no longer reach further along the route.
function Grid.smooth(grid: Grid, path: { number }): { number }
	local n = #path
	if n <= 2 then
		return table.clone(path)
	end
	local result = { path[1] }
	local anchor = 1
	while anchor < n do
		local maxCost = grid.cost[path[anchor]]
		local reach = anchor + 1
		local probeCost = maxCost
		for j = anchor + 1, n do
			probeCost = math.max(probeCost, grid.cost[path[j]])
			-- Only shortcut across ground at most as dear as the route already used
			if j > anchor + 1 and not Grid.lineClear(grid, path[anchor], path[j], probeCost) then
				break
			end
			reach = j
			-- Long straight runs still get a point every so often so heights follow the ground
			if (j - anchor) * grid.cell > 60 then
				break
			end
		end
		table.insert(result, path[reach])
		anchor = reach
	end
	return result
end

-- World x, y, z triples for a list of cells.
function Grid.points(grid: Grid, cells: { number }): { number }
	local points = table.create(#cells * 3)
	for _, index in cells do
		local x, z = Grid.center(grid, index)
		table.insert(points, x)
		table.insert(points, grid.height[index])
		table.insert(points, z)
	end
	return points
end

return Grid
