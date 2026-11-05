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
local MAX_SCHOOLS = 8
local SCHOOL_SIZE = NumberRange.new(3, 5)
-- Big species cruise alone instead of in shoals.
local SOLO_KG = 20
local SPAWN_DISTANCE = NumberRange.new(40, 120)
local DESPAWN_DISTANCE = 170
-- Schools keep at least this far apart (flat studs), and a spawn tries this
-- many spots before waiting for the next interval.
local SCHOOL_GAP = 35
local SPAWN_TRIES = 6
-- School selection is spaced out; models are built or recycled on Heartbeat.
local SPAWN_INTERVAL = 0.6
local MODEL_INTERVAL = 0.12
local MAX_POOLED_FISH = MAX_SCHOOLS * SCHOOL_SIZE.Max
-- From higher up the shallow schools are invisible anyway.
local MAX_CAMERA_HEIGHT = 140
-- Moving welded fish is the costly part, so schools nobody can see skip their
-- move: those behind the camera every frame, distant ones on most frames.
local NEAR_DISTANCE = 60
local FAR_STRIDE = 3
local BEHIND_DOT = 0.15
-- Depth of a fish's top below the calm surface; body size and swell add to it.
-- Shallower schools read as sitting on the water when seen from above.
local DEPTH = NumberRange.new(5, 8.5)
local SWELL_MARGIN = 1.5 -- wave crests rise this many amplitudes above the calm level
-- Water kept above the highest point of every model (dorsal fins, sails).
local SURFACE_CLEARANCE = 1.5
local MIN_CLEARANCE = 3 -- studs of water kept beneath a school
-- Studs per second, the same for every fish in a school. Slow, but quick enough
-- to read as swimming: at 0.1 the schools looked parked.
local SPEED = 0.8
-- Radians per second. Schools hold one straight heading and only turn to
-- avoid shallows. The formation does not spin with its heading, so a shore
-- turn only re-aims the fish instead of swinging them round the school.
local WANDER_TURN = 0
local SHORE_TURN = 0.15
local BOB_HEIGHT, BOB_RATE = 0.06, 0.4
local TAIL_SWING, TAIL_RATE = 0.05, 2
local PROBE_INTERVAL = 0.5
local PROBE_AHEAD = 14
-- Bottom dwellers, shellfish, plants and junk never swim in open water.
-- Junk is matched by name too: some (the Tire) are catchable lake commons.
local GROUNDED = {
	"Crab$",
	"Mussel$",
	"Sea Cucumber$",
	"^Shrimp$",
	"^Kelp$",
	"^Seaweed$",
	"^Sea Lettuce$",
	"Tire$",
	"Boot$",
	"Branch$",
}

local function between(range: NumberRange, rng: Random): number
	return rng:NextNumber(range.Min, range.Max)
end

local function swims(species): boolean
	-- Limited species may be switched off on the dashboard, so they never swim past.
	if
		species.DropOnly
		or not species.Pools
		or species.Requires
		or species.Rarity == "Limited"
		or species.Rarity == "Junk"
	then
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
	-- Highest point above the root. Swimming only yaws the fish, so this holds
	-- at any heading and keeps tall fins under the surface.
	local box, size = model:GetBoundingBox()
	root:SetAttribute("SwimTop", box.Position.Y + size.Y / 2 - root.Position.Y)
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
	local function canSimulate(): boolean
		local camera = workspace.CurrentCamera
		if not camera or player:GetAttribute("MetroRiding") then
			return false
		end
		local eye = camera.CFrame.Position
		-- Surface schools cannot be seen from a dry underground station. Keep
		-- underwater swimming enabled in the ocean, including deep dives.
		return eye.Y - Biomes.WaterLevel <= MAX_CAMERA_HEIGHT
			and (eye.Y >= Biomes.WaterLevel or Biomes.inOceanBounds(eye))
	end
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

	-- Too close to a school already swimming: in a bay only the deep middle passes
	-- the depth check, and every school used to pile up in that one spot.
	local function crowded(origin: Vector3): boolean
		for _, school in schools do
			local gap = Vector3.new(school.center.X - origin.X, 0, school.center.Z - origin.Z)
			if gap.Magnitude < SCHOOL_GAP then
				return true
			end
		end
		return false
	end

	local function spawnAt(origin: Vector3): boolean
		local now = workspace:GetServerTimeNow()
		local pool = if Weather.inLake(origin) then "MainLake" else "OpenSea"
		local id = pickSpecies(pool, (Seasons.current(now)), rng)
		if not id then
			return false
		end
		local species = FishSpecies[id]
		local count = if species.AverageKg >= SOLO_KG then 1 else rng:NextInteger(SCHOOL_SIZE.Min, SCHOOL_SIZE.Max)
		local length = FishModels.catchLength(species.AverageKg, id)
		local spacing = math.max(length * 1.4, 1.5)
		-- Clear the body, the school's vertical spread, the bob and rough swell so
		-- fins and backs never break the surface.
		local spread = if count == 1 then 0 else spacing * 0.3
		local swell = Weather.getState(now, origin).waveAmplitude * SWELL_MARGIN
		local depth = between(DEPTH, rng) + length * 0.5 + spread + swell
		local floor = floorAt(origin)
		if not floor or floor > Biomes.WaterLevel - depth - MIN_CLEARANCE then
			return false
		end
		local center = Vector3.new(origin.X, Biomes.WaterLevel - depth, origin.Z)
		local school = {
			id = id,
			remaining = count,
			spacing = spacing,
			solo = count == 1,
			center = center,
			depth = depth,
			floor = floor,
			ceiling = Biomes.WaterLevel - SURFACE_CLEARANCE - swell,
			heading = rng:NextNumber(0, TAU),
			turn = 0,
			turnTarget = 0,
			nextTurn = 0,
			nextProbe = 0,
			blockedUntil = 0,
			members = {},
		}
		table.insert(schools, school)
		return true
	end

	-- A few spread-out tries per attempt, so a shallow or crowded first pick
	-- does not leave the water empty or bunch the schools together.
	local function spawn(camera: Vector3)
		for _ = 1, SPAWN_TRIES do
			local angle = rng:NextNumber(0, TAU)
			local origin = camera + Vector3.new(math.cos(angle), 0, math.sin(angle)) * between(SPAWN_DISTANCE, rng)
			if not crowded(origin) and spawnAt(origin) then
				return
			end
		end
	end

	-- Limit cloning, parenting and disposal to one fish per Heartbeat. A bounded
	-- species-specific pool avoids rebuilding schools as the boat travels.
	local modelElapsed = MODEL_INTERVAL
	RunService.Heartbeat:Connect(function(dt: number)
		modelElapsed += dt
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
		-- Check here too: the ride attribute can change between render updates.
		if not canSimulate() or modelElapsed < MODEL_INTERVAL then
			return
		end
		modelElapsed = 0
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
			-- A model that reaches higher than the school's depth allowed for sinks
			-- the whole school, or drops it when the seabed leaves no room.
			local top = school.center.Y + offset.Y + (root:GetAttribute("SwimTop") or 0) + BOB_HEIGHT
			if top > school.ceiling then
				local sunk = school.center - Vector3.yAxis * (top - school.ceiling)
				if sunk.Y - MIN_CLEARANCE < school.floor then
					table.insert(retired, { id = school.id, model = model, root = root })
					school.remaining = 0
					if #school.members == 0 then
						despawn(school)
					end
					debug.profileend()
					return
				end
				school.center = sunk
			end
			local position = school.center + offset
			local forward = Vector3.new(math.cos(school.heading), 0, math.sin(school.heading))
			-- Move every part, not just the root: outside the workspace the welds are
			-- inactive, so a root-only move left the fish where they were built (the
			-- template origin, mid-bay at the surface) and they took that offset when
			-- parented. Only once parented does moving the root carry the body.
			model:PivotTo(CFrame.lookAt(position, position + forward) * CFrame.Angles(0, math.pi / 2, 0))
			model.Parent = folder
			table.insert(school.members, {
				model = model,
				root = root,
				offset = offset,
				position = position,
				direction = forward,
				phase = rng:NextNumber(0, TAU),
			})
			debug.profileend()
			return
		end
	end)

	-- Movement runs every rendered frame: stepping slower than the display reads
	-- as jitter on something this close to the camera.
	local spawnElapsed = SPAWN_INTERVAL
	local frame = 0
	RunService.RenderStepped:Connect(function(dt: number)
		dt = math.min(dt, 0.1)
		frame += 1
		if not canSimulate() then
			for index = #schools, 1, -1 do
				despawn(schools[index])
			end
			spawnElapsed = SPAWN_INTERVAL
			return
		end
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(eye.X, 0, eye.Z)
		for index = #schools, 1, -1 do
			local school = schools[index]
			local offset = Vector3.new(school.center.X, 0, school.center.Z) - flat
			if offset.Magnitude > DESPAWN_DISTANCE then
				despawn(school)
			end
		end
		spawnElapsed += dt
		if #schools < MAX_SCHOOLS and spawnElapsed >= SPAWN_INTERVAL then
			spawnElapsed = 0
			spawn(eye)
		end

		local now = os.clock()
		local roots, frames = {}, {}
		for index = #schools, 1, -1 do
			local school = schools[index]
			-- Wander with slow, smoothed turns.
			if now >= school.nextTurn then
				school.nextTurn = now + rng:NextNumber(4, 10)
				school.turnTarget = rng:NextNumber(-WANDER_TURN, WANDER_TURN)
			end
			local forward = Vector3.new(math.cos(school.heading), 0, math.sin(school.heading))
			if now >= school.nextProbe then
				school.nextProbe = now + PROBE_INTERVAL
				local here = floorAt(school.center)
				if not here or here > school.center.Y - 1 then
					-- Stranded anyway (terrain edits, a missed probe): never linger on land.
					despawn(school)
					continue
				end
				local floor = floorAt(school.center + forward * PROBE_AHEAD)
				if not floor or floor > school.center.Y - MIN_CLEARANCE then
					-- Shallows, a beach or the map edge ahead: ease round.
					school.turnTarget = if school.turnTarget >= 0 then SHORE_TURN else -SHORE_TURN
					school.nextTurn = now + 3
					school.blockedUntil = now + 3
				end
			end
			school.turn += (school.turnTarget - school.turn) * (1 - math.exp(-dt * 0.5))
			school.heading += school.turn * dt
			local speed = if now < school.blockedUntil then SPEED * 0.5 else SPEED
			forward = Vector3.new(math.cos(school.heading), 0, math.sin(school.heading))
			school.center += forward * speed * dt
			local toSchool = school.center - eye
			local distance = toSchool.Magnitude
			local shown = look:Dot(toSchool / distance) > BEHIND_DOT
				and (distance < NEAR_DISTANCE or (frame + index) % FAR_STRIDE == 0)
			for _, fish in school.members do
				-- The formation translates with the school but never rotates, so a
				-- fish only ever moves at the school's own crawl plus a slight bob.
				local bob = math.sin(now * BOB_RATE + fish.phase) * BOB_HEIGHT
				fish.position = school.center + fish.offset + Vector3.yAxis * bob
				fish.direction = fish.direction:Lerp(forward, 1 - math.exp(-dt * 0.5)).Unit
				if not shown then
					continue
				end
				local tail = math.sin(now * TAIL_RATE + fish.phase) * TAIL_SWING
				table.insert(roots, fish.root)
				table.insert(
					frames,
					CFrame.lookAt(fish.position, fish.position + fish.direction) * CFrame.Angles(0, math.pi / 2 + tail, 0)
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
