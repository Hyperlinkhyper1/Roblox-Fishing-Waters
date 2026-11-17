-- Four compact port towns, placed at irregular bearings in the existing ocean.
-- Each site has its own coast, street pattern, building stock and landmarks; only the
-- north quay, streaming wrapper and migration are shared. Layouts are seeded so a
-- server restart does not move the towns.
local HttpService = game:GetService("HttpService")
local Builders = require(script.Parent.SmallCityBuilders)
local CityBuildings = require(script.Parent.CityBuildings)
local CityDetail = require(script.Parent.CityDetail)
local CityLand = require(script.Parent.CityLand)
local Lod = require(script.Parent.Lod)
local Props = require(script.Parent.Props)

local Cities = { VERSION = 2, CLEARANCE = 570 }
Cities.Sites = {
	{ name = "Brambleport", x = -2800, z = -3100, seed = 31, profile = "Fishing" },
	{ name = "Northwick", x = 3200, z = -2400, seed = 57, profile = "Industry" },
	{ name = "Westhaven", x = -3100, z = 1650, seed = 83, profile = "Resort" },
	{ name = "Riverton", x = 3400, z = 3850, seed = 109, profile = "River" },
}
local rgb, M = Color3.fromRGB, Enum.Material
local TOP = 8
local PAVE = TOP + 0.4
local BEACH = 0.9

local TREE_COLORS = {
	Fishing = { rgb(62, 96, 58), rgb(74, 110, 64), rgb(52, 84, 54) },
	Industry = { rgb(66, 84, 58), rgb(78, 92, 62), rgb(60, 78, 56) },
	Resort = { rgb(84, 132, 68), rgb(96, 146, 76), rgb(72, 120, 64) },
	River = { rgb(62, 104, 64), rgb(76, 120, 72), rgb(54, 92, 58) },
}

local COASTS = {
	Fishing = function()
		return CityLand.roughen({
			{ -210, -300, "quay" }, { 80, -300 },
			{ 170, -286 }, { 250, -240 }, { 315, -150 }, { 348, -30 },
			{ 330, 95 }, { 270, 205 }, { 170, 280 }, { 30, 325 },
			{ -130, 315 }, { -260, 260 }, { -338, 170 }, { -368, 50 },
			{ -350, -95 }, { -315, -205 }, { -265, -268 },
		}, 90, 12)
	end,
	Industry = function()
		return CityLand.roughen({
			{ -300, -300, "quay" }, { 260, -300 },
			{ 350, -260 }, { 385, -160 }, { 395, -20 }, { 370, 120 },
			{ 300, 240 }, { 180, 320 }, { 0, 340 }, { -180, 325 },
			{ -300, 250 }, { -365, 140 }, { -385, 0 }, { -375, -150 },
			{ -340, -260 },
		}, 100, 11)
	end,
	Resort = function()
		return CityLand.roughen({
			{ -320, -300, "quay" }, { 40, -300 },
			{ 150, -286 }, { 245, -245 }, { 320, -175 }, { 370, -80 },
			{ 380, 40 }, { 350, 150 }, { 290, 240 }, { 190, 300 }, { 60, 335 },
			{ -80, 332, "beach" }, { -200, 302, "beach" }, { -285, 245, "beach" },
			{ -340, 170, "beach" }, { -365, 80, "beach" }, { -370, -20, "beach" },
			{ -350, -140, "beach" }, { -330, -240 },
		}, 95, 10)
	end,
	River = function()
		return CityLand.roughen({
			{ -260, -300, "quay" }, { 20, -300 },
			{ 35, -300, "riverwall" }, { 35, 80, "riverwall" },
			{ 95, 80, "riverwall" }, { 95, -300 },
			{ 110, -300, "quay" }, { 260, -300 },
			{ 340, -245 }, { 380, -150 }, { 385, -20 }, { 355, 110 },
			{ 310, 220 }, { 230, 300 }, { 120, 340 }, { 0, 345 },
			{ -130, 330 }, { -240, 290 }, { -320, 220 }, { -365, 130 },
			{ -375, 10 }, { -355, -120 }, { -320, -240 },
		}, 95, 11)
	end,
}

function Cities.coast(profile: string): { any }
	return (COASTS[profile] or COASTS.Fishing)()
end

function Cities.reserve(placed)
	for _, site in Cities.Sites do
		table.insert(placed, { position = Vector2.new(site.x, site.z), radius = Cities.CLEARANCE })
	end
end

local function group(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name, model.Parent = name, parent
	return model
end

local function buildPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, solid: boolean?): Part
	local p = Props.part(parent, size, cf, color, material)
	p.Name = name
	if not solid then
		p.CanCollide, p.CanQuery, p.CastShadow = false, false, false
	end
	if material == M.Glass then
		p.Reflectance = 0.04
	end
	return p
end

local function part(parent: Instance, origin: Vector3, name: string, size: Vector3, x: number, y: number, z: number, color: Color3, material: Enum.Material, solid: boolean?): Part
	return buildPart(parent, name, size, CFrame.new(origin + Vector3.new(x, y, z)), color, material, solid)
end

local function slab(parent: Instance, origin: Vector3, name: string, size: Vector3, x: number, z: number, y: number, yaw: number?, color: Color3, material: Enum.Material): Part
	local cf = CFrame.new(origin + Vector3.new(x, y, z))
	if yaw and yaw ~= 0 then cf = cf * CFrame.Angles(0, yaw, 0) end
	return buildPart(parent, name, size, cf, color, material, true)
end

local function deco(parent: Instance, origin: Vector3, name: string, size: Vector3, x: number, y: number, z: number, color: Color3, material: Enum.Material): Part
	return part(parent, origin, name, size, x, y, z, color, material, false)
end

local function lot(origin: Vector3, x: number, z: number, yaw: number?, y: number?): CFrame
	return CFrame.new(origin + Vector3.new(x, y or PAVE, z)) * CFrame.Angles(0, yaw or 0, 0)
end

local function road(parent: Instance, origin: Vector3, look, x: number, z: number, w: number, d: number, yaw: number?)
	return slab(parent, origin, "Street", Vector3.new(w, 0.35, d), x, z, TOP + 0.18, yaw, look.asphalt, M.Asphalt)
end

local function pavement(parent: Instance, origin: Vector3, look, x: number, z: number, w: number, d: number, yaw: number?)
	return slab(parent, origin, "Pavement", Vector3.new(w, 0.24, d), x, z, TOP + 0.28, yaw, look.pavement, M.Concrete)
end

local function row(ctx, x: number, z: number, yaw: number, count: number, width: number, depth: number, floors: number, variant: number)
	local base = lot(ctx.origin, x, z, yaw)
	local total = count * width + (count - 1) * 2
	for i = 1, count do
		local cf = base * CFrame.new(-total / 2 + (i - 0.5) * (width + 2), 0, 0)
		Builders.terrace(ctx.buildings, cf, width, depth, floors, variant + i, Builders.look(ctx.profile, ctx.rng))
	end
	task.wait()
end

local function hotel(ctx, x: number, z: number, yaw: number, width: number, depth: number, floors: number, variant: number, grand: boolean?)
	Builders.hotel(ctx.buildings, lot(ctx.origin, x, z, yaw), width, depth, floors, variant, Builders.look(ctx.profile, ctx.rng), grand)
end

local function factory(ctx, x: number, z: number, yaw: number, width: number, depth: number, floors: number, variant: number)
	Builders.factory(ctx.buildings, lot(ctx.origin, x, z, yaw), width, depth, floors, variant, Builders.look(ctx.profile, ctx.rng))
	task.wait()
end

local function furnitureGroup(ctx, name: string): Model
	local model = group(ctx.ground, name)
	model:SetAttribute("LodColor", ctx.look.pavement)
	model:SetAttribute("CityDetailSource", true)
	return model
end

local function furniture(model: Model, ctx, position: Vector3, yaw: number?)
	return Builders.lamp(model, position, yaw or 0, ctx.look.lamp)
end

local function boat(ctx, parent: Instance, x: number, z: number, yaw: number, kind: string, color: Color3)
	-- The hull geometry assumes its origin is the waterline, which sits at y = 0.
	return Builders.boat(parent, Vector3.new(ctx.origin.X + x, 0, ctx.origin.Z + z), yaw, kind, color, ctx.rng)
end

local function gableRoof(parent: Instance, base: CFrame, width: number, depth: number, y: number, rise: number, color: Color3, material: Enum.Material)
	local half = depth / 2
	local slope = math.sqrt(half * half + rise * rise)
	local angle = math.atan2(rise, half)
	for _, side in { -1, 1 } do
		buildPart(
			parent,
			"RoofPanel",
			Vector3.new(width, 0.5, slope + 0.5),
			base * CFrame.new(0, y + rise / 2, side * half / 2) * CFrame.Angles(side * angle, 0, 0),
			color,
			material,
			false
		)
	end
	buildPart(parent, "RoofRidge", Vector3.new(width + 0.4, 0.4, 0.8), base * CFrame.new(0, y + rise, 0), color:Lerp(rgb(0, 0, 0), 0.22), material, false)
end

local function hoist(parent: Instance, origin: Vector3, x: number, z: number, yaw: number, color: Color3)
	local crane = group(parent, "CargoCrane")
	local base = CFrame.new(origin + Vector3.new(x, TOP, z)) * CFrame.Angles(0, yaw, 0)
	local dark = rgb(58, 60, 58)
	buildPart(crane, "CraneBase", Vector3.new(11, 2, 11), base * CFrame.new(0, 1, 0), dark, M.Metal, true)
	buildPart(crane, "CranePost", Vector3.new(2.4, 32, 2.4), base * CFrame.new(0, 17, 0), color, M.Metal, true)
	buildPart(crane, "CraneJib", Vector3.new(2, 2, 30), base * CFrame.new(0, 31, -11), color, M.Metal)
	buildPart(crane, "CraneStay", Vector3.new(0.6, 0.6, 24), base * CFrame.new(0, 26, 3) * CFrame.Angles(-0.45, 0, 0), dark, M.Metal, false)
	buildPart(crane, "CraneCable", Vector3.new(0.35, 13, 0.35), base * CFrame.new(0, 24, -24), dark, M.Metal, false)
	buildPart(crane, "CraneHook", Vector3.new(2.4, 1.2, 2.4), base * CFrame.new(0, 17, -24), color, M.Metal, false)
	buildPart(crane, "CraneCounterweight", Vector3.new(5, 3, 4), base * CFrame.new(0, 29, 5), dark, M.Metal, true)
	local beacon = buildPart(crane, "AviationBeacon", Vector3.new(0.9, 0.9, 0.9), base * CFrame.new(0, 33, -11), rgb(96, 24, 20), M.SmoothPlastic, false)
	beacon.Shape = Enum.PartType.Ball
	beacon:AddTag("AviationBeacon")
	return crane
end

local function port(ctx, spec): Model
	local o, origin = ctx.ground, ctx.origin
	local model = group(o, "IndustrialPort")
	part(model, origin, "PortApron", Vector3.new(spec.apronW, 0.5, spec.apronD), spec.apronX, TOP + 0.25, spec.apronZ, rgb(136, 135, 126), M.Concrete)
	part(model, origin, "CargoPier", Vector3.new(spec.pierW, 6, spec.pierD), spec.pierX, TOP - 3, spec.pierZ, spec.pierColor or rgb(130, 130, 124), spec.pierMat or M.Concrete)
	for x = spec.bollardFrom, spec.bollardTo, spec.bollardStep or 34 do
		part(model, origin, "Bollard", Vector3.new(2.5, 2, 2.5), x, TOP + 1, -294, rgb(49, 53, 53), M.Metal)
	end
	local warehouses = group(model, "Warehouses")
	for i, w in spec.warehouses do
		CityBuildings.warehouse(warehouses, lot(origin, w[1], w[2], w[3] or 0, TOP + 0.55), w[4], w[5], w[6], i)
	end
	for _, c in spec.cranes or {} do
		if c.kind == "container" then
			Builders.crane(model, Vector3.new(origin.X, TOP, origin.Z), c.x, c.z, "CargoCrane")
		else
			hoist(model, origin, c.x, c.z, c.yaw or 0, c.color or rgb(196, 154, 58))
		end
	end
	for _, c in spec.containers or {} do
		part(model, origin, "ShippingContainer", Vector3.new(32, 9, 13), c[1], TOP + 5, c[2], c[3], M.Metal)
		if c[4] then
			part(model, origin, "ShippingContainer", Vector3.new(32, 9, 13), c[1], TOP + 14, c[2], c[5] or c[3], M.Metal)
		end
	end
	return model
end

local function fishMarket(ctx, x: number, z: number, width: number, depth: number, yaw: number)
	local m = Instance.new("Model")
	m.Name = "FishMarket"
	m:SetAttribute("LodColor", rgb(126, 94, 64))
	m:SetAttribute("CityDetailSource", true)
	m.Parent = ctx.landmarks
	local base = lot(ctx.origin, x, z, yaw)
	local look = ctx.look
	buildPart(m, "MarketFloor", Vector3.new(width, 0.8, depth), base * CFrame.new(0, 0.4, 0), rgb(146, 142, 130), M.Cobblestone, true)
	for i = 0, 4 do
		local px = -width / 2 + 2 + i * (width - 4) / 4
		for _, side in { -1, 1 } do
			buildPart(m, "MarketPost", Vector3.new(0.9, 10, 0.9), base * CFrame.new(px, 5, side * (depth / 2 - 2)), look.door, M.WoodPlanks, false)
		end
	end
	gableRoof(m, base, width + 2, depth + 2, 10, 6, look.roof, look.roofMat)
	for i = 1, 3 do
		local pz = -depth / 2 + i * depth / 4
		buildPart(m, "FishCounter", Vector3.new(width * 0.52, 3.2, 3.2), base * CFrame.new(0, 2, pz), look.trim, M.WoodPlanks, false)
		buildPart(m, "CounterCanopy", Vector3.new(width * 0.56, 0.25, 5), base * CFrame.new(0, 7.4, pz), look.accent, M.Fabric, false)
		for _, side in { -1, 1 } do
			buildPart(m, "CounterPost", Vector3.new(0.4, 6, 0.4), base * CFrame.new(side * width * 0.22, 4, pz), look.metal, M.Metal, false)
		end
	end
	for _, side in { -1, 1 } do
		buildPart(m, "MarketSign", Vector3.new(10, 2.4, 0.4), base * CFrame.new(side * width * 0.3, 9.6, depth / 2 - 0.4), look.accent, M.SmoothPlastic, false)
	end
	for i = 1, 6 do
		local px = -width / 2 + 7 + (i - 1) * (width - 14) / 5
		local pz = if i % 2 == 0 then depth / 2 + 2 else -depth / 2 - 2
		buildPart(m, "FishCrate", Vector3.new(3, 2.4, 3), base * CFrame.new(px, 1.2, pz), rgb(150, 126, 92), M.WoodPlanks, false)
	end
end

local function beachHut(ctx, x: number, z: number, yaw: number, color: Color3)
	local m = Instance.new("Model")
	m.Name = "BeachHut"
	m:SetAttribute("LodColor", color)
	m:SetAttribute("CityDetailSource", true)
	m.Parent = ctx.landmarks
	local base = lot(ctx.origin, x, z, yaw)
	buildPart(m, "HutBody", Vector3.new(8, 7, 7), base * CFrame.new(0, 3.5, 0), color, M.WoodPlanks, true)
	gableRoof(m, base, 9, 8, 7, 3, rgb(94, 98, 96), M.Metal)
	buildPart(m, "HutDoor", Vector3.new(2.6, 5, 0.4), base * CFrame.new(0, 2.5, 3.6), rgb(242, 238, 226), M.WoodPlanks, false)
	buildPart(m, "HutWindow", Vector3.new(2, 2, 0.4), base * CFrame.new(2.6, 4.4, 3.6), rgb(68, 84, 88), M.Glass, false)
	buildPart(m, "HutStep", Vector3.new(3.4, 0.5, 1.4), base * CFrame.new(0, 0.25, 4.2), rgb(174, 168, 152), M.Concrete, false)
end

local function weir(ctx, x: number, z: number, width: number)
	local m = Instance.new("Model")
	m.Name = "Weir"
	m:SetAttribute("LodColor", rgb(116, 112, 102))
	m:SetAttribute("CityDetailSource", true)
	m.Parent = ctx.ground
	local stone, dark = rgb(118, 114, 104), rgb(62, 66, 64)
	part(m, ctx.origin, "WeirSill", Vector3.new(width, 6, 7), x, 2.5, z, stone, M.Cobblestone, true)
	for i = 0, 3 do
		part(m, ctx.origin, "WeirPier", Vector3.new(4, 11, 10), x - width / 2 + i * width / 3, 5, z, stone, M.Cobblestone, true)
	end
	for i = 0, 2 do
		local px = x - width / 2 + (i + 0.5) * width / 3
		deco(m, ctx.origin, "SluiceGate", Vector3.new(width / 3 - 5, 4, 0.6), px, 3.5, z - 2.4, dark, M.CorrodedMetal)
		deco(m, ctx.origin, "SluiceWheel", Vector3.new(1.6, 1.6, 0.5), px, 8, z - 3.4, rgb(150, 120, 64), M.Metal)
	end
	for i = 1, 4 do
		deco(m, ctx.origin, "WeirFoam", Vector3.new(width / 5, 0.35, 3), x - width / 2 + (i - 0.5) * width / 4, 5.2, z - 5.2, rgb(216, 226, 222), M.SmoothPlastic)
	end
end

local function railLine(ctx, parent: Instance, x0: number, x1: number, z: number)
	local length = x1 - x0
	local cx = (x0 + x1) / 2
	part(parent, ctx.origin, "Rail", Vector3.new(length, 0.3, 0.5), cx, TOP + 0.62, z - 2.4, rgb(82, 78, 74), M.Metal)
	part(parent, ctx.origin, "Rail", Vector3.new(length, 0.3, 0.5), cx, TOP + 0.62, z + 2.4, rgb(82, 78, 74), M.Metal)
	for x = x0, x1, 8 do
		deco(parent, ctx.origin, "RailSleeper", Vector3.new(1.4, 0.28, 6), x, TOP + 0.45, z, rgb(70, 58, 48), M.WoodPlanks)
	end
end

local function lampsAlong(parent: Model, ctx, x: number, z0: number, z1: number, step: number, yaw: number, y: number?)
	for z = z0, z1, step do
		Builders.lamp(parent, Vector3.new(ctx.origin.X + x, y or PAVE, ctx.origin.Z + z), yaw, ctx.look.lamp)
	end
end

local function lampsAcross(parent: Model, ctx, z: number, x0: number, x1: number, step: number, yaw: number, y: number?)
	for x = x0, x1, step do
		Builders.lamp(parent, Vector3.new(ctx.origin.X + x, y or PAVE, ctx.origin.Z + z), yaw, ctx.look.lamp)
	end
end

local function tree(parent: Model, ctx, x: number, z: number, y: number?)
	local colors = TREE_COLORS[ctx.profile] or TREE_COLORS.Fishing
	Builders.tree(parent, Vector3.new(ctx.origin.X + x, y or PAVE, ctx.origin.Z + z), ctx.rng, colors)
end

local function buildFishing(ctx)
	local o, ground, look = ctx.origin, ctx.ground, ctx.look
	local streets = group(ground, "CityStreets")
	road(streets, o, look, -65, -232, 290, 14)
	road(streets, o, look, -20, 40, 14, 520)
	road(streets, o, look, -15, -150, 530, 14)
	road(streets, o, look, -15, -30, 570, 14)
	road(streets, o, look, -10, 110, 560, 14)
	road(streets, o, look, -10, 230, 460, 14)
	pavement(streets, o, look, -31, 40, 8, 520)
	pavement(streets, o, look, -9, 40, 8, 520)
	pavement(streets, o, look, -65, -221, 290, 8)
	pavement(streets, o, look, 95, 67, 120, 75)
	pavement(streets, o, look, 150, 185, 80, 60)
	pavement(streets, o, look, -250, 150, 50, 50)

	local blocks = group(ground, "CityBlocks")
	ctx.buildings = blocks
	row(ctx, -49, -191, math.pi / 2, 2, 32, 26, 2, 1)
	row(ctx, -49, -90, math.pi / 2, 3, 32, 26, 3, 8)
	row(ctx, -49, 40, math.pi / 2, 3, 38, 26, 3, 16)
	row(ctx, -49, 170, math.pi / 2, 3, 32, 26, 2, 24)
	row(ctx, 8, -191, -math.pi / 2, 2, 32, 26, 2, 32)
	row(ctx, 8, -90, -math.pi / 2, 3, 32, 26, 3, 40)
	row(ctx, 8, 40, -math.pi / 2, 2, 38, 26, 3, 48)
	row(ctx, 8, 170, -math.pi / 2, 2, 42, 26, 2, 56)
	row(ctx, -160, -7, math.pi, 3, 30, 24, 2, 64)
	row(ctx, -190, 83, 0, 2, 30, 24, 2, 72)
	row(ctx, -190, 203, 0, 3, 28, 24, 2, 80)
	row(ctx, 190, 83, 0, 2, 28, 24, 2, 88)
	row(ctx, 200, 203, 0, 2, 30, 24, 3, 96)

	factory(ctx, 210, -85, -math.pi / 2, 60, 32, 2, 3)

	local landmarks = group(ground, "Landmarks")
	ctx.landmarks = landmarks
	Builders.church(landmarks, lot(o, -250, 150, math.pi / 2), 1, Builders.look("Fishing", ctx.rng))
	fishMarket(ctx, 95, 65, 100, 46, 0)
	Builders.bandstand(landmarks, lot(o, 150, 185, 0), 12, 1, Builders.look("Fishing", ctx.rng))
	Builders.harbourLight(landmarks, lot(o, 235, -225, 0), 1)

	port(ctx, {
		apronW = 250, apronX = -65, apronZ = -260, apronD = 80,
		pierW = 40, pierX = -150, pierD = 80, pierZ = -338,
		bollardFrom = -190, bollardTo = 60,
		warehouses = { { -150, -258, 0, 80, 30, 18 }, { -50, -258, 0, 80, 30, 18 } },
		cranes = { { x = -150, z = -280, yaw = 0 } },
	})
	local port = ground:FindFirstChild("IndustrialPort")
	for _, x in { -165, -138 } do
		part(port, o, "FishCrate", Vector3.new(3.2, 2.4, 3.2), x, TOP + 1.7, -325, rgb(150, 126, 92), M.WoodPlanks)
		part(port, o, "FishBarrel", Vector3.new(3, 3, 3), x, TOP + 1.5, -355, rgb(126, 96, 66), M.WoodPlanks)
	end
	Builders.railing(port, Vector3.new(o.X - 168, TOP, o.Z - 300), Vector3.new(o.X - 168, TOP, o.Z - 374), rgb(58, 62, 62))

	local harbour = group(ground, "Harbour")
	boat(ctx, harbour, -225, -340, 0.3, "Fishing", rgb(116, 146, 148))
	boat(ctx, harbour, -90, -350, -0.15, "Fishing", rgb(168, 108, 78))
	boat(ctx, harbour, 30, -338, 0.1, "Sail", rgb(170, 66, 52))

	local quay = furnitureGroup(ctx, "StreetFurnitureQuay")
	lampsAcross(quay, ctx, -221, -195, 65, 55, 0)
	for _, x in { -190, 40 } do
		Builders.bench(quay, Vector3.new(o.X + x, PAVE, o.Z - 220), math.pi)
		Builders.bin(quay, Vector3.new(o.X + x + 5, PAVE, o.Z - 221))
	end
	Builders.railing(quay, Vector3.new(o.X - 130, TOP, o.Z - 300), Vector3.new(o.X - 130, TOP, o.Z - 374), rgb(58, 62, 62))
	lampsAlong(quay, ctx, -166, -370, -305, 35, math.pi / 2, TOP)

	local main = furnitureGroup(ctx, "StreetFurnitureMain")
	lampsAlong(main, ctx, -31, -205, 265, 58, 0)
	lampsAlong(main, ctx, -9, -185, 245, 58, math.pi)
	for _, z in { -170, -70, 50, 140, 220 } do
		Builders.bench(main, Vector3.new(o.X - 31, PAVE, o.Z + z), math.pi / 2)
		Builders.bin(main, Vector3.new(o.X - 25, PAVE, o.Z + z + 4))
	end
	Builders.hydrant(main, Vector3.new(o.X - 27, PAVE, o.Z - 120))
	Builders.hydrant(main, Vector3.new(o.X - 13, PAVE, o.Z + 180))

	local market = furnitureGroup(ctx, "StreetFurnitureMarket")
	lampsAcross(market, ctx, 102, 45, 145, 40, math.pi)
	for _, x in { 62, 128 } do
		Builders.bench(market, Vector3.new(o.X + x, PAVE, o.Z + 34), 0)
		Builders.planter(market, Vector3.new(o.X + x, PAVE, o.Z + 98), 5, look.accent)
	end
	Builders.kiosk(market, Vector3.new(o.X + 45, PAVE, o.Z + 65), -math.pi / 2, look)
	Builders.tree(market, Vector3.new(o.X + 140, PAVE, o.Z + 60), ctx.rng, TREE_COLORS.Fishing)
	tree(market, ctx, 40, 45)

	local green = furnitureGroup(ctx, "StreetFurnitureGreen")
	local flower = rgb(196, 92, 78)
	for _, at in { { 108, 158 }, { 108, 214 }, { 192, 158 } } do
		tree(green, ctx, at[1], at[2])
	end
	for _, at in { { 128, 155 }, { 172, 155 }, { 128, 215 }, { 172, 215 } } do
		Builders.bench(green, Vector3.new(o.X + at[1], PAVE, o.Z + at[2]), if at[2] < 185 then 0 else math.pi)
	end
	Builders.planter(green, Vector3.new(o.X + 150, PAVE, o.Z + 152), 6, flower)
	Builders.planter(green, Vector3.new(o.X + 150, PAVE, o.Z + 220), 6, flower)
	tree(green, ctx, -250, 128)
	tree(green, ctx, -222, 128)
end

local function buildIndustry(ctx)
	local o, ground, look = ctx.origin, ctx.ground, ctx.look
	local streets = group(ground, "CityStreets")
	road(streets, o, look, -20, -170, 540, 16)
	for _, x in { -270, -140, -10, 120, 250 } do road(streets, o, look, x, 20, 16, 520) end
	road(streets, o, look, -20, -140, 600, 16)
	road(streets, o, look, -10, -20, 620, 16)
	road(streets, o, look, -10, 100, 600, 16)
	road(streets, o, look, -10, 220, 520, 16)
	pavement(streets, o, look, -80, 160, 120, 80)
	pavement(streets, o, look, -20, -178, 540, 8)

	local blocks = group(ground, "CityBlocks")
	ctx.buildings = blocks
	row(ctx, -300, -80, math.pi / 2, 3, 30, 24, 4, 1)
	row(ctx, -300, 40, math.pi / 2, 2, 30, 24, 4, 9)
	row(ctx, -168, -80, math.pi / 2, 2, 34, 24, 3, 17)
	row(ctx, -168, 40, math.pi / 2, 2, 34, 24, 3, 25)
	row(ctx, 40, -80, -math.pi / 2, 3, 30, 24, 3, 33)
	row(ctx, 40, 40, -math.pi / 2, 3, 30, 24, 3, 41)
	row(ctx, 40, 160, -math.pi / 2, 3, 30, 24, 4, 49)
	row(ctx, 150, -80, math.pi / 2, 2, 34, 24, 3, 57)
	row(ctx, 150, 160, math.pi / 2, 2, 32, 24, 3, 65)
	row(ctx, 222, -100, math.pi / 2, 2, 30, 24, 3, 73)
	row(ctx, -220, 250, math.pi, 3, 32, 24, 3, 81)

	factory(ctx, 300, 40, -math.pi / 2, 100, 40, 3, 1)
	factory(ctx, 150, 250, 0, 90, 40, 3, 6)
	factory(ctx, -280, 180, math.pi / 2, 80, 34, 3, 11)

	local landmarks = group(ground, "Landmarks")
	ctx.landmarks = landmarks
	Builders.clockTower(landmarks, lot(o, -80, 180, 0), 42, 1, Builders.look("Industry", ctx.rng))
	Builders.gasometer(landmarks, lot(o, -320, 100, 0), 22, 28, 1, Builders.look("Industry", ctx.rng))
	Builders.waterTower(landmarks, lot(o, 60, 270, 0), 26, 1, Builders.look("Industry", ctx.rng))
	Builders.smokestack(landmarks, lot(o, 335, -60, 0), 52, 7, 1, Builders.look("Industry", ctx.rng))
	Builders.smokestack(landmarks, lot(o, 260, 120, 0), 42, 6, 2, Builders.look("Industry", ctx.rng))

	port(ctx, {
		apronW = 470, apronX = -30, apronZ = -230, apronD = 140,
		pierW = 70, pierX = -170, pierD = 90, pierZ = -343,
		bollardFrom = -260, bollardTo = 240,
		warehouses = { { -210, -268, 0, 100, 32, 24 }, { -80, -268, 0, 100, 32, 24 }, { 50, -268, 0, 100, 32, 24 } },
		cranes = { { x = -145, z = -288, kind = "container" }, { x = 130, z = -288, kind = "container" } },
		containers = (function()
			local list = {}
			local colors = { rgb(151, 68, 52), rgb(49, 89, 118), rgb(160, 137, 87), rgb(78, 113, 93) }
			for row = 0, 1 do
				for col = 0, 9 do
					local c = colors[(row * 10 + col) % #colors + 1]
					table.insert(list, { -240 + col * 34, -225 + row * 20, c, row == 0 and col % 3 == 0, colors[(col + 2) % #colors + 1] })
				end
			end
			return list
		end)(),
	})
	local port = ground:FindFirstChild("IndustrialPort")
	railLine(ctx, port, -260, 220, -185)
	railLine(ctx, port, -260, 220, -181)

	local harbour = group(ground, "Harbour")
	boat(ctx, harbour, -235, -358, 0.25, "Barge", rgb(96, 88, 78))
	boat(ctx, harbour, 60, -348, -0.1, "Fishing", rgb(70, 90, 100))

	local quay = furnitureGroup(ctx, "StreetFurnitureQuay")
	lampsAcross(quay, ctx, -178, -250, 240, 58, 0)
	for _, x in { -245, 200 } do
		Builders.bench(quay, Vector3.new(o.X + x, PAVE, o.Z - 177), math.pi)
		Builders.bin(quay, Vector3.new(o.X + x + 5, PAVE, o.Z - 178))
	end
	local civic = furnitureGroup(ctx, "StreetFurnitureCivic")
	lampsAcross(civic, ctx, 122, -130, -30, 32, math.pi)
	lampsAcross(civic, ctx, 198, -130, -30, 32, 0)
	for _, at in { { -125, 128 }, { -35, 128 }, { -125, 192 }, { -35, 192 } } do
		tree(civic, ctx, at[1], at[2])
	end
	Builders.planter(civic, Vector3.new(o.X - 80, PAVE, o.Z + 128), 6, rgb(180, 146, 62))
	Builders.planter(civic, Vector3.new(o.X - 80, PAVE, o.Z + 196), 6, rgb(180, 146, 62))
	Builders.hydrant(civic, Vector3.new(o.X - 18, PAVE, o.Z + 160))
	local works = furnitureGroup(ctx, "StreetFurnitureWorks")
	lampsAlong(works, ctx, -264, -120, 60, 60, math.pi)
	lampsAlong(works, ctx, 244, -120, 60, 60, 0)
	for _, z in { -110, 0, 160, 240 } do
		tree(works, ctx, -320, z)
	end
	for _, z in { -60, 140 } do
		tree(works, ctx, 335, z)
	end
	Builders.bin(works, Vector3.new(o.X + 126, PAVE, o.Z + 12))
	Builders.bin(works, Vector3.new(o.X - 126, PAVE, o.Z + 12))
end

local function buildResort(ctx)
	local o, ground, look = ctx.origin, ctx.ground, ctx.look
	local streets = group(ground, "CityStreets")
	road(streets, o, look, -150, -232, 340, 14)
	pavement(streets, o, look, -313, 30, 16, 340)
	for _, x in { -200, -70, 60, 190 } do road(streets, o, look, x, 30, 14, 460) end
	for _, z in { -140, -20, 100 } do road(streets, o, look, -40, z, 540, 14) end
	road(streets, o, look, -5, 210, 510, 14)
	pavement(streets, o, look, -150, -223, 340, 8)
	pavement(streets, o, look, -240, 200, 90, 60)

	local blocks = group(ground, "CityBlocks")
	ctx.buildings = blocks
	hotel(ctx, -285, -80, -math.pi / 2, 90, 30, 4, 1)
	hotel(ctx, -285, 40, -math.pi / 2, 100, 32, 6, 2, true)
	hotel(ctx, -285, 140, -math.pi / 2, 90, 30, 5, 3)
	row(ctx, -235, -80, math.pi / 2, 3, 30, 22, 3, 10)
	row(ctx, -235, 40, math.pi / 2, 2, 30, 22, 3, 18)
	row(ctx, -235, 150, math.pi / 2, 2, 32, 22, 2, 26)
	row(ctx, -110, -80, math.pi / 2, 3, 30, 22, 3, 34)
	row(ctx, -110, 40, math.pi / 2, 2, 30, 22, 3, 42)
	row(ctx, -110, 150, math.pi / 2, 2, 30, 22, 2, 50)
	row(ctx, 40, -80, -math.pi / 2, 3, 30, 22, 2, 58)
	row(ctx, 40, 40, -math.pi / 2, 2, 30, 22, 3, 66)
	row(ctx, 40, 150, -math.pi / 2, 3, 28, 22, 2, 74)
	row(ctx, 150, -80, math.pi / 2, 2, 32, 22, 3, 82)
	row(ctx, 150, 150, math.pi / 2, 2, 32, 22, 2, 90)
	row(ctx, 250, 60, math.pi / 2, 2, 28, 22, 2, 98)
	row(ctx, -70, -180, 0, 3, 32, 22, 2, 106)
	row(ctx, 120, -180, 0, 3, 32, 22, 2, 114)

	local landmarks = group(ground, "Landmarks")
	ctx.landmarks = landmarks
	Builders.bandstand(landmarks, lot(o, -240, 200, 0), 12, 1, Builders.look("Resort", ctx.rng))
	Builders.pavilion(landmarks, CFrame.new(o + Vector3.new(0, TOP, -462)), 13, 1, Builders.look("Resort", ctx.rng))
	local hutColors = { rgb(214, 136, 118), rgb(116, 168, 158), rgb(222, 186, 112), rgb(136, 148, 190), rgb(178, 196, 156) }
	for i, z in { -100, -60, -20, 20, 60 } do
		beachHut(ctx, -334, z, 0, hutColors[i])
	end

	port(ctx, {
		apronW = 320, apronX = -140, apronZ = -255, apronD = 90,
		pierW = 34, pierX = 0, pierD = 180, pierZ = -388,
		bollardFrom = -300, bollardTo = 10,
		warehouses = { { -250, -255, 0, 80, 30, 20 } },
		cranes = { { x = -90, z = -278, yaw = 0 } },
	})

	local harbour = group(ground, "Harbour")
	boat(ctx, harbour, -70, -360, 0.4, "Sail", rgb(72, 160, 152))
	boat(ctx, harbour, 70, -365, -0.2, "Fishing", rgb(214, 172, 78))

	local promenade = furnitureGroup(ctx, "StreetFurniturePromenade")
	lampsAlong(promenade, ctx, -318, -130, 190, 45, math.pi)
	for _, z in { -120, -40, 40, 120, 180 } do
		Builders.bench(promenade, Vector3.new(o.X - 312, PAVE, o.Z + z), -math.pi / 2)
		Builders.bin(promenade, Vector3.new(o.X - 306, PAVE, o.Z + z + 4))
	end
	Builders.kiosk(promenade, Vector3.new(o.X - 312, PAVE, o.Z - 20), math.pi / 2, look)
	Builders.kiosk(promenade, Vector3.new(o.X - 312, PAVE, o.Z + 110), math.pi / 2, look)
	for _, z in { -130, -50, 30, 170 } do
		Builders.planter(promenade, Vector3.new(o.X - 302, PAVE, o.Z + z), 5, look.accent)
	end

	local beach = furnitureGroup(ctx, "StreetFurnitureBeach")
	for _, z in { -110, -75, -40, -5, 30, 65, 100, 135 } do
		Builders.parasol(beach, Vector3.new(o.X - 388, BEACH, o.Z + z), ctx.rng:NextNumber(0, math.pi), look.accent)
		Builders.lounger(beach, Vector3.new(o.X - 380, BEACH, o.Z + z + 4), math.pi / 2, rgb(238, 234, 222))
	end
	Builders.kiosk(beach, Vector3.new(o.X - 350, BEACH, o.Z - 135), math.pi / 2, look)

	local pier = furnitureGroup(ctx, "StreetFurniturePier")
	lampsAlong(pier, ctx, -12, -440, -315, 35, math.pi / 2, TOP)
	lampsAlong(pier, ctx, 12, -440, -315, 35, -math.pi / 2, TOP)
	Builders.railing(pier, Vector3.new(o.X - 15, TOP, o.Z - 300), Vector3.new(o.X - 15, TOP, o.Z - 438), rgb(92, 98, 98))
	Builders.railing(pier, Vector3.new(o.X + 15, TOP, o.Z - 300), Vector3.new(o.X + 15, TOP, o.Z - 438), rgb(92, 98, 98))
	Builders.bench(pier, Vector3.new(o.X - 10, TOP, o.Z - 330), math.pi)
	Builders.bench(pier, Vector3.new(o.X + 10, TOP, o.Z - 410), 0)
	Builders.kiosk(pier, Vector3.new(o.X - 8, TOP, o.Z - 302), math.pi / 2, look)

	local gardens = furnitureGroup(ctx, "StreetFurnitureGardens")
	for _, at in { { -274, 214 }, { -206, 214 }, { -274, 186 }, { -206, 186 } } do
		tree(gardens, ctx, at[1], at[2])
	end
	for _, at in { { -260, 206 }, { -220, 206 }, { -260, 194 }, { -220, 194 } } do
		Builders.bench(gardens, Vector3.new(o.X + at[1], PAVE, o.Z + at[2]), if at[2] > 200 then math.pi else 0)
	end
	Builders.planter(gardens, Vector3.new(o.X - 240, PAVE, o.Z + 224), 7, rgb(220, 112, 94))
	for _, at in { { 210, -120 }, { 260, -40 }, { 210, 40 }, { 260, 120 } } do
		tree(gardens, ctx, at[1], at[2])
	end
end

local function buildRiver(ctx)
	local o, ground, look = ctx.origin, ctx.ground, ctx.look
	local streets = group(ground, "CityStreets")
	road(streets, o, look, -120, -232, 260, 14)
	road(streets, o, look, 180, -232, 140, 14)
	for _, x in { -250, -150, -50, 170, 270 } do road(streets, o, look, x, 40, 16, 520) end
	road(streets, o, look, -137, -140, 325, 16)
	road(streets, o, look, 202, -140, 195, 16)
	road(streets, o, look, -137, 40, 325, 16)
	road(streets, o, look, 202, 40, 195, 16)
	road(streets, o, look, 0, 220, 560, 16)
	pavement(streets, o, look, 18, 35, 12, 500)
	pavement(streets, o, look, 108, 35, 12, 500)
	pavement(streets, o, look, -180, 108, 120, 150)
	pavement(streets, o, look, 65, 120, 65, 50)

	local blocks = group(ground, "CityBlocks")
	ctx.buildings = blocks
	row(ctx, -275, -180, math.pi / 2, 2, 30, 22, 3, 1)
	row(ctx, -275, -50, math.pi / 2, 2, 30, 22, 3, 9)
	row(ctx, -275, 130, math.pi / 2, 3, 30, 22, 3, 17)
	row(ctx, -255, 205, math.pi / 2, 2, 30, 22, 2, 25)
	row(ctx, -175, -180, math.pi / 2, 2, 28, 22, 3, 33)
	row(ctx, -175, -50, math.pi / 2, 2, 28, 22, 3, 41)
	row(ctx, -175, 264, math.pi / 2, 2, 30, 22, 2, 49)
	row(ctx, -78, -180, math.pi / 2, 2, 26, 22, 2, 57)
	row(ctx, -78, -50, math.pi / 2, 2, 26, 22, 3, 65)
	row(ctx, -78, 130, math.pi / 2, 2, 26, 22, 2, 73)
	row(ctx, -78, 264, math.pi / 2, 2, 26, 22, 2, 81)
	row(ctx, 145, -180, -math.pi / 2, 2, 30, 22, 3, 89)
	row(ctx, 145, -50, -math.pi / 2, 2, 30, 22, 3, 97)
	row(ctx, 145, 130, -math.pi / 2, 3, 28, 22, 2, 105)
	row(ctx, 145, 264, -math.pi / 2, 2, 30, 22, 2, 113)
	row(ctx, 230, -180, math.pi / 2, 2, 30, 22, 3, 121)
	row(ctx, 230, -50, math.pi / 2, 2, 30, 22, 3, 129)
	row(ctx, 230, 130, math.pi / 2, 2, 30, 22, 2, 137)
	row(ctx, 225, 258, math.pi / 2, 2, 26, 22, 2, 145)

	local landmarks = group(ground, "Landmarks")
	ctx.landmarks = landmarks
	Builders.bandstand(landmarks, lot(o, 65, 120, 0), 11, 1, Builders.look("River", ctx.rng))
	Builders.marketHall(landmarks, lot(o, -175, 81, 0), 100, 38, 1, Builders.look("River", ctx.rng))
	Builders.clockTower(landmarks, lot(o, -215, 170, 0), 34, 1, Builders.look("River", ctx.rng))
	Builders.mill(landmarks, lot(o, 115, -90, math.pi), 1, Builders.look("River", ctx.rng))
	Builders.bridge(landmarks, CFrame.new(o + Vector3.new(65, TOP - 0.45, -140)), 80, 18, 1, Builders.look("River", ctx.rng))
	Builders.bridge(landmarks, CFrame.new(o + Vector3.new(65, TOP - 0.45, 40)), 80, 18, 2, Builders.look("River", ctx.rng))
	weir(ctx, 65, 72, 54)

	port(ctx, {
		apronW = 260, apronX = -120, apronZ = -250, apronD = 100,
		pierW = 48, pierX = -180, pierD = 90, pierZ = -343,
		bollardFrom = -240, bollardTo = 0,
		warehouses = { { -200, -255, 0, 80, 30, 20 }, { -90, -255, 0, 80, 30, 20 } },
		cranes = { { x = -145, z = -282, yaw = 0 } },
		containers = {
			{ -220, -222, rgb(151, 68, 52) }, { -182, -222, rgb(49, 89, 118) },
			{ -144, -222, rgb(160, 137, 87) }, { -106, -222, rgb(78, 113, 93) },
			{ -68, -222, rgb(151, 68, 52) }, { -30, -222, rgb(49, 89, 118) },
		},
	})
	local eastQuay = group(ground, "RiversideQuay")
	part(eastQuay, o, "QuayPaving", Vector3.new(150, 0.4, 80), 185, TOP + 0.2, -260, rgb(154, 150, 138), M.Cobblestone)
	for x = 120, 250, 26 do
		part(eastQuay, o, "Bollard", Vector3.new(2.2, 2, 2.2), x, TOP + 1, -294, rgb(49, 53, 53), M.Metal)
	end

	local river = group(ground, "River")
	boat(ctx, river, 65, -190, 0, "Narrowboat", rgb(72, 108, 92))
	boat(ctx, river, 65, -60, 0, "Narrowboat", rgb(122, 84, 64))
	boat(ctx, river, 65, 5, 0, "Barge", rgb(96, 76, 60))
	boat(ctx, group(ground, "Harbour"), -120, -340, 0.1, "Barge", rgb(118, 82, 58))

	local riverWest = furnitureGroup(ctx, "StreetFurnitureRiverWest")
	lampsAlong(riverWest, ctx, 24, -200, 280, 60, 0)
	for _, z in { -160, -40, 80, 190 } do
		Builders.bench(riverWest, Vector3.new(o.X + 18, PAVE, o.Z + z), math.pi / 2)
		Builders.bin(riverWest, Vector3.new(o.X + 13, PAVE, o.Z + z + 4))
	end
	Builders.railing(riverWest, Vector3.new(o.X + 30, TOP, o.Z - 218), Vector3.new(o.X + 30, TOP, o.Z + 74), rgb(70, 74, 72))
	local riverEast = furnitureGroup(ctx, "StreetFurnitureRiverEast")
	lampsAlong(riverEast, ctx, 108, -200, 280, 60, math.pi)
	for _, z in { -120, 0, 120, 220 } do
		Builders.bench(riverEast, Vector3.new(o.X + 114, PAVE, o.Z + z), -math.pi / 2)
		Builders.bin(riverEast, Vector3.new(o.X + 119, PAVE, o.Z + z + 4))
	end
	Builders.railing(riverEast, Vector3.new(o.X + 100, TOP, o.Z - 218), Vector3.new(o.X + 100, TOP, o.Z + 74), rgb(70, 74, 72))

	local market = furnitureGroup(ctx, "StreetFurnitureMarket")
	lampsAcross(market, ctx, 196, -225, -135, 30, 0)
	lampsAcross(market, ctx, 108, -225, -135, 30, math.pi)
	for _, at in { { -225, 112 }, { -135, 112 }, { -225, 190 }, { -135, 190 } } do
		tree(market, ctx, at[1], at[2])
	end
	for _, x in { -215, -135 } do
		Builders.bench(market, Vector3.new(o.X + x, PAVE, o.Z + 150), math.pi / 2)
		Builders.planter(market, Vector3.new(o.X + x, PAVE, o.Z + 196), 6, look.accent)
	end
	local garden = furnitureGroup(ctx, "StreetFurnitureGarden")
	lampsAcross(garden, ctx, 142, 38, 94, 28, math.pi)
	for _, at in { { 36, 102 }, { 96, 102 }, { 36, 140 }, { 96, 140 } } do
		tree(garden, ctx, at[1], at[2])
	end
	for _, at in { { 52, 118 }, { 78, 118 }, { 52, 128 }, { 78, 128 } } do
		Builders.bench(garden, Vector3.new(o.X + at[1], PAVE, o.Z + at[2]), if at[2] < 123 then 0 else math.pi)
	end
	Builders.planter(garden, Vector3.new(o.X + 65, PAVE, o.Z + 98), 6, rgb(188, 150, 74))
	local quay = furnitureGroup(ctx, "StreetFurnitureQuay")
	lampsAcross(quay, ctx, -218, -235, 240, 55, 0)
	Builders.hydrant(quay, Vector3.new(o.X - 60, PAVE, o.Z - 218))
end

local BUILDERS = {
	Fishing = buildFishing,
	Industry = buildIndustry,
	Resort = buildResort,
	River = buildRiver,
}

local function prepareDetails(city: Instance)
	CityDetail.prepare(city)
	-- Saved cities can already have split streaming pieces. Pin each bounded
	-- prepared building as one unit so its local facade follows its collision core.
	for _, model in city:GetDescendants() do
		if model:IsA("Model") and model:HasTag("CityDetail") then Lod.pin(model) end
	end
end

local function build(root: Instance, site): Model
	local rng = Random.new(site.seed)
	local origin = Vector3.new(site.x, 0, site.z)
	local city = Instance.new("Model")
	city.Name = site.name
	city:SetAttribute("SmallCityVersion", Cities.VERSION)
	city:SetAttribute("SmallCityProfile", site.profile)
	city:SetAttribute("LodRoot", true)
	city:SetAttribute("LodStamp", "smallcity" .. Cities.VERSION .. "-" .. site.seed)
	city:SetAttribute("ChartLabel", site.name)
	local ground = group(city, "Ground")
	local coast = Cities.coast(site.profile)
	local chart = {}
	for _, point in coast do table.insert(chart, { site.x + point[1], site.z + point[2] }) end
	city:SetAttribute("ChartCoast", HttpService:JSONEncode(chart))
	CityLand.fill(ground, coast, origin, TOP, -30, rgb(101, 116, 82), M.Grass)
	CityLand.shore(ground, coast, origin, TOP)

	local ctx = {
		origin = origin,
		city = city,
		profile = site.profile,
		rng = rng,
		ground = ground,
		look = Builders.look(site.profile, rng),
	}
	local builder = BUILDERS[site.profile] or buildFishing
	builder(ctx)
	-- Match the main city's facade budget before these buildings first replicate.
	prepareDetails(city)
	Lod.prepareIsland(city)
	city.Parent = root
	return city
end

function Cities.ensure(root: Instance)
	local needsBuild = false
	for _, site in Cities.Sites do
		local city = root:FindFirstChild(site.name)
		if not city or city:GetAttribute("SmallCityVersion") ~= Cities.VERSION then needsBuild = true; break end
	end
	if not needsBuild then
		-- Current-version baked cities still need the facade migration. Their parts
		-- can already be under GroundChunk models after startup streaming preparation.
		for _, site in Cities.Sites do prepareDetails(root:FindFirstChild(site.name) :: Instance) end
		return
	end
	-- Migrate baked maps by removing only overlapping procedural islands, never player property.
	local resumed = os.clock()
	for _, model in root:GetDescendants() do
		if os.clock() - resumed > 0.05 then task.wait(); resumed = os.clock() end
		if model:IsA("Model") and model.Name == "Island" then
			local ground = model:FindFirstChild("Ground")
			if ground and ground:IsA("Model") then
				local bounds, size = ground:GetBoundingBox()
				for _, site in Cities.Sites do
					local distance = (Vector2.new(bounds.X, bounds.Z) - Vector2.new(site.x, site.z)).Magnitude
					if distance < Cities.CLEARANCE + math.max(size.X, size.Z) / 2 then model:Destroy(); break end
				end
			end
		end
	end
	for _, site in Cities.Sites do
		local city = root:FindFirstChild(site.name)
		if city and city:GetAttribute("SmallCityVersion") ~= Cities.VERSION then city:Destroy(); city = nil end
		if not city then
			build(root, site)
			task.wait()
		else
			prepareDetails(city)
		end
	end
	local shells = root:FindFirstChild("Lod")
	if shells then shells:Destroy() end
end

return Cities
