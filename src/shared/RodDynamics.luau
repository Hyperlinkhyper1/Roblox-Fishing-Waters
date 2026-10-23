-- Exact damped springs keep the visual rod and its hanging float stable at
-- different frame rates. Inputs are measured motion, never a looping animation.
local RodDynamics = {}

local MAX_BEND = math.rad(31)
local MAX_SWING = 0.78

function RodDynamics.new()
	return { bendX = 0, bendZ = 0, velocityX = 0, velocityZ = 0, bobX = 0, bobZ = 0, bobVelocityX = 0, bobVelocityZ = 0 }
end

function RodDynamics.reset(state)
	for key in state do
		state[key] = 0
	end
end

local function finiteClamp(value: number, limit: number): number
	if value ~= value then
		return 0
	end
	return math.clamp(value, -limit, limit)
end

local function spring(
	position: number,
	velocity: number,
	target: number,
	dt: number,
	frequency: number,
	damping: number,
	limit: number
)
	local offset = position - target
	local drag = frequency * damping
	local oscillation = frequency * math.sqrt(1 - damping * damping)
	local decay = math.exp(-drag * dt)
	local cosine, sine = math.cos(oscillation * dt), math.sin(oscillation * dt)
	local nextPosition = target + decay * (offset * cosine + (velocity + drag * offset) / oscillation * sine)
	local nextVelocity = decay
		* (velocity * cosine - (drag * velocity + frequency * frequency * offset) / oscillation * sine)
	local bounded = finiteClamp(nextPosition, limit)
	if bounded ~= nextPosition and bounded * nextVelocity > 0 then
		nextVelocity = 0
	end
	return bounded, nextVelocity
end

function RodDynamics.step(state, dt: number, target)
	if dt ~= dt or dt > 0.15 then
		RodDynamics.reset(state)
		return false
	end
	if dt <= 0 then
		return true
	end
	state.bendX, state.velocityX =
		spring(state.bendX, state.velocityX, finiteClamp(target.bendX, MAX_BEND), dt, 13, 0.59, MAX_BEND)
	state.bendZ, state.velocityZ =
		spring(state.bendZ, state.velocityZ, finiteClamp(target.bendZ, MAX_BEND), dt, 13, 0.59, MAX_BEND)
	state.bobX, state.bobVelocityX =
		spring(state.bobX, state.bobVelocityX, finiteClamp(target.bobX, MAX_SWING), dt, 5.4, 0.34, MAX_SWING)
	state.bobZ, state.bobVelocityZ =
		spring(state.bobZ, state.bobVelocityZ, finiteClamp(target.bobZ, MAX_SWING), dt, 5.4, 0.34, MAX_SWING)
	return true
end

return RodDynamics
