-- A distant port city on its own stretch of mainland. Ships reach it up a long estuary, like
-- Southampton Water: the container terminal lines the west bank of a wide basin, the jetties
-- of the eastern docks face it, the refinery sits back behind the terminal, and the dense city fills
-- the peninsula behind the quays with its underground station under the forecourt.
-- Coordinates follow the north-up sea chart (north is -Z), relative to CENTER.
local HttpService = game:GetService("HttpService")
local CityBuildings = require(script.Parent.CityBuildings)
local CityLand = require(script.Parent.CityLand)
local CityLandmark = require(script.Parent.CityLandmark)
local CityMetro = require(script.Parent.CityMetro)
local CityPort = require(script.Parent.CityPort)
local CityRefinery = require(script.Parent.CityRefinery)
local CityStation = require(script.Parent.CityStation)
local Lod = require(script.Parent.Lod)
local Props = require(script.Parent.Props)

local City = {}
City.VERSION = 7
local CENTER = Vector3.new(7000, 0, 7000)
local TOP = 8 -- walkable land height
local CURB = TOP + 0.9 -- pavement and building floor height
local rgb = Color3.fromRGB
local M = Enum.Material

City.COAST = {
	{ -1200, 1180 },
	{ -1380, 900 },
	{ -1520, 620 },
	{ -1460, 300 },
	{ -1600, -20 },
	{ -1560, -380 },
	{ -1460, -700 },
	{ -1540, -1000 },
	{ -1420, -1330 },
	{ -1300, -1620 }, -- western headland
	{ -1170, -1590 }, -- estuary mouth, west side
	{ -1060, -1400 },
	{ -940, -1200 },
	{ -820, -1020 },
	{ -720, -985 },
}
-- Container terminal, head of the estuary and the slips of the eastern docks
for _, point in CityPort.quays() do
	table.insert(City.COAST, point)
end
-- The east bank runs north from the docks, round the cruise branch and out to the mouth
table.insert(City.COAST, { -236, CityPort.DOCKS.z0 }) -- the north wall of the eastern docks meets the natural bank
for _, point in CityPort.cruiseQuays() do
	table.insert(City.COAST, point)
end
for _, point in {
	{ -560, -1370 },
	{ -700, -1560 }, -- estuary mouth, east side
	{ -560, -1640 },
	{ -380, -1600 },
	{ -150, -1470 },
	{ 120, -1420 },
	{ 380, -1300 },
	{ 650, -1250 },
	{ 900, -1150 },
	{ 1180, -1120, "edge" }, -- the chart's eastern edge
	{ 1180, 1180, "edge" }, -- and its southern edge
} do
	table.insert(City.COAST, point)
end

-- Street centrelines and widths. Blocks fill the gaps between them; avenues are wider.
local STREETS_X = {
	{ -390, 16 }, { -300, 16 }, { -205, 16 }, { -105, 20 }, { -25, 16 }, { 60, 16 }, { 150, 26 },
	{ 235, 16 }, { 320, 16 }, { 410, 26 }, { 500, 16 }, { 590, 16 }, { 680, 16 }, { 775, 22 },
	{ 865, 16 }, { 955, 16 }, { 1050, 20 },
}
local STREETS_Z = {
	{ -870, 20 }, { -780, 16 }, { -690, 20 }, { -600, 16 }, { -510, 16 }, { -415, 26 }, { -325, 16 }, { -235, 16 }, { -130, 26 },
	{ -50, 16 }, { 40, 16 }, { 130, 26 }, { 220, 16 }, { 310, 16 }, { 400, 22 }, { 490, 16 }, { 580, 16 }, { 670, 20 },
}
local DOWNTOWN = Vector2.new(250, -80)
local STATION = { x0 = -390, x1 = -105, z0 = -130, z1 = 40 }
local CIVIC = { x0 = 235, x1 = 410, z0 = -325, z1 = -130 }
local CAR_COLORS = {
	rgb(120, 34, 30), rgb(40, 46, 58), rgb(176, 176, 170), rgb(64, 70, 66), rgb(30, 30, 32),
	rgb(90, 104, 120), rgb(150, 132, 96), rgb(200, 200, 196),
}
local LEAVES = { rgb(78, 102, 62), rgb(92, 112, 70), rgb(70, 92, 60), rgb(104, 118, 74), rgb(84, 96, 58) }
local FIELDS = { rgb(150, 140, 86), rgb(110, 126, 72), rgb(122, 104, 78), rgb(132, 146, 88), rgb(96, 112, 66) }

-- How far the built-up area reaches from downtown in a given direction, so the city
-- frays out into an irregular edge instead of filling a rectangle.
local function urbanReach(cx: number, cz: number): number
	local angle = math.atan2(cz - DOWNTOWN.Y, cx - DOWNTOWN.X)
	return 560 + 170 * math.sin(angle * 3 + 0.8) + 90 * math.sin(angle * 5 - 1.1)
end

-- Deterministic noise in [0, 1)
local function hash(a: number, b: number, salt: number): number
	local v = math.sin(a * 12.9898 + b * 78.233 + salt * 37.719) * 43758.5453
	return v - math.floor(v)
end

local function part(parent: Instance, name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material, collidable: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = CENTER + offset
	p.Anchored = true
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = collidable ~= false
	if collidable == false then
		p.CanQuery = false
		p.CastShadow = false
	end
	p.Parent = parent
	return p
end

-- A model that streams in as one piece (see server/Map/Lod)
local function pieceModel(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m:AddTag("LodPiece")
	m.Parent = parent
	return m
end

local function tree(parent: Instance, x: number, z: number, scale: number, seed: number)
	local trunk = 8 + scale * 6
	part(parent, "TreeTrunk", Vector3.new(1.6 + scale, trunk, 1.6 + scale), Vector3.new(x, TOP + trunk / 2, z), rgb(88, 70, 54), M.Wood)
	local crown = part(parent, "TreeCrown", Vector3.one * (11 + scale * 9), Vector3.new(x, TOP + trunk + 3 + scale * 2, z), LEAVES[seed % #LEAVES + 1], M.Grass, false)
	crown.Shape = Enum.PartType.Ball
end

local function car(parent: Instance, x: number, z: number, alongX: boolean, seed: number)
	local body = if alongX then Vector3.new(13, 2.8, 6) else Vector3.new(6, 2.8, 13)
	local cabin = if alongX then Vector3.new(7, 2.2, 5.4) else Vector3.new(5.4, 2.2, 7)
	part(parent, "ParkedCar", body, Vector3.new(x, TOP + 2.0, z), CAR_COLORS[seed % #CAR_COLORS + 1], M.SmoothPlastic)
	part(parent, "CarCabin", cabin, Vector3.new(x, TOP + 4.5, z), rgb(38, 44, 50), M.Glass, false)
end

local function lamp(parent: Instance, x: number, z: number)
	part(parent, "StreetLampPole", Vector3.new(0.6, 15, 0.6), Vector3.new(x, CURB + 7.5, z), rgb(52, 56, 56), M.Metal)
	part(parent, "StreetLampHead", Vector3.new(2.6, 0.7, 2.6), Vector3.new(x, CURB + 15, z), rgb(214, 200, 150), M.SmoothPlastic, false)
end

---------------------------------------------------------------------------------------------------
-- The district: an irregular grid that thins out into low-rise and then countryside

local function blockKind(i: number, j: number, cx: number, cz: number, w: number, d: number, coast): string?
	if cx > STATION.x0 and cx < STATION.x1 and cz > STATION.z0 and cz < STATION.z1 then
		return "station"
	end
	if cx > CIVIC.x0 and cx < CIVIC.x1 and cz > CIVIC.z0 and cz < CIVIC.z1 then
		return "civic"
	end
	-- West of the quay road, the land north of the harbour road is water and docks, and the
	-- eastern docks reach as far as the street behind their back apron
	if cz < -130 and (cx < -105 or (cx < CityPort.DOCKS.x1 and cz > CityPort.DOCKS.z0)) then
		return nil
	end
	if not CityLand.fits(coast, cx, cz, w, d, 14) then
		return nil
	end
	local distance = (Vector2.new(cx, cz) - DOWNTOWN).Magnitude
	local noise = hash(i, j, 1)
	if distance < 235 then
		return "tower"
	end
	local reach = urbanReach(cx, cz)
	local kind
	if cx < 150 and cz < -235 and cz > -700 then
		kind = "old"
	elseif distance < reach * 0.7 then
		kind = "mid"
	elseif distance < reach * (0.88 + noise * 0.3) then
		kind = "low"
	end
	if kind and noise < 0.07 then
		return "park"
	elseif kind and noise < 0.14 then
		return "parking"
	end
	return kind
end

local function fillBlock(block: Model, kind: string, cx: number, cz: number, bw: number, bd: number, seed: number)
	local lotW, lotD = bw - 8, bd - 8
	local distance = (Vector2.new(cx, cz) - DOWNTOWN).Magnitude
	if kind == "tower" then
		local width = math.min(lotW, 44 + seed % 4 * 3)
		local depth = math.min(lotD, 44 + seed % 3 * 4)
		local height = 96 + (1 - distance / 235) * 70 + hash(cx, cz, 3) * 46
		local facing = if seed % 2 == 0 then 0 else math.pi
		CityBuildings.build(block, CFrame.new(CENTER + Vector3.new(cx, CURB, cz)) * CFrame.Angles(0, facing, 0), width, depth, height, seed % 40 + 1)
		return
	elseif kind == "park" then
		part(block, "PocketPark", Vector3.new(lotW, 0.3, lotD), Vector3.new(cx, CURB + 0.05, cz), rgb(96, 114, 74), M.Grass, false)
		part(block, "ParkPath", Vector3.new(lotW, 0.4, 5), Vector3.new(cx, CURB + 0.1, cz), rgb(150, 144, 130), M.Concrete, false)
		for k = 0, 3 do
			tree(block, cx + (k % 2 - 0.5) * lotW * 0.6, cz + (k // 2 - 0.5) * lotD * 0.55, 0.6 + hash(seed, k, 5) * 0.5, seed + k)
		end
		return
	elseif kind == "parking" then
		part(block, "CarPark", Vector3.new(lotW, 0.3, lotD), Vector3.new(cx, CURB + 0.05, cz), rgb(70, 72, 72), M.Asphalt, false)
		for k = 0, 9 do
			if hash(seed, k, 7) < 0.7 then
				local x = cx - lotW / 2 + 6 + (k % 5) * (lotW - 12) / 4
				car(block, x, cz + (k // 5 - 0.5) * lotD * 0.5, false, seed + k)
			end
		end
		return
	elseif kind == "old" and seed % 5 < 2 then
		local facing = if seed % 2 == 0 then 0 else math.pi
		CityBuildings.warehouse(block, CFrame.new(CENTER + Vector3.new(cx, CURB, cz)) * CFrame.Angles(0, facing, 0), lotW, lotD * 0.86, 18 + seed % 3 * 4, seed)
		return
	end

	-- Two rows of street-facing buildings back onto a narrow service yard
	local columns = if kind == "low" then 2 else 2 + seed % 2
	local yard = if kind == "low" then 8 else 3
	for row, side in { -1, 1 } do
		for c = 1, columns do
			local variant = seed * 7 + row * 3 + c
			if kind == "low" and hash(seed, row * 5 + c, 9) < 0.25 then
				continue
			end
			local width = lotW / columns
			local x = cx - lotW / 2 + (c - 0.5) * width
			local inset = (variant % 3) * 0.8
			local depth = (lotD - yard) / 2 - inset
			local z = cz + side * (lotD / 2 - inset - depth / 2)
			local floors
			if kind == "mid" then
				floors = math.clamp(4 + math.floor((420 - distance) / 60) + variant % 3, 4, 9)
			elseif kind == "old" then
				floors = 4 + variant % 3
			else
				floors = 2 + variant % 3
			end
			local facing = if side < 0 then math.pi else 0
			CityBuildings.block(block, CFrame.new(CENTER + Vector3.new(x, CURB, z)) * CFrame.Angles(0, facing, 0), width - 0.3, depth, floors, variant)
		end
	end
	if kind ~= "mid" then
		part(block, "Dumpster", Vector3.new(4, 4, 7), Vector3.new(cx + (seed % 3 - 1) * lotW * 0.3, CURB + 2, cz), rgb(52, 74, 56), M.Metal)
	end
end

local function buildDistrict(ground: Instance, coast): { { number } }
	local kinds: { [number]: { [number]: string } } = {}
	local blocks = {}
	for i = 1, #STREETS_X - 1 do
		kinds[i] = {}
		for j = 1, #STREETS_Z - 1 do
			local x0 = STREETS_X[i][1] + STREETS_X[i][2] / 2
			local x1 = STREETS_X[i + 1][1] - STREETS_X[i + 1][2] / 2
			local z0 = STREETS_Z[j][1] + STREETS_Z[j][2] / 2
			local z1 = STREETS_Z[j + 1][1] - STREETS_Z[j + 1][2] / 2
			local cx, cz, w, d = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0
			local kind = blockKind(i, j, cx, cz, w, d, coast)
			if kind then
				kinds[i][j] = kind
				table.insert(blocks, { i = i, j = j, kind = kind, cx = cx, cz = cz, w = w, d = d })
			end
		end
	end
	local function kindAt(i: number, j: number): string?
		return kinds[i] and kinds[i][j]
	end
	-- A street runs between two cells unless both belong to the same merged plaza
	local function between(a: string?, b: string?): boolean
		if not a and not b then
			return false
		end
		return not (a == b and (a == "civic" or a == "station"))
	end

	local streets = Instance.new("Model")
	streets.Name = "Streets"
	streets.Parent = ground
	local asphalt, line = rgb(58, 60, 60), rgb(196, 192, 170)
	-- Streets along X lines take every intersection they reach, so the cross streets stop short
	local covered: { [string]: boolean } = {}
	for i, street in STREETS_X do
		local x, width = street[1], street[2]
		local active = {}
		for j = 1, #STREETS_Z - 1 do
			active[j] = between(kindAt(i - 1, j), kindAt(i, j))
		end
		local runStart: number? = nil
		for j = 1, #STREETS_Z do
			local on = active[j] == true
			local reaches = on or active[j - 1] == true
			if reaches then
				covered[i .. "," .. j] = true
				runStart = runStart or j
			end
			if runStart and (not on or j == #STREETS_Z) then
				local z0 = STREETS_Z[runStart][1] - STREETS_Z[runStart][2] / 2
				local z1 = STREETS_Z[j][1] + STREETS_Z[j][2] / 2
				part(streets, "Street", Vector3.new(width, 0.5, z1 - z0), Vector3.new(x, TOP + 0.25, (z0 + z1) / 2), asphalt, M.Asphalt)
				if width >= 22 then
					part(streets, "CentreLine", Vector3.new(0.8, 0.06, z1 - z0 - 4), Vector3.new(x, TOP + 0.53, (z0 + z1) / 2), line, M.SmoothPlastic, false)
				end
				runStart = nil
			end
		end
	end
	for j, street in STREETS_Z do
		local z, width = street[1], street[2]
		-- Alternate intersections and the stretches between them, west to east
		local pieces = {}
		for i = 1, #STREETS_X do
			local x = STREETS_X[i][1]
			local half = STREETS_X[i][2] / 2
			local before = i > 1 and between(kindAt(i - 1, j - 1), kindAt(i - 1, j))
			local after = i < #STREETS_X and between(kindAt(i, j - 1), kindAt(i, j))
			table.insert(pieces, { x - half, x + half, (before or after) and not covered[i .. "," .. j] })
			if i < #STREETS_X then
				table.insert(pieces, { x + half, STREETS_X[i + 1][1] - STREETS_X[i + 1][2] / 2, after })
			end
		end
		local runStart: number? = nil
		for k = 1, #pieces + 1 do
			local on = pieces[k] and pieces[k][3]
			if on and not runStart then
				runStart = pieces[k][1]
			elseif not on and runStart then
				local runEnd = pieces[k - 1][2]
				part(streets, "Street", Vector3.new(runEnd - runStart, 0.5, width), Vector3.new((runStart + runEnd) / 2, TOP + 0.25, z), asphalt, M.Asphalt)
				if width >= 22 then
					part(streets, "CentreLine", Vector3.new(runEnd - runStart - 4, 0.06, 0.8), Vector3.new((runStart + runEnd) / 2, TOP + 0.55, z), line, M.SmoothPlastic, false)
				end
				runStart = nil
			end
		end
	end
	-- Zebra crossings where avenues meet
	for i, sx in STREETS_X do
		for j, sz in STREETS_Z do
			if sx[2] >= 22 and sz[2] >= 22 and covered[i .. "," .. j] then
				for _, side in { -1, 1 } do
					for stripe = -2, 2 do
						part(streets, "Crosswalk", Vector3.new(2.2, 0.08, 6), Vector3.new(sx[1] + stripe * 4.4, TOP + 0.56, sz[1] + side * (sz[2] / 2 + 3.5)), line, M.SmoothPlastic, false)
					end
				end
			end
		end
	end
	task.wait()

	for index, b in blocks do
		local block = pieceModel(ground, "CityBlock")
		local seed = b.i * 31 + b.j * 17
		if b.kind == "station" or b.kind == "civic" then
			-- Plazas are paved once, as a whole, below
		else
			local shade = 0.85 + hash(b.i, b.j, 2) * 0.2
			part(block, "Pavement", Vector3.new(b.w, 0.9, b.d), Vector3.new(b.cx, TOP + 0.45, b.cz), Color3.new(0.6 * shade, 0.59 * shade, 0.56 * shade), M.Concrete)
			fillBlock(block, b.kind, b.cx, b.cz, b.w, b.d, seed)
			if b.kind ~= "park" then
				lamp(block, b.cx - b.w / 2 + 1.5, b.cz - b.d / 2 + 1.5)
			end
			-- Cars parked along the kerb on the block's south side
			for k = 0, 3 do
				if hash(seed, k, 11) < 0.55 then
					car(block, b.cx - b.w / 2 + 9 + k * (b.w - 18) / 3, b.cz + b.d / 2 + 4, true, seed + k)
				end
			end
			if b.kind == "mid" and seed % 3 == 0 then
				for k = -1, 1 do
					tree(block, b.cx + k * b.w * 0.3, b.cz - b.d / 2 + 2, 0.45, seed + k)
				end
			end
		end
		if index % 12 == 0 then
			task.wait()
		end
	end

	-- The station forecourt faces the head of the estuary and the marina, with the
	-- underground station below it
	local sx0, sx1 = STATION.x0 + STREETS_X[1][2] / 2, STATION.x1 - STREETS_X[4][2] / 2
	local sz0, sz1 = STATION.z0 + 13, STATION.z1 - 8
	CityMetro.build(ground, CENTER, TOP, { sx0, sx1, sz0, sz1 })
	local plaza = pieceModel(ground, "StationPlaza")
	local station = CityStation.build(plaza, CFrame.new(CENTER + Vector3.new(-250, CURB, -62)))
	station:SetAttribute("LodColor", rgb(140, 100, 84))

	local civic = pieceModel(ground, "CivicSquare")
	local cx0, cx1 = CIVIC.x0 + 8, CIVIC.x1 - 13
	local cz0, cz1 = CIVIC.z0 + 8, CIVIC.z1 - 13
	part(civic, "SquarePaving", Vector3.new(cx1 - cx0, 0.9, cz1 - cz0), Vector3.new((cx0 + cx1) / 2, TOP + 0.45, (cz0 + cz1) / 2), rgb(164, 156, 142), M.Concrete)
	local hall = CityLandmark.build(civic, CFrame.new(CENTER + Vector3.new((cx0 + cx1) / 2, CURB, -262)))
	hall:SetAttribute("LodColor", rgb(150, 110, 92))
	for _, dx in { -60, 60 } do
		for _, dz in { -185, -165 } do
			tree(civic, (cx0 + cx1) / 2 + dx, dz, 0.7, dx + dz)
		end
	end

	-- Woods may grow wherever the grid left a cell empty
	local occupied = {}
	for _, b in blocks do
		table.insert(occupied, { b.cx - b.w / 2 - 10, b.cx + b.w / 2 + 10, b.cz - b.d / 2 - 10, b.cz + b.d / 2 + 10 })
	end
	return occupied
end

---------------------------------------------------------------------------------------------------
-- Suburbs, farmland and woods around the city

local function inside(rects: { { number } }, x: number, z: number, margin: number): boolean
	for _, r in rects do
		if x > r[1] - margin and x < r[2] + margin and z > r[3] - margin and z < r[4] + margin then
			return true
		end
	end
	return false
end

local function suburbs(ground: Instance, coast, reserved: { { number } })
	local roads = Instance.new("Model")
	roads.Name = "SuburbRoads"
	roads.Parent = ground
	local x0, x1 = -380, 1120
	for row, z in { 760, 880, 1000, 1110 } do
		part(roads, "SuburbRoad", Vector3.new(x1 - x0, 0.5, 14), Vector3.new((x0 + x1) / 2, TOP + 0.25, z), rgb(66, 68, 66), M.Asphalt)
		local street: Model
		for x = x0 + 14, x1 - 14, 26 do
			-- A few houses at a time, so each streaming piece stays small and local
			if (x - x0 - 14) % 156 == 0 then
				street = pieceModel(ground, "SuburbStreet")
			end
			for _, side in { -1, 1 } do
				local seed = math.floor(x) * 3 + row * 101 + side
				local hz = z + side * 19
				if hash(x, hz, 13) < 0.3 or not CityLand.fits(coast, x, hz, 14, 14, 12) then
					continue
				end
				local wall = ({ rgb(178, 160, 136), rgb(150, 100, 82), rgb(196, 188, 170), rgb(128, 90, 76), rgb(170, 170, 160) })[seed % 5 + 1]
				local roof = ({ rgb(78, 60, 54), rgb(62, 64, 66), rgb(96, 70, 58) })[seed % 3 + 1]
				local frame = CFrame.new(CENTER + Vector3.new(x, TOP + 5, hz))
				part(street, "House", Vector3.new(14, 10, 11), Vector3.new(x, TOP + 5, hz), wall, if seed % 2 == 0 then M.Brick else M.Concrete)
				for _, slope in { -1, 1 } do
					local tile = part(street, "HouseRoof", Vector3.new(15, 0.8, 7.6), Vector3.zero, roof, M.Slate)
					tile.CFrame = frame * CFrame.new(0, 7.2, slope * 3) * CFrame.Angles(slope * 0.62, 0, 0)
				end
				if seed % 4 == 0 then
					car(street, x + 10, hz - side * 1, false, seed)
				end
			end
		end
		task.wait()
	end
	-- Lanes tie the estates back into the city grid
	for _, x in { -205, 150, 410, 775 } do
		-- Slightly lower than the streets it meets, so the overlaps never flicker
		part(roads, "SuburbLane", Vector3.new(14, 0.4, 1110 - 600), Vector3.new(x, TOP + 0.2, (1110 + 600) / 2), rgb(66, 68, 66), M.Asphalt)
		table.insert(reserved, { x - 8, x + 8, 600, 1110 })
	end
	table.insert(reserved, { x0, x1, 740, 1180 })
end

local function countryside(ground: Instance, coast, reserved: { { number } })
	-- Farmland on the western shore, behind the container terminal
	local fields = {}
	for gx = -1400, -560, 170 do
		for gz = -60, 1080, 150 do
			local w, d = 130 + hash(gx, gz, 15) * 30, 110 + hash(gz, gx, 16) * 30
			if hash(gx, gz, 17) < 0.7 and CityLand.fits(coast, gx, gz, w, d, 20) and not inside(reserved, gx, gz, 90) then
				part(ground, "Field", Vector3.new(w, 0.3, d), Vector3.new(gx, TOP + 0.15, gz), FIELDS[math.floor(hash(gx, gz, 18) * #FIELDS) + 1], M.Grass, false)
				table.insert(fields, { gx - w / 2, gx + w / 2, gz - d / 2, gz + d / 2 })
			end
		end
	end
	part(ground, "CountryRoad", Vector3.new(26, 0.5, 1290), Vector3.new(-640, TOP + 0.25, 515), rgb(66, 68, 66), M.Asphalt)
	local roadWest = CityRefinery.GATE_X - 9
	part(ground, "HarbourRoad", Vector3.new(STREETS_X[1][1] - 8 - roadWest, 0.5, 26), Vector3.new((STREETS_X[1][1] - 8 + roadWest) / 2, TOP + 0.25, -130), rgb(58, 60, 60), M.Asphalt)
	table.insert(reserved, { -653, -627, -130, 1160 })
	table.insert(reserved, { roadWest, -380, -143, -117 })

	-- Woods gather in patches rather than an even scatter
	local count = 0
	for gx = -1600, 1180, 46 do
		for gz = -1790, 1180, 46 do
			local x = gx + (hash(gx, gz, 19) - 0.5) * 30
			local z = gz + (hash(gz, gx, 20) - 0.5) * 30
			local forest = math.sin(x * 0.0045 + 1.3) * math.cos(z * 0.0052 - 0.7) + 0.5 * math.sin(x * 0.011 + z * 0.009)
			if forest > 0.35 and CityLand.inside(coast, x, z) and not inside(reserved, x, z, 12) and not inside(fields, x, z, 6) then
				if CityLand.edgeDistance(coast, x, z) > 22 then
					count += 1
					tree(ground, x, z, 0.6 + hash(x, z, 21) * 0.9, count)
				end
			end
		end
		task.wait()
	end
	Props.lighthouse(ground, CENTER + Vector3.new(-580, TOP, -1580))
end

function City.build(root: Instance): Model
	local existing = root:FindFirstChild("Modern City")
	if existing and existing:IsA("Model") and existing:GetAttribute("CityVersion") == City.VERSION then
		return existing
	end
	local city = Instance.new("Model")
	city.Name = "Modern City"
	city:SetAttribute("CityVersion", City.VERSION)
	-- The city streams and draws its distant shell like an island (see server/Map/Lod)
	city:SetAttribute("LodRoot", true)
	city:SetAttribute("LodStamp", "city" .. City.VERSION)
	if existing then
		city:SetAttribute("LodId", existing:GetAttribute("LodId"))
	end
	local chart = {}
	for _, point in City.COAST do
		table.insert(chart, { CENTER.X + point[1], CENTER.Z + point[2] })
	end
	city:SetAttribute("ChartCoast", HttpService:JSONEncode(chart))

	-- Everything you can see goes under Ground, so the client only drops the distant shell
	-- once most of the real city has arrived.
	local ground = Instance.new("Model")
	ground.Name = "Ground"
	ground.Parent = city
	local coast = CityLand.roughen(City.COAST, 110, 22)
	CityLand.fill(ground, coast, CENTER, TOP, -30, rgb(100, 112, 80), M.Grass, { CityMetro.HOLE })
	CityLand.shore(ground, coast, CENTER, TOP)
	task.wait()

	local reserved = buildDistrict(ground, coast)
	for _, rect in CityPort.build(ground, CENTER, TOP) do
		table.insert(reserved, rect)
	end
	for _, rect in CityRefinery.build(ground, CENTER, TOP) do
		table.insert(reserved, rect)
	end
	task.wait()
	suburbs(ground, coast, reserved)
	countryside(ground, coast, reserved)

	local arrival = part(city, "CityArrival", Vector3.new(2, 0.2, 2), Vector3.new(CityMetro.ARRIVAL[1], CURB + 0.1, CityMetro.ARRIVAL[2]), rgb(150, 144, 134), M.Concrete, false)
	arrival.Transparency = 1

	-- Split into streaming pieces before the first replication, then publish it whole
	Lod.prepareIsland(city)
	city.Parent = root
	if existing then
		existing:Destroy()
	end
	return city
end

return City
