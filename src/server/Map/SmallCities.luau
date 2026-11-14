-- Four compact port cities, placed at irregular bearings in the existing ocean.
-- Layouts are seeded so a server restart does not move the ports.
local HttpService = game:GetService("HttpService")
local CityBuildings = require(script.Parent.CityBuildings)
local CityLand = require(script.Parent.CityLand)
local Lod = require(script.Parent.Lod)
local Props = require(script.Parent.Props)

local Cities = { VERSION = 1, CLEARANCE = 570 }
Cities.Sites = {
	{ name = "Brambleport", x = -2800, z = -3100, seed = 31 },
	{ name = "Northwick", x = 3200, z = -2400, seed = 57 },
	{ name = "Westhaven", x = -3100, z = 1650, seed = 83 },
	{ name = "Riverton", x = 3400, z = 3850, seed = 109 },
}
local rgb, M = Color3.fromRGB, Enum.Material
local TOP = 8

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

local function part(parent: Instance, origin: Vector3, name: string, size: Vector3, x: number, y: number, z: number, color: Color3, material: Enum.Material): Part
	local p = Props.part(parent, size, CFrame.new(origin + Vector3.new(x, y, z)), color, material)
	p.Name = name
	return p
end

local function build(root: Instance, site): Model
	local rng = Random.new(site.seed)
	local origin = Vector3.new(site.x, 0, site.z)
	local city = Instance.new("Model")
	city.Name = site.name
	city:SetAttribute("SmallCityVersion", Cities.VERSION)
	city:SetAttribute("LodRoot", true)
	city:SetAttribute("LodStamp", "smallcity" .. Cities.VERSION .. "-" .. site.seed)
	city:SetAttribute("ChartLabel", site.name)
	local ground = group(city, "Ground")
	-- A straight northern quay is backed by a broad paved port; other shores vary.
	local coast = {
		{ -230, -300, "quay" }, { 230, -300 },
		{ 350 + rng:NextInteger(-25, 30), -220 }, { 405, -40 },
		{ 365, 200 + rng:NextInteger(-25, 25) }, { 250, 320 },
		{ -30, 365 + rng:NextInteger(-25, 25) }, { -275, 300 },
		{ -390, 150 }, { -400, -110 }, { -330, -260 },
	}
	coast = CityLand.roughen(coast, 100, 12)
	local chart = {}
	for _, point in coast do table.insert(chart, { site.x + point[1], site.z + point[2] }) end
	city:SetAttribute("ChartCoast", HttpService:JSONEncode(chart))
	CityLand.fill(ground, coast, origin, TOP, -30, rgb(101, 116, 82), M.Grass)
	CityLand.shore(ground, coast, origin, TOP)

	local streets = group(ground, "CityStreets")
	local asphalt = rgb(62, 64, 65)
	-- The grid joins the port apron and remains fully on land.
	for _, x in { -180, -60, 60, 180 } do
		part(streets, origin, "Street", Vector3.new(16, 0.35, 340), x, TOP + 0.18, 40, asphalt, M.Asphalt)
	end
	for _, z in { -120, 0, 120, 200 } do
		part(streets, origin, "Street", Vector3.new(410, 0.35, 16), 0, TOP + 0.18, z, asphalt, M.Asphalt)
	end
	local blocks = group(ground, "CityBlocks")
	for row, z in { -60, 60, 160 } do
		for column, x in { -120, 0, 120 } do
			local height = rng:NextInteger(42, 100)
			CityBuildings.build(blocks, CFrame.new(origin + Vector3.new(x, TOP + 0.4, z)), 55, if row == 3 then 45 else 64, height, rng:NextInteger(1, 16))
		end
		task.wait()
	end

	local port = group(ground, "IndustrialPort")
	part(port, origin, "PortApron", Vector3.new(460, 0.5, 140), 0, TOP + 0.25, -230, rgb(136, 135, 126), M.Concrete)
	-- A pier projects into open water and connects directly to the quay.
	part(port, origin, "CargoPier", Vector3.new(75, 6, 90), -125, TOP - 3, -343, rgb(130, 130, 124), M.Concrete)
	local warehouses = group(port, "Warehouses")
	for _, x in { -150, 0, 150 } do
		part(warehouses, origin, "Warehouse", Vector3.new(90, 24, 42), x, TOP + 12.5, -180, rgb(133, 137, 133), M.Concrete)
		part(warehouses, origin, "WarehouseRoof", Vector3.new(94, 2, 46), x, TOP + 25.5, -180, rgb(72, 78, 80), M.Metal)
		part(warehouses, origin, "LoadingDoor", Vector3.new(22, 13, 0.5), x, TOP + 7, -201.3, rgb(72, 78, 80), M.Metal)
	end
	local containerColors = { rgb(151, 68, 52), rgb(49, 89, 118), rgb(160, 137, 87), rgb(78, 113, 93) }
	for row = 1, 2 do
		for col = 1, 5 do
			local x, z = -195 + (col - 1) * 70, -252 - (row - 1) * 24
			part(port, origin, "ShippingContainer", Vector3.new(32, 9, 13), x, TOP + 5, z, containerColors[rng:NextInteger(1, #containerColors)], M.Metal)
			if rng:NextNumber() < 0.4 then
				part(port, origin, "ShippingContainer", Vector3.new(32, 9, 13), x, TOP + 14, z, containerColors[rng:NextInteger(1, #containerColors)], M.Metal)
			end
		end
	end
	for _, x in { -70, 170 } do
		local crane = group(port, "CargoCrane")
		for _, dx in { -12, 12 } do
			part(crane, origin, "CraneLeg", Vector3.new(3, 60, 3), x + dx, TOP + 30, -282, rgb(207, 166, 61), M.Metal)
		end
		part(crane, origin, "CraneBeam", Vector3.new(30, 4, 4), x, TOP + 60, -282, rgb(207, 166, 61), M.Metal)
		part(crane, origin, "CraneBoom", Vector3.new(4, 4, 85), x, TOP + 62, -310, rgb(207, 166, 61), M.Metal)
		part(crane, origin, "CraneCable", Vector3.new(0.6, 36, 0.6), x, TOP + 42, -345, rgb(56, 58, 58), M.Metal)
	end
	for x = -210, 210, 35 do
		part(port, origin, "Bollard", Vector3.new(2.5, 2, 2.5), x, TOP + 1, -295, rgb(49, 53, 53), M.Metal)
	end
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
	if not needsBuild then return end
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
		if not city then build(root, site); task.wait() end
	end
	local shells = root:FindFirstChild("Lod")
	if shells then shells:Destroy() end
end

return Cities
