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
	if id == "PottedPlant" then
		plant(0, 0, false)
	elseif id == "FlowerPlanter" then
		block("Planter", Vector3.new(2.8, 0.7, 1.2), 0, 0.35, 0, wood)
		for x = -1, 1 do
			post("Stem", 0.08, 0.7, x, 1.0, 0, green)
			ball(
				"Flower",
				Vector3.new(0.55, 0.5, 0.55),
				x,
				1.45,
				0,
				if x == 0 then cream else orange,
				Enum.Material.Fabric
			)
			ball("Leaves", Vector3.new(0.7, 0.35, 0.6), x, 0.9, 0, green, Enum.Material.Grass)
		end
	elseif id == "WoodenBench" then
		block("Seat", Vector3.new(3.8, 0.22, 1.3), 0, 1.15, 0, wood, Enum.Material.WoodPlanks)
		for _, x in { -1.5, 1.5 } do
			block("Leg", Vector3.new(0.2, 1.15, 1.1), x, 0.575, 0, darkWood)
			block("BackPost", Vector3.new(0.16, 1.2, 0.16), x, 1.75, -0.55, darkWood)
		end
		block("Back", Vector3.new(3.8, 0.55, 0.16), 0, 2.05, -0.55, wood)
	elseif id == "FloorLamp" then
		post("Base", 1.1, 0.15, 0, 0.075, 0, metal, Enum.Material.Metal)
		post("Pole", 0.12, 3.2, 0, 1.7, 0, metal, Enum.Material.Metal)
		post("Shade", 1.2, 0.75, 0, 3.5, 0, cream, Enum.Material.Fabric)
		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range = Color3.fromRGB(255, 224, 166), 0.7, 12
		light.Parent = model:FindFirstChild("Shade")
	elseif id == "BarrelDisplay" then
		post("Barrel", 2.1, 2.3, 0, 1.15, 0, wood, Enum.Material.WoodPlanks)
		for _, y in { 0.4, 1.9 } do
			post("Band", 2.16, 0.14, 0, y, 0, metal, Enum.Material.Metal)
		end
	elseif id == "CrateStack" then
		for _, spec in { { -0.65, 0.65, 0 }, { 0.65, 0.65, 0 }, { 0, 1.95, 0 } } do
			block("Crate", Vector3.new(1.25, 1.25, 1.25), spec[1], spec[2], spec[3], wood, Enum.Material.WoodPlanks)
			block("CrateTrim", Vector3.new(1.25, 0.1, 0.06), spec[1], spec[2], 0.64, darkWood)
		end
	elseif id == "RopeBasket" then
		post("Basket", 1.65, 0.9, 0, 0.45, 0, cream, Enum.Material.Fabric)
		for _, y in { 0.2, 0.45, 0.7 } do
			post("Weave", 1.7, 0.07, 0, y, 0, wood, Enum.Material.Fabric)
		end
		ball("Rope", Vector3.new(1.15, 0.28, 1.15), 0, 0.95, 0, cream, Enum.Material.Fabric)
	elseif id == "LifeRingStand" then
		block("Foot", Vector3.new(1.8, 0.15, 1), 0, 0.075, 0, darkWood)
		post("Stand", 0.12, 2, 0, 1.1, 0, metal, Enum.Material.Metal)
		ring("LifeRing", 0.66, 2.1, 0, cream, 0.24)
		for _, a in { 0, math.pi / 2, math.pi, 3 * math.pi / 2 } do
			part(
				"RedStripe",
				Vector3.new(0.26, 0.35, 0.26),
				CFrame.new(math.sin(a) * 0.66, 2.1 + math.cos(a) * 0.66, 0) * CFrame.Angles(0, 0, -a),
				orange,
				Enum.Material.Fabric
			)
		end
	elseif id == "AnchorDisplay" then
		block("Foot", Vector3.new(2.2, 0.16, 1.1), 0, 0.08, 0, darkWood)
		post("Shaft", 0.18, 2, 0, 1.18, 0, metal, Enum.Material.Metal)
		block("Crossbar", Vector3.new(1.5, 0.15, 0.16), 0, 1.9, 0, metal, Enum.Material.Metal)
		for _, side in { -1, 1 } do
			part(
				"Fluke",
				Vector3.new(0.18, 1.0, 0.18),
				CFrame.new(side * 0.5, 0.45, 0) * CFrame.Angles(0, 0, side * 0.9),
				metal,
				Enum.Material.Metal
			)
		end
		ring("Eye", 0.2, 2.3, 0, metal, 0.08)
	elseif id == "FishingNetDisplay" then
		block("Foot", Vector3.new(2.8, 0.15, 1.1), 0, 0.075, 0, darkWood)
		for _, x in { -1.2, 1.2 } do
			post("Post", 0.14, 2.7, x, 1.45, 0, wood)
		end
		for x = -1, 1, 0.4 do
			block("NetCord", Vector3.new(0.04, 2.3, 0.04), x, 1.45, 0, cream, Enum.Material.Fabric)
		end
		for y = 0.4, 2.5, 0.35 do
			block("NetCord", Vector3.new(2.4, 0.04, 0.04), 0, y, 0, cream, Enum.Material.Fabric)
		end
	elseif id == "NauticalSign" then
		block("Foot", Vector3.new(2.7, 0.15, 1), 0, 0.075, 0, darkWood)
		for _, x in { -0.9, 0.9 } do
			post("Post", 0.13, 2.4, x, 1.3, 0, darkWood)
		end
		block("Sign", Vector3.new(2.7, 1.1, 0.2), 0, 2, 0, blue, Enum.Material.WoodPlanks)
		block("SignStripe", Vector3.new(2.3, 0.08, 0.03), 0, 2, 0.12, cream)
	elseif id == "ShipWheelDisplay" then
		block("Foot", Vector3.new(2.2, 0.15, 1), 0, 0.075, 0, darkWood)
		post("Stand", 0.14, 2, 0, 1.1, 0, darkWood)
		ring("Wheel", 0.8, 2.1, 0, wood, 0.14)
		for i = 0, 3 do
			part(
				"Spoke",
				Vector3.new(0.1, 1.9, 0.1),
				CFrame.new(0, 2.1, 0) * CFrame.Angles(0, 0, i * math.pi / 4),
				darkWood
			)
		end
		ball("Hub", Vector3.new(0.32, 0.32, 0.32), 0, 2.1, 0, cream)
	elseif id == "FishStatue" then
		block("Pedestal", Vector3.new(1.8, 0.6, 1.8), 0, 0.3, 0, metal, Enum.Material.Slate)
		ball("Fish", Vector3.new(1.6, 0.8, 0.6), 0, 1.35, 0, blue, Enum.Material.Metal)
		part("Tail", Vector3.new(0.16, 0.75, 0.55), CFrame.new(-0.85, 1.35, 0), blue, Enum.Material.Metal)
		ball("Eye", Vector3.new(0.12, 0.12, 0.12), 0.5, 1.48, 0.3, darkWood)
	elseif id == "Aquarium" then
		block("Cabinet", Vector3.new(3.8, 0.8, 1.8), 0, 0.4, 0, darkWood)
		local water = block("Water", Vector3.new(3.5, 1.6, 1.5), 0, 1.7, 0, blue, Enum.Material.Glass)
		water.Transparency = 0.45
		block("Lid", Vector3.new(3.8, 0.12, 1.8), 0, 2.56, 0, darkWood)
		for _, x in { -1, 0, 1 } do
			ball("Fish", Vector3.new(0.5, 0.25, 0.2), x, 1.35 + (x + 1) * 0.3, 0, orange, Enum.Material.SmoothPlastic)
		end
	elseif id == "Rug" then
		block("Rug", Vector3.new(3.9, 0.08, 2.9), 0, 0.04, 0, blue, Enum.Material.Fabric)
		for _, z in { -1.15, 1.15 } do
			block("Border", Vector3.new(3.5, 0.02, 0.1), 0, 0.09, z, cream, Enum.Material.Fabric)
		end
	elseif id == "CoatRack" then
		post("Base", 1.5, 0.15, 0, 0.075, 0, darkWood)
		post("Pole", 0.17, 3.5, 0, 1.85, 0, wood)
		for i = 0, 3 do
			local a = i * math.pi / 2
			part(
				"Hook",
				Vector3.new(0.12, 0.8, 0.12),
				CFrame.new(math.sin(a) * 0.25, 3.3, math.cos(a) * 0.25) * CFrame.Angles(0, -a, math.pi / 3),
				wood
			)
		end
	elseif id == "Bookcase" or id == "WallShelf" then
		local height = if id == "Bookcase" then 3.6 else 2.1
		block("Back", Vector3.new(2.8, height, 0.12), 0, height / 2, -0.6, darkWood)
		for _, x in { -1.3, 1.3 } do
			block("Side", Vector3.new(0.15, height, 1.2), x, height / 2, 0, wood)
		end
		local shelves = if id == "Bookcase" then { 0.1, 1.25, 2.4, 3.5 } else { 0.1, 1.0, 2.0 }
		for _, y in shelves do
			block("Shelf", Vector3.new(2.7, 0.12, 1.2), 0, y, 0, wood)
		end
		for _, x in { -0.9, -0.55, -0.2, 0.5, 0.8 } do
			block(
				"Book",
				Vector3.new(0.25, 0.65, 0.65),
				x,
				0.48,
				-0.1,
				if x < 0 then blue else orange,
				Enum.Material.Fabric
			)
		end
	end
	return model
end

return Decorations
