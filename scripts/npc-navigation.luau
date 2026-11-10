local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local Vector3 = {}
local vector = {}
function Vector3.new(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z, Magnitude = math.sqrt(x*x + y*y + z*z) }, vector)
end
function vector.__add(a, b) return Vector3.new(a.X+b.X, a.Y+b.Y, a.Z+b.Z) end
function vector.__sub(a, b) return Vector3.new(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end
function vector.__unm(a) return Vector3.new(-a.X, -a.Y, -a.Z) end
function vector.__mul(a, b) return Vector3.new(a.X*b, a.Y*b, a.Z*b) end
function vector.__index(a, key)
	if key == "Unit" then return Vector3.new(a.X/a.Magnitude, a.Y/a.Magnitude, a.Z/a.Magnitude) end
end
Vector3.zero = Vector3.new(0, 0, 0)
local frameMeta = { __mul = function(a, _) return a end }
local CFrame = { new = function(position) return setmetatable({ Position = position }, frameMeta) end }
local OverlapParams = { new = function() return {} end }
local typeof = function(value) return if type(value) == "table" and value.isGridFrame then "CFrame" else type(value) end
local BaseGrid = (function()
	-- BASE_GRID_SOURCE --
end)()
local require = function(_) return BaseGrid end
local gridFrame = {
	isGridFrame = true,
	Position = Vector3.zero,
	Rotation = {},
	PointToObjectSpace = function(_, value) return value end,
	PointToWorldSpace = function(_, value) return value end,
}
local RaycastParams = { new = function() return {} end }
local function ground(x, z, y)
	return Vector3.new(x, y or 0, z or 0)
end
local Enum = { PathStatus = { Success = "Success", NoPath = "NoPath" }, RaycastFilterType = { Exclude = "Exclude" }, Material = { Water = "Water" } }
local now, npc, paths, commands, config, walking, steering, tick, parameters, casts, rays, boxes, idleWalkingTicks
local os = { clock = function() return now end }
local sweepWalls
local function positionAt(point)
	local height = if config.groundHeight then config.groundHeight(point.X, point.Z) else point.Y
	local nextPosition = Vector3.new(point.X, height + 3, point.Z)
	local body = config.body or 3
	if sweepWalls and sweepWalls(npc.root.Position, Vector3.new(body, 4, body), nextPosition - npc.root.Position) then return end
	npc.root.Position = nextPosition
end
local task = {}
function task.wait(seconds)
	now += seconds
	tick += 1
	if config.onWait then config.onWait(tick) end
	if steering and not config.frozen then
		local nextPosition = npc.root.Position + steering * (npc.humanoid.WalkSpeed * seconds)
		positionAt(Vector3.new(nextPosition.X, nextPosition.Y - 3, nextPosition.Z))
	elseif walking and not config.frozen then
		local current = npc.root.Position
		local dx, dz = walking.X - current.X, walking.Z - current.Z
		local distance = math.sqrt(dx*dx + dz*dz)
		-- Roblox's native MoveTo can stop within approximately one stud.
		if distance > 1 then
			local step = math.min(distance, npc.humanoid.WalkSpeed * seconds)
			positionAt(Vector3.new(current.X + dx/distance*step, walking.Y, current.Z + dz/distance*step))
		else
			idleWalkingTicks += 1
		end
	end
end
local workspace = {}
-- Axis-aligned solid walls, expanded by the swept body's footprint. This
-- catches corner cutting instead of assuming every MoveTo is unobstructed.
sweepWalls = function(start, size, direction, shapecast)
	for _, wall in config.walls or {} do
		-- Like Roblox shapecasts, ignore walls the box already overlaps.
		if shapecast and math.abs(start.X - (wall.min.X + wall.max.X) / 2) < (wall.max.X - wall.min.X + size.X) / 2
			and math.abs(start.Z - (wall.min.Z + wall.max.Z) / 2) < (wall.max.Z - wall.min.Z + size.Z) / 2 then
			continue
		end
		local low, high = 0, 1
		for _, axis in { "X", "Z" } do
			local origin, step = start[axis], direction[axis]
			local minimum, maximum = wall.min[axis] - size[axis]/2, wall.max[axis] + size[axis]/2
			if math.abs(step) < 0.001 then
				if origin < minimum or origin > maximum then high = -1 end
			else
				local a, b = (minimum-origin)/step, (maximum-origin)/step
				low, high = math.max(low, math.min(a,b)), math.min(high, math.max(a,b))
			end
		end
		if low <= high then return { Distance = low * direction.Magnitude } end
	end
	return nil
end
function workspace:Blockcast(frame, size, direction, params)
	casts += 1
	check(params.FilterDescendantsInstances[1] == npc.model and params.RespectCanCollide
		and params.CollisionGroup == npc.root.CollisionGroup, "Body queries use the rig's collision rules")
	if config.onCast then return config.onCast(frame, size, direction) end
	return sweepWalls(frame.Position, size, direction, true)
end
function workspace:GetPartBoundsInBox(frame, size, params)
	boxes += 1
	check(params.RespectCanCollide and params.CollisionGroup == npc.root.CollisionGroup, "Grid queries use rig collision rules")
	return if sweepWalls(frame.Position, size, Vector3.zero) then { true } else {}
end
function workspace:Raycast(origin, direction)
	rays += 1
	if config.onRay then return config.onRay(origin, direction) end
	if not config.ground and not config.water then return nil end
	local height = if config.groundHeight then config.groundHeight(origin.X, origin.Z) else 0
	if height > origin.Y or height < origin.Y + direction.Y then return nil end
	return { Position = ground(origin.X, origin.Z, height), Normal = Vector3.new(0, 1, 0), Material = if config.water then Enum.Material.Water else "Concrete" }
end
local service = {}
function service:CreatePath(options)
	parameters = options
	local path = { disconnected = false, destroyed = false }
	table.insert(paths, path)
	function path:ComputeAsync(start, target)
		self.start, self.target = start, target
		if config.onCompute then config.onCompute(#paths) end
		if config.throwCompute then error("Navmesh unavailable") end
		self.Status = if config.noPath then Enum.PathStatus.NoPath else Enum.PathStatus.Success
		self.points = { { Position = ground(start.X, start.Z, start.Y - 3) } }
		for _, point in config.detour or {} do
			table.insert(self.points, { Position = point })
		end
		table.insert(self.points, { Position = config.endpoint or target })
	end
	function path:GetWaypoints() return self.points end
	path.Blocked = { Connect = function(_, callback)
		path.callback = callback
		return { Disconnect = function() path.disconnected = true end }
	end }
	function path:Destroy() self.destroyed = true end
	return path
end
local game = { GetService = function(_, name)
	if name == "ReplicatedStorage" then return { Shared = { BaseGrid = true } } end
	assert(name == "PathfindingService")
	return service
end }
local Navigation = (function()
	-- NAVIGATION_SOURCE --
end)()
local NpcNavigation = Navigation
-- CUSTOMER_WALK_SOURCE --

local function reset(options)
	now, paths, commands, config, walking, steering, tick, casts, rays, boxes, idleWalkingTicks = 0, {}, {}, options or {}, nil, nil, 0, 0, 0, 0, 0
	npc = {
		active = true,
		root = { Parent = true, Position = Vector3.new(0, 3, 0), Size = Vector3.new(2, 2, 1), CollisionGroup = "Default" },
		humanoid = { Parent = true, Health = 100, HipHeight = 2, WalkSpeed = 9 },
		model = { Parent = true, FindFirstChild = function(_, name)
			return if name == "UpperTorso" then { Size = Vector3.new(2, 2, 1) } else nil
		end },
	}
	function npc.humanoid:MoveTo(target)
		table.insert(commands, target)
		walking, steering = target, nil
	end
	function npc.humanoid:Move(direction)
		assert(direction.X == direction.X and direction.Z == direction.Z, "Steering must never contain NaN")
		if config.normalizeMove and direction.Magnitude > 0 then direction = direction.Unit end
		steering, walking = direction, nil
	end
	-- Any attempt to teleport through a wall fails the test immediately.
	function npc.model:PivotTo() error("Navigation must not teleport") end
end
local function clean()
	for _, path in paths do
		check(path.destroyed, "Path objects must be released")
		check(path.callback == nil or path.disconnected, "Blocked listeners must be released")
	end
end

-- The built-in shop's front wall is at z=15 with a seven-stud opening.
-- Exercise the actual customer wrapper through the same approach points used
-- by the visit, including the return trip after the customer starts leaving.
reset({ ground = true, walls = {
	{ min = ground(-23, 14.675), max = ground(-3.5, 15.325) },
	{ min = ground(3.5, 14.675), max = ground(23, 15.325) },
} })
positionAt(ground(0, 24))
check(walk(npc, ground(0, 18.6)) and walk(npc, ground(0, 11)), "Customer enters through the shop doorway")
check(npc.root.Position.Z < 15, "Customer reaches the inside of the shop")
npc.leaving = true
check(walk(npc, ground(0, 18.6)) and walk(npc, ground(0, 24)), "A leaving customer walks back outside")
clean()

reset({ ground = true, onWait = function() npc.leaving = true end })
check(not walk(npc, ground(10), function() return not npc.leaving end), "Customer wrapper forwards cancellation")
check(npc.root.Position.X < 2, "Cancelled customer stops before the destination")
clean()

reset({ detour = { ground(0, 6), ground(8, 6) } })
check(Navigation.walk(npc, ground(8, 0)), "Follow a route around a wall")
check(commands[1].Z >= 6 and commands[2].Z >= 6, "Use intermediate detour points before the destination")
check(parameters.AgentRadius == 2 and parameters.AgentHeight == 5, "R15 fits shop doorways")
check(not parameters.AgentCanJump and parameters.Costs.Water == math.huge, "Avoid jumping counters and swimming off piers")
clean()

reset({ walls = { { min = ground(3, -5), max = ground(5, 4.5) } },
	detour = { ground(0, 6.6), ground(8, 6.6) } })
npc.humanoid.WalkSpeed = 16
check(Navigation.walk(npc, ground(8)), "Porter rounds a tight solid corner without clipping the wall")
check(#paths == 1, "Precise corner arrival avoids repeatedly replanning the same valid route")
clean()

reset({ walls = { { min = ground(-5, 8), max = ground(5, 9) } },
	detour = { ground(0, 6), ground(8, 6) } })
npc.humanoid.WalkSpeed = 16
check(Navigation.walk(npc, ground(8, 6)), "Do not extend a valid corner waypoint into the wall beyond it")
check(#paths == 1 and commands[1].Z <= 6.1, "Wall clearance limits the corner extension before moving")
clean()

reset({ ground = true, walls = { { min = ground(4, -5), max = ground(6, 5) } },
	onCompute = function(attempt)
		if attempt == 2 then config.detour = { ground(npc.root.Position.X, 7), ground(10, 7) } end
	end })
check(Navigation.walk(npc, ground(10)), "Detect a wall absent from the path's Blocked events and take a new route")
check(#paths == 2 and paths[2].start.X < 1,
	"Reposition on clear ground before recomputing a stale route")
check(now < 10, "Wall detection recovers promptly")
clean()

reset({ frozen = true, water = true, onCast = function() return {} end })
check(not Navigation.walk(npc, ground(10)), "Blocked pier route cannot recover into water")
check(npc.root.Position.X == 0 and npc.root.Position.Z == 0, "Water is never a recovery foothold")
clean()

reset({ frozen = true, onCast = function() return {} end })
check(not Navigation.walk(npc, ground(10)), "Blocked route with no ground fails safely")
check(npc.root.Position.X == 0 and npc.root.Position.Z == 0, "Recovery cannot walk across unsupported ground")
clean()

reset({ ground = true, onCast = function(frame, _, direction)
	if frame.Position.X + direction.X > 0 then return {} end
	return nil
end, onWait = function() npc.active = false end })
check(not Navigation.walk(npc, ground(10)) and #paths == 1, "Dismissal cancels a recovery step before another replan")
check(steering == nil and walking == npc.root.Position, "Recovery cancellation stops the rig")
clean()

reset({ groundHeight = function(x) return x * 2.7 / 8 end,
	ground = true,
	onCast = function() return {} end,
	detour = { ground(2, 0, 0.675), ground(4, 0, 1.35), ground(6, 0, 2.025) } })
check(Navigation.walk(npc, ground(8, 0, 2.7), nil, true), "Uphill dock route is not vetoed by a horizontal body sweep")
check(#paths == 1 and npc.root.Position.Y > 5, "NPC actually gains elevation across the ramp")
check(casts > 0, "Corner extensions are checked for walls on the ramp")
clean()

reset({ groundHeight = function(x) return 2.7 - x * 2.7 / 8 end,
	ground = true,
	onCast = function() return {} end,
	detour = { ground(2, 0, 2.025), ground(4, 0, 1.35), ground(6, 0, 0.675) } })
positionAt(ground(0, 0, 2.7))
check(Navigation.walk(npc, ground(8), nil, true), "Porter can also descend the dock ramp")
check(#paths == 1 and npc.root.Position.Y < 4, "Downhill route reaches the lower pier")
clean()

local function floorAt(origin, water)
	return { Position = ground(origin.X, origin.Z), Normal = Vector3.new(0, 1, 0),
		Material = if water then Enum.Material.Water else "Wood" }
end
reset({ ground = true, onWait = function()
	if not config.shoved and npc.root.Position.X > 7.9 then
		config.shoved = true
		npc.root.Position = Vector3.new(12.4, 3, 0)
	end
	check(npc.root.Position.X < 15, "Steering does not run away after passing a pickup waypoint")
end })
npc.humanoid.WalkSpeed = 16
check(Navigation.walk(npc, ground(10), nil, true), "Correct steering after being pushed beyond the finish zone")
check(config.shoved and #paths == 1, "Overshoot finishes the existing segment without backwards recovery loops")
clean()

reset({ ground = true, noPath = true })
npc.humanoid.WalkSpeed = 16
check(Navigation.walk(npc, ground(10), nil, true, true), "Known dock centerline works without the navmesh")
check(#paths == 0 and math.abs(npc.root.Position.Z) < 0.01, "Straight dock walking never takes a lateral navmesh detour")

reset({ ground = true, normalizeMove = true })
npc.humanoid.WalkSpeed = 16
check(Navigation.walk(npc, ground(0.8), nil, true, true), "A normalized Move direction still reaches a nearby waypoint")
check(npc.humanoid.WalkSpeed == 16, "Waypoint arrival restores the worker's original speed")

reset({ ground = true, frozen = true })
check(not Navigation.walk(npc, ground(10), nil, true, true), "Obstructed dock centerline stops promptly")
check(now < 2 and npc.root.Position.X == 0 and npc.root.Position.Z == 0 and #paths == 0,
	"Blocked dock segments do not try sideways recovery near water")
check(npc.humanoid.WalkSpeed == 9, "A failed leg restores the worker's original speed")

for _, speed in { 16, 32 } do
	local function deckHeight(x, z)
		if x >= 13.5 and x <= 20.5 and z >= -43 and z <= 15 then
			return math.max(3.3, 3.2 + 2.7 * math.clamp(z / 8, 0, 1))
		end
		if math.abs(x) <= 13.5 and math.abs(z + 38) <= 2.5 then return 3.3 end
		return nil
	end
	reset({ normalizeMove = true, groundHeight = function(x, z)
		return assert(deckHeight(x, z), "Porter must stay on the actual deck throughout the pickup and return")
	end, onRay = function(origin)
		local y = deckHeight(origin.X, origin.Z)
		if not y or y > origin.Y or y < origin.Y - 4 then return nil end
		return { Position = ground(origin.X, origin.Z, y), Normal = Vector3.new(0, 1, 0), Material = "Wood" }
	end })
	npc.humanoid.WalkSpeed = speed
	positionAt(ground(17, 11, 5.9))
	for _, point in { ground(17, -2, 3.3), ground(17, -38, 3.3), ground(0, -38, 3.3),
		ground(17, -38, 3.3), ground(17, -2, 3.3), ground(17, 11, 5.9) } do
		local reached = Navigation.walk(npc, point, nil, true, true)
		check(reached, string.format("Full dock route at speed %d: target %.1f,%.1f stopped at %.2f,%.2f,%.2f",
			speed, point.X, point.Z, npc.root.Position.X, npc.root.Position.Y, npc.root.Position.Z))
		check(npc.humanoid.WalkSpeed == speed, "Dock leg restores the worker's configured speed")
	end
	check(#paths == 0, "Even the upgraded porter follows the dock centerline through both right-angle turns")
end

reset({ onRay = function(origin) return floorAt(origin, origin.X > 4) end })
npc.humanoid.WalkSpeed = 16
check(not Navigation.walk(npc, ground(10), nil, true, true), "Direct dock route still refuses water")
check(npc.root.Position.X < 4 and #paths == 0, "Unsupported direct route stops without sidestepping")

reset({ onRay = function(origin) return floorAt(origin, origin.X > 4) end })
npc.humanoid.WalkSpeed = 16
check(not Navigation.walk(npc, ground(10), nil, true), "Successful navmesh route into water fails safely")
check(npc.root.Position.X < 4, "Porter stops before entering the water at full staff speed")
clean()

reset({ onRay = function(origin) return floorAt(origin, origin.X > 3 and origin.Z < 4) end,
	onCompute = function(attempt)
		if attempt == 2 then config.detour = { ground(0, 6), ground(10, 6) } end
	end })
npc.humanoid.WalkSpeed = 16
check(Navigation.walk(npc, ground(10, 6), nil, true), "Porter replans a water shortcut around the dock corner")
check(#paths == 2, "Safe detour succeeds after rejecting the unsupported route")
clean()

reset({ onRay = function(origin)
	return if math.abs(origin.Z) > 1 then nil else floorAt(origin, false)
end })
check(not Navigation.walk(npc, ground(10), nil, true), "Body needs deck support on both sides of the route")
check(npc.root.Position.X == 0 and npc.root.Position.Z == 0, "Porter does not enter a ledge narrower than his body")
clean()

reset({ onRay = function(origin)
	return if origin.X > 3 and origin.X < 6 then nil else floorAt(origin, false)
end })
check(not Navigation.walk(npc, ground(10), nil, true), "Unsupported gap is rejected even with dry ground beyond it")
check(npc.root.Position.X < 3, "Porter stops on the supported side of a gap")
clean()

reset({ onRay = function(origin)
	local seam = origin.X % 1.3
	return if seam < 0.055 then nil else floorAt(origin, false)
end })
npc.humanoid.WalkSpeed = 16
check(Navigation.walk(npc, ground(10), nil, true), "Normal plank seams do not stop a safe dock route")
clean()

reset({ onWait = function(t)
	if t == 2 then paths[1].callback(2) end
end })
check(Navigation.walk(npc, ground(10)), "Replan when the route ahead is blocked")
check(#paths == 2 and paths[2].start.X > 0, "Replan from actual progress")
clean()

reset({ onWait = function(t)
	if t == 2 then paths[1].callback(1) end
end })
check(Navigation.walk(npc, ground(10)) and #paths == 1, "Ignore obstacles behind the NPC")
clean()

reset({ frozen = true, onCompute = function(attempt)
	if attempt == 2 then config.frozen = false end
end })
check(Navigation.walk(npc, ground(10)) and #paths == 2, "Recover from a stuck rig even without a Blocked event")
check(now < 8, "Detect stuck rigs before the old eight-second timeout")
clean()

reset({ frozen = true })
check(not Navigation.walk(npc, ground(10)), "Permanently blocked routes fail safely")
check(#paths == 4 and npc.root.Position.X == 0 and now < 35, "Bound retries without teleporting")
clean()

reset({ noPath = true })
check(not Navigation.walk(npc, ground(10)) and #paths == 4, "Retry unavailable navmesh then fail")
check(npc.root.Position.X == 0, "NoPath must not trigger a direct walk through the obstacle")
clean()

reset({ throwCompute = true })
check(not Navigation.walk(npc, ground(10)), "Handle path computation errors")
clean()

reset({ noPath = true, onCompute = function(attempt)
	if attempt == 2 then config.noPath = false end
end })
check(Navigation.walk(npc, ground(10)) and #paths == 2, "Recover after navmesh becomes available")
clean()

reset({ onWait = function(t) if t == 2 then npc.active = false end end })
check(not Navigation.walk(npc, ground(10)), "Cancel promptly when NPC is dismissed")
check(now < 1 and #paths == 1, "Cancellation does not wait for MoveTo timeout")
clean()

reset({ onWait = function(t) if t == 2 then npc.humanoid.Health = 0 end end })
check(not Navigation.walk(npc, ground(10)), "Stop movement after death")
clean()

reset({ onWait = function(t) if t == 2 then npc.model.Parent = nil end end })
check(not Navigation.walk(npc, ground(10)), "Stop after removal from world")
clean()

reset()
local allowed = true
config.onWait = function(t) if t == 2 then allowed = false end end
check(not Navigation.walk(npc, ground(10), function() return allowed end), "Abort a trip when its owner/boat changes")
clean()

reset({ onCompute = function() npc.active = false end })
check(not Navigation.walk(npc, ground(10)), "Revalidate after ComputeAsync yields")
check(#commands == 1 and commands[1] == npc.root.Position, "No new movement after cancellation during path computation")
clean()

reset()
check(Navigation.walk(npc, ground(0)) and #paths == 0, "Already-arrived NPC does not compute another route")

reset({ endpoint = ground(0) })
check(not Navigation.walk(npc, ground(0, 0, 10)), "A point on another floor is not an arrival")
clean()

reset()
check(not Navigation.walk(npc, ground(0, 0, 10)), "Vertically aligned waypoints fail without invalid steering")
clean()

reset()
npc.humanoid.WalkSpeed = 0
check(not Navigation.walk(npc, ground(10)), "An immobilized NPC cannot hang the worker forever")
clean()

reset()
npc.model.FindFirstChild = function(_, name)
	return if name == "UpperTorso" then { Size = Vector3.new(5, 3, 2) }
		else { Position = Vector3.new(0, 7, 0), Size = Vector3.new(2, 2, 2) }
end
check(Navigation.clearance(npc) == 3, "Large body rigs reserve additional clearance")
check(Navigation.walk(npc, ground(10)) and parameters.AgentHeight == 8, "Tall avatars reserve head clearance without counting accessories")
clean()



reset({ ground = true, walls = {
	{ min = ground(1.975, -15.75), max = ground(2.525, -11.25) },
	{ min = ground(1.975, -2.25), max = ground(2.525, 2.25) },
}, noPath = true })
npc.gridFrame = gridFrame
npc.root.Position = Vector3.new(-9, 3, -9)
check(Navigation.walk(npc, ground(13.5, -9)), "Grid route crosses the rear room divider passage")
check(#paths == 0 and npc.root.Position.X > 3.57, "Rear passage is traversed without the navmesh")

-- The grid also connects the shop to the base outside the front doorway.
reset({ ground = true, walls = {
	{ min = ground(-24.75, 15.4), max = ground(-3.765, 16.1) },
	{ min = ground(3.765, 15.4), max = ground(24.75, 16.1) },
} })
npc.gridFrame = gridFrame
npc.root.Position = Vector3.new(0, 3, 11.25)
check(Navigation.walk(npc, ground(0, 18.6)), "NPC exits the grid through the front doorway")
check(Navigation.walk(npc, ground(0, 11.25)), "NPC enters the grid through the front doorway")
check(#paths == 0, "Door transitions stay on the base grid")
clean()

-- Exercise the production grid planner against real-width room openings and
-- dynamic obstacle boxes. Both ends are inside the 11 by 7 house grid.
-- The enclosed lobby's side door spans z=9..13.5; its center (11.25)
-- falls halfway between furniture-grid rows. Include its wooden jambs and
-- the shell so a route cannot escape around the building instead.
local lobbyWalls = {
	{ min = ground(-25.1, -16.1), max = ground(-24.4, 16.1) },
	{ min = ground(24.4, -16.1), max = ground(25.1, 16.1) },
	{ min = ground(-24.75, -16.1), max = ground(24.75, -15.4) },
	{ min = ground(-24.75, 15.4), max = ground(-5.25, 16.1) },
	{ min = ground(5.25, 15.4), max = ground(24.75, 16.1) },
	{ min = ground(-6.75, 6.475), max = ground(6.75, 7.025) },
	{ min = ground(6.475, 6.75), max = ground(7.025, 9) },
	{ min = ground(6.475, 13.5), max = ground(7.025, 15.75) },
	{ min = ground(6.3, 8.86), max = ground(7.2, 9.14) },
	{ min = ground(6.3, 13.36), max = ground(7.2, 13.64) },
	{ min = ground(-7.025, 2.25), max = ground(-6.475, 9) },
	{ min = ground(-7.025, 13.5), max = ground(-6.475, 15.75) },
	{ min = ground(-7.2, 8.86), max = ground(-6.3, 9.14) },
	{ min = ground(-7.2, 13.36), max = ground(-6.3, 13.64) },
	{ min = ground(-24.75, 1.975), max = ground(-6.75, 2.525) },
	{ min = ground(1.975, -15.75), max = ground(2.525, -11.25) },
	{ min = ground(1.975, -2.25), max = ground(2.525, 6.75) },
}
for _, speed in { 9, 16 } do
	for _, start in { ground(13.5, 9), ground(18, 0), ground(9, 13.5) } do
		reset({ ground = true, walls = lobbyWalls, noPath = true })
		npc.gridFrame = gridFrame
		npc.humanoid.WalkSpeed = speed
		positionAt(start)
		check(Navigation.walk(npc, ground(0, 18.6), nil, true), "Porter exits storage through the enclosed lobby doorway")
		check(Navigation.walk(npc, start, nil, true), "Porter returns through the lobby doorway to the rack")
		check(Navigation.walk(npc, ground(-18, 11.25), nil, true), "Porter crosses the lobby's opposite office doorway")
		check(#paths == 0, "Lobby doorway works without navmesh fallback")
		clean()
	end
end

-- The planning box is wider than the rig, so a porter standing in the nook
-- between the lobby door and the front wall already overlaps both walls.
-- Shapecasts skip parts overlapping their start, which once made the straight
-- line to the front door look clear and pinned him in that corner.
for _, start in { ground(8.25, 14.35), ground(7.4, 11.25), ground(13.5, 14.35) } do
	reset({ ground = true, walls = lobbyWalls, noPath = true, body = 2 })
	npc.gridFrame = gridFrame
	npc.humanoid.WalkSpeed = 16
	npc.root.Position = Vector3.new(start.X, 3, start.Z)
	check(not sweepWalls(npc.root.Position, Vector3.new(2, 4, 2), Vector3.zero), "Wall-hugging start position is physically valid")
	check(Navigation.walk(npc, ground(0, 18.6), nil, true),
		string.format("Porter beside the storage walls at %.2f,%.2f still finds the lobby doorway", start.X, start.Z))
	check(#paths == 0, "Wall-hugging porter stays on the grid")
	clean()
end

local blockedLobby = table.clone(lobbyWalls)
table.insert(blockedLobby, { min = ground(6.3, 9), max = ground(7.2, 13.5) })
reset({ ground = true, walls = blockedLobby, noPath = true })
npc.gridFrame = gridFrame
positionAt(ground(13.5, 9))
check(not Navigation.walk(npc, ground(0, 18.6), nil, true), "An obstructed lobby doorway remains impassable")
check(math.abs(npc.root.Position.X) >= 6.3 or npc.root.Position.Z <= 7.025,
	"Refined routing never walks through a wall into the enclosed lobby")
clean()

local roomWalls = {
	{ min = ground(-24.75, 1.925), max = ground(-13, 2.575) },
	{ min = ground(-7, 1.925), max = ground(9, 2.575) },
	{ min = ground(15.5, 1.925), max = ground(24.75, 2.575) },
}
reset({ ground = true, walls = roomWalls, noPath = true })
npc.gridFrame = gridFrame
npc.root.Position = Vector3.new(0, 3, 9)
local kitchenReached = Navigation.walk(npc, ground(-18, -9))
check(kitchenReached, "Grid route passes through the kitchen doorway")
check(#paths == 0 and npc.root.Position.Z < 0, "Indoor route succeeds without the navmesh")

reset({ ground = true, walls = roomWalls, noPath = true })
npc.gridFrame = gridFrame
npc.root.Position = Vector3.new(0, 3, 9)
check(Navigation.walk(npc, ground(18, -9)), "Grid route passes through the storage doorway")
check(#paths == 0 and npc.root.Position.Z < 0, "Storage route stays on the grid")

reset({ ground = true, walls = { { min = ground(2, -2), max = ground(7, 2) } }, noPath = true })
npc.gridFrame = gridFrame
positionAt(ground(-9, 0))
check(Navigation.walk(npc, ground(13.5, 0)), "Grid route goes around a placed obstacle")
check(#paths == 0 and math.abs(npc.root.Position.X - 13.5) < 1.25, "Obstacle detour reaches the target")

reset({ ground = true, noPath = true })
npc.gridFrame = gridFrame
npc.root.Position = Vector3.new(-18, 3, 0)
check(Navigation.walk(npc, ground(18, 0), nil, true), "Cross a clear room")
check(#paths == 0 and #commands <= 2, "A clear grid corridor uses one movement command instead of stopping at every square")

reset({ ground = true, noPath = true, walls = {
	{ min = ground(-4, -6), max = ground(1, 2) },
	{ min = ground(5, -2), max = ground(10, 5) },
	{ min = ground(-14, 7), max = ground(-8, 10) },
} })
npc.gridFrame = gridFrame
npc.root.Position = Vector3.new(-18, 3, 0)
local multipleReached = Navigation.walk(npc, ground(18, 0), nil, true)
check(multipleReached, "Walk around multiple placed furniture obstacles")
check(#paths == 0 and #commands < 8, "Multiple-furniture route stays on the grid without per-cell stops")
check(idleWalkingTicks == 0, "Walking remains continuous through furniture detour turns")

-- The aligned dining extension is entered from the west, along the narrow
-- quay beside the house and through the centered opening in the west wall.
reset({ noPath = true, walls = {
	{ min = ground(-25.1, -15.75), max = ground(-24.4, 15.75) },
	{ min = ground(-25.1, -23.75), max = ground(-24.4, -15.75) },
	{ min = ground(-25.1, -33.75), max = ground(-24.4, -30.25) },
}, onRay = function(origin, direction)
	if math.abs(origin.X) > 29 or origin.Z < -35 or origin.Z > 24 or origin.Y < 0 or origin.Y + direction.Y > 0 then
		return nil
	end
	return { Position = ground(origin.X, origin.Z), Normal = Vector3.new(0, 1, 0), Material = "Concrete" }
end })
npc.gridFrame = gridFrame
npc.root.Position = Vector3.new(-27.1, 3, 12)
check(Navigation.walk(npc, ground(-27.1, -27), nil, true), "Diner follows the quay beside the aligned walls")
check(Navigation.walk(npc, ground(-22.5, -27), nil, true), "Diner crosses the west dining doorway")
check(#paths == 0, "Diner's west-side approach uses the grid")


-- The freezer access point fits a real R15 torso even though a rounded-up
-- navmesh agent radius would incorrectly mark it as inside the freezer.
reset({ ground = true, walls = { { min = ground(-20.8, 2.5), max = ground(-17.2, 11.5) } } })
npc.gridFrame = gridFrame
npc.root.Position = Vector3.new(0, 3, 9)
check(Navigation.walk(npc, ground(-15.6, 7)), "Customer reaches the built-in freezer access point")
check(#paths == 0 and npc.root.Position.X < -14, "Tight access stays on the grid")
clean()

-- House-local geometry for the separated shop: the house has a split 10.5-stud
-- doorway, the shop has a 7.5-stud doorway, and the freezer faces the aisle. The road
-- and forecourt provide continuous support between the two buildings.
local acrossStreetWalls = {
	{ min = ground(-24.75, 15.4), max = ground(-3, 16.1) },
	{ min = ground(7.5, 15.4), max = ground(24.75, 16.1) },
	{ min = ground(1.975, 2.25), max = ground(2.525, 15.75) },
	{ min = ground(-24.75, 64.925), max = ground(-3.75, 65.575) },
	{ min = ground(3.75, 64.925), max = ground(24.75, 65.575) },
	{ min = ground(17.2, 69.5), max = ground(21.7, 78.5) },
}
local function streetHeight(z)
	if z <= 15.75 or z >= 65.25 then return 0.16 end
	if z >= 60.5 then return -0.1 end
	return -0.16
end
reset({ noPath = true, walls = acrossStreetWalls, groundHeight = function(_, z) return streetHeight(z) end, onRay = function(origin, direction)
	-- Floors, base track, ring road and shop forecourt in the route corridor.
	local supported = (math.abs(origin.X) <= 24.75 and origin.Z >= -35 and origin.Z <= 24)
		or (math.abs(origin.X) <= 4.5 and origin.Z >= 24 and origin.Z <= 61)
		or (math.abs(origin.X) <= 26.5 and origin.Z >= 61 and origin.Z <= 83.25)
	local y = streetHeight(origin.Z)
	if not supported or origin.Y < y or origin.Y + direction.Y > y then return nil end
	return { Position = ground(origin.X, origin.Z, y), Normal = Vector3.new(0, 1, 0), Material = "Concrete" }
end })
npc.gridFrame = gridFrame
npc.humanoid.WalkSpeed = 16
positionAt(ground(5, 11))
for _, point in { ground(5, 18.6), ground(0, 62.4), ground(0, 70), ground(15.6, 74) } do
	check(Navigation.walk(npc, point, nil, true), "Porter carries rack fish through both doorways to the across-street freezer")
end
check(npc.root.Position.X > 14 and npc.root.Position.Z > 65.25, "Porter reaches the freezer aisle")
for _, point in { ground(0, 70), ground(0, 62.4), ground(5, 18.6), ground(5, 11) } do
	check(Navigation.walk(npc, point, nil, true), "Porter returns from the shop to collect more fish")
end
check(#paths == 0, "Across-street route stays on supported grid cells")
clean()

reset({ ground = true, walls = { { min = ground(-40, -1), max = ground(40, 1) } }, noPath = true })
npc.gridFrame = gridFrame
npc.root.Position = Vector3.new(0, 3, -9)
check(not Navigation.walk(npc, ground(0, 9)), "Blocked grid cannot route through a wall")
check(npc.root.Position.Z < 0, "Neither grid nor fallback walks through the obstacle")

-- The actual base's right-hand pier is seven studs wide, its crosswalk five,
-- and the gangway rises 2.7 studs over eight studs. Coordinates here are in
-- HouseFrame rather than BoatDockFrame (the latter is 43 studs behind it).
local function baseFloor(x, z)
	if math.abs(x) <= 24 and z >= -35 and z <= 24 then return 0 end
	if x >= 13.5 and x <= 20.5 and z >= -86 and z < -35 then
		return -2.7 + 2.7 * math.clamp((z + 43) / 8, 0, 1)
	end
	if x >= -13.5 and x <= 13.5 and z >= -83.5 and z <= -78.5 then return -2.7 end
	return nil
end
local function dockRay(origin, direction)
	local y = baseFloor(origin.X, origin.Z)
	if not y or y > origin.Y or y < origin.Y + direction.Y then return nil end
	return { Position = ground(origin.X, origin.Z, y), Normal = Vector3.new(0, 1, 0), Material = "Wood" }
end
reset({ noPath = true, onRay = dockRay, groundHeight = function(x, z)
	return assert(baseFloor(x, z), "Grid route stepped off the quay or dock")
end })
npc.gridFrame = gridFrame
positionAt(ground(0, -9))
for _, target in {
	ground(17, -39, -1.35), ground(17, -81, -2.7), ground(0, -81, -2.7),
	ground(17, -81, -2.7), ground(17, -39, -1.35), ground(0, -9),
} do
	check(Navigation.walk(npc, target, nil, true), "Grid route reaches each house-to-dock destination and returns")
end
check(#paths == 0, "House, ramp, pier and crosswalk use the grid without a navmesh")
print(string.format("House-to-dock round trip: %d raycasts, %d blockcasts, %d box queries", rays, casts, boxes))

-- Water and gaps must be rejected even when another dry cell is reachable
-- across them; the width test samples both sides, not just the cell centers.
for _, hazard in { "gap", "water", "narrow" } do
	reset({ noPath = true, onRay = function(origin, direction)
		local inPier = origin.X >= 13.5 and origin.X <= 20.5 and origin.Z >= -86 and origin.Z <= -43
		if hazard == "narrow" then inPier = origin.X >= 17 and origin.X <= 19 end
		if not inPier then return nil end
		if hazard ~= "narrow" and origin.Z < -65 and origin.Z > -69 then
			return if hazard == "water" then { Position = ground(origin.X, origin.Z, -2.7), Normal = Vector3.new(0, 1, 0), Material = Enum.Material.Water } else nil
		end
		if -2.7 > origin.Y or -2.7 < origin.Y + direction.Y then return nil end
		return { Position = ground(origin.X, origin.Z, -2.7), Normal = Vector3.new(0, 1, 0), Material = "Wood" }
	end })
	npc.gridFrame = gridFrame
	npc.root.Position = Vector3.new(18, 0.3, -54)
	check(not Navigation.walk(npc, ground(18, -76, -2.7), nil, true), "Grid rejects dock " .. hazard)
	check(npc.root.Position.Z > -65, "NPC stays on the safe side of the dock " .. hazard)
	clean()
end

-- A surface high above the house floor is furniture, not a grid floor.
reset({ noPath = true, onRay = function(origin, direction)
	local y = if origin.X > 2 and origin.X < 7 then 2 else 0
	if y > origin.Y or y < origin.Y + direction.Y then return nil end
	return { Position = ground(origin.X, origin.Z, y), Normal = Vector3.new(0, 1, 0), Material = "Wood" }
end })
npc.gridFrame = gridFrame
positionAt(ground(-9, 0))
check(not Navigation.walk(npc, ground(13.5, 0), nil, true), "Grid never treats a tall tabletop as walkable floor")
check(npc.root.Position.X < 2, "NPC does not climb onto the tabletop")
clean()

print("NPC navigation: " .. checks .. " route, recovery, cancellation and cleanup checks passed (simulated world).")
