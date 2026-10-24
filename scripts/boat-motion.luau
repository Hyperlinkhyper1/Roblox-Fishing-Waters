local Motion = require("../src/shared/BoatMotion")
local Catalog = require("../src/shared/BoatCatalog")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
for id, spec in Catalog do
	check(spec.TurnRate > (if id == "Rowboat" then 0.9 else 0.65), "Boats must turn faster than the original rate")
	check(spec.ForwardSpeed / spec.Acceleration == 2, "Cruise speed must take two seconds")
	for _, fps in { 30, 60, 144 } do
		local speed, turn = 0, 0
		for _ = 1, fps * 2 do
			local previous = speed
			speed, turn = Motion.step(speed, turn, 1, 1, spec, 1 / fps)
			check(speed - previous <= spec.Acceleration / fps + 1e-8, id .. " acceleration spike")
		end
		check(math.abs(speed - spec.Acceleration * 2) < 1e-8, "Acceleration depends on frame rate")
		check(turn > 0 and turn <= spec.TurnRate, "Steering must stay within its limit")
		local responsiveTurn = 0
		for _ = 1, fps / 2 do
			local _speed
			_speed, responsiveTurn = Motion.step(spec.ForwardSpeed, responsiveTurn, 1, 1, spec, 1 / fps)
		end
		check(math.abs(responsiveTurn - spec.TurnRate) < 1e-8, "Full steering must respond within half a second")
		for _ = 1, fps do
			local _speed
			_speed, responsiveTurn = Motion.step(spec.ForwardSpeed, responsiveTurn, 1, -1, spec, 1 / fps)
		end
		check(math.abs(responsiveTurn + spec.TurnRate) < 1e-8, "Steering must change direction within one second")
		for _ = 1, fps * 10 do speed = Motion.step(speed, 0, 1, 0, spec, 1 / fps) end
		check(speed == spec.ForwardSpeed, "Forward speed cap")
		local slower = Motion.step(speed, 0, 0, 0, spec, 1 / fps)
		check(math.abs(slower - (speed - spec.CoastDeceleration / fps)) < 1e-8, "Release must coast")
		while speed > 0 do
			speed = Motion.step(speed, 0, -1, 0, spec, 1 / fps)
			check(speed >= 0, "Reversing must brake through zero")
		end
		for _ = 1, fps * 10 do speed = Motion.step(speed, 0, -1, 0, spec, 1 / fps) end
		check(speed == -spec.ReverseSpeed, "Reverse speed cap")
		check(Motion.step(0, 0, 1, 0, spec, 5) <= spec.Acceleration * 0.1, "Hitch acceleration spike")
		-- A lagging actuator used to pin the measured-speed-based command below
		-- one stud/s. This model deliberately follows only a fraction each tick.
		local command, measured = 0, 0
		for _ = 1, fps * 20 do
			command = Motion.step(command, 0, 1, 0, spec, 1 / fps)
			measured += (command - measured) * (1 - math.exp(-4 / fps))
		end
		check(measured > spec.ForwardSpeed * 0.99, "Solver lag prevents reaching cruise speed")
		local _, idleTurn = Motion.step(0, spec.TurnRate, 0, 1, spec, 0.1)
		local _, cruiseTurn = Motion.step(spec.ForwardSpeed, spec.TurnRate, 1, 1, spec, 0.1)
		check(idleTurn < cruiseTurn, "Idle steering is as sensitive as cruise steering")
		local _, deadzoneTurn = Motion.step(0, 0, 0, 0.04, spec, 0.1)
		check(deadzoneTurn == 0, "Small analog drift must not steer")
	end
end
print(`Boat motion: {checks} checks passed (pure controller; no live physics)`)
