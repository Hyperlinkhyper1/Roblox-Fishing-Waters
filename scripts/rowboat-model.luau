-- Run node scripts/check-rowboat-model.cjs. Production Rowboat is inserted below.
-- Recording mocks exercise assembly/geometry invariants, not Roblox physics,
-- seating replication, material appearance, or live Studio gameplay.

local methods, vectorMeta = {}, {}
local function vector(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vectorMeta)
end
function vectorMeta.__add(a, b)
	return vector(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
function vectorMeta.__sub(a, b)
	return vector(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
function vectorMeta.__unm(a)
	return vector(-a.X, -a.Y, -a.Z)
end
function vectorMeta.__mul(a, b)
	if type(a) == "number" then
		a, b = b, a
	end
	return vector(a.X * b, a.Y * b, a.Z * b)
end
function vectorMeta.__div(a, b)
	return vector(a.X / b, a.Y / b, a.Z / b)
end
function vectorMeta.__index(a, key)
	if key == "Magnitude" then
		return math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z)
	elseif key == "Unit" then
		return a / a.Magnitude
	end
	return methods[key]
end
function methods:Dot(b)
	return self.X * b.X + self.Y * b.Y + self.Z * b.Z
end
function methods:Cross(b)
	return vector(self.Y * b.Z - self.Z * b.Y, self.Z * b.X - self.X * b.Z, self.X * b.Y - self.Y * b.X)
end
function methods:Lerp(b, t)
	return self + (b - self) * t
end
local Vector3 = { new = vector, zero = vector(0, 0, 0) }
local Color3 = {
	fromRGB = function(r, g, b)
		return { r, g, b }
	end,
}
local CFrame, frameMeta = {}, {}
local function transform(frame, value)
	return frame.RightVector * value.X + frame.UpVector * value.Y + frame.ZVector * value.Z
end
function frameMeta.__mul(a, b)
	return CFrame.fromMatrix(
		a.Position + transform(a, b.Position),
		transform(a, b.RightVector),
		transform(a, b.UpVector),
		transform(a, b.ZVector)
	)
end
function CFrame.fromMatrix(position, right, up, back)
	return setmetatable(
		{ Position = position, RightVector = right, UpVector = up, ZVector = back, LookVector = -back },
		frameMeta
	)
end
function CFrame.new(x, y, z)
	return CFrame.fromMatrix(
		if type(x) == "table" then x else vector(x, y, z),
		vector(1, 0, 0),
		vector(0, 1, 0),
		vector(0, 0, 1)
	)
end
function CFrame.Angles(x, y, z)
	assert(y == 0 and z == 0, "cooler mock supports the hinge X rotation")
	return CFrame.fromMatrix(vector(), vector(1, 0, 0), vector(0, math.cos(x), math.sin(x)), vector(0, -math.sin(x), math.cos(x)))
end
function frameMeta.__index(self, key)
	if key == "ToObjectSpace" then
		return function(_, other)
			local function inverse(v) return vector(v:Dot(self.RightVector), v:Dot(self.UpVector), v:Dot(self.ZVector)) end
			return CFrame.fromMatrix(inverse(other.Position - self.Position), inverse(other.RightVector), inverse(other.UpVector), inverse(other.ZVector))
		end
	elseif key == "VectorToWorldSpace" then
		return function(_, value) return transform(self, value) end
	end
end
function CFrame.lookAt(a, b)
	local back = (a - b).Unit
	local right = vector(0, 1, 0):Cross(back).Unit
	return CFrame.fromMatrix(a, right, back:Cross(right), back)
end
local Enum = setmetatable({}, {
	__index = function(self, category)
		local values = setmetatable({}, {
			__index = function(_, value)
				return value
			end,
		})
		rawset(self, category, values)
		return values
	end,
})
local PhysicalProperties = {
	new = function(...)
		return { ... }
	end,
}
local pendingTween
local TweenInfo = PhysicalProperties
local game = {
	GetService = function(_, name)
		assert(name == "TweenService")
		return { Create = function(_, target, _, properties)
			local completed
			return {
				Completed = { Once = function(_, callback) completed = callback end },
				Play = function()
					pendingTween = function()
						for key, value in properties do target[key] = value end
						completed()
					end
				end,
			}
		end }
	end,
}
local Instance = {
	new = function(kind)
		local item = { ClassName = kind, children = {}, attributes = {} }
		if kind == "ClickDetector" then
			local callbacks = {}
			item.MouseClick = {
				Connect = function(_, callback) table.insert(callbacks, callback) end,
				Fire = function(_, player) for _, callback in callbacks do callback(player) end end,
			}
		end
		function item:FindFirstChild(name, recurse)
			for _, child in (if recurse then self:GetDescendants() else self.children) do
				if child.Name == name then return child end
			end
			return nil
		end
		function item:FindFirstChildOfClass(class)
			for _, child in self.children do if child.ClassName == class then return child end end
			return nil
		end
		function item:Destroy()
			if self.Parent then table.remove(self.Parent.children, table.find(self.Parent.children, self)) end
			self.Parent = nil
		end
		function item:SetAttribute(key, value)
			self.attributes[key] = value
		end
		function item:GetAttribute(key)
			return self.attributes[key]
		end
		function item:GetDescendants()
			local result = {}
			local function add(parent)
				for _, child in parent.children do
					table.insert(result, child)
					add(child)
				end
			end
			add(self)
			return result
		end
		function item:IsA(class)
			return class == kind
				or (class == "BasePart" and (kind == "Part" or kind == "WedgePart" or kind == "VehicleSeat"))
		end
		return setmetatable(item, {
			__index = function(self, key)
				if key == "Position" then return self.CFrame.Position end
			end,
			__newindex = function(self, key, value)
				rawset(self, key, value)
				if key == "Parent" and value then
					table.insert(value.children, self)
				end
			end,
		})
	end,
}

local function loadRowboat()
	-- ROWBOAT_SOURCE --
end
local Rowboat = loadRowboat()
local checks = 0
local function check(condition, message)
	checks += 1
	assert(condition, message)
end
local function close(a, b)
	return (a - b).Magnitude < 0.0001
end

-- Rotation guards against accidentally building visible parts in world space.
local frames = {
	CFrame.new(35, 72, -18),
	CFrame.fromMatrix(vector(-42, 19, 81), vector(0, 0, -1), vector(0, 1, 0), vector(1, 0, 0)),
}
for _, frame in frames do
	for _, anchored in { false, true } do
		local boat = Rowboat.build(frame, anchored)
		check(boat.Parent == nil, "build must return an unparented model")
		check(boat.PrimaryPart.Name == "HullRoot", "primary root missing")
		check(
			close(boat.PrimaryPart.CFrame.Position, frame.Position + vector(0, -0.4, 0)),
			"waterline root offset changed"
		)
		local parts, welds, seats, planks, floorboards, lanterns, seals = 0, 0, 0, 0, 0, 0, 0
		local floorTop = -math.huge
		for _, item in boat:GetDescendants() do
			if item:IsA("BasePart") then
				parts += 1
				check(item.Anchored == (anchored and item.Name ~= "CoolerLid"), "anchor mismatch on " .. item.Name)
				check(item.Size.X > 0 and item.Size.Y > 0 and item.Size.Z > 0, "invalid dimension on " .. item.Name)
				for _, value in
					{ item.CFrame.Position, item.CFrame.RightVector, item.CFrame.UpVector, item.CFrame.ZVector }
				do
					check(
						value.X == value.X and value.Y == value.Y and value.Z == value.Z,
						"NaN geometry on " .. item.Name
					)
				end
				if item ~= boat.PrimaryPart then
					check(item.Massless, "secondary part must be massless")
				end
				if item.Name == "RowerSeat" then
					seats += 1
					check(item.ClassName == "VehicleSeat" and item.Disabled == anchored, "seat mode")
					check(item.CanTouch == not anchored, "seat contact mode")
					check(close(item.CFrame.LookVector, frame.LookVector), "seat must face local -Z")
					check(close(item.CFrame.Position, (frame * CFrame.new(0, 0.92, 0.6)).Position), "seat transform")
				elseif item.Name == "HullPlank" then
					planks += 1
					check(item.ClassName == "WedgePart" and item.Size.X <= 0.2, "hull must remain thin, open facets")
				elseif item.Name == "FloorSeal" then
					seals += 1
					check(item.CanCollide and item.Material == Enum.Material.Wood, "sole must be solid wood")
					check(math.abs(item.CFrame.Position.Y - frame.Position.Y + item.Size.X / 2 - 0.4) < 0.0001, "sole surface must stay above water")
				elseif item.Name == "Floorboard" then
					floorboards += 1
					floorTop = math.max(floorTop, item.CFrame.Position.Y - frame.Position.Y + item.Size.Y / 2)
				elseif item.Name == "LanternGlass" then
					lanterns += 1
				end
			elseif item.ClassName == "WeldConstraint" or item.ClassName == "Motor6D" then
				welds += 1
				check((item.Part0 == boat.PrimaryPart or item.Part0.Name == "OarShaft") and item.Part1 == item.Parent, "disconnected weld")
			end
		end
		check(parts < 160, "part budget exceeded")
		check(welds == parts - 1, "all secondary parts need root welds")
		check(seats == 1 and planks == 64 and floorboards == 7 and lanterns == 2, "boat detail missing")
		check(seals == 16, "fitted sole must cover all four hull sections")
		check(floorTop >= 0.4 and floorTop < 0.5, "dry floor must remain below the benches")
		check(boat:GetAttribute("DryFloorHeight") == 0.4, "buoyancy needs the floor clearance")
		local lid = boat:FindFirstChild("CoolerLid")
		local hinge = lid:FindFirstChild("CoolerHinge")
		local click = lid:FindFirstChildOfClass("ClickDetector")
		local closed = hinge.C0
		local character = { FindFirstChild = function() return { Position = lid.Position } end }
		local player = { Character = character }
		check(not lid.Anchored and not lid.CanCollide, "hinged lid must move freely on display and owned boats")
		check(not lid:FindFirstChildOfClass("WeldConstraint"), "fixed lid weld would prevent opening")
		check(boat:FindFirstChild("CoolerBody").Size.Y < 0.2, "open cooler must have a hollow interior")
		Rowboat.ensureCoolerInteraction(boat)
		click.MouseClick:Fire({})
		click.MouseClick:Fire({ Character = { FindFirstChild = function() return { Position = lid.Position + vector(20, 0, 0) } end } })
		check(not boat:GetAttribute("CoolerOpen"), "missing and distant characters cannot open cooler")
		click.MouseClick:Fire(player)
		check(boat:GetAttribute("CoolerOpen"), "click must open cooler, including after repeated binding")
		click.MouseClick:Fire(player)
		check(boat:GetAttribute("CoolerOpen"), "clicks during animation must not fight the hinge")
		pendingTween()
		check(hinge.C0.UpVector.Y < 0, "lid must rotate past vertical")
		check(close(hinge.C0.Position, closed.Position), "hinge must remain fixed relative to boat")
		boat:FindFirstChild("CoolerWall"):FindFirstChildOfClass("ClickDetector").MouseClick:Fire(player)
		pendingTween()
		check(not boat:GetAttribute("CoolerOpen") and close(hinge.C0.UpVector, closed.UpVector), "clicking body must close cooler")
		print(
			`Rowboat: anchored={anchored}, parts={parts}, root welds={welds}, forward rowing seat and open hull verified`
		)
	end
end
-- Exercise the production waterline calculation against the actual dry sole.
local Biomes = { WaterLevel = 72 }
for _, normal in { vector(0, 1, 0), vector(0.08, 1, 0.06).Unit, vector(-0.08, 1, -0.06).Unit } do
	for _, flatHeading in frames do
		for _, height in { -0.72, 0, 0.72 } do
			local boat = { model = Rowboat.build(CFrame.new(), false), root = { Position = vector(0, 72, 0) },
				waterlineOffset = vector(0, -0.4, 0), heading = {}, float = {} }
			local wave = { normal = normal, height = height }
			-- BUOYANCY_SOURCE --
			local surfaceY = boat.float.Position.Y - rootOffset.Y
			local lowest = surfaceY + 0.4 * normal.Y
				- math.abs(right.Y) * 3.25 - math.abs(forward.Y) * 7.1
			check(lowest >= Biomes.WaterLevel + 0.35 - 0.0001, "tilted sole submerged in terrain water")
			if height == 0.72 then
				check(math.abs(surfaceY - Biomes.WaterLevel - height) < 0.0001, "crest bobbing changed")
			end
		end
	end
end
print(`Rowboat model: {checks} checks passed (mock construction; live physics and rendering require Studio)`)
