-- Distinct buildings, landmarks and street furniture for the four outer port towns.
-- Everything here is built in a local frame: the caller supplies a CFrame at pavement
-- level whose local +Z is the building's front. Small-city layouts (Map/SmallCities)
-- pick the palette and the mix so no two towns read as the same grid with a new seed.
local LowPoly = require(script.Parent.LowPoly)
local Props = require(script.Parent.Props)

local Builders = {}
local rgb, M = Color3.fromRGB, Enum.Material
local TAU = math.pi * 2

-- One palette per town character. Each entry is a whole building scheme, picked per
-- lot, so a terrace street varies without losing the town's colour.
local LOOKS = {
	Fishing = {
		walls = {
			{ rgb(196, 180, 152), M.Plaster },
			{ rgb(152, 86, 70), M.Brick },
			{ rgb(126, 146, 142), M.WoodPlanks },
			{ rgb(116, 128, 142), M.Plaster },
			{ rgb(180, 152, 112), M.Plaster },
			{ rgb(138, 118, 96), M.WoodPlanks },
		},
		trims = { rgb(232, 222, 202), rgb(94, 78, 62), rgb(244, 240, 230) },
		roofs = { { rgb(72, 76, 78), M.Slate }, { rgb(130, 66, 50), M.ClayRoofTiles }, { rgb(96, 88, 72), M.Slate } },
		glass = { rgb(52, 66, 70), rgb(44, 58, 64) },
		metal = { rgb(58, 62, 62), rgb(74, 68, 60) },
		accents = { rgb(170, 66, 52), rgb(44, 100, 104), rgb(202, 156, 62), rgb(72, 112, 84) },
		door = rgb(78, 60, 46),
		pavement = rgb(158, 154, 144),
		asphalt = rgb(66, 66, 64),
		lamp = rgb(255, 208, 146),
	},
	Industry = {
		walls = {
			{ rgb(122, 80, 68), M.Brick },
			{ rgb(102, 72, 62), M.Brick },
			{ rgb(140, 98, 78), M.Brick },
			{ rgb(136, 134, 126), M.Concrete },
			{ rgb(112, 114, 110), M.Concrete },
			{ rgb(104, 118, 120), M.CorrodedMetal },
		},
		trims = { rgb(166, 154, 138), rgb(76, 78, 76), rgb(118, 112, 100) },
		roofs = { { rgb(58, 60, 60), M.Slate }, { rgb(74, 68, 62), M.CorrodedMetal }, { rgb(64, 66, 66), M.Metal } },
		glass = { rgb(52, 62, 64), rgb(60, 70, 70) },
		metal = { rgb(56, 60, 62), rgb(74, 70, 64) },
		accents = { rgb(190, 146, 48), rgb(148, 74, 44), rgb(60, 104, 112), rgb(120, 52, 44) },
		door = rgb(62, 62, 58),
		pavement = rgb(132, 130, 122),
		asphalt = rgb(58, 58, 56),
		lamp = rgb(240, 220, 176),
	},
	Resort = {
		walls = {
			{ rgb(244, 236, 218), M.Plaster },
			{ rgb(238, 210, 192), M.Plaster },
			{ rgb(202, 222, 218), M.Plaster },
			{ rgb(248, 244, 236), M.Plaster },
			{ rgb(226, 206, 162), M.Plaster },
			{ rgb(216, 186, 170), M.Brick },
		},
		trims = { rgb(250, 248, 242), rgb(226, 214, 190), rgb(204, 186, 148) },
		roofs = { { rgb(78, 92, 98), M.Slate }, { rgb(172, 104, 82), M.ClayRoofTiles }, { rgb(96, 126, 114), M.Slate } },
		glass = { rgb(64, 84, 92), rgb(74, 92, 96) },
		metal = { rgb(80, 82, 82), rgb(102, 92, 78) },
		accents = { rgb(220, 112, 94), rgb(72, 160, 152), rgb(214, 172, 78), rgb(136, 116, 180) },
		door = rgb(92, 72, 54),
		pavement = rgb(206, 200, 186),
		asphalt = rgb(84, 84, 82),
		lamp = rgb(255, 218, 164),
	},
	River = {
		walls = {
			{ rgb(180, 158, 120), M.Limestone },
			{ rgb(132, 82, 66), M.Brick },
			{ rgb(214, 202, 178), M.Plaster },
			{ rgb(148, 146, 134), M.Concrete },
			{ rgb(196, 174, 136), M.Limestone },
			{ rgb(118, 92, 72), M.WoodPlanks },
		},
		trims = { rgb(208, 192, 160), rgb(88, 70, 52), rgb(232, 224, 206) },
		roofs = { { rgb(68, 72, 74), M.Slate }, { rgb(86, 96, 76), M.Slate }, { rgb(138, 76, 58), M.ClayRoofTiles } },
		glass = { rgb(56, 68, 70), rgb(48, 60, 64) },
		metal = { rgb(62, 64, 62), rgb(80, 70, 58) },
		accents = { rgb(56, 88, 70), rgb(122, 44, 54), rgb(188, 150, 74), rgb(58, 82, 104) },
		door = rgb(82, 62, 46),
		pavement = rgb(178, 168, 148),
		asphalt = rgb(72, 70, 66),
		lamp = rgb(255, 204, 138),
	},
}

local function pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

-- A complete scheme for one lot. `profile` is the town character, not its name.
function Builders.look(profile: string, rng: Random)
	local set = LOOKS[profile] or LOOKS.Fishing
	local wall = pick(rng, set.walls)
	local roof = pick(rng, set.roofs)
	return {
		wall = wall[1],
		wallMat = wall[2],
		trim = pick(rng, set.trims),
		roof = roof[1],
		roofMat = roof[2],
		glass = pick(rng, set.glass),
		metal = pick(rng, set.metal),
		accent = pick(rng, set.accents),
		door = set.door,
		pavement = set.pavement,
		asphalt = set.asphalt,
		lamp = set.lamp,
	}
end

local function part(parent: Instance, base: CFrame, name: string, size: Vector3, offset: any, color: Color3, material: Enum.Material, solid: boolean?): Part
	local p = Props.part(parent, size, base * (if typeof(offset) == "CFrame" then offset else CFrame.new(offset)), color, material)
	p.Name = name
	if not solid then
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
	end
	if material == M.Glass then
		p.Reflectance = 0.04
	end
	return p
end

local function deco(parent: Instance, base: CFrame, name: string, size: Vector3, offset: any, color: Color3, material: Enum.Material): Part
	return part(parent, base, name, size, offset, color, material, false)
end

local function noise(a: number, b: number): number
	local v = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
	return v - math.floor(v)
end

local ROOM_GLOW = { rgb(255, 198, 124), rgb(244, 216, 164), rgb(196, 214, 236), rgb(255, 176, 100), rgb(232, 200, 146) }
local SHOP_GLOW = { rgb(255, 214, 150), rgb(250, 228, 186), rgb(255, 196, 118), rgb(234, 240, 246) }

local function glow(p: BasePart, colors: { Color3 }, seed: number, salt: number, chance: number?)
	if noise(seed, salt) > (chance or 0.72) then
		return p
	end
	p:AddTag("NightGlow")
	p:SetAttribute("GlowColor", colors[math.floor(noise(salt, seed) * #colors) % #colors + 1])
	p:SetAttribute("GlowAt", 0.2 + noise(salt, seed) * 0.6)
	return p
end

local function downlight(p: BasePart, range: number, color: Color3)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 140
	light.Range = range
	light.Brightness = 2.4
	light.Color = color
	light.Shadows = false
	light:AddTag("NightLight")
	light:SetAttribute("GlowAt", 0.3)
	light.Parent = p
end

local function shellModel(parent: Instance, name: string, color: Color3): Model
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("LodColor", color)
	m:SetAttribute("CityDetailSource", true)
	m.Parent = parent
	return m
end

-- A two-panel pitched roof with a ridge cap and closed gable ends.
local function pitchedRoof(parent: Instance, base: CFrame, width: number, depth: number, y: number, rise: number, look, material: Enum.Material?)
	local half = depth / 2
	local slope = math.sqrt(half * half + rise * rise)
	local angle = math.atan2(rise, half)
	local roofMat = material or look.roofMat
	for _, side in { -1, 1 } do
		part(
			parent,
			base,
			"RoofPanel",
			Vector3.new(width + 1.3, 0.7, slope + 0.5),
			CFrame.new(0, y + rise / 2, side * half / 2) * CFrame.Angles(side * angle, 0, 0),
			look.roof,
			roofMat
		)
	end
	deco(parent, base, "RoofRidge", Vector3.new(width + 1.5, 0.55, 0.8), Vector3.new(0, y + rise, 0), look.roof:Lerp(rgb(0, 0, 0), 0.28), roofMat)
	for _, side in { -1, 1 } do
		LowPoly.triangle(
			base * Vector3.new(side * (width / 2 + 0.2), y, -half),
			base * Vector3.new(side * (width / 2 + 0.2), y, half),
			base * Vector3.new(side * (width / 2 + 0.2), y + rise, 0),
			base * Vector3.new(side * (width / 2 - 2), y, 0),
			look.wall,
			parent,
			look.wallMat
		)
	end
end

local function hippedRoof(parent: Instance, base: CFrame, width: number, depth: number, y: number, rise: number, look, material: Enum.Material?)
	local roofMat = material or look.roofMat
	local halfW, halfD = width / 2, depth / 2
	local slopeW = math.sqrt(halfW * halfW + rise * rise)
	local slopeD = math.sqrt(halfD * halfD + rise * rise)
	local angleW = math.atan2(rise, halfW)
	local angleD = math.atan2(rise, halfD)
	for _, side in { -1, 1 } do
		part(
			parent,
			base,
			"HipRoofPanel",
			Vector3.new(width + 1.2, 0.65, slopeW + 0.4),
			CFrame.new(0, y + rise / 2, side * halfD / 2) * CFrame.Angles(side * angleD, 0, 0),
			look.roof,
			roofMat
		)
		part(
			parent,
			base,
			"HipRoofPanel",
			Vector3.new(0.65, slopeD + 0.4, depth + 1.2),
			CFrame.new(side * halfW / 2, y + rise / 2, 0) * CFrame.Angles(0, 0, -side * angleW),
			look.roof,
			roofMat
		)
	end
	deco(parent, base, "HipRoofCap", Vector3.new(1.2, 0.5, 1.2), Vector3.new(0, y + rise, 0), look.roof:Lerp(rgb(0, 0, 0), 0.3), roofMat)
end

local function chimney(parent: Instance, base: CFrame, x: number, y: number, z: number, height: number, look)
	part(parent, base, "Chimney", Vector3.new(2.6, height, 2.6), Vector3.new(x, y + height / 2, z), look.wall:Lerp(look.roof, 0.25), look.wallMat)
	deco(parent, base, "ChimneyCap", Vector3.new(3.4, 0.5, 3.4), Vector3.new(x, y + height, z), look.roof, M.Slate)
end

local function shopfront(parent: Instance, base: CFrame, x: number, width: number, front: number, look, seed: number, salt: number)
	deco(parent, base, "ShopFrame", Vector3.new(width, 8.2, 0.5), Vector3.new(x, 5.2, front + 0.3), look.metal, M.Metal)
	local glass = deco(parent, base, "ShopWindow", Vector3.new(width - 1.1, 7, 0.6), Vector3.new(x, 5.2, front + 0.45), look.glass, M.Glass)
	glow(glass, SHOP_GLOW, seed, salt, 0.85)
	deco(parent, base, "ShopMullion", Vector3.new(0.4, 7, 0.7), Vector3.new(x, 5.2, front + 0.65), look.metal, M.Metal)
	deco(parent, base, "ShopSill", Vector3.new(width + 0.6, 0.6, 0.9), Vector3.new(x, 1.2, front + 0.45), look.trim, M.Concrete)
	deco(parent, base, "ShopFascia", Vector3.new(width + 0.8, 1.5, 0.8), Vector3.new(x, 9.6, front + 0.35), look.trim, M.Concrete)
end

local function awning(parent: Instance, base: CFrame, x: number, width: number, front: number, color: Color3)
	local panel = deco(parent, base, "Awning", Vector3.new(width, 0.28, 3.6), CFrame.new(x, 9.1, front + 1.8) * CFrame.Angles(0.22, 0, 0), color, M.Fabric)
	panel.CastShadow = true
	for _, side in { -1, 1 } do
		deco(parent, base, "AwningBrace", Vector3.new(0.2, 1.6, 0.2), Vector3.new(x + side * (width / 2 - 0.4), 9.8, front + 3.3), color:Lerp(rgb(0, 0, 0), 0.35), M.Metal)
	end
end

local function balconies(parent: Instance, base: CFrame, width: number, depth: number, y: number, look)
	local front = depth / 2
	deco(parent, base, "BalconySlab", Vector3.new(width, 0.45, 3.2), Vector3.new(0, y, front + 1.5), look.trim, M.Concrete)
	deco(parent, base, "BalconyRail", Vector3.new(width, 2.1, 0.25), Vector3.new(0, y + 1.3, front + 3), look.glass, M.Glass)
	for _, side in { -1, 1 } do
		deco(parent, base, "BalconyRail", Vector3.new(0.25, 2.1, 3), Vector3.new(side * width / 2, y + 1.3, front + 1.6), look.glass, M.Glass)
	end
end

-----------------------------------------------------------------------------------------------
-- Ordinary building stock

-- A terrace of narrow townhouses: shopfronts at the pavement, joined party walls,
-- varied window bays, balconies and a continuous pitched roof.
function Builders.terrace(parent: Instance, base: CFrame, width: number, depth: number, floors: number, variant: number, look): Model
	local b = shellModel(parent, "CityBlock" .. variant, look.wall)
	local ground, storey = 12, 9.5
	local height = ground + (math.max(2, floors) - 1) * storey
	local front = depth / 2
	local units = math.clamp(math.round(width / 17), 2, 7)
	local uw = width / units

	part(b, base, "Body", Vector3.new(width, height, depth), Vector3.new(0, height / 2, 0), look.wall, look.wallMat, true)
	part(b, base, "Plinth", Vector3.new(width + 0.6, 1.8, depth + 0.6), Vector3.new(0, 0.9, 0), look.trim, M.Concrete, true)
	deco(b, base, "Cornice", Vector3.new(width + 1.1, 1.2, depth + 1.1), Vector3.new(0, height - 0.2, 0), look.trim, M.Concrete)

	for unit = 1, units do
		local x = -width / 2 + (unit - 0.5) * uw
		local seed = variant * 31 + unit
		shopfront(b, base, x - uw * 0.1, uw - 3.4, front, look, seed, 2)
		local doorX = x + uw * 0.38
		deco(b, base, "DoorRecess", Vector3.new(3.2, 8.2, 0.55), Vector3.new(doorX, 4.6, front + 0.3), look.metal, M.Metal)
		deco(b, base, "Door", Vector3.new(2.4, 7.2, 0.65), Vector3.new(doorX, 4.1, front + 0.5), look.door, M.WoodPlanks)
		deco(b, base, "DoorStep", Vector3.new(3.6, 0.5, 1.5), Vector3.new(doorX, 0.25, front + 0.9), look.trim, M.Concrete)
		for floor = 2, math.max(2, floors) do
			local y = ground + (floor - 2) * storey + 5.4
			local glass = deco(b, base, "Window", Vector3.new(uw - 5, 4.6, 0.45), Vector3.new(x, y, front + 0.26), look.glass, M.Glass)
			glow(glass, ROOM_GLOW, seed, floor * 3, 0.6)
			deco(b, base, "WindowSill", Vector3.new(uw - 4.2, 0.5, 0.8), Vector3.new(x, y - 2.8, front + 0.4), look.trim, M.Concrete)
			deco(b, base, "WindowLintel", Vector3.new(uw - 4.2, 0.45, 0.8), Vector3.new(x, y + 2.8, front + 0.4), look.trim, M.Concrete)
			if unit % 2 == 0 and floor == 2 then
				balconies(b, base, uw - 5, depth, y - 1.1, look)
			elseif noise(seed, floor) < 0.22 then
				deco(b, base, "WindowBox", Vector3.new(uw - 5.5, 0.8, 1.1), Vector3.new(x, y - 2.3, front + 0.7), look.accent, M.WoodPlanks)
			end
		end
		if unit % 3 == 1 then
			awning(b, base, x, uw - 3, front, look.accent)
		end
		deco(b, base, "PartyWall", Vector3.new(1, height - 1.2, depth + 0.5), Vector3.new(x + uw / 2, height / 2, 0), look.wall:Lerp(look.trim, 0.18), look.wallMat)
	end

	local rise = math.min(depth * 0.34, 10)
	pitchedRoof(b, base, width, depth, height, rise, look)
	for unit = 1, units, 2 do
		local x = -width / 2 + (unit - 0.5) * uw
		chimney(b, base, x, height + rise * 0.55, -depth * 0.18, 5, look)
	end
	if variant % 3 == 0 then
		-- One unit is taller, a subtle break in the terrace roofline
		local x = -width / 2 + 0.5 * uw
		part(b, base, "TallBay", Vector3.new(uw - 3, 6, depth * 0.5), Vector3.new(x, height + 3, -depth * 0.12), look.wall, look.wallMat)
		pitchedRoof(b, base, uw - 3, depth * 0.5, height + 6, 4, look)
	end
	return b
end

-- A seaside hotel or pension: ground-floor colonnade, stacked balconies facing the
-- sea, a mansard roof and, for the grand ones, a corner turret with a domed cap.
function Builders.hotel(parent: Instance, base: CFrame, width: number, depth: number, floors: number, variant: number, look, grand: boolean?): Model
	local b = shellModel(parent, "CityBlock" .. variant, look.wall)
	local ground, storey = 14, 10
	local height = ground + (math.max(3, floors) - 1) * storey
	local front = depth / 2
	part(b, base, "Body", Vector3.new(width, height, depth), Vector3.new(0, height / 2, 0), look.wall, look.wallMat, true)
	deco(b, base, "Plinth", Vector3.new(width + 0.8, 2.2, depth + 0.8), Vector3.new(0, 1.1, 0), look.trim, M.Concrete)
	deco(b, base, "Cornice", Vector3.new(width + 1.4, 1.4, depth + 1.4), Vector3.new(0, height - 0.3, 0), look.trim, M.Concrete)
	deco(b, base, "StringCourse", Vector3.new(width + 1, 0.7, depth + 1), Vector3.new(0, ground, 0), look.trim, M.Concrete)

	-- Portico: columns, glazed doors and a canopy with warm downlights.
	local bays = math.max(3, math.floor(width / 18))
	for i = 0, bays do
		local x = -width / 2 + i * width / bays
		deco(b, base, "PorticoColumn", Vector3.new(1.6, ground - 2, 1.6), Vector3.new(x, ground / 2, front + 1.8), look.trim, M.Concrete)
	end
	for bay = 1, bays do
		local x = -width / 2 + (bay - 0.5) * width / bays
		local glass = deco(b, base, "LobbyGlass", Vector3.new(width / bays - 3, ground - 3, 0.6), Vector3.new(x, (ground - 2) / 2 + 1, front + 0.35), look.glass, M.Glass)
		glow(glass, SHOP_GLOW, variant, bay + 4, 0.8)
	end
	local canopy = deco(b, base, "PorticoCanopy", Vector3.new(width + 1, 0.7, 4.6), Vector3.new(0, ground - 1.4, front + 2.6), look.trim, M.Concrete)
	downlight(canopy, 30, look.lamp)

	for floor = 2, math.max(3, floors) do
		local y = ground + (floor - 2) * storey + 1
		balconies(b, base, width - 2, depth, y, look)
		for bay = 1, bays do
			local x = -width / 2 + (bay - 0.5) * width / bays
			local glass = deco(b, base, "BalconyWindow", Vector3.new(width / bays - 3.4, 6.4, 0.5), Vector3.new(x, y + 3.6, front + 0.26), look.glass, M.Glass)
			glow(glass, ROOM_GLOW, variant, floor * 7 + bay, 0.7)
			deco(b, base, "BalconyDivider", Vector3.new(0.4, 2.6, 3.2), Vector3.new(x + width / bays / 2, y + 1.3, front + 1.8), look.trim, M.Concrete)
		end
	end
	for _, side in { -1, 1 } do
		deco(b, base, "SideWindowBand", Vector3.new(0.5, height - ground - 4, depth * 0.7), Vector3.new(side * (width / 2 + 0.25), ground + (height - ground) / 2, 0), look.glass, M.Glass)
	end

	local rise = math.min(depth * 0.26, 8)
	pitchedRoof(b, base, width, depth, height, rise, look)
	for bay = 1, bays, 2 do
		local x = -width / 2 + (bay - 0.5) * width / bays
		part(b, base, "Dormer", Vector3.new(4.4, 4.2, 3.8), Vector3.new(x, height + rise * 0.45, front - 2), look.wall, look.wallMat)
		deco(b, base, "DormerGlass", Vector3.new(3.1, 2.3, 0.4), Vector3.new(x, height + rise * 0.5, front - 0.1), look.glass, M.Glass)
		pitchedRoof(b, base, 4.8, 4.2, height + rise * 0.45 + 2.1, 2, look)
	end
	if grand then
		local tx, tz = width / 2 - 3, front - 3
		local turret = part(b, base, "CornerTurret", Vector3.new(height + 8, 15, 15), Vector3.new(tx, (height + 8) / 2, tz), look.wall, look.wallMat, true)
		turret.Shape = Enum.PartType.Cylinder
		turret.CFrame = base * CFrame.new(tx, (height + 8) / 2, tz) * CFrame.Angles(0, 0, math.pi / 2)
		deco(b, base, "TurretCornice", Vector3.new(0.9, 16.5, 16.5), CFrame.new(tx, height + 7.5, tz) * CFrame.Angles(0, 0, math.pi / 2), look.trim, M.Concrete)
		local dome = part(b, base, "TurretDome", Vector3.new(14, 9, 14), Vector3.new(tx, height + 12, tz), look.roof:Lerp(rgb(96, 140, 124), 0.55), M.Metal)
		dome.Shape = Enum.PartType.Ball
		deco(b, base, "Finial", Vector3.new(0.5, 5, 0.5), Vector3.new(tx, height + 18, tz), look.metal, M.Metal)
		for floor = 2, math.max(3, floors), 2 do
			local y = ground + (floor - 1) * storey + 2
			deco(b, base, "TurretWindow", Vector3.new(2.4, 5, 0.5), CFrame.new(tx + 7.2, y, tz) * CFrame.Angles(0, math.pi / 2, 0), look.glass, M.Glass)
		end
	end
	return b
end

-- A brick works with tall windows, a sawtooth roof and a boiler chimney.
function Builders.factory(parent: Instance, base: CFrame, width: number, depth: number, floors: number, variant: number, look): Model
	local b = shellModel(parent, "CityBlock" .. variant, look.wall)
	local ground, storey = 10, 11
	local height = ground + (math.max(2, floors) - 1) * storey
	local front = depth / 2
	part(b, base, "Body", Vector3.new(width, height, depth), Vector3.new(0, height / 2, 0), look.wall, look.wallMat, true)
	deco(b, base, "Plinth", Vector3.new(width + 0.5, 2, depth + 0.5), Vector3.new(0, 1, 0), look.trim, M.Concrete)

	local bays = math.max(3, math.floor(width / 15))
	for bay = 0, bays do
		local x = -width / 2 + bay * width / bays
		deco(b, base, "Pilaster", Vector3.new(1.2, height, 1), Vector3.new(x, height / 2, front + 0.3), look.trim, M.Concrete)
	end
	for bay = 1, bays do
		local x = -width / 2 + (bay - 0.5) * width / bays
		-- The ground floor is loading bays; the remaining floors carry the window rows.
		for floor = 1, math.max(1, floors - 1) do
			local y = ground + (floor - 1) * storey + (if floor == 1 then 1 else 0) + 4.5
			local glass = deco(b, base, "WorksWindow", Vector3.new(width / bays - 4, 7, 0.45), Vector3.new(x, y, front + 0.26), look.glass, M.Glass)
			glow(glass, { rgb(255, 206, 138), rgb(220, 226, 216) }, variant, floor * 5 + bay, 0.42)
			deco(b, base, "WorksWindowSill", Vector3.new(width / bays - 3.2, 0.6, 0.9), Vector3.new(x, y - 4, front + 0.4), look.trim, M.Concrete)
		end
	end
	for _, x in { -width * 0.28, width * 0.28 } do
		deco(b, base, "LoadingDoor", Vector3.new(12, 9, 0.7), Vector3.new(x, 4.5, front + 0.3), look.metal, M.CorrodedMetal)
		deco(b, base, "LoadingCanopy", Vector3.new(14, 0.6, 3.4), Vector3.new(x, 9.6, front + 1.7), look.trim, M.Metal)
	end

	-- Sawtooth north lights: slanted glazing over a low roof deck.
	local roofY = height + 1.4
	part(b, base, "RoofDeck", Vector3.new(width - 1, 1.2, depth - 1), Vector3.new(0, height + 0.6, 0), look.roof, look.roofMat)
	local lights = math.max(2, math.floor(depth / 13))
	for i = 1, lights do
		local z = -depth / 2 + (i - 0.5) * depth / lights
		deco(b, base, "NorthLight", Vector3.new(width - 4, 0.4, 6.4), CFrame.new(0, roofY + 2.4, z) * CFrame.Angles(-0.62, 0, 0), look.glass, M.Glass)
		deco(b, base, "NorthLightFrame", Vector3.new(width - 3, 0.5, 1), CFrame.new(0, roofY + 4.1, z - 2.2), look.metal, M.Metal)
	end
	part(b, base, "BoilerHouse", Vector3.new(width * 0.3, 8, depth * 0.4), Vector3.new(-width * 0.28, height + 4, -depth * 0.2), look.wall, look.wallMat)
	chimney(b, base, width * 0.34, height + 1, depth * 0.18, 25, look)
	deco(b, base, "WorksSign", Vector3.new(width * 0.36, 3.2, 0.5), Vector3.new(0, height - 1, front + 0.35), look.trim, M.SmoothPlastic)
	deco(b, base, "PipeRun", Vector3.new(width * 0.5, 0.8, 0.8), Vector3.new(width * 0.18, height + 2.6, -depth * 0.42), look.metal, M.CorrodedMetal)
	return b
end

-----------------------------------------------------------------------------------------------
-- Landmarks

-- A parish church: buttressed nave, traceried windows, square tower and a slender spire.
function Builders.church(parent: Instance, base: CFrame, variant: number, look): Model
	local b = shellModel(parent, "CityChurch" .. variant, look.wall)
	local width, depth, height = 30, 54, 20
	local front = depth / 2
	part(b, base, "Nave", Vector3.new(width, height, depth), Vector3.new(0, height / 2, 0), look.wall, look.wallMat, true)
	deco(b, base, "NavePlinth", Vector3.new(width + 0.6, 2, depth + 0.6), Vector3.new(0, 1, 0), look.trim, M.Concrete)
	for i = 0, 5 do
		local z = -depth / 2 + i * depth / 5
		for _, side in { -1, 1 } do
			deco(b, base, "Buttress", Vector3.new(1.6, height - 2, 2.4), Vector3.new(side * (width / 2 + 0.5), height / 2, z), look.trim, M.Concrete)
			local glass = deco(
				b,
				base,
				"LancetWindow",
				Vector3.new(0.5, 10, 4.2),
				Vector3.new(side * (width / 2 + 0.1), 11.5, z + depth / 10),
				look.glass,
				M.Glass
			)
			glow(glass, ROOM_GLOW, variant, side * 5 + i, 0.55)
		end
	end
	pitchedRoof(b, base, width, depth, height, 11, look, M.Slate)

	-- Front gable and rose window
	deco(b, base, "FrontGable", Vector3.new(width, 4, 1), Vector3.new(0, height + 1, front), look.wall, look.wallMat)
	local rose = part(b, base, "RoseWindow", Vector3.new(0.5, 8, 8), Vector3.new(0, 15, front + 0.3), look.glass, M.Glass)
	rose.Shape = Enum.PartType.Cylinder
	rose.CFrame = base * CFrame.new(0, 15, front + 0.3) * CFrame.Angles(0, math.pi / 2, 0)
	glow(rose, { rgb(236, 198, 128), rgb(196, 214, 236) }, variant, 3, 0.9)
	deco(b, base, "WestDoor", Vector3.new(6, 9, 0.8), Vector3.new(0, 4.5, front + 0.4), look.door, M.WoodPlanks)

	-- Tower and spire
	local towerX, towerZ = -width / 2 + 8, front - 8
	local tower = part(b, base, "Tower", Vector3.new(15, 38, 15), Vector3.new(towerX, 19, towerZ), look.wall, look.wallMat, true)
	part(b, base, "TowerPlinth", Vector3.new(16.4, 3, 16.4), Vector3.new(towerX, 1.5, towerZ), look.trim, M.Concrete)
	for _, side in { -1, 1 } do
		deco(b, base, "TowerButtress", Vector3.new(2.4, 34, 2.4), Vector3.new(towerX + side * 6.6, 18, towerZ + 6.6), look.trim, M.Concrete)
		deco(b, base, "TowerButtress", Vector3.new(2.4, 34, 2.4), Vector3.new(towerX + side * 6.6, 18, towerZ - 6.6), look.trim, M.Concrete)
	end
	for k = 0, 3 do
		local faceOffset = CFrame.new(towerX, 31.5, towerZ) * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0, 7.6)
		local face = base * faceOffset
		local clock = part(b, base, "ClockFace", Vector3.new(0.35, 5.6, 5.6), faceOffset, rgb(240, 232, 206), M.SmoothPlastic)
		clock.Shape = Enum.PartType.Cylinder
		clock.CFrame = face * CFrame.Angles(0, math.pi / 2, 0)
		local louverOffset = CFrame.new(towerX, 23.5, towerZ) * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0, 7.6)
		deco(b, base, "BelfryLouver", Vector3.new(5, 6, 0.5), louverOffset, rgb(58, 58, 54), M.WoodPlanks)
	end
	deco(b, base, "TowerCornice", Vector3.new(17, 1.4, 17), Vector3.new(towerX, 38, towerZ), look.trim, M.Concrete)
	local spireBase = {}
	for k = 1, 4 do
		local ang = k / 4 * TAU + math.pi / 4
		spireBase[k] = base * Vector3.new(towerX + math.cos(ang) * 7.5, 40, towerZ + math.sin(ang) * 7.5)
	end
	LowPoly.pyramid(spireBase, base * Vector3.new(towerX, 66, towerZ), look.roof:Lerp(rgb(96, 138, 122), 0.35), b, M.Slate)
	deco(b, base, "SpireFinial", Vector3.new(0.45, 5, 0.45), Vector3.new(towerX, 69, towerZ), rgb(198, 168, 88), M.Metal)
	deco(b, base, "SpireCross", Vector3.new(3, 0.4, 0.4), Vector3.new(towerX, 71, towerZ), rgb(198, 168, 88), M.Metal)
	return b
end

-- An iron-and-stone market hall: open arcades, a glazed ridge roof, a clock gable
-- and market counters spilling out under the canopy.
function Builders.marketHall(parent: Instance, base: CFrame, width: number, depth: number, variant: number, look): Model
	local b = shellModel(parent, "CityMarketHall" .. variant, look.wall)
	local front = depth / 2
	part(b, base, "HallFloor", Vector3.new(width, 0.8, depth), Vector3.new(0, 0.4, 0), look.trim, M.Cobblestone)
	deco(b, base, "HallPlinth", Vector3.new(width + 0.8, 2.2, depth + 0.8), Vector3.new(0, 1.1, 0), look.trim, M.Concrete)
	local bays = math.max(4, math.floor(width / 16))
	for bay = 0, bays do
		local x = -width / 2 + bay * width / bays
		part(b, base, "ArcadeColumn", Vector3.new(1.6, 20, 1.6), Vector3.new(x, 10, front - 4), look.wall, look.wallMat)
		part(b, base, "ArcadeColumn", Vector3.new(1.6, 20, 1.6), Vector3.new(x, 10, -front + 4), look.wall, look.wallMat)
	end
	for bay = 0, bays - 1 do
		local x = -width / 2 + (bay + 0.5) * width / bays
		deco(b, base, "ArcadeArch", Vector3.new(width / bays - 2, 4, 0.6), Vector3.new(x, 18, front - 4), look.trim, M.Concrete)
		deco(b, base, "ArcadeScreen", Vector3.new(width / bays - 3, 12, 0.4), Vector3.new(x, 9, front - 3.8), look.glass, M.Glass)
		deco(b, base, "ArcadeScreen", Vector3.new(width / bays - 3, 12, 0.4), Vector3.new(x, 9, -front + 3.8), look.glass, M.Glass)
	end
	for _, side in { -1, 1 } do
		part(b, base, "HallWall", Vector3.new(width, 8, 1), Vector3.new(0, 4, side * (depth / 2 - 1)), look.wall, look.wallMat)
	end
	-- Glazed ridge roof on iron principals
	local rise = 12
	local slope = math.sqrt((depth / 2) * (depth / 2) + rise * rise)
	local angle = math.atan2(rise, depth / 2)
	for _, side in { -1, 1 } do
		deco(b, base, "MarketRoof", Vector3.new(width + 1.4, 0.4, slope + 1), CFrame.new(0, 20 + rise / 2, side * depth / 4) * CFrame.Angles(side * angle, 0, 0), look.glass, M.Glass)
		deco(b, base, "RoofPrincipal", Vector3.new(1, 0.8, slope + 1), CFrame.new(-width / 2 + 1, 20 + rise / 2, side * depth / 4) * CFrame.Angles(side * angle, 0, 0), look.metal, M.Metal)
		deco(b, base, "RoofPrincipal", Vector3.new(1, 0.8, slope + 1), CFrame.new(width / 2 - 1, 20 + rise / 2, side * depth / 4) * CFrame.Angles(side * angle, 0, 0), look.metal, M.Metal)
	end
	deco(b, base, "RoofRidge", Vector3.new(width + 1.8, 1, 1), Vector3.new(0, 20 + rise, 0), look.metal, M.Metal)
	part(b, base, "ClockGable", Vector3.new(18, 14, 2), Vector3.new(0, 27, front - 1), look.wall, look.wallMat)
	local clock = part(b, base, "MarketClock", Vector3.new(0.4, 6.4, 6.4), Vector3.new(0, 28, front + 0.2), rgb(240, 232, 208), M.SmoothPlastic)
	clock.Shape = Enum.PartType.Cylinder
	clock.CFrame = base * CFrame.new(0, 28, front + 0.2) * CFrame.Angles(0, math.pi / 2, 0)
	deco(b, base, "GableCoping", Vector3.new(20, 0.8, 2.6), Vector3.new(0, 34, front - 1), look.trim, M.Concrete)
	deco(b, base, "WeatherVane", Vector3.new(0.4, 5, 0.4), Vector3.new(0, 37, front - 1), look.metal, M.Metal)

	-- Counters and lamps inside the open hall
	for i = 1, 3 do
		local z = -depth / 2 + i * depth / 4
		part(b, base, "MarketCounter", Vector3.new(width * 0.5, 3, 3), Vector3.new(0, 1.5, z), look.door, M.WoodPlanks)
		deco(b, base, "CounterCanopy", Vector3.new(width * 0.54, 0.3, 5), Vector3.new(0, 8, z), look.accent, M.Fabric)
		for _, side in { -1, 1 } do
			local x = side * width * 0.22
			deco(b, base, "CounterPost", Vector3.new(0.4, 7, 0.4), Vector3.new(x, 3.5, z), look.metal, M.Metal)
		end
	end
	for _, x in { -width * 0.3, width * 0.3 } do
		local lamp = deco(b, base, "HallLamp", Vector3.new(1, 1.4, 1), Vector3.new(x, 14, 0), look.lamp, M.Neon)
		local light = Instance.new("PointLight")
		light.Color = look.lamp
		light.Range = 24
		light.Brightness = 1.4
		light.Shadows = false
		light:AddTag("NightLight")
		light:SetAttribute("GlowAt", 0.25)
		light.Parent = lamp
	end
	return b
end

-- A small octagonal bandstand with a bell roof.
function Builders.bandstand(parent: Instance, base: CFrame, radius: number, variant: number, look): Model
	local b = shellModel(parent, "Bandstand" .. variant, look.trim)
	local drum = part(b, base, "BandstandBase", Vector3.new(2.4, radius * 2, radius * 2), Vector3.new(0, 1.2, 0), look.trim, M.Concrete)
	drum.Shape = Enum.PartType.Cylinder
	drum.CFrame = base * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.pi / 2)
	for i = 1, 8 do
		local a = i / 8 * TAU
		local x, z = math.cos(a) * radius * 0.72, math.sin(a) * radius * 0.72
		deco(b, base, "BandstandPost", Vector3.new(0.7, 13, 0.7), Vector3.new(x, 8.3, z), look.metal, M.Metal)
	end
	deco(b, base, "BandstandRail", Vector3.new(radius * 1.5, 1.2, 0.25), Vector3.new(0, 3.2, radius * 0.72), look.metal, M.Metal)
	local ring = {}
	for i = 1, 8 do
		local a = i / 8 * TAU + math.pi / 8
		ring[i] = base * Vector3.new(math.cos(a) * (radius + 2), 15, math.sin(a) * (radius + 2))
	end
	LowPoly.pyramid(ring, base * Vector3.new(0, 21, 0), look.roof, b, M.Metal)
	deco(b, base, "BandstandFinial", Vector3.new(0.4, 4, 0.4), Vector3.new(0, 23, 0), look.accent, M.Metal)
	return b
end

-- A resort pier pavilion: an octagonal drum under an onion dome, reached by lamps.
function Builders.pavilion(parent: Instance, base: CFrame, radius: number, variant: number, look): Model
	local b = shellModel(parent, "PierPavilion" .. variant, look.wall)
	local drum = part(b, base, "PavilionDeck", Vector3.new(2, radius * 2, radius * 2), Vector3.new(0, 1, 0), look.trim, M.Concrete)
	drum.Shape = Enum.PartType.Cylinder
	drum.CFrame = base * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.pi / 2)
	for i = 1, 8 do
		local a = i / 8 * TAU
		local x, z = math.cos(a) * radius * 0.76, math.sin(a) * radius * 0.76
		deco(b, base, "PavilionColumn", Vector3.new(0.9, 16, 0.9), Vector3.new(x, 9, z), look.trim, M.Concrete)
	end
	local wall = part(b, base, "PavilionDrum", Vector3.new(10, radius * 1.4, radius * 1.4), Vector3.new(0, 12, 0), look.wall, look.wallMat)
	wall.Shape = Enum.PartType.Cylinder
	wall.CFrame = base * CFrame.new(0, 12, 0) * CFrame.Angles(0, 0, math.pi / 2)
	for i = 1, 6 do
		local a = i / 6 * TAU
		local x, z = math.cos(a) * radius * 0.7, math.sin(a) * radius * 0.7
		local glass = part(b, base, "PavilionWindow", Vector3.new(0.5, 7, 5), CFrame.new(x, 12, z) * CFrame.Angles(0, -a + math.pi / 2, 0), look.glass, M.Glass)
		glass.Shape = Enum.PartType.Block
		glow(glass, SHOP_GLOW, variant, i, 0.85)
	end
	-- Lower bell roof, then the onion shoulder and finial
	local lower = {}
	for i = 1, 8 do
		local a = i / 8 * TAU + math.pi / 8
		lower[i] = base * Vector3.new(math.cos(a) * (radius + 2.5), 17, math.sin(a) * (radius + 2.5))
	end
	LowPoly.pyramid(lower, base * Vector3.new(0, 23, 0), look.roof:Lerp(rgb(96, 150, 136), 0.35), b, M.Slate)
	local cap = part(b, base, "PavilionDome", Vector3.new(9, 10, 9), Vector3.new(0, 27, 0), look.roof:Lerp(rgb(110, 160, 146), 0.4), M.Metal)
	cap.Shape = Enum.PartType.Ball
	deco(b, base, "PavilionFinial", Vector3.new(0.5, 6, 0.5), Vector3.new(0, 34, 0), rgb(198, 168, 88), M.Metal)
	for i = 1, 8 do
		local a = i / 8 * TAU
		deco(b, base, "PavilionRail", Vector3.new(4.4, 1.2, 0.2), CFrame.new(math.cos(a) * radius * 0.95, 2.6, math.sin(a) * radius * 0.95) * CFrame.Angles(0, -a + math.pi / 2, 0), look.metal, M.Metal)
	end
	return b
end

-- A small harbour light rather than the main city's lighthouse: tapered bands,
-- gallery and a lit lantern visible along the coast at night.
function Builders.harbourLight(parent: Instance, base: CFrame, variant: number): Model
	local b = shellModel(parent, "HarbourLight" .. variant, rgb(226, 222, 210))
	local stone = rgb(126, 122, 114)
	local white, red = rgb(232, 228, 218), rgb(170, 58, 48)
	local plinth = part(b, base, "LightBase", Vector3.new(6, 26, 26), Vector3.new(0, 3, 0), stone, M.Cobblestone)
	plinth.Shape = Enum.PartType.Cylinder
	plinth.CFrame = base * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local r = 7
	for i = 1, 5 do
		local section = part(b, base, "LightTower", Vector3.new(8, r * 2, r * 2), Vector3.new(0, 6 + i * 8 - 4, 0), if i % 2 == 1 then white else red, M.Plaster)
		section.Shape = Enum.PartType.Cylinder
		section.CFrame = base * CFrame.new(0, 6 + i * 8 - 4, 0) * CFrame.Angles(0, 0, math.pi / 2)
		r -= 0.65
	end
	deco(b, base, "LightGallery", Vector3.new(1.2, (r + 3) * 2, (r + 3) * 2), Vector3.new(0, 47, 0), rgb(64, 64, 60), M.DiamondPlate)
	local lantern = deco(b, base, "LightLantern", Vector3.new(6, r * 1.6, r * 1.6), Vector3.new(0, 50, 0), rgb(255, 232, 168), M.Neon)
	lantern.Shape = Enum.PartType.Cylinder
	lantern.CFrame = base * CFrame.new(0, 50, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 214, 148)
	light.Range = 80
	light.Brightness = 2.2
	light.Shadows = false
	light:AddTag("NightLight")
	light:SetAttribute("GlowAt", 0.3)
	light.Parent = lantern
	local cap = part(b, base, "LightCap", Vector3.new(2, 10, 10), CFrame.new(0, 56, 0) * CFrame.Angles(0, 0, math.pi / 2), red, M.Metal)
	cap.Shape = Enum.PartType.Ball
	deco(b, base, "LightDoor", Vector3.new(3.4, 6, 0.6), Vector3.new(0, 10, 7.1), rgb(58, 58, 54), M.WoodPlanks)
	return b
end

-- A civic clock tower on a market square, with a copper spire.
function Builders.clockTower(parent: Instance, base: CFrame, height: number, variant: number, look): Model
	local b = shellModel(parent, "ClockTower" .. variant, look.wall)
	local width = 14
	part(b, base, "TowerBase", Vector3.new(width + 2, 3, width + 2), Vector3.new(0, 1.5, 0), look.trim, M.Concrete)
	part(b, base, "ClockShaft", Vector3.new(width, height, width), Vector3.new(0, height / 2, 0), look.wall, look.wallMat, true)
	for level = 1, 3 do
		local y = level * height / 3.5
		deco(b, base, "TowerBand", Vector3.new(width + 0.8, 1, width + 0.8), Vector3.new(0, y, 0), look.trim, M.Concrete)
	end
	for k = 0, 3 do
		local faceOffset = CFrame.new(0, height - 10, 0) * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0, width / 2 + 0.25)
		local face = base * faceOffset
		local clock = part(b, base, "ClockFace", Vector3.new(0.35, 6.4, 6.4), faceOffset, rgb(242, 234, 210), M.SmoothPlastic)
		clock.Shape = Enum.PartType.Cylinder
		clock.CFrame = face * CFrame.Angles(0, math.pi / 2, 0)
		deco(b, base, "ClockHand", Vector3.new(0.2, 0.4, 4.6), faceOffset * CFrame.new(0, 0, 0.15) * CFrame.Angles(0, 0, 0.4), rgb(46, 46, 44), M.Metal)
	end
	deco(b, base, "TowerCornice", Vector3.new(width + 1.6, 1.4, width + 1.6), Vector3.new(0, height, 0), look.trim, M.Concrete)
	local spireBase = {}
	for k = 1, 4 do
		local ang = k / 4 * TAU + math.pi / 4
		spireBase[k] = base * Vector3.new(math.cos(ang) * (width / 2 - 0.5), height + 1, math.sin(ang) * (width / 2 - 0.5))
	end
	LowPoly.pyramid(spireBase, base * Vector3.new(0, height + 20, 0), rgb(82, 132, 112), b, M.Slate)
	deco(b, base, "TowerFinial", Vector3.new(0.4, 4.5, 0.4), Vector3.new(0, height + 22, 0), rgb(198, 168, 88), M.Metal)
	deco(b, base, "TowerDoor", Vector3.new(5, 8, 0.8), Vector3.new(0, 4, width / 2 + 0.4), look.door, M.WoodPlanks)
	return b
end

-- A tall banded brick chimney with a working smoke plume.
function Builders.smokestack(parent: Instance, base: CFrame, height: number, radius: number, variant: number, look): Model
	local b = shellModel(parent, "FactoryChimney" .. variant, rgb(122, 78, 66))
	local brick = rgb(122, 78, 66)
	local band = rgb(158, 146, 128)
	part(b, base, "StackBase", Vector3.new(radius * 2.6, 5, radius * 2.6), Vector3.new(0, 2.5, 0), band, M.Concrete)
	local sections = 6
	local y = 5
	for i = 1, sections do
		local r = radius * (1 - (i - 1) * 0.09)
		local h = (height - 5) / sections
		local section = part(b, base, "StackShaft", Vector3.new(h, r * 2, r * 2), Vector3.new(0, y + h / 2, 0), brick, M.Brick)
		section.Shape = Enum.PartType.Cylinder
		section.CFrame = base * CFrame.new(0, y + h / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
		deco(b, base, "StackBand", Vector3.new(0.8, r * 2 + 0.4, r * 2 + 0.4), CFrame.new(0, y + h, 0) * CFrame.Angles(0, 0, math.pi / 2), band, M.Brick)
		y += h
	end
	local cap = part(b, base, "StackCap", Vector3.new(2.4, radius * 1.5, radius * 1.5), CFrame.new(0, height + 1, 0) * CFrame.Angles(0, 0, math.pi / 2), rgb(64, 62, 60), M.Metal)
	cap.Shape = Enum.PartType.Cylinder
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "ChimneySmoke"
	smoke.Color = ColorSequence.new(rgb(126, 124, 120))
	smoke.Size = NumberSequence.new(5, 22)
	smoke.Transparency = NumberSequence.new(0.35, 0.9)
	smoke.Lifetime = NumberRange.new(5, 8)
	smoke.Rate = 1.6
	smoke.Speed = NumberRange.new(4, 7)
	smoke.SpreadAngle = Vector2.new(8, 8)
	smoke.LightEmission = 0
	smoke.Parent = cap
	for i = 1, 8 do
		deco(b, base, "StackLadder", Vector3.new(0.6, height / 8, 0.2), Vector3.new(radius + 0.4, (i - 0.5) * height / 8 + 4, 0), rgb(52, 52, 50), M.Metal)
	end
	return b
end

-- A gas-holder: riveted tank in an open steel guide frame.
function Builders.gasometer(parent: Instance, base: CFrame, radius: number, height: number, variant: number, look): Model
	local b = shellModel(parent, "Gasometer" .. variant, rgb(116, 126, 110))
	local tank = part(b, base, "GasTank", Vector3.new(height, radius * 2, radius * 2), Vector3.new(0, height / 2 + 4, 0), rgb(112, 126, 108), M.CorrodedMetal)
	tank.Shape = Enum.PartType.Cylinder
	tank.CFrame = base * CFrame.new(0, height / 2 + 4, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local dome = part(b, base, "GasDome", Vector3.new(radius * 2, height * 0.22, radius * 2), Vector3.new(0, height + 4, 0), rgb(100, 116, 98), M.CorrodedMetal)
	dome.Shape = Enum.PartType.Ball
	for i = 1, 10 do
		local a = i / 10 * TAU
		local x, z = math.cos(a) * radius * 1.06, math.sin(a) * radius * 1.06
		deco(b, base, "GasGuide", Vector3.new(0.7, height + 4, 0.7), Vector3.new(x, (height + 4) / 2, z), rgb(74, 76, 72), M.Metal)
		deco(b, base, "GasBrace", Vector3.new(0.5, 0.5, radius * 1.5), CFrame.new(x, height + 2.5, z) * CFrame.Angles(0, -a, 0), rgb(74, 76, 72), M.Metal)
	end
	for ring = 1, 3 do
		local y = 3 + ring * height / 4
		local hoop = part(b, base, "GasHoop", Vector3.new(0.8, radius * 2.12, radius * 2.12), CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2), rgb(74, 76, 72), M.Metal)
		hoop.Shape = Enum.PartType.Cylinder
	end
	deco(b, base, "GasStair", Vector3.new(1.4, height + 4, 3), CFrame.new(-radius * 1.1, (height + 4) / 2, 0) * CFrame.Angles(0, 0, -0.12), rgb(70, 72, 68), M.Metal)
	return b
end

function Builders.waterTower(parent: Instance, base: CFrame, height: number, variant: number, look): Model
	local b = shellModel(parent, "WaterTower" .. variant, look.trim)
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		deco(b, base, "TowerLeg", Vector3.new(1, height, 1), Vector3.new(c[1] * 5, height / 2, c[2] * 5), look.metal, M.Metal)
	end
	for level = 1, 3 do
		local y = level * height / 4
		for _, side in { -1, 1 } do
			deco(b, base, "TowerBrace", Vector3.new(11, 0.4, 0.4), Vector3.new(0, y, side * 5), look.metal, M.Metal)
			deco(b, base, "TowerBrace", Vector3.new(0.4, 0.4, 11), Vector3.new(side * 5, y, 0), look.metal, M.Metal)
		end
	end
	local tank = part(b, base, "WaterTank", Vector3.new(14, 14, 14), Vector3.new(0, height + 4, 0), look.metal, M.CorrodedMetal)
	tank.Shape = Enum.PartType.Cylinder
	tank.CFrame = base * CFrame.new(0, height + 4, 0) * CFrame.Angles(0, 0, math.pi / 2)
	part(b, base, "TankRoof", Vector3.new(3, 15, 15), Vector3.new(0, height + 12, 0), look.roof, M.Metal).Shape = Enum.PartType.Ball
	deco(b, base, "TankLadder", Vector3.new(0.6, height + 8, 0.2), Vector3.new(7.4, (height + 8) / 2, 0), look.metal, M.Metal)
	return b
end

-- A stone bridge over a river arm: flat walkable deck, parapets and shallow arches.
-- `span` runs along local X, `width` along local Z.
function Builders.bridge(parent: Instance, base: CFrame, span: number, width: number, variant: number, look): Model
	local b = shellModel(parent, "StoneBridge" .. variant, look.trim)
	local deckTop = 0.7
	part(b, base, "BridgeDeck", Vector3.new(span, 1.4, width), Vector3.new(0, deckTop - 0.7, 0), look.trim, M.Concrete, true)
	for _, side in { -1, 1 } do
		deco(b, base, "BridgeParapet", Vector3.new(span, 3.2, 1), Vector3.new(0, deckTop + 1.6, side * (width / 2 - 0.5)), look.wall, look.wallMat)
		deco(b, base, "BridgeCoping", Vector3.new(span + 0.4, 0.5, 1.3), Vector3.new(0, deckTop + 3.4, side * (width / 2 - 0.5)), look.trim, M.Concrete)
	end
	local arches = math.max(2, math.floor(span / 26))
	local bay = span / arches
	for a = 1, arches do
		local cx = -span / 2 + (a - 0.5) * bay
		local radius = bay / 2 - 1
		for side = -1, 1, 2 do
			for i = 0, 4 do
				local ang = math.pi + i / 4 * math.pi
				local x = cx + math.cos(ang) * radius
				local y = deckTop - 1.4 + math.sin(ang) * radius * 0.42
				deco(
					b,
					base,
					"ArchRing",
					Vector3.new(2.2, 1.1, 0.7),
					CFrame.new(x, y, side * (width / 2 + 0.2)) * CFrame.Angles(0, 0, ang + math.pi / 2),
					look.trim,
					M.Concrete
				)
			end
		end
		if a < arches then
			local x = -span / 2 + a * bay
			part(b, base, "BridgePier", Vector3.new(3.4, 9, width + 1), Vector3.new(x, deckTop - 4.6, 0), look.wall, look.wallMat, true)
			deco(b, base, "Cutwater", Vector3.new(4.4, 5, 2.4), Vector3.new(x, deckTop - 3.4, width / 2 + 1), look.trim, M.Concrete)
			deco(b, base, "Cutwater", Vector3.new(4.4, 5, 2.4), Vector3.new(x, deckTop - 3.4, -width / 2 - 1), look.trim, M.Concrete)
		end
	end
	for _, side in { -1, 1 } do
		local x = side * (span / 2 - 1)
		for _, z in { -width / 2 + 1, width / 2 - 1 } do
			local lamp = deco(b, base, "BridgeLamp", Vector3.new(1, 1.4, 1), Vector3.new(x, deckTop + 5, z), look.lamp, M.Neon)
			local light = Instance.new("PointLight")
			light.Color = look.lamp
			light.Range = 20
			light.Brightness = 1.2
			light.Shadows = false
			light:AddTag("NightLight")
			light.Parent = lamp
			deco(b, base, "BridgeLampPost", Vector3.new(0.4, 4, 0.4), Vector3.new(x, deckTop + 2, z), look.metal, M.Metal)
		end
	end
	return b
end

-- A riverside mill: stone range, pitched slate roof, working wheel and sluice.
function Builders.mill(parent: Instance, base: CFrame, variant: number, look): Model
	local b = shellModel(parent, "CityMill" .. variant, look.wall)
	local width, depth, height = 34, 40, 18
	part(b, base, "MillBody", Vector3.new(width, height, depth), Vector3.new(0, height / 2, 0), look.wall, look.wallMat, true)
	deco(b, base, "MillPlinth", Vector3.new(width + 0.6, 2, depth + 0.6), Vector3.new(0, 1, 0), look.trim, M.Concrete)
	for floor = 1, 2 do
		for i = 1, 4 do
			local z = -depth / 2 + i * depth / 4
			local glass = deco(b, base, "MillWindow", Vector3.new(0.5, 5, 4), Vector3.new(width / 2 + 0.2, 3 + floor * 5.5, z), look.glass, M.Glass)
			glow(glass, ROOM_GLOW, variant, floor * 7 + i, 0.45)
		end
	end
	pitchedRoof(b, base, width, depth, height, 8, look, M.Slate)
	part(b, base, "MillChimney", Vector3.new(4, 22, 4), Vector3.new(-width * 0.3, height + 4, -depth * 0.2), look.wall, look.wallMat)
	-- Water wheel on the river side
	local wheelX = width / 2 + 4
	local wheel = part(b, base, "WaterWheel", Vector3.new(1.6, 16, 16), CFrame.new(wheelX, 5.5, 0), look.door, M.WoodPlanks)
	wheel.Shape = Enum.PartType.Cylinder
	for i = 1, 8 do
		local a = i / 8 * TAU
		deco(b, base, "WheelSpoke", Vector3.new(0.5, 15, 0.5), CFrame.new(wheelX, 5.5, 0) * CFrame.Angles(a, 0, 0), look.door:Lerp(rgb(0, 0, 0), 0.25), M.Wood)
		deco(b, base, "WheelBucket", Vector3.new(2.4, 1.4, 1), CFrame.new(wheelX, 5.5 + math.sin(a) * 7.4, math.cos(a) * 7.4) * CFrame.Angles(a, 0, 0), look.door, M.WoodPlanks)
	end
	deco(b, base, "WheelRace", Vector3.new(16, 1, 6), Vector3.new(wheelX + 2, 0.4, 0), rgb(84, 108, 112), M.Glass)
	part(b, base, "MillDoor", Vector3.new(5, 8, 0.8), Vector3.new(0, 4, depth / 2 + 0.3), look.door, M.WoodPlanks)
	return b
end

-- A moored working boat. All parts are decorative; none of these are player vehicles.
function Builders.boat(parent: Instance, position: Vector3, yaw: number, kind: string, color: Color3, rng: Random): Model
	local m = Instance.new("Model")
	m.Name = "MooredBoat"
	m.Parent = parent
	local base = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	local hullLength = if kind == "Barge" then 38 elseif kind == "Narrowboat" then 28 else 20
	local hullWidth = if kind == "Barge" then 9 elseif kind == "Narrowboat" then 6 else 7
	local dark = rgb(44, 48, 50)
	local hull = part(m, base, "BoatHull", Vector3.new(hullWidth, 3.2, hullLength), Vector3.new(0, 0.6, 0), color:Lerp(dark, 0.35), M.WoodPlanks, false)
	hull.CanCollide = false
	part(m, base, "BoatDeck", Vector3.new(hullWidth - 1.4, 0.5, hullLength - 2), Vector3.new(0, 2.4, 0), rgb(150, 132, 104), M.WoodPlanks)
	part(m, base, "BoatGunwale", Vector3.new(hullWidth + 0.3, 0.6, hullLength * 0.9), Vector3.new(0, 2.3, 0), color, M.WoodPlanks)
	if kind == "Sail" then
		part(m, base, "BoatCabin", Vector3.new(hullWidth - 2.6, 3.2, 7), Vector3.new(0, 4, -hullLength * 0.18), rgb(238, 234, 222), M.Plaster)
		part(m, base, "BoatMast", Vector3.new(0.5, 24, 0.5), Vector3.new(0, 12, hullLength * 0.12), rgb(202, 196, 184), M.Metal)
		part(m, base, "BoatBoom", Vector3.new(0.3, 0.3, 10), Vector3.new(0, 13, hullLength * 0.12 - 5), rgb(202, 196, 184), M.Metal)
		part(m, base, "FurledSail", Vector3.new(0.8, 1.4, 9), Vector3.new(0, 13.5, hullLength * 0.12 - 5), rgb(226, 222, 206), M.Fabric)
	elseif kind == "Barge" then
		part(m, base, "BoatHold", Vector3.new(hullWidth - 1.5, 4.5, hullLength * 0.55), Vector3.new(0, 4.4, 0), rgb(78, 76, 70), M.Metal)
		part(m, base, "BoatCabin", Vector3.new(hullWidth - 3, 4.5, 7), Vector3.new(0, 4.6, -hullLength * 0.38), rgb(216, 210, 194), M.Plaster)
		for _, x in { -2, 2 } do
			local glass = part(m, base, "BoatWindow", Vector3.new(1.6, 1.8, 0.3), Vector3.new(x, 5.4, -hullLength * 0.38 + 3.6), rgb(255, 214, 148), M.Neon)
			glow(glass, SHOP_GLOW, rng:NextInteger(1, 99), x, 1)
		end
	elseif kind == "Narrowboat" then
		part(m, base, "BoatCabin", Vector3.new(hullWidth - 1.8, 4, hullLength * 0.6), Vector3.new(0, 4.6, 0), rgb(72, 108, 92), M.WoodPlanks)
		for i = -2, 2 do
			local side = if i % 2 == 0 then -1 else 1
			part(m, base, "BoatWindow", Vector3.new(0.4, 1.8, 3), Vector3.new(side * (hullWidth - 1.8) / 2, 5.2, i * 4), rgb(228, 192, 132), M.Glass)
		end
		part(m, base, "BoatChimney", Vector3.new(0.8, 3, 0.8), Vector3.new(1.2, 8, -hullLength * 0.2), rgb(56, 56, 54), M.Metal)
		part(m, base, "BoatPaint", Vector3.new(hullWidth - 2.8, 1.2, 2.2), Vector3.new(0, 3.2, hullLength * 0.25), rgb(170, 72, 56), M.WoodPlanks)
	else
		part(m, base, "BoatWheelhouse", Vector3.new(hullWidth - 2.8, 5, 5), Vector3.new(0, 5, -hullLength * 0.24), rgb(226, 220, 202), M.WoodPlanks)
		part(m, base, "BoatWheelhouseGlass", Vector3.new(hullWidth - 3.6, 2.2, 0.3), Vector3.new(0, 6.1, -hullLength * 0.24 + 2.5), rgb(255, 210, 140), M.Neon)
		part(m, base, "BoatMast", Vector3.new(0.4, 12, 0.4), Vector3.new(0, 9, hullLength * 0.18), rgb(184, 152, 108), M.Wood)
		for i = 1, 3 do
			local a = (i - 1) / 3 * TAU
			part(m, base, "TyreFender", Vector3.new(0.8, 2, 2), CFrame.new(math.cos(a) * hullWidth / 2, 1.4, math.sin(a) * hullLength * 0.25), rgb(38, 38, 40), M.Rubber).Shape =
				Enum.PartType.Cylinder
		end
	end
	return m
end

-- A ship-to-shore container crane; the boom reaches out over the water.
function Builders.crane(parent: Instance, origin: Vector3, x: number, z: number, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	local base = CFrame.new(origin + Vector3.new(x, 0, z))
	local yellow = rgb(206, 164, 58)
	local dark = rgb(54, 56, 56)
	local function p(n: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material, solid: boolean?)
		return part(m, base, n, size, offset, color, material, solid)
	end
	for _, dx in { -14, 14 } do
		for _, dz in { -5, 5 } do
			p("CraneLeg", Vector3.new(2.4, 52, 2.4), Vector3.new(dx, 26, dz), yellow, M.Metal, true)
		end
		p("CraneSill", Vector3.new(3, 2, 12), Vector3.new(dx, 1, 0), dark, M.Metal, true)
	end
	p("CraneTopBeam", Vector3.new(32, 2.4, 2.4), Vector3.new(0, 52, -5), yellow, M.Metal)
	p("CraneTopBeam", Vector3.new(32, 2.4, 2.4), Vector3.new(0, 52, 5), yellow, M.Metal)
	p("CraneCrossBeam", Vector3.new(2, 2, 12), Vector3.new(-14, 52, 0), yellow, M.Metal)
	p("CraneCrossBeam", Vector3.new(2, 2, 12), Vector3.new(14, 52, 0), yellow, M.Metal)
	p("CraneBoom", Vector3.new(4.4, 2.2, 86), Vector3.new(0, 53, -26), yellow, M.Metal)
	p("CraneBoomTip", Vector3.new(4, 4, 4), Vector3.new(0, 53, -68), yellow, M.Metal)
	p("CraneCounterweight", Vector3.new(8, 5, 5), Vector3.new(0, 49, 26), dark, M.Metal, true)
	p("CraneCab", Vector3.new(5, 6, 5), Vector3.new(9, 46, -8), rgb(96, 112, 118), M.Glass)
	p("CraneTrolley", Vector3.new(5, 2, 4), Vector3.new(0, 51, -38), dark, M.Metal)
	p("CraneCable", Vector3.new(0.4, 34, 0.4), Vector3.new(0, 34, -38), rgb(44, 44, 44), M.Metal)
	p("CraneSpreader", Vector3.new(9, 1.4, 2.4), Vector3.new(0, 17, -38), yellow, M.Metal)
	local beacon = p("CraneBeacon", Vector3.new(1, 1, 1), Vector3.new(0, 55, -68), rgb(96, 24, 20), M.SmoothPlastic)
	beacon.Shape = Enum.PartType.Ball
	beacon:AddTag("AviationBeacon")
	for i = 0, 4 do
		p("CraneStripe", Vector3.new(2.5, 3, 2.5), Vector3.new(0, 8 + i * 9, -5), if i % 2 == 0 then dark else yellow, M.Metal)
	end
	return m
end

-----------------------------------------------------------------------------------------------
-- Street furniture. All pieces are direct Parts under the caller's model so the
-- city's facade migrator can defer them and rebuild them locally at a distance.

local function furniturePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local p = Props.part(parent, size, cframe, color, material)
	p.Name = name
	p.CanCollide, p.CanQuery, p.CastShadow = false, false, false
	return p
end

function Builders.lamp(parent: Instance, position: Vector3, yaw: number, color: Color3): Part
	local base = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	furniturePart(parent, "LampPost", Vector3.new(0.55, 11, 0.55), base * CFrame.new(0, 5.5, 0), rgb(52, 56, 56), M.Metal)
	furniturePart(parent, "LampArm", Vector3.new(2.8, 0.35, 0.35), base * CFrame.new(1.2, 11, 0), rgb(52, 56, 56), M.Metal)
	local head = furniturePart(parent, "LampHead", Vector3.new(1.2, 0.8, 1.2), base * CFrame.new(2.5, 10.65, 0), color, M.SmoothPlastic)
	head.CanCollide = false
	head:AddTag("NightGlow")
	head:SetAttribute("GlowColor", color)
	head:SetAttribute("GlowAt", 0.25)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 48
	light.Brightness = 2.2
	light.Shadows = false
	light:AddTag("NightLight")
	light:SetAttribute("GlowAt", 0.25)
	light.Parent = head
	return head
end

function Builders.bench(parent: Instance, position: Vector3, yaw: number)
	local base = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	local wood, iron = rgb(126, 94, 64), rgb(54, 56, 56)
	furniturePart(parent, "BenchSeat", Vector3.new(5.4, 0.35, 1.7), base * CFrame.new(0, 1.6, 0), wood, M.WoodPlanks)
	furniturePart(parent, "BenchBack", Vector3.new(5.4, 1.6, 0.3), base * CFrame.new(0, 2.6, -0.8), wood, M.WoodPlanks)
	for _, side in { -1, 1 } do
		furniturePart(parent, "BenchLeg", Vector3.new(0.4, 1.6, 1.5), base * CFrame.new(side * 2.2, 0.8, 0), iron, M.Metal)
	end
end

function Builders.bin(parent: Instance, position: Vector3)
	furniturePart(parent, "LitterBin", Vector3.new(1.5, 2.8, 1.5), CFrame.new(position + Vector3.new(0, 1.4, 0)), rgb(38, 58, 46), M.Metal)
end

function Builders.hydrant(parent: Instance, position: Vector3)
	furniturePart(parent, "Hydrant", Vector3.new(0.9, 2.2, 0.9), CFrame.new(position + Vector3.new(0, 1.1, 0)), rgb(170, 40, 32), M.Metal)
	local cap = furniturePart(parent, "HydrantCap", Vector3.new(1.1, 1.1, 1.1), CFrame.new(position + Vector3.new(0, 2.3, 0)), rgb(196, 160, 60), M.Metal)
	cap.Shape = Enum.PartType.Ball
end

function Builders.bollard(parent: Instance, position: Vector3)
	furniturePart(parent, "MooringBollard", Vector3.new(1.4, 2.6, 1.4), CFrame.new(position + Vector3.new(0, 1.3, 0)), rgb(48, 52, 52), M.Metal)
	furniturePart(parent, "BollardCap", Vector3.new(2.2, 0.5, 2.2), CFrame.new(position + Vector3.new(0, 2.6, 0)), rgb(60, 64, 64), M.Metal)
end

function Builders.planter(parent: Instance, position: Vector3, size: number, flower: Color3)
	furniturePart(parent, "Planter", Vector3.new(size, 1.8, size), CFrame.new(position + Vector3.new(0, 0.9, 0)), rgb(146, 134, 116), M.Concrete)
	furniturePart(parent, "PlanterSoil", Vector3.new(size - 1, 0.3, size - 1), CFrame.new(position + Vector3.new(0, 1.8, 0)), rgb(78, 62, 48), M.Ground)
	for i = 1, 3 do
		local offset = Vector3.new((i - 2) * size * 0.22, 2.3, ((i % 2) * 2 - 1) * size * 0.18)
		furniturePart(parent, "PlanterBloom", Vector3.new(0.8, 0.8, 0.8), CFrame.new(position + offset), flower, M.Plastic)
	end
end

-- A compact street tree: trunk and a few faceted crowns, no collision.
function Builders.tree(parent: Instance, position: Vector3, rng: Random, colors: { Color3 })
	local h = rng:NextNumber(9, 15)
	furniturePart(parent, "StreetTreeTrunk", Vector3.new(0.9, h, 0.9), CFrame.new(position + Vector3.new(0, h / 2, 0)), rgb(78, 62, 48), M.Wood)
	for i = 1, rng:NextInteger(2, 3) do
		local s = rng:NextNumber(5, 8)
		local offset = Vector3.new(rng:NextNumber(-2, 2), h - 1 + (i - 1) * 2.2, rng:NextNumber(-2, 2))
		local crown = furniturePart(
			parent,
			"StreetTreeCrown",
			Vector3.new(s, s * 0.72, s),
			CFrame.new(position + offset) * CFrame.Angles(rng:NextNumber(0, TAU), rng:NextNumber(0, TAU), rng:NextNumber(0, TAU)),
			colors[rng:NextInteger(1, #colors)],
			M.LeafyGrass
		)
		crown.CastShadow = true
	end
end

-- A railing between two points: posts and two rails, suited to quays and promenades.
function Builders.railing(parent: Instance, a: Vector3, b: Vector3, color: Color3)
	local delta = b - a
	local length = delta.Magnitude
	local count = math.max(1, math.floor(length / 7))
	for i = 0, count do
		local p = a:Lerp(b, i / count)
		furniturePart(parent, "RailingPost", Vector3.new(0.35, 3.2, 0.35), CFrame.new(p + Vector3.new(0, 1.6, 0)), color, M.Metal)
	end
	for _, y in { 1.2, 2.8 } do
		local mid = (a + b) / 2 + Vector3.new(0, y, 0)
		local p = furniturePart(parent, "RailingBar", Vector3.new(0.18, 0.18, length), CFrame.lookAt(mid, mid + delta), color, M.Metal)
		p.CastShadow = false
	end
end

function Builders.kiosk(parent: Instance, position: Vector3, yaw: number, look)
	local base = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	furniturePart(parent, "KioskBody", Vector3.new(9, 6, 6), base * CFrame.new(0, 3, 0), look.wall, look.wallMat)
	furniturePart(parent, "KioskCounter", Vector3.new(7.4, 1.4, 1.6), base * CFrame.new(0, 3.8, 3.3), look.door, M.WoodPlanks)
	furniturePart(parent, "KioskWindow", Vector3.new(7, 2.8, 0.3), base * CFrame.new(0, 5.4, 3.05), look.glass, M.Glass)
	furniturePart(parent, "KioskRoof", Vector3.new(10.4, 0.5, 7.4), base * CFrame.new(0, 6.5, 0.4), look.roof, look.roofMat)
	furniturePart(parent, "KioskSign", Vector3.new(6, 1.6, 0.3), base * CFrame.new(0, 7.3, 2.9), look.accent, M.SmoothPlastic)
end

function Builders.parasol(parent: Instance, position: Vector3, yaw: number, color: Color3)
	local base = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	furniturePart(parent, "ParasolPole", Vector3.new(0.4, 9, 0.4), base * CFrame.new(0, 4.5, 0), rgb(226, 220, 206), M.Metal)
	for i = 1, 8 do
		local a = i / 8 * TAU
		local stripe = if i % 2 == 0 then color else rgb(244, 240, 230)
		local panel = furniturePart(
			parent,
			"ParasolCanopy",
			Vector3.new(5.4, 0.25, 2.6),
			base * CFrame.new(math.cos(a) * 2.5, 9.4, math.sin(a) * 2.5) * CFrame.Angles(0.2, -a, 0),
			stripe,
			M.Fabric
		)
		panel.CastShadow = false
	end
end

function Builders.lounger(parent: Instance, position: Vector3, yaw: number, color: Color3)
	local base = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	furniturePart(parent, "LoungerBase", Vector3.new(3, 1.1, 6), base * CFrame.new(0, 0.9, 0), rgb(238, 234, 222), M.Plastic)
	furniturePart(parent, "LoungerCushion", Vector3.new(2.6, 0.35, 4.8), base * CFrame.new(0, 1.6, 0.3), color, M.Fabric)
	furniturePart(parent, "LoungerBack", Vector3.new(2.6, 3.4, 0.4), base * CFrame.new(0, 2.8, -2.2) * CFrame.Angles(0.5, 0, 0), rgb(238, 234, 222), M.Plastic)
end

return Builders
