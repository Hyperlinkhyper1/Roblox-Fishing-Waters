-- Who works in the parliament, where each of them should be right now, and how they walk
-- there. Pure rules over Shared.ParliamentLayout: client/Parliament draws the result, and the
-- checks run the same code without Roblox.
--
-- The day is cut into two-hour blocks. Each block everyone picks something to do that suits
-- their job (a debate, a committee, their party's room, lunch) and walks to a free place for
-- it along the building's walking graph. When the division bell rings, every member drops
-- that and walks to their own bench in the Tweede Kamer, and the cabinet to vak K.
local Layout = require(script.Parent.ParliamentLayout)
local Parties = require(script.Parent.Parties)

local Crowd = {}
Crowd.BLOCK_SECONDS = 120
Crowd.WALK_SPEED = 9
Crowd.BELL_HURRY = 1.4

local OUTSIDE = { Id = "Outside", Kind = "Away", Position = Layout.Nodes.Out, Yaw = 0, Node = "Out", Path = {} }
Crowd.Outside = OUTSIDE

local function hash(a: number, b: number): number
	return Parties.hash(a, b)
end

local SKIN = {
	Color3.fromRGB(241, 208, 178),
	Color3.fromRGB(224, 180, 144),
	Color3.fromRGB(198, 148, 110),
	Color3.fromRGB(150, 104, 74),
	Color3.fromRGB(104, 72, 52),
}
local HAIR = {
	Color3.fromRGB(42, 34, 30),
	Color3.fromRGB(92, 62, 40),
	Color3.fromRGB(176, 140, 84),
	Color3.fromRGB(150, 150, 150),
	Color3.fromRGB(120, 54, 36),
	Color3.fromRGB(226, 226, 222),
}
local NEUTRAL = Color3.fromRGB(70, 76, 86)
local UNIFORM = {
	Guard = Color3.fromRGB(34, 44, 66),
	Cook = Color3.fromRGB(236, 236, 230),
	Waiter = Color3.fromRGB(30, 30, 34),
	Barista = Color3.fromRGB(92, 62, 40),
	Bode = Color3.fromRGB(44, 44, 50),
	Reception = Color3.fromRGB(34, 89, 157),
	Official = Color3.fromRGB(150, 45, 48),
	Senator = Color3.fromRGB(46, 104, 78),
}

-- Everyone in the building. `seats` is the house's seat count per party id (Parties.seats);
-- `lite` keeps a third of the members and half the rest (the Performance setting).
function Crowd.roster(seats: { [string]: number }?, governing: string?, lite: boolean?)
	local people = {}
	local function person(role: string, fields)
		local index = #people + 1
		local entry = fields or {}
		entry.Index, entry.Role = index, role
		entry.Skin = SKIN[math.floor(hash(index, 11) * #SKIN) + 1]
		entry.Hair = HAIR[math.floor(hash(index, 12) * #HAIR) + 1]
		entry.Speed = Crowd.WALK_SPEED * (0.86 + hash(index, 13) * 0.3)
		entry.Color = entry.Color or UNIFORM[role] or NEUTRAL:Lerp(entry.Hair, hash(index, 14) * 0.5)
		table.insert(people, entry)
		return entry
	end
	-- Parties sit in wedges across the half circle, west to east, in list order.
	local members = {}
	for _, seat in Layout.Seats do
		if seat.Role == "Member" then
			table.insert(members, seat)
		end
	end
	table.sort(members, function(a, b)
		if a.Angle ~= b.Angle then
			return a.Angle < b.Angle
		end
		return a.Row < b.Row
	end)
	local split = seats or Parties.seats(nil, #members)
	local cursor = 0
	for _, party in Parties.List do
		for place = 1, split[party.Id] or 0 do
			cursor += 1
			local seat = members[cursor]
			if seat and (not lite or cursor % 3 == 1) then
				person("Member", { Party = party.Index, Seat = seat, Color = party.Color })
			end
		end
	end
	local cabinet = governing and Parties.ById[governing]
	local ministers = 0
	for _, seat in Layout.Seats do
		if seat.Role == "Minister" then
			ministers += 1
			if not lite or ministers % 3 == 1 then
				person("Minister", { Party = cabinet and cabinet.Index, Seat = seat, Number = ministers, Color = if cabinet then cabinet.Color:Lerp(Color3.new(0, 0, 0), 0.35) else NEUTRAL })
			end
		end
	end
	person("Speaker", { Seat = Layout.SeatById.Speaker, Color = Color3.fromRGB(28, 34, 60) })
	local senators = 0
	for _, seat in Layout.Seats do
		if seat.Role == "Senator" then
			senators += 1
			if senators % (if lite then 9 else 3) == 1 then
				person("Senator", { Seat = seat })
			end
		end
	end
	local staff = {
		{ "Cook", 3 }, { "Waiter", 1 }, { "Barista", 1 }, { "Guard", 4 }, { "Reception", 2 }, { "Bode", 2 },
		{ "Official", 2 }, { "Librarian", 1 }, { "Journalist", 6 }, { "Camera", 2 }, { "Clerk", 6 }, { "Visitor", 10 },
	}
	for _, entry in staff do
		local count = if lite then math.ceil(entry[2] / 2) else entry[2]
		for number = 1, count do
			person(entry[1], { Number = number })
		end
	end
	return people
end

-- The first free place in a room for someone of `role` (any seat when `role` is nil).
local function take(taken, roomId: string, role: string?, start: number?, kind: string?)
	local room = Layout.RoomById[roomId]
	local spots = room and room.Spots
	if not spots or #spots == 0 then
		return nil
	end
	local offset = math.floor((start or 0) * #spots)
	for step = 0, #spots - 1 do
		local spot = spots[(offset + step) % #spots + 1]
		if not taken[spot] and spot.Role == role and (kind == nil or spot.Kind == kind) then
			taken[spot] = true
			return spot
		end
	end
	return nil
end
local function takeSeat(taken, seat)
	if seat and not taken[seat] then
		taken[seat] = true
		return seat
	end
	return nil
end

local COMMITTEES = { "E1A", "E1B", "E1C", "E2A" }
local STAFF_ROOMS = {
	Cook = { "E0E", "Cook" },
	Waiter = { "E0C", "Waiter" },
	Barista = { "W0D", "Barista" },
	Bode = { "W0A", "Bode" },
	Reception = { "Hall", "Reception" },
	Official = { "E0A", "Official" },
	Librarian = { "W0C", "Librarian" },
	Camera = { "W0B", "Camera" },
}

-- Where everyone belongs during `block`. `division` is true while members are called to vote;
-- `pollsOpen` sends visitors to the voting booths. Returns { [person] = spot } (Outside = away).
function Crowd.assign(people, block: number, hour: number, division: boolean?, pollsOpen: boolean?)
	local taken, plan = {}, {}
	local day = hour >= 8 and hour < 22
	local early, late = hour >= 6 and hour < 8, hour >= 22
	local meal = hour == 12 or hour == 18
	local function free(roomId, start)
		return take(taken, roomId, nil, start, "Sit")
	end
	-- Fixed posts first, so wanderers never take a worker's place.
	for _, person in people do
		local post = STAFF_ROOMS[person.Role]
		if person.Role == "Guard" then
			if person.Number <= 2 then
				plan[person] = take(taken, "W0E", "Guard", 0) or OUTSIDE
			else
				plan[person] = if hour >= 6 then take(taken, "Hall", "Guard", 0) or OUTSIDE else OUTSIDE
			end
		elseif post then
			local present = day or early or (late and person.Role ~= "Cook")
			plan[person] = if present then take(taken, post[1], post[2], 0) or OUTSIDE else OUTSIDE
		elseif person.Role == "Clerk" then
			plan[person] = if day or early then take(taken, if person.Number <= 2 then "W1B" else "W2B", "Clerk", 0) or OUTSIDE else OUTSIDE
		end
	end
	for _, person in people do
		if plan[person] then
			continue
		end
		local roll, pick = hash(person.Index, block), hash(person.Index, block + 0.5)
		local spot
		if person.Role == "Member" then
			if division then
				spot = takeSeat(taken, person.Seat)
			elseif day or (early and roll < 0.25) or (late and roll < 0.3) then
				if late then
					spot = takeSeat(taken, person.Seat)
				elseif meal and roll < 0.55 then
					spot = free("E0C", pick)
				elseif roll < 0.3 then
					spot = takeSeat(taken, person.Seat)
				elseif roll < 0.48 then
					spot = free(COMMITTEES[(person.Index + block) % #COMMITTEES + 1], pick)
				elseif roll < 0.7 then
					spot = free(Layout.PartyRooms[person.Party].Id, pick)
				elseif roll < 0.77 then
					spot = free("W0D", pick)
				elseif roll < 0.82 then
					spot = free("W2A", pick)
				elseif roll < 0.86 then
					spot = free("W0C", pick)
				elseif roll < 0.93 then
					spot = take(taken, "Hall", nil, pick, "Stand")
				else
					spot = take(taken, "Wandelgang", nil, pick, "Stand")
				end
				spot = spot or takeSeat(taken, person.Seat)
			end
		elseif person.Role == "Minister" then
			if division then
				spot = takeSeat(taken, person.Seat)
			elseif day then
				local cabinet = hour == 10 or hour == 14
				if cabinet and person.Number <= 9 then
					spot = takeSeat(taken, Layout.SeatById[if person.Number == 1 then "CouncilChair" else "Council" .. (person.Number - 1)])
				elseif roll < 0.55 then
					spot = takeSeat(taken, person.Seat)
				elseif meal then
					spot = free("E0C", pick)
				else
					spot = free("W2A", pick) or take(taken, "Wandelgang", nil, pick, "Stand")
				end
				spot = spot or takeSeat(taken, person.Seat)
			end
		elseif person.Role == "Speaker" then
			if division or (hour >= 10 and hour < 18) or hour == 20 then
				spot = takeSeat(taken, person.Seat)
			elseif day or early then
				spot = take(taken, "W1B", "Speaker", 0)
			end
		elseif person.Role == "Senator" then
			if hour >= 10 and hour < 18 then
				if roll < 0.62 then
					spot = takeSeat(taken, person.Seat)
				elseif roll < 0.76 then
					spot = free("W0D", pick)
				elseif roll < 0.88 then
					spot = free("W0C", pick)
				else
					spot = take(taken, "Wandelgang", nil, pick, "Stand")
				end
				spot = spot or takeSeat(taken, person.Seat)
			end
		elseif person.Role == "Journalist" then
			if day then
				if division or roll < 0.3 then
					spot = takeSeat(taken, Layout.SeatById["Tribune" .. (12 + person.Number)])
				elseif roll < 0.75 then
					spot = take(taken, "W0B", "Journalist", pick)
				else
					spot = take(taken, "Hall", nil, pick, "Stand")
				end
			end
		elseif person.Role == "Visitor" then
			if day then
				if pollsOpen and roll < 0.4 then
					spot = take(taken, "E0A", "Voter", pick)
				elseif division or roll < 0.6 then
					spot = takeSeat(taken, Layout.SeatById["Tribune" .. person.Number])
				elseif roll < 0.8 then
					spot = take(taken, "E0B", "Visitor", pick)
				elseif roll < 0.9 then
					spot = free("E0C", pick)
				else
					spot = take(taken, "Hall", nil, pick, "Stand")
				end
			end
		end
		plan[person] = spot or OUTSIDE
	end
	return plan
end

-- The points to walk from one place to another: back out to the graph, along it, and in.
-- `ids` marks which points are graph nodes, so a walk can be redirected at the next one.
function Crowd.path(from, to)
	local points, ids = {}, {}
	local function add(position, id)
		table.insert(points, position)
		ids[#points] = id or false
	end
	add(from.Position)
	for index = #from.Path, 1, -1 do
		add(from.Path[index])
	end
	local route = Layout.route(from.Node, to.Node)
	if route then
		for _, id in route do
			add(Layout.Nodes[id], id)
		end
	end
	for _, position in to.Path do
		add(position)
	end
	add(to.Position)
	return points, ids
end

---------------------------------------------------------------------------------------------------
-- The running crowd

-- A crowd in which everyone already stands where the plan puts them.
function Crowd.new(people, plan)
	local state = { People = people, Plan = plan }
	for _, person in people do
		local spot = plan[person] or OUTSIDE
		person.Target, person.Position, person.Yaw = spot, spot.Position, spot.Yaw
		person.Pose = spot.Kind
		person.Points, person.Ids, person.Leg = nil, nil, nil
		person.Changed = true
	end
	return state
end

-- Sends everyone whose place changed on their way.
function Crowd.retarget(state, plan)
	state.Plan = plan
	for _, person in state.People do
		local spot = plan[person] or OUTSIDE
		if spot == person.Target then
			continue
		end
		local points, ids
		if person.Points then
			-- Already walking: keep going to the next graph node and turn off there.
			local turn
			for index = person.Leg, #person.Points do
				if person.Ids[index] then
					turn = index
					break
				end
			end
			points, ids = { person.Position }, { false }
			local from = person.Target
			if turn then
				for index = person.Leg, turn - 1 do
					table.insert(points, person.Points[index])
					ids[#points] = person.Ids[index]
				end
				from = { Position = person.Points[turn], Path = {}, Node = person.Ids[turn] }
			end
			local rest, restIds = Crowd.path(from, spot)
			-- Walking back out of a seat row starts from where the person is now.
			for index = if turn then 1 else 2, #rest do
				table.insert(points, rest[index])
				ids[#points] = restIds[index]
			end
		else
			points, ids = Crowd.path(person.Target, spot)
		end
		person.Target, person.Points, person.Ids, person.Leg = spot, points, ids, 2
		person.Pose, person.Changed = "Walk", true
	end
end

-- Moves the walkers. Returns how many are still on their way.
function Crowd.step(state, dt: number, hurry: boolean?): number
	local walking = 0
	for _, person in state.People do
		local points = person.Points
		if not points then
			continue
		end
		local left = person.Speed * (if hurry then Crowd.BELL_HURRY else 1) * dt
		while left > 0 and person.Leg <= #points do
			local goal = points[person.Leg]
			local offset = goal - person.Position
			local distance = offset.Magnitude
			if distance <= left then
				person.Position = goal
				left -= distance
				person.Leg += 1
			else
				person.Position += offset * (left / distance)
				if offset.X * offset.X + offset.Z * offset.Z > 1e-4 then
					person.Yaw = math.atan2(-offset.X, -offset.Z)
				end
				left = 0
			end
		end
		person.Phase = (person.Phase or 0) + dt * person.Speed * 0.9
		if person.Leg > #points then
			local spot = person.Target
			person.Position, person.Yaw, person.Pose = spot.Position, spot.Yaw, spot.Kind
			person.Points, person.Ids, person.Leg = nil, nil, nil
			person.Changed = true
		else
			walking += 1
		end
	end
	return walking
end

-- The block and clock hour at `elapsed` in-game seconds (DayNight.elapsed).
function Crowd.blockAt(elapsed: number): (number, number)
	local block = math.floor(elapsed / Crowd.BLOCK_SECONDS)
	return block, (block * Crowd.BLOCK_SECONDS / 60) % 24
end

return Crowd
