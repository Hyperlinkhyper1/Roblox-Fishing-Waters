-- Shared server-side navigation for customers and staff. Failed routes are
-- retried from the NPC's actual position; never move a rig through a wall.
local PathfindingService = game:GetService("PathfindingService")

local NpcNavigation = {}
-- Humanoid MoveTo can finish roughly one stud short of its target.
local ARRIVAL_RADIUS = 1.25
local CORNER_RADIUS = 0.4
local STUCK_SECONDS = 0.8
local POLL_SECONDS = 0.1
local MAX_ATTEMPTS = 4
local MAX_WALK_SECONDS = 35

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

function NpcNavigation.clearance(npc): number
	local torso = npc.model:FindFirstChild("UpperTorso") or npc.root
	return math.max(2, math.ceil(math.max(torso.Size.X, torso.Size.Z, npc.root.Size.Z) / 2))
end

function NpcNavigation.walk(npc, target: Vector3, allowed: (() -> boolean)?, stayOnGround: boolean?): boolean
	local humanoid, root = npc.humanoid, npc.root
	local function valid(): boolean
		return npc.active
			and npc.model.Parent ~= nil
			and root.Parent ~= nil
			and humanoid.Health > 0
			and (allowed == nil or allowed())
	end
	local function arrived(position: Vector3, radius: number?): boolean
		return flatDistance(root.Position, position)
				<= (radius or (if stayOnGround then CORNER_RADIUS else ARRIVAL_RADIUS))
			and math.abs(root.Position.Y - humanoid.HipHeight - root.Size.Y / 2 - position.Y) <= 2
	end
	local function stop()
		if root.Parent and humanoid.Parent then
			humanoid:Move(Vector3.zero)
			humanoid:MoveTo(root.Position)
		end
	end
	local deadline = os.clock() + MAX_WALK_SECONDS
	local head = npc.model:FindFirstChild("Head")
	local feetY = root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
	local height = if head then head.Position.Y + head.Size.Y / 2 - feetY else humanoid.HipHeight + root.Size.Y / 2 + 2
	local clearance = NpcNavigation.clearance(npc)
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = { npc.model }
	parameters.RespectCanCollide = true
	parameters.CollisionGroup = root.CollisionGroup
	local function supportedAhead(position: Vector3): boolean
		if not stayOnGround then
			return true
		end
		local delta = Vector3.new(position.X - root.Position.X, 0, position.Z - root.Position.Z)
		if delta.Magnitude < 0.05 then
			return true
		end
		local forward = delta.Unit
		local side = Vector3.new(-forward.Z, 0, forward.X) * (clearance - 0.5)
		local feet =
			Vector3.new(root.Position.X, root.Position.Y - humanoid.HipHeight - root.Size.Y / 2, root.Position.Z)
		-- Check beyond the next movement tick, across the body's width. A path
		-- can report success across an edge; water costs alone do not prevent it.
		local distance = math.min(delta.Magnitude, humanoid.WalkSpeed * POLL_SECONDS + 0.8)
		local samples = math.max(1, math.ceil(distance / 0.5))
		for sample = 1, samples do
			local point = feet + forward * (distance * sample / samples)
			for _, offset in { Vector3.zero, side, -side } do
				local supported = false
				-- Tiny seams between dock planks must not count as missing deck.
				for _, seam in { 0, 0.12 } do
					local floor = workspace:Raycast(
						point + offset + forward * seam + Vector3.new(0, 2, 0),
						Vector3.new(0, -4, 0),
						parameters
					)
					if floor and floor.Material ~= Enum.Material.Water and floor.Normal.Y >= 0.7 then
						supported = true
						break
					end
				end
				if not supported then
					return false
				end
			end
		end
		return true
	end
	-- Sweep the body above low steps; decorative glass, carried fish and the
	-- rig itself must not hide a solid wall or block a walkable doorway.
	local bodySize = Vector3.new(clearance * 2 - 1, math.max(2, height - 1), clearance * 2 - 1)
	local function obstructed(position: Vector3): boolean
		local delta = Vector3.new(position.X - root.Position.X, 0, position.Z - root.Position.Z)
		if delta.Magnitude < 0.05 then
			return false
		end
		local feet = root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
		local origin = Vector3.new(root.Position.X, feet + 1 + bodySize.Y / 2, root.Position.Z)
		return workspace:Blockcast(CFrame.new(origin), bodySize, delta.Unit * math.min(2, delta.Magnitude), parameters)
			~= nil
	end
	local function follow(
		position: Vector3,
		radius: number,
		moveDeadline: number,
		blocked: () -> boolean,
		checkObstacles: boolean?
	): boolean
		local bestDistance, progressAt = flatDistance(root.Position, position), os.clock()
		if not supportedAhead(position) then
			stop()
			return false
		end
		humanoid:MoveTo(position)
		while valid() and not blocked() and not arrived(position, radius) and os.clock() < moveDeadline do
			-- A horizontal sweep sees rising ramps/steps as walls. Trust the
			-- computed walk surface and actual progress on normal path segments;
			-- only veto the unplanned, level steps used during recovery.
			if not supportedAhead(position) or (checkObstacles and obstructed(position)) then
				break
			end
			local distance = flatDistance(root.Position, position)
			if distance <= radius then
				-- Horizontally aligned but on another floor; there is no valid
				-- walking direction here. Replan instead of normalizing zero.
				break
			end
			if distance < bestDistance - 0.15 then
				bestDistance, progressAt = distance, os.clock()
			elseif os.clock() - progressAt >= STUCK_SECONDS then
				break
			end
			if distance < 2 then
				-- MoveTo stops about one stud early. Finish corners precisely so
				-- the next segment cannot shave across a wall or door jamb.
				local delta = Vector3.new(position.X - root.Position.X, 0, position.Z - root.Position.Z)
				humanoid:Move(delta.Unit * math.min(1, distance / math.max(1, humanoid.WalkSpeed * POLL_SECONDS)))
			end
			task.wait(POLL_SECONDS)
		end
		stop()
		return valid() and not blocked() and arrived(position, radius)
	end
	local function recover(position: Vector3)
		-- A new path from exactly the same jammed position often repeats the
		-- same corner. Walk a short, supported step aside before replanning.
		local delta = Vector3.new(position.X - root.Position.X, 0, position.Z - root.Position.Z)
		if delta.Magnitude < 0.05 then
			return
		end
		local forward = delta.Unit
		local side = Vector3.new(-forward.Z, 0, forward.X)
		local feet = root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
		for _, direction in { -forward, side, -side, (side - forward).Unit, (-side - forward).Unit } do
			if not valid() or os.clock() >= deadline then
				return
			end
			local candidate = Vector3.new(root.Position.X, feet, root.Position.Z) + direction * 2
			local supported = not obstructed(candidate)
			-- Sample the entire step so recovery cannot walk off a pier or
			-- across a gap. Water is never accepted as supporting ground.
			for sample = 1, 4 do
				local point = Vector3.new(root.Position.X, feet, root.Position.Z) + direction * (sample * 0.5)
				local floor = workspace:Raycast(point + Vector3.new(0, 1, 0), Vector3.new(0, -2, 0), parameters)
				if not floor or floor.Material == Enum.Material.Water or floor.Normal.Y < 0.7 then
					supported = false
					break
				end
			end
			if
				supported
				and follow(candidate, CORNER_RADIUS, math.min(deadline, os.clock() + 1.5), function()
					return false
				end, true)
			then
				return
			end
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
			-- Shops and piers have walkable doorways and ramps. Do not climb over
			-- counters, freezers, or railings to take a shortcut.
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
			break
		end
		local failedPosition: Vector3? = nil
		if ok and path.Status == Enum.PathStatus.Success then
			local waypoints = path:GetWaypoints()
			local nextWaypoint = 2 -- First point is the computed starting position.
			local blocked = false
			local connection = path.Blocked:Connect(function(index)
				if index >= nextWaypoint then
					blocked = true
				end
			end)
			for index = 2, #waypoints do
				nextWaypoint = index
				local position = waypoints[index].Position
				local distance = flatDistance(root.Position, position)
				local moveDeadline =
					math.min(deadline, os.clock() + math.max(3, distance / math.max(1, humanoid.WalkSpeed) * 2 + 1))
				local radius = if stayOnGround or index < #waypoints then CORNER_RADIUS else ARRIVAL_RADIUS
				if not follow(position, radius, moveDeadline, function()
					return blocked
				end) then
					failedPosition = position
					break
				end
			end
			connection:Disconnect()
		end
		path:Destroy()
		stop()
		if valid() and arrived(target) then
			return true
		end
		if attempt < MAX_ATTEMPTS and valid() and os.clock() < deadline then
			if failedPosition then
				recover(failedPosition)
			end
			-- Let moved furniture/navmesh updates and other characters settle.
			task.wait(0.25 * attempt)
		end
	end
	stop()
	return false
end

return NpcNavigation
