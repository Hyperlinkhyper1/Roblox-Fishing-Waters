-- One absolute clock drives both termini, doors, indicators and passenger journeys.
local Schedule = {}
Schedule.PERIOD = 60
Schedule.OPEN = 8
Schedule.CLOSE = 26
Schedule.DEPART = 28
Schedule.TUNNEL = 36
Schedule.TRANSFER = 48
Schedule.RUN = 250
Schedule.OTHER = { Harbour = "City", City = "Harbour" }
Schedule.NAMES = { Harbour = "Gullhaven", City = "Hafen Mitte" }

function Schedule.state(now)
	local cycle = math.floor(now / Schedule.PERIOD)
	local phase = now - cycle * Schedule.PERIOD
	local offset, doors, status = 0, 0, "Boarding"
	if phase < 6 then
		local t = phase / 6
		offset, status = -Schedule.RUN * (1 - t) ^ 2, "Arriving"
	elseif phase < Schedule.OPEN then
		doors, status = (phase - 6) / 2, "Doors opening"
	elseif phase < Schedule.CLOSE then
		doors = 1
	elseif phase < Schedule.DEPART then
		doors, status = 1 - (phase - Schedule.CLOSE) / 2, "Doors closing"
	elseif phase < Schedule.TUNNEL then
		offset, status = Schedule.RUN * ((phase - Schedule.DEPART) / 8) ^ 2, "Departing"
	else
		offset, status = Schedule.RUN, "Next train"
	end
	return {
		cycle = cycle, phase = phase, offset = offset, doors = doors, status = status,
		boarding = phase >= Schedule.OPEN and phase < Schedule.CLOSE,
		visible = phase < Schedule.TUNNEL,
		seconds = math.ceil(if phase < Schedule.CLOSE then Schedule.CLOSE - phase else Schedule.PERIOD - phase),
	}
end

function Schedule.frame(dock, now)
	return dock * CFrame.new(Schedule.state(now).offset, 0, 0)
end

function Schedule.darkness(now, departure)
	-- Finish the fade while the doors close, before the carriage can leave
	-- the station shell. Stay covered across the clock wrap and until Arrive.
	return math.clamp((now - departure) / (Schedule.DEPART - Schedule.CLOSE), 0, 1)
end

function Schedule.inside(position)
	-- Door thresholds are excluded; a passenger must actually be inside a carriage.
	if math.abs(position.Z) > 4.7 or position.Y < 0 or position.Y > 9 then return false end
	for _, x in { -46, 0, 46 } do
		if math.abs(position.X - x) < 21.5 then return true end
	end
	return false
end

return Schedule
