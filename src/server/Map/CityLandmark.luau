-- Walk-in parliament on Civic Square: a domed chamber between two three-storey wings, behind
-- the curved colonnade of the Great Hall. This builds only what every player needs: the shell,
-- floors, stairs, collision and real Seats (Shared.ParliamentLayout holds the plan). Ornament,
-- furniture and the people inside are local (client/Parliament), so the Performance setting
-- can swap them for plain blocks.
--
-- No two parts share a visible face: slabs run between walls, partitions stand between slabs,
-- and every other segment of a ring is lifted by Layout.RING_LIFT (scripts/check-parliament
-- looks for coplanar faces).
local Layout = require(game:GetService("ReplicatedStorage").Shared.ParliamentLayout)
local Landmark = {}
local V, F, A, rgb, M = Vector3.new, CFrame.new, CFrame.Angles, Color3.fromRGB, Enum.Material
local rad = math.rad
-- Light stone outside; warm stone, dark marble and wood inside.
local STONE, CORNICE, PIER = rgb(214, 207, 190), rgb(226, 220, 204), rgb(222, 215, 198)
local WALL, FLOOR, SLAB = rgb(150, 136, 116), rgb(92, 82, 72), rgb(118, 106, 92)
local GLASS, DARK, WOOD = rgb(70, 96, 108), rgb(37, 49, 55), rgb(96, 66, 42)
local BLUE, GOLD, CARPET = rgb(29, 79, 132), rgb(196, 160, 84), rgb(38, 64, 104)
local RED = rgb(118, 34, 38)
-- The ground floor stands this far above the square, so it never shares the paving's surface.
Landmark.PLINTH = 0.6

function Landmark.build(parent: Instance, base: CFrame): Model
	local hall = Instance.new("Model")
	hall.Name = "CityParliament"
	hall:SetAttribute(Layout.FrameAttribute, base)
	hall:SetAttribute("LodColor", rgb(200, 196, 184))
	local function group(name)
		local model = Instance.new("Model")
		model.Name, model.Parent = name, hall
		model:AddTag("LodPiece")
		return model
	end
	local function part(folder, name, size, frame, color, material, solid)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame = name, size, base * frame
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, solid == true, false, solid == true
		p.Color, p.Material = color, material or M.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.CastShadow, p.Parent = solid == true, folder
		return p
	end
	-- A block given by its extents.
	local function slab(folder, name, x0, x1, y0, y1, z0, z1, color, material, solid)
		local lx, hx = math.min(x0, x1), math.max(x0, x1)
		return part(folder, name, V(hx - lx, y1 - y0, z1 - z0), F((lx + hx) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, material, solid)
	end
	local function glaze(p, transparency)
		p.Transparency, p.Reflectance, p.CastShadow = transparency or 0.45, 0.06, false
		return p
	end
	-- `count` tangent segments of a ring between two radii, every other one lifted.
	local function ring(folder, name, from, to, count, inner, outer, y0, y1, color, material, solid)
		local step = (to - from) / count
		local parts = {}
		for index = 1, count do
			local angle = from + (index - 0.5) * step
			local lift = if index % 2 == 0 then Layout.RING_LIFT else 0
			local width = 2 * outer * math.tan(rad(math.abs(step) / 2)) + 0.05
			local p = part(folder, name, V(width, y1 - y0, outer - inner),
				Layout.facing(angle, (inner + outer) / 2, (y0 + y1) / 2 + lift), color, material, solid)
			table.insert(parts, p)
		end
		return parts
	end
	local function sign(folder, text, frame, width, height, color)
		local board = part(folder, "ParliamentSign", V(width, height, 0.15), frame, color or DARK)
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.SizingMode, gui.PixelsPerStud = Enum.NormalId.Back, Enum.SurfaceGuiSizingMode.PixelsPerStud, 30
		gui.MaxDistance, gui.LightInfluence = 260, 0.4
		local label = Instance.new("TextLabel")
		label.Size, label.Position, label.BackgroundTransparency = UDim2.fromScale(0.96, 0.84), UDim2.fromScale(0.02, 0.08), 1
		label.Font, label.TextColor3, label.TextScaled, label.TextWrapped = Enum.Font.Garamond, rgb(70, 58, 40), true, true
		label.Text, label.Parent, gui.Parent = text, gui, board
		return board
	end
	local function prompt(holder, tag, action, object, distance)
		local p = Instance.new("ProximityPrompt")
		p.ActionText, p.ObjectText, p.MaxActivationDistance = action, object, distance
		p.RequiresLineOfSight, p.HoldDuration, p.Parent = false, 0.4, holder
		holder:AddTag(tag)
	end

	local W, N, S = Layout.HalfWidth, Layout.North, Layout.WingFront
	local inN, inS, outer = Layout.InnerNorth, Layout.InnerFront, Layout.OuterFace
	local wingIn, wall = Layout.InnerFace, Layout.Wall
	local storey, roof, fz = Layout.Storey, Layout.Roof, Layout.Focus.Z
	local plinth = Landmark.PLINTH

	-------------------------------------------------------------------------------------------
	-- Ground, floors and roofs
	local shell = group("ParliamentStructure")
	slab(shell, "Foundation", -W, W, -1 - plinth, 0, N, S, FLOOR, M.Marble, true)
	-- The portico floor follows the colonnade, in strips that never overlap.
	local porch = Layout.ColumnRadius + 4.5
	local x = 0
	while x < 66 do
		local nextX = math.min(x + 8, 66)
		local front = fz + math.sqrt(porch * porch - x * x)
		for _, sx in { -1, 1 } do
			slab(shell, "PorticoFloor", sx * x, sx * nextX, -1 - plinth, 0, S, front, FLOOR, M.Marble, true)
		end
		x = nextX
	end
	for _, side in { -1, 1 } do
		for floor = 1, 2 do
			local y = floor * storey
			local north = if Layout.senateFloor(side, floor) and floor == 2 then Layout.Senate.Gallery else inN
			slab(shell, "WingFloor", side * wingIn, side * outer, y - 1, y, north, Layout.StairZ + wall / 2, SLAB, M.Marble, true)
			slab(shell, "StairHallFloor", side * wingIn, side * Layout.Stair.Spine[2], y - 1, y, Layout.StairZ + wall / 2, inS, SLAB, M.Marble, true)
			slab(shell, "StairTopFloor", side * Layout.Stair.Spine[2], side * outer, y - 1, y, Layout.StairZ + wall / 2, Layout.Stair.Low, SLAB, M.Marble, true)
		end
		slab(shell, "WingRoof", side * wingIn, side * outer, roof, roof + 1.5, inN, inS, rgb(176, 170, 156), M.Concrete, true)
		local tribune = slab(shell, "TribuneBridge", side * 63, side * (Layout.WingInner - wall / 2), storey - 1, storey, Layout.SideDoorZ - 4.5, Layout.SideDoorZ + 7.5, SLAB, M.Marble, true)
		tribune.Name = "TribuneBridge"
	end
	for floor = 1, 2 do
		local y = floor * storey
		slab(shell, "RearGalleryFloor", -(Layout.WingInner - wall / 2), Layout.WingInner - wall / 2, y - 1, y, inN, Layout.RearZ, SLAB, M.Marble, true)
		glaze(slab(shell, "RearBalustrade", -(Layout.WingInner - wall / 2), Layout.WingInner - wall / 2, y, y + 3.5, Layout.RearZ - 0.3, Layout.RearZ, GLASS, M.Glass, true), 0.6)
	end
	-- The roof between the wings: strips that stop at the chamber's wall and the hall's glass.
	-- North of the chamber the strips are glass, lighting the palm courts.
	local roofs = group("ParliamentRoof")
	slab(roofs, "RearRoof", -wingIn, wingIn, roof, roof + 1.5, inN, Layout.RearZ, rgb(176, 170, 156), M.Concrete, true)
	local drum, glassRoof = Layout.DrumOuter, Layout.HallRadius
	local edges, at = { 0 }, 0
	while at < drum do
		at = math.min(math.sqrt(at * at + 240), at + 12, drum)
		table.insert(edges, at)
	end
	table.insert(edges, (drum + wingIn) / 2)
	table.insert(edges, wingIn)
	for index = 1, #edges - 1 do
		local xa, xb = edges[index], edges[index + 1]
		local c = if xb < drum then math.sqrt(drum * drum - xb * xb) else 0
		local front = fz + math.sqrt(glassRoof * glassRoof - xa * xa)
		for _, sx in { -1, 1 } do
			local north = slab(roofs, "CourtRoof", sx * xa, sx * xb, roof, roof + 1.5, Layout.RearZ, fz - c, rgb(176, 170, 156), M.Concrete, true)
			if xa >= 36 then
				north.Name, north.Color, north.Material = "CourtSkylight", GLASS, M.Glass
				glaze(north, 0.5)
			end
			slab(roofs, "HallRoof", sx * xa, sx * xb, roof, roof + 1.5, fz + c, front, rgb(176, 170, 156), M.Concrete, true)
		end
	end

	-- Outer walls: stone bands at the floors, tall windows between them, piers in front.
	local outerWalls = group("ParliamentOuterWalls")
	local BANDS = { { 0, 3 }, { 15, 21 }, { 33, 39 }, { 51, 58 } }
	local WINDOWS = { { 3, 15 }, { 21, 33 }, { 39, 51 } }
	local function facade(folder, x0, x1, z0, z1)
		for _, band in BANDS do
			slab(folder, "StoneBand", x0, x1, band[1], band[2], z0, z1, STONE, M.Limestone, true)
		end
		for _, window in WINDOWS do
			glaze(slab(folder, "WindowGlass", x0, x1, window[1], window[2], z0, z1, GLASS, M.Glass, true))
		end
	end
	local piers = group("ParliamentPiers")
	for _, side in { -1, 1 } do
		facade(outerWalls, side * outer, side * W, N, S)
		facade(outerWalls, side * (Layout.WingInner - wall / 2), side * outer, inS, S)
		for z = N + 6, S - 2, 12 do
			slab(piers, "FacadePier", side * W, side * (W + 1.4), -plinth, 58.5, z - 2, z + 2, PIER, M.Limestone)
		end
		for _, px in { 76, 88, 100 } do
			slab(piers, "FacadePier", side * (px - 2), side * (px + 2), -plinth, 58.5, S, S + 1.4, PIER, M.Limestone)
		end
		slab(piers, "Cornice", side * outer, side * (W + 2.4), 58, 59.6, N - 2.4, S + 2.4, CORNICE, M.Limestone)
		slab(piers, "Cornice", side * (Layout.WingInner - wall / 2), side * outer, 58, 59.6, inS, S + 2.4, CORNICE, M.Limestone)
	end
	facade(outerWalls, -outer, outer, N, inN)
	for px = -102, 102, 12 do
		slab(piers, "FacadePier", px - 2, px + 2, -plinth, 58.5, N - 1.4, N, PIER, M.Limestone)
	end
	slab(piers, "Cornice", -outer, outer, 58, 59.6, N - 2.4, inN, CORNICE, M.Limestone)

	-------------------------------------------------------------------------------------------
	-- The Great Hall's curved front: glass behind fourteen columns, open at the middle.
	local portico = group("ParliamentPortico")
	local segments = 15
	local step = 2 * Layout.HallSpan / segments
	for index = 1, segments do
		local angle = -Layout.HallSpan + (index - 0.5) * step
		local chord = 2 * Layout.HallRadius * math.sin(rad(step / 2)) + 0.1
		local entrance = math.abs(angle) < step * 1.6
		local bottom = if entrance then 16 else 0
		glaze(part(portico, if entrance then "EntranceUpperGlass" else "HallGlass", V(chord, roof - bottom, 0.5),
			Layout.facing(angle, Layout.HallRadius, (roof + bottom) / 2), GLASS, M.Glass, true), 0.5)
	end
	-- Starts just inside the roof strips, so its underside never meets theirs.
	ring(portico, "Entablature", -Layout.HallSpan - 2, Layout.HallSpan + 2, segments, Layout.HallRadius - 2, Layout.ColumnRadius + 3, roof + 0.2, roof + 4.7, CORNICE, M.Limestone, true)
	local columns = 14
	local columnSpan = math.deg(math.asin(66 / Layout.ColumnRadius))
	for index = 0, columns - 1 do
		local angle = -columnSpan + index * 2 * columnSpan / (columns - 1)
		local column = part(portico, "PorticoColumn", V(roof, 3.2, 3.2), Layout.facing(angle, Layout.ColumnRadius, roof / 2) * A(0, 0, math.pi / 2), PIER, M.Marble, true)
		column.Shape = Enum.PartType.Cylinder
	end
	part(portico, "EntranceCanopy", V(30, 0.8, 8), F(0, 16.4, Layout.Front + 4.2), DARK, M.Metal, true)
	sign(portico, "PARLIAMENT", F(0, roof + 2.45, fz + Layout.ColumnRadius + 3.1), 40, 3.2, CORNICE)

	-------------------------------------------------------------------------------------------
	-- The chamber's drum and its dome
	local drumWalls = group("ParliamentDrum")
	local wallRadius, tangent = (Layout.DrumRadius + Layout.DrumOuter) / 2, math.tan(rad(7.5))
	local width = 2 * Layout.DrumOuter * tangent + 0.05
	local thick = Layout.DrumOuter - Layout.DrumRadius
	local top = Layout.Ceiling + 1
	local function drumPanel(angle, y0, y1, offset, size, name, color, material)
		return part(drumWalls, name or "DrumWall", V(size or width, y1 - y0, thick),
			Layout.facing(angle, wallRadius, (y0 + y1) / 2) * F(offset or 0, 0, 0), color or WALL, material or M.Limestone, true)
	end
	-- Public doors from the hall, the members' doors from both wings (with the gallery doors
	-- above them) and the Speaker's door at the back.
	local DOOR = Layout.Door
	local doors = { [30] = { 13 }, [-30] = { 13 }, [180] = { Layout.DoorHeight }, [90] = { Layout.DoorHeight, storey + Layout.DoorHeight }, [-90] = { Layout.DoorHeight, storey + Layout.DoorHeight } }
	for index = 0, 23 do
		local angle = if index > 12 then index * 15 - 360 else index * 15
		local opening = doors[angle]
		if opening then
			local jamb = (width - DOOR) / 2
			for _, side in { -1, 1 } do
				drumPanel(angle, 0, top, side * (DOOR / 2 + jamb / 2), jamb + 0.02)
			end
			if opening[2] then
				drumPanel(angle, opening[1], storey, 0, DOOR)
				drumPanel(angle, opening[2], top, 0, DOOR)
			else
				drumPanel(angle, opening[1], top, 0, DOOR)
			end
		else
			drumPanel(angle, 0, top, 0)
		end
		glaze(drumPanel(angle, top, Layout.ClerestoryTop, 0, nil, "ClerestoryGlass", GLASS, M.Glass), 0.5)
	end
	ring(drumWalls, "DrumRing", 0, 360, 24, Layout.DrumRadius - 0.6, Layout.DrumOuter + 0.6, Layout.ClerestoryTop, Layout.DrumTop, STONE, M.Limestone, true)
	local ceiling = group("ChamberCeiling")
	for _, band in { { Layout.Oculus, 28 }, { 28, 46 }, { 46, Layout.DrumRadius } } do
		ring(ceiling, "ChamberCeiling", 0, 360, 24, band[1], band[2], Layout.Ceiling, Layout.Ceiling + 1, rgb(84, 62, 44), M.Wood, true)
	end
	local dome = group("ParliamentDome")
	local domeRadius, domeRise = Layout.DomeRadius, Layout.DomeRise
	local latitudes = { 0, 20, 40, 60, 78 }
	for band = 1, #latitudes - 1 do
		local a0, a1 = rad(latitudes[band]), rad(latitudes[band + 1])
		local r0, y0 = domeRadius * math.cos(a0), domeRise * math.sin(a0)
		local r1, y1 = domeRadius * math.cos(a1), domeRise * math.sin(a1)
		local length = math.sqrt((r1 - r0) ^ 2 + (y1 - y0) ^ 2) + 0.35
		local tilt = math.atan2(r1 - r0, y1 - y0)
		local across = 2 * (r0 * 0.62 + r1 * 0.38) * tangent + 0.25
		for index = 0, 23 do
			local lift = if index % 2 == 0 then 0 else 0.12
			local pane = part(dome, "DomeGlass", V(across, length, 0.3),
				Layout.facing(index * 15, (r0 + r1) / 2 + lift, Layout.DrumTop + (y0 + y1) / 2) * A(tilt, 0, 0), rgb(150, 190, 196), M.Glass)
			pane.Transparency, pane.Reflectance = 0.45, 0.2
		end
	end
	local crown = rad(latitudes[#latitudes])
	local capY = Layout.DrumTop + domeRise * math.sin(crown)
	local function turned(name, diameter, height, y, color, material)
		local p = part(dome, name, V(height, diameter, diameter), F(0, y, fz) * A(0, 0, math.pi / 2), color, material)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	turned("DomeOculusRing", 2 * domeRadius * math.cos(crown) + 1.4, 1, capY, STONE, M.Metal)
	local lantern = turned("DomeLantern", 9, 7, capY + 4, rgb(255, 228, 180), M.Glass)
	lantern.Transparency = 0.2
	turned("DomeLanternCap", 11, 1, capY + 8, GOLD, M.Metal)
	turned("DomeSpire", 0.7, 16, capY + 16.5, GOLD, M.Metal)
	local glow = Instance.new("PointLight")
	glow.Range, glow.Brightness, glow.Color, glow.Shadows, glow.Parent = 50, 1, rgb(255, 222, 170), false, lantern
	for stripe, tint in { rgb(174, 42, 49), rgb(236, 234, 224), BLUE } do
		part(dome, "DutchFlagStripe", V(7, 1.4, 0.1), F(3.8, capY + 23.5 - (stripe - 1) * 1.4, fz), tint, M.Fabric)
	end

	-------------------------------------------------------------------------------------------
	-- Partitions. Inner and outer walls run full height; everything else stands between slabs.
	local function innerOpenings(side, floor)
		local list = { { Layout.HallOpening[1], Layout.HallOpening[2], if floor == 0 then 16 else storey - 2 } }
		if floor < 2 then
			table.insert(list, { Layout.SideDoorZ - DOOR / 2, Layout.SideDoorZ + DOOR / 2, Layout.DoorHeight })
		end
		if not Layout.senateFloor(side, floor) then
			table.insert(list, { Layout.RearDoorZ - DOOR / 2, Layout.RearDoorZ + DOOR / 2, Layout.DoorHeight })
		elseif floor == 1 then
			local z = Layout.Senate.Dais[2] + 1.7
			table.insert(list, { z - DOOR / 2, z + DOOR / 2, Layout.DoorHeight })
		end
		table.sort(list, function(a, b)
			return a[1] < b[1]
		end)
		return list
	end
	local function wingWalls(side)
		local walls = group(if side > 0 then "ParliamentEastWalls" else "ParliamentWestWalls")
		local lower = group(if side > 0 then "ParliamentEastRooms" else "ParliamentWestRooms")
		local innerX = side * Layout.WingInner
		local function alongZ(folder, name, xc, half, z0, z1, y0, y1, color)
			if z1 - z0 > 0.01 then
				slab(folder, name, xc - half, xc + half, y0, y1, z0, z1, color or WALL, M.SmoothPlastic, true)
			end
		end
		for floor = 0, 2 do
			local y = floor * storey
			local from = inN
			for _, opening in innerOpenings(side, floor) do
				alongZ(walls, "InnerWall", innerX, wall / 2, from, opening[1], y, y + storey)
				alongZ(walls, "InnerWallLintel", innerX, wall / 2, opening[1], opening[2], y + opening[3], y + storey)
				from = opening[2]
			end
			alongZ(walls, "InnerWall", innerX, wall / 2, from, inS, y, y + storey)
			if floor > 0 then
				glaze(slab(walls, "HallBalustrade", innerX - 0.15, innerX + 0.15, y, y + 3.5, Layout.HallOpening[1], Layout.HallOpening[2], GLASS, M.Glass, true), 0.6)
			end
			-- Corridor wall, room dividers and the stair hall's back wall.
			local senate = Layout.senateFloor(side, floor)
			local north = if senate then Layout.Senate.Z1 + 0.5 else inN
			local gaps = {}
			for _, room in Layout.Rooms do
				if room.Side == side and room.Floor == floor and room.Doors then
					for _, z in room.Doors do
						table.insert(gaps, z)
					end
					if room.Z1 < Layout.StairZ then
						slab(lower, "RoomDivider", side * (Layout.RoomWall + 0.5), side * outer, y, y + storey - 1, room.Z1 - 0.4, room.Z1 + 0.4, WALL, M.SmoothPlastic, true)
					end
				end
			end
			table.sort(gaps)
			local stairWall = Layout.StairZ - wall / 2
			local at = north
			for _, z in gaps do
				alongZ(lower, "CorridorWall", side * Layout.RoomWall, 0.5, at, z - DOOR / 2, y, y + Layout.DoorHeight)
				at = z + DOOR / 2
			end
			alongZ(lower, "CorridorWall", side * Layout.RoomWall, 0.5, at, stairWall, y, y + Layout.DoorHeight)
			alongZ(lower, "CorridorWallHead", side * Layout.RoomWall, 0.5, north, stairWall, y + Layout.DoorHeight, y + storey - 1)
			slab(lower, "StairHallWall", side * (Layout.RoomWall - 0.5), side * outer, y, y + storey - 1, stairWall, Layout.StairZ + wall / 2, WALL, M.SmoothPlastic, true)
		end
		return walls
	end
	wingWalls(1)
	local west = wingWalls(-1)
	do
		-- The Senate's south wall (door from the corridor, gallery door above), its tiers,
		-- benches' collision, the President's dais and the public gallery.
		local s = Layout.Senate
		local senate = group("SenateStructure")
		local z0, z1 = s.Z1 - 0.5, s.Z1 + 0.5
		local doorA, doorB = -(Layout.CorridorX + DOOR / 2), -(Layout.CorridorX - DOOR / 2)
		slab(west, "SenateSouthWall", -outer, doorA, s.Y, roof, z0, z1, WALL, M.SmoothPlastic, true)
		slab(west, "SenateSouthWall", doorB, -wingIn, s.Y, roof, z0, z1, WALL, M.SmoothPlastic, true)
		slab(west, "SenateSouthWall", doorA, doorB, s.Y + Layout.DoorHeight, 2 * storey - 1, z0, z1, WALL, M.SmoothPlastic, true)
		slab(west, "SenateSouthWall", doorA, doorB, 2 * storey + Layout.DoorHeight, roof, z0, z1, WALL, M.SmoothPlastic, true)
		glaze(slab(senate, "SenateGalleryRail", -outer, -wingIn, 2 * storey, 2 * storey + 3.5, s.Gallery - 0.3, s.Gallery, GLASS, M.Glass, true), 0.6)
		local last = s.FirstZ + 12 * s.Spacing
		for _, side in { -1, 1 } do
			for row = 2, 3 do
				local a = s.Offsets[row] - 2
				local b = if row == 3 then s.Offsets[3] + 2 else s.Offsets[row + 1] - 2
				slab(senate, "SenateTier", s.X + side * a, s.X + side * b, s.Y, s.Y + (row - 1) * s.RowRise, s.FirstZ - 2, last + 2, RED, M.Carpet, true)
			end
			for row, offset in s.Offsets do
				local bx = s.X + side * (offset - 1.85)
				local bench = slab(senate, "SenateBenchCollision", bx - 0.45, bx + 0.45, s.Y + (row - 1) * s.RowRise + 2.6, s.Y + (row - 1) * s.RowRise + 2.9,
					s.FirstZ - 1.7, s.FirstZ + (s.Counts[side][row] - 1) * s.Spacing + 1.7, DARK, M.SmoothPlastic, true)
				bench.Transparency, bench.CastShadow = 1, false
			end
		end
		local dais = s.Dais
		slab(senate, "SenateDais", s.X - dais[3], s.X + dais[3], s.Y, s.Y + dais[4], dais[1], dais[2], WOOD, M.WoodPlanks, true)
		slab(senate, "SenateDaisStep", s.X + dais[3], s.X + dais[3] + 2.5, s.Y, s.Y + dais[4] / 2, dais[1] + 1, dais[2] - 1, WOOD, M.WoodPlanks, true)
	end

	-- Switchback stairs: walkable ramps (the treads are drawn locally on top).
	local stairs = group("ParliamentStairs")
	local st = Layout.Stair
	local rise, run = storey / 2, st.High - st.Low
	local pitch, length = math.atan2(rise, run), math.sqrt(run * run + rise * rise)
	local sink = 0.5 / math.cos(pitch)
	for _, side in { -1, 1 } do
		for level = 0, 1 do
			local y = level * storey
			local mid = (st.Low + st.High) / 2
			part(stairs, "StairRamp", V(st.Width, 1, length), F(side * st.A, y + rise / 2 - sink, mid) * A(-pitch, 0, 0), SLAB, M.Marble, true)
			part(stairs, "StairRamp", V(st.Width, 1, length), F(side * st.B, y + rise + rise / 2 - sink, mid) * A(pitch, 0, 0), SLAB, M.Marble, true)
			slab(stairs, "StairLanding", side * (Layout.RoomWall + 1), side * outer, y + rise - 1, y + rise, st.High, inS, SLAB, M.Marble, true)
		end
		slab(stairs, "StairSpine", side * st.Spine[1], side * st.Spine[2], 0, 2 * storey + 4, st.Low, st.High, WALL, M.SmoothPlastic, true)
		for floor = 1, 2 do
			glaze(slab(stairs, "StairRail", side * st.Spine[2], side * (st.Spine[2] + 0.3), floor * storey, floor * storey + 3.5, st.High, inS, GLASS, M.Glass, true), 0.6)
		end
		glaze(slab(stairs, "StairRail", side * st.Spine[2], side * outer, 2 * storey, 2 * storey + 3.5, st.Low, st.Low + 0.3, GLASS, M.Glass, true), 0.6)
	end

	-------------------------------------------------------------------------------------------
	-- House of Representatives
	local lowerTiers, upperTiers = group("PlenaryLowerTiers"), group("PlenaryUpperTiers")
	for _, tier in Layout.Tiers do
		part(if tier.Row <= 3 then lowerTiers else upperTiers, "CarpetedTier", tier.Size, tier.Frame, CARPET, M.Carpet, true)
	end
	local chamber = group("PlenaryFloor")
	local topRise = Layout.rowRise(#Layout.Rows)
	for _, degrees in Layout.Aisles do
		-- From the public door up to the back row, without a jump.
		local outerR, innerR = 59, Layout.rowRadius(#Layout.Rows) + Layout.RowPitch / 2
		local runR = outerR - innerR
		local tilt = math.atan2(topRise, runR)
		local rampLength = math.sqrt(runR * runR + topRise * topRise)
		part(chamber, "ParliamentAisleRamp", V(7, 0.6, rampLength), Layout.facing(degrees, (outerR + innerR) / 2, topRise / 2 - 0.3 / math.cos(tilt)) * A(tilt, 0, 0), CARPET, M.Carpet, true)
	end
	local dais = Layout.Dais
	slab(chamber, "SpeakerDais", -dais.X, dais.X, 0, dais.Height, dais.Z0, dais.Z1, WOOD, M.WoodPlanks, true)
	for _, sx in { -1, 1 } do
		slab(chamber, "SpeakerDaisStep", sx * dais.X, sx * (dais.X + 3), 0, dais.Height / 2, dais.Z0 + 4, dais.Z1 - 4, WOOD, M.WoodPlanks, true)
	end
	ring(chamber, "VakKRiser", Layout.VakK.From, Layout.VakK.To, 4, Layout.VakK.Radii[2] - 3.4, Layout.VakK.Radii[2] + 2.6, 0, Layout.VakK.RowRise, CARPET, M.Carpet, true)
	local bell = part(chamber, "DivisionBell", V(0.6, 1.1, 1.1), Layout.Bell * A(0, 0, math.pi / 2), GOLD, M.Metal)
	bell.Shape = Enum.PartType.Cylinder
	prompt(bell, Layout.BellTag, "Ring the division bell", "Division bell", 10)
	local tribune = group("PlenaryTribune")
	local ringSpec = Layout.Tribune
	local spans = (ringSpec.To - ringSpec.From) / 15
	ring(tribune, "TribuneFloor", ringSpec.From, ringSpec.To, spans, ringSpec.Inner, Layout.DrumRadius + 0.5, ringSpec.Y - 1, ringSpec.Y, SLAB, M.Marble, true)
	for _, p in ring(tribune, "TribuneBalustrade", ringSpec.From, ringSpec.To, spans, ringSpec.Inner, ringSpec.Inner + 0.3, ringSpec.Y, ringSpec.Y + 3.5, GLASS, M.Glass, true) do
		glaze(p, 0.6)
	end
	for _, degrees in { ringSpec.From, ringSpec.To } do
		local cap = part(tribune, "TribuneBalustrade", V(0.3, 3.5, Layout.DrumRadius - ringSpec.Inner), Layout.facing(degrees, (Layout.DrumRadius + ringSpec.Inner) / 2, ringSpec.Y + 1.75), GLASS, M.Glass, true)
		glaze(cap, 0.6)
	end

	-- Transparent server Seats preserve sitting/occupancy for all players.
	local seatGroups = {
		Plenary = { group("PlenarySeats"), group("PlenarySeatsOuter") },
		Tribune = { group("TribuneSeats") },
		Senate = { group("SenateSeats") },
		Council = { group("CouncilSeats") },
	}
	local desks = { group("PlenaryDeskCollision"), group("PlenaryDeskCollisionOuter") }
	for _, entry in Layout.Seats do
		local outerRows = entry.Role == "Member" and entry.Row > 4
		local seat = Instance.new("Seat")
		seat.Name, seat.Size = entry.Id, V(if entry.Special then 2.8 else 2.15, 0.45, 2.1)
		seat.CFrame = base * entry.Frame * F(0, 1.65, 0)
		seat.Anchored, seat.Transparency, seat.CastShadow = true, 1, false
		seat.CanCollide, seat.CanTouch, seat.CanQuery = true, true, false
		seat:SetAttribute("ParliamentRoom", entry.Room)
		seat:SetAttribute("SeatRole", entry.Role)
		seat:SetAttribute("SpecialSeat", entry.Special == true)
		seat.Parent = seatGroups[entry.Room][if outerRows then 2 else 1]
		if entry.Role == "Member" or entry.Role == "Minister" then
			local collider = part(desks[if outerRows then 2 else 1], "DeskCollision", V(2.35, 0.22, 1.3), entry.Frame * F(0, 2.85, -2.15), DARK, M.SmoothPlastic, true)
			collider.Transparency, collider.CastShadow = 1, false
		end
	end
	do
		local council, c = seatGroups.Council[1], Layout.Council
		local tableTop = part(council, "CouncilTableCollision", V(c.Length, 0.3, c.Width), F(c.Table + V(0, 2.85, 0)), WOOD, M.Wood, true)
		tableTop.Transparency, tableTop.CastShadow = 1, false
		slab(council, "ChairpersonDais", c.Head - 2.2, c.Head + 2.2, storey, storey + 0.55, c.Table.Z - 3, c.Table.Z + 3, WOOD, M.WoodPlanks, true)
	end

	-------------------------------------------------------------------------------------------
	-- The few things players touch in the hall, and the voting booths.
	local lobby = group("PublicEntranceHall")
	part(lobby, "ReceptionDesk", V(13, 3.2, 3), Layout.Reception * F(0, 1.6, 0), WOOD, M.Wood, true)
	for _, sx in { -1, 1 } do
		slab(lobby, "SecurityPortalPost", sx * 11.6, sx * 12.4, 0, 9, 72.5, 73.5, DARK, M.Metal, true)
	end
	slab(lobby, "SecurityPortalHeader", -12.4, 12.4, 9, 9.8, 72.5, 73.5, DARK, M.Metal, true)
	local hc = Layout.HallColumns
	for _, degrees in hc.Angles do
		local column = part(lobby, "HallColumn", V(roof, hc.Diameter, hc.Diameter), Layout.facing(degrees, hc.Radius, roof / 2) * A(0, 0, math.pi / 2), rgb(178, 164, 140), M.Marble, true)
		column.Shape = Enum.PartType.Cylinder
	end
	local voting = Layout.RoomById.E0A
	for index, booth in voting.Booths do
		local holder = part(lobby, "BallotBooth" .. index, V(2.6, 4.2, 2.4), booth * F(0, 2.1, 0), WALL, M.SmoothPlastic)
		holder.Transparency = 1
		prompt(holder, Layout.BallotTag, "Vote", "Voting booth " .. index, 9)
	end

	-- The forecourt sits on the square's paving, the plinth's height below the floor.
	local forecourt = group("ParliamentForecourt")
	local ground = -plinth
	local poolFront, poolBack = Layout.Front + 18, Layout.Front + 40
	slab(forecourt, "PoolBed", -24, 24, ground, ground + 0.08, poolFront, poolBack, DARK, M.Slate)
	local water = slab(forecourt, "ReflectingPool", -24, 24, ground + 0.08, ground + 0.3, poolFront, poolBack, rgb(70, 104, 120), M.Glass)
	water.Reflectance, water.Transparency = 0.35, 0.2
	for _, sx in { -1, 1 } do
		slab(forecourt, "PoolRim", sx * 24, sx * 25.2, ground, ground + 0.7, poolFront - 1.2, poolBack + 1.2, rgb(214, 207, 190), M.Marble, true)
	end
	for _, z in { poolFront - 1.2, poolBack } do
		slab(forecourt, "PoolRim", -24, 24, ground, ground + 0.7, z, z + 1.2, rgb(214, 207, 190), M.Marble, true)
	end
	for _, sx in { -1, 1 } do
		local fx = sx * 40
		slab(forecourt, "FlagpoleBase", fx - 1.4, fx + 1.4, ground, ground + 1, Layout.Front + 12.6, Layout.Front + 15.4, STONE, M.Concrete, true)
		slab(forecourt, "Flagpole", fx - 0.16, fx + 0.16, ground + 1, ground + 34, Layout.Front + 13.84, Layout.Front + 14.16, DARK, M.Metal)
		for stripe, tint in { rgb(174, 42, 49), rgb(236, 234, 224), BLUE } do
			part(forecourt, "DutchFlagStripe", V(9, 1.6, 0.12), F(fx + 4.6, ground + 32 - (stripe - 1) * 1.6, Layout.Front + 14), tint, M.Fabric)
		end
	end

	hall:AddTag(Layout.Tag)
	hall.Parent = parent
	return hall
end
return Landmark
