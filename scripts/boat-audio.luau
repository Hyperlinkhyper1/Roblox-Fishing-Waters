-- Exercise the actual client mixer; asset playback still requires Studio.
local catalog = (function()
	-- BOAT_CATALOG_SOURCE --
end)()
local folder = {}
local children = {}
local sounds = {}
local scans, velocityReads = 0, 0
local callback, connections = nil, 0
local game = {}
function game:GetService(name)
	if name == "ReplicatedStorage" then return {} end
	return { Heartbeat = { Connect = function(_, fn) callback = fn; connections += 1 end } }
end
local workspace = {}
local present = true
function workspace:FindFirstChild() return if present then folder else nil end
function folder:GetChildren() scans += 1; return children end
local Enum = { RollOffMode = { InverseTapered = "InverseTapered" } }
local Vector2 = { new = function(x, y) return { Magnitude = math.sqrt(x * x + y * y) } end }
local Instance = {}
function Instance.new(kind)
	assert(kind == "Sound")
	local sound = { IsPlaying = false, plays = 0, stops = 0 }
	function sound:Play() self.IsPlaying = true; self.plays += 1 end
	function sound:Stop() self.IsPlaying = false; self.stops += 1 end
	function sound:Destroy() self.destroyed = true; self.IsPlaying = false end
	table.insert(sounds, sound)
	return sound
end
local function boat(id)
	local model = { Parent = folder, attributes = { BoatId = id, RowThrottle = 0 } }
	local root = setmetatable({ velocity = { X = 0, Z = 0 } }, {
		__index = function(self, key)
			if key == "AssemblyLinearVelocity" then velocityReads += 1; return self.velocity end
		end,
		__newindex = function(self, key, value)
			if key == "AssemblyLinearVelocity" then self.velocity = value else rawset(self, key, value) end
		end,
	})
	local seat = {}
	function root:IsDescendantOf(parent) return parent == model and model.PrimaryPart == self end
	function seat:IsDescendantOf(parent) return parent == model end
	function seat:IsA(kind) return kind == "VehicleSeat" end
	function model:IsA(kind) return kind == "Model" end
	function model:GetAttribute(key) return self.attributes[key] end
	function model:FindFirstChild() return seat end
	model.PrimaryPart = root
	table.insert(children, model)
	return model, seat, root
end
local rowboat = boat("Rowboat")
local fishingBoat, seat, root = boat("FishingBoat")
local Audio = (function()
	-- BOAT_AUDIO_SOURCE --
end)()
Audio.start()
Audio.start()
assert(connections == 1, "Mixer must only start once")
callback(1 / 60)
assert(#sounds == 1 and sounds[1].Parent == root, "Only engine boats have positional audio")
local sound = sounds[1]
assert(sound.SoundId == catalog.FishingBoat.EngineSoundId and sound.Looped, "Use catalog library audio in a loop")
assert(sound.plays == 0, "Unoccupied boats must be silent")
for _, fps in { 30, 60, 144 } do
	local beforeScans, beforeReads = scans, velocityReads
	for _ = 1, fps do callback(1 / fps) end
	assert(scans - beforeScans <= 5, "Discovery must stay bounded as frame rate rises")
	assert(velocityReads == beforeReads, "Silent engines must not read boat velocity every frame")
end
seat.Occupant = { Health = 100 }
for _ = 1, 120 do callback(1 / 60) end
local idlePitch, idleVolume = sound.PlaybackSpeed, sound.Volume
assert(sound.plays == 1 and idleVolume > 0.1, "Occupied parked boat must idle without restarting the loop")
fishingBoat.attributes.RowThrottle = 1
callback(1 / 60)
assert(sound.PlaybackSpeed > idlePitch and sound.PlaybackSpeed < 1.39, "Rev changes must blend smoothly")
for _ = 1, 120 do callback(1 / 60) end
assert(sound.Volume > idleVolume and sound.PlaybackSpeed > 1.3, "Throttle must rev the engine")
local forwardPitch = sound.PlaybackSpeed
fishingBoat.attributes.RowThrottle = -1
for _ = 1, 120 do callback(1 / 60) end
assert(math.abs(sound.PlaybackSpeed - forwardPitch) < 0.001, "Reverse must also rev the engine")
fishingBoat.attributes.RowThrottle = 0
root.AssemblyLinearVelocity = { X = catalog.FishingBoat.ForwardSpeed, Z = 0 }
for _ = 1, 120 do callback(1 / 60) end
assert(sound.PlaybackSpeed > forwardPitch, "Cruising speed must sustain engine revs")
seat.Occupant = nil
for _ = 1, 120 do callback(1 / 60) end
assert(sound.Volume == 0 and not sound.IsPlaying and sound.stops == 1, "Dismount must fade and stop despite motion")
seat.Occupant = { Health = 0 }
callback(1 / 60)
assert(not sound.IsPlaying, "A dead driver must not run the engine")
seat.Occupant = { Health = 100 }
callback(1 / 60)
assert(sound.plays == 2, "Boarding again must restart the engine")
fishingBoat.Parent = nil
callback(1 / 60)
assert(sound.destroyed, "Stream-out or boat removal must destroy the local sound")
children = { rowboat }
callback(1 / 60)
assert(#sounds == 1, "A removed boat must not create a new sound")
fishingBoat.Parent = folder
table.insert(children, fishingBoat)
for _ = 1, 16 do callback(1 / 60) end
assert(#sounds == 2 and sounds[2].IsPlaying, "Stream-in must recreate the engine")
present = false
fishingBoat.Parent = nil
callback(1 / 60)
assert(sounds[2].destroyed, "Removing the entire folder must also clear sounds")
-- A root can arrive after its model during streaming, and a folder can be replaced.
present = true
local lateBoat, lateSeat, lateRoot = boat("FishingBoat")
lateBoat.PrimaryPart = nil
lateSeat.Occupant = { Health = 100 }
children = { lateBoat }
callback(1 / 60)
assert(#sounds == 2, "An incomplete boat must wait for its root")
lateBoat.PrimaryPart = lateRoot
for _ = 1, 16 do callback(1 / 60) end
assert(#sounds == 3 and sounds[3].IsPlaying, "Discovery must retry partially streamed boats")
folder = {}
function folder:GetChildren() scans += 1; return {} end
callback(1 / 60)
assert(sounds[3].destroyed, "Replacing the boat folder must release old sounds immediately")
print("Boat audio lifecycle and bounded discovery checks passed at 30/60/144 FPS (mock sound)")
