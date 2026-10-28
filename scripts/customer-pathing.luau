-- Exercise the production waypoint follower against recording engine mocks.
-- This checks routing, retries, cancellation and the no-teleport fallback; it
-- cannot validate the real Roblox navmesh around the base house.
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

local vector = {}
local Vector3 = {}
local function rawVector(x, y, z)
	local result = setmetatable({ X = x, Y = y, Z = z }, vector)
	result.Magnitude = math.sqrt(x * x + y * y + z * z)
	return result
end
function Vector3.new(x, y, z)
	local result = rawVector(x, y, z)
	local magnitude = result.Magnitude
	result.Unit = if magnitude > 0 then rawVector(x / magnitude, y / magnitude, z / magnitude) else rawVector(0, 0, 0)
	return result
end
function vector.__sub(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
function vector.__add(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
function vector.__mul(a, b)
	if type(a) == "number" then
		return Vector3.new(a * b.X, a * b.Y, a * b.Z)
	end
	return Vector3.new(a.X * b, a.Y * b, a.Z * b)
end

local function near(a, b): boolean
	return (a - b).Magnitude < 0.001
end

local clock = 0
local os = { clock = function() return clock end }
local task = {
	wait = function(seconds)
		clock += seconds or 0
	end,
}
local Enum = {
	PathStatus = { Success = "Success", NoPath = "NoPath" },
	PathWaypointAction = { Walk = "Walk", Jump = "Jump" },
	RaycastFilterType = { Exclude = "Exclude" },
}
local RaycastParams = { new = function() return {} end }
local folder = { Name = "ShopCustomers" }
local rayBlocked, pathQueue, computed, groundY = false, {}, {}, 0

local PathfindingService = {}
-- Mirror the documented CreatePath keys; an unknown key can make the real
-- service throw and silently turn every route into the straight-line fallback.
local AGENT_KEYS = {
	AgentRadius = true,
	AgentHeight = true,
	AgentCanJump = true,
	AgentCanClimb = true,
	WaypointSpacing = true,
	Costs = true,
}
function PathfindingService:CreatePath(agent)
	for key in agent do
		assert(AGENT_KEYS[key], "Unknown pathfinding agent parameter: " .. tostring(key))
	end
	assert(agent.AgentRadius == 1.5, "Pathfinding must use the R15 agent radius")
	assert(agent.AgentCanJump == false, "Pathfinding must not jump through shop windows")
	local path = { Status = nil, waypoints = {} }
	function path:ComputeAsync(start, goal)
		table.insert(computed, { start = start, goal = goal })
		local nextPath = table.remove(pathQueue, 1)
		if not nextPath then
			self.Status, self.waypoints = Enum.PathStatus.NoPath, {}
			return
		end
		self.Status, self.waypoints = nextPath.status, nextPath.waypoints or {}
	end
	function path:GetWaypoints()
		return self.waypoints
	end
	return path
end

local workspace = {
	Raycast = function(_, origin, direction)
		if rayBlocked then
			return { Position = Vector3.new(0, 0, 0) }
		end
		-- The fallback also probes downward for the surface under the NPC.
		if direction.Y < 0 then
			return { Position = Vector3.new(origin.X, groundY, origin.Z) }
		end
		return nil
	end,
}

local function waypoint(position, action): any
	return { Position = position, Action = action or Enum.PathWaypointAction.Walk }
end

local function newCustomer(position)
	local root = { Position = position }
	local moves = {}
	local humanoid = {
		Parent = true,
		Health = 100,
		Jump = false,
		MoveTo = function(_, target)
			table.insert(moves, target)
			if not rayBlocked then
				root.Position = target
			end
		end,
		MoveToFinished = { Wait = function() return true end },
	}
	return {
		active = true,
		leaving = false,
		model = { Parent = true },
		root = root,
		humanoid = humanoid,
		moves = moves,
	}
end

-- PATH_CONSTANTS --
-- WALK_SOURCE --

-- A navmesh route must visit the doorway waypoint before the final approach,
-- instead of steering straight at the target from the street.
rayBlocked, pathQueue, computed = false, {
	{
		status = Enum.PathStatus.Success,
		waypoints = {
			waypoint(Vector3.new(0, 0, 20)),
			waypoint(Vector3.new(0, 0, 15)), -- front door
			waypoint(Vector3.new(0, 0, 12.5)), -- path goal, 2.5 short
		},
	},
}, {}
local customer = newCustomer(Vector3.new(0, 0, 20))
local target = Vector3.new(0, 0, 10)
check(walk(customer, target), "A successful path completes the walk")
check(#computed == 1, "One path is computed for a clear route")
check(near(computed[1].start, Vector3.new(0, 0, 20)), "Paths start at the humanoid")
check(near(computed[1].goal, Vector3.new(0, 0, 12.5)), "Paths stop just short of tight fixtures")
check(#customer.moves == 3, "The route skips the start waypoint and visits the rest")
check(near(customer.moves[1], Vector3.new(0, 0, 15)), "The NPC lines up with the doorway first")
check(near(customer.moves[2], Vector3.new(0, 0, 12.5)), "The NPC follows the last navmesh point")
check(near(customer.moves[3], target), "The final approach steers to the target")
check(near(customer.root.Position, target), "The NPC ends at its destination")

-- A stale first path is recomputed from the position where the NPC actually is.
rayBlocked, pathQueue, computed = false, {
	{ status = Enum.PathStatus.NoPath },
	{
		status = Enum.PathStatus.Success,
		waypoints = {
			waypoint(Vector3.new(0, 0, 20)),
			waypoint(Vector3.new(0, 0, 15)),
			waypoint(Vector3.new(0, 0, 12.5)),
		},
	},
}, {}
customer = newCustomer(Vector3.new(0, 0, 20))
check(walk(customer, target), "A failed route gets one recompute")
check(#computed == 2, "The route is computed twice before giving up")
check(near(customer.moves[1], Vector3.new(0, 0, 15)), "The retry still uses the doorway")

-- Open deck targets sit on the platform itself. A fixture offset here would
-- put the goal beyond the pier edge or inside the quay block.
rayBlocked, pathQueue, computed = false, {
	{
		status = Enum.PathStatus.Success,
		waypoints = {
			waypoint(Vector3.new(0, 0, 20)),
			waypoint(Vector3.new(0, 0, 10)),
			waypoint(Vector3.new(0, 0, 5)),
		},
	},
}, {}
customer = newCustomer(Vector3.new(0, 0, 20))
check(walk(customer, Vector3.new(0, 0, 5), 0), "An open deck target completes the walk")
check(near(computed[1].goal, Vector3.new(0, 0, 5)), "Open deck targets pathfind to the exact deck point")

-- Off-navmesh dock tips fall back to a direct walk only when the line is clear.
rayBlocked, pathQueue, computed = false, {
	{ status = Enum.PathStatus.NoPath },
	{ status = Enum.PathStatus.NoPath },
}, {}
customer = newCustomer(Vector3.new(0, 0, 20))
check(walk(customer, target), "A clear straight line rescues an off-navmesh target")
check(#computed == 2, "The fallback happens only after both route attempts")
check(#customer.moves == 1 and near(customer.moves[1], target), "The fallback steers directly")
check(near(customer.root.Position, target), "The direct fallback reaches the target")

-- A blocked NPC must abort the trip, never teleport through a wall.
rayBlocked, pathQueue, computed = true, {
	{ status = Enum.PathStatus.NoPath },
	{ status = Enum.PathStatus.NoPath },
}, {}
customer = newCustomer(Vector3.new(5, 0, 20))
local stuckAt = customer.root.Position
check(not walk(customer, target), "An obstructed straight line aborts the trip")
check(#computed == 2, "Both route attempts run before aborting")
check(#customer.moves == 0, "A blocked NPC is never pushed at the target")
check(near(customer.root.Position, stuckAt), "A blocked NPC never teleports")

-- A single 1.1-stud quay/landing step is climbable in the fallback.
rayBlocked, pathQueue, computed, groundY = false, {
	{ status = Enum.PathStatus.NoPath },
	{ status = Enum.PathStatus.NoPath },
}, {}, 1.1
customer = newCustomer(Vector3.new(0, 0, 20))
check(walk(customer, Vector3.new(0, 1.1, 10)), "A single quay step can be climbed directly")
check(near(customer.root.Position, Vector3.new(0, 1.1, 10)), "The climb reaches the upper deck")

-- A clear line over a taller ledge is not walkable; abort instead of pressing in.
rayBlocked, pathQueue, computed, groundY = false, {
	{ status = Enum.PathStatus.NoPath },
	{ status = Enum.PathStatus.NoPath },
}, {}, 0
customer = newCustomer(Vector3.new(0, 0, 20))
stuckAt = customer.root.Position
check(not walk(customer, Vector3.new(0, 2, 10)), "A ledge above the footing aborts the direct fallback")
check(#customer.moves == 0, "A ledge is never walked into")
check(near(customer.root.Position, stuckAt), "A ledge never teleports the NPC")
groundY = 0

-- Already at an interaction spot: steer the short final leg without pathfinding.
rayBlocked, pathQueue, computed = false, {}, {}
customer = newCustomer(Vector3.new(0, 0, 1))
check(walk(customer, Vector3.new(0, 0, 2.5)), "A short final leg completes directly")
check(#computed == 0, "A nearby target needs no navmesh route")
check(#customer.moves == 1, "The short leg still uses Humanoid:MoveTo")

-- Being beside a ledge is not being on it: the level check stops a false
-- arrival on the 1.1-stud landing while the NPC is still on the pier below.
rayBlocked, pathQueue, computed, groundY = false, {}, {}, 0
customer = newCustomer(Vector3.new(0, 0, 20))
customer.humanoid.MoveTo = function(_, position)
	table.insert(customer.moves, position)
	customer.root.Position = Vector3.new(position.X, 0, position.Z)
end
check(not walk(customer, Vector3.new(0, 1.1, 20.5)), "A below-ledge arrival does not count as reaching the deck")

-- Cancelling mid-step must stop the humanoid and report failure.
rayBlocked, pathQueue, computed = false, {
	{
		status = Enum.PathStatus.Success,
		waypoints = {
			waypoint(Vector3.new(0, 0, 20)),
			waypoint(Vector3.new(0, 0, 15)),
			waypoint(Vector3.new(0, 0, 12.5)),
		},
	},
}, {}
customer = newCustomer(Vector3.new(0, 0, 20))
customer.humanoid.MoveTo = function(_, position)
	table.insert(customer.moves, position)
	if #customer.moves == 1 then
		customer.leaving = true
	end
end
check(not walk(customer, target), "Leaving mid-route cancels the walk")
check(#customer.moves == 2 and near(customer.moves[2], customer.root.Position), "Cancelling stops the humanoid in place")

-- Once shopping is over, the same leaving customer must walk back out.
rayBlocked, pathQueue, computed = false, {
	{
		status = Enum.PathStatus.Success,
		waypoints = {
			waypoint(Vector3.new(0, 0, 20)),
			waypoint(Vector3.new(0, 0, 15)),
			waypoint(Vector3.new(0, 0, 12.5)),
		},
	},
}, {}
customer = newCustomer(Vector3.new(0, 0, 20))
customer.leaving, customer.exiting = true, true
check(walk(customer, target), "A leaving customer still walks out")
check(near(customer.root.Position, target), "The exit walk reaches the street")

print("Customer pathing: " .. checks .. " waypoint, retry, fallback, cancellation and exit checks passed (engine mocks).")
