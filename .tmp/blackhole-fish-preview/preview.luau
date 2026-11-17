local freezerTestPacking, freezerTestModels = (function()
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



Vector3.one = Vector3.new(1, 1, 1)
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
			AncestryChanged = { Connect = function() return { Disconnect = function() end } end },
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
-- Model pivots follow Roblox: a bounding pivot when no PrimaryPart is set.
function instanceMethods:GetBoundingBox()
	local low, high = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, piece in self:GetDescendants() do
		if piece:IsA("BasePart") then
			for _, x in { -0.5, 0.5 } do
				for _, y in { -0.5, 0.5 } do
					for _, z in { -0.5, 0.5 } do
						local p = piece.CFrame * Vector3.new(piece.Size.X * x, piece.Size.Y * y, piece.Size.Z * z)
						low, high = low:Min(p), high:Max(p)
					end
				end
			end
		end
	end
	return CFrame.new((low + high) / 2), high - low
end
function instanceMethods:GetPivot()
	if self.PrimaryPart then
		return self.PrimaryPart.CFrame
	end
	return self:GetBoundingBox()
end
function instanceMethods:PivotTo(target)
	local previous = self:GetPivot()
	for _, piece in self:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.CFrame = target * previous:ToObjectSpace(piece.CFrame)
		end
	end
end
function instanceMethods:ScaleTo(scale)
	local ratio = scale / (self._props.ModelScale or 1)
	local pivot = self:GetPivot()
	for _, piece in self:GetDescendants() do
		if piece:IsA("BasePart") then
			local relative = pivot:ToObjectSpace(piece.CFrame)
			piece.Size *= ratio
			piece.CFrame = pivot
				* CFrame.fromMatrix(relative.Position * ratio, relative.RightVector, relative.UpVector, relative.ZVector)
		end
	end
	self._props.ModelScale = scale
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
	-- BOATCATALOG_SOURCE --
end
dependencies.BoatCatalog = loadBoatCatalog()


local originalTypeof = typeof
local function typeof(value)
  if type(value)=='table' then
    if getmetatable(value)==getmetatable(Vector2.zero) then return 'Vector2' end
    if getmetatable(value)==getmetatable(Vector3.zero) then return 'Vector3' end
  end
  return originalTypeof(value)
end
Vector3.one = Vector3.new(1,1,1)
local vectorMt = getmetatable(Vector3.zero)
local scalarMultiply = vectorMt.__mul
function vectorMt.__mul(a,b)
  if type(a) == 'table' and type(b) == 'table' then return Vector3.new(a.X*b.X,a.Y*b.Y,a.Z*b.Z) end
  return scalarMultiply(a,b)
end
function frameMt.__sub(a,b) return a + (-b) end
local originalFrameIndex = frameMt.__index
function frameMt.__index(self, key)
  if key == 'Rotation' then return frame(Vector3.zero, self.RightVector, self.UpVector, self.ZVector) end
  return originalFrameIndex(self, key)
end
function instanceMethods:AddTag(tag) self._tags[tag] = true end
function instanceMethods:Clone()
  local copy = Instance.new(self.ClassName)
  for key, value in self._props do if key ~= 'Parent' then copy._props[key] = value end end
  copy._attributes = table.clone(self._attributes)
  copy._tags = table.clone(self._tags)
  for _, child in self:GetChildren() do child:Clone().Parent = copy end
  return copy
end
local FishMutations = (function() -- Pure mutation rules shared by the server (which rolls and prices) and every
-- model builder (which paints). A record's Mutation is a "+"-joined key such as
-- "Corrupted+Rainbow+Neon"; Neon catches also carry NeonColor and Corrupted ones
-- carry Corruptions, the list of extra body parts. Rolls take a uniform [0, 1)
-- source so tests can drive them without Roblox's Random.
local FishMutations = {}

-- Chance that a catch carries any mutation at all, Astral included.
FishMutations.CHANCE = 1 / 60
-- Astral only surfaces at night (DayNight.isNight), at this share of every night catch.
FishMutations.ASTRAL_CHANCE = 1 / 1000
FishMutations.ASTRAL_RAINBOW_CHANCE = 0.15
-- Any other mutation can also come out corrupted.
FishMutations.CORRUPTED_EXTRA_CHANCE = 0.1
-- Each corrupted part beyond the first.
FishMutations.EXTRA_CORRUPTION_CHANCE = 0.25
FishMutations.CORRUPTED_BONUS = 1.5
FishMutations.VOID_TOUCHED_BONUS = 2
-- Fishing under a supercell (Weather.mutationContext) turns this share of
-- catches Windy, on top of whatever else they roll.
FishMutations.WINDY_CHANCE = 1 / 3
FishMutations.WINDY_BONUS = 0.5

-- Display and key order.
FishMutations.Order = { "Corrupted", "VoidTouched", "Windy", "Ascended", "Floral", "Snowy", "Tryhard", "JackOFish", "JacksPet", "ZeusStruck", "Nightmare", "Obsidian", "Gusty", "Astral", "Rainbow", "Neon", "Albino" }

FishMutations.Specials = {
 Ascended = { Chance = 1 / 10000, Multiplier = 12 }, Floral = { Chance = 1 / 200, Multiplier = 5 },
 Snowy = { Chance = 1 / 200, Multiplier = 5 }, Tryhard = { Chance = 1 / 10000, Multiplier = 10 },
 JackOFish = { Chance = 0.05, Multiplier = 2.5 }, JacksPet = { Chance = 1 / 500, Multiplier = 15 },
 ZeusStruck = { Chance = 1 / 150, Multiplier = 5 }, Nightmare = { Chance = 1 / 30, Multiplier = 1.5 },
 Obsidian = { Chance = 1 / 30, Multiplier = 2 }, Gusty = { Chance = 1 / 100, Multiplier = 2 },
}

-- Every colour outcome with its share of the non-Astral mutation chance and the
-- worth it adds (1 = +100%).
FishMutations.Outcomes = {
	{ Key = "Neon", Weight = 46, Bonus = 1 },
	{ Key = "Albino", Weight = 20, Bonus = 1.5 },
	{ Key = "Corrupted", Weight = 14, Bonus = 0 },
	{ Key = "Rainbow", Weight = 10, Bonus = 2 },
	{ Key = "Neon+Albino", Weight = 6, Bonus = 5 },
	{ Key = "Rainbow+Neon", Weight = 4, Bonus = 6 },
}
FishMutations.AstralOutcomes = {
	Astral = 10,
	["Astral+Rainbow"] = 20,
}

FishMutations.NeonColors = {
	Red = { 255, 46, 58 },
	Orange = { 255, 136, 24 },
	Yellow = { 255, 232, 40 },
	Green = { 40, 255, 96 },
	Blue = { 36, 140, 255 },
	Purple = { 170, 60, 255 },
	Rose = { 255, 80, 170 },
	White = { 245, 248, 255 },
}
FishMutations.NeonColorOrder = { "Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Rose", "White" }
FishMutations.Corruptions = { "Tail", "Eye", "Fin", "Bone" }

local totalWeight = 0
for _, outcome in FishMutations.Outcomes do
	totalWeight += outcome.Weight
end

function FishMutations.parts(key: string?): { [string]: boolean }
	local set = {}
	if key and key ~= "Normal" then
		for name in string.gmatch(key, "[^+]+") do
			set[name] = true
		end
	end
	return set
end

-- Canonical key for a set of mutation names; "Normal" when empty.
function FishMutations.key(set: { [string]: boolean }): string
	local names = {}
	for _, name in FishMutations.Order do
		if set[name] then
			table.insert(names, name)
		end
	end
	return if #names > 0 then table.concat(names, "+") else "Normal"
end

local function colourBonus(set): number
	local plain = table.clone(set)
	plain.Corrupted = nil
	plain.VoidTouched = nil
	plain.Windy = nil
	local key = FishMutations.key(plain)
	if FishMutations.AstralOutcomes[key] then
		return FishMutations.AstralOutcomes[key]
	end
	for _, outcome in FishMutations.Outcomes do
		if outcome.Key == key then
			return outcome.Bonus
		end
	end
	return 0
end

-- Worth multiplier: colour bonus plus CORRUPTED_BONUS for every corrupted part.
function FishMutations.multiplier(key: string?, corruptions: { string }?): number
	local set = FishMutations.parts(key)
	local bonus = colourBonus(set)
 for name, spec in FishMutations.Specials do
  if set[name] then bonus += spec.Multiplier - 1 end
 end
	if set.VoidTouched then
		bonus += FishMutations.VOID_TOUCHED_BONUS
	end
	if set.Windy then
		bonus += FishMutations.WINDY_BONUS
	end
	if set.Corrupted then
		bonus += FishMutations.CORRUPTED_BONUS * math.max(1, if corruptions then #corruptions else 1)
	end
	return 1 + bonus
end

function FishMutations.value(value: number, key: string?, corruptions: { string }?): number
	return math.max(1, math.floor(value * FishMutations.multiplier(key, corruptions) + 0.5))
end

-- Chance that one catch comes out with exactly this key (any corruption count).
function FishMutations.chance(key: string, night: boolean): number
	local set = FishMutations.parts(key)
	-- Void Touched and Windy come from weather events, never the natural roll.
	if set.VoidTouched or set.Windy then
		return 0
	end
	if not next(set) then
		return 1 - FishMutations.CHANCE
	end
	local corrupted = set.Corrupted
	set.Corrupted = nil
	local colour = FishMutations.key(set)
	local astral = if night then FishMutations.ASTRAL_CHANCE else 0
	if colour == "Normal" then
		-- Plain corruption is its own outcome, never an add-on.
		return (FishMutations.CHANCE - astral) * 14 / totalWeight
	end
	local base
	if colour == "Astral" then
		base = astral * (1 - FishMutations.ASTRAL_RAINBOW_CHANCE)
	elseif colour == "Astral+Rainbow" then
		base = astral * FishMutations.ASTRAL_RAINBOW_CHANCE
	else
		base = 0
		for _, outcome in FishMutations.Outcomes do
			if outcome.Key == colour then
				base = (FishMutations.CHANCE - astral) * outcome.Weight / totalWeight
			end
		end
	end
	return base * (if corrupted then FishMutations.CORRUPTED_EXTRA_CHANCE else 1 - FishMutations.CORRUPTED_EXTRA_CHANCE)
end

local function rollCorruptions(rng: () -> number): { string }
	local pool = table.clone(FishMutations.Corruptions)
	local picked = {}
	repeat
		table.insert(picked, table.remove(pool, math.floor(rng() * #pool) + 1))
	until #pool == 0 or rng() >= FishMutations.EXTRA_CORRUPTION_CHANCE
	return picked
end

export type Traits = { Mutation: string, NeonColor: string?, Corruptions: { string }? }

-- Junk never mutates. `bonus` (from a rod skin) adds to the chance of any
-- mutation and, at night only, to the Astral chance; Astral bonus odds come on
-- top of the plain mutation chance rather than out of it.
-- The server supplies `event` at the fishing position; guaranteed event traits
-- are added after the ordinary roll so colour mutations and rod boosts remain.
function FishMutations.roll(fish, night: boolean, rng: () -> number, bonus: any?, event: any?): Traits
	local extra = if bonus then math.max(0, bonus.mutation or 0) else 0
	local extraAstral = if bonus and night then math.max(0, bonus.astral or 0) else 0
	local astral = if night then FishMutations.ASTRAL_CHANCE + extraAstral else 0
	local pick = rng()
	if fish.Rarity == "Junk" then
		return { Mutation = "Normal" }
	end
	local windy = event ~= nil and event.windy == true and rng() < FishMutations.WINDY_CHANCE
	-- Special finishes replace ordinary colours, while event traits still stack.
 local special
 if event then
  if event.halloween then
   local halloween = rng()
   if halloween < FishMutations.Specials.JackOFish.Chance then special = "JackOFish"
   elseif halloween < FishMutations.Specials.JackOFish.Chance + FishMutations.Specials.JacksPet.Chance then special = "JacksPet" end
  end
  if not special then
   for _, candidate in { "Ascended", "Floral", "Snowy", "Tryhard", "ZeusStruck", "Nightmare", "Obsidian", "Gusty" } do
    local eligible = candidate == "Ascended" or candidate == "Gusty"
     or (candidate == "Floral" and event.season == "Spring")
     or (candidate == "Snowy" and event.season == "Winter")
     or (candidate == "Tryhard" and (event.level or 0) >= 50)
     or (candidate == "ZeusStruck" and event.supercell)
     or (candidate == "Nightmare" and night)
     or (candidate == "Obsidian" and event.volcanic)
    if eligible and rng() < FishMutations.Specials[candidate].Chance then special = candidate break end
   end
  end
 end
 if special then
  local set = { [special] = true }
  if windy then set.Windy = true end
  if event.corrupted or event.voidTouched then set.Corrupted = true end
  if event.voidTouched then set.VoidTouched = true end
  return { Mutation = FishMutations.key(set), Corruptions = if set.Corrupted then rollCorruptions(rng) else nil }
 end
 local key = "Normal"
 if pick >= FishMutations.CHANCE + extra + extraAstral then
		if not windy and (not event or not (event.corrupted or event.voidTouched)) then
			return { Mutation = "Normal" }
		end
	elseif pick < astral then
		key = if rng() < FishMutations.ASTRAL_RAINBOW_CHANCE then "Astral+Rainbow" else "Astral"
	else
		local weight = rng() * totalWeight
		for _, outcome in FishMutations.Outcomes do
			weight -= outcome.Weight
			key = outcome.Key
			if weight < 0 then
				break
			end
		end
	end
	local set = FishMutations.parts(key)
	if key ~= "Normal" and not set.Corrupted and rng() < FishMutations.CORRUPTED_EXTRA_CHANCE then
		set.Corrupted = true
	end
	if event and (event.corrupted or event.voidTouched) then
		set.Corrupted = true
	end
	if event and event.voidTouched then
		set.VoidTouched = true
	end
	if windy then
		set.Windy = true
	end
	local traits: Traits = { Mutation = FishMutations.key(set) }
	-- Rainbow paints over any neon colour, so it never gets one.
	if set.Neon and not set.Rainbow then
		local order = FishMutations.NeonColorOrder
		traits.NeonColor = order[math.floor(rng() * #order) + 1]
	end
	if set.Corrupted then
		traits.Corruptions = rollCorruptions(rng)
	end
	return traits
end

-- Every natural key a roll can produce, without an admin event.
function FishMutations.keys(): { string }
	local keys = {}
	local colours = { "Astral", "Astral+Rainbow" }
	for _, outcome in FishMutations.Outcomes do
		if outcome.Key ~= "Corrupted" then
			table.insert(colours, outcome.Key)
		end
	end
	table.insert(keys, "Corrupted")
	for _, colour in colours do
		table.insert(keys, colour)
		local set = FishMutations.parts(colour)
		set.Corrupted = true
		table.insert(keys, FishMutations.key(set))
	end
	return keys
end

-- Event keys stay separate so natural encounter odds keep their meaning.
-- Each event (Void Touched, Windy) adds its trait to every natural key.
function FishMutations.eventKeys(): { string }
	local keys = {}
	for _, event in { "VoidTouched", "Windy" } do
		table.insert(keys, event)
		for _, key in FishMutations.keys() do
			local set = FishMutations.parts(key)
			set[event] = true
			table.insert(keys, FishMutations.key(set))
		end
	end
	return keys
end

-- Each mutation's own colour (its inventory badge), as RGB. Neon catches use
-- their NeonColor instead and Rainbow names are painted letter by letter.
FishMutations.Colors = {
	Corrupted = { 180, 55, 77 }, VoidTouched = { 95, 61, 151 }, Windy = { 55, 151, 170 },
	Ascended = { 190, 151, 57 }, Floral = { 205, 92, 146 }, Snowy = { 72, 155, 199 },
	Tryhard = { 196, 91, 51 }, JackOFish = { 227, 112, 25 }, JacksPet = { 117, 77, 159 },
	ZeusStruck = { 194, 154, 29 }, Nightmare = { 151, 47, 73 }, Obsidian = { 88, 70, 109 },
	Gusty = { 57, 160, 125 }, Astral = { 185, 139, 47 }, Rainbow = { 109, 97, 179 },
	Neon = { 40, 164, 185 }, Albino = { 151, 164, 181 },
}
FishMutations.RainbowColors = { { 255, 116, 125 }, { 255, 216, 111 }, { 143, 244, 177 }, { 150, 205, 255 } }

local DISPLAY = { VoidTouched = "Void Touched", JackOFish = "Jack O' Fish", JacksPet = "Jack's Pet", ZeusStruck = "Zeus Struck" }

-- { { Key = "Neon", Text = "Red Neon" }, ... } in display order; empty when normal.
function FishMutations.labelParts(key: string?, neonColor: string?): { { Key: string, Text: string } }
	local set = FishMutations.parts(key)
	local parts = {}
	for _, name in FishMutations.Order do
		if set[name] then
			local text = if name == "Neon" and neonColor then neonColor .. " Neon" else DISPLAY[name] or name
			table.insert(parts, { Key = name, Text = text })
		end
	end
	return parts
end

-- "Red Neon Albino", "Corrupted Rainbow Neon", or "" for a normal fish.
function FishMutations.label(key: string?, neonColor: string?): string
	local names = {}
	for _, part in FishMutations.labelParts(key, neonColor) do
		table.insert(names, part.Text)
	end
	return table.concat(names, " ")
end

-- Pale paper (the bestiary book) needs the same hue much darker to stay legible.
local function onPaper(rgb: { number }): { number }
	return { math.floor(rgb[1] * 0.6 + 0.5), math.floor(rgb[2] * 0.6 + 0.5), math.floor(rgb[3] * 0.6 + 0.5) }
end

-- The RGB a mutation's name is written in. Text usually sits on dark UI, so
-- badge colours are lifted a quarter of the way to white; neon colours are
-- already bright. `light` is for text on pale backgrounds.
function FishMutations.textColor(name: string, neonColor: string?, light: boolean?): { number }
	local neon = name == "Neon" and neonColor and FishMutations.NeonColors[neonColor]
	local rgb = neon or FishMutations.Colors[name] or { 200, 200, 200 }
	if light then
		return onPaper(rgb)
	elseif neon then
		return neon
	end
	local lifted = {}
	for i = 1, 3 do
		lifted[i] = math.floor(rgb[i] + (255 - rgb[i]) * 0.25 + 0.5)
	end
	return lifted
end

local function hex(rgb: { number }): string
	return string.format("#%02X%02X%02X", rgb[1], rgb[2], rgb[3])
end

-- Roblox RichText for the mutation label: every mutation word in its own
-- colour, Rainbow letter by letter. "" for a normal fish. `light` darkens the
-- colours for pale backgrounds such as the bestiary page.
function FishMutations.richLabel(key: string?, neonColor: string?, light: boolean?): string
	local words = {}
	for _, part in FishMutations.labelParts(key, neonColor) do
		if part.Key == "Rainbow" then
			local letters = {}
			for index = 1, #part.Text do
				local colour = FishMutations.RainbowColors[(index - 1) % #FishMutations.RainbowColors + 1]
				if light then
					colour = onPaper(colour)
				end
				table.insert(letters, string.format('<font color="%s">%s</font>', hex(colour), string.sub(part.Text, index, index)))
			end
			table.insert(words, table.concat(letters))
		else
			local text = string.gsub(part.Text, "'", "&apos;")
			table.insert(words, string.format('<font color="%s">%s</font>', hex(FishMutations.textColor(part.Key, neonColor, light)), text))
		end
	end
	return table.concat(words, " ")
end

return FishMutations
 end)()
local FishModels = (function() -- Detailed fish built entirely from local parts, so no mesh or image upload is
-- needed. Bodies are overlapping ellipsoids (darker back and paler belly layers
-- give countershading), fins are wedge-pair triangles and markings are thin
-- discs laid on the body surface. Builders work in "fish lengths" (snout at
-- X = +0.5, tail at -0.5, back towards +Y) and are scaled to studs on creation.
local FishModels = {}
local FishMutations = FishMutations
local FishSpecies = (function()
local species = {}
species["AlabamaBass"] = (function()
return {
	Name = "Alabama Bass",
	Rarity = "Uncommon",
	RarityDenominator = 10,
	MinKg = 0.2,
	AverageKg = 1.4,
	MaxKg = 5.5,
	BaseValue = 29,
	Fight = 0.07,
	Pools = { "MainLake" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Requires = { "Day" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####", "####" },
	},
	-- Species-specific body proportions, fins and flank markings share the smooth mesh pipeline.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(52, 76, 42), side = rgb(142, 158, 88), belly = rgb(224, 226, 192) }
		local fin = rgb(100, 122, 66)
		b:fishBody(0.26, 0.14, colors, 0.07)
		local dorsal = b:edgeFin(0.15, -0.23, { 0.06, 0.075, 0.07, 0.055, 0.04, 0.055, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, rgb(54, 72, 40))
		b:edgeFin(-0.08, -0.23, { 0.06, 0.07, 0.045 }, fin, true)
		b:edgeFin(0.08, 0, { 0.055, 0.04 }, fin, true)
		b:forkTail(0.13, 0.028, fin)
		b:pectoral(0.21, -0.04, 0.105, 0.04, fin, 0.1)
		-- Broken dark lateral band and rows of small belly spots.
		for x = 0.25, -0.29, -0.06 do
			b:marks(x, 0, 0.065, 0.028, rgb(52, 76, 38))
		end
		for _, y in { -0.035, -0.065, -0.09 } do
			for x = 0.18, -0.23, -0.055 do
				b:marks(x, y, 0.012, 0.008, rgb(84, 100, 50))
			end
		end
		b:face(0.37, 0.033, 0.046, rgb(174, 132, 58), rgb(54, 72, 40))
	end,
}

end)()
species["Albacore"] = (function()
return {
	Name = "Albacore",
	Rarity = "Epic",
	RarityDenominator = 30,
	MinKg = 4,
	AverageKg = 15,
	MaxKg = 45,
	LengthScale = 1.2,
	BaseValue = 380,
	Fight = 0.07,
	Pools = { "OpenSea" },
	Seasons = { "Autumn", "Winter" },
	Shapes = {
		Normal = { "###", "###" },
		Big = { "####", "####" },
		Huge = { ".####.", "######", ".####." },
	},
	-- Long-finned tuna: dark blue back and pectorals that reach past the second dorsal.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(20, 32, 66), side = rgb(140, 152, 172), belly = rgb(236, 238, 240) }
		local fin = rgb(32, 44, 76)
		b:fishBody(0.245, 0.18, colors, 0.03)
		b:edgeFin(0.14, 0.02, { 0.08, 0.06, 0.03 }, fin, false, 0.05)
		b:fin({ v2(-0.01, b:top(-0.01) - 0.008), v2(-0.1, b:top(-0.01) + 0.1), v2(-0.08, b:top(-0.08) - 0.008) }, fin)
		b:fin({
			v2(-0.03, b:bottom(-0.03) + 0.008),
			v2(-0.12, b:bottom(-0.03) - 0.09),
			v2(-0.09, b:bottom(-0.09) + 0.008),
		}, fin)
		for index = 0, 5 do
			local x = -0.15 - index * 0.03
			for _, below in { false, true } do
				local edge = if below then b:bottom(x) else b:top(x)
				local sign = if below then -1 else 1
				b:fin({
					v2(x + 0.008, edge - sign * 0.004),
					v2(x - 0.012, edge + sign * 0.02),
					v2(x - 0.014, edge - sign * 0.004),
				}, rgb(120, 116, 80))
			end
		end
		b:lunateTail(0.23, fin)
		-- Very long pectoral fins are the albacore's trademark.
		b:pectoral(0.21, 0.01, 0.34, 0.06, fin)
		b:stroke({ v2(0.28, 0.03), v2(0, 0.035), v2(-0.28, 0.01) }, 0.012, rgb(100, 130, 180))
		b:face(0.37, 0.03, 0.05, rgb(170, 170, 150), rgb(60, 70, 100))
	end,
}

end)()
species["Anchovy"] = (function()
return {
	Name = "Anchovy",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.01,
	AverageKg = 0.04,
	MaxKg = 0.18,
	BaseValue = 17,
	Fight = 0.05,
	Pools = { "OpenSea" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "#" },
		Big = { "#" },
		Huge = { "##" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(70, 112, 104), side = rgb(196, 204, 196), belly = rgb(236, 238, 232) }
		local fin = rgb(176, 184, 176)
		b:fishBody(0.15, 0.09, colors, 0.02)
		b:edgeFin(0.04, -0.06, { 0.05, 0.04, 0.025 }, fin, false, 0.25)
		b:edgeFin(-0.06, -0.2, { 0.025, 0.025, 0.02 }, fin, true, 0.25)
		b:forkTail(0.11, 0.08, fin, 0.2)
		b:pectoral(0.22, -0.035, 0.06, 0.02, fin, 0.25)
		b:stroke({ v2(0.24, 0), v2(-0.32, 0) }, 0.016, rgb(214, 224, 228))
		-- Rounded snout overhanging a long jaw.
		b:ellipsoid("Snout", CFrame.new(0.47, 0.012, 0), Vector3.new(0.07, 0.05, 0.05), colors.back)
		b:face(0.39, 0.015, 0.058, rgb(200, 206, 200), rgb(130, 140, 134))
		b:stroke({ v2(0.46, -0.012), v2(0.34, -0.028) }, 0.006, rgb(40, 40, 36))
	end,
}

end)()
species["Angelfish"] = (function()
return {
	Name = "Angelfish",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.08,
	AverageKg = 0.25,
	MaxKg = 1.2,
	BaseValue = 28,
	Fight = 0.03,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "#" },
		Big = { "#", "#" },
		Huge = { "#.", "##", "#." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(184, 186, 180), side = rgb(216, 218, 216), belly = rgb(238, 240, 240) }
		local fin = rgb(206, 208, 206)
		b:fishBody(0.5, 0.07, colors, 0.12)
		b:fin({ v2(0.16, 0.2), v2(-0.02, 0.42), v2(-0.36, 0.66), v2(-0.26, 0.26), v2(-0.24, 0.1) }, fin, 0.2)
		b:fin({ v2(0.1, -0.2), v2(-0.04, -0.42), v2(-0.36, -0.66), v2(-0.26, -0.26), v2(-0.24, -0.1) }, fin, 0.2)
		b:roundTail(0.13, fin, 0.2)
		for _, side in { 1, -1 } do
			b:limb(
				Vector3.new(0.14, -0.2, side * 0.02),
				Vector3.new(0.0, -0.66, side * 0.03),
				0.008,
				rgb(226, 224, 214),
				"Filament"
			)
		end
		for _, tip in { v2(-0.6, 0.22), v2(-0.6, -0.22) } do
			b:limb(Vector3.new(-0.46, tip.Y * 0.5, 0), Vector3.new(tip.X, tip.Y, 0), 0.006, fin, "Filament")
		end
		local dark = rgb(26, 26, 30)
		b:stroke({ v2(0.33, b:top(0.33) - 0.01), v2(0.33, b:bottom(0.33) + 0.01) }, 0.045, dark)
		b:stroke({ v2(0.1, b:top(0.1) - 0.01), v2(0.08, b:bottom(0.08) + 0.01) }, 0.055, dark)
		b:stroke({ v2(-0.15, b:top(-0.15) - 0.01), v2(-0.17, b:bottom(-0.17) + 0.01) }, 0.045, dark)
		b:rays(v2(0.09, 0.22), { v2(-0.12, 0.5) }, dark)
		b:rays(v2(0.07, -0.22), { v2(-0.12, -0.5) }, dark)
		b:rays(v2(-0.15, 0.17), { v2(-0.3, 0.55) }, dark)
		b:rays(v2(-0.17, -0.17), { v2(-0.3, -0.55) }, dark)
		b:pectoral(0.2, -0.02, 0.09, 0.03, fin, 0.3)
		b:face(0.37, 0.06, 0.05, rgb(196, 70, 54), rgb(170, 170, 160))
	end,
}

end)()
species["ArrowSquid"] = (function()
return {
	Name = "Arrow Squid",
	Rarity = "Rare",
	RarityDenominator = 20,
	MinKg = 0.3,
	AverageKg = 1,
	MaxKg = 6,
	BaseValue = 60,
	Fight = 0.04,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "#.", "##" },
		Big = { "#..", "###" },
		Huge = { "#...", "####", "#..." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(176, 94, 84), side = rgb(206, 134, 120), belly = rgb(236, 206, 194) }
		b:layered("Mantle", Vector3.new(0.17, 0, 0), Vector3.new(0.6, 0.15, 0.15), colors)
		b:layered("MantleTip", Vector3.new(0.42, 0, 0), Vector3.new(0.2, 0.075, 0.075), colors)
		b:body("MantlePoint", Vector3.new(0.5, 0, 0), Vector3.new(0.09, 0.034, 0.034), colors.side)
		b:body("Head", Vector3.new(-0.15, 0, 0), Vector3.new(0.14, 0.11, 0.12), colors.side)
		b:ellipsoid("Collar", CFrame.new(-0.11, 0, 0), Vector3.new(0.06, 0.13, 0.135), colors.back)
		local finColor = rgb(214, 152, 136)
		-- Rhomboid fins wrapping the rear third of the mantle.
		for _, side in { 1, -1 } do
			b:fin({
				Vector3.new(0.53, 0, 0),
				Vector3.new(0.45, 0, side * 0.1),
				Vector3.new(0.38, 0, side * 0.135),
				Vector3.new(0.3, 0, side * 0.09),
				Vector3.new(0.25, 0, side * 0.03),
				Vector3.new(0.25, 0, 0),
			}, finColor, 0.12)
		end
		b:speckle(70, v2(-0.08, 0.5), v2(-0.07, 0.075), v2(0.007, 0.016), rgb(128, 52, 46))
		b:stroke({ v2(0.48, 0.02), v2(0.0, 0.07) }, 0.006, rgb(150, 70, 62))
		b:eye(-0.15, 0.008, 0.07, rgb(172, 192, 204))
		local armColor = rgb(212, 142, 128)
		for index = 0, 7 do
			local angle = index / 8 * math.pi * 2
			local spread = Vector3.new(0, math.cos(angle), math.sin(angle))
			local root = Vector3.new(-0.2, 0, 0) + spread * 0.035
			local middle = Vector3.new(-0.34, -0.01, 0) + spread * 0.055
			local tip = Vector3.new(-0.47 + math.abs(math.sin(angle)) * 0.03, -0.03, 0) + spread * 0.045
			b:limb(root, middle, 0.028, armColor, "Arm")
			b:limb(middle, tip, 0.017, armColor, "Arm")
			for step = 1, 3 do
				local sucker = root:Lerp(middle, step / 4) - spread * 0.012
				b:ellipsoid("Sucker", CFrame.new(sucker), Vector3.one * 0.008, rgb(238, 210, 196))
			end
		end
		for _, side in { 1, -1 } do
			local root, middle = Vector3.new(-0.2, -0.01, side * 0.015), Vector3.new(-0.42, -0.05, side * 0.04)
			local club = Vector3.new(-0.62, -0.03, side * 0.05)
			b:limb(root, middle, 0.012, armColor, "Tentacle")
			b:limb(middle, club, 0.01, armColor, "Tentacle")
			b:ellipsoid(
				"TentacleClub",
				CFrame.lookAt(club, club + Vector3.xAxis),
				Vector3.new(0.022, 0.026, 0.07),
				armColor
			)
		end
		b.model:SetAttribute("ViewDirection", Vector3.new(0.1, 0.65, 1))
	end,
}

end)()
species["AtlanticSailfish"] = (function()
return {
	Name = "Atlantic Sailfish",
	Rarity = "Epic",
	RarityDenominator = 35,
	MinKg = 8,
	AverageKg = 28,
	MaxKg = 100,
	LengthScale = 1.55,
	BaseValue = 340,
	Fight = 0.08,
	Pools = { "OpenSea" },
	Seasons = { "Summer", "Autumn" },
	Requires = { "Clear", "Day" },
	Shapes = {
		Normal = { ".##.", "####" },
		Big = { ".###.", "#####" },
		Huge = { ".####.", "######" },
	},
	-- A cobalt sail rises far above the slender striped silver body.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(22, 40, 82), side = rgb(106, 152, 190), belly = rgb(230, 238, 240) }
		local fin, sail = rgb(22, 50, 104), rgb(26, 82, 164)
		b:fishBody(0.155, 0.09, colors, 0.02)
		local dorsal = b:edgeFin(0.26, -0.24, { 0.21, 0.32, 0.35, 0.34, 0.31, 0.27, 0.22, 0.14 }, sail, false, 0.08)
		for index = 3, #dorsal - 1 do
			local tip = dorsal[index]
			local root = v2(tip.X, b:top(tip.X))
			b:rays(root, { tip }, rgb(18, 40, 92))
			b:finSpot(tip.X + 0.015, root.Y + (tip.Y - root.Y) * 0.55, 0.018, rgb(14, 28, 66))
		end
		b:edgeFin(-0.25, -0.3, { 0.025 }, fin)
		b:edgeFin(0.02, -0.18, { 0.075, 0.05, 0.025 }, fin, true)
		b:edgeFin(-0.25, -0.3, { 0.025 }, fin, true)
		b:lunateTail(0.21, fin)
		b:pectoral(0.23, -0.03, 0.16, 0.035, fin)
		for _, side in { 1, -1 } do
			local root = Vector3.new(0.17, b:bottom(0.17), side * 0.012)
			b:limb(root, Vector3.new(-0.12, -0.17, side * 0.024), 0.006, fin, "PelvicFilament")
		end
		for x = 0.23, -0.28, -0.045 do
			b:stroke({ v2(x, b:top(x) * 0.75), v2(x - 0.012, b:bottom(x) * 0.3) }, 0.007, rgb(62, 132, 210))
		end
		b:limb(Vector3.new(0.44, 0.006, 0), Vector3.new(0.84, 0.001, 0), 0.018, colors.back, "Bill")
		b:face(0.37, 0.02, 0.042, rgb(164, 184, 202), rgb(52, 78, 112))
	end,
}

end)()
species["AtlanticSalmon"] = (function()
return {
	Name = "Atlantic Salmon",
	Rarity = "Rare",
	RarityDenominator = 14,
	MinKg = 1,
	AverageKg = 4.5,
	MaxKg = 25,
	BaseValue = 144,
	Fight = 0.07,
	Pools = { "MainLake", "FrostmereExpanse" },
	Seasons = { "Spring", "Autumn", "Winter" },
	Requires = { "Rain" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Silver flanks, dark cross-shaped spots and a narrow tail wrist.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(50, 76, 86), side = rgb(176, 192, 196), belly = rgb(236, 240, 234) }
		local fin, spot = rgb(92, 112, 116), rgb(36, 46, 44)
		b:fishBody(0.22, 0.12, colors, 0.05)
		b:edgeFin(0.08, -0.08, { 0.085, 0.08, 0.055, 0.035 }, fin)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.25, b:top(-0.25) + 0.008, 0), Vector3.new(0.055, 0.035, 0.014), fin)
		b:edgeFin(-0.12, -0.25, { 0.06, 0.055, 0.035 }, fin, true)
		b:edgeFin(0.02, -0.06, { 0.05, 0.04 }, fin, true)
		b:forkTail(0.12, 0.04, fin)
		b:pectoral(0.22, -0.045, 0.11, 0.04, fin)
		for _ = 1, 18 do
			local x, y = b.random(-0.28, 0.3), b.random(0.005, 0.075)
			b:stroke({ v2(x - 0.007, y - 0.007), v2(x + 0.007, y + 0.007) }, 0.005, spot)
			b:stroke({ v2(x - 0.007, y + 0.007), v2(x + 0.007, y - 0.007) }, 0.005, spot)
		end
		b:stroke({ v2(0.28, -0.012), v2(0, -0.016), v2(-0.28, -0.008) }, 0.005, fin)
		b:face(0.38, 0.025, 0.04, rgb(208, 194, 132), fin)
	end,
}


end)()
species["AuroraRockfish"] = (function()
return {
	Name = "Aurora Rockfish",
	Rarity = "Rare",
	RarityDenominator = 16,
	MinKg = 0.3,
	AverageKg = 0.8,
	MaxKg = 2.5,
	BaseValue = 142,
	Fight = 0.04,
	Pools = { "FrostmereExpanse" },
	Seasons = { "Autumn", "Winter" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Rose-red body, dusky mottling and large golden eyes.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(134, 58, 60), side = rgb(216, 116, 102), belly = rgb(246, 206, 182) }
		local fin = rgb(176, 76, 68)
		b:fishBody(0.28, 0.14, colors, 0.08)
		b:layered("LowerJaw", Vector3.new(0.405, -0.052, 0), Vector3.new(0.17, 0.075, 0.09100000000000001), colors)
		local spines = b:edgeFin(0.2, -0.08, { 0.045, 0.09, 0.105, 0.10, 0.085, 0.07, 0.04 }, fin)
		for index = 3, #spines - 1 do
			local tip = spines[index]
			b:rays(v2(tip.X, b:top(tip.X)), { tip }, colors.back)
		end
		b:edgeFin(-0.08, -0.27, { 0.075, 0.085, 0.07, 0.04 }, fin, false, 0.05)
		b:edgeFin(-0.08, -0.25, { 0.065, 0.07, 0.045 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.055, 0.04 }, fin, true)
		b:roundTail(0.13, fin)
		b:pectoral(0.24, -0.045, 0.15, 0.065, fin)
		b:speckle(24, v2(-0.3, 0.3), v2(-0.09, 0.12), v2(0.014, 0.032), rgb(112, 48, 54))
		-- A raised brow and short cheek spines distinguish the rockfish head.
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.34, 0.07, side * 0.042), Vector3.new(0.30, 0.092, side * 0.049), 0.013, colors.back, "Brow")
			b:limb(Vector3.new(0.26, -0.005, side * 0.06720000000000001), Vector3.new(0.20, -0.015, side * 0.09100000000000001), 0.012, fin, "CheekSpine")
		end
		b:face(0.37, 0.045, 0.061, rgb(234, 198, 114), colors.back)
	end,
}


end)()
species["Batfish"] = (function()
return {
	Name = "Batfish",
	Rarity = "Uncommon",
	RarityDenominator = 12,
	MinKg = 0.2,
	AverageKg = 0.8,
	MaxKg = 4,
	BaseValue = 34,
	Fight = 0.04,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Requires = { "Rain" },
	Shapes = {
		Normal = { "#" },
		Big = { "#", "#" },
		Huge = { "#.", "##", "#." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(96, 96, 100), side = rgb(196, 198, 196), belly = rgb(232, 232, 226) }
		local fin = rgb(58, 56, 62)
		local dark = rgb(34, 32, 38)
		local pale = rgb(206, 206, 200)
		-- Wider, strongly compressed disc body with a small head; the extra
		-- Z depth keeps it looking chunky from the side and full head-on.
		b:fishBody(0.52, 0.14, colors, 0.12)
		-- Tall leading dorsal lobe and long-based anal fin, both dark like a
		-- spadefish, with ray rods fanning through the membranes.
		b:edgeFin(0.16, -0.18, { 0.13, 0.17, 0.15, 0.1, 0.07, 0.05 }, fin, false, 0.05)
		b:edgeFin(0.02, -0.16, { 0.11, 0.1, 0.07, 0.05 }, fin, true, 0.05)
		b:rays(v2(0.08, b:top(0.08) + 0.01), { v2(-0.02, b:top(-0.02) + 0.16), v2(-0.09, b:top(-0.09) + 0.12), v2(-0.16, b:top(-0.16) + 0.06) }, rgb(78, 76, 82))
		b:rays(v2(0.06, b:bottom(0.06) - 0.01), { v2(-0.04, b:bottom(-0.04) - 0.11), v2(-0.12, b:bottom(-0.12) - 0.06) }, rgb(78, 76, 82))
		-- Short pelvic filaments dangling below the chest.
		for _, side in { 1, -1 } do
			b:limb(
				Vector3.new(0.16, b:bottom(0.16) + 0.02, side * 0.02),
				Vector3.new(0.1, b:bottom(0.16) - 0.17, side * 0.04),
				0.008,
				fin,
				"Filament"
			)
			b:limb(
				Vector3.new(0.12, b:bottom(0.12) + 0.015, side * 0.018),
				Vector3.new(0.06, b:bottom(0.12) - 0.12, side * 0.03),
				0.006,
				fin,
				"Filament"
			)
		end
		b:forkTail(0.14, 0.04, fin)
		b:pectoral(0.2, -0.02, 0.1, 0.04, fin, 0.2)
		-- Pale margin along the trailing edges of the dark fins.
		b:stroke({ v2(-0.17, b:top(-0.17) + 0.13), v2(-0.2, b:top(-0.2) + 0.035) }, 0.014, pale)
		b:stroke({ v2(-0.15, b:bottom(-0.15) - 0.1), v2(-0.18, b:bottom(-0.18) - 0.03) }, 0.014, pale)
		-- Two to three broad dark vertical bands across the silvery flank,
		-- each one slightly wavy with a paler inner core like juvenile spades.
		b:stroke({ v2(0.2, b:top(0.2) - 0.012), v2(0.19, b:bottom(0.19) + 0.012) }, 0.06, dark)
		b:stroke({ v2(0.205, b:top(0.205) - 0.03), v2(0.19, 0.0) }, 0.022, rgb(120, 118, 120))
		b:stroke({ v2(-0.02, b:top(-0.02) - 0.012), v2(-0.03, b:bottom(-0.03) + 0.012) }, 0.075, dark)
		b:stroke({ v2(-0.015, b:top(-0.015) - 0.03), v2(-0.03, 0.0) }, 0.026, rgb(120, 118, 120))
		b:stroke({ v2(-0.22, b:top(-0.22) - 0.012), v2(-0.23, b:bottom(-0.23) + 0.012) }, 0.055, dark)
		b:stroke({ v2(-0.215, b:top(-0.215) - 0.025), v2(-0.228, 0.0) }, 0.018, rgb(120, 118, 120))
		-- Soft speckling over the back between the bands, plus a silver
		-- shimmer of tiny bright flecks along the upper flank.
		b:speckle(28, v2(-0.3, 0.3), v2(0.02, 0.2), v2(0.008, 0.016), rgb(120, 120, 126))
		b:speckle(18, v2(-0.28, 0.32), v2(0.0, 0.14), v2(0.005, 0.009), rgb(240, 242, 240))
		-- Faint darker edging above each eye for the classic spadefish brow.
		b:marks(0.37, 0.09, 0.05, 0.014, rgb(96, 94, 98))
		-- Small protruding mouth and a bright silvery iris.
		b:face(0.37, 0.05, 0.045, rgb(214, 210, 190), rgb(140, 138, 130))
		b:marks(0.45, -0.045, 0.032, 0.02, rgb(52, 48, 50))
		-- Chin barbel bump and a pale pelvic patch between the filaments.
		b:marks(0.42, b:bottom(0.42) * 0.6, 0.02, 0.016, rgb(148, 146, 148))
	end,
}

end)()
species["BlackBullhead"] = (function()
return {
	Name = "Black Bullhead",
	Rarity = "Common",
	RarityDenominator = 5,
	MinKg = 0.1,
	AverageKg = 0.65,
	MaxKg = 3.5,
	BaseValue = 17,
	Fight = 0.04,
	Pools = { "MainLake", "SoddenMire" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(28, 32, 26), side = rgb(64, 70, 48), belly = rgb(182, 176, 122) }
		local fin, whisker = rgb(46, 52, 38), rgb(24, 28, 22)
		b:fishBody(0.235, 0.21, colors, 0.16)
		local dorsal = b:edgeFin(0.15, 0.025, { 0.11, 0.075, 0.045 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3] }, colors.back)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.23, b:top(-0.23) + 0.006, 0), Vector3.new(0.1, 0.032, 0.015), fin)
		b:edgeFin(-0.02, -0.31, { 0.045, 0.055, 0.055, 0.055, 0.045 }, fin, true)
		b:edgeFin(0.06, -0.005, { 0.045 }, fin, true)
		b:roundTail(0.115, fin)
		b:pectoral(0.24, -0.05, 0.12, 0.045, fin)
		-- Paired long maxillary barbels and four shorter chin barbels.
		for _, side in { 1, -1 } do
			local bend = Vector3.new(0.35, -0.055, side * 0.15)
			b:limb(Vector3.new(0.46, -0.01, side * 0.035), bend, 0.009, whisker, "Barbel")
			b:limb(bend, Vector3.new(0.2, -0.13, side * 0.18), 0.006, whisker, "Barbel")
			for _, z in { 0.015, 0.04 } do
				local chin = b:bottom(0.44)
				b:limb(Vector3.new(0.44, chin + 0.006, side * z), Vector3.new(0.4, chin - 0.055, side * z * 1.7), 0.006, whisker, "Barbel")
			end
		end
		-- Pale tail-base bar contrasts with the nearly black body.
		b:marks(-0.3, 0, 0.035, 0.065, rgb(146, 146, 92))
		b:face(0.4, 0.018, 0.031, rgb(156, 146, 72), colors.back)
	end,
}

end)()
species["BlackGrouper"] = (function()
return {
	Name = "Black Grouper",
	Rarity = "Epic",
	RarityDenominator = 30,
	MinKg = 3,
	AverageKg = 14,
	MaxKg = 90,
	LengthScale = 1.1,
	BaseValue = 350,
	Fight = 0.08,
	Pools = { "CoralShallows", "PirateCove" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "###", "###" },
		Big = { "####", "####" },
		Huge = { "#####", "#####" },
	},
	-- Broad olive-grey grouper with rectangular charcoal blotches and a dark rounded tail.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(50, 52, 44), side = rgb(104, 108, 88), belly = rgb(194, 192, 160) }
		local fin = rgb(46, 50, 42)
		b:fishBody(0.34, 0.19, colors, 0.075)
		local dorsal = b:edgeFin(0.17, -0.22, { 0.055, 0.075, 0.07, 0.06, 0.055, 0.065, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, colors.back)
		b:edgeFin(-0.08, -0.24, { 0.065, 0.075, 0.055 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.06, 0.045 }, fin, true)
		b:roundTail(0.135, fin)
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		for _, x in { 0.19, 0.07, -0.05, -0.18, -0.28 } do
			for _, y in { -0.06, 0.025, 0.09 } do
				b:marks(x, y, 0.068, 0.046, rgb(46, 48, 40))
			end
		end
		b:stroke({ v2(0.47, -0.035), v2(0.34, -0.07) }, 0.014, rgb(36, 38, 32))
		b:face(0.37, 0.04, 0.043, rgb(188, 174, 94), colors.back)
	end,
}

end)()
species["BlackMarlin"] = (function()
return {
	Name = "Black Marlin",
	Rarity = "Legendary",
	RarityDenominator = 160,
	MinKg = 40,
	AverageKg = 180,
	MaxKg = 750,
	LengthScale = 1.65,
	BaseValue = 1200,
	Fight = 0.12,
	Pools = { "CinderIsles" },
	Seasons = { "Summer", "Autumn" },
	Requires = { "Day" },
	Shapes = {
		Normal = { "#####", ".###." },
		Big = { "######", ".####." },
		Huge = { "#######", "#######" },
	},
	-- Heavy dark shoulders and rigid lateral pectorals distinguish this marlin.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(20, 27, 34), side = rgb(80, 98, 108), belly = rgb(210, 220, 224) }
		local fin = rgb(28, 38, 48)
		b:fishBody(0.235, 0.16, colors, 0.02)
		b:layered("Shoulder", Vector3.new(0.18, 0.02, 0), Vector3.new(0.42, 0.245, 0.17), colors)
		b:edgeFin(0.25, -0.23, { 0.11, 0.13, 0.09, 0.045, 0.025, 0.02, 0.016 }, fin)
		b:edgeFin(-0.25, -0.3, { 0.035 }, fin)
		b:edgeFin(0.0, -0.14, { 0.08, 0.055, 0.025 }, fin, true)
		b:edgeFin(-0.25, -0.3, { 0.03 }, fin, true)
		b:lunateTail(0.24, fin)
		for _, side in { 1, -1 } do
			b:fin({
				Vector3.new(0.24, -0.015, side * 0.075),
				Vector3.new(0.10, -0.055, side * 0.30),
				Vector3.new(0.17, -0.065, side * 0.105),
			}, fin)
			b:limb(Vector3.new(0.16, b:bottom(0.16), side * 0.014), Vector3.new(-0.02, -0.19, side * 0.03), 0.008, fin, "PelvicFin")
			b:ellipsoid("TailKeel", CFrame.new(-0.32, 0, side * 0.025), Vector3.new(0.10, 0.018, 0.03), fin)
		end
		b:stroke({ v2(0.27, 0.02), v2(0.08, 0.015), v2(-0.26, 0.0) }, 0.006, rgb(122, 146, 158))
		b:limb(Vector3.new(0.43, 0.008, 0), Vector3.new(0.78, 0.001, 0), 0.03, colors.back, "Bill")
		b:face(0.37, 0.035, 0.047, rgb(134, 150, 148), rgb(40, 52, 62))
	end,
}

end)()
species["BlackRockfish"] = (function()
return {
	Name = "Black Rockfish",
	Rarity = "Uncommon",
	RarityDenominator = 8,
	MinKg = 0.4,
	AverageKg = 1.5,
	MaxKg = 5,
	BaseValue = 54,
	Fight = 0.04,
	Pools = { "MainLake", "FrostmereExpanse" },
	Seasons = { "Spring", "Summer", "Autumn", "Winter" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Charcoal back, slate flanks and irregular pale flecks.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(42, 49, 52), side = rgb(90, 100, 106), belly = rgb(190, 196, 196) }
		local fin = rgb(58, 66, 72)
		b:fishBody(0.29, 0.15, colors, 0.08)
		b:layered("LowerJaw", Vector3.new(0.405, -0.052, 0), Vector3.new(0.17, 0.075, 0.0975), colors)
		local spines = b:edgeFin(0.2, -0.08, { 0.045, 0.09, 0.105, 0.10, 0.085, 0.07, 0.04 }, fin)
		for index = 3, #spines - 1 do
			local tip = spines[index]
			b:rays(v2(tip.X, b:top(tip.X)), { tip }, colors.back)
		end
		b:edgeFin(-0.08, -0.27, { 0.075, 0.085, 0.07, 0.04 }, fin, false, 0.05)
		b:edgeFin(-0.08, -0.25, { 0.065, 0.07, 0.045 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.055, 0.04 }, fin, true)
		b:forkTail(0.14, 0.025, fin)
		b:pectoral(0.24, -0.045, 0.15, 0.065, fin)
		b:speckle(24, v2(-0.3, 0.3), v2(-0.09, 0.12), v2(0.014, 0.032), rgb(154, 162, 164))
		-- A raised brow and short cheek spines distinguish the rockfish head.
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.34, 0.07, side * 0.045), Vector3.new(0.30, 0.092, side * 0.0525), 0.013, colors.back, "Brow")
			b:limb(Vector3.new(0.26, -0.005, side * 0.072), Vector3.new(0.20, -0.015, side * 0.0975), 0.012, fin, "CheekSpine")
		end
		b:face(0.37, 0.045, 0.044, rgb(186, 176, 136), colors.back)
	end,
}


end)()
species["BlackSeabass"] = (function()
return {
	Name = "Black Seabass",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.3,
	AverageKg = 1.2,
	MaxKg = 4.5,
	BaseValue = 46,
	Fight = 0.04,
	Pools = { "MainLake", "CoralShallows" },
	Seasons = { "Spring", "Summer" },
	Requires = { "Day" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####", "####" },
	},
	-- Charcoal sea bass with a tall spiny dorsal, turquoise flecks and blue fin margins.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(30, 40, 42), side = rgb(62, 78, 82), belly = rgb(170, 182, 176) }
		local fin = rgb(32, 52, 58)
		b:fishBody(0.29, 0.13, colors, 0.075)
		local dorsal = b:edgeFin(0.17, -0.22, { 0.055, 0.075, 0.07, 0.06, 0.055, 0.065, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, colors.back)
		b:edgeFin(-0.08, -0.24, { 0.065, 0.075, 0.055 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.06, 0.045 }, fin, true)
		b:roundTail(0.115, fin)
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		b:speckle(44, v2(-0.3, 0.28), v2(-0.09, 0.11), v2(0.006, 0.012), rgb(104, 172, 180))
		b:edgeFin(0.16, -0.18, { 0.09, 0.12, 0.1, 0.07, 0.09, 0.1 }, rgb(74, 128, 148), false, 0.15)
		b:stroke({ v2(0.24, -0.025), v2(0.02, -0.035), v2(-0.27, -0.02) }, 0.006, rgb(124, 150, 156))
		b:face(0.37, 0.04, 0.043, rgb(166, 180, 162), colors.back)
	end,
}

end)()
species["BlackflagGrouper"] = (function()
return {
	Name = "Blackflag Grouper",
	Rarity = "Epic",
	RarityDenominator = 30,
	MinKg = 6,
	AverageKg = 25,
	MaxKg = 120,
	BaseValue = 400,
	Fight = 0.07,
	Pools = { "PirateCove" },
	Seasons = { "Spring", "Summer", "Autumn", "Winter" },
	Shapes = {
		Normal = { "###", "###" },
		Big = { "####", "####" },
		Huge = { "#####", "#####" },
	},
	-- A huge coal-black grouper that lurks under the cove's pier. Every one carries a pale skull
	-- and crossbones on its flank, which is how the cove got its flag.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(28, 28, 32), side = rgb(62, 60, 66), belly = rgb(146, 142, 136) }
		local fin = rgb(40, 38, 44)
		local bone, socket = rgb(236, 230, 214), rgb(18, 16, 18)
		b:fishBody(0.32, 0.17, colors, 0.06)
		local spines = b:edgeFin(0.16, -0.04, { 0.05, 0.065, 0.06, 0.055, 0.05 }, fin, false, 0.05)
		b:rays(spines[1], { spines[3], spines[4], spines[5] }, rgb(20, 20, 24))
		b:edgeFin(-0.04, -0.24, { 0.06, 0.07, 0.06, 0.04 }, fin, false, 0.05)
		b:edgeFin(-0.08, -0.24, { 0.06, 0.06, 0.04 }, fin, true, 0.05)
		b:edgeFin(0.12, 0.02, { 0.06, 0.04 }, fin, true, 0.1)
		b:roundTail(0.12, fin)
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		-- Crossbones first, the skull over them, then its eye sockets on top.
		b:stroke({ v2(-0.09, -0.06), v2(0.07, 0.05) }, 0.014, bone)
		b:stroke({ v2(-0.09, 0.05), v2(0.07, -0.06) }, 0.014, bone)
		for _, side in { 1, -1 } do
			b:mark(-0.01, 0.015, side, 0.075, 0.065, bone, nil, 0.001)
			b:mark(-0.01, -0.025, side, 0.045, 0.03, bone, nil, 0.001)
			b:mark(-0.025, 0.02, side, 0.018, 0.02, socket, nil, 0.002)
			b:mark(0.005, 0.02, side, 0.018, 0.02, socket, nil, 0.002)
		end
		b:speckle(18, v2(0.3, -0.3), v2(-0.08, 0.1), v2(0.008, 0.016), rgb(86, 84, 90))
		b:face(0.37, 0.04, 0.05, rgb(200, 44, 32), rgb(20, 20, 24))
	end,
}

end)()
species["BlackgillRockfish"] = (function()
return {
	Name = "Blackgill Rockfish",
	Rarity = "Rare",
	RarityDenominator = 20,
	MinKg = 0.5,
	AverageKg = 2.2,
	MaxKg = 6,
	BaseValue = 156,
	Fight = 0.05,
	Pools = { "CinderIsles", "PirateCove" },
	Seasons = { "Autumn", "Winter" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Brick-red body with a conspicuous coal-dark gill cover.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(124, 54, 48), side = rgb(192, 98, 86), belly = rgb(232, 178, 154) }
		local fin = rgb(156, 62, 58)
		b:fishBody(0.3, 0.16, colors, 0.08)
		b:layered("LowerJaw", Vector3.new(0.405, -0.052, 0), Vector3.new(0.17, 0.075, 0.10400000000000001), colors)
		local spines = b:edgeFin(0.2, -0.08, { 0.045, 0.09, 0.105, 0.10, 0.085, 0.07, 0.04 }, fin)
		for index = 3, #spines - 1 do
			local tip = spines[index]
			b:rays(v2(tip.X, b:top(tip.X)), { tip }, colors.back)
		end
		b:edgeFin(-0.08, -0.27, { 0.075, 0.085, 0.07, 0.04 }, fin, false, 0.05)
		b:edgeFin(-0.08, -0.25, { 0.065, 0.07, 0.045 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.055, 0.04 }, fin, true)
		b:forkTail(0.14, 0.025, fin)
		b:pectoral(0.24, -0.045, 0.15, 0.065, fin)
		b:marks(0.25, 0.015, 0.075, 0.105, rgb(54, 37, 38))
		-- A raised brow and short cheek spines distinguish the rockfish head.
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.34, 0.07, side * 0.048), Vector3.new(0.30, 0.092, side * 0.055999999999999994), 0.013, colors.back, "Brow")
			b:limb(Vector3.new(0.26, -0.005, side * 0.0768), Vector3.new(0.20, -0.015, side * 0.10400000000000001), 0.012, fin, "CheekSpine")
		end
		b:face(0.37, 0.045, 0.058, rgb(232, 176, 88), colors.back)
	end,
}


end)()
species["BlueCatfish"] = (function()
return {
	Name = "Blue Catfish",
	Rarity = "Rare",
	RarityDenominator = 16,
	MinKg = 1,
	AverageKg = 12,
	MaxKg = 65,
	BaseValue = 88,
	Fight = 0.11,
	Pools = { "MainLake", "SoddenMire" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", "####" },
		Huge = { "######", "######" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(42, 66, 90), side = rgb(132, 166, 188), belly = rgb(232, 236, 230) }
		local fin, whisker = rgb(86, 124, 154), rgb(146, 174, 184)
		b:fishBody(0.235, 0.2, colors, 0.1)
		local dorsal = b:edgeFin(0.15, 0.025, { 0.11, 0.075, 0.045 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3] }, colors.back)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.23, b:top(-0.23) + 0.006, 0), Vector3.new(0.1, 0.032, 0.015), fin)
		b:edgeFin(-0.02, -0.31, { 0.045, 0.055, 0.055, 0.055, 0.045 }, fin, true)
		b:edgeFin(0.06, -0.005, { 0.045 }, fin, true)
		b:forkTail(0.13, 0.075, fin)
		b:pectoral(0.24, -0.05, 0.12, 0.045, fin)
		-- Paired long maxillary barbels and four shorter chin barbels.
		for _, side in { 1, -1 } do
			local bend = Vector3.new(0.35, -0.055, side * 0.15)
			b:limb(Vector3.new(0.46, -0.01, side * 0.035), bend, 0.009, whisker, "Barbel")
			b:limb(bend, Vector3.new(0.2, -0.13, side * 0.18), 0.006, whisker, "Barbel")
			for _, z in { 0.015, 0.04 } do
				local chin = b:bottom(0.44)
				b:limb(Vector3.new(0.44, chin + 0.006, side * z), Vector3.new(0.4, chin - 0.055, side * z * 1.7), 0.006, whisker, "Barbel")
			end
		end
		-- Long, straight-edged anal fin and deeply forked blue tail.
		b:stroke({ v2(0.25, 0.025), v2(-0.05, 0.02), v2(-0.29, 0.005) }, 0.006, rgb(102, 140, 166))
		b:face(0.4, 0.018, 0.031, rgb(158, 176, 154), colors.back)
	end,
}

end)()
species["BlueCrab"] = (function()
return {
	Name = "Blue Crab",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.15,
	AverageKg = 0.45,
	MaxKg = 1.8,
	BaseValue = 26,
	Fight = 0,
	Shapes = {
		Normal = { "##" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb, crab = kit.rgb, kit.crab
		crab(b, {
			shell = rgb(96, 122, 112),
			dark = rgb(70, 96, 92),
			belly = rgb(236, 230, 214),
			clawColor = rgb(66, 128, 196),
			legColor = rgb(84, 142, 196),
			tipColor = rgb(206, 70, 50),
			carapace = Vector3.new(0.34, 0.12, 0.6),
			teeth = 7,
			lateral = 0.1,
			claw = 1.05,
			legs = {
				lean = { 0.6, 0.2, -0.2, -0.95 },
				thigh = 0.16,
				shin = 0.16,
				lift = 0.06,
				drop = 0.15,
				width = 0.032,
				paddle = true,
			},
			spots = { count = 14, size = Vector2.new(0.01, 0.022), color = rgb(122, 146, 128) },
		})
	end,
}

end)()
species["BlueMackerel"] = (function()
return {
	Name = "Blue Mackerel",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.2,
	AverageKg = 0.6,
	MaxKg = 2.5,
	BaseValue = 11,
	Fight = 0.05,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(32, 92, 118), side = rgb(158, 182, 192), belly = rgb(238, 240, 240) }
		local fin = rgb(72, 94, 104)
		b:fishBody(0.17, 0.11, colors, 0.03)
		local spines = b:edgeFin(0.11, -0.01, { 0.07, 0.065, 0.05, 0.035 }, fin, false, 0.1)
		b:rays(spines[1], { spines[4], spines[5], spines[6] }, rgb(40, 56, 64))
		b:edgeFin(-0.08, -0.14, { 0.04, 0.03 }, fin)
		b:edgeFin(-0.08, -0.14, { 0.04, 0.03 }, fin, true)
		for index = 0, 4 do
			local x = -0.17 - index * 0.028
			for _, below in { false, true } do
				local edge = if below then b:bottom(x) else b:top(x)
				local sign = if below then -1 else 1
				b:fin({
					v2(x + 0.008, edge - sign * 0.004),
					v2(x - 0.012, edge + sign * 0.02),
					v2(x - 0.014, edge - sign * 0.004),
				}, rgb(196, 184, 96))
			end
		end
		b:forkTail(0.13, 0.085, fin)
		b:pectoral(0.21, -0.02, 0.09, 0.03, fin)
		for x = 0.21, -0.3, -0.04 do
			local top = b:top(x)
			b:stroke({ v2(x, top * 0.88), v2(x - 0.022, top * 0.52), v2(x + 0.004, top * 0.18) }, 0.007, rgb(16, 36, 50))
		end
		for x = 0.16, -0.26, -0.05 do
			b:marks(x, -0.03 + math.sin(x * 40) * 0.006, 0.012, 0.012, rgb(112, 126, 136))
		end
		b:face(0.375, 0.015, 0.052, rgb(196, 204, 196), rgb(90, 108, 118))
	end,
}

end)()
species["BlueMarlin"] = (function()
return {
	Name = "Blue Marlin",
	Rarity = "Legendary",
	RarityDenominator = 140,
	MinKg = 30,
	AverageKg = 140,
	MaxKg = 650,
	LengthScale = 1.65,
	BaseValue = 1050,
	Fight = 0.11,
	Pools = { "OpenSea" },
	Seasons = { "Summer", "Autumn" },
	Requires = { "Clear", "Day" },
	Shapes = {
		Normal = { "#####", ".###." },
		Big = { "######", ".####." },
		Huge = { "#######", "#######" },
	},
	-- Cobalt shoulders, faint blue bars and a tall pointed first dorsal.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(16, 42, 92), side = rgb(86, 148, 190), belly = rgb(226, 236, 240) }
		local fin = rgb(22, 48, 100)
		b:fishBody(0.225, 0.145, colors, 0.02)
		b:edgeFin(0.25, -0.24, { 0.17, 0.22, 0.13, 0.06, 0.03, 0.025, 0.02 }, fin)
		b:edgeFin(-0.25, -0.3, { 0.035 }, fin)
		b:edgeFin(0.0, -0.15, { 0.085, 0.05, 0.025 }, fin, true)
		b:edgeFin(-0.25, -0.3, { 0.03 }, fin, true)
		b:lunateTail(0.23, fin)
		b:pectoral(0.23, -0.035, 0.22, 0.05, fin)
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.16, b:bottom(0.16), side * 0.012), Vector3.new(-0.08, -0.18, side * 0.025), 0.007, fin, "PelvicFin")
			b:ellipsoid("TailKeel", CFrame.new(-0.32, 0, side * 0.023), Vector3.new(0.10, 0.018, 0.028), colors.back)
		end
		for x = 0.2, -0.27, -0.055 do
			b:stroke({ v2(x, b:top(x) * 0.7), v2(x - 0.015, b:bottom(x) * 0.4) }, 0.009, rgb(62, 128, 184))
		end
		b:limb(Vector3.new(0.44, 0.008, 0), Vector3.new(0.83, 0.002, 0), 0.025, colors.back, "Bill")
		b:face(0.37, 0.032, 0.045, rgb(148, 180, 202), rgb(46, 78, 122))
	end,
}

end)()
species["BlueMussel"] = (function()
return {
	Name = "Blue Mussel",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.03,
	AverageKg = 0.12,
	MaxKg = 0.6,
	BaseValue = 18,
	Fight = 0,
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	Build = function(b, kit)
		local rgb, mussel = kit.rgb, kit.mussel
		mussel(b, rgb(34, 52, 76), rgb(95, 122, 151))
	end,
}

end)()
species["Bluegill"] = (function()
return {
	Name = "Bluegill",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.1,
	AverageKg = 0.35,
	MaxKg = 2,
	BaseValue = 20,
	Fight = 0,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(58, 76, 58), side = rgb(112, 124, 86), belly = rgb(224, 150, 60) }
		local fin = rgb(82, 92, 70)
		b:fishBody(0.42, 0.13, colors, 0.1)
		local dorsal =
			b:edgeFin(0.13, -0.24, { 0.07, 0.05, 0.075, 0.05, 0.075, 0.055, 0.08, 0.1, 0.11, 0.09 }, fin, false, 0.08)
		b:rays(dorsal[1], { dorsal[4], dorsal[6], dorsal[8], dorsal[10] }, rgb(46, 52, 42))
		b:edgeFin(-0.05, -0.24, { 0.06, 0.08, 0.09, 0.07 }, fin, true, 0.08)
		b:edgeFin(0.08, -0.02, { 0.07, 0.06 }, fin, true)
		b:forkTail(0.15, 0.03, fin, 0.05)
		b:pectoral(0.2, -0.04, 0.15, 0.04, rgb(150, 140, 96), 0.15)
		for _, x in { 0.15, 0.07, -0.01, -0.09, -0.17, -0.24 } do
			b:stroke({ v2(x + 0.01, b:top(x) - 0.02), v2(x - 0.01, -0.06) }, 0.03, rgb(40, 50, 36))
		end
		b:stroke({ v2(0.43, -0.02), v2(0.33, -0.05) }, 0.012, rgb(88, 110, 156))
		b:stroke({ v2(0.43, -0.05), v2(0.34, -0.09) }, 0.012, rgb(88, 110, 156))
		b:marks(0.235, 0.035, 0.065, 0.055, rgb(18, 18, 22))
		b:face(0.38, 0.05, 0.05, rgb(46, 40, 36), rgb(70, 80, 56))
	end,
}

end)()
species["Bocaccio"] = (function()
return {
	Name = "Bocaccio",
	Rarity = "Rare",
	RarityDenominator = 18,
	MinKg = 0.8,
	AverageKg = 3.5,
	MaxKg = 12,
	BaseValue = 162,
	Fight = 0.07,
	Pools = { "FrostmereExpanse", "CinderIsles" },
	Seasons = { "Spring", "Autumn", "Winter" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Elongated copper-pink profile and a projecting lower jaw.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(132, 78, 62), side = rgb(202, 140, 112), belly = rgb(242, 214, 184) }
		local fin = rgb(162, 94, 76)
		b:fishBody(0.25, 0.14, colors, 0.08)
		b:layered("LowerJaw", Vector3.new(0.435, -0.052, 0), Vector3.new(0.21, 0.075, 0.09100000000000001), colors)
		local spines = b:edgeFin(0.2, -0.08, { 0.045, 0.09, 0.105, 0.10, 0.085, 0.07, 0.04 }, fin)
		for index = 3, #spines - 1 do
			local tip = spines[index]
			b:rays(v2(tip.X, b:top(tip.X)), { tip }, colors.back)
		end
		b:edgeFin(-0.08, -0.27, { 0.075, 0.085, 0.07, 0.04 }, fin, false, 0.05)
		b:edgeFin(-0.08, -0.25, { 0.065, 0.07, 0.045 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.055, 0.04 }, fin, true)
		b:forkTail(0.14, 0.025, fin)
		b:pectoral(0.24, -0.045, 0.15, 0.065, fin)
		-- A raised brow and short cheek spines distinguish the rockfish head.
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.34, 0.07, side * 0.042), Vector3.new(0.30, 0.092, side * 0.049), 0.013, colors.back, "Brow")
			b:limb(Vector3.new(0.26, -0.005, side * 0.06720000000000001), Vector3.new(0.20, -0.015, side * 0.09100000000000001), 0.012, fin, "CheekSpine")
		end
		b:face(0.37, 0.045, 0.05, rgb(220, 186, 120), colors.back)
	end,
}


end)()
species["BroadbillSwordfish"] = (function()
return {
	Name = "Broadbill Swordfish",
	Rarity = "Epic",
	RarityDenominator = 50,
	MinKg = 15,
	AverageKg = 85,
	MaxKg = 600,
	LengthScale = 1.6,
	BaseValue = 480,
	Fight = 0.10,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "#####" },
		Big = { "######", ".####." },
		Huge = { "#######", ".#####." },
	},
	-- Broad flattened sword, large eyes and a short sickle dorsal; no pelvic fins.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(40, 42, 60), side = rgb(116, 122, 140), belly = rgb(216, 222, 228) }
		local fin = rgb(40, 46, 66)
		b:fishBody(0.21, 0.16, colors, 0.02)
		b:layered("Shoulder", Vector3.new(0.2, 0.015, 0), Vector3.new(0.34, 0.23, 0.18), colors)
		local crest = b:top(0.12)
		b:fin({
			v2(0.25, b:top(0.25) - 0.008), v2(0.15, crest + 0.12),
			v2(0.07, crest + 0.18), v2(0.1, crest + 0.07), v2(0.12, crest - 0.008),
		}, fin)
		b:edgeFin(-0.23, -0.29, { 0.035 }, fin)
		b:edgeFin(0.0, -0.13, { 0.11, 0.065, 0.03 }, fin, true)
		b:edgeFin(-0.23, -0.29, { 0.03 }, fin, true)
		b:lunateTail(0.24, fin)
		b:pectoral(0.22, -0.04, 0.19, 0.04, fin)
		for _, side in { 1, -1 } do
			b:ellipsoid("TailKeel", CFrame.new(-0.33, 0, side * 0.024), Vector3.new(0.105, 0.025, 0.038), colors.back)
		end
		b:ellipsoid("SwordBase", CFrame.new(0.57, 0.005, 0), Vector3.new(0.28, 0.025, 0.085), colors.back)
		b:fin({
			Vector3.new(0.45, 0.006, -0.044), Vector3.new(1.04, 0.006, -0.006),
			Vector3.new(1.07, 0.006, 0), Vector3.new(1.04, 0.006, 0.006),
			Vector3.new(0.45, 0.006, 0.044),
		}, rgb(66, 72, 90))
		b:face(0.365, 0.025, 0.07, rgb(112, 136, 156), rgb(62, 72, 94))
	end,
}

end)()
species["BroomtailGrouper"] = (function()
return {
	Name = "Broomtail Grouper",
	Rarity = "Epic",
	RarityDenominator = 36,
	MinKg = 4,
	AverageKg = 20,
	MaxKg = 100,
	LengthScale = 1.15,
	BaseValue = 390,
	Fight = 0.08,
	Pools = { "CoralShallows" },
	Seasons = { "Autumn", "Winter" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "###", "###" },
		Big = { "####", "####" },
		Huge = { "#####", "#####" },
	},
	-- Heavy mottled grouper with the ragged, broom-like caudal fin that gives it its name.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(74, 68, 52), side = rgb(138, 122, 86), belly = rgb(210, 196, 156) }
		local fin = rgb(90, 78, 54)
		b:fishBody(0.36, 0.2, colors, 0.075)
		local dorsal = b:edgeFin(0.17, -0.22, { 0.055, 0.075, 0.07, 0.06, 0.055, 0.065, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, colors.back)
		b:edgeFin(-0.08, -0.24, { 0.065, 0.075, 0.055 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.06, 0.045 }, fin, true)
		local tail = { v2(-0.345, 0.025) }
		for index = 0, 12 do
			local y = 0.155 - index * 0.31 / 12
			table.insert(tail, v2(if index % 2 == 0 then -0.54 else -0.505, y))
		end
		table.insert(tail, v2(-0.345, -0.025))
		b:fin(tail, fin)
		for y = -0.12, 0.12, 0.04 do
			b:rays(v2(-0.35, 0), { v2(-0.53, y) }, rgb(62, 56, 40))
		end
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		for _, spot in { { 0.22, 0.06 }, { 0.1, -0.055 }, { -0.02, 0.05 }, { -0.14, -0.04 }, { -0.25, 0.02 } } do
			b:marks(spot[1], spot[2], 0.115, 0.085, rgb(76, 62, 40))
		end
		b:speckle(22, v2(-0.3, 0.3), v2(-0.12, 0.13), v2(0.008, 0.014), rgb(190, 170, 126))
		b:face(0.37, 0.04, 0.043, rgb(186, 166, 86), colors.back)
	end,
}

end)()
species["BrownBullhead"] = (function()
return {
	Name = "Brown Bullhead",
	Rarity = "Uncommon",
	RarityDenominator = 8,
	MinKg = 0.15,
	AverageKg = 0.85,
	MaxKg = 4,
	BaseValue = 28,
	Fight = 0.05,
	Pools = { "MainLake", "SoddenMire" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Requires = { "Rain", "Night" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(68, 48, 30), side = rgb(130, 102, 58), belly = rgb(214, 200, 146) }
		local fin, whisker = rgb(98, 76, 42), rgb(62, 48, 30)
		b:fishBody(0.25, 0.22, colors, 0.17)
		local dorsal = b:edgeFin(0.15, 0.025, { 0.11, 0.075, 0.045 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3] }, colors.back)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.23, b:top(-0.23) + 0.006, 0), Vector3.new(0.1, 0.032, 0.015), fin)
		b:edgeFin(-0.02, -0.31, { 0.045, 0.055, 0.055, 0.055, 0.045 }, fin, true)
		b:edgeFin(0.06, -0.005, { 0.045 }, fin, true)
		b:roundTail(0.115, fin)
		b:pectoral(0.24, -0.05, 0.12, 0.045, fin)
		-- Paired long maxillary barbels and four shorter chin barbels.
		for _, side in { 1, -1 } do
			local bend = Vector3.new(0.35, -0.055, side * 0.15)
			b:limb(Vector3.new(0.46, -0.01, side * 0.035), bend, 0.009, whisker, "Barbel")
			b:limb(bend, Vector3.new(0.2, -0.13, side * 0.18), 0.006, whisker, "Barbel")
			for _, z in { 0.015, 0.04 } do
				local chin = b:bottom(0.44)
				b:limb(Vector3.new(0.44, chin + 0.006, side * z), Vector3.new(0.4, chin - 0.055, side * z * 1.7), 0.006, whisker, "Barbel")
			end
		end
		b:speckle(52, v2(0.3, -0.28), v2(-0.09, 0.09), v2(0.015, 0.035), rgb(72, 56, 30))
		b:face(0.4, 0.018, 0.031, rgb(184, 148, 66), colors.back)
	end,
}

end)()
species["CalicoGrouper"] = (function()
return {
	Name = "Calico Grouper",
	Rarity = "Rare",
	RarityDenominator = 14,
	MinKg = 1.5,
	AverageKg = 7,
	MaxKg = 25,
	BaseValue = 170,
	Fight = 0.06,
	Pools = { "CoralShallows", "CinderIsles" },
	Seasons = { "Summer", "Autumn" },
	Requires = { "Clear" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- A warm ochre grouper patterned with large dark calico patches and pale seams.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(106, 74, 50), side = rgb(180, 144, 96), belly = rgb(226, 206, 166) }
		local fin = rgb(112, 82, 54)
		b:fishBody(0.33, 0.18, colors, 0.075)
		local dorsal = b:edgeFin(0.17, -0.22, { 0.055, 0.075, 0.07, 0.06, 0.055, 0.065, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, colors.back)
		b:edgeFin(-0.08, -0.24, { 0.065, 0.075, 0.055 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.06, 0.045 }, fin, true)
		b:roundTail(0.135, fin)
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		for _, spot in { { 0.23, 0.06, 0.1, 0.09 }, { 0.11, -0.04, 0.11, 0.08 }, { -0.02, 0.08, 0.12, 0.1 }, { -0.15, -0.02, 0.1, 0.1 }, { -0.26, 0.035, 0.065, 0.065 } } do
			b:marks(spot[1], spot[2], spot[3], spot[4], rgb(76, 50, 32))
		end
		b:speckle(24, v2(-0.28, 0.3), v2(-0.11, 0.12), v2(0.009, 0.017), rgb(238, 214, 168))
		b:face(0.37, 0.04, 0.043, rgb(206, 166, 78), colors.back)
	end,
}

end)()
species["CanaryRockfish"] = (function()
return {
	Name = "Canary Rockfish",
	Rarity = "Rare",
	RarityDenominator = 14,
	MinKg = 0.4,
	AverageKg = 1.8,
	MaxKg = 5.5,
	BaseValue = 138,
	Fight = 0.04,
	Pools = { "FrostmereExpanse", "CinderIsles" },
	Seasons = { "Spring", "Summer" },
	Requires = { "Day" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Golden-orange flanks and three pale diagonal head stripes.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(192, 100, 28), side = rgb(242, 166, 58), belly = rgb(250, 228, 174) }
		local fin = rgb(224, 132, 34)
		b:fishBody(0.31, 0.15, colors, 0.08)
		b:layered("LowerJaw", Vector3.new(0.405, -0.052, 0), Vector3.new(0.17, 0.075, 0.0975), colors)
		local spines = b:edgeFin(0.2, -0.08, { 0.045, 0.09, 0.105, 0.10, 0.085, 0.07, 0.04 }, fin)
		for index = 3, #spines - 1 do
			local tip = spines[index]
			b:rays(v2(tip.X, b:top(tip.X)), { tip }, colors.back)
		end
		b:edgeFin(-0.08, -0.27, { 0.075, 0.085, 0.07, 0.04 }, fin, false, 0.05)
		b:edgeFin(-0.08, -0.25, { 0.065, 0.07, 0.045 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.055, 0.04 }, fin, true)
		b:forkTail(0.14, 0.025, fin)
		b:pectoral(0.24, -0.045, 0.15, 0.065, fin)
		for _, y in { 0.065, 0.015, -0.04 } do
			b:stroke({ v2(0.41, y + 0.025), v2(0.26, y - 0.025) }, 0.017, rgb(246, 214, 148))
		end
		-- A raised brow and short cheek spines distinguish the rockfish head.
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.34, 0.07, side * 0.045), Vector3.new(0.30, 0.092, side * 0.0525), 0.013, colors.back, "Brow")
			b:limb(Vector3.new(0.26, -0.005, side * 0.072), Vector3.new(0.20, -0.015, side * 0.0975), 0.012, fin, "CheekSpine")
		end
		b:face(0.37, 0.045, 0.049, rgb(244, 204, 86), colors.back)
	end,
}


end)()
species["Carp"] = (function()
return {
	Name = "Carp",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.8,
	AverageKg = 3.5,
	MaxKg = 30,
	BaseValue = 9,
	Fight = 0.02,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "##", "##" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb, carp = kit.rgb, kit.carp
		carp(b, {
			colors = { back = rgb(86, 68, 36), side = rgb(192, 146, 64), belly = rgb(234, 208, 148) },
			fin = rgb(176, 104, 60),
			scale = rgb(164, 118, 48),
			scaleAlt = rgb(176, 130, 54),
			barbel = rgb(170, 120, 70),
			lips = rgb(198, 150, 92),
			iris = rgb(214, 172, 64),
			line = rgb(130, 96, 44),
		})
	end,
}

end)()
species["Catfish"] = (function()
return {
	Name = "Catfish",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.6,
	AverageKg = 3,
	MaxKg = 28,
	LengthScale = 1.2,
	BaseValue = 48,
	Fight = 0.04,
	Pools = { "OpenSea" },
	Seasons = { "Summer" },
	Requires = { "Rain" },
	Shapes = {
		Normal = { "###" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb = kit.rgb
		local colors = { back = rgb(70, 74, 78), side = rgb(130, 132, 128), belly = rgb(226, 222, 210) }
		local fin, whisker = rgb(96, 98, 98), rgb(60, 60, 62)
		b:fishBody(0.2, 0.18, colors, 0.12)
		local dorsal = b:edgeFin(0.14, 0.03, { 0.1, 0.07, 0.04 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3] }, rgb(52, 54, 56))
		b:ellipsoid("AdiposeFin", CFrame.new(-0.22, b:top(-0.22) + 0.006, 0), Vector3.new(0.09, 0.03, 0.012), fin)
		b:edgeFin(-0.04, -0.3, { 0.04, 0.05, 0.05, 0.045, 0.04 }, fin, true)
		b:edgeFin(0.06, 0, { 0.04 }, fin, true)
		b:forkTail(0.11, 0.05, fin)
		b:pectoral(0.24, -0.06, 0.11, 0.035, fin)
		for _, side in { 1, -1 } do
			local bend = Vector3.new(0.36, -0.06, side * 0.14)
			b:limb(Vector3.new(0.46, -0.01, side * 0.035), bend, 0.009, whisker, "Barbel")
			b:limb(bend, Vector3.new(0.22, -0.12, side * 0.17), 0.006, whisker, "Barbel")
			for _, z in { 0.015, 0.04 } do
				local chin = b:bottom(0.44)
				b:limb(
					Vector3.new(0.44, chin + 0.006, side * z),
					Vector3.new(0.41, chin - 0.05, side * z * 1.6),
					0.006,
					rgb(200, 196, 186),
					"Barbel"
				)
			end
		end
		b:face(0.4, 0.02, 0.03, rgb(150, 140, 100), rgb(90, 92, 92))
	end,
}

end)()
species["Chilipepper"] = (function()
return {
	Name = "Chilipepper",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.2,
	AverageKg = 0.9,
	MaxKg = 3,
	BaseValue = 56,
	Fight = 0.04,
	Pools = { "CinderIsles" },
	Seasons = { "Summer", "Autumn" },
	Requires = { "Day" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Slender red body with a fine copper lateral line.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(174, 48, 48), side = rgb(224, 100, 90), belly = rgb(246, 202, 186) }
		local fin = rgb(198, 70, 60)
		b:fishBody(0.23, 0.12, colors, 0.08)
		b:layered("LowerJaw", Vector3.new(0.405, -0.052, 0), Vector3.new(0.17, 0.075, 0.078), colors)
		local spines = b:edgeFin(0.2, -0.08, { 0.045, 0.09, 0.105, 0.10, 0.085, 0.07, 0.04 }, fin)
		for index = 3, #spines - 1 do
			local tip = spines[index]
			b:rays(v2(tip.X, b:top(tip.X)), { tip }, colors.back)
		end
		b:edgeFin(-0.08, -0.27, { 0.075, 0.085, 0.07, 0.04 }, fin, false, 0.05)
		b:edgeFin(-0.08, -0.25, { 0.065, 0.07, 0.045 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.055, 0.04 }, fin, true)
		b:forkTail(0.14, 0.025, fin)
		b:pectoral(0.24, -0.045, 0.15, 0.065, fin)
		b:stroke({ v2(0.29, 0.018), v2(0, 0.012), v2(-0.3, 0) }, 0.009, rgb(242, 168, 132))
		-- A raised brow and short cheek spines distinguish the rockfish head.
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.34, 0.07, side * 0.036), Vector3.new(0.30, 0.092, side * 0.041999999999999996), 0.013, colors.back, "Brow")
			b:limb(Vector3.new(0.26, -0.005, side * 0.0576), Vector3.new(0.20, -0.015, side * 0.078), 0.012, fin, "CheekSpine")
		end
		b:face(0.37, 0.045, 0.046, rgb(230, 180, 90), colors.back)
	end,
}


end)()
species["ChinookSalmon"] = (function()
return {
	Name = "Chinook Salmon",
	Rarity = "Epic",
	RarityDenominator = 30,
	MinKg = 3,
	AverageKg = 12,
	MaxKg = 60,
	LengthScale = 1.15,
	BaseValue = 378,
	Fight = 0.1,
	Pools = { "FrostmereExpanse" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Requires = { "Day" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Heavy king-salmon shoulders, a dark mouth and spots on both tail lobes.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(38, 66, 72), side = rgb(144, 168, 168), belly = rgb(228, 234, 222) }
		local fin, spot = rgb(64, 86, 88), rgb(36, 46, 44)
		b:fishBody(0.28, 0.16, colors, 0.05)
		b:layered("Shoulder", Vector3.new(0.16, 0.02, 0), Vector3.new(0.46, 0.29, 0.17), colors)
		b:edgeFin(0.08, -0.08, { 0.085, 0.08, 0.055, 0.035 }, fin)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.25, b:top(-0.25) + 0.008, 0), Vector3.new(0.055, 0.035, 0.014), fin)
		b:edgeFin(-0.12, -0.25, { 0.06, 0.055, 0.035 }, fin, true)
		b:edgeFin(0.02, -0.06, { 0.05, 0.04 }, fin, true)
		b:forkTail(0.14, 0.04, fin)
		b:pectoral(0.22, -0.045, 0.11, 0.04, fin)
		b:speckle(30, v2(-0.30, 0.30), v2(0, 0.11), v2(0.009, 0.017), spot)
		for _, y in { -0.085, -0.05, 0.045, 0.08 } do
			b:finSpot(-0.46, y, 0.011, spot)
			b:finSpot(-0.425, y * 0.55, 0.008, spot)
		end
		b:marks(0.448, -0.027, 0.05, 0.025, rgb(28, 34, 30))
		b:stroke({ v2(0.28, -0.012), v2(0, -0.016), v2(-0.28, -0.008) }, 0.005, fin)
		b:face(0.38, 0.025, 0.047, rgb(204, 180, 114), fin)
	end,
}


end)()
species["Clownfish"] = (function()
return {
	Name = "Clownfish",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.03,
	AverageKg = 0.09,
	MaxKg = 0.45,
	BaseValue = 19,
	Fight = 0.03,
	Pools = { "OpenSea" },
	Seasons = { "Summer" },
	Requires = { "Clear" },
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(222, 92, 20), side = rgb(240, 122, 32), belly = rgb(246, 158, 72) }
		local fin = rgb(236, 112, 30)
		local white, edge = rgb(250, 250, 246), rgb(22, 18, 16)
		b:fishBody(0.36, 0.14, colors, 0.06)
		b:edgeFin(0.12, -0.26, { 0.06, 0.07, 0.06, 0.08, 0.09, 0.08 }, fin)
		b:edgeFin(-0.06, -0.24, { 0.06, 0.08, 0.06 }, fin, true)
		b:edgeFin(0.08, 0, { 0.07, 0.05 }, fin, true)
		b:roundTail(0.13, fin)
		b:pectoral(0.18, -0.04, 0.11, 0.05, fin)
		-- White bands with thin black borders.
		for _, x in { 0.2, -0.02, -0.3 } do
			local width = if x < -0.2 then 0.03 else 0.045
			b:stroke({ v2(x, b:top(x) - 0.008), v2(x - 0.01, b:bottom(x) + 0.008) }, width, white)
			for _, offset in { -1, 1 } do
				local bx = x + offset * (width / 2 + 0.008)
				b:stroke({ v2(bx, b:top(bx) - 0.008), v2(bx - 0.01, b:bottom(bx) + 0.008) }, 0.009, edge)
			end
		end
		b:face(0.38, 0.04, 0.05, rgb(232, 120, 40), edge)
	end,
}

end)()
species["Cod"] = (function()
return {
	Name = "Cod",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 1,
	AverageKg = 4,
	MaxKg = 40,
	BaseValue = 24,
	Fight = 0.02,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "###" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(102, 94, 60), side = rgb(158, 148, 104), belly = rgb(232, 226, 202) }
		local fin = rgb(122, 112, 78)
		b:fishBody(0.22, 0.15, colors, 0.08)
		b:edgeFin(0.15, 0.04, { 0.05, 0.065, 0.05 }, fin)
		b:edgeFin(0.0, -0.12, { 0.045, 0.055, 0.045 }, fin)
		b:edgeFin(-0.16, -0.27, { 0.04, 0.045, 0.03 }, fin)
		b:edgeFin(-0.03, -0.14, { 0.04, 0.05, 0.04 }, fin, true)
		b:edgeFin(-0.17, -0.27, { 0.04, 0.04, 0.03 }, fin, true)
		b:forkTail(0.09, 0.012, fin)
		b:pectoral(0.21, -0.03, 0.09, 0.04, fin)
		b:speckle(60, v2(-0.33, 0.36), v2(-0.04, 0.12), v2(0.014, 0.03), rgb(92, 80, 50))
		b:stroke({ v2(0.26, 0.04), v2(0.12, 0.05), v2(-0.06, 0.03), v2(-0.32, 0.005) }, 0.009, rgb(226, 220, 196))
		b:limb(
			Vector3.new(0.43, b:bottom(0.43) + 0.005, 0),
			Vector3.new(0.4, b:bottom(0.43) - 0.075, 0),
			0.012,
			rgb(150, 136, 96),
			"Barbel"
		)
		b:face(0.36, 0.02, 0.042, rgb(190, 176, 120), rgb(110, 100, 70))
	end,
}

end)()
species["CohoSalmon"] = (function()
return {
	Name = "Coho Salmon",
	Rarity = "Rare",
	RarityDenominator = 12,
	MinKg = 0.8,
	AverageKg = 3.5,
	MaxKg = 15,
	BaseValue = 136,
	Fight = 0.08,
	Pools = { "MainLake", "FrostmereExpanse" },
	Seasons = { "Autumn", "Winter" },
	Requires = { "Rain", "Day" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Bright silver flanks, blue-green back and a lightly spotted upper tail.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(42, 82, 96), side = rgb(188, 204, 208), belly = rgb(238, 242, 236) }
		local fin, spot = rgb(76, 110, 122), rgb(36, 46, 44)
		b:fishBody(0.23, 0.125, colors, 0.05)
		b:edgeFin(0.08, -0.08, { 0.085, 0.08, 0.055, 0.035 }, fin)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.25, b:top(-0.25) + 0.008, 0), Vector3.new(0.055, 0.035, 0.014), fin)
		b:edgeFin(-0.12, -0.25, { 0.06, 0.055, 0.035 }, fin, true)
		b:edgeFin(0.02, -0.06, { 0.05, 0.04 }, fin, true)
		b:forkTail(0.12, 0.04, fin)
		b:pectoral(0.22, -0.045, 0.11, 0.04, fin)
		b:speckle(18, v2(-0.30, 0.30), v2(0, 0.11), v2(0.009, 0.017), spot)
		for _, y in { 0.035, 0.065, 0.085 } do
			b:finSpot(-0.46, y, 0.011, spot)
			b:finSpot(-0.425, y * 0.55, 0.008, spot)
		end
		b:stroke({ v2(0.28, -0.012), v2(0, -0.016), v2(-0.28, -0.008) }, 0.005, fin)
		b:face(0.38, 0.025, 0.04, rgb(200, 196, 154), fin)
	end,
}


end)()
species["Cowcod"] = (function()
return {
	Name = "Cowcod",
	Rarity = "Epic",
	RarityDenominator = 36,
	MinKg = 1.5,
	AverageKg = 7,
	MaxKg = 18,
	BaseValue = 395,
	Fight = 0.08,
	Pools = { "CinderIsles" },
	Seasons = { "Autumn", "Winter" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Deep orange body, broad head, dark saddles and tall dorsal spines.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(156, 64, 40), side = rgb(224, 114, 64), belly = rgb(248, 202, 150) }
		local fin = rgb(186, 76, 44)
		b:fishBody(0.36, 0.19, colors, 0.08)
		b:layered("LowerJaw", Vector3.new(0.405, -0.052, 0), Vector3.new(0.17, 0.075, 0.12350000000000001), colors)
		local spines = b:edgeFin(0.2, -0.08, { 0.045, 0.09, 0.14, 0.10, 0.085, 0.07, 0.04 }, fin)
		for index = 3, #spines - 1 do
			local tip = spines[index]
			b:rays(v2(tip.X, b:top(tip.X)), { tip }, colors.back)
		end
		b:edgeFin(-0.08, -0.27, { 0.075, 0.085, 0.07, 0.04 }, fin, false, 0.05)
		b:edgeFin(-0.08, -0.25, { 0.065, 0.07, 0.045 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.055, 0.04 }, fin, true)
		b:roundTail(0.13, fin)
		b:pectoral(0.24, -0.045, 0.18, 0.065, fin)
		for _, x in { 0.25, 0.12, -0.03, -0.18, -0.29 } do
			b:stroke({ v2(x, b:top(x) * 0.84), v2(x - 0.02, b:bottom(x) * 0.65) }, 0.028, rgb(130, 50, 34))
		end
		-- A raised brow and short cheek spines distinguish the rockfish head.
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.34, 0.07, side * 0.056999999999999995), Vector3.new(0.30, 0.092, side * 0.06649999999999999), 0.013, colors.back, "Brow")
			b:limb(Vector3.new(0.26, -0.005, side * 0.0912), Vector3.new(0.20, -0.015, side * 0.12350000000000001), 0.012, fin, "CheekSpine")
		end
		b:face(0.37, 0.045, 0.063, rgb(236, 186, 100), colors.back)
	end,
}


end)()
species["Crimsonfish"] = (function()
return {
	Name = "Crimsonfish",
	Rarity = "Rare",
	RarityDenominator = 15,
	MinKg = 0.3,
	AverageKg = 1.2,
	MaxKg = 8,
	BaseValue = 100,
	Fight = 0.05,
	Pools = { "MainLake", "OpenSea" },
	Seasons = { "Summer" },
	Requires = { "Beach" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	},
	-- Crimson beach fish with gold-edged, flowing fins.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(120, 16, 30), side = rgb(196, 30, 46), belly = rgb(236, 120, 110) }
		local fin, gold = rgb(176, 26, 40), rgb(240, 190, 70)
		b:fishBody(0.24, 0.12, colors, 0.05)
		local dorsal = b:edgeFin(0.14, -0.2, { 0.09, 0.11, 0.12, 0.12, 0.11, 0.09, 0.06 }, fin, false, 0.1)
		b:stroke({ dorsal[3], dorsal[4], dorsal[5], dorsal[6], dorsal[7], dorsal[8] }, 0.01, gold)
		local anal = b:edgeFin(-0.06, -0.22, { 0.07, 0.09, 0.08, 0.05 }, fin, true, 0.1)
		b:stroke({ anal[3], anal[4], anal[5], anal[6] }, 0.01, gold)
		b:edgeFin(0.06, -0.01, { 0.06, 0.05 }, fin, true, 0.1)
		b:forkTail(0.17, 0.08, fin, 0.08)
		b:stroke({ v2(-0.5, 0.17), v2(-0.42, 0.08) }, 0.01, gold)
		b:stroke({ v2(-0.5, -0.17), v2(-0.42, -0.08) }, 0.01, gold)
		b:pectoral(0.2, -0.04, 0.13, 0.04, rgb(226, 90, 80), 0.2)
		b:speckle(26, v2(-0.28, 0.3), v2(-0.04, 0.08), v2(0.01, 0.018), rgb(250, 170, 150))
		b:face(0.37, 0.03, 0.05, gold, rgb(140, 20, 34))
	end,
}

end)()
species["CutlassFish"] = (function()
return {
	Name = "Cutlass Fish",
	Rarity = "Rare",
	RarityDenominator = 12,
	MinKg = 0.3,
	AverageKg = 1.5,
	MaxKg = 6,
	LengthScale = 1.4,
	BaseValue = 165,
	Fight = 0.06,
	Pools = { "PirateCove" },
	Seasons = { "Summer", "Autumn", "Winter" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "#####" },
	},
	-- A blade-thin silver ribbonfish that rises to the cove's lanterns after dark: one long
	-- see-through dorsal, no tail fin, just a whip, and a mouth full of fangs.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(150, 164, 178), side = rgb(214, 222, 230), belly = rgb(244, 246, 248) }
		local fin = rgb(196, 210, 222)
		b:fishBody(0.1, 0.05, colors, 0)
		local heights = {}
		for index = 1, 12 do
			heights[index] = 0.025 + 0.006 * math.sin(index * 0.9)
		end
		b:edgeFin(0.3, -0.42, heights, fin, false, 0.35)
		b:limb(Vector3.new(-0.42, 0, 0), Vector3.new(-0.64, -0.01, 0), 0.008, colors.side, "Whip")
		b:pectoral(0.28, -0.01, 0.05, 0.02, fin, 0.3)
		b:stroke({ v2(0.34, 0.012), v2(-0.36, 0.006) }, 0.005, rgb(124, 140, 156))
		for _, x in { 0.47, 0.455, 0.44 } do
			b:marks(x, b:bottom(x) * 0.2, 0.006, 0.014, rgb(250, 250, 250))
		end
		b:face(0.4, 0.016, 0.034, rgb(232, 222, 150), rgb(150, 160, 172))
	end,
}

end)()
species["DeepwaterEel"] = (function()
return {
	Name = "Deepwater Eel",
	Rarity = "Rare",
	RarityDenominator = 12,
	MinKg = 0.8,
	AverageKg = 3,
	MaxKg = 18,
	LengthScale = 1.3,
	BaseValue = 150,
	Fight = 0.07,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Autumn" },
	Requires = { "Storm" },
	Shapes = {
		Normal = { "####" },
		Big = { "#####", "#...." },
		Huge = { "######", "#....#" },
	},
	-- Dusky deep-sea eel: near-black purple-brown with big, pale, light-gathering
	-- eyes and a dorsal fin starting just behind the head.
	Build = function(b, kit)
		local rgb, eel = kit.rgb, kit.eel
		eel(b, {
			back = rgb(34, 28, 38),
			side = rgb(62, 52, 64),
			belly = rgb(118, 104, 112),
			fin = rgb(48, 40, 52),
			iris = rgb(190, 214, 220),
			eyeSize = 0.05,
			dorsalFrom = 0.12,
		})
	end,
}

end)()
species["DeepwaterSalmon"] = (function()
return {
	Name = "Deepwater Salmon",
	Rarity = "Rare",
	RarityDenominator = 12,
	MinKg = 1.5,
	AverageKg = 4,
	MaxKg = 14,
	BaseValue = 155,
	Fight = 0.08,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Winter" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Ocean-phase salmon: a blue-grey back, silver flanks and small dark spots.
	Build = function(b, kit)
		local rgb = kit.rgb
		kit.trout(b, {
			colors = { back = rgb(48, 72, 88), side = rgb(170, 190, 198), belly = rgb(232, 238, 236) },
			fin = rgb(88, 110, 122),
			spots = 38,
			spot = rgb(34, 48, 58),
			iris = rgb(190, 202, 174),
			line = rgb(94, 116, 126),
		})
	end,
}

end)()
species["Dorado"] = (function()
return {
	Name = "Dorado",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 1,
	AverageKg = 4,
	MaxKg = 30,
	BaseValue = 27,
	Fight = 0.06,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Requires = { "Clear" },
	Shapes = {
		Normal = { "###" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	},
	-- Golden dorado: a river predator in gold with rows of dark dashes and a red tail.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(176, 128, 30), side = rgb(232, 182, 54), belly = rgb(246, 226, 160) }
		local fin = rgb(224, 150, 50)
		b:fishBody(0.24, 0.14, colors, 0.05)
		b:edgeFin(0.08, -0.1, { 0.07, 0.07, 0.06, 0.045 }, fin)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.24, b:top(-0.24) + 0.004, 0), Vector3.new(0.05, 0.03, 0.012), fin)
		b:edgeFin(-0.12, -0.23, { 0.06, 0.05, 0.035 }, fin, true)
		b:edgeFin(0.03, -0.06, { 0.05, 0.04 }, fin, true)
		b:forkTail(0.14, 0.06, rgb(214, 72, 44))
		b:stroke({ v2(-0.36, 0), v2(-0.48, 0) }, 0.014, rgb(40, 30, 20))
		b:pectoral(0.2, -0.05, 0.1, 0.035, fin)
		for row = 0, 5 do
			local y = -0.07 + row * 0.03
			for x = 0.22 - (row % 2) * 0.02, -0.3, -0.04 do
				if y < b:top(x) - 0.012 and y > b:bottom(x) + 0.012 then
					b:marks(x, y, 0.018, 0.008, rgb(96, 64, 20))
				end
			end
		end
		b:face(0.37, 0.025, 0.044, rgb(220, 150, 50), rgb(150, 100, 30))
	end,
}

end)()
species["DoubloonFish"] = (function()
return {
	Name = "Doubloon Fish",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.15,
	AverageKg = 0.6,
	MaxKg = 3,
	BaseValue = 52,
	Fight = 0.05,
	Pools = { "PirateCove" },
	Seasons = { "Spring", "Summer", "Autumn", "Winter" },
	Requires = { "Day" },
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	-- A round, coin-flat moonfish that only flashes gold in daylight. The cove's crew swear the
	-- ring on its flank is stamped by the sunken treasure it feeds around.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(170, 124, 28), side = rgb(234, 194, 70), belly = rgb(250, 232, 150) }
		local fin = rgb(222, 172, 56)
		local stamp = rgb(152, 106, 24)
		b:fishBody(0.52, 0.08, colors, 0.14)
		b:edgeFin(0.1, -0.2, { 0.14, 0.1, 0.06, 0.04 }, fin, false, 0.08)
		b:edgeFin(0.06, -0.2, { 0.12, 0.08, 0.05, 0.03 }, fin, true, 0.08)
		b:forkTail(0.16, 0.07, fin)
		b:pectoral(0.2, -0.02, 0.09, 0.03, fin, 0.2)
		-- The doubloon stamp: a ring with a cross in the middle.
		local ring = {}
		for step = 0, 16 do
			local angle = step / 16 * math.pi * 2
			table.insert(ring, v2(0.0 + math.cos(angle) * 0.11, 0.01 + math.sin(angle) * 0.11))
		end
		b:stroke(ring, 0.01, stamp)
		b:stroke({ v2(-0.05, 0.01), v2(0.05, 0.01) }, 0.01, stamp)
		b:stroke({ v2(0.0, -0.04), v2(0.0, 0.06) }, 0.01, stamp)
		b:face(0.37, 0.07, 0.05, rgb(244, 206, 84), rgb(160, 112, 30))
	end,
}

end)()
species["DreadbeardsTreasure"] = (function()
-- The one in a million: Dreadbeard's lost compass rose. Rod only, never netted,
-- and worth nothing at market because the only thing it buys cannot be sold.
return {
	Name = "Dreadbeard's Treasure",
	Rarity = "Secret",
	RarityDenominator = 1000000,
	MinKg = 1,
	AverageKg = 1,
	MaxKg = 1,
	BaseValue = 0,
	Fight = 0,
	DropOnly = true,
	Secret = true,
	Shapes = {
		Normal = { "#" },
	},
	Build = function(b, kit)
		local rgb = kit.rgb
		local gold = rgb(232, 181, 66)
		local bright = rgb(255, 226, 140)
		local dark = rgb(142, 96, 26)
		local shadow = rgb(86, 56, 14)
		local face = rgb(247, 205, 102)

		-- Cylinders run along local X; turn them to face the medallion's Z axis.
		local function disc(name, z, diameter, width, color)
			local part = b:part(
				name,
				"Part",
				Vector3.new(width, diameter, diameter),
				CFrame.new(0, 0, z) * CFrame.Angles(0, math.pi / 2, 0),
				color
			)
			part.Shape = Enum.PartType.Cylinder
			return part
		end

		-- A heavy bevelled rim around a raised golden face.
		disc("Rim", 0, 0.8, 0.1, dark)
		disc("RimEdge", 0.025, 0.75, 0.09, gold)
		disc("Face", 0.06, 0.64, 0.08, face)
		disc("FaceInner", 0.095, 0.58, 0.04, bright)

		-- Eight compass points, each half bright and half shadowed, so the rose
		-- reads as cut metal rather than a flat decal.
		local long, short, halfWidth = 0.31, 0.2, 0.055
		for index = 0, 7 do
			local angle = index * math.pi / 4
			local dir = Vector3.new(math.cos(angle), math.sin(angle), 0)
			local across = Vector3.new(-dir.Y, dir.X, 0)
			local reach = if index % 2 == 0 then long else short
			local tip = dir * reach + Vector3.new(0, 0, 0.125)
			local left = across * halfWidth + Vector3.new(0, 0, 0.125)
			local right = -across * halfWidth + Vector3.new(0, 0, 0.125)
			local notch = dir * 0.035 + Vector3.new(0, 0, 0.125)
			b:triangle(tip, notch, left, if index % 2 == 0 then bright else gold)
			b:triangle(tip, right, notch, if index % 2 == 0 then gold else dark)
			b:ellipsoid("PointStud", CFrame.new(dir * (reach + 0.012) + Vector3.new(0, 0, 0.126)), Vector3.one * 0.022, shadow)
		end

		-- The letter D: a straight spine joined to a half-round bowl.
		local spineX, radius, z = -0.085, 0.132, 0.138
		b:part("DSpine", "Part", Vector3.new(0.034, radius * 2, 0.022), CFrame.new(spineX, 0, z), shadow)
		local previous = Vector3.new(spineX, -radius, z)
		for step = 1, 9 do
			local theta = -math.pi / 2 + math.pi * step / 9
			local point = Vector3.new(spineX + math.cos(theta) * radius, math.sin(theta) * radius, z)
			b:limb(previous, point, 0.034, shadow, "DBowl")
			previous = point
		end

		-- A tiny gem above the rose gives the piece its pirate-loot glint.
		b:ellipsoid("Gem", CFrame.new(0, 0.32, 0.14), Vector3.new(0.05, 0.06, 0.03), rgb(190, 38, 52))
		b:ellipsoid("GemGlint", CFrame.new(-0.012, 0.335, 0.155), Vector3.one * 0.014, rgb(255, 226, 220))
		b.model:SetAttribute("ViewDirection", Vector3.new(0, 0.1, 1))
	end,
}

end)()
species["EclipseRay"] = (function()
return {
	Name = "Eclipse Ray",
	Rarity = "Mythical",
	RarityDenominator = 260,
	MinKg = 6,
	AverageKg = 28,
	MaxKg = 220,
	LengthScale = 1.15,
	BaseValue = 2400,
	Fight = 0.12,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Summer", "Autumn", "Winter" },
	Requires = { "BlackHole" },
	Shapes = {
		Normal = { ".#.", "###", ".#." },
		Big = { ".##.", "####", ".##." },
		Huge = { "..#..", ".###.", "#####", ".###.", "..#.." },
	},
	-- Crescent wings surround a dark disc; an illuminated orbit crowns its back.
	Build = function(b, kit)
		local rgb = kit.rgb
		local colors = { back = rgb(9, 5, 18), side = rgb(23, 10, 39), belly = rgb(36, 15, 59) }
		local membrane, violet, lilac = rgb(17, 7, 30), rgb(153, 45, 255), rgb(210, 125, 255)
		local function glow(part)
			if part then
				part.Material = Enum.Material.Neon
				part:SetAttribute("BlackHoleAccent", true)
			end
			return part
		end
		b:beginSkin(colors)
		b:layered("Disc", Vector3.new(0.08, 0.01, 0), Vector3.new(0.61, 0.11, 0.34), colors)
		b:layered("Head", Vector3.new(0.31, 0.005, 0), Vector3.new(0.25, 0.075, 0.25), colors)
		b:layered("TailRoot", Vector3.new(-0.19, 0, 0), Vector3.new(0.22, 0.065, 0.13), colors)
		b:finishSkin()
		for _, side in { -1, 1 } do
			local root = Vector3.new(0.04, 0, side * 0.08)
			local edge = {
				Vector3.new(0.29, 0.012, side * 0.12),
				Vector3.new(0.25, 0.025, side * 0.28),
				Vector3.new(0.12, 0.055, side * 0.46),
				Vector3.new(-0.12, 0.085, side * 0.65),
				Vector3.new(-0.29, 0.06, side * 0.70),
				Vector3.new(-0.18, 0.018, side * 0.44),
				Vector3.new(-0.24, -0.006, side * 0.20),
				Vector3.new(-0.18, -0.01, side * 0.075),
			}
			for index = 1, #edge - 1 do
				b:triangle(root, edge[index], edge[index + 1], membrane)
				glow(b:limb(edge[index], edge[index + 1], 0.011, violet, "WingRim"))
			end
			for _, index in { 3, 4, 6 } do
				local tip = edge[index]
				b:limb(root + Vector3.new(0, 0.005, 0), tip + Vector3.new(0, 0.005, 0), 0.007, rgb(64, 24, 100), "WingRay")
			end
			local horn = {
				Vector3.new(0.36, 0.015, side * 0.105),
				Vector3.new(0.48, 0.035, side * 0.16),
				Vector3.new(0.54, 0.065, side * 0.13),
			}
			b:limb(horn[1], horn[2], 0.045, colors.side, "CephalicHorn")
			glow(b:limb(horn[2], horn[3], 0.018, lilac, "HornTip"))
			glow(b:ellipsoid("Eye", CFrame.new(0.32, 0.049, side * 0.072), Vector3.new(0.037, 0.02, 0.035), lilac))
			for index = 1, 3 do
				glow(b:limb(Vector3.new(0.25 - index * 0.052, -0.027, side * 0.11), Vector3.new(0.22 - index * 0.052, -0.035, side * 0.13), 0.007, violet, "GillSlit"))
			end
		end
		-- The orbit sits just above the dome and leaves its center completely black.
		for index = 1, 16 do
			local a, c = (index - 1) / 16 * math.pi * 2, index / 16 * math.pi * 2
			local function point(angle)
				return Vector3.new(0.08 + math.cos(angle) * 0.102, 0.071, math.sin(angle) * 0.09)
			end
			glow(b:limb(point(a), point(c), 0.008, lilac, "EclipseOrbit"))
		end
		local previous = Vector3.new(-0.23, 0, 0)
		for index = 1, 12 do
			local t = index / 12
			local point = Vector3.new(-0.23 - t * 0.59, -0.005 + t * 0.04, math.sin(t * math.pi * 1.4) * 0.055)
			local tail = b:limb(previous, point, 0.032 * (1 - t) + 0.006, if index > 9 then violet else colors.side, "WhipTail")
			if index > 9 then glow(tail) end
			previous = point
		end
		b.model:SetAttribute("ViewDirection", Vector3.new(0.4, 1, 0.7))
	end,
}

end)()
species["Flounder"] = (function()
return {
	Name = "Flounder",
	Rarity = "Rare",
	RarityDenominator = 12,
	MinKg = 0.4,
	AverageKg = 1.5,
	MaxKg = 9,
	BaseValue = 145,
	Fight = 0.03,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Summer", "Autumn", "Winter" },
	Shapes = {
		Normal = { "##", "##" },
		Big = { "###", "##." },
		Huge = { "###", "###" },
	},
	Build = function(b, kit)
		local rgb, flatfish = kit.rgb, kit.flatfish
		flatfish(b, {
			top = rgb(118, 108, 84),
			under = rgb(240, 238, 230),
			fin = rgb(132, 120, 94),
			ray = rgb(90, 82, 62),
			light = rgb(214, 120, 54),
			dark = rgb(80, 72, 54),
			iris = rgb(200, 180, 110),
			mouth = rgb(60, 50, 36),
		})
	end,
}

end)()
species["GafftopsailCatfish"] = (function()
return {
	Name = "Gafftopsail Catfish",
	Rarity = "Rare",
	RarityDenominator = 17,
	MinKg = 0.4,
	AverageKg = 2.8,
	MaxKg = 8,
	BaseValue = 156,
	Fight = 0.09,
	Pools = { "CoralShallows", "PirateCove" },
	Seasons = { "Spring", "Summer" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", "####" },
		Huge = { "#####", "#####" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(56, 80, 102), side = rgb(166, 184, 198), belly = rgb(236, 236, 226) }
		local fin, whisker = rgb(110, 138, 160), rgb(190, 202, 200)
		b:fishBody(0.21, 0.18, colors, 0.1)
		local dorsal = b:edgeFin(0.15, 0.025, { 0.22, 0.15, 0.065 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3] }, colors.back)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.23, b:top(-0.23) + 0.006, 0), Vector3.new(0.1, 0.032, 0.015), fin)
		b:edgeFin(-0.02, -0.31, { 0.045, 0.055, 0.055, 0.055, 0.045 }, fin, true)
		b:edgeFin(0.06, -0.005, { 0.045 }, fin, true)
		b:forkTail(0.13, 0.075, fin)
		b:pectoral(0.24, -0.05, 0.12, 0.045, fin)
		-- Paired long maxillary barbels and four shorter chin barbels.
		for _, side in { 1, -1 } do
			local bend = Vector3.new(0.35, -0.055, side * 0.15)
			b:limb(Vector3.new(0.46, -0.01, side * 0.035), bend, 0.009, whisker, "Barbel")
			b:limb(bend, Vector3.new(0.2, -0.13, side * 0.18), 0.006, whisker, "Barbel")
			for _, z in { 0.015, 0.04 } do
				local chin = b:bottom(0.44)
				b:limb(Vector3.new(0.44, chin + 0.006, side * z), Vector3.new(0.4, chin - 0.055, side * z * 1.7), 0.006, whisker, "Barbel")
			end
		end
		-- Sail-like dorsal spine and long trailing pectoral filaments.
		local tip = Vector3.new(0.1, b:top(0.1) + 0.28, 0)
		b:limb(Vector3.new(0.17, b:top(0.17), 0), tip, 0.007, fin, "DorsalFilament")
		b:limb(tip, Vector3.new(-0.09, b:top(0.1) + 0.23, 0), 0.004, fin, "DorsalFilament")
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.21, -0.045, side * 0.065), Vector3.new(-0.03, -0.14, side * 0.13), 0.006, fin, "PectoralFilament")
			b:limb(Vector3.new(-0.03, -0.14, side * 0.13), Vector3.new(-0.22, -0.15, side * 0.1), 0.004, fin, "PectoralFilament")
		end
		b:face(0.4, 0.018, 0.031, rgb(180, 188, 166), colors.back)
	end,
}

end)()
species["GiantSeabass"] = (function()
return {
	Name = "Giant Seabass",
	Rarity = "Legendary",
	RarityDenominator = 90,
	MinKg = 12,
	AverageKg = 70,
	MaxKg = 250,
	LengthScale = 1.3,
	BaseValue = 890,
	Fight = 0.12,
	Pools = { "CinderIsles", "PirateCove" },
	Seasons = { "Spring", "Summer" },
	Requires = { "Rain", "Storm", "Night" },
	Shapes = {
		Normal = { "###", "###" },
		Big = { "####", "####" },
		Huge = { "#####", "#####" },
	},
	-- Massive, high-shouldered dark sea bass with a blunt jaw and scattered slate blotches.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(38, 44, 46), side = rgb(86, 98, 98), belly = rgb(172, 180, 174) }
		local fin = rgb(48, 58, 58)
		b:fishBody(0.43, 0.25, colors, 0.075)
		b:layered("Shoulder", Vector3.new(0.12, 0.035, 0), Vector3.new(0.51, 0.43, 0.255), colors)
		b:layered("Jaw", Vector3.new(0.38, -0.09, 0), Vector3.new(0.25, 0.15, 0.21), colors)
		local dorsal = b:edgeFin(0.17, -0.22, { 0.055, 0.075, 0.07, 0.06, 0.055, 0.065, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, colors.back)
		b:edgeFin(-0.08, -0.24, { 0.065, 0.075, 0.055 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.06, 0.045 }, fin, true)
		b:roundTail(0.135, fin)
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		b:speckle(24, v2(-0.28, 0.29), v2(-0.13, 0.16), v2(0.025, 0.046), rgb(46, 58, 60))
		b:stroke({ v2(0.48, -0.055), v2(0.34, -0.12) }, 0.018, rgb(30, 36, 36))
		b:face(0.37, 0.04, 0.055, rgb(152, 164, 144), colors.back)
	end,
}

end)()
species["Glacierfish"] = (function()
return {
	Name = "Glacierfish",
	Rarity = "Legendary",
	RarityDenominator = 120,
	MinKg = 5,
	AverageKg = 22,
	MaxKg = 140,
	BaseValue = 900,
	Fight = 0.08,
	Pools = { "MainLake", "OpenSea" },
	Seasons = { "Winter" },
	Shapes = {
		Normal = { "###", "###" },
		Big = { "####", "####" },
		Huge = { "#####", "#####", "#####" },
	},
	-- Pale ice-blue legend with frost crystals along its back.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(120, 176, 214), side = rgb(196, 226, 244), belly = rgb(244, 250, 255) }
		local fin, frost = rgb(160, 210, 236), rgb(236, 248, 255)
		b:fishBody(0.26, 0.15, colors, 0.04)
		b:edgeFin(0.14, -0.18, { 0.08, 0.1, 0.1, 0.09, 0.07, 0.05 }, fin, false, 0.25)
		b:edgeFin(-0.06, -0.22, { 0.06, 0.07, 0.05 }, fin, true, 0.25)
		b:edgeFin(0.06, -0.02, { 0.05, 0.04 }, fin, true, 0.25)
		b:forkTail(0.17, 0.07, fin, 0.25)
		b:pectoral(0.2, -0.04, 0.13, 0.04, fin, 0.3)
		for x = 0.26, -0.28, -0.045 do
			local top = b:top(x)
			local height = 0.03 + 0.03 * math.cos(x * 4)
			b:limb(Vector3.new(x, top - 0.004, 0), Vector3.new(x - 0.012, top + height, 0), 0.016, frost, "Spine")
		end
		for _ = 1, 30 do
			local x, y = b.random(-0.3, 0.32), b.random(-0.08, 0.1)
			local size = b.random(0.015, 0.03)
			if y < b:top(x) - size and y > b:bottom(x) + size then
				b:marks(x, y, size, size * 0.5, frost, v2(1, b.random(-1, 1)))
			end
		end
		b:stroke({ v2(0.28, 0.02), v2(0, 0.025), v2(-0.3, 0.005) }, 0.01, rgb(90, 150, 200))
		b:face(0.37, 0.03, 0.05, rgb(140, 220, 255), rgb(120, 170, 210))
	end,
}

end)()
species["GoldenMussel"] = (function()
return {
	Name = "Golden Mussel",
	Rarity = "Rare",
	RarityDenominator = 12,
	MinKg = 0.05,
	AverageKg = 0.22,
	MaxKg = 1.1,
	BaseValue = 56,
	Fight = 0,
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	Build = function(b, kit)
		local rgb, mussel = kit.rgb, kit.mussel
		mussel(b, rgb(204, 158, 54), rgb(240, 212, 128))
	end,
}

end)()
species["Graysby"] = (function()
return {
	Name = "Graysby",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.1,
	AverageKg = 0.65,
	MaxKg = 2.5,
	BaseValue = 53,
	Fight = 0.035,
	Pools = { "CoralShallows", "PirateCove" },
	Seasons = { "Summer", "Autumn" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####", "####" },
	},
	-- Small russet grouper with reddish spots and three dark spots along the dorsal base.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(136, 84, 70), side = rgb(194, 140, 114), belly = rgb(226, 196, 164) }
		local fin = rgb(150, 90, 74)
		b:fishBody(0.28, 0.15, colors, 0.075)
		local dorsal = b:edgeFin(0.17, -0.22, { 0.055, 0.075, 0.07, 0.06, 0.055, 0.065, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, colors.back)
		b:edgeFin(-0.08, -0.24, { 0.065, 0.075, 0.055 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.06, 0.045 }, fin, true)
		b:roundTail(0.135, fin)
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		b:speckle(42, v2(-0.3, 0.31), v2(-0.09, 0.11), v2(0.008, 0.014), rgb(132, 64, 56))
		for _, x in { 0.12, -0.035, -0.18 } do
			b:marks(x, b:top(x) * 0.74, 0.042, 0.032, rgb(58, 46, 40))
		end
		b:face(0.37, 0.04, 0.043, rgb(184, 142, 70), colors.back)
	end,
}

end)()
species["GreatWhiteTooth"] = (function()
return {
	Name = "Great White Tooth",
	Rarity = "Legendary",
	RarityDenominator = 1 / 0.03,
	MinKg = 1,
	AverageKg = 1,
	MaxKg = 1,
	BaseValue = 800,
	Fight = 0,
	DropOnly = true,
	Shapes = {
		Normal = { "#" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		b:fin({ v2(-0.26, -0.25), v2(0.26, -0.25), v2(0.04, 0.40) }, rgb(239, 235, 211))
		b:ellipsoid("Root", CFrame.new(0, -0.24, 0), Vector3.new(0.53, 0.11, 0.10), rgb(203, 190, 161))
	end,
}

end)()
species["GreenMussel"] = (function()
return {
	Name = "Green Mussel",
	Rarity = "Uncommon",
	RarityDenominator = 6,
	MinKg = 0.04,
	AverageKg = 0.18,
	MaxKg = 0.9,
	BaseValue = 30,
	Fight = 0,
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	Build = function(b, kit)
		local rgb, mussel = kit.rgb, kit.mussel
		mussel(b, rgb(45, 100, 67), rgb(134, 175, 104))
	end,
}

end)()
species["GreenSturgeon"] = (function()
return {
	Name = "Green Sturgeon",
	Rarity = "Epic",
	RarityDenominator = 30,
	MinKg = 10,
	AverageKg = 45,
	MaxKg = 160,
	LengthScale = 1.7,
	BaseValue = 395,
	Fight = 0.07,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Summer" },
	Shapes = {
		Normal = { "#####" },
		Big = { "######", ".####." },
		Huge = { "#######", "#######" },
	},
	Build = function(b, kit)
		local rgb, sturgeon = kit.rgb, kit.sturgeon
		sturgeon(b, {
			colors = { back = rgb(62, 82, 52), side = rgb(124, 140, 100), belly = rgb(222, 224, 200) },
			fin = rgb(84, 98, 70),
			scute = rgb(196, 200, 172),
			snout = Vector3.new(0.27, 0.07, 0.085),
			snoutAt = Vector3.new(0.47, -0.016, 0),
			stripe = rgb(96, 132, 72),
			iris = rgb(150, 150, 110),
		})
	end,
}

end)()
species["GreyEel"] = (function()
return {
	Name = "Grey Eel",
	Rarity = "Rare",
	RarityDenominator = 20,
	MinKg = 0.5,
	AverageKg = 2,
	MaxKg = 12,
	BaseValue = 65,
	Fight = 0.06,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", "#..." },
		Huge = { "#####", "#...#" },
	},
	Build = function(b, kit)
		local rgb, eel = kit.rgb, kit.eel
		eel(b, {
			back = rgb(84, 88, 92),
			side = rgb(128, 132, 134),
			belly = rgb(208, 206, 192),
			fin = rgb(110, 112, 108),
			iris = rgb(150, 150, 120),
		})
	end,
}

end)()
species["GulfConey"] = (function()
return {
	Name = "Gulf Coney",
	Rarity = "Common",
	RarityDenominator = 5,
	MinKg = 0.08,
	AverageKg = 0.35,
	MaxKg = 1.3,
	BaseValue = 24,
	Fight = 0.02,
	Pools = { "CoralShallows" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####", "####" },
	},
	-- A compact golden coney with bright blue spots and a charcoal saddle at the tail base.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(164, 116, 36), side = rgb(222, 176, 60), belly = rgb(248, 228, 156) }
		local fin = rgb(194, 132, 42)
		b:fishBody(0.26, 0.14, colors, 0.075)
		local dorsal = b:edgeFin(0.17, -0.22, { 0.055, 0.075, 0.07, 0.06, 0.055, 0.065, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, colors.back)
		b:edgeFin(-0.08, -0.24, { 0.065, 0.075, 0.055 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.06, 0.045 }, fin, true)
		b:roundTail(0.135, fin)
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		b:speckle(36, v2(-0.28, 0.3), v2(-0.085, 0.1), v2(0.007, 0.014), rgb(76, 152, 218))
		b:marks(-0.27, 0.025, 0.072, 0.065, rgb(70, 56, 32))
		b:marks(0.3, 0.045, 0.028, 0.025, rgb(82, 160, 220))
		b:face(0.37, 0.04, 0.043, rgb(198, 104, 48), colors.back)
	end,
}

end)()
species["GulfFlounder"] = (function()
return {
	Name = "Gulf Flounder",
	Rarity = "Epic",
	RarityDenominator = 50,
	MinKg = 0.4,
	AverageKg = 1.5,
	MaxKg = 10,
	BaseValue = 160,
	Fight = 0.03,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "##", "##" },
		Big = { "###", "##." },
		Huge = { "###", "###" },
	},
	Build = function(b, kit)
		local rgb, v2, flatfish = kit.rgb, kit.v2, kit.flatfish
		flatfish(b, {
			top = rgb(124, 98, 66),
			under = rgb(238, 236, 228),
			fin = rgb(142, 114, 80),
			ray = rgb(100, 80, 56),
			light = rgb(156, 128, 90),
			dark = rgb(92, 70, 46),
			ocelli = { v2(-0.02, 0.11), v2(-0.02, -0.11), v2(-0.2, 0) },
			ring = rgb(204, 182, 142),
			center = rgb(36, 28, 22),
			iris = rgb(206, 176, 90),
			mouth = rgb(60, 44, 30),
		})
	end,
}

end)()
species["HairyNescioFih"] = (function()
return {
	Name = "Hairy Nescio Fih",
	Rarity = "Admin",
	RarityDenominator = 5000000,
	MinKg = 20,
	AverageKg = 48,
	MaxKg = 180,
	BaseValue = 150000,
	Fight = 0.35,
	Pools = { "MainLake", "OpenSea" },
	Seasons = { "Spring", "Summer", "Autumn", "Winter" },
	Shapes = {
		Normal = { "#####", "#####" },
		Big = { "######", "######", "######" },
		Huge = { "########", "########", "########", "########" },
	},
	-- The Nescio Fih, but worse: the same pale creature under a shaggy coat
	-- of brown hair, with a long mane down its back.
	Build = function(b, kit)
		kit.nescio(b, { hairy = true })
	end,
}

end)()
species["Halibut"] = (function()
return {
	Name = "Halibut",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 1,
	AverageKg = 6,
	MaxKg = 180,
	LengthScale = 1.25,
	BaseValue = 18,
	Fight = 0.04,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Shapes = {
		Normal = { "##", "##" },
		Big = { "###", "###" },
		Huge = { "#####", "#####", "#####" },
	},
	Build = function(b, kit)
		local rgb, flatfish = kit.rgb, kit.flatfish
		flatfish(b, {
			top = rgb(70, 66, 50),
			under = rgb(244, 244, 238),
			fin = rgb(80, 76, 58),
			ray = rgb(52, 50, 38),
			light = rgb(100, 96, 74),
			dark = rgb(46, 44, 34),
			iris = rgb(170, 160, 120),
			mouth = rgb(36, 34, 26),
		})
	end,
}

end)()
species["Herring"] = (function()
return {
	Name = "Herring",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.1,
	AverageKg = 0.25,
	MaxKg = 0.9,
	BaseValue = 48,
	Fight = 0.04,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Winter" },
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "###" },
	},
	-- Slim silver schooling fish with a blue-green back.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(46, 84, 110), side = rgb(186, 198, 206), belly = rgb(244, 246, 248) }
		local fin = rgb(160, 172, 180)
		b:fishBody(0.19, 0.1, colors, 0.03)
		b:edgeFin(0.05, -0.06, { 0.065, 0.055, 0.03 }, fin, false, 0.15)
		b:edgeFin(-0.12, -0.22, { 0.03, 0.025 }, fin, true, 0.15)
		b:edgeFin(0.0, -0.05, { 0.03 }, fin, true, 0.15)
		b:forkTail(0.13, 0.09, fin, 0.1)
		b:pectoral(0.21, -0.04, 0.07, 0.025, fin, 0.15)
		b:stroke({ v2(0.26, 0.03), v2(-0.3, 0.015) }, 0.01, rgb(140, 176, 196))
		for x = 0.2, -0.24, -0.04 do
			b:stroke({ v2(x, b:bottom(x) * 0.3), v2(x - 0.01, b:bottom(x) * 0.8) }, 0.004, rgb(220, 226, 232))
		end
		b:face(0.37, 0.018, 0.054, rgb(220, 224, 220), rgb(120, 140, 150))
	end,
}

end)()
species["Kelp"] = (function()
return {
	Name = "Kelp",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.1,
	AverageKg = 0.35,
	MaxKg = 1.5,
	BaseValue = 7,
	Fight = 0,
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	-- Giant kelp: a long stipe from a root-like holdfast, with broad, ruffled
	-- golden-brown blades on small gas bladders at staggered heights.
	Build = function(b, kit)
		local rgb, algaBlade = kit.rgb, kit.algaBlade
		local stipe, holdfast, bladder = rgb(92, 72, 34), rgb(70, 56, 30), rgb(150, 120, 52)
		local blades = { rgb(128, 104, 44), rgb(112, 92, 40), rgb(140, 114, 50), rgb(104, 86, 38) }
		local root = Vector3.new(-0.48, -0.06, 0)
		b:ellipsoid("Holdfast", CFrame.new(root), Vector3.new(0.1, 0.07, 0.11), holdfast)
		for index, angle in { 0.6, 2.2, 3.6, 5.0 } do
			local tip = root + Vector3.new(-0.02, -0.035, 0) + Vector3.new(0, 0, math.cos(angle) * 0.06)
			b:limb(root, tip + Vector3.new(0.01 * index, 0, math.sin(angle) * 0.01), 0.016, holdfast, "Holdfast")
		end
		local points = {}
		for step = 0, 6 do
			local t = step / 6
			table.insert(points, root + Vector3.new(0.9 * t, 0.05 * math.sin(t * math.pi * 1.3), 0.03 * math.sin(t * 4)))
		end
		for index = 1, #points - 1 do
			b:limb(points[index], points[index + 1], 0.016, stipe, "Midrib")
		end
		for index, spec in { { 2, 1 }, { 3, -1 }, { 4, 1 }, { 5, -1 }, { 6, 1 } } do
			local base, sign = points[spec[1]], spec[2]
			b:ellipsoid("Bladder", CFrame.new(base + Vector3.new(0.01, sign * 0.02, 0)), Vector3.new(0.035, 0.026, 0.026), bladder)
			local length = 0.42 - index * 0.03
			algaBlade(b, base + Vector3.new(0.02, sign * 0.03, 0), Vector3.new(0.75, sign * 0.55, 0.1 * sign), length, function(t)
				return 0.012 + 0.045 * math.sin(math.min(t * 1.4, 1) * math.pi / 2) * (if t > 0.8 then 1 - (t - 0.8) * 2.5 else 1)
			end, blades[(index - 1) % #blades + 1], 0.12, index)
		end
		b.model:SetAttribute("ViewDirection", Vector3.new(0.25, 0.4, 1))
	end,
}

end)()
species["KingCrab"] = (function()
return {
	Name = "King Crab",
	Rarity = "Rare",
	RarityDenominator = 20,
	MinKg = 0.8,
	AverageKg = 2.6,
	MaxKg = 11,
	BaseValue = 60,
	Fight = 0,
	Shapes = {
		Normal = { "###", "###" },
		Big = { "####", "####" },
		Huge = { "#####", "#####", "#####" },
	},
	Build = function(b, kit)
		local rgb, crab = kit.rgb, kit.crab
		local spine = rgb(226, 132, 104)
		crab(b, {
			shell = rgb(176, 52, 40),
			dark = rgb(144, 38, 32),
			belly = rgb(238, 214, 190),
			clawColor = rgb(188, 64, 46),
			legColor = rgb(186, 62, 46),
			tipColor = rgb(84, 34, 28),
			carapace = Vector3.new(0.38, 0.17, 0.42),
			teeth = 3,
			claw = 1.15,
			offhand = 0.78,
			armSpines = true,
			spineColor = spine,
			legs = { lean = { 0.45, -0.05, -0.55 }, thigh = 0.25, shin = 0.25, lift = 0.1, drop = 0.24, width = 0.044 },
			knobs = { count = 46, size = Vector2.new(0.014, 0.024), color = spine },
		})
	end,
}

end)()
species["LargemouthBass"] = (function()
return {
	Name = "Largemouth Bass",
	Rarity = "Rare",
	RarityDenominator = 14,
	MinKg = 0.3,
	AverageKg = 2.3,
	MaxKg = 11,
	BaseValue = 62,
	Fight = 0.1,
	Pools = { "MainLake", "SoddenMire" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "#####", "#####" },
	},
	-- Species-specific body proportions, fins and flank markings share the smooth mesh pipeline.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(46, 72, 36), side = rgb(130, 152, 78), belly = rgb(232, 232, 196) }
		local fin = rgb(96, 118, 60)
		b:fishBody(0.31, 0.16, colors, 0.1)
		local dorsal = b:edgeFin(0.15, -0.23, { 0.05, 0.065, 0.06, 0.045, 0.015, 0.02, 0.075, 0.085, 0.065 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, rgb(42, 62, 32))
		b:edgeFin(-0.08, -0.23, { 0.06, 0.07, 0.045 }, fin, true)
		b:edgeFin(0.08, 0, { 0.055, 0.04 }, fin, true)
		b:forkTail(0.13, 0.028, fin)
		b:pectoral(0.21, -0.04, 0.105, 0.04, fin, 0.1)
		-- Broad broken lateral stripe and a jaw hinge extending behind the eye.
		for x = 0.25, -0.29, -0.055 do
			b:marks(x, 0, 0.073, 0.042, rgb(42, 64, 30))
		end
		b:stroke({ v2(0.47, -0.025), v2(0.34, -0.075), v2(0.28, -0.045) }, 0.012, rgb(42, 54, 28))
		b:ellipsoid("LowerJaw", CFrame.new(0.425, -0.065, 0), Vector3.new(0.15, 0.035, 0.095), colors.belly)
		b:face(0.37, 0.033, 0.046, rgb(188, 152, 68), rgb(42, 62, 32))
	end,
}

end)()
species["LeatherBoot"] = (function()
return {
	Name = "Leather Boot",
	Rarity = "Junk",
	RarityDenominator = 50,
	MinKg = 0.4,
	AverageKg = 0.8,
	MaxKg = 1.2,
	BaseValue = 1,
	Fight = 0,
	Shapes = {
		Normal = { "#.", "##" },
	},
	Build = function(b, kit)
		local rgb = kit.rgb
		local leather, trim = rgb(119, 76, 49), rgb(88, 54, 35)
		local rubber, welt, thread = rgb(37, 32, 29), rgb(78, 54, 38), rgb(167, 131, 91)
		local lace, brass = rgb(57, 43, 33), rgb(155, 120, 66)
		local function cylinder(name, center, height, length, width, color)
			local part = b:part(
				name,
				"Part",
				Vector3.new(height, length, width),
				CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2),
				color
			)
			part.Shape = Enum.PartType.Cylinder
			return part
		end
		-- Straight sides meet round end caps tangentially, keeping the sole flat
		-- underneath without the old square toe and sharp heel corners.
		local function roundedSole(name, center, length, width, height, radius, color)
			local straight = length - radius * 2
			b:part(name, "Part", Vector3.new(straight, height, width), CFrame.new(center), color)
			for _, side in { -1, 1 } do
				cylinder(name, center + Vector3.new(side * straight / 2, 0, 0), height, radius * 2, width, color)
			end
		end
		roundedSole("Sole", Vector3.new(0.025, -0.282, 0), 0.86, 0.366, 0.063, 0.17, rubber)
		roundedSole("Welt", Vector3.new(0.025, -0.241, 0), 0.872, 0.378, 0.023, 0.176, welt)
		roundedSole("Heel", Vector3.new(-0.245, -0.326, 0), 0.285, 0.326, 0.04, 0.1, rubber)
		roundedSole("LowerLeather", Vector3.new(0.025, -0.216, 0), 0.817, 0.332, 0.045, 0.16, leather)

		-- One long vamp gives the toe a continuous curve. The ankle overlaps the
		-- round shaft below the laces, so it reads as shaped leather rather than balls.
		b:ellipsoid("Foot", CFrame.new(0.025, -0.143, 0), Vector3.new(0.828, 0.286, 0.352), leather)
		b:ellipsoid("Ankle", CFrame.new(-0.205, -0.069, 0), Vector3.new(0.342, 0.36, 0.322), leather)
		cylinder("Shaft", Vector3.new(-0.215, 0.108, 0), 0.356, 0.31, 0.31, leather)
		b:ellipsoid(
			"Quarter",
			CFrame.new(-0.1, 0.065, 0) * CFrame.Angles(0, 0, 0.32),
			Vector3.new(0.34, 0.43, 0.32),
			leather
		)
		b:ellipsoid("HeelCounter", CFrame.new(-0.322, -0.135, 0), Vector3.new(0.148, 0.206, 0.306), trim)
		b:ellipsoid("Tongue", CFrame.new(0.035, 0.103, 0) * CFrame.Angles(0, 0, 0.4), Vector3.new(0.13, 0.386, 0.18), trim)
		for _, side in { -1, 1 } do
			b:ellipsoid(
				"LaceFacing",
				CFrame.new(0.061, 0.102, side * 0.065) * CFrame.Angles(0, 0, 0.42),
				Vector3.new(0.083, 0.35, 0.043),
				leather
			)
		end

		-- A recessed dark oval beneath a rolled leather rim suggests a lined opening.
		cylinder("Opening", Vector3.new(-0.215, 0.287, 0), 0.006, 0.281, 0.281, rgb(29, 22, 19))
		local segments = 32
		for index = 0, segments - 1 do
			local a, c = index * math.pi * 2 / segments, (index + 1) * math.pi * 2 / segments
			local start = Vector3.new(-0.215 + math.cos(a) * 0.149, 0.304, math.sin(a) * 0.149)
			local finish = Vector3.new(-0.215 + math.cos(c) * 0.149, 0.304, math.sin(c) * 0.149)
			b:ellipsoid(
				"RolledCuff",
				CFrame.lookAt((start + finish) / 2, finish) * CFrame.Angles(0, math.pi / 2, 0),
				Vector3.new((finish - start).Magnitude + 0.055, 0.036, 0.036),
				trim
			)
		end

		-- Brass eyelets and lifted crisscross laces follow the sloping tongue.
		local normal = Vector3.new(1, 0.42, 0).Unit
		local rows = {}
		for index = 0, 4 do
			local y = -0.015 + index * 0.058
			local x = 0.142 - index * 0.026
			rows[index + 1] = Vector3.new(x, y, 0)
			for _, side in { -1, 1 } do
				local position = Vector3.new(x, y, side * 0.065)
				local frame = CFrame.lookAt(position, position + normal)
				b:ellipsoid("Eyelet", frame, Vector3.new(0.027, 0.027, 0.009), brass)
				b:ellipsoid("EyeletInset", frame + normal * 0.004, Vector3.new(0.013, 0.013, 0.005), lace)
			end
		end
		for index = 1, #rows - 1 do
			for _, side in { -1, 1 } do
				local a = rows[index] + Vector3.new(0, 0, side * 0.065) + normal * 0.009
				local c = rows[index + 1] - Vector3.new(0, 0, side * 0.065) + normal * 0.009
				local middle = (a + c) / 2 + normal * (if side == 1 then 0.012 else 0.021)
				b:limb(a, middle, 0.01, lace, "Lace")
				b:limb(middle, c, 0.01, lace, "Lace")
			end
		end
		local knot = rows[#rows] + normal * 0.019
		b:ellipsoid("LaceKnot", CFrame.new(knot), Vector3.new(0.027, 0.021, 0.029), lace)
		for _, side in { -1, 1 } do
			local tip = knot + Vector3.new(0.022, -0.063, side * 0.049)
			b:limb(knot, tip, 0.009, lace, "LaceEnd")
		end

		-- Small separate stitches follow the curved welt, including the round toe.
		local straight, radius = 0.52, 0.17
		local perimeter = straight * 2 + math.pi * radius * 2
		local function stitchPoint(distance)
			if distance < straight then
				return Vector3.new(-0.235 + distance, -0.226, 0.174)
			elseif distance < straight + math.pi * radius then
				local angle = math.pi / 2 - (distance - straight) / radius
				return Vector3.new(0.285 + math.cos(angle) * 0.166, -0.226, math.sin(angle) * 0.174)
			elseif distance < straight * 2 + math.pi * radius then
				return Vector3.new(0.285 - (distance - straight - math.pi * radius), -0.226, -0.174)
			end
			local angle = -math.pi / 2 - (distance - straight * 2 - math.pi * radius) / radius
			return Vector3.new(-0.235 + math.cos(angle) * 0.166, -0.226, math.sin(angle) * 0.174)
		end
		for index = 0, 27 do
			local distance = index * perimeter / 28
			b:limb(stitchPoint(distance), stitchPoint(distance + 0.014), 0.005, thread, "WeltStitch")
		end
		-- The pull tab and restrained toe wear keep the found-boot character.
		b:limb(Vector3.new(-0.36, 0.235, -0.026), Vector3.new(-0.386, 0.345, -0.026), 0.022, trim, "PullTab")
		b:limb(Vector3.new(-0.386, 0.345, -0.026), Vector3.new(-0.386, 0.345, 0.026), 0.022, trim, "PullTab")
		b:limb(Vector3.new(-0.386, 0.345, 0.026), Vector3.new(-0.36, 0.235, 0.026), 0.022, trim, "PullTab")
		for index = 0, 2 do
			local x, z = 0.315 + index * 0.018, 0.065 - index * 0.018
			local y = -0.143 + 0.143 * math.sqrt(1 - ((x - 0.025) / 0.414) ^ 2 - (z / 0.176) ^ 2)
			b:ellipsoid(
				"ToeScuff",
				CFrame.new(x, y + 0.001, z) * CFrame.Angles(0, 0, -0.4),
				Vector3.new(0.026, 0.003, 0.008),
				rgb(149, 107, 72)
			)
		end
		b.model:SetAttribute("ViewDirection", Vector3.new(0.85, 0.55, 1))
	end,
}

end)()
species["Lingcod"] = (function()
return {
	Name = "Lingcod",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 1,
	AverageKg = 5,
	MaxKg = 35,
	LengthScale = 1.15,
	BaseValue = 25,
	Fight = 0.05,
	Pools = { "MainLake" },
	Seasons = { "Winter" },
	Requires = { "Storm" },
	Shapes = {
		Normal = { "###" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	},
	-- Big-headed, big-mouthed bottom dweller mottled in browns and greens.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(86, 82, 58), side = rgb(140, 130, 96), belly = rgb(224, 218, 196) }
		local fin = rgb(110, 100, 70)
		b:fishBody(0.2, 0.14, colors, 0.06)
		-- Broad, flattened head with a huge mouth and jutting lower jaw.
		b:layered("Jaw", Vector3.new(0.36, -0.03, 0), Vector3.new(0.27, 0.15, 0.165), colors)
		b:layered("LowerJaw", Vector3.new(0.44, -0.058, 0), Vector3.new(0.13, 0.05, 0.11), colors)
		-- One long dorsal from nape to tail stalk, notched between spiny and soft parts.
		local spines = b:edgeFin(
			0.2,
			-0.27,
			{ 0.04, 0.055, 0.06, 0.05, 0.025, 0.045, 0.055, 0.06, 0.06, 0.055, 0.05, 0.04 },
			fin,
			false,
			0.05
		)
		b:rays(spines[2], { spines[4], spines[5], spines[6] }, rgb(70, 64, 44))
		b:edgeFin(-0.02, -0.26, { 0.05, 0.055, 0.05, 0.04 }, fin, true)
		b:roundTail(0.11, fin)
		b:pectoral(0.21, -0.05, 0.13, 0.05, fin)
		-- Irregular mottling: clusters of overlapping blotches in dark and copper.
		for _ = 1, 22 do
			local cx, cy = b.random(-0.3, 0.34), b.random(-0.05, 0.09)
			local tone = if b.random(0, 1) > 0.45 then rgb(48, 44, 30) else rgb(150, 132, 78)
			for _ = 1, 3 do
				local x, y = cx + b.random(-0.03, 0.03), cy + b.random(-0.02, 0.02)
				local size = b.random(0.02, 0.04)
				if y < b:top(x) - size * 0.6 and y > b:bottom(x) + size * 0.6 then
					b:marks(x, y, size * 1.3, size * 0.75, tone, v2(1, b.random(-0.6, 0.6)))
				end
			end
		end
		b:stroke({ v2(0.5, -0.035), v2(0.32, -0.075) }, 0.009, rgb(40, 34, 26))
		b:face(0.38, 0.03, 0.042, rgb(200, 180, 90), rgb(90, 86, 60))
	end,
}

end)()
species["LongbillSpearfish"] = (function()
return {
	Name = "Longbill Spearfish",
	Rarity = "Rare",
	RarityDenominator = 20,
	MinKg = 3,
	AverageKg = 12,
	MaxKg = 55,
	LengthScale = 1.5,
	BaseValue = 185,
	Fight = 0.08,
	Pools = { "CoralShallows" },
	Seasons = { "Spring", "Summer" },
	Requires = { "Clear", "Day" },
	Shapes = {
		Normal = { "####" },
		Big = { "#####", ".###." },
		Huge = { "######", ".####." },
	},
	-- A narrow body, long needle bill and a low continuous dorsal.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(30, 52, 100), side = rgb(128, 164, 188), belly = rgb(226, 234, 238) }
		local fin = rgb(36, 62, 114)
		b:fishBody(0.14, 0.085, colors, 0.015)
		b:edgeFin(0.26, -0.23, { 0.10, 0.12, 0.11, 0.09, 0.07, 0.05, 0.025 }, fin)
		b:edgeFin(-0.25, -0.3, { 0.025 }, fin)
		b:edgeFin(0.0, -0.16, { 0.065, 0.045, 0.025 }, fin, true)
		b:edgeFin(-0.25, -0.3, { 0.025 }, fin, true)
		b:lunateTail(0.18, fin)
		b:pectoral(0.22, -0.02, 0.16, 0.026, fin)
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.17, b:bottom(0.17), side * 0.009), Vector3.new(-0.08, -0.14, side * 0.018), 0.005, fin, "PelvicFin")
		end
		b:stroke({ v2(0.28, 0.012), v2(0.0, 0.008), v2(-0.3, 0.001) }, 0.006, rgb(74, 126, 178))
		b:limb(Vector3.new(0.44, 0.004, 0), Vector3.new(0.90, 0, 0), 0.015, colors.back, "Spear")
		b:face(0.375, 0.016, 0.035, rgb(190, 198, 196), rgb(70, 92, 120))
	end,
}

end)()
species["Mackerel"] = (function()
return {
	Name = "Mackerel",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.2,
	AverageKg = 0.5,
	MaxKg = 2,
	BaseValue = 18,
	Fight = 0.05,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Summer", "Autumn", "Winter" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####" },
	},
	-- Atlantic mackerel: green-blue back with bold, wavy black bars above an
	-- unspotted silver belly, widely spaced dorsals and dark finlets.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(30, 100, 92), side = rgb(170, 192, 188), belly = rgb(244, 246, 244) }
		local fin, finlet = rgb(70, 92, 92), rgb(52, 70, 72)
		b:fishBody(0.16, 0.1, colors, 0.03)
		local spines = b:edgeFin(0.12, 0.02, { 0.065, 0.06, 0.045, 0.03 }, fin, false, 0.1)
		b:rays(spines[1], { spines[4], spines[5] }, rgb(36, 50, 52))
		b:edgeFin(-0.09, -0.15, { 0.04, 0.03 }, fin)
		b:edgeFin(-0.09, -0.15, { 0.035, 0.025 }, fin, true)
		for index = 0, 4 do
			local x = -0.18 - index * 0.028
			for _, below in { false, true } do
				local edge = if below then b:bottom(x) else b:top(x)
				local sign = if below then -1 else 1
				b:fin({
					v2(x + 0.008, edge - sign * 0.004),
					v2(x - 0.012, edge + sign * 0.02),
					v2(x - 0.014, edge - sign * 0.004),
				}, finlet)
			end
		end
		b:forkTail(0.13, 0.085, fin)
		b:pectoral(0.21, -0.02, 0.08, 0.028, fin)
		for x = 0.2, -0.3, -0.035 do
			local top = b:top(x)
			b:stroke({
				v2(x, top * 0.9),
				v2(x - 0.018, top * 0.62),
				v2(x + 0.006, top * 0.38),
				v2(x - 0.01, top * 0.12),
			}, 0.008, rgb(10, 24, 26))
		end
		b:face(0.375, 0.015, 0.05, rgb(196, 204, 196), rgb(90, 108, 112))
	end,
}

end)()
species["MidnightCarp"] = (function()
return {
	Name = "Midnight Carp",
	Rarity = "Epic",
	RarityDenominator = 50,
	MinKg = 1,
	AverageKg = 5,
	MaxKg = 35,
	BaseValue = 170,
	Fight = 0.05,
	Pools = { "MainLake" },
	Seasons = { "Spring", "Autumn", "Winter" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "##", "##" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	},
	Build = function(b, kit)
		local rgb, carp = kit.rgb, kit.carp
		carp(b, {
			colors = { back = rgb(18, 20, 40), side = rgb(40, 46, 86), belly = rgb(96, 104, 150) },
			fin = rgb(30, 36, 76),
			scale = rgb(70, 92, 170),
			scaleAlt = rgb(48, 58, 112),
			barbel = rgb(60, 66, 110),
			lips = rgb(70, 76, 120),
			iris = rgb(190, 220, 255),
			line = rgb(60, 70, 120),
		})
	end,
}

end)()
species["NassauGrouper"] = (function()
return {
	Name = "Nassau Grouper",
	Rarity = "Rare",
	RarityDenominator = 16,
	MinKg = 1,
	AverageKg = 5,
	MaxKg = 25,
	BaseValue = 180,
	Fight = 0.065,
	Pools = { "CoralShallows" },
	Seasons = { "Spring", "Winter" },
	Requires = { "Day" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Sand-coloured Nassau grouper with five broad dark bars and a black tail saddle.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(134, 116, 76), side = rgb(212, 192, 140), belly = rgb(242, 228, 184) }
		local fin = rgb(144, 122, 76)
		b:fishBody(0.34, 0.18, colors, 0.075)
		local dorsal = b:edgeFin(0.17, -0.22, { 0.055, 0.075, 0.07, 0.06, 0.055, 0.065, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, colors.back)
		b:edgeFin(-0.08, -0.24, { 0.065, 0.075, 0.055 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.06, 0.045 }, fin, true)
		b:roundTail(0.135, fin)
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		for _, x in { 0.26, 0.13, 0, -0.13, -0.26 } do
			b:stroke({ v2(x + 0.01, b:top(x) * 0.86), v2(x - 0.018, b:bottom(x) * 0.65) }, 0.047, rgb(90, 76, 46))
		end
		b:marks(-0.3, 0.005, 0.06, 0.055, rgb(34, 32, 24))
		b:stroke({ v2(0.43, 0.04), v2(0.28, -0.065) }, 0.018, rgb(92, 78, 48))
		b:face(0.37, 0.04, 0.043, rgb(194, 166, 80), colors.back)
	end,
}

end)()
species["NescioFih"] = (function()
return {
	Name = "Nescio Fih",
	Rarity = "Admin",
	RarityDenominator = 1000000,
	MinKg = 18,
	AverageKg = 42,
	MaxKg = 160,
	BaseValue = 50000,
	Fight = 0.3,
	Pools = { "MainLake", "OpenSea" },
	Seasons = { "Spring", "Summer", "Autumn", "Winter" },
	Shapes = {
		Normal = { "#####", "#####" },
		Big = { "######", "######", "######" },
		Huge = { "########", "########", "########", "########" },
	},
	-- Nobody knows what it is. A pale, blotchy thing with a pointed shark's
	-- head, two frog legs folded under its hunched body and a paddle tail.
	Build = function(b, kit)
		kit.nescio(b, {})
	end,
}

end)()
species["OrangeSeaCucumber"] = (function()
return {
	Name = "Orange Sea Cucumber",
	Rarity = "Rare",
	RarityDenominator = 12,
	MinKg = 0.1,
	AverageKg = 0.5,
	MaxKg = 2,
	BaseValue = 140,
	Fight = 0,
	Pools = { "OpenSea" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####" },
	},
	-- Orange-footed sea cucumber: a plump, leathery orange-brown body with rows of
	-- tube feet along five ridges and a crown of bushy, branching orange tentacles.
	Build = function(b, kit)
		local rgb = kit.rgb
		local colors = { back = rgb(150, 72, 30), side = rgb(196, 102, 44), belly = rgb(230, 156, 96) }
		local tentacle, foot = rgb(240, 124, 40), rgb(246, 176, 110)
		b:layered("Body", Vector3.new(-0.04, 0, 0), Vector3.new(0.78, 0.24, 0.25), colors)
		b:layered("Front", Vector3.new(0.3, 0.005, 0), Vector3.new(0.18, 0.19, 0.2), colors)
		b:layered("Rear", Vector3.new(-0.38, -0.005, 0), Vector3.new(0.16, 0.16, 0.17), colors)
		-- Rows of tube feet along the body ridges.
		for _, row in { { 0.06, 1 }, { 0.06, -1 }, { -0.06, 1 }, { -0.06, -1 } } do
			for x = -0.36, 0.3, 0.05 do
				local position, normal = b:surface(x, row[1], row[2])
				if position and normal then
					b:limb(position - normal * 0.004, position + normal * 0.018, 0.016, foot, "Spine")
				end
			end
		end
		for x = -0.36, 0.3, 0.05 do
			local bottom = b:bottom(x)
			b:ellipsoid("TubeFoot", CFrame.new(x, bottom + 0.01, 0), Vector3.new(0.02, 0.022, 0.02), foot)
		end
		b:ellipsoid("Mouth", CFrame.new(0.39, 0.01, 0), Vector3.new(0.04, 0.09, 0.09), colors.back)
		for index = 0, 9 do
			local angle = index / 10 * math.pi * 2
			local spread = Vector3.new(0, math.cos(angle), math.sin(angle))
			local root = Vector3.new(0.39, 0.01, 0) + spread * 0.04
			local middle = Vector3.new(0.47, 0.01, 0) + spread * 0.08
			b:limb(root, middle, 0.016, tentacle, "Filament")
			-- Each tentacle branches into a little bush at its end.
			for branch = -1, 1 do
				local twist = Vector3.new(0, -math.sin(angle), math.cos(angle)) * branch * 0.025
				b:limb(middle, middle + spread * 0.04 + Vector3.new(0.035, 0, 0) + twist, 0.01, tentacle, "Filament")
			end
		end
	end,
}

end)()
species["Parrotfish"] = (function()
return {
	Name = "Parrotfish",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.3,
	AverageKg = 1.6,
	MaxKg = 9,
	BaseValue = 20,
	Fight = 0.04,
	Pools = { "PirateCove" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	},
	-- Reef parrotfish that grazes the coral round Pirate Cove: sea-green scales edged in pink,
	-- a fused ivory beak and a crescent tail.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(28, 132, 128), side = rgb(64, 188, 166), belly = rgb(236, 170, 188) }
		local fin = rgb(226, 112, 168)
		local scale = rgb(232, 138, 176)
		b:fishBody(0.3, 0.14, colors, 0.08)
		b:edgeFin(0.2, -0.24, { 0.05, 0.06, 0.06, 0.06, 0.06, 0.055, 0.05 }, fin, false, 0.05)
		b:edgeFin(-0.04, -0.24, { 0.05, 0.05, 0.04 }, fin, true, 0.05)
		b:edgeFin(0.1, 0.02, { 0.05, 0.035 }, fin, true, 0.1)
		b:lunateTail(0.15, fin)
		b:pectoral(0.2, -0.03, 0.1, 0.04, rgb(240, 190, 70), 0.1)
		-- Pink scale edges in staggered rows along the flank.
		for row = 0, 4 do
			local y = -0.06 + row * 0.03
			for x = 0.18 - (row % 2) * 0.025, -0.3, -0.05 do
				if y < b:top(x) - 0.014 and y > b:bottom(x) + 0.014 then
					b:marks(x, y, 0.022, 0.012, scale, v2(0.3, 1))
				end
			end
		end
		-- Bright facial stripes running back from the beak.
		b:stroke({ v2(0.44, 0.0), v2(0.32, 0.03), v2(0.24, 0.035) }, 0.008, rgb(250, 214, 120))
		b:stroke({ v2(0.44, -0.03), v2(0.3, -0.04) }, 0.008, rgb(250, 214, 120))
		local beakY = b:bottom(0.46) * 0.25
		b:ellipsoid("Beak", CFrame.new(0.485, beakY, 0), Vector3.new(0.05, 0.04, 0.045), rgb(238, 232, 214))
		b:face(0.37, 0.04, 0.046, rgb(240, 180, 60), rgb(30, 110, 110))
	end,
}

end)()
species["PeacockBass"] = (function()
return {
	Name = "Peacock Bass",
	Rarity = "Rare",
	RarityDenominator = 18,
	MinKg = 0.4,
	AverageKg = 2.2,
	MaxKg = 10,
	BaseValue = 76,
	Fight = 0.12,
	Pools = { "MainLake", "SoddenMire" },
	Seasons = { "Summer" },
	Requires = { "Clear", "Day" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "#####", "#####" },
	},
	-- Species-specific body proportions, fins and flank markings share the smooth mesh pipeline.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(70, 108, 38), side = rgb(208, 184, 58), belly = rgb(242, 196, 82) }
		local fin = rgb(186, 110, 42)
		b:fishBody(0.3, 0.15, colors, 0.07)
		local dorsal = b:edgeFin(0.15, -0.23, { 0.06, 0.075, 0.07, 0.055, 0.04, 0.055, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, rgb(42, 66, 32))
		b:edgeFin(-0.08, -0.23, { 0.06, 0.07, 0.045 }, fin, true)
		b:edgeFin(0.08, 0, { 0.055, 0.04 }, fin, true)
		b:forkTail(0.13, 0.028, fin)
		b:pectoral(0.21, -0.04, 0.105, 0.04, fin, 0.1)
		-- Three broad bars and the orange-rimmed tail eyespot.
		for _, x in { 0.18, -0.015, -0.21 } do
			b:stroke({ v2(x, b:top(x) * 0.9), v2(x - 0.025, b:bottom(x) * 0.75) }, 0.048, rgb(44, 60, 30))
		end
		b:marks(-0.3, 0, 0.076, 0.07, rgb(240, 172, 46))
		b:marks(-0.3, 0, 0.045, 0.043, rgb(24, 34, 24))
		b:edgeFin(-0.07, -0.2, { 0.015, 0.018, 0.012 }, rgb(234, 130, 40), true)
		b:face(0.37, 0.033, 0.046, rgb(208, 78, 38), rgb(42, 66, 32))
	end,
}

end)()
species["Pike"] = (function()
return {
	Name = "Pike",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.5,
	AverageKg = 2.5,
	MaxKg = 25,
	LengthScale = 1.25,
	BaseValue = 26,
	Fight = 0.07,
	Pools = { "MainLake" },
	Seasons = { "Summer", "Autumn" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "#####", ".###." },
	},
	-- Long ambush predator: dorsal and anal fins set far back, flat duck-bill snout.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(58, 78, 44), side = rgb(118, 140, 82), belly = rgb(226, 228, 196) }
		local fin = rgb(132, 110, 62)
		b:fishBody(0.15, 0.1, colors, 0.02)
		b:layered("Snout", Vector3.new(0.45, -0.006, 0), Vector3.new(0.2, 0.065, 0.08), colors)
		b:edgeFin(-0.12, -0.25, { 0.06, 0.07, 0.06, 0.04 }, fin)
		b:edgeFin(-0.14, -0.26, { 0.05, 0.06, 0.04 }, fin, true)
		b:edgeFin(0.02, -0.04, { 0.04 }, fin, true)
		b:forkTail(0.11, 0.04, fin)
		b:pectoral(0.25, -0.03, 0.08, 0.025, fin)
		b:speckle(44, v2(-0.3, 0.3), v2(-0.04, 0.06), v2(0.014, 0.026), rgb(206, 214, 150))
		for _ = 1, 10 do
			b:finSpot(b.random(-0.47, -0.37), b.random(-0.09, 0.09), 0.014, rgb(60, 50, 30))
		end
		b:stroke({ v2(0.54, -0.014), v2(0.4, -0.03) }, 0.007, rgb(36, 34, 26))
		b:face(0.35, 0.02, 0.04, rgb(214, 186, 80), rgb(80, 96, 56))
	end,
}

end)()
species["PinkSalmon"] = (function()
return {
	Name = "Pink Salmon",
	Rarity = "Uncommon",
	RarityDenominator = 8,
	MinKg = 0.5,
	AverageKg = 1.8,
	MaxKg = 6.5,
	BaseValue = 52,
	Fight = 0.05,
	Pools = { "MainLake", "FrostmereExpanse" },
	Seasons = { "Summer", "Autumn" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Spawning pink salmon with a high shoulder hump and bold oval tail spots.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(106, 110, 80), side = rgb(186, 168, 142), belly = rgb(230, 214, 190) }
		local fin, spot = rgb(112, 118, 88), rgb(36, 46, 44)
		b:fishBody(0.24, 0.13, colors, 0.05)
		b:layered("Hump", Vector3.new(0.03, 0.055, 0), Vector3.new(0.40, 0.27, 0.12), colors)
		b:layered("Kype", Vector3.new(0.445, -0.035, 0), Vector3.new(0.15, 0.085, 0.08), colors)
		b:edgeFin(0.08, -0.08, { 0.085, 0.08, 0.055, 0.035 }, fin)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.25, b:top(-0.25) + 0.008, 0), Vector3.new(0.055, 0.035, 0.014), fin)
		b:edgeFin(-0.12, -0.25, { 0.06, 0.055, 0.035 }, fin, true)
		b:edgeFin(0.02, -0.06, { 0.05, 0.04 }, fin, true)
		b:forkTail(0.12, 0.04, fin)
		b:pectoral(0.22, -0.045, 0.11, 0.04, fin)
		b:speckle(24, v2(-0.30, 0.30), v2(0, 0.11), v2(0.015, 0.027), spot)
		for _, y in { -0.085, -0.05, 0.045, 0.08 } do
			b:finSpot(-0.46, y, 0.018, spot)
			b:finSpot(-0.425, y * 0.55, 0.014, spot)
		end
		b:stroke({ v2(0.28, -0.012), v2(0, -0.016), v2(-0.28, -0.008) }, 0.005, fin)
		b:face(0.38, 0.025, 0.04, rgb(212, 192, 118), fin)
	end,
}


end)()
species["Pufferfish"] = (function()
return {
	Name = "Pufferfish",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.2,
	AverageKg = 0.9,
	MaxKg = 6,
	BaseValue = 53,
	Fight = 0.02,
	Pools = { "OpenSea" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "#" },
		Big = { "##", "##" },
		Huge = { ".#.", "###", ".#." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(150, 132, 76), side = rgb(196, 180, 120), belly = rgb(240, 236, 214) }
		local fin = rgb(190, 170, 110)
		b:beginSkin(colors)
		b:layered("Body", Vector3.new(0.06, 0, 0), Vector3.new(0.74, 0.58, 0.54), colors)
		b:layered("TailStalk", Vector3.new(-0.3, 0, 0), Vector3.new(0.18, 0.12, 0.1), colors)
		b:edgeFin(-0.2, -0.27, { 0.06, 0.05 }, fin, false, 0.2)
		b:edgeFin(-0.2, -0.27, { 0.06, 0.05 }, fin, true, 0.2)
		b:roundTail(0.11, fin, 0.15)
		b:pectoral(0.18, 0, 0.08, 0.06, fin, 0.25)
		b:speckle(40, v2(-0.25, 0.38), v2(0, 0.26), v2(0.016, 0.03), rgb(70, 60, 36))
		-- Inflated: short spines stand out all over the body.
		for _ = 1, 60 do
			local x, y = b.random(-0.24, 0.36), b.random(-0.25, 0.25)
			local side = if b.random(0, 1) > 0.5 then 1 else -1
			local position, normal = b:surface(x, y, side)
			if position and normal then
				b:limb(position - normal * 0.004, position + normal * 0.04, 0.007, rgb(226, 218, 186), "Spine")
			end
		end
		b:ellipsoid("Beak", CFrame.new(0.43, -0.04, 0), Vector3.new(0.05, 0.05, 0.07), rgb(232, 226, 200))
		b:face(0.3, 0.07, 0.085, rgb(64, 140, 120), rgb(160, 144, 90))
	end,
}

end)()
species["RainbowTrout"] = (function()
return {
	Name = "Rainbow Trout",
	Rarity = "Rare",
	RarityDenominator = 20,
	MinKg = 0.3,
	AverageKg = 1.5,
	MaxKg = 12,
	BaseValue = 62,
	Fight = 0.05,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Requires = { "Rain" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	},
	Build = function(b, kit)
		local rgb, trout = kit.rgb, kit.trout
		trout(b, {
			colors = { back = rgb(70, 96, 70), side = rgb(196, 200, 176), belly = rgb(244, 240, 230) },
			fin = rgb(156, 150, 120),
			band = rgb(226, 112, 140),
			spots = 70,
			spot = rgb(28, 30, 24),
			iris = rgb(210, 180, 100),
			line = rgb(110, 116, 96),
		})
	end,
}

end)()
species["RedHindGrouper"] = (function()
return {
	Name = "Red Hind Grouper",
	Rarity = "Uncommon",
	RarityDenominator = 10,
	MinKg = 0.2,
	AverageKg = 1.4,
	MaxKg = 5.5,
	BaseValue = 64,
	Fight = 0.045,
	Pools = { "CoralShallows", "PirateCove" },
	Seasons = { "Spring", "Summer" },
	Requires = { "Day" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####", "####" },
	},
	-- Cream-coloured hind densely covered in red spots, including its rounded tail.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(174, 126, 90), side = rgb(232, 202, 156), belly = rgb(248, 232, 194) }
		local fin = rgb(174, 104, 78)
		b:fishBody(0.29, 0.15, colors, 0.075)
		local dorsal = b:edgeFin(0.17, -0.22, { 0.055, 0.075, 0.07, 0.06, 0.055, 0.065, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, colors.back)
		b:edgeFin(-0.08, -0.24, { 0.065, 0.075, 0.055 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.06, 0.045 }, fin, true)
		b:roundTail(0.135, fin)
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		b:speckle(72, v2(-0.31, 0.34), v2(-0.105, 0.115), v2(0.007, 0.014), rgb(176, 66, 52))
		for _, x in { -0.43, -0.47 } do
			for y = -0.075, 0.075, 0.0375 do
				b:finSpot(x, y, 0.013, rgb(120, 48, 40))
			end
		end
		b:face(0.37, 0.04, 0.043, rgb(190, 124, 62), colors.back)
	end,
}

end)()
species["RedMullet"] = (function()
return {
	Name = "Red Mullet",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.1,
	AverageKg = 0.4,
	MaxKg = 2,
	BaseValue = 50,
	Fight = 0.03,
	Pools = { "OpenSea" },
	Seasons = { "Summer", "Autumn" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	},
	-- Rosy goatfish with a steep head, a yellow stripe and two long chin barbels.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(176, 70, 66), side = rgb(222, 120, 110), belly = rgb(246, 214, 200) }
		local fin = rgb(220, 150, 130)
		b:fishBody(0.22, 0.12, colors, 0.12)
		b:edgeFin(0.13, 0.01, { 0.07, 0.065, 0.045 }, fin, false, 0.1)
		b:edgeFin(-0.08, -0.18, { 0.05, 0.04 }, fin, false, 0.1)
		b:edgeFin(-0.08, -0.18, { 0.045, 0.035 }, fin, true, 0.1)
		b:forkTail(0.12, 0.07, fin, 0.05)
		b:pectoral(0.21, -0.04, 0.09, 0.03, fin, 0.1)
		b:stroke({ v2(0.3, 0.0), v2(0, -0.004), v2(-0.3, -0.004) }, 0.02, rgb(236, 196, 80))
		local chin = b:bottom(0.42)
		for _, side in { 1, -1 } do
			b:limb(
				Vector3.new(0.43, chin + 0.006, side * 0.012),
				Vector3.new(0.27, chin - 0.05, side * 0.022),
				0.008,
				rgb(246, 220, 190),
				"Barbel"
			)
		end
		b:face(0.36, 0.04, 0.05, rgb(220, 150, 90), rgb(176, 90, 80))
	end,
}

end)()
species["RedSnapper"] = (function()
return {
	Name = "Red Snapper",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.5,
	AverageKg = 2.5,
	MaxKg = 20,
	BaseValue = 19,
	Fight = 0.04,
	Pools = { "OpenSea" },
	Seasons = { "Summer", "Autumn", "Winter" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	},
	-- Deep red reef snapper with a sloped head, spiny dorsal and red eye.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(176, 46, 46), side = rgb(222, 88, 80), belly = rgb(244, 184, 176) }
		local fin = rgb(206, 70, 66)
		b:fishBody(0.34, 0.13, colors, 0.1)
		local dorsal = b:edgeFin(0.16, -0.22, { 0.06, 0.08, 0.08, 0.075, 0.07, 0.065, 0.07, 0.08, 0.07 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[5], dorsal[7] }, rgb(140, 36, 36))
		b:edgeFin(-0.08, -0.22, { 0.07, 0.08, 0.06 }, fin, true)
		b:edgeFin(0.06, -0.02, { 0.06, 0.05 }, fin, true)
		b:forkTail(0.15, 0.06, fin)
		b:pectoral(0.2, -0.03, 0.14, 0.035, fin)
		for y = -0.06, 0.08, 0.035 do
			b:stroke({ v2(0.28, y + 0.01), v2(-0.3, y) }, 0.005, rgb(234, 120, 110))
		end
		b:face(0.37, 0.05, 0.048, rgb(206, 40, 40), rgb(150, 40, 40))
	end,
}

end)()
species["RedeyeBass"] = (function()
return {
	Name = "Redeye Bass",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.1,
	AverageKg = 0.45,
	MaxKg = 2,
	BaseValue = 27,
	Fight = 0.08,
	Pools = { "MainLake" },
	Seasons = { "Spring", "Summer" },
	Requires = { "Clear" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	},
	-- Species-specific body proportions, fins and flank markings share the smooth mesh pipeline.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(72, 86, 54), side = rgb(146, 152, 106), belly = rgb(220, 218, 186) }
		local fin = rgb(144, 104, 64)
		b:fishBody(0.24, 0.12, colors, 0.07)
		local dorsal = b:edgeFin(0.15, -0.23, { 0.06, 0.075, 0.07, 0.055, 0.04, 0.055, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, rgb(64, 76, 42))
		b:edgeFin(-0.08, -0.23, { 0.06, 0.07, 0.045 }, fin, true)
		b:edgeFin(0.08, 0, { 0.055, 0.04 }, fin, true)
		b:forkTail(0.13, 0.028, fin)
		b:pectoral(0.21, -0.04, 0.105, 0.04, fin, 0.1)
		-- Narrow vertical mottling and pale edging on its reddish tail.
		for x = 0.18, -0.25, -0.085 do
			b:stroke({ v2(x, b:top(x) * 0.8), v2(x - 0.02, b:bottom(x) * 0.5) }, 0.022, rgb(82, 98, 58))
		end
		b:fin({ v2(-0.495, 0.125), v2(-0.472, 0.113), v2(-0.472, 0.075) }, rgb(224, 210, 160))
		b:fin({ v2(-0.495, -0.125), v2(-0.472, -0.113), v2(-0.472, -0.075) }, rgb(224, 210, 160))
		b:face(0.37, 0.033, 0.046, rgb(232, 54, 34), rgb(64, 76, 42))
	end,
}

end)()
species["Riftmaw"] = (function()
return {
	Name = "Riftmaw",
	Rarity = "Exotic",
	RarityDenominator = 650,
	MinKg = 18,
	AverageKg = 70,
	MaxKg = 500,
	LengthScale = 1.2,
	BaseValue = 4600,
	Fight = 0.14,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Summer", "Autumn", "Winter" },
	Requires = { "BlackHole" },
	Shapes = {
		Normal = { ".###.", "#####", ".###." },
		Big = { ".####.", "######", ".####." },
		Huge = { ".#####.", "#######", "#######", ".#####." },
	},
	-- A heavy obsidian predator, split by violet fault lines and crystal teeth.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(9, 6, 15), side = rgb(27, 16, 40), belly = rgb(42, 22, 59) }
		local armor, membrane = rgb(15, 10, 24), rgb(47, 22, 72)
		local violet, pale = rgb(170, 48, 255), rgb(219, 132, 255)
		local function glow(part)
			if part then
				part.Material = Enum.Material.Neon
				part:SetAttribute("BlackHoleAccent", true)
			end
			return part
		end
		local function crystal(a, c, tip)
			local first, second = b:triangle(a, c, tip, violet)
			glow(first)
			glow(second)
		end
		b:beginSkin(colors)
		b:layered("Shoulders", Vector3.new(0.08, 0.01, 0), Vector3.new(0.66, 0.37, 0.29), colors)
		b:layered("ArmoredHead", Vector3.new(0.29, -0.008, 0), Vector3.new(0.38, 0.31, 0.29), colors)
		b:layered("RearBody", Vector3.new(-0.2, 0.0, 0), Vector3.new(0.35, 0.25, 0.19), colors)
		b:layered("TailStalk", Vector3.new(-0.36, -0.01, 0), Vector3.new(0.18, 0.11, 0.08), colors)
		b:finishSkin()
		b:layered("MassiveJaw", Vector3.new(0.32, -0.14, 0), Vector3.new(0.4, 0.12, 0.3), colors)
		b:ellipsoid("Mouth", CFrame.new(0.425, -0.075, 0), Vector3.new(0.16, 0.15, 0.25), rgb(4, 2, 8))
		-- A chunky split tail carries violet crystal blades along both lobes.
		for _, sign in { 1, -1 } do
			b:fin({ v2(-0.39, 0), v2(-0.58, sign * 0.20), v2(-0.59, sign * 0.10), v2(-0.48, 0) }, membrane)
			crystal(Vector3.new(-0.57, sign * 0.19, 0), Vector3.new(-0.55, sign * 0.10, 0), Vector3.new(-0.64, sign * 0.23, 0))
		end
		-- Six separate jagged dorsal plates read as a broken crown, not a sail.
		for index = 0, 5 do
			local x = 0.28 - index * 0.105
			local y = b:top(x)
			local height = if index < 3 then 0.15 - index * 0.013 else 0.13 - (index - 3) * 0.025
			b:fin({ v2(x + 0.035, y - 0.012), v2(x - 0.04, y + height), v2(x - 0.075, y - 0.015) }, armor)
			glow(b:limb(Vector3.new(x - 0.022, y + 0.045, 0), Vector3.new(x - 0.04, y + height, 0), 0.009, violet, "CrystalSpine"))
		end
		b:edgeFin(-0.08, -0.32, { 0.08, 0.07, 0.035 }, membrane, true)
		b:pectoral(0.18, -0.07, 0.23, 0.14, armor)
		-- Side plates stand just proud of the smooth skin.
		for _, side in { -1, 1 } do
			for index = 0, 2 do
				local x = 0.15 - index * 0.13
				local origin = b:surface(x, 0.045, side)
				if origin then
					b:triangle(origin + Vector3.new(0.04, 0.055, side * 0.007), origin + Vector3.new(-0.07, 0.005, side * 0.01), origin + Vector3.new(0.015, -0.045, side * 0.014), armor)
				end
			end
			-- Upper and lower teeth meet across the open front of the maw.
			for index = 0, 3 do
				local z = side * (0.025 + index * 0.032)
				local x = 0.493 - index * 0.016
				crystal(Vector3.new(x - 0.024, 0.0, z), Vector3.new(x + 0.008, -0.005, z), Vector3.new(x + 0.005, -0.08, z))
				crystal(Vector3.new(x - 0.022, -0.14, z), Vector3.new(x + 0.01, -0.14, z), Vector3.new(x + 0.007, -0.095, z))
			end
		end
		-- Branching, surface-following fault lines stay crisp on either flank.
		local cracks = {
			{ v2(0.25, 0.085), v2(0.14, 0.02) },
			{ v2(0.14, 0.02), v2(0.07, 0.055) },
			{ v2(0.07, 0.055), v2(-0.045, -0.012) },
			{ v2(-0.045, -0.012), v2(-0.17, 0.025) },
			{ v2(-0.17, 0.025), v2(-0.29, -0.005) },
			{ v2(0.14, 0.02), v2(0.16, -0.075) },
			{ v2(-0.045, -0.012), v2(-0.09, -0.075) },
			{ v2(0.07, 0.055), v2(0.035, 0.13) },
		}
		for _, crack in cracks do
			local delta, middle = crack[2] - crack[1], (crack[1] + crack[2]) / 2
			for _, side in { -1, 1 } do
				glow(b:mark(middle.X, middle.Y, side, delta.Magnitude * 1.1, 0.009, violet, delta, 0.012))
			end
		end
		b:eye(0.34, 0.072, 0.047, pale)
		for _, part in b.model:GetDescendants() do
			if part:IsA("BasePart") and part.Name == "Eye" then glow(part) end
		end
	end,
}

end)()
species["Sailfish"] = (function()
return {
	Name = "Sailfish",
	Rarity = "Epic",
	RarityDenominator = 30,
	MinKg = 12,
	AverageKg = 40,
	MaxKg = 150,
	LengthScale = 1.5,
	BaseValue = 372,
	Fight = 0.07,
	Pools = { "OpenSea" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { ".##.", "####" },
		Big = { ".###.", "#####" },
		Huge = { ".####.", "######" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(28, 50, 96), side = rgb(110, 140, 176), belly = rgb(226, 230, 234) }
		local fin, sail = rgb(34, 56, 104), rgb(40, 72, 150)
		b:fishBody(0.16, 0.1, colors, 0.02)
		local base = b:edgeFin(0.24, -0.16, { 0.2, 0.3, 0.33, 0.32, 0.28, 0.24, 0.18, 0.1 }, sail, false, 0.12)
		for index = 3, #base - 1 do
			local tip = base[index]
			local root = v2(tip.X, b:top(tip.X))
			b:rays(root, { tip }, rgb(24, 40, 90))
			b:finSpot(tip.X + 0.02, root.Y + (tip.Y - root.Y) * b.random(0.3, 0.7), 0.024, rgb(18, 26, 56))
		end
		b:edgeFin(-0.18, -0.25, { 0.04, 0.03 }, fin)
		b:edgeFin(-0.06, -0.2, { 0.08, 0.05, 0.03 }, fin, true)
		for _, side in { 1, -1 } do
			local belly = b:bottom(0.18)
			b:limb(
				Vector3.new(0.18, belly + 0.005, side * 0.01),
				Vector3.new(-0.06, belly - 0.12, side * 0.02),
				0.007,
				fin,
				"Filament"
			)
		end
		b:lunateTail(0.2, fin)
		b:pectoral(0.22, -0.03, 0.12, 0.04, fin)
		for x = 0.16, -0.26, -0.05 do
			b:stroke({ v2(x, b:top(x) * 0.8), v2(x - 0.01, 0) }, 0.008, rgb(150, 190, 226))
		end
		b:limb(Vector3.new(0.44, 0.005, 0), Vector3.new(0.82, 0, 0), 0.022, colors.back, "Bill")
		b:face(0.36, 0.02, 0.045, rgb(170, 180, 190), rgb(60, 80, 120))
	end,
}

end)()
species["Sardine"] = (function()
return {
	Name = "Sardine",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.04,
	AverageKg = 0.12,
	MaxKg = 0.5,
	BaseValue = 18,
	Fight = 0.04,
	Pools = { "OpenSea" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "###" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(40, 96, 112), side = rgb(176, 192, 196), belly = rgb(240, 242, 242) }
		local fin = rgb(150, 164, 166)
		b:fishBody(0.18, 0.1, colors, 0.04)
		b:edgeFin(0.06, -0.05, { 0.06, 0.05, 0.03 }, fin, false, 0.15)
		b:edgeFin(-0.14, -0.22, { 0.03, 0.02 }, fin, true, 0.15)
		b:edgeFin(0, -0.05, { 0.03 }, fin, true, 0.15)
		b:forkTail(0.12, 0.08, fin, 0.1)
		b:pectoral(0.21, -0.04, 0.07, 0.025, fin, 0.15)
		b:stroke({ v2(0.26, 0.02), v2(-0.3, 0.01) }, 0.008, rgb(120, 150, 160))
		for x = 0.18, -0.2, -0.065 do
			b:marks(x, 0.035, 0.016, 0.016, rgb(26, 40, 48))
		end
		b:face(0.37, 0.015, 0.05, rgb(210, 214, 210), rgb(110, 130, 136))
	end,
}

end)()
species["SeaLettuce"] = (function()
return {
	Name = "Sea Lettuce",
	Rarity = "Uncommon",
	RarityDenominator = 6,
	MinKg = 0.05,
	AverageKg = 0.2,
	MaxKg = 0.9,
	BaseValue = 12,
	Fight = 0,
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	-- Sea lettuce (Ulva): a low, bushy tuft of thin, bright green sheets with
	-- crinkled margins and rounded tips. No midribs.
	Build = function(b, kit)
		local rgb, algaBlade = kit.rgb, kit.algaBlade
		local greens = { rgb(108, 181, 67), rgb(124, 196, 76), rgb(96, 168, 60), rgb(136, 204, 88) }
		local root = Vector3.new(-0.3, -0.12, 0)
		b:ellipsoid("Holdfast", CFrame.new(root), Vector3.new(0.05, 0.035, 0.05), rgb(78, 110, 52))
		local sheets = 7
		for index = 1, sheets do
			local spread = (index - (sheets + 1) / 2) / sheets
			local heading = Vector3.new(0.8 - math.abs(spread) * 0.3, 0.14 + spread * 0.8, math.sin(index * 2.1) * 0.7)
			local length = 0.4 + math.sin(index * 1.7) * 0.07
			local width = 0.075 + math.cos(index * 1.3) * 0.018
			algaBlade(b, root, heading, length, function(t)
				return 0.01 + width * math.sqrt(math.max(0, math.sin(math.min(t * 1.15, 1) * math.pi * 0.5 + (if t > 0.6 then (t - 0.6) * 3.9 else 0))))
			end, greens[(index - 1) % #greens + 1], 0.2, index * 1.3)
		end
		b.model:SetAttribute("ViewDirection", Vector3.new(0.25, 0.4, 1))
	end,
}

end)()
species["Seabass"] = (function()
return {
	Name = "Seabass",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.5,
	AverageKg = 2,
	MaxKg = 12,
	BaseValue = 19,
	Fight = 0.04,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Winter" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	},
	-- European sea bass: a sleek silver-grey predator with two separate dorsals
	-- (spiny then soft), a dark spot on the gill cover and a moderately forked tail.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(82, 94, 104), side = rgb(184, 190, 194), belly = rgb(238, 240, 238) }
		local fin = rgb(140, 148, 154)
		b:fishBody(0.24, 0.13, colors, 0.05)
		local spines = b:edgeFin(0.14, 0.02, { 0.06, 0.075, 0.07, 0.05 }, fin, false, 0.08)
		b:rays(spines[1], { spines[3], spines[4], spines[5] }, rgb(80, 88, 96))
		b:edgeFin(-0.02, -0.17, { 0.06, 0.055, 0.045, 0.03 }, fin, false, 0.08)
		b:edgeFin(-0.08, -0.2, { 0.05, 0.05, 0.035 }, fin, true, 0.08)
		b:edgeFin(0.07, -0.01, { 0.05, 0.035 }, fin, true, 0.1)
		b:forkTail(0.13, 0.045, fin)
		b:pectoral(0.21, -0.03, 0.09, 0.03, fin, 0.15)
		b:stroke({ v2(0.25, 0.045), v2(0, 0.04), v2(-0.3, 0.01) }, 0.006, rgb(70, 80, 88))
		b:marks(0.255, 0.035, 0.032, 0.026, rgb(40, 44, 50))
		b:face(0.37, 0.03, 0.05, rgb(190, 196, 196), rgb(100, 110, 118))
	end,
}

end)()
species["Seaweed"] = (function()
return {
	Name = "Seaweed",
	Rarity = "Junk",
	RarityDenominator = 50,
	MinKg = 0.1,
	AverageKg = 0.3,
	MaxKg = 0.8,
	BaseValue = 1,
	Fight = 0,
	Shapes = {
		Normal = { "#" },
	},
	Build = function(b, kit)
		local rgb = kit.rgb
		local stem, holdfast = rgb(62, 83, 31), rgb(74, 65, 30)
		local colors = { rgb(58, 103, 39), rgb(77, 124, 43), rgb(47, 91, 36), rgb(93, 132, 48), rgb(64, 114, 42) }
		local root = Vector3.new(-0.46, -0.08, 0)
		b:ellipsoid("Holdfast", CFrame.new(root), Vector3.new(0.13, 0.1, 0.13), holdfast)
		-- Five tapered ribbons curl away from a shared stem, with raised midribs.
		for frond = 1, 5 do
			local spread = (frond - 3) * 0.12
			local length = 0.82 + (if frond % 2 == 0 then 0.1 else 0)
			local previousLeft, previousRight, previousCenter
			for segment = 0, 6 do
				local t = segment / 6
				local center = root
					+ Vector3.new(
						length * t,
						spread * t + math.sin(t * math.pi * 2 + frond) * 0.045 * t,
						(frond - 3) * 0.025 * t + math.sin(t * math.pi * 2.5 + frond) * 0.065 * t
					)
				local width = 0.009 + math.sin(t * math.pi) * 0.055
				local across = Vector3.new(0, width, math.sin(t * math.pi + frond) * width * 0.45)
				local left, right = center - across, center + across
				if previousCenter then
					for _, points in { { previousLeft, previousRight, right }, { previousLeft, right, left } } do
						local first, second = b:triangle(points[1], points[2], points[3], colors[frond])
						for _, part in { first, second } do
							part.Name = "SeaweedFrond"
						end
					end
					b:limb(previousCenter, center, 0.009, stem, "Midrib")
				end
				previousLeft, previousRight, previousCenter = left, right, center
			end
		end
		b.model:SetAttribute("ViewDirection", Vector3.new(0.25, 0.4, 1))
	end,
}

end)()
species["Shad"] = (function()
return {
	Name = "Shad",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.3,
	AverageKg = 1,
	MaxKg = 3.5,
	BaseValue = 10,
	Fight = 0.04,
	Pools = { "MainLake" },
	Seasons = { "Spring" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####" },
	},
	-- American shad: a deep, silvery herring with a blue-green back and a dark
	-- shoulder spot followed by a row of smaller spots.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(44, 92, 108), side = rgb(192, 200, 204), belly = rgb(244, 244, 240) }
		local fin = rgb(160, 170, 174)
		b:fishBody(0.26, 0.1, colors, 0.06)
		b:edgeFin(0.06, -0.06, { 0.07, 0.06, 0.035 }, fin, false, 0.15)
		b:edgeFin(-0.12, -0.24, { 0.03, 0.025, 0.02 }, fin, true, 0.15)
		b:edgeFin(0.0, -0.05, { 0.03 }, fin, true, 0.15)
		b:forkTail(0.14, 0.1, fin, 0.1)
		b:pectoral(0.21, -0.05, 0.08, 0.025, fin, 0.15)
		b:stroke({ v2(0.26, 0.05), v2(-0.3, 0.02) }, 0.01, rgb(130, 170, 186))
		b:marks(0.22, 0.04, 0.036, 0.032, rgb(30, 40, 46))
		for x = 0.16, -0.06, -0.045 do
			b:marks(x, 0.04, 0.018, 0.018, rgb(44, 56, 62))
		end
		-- Sharp belly scutes along the keel.
		for x = 0.22, -0.22, -0.04 do
			b:stroke({ v2(x, b:bottom(x) * 0.6), v2(x - 0.01, b:bottom(x) * 0.88) }, 0.004, rgb(220, 226, 230))
		end
		b:face(0.37, 0.02, 0.05, rgb(216, 220, 214), rgb(120, 140, 150))
	end,
}

end)()
species["SharkFin"] = (function()
return {
	Name = "Shark Fin",
	Rarity = "Uncommon",
	RarityDenominator = 5,
	MinKg = 1,
	AverageKg = 1,
	MaxKg = 1,
	BaseValue = 90,
	Fight = 0,
	DropOnly = true,
	Shapes = {
		Normal = { "#" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		b:fin({ v2(-0.36, -0.16), v2(0.30, -0.16), v2(0.05, 0.38), v2(-0.08, 0.16) }, rgb(103, 121, 128))
	end,
}

end)()
species["SharkHead"] = (function()
return {
	Name = "Shark Head",
	Rarity = "Epic",
	RarityDenominator = 20,
	MinKg = 1,
	AverageKg = 1,
	MaxKg = 1,
	BaseValue = 400,
	Fight = 0,
	DropOnly = true,
	Shapes = {
		Normal = { "#" },
	},
	Build = function(b, kit)
		local rgb = kit.rgb
		b:ellipsoid("Head", CFrame.new(), Vector3.new(0.65, 0.28, 0.25), rgb(136, 151, 156))
		b:ellipsoid("Belly", CFrame.new(0, -0.07, 0), Vector3.new(0.59, 0.13, 0.23), rgb(214, 216, 210))
		for _, side in { -1, 1 } do
			b:ellipsoid("Eye", CFrame.new(0.18, 0.04, side * 0.116), Vector3.new(0.035, 0.035, 0.015), rgb(20, 24, 26))
		end
	end,
}

end)()
species["SharkMeat"] = (function()
return {
	Name = "Shark Meat",
	Rarity = "Common",
	RarityDenominator = 1 / 0.60,
	MinKg = 1,
	AverageKg = 1,
	MaxKg = 1,
	BaseValue = 35,
	Fight = 0,
	DropOnly = true,
	Shapes = {
		Normal = { "#" },
	},
	-- Shark rewards are individual parts, built locally like the other catch models.
	Build = function(b, kit)
		local rgb = kit.rgb
		b:ellipsoid("Meat", CFrame.new(), Vector3.new(0.55, 0.27, 0.18), rgb(198, 112, 112))
		b:ellipsoid("Cut", CFrame.new(0.01, 0.01, 0.088), Vector3.new(0.43, 0.19, 0.012), rgb(236, 164, 154))
	end,
}

end)()
species["SharkTail"] = (function()
return {
	Name = "Shark Tail",
	Rarity = "Rare",
	RarityDenominator = 1 / 0.12,
	MinKg = 1,
	AverageKg = 1,
	MaxKg = 1,
	BaseValue = 180,
	Fight = 0,
	DropOnly = true,
	Shapes = {
		Normal = { "#" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		b:ellipsoid("TailBase", CFrame.new(0.19, 0, 0), Vector3.new(0.35, 0.13, 0.13), rgb(130, 145, 151))
		b:fin({ v2(0.12, 0), v2(-0.40, 0.40), v2(-0.23, 0.06), v2(-0.38, -0.27) }, rgb(103, 121, 128))
	end,
}

end)()
species["ShoreCrab"] = (function()
return {
	Name = "Shore Crab",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.05,
	AverageKg = 0.2,
	MaxKg = 0.9,
	BaseValue = 12,
	Fight = 0,
	Shapes = {
		Normal = { "##" },
		Big = { "##", "##" },
		Huge = { "###", "###" },
	},
	Build = function(b, kit)
		local rgb, crab = kit.rgb, kit.crab
		crab(b, {
			shell = rgb(92, 112, 58),
			dark = rgb(70, 86, 44),
			belly = rgb(214, 170, 86),
			clawColor = rgb(104, 118, 62),
			legColor = rgb(112, 124, 66),
			carapace = Vector3.new(0.42, 0.14, 0.52),
			teeth = 5,
			claw = 1,
			legs = {
				lean = { 0.55, 0.15, -0.25, -0.7 },
				thigh = 0.17,
				shin = 0.16,
				lift = 0.06,
				drop = 0.17,
				width = 0.034,
			},
			spots = { count = 30, size = Vector2.new(0.012, 0.03), color = rgb(150, 138, 72) },
		})
	end,
}

end)()
species["ShovelnoseSturgeon"] = (function()
return {
	Name = "Shovelnose Sturgeon",
	Rarity = "Epic",
	RarityDenominator = 50,
	MinKg = 0.8,
	AverageKg = 2.5,
	MaxKg = 8,
	LengthScale = 1.6,
	BaseValue = 165,
	Fight = 0.05,
	Pools = { "MainLake" },
	Seasons = { "Spring", "Summer" },
	Shapes = {
		Normal = { "####" },
		Big = { "#####" },
		Huge = { "#####", ".###." },
	},
	Build = function(b, kit)
		local rgb, sturgeon = kit.rgb, kit.sturgeon
		sturgeon(b, {
			colors = { back = rgb(128, 106, 72), side = rgb(178, 158, 120), belly = rgb(236, 230, 212) },
			fin = rgb(140, 118, 84),
			scute = rgb(212, 200, 170),
			-- The flat, wide shovel snout gives the species its name.
			snout = Vector3.new(0.34, 0.032, 0.17),
			snoutAt = Vector3.new(0.5, -0.03, 0),
			barbelX = 0.5,
			filament = true,
			iris = rgb(160, 140, 96),
		})
	end,
}

end)()
species["Shrimp"] = (function()
return {
	Name = "Shrimp",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.01,
	AverageKg = 0.03,
	MaxKg = 0.12,
	BaseValue = 46,
	Fight = 0.02,
	Pools = { "OpenSea" },
	Seasons = { "Summer", "Autumn", "Winter" },
	Shapes = {
		Normal = { "#" },
		Big = { "#" },
		Huge = { "##" },
	},
	-- A continuous shell curls down into six overlapping abdominal plates.
	-- The five-lobed fan, stalked eyes and swept feelers carry the silhouette.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local shell, back = rgb(235, 157, 119), rgb(213, 125, 93)
		local belly, joint = rgb(250, 207, 170), rgb(173, 91, 65)
		local legColor, feeler = rgb(232, 166, 128), rgb(198, 121, 87)
		b:body("Carapace", Vector3.new(0.18, 0.055, 0), Vector3.new(0.33, 0.205, 0.17), shell)
		b:body("CarapaceBack", Vector3.new(0.175, 0.083, 0), Vector3.new(0.315, 0.16, 0.166), back)
		b:body("CarapaceBelly", Vector3.new(0.18, -0.005, 0), Vector3.new(0.27, 0.075, 0.143), belly)
		b:body("Head", Vector3.new(0.305, 0.062, 0), Vector3.new(0.12, 0.12, 0.125), shell)

		-- Frames follow the bend, so the plates overlap rather than forming beads.
		local plates = {
			{ 0.005, 0.058, 0.08, 0.175, 0.18, 0.154 },
			{ -0.095, 0.038, 0.30, 0.17, 0.168, 0.143 },
			{ -0.18, -0.007, 0.62, 0.16, 0.147, 0.127 },
			{ -0.24, -0.075, 1.00, 0.145, 0.123, 0.109 },
			{ -0.262, -0.15, 1.52, 0.13, 0.099, 0.088 },
			{ -0.235, -0.214, 2.02, 0.12, 0.076, 0.068 },
		}
		for index, plate in plates do
			local frame = CFrame.new(plate[1], plate[2], 0) * CFrame.Angles(0, 0, plate[3])
			local length, height, width = plate[4], plate[5], plate[6]
			b:ellipsoid("Segment", frame, Vector3.new(length, height, width), shell)
			b:ellipsoid("SegmentBack", frame * CFrame.new(0, height * 0.12, 0), Vector3.new(length * 0.94, height * 0.8, width * 0.99), back)
			b:ellipsoid("SegmentBelly", frame * CFrame.new(0, -height * 0.28, 0), Vector3.new(length * 0.84, height * 0.48, width * 0.85), belly)
			-- A curved seam wraps over each plate, with a small skirt at the sides.
			local previous
			for step = 0, 4 do
				local angle = math.rad(-105 + step * 52.5)
				local point = frame:PointToWorldSpace(Vector3.new(-length * 0.23, math.cos(angle) * height * 0.47, math.sin(angle) * width * 0.47))
				if previous then
					b:limb(previous, point, 0.0045, joint, "ShellSeam")
				end
				previous = point
			end
			if index <= 5 then
				for _, side in { 1, -1 } do
					local hip = frame:PointToWorldSpace(Vector3.new(0.015, -height * 0.35, side * width * 0.25))
					local knee = frame:PointToWorldSpace(Vector3.new(-0.012, -height * 0.7, side * width * 0.45))
					local tip = frame:PointToWorldSpace(Vector3.new(-0.045, -height * 0.78, side * width * 0.57))
					b:limb(hip, knee, 0.007, legColor, "Swimmeret")
					b:limb(knee, tip, 0.005, belly, "Swimmeret")
				end
			end
		end

		-- Two pairs of broad uropods spread around the central pointed telson.
		local root = Vector3.new(-0.208, -0.256, 0)
		local tailDirection, tailUp = Vector3.new(0.65, -0.76, 0).Unit, Vector3.new(0.76, 0.65, 0).Unit
		for _, angle in { -58, -29, 29, 58 } do
			local radians = math.rad(angle)
			local direction = tailDirection * math.cos(radians) + Vector3.zAxis * math.sin(radians)
			local frame = CFrame.fromMatrix(root + direction * 0.055, direction, tailUp)
			b:ellipsoid("UropodEdge", frame, Vector3.new(0.142, 0.016, 0.061), back)
			b:ellipsoid("Uropod", frame + tailUp * 0.003, Vector3.new(0.133, 0.015, 0.052), shell)
			b:limb(root, root + direction * 0.117, 0.004, joint, "FinRay")
		end
		b:fin({ root + Vector3.zAxis * 0.025, root + tailDirection * 0.15, root - Vector3.zAxis * 0.025 }, shell)
		b:limb(root, root + tailDirection * 0.14, 0.005, back, "Telson")

		-- Thin, upturned rostrum with a serrated upper edge.
		b:fin({ v2(0.275, 0.11), v2(0.49, 0.173), v2(0.34, 0.082) }, shell)
		b:limb(Vector3.new(0.29, 0.119, 0), Vector3.new(0.49, 0.173, 0), 0.009, back, "Spine")
		for tooth = 0, 4 do
			local x = 0.335 + tooth * 0.025
			local y = 0.131 + tooth * 0.0068
			b:fin({ v2(x - 0.008, y), v2(x - 0.003, y + 0.018 - tooth * 0.002), v2(x + 0.009, y + 0.004) }, back)
		end
		for _, side in { 1, -1 } do
			local stalk = Vector3.new(0.357, 0.13, side * 0.069)
			b:limb(Vector3.new(0.31, 0.085, side * 0.04), stalk, 0.015, shell, "EyeStalk")
			b:ellipsoid("Eye", CFrame.new(stalk), Vector3.one * 0.034, rgb(23, 18, 16))
			b:ellipsoid("EyeGlint", CFrame.new(stalk + Vector3.new(0.008, 0.009, side * 0.01)), Vector3.one * 0.008, rgb(255, 244, 224))

			-- A broad scale at the feeler base and a smooth, swept-back antenna.
			b:ellipsoid("AntennaScale", CFrame.new(0.373, 0.055, side * 0.054) * CFrame.Angles(0, side * -0.2, 0.12), Vector3.new(0.105, 0.018, 0.036), belly)
			local p0 = Vector3.new(0.345, 0.06, side * 0.045)
			local p1 = Vector3.new(0.78, 0.29, side * 0.13)
			local p2 = Vector3.new(0.08, 0.36, side * 0.23)
			local p3 = Vector3.new(-0.35, 0.235, side * 0.25)
			local previous = p0
			for step = 1, 8 do
				local t = step / 8
				local u = 1 - t
				local point = p0 * u ^ 3 + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * t ^ 3
				b:limb(previous, point, 0.0065 - t * 0.0035, feeler, "Filament")
				previous = point
			end
			local bend = Vector3.new(0.443, 0.065, side * 0.075)
			b:limb(p0, bend, 0.007, legColor, "Filament")
			for _, spread in { 0.015, 0.045 } do
				b:limb(bend, Vector3.new(0.56, 0.09 + spread, side * (0.075 + spread)), 0.004, feeler, "Filament")
			end
			for leg = 0, 4 do
				local x = 0.265 - leg * 0.043
				local hip = Vector3.new(x, -0.012, side * 0.046)
				local knee = Vector3.new(x + 0.025 - leg * 0.012, -0.09, side * 0.09)
				local tip = Vector3.new(x + 0.06 - leg * 0.024, -0.167 + leg * 0.008, side * 0.105)
				b:limb(hip, knee, 0.009, legColor, "Limb")
				b:limb(knee, tip, 0.006, legColor, "Limb")
			end
		end
		b:speckle(10, v2(0.06, 0.28), v2(0.06, 0.125), v2(0.004, 0.009), joint)
	end,
}

end)()
species["SingularitySerpent"] = (function()
return {
	Name = "Singularity Serpent",
	Rarity = "Divine",
	RarityDenominator = 1500,
	MinKg = 35,
	AverageKg = 150,
	MaxKg = 1200,
	LengthScale = 1.5,
	BaseValue = 9000,
	Fight = 0.18,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Summer", "Autumn", "Winter" },
	Requires = { "BlackHole" },
	Shapes = {
		Normal = { "#####", "....#" },
		Big = { "######", "....##" },
		Huge = { "#######", ".....##", ".....##" },
	},
	-- An S-curved dragon eel with a violet crest, comet tail and light organs.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(8, 5, 15), side = rgb(25, 14, 40), belly = rgb(44, 22, 66) }
		local plate, membrane = rgb(14, 8, 24), rgb(64, 24, 101)
		local violet, pale = rgb(153, 42, 255), rgb(216, 133, 255)
		local function glow(part)
			if part then
				part.Material = Enum.Material.Neon
				part:SetAttribute("BlackHoleAccent", true)
			end
			return part
		end
		local function light(a, c, size, color, name)
			return glow(b:limb(a, c, size, color or violet, name or "VoidFilament"))
		end
		-- The fallback sections and smooth loft share the same curved centerline.
		local spine = {
			{ 0.46, 0.045, 0.19, 0.16 },
			{ 0.30, 0.04, 0.22, 0.18 },
			{ 0.10, 0.025, 0.205, 0.15 },
			{ -0.10, -0.025, 0.175, 0.12 },
			{ -0.30, -0.085, 0.145, 0.095 },
			{ -0.49, -0.085, 0.11, 0.075 },
			{ -0.66, -0.03, 0.08, 0.05 },
			{ -0.79, 0.045, 0.045, 0.03 },
		}
		b:beginSkin(colors)
		for index, node in spine do
			b:layered("Coil" .. index, Vector3.new(node[1], node[2], 0), Vector3.new(if index == 1 then 0.27 else 0.31, node[3], node[4]), colors)
		end
		local stations = { { 0.595, 0.055, 0.035, 0.006 } }
		for _, node in spine do
			table.insert(stations, { node[1], node[2] + node[3] * 0.5, node[2] - node[3] * 0.5, node[4] * 0.5 })
		end
		table.insert(stations, { -0.89, 0.079, 0.065, 0.007 })
		b:finishSkin(stations)
		-- One continuous dorsal ribbon follows the back into the rising tail.
		local previousBase, previousTip
		for index, node in spine do
			local base = Vector3.new(node[1], b:top(node[1]) - 0.008, 0)
			local tip = base + Vector3.new(-0.065, 0.12 + math.sin(index * 0.6) * 0.045, 0)
			if previousBase then
				b:fin({ previousBase, previousTip, tip, base }, membrane, 0.08)
				light(previousTip, tip, 0.009, violet, "DorsalRim")
			end
			previousBase, previousTip = base, tip
		end
		-- Two long rear streamers form a comet-shaped caudal fin.
		local tail = Vector3.new(-0.84, 0.063, 0)
		for _, sign in { -1, 1 } do
			local tip = Vector3.new(-1.12, 0.09 + sign * 0.13, sign * 0.035)
			local notch = Vector3.new(-0.95, 0.075 + sign * 0.028, sign * 0.012)
			b:fin({ tail, tip, notch }, membrane)
			light(tail, tip, 0.009, violet, "CometTail")
		end
		-- Armored body rings and paired bioluminescent nodes mark each curve.
		for index = 2, #spine - 1 do
			local node = spine[index]
			for _, side in { -1, 1 } do
				local surface = b:surface(node[1], node[2] + node[3] * 0.1, side)
				if surface then
					b:ellipsoid("SegmentPlate", CFrame.new(surface + Vector3.new(0, 0, side * 0.003)), Vector3.new(0.09, node[3] * 0.60, 0.015), plate)
					glow(b:ellipsoid("VoidNode", CFrame.new(surface + Vector3.new(0.005, 0, side * 0.013)), Vector3.new(0.027, 0.018, 0.012), violet))
				end
			end
		end
		-- Swept fins keep the silhouette recognizably aquatic.
		for _, side in { -1, 1 } do
			b:fin({ Vector3.new(0.28, 0.015, side * 0.075), Vector3.new(0.05, -0.14, side * 0.19), Vector3.new(0.17, -0.04, side * 0.09) }, membrane)
			light(Vector3.new(0.28, 0.015, side * 0.078), Vector3.new(0.05, -0.14, side * 0.19), 0.008, violet, "PectoralRim")
			-- Backward horns and curling whiskers grow from the broad eel head.
			local horn = Vector3.new(0.39, 0.11, side * 0.05)
			local bend = Vector3.new(0.34, 0.23, side * 0.07)
			b:limb(horn, bend, 0.024, plate, "Horn")
			light(bend, Vector3.new(0.20, 0.29, side * 0.09), 0.012, pale, "HornTip")
			local root = Vector3.new(0.52, 0.02, side * 0.045)
			local curl = Vector3.new(0.60, -0.035, side * 0.12)
			light(root, curl, 0.009, pale, "Whisker")
			light(curl, Vector3.new(0.49, -0.10, side * 0.17), 0.006, violet, "Whisker")
		end
		b:eye(0.46, 0.08, 0.037, pale)
		-- A narrow jaw line and two short crystal fangs avoid an angler silhouette.
		for _, side in { -1, 1 } do
			glow(b:mark(0.53, 0.025, side, 0.08, 0.009, violet, v2(1, 0)))
			light(Vector3.new(0.535, 0.025, side * 0.03), Vector3.new(0.54, -0.018, side * 0.035), 0.011, pale, "CrystalFang")
		end
		for _, part in b.model:GetDescendants() do
			if part:IsA("BasePart") and part.Name == "Eye" then glow(part) end
		end
	end,
}

end)()
species["SmallmouthBass"] = (function()
return {
	Name = "Smallmouth Bass",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.3,
	AverageKg = 1.2,
	MaxKg = 6,
	BaseValue = 25,
	Fight = 0.06,
	Pools = { "MainLake" },
	Seasons = { "Spring", "Autumn" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	},
	-- Bronze black bass with diffuse vertical bars, dark cheek stripes, a joined
	-- spiny-soft dorsal, a big mouth and a red eye.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(86, 72, 38), side = rgb(156, 128, 70), belly = rgb(224, 208, 168) }
		local fin = rgb(130, 106, 62)
		b:fishBody(0.28, 0.14, colors, 0.08)
		local dorsal =
			b:edgeFin(0.14, -0.22, { 0.06, 0.075, 0.07, 0.055, 0.04, 0.05, 0.07, 0.075, 0.06 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, rgb(80, 64, 36))
		b:edgeFin(-0.08, -0.22, { 0.06, 0.065, 0.045 }, fin, true, 0.05)
		b:edgeFin(0.08, 0.0, { 0.06, 0.04 }, fin, true)
		b:forkTail(0.13, 0.035, fin)
		b:pectoral(0.2, -0.04, 0.1, 0.04, fin, 0.1)
		for x = 0.16, -0.3, -0.055 do
			b:stroke({ v2(x + 0.006, b:top(x) * 0.85), v2(x - 0.006, b:bottom(x) * 0.45) }, 0.024, rgb(96, 76, 38))
		end
		for _, y in { 0.02, -0.01, -0.04 } do
			b:stroke({ v2(0.34, y + 0.012), v2(0.25, y) }, 0.01, rgb(70, 56, 30))
		end
		-- Jaw hinge reaches to below the eye.
		b:stroke({ v2(0.47, -0.03), v2(0.37, -0.05) }, 0.008, rgb(40, 32, 22))
		b:face(0.37, 0.035, 0.048, rgb(204, 64, 40), rgb(100, 82, 46))
	end,
}

end)()
species["SockeyeSalmon"] = (function()
return {
	Name = "Sockeye Salmon",
	Rarity = "Rare",
	RarityDenominator = 12,
	MinKg = 1,
	AverageKg = 2.7,
	MaxKg = 7,
	BaseValue = 148,
	Fight = 0.07,
	Pools = { "OpenSea" },
	Seasons = { "Autumn" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "####", "####" },
	},
	-- Spawning sockeye: crimson body, olive-green head, a humped back and the
	-- hooked kype jaw of a breeding male.
	Build = function(b, kit)
		local rgb = kit.rgb
		local colors = { back = rgb(160, 26, 28), side = rgb(204, 42, 38), belly = rgb(214, 96, 84) }
		local head = { back = rgb(50, 74, 44), side = rgb(84, 110, 64), belly = rgb(190, 196, 168) }
		local fin = rgb(110, 96, 60)
		b:fishBody(0.24, 0.12, colors, 0.06)
		b:layered("Hump", Vector3.new(0.05, 0.035, 0), Vector3.new(0.42, 0.24, 0.1), colors)
		b:layered("GreenHead", Vector3.new(0.31, -0.012, 0), Vector3.new(0.34, 0.2, 0.112), head)
		-- Hooked upper snout and upturned lower jaw (kype).
		b:layered("Kype", Vector3.new(0.48, -0.012, 0), Vector3.new(0.12, 0.065, 0.06), head)
		b:limb(Vector3.new(0.52, -0.01, 0), Vector3.new(0.545, -0.075, 0), 0.03, head.back, "Kype")
		b:limb(Vector3.new(0.42, -0.075, 0), Vector3.new(0.5, -0.06, 0), 0.026, head.side, "Jaw")
		b:edgeFin(0.08, -0.06, { 0.07, 0.065, 0.05 }, fin)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.25, b:top(-0.25) + 0.004, 0), Vector3.new(0.045, 0.028, 0.012), fin)
		b:edgeFin(-0.12, -0.23, { 0.055, 0.05, 0.035 }, fin, true)
		b:edgeFin(0.02, -0.06, { 0.05, 0.04 }, fin, true)
		b:forkTail(0.12, 0.03, fin)
		b:pectoral(0.2, -0.05, 0.09, 0.035, fin)
		b:face(0.385, 0.028, 0.04, rgb(206, 176, 90), rgb(40, 60, 36))
	end,
}

end)()
species["Stingray"] = (function()
return {
	Name = "Stingray",
	Rarity = "Legendary",
	RarityDenominator = 150,
	MinKg = 6,
	AverageKg = 25,
	MaxKg = 180,
	LengthScale = 1.25,
	BaseValue = 500,
	Fight = 0.06,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "##.", "###", "##." },
		Big = { "###.", "####", "###." },
		Huge = { "####.", "#####", "####." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local top, darker, under = rgb(104, 88, 70), rgb(88, 74, 58), rgb(234, 232, 224)
		local half = {
			v2(0.46, 0),
			v2(0.42, 0.08),
			v2(0.34, 0.18),
			v2(0.24, 0.27),
			v2(0.14, 0.31),
			v2(0.04, 0.3),
			v2(-0.06, 0.24),
			v2(-0.13, 0.15),
			v2(-0.17, 0.07),
			v2(-0.18, 0),
		}
		local center = Vector3.new(0.12, 0, 0)
		for _, sign in { 1, -1 } do
			for index = 1, #half - 1 do
				local a, c = half[index], half[index + 1]
				b:triangle(center, Vector3.new(a.X, 0, a.Y * sign), Vector3.new(c.X, 0, c.Y * sign), top)
			end
		end
		local domes = {
			{ Vector3.new(0.13, 0, 0), Vector3.new(0.56, 0.03, 0.54), top },
			{ Vector3.new(0.13, 0.008, 0), Vector3.new(0.46, 0.07, 0.3), top },
			{ Vector3.new(0.07, 0.022, 0), Vector3.new(0.32, 0.05, 0.1), darker },
		}
		for _, dome in domes do
			b:ellipsoid("Disc", CFrame.new(dome[1]), dome[2], dome[3])
		end
		b:ellipsoid("Underside", CFrame.new(0.13, -0.008, 0), Vector3.new(0.56, 0.026, 0.54), under)
		local function height(x: number, z: number): number
			local best = 0.002
			for _, dome in domes do
				local h = dome[2] / 2
				local dx, dz = (x - dome[1].X) / h.X, (z - dome[1].Z) / h.Z
				local remaining = 1 - dx * dx - dz * dz
				if remaining > 0 then
					best = math.max(best, dome[1].Y + h.Y * math.sqrt(remaining))
				end
			end
			return best
		end
		for _ = 1, 54 do
			local x, z = b.random(-0.12, 0.4), b.random(-0.27, 0.27)
			local reach = 0.3 * (1 - math.abs(x - 0.12) / 0.4)
			if math.abs(z) < reach then
				local size = b.random(0.012, 0.032)
				b:ellipsoid(
					"Spot",
					CFrame.new(x, height(x, z) + 0.002, z),
					Vector3.new(size, 0.004, size),
					if b.random(0, 1) > 0.35 then rgb(170, 152, 118) else rgb(66, 54, 42)
				)
			end
		end
		for _, sign in { 1, -1 } do
			b:ellipsoid(
				"Eye",
				CFrame.new(0.3, height(0.3, 0.055 * sign) + 0.008, 0.055 * sign),
				Vector3.new(0.035, 0.028, 0.028),
				rgb(36, 32, 28)
			)
			b:ellipsoid(
				"EyeGlint",
				CFrame.new(0.305, height(0.3, 0.055 * sign) + 0.022, 0.05 * sign),
				Vector3.one * 0.008,
				rgb(255, 255, 255)
			)
			b:ellipsoid(
				"Spiracle",
				CFrame.new(0.255, height(0.255, 0.06 * sign) + 0.002, 0.06 * sign),
				Vector3.new(0.03, 0.006, 0.018),
				rgb(48, 40, 32)
			)
			b:ellipsoid("PelvicFin", CFrame.new(-0.19, 0.004, 0.045 * sign), Vector3.new(0.08, 0.016, 0.05), top)
		end
		-- Many short, overlapping sections give a smooth tapering whip.
		local previous = Vector3.new(-0.16, 0.01, 0)
		for index = 1, 14 do
			local t = index / 14
			local point = Vector3.new(-0.16 - t * 0.46, 0.01 + t * 0.01, math.sin(t * math.pi) * 0.03)
			b:limb(previous:Lerp(point, -0.7), point, 0.04 * (1 - t) + 0.006, darker, "Tail")
			previous = point
		end
		b:limb(Vector3.new(-0.3, 0.03, 0.016), Vector3.new(-0.38, 0.036, 0.024), 0.008, rgb(214, 204, 182), "Barb")
		b.model:SetAttribute("ViewDirection", Vector3.new(0.35, 1, 0.55))
	end,
}

end)()
species["StripedMarlin"] = (function()
return {
	Name = "Striped Marlin",
	Rarity = "Epic",
	RarityDenominator = 42,
	MinKg = 12,
	AverageKg = 55,
	MaxKg = 220,
	LengthScale = 1.55,
	BaseValue = 425,
	Fight = 0.10,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Requires = { "Day" },
	Shapes = {
		Normal = { "####", ".##." },
		Big = { "#####", ".###." },
		Huge = { "######", ".####." },
	},
	-- High pointed dorsal and bright lavender-blue bars on a slim body.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(28, 42, 96), side = rgb(120, 146, 188), belly = rgb(228, 232, 240) }
		local fin = rgb(38, 48, 112)
		b:fishBody(0.18, 0.10, colors, 0.02)
		b:edgeFin(0.26, -0.24, { 0.17, 0.24, 0.19, 0.115, 0.055, 0.03, 0.02 }, fin)
		b:edgeFin(-0.25, -0.3, { 0.03 }, fin)
		b:edgeFin(0.0, -0.16, { 0.08, 0.05, 0.025 }, fin, true)
		b:edgeFin(-0.25, -0.3, { 0.025 }, fin, true)
		b:lunateTail(0.22, fin)
		b:pectoral(0.23, -0.025, 0.19, 0.036, fin)
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.17, b:bottom(0.17), side * 0.012), Vector3.new(-0.06, -0.16, side * 0.025), 0.006, fin, "PelvicFin")
		end
		for x = 0.25, -0.29, -0.042 do
			b:stroke({ v2(x, b:top(x) * 0.82), v2(x - 0.013, b:bottom(x) * 0.62) }, 0.012, rgb(104, 122, 238))
		end
		b:limb(Vector3.new(0.44, 0.006, 0), Vector3.new(0.84, 0.002, 0), 0.021, colors.back, "Bill")
		b:face(0.37, 0.023, 0.04, rgb(166, 184, 204), rgb(62, 72, 128))
	end,
}

end)()
species["Sunfish"] = (function()
return {
	Name = "Sunfish",
	Rarity = "Legendary",
	RarityDenominator = 150,
	MinKg = 20,
	AverageKg = 90,
	MaxKg = 600,
	LengthScale = 1.3,
	BaseValue = 520,
	Fight = 0.04,
	Pools = { "MainLake" },
	Seasons = { "Spring", "Summer" },
	Requires = { "Clear" },
	Shapes = {
		Normal = { ".##.", "####", ".##." },
		Big = { ".###.", "#####", ".###." },
		Huge = { ".####.", "######", "######", ".####." },
	},
	-- Ocean sunfish: a tall disc with long dorsal and anal fins and a frilled
	-- clavus where other fish have a tail.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(96, 104, 112), side = rgb(156, 164, 170), belly = rgb(222, 224, 222) }
		local fin = rgb(110, 118, 126)
		b:beginSkin(colors)
		b:layered("Body", Vector3.new(0.05, 0, 0), Vector3.new(0.7, 0.62, 0.16), colors)
		b:layered("Head", Vector3.new(0.3, -0.02, 0), Vector3.new(0.26, 0.4, 0.14), colors)
		local top, bottom = b:top(-0.1), b:bottom(-0.1)
		b:fin({
			v2(-0.06, b:top(-0.06) - 0.01),
			v2(-0.18, top + 0.36),
			v2(-0.25, top + 0.3),
			v2(-0.24, b:top(-0.24) - 0.01),
		}, fin)
		b:fin({
			v2(-0.06, b:bottom(-0.06) + 0.01),
			v2(-0.18, bottom - 0.34),
			v2(-0.25, bottom - 0.28),
			v2(-0.24, b:bottom(-0.24) + 0.01),
		}, fin)
		local clavus = { v2(-0.24, 0) }
		for index = 0, 8 do
			local angle = math.rad(100 + index * 160 / 8)
			local wobble = if index % 2 == 0 then 1 else 0.86
			table.insert(clavus, v2(-0.27 + math.cos(angle) * 0.1 * wobble, math.sin(angle) * 0.28 * wobble))
		end
		b:fin(clavus, fin)
		b:pectoral(0.18, 0.02, 0.07, 0.05, fin)
		b:speckle(34, v2(-0.2, 0.3), v2(-0.25, 0.25), v2(0.02, 0.05), rgb(196, 200, 202))
		b:ellipsoid("Lips", CFrame.new(0.43, -0.02, 0), Vector3.new(0.04, 0.05, 0.05), colors.side)
		b:face(0.34, 0.06, 0.05, rgb(70, 76, 80), fin)
		b.model:SetAttribute("ViewDirection", Vector3.new(0.1, 0.1, 1))
	end,
}

end)()
species["Swordfish"] = (function()
return {
	Name = "Swordfish",
	Rarity = "Epic",
	RarityDenominator = 30,
	MinKg = 20,
	AverageKg = 90,
	MaxKg = 600,
	LengthScale = 1.5,
	BaseValue = 408,
	Fight = 0.06,
	Pools = { "OpenSea" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "####" },
		Big = { "#####", ".###." },
		Huge = { "#######", ".#####." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(54, 46, 66), side = rgb(126, 118, 132), belly = rgb(214, 208, 204) }
		local fin = rgb(60, 52, 70)
		b:fishBody(0.2, 0.16, colors, 0.02)
		-- Heavy shoulders behind the head.
		b:layered("Shoulder", Vector3.new(0.2, 0.012, 0), Vector3.new(0.34, 0.215, 0.175), colors)
		local crest = b:top(0.12)
		b:fin({
			v2(0.25, b:top(0.25) - 0.008),
			v2(0.15, crest + 0.12),
			v2(0.07, crest + 0.165),
			v2(0.1, crest + 0.07),
			v2(0.11, crest + 0.02),
			v2(0.12, crest - 0.008),
		}, fin)
		local keel = b:bottom(0)
		b:fin(
			{ v2(0.04, keel + 0.008), v2(-0.08, keel - 0.12), v2(-0.06, keel - 0.03), v2(-0.04, b:bottom(-0.04) + 0.008) },
			fin
		)
		b:edgeFin(-0.24, -0.29, { 0.03 }, fin)
		b:edgeFin(-0.24, -0.29, { 0.03 }, fin, true)
		b:ellipsoid("Keel", CFrame.new(-0.33, 0, 0), Vector3.new(0.08, 0.03, b:top(-0.33) * 1.4), colors.back)
		b:lunateTail(0.22, fin)
		b:pectoral(0.22, -0.05, 0.14, 0.05, fin)
		-- The flat sword is about a third of the fish's whole length.
		b:ellipsoid("Sword", CFrame.new(0.72, 0.005, 0), Vector3.new(0.58, 0.022, 0.08), rgb(40, 34, 46))
		b:face(0.36, 0.025, 0.065, rgb(60, 70, 90), rgb(80, 70, 90))
	end,
}

end)()
species["TigerGrouper"] = (function()
return {
	Name = "Tiger Grouper",
	Rarity = "Epic",
	RarityDenominator = 32,
	MinKg = 2,
	AverageKg = 9,
	MaxKg = 35,
	BaseValue = 340,
	Fight = 0.08,
	Pools = { "CoralShallows", "CinderIsles" },
	Seasons = { "Summer", "Autumn" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Amber grouper with bold diagonal tiger bars rather than rows of round spots.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(116, 72, 48), side = rgb(210, 148, 82), belly = rgb(240, 210, 158) }
		local fin = rgb(142, 84, 48)
		b:fishBody(0.33, 0.17, colors, 0.075)
		local dorsal = b:edgeFin(0.17, -0.22, { 0.055, 0.075, 0.07, 0.06, 0.055, 0.065, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, colors.back)
		b:edgeFin(-0.08, -0.24, { 0.065, 0.075, 0.055 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.06, 0.045 }, fin, true)
		b:roundTail(0.135, fin)
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		for _, x in { 0.21, 0.09, -0.03, -0.15, -0.26 } do
			b:stroke({ v2(x + 0.045, b:top(x) * 0.83), v2(x - 0.045, b:bottom(x) * 0.62) }, 0.034, rgb(82, 46, 30))
		end
		b:speckle(14, v2(0.28, 0.42), v2(-0.06, 0.08), v2(0.006, 0.012), rgb(168, 78, 42))
		b:face(0.37, 0.04, 0.043, rgb(212, 148, 54), colors.back)
	end,
}

end)()
species["TigerTrout"] = (function()
return {
	Name = "Tiger Trout",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.3,
	AverageKg = 1.5,
	MaxKg = 10,
	BaseValue = 14,
	Fight = 0.05,
	Pools = { "MainLake", "OpenSea" },
	Seasons = { "Autumn", "Winter" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	},
	Build = function(b, kit)
		local rgb, trout = kit.rgb, kit.trout
		trout(b, {
			colors = { back = rgb(110, 92, 50), side = rgb(206, 176, 104), belly = rgb(240, 226, 186) },
			fin = rgb(196, 140, 72),
			vermiculate = true,
			spot = rgb(60, 46, 24),
			iris = rgb(220, 176, 80),
			line = rgb(130, 106, 60),
		})
	end,
}

end)()
species["Tilapia"] = (function()
return {
	Name = "Tilapia",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.2,
	AverageKg = 0.8,
	MaxKg = 4,
	BaseValue = 10,
	Fight = 0.02,
	Pools = { "MainLake" },
	Seasons = { "Summer", "Autumn" },
	Requires = { "Rain" },
	Shapes = {
		Normal = { "##" },
		Big = { "##", "##" },
		Huge = { "###", "###" },
	},
	-- Deep-bodied cichlid with faint bars and a red-edged tail.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(70, 84, 76), side = rgb(140, 152, 140), belly = rgb(222, 222, 210) }
		local fin = rgb(104, 112, 104)
		b:fishBody(0.36, 0.13, colors, 0.08)
		local dorsal = b:edgeFin(0.14, -0.24, { 0.05, 0.06, 0.06, 0.06, 0.06, 0.07, 0.09, 0.1, 0.08 }, fin, false, 0.08)
		b:rays(dorsal[1], { dorsal[3], dorsal[5], dorsal[7], dorsal[9] }, rgb(60, 66, 60))
		b:edgeFin(-0.06, -0.24, { 0.06, 0.08, 0.07 }, fin, true, 0.08)
		b:edgeFin(0.08, -0.02, { 0.06, 0.05 }, fin, true)
		b:roundTail(0.13, fin, 0.05)
		b:stroke({ v2(-0.47, 0.12), v2(-0.5, 0), v2(-0.47, -0.12) }, 0.012, rgb(196, 70, 60))
		b:pectoral(0.2, -0.04, 0.12, 0.04, fin, 0.15)
		for _, x in { 0.14, 0.05, -0.04, -0.13, -0.22 } do
			b:stroke({ v2(x + 0.01, b:top(x) - 0.02), v2(x - 0.01, -0.07) }, 0.026, rgb(104, 116, 106))
		end
		for _ = 1, 12 do
			b:finSpot(b.random(-0.2, 0.1), b:top(-0.05) + b.random(0.01, 0.06), 0.01, rgb(220, 220, 214))
		end
		b:face(0.38, 0.05, 0.048, rgb(196, 132, 70), rgb(84, 96, 88))
	end,
}

end)()
species["Tire"] = (function()
return {
	Name = "Tire",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 2,
	AverageKg = 7,
	MaxKg = 30,
	BaseValue = 12,
	Fight = 0.02,
	Pools = { "MainLake" },
	Shapes = {
		Normal = { "##" },
		Big = { "###", "###" },
		Huge = { "###", "###", "###" },
	},
	Build = function(b, kit)
		local rgb = kit.rgb
		local rubber = rgb(45, 46, 49)
		local sidewall = rgb(53, 54, 57)
		local groove = rgb(27, 28, 30)
		local steel = rgb(126, 130, 133)
		local steelLight = rgb(156, 158, 157)
		local recess = rgb(60, 63, 64)
		local rust = rgb(112, 76, 49)

		-- Cylinders run along local X; turn them to face the wheel's Z axis.
		local function disc(name, z, diameter, width, color)
			local part = b:part(
				name,
				"Part",
				Vector3.new(width, diameter, diameter),
				CFrame.new(0, 0, z) * CFrame.Angles(0, math.pi / 2, 0),
				color
			)
			part.Shape = Enum.PartType.Cylinder
			return part
		end

		-- A continuous tread and narrower sidewalls make a solid, round tire.
		disc("Tread", 0, 0.69, 0.21, rubber)
		disc("Shoulders", 0, 0.65, 0.256, sidewall)
		for _, side in { -1, 1 } do
			-- Layered discs leave narrow concentric rings around the recessed rim.
			disc("SidewallRing", side * 0.129, 0.59, 0.003, groove)
			disc("SidewallInset", side * 0.131, 0.565, 0.003, rubber)
			disc("Bead", side * 0.133, 0.465, 0.004, groove)
			disc("RimLip", side * 0.136, 0.427, 0.008, steelLight)
			disc("RimRecess", side * 0.141, 0.382, 0.004, recess)

			for index = 0, 7 do
				local angle = index * math.pi * 2 / 8
				local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
				local tangent = Vector3.new(-math.sin(angle), math.cos(angle), 0)
				b:part(
					"Spoke",
					"Part",
					Vector3.new(0.047, 0.137, 0.008),
					CFrame.fromMatrix(radial * 0.109 + Vector3.new(0, 0, side * 0.145), tangent, radial, Vector3.zAxis),
					steel
				)
			end
			disc("Hub", side * 0.15, 0.112, 0.014, steelLight)
			disc("HubCap", side * 0.158, 0.051, 0.004, recess)
			for index = 0, 4 do
				local angle = index * math.pi * 2 / 5
				local position = Vector3.new(math.cos(angle) * 0.042, math.sin(angle) * 0.042, side * 0.159)
				local bolt = b:part(
					"LugNut",
					"Part",
					Vector3.new(0.005, 0.012, 0.012),
					CFrame.new(position) * CFrame.Angles(0, math.pi / 2, 0),
					recess
				)
				bolt.Shape = Enum.PartType.Cylinder
			end
		end

		-- Shallow angled cuts break up the tread without adding rounded bumps.
		local segments = 28
		for index = 0, segments - 1 do
			local angle = index * math.pi * 2 / segments
			local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
			local tangent = Vector3.new(-math.sin(angle), math.cos(angle), 0)
			for _, side in { -1, 1 } do
				local frame = CFrame.fromMatrix(
					radial * 0.345 + Vector3.new(0, 0, side * 0.051),
					tangent,
					radial,
					Vector3.zAxis
				)
				b:part(
					"TreadGroove",
					"Part",
					Vector3.new(0.009, 0.003, 0.089),
					frame * CFrame.Angles(0, side * 0.28, 0),
					groove
				)
			end
		end

		-- A valve and restrained corrosion give the found wheel some history.
		b:limb(Vector3.new(0.075, -0.17, 0.148), Vector3.new(0.084, -0.192, 0.158), 0.012, groove, "ValveStem")
		for index = 0, 2 do
			local angle = 0.7 + index * 1.9
			local position = Vector3.new(math.cos(angle) * 0.18, math.sin(angle) * 0.18, 0.142)
			local patch = b:part(
				"Rust",
				"Part",
				Vector3.new(0.002, 0.025, 0.025),
				CFrame.new(position) * CFrame.Angles(0, math.pi / 2, 0),
				rust,
				0.15
			)
			patch.Shape = Enum.PartType.Cylinder
		end
		b.model:SetAttribute("ViewDirection", Vector3.new(0.2, 0.5, 1))
	end,
}

end)()
species["Treefish"] = (function()
return {
	Name = "Treefish",
	Rarity = "Rare",
	RarityDenominator = 18,
	MinKg = 0.2,
	AverageKg = 0.7,
	MaxKg = 2,
	BaseValue = 146,
	Fight = 0.04,
	Pools = { "CoralShallows", "PirateCove" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Yellow-green body with broad black vertical bars and reddish lips.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(98, 98, 38), side = rgb(198, 184, 70), belly = rgb(234, 218, 146) }
		local fin = rgb(166, 150, 54)
		b:fishBody(0.32, 0.16, colors, 0.08)
		b:layered("LowerJaw", Vector3.new(0.405, -0.052, 0), Vector3.new(0.17, 0.075, 0.10400000000000001), colors)
		local spines = b:edgeFin(0.2, -0.08, { 0.045, 0.09, 0.105, 0.10, 0.085, 0.07, 0.04 }, fin)
		for index = 3, #spines - 1 do
			local tip = spines[index]
			b:rays(v2(tip.X, b:top(tip.X)), { tip }, colors.back)
		end
		b:edgeFin(-0.08, -0.27, { 0.075, 0.085, 0.07, 0.04 }, fin, false, 0.05)
		b:edgeFin(-0.08, -0.25, { 0.065, 0.07, 0.045 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.055, 0.04 }, fin, true)
		b:roundTail(0.13, fin)
		b:pectoral(0.24, -0.045, 0.15, 0.065, fin)
		for _, x in { 0.25, 0.12, -0.03, -0.18, -0.29 } do
			b:stroke({ v2(x, b:top(x) * 0.84), v2(x - 0.02, b:bottom(x) * 0.65) }, 0.045, rgb(42, 46, 32))
		end
		-- A raised brow and short cheek spines distinguish the rockfish head.
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.34, 0.07, side * 0.048), Vector3.new(0.30, 0.092, side * 0.055999999999999994), 0.013, colors.back, "Brow")
			b:limb(Vector3.new(0.26, -0.005, side * 0.0768), Vector3.new(0.20, -0.015, side * 0.10400000000000001), 0.012, fin, "CheekSpine")
		end
		b:marks(0.455, -0.028, 0.035, 0.024, rgb(178, 72, 54))
		b:face(0.37, 0.045, 0.05, rgb(230, 178, 72), colors.back)
	end,
}


end)()
species["Tripletail"] = (function()
return {
	Name = "Tripletail",
	Rarity = "Rare",
	RarityDenominator = 14,
	MinKg = 0.5,
	AverageKg = 4,
	MaxKg = 20,
	BaseValue = 150,
	Fight = 0.065,
	Pools = { "MainLake", "CoralShallows" },
	Seasons = { "Summer", "Autumn" },
	Requires = { "Clear", "Day" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Deep, compressed tripletail: tall rear dorsal and anal fins flank a third rounded tail lobe.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(72, 66, 46), side = rgb(128, 116, 78), belly = rgb(192, 176, 128) }
		local fin = rgb(88, 78, 48)
		b:fishBody(0.4, 0.12, colors, 0.075)
		b:edgeFin(0.15, -0.08, { 0.055, 0.065, 0.055, 0.045 }, fin)
		b:edgeFin(-0.06, -0.35, { 0.07, 0.13, 0.15, 0.15, 0.13, 0.08 }, fin)
		b:edgeFin(-0.06, -0.35, { 0.07, 0.13, 0.15, 0.15, 0.13, 0.08 }, fin, true)
		b:edgeFin(0.08, 0, { 0.06, 0.045 }, fin, true)
		b:roundTail(0.17, fin)
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		b:speckle(30, v2(-0.29, 0.28), v2(-0.15, 0.16), v2(0.02, 0.045), rgb(82, 72, 44))
		b:marks(0.25, 0.07, 0.07, 0.065, rgb(164, 146, 96))
		b:face(0.37, 0.04, 0.043, rgb(176, 148, 74), colors.back)
	end,
}

end)()
species["Trout"] = (function()
return {
	Name = "Trout",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.3,
	AverageKg = 1.2,
	MaxKg = 9,
	BaseValue = 10,
	Fight = 0.04,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(78, 90, 54), side = rgb(184, 188, 160), belly = rgb(240, 236, 224) }
		local fin = rgb(150, 142, 108)
		b:fishBody(0.21, 0.12, colors)
		b:edgeFin(0.07, -0.08, { 0.08, 0.075, 0.06, 0.04 }, fin)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.25, b:top(-0.25) + 0.004, 0), Vector3.new(0.045, 0.028, 0.012), fin)
		b:edgeFin(-0.12, -0.23, { 0.06, 0.05, 0.035 }, fin, true)
		b:edgeFin(0.02, -0.07, { 0.05, 0.045 }, fin, true)
		b:forkTail(0.11, 0.045, fin)
		b:pectoral(0.2, -0.05, 0.1, 0.035, fin)
		for x = 0.26, -0.3, -0.028 do
			b:marks(x, -0.004, 0.055, 0.04 * (1 - math.abs(x) * 0.9), rgb(222, 128, 132))
		end
		b:marks(0.29, -0.01, 0.08, 0.045, rgb(216, 132, 128))
		b:speckle(46, v2(-0.33, 0.33), v2(-0.01, 0.11), v2(0.011, 0.018), rgb(32, 32, 26))
		for _ = 1, 9 do
			b:finSpot(b.random(-0.47, -0.37), b.random(-0.09, 0.09), 0.012, rgb(40, 40, 32))
		end
		for _ = 1, 4 do
			b:finSpot(b.random(-0.06, 0.04), b:top(0) + b.random(0.01, 0.05), 0.011, rgb(40, 40, 32))
		end
		b:face(0.37, 0.02, 0.045, rgb(204, 172, 96), rgb(120, 112, 96))
	end,
}

end)()
species["VoidlightAngler"] = (function()
return {
	Name = "Voidlight Angler",
	Rarity = "Legendary",
	RarityDenominator = 110,
	MinKg = 2,
	AverageKg = 9,
	MaxKg = 75,
	BaseValue = 1250,
	Fight = 0.10,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Summer", "Autumn", "Winter" },
	Requires = { "BlackHole" },
	Shapes = {
		Normal = { "###", "###" },
		Big = { "####", "####", ".##." },
		Huge = { "#####", "#####", "#####" },
	},
	-- A squat abyssal predator whose lantern bends over an oversized, needle-toothed jaw.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(8, 5, 15), side = rgb(27, 11, 43), belly = rgb(40, 17, 61) }
		local membrane, violet, lilac = rgb(39, 15, 65), rgb(161, 49, 255), rgb(218, 139, 255)
		local function glow(part)
			if part then
				part.Material = Enum.Material.Neon
				part:SetAttribute("BlackHoleAccent", true)
			end
			return part
		end
		b:fishBody(0.43, 0.33, colors, 0.03)
		b:layered("LowerJaw", Vector3.new(0.36, -0.16, 0), Vector3.new(0.29, 0.105, 0.28), colors)
		b:finishSkin()
		b:ellipsoid("Mouth", CFrame.new(0.455, -0.052, 0), Vector3.new(0.12, 0.18, 0.252), rgb(2, 1, 6))
		for _, side in { -1, 1 } do
			glow(b:limb(Vector3.new(0.47, -0.128, side * 0.09), Vector3.new(0.505, -0.03, side * 0.075), 0.013, lilac, "Fang"))
			glow(b:limb(Vector3.new(0.445, 0.029, side * 0.105), Vector3.new(0.49, -0.056, side * 0.09), 0.011, violet, "Fang"))
			for index = 1, 5 do
				local x = 0.22 - index * 0.082
				glow(b:mark(x, -0.025 - math.sin(index * 0.7) * 0.025, side, 0.037, 0.021, violet))
			end
			glow(b:mark(0.285, 0.10, side, 0.07, 0.072, lilac))
			b:mark(0.287, 0.10, side, 0.027, 0.043, rgb(3, 1, 8), nil, 0.005)
		end
		local dorsal = b:edgeFin(0.05, -0.29, { 0.12, 0.035, 0.17, 0.04, 0.13, 0.025 }, membrane)
		local lower = b:edgeFin(-0.08, -0.29, { 0.06, 0.018, 0.09, 0.025 }, membrane, true)
		for _, points in { dorsal, lower } do
			for index = 2, #points - 1 do
				local a, c = points[index], points[index + 1]
				glow(b:limb(Vector3.new(a.X, a.Y, 0), Vector3.new(c.X, c.Y, 0), 0.008, violet, "FinRim"))
			end
		end
		b:forkTail(0.16, 0.065, membrane)
		for _, sign in { -1, 1 } do
			glow(b:limb(Vector3.new(-0.35, sign * 0.022, 0), Vector3.new(-0.5, sign * 0.16, 0), 0.009, violet, "TailRim"))
			b:fin({
				Vector3.new(0.10, -0.045, sign * 0.15),
				Vector3.new(-0.10, -0.13, sign * 0.29),
				Vector3.new(-0.03, -0.16, sign * 0.20),
				Vector3.new(0.12, -0.09, sign * 0.15),
			}, membrane)
			glow(b:limb(Vector3.new(0.10, -0.045, sign * 0.15), Vector3.new(-0.10, -0.13, sign * 0.29), 0.01, violet, "PectoralRim"))
		end
		local lure = {
			Vector3.new(0.18, 0.18, 0), Vector3.new(0.17, 0.32, 0),
			Vector3.new(0.23, 0.44, 0), Vector3.new(0.35, 0.49, 0),
			Vector3.new(0.46, 0.47, 0), Vector3.new(0.51, 0.39, 0),
		}
		for index = 1, #lure - 1 do
			b:limb(lure[index], lure[index + 1], 0.023 - index * 0.002, membrane, "LanternStalk")
		end
		glow(b:ellipsoid("Lantern", CFrame.new(lure[#lure]), Vector3.one * 0.083, lilac))
		glow(b:ellipsoid("LanternHalo", CFrame.new(lure[#lure]), Vector3.one * 0.125, violet, 0.82))
		b.model:SetAttribute("ViewDirection", Vector3.new(0.22, 0.15, 1))
	end,
}

end)()
species["Walleye"] = (function()
return {
	Name = "Walleye",
	Rarity = "Rare",
	RarityDenominator = 20,
	MinKg = 0.5,
	AverageKg = 2,
	MaxKg = 11,
	BaseValue = 63,
	Fight = 0.04,
	Pools = { "MainLake" },
	Seasons = { "Spring", "Winter" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "####", "####" },
	},
	-- Olive-gold perch with dark saddles, a spiny then soft dorsal and big glassy eyes.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(96, 92, 46), side = rgb(186, 170, 92), belly = rgb(236, 230, 200) }
		local fin = rgb(150, 136, 80)
		b:fishBody(0.2, 0.12, colors, 0.04)
		local spines = b:edgeFin(0.15, 0.0, { 0.07, 0.08, 0.075, 0.06, 0.04 }, fin, false, 0.08)
		b:rays(spines[1], { spines[3], spines[4], spines[5], spines[6] }, rgb(70, 64, 36))
		b:finSpot(0.02, b:top(0.02) + 0.02, 0.022, rgb(30, 28, 20))
		b:edgeFin(-0.04, -0.2, { 0.06, 0.06, 0.05, 0.035 }, fin)
		b:edgeFin(-0.1, -0.22, { 0.05, 0.045, 0.03 }, fin, true)
		b:edgeFin(0.04, -0.04, { 0.04 }, fin, true)
		b:forkTail(0.12, 0.05, fin)
		-- The white tip on the lower tail lobe is the walleye's field mark.
		b:fin({ v2(-0.46, -0.07), v2(-0.5, -0.12), v2(-0.44, -0.1) }, rgb(240, 240, 232))
		b:pectoral(0.2, -0.04, 0.09, 0.03, fin)
		for _, x in { 0.18, 0.06, -0.06, -0.18 } do
			b:stroke({ v2(x, b:top(x) - 0.01), v2(x - 0.02, 0.0) }, 0.04, rgb(80, 74, 36))
		end
		b:face(0.36, 0.025, 0.06, rgb(214, 214, 196), rgb(110, 104, 56))
	end,
}

end)()
species["WhiteCatfish"] = (function()
return {
	Name = "White Catfish",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.2,
	AverageKg = 1.8,
	MaxKg = 9,
	BaseValue = 38,
	Fight = 0.06,
	Pools = { "MainLake" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "#####", "#####" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(88, 104, 116), side = rgb(184, 196, 198), belly = rgb(246, 244, 228) }
		local fin, whisker = rgb(140, 154, 160), rgb(224, 224, 204)
		b:fishBody(0.22, 0.21, colors, 0.14)
		local dorsal = b:edgeFin(0.15, 0.025, { 0.11, 0.075, 0.045 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3] }, colors.back)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.23, b:top(-0.23) + 0.006, 0), Vector3.new(0.1, 0.032, 0.015), fin)
		b:edgeFin(-0.02, -0.31, { 0.045, 0.055, 0.055, 0.055, 0.045 }, fin, true)
		b:edgeFin(0.06, -0.005, { 0.045 }, fin, true)
		b:forkTail(0.13, 0.025, fin)
		b:pectoral(0.24, -0.05, 0.12, 0.045, fin)
		-- Paired long maxillary barbels and four shorter chin barbels.
		for _, side in { 1, -1 } do
			local bend = Vector3.new(0.35, -0.055, side * 0.15)
			b:limb(Vector3.new(0.46, -0.01, side * 0.035), bend, 0.009, whisker, "Barbel")
			b:limb(bend, Vector3.new(0.2, -0.13, side * 0.18), 0.006, whisker, "Barbel")
			for _, z in { 0.015, 0.04 } do
				local chin = b:bottom(0.44)
				b:limb(Vector3.new(0.44, chin + 0.006, side * z), Vector3.new(0.4, chin - 0.055, side * z * 1.7), 0.006, whisker, "Barbel")
			end
		end
		-- Broad pale head and a lightly forked tail.
		b:marks(0.31, -0.035, 0.11, 0.05, rgb(226, 228, 210))
		b:face(0.4, 0.018, 0.031, rgb(178, 184, 142), colors.back)
	end,
}

end)()
species["WhiteMarlin"] = (function()
return {
	Name = "White Marlin",
	Rarity = "Epic",
	RarityDenominator = 32,
	MinKg = 8,
	AverageKg = 25,
	MaxKg = 90,
	LengthScale = 1.5,
	BaseValue = 310,
	Fight = 0.09,
	Pools = { "PirateCove" },
	Seasons = { "Spring", "Summer" },
	Requires = { "Day" },
	Shapes = {
		Normal = { "####", ".##." },
		Big = { "#####", ".###." },
		Huge = { "######", ".####." },
	},
	-- Pale silver flanks and a rounded, dark-spotted first dorsal.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(36, 62, 104), side = rgb(168, 190, 210), belly = rgb(240, 244, 244) }
		local fin = rgb(74, 102, 146)
		b:fishBody(0.17, 0.095, colors, 0.02)
		local dorsal = b:edgeFin(0.26, -0.23, { 0.12, 0.17, 0.18, 0.15, 0.10, 0.055, 0.025 }, fin, false, 0.05)
		for index = 3, 6 do
			local tip = dorsal[index]
			b:finSpot(tip.X, b:top(tip.X) + (tip.Y - b:top(tip.X)) * 0.6, 0.017, rgb(28, 46, 82))
		end
		b:edgeFin(-0.25, -0.3, { 0.025 }, fin)
		b:edgeFin(0.0, -0.16, { 0.075, 0.055, 0.03 }, fin, true)
		b:edgeFin(-0.25, -0.3, { 0.025 }, fin, true)
		b:lunateTail(0.20, fin)
		b:pectoral(0.23, -0.025, 0.17, 0.042, fin)
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.17, b:bottom(0.17), side * 0.012), Vector3.new(-0.03, -0.15, side * 0.024), 0.006, fin, "PelvicFin")
		end
		for x = 0.2, -0.26, -0.06 do
			b:stroke({ v2(x, b:top(x) * 0.65), v2(x - 0.012, b:bottom(x) * 0.3) }, 0.007, rgb(132, 162, 204))
		end
		b:limb(Vector3.new(0.44, 0.006, 0), Vector3.new(0.78, 0.002, 0), 0.018, colors.back, "Bill")
		b:face(0.37, 0.024, 0.04, rgb(180, 192, 198), rgb(84, 108, 144))
	end,
}

end)()
species["WoodenBranch"] = (function()
return {
	Name = "Wooden Branch",
	Rarity = "Junk",
	RarityDenominator = 50,
	MinKg = 0.2,
	AverageKg = 0.5,
	MaxKg = 1,
	BaseValue = 1,
	Fight = 0,
	Shapes = {
		Normal = { "###" },
	},
	Build = function(b, kit)
		local rgb = kit.rgb
		local bark = { rgb(83, 55, 33), rgb(112, 77, 45), rgb(94, 62, 36), rgb(68, 46, 30), rgb(101, 68, 40) }
		local wood, freshWood, split = rgb(180, 138, 82), rgb(207, 166, 105), rgb(48, 33, 23)
		local function face(a, c, d, color, name)
			local first, second = b:triangle(a, c, d, color)
			for _, part in { first, second } do
				part.Name = name
				part.Material = Enum.Material.Wood
			end
		end

		-- Shared five-sided rings keep each bend joined while tapering the branch.
		-- Uneven ring radii and staggered end vertices make flat, chipped wood faces.
		local facets = 5
		local widths = { 1, 0.88, 1.06, 0.91, 0.97 }
		local chips = { 0.2, -0.12, 0.08, -0.23, 0.14 }
		local function branch(points, radii, roll, isTrunk)
			local axis = (points[#points] - points[1]).Unit
			local side = axis:Cross(Vector3.yAxis).Unit
			local up = side:Cross(axis).Unit
			local rings = {}
			for index, center in points do
				local ring = {}
				for corner = 1, facets do
					local angle = (corner - 1) * math.pi * 2 / facets + roll
					local radial = up * math.cos(angle) + side * math.sin(angle)
					local chip = if index == 1 or index == #points then chips[corner] * radii[index] else 0
					ring[corner] = center + radial * radii[index] * widths[corner] + axis * chip
				end
				table.insert(rings, ring)
			end
			for index = 1, #rings - 1 do
				local a, c = rings[index], rings[index + 1]
				for corner = 1, facets do
					local nextCorner = corner % facets + 1
					local color = bark[corner]
					face(a[corner], c[corner], c[nextCorner], color, "BarkFacet")
					face(a[corner], c[nextCorner], a[nextCorner], color, "BarkFacet")
					if isTrunk then
						-- Tapered cracks sit on the actual sloping bark faces, on all sides.
						local normal = (a[corner] - points[index] + a[nextCorner] - points[index]).Unit
						local start = a[corner]:Lerp(a[nextCorner], 0.36):Lerp(c[corner]:Lerp(c[nextCorner], 0.36), 0.16)
						local finish = a[corner]:Lerp(a[nextCorner], 0.44):Lerp(c[corner]:Lerp(c[nextCorner], 0.44), 0.87)
						local across = (a[nextCorner] - a[corner]).Unit * 0.003
						local lift = normal * 0.003
						face(start - across + lift, start + across + lift, finish + lift, split, "BarkSplit")
					end
				end
			end
			for _, index in { 1, #rings } do
				for corner = 1, facets do
					local color = if corner % 2 == 0 then freshWood else wood
					face(points[index], rings[index][corner], rings[index][corner % facets + 1], color, "ExposedWood")
				end
			end
			return rings, axis
		end

		local points = {
			Vector3.new(-0.5, -0.04, 0),
			Vector3.new(-0.18, 0.018, 0.012),
			Vector3.new(0.14, -0.012, -0.006),
			Vector3.new(0.48, 0.065, -0.028),
		}
		local rings, axis = branch(points, { 0.065, 0.055, 0.041, 0.026 }, 0.23, true)
		branch(
			{ points[2], Vector3.new(-0.09, 0.19, 0.025), Vector3.new(0.015, 0.31, 0.045) },
			{ 0.033, 0.023, 0.009 },
			0.7,
			false
		)
		branch({ points[3], Vector3.new(0.29, -0.205, 0.07) }, { 0.025, 0.011 }, -0.25, false)

		-- A pair of solid triangular splinters extends the snapped thick end.
		for _, corner in { 1, 3 } do
			local ring = rings[1]
			local a, c = ring[corner], ring[corner % facets + 1]
			local root = points[1]:Lerp((a + c) / 2, 0.6)
			local tip = a:Lerp(c, 0.3) - axis * (if corner == 1 then 0.07 else 0.042)
			face(a, c, tip, bark[corner], "BrokenBark")
			face(a, root, tip, wood, "WoodSplinter")
			face(c, tip, root, freshWood, "WoodSplinter")
		end
		b.model:SetAttribute("ViewDirection", Vector3.new(0.35, 0.5, 1))
	end,
}

end)()
species["YellowAngler"] = (function()
return {
	Name = "Yellow Angler",
	Rarity = "Legendary",
	RarityDenominator = 90,
	MinKg = 2,
	AverageKg = 8,
	MaxKg = 50,
	BaseValue = 1200,
	Fight = 0.07,
	Pools = { "OpenSea" },
	Seasons = { "Autumn" },
	Shapes = {
		Normal = { "###", "###" },
		Big = { "####", "####" },
		Huge = { "#####", "#####", ".###." },
	},
	-- Fictional golden anglerfish: a huge round head with a gaping, fanged mouth,
	-- a short tapering tail and a glowing lure dangling over the jaws.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(200, 150, 26), side = rgb(238, 198, 58), belly = rgb(248, 228, 146) }
		local fin, tooth = rgb(214, 160, 40), rgb(250, 246, 226)
		b:beginSkin(colors)
		b:layered("Body", Vector3.new(0.06, 0, 0), Vector3.new(0.62, 0.5, 0.46), colors)
		b:layered("TailBody", Vector3.new(-0.26, -0.01, 0), Vector3.new(0.3, 0.2, 0.16), colors)
		b:layered("TailStalk", Vector3.new(-0.36, 0, 0), Vector3.new(0.12, 0.1, 0.07), colors)
		-- The jaw stays separate so the open mouth still shows between them.
		b:finishSkin()
		b:layered("LowerJaw", Vector3.new(0.27, -0.14, 0), Vector3.new(0.38, 0.16, 0.42), colors)
		b:ellipsoid("Mouth", CFrame.new(0.365, -0.065, 0), Vector3.new(0.13, 0.19, 0.34), rgb(48, 12, 18))
		for index = -4, 4 do
			local z = index * 0.032
			local x = 0.43 - math.abs(index) * 0.012
			b:limb(Vector3.new(x, 0.0, z), Vector3.new(x + 0.01, -0.05, z), 0.012, tooth, "Tooth")
			b:limb(Vector3.new(x - 0.01, -0.15, z), Vector3.new(x + 0.005, -0.09, z), 0.012, tooth, "Tooth")
		end
		b:edgeFin(-0.12, -0.3, { 0.06, 0.07, 0.05 }, fin, false, 0.1)
		b:edgeFin(-0.14, -0.3, { 0.05, 0.05 }, fin, true, 0.1)
		b:roundTail(0.12, fin, 0.05)
		b:pectoral(0.0, -0.08, 0.12, 0.08, fin, 0.1)
		b:speckle(36, v2(-0.3, 0.3), v2(-0.05, 0.22), v2(0.015, 0.035), rgb(172, 120, 20))
		-- The illicium arcs forward from the forehead to a glowing esca.
		local base = Vector3.new(0.18, b:top(0.18) - 0.01, 0)
		local bend, tip = Vector3.new(0.34, 0.4, 0), Vector3.new(0.5, 0.34, 0)
		b:limb(base, bend, 0.014, fin, "Filament")
		b:limb(bend, tip, 0.012, fin, "Filament")
		local lure = b:ellipsoid("Lure", CFrame.new(tip + Vector3.new(0.01, -0.025, 0)), Vector3.new(0.05, 0.06, 0.05), rgb(190, 255, 220))
		lure.Material = Enum.Material.Neon
		b:eye(0.26, 0.13, 0.045, rgb(230, 230, 200))
	end,
}

end)()
species["YellowBass"] = (function()
return {
	Name = "Yellow Bass",
	Rarity = "Common",
	RarityDenominator = 5,
	MinKg = 0.08,
	AverageKg = 0.35,
	MaxKg = 1.6,
	BaseValue = 14,
	Fight = 0.03,
	Pools = { "MainLake" },
	Seasons = { "Spring", "Summer" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	},
	-- Species-specific body proportions, fins and flank markings share the smooth mesh pipeline.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(112, 114, 40), side = rgb(220, 202, 92), belly = rgb(246, 234, 176) }
		local fin = rgb(176, 158, 60)
		b:fishBody(0.27, 0.12, colors, 0.07)
		local dorsal = b:edgeFin(0.15, -0.23, { 0.06, 0.075, 0.07, 0.055, 0.04, 0.055, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, rgb(72, 74, 36))
		b:edgeFin(-0.08, -0.23, { 0.06, 0.07, 0.045 }, fin, true)
		b:edgeFin(0.08, 0, { 0.055, 0.04 }, fin, true)
		b:forkTail(0.13, 0.055, fin)
		b:pectoral(0.21, -0.04, 0.105, 0.04, fin, 0.1)
		-- Several long dark stripes across the golden flank.
		for _, y in { -0.075, -0.04, -0.005, 0.03, 0.065 } do
			b:stroke({ v2(0.23, y), v2(-0.08, y * 0.78), v2(-0.3, y * 0.4) }, 0.008, rgb(78, 82, 38))
		end
		b:face(0.37, 0.033, 0.046, rgb(214, 176, 48), rgb(72, 74, 36))
	end,
}

end)()
species["YellowBullhead"] = (function()
return {
	Name = "Yellow Bullhead",
	Rarity = "Common",
	RarityDenominator = 5,
	MinKg = 0.1,
	AverageKg = 0.55,
	MaxKg = 3,
	BaseValue = 16,
	Fight = 0.04,
	Pools = { "MainLake", "SoddenMire" },
	Seasons = { "Summer", "Autumn" },
	Requires = { "Rain" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(100, 90, 36), side = rgb(184, 162, 66), belly = rgb(240, 222, 150) }
		local fin, whisker = rgb(152, 128, 46), rgb(236, 226, 186)
		b:fishBody(0.24, 0.2, colors, 0.16)
		local dorsal = b:edgeFin(0.15, 0.025, { 0.11, 0.075, 0.045 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3] }, colors.back)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.23, b:top(-0.23) + 0.006, 0), Vector3.new(0.1, 0.032, 0.015), fin)
		b:edgeFin(-0.02, -0.31, { 0.045, 0.055, 0.055, 0.055, 0.045 }, fin, true)
		b:edgeFin(0.06, -0.005, { 0.045 }, fin, true)
		b:roundTail(0.115, fin)
		b:pectoral(0.24, -0.05, 0.12, 0.045, fin)
		-- Paired long maxillary barbels and four shorter chin barbels.
		for _, side in { 1, -1 } do
			local bend = Vector3.new(0.35, -0.055, side * 0.15)
			b:limb(Vector3.new(0.46, -0.01, side * 0.035), bend, 0.009, whisker, "Barbel")
			b:limb(bend, Vector3.new(0.2, -0.13, side * 0.18), 0.006, whisker, "Barbel")
			for _, z in { 0.015, 0.04 } do
				local chin = b:bottom(0.44)
				b:limb(Vector3.new(0.44, chin + 0.006, side * z), Vector3.new(0.4, chin - 0.055, side * z * 1.7), 0.006, whisker, "Barbel")
			end
		end
		b:stroke({ v2(0.27, -0.055), v2(0, -0.075), v2(-0.25, -0.03) }, 0.012, rgb(226, 202, 112))
		b:face(0.4, 0.018, 0.031, rgb(182, 146, 46), colors.back)
	end,
}

end)()
species["YellowSeaCucumber"] = (function()
return {
	Name = "Yellow Sea Cucumber",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.1,
	AverageKg = 0.4,
	MaxKg = 1.5,
	BaseValue = 50,
	Fight = 0,
	Pools = { "OpenSea" },
	Seasons = { "Autumn", "Winter" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####" },
	},
	-- A soft yellow sausage studded with papillae, tube feet underneath and a
	-- ring of feeding tentacles at the front. No eyes.
	Build = function(b, kit)
		local rgb = kit.rgb
		local colors = { back = rgb(208, 160, 36), side = rgb(234, 196, 64), belly = rgb(244, 222, 140) }
		b:layered("Body", Vector3.new(0, 0, 0), Vector3.new(0.88, 0.2, 0.22), colors)
		b:layered("Front", Vector3.new(0.38, 0, 0), Vector3.new(0.18, 0.16, 0.17), colors)
		b:layered("Rear", Vector3.new(-0.38, 0, 0), Vector3.new(0.16, 0.14, 0.15), colors)
		for _ = 1, 46 do
			local x, y = b.random(-0.4, 0.4), b.random(-0.02, 0.09)
			local side = if b.random(0, 1) > 0.5 then 1 else -1
			local position, normal = b:surface(x, y, side)
			if position and normal then
				b:limb(position - normal * 0.006, position + normal * b.random(0.02, 0.04), 0.016, rgb(246, 210, 90), "Spine")
			end
		end
		for x = -0.36, 0.36, 0.045 do
			for _, z in { -0.05, 0.05 } do
				b:ellipsoid("TubeFoot", CFrame.new(x, b:bottom(x) + 0.004, z), Vector3.new(0.018, 0.02, 0.018), rgb(250, 236, 180))
			end
		end
		for index = 0, 9 do
			local angle = index / 10 * math.pi * 2
			local spread = Vector3.new(0, math.cos(angle), math.sin(angle))
			local root = Vector3.new(0.46, 0, 0) + spread * 0.04
			local tip = Vector3.new(0.54, 0, 0) + spread * 0.08
			b:limb(root, tip, 0.012, rgb(250, 226, 130), "Filament")
		end
	end,
}

end)()
species["YelloweyeRockfish"] = (function()
return {
	Name = "Yelloweye Rockfish",
	Rarity = "Epic",
	RarityDenominator = 32,
	MinKg = 0.8,
	AverageKg = 4,
	MaxKg = 12,
	BaseValue = 382,
	Fight = 0.07,
	Pools = { "FrostmereExpanse" },
	Seasons = { "Autumn", "Winter" },
	Requires = { "Clear", "Day" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Stocky orange-red body, pronounced brow and oversized yellow eyes.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(186, 68, 30), side = rgb(240, 116, 42), belly = rgb(252, 204, 148) }
		local fin = rgb(212, 82, 28)
		b:fishBody(0.34, 0.17, colors, 0.08)
		b:layered("LowerJaw", Vector3.new(0.405, -0.052, 0), Vector3.new(0.17, 0.075, 0.11050000000000001), colors)
		local spines = b:edgeFin(0.2, -0.08, { 0.045, 0.09, 0.105, 0.10, 0.085, 0.07, 0.04 }, fin)
		for index = 3, #spines - 1 do
			local tip = spines[index]
			b:rays(v2(tip.X, b:top(tip.X)), { tip }, colors.back)
		end
		b:edgeFin(-0.08, -0.27, { 0.075, 0.085, 0.07, 0.04 }, fin, false, 0.05)
		b:edgeFin(-0.08, -0.25, { 0.065, 0.07, 0.045 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.055, 0.04 }, fin, true)
		b:forkTail(0.14, 0.025, fin)
		b:pectoral(0.24, -0.045, 0.15, 0.065, fin)
		-- A raised brow and short cheek spines distinguish the rockfish head.
		for _, side in { 1, -1 } do
			b:limb(Vector3.new(0.34, 0.07, side * 0.051000000000000004), Vector3.new(0.30, 0.092, side * 0.0595), 0.013, colors.back, "Brow")
			b:limb(Vector3.new(0.26, -0.005, side * 0.0816), Vector3.new(0.20, -0.015, side * 0.11050000000000001), 0.012, fin, "CheekSpine")
		end
		b:face(0.37, 0.045, 0.065, rgb(255, 222, 28), colors.back)
	end,
}


end)()
species["YellowfinGrouper"] = (function()
return {
	Name = "Yellowfin Grouper",
	Rarity = "Rare",
	RarityDenominator = 18,
	MinKg = 1,
	AverageKg = 5,
	MaxKg = 25,
	BaseValue = 190,
	Fight = 0.065,
	Pools = { "CoralShallows" },
	Seasons = { "Spring", "Summer" },
	Requires = { "Clear", "Day" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Olive grouper with pale oval spots, yellow paired fins and a yellow-edged rounded tail.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(100, 98, 62), side = rgb(174, 168, 104), belly = rgb(228, 220, 168) }
		local fin = rgb(216, 176, 48)
		b:fishBody(0.31, 0.17, colors, 0.075)
		local dorsal = b:edgeFin(0.17, -0.22, { 0.055, 0.075, 0.07, 0.06, 0.055, 0.065, 0.08, 0.075, 0.055 }, fin, false, 0.05)
		b:rays(dorsal[1], { dorsal[3], dorsal[4], dorsal[5] }, colors.back)
		b:edgeFin(-0.08, -0.24, { 0.065, 0.075, 0.055 }, fin, true)
		b:edgeFin(0.1, 0.015, { 0.06, 0.045 }, fin, true)
		b:roundTail(0.135, fin)
		b:pectoral(0.2, -0.04, 0.13, 0.05, fin)
		b:speckle(42, v2(-0.3, 0.3), v2(-0.105, 0.12), v2(0.012, 0.024), rgb(232, 220, 156))
		b:pectoral(0.22, -0.035, 0.16, 0.055, rgb(242, 198, 44))
		b:marks(0.3, 0.055, 0.026, 0.025, rgb(230, 216, 150))
		b:face(0.37, 0.04, 0.043, rgb(218, 178, 70), colors.back)
	end,
}

end)()
species["YellowfinTuna"] = (function()
return {
	Name = "Yellowfin Tuna",
	Rarity = "Rare",
	RarityDenominator = 12,
	MinKg = 6,
	AverageKg = 35,
	MaxKg = 200,
	LengthScale = 1.3,
	BaseValue = 150,
	Fight = 0.08,
	Pools = { "OpenSea" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "###", "###" },
		Big = { "####", "####" },
		Huge = { ".####.", "######", ".####." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(24, 40, 82), side = rgb(150, 160, 176), belly = rgb(232, 234, 236) }
		local fin, yellow = rgb(40, 52, 84), rgb(242, 196, 40)
		b:fishBody(0.27, 0.2, colors, 0.03)
		b:edgeFin(0.14, 0.02, { 0.08, 0.06, 0.03 }, fin, false, 0.05)
		-- Long yellow sickle fins, the species' trademark.
		b:fin({ v2(0, b:top(0) - 0.008), v2(-0.14, b:top(0) + 0.22), v2(-0.09, b:top(-0.09) - 0.008) }, yellow)
		b:fin(
			{ v2(-0.02, b:bottom(-0.02) + 0.008), v2(-0.16, b:bottom(-0.02) - 0.2), v2(-0.1, b:bottom(-0.1) + 0.008) },
			yellow
		)
		for index = 0, 5 do
			local x = -0.15 - index * 0.03
			for _, below in { false, true } do
				local edge = if below then b:bottom(x) else b:top(x)
				local sign = if below then -1 else 1
				b:fin({
					v2(x + 0.008, edge - sign * 0.004),
					v2(x - 0.012, edge + sign * 0.022),
					v2(x - 0.014, edge - sign * 0.004),
				}, yellow)
			end
		end
		b:lunateTail(0.24, fin)
		b:pectoral(0.21, 0.01, 0.19, 0.065, fin)
		b:stroke({ v2(0.28, 0.035), v2(0, 0.04), v2(-0.28, 0.012) }, 0.018, yellow)
		for x = 0.1, -0.24, -0.05 do
			b:stroke({ v2(x, -0.03), v2(x - 0.01, b:bottom(x) * 0.7) }, 0.006, rgb(200, 206, 214))
		end
		b:face(0.37, 0.03, 0.05, rgb(180, 170, 120), rgb(70, 80, 100))
	end,
}

end)()
species["Yellowshark"] = (function()
return {
	Name = "Yellowshark",
	Rarity = "Legendary",
	RarityDenominator = 90,
	MinKg = 40,
	AverageKg = 180,
	MaxKg = 1100,
	LengthScale = 1.4,
	BaseValue = 1260,
	Fight = 0.08,
	Pools = { "OpenSea" },
	Seasons = { "Summer" },
	Requires = { "Storm" },
	Shapes = {
		Normal = { "..#..", "#####", "#####" },
		Big = { "...#..", "######", "######", ".####." },
		Huge = { "...#...", "#######", "#######", "#######", ".#####." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(196, 150, 32), side = rgb(232, 196, 70), belly = rgb(246, 238, 210) }
		local fin = rgb(204, 160, 40)
		b:fishBody(0.2, 0.19, colors, 0)
		b:layered("Snout", Vector3.new(0.43, 0.01, 0), Vector3.new(0.16, 0.1, 0.13), colors)
		b:fin({
			v2(0.12, b:top(0.12) - 0.008),
			v2(0, b:top(0) + 0.17),
			v2(-0.03, b:top(0) + 0.15),
			v2(-0.04, b:top(-0.04) - 0.008),
		}, fin)
		b:edgeFin(-0.22, -0.28, { 0.04, 0.025 }, fin)
		b:edgeFin(-0.2, -0.26, { 0.035, 0.02 }, fin, true)
		b:edgeFin(-0.04, -0.1, { 0.04, 0.03 }, fin, true)
		b:pectoral(0.18, -0.06, 0.2, 0.06, fin)
		-- Shark tail: the upper lobe reaches much further than the lower one.
		local stalk = b:top(-0.36)
		local upper, lower = v2(-0.34, stalk * 0.9), v2(-0.34, -stalk * 0.9)
		b:fin({ upper, v2(-0.6, 0.26), v2(-0.56, 0.2), v2(-0.42, 0), lower }, fin)
		b:fin({ lower, v2(-0.44, 0), v2(-0.52, -0.15) }, fin)
		b:speckle(24, v2(-0.3, 0.3), v2(0.02, 0.09), v2(0.015, 0.03), rgb(176, 128, 24))
		for index = 0, 4 do
			local x = 0.27 - index * 0.028
			b:stroke({ v2(x, 0.035), v2(x - 0.008, -0.04) }, 0.007, rgb(150, 110, 24))
		end
		b:stroke({ v2(0.43, -0.035), v2(0.38, -0.055), v2(0.32, -0.06) }, 0.008, rgb(60, 40, 20))
		b:eye(0.4, 0.03, 0.03, rgb(20, 20, 20))
	end,
}

end)()
return species
end)()

local SCALE = 4 -- studs per fish length
local FIN = 0.004
local rgb = Color3.fromRGB
local templates: { [string]: Model } = {}
-- Smooth skins by species (see Builder:loftBody), for FishMeshes on clients.
local lofts = {}
local LOFT_STEPS = 6 -- rings between two stations
FishModels.SCALE = SCALE
FishModels.LOFT_TAG = "FishLoft"

type Ellipsoid = { c: Vector3, h: Vector3 }

local function seeded(seed: number)
	local state = seed
	return function(low: number, high: number): number
		state = (state * 16807) % 2147483647
		return low + (high - low) * (state / 2147483647)
	end
end

local Builder = {}
Builder.__index = Builder

local function newBuilder(name: string, seed: number)
	local model = Instance.new("Model")
	model.Name = name
	return setmetatable({ model = model, sections = {} :: { Ellipsoid }, random = seeded(seed) }, Builder)
end

function Builder:part(name: string, class: string, size: Vector3, frame: CFrame, color: Color3, transparency: number?)
	local item = Instance.new(class) :: BasePart
	item.Name = name
	item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = true, false, false, false
	item.CastShadow = false
	item.Material = Enum.Material.SmoothPlastic
	item.TopSurface, item.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	item.Color = color
	item.Transparency = transparency or 0
	item.Size = Vector3.new(math.max(size.X, 0.0003), math.max(size.Y, 0.0003), math.max(size.Z, 0.0003)) * SCALE
	item.CFrame = frame.Rotation + frame.Position * SCALE
	item.Parent = self.model
	return item
end

function Builder:ellipsoid(name: string, frame: CFrame, size: Vector3, color: Color3, transparency: number?)
	local item = self:part(name, "Part", size, frame, color, transparency)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = item
	return item
end

-- An axis-aligned ellipsoid that markings can be laid on.
function Builder:body(name: string, center: Vector3, size: Vector3, color: Color3, transparency: number?)
	local section = { c = center, h = size / 2 }
	table.insert(self.sections, section)
	return self:ellipsoid(name, CFrame.new(center), size, color, transparency), section
end

local function sameColors(a, b): boolean
	return a == b or (a.side == b.side and a.back == b.back and a.belly == b.belly)
end

-- Main colour with a darker back and paler belly layer offset above and below.
-- While a fishBody skin is still open, layers in the body's own colours (a
-- snout, hump or jaw) join the smooth skin instead of staying spheres.
function Builder:layered(name: string, center: Vector3, size: Vector3, colors)
	local side, sideSection = self:body(name, center, size, colors.side)
	local back, backSection = self:body(
		name .. "Back",
		center + Vector3.new(0, size.Y * 0.12, 0),
		size * Vector3.new(0.985, 0.86, 1.012),
		colors.back
	)
	local belly, bellySection = self:body(
		name .. "Belly",
		center - Vector3.new(0, size.Y * 0.14, 0),
		size * Vector3.new(0.97, 0.8, 1.006),
		colors.belly
	)
	local open = self.skinOpen
	if open and sameColors(open.colors, colors) then
		for _, part in { side, back, belly } do
			table.insert(open.parts, part)
		end
		for _, section in { sideSection, backSection, bellySection } do
			table.insert(open.sections, section)
		end
		open.swatches = open.swatches or { Side = side, Back = back, Belly = belly }
	end
	return side, back, belly
end

-- Loft rings are { x, top, bottom, width (half) } cross-sections, snout first.
type Ring = { x: number, top: number, bottom: number, width: number }

-- Point on a loft cross-section; angle 0 is the back, pi the belly and positive
-- angles the +Z flank. Slightly egg-shaped: narrow over the back, fullest
-- just below the middle.
local function loftPoint(ring: Ring, angle: number): Vector3
	local c = math.cos(angle)
	local middle, half = (ring.top + ring.bottom) / 2, (ring.top - ring.bottom) / 2
	return Vector3.new(ring.x, middle + half * c, ring.width * math.sin(angle) * (1 - 0.18 * c))
end

-- The cross-section at x, between the two rings around it; outside the loft it
-- is nil, or the nearest end ring when `clamp` is set.
local function loftRing(rings: { Ring }, x: number, clamp: boolean?): Ring?
	if x >= rings[1].x then
		return if clamp then rings[1] else nil
	end
	for index = 2, #rings do
		local a, b = rings[index - 1], rings[index]
		if x >= b.x then
			local t = (a.x - x) / math.max(a.x - b.x, 1e-6)
			return {
				x = x,
				top = a.top + (b.top - a.top) * t,
				bottom = a.bottom + (b.bottom - a.bottom) * t,
				width = a.width + (b.width - a.width) * t,
			}
		end
	end
	return if clamp then rings[#rings] else nil
end

-- Outward unit normal of the loft skin at x and angle.
local function loftNormal(rings: { Ring }, x: number, angle: number): Vector3
	local ring = loftRing(rings, x, true) :: Ring
	local step = 0.004
	local ahead, behind = loftRing(rings, x + step, true) :: Ring, loftRing(rings, x - step, true) :: Ring
	local along = loftPoint(ahead, angle) - loftPoint(behind, angle)
	local around = loftPoint(ring, angle + 0.01) - loftPoint(ring, angle - 0.01)
	local point = loftPoint(ring, angle)
	local outward = point - Vector3.new(ring.x, (ring.top + ring.bottom) / 2, 0)
	local normal = along:Cross(around)
	if normal.Magnitude < 1e-9 then
		return if outward.Magnitude > 1e-9 then outward.Unit else Vector3.new(1, 0, 0)
	end
	normal = normal.Unit
	return if normal:Dot(outward) < 0 then -normal else normal
end

local function catmull(p0: number, p1: number, p2: number, p3: number, t: number): number
	return 0.5
		* (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (3 * p1 - p0 - 3 * p2 + p3) * t * t * t)
end

-- Sections the smooth skin replaces are skipped while it is in use (the carp
-- clears `loft` briefly to lay its scale discs on the spheres underneath).
local function solid(self, section): boolean
	return not (section.skin and self.loft)
end

-- Outermost body surface at (x, y) on one side (+1 or -1), with its normal.
function Builder:surface(x: number, y: number, side: number): (Vector3?, Vector3?)
	self:finishSkin()
	local bestPoint: Vector3?, bestNormal: Vector3? = nil, nil
	local bestZ = -1
	if self.loft then
		local ring = loftRing(self.loft, x)
		if ring and ring.top > ring.bottom then
			local c = (y - (ring.top + ring.bottom) / 2) / ((ring.top - ring.bottom) / 2)
			if math.abs(c) < 1 then
				local angle = math.acos(c) * side
				local point = loftPoint(ring, angle)
				bestPoint, bestNormal = point, loftNormal(self.loft, x, angle)
				bestZ = point.Z * side
			end
		end
	end
	local best: Ellipsoid? = nil
	for _, section in self.sections do
		if not solid(self, section) then
			continue
		end
		local dx, dy = (x - section.c.X) / section.h.X, (y - section.c.Y) / section.h.Y
		local remaining = 1 - dx * dx - dy * dy
		if remaining > 0 then
			local z = section.c.Z * side + section.h.Z * math.sqrt(remaining)
			if z > bestZ then
				best, bestZ = section, z
			end
		end
	end
	if not best then
		return bestPoint, bestNormal
	end
	local h = best.h
	local normal = Vector3.new(
		(x - best.c.X) / (h.X * h.X),
		(y - best.c.Y) / (h.Y * h.Y),
		side * (bestZ - best.c.Z * side) / (h.Z * h.Z)
	).Unit
	return Vector3.new(x, y, side * bestZ), normal
end

function Builder:top(x: number): number
	self:finishSkin()
	local best = 0
	if self.loft then
		local ring = loftRing(self.loft, x)
		best = if ring then math.max(ring.top, 0) else 0
	end
	for _, section in self.sections do
		local dx = (x - section.c.X) / section.h.X
		if dx * dx < 1 and solid(self, section) then
			best = math.max(best, section.c.Y + section.h.Y * math.sqrt(1 - dx * dx))
		end
	end
	return best
end

function Builder:bottom(x: number): number
	self:finishSkin()
	local best = 0
	if self.loft then
		local ring = loftRing(self.loft, x)
		best = if ring then math.min(ring.bottom, 0) else 0
	end
	for _, section in self.sections do
		local dx = (x - section.c.X) / section.h.X
		if dx * dx < 1 and solid(self, section) then
			best = math.min(best, section.c.Y - section.h.Y * math.sqrt(1 - dx * dx))
		end
	end
	return best
end

-- A thin disc painted onto the body. direction is a world X/Y heading for the
-- disc's long axis; the far side receives the mirror image automatically.
function Builder:mark(
	x: number,
	y: number,
	side: number,
	width: number,
	height: number,
	color: Color3,
	direction: Vector2?,
	lift: number?
)
	local position, normal = self:surface(x, y, side)
	if not position or not normal then
		return nil
	end
	local up = if math.abs(normal.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
	local frame = CFrame.lookAt(position, position + normal, up)
	if direction then
		local heading = frame:VectorToObjectSpace(Vector3.new(direction.X, direction.Y, 0))
		frame *= CFrame.Angles(0, 0, math.atan2(heading.Y, heading.X))
	end
	frame = frame + normal * (0.0025 + (lift or 0))
	return self:ellipsoid("Marking", frame, Vector3.new(width, height, 0.004), color)
end

function Builder:marks(x: number, y: number, width: number, height: number, color: Color3, direction: Vector2?)
	for _, side in { 1, -1 } do
		self:mark(x, y, side, width, height, color, direction)
	end
end

-- Overlapping elongated discs along a polyline on both flanks.
function Builder:stroke(points: { Vector2 }, width: number, color: Color3)
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local delta = b - a
		local steps = math.max(1, math.ceil(delta.Magnitude / (width * 1.6)))
		for step = 0, steps - 1 do
			local point = a + delta * ((step + 0.5) / steps)
			self:marks(point.X, point.Y, delta.Magnitude / steps * 1.5, width, color, delta)
		end
	end
end

function Builder:eye(x: number, y: number, size: number, iris: Color3)
	for _, side in { 1, -1 } do
		local position, normal = self:surface(x, y, side)
		if not position or not normal then
			continue
		end
		local frame = CFrame.lookAt(position, position + normal)
		self:ellipsoid("Eye", frame, Vector3.new(size, size, size * 0.35), iris)
		self:ellipsoid(
			"Pupil",
			frame + normal * size * 0.06,
			Vector3.new(size * 0.6, size * 0.6, size * 0.4),
			rgb(12, 12, 14)
		)
		local glint = position + normal * size * 0.24 + Vector3.new(size * 0.12, size * 0.14, 0)
		self:ellipsoid("EyeGlint", CFrame.new(glint), Vector3.one * size * 0.16, rgb(255, 255, 255))
	end
end

-- Two wedges make an arbitrary triangle (the standard Roblox triangle method).
function Builder:triangle(a: Vector3, b: Vector3, c: Vector3, color: Color3, transparency: number?)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local normal = ac:Cross(ab)
	if normal.Magnitude < 1e-7 then
		return
	end
	local right = normal.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local first = self:part(
		"Fin",
		"WedgePart",
		Vector3.new(FIN, height, math.abs(ab:Dot(back))),
		CFrame.fromMatrix((a + b) / 2, right, up, back),
		color,
		transparency
	)
	local second = self:part(
		"Fin",
		"WedgePart",
		Vector3.new(FIN, height, math.abs(ac:Dot(back))),
		CFrame.fromMatrix((a + c) / 2, -right, up, -back),
		color,
		transparency
	)
	return first, second
end

-- Fan triangulation; points may be Vector2 (placed at z) or Vector3.
function Builder:fin(points: { any }, color: Color3, transparency: number?, z: number?)
	local function point(value): Vector3
		return if typeof(value) == "Vector2" then Vector3.new(value.X, value.Y, z or 0) else value
	end
	for index = 2, #points - 1 do
		self:triangle(point(points[1]), point(points[index]), point(points[index + 1]), color, transparency)
	end
end

-- A tapered rod between two points (barbels, arms, fin rays, filaments).
function Builder:limb(a: Vector3, b: Vector3, diameter: number, color: Color3, name: string?)
	local delta = b - a
	if delta.Magnitude < 1e-5 then
		return nil
	end
	local up = if math.abs(delta.Unit.Y) > 0.98 then Vector3.xAxis else Vector3.yAxis
	local frame = CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.pi / 2, 0)
	return self:ellipsoid(name or "Limb", frame, Vector3.new(delta.Magnitude * 1.08, diameter, diameter), color)
end

function Builder:rays(base: Vector2, tips: { Vector2 }, color: Color3)
	for _, tip in tips do
		self:limb(Vector3.new(base.X, base.Y, 0), Vector3.new(tip.X, tip.Y, 0), 0.0055, color, "FinRay")
	end
end

function Builder:finSpot(x: number, y: number, size: number, color: Color3)
	for _, side in { 1, -1 } do
		self:ellipsoid("FinSpot", CFrame.new(x, y, side * FIN * 0.6), Vector3.new(size, size, 0.003), color)
	end
end

-- Paired fin flat against one flank, angled down and back.
function Builder:pectoral(x: number, y: number, length: number, width: number, color: Color3, transparency: number?)
	for _, side in { 1, -1 } do
		local position = self:surface(x, y, side)
		if not position then
			continue
		end
		local z = position.Z + side * 0.008
		self:fin({
			Vector3.new(x, y + width * 0.4, z),
			Vector3.new(x - length * 0.55, y + width * 0.1, z + side * length * 0.25),
			Vector3.new(x - length, y - width * 0.35, z + side * length * 0.35),
			Vector3.new(x - length * 0.6, y - width * 0.75, z + side * length * 0.2),
			Vector3.new(x, y - width * 0.4, z),
		}, color, transparency)
	end
end

-- Spots scattered over part of the flank, skipping anything off the body.
function Builder:speckle(count: number, xRange: Vector2, yRange: Vector2, sizeRange: Vector2, color: Color3)
	for _ = 1, count do
		local x, y = self.random(xRange.X, xRange.Y), self.random(yRange.X, yRange.Y)
		local size = self.random(sizeRange.X, sizeRange.Y)
		if y < self:top(x) - size and y > self:bottom(x) + size then
			self:marks(x, y, size, size * self.random(0.8, 1.1), color)
		end
	end
end

local function v2(x: number, y: number): Vector2
	return Vector2.new(x, y)
end

-- Shared bony-fish body: head, chest, rear body and tail stalk. It gets a
-- smooth skin (see Builder:smoothSkin) through the envelope of these spheres
-- and any same-coloured layers added before the first surface query.
function Builder:fishBody(depth: number, width: number, colors, headDrop: number?)
	local drop = headDrop or 0.05
	self:beginSkin(colors)
	self:layered("Chest", Vector3.new(0.1, 0, 0), Vector3.new(0.6, depth, width), colors)
	self:layered("Head", Vector3.new(0.29, -depth * drop, 0), Vector3.new(0.38, depth * 0.8, width * 0.9), colors)
	self:layered("Rear", Vector3.new(-0.13, 0, 0), Vector3.new(0.42, depth * 0.72, width * 0.78), colors)
	self:layered("TailStalk", Vector3.new(-0.29, 0, 0), Vector3.new(0.2, depth * 0.3, width * 0.42), colors)
end

-- Loft rings through hand-tuned { x, top, bottom, half width } stations.
local function stationRings(stations: { { number } }): { Ring }
	local rings: { Ring } = {}
	local count = #stations
	for index = 1, count - 1 do
		local p0, p1 = stations[math.max(index - 1, 1)], stations[index]
		local p2, p3 = stations[index + 1], stations[math.min(index + 2, count)]
		for step = 0, LOFT_STEPS - 1 do
			local t = step / LOFT_STEPS
			local function at(key: number): number
				return catmull(p0[key], p1[key], p2[key], p3[key], t)
			end
			local top, bottom = at(2), at(3)
			table.insert(rings, { x = at(1), top = math.max(top, bottom), bottom = bottom, width = math.max(at(4), 0) })
		end
	end
	local last = stations[count]
	table.insert(rings, { x = last[1], top = last[2], bottom = last[3], width = last[4] })
	return rings
end

-- Loft rings hugging the outside of a set of axis-aligned ellipsoids, snout
-- first. `extra` ({ front, back, at }) adds a shape the spheres don't describe
-- (the eel's waving tube): at(x) returns its top, bottom and half width. Rings crowd towards both tips so they close smoothly,
-- and creases where two spheres meet are filled so the skin reads as one body.
local function envelopeRings(sections: { Ellipsoid }, extra: any?): { Ring }
	local front, back = -math.huge, math.huge
	for _, section in sections do
		front = math.max(front, section.c.X + section.h.X)
		back = math.min(back, section.c.X - section.h.X)
	end
	if extra then
		front, back = math.max(front, extra.front), math.min(back, extra.back)
	end
	local span = front - back
	local count = math.clamp(math.ceil(span * 100), 40, 160)
	local rings: { Ring } = {}
	for index = 1, count - 1 do
		local x = front - span * (1 - math.cos(math.pi * index / count)) / 2
		local top, bottom, width = -math.huge, math.huge, 0
		for _, section in sections do
			local dx = (x - section.c.X) / section.h.X
			if dx * dx < 1 then
				local s = math.sqrt(1 - dx * dx)
				top = math.max(top, section.c.Y + section.h.Y * s)
				bottom = math.min(bottom, section.c.Y - section.h.Y * s)
				width = math.max(width, math.abs(section.c.Z) + section.h.Z * s)
			end
		end
		if extra then
			local t, b, w = extra.at(x)
			if t then
				top, bottom, width = math.max(top, t), math.min(bottom, b :: number), math.max(width, w :: number)
			end
		end
		if top > bottom then
			table.insert(rings, { x = x, top = top, bottom = bottom, width = width })
		end
	end
	for _ = 1, 3 do
		local smoothed = {}
		for index, ring in rings do
			local a, c = rings[index - 1], rings[index + 1]
			if a and c then
				smoothed[index] = {
					x = ring.x,
					top = math.max(ring.top, (a.top + 2 * ring.top + c.top) / 4),
					bottom = math.min(ring.bottom, (a.bottom + 2 * ring.bottom + c.bottom) / 4),
					width = math.max(ring.width, (a.width + 2 * ring.width + c.width) / 4),
				}
			else
				smoothed[index] = ring
			end
		end
		rings = smoothed
	end
	return rings
end

-- Replaces sphere bodies with one smooth skin. EditableMesh never replicates,
-- so the spheres are still built: servers and the wiki see them, and
-- FishMeshes hides them (`parts`) on each client once the skin exists. The
-- `swatches` (Side, Back, Belly) lend the skin their colours, so mutations
-- that repaint parts repaint the skin too. Markings, eyes and fins placed
-- afterwards follow the skin's surface. `mode` "flat" paints the +Z face from
-- Side and the -Z face from Belly (flatfish) instead of back-to-belly bands.
function Builder:smoothSkin(rings: { Ring }, parts: { BasePart }, swatches, sections: { Ellipsoid }?, mode: string?)
	self.skinDone, self.skinOpen = true, nil
	if #rings < 2 or not swatches or not swatches.Side then
		return
	end
	for _, section in sections or {} do
		section.skin = true
	end
	for _, part in parts do
		part:SetAttribute("LoftFallback", true)
	end
	for name, part in swatches do
		part:SetAttribute("LoftSwatch", name)
	end
	self.loft = rings
	local anchor = swatches.Side
	lofts[self.model.Name] = { rings = rings, anchorPosition = anchor.Position, anchorSize = anchor.Size, mode = mode }
	self.model:SetAttribute("LoftFish", self.model.Name)
	self.model:AddTag(FishModels.LOFT_TAG)
end

-- Opens a smooth skin: b:layered calls in these `colors` join it until the
-- first surface query (or b:finishSkin()), which lofts it round their spheres.
function Builder:beginSkin(colors)
	if not self.skinDone and not self.skinOpen then
		self.skinOpen = { colors = colors, parts = {}, sections = {} }
	end
end

-- Ring helpers for custom bodies (species modules can't reach the locals):
-- b:smoothSkin(b:envelope({ section, ... }), parts, { Side = p, Back = p, Belly = p }, sections)
-- where sections are the second values b:body returns.
function Builder:envelope(sections: { Ellipsoid }, extra: any?): { Ring }
	return envelopeRings(sections, extra)
end

function Builder:stations(stations: { { number } }): { Ring }
	return stationRings(stations)
end

-- Closes the fishBody skin opened earlier: called on the first surface query
-- and after every builder, so later layers stay separate spheres.
function Builder:finishSkin(stations: { { number } }?)
	local open = self.skinOpen
	if not open or self.skinDone then
		return
	end
	local rings = if stations then stationRings(stations) else envelopeRings(open.sections)
	self:smoothSkin(rings, open.parts, open.swatches, open.sections)
end

-- fishBody with a hand-tuned profile ({ x, top, bottom, half width }
-- stations, snout first) instead of the spheres' envelope.
function Builder:loftBody(stations: { { number } }, colors, depth: number, width: number, headDrop: number?)
	self:fishBody(depth, width, colors, headDrop)
	self:finishSkin(stations)
end

function Builder:face(eyeX: number, eyeY: number, eyeSize: number, iris: Color3, line: Color3)
	self:eye(eyeX, eyeY, eyeSize, iris)
	local mouthY = self:bottom(0.46) * 0.35
	self:stroke({ v2(0.47, mouthY + 0.004), v2(0.41, mouthY - 0.012) }, 0.008, rgb(40, 32, 30))
	self:marks(0.455, eyeY + eyeSize * 0.4, 0.008, 0.008, rgb(30, 28, 26))
	local top, bottom = self:top(0.24) * 0.7, self:bottom(0.24) * 0.75
	self:stroke({ v2(0.255, top), v2(0.232, top * 0.35), v2(0.232, bottom * 0.35), v2(0.255, bottom) }, 0.007, line)
end

function Builder:forkTail(spread: number, notch: number, color: Color3, transparency: number?)
	local stalk = self:top(-0.36)
	local a, b = v2(-0.35, stalk * 0.85), v2(-0.5, spread)
	local c, d, e = v2(-0.5 + notch, 0), v2(-0.5, -spread), v2(-0.35, -stalk * 0.85)
	self:fin({ a, b, c }, color, transparency)
	self:fin({ a, c, e }, color, transparency)
	self:fin({ c, d, e }, color, transparency)
	self:rays(
		v2(-0.36, 0),
		{ v2(-0.49, spread * 0.92), v2(-0.47, spread * 0.45), v2(-0.47, -spread * 0.45), v2(-0.49, -spread * 0.92) },
		color:Lerp(rgb(0, 0, 0), 0.25)
	)
end

function Builder:roundTail(radius: number, color: Color3, transparency: number?)
	local stalk = self:top(-0.36)
	local points = { v2(-0.35, 0), v2(-0.35, stalk * 0.9) }
	for index = 0, 6 do
		local angle = math.rad(110 + index * 140 / 6)
		table.insert(points, v2(-0.38 + math.cos(angle) * radius, math.sin(angle) * radius * 1.1))
	end
	table.insert(points, v2(-0.35, -stalk * 0.9))
	self:fin(points, color, transparency)
	local tips = {}
	for index = 1, 5 do
		local angle = math.rad(120 + index * 120 / 6)
		table.insert(tips, v2(-0.38 + math.cos(angle) * radius * 0.92, math.sin(angle) * radius))
	end
	self:rays(v2(-0.35, 0), tips, color:Lerp(rgb(0, 0, 0), 0.25))
end

-- A fin whose base hugs the back (or belly) between two X positions.
function Builder:edgeFin(
	fromX: number,
	toX: number,
	heights: { number },
	color: Color3,
	below: boolean?,
	transparency: number?
)
	local sign = if below then -1 else 1
	local function edge(x: number): number
		return (if below then self:bottom(x) else self:top(x)) - sign * 0.008
	end
	local points = { v2(fromX, edge(fromX)) }
	for index, height in heights do
		local x = fromX + (toX - fromX) * (index / (#heights + 1))
		table.insert(points, v2(x, edge(x) + sign * height))
	end
	table.insert(points, v2(toX, edge(toX)))
	-- Fan from the base midpoint so spiny, uneven edges still triangulate.
	local middle = (fromX + toX) / 2
	local base = v2(middle, edge(middle) - sign * 0.004)
	table.insert(points, 1, base)
	self:fin(points, color, transparency)
	return points
end

-- Solid crescent (lunate) tail of fast pelagic fish: two sickle lobes with a
-- convex leading edge and a concave trailing edge meeting at the tail stalk.
function Builder:lunateTail(span: number, color: Color3, transparency: number?, lower: number?)
	local stalk = self:top(-0.36)
	local function bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: number): Vector2
		return p0 * (1 - t) ^ 2 + p1 * 2 * t * (1 - t) + p2 * t * t
	end
	for _, sign in { 1, -1 } do
		local reach = span * (if sign < 0 then lower or 1 else 1)
		local tip = v2(-0.5, sign * reach)
		local lead0, lead1 = v2(-0.345, sign * stalk * 0.85), v2(-0.385, sign * reach * 0.72)
		local trail0, trail1 = v2(-0.39, 0), v2(-0.415, sign * reach * 0.48)
		local previousLead, previousTrail = lead0, trail0
		for step = 1, 4 do
			local t = step / 4
			local lead, trail = bezier(lead0, lead1, tip, t), bezier(trail0, trail1, tip, t)
			self:fin({ previousLead, lead, trail, previousTrail }, color, transparency)
			previousLead, previousTrail = lead, trail
		end
	end
	self:fin({ v2(-0.345, stalk * 0.85), v2(-0.39, 0), v2(-0.345, -stalk * 0.85) }, color, transparency)
end

-- Species builders live with their data in Shared.Fish (see Shared.FishSpecies);
-- below are the body-family helpers several of them share, handed over as `kit`.
local builders = {}

-- Carp cross-sections for the smooth skin: { x, top, bottom, half width }.
local CARP_STATIONS = {
	{ 0.505, -0.018, -0.048, 0.012 },
	{ 0.495, 0.018, -0.072, 0.03 },
	{ 0.465, 0.05, -0.095, 0.047 },
	{ 0.41, 0.08, -0.115, 0.06 },
	{ 0.33, 0.11, -0.13, 0.07 },
	{ 0.22, 0.14, -0.142, 0.079 },
	{ 0.1, 0.152, -0.142, 0.081 },
	{ -0.02, 0.142, -0.13, 0.076 },
	{ -0.13, 0.112, -0.105, 0.063 },
	{ -0.22, 0.08, -0.076, 0.047 },
	{ -0.29, 0.052, -0.05, 0.03 },
	{ -0.34, 0.04, -0.039, 0.019 },
	{ -0.375, 0.036, -0.035, 0.012 },
}

-- Deep-bodied carp with scale rows, barbels and fleshy lips; `p` is the palette.
-- The smooth skin follows `p.stations` or the default carp profile.
local function carp(b, p)
	local colors, fin = p.colors, p.fin
	b:loftBody(p.stations or CARP_STATIONS, colors, 0.29, 0.16, 0.08)
	b:edgeFin(0.11, -0.22, { 0.095, 0.07, 0.05, 0.045, 0.04, 0.035 }, fin, false, 0.05)
	b:edgeFin(-0.12, -0.22, { 0.07, 0.05 }, fin, true)
	b:edgeFin(0.02, -0.06, { 0.06, 0.05 }, fin, true)
	b:forkTail(0.15, 0.05, fin)
	b:pectoral(0.2, -0.08, 0.1, 0.04, fin)
	-- Scale discs belong to the sphere body, where they hide its seams, so they
	-- are laid on its spheres and hidden with it. On the smooth skin they read
	-- as studs; its back-to-belly bands carry the colour instead.
	local loft = b.loft
	local existing = {}
	for _, item in b.model:GetChildren() do
		existing[item] = true
	end
	b.loft = nil
	local row = 0
	for y = -0.1, 0.105, 0.04 do
		row += 1
		for x = 0.2 - (row % 2) * 0.022, -0.32, -0.045 do
			b:marks(x, y, 0.036, 0.03, if (row + math.floor(x * 40)) % 3 == 0 then p.scale else p.scaleAlt)
		end
	end
	b.loft = loft
	if loft then
		for _, item in b.model:GetChildren() do
			if not existing[item] then
				item:SetAttribute("LoftFallback", true)
			end
		end
	end
	for _, side in { 1, -1 } do
		b:limb(
			Vector3.new(0.47, -0.045, side * 0.02),
			Vector3.new(0.45, -0.1, side * 0.035),
			0.008,
			p.barbel,
			"Barbel"
		)
		b:limb(
			Vector3.new(0.485, -0.03, side * 0.015),
			Vector3.new(0.52, -0.06, side * 0.03),
			0.006,
			p.barbel,
			"Barbel"
		)
	end
	b:ellipsoid("Lips", CFrame.new(0.5, -0.035, 0), Vector3.new(0.04, 0.035, 0.055), p.lips)
	b:face(0.37, 0.01, 0.036, p.iris, p.line)
end

-- Smooth eel tube along a gently waving spine with continuous dorsal and anal
-- fin ribbons meeting at the pointed tail; `p` is the palette.
local function eel(b, p)
	local back, side, belly = p.back, p.side, p.belly
	local count = 18
	local spine = {}
	for index = 0, count do
		local t = index / count
		table.insert(spine, Vector3.new(0.5 - t, 0.035 * math.sin(t * math.pi * 2.2), 0))
	end
	local function radius(t: number): number
		return 0.058 - 0.04 * t ^ 1.25
	end
	local finTop, finBottom = {}, {}
	local tube, firstBelly = {}, nil
	for index = 1, count do
		local a, c = spine[index], spine[index + 1]
		local t = (index - 0.5) / count
		local direction = (c - a).Unit
		local up = (Vector3.yAxis - direction * direction.Y).Unit
		local middle = (a + c) / 2
		local frame = CFrame.fromMatrix(middle, direction, up)
		-- Long overlap keeps the waists between sections shallow, so the body
		-- reads as one smooth tube instead of a chain of beads.
		local length, h = (c - a).Magnitude * (if index <= 2 then 2 else 3.4), radius(t)
		table.insert(tube, b:ellipsoid("Body", frame, Vector3.new(length, h * 2, h * 1.7), side))
		table.insert(tube, b:ellipsoid("BodyBack", frame + up * h * 0.14, Vector3.new(length * 0.98, h * 1.7, h * 1.72), back))
		local bellyPart = b:ellipsoid("BodyBelly", frame - up * h * 0.16, Vector3.new(length * 0.97, h * 1.6, h * 1.71), belly)
		table.insert(tube, bellyPart)
		firstBelly = firstBelly or bellyPart
		if t > (p.dorsalFrom or 0.22) then
			table.insert(finTop, { middle + up * h * 0.75, middle + up * (h + 0.03 * (1 - t * 0.4)) })
		end
		if t > 0.42 then
			table.insert(finBottom, { middle - up * h * 0.75, middle - up * (h + 0.026 * (1 - t * 0.4)) })
		end
	end
	local finColor = p.fin
	for _, ribbon in { finTop, finBottom } do
		for index = 1, #ribbon - 1 do
			local a, c = ribbon[index], ribbon[index + 1]
			b:fin({ a[1], a[2], c[2], c[1] }, finColor, 0.15)
		end
		local last = ribbon[#ribbon]
		b:fin({ last[1], last[2], spine[#spine] - Vector3.new(0.02, 0, 0) }, finColor, 0.15)
	end
	local headY = spine[1].Y
	-- Head no wider than the body, tapering to a pointed snout.
	local head, headSection = b:body("Head", Vector3.new(0.43, headY, 0), Vector3.new(0.17, 0.1, 0.088), side)
	local headBack, headBackSection =
		b:body("HeadBack", Vector3.new(0.43, headY + 0.012, 0), Vector3.new(0.165, 0.085, 0.09), back)
	local snout, snoutSection = b:body("Snout", Vector3.new(0.5, headY - 0.004, 0), Vector3.new(0.08, 0.05, 0.052), back)
	-- One smooth skin over the head and the waving tube (whose sections are
	-- angled, so the tube is described directly), narrowing to the tail tip.
	local heads = { headSection, headBackSection, snoutSection }
	local rings = envelopeRings(heads, {
		front = 0.5,
		back = -0.52,
		at = function(x: number)
			local t = 0.5 - x
			if t < 0 then
				return nil
			end
			local h = radius(math.min(t, 1)) * math.sqrt(math.clamp((1.02 - t) / 0.06, 0, 1))
			local y = 0.035 * math.sin(t * math.pi * 2.2)
			return y + h, y - h, h * 0.86
		end,
	})
	table.insert(tube, head)
	table.insert(tube, headBack)
	table.insert(tube, snout)
	b:smoothSkin(rings, tube, { Side = head, Back = headBack, Belly = firstBelly }, heads)
	b:eye(0.475, headY + 0.016, p.eyeSize or 0.026, p.iris)
	b:stroke({ v2(0.51, headY - 0.008), v2(0.455, headY - 0.022) }, 0.007, rgb(30, 30, 30))
	b:marks(0.385, headY - 0.005, 0.012, 0.03, back:Lerp(rgb(0, 0, 0), 0.35))
	b:pectoral(0.38, headY - 0.01, 0.05, 0.03, finColor, 0.1)
end

-- Flatfish lying on its blind side with both eyes up; `p` is the palette and
-- p.ocelli (optional) are the eye-spot positions.
local function flatfish(b, p)
	local brown, under = p.top, p.under
	local disc, discSection = b:body("Disc", Vector3.new(0.02, 0, 0), Vector3.new(0.74, 0.46, 0.06), brown)
	local underside = b:ellipsoid("Underside", CFrame.new(0.02, 0, -0.008), Vector3.new(0.735, 0.455, 0.056), under)
	local bump, bumpSection = b:body("HeadBump", Vector3.new(0.33, 0.03, 0), Vector3.new(0.17, 0.18, 0.05), brown)
	local stalk = b:ellipsoid("TailStalk", CFrame.new(-0.34, 0, 0), Vector3.new(0.09, 0.1, 0.04), brown)
	-- Smooth skin: eyed (+Z) face from the Disc, blind face from the Underside.
	local stalkSection = { c = Vector3.new(-0.34, 0, 0), h = Vector3.new(0.045, 0.05, 0.02) }
	b:smoothSkin(
		envelopeRings({ discSection, bumpSection, stalkSection }),
		{ disc, underside, bump, stalk },
		{ Side = disc, Belly = underside },
		{ discSection, bumpSection },
		"flat"
	)
	local finColor, rayColor = p.fin, p.ray
	local function edge(x: number, sign: number): number
		local dx = (x - 0.02) / 0.37
		return sign * 0.23 * math.sqrt(math.max(0, 1 - dx * dx))
	end
	for _, spec in { { 0.33, -0.3, 1, 0.07 }, { 0.17, -0.3, -1, 0.06 } } do
		local from, to, sign, height = spec[1], spec[2], spec[3], spec[4]
		local previousInner, previousOuter
		for index = 0, 12 do
			local x = from + (to - from) * index / 12
			local reach = height * math.sin(math.pi * (0.15 + 0.85 * index / 12)) + 0.012
			local inner = Vector3.new(x, edge(x, sign) * 0.9, 0)
			local outer = Vector3.new(x, edge(x, sign) + sign * reach, 0)
			if previousInner then
				b:fin({ previousInner, previousOuter, outer, inner }, finColor, 0.08)
			end
			if index % 2 == 1 then
				b:limb(inner, outer, 0.005, rayColor, "FinRay")
			end
			previousInner, previousOuter = inner, outer
		end
	end
	b:roundTail(0.14, finColor, 0.08)
	for _ = 1, 44 do
		local x, y = b.random(-0.3, 0.34), b.random(-0.2, 0.2)
		local size = b.random(0.02, 0.05)
		b:mark(
			x,
			y,
			1,
			size,
			size * b.random(0.7, 1),
			if b.random(0, 1) > 0.5 then p.light else p.dark
		)
	end
	for _, spot in p.ocelli or {} do
		b:mark(spot.X, spot.Y, 1, 0.065, 0.065, p.ring)
		b:mark(spot.X, spot.Y, 1, 0.042, 0.042, p.center, nil, 0.001)
	end
	for _, eye in { v2(0.35, 0.06), v2(0.3, 0.125) } do
		local position, normal = b:surface(eye.X, eye.Y, 1)
		if position and normal then
			local center = position + normal * 0.01
			b:ellipsoid("EyeBulge", CFrame.new(center), Vector3.new(0.045, 0.04, 0.035), brown)
			b:ellipsoid("Eye", CFrame.new(center + normal * 0.012), Vector3.new(0.032, 0.03, 0.02), p.iris)
			b:ellipsoid("Pupil", CFrame.new(center + normal * 0.018), Vector3.new(0.02, 0.012, 0.014), rgb(14, 14, 14))
		end
	end
	b:mark(0.41, -0.03, 1, 0.07, 0.012, p.mouth, v2(-1, -1.2))
	b.model:SetAttribute("ViewDirection", Vector3.new(0.15, 0.3, 1))
end

-- Sturgeons share a bony-plated body, a shark-like upper tail lobe and barbels
-- under a pointed snout; `p` is the palette and p.snout the snout size.
local function sturgeon(b, p)
	local colors, fin, scute = p.colors, p.fin, p.scute
	b:fishBody(0.16, 0.14, colors, 0.04)
	b:layered("Snout", p.snoutAt or Vector3.new(0.46, -0.018, 0), p.snout, colors)
	b:edgeFin(-0.16, -0.26, { 0.05, 0.06, 0.04 }, fin)
	b:edgeFin(-0.14, -0.24, { 0.04, 0.05, 0.03 }, fin, true)
	b:edgeFin(0.02, -0.05, { 0.035 }, fin, true)
	b:pectoral(0.24, -0.05, 0.1, 0.03, fin)
	local stalk = b:top(-0.36)
	local upper, lower = v2(-0.34, stalk * 0.9), v2(-0.34, -stalk * 0.9)
	b:fin({ upper, v2(-0.58, 0.16), v2(-0.55, 0.12), v2(-0.42, 0), lower }, fin)
	b:fin({ lower, v2(-0.44, 0), v2(-0.5, -0.09) }, fin)
	if p.filament then
		b:limb(Vector3.new(-0.56, 0.15, 0), Vector3.new(-0.74, 0.2, 0), 0.006, fin, "Filament")
	end
	for x = 0.21, -0.3, -0.05 do
		b:ellipsoid("GrowthRidge", CFrame.new(x, b:top(x) + 0.002, 0), Vector3.new(0.03, 0.014, 0.02), scute)
		b:marks(x, b:top(x) * 0.45, 0.026, 0.02, scute)
		b:marks(x, b:bottom(x) * 0.4, 0.022, 0.016, scute)
	end
	if p.stripe then
		b:stroke({ v2(0.3, 0.012), v2(0, 0.01), v2(-0.32, 0) }, 0.008, p.stripe)
	end
	local barbelX = p.barbelX or 0.46
	local chin = b:bottom(barbelX)
	for _, z in { -0.022, -0.008, 0.008, 0.022 } do
		b:limb(
			Vector3.new(barbelX, chin + 0.004, z),
			Vector3.new(barbelX - 0.012, chin - 0.05, z * 1.3),
			0.008,
			scute,
			"Barbel"
		)
	end
	b:eye(0.36, 0.02, 0.026, p.iris)
end

-- Trout-family body: adipose fin, spotted flank and an optional coloured band.
local function trout(b, p)
	local fin = p.fin
	b:fishBody(0.21, 0.12, p.colors)
	b:edgeFin(0.07, -0.08, { 0.08, 0.075, 0.06, 0.04 }, fin)
	b:ellipsoid("AdiposeFin", CFrame.new(-0.25, b:top(-0.25) + 0.004, 0), Vector3.new(0.045, 0.028, 0.012), fin)
	b:edgeFin(-0.12, -0.23, { 0.06, 0.05, 0.035 }, fin, true)
	b:edgeFin(0.02, -0.07, { 0.05, 0.045 }, fin, true)
	b:forkTail(0.11, 0.035, fin)
	b:pectoral(0.2, -0.05, 0.1, 0.035, fin)
	if p.band then
		for x = 0.27, -0.31, -0.026 do
			b:marks(x, -0.002, 0.05, 0.05 * (1 - math.abs(x) * 0.9), p.band)
		end
		-- The band narrows onto the gill cover rather than ending in a disc.
		b:marks(0.29, -0.008, 0.085, 0.045, p.band)
	end
	if p.vermiculate then
		-- Tiger trout: worm-like squiggles instead of round spots.
		for _ = 1, 22 do
			local x, y = b.random(-0.3, 0.3), b.random(-0.06, 0.1)
			if y < b:top(x) - 0.02 and y > b:bottom(x) + 0.02 then
				local bend = b.random(-0.03, 0.03)
				b:stroke({ v2(x, y), v2(x - 0.03, y + bend), v2(x - 0.06, y - bend * 0.5) }, 0.012, p.spot)
			end
		end
	else
		b:speckle(p.spots, v2(-0.33, 0.33), v2(-0.06, 0.11), v2(0.01, 0.017), p.spot)
		for _ = 1, 12 do
			b:finSpot(b.random(-0.47, -0.37), b.random(-0.09, 0.09), 0.012, p.spot)
		end
	end
	b:face(0.37, 0.02, 0.045, p.iris, p.line)
end

local function mussel(b, shell, edge)
	-- A narrow hinge grows into a broad, rounded outer end. Overlapping lobes
	-- give the closed shell its asymmetric mussel outline and a raised crown.
	local dark = shell:Lerp(rgb(12, 15, 20), 0.55)
	b:ellipsoid("ShellSeam", CFrame.new(0.02, 0, 0), Vector3.new(0.94, 0.43, 0.09), dark)
	b:body("ShellHinge", Vector3.new(-0.29, -0.035, 0), Vector3.new(0.42, 0.20, 0.20), dark)
	b:body("Shell", Vector3.new(0.04, 0, 0), Vector3.new(0.82, 0.43, 0.30), shell)
	b:body("ShellCrown", Vector3.new(0.16, 0.015, 0), Vector3.new(0.58, 0.47, 0.32), shell)
	-- Fine curved growth lines follow the exposed surface on both valves.
	for ridge = 1, 5 do
		local x = -0.21 + ridge * 0.105
		for step = -3, 3 do
			local y = step * 0.047
			local curveX = x - 0.26 * (y / 0.2) ^ 2
			for _, side in { -1, 1 } do
				local mark = b:mark(curveX, y, side, 0.012, 0.052, edge:Lerp(shell, 0.45))
				if mark then mark.Name = "GrowthRidge" end
			end
		end
	end
	for _, side in { -1, 1 } do
		b:mark(0.13, 0.095, side, 0.30, 0.035, edge:Lerp(shell, 0.4), Vector2.new(1, -0.18))
	end
	b.model:SetAttribute("ViewDirection", Vector3.new(0.2, 0.4, 1))
end
-- One flexible algal sheet from `root` along `heading`. `profile(t)` gives the
-- half-width along the blade; `ruffle` alternates the margin for a wavy edge.
local function algaBlade(b, root: Vector3, heading: Vector3, length: number, profile, color: Color3, ruffle: number, phase: number)
	heading = heading.Unit
	local across = heading:Cross(Vector3.zAxis).Unit
	local segments = 7
	local previousLeft, previousRight
	for segment = 0, segments do
		local t = segment / segments
		local center = root
			+ heading * length * t
			+ across * math.sin(t * math.pi * 2 + phase) * 0.03 * t
			+ Vector3.zAxis * math.sin(t * math.pi * 2.5 + phase) * 0.05 * t
		local width = profile(t) * (1 + (if segment % 2 == 0 then ruffle else -ruffle))
		local offset = across * width + Vector3.zAxis * math.sin(t * math.pi + phase) * width * 0.4
		local left, right = center - offset, center + offset
		if previousLeft then
			for _, points in { { previousLeft, previousRight, right }, { previousLeft, right, left } } do
				local first, second = b:triangle(points[1], points[2], points[3], color)
				for _, part in { first, second } do
					if part then
						part.Name = "SeaweedFrond"
					end
				end
			end
		end
		previousLeft, previousRight = left, right
	end
end

-- Crabs face +X like the fish: eyes and claws at the front, legs splayed out to
-- both sides (Z). The carapace is a shell dome under a darker raised one; `look`
-- sets the colours, the claw and leg proportions and each species' extras.
local function crab(b, look)
	local shell, dark, belly = look.shell, look.dark, look.belly
	local clawColor, legColor = look.clawColor or shell, look.legColor or shell
	local tipColor = look.tipColor or rgb(36, 30, 26)
	local carapace = look.carapace
	local half = carapace / 2
	local domes = {
		{ Vector3.new(0, 0, 0), carapace, shell },
		{ Vector3.new(-0.01, carapace.Y * 0.2, 0), carapace * Vector3.new(0.84, 0.76, 0.84), dark },
	}
	b:body("Carapace", domes[1][1], domes[1][2], domes[1][3])
	b:body("CarapaceBack", domes[2][1], domes[2][2], domes[2][3])
	b:ellipsoid("Underside", CFrame.new(0, -carapace.Y * 0.22, 0), carapace * Vector3.new(0.94, 0.7, 0.94), belly)
	local function height(x: number, z: number): number?
		local best = nil
		for _, dome in domes do
			local h = dome[2] / 2
			local dx, dz = (x - dome[1].X) / h.X, (z - dome[1].Z) / h.Z
			local remaining = 1 - dx * dx - dz * dz
			if remaining > 0 then
				best = math.max(best or -math.huge, dome[1].Y + h.Y * math.sqrt(remaining))
			end
		end
		return best
	end
	-- `angle` 0 is straight ahead, +-pi/2 the widest point of the shell.
	local function rim(angle: number, reach: number): Vector3
		return Vector3.new(math.cos(angle) * half.X * reach, 0, math.sin(angle) * half.Z * reach)
	end

	-- Saw teeth along the front edge, and the blue crab's long lateral spines.
	for _, side in { 1, -1 } do
		for index = 1, look.teeth do
			local angle = side * (0.4 + (index - 1) * 1.0 / math.max(look.teeth - 1, 1))
			b:limb(rim(angle, 0.92), rim(angle, 1.1), 0.03, shell, "Spine")
		end
		if look.lateral then
			local base = rim(side * math.pi / 2 * 0.97, 0.9)
			b:limb(base, base + Vector3.new(-0.01, 0.01, side * (half.Z * 0.12 + look.lateral)), 0.034, shell, "Spine")
		end
		b:ellipsoid("FrontLobe", CFrame.new(rim(side * 0.14, 0.98)), Vector3.new(0.05, 0.035, 0.05), shell)
	end
	b:ellipsoid(
		"Mouth",
		CFrame.new(half.X * 0.86, -half.Y * 0.35, 0),
		Vector3.new(0.05, 0.05, half.Z * 0.45),
		belly:Lerp(dark, 0.35)
	)
	for _, side in { 1, -1 } do
		local root = Vector3.new(half.X * 0.82, half.Y * 0.4, side * half.Z * 0.24)
		local top = root + Vector3.new(0.05, 0.05, side * 0.015)
		b:limb(root, top, 0.024, shell, "EyeStalk")
		b:ellipsoid("Eye", CFrame.new(top), Vector3.one * 0.042, rgb(18, 16, 14))
		b:ellipsoid("EyeGlint", CFrame.new(top + Vector3.new(0.012, 0.014, 0)), Vector3.one * 0.012, rgb(255, 255, 255))
	end

	-- Claws: upper arm, forearm, a palm that turns in across the face and two
	-- slightly parted fingers with dark tips. `offhand` shrinks the left claw.
	for _, side in { 1, -1 } do
		local size = look.claw * (if side == -1 then look.offhand or 1 else 1)
		local inward = Vector3.new(0, 0, -side)
		local shoulder = Vector3.new(half.X * 0.5, -half.Y * 0.3, side * half.Z * 0.62)
		local elbow = shoulder + Vector3.new(0.12, 0.02, side * 0.13) * size
		local wrist = elbow + Vector3.new(0.11, 0.025, -side * 0.035) * size
		b:limb(shoulder, elbow, 0.055 * size, clawColor, "Arm")
		b:limb(elbow, wrist, 0.06 * size, clawColor, "Arm")
		b:ellipsoid("Wrist", CFrame.new(wrist), Vector3.one * 0.07 * size, clawColor)
		local direction = Vector3.new(1, 0.08, -side * 0.55).Unit
		local palmEnd = wrist + direction * 0.15 * size
		b:ellipsoid(
			"Palm",
			CFrame.lookAt((wrist + palmEnd) / 2, palmEnd) * CFrame.Angles(0, math.pi / 2, 0),
			Vector3.new(0.18 * size, 0.1 * size, 0.08 * size),
			clawColor
		)
		for _, finger in { { -0.016, -0.006, 0.008 }, { 0.022, 0.02, -0.016 } } do
			local root = palmEnd + Vector3.new(0, finger[1], 0) * size
			local middle = root + (direction * 0.06 + Vector3.new(0, finger[2], 0)) * size
			local tip = middle + (direction * 0.045 + inward * 0.02 + Vector3.new(0, finger[3], 0)) * size
			b:limb(root, middle, 0.034 * size, clawColor, "Finger")
			b:limb(middle, tip, 0.022 * size, tipColor, "FingerTip")
		end
		if look.armSpines then
			for _, t in { 0.3, 0.7 } do
				b:ellipsoid(
					"Spine",
					CFrame.new(shoulder:Lerp(elbow, t) + Vector3.new(0, 0.03 * size, 0)),
					Vector3.new(0.016, 0.034, 0.016),
					look.spineColor or shell
				)
			end
		end
	end

	-- Walking legs, front pairs leaning forward and back pairs back. A leg is
	-- thigh, shin and a pointed dactyl, knees raised above the shell rim.
	local legs = look.legs
	for _, side in { 1, -1 } do
		for index, lean in legs.lean do
			local x = half.X * (0.32 - (index - 1) * 0.3)
			local root = Vector3.new(x, -half.Y * 0.35, side * half.Z * math.sqrt(1 - (x / half.X) ^ 2) * 0.85)
			local out = Vector3.new(lean, 0, side).Unit
			local knee = root + out * legs.thigh + Vector3.new(0, legs.lift, 0)
			local foot = knee + out * legs.shin + Vector3.new(0, -legs.drop, 0)
			local ankle = knee:Lerp(foot, 0.65)
			b:limb(root, knee, legs.width, legColor, "Leg")
			b:limb(knee, ankle, legs.width * 0.8, legColor, "Leg")
			b:limb(ankle, foot, legs.width * 0.55, if legs.paddle then legColor else tipColor, "Leg")
			if legs.paddle and index == #legs.lean then
				b:ellipsoid(
					"Paddle",
					CFrame.lookAt((ankle + foot) / 2, foot) * CFrame.Angles(0, math.pi / 2, 0),
					Vector3.new(0.1, 0.014, 0.065),
					legColor
				)
			end
			if look.armSpines then
				for _, t in { 0.35, 0.75 } do
					b:ellipsoid(
						"Spine",
						CFrame.new(root:Lerp(knee, t) + Vector3.new(0, legs.width * 0.5, 0)),
						Vector3.new(0.014, 0.03, 0.014),
						look.spineColor or shell
					)
				end
			end
		end
	end

	-- Mottling, or the king crab's spiny shell, scattered over the top dome.
	for _, scatter in { look.spots or false, look.knobs or false } do
		for _ = 1, if scatter then scatter.count else 0 do
			local x, z = b.random(-half.X, half.X), b.random(-half.Z, half.Z)
			local y = height(x, z)
			if not y or (x / half.X) ^ 2 + (z / half.Z) ^ 2 > 0.8 then
				continue
			end
			local size = b.random(scatter.size.X, scatter.size.Y)
			if scatter == look.knobs then
				b:ellipsoid("Spine", CFrame.new(x, y + size * 0.3, z), Vector3.new(size, size * 2, size), scatter.color)
			else
				b:ellipsoid("Marking", CFrame.new(x, y + 0.002, z), Vector3.new(size, 0.004, size * 0.8), scatter.color)
			end
		end
	end
	b.model:SetAttribute("ViewDirection", Vector3.new(0.9, 0.85, 0.35))
end

-- Nescio Fih cross-sections, snout first: { x, top, bottom, half width }. A
-- pointed shark's head on a thin neck, a hunched body, broad hips for the legs
-- and a long tail narrowing into the paddle.
local NESCIO_STATIONS = {
	{ 0.502, -0.04, -0.046, 0.003 },
	{ 0.494, -0.026, -0.054, 0.01 },
	{ 0.478, -0.01, -0.061, 0.017 },
	{ 0.455, 0.006, -0.066, 0.023 },
	{ 0.425, 0.022, -0.069, 0.028 },
	{ 0.395, 0.034, -0.069, 0.032 },
	{ 0.365, 0.04, -0.065, 0.034 },
	{ 0.335, 0.041, -0.057, 0.033 },
	{ 0.305, 0.04, -0.048, 0.03 },
	{ 0.275, 0.047, -0.049, 0.032 },
	{ 0.235, 0.06, -0.056, 0.039 },
	{ 0.185, 0.075, -0.063, 0.046 },
	{ 0.125, 0.086, -0.068, 0.051 },
	{ 0.065, 0.09, -0.07, 0.053 },
	{ 0.005, 0.085, -0.07, 0.054 },
	{ -0.045, 0.074, -0.066, 0.056 },
	{ -0.095, 0.06, -0.057, 0.051 },
	{ -0.145, 0.044, -0.045, 0.041 },
	{ -0.2, 0.031, -0.036, 0.031 },
	{ -0.26, 0.021, -0.029, 0.023 },
	{ -0.32, 0.013, -0.023, 0.016 },
	{ -0.38, 0.007, -0.019, 0.011 },
	{ -0.43, 0.002, -0.016, 0.007 },
	{ -0.47, -0.003, -0.013, 0.0035 },
}

-- A smooth tapered tube through `points` (fish lengths): long overlapping
-- ellipsoids along a Catmull-Rom curve, the radius running through `radii`
-- (one per point). Each piece is appended to `samples` (for hair) when given.
local function fleshTube(b, points: { Vector3 }, radii: { number }, color: Color3, name: string, samples: { any }?)
	local count = #points
	local path = {}
	for index = 1, count - 1 do
		local p0, p1 = points[math.max(index - 1, 1)], points[index]
		local p2, p3 = points[index + 1], points[math.min(index + 2, count)]
		local thinnest = math.min(radii[index], radii[index + 1])
		local steps = math.max(2, math.ceil((p2 - p1).Magnitude / math.max(thinnest * 0.7, 0.008)))
		for step = 0, steps - 1 do
			local t = step / steps
			table.insert(path, {
				Vector3.new(
					catmull(p0.X, p1.X, p2.X, p3.X, t),
					catmull(p0.Y, p1.Y, p2.Y, p3.Y, t),
					catmull(p0.Z, p1.Z, p2.Z, p3.Z, t)
				),
				radii[index] + (radii[index + 1] - radii[index]) * t,
			})
		end
	end
	table.insert(path, { points[count], radii[count] })
	for index = 1, #path - 1 do
		local a, c = path[index], path[index + 1]
		local delta = c[1] - a[1]
		local length = delta.Magnitude
		if length > 1e-5 then
			local radius = (a[2] + c[2]) / 2
			local middle = (a[1] + c[1]) / 2
			local up = if math.abs(delta.Unit.Y) > 0.98 then Vector3.xAxis else Vector3.yAxis
			local frame = CFrame.lookAt(middle, c[1], up) * CFrame.Angles(0, math.pi / 2, 0)
			b:ellipsoid(name, frame, Vector3.new(length * 3.2, radius * 2, radius * 2), color)
			if samples then
				table.insert(samples, { point = middle, radius = radius, along = delta.Unit })
			end
		end
	end
	b:ellipsoid(name, CFrame.new(points[1]), Vector3.one * radii[1] * 2, color)
	b:ellipsoid(name, CFrame.new(points[count]), Vector3.one * radii[count] * 2, color)
end

-- The Nescio Fih: a pale, blotchy thing with a pointed shark's head, a hunched
-- body, two frog-like hind legs folded under it and a long paddle tail.
-- `p.hairy` grows a coat of brown hair over it (the Hairy Nescio Fih).
local function nescio(b, p)
	local colors = p.colors or { back = rgb(232, 200, 186), side = rgb(242, 216, 202), belly = rgb(248, 230, 220) }
	local flesh, joint = p.flesh or rgb(240, 212, 198), rgb(237, 196, 182)
	local fold, blush = rgb(220, 170, 156), rgb(226, 160, 146)
	-- Sphere stand-ins for servers and clients without EditableMesh; the
	-- smooth skin follows NESCIO_STATIONS on top of them.
	b:beginSkin(colors)
	b:layered("Chest", Vector3.new(0.12, 0.01, 0), Vector3.new(0.32, 0.158, 0.106), colors)
	b:layered("Head", Vector3.new(0.41, -0.016, 0), Vector3.new(0.17, 0.104, 0.066), colors)
	b:layered("Snout", Vector3.new(0.47, -0.034, 0), Vector3.new(0.07, 0.046, 0.032), colors)
	b:layered("Neck", Vector3.new(0.3, -0.004, 0), Vector3.new(0.1, 0.088, 0.062), colors)
	b:layered("Hips", Vector3.new(-0.05, 0.004, 0), Vector3.new(0.17, 0.138, 0.112), colors)
	b:layered("Rear", Vector3.new(-0.19, -0.003, 0), Vector3.new(0.18, 0.07, 0.064), colors)
	b:layered("TailStalk", Vector3.new(-0.33, -0.006, 0), Vector3.new(0.17, 0.032, 0.028), colors)
	b:layered("TailTip", Vector3.new(-0.43, -0.008, 0), Vector3.new(0.09, 0.018, 0.013), colors)
	b:finishSkin(NESCIO_STATIONS)

	-- Legs: a muscular haunch, thigh forward to the knee, shin back to the
	-- heel, a long foot and four splayed toes with pads and pale nails.
	local legSamples = {}
	local nail = rgb(226, 206, 196)
	for _, s in { 1, -1 } do
		local hip = Vector3.new(-0.04, -0.02, s * 0.04)
		local knee = Vector3.new(0.06, -0.1, s * 0.105)
		local ankle = Vector3.new(-0.06, -0.14, s * 0.11)
		local ball = Vector3.new(0.025, -0.162, s * 0.114)
		local haunch = CFrame.new(-0.015, -0.04, s * 0.05) * CFrame.Angles(0, 0, math.rad(-32))
		b:ellipsoid("Haunch", haunch, Vector3.new(0.12, 0.08, 0.06), flesh)
		local thighMid, shinMid = Vector3.new(0.005, -0.07, s * 0.085), Vector3.new(0.005, -0.122, s * 0.11)
		fleshTube(b, { hip, thighMid, knee }, { 0.04, 0.032, 0.02 }, flesh, "Thigh", legSamples)
		fleshTube(b, { knee, shinMid, ankle }, { 0.019, 0.015, 0.011 }, flesh, "Shin", legSamples)
		fleshTube(b, { ankle, Vector3.new(-0.02, -0.156, s * 0.112), ball }, { 0.012, 0.0095, 0.009 }, flesh, "Foot")
		local kneeCap = knee + Vector3.new(0.004, 0.001, s * 0.002)
		b:ellipsoid("Knee", CFrame.new(kneeCap), Vector3.new(0.042, 0.038, 0.038), joint)
		b:ellipsoid("Heel", CFrame.new(ankle + Vector3.new(-0.006, -0.002, 0)), Vector3.new(0.03, 0.027, 0.025), joint)
		for index, spread in { -0.46, -0.15, 0.15, 0.46 } do
			local yaw = spread * s
			local direction = Vector3.new(math.cos(yaw), -0.08, math.sin(yaw)).Unit
			local length = ({ 0.036, 0.048, 0.05, 0.04 })[index]
			local base = ball + direction * 0.004
			local middle = base + direction * length * 0.5 + Vector3.new(0, 0.002, 0)
			local tip = base + direction * length
			fleshTube(b, { base, middle, tip }, { 0.0066, 0.0054, 0.0046 }, flesh, "Toe")
			b:ellipsoid("Knuckle", CFrame.new(middle), Vector3.one * 0.0124, joint)
			b:ellipsoid("ToePad", CFrame.new(tip + Vector3.new(0, -0.001, 0)), Vector3.new(0.013, 0.0105, 0.012), joint)
			local nailAt = tip + direction * 0.002 + Vector3.new(0, 0.0036, 0)
			local nailFrame = CFrame.lookAt(nailAt, tip + direction, Vector3.yAxis)
			b:ellipsoid("Nail", nailFrame * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(0.008, 0.0028, 0.0066), nail)
		end
	end

	-- Small fleshy flaps where a fish keeps its pectoral fins.
	b:pectoral(0.215, -0.03, 0.055, 0.024, flesh, 0.05)

	-- The paddle: a leaf-shaped fin wrapping the end of the tail, with rays.
	local paddle, ray = rgb(236, 198, 184), rgb(214, 168, 154)
	local function base(x: number): (number, number)
		if x < -0.462 then
			return -0.008, -0.008
		end
		return b:top(x) - 0.003, b:bottom(x) + 0.003
	end
	local tip = v2(-0.502, -0.008)
	for _, upper in { true, false } do
		local strip = {}
		for index = 0, 8 do
			local x = -0.27 - index * (0.2 / 8)
			local t = (-0.27 - x) / 0.232
			local height = 0.032 * math.sin(math.pi * t ^ 1.4) * (if upper then 1 else 0.82)
			local top, bottom = base(x)
			local rim = if upper then top + height else bottom - height
			table.insert(strip, { v2(x, if upper then top else bottom), v2(x, rim) })
		end
		for index = 1, #strip - 1 do
			local a, c = strip[index], strip[index + 1]
			b:fin({ a[1], a[2], c[2], c[1] }, paddle, 0.08)
			if index % 2 == 1 then
				b:limb(Vector3.new(a[1].X, a[1].Y, 0), Vector3.new(a[2].X - 0.006, a[2].Y, 0), 0.003, ray, "FinRay")
			end
		end
		local last = strip[#strip]
		b:fin({ last[1], last[2], tip }, paddle, 0.08)
	end

	-- Face: a small black eye in a pink lid, nostrils, a long thin smile with a
	-- pale lip and three faint gill slits behind the head.
	local eyeX, eyeY = 0.41, 0.012
	local function crease(points: { Vector2 }, width: number, color: Color3)
		for index = 1, #points - 1 do
			local a, c = points[index], points[index + 1]
			local delta = c - a
			local steps = math.max(1, math.ceil(delta.Magnitude / 0.011))
			for step = 0, steps - 1 do
				local point = a + delta * ((step + 0.5) / steps)
				b:marks(point.X, point.Y, delta.Magnitude / steps * 1.35, width, color, delta)
			end
		end
	end
	b:marks(eyeX, eyeY, 0.026, 0.02, blush)
	b:eye(eyeX, eyeY, 0.015, rgb(16, 12, 12))
	crease({ v2(0.434, 0.026), v2(0.41, 0.03), v2(0.39, 0.027) }, 0.003, fold)
	b:marks(0.485, -0.026, 0.0075, 0.0038, rgb(124, 70, 66), v2(1, 0.35))
	local smile = { v2(0.493, -0.044), v2(0.46, -0.054), v2(0.42, -0.056), v2(0.386, -0.052), v2(0.368, -0.044) }
	crease(smile, 0.0035, rgb(150, 82, 78))
	local lip = {}
	for index, point in smile do
		lip[index] = point + v2(0, 0.0045)
	end
	crease(lip, 0.0028, rgb(250, 224, 214))
	crease({ v2(0.47, -0.06), v2(0.43, -0.064), v2(0.395, -0.063) }, 0.0028, fold)
	for index = 0, 2 do
		local x = 0.336 - index * 0.012
		crease({ v2(x + 0.003, 0.016), v2(x - 0.002, -0.006), v2(x + 0.002, -0.028) }, 0.003, rgb(222, 170, 158))
	end
	crease({ v2(0.292, 0.036), v2(0.286, 0), v2(0.29, -0.04) }, 0.004, rgb(228, 174, 162))
	-- Throat and hip creases.
	for index = 0, 2 do
		local y = -0.038 - index * 0.004
		crease({ v2(0.318, y), v2(0.296, y - 0.003), v2(0.272, y - 0.002) }, 0.0024, fold)
	end
	for index = 0, 2 do
		local x = -0.075 - index * 0.012
		crease({ v2(x + 0.004, 0.028), v2(x - 0.004, -0.006), v2(x, -0.042) }, 0.0024, fold)
	end

	-- Bumps of the spine down the back.
	for index = 0, 20 do
		local x = 0.27 - index * 0.028
		local size = math.clamp(b:top(x) / 0.07, 0.3, 1)
		b:ellipsoid(
			"Vertebra",
			CFrame.new(x, b:top(x) - 0.003 * size, 0),
			Vector3.new(0.016, 0.008, 0.013) * size,
			colors.back:Lerp(rgb(160, 110, 100), 0.08)
		)
	end

	-- Soft, uneven blotches: each one a few overlapping skewed discs, faintly
	-- pinker or paler than the skin, plus a scatter of small rosy freckles.
	local function blotches(count: number, low: number, high: number, color: Color3)
		for _ = 1, count do
			local x, y = b.random(-0.3, 0.44), b.random(-0.06, 0.08)
			local size = b.random(low, high)
			for _ = 1, 2 do
				local px, py = x + b.random(-0.5, 0.5) * size, y + b.random(-0.35, 0.35) * size
				if py < b:top(px) - size * 0.35 and py > b:bottom(px) + size * 0.35 then
					local heading = v2(b.random(0.2, 1), b.random(-0.6, 0.6))
					b:marks(px, py, size * b.random(0.7, 1.15), size * b.random(0.4, 0.75), color, heading)
				end
			end
		end
	end
	blotches(11, 0.03, 0.06, rgb(237, 204, 190))
	blotches(7, 0.02, 0.04, rgb(245, 222, 209))
	blotches(8, 0.012, 0.024, rgb(232, 188, 174))
	b:speckle(18, v2(-0.26, 0.36), v2(-0.05, 0.07), v2(0.004, 0.008), blush)

	if p.hairy then
		local shades = { rgb(84, 62, 46), rgb(104, 78, 56), rgb(66, 48, 36), rgb(122, 94, 68), rgb(92, 70, 50) }
		local function shade(): Color3
			return shades[math.clamp(math.floor(b.random(1, #shades + 1)), 1, #shades)]
		end
		local function jitter(amount: number): Vector3
			return Vector3.new(b.random(-amount, amount), b.random(-amount, amount), b.random(-amount, amount))
		end
		-- A flat lock of hair rooted at `root`, lying along `direction` with
		-- its broad side against the skin (`normal`).
		local function lock(root: Vector3, direction: Vector3, normal: Vector3, length: number, width: number)
			local up = normal - direction * normal:Dot(direction)
			up = if up.Magnitude > 1e-4 then up.Unit else Vector3.yAxis
			local center = root + direction * length * 0.42 - up * 0.0015
			b:ellipsoid("Hair", CFrame.fromMatrix(center, direction, up), Vector3.new(length, 0.0045, width), shade())
		end
		local back, down = Vector3.new(-1, 0, 0), Vector3.new(0, -1, 0)
		local x = 0.37
		while x > -0.3 do
			local column = x + b.random(-0.004, 0.004)
			local top, bottom = b:top(column), b:bottom(column)
			local middle, half = (top + bottom) / 2, (top - bottom) / 2
			local head = column > 0.3
			local spacing = if head then 0.016 else 0.021
			local count = math.max(2, math.floor(math.pi * half * 1.15 / spacing))
			-- Short fuzz on the head, a thick shaggy coat over the body.
			local length = if head then 0.024 elseif column > 0.24 then 0.038 else 0.052
			local width = if head then 0.011 else 0.017
			for index = 0, count - 1 do
				local angle = math.pi * (0.05 + 0.92 * (index + b.random(0.15, 0.85)) / count)
				local y = middle + half * math.cos(angle) * 0.97
				local nearEye = (v2(column, y) - v2(eyeX, eyeY)).Magnitude < 0.024
				-- The face stays bare: fuzz only over the crown and behind the jaw.
				local bareFace = head and (column > 0.44 or angle > math.pi * 0.5)
				if not nearEye and not bareFace then
					for _, side in { 1, -1 } do
						local point, normal = b:surface(column, y, side)
						if point and normal then
							local direction = (normal * 0.3 + back * 0.9 + down * 0.25 + jitter(0.15)).Unit
							lock(point, direction, normal, length * b.random(0.8, 1.25), width * b.random(0.8, 1.2))
						end
					end
				end
			end
			x -= if head then 0.016 else 0.02
		end
		-- A long mane drooping along the spine.
		for index = 0, 24 do
			local column = 0.3 - index * 0.024
			local root = Vector3.new(column, b:top(column) - 0.004, b.random(-0.006, 0.006))
			local direction = (Vector3.new(-0.7, 0.45, 0) + jitter(0.2)).Unit
			local length = 0.055 * math.clamp(b:top(column) / 0.06, 0.45, 1.15)
			local bend = root + direction * length * 0.55
			local color = shade()
			b:limb(root, bend, 0.009, color, "Hair")
			b:limb(bend, bend + (direction + Vector3.new(-0.3, -0.75, 0)).Unit * length * 0.5, 0.007, color, "Hair")
		end
		-- Shaggy thighs and shins.
		for _, sample in legSamples do
			local along = sample.along
			local sideways = along:Cross(Vector3.yAxis)
			sideways = if sideways.Magnitude > 1e-4 then sideways.Unit else Vector3.zAxis
			local under = sideways:Cross(along).Unit
			for turn = 0, 2 do
				local angle = turn * 2.1 + b.random(-0.5, 0.5)
				local normal = (sideways * math.cos(angle) + under * math.sin(angle)).Unit
				local root = sample.point + normal * sample.radius * 0.8
				local direction = (normal * 0.35 + Vector3.new(-0.3, -0.8, 0) + jitter(0.2)).Unit
				lock(root, direction, normal, b.random(0.026, 0.038), b.random(0.011, 0.015))
			end
		end
	end
	b.model:SetAttribute("ViewDirection", Vector3.new(0.45, 0.3, 1))
end

local kit = {
	rgb = rgb,
	v2 = v2,
	SCALE = SCALE,
	FIN = FIN,
	carp = carp,
	eel = eel,
	flatfish = flatfish,
	sturgeon = sturgeon,
	trout = trout,
	mussel = mussel,
	algaBlade = algaBlade,
	crab = crab,
	nescio = nescio,
}
for id, fish in FishSpecies do
	local build = fish.Build
	if build then
		builders[id] = function(b)
			build(b, kit)
			b:finishSkin()
		end
	end
end

-- World-axis bounds, so framing never depends on which part came first.
local function measure(model: Model)
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			local frame, half = item.CFrame, item.Size / 2
			local extent = Vector3.new(
				math.abs(frame.RightVector.X) * half.X
					+ math.abs(frame.UpVector.X) * half.Y
					+ math.abs(frame.LookVector.X) * half.Z,
				math.abs(frame.RightVector.Y) * half.X
					+ math.abs(frame.UpVector.Y) * half.Y
					+ math.abs(frame.LookVector.Y) * half.Z,
				math.abs(frame.RightVector.Z) * half.X
					+ math.abs(frame.UpVector.Z) * half.Y
					+ math.abs(frame.LookVector.Z) * half.Z
			)
			low, high = low:Min(frame.Position - extent), high:Max(frame.Position + extent)
		end
	end
	model:SetAttribute("BoundsCenter", (low + high) / 2)
	model:SetAttribute("BoundsSize", high - low)
end

-- Parts a Neon (or Astral) mutation lights up. Eyes and corrupted wounds are
-- never repainted.
local GLOWING = {
	Fin = true,
	FinRay = true,
	FinSpot = true,
	AdiposeFin = true,
	PelvicFin = true,
	Tail = true,
	Filament = true,
	Spine = true,
	Barbel = true,
	Marking = true,
	GrowthRidge = true,
	SeaweedFrond = true,
	Midrib = true,
}
local UNPAINTED = { Eye = true, Pupil = true, EyeGlint = true, Bone = true, BoneKnob = true, Wound = true }
local ASTRAL_GLOW = rgb(170, 70, 255)
-- The client cycles the hue of every part carrying a RainbowHue attribute.
FishModels.RAINBOW_TAG = "RainbowFish"
FishModels.VOID_TAG = "VoidTouchedFish"
FishModels.GLITCH_TAG = "GlitchFish"

-- A builder over an already built, unscaled fish, so corruptions can reuse the
-- surface helpers. Body sections are the axis-aligned ellipsoids.
local function rebuild(model: Model, seed: number)
	local builder = setmetatable({ model = model, sections = {} :: { Ellipsoid }, random = seeded(seed) }, Builder)
	for _, item in model:GetChildren() do
		local mesh = if item:IsA("Part") then item:FindFirstChildOfClass("SpecialMesh") else nil
		if
			mesh
			and mesh.MeshType == Enum.MeshType.Sphere
			and item.CFrame.Rotation == CFrame.identity
			and math.min(item.Size.X, item.Size.Y, item.Size.Z) / SCALE > 0.015
			and not string.find(item.Name, "Fin")
			and not UNPAINTED[item.Name]
		then
			table.insert(builder.sections, { c = item.Position / SCALE, h = item.Size / SCALE / 2 })
		end
	end
	return builder
end

-- The fish's lowest corner and size in fish lengths.
local function bounds(model: Model): (Vector3, Vector3)
	local center, size = model:GetAttribute("BoundsCenter") :: Vector3, model:GetAttribute("BoundsSize") :: Vector3
	return (center - size / 2) / SCALE, size / SCALE
end

local corruptions = {}

-- The tail end, cloned and swung up into a second tail.
function corruptions.Tail(b)
	local low, size = bounds(b.model)
	local hinge = (low.X + size.X * 0.2) * SCALE
	local turn = CFrame.new(hinge, 0, 0) * CFrame.Angles(0, 0, math.rad(-32)) * CFrame.new(-hinge, 0, 0)
	for _, item in b.model:GetChildren() do
		if item:IsA("BasePart") and item.Position.X < hinge and not UNPAINTED[item.Name] then
			local copy = item:Clone()
			copy.CFrame = turn * item.CFrame
			copy.Parent = b.model
		end
	end
end

-- A second, larger eye just behind the first on both flanks.
function corruptions.Eye(b)
	for _, item in b.model:GetChildren() do
		if item.Name == "Eye" and item:IsA("BasePart") and item.Position.Z > 0 then
			local size = item.Size.X / SCALE
			local position = item.Position / SCALE
			b:eye(position.X - size * 1.6, position.Y + size * 0.4, size * 1.15, item.Color)
			return
		end
	end
end

-- An extra pair of fins halfway down the flanks.
function corruptions.Fin(b)
	local low, size = bounds(b.model)
	local color = rgb(150, 142, 108)
	for _, item in b.model:GetChildren() do
		if item.Name == "Fin" and item:IsA("BasePart") then
			color = item.Color
			break
		end
	end
	local x = low.X + size.X * 0.42
	b:pectoral(x, b:top(x) * 0.35, size.X * 0.14, size.Y * 0.18, color)
end

-- A broken bone through a raw wound on the near flank.
function corruptions.Bone(b)
	local low, size = bounds(b.model)
	local x = low.X + size.X * 0.55
	local position, normal = b:surface(x, b:top(x) * 0.25, 1)
	if not position or not normal then
		return
	end
	local wound = b:mark(position.X, position.Y, 1, size.X * 0.07, size.X * 0.05, rgb(120, 26, 34))
	if wound then
		wound.Name = "Wound"
	end
	local tip = position + (normal + Vector3.new(-0.35, 0.3, 0)).Unit * size.X * 0.13
	local bone = rgb(236, 228, 206)
	b:limb(position - normal * 0.01, tip, size.X * 0.022, bone, "Bone")
	local across = normal:Cross(Vector3.zAxis)
	across = (if across.Magnitude > 0.01 then across.Unit else Vector3.yAxis) * size.X * 0.014
	for _, side in { 1, -1 } do
		b:ellipsoid("BoneKnob", CFrame.new(tip + across * side), Vector3.one * size.X * 0.034, bone)
	end
end

local function luminance(color: Color3): number
	return color.R * 0.3 + color.G * 0.59 + color.B * 0.11
end

local function rainbow(item: BasePart, hue: number, saturation: number, value: number)
	item:SetAttribute("RainbowHue", hue)
	item:SetAttribute("RainbowSaturation", saturation)
	item:SetAttribute("RainbowValue", value)
	item.Color = Color3.fromHSV(hue % 1, saturation, value)
end

-- The biggest body part, which carries a mutation's particles and lights.
local function bodyCore(model: Model): BasePart?
	local core: BasePart? = nil
	for _, item in model:GetChildren() do
		if item:IsA("Part") and not UNPAINTED[item.Name] and not GLOWING[item.Name] then
			if not core or item.Size.Magnitude > core.Size.Magnitude then
				core = item
			end
		end
	end
	return core
end

-- Drifting aurora motes and a faint violet glow from the biggest body part.
local function aurora(model: Model)
	local core = bodyCore(model)
	if not core then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "AstralAurora"
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rgb(70, 255, 180)),
		ColorSequenceKeypoint.new(0.5, rgb(80, 160, 255)),
		ColorSequenceKeypoint.new(1, rgb(190, 80, 255)),
	})
	emitter.LightEmission, emitter.LightInfluence = 1, 0
	emitter.Lifetime = NumberRange.new(1.4, 2.6)
	emitter.Rate = 9
	emitter.Speed = NumberRange.new(0.2, 0.6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, 0.5, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-30, 30)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.35, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = core
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range = ASTRAL_GLOW, 0.8, 6
	light.Parent = core
end

-- Supercell catches: a faint storm-sky sheen, slightly see-through fins, and
-- wind streaks and gusts racing from snout to tail. Body sections are axis
-- aligned, so the core part's -X (Left) face points down the fish to its tail.
local WINDY_SHEEN = rgb(196, 222, 236)
local function windswept(model: Model)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and not UNPAINTED[item.Name] then
			item.Color = item.Color:Lerp(WINDY_SHEEN, 0.16)
			if GLOWING[item.Name] and item.Material ~= Enum.Material.Neon then
				item.Transparency = math.max(item.Transparency, 0.12)
			end
		end
	end
	local core = bodyCore(model)
	if not core then
		return
	end
	local streaks = Instance.new("ParticleEmitter")
	streaks.Name = "WindyStreaks"
	streaks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	streaks.Orientation = Enum.ParticleOrientation.VelocityParallel
	streaks.Squash = NumberSequence.new(-4)
	streaks.EmissionDirection = Enum.NormalId.Left
	streaks.Shape = Enum.ParticleEmitterShape.Box
	streaks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	streaks.Color = ColorSequence.new(rgb(232, 244, 250))
	streaks.LightEmission, streaks.LightInfluence = 0.3, 0.4
	streaks.Lifetime = NumberRange.new(0.35, 0.6)
	streaks.Rate = 14
	streaks.Speed = NumberRange.new(5, 8)
	streaks.SpreadAngle = Vector2.new(8, 8)
	streaks.Size = NumberSequence.new(0.05)
	streaks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	streaks.LockedToPart = true
	streaks.Parent = core
	local gusts = Instance.new("ParticleEmitter")
	gusts.Name = "WindyGusts"
	gusts.Texture = "rbxasset://textures/particles/smoke_main.dds"
	gusts.EmissionDirection = Enum.NormalId.Left
	gusts.Color = ColorSequence.new(rgb(225, 238, 245))
	gusts.LightEmission, gusts.LightInfluence = 0.1, 0.8
	gusts.Lifetime = NumberRange.new(0.8, 1.2)
	gusts.Rate = 3
	gusts.Speed = NumberRange.new(2, 3.5)
	gusts.SpreadAngle = Vector2.new(25, 25)
	gusts.Rotation = NumberRange.new(0, 360)
	gusts.RotSpeed = NumberRange.new(-220, 220)
	gusts.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 0.9),
	})
	gusts.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.82),
		NumberSequenceKeypoint.new(1, 1),
	})
	gusts.LockedToPart = true
	gusts.Parent = core
end

-- A rippling lens around a blackened fish. Native black-hole species retain
-- their intrinsic neon organs; other fish and added corruptions turn black.
-- Attachments follow tools, freezer models and scaling without physical parts.
local function voidAura(model: Model)
	local core: BasePart? = nil
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			if item:GetAttribute("BlackHoleAccent") ~= true then
				item.Color = Color3.new(0, 0, 0)
				item.Material = Enum.Material.SmoothPlastic
				item.Transparency = 0
			end
			item.Reflectance = 0
			item:SetAttribute("RainbowHue", nil)
			if not core or item.Size.Magnitude > core.Size.Magnitude then
				core = item
			end
		end
	end
	if not core then
		return
	end
	local center = model:GetAttribute("BoundsCenter") :: Vector3
	local size = model:GetAttribute("BoundsSize") :: Vector3
	local radius = Vector3.new(size.X * 0.62, math.max(size.Y * 0.8, size.X * 0.18), size.Z * 0.6)
	local localCenter = core.CFrame:PointToObjectSpace(center)
	core:SetAttribute("VoidAuraCore", true)
	core:SetAttribute("VoidAuraOriginalSize", core.Size)
	core:SetAttribute("VoidAuraCenter", localCenter)
	core:SetAttribute("VoidAuraRadius", radius)
	local points = {}
	for index = 1, 18 do
		local angle = (index - 1) / 18 * math.pi * 2
		local point = Instance.new("Attachment")
		point.Name = "VoidLens" .. index
		point:SetAttribute("VoidLensAngle", angle)
		point.Position = localCenter + Vector3.new(math.cos(angle) * radius.X, math.sin(angle) * radius.Y, 0)
		point.Parent = core
		table.insert(points, point)
	end
	for index, point in points do
		local beam = Instance.new("Beam")
		beam.Name = "VoidDistortion"
		beam.Attachment0, beam.Attachment1 = point, points[index % #points + 1]
		beam.Width0, beam.Width1 = size.X * 0.018, size.X * 0.018
		beam.Color = ColorSequence.new(rgb(99, 39, 158))
		beam.Transparency = NumberSequence.new(0.18)
		beam.FaceCamera = true
		beam.LightEmission = 0.7
		beam.LightInfluence = 0
		beam.Segments = 1
		beam.Parent = core
	end
	model:AddTag(FishModels.VOID_TAG)
end

-- Add petals as fish geometry so they follow the fish through tools and displays.
local function flowers(model: Model)
 local core = bodyCore(model)
 if not core then return end
 local b = newBuilder("flowers", 23)
 b.model = model
 local center, size = core.Position / SCALE, core.Size / SCALE
 for _, side in { -1, 1 } do
  for _, x in { -0.2, 0.16 } do
   local origin = center + Vector3.new(size.X * x, size.Y * 0.15, side * size.Z * 0.49)
   local radius = math.max(0.018, size.X * 0.045)
   for petal = 1, 5 do
    local angle = petal * math.pi * 2 / 5
    b:ellipsoid("FlowerPetal", CFrame.new(origin + Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)), Vector3.new(radius, radius, radius * 0.45), rgb(255, 224, 241))
   end
   b:ellipsoid("FlowerCenter", CFrame.new(origin + Vector3.new(0, 0, side * radius * 0.3)), Vector3.one * radius * 0.7, rgb(255, 221, 55))
  end
 end
end

local function mutationParticles(model: Model, name: string, color: Color3, texture: string, rate: number)
 local core = bodyCore(model)
 if not core then return end
 local emitter = Instance.new("ParticleEmitter")
 emitter.Name = name
 emitter.Texture = texture
 emitter.Color = ColorSequence.new(color)
 emitter.LightEmission = 0.8
 emitter.Lifetime = NumberRange.new(0.6, 1.4)
 emitter.Speed = NumberRange.new(0.5, 2)
 emitter.SpreadAngle = Vector2.new(180, 180)
 emitter.Rotation = NumberRange.new(0, 360)
 emitter.RotSpeed = NumberRange.new(-90, 90)
 emitter.Rate = rate
 emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) })
 emitter.Parent = core
end

-- Paints a freshly created, unscaled fish with a record's mutations.
function FishModels.mutate(model: Model, traits)
	local set = FishMutations.parts(traits and traits.Mutation)
	if not next(set) then
		return
	end
	if set.Corrupted then
		local seed = 11
		for index = 1, #model.Name do
			seed = (seed * 31 + string.byte(model.Name, index)) % 2147483647
		end
		for _, kind in traits.Corruptions or { "Eye" } do
			if corruptions[kind] then
				-- Rebuilt each time so a corruption sees the parts the last one added.
				corruptions[kind](rebuild(model, seed))
			end
		end
	end
	if set.VoidTouched then
		-- Colour mutations still contribute to value. Only intrinsic black-hole
		-- accents survive the void; eyes, bones and added corruptions turn black.
		measure(model)
		voidAura(model)
		return
	end
	local neon = traits.NeonColor and FishMutations.NeonColors[traits.NeonColor]
	local glow = if set.Astral then ASTRAL_GLOW elseif neon then rgb(neon[1], neon[2], neon[3]) else rgb(255, 255, 255)
	local lit = set.Neon or set.Astral
 local specialColor = if set.Ascended then rgb(255, 235, 35)
  elseif set.Floral then rgb(157, 233, 54) elseif set.Snowy then rgb(213, 240, 255)
  elseif set.JackOFish or set.JacksPet then rgb(255, 123, 20)
  elseif set.ZeusStruck then rgb(255, 244, 28) elseif set.Nightmare then rgb(12, 25, 70)
  elseif set.Obsidian then rgb(81, 35, 135) elseif set.Tryhard then rgb(80, 245, 255) else nil
	local low, size = bounds(model)
	for _, item in model:GetDescendants() do
		if not item:IsA("BasePart") or UNPAINTED[item.Name] then
			continue
		end
		-- Hue runs snout to tail.
		local hue = (1 - (item.Position.X / SCALE - low.X) / math.max(size.X, 0.01)) * 0.85
		local shade = luminance(item.Color)
		if specialColor then
   local accent = GLOWING[item.Name] or item.Name == "Marking"
   if set.Ascended then item.Color = if accent then specialColor else rgb(255, 255, 239)
   elseif set.Snowy then item.Color = if accent then specialColor else rgb(250, 253, 255)
   elseif set.Floral then item.Color = if accent then specialColor else item.Color:Lerp(specialColor, 0.4)
   elseif set.JackOFish or set.JacksPet then item.Color = if accent then rgb(20, 14, 18) else specialColor
   else item.Color = specialColor:Lerp(Color3.new(0, 0, 0), if accent then 0.45 else 0.15) end
   if set.Ascended or set.ZeusStruck or (set.JacksPet and accent) then item.Material = Enum.Material.Neon end
   if set.Obsidian then item.Material = Enum.Material.Glass item.Transparency = 0.25 item.Reflectance = 0.12 end
   if set.Tryhard then
    item:SetAttribute("GlitchBaseColor", item.Color)
    item:SetAttribute("GlitchBaseTransparency", item.Transparency)
   end
  elseif lit and GLOWING[item.Name] then
			item.Material = Enum.Material.Neon
			if set.Rainbow then
				rainbow(item, hue, 0.85, 1)
			else
				item.Color = glow
			end
		elseif set.Astral then
			item.Color = rgb(12, 12, 18):Lerp(rgb(66, 66, 76), shade)
		elseif set.Albino then
			item.Color = Color3.fromHSV(0, 0, 0.9 + 0.1 * shade)
		elseif set.Rainbow then
			rainbow(item, hue, 0.6, 0.72 + 0.28 * shade)
		end
		-- Keep corruption visible even when the rolled extra feature is small or
		-- hidden by the fish's body. Rainbow owns its animated part colours.
		if set.Corrupted and not set.Rainbow and item.Name ~= "Bone" and item.Name ~= "BoneKnob" and item.Name ~= "Wound" then
			item.Color = item.Color:Lerp(rgb(125, 35, 145), 0.55)
		end
	end
	if set.Rainbow then
		model:AddTag(FishModels.RAINBOW_TAG)
	end
	if set.Astral then
		aurora(model)
	end
	if set.Windy or set.Gusty then windswept(model) end
 if set.Corrupted then mutationParticles(model, "Corruption", rgb(185, 55, 210), "rbxasset://textures/particles/sparkles_main.dds", 16) end
 if set.Floral then flowers(model) end
 if set.Snowy then mutationParticles(model, "Snowflakes", rgb(221, 244, 255), "rbxasset://textures/particles/sparkles_main.dds", 12) end
 if set.ZeusStruck then mutationParticles(model, "Lightning", rgb(255, 245, 65), "rbxasset://textures/particles/sparkles_main.dds", 25) end
 if set.JacksPet then mutationParticles(model, "JackEmbers", rgb(255, 135, 20), "rbxasset://textures/particles/sparkles_main.dds", 14) end
 if set.Ascended then mutationParticles(model, "AscendedGlow", rgb(255, 245, 155), "rbxasset://textures/particles/sparkles_main.dds", 16) end
 if set.Tryhard then model:AddTag(FishModels.GLITCH_TAG) end
	measure(model)
end

function FishModels.has(fishId: string): boolean
	return builders[fishId] ~= nil
end

local function template(fishId: string): Model?
	local model = templates[fishId]
	if not model then
		local build = builders[fishId]
		if not build then
			return nil
		end
		local seed = 7
		for index = 1, #fishId do
			seed = (seed * 31 + string.byte(fishId, index)) % 2147483647
		end
		local builder = newBuilder(fishId, seed)
		build(builder)
		model = builder.model
		measure(model)
		if model:GetAttribute("ViewDirection") == nil then
			model:SetAttribute("ViewDirection", Vector3.new(0.18, 0.16, 1))
		end
		templates[fishId] = model
	end
	return model
end

-- `traits` is a catch record (or anything with its Mutation, NeonColor and
-- Corruptions) to paint the fish with.
function FishModels.create(fishId: string, traits: any?): Model?
	local base = template(fishId)
	if not base then
		return nil
	end
	local model = base:Clone()
	FishModels.mutate(model, traits)
	return model
end

-- A species' smooth skin: its rings (fish lengths) and where its Chest swatch
-- sat in the unscaled template (studs). Nil for sphere-bodied species.
function FishModels.loft(fishId: string)
	template(fishId)
	return lofts[fishId]
end

FishModels.loftPoint = loftPoint
FishModels.loftNormal = loftNormal

local crabSpecies = { ShoreCrab = true, BlueCrab = true, KingCrab = true }
-- Crabs cluster tightly in weight, so the cube-root curve used by fish hides
-- their differences. In hand they follow weight almost directly instead; the
-- larger base keeps an average Shore Crab the same size as before while heavier
-- crabs visibly outgrow lighter ones.
local CRAB_HELD_BASE, CRAB_HELD_EXPONENT = 2.4, 0.9

-- A species' optional LengthScale: long-bodied fish (sturgeons, billfish...)
-- read far too small from weight alone, so they draw this much longer.
local function lengthScale(fishId: string?): number
	local species = fishId and FishSpecies[fishId]
	local scale = species and species.LengthScale
	return if type(scale) == "number" and scale > 0 then scale else 1
end
FishModels.lengthScale = lengthScale

-- Compact display size for the freezer and customer hands.
function FishModels.catchLength(kg: number, fishId: string?): number
	-- Crab weights cluster tightly, so a stronger curve makes their differences
	-- visible while still keeping even a record crab within the freezer.
	local exponent = if fishId and crabSpecies[fishId] then 0.65 else 1 / 3
	-- LengthScale goes in before the compression so it can't break the freezer cap.
	local size = math.max(kg, 0.01) ^ exponent * lengthScale(fishId)
	-- Smoothly compress record weights while retaining differences between
	-- catches. The longest side stays below the freezer's 3.54-stud ice depth.
	return 0.6 + 2.6 * size / (size + 0.75)
end

-- Held catches are sized by weight, regardless of their size label. Big and
-- Huge catches already weigh more, so an extra visual multiplier would make
-- the displayed weight inconsistent with the model.
function FishModels.heldLength(kg: number, size: string?, fishId: string?): number
	local weight = math.max(kg, 0.01)
	if fishId and crabSpecies[fishId] then
		return CRAB_HELD_BASE * weight ^ CRAB_HELD_EXPONENT
	end
	return 1.6 * weight ^ (1 / 3) * lengthScale(fishId)
end

local function scaleToLength(model: Model, length: number): Vector3
	local bounds = model:GetAttribute("BoundsSize") :: Vector3
	local scale = length / math.max(bounds.X, bounds.Y, bounds.Z, 0.1)
	model:ScaleTo(scale)
	return bounds * scale
end

function FishModels.scaleCatch(model: Model, kg: number): Vector3
	return scaleToLength(model, FishModels.catchLength(kg, model.Name))
end

-- Cache unscaled geometry by species and mutations, not by catch weight.
local catchBounds = {}
function FishModels.catchBounds(record): Vector3?
	local corrupted = FishMutations.parts(record.Mutation).Corrupted
	local shapes = if corrupted then record.Corruptions or { "Eye" } else {}
	local key = record.FishId .. ":" .. (record.Mutation or "Normal") .. ":" .. table.concat(shapes, ",")
	local size = catchBounds[key]
	if not size then
		local model = FishModels.create(record.FishId, record)
		if not model then
			return nil
		end
		size = model:GetAttribute("BoundsSize")
		catchBounds[key] = size
		model:Destroy()
	end
	return size * (FishModels.catchLength(record.Kg, record.FishId) / math.max(size.X, size.Y, size.Z, 0.1))
end

function FishModels.scaleHeldCatch(model: Model, kg: number, size: string?): Vector3
	return scaleToLength(model, FishModels.heldLength(kg, size, model.Name))
end

function FishModels.silhouette(model: Model)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Color = Color3.new(1, 1, 1)
			item.Transparency = 0
			item.Reflectance = 0
		end
	end
end

-- Fills a ViewportFrame with the fish and frames it. Returns the model and the
-- camera so callers can animate either one. `traits` paints a caught fish's mutations.
function FishModels.show(viewport: ViewportFrame, fishId: string, silhouette: boolean?, traits: any?): (Model?, Camera?)
	for _, child in viewport:GetChildren() do
		if child:IsA("Model") or child:IsA("Camera") or child:IsA("WorldModel") then
			child:Destroy()
		end
	end
	local model = FishModels.create(fishId, if silhouette then nil else traits)
	if not model then
		return nil, nil
	end
	if silhouette then
		FishModels.silhouette(model)
		viewport.Ambient = Color3.new(1, 1, 1)
		viewport.LightColor = Color3.new(0, 0, 0)
	else
		viewport.Ambient = rgb(150, 150, 156)
		viewport.LightColor = rgb(255, 248, 236)
		viewport.LightDirection = Vector3.new(-0.35, -1, -0.55)
	end
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 26
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local center, size = model:GetAttribute("BoundsCenter") :: Vector3, model:GetAttribute("BoundsSize") :: Vector3
	local direction = (model:GetAttribute("ViewDirection") :: Vector3).Unit
	local distance = (size.Magnitude / 2) / math.sin(math.rad(camera.FieldOfView / 2)) * 0.82
	camera.CFrame = CFrame.lookAt(center + direction * distance, center)
	camera:SetAttribute("Focus", center)
	camera:SetAttribute("Distance", distance)
	return model, camera
end

return FishModels
 end)()
local Packing = (function() -- Deterministic rectangle packing on the cooler's sloped ice bed. Measurements
-- come from the same scaled models used by the display; records stay in order.
local Packing = {}
Packing.LEFT, Packing.RIGHT = -4.32, 4.44
Packing.BACK, Packing.FRONT = -1.74, 1.8
Packing.SLOPE = math.atan2(17, 59)
Packing.MARGIN = 0.12
Packing.GAP = 0.06
local EPSILON = 1e-7

local function contains(a, b)
	return b.x >= a.x - EPSILON
		and b.y >= a.y - EPSILON
		and b.x + b.w <= a.x + a.w + EPSILON
		and b.y + b.h <= a.y + a.h + EPSILON
end

local function occupy(free, box)
	local nextFree = {}
	for _, rect in free do
		if
			box.x >= rect.x + rect.w - EPSILON
			or box.x + box.w <= rect.x + EPSILON
			or box.y >= rect.y + rect.h - EPSILON
			or box.y + box.h <= rect.y + EPSILON
		then
			table.insert(nextFree, rect)
		else
			if box.x > rect.x + EPSILON then
				table.insert(nextFree, { x = rect.x, y = rect.y, w = box.x - rect.x, h = rect.h })
			end
			if box.x + box.w < rect.x + rect.w - EPSILON then
				table.insert(
					nextFree,
					{ x = box.x + box.w, y = rect.y, w = rect.x + rect.w - box.x - box.w, h = rect.h }
				)
			end
			if box.y > rect.y + EPSILON then
				table.insert(nextFree, { x = rect.x, y = rect.y, w = rect.w, h = box.y - rect.y })
			end
			if box.y + box.h < rect.y + rect.h - EPSILON then
				table.insert(
					nextFree,
					{ x = rect.x, y = box.y + box.h, w = rect.w, h = rect.y + rect.h - box.y - box.h }
				)
			end
		end
	end
	for index = #nextFree, 1, -1 do
		for other, rect in nextFree do
			if other ~= index and contains(rect, nextFree[index]) then
				table.remove(nextFree, index)
				break
			end
		end
	end
	return nextFree
end

function Packing.layout(records, count: number, measure)
	local width = Packing.RIGHT - Packing.LEFT - 2 * Packing.MARGIN
	local depth = (Packing.FRONT - Packing.BACK) / math.cos(Packing.SLOPE) - 2 * Packing.MARGIN
	local beds, items, placements = {}, {}, {}
	for _ = 1, count do
		table.insert(beds, { { x = 0, y = 0, w = width + Packing.GAP, h = depth + Packing.GAP } })
	end
	for index, record in records do
		local size = measure(record)
		if size then
			table.insert(items, { index = index, w = math.max(size.Y, size.Z), h = size.X, flat = size.Z > size.Y })
		end
	end
	-- Large fish go first; small catches then fill the remaining gaps, including
	-- extra rows and rotated spaces. Never shrink a catch to make it fit.
	table.sort(items, function(a, b)
		local areaA, areaB = a.w * a.h, b.w * b.h
		return if areaA == areaB then a.index < b.index else areaA > areaB
	end)
	local fitted, used = 0, 0
	for _, item in items do
		local best, short, long = nil, math.huge, math.huge
		for bed, free in beds do
			for _, rect in free do
				for rotation = 0, 1 do
					local w = (if rotation == 0 then item.w else item.h) + Packing.GAP
					local h = (if rotation == 0 then item.h else item.w) + Packing.GAP
					if w <= rect.w + EPSILON and h <= rect.h + EPSILON then
						local s, l = math.min(rect.w - w, rect.h - h), math.max(rect.w - w, rect.h - h)
						if s < short - EPSILON or (math.abs(s - short) <= EPSILON and l < long - EPSILON) then
							best = { x = rect.x, y = rect.y, w = w, h = h, bed = bed, rotated = rotation == 1 }
							short, long = s, l
						end
					end
				end
			end
		end
		used += item.w * item.h
		if best then
			beds[best.bed] = occupy(beds[best.bed], best)
			placements[item.index] = {
				Freezer = best.bed,
				X = Packing.LEFT + Packing.MARGIN + best.x + (best.w - Packing.GAP) / 2,
				Z = Packing.BACK + (Packing.MARGIN + best.y + (best.h - Packing.GAP) / 2) * math.cos(Packing.SLOPE),
				Rotated = best.rotated,
				Flat = item.flat,
			}
			fitted += 1
		end
	end
	return placements, fitted == #records, used / (width * depth * count)
end

return Packing
 end)()

local function vectorJson(value)
 return string.format("[%.9g,%.9g,%.9g]", value.X, value.Y, value.Z)
end
local function exportPreview(id)
 local model = assert(FishModels.create(id), id .. ": missing builder")
 local parts = {}
 for _, part in model:GetDescendants() do
  if not part:IsA("BasePart") then continue end
  local mesh = part:FindFirstChildOfClass("SpecialMesh")
  local shape = if mesh and mesh.MeshType == "Sphere" then "sphere" elseif part.ClassName == "WedgePart" then "wedge" else "block"
  local color, frame = part.Color, part.CFrame
  local hex = string.format("#%02x%02x%02x", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
  table.insert(parts, string.format('{"s":"%s","p":%s,"z":%s,"r":[%s,%s,%s],"c":"%s","t":%.9g,"m":"%s"}', shape, vectorJson(part.Position), vectorJson(part.Size), vectorJson(frame.RightVector), vectorJson(frame.UpVector), vectorJson(frame.ZVector), hex, part.Transparency, tostring(part.Material)))
 end
 print(string.format('{"id":"%s","variants":{"Normal":{"parts":[%s],"boundsSize":%s}}}',id, table.concat(parts,","), vectorJson(model:GetAttribute("BoundsSize"))))
end
exportPreview("VoidlightAngler")
exportPreview("EclipseRay")
exportPreview("Riftmaw")
exportPreview("SingularitySerpent")
return Packing, FishModels
end)()
