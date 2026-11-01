-- Shared server-side navigation for customers and staff.
--
-- Walk each segment with a single Humanoid:MoveTo and poll progress instead of
-- re-steering every tick. Per-tick Move calls made R15 rigs stall at corners,
-- oscillate around waypoints and walk through low obstacles; a MoveTo is
-- allowed to settle while we watch for real progress. Failed routes are
-- replanned from the NPC's actual position; a rig is never teleported.
local PathfindingService = game:GetService("PathfindingService")

local NpcNavigation = {}
-- Humanoid MoveTo can finish roughly one stud short of its target.
local ARRIVAL_RADIUS = 1.25
-- Aim this far past an intermediate waypoint so MoveTo's short stop still
-- carries the rig around the corner instead of cutting through its inside.
local CORNER_RADIUS = 2
local STUCK_SECONDS = 1
local POLL_SECONDS = 0.1
local MAX_ATTEMPTS = 4
local MAX_WALK_SECONDS = 35
-- Small, supported step back before replanning a segment that stalled.
local BACKOFF_DISTANCE = 3
local BACKOFF_SECONDS = 1.5

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

function NpcNavigation.clearance(npc): number
	local torso = npc.model:FindFirstChild("UpperTorso") or npc.root
	return math.max(2, math.ceil(math.max(torso.Size.X, torso.Size.Z, npc.root.Size.Z) / 2))
end

function NpcNavigation.walk(
	npc,
	target: Vector3,
	allowed: (() -> boolean)?,
	stayOnGround: boolean?,
	straight: boolean?
): boolean
	local humanoid, root = npc.humanoid, npc.root
	local walkSpeed = humanoid.WalkSpeed
	local deadline = os.clock() + MAX_WALK_SECONDS
	local clearance = NpcNavigation.clearance(npc)
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = { npc.model }
	parameters.RespectCanCollide = true
	parameters.CollisionGroup = root.CollisionGroup
	local head = npc.model:FindFirstChild("Head")
	local startFeet = root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
	local height = if head
		then head.Position.Y + head.Size.Y / 2 - startFeet
		else humanoid.HipHeight + root.Size.Y / 2 + 2

	local function valid(): boolean
		return npc.active
			and npc.model.Parent ~= nil
			and root.Parent ~= nil
			and humanoid.Parent ~= nil
			and humanoid.Health > 0
			and (allowed == nil or allowed())
	end
	local function feet(): number
		return root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
	end
	local function arrived(position: Vector3, radius: number?): boolean
		return flatDistance(root.Position, position) <= (radius or ARRIVAL_RADIUS)
			and math.abs(feet() - position.Y) <= 2.5
	end
	local function stop()
		if root.Parent and humanoid.Parent then
			humanoid:Move(Vector3.zero)
			-- Leave the rig standing where it is instead of walking on to an
			-- abandoned goal after a timeout or cancellation.
			humanoid:MoveTo(root.Position)
		end
	end
	-- A path can report a successful route across a gap or along a pier edge.
	-- Check the deck under the whole body along the segment before walking it.
	-- The segment Y is interpolated so ramps and steps stay supported.
	local function supportedBetween(fromPosition: Vector3, position: Vector3, strict: boolean?, sampleStep: number?): boolean
		local from = Vector3.new(fromPosition.X, 0, fromPosition.Z)
		local to = Vector3.new(position.X, 0, position.Z)
		local delta = to - from
		local distance = delta.Magnitude
		if distance < 0.05 then
			return true
		end
		local forward = delta.Unit
		local side = Vector3.new(-forward.Z, 0, forward.X) * (clearance - 0.5)
		local fromY, toY = fromPosition.Y, position.Y
		local samples = math.max(1, math.ceil(distance / (sampleStep or 0.5)))
		for sample = 1, samples do
			local t = sample / samples
			local point = from + delta * t
			local sampleY = fromY + (toY - fromY) * t
			for _, offset in { Vector3.zero, side, -side } do
				local floor = nil
				-- Tiny seams between deck planks must not read as missing deck.
				for _, seam in { 0, 0.13 } do
					floor = workspace:Raycast(
						Vector3.new(point.X, sampleY + 2, point.Z) + offset + forward * seam,
						Vector3.new(0, -5, 0),
						parameters
					)
					if floor and floor.Material ~= Enum.Material.Water and floor.Normal.Y >= 0.7
						and (not strict or math.abs(floor.Position.Y - sampleY) <= 1.1) then
						break
					end
					floor = nil
				end
				if not floor then
					return false
				end
			end
		end
		return true
	end
	local function supported(position: Vector3): boolean
		return not stayOnGround or supportedBetween(Vector3.new(root.Position.X, feet(), root.Position.Z), position, true)
	end
	local function follow(position: Vector3, radius: number, moveDeadline: number, blocked: () -> boolean): boolean
		if arrived(position, radius) then
			return true
		end
		if flatDistance(root.Position, position) < 0.1 then
			-- Horizontally aligned but on another floor: there is no walking
			-- direction that can fix this segment.
			return false
		end
		if not supported(position) then
			return false
		end
		humanoid:MoveTo(position)
		local best = flatDistance(root.Position, position)
		local progressAt = os.clock()
		while valid() and not blocked() and os.clock() < moveDeadline do
			if arrived(position, radius) then
				return true
			end
			task.wait(POLL_SECONDS)
			if not valid() or blocked() then
				return false
			end
			if arrived(position, radius) then
				return true
			end
			local current = flatDistance(root.Position, position)
			if current < best - 0.15 then
				best, progressAt = current, os.clock()
			elseif os.clock() - progressAt >= STUCK_SECONDS then
				-- The humanoid is not making progress. Let the caller replan
				-- instead of pushing against a corner forever.
				return false
			end
		end
		return valid() and not blocked() and arrived(position, radius)
	end
	-- A new path from the same jammed position often repeats the same corner.
	-- Step straight back along the incoming segment first; only do this after
	-- the rig actually moved, and never after a Blocked event (which reports a
	-- new obstacle and must be routed around from where we stand).
	local function backOff(from: Vector3, position: Vector3)
		local incoming = Vector3.new(position.X - from.X, 0, position.Z - from.Z)
		if incoming.Magnitude < 0.1 then
			return
		end
		local current = Vector3.new(root.Position.X, 0, root.Position.Z)
		local candidate = current - incoming.Unit * math.min(BACKOFF_DISTANCE, incoming.Magnitude)
		local destination = Vector3.new(candidate.X, feet(), candidate.Z)
		if stayOnGround and not supported(destination) then
			return
		end
		humanoid:MoveTo(destination)
		local untilTime = math.min(deadline, os.clock() + BACKOFF_SECONDS)
		while valid() and os.clock() < untilTime and flatDistance(root.Position, destination) > 0.6 do
			task.wait(POLL_SECONDS)
		end
	end

	if not valid() then
		stop()
		return false
	end
	if straight then
		-- Known dock centerlines already describe the safe corridor. Never
		-- take a navmesh detour or a sideways recovery step near water.
		local ok = follow(target, ARRIVAL_RADIUS, deadline, function()
			return false
		end)
		stop()
		return valid() and ok
	end


	-- Route across the base's house-local grid. Sample the actual walking
	-- surface for each cell: the yard, ramps and piers are at different heights,
	-- and empty cells over water must never become shortcuts.
	local gridFrame = npc.gridFrame
	if typeof(gridFrame) == "CFrame" then
		local grid = require(game:GetService("ReplicatedStorage").Shared.BaseGrid)
		local startLocal = gridFrame:PointToObjectSpace(root.Position)
		local goalLocal = gridFrame:PointToObjectSpace(target)
		local startColumn = grid.localToExtendedCell(startLocal.X, startLocal.Z)
		local goalColumn = grid.localToExtendedCell(goalLocal.X, goalLocal.Z)
		if startColumn and goalColumn then
			local overlap = OverlapParams.new()
			overlap.FilterType = Enum.RaycastFilterType.Exclude
			overlap.FilterDescendantsInstances = { npc.model }
			overlap.RespectCanCollide = true
			overlap.CollisionGroup = root.CollisionGroup
			-- The path service uses a conservative whole-stud radius, but that
			-- overstates the physical body for grid queries. In particular it
			-- marks customer access points next to counters as inside the counter.
			-- Reserve the actual torso/root footprint plus room for limbs instead.
			local torso = npc.model:FindFirstChild("UpperTorso") or root
			local width = math.max(3, torso.Size.X + 0.5, torso.Size.Z + 0.5, root.Size.X + 0.5, root.Size.Z + 0.5)
			local bodyHeight = math.max(2, math.min(height, 5))
			local bodySize = Vector3.new(width, bodyHeight, width)
			local topY = math.max(feet(), target.Y) + 2.5
			local bottomY = math.min(feet(), target.Y) - 3
			local function point(column: number, row: number): Vector3?
				local x, z = grid.extendedCellToLocal(column, row)
				local horizontal = gridFrame:PointToWorldSpace(Vector3.new(x, 0, z))
				local hit = workspace:Raycast(Vector3.new(horizontal.X, topY, horizontal.Z), Vector3.new(0, bottomY - topY, 0), parameters)
				-- The base house floor is 0.16 studs above HouseFrame, while the
				-- quay and docks are lower. Furniture tops are not walking surfaces.
				if not hit or hit.Material == Enum.Material.Water or hit.Normal.Y < 0.7
					or hit.Position.Y > gridFrame.Position.Y + 0.25 then
					return nil
				end
				return hit.Position
			end
			local function bodyFrame(position: Vector3): CFrame
				-- Leave room below the box for a sloping ramp under its uphill edge.
				return CFrame.new(position + Vector3.new(0, bodyHeight / 2 + 0.85, 0)) * gridFrame.Rotation
			end
			local function clearAt(position: Vector3): boolean
				return #workspace:GetPartBoundsInBox(bodyFrame(position), bodySize, overlap) == 0
			end
			local function clearBetween(from: Vector3, to: Vector3): boolean
				local delta = to - from
				return math.abs(delta.Y) <= 2
					and (delta.Magnitude < 0.05 or workspace:Blockcast(bodyFrame(from), bodySize, delta, parameters) == nil)
					-- Route search samples at one-stud intervals; follow() checks
					-- the actual segment again at half-stud intervals before moving.
					and supportedBetween(from, to, true, 1)
			end
			local function route(): { Vector3 }?
				local queue, previous, points, usable, edges, cost, closed = {}, {}, {}, {}, {}, {}, {}
				local function key(column: number, row: number): number
					return (row - grid.BASE_MIN_ROW) * (grid.BASE_MAX_COLUMN - grid.BASE_MIN_COLUMN + 1) + column - grid.BASE_MIN_COLUMN + 1
				end
				local function isUsable(column: number, row: number): boolean
					if column < grid.BASE_MIN_COLUMN or column > grid.BASE_MAX_COLUMN or row < grid.BASE_MIN_ROW or row > grid.BASE_MAX_ROW then
						return false
					end
					local id = key(column, row)
					if usable[id] == nil then
						points[id] = point(column, row)
						usable[id] = points[id] ~= nil and clearAt(points[id])
					end
					return usable[id]
				end
				-- Multiple nearby entry cells avoid stranding a rig that starts
				-- beside a fixture or was pushed away from a cell center.
				local starts = {}
				for row = grid.BASE_MIN_ROW, grid.BASE_MAX_ROW do
					for column = grid.BASE_MIN_COLUMN, grid.BASE_MAX_COLUMN do
						local x, z = grid.extendedCellToLocal(column, row)
						local distance = (Vector3.new(x - startLocal.X, 0, z - startLocal.Z)).Magnitude
						if distance <= grid.CELL_SIZE * 1.5 and isUsable(column, row) then
							local candidate = points[key(column, row)]
							if clearBetween(Vector3.new(root.Position.X, feet(), root.Position.Z), candidate) then
								table.insert(starts, { column, row, distance })
							end
						end
					end
				end
				table.sort(starts, function(a, b) return a[3] < b[3] end)
				for _, start in starts do
					local id = key(start[1], start[2])
					previous[id] = 0
					cost[id] = start[3] / grid.CELL_SIZE
					table.insert(queue, { start[1], start[2] })
				end
				local finish = nil
				while #queue > 0 do
					-- Favor cells nearer the destination; this avoids scanning the
					-- whole quay for every trip down a narrow pier.
					local best, bestScore = 1, math.huge
					for index, candidate in queue do
						local id = key(candidate[1], candidate[2])
						local score = cost[id] + flatDistance(points[id], target) / grid.CELL_SIZE
						if score < bestScore then best, bestScore = index, score end
					end
					local current = table.remove(queue, best)
					local id = key(current[1], current[2])
					if closed[id] then continue end
					closed[id] = true
					local position = points[id]
					if flatDistance(position, target) <= grid.CELL_SIZE * 1.5 and clearBetween(position, target) then
						finish = id
						break
					end
					for _, step in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
						local column, row = current[1] + step[1], current[2] + step[2]
						local nextId = key(column, row)
						local nextCost = cost[id] + 1
						if not closed[nextId] and (cost[nextId] == nil or nextCost < cost[nextId]) and isUsable(column, row) then
							local edgeKey = math.min(id, nextId) .. ":" .. math.max(id, nextId)
							if edges[edgeKey] == nil then
								edges[edgeKey] = clearBetween(position, points[nextId])
							end
							if edges[edgeKey] then
								previous[nextId] = id
								cost[nextId] = nextCost
								table.insert(queue, { column, row })
							end
						end
					end
				end
				if not finish then return nil end
				local result = { target }
				while finish ~= 0 do
					table.insert(result, 1, points[finish])
					finish = previous[finish]
				end
				-- Consecutive grid cells are planning details, not stopping points.
				-- Skip as many as the actual swept body and continuous floor allow;
				-- retaining turns only where obstacles or dock edges require them.
				local simplified = {}
				local from = Vector3.new(root.Position.X, feet(), root.Position.Z)
				local first = 1
				while first <= #result do
					local last = first
					for candidate = #result, first + 1, -1 do
						local destination = result[candidate]
						if clearBetween(from, destination) and supportedBetween(from, destination, true) then
							last = candidate
							break
						end
					end
					from = result[last]
					table.insert(simplified, from)
					first = last + 1
				end
				return simplified
			end
			for attempt = 1, MAX_ATTEMPTS do
				if not valid() or os.clock() >= deadline then break end
				if arrived(target) then stop() return true end
				local waypoints = route()
				if not waypoints then break end
				local failed = false
				for index, position in waypoints do
					local aim = position
					if index < #waypoints then
						local from = if index == 1 then root.Position else waypoints[index - 1]
						local direction = Vector3.new(position.X - from.X, 0, position.Z - from.Z)
						if direction.Magnitude > 0.1 then
							local ahead = position + direction.Unit * 1.1
							local current = Vector3.new(root.Position.X, feet(), root.Position.Z)
							-- Do not overshoot a corner if doing so makes the following
							-- leg cut across a wall, furniture, or the edge of a pier.
							if clearBetween(current, ahead) and supportedBetween(current, ahead, true)
								and clearBetween(ahead, waypoints[index + 1]) then
								aim = ahead
							end
						end
					end
					local distance = flatDistance(root.Position, aim)
					local moveDeadline = math.min(deadline, os.clock() + math.max(3, distance / math.max(1, humanoid.WalkSpeed) * 2 + 1))
					if not follow(aim, ARRIVAL_RADIUS, moveDeadline, function() return false end) then
						failed = true
						break
					end
				end
				if not failed and valid() and arrived(target) then stop() return true end
				if valid() and os.clock() < deadline then task.wait(0.25 * attempt) end
			end
			-- A tight fixture approach may not reach a whole-cell center even
			-- though the navmesh can reach it. Preserve that route as a fallback.
		end
	end

	for attempt = 1, MAX_ATTEMPTS do
		if not valid() or os.clock() >= deadline then
			break
		end
		if arrived(target) then
			stop()
			return true
		end
		local path = PathfindingService:CreatePath({
			AgentRadius = clearance,
			AgentHeight = math.max(5, math.ceil(height)),
			AgentCanJump = false,
			AgentCanClimb = false,
			WaypointSpacing = 3,
			Costs = { Water = math.huge },
		})
		local ok = pcall(function()
			path:ComputeAsync(root.Position, target)
		end)
		if not valid() then
			path:Destroy()
			stop()
			return false
		end
		local failed: Vector3? = nil
		local failedFrom: Vector3? = nil
		local progressed = false
		local blockedEvent = false
		if ok and path.Status == Enum.PathStatus.Success then
			local waypoints = path:GetWaypoints()
			local nextWaypoint = 2 -- First point is the computed starting position.
			local blocked = false
			local connection = path.Blocked:Connect(function(index)
				if index >= nextWaypoint then
					blocked = true
				end
			end)
			local previous: Vector3? = nil
			for index = 2, #waypoints do
				if not valid() or os.clock() >= deadline then
					break
				end
				nextWaypoint = index
				local position = waypoints[index].Position
				local distance = flatDistance(root.Position, position)
				local moveDeadline =
					math.min(deadline, os.clock() + math.max(3, distance / math.max(1, humanoid.WalkSpeed) * 2 + 1))
				local startPosition = root.Position
				local from = previous or startPosition
				local targetPosition = position
				if index < #waypoints then
					-- MoveTo stops about a stud short. Aim slightly past a
					-- corner so the rig actually rounds it instead of cutting
					-- across the inside of a doorway or wall.
					local direction = Vector3.new(position.X - from.X, 0, position.Z - from.Z)
					if direction.Magnitude >= 0.5 then
						-- The navmesh only guarantees clearance up to the waypoint.
						-- A wall can be immediately beyond a valid turn, so do not
						-- blindly extend the target into it.
						local extension = direction.Unit * CORNER_RADIUS
						local width = math.max(1, clearance * 2 - 0.1)
						local hit = workspace:Blockcast(
							CFrame.new(position + Vector3.new(0, 2.5, 0)),
							Vector3.new(width, 2, width),
							extension,
							parameters
						)
						local distance = if hit then math.max(0, (hit.Distance or 0) - 0.2) else CORNER_RADIUS
						local ahead = position + direction.Unit * math.min(CORNER_RADIUS, distance)
						local candidate = Vector3.new(ahead.X, position.Y, ahead.Z)
						if not stayOnGround or supported(candidate) then
							targetPosition = candidate
						end
					end
				end
				if not follow(targetPosition, ARRIVAL_RADIUS, moveDeadline, function()
					return blocked
				end) then
					failed = position
					failedFrom = from
					progressed = flatDistance(startPosition, root.Position) > 0.5
					blockedEvent = blocked
					break
				end
				previous = position
			end
			connection:Disconnect()
		end
		path:Destroy()
		if valid() and arrived(target) then
			stop()
			return true
		end
		if attempt < MAX_ATTEMPTS and valid() and os.clock() < deadline then
			if failed and progressed and not blockedEvent then
				backOff(failedFrom or failed, failed)
			end
			-- Let moved furniture/navmesh updates and other characters settle.
			task.wait(0.25 * attempt)
		end
	end
	stop()
	return false
end

return NpcNavigation
