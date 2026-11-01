-- Exercises Harbour's shop-plot clearing (the village houses, lamps and cross
-- streets generated where each base's shop stands, across the ring road) with
-- small yaw-only CFrame mocks. Run: lute run scripts/shop-plot.luau
local fs = require("@lute/fs")
local luau = require("@lute/luau")

local file = fs.open("src/server/Map/Harbour.luau", "r")
local source = string.gsub(fs.read(file), "\r\n", "\n")
fs.close(file)
local first = string.find(source, "local SHOP_PLOT_VERSION", 1, true)
local last = select(2, string.find(source, "\tisland:SetAttribute(\"ShopPlotVersion\", SHOP_PLOT_VERSION)\nend\n", 1, true))
assert(first and last, "Harbour shop-plot section moved")

local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

local function vectorType()
	local mt = {}
	local function new(x, y, z)
		return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, mt)
	end
	mt.__add = function(a, b) return new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
	mt.__sub = function(a, b) return new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
	mt.__mul = function(a, b)
		if type(a) == "number" then a, b = b, a end
		return new(a.X * b, a.Y * b, a.Z * b)
	end
	mt.__div = function(a, b) return new(a.X / b, a.Y / b, a.Z / b) end
	mt.__index = function(a, key)
		if key == "Magnitude" then
			return math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z)
		elseif key == "Unit" then
			return a / a.Magnitude
		elseif key == "Dot" then
			return function(self, b) return self.X * b.X + self.Y * b.Y + self.Z * b.Z end
		end
		return nil
	end
	return { new = new }
end
local Vector3 = vectorType()
-- Vector2 stores (x, y) in X and Y like Roblox.
local Vector2 = vectorType()

-- Yaw-only frames: position plus a turn about +Y (Roblox's sense).
local cframe = {}
local CFrame = {}
local function frame(position, yaw)
	return setmetatable({ Position = position, yaw = yaw }, cframe)
end
function CFrame.new(x, y, z) return frame(Vector3.new(x, y, z), 0) end
function CFrame.Angles(_, y, _) return frame(Vector3.new(), y) end
local function rotate(v, yaw)
	local c, s = math.cos(yaw), math.sin(yaw)
	return Vector3.new(v.X * c + v.Z * s, v.Y, -v.X * s + v.Z * c)
end
cframe.__mul = function(a, b)
	return frame(a.Position + rotate(b.Position, a.yaw), a.yaw + b.yaw)
end
cframe.__index = function(f, key)
	if key == "RightVector" then return rotate(Vector3.new(1, 0, 0), f.yaw)
	elseif key == "UpVector" then return Vector3.new(0, 1, 0)
	elseif key == "LookVector" then return rotate(Vector3.new(0, 0, -1), f.yaw)
	elseif key == "PointToObjectSpace" then
		return function(self, p) return rotate(p - self.Position, -self.yaw) end
	elseif key == "VectorToObjectSpace" then
		return function(self, v) return rotate(v, -self.yaw) end
	end
	return nil
end

local function node(name, class, props)
	local item = { Name = name, ClassName = class, children = {}, attributes = {}, Parent = nil }
	for key, value in props or {} do item[key] = value end
	function item:IsA(kind) return self.ClassName == kind or (kind == "BasePart" and self.ClassName == "Part") end
	function item:GetChildren()
		local result = {}
		for _, child in self.children do if child.Parent == self then table.insert(result, child) end end
		return result
	end
	function item:FindFirstChild(childName)
		for _, child in self:GetChildren() do if child.Name == childName then return child end end
		return nil
	end
	function item:GetAttribute(key) return self.attributes[key] end
	function item:SetAttribute(key, value) self.attributes[key] = value end
	function item:Destroy() self.Parent = nil end
	function item:GetBoundingBox() return self.box, self.size end
	return item
end
local function add(parent, child)
	child.Parent = parent
	table.insert(parent.children, child)
	return child
end

local function typeof(value)
	return if getmetatable(value) == cframe then "CFrame" else type(value)
end
local env = setmetatable({ Vector2 = Vector2, Vector3 = Vector3, CFrame = CFrame, typeof = typeof }, { __index = _G })
local chunk = source:sub(first, last) .. "\nreturn clearShopPlots, overlapsShopPlot\n"
local clearShopPlots, overlapsShopPlot = luau.load(luau.compile(chunk), "shop-plot", env)()

-- A turned base: house-local +Z (toward the road) is not a world axis.
local houseFrame = CFrame.new(400, 5.9, -120) * CFrame.Angles(0, 0.73, 0)
local function at(x, z, yaw)
	return houseFrame * CFrame.new(x, 0, z) * CFrame.Angles(0, yaw or 0, 0)
end
local island = node("Harbour Isle", "Model")
local bases = add(island, node("Bases", "Folder"))
local base = add(bases, node("Base1", "Model"))
local house = add(base, node("BaseHouse", "Model"))
house:SetAttribute("HouseFrame", houseFrame)
local village = add(island, node("Village", "Model"))
local houses = add(village, node("Houses", "Model"))
local streets = add(village, node("CrossStreets", "Model"))

local function model(parent, name, box, size)
	return add(parent, node(name, "Model", { box = box, size = size }))
end
local onPlot = model(houses, "CubeHouse", at(10, 75, 0.1), Vector3.new(20, 12, 16))
local farLamp = model(houses, "LampPost", at(-12, 61, 0), Vector3.new(1.8, 11.4, 1.8))
local nearLamp = model(houses, "LampPost", at(-12, 43, 0), Vector3.new(1.8, 11.4, 1.8))
local besidePlot = model(houses, "Townhouse", at(40, 74, 0), Vector3.new(16, 18, 14))
-- Its axis-aligned bounds would reach the plot; the turned footprint does not.
local turnedClear = model(houses, "Villa", at(-31.5, 89.8, math.pi / 4), Vector3.new(10, 18, 10))
-- Only a turned corner pokes into the plot.
local turnedCorner = model(houses, "Villa", at(-32, 72, math.pi / 4), Vector3.new(10, 18, 10))
local behindLane = model(houses, "CubeHouse", at(0, 104, 0), Vector3.new(20, 12, 16))
local crossing = add(streets, node("Part", "Part", { CFrame = at(5, 72, 0.2), Size = Vector3.new(10, 0.6, 40) }))
local laneJoint = add(streets, node("Part", "Part", { CFrame = at(5, 92, 0), Size = Vector3.new(0.6, 10, 10) }))

check(overlapsShopPlot(houseFrame, at(0, 72), Vector3.new(1, 1, 1)), "Plot centre overlaps")
check(not overlapsShopPlot(houseFrame, at(0, 40), Vector3.new(1, 1, 1)), "The road in front of the house is not the plot")
clearShopPlots(island)
check(onPlot.Parent == nil, "A village house on the shop plot is cleared")
check(farLamp.Parent == nil, "A lamp at the shop's kerb is cleared")
check(nearLamp.Parent == houses, "Lamps on the house side of the road stay")
check(besidePlot.Parent == houses, "Houses beside the plot stay")
check(turnedClear.Parent == houses, "A turned house whose footprint misses the plot stays")
check(turnedCorner.Parent == nil, "A turned house whose corner reaches the plot is cleared")
check(behindLane.Parent == houses, "Houses past the back lane stay")
check(crossing.Parent == nil and laneJoint.Parent == streets, "A cross street through the plot is cleared, not its far joint")
check(island:GetAttribute("ShopPlotVersion") == 1, "Clearing is recorded on the island")
local late = model(houses, "CubeHouse", at(0, 75, 0), Vector3.new(20, 12, 16))
clearShopPlots(island)
check(late.Parent == houses, "A recorded island is not cleared again")

local bare = node("Harbour Isle", "Model")
add(bare, node("Village", "Model"))
clearShopPlots(bare)
check(bare:GetAttribute("ShopPlotVersion") == nil, "An island without bases is left for later")

print(string.format("Shop plots: %d clearing checks passed (yaw-only mocks; no Roblox runtime).", checks))
