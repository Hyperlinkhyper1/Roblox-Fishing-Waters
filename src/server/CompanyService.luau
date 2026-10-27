-- The Company path's hired fisherman. He takes the boat the owner assigned (Home ▸
-- Staff) from its mooring beside the right-hand pier, sails out to open water and
-- fishes on a timer. Every catch is saved straight into that boat's cargo hold.
-- When the hold is full, or after a few catches, he sails home and moors; the
-- porter unloads the hold like any docked boat, then he heads out again. The
-- boat is a display copy moved by the server, so it never needs a driver.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnglerData = require(script.Parent.AnglerData)
local BoatService = require(script.Parent.BoatService)
local CustomerService = require(script.Parent.CustomerService)
local Rowboat = require(script.Parent.Rowboat)
local FishingBoat = require(script.Parent.FishingBoat)
local Trawler = require(script.Parent.Trawler)
local BoatCatalog = require(ReplicatedStorage.Shared.BoatCatalog)
local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Catalog = require(ReplicatedStorage.Shared.AnglerCatalog)
local DayNight = require(ReplicatedStorage.Shared.DayNight)
local FishCatch = require(ReplicatedStorage.Shared.FishCatch)
local FishMutations = require(ReplicatedStorage.Shared.FishMutations)
local Paths = require(ReplicatedStorage.Shared.Paths)
local Weather = require(ReplicatedStorage.Shared.Weather)

local CompanyService = {}
local BASE_TAG = "PlayerBase"
local builders = { Rowboat = Rowboat, FishingBoat = FishingBoat, Trawler = Trawler }
-- Dock-local studs (BoatDockFrame: -Z is the water, +X the right-hand pier at x=17).
local MOORINGS = {
	{ boat = CFrame.new(28, 0, -24), pier = Vector3.new(17, 3.2, -24), pickup = Vector3.new(17, 3.2, -24) },
	{ boat = CFrame.new(-28, 0, -24), pier = Vector3.new(-17, 3.2, -24), pickup = Vector3.new(-17, 3.2, -24) },
}
local CATCH_SECONDS = Vector2.new(16, 26)
local TRIP_CATCHES = 8
local REST_SECONDS = 6
local SPEED_SCALE = 0.55
local TURN_RATE = 1.4

local npc = CustomerService.npc
local random = Random.new()
local started = false
local crews: { [Model]: any } = {}
local folder: Folder

local function dockFrame(base: Model): CFrame?
	local frame = base:GetAttribute("BoatDockFrame")
	return if typeof(frame) == "CFrame" then frame else nil
end

local function water(position: Vector3): boolean
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Include
	parameters.FilterDescendantsInstances = { workspace.Terrain }
	parameters.IgnoreWater = false
	local result = workspace:Raycast(
		Vector3.new(position.X, Biomes.WaterLevel + 14, position.Z),
		Vector3.new(0, -32, 0),
		parameters
	)
	return result ~= nil and result.Material == Enum.Material.Water
end

-- Every few studs along a straight run must be open water.
local function clearRun(from: Vector3, to: Vector3): boolean
	local steps = math.max(1, math.ceil((to - from).Magnitude / 8))
	for step = 0, steps do
		if not water(from:Lerp(to, step / steps)) then
			return false
		end
	end
	return true
end

-- The fisherman's hired state on the owner's profile, or nil when he isn't working.
local function assignment(profile): (string?, any?)
	local angler = profile and profile.Angler
	local boatId = angler and angler.FishermanBoat
	if
		not angler
		or not angler.Staff.Fisherman
		or not Paths.unlocked(profile, "Company")
		or not boatId
		or not profile.OwnedBoats[boatId]
		or not builders[boatId]
	then
		return nil, nil
	end
	return boatId, BoatCatalog[boatId]
end

local function holdFish(profile, boatId: string): number
	local count = 0
	for _, item in profile.Angler.Holds[boatId] or {} do
		if item.Fish then
			count += 1
		end
	end
	return count
end

local function despawn(crew)
	crew.active = false
	if crew.model then
		crew.model:Destroy()
	end
	crews[crew.base] = nil
end

local function status(crew, text: string)
	if crew.worker then
		npc.bubble(crew.worker, "Fisherman · " .. text)
	end
end

local function build(base: Model, owner: Player, boatId: string)
	local dock = dockFrame(base)
	if not dock then
		return nil
	end
	local mooring = MOORINGS[1]
	for _, option in MOORINGS do
		if water((dock * option.boat).Position) then
			mooring = option
			break
		end
	end
	local moor = dock * mooring.boat
	local model = builders[boatId].build(moor, true)
	model.Name = "CompanyBoat_" .. owner.UserId
	model:SetAttribute("OwnerUserId", owner.UserId)
	model:SetAttribute("BoatId", boatId)
	model:SetAttribute("CompanyBoat", true)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			-- Players can't board or be shoved by a hull the server slides around.
			part.CanCollide, part.CanTouch = false, false
			if part:IsA("Seat") or part:IsA("VehicleSeat") then
				part.Disabled = true
			end
		end
	end
	local crew = {
		base = base,
		ownerId = owner.UserId,
		boatId = boatId,
		-- Wears the owner's refit dock paint and keeps the speed of its motors.
		spec = BoatService.outfit(owner, boatId, model),
		model = model,
		active = true,
		mode = "Moored",
		dock = dock,
		moor = moor,
		pier = (dock * CFrame.new(mooring.pier)).Position,
		pickup = (dock * CFrame.new(mooring.pickup)).Position,
		restUntil = os.clock() + REST_SECONDS,
		path = {},
		catches = 0,
		frame = moor,
		-- The hull's pivot sits below the waterline frame it was built at.
		pivotOffset = moor:ToObjectSpace(model:GetPivot()),
	}
	model:SetAttribute("PorterPier", crew.pier)
	model:SetAttribute("PorterPickup", crew.pickup)
	model.Parent = folder
	-- The fisherman stands at the stern with a rod over the side.
	task.spawn(function()
		local ok, worker = pcall(npc.spawn, (moor * CFrame.new(0, 3, 0)).Position, "Fisherman")
		if not ok then
			warn("[Company] Fisherman: " .. tostring(worker))
			return
		end
		if not crew.active then
			worker:Destroy()
			return
		end
		worker.Name = "Fisherman"
		local humanoid = worker:FindFirstChildOfClass("Humanoid") :: Humanoid
		local root = worker:FindFirstChild("HumanoidRootPart") :: BasePart
		for _, part in worker:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored, part.CanCollide, part.Massless = true, false, true
			end
		end
		local floor = model:GetAttribute("DryFloorHeight") or 0.8
		local stand = crew.frame * CFrame.new(0, floor + humanoid.HipHeight + root.Size.Y / 2, crew.spec.Length * 0.28)
		worker:PivotTo(stand * CFrame.Angles(0, math.pi / 2, 0))
		local rod = Instance.new("Part")
		rod.Name = "FishermanRod"
		rod.Size = Vector3.new(0.12, 0.12, 7)
		rod.Color, rod.Material = Color3.fromRGB(70, 52, 38), Enum.Material.Wood
		rod.Anchored, rod.CanCollide, rod.CanQuery, rod.CanTouch = true, false, false, false
		rod.CFrame = stand
			* CFrame.new(-1.6, 0.6, 0)
			* CFrame.Angles(0, math.pi / 2, 0)
			* CFrame.Angles(math.rad(28), 0, 0)
			* CFrame.new(0, 0, -3.2)
		rod.Parent = worker
		worker.Parent = model
		crew.worker = { model = worker, humanoid = humanoid, root = root }
		status(crew, "Getting the boat ready")
	end)
	return crew
end

-- Straight out from the mooring, past the end of the piers.
local function mouthOf(crew): Vector3
	local side = crew.dock:PointToObjectSpace(crew.moor.Position).X
	return (crew.dock * CFrame.new(side, 0, -64)).Position
end

-- A fishing spot in open water reachable in a straight run from the harbour mouth.
local function plan(crew): { CFrame }
	local mouth = mouthOf(crew)
	local spot = mouth
	for _ = 1, 24 do
		local candidate = (crew.dock * CFrame.new(random:NextNumber(-90, 90), 0, -random:NextNumber(95, 210))).Position
		if water(candidate) and clearRun(mouth, candidate) then
			spot = candidate
			break
		end
	end
	return { CFrame.new(mouth), CFrame.new(spot) }
end

local function sail(crew, waypoints: { CFrame }, mode: string)
	crew.path, crew.mode = waypoints, mode
end

local function startTrip(crew)
	crew.catches = 0
	sail(crew, plan(crew), "Outbound")
	status(crew, "Heading out to fish")
end

local function returnHome(crew)
	sail(crew, { CFrame.new(mouthOf(crew)), crew.moor }, "Returning")
	status(crew, "Sailing home with the catch")
end

local function landFish(crew, owner: Player)
	local position = crew.frame.Position
	local pool = Catalog.Pools[if Weather.inLake(position) then Catalog.DefaultPool else "OpenSea"]
	local function rng()
		return random:NextNumber()
	end
	local roll = FishCatch.roll(pool, Catalog.Fish, Catalog.Rarities, rng)
	local traits = FishMutations.roll(
		Catalog.Fish[roll.FishId],
		DayNight.isNight(DayNight.clockTime()),
		rng,
		nil,
		Weather.mutationContext(position)
	)
	roll.Traits = traits
	roll.Value = FishMutations.value(roll.Value, traits.Mutation, traits.Corruptions)
	local full = false
	local ok = BoatService.updateProgress(owner, function(current)
		local boatId = assignment(current)
		assert(boatId == crew.boatId, "The fisherman has another boat now.")
		local data = AnglerData.fishermanCatch(
			current.Angler,
			crew.boatId,
			crew.spec,
			roll,
			os.time(),
			Catalog.Fish,
			Catalog.Mutations
		)
		full = data == nil
		if data then
			current.Angler = data
		end
	end)
	if ok and not full then
		crew.catches += 1
		local fish = Catalog.Fish[roll.FishId]
		status(crew, string.format("Landed a %s (%d this trip)", if fish then fish.Name else roll.FishId, crew.catches))
	end
	if full or crew.catches >= TRIP_CATCHES then
		returnHome(crew)
	end
end

-- Steers the display hull along its waypoints at a fraction of the boat's speed.
local function move(crew, dt: number)
	local target = crew.path[1]
	if not target then
		return
	end
	local position = crew.frame.Position
	local goal = Vector3.new(target.Position.X, Biomes.WaterLevel, target.Position.Z)
	local offset = Vector3.new(goal.X - position.X, 0, goal.Z - position.Z)
	local speed = crew.spec.ForwardSpeed * SPEED_SCALE
	local _, yaw = crew.frame:ToOrientation()
	if offset.Magnitude <= math.max(1, speed * dt) then
		table.remove(crew.path, 1)
		if #crew.path == 0 and crew.mode == "Returning" then
			crew.frame = crew.moor
			crew.model:PivotTo(crew.moor * crew.pivotOffset)
			return
		end
		crew.frame = CFrame.new(Vector3.new(goal.X, Biomes.WaterLevel, goal.Z)) * CFrame.Angles(0, yaw, 0)
	else
		-- Boats face -Z: turn towards the goal, then move along the bow.
		local wanted = math.atan2(-offset.X, -offset.Z)
		local delta = (wanted - yaw + math.pi) % (2 * math.pi) - math.pi
		yaw += math.clamp(delta, -TURN_RATE * dt, TURN_RATE * dt)
		local heading = CFrame.Angles(0, yaw, 0)
		local step = heading.LookVector * math.min(speed * dt, offset.Magnitude) * math.max(0.25, math.cos(delta))
		crew.frame = CFrame.new(Vector3.new(position.X, Biomes.WaterLevel, position.Z) + step) * heading
	end
	crew.model:PivotTo(crew.frame * crew.pivotOffset)
end

-- One decision per tick: rest at the mooring, keep fishing, or set off again.
local function think(crew, owner: Player, profile)
	if crew.mode == "Moored" then
		local waiting = holdFish(profile, crew.boatId)
		if waiting > 0 then
			crew.restUntil = os.clock() + REST_SECONDS
			status(
				crew,
				if profile.Angler.Staff.Porter
					then string.format("Waiting for the porter to unload %d fish", waiting)
					else "Hire a porter to unload my catch"
			)
		elseif os.clock() >= crew.restUntil then
			startTrip(crew)
		end
	elseif crew.mode == "Outbound" and #crew.path == 0 then
		crew.mode = "Fishing"
		crew.nextCatch = os.clock() + random:NextNumber(CATCH_SECONDS.X, CATCH_SECONDS.Y)
		status(crew, "Fishing")
	elseif crew.mode == "Fishing" and os.clock() >= crew.nextCatch and not crew.busy then
		crew.busy = true
		crew.nextCatch = os.clock() + random:NextNumber(CATCH_SECONDS.X, CATCH_SECONDS.Y)
		task.spawn(function()
			local ok, failure = pcall(landFish, crew, owner)
			crew.busy = false
			if not ok then
				warn("[Company] Catch: " .. tostring(failure))
			end
		end)
	elseif crew.mode == "Returning" and #crew.path == 0 then
		crew.mode = "Moored"
		crew.restUntil = os.clock() + REST_SECONDS
		local count = holdFish(profile, crew.boatId)
		if count > 0 then
			npc.notify(owner, string.format("Your fisherman is back with %d fish in the %s.", count, crew.spec.Name))
		end
	end
end

-- The moored company boat for the porter (CustomerService), while it is tied up.
local function moored(shop, owner: Player): (string?, Model?)
	local crew = crews[shop.base]
	if crew and crew.active and crew.mode == "Moored" and crew.ownerId == owner.UserId and crew.model.Parent then
		return crew.boatId, crew.model
	end
	return nil, nil
end

local function syncBase(base: Model)
	local crew = crews[base]
	local owner = npc.ownerOf(base)
	local profile = owner and BoatService.getProfile(owner)
	local boatId = assignment(profile)
	if crew and (not owner or crew.ownerId ~= owner.UserId or crew.boatId ~= boatId) then
		despawn(crew)
		crew = nil
	end
	if not crew and owner and boatId then
		crew = build(base, owner, boatId)
		crews[base] = crew
	end
	return crew, owner, profile
end

function CompanyService.start()
	if started then
		return
	end
	started = true
	folder = Instance.new("Folder")
	folder.Name = "CompanyBoats"
	folder.Parent = workspace
	CustomerService.useCompanyDock(moored)
	BoatService.setBoatLock(function(player, boatId)
		local profile = BoatService.getProfile(player)
		if assignment(profile) == boatId then
			return "Your fisherman is using the "
				.. BoatCatalog[boatId].Name
				.. ". Give him another boat in Home ▸ Staff to sail it yourself."
		end
		return nil
	end)
	RunService.Heartbeat:Connect(function(dt)
		for _, crew in crews do
			if crew.active and #crew.path > 0 then
				move(crew, dt)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, base in CollectionService:GetTagged(BASE_TAG) do
				if not base:IsA("Model") then
					continue
				end
				local ok, failure = pcall(function()
					local crew, owner, profile = syncBase(base)
					if crew and owner and profile then
						think(crew, owner, profile)
					end
				end)
				if not ok then
					warn("[Company] " .. tostring(failure))
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, crew in crews do
			if crew.ownerId == player.UserId then
				despawn(crew)
			end
		end
	end)
end

return CompanyService
