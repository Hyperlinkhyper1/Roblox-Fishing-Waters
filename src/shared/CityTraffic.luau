-- Moving traffic on the port city's avenues.
--
-- The server (Map/ModernCity) publishes the avenue network once, as a JSON attribute on the
-- city model: junctions where two avenues cross and the avenue stretches between them. Every
-- client runs its own little traffic simulation on it (client/CityTraffic) and draws only the
-- nearest vehicles, so the server replicates nothing per frame and cars cost no network at
-- all. Cars keep to the left, queue behind each other, slow for corners, stop at red lights
-- and for players in the road, and buses pull in at the bus shelters.
--
-- Signals run one fixed plan from the synchronised server clock, so the lamps the server
-- built (tagged TrafficLamp) show the same colour on every client that the cars obey.
--
-- Pure maths on plain numbers (no Roblox types), so it runs under lute too.
local CityTraffic = {}

CityTraffic.ATTRIBUTE = "TrafficNetwork"
CityTraffic.LAMP_TAG = "TrafficLamp"

---------------------------------------------------------------------------------------------------
-- Signals

-- East-west traffic (axis "x") gets green first, then a short all-red, then north-south.
local GREEN, AMBER, CLEAR = 13, 3, 2
CityTraffic.CYCLE = 2 * (GREEN + AMBER + CLEAR)

-- "g", "a" or "r" for traffic travelling along `axis` at time `t` (server seconds plus the
-- junction's offset).
function CityTraffic.signal(axis: string, t: number): string
	local phase = t % CityTraffic.CYCLE
	if axis == "z" then
		phase = (phase + CityTraffic.CYCLE / 2) % CityTraffic.CYCLE
	end
	if phase < GREEN then
		return "g"
	elseif phase < GREEN + AMBER then
		return "a"
	end
	return "r"
end

-- Neighbouring junctions start their plans a little apart, so the whole city never stops at once.
function CityTraffic.junctionOffset(i: number, j: number): number
	return ((i * 3 + j * 5) % 4) * 4.5
end

---------------------------------------------------------------------------------------------------
-- Vehicles

export type Kind = { name: string, length: number, speed: number, weight: number, stops: boolean }
CityTraffic.KINDS = {
	{ name = "car", length = 13, speed = 42, weight = 70, stops = false },
	{ name = "taxi", length = 13, speed = 40, weight = 12, stops = false },
	{ name = "van", length = 15, speed = 36, weight = 10, stops = false },
	{ name = "bus", length = 30, speed = 30, weight = 8, stops = true },
} :: { Kind }

local GAP = 3.5 -- bumper to bumper when queued
local ACCEL = 12 -- studs/s^2
local DECEL = 16 -- comfortable braking, used to plan stops
local BRAKE = 34 -- hardest braking ever applied
local TURN_SPEED = 15 -- through a corner
local BUS_DWELL = 6 -- seconds at a shelter
local PLAYER_LOOKAHEAD = 70
local PLAYER_HALF_WIDTH = 4.2
CityTraffic.FAR_STEP = 0.25 -- cars nobody is near move in steps this long

---------------------------------------------------------------------------------------------------
-- Network

export type Node = {
	x: number,
	z: number,
	wNS: number, -- width of the avenue running north-south (constant x) through the junction
	wEW: number, -- and of the one running east-west (constant z)
	signal: boolean,
	offset: number,
	outs: { number },
}

export type Lane = {
	index: number,
	from: number,
	to: number,
	axis: string,
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	dx: number,
	dz: number,
	len: number,
	signal: boolean,
	offset: number,
	stops: { number }, -- distances along the lane where a bus's front halts, ascending
}

export type Connector = {
	len: number,
	turn: boolean,
	points: { number }, -- x, z pairs of a polyline through the junction
	lengths: { number }, -- cumulative length at each point
	x0: number,
	z0: number,
	dx0: number,
	dz0: number,
}

export type Network = {
	y: number,
	nodes: { Node },
	lanes: { Lane },
	connectors: { [number]: Connector },
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	length: number,
}

-- How far from a junction's centre a lane along `axis` stops: the far kerb of the crossing
-- avenue, plus the zebra crossing where both avenues are wide enough to have one.
local function stopDistance(node: Node, axis: string): number
	if axis == "x" then
		return node.wNS / 2 + 2
	end
	local zebra = node.wNS >= 22 and node.wEW >= 22
	return node.wEW / 2 + (if zebra then 7.5 else 2)
end

-- Builds lanes from the published table: { o = {x, y, z}, n = {{x, z, wNS, wEW, signal, offset}},
-- e = {{a, b}}, s = {{x, z}} }, positions relative to o. Every edge carries one lane each way.
function CityTraffic.network(data: any): Network
	local ox, oy, oz = data.o[1], data.o[2], data.o[3]
	local nodes: { Node } = {}
	for _, n in data.n do
		table.insert(nodes, {
			x = ox + n[1],
			z = oz + n[2],
			wNS = n[3],
			wEW = n[4],
			signal = n[5] == 1,
			offset = n[6] or 0,
			outs = {},
		})
	end
	local lanes: { Lane } = {}
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	local total = 0
	for _, e in data.e do
		for _, pair in { { e[1], e[2] }, { e[2], e[1] } } do
			local a, b = nodes[pair[1]], nodes[pair[2]]
			local ddx, ddz = b.x - a.x, b.z - a.z
			local distance = math.sqrt(ddx * ddx + ddz * ddz)
			local dx, dz = ddx / distance, ddz / distance
			local axis = if math.abs(dx) > math.abs(dz) then "x" else "z"
			local width = if axis == "x" then a.wEW else a.wNS
			local off = width / 4
			-- Keep left: the left of heading (dx, dz) is (dz, -dx)
			local lx, lz = dz * off, -dx * off
			local s0, s1 = stopDistance(a, axis), stopDistance(b, axis)
			local lane: Lane = {
				index = #lanes + 1,
				from = pair[1],
				to = pair[2],
				axis = axis,
				x0 = a.x + dx * s0 + lx,
				z0 = a.z + dz * s0 + lz,
				x1 = b.x - dx * s1 + lx,
				z1 = b.z - dz * s1 + lz,
				dx = dx,
				dz = dz,
				len = distance - s0 - s1,
				signal = b.signal,
				offset = b.offset,
				stops = {},
			}
			table.insert(lanes, lane)
			table.insert(a.outs, lane.index)
			total += lane.len
			minX, maxX = math.min(minX, a.x, b.x), math.max(maxX, a.x, b.x)
			minZ, maxZ = math.min(minZ, a.z, b.z), math.max(maxZ, a.z, b.z)
		end
	end
	-- Each shelter serves the lane whose kerb it stands on
	for _, stop in data.s or {} do
		local px, pz = ox + stop[1], oz + stop[2]
		local best: Lane?, bestSide = nil, math.huge
		for _, lane in lanes do
			local rx, rz = px - lane.x0, pz - lane.z0
			local along = rx * lane.dx + rz * lane.dz
			local side = rx * lane.dz - rz * lane.dx -- distance to the left of the lane's centre
			if along > 40 and along < lane.len - 20 and side > 0 and side < 14 and side < bestSide then
				best, bestSide = lane, side
			end
		end
		if best then
			table.insert(best.stops, (px - best.x0) * best.dx + (pz - best.z0) * best.dz + 8)
			table.sort(best.stops)
		end
	end
	return {
		y = oy,
		nodes = nodes,
		lanes = lanes,
		connectors = {},
		minX = minX,
		maxX = maxX,
		minZ = minZ,
		maxZ = maxZ,
		length = total,
	}
end

-- The path through a junction from the end of lane `a` to the start of lane `b`: a cubic curve
-- flattened into a short polyline, so positions along it are cheap and evenly spaced.
function CityTraffic.connector(network: Network, a: number, b: number): Connector
	local key = a * 4096 + b
	local cached = network.connectors[key]
	if cached then
		return cached
	end
	local inLane, outLane = network.lanes[a], network.lanes[b]
	local x0, z0, x3, z3 = inLane.x1, inLane.z1, outLane.x0, outLane.z0
	local dot = inLane.dx * outLane.dx + inLane.dz * outLane.dz
	local k1, k2
	local turn = dot < 0.9
	if not turn then
		local span = math.sqrt((x3 - x0) ^ 2 + (z3 - z0) ^ 2)
		k1, k2 = span / 3, span / 3
	elseif dot < -0.9 then
		-- Turning back at a dead end: swing out into the junction and round
		k1, k2 = 11, -11
	else
		local reach = (x3 - x0) * inLane.dx + (z3 - z0) * inLane.dz
		local cx, cz = x0 + inLane.dx * reach, z0 + inLane.dz * reach
		k1 = reach * 0.55
		k2 = math.sqrt((x3 - cx) ^ 2 + (z3 - cz) ^ 2) * 0.55
	end
	local x1, z1 = x0 + inLane.dx * k1, z0 + inLane.dz * k1
	local x2, z2 = x3 - outLane.dx * k2, z3 - outLane.dz * k2
	local points, lengths = {}, {}
	local total = 0
	local px, pz = x0, z0
	local steps = if turn then 8 else 2
	for k = 0, steps do
		local u = k / steps
		local w = 1 - u
		local x = w * w * w * x0 + 3 * w * w * u * x1 + 3 * w * u * u * x2 + u * u * u * x3
		local z = w * w * w * z0 + 3 * w * w * u * z1 + 3 * w * u * u * z2 + u * u * u * z3
		total += math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
		table.insert(points, x)
		table.insert(points, z)
		table.insert(lengths, total)
		px, pz = x, z
	end
	local connector: Connector = {
		len = math.max(total, 0.5),
		turn = turn,
		points = points,
		lengths = lengths,
		x0 = x0,
		z0 = z0,
		dx0 = inLane.dx,
		dz0 = inLane.dz,
	}
	network.connectors[key] = connector
	return connector
end

---------------------------------------------------------------------------------------------------
-- Simulation

export type Car = {
	id: number,
	kind: Kind,
	length: number,
	speed: number, -- this driver's cruising speed
	v: number,
	lane: number,
	s: number, -- distance of the front bumper along the lane; negative while still in the junction
	conn: Connector?, -- the junction path the car came through
	nextLane: number,
	nextConn: Connector,
	stopIndex: number,
	dwell: number,
	braking: boolean,
	near: boolean, -- set by the client: stepped every frame and watches for players
	pending: number,
	tick: number,
}

export type Sim = {
	network: Network,
	cars: { Car },
	queues: { { Car } }, -- per lane, front car first
	obstacles: { number }, -- x, z pairs (players in the road), set by the client
	seed: number,
	tick: number,
}

local function random(sim: Sim): number
	-- Park-Miller: deterministic for a seed, under lute and in Roblox alike
	sim.seed = (sim.seed * 48271) % 2147483647
	return sim.seed / 2147483647
end

-- The lane a car takes after `laneIndex`: mostly straight on, sometimes a turn, and back the
-- way it came only at a dead end.
local function pickNext(sim: Sim, laneIndex: number): (number, Connector)
	local network = sim.network
	local lane = network.lanes[laneIndex]
	local outs = network.nodes[lane.to].outs
	local choices, weights, total = {}, {}, 0
	for _, out in outs do
		local o = network.lanes[out]
		if o.to ~= lane.from then
			local straight = o.dx * lane.dx + o.dz * lane.dz > 0.9
			local weight = if straight then 3 else 1
			table.insert(choices, out)
			table.insert(weights, weight)
			total += weight
		end
	end
	local chosen
	if #choices == 0 then
		for _, out in outs do
			chosen = out
		end
	else
		local roll = random(sim) * total
		for k, out in choices do
			roll -= weights[k]
			chosen = out
			if roll <= 0 then
				break
			end
		end
	end
	return chosen, CityTraffic.connector(network, laneIndex, chosen)
end

local function firstStop(lane: Lane, s: number): number
	for k, stop in lane.stops do
		if stop > s + 1 then
			return k
		end
	end
	return #lane.stops + 1
end

local function pickKind(sim: Sim): Kind
	local total = 0
	for _, kind in CityTraffic.KINDS do
		total += kind.weight
	end
	local roll = random(sim) * total
	for _, kind in CityTraffic.KINDS do
		roll -= kind.weight
		if roll <= 0 then
			return kind
		end
	end
	return CityTraffic.KINDS[1]
end

-- How many vehicles a network carries at a graphics tier (1-3): one per this many studs of
-- lane, so a small grid is not jammed and a big one not empty.
local LANE_STUDS_PER_VEHICLE = { 170, 115, 85 }
CityTraffic.MAX_POPULATION = 160
function CityTraffic.population(network: Network, tier: number): number
	local spacing = LANE_STUDS_PER_VEHICLE[math.clamp(tier, 1, 3)]
	return math.min(CityTraffic.MAX_POPULATION, math.floor(network.length / spacing))
end

-- Scatters `population` vehicles over the network, spaced apart, already moving.
function CityTraffic.newSim(network: Network, population: number, seed: number?): Sim
	local sim: Sim = {
		network = network,
		cars = {},
		queues = {},
		obstacles = {},
		seed = math.max(1, math.floor(seed or 12345) % 2147483646),
		tick = 0,
	}
	for k in network.lanes do
		sim.queues[k] = {}
	end
	if #network.lanes == 0 then
		return sim
	end
	for id = 1, population do
		local kind = pickKind(sim)
		for _ = 1, 10 do
			-- A lane in proportion to its length, then a free spot along it
			local roll = random(sim) * network.length
			local lane = network.lanes[1]
			for _, candidate in network.lanes do
				roll -= candidate.len
				lane = candidate
				if roll <= 0 then
					break
				end
			end
			if lane.len < kind.length + 10 then
				continue
			end
			local s = kind.length + random(sim) * (lane.len - kind.length - 2)
			local queue = sim.queues[lane.index]
			local at = #queue + 1
			local free = true
			for k, other in queue do
				if other.s < s then
					at = math.min(at, k)
				end
				local ahead, behind = if other.s > s then other else nil, if other.s <= s then other else nil
				if ahead and ahead.s - ahead.length - s < GAP + 8 then
					free = false
				elseif behind and s - kind.length - behind.s < GAP + 8 then
					free = false
				end
			end
			if not free then
				continue
			end
			local car: Car = {
				id = id,
				kind = kind,
				length = kind.length,
				speed = kind.speed * (0.88 + random(sim) * 0.24),
				v = kind.speed * 0.6,
				lane = lane.index,
				s = s,
				conn = nil,
				nextLane = 0,
				nextConn = nil :: any,
				stopIndex = firstStop(lane, s),
				dwell = 0,
				braking = false,
				near = false,
				pending = 0,
				tick = 0,
			}
			car.nextLane, car.nextConn = pickNext(sim, lane.index)
			table.insert(queue, at, car)
			table.insert(sim.cars, car)
			break
		end
	end
	return sim
end

-- A point `s` along the car's current lane (negative: back through the junction it came from)
local function pathPoint(network: Network, car: Car, s: number): (number, number)
	local lane = network.lanes[car.lane]
	if s >= 0 then
		return lane.x0 + lane.dx * s, lane.z0 + lane.dz * s
	end
	local conn = car.conn
	if not conn then
		return lane.x0 + lane.dx * s, lane.z0 + lane.dz * s
	end
	local along = s + conn.len
	if along < 0 then
		return conn.x0 + conn.dx0 * along, conn.z0 + conn.dz0 * along
	end
	local lengths, points = conn.lengths, conn.points
	local scale = lengths[#lengths] / conn.len
	along *= scale
	for k = 2, #lengths do
		if lengths[k] >= along or k == #lengths then
			local span = lengths[k] - lengths[k - 1]
			local t = if span > 0 then math.clamp((along - lengths[k - 1]) / span, 0, 1) else 1
			local ax, az = points[k * 2 - 3], points[k * 2 - 2]
			local bx, bz = points[k * 2 - 1], points[k * 2]
			return ax + (bx - ax) * t, az + (bz - az) * t
		end
	end
	return lane.x0, lane.z0
end

-- The car's centre and heading (a unit vector in x, z)
function CityTraffic.pose(sim: Sim, car: Car): (number, number, number, number)
	local fx, fz = pathPoint(sim.network, car, car.s)
	local rx, rz = pathPoint(sim.network, car, car.s - car.length)
	local hx, hz = fx - rx, fz - rz
	local m = math.sqrt(hx * hx + hz * hz)
	if m < 1e-4 then
		local lane = sim.network.lanes[car.lane]
		return fx, fz, lane.dx, lane.dz
	end
	return (fx + rx) / 2, (fz + rz) / 2, hx / m, hz / m
end

local function advance(sim: Sim, car: Car, dt: number, now: number)
	local network = sim.network
	local lane = network.lanes[car.lane]
	local queue = sim.queues[car.lane]
	local index = table.find(queue, car) or 1
	local limit = math.huge -- the front bumper may not pass this
	local leader = queue[index - 1]
	if leader then
		limit = leader.s - leader.length - GAP
	else
		-- First in its lane: watch the back of the queue it is about to join, and the lights
		local nextQueue = sim.queues[car.nextLane]
		local last = nextQueue[#nextQueue]
		if last and last ~= car then
			limit = math.min(limit, lane.len + car.nextConn.len + last.s - last.length - GAP)
		end
		if lane.signal then
			local state = CityTraffic.signal(lane.axis, now + lane.offset)
			local toLine = lane.len - car.s
			if state == "r" or (state == "a" and toLine > car.v * car.v / (2 * BRAKE) + 1) then
				-- Just short of the line: reaching lane.len itself means entering the junction
				limit = math.min(limit, lane.len - 0.05)
			end
		end
	end
	-- Buses call at every shelter along their lane
	if car.kind.stops then
		local stop = lane.stops[car.stopIndex]
		if stop then
			if car.dwell > 0 then
				car.dwell -= dt
				limit = car.s
				if car.dwell <= 0 then
					car.stopIndex += 1
				end
			elseif car.s >= stop - 0.6 and car.v < 0.8 then
				car.dwell = BUS_DWELL
				limit = car.s
			else
				limit = math.min(limit, stop)
			end
		end
	end
	local hx, hz = lane.dx, lane.dz
	-- Players in the road ahead
	if car.near and #sim.obstacles > 0 then
		local fx, fz = pathPoint(network, car, car.s)
		if car.s < 0 then
			local bx, bz = pathPoint(network, car, car.s - 2)
			local m = math.sqrt((fx - bx) ^ 2 + (fz - bz) ^ 2)
			if m > 1e-4 then
				hx, hz = (fx - bx) / m, (fz - bz) / m
			end
		end
		local obstacles = sim.obstacles
		for k = 1, #obstacles, 2 do
			local rx, rz = obstacles[k] - fx, obstacles[k + 1] - fz
			local ahead = rx * hx + rz * hz
			if ahead > -2 and ahead < PLAYER_LOOKAHEAD and math.abs(rx * hz - rz * hx) < PLAYER_HALF_WIDTH then
				limit = math.min(limit, car.s + ahead - 3)
			end
		end
	end

	local target = car.speed
	local gap = limit - car.s
	if gap < math.huge then
		target = math.min(target, math.sqrt(2 * DECEL * math.max(0, gap - 0.4)))
	end
	if car.s < 0 and car.conn and car.conn.turn then
		target = math.min(target, TURN_SPEED)
	elseif car.nextConn.turn then
		-- Ease off for the corner ahead
		local toCorner = math.max(0, lane.len - car.s)
		target = math.min(target, math.sqrt(TURN_SPEED * TURN_SPEED + 2 * DECEL * toCorner))
	end
	local before = car.v
	if car.v < target then
		car.v = math.min(target, car.v + ACCEL * dt)
	else
		car.v = math.max(target, car.v - BRAKE * dt)
	end
	car.braking = car.v < before - 0.01 or car.v < 0.3
	local s = car.s + car.v * dt
	if s > limit then
		s = math.max(car.s, limit)
		car.v = math.min(car.v, (s - car.s) / math.max(dt, 1e-3))
	end
	car.s = s

	-- Through the junction into the next lane
	while car.s >= lane.len and sim.queues[car.lane][1] == car do
		table.remove(sim.queues[car.lane], 1)
		local overflow = car.s - lane.len
		car.conn = car.nextConn
		car.lane = car.nextLane
		lane = network.lanes[car.lane]
		car.s = overflow - car.nextConn.len
		car.stopIndex = 1
		car.dwell = 0
		table.insert(sim.queues[car.lane], car)
		car.nextLane, car.nextConn = pickNext(sim, car.lane)
	end
end

-- Moves every car on by `dt` seconds at server time `now`. Near cars step every call; the rest
-- save up their time and step every FAR_STEP seconds. Each lane is walked front to back, so a
-- car always reacts to where its leader has already moved this tick.
function CityTraffic.step(sim: Sim, dt: number, now: number)
	sim.tick += 1
	local tick = sim.tick
	for _, queue in sim.queues do
		local k = 1
		while k <= #queue do
			local car = queue[k]
			if car.tick ~= tick then
				car.tick = tick
				car.pending += dt
				if car.near or car.pending >= CityTraffic.FAR_STEP then
					advance(sim, car, math.min(car.pending, 0.5), now)
					car.pending = 0
				end
			end
			if queue[k] == car then
				k += 1
			end
		end
	end
end

return CityTraffic
