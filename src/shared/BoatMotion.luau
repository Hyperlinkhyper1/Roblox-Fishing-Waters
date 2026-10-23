-- Rates are in studs/s² and radians/s². Always brake through zero before reversing.
local BoatMotion = {}

function BoatMotion.approach(value: number, target: number, delta: number): number
	return value + math.clamp(target - value, -delta, delta)
end

function BoatMotion.step(speed: number, turn: number, throttle: number, steer: number, spec, dt: number)
	dt = math.clamp(dt, 0, 0.1)
	local target = throttle * (if throttle < 0 then spec.ReverseSpeed else spec.ForwardSpeed)
	local reversing = speed * target < 0
	local rate = if throttle == 0 then spec.CoastDeceleration
		elseif reversing or math.abs(target) < math.abs(speed) then spec.BrakeDeceleration
		else spec.Acceleration
	speed = BoatMotion.approach(speed, if reversing then 0 else target, rate * dt)
	local steeringScale = 0.25 + 0.75 * math.clamp(math.abs(speed) / spec.ForwardSpeed, 0, 1)
	local steeringInput = if math.abs(steer) < 0.08 then 0 else steer * math.abs(steer)
	local turnRate = if steeringInput == 0 then spec.TurnAcceleration * 2 else spec.TurnAcceleration
	turn = BoatMotion.approach(turn, steeringInput * spec.TurnRate * steeringScale, turnRate * dt)
	return speed, turn
end

function BoatMotion.drive(commandedSpeed: number, measuredSpeed: number, turn: number, throttle: number, steer: number, spec, dt: number)
	-- Retain the ramp between frames so solver lag and water drag do not reset it.
	-- Bound the lead to prevent a blocked hull from accumulating full throttle.
	local speed = math.clamp(commandedSpeed, measuredSpeed - 3, measuredSpeed + 3)
	return BoatMotion.step(speed, turn, throttle, steer, spec, dt)
end

return BoatMotion
