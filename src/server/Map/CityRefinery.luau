-- An oil refinery on the western hinterland, set back behind the container terminal: a tank
-- farm inside its bund walls, LPG spheres, the distillation and cracking units with their
-- columns and furnace stacks, a pipe rack tying it all together, a tanker loading gantry,
-- a flare stack and a fenced yard. Positions are relative to the city centre; north is -Z.
local CityBuildings = require(script.Parent.CityBuildings)

local CityRefinery = {}

-- The fenced site, and the gate its access road leaves from (south side)
CityRefinery.SITE = { x0 = -1390, x1 = -1070, z0 = -1010, z1 = -610 }
CityRefinery.GATE_X = -1240

local rgb = Color3.fromRGB
local M = Enum.Material
local concrete = rgb(118, 116, 110)
local steel = rgb(122, 120, 112)
local galvanised = rgb(158, 160, 156)
local tankWhite = rgb(206, 206, 198)
local dark = rgb(44, 50, 54)
local safety = rgb(206, 166, 50)
local red = rgb(172, 54, 44)
local white = rgb(226, 226, 220)
local PIPES = { rgb(150, 152, 148), rgb(196, 190, 170), rgb(132, 150, 110), rgb(70, 74, 78), rgb(176, 120, 60), rgb(110, 128, 150) }

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

function CityRefinery.build(parent: Instance, origin: Vector3, top: number): { { number } }
	local site = CityRefinery.SITE
	local deck = top + 0.3
	local refinery = Instance.new("Model")
	refinery.Name = "Refinery"
	refinery.Parent = parent

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
	local function ball(into: Instance, name: string, diameter: number, offset: Vector3, color: Color3, collide: boolean?): Part
		local p = part(into, name, Vector3.one * diameter, offset, color, M.Metal, collide)
		p.Shape = Enum.PartType.Ball
		return p
	end
	local function strut(into: Instance, name: string, a: Vector3, b: Vector3, thickness: number, color: Color3, material: Enum.Material, collide: boolean?): Part
		local p = part(into, name, Vector3.new(thickness, thickness, (b - a).Magnitude), (a + b) / 2, color, material, collide)
		p.CFrame = CFrame.lookAt(origin + (a + b) / 2, origin + b)
		return p
	end
	-- A pipe run between two points; a cylinder's axis is its X, so turn X onto the run
	local function pipe(into: Instance, name: string, diameter: number, a: Vector3, b: Vector3, color: Color3): Part
		local p = part(into, name, Vector3.new((b - a).Magnitude, diameter, diameter), (a + b) / 2, color, M.Metal, false)
		p.Shape = Enum.PartType.Cylinder
		p.CFrame = CFrame.lookAt(origin + (a + b) / 2, origin + b) * CFrame.Angles(0, math.pi / 2, 0)
		return p
	end
	local function keep(p: BasePart): BasePart
		p:SetAttribute("LodKeep", true)
		return p
	end
	-- A process column: skirt, shell, domed head, ring platforms and a caged ladder
	local function column(into: Instance, x: number, z: number, diameter: number, height: number)
		cylinder(into, "ColumnSkirt", diameter + 1, 5, Vector3.new(x, deck + 2.5, z), concrete, M.Concrete)
		keep(cylinder(into, "Column", diameter, height, Vector3.new(x, deck + height / 2, z), galvanised, M.Metal))
		ball(into, "ColumnHead", diameter, Vector3.new(x, deck + height, z), galvanised, false)
		for y = 16, height - 6, 16 do
			cylinder(into, "ColumnPlatform", diameter + 5, 0.5, Vector3.new(x, deck + y, z), safety, M.DiamondPlate, false)
		end
		part(into, "ColumnLadder", Vector3.new(1.6, height - 4, 0.4), Vector3.new(x + diameter / 2 + 1.4, deck + height / 2, z), safety, M.Metal, false)
	end
	-- A red-and-white banded chimney
	local function stack(into: Instance, x: number, z: number, diameter: number, height: number)
		keep(cylinder(into, "Stack", diameter, height, Vector3.new(x, deck + height / 2, z), rgb(200, 196, 188), M.Concrete))
		for band = 0, 1 do
			cylinder(into, "StackBand", diameter + 0.3, 5, Vector3.new(x, deck + height - 3 - band * 10, z), red, M.SmoothPlastic, false)
		end
	end
	-- An open steel frame with grated floors and cross bracing
	local function frame(into: Instance, cx: number, cz: number, w: number, d: number, levels: number, storey: number)
		local height = levels * storey
		for _, dx in { -w / 2, 0, w / 2 } do
			for _, dz in { -d / 2, d / 2 } do
				part(into, "FramePost", Vector3.new(1.4, height, 1.4), Vector3.new(cx + dx, deck + height / 2, cz + dz), steel, M.Metal)
			end
		end
		for level = 1, levels do
			part(into, "FrameFloor", Vector3.new(w + 1.4, 0.5, d + 1.4), Vector3.new(cx, deck + level * storey, cz), rgb(96, 98, 96), M.DiamondPlate)
			part(into, "FrameRail", Vector3.new(w + 1.4, 0.3, 0.3), Vector3.new(cx, deck + level * storey + 3.4, cz - d / 2 - 0.5), safety, M.Metal, false)
		end
		for _, dz in { -d / 2, d / 2 } do
			strut(into, "FrameBrace", Vector3.new(cx - w / 2, deck, cz + dz), Vector3.new(cx, deck + storey, cz + dz), 0.8, steel, M.Metal, false)
			strut(into, "FrameBrace", Vector3.new(cx + w / 2, deck, cz + dz), Vector3.new(cx, deck + storey, cz + dz), 0.8, steel, M.Metal, false)
		end
	end

	local reserved = { { site.x0 - 10, site.x1 + 10, site.z0 - 10, site.z1 + 10 } }

	---------------------------------------------------------------------------------------------
	-- Yard: pad, internal roads, fence and floodlights

	local yard = pieceModel(refinery, "RefineryYard")
	local cx, cz = (site.x0 + site.x1) / 2, (site.z0 + site.z1) / 2
	local w, d = site.x1 - site.x0, site.z1 - site.z0
	part(yard, "RefineryPad", Vector3.new(w, 0.6, d), Vector3.new(cx, top, cz), concrete, M.Concrete)
	part(yard, "PlantRoad", Vector3.new(w - 20, 0.2, 12), Vector3.new(cx, deck + 0.1, -868), rgb(64, 66, 66), M.Asphalt, false)
	part(yard, "PlantRoad", Vector3.new(w - 20, 0.2, 12), Vector3.new(cx, deck + 0.1, -688), rgb(64, 66, 66), M.Asphalt, false)
	part(yard, "PlantRoad", Vector3.new(14, 0.2, site.z1 - (-868)), Vector3.new(CityRefinery.GATE_X, deck + 0.1, (site.z1 - 868) / 2), rgb(64, 66, 66), M.Asphalt, false)
	-- Chain-link fence on posts, open at the gate
	local fenceY = deck + 4
	local gate0, gate1 = CityRefinery.GATE_X - 12, CityRefinery.GATE_X + 12
	local runs = {
		{ site.x0, site.z0, site.x1, site.z0 },
		{ site.x1, site.z0, site.x1, site.z1 },
		{ site.x0, site.z0, site.x0, site.z1 },
		{ site.x0, site.z1, gate0, site.z1 },
		{ gate1, site.z1, site.x1, site.z1 },
	}
	for _, run in runs do
		local a, b = Vector3.new(run[1], fenceY, run[2]), Vector3.new(run[3], fenceY, run[4])
		local length = (b - a).Magnitude
		local mesh = strut(yard, "FenceMesh", a, b, 1, rgb(150, 154, 150), M.DiamondPlate)
		mesh.Size = Vector3.new(0.2, 8, length)
		mesh.Transparency = 0.6
		local rail = strut(yard, "FenceRail", a + Vector3.new(0, 4, 0), b + Vector3.new(0, 4, 0), 0.3, galvanised, M.Metal, false)
		rail.Size = Vector3.new(0.3, 0.3, length)
		for t = 0, length, 40 do
			local p = a:Lerp(b, t / length)
			part(yard, "FencePost", Vector3.new(0.5, 9, 0.5), Vector3.new(p.X, deck + 4.5, p.Z), galvanised, M.Metal)
		end
	end
	part(yard, "GateHouse", Vector3.new(8, 8, 10), Vector3.new(gate1 + 8, deck + 4, site.z1 - 8), white, M.SmoothPlastic)
	part(yard, "GateBarrier", Vector3.new(22, 0.6, 0.6), Vector3.new(CityRefinery.GATE_X, deck + 3.5, site.z1 + 1), red, M.SmoothPlastic, false)
	for _, corner in { { site.x0 + 6, site.z0 + 6 }, { site.x1 - 6, site.z0 + 6 }, { site.x0 + 6, -700 }, { site.x1 - 6, -700 } } do
		keep(part(yard, "MastPole", Vector3.new(1.4, 60, 1.4), Vector3.new(corner[1], deck + 30, corner[2]), galvanised, M.Metal))
		local lamps = part(yard, "MastLamps", Vector3.new(6, 2.4, 6), Vector3.new(corner[1], deck + 61, corner[2]), rgb(232, 220, 170), M.Neon, false)
		local light = Instance.new("PointLight")
		light.Range = 60
		light.Brightness = 1.2
		light.Color = rgb(255, 228, 180)
		light.Parent = lamps
	end

	---------------------------------------------------------------------------------------------
	-- Tank farm: two bunded rows of floating-roof tanks with stairs winding up their sides

	local tanks = pieceModel(refinery, "TankFarm")
	for row, rz in { -975, -905 } do
		local bx0, bx1, bz0, bz1 = site.x0 + 8, -1138, rz - 29, rz + 29
		part(tanks, "BundFloor", Vector3.new(bx1 - bx0, 0.2, bz1 - bz0), Vector3.new((bx0 + bx1) / 2, deck + 0.1, rz), rgb(104, 100, 92), M.Pebble, false)
		for _, side in { { bx0, bz0, bx1, bz0 }, { bx0, bz1, bx1, bz1 }, { bx0, bz0, bx0, bz1 }, { bx1, bz0, bx1, bz1 } } do
			local length = math.max(math.abs(side[3] - side[1]), math.abs(side[4] - side[2]))
			local alongX = side[2] == side[4]
			part(tanks, "BundWall", if alongX then Vector3.new(length + 1.2, 2.6, 1.2) else Vector3.new(1.2, 2.6, length + 1.2), Vector3.new((side[1] + side[3]) / 2, deck + 1.3, (side[2] + side[4]) / 2), concrete, M.Concrete)
		end
		for i, x in { -1350, -1290, -1230, -1170 } do
			local diameter = ({ 46, 40, 50, 44 })[(i + row) % 4 + 1]
			local height = 24 + (i + row * 2) % 3 * 3
			local radius = diameter / 2
			cylinder(tanks, "TankFooting", diameter + 1, 1, Vector3.new(x, deck + 0.5, rz), concrete, M.Concrete)
			keep(cylinder(tanks, "StorageTank", diameter, height, Vector3.new(x, deck + height / 2 + 0.5, rz), tankWhite, M.Metal))
			cylinder(tanks, "WindGirder", diameter + 1.4, 0.8, Vector3.new(x, deck + height - 2.5, rz), rgb(170, 172, 166), M.Metal, false)
			cylinder(tanks, "FloatingRoof", diameter - 1.5, 0.6, Vector3.new(x, deck + height - 1.2, rz), rgb(120, 122, 118), M.Metal, false)
			-- A stair climbing a third of the way round
			local start = (i * 1.7 + row) % (math.pi * 2)
			local previous
			for k = 0, 4 do
				local angle = start + k * math.pi / 6
				local point = Vector3.new(x + math.cos(angle) * (radius + 1.4), deck + 0.5 + k * height / 4, rz + math.sin(angle) * (radius + 1.4))
				if previous then
					local tread = strut(tanks, "TankStair", previous, point, 1, safety, M.Metal, false)
					tread.Size = Vector3.new(2.4, 0.4, tread.Size.Z)
					strut(tanks, "TankStairRail", previous + Vector3.new(0, 3, 0), point + Vector3.new(0, 3, 0), 0.25, safety, M.Metal, false)
				end
				previous = point
			end
			pipe(tanks, "TankLine", 1.6, Vector3.new(x, deck + 1.6, rz + (if row == 1 then radius else -radius)), Vector3.new(x, deck + 1.6, if row == 1 then rz + 31 else rz - 31), PIPES[1])
		end
		pipe(tanks, "TankHeader", 2, Vector3.new(bx0, deck + 1.6, if row == 1 then rz + 31 else rz - 31), Vector3.new(-1122, deck + 1.6, if row == 1 then rz + 31 else rz - 31), PIPES[1])
	end

	-- Pressurised LPG spheres on their legs, east of the tanks
	local spheres = pieceModel(refinery, "LpgSpheres")
	for k, z in { -990, -945, -900 } do
		local x, diameter = -1102, 28
		local y = deck + 6 + diameter / 2
		keep(ball(spheres, "LpgSphere", diameter, Vector3.new(x, y, z), rgb(222, 222, 214)))
		cylinder(spheres, "SphereEquator", diameter + 0.6, 1, Vector3.new(x, y, z), rgb(180, 182, 176), M.Metal, false)
		for leg = 0, 5 do
			local angle = leg * math.pi / 3 + k
			part(spheres, "SphereLeg", Vector3.new(1.4, y - deck, 1.4), Vector3.new(x + math.cos(angle) * 12.5, deck + (y - deck) / 2, z + math.sin(angle) * 12.5), steel, M.Metal)
		end
		strut(spheres, "SphereStair", Vector3.new(x - 17, deck, z), Vector3.new(x - 6, y + diameter / 2 - 1, z), 1.4, safety, M.Metal, false)
	end

	---------------------------------------------------------------------------------------------
	-- Process units between the tank farm and the pipe rack

	local crude = pieceModel(refinery, "DistillationUnit")
	frame(crude, -1318, -800, 36, 24, 4, 10)
	column(crude, -1364, -828, 10, 82)
	column(crude, -1364, -782, 8, 64)
	column(crude, -1286, -840, 12, 48)
	pipe(crude, "VapourLine", 2.2, Vector3.new(-1364, deck + 82, -828), Vector3.new(-1330, deck + 41, -812), PIPES[2])
	pipe(crude, "VapourLine", 1.8, Vector3.new(-1364, deck + 64, -782), Vector3.new(-1336, deck + 41, -790), PIPES[2])
	for level = 1, 3 do
		pipe(crude, "HeatExchanger", 4, Vector3.new(-1332, deck + level * 10 + 2.6, -806 + level * 3), Vector3.new(-1306, deck + level * 10 + 2.6, -806 + level * 3), rgb(150, 150, 144))
	end
	-- Fin-fan coolers on the top deck
	part(crude, "AirCooler", Vector3.new(34, 3, 20), Vector3.new(-1318, deck + 42, -800), rgb(110, 112, 110), M.Metal)
	for _, dx in { -10, 0, 10 } do
		cylinder(crude, "CoolerFan", 8, 0.6, Vector3.new(-1318 + dx, deck + 43.7, -800), dark, M.Metal, false)
	end

	local heater = pieceModel(refinery, "FiredHeater")
	part(heater, "HeaterBox", Vector3.new(34, 22, 22), Vector3.new(-1210, deck + 11, -810), rgb(124, 86, 70), M.Metal)
	part(heater, "HeaterHood", Vector3.new(30, 4, 18), Vector3.new(-1210, deck + 24, -810), rgb(96, 70, 60), M.Metal)
	part(heater, "BurnerSkirt", Vector3.new(36, 3, 24), Vector3.new(-1210, deck + 1.5, -810), dark, M.Metal)
	for _, dx in { -9, 9 } do
		stack(heater, -1210 + dx, -834, 5, 74)
		strut(heater, "FlueDuct", Vector3.new(-1210 + dx, deck + 24, -814), Vector3.new(-1210 + dx, deck + 30, -834), 3, rgb(96, 70, 60), M.Metal, false)
	end
	for k = 0, 3 do
		pipe(heater, "TransferLine", 1.4, Vector3.new(-1227, deck + 6 + k * 3, -804), Vector3.new(-1300, deck + 6 + k * 3, -804), PIPES[k % #PIPES + 1])
	end

	local cracker = pieceModel(refinery, "CrackingUnit")
	frame(cracker, -1150, -800, 30, 30, 5, 11)
	keep(cylinder(cracker, "Regenerator", 18, 26, Vector3.new(-1158, deck + 34, -800), galvanised, M.Metal))
	keep(cylinder(cracker, "Reactor", 10, 30, Vector3.new(-1140, deck + 52, -800), galvanised, M.Metal))
	ball(cracker, "ReactorHead", 10, Vector3.new(-1140, deck + 67, -800), galvanised, false)
	for _, dz in { -3, 3 } do
		strut(cracker, "Standpipe", Vector3.new(-1156, deck + 22, -800 + dz), Vector3.new(-1141, deck + 38, -800 + dz), 1.8, rgb(150, 146, 136), M.Metal, false)
		cylinder(cracker, "Cyclone", 4, 10, Vector3.new(-1158 + dz * 2, deck + 52, -796), rgb(150, 146, 136), M.Metal, false)
	end
	stack(cracker, -1110, -836, 6, 86)
	pipe(cracker, "FlueLine", 3, Vector3.new(-1158, deck + 46, -808), Vector3.new(-1110, deck + 46, -836), rgb(110, 104, 96))

	---------------------------------------------------------------------------------------------
	-- The pipe rack spine runs the width of the site, with branches up to the units

	local rack = pieceModel(refinery, "PipeRack", rgb(120, 116, 108))
	local rx0, rx1, rackZ = site.x0 + 6, site.x1 - 6, -712
	for x = rx0, rx1, 31 do
		for _, dz in { -6, 6 } do
			part(rack, "RackPost", Vector3.new(1.2, 14, 1.2), Vector3.new(x, deck + 7, rackZ + dz), steel, M.Metal)
		end
		for _, y in { 7, 13.5 } do
			part(rack, "RackBeam", Vector3.new(1, 1, 13.2), Vector3.new(x, deck + y, rackZ), steel, M.Metal)
		end
	end
	for _, dz in { -6, 6 } do
		part(rack, "RackStringer", Vector3.new(rx1 - rx0, 0.8, 0.8), Vector3.new((rx0 + rx1) / 2, deck + 13.5, rackZ + dz), steel, M.Metal, false)
	end
	for k, spec in { { -4, 1.8 }, { -1.5, 1.4 }, { 1.2, 2.4 }, { 4, 1.2 } } do
		pipe(rack, "RackPipe", spec[2], Vector3.new(rx0, deck + 8.4, rackZ + spec[1]), Vector3.new(rx1, deck + 8.4, rackZ + spec[1]), PIPES[k])
	end
	for k, spec in { { -3.5, 2.8 }, { 0, 1.6 }, { 3.5, 2 } } do
		pipe(rack, "RackPipe", spec[2], Vector3.new(rx0, deck + 15, rackZ + spec[1]), Vector3.new(rx1, deck + 15, rackZ + spec[1]), PIPES[k + 3])
	end
	for k, x in { -1318, -1210, -1150, -1286 } do
		pipe(rack, "RiserPipe", 1.6, Vector3.new(x + 4, deck + 15, rackZ - 6), Vector3.new(x + 4, deck + 15, if k == 4 then -834 else -788), PIPES[k])
	end

	---------------------------------------------------------------------------------------------
	-- Offices, workshop, the tanker loading gantry and the flare

	local offices = pieceModel(refinery, "RefineryOffices")
	CityBuildings.block(offices, CFrame.new(origin + Vector3.new(-1318, deck, -652)), 50, 26, 2, 4)
	CityBuildings.warehouse(offices, CFrame.new(origin + Vector3.new(-1170, deck, -652)) * CFrame.Angles(0, math.pi / 2, 0), 34, 54, 14, 3)

	local loading = pieceModel(refinery, "LoadingGantry", rgb(170, 170, 164))
	local lx, lz = -1106, -655
	part(loading, "GantryCanopy", Vector3.new(30, 1.6, 46), Vector3.new(lx, deck + 14, lz), rgb(196, 196, 190), M.Metal)
	part(loading, "CanopyFascia", Vector3.new(30.4, 2.4, 46.4), Vector3.new(lx, deck + 12.6, lz), red, M.SmoothPlastic, false)
	for _, dx in { -14, 14 } do
		for _, dz in { -22, 22 } do
			part(loading, "CanopyColumn", Vector3.new(1.2, 13, 1.2), Vector3.new(lx + dx, deck + 6.5, lz + dz), dark, M.Metal)
		end
	end
	for k, dz in { -14, 0, 14 } do
		local z = lz + dz
		part(loading, "TankerCab", Vector3.new(7, 7, 7), Vector3.new(lx - 14, deck + 4.5, z), PIPES[k + 3]:Lerp(white, 0.4), M.SmoothPlastic)
		part(loading, "TankerChassis", Vector3.new(26, 1.4, 5.6), Vector3.new(lx + 2, deck + 1.6, z), dark, M.Metal)
		pipe(loading, "TankerBarrel", 6.4, Vector3.new(lx - 9, deck + 5.6, z), Vector3.new(lx + 14, deck + 5.6, z), rgb(210, 210, 204))
		strut(loading, "LoadingArm", Vector3.new(lx, deck + 13, z - 4), Vector3.new(lx + 2, deck + 9.4, z), 0.8, safety, M.Metal, false)
	end

	local flare = pieceModel(refinery, "FlareStack")
	local fx, fz, fh = site.x0 + 20, site.z1 - 22, 120
	keep(cylinder(flare, "FlareStack", 3, fh, Vector3.new(fx, deck + fh / 2, fz), rgb(164, 70, 58), M.Metal))
	for leg = 0, 2 do
		local angle = leg * math.pi * 2 / 3
		local foot = Vector3.new(fx + math.cos(angle) * 9, deck, fz + math.sin(angle) * 9)
		local head = Vector3.new(fx + math.cos(angle) * 2.5, deck + fh - 6, fz + math.sin(angle) * 2.5)
		strut(flare, "FlareLeg", foot, head, 1.2, steel, M.Metal)
		local nextAngle = angle + math.pi * 2 / 3
		for _, t in { 0.2, 0.45, 0.7 } do
			local r = 9 + (2.5 - 9) * t
			local y = deck + (fh - 6) * t
			strut(flare, "FlareBrace", Vector3.new(fx + math.cos(angle) * r, y, fz + math.sin(angle) * r), Vector3.new(fx + math.cos(nextAngle) * r, y, fz + math.sin(nextAngle) * r), 0.6, steel, M.Metal, false)
		end
	end
	local tip = cylinder(flare, "FlareTip", 4, 4, Vector3.new(fx, deck + fh + 2, fz), dark, M.Metal, false)
	local fire = Instance.new("Fire")
	fire.Size = 10
	fire.Heat = 16
	fire.Color = rgb(255, 150, 60)
	fire.SecondaryColor = rgb(255, 220, 120)
	fire.Parent = tip
	local glow = Instance.new("PointLight")
	glow.Range = 40
	glow.Brightness = 2
	glow.Color = rgb(255, 170, 90)
	glow.Parent = tip

	-- The access road south to the harbour road
	local road = pieceModel(refinery, "RefineryRoad")
	part(road, "RefineryRoad", Vector3.new(16, 0.5, -143 - site.z1), Vector3.new(CityRefinery.GATE_X, top + 0.25, (site.z1 - 143) / 2), rgb(66, 68, 66), M.Asphalt)
	table.insert(reserved, { CityRefinery.GATE_X - 10, CityRefinery.GATE_X + 10, site.z1, -117 })
	return reserved
end

return CityRefinery
