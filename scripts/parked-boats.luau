-- Run with node scripts/check-parked-boats.mjs; no Roblox physics runtime.
-- MOCKS --

local checks = 0
local function check(condition, message)
	assert(condition, message)
	checks += 1
end
local function close(a, b, message)
	if (a - b).Magnitude >= 1e-6 then
		print(message, a.X, a.Y, a.Z, "expected", b.X, b.Y, b.Z)
	end
	check((a - b).Magnitude < 1e-6, message)
end
local toObjectSpace = frameMethods.ToObjectSpace
function frameMethods:ToObjectSpace(other)
	-- Keep the exact identity invariant of Roblox's rigid CFrame transforms.
	return if self == other then CFrame.identity else toObjectSpace(self, other)
end
function instanceMethods:GetPivot()
	return self.PrimaryPart.CFrame
end
function instanceMethods:PivotTo(target)
	local before = self:GetPivot()
	for _, piece in self:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.CFrame = target * before:ToObjectSpace(piece.CFrame)
		end
	end
end
local RaycastParams = {
	new = function()
		return {}
	end,
}
workspace = Instance.new("Folder")
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "PlayerBoats", workspace
local character = Instance.new("Model")
local avatar = Instance.new("Part")
avatar.Name, avatar.Parent = "HumanoidRootPart", character
avatar.Size, avatar.CollisionGroup = Vector3.new(2, 2, 1), "Players"
avatar.Anchored = false
local humanoid = Instance.new("Humanoid")
humanoid.Parent = character
humanoid.Health, humanoid.HipHeight = 100, 2
humanoid.MoveDirection = Vector3.zero
humanoid.FloorMaterial = Enum.Material.Wood
local state = Enum.HumanoidStateType.Running
function humanoid:GetState()
	return state
end
local player = { Character = character }
local callbacks = {}
local runService = { PreSimulation = {
	Connect = function(_, callback)
		table.insert(callbacks, callback)
	end,
} }
local services = { Players = { LocalPlayer = player }, ReplicatedStorage = {}, RunService = runService }
game.GetService = function(_, name)
	return services[name]
end
local now, waveScale = 0, 1
function workspace:GetServerTimeNow()
	return now
end
local ground, raycasts
raycasts = 0
function workspace:Raycast(origin, direction, parameters)
	raycasts += 1
	check(
		parameters.FilterDescendantsInstances[1] == character
			and parameters.IgnoreWater
			and parameters.RespectCanCollide
			and parameters.CollisionGroup == avatar.CollisionGroup,
		"Ground queries must ignore self, water and noncolliding decorations"
	)
	check(direction.Y <= -3.75 and origin == avatar.Position, "Ground queries must reach R6 and R15 feet")
	return if ground then { Instance = ground } else nil
end
dependencies.Weather = {
	parkedOffset = function(rest, parkedAt, time)
		local pivot = rest.Position
		return CFrame.new(pivot + Vector3.new(0, math.sin(time - parkedAt) * waveScale, 0))
			* CFrame.Angles(math.sin(time) * 0.08 * waveScale, 0, math.cos(time) * 0.1 * waveScale)
			* CFrame.new(-pivot)
	end,
}
local function boat(name, rest)
	local model = Instance.new("Model")
	model.Name, model.Parent = name, folder
	local root = Instance.new("Part")
	root.Parent, root.CFrame, root.Anchored = model, rest, true
	model.PrimaryPart = root
	model:SetAttribute("Parked", true)
	model:SetAttribute("ParkedFrame", rest)
	model:SetAttribute("ParkedAt", now)
	return model, root
end
local first, firstRoot = boat("Rowboat", CFrame.new(1800, 0, 1800) * CFrame.Angles(0.09, 1, -0.07))
local second, secondRoot = boat("FishingBoat", CFrame.new(-50, 0, 0))
local function loadClient()
	-- CLIENT --
end
local Client = loadClient()
Client.start()
Client.start()
check(#callbacks == 1, "Repeated startup must not duplicate character corrections")
local function step()
	now += 1 / 60
	callbacks[1]()
end
local function place(model, localPosition)
	ground = model.PrimaryPart
	avatar.CFrame = CFrame.new(model.PrimaryPart.CFrame:PointToWorldSpace(localPosition))
	avatar.AssemblyLinearVelocity = Vector3.zero
end
local station = Vector3.new(1, 4, 2)
place(first, station)
step()
for _ = 1, 3600 do
	-- Reproduce solver/contact slip on every frame for a full minute.
	avatar.CFrame += firstRoot.CFrame:VectorToWorldSpace(Vector3.new(0.005, 0, 0.012))
	avatar.AssemblyLinearVelocity = Vector3.new(0.3, -0.1, 0.72)
	step()
	close(
		firstRoot.CFrame:PointToObjectSpace(avatar.Position),
		station,
		"Idle rider must not drift over repeated swells"
	)
	close(
		avatar.AssemblyLinearVelocity,
		Vector3.new(0, -0.1, 0),
		"Idle grip must clear horizontal slip, preserving gravity"
	)
	close(avatar.CFrame.UpVector, Vector3.yAxis, "Carrying must keep the character upright")
end
check(
	(firstRoot.Position - first:GetAttribute("ParkedFrame").Position).Magnitude > 0.01,
	"Regression must exercise an animated hull"
)
humanoid.MoveDirection = Vector3.xAxis
for _ = 1, 30 do
	local before = firstRoot.CFrame:PointToObjectSpace(avatar.Position) + Vector3.new(0.02, 0, 0)
	avatar.CFrame += firstRoot.CFrame:VectorToWorldSpace(Vector3.new(0.02, 0, 0))
	avatar.AssemblyLinearVelocity = Vector3.new(4, 0, 0)
	step()
	close(
		firstRoot.CFrame:PointToObjectSpace(avatar.Position),
		before,
		"Walking must retain input while following the hull"
	)
	close(avatar.AssemblyLinearVelocity, Vector3.new(4, 0, 0), "Walking velocity must remain usable")
end
humanoid.MoveDirection = Vector3.zero
step()
station = firstRoot.CFrame:PointToObjectSpace(avatar.Position)
avatar.CFrame += firstRoot.CFrame:VectorToWorldSpace(Vector3.new(0.01, 0, 0))
step()
close(firstRoot.CFrame:PointToObjectSpace(avatar.Position), station, "Stopping must hold the new deck position")

local function untouched(message)
	local before = avatar.CFrame
	local velocity = Vector3.new(2, 9, 3)
	avatar.AssemblyLinearVelocity = velocity
	step()
	check(avatar.CFrame == before, message)
	close(avatar.AssemblyLinearVelocity, velocity, message .. " (velocity)")
end
humanoid.Jump = true
untouched("A jump request must release grip before takeoff")
humanoid.Jump = false
for _, nextState in
	{
		Enum.HumanoidStateType.Jumping,
		Enum.HumanoidStateType.Freefall,
		Enum.HumanoidStateType.Swimming,
		Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.Dead,
	}
do
	state = nextState
	untouched("Airborne and other movement states must not be dragged by the deck")
end
state = Enum.HumanoidStateType.Running
humanoid.SeatPart = firstRoot
untouched("Seated characters must be carried only by the seat weld")
humanoid.SeatPart = nil
humanoid.Sit = true
untouched("Sitting must not be counteracted while the seat weld is pending")
humanoid.Sit = false
humanoid.FloorMaterial = Enum.Material.Air
untouched("Being above a boat must not count as standing on it")
humanoid.FloorMaterial = Enum.Material.Wood
humanoid.Health = 0
untouched("Dead characters must not be held")
humanoid.Health = 100
ground = nil
untouched("Walking off the edge must release grip")
ground = Instance.new("Part")
untouched("A dock or unrelated floor must not acquire boat grip")
ground = firstRoot
first:SetAttribute("Parked", false)
firstRoot.Anchored = false
untouched("Driving boats must not receive idle corrections")
first:SetAttribute("Parked", true)
firstRoot.Anchored = true
first:SetAttribute("ParkedAt", now)
place(first, Vector3.new(-1, 4, -2))
step()
close(
	firstRoot.CFrame:PointToObjectSpace(avatar.Position),
	Vector3.new(-1, 4, -2),
	"Reparking must acquire the new station"
)
place(second, Vector3.new(2, 4, 3))
step()
close(
	secondRoot.CFrame:PointToObjectSpace(avatar.Position),
	Vector3.new(2, 4, 3),
	"Changing boats must discard the old station"
)
avatar.CFrame += Vector3.new(20, 0, 0)
local teleported = secondRoot.CFrame:PointToObjectSpace(avatar.Position)
step()
close(
	secondRoot.CFrame:PointToObjectSpace(avatar.Position),
	teleported,
	"External teleports must discard the old station"
)
humanoid.HipHeight = 0
step()
player.Character = nil
untouched("Respawning must discard the previous character")
player.Character = character
place(second, Vector3.new(-2, 4, 0))
step()
close(
	secondRoot.CFrame:PointToObjectSpace(avatar.Position),
	Vector3.new(-2, 4, 0),
	"Returning character must acquire its current station"
)
folder.Parent = nil
untouched("Streaming out the boat folder must release grip")
folder.Parent = workspace
place(second, Vector3.new(0, 4, -3))
step()
close(
	secondRoot.CFrame:PointToObjectSpace(avatar.Position),
	Vector3.new(0, 4, -3),
	"Streaming back must not restore a stale station"
)
print("Parked boats: " .. checks .. " checks passed; minute of swell/slip, walking, jumping, seats and lifecycle")
