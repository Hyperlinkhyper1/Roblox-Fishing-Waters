-- A contemporary civic landmark: a glass addition rises above masonry wings,
-- with a low glazed dome recalling the skyline of Berlin's historic centre.
-- The supplied frame is at street level; the principal entrance faces +Z.
local CityLandmark = {}

local rgb = Color3.fromRGB
local brick = rgb(145, 91, 75)
local darkBrick = rgb(105, 71, 65)
local stone = rgb(216, 204, 183)
local lightStone = rgb(233, 223, 203)
local glass = rgb(80, 120, 133)
local lightGlass = rgb(116, 155, 165)
local metal = rgb(61, 76, 78)
local roof = rgb(84, 90, 85)

local function piece(parent: Instance, base: CFrame, name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material, solid: boolean?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = base * CFrame.new(offset)
	part.Anchored = true
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = solid == true
	part.CanTouch = false
	part.CanQuery = solid == true
	if not solid then
		part.CastShadow = false
	end
	part.Parent = parent
	return part
end

-- Discs are horizontal cylinders: Roblox cylinders run along their X axis.
local function disc(parent: Instance, base: CFrame, name: string, diameter: number, thickness: number, position: Vector3, color: Color3, material: Enum.Material)
	local part = piece(parent, base, name, Vector3.new(thickness, diameter, diameter), position, color, material)
	part.Shape = Enum.PartType.Cylinder
	part.CFrame = base * CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
	return part
end

function CityLandmark.build(parent: Instance, base: CFrame): Model
	local hall = Instance.new("Model")
	hall.Name = "GlassCivicHall"
	hall.Parent = parent

	-- The two historic-looking brick wings frame a recessed central lobby.
	-- Separate collision bodies preserve the stepped outline at street level.
	for _, side in { -1, 1 } do
		local x = side * 44
		piece(hall, base, "BrickWing", Vector3.new(40, 41, 64), Vector3.new(x, 20.5, 0), brick, Enum.Material.Brick, true)
		piece(hall, base, "WingPlinth", Vector3.new(41, 3, 65), Vector3.new(x, 1.5, 0), stone, Enum.Material.Concrete)
		piece(hall, base, "WingCornice", Vector3.new(42, 2, 66), Vector3.new(x, 41, 0), lightStone, Enum.Material.Concrete)
		piece(hall, base, "WingRoof", Vector3.new(40, 1.5, 64), Vector3.new(x, 42.7, 0), roof, Enum.Material.Slate)
		for _, y in { 13, 26, 38 } do
			piece(hall, base, "MasonryCourse", Vector3.new(40, 1, 0.8), Vector3.new(x, y, 32.4), stone, Enum.Material.Concrete)
		end
		for _, dx in { -13, 0, 13 } do
			for _, y in { 7.5, 19.5, 32 } do
				piece(hall, base, "HistoricWindowFrame", Vector3.new(9, 8.7, 0.6), Vector3.new(x + dx, y, 32.3), lightStone, Enum.Material.Concrete)
				piece(hall, base, "HistoricWindow", Vector3.new(7.5, 7.2, 0.7), Vector3.new(x + dx, y, 32.68), glass, Enum.Material.Glass)
				piece(hall, base, "HistoricWindowDivider", Vector3.new(0.4, 7.2, 0.25), Vector3.new(x + dx, y, 33.1), stone, Enum.Material.Concrete)
				piece(hall, base, "HistoricWindowSill", Vector3.new(9.5, 0.5, 1.2), Vector3.new(x + dx, y - 4.5, 32.7), stone, Enum.Material.Concrete)
			end
		end
		-- Wrap the masonry detail around the public side walls.
		for _, z in { -20, -6, 8, 22 } do
			for _, y in { 19.5, 32 } do
				piece(hall, base, "SideWindowFrame", Vector3.new(0.6, 8.7, 9), Vector3.new(side * 64.3, y, z), lightStone, Enum.Material.Concrete)
				piece(hall, base, "SideWindow", Vector3.new(0.7, 7.2, 7.5), Vector3.new(side * 64.68, y, z), glass, Enum.Material.Glass)
			end
		end
	end

	-- Deep stone piers and a glazed entrance sit between the older wings.
	piece(hall, base, "LobbyCore", Vector3.new(48, 35, 52), Vector3.new(0, 17.5, -6), metal, Enum.Material.Concrete, true)
	piece(hall, base, "LobbyGlazing", Vector3.new(42, 28, 0.6), Vector3.new(0, 17, 20.3), lightGlass, Enum.Material.Glass)
	for _, x in { -23, -15, -7, 1, 9, 17, 23 } do
		piece(hall, base, "LobbyMullion", Vector3.new(0.7, 28, 0.9), Vector3.new(x, 17, 20.8), metal, Enum.Material.Metal)
	end
	for _, y in { 4, 14, 24, 31 } do
		piece(hall, base, "LobbyTransom", Vector3.new(45, 0.7, 0.9), Vector3.new(0, y, 20.8), metal, Enum.Material.Metal)
	end
	for _, x in { -25, 25 } do
		piece(hall, base, "EntranceStonePier", Vector3.new(4, 37, 5), Vector3.new(x, 18.5, 22), lightStone, Enum.Material.Concrete)
	end
	piece(hall, base, "EntranceFrame", Vector3.new(17, 13, 0.6), Vector3.new(0, 6.5, 21.2), stone, Enum.Material.Concrete)
	piece(hall, base, "EntranceDoors", Vector3.new(14, 11.5, 0.7), Vector3.new(0, 5.75, 21.6), glass, Enum.Material.Glass)
	piece(hall, base, "DoorDivider", Vector3.new(0.5, 11.5, 0.3), Vector3.new(0, 5.75, 22.1), metal, Enum.Material.Metal)
	piece(hall, base, "EntranceCanopy", Vector3.new(37, 1.2, 14), Vector3.new(0, 14, 27), metal, Enum.Material.Metal)
	piece(hall, base, "CanopyEdge", Vector3.new(37, 0.45, 0.5), Vector3.new(0, 14.8, 34), lightStone, Enum.Material.Concrete)

	-- The asymmetrical setback glass addition gives the hall a modern skyline.
	-- Opaque blue-green panes lie in front of the solid core, so their colour
	-- remains visible even when the building has no simulated interior.
	piece(hall, base, "AdditionCore", Vector3.new(64, 44, 46), Vector3.new(19, 58, -8), metal, Enum.Material.Concrete, true)
	for _, sign in { -1, 1 } do
		piece(hall, base, "AdditionFrontGlass", Vector3.new(62, 41, 0.5), Vector3.new(19, 58, -8 + sign * 23.3), glass, Enum.Material.Glass)
		piece(hall, base, "AdditionSideGlass", Vector3.new(0.5, 41, 44), Vector3.new(19 + sign * 32.3, 58, -8), glass, Enum.Material.Glass)
	end
	for _, x in { -10, -2, 6, 14, 22, 30, 38, 46 } do
		for _, sign in { -1, 1 } do
			piece(hall, base, "AdditionVerticalFin", Vector3.new(0.65, 42, 0.8), Vector3.new(x, 58, -8 + sign * 23.7), stone, Enum.Material.Metal)
		end
	end
	for _, z in { -28, -20, -12, -4, 4, 12 } do
		for _, sign in { -1, 1 } do
			piece(hall, base, "AdditionSideFin", Vector3.new(0.8, 42, 0.65), Vector3.new(19 + sign * 32.7, 58, z), metal, Enum.Material.Metal)
		end
	end
	for _, y in { 38, 48, 58, 68, 78 } do
		piece(hall, base, "AdditionFloorBand", Vector3.new(66, 0.8, 48), Vector3.new(19, y, -8), lightStone, Enum.Material.Concrete)
	end
	piece(hall, base, "SetbackRoof", Vector3.new(67, 2, 49), Vector3.new(19, 81, -8), stone, Enum.Material.Concrete)
	piece(hall, base, "UpperLanternCore", Vector3.new(44, 15, 31), Vector3.new(24, 89, -9), metal, Enum.Material.Concrete, true)
	piece(hall, base, "UpperLanternGlass", Vector3.new(42, 13, 0.6), Vector3.new(24, 89, 6.8), lightGlass, Enum.Material.Glass)
	for _, x in { 5, 13, 21, 29, 37, 43 } do
		piece(hall, base, "LanternMullion", Vector3.new(0.6, 13, 0.8), Vector3.new(x, 89, 7.2), metal, Enum.Material.Metal)
	end
	piece(hall, base, "LanternCrown", Vector3.new(47, 2, 34), Vector3.new(24, 97.5, -9), lightStone, Enum.Material.Concrete)

	-- A tiered glass dome and metal rings evoke the Reichstag dome without
	-- requiring a mesh; the smaller crown sits on the opposite historic wing.
	disc(hall, base, "DomeDrum", 28, 2, Vector3.new(-39, 44.5, -4), stone, Enum.Material.Concrete)
	for level = 0, 5 do
		local diameter = 27 - level * 3
		local y = 46.5 + level * 2.1
		disc(hall, base, "DomeGlass", diameter, 2, Vector3.new(-39, y, -4), lightGlass, Enum.Material.Glass)
		disc(hall, base, "DomeRib", diameter + 0.4, 0.25, Vector3.new(-39, y + 0.9, -4), metal, Enum.Material.Metal)
	end
	disc(hall, base, "DomeCap", 9, 1.2, Vector3.new(-39, 59.5, -4), stone, Enum.Material.Concrete)

	-- Low planters and slender flagpoles dress the entrance at pedestrian scale.
	for _, side in { -1, 1 } do
		piece(hall, base, "EntrancePlanter", Vector3.new(8, 2, 4), Vector3.new(side * 31, 1, 37), stone, Enum.Material.Concrete)
		piece(hall, base, "PlanterShrub", Vector3.new(7, 2.5, 3), Vector3.new(side * 31, 3.2, 37), rgb(91, 121, 84), Enum.Material.Grass)
		piece(hall, base, "Flagpole", Vector3.new(0.7, 23, 0.7), Vector3.new(side * 57, 11.5, 37), metal, Enum.Material.Metal)
	end
	return hall
end

return CityLandmark
