-- Decorative, floor-placed furniture shared by the showroom, previews and bases.
local Decorations = {}

local ids = {
	PottedPlant = true,
	FlowerPlanter = true,
	WoodenBench = true,
	FloorLamp = true,
	BarrelDisplay = true,
	CrateStack = true,
	RopeBasket = true,
	LifeRingStand = true,
	AnchorDisplay = true,
	FishingNetDisplay = true,
	NauticalSign = true,
	ShipWheelDisplay = true,
	FishStatue = true,
	Aquarium = true,
	Rug = true,
	CoatRack = true,
	Bookcase = true,
	WallShelf = true,
}

local wood = Color3.fromRGB(123, 82, 52)
local darkWood = Color3.fromRGB(75, 51, 37)
local cream = Color3.fromRGB(235, 218, 178)
local green = Color3.fromRGB(67, 124, 75)
local blue = Color3.fromRGB(65, 131, 152)
local metal = Color3.fromRGB(78, 89, 91)
local orange = Color3.fromRGB(201, 103, 63)

function Decorations.has(id: string): boolean
	return ids[id] == true
end

function Decorations.build(parent: Instance, frame: CFrame, id: string): Model
	local model = Instance.new("Model")
	model.Name = id
	model.Parent = parent
	local function part(name, size, cf, color, material, shape)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame = name, size, frame * cf
		p.Color, p.Material = color, material or Enum.Material.Wood
		p.Anchored = true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if shape then
			p.Shape = shape
		end
		p.Parent = model
		return p
	end
	local function block(name, size, x, y, z, color, material)
		return part(name, size, CFrame.new(x, y, z), color, material)
	end
	local function ball(name, size, x, y, z, color, material)
		return part(name, size, CFrame.new(x, y, z), color, material, Enum.PartType.Ball)
	end
	local function post(name, diameter, height, x, y, z, color, material)
		return part(
			name,
			Vector3.new(height, diameter, diameter),
			CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2),
			color,
			material,
			Enum.PartType.Cylinder
		)
	end
	local function ring(name, radius, y, z, color, thickness)
		for i = 0, 11 do
			local angle = i * math.pi / 6
			part(
				name,
				Vector3.new(thickness, radius * 0.54, thickness),
				CFrame.new(math.sin(angle) * radius, y + math.cos(angle) * radius, z) * CFrame.Angles(0, 0, -angle),
				color
			)
		end
	end
	local function plant(x, z, flower)
		post("Pot", 0.85, 0.75, x, 0.375, z, orange, Enum.Material.Concrete)
		post("Stem", 0.1, 1.05, x, 1.2, z, green)
		for i = 0, 4 do
			local angle = i * math.pi * 2 / 5
			ball(
				"Leaf",
				Vector3.new(0.55, 0.7, 0.55),
				x + math.sin(angle) * 0.35,
				1.45 + (i % 2) * 0.25,
				z + math.cos(angle) * 0.35,
				green,
				Enum.Material.Grass
			)
		end
		if flower then
			ball("Flower", Vector3.new(0.4, 0.4, 0.4), x, 1.95, z, cream, Enum.Material.Fabric)
		end
	end
	-- Sizes follow FurnitureCatalog: each piece fits its 1x1 or 1x2 grid cells.
	if id == "PottedPlant" then
		post("Saucer", 1.5, 0.1, 0, 0.05, 0, Color3.fromRGB(176, 88, 54), Enum.Material.Concrete)
		post("Pot", 1.25, 1.1, 0, 0.6, 0, orange, Enum.Material.Concrete)
		post("PotRim", 1.4, 0.18, 0, 1.12, 0, Color3.fromRGB(176, 88, 54), Enum.Material.Concrete)
		post("Soil", 1.15, 0.04, 0, 1.2, 0, darkWood, Enum.Material.Ground)
		post("Stem", 0.14, 1.2, 0, 1.8, 0, darkWood)
		for i = 0, 7 do
			local angle = i * math.pi * 2 / 8
			local reach = if i % 2 == 0 then 0.75 else 0.5
			ball(
				"Leaf",
				Vector3.new(0.9, 0.55, 0.7),
				math.sin(angle) * reach,
				1.75 + (i % 3) * 0.35,
				math.cos(angle) * reach,
				if i % 2 == 0 then green else Color3.fromRGB(88, 148, 84),
				Enum.Material.Grass
			)
		end
		ball("Crown", Vector3.new(0.9, 0.8, 0.9), 0, 2.65, 0, green, Enum.Material.Grass)
	elseif id == "FlowerPlanter" then
		block("Planter", Vector3.new(4.1, 0.8, 1.5), 0, 0.4, 0, wood, Enum.Material.WoodPlanks)
		block("PlanterRim", Vector3.new(4.2, 0.12, 1.6), 0, 0.84, 0, darkWood)
		block("Soil", Vector3.new(3.9, 0.04, 1.3), 0, 0.8, 0, darkWood, Enum.Material.Ground)
		for i = 0, 1 do
			block("PlanterBand", Vector3.new(4.12, 0.08, 1.52), 0, 0.2 + i * 0.4, 0, metal, Enum.Material.Metal)
		end
		local blooms = { cream, orange, Color3.fromRGB(214, 86, 120), cream, orange }
		for index, color in blooms do
			local x = -1.6 + (index - 1) * 0.8
			local z = if index % 2 == 0 then 0.25 else -0.2
			post("Stem", 0.08, 0.7, x, 1.15, z, green)
			ball("Leaves", Vector3.new(0.75, 0.4, 0.65), x, 1.0, z, green, Enum.Material.Grass)
			ball("Flower", Vector3.new(0.5, 0.42, 0.5), x, 1.55, z, color, Enum.Material.Fabric)
			ball("FlowerHeart", Vector3.new(0.18, 0.18, 0.18), x, 1.68, z, Color3.fromRGB(240, 200, 70), Enum.Material.SmoothPlastic)
		end
	elseif id == "WoodenBench" then
		for i = -1, 1 do
			block("SeatSlat", Vector3.new(4.1, 0.16, 0.38), 0, 1.2, 0.3 + i * 0.42, wood, Enum.Material.WoodPlanks)
		end
		for _, x in { -1.7, 1.7 } do
			block("Leg", Vector3.new(0.2, 1.1, 1.3), x, 0.55, 0.3, darkWood)
			block("Armrest", Vector3.new(0.22, 0.12, 1.4), x + (if x < 0 then -0.25 else 0.25), 1.8, 0.2, darkWood)
			block("ArmPost", Vector3.new(0.14, 0.6, 0.14), x + (if x < 0 then -0.25 else 0.25), 1.5, 0.75, darkWood)
			block("BackPost", Vector3.new(0.16, 1.5, 0.16), x, 1.9, -0.65, darkWood)
		end
		for i = 0, 1 do
			block("BackSlat", Vector3.new(4.1, 0.3, 0.12), 0, 1.75 + i * 0.5, -0.65, wood, Enum.Material.WoodPlanks)
		end
	elseif id == "FloorLamp" then
		post("Base", 1.3, 0.15, 0, 0.075, 0, metal, Enum.Material.Metal)
		post("Pole", 0.12, 3.4, 0, 1.8, 0, metal, Enum.Material.Metal)
		post("Shade", 1.4, 0.8, 0, 3.6, 0, cream, Enum.Material.Fabric)
		post("ShadeTrim", 1.45, 0.06, 0, 3.22, 0, Color3.fromRGB(190, 150, 90), Enum.Material.Fabric)
		local bulb = ball("Bulb", Vector3.new(0.4, 0.4, 0.4), 0, 3.4, 0, Color3.fromRGB(255, 236, 190), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range = Color3.fromRGB(255, 224, 166), 0.7, 12
		light.Parent = bulb
	elseif id == "BarrelDisplay" then
		post("Barrel", 2.2, 2.5, 0, 1.25, 0, wood, Enum.Material.WoodPlanks)
		post("Belly", 2.4, 1.2, 0, 1.25, 0, wood, Enum.Material.WoodPlanks)
		for _, y in { 0.3, 0.95, 1.55, 2.2 } do
			post("Band", if y == 0.95 or y == 1.55 then 2.46 else 2.26, 0.14, 0, y, 0, metal, Enum.Material.Metal)
		end
		post("Lid", 2.0, 0.06, 0, 2.53, 0, darkWood, Enum.Material.WoodPlanks)
		-- A few fish laid on ice on the lid.
		post("Ice", 1.2, 0.08, 0, 2.6, 0, Color3.fromRGB(226, 244, 248), Enum.Material.Ice)
		for i = -1, 1 do
			ball("Fish", Vector3.new(0.75, 0.2, 0.26), i * 0.15, 2.72, i * 0.3, blue, Enum.Material.SmoothPlastic)
		end
	elseif id == "CrateStack" then
		for _, spec in { { -0.85, 0.75, 0.3, 1.5 }, { 0.85, 0.75, 0.3, 1.5 }, { 0, 2.1, 0.2, 1.2 }, { 1.0, 0.45, -1.0, 0.9 } } do
			local x, y, z, s = spec[1], spec[2], spec[3], spec[4]
			block("Crate", Vector3.new(s, s, s), x, y, z, wood, Enum.Material.WoodPlanks)
			for _, dy in { -s / 2 + 0.08, s / 2 - 0.08 } do
				block("CrateTrim", Vector3.new(s + 0.04, 0.12, s + 0.04), x, y + dy, z, darkWood)
			end
			block("CrateLabel", Vector3.new(s * 0.5, s * 0.25, 0.03), x, y, z + s / 2 + 0.02, cream, Enum.Material.SmoothPlastic)
		end
	elseif id == "RopeBasket" then
		post("Basket", 1.9, 1.0, 0, 0.5, 0, cream, Enum.Material.Fabric)
		for _, y in { 0.2, 0.45, 0.7, 0.95 } do
			post("Weave", 1.96, 0.07, 0, y, 0, wood, Enum.Material.Fabric)
		end
		for i = 0, 2 do
			post("RopeCoil", 1.5 - i * 0.35, 0.18, 0, 1.08 + i * 0.16, 0, Color3.fromRGB(214, 190, 140), Enum.Material.Fabric)
		end
		part("RopeEnd", Vector3.new(0.14, 0.9, 0.14), CFrame.new(0.85, 0.75, 0.3) * CFrame.Angles(0, 0, 0.5), Color3.fromRGB(214, 190, 140), Enum.Material.Fabric)
	elseif id == "LifeRingStand" then
		block("Foot", Vector3.new(2, 0.15, 1.2), 0, 0.075, 0, darkWood)
		post("Stand", 0.14, 2.1, 0, 1.15, 0, metal, Enum.Material.Metal)
		block("Hook", Vector3.new(0.14, 0.14, 0.3), 0, 2.85, 0.1, metal, Enum.Material.Metal)
		ring("LifeRing", 0.66, 2.1, 0.12, cream, 0.24)
		for _, a in { 0, math.pi / 2, math.pi, 3 * math.pi / 2 } do
			part(
				"RedStripe",
				Vector3.new(0.26, 0.35, 0.26),
				CFrame.new(math.sin(a) * 0.66, 2.1 + math.cos(a) * 0.66, 0.12) * CFrame.Angles(0, 0, -a),
				orange,
				Enum.Material.Fabric
			)
		end
	elseif id == "AnchorDisplay" then
		block("Foot", Vector3.new(2.4, 0.2, 1.3), 0, 0.1, 0, darkWood)
		block("FootPlaque", Vector3.new(1, 0.12, 0.03), 0, 0.1, 0.66, Color3.fromRGB(196, 160, 90), Enum.Material.Metal)
		post("Shaft", 0.2, 2.2, 0, 1.3, 0, metal, Enum.Material.Metal)
		block("Crossbar", Vector3.new(1.7, 0.16, 0.18), 0, 2.05, 0, metal, Enum.Material.Metal)
		for _, side in { -1, 1 } do
			part("Fluke", Vector3.new(0.2, 1.1, 0.2), CFrame.new(side * 0.55, 0.55, 0) * CFrame.Angles(0, 0, side * 0.9), metal, Enum.Material.Metal)
			part("FlukeTip", Vector3.new(0.35, 0.3, 0.12), CFrame.new(side * 0.95, 0.85, 0) * CFrame.Angles(0, 0, side * 0.5), metal, Enum.Material.Metal)
		end
		ring("Eye", 0.2, 2.5, 0, metal, 0.08)
		-- A loop of rope through the eye.
		ring("Rope", 0.32, 2.35, 0.05, Color3.fromRGB(214, 190, 140), 0.08)
	elseif id == "FishingNetDisplay" then
		block("Foot", Vector3.new(4.1, 0.15, 1.1), 0, 0.075, 0, darkWood)
		for _, x in { -1.9, 1.9 } do
			post("Post", 0.16, 2.9, x, 1.55, 0, wood)
			ball("Finial", Vector3.new(0.26, 0.26, 0.26), x, 3.05, 0, darkWood)
		end
		block("TopRail", Vector3.new(3.9, 0.12, 0.12), 0, 2.85, 0, wood)
		for x = -1.6, 1.61, 0.4 do
			block("NetCord", Vector3.new(0.04, 2.3, 0.04), x, 1.6, 0, cream, Enum.Material.Fabric)
		end
		for y = 0.5, 2.75, 0.35 do
			block("NetCord", Vector3.new(3.7, 0.04, 0.04), 0, y, 0, cream, Enum.Material.Fabric)
		end
		-- Cork floats along the top and a couple of glass buoys caught in the mesh.
		for x = -1.4, 1.41, 0.7 do
			block("Float", Vector3.new(0.3, 0.2, 0.2), x, 2.7, 0.05, orange, Enum.Material.Fabric)
		end
		ball("GlassBuoy", Vector3.new(0.5, 0.5, 0.5), -0.7, 1.3, 0.12, Color3.fromRGB(86, 168, 140), Enum.Material.Glass).Transparency = 0.3
		ball("GlassBuoy", Vector3.new(0.4, 0.4, 0.4), 0.9, 1.8, 0.12, Color3.fromRGB(70, 120, 190), Enum.Material.Glass).Transparency = 0.3
	elseif id == "NauticalSign" then
		block("Foot", Vector3.new(3.2, 0.15, 1.1), 0, 0.075, 0, darkWood)
		for _, x in { -1.2, 1.2 } do
			post("Post", 0.15, 2.6, x, 1.4, 0, darkWood)
		end
		block("Sign", Vector3.new(3.3, 1.2, 0.2), 0, 2.1, 0, blue, Enum.Material.WoodPlanks)
		block("SignFrame", Vector3.new(3.4, 1.3, 0.14), 0, 2.1, -0.04, darkWood)
		block("SignStripe", Vector3.new(2.8, 0.08, 0.03), 0, 1.75, 0.12, cream)
		-- A little anchor emblem in the middle.
		block("EmblemShaft", Vector3.new(0.08, 0.55, 0.03), 0, 2.2, 0.12, cream)
		block("EmblemBar", Vector3.new(0.35, 0.07, 0.03), 0, 2.4, 0.12, cream)
		block("EmblemFoot", Vector3.new(0.5, 0.07, 0.03), 0, 1.95, 0.12, cream)
		for _, x in { -1.6, 1.6 } do
			ball("RopeKnot", Vector3.new(0.2, 0.2, 0.2), x, 2.75, 0.06, Color3.fromRGB(214, 190, 140), Enum.Material.Fabric)
		end
	elseif id == "ShipWheelDisplay" then
		block("Foot", Vector3.new(2.4, 0.15, 1.2), 0, 0.075, 0, darkWood)
		post("Stand", 0.16, 2.1, 0, 1.15, 0, darkWood)
		ring("Wheel", 0.8, 2.2, 0, wood, 0.14)
		ring("InnerRing", 0.42, 2.2, 0, darkWood, 0.08)
		for i = 0, 3 do
			part("Spoke", Vector3.new(0.1, 2.3, 0.1), CFrame.new(0, 2.2, 0) * CFrame.Angles(0, 0, i * math.pi / 4), darkWood)
		end
		for i = 0, 7 do
			local a = i * math.pi / 4
			ball("Handle", Vector3.new(0.16, 0.16, 0.16), math.sin(a) * 1.15, 2.2 + math.cos(a) * 1.15, 0, wood)
		end
		ball("Hub", Vector3.new(0.36, 0.36, 0.36), 0, 2.2, 0, Color3.fromRGB(196, 160, 90), Enum.Material.Metal)
	elseif id == "FishStatue" then
		block("Plinth", Vector3.new(2.2, 0.3, 2.2), 0, 0.15, 0, darkWood)
		block("Pedestal", Vector3.new(1.8, 0.8, 1.8), 0, 0.7, 0, metal, Enum.Material.Slate)
		block("Plaque", Vector3.new(1, 0.25, 0.03), 0, 0.7, 0.92, Color3.fromRGB(196, 160, 90), Enum.Material.Metal)
		-- A leaping fish on a short rod, mid-jump.
		post("Rod", 0.1, 0.6, 0, 1.4, 0, metal, Enum.Material.Metal)
		local bronze = Color3.fromRGB(176, 128, 72)
		part("Fish", Vector3.new(1.8, 0.85, 0.6), CFrame.new(0, 2.05, 0) * CFrame.Angles(0, 0, 0.35), bronze, Enum.Material.Metal, Enum.PartType.Ball)
		part("Tail", Vector3.new(0.16, 0.8, 0.6), CFrame.new(-0.95, 1.7, 0) * CFrame.Angles(0, 0, 0.75), bronze, Enum.Material.Metal)
		part("Fin", Vector3.new(0.5, 0.35, 0.08), CFrame.new(0, 2.5, 0) * CFrame.Angles(0, 0, 0.35), bronze, Enum.Material.Metal)
		ball("Eye", Vector3.new(0.12, 0.12, 0.12), 0.6, 2.35, 0.27, darkWood)
	elseif id == "Aquarium" then
		-- A long tank that fills two cells along a wall.
		block("Cabinet", Vector3.new(8.1, 1.4, 1.9), 0, 0.7, 0, darkWood)
		for i = -2, 2 do
			block("CabinetDoor", Vector3.new(1.5, 1.05, 0.04), i * 1.6, 0.7, 0.96, wood)
		end
		block("TankBase", Vector3.new(8, 0.12, 1.8), 0, 1.46, 0, metal, Enum.Material.Metal)
		local water = block("Water", Vector3.new(7.8, 1.8, 1.6), 0, 2.42, 0, blue, Enum.Material.Glass)
		water.Transparency, water.CanCollide = 0.55, false
		block("Sand", Vector3.new(7.7, 0.2, 1.5), 0, 1.62, 0, Color3.fromRGB(220, 200, 150), Enum.Material.Sand)
		for _, x in { -4.0, 4.0 } do
			block("TankCorner", Vector3.new(0.1, 1.9, 1.8), x, 2.42, 0, metal, Enum.Material.Metal)
		end
		block("Lid", Vector3.new(8.1, 0.16, 1.9), 0, 3.4, 0, darkWood)
		local lamp = block("TankLamp", Vector3.new(7.4, 0.04, 0.3), 0, 3.31, 0, Color3.fromRGB(200, 240, 255), Enum.Material.Neon)
		local light = Instance.new("SurfaceLight")
		light.Face, light.Brightness, light.Range, light.Color = Enum.NormalId.Bottom, 0.6, 4, Color3.fromRGB(170, 220, 255)
		light.Parent = lamp
		-- Weed, a rock arch and a little school of fish.
		for i, x in { -3.3, -2.6, 1.8, 3.2 } do
			block("Weed", Vector3.new(0.18, 0.7 + (i % 2) * 0.5, 0.18), x, 1.95 + (i % 2) * 0.25, -0.4, green, Enum.Material.Grass)
		end
		ball("Rock", Vector3.new(1.2, 0.7, 0.9), -0.8, 1.85, -0.3, Color3.fromRGB(120, 120, 116), Enum.Material.Slate)
		ball("Rock", Vector3.new(0.8, 0.5, 0.7), 0.6, 1.8, 0.2, Color3.fromRGB(140, 136, 128), Enum.Material.Slate)
		for i, spec in { { -2.0, 2.6, orange }, { -1.4, 2.9, orange }, { 0.4, 2.3, cream }, { 2.4, 2.7, Color3.fromRGB(240, 210, 60) }, { 2.9, 2.2, orange } } do
			local fish = ball("Fish", Vector3.new(0.5, 0.25, 0.18), spec[1], spec[2], (i % 2) * 0.3 - 0.15, spec[3], Enum.Material.SmoothPlastic)
			fish.CanCollide = false
		end
	elseif id == "Rug" then
		-- A long runner across two cells.
		block("Rug", Vector3.new(8.1, 0.08, 3.9), 0, 0.04, 0, blue, Enum.Material.Fabric)
		block("Field", Vector3.new(7.3, 0.02, 3.1), 0, 0.09, 0, Color3.fromRGB(176, 72, 58), Enum.Material.Fabric)
		for _, z in { -1.65, 1.65 } do
			block("Border", Vector3.new(7.7, 0.02, 0.12), 0, 0.1, z, cream, Enum.Material.Fabric)
		end
		for _, x in { -3.85, 3.85 } do
			block("Border", Vector3.new(0.12, 0.02, 3.4), x, 0.1, 0, cream, Enum.Material.Fabric)
			for z = -1.6, 1.61, 0.4 do
				block("Tassel", Vector3.new(0.22, 0.03, 0.08), x + (if x < 0 then -0.1 else 0.1), 0.03, z, cream, Enum.Material.Fabric)
			end
		end
		-- A row of diamonds down the middle.
		for x = -2.4, 2.41, 1.6 do
			part("Diamond", Vector3.new(0.9, 0.02, 0.9), CFrame.new(x, 0.11, 0) * CFrame.Angles(0, math.pi / 4, 0), cream, Enum.Material.Fabric)
			part("DiamondCore", Vector3.new(0.45, 0.02, 0.45), CFrame.new(x, 0.12, 0) * CFrame.Angles(0, math.pi / 4, 0), blue, Enum.Material.Fabric)
		end
	elseif id == "CoatRack" then
		post("Base", 1.5, 0.15, 0, 0.075, 0, darkWood)
		for i = 0, 3 do
			local a = i * math.pi / 2 + math.pi / 4
			part("Foot", Vector3.new(0.14, 0.12, 0.8), CFrame.new(math.sin(a) * 0.45, 0.15, math.cos(a) * 0.45) * CFrame.Angles(0, a, 0), darkWood)
		end
		post("Pole", 0.17, 3.6, 0, 1.9, 0, wood)
		ball("Finial", Vector3.new(0.3, 0.3, 0.3), 0, 3.75, 0, darkWood)
		for i = 0, 3 do
			local a = i * math.pi / 2
			part("Hook", Vector3.new(0.12, 0.8, 0.12), CFrame.new(math.sin(a) * 0.25, 3.3, math.cos(a) * 0.25) * CFrame.Angles(0, -a, math.pi / 3), wood)
		end
		-- A scarf and a sou'wester left on the hooks.
		block("Scarf", Vector3.new(0.2, 1.2, 0.45), 0.42, 2.8, 0, orange, Enum.Material.Fabric)
		post("HatBrim", 0.9, 0.06, 0, 3.55, -0.4, Color3.fromRGB(236, 196, 60), Enum.Material.Fabric)
		ball("HatCrown", Vector3.new(0.55, 0.4, 0.55), 0, 3.7, -0.4, Color3.fromRGB(236, 196, 60), Enum.Material.Fabric)
	elseif id == "Bookcase" or id == "WallShelf" then
		local tall = id == "Bookcase"
		local height = if tall then 4.2 else 2.4
		local depth = if tall then 1.4 else 1.2
		block("Back", Vector3.new(4.0, height, 0.1), 0, height / 2, -depth / 2 + 0.05, darkWood)
		for _, x in { -2.0, 2.0 } do
			block("Side", Vector3.new(0.18, height, depth), x, height / 2, 0, wood)
		end
		block("Crown", Vector3.new(4.2, 0.16, depth), 0, height + 0.08, 0, darkWood)
		local shelves = if tall then { 0.12, 1.15, 2.2, 3.2 } else { 0.12, 1.2 }
		for _, y in shelves do
			block("Shelf", Vector3.new(3.85, 0.12, depth - 0.1), 0, y, 0.03, wood)
		end
		local spines = { blue, orange, cream, green, Color3.fromRGB(150, 50, 46), blue }
		for row, y in shelves do
			if tall then
				-- Books on every shelf, with a gap and a leaning volume at the end.
				for i = 0, 7 do
					if i ~= 5 then
						local h = 0.62 + ((i * 7 + row * 3) % 4) * 0.07
						block("Book", Vector3.new(0.28, h, 0.75), -1.65 + i * 0.32, y + 0.06 + h / 2, -0.05, spines[(i + row) % #spines + 1], Enum.Material.Fabric)
					end
				end
				part("Book", Vector3.new(0.28, 0.66, 0.75), CFrame.new(1.3, y + 0.4, -0.05) * CFrame.Angles(0, 0, -0.35), spines[row % #spines + 1], Enum.Material.Fabric)
			else
				-- Seaside keepsakes: a ship in a bottle, shells and a small lantern.
				local bottle = part("Bottle", Vector3.new(1.1, 0.45, 0.45), CFrame.new(-1.1, y + 0.29, 0), Color3.fromRGB(150, 200, 190), Enum.Material.Glass, Enum.PartType.Cylinder)
				bottle.Transparency = 0.4
				block("ShipHull", Vector3.new(0.5, 0.1, 0.14), -1.1, y + 0.22, 0, darkWood)
				block("ShipSail", Vector3.new(0.04, 0.22, 0.2), -1.1, y + 0.38, 0, cream, Enum.Material.Fabric)
				ball("Shell", Vector3.new(0.4, 0.22, 0.32), 0.2, y + 0.17, 0.1, Color3.fromRGB(244, 214, 196), Enum.Material.SmoothPlastic)
				ball("Shell", Vector3.new(0.3, 0.18, 0.26), 0.6, y + 0.15, -0.1, cream, Enum.Material.SmoothPlastic)
				block("LanternBox", Vector3.new(0.4, 0.55, 0.4), 1.35, y + 0.34, 0, metal, Enum.Material.Metal)
				block("LanternGlow", Vector3.new(0.3, 0.35, 0.3), 1.35, y + 0.34, 0.06, Color3.fromRGB(255, 214, 140), Enum.Material.Neon)
			end
		end
	end
	return model
end

return Decorations
