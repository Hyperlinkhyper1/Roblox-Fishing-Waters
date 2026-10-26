-- MOCKS --

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
local water, roof, lake = true, false, false
local rays = 0
function workspace:Raycast(origin, direction, params)
	rays += 1
	if direction.Y > 0 then
		assert(params.IgnoreWater and params.RespectCanCollide, "Only solid roofs should shelter audio")
		return if roof then {} else nil
	end
	assert(params.FilterType == Enum.RaycastFilterType.Include, "Water probes must ignore docks, hulls and characters")
	assert(params.FilterDescendantsInstances[1] == self.Terrain and not params.IgnoreWater, "Probe real Terrain water")
	return if water then { Material = Enum.Material.Water, Position = Vector3.new(origin.X, 0, origin.Z) } else nil
end
local players = { PlayerAdded = signal(), PlayerRemoving = signal() }
local roster = {}
function players:GetPlayers()
	return roster
end
local function makeCharacter(player)
	local character = Instance.new("Model")
	character.Parent = workspace
	local root = Instance.new("Part")
	root.Name, root.Parent = "HumanoidRootPart", character
	root.CFrame, root.AssemblyLinearVelocity = CFrame.new(0, 6, 0), Vector3.zero
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent, humanoid.Health, humanoid.MoveDirection = character, 100, Vector3.zero
	humanoid.State = Enum.HumanoidStateType.Running
	humanoid.FloorMaterial = Enum.Material.Air
	function humanoid:GetState()
		return self.State
	end
	player.Character = character
	return character, root, humanoid
end
local function makePlayer()
	local player = { CharacterAdded = signal(), CharacterRemoving = signal() }
	local character, root, humanoid = makeCharacter(player)
	table.insert(roster, player)
	return player, character, root, humanoid
end
local player, character, root, humanoid = makePlayer()
players.LocalPlayer = player
local heartbeat = signal()
local preloadCount = 0
local services = {
	Players = players,
	SoundService = soundService,
	RunService = { Heartbeat = heartbeat },
	ReplicatedStorage = {},
	ContentProvider = {
		PreloadAsync = function(_, assets)
			preloadCount += 1
			assert(#assets == 4, "Preload surf and Roblox's bundled water/wind cues")
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
dependencies.Biomes = { MapHalfSize = 5200, SeaFloor = -64, WaterLevel = 0 }
local weather = { windSpeed = 6 }
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
	for _ = 1, math.ceil((seconds or 1 / 60) * 60) do
		clock += 1 / 60
		heartbeat:Fire(1 / 60)
	end
end
local function move(x, y, z)
	workspace.CurrentCamera.CFrame = CFrame.new(x, y, z)
end
local function enter(speed)
	root.AssemblyLinearVelocity = Vector3.new(0, -speed, 0)
	humanoid.State = Enum.HumanoidStateType.Freefall
	root.CFrame = CFrame.new(0, 4, 0)
	step()
	root.CFrame = CFrame.new(0, -1, 0)
	root.AssemblyLinearVelocity = Vector3.zero
	humanoid.State = Enum.HumanoidStateType.Swimming
	step()
end

Client.start()
Client.start()
assert(preloadCount == 1 and #soundService:GetChildren() == 1, "Startup must be idempotent")
local ambience = soundService:FindFirstChild("EnvironmentAudio")
local waves, wind, underwater =
	ambience:FindFirstChild("OceanWaves"),
	ambience:FindFirstChild("CoastalWind"),
	ambience:FindFirstChild("UnderwaterWash")
step(3)
assert(waves.Volume > 0.2 and wind.Volume > 0.08, "Calm weather must still have audible water and wind")
assert(waves.PlayCount == 1 and wind.PlayCount == 1, "Steady ambience must never restart each frame")
assert(underwater.Volume == 0, "Underwater wash must stay silent above water")
for _, cue in { waves, wind, underwater } do
	assert(cue:GetAttribute("AudioCategory") == "Effects", "Ambience must respect the effects slider")
end
local clearWind = wind.Volume
weather.windSpeed = 52
step(3)
assert(wind.Volume > clearWind * 2 and waves.Volume > 0.4, "Storm wind and waves must rise with weather")
local exposedWaves, exposedWind = waves.Volume, wind.Volume
roof = true
step(3)
assert(waves.Volume < exposedWaves * 0.3 and wind.Volume < exposedWind * 0.35, "Indoor ambience must fade down")
roof = false
lake = true
step(3)
assert(waves.Volume < exposedWaves * 0.8 and waves.Volume > 0.2, "The sheltered lake needs a gentler audible wash")
water = false
step(3)
assert(
	waves.Volume == 0 and not waves.IsPlaying and wind.Volume > 0.2,
	"Inland water should fade out while wind continues"
)
water = true
move(0, -4, 0)
step(3)
assert(
	underwater.Volume > 0.3 and waves.Volume < 0.02 and wind.Volume < 0.03,
	"Diving must replace outdoor noise with a muffled wash"
)
local eq = underwater:FindFirstChildOfClass("EqualizerSoundEffect")
assert(eq.HighGain < -20 and eq.MidGain < -10, "Underwater wash must remove surface hiss")
move(0, -0.05, 0)
step(0.5)
assert(underwater.Volume > 0.3, "Waterline hysteresis must prevent audio flicker")
move(0, 8, 0)
step(3)
assert(
	underwater.Volume == 0 and not underwater.IsPlaying and waves.Volume > 0.2,
	"Surfacing must restore outdoor ambience"
)
local raysBefore = rays
step(1)
assert(rays - raysBefore <= 42, "Shoreline sampling must stay bounded instead of raycasting every frame")

local splash = root:FindFirstChild("WaterSplash")
local swim = root:FindFirstChild("WaterSwimming")
assert(splash and swim and not splash.IsPlaying and swim.Volume == 0, "Fallback character cues must start silently")
enter(12)
assert(splash.PlayCount == 1 and splash.Volume >= 0.5, "A normal water entry must produce an audible splash")
local gentle = splash.Volume
step(1)
assert(splash.PlayCount == 1, "Treading water must not keep splashing")
root.CFrame = CFrame.new(0, -4, 0)
humanoid.State = Enum.HumanoidStateType.Freefall
step(1)
humanoid.State = Enum.HumanoidStateType.Swimming
step(1)
assert(splash.PlayCount == 1, "Underwater state changes must not replay a surface splash")
root.AssemblyLinearVelocity = Vector3.new(8, 0, 0)
step(1)
assert(swim.IsPlaying and swim.Volume > 0.25, "Moving through water must have swimming sounds")
root.AssemblyLinearVelocity = Vector3.zero
step(3)
assert(swim.Volume == 0 and not swim.IsPlaying, "Idle swimmers must not loop full-volume strokes")
enter(65)
assert(splash.PlayCount == 2 and splash.Volume > gentle, "A larger plunge must sound stronger")
step()
enter(65)
assert(splash.PlayCount == 2, "Rapid state flicker must not spam splashes")
step(1)
humanoid.State = Enum.HumanoidStateType.Running
humanoid.FloorMaterial = Enum.Material.Wood
root.CFrame = CFrame.new(0, -2, 0)
step(1)
assert(splash.PlayCount == 2 and swim.Volume < 0.02, "A dry boat floor below sea level must not sound like swimming")
humanoid.SeatPart = Instance.new("Seat")
enter(65)
assert(splash.PlayCount == 2, "Seated boats must not trigger player plunges")
humanoid.SeatPart = nil
humanoid.Health = 0
enter(65)
assert(splash.PlayCount == 2, "Dead characters must not produce new water entries")
humanoid.Health = 100
humanoid.State = Enum.HumanoidStateType.Running
root.CFrame = CFrame.new(0, 6, 0)
step(1)

-- Roblox may create its character sounds after our own emitters.
local nativeSplash = Instance.new("Sound")
nativeSplash.Name, nativeSplash.Parent = "Splash", root
nativeSplash.SoundId = "rbxasset://sounds/impact_water.mp3"
nativeSplash.Looped, nativeSplash.Volume = false, 0
local nativeSwim = Instance.new("Sound")
nativeSwim.Name, nativeSwim.Parent = "Swimming", root
nativeSwim.SoundId = "rbxasset://sounds/action_swim.mp3"
nativeSwim.Looped, nativeSwim.Volume = true, 0
step(1)
assert(splash.Parent == root and swim.Parent == root, "Late default sounds must preserve the active emitters")
assert(
	nativeSplash.SoundId == "" and nativeSwim.SoundId == "",
	"Default water cues must be silent to avoid duplicate playback"
)
nativeSwim.Volume = 1 -- Simulate the default controller updating its own loop.
enter(35)
assert(splash.PlayCount == 3 and splash.Volume > 0.5, "Water entry must keep working after default audio arrives")
assert(nativeSwim.SoundId == "" and swim.Volume < 0.6, "Default volume updates must not overpower the water mix")
assert(splash.RollOffMaxDistance == 100, "Other swimmers must attenuate with distance")

local other, otherCharacter, otherRoot, otherHumanoid = makePlayer()
players.PlayerAdded:Fire(other)
otherRoot.CFrame = CFrame.new(500, 6, 0)
step(1)
otherRoot.CFrame = CFrame.new(500, -1, 0)
otherHumanoid.State = Enum.HumanoidStateType.Swimming
step(1)
assert(not otherRoot:FindFirstChild("WaterSplash").IsPlaying, "Distant players must not trigger audible splashes")
players.PlayerRemoving:Fire(other)
assert(#otherRoot:GetChildren() == 0, "Leaving players must release their fallback sounds")
player.CharacterRemoving:Fire(character)
assert(nativeSplash.Parent == root and nativeSwim.Parent == root, "Cleanup must preserve engine-owned character sounds")
assert(nativeSplash.SoundId ~= "" and nativeSwim.SoundId ~= "", "Cleanup must restore the default cues")
local replacement, replacementRoot = makeCharacter(player)
player.CharacterAdded:Fire(replacement)
step(1)
assert(replacementRoot:FindFirstChild("WaterSplash"), "Respawns must receive water audio again")
player.CharacterRemoving:Fire(replacement)
assert(#replacementRoot:GetChildren() == 0, "Respawns must release owned emitters")

local camera = workspace.CurrentCamera
workspace.CurrentCamera = nil
step(1)
assert(waves.Volume == 0 and wind.Volume == 0 and underwater.Volume == 0, "A missing camera must silence ambience")
workspace.CurrentCamera = camera
move(6000, 8, 0)
step(3)
assert(waves.Volume == 0 and wind.Volume == 0, "Audio must not leak beyond the ocean map")
move(0, 8, 0)
step(1)
assert(waves.IsPlaying and wind.IsPlaying, "Camera recovery must resume the existing loops")
print(
	"Environment audio: weather/shore/roof/dive mixing, bounded probes, splash strength, no duplicates, respawns and distance passed"
)
