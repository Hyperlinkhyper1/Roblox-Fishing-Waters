-- The helm's per-step mover targets for a launched hull: buoyancy on the swell, banking,
-- heading and drive. The server runs them for hulls it simulates (coasting, tornadoes,
-- nobody at the helm); the driver's client runs the same code for its own hull, so the
-- helm answers at once and the boat is never a replica waiting on the network.
local Biomes = require(script.Parent.Biomes)
local BoatMotion = require(script.Parent.BoatMotion)
local Weather = require(script.Parent.Weather)

local BoatDrive = {}

-- The waterline target looks this far ahead along the hull's motion, so the soft
-- suspension starts rising before the bow reaches a crest instead of after.
local WAVE_LEAD_SECONDS = 0.12
-- At full speed the hull spans this much more water: planing boats skim chop.
local PLANING_STRETCH = 0.5

-- Spec fields the drive reads. The server publishes them on the hull (as Drive<Field>
-- attributes) because refits tune them per player.
BoatDrive.FIELDS = {
	"ForwardSpeed",
	"ReverseSpeed",
	"Acceleration",
	"BrakeDeceleration",
	"CoastDeceleration",
	"TurnRate",
	"TurnAcceleration",
	"IdleSteering",
	"MaxBankAngle",
	"Length",
	"Beam",
}

function BoatDrive.waterAhead(boat, direction: Vector3): boolean
	local parameters = RaycastParams.new()
	-- Only terrain can tell us whether the water ends. Docks, floating objects,
	-- and other boats are handled by physical collisions instead of the drive.
	parameters.FilterType = Enum.RaycastFilterType.Include
	parameters.FilterDescendantsInstances = { workspace.Terrain }
	parameters.IgnoreWater = false
	parameters.RespectCanCollide = true
	local position = boat.root.Position + direction * (boat.spec.Length / 2 + 2)
	-- The sea ends at the ocean bounds even where the ray below finds nothing: past them is
	-- empty sky, and the admin-only scale models beyond (ScaleModels) must stay out of reach.
	if not Biomes.inOceanBounds(Vector3.new(position.X, Biomes.WaterLevel, position.Z)) then
		return false
	end
	local result = workspace:Raycast(
		Vector3.new(position.X, Biomes.WaterLevel + 14, position.Z),
		Vector3.new(0, -32, 0),
		parameters
	)
	-- A missed ray is inconclusive (for example at a water voxel boundary).
	return result == nil or result.Material == Enum.Material.Water
end

function BoatDrive.updateSuspension(boat)
	local mass = boat.root.AssemblyMass
	local gravity = workspace.Gravity
	-- Cancel the assembly's weight separately so soft alignment does not need
	-- a permanent height error to hold up the hull and its seated passengers.
	boat.lift.Force = Vector3.new(0, mass * gravity, 0)
	boat.float.MaxAxesForce = Vector3.new(0, mass * (gravity + 100) * 4, 0)
	-- Allow acceleration, braking, turning and water drag, but let solid contacts
	-- stop the hull rather than asking the solver for unlimited collision force.
	local spec = boat.spec
	boat.velocity.MaxForce = mass
		* (math.max(spec.Acceleration, spec.BrakeDeceleration) + spec.ForwardSpeed * spec.TurnRate + gravity * 0.25)
	-- Approximate hull inertia; keep righting torque proportional to hull size
	-- without the oversized gravity-based torque that pried boats off obstacles.
	boat.heading.MaxTorque = mass * (spec.Length ^ 2 + spec.Beam ^ 2) / 12 * 20
	boat.heading.MaxAngularVelocity = spec.TurnRate + 2
end

-- Steers the movers for one physics step, given the speed and turn BoatMotion.step chose.
-- Returns the weather state so callers driving several hulls sample it once.
function BoatDrive.apply(
	boat,
	speed: number,
	turn: number,
	throttle: number,
	steer: number,
	dt: number,
	serverTime: number,
	weather
)
	boat.turn = turn
	local root = boat.root
	local actualForward = root.CFrame.LookVector
	actualForward = Vector3.new(actualForward.X, 0, actualForward.Z)
	actualForward = if actualForward.Magnitude > 0.0001
		then actualForward.Unit
		else CFrame.Angles(0, boat.yaw, 0).LookVector
	-- Like a real boat (or car), reversing mirrors the steering direction.
	local yawRateCommand = -turn * (if speed < 0 then -1 else 1)
	local actualYaw = math.atan2(-actualForward.X, -actualForward.Z)
	if math.abs(steer) < 0.08 then
		boat.yaw = actualYaw
	end
	boat.yaw = BoatMotion.advanceHeading(boat.yaw, actualYaw, yawRateCommand, dt)
	-- Seat welds change assembly mass when passengers board or leave.
	BoatDrive.updateSuspension(boat)
	local flatHeading = CFrame.Angles(0, boat.yaw, 0)
	local motion = root.AssemblyLinearVelocity
	motion = Vector3.new(motion.X, 0, motion.Z)
	local planing = math.clamp(math.abs(speed) / boat.spec.ForwardSpeed, 0, 1)
	weather = weather or Weather.getState(serverTime)
	local wave = Weather.hullSample(
		root.Position + motion * WAVE_LEAD_SECONDS,
		flatHeading.LookVector,
		boat.spec.Length * 0.4 * (1 + PLANING_STRETCH * planing),
		boat.spec.Beam * 0.4,
		serverTime,
		weather,
		-- Ride the visible surface: crests are drawn by the client swell mesh,
		-- troughs are hidden beneath Terrain's flat water.
		0
	)
	-- Riding a swell at speed climbs far faster than bobbing in place: a fixed
	-- 6 stud/s cap left fast hulls under each oncoming crest, bow first.
	boat.float.MaxVelocity = 6 + motion.Magnitude * 0.5
	local yawRate = root.AssemblyAngularVelocity.Y
	local bankYawRate = -BoatMotion.steering(speed, steer, boat.spec) * (if speed < 0 then -1 else 1)
	boat.bank, boat.bankVelocity = BoatMotion.bank(
		boat.bank,
		boat.bankVelocity,
		root.AssemblyLinearVelocity:Dot(actualForward),
		bankYawRate,
		boat.spec,
		workspace.Gravity,
		dt
	)
	-- Project the chosen heading onto the wave plane. Sampling a shared
	-- normal keeps pitch and roll correct at every heading, including
	-- when the same hull moves between the sheltered lake and open sea.
	local normal = wave.normal
	local forward = flatHeading.LookVector
	forward = (forward - normal * forward:Dot(normal)).Unit
	local right = forward:Cross(normal).Unit
	-- Bank relative to the wave plane, keeping the existing swell pitch.
	local bankCos, bankSin = math.cos(boat.bank), math.sin(boat.bank)
	right, normal = right * bankCos + normal * bankSin, normal * bankCos - right * bankSin
	local surfaceFrame = CFrame.fromMatrix(Vector3.zero, right, normal, -forward)
	boat.heading.CFrame = surfaceFrame
	local rootOffset = surfaceFrame:VectorToWorldSpace(boat.waterlineOffset)
	local surfaceHeight = Biomes.WaterLevel + wave.height
	local floorHeight = boat.model:GetAttribute("DryFloorHeight")
	if floorHeight then
		-- The terrain swimming surface stays flat while the boat follows swells.
		-- Keep even the lowest tilted corner of the sole above its ripples.
		local lowestFloor = floorHeight * normal.Y
			- math.abs(right.Y) * boat.model:GetAttribute("DryFloorHalfBeam")
			- math.abs(forward.Y) * boat.model:GetAttribute("DryFloorHalfLength")
		surfaceHeight = math.max(surfaceHeight, Biomes.WaterLevel + 0.35 - lowestFloor)
	end
	boat.float.Position = Vector3.new(boat.root.Position.X, surfaceHeight + rootOffset.Y, boat.root.Position.Z)
	local direction = flatHeading.LookVector * (if speed < 0 then -1 else 1)
	if os.clock() < boat.launchGraceUntil then
		boat.clearWater = true
	elseif (math.abs(speed) > 0.1 or throttle ~= 0) and os.clock() - boat.lastWaterCheck > 0.15 then
		boat.clearWater, boat.lastWaterCheck = BoatDrive.waterAhead(boat, direction), os.clock()
	end
	if not boat.clearWater then
		speed = 0
	end
	boat.speed = speed
	-- Compensate only normal yaw around the stern. Impact-induced pitch,
	-- roll or spinning must not feed extra horizontal propulsion back in.
	local center = root.AssemblyCenterOfMass
	boat.driveAttachment.Position = root.CFrame:PointToObjectSpace(center)
	local stern = root.Position
		+ root.CFrame:VectorToWorldSpace(Vector3.new(0, 0, boat.spec.Length * 0.4) - boat.waterlineOffset)
	local lever = center - stern
	local driveYaw = Vector3.new(0, math.clamp(yawRate, -boat.spec.TurnRate, boat.spec.TurnRate), 0)
	local movement = actualForward * speed + driveYaw:Cross(lever)
	boat.velocity.PlaneVelocity = Vector2.new(movement.X, movement.Z)
	-- AlignOrientation alone owns rotation. Overwriting angular velocity
	-- every frame fights its roll/pitch corrections and collision response.
	return weather
end

return BoatDrive
