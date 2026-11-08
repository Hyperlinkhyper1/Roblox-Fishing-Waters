-- Island-wide pedestrians share the actual road/footpath network. Clients
-- interpolate short published trips; only visitors inside shops use physics.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pedestrians = require(ReplicatedStorage.Shared.Pedestrians)
local DayNight = require(ReplicatedStorage.Shared.DayNight)
local Weather = require(ReplicatedStorage.Shared.Weather)
local Grid = require(script.Parent.PedestrianGrid)
local Network = require(script.Parent.PedestrianNetwork)

local Streets = {}
local businesses, registered, people = {}, {}, {}
local folder: Folder
local network
local started, revision, builtRevision = false, 0, -1
local random = Random.new()
local visitors, serial, population = 0, 0, 0
local TICK, PLANS_PER_TICK = 0.25, 3
local CHUNK_CELLS, PASSING_RADIUS = 21, 24
local MIN_WALK_SECONDS = 2

local function owned(shop): boolean
	local id = shop.base:GetAttribute("OwnerUserId")
	return shop.base.Parent ~= nil and type(id) == "number" and id > 0 and Players:GetPlayerByUserId(id) ~= nil
end

local function remove(ped)
	if people[ped] then
		people[ped] = nil
		population -= 1
		ped.config:Destroy()
	end
end

local function publish(ped, cells, now: number, entrance, leaving: boolean?)
	local points = { ped.position.X, ped.position.Y, ped.position.Z }
	local path = Grid.points(network.grid, Grid.smooth(network.grid, cells))
	table.move(path, 1, #path, 4, points)
	if entrance then
		-- Reach the centre of the actual doorway approach, not a cell by a jamb.
		table.insert(points, entrance.world.X)
		table.insert(points, network.grid.height[cells[#cells]])
		table.insert(points, entrance.world.Z)
	end
	local walk = Pedestrians.pathLength(points) / ped.speed
	local dwell = if leaving then Pedestrians.FADE_SECONDS elseif entrance then 0.25 else random:NextNumber(0, 0.6)
	local trip = {
		start = now + 0.1, speed = ped.speed, points = points,
		emerge = ped.emerge, leave = leaving, stop = if leaving then "x" else "p",
		stopSeconds = dwell, bag = ped.bag,
	}
	ped.config:SetAttribute("Trip", Pedestrians.encode(trip))
	ped.emerge, ped.removeAfter = false, leaving
	ped.endsAt = trip.start + walk + dwell
	ped.walked += walk
	ped.cell = cells[#cells]
	local n = #points
	ped.position = Vector3.new(points[n - 2], points[n - 1], points[n])
	if n >= 6 then ped.yaw = Pedestrians.flatAngle(points[n - 2] - points[n - 5], points[n] - points[n - 3]) or ped.yaw end
end

local function destination(ped): number?
	local component = network.components[network.componentOf[ped.cell]]
	if not component then return nil end
	local best, distance = nil, -1
	-- Some long journeys pass another open business. The passing roll still
	-- decides whether to enter, and all travel stays on the public network.
	if random:NextNumber() < 0.35 then
		for _, shop in businesses do
			if shop.street and owned(shop) and shop.interest() > 0
				and network.componentOf[shop.street] == network.componentOf[ped.cell] then
				local d = (Network.point(network, shop.street) - ped.position).Magnitude
				if d > 180 and random:NextNumber() < 0.5 then return shop.street end
			end
		end
	end
	for _ = 1, 32 do
		local cell = component[random:NextInteger(1, #component)]
		local d = (Network.point(network, cell) - ped.position).Magnitude
		if not table.find(ped.history, cell) and d > distance then best, distance = cell, d end
		if distance >= 200 then break end
	end
	return best
end

local function plan(ped, now: number)
	if ped.retiring then
		publish(ped, {ped.cell}, now, nil, true)
		return
	end
	if not ped.route then
		local target = ped.destination or destination(ped)
		local route = target and Grid.findPath(network.grid, ped.cell, target)
		if not route then ped.endsAt = now + 3; ped.destination = nil; return end
		ped.route, ped.routeIndex, ped.destination = route, 1, target
	end
	local route, first = ped.route, ped.routeIndex
	-- The first leg is short enough that a walker can notice a nearby shop
	-- after appearing on the street, before a long journey carries it past.
	local chunk = if ped.walked < MIN_WALK_SECONDS then 4 else CHUNK_CELLS
	local last = math.min(#route, first + chunk)
	ped.pending = nil
	if ped.walked >= MIN_WALK_SECONDS and now >= ped.nextShop and visitors < Pedestrians.MAX_VISITORS then
		for i = first, last do
			local p = Network.point(network, route[i])
			for _, shop in businesses do
				if shop.cell and owned(shop) and now >= (ped.tried[shop] or 0)
					and (p - shop.streetWorld).Magnitude <= PASSING_RADIUS then
					local interest = shop.interest()
					if interest > 0 then
						ped.tried[shop] = now + 90
						if random:NextNumber() < interest then
							local detour = Grid.findPath(network.grid, route[i], shop.cell)
							if detour then
								local cells = table.move(route, first, i, 1, {})
								table.move(detour, 2, #detour, #cells + 1, cells)
								ped.pending, ped.route = shop, nil
								publish(ped, cells, now, shop)
								return
							end
						end
					end
				end
			end
		end
	end
	local cells = table.move(route, first, last, 1, {})
	ped.routeIndex = last
	if last == #route then
		table.insert(ped.history, ped.destination)
		if #ped.history > 3 then table.remove(ped.history, 1) end
		ped.route, ped.destination = nil, nil
	end
	publish(ped, cells, now)
end

local function offer(ped, now: number): boolean
	local shop = ped.pending
	ped.pending = nil
	if not shop or ped.retiring or not owned(shop) or visitors >= Pedestrians.MAX_VISITORS then return false end
	local avatars = ReplicatedStorage:FindFirstChild(Pedestrians.AVATAR_FOLDER)
	if not avatars or not avatars:FindFirstChild(tostring(Pedestrians.avatarSlot(ped.look))) then return false end
	local ownerId = shop.base:GetAttribute("OwnerUserId")
	local guest = { id = ped.config.Name, look = ped.look, position = ped.position, speed = ped.speed, yaw = ped.yaw or 0 }
	local released, begun = false, false
	function guest.valid(): boolean
		return not released and people[ped] ~= nil and owned(shop) and shop.base:GetAttribute("OwnerUserId") == ownerId
	end
	function guest.begin(model: Model): boolean
		if not guest.valid() then return false end
		begun = true
		model:SetAttribute("PedestrianId", guest.id)
		ped.config:SetAttribute("InShop", true)
		return true
	end
	function guest.finish(position: Vector3?, bought: boolean?)
		if released then return end
		released, ped.guest = true, nil
		visitors -= 1
		if not people[ped] then return end
		local cell = position and Grid.nearest(network.grid, position.X, position.Z, 6)
		if cell and math.abs(position.Y - network.grid.height[cell]) > 2.5 then cell = nil end
		if begun and not cell then remove(ped); return end
		ped.cell, ped.position = cell or ped.cell, position or guest.position
		ped.bag = if bought then 3 else ped.bag
		ped.nextShop = workspace:GetServerTimeNow() + 45
		ped.route = nil
		plan(ped, workspace:GetServerTimeNow())
		ped.config:SetAttribute("InShop", false)
	end
	ped.guest, ped.nextShop = guest, now + 12
	visitors += 1
	local ok, accepted = pcall(shop.visit, guest)
	if not ok then warn("[Pedestrians] Visit: " .. tostring(accepted)) end
	if not ok or not accepted then guest.finish(nil) end
	return true
end

local function spawn(now: number)
	serial += 1
	local cell = network.cells[random:NextInteger(1, #network.cells)]
	-- Seed some walkers near occupied shops, then send them on long journeys.
	local shops = {}
	for _, shop in businesses do if shop.street and owned(shop) then table.insert(shops, shop) end end
	if #shops > 0 and serial <= #shops * 8 then
		local shop = shops[(serial - 1) % #shops + 1]
		local nearby = {}
		for _, at in network.cells do
			local d = (Network.point(network, at) - shop.streetWorld).Magnitude
			if d >= 8 and d <= 35 then table.insert(nearby, at) end
		end
		if #nearby > 0 then cell = nearby[random:NextInteger(1, #nearby)] end
	end
	local config = Instance.new("Configuration")
	config.Name = "Walker" .. serial
	local ped = {
		config = config, look = random:NextInteger(1, 2^30), cell = cell,
		position = Network.point(network, cell), speed = random:NextNumber(4.4, 5.8),
		walked = 0, bag = 0, emerge = true, endsAt = now, nextShop = now + MIN_WALK_SECONDS,
		history = {}, tried = {},
	}
	config:SetAttribute("Look", ped.look)
	people[ped], population = true, population + 1
	plan(ped, now)
	config.Parent = folder
end

local function build(): boolean
	local map = workspace:FindFirstChild("Map")
	if not map then return false end
	local savedRevision = revision
	local nextNetwork = Network.build(map, businesses)
	if not nextNetwork or #nextNetwork.cells == 0 then return false end
	network, builtRevision = nextNetwork, savedRevision
	for _, shop in businesses do
		shop.world = shop.frame:PointToWorldSpace(shop.position)
		shop.cell = Grid.nearest(network.grid, shop.world.X, shop.world.Z, 6)
		local road = shop.frame:PointToWorldSpace(Vector3.new(shop.position.X, 0, math.min(shop.position.Z, 52)))
		shop.street = Grid.nearest(network.grid, road.X, road.Z, 12)
		shop.streetWorld = if shop.street then Network.point(network, shop.street) else shop.world
		shop.base:SetAttribute("Pedestrian" .. shop.key .. "Reachable", shop.cell ~= nil and shop.street ~= nil
			and network.componentOf[shop.cell] == network.componentOf[shop.street])
	end
	for ped in people do
		if not ped.guest then
			local cell = Grid.nearest(network.grid, ped.position.X, ped.position.Z, 6)
			if cell then ped.cell, ped.route = cell, nil else remove(ped) end
		end
	end
	folder:SetAttribute("WalkableCells", #network.cells)
	folder:SetAttribute("RouteComponents", #network.components)
	folder:SetAttribute("Ready", true)
	return true
end

function Streets.register(base: Model, frame: CFrame, key: string, position: Vector3, visit, interest)
	registered[base] = registered[base] or {}
	local shop = registered[base][key]
	if not shop then
		shop = { base = base, key = key }
		registered[base][key] = shop
		table.insert(businesses, shop)
	end
	shop.frame, shop.position, shop.visit, shop.interest = frame, position, visit, interest
	revision += 1
end

function Streets.start(sharedFolder: Folder)
	if started then return end
	started, folder = true, sharedFolder
	task.spawn(function()
		while not ReplicatedStorage:GetAttribute("FishingWatersGenerationComplete") do task.wait(1) end
		local nextBuild, nextCensus, wanted = 0, 0, 0
		while true do
			task.wait(TICK)
			local now = workspace:GetServerTimeNow()
			if builtRevision ~= revision and now >= nextBuild then
				nextBuild = now + 15
				local ok, result = pcall(build)
				if not ok then warn("[Pedestrians] Road network: " .. tostring(result)) end
				if not ok or not result then continue end
			end
			if not network then continue end
			if now >= nextCensus then
				nextCensus = now + 3
				local owners, seen = 0, {}
				for _, shop in businesses do
					if owned(shop) and not seen[shop.base] then owners += 1; seen[shop.base] = true end
				end
				local p = Network.point(network, network.cells[1])
				local ok, weather = pcall(Weather.getState, now, p)
				wanted = Pedestrians.islandPopulation(DayNight.clockTime(now), if ok and weather then weather.rain or 0 else 0, owners)
				folder:SetAttribute("Wanted", wanted)
			end
			local outside, retiring, planned = 0, 0, 0
			for ped in people do
				if not ped.guest then
					outside += 1
					if ped.retiring then retiring += 1 end
					if now >= ped.endsAt and planned < PLANS_PER_TICK then
						planned += 1
						if ped.removeAfter then remove(ped) elseif not offer(ped, now) then plan(ped, now) end
					end
				end
			end
			if outside - retiring > wanted then
				for ped in people do if not ped.guest and not ped.retiring then ped.retiring = true; break end end
			elseif outside < wanted and planned < PLANS_PER_TICK then
				spawn(now)
			end
			folder:SetAttribute("Population", population)
			folder:SetAttribute("Visitors", visitors)
		end
	end)
end

return Streets

