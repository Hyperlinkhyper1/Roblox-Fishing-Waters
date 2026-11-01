-- Cosmetic schools of fish swimming just under the surface around the camera,
-- so the water reads as alive. Client-only: every player sees their own schools
-- and nothing replicates. Species come from the pool the school spawns in, so
-- what swims past is what bites there (commons most of the time).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local FishModels = require(ReplicatedStorage.Shared.FishModels)
local FishSpecies = require(ReplicatedStorage.Shared.FishSpecies)
local Seasons = require(ReplicatedStorage.Shared.Seasons)
local Weather = require(ReplicatedStorage.Shared.Weather)

local AmbientFish = {}
local started = false
local TAU = math.pi * 2
local MAX_SCHOOLS = 6
local SCHOOL_SIZE = NumberRange.new(3, 6)
-- Big species cruise alone instead of in shoals.
local SOLO_KG = 20
local SPAWN_DISTANCE = NumberRange.new(40, 120)
local DESPAWN_DISTANCE = 170
-- School selection is spaced out; models are built or recycled on Heartbeat.
local SPAWN_INTERVAL = 0.6
local MAX_POOLED_FISH = MAX_SCHOOLS * SCHOOL_SIZE.Max
-- From higher up the shallow schools are invisible anyway.
local MAX_CAMERA_HEIGHT = 140
local DEPTH = NumberRange.new(1.5, 5)
local MIN_CLEARANCE = 3 -- studs of water kept beneath a school
local SPEED = NumberRange.new(2.5, 5)
local FLEE_RADIUS = 14
local FLEE_TIME = 1.6
local PROBE_INTERVAL = 0.5
local PROBE_AHEAD = 14
-- Bottom dwellers, shellfish, plants and junk never swim in open water.
local GROUNDED = { "Crab$", "Mussel$", "Sea Cucumber$", "^Shrimp$", "^Kelp$", "^Seaweed$", "^Sea Lettuce$" }

local function between(range: NumberRange, rng: Random): number
	return rng:NextNumber(range.Min, range.Max)
end

local function swims(species): boolean
	if species.DropOnly or not species.Pools or species.Requires then
		return false
	end
	for _, pattern in GROUNDED do
		if string.find(species.Name, pattern) then
			return false
		end
	end
	return true
end

-- Weighted by encounter odds, so a Legendary swimming past stays a rare sight.
local function pickSpecies(pool: string, season: string, rng: Random): string?
	local total, choices = 0, {}
	for id, species in FishSpecies do
		if swims(species) and table.find(species.Pools, pool) and FishModels.has(id) then
			if not species.Seasons or table.find(species.Seasons, season) then
				local weight = 1 / math.max(species.RarityDenominator or 1, 1)
				total += weight
				table.insert(choices, { id = id, weight = weight })
			end
		end
	end
	local roll = rng:NextNumber(0, total)
	for _, choice in choices do
		roll -= choice.weight
		if roll <= 0 then
			return choice.id
		end
	end
	return if #choices > 0 then choices[#choices].id else nil
end

-- Every visible part is welded to one anchored, invisible root, so a frame moves
-- a single part per fish instead of every fin.
local function build(id: string): (Model?, BasePart?)
	local model = FishModels.create(id)
	if not model then
		return nil, nil
	end
	FishModels.scaleCatch(model, FishSpecies[id].AverageKg)
	-- Builders draw the head toward +X around the origin; keep that axis.
	local root = Instance.new("Part")
	root.Name = "SwimRoot"
	root.Size = Vector3.one * 0.2
	root.CFrame = CFrame.new(model:GetPivot().Position)
	root.Transparency = 1
	root.Anchored = true
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = false
			item.Massless = true
			item.CanCollide, item.CanQuery, item.CanTouch = false, false, false
			item.CastShadow = false
			-- Recycled schools must not pile up in SeasonFoliage's tracked parts.
			item:SetAttribute("SeasonExempt", true)
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = root, item
			weld.Parent = root
		end
	end
	root.CanCollide, root.CanQuery, root.CanTouch = false, false, false
	root.Parent = model
	model.PrimaryPart = root
	return model, root
end

function AmbientFish.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local folder = Instance.new("Folder")
	folder.Name = "AmbientFish"
	folder.Parent = workspace
	local rng = Random.new()
	local terrainParams = RaycastParams.new()
	terrainParams.FilterType = Enum.RaycastFilterType.Include
	terrainParams.FilterDescendantsInstances = { workspace.Terrain }

	-- Height of the seabed (or dry land) under a point, or nil outside open water.
	local function floorAt(position: Vector3): number?
		if not Biomes.inOceanBounds(position) then
			return nil
		end
		terrainParams.IgnoreWater = false
		local top = Vector3.new(position.X, Biomes.WaterLevel + 6, position.Z)
		local surface = workspace:Raycast(top, Vector3.new(0, -12, 0), terrainParams)
		if not surface or surface.Material ~= Enum.Material.Water then
			return nil
		end
		terrainParams.IgnoreWater = true
		local bed =
			workspace:Raycast(top, Vector3.new(0, -(Biomes.WaterLevel - Biomes.SeaFloor) - 12, 0), terrainParams)
		return if bed then bed.Position.Y else Biomes.SeaFloor
	end

	local schools = {}
	local retired = {}
	local pool = {}
	local pooledCount = 0
	local function despawn(school)
		for _, fish in school.members do
			table.insert(retired, { id = school.id, model = fish.model, root = fish.root })
		end
		table.remove(schools, table.find(schools, school))
	end

	local function spawn(camera: Vector3)
		local angle = rng:NextNumber(0, TAU)
		local origin = camera + Vector3.new(math.cos(angle), 0, math.sin(angle)) * between(SPAWN_DISTANCE, rng)
		local now = workspace:GetServerTimeNow()
		-- Rough swell sinks storm schools so they never break the surface.
		local depth = between(DEPTH, rng) + Weather.getState(now, origin).waveAmplitude
		local floor = floorAt(origin)
		if not floor or floor > Biomes.WaterLevel - depth - MIN_CLEARANCE then
			return
		end
		local pool = if Weather.inLake(origin) then "MainLake" else "OpenSea"
		local id = pickSpecies(pool, (Seasons.current(now)), rng)
		if not id then
			return
		end
		local species = FishSpecies[id]
		local count = if species.AverageKg >= SOLO_KG then 1 else rng:NextInteger(SCHOOL_SIZE.Min, SCHOOL_SIZE.Max)
		local center = Vector3.new(origin.X, Biomes.WaterLevel - depth, origin.Z)
		local school = {
			id = id,
			remaining = count,
			spacing = math.max(FishModels.catchLength(species.AverageKg, id) * 1.4, 1.5),
			solo = count == 1,
			center = center,
			depth = depth,
			heading = rng:NextNumber(0, TAU),
			turn = 0,
			turnTarget = 0,
			nextTurn = 0,
			nextProbe = 0,
			speed = between(SPEED, rng),
			fleeUntil = 0,
			members = {},
		}
		table.insert(schools, school)
	end

	-- Limit cloning, parenting and disposal to one fish per Heartbeat. A bounded
	-- species-specific pool avoids rebuilding schools as the boat travels.
	RunService.Heartbeat:Connect(function()
		if #retired > 0 then
			debug.profilebegin("AmbientFish/Recycle")
			local fish = table.remove(retired)
			fish.model.Parent = nil
			if pooledCount < MAX_POOLED_FISH then
				local bucket = pool[fish.id]
				if not bucket then
					bucket = {}
					pool[fish.id] = bucket
				end
				table.insert(bucket, fish)
				pooledCount += 1
			else
				fish.model:Destroy()
			end
			debug.profileend()
			return
		end
		for _, school in schools do
			if school.remaining <= 0 then
				continue
			end
			school.remaining -= 1
			debug.profilebegin("AmbientFish/BuildOrReuse")
			local bucket = pool[school.id]
			local fish = if bucket then table.remove(bucket) else nil
			local model, root
			if fish then
				pooledCount -= 1
				model, root = fish.model, fish.root
			else
				model, root = build(school.id)
			end
			if not model or not root then
				school.remaining = 0
				if #school.members == 0 then
					despawn(school)
				end
				debug.profileend()
				return
			end
			local offset = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.3, 0.3), rng:NextNumber(-1, 1))
				* school.spacing
			if school.solo then
				offset = Vector3.zero
			end
			local position = school.center + offset
			root.CFrame = CFrame.new(position)
			model.Parent = folder
			table.insert(school.members, {
				model = model,
				root = root,
				offset = offset,
				position = position,
				direction = Vector3.xAxis,
				phase = rng:NextNumber(0, TAU),
				lag = rng:NextNumber(1.5, 3),
			})
			debug.profileend()
			return
		end
	end)

	local spawnElapsed = SPAWN_INTERVAL
	RunService.RenderStepped:Connect(function(dt: number)
		dt = math.min(dt, 0.1)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		local flat = Vector3.new(eye.X, 0, eye.Z)
		local high = eye.Y - Biomes.WaterLevel > MAX_CAMERA_HEIGHT
		for index = #schools, 1, -1 do
			local school = schools[index]
			local offset = Vector3.new(school.center.X, 0, school.center.Z) - flat
			if high or offset.Magnitude > DESPAWN_DISTANCE then
				despawn(school)
			end
		end
		spawnElapsed += dt
		if not high and #schools < MAX_SCHOOLS and spawnElapsed >= SPAWN_INTERVAL then
			spawnElapsed = 0
			spawn(eye)
		end

		local now = os.clock()
		local character = player.Character
		local body = character and character:FindFirstChild("HumanoidRootPart")
		local threat = if body
				and body:IsA("BasePart")
				and body.Position.Y < Biomes.WaterLevel + 4
			then body.Position
			else nil
		local roots, frames = {}, {}
		for _, school in schools do
			-- Wander with slow, smoothed turns.
			if now >= school.nextTurn then
				school.nextTurn = now + rng:NextNumber(2, 6)
				school.turnTarget = rng:NextNumber(-0.5, 0.5)
			end
			local forward = Vector3.new(math.cos(school.heading), 0, math.sin(school.heading))
			if now >= school.nextProbe then
				school.nextProbe = now + PROBE_INTERVAL
				local floor = floorAt(school.center + forward * PROBE_AHEAD)
				if not floor or floor > school.center.Y - MIN_CLEARANCE then
					-- Shallows, a beach or the map edge ahead: swing round.
					school.turnTarget = if school.turnTarget >= 0 then 1.6 else -1.6
					school.nextTurn = now + 1.5
				end
			end
			local speed = school.speed
			if threat then
				local away = Vector3.new(school.center.X - threat.X, 0, school.center.Z - threat.Z)
				if away.Magnitude < FLEE_RADIUS then
					school.fleeUntil = now + FLEE_TIME
					school.heading = math.atan2(away.Z, away.X)
				end
			end
			if now < school.fleeUntil then
				speed *= 2.6
			end
			school.turn += (school.turnTarget - school.turn) * (1 - math.exp(-dt * 1.5))
			school.heading += school.turn * dt
			forward = Vector3.new(math.cos(school.heading), 0, math.sin(school.heading))
			school.center += forward * speed * dt
			local spin = CFrame.Angles(0, -school.heading, 0)
			for _, fish in school.members do
				local bob = Vector3.yAxis * math.sin(now * 0.8 + fish.phase) * 0.25
				local target = school.center + spin * fish.offset + bob
				local step = target - fish.position
				fish.position += step * (1 - math.exp(-dt * fish.lag))
				local heading = (forward * speed + step * 0.6)
				if heading.Magnitude > 0.05 then
					fish.direction = fish.direction:Lerp(heading.Unit, 1 - math.exp(-dt * 4))
				end
				local direction = Vector3.new(fish.direction.X, fish.direction.Y * 0.3, fish.direction.Z)
				if direction.Magnitude < 0.01 then
					direction = forward
				end
				-- A body yaw at swimming frequency reads as a tail beat at this range.
				local wiggle = math.sin(now * (4 + speed * 1.5) + fish.phase) * 0.16
				table.insert(roots, fish.root)
				table.insert(
					frames,
					CFrame.lookAt(fish.position, fish.position + direction) * CFrame.Angles(0, math.pi / 2 + wiggle, 0)
				)
			end
		end
		if #roots > 0 then
			debug.profilebegin("AmbientFish/Move")
			workspace:BulkMoveTo(roots, frames, Enum.BulkMoveMode.FireCFrameChanged)
			debug.profileend()
		end
	end)
end

return AmbientFish
