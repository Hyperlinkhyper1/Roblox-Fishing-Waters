-- Contemporary Berlin-inspired mixed-use buildings. The lot origin is at
-- pavement level and the principal entrance faces local +Z.
local Props = require(script.Parent.Props)

local CityBuildings = {}
local rgb = Color3.fromRGB
local M = Enum.Material

-- Weathered stone and smoky glass: a working port city, not a showroom.
local PALETTES = {
	{ stone = rgb(176, 166, 148), trim = rgb(198, 190, 172), glass = rgb(58, 74, 80), metal = rgb(52, 58, 60), brick = rgb(128, 82, 70) },
	{ stone = rgb(158, 150, 136), trim = rgb(186, 178, 160), glass = rgb(64, 80, 90), metal = rgb(56, 60, 64), brick = rgb(118, 72, 62) },
	{ stone = rgb(184, 176, 160), trim = rgb(204, 196, 180), glass = rgb(70, 86, 90), metal = rgb(62, 66, 66), brick = rgb(136, 88, 72) },
	{ stone = rgb(150, 150, 140), trim = rgb(180, 178, 164), glass = rgb(52, 68, 76), metal = rgb(48, 56, 58), brick = rgb(110, 74, 66) },
	{ stone = rgb(178, 160, 140), trim = rgb(200, 186, 168), glass = rgb(72, 84, 90), metal = rgb(66, 62, 60), brick = rgb(140, 88, 70) },
	{ stone = rgb(160, 160, 152), trim = rgb(190, 188, 176), glass = rgb(56, 70, 84), metal = rgb(54, 60, 66), brick = rgb(122, 78, 68) },
	{ stone = rgb(170, 158, 144), trim = rgb(196, 186, 172), glass = rgb(60, 78, 80), metal = rgb(54, 62, 60), brick = rgb(130, 76, 62) },
	{ stone = rgb(166, 154, 144), trim = rgb(192, 182, 168), glass = rgb(70, 82, 94), metal = rgb(60, 62, 68), brick = rgb(118, 68, 62) },
}


local function piece(parent: Instance, base: CFrame, name: string, size: Vector3, offset: Vector3, color: Color3, mat: Enum.Material, solid: boolean?): Part
	local p = Props.part(parent, size, base * CFrame.new(offset), color, mat)
	p.Name = name
	if not solid then
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
	end
	if mat == M.Glass then
		-- Opaque tinted glazing conceals the solid collision core behind it.
		p.Reflectance = 0.05
	end
	return p
end

-- Glazed curtain walls use broad panes and slender structural mullions rather
-- than one part per window. Both the sides and back remain finished from afar.
local function curtain(parent: Instance, base: CFrame, cx: number, cz: number, width: number, depth: number, bottom: number, height: number, palette, facadeStyle: number)
	local y = bottom + height / 2
	local horizontalCount = math.clamp(math.floor(height / 13), 2, 9)
	local verticalCount = if facadeStyle == 1 then 3 else 4
	for _, sign in { -1, 1 } do
		local z = cz + sign * (depth / 2 + 0.18)
		local x = cx + sign * (width / 2 + 0.18)
		piece(parent, base, "CurtainGlass", Vector3.new(width - 1.4, height - 1, 0.35), Vector3.new(cx, y, z), palette.glass, M.Glass)
		piece(parent, base, "SideGlass", Vector3.new(0.35, height - 1, depth - 1.4), Vector3.new(x, y, cz), palette.glass, M.Glass)
		for i = 0, verticalCount do
			local dx = -width / 2 + i * width / verticalCount
			piece(parent, base, "StonePier", Vector3.new(if facadeStyle == 2 then 1.5 else 0.85, height, 0.8), Vector3.new(cx + dx, y, z + sign * 0.23), palette.trim, M.Concrete)
		end
		for i = 0, 3 do
			local dz = -depth / 2 + i * depth / 3
			piece(parent, base, "SideMullion", Vector3.new(0.8, height, 0.75), Vector3.new(x + sign * 0.23, y, cz + dz), palette.metal, M.Metal)
		end
		for floor = 1, horizontalCount - 1 do
			local fy = bottom + floor * height / horizontalCount
			piece(parent, base, "FloorBand", Vector3.new(width, if facadeStyle == 2 then 0.8 else 0.45, 0.75), Vector3.new(cx, fy, z + sign * 0.23), palette.metal, M.Metal)
			piece(parent, base, "SideFloorBand", Vector3.new(0.75, 0.45, depth), Vector3.new(x + sign * 0.23, fy, cz), palette.metal, M.Metal)
		end
	end
end

function CityBuildings.build(parent: Instance, base: CFrame, width: number, depth: number, height: number, variant: number): Model
	local building = Instance.new("Model")
	building.Name = "CityBuilding" .. variant
	building:SetAttribute("CityBuildingVariant", variant)
	building.Parent = parent

	local palette = PALETTES[(variant - 1) % #PALETTES + 1]
	building:SetAttribute("LodColor", palette.glass:Lerp(palette.stone, 0.3))
	local style = (variant - 1 + math.floor((variant - 1) / #PALETTES)) % 5
	local front = depth / 2
	local podiumHeight = 16 + (variant % 3) * 2
	local shaftWidth = width * ({ 0.84, 0.72, 0.88, 0.76, 0.82 })[style + 1]
	local shaftDepth = depth * ({ 0.82, 0.80, 0.86, 0.76, 0.81 })[style + 1]
	local shaftX = ({ 0, -0.08, 0, 0.09, -0.04 })[style + 1] * width
	local shaftZ = ({ -0.03, -0.04, 0, -0.05, 0 })[style + 1] * depth
	local shoulderY = height * ({ 0.76, 0.70, 0.84, 0.75, 0.80 })[style + 1]
	local shaftHeight = shoulderY - podiumHeight
	local stone = if style == 1 or style == 4 then palette.brick else palette.stone
	local stoneMaterial = if style == 1 or style == 4 then M.Brick else M.Concrete

	-- A richly framed street wall echoes older Berlin blocks, while the
	-- setback glazed upper volumes give the silhouette a contemporary profile.
	piece(building, base, "MasonryPodium", Vector3.new(width, podiumHeight, depth), Vector3.new(0, podiumHeight / 2, 0), stone, stoneMaterial, true)
	piece(building, base, "StreetPlinth", Vector3.new(width + 0.6, 2.2, depth + 0.6), Vector3.new(0, 1.1, 0), palette.trim, M.Concrete)
	piece(building, base, "PodiumCornice", Vector3.new(width + 1, 1.2, depth + 1), Vector3.new(0, podiumHeight - 0.3, 0), palette.trim, M.Concrete)
	piece(building, base, "PodiumStringcourse", Vector3.new(width + 0.5, 0.7, 0.8), Vector3.new(0, podiumHeight * 0.57, front + 0.3), palette.trim, M.Concrete)
	for _, x in { -width * 0.43, -width * 0.24, 0, width * 0.24, width * 0.43 } do
		piece(building, base, "StreetPilaster", Vector3.new(1.4, podiumHeight - 3, 0.8), Vector3.new(x, podiumHeight / 2 + 0.5, front + 0.35), palette.trim, M.Concrete)
	end
	for _, side in { -1, 1 } do
		local x = side * width * 0.26
		piece(building, base, "ShopWindowFrame", Vector3.new(width * 0.30, 8.5, 0.6), Vector3.new(x, 6.1, front + 0.4), palette.metal, M.Metal)
		piece(building, base, "ShopWindow", Vector3.new(width * 0.30 - 1.2, 7.3, 0.7), Vector3.new(x, 6.1, front + 0.55), palette.glass, M.Glass)
		piece(building, base, "ShopMullion", Vector3.new(0.55, 7.3, 0.9), Vector3.new(x, 6.1, front + 0.85), palette.metal, M.Metal)
		piece(building, base, "UpperShopWindow", Vector3.new(width * 0.28, math.max(2, podiumHeight - 12), 0.45), Vector3.new(x, (podiumHeight + 10) / 2, front + 0.34), palette.glass, M.Glass)
		for _, z in { -depth * 0.26, 0, depth * 0.26 } do
			piece(building, base, "SideStreetWindow", Vector3.new(0.55, 8, depth * 0.17), Vector3.new(side * (width / 2 + 0.3), 7.5, z), palette.glass, M.Glass)
			piece(building, base, "SideStreetSill", Vector3.new(0.85, 0.6, depth * 0.18), Vector3.new(side * (width / 2 + 0.4), 3.3, z), palette.trim, M.Concrete)
		end
	end
	piece(building, base, "EntranceRecess", Vector3.new(8, 10.5, 0.65), Vector3.new(0, 5.25, front + 0.4), palette.metal, M.Metal)
	piece(building, base, "EntranceGlass", Vector3.new(6.8, 8.6, 0.75), Vector3.new(0, 4.8, front + 0.55), palette.glass, M.Glass)
	piece(building, base, "DoorDivider", Vector3.new(0.45, 8.6, 0.8), Vector3.new(0, 4.8, front + 0.8), palette.metal, M.Metal)
	piece(building, base, "EntranceCanopy", Vector3.new(12, 0.65, 4), Vector3.new(0, 11.3, front + 1.8), palette.metal, M.Metal)
	local plaque = piece(building, base, "AddressPlaque", Vector3.new(2.4, 1.8, 0.25), Vector3.new(5.2, 6.2, front + 0.5), palette.metal, M.Metal)
	local plaqueGui = Instance.new("SurfaceGui")
	plaqueGui.Face = Enum.NormalId.Back
	plaqueGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	plaqueGui.PixelsPerStud = 32
	plaqueGui.Parent = plaque
	local address = Instance.new("TextLabel")
	address.Size = UDim2.fromScale(1, 1)
	address.BackgroundTransparency = 1
	address.Font = Enum.Font.Garamond
	address.TextColor3 = palette.trim
	address.TextScaled = true
	address.Text = tostring(variant)
	address.Parent = plaqueGui
	for _, x in { -5.4, 5.4 } do
		piece(building, base, "CanopyBrace", Vector3.new(0.4, 2, 0.4), Vector3.new(x, 12.4, front + 2.8), palette.metal, M.Metal)
	end

	-- Continuous wings, offset tiers and different crowns create five distinct
	-- massing families rather than one box with a different window colour.
	piece(building, base, "LowerTower", Vector3.new(shaftWidth, shaftHeight, shaftDepth), Vector3.new(shaftX, podiumHeight + shaftHeight / 2, shaftZ), palette.metal, M.Concrete, true)
	curtain(building, base, shaftX, shaftZ, shaftWidth, shaftDepth, podiumHeight, shaftHeight, palette, style % 3)
	local topWidth = shaftWidth * ({ 0.78, 0.68, 0.92, 0.72, 0.80 })[style + 1]
	local topDepth = shaftDepth * ({ 0.80, 0.72, 0.85, 0.83, 0.74 })[style + 1]
	local topX = shaftX + ({ 0, 0.10, -0.025, -0.08, 0.06 })[style + 1] * width
	local topZ = shaftZ - shaftDepth * 0.05
	local topHeight = height - shoulderY
	piece(building, base, "UpperTower", Vector3.new(topWidth, topHeight, topDepth), Vector3.new(topX, shoulderY + topHeight / 2, topZ), palette.metal, M.Concrete, true)
	curtain(building, base, topX, topZ, topWidth, topDepth, shoulderY, topHeight, palette, (style + 1) % 3)
	piece(building, base, "SetbackCornice", Vector3.new(shaftWidth + 1, 1.2, shaftDepth + 1), Vector3.new(shaftX, shoulderY, shaftZ), palette.trim, M.Concrete)
	piece(building, base, "RoofEdge", Vector3.new(topWidth + 1.4, 1.3, topDepth + 1.4), Vector3.new(topX, height, topZ), palette.metal, M.Metal)

	if style == 0 then
		-- A pair of stone piers frames a projecting glass oriel above the street.
		local bayWidth = shaftWidth * 0.30
		local bayZ = shaftZ + shaftDepth / 2 + 1.2
		piece(building, base, "GlassOriel", Vector3.new(bayWidth, shaftHeight * 0.76, 2.2), Vector3.new(shaftX, podiumHeight + shaftHeight * 0.53, bayZ), palette.glass, M.Glass)
		for _, side in { -1, 1 } do
			piece(building, base, "OrielFrame", Vector3.new(1.1, shaftHeight * 0.78, 2.6), Vector3.new(shaftX + side * bayWidth / 2, podiumHeight + shaftHeight * 0.53, bayZ), palette.trim, M.Concrete)
		end
		-- A shallow pitched metal roof references Berlin's roofscape.
		local rise = 6
		local halfDepth = topDepth / 2
		local slopeLength = math.sqrt(halfDepth * halfDepth + rise * rise)
		local angle = math.atan2(rise, halfDepth)
		piece(building, base, "RoofCore", Vector3.new(topWidth - 1, rise * 0.5, topDepth * 0.62), Vector3.new(topX, height + rise * 0.25, topZ), palette.metal, M.Metal)
		for _, side in { -1, 1 } do
			local roof = piece(building, base, "PitchedRoof", Vector3.new(topWidth + 1, 0.8, slopeLength), Vector3.new(topX, height + rise / 2, topZ + side * halfDepth / 2), palette.metal, M.Metal)
			roof.CFrame = roof.CFrame * CFrame.Angles(side * angle, 0, 0)
		end
	elseif style == 1 then
		-- A retained brick warehouse bay offsets the modern tower above it.
		local wingX = width * 0.34
		local wingHeight = height * 0.51
		piece(building, base, "BrickWing", Vector3.new(width * 0.24, wingHeight - podiumHeight, depth * 0.68), Vector3.new(wingX, (wingHeight + podiumHeight) / 2, -depth * 0.04), palette.brick, M.Brick, true)
		for i = 1, 3 do
			local y = podiumHeight + i * (wingHeight - podiumHeight) / 4
			piece(building, base, "WingWindow", Vector3.new(width * 0.14, 6, 0.5), Vector3.new(wingX, y, depth * 0.30 + 0.3), palette.glass, M.Glass)
			piece(building, base, "WingSill", Vector3.new(width * 0.17, 0.6, 0.8), Vector3.new(wingX, y - 3.2, depth * 0.30 + 0.5), palette.trim, M.Concrete)
		end
	elseif style == 2 then
		-- Deep vertical fins cast shade and recall the rhythm of stone facades.
		for _, side in { -1, 1 } do
			piece(building, base, "VerticalFin", Vector3.new(2.4, shaftHeight * 0.92, 3), Vector3.new(shaftX + side * shaftWidth * 0.32, podiumHeight + shaftHeight / 2, shaftZ + shaftDepth / 2 + 1.1), palette.trim, M.Concrete)
		end
		local wingHeight = shaftHeight * 0.78
		local wingX = -width * 0.39
		local wingZ = shaftZ + shaftDepth * 0.30 + 1.5
		piece(building, base, "StoneSideWing", Vector3.new(width * 0.18, wingHeight, shaftDepth * 0.4), Vector3.new(wingX, podiumHeight + wingHeight / 2, wingZ), palette.stone, M.Concrete, true)
		for i = 1, 3 do
			local y = podiumHeight + i * wingHeight / 4
			piece(building, base, "StoneWingWindow", Vector3.new(width * 0.11, 6, 0.5), Vector3.new(wingX, y, wingZ + shaftDepth * 0.2 + 0.3), palette.glass, M.Glass)
		end
		piece(building, base, "StoneWingCornice", Vector3.new(width * 0.18, 1, shaftDepth * 0.4), Vector3.new(wingX, podiumHeight + wingHeight, wingZ), palette.trim, M.Concrete)
	elseif style == 3 then
		-- A stack of shallow terraces softens one asymmetrical glass corner.
		for i = 1, 3 do
			local y = podiumHeight + shaftHeight * (0.18 + i * 0.18)
			local x = shaftX + shaftWidth * 0.24
			local z = shaftZ + shaftDepth / 2
			piece(building, base, "TerraceSlab", Vector3.new(shaftWidth * 0.34, 0.7, 3.4), Vector3.new(x, y, z + 1.6), palette.trim, M.Concrete)
			piece(building, base, "TerraceRail", Vector3.new(shaftWidth * 0.34, 2.2, 0.25), Vector3.new(x, y + 1.4, z + 3.2), palette.glass, M.Glass)
		end
		-- A narrow masonry stair tower rises beside the offset glass shaft.
		local towerX = -width * 0.38
		local towerWidth = width * 0.22
		local towerHeight = height * 0.89 - podiumHeight
		piece(building, base, "StairTower", Vector3.new(towerWidth, towerHeight, depth * 0.54), Vector3.new(towerX, podiumHeight + towerHeight / 2, -depth * 0.04), palette.stone, M.Concrete, true)
		piece(building, base, "StairTowerGlass", Vector3.new(towerWidth * 0.45, towerHeight * 0.83, 0.5), Vector3.new(towerX, podiumHeight + towerHeight * 0.5, depth * 0.23 + 0.3), palette.glass, M.Glass)
		piece(building, base, "StairTowerCrown", Vector3.new(towerWidth + 0.6, 1.4, depth * 0.55), Vector3.new(towerX, podiumHeight + towerHeight, -depth * 0.04), palette.trim, M.Concrete)
	else
		-- A copper-toned vertical bay and a low roof lantern create a distinct crown.
		piece(building, base, "CopperBay", Vector3.new(shaftWidth * 0.22, shaftHeight * 0.84, 1.5), Vector3.new(shaftX - shaftWidth * 0.25, podiumHeight + shaftHeight * 0.48, shaftZ + shaftDepth / 2 + 0.8), rgb(120, 128, 112), M.Metal)
		piece(building, base, "RoofLantern", Vector3.new(topWidth * 0.43, 4, topDepth * 0.40), Vector3.new(topX, height + 2, topZ), palette.glass, M.Glass)
		piece(building, base, "LanternCap", Vector3.new(topWidth * 0.46, 0.8, topDepth * 0.43), Vector3.new(topX, height + 4.2, topZ), palette.metal, M.Metal)
	end
	return building
end

-- Everyday low- and mid-rise buildings that fill most of the city. Each face is dressed with
-- a handful of parts: wrap-around window bands, then piers that cross the whole building so
-- one part shows on two opposite faces. Sooty brick, stained concrete and rooftop clutter
-- keep the streets from looking freshly unpacked.
local GRIME = {
	{ wall = rgb(126, 98, 86), trim = rgb(164, 154, 138), glass = rgb(46, 54, 58), roof = rgb(62, 62, 60), mat = M.Brick },
	{ wall = rgb(146, 142, 132), trim = rgb(108, 106, 100), glass = rgb(52, 60, 64), roof = rgb(72, 72, 68), mat = M.Concrete },
	{ wall = rgb(100, 72, 64), trim = rgb(156, 146, 130), glass = rgb(40, 46, 50), roof = rgb(56, 56, 56), mat = M.Brick },
	{ wall = rgb(170, 160, 140), trim = rgb(124, 116, 102), glass = rgb(54, 62, 66), roof = rgb(78, 76, 72), mat = M.Concrete },
	{ wall = rgb(128, 132, 128), trim = rgb(90, 94, 94), glass = rgb(42, 52, 58), roof = rgb(68, 70, 70), mat = M.Concrete },
	{ wall = rgb(138, 88, 70), trim = rgb(190, 180, 160), glass = rgb(46, 56, 60), roof = rgb(60, 58, 56), mat = M.Brick },
	{ wall = rgb(156, 128, 100), trim = rgb(106, 90, 74), glass = rgb(48, 56, 58), roof = rgb(72, 68, 64), mat = M.Brick },
	{ wall = rgb(112, 108, 100), trim = rgb(150, 144, 132), glass = rgb(38, 46, 52), roof = rgb(58, 60, 60), mat = M.Concrete },
}
local AWNINGS = { rgb(112, 44, 38), rgb(44, 72, 58), rgb(50, 60, 90), rgb(146, 106, 48), rgb(66, 66, 66) }
local GROUND_FLOOR = 12
local STOREY = 10

function CityBuildings.block(parent: Instance, base: CFrame, width: number, depth: number, floors: number, variant: number): Model
	local building = Instance.new("Model")
	building.Name = "CityBlock" .. variant
	local look = GRIME[variant % #GRIME + 1]
	local height = GROUND_FLOOR + (floors - 1) * STOREY
	building:SetAttribute("LodColor", look.wall)
	building.Parent = parent

	piece(building, base, "Body", Vector3.new(width, height, depth), Vector3.new(0, height / 2, 0), look.wall, look.mat, true)
	piece(building, base, "Plinth", Vector3.new(width + 0.4, 1.6, depth + 0.4), Vector3.new(0, 0.8, 0), look.roof, M.Concrete)
	piece(building, base, "Shopfronts", Vector3.new(width + 0.3, 6.6, depth + 0.3), Vector3.new(0, 5.1, 0), look.glass, M.Glass)
	piece(building, base, "Fascia", Vector3.new(width + 0.5, 1.6, depth + 0.5), Vector3.new(0, 9.4, 0), look.trim, M.Concrete)
	for floor = 1, floors - 1 do
		local y = GROUND_FLOOR + (floor - 1) * STOREY + 5
		piece(building, base, "WindowBand", Vector3.new(width + 0.3, 4.4, depth + 0.3), Vector3.new(0, y, 0), look.glass, M.Glass)
	end
	if floors > 1 then
		local upper = height - GROUND_FLOOR
		local columns = math.max(2, math.floor(width / 12))
		for i = 1, columns - 1 do
			local x = -width / 2 + i * width / columns
			piece(building, base, "Pier", Vector3.new(1.3, upper, depth + 0.6), Vector3.new(x, GROUND_FLOOR + upper / 2, 0), look.wall, look.mat)
		end
		local rows = math.max(2, math.floor(depth / 12))
		for i = 1, rows - 1 do
			local z = -depth / 2 + i * depth / rows
			piece(building, base, "SidePier", Vector3.new(width + 0.6, upper, 1.3), Vector3.new(0, GROUND_FLOOR + upper / 2, z), look.wall, look.mat)
		end
	end
	piece(building, base, "Cornice", Vector3.new(width + 1, 1.4, depth + 1), Vector3.new(0, height + 0.3, 0), look.trim, M.Concrete)
	piece(building, base, "TarRoof", Vector3.new(width - 1.6, 0.5, depth - 1.6), Vector3.new(0, height + 0.8, 0), look.roof, M.Slate)

	-- Rooftop plant, stair huts and tanks break up the skyline seen from the quays.
	local sx = if variant % 2 == 0 then 1 else -1
	if variant % 2 == 0 or floors > 5 then
		piece(building, base, "StairHut", Vector3.new(7, 6, 8), Vector3.new(sx * width * 0.22, height + 4, -depth * 0.18), look.wall:Lerp(look.roof, 0.3), look.mat, true)
	end
	if variant % 3 ~= 1 then
		piece(building, base, "AirHandler", Vector3.new(6, 3, 8), Vector3.new(-sx * width * 0.2, height + 2.5, depth * 0.15), rgb(128, 130, 128), M.DiamondPlate)
	end
	if variant % 3 == 0 then
		local tank = piece(building, base, "WaterTank", Vector3.new(7, 6, 6), Vector3.new(-sx * width * 0.18, height + 4.5, -depth * 0.2), rgb(96, 76, 60), M.WoodPlanks)
		tank.Shape = Enum.PartType.Cylinder
		tank.CFrame = tank.CFrame * CFrame.Angles(0, 0, math.pi / 2)
	end
	if variant % 2 == 1 then
		piece(building, base, "Awning", Vector3.new(width * 0.7, 0.5, 3.2), Vector3.new(0, 9.2, depth / 2 + 1.7), AWNINGS[variant % #AWNINGS + 1], M.Fabric)
	end
	if variant % 7 == 3 and width > 24 then
		-- A tired rooftop hoarding faces the street
		local board = piece(building, base, "Billboard", Vector3.new(width * 0.7, 9, 0.6), Vector3.new(0, height + 8, depth * 0.3), rgb(196, 178, 120):Lerp(look.roof, (variant % 4) * 0.2), M.SmoothPlastic)
		board.CastShadow = true
		for _, side in { -1, 1 } do
			piece(building, base, "BillboardLeg", Vector3.new(0.6, 4, 0.6), Vector3.new(side * width * 0.28, height + 2.5, depth * 0.3 - 0.6), look.roof, M.Metal)
		end
	end
	return building
end

-- Victorian dock sheds and bonded stores: long brick halls under a pitched slate roof.
function CityBuildings.warehouse(parent: Instance, base: CFrame, width: number, depth: number, height: number, variant: number): Model
	local building = Instance.new("Model")
	building.Name = "DockWarehouse" .. variant
	local brick = ({ rgb(118, 72, 60), rgb(98, 66, 58), rgb(136, 90, 70), rgb(108, 80, 66) })[variant % 4 + 1]
	local stone = rgb(166, 152, 132)
	local slate = rgb(58, 60, 62)
	building:SetAttribute("LodColor", brick)
	building.Parent = parent

	piece(building, base, "Hall", Vector3.new(width, height, depth), Vector3.new(0, height / 2, 0), brick, M.Brick, true)
	piece(building, base, "Plinth", Vector3.new(width + 0.4, 2, depth + 0.4), Vector3.new(0, 1, 0), stone, M.Concrete)
	piece(building, base, "StringCourse", Vector3.new(width + 0.4, 1, depth + 0.4), Vector3.new(0, height * 0.55, 0), stone, M.Concrete)
	piece(building, base, "UpperWindows", Vector3.new(width - 4, 4, depth + 0.3), Vector3.new(0, height * 0.75, 0), rgb(44, 50, 52), M.Glass)
	local doors = math.max(2, math.floor(width / 22))
	for i = 1, doors do
		local x = -width / 2 + (i - 0.5) * width / doors
		piece(building, base, "LoadingDoor", Vector3.new(10, 11, depth + 0.4), Vector3.new(x, 6.5, 0), rgb(54, 60, 58), M.Metal)
	end
	local rise = math.min(depth * 0.3, 12)
	local half = depth / 2
	local slope = math.sqrt(half * half + rise * rise)
	local angle = math.atan2(rise, half)
	for _, side in { -1, 1 } do
		local roof = piece(building, base, "SlateRoof", Vector3.new(width + 1.5, 0.9, slope + 1), Vector3.new(0, height + rise / 2, side * half / 2), slate, M.Slate, true)
		roof.CFrame = roof.CFrame * CFrame.Angles(side * angle, 0, 0)
	end
	piece(building, base, "RoofFill", Vector3.new(width, rise * 0.6, depth * 0.45), Vector3.new(0, height + rise * 0.3, 0), slate, M.Slate)
	piece(building, base, "Gable", Vector3.new(width + 0.6, 2.2, 1.2), Vector3.new(0, height + 1.1, half), stone, M.Concrete)
	if variant % 2 == 0 then
		piece(building, base, "Chimney", Vector3.new(4, 14, 4), Vector3.new(width * 0.35, height + rise + 3, 0), brick, M.Brick, true)
	end
	return building
end

return CityBuildings
