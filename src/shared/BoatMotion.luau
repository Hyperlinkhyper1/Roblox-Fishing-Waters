-- Rates are in studs/s² and radians/s². Always brake through zero before reversing.
local BoatMotion = {}

function BoatMotion.approach(value: number, target: number, delta: number): number
	return value + math.clamp(target - value, -delta, delta)
end

-- A blocked hull must not accumulate turns to unwind after contact ends.
function BoatMotion.heading(target: number, actual: number): number
	local error = math.atan2(math.sin(target - actual), math.cos(target - actual))
	return actual + math.clamp(error, -0.35, 0.35)
end

function BoatMotion.step(speed: number, turn: number, throttle: number, steer: number, spec, dt: number)
	dt = math.clamp(dt, 0, 0.1)
	local target = throttle * (if throttle < 0 then spec.ReverseSpeed else spec.ForwardSpeed)
	local reversing = speed * target < 0
	local rate = if throttle == 0
		then spec.CoastDeceleration
		elseif reversing or math.abs(target) < math.abs(speed) then spec.BrakeDeceleration
		else spec.Acceleration
	speed = BoatMotion.approach(speed, if reversing then 0 else target, rate * dt)
	-- IdleSteering is the share of the turn rate available at a standstill.
	local idle = spec.IdleSteering or 0.25
	local steeringScale = idle + (1 - idle) * math.clamp(math.abs(speed) / spec.ForwardSpeed, 0, 1)
	local steeringInput = if math.abs(steer) < 0.08 then 0 else steer * math.abs(steer)
	local turnRate = if steeringInput == 0 then spec.TurnAcceleration * 2 else spec.TurnAcceleration
	turn = BoatMotion.approach(turn, steeringInput * spec.TurnRate * steeringScale, turnRate * dt)
	return speed, turn
end

-- Lateral acceleration is speed * yaw rate. A critically damped spring lets
-- the hull lean into that load and settle without snapping when steering stops.
function BoatMotion.bank(
	bank: number,
	bankVelocity: number,
	speed: number,
	yawRate: number,
	spec,
	gravity: number,
	dt: number
)
	dt = math.clamp(dt, 0, 0.1)
	local limit = math.rad(spec.MaxBankAngle)
	local target = math.clamp(math.atan(speed * yawRate * 0.8 / math.max(gravity, 1)), -limit, limit)
	local frequency = 7
	local offset = bank - target
	local decay = math.exp(-frequency * dt)
	local spring = bankVelocity + frequency * offset
	return target + (offset + spring * dt) * decay, (bankVelocity - frequency * spring * dt) * decay
end

return BoatMotion
