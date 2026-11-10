-- Builds the ocean-floor carpet around the camera from the patch templates the
-- server publishes in ReplicatedStorage.SeabedCarpet. The server used to clone
-- a patch into every cell of the ocean (~700k parts), which crashed live
-- servers; here only the cells within RADIUS exist, locally on this client.
-- Cell rules (grid, jitter, patch choice) live in shared/SeabedCarpet, so every
-- client builds the same floor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Rules = require(ReplicatedStorage.Shared.SeabedCarpet)

-- Names this module's per-frame work in the MicroProfiler (otherwise it is all "Script_Client").
local function profiled<A...>(label: string, callback: (A...) -> ()): (A...) -> ()
	if not debug.profilebegin then
		return callback -- test runners without the MicroProfiler API
	end
	return function(...: A...)
		debug.profilebegin(label)
		callback(...)
		debug.profileend()
	end
end

local SeabedCarpet = {}

-- The deep floor is out of sight further away than this, even from a diver.
local RADIUS = 320
-- The harbour lake's grid is four times as dense (24-stud cells) and lies around the village,
-- where the camera spends most of its time; past this the floor is lost under the surface
-- glare anyway. At 320 it was ~700 patches (~7k parts) drawn under the water at all times.
local LAKE_RADIUS = 208
-- Cells are only removed this far past their grid's radius, so a camera on a cell edge doesn't churn.
local KEEP_MARGIN = 96
local STEP_SECONDS = 0.2
-- Raycasts and clones per step; a full ring of new cells builds within a second or two.
local CELLS_PER_STEP = 24
-- Ground that hasn't streamed in yet: try again a few times.
local RETRY_SECONDS = 2
local MAX_TRIES = 8

local started = false

local function groundOf(instance: Instance): boolean
	return instance:IsA("Terrain")
		or instance:FindFirstAncestor("Ground") ~= nil
		or instance:FindFirstAncestor("SeabedSlope") ~= nil
end

-- Pure stepping logic, separate from the Roblox loop so the checks can drive it.
-- `sample(x, z)` follows Rules.plan; `place(styleId, template, frame, scale)` returns
-- the built model. Returns `update(position, now)` and the live cell table.
function SeabedCarpet.tracker(data, sample, place)
	local grids = Rules.grids()
	local taken = {}
	for _, grid in grids do
		taken[grid.id] = Rules.occupied(grid, data.gardens)
	end
	local inLake = Rules.lakeTest(data.lake)
	-- [key] = { model = Model?, x, z, keep, tries, retryAt }
	local cells: { [number]: any } = {}

	local function update(position: Vector3, now: number): number
		local built = 0
		-- Drop cells that fell well behind.
		for key, entry in cells do
			if math.max(math.abs(entry.x - position.X), math.abs(entry.z - position.Z)) > entry.keep then
				if entry.model then
					entry.model:Destroy()
				end
				cells[key] = nil
			end
		end
		for _, grid in grids do
			local half = grid.cell / 2
			local radius = if grid.lake then LAKE_RADIUS else RADIUS
			local x0, x1, z0, z1 = Rules.range(grid, position.X, position.Z, radius)
			for cx = x0, x1 do
				for cz = z0, z1 do
					if built >= CELLS_PER_STEP then
						return built
					end
					local key = Rules.key(grid, cx, cz)
					local entry = cells[key]
					if
						taken[grid.id][key]
						or (entry and (entry.model or entry.tries >= MAX_TRIES or now < entry.retryAt))
					then
						continue
					end
					if not entry then
						entry = {
							x = cx * grid.cell + half,
							z = cz * grid.cell + half,
							keep = radius + KEEP_MARGIN,
							tries = 0,
							retryAt = 0,
						}
						cells[key] = entry
					end
					built += 1
					local hit, rng, retry = Rules.plan(grid, cx, cz, data.seed, inLake, sample)
					if hit and rng then
						local frame, template, scale = Rules.frame(hit, rng)
						entry.model = place(Rules.style(hit.Position), template, frame, scale)
					else
						entry.tries = if retry then entry.tries + 1 else MAX_TRIES
						entry.retryAt = now + RETRY_SECONDS
					end
				end
			end
		end
		return built
	end
	return update, cells
end

function SeabedCarpet.start()
	if started then
		return
	end
	started = true
	local source = ReplicatedStorage:WaitForChild(Rules.FOLDER, math.huge)
	local lake = source:WaitForChild("Lake", math.huge) :: StringValue
	local gardens = source:WaitForChild("Gardens", math.huge) :: StringValue
	local templates: { [string]: { Model } } = {}
	for _, id in Rules.STYLES do
		local folder = source:WaitForChild(id, math.huge)
		local list = {}
		for index = 1, Rules.TEMPLATES do
			list[index] = folder:WaitForChild(tostring(index), math.huge) :: Model
		end
		templates[id] = list
	end

	local folder = Instance.new("Folder")
	folder.Name = "SeabedCarpet"
	folder.Parent = workspace
	-- Terrain is read from voxels, never raycast: a ray into a terrain chunk this client hasn't
	-- queried builds that chunk's collision first (RaycastTerrain > buildKDTree, tens of ms),
	-- and a moving camera reaches fresh seabed chunks with every new ring of cells.
	local TerrainProbe = require(script.Parent.TerrainProbe)
	local TOP, BOTTOM = 600, -120
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder, workspace.Terrain }
	params.IgnoreWater = true

	-- Same acceptance as the server's garden sampling. Anything else in the way
	-- (an unstreamed island, a swimmer, a crab cage) is retried a few times.
	local function sample(x: number, z: number): (RaycastResult?, boolean)
		local partHit = workspace:Raycast(Vector3.new(x, TOP, z), Vector3.new(0, BOTTOM - TOP, 0), params)
		local floor, normal, surface = TerrainProbe.seabed(x, z, BOTTOM)
		local hit: any = partHit
		if not partHit or (floor and floor > partHit.Position.Y) then
			if floor then
				hit = { Position = Vector3.new(x, floor, z), Normal = normal, Instance = workspace.Terrain }
			elseif surface == "land" then
				return nil, false
			else
				return nil, true -- terrain not streamed in yet
			end
		end
		if
			hit.Position.Y >= Biomes.WaterLevel - 8
			or hit.Normal.Y <= 0.78
			or not Biomes.inOceanBounds(hit.Position)
		then
			return nil, false
		end
		if not groundOf(hit.Instance) then
			return nil, true
		end
		return hit, false
	end
	local function place(style: string, template: number, frame: CFrame, scale: number): Model?
		local pool = templates[style] or templates.open
		local patch = pool[template]:Clone()
		patch:ScaleTo(scale)
		patch:PivotTo(frame)
		patch.Parent = folder
		return patch
	end

	local update = SeabedCarpet.tracker({
		seed = source:GetAttribute("Seed") or 0,
		lake = Rules.decode(lake.Value),
		gardens = Rules.decode(gardens.Value),
	}, sample, place)
	local elapsed = STEP_SECONDS
	RunService.Heartbeat:Connect(profiled("SeabedCarpet", function(dt)
		elapsed += dt
		if elapsed < STEP_SECONDS then
			return
		end
		elapsed = 0
		local camera = workspace.CurrentCamera
		if camera then
			update(camera.CFrame.Position, os.clock())
		end
	end))
end

return SeabedCarpet
