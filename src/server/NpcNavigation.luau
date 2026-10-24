-- Shared server-side navigation for customers and staff. Failed routes are
-- retried from the NPC's actual position; never move a rig through a wall.
local PathfindingService = game:GetService("PathfindingService")

local NpcNavigation = {}
-- Humanoid MoveTo can finish roughly one stud short of its target.
local ARRIVAL_RADIUS = 1.25
local STUCK_SECONDS = 1.5
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

function NpcNavigation.walk(npc, target: Vector3, allowed: (() -> boolean)?): boolean
	local humanoid, root = npc.humanoid, npc.root
	local function valid(): boolean
		return npc.active
			and npc.model.Parent ~= nil
			and root.Parent ~= nil
			and humanoid.Health > 0
			and (allowed == nil or allowed())
	end
	local function arrived(position: Vector3): boolean
		return flatDistance(root.Position, position) <= ARRIVAL_RADIUS
			and math.abs(root.Position.Y - humanoid.HipHeight - root.Size.Y / 2 - position.Y) <= 2
	end
	local function stop()
		if root.Parent and humanoid.Parent then
			humanoid:MoveTo(root.Position)
		end
	end
	local deadline = os.clock() + MAX_WALK_SECONDS
	local head = npc.model:FindFirstChild("Head")
	local feetY = root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
	local height = if head then head.Position.Y + head.Size.Y / 2 - feetY else humanoid.HipHeight + root.Size.Y / 2 + 2
	for attempt = 1, MAX_ATTEMPTS do
		if not valid() or os.clock() >= deadline then
			break
		end
		if arrived(target) then
			stop()
			return true
		end
		local path = PathfindingService:CreatePath({
			AgentRadius = NpcNavigation.clearance(npc),
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
				local bestDistance = flatDistance(root.Position, position)
				local progressAt = os.clock()
				local moveDeadline =
					math.min(deadline, os.clock() + math.max(3, bestDistance / math.max(1, humanoid.WalkSpeed) * 2 + 1))
				humanoid:MoveTo(position)
				while valid() and not blocked and not arrived(position) and os.clock() < moveDeadline do
					local distance = flatDistance(root.Position, position)
					if distance < bestDistance - 0.2 then
						bestDistance, progressAt = distance, os.clock()
					elseif os.clock() - progressAt >= STUCK_SECONDS then
						blocked = true
						break
					end
					task.wait(POLL_SECONDS)
				end
				if not valid() or blocked or not arrived(position) then
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
			-- Let moved furniture/navmesh updates and other characters settle.
			task.wait(0.25 * attempt)
		end
	end
	stop()
	return false
end

return NpcNavigation
