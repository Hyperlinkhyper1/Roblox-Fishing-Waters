-- Shared plan of the parliament: shell dimensions, real seats, every room and the
-- walking graph its staff follow. The shell (Map/CityLandmark), the local furnishings
-- (ParliamentInterior) and the crowd (ParliamentCrowd) all read the same numbers.
-- Building axes: +Z is the front (Civic Square), +X is east, Y rises from the ground floor.
-- This module requires nothing, so the map harnesses can load it on its own.
--
-- Scale: an avatar is about 5 studs tall. Storeys are 18 studs, doors 8 by 11, corridors 10
-- wide, rooms about 25 by 25.
local Layout = {}
local V, F, A = Vector3.new, CFrame.new, CFrame.Angles
local rad, sin, cos, pi = math.rad, math.sin, math.cos, math.pi

Layout.Tag, Layout.FrameAttribute = "CityParliament", "ParliamentFrame"
Layout.BellTag, Layout.BallotTag = "ParliamentBell", "ParliamentBallot"
-- Two three-storey wings flank a round chamber under the glass dome. The curved Great Hall
-- bulges out in front of the chamber, between the wings; the Members' Lobby runs behind it.
Layout.HalfWidth, Layout.North, Layout.WingFront = 108, -98, 66
Layout.Wall = 1.2
Layout.Storey, Layout.Floors, Layout.Roof, Layout.Height = 18, 3, 54, 70
Layout.WingInner, Layout.RoomWall, Layout.CorridorX = 70, 81, 75.5
Layout.InnerFace = Layout.WingInner + Layout.Wall / 2 -- the wing side of the inner wall
Layout.OuterFace = Layout.HalfWidth - Layout.Wall -- the inside of the outer walls
Layout.InnerNorth = Layout.North + Layout.Wall
Layout.InnerFront = Layout.WingFront - Layout.Wall
Layout.RoomCentre = (Layout.RoomWall + 0.5 + Layout.OuterFace) / 2
Layout.RoomHalfU = (Layout.OuterFace - Layout.RoomWall - 0.5) / 2
Layout.StairZ, Layout.RearZ = 33, -82
Layout.Door, Layout.DoorHeight = 8, 11
Layout.Focus = V(0, 0, -16)
Layout.MainFocus = Layout.Focus
Layout.DrumRadius, Layout.DrumOuter = 62, 64
-- The chamber has a coffered ceiling with an oculus under the dome.
Layout.Ceiling, Layout.Oculus = 56, 16
Layout.ClerestoryTop, Layout.DrumTop = 66, 69
Layout.HallRadius, Layout.ColumnRadius = 98, 103
Layout.HallSpan = math.deg(math.asin(Layout.WingInner / Layout.HallRadius))
Layout.Front = Layout.Focus.Z + Layout.HallRadius
Layout.DomeRadius, Layout.DomeRise = 63, 36
-- Switchback stairs at the front of each wing: flight A climbs north to south on the inner
-- side, a landing runs along the front wall, flight B climbs back on the outer side.
Layout.Stair = { A = 88.75, B = 101.05, Width = 11.5, Low = 36, High = 57, Spine = { 94.5, 95.3 } }
-- The inner walls open onto the Great Hall here on every floor.
Layout.HallOpening = { 36, 50 }
-- Members' doors into the chamber, and gallery doors above them, face both wings here.
Layout.SideDoorZ = -17.5
Layout.RearDoorZ = -89.5

-- A point `radius` from the chamber focus; 0 degrees faces the square, 90 is east.
function Layout.polar(degrees: number, radius: number, y: number?): Vector3
	local a = rad(degrees)
	return V(Layout.Focus.X + sin(a) * radius, y or 0, Layout.Focus.Z + cos(a) * radius)
end
-- The same point as a frame looking at the focus.
function Layout.facing(degrees: number, radius: number, y: number?): CFrame
	return F(Layout.polar(degrees, radius, y)) * A(0, rad(degrees), 0)
end

---------------------------------------------------------------------------------------------------
-- Real seats. Each is a server Seat; `Yaw` is the direction its occupant faces.

Layout.Rows = { 15, 18, 24, 27, 30, 36 }
Layout.FirstRow, Layout.RowPitch, Layout.RowRise = 22, 5, 0.8
-- Twenty-degree radial aisles leave room for avatars between the desk ends.
Layout.Sectors = { { -84, -40 }, { -20, 20 }, { 40, 84 } }
Layout.Aisles = { -30, 30 }
Layout.TierSpan, Layout.TierSegments = 87, 24
Layout.Seats, Layout.Tiers, Layout.SeatById = {}, {}, {}
local function seat(entry)
	entry.Position = entry.Frame.Position
	table.insert(Layout.Seats, entry)
	Layout.SeatById[entry.Id] = entry
	return entry
end

function Layout.rowRadius(row: number): number
	return Layout.FirstRow + (row - 1) * Layout.RowPitch
end
function Layout.rowRise(row: number): number
	return (row - 1) * Layout.RowRise
end
-- Tangent segments of a ring overlap a little at their outer edge. Every other one is lifted
-- this far, so no two of them ever share a visible face.
Layout.RING_LIFT = 0.1

for row, count in Layout.Rows do
	local radius, rise = Layout.rowRadius(row), Layout.rowRise(row)
	for _, sector in Layout.Sectors do
		local seats = count / 3
		for index = 1, seats do
			local angle = sector[1] + (sector[2] - sector[1]) * (index - 1) / (seats - 1)
			seat({
				Id = "MP" .. tostring(#Layout.Seats + 1),
				Room = "Plenary",
				Role = "Member",
				Row = row,
				Angle = angle,
				Radius = radius,
				Yaw = rad(angle),
				Frame = Layout.facing(angle, radius, rise),
			})
		end
	end
	local step = 2 * Layout.TierSpan / Layout.TierSegments
	for segment = 1, Layout.TierSegments do
		local angle = -Layout.TierSpan + (segment - 0.5) * step
		local p = Layout.polar(angle, radius)
		local lift = if segment % 2 == 0 then Layout.RING_LIFT else 0
		local top = rise + lift
		table.insert(Layout.Tiers, {
			Row = row,
			Frame = F(p.X, (top - 0.4) / 2, p.Z) * A(0, rad(angle), 0),
			Size = V(2 * (radius + Layout.RowPitch / 2) * math.tan(rad(step / 2)) + 0.05, top + 0.4, Layout.RowPitch),
		})
	end
end
-- The Speaker presides from a raised dais at the back of the chamber.
Layout.Dais = { X = 10, Z0 = Layout.Focus.Z - 29, Z1 = Layout.Focus.Z - 13, Height = 1.2 }
Layout.Speaker = V(0, Layout.Dais.Height, Layout.Focus.Z - 21)
seat({ Id = "Speaker", Room = "Plenary", Role = "Speaker", Yaw = pi, Frame = F(Layout.Speaker) * A(0, pi, 0) })
-- Vak K: the government's benches beside the Speaker, facing the members.
Layout.VakK = { From = 100, To = 132, Radii = { 27, 33 }, Counts = { 6, 7 }, RowRise = 0.6 }
do
	local box, index = Layout.VakK, 0
	for row, count in box.Counts do
		local radius = box.Radii[row]
		for place = 1, count do
			index += 1
			local angle = box.From + (box.To - box.From) * (place - 1) / (count - 1)
			seat({
				Id = "VakK" .. tostring(index),
				Room = "Plenary",
				Role = "Minister",
				Row = row,
				Angle = angle,
				Radius = radius,
				Yaw = rad(angle),
				Frame = Layout.facing(angle, radius, (row - 1) * box.RowRise),
			})
		end
	end
end
-- The public gallery rings the chamber one storey up, open behind the Speaker.
Layout.Tribune = { Y = Layout.Storey, Inner = 50, Walk = 53, Seats = 57.5, From = -150, To = 150 }
for index = 1, 30 do
	local angle = -84 + 168 * (index - 1) / 29
	seat({
		Id = "Tribune" .. tostring(index),
		Room = "Tribune",
		Role = "Visitor",
		Angle = angle,
		Yaw = rad(angle),
		Frame = Layout.facing(angle, Layout.Tribune.Seats, Layout.Tribune.Y),
	})
end
-- The Senate: 75 senators on facing benches, the President at the north end. It fills the
-- north of the west wing on the first and second floors.
Layout.Senate = {
	X = -88.75,
	Y = Layout.Storey,
	Z0 = Layout.InnerNorth,
	Z1 = -24,
	Offsets = { 5.5, 9.5, 13.5 },
	RowRise = 0.8,
	FirstZ = -84,
	Spacing = 3.3,
	Counts = { [-1] = { 12, 13, 13 }, [1] = { 12, 12, 13 } },
	Dais = { -96, -89, 6, 1.2 },
	Gallery = -34,
}
do
	local s, index = Layout.Senate, 0
	for _, side in { -1, 1 } do
		for row, offset in s.Offsets do
			for place = 1, s.Counts[side][row] do
				index += 1
				seat({
					Id = "Senator" .. tostring(index),
					Room = "Senate",
					Role = "Senator",
					Side = side,
					Row = row,
					Yaw = side * pi / 2,
					Frame = F(s.X + side * offset, s.Y + (row - 1) * s.RowRise, s.FirstZ + (place - 1) * s.Spacing)
						* A(0, side * pi / 2, 0),
				})
			end
		end
	end
	seat({
		Id = "SenatePresident",
		Room = "Senate",
		Role = "President",
		Yaw = pi,
		Frame = F(s.X, s.Y + s.Dais[4], (s.Dais[1] + s.Dais[2]) / 2) * A(0, pi, 0),
	})
end
-- The Cabinet Room: exactly nine seats, four per side and one distinctive chair at the head.
Layout.Council = { Table = V(-92.5, Layout.Storey, 20), Length = 16, Width = 4.4, Head = -103.4 }
for index = 1, 4 do
	local x = -98.5 + (index - 1) * 4
	seat({ Id = "Council" .. tostring(index), Room = "Council", Role = "Councillor", Yaw = pi, Frame = F(x, Layout.Storey, 16.4) * A(0, pi, 0) })
	seat({ Id = "Council" .. tostring(index + 4), Room = "Council", Role = "Councillor", Yaw = 0, Frame = F(x, Layout.Storey, 23.6) })
end
seat({
	Id = "CouncilChair",
	Room = "Council",
	Role = "Chairperson",
	Special = true,
	Yaw = -pi / 2,
	Frame = F(Layout.Council.Head, Layout.Storey + 0.55, 20) * A(0, -pi / 2, 0),
})

---------------------------------------------------------------------------------------------------
-- Rooms. Wing rooms share one local frame: +u runs from the corridor wall to the windows and
-- w along the wing, so one furniture plan fits both wings. `Spots` are where people sit or stand.

Layout.Rooms, Layout.RoomById = {}, {}
-- Bays along each wing, south to north (the room walls stand on these lines).
local BAY = {
	A = { 7, Layout.StairZ },
	B = { -19, 7 },
	C = { -45, -19 },
	D = { -71, -45 },
	E = { Layout.InnerNorth, -71 },
}
Layout.Bays = BAY

local function spot(room, u: number, w: number, facing: number, kind: string?, role: string?)
	local frame = room.Frame * F(u, 0, w) * A(0, rad(facing), 0)
	local entry = {
		Room = room.Id,
		Kind = kind or "Sit",
		Role = role,
		Frame = frame,
		Position = frame.Position,
		Yaw = room.Yaw + rad(facing),
		Node = "In:" .. room.Id,
		Path = {},
	}
	table.insert(room.Spots, entry)
	return entry
end

local function room(id: string, name: string, kind: string, side: number, floor: number, z0: number, z1: number, doorZ: number?)
	local y = floor * Layout.Storey
	local yaw = if side > 0 then 0 else pi
	local centre = V(side * Layout.RoomCentre, y, (z0 + z1) / 2)
	local entry = {
		Id = id,
		Name = name,
		Kind = kind,
		Side = side,
		Floor = floor,
		Y = y,
		Z0 = z0,
		Z1 = z1,
		Yaw = yaw,
		Centre = centre,
		Frame = F(centre) * A(0, yaw, 0),
		HalfU = Layout.RoomHalfU - 0.2,
		HalfW = (z1 - z0) / 2 - 0.5,
		Doors = { doorZ or (z0 + z1) / 2 },
		Spots = {},
	}
	table.insert(Layout.Rooms, entry)
	Layout.RoomById[id] = entry
	return entry
end

-- A long table down the room with chairs on both sides and one at the head.
local function meeting(entry, perSide: number)
	local gap, centre = 2.8, -0.6
	local length = perSide * gap + 1.2
	entry.Table = { U = centre, W = 0, LU = length, LW = 4.4 }
	for index = 1, perSide do
		local u = centre + (index - (perSide + 1) / 2) * gap
		spot(entry, u, -3.7, 180)
		spot(entry, u, 3.7, 0)
	end
	spot(entry, centre + length / 2 + 1.9, 0, 90, "Sit", "Chair")
end

local PARTY_ROOMS = {}
local function partyRoom(id: string, side: number, floor: number, bay)
	local entry = room(id, "Party Room", "Fractie", side, floor, bay[1], bay[2])
	table.insert(PARTY_ROOMS, entry)
	entry.Party = #PARTY_ROOMS
	meeting(entry, 6)
	spot(entry, -10.2, -9, -90, "Sit", "Lounge")
	spot(entry, -10.2, 9, -90, "Sit", "Lounge")
	return entry
end
-- A horseshoe committee table, open towards the public seats by the door.
local function committee(id: string, name: string, side: number, floor: number, bay)
	local entry = room(id, name, "Committee", side, floor, bay[1], bay[2])
	entry.Horseshoe = { BaseU = 6, ArmW = 6.8, ArmFrom = -5.5, Depth = 2.2 }
	for _, w in { -4.8, -2.4, 2.4, 4.8 } do
		spot(entry, 8.6, w, 90)
	end
	for _, armSide in { -1, 1 } do
		for _, u in { -4.2, -1.4, 1.4, 4.2 } do
			spot(entry, u, armSide * 9.4, if armSide > 0 then 0 else 180)
		end
	end
	spot(entry, 8.6, 0, 90, "Sit", "Chair")
	spot(entry, -7.2, 0, -90, "Sit", "Witness")
	for _, w in { -7.5, -4.5, -1.5, 1.5, 4.5, 7.5 } do
		spot(entry, -10.6, w, -90, "Sit", "Public")
	end
	return entry
end

do
	-- Ground floor, east: everything the public comes for.
	local voting = room("E0A", "Polling Station", "Voting", 1, 0, BAY.A[1], BAY.A[2])
	voting.Booths = {}
	for index = 1, 4 do
		local w = -7.5 + (index - 1) * 5
		table.insert(voting.Booths, voting.Frame * F(10.2, 0, w))
		spot(voting, 7.4, w, -90, "Stand", "Voter")
	end
	voting.OfficialTable = { U = -3, W = -8.2 }
	spot(voting, -4.4, -10.4, 180, "Sit", "Official")
	spot(voting, -1.6, -10.4, 180, "Sit", "Official")
	voting.BallotBox = voting.Frame * F(-1, 0, 5)

	local exhibition = room("E0B", "Visitor Centre", "Exhibition", 1, 0, BAY.B[1], BAY.B[2])
	exhibition.Displays = { { -6.5, -7 }, { 6.5, -7 }, { -6.5, 7 }, { 6.5, 7 } }
	for _, display in exhibition.Displays do
		spot(exhibition, display[1], display[2] * 0.62, if display[2] < 0 then 0 else 180, "Stand", "Visitor")
	end

	local restaurant = room("E0C", "Members' Restaurant", "Restaurant", 1, 0, BAY.D[1], BAY.C[2], -32)
	table.insert(restaurant.Doors, -58)
	restaurant.Tables = {}
	for _, u in { -5, 5 } do
		for row = 1, 7 do
			local w = -16 + (row - 1) * 6.33
			table.insert(restaurant.Tables, { U = u, W = w })
			spot(restaurant, u - 1.9, w, -90)
			spot(restaurant, u + 1.9, w, 90)
			spot(restaurant, u, w - 1.9, 180)
			spot(restaurant, u, w + 1.9, 0)
		end
	end
	for _, u in { -6, -2, 2, 6 } do
		spot(restaurant, u, -21.4, 0, "Stand", "Buffet")
	end
	spot(restaurant, 10, -20.5, 90, "Stand", "Waiter")

	local kitchen = room("E0E", "Kitchen", "Kitchen", 1, 0, BAY.E[1], BAY.E[2])
	spot(kitchen, -3, -8.6, 0, "Stand", "Cook")
	spot(kitchen, 3, -8.6, 0, "Stand", "Cook")
	spot(kitchen, -3, 8.6, 180, "Stand", "Cook")
	spot(kitchen, 8.8, 1, -90, "Stand", "Cook")

	-- Ground floor, west: the working ground floor.
	local mail = room("W0A", "Cloakroom & Post Room", "Mail", -1, 0, BAY.A[1], BAY.A[2])
	spot(mail, 5.8, -3, 90, "Stand", "Bode")
	spot(mail, 5.8, 3, 90, "Stand", "Bode")
	spot(mail, 1, 0, -90, "Stand", "Visitor")

	local press = room("W0B", "Press Room", "Press", -1, 0, BAY.B[1], BAY.B[2])
	spot(press, 9.6, 0, 90, "Stand", "Speaker")
	for _, u in { -6.5, -3.5, -0.5 } do
		for _, w in { -6, -3, 0, 3, 6 } do
			spot(press, u, w, -90, "Sit", "Journalist")
		end
	end
	spot(press, -10.4, -9, -90, "Stand", "Camera")
	spot(press, -10.4, 9, -90, "Stand", "Camera")

	local library = room("W0C", "Library", "Library", -1, 0, BAY.C[1], BAY.C[2])
	library.Tables = { { U = -1, W = -5.2 }, { U = -1, W = 5.2 } }
	for _, desk in library.Tables do
		for _, u in { -2.4, 0, 2.4 } do
			spot(library, desk.U + u, desk.W - 1.9, 180)
			spot(library, desk.U + u, desk.W + 1.9, 0)
		end
	end
	spot(library, 9.6, -8, -90, "Stand", "Reader")
	spot(library, 9.6, 8, -90, "Stand", "Reader")
	spot(library, -9.6, -10, 180, "Sit", "Librarian")

	local cafe = room("W0D", "Coffee Bar", "Cafe", -1, 0, BAY.D[1], BAY.D[2])
	spot(cafe, 10.8, 0, 90, "Stand", "Barista")
	for index = 1, 6 do
		spot(cafe, 7, -7.5 + (index - 1) * 3, -90, "Sit", "Stool")
	end
	cafe.Tables = { { U = -5, W = -8 }, { U = -5, W = 0 }, { U = -5, W = 8 } }
	for _, desk in cafe.Tables do
		spot(cafe, desk.U - 1.9, desk.W, -90)
		spot(cafe, desk.U + 1.9, desk.W, 90)
	end

	local security = room("W0E", "Security Office", "Security", -1, 0, BAY.E[1], BAY.E[2])
	for _, w in { -6, 0, 6 } do
		spot(security, 4, w, -90, "Sit", "Guard")
	end

	-- First floor: committee rooms and the first party rooms in the east,
	-- the cabinet, the Speaker and the Senate in the west.
	committee("E1A", "Committee Room 1", 1, 1, BAY.A)
	committee("E1B", "Committee Room 2", 1, 1, BAY.B)
	committee("E1C", "Committee Room 3", 1, 1, BAY.C)
	partyRoom("E1D", 1, 1, BAY.D)
	partyRoom("E1E", 1, 1, BAY.E)

	local council = room("W1A", "Cabinet Room", "Council", -1, 1, BAY.A[1], BAY.A[2])
	for _, entry in Layout.Seats do
		if entry.Room == "Council" then
			table.insert(council.Spots, {
				Room = "W1A",
				Kind = "Sit",
				Role = entry.Role,
				Seat = entry.Id,
				Frame = entry.Frame,
				Position = entry.Position,
				Yaw = entry.Yaw,
				Node = "In:W1A",
				Path = {},
			})
		end
	end

	local speaker = room("W1B", "Speaker's Office", "Speaker", -1, 1, Layout.Senate.Z1, BAY.B[2], -8.5)
	spot(speaker, 8.4, -11, 90, "Sit", "Speaker")
	speaker.Table = { U = -0.5, W = 6.5, LU = 7, LW = 4 }
	for _, u in { -2.2, 1.2 } do
		spot(speaker, u, 2.9, 180)
		spot(speaker, u, 10.1, 0)
	end
	spot(speaker, -8.4, -12.6, 180, "Sit", "Clerk")
	spot(speaker, -4.4, -12.6, 180, "Sit", "Clerk")

	-- Second floor: one more committee room, the other party rooms, the lounge and offices.
	committee("E2A", "Committee Room 4", 1, 2, BAY.A)
	partyRoom("E2B", 1, 2, BAY.B)
	partyRoom("E2C", 1, 2, BAY.C)
	partyRoom("E2D", 1, 2, BAY.D)
	partyRoom("E2E", 1, 2, BAY.E)

	local lounge = room("W2A", "Members' Lounge", "Lounge", -1, 2, BAY.A[1], BAY.A[2])
	lounge.Sofas = { { U = -3.5, W = -6.2, Facing = 180 }, { U = -3.5, W = 6.2, Facing = 0 }, { U = 6.4, W = 0, Facing = 90 } }
	for _, sofa in lounge.Sofas do
		for _, slide in { -2, 0, 2 } do
			local along = if sofa.Facing == 90 then 0 else slide
			local across = if sofa.Facing == 90 then slide else 0
			spot(lounge, sofa.U + along, sofa.W + across, sofa.Facing)
		end
	end

	local office = room("W2B", "Clerks' Office", "Office", -1, 2, Layout.Senate.Z1, BAY.B[2], -8.5)
	for _, u in { -5.2, 4.6 } do
		for _, w in { -11, -4, 3, 10 } do
			spot(office, u, w, -90, "Sit", "Clerk")
		end
	end
end
Layout.PartyRooms = PARTY_ROOMS

-- Named spaces that are not wing rooms: where to stand and talk.
local function space(id: string, name: string, kind: string, y: number, centre: Vector3)
	local entry = { Id = id, Name = name, Kind = kind, Y = y, Floor = y / Layout.Storey, Centre = centre, Spots = {} }
	table.insert(Layout.Rooms, entry)
	Layout.RoomById[id] = entry
	return entry
end
local function standing(entry, position: Vector3, yaw: number, node: string, role: string?)
	table.insert(entry.Spots, {
		Room = entry.Id,
		Kind = "Stand",
		Role = role,
		Frame = F(position) * A(0, yaw, 0),
		Position = position,
		Yaw = yaw,
		Node = node,
		Path = {},
	})
end
-- Interior columns of the Great Hall stand on this ring.
Layout.HallColumns = { Radius = 90, Angles = { -38.5, -27.5, -16.5, -5.5, 5.5, 16.5, 27.5, 38.5 }, Diameter = 3.2 }
do
	local hall = space("Hall", "Great Hall", "Hall", 0, V(0, 0, 66))
	for _, side in { -1, 1 } do
		local wing = if side > 0 then "E" else "W"
		-- Pairs talking in the hall, between the columns and clear of the walking line.
		for _, degrees in { 11, 22, 33 } do
			local a, b = Layout.polar(side * (degrees - 1.6), 86), Layout.polar(side * (degrees + 1.6), 86)
			local node = "Hall" .. wing .. (if degrees < 20 then "15" elseif degrees < 30 then "30" else "41")
			standing(hall, a, math.atan2(a.X - b.X, a.Z - b.Z), node)
			standing(hall, b, math.atan2(b.X - a.X, b.Z - a.Z), node)
		end
		standing(hall, V(side * 7, 0, 76), 0, "Entry", "Guard")
	end
	-- The reception desk follows the curve of the hall, clear of the walking line.
	Layout.Reception = Layout.facing(-14, 75.5)
	standing(hall, Layout.polar(-11.5, 73), rad(-11.5) + pi, "HallW15", "Reception")
	standing(hall, Layout.polar(-16.5, 73), rad(-16.5) + pi, "HallW15", "Reception")

	local lobby = space("Wandelgang", "Members' Lobby", "Lobby", 0, V(0, 0, -90))
	for _, x in { -48, -26, 20, 42 } do
		local node = if x < -37 then "R0_-56" elseif x > 31 then "R0_56" else "R0_0"
		standing(lobby, V(x, 0, -93.5), -pi / 2, node)
		standing(lobby, V(x + 3.2, 0, -93.5), pi / 2, node)
	end
end
space("Plenary", "House of Representatives", "Plenary", 0, Layout.Focus)
space("Tribune", "Public Gallery", "Tribune", Layout.Storey, Layout.Focus + V(0, Layout.Storey, 0))
space("Senate", "Senate", "Senate", Layout.Storey, V(Layout.Senate.X, Layout.Storey, -60))
Layout.Bell = F(4.5, Layout.Dais.Height + 4, Layout.Dais.Z1 - 0.6)

---------------------------------------------------------------------------------------------------
-- The walking graph. Nodes are building-local points; links are straight, clear walks.

Layout.Nodes, Layout.Links = {}, {}
local function node(id: string, position: Vector3)
	Layout.Nodes[id] = position
	Layout.Links[id] = Layout.Links[id] or {}
end
local function link(a: string, b: string)
	assert(Layout.Nodes[a] and Layout.Nodes[b], "Unknown parliament node " .. a .. " or " .. b)
	table.insert(Layout.Links[a], b)
	table.insert(Layout.Links[b], a)
end
local function chain(ids: { string })
	for index = 2, #ids do
		link(ids[index - 1], ids[index])
	end
end
local function corridor(wing: string, floor: number, z: number): string
	return "C" .. wing .. tostring(floor) .. "_" .. tostring(z)
end
Layout.corridorNode = corridor

-- Whether a wing floor's corridor stops short at the Senate (west, first and second floors).
function Layout.senateFloor(side: number, floor: number): boolean
	return side < 0 and floor > 0
end

do
	local fz, storey, cx = Layout.Focus.Z, Layout.Storey, Layout.CorridorX
	node("Out", V(0, 0, 93))
	node("Entry", V(0, 0, 77))
	node("Hall0", Layout.polar(0, 86))
	node("Well", Layout.polar(0, 5))
	node("WellW", V(-15, 0, fz + 2))
	node("Behind", V(-16, 0, Layout.Dais.Z0 - 3))
	node("TKNorthIn", Layout.polar(180, 58))
	chain({ "Out", "Entry", "Hall0" })
	chain({ "Well", "WellW", "Behind", "TKNorthIn" })
	for floor = 0, 2 do
		local y = floor * storey
		for _, x in { -56, 0, 56 } do
			node("R" .. floor .. "_" .. x, V(x, y, Layout.RearDoorZ))
		end
		chain({ "R" .. floor .. "_-56", "R" .. floor .. "_0", "R" .. floor .. "_56" })
	end
	link("TKNorthIn", "R0_0")
	local topRise = Layout.rowRise(#Layout.Rows)
	for _, side in { -1, 1 } do
		local wing = if side > 0 then "E" else "W"
		-- Along the hall, and through the public door up the aisle ramp and down the aisle.
		node("Hall" .. wing .. "15", Layout.polar(side * 15, 82))
		node("Hall" .. wing .. "30", Layout.polar(side * 30, 82))
		node("Hall" .. wing .. "41", Layout.polar(side * 41, 82))
		node("HallDoor" .. wing, V(side * 64, 0, 43))
		node("StairHall" .. wing, V(side * cx, 0, 43))
		node("TKOut" .. wing, Layout.polar(side * 30, 70))
		node("TKIn" .. wing, Layout.polar(side * 30, 59.5))
		node("TKTop" .. wing, Layout.polar(side * 30, 49, topRise))
		chain({ "Hall0", "Hall" .. wing .. "15", "Hall" .. wing .. "30", "Hall" .. wing .. "41", "HallDoor" .. wing, "StairHall" .. wing })
		chain({ "Hall" .. wing .. "30", "TKOut" .. wing, "TKIn" .. wing, "TKTop" .. wing })
		local previous = "TKTop" .. wing
		for row = #Layout.Rows, 1, -1 do
			local id = "Aisle" .. wing .. row
			node(id, Layout.polar(side * 30, Layout.rowRadius(row), Layout.rowRise(row)))
			link(previous, id)
			previous = id
		end
		node("AisleFoot" .. wing, Layout.polar(side * 30, 17))
		chain({ previous, "AisleFoot" .. wing, "Well" })
		-- The members' side doors open onto the floor of the house.
		node("TKSide" .. wing, V(side * 58, 0, Layout.SideDoorZ))
		node("TKMid" .. wing, V(side * 14, 0, Layout.SideDoorZ))
		chain({ "TKSide" .. wing, "TKMid" .. wing, "Well" })

		for floor = 0, 2 do
			local y = floor * storey
			local senate = Layout.senateFloor(side, floor)
			local stops = { [35] = true }
			if senate then
				stops[-22] = true
			else
				stops[Layout.RearDoorZ] = true
			end
			if floor < 2 then
				stops[Layout.SideDoorZ] = true
			end
			if floor == 0 then
				stops[43] = true
			end
			for _, entry in Layout.Rooms do
				if entry.Side == side and entry.Floor == floor and entry.Doors then
					for _, z in entry.Doors do
						stops[z] = true
					end
				end
			end
			local ordered = {}
			for z in stops do
				table.insert(ordered, z)
			end
			table.sort(ordered)
			local ids = {}
			for _, z in ordered do
				node(corridor(wing, floor, z), V(side * cx, y, z))
				table.insert(ids, corridor(wing, floor, z))
			end
			chain(ids)
			node("L" .. wing .. floor, V(side * cx, y, 35))
			if not senate then
				link(corridor(wing, floor, Layout.RearDoorZ), "R" .. floor .. "_" .. tostring(side * 56))
			end
		end
		link("StairHall" .. wing, corridor(wing, 0, 43))
		link("TKSide" .. wing, corridor(wing, 0, Layout.SideDoorZ))
		-- Switchback stairs: two flights per storey, joined by a landing along the front wall.
		local s = Layout.Stair
		for storeyIndex = 0, 1 do
			local y = storeyIndex * storey
			local tag = wing .. storeyIndex
			node("SA" .. tag, V(side * s.A, y, s.Low - 0.5))
			node("SB" .. tag, V(side * s.A, y + storey / 2, s.High + 0.5))
			node("SM" .. tag, V(side * (s.Spine[1] + s.Spine[2]) / 2, y + storey / 2, 61))
			node("SC" .. tag, V(side * s.B, y + storey / 2, s.High + 0.5))
			node("SD" .. tag, V(side * s.B, y + storey, 35))
			chain({ corridor(wing, storeyIndex, 35), "SA" .. tag, "SB" .. tag, "SM" .. tag, "SC" .. tag, "SD" .. tag, corridor(wing, storeyIndex + 1, 35) })
		end
	end
	for _, entry in Layout.Rooms do
		if entry.Doors then
			local wing = if entry.Side > 0 then "E" else "W"
			node("In:" .. entry.Id, V(entry.Side * 85.5, entry.Y, entry.Doors[1]))
			link("In:" .. entry.Id, corridor(wing, entry.Floor, entry.Doors[1]))
		end
	end
	-- The gallery horseshoe, entered from both first-floor corridors.
	local ring = {}
	for degrees = Layout.Tribune.From, Layout.Tribune.To, 15 do
		node("Trib" .. degrees, Layout.polar(degrees, Layout.Tribune.Walk, Layout.Tribune.Y))
		table.insert(ring, "Trib" .. degrees)
	end
	chain(ring)
	for _, side in { -1, 1 } do
		local wing = if side > 0 then "E" else "W"
		node("TribDoor" .. wing, V(side * 58, Layout.Tribune.Y, Layout.SideDoorZ))
		chain({ "Trib" .. (side * 90), "TribDoor" .. wing, corridor(wing, 1, Layout.SideDoorZ) })
	end
	-- Senate: the south door from the corridor, the north door to the Members' Lobby gallery.
	local senate = Layout.Senate
	local north = senate.Dais[2] + 1.7
	node("EKIn", V(-cx, senate.Y, senate.Z1 - 3))
	node("EKAisleS", V(senate.X, senate.Y, senate.Z1 - 6))
	node("EKAisleN", V(senate.X, senate.Y, north))
	node("EKSide", V(-74.5, senate.Y, north))
	chain({ corridor("W", 1, -22), "EKIn", "EKAisleS", "EKAisleN", "EKSide", "R1_-56" })
	node("EKGalleryDoor", V(-cx, 2 * storey, senate.Z1 - 3))
	node("EKGallery", V(senate.X - 4, 2 * storey, (senate.Gallery + senate.Z1) / 2))
	chain({ corridor("W", 2, -22), "EKGalleryDoor", "EKGallery" })
end

-- How each real seat is reached: the graph node to walk to, then any points after it.
do
	local function reach(entry, nodeId: string, path: { Vector3 })
		entry.Node, entry.Path, entry.Kind = nodeId, path, "Sit"
	end
	-- Walks along an arc at `radius` and `y` from one angle to another, a point every 8 degrees.
	local function arc(path, from: number, to: number, radius: number, y: number)
		local steps = math.max(1, math.ceil(math.abs(to - from) / 8))
		for step = 1, steps do
			table.insert(path, Layout.polar(from + (to - from) * step / steps, radius, y))
		end
	end
	for _, entry in Layout.Seats do
		if entry.Role == "Member" then
			local side = if entry.Angle < 0 then -1 else 1
			-- Along the row behind the seats, then into the seat.
			local path = { Layout.polar(side * 30, entry.Radius + 1.65, Layout.rowRise(entry.Row)) }
			arc(path, side * 30, entry.Angle, entry.Radius + 1.65, Layout.rowRise(entry.Row))
			reach(entry, "Aisle" .. (if side > 0 then "E" else "W") .. entry.Row, path)
		elseif entry.Role == "Speaker" then
			local dais = Layout.Dais
			reach(entry, "WellW", { V(-15, 0, Layout.Speaker.Z), V(-11.5, dais.Height / 2, Layout.Speaker.Z - 1), V(-7, dais.Height, Layout.Speaker.Z - 2) })
		elseif entry.Role == "Minister" then
			local radius, y = entry.Radius + 2.15, (entry.Row - 1) * Layout.VakK.RowRise
			local path = { Layout.polar(96, radius, y) }
			arc(path, 96, entry.Angle, radius, y)
			reach(entry, "TKMidE", path)
		elseif entry.Room == "Tribune" then
			local nearest = math.floor(entry.Angle / 15 + 0.5) * 15
			reach(entry, "Trib" .. nearest, { Layout.polar(entry.Angle, Layout.Tribune.Walk, Layout.Tribune.Y) })
		elseif entry.Role == "President" then
			local s = Layout.Senate
			reach(entry, "EKAisleN", { V(s.X + s.Dais[3] + 1.5, s.Y, s.Dais[2] + 1), V(s.X + s.Dais[3] - 1, s.Y + s.Dais[4], entry.Position.Z) })
		elseif entry.Room == "Senate" then
			local z = entry.Position.Z
			reach(entry, if z < -62 then "EKAisleN" else "EKAisleS", { V(Layout.Senate.X, Layout.Senate.Y, z) })
		else
			reach(entry, "In:W1A", {})
		end
	end
end

-- Shortest walk between two nodes, as a list of node ids including both ends.
function Layout.route(from: string, to: string): { string }?
	if from == to then
		return { from }
	end
	local distance, previous, open = { [from] = 0 }, {}, { from }
	while #open > 0 do
		local best = 1
		for index = 2, #open do
			if distance[open[index]] < distance[open[best]] then
				best = index
			end
		end
		local current = table.remove(open, best)
		if current == to then
			break
		end
		for _, other in Layout.Links[current] do
			local length = distance[current] + (Layout.Nodes[other] - Layout.Nodes[current]).Magnitude
			if not distance[other] or length < distance[other] then
				if not distance[other] then
					table.insert(open, other)
				end
				distance[other], previous[other] = length, current
			end
		end
	end
	if not distance[to] then
		return nil
	end
	local ids, cursor = { to }, to
	while cursor ~= from do
		cursor = previous[cursor]
		table.insert(ids, 1, cursor)
	end
	return ids
end

function Layout.inside(base: CFrame, position: Vector3): boolean
	local p = base:PointToObjectSpace(position)
	if math.abs(p.X) >= Layout.HalfWidth - 0.8 or p.Z <= Layout.North + 0.8 or p.Y <= -0.5 or p.Y >= Layout.Height then
		return false
	end
	if math.abs(p.X) > Layout.WingInner then
		return p.Z < Layout.WingFront - 0.8
	end
	local dx, dz = p.X - Layout.Focus.X, p.Z - Layout.Focus.Z
	return dx * dx + dz * dz < (Layout.HallRadius - 0.8) ^ 2
end

-- Close enough to the square to see the facade ornament.
function Layout.near(base: CFrame, position: Vector3, distance: number): boolean
	local p = base:PointToObjectSpace(position)
	return p.X * p.X + p.Z * p.Z < distance * distance and math.abs(p.Y) < distance
end
return Layout
