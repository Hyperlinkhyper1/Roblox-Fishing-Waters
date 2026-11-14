-- The server owns trip state; these rules are shared with the offline checks.
local Ferry = {}
Ferry.BOAT_ID = "SmallFerry"
Ferry.BOAT_RANGE = 75
Ferry.PLAYER_RANGE = 16
Ferry.PASSENGERS = 4
Ferry.FARE_PER_PASSENGER = 500
Ferry.FARE = Ferry.PASSENGERS * Ferry.FARE_PER_PASSENGER

function Ferry.destination(origin: string): string?
	if origin == "Main" then return "City" end
	if origin == "City" then return "Main" end
	return nil
end

function Ferry.action(origin: string, trip, hasStarted: boolean, sameBoat: boolean, boatDistance: number, playerDistance: number): (string, string?)
	if not Ferry.destination(origin) then return "reject", "Unknown ferry stop." end
	if playerDistance > Ferry.PLAYER_RANGE then return "reject", "Move closer to the ferry stop." end
	if boatDistance > Ferry.BOAT_RANGE then return "reject", "Bring your Small Ferry alongside this dock." end
	if trip then
		if not sameBoat then return "reject", "Your passengers need the ferry they boarded." end
		if origin ~= trip.destination then return "reject", "Take your passengers to " .. trip.destination .. " first." end
		return "complete", nil
	end
	if origin == "City" and not hasStarted then return "reject", "Start ferry service at the public dock on the main island first." end
	return "board", nil
end

return Ferry
