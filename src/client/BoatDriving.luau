-- Drives the local player's own hull. While they are at the helm the server hands this
-- client network ownership of the boat (BoatService setDriver), and from then on the movers
-- are steered here every physics step from local input, with the same shared BoatDrive code
-- the server uses. The helm answers at once and the hull never waits on replication.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BoatCatalog = require(ReplicatedStorage.Shared.BoatCatalog)
local BoatDrive = require(ReplicatedStorage.Shared.BoatDrive)
local BoatMotion = require(ReplicatedStorage.Shared.BoatMotion)

local BoatDriving = {}
local started = false
local helm: Model? = nil
local helmThrottle, helmSteer = 0, 0
local hull = nil

-- Called every frame by Boating with the hull at the local player's helm (or nil).
function BoatDriving.setInput(model: Model?, throttle: number, steer: number)
	helm, helmThrottle, helmSteer = model, throttle, steer
end

-- Refits retune the spec, so it is read from the hull's attributes each step.
local function readSpec(model: Model, spec)
	for _, field in BoatDrive.FIELDS do
		local value = model:GetAttribute("Drive" .. field)
		if type(value) == "number" then
			spec[field] = value
		end
	end
end

local function prepare(model: Model)
	local root = model.PrimaryPart
	local base = BoatCatalog[model:GetAttribute("BoatId")]
	local waterline = model:GetAttribute("WaterlineRootOffset")
	if not root or not base or typeof(waterline) ~= "Vector3" then
		return nil
	end
	local float = root:FindFirstChild("Waterline")
	local lift = root:FindFirstChild("WeightSupport")
	local heading = root:FindFirstChild("UprightHeading")
	local velocity = root:FindFirstChild("Rowing")
	local driveAttachment = root:FindFirstChild("BoatDrive")
	if not (float and lift and heading and velocity and driveAttachment) then
		return nil
	end
	local spec = table.clone(base)
	readSpec(model, spec)
	local look = root.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	forward = if forward.Magnitude > 0.0001 then forward.Unit else Vector3.zAxis
	local grace = model:GetAttribute("LaunchGraceUntil")
	return {
		spec = spec,
		model = model,
		root = root,
		float = float,
		lift = lift,
		heading = heading,
		velocity = velocity,
		driveAttachment = driveAttachment,
		waterlineOffset = waterline,
		yaw = math.atan2(-forward.X, -forward.Z),
		-- Taking over mid-voyage (say, after the server coasted it) keeps the way it has on.
		speed = root.AssemblyLinearVelocity:Dot(forward),
		turn = 0,
		bank = 0,
		bankVelocity = 0,
		clearWater = true,
		lastWaterCheck = 0,
		launchGraceUntil = if type(grace) == "number" then os.clock() + grace - workspace:GetServerTimeNow() else 0,
	}
end

function BoatDriving.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	-- Before the solver, like the server's loop, so each step uses one coherent set of targets.
	RunService.PreSimulation:Connect(function(dt)
		local model = helm
		if
			not model
			or not model.Parent
			or model:GetAttribute("DriverUserId") ~= player.UserId
			or model:GetAttribute("Parked")
			or model:GetAttribute("Sinking")
			or model:GetAttribute("Hoisted")
		then
			hull = nil
			return
		end
		if not hull or hull.model ~= model then
			hull = prepare(model)
			if not hull then
				return
			end
		end
		readSpec(model, hull.spec)
		local speed, turn = BoatMotion.step(hull.speed, hull.turn, helmThrottle, helmSteer, hull.spec, dt)
		BoatDrive.apply(hull, speed, turn, helmThrottle, helmSteer, dt, workspace:GetServerTimeNow(), nil)
	end)
end

return BoatDriving
