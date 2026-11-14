-- Traffic and signals in the port city (Shared.CityTraffic holds the rules).
--
-- The server publishes the avenue network once, as an attribute on the city model. This
-- client simulates a fixed population of cars, taxis, vans and double-decker buses on it and
-- draws only the nearest few, so nothing replicates per frame:
--   * The simulation only runs while the camera is near the city. Cars within NEAR_RADIUS
--     step every frame and brake for players in the road; the rest step four times a second.
--   * At most DRAWN_BY_TIER vehicles are drawn (by graphics tier), chosen twice a second
--     from those within DRAW_RADIUS. Vehicles are local, anchored at the root, welded,
--     cars have one box collider, other traffic is non-colliding; all moves go out in one BulkMoveTo, and
--     vehicles past FAR_DRAW move every other frame.
--   * Undrawn vehicles are parked far out of sight in small per-kind pools, never destroyed
--     and re-parented, and only the nearest ones cast shadows.
--   * Head, tail and brake lights are written only when they change.
-- The signal lamps the server built (tagged TrafficLamp) follow the same server-clock plan
-- the cars obey, checked four times a second and written only when a lamp changes.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Traffic = require(ReplicatedStorage.Shared.CityTraffic)
local DayNight = require(ReplicatedStorage.Shared.DayNight)

local CityTrafficClient = {}

local DRAW_RADIUS = 220 -- inside the 256-stud streaming radius, so the road is there
local FAR_DRAW = 200
local NEAR_RADIUS = 650
local SHADOW_RADIUS = 90
local WAKE_MARGIN = 700 -- run while the camera is this close to the network's bounding box
local DRAWN_BY_TIER = { 14, 24, 36 }
local SELECT_INTERVAL = 0.5
local OBSTACLE_INTERVAL = 0.1
local NEW_MODELS_PER_PASS = 1 -- avoid registering a group of vehicles on city arrival
local PARKED = CFrame.new(0, 25000, 0)
local rgb = Color3.fromRGB

local CAR_COLORS = {
	rgb(120, 34, 30), rgb(40, 46, 58), rgb(176, 176, 170), rgb(64, 70, 66), rgb(30, 30, 32), rgb(90, 104, 120),
	rgb(150, 132, 96), rgb(200, 200, 196), rgb(54, 84, 120), rgb(110, 116, 62), rgb(160, 70, 40),
}
local VAN_STRIPES = { rgb(196, 40, 36), rgb(36, 96, 170), rgb(40, 140, 80), rgb(230, 160, 30) }
local HEAD_ON, HEAD_OFF = rgb(255, 244, 214), rgb(214, 214, 206)
local TAIL_ON, TAIL_OFF = rgb(255, 36, 30), rgb(110, 22, 20)
local SIGN_ON, SIGN_OFF = rgb(255, 180, 50), rgb(196, 150, 60)
local LIGHTS_AT = 0.35 -- darkness at which headlights come on

local function profiled<A...>(label: string, callback: (A...) -> ()): (A...) -> ()
	if not debug.profilebegin then
		return callback
	end
	return function(...: A...)
		debug.profilebegin(label)
		callback(...)
		debug.profileend()
	end
end

---------------------------------------------------------------------------------------------------
-- Signal lamps

local LAMP_LIT = { r = rgb(255, 46, 36), a = rgb(255, 176, 40), g = rgb(70, 255, 130) }
local LAMP_DARK = { r = rgb(70, 22, 18), a = rgb(72, 54, 18), g = rgb(18, 58, 32) }

local function startLamps()
	type Lamp = { axis: string, lamp: string, offset: number, lit: boolean }
	local lamps: { [BasePart]: Lamp } = {}
	local function add(instance: Instance)
		if not instance:IsA("BasePart") or lamps[instance] then
			return
		end
		local axis, lamp, offset = instance:GetAttribute("Axis"), instance:GetAttribute("Lamp"), instance:GetAttribute("Offset")
		if type(axis) ~= "string" or type(lamp) ~= "string" or not LAMP_LIT[lamp] then
			return
		end
		-- Built dark, so only a lamp that should be lit needs writing
		lamps[instance] = { axis = axis, lamp = lamp, offset = if type(offset) == "number" then offset else 0, lit = false }
	end
	CollectionService:GetInstanceAddedSignal(Traffic.LAMP_TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Traffic.LAMP_TAG):Connect(function(instance)
		lamps[instance :: BasePart] = nil
	end)
	for _, instance in CollectionService:GetTagged(Traffic.LAMP_TAG) do
		add(instance)
	end
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = workspace:GetServerTimeNow()
			for part, lamp in lamps do
				local lit = Traffic.signal(lamp.axis, now + lamp.offset) == lamp.lamp
				if lit ~= lamp.lit then
					lamp.lit = lit
					part.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
					part.Color = if lit then LAMP_LIT[lamp.lamp] else LAMP_DARK[lamp.lamp]
				end
			end
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- Vehicle models

type Visual = {
	kind: string,
	model: Model,
	root: BasePart,
	rootY: number, -- height of the root's centre above the road
	head: BasePart,
	tail: BasePart,
	sign: BasePart?,
	paint: BasePart?, -- recoloured per assignment
	car: Traffic.Car?,
	headLit: boolean,
	tailLit: boolean,
	shadow: boolean,
	fresh: boolean, -- assigned this pass: moved on the next frame even if far
}

local folder: Folder
local parkedCount = 0

local function newVisual(kind: string): Visual
	parkedCount += 1
	local model = Instance.new("Model")
	model.Name = kind
	local parkedAt = PARKED * CFrame.new(parkedCount * 40, 0, 0)
	local root: BasePart
	local function part(name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material, cylinder: boolean?): BasePart
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if cylinder then
			p.Shape = Enum.PartType.Cylinder
		end
		if root then
			p.Massless = true
			p.Anchored = false
			p.CFrame = root.CFrame * CFrame.new(offset)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = p
			weld.Parent = p
		else
			p.Anchored = true
			p.CFrame = parkedAt
			root = p
		end
		p.Parent = model
		return p
	end
	local wheel = rgb(26, 26, 28)
	local glass = rgb(40, 46, 52)
	local visual: Visual
	if kind == "bus" then
		-- A red double-decker
		local body = part("Body", Vector3.new(7.6, 12.4, 30), Vector3.zero, rgb(176, 30, 28), Enum.Material.SmoothPlastic)
		part("LowerWindows", Vector3.new(7.8, 2.6, 26), Vector3.new(0, -1.4, 1), glass, Enum.Material.Glass)
		part("UpperWindows", Vector3.new(7.8, 2.6, 28.4), Vector3.new(0, 3.4, 0.4), glass, Enum.Material.Glass)
		part("Windscreen", Vector3.new(7, 3, 0.2), Vector3.new(0, -1.8, -15.05), glass, Enum.Material.Glass)
		part("Wheels", Vector3.new(8, 2.6, 2.6), Vector3.new(0, -5.7, -10), wheel, Enum.Material.SmoothPlastic, true)
		part("Wheels", Vector3.new(8, 2.6, 2.6), Vector3.new(0, -5.7, 9), wheel, Enum.Material.SmoothPlastic, true)
		part("Destination", Vector3.new(5, 1.1, 0.2), Vector3.new(0, 5.4, -15.05), SIGN_ON, Enum.Material.Neon)
		local head = part("Headlights", Vector3.new(6.4, 0.7, 0.2), Vector3.new(0, -4.8, -15.05), HEAD_OFF, Enum.Material.SmoothPlastic)
		local tail = part("Taillights", Vector3.new(6.4, 0.7, 0.2), Vector3.new(0, -4.8, 15.05), TAIL_OFF, Enum.Material.SmoothPlastic)
		visual = { kind = kind, model = model, root = body, rootY = 7, head = head, tail = tail } :: any
	elseif kind == "van" then
		local body = part("Body", Vector3.new(6, 5.4, 15), Vector3.zero, rgb(228, 228, 222), Enum.Material.SmoothPlastic)
		local stripe = part("Stripe", Vector3.new(6.1, 0.6, 15.1), Vector3.new(0, -0.4, 0), VAN_STRIPES[1], Enum.Material.SmoothPlastic)
		part("Windscreen", Vector3.new(5.4, 2, 0.2), Vector3.new(0, 1, -7.55), glass, Enum.Material.Glass)
		part("Wheels", Vector3.new(6.4, 2.2, 2.2), Vector3.new(0, -2.3, -5), wheel, Enum.Material.SmoothPlastic, true)
		part("Wheels", Vector3.new(6.4, 2.2, 2.2), Vector3.new(0, -2.3, 5), wheel, Enum.Material.SmoothPlastic, true)
		local head = part("Headlights", Vector3.new(5, 0.6, 0.2), Vector3.new(0, -1.6, -7.55), HEAD_OFF, Enum.Material.SmoothPlastic)
		local tail = part("Taillights", Vector3.new(5, 0.6, 0.2), Vector3.new(0, -1.6, 7.55), TAIL_OFF, Enum.Material.SmoothPlastic)
		visual = { kind = kind, model = model, root = body, rootY = 3.4, head = head, tail = tail, paint = stripe } :: any
	else
		local taxi = kind == "taxi"
		local body = part("Body", Vector3.new(5.6, 2.4, 13), Vector3.zero, if taxi then rgb(24, 24, 26) else CAR_COLORS[1], Enum.Material.SmoothPlastic)
		body.CanCollide = true -- one simple collider; all other parts remain non-colliding
		part("Cabin", Vector3.new(5, if taxi then 2.6 else 2, if taxi then 6.4 else 6.8), Vector3.new(0, if taxi then 2.5 else 2.2, 0.6), glass, Enum.Material.Glass)
		part("Roof", Vector3.new(5, 0.25, if taxi then 6.4 else 6.8), Vector3.new(0, if taxi then 3.85 else 3.25, 0.6), if taxi then rgb(24, 24, 26) else rgb(38, 44, 50), Enum.Material.SmoothPlastic)
		part("Grille", Vector3.new(3.2, 0.45, 0.15), Vector3.new(0, -0.45, -6.55), rgb(35, 36, 38), Enum.Material.SmoothPlastic)
		part("RearPlate", Vector3.new(1.5, 0.45, 0.15), Vector3.new(0, -0.35, 6.55), rgb(210, 210, 190), Enum.Material.SmoothPlastic)
		part("Wheels", Vector3.new(6, 2.2, 2.2), Vector3.new(0, -0.8, -4.2), wheel, Enum.Material.SmoothPlastic, true)
		part("Wheels", Vector3.new(6, 2.2, 2.2), Vector3.new(0, -0.8, 4.2), wheel, Enum.Material.SmoothPlastic, true)
		local head = part("Headlights", Vector3.new(4.8, 0.6, 0.2), Vector3.new(0, 0.3, -6.55), HEAD_OFF, Enum.Material.SmoothPlastic)
		local tail = part("Taillights", Vector3.new(4.8, 0.6, 0.2), Vector3.new(0, 0.3, 6.55), TAIL_OFF, Enum.Material.SmoothPlastic)
		local sign = if taxi then part("TaxiSign", Vector3.new(1.6, 0.5, 0.7), Vector3.new(0, 4.05, 0.6), SIGN_OFF, Enum.Material.SmoothPlastic) else nil
		visual = { kind = kind, model = model, root = body, rootY = 1.9, head = head, tail = tail, sign = sign, paint = if taxi then nil else body } :: any
	end
	visual.headLit = false
	visual.tailLit = false
	visual.shadow = false
	visual.fresh = false
	model.PrimaryPart = visual.root
	model.Parent = folder
	return visual
end

local function setLights(visual: Visual, night: boolean, braking: boolean)
	if visual.headLit ~= night then
		visual.headLit = night
		visual.head.Material = if night then Enum.Material.Neon else Enum.Material.SmoothPlastic
		visual.head.Color = if night then HEAD_ON else HEAD_OFF
		local sign = visual.sign
		if sign then
			sign.Material = visual.head.Material
			sign.Color = if night then SIGN_ON else SIGN_OFF
		end
	end
	local tail = night or braking
	if visual.tailLit ~= tail then
		visual.tailLit = tail
		visual.tail.Material = if tail then Enum.Material.Neon else Enum.Material.SmoothPlastic
		visual.tail.Color = if tail then TAIL_ON else TAIL_OFF
	end
end

---------------------------------------------------------------------------------------------------

local function findCity(): Instance?
	local map = workspace:FindFirstChild("Map")
	return map and map:FindFirstChild("Modern City")
end

function CityTrafficClient.start()
	startLamps()
	folder = Instance.new("Folder")
	folder.Name = "CityTraffic"
	folder.Parent = workspace

	local player = Players.LocalPlayer
	local sim: Traffic.Sim? = nil
	local network: Traffic.Network? = nil
	local source: string? = nil
	local drawn: { [Traffic.Car]: Visual } = {}
	local pools: { [string]: { Visual } } = {}
	local active = false
	local night = false
	local selectTimer, obstacleTimer, wakeTimer, darkTimer = 0, 0, 0, 0
	local frame = 0
	local moveParts: { BasePart } = {}
	local moveFrames: { CFrame } = {}
	local parking: { Visual } = {} -- released this frame; parked unless reassigned first

	-- One BulkMoveTo per frame: drawn vehicles, then any released one nobody took over
	local function flush()
		for _, visual in parking do
			if not visual.car then
				table.insert(moveParts, visual.root)
				table.insert(moveFrames, PARKED)
			end
		end
		table.clear(parking)
		if #moveParts > 0 then
			workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
			table.clear(moveParts)
			table.clear(moveFrames)
		end
	end

	local function tier(): number
		local value = player:GetAttribute("GraphicsTier")
		return if type(value) == "number" then math.clamp(math.floor(value), 1, 3) else 3
	end

	local function release(car: Traffic.Car)
		local visual = drawn[car]
		if not visual then
			return
		end
		drawn[car] = nil
		visual.car = nil
		table.insert(parking, visual)
		if visual.shadow then
			visual.shadow = false
			visual.root.CastShadow = false
		end
		local pool = pools[visual.kind]
		if not pool then
			pool = {}
			pools[visual.kind] = pool
		end
		table.insert(pool, visual)
	end

	local function releaseAll()
		for car in drawn do
			release(car)
		end
	end

	-- (Re)build the simulation whenever the city publishes a network
	local function load(city: Instance)
		local raw = city:GetAttribute(Traffic.ATTRIBUTE)
		if type(raw) ~= "string" or raw == source then
			return
		end
		local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
		if not ok or type(data) ~= "table" or type(data.n) ~= "table" then
			warn("[CityTraffic] Could not read the traffic network")
			return
		end
		releaseAll()
		source = raw
		network = Traffic.network(data)
		sim = Traffic.newSim(network :: Traffic.Network, Traffic.population(network :: Traffic.Network, tier()), #raw)
	end

	task.spawn(function()
		while not source do
			local city = findCity()
			if city then
				load(city)
				city:GetAttributeChangedSignal(Traffic.ATTRIBUTE):Connect(function()
					load(city)
				end)
				-- A rebuilt city replaces the model; look for the new one
				city.AncestryChanged:Wait()
				source = nil
			end
			task.wait(2)
		end
	end)

	local function select(camera: Vector3)
		local current = sim :: Traffic.Sim
		local candidates: { Traffic.Car } = {}
		local distances: { [Traffic.Car]: number } = {}
		for _, car in current.cars do
			local x, z = Traffic.pose(current, car)
			local d = math.sqrt((x - camera.X) ^ 2 + (z - camera.Z) ^ 2)
			car.near = d < NEAR_RADIUS
			if d < DRAW_RADIUS then
				distances[car] = d
				table.insert(candidates, car)
			end
		end
		table.sort(candidates, function(a, b)
			return distances[a] < distances[b]
		end)
		local keep: { [Traffic.Car]: boolean } = {}
		for k = 1, math.min(#candidates, DRAWN_BY_TIER[tier()]) do
			keep[candidates[k]] = true
		end
		for car in drawn do
			if not keep[car] then
				release(car)
			end
		end
		local built = 0
		for car in keep do
			local visual = drawn[car]
			if not visual then
				local pool = pools[car.kind.name]
				visual = pool and table.remove(pool)
				if not visual then
					if built >= NEW_MODELS_PER_PASS then
						continue
					end
					built += 1
					visual = newVisual(car.kind.name)
				end
				local v = visual :: Visual
				v.car = car
				v.fresh = true
				local paint = v.paint
				if paint then
					local colors = if v.kind == "van" then VAN_STRIPES else CAR_COLORS
					paint.Color = colors[car.id % #colors + 1]
				end
				drawn[car] = v
			end
			local v = visual :: Visual
			local shadow = distances[car] < SHADOW_RADIUS
			if v.shadow ~= shadow then
				v.shadow = shadow
				v.root.CastShadow = shadow
			end
		end
	end

	local function obstacles(current: Traffic.Sim)
		local list = current.obstacles
		table.clear(list)
		local net = current.network
		for _, other in Players:GetPlayers() do
			local character = other.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local p = root.Position
				-- Only people standing at street level inside the network's box matter
				if p.X > net.minX - 30 and p.X < net.maxX + 30 and p.Z > net.minZ - 30 and p.Z < net.maxZ + 30 and math.abs(p.Y - net.y) < 12 then
					table.insert(list, p.X)
					table.insert(list, p.Z)
				end
			end
		end
	end

	RunService.Heartbeat:Connect(profiled("CityTraffic", function(dt: number)
		local current = sim
		local camera = workspace.CurrentCamera
		if not current or not camera or not network then
			return
		end
		local net = network :: Traffic.Network
		local position = camera.CFrame.Position
		wakeTimer -= dt
		if wakeTimer <= 0 then
			wakeTimer = 1
			local dx = math.max(net.minX - position.X, 0, position.X - net.maxX)
			local dz = math.max(net.minZ - position.Z, 0, position.Z - net.maxZ)
			local wake = dx * dx + dz * dz < WAKE_MARGIN * WAKE_MARGIN
				and position.Y >= net.y - 15 and not Players.LocalPlayer:GetAttribute("MetroRiding")
			if wake ~= active then
				active = wake
				if not wake then
					releaseAll()
				end
				selectTimer = 0
			end
		end
		if not active then
			flush()
			return
		end
		frame += 1
		dt = math.min(dt, 0.25)
		darkTimer -= dt
		if darkTimer <= 0 then
			darkTimer = 1
			night = DayNight.darkness(DayNight.clockTime()) >= LIGHTS_AT
		end
		obstacleTimer -= dt
		if obstacleTimer <= 0 then
			obstacleTimer = OBSTACLE_INTERVAL
			obstacles(current)
		end
		Traffic.step(current, dt, workspace:GetServerTimeNow())
		selectTimer -= dt
		if selectTimer <= 0 then
			selectTimer = SELECT_INTERVAL
			select(position)
		end
		local y = net.y
		for car, visual in drawn do
			local x, z, hx, hz = Traffic.pose(current, car)
			-- Distant vehicles move every other frame
			local far = (x - position.X) ^ 2 + (z - position.Z) ^ 2 > FAR_DRAW * FAR_DRAW
			if not far or visual.fresh or (frame + car.id) % 2 == 0 then
				visual.fresh = false
				local at = Vector3.new(x, y + visual.rootY, z)
				table.insert(moveParts, visual.root)
				table.insert(moveFrames, CFrame.lookAt(at, at + Vector3.new(hx, 0, hz)))
			end
			setLights(visual, night, car.braking)
		end
		flush()
	end))
end

return CityTrafficClient
