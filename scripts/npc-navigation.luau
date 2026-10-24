local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local Vector3 = {}
function Vector3.new(x, y, z)
	return { X = x, Y = y, Z = z, Magnitude = math.sqrt(x*x + y*y + z*z) }
end
local function ground(x, z, y)
	return Vector3.new(x, y or 0, z or 0)
end
local Enum = { PathStatus = { Success = "Success", NoPath = "NoPath" } }
local now, npc, paths, commands, config, walking, tick, parameters
local os = { clock = function() return now end }
local function positionAt(point)
	npc.root.Position = Vector3.new(point.X, point.Y + 3, point.Z)
end
local task = {}
function task.wait(seconds)
	now += seconds
	tick += 1
	if config.onWait then config.onWait(tick) end
	if walking and not config.frozen then
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
	now, paths, commands, config, walking, tick = 0, {}, {}, options or {}, nil, 0
	npc = {
		active = true,
		root = { Parent = true, Position = Vector3.new(0, 3, 0), Size = Vector3.new(2, 2, 1) },
		humanoid = { Parent = true, Health = 100, HipHeight = 2, WalkSpeed = 9 },
		model = { Parent = true, FindFirstChild = function(_, name)
			return if name == "UpperTorso" then { Size = Vector3.new(2, 2, 1) } else nil
		end },
	}
	function npc.humanoid:MoveTo(target)
		table.insert(commands, target)
		walking = target
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
check(commands[1].Z == 6 and commands[2].Z == 6, "Use intermediate detour points before the destination")
check(parameters.AgentRadius == 2 and parameters.AgentHeight == 5, "R15 fits shop doorways")
check(not parameters.AgentCanJump and parameters.Costs.Water == math.huge, "Avoid jumping counters and swimming off piers")
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
