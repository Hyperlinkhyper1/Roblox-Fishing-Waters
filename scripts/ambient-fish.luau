-- MOCKS --

-- Runs the real AmbientFish schools against recording mocks: species choice,
-- spawn depth, recycling, shore avoidance, fleeing and the single-root welds.
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
workspace.CurrentCamera.CFrame = CFrame.new(0, 12, 0)
workspace.CurrentCamera.Parent = workspace
function workspace:GetServerTimeNow()
	return clock
end
-- Sea everywhere at floorY, except dry land east of shoreX.
local floorY, shoreX = -30, math.huge
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
local player = {}
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
	workspace.CurrentCamera.CFrame = CFrame.new(x, y, z)
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

step(10)
local models = fish()
assert(#models >= 6, "Schools fill the water around the camera")
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
	local y = root.CFrame.Position.Y
	assert(y < -1 and y > floorY + 2, "Schools swim just under the surface, clear of the seabed")
end
for _, id in { "BlueCrab", "NightEel", "Icefish", "SharkFin", "Pike" } do
	assert(not created[id], id .. " must not swim here")
end

-- Bodies face the way they swim.
local sample = rootOf(models[1])
local before = sample.CFrame.Position
step(0.5)
local travelled = sample.CFrame.Position - before
assert(travelled.Magnitude > 0.5, "Fish keep swimming")
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
assert(#fish() >= 3 and #fish() <= 6, "Solo species spawn one fish per school")
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

-- A swimmer scatters a nearby school.
local target = rootOf(fish()[1])
local spot = target.CFrame.Position
body.CFrame = CFrame.new(spot.X - 3, -1, spot.Z)
step(1)
local fled = target.CFrame.Position
assert((fled - body.CFrame.Position).Magnitude > (spot - body.CFrame.Position).Magnitude + 3, "Fish flee a swimmer")
body.CFrame = CFrame.new(0, 40, 0)

-- Storm swell sinks new schools.
move(0, 400, 0)
step(1)
waves = 4
move(0, 12, 0)
step(10)
for _, model in fish() do
	assert(rootOf(model).CFrame.Position.Y < -5, "Storm schools swim below the swell")
end

print("Ambient fish: species pools, welds, depth, heading, solo cruisers, recycling, lake, shallows, shore, fleeing and swell passed")
