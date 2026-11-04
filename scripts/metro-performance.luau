-- Run with node scripts/check-metro.mjs --performance-only.
-- Uses the real train and client controller without depending on station geometry.
local Schedule, Train = require("MetroSchedule"), require("MetroTrain")
local dock = CFrame.new(120, -30, -600) * CFrame.Angles(0, 0.4, 0)
local model, doors = Train.build(workspace, dock, false)
local originals, doorByPart = {}, {}
for _, part in model:GetDescendants() do
	if part:IsA("BasePart") then originals[part] = dock:ToObjectSpace(part.CFrame) end
end
for _, door in doors do doorByPart[door.part] = door end
Train.pose(model, doors, dock, 1)
check(bulkCalls == 1 and bulkParts == #doors, "Parked trains only move doors and glass")
Train.pose(model, doors, dock * CFrame.new(), 1)
check(bulkCalls == 1, "Unchanged train poses do no engine work")
local travelled = dock * CFrame.new(123, 0, -8) * CFrame.Angles(0, 0.6, 0)
Train.pose(model, doors, travelled, 0.4)
check(bulkCalls == 2 and bulkParts > #doors, "Moving trains use one batch for body and doors")
local partCount = 0
for part, closed in originals do
	partCount += 1
	local door = doorByPart[part]
	local expected = travelled * closed * (if door then CFrame.new(door.direction * 0.4 * 2.7, 0, 0) else CFrame.identity)
	check((part.Position - expected.Position).Magnitude < 0.0001, "Part offsets survive movement: " .. part.Name)
	check((part.CFrame.RightVector - expected.RightVector).Magnitude < 0.0001, "Part rotations survive movement: " .. part.Name)
end
check(bulkParts == partCount, "Every train part moves exactly once")
Train.pose(model, doors, travelled, 0.8)
check(bulkCalls == 3 and bulkParts == #doors, "Door animation leaves the parked body alone")
model:Destroy()

local function stop(name, frame)
	local station = Instance.new("Model")
	station.Name, station.Parent = name, workspace
	local marker = Instance.new("Part")
	marker.Name, marker.CFrame, marker.Parent = "TrainDock", frame, station
	return station
end
local source = stop("Source", dock)
local destination = stop("Destination", dock * CFrame.new(5000, 0, 5000))
collection.tagged = { source, destination }
local player = Instance.new("Player")
player.CharacterRemoving = signal()
player.Character = Instance.new("Model")
local humanoid = Instance.new("Humanoid")
humanoid.Parent = player.Character
players.LocalPlayer = player
local playerGui = Instance.new("PlayerGui")
playerGui.Name, playerGui.Parent = "PlayerGui", player
function methods:WaitForChild(name) return assert(self:FindFirstChild(name), "Missing mock child " .. name) end
local transit = Instance.new("Folder")
transit.Name, transit.Parent = "MetroTransit", replicated
transit:SetAttribute("Ready", true)
local remote = Instance.new("RemoteEvent")
remote.Name, remote.Parent, remote.OnClientEvent = "Ride", transit, signal()
local render, clientHeartbeat = nil, signal()
Enum.RenderPriority.Camera = { Value = 200 }
local previousServices = game.GetService
game.GetService = function(self, name)
	if name == "RunService" then
		return { Heartbeat = clientHeartbeat, BindToRenderStep = function(_, _, _, callback) render = callback end }
	end
	return previousServices(self, name)
end
local camera = Instance.new("Camera")
camera.CFrame, camera.CameraType, camera.FieldOfView = dock, Enum.CameraType.Custom, 74
camera.CameraSubject, workspace.CurrentCamera = humanoid, camera
require("MetroClient").start()
now = 10
render()
local visuals = workspace.MetroVisuals
check(#visuals:GetChildren() == 0, "Stop registration and rendering never build trains")
clientHeartbeat:Fire()
check(#visuals:GetChildren() == 1, "Heartbeat builds the nearby train")
clientHeartbeat:Fire()
render()
check(#visuals:GetChildren() == 1, "The preloaded destination never builds a distant train")
local sourceVisual = visuals:GetChildren()[1]
now = 26
local payload = { origin = "Gullhaven", destination = "Hafen Mitte", dock = dock, departure = 26, arrival = 68 }
remote.OnClientEvent:Fire("Depart", payload)
render()
check(camera.CameraType == Enum.CameraType.Scriptable and playerGui.MetroJourney.Enabled, "Departure starts the journey camera")
now = 36
render()
check(sourceVisual.Parent == visuals, "Entering the tunnel keeps the train registered")
remote.OnClientEvent:Fire("Transfer", { dock = destination.TrainDock.CFrame })
now = 48
render()
clientHeartbeat:Fire()
render()
check(#visuals:GetChildren() == 2, "Destination train builds after camera transfer")
check((camera.CFrame.Position - destination.TrainDock.Position).Magnitude < 400, "Camera follows the destination train")
remote.OnClientEvent:Fire("Arrive")
check(camera.CameraType == Enum.CameraType.Custom and camera.FieldOfView == 74 and not playerGui.MetroJourney.Enabled, "Arrival restores the camera")
remote.OnClientEvent:Fire("Depart", payload)
render()
player.CharacterRemoving:Fire()
check(camera.CameraType == Enum.CameraType.Custom and not playerGui.MetroJourney.Enabled, "Respawn restores the camera")
collection.removed:Fire(destination)
check(#visuals:GetChildren() == 1, "A streamed-out station releases its visual train")
local unloaded = stop("Unloaded", dock * CFrame.new(8000, 0, 0))
collection.added:Fire(unloaded)
collection.removed:Fire(unloaded)
clientHeartbeat:Fire()
check(#visuals:GetChildren() == 1, "A station can stream out before its train is built")
output("Metro performance: " .. checks .. " movement, geometry and client lifecycle checks passed")
