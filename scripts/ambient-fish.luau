-- MOCKS --

-- Runs the real AmbientFish schools against recording mocks: species choice,
-- spawn depth, recycling, shore avoidance, the slow drift and the single-root welds.
-- How the schools look through Terrain water still needs a Studio check.
NumberRange = {
	new = function(low, high)
		return { Min = low, Max = high or low }
	end,
}
local seededRandom = Random.new
Random.new = function(seed)
	return seededRandom(seed or 4242)
end
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback)
			table.insert(callbacks, callback)
		end,
		Fire = function(_, ...)
			for _, callback in callbacks do
				callback(...)
			end
		end,
	}
end
local clock = 0
local debug = { profilebegin = function() end, profileend = function() end }
local os = {
	clock = function()
		return clock
	end,
}
local RaycastParams = {
	new = function()
		return {}
	end,
}
workspace = Instance.new("Folder")
workspace.Terrain = Instance.new("Terrain")
workspace.Terrain.Parent = workspace
workspace.CurrentCamera = Instance.new("Camera")
-- Schools out of view skip their move, so behaviour checks use a camera that
-- faces every school; the culling check below gives it a real heading.
local facing = nil
local function view(position)
	return {
		Position = position,
		LookVector = {
			Dot = function(_, direction)
				return if facing then facing:Dot(direction) else 1
			end,
		},
	}
end
workspace.CurrentCamera.CFrame = view(Vector3.new(0, 12, 0))
workspace.CurrentCamera.Parent = workspace
function workspace:GetServerTimeNow()
	return clock
end
-- Sea everywhere at floorY, except dry land east of shoreX.
local floorY, shoreX, dryPocket = -30, math.huge, false
function workspace:Raycast(origin, direction, params)
	assert(params.FilterType == Enum.RaycastFilterType.Include, "Depth probes must ignore docks and hulls")
	assert(params.FilterDescendantsInstances[1] == self.Terrain, "Depth probes read Terrain only")
	if origin.X > shoreX then
		return { Material = Enum.Material.Sand, Position = Vector3.new(origin.X, 3, origin.Z) }
	end
	if not params.IgnoreWater then
		return { Material = Enum.Material.Water, Position = Vector3.new(origin.X, 0, origin.Z) }
	end
	return { Material = Enum.Material.Sand, Position = Vector3.new(origin.X, floorY, origin.Z) }
end
local moves = 0
function workspace:BulkMoveTo(parts, frames)
	moves += 1
	for index, part in parts do
		part.CFrame = frames[index]
	end
end
local player = Instance.new("Player")
local character = Instance.new("Model")
local body = Instance.new("Part")
body.Name = "HumanoidRootPart"
body.CFrame = CFrame.new(0, 40, 0)
body.Parent = character
player.Character = character
local renderStepped = signal()
local heartbeat = signal()
local services = {
	Players = { LocalPlayer = player },
	RunService = { RenderStepped = renderStepped, Heartbeat = heartbeat },
	ReplicatedStorage = {},
}
game.GetService = function(_, name)
	assert(services[name], name)
	return services[name]
end
dependencies.Biomes = {
	WaterLevel = 0,
	SeaFloor = -64,
	inOceanBounds = function(position)
		if dryPocket and position.Y < 0 and math.abs(position.X) < 20 and math.abs(position.Z) < 20 then
			return false
		end
		return math.abs(position.X) < 5200 and math.abs(position.Z) < 5200
	end,
}
dependencies.FishSpecies = {
	Sardine = { Name = "Sardine", RarityDenominator = 4, AverageKg = 0.1, Pools = { "OpenSea" } },
	Tuna = { Name = "Yellowfin Tuna", RarityDenominator = 4, AverageKg = 30, Pools = { "OpenSea" } },
	Pike = { Name = "Pike", RarityDenominator = 4, AverageKg = 2, Pools = { "MainLake" } },
	BlueCrab = { Name = "Blue Crab", RarityDenominator = 2, AverageKg = 0.5, Pools = { "OpenSea" } },
	NightEel = { Name = "Night Eel", RarityDenominator = 2, AverageKg = 1, Pools = { "OpenSea" }, Requires = { "Night" } },
	Icefish = { Name = "Icefish", RarityDenominator = 2, AverageKg = 1, Pools = { "OpenSea" }, Seasons = { "Winter" } },
	SharkFin = { Name = "Shark Fin", RarityDenominator = 2, AverageKg = 1, DropOnly = true },
	Tire = { Name = "Tire", Rarity = "Common", RarityDenominator = 4, AverageKg = 7, Pools = { "MainLake", "OpenSea" } },
	LeatherBoot = { Name = "Leather Boot", Rarity = "Junk", RarityDenominator = 2, AverageKg = 1, Pools = { "OpenSea" } },
}
local created = {}
local totalCreated = 0
dependencies.FishModels = {
	has = function(id)
		return dependencies.FishSpecies[id] ~= nil
	end,
	create = function(id)
		totalCreated += 1
		created[id] = (created[id] or 0) + 1
		local model = Instance.new("Model")
		model.Name = id
		local trunk = Instance.new("Part")
		trunk.Name, trunk.Anchored, trunk.Material = "Body", true, Enum.Material.Grass
		trunk.Size, trunk.CFrame = Vector3.new(1, 0.4, 0.3), CFrame.new(0, 0, 0)
		trunk.Parent = model
		local snout = Instance.new("Part")
		snout.Name, snout.Anchored = "Snout", true
		snout.Size, snout.CFrame = Vector3.new(0.1, 0.1, 0.1), CFrame.new(0.55, 0, 0)
		snout.Parent = model
		if id == "Tuna" then
			-- A sail far taller than the body, like a sailfish's dorsal fin.
			local sail = Instance.new("Part")
			sail.Name, sail.Anchored = "Sail", true
			sail.Size, sail.CFrame = Vector3.new(0.3, 6, 0.1), CFrame.new(0, 3, 0)
			sail.Parent = model
		end
		return model
	end,
	scaleCatch = function() end,
	catchLength = function()
		return 1
	end,
}
dependencies.Seasons = {
	current = function()
		return "Summer", 0
	end,
}
local waves = 0
dependencies.Weather = {
	getState = function()
		return { waveAmplitude = waves }
	end,
	inLake = function(position)
		return position.X < -1000
	end,
}
local Client = (function()
	-- CLIENT --
end)()

local function step(seconds)
	for _ = 1, math.ceil(seconds * 60) do
		clock += 1 / 60
		local before = totalCreated
		local folder = workspace:FindFirstChild("AmbientFish")
		local visible = #folder:GetChildren()
		renderStepped:Fire(1 / 60)
		assert(totalCreated == before, "Rendering never builds fish")
		assert(#folder:GetChildren() == visible, "Rendering never parents or removes schools")
		heartbeat:Fire(1 / 60)
		assert(totalCreated - before <= 1, "At most one fish is built per Heartbeat")
		assert(math.abs(#folder:GetChildren() - visible) <= 1, "At most one fish enters or leaves per Heartbeat")
	end
end
local function move(x, y, z)
	workspace.CurrentCamera.CFrame = view(Vector3.new(x, y, z))
end
local function fish()
	return workspace:FindFirstChild("AmbientFish"):GetChildren()
end
local function rootOf(model)
	return model:FindFirstChild("SwimRoot")
end

Client.start()
Client.start()
local folders = 0
for _, child in workspace:GetChildren() do
	if child.Name == "AmbientFish" then
		folders += 1
	end
end
assert(folders == 1, "Startup must be idempotent")

-- Departure can arrive between render and Heartbeat while a school is only
-- partly built. Neither queued construction nor movement should continue.
step(0.6)
assert(totalCreated > 0, "A partly populated school exists before departure")
player:SetAttribute("MetroRiding", true)
local rideCreated, rideMoves = totalCreated, moves
heartbeat:Fire(1)
assert(totalCreated == rideCreated, "Departure stops pending builds before the next render")
step(10)
assert(totalCreated == rideCreated and moves == rideMoves, "Metro rides do no fish construction or movement")
assert(#fish() == 0, "Departure drains old schools through the bounded recycler")

player:SetAttribute("MetroRiding", nil)
dryPocket = true
move(0, -24, 0)
step(10)
assert(totalCreated == rideCreated and #fish() == 0, "Dry underground stations never spawn surrounding surface schools")
dryPocket = false
step(10)
assert(#fish() >= 12, "An underwater camera in the ocean still sees schools")
local underwaterCreated = totalCreated
local savedCamera = workspace.CurrentCamera
workspace.CurrentCamera = nil
step(2)
assert(#fish() == 0 and totalCreated == underwaterCreated, "Missing cameras retire schools without building fish")
workspace.CurrentCamera = savedCamera
move(0, 12, 0)
print("Ambient fish: metro ride, underground station, underwater camera and camera recovery checks passed")
if METRO_ONLY then return end

step(10)
local models = fish()
-- Eight schools: solo Tuna count one fish each, Sardine shoals three to five.
assert(#models >= 8 and #models <= 40, "Schools fill the water within the cosmetic fish budget: " .. #models)
-- Schools spread round the camera instead of piling into one spot: any two fish
-- are either schoolmates (a few studs apart) or a full school gap away.
for _, a in models do
	for _, b in models do
		local pa, pb = rootOf(a).CFrame.Position, rootOf(b).CFrame.Position
		local gap = Vector3.new(pa.X - pb.X, 0, pa.Z - pb.Z).Magnitude
		assert(gap < 14 or gap > 20, "Schools keep apart: two fish " .. gap .. " studs apart")
	end
end
for _, model in models do
	assert(model.Name == "Sardine" or model.Name == "Tuna", "Only open-sea swimmers that bite now: " .. model.Name)
	local root = rootOf(model)
	assert(root and model.PrimaryPart == root and root.Anchored and root.Transparency == 1, "One anchored, hidden root")
	assert(not root.CanCollide and not root.CanQuery and not root.CanTouch, "The root never blocks casts or players")
	local welds, parts = 0, 0
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and item ~= root then
			parts += 1
			assert(not item.Anchored and item.Massless, "Visible parts ride the root")
			assert(not item.CanCollide and not item.CanQuery and not item.CanTouch, "Fish never block casts or players")
			assert(item:GetAttribute("SeasonExempt"), "Recycled fish stay out of the season recolour list")
		elseif item.ClassName == "WeldConstraint" then
			assert(item.Part0 == root, "Welds hang off the root")
			welds += 1
		end
	end
	assert(welds == parts, "Every visible part is welded")
	-- Inactive welds don't carry parts in Roblox either, so a fish must be placed
	-- whole before it is parented. Its visible body starts at the school, not at
	-- the template origin (mid-bay, on the surface); mock welds never carry it, so
	-- allow the 10 s of drift since it was placed.
	local rootPosition = root.CFrame.Position
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and item ~= root then
			local p = item.CFrame.Position
			assert(
				Vector3.new(p.X - rootPosition.X, 0, p.Z - rootPosition.Z).Magnitude < 16,
				model.Name .. "'s body was left behind at " .. tostring(p)
			)
			assert(p.Y + item.Size.Y / 2 < -1, model.Name .. "'s body sits under the surface: " .. p.Y)
		end
	end
	local y = root.CFrame.Position.Y
	assert(y < -3 and y > floorY + 2, "Schools swim fully submerged, clear of the seabed")
	-- The Tuna mock carries a sail far taller than its body. Mock welds don't
	-- carry parts, so measure from the root and the height recorded at build.
	local reach = root:GetAttribute("SwimTop")
	assert(reach and (model.Name ~= "Tuna" or reach > 2.9), "The build records the model's full height")
	assert(y + reach < -1.4, model.Name .. "'s highest point stays under the surface")
end
for _, id in { "BlueCrab", "NightEel", "Icefish", "SharkFin", "Pike", "Tire", "LeatherBoot" } do
	assert(not created[id], id .. " must not swim here")
end

-- Bodies face the way they swim, a slow 0.8 studs a second on one heading.
local sample = rootOf(models[1])
local before = sample.CFrame.Position
step(10)
local travelled = sample.CFrame.Position - before
local drift = Vector3.new(travelled.X, 0, travelled.Z).Magnitude
assert(drift > 5.6 and drift < 8.8, "Fish swim at 0.8 studs per second: " .. drift)
local flat = Vector3.new(travelled.X, 0, travelled.Z).Unit
local right = sample.CFrame.RightVector
assert(Vector3.new(right.X, 0, right.Z).Unit:Dot(flat) > 0.75, "The head (+X) leads")
assert(moves > 0, "Frames are moved in one bulk call")

-- Big species cruise alone.
dependencies.FishSpecies.Sardine.Pools = {}
move(0, 400, 0)
step(1)
assert(#fish() == 0, "Climbing high clears every school")
move(0, 12, 0)
step(10)
assert(#fish() >= 3 and #fish() <= 8, "Solo species spawn one fish per school")
local soloCreated = totalCreated
move(1200, 12, 0)
step(10)
assert(totalCreated == soloCreated, "The same species reuses retired fish after travelling")
dependencies.FishSpecies.Sardine.Pools = { "OpenSea" }

-- Leaving the area recycles schools behind the camera.
move(2400, 12, 0)
step(10)
for _, model in fish() do
	local position = rootOf(model).CFrame.Position
	assert(Vector3.new(position.X - 2400, 0, position.Z).Magnitude < 200, "Old schools are recycled, not left behind")
end

-- The lake has its own species.
move(-2000, 12, 0)
step(10)
for _, model in fish() do
	assert(model.Name == "Pike", "Lake schools are lake species")
end

-- Shallow water never spawns schools.
floorY = -4
move(2000, 12, 2000)
step(10)
assert(#fish() == 0, "Shallows are too thin to hold a school")
floorY = -30

-- Schools turn back from a shore instead of swimming onto it.
shoreX = 40
move(0, 12, 0)
step(60)
for _, model in fish() do
	assert(rootOf(model).CFrame.Position.X < shoreX + 12, "Schools stay off the beach")
end

-- Nothing ever darts or swings: per frame, even a swimmer right beside a school
-- and shore turns leave every fish within its crawl, bob and gentle tail beat.
facing = Vector3.new(1, 0, 0)
for frame = 1, 20 * 60 do
	local near = fish()[1]
	if near and frame % 60 == 0 then
		local position = rootOf(near).CFrame.Position
		body.CFrame = CFrame.new(position.X - 2, -1, position.Z)
	end
	local before = {}
	for _, model in fish() do
		before[model] = rootOf(model).CFrame
	end
	step(1 / 60)
	for _, model in fish() do
		local root = rootOf(model)
		assert(root.CFrame.Position.X < shoreX + 3, "Schools never reach the beach")
		local previous = before[model]
		-- A culled school catches up out of sight when it re-enters view (an
		-- 81-degree cone, wider than any screen); judge only ones seen throughout.
		local eye = workspace.CurrentCamera.CFrame.Position
		local seen = previous
			and facing:Dot((previous.Position - eye).Unit) > 0.3
			and facing:Dot((root.CFrame.Position - eye).Unit) > 0.3
		if seen and previous ~= root.CFrame then
			local moved = (root.CFrame.Position - previous.Position).Magnitude
			-- 0.8 studs/s is 0.0133 a frame at 60 fps; schools past 60 studs step every
			-- third frame (FAR_STRIDE), so up to 0.04 at once, plus the bob.
			assert(moved < 0.045, "Fish swim slowly instead of darting: " .. moved)
			local turn = math.acos(math.clamp(previous.LookVector:Dot(root.CFrame.LookVector), -1, 1))
			assert(turn < 0.01, "Fish turn gently instead of swinging round: " .. turn)
		end
	end
end
body.CFrame = CFrame.new(0, 40, 0)
facing = nil

-- Storm swell sinks new schools.
move(0, 400, 0)
step(1)
waves = 4
move(0, 12, 0)
step(10)
for _, model in fish() do
	assert(rootOf(model).CFrame.Position.Y < -5, "Storm schools swim below the swell")
end

-- Schools behind the camera hold still; nearby ones in view move every frame.
facing = Vector3.new(0, 0, -1)
local behind, ahead = nil, nil
for _, model in fish() do
	local root = rootOf(model)
	local offset = root.CFrame.Position - Vector3.new(0, 12, 0)
	if offset.Magnitude > 20 and offset.Unit:Dot(facing) < 0 then
		behind = behind or root
	elseif offset.Magnitude > 20 and offset.Magnitude < 60 and offset.Unit:Dot(facing) > 0.3 then
		ahead = ahead or root
	end
end
assert(behind, "A school swims behind the camera")
local held = behind.CFrame
step(0.5)
assert(behind.CFrame == held, "Schools behind the camera skip their move")
if ahead then
	local was = ahead.CFrame
	step(1 / 60)
	assert(ahead.CFrame ~= was, "Nearby schools in view move every frame")
end
facing = nil

print("Ambient fish: species pools, welds, depth, heading, solo cruisers, recycling, lake, shallows, shore, slow drift, tall fins and swell passed")
