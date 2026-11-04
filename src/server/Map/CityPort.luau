-- The city's docks, laid out like Southampton's at the head of a long estuary. Ships come
-- down the channel from the north-west into a wide basin: a container terminal lines the west
-- bank, the eastern docks face it as a comb of finger jetties with a slip between each pair,
-- a branch cut into the east bank north of them takes the cruise liners, and a marina fills
-- the head.
-- Positions are relative to the city centre at water level; north is -Z.
local CityBuildings = require(script.Parent.CityBuildings)

local CityPort = {}

-- Quay lines shared with the coastline in ModernCity
CityPort.WEST_QUAY = -620 -- container terminal, water to the east
CityPort.EAST_QUAY = -180 -- heads of the eastern jetties, water to the west
CityPort.HEAD = -150 -- head of the estuary, water to the north
CityPort.WEST_NORTH = -960
-- The eastern docks: jetties run from the back wall out to the basin, the slips between
-- them are open water, and the back apron reaches the first city street
CityPort.DOCKS = { x0 = CityPort.EAST_QUAY, back = 0, x1 = 52, z0 = -765, z1 = CityPort.HEAD }
CityPort.JETTIES = { { -678, -638 }, { -551, -491 }, { -404, -364 }, { -277, -237 } } -- north to south, {z0, z1}
CityPort.CRUISE_JETTY = 2
-- The cruise branch off the east bank, with a berth along each side: x0 is the south corner of
-- its mouth, mouth the north corner (the bank slants back towards the sea) and x1 its head
CityPort.CRUISE_BASIN = { x0 = -240, mouth = -460, x1 = 220, z0 = -1230, z1 = -940 }
-- Channel centreline from the estuary mouth to the berths, for buoys and checks
CityPort.CHANNEL = { { -935, -1570 }, { -780, -1300 }, { -630, -1100 }, { -495, -900 }, { -410, -700 }, { -400, -400 } }

-- The quay walls from the north end of the container terminal, round the head of the
-- estuary and in and out of every slip, ending at the north wall of the eastern docks
function CityPort.quays(): { { any } }
	local docks = CityPort.DOCKS
	local points = {
		{ CityPort.WEST_QUAY, CityPort.WEST_NORTH, "quay" },
		{ CityPort.WEST_QUAY, CityPort.HEAD, "quay" },
		{ docks.back, CityPort.HEAD, "quay" },
	}
	for k = #CityPort.JETTIES, 1, -1 do
		local jetty = CityPort.JETTIES[k]
		table.insert(points, { docks.back, jetty[2], "quay" })
		table.insert(points, { docks.x0, jetty[2], "quay" })
		table.insert(points, { docks.x0, jetty[1], "quay" })
		table.insert(points, { docks.back, jetty[1], "quay" })
	end
	table.insert(points, { docks.back, docks.z0, "quay" })
	return points
end

-- The quay walls of the cruise branch, from the south corner of its mouth round the head to
-- the north corner, where the natural bank carries on towards the sea
function CityPort.cruiseQuays(): { { any } }
	local basin = CityPort.CRUISE_BASIN
	return {
		{ basin.x0, basin.z1, "quay" },
		{ basin.x1, basin.z1, "quay" },
		{ basin.x1, basin.z0, "quay" },
		{ basin.mouth, basin.z0 },
	}
end

-- The slips between the jetties, north to south, as {z0, z1}
function CityPort.slips(): { { number } }
	local slips, z = {}, CityPort.DOCKS.z0
	for _, jetty in CityPort.JETTIES do
		table.insert(slips, { z, jetty[1] })
		z = jetty[2]
	end
	table.insert(slips, { z, CityPort.HEAD })
	return slips
end

local rgb = Color3.fromRGB
local M = Enum.Material
local concrete = rgb(124, 126, 122)
local apron = rgb(108, 110, 108)
local dark = rgb(44, 50, 54)
local craneBlue = rgb(52, 88, 128)
local white = rgb(222, 222, 214)
local CONTAINERS = {
	rgb(52, 96, 128), rgb(160, 70, 52), rgb(188, 142, 58), rgb(78, 118, 100),
	rgb(112, 116, 124), rgb(168, 176, 170), rgb(138, 82, 56), rgb(56, 64, 86),
	rgb(196, 196, 186), rgb(92, 52, 48),
}

-- Every model that streams as one piece; see server/Map/Lod.
local function pieceModel(parent: Instance, name: string, lodColor: Color3?): Model
	local m = Instance.new("Model")
	m.Name = name
	if lodColor then
		m:SetAttribute("LodColor", lodColor)
	end
	m:AddTag("LodPiece")
	m.Parent = parent
	return m
end

function CityPort.build(parent: Instance, origin: Vector3, top: number): { { number } }
	local port = Instance.new("Model")
	port.Name = "CityPort"
	port.Parent = parent
	-- Rectangles {x0, x1, z0, z1} the countryside must keep clear of
	local reserved: { { number } } = {}

	local function part(into: Instance, name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material, collide: boolean?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Position = origin + offset
		p.Anchored = true
		p.Color = color
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = collide ~= false
		if collide == false then
			p.CanQuery = false
		end
		p.Parent = into
		return p
	end
	local function cylinder(into: Instance, name: string, diameter: number, height: number, offset: Vector3, color: Color3, material: Enum.Material, collide: boolean?): Part
		local p = part(into, name, Vector3.new(height, diameter, diameter), offset, color, material, collide)
		p.Shape = Enum.PartType.Cylinder
		p.CFrame = CFrame.new(origin + offset) * CFrame.Angles(0, 0, math.pi / 2)
		return p
	end
	local function keep(p: BasePart): BasePart
		p:SetAttribute("LodKeep", true)
		return p
	end
	-- A sloped strut between two points, for crane stays and gangways
	local function strut(into: Instance, name: string, a: Vector3, b: Vector3, thickness: number, color: Color3, material: Enum.Material, collide: boolean?): Part
		local p = part(into, name, Vector3.new(thickness, thickness, (b - a).Magnitude), (a + b) / 2, color, material, collide)
		p.CFrame = CFrame.lookAt(origin + (a + b) / 2, origin + b)
		return p
	end

	local W, H = CityPort.WEST_QUAY, CityPort.HEAD
	local deck = top + 0.3

	---------------------------------------------------------------------------------------------
	-- Container terminal on the west bank

	local yardX0, yardZ0, yardZ1 = W - 400, CityPort.WEST_NORTH + 5, H - 5
	table.insert(reserved, { yardX0 - 20, W, yardZ0 - 20, yardZ1 + 10 })
	part(port, "TerminalYard", Vector3.new(W - yardX0, 0.6, yardZ1 - yardZ0), Vector3.new((W + yardX0) / 2, top, (yardZ0 + yardZ1) / 2), apron, M.Concrete)
	for _, x in { W - 8, W - 50 } do
		part(port, "CraneRail", Vector3.new(1.2, 0.3, yardZ1 - yardZ0), Vector3.new(x, deck + 0.05, (yardZ0 + yardZ1) / 2), dark, M.Metal, false)
	end
	part(port, "QuayEdgeLine", Vector3.new(1, 0.1, yardZ1 - yardZ0), Vector3.new(W - 3, deck + 0.02, (yardZ0 + yardZ1) / 2), rgb(214, 182, 72), M.SmoothPlastic, false)
	for z = yardZ0 + 20, yardZ1 - 20, 45 do
		part(port, "MooringBollard", Vector3.new(2.5, 3, 2.5), Vector3.new(W - 3, deck + 1.5, z), dark, M.Metal)
	end

	-- Ship-to-shore gantry cranes stand on the quay rails with their booms over the berth
	for index, z in { -900, -815, -730, -645, -560, -475, -390 } do
		local crane = pieceModel(port, "GantryCrane")
		local wx, lx = W - 8, W - 50
		for _, leg in { wx, lx } do
			for _, dz in { -14, 14 } do
				keep(part(crane, "CraneLeg", Vector3.new(3.5, 70, 3.5), Vector3.new(leg, deck + 35, z + dz), craneBlue, M.Metal))
				part(crane, "CraneBogie", Vector3.new(4, 3, 9), Vector3.new(leg, deck + 1.5, z + dz), dark, M.Metal)
			end
			part(crane, "PortalBeam", Vector3.new(3, 4, 32), Vector3.new(leg, deck + 68, z), craneBlue, M.Metal)
		end
		part(crane, "SillBeam", Vector3.new(wx - lx - 3.5, 3, 3), Vector3.new((wx + lx) / 2, deck + 26, z - 14), craneBlue, M.Metal)
		part(crane, "SillBeam", Vector3.new(wx - lx - 3.5, 3, 3), Vector3.new((wx + lx) / 2, deck + 26, z + 14), craneBlue, M.Metal)
		-- The boom reaches well past the ship; the backreach carries the machinery house
		local tip, back = W + 95, lx - 30
		keep(part(crane, "CraneBoom", Vector3.new(tip - back, 5, 6), Vector3.new((tip + back) / 2, deck + 74, z), craneBlue, M.Metal))
		part(crane, "MachineryHouse", Vector3.new(18, 10, 16), Vector3.new(back + 10, deck + 81, z), white, M.SmoothPlastic)
		for _, dz in { -2.5, 2.5 } do
			keep(part(crane, "ApexPost", Vector3.new(2.5, 32, 2.5), Vector3.new(wx - 4, deck + 92, z + dz), craneBlue, M.Metal))
			strut(crane, "ForeStay", Vector3.new(wx - 4, deck + 107, z + dz), Vector3.new(tip - 4, deck + 76, z + dz), 1.2, craneBlue, M.Metal, false)
			strut(crane, "BackStay", Vector3.new(wx - 4, deck + 107, z + dz), Vector3.new(back + 2, deck + 76, z + dz), 1.2, craneBlue, M.Metal, false)
		end
		-- With the berth empty, the trolleys wait over the quay edge
		local trolley = W + 10 + (index % 3) * 18
		part(crane, "CraneCab", Vector3.new(7, 6, 7), Vector3.new(trolley, deck + 68, z), white, M.SmoothPlastic, false)
		part(crane, "HoistCable", Vector3.new(0.4, 10, 0.4), Vector3.new(trolley, deck + 60, z), dark, M.Metal, false)
		part(crane, "Spreader", Vector3.new(9, 1.5, 34), Vector3.new(trolley, deck + 54.5, z), rgb(204, 168, 60), M.Metal, false)
	end

	-- Container stacks in five lanes, with straddle-crane gaps between blocks of rows
	local laneXs = { W - 100, W - 160, W - 220, W - 280, W - 340 }
	local containerSize = Vector3.new(7, 7.4, 34)
	local row = 0
	for lane, lx in laneXs do
		local block: Model? = nil
		for z = yardZ0 + 30, yardZ1 - 60, 38 do
			row += 1
			if row % 6 == 0 then
				-- A cross aisle every few rows lets trucks through
				block = nil
				continue
			end
			if not block or #block:GetChildren() > 120 then
				block = pieceModel(port, "ContainerStacks", CONTAINERS[lane % #CONTAINERS + 1]:Lerp(rgb(120, 110, 100), 0.4))
			end
			for column = 0, 4 do
				local hash = (row * 31 + column * 17 + lane * 7) % 29
				local tiers = 1 + hash % 4
				if hash % 11 == 0 then
					tiers = 0
				end
				for tier = 1, tiers do
					local color = CONTAINERS[(row * 3 + column * 5 + tier * 7 + lane) % #CONTAINERS + 1]
					local y = deck + 0.3 + (tier - 0.5) * containerSize.Y
					part(block :: Model, "Container", containerSize, Vector3.new(lx + (column - 2) * 7.1, y, z), color, M.Metal)
				end
			end
		end
	end
	-- Rubber-tyred gantries straddle the lanes
	for lane, lx in laneXs do
		local rtg = pieceModel(port, "YardGantry")
		local z = yardZ0 + 60 + lane * 110
		for _, dx in { -21, 21 } do
			for _, dz in { -10, 10 } do
				part(rtg, "GantryLeg", Vector3.new(2, 34, 2), Vector3.new(lx + dx, deck + 17, z + dz), rgb(200, 170, 60), M.Metal)
			end
			part(rtg, "GantryWheels", Vector3.new(3, 3, 24), Vector3.new(lx + dx, deck + 1.5, z), dark, M.Rubber)
		end
		for _, dz in { -10, 10 } do
			part(rtg, "GantryGirder", Vector3.new(46, 3, 2.5), Vector3.new(lx, deck + 35, z + dz), rgb(200, 170, 60), M.Metal)
		end
		part(rtg, "GantryCab", Vector3.new(5, 4, 5), Vector3.new(lx + 12, deck + 31, z), white, M.SmoothPlastic, false)
	end
	-- Floodlight masts and trucks waiting under the cranes
	for z = yardZ0 + 40, yardZ1, 150 do
		for _, x in { W - 70, yardX0 + 30 } do
			local mast = pieceModel(port, "FloodlightMast")
			keep(part(mast, "MastPole", Vector3.new(1.6, 80, 1.6), Vector3.new(x, deck + 40, z), rgb(150, 150, 146), M.Metal))
			part(mast, "MastLamps", Vector3.new(8, 3, 8), Vector3.new(x, deck + 81, z), rgb(70, 74, 76), M.Metal)
		end
	end
	for index, z in { -870, -770, -690, -600, -520, -430, -300, -240 } do
		local truck = pieceModel(port, "Truck")
		local x = W - 30 + (index % 2) * 6
		part(truck, "TruckCab", Vector3.new(7, 7, 8), Vector3.new(x, deck + 4.5, z - 21), CONTAINERS[index + 2], M.SmoothPlastic)
		part(truck, "TruckChassis", Vector3.new(6, 1.6, 36), Vector3.new(x, deck + 1.8, z), dark, M.Metal)
		part(truck, "TruckContainer", containerSize, Vector3.new(x, deck + 6.4, z + 2), CONTAINERS[index * 3 % #CONTAINERS + 1], M.Metal)
	end
	-- A rail siding along the back of the yard, with a container train being loaded
	local railX, railZ0, railZ1 = yardX0 + 15, yardZ0 + 20, yardZ1 - 70
	local siding = pieceModel(port, "RailSiding")
	part(siding, "SidingBallast", Vector3.new(10, 0.4, railZ1 - railZ0), Vector3.new(railX, deck + 0.2, (railZ0 + railZ1) / 2), rgb(96, 90, 84), M.Pebble, false)
	for _, dx in { -2.5, 2.5 } do
		part(siding, "SidingRail", Vector3.new(0.5, 0.5, railZ1 - railZ0), Vector3.new(railX + dx, deck + 0.65, (railZ0 + railZ1) / 2), rgb(120, 110, 100), M.Metal, false)
	end
	local wagons = pieceModel(port, "ContainerTrain", rgb(110, 90, 80))
	for k = 0, 9 do
		local z = railZ0 + 30 + k * 44
		part(wagons, "Flatcar", Vector3.new(8, 1.6, 40), Vector3.new(railX, deck + 2.4, z), rgb(70, 60, 56), M.Metal)
		for _, dz in { -16, 16 } do
			part(wagons, "Bogie", Vector3.new(6, 1.6, 6), Vector3.new(railX, deck + 1, z + dz), dark, M.Metal)
		end
		if k % 4 ~= 3 then
			part(wagons, "WagonContainer", containerSize, Vector3.new(railX, deck + 6.9, z), CONTAINERS[(k * 7 + 3) % #CONTAINERS + 1], M.Metal)
		end
	end
	part(wagons, "Locomotive", Vector3.new(9, 12, 46), Vector3.new(railX, deck + 7.5, railZ0 + 30 + 10 * 44 + 1), rgb(196, 160, 52), M.SmoothPlastic)
	part(wagons, "LocoCab", Vector3.new(9.3, 3, 8), Vector3.new(railX, deck + 11, railZ0 + 30 + 10 * 44 - 16), rgb(40, 46, 52), M.Glass, false)
	-- Gatehouse and the terminal office at the landward end of the yard
	local gate = pieceModel(port, "TerminalGate", rgb(140, 140, 136))
	part(gate, "GateCanopy", Vector3.new(80, 2, 24), Vector3.new(yardX0 + 120, deck + 14, yardZ1 - 14), rgb(196, 196, 190), M.Metal)
	for _, dx in { -36, -12, 12, 36 } do
		part(gate, "GateBooth", Vector3.new(4, 9, 7), Vector3.new(yardX0 + 120 + dx, deck + 4.5, yardZ1 - 14), white, M.SmoothPlastic)
		part(gate, "CanopyColumn", Vector3.new(1.2, 13, 1.2), Vector3.new(yardX0 + 120 + dx, deck + 6.5, yardZ1 - 4), dark, M.Metal)
	end
	local office = pieceModel(port, "TerminalOffice")
	CityBuildings.block(office, CFrame.new(origin + Vector3.new(yardX0 + 30, deck, yardZ1 - 30)) * CFrame.Angles(0, math.pi / 2, 0), 48, 30, 5, 11)

	---------------------------------------------------------------------------------------------
	-- Eastern docks: ships berth along both sides of every jetty and across the head of each
	-- slip. The widest jetty carries the cruise terminal; the others have transit sheds and
	-- level-luffing cranes, and the old brick sheds line the back apron.

	local docks = CityPort.DOCKS
	local back, tip, north = docks.back, docks.x0, docks.z0
	local northEnd = -230 -- where the north wall meets the natural bank, kept clear of it
	table.insert(reserved, { tip, docks.x1, north - 30, H })
	local yellow, craneRed = rgb(214, 182, 72), rgb(150, 62, 48)
	-- A painted line and bollards a few studs in from a quay wall; (nx, nz) points inland
	local function quayEdge(ax: number, az: number, bx: number, bz: number, nx: number, nz: number)
		local length = math.abs(bx - ax) + math.abs(bz - az)
		local size = if ax == bx then Vector3.new(1, 0.1, length - 2) else Vector3.new(length - 2, 0.1, 1)
		part(port, "QuayEdgeLine", size, Vector3.new((ax + bx) / 2 + nx * 3, deck + 0.02, (az + bz) / 2 + nz * 3), yellow, M.SmoothPlastic, false)
		local count = math.max(1, math.floor(length / 32))
		for k = 1, count do
			local t = (k - 0.5) / count
			part(port, "MooringBollard", Vector3.new(2.5, 3, 2.5), Vector3.new(ax + (bx - ax) * t + nx * 3, deck + 1.5, az + (bz - az) * t + nz * 3), dark, M.Metal)
		end
	end
	-- A level-luffing crane on a portal the trucks drive under, its jib out over the slip
	local function dockCrane(x: number, z: number, reach: number)
		local crane = pieceModel(port, "DockCrane", craneRed)
		for _, dx in { -4.5, 4.5 } do
			for _, dz in { -4.5, 4.5 } do
				part(crane, "PortalLeg", Vector3.new(1.4, 16, 1.4), Vector3.new(x + dx, deck + 8, z + dz), craneRed, M.Metal)
			end
		end
		part(crane, "PortalDeck", Vector3.new(11, 2, 11), Vector3.new(x, deck + 17, z), craneRed, M.Metal)
		keep(part(crane, "CraneTower", Vector3.new(4, 12, 4), Vector3.new(x, deck + 24, z), craneRed, M.Metal))
		part(crane, "CraneHouse", Vector3.new(9, 8, 11), Vector3.new(x, deck + 34, z - math.sign(reach) * 2), rgb(206, 204, 196), M.SmoothPlastic)
		part(crane, "Counterweight", Vector3.new(6, 5, 4), Vector3.new(x, deck + 33, z - math.sign(reach) * 9), dark, M.Metal)
		keep(strut(crane, "CraneJib", Vector3.new(x, deck + 36, z), Vector3.new(x, deck + 50, z + reach), 1.6, craneRed, M.Metal, false))
		part(crane, "HoistCable", Vector3.new(0.3, 16, 0.3), Vector3.new(x, deck + 42, z + reach), dark, M.Metal, false)
		part(crane, "CraneHook", Vector3.new(1.6, 1.6, 1.6), Vector3.new(x, deck + 33.5, z + reach), yellow, M.Metal, false)
	end

	-- Back apron along the slip heads, the north wall and the jetties themselves
	part(port, "DockApron", Vector3.new(docks.x1 - back, 0.6, H - north + 25), Vector3.new((back + docks.x1) / 2, top, (H + north - 25) / 2), apron, M.Concrete)
	part(port, "NorthWallApron", Vector3.new(back - northEnd, 0.6, 22), Vector3.new((back + northEnd) / 2, top, north - 11), apron, M.Concrete)
	quayEdge(northEnd, north, back, north, 0, -1)
	quayEdge(tip, H, back, H, 0, 1)
	for _, slip in CityPort.slips() do
		quayEdge(back, slip[1], back, slip[2], 1, 0)
	end
	for index, jetty in CityPort.JETTIES do
		local z0, z1 = jetty[1], jetty[2]
		local zm = (z0 + z1) / 2
		part(port, "JettyApron", Vector3.new(back - tip, 0.6, z1 - z0), Vector3.new((back + tip) / 2, top, zm), apron, M.Concrete)
		quayEdge(tip, z0, back, z0, 0, 1)
		quayEdge(tip, z1, back, z1, 0, -1)
		quayEdge(tip, z0, tip, z1, 1, 0)
		if index == CityPort.CRUISE_JETTY then
			-- The terminal hall down the middle of the jetty, waiting for the next liner
			local terminal = pieceModel(port, "CruiseTerminal", rgb(150, 156, 160))
			local tx, tw, tl = (tip + back) / 2 + 8, z1 - z0 - 26, back - tip - 36
			part(terminal, "TerminalHall", Vector3.new(tl, 20, tw), Vector3.new(tx, deck + 10, zm), rgb(176, 178, 174), M.Concrete)
			part(terminal, "HallGlazing", Vector3.new(tl - 10, 9, tw + 0.3), Vector3.new(tx, deck + 11, zm), rgb(58, 74, 84), M.Glass, false)
			for _, side in { -1, 1 } do
				local roof = part(terminal, "HallRoof", Vector3.new(tl + 4, 1, tw / 2 + 3), Vector3.new(tx, deck + 22, zm + side * tw / 4), rgb(140, 146, 150), M.Metal)
				roof.CFrame = roof.CFrame * CFrame.Angles(side * 0.18, 0, 0)
			end
			-- Covered walkways out to the berths on either side
			for _, side in { -1, 1 } do
				for _, x in { tip + 40, tip + 110 } do
					part(terminal, "Walkway", Vector3.new(6, 6, (z1 - z0 - tw) / 2 - 4), Vector3.new(x, deck + 12, zm + side * ((z1 - z0) / 4 + tw / 4 - 2)), rgb(196, 198, 194), M.SmoothPlastic, false)
				end
			end
		else
			-- A transit shed behind a pair of cranes that work the slips either side
			local sheds = pieceModel(port, "JettyShed")
			CityBuildings.warehouse(sheds, CFrame.new(origin + Vector3.new((back + tip) / 2 + 12, deck, zm)), back - tip - 60, z1 - z0 - 18, 16 + index % 2 * 4, index + 2)
			dockCrane(tip + 14, z0 + 10, -30)
			dockCrane(tip + 30, z1 - 10, 30)
		end
	end
	-- Retained brick sheds on the back apron, with gaps where the slip heads need the quay
	local sheds = pieceModel(port, "DockSheds")
	local shedX = (back + docks.x1) / 2 + 2
	CityBuildings.warehouse(sheds, CFrame.new(origin + Vector3.new(shedX, deck, -690)) * CFrame.Angles(0, math.pi / 2, 0), 130, 30, 20, 1)
	CityBuildings.warehouse(sheds, CFrame.new(origin + Vector3.new(shedX, deck, -440)) * CFrame.Angles(0, math.pi / 2, 0), 150, 30, 18, 2)
	CityBuildings.warehouse(sheds, CFrame.new(origin + Vector3.new(shedX, deck, -235)) * CFrame.Angles(0, math.pi / 2, 0), 110, 30, 18, 3)

	---------------------------------------------------------------------------------------------
	-- Cruise branch: a wide basin where liners turn in off the estuary and berth along either
	-- side. The main terminal lines the north quay, a smaller hall on the south quay backs onto
	-- the city's northern street, and the car park fills the apron round the head.

	local basin = CityPort.CRUISE_BASIN
	local bz0, bz1 = basin.z0, basin.z1
	-- Aprons stop short of the mouth corners, where the natural bank wanders, and the north
	-- one stays clear of the open coast behind it
	local nx0, nx1, sx0, ex = basin.mouth + 40, basin.x1 + 30, basin.x0 + 25, basin.x1 + 100
	local northDepth, southDepth = 90, 56
	table.insert(reserved, { basin.mouth, ex, bz0 - northDepth - 10, bz1 + southDepth })
	part(port, "CruiseApron", Vector3.new(nx1 - nx0, 0.6, northDepth), Vector3.new((nx0 + nx1) / 2, top, bz0 - northDepth / 2), apron, M.Concrete)
	part(port, "CruiseApron", Vector3.new(ex - sx0, 0.6, southDepth), Vector3.new((sx0 + ex) / 2, top, bz1 + southDepth / 2), apron, M.Concrete)
	part(port, "CruiseApron", Vector3.new(ex - basin.x1, 0.6, bz1 - bz0), Vector3.new((basin.x1 + ex) / 2, top, (bz0 + bz1) / 2), apron, M.Concrete)
	quayEdge(nx0, bz0, basin.x1, bz0, 0, -1)
	quayEdge(basin.x1, bz0, basin.x1, bz1, 1, 0)
	quayEdge(sx0, bz1, basin.x1, bz1, 0, 1)

	-- A terminal hall a service road back from its berth, with boarding bridges on towers at
	-- the quay edge; `face` is the side the water is on (+1 south, -1 north)
	local function cruiseHall(x: number, z: number, length: number, depth: number, face: number, quayZ: number)
		local terminal = pieceModel(port, "CruiseTerminal", rgb(150, 156, 160))
		part(terminal, "TerminalHall", Vector3.new(length, 20, depth), Vector3.new(x, deck + 10, z), rgb(176, 178, 174), M.Concrete)
		part(terminal, "HallGlazing", Vector3.new(length - 10, 9, depth + 0.3), Vector3.new(x, deck + 11, z), rgb(58, 74, 84), M.Glass, false)
		for _, side in { -1, 1 } do
			local roof = part(terminal, "HallRoof", Vector3.new(length + 4, 1, depth / 2 + 3), Vector3.new(x, deck + 22, z + side * depth / 4), rgb(140, 146, 150), M.Metal)
			roof.CFrame = roof.CFrame * CFrame.Angles(side * 0.18, 0, 0)
		end
		local wall, tower = z + face * depth / 2, quayZ - face * 10
		for _, dx in { -length / 4, length / 4 } do
			part(terminal, "Walkway", Vector3.new(6, 6, math.abs(tower - wall)), Vector3.new(x + dx, deck + 12, (wall + tower) / 2), rgb(196, 198, 194), M.SmoothPlastic, false)
			part(terminal, "BoardingTower", Vector3.new(9, 15, 9), Vector3.new(x + dx, deck + 7.5, tower), rgb(196, 198, 194), M.SmoothPlastic)
			-- The bridge head reaches out past the quay wall to meet a liner's shell door
			part(terminal, "BridgeHead", Vector3.new(6, 6, 12), Vector3.new(x + dx, deck + 12, tower + face * 10), rgb(170, 172, 168), M.SmoothPlastic, false)
		end
	end
	local hallDepth = 40
	for _, x in { -305, -95, 115 } do
		cruiseHall(x, bz0 - 24 - hallDepth / 2, 170, hallDepth, 1, bz0)
	end
	cruiseHall(60, bz1 + 20 + 12, 200, 24, -1, bz1)

	-- Floodlights between and beside the north halls
	for _, x in { -200, 10, basin.x1 - 5 } do
		local mast = pieceModel(port, "FloodlightMast")
		keep(part(mast, "MastPole", Vector3.new(1.6, 80, 1.6), Vector3.new(x, deck + 40, bz0 - 44), rgb(150, 150, 146), M.Metal))
		part(mast, "MastLamps", Vector3.new(8, 3, 8), Vector3.new(x, deck + 81, bz0 - 44), rgb(70, 74, 76), M.Metal)
	end
	-- Passengers' cars on the apron round the head, two rows facing a centre aisle
	local carPark = pieceModel(port, "CruiseCarPark", rgb(80, 82, 82))
	local parkX0, parkX1 = basin.x1 + 18, ex - 8
	part(carPark, "CarPark", Vector3.new(parkX1 - parkX0, 0.3, bz1 - bz0 - 12), Vector3.new((parkX0 + parkX1) / 2, deck + 0.05, (bz0 + bz1) / 2), rgb(70, 72, 72), M.Asphalt, false)
	local spaces = 0
	for z = bz0 + 16, bz1 - 16, 9 do
		for _, x in { parkX0 + 10, parkX1 - 10 } do
			spaces += 1
			if (spaces * 7) % 5 == 0 then
				continue
			end
			local color = CONTAINERS[(spaces * 3) % #CONTAINERS + 1]:Lerp(white, 0.2)
			part(carPark, "ParkedCar", Vector3.new(13, 2.8, 6), Vector3.new(x, deck + 1.7, z), color, M.SmoothPlastic)
			part(carPark, "CarCabin", Vector3.new(7, 2.2, 5.4), Vector3.new(x, deck + 4.2, z), rgb(38, 44, 50), M.Glass, false)
		end
	end
	-- Coaches wait along the south quay for the next sailing's tours
	local coaches = pieceModel(port, "CruiseCoaches", rgb(196, 196, 186))
	for k, x in { -190, -150, -110, -70 } do
		local z = bz1 + 32
		part(coaches, "Coach", Vector3.new(34, 9, 8), Vector3.new(x, deck + 5, z), if k % 2 == 0 then white else rgb(52, 96, 128), M.SmoothPlastic)
		part(coaches, "CoachWindows", Vector3.new(28, 3, 8.3), Vector3.new(x - 1, deck + 6.5, z), rgb(38, 44, 50), M.Glass, false)
	end

	---------------------------------------------------------------------------------------------
	-- Marina pontoons at the head of the estuary, so arrivals by boat can come ashore

	local marina = pieceModel(port, "Marina")
	local pontoonTop = 1.4
	local walkZ = H - 22
	part(marina, "PontoonWalk", Vector3.new(310, 1.4, 8), Vector3.new(-420, pontoonTop - 0.7, walkZ), rgb(150, 140, 120), M.WoodPlanks)
	for index, x in { -550, -495, -440, -385, -330, -275 } do
		part(marina, "PontoonFinger", Vector3.new(7, 1.4, 110), Vector3.new(x, pontoonTop - 0.7, walkZ - 59), rgb(150, 140, 120), M.WoodPlanks)
		part(marina, "PontoonFloat", Vector3.new(7.4, 1, 110), Vector3.new(x, -0.2, walkZ - 59), rgb(70, 74, 76), M.Plastic, false)
		cylinder(marina, "MarinaPile", 2.2, 14, Vector3.new(x + 4.6, 3, walkZ - 112), rgb(84, 86, 84), M.Metal)
		-- A couple of small craft tied up at each finger
		for k, dz in { -35, -85 } do
			local side = if (index + k) % 2 == 0 then 1 else -1
			local hullColor = CONTAINERS[(index * 2 + k) % #CONTAINERS + 1]:Lerp(white, 0.5)
			local bx, bz = x + side * 9, walkZ + dz
			part(marina, "MooredBoat", Vector3.new(8, 3.5, 24), Vector3.new(bx, 0.8, bz), hullColor, M.SmoothPlastic)
			part(marina, "BoatDeck", Vector3.new(7.4, 0.2, 23), Vector3.new(bx, 2.65, bz), white, M.SmoothPlastic, false)
			part(marina, "MooredCabin", Vector3.new(5.5, 3, 8), Vector3.new(bx, 4, bz + 3), white, M.SmoothPlastic, false)
			part(marina, "CabinRoof", Vector3.new(6, 0.35, 8.6), Vector3.new(bx, 5.65, bz + 3), white, M.SmoothPlastic, false)
			local windowColor = rgb(50, 75, 86)
			for _, s in { -1, 1 } do
				part(marina, "CabinWindow", Vector3.new(0.12, 1.5, 5.8), Vector3.new(bx + s * 2.78, 4.25, bz + 3), windowColor, M.Glass, false)
				part(marina, "HullStripe", Vector3.new(0.12, 0.4, 22), Vector3.new(bx + s * 4.03, 1.7, bz), white, M.SmoothPlastic, false)
				strut(marina, "BowRail", Vector3.new(bx + s * 3.3, 3.6, bz - 10), Vector3.new(bx + s * 3.3, 3.6, bz - 4), 0.22, white, M.Metal, false)
			end
			part(marina, "CabinWindshield", Vector3.new(4.5, 1.5, 0.12), Vector3.new(bx, 4.25, bz - 1.03), windowColor, M.Glass, false)
			part(marina, "BowHatch", Vector3.new(2.4, 0.2, 2.6), Vector3.new(bx, 2.85, bz - 7), windowColor, M.SmoothPlastic, false)
			strut(marina, "MooringLine", Vector3.new(bx - side * 3.8, 2.6, bz + 8), Vector3.new(x + side * 3.5, pontoonTop + 0.1, bz + 10), 0.18, rgb(188, 180, 158), M.Fabric, false)
		end
	end
	for _, x in { -400, -310 } do
		-- Gangways climb from the pontoon walk to the quay at a walkable slope
		local ramp = strut(marina, "Gangway", Vector3.new(x, pontoonTop, walkZ - 2), Vector3.new(x, deck, H + 3), 1, rgb(120, 122, 120), M.DiamondPlate)
		ramp.Size = Vector3.new(6, 0.8, ramp.Size.Z)
		for _, side in { -3, 3 } do
			strut(marina, "GangwayRail", Vector3.new(x + side, pontoonTop + 3, walkZ - 2), Vector3.new(x + side, deck + 3, H + 3), 0.3, rgb(170, 172, 168), M.Metal, false)
		end
	end
	part(port, "HeadQuayApron", Vector3.new(CityPort.DOCKS.x1 - W, 0.6, 12), Vector3.new((W + CityPort.DOCKS.x1) / 2, top, H + 6), apron, M.Concrete)

	---------------------------------------------------------------------------------------------
	-- Lateral buoys mark the channel: red to port and green to starboard heading in

	local channel = CityPort.CHANNEL
	-- Where the channel bends past the terminal, a buoy would land on the yard
	local function onLand(x: number, z: number): boolean
		for _, r in reserved do
			if x > r[1] and x < r[2] and z > r[3] and z < r[4] then
				return true
			end
		end
		return false
	end
	-- Only the outer reach is buoyed: further in the quays show the way, and the inner buoys
	-- would sit right off the cruise berths
	for i = 1, #channel - 4 do
		local a, b = channel[i], channel[i + 1]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local length = math.sqrt(dx * dx + dz * dz)
		local nx, nz = -dz / length, dx / length
		for _, side in { -1, 1 } do
			local buoy = pieceModel(port, "ChannelBuoy")
			local position = Vector3.new(a[1] + nx * side * 150, 0, a[2] + nz * side * 150)
			if onLand(position.X, position.Z) then
				continue
			end
			local color = if side < 0 then rgb(176, 46, 40) else rgb(40, 120, 70)
			cylinder(buoy, "BuoyBody", 5, 6, position + Vector3.new(0, 1.5, 0), color, M.SmoothPlastic)
			part(buoy, "BuoyMast", Vector3.new(1.2, 7, 1.2), position + Vector3.new(0, 8, 0), color, M.SmoothPlastic, false)
			part(buoy, "BuoyTopmark", Vector3.new(3, 3, 3), position + Vector3.new(0, 12.5, 0), color, M.SmoothPlastic, false)
		end
	end

	return reserved
end

return CityPort
