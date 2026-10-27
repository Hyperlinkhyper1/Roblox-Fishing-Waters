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

-- Discard an old heading lead as soon as the requested turn changes direction.
function BoatMotion.advanceHeading(target: number, actual: number, yawRate: number, dt: number): number
	local error = math.atan2(math.sin(target - actual), math.cos(target - actual))
	if yawRate == 0 or error * yawRate < 0 then
		target = actual
	end
	return BoatMotion.heading(target + yawRate * math.clamp(dt, 0, 0.1), actual)
end

function BoatMotion.steering(speed: number, steer: number, spec): number
	local idle = spec.IdleSteering or 0.25
	local scale = idle + (1 - idle) * math.clamp(math.abs(speed) / spec.ForwardSpeed, 0, 1)
	local input = if math.abs(steer) < 0.08 then 0 else steer * math.abs(steer)
	return input * spec.TurnRate * scale
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
	local targetTurn = BoatMotion.steering(speed, steer, spec)
	-- The constraint handles physical inertia. Do not spend another half-second
	-- ramping the command through the old turn before countersteering can begin.
	if turn * targetTurn < 0 then
		turn = 0
	end
	local turnRate = math.max(spec.TurnAcceleration, spec.TurnRate / 0.18)
	turn = BoatMotion.approach(turn, targetTurn, turnRate * (if targetTurn == 0 then 2 else 1) * dt)
	return speed, turn
end

-- Lean into the requested lateral acceleration, independent of noisy measured
-- spin. Countersteering cancels outward roll momentum before easing back over.
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
	if bankVelocity * (target - bank) < 0 then
		bankVelocity = 0
	end
	local frequency = 12
	local offset = bank - target
	local decay = math.exp(-frequency * dt)
	local spring = bankVelocity + frequency * offset
	return target + (offset + spring * dt) * decay, (bankVelocity - frequency * spring * dt) * decay
end

return BoatMotion
