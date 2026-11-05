-- MOCKS --
local callback, connections, time = nil, 0, 0
local settingsWrites, ranges, samples, clears = 0, 0, 0, 0
local originalWrite = instanceMt.__newindex
function instanceMt.__newindex(self, key, value)
	if self.ClassName == "ParticleEmitter" then settingsWrites += 1 end
	originalWrite(self, key, value)
end
local makeRange = NumberRange.new
function NumberRange.new(...)
	ranges += 1
	return makeRange(...)
end
function instanceMethods:Clear()
	assert(self:IsA("ParticleEmitter"))
	clears += 1
end
game.GetService = function(_, name)
	return if name == "RunService" then {
		Heartbeat = { Connect = function(_, fn) callback = fn; connections += 1 end },
	} else {}
end
dependencies.BoatCatalog = {
	Motorboat = { DriverSeat = "Helm", Beam = 10, Length = 24, ForwardSpeed = 50,
		StarterParts = { { PartId = "Engine" } } },
}
dependencies.Cargo = { Parts = { Engine = { Motor = true } } }
dependencies.Biomes = { WaterLevel = 0 }
local waveHeight = 0
dependencies.Weather = { sample = function()
	samples += 1
	return { height = waveHeight }
end }
workspace = Instance.new("Folder")
workspace.CurrentCamera = { CFrame = CFrame.new(0, 10, 0) }
function workspace:GetServerTimeNow() return time end
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "PlayerBoats", workspace
local model = Instance.new("Model")
model:SetAttribute("BoatId", "Motorboat")
model.Parent = folder
local hull = Instance.new("Part")
hull.AssemblyLinearVelocity = Vector3.new(0, 0, -25)
hull.Parent = model
model.PrimaryPart = hull
local seat = Instance.new("VehicleSeat")
seat.Name, seat.Parent = "Helm", model
seat.Occupant = { Health = 100 }
local Spray = (function()
	-- BOAT_SPRAY --
end)()
Spray.start()
Spray.start()
assert(connections == 1, "Spray startup must be idempotent")
local function tick(dt) time += dt; callback(dt) end
local function advance(seconds, fps)
	for _ = 1, math.ceil(seconds * fps) do tick(1 / fps) end
end
local function jets()
	local found = {}
	for _, item in model:GetDescendants() do
		if item:IsA("ParticleEmitter") then table.insert(found, item) end
	end
	return found
end
advance(0.1, 60)
local emitters = jets()
assert(#emitters == 2 and emitters[1].Enabled and emitters[1].Rate > 25, "A moving motorboat must spray at both sides")
for _, fps in { 30, 60, 144 } do
	local beforeSamples, beforeRanges, beforeWrites = samples, ranges, settingsWrites
	advance(1, fps)
	assert(samples - beforeSamples <= 21, "Spray water samples must remain bounded at " .. fps .. " FPS")
	assert(ranges == beforeRanges and settingsWrites == beforeWrites, "Steady spray must reuse its settings")
end
hull.AssemblyLinearVelocity = Vector3.new(0, 0, -50)
local beforeRanges = ranges
advance(0.1, 60)
assert(emitters[1].Rate == 110 and ranges == beforeRanges + 1, "Both jets must share one speed range per speed change")
seat.Occupant = nil
advance(0.1, 60)
assert(not emitters[1].Enabled and emitters[1].Rate == 0, "Dismount must stop new spray")
local beforeWrites = settingsWrites
beforeRanges = ranges
advance(1, 144)
assert(settingsWrites == beforeWrites and ranges == beforeRanges, "Idle emitters must not keep receiving property writes")
seat.Occupant = { Health = 100 }
advance(0.1, 60)
assert(emitters[1].Enabled and emitters[1].Rate == 110, "Boarding must restore spray even at the same speed")
workspace.CurrentCamera.CFrame = CFrame.new(1000, 10, 0)
advance(0.1, 60)
assert(not emitters[1].Enabled and clears == 2, "Leaving visual range must clear both jets once")
beforeWrites = settingsWrites
local beforeSamples = samples
advance(1, 144)
assert(clears == 2 and settingsWrites == beforeWrites and samples == beforeSamples, "Distant jets must remain dormant")
workspace.CurrentCamera.CFrame = CFrame.new(0, 10, 0)
advance(0.1, 60)
assert(emitters[1].Enabled, "Returning to visual range must reactivate spray")
model:SetAttribute("MotorCount", 0)
advance(0.1, 60)
assert(not emitters[1].Enabled, "Removing every motor must disable spray")
model:SetAttribute("MotorCount", 1)
model:SetAttribute("Hoisted", true)
advance(0.1, 60)
assert(not emitters[1].Enabled, "Hoisted boats must not spray")
model:SetAttribute("Hoisted", false)
waveHeight = -20
advance(0.1, 60)
assert(not emitters[1].Enabled, "A hull above the water must not spray")
waveHeight = 0
advance(0.1, 60)
assert(emitters[1].Enabled, "Landing back on the water must restore spray")
local beforeSlowFrame = samples
tick(2)
assert(samples == beforeSlowFrame + 1, "A slow frame must not cause catch-up bursts")
local oldAttachments = { emitters[1].Parent, emitters[2].Parent }
model.Parent = nil
advance(0.1, 60)
assert(oldAttachments[1].Parent == nil and oldAttachments[2].Parent == nil, "Streaming out must destroy local spray attachments")
model.Parent = folder
advance(0.4, 60)
assert(#jets() == 2 and jets()[1].Enabled, "Streaming back in must recreate exactly two jets")
workspace.CurrentCamera = nil
advance(0.1, 60)
assert(not jets()[1].Enabled, "Camera removal must stop spray")
print("Boat spray lifecycle, idle-write and sample-budget checks passed at 30/60/144 FPS (recording mocks)")
