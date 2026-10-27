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
	local function supported(position: Vector3): boolean
		if not stayOnGround then
			return true
		end
		local from = Vector3.new(root.Position.X, 0, root.Position.Z)
		local to = Vector3.new(position.X, 0, position.Z)
		local delta = to - from
		local distance = delta.Magnitude
		if distance < 0.05 then
			return true
		end
		local forward = delta.Unit
		local side = Vector3.new(-forward.Z, 0, forward.X) * (clearance - 0.5)
		local fromY, toY = feet(), position.Y
		local samples = math.max(1, math.ceil(distance / 0.5))
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
					if floor and floor.Material ~= Enum.Material.Water and floor.Normal.Y >= 0.7 then
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
	local function follow(
		position: Vector3,
		radius: number,
		moveDeadline: number,
		blocked: () -> boolean
	): boolean
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
				local moveDeadline = math.min(
					deadline,
					os.clock() + math.max(3, distance / math.max(1, humanoid.WalkSpeed) * 2 + 1)
				)
				local startPosition = root.Position
				local from = previous or startPosition
				local targetPosition = position
				if index < #waypoints then
					-- MoveTo stops about a stud short. Aim slightly past a
					-- corner so the rig actually rounds it instead of cutting
					-- across the inside of a doorway or wall.
					local direction = Vector3.new(position.X - from.X, 0, position.Z - from.Z)
					if direction.Magnitude >= 0.5 then
						local ahead = position + direction.Unit * CORNER_RADIUS
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
