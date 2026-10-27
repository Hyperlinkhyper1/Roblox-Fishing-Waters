local Motion = require("../src/shared/BoatMotion")
local Catalog = require("../src/shared/BoatCatalog")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
for id, spec in Catalog do
	for _, actual in { 0, math.pi - 0.01, -math.pi + 0.01 } do
		for _, direction in { -1, 1 } do
			local target = actual
			for _ = 1, 3600 do
				target = Motion.heading(target + direction * spec.TurnRate / 60, actual)
			end
			check(math.abs(target - actual) <= 0.350001, id .. " blocked steering must not accumulate full turns")
		end
		local requested = actual + 0.02
		check(math.abs(Motion.heading(requested, actual) - requested) < 1e-8, "Normal heading lag must be preserved")
	end
	check(
		math.abs(Motion.heading(-math.pi + 0.01, math.pi - 0.01) - (math.pi + 0.01)) < 1e-8,
		"Heading must cross the angle boundary along the shortest path"
	)
	check(spec.TurnRate > (if id == "Rowboat" then 0.9 else 0.65), "Boats must turn faster than the original rate")
	check(spec.ForwardSpeed / spec.Acceleration == 2, "Cruise speed must take two seconds")
	local expectedBank = math.clamp(
		math.atan(spec.ForwardSpeed * -spec.TurnRate * 0.8 / 196.2),
		-math.rad(spec.MaxBankAngle),
		math.rad(spec.MaxBankAngle)
	)
	for _, fps in { 30, 60, 144 } do
		for _, direction in { -1, 1 } do
			-- Reverse before the bank finishes building: retained spring momentum
			-- used to deepen the old lean for several more frames.
			local bank, velocity = 0, 0
			for _ = 1, math.ceil(fps * 0.08) do
				bank, velocity =
					Motion.bank(bank, velocity, spec.ForwardSpeed, direction * spec.TurnRate, spec, 196.2, 1 / fps)
			end
			local previous = bank
			bank, velocity =
				Motion.bank(bank, velocity, spec.ForwardSpeed, -direction * spec.TurnRate, spec, 196.2, 1 / fps)
			check((bank - previous) * direction < 0, id .. " reversal must immediately stop deepening the old lean")
			for _ = 1, math.ceil(fps * 0.25) do
				previous = bank
				bank, velocity =
					Motion.bank(bank, velocity, spec.ForwardSpeed, -direction * spec.TurnRate, spec, 196.2, 1 / fps)
				check(
					(bank - previous) * direction <= 0,
					id .. " reversed lean must move monotonically toward the new side"
				)
			end
			check(bank * direction < 0, id .. " lean must reach the opposite side within a quarter second")
			local _, reversedTurn =
				Motion.step(spec.ForwardSpeed, direction * spec.TurnRate, 1, -direction, spec, 1 / fps)
			check(reversedTurn * direction < 0, id .. " turn command must countersteer on the first frame")
			local actual = math.pi - 0.01
			local heading =
				Motion.advanceHeading(actual + direction * 0.35, actual, -direction * spec.TurnRate, 1 / fps)
			check((heading - actual) * direction < 0, id .. " old heading lead must not delay countersteering")
			check(
				Motion.advanceHeading(actual + direction * 0.35, actual, 0, 1 / fps) == actual,
				id .. " neutral steering must discard residual heading lead"
			)
		end
		local bank, bankVelocity = 0, 0
		for _ = 1, fps * 2 do
			local previous = bank
			bank, bankVelocity =
				Motion.bank(bank, bankVelocity, spec.ForwardSpeed, -spec.TurnRate, spec, 196.2, 1 / fps)
			check(bank <= previous and bank >= expectedBank - 1e-8, id .. " lean must build smoothly without overshoot")
		end
		check(math.abs(bank - expectedBank) < 0.00001, id .. " bank must reach its physical target at every frame rate")
		for _ = 1, fps * 3 do
			bank, bankVelocity = Motion.bank(bank, bankVelocity, spec.ForwardSpeed, 0, spec, 196.2, 1 / fps)
		end
		check(
			math.abs(bank) < 0.00001 and math.abs(bankVelocity) < 0.00001,
			id .. " straightening must settle the hull"
		)
		local stillBank = Motion.bank(0, 0, 0, spec.TurnRate, spec, 196.2, 1 / fps)
		check(stillBank == 0, "Turning without travel must not bank")
		local left = Motion.bank(0, 0, spec.ForwardSpeed, spec.TurnRate, spec, 196.2, 1 / fps)
		local reverse = Motion.bank(0, 0, -spec.ReverseSpeed, -spec.TurnRate, spec, 196.2, 1 / fps)
		check(left > 0 and reverse > 0, "Bank direction must follow lateral acceleration in forward and reverse")
		check(
			Motion.bank(0, 0, spec.ForwardSpeed, spec.TurnRate, spec, 196.2, 5)
				== Motion.bank(0, 0, spec.ForwardSpeed, spec.TurnRate, spec, 196.2, 0.1),
			"Hitches must not snap bank"
		)
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
		for _ = 1, fps * 10 do
			speed = Motion.step(speed, 0, 1, 0, spec, 1 / fps)
		end
		check(speed == spec.ForwardSpeed, "Forward speed cap")
		local slower = Motion.step(speed, 0, 0, 0, spec, 1 / fps)
		check(math.abs(slower - (speed - spec.CoastDeceleration / fps)) < 1e-8, "Release must coast")
		while speed > 0 do
			speed = Motion.step(speed, 0, -1, 0, spec, 1 / fps)
			check(speed >= 0, "Reversing must brake through zero")
		end
		for _ = 1, fps * 10 do
			speed = Motion.step(speed, 0, -1, 0, spec, 1 / fps)
		end
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
