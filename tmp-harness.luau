-- Production Harbour/Drydock/Shipwright/Rowboat/Props builders are inserted by
-- check-drydock.mjs or drydock-check.ps1. This checks their emitted geometry with matrix-aware
-- recording mocks; it does not run Roblox physics or replace Studio play.
-- Run with scripts/check-harbour-geometry.ps1. Production Harbour source is
-- inserted at the marker, then its real builders run against recording mocks.
-- This checks surface geometry, not Roblox physics, rendering, or Studio play.

local function vectorType(dimensions)
	local methods = {}
	local mt = {}
	local function new(x, y, z)
		return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, mt)
	end
	function mt.__add(a, b)
		return new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
	end
	function mt.__sub(a, b)
		return new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
	end
	function mt.__unm(a)
		return new(-a.X, -a.Y, -a.Z)
	end
	function mt.__mul(a, b)
		if type(a) == "number" then
			a, b = b, a
		end
		return new(a.X * b, a.Y * b, a.Z * b)
	end
	function mt.__div(a, b)
		return new(a.X / b, a.Y / b, a.Z / b)
	end
	function mt.__index(a, key)
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
		assert(dimensions == 3)
		return new(self.Y * b.Z - self.Z * b.Y, self.Z * b.X - self.X * b.Z, self.X * b.Y - self.Y * b.X)
	end
	function methods:Min(b)
		return new(math.min(self.X, b.X), math.min(self.Y, b.Y), math.min(self.Z, b.Z))
	end
	function methods:Max(b)
		return new(math.max(self.X, b.X), math.max(self.Y, b.Y), math.max(self.Z, b.Z))
	end
	function methods:Lerp(b, t)
		return self + (b - self) * t
	end
	return { new = new, zero = new(0, 0, 0) }
end

local Vector2 = vectorType(2)
local Vector3 = vectorType(3)
local Color3 = {}
function Color3.new(r, g, b)
	return {
		R = r,
		G = g,
		B = b,
		Lerp = function(self, other, t)
			return Color3.new(
				self.R + (other.R - self.R) * t,
				self.G + (other.G - self.G) * t,
				self.B + (other.B - self.B) * t
			)
		end,
	}
end
function Color3.fromRGB(r, g, b)
	return Color3.new(r / 255, g / 255, b / 255)
end

local Random = {}
function Random.new(seed)
	local state = seed
	local rng = {}
	function rng:NextNumber(low, high)
		state = (state * 16807) % 2147483647
		local t = state / 2147483647
		return (low or 0) + ((high or 1) - (low or 0)) * t
	end
	function rng:NextInteger(low, high)
		return math.min(high, math.floor(self:NextNumber(low, high + 1)))
	end
	return rng
end



Vector3.xAxis = Vector3.new(1, 0, 0)
Vector3.yAxis = Vector3.new(0, 1, 0)
Vector3.zAxis = Vector3.new(0, 0, 1)

local CFrame = {}
local frameMethods = {}
local frameMt = {}
local function frame(position, right, up, back)
	return setmetatable(
		{ Position = position, RightVector = right, UpVector = up, ZVector = back, _type = "CFrame" },
		frameMt
	)
end
function CFrame.new(x, y, z)
	return frame(if type(x) == "table" then x else Vector3.new(x, y, z), Vector3.xAxis, Vector3.yAxis, Vector3.zAxis)
end
CFrame.identity = CFrame.new()
function CFrame.fromMatrix(position, right, up, back)
	return frame(position, right, up, back or right:Cross(up))
end
function frameMethods:VectorToWorldSpace(v)
	return self.RightVector * v.X + self.UpVector * v.Y + self.ZVector * v.Z
end
function frameMethods:PointToWorldSpace(v)
	return self.Position + self:VectorToWorldSpace(v)
end
function frameMethods:VectorToObjectSpace(v)
	return Vector3.new(v:Dot(self.RightVector), v:Dot(self.UpVector), v:Dot(self.ZVector))
end
function frameMethods:PointToObjectSpace(v)
	return self:VectorToObjectSpace(v - self.Position)
end
function frameMethods:ToObjectSpace(other)
	return frame(
		self:PointToObjectSpace(other.Position),
		self:VectorToObjectSpace(other.RightVector),
		self:VectorToObjectSpace(other.UpVector),
		self:VectorToObjectSpace(other.ZVector)
	)
end
function frameMt.__index(self, key)
	return if key == "LookVector" then -self.ZVector else frameMethods[key]
end
function frameMt.__mul(a, b)
	if b._type == "CFrame" then
		return frame(
			a:PointToWorldSpace(b.Position),
			a:VectorToWorldSpace(b.RightVector),
			a:VectorToWorldSpace(b.UpVector),
			a:VectorToWorldSpace(b.ZVector)
		)
	end
	return a:PointToWorldSpace(b)
end
function frameMt.__add(a, b)
	return frame(a.Position + b, a.RightVector, a.UpVector, a.ZVector)
end
function frameMt.__sub(a, b)
	return a + -b
end
function CFrame.Angles(x, y, z)
	local sx, cx, sy, cy, sz, cz = math.sin(x), math.cos(x), math.sin(y), math.cos(y), math.sin(z), math.cos(z)
	local rx = frame(Vector3.zero, Vector3.xAxis, Vector3.new(0, cx, sx), Vector3.new(0, -sx, cx))
	local ry = frame(Vector3.zero, Vector3.new(cy, 0, -sy), Vector3.yAxis, Vector3.new(sy, 0, cy))
	local rz = frame(Vector3.zero, Vector3.new(cz, sz, 0), Vector3.new(-sz, cz, 0), Vector3.zAxis)
	return rx * ry * rz
end
function CFrame.lookAt(origin, target, upwards)
	local look = (target - origin).Unit
	local right = look:Cross(upwards or Vector3.yAxis).Unit
	return frame(origin, right, right:Cross(look).Unit, -look)
end
local function typeof(value)
	return if type(value) == "table" and value._type then value._type else type(value)
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
local function valueType()
	return {
		new = function(...)
			return { ... }
		end,
		fromScale = function(...)
			return { ... }
		end,
	}
end
local UDim2, NumberSequence, NumberSequenceKeypoint, NumberRange, ColorSequence =
	valueType(), valueType(), valueType(), valueType(), valueType()
local PhysicalProperties = valueType()
local instanceMethods = {}
local instanceMt = {}
local Instance = {}
local partTypes = { Part = true, WedgePart = true, Seat = true, VehicleSeat = true, SpawnLocation = true }
function Instance.new(class)
	return setmetatable({
		_props = {
			MouseClick = { Connect = function() end },
			ClassName = class,
			Name = class,
			Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(),
			CanCollide = true,
			Transparency = 0,
		},
		_children = {},
		_attributes = {},
		_tags = {},
	}, instanceMt)
end
function instanceMt.__index(self, key)
	if key == "Position" then
		return self.CFrame.Position
	end
	return instanceMethods[key] or self._props[key]
end
function instanceMt.__newindex(self, key, value)
	if key == "Parent" then
		local old = self._props.Parent
		if old then
			table.remove(old._children, table.find(old._children, self))
		end
		if value then
			table.insert(value._children, self)
		end
	end
	self._props[key] = value
end
function instanceMethods:IsA(class)
	return self.ClassName == class or (class == "BasePart" and partTypes[self.ClassName] == true)
end
function instanceMethods:SetAttribute(key, value)
	self._attributes[key] = value
end
function instanceMethods:GetAttribute(key)
	return self._attributes[key]
end
function instanceMethods:ApplyDescriptionAsync(description)
	self._appliedDescription = description
	local character = self.Parent or self
	local shirt = Instance.new("Shirt")
	shirt.Name = "Shirt"
	shirt.ShirtTemplate = "rbxassetid://" .. tostring(description.Shirt)
	shirt.Parent = character
	local pants = Instance.new("Pants")
	pants.Name = "Pants"
	pants.PantsTemplate = "rbxassetid://" .. tostring(description.Pants)
	pants.Parent = character
	for _, id in string.split(description.HatAccessory or "", ",") do
		local accessory = Instance.new("Accessory")
		accessory.Name = "HatAccessory"
		accessory:SetAttribute("AssetId", tonumber(id))
		accessory.Parent = character
	end
	for _, id in string.split(description.WaistAccessory or "", ",") do
		local accessory = Instance.new("Accessory")
		accessory.Name = "WaistAccessory"
		accessory:SetAttribute("AssetId", tonumber(id))
		accessory.Parent = character
	end
end
function instanceMethods:GetChildren()
	return table.clone(self._children)
end
-- The refit lift moves during construction, before the launch scenarios below.
function instanceMethods:GetPivot()
	return self.PrimaryPart.CFrame
end
function instanceMethods:PivotTo(target)
	local previous = self:GetPivot()
	for _, piece in self:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.CFrame = target * previous:ToObjectSpace(piece.CFrame)
		end
	end
end
function instanceMethods:GetDescendants()
	local result = {}
	for _, child in self._children do
		table.insert(result, child)
		for _, descendant in child:GetDescendants() do
			table.insert(result, descendant)
		end
	end
	return result
end
function instanceMethods:FindFirstChild(name, recurse)
	for _, child in (if recurse then self:GetDescendants() else self._children) do
		if child.Name == name then
			return child
		end
	end
	return nil
end
function instanceMethods:FindFirstChildOfClass(class)
	for _, item in self:GetChildren() do
		if item:IsA(class) then return item end
	end
	return nil
end
function instanceMethods:GetFullName()
	return if self.Parent then self.Parent:GetFullName() .. "." .. self.Name else self.Name
end
function instanceMethods:IsDescendantOf(ancestor)
	local parent = self.Parent
	while parent do
		if parent == ancestor then
			return true
		end
		parent = parent.Parent
	end
	return false
end
function instanceMethods:FindFirstChildWhichIsA(class)
	for _, item in self._children do
		if item:IsA(class) then
			return item
		end
	end
	return nil
end
function instanceMethods:Destroy()
	self.Parent = nil
end
local CollectionService = {}
function CollectionService:AddTag(item, tag)
	item._tags[tag] = true
end
function CollectionService:RemoveTag(item, tag)
	item._tags[tag] = nil
end
function CollectionService:HasTag(item, tag)
	return item._tags[tag] == true
end
local game = {
	GetService = function(_, name)
		if name == "ReplicatedStorage" then
			return {}
		end
		assert(name == "CollectionService")
		return CollectionService
	end,
}
local workspace = { Terrain = { FillBlock = function() end }, Name = "Workspace", _children = {} }
workspace.FindFirstChild = instanceMethods.FindFirstChild
workspace.GetChildren = instanceMethods.GetChildren
workspace.GetDescendants = instanceMethods.GetDescendants
function workspace:GetFullName()
	return "Workspace"
end
local task = { wait = function() end }
local warn = print
local dependencies = { Islands = {} }
local function loadBoatCatalog()
	-- Purchase preview and server driving use the same specifications.
-- Hold is the cargo grid mask (see Shared.Cargo): a top-down outline of the hull,
-- bow at the top, so bigger hulls carry more.
-- StarterParts is the boat kit already stowed when a hold is first opened.
local fishingHold = table.freeze({
	"...#...",
	"..###..",
	"..###..",
	".#####.",
	".#####.",
	"#######",
	"#######",
	"#######",
	"#######",
	"#######",
	"#######",
	".#####.",
})

-- Long bow and narrow beam: 90 cells, about 70% of the previous hold.
local patrolHold = table.freeze({
	"...##...",
	"...##...",
	"..####..",
	"..####..",
	".######.",
	".######.",
	".######.",
	".######.",
	"########",
	"########",
	"########",
	"########",
	"########",
	"########",
	".######.",
})

return table.freeze({
	Rowboat = table.freeze({
		Name = "Wooden rowboat",
		Price = 500,
		ForwardSpeed = 24,
		ReverseSpeed = 9,
		TurnRate = 1.2,
		Acceleration = 12,
		CoastDeceleration = 4,
		BrakeDeceleration = 16,
		TurnAcceleration = 2.4,
		MaxBankAngle = 9,
		Length = 14.4,
		Beam = 6.8,
		Seats = 1,
		DriverSeat = "RowerSeat",
		Hold = table.freeze({
			"..#..",
			".###.",
			".###.",
			"#####",
			"#####",
			"#####",
			".###.",
			".###.",
		}),
		StarterParts = table.freeze({
			table.freeze({ PartId = "Lantern", X = 3, Y = 1, R = 0 }),
		}),
	}),
	FishingBoat = table.freeze({
		Name = "Small fishing boat",
		Price = 2500,
		ForwardSpeed = 50,
		ReverseSpeed = 14,
		TurnRate = 0.9,
		Acceleration = 25,
		CoastDeceleration = 5,
		BrakeDeceleration = 24,
		TurnAcceleration = 1.8,
		MaxBankAngle = 12,
		-- Roblox Creator Store: Engine Sound Loop 7 by Czlopek.
		-- https://create.roblox.com/store/asset/6667206432/Engine-Sound-Loop-7
		EngineSoundId = "rbxassetid://6667206432",
		Length = 22,
		Beam = 9.6,
		Seats = 3,
		DriverSeat = "HelmSeat",
		Hold = fishingHold,
		StarterParts = table.freeze({
			table.freeze({ PartId = "Engine", X = 3, Y = 11, R = 0 }),
			table.freeze({ PartId = "Lantern", X = 4, Y = 1, R = 0 }),
		}),
	}),
	RacingSpeedboat = table.freeze({
		Name = "Racing speedboat",
		Price = 12500,
		ForwardSpeed = 80,
		ReverseSpeed = 24,
		TurnRate = 1.8,
		Acceleration = 40,
		CoastDeceleration = 8,
		BrakeDeceleration = 48,
		TurnAcceleration = 4,
		MaxBankAngle = 26,
		EngineSoundId = "rbxassetid://6667206432",
		Length = 36,
		Beam = 9.6,
		Seats = 4,
		DriverSeat = "HelmSeat",
		-- 49 usable tiles: fifteen fewer than the fishing boat.
		Hold = table.freeze({
			"...#...",
			"..###..",
			"..###..",
			".#####.",
			".#####.",
			".#####.",
			"#######",
			"#######",
			"#######",
			"..###..",
			"..###..",
		}),
		StarterParts = table.freeze({
			table.freeze({ PartId = "Engine", X = 3, Y = 10, R = 0 }),
			table.freeze({ PartId = "Lantern", X = 4, Y = 1, R = 0 }),
		}),
	}),
	Speedboat = table.freeze({
		Name = "Bluewater speedboat",
		Price = 6500,
		ForwardSpeed = 60,
		ReverseSpeed = 20,
		TurnRate = 1.4,
		Acceleration = 30,
		CoastDeceleration = 7,
		BrakeDeceleration = 36,
		TurnAcceleration = 3.2,
		MaxBankAngle = 20,
		EngineSoundId = "rbxassetid://6667206432",
		Length = 24,
		Beam = 9.6,
		Seats = 3,
		DriverSeat = "HelmSeat",
		Hold = fishingHold,
		StarterParts = table.freeze({
			table.freeze({ PartId = "Engine", X = 3, Y = 11, R = 0 }),
			table.freeze({ PartId = "Lantern", X = 4, Y = 1, R = 0 }),
		}),
	}),
	PatrolBoat = table.freeze({
		Name = "Gray patrol cruiser",
		Price = 15000,
		ForwardSpeed = 70,
		ReverseSpeed = 26,
		TurnRate = 1.35,
		Acceleration = 35,
		CoastDeceleration = 9,
		BrakeDeceleration = 56,
		TurnAcceleration = 4.2,
		-- Twin screws let the long hull pivot in harbour at half its cruise turn rate.
		IdleSteering = 0.5,
		MaxBankAngle = 14,
		EngineSoundId = "rbxassetid://6667206432",
		Length = 42 * 1.2,
		Beam = 12 * 1.2,
		Seats = 3,
		DriverSeat = "HelmSeat",
		Hold = patrolHold,
		HoldVersion = 3,
		StarterParts = table.freeze({
			table.freeze({ PartId = "PatrolEngine", X = 3, Y = 11, R = 0 }),
			table.freeze({ PartId = "Lantern", X = 4, Y = 1, R = 0 }),
		}),
	}),
	Trawler = table.freeze({
		Name = "Teal fishing trawler",
		Price = 17500,
		ForwardSpeed = 70,
		ReverseSpeed = 20,
		TurnRate = 0.85,
		Acceleration = 35,
		CoastDeceleration = 6,
		BrakeDeceleration = 38,
		TurnAcceleration = 2.2,
		IdleSteering = 0.35,
		MaxBankAngle = 9,
		EngineSoundId = "rbxassetid://6667206432",
		Length = 44,
		Beam = 14.8,
		Seats = 3,
		DriverSeat = "HelmSeat",
		-- 104 usable tiles, bow first. Broad aft working hold with a tapered entry.
		Hold = table.freeze({
			"...##...",
			"..####..",
			".######.",
			".######.",
			"########",
			"########",
			"########",
			"########",
			"########",
			"########",
			"########",
			"########",
			"########",
			"########",
			".######.",
		}),
		StarterParts = table.freeze({
			-- Eight-tile engine bed, centered across the aft hold.
			table.freeze({ PartId = "TrawlerEngine", X = 3, Y = 13, R = 0 }),
			table.freeze({ PartId = "Lantern", X = 4, Y = 1, R = 0 }),
		}),
	}),
})

end
dependencies.BoatCatalog = loadBoatCatalog()

local function loadLowPoly()
	-- Flat-shaded geometry built from WedgeParts. Every triangle is two wedges,
-- which is what gives the map its faceted, Dredge-like look.

local LowPoly = {}

local THICKNESS = 0.6

local function wedge(color: Color3, material: Enum.Material): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.CanTouch = false
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Material = material
	w.Color = color
	return w
end

-- `inside` is any point behind the face; the wedges' thickness is pushed toward it
-- so the visible surface sits exactly on the triangle.
function LowPoly.triangle(
	a: Vector3,
	b: Vector3,
	c: Vector3,
	inside: Vector3,
	color: Color3,
	parent: Instance,
	material: Enum.Material?,
	thickness: number?
)
	if (b - a):Cross(c - a).Magnitude < 0.01 then
		return
	end

	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b

	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))

	local normal = if right:Dot((a + b + c) / 3 - inside) >= 0 then right else -right
	local depth = thickness or THICKNESS
	local shift = -normal * (depth / 2)
	local mat = material or Enum.Material.SmoothPlastic

	local w1 = wedge(color, mat)
	w1.Size = Vector3.new(depth, height, math.abs(ab:Dot(back)))
	w1.CFrame = CFrame.fromMatrix((a + b) / 2 + shift, right, up, back)
	w1.Parent = parent

	local w2 = wedge(color, mat)
	w2.Size = Vector3.new(depth, height, math.abs(ac:Dot(back)))
	w2.CFrame = CFrame.fromMatrix((a + c) / 2 + shift, -right, up, -back)
	w2.Parent = parent
end

-- Open-bottomed pyramid over a ring of base points (in order around the ring).
function LowPoly.pyramid(
	base: { Vector3 },
	apex: Vector3,
	color: Color3,
	parent: Instance,
	material: Enum.Material?,
	inside: Vector3?
)
	local centroid = Vector3.zero
	for _, p in base do
		centroid += p
	end
	centroid /= #base
	local core = inside or centroid:Lerp(apex, 0.3)
	for i = 1, #base do
		LowPoly.triangle(base[i], base[i % #base + 1], apex, core, color, parent, material)
	end
end

-- Faceted rock: two pyramids sharing a jittered ring.
function LowPoly.boulder(
	center: Vector3,
	radius: number,
	rng: Random,
	color: Color3,
	parent: Instance,
	material: Enum.Material?
)
	local ring = {}
	local sides = rng:NextInteger(5, 6)
	for i = 1, sides do
		local a = (i + rng:NextNumber(-0.25, 0.25)) / sides * math.pi * 2
		local r = radius * rng:NextNumber(0.8, 1.15)
		ring[i] = center + Vector3.new(math.cos(a) * r, rng:NextNumber(-0.25, 0.25) * radius, math.sin(a) * r)
	end
	local top = center
		+ Vector3.new(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0.7, 1.1), rng:NextNumber(-0.3, 0.3)) * radius
	local bottom = center - Vector3.new(0, radius * 0.7, 0)
	LowPoly.pyramid(ring, top, color, parent, material, center)
	LowPoly.pyramid(ring, bottom, color, parent, material, center)
end

return LowPoly

end
dependencies.LowPoly = loadLowPoly()
local function loadProps()
	-- Set dressing: trees, buildings, harbour clutter, rocks and effects, all using Roblox's textured materials.
-- Each builder takes a ground position and puts its parts in a new Model under `parent`.

local LowPoly = dependencies.LowPoly

local Props = {}

local HOUSE_COLLISION_VERSION = 1
local HOUSE_NAMES = {
	House = true,
	CubeHouse = true,
	Townhouse = true,
	Villa = true,
	FishingRodShop = true,
	FurnitureShop = true,
}
local BASE_TRIM = {
	SidePlinth = true,
	EavesBeam = true,
	TimberPost = true,
	DoorJamb = true,
	DoorHeader = true,
	RidgeCap = true,
	CeilingTie = true,
}

local function noCollision(piece: BasePart)
	piece.CanCollide, piece.CanTouch, piece.CanQuery = false, false, false
end

-- Keep the existing solid building cores and walking surfaces. Facade details
-- within 0.65 studs of a core share its collision instead of each adding a body.
-- Test all eight corners in the core's frame, including on rotated houses.
local function coveredByCore(piece: BasePart, core: BasePart): boolean
	local half = core.Size / 2 + Vector3.new(0.65, 0.65, 0.65)
	for _, x in { -0.5, 0.5 } do
		for _, y in { -0.5, 0.5 } do
			for _, z in { -0.5, 0.5 } do
				local point = core.CFrame:PointToObjectSpace(
					piece.CFrame * Vector3.new(piece.Size.X * x, piece.Size.Y * y, piece.Size.Z * z)
				)
				if math.abs(point.X) > half.X or math.abs(point.Y) > half.Y or math.abs(point.Z) > half.Z then
					return false
				end
			end
		end
	end
	return true
end

function Props.simplifyHouseCollision(house: Model)
	if house:GetAttribute("HouseCollisionVersion") == HOUSE_COLLISION_VERSION then
		return
	end
	if house.Name == "BaseHouse" then
		-- Player homes are hollow: never replace their rooms with a solid box.
		-- Only shell trim is decorative; furniture retains its own interactions.
		local shell = house:FindFirstChild("Shell")
		for _, piece in if shell then shell:GetDescendants() else {} do
			if piece:IsA("BasePart") and BASE_TRIM[piece.Name] then
				noCollision(piece)
			end
		end
	else
		local pieces, cores = {}, {}
		for _, piece in house:GetDescendants() do
			if piece:IsA("BasePart") and piece.CanCollide then
				table.insert(pieces, piece)
				-- Scenery houses already have solid, rectangular wall blocks.
				-- Roofs, steps, stilts, balconies and exterior stairs are not cores.
				if
					piece:IsA("Part")
					and piece.Shape == Enum.PartType.Block
					and piece.Size.X >= 8
					and piece.Size.Z >= 8
					and piece.Size.Y >= 6
				then
					table.insert(cores, piece)
				end
			end
		end
		for _, piece in pieces do
			if table.find(cores, piece) then
				continue
			end
			for _, core in cores do
				if coveredByCore(piece, core) then
					noCollision(piece)
					break
				end
			end
		end
	end
	house:SetAttribute("HouseCollisionVersion", HOUSE_COLLISION_VERSION)
end

-- Baked maps keep their models, positions, ownership and furnishings.
function Props.ensureHouseCollision(root: Instance)
	for _, house in root:GetDescendants() do
		if
			house:IsA("Model")
			and (
				HOUSE_NAMES[house.Name]
				or house.Name == "BaseHouse"
				or house.Name == "PlazaHouse"
				or string.match(house.Name, "^PlazaHouse%d+$")
			)
		then
			Props.simplifyHouseCollision(house)
		end
	end
end

local TAU = math.pi * 2
local rgb = Color3.fromRGB
local M = Enum.Material

local WOOD = rgb(122, 92, 64)
local WOOD_DARK = rgb(78, 60, 46)
local TRUNK = rgb(88, 66, 50)
local WHITE = rgb(232, 228, 218)
local RED = rgb(170, 52, 44)
local IRON = rgb(52, 50, 48)
local ROPE = rgb(176, 150, 106)
local STONE = rgb(132, 126, 118)
local LAMP = rgb(255, 210, 140)
local LAVA = rgb(255, 96, 28)

local function newModel(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function part(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = material or M.SmoothPlastic
	p.Color = color
	p.Size = size
	p.CFrame = cframe
	p.Parent = parent
	return p
end

-- Upright cylinder centered on `center`.
local function cylinder(
	parent: Instance,
	center: Vector3,
	height: number,
	diameter: number,
	color: Color3,
	material: Enum.Material?
): Part
	local p = part(
		parent,
		Vector3.new(height, diameter, diameter),
		CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A block stretched between two points; trunks, roots, posts, branches, ropes and fronds.
local function beam(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	width: number,
	color: Color3,
	thickness: number?,
	material: Enum.Material?
): Part
	if math.abs((b - a).Unit.Y) > 0.999 then
		b += Vector3.new(0.01, 0, 0)
	end
	return part(
		parent,
		Vector3.new(width, thickness or width, (b - a).Magnitude),
		CFrame.lookAt((a + b) / 2, b),
		color,
		material
	)
end

-- Randomly rotated block; reads as a chunky clump (canopies, rocks, coral).
local function blob(
	parent: Instance,
	center: Vector3,
	size: Vector3,
	rng: Random,
	color: Color3,
	material: Enum.Material?
): Part
	local spin = CFrame.Angles(rng:NextNumber(0, TAU), rng:NextNumber(0, TAU), rng:NextNumber(0, TAU))
	return part(parent, size, CFrame.new(center) * spin, color, material)
end

local function ball(parent: Instance, center: Vector3, size: number, color: Color3, material: Enum.Material?): Part
	local p = part(parent, Vector3.new(size, size, size), CFrame.new(center), color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
end

local function shade(color: Color3, rng: Random, amount: number): Color3
	local s = 1 + rng:NextNumber(-amount, amount)
	return Color3.new(math.min(color.R * s, 1), math.min(color.G * s, 1), math.min(color.B * s, 1))
end

function Props.pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

Props.part = part
Props.cylinder = cylinder
Props.beam = beam
Props.blob = blob
Props.ball = ball
Props.light = light
Props.shade = shade

----------------------------------------------------------------------------------------------------
-- Trees

-- Tiered conifer; `snow` frosts the tiers for the ice biome.
function Props.pine(parent: Instance, ground: Vector3, rng: Random, leaves: Color3, snow: Color3?): Model
	local m = newModel("Pine", parent)
	local h = rng:NextNumber(14, 30)
	local width = h * rng:NextNumber(0.2, 0.26)
	part(m, Vector3.new(1.2, h * 0.3, 1.2), CFrame.new(ground + Vector3.new(0, h * 0.15 - 1, 0)), TRUNK, M.Wood)

	local tiers = if h > 21 then 3 else 2
	local spin = rng:NextNumber(0, TAU)
	for i = 1, tiers do
		local k = (i - 1) / tiers
		local baseY = h * (0.16 + k * 0.6)
		local apexY = if i == tiers then h else baseY + h * 0.5
		local r = width * (1 - k * 0.55)
		local base = {}
		for s = 0, 3 do
			local a = spin + i * 0.7 + s * TAU / 4 + rng:NextNumber(-0.2, 0.2)
			base[s + 1] = ground + Vector3.new(math.cos(a) * r, baseY, math.sin(a) * r)
		end
		local apex = ground + Vector3.new(rng:NextNumber(-0.4, 0.4), apexY, rng:NextNumber(-0.4, 0.4))
		local color = shade(leaves, rng, 0.08)
		local material = M.Grass
		if snow then
			color = color:Lerp(snow, if i == tiers then 0.85 else 0.45)
			material = if i == tiers then M.Snow else M.Grass
		end
		LowPoly.pyramid(base, apex, color, m, material)
	end
	return m
end

-- Round-canopied tree (the orange/brown autumn trees around the Sound).
function Props.broadleaf(parent: Instance, ground: Vector3, rng: Random, colors: { Color3 }): Model
	local m = newModel("Tree", parent)
	local h = rng:NextNumber(10, 16)
	local top = ground + Vector3.new(rng:NextNumber(-1, 1), h * 0.65, rng:NextNumber(-1, 1))
	beam(m, ground - Vector3.new(0, 1, 0), top, 1.4, TRUNK, nil, M.Wood)
	for _ = 1, 2 do
		local a = rng:NextNumber(0, TAU)
		local tip = top:Lerp(ground, 0.35) + Vector3.new(math.cos(a) * 3.5, 3, math.sin(a) * 3.5)
		beam(m, top:Lerp(ground, 0.4), tip, 0.6, TRUNK, nil, M.Wood)
	end
	for _ = 1, rng:NextInteger(3, 4) do
		local s = rng:NextNumber(5, 8)
		local offset = Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(0, 3.5), rng:NextNumber(-3, 3))
		blob(m, top + offset, Vector3.new(s, s * 0.8, s), rng, shade(Props.pick(rng, colors), rng, 0.06), M.LeafyGrass)
	end
	return m
end

-- Mangrove on arching stilt roots. `floorY` is where the roots end (sea floor or ground).
function Props.mangrove(
	parent: Instance,
	ground: Vector3,
	rng: Random,
	floorY: number,
	bark: Color3,
	canopy: { Color3 }
): Model
	local m = newModel("Mangrove", parent)
	local h = rng:NextNumber(16, 28)
	local hub = ground + Vector3.new(0, rng:NextNumber(4, 7), 0)
	local top = ground + Vector3.new(rng:NextNumber(-2, 2), h, rng:NextNumber(-2, 2))
	beam(m, hub, top, 1.4, bark, nil, M.Wood)

	for _ = 1, rng:NextInteger(4, 6) do
		local a = rng:NextNumber(0, TAU)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local reach = rng:NextNumber(5, 9)
		local knee = hub + dir * reach * 0.6 + Vector3.new(0, rng:NextNumber(0, 2), 0)
		local foot = Vector3.new(ground.X, floorY, ground.Z) + dir * reach
		beam(m, hub + Vector3.new(0, 1, 0), knee, 0.8, bark, nil, M.Wood)
		beam(m, knee, foot, 0.8, bark, nil, M.Wood)
	end

	local crowns = { top }
	for _ = 1, rng:NextInteger(2, 3) do
		local a = rng:NextNumber(0, TAU)
		local from = hub:Lerp(top, rng:NextNumber(0.5, 0.85))
		local to = from
			+ Vector3.new(math.cos(a) * rng:NextNumber(5, 9), rng:NextNumber(2, 5), math.sin(a) * rng:NextNumber(5, 9))
		beam(m, from, to, 0.7, bark, nil, M.Wood)
		table.insert(crowns, to)
	end
	for _, crown in crowns do
		local s = rng:NextNumber(8, 13)
		local tilt = CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, TAU), rng:NextNumber(-0.2, 0.2))
		part(
			m,
			Vector3.new(s, s * 0.45, s),
			CFrame.new(crown) * tilt,
			shade(Props.pick(rng, canopy), rng, 0.06),
			M.LeafyGrass
		)
	end
	return m
end

function Props.palm(parent: Instance, ground: Vector3, rng: Random): Model
	local m = newModel("Palm", parent)
	local h = rng:NextNumber(14, 22)
	local lean = rng:NextNumber(0, TAU)
	local dir = Vector3.new(math.cos(lean), 0, math.sin(lean))
	local bend = rng:NextNumber(2, 6)

	local prev = ground - Vector3.new(0, 1, 0)
	for k = 1, 5 do
		local t = k / 5
		local p = ground + Vector3.new(0, h * t, 0) + dir * (bend * t * t)
		beam(m, prev, p, 1.3 - t * 0.4, if k % 2 == 0 then rgb(140, 112, 78) else rgb(120, 94, 66), nil, M.Wood)
		prev = p
	end

	local top = prev
	for f = 1, 6 do
		local a = f / 6 * TAU + rng:NextNumber(-0.2, 0.2)
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local mid = top + d * 5 + Vector3.new(0, 1.2, 0)
		local tip = top + d * 10 + Vector3.new(0, -2.5, 0)
		beam(m, top, mid, 2.4, rgb(78, 140, 60), 0.25, M.LeafyGrass)
		beam(m, mid, tip, 2, rgb(62, 118, 52), 0.25, M.LeafyGrass)
	end
	for _ = 1, rng:NextInteger(1, 3) do
		ball(m, top + Vector3.new(rng:NextNumber(-1, 1), -1, rng:NextNumber(-1, 1)), 1.1, rgb(96, 70, 44), M.Wood)
	end
	return m
end

-- Bare trunk with a few branches; swamp snags and charred volcanic trees.
function Props.deadTree(parent: Instance, ground: Vector3, rng: Random, color: Color3): Model
	local m = newModel("DeadTree", parent)
	local h = rng:NextNumber(8, 16)
	local top = ground + Vector3.new(rng:NextNumber(-1.5, 1.5), h, rng:NextNumber(-1.5, 1.5))
	beam(m, ground - Vector3.new(0, 1, 0), top, 1.1, color, nil, M.Wood)
	for _ = 1, rng:NextInteger(2, 3) do
		local a = rng:NextNumber(0, TAU)
		local from = ground:Lerp(top, rng:NextNumber(0.45, 0.85))
		local to = from
			+ Vector3.new(
				math.cos(a) * rng:NextNumber(3, 6),
				rng:NextNumber(1.5, 4),
				math.sin(a) * rng:NextNumber(3, 6)
			)
		beam(m, from, to, 0.5, color, nil, M.Wood)
	end
	return m
end

function Props.bush(parent: Instance, ground: Vector3, rng: Random, colors: { Color3 }): Model
	local m = newModel("Bush", parent)
	for _ = 1, rng:NextInteger(2, 3) do
		local s = rng:NextNumber(2.5, 4.5)
		local offset = Vector3.new(rng:NextNumber(-1.5, 1.5), s * 0.25, rng:NextNumber(-1.5, 1.5))
		blob(
			m,
			ground + offset,
			Vector3.new(s, s * 0.7, s),
			rng,
			shade(Props.pick(rng, colors), rng, 0.06),
			M.LeafyGrass
		)
	end
	return m
end

-- Little clump of flowers.
function Props.flowers(parent: Instance, ground: Vector3, rng: Random): Model
	local m = newModel("Flowers", parent)
	local colors = { rgb(230, 90, 90), rgb(250, 210, 90), rgb(240, 240, 240), rgb(180, 120, 220), rgb(250, 150, 60) }
	local color = Props.pick(rng, colors)
	for _ = 1, rng:NextInteger(4, 7) do
		local at = ground + Vector3.new(rng:NextNumber(-1.8, 1.8), 0, rng:NextNumber(-1.8, 1.8))
		part(m, Vector3.new(0.15, 1.2, 0.15), CFrame.new(at + Vector3.new(0, 0.6, 0)), rgb(80, 120, 60), M.Grass)
		ball(m, at + Vector3.new(0, 1.3, 0), 0.6, color, M.Plastic)
	end
	return m
end

----------------------------------------------------------------------------------------------------
-- Rocks and ice

function Props.rock(parent: Instance, ground: Vector3, rng: Random, size: number, color: Color3): Part
	return blob(
		parent,
		ground + Vector3.new(0, size * 0.2, 0),
		Vector3.new(size, size * rng:NextNumber(0.5, 0.9), size * rng:NextNumber(0.7, 1.1)),
		rng,
		shade(color, rng, 0.08),
		M.Rock
	)
end

function Props.boulder(
	parent: Instance,
	ground: Vector3,
	rng: Random,
	radius: number,
	color: Color3,
	material: Enum.Material?
): Model
	local m = newModel("Boulder", parent)
	LowPoly.boulder(
		ground + Vector3.new(0, radius * 0.3, 0),
		radius,
		rng,
		shade(color, rng, 0.06),
		m,
		material or M.Rock
	)
	return m
end

-- Tall leaning four-sided shard (ice spikes, obsidian).
function Props.spike(
	parent: Instance,
	ground: Vector3,
	rng: Random,
	height: number,
	radius: number,
	color: Color3,
	material: Enum.Material?
): Model
	local m = newModel("Spike", parent)
	local spin = rng:NextNumber(0, TAU)
	local base = {}
	for i = 0, 3 do
		local a = spin + i * TAU / 4 + rng:NextNumber(-0.2, 0.2)
		local r = radius * rng:NextNumber(0.8, 1.2)
		base[i + 1] = ground + Vector3.new(math.cos(a) * r, -2, math.sin(a) * r)
	end
	local lean = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * height * 0.15
	LowPoly.pyramid(base, ground + Vector3.new(0, height, 0) + lean, shade(color, rng, 0.05), m, material or M.Ice)
	return m
end

-- Cluster of basalt columns.
function Props.basalt(parent: Instance, ground: Vector3, rng: Random, color: Color3): Model
	local m = newModel("Basalt", parent)
	for _ = 1, rng:NextInteger(3, 6) do
		local h = rng:NextNumber(4, 12)
		local offset = Vector3.new(rng:NextNumber(-3, 3), h / 2 - 1, rng:NextNumber(-3, 3))
		part(
			m,
			Vector3.new(2.6, h, 2.6),
			CFrame.new(ground + offset) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
			shade(color, rng, 0.1),
			M.Basalt
		)
	end
	return m
end

----------------------------------------------------------------------------------------------------
-- Water plants

function Props.reeds(parent: Instance, position: Vector3, rng: Random): Model
	local m = newModel("Reeds", parent)
	for _ = 1, rng:NextInteger(5, 8) do
		local base = position + Vector3.new(rng:NextNumber(-2.5, 2.5), -3, rng:NextNumber(-2.5, 2.5))
		local tip = base + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(7, 12), rng:NextNumber(-1, 1))
		beam(m, base, tip, 0.35, shade(rgb(150, 150, 72), rng, 0.12), nil, M.Grass)
	end
	return m
end

function Props.lilyPad(parent: Instance, position: Vector3, rng: Random): Model
	local m = newModel("LilyPad", parent)
	local d = rng:NextNumber(2.5, 5)
	cylinder(m, position + Vector3.new(0, 0.1, 0), 0.2, d, shade(rgb(84, 116, 56), rng, 0.1), M.LeafyGrass)
	if rng:NextNumber() < 0.2 then
		blob(m, position + Vector3.new(0, 0.5, 0), Vector3.new(0.9, 0.9, 0.9), rng, rgb(230, 170, 190), M.Plastic)
	end
	return m
end

function Props.coral(parent: Instance, ground: Vector3, rng: Random, colors: { Color3 }): Model
	local m = newModel("Coral", parent)
	for _ = 1, rng:NextInteger(2, 4) do
		local s = rng:NextNumber(1.5, 4)
		local offset = Vector3.new(rng:NextNumber(-2, 2), s * 0.4, rng:NextNumber(-2, 2))
		blob(m, ground + offset, Vector3.new(s * 0.6, s * 1.4, s * 0.6), rng, Props.pick(rng, colors), M.Pebble)
	end
	return m
end

----------------------------------------------------------------------------------------------------
-- Buildings

local SHUTTERS = { rgb(70, 92, 112), rgb(112, 60, 50), rgb(72, 102, 74), rgb(64, 62, 60) }

-- Cottage with timber corners, framed windows and a gabled roof; front door on its local +Z.
-- `stilts` raises it on posts (swamp shacks, beach huts). Tall ones get a second floor of windows.
function Props.house(
	parent: Instance,
	ground: Vector3,
	facing: number,
	rng: Random,
	wall: Color3,
	roof: Color3,
	stilts: number?
): Model
	local m = newModel("House", parent)
	local w, d = rng:NextNumber(11, 16), rng:NextNumber(9, 13)
	local stories = if not stilts and rng:NextNumber() < 0.3 then 2 else 1
	local h = if stories == 2 then rng:NextNumber(15, 17) else rng:NextNumber(8, 10.5)
	local lift = stilts or 0
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	local trim = wall:Lerp(Color3.new(0, 0, 0), 0.45)
	local shutter = Props.pick(rng, SHUTTERS)
	local wallMaterial = if stilts or rng:NextNumber() < 0.45 then M.WoodPlanks else M.Plaster
	local roofMaterial = if stilts then M.Fabric elseif rng:NextNumber() < 0.5 then M.RoofShingles else M.ClayRoofTiles

	if lift > 0 then
		for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
			local x, z = c[1] * (w / 2 - 0.5), c[2] * (d / 2 - 0.5)
			beam(
				m,
				base:PointToWorldSpace(Vector3.new(x, -6, z)),
				base:PointToWorldSpace(Vector3.new(x, lift, z)),
				0.9,
				WOOD_DARK,
				nil,
				M.Wood
			)
		end
		part(m, Vector3.new(w + 2, 0.6, d + 4), base * CFrame.new(0, lift - 0.7, 1.5), WOOD, M.WoodPlanks)
	end

	local floor = if lift > 0 then lift - 0.4 else 0.6
	if lift == 0 then
		part(m, Vector3.new(w + 0.8, 2, d + 0.8), base * CFrame.new(0, -0.4, 0), STONE, M.Cobblestone)
	end
	part(m, Vector3.new(w, h, d), base * CFrame.new(0, floor + h / 2, 0), wall, wallMaterial)
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		part(m, Vector3.new(0.8, h, 0.8), base * CFrame.new(c[1] * w / 2, floor + h / 2, c[2] * d / 2), trim, M.Wood)
	end
	if stories == 2 then
		part(m, Vector3.new(w + 0.4, 0.6, d + 0.4), base * CFrame.new(0, floor + h / 2, 0), trim, M.Wood)
	end

	-- Roof: two slanted panels, a ridge beam and the gable triangles
	local top = floor + h
	local pitch = math.rad(rng:NextNumber(32, 42))
	local rise = d / 2 * math.tan(pitch)
	local slant = (d / 2 + 1.2) / math.cos(pitch)
	for side = -1, 1, 2 do
		part(
			m,
			Vector3.new(w + 1.8, 0.7, slant),
			base * CFrame.new(0, top + rise / 2, side * d / 4) * CFrame.Angles(side * pitch, 0, 0),
			roof,
			roofMaterial
		)
		local x = side * w / 2
		LowPoly.triangle(
			base:PointToWorldSpace(Vector3.new(x, top, -d / 2)),
			base:PointToWorldSpace(Vector3.new(x, top, d / 2)),
			base:PointToWorldSpace(Vector3.new(x, top + rise, 0)),
			base:PointToWorldSpace(Vector3.new(0, top, 0)),
			wall,
			m,
			wallMaterial
		)
	end
	part(
		m,
		Vector3.new(w + 2, 0.8, 0.8),
		base * CFrame.new(0, top + rise + 0.2, 0),
		roof:Lerp(Color3.new(0, 0, 0), 0.3),
		M.Wood
	)

	-- Door with a frame, a handle and a step
	local front = d / 2
	part(m, Vector3.new(3.4, 5.8, 0.2), base * CFrame.new(0, floor + 2.9, front + 0.05), trim, M.Wood)
	part(m, Vector3.new(2.4, 5, 0.3), base * CFrame.new(0, floor + 2.5, front + 0.1), WOOD_DARK, M.WoodPlanks)
	ball(m, base:PointToWorldSpace(Vector3.new(0.8, floor + 2.5, front + 0.3)), 0.35, rgb(200, 170, 80), M.Metal)
	if lift == 0 then
		part(m, Vector3.new(4, 0.6, 1.6), base * CFrame.new(0, floor - 0.2, front + 0.8), STONE, M.Slate)
	end

	-- Framed, shuttered front windows on every floor, plain windows on the sides
	local storyHeight = h / stories
	for s = 1, stories do
		local y = floor + (s - 1) * storyHeight + storyHeight * 0.55
		for side = -1, 1, 2 do
			local x = side * (w / 4 + 0.8)
			part(m, Vector3.new(2.4, 2.6, 0.15), base * CFrame.new(x, y, front + 0.05), trim, M.Wood)
			local glass = part(m, Vector3.new(1.7, 1.9, 0.2), base * CFrame.new(x, y, front + 0.1), LAMP, M.Neon)
			part(m, Vector3.new(0.15, 1.9, 0.25), base * CFrame.new(x, y, front + 0.12), trim, M.Wood)
			part(m, Vector3.new(2.8, 0.3, 0.7), base * CFrame.new(x, y - 1.4, front + 0.3), trim, M.Wood)
			for flap = -1, 1, 2 do
				part(
					m,
					Vector3.new(0.8, 2.6, 0.15),
					base * CFrame.new(x + flap * 1.7, y, front + 0.1),
					shutter,
					M.WoodPlanks
				)
			end
			if s == 1 and side == 1 then
				light(glass, LAMP, 16, 0.8)
			end
			part(m, Vector3.new(0.2, 1.9, 1.7), base * CFrame.new(side * (w / 2 + 0.05), y, 0), LAMP, M.Neon)
		end
	end

	if rng:NextNumber() < 0.6 then
		local chimney = base * CFrame.new(w / 3, top + rise * 0.7, -d / 5)
		part(m, Vector3.new(1.8, rise + 3, 1.8), chimney, rgb(140, 84, 66), M.Brick)
		part(m, Vector3.new(2.3, 0.5, 2.3), chimney * CFrame.new(0, (rise + 3) / 2, 0), rgb(80, 70, 66), M.Slate)
	end
	if lift == 0 and rng:NextNumber() < 0.45 then
		-- Little porch roof over the door, with a lantern
		part(
			m,
			Vector3.new(5, 0.4, 2.8),
			base * CFrame.new(0, floor + 6, front + 1.3) * CFrame.Angles(0.25, 0, 0),
			roof,
			roofMaterial
		)
		for side = -1, 1, 2 do
			part(m, Vector3.new(0.4, 6, 0.4), base * CFrame.new(side * 2.2, floor + 3, front + 2.5), trim, M.Wood)
		end
		Props.lantern(m, base * CFrame.new(1.6, floor + 5.2, front + 0.6))
	end
	if rng:NextNumber() < 0.4 then
		local box = base * CFrame.new(-(w / 4 + 0.8), floor + storyHeight * 0.55 - 2, front + 0.7)
		part(m, Vector3.new(2.8, 0.8, 0.9), box, WOOD, M.WoodPlanks)
		for k = -1, 1 do
			ball(
				m,
				box.Position + base.RightVector * k * 0.8 + Vector3.new(0, 0.6, 0),
				0.7,
				Props.pick(rng, {
					rgb(220, 80, 80),
					rgb(250, 210, 90),
					rgb(240, 240, 240),
				}),
				M.Plastic
			)
		end
	end
	Props.simplifyHouseCollision(m)
	return m
end

-- Waterside fishing hut on a plank deck: front porch under a tin roof, life ring, lantern and bench.
-- Faces its local +Z. `color` tints the plank walls.
function Props.fishingHut(parent: Instance, ground: Vector3, facing: number, rng: Random, color: Color3): Model
	local m = newModel("FishingHut", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	local w, d, h = 16, 12, 10
	local wall = color:Lerp(rgb(150, 150, 140), 0.45)
	local trim = rgb(96, 70, 50)
	local tin = rgb(118, 122, 124)

	-- Raised deck with a porch out front
	part(m, Vector3.new(w + 4, 0.8, d + 9), base * CFrame.new(0, 0.6, 2.5), WOOD, M.WoodPlanks)
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		part(
			m,
			Vector3.new(0.9, 2, 0.9),
			base * CFrame.new(c[1] * (w / 2 + 1.5), 0, 2.5 + c[2] * (d + 8) / 2),
			WOOD_DARK,
			M.Wood
		)
	end
	part(m, Vector3.new(w, h, d), base * CFrame.new(0, 1 + h / 2, 0), wall, M.WoodPlanks)
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		part(m, Vector3.new(0.8, h, 0.8), base * CFrame.new(c[1] * w / 2, 1 + h / 2, c[2] * d / 2), trim, M.Wood)
	end
	part(m, Vector3.new(w + 0.4, 0.6, d + 0.4), base * CFrame.new(0, 1.3, 0), trim, M.Wood)

	-- Gabled tin roof that runs forward over the porch
	local top = 1 + h
	local pitch = math.rad(28)
	local rise = w / 2 * math.tan(pitch)
	local depth = d + 7
	for side = -1, 1, 2 do
		local slant = (w / 2 + 1.2) / math.cos(pitch)
		part(
			m,
			Vector3.new(slant, 0.5, depth),
			base * CFrame.new(side * w / 4, top + rise / 2, 3) * CFrame.Angles(0, 0, -side * pitch),
			tin,
			M.CorrodedMetal
		)
		local z = side * d / 2
		LowPoly.triangle(
			base:PointToWorldSpace(Vector3.new(-w / 2, top, z)),
			base:PointToWorldSpace(Vector3.new(w / 2, top, z)),
			base:PointToWorldSpace(Vector3.new(0, top + rise, z)),
			base:PointToWorldSpace(Vector3.new(0, top, 0)),
			wall,
			m,
			M.WoodPlanks
		)
	end
	part(m, Vector3.new(0.8, 0.8, depth + 0.4), base * CFrame.new(0, top + rise + 0.2, 3), trim, M.Wood)
	for side = -1, 1, 2 do
		part(m, Vector3.new(0.7, h, 0.7), base * CFrame.new(side * (w / 2 - 0.4), 1 + h / 2, d / 2 + 6.2), trim, M.Wood)
	end

	-- Porch railing with a gap for the steps
	local railY = 3
	for side = -1, 1, 2 do
		local x = side * (w / 2 + 1.6)
		beam(
			m,
			base:PointToWorldSpace(Vector3.new(x, railY, d / 2)),
			base:PointToWorldSpace(Vector3.new(x, railY, d / 2 + 6.5)),
			0.35,
			trim,
			nil,
			M.Wood
		)
		part(m, Vector3.new(0.4, 2.5, 0.4), base * CFrame.new(x, 2, d / 2 + 6.5), trim, M.Wood)
		beam(
			m,
			base:PointToWorldSpace(Vector3.new(x, railY, d / 2 + 6.5)),
			base:PointToWorldSpace(Vector3.new(side * 3, railY, d / 2 + 6.5)),
			0.35,
			trim,
			nil,
			M.Wood
		)
	end

	-- Front: door, window, life ring, lantern
	local front = d / 2
	part(m, Vector3.new(3.6, 6.4, 0.2), base * CFrame.new(-3, 4.2, front + 0.05), trim, M.Wood)
	part(m, Vector3.new(2.8, 5.8, 0.3), base * CFrame.new(-3, 3.9, front + 0.1), WOOD_DARK, M.WoodPlanks)
	part(m, Vector3.new(4.2, 3.4, 0.15), base * CFrame.new(3.5, 6, front + 0.05), trim, M.Wood)
	local glass = part(m, Vector3.new(3.4, 2.6, 0.2), base * CFrame.new(3.5, 6, front + 0.1), LAMP, M.Neon)
	light(glass, LAMP, 18, 0.9)
	part(m, Vector3.new(0.2, 2.6, 0.25), base * CFrame.new(3.5, 6, front + 0.15), trim, M.Wood)
	part(m, Vector3.new(4.6, 0.3, 0.8), base * CFrame.new(3.5, 4.2, front + 0.4), trim, M.Wood)
	Props.lifeRing(m, base * CFrame.new(0.2, 7.6, front + 0.3))
	Props.lantern(m, base * CFrame.new(-0.6, 9.2, front + 4))
	Props.bench(m, base:PointToWorldSpace(Vector3.new(3.5, 1, front + 1.6)), facing + math.pi)
	Props.crates(m, base:PointToWorldSpace(Vector3.new(-w / 2 - 0.2, 1, front + 5)), rng)
	Props.ropeCoil(m, base:PointToWorldSpace(Vector3.new(w / 2 - 1, 1, front + 5)))

	-- Side window and a stovepipe
	part(m, Vector3.new(0.2, 2.4, 3), base * CFrame.new(w / 2 + 0.05, 6, -1), LAMP, M.Neon)
	part(m, Vector3.new(0.15, 3, 3.6), base * CFrame.new(w / 2 + 0.02, 6, -1), trim, M.Wood)
	cylinder(m, base:PointToWorldSpace(Vector3.new(-w / 4, top + rise + 1.5, -d / 4)), 4, 1.2, IRON, M.Metal)
	return m
end

function Props.clockTower(parent: Instance, ground: Vector3, facing: number): Model
	local m = newModel("ClockTower", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	part(m, Vector3.new(11, 2, 11), base * CFrame.new(0, 0, 0), STONE, M.Cobblestone)
	part(m, Vector3.new(9, 30, 9), base * CFrame.new(0, 15, 0), WHITE, M.Plaster)
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		part(m, Vector3.new(1.2, 30, 1.2), base * CFrame.new(c[1] * 4.5, 15, c[2] * 4.5), STONE, M.Brick)
	end
	part(m, Vector3.new(10, 1.2, 10), base * CFrame.new(0, 29.6, 0), rgb(90, 80, 76), M.Slate)
	part(m, Vector3.new(7, 8, 7), base * CFrame.new(0, 34, 0), WHITE, M.Plaster)
	for k = 0, 3 do
		local side = base * CFrame.Angles(0, k * math.pi / 2, 0)
		cylinder(m, (side * CFrame.new(0, 34, 3.6)).Position, 0.3, 4.4, rgb(255, 240, 200), M.Neon).CFrame = side
			* CFrame.new(0, 34, 3.6)
			* CFrame.Angles(0, math.pi / 2, 0)
		part(m, Vector3.new(0.3, 1.6, 0.2), side * CFrame.new(0, 34.6, 3.85), IRON, M.Metal)
		part(m, Vector3.new(1.2, 0.3, 0.2), side * CFrame.new(0.5, 34, 3.85), IRON, M.Metal)
		part(m, Vector3.new(2.2, 3.2, 0.2), side * CFrame.new(0, 20, 4.55), rgb(70, 92, 112), M.Glass)
	end
	part(m, Vector3.new(3.4, 6.4, 0.2), base * CFrame.new(0, 4.2, 4.55), rgb(90, 80, 76), M.Wood)
	part(m, Vector3.new(3, 6, 0.3), base * CFrame.new(0, 4, 4.6), WOOD_DARK, M.WoodPlanks)

	local corners = {}
	for i, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		corners[i] = base:PointToWorldSpace(Vector3.new(c[1] * 4.5, 38, c[2] * 4.5))
	end
	LowPoly.pyramid(corners, base:PointToWorldSpace(Vector3.new(0, 47, 0)), RED, m, M.RoofShingles)
	return m
end

-- Small dock details never snag characters, boats, or interaction raycasts.
local function dockDetail(p: BasePart, name: string): BasePart
	p.Name = name
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local DOCK_WOOD = rgb(119, 83, 53)
local DOCK_WORN = rgb(158, 122, 81)
local DOCK_PILE = rgb(77, 55, 39)

-- Local -Z runs along the section. Every board has a level top at local Y = 0.3.
local function dockDeck(parent: Model, frame: CFrame, width: number, length: number, rng: Random)
	-- A single walking surface keeps plank seams out of the navmesh and physics.
	local surface =
		part(parent, Vector3.new(width, 0.6, length), frame * CFrame.new(0, 0, -length / 2), DOCK_WOOD, M.Wood)
	surface.Name = "DeckSurface"
	surface.Transparency, surface.CastShadow = 1, false
	local count = math.ceil(length / 1.3)
	local pitch = length / count
	for i = 1, count do
		local z = -(i - 0.5) * pitch
		local color = DOCK_WOOD:Lerp(DOCK_WORN, rng:NextNumber(0.08, 0.8))
		local board = part(parent, Vector3.new(width, 0.6, pitch - 0.055), frame * CFrame.new(0, 0, z), color, M.Wood)
		board.Name = "DeckPlank"
		board.CanCollide, board.CanQuery = false, false
		if i % 3 == 1 then
			for _, side in { -1, 1 } do
				dockDetail(
					cylinder(
						parent,
						(frame * CFrame.new(side * (width / 2 - 0.6), 0.306, z)).Position,
						0.025,
						0.13,
						IRON,
						M.Metal
					),
					"PlankNail"
				)
			end
		end
	end
	for _, side in { -1, 1 } do
		local stringer = part(
			parent,
			Vector3.new(0.5, 0.85, length),
			frame * CFrame.new(side * (width / 2 - 0.3), -0.65, -length / 2),
			DOCK_PILE,
			M.Wood
		)
		stringer.Name = "Stringer"
	end
end

local function dockPile(parent: Model, frame: CFrame, x: number, z: number, rng: Random)
	local position = frame * CFrame.new(x, 0, z)
	local pile =
		cylinder(parent, (position * CFrame.new(0, -7.2, 0)).Position, 18, 1.2, shade(DOCK_PILE, rng, 0.08), M.Wood)
	pile.Name = "Pile"
	dockDetail(
		cylinder(parent, (position * CFrame.new(0, 1.83, 0)).Position, 0.1, 1.24, DOCK_WORN, M.Wood),
		"PileEndGrain"
	)
	dockDetail(
		cylinder(parent, (position * CFrame.new(0, -3.1, 0)).Position, 0.85, 1.23, rgb(65, 69, 48), M.Wood),
		"TidalMark"
	)
	dockDetail(cylinder(parent, (position * CFrame.new(0, -0.5, 0)).Position, 0.18, 1.26, IRON, M.Metal), "PileCollar")
	for i = 0, 2 do
		dockDetail(
			cylinder(parent, (position * CFrame.new(0, 1.05 + i * 0.14, 0)).Position, 0.11, 1.3, ROPE, M.Fabric),
			"RopeLashing"
		)
	end
end

local function dockRope(parent: Model, frame: CFrame, a: Vector3, b: Vector3)
	local previous = frame:PointToWorldSpace(a)
	for i = 1, 4 do
		local t = i / 4
		local nextPoint = frame:PointToWorldSpace(a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * 0.24, 0))
		dockDetail(beam(parent, previous, nextPoint, 0.18, ROPE, nil, M.Fabric), "RopeRail")
		previous = nextPoint
	end
end

-- Warm inset panes with dark metal frames, mounted outside the walking lane.
local function dockLamp(parent: Model, frame: CFrame)
	local model = newModel("DockLamp", parent)
	part(model, Vector3.new(0.5, 4.8, 0.5), frame * CFrame.new(0, 2.4, 0), DOCK_PILE, M.Wood)
	part(model, Vector3.new(1.15, 0.18, 1.15), frame * CFrame.new(0, 4.85, 0), IRON, M.Metal)
	local pane = part(model, Vector3.new(0.76, 1.05, 0.76), frame * CFrame.new(0, 5.45, 0), rgb(255, 228, 163), M.Neon)
	dockDetail(pane, "LampPane")
	light(pane, rgb(255, 215, 148), 17, 1.15)
	for _, x in { -0.48, 0.48 } do
		for _, z in { -0.48, 0.48 } do
			dockDetail(
				part(model, Vector3.new(0.1, 1.2, 0.1), frame * CFrame.new(x, 5.45, z), IRON, M.Metal),
				"LampFrame"
			)
		end
	end
	dockDetail(part(model, Vector3.new(1.35, 0.22, 1.35), frame * CFrame.new(0, 6.12, 0), IRON, M.Metal), "LampCap")
end

type DockOptions = { innerSide: number?, junctionStart: number?, junctionEnd: number? }

-- Pier with an open central walk lane and an optional opening for the crosswalk.
function Props.dock(
	parent: Instance,
	start: Vector3,
	direction: Vector3,
	length: number,
	rng: Random,
	options: DockOptions?
): Vector3
	local m = newModel("Dock", parent)
	local origin = Vector3.new(start.X, 3, start.Z)
	local frame = CFrame.lookAt(origin, origin + Vector3.new(direction.X, 0, direction.Z))
	dockDeck(m, frame, 7, length, rng)
	local postsZ = { 1.2 }
	for z = 10.2, length - 2, 9 do
		table.insert(postsZ, z)
	end
	table.insert(postsZ, length - 1.2)
	for _, side in { -1, 1 } do
		local sidePosts = {}
		for _, z in postsZ do
			if
				not (
					options
					and side == options.innerSide
					and options.junctionStart
					and options.junctionEnd
					and z > options.junctionStart
					and z < options.junctionEnd
				)
			then
				table.insert(sidePosts, z)
			end
		end
		if options and side == options.innerSide and options.junctionStart and options.junctionEnd then
			if not table.find(sidePosts, options.junctionStart) then
				table.insert(sidePosts, options.junctionStart)
			end
			if not table.find(sidePosts, options.junctionEnd) then
				table.insert(sidePosts, options.junctionEnd)
			end
		end
		table.sort(sidePosts)
		for _, z in sidePosts do
			dockPile(m, frame, side * 3.85, -z, rng)
		end
		for i = 1, #sidePosts - 1 do
			local a, b = sidePosts[i], sidePosts[i + 1]
			if
				not (options and side == options.innerSide and a == options.junctionStart and b == options.junctionEnd)
			then
				dockRope(m, frame, Vector3.new(side * 3.85, 1.3, -a), Vector3.new(side * 3.85, 1.3, -b))
			end
		end
	end
	for i, z in postsZ do
		local bearer = part(m, Vector3.new(8.5, 0.65, 0.7), frame * CFrame.new(0, -1.1, -z), DOCK_PILE, M.Wood)
		bearer.Name = "Bearer"
		if i % 2 == 0 then
			for _, side in { -1, 1 } do
				local brace = beam(
					m,
					frame * Vector3.new(side * 3.85, -3.2, -z),
					frame * Vector3.new(side * 0.7, -1.45, -z),
					0.35,
					DOCK_WOOD,
					nil,
					M.Wood
				)
				brace.Name = "Brace"
			end
		end
	end
	local lampSide = if options and options.innerSide then -options.innerSide else 1
	dockLamp(m, frame * CFrame.new(lampSide * 4.15, 0.3, -(length - 1.2)))
	-- Keep the ladder beyond the tip and the landing free of loose props.
	Props.ladder(m, frame * CFrame.new(-1.5, 0, -length), -6)
	return (frame * CFrame.new(0, 0.3, -(length - 5))).Position
end

-- Matching boarded crosswalk. Local X spans 27 studs; both ends stay open.
function Props.dockLink(parent: Instance, frame: CFrame, rng: Random): Model
	local model = newModel("DockLink", parent)
	local along = frame * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(0, 0, 13.5)
	dockDeck(model, along, 5, 27, rng)
	for _, x in { -8, 0, 8 } do
		dockPile(model, frame, x, -3.1, rng)
		local joist = part(model, Vector3.new(0.7, 0.7, 6.6), frame * CFrame.new(x, -1.1, 0), DOCK_PILE, M.Wood)
		joist.Name = "Joist"
	end
	for _, a in { -8, 0 } do
		dockRope(model, frame, Vector3.new(a, 1.3, -3.1), Vector3.new(a + 8, 1.3, -3.1))
	end
	return model
end

-- Big striped lighthouse on a round stone platform. Its "LighthouseLens" part is spun by Map.animate.
function Props.lighthouse(parent: Instance, ground: Vector3): Model
	local m = newModel("Lighthouse", parent)
	local gx, gz = ground.X, ground.Z

	-- Round platform with a fence around the edge
	cylinder(m, Vector3.new(gx, ground.Y + 0.5, gz), 3, 36, STONE, M.Cobblestone)
	local fence = {}
	for i = 1, 20 do
		local a = i / 20 * TAU
		fence[i] = Vector3.new(gx + math.cos(a) * 17, ground.Y + 2, gz + math.sin(a) * 17)
		part(m, Vector3.new(0.5, 3, 0.5), CFrame.new(fence[i] + Vector3.new(0, 1.5, 0)), WOOD_DARK, M.Wood)
	end
	for i = 1, 20 do
		if i ~= 5 then -- gap facing the path
			beam(
				m,
				fence[i] + Vector3.new(0, 2.4, 0),
				fence[i % 20 + 1] + Vector3.new(0, 2.4, 0),
				0.3,
				WOOD,
				nil,
				M.WoodPlanks
			)
		end
	end

	local y = ground.Y + 2
	local r = 8.5
	for i = 1, 7 do
		cylinder(m, Vector3.new(gx, y + 4, gz), 8, r * 2, if i % 2 == 1 then WHITE else RED, M.Plaster)
		if i % 2 == 0 then
			for _, a in { 0, math.pi } do
				local face = CFrame.new(gx, y + 4, gz) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, r - 0.2)
				part(m, Vector3.new(1.6, 2.6, 0.6), face, rgb(50, 56, 62), M.Glass)
			end
		end
		y += 8
		r -= 0.5
	end
	part(m, Vector3.new(3, 6, 0.6), CFrame.new(gx, ground.Y + 5, gz) * CFrame.new(0, 0, 8.4), WOOD_DARK, M.WoodPlanks)

	-- Gallery with railing
	cylinder(m, Vector3.new(gx, y + 0.5, gz), 1, (r + 3) * 2, rgb(60, 56, 54), M.DiamondPlate)
	local rail = {}
	for i = 1, 16 do
		local a = i / 16 * TAU
		rail[i] = Vector3.new(gx + math.cos(a) * (r + 2.6), y + 1, gz + math.sin(a) * (r + 2.6))
		part(m, Vector3.new(0.3, 3, 0.3), CFrame.new(rail[i] + Vector3.new(0, 1.5, 0)), IRON, M.Metal)
	end
	for i = 1, 16 do
		beam(m, rail[i] + Vector3.new(0, 3, 0), rail[i % 16 + 1] + Vector3.new(0, 3, 0), 0.3, IRON, nil, M.Metal)
	end

	-- Lantern room
	local glass = cylinder(m, Vector3.new(gx, y + 4, gz), 6, (r - 0.5) * 2, rgb(255, 240, 200), M.SmoothPlastic)
	glass.Transparency = 0.5
	local lamp = ball(m, Vector3.new(gx, y + 4, gz), 3, LAMP, M.Neon)
	light(lamp, LAMP, 100, 3)

	local lens = part(m, Vector3.new(1, 1, 1), CFrame.new(gx, y + 4, gz), LAMP)
	lens.Name = "LighthouseLens"
	lens.Transparency = 1
	lens.CanCollide = false
	lens.CanQuery = false
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Range = 60
	spot.Angle = 35
	spot.Brightness = 8
	spot.Color = LAMP
	spot.Parent = lens
	local a0 = Instance.new("Attachment")
	a0.Parent = lens
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0, -180)
	a1.Parent = lens
	local ray = Instance.new("Beam")
	ray.Attachment0 = a0
	ray.Attachment1 = a1
	ray.Width0 = 3
	ray.Width1 = 40
	ray.FaceCamera = true
	ray.LightEmission = 1
	ray.Segments = 1
	ray.Color = ColorSequence.new(LAMP)
	ray.Transparency = NumberSequence.new(0.55, 1)
	ray.Parent = lens

	-- Domed cap
	cylinder(m, Vector3.new(gx, y + 7.3, gz), 0.6, (r + 0.6) * 2, RED, M.Metal)
	local cap = {}
	for i = 1, 8 do
		local a = i / 8 * TAU
		cap[i] = Vector3.new(gx + math.cos(a) * (r + 0.3), y + 7.6, gz + math.sin(a) * (r + 0.3))
	end
	LowPoly.pyramid(cap, Vector3.new(gx, y + 12, gz), RED, m, M.Metal)
	ball(m, Vector3.new(gx, y + 12.5, gz), 1.4, IRON, M.Metal)
	return m
end

-- Channel marker floating at the waterline.
function Props.buoy(parent: Instance, position: Vector3, rng: Random): Model
	local m = newModel("Buoy", parent)
	local color = if rng:NextNumber() < 0.5 then RED else WHITE
	cylinder(m, position + Vector3.new(0, 0.3, 0), 2.4, 5, color, M.Plastic)
	cylinder(m, position + Vector3.new(0, 1.6, 0), 0.5, 5.4, rgb(60, 56, 54), M.Rubber)
	local top = position + Vector3.new(0, 7, 0)
	for k = 0, 2 do
		local a = k * TAU / 3
		beam(m, position + Vector3.new(math.cos(a) * 1.8, 1.5, math.sin(a) * 1.8), top, 0.35, color, nil, M.Metal)
	end
	local lamp = part(m, Vector3.new(1.2, 1.2, 1.2), CFrame.new(top + Vector3.new(0, 0.6, 0)), LAMP, M.Neon)
	light(lamp, LAMP, 24, 2)
	return m
end

----------------------------------------------------------------------------------------------------
-- Harbour and village clutter

function Props.lampPost(parent: Instance, ground: Vector3): Model
	local m = newModel("LampPost", parent)
	part(m, Vector3.new(1.4, 0.8, 1.4), CFrame.new(ground + Vector3.new(0, 0.4, 0)), IRON, M.Metal)
	cylinder(m, ground + Vector3.new(0, 4.5, 0), 9, 0.55, IRON, M.Metal)
	part(m, Vector3.new(1.8, 0.4, 1.8), CFrame.new(ground + Vector3.new(0, 10.8, 0)), IRON, M.Metal)
	part(m, Vector3.new(0.8, 0.5, 0.8), CFrame.new(ground + Vector3.new(0, 11.2, 0)), IRON, M.Metal)
	local lamp = part(m, Vector3.new(1.1, 1.5, 1.1), CFrame.new(ground + Vector3.new(0, 9.8, 0)), LAMP, M.Neon)
	light(lamp, LAMP, 22, 1.2)
	return m
end

-- Small hanging lantern centred on `cframe`.
function Props.lantern(parent: Instance, cframe: CFrame, range: number?, brightness: number?): Model
	local m = newModel("Lantern", parent)
	part(m, Vector3.new(0.2, 1, 0.2), cframe * CFrame.new(0, 1.1, 0), IRON, M.Metal)
	part(m, Vector3.new(1.2, 0.3, 1.2), cframe * CFrame.new(0, 0.6, 0), IRON, M.Metal)
	part(m, Vector3.new(1.2, 0.2, 1.2), cframe * CFrame.new(0, -0.6, 0), IRON, M.Metal)
	local glow = part(m, Vector3.new(0.9, 1, 0.9), cframe, LAMP, M.Neon)
	light(glow, LAMP, range or 14, brightness or 1)
	return m
end

-- Festoon of coloured bulbs sagging between two points.
function Props.stringLights(parent: Instance, a: Vector3, b: Vector3, rng: Random, sag: number?): Model
	local m = newModel("StringLights", parent)
	local colors = { rgb(255, 200, 120), rgb(255, 150, 60), rgb(170, 110, 255), rgb(120, 220, 255) }
	local droop = sag or (b - a).Magnitude * 0.08
	local count = math.max(4, math.floor((b - a).Magnitude / 4))
	local prev = a
	for i = 1, count do
		local t = i / count
		local p = a:Lerp(b, t) - Vector3.new(0, droop * 4 * t * (1 - t), 0)
		beam(m, prev, p, 0.12, IRON, nil, M.Fabric)
		if i < count then
			local bulb = ball(m, p - Vector3.new(0, 0.35, 0), 0.5, Props.pick(rng, colors), M.Neon)
			bulb.CanCollide = false
			bulb.CastShadow = false
		end
		prev = p
	end
	return m
end

-- Red-and-white life ring hung on a wall; `cframe` faces out of the wall.
function Props.lifeRing(parent: Instance, cframe: CFrame): Model
	local m = newModel("LifeRing", parent)
	local sides = 8
	for i = 1, sides do
		local a0, a1 = (i - 1) / sides * TAU, i / sides * TAU
		local p0 = cframe:PointToWorldSpace(Vector3.new(math.cos(a0) * 1.3, math.sin(a0) * 1.3, 0))
		local p1 = cframe:PointToWorldSpace(Vector3.new(math.cos(a1) * 1.3, math.sin(a1) * 1.3, 0))
		beam(m, p0, p1, 0.55, if i % 2 == 0 then RED else WHITE, 0.55, M.Plastic)
	end
	return m
end

-- Ladder hanging down from `top` (its local -Z is out over the water) to height `bottomY`.
function Props.ladder(parent: Instance, top: CFrame, bottomY: number): Model
	local m = newModel("Ladder", parent)
	local height = top.Position.Y - bottomY
	for side = -1, 1, 2 do
		part(
			m,
			Vector3.new(0.3, height + 1.5, 0.3),
			top * CFrame.new(side * 0.9, -height / 2 + 0.75, -0.3),
			WOOD_DARK,
			M.Wood
		)
	end
	for y = 0.8, height, 1.4 do
		part(m, Vector3.new(1.8, 0.2, 0.25), top * CFrame.new(0, -y + 0.8, -0.3), WOOD, M.Wood)
	end
	return m
end

function Props.ropeCoil(parent: Instance, ground: Vector3): Model
	local m = newModel("RopeCoil", parent)
	cylinder(m, ground + Vector3.new(0, 0.3, 0), 0.6, 2.6, ROPE, M.Fabric)
	cylinder(m, ground + Vector3.new(0, 0.75, 0), 0.4, 1.8, ROPE, M.Fabric)
	return m
end

-- Netted crab pot.
function Props.crabPot(parent: Instance, ground: Vector3, rng: Random): Model
	local m = newModel("CrabPot", parent)
	local frame = CFrame.new(ground + Vector3.new(0, 1, 0)) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
	local net = part(m, Vector3.new(3, 1.8, 2.2), frame, rgb(120, 130, 120), M.Fabric)
	net.Transparency = 0.35
	for _, y in { -0.9, 0.9 } do
		part(m, Vector3.new(3.1, 0.15, 2.3), frame * CFrame.new(0, y, 0), IRON, M.Metal)
	end
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		part(m, Vector3.new(0.15, 1.8, 0.15), frame * CFrame.new(c[1] * 1.5, 0, c[2] * 1.1), IRON, M.Metal)
	end
	part(m, Vector3.new(0.4, 0.4, 0.4), frame * CFrame.new(0.4, 0, 0), rgb(220, 100, 60), M.Plastic)
	return m
end

-- A crab cage the angler can buy: coated-wire box on wooden skids with a funnel
-- entrance at each end, an orange bait box hung inside and a rope bridle on top.
-- `frame` is the centre of its base, the long sides along X. With `float`, a rope
-- runs to a marker float in a "Float" model that rides at CRAB_CAGE_WATERLINE.
-- Every part is decoration: no collision, queries or touches.
Props.CRAB_CAGE_SIZE = Vector3.new(3.2, 1.9, 2.4)
Props.CRAB_CAGE_WATERLINE = 1.45
function Props.crabCage(parent: Instance, frame: CFrame, float: boolean?): Model
	local m = newModel("CrabCage", parent)
	local coat, wire = rgb(30, 58, 50), rgb(48, 96, 80)
	local net, rubber = rgb(226, 214, 176), rgb(28, 28, 30)
	local size = Props.CRAB_CAGE_SIZE
	local hw, hd, top = size.X / 2 - 0.07, size.Z / 2 - 0.07, size.Y
	local floor = 0.3
	local function piece(container: Instance, dimensions: Vector3, offset: CFrame, color: Color3, material): Part
		local p = part(container, dimensions, frame * offset, color, material)
		p.CanCollide, p.CanQuery = false, false
		return p
	end
	local function bar(container: Instance, a: Vector3, b: Vector3, width: number, color: Color3, material): Part
		local p = beam(container, frame * a, frame * b, width, color, nil, material or M.SmoothPlastic)
		p.CanCollide, p.CanQuery = false, false
		p.CastShadow = width > 0.06
		return p
	end
	local V = Vector3.new
	-- An invisible root at `frame` keeps the model's pivot on the cage's base,
	-- even while a held copy is carried around welded to a Tool.
	local root = piece(m, V(0.2, 0.2, 0.2), CFrame.new(), WOOD)
	root.Name = "CageRoot"
	root.Transparency, root.CastShadow = 1, false
	m.PrimaryPart = root

	-- Skids, a slatted floor and two weight bars to sink it
	for _, z in { -(hd - 0.1), hd - 0.1 } do
		piece(m, V(size.X + 0.3, 0.16, 0.3), CFrame.new(0, 0.08, z), WOOD_DARK, M.Wood)
	end
	for index, z in { -0.84, -0.28, 0.28, 0.84 } do
		piece(
			m,
			V(size.X, 0.14, 0.48),
			CFrame.new(0, 0.23, z),
			if index % 2 == 0 then WOOD else WOOD:Lerp(WOOD_DARK, 0.3),
			M.WoodPlanks
		)
	end
	for _, x in { -(hw - 0.3), hw - 0.3 } do
		piece(m, V(0.3, 0.14, size.Z - 0.5), CFrame.new(x, floor + 0.07, 0), IRON, M.Metal)
	end

	-- Corner posts and the top and bottom rims
	for _, x in { -hw, hw } do
		for _, z in { -hd, hd } do
			bar(m, V(x, floor, z), V(x, top, z), 0.14, coat)
		end
	end
	for _, y in { floor + 0.04, top } do
		for _, z in { -hd, hd } do
			bar(m, V(-hw, y, z), V(hw, y, z), 0.12, coat)
		end
		for _, x in { -hw, hw } do
			bar(m, V(x, y, -hd), V(x, y, hd), 0.12, coat)
		end
	end
	-- Wire mesh on the long sides and the top
	for _, z in { -hd, hd } do
		for _, x in { -1, -0.5, 0, 0.5, 1 } do
			bar(m, V(x, floor, z), V(x, top, z), 0.05, wire)
		end
		for _, y in { 0.85, 1.4 } do
			bar(m, V(-hw, y, z), V(hw, y, z), 0.05, wire)
		end
	end
	for _, z in { -0.6, 0, 0.6 } do
		bar(m, V(-hw, top, z), V(hw, top, z), 0.05, wire)
	end
	for _, x in { -1.05, -0.45, 0.45, 1.05 } do
		-- The inner pair are the edges of the bait lid.
		local lid = math.abs(x) < 1
		bar(m, V(x, top, -hd), V(x, top, hd), if lid then 0.08 else 0.05, if lid then coat else wire)
	end
	-- A bungee holds the bait lid shut, hooked over the rim
	bar(m, V(0.1, top + 0.06, 0), V(hw, top + 0.03, 0), 0.07, rubber, M.Rubber)
	local function knob(at: Vector3, diameter: number)
		local p = ball(m, frame * at, diameter, IRON, M.Metal)
		p.CanCollide, p.CanQuery = false, false
	end
	knob(V(hw, top, 0), 0.14)

	-- Funnel entrances: a net ring on each end narrowing to a dark throat inside
	for _, side in { -1, 1 } do
		local x, y = side * hw, 1.11
		for _, z in { -0.66, 0.66 } do
			bar(m, V(x, floor, z), V(x, top, z), 0.05, wire)
		end
		for _, rail in { 0.62, 1.6 } do
			bar(m, V(x, rail, -hd), V(x, rail, hd), 0.05, wire)
		end
		local function ring(angle: number): Vector3
			return V(x, y + math.sin(angle) * 0.4, math.cos(angle) * 0.4)
		end
		for k = 0, 7 do
			bar(m, ring(k * TAU / 8), ring((k + 1) * TAU / 8), 0.08, net, M.Fabric)
		end
		local throatX = side * (hw - 0.55)
		local throat = piece(m, V(0.05, 0.36, 0.36), CFrame.new(throatX, y - 0.06, 0), rgb(18, 30, 26), M.Fabric)
		throat.Shape = Enum.PartType.Cylinder
		throat.Transparency = 0.25
		for k = 0, 3 do
			local angle = k * TAU / 4 + TAU / 8
			local inner = V(throatX, y - 0.06 + math.sin(angle) * 0.17, math.cos(angle) * 0.17)
			bar(m, ring(angle), inner, 0.04, net, M.Fabric)
		end
	end

	-- Bait box hung from the lid on a cord
	piece(m, V(0.5, 0.36, 0.36), CFrame.new(0, 1.3, 0), rgb(236, 124, 42), M.SmoothPlastic)
	piece(m, V(0.52, 0.05, 0.38), CFrame.new(0, 1.26, 0), rgb(150, 66, 22), M.SmoothPlastic)
	piece(m, V(0.54, 0.07, 0.4), CFrame.new(0, 1.5, 0), rgb(214, 104, 32), M.SmoothPlastic)
	bar(m, V(0, 1.52, 0), V(0, top, 0), 0.03, net, M.Fabric)

	-- Rope bridle up to a shackle in the middle of the lid
	local shackle = V(0, top + 0.47, 0)
	for _, x in { -hw * 0.6, hw * 0.6 } do
		bar(m, V(x, top, 0), shackle, 0.07, ROPE, M.Fabric)
	end
	knob(shackle, 0.16)

	if float then
		local buoy = newModel("Float", m)
		local water = Props.CRAB_CAGE_WATERLINE
		local at = V(hw + 0.75, water, hd - 0.3)
		-- Upright at the waterline, so the client can bob it about its own middle.
		buoy.WorldPivot = CFrame.new(frame * at)
		local sag = V(hw * 0.5, water + 0.05, 0.4)
		bar(buoy, shackle, sag, 0.07, ROPE, M.Fabric)
		bar(buoy, sag, at + V(-0.45, 0.1, 0), 0.07, ROPE, M.Fabric)
		local function drum(height: number, diameter: number, y: number, color: Color3, material): Part
			local p = piece(
				buoy,
				V(height, diameter, diameter),
				CFrame.new(at + V(0, y, 0)) * CFrame.Angles(0, 0, math.pi / 2),
				color,
				material
			)
			p.Shape = Enum.PartType.Cylinder
			return p
		end
		drum(1.1, 0.95, 0.15, rgb(240, 112, 38), M.SmoothPlastic)
		drum(0.22, 0.98, 0.4, WHITE, M.SmoothPlastic)
		drum(0.14, 0.6, 0.76, rgb(200, 84, 30), M.SmoothPlastic)
		bar(buoy, at + V(0, 0.7, 0), at + V(0, 2.9, 0), 0.09, WOOD_DARK, M.Wood)
		piece(buoy, V(0.04, 0.5, 0.8), CFrame.new(at + V(0, 2.6, 0.42)), rgb(250, 214, 64), M.Fabric).Name = "Flag"
	end
	return m
end

function Props.barrel(parent: Instance, ground: Vector3, rng: Random): Model
	local m = newModel("Barrel", parent)
	local center = ground + Vector3.new(0, 1.5, 0)
	cylinder(m, center, 3, 2.3, shade(WOOD, rng, 0.1), M.WoodPlanks)
	cylinder(m, center + Vector3.new(0, 0.8, 0), 0.3, 2.45, IRON, M.Metal)
	cylinder(m, center - Vector3.new(0, 0.8, 0), 0.3, 2.45, IRON, M.Metal)
	return m
end

function Props.crates(parent: Instance, ground: Vector3, rng: Random): Model
	local m = newModel("Crates", parent)
	local y = ground.Y
	for i = 1, rng:NextInteger(1, 3) do
		local s = rng:NextNumber(2.4, 3.4)
		local offset = if i == 3
			then Vector3.zero
			else Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
		local at = Vector3.new(ground.X, y + s / 2, ground.Z) + offset
		part(
			m,
			Vector3.new(s, s, s),
			CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
			shade(WOOD, rng, 0.12),
			M.WoodPlanks
		)
		if i == 2 then
			y += s
		end
	end
	return m
end

function Props.bench(parent: Instance, ground: Vector3, facing: number): Model
	local m = newModel("Bench", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	part(m, Vector3.new(5, 0.4, 1.6), base * CFrame.new(0, 1.6, 0), WOOD, M.WoodPlanks)
	part(m, Vector3.new(5, 1.4, 0.3), base * CFrame.new(0, 2.6, -0.8) * CFrame.Angles(-0.2, 0, 0), WOOD, M.WoodPlanks)
	for side = -1, 1, 2 do
		part(m, Vector3.new(0.4, 1.6, 1.4), base * CFrame.new(side * 2.1, 0.8, 0), IRON, M.Metal)
	end
	return m
end

-- Signpost with an arrow board per entry ({text, angle relative to `facing`}).
function Props.signpost(parent: Instance, ground: Vector3, facing: number, arrows: { { any } }): Model
	local m = newModel("Signpost", parent)
	part(m, Vector3.new(0.6, 8, 0.6), CFrame.new(ground + Vector3.new(0, 4, 0)), WOOD_DARK, M.Wood)
	for i, arrow in arrows do
		local board = part(
			m,
			Vector3.new(5, 1.2, 0.3),
			CFrame.new(ground + Vector3.new(0, 7.4 - i * 1.5, 0))
				* CFrame.Angles(0, facing + arrow[2], 0)
				* CFrame.new(2.4, 0, 0),
			WOOD,
			M.WoodPlanks
		)
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 40
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.Garamond
			label.TextScaled = true
			label.TextColor3 = rgb(40, 30, 22)
			label.Text = arrow[1]
			label.Parent = gui
			gui.Parent = board
		end
	end
	return m
end

-- Market stall with a striped canopy and a counter of fish; faces its local +Z.
function Props.stall(parent: Instance, ground: Vector3, facing: number, rng: Random, canopy: Color3): Model
	local m = newModel("Stall", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	part(m, Vector3.new(9, 3, 3), base * CFrame.new(0, 1.5, 1.5), WOOD, M.WoodPlanks)
	part(m, Vector3.new(9.4, 0.3, 3.4), base * CFrame.new(0, 3.1, 1.5), WOOD_DARK, M.Wood)
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		part(m, Vector3.new(0.5, 8, 0.5), base * CFrame.new(c[1] * 4.3, 4, c[2] * 2.5 + 0.5), WOOD_DARK, M.Wood)
	end
	for i = 0, 4 do
		local stripe = if i % 2 == 0 then canopy else WHITE
		part(
			m,
			Vector3.new(2, 0.3, 7),
			base * CFrame.new(-4 + i * 2, 8.2, 0.5) * CFrame.Angles(0.18, 0, 0),
			stripe,
			M.Fabric
		)
	end
	part(m, Vector3.new(8.6, 1.2, 2.4), base * CFrame.new(0, 3.5, 1.5), rgb(200, 220, 230), M.Ice)
	for k = 1, 4 do
		local fish = base * CFrame.new(-3.5 + k * 1.6, 4.2, 1.5) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0)
		part(m, Vector3.new(0.6, 0.4, 1.8), fish, shade(rgb(150, 160, 170), rng, 0.15), M.Foil)
	end
	Props.lantern(m, base * CFrame.new(3.8, 6.6, 3.2))
	Props.crates(m, base:PointToWorldSpace(Vector3.new(5.8, 0, -1)), rng)
	return m
end

function Props.well(parent: Instance, ground: Vector3): Model
	local m = newModel("Well", parent)
	cylinder(m, ground + Vector3.new(0, 1.5, 0), 3, 7, STONE, M.Cobblestone)
	cylinder(m, ground + Vector3.new(0, 2.9, 0), 0.4, 5.6, rgb(40, 70, 80), M.Glass)
	for side = -1, 1, 2 do
		part(m, Vector3.new(0.6, 7, 0.6), CFrame.new(ground + Vector3.new(side * 3, 5, 0)), WOOD_DARK, M.Wood)
	end
	part(m, Vector3.new(6.4, 0.4, 0.4), CFrame.new(ground + Vector3.new(0, 6.2, 0)), WOOD_DARK, M.Wood)
	part(m, Vector3.new(1, 1.4, 1), CFrame.new(ground + Vector3.new(0, 5, 0)), WOOD, M.WoodPlanks)
	for side = -1, 1, 2 do
		part(
			m,
			Vector3.new(8, 0.4, 3.4),
			CFrame.new(ground + Vector3.new(0, 8.6, side * 1.4)) * CFrame.Angles(side * 0.5, 0, 0),
			RED,
			M.RoofShingles
		)
	end
	return m
end

-- Two posts with fish hung out to dry.
function Props.fishRack(parent: Instance, ground: Vector3, facing: number, rng: Random): Model
	local m = newModel("FishRack", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	for side = -1, 1, 2 do
		part(m, Vector3.new(0.5, 6, 0.5), base * CFrame.new(side * 4, 3, 0), WOOD_DARK, M.Wood)
	end
	part(m, Vector3.new(8.6, 0.4, 0.4), base * CFrame.new(0, 5.8, 0), WOOD_DARK, M.Wood)
	for k = 1, 4 do
		part(
			m,
			Vector3.new(0.5, 1.8, 0.3),
			base * CFrame.new(-4 + k * 1.6, 4.6, 0),
			shade(rgb(160, 168, 172), rng, 0.15),
			M.Foil
		)
	end
	return m
end

-- Low wooden fence between two points.
function Props.fence(parent: Instance, a: Vector3, b: Vector3): Model
	local m = newModel("Fence", parent)
	local length = (b - a).Magnitude
	local count = math.max(1, math.floor(length / 4))
	for i = 0, count do
		part(m, Vector3.new(0.4, 2.6, 0.4), CFrame.new(a:Lerp(b, i / count) + Vector3.new(0, 1.3, 0)), WOOD, M.Wood)
	end
	for _, y in { 1, 2.1 } do
		beam(m, a + Vector3.new(0, y, 0), b + Vector3.new(0, y, 0), 0.25, WOOD, nil, M.WoodPlanks)
	end
	return m
end

function Props.flag(parent: Instance, ground: Vector3, color: Color3): Model
	local m = newModel("Flag", parent)
	cylinder(m, ground + Vector3.new(0, 9, 0), 18, 0.5, rgb(70, 66, 62), M.Metal)
	part(m, Vector3.new(0.2, 4, 6), CFrame.new(ground + Vector3.new(0, 15.6, 3.2)), color, M.Fabric)
	ball(m, ground + Vector3.new(0, 18.2, 0), 0.9, rgb(200, 170, 80), M.Metal)
	return m
end

----------------------------------------------------------------------------------------------------
-- Beach

-- Striped beach umbrella on a pole stuck in the sand.
function Props.beachUmbrella(parent: Instance, ground: Vector3, rng: Random, color: Color3): Model
	local m = newModel("BeachUmbrella", parent)
	local lean = CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12))
	local base = CFrame.new(ground) * lean
	local function at(x: number, y: number, z: number): Vector3
		return base:PointToWorldSpace(Vector3.new(x, y, z))
	end
	beam(m, at(0, -1, 0), at(0, 9.4, 0), 0.35, WHITE, nil, M.Metal)
	local apex, inside = at(0, 9.4, 0), at(0, 7, 0)
	for i = 1, 10 do
		local a0, a1 = i / 10 * TAU, (i + 1) / 10 * TAU
		local r0 = at(math.cos(a0) * 5.4, 7.8, math.sin(a0) * 5.4)
		local r1 = at(math.cos(a1) * 5.4, 7.8, math.sin(a1) * 5.4)
		local stripe = if i % 2 == 0 then color else WHITE
		LowPoly.triangle(r0, r1, apex, inside, stripe, m, M.Fabric)
		-- Scalloped valance hanging from the rim
		beam(m, r0 - Vector3.new(0, 0.35, 0), r1 - Vector3.new(0, 0.35, 0), 0.1, stripe, 0.7, M.Fabric)
	end
	ball(m, apex + Vector3.new(0, 0.3, 0), 0.6, WHITE, M.Plastic)
	return m
end

-- Sun lounger with a raised backrest; the foot end points along `facing`.
function Props.sunLounger(parent: Instance, ground: Vector3, facing: number, color: Color3): Model
	local m = newModel("SunLounger", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	part(m, Vector3.new(2.6, 0.3, 4.6), base * CFrame.new(0, 1.2, 1), WHITE, M.Plastic)
	part(m, Vector3.new(2.3, 0.25, 4.4), base * CFrame.new(0, 1.45, 1), color, M.Fabric)
	local back = base * CFrame.new(0, 1.3, -1.3) * CFrame.Angles(0.75, 0, 0) * CFrame.new(0, 0, -1.3)
	part(m, Vector3.new(2.6, 0.3, 2.6), back, WHITE, M.Plastic)
	part(m, Vector3.new(2.3, 0.25, 2.4), back * CFrame.new(0, 0.25, 0), color, M.Fabric)
	part(m, Vector3.new(1.4, 0.45, 0.7), back * CFrame.new(0, 0.5, -0.8), WHITE, M.Fabric)
	for _, x in { -1.1, 1.1 } do
		for _, z in { -1.1, 3 } do
			part(m, Vector3.new(0.25, 1.1, 0.25), base * CFrame.new(x, 0.55, z), WHITE, M.Plastic)
		end
	end
	return m
end

-- Striped towel following the sand's slope, built from adjoining fabric panels.
function Props.towel(parent: Instance, ground: Vector3, facing: number, color: Color3, normal: Vector3?): Model
	local m = newModel("Towel", parent)
	local up = if normal and normal.Magnitude > 0.001 then normal.Unit else Vector3.yAxis
	local right = Vector3.new(math.cos(facing), 0, -math.sin(facing))
	right -= up * right:Dot(up)
	if right.Magnitude < 0.001 then
		right = if math.abs(up.Y) < 0.9 then Vector3.yAxis:Cross(up) else Vector3.zAxis:Cross(up)
	end
	right = right.Unit
	local base = CFrame.fromMatrix(ground, right, up, right:Cross(up))
	local function panel(from: number, to: number, tint: Color3)
		local fabric =
			part(m, Vector3.new(2.8, 0.1, to - from), base * CFrame.new(0, 0.05, (from + to) / 2), tint, M.Fabric)
		fabric.CanCollide = false
		fabric.CanTouch = false
		fabric.CanQuery = false
		fabric.CastShadow = false
	end
	local edge = -2.8
	for _, z in { -2, 0, 2 } do
		panel(edge, z - 0.25, color)
		panel(z - 0.25, z + 0.25, WHITE)
		edge = z + 0.25
	end
	panel(edge, 2.8, color)
	return m
end

-- White lifeguard tower on stilts with a red roof, a ladder at the back and a life ring.
function Props.lifeguardTower(parent: Instance, ground: Vector3, facing: number): Model
	local m = newModel("LifeguardTower", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	local floor = 8
	for _, x in { -2.6, 2.6 } do
		for _, z in { -2.6, 2.6 } do
			beam(
				m,
				base * Vector3.new(x * 1.25, -1, z * 1.25),
				base * Vector3.new(x, floor, z),
				0.6,
				WHITE,
				nil,
				M.Wood
			)
		end
	end
	for _, z in { -3.05, 3.05 } do
		beam(m, base * Vector3.new(-3.05, 2, z), base * Vector3.new(3.05, 2, z), 0.3, WHITE, nil, M.Wood)
	end
	part(m, Vector3.new(7, 0.5, 7), base * CFrame.new(0, floor, 0), WOOD, M.WoodPlanks)
	-- Cabin: low walls round three sides, open toward the sea
	part(m, Vector3.new(6.4, 3, 0.3), base * CFrame.new(0, floor + 1.7, -3.1), WHITE, M.WoodPlanks)
	for side = -1, 1, 2 do
		part(m, Vector3.new(0.3, 3, 6.4), base * CFrame.new(side * 3.1, floor + 1.7, 0), WHITE, M.WoodPlanks)
		part(m, Vector3.new(0.3, 3.6, 0.3), base * CFrame.new(side * 3.1, floor + 5, 3.1), WHITE, M.Wood)
	end
	part(m, Vector3.new(6.4, 1.2, 0.3), base * CFrame.new(0, floor + 0.8, 3.1), RED, M.WoodPlanks)
	part(m, Vector3.new(8, 0.4, 8), base * CFrame.new(0, floor + 7, 0) * CFrame.Angles(0.12, 0, 0), RED, M.WoodPlanks)
	-- Ladder up the back
	local ladderTop, ladderFoot = base * Vector3.new(0, floor, -3.6), base * Vector3.new(0, 0, -7)
	for side = -1, 1, 2 do
		local offset = base:VectorToWorldSpace(Vector3.new(side * 0.9, 0, 0))
		beam(m, ladderFoot + offset, ladderTop + offset, 0.25, WOOD, nil, M.Wood)
	end
	for k = 1, 7 do
		beam(
			m,
			ladderFoot:Lerp(ladderTop, k / 8) + base:VectorToWorldSpace(Vector3.new(-0.9, 0, 0)),
			ladderFoot:Lerp(ladderTop, k / 8) + base:VectorToWorldSpace(Vector3.new(0.9, 0, 0)),
			0.2,
			WOOD,
			nil,
			M.Wood
		)
	end
	Props.lifeRing(m, base * CFrame.new(0, floor + 1.7, 3.3))
	-- Red flag on a pole beside it
	cylinder(m, base * Vector3.new(4.6, 7, -1), 14, 0.3, WHITE, M.Metal)
	part(
		m,
		Vector3.new(0.15, 2, 3),
		CFrame.new(base * Vector3.new(4.6, 13, -1)) * CFrame.Angles(0, facing, 0) * CFrame.new(0, 0, 1.5),
		RED,
		M.Fabric
	)
	return m
end

-- Striped changing cabana with a pointed roof; the doorway faces along `facing`.
function Props.cabana(parent: Instance, ground: Vector3, facing: number, color: Color3): Model
	local m = newModel("Cabana", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	local w, h = 5, 7
	part(m, Vector3.new(w + 1, 0.4, w + 1), base * CFrame.new(0, 0.2, 0), WOOD, M.WoodPlanks)
	for i = 0, 4 do
		local x = -w / 2 + (i + 0.5) * w / 5
		local stripe = if i % 2 == 0 then color else WHITE
		part(m, Vector3.new(w / 5, h, 0.2), base * CFrame.new(x, h / 2 + 0.4, -w / 2), stripe, M.Fabric)
		part(m, Vector3.new(0.2, h, w / 5), base * CFrame.new(w / 2, h / 2 + 0.4, x), stripe, M.Fabric)
		part(m, Vector3.new(0.2, h, w / 5), base * CFrame.new(-w / 2, h / 2 + 0.4, x), stripe, M.Fabric)
	end
	-- Curtains drawn back either side of the door
	for side = -1, 1, 2 do
		part(m, Vector3.new(1.4, h, 0.25), base * CFrame.new(side * 1.8, h / 2 + 0.4, w / 2), color, M.Fabric)
	end
	part(m, Vector3.new(w + 0.4, 0.6, w + 0.4), base * CFrame.new(0, h + 0.7, 0), WHITE, M.Wood)
	local roof = {
		base * Vector3.new(-w / 2 - 0.6, h + 1, -w / 2 - 0.6),
		base * Vector3.new(w / 2 + 0.6, h + 1, -w / 2 - 0.6),
		base * Vector3.new(w / 2 + 0.6, h + 1, w / 2 + 0.6),
		base * Vector3.new(-w / 2 - 0.6, h + 1, w / 2 + 0.6),
	}
	LowPoly.pyramid(roof, base * Vector3.new(0, h + 4.5, 0), color, m, M.Fabric)
	ball(m, base * Vector3.new(0, h + 4.8, 0), 0.6, WHITE, M.Wood)
	return m
end

-- Bleached driftwood log half sunk in the sand, with a stub of branch.
function Props.driftwood(parent: Instance, ground: Vector3, rng: Random): Model
	local m = newModel("Driftwood", parent)
	local a = rng:NextNumber(0, TAU)
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local length = rng:NextNumber(6, 11)
	local color = shade(rgb(196, 182, 160), rng, 0.06)
	local p0, p1 =
		ground - dir * length / 2 + Vector3.new(0, 0.3, 0), ground + dir * length / 2 + Vector3.new(0, 0.5, 0)
	beam(m, p0, p1, rng:NextNumber(0.9, 1.4), color, nil, M.Wood)
	local fork = p0:Lerp(p1, 0.7)
	beam(m, fork, fork + (dir + Vector3.new(-dir.Z, 0.5, dir.X)).Unit * 3, 0.45, color, nil, M.Wood)
	return m
end

-- A scatter of shells and pebbles round `ground`.
function Props.shells(parent: Instance, ground: Vector3, rng: Random): Model
	local m = newModel("Shells", parent)
	local colors = { rgb(246, 228, 214), rgb(236, 190, 170), rgb(214, 196, 168), rgb(250, 244, 236) }
	for _ = 1, rng:NextInteger(4, 8) do
		local p = ground + Vector3.new(rng:NextNumber(-4, 4), 0.1, rng:NextNumber(-4, 4))
		local s = rng:NextNumber(0.35, 0.7)
		local shell = part(
			m,
			Vector3.new(s, s * 0.4, s * 1.2),
			CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
			shade(Props.pick(rng, colors), rng, 0.05),
			M.Marble
		)
		shell.CanCollide = false
	end
	return m
end

-- Little sandcastle with four towers, a keep and a flag, ringed by a moat.
function Props.sandcastle(parent: Instance, ground: Vector3, color: Color3): Model
	local m = newModel("Sandcastle", parent)
	cylinder(m, ground + Vector3.new(0, 0.05, 0), 0.1, 7.5, rgb(120, 140, 130), M.SmoothPlastic).Transparency = 0.3
	part(m, Vector3.new(4, 1.2, 4), CFrame.new(ground + Vector3.new(0, 0.6, 0)), color, M.Sand)
	for _, x in { -1.8, 1.8 } do
		for _, z in { -1.8, 1.8 } do
			cylinder(m, ground + Vector3.new(x, 1, z), 2, 1.2, color, M.Sand)
			LowPoly.pyramid({
				ground + Vector3.new(x - 0.6, 2, z - 0.6),
				ground + Vector3.new(x + 0.6, 2, z - 0.6),
				ground + Vector3.new(x + 0.6, 2, z + 0.6),
				ground + Vector3.new(x - 0.6, 2, z + 0.6),
			}, ground + Vector3.new(x, 2.8, z), color, m, M.Sand)
		end
	end
	part(m, Vector3.new(1.8, 2.2, 1.8), CFrame.new(ground + Vector3.new(0, 2.3, 0)), color, M.Sand)
	cylinder(m, ground + Vector3.new(0, 4, 0), 1.6, 0.1, WOOD, M.Wood)
	part(m, Vector3.new(0.05, 0.5, 0.8), CFrame.new(ground + Vector3.new(0, 4.5, 0.4)), RED, M.Fabric)
	return m
end

-- Beach volleyball net between two posts, with a ball lying nearby.
function Props.volleyballNet(parent: Instance, ground: Vector3, facing: number): Model
	local m = newModel("VolleyballNet", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	for side = -1, 1, 2 do
		cylinder(m, base * Vector3.new(side * 9, 4, 0), 9, 0.4, WHITE, M.Metal)
	end
	local net = part(m, Vector3.new(18, 3, 0.1), base * CFrame.new(0, 6.2, 0), rgb(40, 40, 44), M.Fabric)
	net.Transparency = 0.45
	part(m, Vector3.new(18, 0.4, 0.15), base * CFrame.new(0, 7.8, 0), WHITE, M.Fabric)
	-- Court boundary lines meet at the corners without overlapping their top faces.
	for _, z in { -8, 8 } do
		part(m, Vector3.new(18.3, 0.08, 0.3), base * CFrame.new(0, 0.04, z), WHITE, M.Fabric).CanCollide = false
	end
	for _, x in { -9, 9 } do
		part(m, Vector3.new(0.3, 0.08, 15.7), base * CFrame.new(x, 0.04, 0), WHITE, M.Fabric).CanCollide = false
	end
	Props.beachBall(m, base * Vector3.new(3, 0, 4))
	return m
end

-- Beach ball in segments of bright colour.
function Props.beachBall(parent: Instance, ground: Vector3): Model
	local m = newModel("BeachBall", parent)
	ball(m, ground + Vector3.new(0, 0.9, 0), 1.8, WHITE, M.SmoothPlastic)
	local colors = { RED, rgb(240, 200, 50), rgb(40, 110, 190) }
	for i, color in colors do
		local band = part(
			m,
			Vector3.new(0.45, 1.85, 1.85),
			CFrame.new(ground + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, i / #colors * math.pi, 0),
			color,
			M.SmoothPlastic
		)
		band.Shape = Enum.PartType.Cylinder
	end
	return m
end

-- Clump of washed-up seaweed along the tide line.
function Props.seaweed(parent: Instance, ground: Vector3, rng: Random): Model
	local m = newModel("Seaweed", parent)
	for _ = 1, rng:NextInteger(3, 6) do
		local p = ground + Vector3.new(rng:NextNumber(-2.5, 2.5), 0.08, rng:NextNumber(-2.5, 2.5))
		local strand = part(
			m,
			Vector3.new(rng:NextNumber(0.5, 1.1), 0.15, rng:NextNumber(2, 4)),
			CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
			shade(rgb(64, 84, 46), rng, 0.15),
			M.Grass
		)
		strand.CanCollide = false
	end
	return m
end

----------------------------------------------------------------------------------------------------
-- Volcanic effects

local function anchor(parent: Instance, position: Vector3): Part
	local p = part(parent, Vector3.new(4, 1, 4), CFrame.new(position), LAVA)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	return p
end

local function smoke(parent: BasePart, size: number, rise: number)
	local s = Instance.new("Smoke")
	s.Color = rgb(70, 64, 62)
	s.Opacity = 0.22
	s.Size = size
	s.RiseVelocity = rise
	s.Parent = parent
end

function Props.lavaPool(parent: Instance, ground: Vector3, rng: Random, diameter: number?): Model
	local m = newModel("LavaPool", parent)
	local d = diameter or rng:NextNumber(6, 14)
	cylinder(m, ground + Vector3.new(0, 0.1, 0), 0.3, d + 3, rgb(60, 40, 36), M.CrackedLava)
	local pool = cylinder(m, ground + Vector3.new(0, 0.2, 0), 0.4, d, LAVA, M.Neon)
	light(pool, LAVA, d * 2.5, 2)
	return m
end

-- Glowing ribbon following a list of surface points.
function Props.lavaFlow(parent: Instance, points: { Vector3 })
	local m = newModel("LavaFlow", parent)
	for i = 1, #points - 1 do
		local width = 7 - 4 * i / #points
		local lift = Vector3.new(0, 0.6, 0)
		local p = beam(m, points[i] + lift, points[i + 1] + lift, width, LAVA, 0.5, M.Neon)
		if i % 4 == 1 then
			light(p, LAVA, 40, 1.5)
		end
	end
end

function Props.vent(parent: Instance, ground: Vector3)
	smoke(anchor(parent, ground + Vector3.new(0, 2, 0)), 14, 10)
end

-- Lava lake in a volcano's crater with rising smoke and embers.
function Props.crater(parent: Instance, center: Vector3, radius: number, rimY: number)
	local m = newModel("Crater", parent)
	local lake = cylinder(m, center + Vector3.new(0, 1, 0), 0.6, radius * 2, LAVA, M.Neon)
	light(lake, LAVA, 60, 5)

	local embers = Instance.new("ParticleEmitter")
	embers.Color = ColorSequence.new(rgb(255, 180, 80), rgb(255, 70, 20))
	embers.LightEmission = 1
	embers.Size = NumberSequence.new(0.8, 0)
	embers.Lifetime = NumberRange.new(2, 5)
	embers.Rate = 25
	embers.Speed = NumberRange.new(15, 35)
	embers.SpreadAngle = Vector2.new(25, 25)
	embers.Acceleration = Vector3.new(0, -6, 0)
	embers.Parent = anchor(m, center + Vector3.new(0, 2, 0))

	smoke(anchor(m, Vector3.new(center.X, rimY + 10, center.Z)), 60, 18)
end

return Props

end
dependencies.Props = loadProps()
local function loadImportedModel()
	-- Native geometry shared by the supplied shop fixtures.
local ImportedModel = {}
local SKIN = 0.01

local function direction(v: Vector3): Vector3
	return Vector3.new(v.X, v.Z, -v.Y)
end

function ImportedModel.build(parent: Instance, frame: CFrame, geometry, options): Model
	local Geometry = geometry
	local scale = options.width / (Geometry.boundsMax.X - Geometry.boundsMin.X)
	local origin = options.origin
		or Vector3.new(
			(Geometry.boundsMin.X + Geometry.boundsMax.X) / 2,
			(Geometry.boundsMin.Y + Geometry.boundsMax.Y) / 2,
			Geometry.boundsMin.Z
		)
	local function point(v: Vector3): Vector3
		return direction(v - origin) * scale
	end
	local freezer = Instance.new("Model")
	freezer.Name = options.name
	freezer:SetAttribute("ModelVersion", options.version or 1)
	freezer:SetAttribute("SourceModel", options.sourceName)
	freezer:SetAttribute("SourceHash", Geometry.sourceHash)
	freezer:SetAttribute("SourceObjectCount", Geometry.sourceObjectCount or #Geometry.objects)
	freezer.Parent = parent

	local function part(kind: string, group: Model, size: Vector3, cf: CFrame, color: Color3): BasePart
		local finish = options.appearance and options.appearance[group.Name]
		local item = Instance.new(kind) :: BasePart
		item.Name = if kind == "Part" then "Solid" else "Surface"
		item.Size = size
		item.CFrame = frame * cf
		item.Color = if finish then finish.color else color
		item.Material = if finish then finish.material else Enum.Material.SmoothPlastic
		item.Transparency = if finish then finish.transparency or 0 else 0
		item.Reflectance = if finish then finish.reflectance or 0 else 0
		item.Anchored = true
		item.CanTouch = false
		item.CanCollide = options.canCollide ~= false
		item.TopSurface = Enum.SurfaceType.Smooth
		item.BottomSurface = Enum.SurfaceType.Smooth
		item.Parent = group
		return item
	end

	local vertices = {}
	for i, vertex in Geometry.vertices do
		vertices[i] = point(vertex)
	end
	for _, source in Geometry.objects do
		local group = Instance.new("Model")
		group.Name = source.name
		group:SetAttribute("SourceFaceCount", #source.faces)
		group:SetAttribute("SourceObject", source.sourceObject or source.name)
		-- Keep the supplied palette as metadata while allowing authored finishes.
		group:SetAttribute("SourceColor", source.color)
		group.Parent = freezer
		if source.box then
			local box = source.box
			local right = direction(box.right).Unit
			local back = right:Cross(direction(box.up)).Unit
			local up = back:Cross(right).Unit
			part("Part", group, box.size * scale, CFrame.fromMatrix(point(box.center), right, up, back), source.color)
			continue
		end
		local handled = {}
		for _, rectangle in source.rectangles or {} do
			local right, sourceUp = direction(rectangle.right).Unit, direction(rectangle.up).Unit
			local back = right:Cross(sourceUp).Unit
			local up = back:Cross(right).Unit
			local patch = part(
				"Part",
				group,
				Vector3.new(rectangle.size.X * scale, rectangle.size.Y * scale, SKIN),
				CFrame.fromMatrix(point(rectangle.center) - back * (SKIN / 2), right, up, back),
				source.color
			)
			patch.Name = "SurfacePatch"
			for _, faceIndex in rectangle.faces do
				handled[faceIndex] = true
			end
		end
		for faceIndex, face in source.faces do
			if handled[faceIndex] then
				continue
			end
			local a, b, c = vertices[face[1]], vertices[face[2]], vertices[face[3]]
			-- Source winding points out of the solid, including the recessed cavities.
			local cross = (b - a):Cross(c - a)
			if cross.Magnitude < 1e-12 then
				continue
			end
			local normal = cross.Unit
			local ab, ac, bc = b - a, c - a, c - b
			local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
			if abd > acd and abd > bcd then
				c, a = a, c
			elseif acd > bcd and acd > abd then
				a, b = b, a
			end
			ab, ac, bc = b - a, c - a, c - b
			local right = ac:Cross(ab).Unit
			local up, back = bc:Cross(right).Unit, bc.Unit
			local height = math.abs(ab:Dot(up))
			local shift = -normal * (SKIN / 2)
			local first, second = math.abs(ab:Dot(back)), math.abs(ac:Dot(back))
			-- Right triangles need one wedge. Skip the zero-area half instead of
			-- letting Roblox clamp it into a visible sliver.
			if first > 0.000001 then
				part(
					"WedgePart",
					group,
					Vector3.new(SKIN, math.max(height, 0.001), math.max(first, 0.001)),
					CFrame.fromMatrix((a + b) / 2 + shift, right, up, back),
					source.color
				)
			end
			if second > 0.000001 then
				part(
					"WedgePart",
					group,
					Vector3.new(SKIN, math.max(height, 0.001), math.max(second, 0.001)),
					CFrame.fromMatrix((a + c) / 2 + shift, -right, up, -back),
					source.color
				)
			end
		end
	end
	return freezer
end

return ImportedModel

end
dependencies.ImportedModel = loadImportedModel()
local function loadShopDeskGeometry()
	-- Generated by scripts/import-tinkercad.cjs from Ingenious Lappi.zip.
-- SHA-256 (OBJ + MTL): c2caa342780f91ecc0b3af1eb28856d330b0b1fdb9cc7245dbc33d1f51df6669
return {
	sourceHash = "c2caa342780f91ecc0b3af1eb28856d330b0b1fdb9cc7245dbc33d1f51df6669",
	sourceObjectCount = 6,
	degenerateFaceCount = 0,
	boundsMin = Vector3.new(-91, -4, 0),
	boundsMax = Vector3.new(69, 61, 64),
	vertices = {
		Vector3.new(69, 1, 60),
		Vector3.new(69, 1, 0),
		Vector3.new(69, 61, 60),
		Vector3.new(69, 61, 0),
		Vector3.new(-91, 61, 60),
		Vector3.new(-91, 61, 0),
		Vector3.new(-91, 1, 60),
		Vector3.new(-91, 1, 0),
		Vector3.new(69, -4, 64),
		Vector3.new(69, -4, 60),
		Vector3.new(69, 61, 64),
		Vector3.new(69, 61, 60),
		Vector3.new(-91, 61, 64),
		Vector3.new(-91, 61, 60),
		Vector3.new(-91, -4, 64),
		Vector3.new(-91, -4, 60),
		Vector3.new(-16, -1, 55),
		Vector3.new(-16, -1, 5),
		Vector3.new(-16, 1, 55),
		Vector3.new(-16, 1, 5),
		Vector3.new(-86, 1, 55),
		Vector3.new(-86, 1, 5),
		Vector3.new(-86, -1, 55),
		Vector3.new(-86, -1, 5),
		Vector3.new(64, -1, 55),
		Vector3.new(64, -1, 5),
		Vector3.new(64, 1, 55),
		Vector3.new(64, 1, 5),
		Vector3.new(-6, 1, 55),
		Vector3.new(-6, 1, 5),
		Vector3.new(-6, -1, 55),
		Vector3.new(-6, -1, 5),
		Vector3.new(3, -4, 45),
		Vector3.new(3, -4, 20),
		Vector3.new(3, -2, 45),
		Vector3.new(3, -2, 20),
		Vector3.new(-1, -2, 45),
		Vector3.new(-1, -2, 20),
		Vector3.new(-1, -4, 45),
		Vector3.new(-1, -4, 20),
		Vector3.new(-21, -4, 45),
		Vector3.new(-21, -4, 20),
		Vector3.new(-21, -2, 45),
		Vector3.new(-21, -2, 20),
		Vector3.new(-25, -2, 45),
		Vector3.new(-25, -2, 20),
		Vector3.new(-25, -4, 45),
		Vector3.new(-25, -4, 20),
	},
	objects = {
		{
			name = "obj_0",
			sourceObject = "obj_0",
			color = Color3.new(0.9137254901960784, 0.11372549019607843, 0.17647058823529413),
			box = {
				center = Vector3.new(-11, 31, 30),
				size = Vector3.new(60, 60, 160),
				right = Vector3.new(0, 0, -1),
				up = Vector3.new(0, 1, 0),
			},
			faces = {
				{ 1, 2, 3 },
				{ 2, 4, 3 },
				{ 5, 6, 7 },
				{ 6, 8, 7 },
				{ 5, 7, 3 },
				{ 7, 1, 3 },
				{ 8, 6, 2 },
				{ 6, 4, 2 },
				{ 7, 8, 1 },
				{ 8, 2, 1 },
				{ 3, 4, 5 },
				{ 4, 6, 5 },
			},
		},
		{
			name = "obj_1",
			sourceObject = "obj_1",
			color = Color3.new(0.9137254901960784, 0.11372549019607843, 0.17647058823529413),
			box = {
				center = Vector3.new(-11, 28.5, 62),
				size = Vector3.new(4, 65, 160),
				right = Vector3.new(0, 0, -1),
				up = Vector3.new(0, 1, 0),
			},
			faces = {
				{ 9, 10, 11 },
				{ 10, 12, 11 },
				{ 13, 14, 15 },
				{ 14, 16, 15 },
				{ 13, 15, 11 },
				{ 15, 9, 11 },
				{ 16, 14, 10 },
				{ 14, 12, 10 },
				{ 15, 16, 9 },
				{ 16, 10, 9 },
				{ 11, 12, 13 },
				{ 12, 14, 13 },
			},
		},
		{
			name = "obj_2",
			sourceObject = "obj_2",
			color = Color3.new(0.9137254901960784, 0.11372549019607843, 0.17647058823529413),
			box = {
				center = Vector3.new(-51, 0, 30),
				size = Vector3.new(50, 2, 70),
				right = Vector3.new(0, 0, -1),
				up = Vector3.new(0, 1, 0),
			},
			faces = {
				{ 17, 18, 19 },
				{ 18, 20, 19 },
				{ 21, 22, 23 },
				{ 22, 24, 23 },
				{ 21, 23, 19 },
				{ 23, 17, 19 },
				{ 24, 22, 18 },
				{ 22, 20, 18 },
				{ 23, 24, 17 },
				{ 24, 18, 17 },
				{ 19, 20, 21 },
				{ 20, 22, 21 },
			},
		},
		{
			name = "obj_3",
			sourceObject = "obj_3",
			color = Color3.new(0.9137254901960784, 0.11372549019607843, 0.17647058823529413),
			box = {
				center = Vector3.new(29, 0, 30),
				size = Vector3.new(50, 2, 70),
				right = Vector3.new(0, 0, -1),
				up = Vector3.new(0, 1, 0),
			},
			faces = {
				{ 25, 26, 27 },
				{ 26, 28, 27 },
				{ 29, 30, 31 },
				{ 30, 32, 31 },
				{ 29, 31, 27 },
				{ 31, 25, 27 },
				{ 32, 30, 26 },
				{ 30, 28, 26 },
				{ 31, 32, 25 },
				{ 32, 26, 25 },
				{ 27, 28, 29 },
				{ 28, 30, 29 },
			},
		},
		{
			name = "obj_4",
			sourceObject = "obj_4",
			color = Color3.new(0.9137254901960784, 0.11372549019607843, 0.17647058823529413),
			box = {
				center = Vector3.new(1, -3, 32.5),
				size = Vector3.new(25, 2, 4),
				right = Vector3.new(0, 0, -1),
				up = Vector3.new(0, 1, 0),
			},
			faces = {
				{ 33, 34, 35 },
				{ 34, 36, 35 },
				{ 37, 38, 39 },
				{ 38, 40, 39 },
				{ 37, 39, 35 },
				{ 39, 33, 35 },
				{ 40, 38, 34 },
				{ 38, 36, 34 },
				{ 39, 40, 33 },
				{ 40, 34, 33 },
				{ 35, 36, 37 },
				{ 36, 38, 37 },
			},
		},
		{
			name = "obj_5",
			sourceObject = "obj_5",
			color = Color3.new(0.9137254901960784, 0.11372549019607843, 0.17647058823529413),
			box = {
				center = Vector3.new(-23, -3, 32.5),
				size = Vector3.new(25, 2, 4),
				right = Vector3.new(0, 0, -1),
				up = Vector3.new(0, 1, 0),
			},
			faces = {
				{ 41, 42, 43 },
				{ 42, 44, 43 },
				{ 45, 46, 47 },
				{ 46, 48, 47 },
				{ 45, 47, 43 },
				{ 47, 41, 43 },
				{ 48, 46, 42 },
				{ 46, 44, 42 },
				{ 47, 48, 41 },
				{ 48, 42, 41 },
				{ 43, 44, 45 },
				{ 44, 46, 45 },
			},
		},
	},
}

end
dependencies.ShopDeskGeometry = loadShopDeskGeometry()
local function loadCashRegisterGeometry()
	-- Generated by scripts/import-tinkercad.cjs from Cash Register.zip.
-- SHA-256 (OBJ + MTL): 62447cce4b02cb3775be24b2395bb9aa983b0c567f365586de43a9d603ff48e5
return {
	sourceHash = "62447cce4b02cb3775be24b2395bb9aa983b0c567f365586de43a9d603ff48e5",
	sourceObjectCount = 1,
	degenerateFaceCount = 32,
	boundsMin = Vector3.new(-59.777, -53.002, 0),
	boundsMax = Vector3.new(18, 24.599, 82.789),
	vertices = {
		Vector3.new(-59.701, 24.146, 16.205),
		Vector3.new(-59.701, 24.146, 0),
		Vector3.new(-39.725, 21.255, 64.835),
		Vector3.new(-43.914, 23.235, 61.414),
		Vector3.new(-43.914, 23.235, 82.789),
		Vector3.new(-39.725, 22.211, 64.835),
		Vector3.new(-59.777, 19.643, 0.737),
		Vector3.new(-59.777, -16.226, 0.737),
		Vector3.new(-59.777, -16.226, 38.3199),
		Vector3.new(-59.777, 19.643, 47.3914),
		Vector3.new(-39.725, 21.255, 79.785),
		Vector3.new(-59.701, 19.643, 0.737),
		Vector3.new(-59.701, 19.643, 16.205),
		Vector3.new(-39.725, 22.211, 79.785),
		Vector3.new(-39.725, 22.211, 79.782),
		Vector3.new(-21.4777, 21.255, 61.667),
		Vector3.new(-21.4777, 21.255, 61.414),
		Vector3.new(-21.456, 21.118, 61.667),
		Vector3.new(-39.725, 22.211, 64.837),
		Vector3.new(-59.727, -16.299, 25.919),
		Vector3.new(-59.727, -16.299, 16.205),
		Vector3.new(-59.727, -52.268, 16.205),
		Vector3.new(-21.079, 20.377, 61.667),
		Vector3.new(-19.822, -53.002, 7.65),
		Vector3.new(-19.933, -53.002, 8.35),
		Vector3.new(-20.254, -53.002, 8.98),
		Vector3.new(-59.701, -52.348, 0),
		Vector3.new(-59.701, -52.348, 16.205),
		Vector3.new(-20.254, -53.002, 6.32),
		Vector3.new(-19.933, -53.002, 6.951),
		Vector3.new(-59.701, -52.268, 16.205),
		Vector3.new(-59.701, -16.299, 16.205),
		Vector3.new(-59.701, -16.226, 16.205),
		Vector3.new(-59.701, -16.226, 0.737),
		Vector3.new(-20.49, 19.789, 61.667),
		Vector3.new(-22.085, -53.002, 5.388),
		Vector3.new(-24.348, -52.348, 7.65),
		Vector3.new(-21.386, -53.002, 5.498),
		Vector3.new(-20.755, -53.002, 5.82),
		Vector3.new(-19.735, -39.384, 22.302),
		Vector3.new(-16.776, 20.377, 16.205),
		Vector3.new(1.999, 21.255, 79.785),
		Vector3.new(1.999, 21.255, 64.835),
		Vector3.new(6.363, 21.255, 61.414),
		Vector3.new(-20.755, -53.002, 9.481),
		Vector3.new(-21.386, -53.002, 9.802),
		Vector3.new(-22.085, -53.002, 9.913),
		Vector3.new(-22.784, -53.002, 9.802),
		Vector3.new(-23.415, -53.002, 9.481),
		Vector3.new(-23.916, -53.002, 8.98),
		Vector3.new(-24.237, -53.002, 8.35),
		Vector3.new(-24.348, -53.002, 7.65),
		Vector3.new(-24.237, -53.002, 6.951),
		Vector3.new(-23.916, -53.002, 6.32),
		Vector3.new(-23.415, -53.002, 5.82),
		Vector3.new(-22.784, -53.002, 5.498),
		Vector3.new(-16.3772, 21.255, 61.667),
		Vector3.new(6.363, 23.235, 82.789),
		Vector3.new(6.363, 23.235, 61.414),
		Vector3.new(-16.3772, 21.255, 61.414),
		Vector3.new(-16.6396, 23.235, 61.667),
		Vector3.new(6.363, 21.255, 82.789),
		Vector3.new(18, 24.146, 0),
		Vector3.new(-18.927, 24.599, 0),
		Vector3.new(-16.6396, 23.235, 61.414),
		Vector3.new(18, -52.348, 16.205),
		Vector3.new(-16.268, 21.94, 16.205),
		Vector3.new(17.932, -16.299, 16.205),
		Vector3.new(17.932, -52.268, 16.205),
		Vector3.new(17.932, -52.348, 16.205),
		Vector3.new(-17.4728, 24.146, 0),
		Vector3.new(-16.268, 21.94, 61.414),
		Vector3.new(-20.3822, 24.146, 0),
		Vector3.new(17.932, -16.299, 25.919),
		Vector3.new(-16.384, 22.6679, 61.414),
		Vector3.new(-16.3112, 22.211, 61.414),
		Vector3.new(-19.749, 24.469, 0),
		Vector3.new(-18.106, 24.469, 0),
		Vector3.new(17.924, 19.281, 16.205),
		Vector3.new(17.924, -16.226, 16.205),
		Vector3.new(-20.2038, 19.643, 47.3914),
		Vector3.new(17.924, -16.226, 38.3199),
		Vector3.new(-16.399, 22.762, 61.414),
		Vector3.new(-19.822, 19.4482, 47.3421),
		Vector3.new(-19.822, -52.348, 16.205),
		Vector3.new(-19.822, -52.348, 7.65),
		Vector3.new(0.141, -28.699, 24.898),
		Vector3.new(-26.555, -25.934, 25.749),
		Vector3.new(-26.335, -18.663, 27.59),
		Vector3.new(7.8492, -25.1648, 25.75),
		Vector3.new(7.8535, -25.1644, 25.75),
		Vector3.new(7.9136, -25.1589, 25.7511),
		Vector3.new(7.9698, -25.1407, 25.7554),
		Vector3.new(-28.949, -28.965, 24.994),
		Vector3.new(8.189, -17.896, 27.59),
		Vector3.new(4.227, -13.0602, 28.837),
		Vector3.new(6.2621, -13.0154, 28.837),
		Vector3.new(12.836, -6.6344, 28.837),
		Vector3.new(6.2571, -6.5539, 28.837),
		Vector3.new(4.3877, -6.5309, 28.837),
		Vector3.new(4.3876, -6.5309, 28.837),
		Vector3.new(0, -6.462, 28.837),
		Vector3.new(12.836, -6.462, 28.837),
		Vector3.new(12.5525, -9.01, 28.837),
		Vector3.new(12.836, -8.8295, 28.837),
		Vector3.new(4.3354, -8.6589, 28.837),
		Vector3.new(4.3354, -8.6556, 28.837),
		Vector3.new(4.362, -7.5767, 28.837),
		Vector3.new(-1.9539, -13.1997, 28.837),
		Vector3.new(-1.1957, -13.1828, 28.837),
		Vector3.new(-2.0695, -13.2018, 28.837),
		Vector3.new(-1.1957, -13.1825, 28.837),
		Vector3.new(-16.384, -38.7243, 19.8627),
		Vector3.new(-17.4735, -38.7119, 19.8661),
		Vector3.new(-26.1658, -28.3313, 22.6695),
		Vector3.new(-17.3803, -35.6715, 20.6871),
		Vector3.new(-1.1952, -13.1642, 28.837),
		Vector3.new(-26.6839, -28.3254, 22.6711),
		Vector3.new(-3.8374, -8.8371, 28.837),
		Vector3.new(-17.4735, -38.7119, 19.8661),
		Vector3.new(-4.1245, -9.0205, 28.837),
		Vector3.new(-26.5908, -25.2851, 23.4922),
		Vector3.new(-4.1576, -9.0416, 28.837),
		Vector3.new(-4.1587, -9.0212, 28.837),
		Vector3.new(-28.9855, -28.2991, 22.6782),
		Vector3.new(-4.1683, -8.845, 28.837),
		Vector3.new(-29.1224, -32.768, 21.4713),
		Vector3.new(-3.873, -8.8378, 28.837),
		Vector3.new(-26.4188, -19.6726, 25.0079),
		Vector3.new(-26.3687, -18.047, 25.4469),
		Vector3.new(-26.369, -18.047, 25.4469),
		Vector3.new(-29.0109, -18.0168, 25.4551),
		Vector3.new(-16.399, 22.762, 16.205),
		Vector3.new(-29.169, -36.235, 23.153),
		Vector3.new(-29.1521, -33.7364, 21.2098),
		Vector3.new(-29.2073, -35.5367, 20.7236),
		Vector3.new(-26.2493, -35.5702, 20.7145),
		Vector3.new(-24.348, -35.5919, 20.7086),
		Vector3.new(-4.1684, -8.845, 28.837),
		Vector3.new(-25.171, -39.885, 22.206),
		Vector3.new(-1.0878, -8.7789, 28.837),
		Vector3.new(-29.3174, -39.1295, 19.7533),
		Vector3.new(-32.768, -39.0904, 19.7638),
		Vector3.new(1.869, 21.792, 64.837),
		Vector3.new(1.869, 21.792, 79.782),
		Vector3.new(-29.3173, -39.1295, 19.7533),
		Vector3.new(1.869, 22.211, 79.782),
		Vector3.new(-1.0876, -8.7705, 28.837),
		Vector3.new(1.869, 22.211, 64.837),
		Vector3.new(-28.2494, -39.1416, 19.75),
		Vector3.new(-25.391, -47.157, 20.365),
		Vector3.new(-25.4319, -46.4155, 17.7855),
		Vector3.new(-25.4149, -45.8622, 17.935),
		Vector3.new(1.999, 22.211, 79.785),
		Vector3.new(-17.3803, -35.6715, 20.6871),
		Vector3.new(-19.7732, -38.6856, 19.8731),
		Vector3.new(-25.2098, -39.1763, 19.7406),
		Vector3.new(-25.2101, -39.1763, 19.7406),
		Vector3.new(-25.2674, -41.0471, 19.2354),
		Vector3.new(-19.6792, -35.6453, 20.6942),
		Vector3.new(-19.822, -45.9261, 17.9177),
		Vector3.new(-19.7903, -39.2376, 19.7241),
		Vector3.new(-19.822, -40.2626, 19.4472),
		Vector3.new(-21.456, 21.118, 16.205),
		Vector3.new(-34.3119, -25.1969, 23.516),
		Vector3.new(-21.079, 20.377, 16.205),
		Vector3.new(-34.0901, -17.9588, 25.4707),
		Vector3.new(8.1583, -17.3351, 25.6392),
		Vector3.new(0, -17.2419, 25.6644),
		Vector3.new(-20.49, 19.789, 16.205),
		Vector3.new(8.1583, -17.3353, 25.6391),
		Vector3.new(-34.3119, -25.1969, 23.516),
		Vector3.new(-20.2038, 19.643, 16.205),
		Vector3.new(-34.0902, -17.9588, 25.4707),
		Vector3.new(7.961, -25.0194, 25.2391),
		Vector3.new(-34.385, -29.466, 24.898),
		Vector3.new(7.9365, -24.5726, 23.6846),
		Vector3.new(-34.422, -28.7898, 22.5457),
		Vector3.new(8.1129, -18.8151, 25.2395),
		Vector3.new(-43.819, -26.317, 25.749),
		Vector3.new(-43.598, -19.047, 27.59),
		Vector3.new(-1.0457, -7.0597, 28.837),
		Vector3.new(-2.8342, -7.0376, 28.837),
		Vector3.new(-21.586, 21.94, 16.205),
		Vector3.new(-21.456, 22.762, 61.414),
		Vector3.new(-21.2154, 23.235, 61.414),
		Vector3.new(-13.035, -13.4442, 28.837),
		Vector3.new(-10.9993, -13.3988, 28.837),
		Vector3.new(7.9067, -25.1373, 25.6517),
		Vector3.new(7.8529, -25.1631, 25.7438),
		Vector3.new(-15.167, -15.268, 28.837),
		Vector3.new(-21.586, 21.94, 61.414),
		Vector3.new(1.999, 22.211, 64.835),
		Vector3.new(-21.5431, 22.211, 61.414),
		Vector3.new(-13.035, -13.4438, 28.837),
		Vector3.new(-15.167, -6.462, 28.837),
		Vector3.new(-12.8744, -6.9149, 28.837),
		Vector3.new(12.836, -6.462, 35.927),
		Vector3.new(-15.167, -6.462, 35.927),
		Vector3.new(-15.167, -15.268, 35.927),
		Vector3.new(12.836, -15.268, 35.927),
		Vector3.new(-45.356, -29.3565, 24.9871),
		Vector3.new(-15.312, -6.462, 35.93),
		Vector3.new(-15.312, -16.226, 35.93),
		Vector3.new(12.836, -16.226, 35.93),
		Vector3.new(12.836, -6.462, 35.93),
		Vector3.new(-15.312, -6.462, 28.835),
		Vector3.new(-15.312, -16.226, 28.835),
		Vector3.new(12.836, -16.226, 28.835),
		Vector3.new(-20.49, 24.091, 61.667),
		Vector3.new(-21.079, 23.503, 61.667),
		Vector3.new(-21.2154, 23.235, 61.667),
		Vector3.new(0, -28.0767, 22.7383),
		Vector3.new(6.2483, -13.0236, 28.835),
		Vector3.new(4.2268, -13.0681, 28.835),
		Vector3.new(12.836, -6.462, 28.835),
		Vector3.new(4.3875, -6.5303, 28.835),
		Vector3.new(4.3877, -6.5303, 28.835),
		Vector3.new(6.2595, -6.5534, 28.835),
		Vector3.new(12.836, -6.6338, 28.835),
		Vector3.new(12.5508, -9.0105, 28.835),
		Vector3.new(12.836, -8.8289, 28.835),
		Vector3.new(4.3353, -8.6583, 28.835),
		Vector3.new(4.3354, -8.655, 28.835),
		Vector3.new(-38.162, -18.545, 27.686),
		Vector3.new(4.3619, -7.5775, 28.835),
		Vector3.new(-1.1959, -13.1907, 28.835),
		Vector3.new(-1.9503, -13.2075, 28.835),
		Vector3.new(-2.0653, -13.2096, 28.835),
		Vector3.new(-38.383, -25.816, 25.845),
		Vector3.new(-1.1959, -13.1904, 28.835),
		Vector3.new(0.107, -28.0779, 22.7379),
		Vector3.new(0.1068, -28.0779, 22.7379),
		Vector3.new(-1.1955, -13.172, 28.835),
		Vector3.new(0.0565, -29.7167, 22.2953),
		Vector3.new(-4.1684, -8.8444, 28.835),
		Vector3.new(-4.1588, -9.0206, 28.835),
		Vector3.new(-4.1577, -9.041, 28.835),
		Vector3.new(-4.1245, -9.0198, 28.835),
		Vector3.new(-3.8374, -8.8365, 28.835),
		Vector3.new(-3.8731, -8.8373, 28.835),
		Vector3.new(-4.1684, -8.8444, 28.835),
		Vector3.new(-43.9496, -28.681, 22.575),
		Vector3.new(-43.856, -25.6407, 23.3961),
		Vector3.new(-43.856, -25.6405, 23.3962),
		Vector3.new(-43.839, -25.0886, 23.5452),
		Vector3.new(-1.0879, -8.7784, 28.835),
		Vector3.new(-45.3699, -28.6648, 22.5794),
		Vector3.new(-1.0877, -8.7699, 28.835),
		Vector3.new(-21.456, 22.762, 16.205),
		Vector3.new(-46.7564, -25.6075, 23.4051),
		Vector3.new(-1.0458, -7.0591, 28.835),
		Vector3.new(-2.8367, -7.037, 28.835),
		Vector3.new(-11.0131, -13.407, 28.835),
		Vector3.new(-13.0352, -13.4521, 28.835),
		Vector3.new(-38.4195, -25.1502, 23.5286),
		Vector3.new(-38.4187, -25.1502, 23.5286),
		Vector3.new(-13.0352, -13.4517, 28.835),
		Vector3.new(-12.8745, -6.9143, 28.835),
		Vector3.new(-43.839, -25.0881, 23.5454),
		Vector3.new(-38.4195, -25.15, 23.5286),
		Vector3.new(-35.5992, -25.1822, 23.5199),
		Vector3.new(-38.1969, -17.9119, 25.4834),
		Vector3.new(-38.2139, -18.4653, 25.334),
		Vector3.new(-43.6335, -18.4034, 25.3507),
		Vector3.new(12.836, -15.268, 28.837),
		Vector3.new(-49.152, -18.3403, 25.3677),
		Vector3.new(-43.6335, -18.4036, 25.3506),
		Vector3.new(-22.085, -52.348, 9.913),
		Vector3.new(-38.2139, -18.4656, 25.3339),
		Vector3.new(-20.3822, 24.146, 16.205),
		Vector3.new(-20.49, 24.091, 16.205),
		Vector3.new(-43.6855, -20.102, 24.892),
		Vector3.new(-20.254, -52.348, 6.32),
		Vector3.new(-38.2481, -19.583, 25.0321),
		Vector3.new(-54.3023, -39.3982, 19.6807),
		Vector3.new(-54.261, -40.152, 22.302),
		Vector3.new(-19.933, -52.348, 6.951),
		Vector3.new(-54.481, -47.423, 20.461),
		Vector3.new(-54.5241, -46.6368, 17.7258),
		Vector3.new(-52.2226, -46.6629, 17.7188),
		Vector3.new(-54.5241, -46.6365, 17.7259),
		Vector3.new(-19.933, -52.348, 8.35),
		Vector3.new(-51.3521, -18.3152, 25.3745),
		Vector3.new(-21.586, -52.348, 0),
		Vector3.new(-51.5749, -25.5529, 23.4198),
		Vector3.new(-22.085, -52.348, 5.388),
		Vector3.new(-20.254, -52.348, 8.98),
		Vector3.new(-20.48, -52.348, 9.206),
		Vector3.new(18, -52.348, 0),
		Vector3.new(-22.784, -52.348, 9.802),
		Vector3.new(-51.3539, -18.3152, 25.3745),
		Vector3.new(-23.415, -52.348, 9.481),
		Vector3.new(-51.5757, -25.5529, 23.4198),
		Vector3.new(-55.424, -18.929, 27.686),
		Vector3.new(-23.916, -52.348, 8.98),
		Vector3.new(-55.645, -26.2, 25.845),
		Vector3.new(-24.237, -52.348, 8.35),
		Vector3.new(-52.6617, -18.3002, 25.3785),
		Vector3.new(-55.4604, -18.2682, 25.3872),
		Vector3.new(-55.4602, -18.2682, 25.3872),
		Vector3.new(-55.683, -25.5063, 23.4324),
		Vector3.new(-55.5139, -20.0121, 24.9162),
		Vector3.new(-24.237, -52.348, 6.951),
		Vector3.new(-45.2111, -36.6312, 23.1431),
		Vector3.new(-23.916, -52.348, 6.32),
		Vector3.new(-23.415, -52.348, 5.82),
		Vector3.new(-43.3956, -35.9279, 20.6179),
		Vector3.new(-45.2169, -36.3426, 22.139),
		Vector3.new(-22.784, -52.348, 5.498),
		Vector3.new(-45.2256, -35.9071, 20.6235),
		Vector3.new(-36.998, -39.768, 22.302),
		Vector3.new(-37.038, -39.0419, 19.7769),
		Vector3.new(-37.055, -39.5946, 19.6277),
		Vector3.new(-21.386, -52.348, 5.498),
		Vector3.new(-34.737, -39.068, 19.7699),
		Vector3.new(-20.755, -52.348, 5.82),
		Vector3.new(-34.6438, -36.0272, 20.5911),
		Vector3.new(-34.605, -36.737, 23.057),
		Vector3.new(-34.6438, -36.0279, 20.5909),
		Vector3.new(-34.5878, -34.2006, 21.0844),
		Vector3.new(-20.755, -52.348, 9.481),
		Vector3.new(-21.386, -52.348, 9.802),
		Vector3.new(18, 24.146, 16.205),
		Vector3.new(-18.927, 24.599, 61.667),
		Vector3.new(-42.435, -40.269, 22.206),
		Vector3.new(-16.776, 23.503, 61.667),
		Vector3.new(-17.365, 24.091, 61.667),
		Vector3.new(-45.633, -39.4966, 19.6541),
		Vector3.new(-18.106, 24.469, 61.667),
		Vector3.new(-42.4753, -39.5327, 19.6444),
		Vector3.new(-19.749, 24.469, 61.667),
		Vector3.new(17.924, 19.643, 16.205),
		Vector3.new(17.924, 19.643, 47.3914),
		Vector3.new(-42.655, -47.541, 20.365),
		Vector3.new(-42.6364, -44.7889, 18.2248),
		Vector3.new(-42.6971, -46.7716, 17.6894),
		Vector3.new(-54.462, -44.6097, 18.2732),
		Vector3.new(-37.2006, -44.3247, 18.3502),
		Vector3.new(-37.219, -47.039, 20.461),
		Vector3.new(-34.0471, -46.3171, 17.8121),
		Vector3.new(-37.2606, -46.2804, 17.822),
		Vector3.new(-51.1938, -46.6746, 17.7156),
		Vector3.new(-16.399, 21.118, 61.667),
		Vector3.new(-19.749, 19.411, 61.667),
		Vector3.new(-18.927, 19.281, 61.667),
		Vector3.new(-18.106, 19.411, 61.667),
		Vector3.new(-17.365, 19.789, 61.667),
		Vector3.new(-16.776, 20.377, 61.667),
		Vector3.new(-21.079, 23.503, 16.205),
		Vector3.new(9.353, -39.118, 22.206),
		Vector3.new(9.133, -46.389, 20.365),
		Vector3.new(6.5151, -38.4326, 19.9415),
		Vector3.new(0, -38.3582, 19.9616),
		Vector3.new(9.3172, -38.4644, 19.9329),
		Vector3.new(9.3172, -38.4644, 19.9329),
		Vector3.new(9.1496, -43.9339, 18.4558),
		Vector3.new(9.0954, -45.7029, 17.978),
		Vector3.new(0, -45.599, 18.0061),
		Vector3.new(-9.293, -25.55, 25.749),
		Vector3.new(-9.073, -18.279, 27.59),
		Vector3.new(-21.586, -28.3833, 22.6555),
		Vector3.new(-3.6687, -17.1999, 25.6757),
		Vector3.new(-3.6686, -17.1999, 25.6757),
		Vector3.new(-1.2212, -17.228, 25.6681),
		Vector3.new(-3.6856, -17.7522, 25.5265),
		Vector3.new(-9.1052, -17.6907, 25.5431),
		Vector3.new(-11.686, -28.581, 24.994),
		Vector3.new(-3.6856, -17.7537, 25.5261),
		Vector3.new(-21.586, -35.6235, 20.7001),
		Vector3.new(-9.1053, -17.6916, 25.5429),
		Vector3.new(-1.3046, -24.4671, 23.7131),
		Vector3.new(-3.8904, -24.4375, 23.7211),
		Vector3.new(-9.3101, -24.3755, 23.7378),
		Vector3.new(-9.327, -24.9288, 23.5884),
		Vector3.new(-2.5561, -28.0475, 22.7461),
		Vector3.new(-11.7212, -27.9428, 22.7744),
		Vector3.new(-11.9909, -24.8985, 23.5966),
		Vector3.new(-11.7212, -27.9428, 22.7744),
		Vector3.new(-3.7154, -18.7252, 25.2638),
		Vector3.new(-9.278, -23.328, 24.0207),
		Vector3.new(-11.7728, -29.6268, 22.3196),
		Vector3.new(-19.822, -17.569, 25.576),
		Vector3.new(-18.3675, -17.5856, 25.5715),
		Vector3.new(-19.822, -28.4033, 22.65),
		Vector3.new(-17.1585, -28.4335, 22.6419),
		Vector3.new(-19.822, -24.8091, 23.6207),
		Vector3.new(-17.1585, -28.4342, 22.6417),
		Vector3.new(-17.211, -30.145, 22.1797),
		Vector3.new(-8.1681, -46.0592, 17.8818),
		Vector3.new(-0.115, -35.3154, 20.7833),
		Vector3.new(-0.2082, -38.3558, 19.9622),
		Vector3.new(-0.43, -45.5941, 18.0074),
		Vector3.new(-9.1026, -35.2128, 20.811),
		Vector3.new(-11.9437, -35.1803, 20.8198),
		Vector3.new(-2.5097, -38.3295, 19.9693),
		Vector3.new(-2.5097, -38.3302, 19.9691),
		Vector3.new(-2.7315, -45.5678, 18.0145),
		Vector3.new(-7.9463, -38.8207, 19.8367),
		Vector3.new(-8.0014, -40.6186, 19.3511),
		Vector3.new(-19.6793, -35.6453, 20.6942),
		Vector3.new(-19.822, -35.6437, 20.6947),
		Vector3.new(-20.899, -18.162, 27.686),
		Vector3.new(-21.121, -25.432, 25.845),
		Vector3.new(-20.9322, -17.5563, 25.5795),
		Vector3.new(-20.9322, -17.5563, 25.5795),
		Vector3.new(-26.4973, -16.226, 17.8494),
		Vector3.new(-26.4995, -16.299, 17.8309),
		Vector3.new(-26.4995, -16.299, 17.8312),
		Vector3.new(-26.4973, -16.226, 17.8497),
		Vector3.new(-21.156, -24.7938, 23.6248),
		Vector3.new(-26.4995, -16.299, 17.8317),
		Vector3.new(-26.4973, -16.226, 17.8502),
		Vector3.new(-20.9816, -19.1545, 25.1478),
		Vector3.new(-26.4685, -16.226, 19.111),
		Vector3.new(-26.4645, -16.299, 19.365),
		Vector3.new(-49.152, -16.226, 17.9773),
		Vector3.new(-48.3611, -16.226, 17.9728),
		Vector3.new(-43.751, -16.272, 17.935),
		Vector3.new(-43.7518, -16.299, 17.9282),
		Vector3.new(-48.3685, -16.226, 17.9731),
		Vector3.new(-43.7518, -16.299, 17.9284),
		Vector3.new(-48.3779, -16.226, 17.9735),
		Vector3.new(-3.637, -17.778, 27.686),
		Vector3.new(8.0035, -16.226, 17.655),
		Vector3.new(8.0013, -16.299, 17.6365),
		Vector3.new(8.0035, -16.226, 17.655),
		Vector3.new(8.0013, -16.299, 17.6366),
		Vector3.new(8.0013, -16.299, 17.6372),
		Vector3.new(8.0036, -16.226, 17.6557),
		Vector3.new(-43.7518, -16.299, 17.9288),
		Vector3.new(-3.857, -25.048, 25.845),
		Vector3.new(2.8588, -16.299, 22.2602),
		Vector3.new(8.1016, -16.299, 22.0356),
		Vector3.new(8.0976, -16.226, 21.7817),
		Vector3.new(3.1794, -16.226, 21.9924),
		Vector3.new(8.1015, -16.299, 22.0352),
		Vector3.new(8.0976, -16.226, 21.7813),
		Vector3.new(-37.4839, -16.299, 17.8932),
		Vector3.new(-37.5986, -16.226, 17.9124),
		Vector3.new(-48.3843, -16.226, 17.9738),
		Vector3.new(-3.8282, -16.299, 17.7036),
		Vector3.new(-3.826, -16.226, 17.7221),
		Vector3.new(-3.8259, -16.226, 17.727),
		Vector3.new(-3.8281, -16.299, 17.7085),
		Vector3.new(-3.8259, -16.226, 17.7278),
		Vector3.new(-3.8281, -16.299, 17.7094),
		Vector3.new(-3.722, -16.226, 22.2887),
		Vector3.new(-3.718, -16.299, 22.5425),
		Vector3.new(-43.7518, -16.299, 17.9289),
		Vector3.new(-38.331, -16.299, 17.8981),
		Vector3.new(-38.3288, -16.226, 17.9165),
		Vector3.new(-9.2468, -16.226, 17.7522),
		Vector3.new(-9.2491, -16.299, 17.7337),
		Vector3.new(-49.152, -16.226, 18.0068),
		Vector3.new(-47.8525, -16.299, 18.2051),
		Vector3.new(-9.2468, -16.226, 17.7522),
		Vector3.new(-9.2491, -16.299, 17.7337),
		Vector3.new(-47.8525, -16.299, 18.2051),
		Vector3.new(-35.9857, -16.299, 19.7738),
		Vector3.new(-38.2858, -16.299, 19.8723),
		Vector3.new(-38.2899, -16.226, 19.6184),
		Vector3.new(-36.1244, -16.299, 19.7797),
		Vector3.new(-36.4267, -16.226, 19.5385),
		Vector3.new(-43.8696, -16.299, 18.0341),
		Vector3.new(-43.7495, -16.299, 18.0289),
		Vector3.new(-43.7495, -16.299, 18.0289),
		Vector3.new(-18.106, 19.411, 47.3327),
		Vector3.new(-18.927, 19.281, 47.2999),
		Vector3.new(-53.2791, -16.299, 17.9822),
		Vector3.new(-53.2769, -16.226, 18.0007),
		Vector3.new(-53.2791, -16.299, 17.9822),
		Vector3.new(-17.6512, 19.643, 47.3914),
		Vector3.new(-53.2769, -16.226, 18.0007),
		Vector3.new(-55.5814, -16.299, 17.9953),
		Vector3.new(-55.5792, -16.226, 18.0138),
		Vector3.new(-53.2687, -16.299, 18.4377),
		Vector3.new(-53.2727, -16.226, 18.1837),
		Vector3.new(-53.2727, -16.226, 18.1837),
		Vector3.new(-53.2687, -16.299, 18.4377),
		Vector3.new(-55.573, -16.226, 18.2825),
		Vector3.new(-55.569, -16.299, 18.5364),
		Vector3.new(-16.776, 23.503, 16.205),
		Vector3.new(-19.749, 19.411, 47.3327),
		Vector3.new(-17.365, 24.091, 16.205),
		Vector3.new(-17.4728, 24.146, 16.205),
		Vector3.new(-17.123, -29.082, 24.898),
		Vector3.new(-9.249, -16.299, 17.7346),
		Vector3.new(-9.2468, -16.226, 17.7531),
		Vector3.new(-12.7167, -16.299, 20.8515),
		Vector3.new(-9.1815, -16.299, 20.701),
		Vector3.new(-9.1855, -16.226, 20.447),
		Vector3.new(-12.396, -16.226, 20.5837),
		Vector3.new(-9.1815, -16.299, 20.6997),
		Vector3.new(-9.1855, -16.226, 20.4459),
		Vector3.new(-19.957, -46.655, 20.461),
		Vector3.new(-19.997, -45.9241, 17.9183),
		Vector3.new(-19.9388, -44.0397, 18.4272),
		Vector3.new(-9.2299, -16.226, 18.4966),
		Vector3.new(-9.2304, -16.299, 18.5534),
		Vector3.new(-19.7314, -16.226, 17.8117),
		Vector3.new(-19.6167, -16.299, 17.7925),
		Vector3.new(-19.822, -16.299, 17.7937),
		Vector3.new(-19.822, -16.226, 17.8122),
		Vector3.new(-19.822, -16.299, 21.1565),
		Vector3.new(-8.129, -46.773, 20.365),
		Vector3.new(-21.0789, -16.299, 17.8008),
		Vector3.new(-21.0766, -16.226, 17.8193),
		Vector3.new(-21.005, -16.226, 20.9532),
		Vector3.new(-7.909, -39.502, 22.206),
		Vector3.new(-21.001, -16.299, 21.2071),
		Vector3.new(-11.907, -35.851, 23.153),
		Vector3.new(-0.079, -35.969, 23.057),
		Vector3.new(-2.473, -39, 22.302),
		Vector3.new(-2.693, -46.271, 20.461),
		Vector3.new(-17.343, -36.353, 23.057),
		Vector3.new(-16.399, 21.118, 16.205),
		Vector3.new(-17.365, 19.789, 16.205),
		Vector3.new(-17.6512, 19.643, 16.205),
		Vector3.new(-43.914, 21.255, 61.414),
		Vector3.new(-43.914, 21.255, 82.789),
		Vector3.new(-39.725, 21.792, 64.837),
		Vector3.new(-39.725, 21.792, 79.782),
	},
	objects = {
		{
			name = "obj_0_color_2829873",
			sourceObject = "obj_0",
			color = Color3.new(0.16862745098039217, 0.1803921568627451, 0.19215686274509805),
			rectangles = {
				{
					center = Vector3.new(-59.714, -34.2835, 16.205),
					size = Vector3.new(0.026, 35.969, 0),
					right = Vector3.new(-1, 0, 0),
					up = Vector3.new(0, 1, 0),
					faces = { 26, 27 },
				},
				{
					center = Vector3.new(-21.2675, 20.7475, 38.936),
					size = Vector3.new(0.831390402, 45.462, 0),
					right = Vector3.new(-0.453457244, 0.891278031, 0),
					up = Vector3.new(0, 0, -1),
					faces = { 29, 56 },
				},
				{
					center = Vector3.new(-20.7845, 20.083, 38.936),
					size = Vector3.new(0.832264982, 45.462, 0),
					right = Vector3.new(0.707707296, -0.706505756, 0),
					up = Vector3.new(0, 0, 1),
					faces = { 30, 51 },
				},
				{
					center = Vector3.new(-18.928, 22.0015, 64.837),
					size = Vector3.new(41.594, 0.419, 0),
					right = Vector3.new(-1, 0, 0),
					up = Vector3.new(0, 1, 0),
					faces = { 62, 99 },
				},
				{
					center = Vector3.new(1.869, 22.0015, 72.3095),
					size = Vector3.new(14.945, 0.419, 0),
					right = Vector3.new(0, 0, -1),
					up = Vector3.new(0, 1, 0),
					faces = { 63, 64 },
				},
				{
					center = Vector3.new(-1.1655, -10.865, 35.927),
					size = Vector3.new(28.003, 8.806, 0),
					right = Vector3.new(-1, 0, 0),
					up = Vector3.new(0, -1, 0),
					faces = { 86, 87 },
				},
				{
					center = Vector3.new(-20.7845, 23.797, 38.936),
					size = Vector3.new(45.462, 0.832264982, 0),
					right = Vector3.new(0, 0, 1),
					up = Vector3.new(0.707707296, 0.706505756, 0),
					faces = { 90, 96 },
				},
				{
					center = Vector3.new(-18.928, 21.792, 72.3095),
					size = Vector3.new(41.594, 14.945, 0),
					right = Vector3.new(1, 0, 0),
					up = Vector3.new(0, 0, 1),
					faces = { 97, 434 },
				},
				{
					center = Vector3.new(-18.928, 22.0015, 79.782),
					size = Vector3.new(0.419, 41.594, 0),
					right = Vector3.new(0, 1, 0),
					up = Vector3.new(-1, 0, 0),
					faces = { 98, 435 },
				},
				{
					center = Vector3.new(18, -14.101, 8.1025),
					size = Vector3.new(76.494, 16.205, 0),
					right = Vector3.new(0, -1, 0),
					up = Vector3.new(0, 0, -1),
					faces = { 131, 135 },
				},
				{
					center = Vector3.new(-17.0705, 23.797, 38.936),
					size = Vector3.new(0.832264982, 45.462, 0),
					right = Vector3.new(0.707707296, -0.706505756, 0),
					up = Vector3.new(0, 0, -1),
					faces = { 147, 338 },
				},
				{
					center = Vector3.new(-16.5875, 20.7475, 38.936),
					size = Vector3.new(0.831390402, 45.462, 0),
					right = Vector3.new(-0.453457244, -0.891278031, 0),
					up = Vector3.new(0, 0, -1),
					faces = { 172, 332 },
				},
				{
					center = Vector3.new(-19.338, 24.534, 30.8335),
					size = Vector3.new(0.832216318, 61.667, 0),
					right = Vector3.new(0.987723963, 0.156209386, 0),
					up = Vector3.new(0, 0, -1),
					faces = { 180, 346 },
				},
				{
					center = Vector3.new(-40.0416, 24.146, 8.1025),
					size = Vector3.new(16.205, 39.3188, 0),
					right = Vector3.new(0, 0, -1),
					up = Vector3.new(-1, 0, 0),
					faces = { 183, 186 },
				},
				{
					center = Vector3.new(0.2636, 24.146, 8.1025),
					size = Vector3.new(16.205, 35.4728, 0),
					right = Vector3.new(0, 0, 1),
					up = Vector3.new(1, 0, 0),
					faces = { 347, 348 },
				},
				{
					center = Vector3.new(-18.5165, 24.534, 30.8335),
					size = Vector3.new(61.667, 0.831228609, 0),
					right = Vector3.new(0, 0, 1),
					up = Vector3.new(0.98769459, -0.156395002, 0),
					faces = { 327, 329 },
				},
				{
					center = Vector3.new(-17.0705, 20.083, 38.936),
					size = Vector3.new(45.462, 0.832264982, 0),
					right = Vector3.new(0, 0, 1),
					up = Vector3.new(-0.707707296, -0.706505756, 0),
					faces = { 418, 429 },
				},
				{
					center = Vector3.new(-15.167, -10.865, 32.382),
					size = Vector3.new(7.09, 8.806, 0),
					right = Vector3.new(0, 0, 1),
					up = Vector3.new(0, 1, 0),
					faces = { 430, 431 },
				},
				{
					center = Vector3.new(-1.1655, -15.268, 32.382),
					size = Vector3.new(7.09, 28.003, 0),
					right = Vector3.new(0, 0, 1),
					up = Vector3.new(-1, 0, 0),
					faces = { 432, 433 },
				},
			},
			faces = {
				{ 13, 1, 12 },
				{ 16, 17, 18 },
				{ 20, 21, 22 },
				{ 28, 31, 27 },
				{ 32, 34, 31 },
				{ 33, 34, 32 },
				{ 27, 31, 34 },
				{ 184, 164, 17 },
				{ 35, 81, 345 },
				{ 66, 324, 68 },
				{ 66, 68, 69 },
				{ 70, 66, 69 },
				{ 68, 74, 69 },
				{ 298, 28, 37 },
				{ 37, 28, 27 },
				{ 298, 296, 28 },
				{ 64, 285, 77 },
				{ 78, 285, 64 },
				{ 68, 79, 80 },
				{ 69, 85, 70 },
				{ 484, 345, 84 },
				{ 84, 345, 81 },
				{ 67, 133, 76 },
				{ 83, 133, 65 },
				{ 33, 32, 80 },
				{ 31, 22, 21 },
				{ 31, 21, 32 },
				{ 72, 67, 76 },
				{ 23, 18, 166 },
				{ 166, 170, 23 },
				{ 96, 97, 266 },
				{ 100, 101, 103 },
				{ 102, 103, 101 },
				{ 99, 100, 103 },
				{ 98, 99, 103 },
				{ 266, 97, 104 },
				{ 266, 104, 105 },
				{ 106, 96, 141 },
				{ 117, 141, 96 },
				{ 107, 148, 108 },
				{ 110, 266, 109 },
				{ 109, 266, 111 },
				{ 117, 96, 112 },
				{ 266, 110, 96 },
				{ 75, 76, 133 },
				{ 123, 124, 121 },
				{ 124, 126, 121 },
				{ 128, 121, 126 },
				{ 119, 121, 128 },
				{ 83, 75, 133 },
				{ 35, 23, 170 },
				{ 35, 170, 81 },
				{ 67, 324, 133 },
				{ 330, 486, 78 },
				{ 18, 17, 164 },
				{ 18, 164, 166 },
				{ 126, 124, 139 },
				{ 141, 148, 106 },
				{ 107, 106, 148 },
				{ 182, 102, 148 },
				{ 81, 170, 173 },
				{ 144, 522, 149 },
				{ 145, 144, 149 },
				{ 145, 149, 147 },
				{ 13, 173, 170 },
				{ 13, 170, 166 },
				{ 169, 168, 74 },
				{ 168, 171, 74 },
				{ 171, 179, 74 },
				{ 179, 177, 74 },
				{ 108, 148, 102 },
				{ 101, 108, 102 },
				{ 183, 102, 182 },
				{ 197, 102, 183 },
				{ 184, 13, 164 },
				{ 350, 250, 186 },
				{ 188, 191, 187 },
				{ 111, 191, 188 },
				{ 196, 195, 191 },
				{ 187, 191, 195 },
				{ 192, 184, 17 },
				{ 195, 196, 197 },
				{ 197, 196, 102 },
				{ 192, 194, 184 },
				{ 185, 250, 194 },
				{ 198, 199, 200 },
				{ 198, 200, 201 },
				{ 212, 61, 211 },
				{ 210, 211, 61 },
				{ 210, 350, 211 },
				{ 212, 211, 186 },
				{ 350, 186, 211 },
				{ 184, 194, 250 },
				{ 185, 186, 250 },
				{ 1, 184, 250 },
				{ 210, 272, 350 },
				{ 522, 144, 145 },
				{ 15, 145, 147 },
				{ 19, 149, 522 },
				{ 322, 85, 323 },
				{ 269, 323, 85 },
				{ 28, 293, 85 },
				{ 271, 1, 272 },
				{ 69, 31, 85 },
				{ 28, 85, 31 },
				{ 272, 210, 271 },
				{ 274, 290, 278 },
				{ 86, 278, 290 },
				{ 86, 70, 283 },
				{ 283, 70, 288 },
				{ 85, 322, 70 },
				{ 310, 307, 285 },
				{ 27, 285, 307 },
				{ 287, 310, 285 },
				{ 288, 70, 289 },
				{ 269, 85, 291 },
				{ 291, 85, 293 },
				{ 86, 290, 70 },
				{ 66, 70, 290 },
				{ 274, 317, 290 },
				{ 293, 28, 296 },
				{ 37, 27, 304 },
				{ 304, 27, 306 },
				{ 307, 306, 27 },
				{ 285, 290, 317 },
				{ 287, 285, 315 },
				{ 315, 285, 317 },
				{ 71, 285, 78 },
				{ 73, 77, 285 },
				{ 27, 2, 285 },
				{ 324, 66, 63 },
				{ 289, 70, 322 },
				{ 290, 285, 71 },
				{ 290, 71, 63 },
				{ 290, 63, 66 },
				{ 483, 133, 324 },
				{ 61, 327, 328 },
				{ 61, 328, 330 },
				{ 330, 325, 61 },
				{ 332, 61, 325 },
				{ 210, 61, 332 },
				{ 324, 67, 333 },
				{ 324, 333, 79 },
				{ 79, 68, 324 },
				{ 61, 65, 327 },
				{ 483, 327, 65 },
				{ 483, 328, 327 },
				{ 341, 342, 31 },
				{ 342, 337, 31 },
				{ 281, 280, 31 },
				{ 118, 115, 122 },
				{ 122, 165, 125 },
				{ 125, 178, 127 },
				{ 125, 118, 122 },
				{ 129, 414, 130 },
				{ 115, 411, 122 },
				{ 20, 167, 405 },
				{ 130, 405, 131 },
				{ 131, 405, 132 },
				{ 178, 321, 127 },
				{ 142, 136, 143 },
				{ 135, 127, 321 },
				{ 146, 136, 142 },
				{ 146, 150, 136 },
				{ 137, 136, 150 },
				{ 347, 348, 346 },
				{ 345, 346, 348 },
				{ 345, 348, 349 },
				{ 345, 349, 344 },
				{ 57, 344, 60 },
				{ 517, 67, 60 },
				{ 344, 349, 517 },
				{ 517, 60, 344 },
				{ 157, 138, 158 },
				{ 137, 158, 138 },
				{ 152, 497, 153 },
				{ 150, 158, 137 },
				{ 332, 271, 210 },
				{ 178, 125, 165 },
				{ 64, 332, 325 },
				{ 272, 1, 350 },
				{ 350, 1, 250 },
				{ 271, 73, 1 },
				{ 232, 372, 233 },
				{ 233, 372, 213 },
				{ 73, 2, 1 },
				{ 372, 232, 177 },
				{ 235, 177, 232 },
				{ 166, 164, 13 },
				{ 353, 356, 177 },
				{ 177, 235, 353 },
				{ 356, 355, 177 },
				{ 69, 74, 355 },
				{ 69, 355, 357 },
				{ 358, 69, 357 },
				{ 358, 359, 69 },
				{ 391, 353, 235 },
				{ 177, 355, 74 },
				{ 20, 406, 363 },
				{ 364, 74, 363 },
				{ 20, 363, 74 },
				{ 74, 364, 365 },
				{ 74, 365, 169 },
				{ 366, 363, 367 },
				{ 369, 366, 367 },
				{ 380, 369, 371 },
				{ 367, 371, 369 },
				{ 152, 341, 31 },
				{ 375, 376, 373 },
				{ 374, 375, 373 },
				{ 213, 372, 376 },
				{ 132, 405, 167 },
				{ 376, 375, 377 },
				{ 165, 172, 178 },
				{ 136, 135, 321 },
				{ 167, 20, 174 },
				{ 378, 377, 375 },
				{ 243, 178, 256 },
				{ 245, 244, 256 },
				{ 246, 245, 256 },
				{ 243, 256, 244 },
				{ 122, 411, 129 },
				{ 373, 376, 372 },
				{ 286, 294, 276 },
				{ 373, 380, 381 },
				{ 373, 381, 374 },
				{ 371, 381, 380 },
				{ 243, 244, 248 },
				{ 244, 251, 248 },
				{ 498, 163, 159 },
				{ 498, 153, 497 },
				{ 159, 153, 498 },
				{ 260, 246, 256 },
				{ 260, 256, 261 },
				{ 379, 388, 382 },
				{ 257, 256, 178 },
				{ 262, 257, 178 },
				{ 172, 262, 178 },
				{ 265, 20, 267 },
				{ 264, 263, 265 },
				{ 263, 20, 265 },
				{ 174, 20, 263 },
				{ 367, 363, 384 },
				{ 384, 363, 383 },
				{ 270, 264, 265 },
				{ 268, 270, 265 },
				{ 386, 379, 377 },
				{ 377, 378, 386 },
				{ 387, 386, 378 },
				{ 385, 386, 387 },
				{ 270, 268, 275 },
				{ 261, 275, 273 },
				{ 261, 273, 260 },
				{ 273, 275, 268 },
				{ 386, 388, 379 },
				{ 267, 20, 284 },
				{ 301, 299, 20 },
				{ 389, 382, 388 },
				{ 251, 286, 248 },
				{ 161, 497, 69 },
				{ 393, 398, 69 },
				{ 284, 20, 292 },
				{ 292, 20, 299 },
				{ 22, 276, 302 },
				{ 394, 396, 391 },
				{ 392, 354, 391 },
				{ 354, 353, 391 },
				{ 302, 303, 20 },
				{ 303, 300, 20 },
				{ 22, 302, 20 },
				{ 359, 393, 69 },
				{ 301, 20, 300 },
				{ 394, 395, 399 },
				{ 392, 391, 396 },
				{ 294, 302, 276 },
				{ 382, 389, 395 },
				{ 389, 116, 395 },
				{ 394, 399, 396 },
				{ 313, 308, 331 },
				{ 314, 313, 331 },
				{ 311, 329, 308 },
				{ 400, 390, 398 },
				{ 390, 69, 398 },
				{ 248, 286, 276 },
				{ 397, 396, 399 },
				{ 248, 276, 311 },
				{ 507, 503, 32 },
				{ 507, 416, 511 },
				{ 399, 400, 397 },
				{ 398, 397, 400 },
				{ 318, 320, 136 },
				{ 143, 136, 320 },
				{ 316, 143, 320 },
				{ 321, 318, 136 },
				{ 316, 320, 313 },
				{ 308, 313, 320 },
				{ 402, 162, 401 },
				{ 160, 401, 162 },
				{ 160, 162, 156 },
				{ 331, 336, 339 },
				{ 314, 331, 339 },
				{ 342, 339, 336 },
				{ 336, 337, 342 },
				{ 343, 31, 337 },
				{ 399, 395, 113 },
				{ 114, 113, 116 },
				{ 116, 113, 395 },
				{ 120, 114, 155 },
				{ 116, 155, 114 },
				{ 68, 80, 32 },
				{ 156, 120, 160 },
				{ 155, 160, 120 },
				{ 469, 468, 346 },
				{ 331, 308, 329 },
				{ 281, 31, 343 },
				{ 276, 329, 311 },
				{ 345, 484, 346 },
				{ 469, 346, 484 },
				{ 483, 65, 133 },
				{ 282, 22, 280 },
				{ 338, 22, 282 },
				{ 276, 22, 338 },
				{ 31, 280, 22 },
				{ 348, 347, 473 },
				{ 152, 69, 497 },
				{ 485, 486, 328 },
				{ 64, 325, 330 },
				{ 402, 370, 162 },
				{ 330, 78, 64 },
				{ 347, 346, 468 },
				{ 347, 468, 473 },
				{ 41, 517, 349 },
				{ 507, 32, 408 },
				{ 324, 486, 485 },
				{ 324, 485, 483 },
				{ 409, 412, 507 },
				{ 408, 409, 507 },
				{ 328, 483, 485 },
				{ 416, 460, 511 },
				{ 412, 416, 507 },
				{ 330, 328, 486 },
				{ 451, 439, 32 },
				{ 420, 451, 32 },
				{ 422, 451, 420 },
				{ 408, 32, 439 },
				{ 332, 64, 77 },
				{ 71, 486, 63 },
				{ 486, 324, 63 },
				{ 71, 78, 486 },
				{ 332, 77, 271 },
				{ 73, 271, 77 },
				{ 405, 406, 20 },
				{ 383, 363, 406 },
				{ 68, 426, 428 },
				{ 428, 429, 68 },
				{ 434, 74, 437 },
				{ 115, 362, 411 },
				{ 362, 385, 411 },
				{ 387, 411, 385 },
				{ 405, 130, 414 },
				{ 414, 129, 411 },
				{ 138, 157, 370 },
				{ 437, 68, 429 },
				{ 390, 161, 69 },
				{ 31, 69, 152 },
				{ 74, 68, 437 },
				{ 433, 74, 434 },
				{ 157, 159, 163 },
				{ 163, 162, 157 },
				{ 162, 370, 157 },
				{ 426, 68, 442 },
				{ 447, 445, 488 },
				{ 503, 502, 32 },
				{ 442, 488, 445 },
				{ 20, 449, 511 },
				{ 74, 433, 449 },
				{ 74, 449, 20 },
				{ 447, 494, 449 },
				{ 491, 449, 494 },
				{ 488, 442, 458 },
				{ 458, 442, 454 },
				{ 491, 490, 449 },
				{ 490, 505, 449 },
				{ 447, 488, 500 },
				{ 16, 18, 344 },
				{ 344, 57, 16 },
				{ 500, 494, 447 },
				{ 35, 345, 344 },
				{ 18, 23, 344 },
				{ 35, 344, 23 },
				{ 68, 454, 442 },
				{ 454, 68, 502 },
				{ 68, 32, 502 },
				{ 431, 451, 422 },
				{ 451, 466, 461 },
				{ 505, 511, 449 },
				{ 519, 518, 473 },
				{ 431, 450, 451 },
				{ 477, 20, 456 },
				{ 20, 459, 456 },
				{ 20, 511, 460 },
				{ 465, 20, 466 },
				{ 459, 20, 465 },
				{ 461, 20, 463 },
				{ 460, 463, 20 },
				{ 20, 461, 466 },
				{ 467, 466, 451 },
				{ 450, 467, 451 },
				{ 21, 20, 32 },
				{ 482, 32, 20 },
				{ 475, 472, 32 },
				{ 470, 32, 472 },
				{ 420, 32, 470 },
				{ 20, 477, 480 },
				{ 72, 60, 67 },
				{ 20, 480, 482 },
				{ 475, 32, 482 },
				{ 41, 349, 348 },
				{ 67, 517, 333 },
				{ 517, 41, 333 },
				{ 2, 27, 34 },
				{ 2, 34, 12 },
				{ 73, 285, 2 },
				{ 519, 333, 518 },
				{ 348, 473, 518 },
				{ 2, 12, 1 },
				{ 518, 333, 41 },
				{ 1, 13, 184 },
				{ 41, 348, 518 },
				{ 191, 200, 196 },
				{ 200, 199, 196 },
				{ 266, 201, 191 },
				{ 201, 200, 191 },
				{ 522, 145, 523 },
				{ 145, 15, 523 },
				{ 112, 96, 110 },
				{ 191, 111, 266 },
			},
		},
		{
			name = "obj_0_color_6383466",
			sourceObject = "obj_0",
			color = Color3.new(0.3803921568627451, 0.403921568627451, 0.41568627450980394),
			rectangles = {
				{
					center = Vector3.new(6.363, 22.245, 72.1015),
					size = Vector3.new(1.98, 21.375, 0),
					right = Vector3.new(0, -1, 0),
					up = Vector3.new(0, 0, -1),
					faces = { 31, 32 },
				},
				{
					center = Vector3.new(1.999, 21.733, 72.31),
					size = Vector3.new(14.95, 0.956, 0),
					right = Vector3.new(0, 0, 1),
					up = Vector3.new(0, 1, 0),
					faces = { 37, 66 },
				},
				{
					center = Vector3.new(-18.7755, 22.245, 82.789),
					size = Vector3.new(1.98, 50.277, 0),
					right = Vector3.new(0, 1, 0),
					up = Vector3.new(-1, 0, 0),
					faces = { 64, 360 },
				},
				{
					center = Vector3.new(-18.863, 21.733, 64.835),
					size = Vector3.new(0.956, 41.724, 0),
					right = Vector3.new(0, -1, 0),
					up = Vector3.new(1, 0, 0),
					faces = { 103, 104 },
				},
				{
					center = Vector3.new(-18.863, 21.733, 79.785),
					size = Vector3.new(0.956, 41.724, 0),
					right = Vector3.new(0, -1, 0),
					up = Vector3.new(-1, 0, 0),
					faces = { 106, 107 },
				},
				{
					center = Vector3.new(-26.4984, -16.2625, 17.84055),
					size = Vector3.new(0.075536273, 0.000775506, 0),
					right = Vector3.new(0.029201022, 0.968942987, 0.245554045),
					up = Vector3.new(-0.007396901, -0.24544261, 0.969382902),
					faces = { 188, 189, 191, 192 },
				},
				{
					center = Vector3.new(-43.751402454, -16.285582822, 17.931929141),
					size = Vector3.new(0.027854623, 0.000678821, 0),
					right = Vector3.new(0.028720547, 0.969318464, 0.24412465),
					up = Vector3.new(-0.00723015, -0.24401756, 0.969743861),
					faces = { 199, 204, 234 },
				},
				{
					center = Vector3.new(-9.1835, -16.2625, 20.57345),
					size = Vector3.new(0.265369329, 0.000359845, 0),
					right = Vector3.new(-0.015144624, 0.27638939, -0.9609264),
					up = Vector3.new(-0.052574634, 0.959487078, 0.276804),
					faces = { 286, 287 },
				},
				{
					center = Vector3.new(-43.914, 22.245, 72.1015),
					size = Vector3.new(21.375, 1.98, 0),
					right = Vector3.new(0, 0, 1),
					up = Vector3.new(0, 1, 0),
					faces = { 365, 366 },
				},
				{
					center = Vector3.new(4.3876, -6.5306, 28.836),
					size = Vector3.new(0.002088061, 0.0002, 0),
					right = Vector3.new(0, 0.287347886, -0.957826285),
					up = Vector3.new(-1, 0, 0),
					faces = { 369, 370 },
				},
				{
					center = Vector3.new(-1.1958, -13.1866, 28.836),
					size = Vector3.new(0.008441355, 0.000153408, 0),
					right = Vector3.new(-0.025441093, -0.966761517, -0.254410926),
					up = Vector3.new(-0.096196366, 0.255679816, -0.961963664),
					faces = { 395, 396 },
				},
				{
					center = Vector3.new(-4.1582, -9.0311, 28.836),
					size = Vector3.new(0.021034149, 0.00200114, 0),
					right = Vector3.new(-0.05384335, 0.998549395, 0),
					up = Vector3.new(0.033706252, 0.001817494, 0.99943013),
					faces = { 399, 400 },
				},
				{
					center = Vector3.new(-1.0667, -7.9148, 28.836),
					size = Vector3.new(1.711910391, 0.002003284, 0),
					right = Vector3.new(0.024484124, 0.999700219, 0),
					up = Vector3.new(0.057219106, -0.00140138, 0.998360661),
					faces = { 417, 418 },
				},
				{
					center = Vector3.new(-13.0351, -13.44795, 28.836),
					size = Vector3.new(0.008539337, 0.000098629, 0),
					right = Vector3.new(-0.024534799, -0.969124557, -0.245347989),
					up = Vector3.new(0.096431498, -0.246571678, 0.964314977),
					faces = { 424, 425 },
				},
			},
			faces = {
				{ 44, 62, 43 },
				{ 44, 43, 60 },
				{ 60, 43, 57 },
				{ 42, 43, 62 },
				{ 61, 58, 59 },
				{ 59, 65, 61 },
				{ 90, 91, 95 },
				{ 91, 92, 95 },
				{ 93, 95, 92 },
				{ 95, 424, 90 },
				{ 129, 89, 88 },
				{ 168, 169, 95 },
				{ 114, 40, 113 },
				{ 94, 115, 118 },
				{ 129, 88, 122 },
				{ 127, 94, 125 },
				{ 118, 125, 94 },
				{ 89, 129, 130 },
				{ 131, 89, 130 },
				{ 131, 132, 89 },
				{ 60, 72, 44 },
				{ 59, 44, 72 },
				{ 135, 134, 127 },
				{ 94, 127, 134 },
				{ 76, 59, 72 },
				{ 135, 136, 134 },
				{ 76, 75, 59 },
				{ 75, 83, 59 },
				{ 59, 83, 65 },
				{ 136, 137, 134 },
				{ 58, 62, 59 },
				{ 44, 59, 62 },
				{ 142, 140, 146 },
				{ 146, 140, 150 },
				{ 151, 152, 153 },
				{ 114, 120, 40 },
				{ 43, 42, 154 },
				{ 341, 152, 151 },
				{ 158, 140, 157 },
				{ 120, 156, 40 },
				{ 95, 93, 179 },
				{ 140, 159, 157 },
				{ 179, 171, 95 },
				{ 153, 159, 151 },
				{ 140, 151, 159 },
				{ 162, 163, 40 },
				{ 158, 150, 140 },
				{ 506, 510, 40 },
				{ 122, 88, 165 },
				{ 230, 165, 88 },
				{ 132, 167, 89 },
				{ 365, 424, 169 },
				{ 174, 225, 167 },
				{ 89, 167, 225 },
				{ 177, 179, 175 },
				{ 175, 179, 93 },
				{ 17, 16, 3 },
				{ 16, 57, 3 },
				{ 43, 3, 57 },
				{ 168, 95, 171 },
				{ 62, 521, 42 },
				{ 175, 189, 372 },
				{ 432, 372, 90 },
				{ 5, 62, 58 },
				{ 175, 372, 177 },
				{ 43, 154, 193 },
				{ 260, 273, 180 },
				{ 267, 284, 295 },
				{ 19, 6, 149 },
				{ 154, 147, 193 },
				{ 149, 193, 147 },
				{ 246, 260, 180 },
				{ 268, 265, 181 },
				{ 176, 243, 202 },
				{ 251, 180, 286 },
				{ 90, 372, 190 },
				{ 190, 372, 189 },
				{ 92, 189, 93 },
				{ 175, 93, 189 },
				{ 91, 190, 92 },
				{ 189, 92, 190 },
				{ 190, 91, 90 },
				{ 233, 87, 232 },
				{ 225, 230, 88 },
				{ 213, 87, 233 },
				{ 88, 89, 225 },
				{ 87, 235, 232 },
				{ 180, 244, 245 },
				{ 180, 245, 246 },
				{ 243, 248, 202 },
				{ 251, 244, 180 },
				{ 297, 286, 180 },
				{ 17, 520, 192 },
				{ 257, 230, 256 },
				{ 230, 261, 256 },
				{ 176, 178, 243 },
				{ 186, 185, 4 },
				{ 4, 185, 194 },
				{ 257, 262, 230 },
				{ 262, 172, 230 },
				{ 172, 165, 230 },
				{ 264, 225, 263 },
				{ 6, 3, 193 },
				{ 43, 193, 3 },
				{ 263, 225, 174 },
				{ 154, 42, 14 },
				{ 42, 11, 14 },
				{ 154, 14, 147 },
				{ 15, 147, 14 },
				{ 193, 149, 6 },
				{ 264, 270, 225 },
				{ 181, 180, 273 },
				{ 273, 268, 181 },
				{ 275, 261, 230 },
				{ 275, 230, 225 },
				{ 270, 275, 225 },
				{ 180, 181, 295 },
				{ 281, 279, 280 },
				{ 181, 267, 295 },
				{ 282, 280, 279 },
				{ 180, 295, 297 },
				{ 292, 295, 284 },
				{ 265, 267, 181 },
				{ 286, 297, 294 },
				{ 292, 299, 295 },
				{ 300, 295, 301 },
				{ 301, 295, 299 },
				{ 297, 302, 294 },
				{ 300, 303, 295 },
				{ 302, 297, 303 },
				{ 295, 303, 297 },
				{ 319, 176, 305 },
				{ 308, 319, 309 },
				{ 309, 311, 308 },
				{ 311, 309, 248 },
				{ 202, 248, 309 },
				{ 305, 202, 309 },
				{ 313, 314, 312 },
				{ 143, 312, 142 },
				{ 140, 142, 312 },
				{ 312, 143, 316 },
				{ 318, 319, 320 },
				{ 321, 319, 318 },
				{ 176, 319, 321 },
				{ 176, 321, 178 },
				{ 202, 305, 176 },
				{ 305, 309, 319 },
				{ 320, 319, 308 },
				{ 316, 313, 312 },
				{ 329, 326, 331 },
				{ 277, 326, 329 },
				{ 336, 335, 337 },
				{ 279, 338, 282 },
				{ 326, 335, 336 },
				{ 331, 326, 336 },
				{ 277, 276, 338 },
				{ 277, 338, 279 },
				{ 279, 335, 326 },
				{ 277, 279, 326 },
				{ 340, 312, 339 },
				{ 314, 339, 312 },
				{ 151, 340, 341 },
				{ 340, 342, 341 },
				{ 339, 342, 340 },
				{ 312, 340, 151 },
				{ 140, 312, 151 },
				{ 277, 329, 276 },
				{ 279, 281, 343 },
				{ 337, 335, 343 },
				{ 335, 279, 343 },
				{ 352, 357, 351 },
				{ 212, 5, 61 },
				{ 58, 61, 5 },
				{ 354, 514, 353 },
				{ 212, 4, 5 },
				{ 353, 351, 356 },
				{ 186, 4, 212 },
				{ 355, 356, 351 },
				{ 355, 351, 357 },
				{ 357, 352, 358 },
				{ 359, 358, 352 },
				{ 362, 115, 94 },
				{ 370, 516, 138 },
				{ 137, 138, 134 },
				{ 94, 487, 362 },
				{ 405, 403, 406 },
				{ 406, 403, 383 },
				{ 409, 408, 407 },
				{ 410, 412, 407 },
				{ 404, 411, 387 },
				{ 409, 407, 412 },
				{ 412, 410, 413 },
				{ 415, 416, 412 },
				{ 415, 412, 413 },
				{ 419, 420, 418 },
				{ 420, 470, 418 },
				{ 368, 382, 512 },
				{ 421, 456, 418 },
				{ 422, 420, 419 },
				{ 427, 429, 425 },
				{ 425, 428, 426 },
				{ 428, 425, 429 },
				{ 429, 427, 430 },
				{ 422, 419, 431 },
				{ 432, 90, 424 },
				{ 435, 436, 434 },
				{ 433, 434, 436 },
				{ 440, 407, 439 },
				{ 95, 169, 424 },
				{ 438, 435, 437 },
				{ 434, 437, 435 },
				{ 363, 424, 364 },
				{ 408, 439, 407 },
				{ 364, 424, 365 },
				{ 441, 455, 456 },
				{ 430, 438, 429 },
				{ 437, 429, 438 },
				{ 366, 424, 363 },
				{ 425, 426, 443 },
				{ 442, 443, 426 },
				{ 466, 419, 465 },
				{ 442, 445, 443 },
				{ 445, 447, 443 },
				{ 467, 450, 419 },
				{ 444, 443, 447 },
				{ 446, 444, 447 },
				{ 418, 459, 419 },
				{ 423, 456, 421 },
				{ 465, 419, 459 },
				{ 448, 449, 433 },
				{ 448, 433, 436 },
				{ 360, 381, 361 },
				{ 361, 371, 367 },
				{ 431, 419, 450 },
				{ 448, 446, 447 },
				{ 448, 447, 449 },
				{ 452, 440, 451 },
				{ 439, 451, 440 },
				{ 366, 369, 424 },
				{ 477, 456, 455 },
				{ 423, 441, 456 },
				{ 457, 488, 453 },
				{ 453, 458, 454 },
				{ 459, 418, 456 },
				{ 464, 460, 415 },
				{ 416, 415, 460 },
				{ 368, 87, 376 },
				{ 451, 461, 462 },
				{ 451, 462, 452 },
				{ 360, 375, 374 },
				{ 462, 461, 464 },
				{ 463, 464, 461 },
				{ 464, 463, 460 },
				{ 376, 377, 368 },
				{ 466, 467, 419 },
				{ 382, 368, 379 },
				{ 417, 418, 470 },
				{ 471, 417, 470 },
				{ 360, 378, 375 },
				{ 471, 470, 474 },
				{ 472, 474, 470 },
				{ 432, 373, 372 },
				{ 474, 472, 476 },
				{ 475, 476, 472 },
				{ 455, 478, 477 },
				{ 480, 477, 479 },
				{ 478, 479, 477 },
				{ 381, 360, 374 },
				{ 482, 480, 481 },
				{ 479, 481, 480 },
				{ 481, 476, 475 },
				{ 481, 475, 482 },
				{ 371, 361, 381 },
				{ 369, 380, 424 },
				{ 373, 432, 380 },
				{ 424, 380, 432 },
				{ 376, 87, 213 },
				{ 377, 379, 368 },
				{ 458, 453, 488 },
				{ 488, 457, 489 },
				{ 487, 94, 134 },
				{ 492, 493, 491 },
				{ 490, 491, 493 },
				{ 386, 385, 487 },
				{ 385, 362, 487 },
				{ 495, 492, 494 },
				{ 491, 494, 492 },
				{ 405, 414, 403 },
				{ 411, 404, 414 },
				{ 403, 414, 404 },
				{ 404, 360, 403 },
				{ 360, 361, 403 },
				{ 402, 516, 370 },
				{ 497, 161, 496 },
				{ 506, 496, 161 },
				{ 496, 498, 497 },
				{ 367, 384, 361 },
				{ 384, 403, 361 },
				{ 403, 384, 383 },
				{ 163, 498, 40 },
				{ 496, 40, 498 },
				{ 499, 500, 488 },
				{ 499, 488, 489 },
				{ 506, 40, 496 },
				{ 499, 495, 500 },
				{ 494, 500, 495 },
				{ 501, 502, 503 },
				{ 501, 503, 504 },
				{ 454, 502, 453 },
				{ 501, 453, 502 },
				{ 388, 386, 487 },
				{ 509, 505, 493 },
				{ 516, 116, 389 },
				{ 487, 389, 388 },
				{ 360, 404, 378 },
				{ 387, 378, 404 },
				{ 161, 390, 506 },
				{ 503, 507, 508 },
				{ 503, 508, 504 },
				{ 511, 505, 509 },
				{ 490, 493, 505 },
				{ 509, 508, 507 },
				{ 509, 507, 511 },
				{ 40, 510, 113 },
				{ 399, 113, 510 },
				{ 400, 399, 510 },
				{ 368, 512, 513 },
				{ 87, 368, 513 },
				{ 391, 235, 513 },
				{ 400, 510, 506 },
				{ 512, 394, 513 },
				{ 515, 352, 514 },
				{ 351, 514, 352 },
				{ 392, 514, 354 },
				{ 351, 353, 514 },
				{ 352, 515, 359 },
				{ 393, 359, 515 },
				{ 87, 513, 235 },
				{ 395, 394, 512 },
				{ 391, 513, 394 },
				{ 382, 395, 512 },
				{ 392, 396, 514 },
				{ 396, 397, 514 },
				{ 400, 506, 390 },
				{ 515, 398, 393 },
				{ 515, 514, 398 },
				{ 397, 398, 514 },
				{ 134, 138, 516 },
				{ 401, 516, 402 },
				{ 516, 487, 134 },
				{ 160, 155, 516 },
				{ 160, 516, 401 },
				{ 156, 162, 40 },
				{ 516, 389, 487 },
				{ 116, 516, 155 },
				{ 3, 11, 521 },
				{ 521, 520, 3 },
				{ 520, 17, 3 },
				{ 11, 42, 521 },
				{ 5, 521, 62 },
				{ 194, 192, 4 },
				{ 4, 192, 520 },
				{ 214, 97, 96 },
				{ 214, 96, 215 },
				{ 520, 521, 4 },
				{ 5, 4, 521 },
				{ 220, 219, 98 },
				{ 99, 98, 219 },
				{ 100, 218, 101 },
				{ 217, 101, 218 },
				{ 218, 100, 99 },
				{ 218, 99, 219 },
				{ 11, 3, 523 },
				{ 522, 523, 3 },
				{ 14, 11, 523 },
				{ 14, 523, 15 },
				{ 104, 97, 221 },
				{ 214, 221, 97 },
				{ 3, 6, 522 },
				{ 19, 522, 6 },
				{ 105, 104, 222 },
				{ 221, 222, 104 },
				{ 223, 215, 96 },
				{ 223, 96, 106 },
				{ 106, 107, 223 },
				{ 224, 223, 107 },
				{ 217, 226, 108 },
				{ 217, 108, 101 },
				{ 224, 107, 226 },
				{ 108, 226, 107 },
				{ 109, 228, 110 },
				{ 227, 110, 228 },
				{ 109, 111, 229 },
				{ 109, 229, 228 },
				{ 112, 110, 231 },
				{ 227, 231, 110 },
				{ 117, 112, 234 },
				{ 231, 234, 112 },
				{ 238, 237, 124 },
				{ 238, 124, 123 },
				{ 237, 242, 139 },
				{ 237, 139, 124 },
				{ 240, 239, 119 },
				{ 121, 119, 239 },
				{ 121, 239, 238 },
				{ 121, 238, 123 },
				{ 234, 247, 117 },
				{ 141, 117, 247 },
				{ 119, 128, 240 },
				{ 241, 240, 128 },
				{ 247, 249, 148 },
				{ 247, 148, 141 },
				{ 241, 128, 126 },
				{ 241, 126, 236 },
				{ 236, 126, 139 },
				{ 236, 139, 242 },
				{ 249, 252, 182 },
				{ 249, 182, 148 },
				{ 197, 183, 253 },
				{ 252, 253, 183 },
				{ 252, 183, 182 },
				{ 255, 254, 187 },
				{ 188, 187, 254 },
				{ 187, 195, 258 },
				{ 187, 258, 255 },
				{ 254, 229, 188 },
				{ 111, 188, 229 },
				{ 195, 197, 259 },
				{ 195, 259, 258 },
				{ 197, 253, 259 },
			},
		},
		{
			name = "obj_0_color_10988977",
			sourceObject = "obj_0",
			color = Color3.new(0.6549019607843137, 0.6784313725490196, 0.6941176470588235),
			rectangles = {
				{
					center = Vector3.new(0.1364, 19.643, 31.7982),
					size = Vector3.new(31.1864, 35.5752, 0),
					right = Vector3.new(0, 0, -1),
					up = Vector3.new(-1, 0, 0),
					faces = { 69, 91 },
				},
				{
					center = Vector3.new(-1.238, -11.344, 35.93),
					size = Vector3.new(9.764, 28.148, 0),
					right = Vector3.new(0, 1, 0),
					up = Vector3.new(1, 0, 0),
					faces = { 7, 8 },
				},
				{
					center = Vector3.new(12.836, -6.5482, 28.836),
					size = Vector3.new(0.1724, 0.002, 0),
					right = Vector3.new(0, 1, 0),
					up = Vector3.new(0, 0, -1),
					faces = { 51, 52 },
				},
				{
					center = Vector3.new(-15.312, -11.344, 32.3825),
					size = Vector3.new(9.764, 7.095, 0),
					right = Vector3.new(0, 1, 0),
					up = Vector3.new(0, 0, 1),
					faces = { 57, 58 },
				},
				{
					center = Vector3.new(-59.739, 1.7085, 0.737),
					size = Vector3.new(35.869, 0.076, 0),
					right = Vector3.new(0, 1, 0),
					up = Vector3.new(1, 0, 0),
					faces = { 127, 128 },
				},
			},
			faces = {
				{ 7, 8, 9 },
				{ 7, 9, 10 },
				{ 10, 13, 7 },
				{ 12, 7, 13 },
				{ 82, 80, 79 },
				{ 84, 81, 9 },
				{ 204, 203, 205 },
				{ 205, 203, 206 },
				{ 208, 209, 229 },
				{ 214, 215, 209 },
				{ 215, 231, 227 },
				{ 216, 217, 218 },
				{ 216, 218, 219 },
				{ 216, 219, 220 },
				{ 214, 209, 221 },
				{ 222, 221, 209 },
				{ 207, 253, 217 },
				{ 226, 217, 252 },
				{ 209, 215, 227 },
				{ 228, 209, 227 },
				{ 229, 209, 228 },
				{ 234, 231, 215 },
				{ 234, 215, 247 },
				{ 238, 239, 237 },
				{ 236, 237, 239 },
				{ 240, 241, 239 },
				{ 236, 239, 241 },
				{ 242, 237, 236 },
				{ 215, 223, 247 },
				{ 223, 224, 249 },
				{ 224, 226, 249 },
				{ 252, 249, 226 },
				{ 207, 217, 216 },
				{ 249, 247, 223 },
				{ 252, 217, 253 },
				{ 255, 208, 254 },
				{ 255, 258, 208 },
				{ 229, 254, 208 },
				{ 207, 208, 258 },
				{ 207, 258, 259 },
				{ 253, 207, 259 },
				{ 207, 196, 199 },
				{ 207, 199, 203 },
				{ 103, 102, 216 },
				{ 216, 102, 207 },
				{ 102, 196, 207 },
				{ 198, 206, 199 },
				{ 203, 199, 206 },
				{ 266, 209, 201 },
				{ 205, 201, 209 },
				{ 220, 98, 103 },
				{ 220, 103, 216 },
				{ 209, 266, 222 },
				{ 105, 222, 266 },
				{ 205, 206, 201 },
				{ 198, 201, 206 },
				{ 203, 208, 207 },
				{ 204, 208, 203 },
				{ 334, 82, 79 },
				{ 334, 79, 333 },
				{ 81, 13, 10 },
				{ 173, 13, 81 },
				{ 508, 407, 33 },
				{ 10, 9, 81 },
				{ 9, 82, 469 },
				{ 84, 9, 484 },
				{ 9, 415, 509 },
				{ 493, 208, 509 },
				{ 334, 333, 473 },
				{ 205, 82, 204 },
				{ 208, 448, 209 },
				{ 493, 492, 208 },
				{ 436, 209, 448 },
				{ 453, 80, 443 },
				{ 425, 80, 427 },
				{ 427, 80, 430 },
				{ 438, 80, 435 },
				{ 438, 430, 80 },
				{ 443, 444, 489 },
				{ 444, 446, 489 },
				{ 34, 33, 8 },
				{ 435, 209, 436 },
				{ 508, 509, 415 },
				{ 489, 457, 443 },
				{ 8, 33, 9 },
				{ 457, 453, 443 },
				{ 407, 440, 33 },
				{ 407, 508, 410 },
				{ 448, 208, 492 },
				{ 492, 495, 448 },
				{ 519, 473, 333 },
				{ 410, 508, 413 },
				{ 499, 446, 495 },
				{ 413, 508, 415 },
				{ 448, 495, 446 },
				{ 499, 489, 446 },
				{ 417, 33, 418 },
				{ 425, 443, 80 },
				{ 452, 462, 418 },
				{ 209, 82, 205 },
				{ 440, 452, 33 },
				{ 418, 33, 452 },
				{ 462, 9, 418 },
				{ 423, 421, 9 },
				{ 441, 423, 9 },
				{ 415, 9, 464 },
				{ 209, 435, 80 },
				{ 82, 209, 80 },
				{ 421, 418, 9 },
				{ 82, 9, 204 },
				{ 464, 9, 462 },
				{ 208, 204, 9 },
				{ 9, 509, 208 },
				{ 474, 476, 33 },
				{ 476, 481, 33 },
				{ 33, 481, 9 },
				{ 417, 471, 33 },
				{ 474, 33, 471 },
				{ 479, 478, 9 },
				{ 455, 441, 9 },
				{ 478, 455, 9 },
				{ 481, 479, 9 },
				{ 33, 80, 501 },
				{ 453, 501, 80 },
				{ 501, 504, 33 },
				{ 508, 33, 504 },
				{ 8, 7, 34 },
				{ 12, 34, 7 },
				{ 473, 468, 82 },
				{ 473, 82, 334 },
				{ 484, 9, 469 },
				{ 468, 469, 82 },
			},
		},
		{
			name = "obj_0_color_14541540",
			sourceObject = "obj_0",
			color = Color3.new(0.8666666666666667, 0.8862745098039215, 0.8941176470588236),
			rectangles = {
				{
					center = Vector3.new(-20.0935, -52.675, 6.6355),
					size = Vector3.new(0.654, 0.707956213, 0),
					right = Vector3.new(0, -1, 0),
					up = Vector3.new(-0.453417872, 0, -0.891298061),
					faces = { 19, 20 },
				},
				{
					center = Vector3.new(-19.8775, -52.675, 7.3005),
					size = Vector3.new(0.654, 0.707758433, 0),
					right = Vector3.new(0, -1, 0),
					up = Vector3.new(-0.156833172, 0, -0.987625109),
					faces = { 21, 22 },
				},
				{
					center = Vector3.new(-19.8775, -52.675, 8),
					size = Vector3.new(0.654, 0.708746076, 0),
					right = Vector3.new(0, -1, 0),
					up = Vector3.new(0.156614624, 0, -0.987659789),
					faces = { 23, 24 },
				},
				{
					center = Vector3.new(-20.0935, -52.675, 8.665),
					size = Vector3.new(0.654, 0.707065061, 0),
					right = Vector3.new(0, -1, 0),
					up = Vector3.new(0.45398934, 0, -0.891007115),
					faces = { 25, 26 },
				},
				{
					center = Vector3.new(-20.5045, -52.675, 9.2305),
					size = Vector3.new(0.654, 0.708520995, 0),
					right = Vector3.new(0, 1, 0),
					up = Vector3.new(-0.707106781, 0, 0.707106781),
					faces = { 27, 54, 55 },
				},
				{
					center = Vector3.new(-22.4345, -52.675, 9.8575),
					size = Vector3.new(0.654, 0.707758433, 0),
					right = Vector3.new(0, 1, 0),
					up = Vector3.new(-0.987625109, 0, -0.156833172),
					faces = { 28, 29 },
				},
				{
					center = Vector3.new(-23.0995, -52.675, 9.6415),
					size = Vector3.new(0.707956213, 0.654, 0),
					right = Vector3.new(-0.891298061, 0, -0.453417872),
					up = Vector3.new(0, -1, 0),
					faces = { 30, 31 },
				},
				{
					center = Vector3.new(-23.6655, -52.675, 9.2305),
					size = Vector3.new(0.708520995, 0.654, 0),
					right = Vector3.new(-0.707106781, 0, -0.707106781),
					up = Vector3.new(0, -1, 0),
					faces = { 32, 33 },
				},
				{
					center = Vector3.new(-24.0765, -52.675, 8.665),
					size = Vector3.new(0.707065061, 0.654, 0),
					right = Vector3.new(-0.45398934, 0, -0.891007115),
					up = Vector3.new(0, -1, 0),
					faces = { 34, 35 },
				},
				{
					center = Vector3.new(-24.2925, -52.675, 8),
					size = Vector3.new(0.708746076, 0.654, 0),
					right = Vector3.new(-0.156614624, 0, -0.987659789),
					up = Vector3.new(0, -1, 0),
					faces = { 36, 37 },
				},
				{
					center = Vector3.new(-24.2925, -52.675, 7.3005),
					size = Vector3.new(0.654, 0.707758433, 0),
					right = Vector3.new(0, 1, 0),
					up = Vector3.new(0.156833172, 0, -0.987625109),
					faces = { 38, 39 },
				},
				{
					center = Vector3.new(-24.0765, -52.675, 6.6355),
					size = Vector3.new(0.707956213, 0.654, 0),
					right = Vector3.new(0.453417872, 0, -0.891298061),
					up = Vector3.new(0, -1, 0),
					faces = { 40, 41 },
				},
				{
					center = Vector3.new(-23.6655, -52.675, 6.07),
					size = Vector3.new(0.654, 0.707814241, 0),
					right = Vector3.new(0, -1, 0),
					up = Vector3.new(-0.707812828, 0, 0.706400028),
					faces = { 42, 43 },
				},
				{
					center = Vector3.new(-23.0995, -52.675, 5.659),
					size = Vector3.new(0.654, 0.708410192, 0),
					right = Vector3.new(0, -1, 0),
					up = Vector3.new(-0.89072688, 0, 0.454538915),
					faces = { 44, 45 },
				},
				{
					center = Vector3.new(-22.4345, -52.675, 5.443),
					size = Vector3.new(0.654, 0.707602289, 0),
					right = Vector3.new(0, -1, 0),
					up = Vector3.new(-0.987843045, 0, 0.155454556),
					faces = { 46, 47 },
				},
				{
					center = Vector3.new(-21.7355, -52.675, 5.443),
					size = Vector3.new(0.654, 0.707602289, 0),
					right = Vector3.new(0, -1, 0),
					up = Vector3.new(-0.987843045, 0, -0.155454556),
					faces = { 48, 49 },
				},
				{
					center = Vector3.new(-21.0705, -52.675, 5.659),
					size = Vector3.new(0.654, 0.708410192, 0),
					right = Vector3.new(0, -1, 0),
					up = Vector3.new(-0.89072688, 0, -0.454538915),
					faces = { 50, 51 },
				},
				{
					center = Vector3.new(-20.5045, -52.675, 6.07),
					size = Vector3.new(0.707814241, 0.654, 0),
					right = Vector3.new(0.707812828, 0, 0.706400028),
					up = Vector3.new(0, -1, 0),
					faces = { 52, 53 },
				},
				{
					center = Vector3.new(-21.0705, -52.675, 9.6415),
					size = Vector3.new(0.707956213, 0.654, 0),
					right = Vector3.new(-0.891298061, 0, 0.453417872),
					up = Vector3.new(0, -1, 0),
					faces = { 56, 57 },
				},
				{
					center = Vector3.new(-21.7355, -52.675, 9.8575),
					size = Vector3.new(0.707758433, 0.654, 0),
					right = Vector3.new(-0.987625109, 0, 0.156833172),
					up = Vector3.new(0, -1, 0),
					faces = { 58, 59 },
				},
			},
			faces = {
				{ 26, 39, 25 },
				{ 29, 30, 25 },
				{ 24, 25, 30 },
				{ 39, 26, 38 },
				{ 29, 25, 39 },
				{ 36, 38, 26 },
				{ 36, 26, 45 },
				{ 36, 45, 46 },
				{ 36, 46, 47 },
				{ 36, 47, 48 },
				{ 36, 48, 49 },
				{ 36, 49, 50 },
				{ 36, 50, 51 },
				{ 36, 51, 52 },
				{ 36, 52, 53 },
				{ 36, 53, 54 },
				{ 36, 54, 55 },
				{ 36, 55, 56 },
				{ 278, 30, 29 },
				{ 278, 29, 274 },
				{ 86, 24, 30 },
				{ 86, 30, 278 },
				{ 283, 25, 24 },
				{ 283, 24, 86 },
				{ 288, 26, 25 },
				{ 288, 25, 283 },
				{ 26, 288, 289 },
				{ 47, 269, 291 },
				{ 47, 291, 48 },
				{ 291, 293, 49 },
				{ 291, 49, 48 },
				{ 293, 296, 50 },
				{ 293, 50, 49 },
				{ 296, 298, 51 },
				{ 296, 51, 50 },
				{ 298, 37, 52 },
				{ 298, 52, 51 },
				{ 52, 37, 304 },
				{ 52, 304, 53 },
				{ 304, 306, 54 },
				{ 304, 54, 53 },
				{ 307, 55, 54 },
				{ 307, 54, 306 },
				{ 310, 56, 55 },
				{ 310, 55, 307 },
				{ 287, 36, 56 },
				{ 287, 56, 310 },
				{ 315, 38, 36 },
				{ 315, 36, 287 },
				{ 317, 39, 38 },
				{ 317, 38, 315 },
				{ 317, 274, 39 },
				{ 29, 39, 274 },
				{ 26, 289, 45 },
				{ 322, 45, 289 },
				{ 322, 323, 46 },
				{ 322, 46, 45 },
				{ 323, 269, 47 },
				{ 323, 47, 46 },
			},
		},
	},
}

end
dependencies.CashRegisterGeometry = loadCashRegisterGeometry()
local function loadShopDesk()
	local ImportedModel = dependencies.ImportedModel
local DeskGeometry = dependencies.ShopDeskGeometry
local RegisterGeometry = dependencies.CashRegisterGeometry

local ShopDesk = {}
local VERSION = 4
local DESK_WIDTH = 7.5
local DESK_HEIGHT = 64 * DESK_WIDTH / 160
local REGISTER_WIDTH = 1.8
local rgb = Color3.fromRGB
local M = Enum.Material
local DESK_APPEARANCE = {
	obj_0 = { color = rgb(105, 69, 43), material = M.Wood },
	obj_1 = { color = rgb(74, 46, 30), material = M.Wood },
	obj_2 = { color = rgb(137, 97, 62), material = M.Wood },
	obj_3 = { color = rgb(137, 97, 62), material = M.Wood },
	obj_4 = { color = rgb(176, 137, 68), material = M.Metal },
	obj_5 = { color = rgb(176, 137, 68), material = M.Metal },
}
local REGISTER_APPEARANCE = {
	obj_0_color_2829873 = { color = rgb(48, 58, 62), material = M.Metal },
	obj_0_color_6383466 = { color = rgb(55, 107, 112), material = M.Metal },
	obj_0_color_10988977 = { color = rgb(181, 190, 187), material = M.Metal },
	obj_0_color_14541540 = { color = rgb(235, 227, 205), material = M.SmoothPlastic },
}

function ShopDesk.build(parent: Instance, frame: CFrame): Model
	local desk = ImportedModel.build(parent, frame, DeskGeometry, {
		name = "ShopDesk",
		sourceName = "Ingenious Lappi",
		version = VERSION,
		width = DESK_WIDTH,
		appearance = DESK_APPEARANCE,
	})
	-- Local +Z is the desk's front (the supplied cabinet handles). Viewed
	-- from that front, -X is the left side. Both models share that facing.
	ImportedModel.build(desk, frame * CFrame.new(-0.31 * DESK_WIDTH, DESK_HEIGHT, 0), RegisterGeometry, {
		name = "CashRegister",
		sourceName = "Cash Register",
		version = VERSION,
		width = REGISTER_WIDTH,
		canCollide = false,
		appearance = REGISTER_APPEARANCE,
	})
	return desk
end

ShopDesk.WIDTH = DESK_WIDTH
ShopDesk.HEIGHT = DESK_HEIGHT
ShopDesk.DEPTH = 65 * DESK_WIDTH / 160
-- Turn counterclockwise as seen from above. The end meets the front
-- window sill's inside edge (z=14.425) without clipping its stone lip.
-- Customers stand on the desk's local -Z side, facing the shopkeeper.
function ShopDesk.frame(houseFrame: CFrame): CFrame
	return houseFrame * CFrame.new(16, 0.16, 14.425 - DESK_WIDTH / 2) * CFrame.Angles(0, math.pi / 2, 0)
end

function ShopDesk.ensure(shop: Model, houseFrame: CFrame)
	local existing = shop:FindFirstChild("ShopDesk")
	local register = existing and existing:FindFirstChild("CashRegister")
	if
		existing
		and existing:IsA("Model")
		and existing:GetAttribute("ModelVersion") == VERSION
		and existing:GetAttribute("SourceHash") == DeskGeometry.sourceHash
		and register
		and register:IsA("Model")
		and register:GetAttribute("ModelVersion") == VERSION
		and register:GetAttribute("SourceHash") == RegisterGeometry.sourceHash
	then
		return
	end
	if existing then
		existing:Destroy()
	end
	ShopDesk.build(shop, ShopDesk.frame(houseFrame))
end

return ShopDesk

end
dependencies.ShopDesk = loadShopDesk()
local function loadFishFreezerGeometry()
	-- Generated by node scripts/import-fish-freezer.cjs; edit the source OBJ/MTL instead.
-- Source: Smashing Elzing-Habbi.zip; SHA-256 (OBJ + MTL): 5b1c95f22fbaf0e9f9881839a05451c630f61137f76c6b1d3e53ac168b4122c1
-- Original Tinkercad coordinates; Z is up. Every source object and face is retained.
return {
	boundsMin = Vector3.new(-77, -15, 0),
	boundsMax = Vector3.new(73, 45.015, 66.9999),
	sourceHash = "5b1c95f22fbaf0e9f9881839a05451c630f61137f76c6b1d3e53ac168b4122c1",
	vertices = {
		Vector3.new(-74.003, -15, 40),
		Vector3.new(-77, -15, 40),
		Vector3.new(-77, 2.579, 59.092),
		Vector3.new(-77, 6.943, 60.872),
		Vector3.new(-77, 11.674, 62.45),
		Vector3.new(-77, 16.726, 63.812),
		Vector3.new(-74.003, 11.674, 62.45),
		Vector3.new(71.003, 22.05, 64.945),
		Vector3.new(73, 45.015, 40),
		Vector3.new(73, 45.015, 66.9999),
		Vector3.new(73, 39.135, 66.87),
		Vector3.new(73, 33.309, 66.482),
		Vector3.new(73, 27.596, 65.838),
		Vector3.new(73, 22.05, 64.945),
		Vector3.new(71.003, 43.003, 66.9555),
		Vector3.new(73, 16.726, 63.812),
		Vector3.new(71.003, 43.003, 40),
		Vector3.new(73, 11.674, 62.45),
		Vector3.new(73, 6.943, 60.872),
		Vector3.new(73, 2.579, 59.092),
		Vector3.new(71.003, 16.726, 63.812),
		Vector3.new(71.003, 2.579, 59.092),
		Vector3.new(71.003, 6.943, 60.872),
		Vector3.new(71.003, 11.674, 62.45),
		Vector3.new(71.003, 27.596, 65.838),
		Vector3.new(71.003, 33.309, 66.482),
		Vector3.new(-77, 22.05, 64.945),
		Vector3.new(71.003, 39.135, 66.87),
		Vector3.new(-77, 27.596, 65.838),
		Vector3.new(-74.003, -1.377, 57.129),
		Vector3.new(-74.003, -4.885, 55.001),
		Vector3.new(-74.003, -7.913, 52.728),
		Vector3.new(-77, 33.309, 66.482),
		Vector3.new(-74.003, -10.431, 50.333),
		Vector3.new(-77, 39.135, 66.87),
		Vector3.new(-74.003, -12.416, 47.838),
		Vector3.new(73, -1.377, 57.129),
		Vector3.new(-74.003, -13.847, 45.268),
		Vector3.new(73, -4.885, 55.001),
		Vector3.new(-74.003, -14.711, 42.647),
		Vector3.new(71.003, -14.711, 42.647),
		Vector3.new(-77, -1.377, 57.129),
		Vector3.new(71.003, -15, 40),
		Vector3.new(-77, 45.015, 66.9999),
		Vector3.new(73, -15, 40),
		Vector3.new(73, -14.711, 42.647),
		Vector3.new(-77, 45.015, 40),
		Vector3.new(73, -7.913, 52.728),
		Vector3.new(73, -10.431, 50.333),
		Vector3.new(73, -12.416, 47.838),
		Vector3.new(73, -13.847, 45.268),
		Vector3.new(-77, -4.885, 55.001),
		Vector3.new(-77, -7.913, 52.728),
		Vector3.new(-77, -14.711, 42.647),
		Vector3.new(-77, -13.847, 45.268),
		Vector3.new(-77, -10.431, 50.333),
		Vector3.new(-74.003, 16.726, 63.812),
		Vector3.new(-77, -12.416, 47.838),
		Vector3.new(-74.003, 6.943, 60.872),
		Vector3.new(71.003, -13.847, 45.268),
		Vector3.new(71.003, -12.416, 47.838),
		Vector3.new(71.003, -10.431, 50.333),
		Vector3.new(71.003, -7.913, 52.728),
		Vector3.new(71.003, -4.885, 55.001),
		Vector3.new(71.003, -1.377, 57.129),
		Vector3.new(-74.003, 2.579, 59.092),
		Vector3.new(-74.003, 43.003, 66.9555),
		Vector3.new(-74.003, 39.135, 66.87),
		Vector3.new(-74.003, 33.309, 66.482),
		Vector3.new(-74.003, 27.596, 65.838),
		Vector3.new(-74.003, 43.003, 40),
		Vector3.new(-74.003, 22.05, 64.945),
		Vector3.new(-74, 44, 40),
		Vector3.new(-74, 44, 57),
		Vector3.new(72, 44, 57),
		Vector3.new(72, 44, 40),
		Vector3.new(-74, -15, 40),
		Vector3.new(72, -15, 40),
		Vector3.new(-75.129, 45, 31.588),
		Vector3.new(-75.129, 33.998, 31.588),
		Vector3.new(-75.129, 33.998, 1.583),
		Vector3.new(-75.129, 45, 1.583),
		Vector3.new(73, 45, 40),
		Vector3.new(73, -15, 40),
		Vector3.new(-77, 45, 40),
		Vector3.new(-77, -15, 40),
		Vector3.new(-41.003, 7.998, 0),
		Vector3.new(69.003, 7.998, 0),
		Vector3.new(-41.003, 45, 0),
		Vector3.new(73, -15, 0),
		Vector3.new(69.003, 45, 0),
		Vector3.new(73, 45, 0),
		Vector3.new(-77, -15, 0),
		Vector3.new(-77, 45, 0),
		Vector3.new(-45.124, 45, 31.588),
		Vector3.new(-45.124, 45, 1.583),
		Vector3.new(69.003, 45, 32.002),
		Vector3.new(-41.003, 45, 32.002),
		Vector3.new(-45.124, 33.998, 31.588),
		Vector3.new(-45.124, 33.998, 1.583),
		Vector3.new(-41.003, 7.998, 32.002),
		Vector3.new(69.003, 7.998, 32.002),
		Vector3.new(63, 21, 20),
		Vector3.new(63, 21, 0),
		Vector3.new(63, 41, 20),
		Vector3.new(63, 41, 0),
		Vector3.new(43, 41, 20),
		Vector3.new(43, 41, 0),
		Vector3.new(43, 21, 20),
		Vector3.new(43, 21, 0),
		Vector3.new(64, 28, 21),
		Vector3.new(64, 28, 0),
		Vector3.new(64, 34, 21),
		Vector3.new(64, 34, 0),
		Vector3.new(42, 34, 21),
		Vector3.new(42, 34, 0),
		Vector3.new(42, 28, 21),
		Vector3.new(42, 28, 0),
		Vector3.new(35.2244, 36.1744, 21),
		Vector3.new(35.2244, 36.1744, 0),
		Vector3.new(31.1324, 40.5625, 21),
		Vector3.new(31.1324, 40.5625, 0),
		Vector3.new(15.0426, 25.5586, 21),
		Vector3.new(15.0426, 25.5586, 0),
		Vector3.new(19.1346, 21.1704, 21),
		Vector3.new(19.1346, 21.1704, 0),
		Vector3.new(39.267, 30.3729, 20),
		Vector3.new(39.267, 30.3729, 0),
		Vector3.new(25.6271, 45, 20),
		Vector3.new(25.6271, 45, 0),
		Vector3.new(11, 31.36, 20),
		Vector3.new(11, 31.36, 0),
		Vector3.new(24.64, 16.733, 20),
		Vector3.new(24.64, 16.733, 0),
		Vector3.new(-7.3609, 21.7247, 21),
		Vector3.new(-7.3609, 21.7247, 0),
		Vector3.new(-1.492, 20.4772, 21),
		Vector3.new(-1.492, 20.4772, 0),
		Vector3.new(3.0821, 41.9965, 21),
		Vector3.new(3.0821, 41.9965, 0),
		Vector3.new(-2.7868, 43.244, 21),
		Vector3.new(-2.7868, 43.244, 0),
		Vector3.new(-14, 24.1582, 20),
		Vector3.new(-14, 24.1582, 0),
		Vector3.new(5.563, 20, 20),
		Vector3.new(5.563, 20, 0),
		Vector3.new(9.7212, 39.563, 20),
		Vector3.new(9.7212, 39.563, 0),
		Vector3.new(-9.8418, 43.7212, 20),
		Vector3.new(-9.8418, 43.7212, 0),
		Vector3.new(-26.5514, 43.3929, 21),
		Vector3.new(-26.5514, 43.3929, 0),
		Vector3.new(-32.3976, 42.0432, 21),
		Vector3.new(-32.3976, 42.0432, 0),
		Vector3.new(-27.4486, 20.6071, 21),
		Vector3.new(-27.4486, 20.6071, 0),
		Vector3.new(-21.6024, 21.9568, 21),
		Vector3.new(-21.6024, 21.9568, 0),
		Vector3.new(-19.5058, 43.9932, 20),
		Vector3.new(-19.5058, 43.9932, 0),
		Vector3.new(-38.9932, 39.4942, 20),
		Vector3.new(-38.9932, 39.4942, 0),
		Vector3.new(-34.4942, 20.0068, 20),
		Vector3.new(-34.4942, 20.0068, 0),
		Vector3.new(-15.0068, 24.5058, 20),
		Vector3.new(-15.0068, 24.5058, 0),
	},
	objects = {
		{
			name = "obj_0",
			color = Color3.new(0.4588235294117647, 0.807843137254902, 0.8588235294117647),
			faces = {
				{ 9, 10, 11 },
				{ 9, 11, 12 },
				{ 9, 12, 13 },
				{ 9, 13, 14 },
				{ 9, 14, 16 },
				{ 9, 16, 18 },
				{ 9, 18, 19 },
				{ 20, 9, 19 },
				{ 8, 21, 16 },
				{ 8, 16, 14 },
				{ 43, 41, 17 },
				{ 22, 23, 17 },
				{ 23, 24, 17 },
				{ 24, 21, 17 },
				{ 8, 17, 21 },
				{ 25, 17, 8 },
				{ 26, 17, 25 },
				{ 28, 17, 26 },
				{ 15, 17, 28 },
				{ 31, 32, 71 },
				{ 32, 34, 71 },
				{ 34, 36, 71 },
				{ 36, 38, 71 },
				{ 38, 40, 71 },
				{ 1, 71, 40 },
				{ 21, 24, 18 },
				{ 21, 18, 16 },
				{ 41, 43, 45 },
				{ 41, 45, 46 },
				{ 3, 47, 42 },
				{ 4, 47, 3 },
				{ 5, 47, 4 },
				{ 6, 47, 5 },
				{ 27, 47, 6 },
				{ 29, 47, 27 },
				{ 33, 47, 29 },
				{ 35, 47, 33 },
				{ 44, 47, 35 },
				{ 2, 54, 47 },
				{ 9, 20, 37 },
				{ 9, 37, 39 },
				{ 9, 39, 48 },
				{ 9, 48, 49 },
				{ 9, 49, 50 },
				{ 9, 50, 51 },
				{ 9, 51, 46 },
				{ 9, 46, 45 },
				{ 42, 52, 31 },
				{ 42, 31, 30 },
				{ 24, 23, 19 },
				{ 24, 19, 18 },
				{ 52, 53, 32 },
				{ 52, 32, 31 },
				{ 23, 22, 20 },
				{ 23, 20, 19 },
				{ 53, 56, 34 },
				{ 53, 34, 32 },
				{ 56, 58, 36 },
				{ 56, 36, 34 },
				{ 6, 5, 7 },
				{ 6, 7, 57 },
				{ 28, 11, 15 },
				{ 11, 10, 15 },
				{ 58, 55, 38 },
				{ 58, 38, 36 },
				{ 28, 26, 12 },
				{ 28, 12, 11 },
				{ 5, 4, 59 },
				{ 5, 59, 7 },
				{ 55, 54, 40 },
				{ 55, 40, 38 },
				{ 60, 17, 41 },
				{ 61, 17, 60 },
				{ 62, 17, 61 },
				{ 63, 17, 62 },
				{ 64, 17, 63 },
				{ 65, 17, 64 },
				{ 22, 17, 65 },
				{ 54, 2, 1 },
				{ 54, 1, 40 },
				{ 26, 25, 13 },
				{ 26, 13, 12 },
				{ 4, 3, 66 },
				{ 4, 66, 59 },
				{ 25, 8, 14 },
				{ 25, 14, 13 },
				{ 30, 66, 42 },
				{ 3, 42, 66 },
				{ 10, 67, 15 },
				{ 9, 47, 10 },
				{ 10, 44, 67 },
				{ 44, 35, 67 },
				{ 68, 67, 35 },
				{ 71, 17, 15 },
				{ 55, 47, 54 },
				{ 58, 47, 55 },
				{ 56, 47, 58 },
				{ 53, 47, 56 },
				{ 52, 47, 53 },
				{ 42, 47, 52 },
				{ 10, 47, 44 },
				{ 35, 33, 69 },
				{ 35, 69, 68 },
				{ 22, 65, 37 },
				{ 22, 37, 20 },
				{ 33, 29, 70 },
				{ 33, 70, 69 },
				{ 71, 9, 17 },
				{ 65, 64, 39 },
				{ 65, 39, 37 },
				{ 67, 71, 15 },
				{ 29, 27, 72 },
				{ 29, 72, 70 },
				{ 64, 63, 48 },
				{ 64, 48, 39 },
				{ 9, 45, 17 },
				{ 63, 62, 49 },
				{ 63, 49, 48 },
				{ 27, 6, 57 },
				{ 27, 57, 72 },
				{ 43, 17, 45 },
				{ 62, 61, 50 },
				{ 62, 50, 49 },
				{ 61, 60, 51 },
				{ 61, 51, 50 },
				{ 67, 68, 71 },
				{ 68, 69, 71 },
				{ 69, 70, 71 },
				{ 70, 72, 71 },
				{ 72, 57, 71 },
				{ 57, 7, 71 },
				{ 7, 59, 71 },
				{ 59, 66, 71 },
				{ 66, 30, 71 },
				{ 30, 31, 71 },
				{ 71, 47, 9 },
				{ 60, 41, 46 },
				{ 60, 46, 51 },
				{ 1, 2, 71 },
				{ 47, 71, 2 },
			},
		},
		{
			name = "obj_1",
			color = Color3.new(0.27450980392156865, 0.7176470588235294, 0.28627450980392155),
			faces = {
				{ 73, 74, 75 },
				{ 73, 75, 76 },
				{ 77, 74, 73 },
				{ 76, 75, 78 },
				{ 73, 76, 78 },
				{ 73, 78, 77 },
				{ 75, 74, 77 },
				{ 75, 77, 78 },
			},
		},
		{
			name = "obj_2",
			color = Color3.new(0.9137254901960784, 0.11372549019607843, 0.17647058823529413),
			faces = {
				{ 79, 80, 81 },
				{ 79, 81, 82 },
				{ 83, 85, 84 },
				{ 88, 90, 87 },
				{ 89, 87, 94 },
				{ 93, 87, 90 },
				{ 91, 92, 88 },
				{ 90, 88, 92 },
				{ 94, 87, 93 },
				{ 93, 90, 86 },
				{ 90, 84, 86 },
				{ 85, 95, 79 },
				{ 82, 96, 94 },
				{ 85, 83, 98 },
				{ 94, 96, 89 },
				{ 98, 89, 96 },
				{ 96, 95, 98 },
				{ 85, 98, 95 },
				{ 91, 97, 92 },
				{ 83, 92, 97 },
				{ 97, 98, 83 },
				{ 82, 94, 79 },
				{ 85, 79, 94 },
				{ 95, 99, 80 },
				{ 95, 80, 79 },
				{ 82, 81, 100 },
				{ 82, 100, 96 },
				{ 80, 99, 100 },
				{ 80, 100, 81 },
				{ 96, 100, 99 },
				{ 96, 99, 95 },
				{ 101, 102, 88 },
				{ 101, 88, 87 },
				{ 97, 102, 101 },
				{ 97, 101, 98 },
				{ 98, 101, 87 },
				{ 98, 87, 89 },
				{ 88, 102, 97 },
				{ 88, 97, 91 },
				{ 84, 90, 92 },
				{ 84, 92, 83 },
				{ 85, 94, 93 },
				{ 85, 93, 86 },
				{ 84, 85, 86 },
			},
		},
		{
			name = "obj_3",
			color = Color3.new(0.6627450980392157, 0.4823529411764706, 0.3137254901960784),
			box = {
				center = Vector3.new(53, 31, 10),
				size = Vector3.new(20, 20, 20),
				right = Vector3.new(0, 0, -1),
				up = Vector3.new(0, 1, 0),
			},
			faces = {
				{ 103, 104, 105 },
				{ 104, 106, 105 },
				{ 107, 108, 109 },
				{ 108, 110, 109 },
				{ 107, 109, 105 },
				{ 109, 103, 105 },
				{ 110, 108, 104 },
				{ 108, 106, 104 },
				{ 109, 110, 103 },
				{ 110, 104, 103 },
				{ 105, 106, 107 },
				{ 106, 108, 107 },
			},
		},
		{
			name = "obj_4",
			color = Color3.new(0.9137254901960784, 0.11372549019607843, 0.17647058823529413),
			box = {
				center = Vector3.new(53, 31, 10.5),
				size = Vector3.new(21, 6, 22),
				right = Vector3.new(0, 0, -1),
				up = Vector3.new(0, 1, 0),
			},
			faces = {
				{ 111, 112, 113 },
				{ 112, 114, 113 },
				{ 115, 116, 117 },
				{ 116, 118, 117 },
				{ 115, 117, 113 },
				{ 117, 111, 113 },
				{ 118, 116, 112 },
				{ 116, 114, 112 },
				{ 117, 118, 111 },
				{ 118, 112, 111 },
				{ 113, 114, 115 },
				{ 114, 116, 115 },
			},
		},
		{
			name = "obj_5",
			color = Color3.new(0.9137254901960784, 0.11372549019607843, 0.17647058823529413),
			box = {
				center = Vector3.new(25.1335, 30.86645, 10.5),
				size = Vector3.new(21, 5.999990467, 22.000038183),
				right = Vector3.new(0, 0, -1),
				up = Vector3.new(-0.682001084, 0.731351162, 0),
			},
			faces = {
				{ 119, 120, 121 },
				{ 120, 122, 121 },
				{ 123, 124, 125 },
				{ 124, 126, 125 },
				{ 123, 125, 121 },
				{ 125, 119, 121 },
				{ 126, 124, 120 },
				{ 124, 122, 120 },
				{ 125, 126, 119 },
				{ 126, 120, 119 },
				{ 121, 122, 123 },
				{ 122, 124, 123 },
			},
		},
		{
			name = "obj_6",
			color = Color3.new(0.6627450980392157, 0.4823529411764706, 0.3137254901960784),
			box = {
				center = Vector3.new(25.13355, 30.8665, 10),
				size = Vector3.new(20, 19.99997316, 19.999900025),
				right = Vector3.new(0, 0, -1),
				up = Vector3.new(-0.681995915, 0.731355981, 0),
			},
			faces = {
				{ 127, 128, 129 },
				{ 128, 130, 129 },
				{ 131, 132, 133 },
				{ 132, 134, 133 },
				{ 131, 133, 129 },
				{ 133, 127, 129 },
				{ 134, 132, 128 },
				{ 132, 130, 128 },
				{ 133, 134, 127 },
				{ 134, 128, 127 },
				{ 129, 130, 131 },
				{ 130, 132, 131 },
			},
		},
		{
			name = "obj_7",
			color = Color3.new(0.9137254901960784, 0.11372549019607843, 0.17647058823529413),
			box = {
				center = Vector3.new(-2.1394, 31.8606, 10.5),
				size = Vector3.new(21, 6.000020288, 22.000060529),
				right = Vector3.new(0, 0, -1),
				up = Vector3.new(0.978146693, -0.207915964, 0),
			},
			faces = {
				{ 135, 136, 137 },
				{ 136, 138, 137 },
				{ 139, 140, 141 },
				{ 140, 142, 141 },
				{ 139, 141, 137 },
				{ 141, 135, 137 },
				{ 142, 140, 136 },
				{ 140, 138, 136 },
				{ 141, 142, 135 },
				{ 142, 136, 135 },
				{ 137, 138, 139 },
				{ 138, 140, 139 },
			},
		},
		{
			name = "obj_8",
			color = Color3.new(0.6627450980392157, 0.4823529411764706, 0.3137254901960784),
			box = {
				center = Vector3.new(-2.1394, 31.8606, 10),
				size = Vector3.new(20, 20.000039906, 20.000039906),
				right = Vector3.new(0, 0, -1),
				up = Vector3.new(0.978148048, -0.207909585, 0),
			},
			faces = {
				{ 143, 144, 145 },
				{ 144, 146, 145 },
				{ 147, 148, 149 },
				{ 148, 150, 149 },
				{ 147, 149, 145 },
				{ 149, 143, 145 },
				{ 150, 148, 144 },
				{ 148, 146, 144 },
				{ 149, 150, 143 },
				{ 150, 144, 143 },
				{ 145, 146, 147 },
				{ 146, 148, 147 },
			},
		},
		{
			name = "obj_9",
			color = Color3.new(0.9137254901960784, 0.11372549019607843, 0.17647058823529413),
			box = {
				center = Vector3.new(-27, 32, 10.5),
				size = Vector3.new(21, 5.999978711, 21.999976914),
				right = Vector3.new(0, 0, -1),
				up = Vector3.new(-0.974370124, -0.224950798, 0),
			},
			faces = {
				{ 151, 152, 153 },
				{ 152, 154, 153 },
				{ 155, 156, 157 },
				{ 156, 158, 157 },
				{ 155, 157, 153 },
				{ 157, 151, 153 },
				{ 158, 156, 152 },
				{ 156, 154, 152 },
				{ 157, 158, 151 },
				{ 158, 152, 151 },
				{ 153, 154, 155 },
				{ 154, 156, 155 },
			},
		},
		{
			name = "obj_10",
			color = Color3.new(0.6627450980392157, 0.4823529411764706, 0.3137254901960784),
			box = {
				center = Vector3.new(-27, 32, 10),
				size = Vector3.new(20, 19.999993994, 19.999993994),
				right = Vector3.new(0, 0, -1),
				up = Vector3.new(-0.974370293, -0.224950068, 0),
			},
			faces = {
				{ 159, 160, 161 },
				{ 160, 162, 161 },
				{ 163, 164, 165 },
				{ 164, 166, 165 },
				{ 163, 165, 161 },
				{ 165, 159, 161 },
				{ 166, 164, 160 },
				{ 164, 162, 160 },
				{ 165, 166, 159 },
				{ 166, 160, 159 },
				{ 161, 162, 163 },
				{ 162, 164, 163 },
			},
		},
	},
}

end
dependencies.FishFreezerGeometry = loadFishFreezerGeometry()
local function loadFishFreezer()
	-- Supplied Tinkercad freezer, scaled for a comfortable shop counter height.
local Geometry = dependencies.FishFreezerGeometry
local ImportedModel = dependencies.ImportedModel

local FishFreezer = {}
local VERSION = 3
local rgb = Color3.fromRGB
local M = Enum.Material
local APPEARANCE = {
	obj_0 = { color = rgb(169, 215, 219), material = M.SmoothPlastic, transparency = 0.58, reflectance = 0.08 },
	obj_1 = { color = rgb(211, 233, 226), material = M.Ice },
	obj_2 = { color = rgb(40, 98, 105), material = M.Metal },
}
-- Salmon portions with cream wrapping, retaining all four supplied packages.
for _, name in { "obj_3", "obj_6", "obj_8", "obj_10" } do
	APPEARANCE[name] = { color = rgb(212, 138, 115), material = M.SmoothPlastic }
end
for _, name in { "obj_4", "obj_5", "obj_7", "obj_9" } do
	APPEARANCE[name] = { color = rgb(236, 224, 196), material = M.Fabric }
end

function FishFreezer.build(parent: Instance, frame: CFrame): Model
	return ImportedModel.build(parent, frame, Geometry, {
		name = "FishFreezer",
		sourceName = "Smashing Elzing-Habbi",
		version = VERSION,
		width = 9,
		origin = Vector3.new(-2, 15, 0),
		appearance = APPEARANCE,
	})
end

-- The left wall keeps both entrances and the central shop aisle clear.
-- Local +Z faces into the shop; the cabinet reaches DEPTH / 2 towards it.
FishFreezer.DEPTH = 3.6
FishFreezer.HEIGHT = 4
function FishFreezer.frame(houseFrame: CFrame): CFrame
	return houseFrame * CFrame.new(-19, 0.16, 7) * CFrame.Angles(0, math.pi / 2, 0)
end

-- The sloped ice bed under the glass (source obj_1) is 40 units high at the
-- front (source y=-15) and rises to 57 at the back (y=44). Source units scale
-- by width / 150 about the build origin (-2, 15, 0).
local UNIT = 9 / 150
local ICE_SLOPE = math.atan2(57 - 40, 44 + 15)
FishFreezer.ICE_X = Vector2.new((-74 + 2) * UNIT, (72 + 2) * UNIT) -- left, right
FishFreezer.ICE_Z = Vector2.new(-(44 - 15) * UNIT, (15 + 15) * UNIT) -- back, front

-- The ice surface at freezer-local (x, z); UpVector is the surface normal.
function FishFreezer.iceSurface(frame: CFrame, x: number, z: number): CFrame
	local back, front = FishFreezer.ICE_Z.X, FishFreezer.ICE_Z.Y
	local height = (40 + (57 - 40) * (front - z) / (front - back)) * UNIT
	return frame * CFrame.new(x, height, z) * CFrame.Angles(ICE_SLOPE, 0, 0)
end

function FishFreezer.ensure(shop: Model, houseFrame: CFrame)
	local existing = shop:FindFirstChild("FishFreezer")
	if existing and existing:IsA("Model") and existing:GetAttribute("ModelVersion") == VERSION then
		return
	end
	if existing then
		existing:Destroy()
	end
	FishFreezer.build(shop, FishFreezer.frame(houseFrame))
end

return FishFreezer

end
dependencies.FishFreezer = loadFishFreezer()
local function loadBaseHouse()
	-- Empty player-base shell. Local +Z is the front; the deck is y=0.
-- The same builder is used for fresh plots and upgrades to a saved map.
local Props = dependencies.Props
local FishFreezer = dependencies.FishFreezer
local ShopDesk = dependencies.ShopDesk

local BaseHouse = {}
local VERSION = 4
local LIGHTING_VERSION = 2
local rgb = Color3.fromRGB
local M = Enum.Material
local PLASTER = rgb(230, 222, 199)
local STONE = rgb(168, 156, 130)
local WOOD = rgb(124, 88, 55)
local DARK_WOOD = rgb(67, 48, 35)
local IRON = rgb(43, 53, 57)
local CREAM = rgb(247, 235, 204)
local TILE = rgb(194, 207, 197)
local TERRACOTTA = rgb(164, 75, 46)

local function model(parent: Instance, name: string): Model
	local result = Instance.new("Model")
	result.Name = name
	result.Parent = parent
	return result
end

-- Furnish saved shells in place, keeping lamps attached to the ceiling ties.
local function ensureLights(house: Model, frame: CFrame)
	for roomName, positions in
		{
			Shop = { Vector3.new(-15, 0, 10), Vector3.new(0, 0, 10), Vector3.new(15, 0, 10) },
			Processing = { Vector3.new(-16, 0, -10), Vector3.new(-4, 0, -10) },
			Storage = { Vector3.new(8, 0, -10), Vector3.new(18, 0, -10) },
		}
	do
		local room = house:FindFirstChild(roomName)
		if not room then
			continue
		end
		local existing = room:FindFirstChild("CeilingLights")
		if existing and existing:GetAttribute("LayoutVersion") == LIGHTING_VERSION then
			continue
		end
		if existing then
			existing:Destroy()
		end
		local lights = model(room, "CeilingLights")
		lights:SetAttribute("LayoutVersion", LIGHTING_VERSION)
		for index, position in positions do
			local fixture = model(lights, "Pendant" .. index)
			local function piece(name: string, size: Vector3, y: number, color: Color3, material: Enum.Material): Part
				local result = Props.part(fixture, size, frame * CFrame.new(position.X, y, position.Z), color, material)
				result.Name = name
				result.CanCollide, result.CanQuery = false, false
				return result
			end
			piece("CeilingMount", Vector3.new(0.65, 0.12, 0.65), 10.82, IRON, M.Metal)
			piece("HangingCord", Vector3.new(0.08, 1.36, 0.08), 10.08, IRON, M.Metal)
			piece("LampShade", Vector3.new(1.8, 0.3, 1.8), 9.25, IRON, M.Metal)
			local bulb = piece("LampGlobe", Vector3.new(0.7, 0.7, 0.7), 8.85, rgb(240, 226, 200), M.SmoothPlastic)
			bulb.Shape = Enum.PartType.Ball
			local glow = Instance.new("PointLight")
			glow.Name = "InteriorLight"
			glow.Color = rgb(255, 237, 209)
			-- Soft interior fill; walls and the shade contain the light instead
			-- of letting every pendant illuminate the outside of the house.
			glow.Brightness = 0.45
			glow.Range = 18
			glow.Shadows = true
			glow.Enabled = true
			glow.Parent = bulb
		end
	end
end

function BaseHouse.build(parent: Instance, frame: CFrame, accent: Color3, index: number): Model
	local house = model(parent, "BaseHouse")
	house:SetAttribute("LayoutVersion", VERSION)
	house:SetAttribute("BaseId", index)
	house:SetAttribute("HouseFrame", frame)
	local shell = model(house, "Shell")
	local shop = model(house, "Shop")
	local processing = model(house, "Processing")
	local storage = model(house, "Storage")
	shop:SetAttribute("RoomType", "Shop")
	processing:SetAttribute("RoomType", "Processing")
	storage:SetAttribute("RoomType", "Storage")

	local function block(
		group: Instance,
		name: string,
		size: Vector3,
		x: number,
		y: number,
		z: number,
		color: Color3,
		material: Enum.Material?,
		rotation: CFrame?,
		decorative: boolean?
	): Part
		local piece =
			Props.part(group, size, frame * CFrame.new(x, y, z) * (rotation or CFrame.identity), color, material)
		piece.Name = name
		if decorative then
			piece.CanCollide = false
			piece.CanQuery = false
		end
		return piece
	end
	local function text(
		group: Instance,
		name: string,
		value: string,
		x: number,
		y: number,
		z: number,
		width: number,
		height: number,
		back: boolean?
	)
		local board = block(group, name, Vector3.new(width, height, 0.16), x, y, z, IRON, M.WoodPlanks, nil, true)
		local gui = Instance.new("SurfaceGui")
		gui.Face = if back then Enum.NormalId.Front else Enum.NormalId.Back
		-- Match the canvas to the physical board so glyphs retain their proportions.
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(math.round(width * 20), math.round(height * 20))
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -24, 1, -12)
		label.Position = UDim2.new(0, 12, 0, 6)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextWrapped = false
		label.TextColor3 = CREAM
		label.Text = value
		label.Parent = gui
	end
	-- Preserve the original room floors and connecting passage.
	local shopFloor = block(shop, "ShopFloor", Vector3.new(45.3, 0.16, 14), 0, 0.08, 7.65, WOOD, M.WoodPlanks)
	block(processing, "WashableFloor", Vector3.new(25.3, 0.16, 15.3), -10, 0.08, -7, TILE, M.CeramicTiles)
	block(storage, "StoreFloor", Vector3.new(19.3, 0.16, 15.3), 13, 0.08, -7, rgb(148, 135, 111), M.Concrete)
	block(shell, "PassageFloor", Vector3.new(0.7, 0.16, 6), 3, 0.08, -7, TILE, M.CeramicTiles)

	-- Wall openings are actual gaps. Windows have thin panes, never a solid hut core.
	type Opening = { x: number, width: number, bottom: number, top: number }
	local function wall(z: number, openings: { Opening }, name: string)
		local cursor = -23
		for _, opening in openings do
			local left, right = opening.x - opening.width / 2, opening.x + opening.width / 2
			if left > cursor then
				block(
					shell,
					name,
					Vector3.new(left - cursor, 11.5, 0.65),
					(cursor + left) / 2,
					5.75,
					z,
					PLASTER,
					M.Plaster
				)
			end
			if opening.bottom > 0 then
				block(
					shell,
					name .. "SillWall",
					Vector3.new(opening.width, opening.bottom, 0.65),
					opening.x,
					opening.bottom / 2,
					z,
					PLASTER,
					M.Plaster
				)
			end
			block(
				shell,
				name .. "Lintel",
				Vector3.new(opening.width, 11.5 - opening.top, 0.65),
				opening.x,
				(11.5 + opening.top) / 2,
				z,
				PLASTER,
				M.Plaster
			)
			cursor = right
		end
		if cursor < 23 then
			block(shell, name, Vector3.new(23 - cursor, 11.5, 0.65), (cursor + 23) / 2, 5.75, z, PLASTER, M.Plaster)
		end
	end
	wall(15, {
		{ x = -13, width = 10, bottom = 3, top = 8.7 },
		{ x = 0, width = 7, bottom = 0, top = 8.8 },
		{ x = 13, width = 10, bottom = 3, top = 8.7 },
	}, "FrontWall")
	wall(-15, {
		{ x = -13, width = 7, bottom = 4, top = 8.3 },
		{ x = 0, width = 6, bottom = 0, top = 8.5 },
		{ x = 13, width = 7, bottom = 4, top = 8.3 },
	}, "RearWall")
	wall(1, {
		{ x = -10, width = 6, bottom = 0, top = 8.5 },
		{ x = 12, width = 6, bottom = 0, top = 8.5 },
	}, "RoomPartition")
	for _, x in { -23, 23 } do
		block(shell, "SideWall", Vector3.new(0.65, 11.5, 30), x, 5.75, 0, PLASTER, M.Plaster)
		block(shell, "SidePlinth", Vector3.new(0.82, 0.75, 30), x, 0.5, 0, STONE, M.Slate)
		block(shell, "EavesBeam", Vector3.new(0.5, 0.55, 32.5), x, 11.4, 0, DARK_WOOD, M.Wood)
		for _, z in { -14.4, 0.5, 14.4 } do
			block(shell, "TimberPost", Vector3.new(0.9, 10.8, 0.9), x * 0.97, 5.4, z, WOOD, M.Wood)
		end
	end
	-- Rear room divider, with a six-stud cross passage at z=-7.
	block(shell, "StorePartitionRear", Vector3.new(0.55, 11.5, 5), 3, 5.75, -12.5, PLASTER, M.Plaster)
	block(shell, "StorePartitionFront", Vector3.new(0.55, 11.5, 5), 3, 5.75, -1.5, PLASTER, M.Plaster)
	block(shell, "StorePassageLintel", Vector3.new(0.55, 3, 6), 3, 10, -7, PLASTER, M.Plaster)

	-- Recessed shop windows, divided lights, deep stone sills, and opened shutters.
	-- Avoid refractive Glass so the sea remains visible through the glazing.
	for _, z in { -15, 15 } do
		local front = z > 0
		local width = if front then 10 else 7
		local bottom, top = if front then 3 else 4, if front then 8.7 else 8.3
		for _, x in { -13, 13 } do
			local glass = block(
				shell,
				"WindowGlass",
				Vector3.new(width, top - bottom, 0.12),
				x,
				(bottom + top) / 2,
				z,
				rgb(105, 165, 175),
				M.SmoothPlastic,
				nil,
				true
			)
			glass.Transparency = 0.68
			for _, dx in { -width / 2, 0, width / 2 } do
				block(
					shell,
					"WindowMullion",
					Vector3.new(0.16, top - bottom + 0.2, 0.32),
					x + dx,
					(bottom + top) / 2,
					z,
					CREAM,
					M.Wood,
					nil,
					true
				)
			end
			for _, y in { bottom, (bottom + top) / 2, top } do
				block(shell, "WindowRail", Vector3.new(width, 0.17, 0.32), x, y, z, CREAM, M.Wood, nil, true)
			end
			block(
				shell,
				"StoneSill",
				Vector3.new(width + 0.6, 0.24, 1.15),
				x,
				bottom - 0.1,
				z,
				STONE,
				M.Slate,
				nil,
				true
			)
			if front then
				for _, side in { -1, 1 } do
					block(
						shell,
						"OpenShutter",
						Vector3.new(1.7, 5.7, 0.3),
						x + side * 6,
						5.85,
						z + 0.65,
						accent,
						M.WoodPlanks,
						CFrame.Angles(0, side * 0.22, 0),
						true
					)
				end
			end
		end
	end
	for _, z in { 15, -15 } do
		local doorWidth = if z > 0 then 7 else 6
		for _, side in { -1, 1 } do
			block(shell, "DoorJamb", Vector3.new(0.28, 8.7, 0.9), side * (doorWidth / 2 + 0.16), 4.35, z, WOOD, M.Wood)
		end
		block(shell, "DoorHeader", Vector3.new(doorWidth + 0.6, 0.3, 0.9), 0, 8.85, z, WOOD, M.Wood)
	end
	block(shell, "EntranceStep", Vector3.new(7, 0.2, 1.8), 0, 0.06, 15.6, STONE, M.Slate)
	block(shell, "FrontApproachStep", Vector3.new(7, 0.4, 2.2), 0, -0.45, 17.6, STONE, M.Slate)
	block(shell, "RearLanding", Vector3.new(7, 0.3, 2.6), 0, 0, -16.2, STONE, M.Slate)
	block(shell, "RearStep", Vector3.new(7, 0.4, 1.8), 0, -0.45, -18.2, STONE, M.Slate)

	-- Pitched terracotta roof, separate rafters, tile courses, ridge caps and gutters.
	local pitch = math.atan2(4.8, 24)
	for _, side in { -1, 1 } do
		local tilt = CFrame.Angles(0, 0, -side * pitch)
		block(shell, "RoofSlope", Vector3.new(24.5, 0.45, 33), side * 12, 14.05, 0, TERRACOTTA, M.RoofShingles, tilt)
		for course = 0, 11 do
			local x = (course + 0.5) * 2
			block(
				shell,
				"TileCourse",
				Vector3.new(0.16, 0.18, 33.1),
				side * x,
				16.68 - x * 0.2,
				0,
				rgb(191, 96, 60),
				M.Brick,
				tilt,
				true
			)
		end
		block(shell, "RainGutter", Vector3.new(0.4, 0.35, 33.4), side * 24.1, 11.6, 0, IRON, M.Metal, nil, true)
	end
	block(shell, "RidgeCap", Vector3.new(0.8, 0.55, 33.4), 0, 16.55, 0, rgb(195, 101, 66), M.Brick)
	for _, z in { -15, 15 } do
		for row = 0, 7 do
			block(shell, "Gable", Vector3.new(45.5 - row * 5.7, 0.6, 0.65), 0, 11.55 + row * 0.6, z, PLASTER, M.Plaster)
		end
		for _, side in { -1, 1 } do
			block(
				shell,
				"BargeBoard",
				Vector3.new(24.5, 0.4, 0.6),
				side * 12,
				14.05,
				z + math.sign(z) * 1.3,
				CREAM,
				M.Wood,
				CFrame.Angles(0, 0, -side * pitch),
				true
			)
		end
	end
	for _, z in { -10, 0, 10 } do
		block(shell, "CeilingTie", Vector3.new(45, 0.45, 0.4), 0, 11.1, z, DARK_WOOD, M.Wood)
	end
	block(shell, "Downpipe", Vector3.new(0.22, 10.8, 0.22), -23.7, 5.8, -13, IRON, M.Metal, nil, true)
	text(shell, "ShopSign", "FISH & TACKLE  /  " .. string.format("%02d", index), 0, 10.45, 15.5, 20, 1.8)
	-- Striped canvas awning above the open entrance.
	for stripe = -5, 5 do
		block(
			shell,
			"AwningStripe",
			Vector3.new(1.65, 0.15, 3.6),
			stripe * 1.65,
			9.2,
			17,
			if stripe % 2 == 0 then accent else CREAM,
			M.Fabric,
			CFrame.Angles(-0.12, 0, 0),
			true
		)
		block(
			shell,
			"AwningValance",
			Vector3.new(1.65, 0.5, 0.12),
			stripe * 1.65,
			8.8,
			18.75,
			if stripe % 2 == 0 then accent else CREAM,
			M.Fabric,
			nil,
			true
		)
	end

	-- The structural floor is the queryable reference for the plot, not an invisible blocker.
	house.PrimaryPart = shopFloor
	FishFreezer.ensure(shop, frame)
	ShopDesk.ensure(shop, frame)
	ensureLights(house, frame)
	Props.simplifyHouseCollision(house)
	return house
end

-- Leave ownership and all boating objects intact when upgrading a baked plot.
function BaseHouse.ensure(base: Model)
	-- Saved plots may already have the current house but still show the old circle.
	local savedPad = base:FindFirstChild("ClaimPad")
	if savedPad and savedPad:IsA("BasePart") then
		for _, child in base:GetChildren() do
			if
				child:IsA("BasePart")
				and (
					child == savedPad
					or (
						child:IsA("Part")
						and child.Shape == Enum.PartType.Cylinder
						and (child.Position - savedPad.Position).Magnitude < 0.5
						and child.Size.Y > 10
					)
				)
			then
				child.Transparency = 1
				child.CanCollide = false
				child.CanTouch = false
				child.CanQuery = false
			end
		end
	end
	local existing = base:FindFirstChild("BaseHouse")
	if existing and existing:GetAttribute("LayoutVersion") == VERSION then
		local sign = existing:FindFirstChild("ShopSign", true)
		local gui = sign and sign:FindFirstChildWhichIsA("SurfaceGui")
		if gui then
			gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
			gui.CanvasSize = Vector2.new(400, 36)
			local label = gui:FindFirstChildWhichIsA("TextLabel", true)
			if label then
				label.TextScaled = true
				label.TextWrapped = false
				label.Size = UDim2.new(1, -24, 1, -12)
				label.Position = UDim2.fromOffset(12, 6)
			end
		end
		local shop = existing:FindFirstChild("Shop")
		local houseFrame = existing:GetAttribute("HouseFrame")
		if shop and shop:IsA("Model") and typeof(houseFrame) == "CFrame" then
			FishFreezer.ensure(shop, houseFrame)
			ShopDesk.ensure(shop, houseFrame)
			ensureLights(existing, houseFrame)
		end
		Props.simplifyHouseCollision(existing)
		return
	end
	local dockFrame = base:GetAttribute("BoatDockFrame")
	local spawn = base:FindFirstChild("SpawnPoint")
	if typeof(dockFrame) ~= "CFrame" and spawn and spawn:IsA("SpawnLocation") then
		-- Original Harbour spawn: cf(-26,4,6.1). Recover before moving it.
		dockFrame = spawn.CFrame * CFrame.new(-4, -6.1, -26)
		base:SetAttribute("BoatDockFrame", dockFrame)
	end
	if typeof(dockFrame) ~= "CFrame" then
		return
	end
	local claim = base:FindFirstChild("ClaimPad")
	local accent = if claim and claim:IsA("BasePart") then claim.Color else rgb(40, 120, 156)
	if existing then
		existing:Destroy()
	end
	for _, child in base:GetChildren() do
		if child.Name == "Hut" or child.Name == "FishRack" or child.Name == "Bench" then
			child:Destroy()
		end
	end
	local frame = dockFrame :: CFrame
	BaseHouse.build(base, frame * CFrame.new(0, 5.9, 43), accent, base:GetAttribute("BaseId") or 1)
	if spawn and spawn:IsA("SpawnLocation") then
		spawn.CFrame = frame * CFrame.new(4, 6.1, 20)
	end
	if claim and claim:IsA("BasePart") then
		-- Keep the original claim ring and pad together on the clear front apron.
		local oldPosition = claim.Position
		local newPosition = (frame * CFrame.new(-12, 6.05, 21)).Position
		for _, child in base:GetChildren() do
			if
				child:IsA("Part")
				and child.Shape == Enum.PartType.Cylinder
				and child ~= claim
				and (child.Position - oldPosition).Magnitude < 0.5
				and child.Size.Y > 10
			then
				child.CFrame += newPosition - oldPosition
			end
		end
		claim.CFrame += newPosition - oldPosition
	end
end

return BaseHouse

end
dependencies.BaseHouse = loadBaseHouse()
local function loadMediterranean()
	-- Mediterranean set dressing for Harbour Isle: whitewashed cube houses, pastel townhouses, villas,
-- domed chapels, windmills, olive and cypress trees, and the fittings of a piazza.
-- Builders follow the Props conventions: a ground position, a facing (front on local +Z), parts in a new Model.

local LowPoly = dependencies.LowPoly
local Props = dependencies.Props

local Med = {}

local TAU = math.pi * 2
local rgb = Color3.fromRGB
local M = Enum.Material
local part, cylinder, beam, blob, ball = Props.part, Props.cylinder, Props.beam, Props.blob, Props.ball
local light, shade, pick = Props.light, Props.shade, Props.pick

local WHITEWASH = rgb(242, 240, 232)
local OFFWHITE = rgb(226, 222, 210)
local AEGEAN = rgb(36, 92, 168)
local TERRACOTTA = rgb(184, 92, 58)
local STONE = rgb(204, 192, 168)
local STONE_WALL = rgb(168, 154, 130)
local IRON = rgb(44, 42, 40)
local BRASS = rgb(186, 148, 70)
local WOOD = rgb(122, 92, 64)
local WOOD_DARK = rgb(78, 60, 46)
local TRUNK = rgb(96, 76, 58)
local OLIVE_BARK = rgb(112, 100, 86)
local LAMP = rgb(255, 210, 140)
local GLASS = rgb(44, 60, 76)
local DIRT = rgb(170, 132, 92)
local LEAF = rgb(70, 104, 56)
local VINE = rgb(84, 122, 58)
local CYPRESS = rgb(46, 72, 50)
local STONE_PINE = rgb(62, 92, 56)
local LAVENDER = rgb(146, 112, 196)
local CANVAS = rgb(240, 234, 218)
local WATER = rgb(78, 160, 178)

Med.WHITEWASH = WHITEWASH
Med.AEGEAN = AEGEAN

local SHUTTERS = { rgb(36, 92, 168), rgb(28, 120, 150), rgb(40, 70, 130), rgb(64, 118, 72), rgb(92, 126, 66) }
local TOWN_SHUTTERS = { rgb(64, 110, 72), rgb(92, 126, 66), rgb(112, 74, 52), rgb(40, 96, 120), rgb(150, 120, 60) }
local PASTELS = {
	rgb(236, 206, 150),
	rgb(232, 176, 140),
	rgb(242, 224, 184),
	rgb(216, 152, 112),
	rgb(246, 234, 204),
	rgb(224, 190, 120),
	rgb(210, 128, 96),
}
local ROOF_TILES = { rgb(184, 92, 58), rgb(166, 80, 52), rgb(196, 110, 70), rgb(150, 70, 48) }
local BLOOMS = { rgb(206, 44, 122), rgb(226, 80, 156), rgb(180, 40, 110), rgb(236, 120, 170) }
local OLIVE_LEAF = { rgb(128, 140, 96), rgb(112, 126, 86), rgb(142, 152, 110) }
local AWNINGS = { rgb(180, 52, 44), rgb(36, 92, 168), rgb(56, 120, 70), rgb(214, 160, 50), rgb(120, 60, 110) }
local SHOPS = { "Taverna", "Bakery", "Caffè", "Fishmonger", "Gelato", "Olive Oil", "Pottery", "Enoteca", "Bottega" }

type Look = {
	frame: Color3,
	shutter: Color3?,
	arched: boolean,
	winW: number,
	winH: number,
	spacing: number,
}

type Facade = {
	floor: number,
	storyH: number,
	stories: number,
	doorX: number?,
	doorGap: number?,
	skipSide: number?,
	extras: ((side: number, story: number, face: CFrame) -> ())?,
}

local function newModel(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

----------------------------------------------------------------------------------------------------
-- Facade pieces

-- Frame on the outer surface of one wall of a w x d block standing on `base`, `y` up from it.
-- Side 0 is the front (+Z), 1 is +X, 2 the back, 3 is -X. +Z of the frame points out of the wall.
local function wallFace(base: CFrame, w: number, d: number, side: number, y: number): (CFrame, number)
	local outward = if side % 2 == 0 then d / 2 else w / 2
	local width = if side % 2 == 0 then w else d
	return base * CFrame.Angles(0, side * math.pi / 2, 0) * CFrame.new(0, y, outward), width
end

-- Upright disc on a wall (arch heads, round windows, clock faces); `face` is its centre.
local function disc(
	m: Model,
	face: CFrame,
	diameter: number,
	thickness: number,
	color: Color3,
	material: Enum.Material
): Part
	local p = cylinder(m, Vector3.zero, thickness, diameter, color, material)
	p.CFrame = face * CFrame.Angles(0, math.pi / 2, 0)
	return p
end

-- Window centred on `face`, with a plaster surround, sill, optional arched head and open shutters.
local function window(
	m: Model,
	face: CFrame,
	width: number,
	height: number,
	frame: Color3,
	shutter: Color3?,
	arched: boolean,
	lit: boolean
): Part
	local color, material = if lit then LAMP else GLASS, if lit then M.Neon else M.Glass
	part(m, Vector3.new(width + 0.8, height + 0.8, 0.12), face * CFrame.new(0, 0, 0.06), frame, M.Plaster)
	local glassDepth = if arched then 0.18 else 0.1
	local glass = part(m, Vector3.new(width, height, 0.2), face * CFrame.new(0, 0, glassDepth), color, material)
	local mullionDepth = if arched then 0.44 else 0.26
	part(m, Vector3.new(0.15, height, mullionDepth), face * CFrame.new(0, 0, mullionDepth / 2), frame, M.Wood)
	if arched then
		-- Overlapping arch, glazing and mullion faces stay 0.08 studs apart.
		disc(m, face * CFrame.new(0, height / 2, 0.14), width + 0.8, 0.12, frame, M.Plaster)
		disc(m, face * CFrame.new(0, height / 2, 0.27), width, 0.18, color, material)
	end
	part(m, Vector3.new(width + 1.4, 0.35, 0.9), face * CFrame.new(0, -height / 2 - 0.35, 0.4), frame, M.Plaster)
	if shutter then
		for flap = -1, 1, 2 do
			part(
				m,
				Vector3.new(width / 2 + 0.1, height + 0.2, 0.15),
				face * CFrame.new(flap * (width * 0.75 + 0.55), 0, 0.1),
				shutter,
				M.WoodPlanks
			)
		end
	end
	return glass
end

-- Door standing on `face` (bottom centre on the wall) with a surround, handle and a stone step.
local function door(
	m: Model,
	face: CFrame,
	width: number,
	height: number,
	color: Color3,
	frame: Color3,
	arched: boolean
): Part
	part(
		m,
		Vector3.new(width + 1, height + 0.5, 0.12),
		face * CFrame.new(0, (height + 0.5) / 2, 0.06),
		frame,
		M.Plaster
	)
	local leaf = part(m, Vector3.new(width, height, 0.3), face * CFrame.new(0, height / 2, 0.15), color, M.WoodPlanks)
	if arched then
		disc(m, face * CFrame.new(0, height + 0.5, 0.14), width + 1, 0.12, frame, M.Plaster)
		disc(m, face * CFrame.new(0, height, 0.25), width, 0.26, color, M.WoodPlanks)
	end
	ball(m, (face * CFrame.new(width * 0.3, height * 0.45, 0.4)).Position, 0.35, BRASS, M.Metal)
	part(m, Vector3.new(width + 2.2, 0.5, 1.8), face * CFrame.new(0, 0.25, 0.9), STONE, M.Limestone)
	return leaf
end

-- Balcony whose floor is level with `face`, with a wrought-iron railing.
local function balcony(m: Model, face: CFrame, width: number, depth: number, slab: Color3)
	part(m, Vector3.new(width, 0.5, depth), face * CFrame.new(0, -0.25, depth / 2), slab, M.Plaster)
	local posts = math.max(3, math.floor(width / 1.1))
	for i = 0, posts do
		local x = -width / 2 + 0.2 + (width - 0.4) * i / posts
		part(m, Vector3.new(0.14, 2.6, 0.14), face * CFrame.new(x, 1.3, depth - 0.2), IRON, M.Metal)
	end
	part(m, Vector3.new(width - 0.2, 0.2, 0.22), face * CFrame.new(0, 2.6, depth - 0.2), IRON, M.Metal)
	for side = -1, 1, 2 do
		part(
			m,
			Vector3.new(0.2, 0.2, depth - 0.2),
			face * CFrame.new(side * (width / 2 - 0.2), 2.6, depth / 2),
			IRON,
			M.Metal
		)
	end
end

local function flowerBox(m: Model, face: CFrame, width: number, rng: Random)
	part(m, Vector3.new(width, 0.8, 0.9), face * CFrame.new(0, 0, 0.6), TERRACOTTA, M.Sandstone)
	for k = 1, 3 do
		local color = if rng:NextNumber() < 0.6 then pick(rng, BLOOMS) else LEAF
		blob(
			m,
			(face * CFrame.new((k - 2) * width / 3.2, 0.6, 0.6)).Position,
			Vector3.new(1.1, 0.9, 0.9),
			rng,
			color,
			M.LeafyGrass
		)
	end
end

-- Windows across every wall of a w x d block. The front ground floor leaves a gap for the door.
local function fenestrate(m: Model, base: CFrame, w: number, d: number, rng: Random, look: Look, facade: Facade)
	local lit = false
	for side = 0, 3 do
		if side == facade.skipSide then
			continue
		end
		local _, width = wallFace(base, w, d, side, 0)
		local n = math.max(1, math.floor(width / look.spacing))
		for s = 1, facade.stories do
			local y = facade.floor + (s - 1) * facade.storyH + facade.storyH * 0.55
			local face = wallFace(base, w, d, side, y)
			for i = 1, n do
				local x = (i - (n + 1) / 2) * width / n
				local gap = facade.doorGap or (look.winW / 2 + 3)
				local skip = if side == 0
					then s == 1 and facade.doorX ~= nil and math.abs(x - facade.doorX) < gap
					else rng:NextNumber() < 0.3
				if not skip then
					local glow = rng:NextNumber() < 0.3
					local at = face * CFrame.new(x, 0, 0)
					local glass = window(m, at, look.winW, look.winH, look.frame, look.shutter, look.arched, glow)
					if glow and not lit then
						light(glass, LAMP, 18, 0.7)
						lit = true
					end
					if facade.extras then
						facade.extras(side, s, at)
					end
				end
			end
		end
	end
end

-- Block with a flat roof: a slab lipped over the walls and a low parapet round the terrace.
local function flatBlock(m: Model, base: CFrame, w: number, d: number, floor: number, h: number, color: Color3)
	part(m, Vector3.new(w, h, d), base * CFrame.new(0, floor + h / 2, 0), color, M.Plaster)
	part(m, Vector3.new(w + 0.6, 0.4, d + 0.6), base * CFrame.new(0, floor + h + 0.2, 0), color, M.Plaster)
	for side = 0, 3 do
		local face, width = wallFace(base, w, d, side, floor + h + 0.9)
		local length = if side % 2 == 0 then width else width - 1.2
		part(m, Vector3.new(length, 1, 0.6), face * CFrame.new(0, 0, -0.3), color, M.Plaster)
	end
end

-- Shallow clay-tile roof with its ridge along local X. Returns how far the ridge rises above `top`.
local function gableRoof(
	m: Model,
	base: CFrame,
	w: number,
	d: number,
	top: number,
	pitch: number,
	roof: Color3,
	gable: Color3
): number
	local rise = d / 2 * math.tan(pitch)
	local slant = (d / 2 + 1.4) / math.cos(pitch)
	for side = -1, 1, 2 do
		part(
			m,
			Vector3.new(w + 2, 0.7, slant),
			base * CFrame.new(0, top + rise / 2, side * d / 4) * CFrame.Angles(side * pitch, 0, 0),
			roof,
			M.ClayRoofTiles
		)
		local x = side * w / 2
		LowPoly.triangle(
			base:PointToWorldSpace(Vector3.new(x, top, -d / 2)),
			base:PointToWorldSpace(Vector3.new(x, top, d / 2)),
			base:PointToWorldSpace(Vector3.new(x, top + rise, 0)),
			base:PointToWorldSpace(Vector3.new(0, top, 0)),
			gable,
			m,
			M.Plaster
		)
	end
	part(
		m,
		Vector3.new(w + 2.2, 0.8, 1),
		base * CFrame.new(0, top + rise + 0.15, 0),
		roof:Lerp(Color3.new(0, 0, 0), 0.2),
		M.ClayRoofTiles
	)
	return rise
end

-- Squat whitewashed chimney with a little capped vent, Cycladic style.
local function chimney(m: Model, at: CFrame)
	part(m, Vector3.new(1.8, 3, 1.8), at * CFrame.new(0, 1.5, 0), WHITEWASH, M.Plaster)
	part(m, Vector3.new(2.4, 0.4, 2.4), at * CFrame.new(0, 3.6, 0), WHITEWASH, M.Plaster)
	for side = -1, 1, 2 do
		part(m, Vector3.new(0.4, 0.8, 2), at * CFrame.new(side * 0.8, 3.1, 0), WHITEWASH, M.Plaster)
	end
end

-- Facade pieces shared with the piazza's bespoke houses.
Med.window, Med.door, Med.balcony, Med.flowerBox, Med.gableRoof = window, door, balcony, flowerBox, gableRoof

-- Little blue dome on a drum, topped with a cross.
local function dome(m: Model, at: Vector3, diameter: number, drum: number)
	cylinder(m, at + Vector3.new(0, drum / 2, 0), drum, diameter, WHITEWASH, M.Plaster)
	ball(m, at + Vector3.new(0, drum, 0), diameter, AEGEAN, M.SmoothPlastic)
	local tip = at + Vector3.new(0, drum + diameter / 2, 0)
	part(m, Vector3.new(0.3, 2.4, 0.3), CFrame.new(tip + Vector3.new(0, 1, 0)), IRON, M.Metal)
	part(m, Vector3.new(1.2, 0.3, 0.3), CFrame.new(tip + Vector3.new(0, 1.5, 0)), IRON, M.Metal)
end

-- Bougainvillea climbing a wall from a root on `face` to a spill of blossom `height` up.
function Med.bougainvillea(parent: Instance, face: CFrame, rng: Random, height: number): Model
	local m = newModel("Bougainvillea", parent)
	beam(
		m,
		(face * CFrame.new(0, 0, 0.4)).Position,
		(face * CFrame.new(-0.4, height, 0.5)).Position,
		0.35,
		TRUNK,
		nil,
		M.Wood
	)
	for _ = 1, rng:NextInteger(6, 9) do
		local p = face * CFrame.new(rng:NextNumber(-3.4, 1), height + rng:NextNumber(-2.4, 1), rng:NextNumber(0.5, 1.1))
		local s = rng:NextNumber(1.4, 2.4)
		local color = if rng:NextNumber() < 0.75 then shade(pick(rng, BLOOMS), rng, 0.08) else LEAF
		blob(m, p.Position, Vector3.new(s, s * 0.8, s * 0.6), rng, color, M.LeafyGrass).CanCollide = false
	end
	return m
end

-- Outdoor masonry stair running up a side wall from the front to the roof.
local function sideStair(m: Model, base: CFrame, w: number, d: number, floor: number, roofY: number, side: number)
	local steps = math.ceil((roofY - floor) / 0.9)
	local run = (d - 1.5) / steps
	local x = side * (w / 2 + 1.4)
	for i = 1, steps do
		local top = floor + (roofY - floor) * i / steps
		local z = d / 2 - 0.5 - (i - 0.5) * run
		part(m, Vector3.new(2.8, top, run), base * CFrame.new(x, top / 2, z), WHITEWASH, M.Plaster)
	end
	local low = base:PointToWorldSpace(Vector3.new(side * (w / 2 + 2.6), floor + 1.4, d / 2 - 0.5))
	local high = base:PointToWorldSpace(Vector3.new(side * (w / 2 + 2.6), roofY + 1.4, -d / 2 + 1))
	beam(m, low, high, 0.6, WHITEWASH, 1.2, M.Plaster)
end

----------------------------------------------------------------------------------------------------
-- Pots and plants

-- Terracotta pot holding flowers, a shrub or a little lemon tree.
function Med.pot(parent: Instance, ground: Vector3, rng: Random, plant: string?): Model
	local m = newModel("Pot", parent)
	local kind = plant or pick(rng, { "flowers", "shrub", "lemon" })
	local s = if kind == "lemon" then 2.6 else rng:NextNumber(1.6, 2.2)
	cylinder(m, ground + Vector3.new(0, s * 0.45, 0), s * 0.9, s, TERRACOTTA, M.Sandstone)
	cylinder(
		m,
		ground + Vector3.new(0, s * 0.92, 0),
		s * 0.15,
		s * 1.15,
		TERRACOTTA:Lerp(Color3.new(0, 0, 0), 0.15),
		M.Sandstone
	)
	local soil = ground + Vector3.new(0, s, 0)
	if kind == "lemon" then
		beam(m, soil - Vector3.new(0, 0.5, 0), soil + Vector3.new(0, 3, 0), 0.4, TRUNK, nil, M.Wood)
		local crown = soil + Vector3.new(0, 4.2, 0)
		blob(m, crown, Vector3.new(3.4, 3, 3.4), rng, rgb(60, 110, 50), M.LeafyGrass)
		for _ = 1, 6 do
			local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.6, 0.8), rng:NextNumber(-1, 1)).Unit
			ball(m, crown + dir * 1.9, 0.55, rgb(244, 214, 60), M.SmoothPlastic)
		end
	elseif kind == "shrub" then
		blob(
			m,
			soil + Vector3.new(0, 0.6, 0),
			Vector3.new(s * 1.2, s, s * 1.2),
			rng,
			shade(LEAF, rng, 0.1),
			M.LeafyGrass
		)
	else
		for _ = 1, 3 do
			local at = soil + Vector3.new(rng:NextNumber(-0.4, 0.4), 0.5, rng:NextNumber(-0.4, 0.4))
			blob(m, at, Vector3.new(1, 0.8, 1), rng, pick(rng, BLOOMS), M.LeafyGrass)
		end
	end
	return m
end

function Med.lavender(parent: Instance, ground: Vector3, rng: Random): Model
	local m = newModel("Lavender", parent)
	for _ = 1, rng:NextInteger(3, 5) do
		local at = ground + Vector3.new(rng:NextNumber(-2.2, 2.2), 0.5, rng:NextNumber(-2.2, 2.2))
		blob(m, at, Vector3.new(1.8, 1.1, 1.8), rng, rgb(104, 120, 84), M.LeafyGrass)
		part(
			m,
			Vector3.new(1.4, 0.8, 1.4),
			CFrame.new(at + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
			shade(LAVENDER, rng, 0.08),
			M.LeafyGrass
		)
	end
	return m
end

----------------------------------------------------------------------------------------------------
-- Trees

-- Gnarled olive: a twisting trunk under flat silvery-green clumps.
function Med.olive(parent: Instance, ground: Vector3, rng: Random, scale: number?): Model
	local k = scale or 1
	local m = newModel("Olive", parent)
	local lean = rng:NextNumber(0, TAU)
	local dir = Vector3.new(math.cos(lean), 0, math.sin(lean))
	local h = rng:NextNumber(8, 12) * k
	local knee = ground + Vector3.new(0, h * 0.35, 0) + dir * rng:NextNumber(0.8, 1.8) * k
	local top = ground + Vector3.new(0, h * 0.62, 0) - dir * rng:NextNumber(0, 1) * k
	beam(m, ground - Vector3.new(0, 1, 0), knee, 1.9 * k, OLIVE_BARK, nil, M.Wood)
	beam(m, knee, top, 1.4 * k, OLIVE_BARK, nil, M.Wood)
	local crowns = { top + Vector3.new(0, 1.5 * k, 0) }
	for _ = 1, rng:NextInteger(2, 3) do
		local a = rng:NextNumber(0, TAU)
		local tip = top + Vector3.new(math.cos(a) * 3.5 * k, rng:NextNumber(1, 2.5) * k, math.sin(a) * 3.5 * k)
		beam(m, knee:Lerp(top, 0.6), tip, 0.7 * k, OLIVE_BARK, nil, M.Wood)
		table.insert(crowns, tip)
	end
	for _, c in crowns do
		local s = rng:NextNumber(5, 7.5) * k
		part(
			m,
			Vector3.new(s, s * 0.5, s * rng:NextNumber(0.8, 1.1)),
			CFrame.new(c + Vector3.new(0, s * 0.15, 0))
				* CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, TAU), rng:NextNumber(-0.25, 0.25)),
			shade(pick(rng, OLIVE_LEAF), rng, 0.05),
			M.LeafyGrass
		)
	end
	return m
end

-- Tall dark spindle of a cypress.
function Med.cypress(parent: Instance, ground: Vector3, rng: Random, height: number?): Model
	local m = newModel("Cypress", parent)
	local h = height or rng:NextNumber(16, 26)
	local r = h * rng:NextNumber(0.09, 0.11)
	part(m, Vector3.new(1, 3, 1), CFrame.new(ground + Vector3.new(0, 0.5, 0)), TRUNK, M.Wood)
	local ringY = h * 0.3
	local spin = rng:NextNumber(0, TAU)
	local ring = {}
	for i = 1, 5 do
		local a = spin + i / 5 * TAU
		ring[i] = ground + Vector3.new(math.cos(a) * r, ringY + rng:NextNumber(-0.4, 0.4), math.sin(a) * r)
	end
	local color = shade(CYPRESS, rng, 0.08)
	local core = ground + Vector3.new(0, ringY, 0)
	local apex = ground + Vector3.new(rng:NextNumber(-0.3, 0.3), h, rng:NextNumber(-0.3, 0.3))
	LowPoly.pyramid(ring, apex, color, m, M.LeafyGrass, core)
	LowPoly.pyramid(ring, ground + Vector3.new(0, 1.5, 0), color:Lerp(Color3.new(0, 0, 0), 0.12), m, M.LeafyGrass, core)
	return m
end

-- Umbrella pine: a tall leaning trunk under a flat, spreading crown.
function Med.stonePine(parent: Instance, ground: Vector3, rng: Random): Model
	local m = newModel("StonePine", parent)
	local h = rng:NextNumber(17, 25)
	local lean = rng:NextNumber(0, TAU)
	local dir = Vector3.new(math.cos(lean), 0, math.sin(lean))
	local top = ground + Vector3.new(0, h, 0) + dir * rng:NextNumber(1.5, 4)
	local mid = ground:Lerp(top, 0.55) + dir * 0.6
	beam(m, ground - Vector3.new(0, 1, 0), mid, 1.5, rgb(110, 78, 58), nil, M.Wood)
	beam(m, mid, top, 1.2, rgb(110, 78, 58), nil, M.Wood)
	local crowns = { top + Vector3.new(0, 1, 0) }
	for _ = 1, rng:NextInteger(2, 3) do
		local a = rng:NextNumber(0, TAU)
		local tip = top
			+ Vector3.new(
				math.cos(a) * rng:NextNumber(4, 6),
				rng:NextNumber(-1.5, 0.5),
				math.sin(a) * rng:NextNumber(4, 6)
			)
		beam(m, mid:Lerp(top, 0.7), tip, 0.6, rgb(110, 78, 58), nil, M.Wood)
		table.insert(crowns, tip)
	end
	for i, c in crowns do
		local s = if i == 1 then rng:NextNumber(12, 15) else rng:NextNumber(7, 10)
		part(
			m,
			Vector3.new(s, 2.6, s * rng:NextNumber(0.75, 1)),
			CFrame.new(c + Vector3.new(0, 1, 0)) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), rng:NextNumber(0, TAU), 0),
			shade(STONE_PINE, rng, 0.07),
			M.LeafyGrass
		)
	end
	return m
end

----------------------------------------------------------------------------------------------------
-- Houses

-- Cycladic cube house: whitewashed walls, blue door and shutters, a flat roof terrace, and often
-- a second block stacked on top, an outside stair, a pergola or a little dome.
function Med.cubeHouse(parent: Instance, ground: Vector3, facing: number, rng: Random): Model
	local m = newModel("CubeHouse", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	local w, d, h = rng:NextNumber(17, 22), rng:NextNumber(15, 18), rng:NextNumber(10.5, 12)
	local accent = pick(rng, SHUTTERS)
	local shuttered = rng:NextNumber() < 0.65
	local look: Look = {
		frame = if shuttered then OFFWHITE else accent,
		shutter = if shuttered then accent else nil,
		arched = rng:NextNumber() < 0.4,
		winW = 2.6,
		winH = 3.2,
		spacing = 7.5,
	}
	local floor = 0.6
	local stairSide = if rng:NextNumber() < 0.5 then -1 else 1
	local hasStair = rng:NextNumber() < 0.55

	part(m, Vector3.new(w + 1, 2, d + 1), base * CFrame.new(0, -0.4, 0), STONE, M.Limestone)
	flatBlock(m, base, w, d, floor, h, WHITEWASH)
	local doorX = rng:NextNumber(-w * 0.22, w * 0.22)
	local front = wallFace(base, w, d, 0, floor)
	door(m, front * CFrame.new(doorX, 0, 0), 3.6, 7.2, accent, look.frame, rng:NextNumber() < 0.6)
	fenestrate(m, base, w, d, rng, look, {
		floor = floor,
		storyH = h,
		stories = 1,
		doorX = doorX,
		skipSide = if hasStair then (if stairSide == 1 then 1 else 3) else nil,
	})
	if rng:NextNumber() < 0.55 then
		Med.bougainvillea(m, front * CFrame.new(doorX + 3.4, 0, 0), rng, 8.6)
	end

	local roofY = floor + h + 0.4
	local hasUpper = rng:NextNumber() < 0.65
	if hasUpper then
		local w2, d2, h2 = w * rng:NextNumber(0.42, 0.58), d * rng:NextNumber(0.5, 0.65), rng:NextNumber(8.5, 9.5)
		local upper = base * CFrame.new(-stairSide * ((w - w2) / 2 - 0.6), roofY, -((d - d2) / 2 - 0.6))
		flatBlock(m, upper, w2, d2, 0, h2, WHITEWASH)
		door(m, wallFace(upper, w2, d2, 0, 0), 3, 6.6, accent, look.frame, true)
		fenestrate(m, upper, w2, d2, rng, look, { floor = 0, storyH = h2, stories = 1, doorX = 0 })
		local upperRoof = upper * CFrame.new(0, h2 + 0.4, 0)
		if rng:NextNumber() < 0.25 then
			dome(m, upperRoof.Position, math.min(w2, d2) * 0.55, 1.2)
		else
			chimney(m, upperRoof * CFrame.new(w2 / 4, 0, -d2 / 4))
		end
	else
		chimney(m, base * CFrame.new(-w / 4, roofY, -d / 4))
	end

	-- Life on the roof terrace in front of the upper block
	local terrace = base * CFrame.new(stairSide * w / 4, roofY, d / 4)
	local shaded = rng:NextNumber() < 0.45
	if shaded then
		Med.pergola(m, terrace.Position, facing, rng, w * 0.4, d * 0.35, 7)
	end
	for _, corner in { -stairSide, stairSide } do
		if rng:NextNumber() < 0.6 and not (shaded and corner == stairSide) then
			Med.pot(m, base:PointToWorldSpace(Vector3.new(corner * (w / 2 - 1.6), roofY, d / 2 - 1.6)), rng)
		end
	end
	if hasStair then
		sideStair(m, base, w, d, floor, roofY, stairSide)
	end
	Props.simplifyHouseCollision(m)
	return m
end

-- Pastel townhouse of two or three floors under a clay-tile roof: shutters, balconies,
-- flower boxes and sometimes a shopfront with a striped awning.
function Med.townhouse(parent: Instance, ground: Vector3, facing: number, rng: Random, shopfront: boolean?): Model
	local m = newModel("Townhouse", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	local w, d = rng:NextNumber(15, 19), rng:NextNumber(13, 16)
	local stories = if rng:NextNumber() < 0.6 then 2 else 3
	local storyH = rng:NextNumber(8.5, 9.5)
	local h = stories * storyH
	local wall = pick(rng, PASTELS)
	local trim = WHITEWASH:Lerp(wall, 0.2)
	local look: Look = {
		frame = trim,
		shutter = pick(rng, TOWN_SHUTTERS),
		arched = rng:NextNumber() < 0.3,
		winW = 2.4,
		winH = 3.6,
		spacing = 7,
	}
	local floor = 0.6
	local shop = if shopfront ~= nil then shopfront else rng:NextNumber() < 0.3

	part(m, Vector3.new(w + 1, 2, d + 1), base * CFrame.new(0, -0.4, 0), STONE, M.Limestone)
	part(m, Vector3.new(w, h, d), base * CFrame.new(0, floor + h / 2, 0), wall, M.Plaster)
	if rng:NextNumber() < 0.5 then
		for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
			part(m, Vector3.new(1, h, 1), base * CFrame.new(c[1] * w / 2, floor + h / 2, c[2] * d / 2), trim, M.Plaster)
		end
	end
	for s = 1, stories - 1 do
		part(m, Vector3.new(w + 0.5, 0.5, d + 0.5), base * CFrame.new(0, floor + s * storyH, 0), trim, M.Plaster)
	end
	part(m, Vector3.new(w + 1, 0.9, d + 1), base * CFrame.new(0, floor + h + 0.45, 0), trim, M.Plaster)
	gableRoof(m, base, w, d, floor + h + 0.9, math.rad(rng:NextNumber(18, 24)), pick(rng, ROOF_TILES), wall)

	local front = wallFace(base, w, d, 0, floor)
	if shop then
		-- Shop window under a striped awning, a sign board above it, the door to one side
		local sw, sx = w * 0.55, -w * 0.12
		local awning = pick(rng, AWNINGS)
		part(m, Vector3.new(sw + 1, 5.6, 0.14), front * CFrame.new(sx, 3.2, 0.07), WOOD_DARK, M.Wood)
		local glass = part(m, Vector3.new(sw, 4.6, 0.2), front * CFrame.new(sx, 3.3, 0.12), LAMP, M.Neon)
		light(glass, LAMP, 20, 0.8)
		part(m, Vector3.new(sw + 1.2, 0.6, 1.2), front * CFrame.new(sx, 0.8, 0.5), WOOD, M.WoodPlanks)
		for i = 0, 5 do
			part(
				m,
				Vector3.new(sw / 6, 0.25, 3.8),
				front * CFrame.new(sx - sw / 2 + (i + 0.5) * sw / 6, 6.6, 1.7) * CFrame.Angles(0.35, 0, 0),
				if i % 2 == 0 then awning else CANVAS,
				M.Fabric
			)
		end
		local board =
			part(m, Vector3.new(sw * 0.8, 1.4, 0.3), front * CFrame.new(sx, 7.9, 0.2), WOOD_DARK, M.WoodPlanks)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Garamond
		label.TextScaled = true
		label.TextColor3 = rgb(245, 230, 190)
		label.Text = pick(rng, SHOPS)
		label.Parent = gui
		gui.Parent = board
		door(m, front * CFrame.new(sx + sw / 2 + 2.4, 0, 0), 3, 6.4, WOOD_DARK, trim, false)
		Med.pot(m, front:PointToWorldSpace(Vector3.new(sx - sw / 2 - 1.2, 0, 1.4)), rng)
	else
		door(m, front, 3.4, 6.4, pick(rng, TOWN_SHUTTERS), trim, true)
		for side = -1, 1, 2 do
			if rng:NextNumber() < 0.5 then
				Med.pot(m, front:PointToWorldSpace(Vector3.new(side * 3.2, 0, 1.2)), rng)
			end
		end
	end

	fenestrate(m, base, w, d, rng, look, {
		floor = floor,
		storyH = storyH,
		stories = stories,
		doorX = 0,
		doorGap = if shop then w else nil,
		extras = function(side, story, face)
			if side ~= 0 or story == 1 then
				return
			end
			if rng:NextNumber() < 0.45 then
				balcony(m, face * CFrame.new(0, 0.5 - storyH * 0.55, 0), look.winW * 2 + 2, 2.2, trim)
				if rng:NextNumber() < 0.5 then
					Med.pot(m, face:PointToWorldSpace(Vector3.new(look.winW, 0.5 - storyH * 0.55, 1.2)), rng, "flowers")
				end
			elseif rng:NextNumber() < 0.6 then
				flowerBox(m, face * CFrame.new(0, -look.winH / 2 - 0.9, 0), look.winW + 0.6, rng)
			end
		end,
	})
	if not shop and rng:NextNumber() < 0.35 then
		Med.bougainvillea(m, front * CFrame.new(-2.6, 0, 0), rng, 7.4)
	end
	Props.simplifyHouseCollision(m)
	return m
end

-- Two-storey villa with a columned loggia carrying a balustraded terrace, flanked by cypresses.
function Med.villa(parent: Instance, ground: Vector3, facing: number, rng: Random): Model
	local m = newModel("Villa", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	local w, d = rng:NextNumber(22, 25), rng:NextNumber(15, 17)
	local storyH, stories = 9, 2
	local h = storyH * stories
	local wall = if rng:NextNumber() < 0.4 then WHITEWASH else pick(rng, PASTELS)
	local trim = WHITEWASH:Lerp(wall, 0.15)
	local look: Look = {
		frame = trim,
		shutter = pick(rng, TOWN_SHUTTERS),
		arched = true,
		winW = 2.4,
		winH = 3.8,
		spacing = 7,
	}
	local floor = 0.6
	local depth = 6

	part(m, Vector3.new(w + 1, 2, d + 1), base * CFrame.new(0, -0.4, 0), STONE, M.Limestone)
	part(m, Vector3.new(w + 1, 2, depth), base * CFrame.new(0, -0.4, d / 2 + 0.5 + depth / 2), STONE, M.Limestone)
	part(m, Vector3.new(w, h, d), base * CFrame.new(0, floor + h / 2, 0), wall, M.Plaster)
	part(m, Vector3.new(w + 0.5, 0.5, d + 0.5), base * CFrame.new(0, floor + storyH, 0), trim, M.Plaster)
	part(m, Vector3.new(w + 1, 0.9, d + 1), base * CFrame.new(0, floor + h + 0.45, 0), trim, M.Plaster)
	gableRoof(m, base, w, d, floor + h + 0.9, math.rad(20), pick(rng, ROOF_TILES), wall)
	chimney(m, base * CFrame.new(w / 3, floor + h + 0.9, -d / 4) * CFrame.new(0, d / 4 * math.tan(math.rad(20)), 0))

	-- Loggia: columns along the front carrying a terrace slab
	local columnZ = d / 2 + depth - 0.9
	local columns = 5
	for i = 0, columns - 1 do
		local x = -w / 2 + 1 + (w - 2) * i / (columns - 1)
		local colH = storyH - 0.6
		cylinder(m, base:PointToWorldSpace(Vector3.new(x, floor + colH / 2, columnZ)), colH, 1.5, trim, M.Plaster)
		part(m, Vector3.new(2, 0.6, 2), base * CFrame.new(x, floor + 0.3, columnZ), STONE, M.Limestone)
		part(m, Vector3.new(2, 0.6, 2), base * CFrame.new(x, floor + colH - 0.3, columnZ), trim, M.Plaster)
	end
	local terraceY = floor + storyH + 0.2
	part(
		m,
		Vector3.new(w + 0.6, 0.8, depth + 0.2),
		base * CFrame.new(0, terraceY - 0.4, d / 2 + depth / 2),
		trim,
		M.Plaster
	)
	for x = -w / 2 + 0.6, w / 2 - 0.5, 1.2 do
		cylinder(m, base:PointToWorldSpace(Vector3.new(x, terraceY + 1, d / 2 + depth - 0.4)), 2, 0.6, trim, M.Plaster)
	end
	part(m, Vector3.new(w + 0.6, 0.5, 0.9), base * CFrame.new(0, terraceY + 2.2, d / 2 + depth - 0.4), trim, M.Plaster)
	for side = -1, 1, 2 do
		part(
			m,
			Vector3.new(0.9, 2.4, depth),
			base * CFrame.new(side * (w / 2 - 0.15), terraceY + 1.2, d / 2 + depth / 2),
			trim,
			M.Plaster
		)
	end

	local front = wallFace(base, w, d, 0, floor)
	door(m, front, 4, 7, pick(rng, TOWN_SHUTTERS), trim, true)
	fenestrate(m, base, w, d, rng, look, { floor = floor, storyH = storyH, stories = stories, doorX = 0 })
	for _, x in { -w / 4, w / 4 } do
		Med.pot(m, base:PointToWorldSpace(Vector3.new(x, floor, d / 2 + depth / 2)), rng, "lemon")
		Med.pot(m, base:PointToWorldSpace(Vector3.new(x, terraceY, d / 2 + depth / 2)), rng, "flowers")
	end
	Med.bougainvillea(m, base * CFrame.new(-w / 2 + 1, floor, columnZ + 0.8), rng, storyH)
	for side = -1, 1, 2 do
		Med.cypress(m, base:PointToWorldSpace(Vector3.new(side * (w / 2 + 2), 0, columnZ)), rng, rng:NextNumber(18, 22))
	end
	Props.simplifyHouseCollision(m)
	return m
end

-- Whitewashed chapel with a blue dome, a bell gable over the door and a round window. `size` scales it.
function Med.chapel(parent: Instance, ground: Vector3, facing: number, rng: Random, size: number?): Model
	local k = size or 1
	local m = newModel("Chapel", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	local w, d, h = 13 * k, 16 * k, 10 * k
	local floor = 0.6

	part(m, Vector3.new(w + 3, 2.4, d + 3), base * CFrame.new(0, -0.6, 0), STONE, M.Limestone)
	part(m, Vector3.new(w * 0.5, 0.3, 1.6), base * CFrame.new(0, 0.15, d / 2 + 2.3), STONE, M.Limestone)
	flatBlock(m, base, w, d, floor, h, WHITEWASH)

	local front = wallFace(base, w, d, 0, floor)
	door(m, front, 3.4 * k, 6 * k, AEGEAN, OFFWHITE, true)
	local rose = front * CFrame.new(0, 8.6 * k, 0)
	disc(m, rose * CFrame.new(0, 0, 0.06), 2.4 * k, 0.12, OFFWHITE, M.Plaster)
	disc(m, rose * CFrame.new(0, 0, 0.1), 1.6 * k, 0.2, AEGEAN, M.Glass)
	for _, side in { 1, 3 } do
		for _, z in { -d / 4, d / 4 } do
			local face = wallFace(base, w, d, side, floor + h * 0.5)
			window(m, face * CFrame.new(z, 0, 0), 1.4 * k, 3.4 * k, OFFWHITE, nil, true, rng:NextNumber() < 0.5)
		end
	end

	local roofY = floor + h + 0.4
	dome(m, base:PointToWorldSpace(Vector3.new(0, roofY, -d * 0.1)), 9 * k, 3 * k)

	-- Bell gable standing on the front parapet
	local gable = base * CFrame.new(0, roofY + 1, d / 2 - 0.5)
	for side = -1, 1, 2 do
		part(m, Vector3.new(1.2 * k, 5 * k, 1), gable * CFrame.new(side * 1.9 * k, 2.5 * k, 0), WHITEWASH, M.Plaster)
	end
	part(m, Vector3.new(5 * k, 1.2 * k, 1), gable * CFrame.new(0, 5.6 * k, 0), WHITEWASH, M.Plaster)
	disc(m, gable * CFrame.new(0, 6.2 * k, 0.08), 2.6 * k, 1, WHITEWASH, M.Plaster)
	part(m, Vector3.new(0.3, 1.8 * k, 0.3), gable * CFrame.new(0, 8.2 * k, 0), IRON, M.Metal)
	part(m, Vector3.new(1 * k, 0.3, 0.3), gable * CFrame.new(0, 8.5 * k, 0), IRON, M.Metal)
	part(m, Vector3.new(2.6 * k, 0.3, 0.3), gable * CFrame.new(0, 4.9 * k, 0), IRON, M.Metal)
	ball(m, (gable * CFrame.new(0, 3.9 * k, 0)).Position, 1.8 * k, BRASS, M.Metal)

	for side = -1, 1, 2 do
		Med.pot(m, front:PointToWorldSpace(Vector3.new(side * 3.6 * k, 0, 1.2)), rng, "flowers")
	end
	return m
end

-- Square campanile with a clock face, an open belfry and a small dome.
function Med.bellTower(parent: Instance, ground: Vector3, facing: number, rng: Random): Model
	local m = newModel("BellTower", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	local s, h = 7, 22
	local floor = 0.6
	part(m, Vector3.new(s + 1.2, 2, s + 1.2), base * CFrame.new(0, -0.4, 0), STONE, M.Limestone)
	part(m, Vector3.new(s, h, s), base * CFrame.new(0, floor + h / 2, 0), WHITEWASH, M.Plaster)
	door(m, wallFace(base, s, s, 0, floor), 2.6, 5.4, WOOD_DARK, OFFWHITE, true)
	for side = 0, 3 do
		local face = wallFace(base, s, s, side, floor + h - 4)
		disc(m, face * CFrame.new(0, 0, 0.06), 5, 0.12, OFFWHITE, M.Plaster)
		disc(m, face * CFrame.new(0, 0, 0.12), 4.2, 0.2, rgb(250, 240, 214), M.SmoothPlastic)
		part(m, Vector3.new(0.3, 1.7, 0.2), face * CFrame.new(0, 0.7, 0.3), IRON, M.Metal)
		part(m, Vector3.new(1.3, 0.3, 0.2), face * CFrame.new(0.55, 0, 0.3), IRON, M.Metal)
		if side ~= 0 then
			window(m, wallFace(base, s, s, side, floor + h * 0.45), 1.2, 3, OFFWHITE, nil, true, false)
		end
	end

	local y = floor + h
	part(m, Vector3.new(s + 0.8, 0.6, s + 0.8), base * CFrame.new(0, y + 0.3, 0), OFFWHITE, M.Plaster)
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		part(
			m,
			Vector3.new(1.4, 6, 1.4),
			base * CFrame.new(c[1] * (s / 2 - 0.7), y + 3.6, c[2] * (s / 2 - 0.7)),
			WHITEWASH,
			M.Plaster
		)
	end
	part(m, Vector3.new(s - 1, 0.3, 0.3), base * CFrame.new(0, y + 5.8, 0), WOOD_DARK, M.Wood)
	ball(m, base:PointToWorldSpace(Vector3.new(0, y + 4.4, 0)), 2.8, BRASS, M.Metal)
	part(m, Vector3.new(s + 0.8, 0.6, s + 0.8), base * CFrame.new(0, y + 6.9, 0), OFFWHITE, M.Plaster)
	if rng:NextNumber() < 0.5 then
		dome(m, base:PointToWorldSpace(Vector3.new(0, y + 7.2, 0)), 5, 1)
	else
		local corners = {}
		for i, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
			corners[i] = base:PointToWorldSpace(Vector3.new(c[1] * (s / 2 + 0.4), y + 7.2, c[2] * (s / 2 + 0.4)))
		end
		LowPoly.pyramid(corners, base:PointToWorldSpace(Vector3.new(0, y + 12, 0)), TERRACOTTA, m, M.ClayRoofTiles)
	end
	return m
end

-- Greek windmill: a round white tower under a conical thatch cap, with eight triangular canvas sails.
function Med.windmill(parent: Instance, ground: Vector3, facing: number, rng: Random): Model
	local m = newModel("Windmill", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	local r, h = 6.5, 18
	cylinder(m, ground + Vector3.new(0, -1.5, 0), 5, r * 2 + 3, STONE, M.Limestone)
	cylinder(m, ground + Vector3.new(0, 1 + h / 2, 0), h, r * 2, WHITEWASH, M.Plaster)
	local ring = {}
	for i = 1, 10 do
		local a = i / 10 * TAU
		ring[i] = ground + Vector3.new(math.cos(a) * (r + 0.8), 1 + h, math.sin(a) * (r + 0.8))
	end
	LowPoly.pyramid(ring, ground + Vector3.new(0, 1 + h + 6.5, 0), rgb(150, 120, 82), m, M.Wood)

	part(m, Vector3.new(3.8, 7, 0.4), base * CFrame.new(0, 4.5, r - 0.05), OFFWHITE, M.Plaster)
	part(m, Vector3.new(3, 6.4, 0.6), base * CFrame.new(0, 4.2, r), AEGEAN, M.WoodPlanks)
	for _, spot in { { -0.7, 10 }, { 0.8, 14 } } do
		part(
			m,
			Vector3.new(1.4, 2, 0.6),
			base * CFrame.Angles(0, spot[1], 0) * CFrame.new(0, spot[2], r - 0.1),
			AEGEAN,
			M.WoodPlanks
		)
	end

	-- Sails turned to face the sea breeze
	local hub = base * CFrame.new(0, h - 1, r + 2)
	beam(m, base:PointToWorldSpace(Vector3.new(0, h - 1, 0)), hub.Position, 0.9, WOOD_DARK, nil, M.Wood)
	ball(m, hub.Position, 1.8, WOOD_DARK, M.Wood)
	local spin = rng:NextNumber(0, TAU)
	for i = 1, 8 do
		local a = spin + i / 8 * TAU
		local dir = Vector3.new(math.cos(a), math.sin(a), 0)
		local dir2 = Vector3.new(math.cos(a + 0.34), math.sin(a + 0.34), 0)
		beam(m, hub.Position, hub:PointToWorldSpace(dir * 10), 0.35, WOOD, nil, M.Wood)
		LowPoly.triangle(
			hub:PointToWorldSpace(dir * 1.6),
			hub:PointToWorldSpace(dir * 10),
			hub:PointToWorldSpace(dir2 * 8.6),
			hub:PointToWorldSpace(Vector3.new(0, 0, -1)),
			CANVAS,
			m,
			M.Fabric
		)
	end
	return m
end

----------------------------------------------------------------------------------------------------
-- Piazza and garden fittings

-- Wooden pergola on whitewashed posts, overgrown with vines and the odd bougainvillea.
function Med.pergola(
	parent: Instance,
	ground: Vector3,
	facing: number,
	rng: Random,
	w: number,
	d: number,
	height: number?
): Model
	local m = newModel("Pergola", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	local h = height or 9
	local xs = if w > 12 then { -w / 2, 0, w / 2 } else { -w / 2, w / 2 }
	for _, x in xs do
		for _, z in { -d / 2, d / 2 } do
			part(m, Vector3.new(1.1, h, 1.1), base * CFrame.new(x, h / 2, z), WHITEWASH, M.Plaster)
		end
	end
	for _, z in { -d / 2, d / 2 } do
		part(m, Vector3.new(w + 2, 0.7, 0.7), base * CFrame.new(0, h + 0.35, z), WOOD, M.Wood)
	end
	local rafters = math.max(2, math.floor(w / 2.2))
	for i = 0, rafters do
		part(m, Vector3.new(0.4, 0.4, d + 2), base * CFrame.new(-w / 2 + w * i / rafters, h + 0.9, 0), WOOD, M.Wood)
	end
	for _ = 1, math.max(3, math.floor(w * d / 14)) do
		local p = base
			* CFrame.new(rng:NextNumber(-w / 2, w / 2), h + rng:NextNumber(1, 1.6), rng:NextNumber(-d / 2, d / 2))
		local s = rng:NextNumber(1.8, 3)
		local color = if rng:NextNumber() < 0.25 then pick(rng, BLOOMS) else shade(VINE, rng, 0.1)
		blob(m, p.Position, Vector3.new(s, s * 0.6, s), rng, color, M.LeafyGrass)
		if rng:NextNumber() < 0.15 then
			ball(m, p.Position - Vector3.new(0, 1.1, 0), 0.8, rgb(90, 40, 90), M.SmoothPlastic)
		end
	end
	return m
end

-- Café table with a marble top, chairs and, if given a colour, a striped parasol.
function Med.cafeTable(parent: Instance, ground: Vector3, rng: Random, parasol: Color3?): Model
	local m = newModel("CafeTable", parent)
	cylinder(m, ground + Vector3.new(0, 0.1, 0), 0.2, 1.6, IRON, M.Metal)
	cylinder(m, ground + Vector3.new(0, 1.6, 0), 3, 0.4, IRON, M.Metal)
	cylinder(m, ground + Vector3.new(0, 3.1, 0), 0.2, 3.6, WHITEWASH, M.Marble)
	ball(m, ground + Vector3.new(0.6, 3.5, 0.3), 0.6, rgb(150, 40, 60), M.Glass)
	local chairColor = if rng:NextNumber() < 0.5 then AEGEAN else WOOD
	local spin = rng:NextNumber(0, TAU)
	local chairs = rng:NextInteger(2, 4)
	for i = 1, chairs do
		local a = spin + i / chairs * TAU
		local seatAt = ground + Vector3.new(math.cos(a) * 2.8, 0, math.sin(a) * 2.8)
		local frame = CFrame.lookAt(seatAt, Vector3.new(ground.X, seatAt.Y, ground.Z))
		part(m, Vector3.new(1.6, 0.3, 1.6), frame * CFrame.new(0, 1.9, 0), chairColor, M.Wood)
		part(m, Vector3.new(1.6, 2, 0.25), frame * CFrame.new(0, 3, 0.75), chairColor, M.Wood)
		for side = -1, 1, 2 do
			part(m, Vector3.new(0.2, 1.8, 1.4), frame * CFrame.new(side * 0.65, 0.9, 0), IRON, M.Metal)
		end
	end
	if parasol then
		cylinder(m, ground + Vector3.new(0, 4.6, 0), 9, 0.3, WHITEWASH, M.Metal)
		local apex = ground + Vector3.new(0, 9.3, 0)
		for i = 1, 8 do
			local a0, a1 = i / 8 * TAU, (i + 1) / 8 * TAU
			LowPoly.triangle(
				ground + Vector3.new(math.cos(a0) * 4.6, 7.8, math.sin(a0) * 4.6),
				ground + Vector3.new(math.cos(a1) * 4.6, 7.8, math.sin(a1) * 4.6),
				apex,
				ground + Vector3.new(0, 6, 0),
				if i % 2 == 0 then parasol else CANVAS,
				m,
				M.Fabric
			)
		end
	end
	return m
end

-- Two-tier stone fountain in a round basin, with spray falling from the top bowl.
function Med.fountain(parent: Instance, ground: Vector3): Model
	local m = newModel("Fountain", parent)
	local function at(y: number): Vector3
		return ground + Vector3.new(0, y, 0)
	end
	cylinder(m, at(0.4), 0.8, 26, STONE:Lerp(Color3.new(0, 0, 0), 0.15), M.Limestone)
	cylinder(m, at(1.4), 1.2, 22, STONE, M.Limestone)
	local pool = cylinder(m, at(2.25), 0.4, 21, WATER, M.Glass)
	pool.Transparency = 0.25
	pool.CanCollide = false
	local rim = {}
	for i = 1, 16 do
		local a = i / 16 * TAU
		rim[i] = at(2.7) + Vector3.new(math.cos(a) * 10.6, 0, math.sin(a) * 10.6)
		cylinder(m, rim[i], 1.4, 1.4, STONE, M.Limestone)
	end
	for i = 1, 16 do
		beam(m, rim[i], rim[i % 16 + 1], 1.2, STONE, 1.4, M.Limestone)
	end

	cylinder(m, at(5), 6, 3.2, STONE, M.Limestone)
	cylinder(m, at(8.4), 0.8, 9, STONE, M.Limestone)
	local bowl = cylinder(m, at(8.85), 0.2, 8, WATER, M.Glass)
	bowl.Transparency = 0.25
	cylinder(m, at(10.3), 3, 1.4, STONE, M.Limestone)
	cylinder(m, at(12.1), 0.6, 3.6, STONE, M.Limestone)
	ball(m, at(12.8), 1.2, STONE, M.Limestone)

	local spout = part(m, Vector3.new(1, 1, 1), CFrame.new(at(12.8)), WATER)
	spout.Transparency = 1
	spout.CanCollide = false
	spout.CanQuery = false
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(rgb(210, 240, 250))
	spray.Transparency = NumberSequence.new(0.3, 1)
	spray.Size = NumberSequence.new(0.5, 0.2)
	spray.Lifetime = NumberRange.new(0.9, 1.3)
	spray.Rate = 45
	spray.Speed = NumberRange.new(6, 9)
	spray.SpreadAngle = Vector2.new(35, 35)
	spray.Acceleration = Vector3.new(0, -22, 0)
	spray.LightEmission = 0.2
	spray.Parent = spout
	return m
end

-- Square stone planter with an olive or lemon tree.
function Med.planter(parent: Instance, ground: Vector3, rng: Random, tree: string): Model
	local m = newModel("Planter", parent)
	part(m, Vector3.new(7, 2, 7), CFrame.new(ground + Vector3.new(0, 1, 0)), STONE, M.Limestone)
	part(m, Vector3.new(6, 0.3, 6), CFrame.new(ground + Vector3.new(0, 2.05, 0)), DIRT, M.Ground)
	if tree == "olive" then
		Med.olive(m, ground + Vector3.new(0, 2, 0), rng, 0.85)
	else
		Med.pot(m, ground + Vector3.new(0, 2, 0), rng, "lemon")
	end
	return m
end

-- Keep the individual stones as decoration, with one smooth collision box per wall.
local function simplifyStoneWall(wall: Model)
	if wall:GetAttribute("CollisionVersion") == 1 then
		return
	end
	local stones = {}
	local frame: CFrame? = nil
	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = -minimum
	for _, stone in wall:GetChildren() do
		if not stone:IsA("BasePart") then
			continue
		end
		frame = frame or stone.CFrame
		table.insert(stones, stone)
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					local corner = frame:PointToObjectSpace(
						stone.CFrame:PointToWorldSpace(
							Vector3.new(stone.Size.X * x, stone.Size.Y * y, stone.Size.Z * z) / 2
						)
					)
					minimum = minimum:Min(corner)
					maximum = maximum:Max(corner)
				end
			end
		end
	end
	if not frame then
		return
	end
	local hitbox = part(wall, maximum - minimum, frame * CFrame.new((minimum + maximum) / 2), STONE_WALL, M.Slate)
	hitbox.Name = "WallHitbox"
	hitbox.CanCollide = true
	hitbox.CanQuery = true
	hitbox.Transparency = 1
	hitbox.CastShadow = false
	for _, stone in stones do
		stone.CanCollide = false
		stone.CanTouch = false
		stone.CanQuery = false
	end
	wall:SetAttribute("CollisionVersion", 1)
end

-- Dry-stone wall between two ground points.
function Med.stoneWall(parent: Instance, a: Vector3, b: Vector3, rng: Random): Model
	local m = newModel("StoneWall", parent)
	local length = (b - a).Magnitude
	local n = math.max(1, math.floor(length / 2.6))
	local dir = (b - a).Unit
	for i = 0, n - 1 do
		local p0, p1 = a + dir * (i * length / n), a + dir * ((i + 1) * length / n)
		local h = rng:NextNumber(2, 2.8)
		local lift = Vector3.new(0, h / 2 - 0.3, 0)
		part(
			m,
			Vector3.new(1.6 + (i % 2) * 0.12, h, length / n + 0.05),
			CFrame.lookAt((p0 + p1) / 2 + lift, p1 + lift),
			shade(STONE_WALL, rng, 0.1),
			M.Slate
		)
	end
	simplifyStoneWall(m)
	return m
end

-- Upgrade borders already baked into a saved map without rebuilding their stones.
function Med.ensureStoneWalls(root: Instance)
	for _, wall in root:GetDescendants() do
		if wall:IsA("Model") and wall.Name == "StoneWall" then
			simplifyStoneWall(wall)
		end
	end
end

-- Rows of vines on posts and wires over a patch of tilled earth, walled on three sides.
function Med.vineyard(parent: Instance, ground: Vector3, facing: number, rng: Random, w: number, d: number): Model
	local m = newModel("Vineyard", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	part(m, Vector3.new(w, 0.4, d), base * CFrame.new(0, 0.1, 0), DIRT, M.Ground).CastShadow = false
	local rows = math.floor(w / 3.6)
	for i = 1, rows do
		local x = -w / 2 + (i - 0.5) * w / rows
		for _, z in { -d / 2 + 1, d / 2 - 1 } do
			part(m, Vector3.new(0.4, 4, 0.4), base * CFrame.new(x, 2, z), WOOD_DARK, M.Wood)
		end
		part(m, Vector3.new(0.1, 0.1, d - 2), base * CFrame.new(x, 3.6, 0), IRON, M.Metal)
		for z = -d / 2 + 2.5, d / 2 - 2.5, 2.6 do
			blob(
				m,
				(base * CFrame.new(x, 2.6, z)).Position,
				Vector3.new(1.6, 2.2, 2.2),
				rng,
				shade(VINE, rng, 0.1),
				M.LeafyGrass
			)
			if rng:NextNumber() < 0.3 then
				ball(m, (base * CFrame.new(x + 0.9, 1.9, z)).Position, 0.7, rgb(90, 40, 90), M.SmoothPlastic)
			end
		end
	end
	local corners = {
		base:PointToWorldSpace(Vector3.new(-w / 2 - 1, 0, d / 2)),
		base:PointToWorldSpace(Vector3.new(-w / 2 - 1, 0, -d / 2 - 1)),
		base:PointToWorldSpace(Vector3.new(w / 2 + 1, 0, -d / 2 - 1)),
		base:PointToWorldSpace(Vector3.new(w / 2 + 1, 0, d / 2)),
	}
	for c = 1, 3 do
		Med.stoneWall(m, corners[c], corners[c + 1], rng)
	end
	return m
end

-- Painted wooden fishing boat floating at `position` (the waterline), bow on its local +Z.
function Med.boat(
	parent: Instance,
	position: Vector3,
	facing: number,
	rng: Random,
	color: Color3,
	dimensions: { length: number, width: number, mast: boolean }?
): Model
	local m = newModel("Boat", parent)
	local base = CFrame.new(position) * CFrame.Angles(0, facing, 0)
	local length = if dimensions then dimensions.length else rng:NextNumber(13, 17)
	local width = if dimensions then dimensions.width else rng:NextNumber(4.6, 5.6)
	local mid = length * 0.3
	local top, bottom = 1.4, -0.6

	-- Keep the floor inside the walls and above the waves. The old floor shared
	-- both outside wall faces and sat directly on the terrain water surface.
	local floor = part(m, Vector3.new(width - 0.88, 0.24, mid * 2), base * CFrame.new(0, 0.4, 0), WOOD, M.WoodPlanks)
	floor.Name = "BoatFloor"
	for side = -1, 1, 2 do
		local hull = part(
			m,
			Vector3.new(0.4, top - bottom, mid * 2),
			base * CFrame.new(side * (width / 2 - 0.2), (top + bottom) / 2, 0),
			WHITEWASH,
			M.WoodPlanks
		)
		hull.Name = "BoatSide"
		-- Cap the hull instead of laying paint over a coplanar inner wall.
		local rail = part(
			m,
			Vector3.new(0.5, 0.3, mid * 2),
			base * CFrame.new(side * (width / 2 - 0.2), top + 0.15, 0),
			color,
			M.WoodPlanks
		)
		rail.Name = "BoatRail"
	end
	for _, e in { 1, -1 } do
		local function p(x: number, y: number, z: number): Vector3
			return base:PointToWorldSpace(Vector3.new(x, y, z * e))
		end
		local tl, tr = p(-width / 2, top, mid), p(width / 2, top, mid)
		local bl, br = p(-width / 2, bottom, mid), p(width / 2, bottom, mid)
		local tip = p(0, top + (if e == 1 then 1 else 0.4), length / 2)
		local keel = p(0, bottom, length / 2 - 2)
		local inside = p(0, 0.4, mid + 1)
		-- Thin planking avoids the thick terrain wedges protruding through the
		-- neighboring bow/stern panels. The shared triangle helper retains its
		-- original thickness everywhere else on the map.
		LowPoly.triangle(tl, bl, keel, inside, WHITEWASH, m, M.WoodPlanks, 0.12)
		LowPoly.triangle(tl, keel, tip, inside, color, m, M.WoodPlanks, 0.12)
		LowPoly.triangle(tr, br, keel, inside, WHITEWASH, m, M.WoodPlanks, 0.12)
		LowPoly.triangle(tr, keel, tip, inside, color, m, M.WoodPlanks, 0.12)
		LowPoly.triangle(bl, br, keel, inside, WHITEWASH, m, M.WoodPlanks, 0.12)
		LowPoly.triangle(tl, tr, tip, inside, WOOD, m, M.WoodPlanks, 0.12)
	end
	for _, z in { -mid * 0.5, mid * 0.5 } do
		part(m, Vector3.new(width - 0.8, 0.3, 1.2), base * CFrame.new(0, 0.7, z), WOOD, M.WoodPlanks)
	end
	local mast = if dimensions then dimensions.mast else rng:NextNumber() < 0.5
	if mast then
		cylinder(m, base:PointToWorldSpace(Vector3.new(0, 4.5, mid * 0.5)), 8, 0.4, WOOD_DARK, M.Wood)
	else
		for side = -1, 1, 2 do
			beam(
				m,
				base:PointToWorldSpace(Vector3.new(side * 1, 1.2, -mid)),
				base:PointToWorldSpace(Vector3.new(side * 1.4, 1.2, mid)),
				0.3,
				WOOD,
				nil,
				M.Wood
			)
		end
	end
	m:SetAttribute("BoatGeometryVersion", 2)
	return m
end

-- Upgrade the decorative boats in saved maps too. Their original floor records
-- the exact position, rotation, beam and length, so no scenery is rerolled.
function Med.ensureBoats(root: Instance)
	for _, old in root:GetDescendants() do
		if not old:IsA("Model") or old.Name ~= "Boat" or old:GetAttribute("BoatGeometryVersion") == 2 then
			continue
		end
		local floor: BasePart? = nil
		local color: Color3? = nil
		local mast = false
		for _, child in old:GetChildren() do
			if child:IsA("Part") then
				local size = child.Size
				if math.abs(size.Y - 0.4) < 0.001 and size.X >= 4.6 and size.X <= 5.6 then
					floor = child
				elseif math.abs(size.X - 0.5) < 0.001 and math.abs(size.Y - 0.5) < 0.001 then
					color = child.Color
				elseif child.Shape == Enum.PartType.Cylinder and math.abs(size.X - 8) < 0.001 then
					mast = true
				end
			end
		end
		if floor and color then
			local frame = floor.CFrame
			Med.boat(
				old.Parent,
				frame.Position,
				math.atan2(-frame.LookVector.X, -frame.LookVector.Z),
				Random.new(0),
				color,
				{
					length = floor.Size.Z / 0.6,
					width = floor.Size.X,
					mast = mast,
				}
			)
			old:Destroy()
		end
	end
end

return Med

end
dependencies.Mediterranean = loadMediterranean()
local function loadBeachDetails()
	-- Small, walk-through details that follow the beach mesh rather than a flat sand plane.
local Props = dependencies.Props

local BeachDetails = {}

local rgb = Color3.fromRGB
local M = Enum.Material
local TAU = math.pi * 2
local GRASSES = { rgb(144, 151, 89), rgb(165, 165, 102), rgb(128, 142, 82) }
local PEBBLES = { rgb(181, 174, 156), rgb(153, 149, 135), rgb(205, 194, 171) }
local TOYS = { rgb(214, 86, 65), rgb(50, 143, 163), rgb(232, 183, 70) }

type Frame = (number) -> (Vector2, Vector2)
type Surface = (Vector2, number?) -> Vector3

local function detail(p: Part): Part
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	return p
end

local function newModel(name: string, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

local function openCorridor(along: number, length: number, margin: number): boolean
	return math.abs(along - length * 0.3) > 10 + margin
		and math.abs(along - length * 0.66) > 10 + margin
		and math.abs(along - length * 0.5) > 12 + margin
end

local function grassTuft(parent: Instance, at: Vector2, surface: Surface, rng: Random)
	local model = newModel("MarramGrass", parent)
	local color = Props.pick(rng, GRASSES)
	local spin = rng:NextNumber(0, TAU)
	for blade = 1, rng:NextInteger(4, 6) do
		local angle = spin + blade * 2.4
		local spread = Vector2.new(math.cos(angle), math.sin(angle))
		local base = surface(at + spread * rng:NextNumber(0.1, 0.5), -0.08)
		local height = rng:NextNumber(1.1, 2.3)
		local tip = base + Vector3.new(spread.X * 0.6, height, spread.Y * 0.6)
		detail(Props.beam(model, base, tip, rng:NextNumber(0.1, 0.17), Props.shade(color, rng, 0.07), 0.08, M.Grass))
		if blade <= 2 then
			local seed = tip + Vector3.new(spread.X * 0.1, 0.24, spread.Y * 0.1)
			detail(Props.beam(model, tip, seed, 0.12, rgb(186, 177, 126), 0.12, M.Grass))
		end
	end
end

local function pebbleCluster(parent: Instance, at: Vector2, surface: Surface, rng: Random)
	local model = newModel("BeachPebbles", parent)
	for _ = 1, rng:NextInteger(4, 6) do
		local angle = rng:NextNumber(0, TAU)
		local offset = Vector2.new(math.cos(angle), math.sin(angle)) * rng:NextNumber(0.2, 2.1)
		local size = rng:NextNumber(0.4, 1)
		local height = size * rng:NextNumber(0.35, 0.55)
		local pebble = detail(
			Props.part(
				model,
				Vector3.new(size, height, size * rng:NextNumber(0.7, 1.2)),
				CFrame.new(surface(at + offset, height * 0.34)) * CFrame.Angles(0, angle, 0),
				Props.shade(Props.pick(rng, PEBBLES), rng, 0.05),
				M.Pebble
			)
		)
		pebble.Shape = Enum.PartType.Ball
	end
end

local function bucketAndSpade(parent: Instance, at: Vector2, surface: Surface, facing: number, color: Color3)
	local model = newModel("BucketAndSpade", parent)
	local base = CFrame.new(surface(at, 0.03)) * CFrame.Angles(0, facing, 0)
	-- Open octagonal bucket: the inset sand remains clearly below the rim.
	detail(Props.cylinder(model, base * Vector3.new(0, 0.12, 0), 0.18, 1.3, color, M.SmoothPlastic))
	for side = 0, 7 do
		local angle = side / 8 * TAU
		detail(
			Props.part(
				model,
				Vector3.new(0.57, 1.05, 0.12),
				base * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.68, 0.65),
				color,
				M.SmoothPlastic
			)
		)
	end
	detail(Props.cylinder(model, base * Vector3.new(0, 0.3, 0), 0.15, 1.08, rgb(221, 203, 162), M.Sand))
	local handle = rgb(239, 228, 203)
	local previous = base * Vector3.new(-0.67, 1, 0)
	for segment = 1, 5 do
		local angle = math.pi - segment / 5 * math.pi
		local nextPoint = base * Vector3.new(math.cos(angle) * 0.67, 1 + math.sin(angle) * 0.6, 0)
		detail(Props.beam(model, previous, nextPoint, 0.11, handle, 0.11, M.SmoothPlastic))
		previous = nextPoint
	end

	-- A spade resting next to the bucket, sampled separately so it follows the local sand height.
	local side = Vector2.new(math.cos(facing), -math.sin(facing))
	local spade = CFrame.new(surface(at + side * 1.45, 0.14)) * CFrame.Angles(0, facing + 0.35, 0)
	detail(Props.part(model, Vector3.new(0.14, 0.15, 1.3), spade, handle, M.SmoothPlastic))
	detail(Props.part(model, Vector3.new(0.64, 0.18, 0.75), spade * CFrame.new(0, 0, -0.95), color, M.SmoothPlastic))
	detail(Props.part(model, Vector3.new(0.5, 0.17, 0.16), spade * CFrame.new(0, 0, 0.72), color, M.SmoothPlastic))
end

function BeachDetails.build(parent: Instance, rng: Random, length: number, frame: Frame, surface: Surface)
	local model = newModel("BeachDetails", parent)
	local function point(along: number, depth: number): (Vector2, Vector2)
		local waterline, inland = frame(along)
		return waterline + inland * depth, inland
	end

	-- Staggered small patches break up the dune edge without filling the walking routes.
	local count = math.clamp(math.floor(length / 18), 8, 26)
	for index = 1, count do
		local along = length * (0.1 + 0.8 * (index - 0.5) / count) + rng:NextNumber(-4, 4)
		local inCabana = false
		for _, start in { length * 0.22, length * 0.36 } do
			inCabana = inCabana or (along > start - 6 and along < start + 30)
		end
		if openCorridor(along, length, 2) and not inCabana then
			local at = point(along, rng:NextNumber(38, 43))
			grassTuft(model, at, surface, rng)
		end
	end

	-- Rounded pebbles collect toward the rocky shoulders, leaving the central bathing sand clear.
	for _, fraction in { 0.1, 0.15, 0.84, 0.89, 0.93 } do
		local along = length * fraction + rng:NextNumber(-4, 4)
		if openCorridor(along, length, 3) then
			local at = point(along, rng:NextNumber(4, 12))
			pebbleCluster(model, at, surface, rng)
		end
	end

	for index, fraction in { 0.19, 0.88 } do
		local along = length * fraction
		if openCorridor(along, length, 3) then
			local at, inland = point(along, 14 + index * 2)
			local facing = math.atan2(-inland.X, -inland.Y) + 0.25
			bucketAndSpade(model, at, surface, facing, TOYS[index])
		end
	end
end

return BeachDetails

end
dependencies.BeachDetails = loadBeachDetails()
local function loadRowboat()
	-- Native geometry shared by the drydock display and each player's working boat.
-- The frame origin is the waterline; forward is local -Z. The open hull is built
-- from thin faceted planks instead of a solid block across the passenger space.

local Rowboat = {}

local WOOD = {
	Color3.fromRGB(83, 69, 59),
	Color3.fromRGB(94, 78, 65),
	Color3.fromRGB(104, 86, 71),
	Color3.fromRGB(89, 74, 62),
}
local RAIL = Color3.fromRGB(112, 91, 73)
local IRON = Color3.fromRGB(49, 47, 42)
local LAMP = Color3.fromRGB(255, 218, 151)
local PLANK_THICKNESS = 0.14
local FLOOR_HEIGHT = 0.4
local connectedCoolers = setmetatable({}, { __mode = "k" })

-- Connections are runtime state, so baked shop boats must be rebound on load.
function Rowboat.ensureCoolerInteraction(model: Model)
	local lid = model:FindFirstChild("CoolerLid", true)
	local hinge = if lid then lid:FindFirstChild("CoolerHinge") else nil
	if not hinge or connectedCoolers[lid] then return end
	connectedCoolers[lid] = true
	lid.Anchored = false
	local closed = hinge:GetAttribute("ClosedC0")
	local busy = false
	local function toggle(player: Player)
		local character = player.Character
		local playerRoot = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if busy or not playerRoot or not lid.Parent or (playerRoot.Position - lid.Position).Magnitude > 12 then return end
		busy = true
		local open = not model:GetAttribute("CoolerOpen")
		model:SetAttribute("CoolerOpen", open)
		local tween = game:GetService("TweenService"):Create(hinge,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ C0 = if open then closed * CFrame.Angles(math.rad(-105), 0, 0) else closed })
		tween.Completed:Once(function() busy = false end)
		tween:Play()
	end
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") and (piece.Name == "CoolerBody" or piece.Name == "CoolerWall" or piece == lid) then
			local click = piece:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector")
			click.MaxActivationDistance = 12
			click.Parent = piece
			click.MouseClick:Connect(toggle)
		end
	end
end

function Rowboat.build(frame: CFrame, anchored: boolean?): Model
	local isAnchored = anchored == true
	local model = Instance.new("Model")
	model.Name = "Rowboat"
	model:SetAttribute("HullLength", 14.4)
	model:SetAttribute("HullBeam", 6.8)
	model:SetAttribute("DryFloorHeight", FLOOR_HEIGHT)
	model:SetAttribute("DryFloorHalfBeam", 3.25)
	model:SetAttribute("DryFloorHalfLength", 7.1)

	local root = Instance.new("Part")
	root.Name = "HullRoot"
	root.Size = Vector3.new(3.4, 0.45, 8.5)
	root.CFrame = frame * CFrame.new(0, -0.4, 0)
	root.Transparency = 1
	root.Anchored = isAnchored
	root.CanCollide = false
	root.CanTouch = false
	root.RootPriority = 127
	root.CustomPhysicalProperties = PhysicalProperties.new(1.4, 0.45, 0.05, 100, 100)
	root.Parent = model
	model.PrimaryPart = root

	local function finish(p: BasePart, name: string, color: Color3, material: Enum.Material, collide: boolean?)
		p.Name = name
		p.Anchored = isAnchored
		p.CanCollide = collide ~= false
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Color = color
		p.Material = material
		p.Massless = true
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
		return p
	end

	local function part(
		name: string,
		size: Vector3,
		localFrame: CFrame,
		color: Color3,
		material: Enum.Material?,
		collide: boolean?
	): Part
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = frame * localFrame
		finish(p, name, color, material or Enum.Material.Wood, collide)
		return p
	end

	local function beam(
		name: string,
		a: Vector3,
		b: Vector3,
		width: number,
		depth: number,
		color: Color3,
		material: Enum.Material?,
		collide: boolean?
	): Part
		return part(
			name,
			Vector3.new(width, depth, (b - a).Magnitude),
			CFrame.lookAt((a + b) / 2, b),
			color,
			material,
			collide
		)
	end

	-- Two thin wedges cover one triangle. Their thickness is pushed inward, so
	-- adjacent patches share the outside edge without chunky projecting corners.
	local function triangle(name: string, a: Vector3, b: Vector3, c: Vector3, inside: Vector3, color: Color3)
		local ab, ac, bc = b - a, c - a, c - b
		local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
		if abd > acd and abd > bcd then
			c, a = a, c
		elseif acd > bcd and acd > abd then
			a, b = b, a
		end
		ab, ac, bc = b - a, c - a, c - b
		local right = ac:Cross(ab).Unit
		local up = bc:Cross(right).Unit
		local back = bc.Unit
		local height = math.abs(ab:Dot(up))
		local normal = if right:Dot((a + b + c) / 3 - inside) >= 0 then right else -right
		local shift = -normal * (PLANK_THICKNESS / 2)
		local first = Instance.new("WedgePart")
		first.Size = Vector3.new(PLANK_THICKNESS, height, math.abs(ab:Dot(back)))
		first.CFrame = frame * CFrame.fromMatrix((a + b) / 2 + shift, right, up, back)
		finish(first, name, color, Enum.Material.Wood)
		local second = Instance.new("WedgePart")
		second.Size = Vector3.new(PLANK_THICKNESS, height, math.abs(ac:Dot(back)))
		second.CFrame = frame * CFrame.fromMatrix((a + c) / 2 + shift, -right, up, -back)
		finish(second, name, color, Enum.Material.Wood)
	end

	local stations = {
		{ z = -7.1, width = 0.25, bottom = 0.12, top = 2.18 },
		{ z = -4.6, width = 2.73, bottom = 1.70, top = 1.83 },
		{ z = 0, width = 3.25, bottom = 2.08, top = 1.70 },
		{ z = 4.6, width = 2.73, bottom = 1.70, top = 1.83 },
		{ z = 7.1, width = 0.25, bottom = 0.12, top = 2.18 },
	}
	local function hullPoint(station, side: number, level: number): Vector3
		local bottomY = if math.abs(station.z) > 7 then 0.12 else -0.48
		return Vector3.new(
			side * (station.bottom + (station.width - station.bottom) * level),
			bottomY + (station.top - bottomY) * level,
			station.z
		)
	end
	for _, side in { -1, 1 } do
		for i = 1, #stations - 1 do
			local from, to = stations[i], stations[i + 1]
			for band = 0, 1 do
				local low, high = band / 2, (band + 1) / 2
				local a, b = hullPoint(from, side, low), hullPoint(to, side, low)
				local c, d = hullPoint(to, side, high), hullPoint(from, side, high)
				local inside = Vector3.new(0, 0.5, (from.z + to.z) / 2)
				local color = WOOD[(i + band + (if side > 0 then 1 else 0)) % #WOOD + 1]
				triangle("HullPlank", a, b, c, inside, color)
				triangle("HullPlank", a, c, d, inside, color)
			end
			beam("Gunwale", hullPoint(from, side, 1), hullPoint(to, side, 1), 0.24, 0.22, RAIL)
			beam("PlankSeam", hullPoint(from, side, 0.5), hullPoint(to, side, 0.5), 0.065, 0.075, WOOD[1], nil, false)
		end
	end

	-- Terrain water is not displaced by hull parts. A continuous, raised wooden
	-- sole meets the hull at every station, including the tapered bow and stern.
	local function floorPoint(station, side: number): Vector3
		local bottomY = if math.abs(station.z) > 7 then 0.12 else -0.48
		local level = (FLOOR_HEIGHT - bottomY) / (station.top - bottomY)
		return Vector3.new(side * (station.bottom + (station.width - station.bottom) * level), FLOOR_HEIGHT, station.z)
	end
	for i = 1, #stations - 1 do
		local a, b = floorPoint(stations[i], -1), floorPoint(stations[i + 1], -1)
		local c, d = floorPoint(stations[i + 1], 1), floorPoint(stations[i], 1)
		local inside = Vector3.new(0, -1, (a.Z + b.Z) / 2)
		triangle("FloorSeal", a, b, c, inside, WOOD[i % #WOOD + 1])
		triangle("FloorSeal", a, c, d, inside, WOOD[i % #WOOD + 1])
	end

	-- Narrow boards retain the planked appearance above the fitted sole.
	for i = -3, 3 do
		local length = 11.6 - math.abs(i) * 1.0
		part("Floorboard", Vector3.new(0.51, 0.20, length), CFrame.new(i * 0.53, FLOOR_HEIGHT - 0.08, 0), WOOD[(i + 3) % #WOOD + 1])
	end
	part("Keel", Vector3.new(0.26, 0.25, 13.5), CFrame.new(0, -0.51, 0), WOOD[1])
	for _, z in { -7.05, 7.05 } do
		part("Stem", Vector3.new(0.35, 2.05, 0.25), CFrame.new(0, 1.16, z), WOOD[1])
	end
	for _, z in { -3.65, 0.6, 3.65 } do
		local width = if z == 0.6 then 5.55 else 4.9
		part("Bench", Vector3.new(width, 0.24, 1.05), CFrame.new(0, 0.9, z), RAIL)
		for _, side in { -1, 1 } do
			part("BenchSupport", Vector3.new(0.22, 0.9, 0.5), CFrame.new(side * (width / 2 - 0.4), 0.34, z), WOOD[1])
		end
	end

	-- A compact insulated cooler rests on the bow floor ahead of the front bench.
	local coolerBlue = Color3.fromRGB(67, 111, 124)
	local coolerWhite = Color3.fromRGB(230, 230, 211)
	part("CoolerBody", Vector3.new(2, 0.12, 1.4), CFrame.new(0, FLOOR_HEIGHT + 0.08, -4.95), coolerBlue, Enum.Material.SmoothPlastic, false)
	for _, side in { -1, 1 } do
		part("CoolerWall", Vector3.new(0.12, 1.03, 1.4), CFrame.new(side * 0.94, 1.055, -4.95), coolerBlue, Enum.Material.SmoothPlastic, false)
		part("CoolerWall", Vector3.new(1.76, 1.03, 0.12), CFrame.new(0, 1.055, -4.95 + side * 0.64), coolerBlue, Enum.Material.SmoothPlastic, false)
		part("CoolerSeal", Vector3.new(0.14, 0.06, 1.48), CFrame.new(side * 0.97, 1.6, -4.95), IRON, Enum.Material.Rubber, false)
		part("CoolerSeal", Vector3.new(1.8, 0.06, 0.14), CFrame.new(0, 1.6, -4.95 + side * 0.67), IRON, Enum.Material.Rubber, false)
	end
	local lid = part("CoolerLid", Vector3.new(2.15, 0.18, 1.55), CFrame.new(0, 1.72, -4.95), coolerWhite, Enum.Material.SmoothPlastic, false)
	lid:FindFirstChildOfClass("WeldConstraint"):Destroy()
	local pivot = frame * CFrame.new(0, 1.63, -5.725)
	local hinge = Instance.new("Motor6D")
	hinge.Name = "CoolerHinge"
	hinge.Part0, hinge.Part1 = root, lid
	hinge.C0 = root.CFrame:ToObjectSpace(pivot)
	hinge.C1 = lid.CFrame:ToObjectSpace(pivot)
	hinge:SetAttribute("ClosedC0", hinge.C0)
	hinge.Parent = lid
	model:SetAttribute("CoolerOpen", false)
	for _, side in { -1, 1 } do
		part("CoolerLatch", Vector3.new(0.16, 0.32, 0.1), CFrame.new(side * 0.65, 1.48, -4.205), IRON, Enum.Material.Metal, false)
		part("CoolerHandleMount", Vector3.new(0.12, 0.3, 0.75), CFrame.new(side * 1.04, 1.26, -4.95), coolerWhite, Enum.Material.SmoothPlastic, false)
		part("CoolerHandle", Vector3.new(0.16, 0.13, 0.65), CFrame.new(side * 1.15, 1.23, -4.95), IRON, Enum.Material.SmoothPlastic, false)
	end

	local seat = Instance.new("VehicleSeat")
	seat.Size = Vector3.new(2.1, 0.22, 1.05)
	seat.CFrame = frame * CFrame.new(0, 0.92, 0.6)
	seat.Transparency = 1
	seat.HeadsUpDisplay = false
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	finish(seat, "RowerSeat", RAIL, Enum.Material.Wood, false)
	seat.CanTouch = not isAnchored
	seat.Disabled = isAnchored

	for _, side in { -1, 1 } do
		local inner = Vector3.new(side * 1.9, 1.91, -1.6)
		local outer = Vector3.new(side * 4.66, 1.08, 3.72)
		local shaft = beam("OarShaft", inner, outer, 0.13, 0.13, RAIL, nil, false)
		local grip = beam("OarGrip", inner, inner:Lerp(outer, 0.13), 0.19, 0.18, WOOD[1], nil, false)
		local bladeEnd = outer + (outer - inner).Unit * 1.15
		local blade = beam("OarBlade", outer, bladeEnd, 0.6, 0.13, WOOD[2], nil, false)
		-- One pivot per complete oar. Nothing is also welded directly to the hull.
		local pivot = frame * CFrame.new(side * 3.08, 1.76, 0.6)
		for _, piece in { shaft, grip, blade } do
			piece:FindFirstChildOfClass("WeldConstraint"):Destroy()
			if piece ~= shaft then
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1, weld.Parent = shaft, piece, piece
			end
		end
		local joint = Instance.new("Motor6D")
		joint.Name = if side < 0 then "PortOar" else "StarboardOar"
		joint.Part0, joint.Part1 = root, shaft
		joint.C0 = root.CFrame:ToObjectSpace(pivot)
		joint.C1 = shaft.CFrame:ToObjectSpace(pivot)
		joint:SetAttribute("RowSide", side)
		joint.Parent = shaft
		part(
			"Oarlock",
			Vector3.new(0.15, 0.32, 0.27),
			CFrame.new(side * 3.08, 1.76, 0.6),
			IRON,
			Enum.Material.Metal,
			false
		)
	end

	for _, z in { -6.25, 6.25 } do
		part("EndBoard", Vector3.new(1.45, 0.16, 0.8), CFrame.new(0, 1.95, z), RAIL)
		local base = Vector3.new(0, 2.12, z)
		part("LanternFoot", Vector3.new(0.44, 0.12, 0.44), CFrame.new(base), IRON, Enum.Material.Metal, false)
		local glow = part(
			"LanternGlass",
			Vector3.new(0.28, 0.47, 0.28),
			CFrame.new(base + Vector3.new(0, 0.28, 0)),
			LAMP,
			Enum.Material.Neon,
			false
		)
		part(
			"LanternCap",
			Vector3.new(0.44, 0.12, 0.44),
			CFrame.new(base + Vector3.new(0, 0.56, 0)),
			IRON,
			Enum.Material.Metal,
			false
		)
		for _, x in { -0.18, 0.18 } do
			part(
				"LanternFrame",
				Vector3.new(0.045, 0.49, 0.045),
				CFrame.new(base + Vector3.new(x, 0.29, 0)),
				IRON,
				Enum.Material.Metal,
				false
			)
		end
		part(
			"LanternHandle",
			Vector3.new(0.12, 0.2, 0.05),
			CFrame.new(base + Vector3.new(0, 0.72, 0)),
			IRON,
			Enum.Material.Metal,
			false
		)
		local light = Instance.new("PointLight")
		light.Color = LAMP
		light.Range = 8
		light.Brightness = 0.55
		light.Shadows = false
		light.Parent = glow
	end

	Rowboat.ensureCoolerInteraction(model)
	return model
end

return Rowboat

end
dependencies.Rowboat = loadRowboat()
local function loadFishingBoat()
	-- A small working fisher, shared by the drydock display and owned boats.
-- The supplied frame is the waterline and local -Z points toward the bow.
-- Only the hull, deck, and wheelhouse walls collide; equipment stays decorative.

local FishingBoat = {}

local WHITE = Color3.fromRGB(224, 229, 215)
local CREAM = Color3.fromRGB(239, 222, 179)
local TEAL = Color3.fromRGB(47, 103, 96)
local DECK = Color3.fromRGB(98, 123, 109)
local DARK = Color3.fromRGB(38, 47, 43)
local ROOF = Color3.fromRGB(119, 65, 47)
local WOOD = Color3.fromRGB(145, 111, 73)
local ROPE = Color3.fromRGB(188, 171, 128)
local ORANGE = Color3.fromRGB(220, 109, 49)
local GLASS = Color3.fromRGB(103, 159, 169)
local METAL = Color3.fromRGB(145, 155, 146)
local THICKNESS = 0.18

function FishingBoat.build(frame: CFrame, anchored: boolean?): Model
	local isAnchored = anchored == true
	local model = Instance.new("Model")
	model.Name = "FishingBoat"
	model:SetAttribute("HullLength", 22)
	model:SetAttribute("HullBeam", 9.6)
	model:SetAttribute("PassengerSeats", 2)
	model:SetAttribute("DriverSeat", "HelmSeat")
	model:SetAttribute("DryFloorHeight", 1.1)
	model:SetAttribute("DryFloorHalfBeam", 4.2)
	model:SetAttribute("DryFloorHalfLength", 10.85)

	local root = Instance.new("Part")
	root.Name = "HullRoot"
	root.Size = Vector3.new(5.6, 0.5, 14)
	root.CFrame = frame * CFrame.new(0, -0.4, 0)
	root.Transparency = 1
	root.Anchored = isAnchored
	root.CanCollide = false
	root.CanTouch = false
	root.RootPriority = 127
	root.CustomPhysicalProperties = PhysicalProperties.new(1.4, 0.45, 0.05, 100, 100)
	root.Parent = model
	model.PrimaryPart = root

	local function finish(p: BasePart, name: string, color: Color3, material: Enum.Material?, collide: boolean?)
		p.Name = name
		p.Anchored = isAnchored
		p.CanCollide = collide == true
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Massless = true
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
		return p
	end

	local function part(
		name: string,
		size: Vector3,
		localFrame: CFrame,
		color: Color3,
		material: Enum.Material?,
		collide: boolean?
	): Part
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = frame * localFrame
		finish(p, name, color, material, collide)
		return p
	end

	local function beam(
		name: string,
		a: Vector3,
		b: Vector3,
		width: number,
		depth: number,
		color: Color3,
		material: Enum.Material?,
		collide: boolean?
	): Part
		return part(
			name,
			Vector3.new(width, depth, (b - a).Magnitude),
			CFrame.lookAt((a + b) / 2, b),
			color,
			material,
			collide
		)
	end

	-- Thin facets form an open hull; there is no solid collision box through it.
	local function triangle(name: string, a: Vector3, b: Vector3, c: Vector3, inside: Vector3, color: Color3)
		local ab, ac, bc = b - a, c - a, c - b
		local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
		if abd > acd and abd > bcd then
			c, a = a, c
		elseif acd > bcd and acd > abd then
			a, b = b, a
		end
		ab, ac, bc = b - a, c - a, c - b
		local right = ac:Cross(ab).Unit
		local up = bc:Cross(right).Unit
		local back = bc.Unit
		local height = math.abs(ab:Dot(up))
		local normal = if right:Dot((a + b + c) / 3 - inside) >= 0 then right else -right
		local shift = -normal * THICKNESS / 2
		local first = Instance.new("WedgePart")
		first.Size = Vector3.new(THICKNESS, height, math.abs(ab:Dot(back)))
		first.CFrame = frame * CFrame.fromMatrix((a + b) / 2 + shift, right, up, back)
		finish(first, name, color, nil, true)
		local second = Instance.new("WedgePart")
		second.Size = Vector3.new(THICKNESS, height, math.abs(ac:Dot(back)))
		second.CFrame = frame * CFrame.fromMatrix((a + c) / 2 + shift, -right, up, -back)
		finish(second, name, color, nil, true)
	end

	local stations = {
		{ z = -10.85, width = 0.18, bottom = 0.12, top = 3.0, keel = -0.05 },
		{ z = -8.0, width = 3.3, bottom = 1.8, top = 2.55, keel = -1.3 },
		{ z = -3.5, width = 4.65, bottom = 3.95, top = 2.2, keel = -1.5 },
		{ z = 3.5, width = 4.65, bottom = 3.95, top = 2.2, keel = -1.5 },
		{ z = 8.5, width = 4.4, bottom = 4.1, top = 2.2, keel = -1.25 },
		{ z = 10.8, width = 3.65, bottom = 2.8, top = 2.3, keel = -0.95 },
	}
	local function hullPoint(station, side: number, level: number): Vector3
		local bottomY = if station.z < -10 then 0.25 else -0.72
		return Vector3.new(
			side * (station.bottom + (station.width - station.bottom) * level),
			bottomY + (station.top - bottomY) * level,
			station.z
		)
	end
	-- Each cross-section curves inward through the bilge to the center keel.
	-- These panels close the underside all the way from bow to transom.
	local function bottomPoint(station, side: number, level: number): Vector3
		if level == 0 then
			return hullPoint(station, side, 0)
		elseif level == 1 then
			local edge = hullPoint(station, side, 0)
			return Vector3.new(side * station.bottom * 0.52, station.keel + (edge.Y - station.keel) * 0.42, station.z)
		end
		return Vector3.new(0, station.keel, station.z)
	end
	for _, side in { -1, 1 } do
		for i = 1, #stations - 1 do
			local from, to = stations[i], stations[i + 1]
			for _, band in { { 0, 0.79, WHITE }, { 0.79, 1, TEAL } } do
				local a, b = hullPoint(from, side, band[1]), hullPoint(to, side, band[1])
				local c, d = hullPoint(to, side, band[2]), hullPoint(from, side, band[2])
				local inside = Vector3.new(0, 0.8, (from.z + to.z) / 2)
				triangle("HullPanel", a, b, c, inside, band[3])
				triangle("HullPanel", a, c, d, inside, band[3])
			end
			for band = 0, 1 do
				local a, b = bottomPoint(from, side, band), bottomPoint(to, side, band)
				local c, d = bottomPoint(to, side, band + 1), bottomPoint(from, side, band + 1)
				local inside = Vector3.new(0, 0.8, (from.z + to.z) / 2)
				local name = if band == 0 then "BilgePanel" else "BottomPanel"
				triangle(name, a, b, c, inside, WHITE)
				triangle(name, a, c, d, inside, WHITE)
			end
			beam("Gunwale", hullPoint(from, side, 1), hullPoint(to, side, 1), 0.3, 0.24, DARK)
		end
	end
	for _, station in { stations[1], stations[#stations] } do
		local center = Vector3.new(0, hullPoint(station, 1, 0).Y, station.z)
		local inside = Vector3.new(0, 0.8, 0)
		for _, side in { -1, 1 } do
			local edge, bilge, keel =
				bottomPoint(station, side, 0), bottomPoint(station, side, 1), bottomPoint(station, side, 2)
			triangle("HullEndCap", edge, bilge, keel, inside, WHITE)
			triangle("HullEndCap", edge, keel, center, inside, WHITE)
		end
		if station == stations[1] then
			local left, right = hullPoint(station, -1, 1), hullPoint(station, 1, 1)
			triangle("BowCap", center, left, right, inside, WHITE)
			triangle("BowCap", center, hullPoint(station, -1, 0), left, inside, WHITE)
			triangle("BowCap", center, right, hullPoint(station, 1, 0), inside, WHITE)
		end
	end
	local stern = stations[#stations]
	local sternLeft, sternRight = hullPoint(stern, -1, 0), hullPoint(stern, 1, 0)
	triangle("Transom", sternLeft, sternRight, hullPoint(stern, 1, 1), Vector3.new(0, 0.8, 0), WHITE)
	triangle("Transom", sternLeft, hullPoint(stern, 1, 1), hullPoint(stern, -1, 1), Vector3.new(0, 0.8, 0), WHITE)
	part("TransomTrim", Vector3.new(7.4, 0.5, 0.23), CFrame.new(0, 2.04, 10.8), TEAL)
	part("TransomCap", Vector3.new(7.5, 0.2, 0.3), CFrame.new(0, 2.3, 10.8), DARK)
	for index = 1, #stations - 1 do
		beam(
			"Keel",
			bottomPoint(stations[index], 1, 2),
			bottomPoint(stations[index + 1], 1, 2),
			0.18,
			0.16,
			TEAL,
			nil,
			true
		)
	end
	part("BowStem", Vector3.new(0.3, 2.85, 0.25), CFrame.new(0, 1.625, -10.85), WHITE)

	-- Continuous planks provide a working bow deck and two clear side walkways.
	local function deckWidth(station): number
		local bottomY = if station.z < -10 then 0.25 else -0.72
		local level = (1.1 - bottomY) / (station.top - bottomY)
		return math.max(0, station.bottom + (station.width - station.bottom) * level - 0.15)
	end
	for i = -7, 7 do
		local outside = (math.abs(i) + 0.5) * 0.55
		local startZ, endZ = stations[1].z, stations[#stations].z - 0.15
		for index = 1, #stations - 1 do
			local a, b = stations[index], stations[index + 1]
			local fromWidth, toWidth = deckWidth(a), deckWidth(b)
			if fromWidth < outside and toWidth >= outside then
				startZ = a.z + (b.z - a.z) * (outside - fromWidth) / (toWidth - fromWidth)
			elseif fromWidth >= outside and toWidth < outside then
				endZ = a.z + (b.z - a.z) * (outside - fromWidth) / (toWidth - fromWidth)
			end
		end
		part(
			"WorkingDeck",
			Vector3.new(0.55, 0.22, endZ - startZ),
			CFrame.new(i * 0.55, 0.99, (startZ + endZ) / 2),
			DECK,
			Enum.Material.Wood,
			true
		)
	end

	-- Cream wheelhouse near the stern. The 2.6-stud front opening reaches the
	-- same level deck without a doorstep; the helm controls do not obstruct it.
	-- Transparent SmoothPlastic keeps terrain water visible through the windows;
	-- refractive Glass hides water and other transparent effects behind it.
	part("CabinBackLower", Vector3.new(4.2, 2.35, 0.24), CFrame.new(0, 2.275, 7.8), CREAM, nil, true)
	part("CabinBackHeader", Vector3.new(4.2, 0.55, 0.24), CFrame.new(0, 6.525, 7.8), CREAM, nil, true)
	for _, side in { -1, 1 } do
		part("CabinSideLower", Vector3.new(0.24, 2.35, 4.8), CFrame.new(side * 1.98, 2.275, 5.4), CREAM, nil, true)
		part("CabinSideHeader", Vector3.new(0.24, 0.55, 4.8), CFrame.new(side * 1.98, 6.525, 5.4), CREAM, nil, true)
		part("CabinFrontJamb", Vector3.new(0.8, 2.35, 0.24), CFrame.new(side * 1.7, 2.275, 3.0), CREAM, nil, true)
		part("CabinFrontHeader", Vector3.new(0.8, 0.55, 0.24), CFrame.new(side * 1.7, 6.525, 3.0), CREAM, nil, true)
		local frontGlass = part(
			"CabinFrontWindow",
			Vector3.new(0.58, 2.55, 0.12),
			CFrame.new(side * 1.7, 4.825, 3.0),
			GLASS,
			Enum.Material.SmoothPlastic,
			true
		)
		frontGlass.Transparency = 0.28
		part("CabinCorner", Vector3.new(0.25, 2.85, 0.25), CFrame.new(side * 1.98, 4.825, 7.8), CREAM, nil, true)
		for _, z in { 4.2, 6.6 } do
			local glass = part(
				"CabinSideWindow",
				Vector3.new(0.12, 2.55, 2.12),
				CFrame.new(side * 1.98, 4.825, z),
				GLASS,
				Enum.Material.SmoothPlastic,
				true
			)
			glass.Transparency = 0.28
		end
		part("WindowMullion", Vector3.new(0.29, 2.85, 0.2), CFrame.new(side * 1.98, 4.825, 5.4), CREAM, nil, true)
		part("WindowSill", Vector3.new(0.36, 0.15, 4.95), CFrame.new(side * 1.98, 3.48, 5.4), TEAL)
		local rearGlass = part(
			"CabinRearWindow",
			Vector3.new(1.67, 2.55, 0.12),
			CFrame.new(side * 0.97, 4.825, 7.8),
			GLASS,
			Enum.Material.SmoothPlastic,
			true
		)
		rearGlass.Transparency = 0.28
	end
	part("CabinRearMullion", Vector3.new(0.2, 2.85, 0.26), CFrame.new(0, 4.825, 7.8), CREAM, nil, true)
	part("DoorHeader", Vector3.new(2.6, 0.2, 0.24), CFrame.new(0, 6.7, 3.0), CREAM, nil, true)
	part("CabinRoof", Vector3.new(4.85, 0.32, 5.65), CFrame.new(0, 6.96, 5.35), ROOF, nil, true)
	part("RoofEdge", Vector3.new(4.95, 0.12, 5.76), CFrame.new(0, 6.82, 5.35), DARK)
	part("RoofRidge", Vector3.new(0.14, 0.1, 5.45), CFrame.new(0, 7.16, 5.35), WOOD)
	for _, x in { -1.6, -0.8, 0.8, 1.6 } do
		part("RoofSeam", Vector3.new(0.035, 0.035, 5.45), CFrame.new(x, 7.135, 5.35), Color3.fromRGB(94, 51, 39))
	end

	part("HelmPedestal", Vector3.new(0.55, 0.8, 0.55), CFrame.new(0, 1.5, 5.9), DARK)
	part("HelmCushion", Vector3.new(1.85, 0.25, 1.3), CFrame.new(0, 1.99, 5.9), ROOF)
	part("HelmBack", Vector3.new(1.85, 1.25, 0.2), CFrame.new(0, 2.67, 6.5), ROOF)
	local helm = Instance.new("VehicleSeat")
	helm.Size = Vector3.new(1.85, 0.24, 1.3)
	helm.CFrame = frame * CFrame.new(0, 2.04, 5.9)
	helm.Transparency = 1
	helm.HeadsUpDisplay = false
	helm.MaxSpeed = 0
	helm.Torque = 0
	helm.TurnSpeed = 0
	finish(helm, "HelmSeat", ROOF, nil, false)
	helm.CanTouch = not isAnchored
	helm.Disabled = isAnchored
	part("HelmConsole", Vector3.new(1.5, 1.0, 0.75), CFrame.new(0, 2.1, 4.25), TEAL)
	part("ConsoleTop", Vector3.new(1.65, 0.13, 0.86), CFrame.new(0, 2.67, 4.25), WOOD)
	part("InstrumentPanel", Vector3.new(1.2, 0.3, 0.1), CFrame.new(0, 2.95, 4.6), DARK)
	for _, x in { -0.33, 0.33 } do
		local gauge = part(
			"HelmGauge",
			Vector3.new(0.05, 0.26, 0.26),
			CFrame.new(x, 2.95, 4.67) * CFrame.Angles(0, math.pi / 2, 0),
			CREAM
		)
		gauge.Shape = Enum.PartType.Cylinder
	end
	local wheelCenter = Vector3.new(0, 3.05, 4.85)
	for i = 0, 7 do
		local a, b = i * math.pi / 4, (i + 1) * math.pi / 4
		beam(
			"SteeringWheel",
			wheelCenter + Vector3.new(math.cos(a) * 0.48, math.sin(a) * 0.48, 0),
			wheelCenter + Vector3.new(math.cos(b) * 0.48, math.sin(b) * 0.48, 0),
			0.1,
			0.1,
			WOOD
		)
	end
	for i = 0, 2 do
		local angle = i * math.pi * 2 / 3
		beam(
			"WheelSpoke",
			wheelCenter,
			wheelCenter + Vector3.new(math.cos(angle) * 0.45, math.sin(angle) * 0.45, 0),
			0.07,
			0.07,
			METAL
		)
	end

	-- Two usable fishing seats leave a broad lane down the middle of the bow.
	for _, side in { -1, 1 } do
		part("FishingSeatPedestal", Vector3.new(0.35, 0.68, 0.35), CFrame.new(side * 2.35, 1.44, -1.5), DARK)
		part("FishingSeatCushion", Vector3.new(1.6, 0.22, 1.3), CFrame.new(side * 2.35, 1.86, -1.5), CREAM)
		part("FishingSeatBack", Vector3.new(1.6, 0.85, 0.17), CFrame.new(side * 2.35, 2.36, -0.88), TEAL)
		local passenger = Instance.new("Seat")
		passenger.Size = Vector3.new(1.6, 0.24, 1.3)
		passenger.CFrame = frame * CFrame.new(side * 2.35, 1.9, -1.5)
		passenger.Transparency = 1
		finish(passenger, "FishingSeat" .. (if side < 0 then "Port" else "Starboard"), CREAM, nil, false)
		passenger.CanTouch = not isAnchored
		passenger.Disabled = isAnchored
	end

	-- Hanging rubber fenders and their pale lashings give the working hull scale.
	for _, side in { -1, 1 } do
		for _, z in { -3.7, 1.2, 6.8 } do
			local x = side * (if z == 6.8 then 4.54 else 4.7)
			local fender = part("RubberFender", Vector3.new(0.4, 1.25, 1.25), CFrame.new(x, 1.22, z), DARK)
			fender.Shape = Enum.PartType.Cylinder
			local inset = part("FenderInset", Vector3.new(0.415, 0.54, 0.54), CFrame.new(x, 1.22, z), TEAL)
			inset.Shape = Enum.PartType.Cylinder
			beam("FenderRope", Vector3.new(x, 1.75, z), Vector3.new(x - side * 0.2, 2.35, z + 0.15), 0.055, 0.055, ROPE)
		end
	end

	-- Low-profile equipment sits against the sides, clear of the central route.
	for _, spec in { { -2.8, -5.65 }, { -2.65, -4.15 } } do
		local x, z = spec[1], spec[2]
		part("FishCrate", Vector3.new(1.5, 0.85, 1.2), CFrame.new(x, 1.54, z), WOOD, Enum.Material.Wood)
		part("CrateRim", Vector3.new(1.62, 0.12, 1.32), CFrame.new(x, 2.01, z), CREAM, Enum.Material.Wood)
		for _, dz in { -0.4, 0, 0.4 } do
			part("CrateSlat", Vector3.new(1.54, 0.06, 0.11), CFrame.new(x, 1.96, z + dz), DARK)
		end
	end
	local ropeCenter = Vector3.new(2.65, 1.24, -5.2)
	for ring = 0, 1 do
		local radius = 0.54 + ring * 0.15
		for i = 0, 9 do
			local a, b = i * math.pi / 5, (i + 1) * math.pi / 5
			beam(
				"CoiledRope",
				ropeCenter + Vector3.new(math.cos(a) * radius, ring * 0.06, math.sin(a) * radius),
				ropeCenter + Vector3.new(math.cos(b) * radius, ring * 0.06, math.sin(b) * radius),
				0.1,
				0.1,
				ROPE
			)
		end
	end
	for _, side in { -1, 1 } do
		part("BowCleat", Vector3.new(0.7, 0.12, 0.2), CFrame.new(side * 1.8, 2.5, -8.1), METAL)
		part("BowCleatFoot", Vector3.new(0.18, 0.25, 0.18), CFrame.new(side * 1.8, 2.35, -8.1), METAL)
		local a, b = Vector3.new(side * 3.8, 1.3, -3.0), Vector3.new(side * 4.25, 5.6, -5.7)
		beam("FishingRod", a, b, 0.055, 0.055, DARK)
		beam("RodGrip", a, a:Lerp(b, 0.18), 0.13, 0.13, WOOD)
		beam("FishingLine", b, Vector3.new(side * 4.15, 0.45, -6.0), 0.018, 0.018, ROPE)
	end
	for _, spec in { { 2.85, 8.7, ORANGE }, { 3.45, 8.4, CREAM }, { 3.0, 9.3, ORANGE } } do
		local buoy = part("FishingBuoy", Vector3.new(0.66, 0.95, 0.66), CFrame.new(spec[1], 1.62, spec[2]), spec[3])
		buoy.Shape = Enum.PartType.Ball
		part("BuoyHandle", Vector3.new(0.12, 0.23, 0.12), CFrame.new(spec[1], 2.18, spec[2]), DARK)
	end

	-- The wheelhouse roof, mast, boom, and safety ring establish the silhouette.
	part("Mast", Vector3.new(0.17, 5.4, 0.17), CFrame.new(0, 9.8, 4.4), WOOD)
	part("MastCrossbar", Vector3.new(4.6, 0.12, 0.12), CFrame.new(0, 11.25, 4.4), WOOD)
	beam("MastBoom", Vector3.new(0, 9.1, 4.4), Vector3.new(0, 8.0, -0.8), 0.13, 0.13, WOOD)
	for _, side in { -1, 1 } do
		beam("MastRigging", Vector3.new(0, 12.3, 4.4), Vector3.new(side * 3.65, 2.3, 8.8), 0.035, 0.035, ROPE)
	end
	beam("BoomRigging", Vector3.new(0, 11.6, 4.4), Vector3.new(0, 8.0, -0.8), 0.035, 0.035, ROPE)
	part("NavigationLamp", Vector3.new(0.23, 0.28, 0.23), CFrame.new(0, 12.6, 4.4), CREAM, Enum.Material.Neon)
	part("Vent", Vector3.new(0.42, 0.85, 0.42), CFrame.new(1.18, 7.52, 6.3), DARK, Enum.Material.Metal)
	part("VentCap", Vector3.new(0.63, 0.12, 0.63), CFrame.new(1.18, 8.0, 6.3), METAL, Enum.Material.Metal)
	local ringCenter = Vector3.new(0, 4.8, 8.0)
	for i = 0, 11 do
		local a, b = i * math.pi / 6, (i + 1) * math.pi / 6
		beam(
			"LifeRing",
			ringCenter + Vector3.new(math.cos(a) * 0.72, math.sin(a) * 0.72, 0),
			ringCenter + Vector3.new(math.cos(b) * 0.72, math.sin(b) * 0.72, 0),
			0.2,
			0.2,
			if i % 3 == 0 then CREAM else ORANGE
		)
	end

	-- A warm bow lantern keeps the working-boat look alongside electric lighting.
	local lanternBase = Vector3.new(0, 2.6, -8.5)
	local lanternColor = Color3.fromRGB(255, 218, 151)
	part("LanternStand", Vector3.new(0.16, 1.44, 0.16), CFrame.new(0, 1.82, -8.5), DARK, Enum.Material.Metal)
	part("LanternFoot", Vector3.new(0.52, 0.12, 0.52), CFrame.new(lanternBase), DARK, Enum.Material.Metal)
	local lantern = part(
		"LanternGlass",
		Vector3.new(0.36, 0.58, 0.36),
		CFrame.new(lanternBase + Vector3.new(0, 0.35, 0)),
		lanternColor,
		Enum.Material.Neon
	)
	part(
		"LanternCap",
		Vector3.new(0.52, 0.12, 0.52),
		CFrame.new(lanternBase + Vector3.new(0, 0.7, 0)),
		DARK,
		Enum.Material.Metal
	)
	for _, x in { -0.22, 0.22 } do
		part(
			"LanternFrame",
			Vector3.new(0.05, 0.6, 0.05),
			CFrame.new(lanternBase + Vector3.new(x, 0.35, 0)),
			DARK,
			Enum.Material.Metal
		)
	end
	part(
		"LanternHandle",
		Vector3.new(0.12, 0.24, 0.06),
		CFrame.new(lanternBase + Vector3.new(0, 0.88, 0)),
		DARK,
		Enum.Material.Metal
	)
	local lanternLight = Instance.new("PointLight")
	lanternLight.Name = "LanternLight"
	lanternLight.Color, lanternLight.Range, lanternLight.Brightness = lanternColor, 10, 0.6
	lanternLight.Shadows = false
	lanternLight.Parent = lantern

	local lampColor = Color3.fromRGB(255, 244, 219)
	local ceiling =
		part("CabinLight", Vector3.new(0.8, 0.12, 0.55), CFrame.new(0, 6.72, 5.4), lampColor, Enum.Material.Neon)
	local deckLight = Instance.new("PointLight")
	deckLight.Name = "DeckLight"
	deckLight.Color, deckLight.Range, deckLight.Brightness = lampColor, 18, 0.6
	deckLight.Shadows = false
	deckLight.Parent = ceiling
	-- Keep the lamps above the bow sides, with beams pointing along local -Z.
	for _, side in { -1, 1 } do
		part(
			"HeadlightStand",
			Vector3.new(0.16, 1.4, 0.16),
			CFrame.new(side * 1.15, 1.8, -8.7),
			DARK,
			Enum.Material.Metal
		)
		part(
			"HeadlightHousing",
			Vector3.new(0.7, 0.5, 0.55),
			CFrame.new(side * 1.15, 2.75, -8.7),
			DARK,
			Enum.Material.Metal
		)
		local lens = part(
			"HeadlightLens",
			Vector3.new(0.54, 0.34, 0.06),
			CFrame.new(side * 1.15, 2.75, -9.01),
			lampColor,
			Enum.Material.Neon
		)
		lens.CastShadow = false
		local headlight = Instance.new("SpotLight")
		headlight.Name = "Headlight"
		headlight.Face = Enum.NormalId.Front
		headlight.Color, headlight.Range, headlight.Brightness, headlight.Angle = lampColor, 45, 1.2, 65
		headlight.Shadows = false
		headlight.Parent = lens
	end
	return model
end

return FishingBoat

end
dependencies.FishingBoat = loadFishingBoat()
local function loadSpeedboat()
	-- Blue-and-white sport cruiser. Waterline origin; local -Z is the bow.
-- The faceted V hull and cockpit sole form one welded, server-driven assembly.
local Speedboat = {}
local WHITE = Color3.fromRGB(237, 241, 246)
local BLUE = Color3.fromRGB(8, 113, 166)
local DECK = Color3.fromRGB(185, 204, 212)
local DARK = Color3.fromRGB(40, 51, 61)
local GLASS = Color3.fromRGB(62, 83, 99)
local METAL = Color3.fromRGB(122, 139, 151)
local THICKNESS = 0.18

function Speedboat.build(frame: CFrame, anchored: boolean?): Model
	local isAnchored = anchored == true
	local model = Instance.new("Model")
	model.Name = "Speedboat"
	model:SetAttribute("HullLength", 24)
	model:SetAttribute("HullBeam", 9.6)
	model:SetAttribute("PassengerSeats", 2)
	model:SetAttribute("DriverSeat", "HelmSeat")
	model:SetAttribute("DryFloorHeight", 1.1)
	model:SetAttribute("DryFloorHalfBeam", 4.2)
	model:SetAttribute("DryFloorHalfLength", 10.85)

	local root = Instance.new("Part")
	root.Name = "HullRoot"
	root.Size = Vector3.new(5.6, 0.5, 14)
	root.CFrame = frame * CFrame.new(0, -0.4, 0)
	root.Transparency = 1
	root.Anchored = isAnchored
	root.CanCollide = false
	root.CanTouch = false
	root.RootPriority = 127
	root.CustomPhysicalProperties = PhysicalProperties.new(1.4, 0.45, 0.05, 100, 100)
	root.Parent = model
	model.PrimaryPart = root

	local function finish(p: BasePart, name: string, color: Color3, material: Enum.Material?, collide: boolean?)
		p.Name = name
		p.Anchored = isAnchored
		p.CanCollide = collide == true
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Massless = true
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
		return p
	end

	local function part(
		name: string,
		size: Vector3,
		localFrame: CFrame,
		color: Color3,
		material: Enum.Material?,
		collide: boolean?
	): Part
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = frame * localFrame
		finish(p, name, color, material, collide)
		return p
	end

	local function beam(
		name: string,
		a: Vector3,
		b: Vector3,
		width: number,
		depth: number,
		color: Color3,
		material: Enum.Material?,
		collide: boolean?
	): Part
		return part(
			name,
			Vector3.new(width, depth, (b - a).Magnitude),
			CFrame.lookAt((a + b) / 2, b),
			color,
			material,
			collide
		)
	end

	-- Thin facets form an open hull; there is no solid collision box through it.
	local function triangle(name: string, a: Vector3, b: Vector3, c: Vector3, inside: Vector3, color: Color3)
		local ab, ac, bc = b - a, c - a, c - b
		local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
		if abd > acd and abd > bcd then
			c, a = a, c
		elseif acd > bcd and acd > abd then
			a, b = b, a
		end
		ab, ac, bc = b - a, c - a, c - b
		local right = ac:Cross(ab).Unit
		local up = bc:Cross(right).Unit
		local back = bc.Unit
		local height = math.abs(ab:Dot(up))
		local normal = if right:Dot((a + b + c) / 3 - inside) >= 0 then right else -right
		local shift = -normal * THICKNESS / 2
		local first = Instance.new("WedgePart")
		first.Size = Vector3.new(THICKNESS, height, math.abs(ab:Dot(back)))
		first.CFrame = frame * CFrame.fromMatrix((a + b) / 2 + shift, right, up, back)
		finish(first, name, color, nil, true)
		local second = Instance.new("WedgePart")
		second.Size = Vector3.new(THICKNESS, height, math.abs(ac:Dot(back)))
		second.CFrame = frame * CFrame.fromMatrix((a + c) / 2 + shift, -right, up, -back)
		finish(second, name, color, nil, true)
	end

	local stations = {
		{ z = -10.85, width = 0.18, bottom = 0.12, top = 3.0, keel = -0.05 },
		{ z = -8.0, width = 3.3, bottom = 1.8, top = 2.55, keel = -1.3 },
		{ z = -3.5, width = 4.65, bottom = 3.95, top = 2.2, keel = -1.5 },
		{ z = 3.5, width = 4.65, bottom = 3.95, top = 2.2, keel = -1.5 },
		{ z = 8.5, width = 4.4, bottom = 4.1, top = 2.2, keel = -1.25 },
		{ z = 10.8, width = 3.65, bottom = 2.8, top = 2.3, keel = -0.95 },
	}
	local function hullPoint(station, side: number, level: number): Vector3
		local bottomY = if station.z < -10 then 0.25 else -0.72
		return Vector3.new(
			side * (station.bottom + (station.width - station.bottom) * level),
			bottomY + (station.top - bottomY) * level,
			station.z
		)
	end
	-- Each cross-section curves inward through the bilge to the center keel.
	-- These panels close the underside all the way from bow to transom.
	local function bottomPoint(station, side: number, level: number): Vector3
		if level == 0 then
			return hullPoint(station, side, 0)
		elseif level == 1 then
			local edge = hullPoint(station, side, 0)
			return Vector3.new(side * station.bottom * 0.52, station.keel + (edge.Y - station.keel) * 0.42, station.z)
		end
		return Vector3.new(0, station.keel, station.z)
	end
	for _, side in { -1, 1 } do
		for i = 1, #stations - 1 do
			local from, to = stations[i], stations[i + 1]
			for _, band in { { 0, 0.68, BLUE }, { 0.68, 1, WHITE } } do
				local a, b = hullPoint(from, side, band[1]), hullPoint(to, side, band[1])
				local c, d = hullPoint(to, side, band[2]), hullPoint(from, side, band[2])
				local inside = Vector3.new(0, 0.8, (from.z + to.z) / 2)
				triangle("HullPanel", a, b, c, inside, band[3])
				triangle("HullPanel", a, c, d, inside, band[3])
			end
			for band = 0, 1 do
				local a, b = bottomPoint(from, side, band), bottomPoint(to, side, band)
				local c, d = bottomPoint(to, side, band + 1), bottomPoint(from, side, band + 1)
				local inside = Vector3.new(0, 0.8, (from.z + to.z) / 2)
				local name = if band == 0 then "BilgePanel" else "BottomPanel"
				triangle(name, a, b, c, inside, BLUE)
				triangle(name, a, c, d, inside, BLUE)
			end
			beam("Gunwale", hullPoint(from, side, 1), hullPoint(to, side, 1), 0.3, 0.24, DARK)
		end
	end
	for _, station in { stations[1], stations[#stations] } do
		local center = Vector3.new(0, hullPoint(station, 1, 0).Y, station.z)
		local inside = Vector3.new(0, 0.8, 0)
		for _, side in { -1, 1 } do
			local edge, bilge, keel =
				bottomPoint(station, side, 0), bottomPoint(station, side, 1), bottomPoint(station, side, 2)
			triangle("HullEndCap", edge, bilge, keel, inside, BLUE)
			triangle("HullEndCap", edge, keel, center, inside, BLUE)
		end
		if station == stations[1] then
			local left, right = hullPoint(station, -1, 1), hullPoint(station, 1, 1)
			triangle("BowCap", center, left, right, inside, BLUE)
			triangle("BowCap", center, hullPoint(station, -1, 0), left, inside, BLUE)
			triangle("BowCap", center, right, hullPoint(station, 1, 0), inside, BLUE)
		end
	end
	local stern = stations[#stations]
	local sternLeft, sternRight = hullPoint(stern, -1, 0), hullPoint(stern, 1, 0)
	triangle("Transom", sternLeft, sternRight, hullPoint(stern, 1, 1), Vector3.new(0, 0.8, 0), WHITE)
	triangle("Transom", sternLeft, hullPoint(stern, 1, 1), hullPoint(stern, -1, 1), Vector3.new(0, 0.8, 0), WHITE)
	part("TransomTrim", Vector3.new(7.4, 0.5, 0.23), CFrame.new(0, 2.04, 10.8), WHITE)
	part("TransomCap", Vector3.new(7.5, 0.2, 0.3), CFrame.new(0, 2.3, 10.8), WHITE)
	for index = 1, #stations - 1 do
		beam(
			"Keel",
			bottomPoint(stations[index], 1, 2),
			bottomPoint(stations[index + 1], 1, 2),
			0.18,
			0.16,
			BLUE,
			nil,
			true
		)
	end
	part("BowStem", Vector3.new(0.3, 2.85, 0.25), CFrame.new(0, 1.625, -10.85), WHITE)

	-- Continuous planks provide a working bow deck and two clear side walkways.
	local function deckWidth(station): number
		local bottomY = if station.z < -10 then 0.25 else -0.72
		local level = (1.1 - bottomY) / (station.top - bottomY)
		return math.max(0, station.bottom + (station.width - station.bottom) * level - 0.15)
	end
	for i = -7, 7 do
		local outside = (math.abs(i) + 0.5) * 0.55
		local startZ, endZ = stations[1].z, stations[#stations].z - 0.15
		for index = 1, #stations - 1 do
			local a, b = stations[index], stations[index + 1]
			local fromWidth, toWidth = deckWidth(a), deckWidth(b)
			if fromWidth < outside and toWidth >= outside then
				startZ = a.z + (b.z - a.z) * (outside - fromWidth) / (toWidth - fromWidth)
			elseif fromWidth >= outside and toWidth < outside then
				endZ = a.z + (b.z - a.z) * (outside - fromWidth) / (toWidth - fromWidth)
			end
		end
		part(
			"WorkingDeck",
			Vector3.new(0.55, 0.22, endZ - startZ),
			CFrame.new(i * 0.55, 0.99, (startZ + endZ) / 2),
			DECK,
			Enum.Material.SmoothPlastic,
			true
		)
	end

	-- Fitted bow deck closes the forward hull while leaving the cockpit open.
	for index = 1, 3 do
		local a, b = stations[index], stations[index + 1]
		local centerA = Vector3.new(0, a.top - 0.12, a.z)
		local centerB = Vector3.new(0, b.top - 0.12, b.z)
		for _, side in { -1, 1 } do
			local edgeA = hullPoint(a, side, 1) - Vector3.new(0, 0.12, 0)
			local edgeB = hullPoint(b, side, 1) - Vector3.new(0, 0.12, 0)
			-- End the foredeck ahead of the helm, rather than covering the cockpit.
			if index == 3 then
				centerB = Vector3.new(0, 2.08, -0.8)
				edgeB = Vector3.new(side * 4.65, 2.08, -0.8)
			end
			triangle("Foredeck", centerA, edgeA, edgeB, Vector3.new(0, 0, -4), WHITE)
			triangle("Foredeck", centerA, edgeB, centerB, Vector3.new(0, 0, -4), WHITE)
		end
	end
	part("DeckStripe", Vector3.new(1.3, 0.035, 5.5), CFrame.new(0, 2.105, -3.6), BLUE)
	part("ForedeckHatchRim", Vector3.new(2.05, 0.12, 1.65), CFrame.new(0, 2.19, -4.6), METAL)
	part("ForedeckHatch", Vector3.new(1.8, 0.14, 1.4), CFrame.new(0, 2.26, -4.6), DARK)

	-- Swept windshield: dark glazing, white frame, and small triangular sides.
	local screenBottom = Vector3.new(0, 2.28, -0.7)
	local screenTop = Vector3.new(0, 4.15, 1.25)
	local windshield = beam("Windshield", screenBottom, screenTop, 6.0, 0.12, GLASS)
	windshield.Transparency = 0.2
	beam("WindshieldHeader", screenTop + Vector3.new(-3.1, 0, 0), screenTop + Vector3.new(3.1, 0, 0), 0.2, 0.2, WHITE)
	beam(
		"WindshieldSill",
		screenBottom + Vector3.new(-3.1, 0, 0),
		screenBottom + Vector3.new(3.1, 0, 0),
		0.24,
		0.24,
		WHITE
	)
	beam("WindshieldMullion", screenBottom, screenTop, 0.18, 0.18, WHITE)
	for _, side in { -1, 1 } do
		local front = screenBottom + Vector3.new(side * 3.1, 0, 0)
		local top = screenTop + Vector3.new(side * 3.1, 0, 0)
		local rear = Vector3.new(side * 3.1, 2.28, 3.0)
		beam("WindshieldPillar", front, top, 0.24, 0.24, WHITE)
		beam("WindowRearFrame", top, rear, 0.2, 0.2, WHITE)
		triangle("SideWindow", front, top, rear, Vector3.new(0, 2.4, 1), GLASS)
		part("CockpitCoaming", Vector3.new(0.35, 0.28, 9.8), CFrame.new(side * 3.3, 2.3, 5.85), WHITE)
		-- Round portholes with a pale rim along the blue hull.
		for _, z in { -2.8, 3.7, 8.1 } do
			local width = 0
			for index = 1, #stations - 1 do
				local a, b = stations[index], stations[index + 1]
				if z >= a.z and z <= b.z then
					local function widthAt(station)
						return station.bottom + (station.width - station.bottom) * (0.85 + 0.72) / (station.top + 0.72)
					end
					width = widthAt(a) + (widthAt(b) - widthAt(a)) * (z - a.z) / (b.z - a.z)
					break
				end
			end
			local rim =
				part("PortholeRim", Vector3.new(0.12, 0.65, 0.65), CFrame.new(side * (width + 0.045), 0.85, z), WHITE)
			rim.Shape = Enum.PartType.Cylinder
			local glass =
				part("PortholeGlass", Vector3.new(0.14, 0.43, 0.43), CFrame.new(side * (width + 0.11), 0.85, z), DARK)
			glass.Shape = Enum.PartType.Cylinder
		end
		-- Low rails follow the pointed bow and stop before the boarding cockpit.
		local railPoints = {
			Vector3.new(side * 0.22, 3.7, -10.5),
			Vector3.new(side * 3.15, 3.3, -8.0),
			Vector3.new(side * 4.4, 3.0, -3.5),
			Vector3.new(side * 4.4, 3.0, -0.9),
		}
		for index, point in railPoints do
			part("BowRailPost", Vector3.new(0.09, 0.75, 0.09), CFrame.new(point - Vector3.new(0, 0.375, 0)), METAL)
			if index > 1 then
				beam("BowRail", railPoints[index - 1], point, 0.1, 0.1, METAL)
			end
		end
		part("SternCushion", Vector3.new(2.15, 0.28, 1.6), CFrame.new(side * 1.6, 1.72, 8.5), BLUE)
		part("SternBackrest", Vector3.new(2.15, 0.95, 0.25), CFrame.new(side * 1.6, 2.24, 9.25), WHITE)
		local passenger = Instance.new("Seat")
		passenger.Size = Vector3.new(2.15, 0.24, 1.6)
		passenger.CFrame = frame * CFrame.new(side * 1.6, 1.87, 8.5)
		passenger.Transparency = 1
		finish(passenger, "PassengerSeat" .. (if side < 0 then "Port" else "Starboard"), BLUE)
		passenger.CanTouch = not isAnchored
		passenger.Disabled = isAnchored
	end

	part("HelmPedestal", Vector3.new(0.5, 0.7, 0.5), CFrame.new(1.6, 1.45, 4.3), METAL)
	part("HelmCushion", Vector3.new(1.8, 0.3, 1.6), CFrame.new(1.6, 1.95, 4.3), BLUE)
	part("HelmBackrest", Vector3.new(1.8, 1.2, 0.25), CFrame.new(1.6, 2.5, 5.0), WHITE)
	local helm = Instance.new("VehicleSeat")
	helm.Size = Vector3.new(1.8, 0.24, 1.6)
	helm.CFrame = frame * CFrame.new(1.6, 2.1, 4.3)
	helm.Transparency = 1
	helm.HeadsUpDisplay = false
	helm.MaxSpeed, helm.Torque, helm.TurnSpeed = 0, 0, 0
	finish(helm, "HelmSeat", BLUE)
	helm.CanTouch = not isAnchored
	helm.Disabled = isAnchored
	part("HelmConsole", Vector3.new(2.3, 1.1, 0.7), CFrame.new(1.6, 1.75, 2.25), WHITE)
	part("InstrumentPanel", Vector3.new(1.9, 0.35, 0.12), CFrame.new(1.6, 2.48, 2.65), DARK)
	local wheelCenter = Vector3.new(1.6, 2.9, 2.95)
	for i = 0, 7 do
		local a, b = i * math.pi / 4, (i + 1) * math.pi / 4
		beam(
			"SteeringWheel",
			wheelCenter + Vector3.new(math.cos(a) * 0.42, math.sin(a) * 0.42, 0),
			wheelCenter + Vector3.new(math.cos(b) * 0.42, math.sin(b) * 0.42, 0),
			0.08,
			0.08,
			DARK
		)
	end
	for i = 0, 2 do
		local angle = i * math.pi * 2 / 3
		beam(
			"WheelSpoke",
			wheelCenter,
			wheelCenter + Vector3.new(math.cos(angle) * 0.4, math.sin(angle) * 0.4, 0),
			0.06,
			0.06,
			METAL
		)
	end
	part("EngineCover", Vector3.new(2.1, 0.55, 1.5), CFrame.new(0, 1.4, 10), WHITE)
	part("SwimPlatform", Vector3.new(5.8, 0.18, 0.8), CFrame.new(0, 0.65, 11.2), WHITE, nil, true)
	for _, x in { -1.7, 1.7 } do
		part("SternCleat", Vector3.new(0.65, 0.12, 0.18), CFrame.new(x, 2.44, 10.3), METAL)
	end
	local lampColor = Color3.fromRGB(239, 247, 255)
	for _, side in { -1, 1 } do
		-- Low cockpit lamps light the deck without obstructing the helm or seats.
		local deckLamp = part(
			"DeckLightLens",
			Vector3.new(0.08, 0.2, 0.55),
			CFrame.new(side * 4.48, 1.7, 4.8),
			lampColor,
			Enum.Material.Neon
		)
		local deckLight = Instance.new("PointLight")
		deckLight.Name = "DeckLight"
		deckLight.Color, deckLight.Range, deckLight.Brightness = lampColor, 16, 0.5
		deckLight.Shadows = false
		deckLight.Parent = deckLamp

		part(
			"HeadlightStand",
			Vector3.new(0.18, 0.7, 0.18),
			CFrame.new(side * 2.4, 2.8, -8),
			METAL,
			Enum.Material.Metal
		)
		part(
			"HeadlightHousing",
			Vector3.new(0.8, 0.46, 0.6),
			CFrame.new(side * 2.4, 3.35, -8),
			DARK,
			Enum.Material.Metal
		)
		local lens = part(
			"HeadlightLens",
			Vector3.new(0.62, 0.3, 0.06),
			CFrame.new(side * 2.4, 3.35, -8.34),
			lampColor,
			Enum.Material.Neon
		)
		lens.CastShadow = false
		local headlight = Instance.new("SpotLight")
		headlight.Name = "Headlight"
		headlight.Face = Enum.NormalId.Front
		headlight.Color, headlight.Range, headlight.Brightness, headlight.Angle = lampColor, 45, 1.2, 65
		headlight.Shadows = false
		headlight.Parent = lens
	end
	return model
end

return Speedboat

end
dependencies.Speedboat = loadSpeedboat()
local function loadRacingSpeedboat()
	-- RACINGSPEEDBOAT_SOURCE --
end
dependencies.RacingSpeedboat = loadRacingSpeedboat()
local function loadPatrolBoat()
	-- PATROLBOAT_SOURCE --
end
dependencies.PatrolBoat = loadPatrolBoat()
local function loadTrawler()
	-- TRAWLER_SOURCE --
end
dependencies.Trawler = loadTrawler()
local function loadShipwright()
	-- Mara is a locally built R6 rig dressed in genuine Roblox Marketplace items.
-- HumanoidDescription applies the catalog shirt, pants, hard hat and tool belt,
-- so those are the real catalog models instead of hand-sculpted lookalikes.
-- Classic faces are no longer sold in the Marketplace, so the head keeps the
-- engine's built-in smile texture. Building the rig locally keeps the shipwright
-- present even when an asset request is slow or unavailable.

local Shipwright = {}

local COSMETICS_VERSION = 3
local SKIN = Color3.fromRGB(216, 164, 119)

-- Verified Marketplace assets (all currently for sale):
--   Shirt  "Mechanic Coveralls +" (navy short-sleeved coverall top)
--   Pants  "Mechanic Coveralls -" (matching trousers and work boots)
--   Hat    "Hard Hat" (yellow construction helmet)
--   Waist  "Tool Belt" (hammer, wrenches and tape measure)
local COSMETICS = {
	Shirt = 6500613508,
	Pants = 6500616492,
	Hat = 9667880157,
	Waist = 12127743738,
}
Shipwright.COSMETICS = COSMETICS

local BODY_PARTS = {
	HumanoidRootPart = true,
	Torso = true,
	Head = true,
	["Right Arm"] = true,
	["Left Arm"] = true,
	["Right Leg"] = true,
	["Left Leg"] = true,
}

-- Also repair baked NPCs without rebuilding the workshop or launch equipment.
function Shipwright.ensureInteraction(model: Model): ProximityPrompt?
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return nil
	end
	local prompt = model:FindFirstChild("TalkToShipwrightPrompt", true)
	if prompt and not prompt:IsA("ProximityPrompt") then
		prompt:Destroy()
		prompt = nil
	end
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TalkToShipwrightPrompt"
	end
	-- The invisible root is inside the torso, where camera occlusion can hide
	-- the prompt. Display it at the head; BoatService checks range, interior and
	-- the player's sightline on the server before opening or buying anything.
	prompt.ActionText = "Talk"
	prompt.ObjectText = "Mara · Shipwright"
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Enabled = true
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.ClickablePrompt = true
	prompt.UIOffset = Vector2.new(0, -30)
	prompt.Parent = head
	return prompt
end

local function createDescription(): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	description.Name = "ShipwrightAppearance"
	description.Shirt = COSMETICS.Shirt
	description.Pants = COSMETICS.Pants
	description.HatAccessory = tostring(COSMETICS.Hat)
	description.WaistAccessory = tostring(COSMETICS.Waist)
	description.HeadColor = SKIN
	description.TorsoColor = SKIN
	description.LeftArmColor = SKIN
	description.RightArmColor = SKIN
	description.LeftLegColor = SKIN
	description.RightLegColor = SKIN
	return description
end

-- Classic faces are retired from the Marketplace, so restore the same built-in
-- smile the previous hand-built Mara used.
local function ensureFace(model: Model)
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local face = head:FindFirstChild("face")
	if face and face:IsA("Decal") then
		return
	end
	local decal = Instance.new("Decal")
	decal.Name = "face"
	decal.Face = Enum.NormalId.Front
	decal.Texture = "rbxasset://textures/face.png"
	decal.Parent = head
end

-- Older baked maps carried the previous hand-modelled costume. Remove those
-- pieces before applying the catalog outfit, otherwise both hats would render.
local function stripLegacyDetails(model: Model)
	for _, item in model:GetDescendants() do
		if item:IsA("Accessory") or item:IsA("Shirt") or item:IsA("Pants") then
			item:Destroy()
		elseif item:IsA("BasePart") and not BODY_PARTS[item.Name] then
			item:Destroy()
		elseif item:IsA("Decal") and item.Name == "face" then
			item:Destroy()
		end
	end
end

-- Applies the Marketplace outfit to a fresh or previously baked shipwright.
-- Returns true once the description has been applied and remembered on the
-- model, so repeated world upgrades do not reload the avatar assets.
function Shipwright.ensureAppearance(model: Model): boolean
	if model:GetAttribute("CosmeticsVersion") == COSMETICS_VERSION then
		return true
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end
	-- Baked shipwrights predate the explicit rig type; keep descriptions on R6.
	humanoid.RigType = Enum.HumanoidRigType.R6

	stripLegacyDetails(model)

	local description = createDescription()
	local applied, reason = pcall(function()
		humanoid:ApplyDescriptionAsync(description)
	end)
	description:Destroy()
	-- Keep a readable face even if the catalog request failed.
	ensureFace(model)
	if not applied then
		warn("Shipwright Marketplace cosmetics failed to load: " .. tostring(reason))
		return false
	end

	-- Applying before the model is parented can silently skip the accessories.
	-- Report that as unfinished so the caller's post-parent retry runs.
	local hasShirt, hasPants, hasAccessory = false, false, false
	for _, item in model:GetDescendants() do
		if item:IsA("Shirt") then
			hasShirt = true
		elseif item:IsA("Pants") then
			hasPants = true
		elseif item:IsA("Accessory") then
			hasAccessory = true
		end
	end
	if not (hasShirt and hasPants and hasAccessory) then
		warn("Shipwright Marketplace cosmetics did not fully attach; retrying after parenting")
		return false
	end

	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.CanCollide = false
			item.CanTouch = false
			item.Massless = true
			item.Anchored = item.Name == "HumanoidRootPart"
			if item.Name == "HumanoidRootPart" then
				item.CanQuery = false
				item.CastShadow = false
			end
		end
	end

	model:SetAttribute("CosmeticsVersion", COSMETICS_VERSION)
	return true
end

-- frame is at the soles of the boots. The rig looks along its local -Z axis.
function Shipwright.build(frame: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Shipwright"
	model:SetAttribute("NpcName", "Mara")
	model:SetAttribute("Role", "Shipwright")

	local function part(name: string, size: Vector3, offset: CFrame, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = frame * offset
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false
		p.CanTouch = false
		p.Massless = true
		p.Parent = model
		return p
	end

	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), SKIN)
	root.Transparency = 1
	root.CanQuery = false
	root.Anchored = true
	root.CastShadow = false
	local torso = part("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), SKIN)
	local head = part("Head", Vector3.new(2, 1, 1), CFrame.new(0, 4.5, 0), SKIN)
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.1, 1.1, 1.1)
	headMesh.Parent = head

	local rightArm = part("Right Arm", Vector3.new(1, 2, 1), CFrame.new(1.5, 3, 0), SKIN)
	local leftArm = part("Left Arm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 3, 0), SKIN)
	local rightLeg = part("Right Leg", Vector3.new(1, 2, 1), CFrame.new(0.5, 1, 0), SKIN)
	local leftLeg = part("Left Leg", Vector3.new(1, 2, 1), CFrame.new(-0.5, 1, 0), SKIN)

	-- Standard R6 attachment points, copied from Roblox's own R6 character.
	-- Humanoid:ApplyDescription welds catalog accessories to the attachment that
	-- shares their name, so the hard hat and tool belt land in the right place.
	local function attach(bodyPart: BasePart, name: string, offset: Vector3)
		local point = Instance.new("Attachment")
		point.Name = name
		point.CFrame = CFrame.new(offset.X, offset.Y, offset.Z)
		point.Parent = bodyPart
	end
	attach(head, "FaceCenterAttachment", Vector3.new(0, 0, 0))
	attach(head, "FaceFrontAttachment", Vector3.new(0, 0, -0.6))
	attach(head, "HairAttachment", Vector3.new(0, 0.6, 0))
	attach(head, "HatAttachment", Vector3.new(0, 0.6, 0))
	attach(torso, "BodyBackAttachment", Vector3.new(0, 0, 0.5))
	attach(torso, "BodyFrontAttachment", Vector3.new(0, 0, -0.5))
	attach(torso, "LeftCollarAttachment", Vector3.new(-1, 1, 0))
	attach(torso, "NeckAttachment", Vector3.new(0, 1, 0))
	attach(torso, "RightCollarAttachment", Vector3.new(1, 1, 0))
	attach(torso, "WaistBackAttachment", Vector3.new(0, -1, 0.5))
	attach(torso, "WaistCenterAttachment", Vector3.new(0, -1, 0))
	attach(torso, "WaistFrontAttachment", Vector3.new(0, -1, -0.5))
	attach(rightArm, "RightShoulderAttachment", Vector3.new(0, 1, 0))
	attach(leftArm, "LeftShoulderAttachment", Vector3.new(0, 1, 0))

	-- Standard R6 joint names and positions keep all six body parts on one rig.
	local function motor(name: string, a: BasePart, b: BasePart, offset: CFrame)
		local joint = Instance.new("Motor6D")
		joint.Name = name
		joint.Part0 = a
		joint.Part1 = b
		local jointFrame = frame * offset
		joint.C0 = a.CFrame:ToObjectSpace(jointFrame)
		joint.C1 = b.CFrame:ToObjectSpace(jointFrame)
		joint.Parent = a
	end
	motor("RootJoint", root, torso, CFrame.new(0, 3, 0))
	motor("Neck", torso, head, CFrame.new(0, 4, 0))
	motor("Right Shoulder", torso, rightArm, CFrame.new(1, 3.5, 0))
	motor("Left Shoulder", torso, leftArm, CFrame.new(-1, 3.5, 0))
	motor("Right Hip", torso, rightLeg, CFrame.new(0.5, 2, 0))
	motor("Left Hip", torso, leftLeg, CFrame.new(-0.5, 2, 0))

	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayName = "Mara · Shipwright"
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
	humanoid.BreakJointsOnDeath = false
	humanoid.NameDisplayDistance = 28
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = model

	model.PrimaryPart = root
	Shipwright.ensureAppearance(model)
	Shipwright.ensureInteraction(model)
	return model
end

return Shipwright

end
dependencies.Shipwright = loadShipwright()
local function loadDrydockInterior()
	-- Fixed, hand-placed workshop dressing. Coordinates share Drydock's floor frame:
-- the walking surface is Y=2, the repair basin is on the left, and visitors
-- approach the counter from -Z. Small details never participate in physics.
local Props = dependencies.Props

local Interior = {}
local VERSION = 1
local rgb, V, A = Color3.fromRGB, Vector3.new, CFrame.Angles
local M = Enum.Material
local STEEL = rgb(47, 58, 64)
local SILVER = rgb(169, 181, 182)
local BLACK = rgb(29, 35, 37)
local TEAL = rgb(46, 96, 105)
local RED = rgb(164, 62, 45)
local YELLOW = rgb(232, 184, 48)
local CREAM = rgb(234, 225, 196)
local WOOD = rgb(139, 104, 65)
local ROPE = rgb(171, 145, 99)
local RUST = rgb(115, 71, 46)

function Interior.ensure(shop: Model, frame: CFrame)
	local existing = shop:FindFirstChild("InteriorDetails")
	if existing and existing:GetAttribute("DetailVersion") == VERSION then
		return
	end
	if existing then
		existing:Destroy()
	end
	-- Replace the original block-shaped tools and gas bottle on baked maps too.
	for _, item in shop:GetChildren() do
		if table.find({ "HangingWrench", "WrenchJaw", "WeldingCylinder", "CylinderValve" }, item.Name) then
			item:Destroy()
		end
	end
	local root = Instance.new("Model")
	root.Name = "InteriorDetails"
	root.Parent = shop
	local parent: Model = root
	local function group(name: string)
		local model = Instance.new("Model")
		model.Name, model.Parent = name, root
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		parent = model
	end
	local function p(
		name: string,
		size: Vector3,
		x: number,
		y: number,
		z: number,
		color: Color3,
		material: Enum.Material?,
		spin: CFrame?
	): Part
		local item =
			Props.part(parent, size, frame * CFrame.new(x, y, z) * (spin or CFrame.new()), color, material or M.Metal)
		item.Name = name
		item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
		item.CastShadow = size.X * size.Y * size.Z > 0.12
		return item
	end
	local function solid(item: Part): Part
		item.CanCollide, item.CanQuery = true, true
		return item
	end
	local function rod(
		name: string,
		a: Vector3,
		b: Vector3,
		diameter: number,
		color: Color3,
		material: Enum.Material?
	): Part
		local delta = b - a
		local spin =
			CFrame.lookAt((a + b) / 2, b, if math.abs(delta.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis)
		local item = p(name, V(delta.Magnitude, diameter, diameter), 0, 0, 0, color, material)
		item.Shape = Enum.PartType.Cylinder
		item.CFrame = frame * spin * A(0, math.pi / 2, 0)
		return item
	end
	local function ring(
		name: string,
		center: Vector3,
		radius: number,
		thickness: number,
		color: Color3,
		orientation: CFrame?,
		segments: number?
	)
		local basis = CFrame.new(center) * (orientation or CFrame.new())
		local count = segments or 12
		for i = 1, count do
			local a, b = (i - 1) * math.pi * 2 / count, i * math.pi * 2 / count
			rod(
				name,
				basis * V(math.cos(a) * radius, math.sin(a) * radius, 0),
				basis * V(math.cos(b) * radius, math.sin(b) * radius, 0),
				thickness,
				color,
				if color == ROPE
					then M.Fabric
					elseif color == SILVER or color == YELLOW then M.Metal
					else M.SmoothPlastic
			)
		end
	end
	local function sign(
		name: string,
		text: string,
		x: number,
		y: number,
		z: number,
		width: number,
		height: number,
		background: Color3,
		ink: Color3?,
		spin: CFrame?
	)
		local panel = p(name, V(width, height, 0.09), x, y, z, background, M.SmoothPlastic, spin)
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.SizingMode, gui.PixelsPerStud = Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, 44
		gui.Parent = panel
		local label = Instance.new("TextLabel")
		label.Size, label.Position = UDim2.fromScale(0.9, 0.86), UDim2.fromScale(0.05, 0.07)
		label.BackgroundTransparency = 1
		label.Text, label.TextColor3 = text, ink or CREAM
		label.Font, label.TextScaled = Enum.Font.GothamBold, true
		label.Parent = gui
		return panel
	end
	local function gauge(name: string, x: number, y: number, z: number, radius: number, needleAngle: number)
		rod(name .. "Rim", V(x, y, z - 0.05), V(x, y, z + 0.1), radius * 2, SILVER)
		rod(name .. "Face", V(x, y, z - 0.07), V(x, y, z - 0.1), radius * 1.7, CREAM)
		for i = 0, 6 do
			local angle = math.rad(30 + i * 40)
			p(
				name .. "Tick",
				V(0.035, radius * 0.2, 0.025),
				x + math.sin(angle) * radius * 0.65,
				y + math.cos(angle) * radius * 0.65,
				z - 0.12,
				BLACK,
				nil,
				A(0, 0, -angle)
			)
		end
		p(name .. "Needle", V(0.04, radius * 1.1, 0.025), x, y, z - 0.14, RED, nil, A(0, 0, needleAngle))
	end
	local function hose(name: string, points: { Vector3 }, diameter: number, color: Color3)
		for i = 2, #points do
			rod(name, points[i - 1], points[i], diameter, color, M.SmoothPlastic)
		end
	end

	-- The existing bench becomes a fitted tool station with drawers, a perforated
	-- board, recognizable hand tools, vise hardware, and a repair in progress.
	group("ToolStation")
	for _, x in { 10.9, 16.1 } do
		p("BenchDrawerCabinet", V(2.1, 2.3, 2.4), x, 3.6, 9, TEAL)
		for y = 2.9, 4.4, 0.5 do
			p("BenchDrawer", V(1.94, 0.41, 0.12), x, y, 7.75, STEEL)
			p("DrawerPull", V(0.85, 0.09, 0.16), x, y + 0.02, 7.64, SILVER)
		end
	end
	p("BenchLowerShelf", V(7.2, 0.16, 2.4), 13.5, 2.55, 9, WOOD, M.WoodPlanks)
	p("BenchTimberTop", V(8.2, 0.18, 3.1), 13.5, 5.43, 9, WOOD, M.WoodPlanks)
	for _, x in { 9.3, 17.7 } do
		p("PegboardFrame", V(0.14, 4.2, 0.2), x, 7.5, 10.26, SILVER)
	end
	for _, y in { 5.42, 9.58 } do
		p("PegboardFrame", V(8.5, 0.14, 0.2), 13.5, y, 10.26, SILVER)
	end
	for x = 9.8, 17.2, 0.55 do
		for y = 5.85, 9.2, 0.55 do
			p("PegboardHole", V(0.065, 0.065, 0.018), x, y, 10.337, BLACK)
		end
	end
	for i = 1, 4 do
		local x, length = 9.7 + i * 0.7, 1 + i * 0.2
		rod("SpannerShaft", V(x, 8.75, 10.07), V(x, 8.75 - length, 10.07), 0.14, SILVER)
		for _, side in { -1, 1 } do
			p("SpannerOpenJaw", V(0.13, 0.34, 0.16), x + side * 0.18, 8.89, 10.07, SILVER, nil, A(0, 0, -side * 0.22))
		end
		ring("SpannerBoxEnd", V(x, 8.66 - length, 10.07), 0.17, 0.09, SILVER, nil, 6)
		p("ToolPeg", V(0.08, 0.08, 0.28), x, 8.87, 10.19, BLACK)
	end
	for i = 1, 3 do
		local x = 13.4 + i * 0.55
		rod("ScrewdriverShaft", V(x, 7.1, 10.03), V(x, 8.05, 10.03), 0.065, SILVER)
		rod("ScrewdriverHandle", V(x, 8.05, 10.03), V(x, 8.65, 10.03), 0.22, if i == 2 then YELLOW else RED)
	end
	p("HangingHammerHandle", V(0.14, 1.6, 0.18), 16.15, 8, 10.03, WOOD, M.Wood)
	p("HangingHammerHead", V(0.9, 0.3, 0.3), 16.15, 8.75, 10.03, SILVER)
	p("HandsawBlade", V(1.85, 0.6, 0.08), 13.65, 6.45, 10.06, SILVER, nil, A(0, 0, -0.12))
	p("HandsawHandle", V(0.55, 0.75, 0.15), 14.82, 6.53, 10.05, WOOD, M.Wood)
	for x = 12.8, 14.4, 0.18 do
		p("SawTooth", V(0.12, 0.12, 0.08), x, 6.08 - (x - 13.65) * 0.12, 10.06, SILVER, nil, A(0, 0, math.pi / 4))
	end
	rod("ViseThread", V(15.1, 5.86, 8.25), V(16.5, 5.86, 8.25), 0.14, SILVER)
	rod("ViseCrank", V(16.6, 5.47, 8.25), V(16.6, 6.25, 8.25), 0.1, BLACK)
	for i = 1, 7 do
		p("ViseScrewThread", V(0.035, 0.22, 0.22), 15.45 + i * 0.11, 5.86, 8.25, BLACK)
	end
	p("RepairTimber", V(1.75, 0.15, 0.75), 15.8, 6.4, 8.8, WOOD, M.Wood, A(0, 0.12, 0))
	p("BenchCuttingMat", V(2.5, 0.04, 1.9), 12.6, 5.55, 8.7, rgb(46, 83, 72), M.SmoothPlastic)
	for x = 11.6, 13.6, 0.4 do
		p("CuttingMatGrid", V(0.018, 0.012, 1.7), x, 5.578, 8.7, rgb(108, 137, 111))
	end
	p("BenchPlaneBody", V(0.55, 0.3, 1.1), 12.1, 5.75, 8.55, STEEL, nil, A(0, -0.3, 0))
	p("BenchPlaneGrip", V(0.15, 0.38, 0.25), 12.1, 6.03, 8.8, WOOD, M.Wood)
	rod("GlueBottle", V(10, 5.55, 9.3), V(10, 6.12, 9.3), 0.38, CREAM)
	p("GlueNozzle", V(0.12, 0.22, 0.12), 10, 6.22, 9.3, RED)
	p("FoldedShopRag", V(0.75, 0.08, 0.6), 14.6, 5.56, 9.4, rgb(120, 148, 143), M.Fabric, A(0, 0.3, 0))
	for i = 1, 5 do
		p("TimberOffcut", V(0.3, 0.13, 1.1 + i * 0.1), 11.9 + i * 0.45, 2.72, 9.1, WOOD, M.Wood, A(0, i * 0.12, 0))
	end
	sign("ToolStationLabel", "HAND TOOLS  /  RETURN AFTER USE", 13.5, 9.88, 10.18, 7.6, 0.45, TEAL)

	group("PartsStores")
	local binLabels = { "BOLTS", "CLEATS", "HINGES", "FITTINGS" }
	for level = 0, 2 do
		local shelfY = 2.3 + level * 3.5
		for i = 1, 4 do
			local x = 5 + i * 3
			sign("PartsBinLabel", binLabels[i], x, shelfY + 0.65, 16.56, 1.65, 0.38, CREAM, BLACK)
			-- Visible contents sit above the original open storage-bin rims.
			for k = 1, 3 do
				local px = x - 0.62 + k * 0.3
				if i == 1 then
					rod("StoredBolt", V(px, shelfY + 1.14, 17.1), V(px + 0.15, shelfY + 1.48, 17.65), 0.12, SILVER)
				elseif i == 2 then
					p("StoredCleat", V(0.5, 0.12, 0.2), px, shelfY + 1.36, 17.5, SILVER, nil, A(0, k * 0.35, 0))
				else
					p(
						"StoredFitting",
						V(0.3, 0.3, 0.35),
						px,
						shelfY + 1.35,
						17.4,
						if i == 3 then SILVER else RUST,
						nil,
						A(0, k * 0.4, 0.2)
					)
				end
			end
		end
	end
	for _, x in { 6, 18.7 } do
		for y = 2.8, 9.8, 0.6 do
			p("RackAdjustmentSlot", V(0.08, 0.18, 0.025), x, y, 17.23, BLACK)
		end
	end
	sign("StoresHeader", "MARINE PARTS  /  STORES", 12.3, 11, 17.45, 12, 0.85, TEAL)
	-- Spare shaft, flanged pipe sections, and a strapped service crate.
	rod("SparePropShaft", V(6.8, 10.05, 17.7), V(17.5, 10.05, 17.7), 0.18, SILVER)
	for _, x in { 7.5, 10.5, 13.5, 16.5 } do
		p("ShaftRackSaddle", V(0.35, 0.35, 1), x, 9.7, 17.65, BLACK)
	end
	solid(p("ServiceCrate", V(2.2, 1.9, 2.1), 18.9, 2.95, -9.9, WOOD, M.WoodPlanks))
	for _, x in { 18.15, 19.65 } do
		p("CrateStrapping", V(0.1, 1.94, 2.13), x, 2.95, -9.9, STEEL)
	end
	sign("CrateStamp", "MARINE\nSPARES", 18.9, 3.05, -10.98, 1.25, 0.8, WOOD, BLACK)

	group("WeldingBay")
	-- A two-bottle trolley replaces the single square placeholder cylinder.
	solid(p("WeldingCartBase", V(2.3, 0.22, 2.2), 18.35, 2.4, 12.9, STEEL, M.DiamondPlate))
	for _, x in { 17.35, 19.35 } do
		rod("WeldingCartWheel", V(x - 0.12, 2.4, 13.45), V(x + 0.12, 2.4, 13.45), 0.64, BLACK)
		rod("WeldingCartHandle", V(x, 2.5, 13.65), V(x, 6.25, 13.65), 0.14, STEEL)
	end
	rod("WeldingCartGrip", V(17.35, 6.25, 13.65), V(19.35, 6.25, 13.65), 0.16, BLACK)
	for i = 1, 2 do
		local x, height = 17.7 + (i - 1) * 1.2, if i == 1 then 3.5 else 2.9
		local top = 2.55 + height
		solid(rod("GasBottle", V(x, 2.55, 12.9), V(x, top, 12.9), 0.88, if i == 1 then TEAL else RED))
		rod("GasBottleShoulder", V(x, top, 12.9), V(x, top + 0.22, 12.9), 0.57, SILVER)
		rod("GasBottleValve", V(x, top + 0.2, 12.9), V(x, top + 0.53, 12.9), 0.16, ROPE)
		p("GasValveWheel", V(0.5, 0.08, 0.38), x, top + 0.55, 12.9, RED)
		gauge("Regulator", x, top + 0.25, 12.5, 0.22, -0.65)
		p("CylinderRetainingStrap", V(1.1, 0.16, 1.02), x, 4.7, 12.9, BLACK)
	end
	solid(p("WelderCabinet", V(1.6, 1.6, 2.1), 19, 2.98, 8.1, RED))
	p("WelderTopHandle", V(0.9, 0.15, 0.15), 19, 3.99, 8.1, BLACK)
	for i = 1, 5 do
		p("WelderVent", V(0.9, 0.07, 0.03), 19, 2.5 + i * 0.18, 7.03, BLACK)
	end
	rod("WelderDial", V(18.6, 3.42, 7.01), V(18.6, 3.42, 6.9), 0.24, BLACK)
	sign("WelderReadout", "135 A", 19.25, 3.45, 6.98, 0.5, 0.25, BLACK, YELLOW)
	ring("WeldingHoseCoil", V(19.2, 5.35, 12.05), 0.65, 0.12, BLACK)
	hose(
		"WeldingLead",
		{ V(19, 2.7, 7), V(18.5, 2.14, 6.6), V(17.7, 2.14, 7.2), V(17.7, 4.2, 9.6), V(17, 5.55, 9.5) },
		0.11,
		BLACK
	)
	p("WeldingTorchHandle", V(0.16, 0.16, 0.7), 17, 5.65, 9.3, BLACK)
	rod("WeldingTorchNozzle", V(17, 5.65, 8.95), V(16.8, 5.65, 8.65), 0.09, ROPE)
	p("WeldingMaskShell", V(0.75, 0.95, 0.5), 17.1, 6.15, 9.55, BLACK, M.SmoothPlastic, A(-0.25, 0.15, 0))
	p("WeldingMaskLens", V(0.52, 0.26, 0.04), 17.1, 6.24, 9.23, rgb(56, 94, 85), M.Glass)
	sign(
		"WeldingSafety",
		"WELDING AREA\nEYE PROTECTION REQUIRED",
		19.95,
		8.1,
		12.7,
		3.4,
		1.6,
		YELLOW,
		BLACK,
		A(0, math.pi / 2, 0)
	)

	group("MachiningAndToolCart")
	solid(p("DrillPressBase", V(2.2, 0.24, 2.3), 19, 2.15, 1.7, STEEL))
	rod("DrillPressColumn", V(19, 2.25, 2.5), V(19, 7.2, 2.5), 0.3, SILVER)
	p("DrillPressTable", V(1.9, 0.18, 1.9), 19, 4.55, 1.7, STEEL)
	for _, x in { 18.5, 19.5 } do
		p("DrillTableSlot", V(0.09, 0.02, 1.5), x, 4.65, 1.7, BLACK)
	end
	p("DrillPressHead", V(1.15, 0.85, 1.8), 19, 6.7, 1.8, TEAL)
	p("DrillBeltCover", V(1.3, 0.28, 2.35), 19, 7.24, 2.1, TEAL)
	rod("DrillMotor", V(19, 6, 2.8), V(19, 7, 2.8), 0.8, BLACK)
	rod("DrillChuck", V(19, 5.8, 1.35), V(19, 6.35, 1.35), 0.3, SILVER)
	rod("DrillBit", V(19, 4.95, 1.35), V(19, 5.8, 1.35), 0.08, BLACK)
	p("DrillWorkpiece", V(1.1, 0.12, 0.8), 19, 4.72, 1.45, WOOD, M.Wood)
	for i = 1, 3 do
		local angle = i * math.pi * 2 / 3
		rod(
			"DrillFeedHandle",
			V(18.32, 6.4, 2),
			V(18.32, 6.4 + math.sin(angle) * 0.65, 2 + math.cos(angle) * 0.65),
			0.08,
			SILVER
		)
		rod(
			"DrillFeedGrip",
			V(18.32, 6.4 + math.sin(angle) * 0.6, 2 + math.cos(angle) * 0.6),
			V(18.32, 6.4 + math.sin(angle) * 0.8, 2 + math.cos(angle) * 0.8),
			0.18,
			BLACK
		)
	end
	sign(
		"DrillPressLabel",
		"BENCH DRILL\nCLAMP WORK BEFORE DRILLING",
		19.95,
		9.1,
		2.4,
		3.9,
		1.1,
		TEAL,
		CREAM,
		A(0, math.pi / 2, 0)
	)
	solid(p("RollingToolCabinet", V(2.5, 2.1, 1.6), 14.1, 3.4, 13.2, RED))
	for _, x in { 13.1, 15.1 } do
		for _, z in { 12.6, 13.8 } do
			rod("ToolCartCastor", V(x - 0.1, 2.22, z), V(x + 0.1, 2.22, z), 0.42, BLACK)
		end
	end
	for y = 2.7, 4.1, 0.35 do
		p("ToolCartDrawer", V(2.24, 0.27, 0.1), 14.1, y, 12.35, RED)
		p("ToolCartDrawerHandle", V(1.6, 0.06, 0.1), 14.1, y + 0.03, 12.24, SILVER)
	end
	p("ToolCartRubberTop", V(2.6, 0.08, 1.7), 14.1, 4.5, 13.2, BLACK)
	for i = 1, 6 do
		rod(
			"SocketSet",
			V(13.15 + i * 0.26, 4.56, 13.5),
			V(13.15 + i * 0.26, 4.78 + i * 0.03, 13.5),
			0.15 + i * 0.014,
			SILVER
		)
	end
	rod("SocketRail", V(13.25, 4.57, 13.5), V(14.9, 4.57, 13.5), 0.08, STEEL)
	p("RatchetHandle", V(1.1, 0.09, 0.15), 14.1, 4.6, 12.9, SILVER, nil, A(0, 0.2, 0))
	rod("RatchetHead", V(14.65, 4.57, 12.8), V(14.65, 4.69, 12.8), 0.3, SILVER)

	group("CompressorAndServices")
	-- Left-rear wall equipment is tucked outboard of the basin-side walking lane.
	solid(rod("CompressorTank", V(-19, 3.05, 8.6), V(-19, 3.05, 12.1), 1.55, TEAL))
	for _, z in { 9.1, 11.6 } do
		p("CompressorFoot", V(1.7, 0.45, 0.45), -19, 2.23, z, BLACK)
	end
	p("CompressorMotor", V(0.95, 0.65, 1.3), -19, 4.12, 10.65, STEEL)
	for z = 10.1, 11.2, 0.18 do
		p("CompressorCoolingFin", V(1.1, 0.08, 0.08), -19, 4.37, z, SILVER)
	end
	gauge("AirPressure", -18.8, 4.55, 9.65, 0.3, 0.65)
	rod("AirOutlet", V(-18.8, 3.9, 9.8), V(-18.8, 4.3, 9.8), 0.13, ROPE)
	ring("AirHoseReel", V(-20, 6.7, 11.2), 0.9, 0.16, YELLOW, A(0, math.pi / 2, 0))
	ring("AirHose", V(-19.82, 6.7, 11.2), 0.65, 0.11, BLACK, A(0, math.pi / 2, 0))
	hose("AirHoseTail", { V(-19.8, 6.1, 11.2), V(-19.6, 5.2, 11.6), V(-19, 4.15, 11.8) }, 0.11, BLACK)
	-- Overhead mains, elbows, clamps, and downpipes make the shell feel serviced.
	for _, side in { -1, 1 } do
		local x = side * 19.8
		rod("ServiceAirMain", V(x, 10.65, -17), V(x, 10.65, 17.5), 0.2, TEAL)
		rod("ElectricalConduit", V(x, 11.2, -17), V(x, 11.2, 17.5), 0.1, SILVER)
		for z = -16, 16, 4 do
			p("PipeWallBracket", V(0.65, 0.1, 0.5), x, 10.48, z, STEEL)
			p("PipeClamp", V(0.1, 0.36, 0.35), x, 10.65, z, SILVER)
		end
	end
	rod("RearServiceMain", V(-19.8, 10.65, 18.5), V(19.8, 10.65, 18.5), 0.2, TEAL)
	for _, x in { -19.8, 19.8 } do
		rod("ServiceMainElbow", V(x, 10.65, 17.5), V(x, 10.65, 18.5), 0.23, TEAL)
	end
	rod("CompressorRiser", V(-19.8, 4, 9), V(-19.8, 10.65, 9), 0.17, TEAL)
	rod("AirTapDrop", V(19.8, 10.65, 5), V(19.8, 5.1, 5), 0.15, TEAL)
	ring("IsolationValve", V(-19.55, 5.3, 9), 0.32, 0.09, RED, A(0, math.pi / 2, 0), 8)
	solid(p("ElectricalCabinet", V(0.75, 3, 2.6), -19.9, 6.7, -13.7, STEEL))
	p("ElectricalDoor", V(0.07, 2.75, 2.38), -19.48, 6.7, -13.7, rgb(112, 126, 125))
	p("CabinetLatch", V(0.18, 0.7, 0.1), -19.36, 6.5, -12.95, BLACK)
	sign("ElectricalWarning", "DANGER\nHIGH VOLTAGE", -19.39, 7.1, -13.8, 1.7, 1, YELLOW, BLACK, A(0, -math.pi / 2, 0))
	rod("CabinetConduit", V(-19.9, 8.2, -13.7), V(-19.9, 11.2, -13.7), 0.14, SILVER)
	-- Rear extractor: deep housing, circular guard, hub and six pitched blades.
	p("ExtractorHousing", V(3.4, 3.1, 0.45), 0.7, 11.5, 18.7, STEEL)
	rod("ExtractorRecess", V(0.7, 11.5, 18.37), V(0.7, 11.5, 18.55), 2.7, BLACK)
	for i = 1, 6 do
		local angle = i * math.pi / 3
		p(
			"ExtractorBlade",
			V(0.44, 1.1, 0.13),
			0.7 + math.sin(angle) * 0.62,
			11.5 + math.cos(angle) * 0.62,
			18.23,
			SILVER,
			nil,
			A(0, 0, -angle + 0.35)
		)
	end
	rod("ExtractorHub", V(0.7, 11.5, 18.07), V(0.7, 11.5, 18.3), 0.46, TEAL)
	ring("ExtractorGuard", V(0.7, 11.5, 18.03), 1.34, 0.09, SILVER)
	for i = -2, 2 do
		p("ExtractorGuardBar", V(2.4, 0.035, 0.035), 0.7, 11.5 + i * 0.37, 17.96, SILVER)
	end

	group("TimberAndRigging")
	-- Vertical wall racks keep the narrow west catwalk usable.
	for _, z in { -7, 3.6 } do
		p("TimberRackUpright", V(0.3, 6, 0.3), -20, 5, z, STEEL)
		for _, y in { 3, 5.25, 7.5 } do
			p("TimberRackArm", V(1.7, 0.16, 0.3), -19.3, y, z, STEEL)
			p("TimberRackLip", V(0.12, 0.35, 0.3), -18.5, y + 0.16, z, STEEL)
		end
	end
	for level = 0, 2 do
		for i = 1, 3 do
			p(
				"SeasonedBoatTimber",
				V(0.36, 0.22, 10.5 - i * 0.5),
				-19.85 + i * 0.43,
				3.2 + level * 2.25,
				-1.7 + i * 0.2,
				if i == 2 then rgb(176, 139, 86) else WOOD,
				M.Wood
			)
		end
	end
	sign(
		"TimberRackLabel",
		"SEASONED OAK  /  HULL REPAIRS",
		-19.98,
		9,
		-1.5,
		6.8,
		0.65,
		TEAL,
		CREAM,
		A(0, -math.pi / 2, 0)
	)
	for i = 1, 3 do
		local x = -11.8 + (i - 1) * 2.4
		p("OarRackHook", V(0.55, 0.18, 0.65), x, 5.25, 18.5, STEEL)
		rod("SpareOarShaft", V(x, 3.2, 18.3), V(x, 9, 18.3), 0.16, WOOD, M.Wood)
		p("SpareOarBlade", V(0.65, 1.65, 0.16), x, 9.45, 18.3, CREAM, M.Wood)
		p("OarBladePaint", V(0.67, 0.3, 0.18), x, 9.8, 18.3, TEAL)
	end
	for i = 1, 2 do
		local x = -3.6 + (i - 1) * 2.1
		p("RopeHanger", V(0.8, 0.18, 0.65), x, 6.8, 18.45, STEEL)
		for layer = 1, 3 do
			ring("HangingMooringRope", V(x, 5.9, 18.1 - layer * 0.11), 0.78 - layer * 0.09, 0.12, ROPE)
		end
		hose("RopeLooseEnd", { V(x + 0.3, 5.2, 17.85), V(x + 0.2, 4.5, 17.85), V(x + 0.45, 4.2, 17.85) }, 0.1, ROPE)
	end
	solid(p("RiggingChest", V(3.5, 1.65, 2.1), -17.7, 2.83, 16.8, WOOD, M.WoodPlanks))
	p("ChestLid", V(3.65, 0.15, 2.22), -17.7, 3.73, 16.8, WOOD, M.Wood)
	for _, x in { -18.9, -16.5 } do
		p("ChestIronBand", V(0.16, 1.7, 2.14), x, 2.85, 16.8, STEEL)
	end
	sign("RiggingChestLabel", "RIGGING", -17.7, 3, 15.7, 1.8, 0.5, STEEL)
	-- A spare propeller is a workshop landmark, mounted above the stores.
	rod("PropellerDisplayHub", V(19.8, 7.1, -2), V(19.3, 7.1, -2), 0.65, ROPE)
	for i = 1, 3 do
		local angle = i * math.pi * 2 / 3
		p(
			"SparePropellerBlade",
			V(0.14, 1.55, 0.72),
			19.38,
			7.1 + math.cos(angle) * 0.8,
			-2 + math.sin(angle) * 0.8,
			ROPE,
			nil,
			A(angle, 0, 0)
		)
	end
	sign(
		"PropellerLabel",
		"RECONDITIONED\nMARINE PROPELLERS",
		19.9,
		9.2,
		-2,
		4.4,
		0.9,
		TEAL,
		CREAM,
		A(0, math.pi / 2, 0)
	)

	group("ShipwrightOffice")
	-- A little planning desk against the front wall, facing into the workshop.
	solid(p("PlanningDesk", V(5, 0.26, 2.6), 16.3, 4.7, -17.3, WOOD, M.WoodPlanks))
	for _, x in { 14.15, 18.45 } do
		p("PlanningDeskLeg", V(0.25, 2.6, 2.2), x, 3.3, -17.3, STEEL)
	end
	p("DeskDrawer", V(2.2, 0.7, 2.2), 17.5, 4.16, -17.3, TEAL)
	p("DeskDrawerPull", V(0.8, 0.1, 0.15), 17.5, 4.18, -16.12, SILVER)
	p("BlueprintSheet", V(2.6, 0.025, 1.65), 15.7, 4.85, -17.2, rgb(54, 95, 128), M.SmoothPlastic)
	for _, side in { -1, 1 } do
		hose("BlueprintHullLines", {
			V(15.7, 4.87, -17.9),
			V(15.7 + side * 0.65, 4.87, -17.55),
			V(15.7 + side * 0.75, 4.87, -16.65),
			V(15.7, 4.87, -16.5),
		}, 0.025, CREAM)
	end
	for z = -17.6, -16.7, 0.3 do
		p("BlueprintFrameLines", V(1.15, 0.012, 0.02), 15.7, 4.88, z, CREAM)
	end
	for _, z in { -18.03, -16.4 } do
		rod("BlueprintRolledEdge", V(14.4, 4.9, z), V(17, 4.9, z), 0.12, CREAM)
	end
	p("DeskLedger", V(0.9, 0.14, 1.15), 18.05, 4.91, -17.4, BLACK, M.Fabric, A(0, -0.2, 0))
	rod("DeskPencil", V(16.8, 4.91, -16.55), V(17.45, 4.91, -16.9), 0.045, YELLOW)
	rod("EnamelMug", V(18.15, 4.86, -16.55), V(18.15, 5.25, -16.55), 0.38, CREAM)
	rod("MugCoffee", V(18.15, 5.252, -16.55), V(18.15, 5.27, -16.55), 0.3, rgb(63, 42, 30))
	ring("MugHandle", V(18.43, 5.06, -16.55), 0.14, 0.065, CREAM, nil, 8)
	-- Noticeboard on the inward-facing side of the front wall.
	p("JobBoardFrame", V(6.5, 3.8, 0.18), 14.8, 8, -18.9, WOOD, M.Wood)
	p("JobBoardCork", V(6.2, 3.5, 0.08), 14.8, 8, -18.76, rgb(127, 99, 66), M.Wood)
	for i, entry in
		{
			"JOB 014\nHULL RESEAL\nIN PROGRESS",
			"JOB 015\nENGINE SERVICE\nAWAITING PARTS",
			"TIDE TABLE\nCHECK BEFORE\nLAUNCH",
		}
	do
		local x = 12.65 + i * 1.1
		sign("PinnedJobSheet", entry, x, 8, -18.66, 0.98, 1.8, CREAM, BLACK, A(0, math.pi, 0))
		p("NoticeboardPin", V(0.09, 0.09, 0.06), x, 8.77, -18.55, RED)
	end
	sign("JobBoardHeader", "SHIPWRIGHT  /  WORK ORDERS", 14.8, 9.39, -18.64, 5.6, 0.5, TEAL, CREAM, A(0, math.pi, 0))
	-- Counter detail stays behind its visitor edge and leaves the NPC visible.
	p("CounterLedger", V(1.1, 0.1, 0.85), 10.2, 4.84, -3.9, CREAM, M.SmoothPlastic, A(0, 0.15, 0))
	p("CounterPen", V(0.7, 0.05, 0.05), 10.3, 4.91, -3.95, BLACK, nil, A(0, 0.3, 0))
	rod("CounterBellBase", V(14.5, 4.79, -4.1), V(14.5, 4.88, -4.1), 0.68, BLACK)
	rod("CounterBell", V(14.5, 4.88, -4.1), V(14.5, 5.15, -4.1), 0.48, ROPE)
	rod("BellPlunger", V(14.5, 5.15, -4.1), V(14.5, 5.27, -4.1), 0.13, BLACK)
	sign(
		"CounterOpeningHours",
		"REPAIRS & BOAT SALES\nOPEN DAILY",
		10.5,
		11.1,
		-18.85,
		5.3,
		1.3,
		TEAL,
		CREAM,
		A(0, math.pi, 0)
	)

	group("SafetyStation")
	-- Safety equipment is concentrated on the entry wall, clear of the stairs.
	p("SafetyStationBackboard", V(6.2, 5.7, 0.18), -14, 6.8, -18.85, rgb(221, 210, 174))
	sign("SafetyStationHeader", "WORKSHOP SAFETY", -14, 9.15, -18.65, 5.8, 0.65, TEAL, CREAM, A(0, math.pi, 0))
	p("FirstAidCase", V(1.65, 1.3, 0.4), -12.2, 7.4, -18.42, rgb(57, 119, 87))
	p("FirstAidCross", V(0.9, 0.24, 0.04), -12.2, 7.4, -18.19, CREAM)
	p("FirstAidCross", V(0.24, 0.9, 0.04), -12.2, 7.4, -18.18, CREAM)
	rod("FireExtinguisher", V(-15.7, 4.25, -18.15), V(-15.7, 6.1, -18.15), 0.65, RED)
	p("ExtinguisherLever", V(0.5, 0.12, 0.18), -15.7, 6.35, -18.15, BLACK)
	rod("ExtinguisherNeck", V(-15.7, 6.1, -18.15), V(-15.7, 6.35, -18.15), 0.2, SILVER)
	p("ExtinguisherLabel", V(0.46, 0.65, 0.045), -15.7, 5.25, -17.81, CREAM)
	hose("ExtinguisherHose", { V(-15.5, 6.27, -18.1), V(-15.12, 6.05, -18.1), V(-15.05, 4.9, -18.1) }, 0.09, BLACK)
	sign("ExtinguisherSign", "FIRE", -15.7, 7.4, -18.37, 1.35, 0.55, RED, CREAM, A(0, math.pi, 0))
	sign(
		"SafetyRules",
		"WEAR EYE PROTECTION\nKEEP WALKWAYS CLEAR\nNO SMOKING",
		-13.1,
		5.4,
		-18.36,
		2.6,
		1.55,
		STEEL,
		CREAM,
		A(0, math.pi, 0)
	)
	-- Orange life ring is assembled as an open ring, with four cream bindings.
	ring("Lifebuoy", V(-9, 8, -18.35), 1, 0.28, rgb(219, 105, 45))
	for i = 0, 3 do
		local angle = i * math.pi / 2
		p(
			"LifebuoyBinding",
			V(0.37, 0.32, 0.33),
			-9 + math.sin(angle),
			8 + math.cos(angle),
			-18.35,
			CREAM,
			nil,
			A(0, 0, -angle)
		)
	end
	ring("LifebuoyGrabRope", V(-9, 8, -18.35), 1.31, 0.065, ROPE)
	sign("LifebuoyLabel", "RESCUE EQUIPMENT", -9, 6.2, -18.54, 3, 0.5, TEAL, CREAM, A(0, math.pi, 0))
	-- Recessed-looking mat and aisle markings sit on top of the actual floor.
	p("EntranceRubberMat", V(9, 0.025, 3), 0, 2.02, -17, BLACK, M.SmoothPlastic)
	for x = -4, 4, 0.5 do
		p("EntranceMatRib", V(0.08, 0.014, 2.7), x, 2.04, -17, rgb(66, 70, 66))
	end

	group("CraneAndLightingDetails")
	for _, x in { -15, 2 } do
		for _, y in { 12.02, 12.62 } do
			p("CraneRunwayFlange", V(0.85, 0.12, 30), x, y, 0, YELLOW)
		end
		for _, z in { -12, 0, 12 } do
			p("RunwaySupportPlate", V(1.2, 0.16, 1.1), x, 11.8, z, STEEL)
		end
		for _, z in { 2.35, 3.65 } do
			rod("GantryEndTruckWheel", V(x - 0.22, 12.95, z), V(x + 0.22, 12.95, z), 0.56, BLACK)
		end
	end
	for _, y in { 12.62, 13.62 } do
		p("GantryBeamFlange", V(19, 0.12, 1.45), -6.5, y, 3, YELLOW)
	end
	for x = -14, 1, 1.5 do
		p("CraneBeamBolt", V(0.16, 0.16, 0.07), x, 13.25, 2.4, BLACK)
	end
	hose(
		"HoistPowerCable",
		{ V(1.8, 13.2, -14), V(1.8, 13.05, -9), V(1.8, 12.7, -7), V(1.8, 13.05, -5), V(1.8, 13.05, 2), V(-6, 13.05, 3) },
		0.1,
		BLACK
	)
	rod("CranePendantCable", V(1, 12.3, 3), V(1, 5.7, 3), 0.08, BLACK)
	p("CranePendant", V(0.5, 1.25, 0.35), 1, 5.12, 3, YELLOW)
	for i = 1, 3 do
		rod("PendantButton", V(1, 5.55 - i * 0.3, 2.8), V(1, 5.55 - i * 0.3, 2.75), 0.16, if i == 1 then RED else BLACK)
	end
	-- Diffusers and wire hangers enrich the existing lights without adding lights.
	for _, x in { -15.5, 13 } do
		for _, z in { -10, 8 } do
			for _, dx in { -1.15, 1.15 } do
				rod("LightSuspension", V(x + dx, 11.95, z), V(x + dx, 13.8, z), 0.045, BLACK)
			end
			for dx = -1.3, 1.3, 0.65 do
				p("LightGuard", V(0.055, 0.24, 1.1), x + dx, 11.7, z, STEEL)
			end
		end
	end
	for _, x in { -20, 20 } do
		for _, z in { -18.5, 0, 18.5 } do
			p("ColumnGusset", V(1.5, 1.1, 0.16), x, 13.6, z, STEEL)
			for _, dx in { -0.45, 0.45 } do
				p("GussetRivet", V(0.12, 0.12, 0.1), x + dx, 13.6, z - 0.14, SILVER)
			end
		end
	end

	group("FloorAndBasinDetails")
	-- Seams and patches sit above the walkway only; the repair basin stays hollow.
	for z = -15, 15, 6 do
		p("ConcreteExpansionJoint", V(20, 0.012, 0.035), 10.5, 2.013, z, rgb(101, 110, 105))
		p("ConcreteExpansionJoint", V(6.5, 0.012, 0.035), -17.5, 2.013, z, rgb(101, 110, 105))
	end
	for _, x in { 2.2, 7.6 } do
		for z = -12, 13, 4 do
			p("AislePaint", V(0.12, 0.018, 2.2), x, 2.026, z, YELLOW)
		end
	end
	for i, spec in { V(17.8, 0, 7), V(-18.8, 0, 11.2), V(14, 0, 10.8), V(-16.7, 0, 16) } do
		for k = 1, 3 do
			local stain = p(
				"WorkshopOilWear",
				V(0.5 + k * 0.4, 0.009, 0.35 + k * 0.25),
				spec.X + k * 0.18,
				2.022 + k * 0.002,
				spec.Z,
				rgb(76, 82, 71),
				M.SmoothPlastic,
				A(0, i * 0.7 + k * 0.2, 0)
			)
			stain.Transparency = 0.65
		end
	end
	for i = 1, 9 do
		p(
			"WoodShaving",
			V(0.08, 0.03, 0.25 + i % 3 * 0.1),
			11 + (i * 0.57) % 5.5,
			2.04,
			7.05 + (i * 0.37) % 0.4,
			WOOD,
			M.Wood,
			A(0, i * 0.8, 0)
		)
	end
	-- Basin wall service pipe, flanges, drain sump, and repair identification.
	rod("BasinDrainPipe", V(-12.95, 0.85, -7.5), V(-12.95, 0.85, 10.5), 0.18, RUST)
	for z = -7, 9, 4 do
		rod("BasinPipeFlange", V(-12.95, 0.85, z - 0.07), V(-12.95, 0.85, z + 0.07), 0.35, STEEL)
	end
	p("BasinSumpGrate", V(1.6, 0.05, 1.5), -11.2, 0.34, 10, BLACK, M.DiamondPlate)
	for x = -11.8, -10.6, 0.2 do
		p("SumpGrateBar", V(0.07, 0.03, 1.3), x, 0.38, 10, SILVER)
	end
	sign("RepairBayNumber", "01\nHULL REPAIR", -7, 10.9, 18.4, 5, 1.5, TEAL)
	sign("BasinWarning", "CAUTION  /  OPEN REPAIR PIT", -7, 2.015, -10.9, 7, 0.8, YELLOW, BLACK, A(math.pi / 2, 0, 0))
	-- Commit after construction so an interrupted build is repaired on next ensure.
	root:SetAttribute("DetailVersion", VERSION)
end

return Interior

end
dependencies.DrydockInterior = loadDrydockInterior()
local function loadDrydock()
	-- Walk-in industrial boatyard and launch controls. Versioned construction also
-- upgrades drydocks baked into a saved Studio map.
local CollectionService = game:GetService("CollectionService")

local Props = dependencies.Props
local Shipwright = dependencies.Shipwright
local DrydockInterior = dependencies.DrydockInterior
local Rowboat = dependencies.Rowboat

local Drydock = {}
local LAYOUT_VERSION = 15
local rgb = Color3.fromRGB
local M = Enum.Material
local STEEL = rgb(47, 58, 64)
local WALL = rgb(105, 123, 130)
local RUST = rgb(121, 73, 45)
local CONCRETE = rgb(137, 143, 140)
local YELLOW = rgb(232, 184, 48)
local BLACK = rgb(30, 34, 35)
local CREAM = rgb(239, 236, 211)
local TEAL = rgb(46, 96, 105)
local DARK_WOOD = rgb(70, 53, 40)

local function boardText(board: BasePart, value: string, color: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 36
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color or CREAM
	label.Text = value
	label.Parent = gui
end

local function prompt(parent: BasePart, name: string, action: string, object: string): ProximityPrompt
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("ProximityPrompt") then
		return existing
	end
	local p = Instance.new("ProximityPrompt")
	p.Name, p.ActionText, p.ObjectText = name, action, object
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.HoldDuration = 0.35
	p.Parent = parent
	return p
end

-- Clear only beach props occupying the building. A palm/bush is one prop, so
-- remove its entire model when its trunk intersects rather than leaving fronds
-- hanging in the workshop. Long boardwalk/fence sections remain localized.
local function clearApron(plaza: Model, shop: Model, footprintName: string?)
	local beach = plaza.Parent and plaza.Parent:FindFirstChild("Beach")
	local footprint = shop:FindFirstChild(footprintName or "ShopFootprint", true)
	if not footprint or not footprint:IsA("BasePart") then
		return
	end
	local half = footprint.Size / 2
	local candidates = if beach then beach:GetDescendants() else {}
	-- Palms at the plaza edge can overhang the new roof even when their trunks
	-- stand outside the site. Clear whole intersecting plants, keeping nearby ones.
	for _, decoration in plaza:GetChildren() do
		if decoration:IsA("Model") and (decoration.Name == "Palm" or decoration.Name == "Bush") then
			for _, piece in decoration:GetDescendants() do
				table.insert(candidates, piece)
			end
		end
	end
	local remove: { [Instance]: boolean } = {}
	for _, item in candidates do
		if not item:IsA("BasePart") then
			continue
		end
		local low = Vector3.new(math.huge, math.huge, math.huge)
		local high = Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, x in { -0.5, 0.5 } do
			for _, y in { -0.5, 0.5 } do
				for _, z in { -0.5, 0.5 } do
					local p = footprint.CFrame:PointToObjectSpace(
						item.CFrame * Vector3.new(item.Size.X * x, item.Size.Y * y, item.Size.Z * z)
					)
					low = Vector3.new(math.min(low.X, p.X), math.min(low.Y, p.Y), math.min(low.Z, p.Z))
					high = Vector3.new(math.max(high.X, p.X), math.max(high.Y, p.Y), math.max(high.Z, p.Z))
				end
			end
		end
		if
			low.X < half.X
			and high.X > -half.X
			and low.Y < half.Y
			and high.Y > -half.Y
			and low.Z < half.Z
			and high.Z > -half.Z
		then
			local target: Instance = item
			local ancestor = item.Parent
			while ancestor and ancestor ~= beach and ancestor ~= plaza do
				if
					ancestor:IsA("Model")
					and ancestor.Name ~= "Fence"
					and ancestor.Name ~= "Surf"
					and ancestor.Name ~= "BeachDetails"
					and ancestor.Name ~= "FoamRibbon"
				then
					target = ancestor
				end
				ancestor = ancestor.Parent
			end
			remove[target] = true
		end
	end
	for target in remove do
		target:Destroy()
	end
end

-- A raised, open-air repair basin keeps its floor above the beach mesh and water.
-- The hauling slip carries the preview cradle into open launch water.
local function buildRearDrydock(shop: Model, frame: CFrame)
	local rear = Instance.new("Model")
	rear.Name = "RearDrydock"
	rear.Parent = shop
	local function part(
		name: string,
		size: Vector3,
		x: number,
		y: number,
		z: number,
		color: Color3,
		material: Enum.Material?
	): Part
		local p = Props.part(rear, size, frame * CFrame.new(x, y, z), color, material or M.Metal)
		p.Name = name
		return p
	end
	local function beam(
		name: string,
		a: Vector3,
		b: Vector3,
		width: number,
		depth: number,
		color: Color3,
		material: Enum.Material?
	): Part
		local p = Props.beam(rear, frame * a, frame * b, width, color, depth, material or M.Metal)
		p.Name = name
		return p
	end
	local footprint = part("RearDrydockFootprint", Vector3.new(43, 32, 96), 0, 4, 68, CONCRETE, M.Concrete)
	footprint.Transparency, footprint.CanCollide, footprint.CanTouch, footprint.CanQuery = 1, false, false, false
	footprint.CastShadow = false
	rear.PrimaryPart = footprint

	-- Separate floor, retaining walls and quays leave a real four-stud-deep hollow.
	-- Even the highest beach vertex is below this dry floor; no terrain cut is needed.
	part("RearBasinFloor", Vector3.new(22, 0.6, 42), 0, 0.2, 55, rgb(91, 100, 99), M.Concrete)
	part("RearHeadwall", Vector3.new(24, 4, 1), 0, 2.5, 33.5, CONCRETE, M.Concrete)
	for _, side in { -1, 1 } do
		part("RearBasinWall", Vector3.new(1, 4, 42), side * 11.5, 2.5, 55, CONCRETE, M.Concrete)
		part("RearQuayWalkway", Vector3.new(7, 12.5, 32), side * 15.5, -1.75, 64, CONCRETE, M.Concrete)
		part("RearCoping", Vector3.new(0.6, 0.16, 42), side * 11.65, 4.58, 55, BLACK, M.DiamondPlate)
		for z = 35, 75, 2 do
			part("RearHazardStripe", Vector3.new(0.62, 0.04, 0.85), side * 11.65, 4.68, z, YELLOW)
		end
		-- Two independent stairs can be approached from either side of the workshop.
		for i = 1, 23 do
			local top = -4.7 + i * 0.4
			local z = 20.2 + i * 1.2
			part("RearAccessStep", Vector3.new(7, top + 8, 1.4), side * 15.5, (top - 8) / 2, z, CONCRETE, M.Concrete)
			if i % 4 == 1 or i == 23 then
				part("RearStairPost", Vector3.new(0.16, 2.9, 0.16), side * 18.75, top + 1.45, z, STEEL)
			end
		end
		for _, height in { 1.2, 2.8 } do
			beam(
				"RearStairRail",
				Vector3.new(side * 18.75, -4.3 + height, 21.4),
				Vector3.new(side * 18.75, 4.5 + height, 47.8),
				0.14,
				0.14,
				STEEL
			)
		end
		for z = 49, 79, 10 do
			part("RearSafetyPost", Vector3.new(0.16, 3, 0.16), side * 18.75, 6, z, STEEL)
		end
		for _, y in { 5.6, 7.4 } do
			part("RearSafetyRail", Vector3.new(0.14, 0.14, 30), side * 18.75, y, 64, STEEL)
		end
		-- Outboard columns leave the working path beside the basin unobstructed.
		part("OutdoorGantryFoot", Vector3.new(1.4, 0.25, 2.5), side * 18.1, 4.625, 54, STEEL, M.DiamondPlate)
		-- Tall enough for a lifted hull's mast, and clear of the height boats probe for water.
		part("OutdoorGantryColumn", Vector3.new(0.9, 18.8, 1), side * 18.25, 14, 54, STEEL)
		beam(
			"OutdoorGantryBrace",
			Vector3.new(side * 18.25, 20.5, 54),
			Vector3.new(side * 14.5, 23.5, 54),
			0.45,
			0.45,
			YELLOW
		)
	end
	part("OutdoorGantryBeam", Vector3.new(39, 1.25, 1.25), 0, 24, 54, YELLOW)
	part("OutdoorHoistTrolley", Vector3.new(2.5, 0.8, 2), 0, 23, 54, STEEL)
	beam("OutdoorHoistCable", Vector3.new(0, 22.6, 54), Vector3.new(0, 20.8, 54), 0.1, 0.1, BLACK)
	part("OutdoorHookBlock", Vector3.new(0.8, 0.9, 0.7), 0, 20.4, 54, YELLOW)
	beam("OutdoorCraneHook", Vector3.new(0, 20, 54), Vector3.new(-0.45, 19.5, 54), 0.18, 0.18, STEEL)
	beam("OutdoorCraneHook", Vector3.new(-0.45, 19.5, 54), Vector3.new(0.3, 19.5, 54), 0.18, 0.18, STEEL)
	beam("OutdoorCraneHook", Vector3.new(0.3, 19.5, 54), Vector3.new(0.45, 19.85, 54), 0.18, 0.18, STEEL)

	-- Empty keel and bilge blocks make the basin read as a place to work on a hull.
	for z = 39, 71, 8 do
		part("KeelBlock", Vector3.new(2.5, 0.9, 2), 0, 0.95, z, DARK_WOOD, M.Wood)
		for _, side in { -1, 1 } do
			part("BilgeBlock", Vector3.new(1.5, 0.65, 2), side * 6, 0.825, z, DARK_WOOD, M.Wood)
		end
	end
	for _, x in { -3.5, 3.5 } do
		part("HaulRail", Vector3.new(0.22, 0.2, 42), x, 0.6, 55, STEEL)
	end
	part("RearDrainGrate", Vector3.new(1.3, 0.08, 36), -9.5, 0.54, 55, BLACK, M.DiamondPlate)
	for z = 38, 72, 2 do
		part("RearDrainSlot", Vector3.new(1.1, 0.03, 0.12), -9.5, 0.595, z, STEEL)
	end
	-- This is a marine slipway, with continuous rails from the dry basin to below
	-- the waterline. The slab stays above the sloping beach and seabed throughout.
	beam("SlipwayDeck", Vector3.new(0, 0.2, 76), Vector3.new(0, -8.8, 114), 22, 0.6, CONCRETE, M.Concrete)
	for _, x in { -3.5, 3.5 } do
		beam("SlipwayRail", Vector3.new(x, 0.6, 76), Vector3.new(x, -8.4, 114), 0.22, 0.2, STEEL)
	end
	for _, side in { -1, 1 } do
		part("HaulWinchBase", Vector3.new(2.4, 0.3, 2.8), side * 13.7, 4.65, 72, STEEL, M.DiamondPlate)
		part("HaulWinch", Vector3.new(1.8, 1.4, 1.8), side * 13.7, 5.5, 72, TEAL)
		part("HaulWinchDrum", Vector3.new(2.4, 0.65, 0.7), side * 13.7, 5.7, 71.4, RUST)
		local glow =
			part("RearWorkLight", Vector3.new(0.7, 0.35, 0.7), side * 18.25, 22.5, 53.2, rgb(255, 232, 178), M.Neon)
		glow.CanCollide = false
		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range, light.Shadows = rgb(255, 232, 178), 1.1, 28, false
		light.Parent = glow
	end
	local sign = part("RearDrydockSign", Vector3.new(15, 1.5, 0.18), 0, 3.2, 32.9, STEEL)
	boardText(sign, "DRYDOCK  /  REFIT LIFT", CREAM)
	-- These frames share the rowboat's waterline origin and point out to the bay.
	for name, position in
		{
			PreviewOrigin = Vector3.new(0, 2.1, 54),
			FishingBoatPreview = Vector3.new(0, 2.1, 54),
			SpeedboatPreview = Vector3.new(0, 2.1, 54),
			PatrolBoatPreview = Vector3.new(0, 2.1, 54),
			RacingSpeedboatPreview = Vector3.new(0, 2.1, 54),
			TrawlerPreview = Vector3.new(0, 2.1, 54),
			SlipwayTop = Vector3.new(0, 2.1, 54),
			LaunchWater = Vector3.new(0, -frame.Position.Y, 54),
		}
	do
		local point = part(
			if name == "FishingBoatPreview"
				then "FishingBoatDisplayOrigin"
				elseif name == "SpeedboatPreview" then "SpeedboatDisplayOrigin"
				elseif name == "PatrolBoatPreview" then "PatrolBoatDisplayOrigin"
				elseif name == "RacingSpeedboatPreview" then "RacingSpeedboatDisplayOrigin"
				elseif name == "TrawlerPreview" then "TrawlerDisplayOrigin"
				else name,
			Vector3.new(1, 1, 1),
			position.X,
			position.Y,
			position.Z,
			STEEL
		)
		point.CFrame *= CFrame.Angles(0, math.pi, 0)
		shop:SetAttribute(name .. "Frame", point.CFrame)
		point.Transparency, point.CanCollide, point.CanTouch, point.CanQuery = 1, false, false, false
	end
	local cradle = Instance.new("Model")
	cradle.Name = "LaunchCradle"
	cradle.Parent = rear
	for _, z in { 50, 58 } do
		local crossbar = part("LaunchCradleBeam", Vector3.new(8.5, 0.35, 1), 0, 1.3, z, YELLOW)
		crossbar.Parent = cradle
		crossbar.CanCollide = false
		cradle.PrimaryPart = crossbar
		for _, x in { -3.5, 3.5 } do
			local wheel = part("CradleRoller", Vector3.new(0.7, 0.6, 1), x, 0.95, z, STEEL)
			wheel.Parent = cradle
			wheel.CanCollide = false
		end
	end
	-- Reuse the original repair platform, including its blocks, rails,
	-- drainage and attached slipway. The surrounding quays stay fixed.
	local moving = {
		RearBasinFloor = true,
		KeelBlock = true,
		BilgeBlock = true,
		HaulRail = true,
		RearDrainGrate = true,
		RearDrainSlot = true,
		SlipwayDeck = true,
		SlipwayRail = true,
	}
	for _, piece in rear:GetChildren() do
		if moving[piece.Name] then
			piece.Parent = cradle
			if piece.Name == "RearBasinFloor" then
				cradle.PrimaryPart = piece
			end
		end
	end
	-- The cradle rests underwater as the refit lift: owners sail over it and it lifts
	-- their hull into the dry basin (DrydockLaunch.lift). Purchases ride it down too.
	-- Lowered, its keel blocks sit four studs under the surface, below every hull.
	local drop = frame.Position.Y + 6.1
	cradle:PivotTo(cradle:GetPivot() - Vector3.new(0, drop, 0))
	shop:SetAttribute("LiftDrop", drop)
	shop:SetAttribute("LiftKeelHeight", (frame * CFrame.new(0, 1.4, 0)).Position.Y)
	-- A hull counts as over the lift while its root floats between the basin walls.
	shop:SetAttribute("SlipFrame", CFrame.new((frame * CFrame.new(0, 0, 62)).Position * Vector3.new(1, 0, 1)))
	shop:SetAttribute("SlipSize", Vector3.new(20, 30, 56))
	-- With the floor down, the pit wall closes the gap under the headwall.
	part("LiftPitWall", Vector3.new(23, 12, 1), 0, -5.5, 33.5, CONCRETE, M.Concrete)
	-- Reopens the refit menu; each client enables it only while its own boat is over the lift.
	local anchor = part("RefitPromptAnchor", Vector3.new(1, 1, 1), 0, 10, 60, STEEL)
	anchor.Transparency, anchor.CanCollide, anchor.CanQuery, anchor.CastShadow = 1, false, false, false
	local refit = Instance.new("ProximityPrompt")
	refit.Name = "RefitDockPrompt"
	refit.ActionText, refit.ObjectText = "Lift & refit", "Drydock"
	refit.MaxActivationDistance = 40
	refit.RequiresLineOfSight = false
	refit.Enabled = false
	refit.Parent = anchor
	-- Atomic streaming prevents partial hulls while the shop camera watches it.
	rear.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
end

-- plazaFrame is the walkable paving at the square center. The lake is +Z;
-- the north entry opens directly onto the plaza's southern promenade.
function Drydock.build(plaza: Model, plazaFrame: CFrame): Model
	local existing = plaza:FindFirstChild("Drydock")
	if existing and existing:IsA("Model") and existing:GetAttribute("LayoutVersion") == LAYOUT_VERSION then
		-- Saved version-15 shops share this waterline origin; add the new hull without rebuilding the lift.
		if existing:GetAttribute("TrawlerPreviewFrame") == nil then
			existing:SetAttribute("TrawlerPreviewFrame", existing:GetAttribute("FishingBoatPreviewFrame"))
		end
		for _, item in existing:GetDescendants() do
			if item:IsA("Model") and item:FindFirstChild("CoolerLid") then
				Rowboat.ensureCoolerInteraction(item)
			end
		end
		local npc = existing:FindFirstChild("Shipwright")
		if npc and npc:IsA("Model") then
			Shipwright.ensureAppearance(npc)
			Shipwright.ensureInteraction(npc)
		end
		DrydockInterior.ensure(existing, plazaFrame * CFrame.new(0, 0, 82))
		CollectionService:AddTag(existing, "BoatShop")
		CollectionService:AddTag(existing, "RefitDock")
		clearApron(plaza, existing)
		clearApron(plaza, existing, "RearDrydockFootprint")
		return existing
	elseif existing then
		existing:Destroy()
	end
	local shop = Instance.new("Model")
	shop.Name = "Drydock"
	shop:SetAttribute("LayoutVersion", LAYOUT_VERSION)
	shop:SetAttribute("BoatId", "Rowboat")
	shop:SetAttribute("Price", 500)
	local frame = plazaFrame * CFrame.new(0, 0, 82)
	shop:SetAttribute("InteriorFrame", frame * CFrame.new(0, 8, 0))
	shop:SetAttribute("InteriorSize", Vector3.new(40, 16, 36))
	shop.Parent = plaza
	local function at(x: number, y: number, z: number): CFrame
		return frame * CFrame.new(x, y, z)
	end
	local function part(
		name: string,
		size: Vector3,
		x: number,
		y: number,
		z: number,
		color: Color3,
		material: Enum.Material?,
		spin: CFrame?
	): Part
		local p = Props.part(shop, size, at(x, y, z) * (spin or CFrame.new()), color, material or M.Metal)
		p.Name = name
		return p
	end
	local function beam(name: string, a: Vector3, b: Vector3, width: number, depth: number, color: Color3): Part
		local p = Props.beam(shop, frame * a, frame * b, width, color, depth, M.Metal)
		p.Name = name
		return p
	end
	local function light(x: number, y: number, z: number, size: Vector3)
		part("WorkLightHousing", size + Vector3.new(0.35, 0.15, 0.35), x, y + 0.15, z, STEEL)
		local glow = part("WorkLight", size, x, y, z, rgb(255, 236, 180), M.Neon)
		glow.CanCollide = false
		local l = Instance.new("PointLight")
		l.Color, l.Brightness, l.Range, l.Shadows = rgb(255, 231, 184), 1.15, 22, false
		l.Parent = glow
	end
	local footprint = part("ShopFootprint", Vector3.new(43, 28, 40), 0, 7, 0, CONCRETE, M.Concrete)
	footprint.Transparency, footprint.CanCollide, footprint.CanTouch, footprint.CanQuery = 1, false, false, false
	footprint.CastShadow = false
	shop.PrimaryPart = footprint

	-- Concrete is segmented around a real hollow dry repair basin. The raised
	-- perimeter gives the bay 1.7 studs of visible depth without cutting terrain.
	part("ConcreteWalkway", Vector3.new(8, 8.4, 40), -17.5, -2.2, 0, CONCRETE, M.Concrete)
	part("ConcreteWalkway", Vector3.new(22, 8.4, 40), 10.5, -2.2, 0, CONCRETE, M.Concrete)
	part("ConcreteWalkway", Vector3.new(13, 8.4, 11), -7, -2.2, -14.5, CONCRETE, M.Concrete)
	part("ConcreteWalkway", Vector3.new(13, 8.4, 7), -7, -2.2, 16.5, CONCRETE, M.Concrete)
	part("BasinFloor", Vector3.new(13, 0.6, 22), -7, 0, 2, rgb(81, 91, 90), M.Concrete)
	for _, x in { -13.5, -0.5 } do
		part("BasinWall", Vector3.new(0.6, 2.3, 22.6), x, 1.2, 2, CONCRETE, M.Concrete)
	end
	for _, z in { -9, 13 } do
		part("BasinWall", Vector3.new(13.6, 2.3, 0.6), -7, 1.2, z, CONCRETE, M.Concrete)
	end
	for i = 1, 5 do
		part("EntranceStep", Vector3.new(14, i * 0.4, 1.25), 0, i * 0.2, -24.75 + i * 1.2, CONCRETE, M.Concrete)
	end
	-- A service ladder reaches the dry basin floor from the clear rear walkway.
	for _, x in { -9, -7 } do
		part("BasinLadderRail", Vector3.new(0.14, 2.7, 0.14), x, 1.3, 12.55, STEEL)
	end
	for y = 0.45, 2.45, 0.5 do
		part("BasinLadderRung", Vector3.new(2.1, 0.14, 0.14), -8, y, 12.55, STEEL)
	end
	part("DrainGrate", Vector3.new(1.6, 0.08, 5), -11.2, 0.34, 2, BLACK, M.DiamondPlate)
	for z = 0, 4, 0.5 do
		part("DrainSlot", Vector3.new(1.35, 0.02, 0.08), -11.2, 0.39, z, STEEL)
	end
	for _, x in { -13.1, -0.9 } do
		part("HazardRail", Vector3.new(0.5, 0.08, 22), x, 2.39, 2, BLACK, M.DiamondPlate)
		for z = -8, 12, 1.5 do
			part("HazardStripe", Vector3.new(0.52, 0.04, 0.7), x, 2.45, z, YELLOW)
		end
	end
	for _, z in { -8.7, 12.7 } do
		part("HazardRail", Vector3.new(12, 0.08, 0.5), -7, 2.39, z, BLACK, M.DiamondPlate)
		for x = -12, -2, 1.5 do
			part("HazardStripe", Vector3.new(0.7, 0.04, 0.52), x, 2.45, z, YELLOW)
		end
	end

	-- Corrugated steel walls, a broad permanent entry, and exposed roof portals.
	for _, x in { -21, 21 } do
		part("SideCorrugatedWall", Vector3.new(0.7, 12, 40), x, 8, 0, WALL, M.CorrodedMetal)
		for z = -18, 18, 2 do
			part("WallRib", Vector3.new(0.2, 12, 0.23), x - math.sign(x) * 0.45, 8, z, STEEL)
		end
	end
	part("RearCorrugatedWall", Vector3.new(42, 12, 0.7), 0, 8, 19.5, WALL, M.CorrodedMetal)
	for x = -20, 20, 2 do
		part("WallRib", Vector3.new(0.23, 12, 0.2), x, 8, 19.02, STEEL)
	end
	for _, x in { -14.25, 14.25 } do
		part("FrontCorrugatedWall", Vector3.new(14.5, 10, 0.7), x, 7, -19.5, WALL, M.CorrodedMetal)
	end
	part("EntranceHeader", Vector3.new(43, 2, 0.9), 0, 13, -19.5, STEEL)
	part("RollerDoorHousing", Vector3.new(15.5, 0.8, 1.5), 0, 12.05, -19.1, rgb(125, 136, 138))
	for _, x in { -20, 20 } do
		for _, z in { -18.5, 0, 18.5 } do
			part("ColumnFoot", Vector3.new(2.3, 0.3, 2.3), x, 2.15, z, STEEL, M.DiamondPlate)
			part("SteelColumn", Vector3.new(0.9, 12, 0.9), x, 8, z, STEEL)
			for _, dx in { -0.75, 0.75 } do
				part("AnchorBolt", Vector3.new(0.18, 0.2, 0.18), x + dx, 2.4, z, rgb(153, 160, 159))
			end
		end
	end
	local pitch = math.atan2(6, 21)
	for _, side in { -1, 1 } do
		part(
			"CorrugatedRoof",
			Vector3.new(math.sqrt(21 * 21 + 36) + 0.6, 0.4, 40),
			side * 10.5,
			17,
			0,
			rgb(84, 103, 110),
			M.CorrodedMetal,
			CFrame.Angles(0, 0, -side * pitch)
		)
	end
	for x = -20, 20, 1.5 do
		part("RoofRib", Vector3.new(0.16, 0.16, 40), x, 20.35 - math.abs(x) * 6 / 21, 0, STEEL)
	end
	for _, z in { -18.5, -6, 6, 18.5 } do
		beam("RoofTruss", Vector3.new(-20, 14, z), Vector3.new(0, 19.75, z), 0.45, 0.55, STEEL)
		beam("RoofTruss", Vector3.new(0, 19.75, z), Vector3.new(20, 14, z), 0.45, 0.55, STEEL)
		part("TrussTie", Vector3.new(40, 0.4, 0.45), 0, 14, z, STEEL)
		for x = -15, 15, 10 do
			beam(
				"TrussBrace",
				Vector3.new(x, 14, z),
				Vector3.new(x + 5, 19.5 - math.abs(x + 5) * 0.275, z),
				0.22,
				0.25,
				WALL
			)
		end
	end
	part("RoofRidge", Vector3.new(0.6, 0.5, 40), 0, 20.1, 0, STEEL)
	-- Short gable battens close the triangular ends while retaining ventilation.
	for _, z in { -19.5, 19.5 } do
		for x = -18, 18, 2 do
			local height = 5.7 * (1 - math.abs(x) / 21)
			part("GableBatten", Vector3.new(1.75, height, 0.35), x, 14 + height / 2, z, WALL, M.CorrodedMetal)
		end
	end

	-- Overhead bridge crane, with the hook visibly hoisted above the hull.
	for _, x in { -15, 2 } do
		part("CraneRunway", Vector3.new(0.5, 0.65, 30), x, 12.3, 0, YELLOW)
		part("CraneRail", Vector3.new(0.18, 0.2, 30), x, 12.75, 0, STEEL)
	end
	part("GantryBeam", Vector3.new(19, 1.05, 1.1), -6.5, 13.1, 3, YELLOW)
	part("HoistMotor", Vector3.new(2.3, 1.2, 2.5), -7, 12.5, 3, STEEL)
	part("HoistDrum", Vector3.new(1.7, 0.65, 1.2), -7, 11.7, 3, RUST)
	for y = 8.8, 11.2, 0.3 do
		part("ChainLink", Vector3.new(0.13, 0.34, 0.13), -7, y, 3, BLACK)
	end
	part("HookBlock", Vector3.new(0.75, 0.7, 0.65), -7, 8.4, 3, YELLOW)
	beam("CraneHook", Vector3.new(-7, 8.1, 3), Vector3.new(-7.35, 7.65, 3), 0.16, 0.16, STEEL)
	beam("CraneHook", Vector3.new(-7.35, 7.65, 3), Vector3.new(-6.8, 7.65, 3), 0.16, 0.16, STEEL)
	beam("CraneHook", Vector3.new(-6.8, 7.65, 3), Vector3.new(-6.65, 7.95, 3), 0.16, 0.16, STEEL)
	local craneSign = part("CraneLoadSign", Vector3.new(3.5, 0.7, 0.08), -6.5, 13.05, 2.38, STEEL)
	boardText(craneSign, "1 TONNE", YELLOW)

	for _, z in { -2.4, 6.4 } do
		part("CradleCrossbeam", Vector3.new(8.6, 0.45, 1.2), -7, 0.875, z, STEEL)
		for _, x in { -10.1, -3.9 } do
			part("CradleFoot", Vector3.new(0.75, 0.4, 1.6), x, 0.5, z, RUST)
		end
	end
	local boat = Rowboat.build(at(-7, 1.735, 2), true)
	boat.Name = "DisplayRowboat"
	boat:SetAttribute("DisplayOnly", true)
	boat.Parent = shop

	-- Shop side: a clear customer aisle, staffed counter and workshop behind it.
	part("ShipwrightCounter", Vector3.new(7, 2.5, 2), 12, 3.25, -4, rgb(72, 88, 94), M.Metal)
	part("CounterTop", Vector3.new(7.5, 0.25, 2.5), 12, 4.65, -4, STEEL, M.DiamondPlate)
	local price = part("BoatPrices", Vector3.new(6.5, 2.5, 0.08), 12, 3.3, -5.06, STEEL)
	boardText(
		price,
		"ROWBOAT  $500\nFISHER'S BOAT  $2500\nBLUEWATER  $6500\nRACING SPEEDBOAT  $12500\nPATROL CRUISER  $25000",
		YELLOW
	)
	local npc = Shipwright.build(at(12, 2, -0.5))
	npc.Parent = shop
	-- build applies the outfit before the model is in the DataModel; retry here
	-- for the rare case where a slow asset request failed the first time.
	Shipwright.ensureAppearance(npc)
	part("WorkshopBench", Vector3.new(8, 0.5, 3), 13.5, 5.1, 9, STEEL, M.DiamondPlate)
	for _, x in { 10.3, 16.7 } do
		part("BenchLeg", Vector3.new(0.6, 3, 2), x, 3.5, 9, STEEL)
	end
	part("ToolBackboard", Vector3.new(8.5, 4, 0.3), 13.5, 7.5, 10.5, rgb(71, 83, 87), M.DiamondPlate)
	for x = 10, 16, 1.5 do
		part("HangingWrench", Vector3.new(0.2, 1.4, 0.2), x, 7.6, 10.2, rgb(160, 170, 174))
		part("WrenchJaw", Vector3.new(0.55, 0.3, 0.2), x, 8.3, 10.2, rgb(160, 170, 174))
	end
	part("BenchVise", Vector3.new(1.2, 0.7, 1.3), 15.8, 5.7, 8.8, TEAL)
	part("ViseJaw", Vector3.new(1.6, 0.25, 0.45), 15.8, 6.15, 8.8, STEEL)
	part("WeldingCylinder", Vector3.new(1.5, 3.5, 1.5), 18, 3.75, 13, rgb(70, 111, 101))
	part("CylinderValve", Vector3.new(0.6, 0.6, 0.6), 18, 5.8, 13, STEEL)
	for _, x in { 6, 18.7 } do
		part("StorageUpright", Vector3.new(0.5, 8, 0.5), x, 6, 17.5, STEEL)
	end
	for y = 2.3, 9.3, 3.5 do
		part("PartsRackShelf", Vector3.new(13.5, 0.25, 2.7), 12.3, y, 17.5, WALL)
		for x = 8, 17, 3 do
			part("PartsBin", Vector3.new(2, 1.2, 1.8), x, y + 0.7, 17.5, rgb(137, 95, 61), M.Metal)
		end
	end
	for _, z in { -10, 8 } do
		light(-15.5, 11.7, z, Vector3.new(3.2, 0.2, 1))
		light(13, 11.7, z, Vector3.new(3.2, 0.2, 1))
	end
	light(0, 11.15, -18.5, Vector3.new(5.5, 0.2, 0.6))
	local name = part("DrydockSign", Vector3.new(30, 2.3, 0.22), 0, 15.1, -20, STEEL)
	boardText(name, "INDUSTRIAL DRYDOCK")
	local entrySign = part("ShipwrightSign", Vector3.new(5.8, 1.4, 0.16), 13, 9.2, -20, STEEL)
	boardText(entrySign, "SHIPWRIGHT INSIDE", YELLOW)
	DrydockInterior.ensure(shop, frame)
	buildRearDrydock(shop, frame)
	CollectionService:AddTag(shop, "BoatShop")
	CollectionService:AddTag(shop, "RefitDock")
	clearApron(plaza, shop)
	clearApron(plaza, shop, "RearDrydockFootprint")
	return shop
end

function Drydock.ensureDock(base: Model)
	local stored = base:GetAttribute("BoatDockFrame")
	local frame: CFrame
	if typeof(stored) == "CFrame" then
		frame = stored
	else
		local spawn = base:FindFirstChild("SpawnPoint")
		if not spawn or not spawn:IsA("BasePart") then
			warn("[Drydock] Cannot locate the dock for " .. base:GetFullName())
			return
		end
		-- SpawnPoint preserves the original base yaw, unlike the circular ClaimPad.
		frame = spawn.CFrame * CFrame.new(-4, -6.1, -26)
		base:SetAttribute("BoatDockFrame", frame)
	end
	local marker = base:FindFirstChild("BoatSpawn")
	if not marker then
		marker = Instance.new("Part")
		marker.Name = "BoatSpawn"
		marker.Parent = base
	end
	if marker:IsA("BasePart") then
		marker.Size = Vector3.new(1, 1, 1)
		marker.CFrame = frame * CFrame.new(0, 0, -52)
		marker.Anchored = true
		marker.Transparency = 1
		marker.CanCollide = false
		marker.CanTouch = false
		marker.CanQuery = false
		marker.CastShadow = false
	end
	local terminal = base:FindFirstChild("BoatDockControl")
	if not terminal then
		local control = Props.part(
			base,
			Vector3.new(3.4, 2.1, 0.5),
			frame * CFrame.new(-8, 5, -37.5) * CFrame.Angles(0, math.pi, 0),
			TEAL,
			M.WoodPlanks
		)
		control.Name = "BoatDockControl"
		boardText(control, "YOUR BOATS")
		local support =
			Props.part(base, Vector3.new(0.55, 2.8, 0.55), frame * CFrame.new(-8, 3.6, -37.5), DARK_WOOD, M.Wood)
		support.Name = "BoatControlPost"
		terminal = control
	end
	if terminal:IsA("BasePart") then
		local spawnPrompt = prompt(terminal, "SpawnRowboatPrompt", "Choose boat", "Your boats")
		spawnPrompt.ActionText, spawnPrompt.ObjectText = "Choose boat", "Your boats"
		-- Existing saved terminals keep their panel and receive the updated label.
		for _, label in terminal:GetDescendants() do
			if label:IsA("TextLabel") then
				label.Text = "YOUR BOATS"
			end
		end
	end
end

function Drydock.ensure(root: Instance)
	for _, item in root:GetDescendants() do
		if item:IsA("Model") and item.Name == "Plaza" then
			-- The square's main paving slab is stable across saved maps, so the
			-- retrofitted drydock doesn't depend on the current biome center/seed.
			for _, slab in item:GetChildren() do
				if
					slab:IsA("BasePart")
					and (slab.Size.X == 120 or slab.Size.X == 116)
					and slab.Size.Z == slab.Size.X
				then
					Drydock.build(item, slab.CFrame * CFrame.new(0, slab.Size.Y / 2, 0))
					break
				end
			end
		elseif item:IsA("Model") and CollectionService:HasTag(item, "PlayerBase") then
			Drydock.ensureDock(item)
		end
	end
end

return Drydock

end
dependencies.Drydock = loadDrydock()
local function loadPlazaHouses()
	-- Rows of detailed two-tone townhouses closing in the piazza on its west, north and east sides:
-- a coloured ground floor under a contrasting upper storey, quoins, string courses, rafter tails
-- under the eaves, shuttered arched windows, balconies, wall lanterns, climbing ivy and clutter.
-- The rod store uses the same builder. The rows are placed after the village so they can clear
-- ordinary houses and trees off their plots; any plot that would cover a street is left empty.

local Med = dependencies.Mediterranean
local Props = dependencies.Props

local PlazaHouses = {}

local LAYOUT_VERSION = 1
local TAU = math.pi * 2
local rgb = Color3.fromRGB
local M = Enum.Material
local part, beam, pick = Props.part, Props.beam, Props.pick

local STORY = 10
local FLOOR = 0.8
local STONE = rgb(214, 200, 172)
local QUOIN = rgb(196, 182, 156)
local WOOD = rgb(112, 80, 54)
local IRON = rgb(44, 42, 40)
local CREAM = rgb(255, 240, 205)
local LEAVES = { rgb(70, 132, 52), rgb(92, 152, 60), rgb(58, 112, 46), rgb(110, 164, 70) }

local LOWER = {
	rgb(226, 126, 70),
	rgb(240, 182, 66),
	rgb(244, 230, 200),
	rgb(206, 104, 72),
	rgb(236, 160, 96),
}
local UPPER = {
	rgb(244, 234, 210),
	rgb(92, 150, 202),
	rgb(240, 196, 92),
	rgb(108, 168, 170),
	rgb(234, 214, 176),
}
local SHUTTERS = { rgb(48, 112, 116), rgb(70, 120, 66), rgb(130, 82, 54), rgb(44, 86, 140), rgb(64, 140, 120) }
local ROOFS = { rgb(170, 84, 52), rgb(152, 72, 46), rgb(186, 100, 62) }
local DOORS = { rgb(170, 78, 54), rgb(142, 64, 44), rgb(70, 120, 66), rgb(60, 98, 130) }
local AWNINGS = { rgb(180, 52, 44), rgb(36, 92, 168), rgb(56, 120, 70), rgb(214, 160, 50) }
local SHOPS = { "Bakery", "Taverna", "Bait & Tackle", "Fishmonger", "Gelato", "Net Mender", "Chandlery", "Caffè" }

export type Spec = {
	width: number,
	depth: number,
	stories: number,
	lower: Color3,
	upper: Color3,
	trim: Color3,
	shutter: Color3,
	roof: Color3,
	door: Color3,
	balcony: boolean,
	shop: string?, -- shopfront window and awning, with this name on the board above
	blade: string?, -- a sign hung from an iron bracket beside the door
	signColor: Color3?,
	doorSide: number?, -- which end of a shopfront the door takes: 1 is +X (the default), -1 is -X
}

local function boardText(board: BasePart, value: string, face: Enum.NormalId, color: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color or CREAM
	label.Text = value
	label.Parent = gui
end
PlazaHouses.boardText = boardText

-- Frame on the outer surface of one wall; side 0 is the front (+Z), 1 is +X, 2 the back, 3 is -X.
local function wallFace(base: CFrame, w: number, d: number, side: number, y: number): (CFrame, number)
	local outward = if side % 2 == 0 then d / 2 else w / 2
	return base * CFrame.Angles(0, side * math.pi / 2, 0) * CFrame.new(0, y, outward), if side % 2 == 0 then w else d
end

-- Ivy climbing a wall from the ground: a wandering stem with leaves either side, spreading near the top.
local function ivy(m: Model, face: CFrame, x: number, height: number, rng: Random)
	local stem = Vector3.new(x, 0.2, 0.18)
	local y = 0.2
	while y < height do
		local spread = 1 + y / height * 1.4
		local nextStem = Vector3.new(stem.X + rng:NextNumber(-0.7, 0.7), y + 1.1, 0.18)
		beam(m, face * stem, face * nextStem, 0.18, rgb(84, 70, 48), nil, M.Wood).CanCollide = false
		for _ = 1, 2 do
			local leaf = part(
				m,
				Vector3.new(rng:NextNumber(0.8, 1.6), rng:NextNumber(0.6, 1.2), 0.2),
				face
					* CFrame.new(stem.X + rng:NextNumber(-1, 1) * spread, y + rng:NextNumber(0, 1), 0.22)
					* CFrame.Angles(0, 0, rng:NextNumber(0, TAU)),
				pick(rng, LEAVES),
				M.LeafyGrass
			)
			leaf.CanCollide = false
			leaf.CastShadow = false
		end
		stem = nextStem
		y += 1.1
	end
end

-- Lantern hanging from an iron bracket on a wall; `face` is the fixing point.
local function wallLantern(m: Model, face: CFrame)
	part(m, Vector3.new(0.5, 0.8, 0.2), face * CFrame.new(0, 0, 0.1), IRON, M.Metal)
	part(m, Vector3.new(0.18, 0.18, 1.5), face * CFrame.new(0, 0.2, 0.75), IRON, M.Metal).CanCollide = false
	beam(m, face * Vector3.new(0, -0.4, 0.15), face * Vector3.new(0, 0.2, 1.1), 0.12, IRON, nil, M.Metal).CanCollide =
		false
	local lantern = Props.lantern(m, face * CFrame.new(0, -1.5, 1.3))
	for _, piece in lantern:GetChildren() do
		if piece:IsA("BasePart") then
			piece.CanCollide = false
		end
	end
end

-- Shopfront: a gridded window glowing with lamplight, a striped awning and a name board.
local function shopfront(m: Model, front: CFrame, x: number, width: number, spec: Spec, rng: Random)
	local frame, awning = spec.shutter, pick(rng, AWNINGS)
	part(m, Vector3.new(width + 1, 5.8, 0.16), front * CFrame.new(x, FLOOR + 3.6, 0.08), frame, M.Wood)
	local glass =
		part(m, Vector3.new(width, 4.8, 0.2), front * CFrame.new(x, FLOOR + 3.7, 0.14), rgb(255, 214, 150), M.Neon)
	Props.light(glass, rgb(255, 214, 150), 18, 0.8)
	local panes = math.max(2, math.floor(width / 1.6))
	for i = 1, panes - 1 do
		part(
			m,
			Vector3.new(0.14, 4.8, 0.3),
			front * CFrame.new(x - width / 2 + i * width / panes, FLOOR + 3.7, 0.3),
			frame,
			M.Wood
		)
	end
	part(m, Vector3.new(width, 0.14, 0.3), front * CFrame.new(x, FLOOR + 4.7, 0.3), frame, M.Wood)
	part(m, Vector3.new(width + 1.4, 0.5, 1.2), front * CFrame.new(x, FLOOR + 1, 0.55), WOOD, M.WoodPlanks)
	local strips = math.max(4, math.floor(width / 1.3))
	for i = 0, strips - 1 do
		part(
			m,
			Vector3.new(width / strips + 0.02, 0.2, 3.4),
			front * CFrame.new(x - width / 2 + (i + 0.5) * width / strips, FLOOR + 7, 1.55) * CFrame.Angles(0.38, 0, 0),
			if i % 2 == 0 then awning else CREAM,
			M.Fabric
		).CanCollide =
			false
	end
	local board =
		part(m, Vector3.new(width * 0.85, 1.3, 0.3), front * CFrame.new(x, FLOOR + 8.4, 0.18), frame, M.WoodPlanks)
	boardText(board, spec.shop :: string, Enum.NormalId.Back, spec.signColor)
end

-- A sign on an iron arm sticking out from the wall, readable from both directions along the street.
local function bladeSign(m: Model, face: CFrame, text: string, color: Color3?)
	part(m, Vector3.new(0.3, 0.3, 3.2), face * CFrame.new(0, 0, 1.6), IRON, M.Metal).CanCollide = false
	beam(m, face * Vector3.new(0, -1.2, 0.1), face * Vector3.new(0, 0, 2.2), 0.16, IRON, nil, M.Metal).CanCollide =
		false
	for _, z in { 0.9, 2.7 } do
		part(m, Vector3.new(0.1, 0.5, 0.1), face * CFrame.new(0, -0.35, z), IRON, M.Metal).CanCollide = false
	end
	local board = part(m, Vector3.new(0.25, 1.6, 2.6), face * CFrame.new(0, -1.4, 1.8), WOOD, M.WoodPlanks)
	board.CanCollide = false
	boardText(board, text, Enum.NormalId.Right, color)
	boardText(board, text, Enum.NormalId.Left, color)
end

-- One townhouse standing on `base` (ground level, front on local +Z). Returns the model and the
-- frame at the foot of its front door, with +Z pointing out into the street.
function PlazaHouses.house(parent: Instance, base: CFrame, spec: Spec, rng: Random): (Model, CFrame, BasePart)
	local m = Instance.new("Model")
	m.Name = "PlazaHouse"
	m.Parent = parent
	local w, d, stories = spec.width, spec.depth, spec.stories
	local h = stories * STORY
	local top = FLOOR + h

	-- A plinth deep enough to meet uneven ground, then the two-tone walls
	part(m, Vector3.new(w + 0.8, 4, d + 0.8), base * CFrame.new(0, FLOOR - 2, 0), STONE, M.Limestone)
	part(m, Vector3.new(w, STORY, d), base * CFrame.new(0, FLOOR + STORY / 2, 0), spec.lower, M.Plaster)
	if stories > 1 then
		part(
			m,
			Vector3.new(w, h - STORY, d),
			base * CFrame.new(0, FLOOR + STORY + (h - STORY) / 2, 0),
			spec.upper,
			M.Plaster
		)
	end
	for s = 1, stories - 1 do
		part(m, Vector3.new(w + 0.7, 0.55, d + 0.7), base * CFrame.new(0, FLOOR + s * STORY, 0), spec.trim, M.Plaster)
		part(
			m,
			Vector3.new(w + 0.35, 0.25, d + 0.35),
			base * CFrame.new(0, FLOOR + s * STORY - 0.4, 0),
			spec.trim,
			M.Plaster
		)
	end
	-- Rusticated quoins on the ground-floor corners
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			for k = 0, 3 do
				local a = if k % 2 == 0 then 1.5 else 1.1
				part(
					m,
					Vector3.new(a, 1.9, a),
					base * CFrame.new(cx * (w / 2 - a / 2 + 0.15), FLOOR + 1.2 + k * 2.1, cz * (d / 2 - a / 2 + 0.15)),
					QUOIN,
					M.Limestone
				)
			end
		end
	end

	-- Cornice, rafter tails under the eaves, tiled roof and a chimney
	part(m, Vector3.new(w + 1.2, 0.8, d + 1.2), base * CFrame.new(0, top + 0.4, 0), spec.trim, M.Plaster)
	for _, z in { -1, 1 } do
		for x = -w / 2 + 1, w / 2 - 0.9, 1.8 do
			part(m, Vector3.new(0.4, 0.4, 1.5), base * CFrame.new(x, top - 0.1, z * (d / 2 + 0.75)), WOOD, M.Wood).CanCollide =
				false
		end
	end
	local rise = Med.gableRoof(m, base, w, d, top + 0.8, math.rad(rng:NextNumber(20, 25)), spec.roof, spec.upper)
	local chimneyX = (if rng:NextNumber() < 0.5 then -1 else 1) * w * 0.28
	local stackH = rise / 2 + 3
	part(
		m,
		Vector3.new(1.8, stackH, 1.8),
		base * CFrame.new(chimneyX, top + 0.8 + stackH / 2, -d / 4),
		spec.trim,
		M.Plaster
	)
	part(
		m,
		Vector3.new(2.4, 0.4, 2.4),
		base * CFrame.new(chimneyX, top + 0.8 + stackH + 0.2, -d / 4),
		spec.trim,
		M.Plaster
	)

	-- Front: door, shopfront or windows on the ground floor; a balcony and windows above
	local front = wallFace(base, w, d, 0, 0)
	local doorSide = spec.doorSide or 1
	local doorX = if spec.shop
		then doorSide * (w / 2 - 3.8)
		else (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(0, w / 6)
	local doorFace = front * CFrame.new(doorX, FLOOR, 0)
	local leaf = Med.door(m, doorFace, 3.4, 6.6, spec.door, spec.trim, true)
	local n = math.max(2, math.floor(w / 6))
	local windowW, windowH = 2.6, 3.8
	local lit = false
	local function addWindow(at: CFrame, upper: boolean)
		local glow = rng:NextNumber() < 0.3
		local glass = Med.window(m, at, windowW, windowH, spec.trim, spec.shutter, true, glow)
		if glow and not lit then
			Props.light(glass, rgb(255, 210, 140), 18, 0.7)
			lit = true
		end
		if upper and rng:NextNumber() < 0.4 then
			Med.flowerBox(m, at * CFrame.new(0, -windowH / 2 - 0.9, 0), windowW + 0.6, rng)
		end
	end
	if spec.shop then
		shopfront(m, front, -2.4 * doorSide, w - 9, spec, rng)
	else
		for i = 1, n do
			local x = (i - (n + 1) / 2) * (w - 6) / n
			if math.abs(x - doorX) > 5.5 then
				addWindow(front * CFrame.new(x, FLOOR + STORY * 0.5, 0), false)
			end
		end
	end
	local balconyX = if spec.balcony then (if spec.shop then 0 else doorX) else nil
	for s = 2, stories do
		local y = FLOOR + (s - 1) * STORY
		if s == 2 and balconyX then
			local sill = front * CFrame.new(balconyX, y + 0.3, 0)
			Med.door(m, sill, 3, 6.4, spec.shutter, spec.trim, true)
			Med.balcony(m, sill, 9, 2.4, spec.trim)
			for _, side in { -1, 1 } do
				part(m, Vector3.new(0.8, 1.6, 1.8), sill * CFrame.new(side * 3.6, -1.1, 0.9), spec.trim, M.Plaster)
			end
			Med.pot(m, sill:PointToWorldSpace(Vector3.new(-3.4, 0, 1.2)), rng, "flowers")
		end
		for i = 1, n do
			local x = (i - (n + 1) / 2) * (w - 6) / n
			if not (s == 2 and balconyX and math.abs(x - balconyX) < 7.8) then
				addWindow(front * CFrame.new(x, y + STORY * 0.5, 0), true)
			end
		end
	end

	-- Sides and back carry fewer windows, some left blank
	for side = 1, 3 do
		local face, width = wallFace(base, w, d, side, 0)
		local count = math.max(1, math.floor(width / 7))
		for s = 1, stories do
			for i = 1, count do
				if rng:NextNumber() < 0.35 then
					continue
				end
				local x = (i - (count + 1) / 2) * (width - 6) / count
				addWindow(face * CFrame.new(x, FLOOR + (s - 1) * STORY + STORY * 0.5, 0), s > 1)
			end
		end
	end

	-- Street details: lanterns either side of the door, ivy, a sign, pots and barrels on the step
	for _, side in { -1, 1 } do
		-- On a shop the awning takes the place of the lantern nearer the window
		if math.abs(doorX + side * 2.9) < w / 2 - 1 and not (spec.shop and side ~= doorSide) then
			wallLantern(m, doorFace * CFrame.new(side * 2.9, 8.4, 0))
		end
	end
	local ivyX = if doorX > 0 then -w / 2 + rng:NextNumber(1.5, 3) else w / 2 - rng:NextNumber(1.5, 3)
	ivy(m, front, ivyX, math.min(h, STORY * 1.6) + rng:NextNumber(-2, 2), rng)
	if rng:NextNumber() < 0.5 then
		local sideFace = wallFace(base, w, d, if ivyX > 0 then 1 else 3, 0)
		ivy(m, sideFace, (if ivyX > 0 then 1 else -1) * (d / 2 - 2), h * 0.8, rng)
	end
	if spec.blade then
		local bladeX = if doorX > 0 then -w / 2 + 0.8 else w / 2 - 0.8
		bladeSign(m, front * CFrame.new(bladeX, FLOOR + 9.2, 0), spec.blade :: string, spec.signColor)
	end
	-- Kept to a narrow strip by the wall, so nothing spills onto the kerb of the square
	local street = base * CFrame.new(0, 0, d / 2 + 1.6)
	for _ = 1, rng:NextInteger(1, 3) do
		local x = rng:NextNumber(-w / 2 + 1.5, w / 2 - 1.5)
		if math.abs(x - doorX) < 3.5 or (spec.shop and x * doorSide < w / 2 - 6) then
			continue
		end
		local roll = rng:NextNumber()
		local at = street:PointToWorldSpace(Vector3.new(x, 0, rng:NextNumber(-0.4, 0.2)))
		if roll < 0.45 then
			Props.barrel(m, at, rng)
		else
			Med.pot(m, at, rng, if roll < 0.75 then "flowers" else "lemon")
		end
	end
	Props.simplifyHouseCollision(m)
	return m, doorFace, leaf
end

-- A random member of the plaza family, so the rows read as one street of individual houses.
function PlazaHouses.spec(rng: Random, width: number, depth: number, stories: number): Spec
	local lower = pick(rng, LOWER)
	local upper = pick(rng, UPPER)
	if upper == lower then
		upper = UPPER[1]
	end
	local shop = if rng:NextNumber() < 0.3 then pick(rng, SHOPS) else nil
	return {
		width = width,
		depth = depth,
		stories = stories,
		lower = lower,
		upper = upper,
		trim = rgb(248, 240, 222),
		shutter = pick(rng, SHUTTERS),
		roof = pick(rng, ROOFS),
		door = pick(rng, DOORS),
		balcony = stories > 1 and rng:NextNumber() < 0.6,
		shop = shop,
		blade = if shop == nil and rng:NextNumber() < 0.2 then pick(rng, SHOPS) else nil,
	}
end

----------------------------------------------------------------------------------------------------
-- Placement round the piazza

-- Plots in paving coordinates (the square runs to ±60), each { x, z, facing, width, stories }.
-- Width runs along the row; every house is 16 deep and fronts onto the square.
local DEPTH = 16
local function plots(): { { number } }
	local list = {}
	local function row(
		fixed: number,
		from: number,
		widths: { number },
		facing: number,
		axis: string,
		stories: { number }
	)
		local at = from
		for i, width in widths do
			local middle = at + width / 2
			if axis == "z" then
				table.insert(list, { fixed, middle, facing, width, stories[i] })
			else
				table.insert(list, { middle, fixed, facing, width, stories[i] })
			end
			at += width
		end
	end
	-- West and east rows run from the north corner toward the bay; the north row closes the top.
	row(-72, -60, { 18, 16, 18, 16, 14 }, math.pi / 2, "z", { 3, 2, 3, 2, 2 })
	row(72, -60, { 16, 18, 16, 18, 14 }, -math.pi / 2, "z", { 2, 3, 2, 3, 2 })
	row(-72, -80, { 18, 18, 18, 16, 20, 16, 18, 18, 18 }, 0, "x", { 3, 2, 3, 2, 3, 3, 2, 3, 2 })
	return list
end

-- Conservative overlap: the bounds of `item` measured in the footprint box's own space.
local function overlaps(footprint: CFrame, half: Vector3, item: BasePart): boolean
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low
	for _, x in { -0.5, 0.5 } do
		for _, y in { -0.5, 0.5 } do
			for _, z in { -0.5, 0.5 } do
				local p = footprint:PointToObjectSpace(
					item.CFrame * Vector3.new(item.Size.X * x, item.Size.Y * y, item.Size.Z * z)
				)
				low, high = low:Min(p), high:Max(p)
			end
		end
	end
	return low.X < half.X
		and high.X > -half.X
		and low.Y < half.Y
		and high.Y > -half.Y
		and low.Z < half.Z
		and high.Z > -half.Z
end

-- The highest ground under a plot's corners, so a house never sinks into a rising slope.
local function groundUnder(island: Instance?, frame: CFrame, w: number, d: number, fallback: number): number
	local groundModel = island and island:FindFirstChild("Ground")
	if not groundModel then
		return fallback
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { groundModel }
	local best = fallback
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		local p = frame:PointToWorldSpace(Vector3.new(c[1] * w / 2, 0, c[2] * d / 2))
		local hit = workspace:Raycast(p + Vector3.new(0, 60, 0), Vector3.new(0, -120, 0), params)
		if hit then
			best = math.max(best, hit.Position.Y)
		end
	end
	return math.min(best, fallback + 3)
end

-- pavingFrame is the top of the paving at the centre of the square.
function PlazaHouses.build(plaza: Model, pavingFrame: CFrame): Model
	local existing = plaza:FindFirstChild("PlazaHouses")
	if existing and existing:GetAttribute("LayoutVersion") == LAYOUT_VERSION then
		return existing
	elseif existing then
		existing:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "PlazaHouses"
	model:SetAttribute("LayoutVersion", LAYOUT_VERSION)

	local village = plaza.Parent
	local island = village and village.Parent
	-- Streets, paths, beach, bases and the square itself block a plot. Generated houses and trees
	-- are cleared off it instead.
	local clearable: { Instance } = {}
	for _, name in { "Houses" } do
		local folder = village and village:FindFirstChild(name)
		if folder then
			table.insert(clearable, folder)
		end
	end
	for _, name in { "Hilltops", "Forest" } do
		local folder = island and island:FindFirstChild(name)
		if folder then
			table.insert(clearable, folder)
		end
	end
	local center = pavingFrame.Position
	local blocking, removable = {}, {}
	local function near(item: BasePart): boolean
		local offset = item.Position - center
		return Vector2.new(offset.X, offset.Z).Magnitude < 150 + item.Size.Magnitude / 2
	end
	if village then
		for _, item in village:GetDescendants() do
			if item:IsA("BasePart") and near(item) then
				local owner = nil
				for _, folder in clearable do
					if item:IsDescendantOf(folder) then
						owner = folder
						break
					end
				end
				if owner then
					-- Remove the whole prop (a house, lamp or tree), not just the overlapping part
					local target: Instance = item
					while target.Parent and target.Parent ~= owner do
						target = target.Parent
					end
					table.insert(removable, { item, target })
				else
					table.insert(blocking, item)
				end
			end
		end
	end
	for _, folder in clearable do
		if not folder:IsDescendantOf(village :: Instance) then
			for _, item in folder:GetDescendants() do
				if item:IsA("BasePart") and near(item) then
					local target: Instance = item
					while target.Parent and target.Parent ~= folder do
						target = target.Parent
					end
					table.insert(removable, { item, target })
				end
			end
		end
	end
	local bases = island and island:FindFirstChild("Bases")
	if bases then
		for _, item in bases:GetDescendants() do
			if item:IsA("BasePart") and near(item) then
				table.insert(blocking, item)
			end
		end
	end

	local rng = Random.new(7311)
	local groundY = center.Y - 0.8
	for index, plot in plots() do
		local x, z, facing, width, stories = plot[1], plot[2], plot[3], plot[4], plot[5]
		local spec = PlazaHouses.spec(rng, width, DEPTH, stories)
		local frame = CFrame.new(center.X, groundY, center.Z) * CFrame.new(x, 0, z) * CFrame.Angles(0, facing, 0)
		-- Plots touch along the row, so test each one fractionally inside its own walls
		local footprint = frame * CFrame.new(0, 20, 0)
		local half = Vector3.new(width / 2 - 0.3, 19.5, DEPTH / 2 + 1)
		local clear = true
		for _, item in blocking do
			if item.Parent and item.Transparency < 1 and overlaps(footprint, half, item) then
				clear = false
				break
			end
		end
		if not clear then
			continue
		end
		local doomed: { [Instance]: boolean } = {}
		for _, entry in removable do
			if entry[2].Parent and overlaps(footprint, half, entry[1]) then
				doomed[entry[2]] = true
			end
		end
		for target in doomed do
			target:Destroy()
		end
		local y = groundUnder(island, frame, width, DEPTH, groundY)
		local house = PlazaHouses.house(model, frame + Vector3.new(0, y - groundY, 0), spec, rng)
		house.Name = "PlazaHouse" .. index
	end
	model.Parent = plaza
	return model
end

-- The current paving is 116 studs wide; older baked maps used 120. Its top centre anchors
-- everything added to a saved square.
function PlazaHouses.pavingFrame(plaza: Model): CFrame?
	for _, slab in plaza:GetChildren() do
		if
			slab:IsA("BasePart")
			and slab.Size.X >= 115.9
			and slab.Size.X <= 120.1
			and math.abs(slab.Size.X - slab.Size.Z) < 0.01
			and slab.Size.Y <= 1
		then
			return slab.CFrame * CFrame.new(0, slab.Size.Y / 2, 0)
		end
	end
	return nil
end

function PlazaHouses.ensure(root: Instance)
	for _, plaza in root:GetDescendants() do
		if plaza:IsA("Model") and plaza.Name == "Plaza" then
			local frame = PlazaHouses.pavingFrame(plaza)
			if frame then
				PlazaHouses.build(plaza, frame)
			end
		end
	end
end

return PlazaHouses

end
dependencies.PlazaHouses = loadPlazaHouses()
local function loadRodShop()
	-- Tide & Tackle, the rod store on the west side of the piazza. Outside it is one of the plaza's
-- two-tone townhouses with a shopfront; its street door leads into a two-level hall built away
-- from the map, with a gallery round three sides under open roof trusses. The hall's exit leads
-- back out onto the square. The same versioned builder repairs saved Studio maps at startup.
local CollectionService = game:GetService("CollectionService")

local LowPoly = dependencies.LowPoly
local PlazaHouses = dependencies.PlazaHouses
local Props = dependencies.Props

local RodShop = {}
local LAYOUT_VERSION = 3
local INTERIOR_VERSION = 6
local TAU = math.pi * 2
local rgb = Color3.fromRGB
local M = Enum.Material

-- 1500 studs past the ocean's edge (Biomes.MapHalfSize is 5200), where nothing else is ever built
local INTERIOR_ORIGIN = CFrame.new(6700, 300, 0)
local W, D = 56, 44 -- inner floor of the hall
local GALLERY = 12 -- height of the gallery deck
local EAVES = 24 -- top of the side walls
local RIDGE = 34

local YELLOW = rgb(244, 196, 76)
local MINT = rgb(156, 214, 192)
local FLOOR_WOOD = rgb(150, 104, 64)
local WOOD = rgb(184, 132, 72)
local BEAM = rgb(150, 100, 52)
local DARK_WOOD = rgb(102, 70, 44)
local GREEN_DOOR = rgb(84, 160, 70)
local DOOR_FRAME = rgb(214, 196, 150)
local WINDOW_FRAME = rgb(58, 112, 52)
local DAYLIGHT = rgb(255, 238, 176)
local CREAM = rgb(255, 245, 213)
local IRON = rgb(50, 57, 57)
local LAMP = rgb(255, 214, 150)
local LEAF = { rgb(86, 170, 60), rgb(110, 196, 70), rgb(70, 146, 52) }

local function interiorFolder(): Folder
	local folder = workspace:FindFirstChild("Interiors")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Interiors"
		folder.Parent = workspace
	end
	return folder :: Folder
end

local function doorPrompt(parent: BasePart, action: string, destination: CFrame): ProximityPrompt
	local prompt = parent:FindFirstChild("RodStoreDoorPrompt") :: ProximityPrompt?
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RodStoreDoorPrompt"
		prompt.ObjectText = "Tide & Tackle"
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt.Parent = parent
	end
	local p = prompt :: ProximityPrompt
	p.ActionText = action
	p:SetAttribute("TeleportTo", destination)
	return p
end

----------------------------------------------------------------------------------------------------
-- Interior

local function buildInterior(): Model
	local o = INTERIOR_ORIGIN
	local hall = Instance.new("Model")
	hall.Name = "RodStoreInterior"
	hall:SetAttribute("LayoutVersion", INTERIOR_VERSION)
	hall:SetAttribute("InteriorFrame", o * CFrame.new(0, RIDGE / 2, 0))
	hall:SetAttribute("InteriorSize", Vector3.new(W, RIDGE, D))
	hall:SetAttribute("ArrivalFrame", o * CFrame.new(0, 3.2, -D / 2 + 5) * CFrame.Angles(0, math.pi, 0))
	-- Stream the whole hall in at once so nobody arrives on a half-loaded floor
	hall.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local rng = Random.new(2811)

	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
		local piece = Props.part(hall, size, o * cf, color, material or M.Wood)
		piece.Name = name
		return piece
	end
	local function deco(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
		local piece = part(name, size, cf, color, material)
		piece.CanCollide = false
		return piece
	end
	local function beam(name: string, a: Vector3, b: Vector3, width: number, color: Color3, thickness: number?): Part
		local piece = Props.beam(hall, o * a, o * b, width, color, thickness, M.Wood)
		piece.Name = name
		return piece
	end
	local function glow(piece: BasePart, color: Color3, range: number, brightness: number)
		Props.light(piece, color, range, brightness)
	end
	-- Frame on a wall's inner face at `pos`, with +Z pointing into the room along `normal`
	local function onWall(pos: Vector3, normal: Vector3): CFrame
		return CFrame.lookAt(pos, pos - normal)
	end
	local function disc(name: string, face: CFrame, diameter: number, thickness: number, color: Color3, material)
		local piece = part(
			name,
			Vector3.new(thickness, diameter, diameter),
			face * CFrame.Angles(0, math.pi / 2, 0),
			color,
			material
		)
		piece.Shape = Enum.PartType.Cylinder
		piece.CanCollide = false
		return piece
	end

	-- Shell: plank floor, yellow lower walls, mint upper walls, gables and a tiled roof
	part("Floor", Vector3.new(W + 2, 1, D + 2), CFrame.new(0, -0.5, 0), FLOOR_WOOD, M.WoodPlanks)
	for i = -3, 3 do
		deco("FloorBoardLine", Vector3.new(0.12, 0.02, D), CFrame.new(i * 8, 0.01, 0), DARK_WOOD, M.Wood)
	end
	for _, side in { -1, 1 } do
		part(
			"SideWallLower",
			Vector3.new(1, GALLERY, D + 2),
			CFrame.new(side * (W / 2 + 0.5), GALLERY / 2, 0),
			YELLOW,
			M.Plaster
		)
		part(
			"SideWallUpper",
			Vector3.new(1, EAVES - GALLERY, D + 2),
			CFrame.new(side * (W / 2 + 0.5), (GALLERY + EAVES) / 2, 0),
			MINT,
			M.Plaster
		)
		part(
			"EndWallLower",
			Vector3.new(W, GALLERY, 1),
			CFrame.new(0, GALLERY / 2, side * (D / 2 + 0.5)),
			YELLOW,
			M.Plaster
		)
		part(
			"EndWallUpper",
			Vector3.new(W, EAVES - GALLERY, 1),
			CFrame.new(0, (GALLERY + EAVES) / 2, side * (D / 2 + 0.5)),
			MINT,
			M.Plaster
		)
		for _, x in { -1, 1 } do
			LowPoly.triangle(
				(o * Vector3.new(x * (W / 2 + 1), EAVES, side * (D / 2 + 0.5))),
				(o * Vector3.new(0, RIDGE + 0.5, side * (D / 2 + 0.5))),
				(o * Vector3.new(0, EAVES, side * (D / 2 + 0.5))),
				o * Vector3.new(0, EAVES, 0),
				MINT,
				hall,
				M.Plaster,
				1
			)
		end
		-- Wainscot and the dado rail round the ground floor
		part("Wainscot", Vector3.new(0.2, 3, D), CFrame.new(side * (W / 2 - 0.1), 1.5, 0), WOOD, M.WoodPlanks)
		part("Wainscot", Vector3.new(W, 3, 0.2), CFrame.new(0, 1.5, side * (D / 2 - 0.1)), WOOD, M.WoodPlanks)
		local slope = math.atan2(RIDGE - EAVES, W / 2)
		local run = math.sqrt((W / 2 + 2) ^ 2 + (RIDGE - EAVES) ^ 2)
		part(
			"Roof",
			Vector3.new(run, 1, D + 4),
			CFrame.new(side * W / 4, (EAVES + RIDGE) / 2 + 0.8, 0) * CFrame.Angles(0, 0, -side * slope),
			rgb(176, 98, 64),
			M.WoodPlanks
		)
	end

	-- Exposed trusses: tie beam, king post, rafters and struts, with purlins along the slopes
	for _, z in { -16, -5.5, 5.5, 16 } do
		beam("TieBeam", Vector3.new(-W / 2, EAVES, z), Vector3.new(W / 2, EAVES, z), 1.1, BEAM)
		beam("KingPost", Vector3.new(0, EAVES, z), Vector3.new(0, RIDGE, z), 0.9, BEAM)
		for _, side in { -1, 1 } do
			beam("Rafter", Vector3.new(side * W / 2, EAVES, z), Vector3.new(0, RIDGE, z), 1, BEAM)
			beam(
				"Strut",
				Vector3.new(0, EAVES + 1, z),
				Vector3.new(side * W / 4, EAVES + (RIDGE - EAVES) / 2, z),
				0.6,
				BEAM
			)
		end
	end
	beam("Ridge", Vector3.new(0, RIDGE, -D / 2), Vector3.new(0, RIDGE, D / 2), 1.1, BEAM)
	for _, side in { -1, 1 } do
		for _, t in { 0.35, 0.7 } do
			local x, y = side * W / 2 * (1 - t), EAVES + (RIDGE - EAVES) * t
			beam("Purlin", Vector3.new(x, y, -D / 2), Vector3.new(x, y, D / 2), 0.7, BEAM)
		end
	end

	-- Gallery decks round the back and sides, held up on posts and edge beams
	local inner = W / 2 - 7
	local backEdge = D / 2 - 8
	part("GalleryBack", Vector3.new(W, 0.8, 8), CFrame.new(0, GALLERY - 0.4, D / 2 - 4), WOOD, M.WoodPlanks)
	for _, side in { -1, 1 } do
		part(
			"GallerySide",
			Vector3.new(7, 0.8, backEdge + 6),
			CFrame.new(side * (inner + 3.5), GALLERY - 0.4, (backEdge - 6) / 2),
			WOOD,
			M.WoodPlanks
		)
		beam(
			"GalleryEdgeBeam",
			Vector3.new(side * inner, GALLERY - 1.2, -6),
			Vector3.new(side * inner, GALLERY - 1.2, backEdge),
			1,
			BEAM
		)
		for _, z in { -6, 4, backEdge } do
			part(
				"GalleryPost",
				Vector3.new(1, GALLERY - 0.8, 1),
				CFrame.new(side * inner, (GALLERY - 0.8) / 2, z),
				BEAM
			)
		end
	end
	beam(
		"GalleryEdgeBeam",
		Vector3.new(-inner, GALLERY - 1.2, backEdge),
		Vector3.new(inner, GALLERY - 1.2, backEdge),
		1,
		BEAM
	)
	for _, x in { -11, 11 } do
		part("GalleryPost", Vector3.new(1, GALLERY - 0.8, 1), CFrame.new(x, (GALLERY - 0.8) / 2, backEdge), BEAM)
	end
	-- Turned balusters under a handrail along every open edge
	local function balustrade(a: Vector3, b: Vector3)
		local length = (b - a).Magnitude
		local dir = (b - a).Unit
		for k = 0, math.floor(length / 1.25) do
			local p = a + dir * (k * 1.25) + Vector3.new(0, GALLERY + 1.5, 0)
			part("Baluster", Vector3.new(0.4, 3, 0.4), CFrame.new(p), WOOD)
			deco("BalusterBulb", Vector3.new(0.65, 0.7, 0.65), CFrame.new(p + Vector3.new(0, -0.3, 0)), WOOD)
		end
		beam("Handrail", a + Vector3.new(0, GALLERY + 3.2, 0), b + Vector3.new(0, GALLERY + 3.2, 0), 0.6, BEAM, 0.45)
		beam("BottomRail", a + Vector3.new(0, GALLERY + 0.2, 0), b + Vector3.new(0, GALLERY + 0.2, 0), 0.5, BEAM, 0.3)
	end
	balustrade(Vector3.new(-inner, 0, backEdge), Vector3.new(inner, 0, backEdge))
	for _, side in { -1, 1 } do
		balustrade(Vector3.new(side * inner, 0, -6), Vector3.new(side * inner, 0, backEdge))
	end
	balustrade(Vector3.new(-W / 2, 0, -6), Vector3.new(-inner, 0, -6))

	-- Stairs up the right-hand wall arrive at the open front end of that gallery
	local steps = 15
	local rise = GALLERY / steps
	for i = 1, steps do
		part(
			"Stair",
			Vector3.new(6.5, i * rise, 1),
			CFrame.new(inner + 3.5, i * rise / 2, -6 - (steps - i) - 0.5),
			WOOD,
			M.WoodPlanks
		)
		deco(
			"StairNosing",
			Vector3.new(6.5, 0.15, 0.2),
			CFrame.new(inner + 3.5, i * rise + 0.02, -6 - (steps - i) - 0.95),
			DARK_WOOD
		)
	end
	beam("StairRail", Vector3.new(inner, 3.2, -6 - steps), Vector3.new(inner, GALLERY + 3.2, -6), 0.5, BEAM, 0.45)
	for k = 0, steps - 1, 2 do
		local y = (k + 1) * rise
		part("StairBaluster", Vector3.new(0.35, 3, 0.35), CFrame.new(inner, y + 1.5, -6 - steps + k + 0.5), WOOD)
	end

	-- Windows of small green panes and arched green doors, as on a harbour warehouse
	local function gridWindow(face: CFrame, width: number, height: number)
		deco(
			"WindowSurround",
			Vector3.new(width + 1, height + 1, 0.2),
			face * CFrame.new(0, 0, 0.1),
			DOOR_FRAME,
			M.Limestone
		)
		deco(
			"WindowArch",
			Vector3.new(0.2, width + 1, width + 1),
			face * CFrame.new(0, height / 2, 0.1) * CFrame.Angles(0, math.pi / 2, 0),
			DOOR_FRAME,
			M.Limestone
		).Shape =
			Enum.PartType.Cylinder
		local pane =
			deco("WindowLight", Vector3.new(width, height, 0.2), face * CFrame.new(0, 0, 0.22), DAYLIGHT, M.Neon)
		disc("WindowLightArch", face * CFrame.new(0, height / 2, 0.22), width, 0.2, DAYLIGHT, M.Neon)
		for i = 1, 3 do
			deco(
				"WindowBar",
				Vector3.new(0.18, height + width / 2, 0.3),
				face * CFrame.new(-width / 2 + i * width / 4, width / 4, 0.36),
				WINDOW_FRAME
			)
		end
		for j = 1, 4 do
			deco(
				"WindowBar",
				Vector3.new(width, 0.18, 0.3),
				face * CFrame.new(0, -height / 2 + j * height / 4, 0.36),
				WINDOW_FRAME
			)
		end
		deco(
			"WindowSill",
			Vector3.new(width + 1.6, 0.35, 0.9),
			face * CFrame.new(0, -height / 2 - 0.5, 0.4),
			DOOR_FRAME,
			M.Limestone
		)
		return pane
	end
	local function archDoor(face: CFrame, width: number, height: number): Part
		deco(
			"DoorSurround",
			Vector3.new(width + 1.6, height, 0.25),
			face * CFrame.new(0, height / 2, 0.12),
			DOOR_FRAME,
			M.Limestone
		)
		disc("DoorSurroundArch", face * CFrame.new(0, height, 0.12), width + 1.6, 0.25, DOOR_FRAME, M.Limestone)
		local leaf = part(
			"DoorLeaf",
			Vector3.new(width, height, 0.3),
			face * CFrame.new(0, height / 2, 0.35),
			GREEN_DOOR,
			M.WoodPlanks
		)
		disc("DoorLeafArch", face * CFrame.new(0, height, 0.35), width, 0.3, GREEN_DOOR, M.WoodPlanks)
		for i = 1, 3 do
			deco(
				"DoorPlank",
				Vector3.new(0.12, height + width / 2 - 0.4, 0.4),
				face * CFrame.new(-width / 2 + i * width / 4, height / 2 + width / 4 - 0.2, 0.42),
				rgb(64, 130, 54)
			)
		end
		for _, y in { 0.25, 0.75 } do
			deco(
				"DoorStrap",
				Vector3.new(width * 0.7, 0.4, 0.45),
				face * CFrame.new(-width * 0.12, height * y, 0.45),
				DOOR_FRAME,
				M.Metal
			)
		end
		deco(
			"DoorHandle",
			Vector3.new(0.4, 1.4, 0.35),
			face * CFrame.new(width * 0.3, height * 0.45, 0.62),
			DOOR_FRAME,
			M.Metal
		)
		return leaf
	end

	-- Front wall: the way out between two tall windows, and windows above the gallery line
	local front = onWall(Vector3.new(0, 0, -D / 2), Vector3.new(0, 0, 1))
	local exit = archDoor(front, 6, 9)
	for _, x in { -14, 14 } do
		local glass = gridWindow(front * CFrame.new(x, 6, 0), 5, 6)
		glow(glass, DAYLIGHT, 16, 0.6)
		gridWindow(front * CFrame.new(x, GALLERY + 5, 0), 4, 4.5)
	end
	gridWindow(front * CFrame.new(-24, 6, 0), 3, 5)
	-- Left wall (its local +X runs toward the front): a green door on each level and windows between
	local left = onWall(Vector3.new(-W / 2, 0, 0), Vector3.new(1, 0, 0))
	archDoor(left * CFrame.new(3, 0, 0), 5, 8)
	archDoor(left * CFrame.new(-4, GALLERY, 0), 4.4, 7.4)
	gridWindow(left * CFrame.new(18, 6, 0), 4, 5.5)
	for _, x in { -11, 14 } do
		gridWindow(left * CFrame.new(x, GALLERY + 5, 0), 4, 4.5)
	end
	-- Right wall (local +X runs toward the back): windows above the stairs and along the gallery
	local right = onWall(Vector3.new(W / 2, 0, 0), Vector3.new(-1, 0, 0))
	for _, x in { -14, 0, 12 } do
		gridWindow(right * CFrame.new(x, GALLERY + 5, 0), 4, 4.5)
	end
	gridWindow(right * CFrame.new(9.5, 6, 0), 4, 5.5)
	-- Back wall upstairs
	local back = onWall(Vector3.new(0, 0, D / 2), Vector3.new(0, 0, -1))
	archDoor(back * CFrame.new(0, GALLERY, 0), 4.4, 7.4)
	for _, x in { -14, 14 } do
		gridWindow(back * CFrame.new(x, GALLERY + 5, 0), 4, 4.5)
	end

	-- Glowing brick alcove at the back, where the store keeps its prize rod
	local alcove = back
	for _, x in { -4.2, 4.2 } do
		part("AlcovePier", Vector3.new(1.6, 9, 1.6), alcove * CFrame.new(x, 4.5, 0.8), rgb(196, 176, 150), M.Brick)
	end
	part("AlcoveHeader", Vector3.new(10, 1.6, 1.6), alcove * CFrame.new(0, 9.8, 0.8), rgb(196, 176, 150), M.Brick)
	local alcoveGlow =
		deco("AlcoveGlow", Vector3.new(6.8, 8.8, 0.2), alcove * CFrame.new(0, 4.4, 0.15), rgb(214, 96, 196), M.Neon)
	glow(alcoveGlow, rgb(232, 110, 214), 14, 0.6)
	part("AlcovePlinth", Vector3.new(3, 2.4, 2), alcove * CFrame.new(0, 1.2, 1.4), rgb(120, 110, 130), M.Slate)
	local prizeBase = alcove * CFrame.new(0, 2.4, 1.4)
	beam(
		"PrizeRodBlank",
		(prizeBase * CFrame.new(-0.4, 0.3, 0)).Position,
		(prizeBase * CFrame.new(0.8, 6.6, 0)).Position,
		0.18,
		rgb(255, 196, 60)
	).Material =
		M.Neon
	beam(
		"PrizeRodGrip",
		(prizeBase * CFrame.new(-0.6, 0, 0)).Position,
		(prizeBase * CFrame.new(-0.3, 1.6, 0)).Position,
		0.35,
		DARK_WOOD
	)

	-- The counter, with racks of rods behind it under the back gallery
	part("CounterBase", Vector3.new(16, 3.2, 2.6), CFrame.new(0, 1.6, backEdge - 6), rgb(70, 126, 110), M.WoodPlanks)
	part("CounterTop", Vector3.new(16.6, 0.35, 3.2), CFrame.new(0, 3.37, backEdge - 6), WOOD)
	for _, x in { -6, -2, 2, 6 } do
		deco(
			"CounterPanel",
			Vector3.new(3.2, 2.2, 0.12),
			CFrame.new(x, 1.6, backEdge - 7.35),
			rgb(58, 104, 92),
			M.WoodPlanks
		)
	end
	local menu =
		deco("RodPriceBoard", Vector3.new(6, 1.4, 0.15), CFrame.new(0, 8.8, backEdge - 4.2), DARK_WOOD, M.WoodPlanks)
	PlazaHouses.boardText(menu, "ROD UPGRADES", Enum.NormalId.Front)
	for _, x in { -2.9, 2.9 } do
		deco("BoardHanger", Vector3.new(0.12, 2.5, 0.12), CFrame.new(x, 10.75, backEdge - 4.2), IRON, M.Metal)
	end
	-- A brass bell and a ledger on the counter
	deco("CounterBell", Vector3.new(0.8, 0.6, 0.8), CFrame.new(5.5, 3.85, backEdge - 6), rgb(214, 170, 70), M.Metal).Shape =
		Enum.PartType.Ball
	deco(
		"Ledger",
		Vector3.new(1.8, 0.25, 1.3),
		CFrame.new(-5, 3.67, backEdge - 6) * CFrame.Angles(0, 0.25, 0),
		rgb(120, 40, 36),
		M.Fabric
	)

	local rodColors = { rgb(64, 103, 89), rgb(183, 81, 51), rgb(47, 81, 118), rgb(175, 134, 62), rgb(120, 70, 140) }
	local function rodRack(face: CFrame, count: number)
		local width = count * 1.6 + 1
		part("RackBase", Vector3.new(width, 1.2, 1.4), face * CFrame.new(0, 0.6, 0.8), DARK_WOOD)
		deco("RackRail", Vector3.new(width, 0.35, 0.5), face * CFrame.new(0, 7.2, 0.35), DARK_WOOD)
		for _, x in { -width / 2, width / 2 } do
			part("RackSide", Vector3.new(0.4, 8, 1.4), face * CFrame.new(x, 4, 0.8), DARK_WOOD)
		end
		for i = 1, count do
			local x = -width / 2 + 0.5 + (i - 0.5) * 1.6
			local color = rodColors[(i - 1) % #rodColors + 1]
			local foot = face * Vector3.new(x, 1.2, 0.9)
			local tip = face * Vector3.new(x + 0.3, 10.5, 0.35)
			Props.beam(hall, o * foot, o * tip, 0.14, color, nil, M.SmoothPlastic).CanCollide = false
			Props.beam(hall, o * foot, o * (face * Vector3.new(x + 0.05, 3, 0.85)), 0.3, rgb(196, 150, 96), nil, M.Wood).CanCollide =
				false
			deco("RackReel", Vector3.new(0.45, 0.6, 0.4), face * CFrame.new(x, 3.4, 1.15), IRON, M.Metal)
		end
	end
	rodRack(back * CFrame.new(-11.5, 0, 0), 7)
	rodRack(back * CFrame.new(11.5, 0, 0), 7)
	rodRack(left * CFrame.new(-16.5, 0, 0), 6)
	rodRack(right * CFrame.new(0, 0, 0), 6)

	-- Tackle shelves and a bookcase of fishing almanacs
	local function shelves(face: CFrame, width: number, height: number, tiers: number)
		for _, x in { -width / 2, width / 2 } do
			part("ShelfSide", Vector3.new(0.35, height, 1.8), face * CFrame.new(x, height / 2, 0.9), DARK_WOOD)
		end
		deco("ShelfBack", Vector3.new(width, height, 0.15), face * CFrame.new(0, height / 2, 0.08), WOOD, M.WoodPlanks)
		for t = 0, tiers do
			local y = 0.3 + t * (height - 0.6) / tiers
			part("Shelf", Vector3.new(width, 0.25, 1.8), face * CFrame.new(0, y, 0.9), DARK_WOOD)
			if t == tiers then
				continue
			end
			local x = -width / 2 + 0.5
			while x < width / 2 - 0.6 do
				local roll = rng:NextNumber()
				if roll < 0.55 then
					local bookW = rng:NextNumber(0.35, 0.6)
					local bookH = rng:NextNumber(1.2, 1.8)
					deco(
						"Book",
						Vector3.new(bookW, bookH, 1.3),
						face * CFrame.new(x + bookW / 2, y + 0.12 + bookH / 2, 0.9),
						Props.pick(rng, rodColors),
						M.Fabric
					)
					x += bookW + 0.05
				elseif roll < 0.8 then
					deco(
						"TackleTin",
						Vector3.new(1.1, 0.7, 1.2),
						face * CFrame.new(x + 0.55, y + 0.47, 0.9),
						Props.pick(rng, { rgb(70, 126, 110), rgb(190, 152, 100), rgb(170, 70, 50) }),
						M.SmoothPlastic
					)
					x += 1.2
				else
					local coins = deco(
						"GoldCoins",
						Vector3.new(0.4, 1, 1),
						face * CFrame.new(x + 0.5, y + 0.3, 0.9) * CFrame.Angles(0, 0, math.pi / 2),
						rgb(244, 198, 60),
						M.Metal
					)
					coins.Shape = Enum.PartType.Cylinder
					x += 1.1
				end
			end
		end
	end
	shelves(right * CFrame.new(16, 0, 0), 5, 7.5, 4)
	shelves(left * CFrame.new(11, 0, 0), 4.5, 6, 3)

	-- Floor props: a bench, barrels, crate stacks, display pedestals and a long rug down the aisle
	local function at(x: number, z: number, y: number?): Vector3
		return o * Vector3.new(x, y or 0, z)
	end
	Props.bench(hall, at(-W / 2 + 2.2, 4.5), math.pi / 2)
	for _, p in { { -W / 2 + 2, 9.2 }, { -W / 2 + 4.4, 10 }, { inner - 2, -16 } } do
		Props.barrel(hall, at(p[1], p[2]), rng)
	end
	Props.crates(hall, at(inner - 2, 10), rng)
	Props.crates(hall, at(-inner + 2, -19), rng)
	deco("AisleRug", Vector3.new(7, 0.06, 24), CFrame.new(0, 0.03, -8), rgb(170, 66, 52), M.Fabric)
	deco("AisleRugBorder", Vector3.new(8, 0.04, 25), CFrame.new(0, 0.02, -8), rgb(222, 180, 90), M.Fabric)
	-- A plain wooden crate with an empty inside and a separate hinged lid. Its prompt opens the
	-- crate window; FishingService checks the angler is standing at it.
	-- Bobbers take the opposite side of the aisle, facing the rod cases.
	for _, bobberCase in { false, true } do
		local kind = if bobberCase then "Bobber" else "Rod"
		local stand = CFrame.new(if bobberCase then -10 else 10, 0, -6)
			* CFrame.Angles(0, if bobberCase then -math.pi / 2 else math.pi / 2, 0)
		part("CratePlinth", Vector3.new(3.4, 0.8, 3), stand * CFrame.new(0, 0.4, 0), rgb(120, 116, 112), M.Slate)
		local display = Instance.new("Model")
		display.Name = kind .. "CrateDisplay"
		display:SetAttribute("CrateFrame", o * stand)
		display:SetAttribute("LidHinge", o * stand * CFrame.new(0, 2.4, 0.9))
		display.Parent = hall
		local function cratePart(name: string, size: Vector3, offset: CFrame, color: Color3): Part
			local piece = part(name, size, stand * offset, color, M.WoodPlanks)
			piece.CanQuery = false
			piece.Parent = display
			return piece
		end
		cratePart("CrateBottom", Vector3.new(2.6, 0.18, 1.8), CFrame.new(0, 0.89, 0), DARK_WOOD)
		local crate = cratePart(kind .. "Crate", Vector3.new(2.6, 1.42, 0.16), CFrame.new(0, 1.69, -0.82), WOOD)
		crate.CanQuery = true
		cratePart("CrateBack", Vector3.new(2.6, 1.42, 0.16), CFrame.new(0, 1.69, 0.82), WOOD)
		for _, x in { -1.22, 1.22 } do
			cratePart("CrateSide", Vector3.new(0.16, 1.42, 1.48), CFrame.new(x, 1.69, 0), WOOD)
		end
		for _, x in { -1.05, 1.05 } do
			for _, z in { -0.93, 0.93 } do
				cratePart("CrateBrace", Vector3.new(0.16, 1.6, 0.1), CFrame.new(x, 1.6, z), DARK_WOOD)
			end
		end
		local lid = Instance.new("Model")
		lid.Name = kind .. "CrateLid"
		lid.Parent = display
		local board = cratePart("LidBoard", Vector3.new(2.7, 0.2, 1.9), CFrame.new(0, 2.5, 0), WOOD)
		board.CanCollide = false
		board.Parent = lid
		lid.PrimaryPart = board
		for _, x in { -1.05, 1.05 } do
			local brace = cratePart("LidBrace", Vector3.new(0.16, 0.08, 1.9), CFrame.new(x, 2.64, 0), DARK_WOOD)
			brace.CanCollide = false
			brace.Parent = lid
		end
		local sign = deco(
			kind .. "CrateSign",
			Vector3.new(3, 0.8, 0.12),
			stand * CFrame.new(0, 4.4, 0.6),
			DARK_WOOD,
			M.WoodPlanks
		)
		sign.CanQuery = false
		PlazaHouses.boardText(
			sign,
			if bobberCase then "BOBBERS\n$350" else "ROD CRATES\n$350 / $750",
			Enum.NormalId.Front
		)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Open" .. kind .. "CratePrompt"
		prompt.ActionText = if bobberCase then "Open case" else "Open crates"
		prompt.ObjectText = if bobberCase then "Bobbers · $350" else "Rod Crates"
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt.Parent = crate
	end

	-- Up on the gallery: potted palms, barrels and crates
	local function pottedPalm(x: number, z: number)
		local base = at(x, z, GALLERY)
		Props.cylinder(hall, base + Vector3.new(0, 1, 0), 2, 2.6, rgb(184, 96, 60), M.Sandstone)
		local top = base + Vector3.new(rng:NextNumber(-0.6, 0.6), 7, rng:NextNumber(-0.6, 0.6))
		Props.beam(hall, base + Vector3.new(0, 1.5, 0), top, 0.6, rgb(130, 100, 70), nil, M.Wood).CanCollide = false
		for f = 1, 7 do
			local a = f / 7 * TAU + rng:NextNumber(-0.2, 0.2)
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local mid = top + dir * 2.4 + Vector3.new(0, 0.8, 0)
			local tip = top + dir * 4.6 + Vector3.new(0, -1.2, 0)
			Props.beam(hall, top, mid, 1.3, Props.pick(rng, LEAF), 0.15, M.LeafyGrass).CanCollide = false
			Props.beam(hall, mid, tip, 1.1, Props.pick(rng, LEAF), 0.15, M.LeafyGrass).CanCollide = false
		end
	end
	for _, p in { { -18, D / 2 - 3 }, { 18, D / 2 - 3 }, { -W / 2 + 3, 0 }, { W / 2 - 3, 8 } } do
		pottedPalm(p[1], p[2])
	end
	for _, p in { { -8, D / 2 - 2.5 }, { -5.5, D / 2 - 2 }, { 24, D / 2 - 2.5 }, { -W / 2 + 2.5, 9 } } do
		Props.barrel(hall, at(p[1], p[2], GALLERY), rng)
	end
	Props.crates(hall, at(8, D / 2 - 3, GALLERY), rng)
	Props.crates(hall, at(-24, D / 2 - 3, GALLERY), rng)
	Props.crates(hall, at(W / 2 - 3, -2, GALLERY), rng)

	-- Hanging lanterns from the tie beams, and a lamp under each gallery post
	for _, z in { -16, -5.5, 5.5 } do
		for _, x in { -10, 10 } do
			local hook = Vector3.new(x, EAVES - 0.5, z)
			deco("LanternChain", Vector3.new(0.12, 5, 0.12), CFrame.new(hook - Vector3.new(0, 2.5, 0)), IRON, M.Metal)
			local lantern = Props.lantern(hall, o * CFrame.new(hook - Vector3.new(0, 6.6, 0)), 14, 0.6)
			for _, piece in lantern:GetChildren() do
				if piece:IsA("BasePart") then
					piece.CanCollide = false
				end
			end
		end
	end
	for _, p in { { -inner, -6 }, { inner, 4 }, { -inner, 4 }, { -11, backEdge }, { 11, backEdge } } do
		local lantern = Props.lantern(hall, o * CFrame.new(p[1], GALLERY - 3, p[2] - 0.9), 14, 0.6)
		for _, piece in lantern:GetChildren() do
			if piece:IsA("BasePart") then
				piece.CanCollide = false
			end
		end
	end

	-- The exit leads back through the green door; RodShop.build links it to the square
	exit.Name = "ExitDoor"
	CollectionService:AddTag(hall, "FishingRodShop")
	hall.Parent = interiorFolder()
	return hall
end

-- Finn stands centered behind the counter, facing the door below the upgrade sign.
-- FishingService dresses and places him at startup; the frame is at his soles.
local KEEPER_FRAME = INTERIOR_ORIGIN * CFrame.new(0, 0, D / 2 - 8 - 2.8)

-- Crab cages on a pallet left of the aisle, a spare on the floor in front and a
-- few loose floats. Built onto saved halls too, so it needs no interior rebuild.
-- FishingService sells one cage per BuyCrabCagePrompt at the price on the sign.
local function ensureCrabCageStand(hall: Model)
	if hall:FindFirstChild("CrabCageStand") then
		return
	end
	local stand = Instance.new("Model")
	stand.Name = "CrabCageStand"
	-- Local +Z faces the aisle; the cages' long sides run along the hall.
	local base = INTERIOR_ORIGIN * CFrame.new(-15, 0, 2) * CFrame.Angles(0, math.pi / 2, 0)
	local pallet = Props.part(stand, Vector3.new(6.8, 0.5, 3.4), base * CFrame.new(0, 0.25, 0), WOOD, M.WoodPlanks)
	pallet.Name = "Pallet"
	for _, x in { -2.9, 0, 2.9 } do
		Props.part(stand, Vector3.new(0.6, 0.12, 3.4), base * CFrame.new(x, 0.56, 0), DARK_WOOD, M.Wood).CanCollide =
			false
	end
	for _, x in { -1.65, 1.65 } do
		Props.crabCage(stand, base * CFrame.new(x, 0.62, 0))
	end
	Props.crabCage(stand, base * CFrame.new(-1.4, 0, 3.6) * CFrame.Angles(0, 0.45, 0))
	for index, offset in { CFrame.new(2.2, 0.45, 3), CFrame.new(3, 0.45, 3.6), CFrame.new(2.6, 1.3, 3.3) } do
		local floatPart = Props.part(
			stand,
			Vector3.new(1.1, 0.9, 0.9),
			base * offset * CFrame.Angles(0, index * 0.7, 0),
			rgb(240, 112, 38),
			M.SmoothPlastic
		)
		floatPart.Name = "SpareFloat"
		floatPart.Shape = Enum.PartType.Cylinder
		floatPart.CanCollide = false
	end
	for _, x in { -2.6, 2.6 } do
		Props.part(stand, Vector3.new(0.3, 5, 0.3), base * CFrame.new(x, 2.5, -1.9), DARK_WOOD, M.Wood)
	end
	local sign = Props.part(
		stand,
		Vector3.new(5.6, 1.5, 0.15),
		base * CFrame.new(0, 4.6, -1.85) * CFrame.Angles(0, math.pi, 0),
		DARK_WOOD,
		M.WoodPlanks
	)
	sign.Name = "CrabCageSign"
	sign.CanCollide, sign.CanQuery = false, false
	PlazaHouses.boardText(sign, "CRAB CAGES\n$35 · 3 HAULS", Enum.NormalId.Front)
	-- The prompt hangs over the pallet, where nothing blocks the shop's sightline check.
	local anchor = Props.part(stand, Vector3.new(1, 1, 1), base * CFrame.new(0, 3.4, 0.4), WOOD)
	anchor.Name = "CrabCagePromptAnchor"
	anchor.Transparency, anchor.CanCollide, anchor.CastShadow = 1, false, false
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyCrabCagePrompt"
	prompt.ActionText = "Buy · $35"
	prompt.ObjectText = "Crab Cage"
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0.35
	prompt.Parent = anchor
	stand.Parent = hall
end

local function ensureInterior(): Model
	local existing = interiorFolder():FindFirstChild("RodStoreInterior")
	local hall: Model
	if existing and existing:IsA("Model") and existing:GetAttribute("LayoutVersion") == INTERIOR_VERSION then
		hall = existing
	else
		if existing then
			existing:Destroy()
		end
		hall = buildInterior()
	end
	-- Refresh saved interiors too, without rebuilding the shop for a sign change.
	local cratePrompt = hall:FindFirstChild("OpenRodCratePrompt", true)
	if cratePrompt and cratePrompt:IsA("ProximityPrompt") then
		cratePrompt.ObjectText = "Rod Crates"
	end
	local crateSign = hall:FindFirstChild("RodCrateSign", true)
	if crateSign then
		for _, item in crateSign:GetDescendants() do
			if item:IsA("TextLabel") then
				item.Text = "ROD CRATES\n$350 / $750"
			end
		end
	end
	ensureCrabCageStand(hall)
	hall:SetAttribute("KeeperFrame", KEEPER_FRAME)
	CollectionService:AddTag(hall, "FishingRodShop")
	return hall
end

----------------------------------------------------------------------------------------------------
-- Storefront on the square

-- Front on local +Z; turned so the door faces the fountain, clear of the cafe tables to the south.
function RodShop.build(plaza: Model, plazaFrame: CFrame): Model
	local hall = ensureInterior()
	local existing = plaza:FindFirstChild("FishingRodShop")
	local shop: Model
	if existing and existing:IsA("Model") and existing:GetAttribute("LayoutVersion") == LAYOUT_VERSION then
		shop = existing
	else
		if existing then
			existing:Destroy()
		end
		local base = plazaFrame * CFrame.new(-45, 0, 35) * CFrame.Angles(0, math.pi / 2, 0)
		local rng = Random.new(4242)
		local doorFace, leaf
		shop, doorFace, leaf = PlazaHouses.house(plaza, base, {
			width = 22,
			depth = 18,
			stories = 2,
			lower = rgb(244, 232, 206),
			upper = rgb(86, 146, 200),
			trim = rgb(250, 242, 224),
			shutter = rgb(120, 80, 52),
			roof = rgb(170, 84, 52),
			door = rgb(176, 70, 52),
			balcony = true,
			shop = "TIDE & TACKLE",
			blade = "RODS",
			signColor = CREAM,
			-- The door takes the end nearer the bay, clear of the cafe tables
			doorSide = -1,
		}, rng)
		shop.Name = "FishingRodShop"
		shop:SetAttribute("LayoutVersion", LAYOUT_VERSION)
		-- A promenade palm this close would push its fronds through the walls
		for _, palm in plaza:GetChildren() do
			local trunk = palm:IsA("Model") and palm.Name == "Palm" and palm:FindFirstChildWhichIsA("BasePart")
			if trunk then
				local p = base:PointToObjectSpace(trunk.Position)
				local dx, dz = math.max(math.abs(p.X) - 11, 0), math.max(math.abs(p.Z) - 9, 0)
				if dx * dx + dz * dz < 100 then
					palm:Destroy()
				end
			end
		end
		leaf.Name = "StreetDoor"
		shop:SetAttribute("ExitFrame", doorFace * CFrame.new(0, 3.2, 4.5) * CFrame.Angles(0, math.pi, 0))
		-- A chalkboard on the step tells new anglers what is inside
		local board = doorFace * CFrame.new(-5, 0, 4)
		local panel
		for _, side in { -1, 1 } do
			-- The two leaves lean together at the top
			panel = Props.part(
				shop,
				Vector3.new(2.6, 3.6, 0.2),
				board * CFrame.new(0, 1.7, side * 0.55) * CFrame.Angles(-side * 0.3, 0, 0),
				rgb(60, 52, 44),
				M.Wood
			)
		end
		local slate = Props.part(
			shop,
			Vector3.new(2.2, 2.6, 0.06),
			panel.CFrame * CFrame.new(0, 0.2, 0.13),
			rgb(36, 44, 40),
			M.Slate
		)
		slate.CanCollide = false
		PlazaHouses.boardText(slate, "ROD\nUPGRADES\n& CRATES\ninside", Enum.NormalId.Back)
	end
	-- Link both doors every startup, so a rebuilt square and a saved hall always agree
	local leaf = shop:FindFirstChild("StreetDoor", true)
	local arrival = hall:GetAttribute("ArrivalFrame")
	local exitFrame = shop:GetAttribute("ExitFrame")
	if leaf and leaf:IsA("BasePart") and typeof(arrival) == "CFrame" then
		doorPrompt(leaf, "Enter", arrival)
	end
	local exit = hall:FindFirstChild("ExitDoor", true)
	if exit and exit:IsA("BasePart") and typeof(exitFrame) == "CFrame" then
		doorPrompt(exit, "Leave", exitFrame)
	end
	CollectionService:RemoveTag(shop, "FishingRodShop")
	return shop
end

function RodShop.ensure(root: Instance)
	for _, plaza in root:GetDescendants() do
		if plaza:IsA("Model") and plaza.Name == "Plaza" then
			local frame = PlazaHouses.pavingFrame(plaza)
			if frame then
				RodShop.build(plaza, frame)
			end
		end
	end
end

return RodShop

end
dependencies.RodShop = loadRodShop()
local function loadStorageRack()
	-- Galvanised shelving for a base's storage room. Local +Z is the open front; the
-- floor is y=0. Each stored fish shows as an iced crate on a shelf.
local Props = dependencies.Props

local StorageRack = {}
local rgb = Color3.fromRGB
local M = Enum.Material
local STEEL = rgb(118, 128, 132)
local DARK_STEEL = rgb(64, 72, 76)
local BOARD = rgb(150, 112, 74)
local CRATE = rgb(212, 226, 230)
local ICE = rgb(226, 244, 248)

StorageRack.WIDTH = 6
StorageRack.DEPTH = 2
StorageRack.HEIGHT = 6.6
local SHELVES = { 0.35, 2.4, 4.45 }
-- Crate spots: four along each shelf.
local CRATE_SPOTS = {}
for _, y in SHELVES do
	for index = 0, 3 do
		table.insert(CRATE_SPOTS, Vector3.new(-2.1 + index * 1.4, y, 0.05))
	end
end

function StorageRack.build(parent: Instance, frame: CFrame): Model
	local rack = Instance.new("Model")
	rack.Name = "StorageRack"
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material): Part
		local result = Props.part(rack, size, frame * offset, color, material)
		result.Name = name
		return result
	end
	local halfW, halfD = StorageRack.WIDTH / 2, StorageRack.DEPTH / 2
	for _, x in { -halfW + 0.12, halfW - 0.12 } do
		for _, z in { -halfD + 0.12, halfD - 0.12 } do
			piece("Upright", Vector3.new(0.22, StorageRack.HEIGHT, 0.22), CFrame.new(x, StorageRack.HEIGHT / 2, z), STEEL, M.Metal)
		end
		-- Diagonal bracing on each end frame.
		local brace = piece(
			"EndBrace",
			Vector3.new(0.1, math.sqrt(StorageRack.DEPTH ^ 2 + 4), 0.1),
			CFrame.new(x, 3.4, 0) * CFrame.Angles(math.atan2(StorageRack.DEPTH - 0.24, 2), 0, 0),
			DARK_STEEL,
			M.Metal
		)
		brace.CanCollide = false
	end
	for _, y in SHELVES do
		piece("Shelf", Vector3.new(StorageRack.WIDTH - 0.1, 0.14, StorageRack.DEPTH - 0.1), CFrame.new(0, y + 0.07, 0), BOARD, M.WoodPlanks)
		for _, z in { -halfD + 0.12, halfD - 0.12 } do
			piece("ShelfBeam", Vector3.new(StorageRack.WIDTH, 0.26, 0.12), CFrame.new(0, y, z), rgb(214, 104, 52), M.Metal)
		end
	end
	piece("TopShelfCap", Vector3.new(StorageRack.WIDTH, 0.12, StorageRack.DEPTH), CFrame.new(0, StorageRack.HEIGHT, 0), DARK_STEEL, M.Metal)
	return rack
end

-- Shows `count` crates on the rack, rebuilding only when the count changes.
function StorageRack.fill(rack: Model, frame: CFrame, count: number)
	count = math.clamp(count, 0, #CRATE_SPOTS)
	local existing = rack:FindFirstChild("Crates")
	if existing and existing:GetAttribute("Count") == count then
		return
	end
	if existing then
		existing:Destroy()
	end
	local crates = Instance.new("Model")
	crates.Name = "Crates"
	crates:SetAttribute("Count", count)
	for index = 1, count do
		local spot = CRATE_SPOTS[index]
		local base = frame * CFrame.new(spot.X, spot.Y + 0.14, spot.Z)
		local box = Props.part(crates, Vector3.new(1.2, 0.7, 1.5), base * CFrame.new(0, 0.35, 0), CRATE, M.SmoothPlastic)
		box.Name = "FishCrate"
		box.CanCollide = false
		local ice = Props.part(crates, Vector3.new(1, 0.12, 1.3), base * CFrame.new(0, 0.66, 0), ICE, M.Ice)
		ice.Name = "CrushedIce"
		ice.CanCollide = false
	end
	crates.Parent = rack
end

StorageRack.CRATES = #CRATE_SPOTS
return StorageRack

end
dependencies.StorageRack = loadStorageRack()
local function loadKitchen()
	-- Kitchen fixtures for the Supermarket path: the processing room's cooking stations,
-- the shop's food display case and the cooked dishes themselves. Local +Z is the
-- side the cook (or a customer at the case) stands on; the floor is y=0.
local Props = dependencies.Props

local Kitchen = {}
local rgb = Color3.fromRGB
local M = Enum.Material
local STEEL = rgb(186, 192, 196)
local DARK_STEEL = rgb(62, 68, 72)
local CABINET = rgb(222, 226, 226)
local BLACK = rgb(32, 32, 34)
local WOOD = rgb(148, 108, 70)
local LIGHT_WOOD = rgb(206, 170, 118)
local PLATE = rgb(244, 244, 238)

Kitchen.WIDTH = 6
Kitchen.DEPTH = 2.4
Kitchen.TOP = 3.1
Kitchen.CASE_WIDTH = 6
Kitchen.CASE_DEPTH = 2.6
Kitchen.CASE_SHELF = 2.5
-- Where a cooking fish or finished dish sits, in station-local studs.
Kitchen.WORK_SPOT = CFrame.new(0.6, Kitchen.TOP + 0.02, 0.15)
-- Six dish spots under the glass of a food display case: three across, two deep.
Kitchen.CASE_SPOTS = {}
for _, z in { -0.5, 0.55 } do
	for _, x in { -1.9, 0, 1.9 } do
		table.insert(Kitchen.CASE_SPOTS, CFrame.new(x, Kitchen.CASE_SHELF + 0.14, z))
	end
end
-- Eight fish spots on the ice bed of a kitchen fish storage counter: four across, two deep.
Kitchen.STORAGE_SPOTS = {}
for _, z in { -0.5, 0.45 } do
	for _, x in { -2.1, -0.7, 0.7, 2.1 } do
		table.insert(Kitchen.STORAGE_SPOTS, CFrame.new(x, Kitchen.TOP + 0.05, z))
	end
end

local function builder(parent: Instance, name: string, frame: CFrame)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	local function piece(
		label: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material?,
		solid: boolean?
	): Part
		local result = Props.part(model, size, frame * offset, color, material)
		result.Name = label
		if not solid then
			result.CanCollide = false
			result.CanQuery = false
		end
		return result
	end
	return model, piece
end

-- The cabinet and worktop every station shares.
local function counter(piece, top: Color3, topMaterial: Enum.Material, body: Color3)
	piece("Cabinet", Vector3.new(Kitchen.WIDTH, Kitchen.TOP - 0.2, Kitchen.DEPTH), CFrame.new(0, (Kitchen.TOP - 0.2) / 2, 0), body, M.SmoothPlastic, true)
	piece("Worktop", Vector3.new(Kitchen.WIDTH + 0.1, 0.2, Kitchen.DEPTH + 0.1), CFrame.new(0, Kitchen.TOP - 0.1, 0), top, topMaterial, true)
	piece("Kickboard", Vector3.new(Kitchen.WIDTH - 0.2, 0.3, 0.05), CFrame.new(0, 0.15, Kitchen.DEPTH / 2 + 0.01), DARK_STEEL, M.Metal)
	for index = -1, 1 do
		piece("CabinetDoor", Vector3.new(1.8, 2.1, 0.06), CFrame.new(index * 1.95, 1.55, Kitchen.DEPTH / 2 + 0.03), body:Lerp(Color3.new(1, 1, 1), 0.15), M.SmoothPlastic)
		piece("DoorHandle", Vector3.new(0.9, 0.08, 0.08), CFrame.new(index * 1.95, 2.4, Kitchen.DEPTH / 2 + 0.1), DARK_STEEL, M.Metal)
	end
end

function Kitchen.buildStation(parent: Instance, frame: CFrame, station: string): Model
	local model, piece = builder(parent, station, frame)
	if station == "Prep" then
		counter(piece, STEEL, M.Metal, CABINET)
		piece("CuttingBoard", Vector3.new(2, 0.1, 1.3), CFrame.new(0.6, Kitchen.TOP + 0.05, 0.1), LIGHT_WOOD, M.Wood)
		piece("Sink", Vector3.new(1.5, 0.08, 1.4), CFrame.new(-1.9, Kitchen.TOP + 0.01, 0), DARK_STEEL, M.Metal)
		piece("Tap", Vector3.new(0.12, 0.9, 0.12), CFrame.new(-1.9, Kitchen.TOP + 0.45, -0.85), STEEL, M.Metal)
		piece("Spout", Vector3.new(0.12, 0.12, 0.6), CFrame.new(-1.9, Kitchen.TOP + 0.85, -0.6), STEEL, M.Metal)
		piece("KnifeBlock", Vector3.new(0.4, 0.6, 0.5), CFrame.new(2.4, Kitchen.TOP + 0.3, -0.7), WOOD, M.Wood)
	elseif station == "GrillStation" then
		counter(piece, DARK_STEEL, M.Metal, rgb(170, 60, 44))
		piece("GrillBed", Vector3.new(3, 0.12, 1.7), CFrame.new(0.6, Kitchen.TOP + 0.02, 0), BLACK, M.Metal)
		local coals = piece("Coals", Vector3.new(2.8, 0.06, 1.5), CFrame.new(0.6, Kitchen.TOP + 0.06, 0), rgb(255, 120, 40), M.Neon)
		coals.Transparency = 0.25
		for bar = -3, 3 do
			piece("GrillBar", Vector3.new(0.06, 0.06, 1.7), CFrame.new(0.6 + bar * 0.42, Kitchen.TOP + 0.12, 0), DARK_STEEL, M.Metal)
		end
		piece("HoodPost", Vector3.new(0.15, 3, 0.15), CFrame.new(-2.8, Kitchen.TOP + 1.5, -1.05), DARK_STEEL, M.Metal)
		piece("Hood", Vector3.new(4.2, 0.4, 1.8), CFrame.new(0.6, Kitchen.TOP + 3, -0.3), STEEL, M.Metal)
		local glow = Instance.new("PointLight")
		glow.Color, glow.Brightness, glow.Range = rgb(255, 140, 60), 0.8, 8
		glow.Parent = coals
	elseif station == "Smoker" then
		counter(piece, WOOD, M.WoodPlanks, rgb(92, 70, 52))
		piece("SmokeBox", Vector3.new(2.4, 2.2, 1.8), CFrame.new(-1.6, Kitchen.TOP + 1.1, -0.1), rgb(56, 44, 36), M.WoodPlanks, true)
		piece("SmokeDoor", Vector3.new(2, 1.8, 0.08), CFrame.new(-1.6, Kitchen.TOP + 1.1, 0.84), rgb(76, 60, 46), M.Wood)
		piece("Chimney", Vector3.new(0.5, 2.2, 0.5), CFrame.new(-2.2, Kitchen.TOP + 3.3, -0.4), DARK_STEEL, M.Metal)
		local vent = piece("Vent", Vector3.new(0.4, 0.1, 0.4), CFrame.new(-2.2, Kitchen.TOP + 4.42, -0.4), BLACK, M.Metal)
		local smoke = Instance.new("ParticleEmitter")
		smoke.Name = "Smoke"
		smoke.Color = ColorSequence.new(rgb(180, 176, 168))
		smoke.Transparency = NumberSequence.new(0.5, 1)
		smoke.Size = NumberSequence.new(0.6, 2.4)
		smoke.Lifetime = NumberRange.new(2, 3.5)
		smoke.Rate = 4
		smoke.Speed = NumberRange.new(1.5, 2.5)
		smoke.SpreadAngle = Vector2.new(12, 12)
		smoke.Parent = vent
		piece("HangingRail", Vector3.new(2.6, 0.08, 0.08), CFrame.new(1.4, Kitchen.TOP + 1.6, -1), DARK_STEEL, M.Metal)
	elseif station == "SushiBar" then
		counter(piece, LIGHT_WOOD, M.Wood, rgb(70, 54, 44))
		piece("BambooMat", Vector3.new(1.6, 0.05, 1.2), CFrame.new(0.6, Kitchen.TOP + 0.03, 0.1), rgb(196, 182, 120), M.Fabric)
		local bowl = Props.cylinder(model, (frame * CFrame.new(-1.6, Kitchen.TOP + 0.25, -0.3)).Position, 0.5, 1, rgb(160, 40, 36), M.SmoothPlastic)
		bowl.Name = "RiceBowl"
		bowl.CanCollide = false
		local rice = Props.cylinder(model, (frame * CFrame.new(-1.6, Kitchen.TOP + 0.52, -0.3)).Position, 0.06, 0.85, PLATE, M.SmoothPlastic)
		rice.Name = "Rice"
		rice.CanCollide = false
		piece("Noren", Vector3.new(4.5, 1, 0.05), CFrame.new(0, Kitchen.TOP + 2.6, -1.1), rgb(34, 52, 92), M.Fabric)
		piece("NorenRod", Vector3.new(4.8, 0.1, 0.1), CFrame.new(0, Kitchen.TOP + 3.15, -1.1), LIGHT_WOOD, M.Wood)
		for _, x in { -2.3, 2.3 } do
			piece("NorenPost", Vector3.new(0.15, 3.2, 0.15), CFrame.new(x, Kitchen.TOP + 1.6, -1.1), LIGHT_WOOD, M.Wood)
		end
	elseif station == "KitchenStorage" then
		return Kitchen.buildStorage(parent, frame)
	else
		error("Unknown kitchen station " .. tostring(station))
	end
	return model
end

-- A chilled prep table holding up to 8 fish for cooking.
function Kitchen.buildStorage(parent: Instance, frame: CFrame): Model
	local model, piece = builder(parent, "KitchenStorage", frame)
	counter(piece, STEEL, M.Metal, rgb(52, 60, 66))

	local ice = piece("IceBed", Vector3.new(5.6, 0.06, 2.1), CFrame.new(0, Kitchen.TOP + 0.02, 0), rgb(218, 238, 245), M.Ice, true)
	ice.Transparency = 0.15

	piece("IceTrimFront", Vector3.new(5.8, 0.08, 0.1), CFrame.new(0, Kitchen.TOP + 0.04, 1.1), STEEL, M.Metal)
	piece("IceTrimBack", Vector3.new(5.8, 0.08, 0.1), CFrame.new(0, Kitchen.TOP + 0.04, -1.1), STEEL, M.Metal)
	piece("IceTrimLeft", Vector3.new(0.1, 0.08, 2.2), CFrame.new(-2.85, Kitchen.TOP + 0.04, 0), STEEL, M.Metal)
	piece("IceTrimRight", Vector3.new(0.1, 0.08, 2.2), CFrame.new(2.85, Kitchen.TOP + 0.04, 0), STEEL, M.Metal)

	piece("Backsplash", Vector3.new(5.9, 0.8, 0.08), CFrame.new(0, Kitchen.TOP + 0.4, -Kitchen.DEPTH / 2 + 0.05), STEEL, M.Metal, true)
	piece("TicketRail", Vector3.new(5.4, 0.1, 0.05), CFrame.new(0, Kitchen.TOP + 0.75, -Kitchen.DEPTH / 2 + 0.1), DARK_STEEL, M.Metal)
	for index = -2, 2 do
		piece("Ticket" .. (index + 3), Vector3.new(0.45, 0.5, 0.02), CFrame.new(index * 1.1, Kitchen.TOP + 0.55, -Kitchen.DEPTH / 2 + 0.12), rgb(245, 245, 230), M.SmoothPlastic)
	end

	for _, x in { -1.4, 0, 1.4 } do
		piece("DividerX" .. x, Vector3.new(0.04, 0.02, 2.0), CFrame.new(x, Kitchen.TOP + 0.05, 0), DARK_STEEL, M.Metal)
	end
	piece("DividerZ", Vector3.new(5.4, 0.02, 0.04), CFrame.new(0, Kitchen.TOP + 0.05, -0.025), DARK_STEEL, M.Metal)

	local mist = Instance.new("ParticleEmitter")
	mist.Name = "ChillMist"
	mist.Color = ColorSequence.new(rgb(225, 242, 255))
	mist.Transparency = NumberSequence.new(0.65, 1)
	mist.Size = NumberSequence.new(0.3, 0.8)
	mist.Lifetime = NumberRange.new(1.2, 2)
	mist.Rate = 4
	mist.Speed = NumberRange.new(0.2, 0.6)
	mist.SpreadAngle = Vector2.new(180, 0)
	mist.Parent = ice

	return model
end

-- A glass-topped chilled case. Dishes are added by the shop's display.
function Kitchen.buildCase(parent: Instance, frame: CFrame): Model
	local model, piece = builder(parent, "FoodCase", frame)
	local w, d = Kitchen.CASE_WIDTH, Kitchen.CASE_DEPTH
	piece("CaseBase", Vector3.new(w, Kitchen.CASE_SHELF - 0.1, d), CFrame.new(0, (Kitchen.CASE_SHELF - 0.1) / 2, 0), rgb(46, 92, 110), M.SmoothPlastic, true)
	piece("CaseTrim", Vector3.new(w + 0.1, 0.12, d + 0.1), CFrame.new(0, Kitchen.CASE_SHELF - 0.04, 0), STEEL, M.Metal, true)
	piece("Shelf", Vector3.new(w - 0.2, 0.08, d - 0.2), CFrame.new(0, Kitchen.CASE_SHELF + 0.06, 0), rgb(236, 242, 244), M.SmoothPlastic)
	for _, x in { -w / 2 + 0.05, w / 2 - 0.05 } do
		local side = piece("SideGlass", Vector3.new(0.06, 1.2, d - 0.1), CFrame.new(x, Kitchen.CASE_SHELF + 0.65, 0), rgb(200, 230, 236), M.SmoothPlastic, true)
		side.Transparency = 0.7
	end
	local front = piece("FrontGlass", Vector3.new(w - 0.1, 1.25, 0.06), CFrame.new(0, Kitchen.CASE_SHELF + 0.6, d / 2 - 0.2) * CFrame.Angles(math.rad(-14), 0, 0), rgb(200, 230, 236), M.SmoothPlastic, true)
	front.Transparency = 0.72
	local top = piece("TopGlass", Vector3.new(w - 0.1, 0.06, d - 0.5), CFrame.new(0, Kitchen.CASE_SHELF + 1.24, -0.2), rgb(200, 230, 236), M.SmoothPlastic, true)
	top.Transparency = 0.72
	piece("PriceRail", Vector3.new(w, 0.25, 0.06), CFrame.new(0, Kitchen.CASE_SHELF - 0.25, d / 2 + 0.03), rgb(240, 196, 80), M.SmoothPlastic)
	local light = Instance.new("SurfaceLight")
	light.Face, light.Brightness, light.Range, light.Angle = Enum.NormalId.Bottom, 0.6, 3, 120
	light.Color = rgb(255, 246, 228)
	light.Parent = top
	return model
end

-- One cooked dish, resting with its base on `frame`'s origin. Purely decorative.
function Kitchen.buildDish(recipeId: string, look: string, frame: CFrame): Model
	local model, piece = builder(nil :: any, "Dish", frame)
	model:SetAttribute("RecipeId", recipeId)
	local function round(label: string, y: number, height: number, diameter: number, color: Color3, material: Enum.Material?, x: number?, z: number?): Part
		local part = Props.cylinder(model, (frame * CFrame.new(x or 0, y, z or 0)).Position, height, diameter, color, material)
		part.Name = label
		part.CanCollide, part.CanQuery = false, false
		return part
	end
	if look == "Sushi" or look == "Sashimi" then
		piece("ServingBoard", Vector3.new(1.5, 0.12, 0.8), CFrame.new(0, 0.06, 0), WOOD, M.Wood)
	else
		round("Plate", 0.04, 0.08, 1.35, PLATE, M.SmoothPlastic)
		round("PlateRim", 0.09, 0.03, 1.1, rgb(226, 226, 220), M.SmoothPlastic)
	end
	if look == "Fillet" then
		piece("Fillet", Vector3.new(0.85, 0.14, 0.42), CFrame.new(-0.05, 0.18, 0) * CFrame.Angles(0, 0.3, 0), rgb(240, 160, 130), M.SmoothPlastic)
		local lemon = piece("Lemon", Vector3.new(0.26, 0.26, 0.26), CFrame.new(0.4, 0.22, 0.25), rgb(246, 220, 70), M.SmoothPlastic)
		lemon.Shape = Enum.PartType.Ball
		piece("Herb", Vector3.new(0.3, 0.04, 0.15), CFrame.new(-0.35, 0.13, -0.3), rgb(70, 140, 60), M.Grass)
	elseif look == "Chips" then
		piece("BatteredFish", Vector3.new(0.75, 0.2, 0.36), CFrame.new(-0.18, 0.21, 0) * CFrame.Angles(0, -0.25, 0), rgb(214, 156, 66), M.Sand)
		for index = 1, 6 do
			piece("Chip", Vector3.new(0.45, 0.08, 0.08), CFrame.new(0.32, 0.15 + (index % 2) * 0.07, -0.3 + index * 0.1) * CFrame.Angles(0, index * 0.5, 0), rgb(240, 206, 110), M.SmoothPlastic)
		end
	elseif look == "Grilled" then
		piece("GrilledFish", Vector3.new(1, 0.22, 0.34), CFrame.new(0, 0.2, 0), rgb(158, 120, 84), M.SmoothPlastic)
		piece("Tail", Vector3.new(0.2, 0.18, 0.3), CFrame.new(-0.56, 0.2, 0) * CFrame.Angles(0, math.rad(45), 0), rgb(130, 96, 66), M.SmoothPlastic)
		for index = -1, 1 do
			piece("GrillMark", Vector3.new(0.05, 0.02, 0.32), CFrame.new(index * 0.22, 0.32, 0), BLACK, M.SmoothPlastic)
		end
	elseif look == "Skewers" then
		for _, z in { -0.18, 0.18 } do
			piece("Skewer", Vector3.new(1.2, 0.04, 0.04), CFrame.new(0, 0.2, z), LIGHT_WOOD, M.Wood)
			for index = -1, 1 do
				piece("Chunk", Vector3.new(0.2, 0.2, 0.2), CFrame.new(index * 0.3, 0.2, z), if index == 0 then rgb(226, 84, 56) else rgb(222, 170, 112), M.SmoothPlastic)
			end
		end
	elseif look == "Smoked" then
		for index = 0, 2 do
			piece("SmokedSlice", Vector3.new(0.7, 0.08, 0.3), CFrame.new(0, 0.14 + index * 0.05, -0.2 + index * 0.2) * CFrame.Angles(0, index * 0.25, 0), rgb(176, 92, 40), M.SmoothPlastic)
		end
	elseif look == "Sushi" then
		for index = 0, 5 do
			local x = -0.55 + (index % 3) * 0.55
			local z = if index < 3 then -0.18 else 0.18
			round("Nori", 0.24, 0.24, 0.3, rgb(30, 40, 30), M.SmoothPlastic, x, z)
			round("Rice", 0.37, 0.02, 0.24, PLATE, M.SmoothPlastic, x, z)
			round("Salmon", 0.385, 0.01, 0.1, rgb(240, 120, 80), M.SmoothPlastic, x, z)
		end
	elseif look == "Sashimi" then
		for index = 0, 3 do
			piece("GoldenSlice", Vector3.new(0.3, 0.1, 0.5), CFrame.new(-0.45 + index * 0.3, 0.18, 0) * CFrame.Angles(0, 0, math.rad(-20)), rgb(244, 190, 70), M.Foil)
		end
		piece("Shiso", Vector3.new(0.35, 0.03, 0.4), CFrame.new(0.55, 0.13, 0), rgb(60, 150, 70), M.Grass)
	end
	return model
end

return Kitchen

end
dependencies.Kitchen = loadKitchen()
local function loadDiningRoom()
	-- The Restaurant path's dining room: an extension built onto the back of a base
-- house, behind the processing room, plus the dining tables placed inside it.
-- Positions are house-local studs (BaseHouse "HouseFrame"; floor y=0.16, rear wall z=-15).
local Props = dependencies.Props

local DiningRoom = {}
local rgb = Color3.fromRGB
local M = Enum.Material
local PLASTER = rgb(236, 226, 204)
local STONE = rgb(168, 156, 130)
local WOOD = rgb(124, 88, 55)
local DARK_WOOD = rgb(67, 48, 35)
local IRON = rgb(43, 53, 57)
local CREAM = rgb(247, 235, 204)
local TERRACOTTA = rgb(164, 75, 46)
local LINEN = rgb(244, 240, 228)

local LEFT, RIGHT = -23, -5.5
local BACK, FRONT = -30, -15.33
local HEIGHT = 9
DiningRoom.VERSION = 1
-- Diners arrive along the quay and walk in through this doorway (house-local).
DiningRoom.DOOR = Vector3.new(-13, 0.16, -30)
DiningRoom.ARRIVAL = Vector3.new(-13, 0.16, -32.4)
DiningRoom.INSIDE = Vector3.new(-13, 0.16, -27.4)
local DOOR_WIDTH = 5

function DiningRoom.build(parent: Instance, frame: CFrame): Model
	local room = Instance.new("Model")
	room.Name = "Dining"
	room:SetAttribute("RoomType", "Dining")
	room:SetAttribute("LayoutVersion", DiningRoom.VERSION)
	local function block(name: string, size: Vector3, x: number, y: number, z: number, color: Color3, material: Enum.Material?, decorative: boolean?): Part
		local piece = Props.part(room, size, frame * CFrame.new(x, y, z), color, material)
		piece.Name = name
		if decorative then
			piece.CanCollide, piece.CanQuery = false, false
		end
		return piece
	end
	local width, depth = RIGHT - LEFT, FRONT - BACK
	local cx, cz = (LEFT + RIGHT) / 2, (BACK + FRONT) / 2
	block("DiningFloor", Vector3.new(width, 0.16, depth), cx, 0.08, cz, rgb(150, 104, 66), M.WoodPlanks)
	block("Plinth", Vector3.new(width + 0.4, 0.5, 0.8), cx, 0.25, BACK - 0.2, STONE, M.Slate)

	-- A side wall along z with a window opening between zA and zB.
	local function sideWall(x: number, name: string)
		local zA, zB = -25.5, -19
		block(name, Vector3.new(0.6, HEIGHT, zA - BACK), x, HEIGHT / 2, (BACK + zA) / 2, PLASTER, M.Plaster)
		block(name, Vector3.new(0.6, HEIGHT, FRONT - zB), x, HEIGHT / 2, (zB + FRONT) / 2, PLASTER, M.Plaster)
		block(name .. "Sill", Vector3.new(0.6, 3, zB - zA), x, 1.5, (zA + zB) / 2, PLASTER, M.Plaster)
		block(name .. "Lintel", Vector3.new(0.6, 2, zB - zA), x, HEIGHT - 1, (zA + zB) / 2, PLASTER, M.Plaster)
		local glass = block(name .. "Glass", Vector3.new(0.12, 4, zB - zA), x, 5, (zA + zB) / 2, rgb(105, 165, 175), M.SmoothPlastic, true)
		glass.Transparency = 0.68
		for _, y in { 3, 5, 7 } do
			block(name .. "Rail", Vector3.new(0.3, 0.16, zB - zA), x, y, (zA + zB) / 2, CREAM, M.Wood, true)
		end
		block(name .. "Mullion", Vector3.new(0.3, 4, 0.16), x, 5, (zA + zB) / 2, CREAM, M.Wood, true)
	end
	sideWall(LEFT, "DiningWestWall")
	sideWall(RIGHT, "DiningEastWall")
	-- Water-side wall with the guests' doorway.
	local doorLeft, doorRight = DiningRoom.DOOR.X - DOOR_WIDTH / 2, DiningRoom.DOOR.X + DOOR_WIDTH / 2
	block("DiningBackWall", Vector3.new(doorLeft - LEFT + 0.3, HEIGHT, 0.6), (LEFT - 0.3 + doorLeft) / 2, HEIGHT / 2, BACK + 0.3, PLASTER, M.Plaster)
	block("DiningBackWall", Vector3.new(RIGHT + 0.3 - doorRight, HEIGHT, 0.6), (doorRight + RIGHT + 0.3) / 2, HEIGHT / 2, BACK + 0.3, PLASTER, M.Plaster)
	block("DoorLintel", Vector3.new(DOOR_WIDTH, HEIGHT - 7.6, 0.6), DiningRoom.DOOR.X, (HEIGHT + 7.6) / 2, BACK + 0.3, PLASTER, M.Plaster)
	for _, side in { -1, 1 } do
		block("DoorJamb", Vector3.new(0.28, 7.6, 0.8), DiningRoom.DOOR.X + side * (DOOR_WIDTH / 2 + 0.14), 3.8, BACK + 0.3, WOOD, M.Wood)
	end
	block("DoorStep", Vector3.new(DOOR_WIDTH + 1, 0.2, 1.6), DiningRoom.DOOR.X, 0.06, BACK - 0.6, STONE, M.Slate)

	-- Flat roof hidden in build mode (above the lintels), with a terracotta edge.
	block("DiningRoof", Vector3.new(width + 1.2, 0.5, depth + 0.8), cx, HEIGHT + 0.25, cz - 0.2, rgb(118, 106, 92), M.Concrete)
	for _, z in { BACK - 0.5, FRONT + 0.1 } do
		block("RoofTrim", Vector3.new(width + 1.4, 0.4, 0.4), cx, HEIGHT + 0.65, z, TERRACOTTA, M.Brick, true)
	end
	for _, x in { LEFT - 0.5, RIGHT + 0.5 } do
		block("RoofTrim", Vector3.new(0.4, 0.4, depth + 1), x, HEIGHT + 0.65, cz - 0.2, TERRACOTTA, M.Brick, true)
	end

	-- Name board over the door, facing the quay.
	local board = block("RestaurantSign", Vector3.new(7, 1.1, 0.16), DiningRoom.DOOR.X, 8.2, BACK - 0.1, IRON, M.WoodPlanks, true)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(420, 66)
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -20, 1, -8)
	label.Position = UDim2.fromOffset(10, 4)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Garamond
	label.TextScaled = true
	label.TextColor3 = CREAM
	label.Text = "RESTAURANT"
	label.Parent = gui

	-- Warm pendant lamps over the tables.
	for index, position in { Vector3.new(-17.5, 0, -22), Vector3.new(-10.5, 0, -22) } do
		local shade = block("DiningLamp" .. index, Vector3.new(1.6, 0.35, 1.6), position.X, 8.1, position.Z, DARK_WOOD, M.Wood, true)
		block("DiningLampCord" .. index, Vector3.new(0.08, 0.8, 0.08), position.X, 8.7, position.Z, IRON, M.Metal, true)
		local glow = Instance.new("PointLight")
		glow.Color, glow.Brightness, glow.Range, glow.Shadows = rgb(255, 226, 180), 0.55, 18, true
		glow.Parent = shade
	end
	-- A long kitchen pass shelf under the processing room's rear window.
	block("PassShelf", Vector3.new(7.6, 0.2, 1), -13, 3.9, FRONT - 0.5, WOOD, M.WoodPlanks)
	room.Parent = parent
	return room
end

DiningRoom.TABLE_TOP = 2.6
DiningRoom.SEAT_OFFSET = 2.15
-- Each table seats two diners, one on each long side (local ±Z).
function DiningRoom.buildTable(parent: Instance, frame: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "DiningTable"
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
		local result = Props.part(model, size, frame * offset, color, material)
		result.Name = name
		return result
	end
	piece("TableTop", Vector3.new(4, 0.18, 2.6), CFrame.new(0, DiningRoom.TABLE_TOP - 0.09, 0), WOOD, M.Wood)
	local cloth = piece("TableCloth", Vector3.new(4.1, 0.04, 1.2), CFrame.new(0, DiningRoom.TABLE_TOP + 0.01, 0), LINEN, M.Fabric)
	cloth.CanCollide = false
	for _, x in { -1.75, 1.75 } do
		for _, z in { -1.05, 1.05 } do
			piece("TableLeg", Vector3.new(0.22, DiningRoom.TABLE_TOP - 0.18, 0.22), CFrame.new(x, (DiningRoom.TABLE_TOP - 0.18) / 2, z), DARK_WOOD, M.Wood)
		end
	end
	local candle = Props.cylinder(model, (frame * CFrame.new(0, DiningRoom.TABLE_TOP + 0.25, 0)).Position, 0.45, 0.16, CREAM, M.SmoothPlastic)
	candle.Name, candle.CanCollide = "Candle", false
	for index, side in { 1, -1 } do
		local z = side * DiningRoom.SEAT_OFFSET
		local seat = Instance.new("Seat")
		seat.Name = "DinerSeat" .. index
		seat.Size = Vector3.new(1.5, 0.3, 1.5)
		seat.Anchored = true
		seat.TopSurface, seat.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		seat.Color, seat.Material = WOOD, M.Wood
		-- Faces the table.
		seat.CFrame = frame * CFrame.new(0, 1.55, z) * CFrame.Angles(0, if side > 0 then 0 else math.pi, 0)
		seat:SetAttribute("PlateOffset", Vector3.new(0, DiningRoom.TABLE_TOP + 0.02, side * 0.6))
		seat.Parent = model
		piece("ChairBack", Vector3.new(1.5, 1.8, 0.18), CFrame.new(0, 2.5, z + side * 0.7), DARK_WOOD, M.Wood)
		for _, x in { -0.6, 0.6 } do
			for _, dz in { -0.6, 0.6 } do
				piece("ChairLeg", Vector3.new(0.16, 1.4, 0.16), CFrame.new(x, 0.7, z + dz), DARK_WOOD, M.Wood)
			end
		end
	end
	return model
end

return DiningRoom

end
dependencies.DiningRoom = loadDiningRoom()
local function loadFurnitureShop()
	-- Harbour Home's plaza door leads to a furnished showroom away from the map.
-- Every catalogue item stands full-size on a plinth facing its aisle, and the
-- indoor service desk sells the whole list. Versioned builders upgrade saved
-- storefronts and restore door links and shop tags.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Furniture = dependencies.FurnitureCatalog
local DiningRoom = dependencies.DiningRoom
local FishFreezer = dependencies.FishFreezer
local Kitchen = dependencies.Kitchen
local PlazaHouses = dependencies.PlazaHouses
local Props = dependencies.Props
local ShopDesk = dependencies.ShopDesk
local StorageRack = dependencies.StorageRack

local FurnitureShop = {}
local LAYOUT_VERSION = 2
local INTERIOR_VERSION = 2
local ORIGIN = CFrame.new(6700, 300, 160)
local W, D, H = 48, 40, 18
local rgb = Color3.fromRGB
local M = Enum.Material
local CREAM = rgb(255, 245, 213)
local TEAL = rgb(64, 140, 120)
local WOOD = rgb(150, 104, 64)
local GOLD = rgb(200, 152, 74)
local RUG = rgb(122, 66, 48)
local LINEN = rgb(236, 226, 204)
local LEAF = rgb(64, 118, 66)
local POT = rgb(164, 96, 62)
local SHADE = rgb(102, 70, 44)

local function interiors(): Instance
	local folder = workspace:FindFirstChild("Interiors")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name, folder.Parent = "Interiors", workspace
	end
	return folder
end

local function doorPrompt(door: BasePart, action: string, destination: CFrame)
	local prompt = door:FindFirstChild("FurnitureStoreDoorPrompt") :: ProximityPrompt?
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "FurnitureStoreDoorPrompt"
		prompt.ObjectText = "Harbour Home"
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt.Parent = door
	end
	local p = prompt :: ProximityPrompt
	p.ActionText = action
	p:SetAttribute("TeleportTo", destination)
end

local function restoreTags(hall: Model)
	CollectionService:AddTag(hall, "FurnitureShowroom")
	local top = hall:FindFirstChild("CounterTop")
	if top then CollectionService:AddTag(top, "FurnitureShop") end
end

-- The same builders that furnish a player's house, so displays match the goods.
local function buildSample(id: string, parent: Instance, frame: CFrame): Model
	if id == "Freezer" then
		return FishFreezer.build(parent, frame)
	elseif id == "Register" then
		return ShopDesk.build(parent, frame)
	elseif id == "StorageRack" then
		local sample = StorageRack.build(parent, frame)
		StorageRack.fill(sample, frame, StorageRack.CRATES)
		return sample
	elseif id == "FoodCase" then
		return Kitchen.buildCase(parent, frame)
	elseif id == "KitchenStorage" then
		return Kitchen.buildStorage(parent, frame)
	elseif id == "DiningTable" then
		return DiningRoom.buildTable(parent, frame)
	end
	return Kitchen.buildStation(parent, frame, id)
end

-- Where each item stands in the showroom. `side` names the wall it lines:
-- left/right displays face the side aisles, back displays face the cross aisle
-- by the entrance. `turn` swings the item's customer side toward that aisle.
local DISPLAYS = {
	-- Left wall: the cooking line.
	{ id = "GrillStation", side = "left", x = -18, z = 0, turn = math.pi / 2, plinth = Vector3.new(8, 0.3, 6.5) },
	{ id = "Smoker", side = "left", x = -18, z = 7, turn = math.pi / 2, plinth = Vector3.new(8, 0.3, 6.5) },
	{ id = "SushiBar", side = "left", x = -18, z = 14, turn = math.pi / 2, plinth = Vector3.new(8, 0.3, 6.5) },
	-- Right wall: the shop floor and storage.
	{ id = "Freezer", side = "right", x = 18, z = 0, turn = -math.pi / 2, plinth = Vector3.new(8, 0.3, 9) },
	{ id = "FoodCase", side = "right", x = 18, z = 8, turn = -math.pi / 2, plinth = Vector3.new(8, 0.3, 6.5) },
	{ id = "StorageRack", side = "right", x = 18, z = 15, turn = -math.pi / 2, plinth = Vector3.new(8, 0.3, 6.5) },
	-- Back wall: the sales row under the welcome sign.
	{ id = "KitchenStorage", side = "back", x = -10, z = 15, turn = math.pi, plinth = Vector3.new(7, 0.3, 7) },
	{ id = "Register", side = "back", x = 0, z = 15, turn = 0, plinth = Vector3.new(8.5, 0.3, 7) },
	{ id = "DiningTable", side = "back", x = 10, z = 15, turn = math.pi, plinth = Vector3.new(7, 0.3, 7) },
}

local function ensureInterior(): Model
	local folder = interiors()
	local existing = folder:FindFirstChild("FurnitureStoreInterior")
	if existing and existing:IsA("Model") and existing:GetAttribute("LayoutVersion") == INTERIOR_VERSION then
		restoreTags(existing)
		return existing
	elseif existing then
		existing:Destroy()
	end
	local hall = Instance.new("Model")
	hall.Name = "FurnitureStoreInterior"
	hall.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	hall:SetAttribute("LayoutVersion", INTERIOR_VERSION)
	hall:SetAttribute("InteriorFrame", ORIGIN * CFrame.new(0, H / 2, 0))
	hall:SetAttribute("InteriorSize", Vector3.new(W, H, D))
	hall:SetAttribute("ArrivalFrame", ORIGIN * CFrame.new(0, 3.2, -D / 2 + 5) * CFrame.Angles(0, math.pi, 0))
	local function part(name: string, size: Vector3, frame: CFrame, color: Color3, material: Enum.Material): Part
		local p = Props.part(hall, size, ORIGIN * frame, color, material)
		p.Name = name
		return p
	end
	local function sign(name: string, size: Vector3, frame: CFrame, text: string, color: Color3): Part
		local p = part(name, size, frame, color, M.Wood)
		p.CanCollide = false
		PlazaHouses.boardText(p, text, Enum.NormalId.Front)
		return p
	end

	-- Shell: warm plaster over teal wainscot, an oak floor and trimmed ceiling.
	part("Floor", Vector3.new(W + 2, 1, D + 2), CFrame.new(0, -0.5, 0), WOOD, M.WoodPlanks)
	part("Ceiling", Vector3.new(W + 2, 1, D + 2), CFrame.new(0, H + 0.5, 0), rgb(244, 234, 210), M.Plaster)
	for _, side in { -1, 1 } do
		part("SideWall", Vector3.new(1, H, D + 2), CFrame.new(side * (W / 2 + 0.5), H / 2, 0), rgb(244, 234, 210), M.Plaster)
		part("EndWall", Vector3.new(W, H, 1), CFrame.new(0, H / 2, side * (D / 2 + 0.5)), rgb(236, 160, 96), M.Plaster)
		part("Wainscot", Vector3.new(0.2, 3, D), CFrame.new(side * (W / 2 - 0.1), 1.5, 0), TEAL, M.WoodPlanks)
		part("Skirting", Vector3.new(W, 0.4, 0.25), CFrame.new(0, 0.2, side * (D / 2 - 0.1)), TEAL, M.Wood)
		part("WainscotCap", Vector3.new(0.35, 0.18, D), CFrame.new(side * (W / 2 - 0.22), 3.06, 0), GOLD, M.Wood)
		part("CrownTrim", Vector3.new(0.45, 0.7, D), CFrame.new(side * (W / 2 - 0.25), H - 0.6, 0), CREAM, M.Wood)
		part("CrownTrim", Vector3.new(W, 0.7, 0.45), CFrame.new(0, H - 0.6, side * (D / 2 - 0.25)), CREAM, M.Wood)
	end
	-- Coffered ceiling: transverse beams carry the lanterns, long beams between.
	for _, z in { -12, 0, 12 } do
		part("CeilingBeam", Vector3.new(W, 0.7, 0.7), CFrame.new(0, H - 0.4, z), WOOD, M.Wood)
		for _, x in { -12, 12 } do
			local lamp = Props.lantern(hall, ORIGIN * CFrame.new(x, H - 2.5, z), 22, 0.8)
			for _, piece in lamp:GetChildren() do
				if piece:IsA("BasePart") then piece.CanCollide = false end
			end
		end
	end
	for _, x in { -16, 0, 16 } do
		part("CeilingBeam", Vector3.new(0.7, 0.7, D), CFrame.new(x, H - 0.4, 0), WOOD, M.Wood)
	end
	-- Lower lanterns over the entrance, the sales counter and the back row.
	for _, spot in { Vector3.new(-17, 11, -7), Vector3.new(0, 13.5, -13), Vector3.new(0, 13.5, 12) } do
		local lamp = Props.lantern(hall, ORIGIN * CFrame.new(spot), 18, 0.8)
		for _, piece in lamp:GetChildren() do
			if piece:IsA("BasePart") then piece.CanCollide = false end
		end
	end
	-- Side windows light the aisles; back windows flank the welcome sign and
	-- wear linen curtains.
	for _, side in { -1, 1 } do
		for _, z in { -16, -8 } do
			part("WindowFrame", Vector3.new(0.3, 7, 6), CFrame.new(side * (W / 2 - 0.25), 10, z), TEAL, M.Wood)
			local pane = part("WindowLight", Vector3.new(0.1, 6, 5), CFrame.new(side * (W / 2 - 0.45), 10, z), CREAM, M.Neon)
			pane.CanCollide = false
			Props.light(pane, CREAM, 14, 0.35)
		end
		local x = side * 18
		part("WindowFrame", Vector3.new(6, 7, 0.3), CFrame.new(x, 10, D / 2 - 0.25), TEAL, M.Wood)
		local pane = part("WindowLight", Vector3.new(5, 6, 0.1), CFrame.new(x, 10, D / 2 - 0.45), CREAM, M.Neon)
		pane.CanCollide = false
		Props.light(pane, CREAM, 14, 0.35)
		for _, dx in { -3.3, 3.3 } do
			local curtain = part("Curtain", Vector3.new(1.5, 7.5, 0.15), CFrame.new(x + dx, 9.4, D / 2 - 0.65), LINEN, M.Fabric)
			curtain.CanCollide = false
		end
	end
	sign("WelcomeSign", Vector3.new(24, 2.5, 0.2), CFrame.new(0, 14, D / 2 - 0.3), "HARBOUR HOME", TEAL)
	sign("ShowroomGuide", Vector3.new(26, 1.5, 0.2), CFrame.new(0, 11.5, D / 2 - 0.3), "Browse a display · Buy here · Place at home", SHADE)
	part("ExitDoor", Vector3.new(4, 8, 0.3), CFrame.new(0, 4, -D / 2 + 0.2), rgb(60, 98, 130), M.WoodPlanks)
	sign("ExitSign", Vector3.new(6, 1.3, 0.2), CFrame.new(0, 9.5, -D / 2 + 0.4) * CFrame.Angles(0, math.pi, 0), "EXIT · PLAZA", TEAL)
	-- Framed art flanks the exit; timber columns and an arch frame the doorway.
	for _, side in { -1, 1 } do
		local frame = part("ArtFrame", Vector3.new(7, 4.5, 0.2), CFrame.new(side * 12, 6, -D / 2 + 0.15), GOLD, M.Wood)
		frame.CanCollide = false
		local canvas = part("ArtCanvas", Vector3.new(6, 3.5, 0.12), CFrame.new(side * 12, 6, -D / 2 + 0.3), TEAL, M.SmoothPlastic)
		canvas.CanCollide = false
		part("DoorColumn", Vector3.new(1.3, 12, 1.3), CFrame.new(side * 5, 6, -19.2), CREAM, M.Wood)
		part("DoorColumnCap", Vector3.new(1.7, 0.5, 1.7), CFrame.new(side * 5, 12.25, -19.2), WOOD, M.Wood)
		part("DoorColumnBase", Vector3.new(1.7, 0.6, 1.7), CFrame.new(side * 5, 0.3, -19.2), WOOD, M.Wood)
	end
	part("DoorArch", Vector3.new(12.3, 1.2, 1.3), CFrame.new(0, 13, -19.2), WOOD, M.Wood)
	-- Runner rugs warm the aisles; none of it blocks a walking avatar.
	local function rug(name: string, size: Vector3, at: Vector3, color: Color3)
		local carpet = part(name, size, ORIGIN * CFrame.new(at), color, M.Fabric)
		carpet.CanCollide = false
	end
	rug("CentreRunnerTrim", Vector3.new(5.8, 0.06, 28.8), Vector3.new(0, 0.03, -1), GOLD)
	rug("CentreRunner", Vector3.new(5, 0.08, 28), Vector3.new(0, 0.05, -1), RUG)
	for _, x in { -10, 10 } do
		rug("AisleRunnerTrim", Vector3.new(3.8, 0.06, 22.8), Vector3.new(x, 0.03, 4), GOLD)
		rug("AisleRunner", Vector3.new(3, 0.08, 22), Vector3.new(x, 0.05, 4), RUG)
	end
	rug("EntryMat", Vector3.new(6, 0.08, 2.5), Vector3.new(0, 0.05, -18), TEAL)
	-- Potted greenery by the door and in the counter corner.
	local rng = Random.new(90210)
	local function plant(x: number, z: number)
		local m = Instance.new("Model")
		m.Name = "PottedPlant"
		local function at(dx: number, y: number, dz: number): Vector3
			return (ORIGIN * CFrame.new(x + dx, y, z + dz)).Position
		end
		Props.cylinder(m, at(0, 0.85, 0), 1.7, 2.2, POT, M.SmoothPlastic)
		Props.cylinder(m, at(0, 1.78, 0), 0.25, 2, rgb(70, 52, 40), M.Ground)
		Props.beam(m, at(0, 1.9, 0), at(0, 3.1, 0), 0.35, rgb(92, 70, 48), 0.35, M.Wood)
		for _, offset in {
			Vector3.new(0, 3.1, 0),
			Vector3.new(0.9, 2.7, 0.4),
			Vector3.new(-0.8, 2.8, -0.5),
			Vector3.new(0.2, 2.6, -0.9),
		} do
			Props.blob(m, at(offset.X, offset.Y, offset.Z), Vector3.new(2.4, 1.1, 1.6), rng, LEAF, M.LeafyGrass)
		end
		for _, piece in m:GetDescendants() do
			if piece:IsA("BasePart") then piece.CanCollide = false end
		end
		m.Parent = hall
	end
	for _, spot in { Vector2.new(-7, -16.5), Vector2.new(7, -16.5), Vector2.new(-21, -12), Vector2.new(21, -12) } do
		plant(spot.X, spot.Y)
	end
	sign("ZoneSign", Vector3.new(12, 2, 0.15), CFrame.new(-(W / 2 - 0.5), 11.8, 8) * CFrame.Angles(0, -math.pi / 2, 0), "COOKING & KITCHEN", TEAL)
	sign("ZoneSign", Vector3.new(12, 2, 0.15), CFrame.new(W / 2 - 0.5, 11.8, 8) * CFrame.Angles(0, math.pi / 2, 0), "SHOP FLOOR & STORAGE", TEAL)

	-- Full-size examples of every catalogue item, each on a plinth facing the
	-- aisle where its customers stand.
	for _, spec in DISPLAYS do
		local item = Furniture.Items[spec.id]
		local display = Instance.new("Model")
		display.Name = spec.id .. "Display"
		display:SetAttribute("ItemId", spec.id)
		local plinth = part("DisplayPlinth", spec.plinth, CFrame.new(spec.x, 0.15, spec.z), rgb(224, 207, 174), M.Limestone)
		plinth.Parent = display
		local trim = part("PlinthTrim", Vector3.new(spec.plinth.X + 0.3, 0.1, spec.plinth.Z + 0.3), CFrame.new(spec.x, 0.32, spec.z), GOLD, M.Wood)
		trim.Parent = display
		local sample = buildSample(spec.id, display, ORIGIN * CFrame.new(spec.x, 0.37, spec.z) * CFrame.Angles(0, spec.turn, 0))
		sample.Name = "Sample" .. spec.id
		sample.Parent = display
		-- The price board stands at the plinth's aisle edge; the description
		-- hangs on the wall above the display.
		local labelFrame, detailFrame, detailSize, customer
		if spec.side == "left" then
			labelFrame = CFrame.new(spec.x + 4.45, 1.9, spec.z) * CFrame.Angles(0, -math.pi / 2, 0)
			detailFrame = CFrame.new(-(W / 2 - 0.5), 8.8, spec.z) * CFrame.Angles(0, -math.pi / 2, 0)
			detailSize = Vector3.new(spec.plinth.Z, 2.8, 0.15)
			customer = Vector3.new(spec.x + 8, 3.2, spec.z)
		elseif spec.side == "right" then
			labelFrame = CFrame.new(spec.x - 4.45, 1.9, spec.z) * CFrame.Angles(0, math.pi / 2, 0)
			detailFrame = CFrame.new(W / 2 - 0.5, 8.8, spec.z) * CFrame.Angles(0, math.pi / 2, 0)
			detailSize = Vector3.new(spec.plinth.Z, 2.8, 0.15)
			customer = Vector3.new(spec.x - 8, 3.2, spec.z)
		else
			labelFrame = CFrame.new(spec.x, 1.9, spec.z - 3.8)
			detailFrame = CFrame.new(spec.x, 8.8, D / 2 - 0.4)
			detailSize = Vector3.new(spec.plinth.X, 2.8, 0.15)
			customer = Vector3.new(spec.x, 3.2, spec.z - 6.5)
		end
		display:SetAttribute("CustomerSpot", customer)
		local labelSize = Vector3.new(math.min(spec.plinth.X, spec.plinth.Z) - 0.5, 2.2, 0.2)
		local backing = part(
			"PriceFrame",
			Vector3.new(labelSize.X + 0.5, labelSize.Y + 0.5, 0.12),
			labelFrame * CFrame.new(0, 0, 0.06),
			GOLD,
			M.Metal
		)
		backing.CanCollide = false
		backing.Parent = display
		local label = sign("PriceLabel", labelSize, labelFrame, string.format("%s\n$%d", item.Name, item.Price), SHADE)
		label.Parent = display
		label:SetAttribute("ItemId", spec.id)
		sign("DisplayDetails", detailSize, detailFrame, item.Description, TEAL).Parent = display
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BrowseFurniturePrompt"
		prompt.ActionText = "View · $" .. item.Price
		prompt.ObjectText = item.Name
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt:SetAttribute("ItemId", spec.id)
		prompt.Parent = label
		display.Parent = hall
	end

	-- An indoor service desk also offers the whole catalogue.
	local counterFrame = ORIGIN * CFrame.new(-17, 0, -7)
	local counter = ShopDesk.build(hall, counterFrame)
	counter.Name = "SalesCounter"
	local top = part("CounterTop", Vector3.new(ShopDesk.WIDTH, 0.2, ShopDesk.DEPTH), CFrame.new(-17, ShopDesk.HEIGHT + 0.1, -7), WOOD, M.Wood)
	top.Transparency, top.CanCollide, top.CanQuery, top.CanTouch = 1, false, false, false
	local browse = Instance.new("ProximityPrompt")
	browse.Name, browse.ActionText, browse.ObjectText = "BrowseFurniturePrompt", "Browse furniture", "Harbour Home"
	browse.MaxActivationDistance, browse.RequiresLineOfSight, browse.HoldDuration = 7, false, 0
	browse.Parent = top
	hall:SetAttribute("KeeperFrame", counterFrame * CFrame.new(0, 0, ShopDesk.DEPTH / 2 + 1.3))
	sign("ServiceSign", Vector3.new(10, 2, 0.2), CFrame.new(-17, 8, -3), "Need a hand?\nBrowse at the counter", TEAL)
	-- Tag after parenting so listeners inspect the finished showroom.
	hall.Parent = folder
	restoreTags(hall)
	return hall
end

function FurnitureShop.build(plaza: Model, plazaFrame: CFrame): Model
	local hall = ensureInterior()
	local existing = plaza:FindFirstChild("FurnitureShop")
	local shop: Model
	if existing and existing:IsA("Model") and existing:GetAttribute("LayoutVersion") == LAYOUT_VERSION then
		shop = existing
	else
		if existing then existing:Destroy() end
		local base = plazaFrame * CFrame.new(45, 0, 38) * CFrame.Angles(0, -math.pi / 2, 0)
		local doorFace, leaf
		shop, doorFace, leaf = PlazaHouses.house(plaza, base, {
			width = 18, depth = 18, stories = 2,
			lower = rgb(236, 160, 96), upper = rgb(244, 234, 210), trim = rgb(250, 242, 224),
			shutter = TEAL, roof = rgb(152, 72, 46), door = rgb(60, 98, 130), balcony = true,
			shop = "HARBOUR HOME", blade = "FURNITURE", signColor = CREAM, doorSide = 1,
		}, Random.new(5150))
		shop.Name = "FurnitureShop"
		shop:SetAttribute("LayoutVersion", LAYOUT_VERSION)
		leaf.Name = "StreetDoor"
		shop:SetAttribute("ExitFrame", doorFace * CFrame.new(0, 3.2, 4.5) * CFrame.Angles(0, math.pi, 0))
		for _, prop in plaza:GetChildren() do
			local reach = if prop.Name == "Palm" then 10 elseif prop.Name == "Planter" then 4 else nil
			local trunk = reach and prop:IsA("Model") and prop:FindFirstChildWhichIsA("BasePart", true)
			if trunk then
				local p = base:PointToObjectSpace(trunk.Position)
				local dx, dz = math.max(math.abs(p.X) - 9.4, 0), math.max(math.abs(p.Z) - 15, 0)
				if dx * dx + dz * dz < reach * reach then prop:Destroy() end
			end
		end
		local board = Props.part(shop, Vector3.new(2.8, 3.6, 0.2), doorFace * CFrame.new(-5, 1.8, 4), rgb(36, 44, 40), M.Slate)
		board.CanCollide = false
		PlazaHouses.boardText(board, "FREEZERS\nCOUNTERS\nRACKS\ninside", Enum.NormalId.Back)
	end
	local leaf = shop:FindFirstChild("StreetDoor", true)
	local exit = hall:FindFirstChild("ExitDoor")
	if leaf and leaf:IsA("BasePart") then doorPrompt(leaf, "Enter", hall:GetAttribute("ArrivalFrame")) end
	if exit and exit:IsA("BasePart") then doorPrompt(exit, "Leave", shop:GetAttribute("ExitFrame")) end
	return shop
end

function FurnitureShop.ensure(root: Instance)
	for _, plaza in root:GetDescendants() do
		if plaza:IsA("Model") and plaza.Name == "Plaza" then
			local frame = PlazaHouses.pavingFrame(plaza)
			if frame then FurnitureShop.build(plaza, frame) end
		end
	end
end

return FurnitureShop

end
local function loadFurnitureCatalog()
	-- Furniture sold at the plaza's furniture shop and the placement rules for a base
-- house, shared by the server (which validates every placement) and the build
-- mode preview. Pure: no Roblox services, so the saved-data tests run it directly.
--
-- Positions are house-local studs (the BaseHouse "HouseFrame": +Z is the street
-- front, the floor is y=0.16). An item at X, Z turns R quarter turns about +Y; its
-- own +Z is the side customers or the porter use.
local Furniture = {}

Furniture.Order = {
	"Freezer",
	"Register",
	"StorageRack",
	"FoodCase",
	"GrillStation",
	"Smoker",
	"SushiBar",
	"KitchenStorage",
	"DiningTable",
}
Furniture.Items = {
	Freezer = {
		Name = "Fish freezer",
		Price = 750,
		Room = "Shop",
		MaxPlaced = 4,
		Description = "Another chilled display for customers. Smaller fish leave room for more stock.",
		-- Body footprint, plus the strip customers stand on in front (+Z) and behind (-Z).
		Width = 9,
		Depth = 3.6,
		Front = 2.4,
		Back = 0,
	},
	Register = {
		Name = "Cash register counter",
		Price = 500,
		Room = "Shop",
		MaxPlaced = 3,
		Description = "A second till. Each counter serves one more customer at a time.",
		Width = 7.5,
		Depth = 3.05,
		-- Customers queue on the -Z side; the seller stands on +Z.
		Front = 2,
		Back = 2,
	},
	StorageRack = {
		Name = "Storage rack",
		Price = 300,
		Room = "Storage",
		MaxPlaced = 6,
		Description = "Shelving for overflow stock. Holds 12 fish when your freezers are full, so you can empty your boat.",
		Width = 6,
		Depth = 2,
		Front = 1.5,
		Back = 0,
	},
	-- Requires names the Paths stage that unlocks buying and placing the item.
	FoodCase = {
		Name = "Food display case",
		Price = 600,
		Room = "Shop",
		MaxPlaced = 3,
		Requires = "Supermarket",
		Description = "A chilled glass case. Shows 6 cooked dishes for shop customers to buy.",
		Width = 6,
		Depth = 2.6,
		Front = 2.4,
		Back = 0,
	},
	GrillStation = {
		Name = "Grill station",
		Price = 2000,
		Room = "Processing",
		MaxPlaced = 1,
		Requires = "Supermarket",
		Description = "Cooks grilled fish and fish skewers from Uncommon fish and rarer.",
		Width = 6,
		Depth = 2.4,
		Front = 2,
		Back = 0,
	},
	Smoker = {
		Name = "Smokehouse",
		Price = 4000,
		Room = "Processing",
		MaxPlaced = 1,
		Requires = "Supermarket",
		Description = "Slow-smokes Rare fish and rarer into smoked fish.",
		Width = 6,
		Depth = 2.4,
		Front = 2,
		Back = 0,
	},
	SushiBar = {
		Name = "Sushi bar",
		Price = 7500,
		Room = "Processing",
		MaxPlaced = 1,
		Requires = "Supermarket",
		Description = "Turns Epic and Legendary fish into sushi platters and golden sashimi.",
		Width = 6,
		Depth = 2.4,
		Front = 2,
		Back = 0,
	},
	KitchenStorage = {
		Name = "Kitchen storage",
		Price = 750,
		Room = "Processing",
		MaxPlaced = 1,
		Requires = "Supermarket",
		Description = "A chilled prep table. Select up to 8 fish by rarity for your porter to bring here for cooking.",
		Width = 6,
		Depth = 2.4,
		Front = 2,
		Back = 0,
	},
	DiningTable = {
		Name = "Dining table",
		Price = 400,
		Room = "Dining",
		MaxPlaced = 8,
		Requires = "Restaurant",
		Description = "A table for two in your dining room. Each seat welcomes one diner.",
		Width = 4,
		Depth = 2.6,
		-- A chair stands on each long side.
		Front = 1.6,
		Back = 1.6,
	},
}
Furniture.RACK_CAPACITY = 12
Furniture.KITCHEN_STORAGE_CAPACITY = 8
Furniture.GRID = 0.5

-- Inner floor of each furnishable room, as { x1, z1, x2, z2 }.
Furniture.Rooms = {
	Shop = { -22.6, 1.35, 22.6, 14.6 },
	Storage = { 3.35, -14.6, 22.6, 0.65 },
	Processing = { -22.6, -14.6, 2.65, 0.65 },
	Kitchen = { -22.6, -14.6, 2.65, 0.65 },
	-- The Restaurant's dining room extension behind the processing room.
	Dining = { -22.4, -29.4, -6.1, -15.35 },
}
Furniture.RoomNames = {
	Shop = "front shop room",
	Storage = "storage room",
	Processing = "kitchen",
	Kitchen = "kitchen",
	Dining = "dining room",
}
-- Walkways, doorways and the built-in fixtures stay clear.
Furniture.Blocked = {
	{ -4, 1.35, 4, 14.6 }, -- entrance aisle customers walk along
	{ -13.5, 1.35, -6.5, 4 }, -- doorway to the processing room
	{ 8.5, -3, 15.5, 4 }, -- doorway between the shop and the storage room
	{ 3.35, -10.5, 6.5, -3.5 }, -- passage from the processing room
	{ -20.8, 2.5, -15.6, 11.5 }, -- built-in freezer and its customer strip
	{ 11.5, 6.4, 21, 14.6 }, -- built-in counter, its customers and the seller
	{ -13.5, -3, -6.5, 1.35 }, -- processing room side of the shop doorway
	{ -0.5, -10.5, 2.65, -3.5 }, -- processing room side of the storage passage
	{ -3.5, -14.6, 2.65, -11 }, -- rear door
	{ -22.6, -14.6, -18, -1 }, -- built-in prep benches and their cooks
	{ -16, -29.4, -10, -25.5 }, -- dining room entrance
}

-- The rectangle { x1, z1, x2, z2 } the item covers, including its access strips.
function Furniture.footprint(itemId: string, x: number, z: number, r: number): { number }?
	local item = Furniture.Items[itemId]
	if not item then
		return nil
	end
	local halfW = item.Width / 2
	local low, high = -item.Depth / 2 - item.Back, item.Depth / 2 + item.Front
	-- Quarter turns of the local rectangle (x across, z from low to high).
	local corners = {}
	for _, c in { { -halfW, low }, { halfW, high } } do
		local cx, cz = c[1], c[2]
		for _ = 1, r % 4 do
			-- Clockwise seen from above matches CFrame.Angles(0, r * pi / 2, 0).
			cx, cz = cz, -cx
		end
		table.insert(corners, { cx, cz })
	end
	return {
		x + math.min(corners[1][1], corners[2][1]),
		z + math.min(corners[1][2], corners[2][2]),
		x + math.max(corners[1][1], corners[2][1]),
		z + math.max(corners[1][2], corners[2][2]),
	}
end

local function overlaps(a: { number }, b: { number }): boolean
	return a[1] < b[3] - 1e-3 and a[3] > b[1] + 1e-3 and a[2] < b[4] - 1e-3 and a[4] > b[2] + 1e-3
end

local function inside(a: { number }, room: { number }): boolean
	return a[1] >= room[1] - 1e-3 and a[3] <= room[3] + 1e-3 and a[2] >= room[2] - 1e-3 and a[4] <= room[4] + 1e-3
end

local function onGrid(value: number): boolean
	return type(value) == "number"
		and value == value
		and math.abs(value) <= 64
		and math.abs(value / Furniture.GRID - math.round(value / Furniture.GRID)) < 1e-6
end

-- Checks one placement against the room rules and the other placed items
-- (`placed`, skipping index `skip`). Returns nil when it fits, or a player-facing reason.
function Furniture.check(placed, itemId: string, x: number, z: number, r: number, skip: number?): string?
	local item = Furniture.Items[itemId]
	if not item then
		return "That isn't furniture."
	elseif not (onGrid(x) and onGrid(z) and type(r) == "number" and r % 1 == 0 and r >= 0 and r <= 3) then
		return "That isn't a spot in your house."
	end
	local area = Furniture.footprint(itemId, x, z, r) :: { number }
	if not inside(area, Furniture.Rooms[item.Room]) then
		return item.Name .. "s can only go in the " .. Furniture.RoomNames[item.Room] .. "."
	end
	for _, blocked in Furniture.Blocked do
		if overlaps(area, blocked) then
			return "Keep doorways, the aisle and the built-in fixtures clear."
		end
	end
	for index, other in placed do
		if
			index ~= skip and overlaps(area, Furniture.footprint(other.ItemId, other.X, other.Z, other.R) :: { number })
		then
			return "That spot is taken by other furniture."
		end
	end
	return nil
end

-- nil when the item can be bought and placed on this profile's path, otherwise why not.
-- `unlocked` is a Paths stage id → true map.
function Furniture.locked(itemId: string, unlocked): string?
	local item = Furniture.Items[itemId]
	if item and item.Requires and not (unlocked and unlocked[item.Requires]) then
		return item.Name .. "s unlock with the " .. item.Requires .. " path."
	end
	return nil
end

function Furniture.count(placed, itemId: string): number
	local count = 0
	for _, entry in placed do
		if entry.ItemId == itemId then
			count += 1
		end
	end
	return count
end

-- World frame on the floor of the house for a placed entry.
function Furniture.frame(houseFrame, entry)
	return houseFrame * CFrame.new(entry.X, 0.16, entry.Z) * CFrame.Angles(0, entry.R * math.pi / 2, 0)
end

return Furniture

end
dependencies.FurnitureCatalog = loadFurnitureCatalog()
dependencies.FurnitureShop = loadFurnitureShop()

local function loadBiomes()
	-- World layout and mood for each biome. Shared so the server can build the map
-- and the client can match the atmosphere to wherever the camera is.

export type Look = {
	waterColor: Color3,
	atmosphereColor: Color3,
	atmosphereDecay: Color3,
	density: number,
	haze: number,
	glare: number,
	tint: Color3,
	saturation: number,
	contrast: number,
	ambient: Color3,
	cloudCover: number,
	cloudColor: Color3,
}

export type Biome = {
	id: string,
	name: string,
	center: Vector2, -- X/Z in world space
	radius: number,
	seabed: Enum.Material,
	seabedColor: Color3,
	shelfDepth: number?, -- biome-wide seabed height; nil keeps the deep sea floor
	look: Look,
}

local rgb = Color3.fromRGB

local Biomes = {}

Biomes.Seed = 1847
Biomes.WaterLevel = 0
Biomes.SeaFloor = -64
Biomes.MapHalfSize = 5200
-- Blend distant islands into the horizon instead of keeping sharp silhouettes.
Biomes.DistanceFogOffset = 0.1

Biomes.Normal = {
	id = "normal",
	name = "Gullhaven Sound",
	center = Vector2.new(0, 0),
	radius = 1300,
	seabed = Enum.Material.Sand,
	seabedColor = rgb(206, 190, 148),
	look = {
		waterColor = rgb(46, 110, 118),
		atmosphereColor = rgb(199, 205, 200),
		atmosphereDecay = rgb(92, 106, 114),
		density = 0.32,
		haze = 1.8,
		glare = 0.2,
		tint = rgb(240, 245, 245),
		saturation = -0.05,
		contrast = 0.05,
		ambient = rgb(128, 132, 136),
		cloudCover = 0.55,
		cloudColor = rgb(230, 232, 235),
	},
} :: Biome

Biomes.Swamp = {
	id = "swamp",
	name = "The Sodden Mire",
	center = Vector2.new(-3700, -200),
	radius = 1250,
	seabed = Enum.Material.Mud,
	seabedColor = rgb(64, 58, 36),
	shelfDepth = -14,
	look = {
		waterColor = rgb(92, 84, 46),
		atmosphereColor = rgb(214, 190, 128),
		atmosphereDecay = rgb(140, 110, 60),
		density = 0.42,
		haze = 2.8,
		glare = 0.1,
		tint = rgb(255, 236, 200),
		saturation = -0.1,
		contrast = 0.04,
		ambient = rgb(140, 126, 96),
		cloudCover = 0.7,
		cloudColor = rgb(220, 200, 160),
	},
} :: Biome

Biomes.Tropical = {
	id = "tropical",
	name = "Coral Shallows",
	center = Vector2.new(-200, 3700),
	radius = 1300,
	seabed = Enum.Material.Limestone,
	seabedColor = rgb(226, 214, 170),
	shelfDepth = -22,
	look = {
		waterColor = rgb(38, 170, 170),
		atmosphereColor = rgb(210, 235, 240),
		atmosphereDecay = rgb(120, 170, 190),
		density = 0.28,
		haze = 1.2,
		glare = 0.6,
		tint = rgb(255, 252, 240),
		saturation = 0.15,
		contrast = 0.06,
		ambient = rgb(150, 156, 150),
		cloudCover = 0.45,
		cloudColor = rgb(255, 255, 255),
	},
} :: Biome

Biomes.Volcanic = {
	id = "volcanic",
	name = "Cinder Isles",
	center = Vector2.new(3700, 300),
	radius = 1250,
	seabed = Enum.Material.Basalt,
	seabedColor = rgb(38, 36, 38),
	look = {
		waterColor = rgb(40, 46, 50),
		atmosphereColor = rgb(180, 110, 90),
		atmosphereDecay = rgb(90, 40, 30),
		density = 0.38,
		haze = 2.3,
		glare = 0.4,
		tint = rgb(255, 220, 205),
		saturation = -0.05,
		contrast = 0.12,
		ambient = rgb(120, 96, 90),
		cloudCover = 0.75,
		cloudColor = rgb(110, 96, 92),
	},
} :: Biome

Biomes.Ice = {
	id = "ice",
	name = "Frostmere Expanse",
	center = Vector2.new(300, -3700),
	radius = 1300,
	seabed = Enum.Material.Glacier,
	seabedColor = rgb(150, 186, 204),
	look = {
		waterColor = rgb(70, 120, 150),
		atmosphereColor = rgb(215, 228, 240),
		atmosphereDecay = rgb(150, 175, 200),
		density = 0.36,
		haze = 2,
		glare = 0.3,
		tint = rgb(230, 240, 255),
		saturation = -0.2,
		contrast = 0.05,
		ambient = rgb(150, 160, 175),
		cloudCover = 0.65,
		cloudColor = rgb(240, 245, 250),
	},
} :: Biome

Biomes.OpenSea = {
	id = "open",
	name = "Open Waters",
	center = Vector2.new(0, 0),
	radius = 0,
	seabed = Enum.Material.Slate,
	seabedColor = rgb(56, 74, 80),
	look = {
		waterColor = rgb(30, 80, 96),
		atmosphereColor = rgb(180, 190, 195),
		atmosphereDecay = rgb(70, 85, 95),
		density = 0.35,
		haze = 2.1,
		glare = 0.2,
		tint = rgb(235, 240, 245),
		saturation = -0.1,
		contrast = 0.06,
		ambient = rgb(118, 124, 130),
		cloudCover = 0.6,
		cloudColor = rgb(215, 220, 225),
	},
} :: Biome

Biomes.list = { Biomes.Normal, Biomes.Swamp, Biomes.Tropical, Biomes.Volcanic, Biomes.Ice } :: { Biome }

-- How far a point is into a biome, as a fraction of its radius (0 = center, 1 = edge).
function Biomes.depthIn(biome: Biome, position: Vector3): number
	return (Vector2.new(position.X, position.Z) - biome.center).Magnitude / biome.radius
end

function Biomes.at(position: Vector3): Biome
	local best, bestDepth = Biomes.OpenSea, 1
	for _, biome in Biomes.list do
		local depth = Biomes.depthIn(biome, position)
		if depth < bestDepth then
			best, bestDepth = biome, depth
		end
	end
	return best
end

return Biomes

end
local Biomes = loadBiomes()
dependencies.Biomes = Biomes
local function loadSeabed()
	-- SEABED_SOURCE --
end
dependencies.Seabed = loadSeabed()
local function loadHarbour()
	-- The home island: a horseshoe of land wrapped around a sheltered bay that opens to the west.
-- Player bases line the bay shore (a quay plot with two piers each), a Mediterranean village of
-- whitewashed cube houses, pastel townhouses and villas rings them around a piazza, windmills and a
-- chapel crown the hills, and a lighthouse stands on the southern headland at the bay mouth.
-- The coastline is traced from the concept sketch in pixel coordinates and scaled into the world.

local CollectionService = game:GetService("CollectionService")

local BaseHouse = dependencies.BaseHouse
local BeachDetails = dependencies.BeachDetails
local Drydock = dependencies.Drydock
local FurnitureShop = dependencies.FurnitureShop
local BackpackShop = dependencies.BackpackShop
local Islands = dependencies.Islands
local LowPoly = dependencies.LowPoly
local Med = dependencies.Mediterranean
local PlazaHouses = dependencies.PlazaHouses
local Props = dependencies.Props
local RodShop = dependencies.RodShop
local Seabed = dependencies.Seabed

local Harbour = {}

local rgb = Color3.fromRGB
local pick = Props.pick
local M = Enum.Material
local TAU = math.pi * 2

local SCALE = 0.85 -- studs per sketch pixel
local SKETCH_CENTER = Vector2.new(870, 1330) -- sketch pixel that lands on the biome center
local CELL = 16 -- ground mesh resolution
local SEABED_RUN = 128 -- continuous underwater descent from shore to the deep floor
local GROUND_MARGIN = SEABED_RUN + CELL
local LAND = 5 -- height of the flat village ground
local ROAD_OFFSET = 95 -- how far inland the ring road runs from the bay shore
local ROAD_WIDTH = 16
local LANE_OFFSET = 40 -- how far behind the ring road the back lane runs, past the first row of houses
local LANE_WIDTH = 10
local VILLAGE_BAND = 165 -- land closer than this to the bay stays flat; further inland rises into hills and cliffs
local PLAZA_HALF = 60 -- the piazza is a square this far from its centre to each edge

-- Roughly how far the island reaches from its center, for keeping other islands away.
Harbour.FOOTPRINT = 820
Harbour.BASE_TAG = "PlayerBase"

-- Sea-facing coast, clockwise from the tip of the western arm round to the southern headland.
-- The north and east shores bulge past the sketch so the piazza and the eastern bases
-- keep room for the road and a row or two of houses behind them.
local OUTER = {
	{ 430, 1340 },
	{ 372, 1290 },
	{ 330, 1200 },
	{ 312, 1090 },
	{ 318, 970 },
	{ 345, 860 },
	{ 395, 760 },
	{ 448, 672 },
	{ 528, 588 },
	{ 640, 515 },
	{ 780, 473 },
	{ 950, 477 },
	{ 1120, 510 },
	{ 1270, 552 },
	{ 1365, 600 },
	{ 1430, 680 },
	{ 1505, 790 },
	{ 1565, 945 },
	{ 1610, 1120 },
	{ 1632, 1320 },
	{ 1615, 1520 },
	{ 1560, 1712 },
	{ 1465, 1880 },
	{ 1325, 2018 },
	{ 1150, 2098 },
	{ 950, 2130 },
	{ 760, 2140 },
	{ 580, 2110 },
	{ 430, 2050 },
	{ 320, 1960 },
	{ 262, 1850 },
	{ 250, 1740 },
	{ 265, 1640 },
	{ 290, 1565 },
}

-- Bay shore, from the southern headland round the inner bay and back to the western arm.
local BAY = {
	{ 350, 1555 },
	{ 450, 1553 },
	{ 550, 1565 },
	{ 650, 1598 },
	{ 760, 1640 },
	{ 850, 1640 },
	{ 950, 1620 },
	{ 1030, 1630 },
	{ 1100, 1668 },
	{ 1170, 1690 },
	{ 1240, 1660 },
	{ 1305, 1585 },
	{ 1345, 1480 },
	{ 1362, 1360 },
	{ 1348, 1262 },
	{ 1290, 1182 },
	{ 1200, 1122 },
	{ 1105, 1090 },
	{ 1045, 1050 },
	{ 1012, 980 },
	{ 985, 902 },
	{ 940, 852 },
	{ 870, 818 },
	{ 760, 820 },
	{ 685, 850 },
	{ 652, 905 },
	{ 663, 1000 },
	{ 680, 1118 },
	{ 660, 1190 },
	{ 600, 1255 },
	{ 520, 1300 },
}

-- The "n" shapes on the sketch, as points on the bay shore.
local BASES = { { 668, 1030 }, { 1000, 950 }, { 1150, 1105 }, { 1360, 1330 }, { 1340, 1500 }, { 880, 1638 } }
local LIGHTHOUSE = { 360, 1640 }
-- The bathing beach round the head of the bay, between the first two bases.
local BEACH = { { 660, 975 }, { 652, 905 }, { 685, 850 }, { 760, 820 }, { 870, 818 }, { 940, 852 }, { 985, 902 } }
local BEACH_WIDTH = 42 -- dry sand from the waterline up to the foot of the dunes
local BEACH_FADE = 45 -- the beach blends back into the normal shore over this much coastline at each end
-- Set back from the bay so the ring road runs along the piazza's southern side; the drydock
-- slipway needs the bay about 130 studs south of the centre, so move this with SCALE.
local PLAZA = { 870, 665 }

-- Sun-baked Mediterranean ground: dry grass, maquis on the hills, pale limestone cliffs
local GRASS = rgb(146, 148, 90)
local HILL = rgb(116, 124, 74)
local SAND = rgb(224, 208, 166)
local BEACH_SAND = rgb(242, 228, 188)
local WET_SAND = rgb(196, 176, 136)
local DUNE_GRASS = { rgb(150, 156, 92), rgb(170, 168, 104), rgb(126, 140, 80) }
local BEACH_COLORS = { rgb(214, 64, 56), rgb(40, 120, 196), rgb(240, 186, 52), rgb(40, 156, 140), rgb(226, 112, 150) }
local ROCK = rgb(186, 176, 156)
local ROAD = rgb(204, 192, 168)
local DIRT = rgb(178, 140, 98)
local PAVING = rgb(228, 216, 194)
local PAVING_DARK = rgb(176, 160, 134)
local QUAY = rgb(150, 140, 126)
local DECK = rgb(132, 102, 74)

local ACCENTS = {
	rgb(60, 110, 170),
	rgb(180, 60, 50),
	rgb(70, 140, 80),
	rgb(220, 180, 60),
	rgb(130, 80, 160),
	rgb(220, 120, 50),
}
local MAQUIS = { rgb(92, 110, 64), rgb(110, 120, 70), rgb(78, 98, 60) }
local BOATS = { rgb(36, 92, 168), rgb(190, 60, 50), rgb(60, 140, 90), rgb(230, 180, 60), rgb(40, 140, 160) }

type Shape = {
	coast: { Vector2 },
	bayShore: { Vector2 },
	beach: { Vector2 },
	beachLength: number,
	center: Vector2,
	flats: { Spot }, -- areas kept level even past the village band
	toWorld: ({ number }) -> Vector2,
}
type Spot = { position: Vector2, radius: number }
type RoadPoint = { position: Vector2, inland: Vector2 }
type Street = { RoadPoint } -- an unbroken run of street, in order

----------------------------------------------------------------------------------------------------
-- Geometry

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function segmentDistance(p: Vector2, a: Vector2, b: Vector2): (number, Vector2)
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
	local q = a + ab * t
	return (p - q).Magnitude, q
end

local function isInside(poly: { Vector2 }, p: Vector2): boolean
	local inside = false
	local j = #poly
	for i = 1, #poly do
		local a, b = poly[i], poly[j]
		if (a.Y > p.Y) ~= (b.Y > p.Y) and p.X < (b.X - a.X) * (p.Y - a.Y) / (b.Y - a.Y) + a.X then
			inside = not inside
		end
		j = i
	end
	return inside
end

-- Nearest point on a polyline and the segment direction there.
local function nearestOnLine(line: { Vector2 }, p: Vector2): (number, Vector2, Vector2)
	local best, point, tangent = math.huge, p, Vector2.new(1, 0)
	for i = 1, #line - 1 do
		local dist, q = segmentDistance(p, line[i], line[i + 1])
		if dist < best then
			best, point, tangent = dist, q, (line[i + 1] - line[i]).Unit
		end
	end
	return best, point, tangent
end

-- Signed distance to the coast: positive on land, negative at sea.
local function coastDistance(shape: Shape, p: Vector2): number
	local coast = shape.coast
	local best = math.huge
	local j = #coast
	for i = 1, #coast do
		best = math.min(best, (segmentDistance(p, coast[j], coast[i])))
		j = i
	end
	return if isInside(coast, p) then best else -best
end

-- How much `p` belongs to the bathing beach: 1 along its middle, fading out at both ends and away
-- from the shore.
local function beachWeight(shape: Shape, p: Vector2): number
	local line = shape.beach
	local best, along, walked = math.huge, 0, 0
	for i = 1, #line - 1 do
		local a, b = line[i], line[i + 1]
		local dist, q = segmentDistance(p, a, b)
		if dist < best then
			best, along = dist, walked + (q - a).Magnitude
		end
		walked += (b - a).Magnitude
	end
	return smoothstep(along / BEACH_FADE)
		* smoothstep((walked - along) / BEACH_FADE)
		* (1 - smoothstep((best - 100) / 40))
end

local function beachWidthAt(p: Vector2): number
	return BEACH_WIDTH + math.noise(p.X / 42, p.Y / 42, 3.7) * 10
end

local function heightAt(shape: Shape, p: Vector2): number
	-- Water must extend beneath the original lift and out through its slipway.
	-- Keep the channel's sloping banks underneath the existing quay walls.
	local plaza = shape.toWorld(PLAZA)
	local dx, dz = math.abs(p.X - plaza.X), p.Y - plaza.Y
	if dx < 25 and dz > 108 and dz < 238 then
		local bank = math.clamp((25 - dx) / 8, 0, 1)
		local ends = math.min(math.clamp((dz - 108) / 8, 0, 1), math.clamp((238 - dz) / 8, 0, 1))
		if bank * ends >= 1 then
			return -18
		end
	end
	local d = coastDistance(shape, p)
	local beach = beachWeight(shape, p)
	if d <= 0 then
		return Seabed.height(-d, SEABED_RUN)
	end

	local h = LAND
	if d < 10 then
		h = 1.5 * d / 10
	elseif d < 24 then
		h = 1.5 + (LAND - 1.5) * smoothstep((d - 10) / 14)
	end
	if beach > 0 then
		-- A wide, nearly flat strand, then a low dune up to the village
		local width = beachWidthAt(p)
		local sand = if d < width then 2 * d / width else 2 + (LAND - 2) * smoothstep((d - width) / 16)
		-- Small wind-shaped undulations fade out before the level village ground.
		sand += math.noise(p.X / 19, p.Y / 19, 2.4) * 0.24 * smoothstep(d / 10) * (1 - smoothstep((d - width) / 12))
		h += (sand - h) * beach
	end

	-- Away from the bay the land climbs: cliffs along the open-sea coast, wooded hills inland
	local inland = smoothstep(((nearestOnLine(shape.bayShore, p)) - VILLAGE_BAND) / 65)
	for _, f in shape.flats do
		inland *= smoothstep(((p - f.position).Magnitude - f.radius) / 40)
	end
	if inland <= 0 then
		return h
	end
	local cliff = smoothstep((d - 3) / 12)
	local hill = smoothstep((d - 60) / 80)
	local noise = math.clamp(math.noise(p.X / 190, p.Y / 190, 7.3) + 0.5, 0, 1)
	return h + inland * (cliff * 12 + hill * (8 + 34 * noise))
end

local function makeShape(center: Vector2): Shape
	local function toWorld(p: { number }): Vector2
		return center + (Vector2.new(p[1], p[2]) - SKETCH_CENTER) * SCALE
	end
	local flats = { { position = toWorld(PLAZA), radius = PLAZA_HALF * 1.6 } }
	local coast, bayShore = {}, { toWorld(OUTER[#OUTER]) }
	for _, p in OUTER do
		table.insert(coast, toWorld(p))
	end
	for i, p in BAY do
		local a = toWorld(p)
		table.insert(coast, a)
		table.insert(bayShore, a)
		if i >= 20 and i <= 27 then
			-- The bathing cove follows one shared curve for land, props and surf.
			-- Keep the sketch's main anchors, rounding the long straight beach edges.
			local prev, b, nxt = toWorld(BAY[i - 1]), toWorld(BAY[i + 1]), toWorld(BAY[i + 2])
			local steps = math.ceil((b - a).Magnitude / 8)
			for k = 1, steps - 1 do
				local t = k / steps
				local q = (
					a * 2
					+ (b - prev) * t
					+ (prev * 2 - a * 5 + b * 4 - nxt) * t * t
					+ (-prev + a * 3 - b * 3 + nxt) * t * t * t
				) * 0.5
				table.insert(coast, q)
				table.insert(bayShore, q)
			end
		end
	end
	table.insert(bayShore, toWorld(OUTER[1]))
	local function coordinate(p: Vector2): (number, Vector2)
		local best, index, point = math.huge, 1, p
		for i = 1, #bayShore - 1 do
			local a, b = bayShore[i], bayShore[i + 1]
			local distance, q = segmentDistance(p, a, b)
			if distance < best then
				best, index, point = distance, i + (q - a).Magnitude / (b - a).Magnitude, q
			end
		end
		return index, point
	end
	local first, a = coordinate(toWorld(BEACH[1]))
	local last, b = coordinate(toWorld(BEACH[#BEACH]))
	local beach = { a }
	for i = math.ceil(first) - 1, math.floor(last) + 1, -1 do
		table.insert(beach, bayShore[i])
	end
	table.insert(beach, b)
	local beachLength = 0
	for i = 2, #beach do
		beachLength += (beach[i] - beach[i - 1]).Magnitude
	end
	return {
		coast = coast,
		bayShore = bayShore,
		beach = beach,
		beachLength = beachLength,
		center = center,
		flats = flats,
		toWorld = toWorld,
	}
end

-- Nearest point on the bay shore and the direction out over the water from it.
local function shoreAt(shape: Shape, p: Vector2): (Vector2, Vector2)
	local _, point, tangent = nearestOnLine(shape.bayShore, p)
	local normal = Vector2.new(-tangent.Y, tangent.X)
	if isInside(shape.coast, point + normal * 10) then
		normal = -normal
	end
	return point, normal
end

local function isFree(spots: { Spot }, p: Vector2, radius: number): boolean
	for _, s in spots do
		if (s.position - p).Magnitude < s.radius + radius then
			return false
		end
	end
	return true
end

local function reserve(spots: { Spot }, p: Vector2, radius: number)
	table.insert(spots, { position = p, radius = radius })
end

local function flat(shape: Shape, p: Vector2, radius: number): boolean
	for _, o in
		{
			Vector2.zero,
			Vector2.new(radius, 0),
			Vector2.new(-radius, 0),
			Vector2.new(0, radius),
			Vector2.new(0, -radius),
		}
	do
		if heightAt(shape, p + o) ~= LAND then
			return false
		end
	end
	return true
end

local function ground(p: Vector2, lift: number?): Vector3
	return Vector3.new(p.X, LAND + (lift or 0), p.Y)
end

local function facingToward(from: Vector2, to: Vector2): number
	local dir = to - from
	return math.atan2(dir.X, dir.Y)
end

----------------------------------------------------------------------------------------------------
-- Ground mesh and seabed

local function buildGround(shape: Shape, parent: Model, rng: Random)
	local groundModel = Instance.new("Model")
	groundModel.Name = "Ground"
	groundModel:SetAttribute("DrydockChannelVersion", 1)
	groundModel.Parent = parent

	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, p in shape.coast do
		minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
		minZ, maxZ = math.min(minZ, p.Y), math.max(maxZ, p.Y)
	end
	minX, minZ = minX - GROUND_MARGIN, minZ - GROUND_MARGIN
	local cols = math.ceil((maxX + GROUND_MARGIN - minX) / CELL)
	local rows = math.ceil((maxZ + GROUND_MARGIN - minZ) / CELL)

	local vertices = {}
	for i = 0, cols do
		vertices[i] = {}
		for k = 0, rows do
			local p = Vector2.new(minX + i * CELL, minZ + k * CELL)
			local h = heightAt(shape, p)
			-- Shared vertices keep every seam closed. Level village vertices stay on the
			-- grid so the merged grass slabs still meet the beach exactly.
			local amount = beachWeight(shape, p) * math.clamp((LAND - h) / 1.2, 0, 1)
			if amount > 0 then
				p += Vector2.new(
					math.clamp(math.noise(i * 1.73, k * 2.31, 11.7), -0.5, 0.5),
					math.clamp(math.noise(i * 2.17, k * 1.91, 29.3), -0.5, 0.5)
				) * CELL * 0.48 * amount
				h = heightAt(shape, p)
			end
			vertices[i][k] = Vector3.new(p.X, h, p.Y)
		end
		if i % 10 == 0 then
			task.wait()
		end
	end

	local function face(a: Vector3, b: Vector3, c: Vector3)
		local normal = (b - a):Cross(c - a).Unit
		local y = (a.Y + b.Y + c.Y) / 3
		local mid = (a + b + c) / 3
		local beach = beachWeight(shape, Vector2.new(mid.X, mid.Z))
		local color, material
		if y < LAND - 0.01 and math.abs(normal.Y) > 0.9 and beach > 0.35 then
			local wet = smoothstep((y + 0.9) / 0.9) * (1 - smoothstep(y / 1.1))
			color = BEACH_SAND:Lerp(WET_SAND, wet):Lerp(GRASS, smoothstep((y - 2.8) / 2.2))
			material = M.Sand
		elseif y < 0 then
			color, material = SAND, M.Sand
		elseif math.abs(normal.Y) < 0.72 then
			color, material = ROCK, M.Limestone
		elseif y < 2.2 then
			color, material = SAND, M.Sand
		elseif y > LAND + 6 then
			color, material = HILL, M.LeafyGrass
		else
			color, material = GRASS, M.Grass
		end
		-- Continuous, restrained sand variation avoids a checkerboard of random tiles.
		local shade = if beach > 0.1 or y < 0
			then 1 + math.noise(mid.X / 35, mid.Z / 35, 17.8) * 0.035
			else rng:NextNumber(0.94, 1.04)
		color = Color3.new(math.min(color.R * shade, 1), math.min(color.G * shade, 1), math.min(color.B * shade, 1))
		LowPoly.triangle(a, b, c, (a + b + c) / 3 - Vector3.new(0, 40, 0), color, groundModel, material)
	end

	for k = 0, rows - 1 do
		local z0 = minZ + k * CELL
		-- Flat village ground is merged into one slab per run of cells
		local runStart: number? = nil
		local function flush(endI: number)
			if runStart then
				local x0, x1 = minX + runStart * CELL, minX + endI * CELL
				Props.part(
					groundModel,
					Vector3.new(x1 - x0, 4, CELL),
					CFrame.new((x0 + x1) / 2, LAND - 2, z0 + CELL / 2),
					GRASS:Lerp(HILL, rng:NextNumber(0, 0.2)),
					M.Grass
				)
				runStart = nil
			end
		end
		for i = 0, cols - 1 do
			local a, b, c, d = vertices[i][k], vertices[i + 1][k], vertices[i][k + 1], vertices[i + 1][k + 1]
			if
				a.Y == LAND
				and b.Y == LAND
				and c.Y == LAND
				and d.Y == LAND
				and a.X == minX + i * CELL
				and a.Z == z0
				and b.X == minX + (i + 1) * CELL
				and b.Z == z0
				and c.X == minX + i * CELL
				and c.Z == z0 + CELL
				and d.X == minX + (i + 1) * CELL
				and d.Z == z0 + CELL
			then
				runStart = runStart or i
			else
				flush(i)
				if math.max(a.Y, b.Y, c.Y, d.Y) > Seabed.Floor then
					if (i + k) % 2 == 0 then
						face(a, b, c)
						face(b, d, c)
					else
						face(a, b, d)
						face(a, d, c)
					end
				end
			end
		end
		flush(cols)
		task.wait()
	end
end

----------------------------------------------------------------------------------------------------
-- Paths

local function resample(line: { Vector2 }, step: number): { Vector2 }
	local out = { line[1] }
	local carry = 0
	for i = 1, #line - 1 do
		local a, b = line[i], line[i + 1]
		local length = (b - a).Magnitude
		local t = step - carry
		while t <= length do
			table.insert(out, a:Lerp(b, t / length))
			t += step
		end
		carry = length - (t - step)
	end
	return out
end

-- Flat strip of path from `a` to `b` whose top sits `top` above the village ground, with a round
-- joint at `a` so bends join up without gaps. Overlapping pieces must never share a top height or
-- they z-fight: joints sit a step below the strips, and `raised` lets neighbouring strips alternate.
local PATH_STEP = 0.08

local function pathSegment(
	parent: Instance,
	a: Vector2,
	b: Vector2,
	width: number,
	color: Color3,
	material: Enum.Material,
	top: number,
	raised: boolean?
)
	local thickness = 0.6
	if (b - a).Magnitude > 0.5 then
		local y = top + (if raised then PATH_STEP else 0) - thickness / 2
		Props.beam(parent, ground(a, y), ground(b, y), width, color, thickness, material).CastShadow = false
	end
	local joint = Props.cylinder(parent, ground(a, top - PATH_STEP - thickness / 2), thickness, width, color, material)
	joint.CastShadow = false
end

-- True when the whole stretch from `a` to `b` stays on the island, back from the coast and out of
-- the keep-out spots, so a street can run along it.
local function roadClear(shape: Shape, keepOut: { Spot }, a: Vector2, b: Vector2): boolean
	local n = math.max(1, math.ceil((b - a).Magnitude / 6))
	for k = 0, n do
		local m = a:Lerp(b, k / n)
		if not (isInside(shape.coast, m) and coastDistance(shape, m) > 22 and isFree(keepOut, m, 4)) then
			return false
		end
	end
	return true
end

-- Street following the bay shore `offset` inland, as runs of points. It only breaks where it has to
-- (at the coast or a keep-out spot); runs too short to read as a street are left out.
local function buildRoad(
	shape: Shape,
	parent: Instance,
	name: string,
	keepOut: { Spot },
	offset: number,
	width: number,
	top: number
): { Street }
	local points: { RoadPoint } = {}
	for _, s in resample(shape.bayShore, 8) do
		-- Start straight inland from the shore, then settle onto the line that is exactly `offset`
		-- from the nearest shore point; that untangles the fold-backs at tight bends.
		local _, point, tangent = nearestOnLine(shape.bayShore, s)
		local inland = Vector2.new(-tangent.Y, tangent.X)
		if not isInside(shape.coast, point + inland * 10) then
			inland = -inland
		end
		local p = point + inland * offset
		for _ = 1, 4 do
			local _, q = nearestOnLine(shape.bayShore, p)
			p = q + (p - q).Unit * offset
		end
		local _, q = nearestOnLine(shape.bayShore, p)
		inland = (p - q).Unit

		if isInside(shape.coast, p) and coastDistance(shape, p) > 26 and isFree(keepOut, p, 4) then
			local last = points[#points]
			if not last then
				table.insert(points, { position = p, inland = inland })
			elseif (p - last.position).Magnitude >= 7 then
				local heading = if #points >= 2
					then (last.position - points[#points - 1].position).Unit
					else (p - last.position).Unit
				-- Points that land behind the previous one come from the inside of a bend; skip them
				if (p - last.position).Unit:Dot(heading) > -0.2 then
					table.insert(points, { position = p, inland = inland })
				end
			end
		end
	end

	-- Ease out the kinks left where fold-back points were skipped
	for _ = 1, 3 do
		local before = table.clone(points)
		for i = 2, #points - 1 do
			local a, b, c = before[i - 1].position, before[i].position, before[i + 1].position
			if (a - b).Magnitude < 30 and (c - b).Magnitude < 30 then
				points[i] = { position = b * 0.5 + (a + c) * 0.25, inland = before[i].inland }
			end
		end
	end

	-- Neighbours join whenever the whole stretch between them is clear, however far apart the
	-- skipped bend left them; a run only ends where the street has to stop.
	local runs: { Street } = {}
	local run: Street = {}
	for _, p in points do
		local last = run[#run]
		if
			last
			and not (
				(p.position - last.position).Magnitude < 120 and roadClear(shape, keepOut, last.position, p.position)
			)
		then
			table.insert(runs, run)
			run = {}
		end
		table.insert(run, p)
	end
	table.insert(runs, run)

	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	local streets: { Street } = {}
	for _, r in runs do
		local length = 0
		for i = 2, #r do
			length += (r[i].position - r[i - 1].position).Magnitude
		end
		if length < 40 then
			continue
		end
		table.insert(streets, r)
		for i, a in r do
			-- Square the inland direction to the street now that it has been smoothed
			local prev, nxt = r[math.max(i - 1, 1)].position, r[math.min(i + 1, #r)].position
			local normal = Vector2.new(prev.Y - nxt.Y, nxt.X - prev.X).Unit
			a.inland = if normal:Dot(a.inland) < 0 then -normal else normal

			local b = r[i + 1]
			pathSegment(
				model,
				a.position,
				if b then b.position else a.position,
				width,
				ROAD,
				M.Cobblestone,
				top,
				i % 2 == 0
			)
			-- Kerb stones along both edges of the main road
			if width >= ROAD_WIDTH and i % 3 == 0 then
				for _, side in { -1, 1 } do
					local kerb = a.position + a.inland * side * (width / 2 + 0.6)
					Props.part(model, Vector3.new(1.2, 0.8, 1.2), CFrame.new(ground(kerb, 0.3)), QUAY, M.Slate)
				end
			end
		end
	end
	return streets
end

local function nearestRoad(streets: { Street }, p: Vector2): RoadPoint
	local best, point = math.huge, streets[1][1]
	for _, street in streets do
		for _, r in street do
			local d = (r.position - p).Magnitude
			if d < best then
				best, point = d, r
			end
		end
	end
	return point
end

-- Keep houses off a laid path by reserving spots along it.
local function reservePath(spots: { Spot }, a: Vector2, b: Vector2, radius: number)
	local n = math.max(1, math.ceil((b - a).Magnitude / 6))
	for k = 0, n do
		reserve(spots, a:Lerp(b, k / n), radius)
	end
end

----------------------------------------------------------------------------------------------------
-- Beach: umbrellas and loungers on the sand, a lifeguard tower, cabanas and palms along the dunes,
-- boats hauled up at the waterline, surf foam and tide-line clutter, and boardwalks up to the road.

-- Waterline point `along` studs down the beach, and the direction inland from it.
local function beachFrame(shape: Shape, along: number): (Vector2, Vector2)
	local line = shape.beach
	local i = 1
	while i < #line - 1 and along > (line[i + 1] - line[i]).Magnitude do
		along -= (line[i + 1] - line[i]).Magnitude
		i += 1
	end
	local a, b = line[i], line[i + 1]
	local point, out = shoreAt(shape, a:Lerp(b, math.clamp(along / (b - a).Magnitude, 0, 1)))
	return point, -out
end

local function buildSurf(shape: Shape, island: Model, beach: Instance)
	-- Invisible shoreline samples drive the client's moving, soft-edged surf.
	-- No static foam geometry remains on the water when the waves fade out.
	local old = beach:FindFirstChild("Surf")
	if old then
		old:Destroy()
	end
	local surfModel = Instance.new("Model")
	surfModel.Name = "Surf"
	surfModel.Parent = beach
	local length = shape.beachLength
	local function surfaceAt(point: Vector2): Vector3
		return Islands.surface(island, point.X, point.Y) or Vector3.new(point.X, heightAt(shape, point), point.Y)
	end
	local start = BEACH_FADE * 0.65
	for along = start, length - start - 14, 14 do
		local a, inlandA = beachFrame(shape, along)
		local b, inlandB = beachFrame(shape, along + 13)
		local origin = (a + b) / 2
		local source = Instance.new("Part")
		source.Name = "ShoreWaveSource"
		source.Anchored = true
		source.Size = Vector3.new(1, 1, 1)
		source.CFrame = CFrame.new(origin.X, 0, origin.Y)
		source.Transparency = 1
		source.CanCollide = false
		source.CanTouch = false
		source.CanQuery = false
		source.CastShadow = false
		for index, sample in { { a, inlandA }, { b, inlandB } } do
			local point, inland = sample[1], sample[2]
			local surface = surfaceAt(point)
			local runup = surfaceAt(point + inland * 2.8)
			source:SetAttribute("Shore" .. index, Vector3.new(point.X - origin.X, 0, point.Y - origin.Y))
			source:SetAttribute("Inland" .. index, Vector3.new(inland.X, 0, inland.Y))
			source:SetAttribute("WaterHeight" .. index, math.max(0.16, surface.Y + 0.08))
			source:SetAttribute("RunupHeight" .. index, math.max(0.16, runup.Y + 0.08))
		end
		source:SetAttribute("Along", along)
		source:SetAttribute(
			"EdgeFade",
			smoothstep((along - start) / 24) * smoothstep((length - start - along - 13) / 24)
		)
		source.Parent = surfModel
		CollectionService:AddTag(source, "ShoreWaveSource")
	end
	surfModel:SetAttribute("ShoreWavesVersion", 1)
end

local function buildBeach(shape: Shape, island: Model, parent: Instance, spots: { Spot }, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Beach"
	model.Parent = parent
	local length = shape.beachLength
	local function sand(p: Vector2, lift: number?): Vector3
		-- Props sit on the rendered triangles, including the gently uneven dunes.
		local surface = Islands.surface(island, p.X, p.Y)
		return (surface or Vector3.new(p.X, heightAt(shape, p), p.Y)) + Vector3.new(0, lift or 0, 0)
	end
	-- Spot `depth` studs up the beach from the waterline at `along`, and the facing out to sea there
	local function spot(along: number, depth: number): (Vector2, number)
		local point, inland = beachFrame(shape, along)
		local p = point + inland * depth
		return p, facingToward(p, p - inland)
	end

	-- Keep trees and houses off the sand
	for along = BEACH_FADE * 0.6, length - BEACH_FADE * 0.6, 12 do
		local point, inland = beachFrame(shape, along)
		reserve(spots, point + inland * 28, 26)
	end
	buildSurf(shape, island, model)

	-- Landmarks along the strand, as fractions of its length
	local tower = length * 0.5
	local net = length * 0.78
	local cabanas = { length * 0.22, length * 0.36 }
	local walks = { length * 0.3, length * 0.66 }
	local function clearWalk(along: number, radius: number): boolean
		for _, walk in walks do
			if math.abs(along - walk) < radius + 2.5 then
				return false
			end
		end
		return true
	end

	local p, facing = spot(tower, 30)
	Props.lifeguardTower(model, sand(p), facing)
	p, facing = spot(net, 26)
	Props.volleyballNet(model, sand(p), facing)

	-- Umbrella pitches: an umbrella with a lounger or two beside it and maybe a towel in front
	for along = BEACH_FADE + 8, length - BEACH_FADE - 8, 22 do
		if math.abs(along - tower) < 16 or math.abs(along - net) < 18 or not clearWalk(along, 10) then
			continue
		end
		local depth = rng:NextNumber(16, 28)
		local color = pick(rng, BEACH_COLORS)
		local point, inland = beachFrame(shape, along + rng:NextNumber(-4, 4))
		local side = Vector2.new(-inland.Y, inland.X)
		local base = point + inland * depth
		local seaward = facingToward(base, base - inland)
		Props.beachUmbrella(model, sand(base), rng, color)
		for k = 1, rng:NextInteger(1, 2) do
			local s = if k == 1 then -1 else 1
			local loungerAt = base + side * s * 3.2 + inland * 1.5
			Props.sunLounger(model, sand(loungerAt), seaward + rng:NextNumber(-0.15, 0.15), pick(rng, BEACH_COLORS))
		end
		if rng:NextNumber() < 0.55 then
			local towelAt = base - inland * rng:NextNumber(6, 9) + side * rng:NextNumber(-3, 3)
			local _, normal = Islands.surface(island, towelAt.X, towelAt.Y)
			Props.towel(
				model,
				sand(towelAt, 0.08),
				seaward + rng:NextNumber(-0.5, 0.5),
				pick(rng, BEACH_COLORS),
				normal
			)
		end
	end

	-- Changing cabanas in a row at the foot of the dunes
	for _, from in cabanas do
		for k = 0, 3 do
			local at, face = spot(from + k * 8, 46)
			Props.cabana(model, sand(at, -0.3), face, BEACH_COLORS[(k % #BEACH_COLORS) + 1])
			reserve(spots, at, 5)
		end
	end

	-- Palms and dune grass along the top of the sand
	for along = BEACH_FADE, length - BEACH_FADE, 16 do
		if not clearWalk(along, 10) then
			continue
		end
		local inCabanas = false
		for _, from in cabanas do
			inCabanas = inCabanas or (along > from - 8 and along < from + 32)
		end
		local at = spot(along + rng:NextNumber(-5, 5), rng:NextNumber(48, 55))
		if not inCabanas and rng:NextNumber() < 0.7 then
			Props.palm(model, sand(at), rng)
			reserve(spots, at, 4)
		end
		local tuft = spot(along + rng:NextNumber(-8, 8), rng:NextNumber(40, 52))
		Props.bush(model, sand(tuft, -0.6), rng, DUNE_GRASS)
	end

	-- Boardwalks from the road down over the dunes onto the sand
	for _, along in walks do
		local point, inland = beachFrame(shape, along)
		local foot, top, road = point + inland * 32, point + inland * (BEACH_WIDTH + 16), point + inland * ROAD_OFFSET
		Props.beam(model, sand(foot, 0.3), sand(top, 0.3), 4.5, DECK, 0.5, M.WoodPlanks)
		Props.beam(model, ground(top, 0.3), ground(road, 0.3), 4.5, DECK, 0.5, M.WoodPlanks)
		local side = Vector2.new(-inland.Y, inland.X)
		for _, s in { -1, 1 } do
			local edge = side * s * 2.6
			Props.fence(model, sand(foot + edge + inland * 4), sand(top + edge))
		end
		reservePath(spots, top, road, 5)
	end

	-- Boats hauled up on the sand
	for _, along in { length * 0.14, length * 0.42, length * 0.58 } do
		local at, face = spot(along, rng:NextNumber(7, 10))
		Med.boat(model, sand(at, 0.4), face + rng:NextNumber(-0.4, 0.4), rng, pick(rng, BOATS))
	end
	-- Sandcastles and loose beach balls near the water
	for _, along in { length * 0.33, length * 0.7 } do
		local at = spot(along + rng:NextNumber(-6, 6), rng:NextNumber(9, 13))
		Props.sandcastle(model, sand(at), BEACH_SAND:Lerp(WET_SAND, 0.4))
	end
	for _ = 1, 3 do
		local at = spot(rng:NextNumber(BEACH_FADE + 10, length - BEACH_FADE - 10), rng:NextNumber(12, 30))
		Props.beachBall(model, sand(at))
	end

	-- Tide line: seaweed, shells and driftwood
	for _ = 1, 14 do
		local at = spot(rng:NextNumber(BEACH_FADE, length - BEACH_FADE), rng:NextNumber(1.5, 5))
		Props.seaweed(model, sand(at), rng)
	end
	for _ = 1, 12 do
		local at = spot(rng:NextNumber(BEACH_FADE, length - BEACH_FADE), rng:NextNumber(3, 14))
		Props.shells(model, sand(at), rng)
	end
	for _ = 1, 6 do
		local at = spot(rng:NextNumber(BEACH_FADE, length - BEACH_FADE), rng:NextNumber(8, 18))
		Props.driftwood(model, sand(at), rng)
	end
	BeachDetails.build(model, rng, length, function(along: number): (Vector2, Vector2)
		return beachFrame(shape, along)
	end, sand)
end

----------------------------------------------------------------------------------------------------
-- Player bases: a stone quay plot on the shore with two piers reaching into the bay

local DOCK_DETAIL_VERSION = 2

local function ensureDockAccess(base: Model, frame: CFrame)
	local existing = base:FindFirstChild("DockAccess")
	if existing and existing:GetAttribute("LayoutVersion") == 2 then
		return
	end
	if existing then
		existing:Destroy()
	end
	-- Remove only the original raised blocks on maps saved before ramps existed.
	for _, item in base:GetChildren() do
		if item:IsA("BasePart") then
			local p = frame:PointToObjectSpace(item.Position)
			if
				(item.Size - Vector3.new(7, 2.6, 3.2)).Magnitude < 0.01
				and math.abs(math.abs(p.X) - 17) < 0.01
				and math.abs(p.Y - 3.1) < 0.01
				and math.abs(p.Z - 6.4) < 0.01
			then
				item:Destroy()
			end
		end
	end
	local access = Instance.new("Model")
	access.Name = "DockAccess"
	local wood = Color3.fromRGB(133, 96, 62)
	local worn = Color3.fromRGB(158, 122, 81)
	local dark = Color3.fromRGB(77, 55, 39)
	local iron = Color3.fromRGB(52, 50, 48)
	local rope = Color3.fromRGB(176, 150, 106)
	local rise, run, thickness = 2.7, 8, 0.4
	local length = math.sqrt(run * run + rise * rise)
	local slope = CFrame.Angles(-math.atan2(rise, run), 0, 0)
	for _, side in { -1, 1 } do
		local gangway = Instance.new("Model")
		gangway.Name = if side < 0 then "LeftGangway" else "RightGangway"
		gangway.Parent = access
		local center = frame * CFrame.new(side * 17, 4.55, 4) * slope
		local function piece(
			name: string,
			size: Vector3,
			cf: CFrame,
			color: Color3,
			material: Enum.Material,
			decorative: boolean?
		): Part
			local part = Props.part(gangway, size, cf, color, material)
			part.Name = name
			if decorative then
				part.CanCollide, part.CanQuery = false, false
			end
			return part
		end
		-- A continuous collider carries players and NPCs across the narrow plank seams.
		-- Its top still meets the pier at y=3.2 and the quay at y=5.9.
		local ramp = piece(
			"DockRamp",
			Vector3.new(7, thickness, length + 0.2),
			center * CFrame.new(0, -thickness / 2, 0),
			wood,
			M.Wood
		)
		ramp.Transparency = 1
		ramp.CastShadow = false
		local count = 10
		local pitch = (length + 0.2) / count
		for i = 1, count do
			local z = (i - (count + 1) / 2) * pitch
			piece(
				"GangwayPlank",
				Vector3.new(7, thickness, pitch - 0.035),
				center * CFrame.new(0, -thickness / 2, z),
				wood:Lerp(worn, (i % 3) * 0.2),
				M.Wood,
				true
			)
		end
		for _, edge in { -1, 1 } do
			piece(
				"Stringer",
				Vector3.new(0.5, 0.8, length + 0.3),
				center * CFrame.new(edge * 3.15, -0.7, 0),
				dark,
				M.Wood,
				true
			)
			local x = side * 17 + edge * 3.9
			for _, z in { 0.4, 7.8, 10.6 } do
				local y = 3.2 + rise * math.min(z, run) / run
				piece("RailPost", Vector3.new(0.55, 3.1, 0.55), frame * CFrame.new(x, y + 1.3, z), dark, M.Wood)
				piece("PostCap", Vector3.new(0.7, 0.12, 0.7), frame * CFrame.new(x, y + 2.91, z), worn, M.Wood, true)
				piece(
					"PostCollar",
					Vector3.new(0.57, 0.18, 0.57),
					frame * CFrame.new(x, y + 0.45, z),
					iron,
					M.Metal,
					true
				)
			end
			for _, span in { { 0.4, 7.8 }, { 7.8, 10.6 } } do
				for _, rail in { { 2.65, 0.24, wood, M.Wood, "Handrail" }, { 1.35, 0.16, rope, M.Fabric, "RopeRail" } } do
					local function at(z: number): Vector3
						return frame * Vector3.new(x, 3.2 + rise * math.min(z, run) / run + rail[1], z)
					end
					local beam = Props.beam(gangway, at(span[1]), at(span[2]), rail[2], rail[3], nil, rail[4])
					beam.Name = rail[5]
					beam.CanCollide, beam.CanQuery = false, false
				end
			end
		end
		-- A short boarded apron bridges the coloured quay lip onto the base deck.
		local landing =
			piece("QuayLanding", Vector3.new(7, 0.3, 2.8), frame * CFrame.new(side * 17, 5.76, 9.4), dark, M.Wood)
		landing.Transparency = 1
		landing.CastShadow = false
		for i = 1, 4 do
			piece(
				"LandingPlank",
				Vector3.new(7, 0.3, 0.665),
				frame * CFrame.new(side * 17, 5.76, 8 + (i - 0.5) * 0.7),
				wood:Lerp(worn, (i % 3) * 0.2),
				M.Wood,
				true
			)
		end
		for _, z in { 0.6, 6.9 } do
			local y = 3.2 + rise * z / run
			piece(
				"Bearer",
				Vector3.new(8.4, 0.55, 0.65),
				frame * CFrame.new(side * 17, y - 1.05, z),
				dark,
				M.Wood,
				true
			)
		end
	end
	access:SetAttribute("LayoutVersion", 2)
	access.Parent = base
end

-- The legacy post extended through the lower half of the board and obscured both faces.
local function ensureDockSign(base: Model)
	local board = base:FindFirstChild("NameBoard")
	if not board or not board:IsA("BasePart") then
		return
	end
	for _, item in base:GetChildren() do
		if not item:IsA("BasePart") then
			continue
		end
		local legacyPost = (item.Size - Vector3.new(0.6, 6, 0.6)).Magnitude < 0.01
			and (board.CFrame:PointToObjectSpace(item.Position) - Vector3.new(0, -3, 0)).Magnitude < 0.01
		if item.Name == "DockSignPost" or legacyPost then
			item.Name = "DockSignPost"
			item.Size = Vector3.new(0.6, 4.5, 0.6)
			item.CFrame = board.CFrame * CFrame.new(0, -3.75, 0)
		end
	end
end

local function buildBaseDocks(base: Model, frame: CFrame, index: number)
	-- Cosmetic variation has its own stream, so adding joinery never moves village props.
	local rng = Random.new(82417 + index * 997)
	for _, side in { -1, 1 } do
		Props.dock(base, (frame * CFrame.new(side * 17, 0, 5)).Position, frame.LookVector, 48, rng, {
			innerSide = -side,
			junctionStart = 40,
			junctionEnd = 46.8,
		})
	end
	Props.dockLink(base, frame * CFrame.new(0, 3, -38), rng)
	ensureDockAccess(base, frame)
	base:SetAttribute("DockDetailVersion", DOCK_DETAIL_VERSION)
end

local function buildBase(
	shape: Shape,
	parent: Instance,
	index: number,
	anchor: Vector2,
	rng: Random
): (Vector2, Vector2)
	local shore, toWater = shoreAt(shape, anchor)
	local origin = Vector3.new(shore.X, 0, shore.Y)
	local forward = Vector3.new(toWater.X, 0, toWater.Y)
	local frame = CFrame.lookAt(origin, origin + forward)
	-- f: studs toward the water (negative = inland), r: studs to the right when facing the water
	local function cf(f: number, r: number, y: number): CFrame
		return frame * CFrame.new(r, y, -f)
	end
	local function at(f: number, r: number, y: number): Vector3
		return cf(f, r, y).Position
	end

	local accent = ACCENTS[(index - 1) % #ACCENTS + 1]
	local top = LAND + 0.5
	local deck = top + 0.4
	local facing = math.atan2(forward.X, forward.Z)

	local m = Instance.new("Model")
	m.Name = "Base" .. index
	m:SetAttribute("BaseId", index)
	m:SetAttribute("OwnerUserId", 0)
	m:SetAttribute("BoatDockFrame", frame)
	CollectionService:AddTag(m, Harbour.BASE_TAG)
	m.Parent = parent

	-- Stone quay with a plank deck, edged in the owner's colour
	Props.part(m, Vector3.new(58, 9, 52), cf(-34, 0, top - 4.5), QUAY, M.Cobblestone)
	Props.part(m, Vector3.new(55, 0.4, 49), cf(-34.5, 0, top + 0.2), DECK, M.WoodPlanks)
	Props.part(m, Vector3.new(58.4, 1, 1.2), cf(-8, 0, top - 0.3), accent, M.WoodPlanks)
	for _, r in { -29, 29 } do
		Props.part(m, Vector3.new(1.2, 1, 52), cf(-34, r, top - 0.3), accent, M.WoodPlanks)
	end
	-- Mooring bollards along the front
	for r = -24, 24, 12 do
		if math.abs(r) ~= 12 then
			Props.cylinder(m, at(-9, r, deck + 0.8), 1.6, 1.4, rgb(52, 50, 48), M.Metal)
		end
	end

	-- Ramps connect the quay to the two boarded piers without a jump.
	buildBaseDocks(m, frame, index)

	-- Keep the legacy prop builders' RNG draws: the beach and village share this
	-- seeded stream. BaseHouse.ensure replaces these props below, so upgrading
	-- the house does not also reshuffle the rest of the island.
	local hut = Props.fishingHut(m, at(-44, 10, deck), facing, rng, accent)
	hut.Name = "Hut"
	local pad = Props.cylinder(m, at(-26, -12, deck + 0.15), 0.3, 11, accent, M.Neon)
	pad.Name = "ClaimPad"
	-- Retain the plot reference and accent without a visible circle on the deck.
	pad.Transparency = 1
	pad.CanCollide = false
	pad.CanTouch = false
	pad.CanQuery = false
	m.PrimaryPart = pad

	-- Name board facing both ways; BaseService writes the owner's name on it
	local signPost = Props.part(m, Vector3.new(0.6, 4.5, 0.6), cf(-11, -22, deck + 2.25), rgb(78, 60, 46), M.Wood)
	signPost.Name = "DockSignPost"
	local board = Props.part(m, Vector3.new(7, 3, 0.4), cf(-11, -22, deck + 6), rgb(122, 92, 64), M.WoodPlanks)
	board.Name = "NameBoard"
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Garamond
		label.TextScaled = true
		label.TextColor3 = rgb(245, 238, 220)
		label.Text = "Base " .. index
		label.Parent = gui
		gui.Parent = board
	end

	local flagAt = at(-56, -25, deck)
	Props.flag(m, flagAt, accent)
	Props.lampPost(m, at(-10.5, 27, deck))
	Props.lampPost(m, at(-10.5, -27, deck))
	-- Festoon lights from the flagpole to the lamps, like a little fairground over the quay
	Props.stringLights(m, flagAt + Vector3.new(0, 14, 0), at(-10.5, -27, deck + 10.6), rng)
	Props.stringLights(m, at(-10.5, -27, deck + 10.6), at(-10.5, 27, deck + 10.6), rng)
	Props.crates(m, at(-15, 22, deck), rng)
	Props.barrel(m, at(-19, 25, deck), rng)
	Props.barrel(m, at(-15.5, 25.5, deck), rng)
	Props.crabPot(m, at(-21, 18, deck), rng)
	Props.crabPot(m, at(-14, -4, deck), rng)
	Props.ropeCoil(m, at(-12, 6, deck))
	Props.fishRack(m, at(-38, -21, deck), facing + math.pi / 2, rng)
	Props.bench(m, at(-30, -24, deck), facing - math.pi / 2)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnPoint"
	spawn.Anchored = true
	spawn.Size = Vector3.new(5, 0.2, 5)
	spawn.CFrame = cf(-26, 4, deck + 0.2)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = m
	Drydock.ensureDock(m)
	BaseHouse.ensure(m)

	local center = at(-34, 0, 0)
	local back = at(-62, 0, 0)
	return Vector2.new(center.X, center.Z), Vector2.new(back.X, back.Z)
end
----------------------------------------------------------------------------------------------------
-- Village

-- The piazza: a domed church and bell tower along the north side flanked by shops, a two-tier
-- fountain in the middle, a café under a pergola to the west and market stalls to the east.
-- The bay lies to the south (+Z), so the buildings face that way; the ring road crosses the south side.
local function buildPlaza(parent: Instance, center: Vector2, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Plaza"
	model.Parent = parent
	local function at(x: number, z: number, lift: number?): Vector3
		return ground(center + Vector2.new(x, z), lift)
	end
	local function slab(size: Vector3, x: number, z: number, lift: number, color: Color3, material: Enum.Material)
		Props.part(model, size, CFrame.new(at(x, z, lift)), color, material).CastShadow = false
	end
	local size = PLAZA_HALF * 2
	local pavingSize = size - 4

	-- Pale limestone laid in a grid of darker bands, edged with a kerb, with a ring round the fountain
	-- The curb owns the outside faces; paving and inlays stop at its inner edge.
	slab(Vector3.new(pavingSize, 0.6, pavingSize), 0, 0, 0.5, PAVING, M.Limestone)
	for k = -2, 2 do
		-- Each crossing belongs to the north/south band. The other band butts up
		-- against it, instead of placing two differently textured faces on one plane.
		slab(Vector3.new(1.4, 0.12, pavingSize), k * 24, 0, 0.86, PAVING_DARK, M.Cobblestone)
		local from = -PLAZA_HALF + 2
		for crossing = -2, 3 do
			local edge = if crossing == 3 then PLAZA_HALF - 2 else crossing * 24 - 0.7
			slab(Vector3.new(edge - from, 0.12, 1.4), (from + edge) / 2, k * 24, 0.86, PAVING_DARK, M.Cobblestone)
			from = edge + 1.4
		end
	end
	for _, e in { -1, 1 } do
		slab(Vector3.new(size, 0.8, 2), 0, e * (PLAZA_HALF - 1), 0.64, PAVING_DARK, M.Slate)
		slab(Vector3.new(2, 0.8, size - 4), e * (PLAZA_HALF - 1), 0, 0.64, PAVING_DARK, M.Slate)
	end
	model:SetAttribute("PlazaPavingVersion", 2)
	Props.cylinder(model, at(0, 0, 0.7), 0.7, 40, PAVING_DARK, M.Cobblestone).CastShadow = false
	Props.cylinder(model, at(0, 0, 0.8), 0.7, 36, PAVING, M.Limestone).CastShadow = false
	Med.fountain(model, at(0, 0, 1.15))
	for _, offset in { Vector2.new(0, -16.5), Vector2.new(0, 16.5), Vector2.new(-16.5, 0), Vector2.new(16.5, 0) } do
		Med.pot(model, at(offset.X, offset.Y, 0.95), rng, "flowers")
	end
	for _, offset in { Vector2.new(-14, -14), Vector2.new(14, -14), Vector2.new(14, 14), Vector2.new(-14, 14) } do
		local p = center + offset
		Props.bench(model, ground(p, 0.95), facingToward(p, center))
	end

	-- North side: church, campanile and two shops, all facing the fountain
	Med.chapel(model, at(0, -40, 0.8), 0, rng, 1.5)
	Med.bellTower(model, at(-19, -47, 0.8), 0, rng)
	for _, x in { -42, 42 } do
		Med.townhouse(model, at(x, -47, 0.8), 0, rng, true)
	end
	for _, x in { -14, 14 } do
		Med.cypress(model, at(x, -24, 0.8), rng, rng:NextNumber(19, 23))
	end

	-- West: café tables under a vine-covered pergola, and a few more out in the sun
	Med.pergola(model, at(-42, -4, 0.8), 0, rng, 18, 22)
	for _, offset in { Vector2.new(-46.5, -9), Vector2.new(-37.5, -9), Vector2.new(-46.5, 2), Vector2.new(-37.5, 2) } do
		Med.cafeTable(model, at(offset.X, offset.Y, 0.8), rng)
	end
	local parasols = { rgb(36, 92, 168), rgb(180, 52, 44), rgb(56, 120, 70) }
	for i, offset in { Vector2.new(-25, -11), Vector2.new(-26, 9), Vector2.new(-24, 30) } do
		Med.cafeTable(model, at(offset.X, offset.Y, 0.8), rng, parasols[i])
	end
	for _, z in { -17, 9 } do
		Med.pot(model, at(-53, z, 0.8), rng, "lemon")
	end

	-- East: a row of market stalls facing across the square
	local canopies = { rgb(180, 52, 44), rgb(36, 92, 168), rgb(56, 120, 70), rgb(214, 160, 50) }
	for i, z in { -18, -6, 6, 18 } do
		local p = center + Vector2.new(44, z)
		Props.stall(model, ground(p, 0.8), facingToward(p, Vector2.new(center.X, p.Y)), rng, canopies[i])
		if i % 2 == 0 then
			Props.barrel(model, ground(p + Vector2.new(8, 3), 0.8), rng)
		end
	end

	-- South: a promenade of palms, benches looking out over the bay, and olive planters
	for _, x in { -34, -10, 10, 34 } do
		Props.palm(model, at(x, 52, 0.8), rng)
	end
	for _, x in { -22, 0, 22 } do
		Props.bench(model, at(x, 54, 0.8), 0)
	end
	for _, x in { -46, 46 } do
		Med.planter(model, at(x, 51, 0.8), rng, "olive")
	end

	-- Lamps round the edge with festoons strung between them and across the square
	local lamps = {}
	for _, x in { -56, 56 } do
		for _, z in { -18, 22, 56 } do
			Props.lampPost(model, at(x, z, 0.8))
			lamps[`{x},{z}`] = at(x, z, 12.4)
		end
	end
	local function festoon(a: string, b: string, sag: number?)
		Props.stringLights(model, lamps[a], lamps[b], rng, sag)
	end
	festoon("-56,-18", "-56,22")
	festoon("-56,22", "-56,56")
	festoon("56,-18", "56,22")
	festoon("56,22", "56,56")
	festoon("-56,56", "56,56", 3)
	festoon("-56,-18", "56,-18", 2)
	festoon("-56,22", "56,22", 2)
	Drydock.build(model, CFrame.new(at(0, 0, 0.8)))
	RodShop.build(model, CFrame.new(at(0, 0, 0.8)))
	FurnitureShop.build(model, CFrame.new(at(0, 0, 0.8)))
	BackpackShop.build(model, CFrame.new(at(0, 0, 0.8)))
end

local HOUSE_HALF = { cube = 14, town = 10, villa = 15, green = 9 } -- half the frontage along the street
local HOUSE_FRONT = { cube = 10, town = 9, villa = 16, green = 4 } -- how far the doorstep sits from the middle
local RING_KINDS = { { "cube", 0.4 }, { "town", 0.35 }, { "villa", 0.15 }, { "green", 0.1 } }
local LANE_KINDS = { { "cube", 0.5 }, { "town", 0.42 }, { "green", 0.08 } }

local function rollKind(kinds: { { any } }, rng: Random): string
	local roll = rng:NextNumber()
	for _, k in kinds do
		roll -= k[2]
		if roll <= 0 then
			return k[1]
		end
	end
	return kinds[#kinds][1]
end

-- Points every `step` studs along a street, each with the direction away from the bay.
local function streetFrames(street: Street, step: number): { RoadPoint }
	local frames = {}
	for i = 1, #street - 1 do
		local a, b = street[i], street[i + 1]
		local n = math.max(1, math.floor((b.position - a.position).Magnitude / step))
		for k = 0, n - 1 do
			local t = k / n
			table.insert(
				frames,
				{ position = a.position:Lerp(b.position, t), inland = a.inland:Lerp(b.inland, t).Unit }
			)
		end
	end
	return frames
end

-- One house (or a little green) at `p` with its front to the street at `toward`, and a bit of
-- life round the doorstep and sometimes a walled yard out back.
local function placeHouse(
	shape: Shape,
	model: Instance,
	kind: string,
	p: Vector2,
	toward: Vector2,
	lane: boolean,
	spots: { Spot },
	rng: Random
)
	local half = HOUSE_HALF[kind]
	local toStreet = (toward - p).Unit
	local across = Vector2.new(-toStreet.Y, toStreet.X)
	local facing = facingToward(p, toward) + rng:NextNumber(-0.04, 0.04)
	reserve(spots, p, 10)
	for _, s in { -1, 1 } do
		reserve(spots, p + across * s * (half - 5), 6)
	end

	if kind == "green" then
		if lane and rng:NextNumber() < 0.5 then
			Med.vineyard(model, ground(p), facing, rng, 16, 14)
		else
			-- A small olive green between houses
			Med.olive(model, ground(p - toStreet * 2), rng)
			Props.bench(model, ground(p + toStreet * 4), facing)
			Med.lavender(model, ground(p + across * 5), rng)
			Med.lavender(model, ground(p - across * 5), rng)
		end
		return
	end
	if kind == "cube" then
		Med.cubeHouse(model, ground(p), facing, rng)
	elseif kind == "town" then
		Med.townhouse(model, ground(p), facing, rng)
	else
		Med.villa(model, ground(p), facing, rng)
		return
	end

	local front = p + toStreet * (HOUSE_FRONT[kind] + 1)
	local extra = rng:NextNumber()
	if extra < 0.25 then
		Med.pot(model, ground(front + across * 6), rng)
		Med.pot(model, ground(front + across * 7.6), rng)
	elseif extra < 0.4 then
		Props.bench(model, ground(front - across * 6), facing)
	elseif extra < 0.5 and not lane then
		Med.cafeTable(model, ground(front + across * 7), rng)
	end
	if rng:NextNumber() < 0.35 then
		-- Walled yard out back with an olive or a lemon tree
		local yard = p - toStreet * 16
		if flat(shape, yard, 7) and isFree(spots, yard, 6) then
			reserve(spots, yard, 6)
			local corners = {
				yard + across * 7 + toStreet * 4,
				yard + across * 7 - toStreet * 4,
				yard - across * 7 - toStreet * 4,
				yard - across * 7 + toStreet * 4,
			}
			for c = 1, 3 do
				Med.stoneWall(model, ground(corners[c]), ground(corners[c + 1]), rng)
			end
			Props.part(
				model,
				Vector3.new(13, 0.4, 7),
				CFrame.new(ground(yard, 0.1)) * CFrame.Angles(0, facing, 0),
				DIRT,
				M.Ground
			)
			if rng:NextNumber() < 0.5 then
				Med.olive(model, ground(yard + across * 3), rng, 0.8)
			else
				Med.pot(model, ground(yard + across * 3), rng, "lemon")
			end
			Med.lavender(model, ground(yard - across * 3), rng)
		end
	end
end

-- A terrace of houses shoulder to shoulder along one side of a street (`side` 1 is away from the
-- bay), every door facing it. Each slot slides along until its house fits, so the row stays tight.
local function lineStreet(
	shape: Shape,
	model: Instance,
	street: Street,
	side: number,
	width: number,
	kinds: { { any } },
	spots: { Spot },
	rng: Random
)
	local last: Vector2?, lastHalf = nil, 0
	local kind = rollKind(kinds, rng)
	local gap = if kind == "town" then 0.6 else rng:NextNumber(1.5, 3.5)
	for n, f in streetFrames(street, 3) do
		local half = HOUSE_HALF[kind]
		local p = f.position + f.inland * side * (width / 2 + HOUSE_FRONT[kind] + 2)
		if last and (p - last).Magnitude < lastHalf + half + gap then
			continue
		end
		if
			isInside(shape.coast, p)
			and coastDistance(shape, p) > 30
			and flat(shape, p, half - 2)
			and isFree(spots, p, 9)
		then
			placeHouse(shape, model, kind, p, f.position, width < ROAD_WIDTH, spots, rng)
			last, lastHalf = p, half
		end
		-- Whether it fitted or not, the next slot gets a fresh roll so a big house can't stall a row
		kind = rollKind(kinds, rng)
		gap = if kind == "town" then 0.6 else rng:NextNumber(1.5, 3.5)
		if n % 40 == 0 then
			task.wait()
		end
	end
end

local function buildHouses(
	shape: Shape,
	parent: Instance,
	road: { Street },
	lanes: { Street },
	spots: { Spot },
	rng: Random
)
	local model = Instance.new("Model")
	model.Name = "Houses"
	model.Parent = parent

	-- Lamps go in first so the houses leave room for them
	local lamps = {}
	for _, street in road do
		for i, r in street do
			if i % 5 == 1 then
				local side = if i % 10 == 1 then 1 else -1
				local lampAt = r.position + r.inland * side * (ROAD_WIDTH / 2 + 1)
				Props.lampPost(model, ground(lampAt))
				reserve(spots, lampAt, 0.5)
				table.insert(lamps, ground(lampAt))
			end
		end
	end
	-- Bulbs strung across the road between some of the lamps
	for i = 1, #lamps - 1, 2 do
		local a, b = lamps[i], lamps[i + 1]
		if (a - b).Magnitude < 70 then
			Props.stringLights(model, a + Vector3.new(0, 10.6, 0), b + Vector3.new(0, 10.6, 0), rng)
		end
	end

	-- Both sides of the ring road, then the far side of each back lane; the near side of a lane is
	-- the backs of the ring road's inland row.
	for _, street in road do
		for _, side in { -1, 1 } do
			lineStreet(shape, model, street, side, ROAD_WIDTH, RING_KINDS, spots, rng)
		end
	end
	for _, street in lanes do
		lineStreet(shape, model, street, 1, LANE_WIDTH, LANE_KINDS, spots, rng)
	end
end

-- Windmills along the ridges above the village and a chapel on a hilltop, turned toward the bay
-- so they show from the water.
local function buildHilltops(shape: Shape, island: Model, spots: { Spot }, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Hilltops"
	model.Parent = island
	local coast = shape.coast

	local candidates = {}
	for _ = 1, 500 do
		local p = coast[rng:NextInteger(1, #coast)]:Lerp(shape.center, rng:NextNumber(0.05, 0.5))
		if
			isInside(coast, p)
			and coastDistance(shape, p) > 40
			and (nearestOnLine(shape.bayShore, p)) > VILLAGE_BAND + 60
		then
			local spot, normal = Islands.surface(island, p.X, p.Y)
			if spot and normal and normal.Y > 0.95 then
				table.insert(candidates, spot)
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.Y > b.Y
	end)

	local built = 0
	for _, spot in candidates do
		local p = Vector2.new(spot.X, spot.Z)
		if isFree(spots, p, 70) then
			reserve(spots, p, 18)
			local facing = facingToward(p, shape.center)
			if built == 1 then
				Props.part(
					model,
					Vector3.new(24, 10, 26),
					CFrame.new(spot - Vector3.new(0, 5.5, 0)) * CFrame.Angles(0, facing, 0),
					ROCK,
					M.Limestone
				)
				Med.chapel(model, spot - Vector3.new(0, 0.8, 0), facing, rng)
				local side = Vector3.new(math.cos(facing), 0, -math.sin(facing))
				for _, s in { -1, 1 } do
					Med.cypress(model, spot + side * s * 13 - Vector3.new(0, 0.5, 0), rng)
				end
			else
				Props.cylinder(model, spot - Vector3.new(0, 4, 0), 8, 22, ROCK, M.Limestone)
				Med.windmill(model, spot - Vector3.new(0, 0.5, 0), facing, rng)
			end
			built += 1
			if built >= 4 then
				break
			end
		end
	end
end

local function buildForest(shape: Shape, island: Model, spots: { Spot }, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Forest"
	model.Parent = island
	local placed = 0
	local coast = shape.coast
	for attempt = 1, 2600 do
		if placed >= 420 then
			break
		end
		local p = coast[rng:NextInteger(1, #coast)]:Lerp(shape.center, rng:NextNumber(0, 1))
			+ Vector2.new(rng:NextNumber(-100, 100), rng:NextNumber(-100, 100))
		if isInside(coast, p) and coastDistance(shape, p) > 8 and isFree(spots, p, 6) then
			local spot, normal = Islands.surface(island, p.X, p.Y)
			if spot and normal and normal.Y > 0.75 and spot.Y > 2 then
				reserve(spots, p, 5)
				local roll = rng:NextNumber()
				if spot.Y > LAND + 3 then
					-- Hills: umbrella pines and cypresses over maquis scrub
					if roll < 0.3 then
						Med.stonePine(model, spot, rng)
					elseif roll < 0.5 then
						Med.cypress(model, spot, rng)
					elseif roll < 0.65 then
						Med.olive(model, spot, rng)
					elseif roll < 0.9 then
						Props.bush(model, spot, rng, MAQUIS)
					else
						Med.lavender(model, spot, rng)
					end
				elseif roll < 0.35 then
					Med.olive(model, spot, rng)
				elseif roll < 0.5 then
					Med.cypress(model, spot, rng)
				elseif roll < 0.6 then
					Props.palm(model, spot, rng)
				elseif roll < 0.8 then
					Props.bush(model, spot, rng, MAQUIS)
				elseif roll < 0.9 then
					Med.lavender(model, spot, rng)
				else
					Props.flowers(model, spot, rng)
				end
				placed += 1
			end
		end
		if attempt % 100 == 0 then
			task.wait()
		end
	end
	-- Pale limestone rocks on the rocky coast; keep the bathing beach and its
	-- waterline clear, including a margin for the largest boulder's footprint.
	for _ = 1, 100 do
		local p = coast[rng:NextInteger(1, #coast)]
		local q = p:Lerp(coast[rng:NextInteger(1, #coast)], rng:NextNumber(0, 0.03))
		local spot = Islands.surface(island, q.X + rng:NextNumber(-14, 14), q.Y + rng:NextNumber(-14, 14))
		if
			spot
			and spot.Y > -3
			and nearestOnLine(shape.beach, Vector2.new(spot.X, spot.Z)) > BEACH_WIDTH + 24
			and isFree(spots, Vector2.new(spot.X, spot.Z), 4)
		then
			Props.boulder(model, spot, rng, rng:NextNumber(3, 8), ROCK, M.Limestone)
		end
	end
end

-- Painted fishing boats riding at anchor around the bay, clear of the base piers.
local function buildBoats(shape: Shape, island: Model, rng: Random, avoid: { Vector2 })
	local model = Instance.new("Model")
	model.Name = "Boats"
	model.Parent = island
	local line = shape.bayShore
	local placed: { Vector2 } = {}
	for _ = 1, 80 do
		if #placed >= 10 then
			break
		end
		local k = rng:NextInteger(1, #line - 1)
		local point, out = shoreAt(shape, line[k]:Lerp(line[k + 1], rng:NextNumber()))
		local p = point + out * rng:NextNumber(28, 90)
		local clear = coastDistance(shape, p) < -16
		for _, a in avoid do
			clear = clear and (a - p).Magnitude > 80
		end
		for _, b in placed do
			clear = clear and (b - p).Magnitude > 30
		end
		if clear then
			table.insert(placed, p)
			Med.boat(model, Vector3.new(p.X, 0, p.Y), rng:NextNumber(0, TAU), rng, pick(rng, BOATS))
		end
	end
end

----------------------------------------------------------------------------------------------------

-- Also available to charts of places baked before coast metadata was saved.
function Harbour.chartCoast(center: Vector2): { { number } }
	local coast = {}
	for _, point in makeShape(center).coast do
		table.insert(coast, { point.X, point.Y })
	end
	return coast
end

function Harbour.build(parent: Instance, rng: Random, center: Vector2): CFrame
	local island = Instance.new("Model")
	island.Name = "Harbour Isle"
	island.Parent = parent

	local shape = makeShape(center)
	local coast = {}
	for _, point in shape.coast do
		table.insert(coast, { point.X, point.Y })
	end
	island:SetAttribute("ChartCoast", game:GetService("HttpService"):JSONEncode(coast))
	buildGround(shape, island, rng)

	local village = Instance.new("Model")
	village.Name = "Village"
	village.Parent = island
	local spots: { Spot } = {}

	-- Landmarks first so the road and houses keep clear of them
	local plaza = shape.toWorld(PLAZA)
	reserve(spots, plaza, PLAZA_HALF * 1.42)
	reserve(spots, plaza + Vector2.new(0, 82), 31)
	-- Keep shore clutter clear of the rear repair basin and its water approach.
	reservePath(spots, plaza + Vector2.new(0, 104), plaza + Vector2.new(0, 198), 23)
	local lighthouse = shape.toWorld(LIGHTHOUSE)
	reserve(spots, lighthouse, 34)

	local bases = Instance.new("Folder")
	bases.Name = "Bases"
	bases.Parent = island
	local baseBacks, baseShores = {}, {}
	for index, anchor in BASES do
		local world = shape.toWorld(anchor)
		local middle, back = buildBase(shape, bases, index, world, rng)
		reserve(spots, middle, 36)
		table.insert(baseBacks, back)
		table.insert(baseShores, (shoreAt(shape, world)))
		task.wait()
	end
	buildBeach(shape, island, village, spots, rng)

	-- The road gives way to the piazza's paving where it crosses the square
	local keepOut = {
		{ position = lighthouse, radius = 26 },
		{ position = plaza, radius = PLAZA_HALF + 2 },
	}
	local road = buildRoad(shape, village, "Road", keepOut, ROAD_OFFSET, ROAD_WIDTH, 0.6)
	for _, street in road do
		for i = 2, #street do
			reservePath(spots, street[i - 1].position, street[i].position, ROAD_WIDTH / 2 + 1)
		end
	end

	-- A back lane behind the first row of houses gives the second row a street of its own to face;
	-- cross streets tie it to the ring road at each end and every block or so in between.
	local lanes = buildRoad(shape, village, "Lane", keepOut, ROAD_OFFSET + LANE_OFFSET, LANE_WIDTH, 0.45)
	local crossStreets = Instance.new("Model")
	crossStreets.Name = "CrossStreets"
	crossStreets.Parent = village
	for _, street in lanes do
		for i, r in street do
			if i > 1 then
				reservePath(spots, street[i - 1].position, r.position, LANE_WIDTH / 2 + 0.5)
			end
			if (i - 1) % 12 == 0 or i == #street then
				local joint = nearestRoad(road, r.position)
				local reach = (joint.position - r.position).Magnitude
				if reach < LANE_OFFSET + 25 and roadClear(shape, keepOut, joint.position, r.position) then
					pathSegment(crossStreets, r.position, joint.position, LANE_WIDTH, ROAD, M.Cobblestone, 0.3)
					reservePath(spots, r.position, joint.position, LANE_WIDTH / 2 + 5)
				end
			end
		end
	end

	-- Dirt tracks from each base and the lighthouse up to the road, with signposts at the junctions
	for i, back in baseBacks do
		local joint = nearestRoad(road, back)
		pathSegment(village, back, joint.position, 9, DIRT, M.Pebble, 0.4)
		reservePath(spots, back, joint.position, 11)
		local signAt = joint.position - joint.inland * (ROAD_WIDTH / 2 + 2)
		local side = Vector2.new(-joint.inland.Y, joint.inland.X)
		Props.signpost(
			village,
			ground(signAt + side * 7),
			facingToward(signAt, back) - math.pi / 2,
			{ { "Base " .. i, 0 } }
		)
		reserve(spots, signAt + side * 7, 2)
	end
	local toLighthouse = nearestRoad(road, lighthouse)
	local lighthouseGate = lighthouse + (toLighthouse.position - lighthouse).Unit * 17
	pathSegment(village, lighthouseGate, toLighthouse.position, 9, DIRT, M.Pebble, 0.4)
	reservePath(spots, lighthouseGate, toLighthouse.position, 11)

	buildPlaza(village, plaza, rng)
	local plazaRoad = nearestRoad(road, plaza)
	Props.signpost(
		village,
		ground(plazaRoad.position + plazaRoad.inland * -(ROAD_WIDTH / 2 + 3), 0.6),
		facingToward(plazaRoad.position, plaza) - math.pi / 2,
		{ { "Plaza", 0 }, { "Lighthouse", math.pi } }
	)

	Props.lighthouse(village, ground(lighthouse))
	local cottage = lighthouse + Vector2.new(36, 4)
	if flat(shape, cottage, 12) and isFree(spots, cottage, 14) then
		Med.cubeHouse(village, ground(cottage), facingToward(cottage, lighthouse), rng)
		reserve(spots, cottage, 16)
	end

	buildHouses(shape, village, road, lanes, spots, rng)
	buildHilltops(shape, island, spots, rng)
	buildForest(shape, island, spots, rng)
	-- The piazza's own terraces go in last, clearing any generated house or tree off their plots
	PlazaHouses.build(village:FindFirstChild("Plaza") :: Model, CFrame.new(ground(plaza, 0.8)))
	buildBoats(shape, island, rng, baseShores)
	Harbour.ensureBaseOneBoatClearance(island)
	Harbour.ensureLaunchClearance(island)

	-- Buoys marking the way into the bay
	local mouthA, mouthB = shape.toWorld(OUTER[1]), shape.toWorld(OUTER[#OUTER])
	for _, t in { 0.25, 0.75 } do
		for _, out in { 40, 190 } do
			local p = mouthA:Lerp(mouthB, t) + Vector2.new(-out, 0)
			Props.buoy(island, Vector3.new(p.X, 0, p.Y), rng)
		end
	end

	return CFrame.new(ground(plaza + Vector2.new(0, 34), 3.5))
end

-- Upgrade only the generated dock pieces, keeping claimed bases and their controls intact.
-- Saved Studio maps skip Map.build, so this also runs on the normal startup path.
function Harbour.ensureDocks(root: Instance)
	for _, base in root:GetDescendants() do
		if not base:IsA("Model") or not CollectionService:HasTag(base, Harbour.BASE_TAG) then
			continue
		end
		ensureDockSign(base)
		local frame = base:GetAttribute("BoatDockFrame")
		if typeof(frame) ~= "CFrame" then
			local spawn = base:FindFirstChild("SpawnPoint")
			if not spawn or not spawn:IsA("BasePart") then
				continue
			end
			frame = spawn.CFrame * CFrame.new(-4, -6.1, -26)
			base:SetAttribute("BoatDockFrame", frame)
		end
		ensureDockAccess(base, frame)
		if base:GetAttribute("DockDetailVersion") == DOCK_DETAIL_VERSION then
			continue
		end
		for _, item in base:GetChildren() do
			if item:IsA("Model") and (item.Name == "Dock" or item.Name == "DockLink") then
				item:Destroy()
			elseif item:IsA("BasePart") then
				-- The legacy crosswalk and its three anonymous piles are direct base children.
				local p = frame:PointToObjectSpace(item.Position)
				local slab = (item.Size - Vector3.new(27, 0.6, 5)).Magnitude < 0.01
					and (p - Vector3.new(0, 3, -38)).Magnitude < 0.01
				local pile = (item.Size - Vector3.new(0.9, 18, 0.9)).Magnitude < 0.01
					and math.abs(p.Y + 6.4) < 0.01
					and math.abs(p.Z + 38) < 0.01
					and (math.abs(p.X) < 0.01 or math.abs(math.abs(p.X) - 8) < 0.01)
				if slab or pile then
					item:Destroy()
				end
			end
		end
		buildBaseDocks(base, frame, base:GetAttribute("BaseId") or 1)
	end
end

-- Remove the red scenery boat and the remaining boat in front of base 1,
-- including on baked maps. Each removal has its own saved migration marker.
-- Run after generation so the shared RNG and all other scenery stay in place.
function Harbour.ensureBaseOneBoatClearance(root: Instance)
	local islands = root:GetDescendants()
	table.insert(islands, root)
	for _, island in islands do
		if island.Name ~= "Harbour Isle" then
			continue
		end
		local bases = island:FindFirstChild("Bases")
		local base = bases and bases:FindFirstChild("Base1")
		local frame = base and base:GetAttribute("BoatDockFrame")
		local boats = island:FindFirstChild("Boats")
		if typeof(frame) ~= "CFrame" or not boats then
			continue
		end
		for _, marker in { "BaseOneRedBoatRemoved", "BaseOneFrontBoatRemoved" } do
			if island:GetAttribute(marker) then
				continue
			end
			local nearest: Model? = nil
			local distance = 220
			for _, boat in boats:GetChildren() do
				if not boat:IsA("Model") or boat.Name ~= "Boat" then
					continue
				end
				local floor = boat:FindFirstChild("BoatFloor")
				local red = false
				for _, piece in boat:GetChildren() do
					if piece:IsA("BasePart") then
						red = red or piece.Color == BOATS[2]
						-- Legacy baked boats have an unnamed floor.
						if
							not floor
							and math.abs(piece.Size.Y - 0.4) < 0.001
							and piece.Size.X >= 4.6
							and piece.Size.X <= 5.6
						then
							floor = piece
						end
					end
				end
				if (marker == "BaseOneFrontBoatRemoved" or red) and floor and floor:IsA("BasePart") then
					local position = frame:PointToObjectSpace(floor.Position)
					local separation = Vector2.new(position.X, position.Z).Magnitude
					if position.Z < 0 and separation < distance then
						nearest, distance = boat, separation
					end
				end
			end
			if nearest then
				nearest:Destroy()
				island:SetAttribute(marker, true)
			end
		end
	end
end

-- Add the boat shop and launch points to a map already baked in Studio.
-- Move anchored scenery aside so the slipway and its water approach stay open.
function Harbour.ensureLaunchClearance(root: Instance)
	for _, shop in root:GetDescendants() do
		if not shop:IsA("Model") or shop.Name ~= "Drydock" then
			continue
		end
		local launch = shop:GetAttribute("LaunchWaterFrame")
		if typeof(launch) ~= "CFrame" then
			continue
		end
		for _, boat in root:GetDescendants() do
			if not boat:IsA("Model") or boat.Name ~= "Boat" then
				continue
			end
			local floor = boat:FindFirstChild("BoatFloor")
			if not floor then
				for _, piece in boat:GetChildren() do
					if piece:IsA("BasePart") then
						floor = piece
						break
					end
				end
			end
			if not floor or not floor:IsA("BasePart") then
				continue
			end
			local position = launch:PointToObjectSpace(floor.Position)
			if math.abs(position.X) < 45 and position.Z > -70 and position.Z < 55 then
				local side = if position.X < 0 then -1 else 1
				local offset = launch:VectorToWorldSpace(Vector3.new(side * 65 - position.X, 0, 0))
				for _, piece in boat:GetDescendants() do
					if piece:IsA("BasePart") then
						piece.CFrame += offset
					end
				end
			end
		end
	end
end

function Harbour.ensureBoating(root: Instance)
	for _, island in root:GetDescendants() do
		if island:IsA("Model") and island.Name == "Harbour Isle" then
			local groundMesh = island:FindFirstChild("Ground")
			local shop = island:FindFirstChild("Drydock", true)
			local footprint = shop and shop:FindFirstChild("ShopFootprint")
			if groundMesh and groundMesh:GetAttribute("DrydockChannelVersion") ~= 1 and footprint then
				local plaza = Vector2.new(footprint.Position.X, footprint.Position.Z - 82)
				local center = plaza - makeShape(Vector2.new(0, 0)).toWorld(PLAZA)
				groundMesh:Destroy()
				buildGround(makeShape(center), island, Random.new(0))
			end
		end
	end
	Harbour.ensureDocks(root)
	Harbour.ensureBaseOneBoatClearance(root)
	Drydock.ensure(root)
	Harbour.ensureLaunchClearance(root)
end

-- Saved maps also receive the enterable tackle shop, its purchase counter and the furniture shop.
function Harbour.ensureFishing(root: Instance)
	RodShop.ensure(root)
	FurnitureShop.ensure(root)
	BackpackShop.ensure(root)

	PlazaHouses.ensure(root)
end

-- Saved maps keep their terrain and docks while receiving the current base house.
function Harbour.ensureBases(root: Instance)
	for _, item in root:GetDescendants() do
		if item:IsA("Model") and CollectionService:HasTag(item, Harbour.BASE_TAG) then
			BaseHouse.ensure(item)
		end
	end
end

-- Saved beaches receive moving surf without rebuilding their terrain or decorations.
function Harbour.ensureSurf(root: Instance, center: Vector2)
	for _, island in root:GetDescendants() do
		if not island:IsA("Model") or island.Name ~= "Harbour Isle" then
			continue
		end
		local village = island:FindFirstChild("Village")
		local beach = village and village:FindFirstChild("Beach")
		if beach then
			local surf = beach:FindFirstChild("Surf")
			if not surf or surf:GetAttribute("ShoreWavesVersion") ~= 1 then
				buildSurf(makeShape(center), island, beach)
			end
		end
	end
end

-- Trim legacy paving in place, preserving every plaza prop and its placement.
function Harbour.ensurePlazaPaving(root: Instance)
	for _, plaza in root:GetDescendants() do
		if not plaza:IsA("Model") or plaza.Name ~= "Plaza" or plaza:GetAttribute("PlazaPavingVersion") == 2 then
			continue
		end
		local size = PLAZA_HALF * 2
		local floor: BasePart? = nil
		for _, child in plaza:GetChildren() do
			if child:IsA("Part") and (child.Size - Vector3.new(size, 0.6, size)).Magnitude < 0.001 then
				floor = child
				break
			end
		end
		if not floor then
			continue
		end
		local center = floor.Position
		local half = PLAZA_HALF - 2
		floor.Size = Vector3.new(half * 2, floor.Size.Y, half * 2)
		for _, child in plaza:GetChildren() do
			if not child:IsA("Part") or child.Material ~= M.Cobblestone or math.abs(child.Size.Y - 0.12) > 0.001 then
				continue
			end
			local p, s = child.Position, child.Size
			local minX, maxX = math.max(p.X - s.X / 2, center.X - half), math.min(p.X + s.X / 2, center.X + half)
			local minZ, maxZ = math.max(p.Z - s.Z / 2, center.Z - half), math.min(p.Z + s.Z / 2, center.Z + half)
			child.Size = Vector3.new(maxX - minX, s.Y, maxZ - minZ)
			child.CFrame = CFrame.new((minX + maxX) / 2, p.Y, (minZ + maxZ) / 2)
		end
		plaza:SetAttribute("PlazaPavingVersion", 2)
	end
end
return {}
end
local Harbour = loadHarbour()
local shape = Harbour.makeShape(Biomes.Normal.center)
dependencies.Islands.surface = function(_, x, z)
	return Vector3.new(x, Harbour.heightAt(shape, Vector2.new(x, z)), z), Vector3.yAxis
end

local checks, failures = 0, 0
local function check(condition, message)
	checks += 1
	if not condition then
		failures += 1
		if failures < 30 then
			print("FAIL: " .. message)
		end
	end
end
local EPS = 1e-5
local worldCorners, worldBounds = {}, {}
local function corners(part, reference)
	if not reference and worldCorners[part] then
		return worldCorners[part]
	end
	local result = {}
	for _, x in { -0.5, 0.5 } do
		for _, y in { -0.5, 0.5 } do
			for _, z in { -0.5, 0.5 } do
				local p = part.CFrame * Vector3.new(part.Size.X * x, part.Size.Y * y, part.Size.Z * z)
				table.insert(result, if reference then reference:PointToObjectSpace(p) else p)
			end
		end
	end
	if not reference then
		worldCorners[part] = result
	end
	return result
end
local function bounds(part, reference)
	if not reference and worldBounds[part] then
		return table.unpack(worldBounds[part])
	end
	local low, high = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in corners(part, reference) do
		low = Vector3.new(math.min(low.X, p.X), math.min(low.Y, p.Y), math.min(low.Z, p.Z))
		high = Vector3.new(math.max(high.X, p.X), math.max(high.Y, p.Y), math.max(high.Z, p.Z))
	end
	if not reference then
		worldBounds[part] = { low, high }
	end
	return low, high
end
local function overlaps(a, b)
	local al, ah = bounds(a)
	local bl, bh = bounds(b)
	if
		ah.X <= bl.X + EPS
		or bh.X <= al.X + EPS
		or ah.Y <= bl.Y + EPS
		or bh.Y <= al.Y + EPS
		or ah.Z <= bl.Z + EPS
		or bh.Z <= al.Z + EPS
	then
		return false
	end
	local axes = {
		a.CFrame.RightVector,
		a.CFrame.UpVector,
		a.CFrame.ZVector,
		b.CFrame.RightVector,
		b.CFrame.UpVector,
		b.CFrame.ZVector,
	}
	for i = 1, 3 do
		for k = 4, 6 do
			table.insert(axes, axes[i]:Cross(axes[k]))
		end
	end
	for _, axis in axes do
		if axis.Magnitude < EPS then
			continue
		end
		local aMin, aMax, bMin, bMax = math.huge, -math.huge, math.huge, -math.huge
		for _, p in corners(a) do
			aMin, aMax = math.min(aMin, p:Dot(axis)), math.max(aMax, p:Dot(axis))
		end
		for _, p in corners(b) do
			bMin, bMax = math.min(bMin, p:Dot(axis)), math.max(bMax, p:Dot(axis))
		end
		if aMax <= bMin + EPS or bMax <= aMin + EPS then
			return false
		end
	end
	return true
end

-- Audit the actual dock builders in each base's rotated frame. These checks
-- cover useful walking space as well as the cosmetic structure, so a richer
-- rail, lamp, or fastening cannot silently turn into a player obstacle.
local function auditDocks(base, label)
	local reference = base:GetAttribute("BoatDockFrame")
	check(typeof(reference) == "CFrame", label .. " has no dock reference frame")
	local models, dockCount, linkCount, structureParts = {}, 0, 0, {}
	for _, item in base:GetChildren() do
		if item:IsA("Model") and (item.Name == "Dock" or item.Name == "DockLink") then
			table.insert(models, item)
			if item.Name == "Dock" then
				dockCount += 1
			else
				linkCount += 1
			end
		end
	end
	check(dockCount == 2 and linkCount == 1, label .. " needs two dock legs and one matching crosswalk")
	for _, model in models do
		local boards, piles, rails, lamps, supports = {}, 0, 0, 0, 0
		local axis = if model.Name == "DockLink" then "X" else "Z"
		for _, item in model:GetDescendants() do
			if item.Name == "DockLamp" and item:IsA("Model") then
				lamps += 1
			end
			if not item:IsA("BasePart") then
				continue
			end
			table.insert(structureParts, item)
			if item.Name == "DeckPlank" then
				local low, high = bounds(item, reference)
				check(math.abs(high.Y - 3.3) < EPS, label .. " has an uneven or raised deck plank")
				check((item.CFrame.UpVector - Vector3.yAxis).Magnitude < EPS, label .. " has a tilted deck plank")
				check(not item.CanCollide and not item.CanQuery, label .. " plank seams affect dock navigation")
				table.insert(boards, { low = low[axis], high = high[axis] })
			elseif item.Name == "Pile" then
				piles += 1
			elseif item.Name == "RopeRail" then
				rails += 1
				check(
					not item.CanCollide and not item.CanTouch and not item.CanQuery,
					label .. " rope rail blocks movement or queries"
				)
			end
			if
				string.find(item.Name, "Bearer")
				or string.find(item.Name, "Joist")
				or string.find(item.Name, "Brace")
			then
				supports += 1
			end
		end
		local surface = model:FindFirstChild("DeckSurface")
		check(surface and surface.CanCollide and surface.Anchored and surface.Transparency == 1,
			label .. " needs continuous support beneath the visible planks")
		check(#boards >= 12, label .. " " .. model.Name .. " is missing its individual timber boards")
		check(
			piles >= (if model.Name == "Dock" then 6 else 3),
			label .. " " .. model.Name .. " lacks substantial support piles"
		)
		check(supports >= 2, label .. " " .. model.Name .. " lacks visible timber framing")
		if model.Name == "Dock" then
			check(rails >= 4, label .. " dock leg lacks rope railing")
			check(lamps >= 1, label .. " dock leg lacks a warm dock lamp")
		end
		table.sort(boards, function(a, b)
			return a.low < b.low
		end)
		for index = 2, #boards do
			local seam = boards[index].low - boards[index - 1].high
			check(
				seam >= -EPS and seam <= 0.25,
				label .. " " .. model.Name .. " has overlapping boards or an oversized walking seam"
			)
		end
		if #boards > 0 then
			local span = boards[#boards].high - boards[1].low
			check(
				span >= (if model.Name == "Dock" then 46.5 else 26.5),
				label .. " " .. model.Name .. " deck is too short"
			)
		end
	end
	local lanes = {
		{ name = "left pier", size = Vector3.new(4, 5.5, 47.8), at = Vector3.new(-17, 6.06, -19) },
		{ name = "right pier", size = Vector3.new(4, 5.5, 47.8), at = Vector3.new(17, 6.06, -19) },
		{ name = "crosswalk junctions", size = Vector3.new(34, 5.5, 4), at = Vector3.new(0, 6.06, -38) },
	}
	for _, lane in lanes do
		local volume = { Size = lane.size, CFrame = reference * CFrame.new(lane.at) }
		local blockers = {}
		for _, item in structureParts do
			if item.CanCollide and overlaps(volume, item) then
				table.insert(blockers, item.Name)
			end
		end
		check(
			#blockers == 0,
			label
				.. " "
				.. lane.name
				.. " has less than four studs of walking clearance: "
				.. table.concat(blockers, ", ")
		)
	end
	return models
end

-- Production plaza and shop builders are inserted by check-rod-shop.mjs.
-- Recording mocks check geometry and migrations, not Roblox rendering or live physics.
local root = Instance.new("Folder")
root.Name = "Map"
local village = Instance.new("Model")
village.Name, village.Parent = "Village", root
local plazaCenter = shape.toWorld({ 870, 665 })
Harbour.buildPlaza(village, plazaCenter, Random.new(Biomes.Seed + 1))
local plaza = root:FindFirstChild("Plaza", true)
local paving
for _, piece in plaza:GetChildren() do
	if piece:IsA("BasePart") and piece.Size.X == 116 and piece.Size.Z == 116 then
		paving = piece
	end
end
assert(paving, "Plaza paving was not built")
local plazaFrame = paving.CFrame * CFrame.new(0, paving.Size.Y / 2, 0)
local function avatarAt(frame)
	return { Size = Vector3.new(3, 5.5, 3), CFrame = frame }
end
local function solids(model)
	local list = {}
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") and piece.CanCollide then
			table.insert(list, piece)
		end
	end
	return list
end
local function walk(route, frame, obstacles, label)
	for segment = 1, #route - 1 do
		local a, b = route[segment], route[segment + 1]
		local steps = math.ceil((b - a).Magnitude / 0.5)
		for step = 0, steps do
			local avatar = avatarAt(frame * CFrame.new(a:Lerp(b, step / steps)))
			for _, obstacle in obstacles do
				check(not overlaps(avatar, obstacle), label .. " blocked by " .. obstacle:GetFullName())
			end
		end
	end
end

-- The storefront on the square: a door that leads in, and no purchase volume of its own
local rodShop = plaza:FindFirstChild("FishingRodShop")
check(rodShop ~= nil, "Plaza lacks its rod store")
check(not CollectionService:HasTag(rodShop, "FishingRodShop"), "The storefront must not carry the purchase tag")
local streetDoor = rodShop:FindFirstChild("StreetDoor", true)
local enter = streetDoor and streetDoor:FindFirstChild("RodStoreDoorPrompt")
check(enter and enter:IsA("ProximityPrompt") and enter.ActionText == "Enter", "Street door lacks its Enter prompt")

-- The hall away from the map carries the purchase volume, counter and exit
local interiors = workspace:FindFirstChild("Interiors")
local hall = interiors and interiors:FindFirstChild("RodStoreInterior")
check(hall and CollectionService:HasTag(hall, "FishingRodShop"), "Rod store interior is missing or untagged")
local crateDisplay = hall:FindFirstChild("RodCrateDisplay")
check(crateDisplay ~= nil, "Rod stand needs its animated crate model")
local crateFrame = crateDisplay:GetAttribute("CrateFrame")
local lidHinge = crateDisplay:GetAttribute("LidHinge")
local crateLid = crateDisplay:FindFirstChild("RodCrateLid")
check(typeof(crateFrame) == "CFrame" and typeof(lidHinge) == "CFrame", "Crate animation frames must be saved")
check(crateLid and crateLid.PrimaryPart.Name == "LidBoard", "The lid must move independently of the crate walls")
check(crateDisplay:FindFirstChild("OpenRodCratePrompt", true).Parent.Name == "RodCrate", "Crate prompt needs its queryable front wall")
local cavity = { Size = Vector3.new(1, 0.8, 0.8), CFrame = crateFrame * CFrame.new(0, 1.6, 0) }
for _, piece in crateDisplay:GetDescendants() do
	if piece:IsA("BasePart") then
		check(piece.Material == Enum.Material.WoodPlanks, "Basic crate uses plain wood")
		check(not overlaps(cavity, piece), "Crate must be hollow for the rod reveal")
	end
	check(not piece:IsA("PointLight"), "Basic crate has no glowing orb")
end
check(not hall:FindFirstChild("BuyFishingRodPrompt", true), "Free rod claim prompt must be removed")
local arrival = hall:GetAttribute("ArrivalFrame")
local interiorFrame, interiorSize = hall:GetAttribute("InteriorFrame"), hall:GetAttribute("InteriorSize")
check(typeof(arrival) == "CFrame" and typeof(interiorFrame) == "CFrame", "Interior frames missing")
check(
	(enter:GetAttribute("TeleportTo").Position - arrival.Position).Magnitude < EPS,
	"Street door does not lead to the hall's arrival point"
)
local function insideHall(p)
	local q = interiorFrame:PointToObjectSpace(p)
	return math.abs(q.X) < interiorSize.X / 2
		and math.abs(q.Y) < interiorSize.Y / 2
		and math.abs(q.Z) < interiorSize.Z / 2
end
check(insideHall(arrival.Position), "Arrival point is outside the purchase volume")
check(
	(arrival.Position - Vector3.new(0, arrival.Position.Y, 0)).Magnitude > 5200 + 500,
	"Interior must stand well beyond the map's edge"
)
check(arrival.LookVector:Dot(interiorFrame.ZVector) > 0.99, "Arrival must face into the hall")
local exitDoor = hall:FindFirstChild("ExitDoor", true)
local leave = exitDoor and exitDoor:FindFirstChild("RodStoreDoorPrompt")
local exitFrame = rodShop:GetAttribute("ExitFrame")
check(leave and leave.ActionText == "Leave", "Hall exit lacks its Leave prompt")
check(
	typeof(exitFrame) == "CFrame" and (leave:GetAttribute("TeleportTo").Position - exitFrame.Position).Magnitude < EPS,
	"Hall exit does not lead back to the street door"
)
check(
	(exitFrame.Position - streetDoor.Position).Magnitude < enter.MaxActivationDistance,
	"Leaving should set the angler down by the street door"
)
check(
	(arrival.Position - exitDoor.Position).Magnitude < leave.MaxActivationDistance,
	"The exit prompt should be reachable from the arrival point"
)

-- Nothing solid where either teleport sets an avatar down, nor on the way to the counter
local hallSolids = solids(hall)
local plazaSolids = solids(plaza)
for _, obstacle in plazaSolids do
	check(not overlaps(avatarAt(exitFrame), obstacle), "Exit point lands inside " .. obstacle:GetFullName())
end
local counter = hall:FindFirstChild("CounterTop")
local hallFrame = interiorFrame * CFrame.new(0, -interiorSize.Y / 2, 0)
local counterLocal = hallFrame:PointToObjectSpace(counter.Position)
local rodKeeperFrame = hall:GetAttribute("KeeperFrame")
local keeperLocal = hallFrame:PointToObjectSpace(rodKeeperFrame.Position)
check(math.abs(keeperLocal.X - counterLocal.X) < EPS and keeperLocal.Z > counterLocal.Z + counter.Size.Z / 2, "Finn must stand centered behind the counter")
local customerZ = counterLocal.Z - counter.Size.Z / 2 - 2
walk(
	{ hallFrame:PointToObjectSpace(arrival.Position), Vector3.new(0, 3.3, customerZ) },
	hallFrame,
	hallSolids,
	"Aisle to counter"
)
check(insideHall(hallFrame * Vector3.new(0, 3.3, customerZ)), "Counter customer is outside the purchase volume")
check(
	((hallFrame * Vector3.new(0, 3.3, customerZ)) - (rodKeeperFrame * Vector3.new(0, 5.2, 0))).Magnitude < 11,
	"Finn's prompt is out of reach from the customer side"
)
-- Plaza approach: from the square up to the street door
local doorLocal = plazaFrame:PointToObjectSpace(exitFrame.Position)
walk(
	{ Vector3.new(-15, 3.4, doorLocal.Z), Vector3.new(doorLocal.X, 3.4, doorLocal.Z) },
	plazaFrame,
	plazaSolids,
	"Plaza route to rod store"
)

-- Reproduce the server's eye-to-prompt ray against the actual part boxes.
local function segmentHit(a, b, obstacle)
	local origin = obstacle.CFrame:PointToObjectSpace(a)
	local delta = obstacle.CFrame:VectorToObjectSpace(b - a)
	local near, far = 0, 1
	for _, axis in { "X", "Y", "Z" } do
		local half = obstacle.Size[axis] / 2
		if math.abs(delta[axis]) < EPS then
			if math.abs(origin[axis]) > half then
				return nil
			end
		else
			local low = (-half - origin[axis]) / delta[axis]
			local high = (half - origin[axis]) / delta[axis]
			near = math.max(near, math.min(low, high))
			far = math.min(far, math.max(low, high))
			if near > far then
				return nil
			end
		end
	end
	return near
end
for _, x in { -3, 0, 3 } do
	local eye = hallFrame * Vector3.new(x, 5.2, customerZ)
	local keeperHead = rodKeeperFrame * Vector3.new(0, 5.2, 0)
	for _, obstacle in hall:GetDescendants() do
		if obstacle:IsA("BasePart") and obstacle.CanQuery ~= false then
			local hit = segmentHit(eye, keeperHead, obstacle)
			check(not hit, "Finn's head ray from x=" .. x .. " is blocked by " .. obstacle.Name)
		end
	end
end

-- Stairs climb in walkable steps to the gallery deck
local stairs = {}
for _, piece in hall:GetChildren() do
	if piece:IsA("BasePart") and piece.Name == "Stair" then
		table.insert(stairs, hallFrame:PointToObjectSpace(piece.Position).Y * 2)
	end
end
table.sort(stairs)
check(#stairs >= 10, "Gallery stairs are missing")
for i, top in stairs do
	check(top - (stairs[i - 1] or 0) <= 1 + EPS, "Stair step " .. i .. " is too tall to walk up")
end
check(math.abs(stairs[#stairs] - 12) < EPS, "Stairs must arrive level with the gallery deck")

-- Terraces round the square: plots on streets stay empty, generated houses are cleared away
local houses = Instance.new("Model")
houses.Name, houses.Parent = "Houses", village
local doomed = Instance.new("Model")
doomed.Name, doomed.Parent = "Townhouse", houses
local doomedWall = Instance.new("Part")
doomedWall.Size, doomedWall.CFrame, doomedWall.Parent =
	Vector3.new(10, 10, 10), plazaFrame * CFrame.new(-72, 4, -30), doomed
local spared = Instance.new("Model")
spared.Name, spared.Parent = "Townhouse", houses
local sparedWall = Instance.new("Part")
sparedWall.Size, sparedWall.CFrame, sparedWall.Parent =
	Vector3.new(10, 10, 10), plazaFrame * CFrame.new(-120, 4, -30), spared
local road = Instance.new("Model")
road.Name, road.Parent = "Road", village
local street = Instance.new("Part")
street.Size, street.CFrame, street.Parent = Vector3.new(30, 1, 16), plazaFrame * CFrame.new(72, -0.6, 10), road
local terraces = dependencies.PlazaHouses.build(plaza, plazaFrame)
local built = {}
for _, house in terraces:GetChildren() do
	table.insert(built, house)
end
check(#built >= 14, "Too few terrace houses round the square: " .. #built)
check(doomed.Parent == nil, "A generated house on a terrace plot was not cleared")
check(spared.Parent == houses, "A generated house clear of the terraces was removed")
for _, house in built do
	for _, piece in house:GetDescendants() do
		if piece:IsA("BasePart") and piece.CanCollide then
			check(not overlaps(piece, street), house.Name .. " was built across a street")
			check(not overlaps(piece, paving), house.Name .. " intrudes on the paving")
		end
	end
end
local afterTerraces = #plaza:GetDescendants()
check(dependencies.PlazaHouses.build(plaza, plazaFrame) == terraces, "Terrace build is not idempotent")
check(#plaza:GetDescendants() == afterTerraces, "Terrace rebuild duplicated parts")

-- Harbour Home: a linked showroom with full-size displays and reachable purchase prompts.
local furnitureShop = plaza:FindFirstChild("FurnitureShop")
check(furnitureShop ~= nil, "Plaza lacks its furniture shop")
check(not furnitureShop:FindFirstChild("SalesCounter"), "Old pavement counter must be removed")
check(not furnitureShop:FindFirstChild("BrowseFurniturePrompt", true), "Streetfront must not sell furniture")
local furnitureDoor = furnitureShop:FindFirstChild("StreetDoor", true)
local furnitureEnter = furnitureDoor and furnitureDoor:FindFirstChild("FurnitureStoreDoorPrompt")
check(furnitureEnter and furnitureEnter.ActionText == "Enter", "Furniture street door lacks Enter prompt")
local showroom = interiors:FindFirstChild("FurnitureStoreInterior")
check(showroom and CollectionService:HasTag(showroom, "FurnitureShowroom"), "Furniture showroom is missing or untagged")
check(showroom.ModelStreamingMode == Enum.ModelStreamingMode.Atomic, "Showroom must stream as one model")
local showroomFrame = showroom:GetAttribute("InteriorFrame") * CFrame.new(0, -9, 0)
local showroomArrival = showroom:GetAttribute("ArrivalFrame")
check((furnitureEnter:GetAttribute("TeleportTo").Position - showroomArrival.Position).Magnitude < EPS, "Furniture door leads to wrong interior")
check(showroomArrival.LookVector:Dot(showroomFrame.ZVector) > 0.99, "Furniture arrival must face into showroom")
local furnitureLeave = showroom:FindFirstChild("ExitDoor"):FindFirstChild("FurnitureStoreDoorPrompt")
local furnitureExit = furnitureShop:GetAttribute("ExitFrame")
check(furnitureLeave and furnitureLeave.ActionText == "Leave", "Furniture showroom lacks Leave prompt")
check((furnitureLeave:GetAttribute("TeleportTo").Position - furnitureExit.Position).Magnitude < EPS, "Showroom exit must return to storefront")
for _, piece in plazaSolids do
	check(not overlaps(avatarAt(furnitureExit), piece), "Furniture exit lands inside " .. piece:GetFullName())
end
local showroomSolids = solids(showroom)
for _, id in dependencies.FurnitureCatalog.Order do
	-- Every catalogue item has a full-size display facing its own customer spot.
	local display = showroom:FindFirstChild(id .. "Display")
	local sample = display and display:FindFirstChild("Sample" .. id)
	check(sample and sample:IsA("Model") and #sample:GetDescendants() > 5, "Missing full-size furniture sample: " .. id)
	local prompt = display and display:FindFirstChild("BrowseFurniturePrompt", true)
	check(prompt and prompt:GetAttribute("ItemId") == id, "Display must offer its own item: " .. id)
	local label = prompt.Parent:FindFirstChildWhichIsA("SurfaceGui"):FindFirstChildWhichIsA("TextLabel")
	check(string.find(label.Text, "$" .. dependencies.FurnitureCatalog.Items[id].Price, 1, true) ~= nil, "Display price disagrees with catalogue: " .. id)
	local customer = display and display:GetAttribute("CustomerSpot")
	local spot = if customer ~= nil and type(customer.X) == "number" then customer else nil
	check(spot ~= nil, "Display lacks its customer spot: " .. id)
	if spot then
		walk({
			showroomFrame:PointToObjectSpace(showroomArrival.Position),
			Vector3.new(0, 3.2, -8),
			Vector3.new(spot.X, 3.2, -8),
			spot,
		}, showroomFrame, showroomSolids, "Route to " .. id .. " display")
		check(
			((showroomFrame * spot) - prompt.Parent.Position).Magnitude < prompt.MaxActivationDistance,
			"Display prompt out of reach: " .. id
		)
	end
end
local counterTop = showroom:FindFirstChild("CounterTop")
check(counterTop and CollectionService:HasTag(counterTop, "FurnitureShop"), "Furniture counter is untagged")
local browse = counterTop and counterTop:FindFirstChild("BrowseFurniturePrompt")
check(browse and browse:IsA("ProximityPrompt"), "Furniture counter lacks its browse prompt")
local shopSolids = solids(furnitureShop)
for _, piece in plaza:GetDescendants() do
	-- Paving, kerbs and inlays are flat slabs the shop stands on.
	if piece:IsA("BasePart") and piece.CanCollide and not piece:IsDescendantOf(furnitureShop) and piece.Size.Y > 1 then
		for _, own in shopSolids do
			check(not overlaps(own, piece), "Furniture shop collides with " .. piece:GetFullName())
		end
	end
end
local keeperFrame = showroom:GetAttribute("KeeperFrame")
local customerSpot = keeperFrame * CFrame.new(0, 2.9, -dependencies.ShopDesk.DEPTH - 2.9)
walk({ showroomFrame:PointToObjectSpace(showroomArrival.Position), Vector3.new(0, 3.2, -11), showroomFrame:PointToObjectSpace(customerSpot.Position) }, showroomFrame, showroomSolids, "Indoor furniture counter approach")
local furnitureDoorLocal = plazaFrame:PointToObjectSpace(furnitureExit.Position)
walk({ Vector3.new(15, 3.4, furnitureDoorLocal.Z), Vector3.new(furnitureDoorLocal.X, 3.4, furnitureDoorLocal.Z) }, plazaFrame, plazaSolids, "Plaza route to furniture shop")
local afterFurniture = #plaza:GetDescendants()
check(dependencies.FurnitureShop.build(plaza, plazaFrame) == furnitureShop, "Furniture shop build is not idempotent")
check(#plaza:GetDescendants() == afterFurniture, "Furniture shop rebuild duplicated parts")

for _, width in { 116, 120 } do
	local saved = Instance.new("Folder")
	local savedPlaza = Instance.new("Model")
	savedPlaza.Name, savedPlaza.Parent = "Plaza", saved
	local savedFloor = Instance.new("Part")
	savedFloor.Size, savedFloor.CFrame, savedFloor.Parent =
		Vector3.new(width, 0.6, width), CFrame.new(112, 8.5, -92) * CFrame.Angles(0, 0.72, 0), savedPlaza
	local unrelated = Instance.new("Part")
	unrelated.Name, unrelated.Parent = "UnrelatedPlazaDecoration", savedPlaza
	dependencies.RodShop.ensure(saved)
	local result = savedPlaza:FindFirstChild("FishingRodShop")
	check(result ~= nil, "Saved plaza " .. width .. " did not receive its rod store")
	local expected = savedFloor.CFrame * CFrame.new(0, 0.3, 0) * CFrame.new(-45, 0, 35)
	local exitAt = savedFloor.CFrame:PointToObjectSpace(result:GetAttribute("ExitFrame").Position)
	local wanted = savedFloor.CFrame:PointToObjectSpace(expected.Position)
	check(
		math.abs(exitAt.Z - wanted.Z) < 12 and exitAt.X > wanted.X,
		"Saved rod store ignored paving position or rotation"
	)
	local afterRodEnsure = #saved:GetDescendants()
	local hallBefore = workspace:FindFirstChild("Interiors"):FindFirstChild("RodStoreInterior")
	dependencies.RodShop.ensure(saved)
	check(
		savedPlaza:FindFirstChild("FishingRodShop") == result and #saved:GetDescendants() == afterRodEnsure,
		"Rod store saved-map upgrade is not idempotent"
	)
	check(
		workspace:FindFirstChild("Interiors"):FindFirstChild("RodStoreInterior") == hallBefore,
		"Rod store interior was rebuilt needlessly"
	)
	check(unrelated.Parent == savedPlaza, "Rod store upgrade removed an unrelated plaza decoration")
	dependencies.FurnitureShop.ensure(saved)
	local savedFurniture = savedPlaza:FindFirstChild("FurnitureShop")
	check(savedFurniture ~= nil, "Saved plaza " .. width .. " did not receive its furniture shop")
	local afterFurnitureEnsure = #saved:GetDescendants()
	dependencies.FurnitureShop.ensure(saved)
	check(#saved:GetDescendants() == afterFurnitureEnsure, "Furniture shop saved-map upgrade is not idempotent")
	check(interiors:FindFirstChild("FurnitureStoreInterior") == showroom, "Furniture showroom rebuilt needlessly")
	CollectionService:RemoveTag(showroom, "FurnitureShowroom")
	CollectionService:RemoveTag(counterTop, "FurnitureShop")
	savedFurniture:SetAttribute("LayoutVersion", 1)
	local oldCounter = Instance.new("Part")
	oldCounter.Name, oldCounter.Parent = "CounterTop", savedFurniture
	dependencies.FurnitureShop.ensure(saved)
	local upgradedFurniture = savedPlaza:FindFirstChild("FurnitureShop")
	check(savedFurniture.Parent == nil and upgradedFurniture ~= savedFurniture, "Old pavement furniture shop did not upgrade")
	check(not upgradedFurniture:FindFirstChild("CounterTop"), "Pavement purchase anchor survived upgrade")
	check(CollectionService:HasTag(showroom, "FurnitureShowroom") and CollectionService:HasTag(counterTop, "FurnitureShop"), "Furniture shop tags were not restored")
	check((furnitureLeave:GetAttribute("TeleportTo").Position - upgradedFurniture:GetAttribute("ExitFrame").Position).Magnitude < EPS, "Showroom exit not relinked after upgrade")

	result:SetAttribute("LayoutVersion", 0)
	dependencies.RodShop.ensure(saved)
	local upgraded = savedPlaza:FindFirstChild("FishingRodShop")
	check(result.Parent == nil and upgraded ~= result, "Stale rod store layout did not upgrade")
	local relinked = hallBefore:FindFirstChild("ExitDoor", true):FindFirstChild("RodStoreDoorPrompt")
	check(
		(relinked:GetAttribute("TeleportTo").Position - upgraded:GetAttribute("ExitFrame").Position).Magnitude < EPS,
		"Hall exit was not relinked to the rebuilt storefront"
	)
	-- A saved purple/gold crate hall must upgrade to the hollow wooden version.
	hallBefore:SetAttribute("LayoutVersion", 3)
	dependencies.RodShop.ensure(saved)
	local rebuiltHall = interiors:FindFirstChild("RodStoreInterior")
	check(hallBefore.Parent == nil and rebuiltHall ~= hallBefore, "Old crate interior was not replaced")
	check(rebuiltHall:FindFirstChild("RodCrateDisplay") ~= nil and rebuiltHall:GetAttribute("LayoutVersion") == 6, "Saved hall lacks the new wooden crate")
	local bobberDisplay = rebuiltHall:FindFirstChild("BobberCrateDisplay")
	local rodDisplay = rebuiltHall:FindFirstChild("RodCrateDisplay")
	check(bobberDisplay and bobberDisplay:FindFirstChild("BobberCrateLid"), "Saved hall must receive the bobber case and opening lid")
	local bobberPrompt = bobberDisplay and bobberDisplay:FindFirstChild("OpenBobberCratePrompt", true)
	check(bobberPrompt and bobberPrompt.ObjectText == "Bobbers · $350", "Bobber case has its own priced prompt")
	local bobberPosition = bobberDisplay and bobberDisplay:GetAttribute("CrateFrame").Position
	local rodPosition = rodDisplay:GetAttribute("CrateFrame").Position
	check(bobberPosition and math.abs((bobberPosition - rodPosition).Magnitude - 20) < EPS, "Bobber case stands opposite the rod cases across the aisle")
	dependencies.RodShop.ensure(saved)
	check(interiors:FindFirstChild("RodStoreInterior") == rebuiltHall, "New crate hall must remain idempotent")
end
assert(failures == 0, tostring(failures) .. " rod store geometry checks failed")
print(
	string.format(
		"PASS: %d rod store geometry assertions; street door and hall exit teleports, clear landing spots, aisle and counter sightlines, walkable gallery stairs, plaza terraces clearing houses but not streets, saved-map upgrades and idempotency. Recording mocks do not verify live Roblox rendering or physics.",
		checks
	)
)
