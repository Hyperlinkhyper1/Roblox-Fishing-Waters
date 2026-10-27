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
local CFrame = { new = function(position) return { Position = position } end }
local RaycastParams = { new = function() return {} end }
local function ground(x, z, y)
	return Vector3.new(x, y or 0, z or 0)
end
local Enum = { PathStatus = { Success = "Success", NoPath = "NoPath" }, RaycastFilterType = { Exclude = "Exclude" }, Material = { Water = "Water" } }
local now, npc, paths, commands, config, walking, steering, tick, parameters, casts
local os = { clock = function() return now end }
local sweepWalls
local function positionAt(point)
	local height = if config.groundHeight then config.groundHeight(point.X, point.Z) else point.Y
	local nextPosition = Vector3.new(point.X, height + 3, point.Z)
	if sweepWalls and sweepWalls(npc.root.Position, Vector3.new(3, 4, 3), nextPosition - npc.root.Position) then return end
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
		end
	end
end
local workspace = {}
-- Axis-aligned solid walls, expanded by the swept body's footprint. This
-- catches corner cutting instead of assuming every MoveTo is unobstructed.
sweepWalls = function(start, size, direction)
	for _, wall in config.walls or {} do
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
	return sweepWalls(frame.Position, size, direction)
end
function workspace:Raycast(origin, direction)
	if config.onRay then return config.onRay(origin) end
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
	assert(name == "PathfindingService")
	return service
end }
local Navigation = (function()
	-- NAVIGATION_SOURCE --
end)()

local function reset(options)
	now, paths, commands, config, walking, steering, tick, casts = 0, {}, {}, options or {}, nil, nil, 0, 0
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
check(casts == 0, "Normal path following relies on progress rather than level recovery probes")
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

print("NPC navigation: " .. checks .. " route, recovery, cancellation and cleanup checks passed (simulated world).")
