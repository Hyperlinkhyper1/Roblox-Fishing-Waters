-- Run node scripts/check-boat-refit.mjs. Production boats, BoatRefitService and
-- DrydockLaunch are inserted at the marker; these mocks add the Color3, typeof, tag,
-- clock and CFrame pieces the shared recording mock lacks.
local colorMeta = {}
colorMeta.__index = {
	ToHex = function(c)
		return string.format("%02X%02X%02X", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
	end,
	Lerp = function(a, b, t)
		return setmetatable(
			{ R = a.R + (b.R - a.R) * t, G = a.G + (b.G - a.G) * t, B = a.B + (b.B - a.B) * t },
			colorMeta
		)
	end,
}
colorMeta.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
Color3 = {
	new = function(r, g, b)
		return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, colorMeta)
	end,
}
Color3.fromRGB = function(r, g, b)
	return Color3.new(r / 255, g / 255, b / 255)
end
local function typeof(value)
	if type(value) == "table" then
		if getmetatable(value) == colorMeta then
			return "Color3"
		elseif getmetatable(value) == frameMeta then
			return "CFrame"
		elseif getmetatable(value) == vectorMeta then
			return "Vector3"
		end
	end
	return type(value)
end
local newInstance = Instance.new
Instance.new = function(kind)
	local item = newInstance(kind)
	if kind == "Model" then
		rawset(item, "GetPivot", function(self)
			return self.PrimaryPart.CFrame
		end)
		rawset(item, "PivotTo", function(self, target)
			local previous = self:GetPivot()
			for _, p in self:GetDescendants() do
				if p:IsA("BasePart") then
					p.CFrame = target * previous:ToObjectSpace(p.CFrame)
				end
			end
		end)
	end
	rawset(item, "IsDescendantOf", function(self, ancestor)
		local parent = self.Parent
		while parent do
			if parent == ancestor then return true end
			parent = parent.Parent
		end
		return false
	end)
	rawset(item, "FindFirstAncestor", function(self, name)
		local parent = rawget(self, "Parent")
		while parent do
			if parent.Name == name then
				return parent
			end
			parent = rawget(parent, "Parent")
		end
		return nil
	end)
	rawset(item, "GetBoundingBox", function(self)
		local sum, count = vector(0, 0, 0), 0
		for _, p in self:GetDescendants() do
			if p:IsA("BasePart") then
				sum += p.CFrame.Position
				count += 1
			end
		end
		return CFrame.new(sum / math.max(count, 1)), vector(1, 1, 1)
	end)
	return item
end
local oldMul = frameMeta.__mul
function frameMeta.__mul(a, b)
	if getmetatable(b) == vectorMeta then
		return a.Position + a.RightVector * b.X + a.UpVector * b.Y + a.ZVector * b.Z
	end
	return oldMul(a, b)
end
function frameMeta.__add(a, v)
	return CFrame.fromMatrix(a.Position + v, a.RightVector, a.UpVector, a.ZVector)
end
function frameMeta.__sub(a, v)
	return CFrame.fromMatrix(a.Position - v, a.RightVector, a.UpVector, a.ZVector)
end
local oldIndex = frameMeta.__index
function frameMeta.__index(a, key)
	if key == "PointToObjectSpace" then
		return function(self, p)
			local v = p - self.Position
			return vector(v:Dot(self.RightVector), v:Dot(self.UpVector), v:Dot(self.ZVector))
		end
	elseif key == "Lerp" then
		return function(self, other, t)
			return CFrame.fromMatrix(self.Position:Lerp(other.Position, t), self.RightVector, self.UpVector, self.ZVector)
		end
	end
	return oldIndex(a, key)
end
local tags = {}
local CollectionService = {
	AddTag = function(_, item, tag)
		tags[tag] = tags[tag] or {}
		if not table.find(tags[tag], item) then
			table.insert(tags[tag], item)
		end
	end,
	GetTagged = function(_, tag)
		return tags[tag] or {}
	end,
}
-- Every frame advances a quarter second, so lift tweens finish in a few steps.
local RunService = {
	Heartbeat = {
		Wait = function()
			return 0.25
		end,
	},
}
local Players = {}
local game = {
	GetService = function(_, name)
		return if name == "CollectionService" then CollectionService elseif name == "RunService" then RunService elseif name == "Players" then Players else {}
	end,
}
local script = { Parent = {} }
local UDim2 = {
	fromScale = function(x, y)
		return { x, y }
	end,
}
local dependencies = {
	Biomes = { WaterLevel = 0 },
	BoatCatalog = {},
	AnglerData = {},
	BoatService = {},
	Aboard = function() end,
	AnglerCatalog = {},
	DrydockLaunch = {},
	TrawlerNetService = { dress = function() end, stow = function() end },
}
-- MODULES --
local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end
local function colors(model)
	local result = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			result[p] = p.Color
		end
	end
	return result
end
local builders = {
	Rowboat = Rowboat,
	FishingBoat = FishingBoat,
	Speedboat = Speedboat,
	RacingSpeedboat = RacingSpeedboat,
	PatrolBoat = PatrolBoat,
	Trawler = Trawler,
}
for _, name in { "FishingBoat", "Speedboat", "RacingSpeedboat", "PatrolBoat", "Rowboat", "Trawler" } do
	local model = builders[name].build(CFrame.new(0, 0, 0), true)
	local factory = colors(model)
	Refit.paint(model, nil)
	check(model:GetAttribute("Paint") == nil, name .. ": factory model stays unpainted")
	Refit.paint(model, "Red")
	local red = Color3.fromRGB(196, 40, 40)
	local painted, names, area, total = 0, {}, 0, 0
	for p, before in factory do
		if p.Color ~= before then
			painted += 1
			names[p.Name] = (names[p.Name] or 0) + 1
			if p.Name ~= "HullPlank" then
				check(p.Color == red, name .. ": non-plank facets take the exact paint")
			end
		end
		if p.Name == "HullPanel" or p.Name == "HullPlank" then
			total += p.Size.Y * p.Size.Z
			if p.Color ~= before then
				area += p.Size.Y * p.Size.Z
			end
		end
	end
	local list = {}
	for n, c in names do
		table.insert(list, n .. "=" .. c)
	end
	table.sort(list)
	print(
		string.format(
			"%-16s painted %3d parts, %.0f%% of side area: %s",
			name,
			painted,
			100 * area / total,
			table.concat(list, " ")
		)
	)
	check(painted > 20, name .. ": hull takes paint")
	check(area / total > 0.5, name .. ": most of the visible side takes paint")
	check(model:GetAttribute("Paint") == "Red", name .. ": paint recorded")
	Refit.paint(model, "Blue")
	local blue = colors(model)
	Refit.paint(model, "Factory")
	for p, before in factory do
		check(p.Color == before, name .. ": factory finish restores " .. p.Name)
	end
	Refit.paint(model, "Blue")
	for p, c in colors(model) do
		check(c == blue[p], name .. ": repainting never compounds")
	end
	Refit.paint(model, "Chartreuse")
	for p, before in factory do
		check(p.Color == before, name .. ": unknown paint means factory")
	end
end

-- The drydock lift: the cradle rises under a floating hull, meets its keel and
-- carries it up; lowering sets it back afloat and frees the lift.
local function lowest(model, name)
	local result = math.huge
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Name == name then
			local f, size = p.CFrame, p.Size
			local reach = math.abs(f.RightVector.Y) * size.X
				+ math.abs(f.UpVector.Y) * size.Y
				+ math.abs(f.LookVector.Y) * size.Z
			result = math.min(result, f.Position.Y - reach / 2)
		end
	end
	return result
end
for _, name in { "Rowboat", "FishingBoat", "PatrolBoat", "Trawler" } do
	local shop = Instance.new("Model")
	shop.Name = "Drydock"
	local cradle = Instance.new("Model")
	cradle.Name = "LaunchCradle"
	cradle.Parent = shop
	local block = Instance.new("Part")
	block.Name = "KeelBlock"
	block.Size, block.CFrame = vector(2.5, 0.9, 2), CFrame.new(0, 7.2 - 0.45 - 11.9, 0)
	block.Parent = cradle
	local pivot = CFrame.new(0, -4.7, 0)
	rawset(cradle, "GetPivot", function()
		return pivot
	end)
	rawset(cradle, "PivotTo", function(_, frame)
		block.CFrame = CFrame.new(block.CFrame.Position + (frame.Position - pivot.Position))
		pivot = frame
	end)
	shop:SetAttribute("LiftDrop", 11.9)
	shop:SetAttribute("LiftKeelHeight", 7.2)
	local boat = builders[name].build(CFrame.new(0, 0, 0), true)
	local floatKeel = lowest(boat, "Keel")
	check(floatKeel > -4.7, name .. ": the lowered blocks sit under the floating keel")
	local heights = {}
	local function hoist(height)
		table.insert(heights, height or "afloat")
	end
	local player = { UserId = 7 }
	local lift = DrydockLaunch.lift(shop, player, boat, hoist)
	check(lift ~= nil, name .. ": the lift raises the hull")
	check(math.abs(pivot.Position.Y - (-4.7 + 11.9)) < 1e-9, name .. ": the cradle ends in the dry basin")
	check(shop:GetAttribute("LiftingUserId") == 7, name .. ": the lift shows who is using it")
	local top = heights[#heights]
	check(heights[1] == 0, name .. ": blocks climb before the hull moves")
	check(math.abs(floatKeel + top - 7.2) < 1e-6, name .. ": the keel ends resting on the blocks")
	check(
		math.abs(block.CFrame.Position.Y + 0.45 - (floatKeel + top)) < 1e-6,
		name .. ": blocks and keel meet in the basin"
	)
	local _, busy = DrydockLaunch.lift(shop, player, boat, hoist)
	check(busy and string.find(busy, "in use"), name .. ": one hull at a time")
	DrydockLaunch.lower(lift)
	check(math.abs(pivot.Position.Y + 4.7) < 1e-9, name .. ": the cradle goes back underwater")
	check(heights[#heights] == "afloat", name .. ": the hull is set back afloat")
	check(shop:GetAttribute("LiftingUserId") == nil, name .. ": the lift is free again")
	local count = #heights
	DrydockLaunch.lower(lift)
	check(#heights == count, name .. ": lowering twice does nothing")
	check(DrydockLaunch.lift(shop, player, boat, hoist) ~= nil, name .. ": a free lift raises again")
end
-- Exercise the trawler's real drydock reservation, cancellation and purchase lowering.
local world = Instance.new("Model")
local shop = Instance.new("Model")
shop.Name, shop.Parent = "Drydock", world
local display = CFrame.new(0, 7.9, 54) * CFrame.Angles(0, math.pi, 0)
shop:SetAttribute("TrawlerPreviewFrame", display)
shop:SetAttribute("LiftDrop", 11.9)
for _, name in { "PreviewOrigin", "SlipwayTop", "LaunchWater" } do
	local p = Instance.new("Part")
	p.Name, p.CFrame, p.Parent = name, if name == "LaunchWater" then display - vector(0, 7.9, 0) else display, shop
end
local cradle = Instance.new("Model")
cradle.Name, cradle.Parent = "LaunchCradle", shop
local block = Instance.new("Part")
block.CFrame, block.Parent = CFrame.new(0, -4, 54), cradle
cradle.PrimaryPart = block
local player = { UserId = 91, Parent = Players }
local reservation = assert(DrydockLaunch.reserve(shop, player, "Trawler"))
check(reservation.preview.Name == "TrawlerPreview" and reservation.preview:GetAttribute("BoatId") == "Trawler", "Purchase reserves the real trawler builder")
for _, p in reservation.preview:GetDescendants() do
	if p:IsA("BasePart") then
		check(not p.CanCollide and p.Anchored, "Purchase display is anchored and nonblocking")
		for _, x in { -0.5, 0.5 } do
			for _, y in { -0.5, 0.5 } do
				for _, z in { -0.5, 0.5 } do
					local point = display:PointToObjectSpace(p.CFrame * vector(p.Size.X * x, p.Size.Y * y, p.Size.Z * z))
					check(point.Z < 20, "Entire trawler clears the drydock headwall")
				end
			end
		end
	end
end
check(DrydockLaunch.reserve(shop, player, "Trawler") == nil, "Purchase reservation excludes a second launch")
local cancelled = reservation.preview
DrydockLaunch.release(reservation)
check(cancelled.Parent == nil and shop:GetAttribute("LaunchingBoatId") == nil, "Cancelled purchase removes its temporary hull and releases the bay")
reservation = assert(DrydockLaunch.reserve(shop, player, "Trawler"))
check(DrydockLaunch.run(reservation, function(owner, waterline, model)
	check(owner == player and model == reservation.preview, "Lowering activates the reserved trawler")
	check(math.abs(model.PrimaryPart.CFrame.Position.Y + 0.4) < 0.00001, "Trawler reaches its waterline before physics activation")
	model.Parent = world
	return true
end), "Trawler purchase lowering completes")
print("boat refit and trawler launch checks passed", checks)
