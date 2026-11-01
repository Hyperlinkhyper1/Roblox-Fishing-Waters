-- MOCKS --

-- Runs the real CoastalAmbience mixer against recording mocks: which layers
-- play on open water, a beach, by day and night, underwater and in the rain.
-- Playback quality, loop seams and asset delivery still need a Studio listen.
NumberRange = {
	new = function(low, high)
		return { Min = low, Max = high or low }
	end,
}
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
function instanceMethods:Play()
	self.IsPlaying = true
	self.PlayCount = (self.PlayCount or 0) + 1
end
function instanceMethods:Stop()
	self.IsPlaying = false
end
local newInstance = Instance.new
Instance.new = function(class)
	local item = newInstance(class)
	if class == "Sound" then
		item.TimeLength, item.TimePosition = 40, 0
	end
	return item
end
local soundService = Instance.new("Folder")
workspace = Instance.new("Folder")
workspace.Terrain = Instance.new("Terrain")
workspace.Terrain.Parent = workspace
workspace.CurrentCamera = Instance.new("Camera")
workspace.CurrentCamera.CFrame = CFrame.new(0, 8, 0)
workspace.CurrentCamera.Parent = workspace
function workspace:GetServerTimeNow()
	return clock
end
-- Land lies east of `shoreX`; everything else is sea.
local shoreX = math.huge
local roof = false
local rays = 0
function workspace:Raycast(origin, direction, params)
	rays += 1
	if direction.Y > 0 then
		assert(params.IgnoreWater and params.RespectCanCollide, "Only solid roofs should shelter ambience")
		return if roof then {} else nil
	end
	assert(params.FilterType == Enum.RaycastFilterType.Include, "Coast probes must ignore docks, hulls and characters")
	assert(params.FilterDescendantsInstances[1] == self.Terrain and not params.IgnoreWater, "Probe real Terrain water")
	if origin.X > shoreX then
		return { Material = Enum.Material.Sand, Position = Vector3.new(origin.X, 3, origin.Z) }
	end
	return { Material = Enum.Material.Water, Position = Vector3.new(origin.X, 0, origin.Z) }
end
local players = { PlayerAdded = signal(), PlayerRemoving = signal() }
function players:GetPlayers()
	return {}
end
local heartbeat = signal()
local preloaded = {}
local preloadCount = 0
local services = {
	Players = players,
	SoundService = soundService,
	RunService = { Heartbeat = heartbeat },
	ReplicatedStorage = {},
	ContentProvider = {
		PreloadAsync = function(_, assets)
			preloadCount += 1
			preloaded = assets
		end,
	},
}
game.GetService = function(_, name)
	assert(services[name], name)
	return services[name]
end
task.spawn = function(callback)
	callback()
end
dependencies.Biomes = {
	WaterLevel = 0,
	SeaFloor = -64,
	inOceanBounds = function(position)
		return math.abs(position.X) < 5200 and math.abs(position.Z) < 5200
	end,
}
local darkness = 0
dependencies.DayNight = {
	clockTime = function()
		return 12
	end,
	darkness = function()
		return darkness
	end,
}
local weather = { windSpeed = 6, rain = 0, storm = 0 }
local lake = false
dependencies.Weather = {
	getState = function()
		return weather
	end,
	inLake = function()
		return lake
	end,
}
local Client = (function()
	-- CLIENT --
end)()

local function step(seconds)
	for _ = 1, math.ceil(seconds * 60) do
		clock += 1 / 60
		heartbeat:Fire(1 / 60)
	end
end
local function move(x, y, z)
	workspace.CurrentCamera.CFrame = CFrame.new(x, y, z)
end

Client.start()
Client.start()
assert(preloadCount == 1 and #soundService:GetChildren() == 1, "Startup must be idempotent")
assert(#preloaded == 7, "Preload the four beds and three gull calls")
local folder = soundService:FindFirstChild("CoastalAmbience")
local sea, hull, surf, crickets =
	folder:FindFirstChild("SeaLap"),
	folder:FindFirstChild("HullLap"),
	folder:FindFirstChild("ShoreSurf"),
	folder:FindFirstChild("Crickets")
for _, loop in { sea, hull, surf, crickets } do
	assert(loop.Looped and loop:GetAttribute("AudioCategory") == "Effects", loop.Name .. " must be an effects loop")
	assert(string.match(loop.SoundId, "^rbxassetid://%d+$"), loop.Name .. " must use a licensed asset id")
end
local gull = workspace.Terrain:FindFirstChild("GullCall"):FindFirstChild("Gull")
assert(gull and not gull.Looped and gull.RollOffMaxDistance > 100, "Gulls are positional one-shots")

-- Open sea, standing on a low deck.
step(8)
assert(sea.Volume > 0.15 and hull.Volume > 0.1, "Open water near the surface laps")
assert(surf.Volume < 0.01 and not surf.IsPlaying, "No surf without a shore")
assert(sea.PlayCount == 1, "Steady beds must never restart each frame")
assert((gull.PlayCount or 0) == 0, "No gulls far from land")

-- High above the sea the hull slap goes and the bed thins.
move(0, 90, 0)
step(6)
assert(hull.Volume < 0.01 and sea.Volume < 0.12, "Climbing away from the water fades the surface layers")

-- Beach: land to the east.
shoreX = 20
move(0, 8, 0)
step(8)
assert(surf.Volume > 0.2, "A beach must have surf")
assert(crickets.Volume < 0.01, "No crickets by day")
step(60)
assert((gull.PlayCount or 0) >= 2, "Daytime coasts get regular gull calls")
local anchor = gull.Parent
local offset = anchor.WorldPosition - workspace.CurrentCamera.CFrame.Position
assert(offset.Y >= 12 and Vector3.new(offset.X, 0, offset.Z).Magnitude >= 35, "Gulls call from above and around")

-- The lake gets gentler surf.
local seaSurf = surf.Volume
lake = true
step(8)
assert(surf.Volume < seaSurf * 0.7 and surf.Volume > 0.05, "Lake shores roll in softer")
lake = false

-- Night: crickets on, gulls off.
darkness = 1
step(8)
assert(crickets.Volume > 0.07, "Night shores have crickets")
local gullsAtDusk = gull.PlayCount
step(60)
assert(gull.PlayCount == gullsAtDusk, "Gulls sleep at night")

-- Rain silences gulls by day too.
darkness, weather = 0, { windSpeed = 8, rain = 0.8, storm = 0 }
local gullsBeforeRain = gull.PlayCount
step(60)
assert(gull.PlayCount == gullsBeforeRain, "No gulls in the rain")

-- Storm surf grows.
weather = { windSpeed = 40, rain = 0.5, storm = 0.9 }
step(8)
assert(surf.Volume > seaSurf * 1.2, "Storms raise the surf")
weather = { windSpeed = 6, rain = 0, storm = 0 }

-- Indoors ducks everything.
step(8)
local open = surf.Volume
roof = true
step(8)
assert(surf.Volume < open * 0.45, "A roof overhead muffles the coast")
roof = false

-- Underwater silences every surface layer.
move(0, -6, 0)
step(8)
assert(sea.Volume < 0.01 and hull.Volume < 0.01 and surf.Volume < 0.01, "Diving must silence surface ambience")

-- Sampling stays bounded.
move(0, 8, 0)
local before = rays
step(1)
assert(rays - before <= 2 * 18, "Coast sampling must stay bounded instead of raycasting every frame")

-- A missing camera fades everything out.
workspace.CurrentCamera = nil
step(8)
assert(sea.Volume < 0.01 and surf.Volume < 0.01, "A missing camera must silence ambience")

print("Coastal ambience: open sea, beach, lake, night, rain, storm, roof, dive and bounded sampling passed")
