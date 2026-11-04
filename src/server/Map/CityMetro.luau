-- Hafen Mitte, the city's underground station, built like a London tube station under the
-- forecourt where /tp city lands. Escalators and a tiled stairwell lead down from the plaza
-- into a ticket hall with its barrier line, and a footbridge crosses a vaulted, tiled
-- platform hall with two tracks and a train waiting. The plaza above gets its street
-- furniture: phone boxes, hire bikes, a fountain, a taxi rank and the station entrances.
-- Positions are relative to the city centre at sea level; north is -Z. Everything below
-- ground sits inside Biomes.DryPockets, which the map clears of water.
local CityMetro = {}

-- The opening the station needs in the land slab {x0, x1, z0, z1}, inside the forecourt
CityMetro.HOLE = { -380, -118, -116, 30 }
-- Where /tp city lands: on the plaza, facing the escalator entrance
CityMetro.ARRIVAL = { -262, 3 }

local HALL = -12 -- ticket hall and footbridge floor
local CEILING = 5.4 -- underside of the ticket hall ceiling
local PLATFORM = -34
local BED = -37.5 -- top of the track bed
local BASE = -40
-- Vaulted platform hall, inside its walls
local VX0, VX1, VZ0, VZ1 = -372, -128, -112, -50
local SPRING, CROWN = -2, 6
local NORTH_EDGE, SOUTH_EDGE = -97, -65 -- platform edges either side of the tracks
local TRACKS = { -91.5, -70.5 }
local RIBS = { -352, -318, -284, -250, -216, -182, -148 }
local SEGMENTS = 8
-- Ticket hall, inside its walls
local TX0, TX1, TZ0, TZ1 = -340, -130, -46, 22
local BRIDGE_X = -250 -- the footbridge runs north from the ticket hall across the tracks
-- Openings in the forecourt
local ESCALATOR = { x0 = -232, x1 = -208, z0 = -8, z1 = 14 }
local STAIRWELL = { x0 = -330, x1 = -310, z0 = 0, z1 = 10 }

local rgb = Color3.fromRGB
local M = Enum.Material
local cream = rgb(232, 224, 198) -- glazed wall tiles
local maroon = rgb(112, 30, 38)
local teal = rgb(34, 84, 76) -- tile bands and ironwork
local terrazzo = rgb(206, 198, 180)
local paving = rgb(150, 144, 134)
local granite = rgb(112, 108, 102)
local ironwork = rgb(28, 40, 36)
local stainless = rgb(170, 174, 176)
local brass = rgb(178, 142, 74)
local black = rgb(20, 20, 22)
local white = rgb(240, 240, 236)
local roundelRed = rgb(220, 36, 31)
local roundelBlue = rgb(0, 25, 168)
local LEAVES = { rgb(78, 102, 62), rgb(92, 112, 70), rgb(70, 92, 60) }
local FACES = { ["z+"] = Enum.NormalId.Back, ["z-"] = Enum.NormalId.Front, ["x+"] = Enum.NormalId.Right, ["x-"] = Enum.NormalId.Left }

local function pieceModel(parent: Instance, name: string, underground: boolean?): Model
	local m = Instance.new("Model")
	m.Name = name
	if underground then
		-- Nothing below ground belongs in the distant shell
		m:SetAttribute("LodSkip", true)
	end
	m:AddTag("LodPiece")
	m.Parent = parent
	return m
end

local function glow(p: BasePart, face: Enum.NormalId?, range: number, brightness: number)
	local light: Light
	if face then
		local surface = Instance.new("SurfaceLight")
		surface.Face = face
		surface.Angle = 120
		light = surface
	else
		light = Instance.new("PointLight")
	end
	light.Range = range
	light.Brightness = brightness
	light.Color = rgb(255, 238, 210)
	light.Parent = p
end

local function sign(p: BasePart, face: Enum.NormalId, words: string, color: Color3, font: Enum.Font?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = font or Enum.Font.GothamBold
	label.TextColor3 = color
	label.TextScaled = true
	label.Text = words
	label.Parent = gui
	return label
end

-- Repair the same named rooms in fresh and baked maps. Rooms retain this
-- stamp when MetroStations moves them into the persistent city stop.
function CityMetro.ensureSurfaces(root: Instance, origin: Vector3)
	for _, room in root:GetChildren() do
		if room:GetAttribute("MetroSurfaceVersion") == 1 or not room.Name:match("^Metro") then continue end
		for _, p in room:GetDescendants() do
			if not p:IsA("BasePart") then continue end
			local name = p.Name
			if name == "VaultPanel" or name == "VaultRib" then
				-- Overlapping arch segments need distinct end-cap planes.
				local index = math.floor(math.clamp((p.Position.Z - origin.Z - VZ0) / (VZ1 - VZ0), 0, 0.999) * SEGMENTS)
				p.Size += Vector3.new((if name == "VaultPanel" then 0.24 else 0.2) + index % 2 * 0.12, 0, 0)
			elseif name == "StairSoffit" or name == "EscalatorTruss" then
				-- Keep structural backing inside the visible stair edges.
				p.Size -= Vector3.new(if name == "StairSoffit" then 0.6 else 0.2, 0, 0)
			elseif name == "BridgeStep" or name == "StairStep" or name == "FixedStep" then
				local top = p.Position.Y - origin.Y + p.Size.Y / 2
				local floor = if name == "BridgeStep" then PLATFORM else HALL
				if math.abs(top - floor) < 0.001 then p.CFrame += Vector3.new(0, 0.06, 0) end
			elseif name == "RibPilaster" then
				p.CFrame += Vector3.new(0.04, 0, if p.Position.Z - origin.Z < (VZ0 + VZ1) / 2 then 0.04 else -0.04)
			elseif name == "EndWall" then
				-- Extend outward, keeping the platform-facing boundary intact.
				p.Size += Vector3.new(0.16, 0.12, 0)
				p.CFrame += Vector3.new(if p.Position.X - origin.X < (VX0 + VX1) / 2 then -0.08 else 0.08, 0, 0)
				if math.abs(p.Size.Z - 17) < 0.001 then
					p.Size += Vector3.new(0, 0, 0.06)
					p.CFrame += Vector3.new(0, 0, if p.Position.Z - origin.Z < (VZ0 + VZ1) / 2 then -0.03 else 0.03)
				end
			elseif room.Name == "MetroTicketHall" and name == "FloorBorder" and p.Size.Z > p.Size.X then
				p.Size -= Vector3.new(0, 0, 3)
			elseif room.Name == "MetroTicketHall" and (name == "DadoTiles" or name == "FriezeTiles") and p.Size.X > p.Size.Z then
				p.Size -= Vector3.new(0.48, 0, 0)
			elseif name == "WellFascia" then
				p.Size += Vector3.new(if p.Size.X > p.Size.Z then -0.12 else 0.12, 0, 0.12)
				p.CFrame += Vector3.new(0, 0.06, 0)
			elseif name == "StairWall" then
				if p.Size.X < p.Size.Z then
					p.Size += Vector3.new(0.12, 0, -0.12)
				else
					p.Size += Vector3.new(0.08, 0, 0.12)
					p.CFrame += Vector3.new(0.04, 0, 0)
				end
			elseif room.Name == "MetroStairwell" and name == "StairHandrail" then
				if math.abs(p.CFrame.LookVector.Y) < 0.001 then p.Size += Vector3.new(0.08, 0, 0) end
			elseif name == "MapFrame" then
				p.CFrame += Vector3.new(0.04, 0, 0)
			elseif name == "LightTrough" then
				p.Size += Vector3.new(0.08, 0, 0)
				p.CFrame += Vector3.new(0, -0.04, 0)
			elseif name == "ClockHand" then
				if p.Size.Y < math.max(p.Size.X, p.Size.Z) then
					p.Size += Vector3.new(0.12, 0, 0.12)
					p.CFrame += Vector3.new(0, 0.04, 0)
				end
			end
		end
		room:SetAttribute("MetroSurfaceVersion", 1)
	end
end

function CityMetro.build(parent: Instance, origin: Vector3, top: number, forecourt: { number })
	local surface = top + 0.9
	local metro = Instance.new("Model")
	metro.Name = "HafenMitte"
	metro.Parent = parent

	local function part(into: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material, collide: boolean?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Position = origin + position
		p.Anchored = true
		p.Color = color
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = collide ~= false
		if collide == false then
			p.CanQuery = false
			p.CastShadow = false
		end
		p.Parent = into
		return p
	end
	local function box(into: Instance, name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, color: Color3, material: Enum.Material, collide: boolean?): Part
		return part(into, name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, material, collide)
	end
	local function cylinder(into: Instance, name: string, diameter: number, length: number, position: Vector3, axis: string, color: Color3, material: Enum.Material, collide: boolean?): Part
		local p = part(into, name, Vector3.new(length, diameter, diameter), position, color, material, collide)
		p.Shape = Enum.PartType.Cylinder
		local turn = if axis == "y" then CFrame.Angles(0, 0, math.pi / 2) elseif axis == "z" then CFrame.Angles(0, math.pi / 2, 0) else CFrame.identity
		p.CFrame = CFrame.new(origin + position) * turn
		return p
	end
	local function ball(into: Instance, name: string, diameter: number, position: Vector3, color: Color3, material: Enum.Material): Part
		local p = part(into, name, Vector3.one * diameter, position, color, material, false)
		p.Shape = Enum.PartType.Ball
		return p
	end
	-- A slab whose top face runs from a to b, for stairs, escalators and balustrades
	local function incline(into: Instance, name: string, a: Vector3, b: Vector3, width: number, thickness: number, color: Color3, material: Enum.Material, collide: boolean?): Part
		local p = part(into, name, Vector3.new(width, thickness, (b - a).Magnitude), (a + b) / 2, color, material, collide)
		p.CFrame = CFrame.lookAt(origin + (a + b) / 2, origin + b) * CFrame.new(0, -thickness / 2, 0)
		return p
	end
	local function rod(into: Instance, name: string, a: Vector3, b: Vector3, thickness: number, color: Color3, material: Enum.Material): Part
		local p = part(into, name, Vector3.new(thickness, thickness, (b - a).Magnitude), (a + b) / 2, color, material, false)
		p.CFrame = CFrame.lookAt(origin + (a + b) / 2, origin + b)
		return p
	end
	-- Paves a rectangle as a few strips, leaving the given openings {x0, x1, z0, z1} clear
	local function pave(into: Instance, name: string, x0: number, x1: number, z0: number, z1: number, holes, y0: number, y1: number, color: Color3, material: Enum.Material)
		local xs, zs = { x0, x1 }, { z0, z1 }
		for _, hole in holes do
			for _, x in { hole.x0, hole.x1 } do
				if x > x0 and x < x1 then
					table.insert(xs, x)
				end
			end
			for _, z in { hole.z0, hole.z1 } do
				if z > z0 and z < z1 then
					table.insert(zs, z)
				end
			end
		end
		table.sort(xs)
		table.sort(zs)
		for j = 1, #zs - 1 do
			local runStart: number? = nil
			for i = 1, #xs - 1 do
				local mx, mz = (xs[i] + xs[i + 1]) / 2, (zs[j] + zs[j + 1]) / 2
				local open = false
				for _, hole in holes do
					if mx > hole.x0 and mx < hole.x1 and mz > hole.z0 and mz < hole.z1 then
						open = true
					end
				end
				if not open and not runStart then
					runStart = xs[i]
				end
				if runStart and (open or i == #xs - 1) then
					local runEnd = if open then xs[i] else xs[i + 1]
					if runEnd - runStart > 0.01 and zs[j + 1] - zs[j] > 0.01 then
						box(into, name, runStart, runEnd, y0, y1, zs[j], zs[j + 1], color, material)
					end
					runStart = nil
				end
			end
		end
	end
	-- The red ring, white disc and blue name bar, readable from both sides of `axis`
	local function roundel(into: Instance, position: Vector3, axis: string, diameter: number, words: string)
		cylinder(into, "RoundelRing", diameter, 0.3, position, axis, roundelRed, M.SmoothPlastic, false)
		cylinder(into, "RoundelDisc", diameter * 0.62, 0.36, position, axis, white, M.SmoothPlastic, false)
		local size = if axis == "z" then Vector3.new(diameter * 1.3, diameter * 0.24, 0.44) else Vector3.new(0.44, diameter * 0.24, diameter * 1.3)
		local bar = part(into, "RoundelBar", size, position, roundelBlue, M.SmoothPlastic, false)
		for _, face in if axis == "z" then { Enum.NormalId.Front, Enum.NormalId.Back } else { Enum.NormalId.Left, Enum.NormalId.Right } do
			sign(bar, face, words, white)
		end
	end
	local function poster(into: Instance, position: Vector3, facing: string, title: string, line: string, color: Color3)
		local alongX = facing:sub(1, 1) == "z"
		local out = if facing:sub(2) == "+" then 1 else -1
		local normal = if alongX then Vector3.new(0, 0, out) else Vector3.new(out, 0, 0)
		local w, h = 7, 9.5
		part(into, "PosterFrame", if alongX then Vector3.new(w + 0.8, h + 0.8, 0.2) else Vector3.new(0.2, h + 0.8, w + 0.8), position + normal * 0.1, black, M.Metal, false)
		local sheet = part(into, "Poster", if alongX then Vector3.new(w, h, 0.1) else Vector3.new(0.1, h, w), position + normal * 0.25, color, M.SmoothPlastic, false)
		local heading = sign(sheet, FACES[facing], title, white)
		heading.Size = UDim2.fromScale(0.9, 0.3)
		heading.Position = UDim2.fromScale(0.05, 0.12)
		local small = Instance.new("TextLabel")
		small.Size = UDim2.fromScale(0.86, 0.24)
		small.Position = UDim2.fromScale(0.07, 0.62)
		small.BackgroundTransparency = 1
		small.Font = Enum.Font.Gotham
		small.TextColor3 = white
		small.TextScaled = true
		small.Text = line
		small.Parent = heading.Parent
	end
	-- A bench whose back is on the `back` side (+1 or -1 across its length)
	local function bench(into: Instance, x: number, y: number, z: number, alongX: boolean, back: number)
		local length, depth = 7, 1.8
		local function at(along: number, across: number, height: number): Vector3
			return if alongX then Vector3.new(x + along, y + height, z + across) else Vector3.new(x + across, y + height, z + along)
		end
		local function size(along: number, height: number, across: number): Vector3
			return if alongX then Vector3.new(along, height, across) else Vector3.new(across, height, along)
		end
		part(into, "BenchSeat", size(length, 0.4, depth), at(0, 0, 1.8), rgb(120, 86, 58), M.Wood)
		part(into, "BenchBack", size(length, 2, 0.3), at(0, back * (depth / 2 - 0.15), 3), rgb(120, 86, 58), M.Wood, false)
		for _, along in { -2.8, 2.8 } do
			part(into, "BenchLeg", size(0.4, 1.6, depth), at(along, 0, 0.8), ironwork, M.Metal)
		end
	end

	---------------------------------------------------------------------------------------------
	-- The forecourt, open over the escalators and the stairwell

	local holes = { ESCALATOR, STAIRWELL }
	local court = pieceModel(metro, "Forecourt")
	pave(court, "Forecourt", forecourt[1], forecourt[2], forecourt[3], forecourt[4], holes, top, surface, paving, M.Concrete)
	-- Granite banding across the paving
	for _, z in { -100, -30 } do
		box(court, "GraniteBand", forecourt[1] + 2, forecourt[2] - 2, surface, surface + 0.04, z - 1, z + 1, granite, M.Granite, false):SetAttribute("LodSkip", true)
	end
	box(court, "GraniteBand", -151, -149, surface, surface + 0.04, forecourt[3] + 2, forecourt[4] - 2, granite, M.Granite, false):SetAttribute("LodSkip", true)

	---------------------------------------------------------------------------------------------
	-- Ticket hall: terrazzo floor, tiled walls, the barrier line and the ticket office

	local hall = pieceModel(metro, "MetroTicketHall", true)
	box(hall, "HallFloor", TX0 - 2, TX1 + 2, HALL - 2, HALL, TZ0 - 2, TZ1 + 2, terrazzo, M.Marble)
	for _, strip in { { TX0, TX1, TZ0, TZ0 + 1.5 }, { TX0, TX1, TZ1 - 1.5, TZ1 }, { TX0, TX0 + 1.5, TZ0, TZ1 }, { TX1 - 1.5, TX1, TZ0, TZ1 } } do
		box(hall, "FloorBorder", strip[1], strip[2], HALL, HALL + 0.04, strip[3], strip[4], maroon, M.Marble, false)
	end
	box(hall, "HallWall", TX0 - 2, TX1 + 2, HALL, top, TZ1, TZ1 + 2, cream, M.CeramicTiles)
	box(hall, "HallWall", TX0 - 2, TX0, HALL, top, TZ0 - 2, TZ1, cream, M.CeramicTiles)
	box(hall, "HallWall", TX1, TX1 + 2, HALL, top, TZ0 - 2, TZ1, cream, M.CeramicTiles)
	box(hall, "HallWall", TX0, BRIDGE_X - 6, HALL, top, TZ0 - 2, TZ0, cream, M.CeramicTiles)
	box(hall, "HallWall", BRIDGE_X + 6, TX1, HALL, top, TZ0 - 2, TZ0, cream, M.CeramicTiles)
	box(hall, "HallWall", BRIDGE_X - 6, BRIDGE_X + 6, HALL + 9, top, TZ0 - 2, TZ0, cream, M.CeramicTiles)
	for _, face in { { TX0, TX1, TZ1 - 0.2, TZ1 }, { TX0, TX0 + 0.2, TZ0, TZ1 }, { TX1 - 0.2, TX1, TZ0, TZ1 }, { TX0, BRIDGE_X - 6, TZ0, TZ0 + 0.2 }, { BRIDGE_X + 6, TX1, TZ0, TZ0 + 0.2 } } do
		box(hall, "DadoTiles", face[1], face[2], HALL, HALL + 3, face[3], face[4], maroon, M.CeramicTiles, false)
		box(hall, "FriezeTiles", face[1], face[2], 2, 3.2, face[3], face[4], teal, M.CeramicTiles, false)
	end
	pave(hall, "HallCeiling", TX0, TX1, TZ0, TZ1, holes, CEILING, CEILING + 0.6, rgb(236, 232, 220), M.SmoothPlastic)
	-- Close the gap between the ceiling and the forecourt round the openings
	local E, S = ESCALATOR, STAIRWELL
	for _, edge in { { E.x0, E.x1, E.z0 - 0.4, E.z0 }, { E.x0, E.x1, E.z1, E.z1 + 0.4 }, { E.x1, E.x1 + 0.4, E.z0, E.z1 }, { E.x0 - 0.4, E.x0, E.z0, E.z1 }, { S.x1, S.x1 + 0.4, S.z0, S.z1 } } do
		box(hall, "WellFascia", edge[1], edge[2], CEILING, top, edge[3], edge[4], cream, M.CeramicTiles)
	end
	for _, z in { -38, -22, 18 } do
		glow(box(hall, "LightPanel", TX0 + 6, TX1 - 6, CEILING - 0.2, CEILING, z - 1, z + 1, rgb(255, 246, 226), M.Neon, false), Enum.NormalId.Bottom, 24, 1.2)
	end
	for _, c in { { -290, -18 }, { -210, -18 }, { -170, -18 }, { -170, 12 } } do
		box(hall, "HallColumn", c[1] - 1.5, c[1] + 1.5, HALL, CEILING, c[2] - 1.5, c[2] + 1.5, cream, M.CeramicTiles)
		box(hall, "ColumnBase", c[1] - 1.9, c[1] + 1.9, HALL, HALL + 1.2, c[2] - 1.9, c[2] + 1.9, maroon, M.CeramicTiles, false)
		box(hall, "ColumnCapital", c[1] - 2.1, c[1] + 2.1, CEILING - 1, CEILING, c[2] - 2.1, c[2] + 2.1, teal, M.CeramicTiles, false)
	end
	-- The barrier line: gate cabinets with paddles you walk through, glass railings either side
	local lineZ = -30
	for k = 0, 8 do
		local x = BRIDGE_X - 28 + k * 7
		box(hall, "GateCabinet", x - 0.6, x + 0.6, HALL, HALL + 3.4, lineZ - 2.5, lineZ + 2.5, rgb(60, 64, 68), M.Metal)
		box(hall, "GateLamp", x - 0.65, x + 0.65, HALL + 3.4, HALL + 3.6, lineZ + 1.2, lineZ + 2.4, rgb(80, 220, 120), M.Neon, false)
		if k < 8 then
			for _, px in { x + 1.9, x + 5.1 } do
				box(hall, "GatePaddle", px - 1.3, px + 1.3, HALL + 1.2, HALL + 3.6, lineZ - 0.15, lineZ + 0.15, roundelRed, M.Glass, false).Transparency = 0.3
			end
		end
	end
	for _, run in { { TX0, BRIDGE_X - 28.6 }, { BRIDGE_X + 28.6, TX1 } } do
		box(hall, "BarrierGlass", run[1], run[2], HALL, HALL + 3.4, lineZ - 0.15, lineZ + 0.15, rgb(180, 200, 204), M.Glass).Transparency = 0.5
		box(hall, "BarrierRail", run[1], run[2], HALL + 3.4, HALL + 3.7, lineZ - 0.25, lineZ + 0.25, stainless, M.Metal, false)
	end
	-- Ticket office windows on the east wall, machines along the south wall
	box(hall, "TicketOffice", TX1 - 6, TX1, HALL, HALL + 9, -24, -6, rgb(92, 64, 48), M.Wood)
	box(hall, "TicketWindows", TX1 - 6.2, TX1 - 6, HALL + 3.6, HALL + 7.2, -22, -8, rgb(60, 72, 76), M.Glass, false)
	box(hall, "TicketCounter", TX1 - 7.4, TX1 - 6, HALL + 3.2, HALL + 3.6, -22, -8, stainless, M.Metal)
	sign(box(hall, "TicketSign", TX1 - 6.3, TX1 - 6, HALL + 7.6, HALL + 8.8, -20, -10, roundelBlue, M.SmoothPlastic, false), Enum.NormalId.Left, "TICKETS", white)
	for k = 0, 3 do
		local x = -165 + k * 7
		box(hall, "TicketMachine", x - 2, x + 2, HALL, HALL + 6.5, TZ1 - 2.2, TZ1, rgb(30, 60, 140), M.SmoothPlastic)
		box(hall, "MachineScreen", x - 1.2, x + 1.2, HALL + 3.6, HALL + 5.4, TZ1 - 2.3, TZ1 - 2.2, rgb(120, 200, 230), M.Neon, false)
	end
	-- The station roundel over the way through to the platforms, and a clock beside it
	roundel(hall, Vector3.new(BRIDGE_X, 1.2, TZ0 + 0.3), "z", 7, "HAFEN MITTE")
	cylinder(hall, "ClockRim", 4.6, 0.3, Vector3.new(BRIDGE_X - 20, 0, TZ0 + 0.2), "z", black, M.Metal, false)
	cylinder(hall, "ClockFace", 4, 0.4, Vector3.new(BRIDGE_X - 20, 0, TZ0 + 0.25), "z", white, M.SmoothPlastic, false)
	box(hall, "ClockHand", BRIDGE_X - 20.1, BRIDGE_X - 19.9, -0.1, 1.6, TZ0 + 0.4, TZ0 + 0.55, black, M.Metal, false)
	box(hall, "ClockHand", BRIDGE_X - 20, BRIDGE_X - 18.8, -0.1, 0.1, TZ0 + 0.4, TZ0 + 0.55, black, M.Metal, false)
	for k, ad in { { "LEUCHTTURM", "Climb the lighthouse at the estuary mouth", rgb(40, 90, 130) }, { "KAI MARKT", "Fresh fish on the quay every morning", rgb(150, 60, 40) }, { "AQUARIUM", "Open daily, five minutes from here", rgb(30, 110, 100) }, { "CHARTER A BOAT", "Day trips from the marina", rgb(180, 130, 40) } } do
		poster(hall, Vector3.new(-316 + (k - 1) * 26, -3.5, TZ1), "z-", ad[1], ad[2], ad[3])
	end
	-- The network map on the west wall
	local mapBoard = box(hall, "NetworkMap", TX0, TX0 + 0.3, -9, 0, -34, -16, white, M.SmoothPlastic, false)
	box(hall, "MapFrame", TX0, TX0 + 0.2, -9.4, 0.4, -34.4, -15.6, black, M.Metal, false)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = mapBoard
	local lines = {
		{ roundelRed, 0.05, 0.42, 0.9, 0.05 },
		{ rgb(0, 120, 60), 0.05, 0.72, 0.7, 0.05 },
		{ roundelBlue, 0.3, 0.08, 0.035, 0.84 },
		{ rgb(250, 190, 0), 0.68, 0.2, 0.035, 0.7 },
	}
	for _, spec in lines do
		local stroke = Instance.new("Frame")
		stroke.BackgroundColor3 = spec[1]
		stroke.BorderSizePixel = 0
		stroke.Position = UDim2.fromScale(spec[2], spec[3])
		stroke.Size = UDim2.fromScale(spec[4], spec[5])
		stroke.Parent = gui
	end
	for _, stop in { { "HAFEN MITTE", 0.33, 0.3 }, { "ALTSTADT", 0.5, 0.3 }, { "RATHAUS", 0.71, 0.3 }, { "KAI WEST", 0.06, 0.3 }, { "MARINA", 0.33, 0.6 }, { "PARK", 0.71, 0.6 }, { "LEUCHTTURM", 0.33, 0.9 } } do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(stop[2], stop[3])
		label.Size = UDim2.fromScale(0.25, 0.1)
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = rgb(20, 30, 60)
		label.TextScaled = true
		label.Text = stop[1]
		label.Parent = gui
	end

	---------------------------------------------------------------------------------------------
	-- Escalators: two moving lanes either side of a fixed stair, with uplighters on the medians

	local escalators = pieceModel(metro, "MetroEscalators", true)
	local drop = surface - HALL
	local run = drop / math.tan(math.rad(30))
	local topX, footX = E.x0, E.x0 + run
	local function lineY(x: number): number
		return surface - (x - topX) * drop / run
	end
	local midZ = (E.z0 + E.z1) / 2
	incline(escalators, "EscalatorTruss", Vector3.new(topX, surface - 1.4, midZ), Vector3.new(footX, HALL - 1.4, midZ), E.z1 - E.z0, 1.2, stainless, M.Metal)
	for _, laneZ in { -4, 10 } do
		-- An invisible ramp carries players; the steps are only for show
		incline(escalators, "EscalatorRamp", Vector3.new(topX, surface + 0.4, laneZ), Vector3.new(footX, HALL + 0.4, laneZ), 6, 1, stainless, M.Metal).Transparency = 1
		for k = 0, 25 do
			local x0, x1 = topX + k * run / 26, topX + (k + 1) * run / 26
			local y = lineY((x0 + x1) / 2) + 0.4
			box(escalators, "EscalatorStep", x0, x1, y - 1.2, y, laneZ - 2.8, laneZ + 2.8, rgb(64, 66, 68), M.DiamondPlate, false)
		end
	end
	local rise, tread = drop / 22, run / 22
	for k = 0, 21 do
		local y = surface - (k + 1) * rise
		box(escalators, "FixedStep", topX + k * tread, topX + (k + 1) * tread, y - 1.6, y, 0, 6, rgb(150, 146, 138), M.Granite)
	end
	for _, z in { -7.5, -0.5, 6.5, 13.5 } do
		local outer = z == -7.5 or z == 13.5
		incline(escalators, "BalustradeDeck", Vector3.new(topX, surface + 1.2, z), Vector3.new(footX, HALL + 1.2, z), 1, 1.8, stainless, M.Metal)
		if outer then
			incline(escalators, "BalustradeGlass", Vector3.new(topX, surface + 4.4, z), Vector3.new(footX, HALL + 4.4, z), 0.3, 3.2, rgb(190, 210, 214), M.Glass).Transparency = 0.45
		else
			-- The bronze uplighters standing on the medians
			for x = topX + 4, footX - 3, 6.5 do
				local y = lineY(x) + 1.2
				rod(escalators, "Uplighter", Vector3.new(x, y, z), Vector3.new(x, y + 2.2, z), 0.35, brass, M.Metal)
				local cap = ball(escalators, "UplighterGlow", 0.9, Vector3.new(x, y + 2.5, z), rgb(255, 226, 170), M.Neon)
				if z == -0.5 and (x == topX + 4 or x + 6.5 > footX - 3) then
					glow(cap, nil, 22, 0.8)
				end
			end
		end
		incline(escalators, "Handrail", Vector3.new(topX, surface + 4.9, z), Vector3.new(footX, HALL + 4.9, z), 0.6, 0.5, black, M.Rubber, false)
	end

	---------------------------------------------------------------------------------------------
	-- The stairwell entrance: two tiled flights with a landing, brass handrails

	local stairs = pieceModel(metro, "MetroStairwell", true)
	local stepRise = drop / 22
	local x, y = S.x0, surface
	local rail = { Vector3.new(x, y + 3, 0) }
	for k = 1, 22 do
		if k == 12 then
			box(stairs, "StairLanding", x, x + 8, y - 1.6, y, S.z0, S.z1, terrazzo, M.Marble)
			table.insert(rail, Vector3.new(x, y + 3, 0))
			x += 8
			table.insert(rail, Vector3.new(x, y + 3, 0))
		end
		y -= stepRise
		box(stairs, "StairStep", x, x + 1.6, y - 1.6, y, S.z0, S.z1, terrazzo, M.Marble)
		x += 1.6
	end
	table.insert(rail, Vector3.new(x, y + 3, 0))
	local stairFoot = x
	box(stairs, "StairWall", S.x0 - 1, stairFoot, HALL, top, S.z0 - 1, S.z0, cream, M.CeramicTiles)
	box(stairs, "StairWall", S.x0 - 1, stairFoot, HALL, top, S.z1, S.z1 + 1, cream, M.CeramicTiles)
	box(stairs, "StairWall", S.x0 - 1, S.x0, HALL, top, S.z0, S.z1, cream, M.CeramicTiles)
	for _, z in { S.z0 + 0.3, S.z1 - 0.3 } do
		for k = 1, #rail - 1 do
			rod(stairs, "StairHandrail", rail[k] + Vector3.new(0, 0, z), rail[k + 1] + Vector3.new(0, 0, z), 0.3, brass, M.Metal)
		end
	end

	---------------------------------------------------------------------------------------------
	-- Entrances on the plaza: a glass canopy over the escalators, railings round both wells

	local entrances = pieceModel(metro, "MetroEntrances")
	local function railing(x0: number, z0: number, x1: number, z1: number)
		local a, b = Vector3.new(x0, surface, z0), Vector3.new(x1, surface, z1)
		local length = (b - a).Magnitude
		local alongX = math.abs(x1 - x0) > math.abs(z1 - z0)
		box(entrances, "RailingBars", math.min(x0, x1) - (if alongX then 0 else 0.1), math.max(x0, x1) + (if alongX then 0 else 0.1), surface, surface + 3.6, math.min(z0, z1) - (if alongX then 0.1 else 0), math.max(z0, z1) + (if alongX then 0.1 else 0), ironwork, M.Metal).Transparency = 0.55
		rod(entrances, "RailingTop", a + Vector3.new(0, 3.7, 0), b + Vector3.new(0, 3.7, 0), 0.35, ironwork, M.Metal)
		local posts = math.max(1, math.round(length / 6))
		for k = 0, posts do
			local p = a:Lerp(b, k / posts)
			part(entrances, "RailingPost", Vector3.new(0.45, 4, 0.45), p + Vector3.new(0, 2, 0), ironwork, M.Metal)
			ball(entrances, "RailingFinial", 0.7, p + Vector3.new(0, 4.2, 0), brass, M.Metal)
		end
	end
	railing(E.x0, E.z0 - 0.5, E.x1 + 0.5, E.z0 - 0.5)
	railing(E.x0, E.z1 + 0.5, E.x1 + 0.5, E.z1 + 0.5)
	railing(E.x1 + 0.5, E.z0 - 0.5, E.x1 + 0.5, E.z1 + 0.5)
	railing(S.x0, S.z0 - 0.5, S.x1 + 0.5, S.z0 - 0.5)
	railing(S.x0, S.z1 + 0.5, S.x1 + 0.5, S.z1 + 0.5)
	railing(S.x1 + 0.5, S.z0 - 0.5, S.x1 + 0.5, S.z1 + 0.5)
	local cx0, cx1, cz0, cz1 = E.x0 - 12, E.x1 + 2, E.z0 - 4, E.z1 + 4
	for _, corner in { { cx0 + 1, cz0 + 1 }, { cx0 + 1, cz1 - 1 }, { cx1 - 1, cz0 + 1 }, { cx1 - 1, cz1 - 1 } } do
		part(entrances, "CanopyColumn", Vector3.new(0.9, 12, 0.9), Vector3.new(corner[1], surface + 6, corner[2]), ironwork, M.Metal)
	end
	box(entrances, "CanopyGlass", cx0, cx1, surface + 12, surface + 12.3, cz0, cz1, rgb(170, 196, 204), M.Glass, false).Transparency = 0.45
	for _, edge in { { cx0, cx1, cz0, cz0 + 0.6 }, { cx0, cx1, cz1 - 0.6, cz1 }, { cx0, cx0 + 0.6, cz0, cz1 }, { cx1 - 0.6, cx1, cz0, cz1 } } do
		box(entrances, "CanopyFrame", edge[1], edge[2], surface + 11.6, surface + 12.6, edge[3], edge[4], ironwork, M.Metal, false)
	end
	sign(box(entrances, "CanopyFascia", cx0 - 0.4, cx0, surface + 10.2, surface + 11.6, cz0 + 3, cz1 - 3, roundelBlue, M.SmoothPlastic, false), Enum.NormalId.Left, "HAFEN MITTE", white)
	rod(entrances, "RoundelPost", Vector3.new(cx0 + 4, surface + 12.6, midZ), Vector3.new(cx0 + 4, surface + 14.4, midZ), 0.5, ironwork, M.Metal)
	roundel(entrances, Vector3.new(cx0 + 4, surface + 18, midZ), "x", 7.5, "METRO")
	-- The classic roundel on a post beside the stairwell
	part(entrances, "SignPost", Vector3.new(0.5, 10, 0.5), Vector3.new(S.x0 - 3, surface + 5, S.z0 - 3), ironwork, M.Metal)
	roundel(entrances, Vector3.new(S.x0 - 3, surface + 12, S.z0 - 3), "x", 4.2, "METRO")

	---------------------------------------------------------------------------------------------
	-- Platform hall: a tiled vault on iron ribs, with tunnel mouths at both ends

	local vault = pieceModel(metro, "MetroVault", true)
	box(vault, "VaultBase", VX0 - 2, VX1 + 2, BASE - 2, BASE, VZ0 - 2, VZ1 + 2, rgb(70, 68, 64), M.Concrete)
	box(vault, "TrackBed", VX0 - 2, VX1 + 2, BASE, BED, NORTH_EDGE, SOUTH_EDGE, rgb(58, 56, 54), M.Concrete)
	box(vault, "VaultWall", VX0 - 2, VX1 + 2, BASE, SPRING, VZ0 - 2, VZ0, cream, M.CeramicTiles)
	box(vault, "VaultWall", VX0 - 2, BRIDGE_X - 6, BASE, SPRING, VZ1, VZ1 + 2, cream, M.CeramicTiles)
	box(vault, "VaultWall", BRIDGE_X + 6, VX1 + 2, BASE, SPRING, VZ1, VZ1 + 2, cream, M.CeramicTiles)
	box(vault, "VaultWall", BRIDGE_X - 6, BRIDGE_X + 6, BASE, HALL - 1.5, VZ1, VZ1 + 2, cream, M.CeramicTiles)
	box(vault, "VaultWall", BRIDGE_X - 6, BRIDGE_X + 6, HALL + 9, SPRING, VZ1, VZ1 + 2, cream, M.CeramicTiles)
	-- A segmental arch from wall to wall
	local half, archZ, archRise = (VZ1 - VZ0) / 2, (VZ0 + VZ1) / 2, CROWN - SPRING
	local radius = (half * half + archRise * archRise) / (2 * archRise)
	local centreY = CROWN - radius
	local sweep = math.asin(half / radius)
	local function arc(t: number): (number, number)
		local angle = -sweep + 2 * sweep * t
		return archZ + radius * math.sin(angle), centreY + radius * math.cos(angle)
	end
	local function arcPiece(into: Instance, name: string, k: number, x: number, length: number, thickness: number, inset: number, color: Color3, material: Enum.Material, collide: boolean)
		local z0, y0 = arc(k / SEGMENTS)
		local z1, y1 = arc((k + 1) / SEGMENTS)
		local mid = Vector3.new(x, (y0 + y1) / 2, (z0 + z1) / 2)
		local normal = Vector3.new(0, mid.Y - centreY, mid.Z - archZ).Unit
		local span = math.sqrt((z1 - z0) ^ 2 + (y1 - y0) ^ 2)
		local p = part(into, name, Vector3.new(length, thickness, span + 0.3), mid, color, material, collide)
		p.CFrame = CFrame.fromMatrix(origin + mid + normal * inset, Vector3.xAxis, normal)
	end
	for k = 0, SEGMENTS - 1 do
		arcPiece(vault, "VaultPanel", k, (VX0 + VX1) / 2, VX1 - VX0 + 4, 1, 0.5, cream, M.CeramicTiles, true)
	end
	for _, rx in RIBS do
		for k = 0, SEGMENTS - 1 do
			arcPiece(vault, "VaultRib", k, rx, 1.6, 1.2, -0.6, teal, M.Metal, false)
		end
		box(vault, "RibPilaster", rx - 0.8, rx + 0.8, PLATFORM, SPRING, VZ0, VZ0 + 0.6, teal, M.Metal, false)
		if rx ~= BRIDGE_X then
			box(vault, "RibPilaster", rx - 0.8, rx + 0.8, PLATFORM, SPRING, VZ1 - 0.6, VZ1, teal, M.Metal, false)
			-- Globe lamps hang from the ribs over the tracks
			rod(vault, "LampChain", Vector3.new(rx, CROWN - 0.6, archZ), Vector3.new(rx, -12, archZ), 0.25, ironwork, M.Metal)
			glow(ball(vault, "GlobeLamp", 2.6, Vector3.new(rx, -13.3, archZ), rgb(255, 236, 196), M.Neon), nil, 36, 0.9)
		end
	end
	-- End walls, open at each track into a dark tunnel mouth
	local portals = { { NORTH_EDGE, NORTH_EDGE + 11 }, { SOUTH_EDGE - 11, SOUTH_EDGE } }
	for _, ends in { { VX0 - 2, VX0, -1 }, { VX1, VX1 + 2, 1 } } do
		local x0, x1, outward = ends[1], ends[2], ends[3]
		local inner = if outward < 0 then x1 else x0
		box(vault, "EndWall", x0, x1, BASE, CROWN + 1, VZ0 - 2, NORTH_EDGE, cream, M.CeramicTiles)
		box(vault, "EndWall", x0, x1, BASE, CROWN + 1, NORTH_EDGE + 11, SOUTH_EDGE - 11, cream, M.CeramicTiles)
		box(vault, "EndWall", x0, x1, BASE, CROWN + 1, SOUTH_EDGE, VZ1 + 2, cream, M.CeramicTiles)
		for index, portal in portals do
			box(vault, "EndWall", x0, x1, BED + 14, CROWN + 1, portal[1], portal[2], cream, M.CeramicTiles)
			local back = if outward < 0 then x0 - 4 else x1 + 4
			box(vault, "TunnelMouth", math.min(back, if outward < 0 then x0 else x1), math.max(back, if outward < 0 then x0 else x1), BED, BED + 14, portal[1], portal[2], rgb(6, 6, 8), M.SmoothPlastic)
			box(vault, "PortalBand", inner - 0.3, inner + 0.3, BED + 14, BED + 15.6, portal[1] - 1, portal[2] + 1, maroon, M.CeramicTiles, false)
			local lamp = if (index == 1) == (outward < 0) then rgb(230, 40, 30) else rgb(40, 220, 90)
			box(vault, "SignalLamp", inner - 0.4, inner + 0.4, BED + 9, BED + 10, portal[2] + 1.5, portal[2] + 2.5, lamp, M.Neon, false)
		end
	end

	---------------------------------------------------------------------------------------------
	-- Platforms: edge coping, MIND THE GAP, tiled walls with roundels, posters and benches

	local platforms = pieceModel(metro, "MetroPlatforms", true)
	local ads = {
		{ "HAFEN MITTE", "Change here for the marina", roundelBlue },
		{ "KAI MARKT", "Fresh fish every morning", rgb(150, 60, 40) },
		{ "LEUCHTTURM", "The best view of the estuary", rgb(40, 90, 130) },
	}
	for index, spec in { { VZ0, NORTH_EDGE, 1, { -362, -267, -138 }, { -335, -301, -165 }, { -245, -207 } }, { SOUTH_EDGE, VZ1, -1, { -362, -233, -138 }, { -335, -199, -165 }, { -293, -243 } } } do
		local z0, z1, toward = spec[1], spec[2], spec[3]
		local edge = if toward > 0 then z1 else z0
		local wall = if toward > 0 then z0 else z1
		local facing = if toward > 0 then "z+" else "z-"
		box(platforms, "Platform", VX0, VX1, BASE, PLATFORM, z0, z1, rgb(88, 88, 86), M.Concrete)
		local function band(name: string, from: number, to: number, color: Color3, material: Enum.Material, height: number): Part
			local a, b = edge - toward * from, edge - toward * to
			return box(platforms, name, VX0, VX1, PLATFORM, PLATFORM + height, math.min(a, b), math.max(a, b), color, material, false)
		end
		band("PlatformCoping", 0, 1.6, rgb(196, 192, 182), M.Concrete, 0.12)
		band("YellowLine", 2.0, 2.4, rgb(232, 196, 40), M.SmoothPlastic, 0.14)
		band("TactilePaving", 2.6, 4.2, rgb(206, 186, 120), M.Pebble, 0.1)
		for _, gx in { -330, -190, -150 } do
			local a, b = edge - toward * 0.1, edge - toward * 1.5
			sign(box(platforms, "MindTheGap", gx - 6, gx + 6, PLATFORM, PLATFORM + 0.16, math.min(a, b), math.max(a, b), rgb(196, 192, 182), M.Concrete, false), Enum.NormalId.Top, "MIND THE GAP", white)
		end
		local function onWall(name: string, x0: number, x1: number, y0: number, y1: number, depth: number, color: Color3, material: Enum.Material): Part
			local a, b = wall, wall + toward * depth
			return box(platforms, name, x0, x1, y0, y1, math.min(a, b), math.max(a, b), color, material, false)
		end
		onWall("DadoTiles", VX0, VX1, PLATFORM, PLATFORM + 3.5, 0.2, maroon, M.CeramicTiles)
		onWall("FriezeTiles", VX0, VX1, -17, -15.6, 0.2, teal, M.CeramicTiles)
		-- Light troughs along the wall, broken where the stair from the bridge comes down
		local gap = spec[6]
		for _, run in { { VX0, gap[1] }, { gap[2], VX1 } } do
			onWall("LightTrough", run[1], run[2], -13.5, -12.5, 2.2, rgb(40, 70, 64), M.Metal)
			glow(onWall("LightTube", run[1], run[2], -13.9, -13.5, 1.6, rgb(255, 244, 220), M.Neon), Enum.NormalId.Bottom, 22, 1)
		end
		for _, rx in spec[5] do
			roundel(platforms, Vector3.new(rx, -26, wall + toward * 0.4), "z", 8, "HAFEN MITTE")
		end
		for k, px in spec[4] do
			local ad = ads[(k + index) % #ads + 1]
			poster(platforms, Vector3.new(px, -25, wall + toward * 0.2), facing, ad[1], ad[2], ad[3])
		end
		for _, bx in { -335, -165, if toward > 0 then -301 else -199 } do
			bench(platforms, bx, PLATFORM, wall + toward * 1.4, true, -toward)
		end
		-- A next-train indicator hanging over the platform
		local pz = (z0 + z1) / 2
		local _, archY = arc(math.clamp((pz - VZ0) / (VZ1 - VZ0), 0, 1))
		rod(platforms, "IndicatorRod", Vector3.new(-318, -18, pz), Vector3.new(-318, archY, pz), 0.25, ironwork, M.Metal)
		local board = box(platforms, "TrainIndicator", -323, -313, -21.4, -18.6, pz - 0.3, pz + 0.3, black, M.Metal, false)
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			sign(board, face, if toward > 0 then "1  KAI WEST      2 min" else "1  ALTSTADT      4 min", rgb(255, 170, 40), Enum.Font.Code)
		end
	end

	-- Tracks: sleepers, running rails and the two conductor rails
	local tracks = pieceModel(metro, "MetroTracks", true)
	for _, tz in TRACKS do
		box(tracks, "DrainPit", VX0 - 2, VX1 + 2, BED, BED + 0.02, tz - 1.8, tz + 1.8, rgb(28, 28, 28), M.SmoothPlastic, false)
		for sx = VX0 + 2, VX1 - 2, 8 do
			box(tracks, "Sleeper", sx - 0.6, sx + 0.6, BED, BED + 0.5, tz - 3.6, tz + 3.6, rgb(74, 66, 58), M.Wood, false)
		end
		for _, dz in { -2.4, 2.4 } do
			box(tracks, "Rail", VX0 - 2, VX1 + 2, BED + 0.5, BED + 1.1, tz + dz - 0.25, tz + dz + 0.25, rgb(140, 136, 130), M.Metal, false)
		end
		box(tracks, "ConductorRail", VX0 - 2, VX1 + 2, BED + 0.5, BED + 1, tz - 0.25, tz + 0.25, rgb(110, 110, 106), M.Metal, false)
		box(tracks, "ConductorRail", VX0 - 2, VX1 + 2, BED + 0.8, BED + 1.3, tz + 3.65, tz + 4.15, rgb(110, 110, 106), M.Metal, false)
	end

	---------------------------------------------------------------------------------------------
	-- The footbridge over the tracks, and the stairs down to each platform

	local bridge = pieceModel(metro, "MetroBridge", true)
	box(bridge, "BridgeDeck", BRIDGE_X - 6, BRIDGE_X + 6, HALL - 1.5, HALL, VZ0, VZ1 + 2, terrazzo, M.Marble)
	for _, side in { -1, 1 } do
		local gx = BRIDGE_X + side * 6
		box(bridge, "BridgeGirder", gx - 0.4, gx + 0.4, HALL - 3, HALL - 0.2, VZ0, VZ1, teal, M.Metal)
		-- Parapets, open where each stair leaves the bridge
		local z0, z1 = if side < 0 then VZ0 else VZ0 + 8, if side < 0 then VZ1 - 8 else VZ1
		box(bridge, "BridgeParapet", gx - 0.15, gx + 0.15, HALL, HALL + 3.4, z0, z1, rgb(180, 200, 204), M.Glass).Transparency = 0.45
		box(bridge, "ParapetRail", gx - 0.3, gx + 0.3, HALL + 3.4, HALL + 3.8, z0, z1, teal, M.Metal, false)
	end
	for _, dx in { -3, 3 } do
		box(bridge, "BridgeColumn", BRIDGE_X + dx - 0.6, BRIDGE_X + dx + 0.6, BED, HALL - 3, archZ - 0.6, archZ + 0.6, teal, M.Metal)
	end
	cylinder(bridge, "ClockRim", 5.4, 0.5, Vector3.new(BRIDGE_X, -17, archZ), "x", black, M.Metal, false)
	cylinder(bridge, "ClockFace", 4.8, 0.6, Vector3.new(BRIDGE_X, -17, archZ), "x", white, M.SmoothPlastic, false)
	box(bridge, "ClockHand", BRIDGE_X - 0.4, BRIDGE_X + 0.4, -17.1, -15.2, archZ - 0.1, archZ + 0.1, black, M.Metal, false)
	box(bridge, "ClockHand", BRIDGE_X - 0.4, BRIDGE_X + 0.4, -17.1, -16.9, archZ, archZ + 1.4, black, M.Metal, false)
	box(bridge, "ClockHanger", BRIDGE_X - 0.2, BRIDGE_X + 0.2, -14.3, HALL - 1.5, archZ - 0.2, archZ + 0.2, ironwork, M.Metal, false)
	local function bridgeStair(direction: number, z0: number, z1: number, startX: number, openZ: number)
		for k = 0, 21 do
			local xa, xb = startX + direction * k * 1.6, startX + direction * (k + 1) * 1.6
			local stepTop = HALL - (k + 1)
			box(bridge, "BridgeStep", math.min(xa, xb), math.max(xa, xb), stepTop - 1.4, stepTop, z0, z1, terrazzo, M.Marble)
		end
		local foot = startX + direction * 22 * 1.6
		local zm = (z0 + z1) / 2
		incline(bridge, "StairSoffit", Vector3.new(startX, HALL - 1.4, zm), Vector3.new(foot, PLATFORM - 1.4, zm), z1 - z0, 1, cream, M.CeramicTiles)
		incline(bridge, "StairBalustrade", Vector3.new(startX, HALL + 3.4, openZ), Vector3.new(foot, PLATFORM + 3.4, openZ), 0.3, 3.6, rgb(180, 200, 204), M.Glass).Transparency = 0.45
		for _, z in { openZ, if openZ == z0 then z1 - 0.3 else z0 + 0.3 } do
			rod(bridge, "StairHandrail", Vector3.new(startX, HALL + 3.6, z), Vector3.new(foot, PLATFORM + 3.6, z), 0.3, brass, M.Metal)
		end
	end
	bridgeStair(-1, VZ1 - 8, VZ1, BRIDGE_X - 6, VZ1 - 8)
	bridgeStair(1, VZ0, VZ0 + 8, BRIDGE_X + 6, VZ0 + 8)

	---------------------------------------------------------------------------------------------
	-- A three-car train waiting at the north platform

	local train = pieceModel(metro, "MetroTrain", true)
	local tz = TRACKS[1]
	for car = 0, 2 do
		local x0 = -330 + car * 54
		local x1 = x0 + 52
		box(train, "CarBody", x0, x1, BED + 1.6, BED + 10.6, tz - 4.5, tz + 4.5, rgb(236, 236, 232), M.SmoothPlastic)
		box(train, "CarSkirt", x0 - 0.1, x1 + 0.1, BED + 1, BED + 2.6, tz - 4.6, tz + 4.6, roundelBlue, M.SmoothPlastic, false)
		box(train, "CarWindows", x0 + 1, x1 - 1, BED + 5.6, BED + 8.6, tz - 4.6, tz + 4.6, rgb(40, 48, 56), M.Glass, false)
		cylinder(train, "CarRoof", 8.6, 52, Vector3.new((x0 + x1) / 2, BED + 10.4, tz), "x", rgb(196, 198, 200), M.SmoothPlastic)
		for d = 0, 3 do
			local dx = x0 + 6 + d * 13.3
			box(train, "CarDoors", dx - 1.6, dx + 1.6, BED + 2.2, BED + 9.6, tz - 4.65, tz + 4.65, roundelRed, M.SmoothPlastic, false)
		end
		for _, bx in { x0 + 8, x1 - 8 } do
			box(train, "Bogie", bx - 4, bx + 4, BED + 0.6, BED + 1.8, tz - 3, tz + 3, black, M.Metal, false)
		end
	end
	for _, cab in { { -330.3, -330 }, { -170, -169.7 } } do
		box(train, "CabWindscreen", cab[1], cab[2], BED + 5.6, BED + 9, tz - 3.4, tz + 3.4, rgb(30, 36, 42), M.Glass, false)
		for _, dz in { -3, 3 } do
			box(train, "Headlight", cab[1], cab[2], BED + 3, BED + 3.8, tz + dz - 0.5, tz + dz + 0.5, rgb(255, 240, 200), M.Neon, false)
		end
	end

	---------------------------------------------------------------------------------------------
	-- Street furniture on the plaza

	local west = pieceModel(metro, "PlazaWest")
	local east = pieceModel(metro, "PlazaEast")
	local function planter(into: Instance, px: number, pz: number, seed: number)
		part(into, "Planter", Vector3.new(10, 2, 10), Vector3.new(px, surface + 1, pz), rgb(170, 162, 146), M.Granite)
		part(into, "PlanterSoil", Vector3.new(9, 0.2, 9), Vector3.new(px, surface + 2.05, pz), rgb(70, 56, 44), M.Ground, false)
		part(into, "TreeTrunk", Vector3.new(1.4, 10, 1.4), Vector3.new(px, surface + 7, pz), rgb(88, 70, 54), M.Wood)
		local crown = part(into, "TreeCrown", Vector3.one * 13, Vector3.new(px, surface + 15, pz), LEAVES[seed % #LEAVES + 1], M.Grass, false)
		crown.Shape = Enum.PartType.Ball
	end
	local function streetLamp(into: Instance, px: number, pz: number, lit: boolean)
		part(into, "LampBase", Vector3.new(1.2, 1.6, 1.2), Vector3.new(px, surface + 0.8, pz), ironwork, M.Metal)
		part(into, "LampPost", Vector3.new(0.5, 11, 0.5), Vector3.new(px, surface + 6.5, pz), ironwork, M.Metal)
		local lantern = part(into, "Lantern", Vector3.new(1.4, 2, 1.4), Vector3.new(px, surface + 13, pz), rgb(255, 232, 180), M.Neon, false)
		part(into, "LanternCap", Vector3.new(1.9, 0.5, 1.9), Vector3.new(px, surface + 14.2, pz), ironwork, M.Metal, false)
		if lit then
			glow(lantern, nil, 26, 0.9)
		end
	end
	local function bollards(into: Instance, x0: number, x1: number)
		for bx = x0, x1, 13 do
			cylinder(into, "Bollard", 1, 3, Vector3.new(bx, surface + 1.5, forecourt[4] - 1.2), "y", ironwork, M.Metal)
		end
	end
	local function bin(into: Instance, px: number, pz: number)
		cylinder(into, "LitterBin", 2, 3.2, Vector3.new(px, surface + 1.6, pz), "y", black, M.Metal)
	end

	-- West: bus stops, phone boxes, the post box, hire bikes, trees and a flower stall
	for _, sx in { -366, -342 } do
		part(west, "ShelterRoof", Vector3.new(12, 0.5, 5), Vector3.new(sx, surface + 8, 25.5), rgb(70, 76, 78), M.Metal)
		part(west, "ShelterGlass", Vector3.new(12, 6.5, 0.3), Vector3.new(sx, surface + 4, 23.2), rgb(160, 180, 186), M.Glass).Transparency = 0.5
		for _, dx in { -5.6, 5.6 } do
			part(west, "ShelterPost", Vector3.new(0.4, 8, 0.4), Vector3.new(sx + dx, surface + 4, 23.2), rgb(70, 76, 78), M.Metal)
		end
		part(west, "BusStopPole", Vector3.new(0.35, 10, 0.35), Vector3.new(sx + 8, surface + 5, 28.5), rgb(70, 76, 78), M.Metal)
		roundel(west, Vector3.new(sx + 8, surface + 10.5, 28.5), "z", 2.6, "BUS")
	end
	for k, pz in { 8, 13 } do
		local px = -376
		part(west, "PhoneBox", Vector3.new(3.4, 8, 3.4), Vector3.new(px, surface + 4, pz), rgb(196, 28, 32), M.SmoothPlastic)
		part(west, "PhoneBoxPanes", Vector3.new(3.5, 5, 3.5), Vector3.new(px, surface + 4.2, pz), rgb(52, 60, 62), M.Glass, false).Transparency = 0.25
		local band = part(west, "PhoneBoxSign", Vector3.new(3.6, 0.6, 3.6), Vector3.new(px, surface + 7.2, pz), white, M.SmoothPlastic, false)
		sign(band, Enum.NormalId.Right, "TELEPHONE", black)
		part(west, "PhoneBoxCrown", Vector3.new(3.9, 0.7, 3.9), Vector3.new(px, surface + 8.3, pz), rgb(196, 28, 32), M.SmoothPlastic, false)
		if k == 1 then
			cylinder(west, "PillarBox", 2.2, 5, Vector3.new(px, surface + 2.5, pz - 9), "y", rgb(196, 28, 32), M.SmoothPlastic)
			cylinder(west, "PillarBoxCap", 2.6, 0.7, Vector3.new(px, surface + 5.3, pz - 9), "y", rgb(196, 28, 32), M.SmoothPlastic, false)
			cylinder(west, "PillarBoxBase", 2.4, 0.6, Vector3.new(px, surface + 0.3, pz - 9), "y", black, M.SmoothPlastic, false)
		end
	end
	local dockX = -373
	part(west, "BikeDockRail", Vector3.new(0.4, 0.6, 26), Vector3.new(dockX, surface + 0.3, -75), rgb(60, 64, 66), M.Metal)
	part(west, "BikeTerminal", Vector3.new(1.4, 6, 2.4), Vector3.new(dockX, surface + 3, -91), roundelRed, M.SmoothPlastic)
	for k = 0, 5 do
		local bz = -85 + k * 4
		for _, dx in { 1.6, 5.2 } do
			cylinder(west, "BikeWheel", 2.6, 0.3, Vector3.new(dockX + dx, surface + 1.3, bz), "z", black, M.Rubber, false)
		end
		part(west, "BikeFrame", Vector3.new(4, 0.9, 0.4), Vector3.new(dockX + 3.4, surface + 2.2, bz), roundelRed, M.Metal, false)
	end
	for k, spot in { { -365, -106 }, { -365, -40 }, { -290, -104 } } do
		planter(west, spot[1], spot[2], k)
	end
	bench(west, -365, surface, -52, true, -1)
	bench(west, -350, surface, -106, false, -1)
	bench(west, -290, surface, -93, true, -1)
	for _, spot in { { -378, -50 }, { -345, 20 }, { -300, -30 }, { -350, -112 } } do
		streetLamp(west, spot[1], spot[2], spot[2] > 0)
	end
	-- Flower stall
	part(west, "FlowerCart", Vector3.new(6, 3, 3), Vector3.new(-300, surface + 1.5, 24), rgb(36, 74, 52), M.Wood)
	part(west, "UmbrellaPole", Vector3.new(0.3, 7, 0.3), Vector3.new(-300, surface + 3.5, 24), ironwork, M.Metal, false)
	cylinder(west, "Umbrella", 8, 0.4, Vector3.new(-300, surface + 7.2, 24), "y", rgb(232, 222, 196), M.Fabric, false)
	for k, color in { rgb(220, 60, 80), rgb(250, 200, 60), rgb(240, 240, 230), rgb(150, 80, 170), rgb(240, 120, 50) } do
		ball(west, "Flowers", 1.6, Vector3.new(-302.4 + k * 0.8, surface + 3.6, 24 + (k % 2 - 0.5)), color, M.Fabric)
	end
	-- Pillar clock and fingerpost
	part(west, "ClockPillar", Vector3.new(0.9, 11, 0.9), Vector3.new(-288, surface + 5.5, -24), ironwork, M.Metal)
	cylinder(west, "StreetClock", 3.4, 1.2, Vector3.new(-288, surface + 12, -24), "z", ironwork, M.Metal, false)
	cylinder(west, "StreetClockFace", 2.8, 1.3, Vector3.new(-288, surface + 12, -24), "z", white, M.SmoothPlastic, false)
	part(west, "StreetClockHands", Vector3.new(0.15, 1.2, 1.4), Vector3.new(-288, surface + 12.4, -24), black, M.Metal, false)
	part(west, "FingerPost", Vector3.new(0.5, 9, 0.5), Vector3.new(-345, surface + 4.5, -24), ironwork, M.Metal)
	for k, finger in { { "HAFEN", 1 }, { "ALTSTADT", -1 }, { "MARINA", 1 } } do
		local board = part(west, "Finger", Vector3.new(5, 0.9, 0.2), Vector3.new(-345 + finger[2] * 2.6, surface + 6 + k * 1.1, -24), white, M.SmoothPlastic, false)
		sign(board, Enum.NormalId.Front, finger[1], black)
		sign(board, Enum.NormalId.Back, finger[1], black)
	end
	bin(west, -352, -30)
	bin(west, -282, 18)
	bollards(west, -380, -253)
	-- A café terrace and street trees round the arrival point
	for k, spot in { { -298, -12 }, { -284, -12 }, { -298, 0 }, { -284, 0 } } do
		cylinder(west, "CafeTable", 3, 0.3, Vector3.new(spot[1], surface + 2.6, spot[2]), "y", white, M.Metal)
		part(west, "CafeTableLeg", Vector3.new(0.3, 2.5, 0.3), Vector3.new(spot[1], surface + 1.25, spot[2]), ironwork, M.Metal)
		cylinder(west, "CafeParasol", 7, 0.3, Vector3.new(spot[1], surface + 7.5, spot[2]), "y", if k % 2 == 0 then rgb(36, 74, 52) else rgb(232, 222, 196), M.Fabric, false)
		part(west, "ParasolPole", Vector3.new(0.25, 5, 0.25), Vector3.new(spot[1], surface + 5.1, spot[2]), ironwork, M.Metal, false)
		for _, dx in { -2.6, 2.6 } do
			part(west, "CafeChair", Vector3.new(1.4, 1.8, 1.4), Vector3.new(spot[1] + dx, surface + 0.9, spot[2]), ironwork, M.Metal)
		end
	end
	part(west, "CafeKiosk", Vector3.new(8, 8, 6), Vector3.new(-306, surface + 4, -12), rgb(84, 60, 44), M.Wood)
	sign(part(west, "CafeSign", Vector3.new(0.2, 1.2, 6), Vector3.new(-301.9, surface + 7, -12), rgb(36, 74, 52), M.SmoothPlastic, false), Enum.NormalId.Right, "KAFFEE", white)
	for k, spot in { { -292, 16 }, { -270, 16 }, { -270, -22 }, { -190, 8 } } do
		part(west, "TreeGrate", Vector3.new(3.4, 0.1, 3.4), Vector3.new(spot[1], surface + 0.05, spot[2]), ironwork, M.Metal, false)
		part(west, "TreeTrunk", Vector3.new(1.2, 9, 1.2), Vector3.new(spot[1], surface + 4.5, spot[2]), rgb(88, 70, 54), M.Wood)
		local crown = part(west, "TreeCrown", Vector3.one * 11, Vector3.new(spot[1], surface + 12.5, spot[2]), LEAVES[k % #LEAVES + 1], M.Grass, false)
		crown.Shape = Enum.PartType.Ball
	end
	-- A wayfinding totem by the arrival point, with the area map on both faces
	local totem = part(west, "Wayfinding", Vector3.new(0.6, 8, 3), Vector3.new(-264, surface + 4, -6), rgb(40, 44, 48), M.Metal)
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		sign(totem, face, "HAFEN MITTE\n\nMETRO  ↓\nMARINA  ↑\nALTSTADT  →\nKAI WEST  ←", white)
	end

	-- East: fountain, statue, taxi rank, news kiosk, coffee cart, trees and lamps
	local fx, fz = -160, -14
	cylinder(east, "FountainBasin", 22, 2.4, Vector3.new(fx, surface + 1.2, fz), "y", rgb(176, 168, 150), M.Granite)
	cylinder(east, "FountainWater", 20.4, 0.3, Vector3.new(fx, surface + 2.15, fz), "y", rgb(70, 130, 150), M.Glass, false).Transparency = 0.25
	cylinder(east, "FountainPedestal", 3, 6, Vector3.new(fx, surface + 3, fz), "y", rgb(176, 168, 150), M.Granite)
	cylinder(east, "FountainBowl", 8, 0.8, Vector3.new(fx, surface + 6.2, fz), "y", rgb(176, 168, 150), M.Granite, false)
	cylinder(east, "FountainJet", 1, 4, Vector3.new(fx, surface + 8.6, fz), "y", rgb(200, 230, 240), M.Glass, false).Transparency = 0.4
	bench(east, fx - 18, surface, fz, false, -1)
	bench(east, fx + 18, surface, fz, false, 1)
	bench(east, fx, surface, fz - 18, true, -1)
	-- A bronze fisherman on his plinth
	part(east, "StatuePlinth", Vector3.new(6, 7, 6), Vector3.new(-160, surface + 3.5, -64), rgb(150, 144, 134), M.Granite)
	part(east, "StatueBody", Vector3.new(2.6, 6, 1.8), Vector3.new(-160, surface + 10, -64), rgb(84, 110, 92), M.CorrodedMetal)
	ball(east, "StatueHead", 1.8, Vector3.new(-160, surface + 13.9, -64), rgb(84, 110, 92), M.CorrodedMetal)
	rod(east, "StatueRod", Vector3.new(-158.6, surface + 11, -64), Vector3.new(-154, surface + 17, -66), 0.25, rgb(84, 110, 92), M.CorrodedMetal)
	for k, tx in { -170, -153, -136 } do
		part(east, "BlackCab", Vector3.new(13, 2.8, 6), Vector3.new(tx, surface + 1.8, 25), rgb(18, 18, 20), M.SmoothPlastic)
		part(east, "CabCabin", Vector3.new(7.5, 2.6, 5.6), Vector3.new(tx + 0.5, surface + 4.5, 25), rgb(26, 28, 30), M.Glass, false)
		part(east, "TaxiLight", Vector3.new(1.4, 0.5, 0.8), Vector3.new(tx + 0.5, surface + 6.05, 25), rgb(255, 200, 60), M.Neon, false)
		if k == 1 then
			part(east, "TaxiRankSign", Vector3.new(0.3, 8, 0.3), Vector3.new(tx - 8, surface + 4, 21.5), rgb(70, 76, 78), M.Metal)
		end
	end
	part(east, "NewsKiosk", Vector3.new(7, 7.5, 5), Vector3.new(-197, surface + 3.75, 24), rgb(30, 70, 52), M.Wood)
	part(east, "KioskAwning", Vector3.new(7.6, 0.3, 2.4), Vector3.new(-197, surface + 6.5, 21.4), rgb(176, 40, 40), M.Fabric, false)
	sign(part(east, "KioskSign", Vector3.new(6, 1, 0.2), Vector3.new(-197, surface + 7.1, 21.4), white, M.SmoothPlastic, false), Enum.NormalId.Front, "NEWS", black)
	part(east, "Magazines", Vector3.new(6, 1.6, 0.6), Vector3.new(-197, surface + 2.6, 21.2), rgb(200, 120, 60), M.SmoothPlastic, false)
	part(east, "CoffeeCart", Vector3.new(5, 3.6, 2.6), Vector3.new(-186, surface + 1.8, -32), rgb(90, 56, 40), M.Wood)
	part(east, "CoffeePole", Vector3.new(0.3, 6, 0.3), Vector3.new(-186, surface + 3, -32), ironwork, M.Metal, false)
	cylinder(east, "CoffeeUmbrella", 6, 0.4, Vector3.new(-186, surface + 6.2, -32), "y", rgb(150, 40, 44), M.Fabric, false)
	for k, spot in { { -130, -106 }, { -200, -104 }, { -128, -50 } } do
		planter(east, spot[1], spot[2], k + 1)
	end
	for _, spot in { { -204, -26 }, { -122, 4 }, { -150, -96 }, { -240, 28 } } do
		streetLamp(east, spot[1], spot[2], spot[1] > -160)
	end
	bin(east, -176, 4)
	bin(east, -140, -40)
	bollards(east, -240, -117)
	CityMetro.ensureSurfaces(metro, origin)
end

return CityMetro
