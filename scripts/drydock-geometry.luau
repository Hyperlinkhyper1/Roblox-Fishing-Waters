-- Production Harbour/Drydock/Shipwright/Rowboat/Props builders are inserted by
-- check-drydock.mjs or drydock-check.ps1. This checks their emitted geometry with matrix-aware
-- recording mocks; it does not run Roblox physics or replace Studio play.
-- SHARED_PRIMITIVES --

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
function instanceMethods:Destroy()
	self.Parent = nil
end
local CollectionService = {}
function CollectionService:AddTag(item, tag)
	item._tags[tag] = true
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
local workspace = { Terrain = { FillBlock = function() end } }
local task = { wait = function() end }
local warn = print
local dependencies = { Islands = {} }
local function loadBoatCatalog()
	-- BOATCATALOG_SOURCE --
end
dependencies.BoatCatalog = loadBoatCatalog()

local function loadLowPoly()
	-- LOWPOLY_SOURCE --
end
dependencies.LowPoly = loadLowPoly()
local function loadProps()
	-- PROPS_SOURCE --
end
dependencies.Props = loadProps()
local function loadImportedModel()
	-- IMPORTEDMODEL_SOURCE --
end
dependencies.ImportedModel = loadImportedModel()
local function loadShopDeskGeometry()
	-- SHOPDESKGEOMETRY_SOURCE --
end
dependencies.ShopDeskGeometry = loadShopDeskGeometry()
local function loadCashRegisterGeometry()
	-- CASHREGISTERGEOMETRY_SOURCE --
end
dependencies.CashRegisterGeometry = loadCashRegisterGeometry()
local function loadShopDesk()
	-- SHOPDESK_SOURCE --
end
dependencies.ShopDesk = loadShopDesk()
local function loadFishFreezerGeometry()
	-- FISHFREEZERGEOMETRY_SOURCE --
end
dependencies.FishFreezerGeometry = loadFishFreezerGeometry()
local function loadFishFreezer()
	-- FISHFREEZER_SOURCE --
end
dependencies.FishFreezer = loadFishFreezer()
local function loadBaseHouse()
	-- BASEHOUSE_SOURCE --
end
dependencies.BaseHouse = loadBaseHouse()
local function loadMediterranean()
	-- MEDITERRANEAN_SOURCE --
end
dependencies.Mediterranean = loadMediterranean()
local function loadBeachDetails()
	-- BEACHDETAILS_SOURCE --
end
dependencies.BeachDetails = loadBeachDetails()
local function loadRowboat()
	-- ROWBOAT_SOURCE --
end
dependencies.Rowboat = loadRowboat()
local function loadFishingBoat()
	-- FISHINGBOAT_SOURCE --
end
dependencies.FishingBoat = loadFishingBoat()
local function loadShipwright()
	-- SHIPWRIGHT_SOURCE --
end
dependencies.Shipwright = loadShipwright()
local function loadDrydockInterior()
	-- DRYDOCKINTERIOR_SOURCE --
end
dependencies.DrydockInterior = loadDrydockInterior()
local function loadDrydock()
	-- DRYDOCK_SOURCE --
end
dependencies.Drydock = loadDrydock()
local function loadRodShop()
	-- RODSHOP_SOURCE --
end
dependencies.RodShop = loadRodShop()
local function loadBiomes()
	-- BIOMES_SOURCE --
end
local Biomes = loadBiomes()
dependencies.Biomes = Biomes
local function loadSeabed()
	-- SEABED_SOURCE --
end
dependencies.Seabed = loadSeabed()
local function loadHarbour()
	-- HARBOUR_SOURCE --
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
				check(item.CanCollide, label .. " has a nonphysical walking plank")
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

-- Limit construction to the plaza, adjacent beach, and six player bases. This
-- retains the real integration paths without building the distant terrain or
-- comparing every village part with every workshop detail.
local root = Instance.new("Folder")
root.Name = "Map"
local rng = Random.new(Biomes.Seed + 1)
local village = Instance.new("Model")
village.Name, village.Parent = "Village", root
local plazaCenter = shape.toWorld({ 870, 694 })
local spots =
	{ { position = plazaCenter, radius = 60 * 1.42 }, { position = plazaCenter + Vector2.new(0, 82), radius = 31 } }
Harbour.buildPlaza(village, plazaCenter, rng)
Harbour.buildBeach(shape, root, village, spots, rng)
local bases = Instance.new("Folder")
bases.Name, bases.Parent = "Bases", root
for index, anchor in { { 668, 1030 }, { 1000, 950 }, { 1150, 1105 }, { 1360, 1330 }, { 1340, 1500 }, { 880, 1638 } } do
	Harbour.buildBase(shape, bases, index, shape.toWorld(anchor), rng)
end
Harbour.ensureBoating(root)
local plaza = root:FindFirstChild("Plaza", true)
local shop = plaza:FindFirstChild("Drydock")
check(shop ~= nil and CollectionService:HasTag(shop, "BoatShop"), "Actual shop must exist and be tagged")
check(shop:GetAttribute("LayoutVersion") == 10, "Industrial shop must declare its migration version")
check(
	shop:GetAttribute("BoatId") == "Rowboat" and shop:GetAttribute("Price") == 500,
	"The default shop boat must preserve the $500 rowboat"
)
local paving
for _, child in plaza:GetChildren() do
	if child:IsA("BasePart") and (child.Size.X == 120 or child.Size.X == 116) and child.Size.Z == child.Size.X then
		paving = child
	end
end
local plazaFrame = paving.CFrame * CFrame.new(0, paving.Size.Y / 2, 0)
local shopFrame = plazaFrame * CFrame.new(0, 0, 82)
local footprint = shop:FindFirstChild("ShopFootprint")
check(
	footprint and footprint:IsA("BasePart") and footprint.CanCollide == false and footprint.Transparency == 1,
	"Footprint must describe the site without filling its repair basin"
)
check(
	(Vector3.new(footprint.Position.X, 0, footprint.Position.Z) - Vector3.new(
		shopFrame.Position.X,
		0,
		shopFrame.Position.Z
	)).Magnitude < EPS,
	"Shop must remain beyond the plaza's lakeside edge"
)
local footLow, footHigh = bounds(footprint)
check(footLow.Z > paving.Position.Z + 60, "Industrial shop must stay beyond the plaza's southern edge")
for x = footLow.X, footHigh.X, 2 do
	for z = footLow.Z, footHigh.Z, 2 do
		check(Harbour.coastDistance(shape, Vector2.new(x, z)) > 0, "Industrial drydock footprint extends over water")
	end
end
local function descendantOf(item, ancestor)
	while item do
		if item == ancestor then
			return true
		end
		item = item.Parent
	end
	return false
end
local shopParts, solidParts, byName = {}, {}, {}
for _, item in shop:GetDescendants() do
	if item:IsA("BasePart") then
		table.insert(shopParts, item)
		byName[item.Name] = (byName[item.Name] or 0) + 1
		if item.CanCollide then
			table.insert(solidParts, item)
		end
	end
end
for _, detail in
	{
		"SteelColumn",
		"CorrugatedRoof",
		"RoofTruss",
		"GantryBeam",
		"CraneRunway",
		"CraneHook",
		"HazardStripe",
		"WorkLight",
	}
do
	check((byName[detail] or 0) > 0, "Walk-in industrial workshop is missing " .. detail)
end
local npc = shop:FindFirstChild("Shipwright")
check(npc and npc:IsA("Model") and npc:FindFirstChild("Humanoid"), "Shop must contain a humanoid shipwright")
check(npc:GetAttribute("CosmeticsVersion") == 3, "Shipwright must wear the Marketplace outfit")
local talk = npc and npc:FindFirstChild("TalkToShipwrightPrompt", true)
check(
	talk and talk:IsA("ProximityPrompt") and talk.ActionText == "Talk",
	"Buying must begin by talking to the shipwright"
)
check(
	talk and talk.RequiresLineOfSight == false and talk.MaxActivationDistance <= 8 and talk.Parent.Name == "Head",
	"NPC conversation must show at the head without the torso or counter hiding its prompt"
)
for _, item in shop:GetDescendants() do
	if item:IsA("ProximityPrompt") then
		check(item == talk, "Purchase counter or display retains a second shop interaction")
	end
end

local function probe(size, position)
	local item = Instance.new("Part")
	item.Size, item.CFrame = size, shopFrame * CFrame.new(position)
	return item
end
local function surfaceAt(x, z)
	local height = -math.huge
	for _, part in solidParts do
		local low, high = bounds(part, shopFrame)
		if x >= low.X - EPS and x <= high.X + EPS and z >= low.Z - EPS and z <= high.Z + EPS and high.Y <= 2.05 then
			height = math.max(height, high.Y)
		end
	end
	return height
end
-- Follow the entrance stairs, across the front apron, then to the visitor side
-- of the shipwright's counter. Low step faces are allowed below knee height;
-- the three-stud-wide, six-stud-tall standing envelope must otherwise be clear.
local route = { Vector2.new(0, -24), Vector2.new(0, -14), Vector2.new(12, -14), Vector2.new(12, -7) }
local routeBlocked, supportLost, lastHeight, routeSamples = {}, false, nil, 0
for segment = 1, #route - 1 do
	local a, b = route[segment], route[segment + 1]
	local steps = math.ceil((b - a).Magnitude / 0.5)
	for step = 0, steps do
		local point = a:Lerp(b, step / steps)
		local height = surfaceAt(point.X, point.Y)
		routeSamples += 1
		if height == -math.huge then
			supportLost = true
			continue
		end
		check(
			not lastHeight or math.abs(height - lastHeight) <= 0.45,
			"Entrance has a step too tall for the walk-in route"
		)
		lastHeight = height
		local avatar = probe(Vector3.new(3, 5.55, 1), Vector3.new(point.X, height + 3.225, point.Y))
		for _, part in solidParts do
			if not descendantOf(part, npc) and overlaps(avatar, part) then
				routeBlocked[part.Name] = true
			end
		end
	end
end
check(not supportLost, "Walk-in route contains an unsupported gap")
local blockers = {}
for name in routeBlocked do
	table.insert(blockers, name)
end
check(#blockers == 0, "Walk-in route collides with: " .. table.concat(blockers, ", "))

-- Interior additions must leave a usable workshop around the existing pit.
local interior = shop:FindFirstChild("InteriorDetails")
check(interior and interior:GetAttribute("DetailVersion") == 1, "Workshop detail migration must be present")
local detailParts, detailSolids, detailSigns = 0, 0, 0
for _, item in interior:GetDescendants() do
	if item:IsA("BasePart") then
		detailParts += 1
		local low, high = bounds(item, shopFrame)
		check(low.X > -21 and high.X < 21 and low.Z > -19.2 and high.Z < 19,
			"Interior detail escapes the building: " .. item.Name)
		check(item.Anchored and not item.CanTouch, "Dressing must remain static without touch events: " .. item.Name)
		if item.CanCollide then
			detailSolids += 1
		else
			check(item.CanQuery == false, "Decorative pieces must not intercept gameplay raycasts: " .. item.Name)
		end
	elseif item:IsA("SurfaceGui") then
		detailSigns += 1
		check(item.SizingMode == Enum.SurfaceGuiSizingMode.PixelsPerStud, "Interior sign canvas must follow its physical proportions")
	elseif item:IsA("PointLight") or item:IsA("ProximityPrompt") then
		check(false, "Set dressing must reuse workshop lighting and the shipwright interaction")
	end
end
check(detailParts > 600 and detailParts < 1300, "Rich workshop details must stay inside a bounded part budget")
check(detailSolids <= 14 and detailSigns >= 20, "Fine details should stay decorative and stations should have labels")
for _, name in {
	"ToolStation", "PartsStores", "WeldingBay", "MachiningAndToolCart", "CompressorAndServices",
	"TimberAndRigging", "ShipwrightOffice", "SafetyStation", "CraneAndLightingDetails", "FloorAndBasinDetails",
} do
	local station = interior:FindFirstChild(name)
	check(station and station.ModelStreamingMode == Enum.ModelStreamingMode.Atomic, "Workshop station must stream together: " .. name)
end
for _, name in { "HangingWrench", "WrenchJaw", "WeldingCylinder", "CylinderValve" } do
	check(shop:FindFirstChild(name) == nil, "Original placeholder equipment must be replaced: " .. name)
end
local floorWarning = interior:FindFirstChild("BasinWarning", true)
check((-floorWarning.CFrame.ZVector):Dot(shopFrame.UpVector) > 0.99, "Pit warning text must face upward")
local workshopSamples, workshopBlockers = 0, {}
for _, points in {
	{ Vector2.new(-16.5, -14), Vector2.new(-16.5, 14) },
	{ Vector2.new(5, -14), Vector2.new(5, 14) },
	{ Vector2.new(5, 6), Vector2.new(13.5, 6) },
	{ Vector2.new(-16.5, 14.6), Vector2.new(5, 14.6) },
} do
	local a, b = points[1], points[2]
	local steps = math.ceil((b - a).Magnitude / 0.5)
	for step = 0, steps do
		local point = a:Lerp(b, step / steps)
		workshopSamples += 1
		check(math.abs(surfaceAt(point.X, point.Y) - 2) < 0.06, "Workshop lane needs a continuous raised floor")
		local avatar = probe(Vector3.new(3, 5.55, 1), Vector3.new(point.X, 5.225, point.Y))
		for _, piece in solidParts do
			if not descendantOf(piece, npc) and overlaps(avatar, piece) then workshopBlockers[piece.Name] = true end
		end
	end
end
for name in workshopBlockers do check(false, "Workshop walking lane is obstructed by " .. name) end
print(string.format("Interior: %d added parts, %d coarse colliders, %d labeled panels; %d workshop walking samples.", detailParts, detailSolids, detailSigns, workshopSamples))

-- EXPORT_DRYDOCK_PREVIEW --

local standingHeight = surfaceAt(12, -7)
local visitorHead = shopFrame * Vector3.new(12, standingHeight + 5.5, -7)
check(
	(visitorHead - talk.Parent.Position).Magnitude <= talk.MaxActivationDistance,
	"Counter visitor position cannot reach the talk prompt"
)
-- Check a camera/head-to-prompt segment against nearby solid geometry. The NPC's
-- own body is excluded because Roblox prompt LOS handles its owning character.
local function segmentHits(part, from, to)
	local a = part.CFrame:PointToObjectSpace(from)
	local b = part.CFrame:PointToObjectSpace(to)
	local tMin, tMax = 0, 1
	for _, axis in { "X", "Y", "Z" } do
		local delta, half = b[axis] - a[axis], part.Size[axis] / 2
		if math.abs(delta) < EPS then
			if a[axis] < -half or a[axis] > half then
				return false
			end
		else
			local first, last = (-half - a[axis]) / delta, (half - a[axis]) / delta
			if first > last then
				first, last = last, first
			end
			tMin, tMax = math.max(tMin, first), math.min(tMax, last)
			if tMin > tMax then
				return false
			end
		end
	end
	return tMin < 1 and tMax > 0
end
for _, part in solidParts do
	if not descendantOf(part, npc) then
		check(
			not segmentHits(part, visitorHead, talk.Parent.Position),
			"Shipwright line of sight is blocked by " .. part.Name
		)
	end
end

-- Probe the usable volume above the basin floor. Only the displayed hull and
-- its supports may occupy it; a broad footing or walkway would fill it in.
local display = shop:FindFirstChild("DisplayRowboat")
check(display and display:GetAttribute("DisplayOnly") == true, "Repair basin must display the purchasable rowboat")
local basin = probe(Vector3.new(11, 5.05, 20), Vector3.new(-7, 2.975, 1.8))
local basinBlockers = {}
for _, part in solidParts do
	if not descendantOf(part, display) and not string.find(part.Name, "Cradle") and overlaps(basin, part) then
		table.insert(basinBlockers, part.Name)
	end
end
check(#basinBlockers == 0, "Repair basin is filled by: " .. table.concat(basinBlockers, ", "))
local basinFloor = shop:FindFirstChild("BasinFloor")
check(basinFloor and basinFloor.CanCollide, "Repair basin needs a physical dry floor")
local _, basinHigh = bounds(basinFloor, shopFrame)
check(standingHeight - basinHigh.Y >= 1.5, "Repair basin must be visibly recessed below the workshop floor")
for _, part in shopParts do
	if part.Name == "CorrugatedRoof" then
		local low = bounds(part, shopFrame)
		check(low.Y > standingHeight + 8, "Industrial roof lacks standing and crane headroom")
	end
end

-- The rear yard must be a physical empty repair berth facing the bay, with a
-- continuous descent into the sea and usable access from the real beach.
local rear = shop:FindFirstChild("RearDrydock")
check(rear and rear:IsA("Model"), "Workshop needs an actual outdoor drydock behind its rear wall")
local rearFootprint = rear and rear:FindFirstChild("RearDrydockFootprint")
check(
	rearFootprint
		and rearFootprint:IsA("BasePart")
		and rearFootprint.Transparency == 1
		and not rearFootprint.CanCollide
		and not rearFootprint.CanTouch
		and not rearFootprint.CanQuery,
	"Rear site footprint must remain invisible and nonphysical"
)
local rearLow, rearHigh = bounds(rearFootprint, shopFrame)
check(rearLow.Z >= 19.5 and rearHigh.Z > 100, "Outdoor drydock must extend behind the workshop toward the water")
local rearParts, rearSolid, rearNames, accessSteps = {}, {}, {}, {}
for _, item in rear:GetDescendants() do
	check(not item:IsA("ProximityPrompt"), "Unassigned rear drydock must not add a gameplay interaction")
	if item:IsA("BasePart") then
		table.insert(rearParts, item)
		rearNames[item.Name] = (rearNames[item.Name] or 0) + 1
		if item.CanCollide then
			table.insert(rearSolid, item)
		end
		if item.Name == "RearAccessStep" then
			table.insert(accessSteps, item)
			check(
				item.CanCollide and (item.CFrame.UpVector - Vector3.yAxis).Magnitude < EPS,
				"Rear stairs need level physical treads"
			)
		end
	end
end
for _, detail in
	{
		"RearBasinFloor",
		"RearBasinWall",
		"RearQuayWalkway",
		"RearAccessStep",
		"KeelBlock",
		"BilgeBlock",
		"HaulRail",
		"SlipwayDeck",
		"SlipwayRail",
		"OutdoorGantryColumn",
		"OutdoorGantryBeam",
		"OutdoorCraneHook",
	}
do
	check((rearNames[detail] or 0) > 0, "Outdoor drydock is missing " .. detail)
end
local rearFloor = rear:FindFirstChild("RearBasinFloor", true)
check(rearFloor and rearFloor.CanCollide, "Outdoor repair berth needs a solid dry basin floor")
local rearFloorLow, rearFloorHigh = bounds(rearFloor, shopFrame)
check(rearFloorLow.Z > 30 and rearFloorHigh.Z >= 75, "Outdoor repair berth must have room for a real boat")
check(rearFloor.Size.X >= 20 and rearFloor.Size.Z >= 40, "Rear basin floor is too small to read as a repair berth")
local fishingPreview = rear:FindFirstChild("FishingBoatPreview")
local fishingFloor = rear:FindFirstChild("FishingBerthFloor")
check(
	fishingPreview and fishingPreview:IsA("Model") and fishingPreview:GetAttribute("BoatId") == "FishingBoat",
	"The fisher's boat needs a separate identifiable physical preview"
)
check(fishingFloor and fishingFloor.CanCollide, "Fishing preview requires its own recessed repair berth")
local fishingLow, fishingHigh = bounds(fishingFloor, shopFrame)
for _, piece in fishingPreview:GetDescendants() do
	if piece:IsA("BasePart") then
		local low, high = bounds(piece, shopFrame)
		check(
			low.X >= fishingLow.X and high.X <= fishingHigh.X and low.Z >= fishingLow.Z and high.Z <= fishingHigh.Z,
			"Fishing preview projects beyond its side berth: " .. piece.Name
		)
		check(piece.Anchored and not piece.CanCollide, "Fishing preview must be anchored and nonphysical")
	end
end
local dryFloorWorldY = (rearFloor.CFrame * Vector3.new(0, rearFloor.Size.Y / 2, 0)).Y
check(dryFloorWorldY > Biomes.WaterLevel + 1, "Outdoor basin floor must stay visibly above seawater")
for x = rearFloorLow.X + 0.5, rearFloorHigh.X - 0.5, 2 do
	for z = rearFloorLow.Z + 0.5, rearFloorHigh.Z - 0.5, 2 do
		local point = shopFrame * Vector3.new(x, 0, z)
		check(
			dryFloorWorldY > Harbour.heightAt(shape, Vector2.new(point.X, point.Z)) + 0.1,
			"Terrain hides the dry basin floor"
		)
	end
end
local rearBasinVolume = probe(Vector3.new(20, 3.6, 41), Vector3.new(0, rearFloorHigh.Y + 2, 55))
local rearBasinBlockers = {}
for _, item in rearSolid do
	if
		item.Name ~= "KeelBlock"
		and item.Name ~= "BilgeBlock"
		and item.Name ~= "HaulRail"
		and overlaps(rearBasinVolume, item)
	then
		table.insert(rearBasinBlockers, item.Name)
	end
end
check(#rearBasinBlockers == 0, "Outdoor basin is filled by: " .. table.concat(rearBasinBlockers, ", "))
local quayHeight = -math.huge
for _, item in rearParts do
	if item.Name == "RearQuayWalkway" then
		local low, high = bounds(item, shopFrame)
		quayHeight = math.max(quayHeight, high.Y)
		check(item.CanCollide and high.Y - rearFloorHigh.Y >= 3.5, "Rear basin must sit below physical side quays")
	end
end
local function rearSurfaceAt(x, z)
	local point = shopFrame * Vector3.new(x, 0, z)
	local height = Harbour.heightAt(shape, Vector2.new(point.X, point.Z)) - shopFrame.Position.Y
	local constructed = false
	for _, item in rearSolid do
		if item.Name ~= "RearAccessStep" and item.Name ~= "RearQuayWalkway" and item.Name ~= "FishingBerthQuay" then
			continue
		end
		local low, high = bounds(item, shopFrame)
		if x >= low.X - EPS and x <= high.X + EPS and z >= low.Z - EPS and z <= high.Z + EPS then
			height = math.max(height, high.Y)
			constructed = true
		end
	end
	return height, constructed
end
local rearRouteSamples, rearRouteBlockers = 0, {}
for _, side in { -1, 1 } do
	local previous, previousConstructed
	for z = 20, 79, 0.25 do
		-- Pass the gantry on its inboard side, then use the clear outboard
		-- lane beside the winches. The platform provides both walking lanes.
		local x = side * (15.5 + 1.2 * math.clamp((z - 60) / 6, 0, 1))
		local height, constructed = rearSurfaceAt(x, z)
		rearRouteSamples += 1
		-- The first riser meets gently uneven sand; built risers retain the
		-- tighter limit used by the shop entrance route.
		local allowedRise = if previousConstructed then 0.45 else 0.55
		check(
			not previous or math.abs(height - previous) <= allowedRise,
			"Rear stairs do not join the actual sand and side quay with walkable steps"
		)
		previous, previousConstructed = height, constructed
		local avatar = probe(Vector3.new(3, 5.55, 0.3), Vector3.new(x, height + 3.225, z))
		for _, item in rearSolid do
			if overlaps(avatar, item) then
				rearRouteBlockers[item.Name] = true
			end
		end
	end
	check(
		math.abs(rearSurfaceAt(side * 15.5, 79) - quayHeight) < EPS,
		"Rear side quay lacks a continuous walking surface"
	)
end
local fishingWalk = {
	Vector3.new(16.7, 0, 64),
	Vector3.new(21, 0, 64),
	Vector3.new(21, 0, 35.5),
	Vector3.new(39, 0, 35.5),
	Vector3.new(39, 0, 72.5),
	Vector3.new(21, 0, 72.5),
	Vector3.new(21, 0, 64),
}
for index = 2, #fishingWalk do
	local from, to = fishingWalk[index - 1], fishingWalk[index]
	local count = math.ceil((to - from).Magnitude / 0.5)
	for sample = 0, count do
		local point = from:Lerp(to, sample / count)
		local height, constructed = rearSurfaceAt(point.X, point.Z)
		rearRouteSamples += 1
		check(constructed and math.abs(height - quayHeight) < EPS, "Fishing berth quays need a continuous level route")
		local avatar = probe(Vector3.new(3, 5.55, 3), Vector3.new(point.X, height + 3.225, point.Z))
		for _, item in rearSolid do
			if overlaps(avatar, item) then
				rearRouteBlockers[item.Name] = true
			end
		end
	end
end
local rearBlockedNames = {}
for name in rearRouteBlockers do
	table.insert(rearBlockedNames, name)
end
check(#rearBlockedNames == 0, "Rear walking route collides with: " .. table.concat(rearBlockedNames, ", "))
local slipway = rear:FindFirstChild("SlipwayDeck", true)
check(slipway and slipway.CanCollide, "A real slipway must physically connect the basin to the sea")
local slipEnds = {
	slipway.CFrame * Vector3.new(0, slipway.Size.Y / 2, -slipway.Size.Z / 2),
	slipway.CFrame * Vector3.new(0, slipway.Size.Y / 2, slipway.Size.Z / 2),
}
table.sort(slipEnds, function(a, b)
	return shopFrame:PointToObjectSpace(a).Z < shopFrame:PointToObjectSpace(b).Z
end)
local slipTop, slipBottom = slipEnds[1], slipEnds[2]
check(math.abs(slipTop.Y - dryFloorWorldY) < 0.3, "Slipway does not meet the dry repair floor")
check(slipBottom.Y < Biomes.WaterLevel - 2, "Slipway must descend below the waterline")
check(
	Harbour.coastDistance(shape, Vector2.new(slipBottom.X, slipBottom.Z)) < 0,
	"Slipway ends on land instead of in the bay"
)
check(
	Harbour.heightAt(shape, Vector2.new(slipBottom.X, slipBottom.Z)) < slipBottom.Y - 1,
	"Slipway submerged end intersects the seabed"
)

-- Any surrounding beach/boardwalk piece left in the building volume is an
-- integration error. Bounds filtering keeps this linear in the scene size.
local occupied = probe(Vector3.new(42, 22, 39), Vector3.new(0, 7, 0))
local beachHits, rearBeachHits = {}, {}
local beach = village:FindFirstChild("Beach") or root:FindFirstChild("Beach", true)
check(beach ~= nil, "Focused integration scene must contain real beach props")
for _, item in beach:GetDescendants() do
	if item:IsA("BasePart") and item.Transparency < 1 then
		if overlaps(occupied, item) then
			table.insert(beachHits, item:GetFullName())
		end
		if overlaps(rearFootprint, item) then
			table.insert(rearBeachHits, item:GetFullName())
		end
	end
end
check(#beachHits == 0, tostring(#beachHits) .. " generated beach pieces intrude into the workshop")
check(#rearBeachHits == 0, tostring(#rearBeachHits) .. " generated beach pieces intrude into the rear drydock")

-- Plaza palms and lights are built before the shop and are not beach props.
-- Check only nearby candidates against the emitted workshop to catch a crown
-- entering the roof while avoiding the old whole-village cross product.
local plazaHits, nearbyPlazaParts = {}, 0
for _, item in plaza:GetDescendants() do
	if not item:IsA("BasePart") or item.Transparency >= 1 or descendantOf(item, shop) then
		continue
	end
	local low, high = bounds(item)
	if
		high.X <= footLow.X
		or low.X >= footHigh.X
		or high.Z <= footLow.Z
		or low.Z >= footHigh.Z
		or high.Y <= footLow.Y
		or low.Y >= footHigh.Y
	then
		continue
	end
	nearbyPlazaParts += 1
	for _, shopPart in shopParts do
		if shopPart.Transparency < 1 and overlaps(item, shopPart) then
			table.insert(plazaHits, item:GetFullName() .. " intersects " .. shopPart.Name)
			break
		end
	end
end
for i, hit in plazaHits do
	if i <= 10 then
		print("PLAZA COLLISION: " .. hit)
	end
end
check(#plazaHits == 0, tostring(#plazaHits) .. " existing plaza details intersect the industrial workshop")

local baked = Instance.new("Folder")
baked.Name = "BakedMap"
local oldPlaza = Instance.new("Model")
oldPlaza.Name, oldPlaza.Parent = "Plaza", baked
local oldPaving = Instance.new("Part")
oldPaving.Size, oldPaving.CFrame, oldPaving.Parent = Vector3.new(120, paving.Size.Y, 120), paving.CFrame, oldPlaza
local legacy = Instance.new("Model")
legacy.Name, legacy.Parent = "Drydock", oldPlaza
legacy:SetAttribute("LayoutVersion", 1)
local oldCounter = Instance.new("Part")
oldCounter.Name, oldCounter.Parent = "PurchaseCounter", legacy
local oldBuy = Instance.new("ProximityPrompt")
oldBuy.Name, oldBuy.Parent = "BuyRowboatPrompt", oldCounter
local oldBeach = Instance.new("Model")
oldBeach.Name, oldBeach.Parent = "Beach", baked
local oldClutter = Instance.new("Part")
oldClutter.Size, oldClutter.CFrame, oldClutter.Parent = Vector3.new(2, 2, 2), shopFrame, oldBeach
local outsideClutter = Instance.new("Part")
outsideClutter.CFrame, outsideClutter.Parent = shopFrame * CFrame.new(50, 0, 0), oldBeach
-- A palm trunk may be outside the apron while its crown penetrates the roof.
-- Retrofit must remove the whole prop, leaving no floating palm fragments.
local oldPalm = Instance.new("Model")
oldPalm.Name, oldPalm.Parent = "Palm", oldBeach
local palmTrunk = Instance.new("Part")
palmTrunk.Size, palmTrunk.CFrame, palmTrunk.Parent = Vector3.new(1, 14, 1), shopFrame * CFrame.new(25, 7, 0), oldPalm
local palmCrown = Instance.new("Part")
palmCrown.Size, palmCrown.CFrame, palmCrown.Parent = Vector3.new(12, 2, 3), shopFrame * CFrame.new(22, 14, 0), oldPalm
local outsidePalm = Instance.new("Model")
outsidePalm.Name, outsidePalm.Parent = "Palm", oldBeach
local outsideLeaf = Instance.new("Part")
outsideLeaf.CFrame, outsideLeaf.Parent = shopFrame * CFrame.new(55, 15, 0), outsidePalm

local details = Instance.new("Model")
details.Name, details.Parent = "BeachDetails", oldBeach
local insideGrass = Instance.new("Model")
insideGrass.Name, insideGrass.Parent = "MarramGrass", details
local insideBlade = Instance.new("Part")
insideBlade.Size, insideBlade.CFrame, insideBlade.Parent =
	Vector3.new(1, 2, 1), shopFrame * CFrame.new(5, 0, 5), insideGrass
local outsideGrass = Instance.new("Model")
outsideGrass.Name, outsideGrass.Parent = "MarramGrass", details
local outsideBlade = Instance.new("Part")
outsideBlade.CFrame, outsideBlade.Parent = shopFrame * CFrame.new(50, 0, 5), outsideGrass
local plazaPalm = Instance.new("Model")
plazaPalm.Name, plazaPalm.Parent = "Palm", oldPlaza
local plazaCrown = Instance.new("Part")
plazaCrown.Size, plazaCrown.CFrame, plazaCrown.Parent =
	Vector3.new(12, 2, 3), shopFrame * CFrame.new(22, 14, 0), plazaPalm
local outsidePlazaPalm = Instance.new("Model")
outsidePlazaPalm.Name, outsidePlazaPalm.Parent = "Palm", oldPlaza
local outsidePlazaLeaf = Instance.new("Part")
outsidePlazaLeaf.CFrame, outsidePlazaLeaf.Parent = shopFrame * CFrame.new(55, 15, 0), outsidePlazaPalm

local baseCount = 0
local savedDockFixtures, freshDockModels = {}, {}
for _, base in root:GetDescendants() do
	if not base:IsA("Model") or not CollectionService:HasTag(base, "PlayerBase") then
		continue
	end
	baseCount += 1
	local boatFrame = base:FindFirstChild("BoatSpawn").CFrame
	local dockFrame = base:GetAttribute("BoatDockFrame")
	for _, model in auditDocks(base, "Fresh " .. base.Name) do
		table.insert(freshDockModels, { base = base, model = model })
	end
	check(math.abs(boatFrame.Position.Y - Biomes.WaterLevel) < EPS, base.Name .. " launch is not at sea level")
	check((boatFrame.LookVector - dockFrame.LookVector).Magnitude < EPS, base.Name .. " launch does not face outward")
	check(
		(dockFrame:PointToObjectSpace(boatFrame.Position) - Vector3.new(0, 0, -52)).Magnitude < EPS,
		base.Name .. " launch offset changed"
	)
	local minClearance, minDepth = math.huge, math.huge
	for x = -5.3, 5.3, 0.53 do
		for z = -7.2, 7.2, 0.6 do
			local p = boatFrame * Vector3.new(x, 0, z)
			local point = Vector2.new(p.X, p.Z)
			local d, h = Harbour.coastDistance(shape, point), Harbour.heightAt(shape, point)
			minClearance, minDepth = math.min(minClearance, -d), math.min(minDepth, -h)
			check(d < 0, base.Name .. " hull/oar envelope reaches land")
			check(h < Biomes.WaterLevel - 0.65, base.Name .. " keel reaches seabed")
		end
	end
	local boat = dependencies.Rowboat.build(boatFrame, false)
	local actualAft, pierTip = -math.huge, math.huge
	local pierParts = {}
	for _, part in boat:GetDescendants() do
		if part:IsA("BasePart") then
			for _, point in corners(part, dockFrame) do
				actualAft = math.max(actualAft, point.Z)
			end
		end
	end
	for _, item in base:GetDescendants() do
		if item:IsA("BasePart") and item.Name ~= "BoatSpawn" and item.Transparency < 1 then
			for _, point in corners(item, dockFrame) do
				pierTip = math.min(pierTip, point.Z)
			end
			if item.CanCollide then
				table.insert(pierParts, item)
			end
		end
	end
	check(actualAft < pierTip, base.Name .. " boat stern is not beyond all pier geometry")
	for _, part in boat:GetDescendants() do
		if part:IsA("BasePart") and part.CanCollide then
			for _, obstacle in pierParts do
				check(not overlaps(part, obstacle), base.Name .. " launched boat intersects pier/ladder")
			end
		end
	end
	print(
		string.format(
			"%s: waterline %.2f, shore clearance %.2f, depth %.2f, stern/pier gap %.2f studs.",
			base.Name,
			boatFrame.Position.Y,
			minClearance,
			minDepth,
			pierTip - actualAft
		)
	)
	local oldBase = Instance.new("Model")
	oldBase.Name, oldBase.Parent = base.Name, baked
	oldBase:SetAttribute("BaseId", base:GetAttribute("BaseId"))
	oldBase:SetAttribute("BoatDockFrame", dockFrame)
	CollectionService:AddTag(oldBase, "PlayerBase")
	local oldSpawn = Instance.new("SpawnLocation")
	oldSpawn.Name, oldSpawn.CFrame, oldSpawn.Parent = "SpawnPoint", base:FindFirstChild("SpawnPoint").CFrame, oldBase
	-- Reproduce the old named pier models and the anonymous crosswalk pieces,
	-- including their exact transforms. An unrelated piece remains as a guard
	-- against an overly broad saved-map cleanup.
	local fixture = { base = oldBase, oldDocks = {}, oldPiles = {} }
	for _, side in { -1, 1 } do
		local oldDock = Instance.new("Model")
		oldDock.Name, oldDock.Parent = "Dock", oldBase
		local oldBoard = Instance.new("Part")
		oldBoard.Size, oldBoard.CFrame, oldBoard.Parent =
			Vector3.new(7, 0.6, 2), dockFrame * CFrame.new(side * 17, 3, 4), oldDock
		table.insert(fixture.oldDocks, oldDock)
	end
	local oldLink = Instance.new("Part")
	oldLink.Size, oldLink.CFrame, oldLink.Parent = Vector3.new(27, 0.6, 5), dockFrame * CFrame.new(0, 3, -38), oldBase
	fixture.oldLink = oldLink
	for _, x in { -8, 0, 8 } do
		local oldPile = Instance.new("Part")
		oldPile.Size, oldPile.CFrame, oldPile.Parent =
			Vector3.new(0.9, 18, 0.9), dockFrame * CFrame.new(x, -6.4, -38), oldBase
		table.insert(fixture.oldPiles, oldPile)
	end
	local sentinel = Instance.new("Part")
	sentinel.Name, sentinel.Size, sentinel.CFrame, sentinel.Parent =
		"UnrelatedDocksideObject", Vector3.new(1, 1, 1), dockFrame * CFrame.new(11, 4, -25), oldBase
	fixture.sentinel = sentinel
	table.insert(savedDockFixtures, fixture)
end
check(baseCount == 6, "Must check all six base launches")
Harbour.ensureDocks(root)
for _, item in freshDockModels do
	check(item.model.Parent == item.base, item.base.Name .. " fresh docks were unnecessarily replaced during ensure")
end
Harbour.ensureDocks(baked)
for _, fixture in savedDockFixtures do
	for _, model in fixture.oldDocks do
		check(model.Parent == nil, fixture.base.Name .. " retains a legacy pier model")
	end
	check(fixture.oldLink.Parent == nil, fixture.base.Name .. " retains the anonymous legacy crosswalk slab")
	for _, pile in fixture.oldPiles do
		check(pile.Parent == nil, fixture.base.Name .. " retains a legacy crosswalk pile")
	end
	check(fixture.sentinel.Parent == fixture.base, fixture.base.Name .. " dock retrofit removed unrelated geometry")
	fixture.models = auditDocks(fixture.base, "Saved " .. fixture.base.Name)
end
Harbour.ensureBoating(baked)
local replacement = oldPlaza:FindFirstChild("Drydock")
check(legacy.Parent == nil and replacement ~= legacy, "Version-one counter shop was not replaced")
check(replacement:GetAttribute("LayoutVersion") == 10, "Saved map did not receive the industrial layout")
check(
	replacement:FindFirstChild("TalkToShipwrightPrompt", true) ~= nil
		and replacement:FindFirstChild("BuyRowboatPrompt", true) == nil,
	"Saved map did not migrate to NPC conversation"
)
check(oldClutter.Parent == nil, "Saved beach clutter remains inside drydock")
check(oldPalm.Parent == nil, "Saved palm crown intersects shop or leaves an orphaned trunk")
check(
	insideGrass.Parent == nil and details.Parent == oldBeach,
	"Clearing one grass tuft removed the whole BeachDetails container"
)
check(
	outsideGrass.Parent == details and outsideBlade.Parent == outsideGrass,
	"Unrelated grass tuft outside the drydock was removed"
)
check(plazaPalm.Parent == nil, "Saved plaza palm crown still enters the workshop roof")
check(
	outsidePlazaPalm.Parent == oldPlaza and outsidePlazaLeaf.Parent == outsidePlazaPalm,
	"Unrelated plaza palm outside the drydock was removed"
)
check(
	outsideClutter.Parent == oldBeach and outsidePalm.Parent == oldBeach and outsideLeaf.Parent == outsidePalm,
	"Saved beach props outside the workshop were removed"
)
local afterFirst = #baked:GetDescendants()
Harbour.ensureBoating(baked)
check(
	oldPlaza:FindFirstChild("Drydock") == replacement and #baked:GetDescendants() == afterFirst,
	"Industrial upgrade must run once and preserve the resulting shop"
)
Harbour.ensureDocks(baked)
check(#baked:GetDescendants() == afterFirst, "Dock retrofit is not idempotent")
for _, fixture in savedDockFixtures do
	for _, model in fixture.models do
		check(model.Parent == fixture.base, fixture.base.Name .. " dock ensure replaced current geometry")
	end
end
for _, fresh in root:GetDescendants() do
	if not fresh:IsA("Model") or not CollectionService:HasTag(fresh, "PlayerBase") then
		continue
	end
	local old = baked:FindFirstChild(fresh.Name)
	for _, name in { "BoatSpawn", "BoatDockControl" } do
		local a, b = fresh:FindFirstChild(name), old:FindFirstChild(name)
		check(
			(a.Position - b.Position).Magnitude < EPS and (a.CFrame.LookVector - b.CFrame.LookVector).Magnitude < EPS,
			fresh.Name .. " fresh/saved " .. name .. " differs"
		)
	end
end
local savedParts = {}
for _, item in replacement:GetDescendants() do
	if item:IsA("BasePart") then
		table.insert(savedParts, item)
	end
end
check(#shopParts == #savedParts, "Fresh/saved shop part counts differ")
for i, a in shopParts do
	local b = savedParts[i]
	check(
		b
			and a.Name == b.Name
			and (a.Position - b.Position).Magnitude < EPS
			and (a.CFrame.LookVector - b.CFrame.LookVector).Magnitude < EPS,
		"Fresh/saved shop transform differs: " .. a.Name
	)
end
-- Reproduce the current saved workshop without the new rear yard. Its 116-stud
-- paving must be recognized just like the older 120-stud plaza fixture above.
local bakedV2 = Instance.new("Folder")
bakedV2.Name = "SavedVersionTwoMap"
local plazaV2 = Instance.new("Model")
plazaV2.Name, plazaV2.Parent = "Plaza", bakedV2
local pavingV2 = Instance.new("Part")
pavingV2.Size, pavingV2.CFrame, pavingV2.Parent = paving.Size, paving.CFrame, plazaV2
local legacyV2 = dependencies.Drydock.build(plazaV2, plazaFrame)
legacyV2:SetAttribute("LayoutVersion", 2)
local missingRear = legacyV2:FindFirstChild("RearDrydock")
missingRear:Destroy()
local beachV2 = Instance.new("Model")
beachV2.Name, beachV2.Parent = "Beach", bakedV2
local rearClutterV2 = Instance.new("Part")
rearClutterV2.Name, rearClutterV2.Size, rearClutterV2.CFrame, rearClutterV2.Parent =
	"RearBeachClutter", Vector3.new(2, 2, 2), shopFrame * CFrame.new(0, 1, 55), beachV2
local outsideClutterV2 = Instance.new("Part")
outsideClutterV2.CFrame, outsideClutterV2.Parent = shopFrame * CFrame.new(50, 1, 55), beachV2
Harbour.ensureBoating(bakedV2)
local replacementV2 = plazaV2:FindFirstChild("Drydock")
check(legacyV2.Parent == nil and replacementV2 ~= legacyV2, "Saved version-two workshop was not upgraded")
check(
	replacementV2:GetAttribute("LayoutVersion") == 10,
	"Saved version-two workshop did not receive the rear drydock layout"
)
local savedRearV2 = replacementV2:FindFirstChild("RearDrydock")
check(
	savedRearV2 and savedRearV2:FindFirstChild("RearBasinFloor", true),
	"Saved version-two workshop still lacks the outdoor basin"
)
check(rearClutterV2.Parent == nil, "Saved beach clutter remains inside the new rear drydock")
check(outsideClutterV2.Parent == beachV2, "Rear retrofit removed an unrelated beach prop outside its footprint")
local savedV2Parts = {}
for _, item in replacementV2:GetDescendants() do
	if item:IsA("BasePart") then
		table.insert(savedV2Parts, item)
	end
end
check(#shopParts == #savedV2Parts, "Fresh/version-two-upgraded shop part counts differ")
for i, fresh in shopParts do
	local saved = savedV2Parts[i]
	check(
		saved
			and saved.Name == fresh.Name
			and (saved.Size - fresh.Size).Magnitude < EPS
			and (saved.Position - fresh.Position).Magnitude < EPS
			and (saved.CFrame.LookVector - fresh.CFrame.LookVector).Magnitude < EPS,
		"Version-two-upgraded geometry differs from the fresh drydock: " .. fresh.Name
	)
end
local afterV2Upgrade = #bakedV2:GetDescendants()
Harbour.ensureBoating(bakedV2)
check(
	plazaV2:FindFirstChild("Drydock") == replacementV2
		and replacementV2:FindFirstChild("RearDrydock") == savedRearV2
		and #bakedV2:GetDescendants() == afterV2Upgrade,
	"Rear drydock upgrade must run once and preserve the finished saved workshop"
)
-- A current saved shell needs an additive furnishing upgrade: keep the NPC,
-- original floor, boats, and lift rather than reconstructing the entire shop.
do
	local savedRear = replacementV2:FindFirstChild("RearDrydock")
	local savedBoat = replacementV2:FindFirstChild("LaunchPreview", true)
	local savedNpc = replacementV2:FindFirstChild("Shipwright")
	replacementV2:FindFirstChild("InteriorDetails"):Destroy()
	for _, name in { "HangingWrench", "WrenchJaw", "WeldingCylinder", "CylinderValve" } do
		local old = Instance.new("Part")
		old.Name, old.Parent = name, replacementV2
	end
	dependencies.Drydock.build(plazaV2, plazaFrame)
	local upgrade = replacementV2:FindFirstChild("InteriorDetails")
	check(upgrade and upgrade:GetAttribute("DetailVersion") == 1, "Current saved shell did not receive detailed furnishings")
	check(plazaV2:FindFirstChild("Drydock") == replacementV2 and replacementV2:FindFirstChild("RearDrydock") == savedRear
		and replacementV2:FindFirstChild("Shipwright") == savedNpc and replacementV2:FindFirstChild("LaunchPreview", true) == savedBoat,
		"Furnishing upgrades must preserve the building, NPC, preview boat and operational lift")
	local upgradedCount = #replacementV2:GetDescendants()
	dependencies.Drydock.build(plazaV2, plazaFrame)
	check(replacementV2:FindFirstChild("InteriorDetails") == upgrade and #replacementV2:GetDescendants() == upgradedCount,
		"Repeated furnishing upgrades must not duplicate tools or equipment")
	upgrade:SetAttribute("DetailVersion", 0)
	dependencies.Drydock.build(plazaV2, plazaFrame)
	check(upgrade.Parent == nil and #replacementV2:GetDescendants() == upgradedCount,
		"Outdated furnishings must be replaced without duplicating the workshop")
end

local function checkLaunchFlow()
	-- Repair the prompt in a current, baked drydock as well as fresh NPCs.
	-- Keep the shipyard and its launch preview in place during this migration.
	do
		local savedNpc = shop:FindFirstChild("Shipwright")
		local savedTalk = savedNpc:FindFirstChild("TalkToShipwrightPrompt", true)
		local savedPreview = shop:FindFirstChild("LaunchPreview", true)
		local beforeRepair = #shop:GetDescendants()
		savedTalk.Parent = savedNpc.PrimaryPart
		savedTalk.RequiresLineOfSight, savedTalk.Enabled = true, false
		savedTalk.Style = Enum.ProximityPromptStyle.Custom
		Harbour.ensureBoating(root)
		check(
			plaza:FindFirstChild("Drydock") == shop and shop:FindFirstChild("LaunchPreview", true) == savedPreview,
			"Prompt repair must preserve the current drydock and preview"
		)
		check(
			savedTalk.Parent == savedNpc:FindFirstChild("Head")
				and savedTalk.Enabled
				and not savedTalk.RequiresLineOfSight
				and savedTalk.Style == Enum.ProximityPromptStyle.Default,
			"Saved root prompt must migrate to an enabled head prompt with native UI"
		)
		Harbour.ensureBoating(root)
		check(
			savedNpc:FindFirstChild("TalkToShipwrightPrompt", true) == savedTalk
				and #shop:GetDescendants() == beforeRepair,
			"Repeated prompt repair must reuse the prompt and keep one interaction"
		)
	end
	-- A saved version-three rear yard also needs the new launch equipment.
	replacementV2:SetAttribute("LayoutVersion", 3)
	replacementV2:FindFirstChild("LaunchPreview", true):Destroy()
	replacementV2:FindFirstChild("LaunchCradle", true):Destroy()
	Harbour.ensureBoating(bakedV2)
	local upgradedV3 = plazaV2:FindFirstChild("Drydock")
	check(
		upgradedV3 ~= replacementV2 and upgradedV3:GetAttribute("LayoutVersion") == 10,
		"Saved version-three rear yard must upgrade to the working drydock"
	)
	check(
		upgradedV3:FindFirstChild("LaunchPreview", true) and upgradedV3:FindFirstChild("LaunchCradle", true),
		"Saved version-three yard must receive a launchable preview and cradle"
	)
	upgradedV3:SetAttribute("LayoutVersion", 4)
	upgradedV3:FindFirstChild("FishingBoatPreview", true):Destroy()
	Harbour.ensureBoating(bakedV2)
	local upgradedV4 = plazaV2:FindFirstChild("Drydock")
	check(
		upgradedV4 ~= upgradedV3 and upgradedV4:GetAttribute("LayoutVersion") == 10
			and upgradedV4:FindFirstChild("FishingBoatPreview", true)
			and typeof(upgradedV4:GetAttribute("FishingBoatPreviewFrame")) == "CFrame",
		"Saved version-four rowboat yards must receive the new fisher's boat and berth"
	)
	-- Saved copies of the mistakenly extended lift must return to the old bay.
	upgradedV4:SetAttribute("LayoutVersion", 6)
	local extraDeck = Instance.new("Part")
	extraDeck.Name, extraDeck.Parent = "LaunchPlatformDeck", upgradedV4
	Harbour.ensureBoating(bakedV2)
	local upgradedV6 = plazaV2:FindFirstChild("Drydock")
	check(upgradedV6 ~= upgradedV4 and upgradedV6:GetAttribute("LayoutVersion") == 10
		and not upgradedV6:FindFirstChild("LaunchPlatformDeck", true)
		and not upgradedV6:FindFirstChild("LiftAccessWalkway", true),
		"Saved extra-platform layouts must be replaced with the original lift bay")
	-- Saved fishing boats from before the closed hull must be rebuilt as well.
	upgradedV6:SetAttribute("LayoutVersion", 7)
	local oldFishingPreview = upgradedV6:FindFirstChild("FishingBoatPreview", true)
	for _, piece in oldFishingPreview:GetDescendants() do
		if piece.Name == "BilgePanel" or piece.Name == "BottomPanel" then piece:Destroy() end
	end
	Harbour.ensureBoating(bakedV2)
	local hullUpgrade = plazaV2:FindFirstChild("Drydock")
	check(hullUpgrade ~= upgradedV6 and hullUpgrade:GetAttribute("LayoutVersion") == 10
		and hullUpgrade:FindFirstChild("FishingBoatPreview", true):FindFirstChild("BottomPanel", true)
		and hullUpgrade:FindFirstChild("FishingBoatPreview", true):FindFirstChild("HullEndCap", true),
		"Saved open-bottom fishing previews must receive the complete closed hull")
	-- Exercise the real launch controller on geometry emitted by the real builder.
	function frameMethods:Lerp(other, alpha)
		return frame(self.Position:Lerp(other.Position, alpha), self.RightVector, self.UpVector, self.ZVector)
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
	function instanceMethods:GetPivot()
		return self.PrimaryPart.CFrame
	end
	function instanceMethods:FindFirstChildOfClass(class)
		for _, item in self:GetChildren() do
			if item:IsA(class) then
				return item
			end
		end
		return nil
	end
	function instanceMethods:PivotTo(target)
		local previous = self:GetPivot()
		for _, piece in self:GetDescendants() do
			if piece:IsA("BasePart") then
				piece.CFrame = target * previous:ToObjectSpace(piece.CFrame)
			end
		end
	end
	local RaycastParams = {
		new = function()
			return {}
		end,
	}
	local launchPlayers = Instance.new("Players")
	local launchPlayer = Instance.new("Player")
	launchPlayer.UserId, launchPlayer.Parent = 123, launchPlayers
	local waitCount, launchSamples = 0, {}
	local waitHook = nil
	local launchRunService = {
		Heartbeat = {
			Wait = function()
				waitCount += 1
				if waitHook then
					waitHook()
				end
				return 0.25
			end,
		},
	}
	local pendingReturn
	local task = { spawn = function(callback) pendingReturn = callback end }
	local function finishReturn(model)
		local before = model:GetPivot()
		local ticks = 0
		waitHook = function()
			ticks += 1
			if ticks == 4 then model:PivotTo(before + Vector3.new(0, 0, 100)) end
		end
		assert(pendingReturn)()
		pendingReturn = nil
		waitHook = nil
	end
	local function loadDrydockLaunch()
		local game = {
			GetService = function(_, name)
				if name == "RunService" then
					return launchRunService
				end
				if name == "Players" then
					return launchPlayers
				end
				if name == "ReplicatedStorage" then
					return {}
				end
				error(name)
			end,
		}
		-- DRYDOCKLAUNCH_SOURCE --
	end
	local DrydockLaunch = loadDrydockLaunch()
	function workspace:Raycast()
		error("Drydock launches must not query terrain, water depth, boats or obstacles")
	end
	local previewOrigin = shop:GetAttribute("PreviewOriginFrame")
	local launchFinish = shop:GetAttribute("LaunchWaterFrame")
	check(
		typeof(previewOrigin) == "CFrame" and typeof(launchFinish) == "CFrame",
		"The shop must publish camera and launch frames"
	)
	check(math.abs(launchFinish.Position.Y - Biomes.WaterLevel) < EPS, "Launch must finish at the actual waterline")
	for _, offset in
		{ Vector3.zero, Vector3.new(-4, 0, 0), Vector3.new(4, 0, 0), Vector3.new(0, 0, -9), Vector3.new(0, 0, -22) }
	do
		local point = launchFinish * offset
		check(
			Harbour.heightAt(shape, Vector2.new(point.X, point.Z)) < Biomes.WaterLevel - 3.5,
			"Drydock must release the whole hull into deep water with a clear departure"
		)
	end
	local preview = shop:FindFirstChild("LaunchPreview", true)
	local displayPivot = preview:GetPivot()
	for _, piece in preview:GetDescendants() do
		if piece:IsA("BasePart") then
			check((piece.Anchored or piece.Name == "CoolerLid") and not piece.CanCollide, "Preview hull must be anchored and cannot obstruct a launch")
		end
	end
	check(preview:FindFirstChild("RowerSeat", true).Disabled, "Preview cannot be driven before purchase")
	local reservation = assert(DrydockLaunch.reserve(shop, launchPlayer))
	check(reservation ~= nil, "Launch must not perform a water or obstruction precheck")
	check(shop:GetAttribute("LaunchingUserId") == 123, "Reservation must identify the buyer")
	check(DrydockLaunch.reserve(shop, launchPlayer) == nil, "A second buyer must not reserve an occupied slipway")
	DrydockLaunch.release(reservation)
	check(
		shop:GetAttribute("LaunchingUserId") == nil and shop:FindFirstChild("LaunchPreview", true) == preview,
		"A failed purchase releases the slipway without replacing the preview"
	)
	reservation = assert(DrydockLaunch.reserve(shop, launchPlayer))
	waitHook = function()
		table.insert(launchSamples, preview:GetPivot().Position)
	end
	local platform = reservation.cradle
	local originalFloor = platform:FindFirstChild("RearBasinFloor")
	check(originalFloor and platform.PrimaryPart == originalFloor, "Original basin floor must be the lift platform")
	check(not rear:FindFirstChild("LaunchPlatformDeck", true) and not rear:FindFirstChild("LiftAccessWalkway", true),
		"Do not add a second platform or extra access walkways")
	check(math.abs(shopFrame:PointToObjectSpace(previewOrigin.Position).Z - 54) < EPS,
		"Launch preview must stay in the original repair bay")
	check(math.abs(previewOrigin.Position.X - launchFinish.Position.X) < EPS
		and math.abs(previewOrigin.Position.Z - launchFinish.Position.Z) < EPS, "Original platform must launch vertically")
	local movingParts = {}
	for _, piece in platform:GetDescendants() do
		if piece:IsA("BasePart") then movingParts[piece] = piece.CFrame end
	end
	local quay = rear:FindFirstChild("RearQuayWalkway")
	local quayStart = quay.CFrame
	waitHook = function()
		table.insert(launchSamples, preview:GetPivot().Position)
		local offset = platform:GetPivot().Position - reservation.cradleStart.Position
		for piece, original in movingParts do
			check((piece.Position - original.Position - offset).Magnitude < EPS,
				"Original platform pieces must lower together: " .. piece.Name)
		end
		check((quay.Position - quayStart.Position).Magnitude < EPS, "Surrounding quays must stay fixed")
	end
	local activated = 0
	local launchResult = DrydockLaunch.run(reservation, function(player, launchFrame, model)
		activated += 1
		check(
			player == launchPlayer and model == preview,
			"Purchase must activate the exact preview boat for its buyer"
		)
		check(
			(launchFrame.Position - launchFinish.Position).Magnitude < EPS,
			"Activation must use the drydock water marker"
		)
		check(
			(model:GetPivot().Position - (displayPivot.Position + launchFinish.Position - previewOrigin.Position)).Magnitude
				< EPS,
			"Boat geometry must reach the launch water before physics activates"
		)
		model.Name, model.Parent = "PurchasedBoat", root
		return true
	end)
	check(launchResult and activated == 1 and waitCount == 28, "Lowering must run for seven seconds and activate once")
	check(launchSamples[1].Y > launchSamples[#launchSamples].Y, "The boat must visibly descend toward the water")
	for i = 2, #launchSamples do
		check(math.abs(launchSamples[i].Z - launchSamples[1].Z) < EPS and math.abs(launchSamples[i].X - launchSamples[1].X) < EPS, "Lift launch must move straight down without rolling toward the bay")
	end
	DrydockLaunch.release(reservation)
	check(DrydockLaunch.reserve(shop, launchPlayer) == nil, "Lift must remain reserved while boat overlaps it")
	check((reservation.cradle:GetPivot().Position - reservation.cradleStart.Position).Magnitude > 1, "Lift must stay submerged before departure")
	finishReturn(preview)
	check((reservation.cradle:GetPivot().Position - reservation.cradleStart.Position).Magnitude < EPS, "Whole lift must rise after departure")
	local nextPreview = shop:FindFirstChild("LaunchPreview", true)
	check(nextPreview ~= preview and nextPreview.Parent, "Completed launch must replenish the shop preview")
	check(preview.Parent == root, "Replenishing the preview must preserve the purchased boat")
	local fisher = shop:FindFirstChild("FishingBoatPreview", true)
	local fisherPivot, rowPivot = fisher:GetPivot(), nextPreview:GetPivot()
	local fishingOrigin = shop:GetAttribute("FishingBoatPreviewFrame")
	check(DrydockLaunch.reserve(shop, launchPlayer, "UnknownBoat") == nil, "Unknown boats cannot reserve the slipway")
	reservation = assert(DrydockLaunch.reserve(shop, launchPlayer, "FishingBoat"))
	check(
		reservation.boatId == "FishingBoat" and reservation.preview == fisher
			and shop:GetAttribute("LaunchingBoatId") == "FishingBoat",
		"Fishing purchase must reserve its own physical model and advertise its identity"
	)
	check(
		(fisher:GetPivot().Position - (previewOrigin.Position + Vector3.new(0, -0.4, 0))).Magnitude < EPS,
		"Fishing preview must move from its berth onto the shared launch cradle"
	)
	check(
		(nextPreview:GetPivot().Position - (fishingOrigin.Position + Vector3.new(0, -0.4, 0))).Magnitude < EPS,
		"The rowboat must park in the empty side berth instead of overlapping the larger launch"
	)
	DrydockLaunch.release(reservation)
	check(
		shop:FindFirstChild("FishingBoatPreview", true) == fisher
			and (fisher:GetPivot().Position - fisherPivot.Position).Magnitude < EPS
			and (nextPreview:GetPivot().Position - rowPivot.Position).Magnitude < EPS,
		"A failed fishing purchase must restore both previews to their original berths"
	)
	waitHook = nil
	reservation = assert(DrydockLaunch.reserve(shop, launchPlayer, "FishingBoat"))
	check(DrydockLaunch.run(reservation, function(player, launchFrame, model)
		check(
			player == launchPlayer and model == fisher and model:GetAttribute("BoatId") == "FishingBoat",
			"Fishing purchase must activate the same larger preview with its boat identity"
		)
		check(
			(model:GetPivot().Position - (launchFrame.Position + Vector3.new(0, -0.4, 0))).Magnitude < EPS,
			"The larger fishing hull must reach the shared waterline before activation"
		)
		model.Name, model.Parent = "PurchasedFishingBoat", root
		return true
	end), "The fishing boat launch must activate successfully")
	DrydockLaunch.release(reservation)
	finishReturn(fisher)
	local nextFisher = shop:FindFirstChild("FishingBoatPreview", true)
	check(
		nextFisher ~= fisher and nextFisher:GetAttribute("BoatId") == "FishingBoat"
			and (nextFisher:GetPivot().Position - fisherPivot.Position).Magnitude < EPS,
		"Completed fishing launch must replenish the correct hull at its original side berth"
	)
	check(
		fisher.Parent == root and (nextPreview:GetPivot().Position - rowPivot.Position).Magnitude < EPS,
		"Fishing replenishment must preserve the purchased hull and restore the parked rowboat"
	)
	reservation = assert(DrydockLaunch.reserve(shop, launchPlayer))
	local originalPivot = nextPreview:GetPivot()
	waitHook = function()
		if waitCount > 30 then
			error("Interrupted animation")
		end
	end
	check(not pcall(DrydockLaunch.run, reservation, function()
		error("Must not activate")
	end), "An interrupted animation must not activate a partial launch")
	DrydockLaunch.release(reservation)
	check(
		(nextPreview:GetPivot().Position - originalPivot.Position).Magnitude < EPS,
		"Interruption must return the preview to its cradle"
	)
	check(shop:GetAttribute("LaunchingUserId") == nil, "Interruption must free the drydock")
	waitHook = nil
	reservation = assert(DrydockLaunch.reserve(shop, launchPlayer))
	launchPlayer.Parent = nil
	check(DrydockLaunch.run(reservation, function()
		error("Departed player must not receive an active boat")
	end) == nil, "Disconnect must not create an orphan owned boat")
	DrydockLaunch.release(reservation)
	check(
		(nextPreview:GetPivot().Position - originalPivot.Position).Magnitude < EPS,
		"Disconnect must restore the preview"
	)
	-- Camera lifecycle uses the actual camera module and generated preview frames.
	local render, renderDisconnects, cameraTime, streams = nil, 0, 10, 0
	local renderSignal = {
		Connect = function(_, callback)
			render = callback
			return {
				Disconnect = function()
					renderDisconnects += 1
					render = nil
				end,
			}
		end,
	}
	local originalFrame = CFrame.new(10, 20, 30)
	local oldSubject = Instance.new("Humanoid")
	workspace.CurrentCamera = {
		CameraSubject = oldSubject,
		CameraType = Enum.CameraType.Custom,
		FieldOfView = 70,
		CFrame = originalFrame,
		ViewportSize = Vector2.new(1920, 1080),
	}
	function workspace:GetServerTimeNow()
		return cameraTime
	end
	launchPlayers.LocalPlayer = launchPlayer
	function launchPlayer:RequestStreamAroundAsync()
		streams += 1
	end
	local function loadDrydockCamera()
		local game = {
			GetService = function(_, name)
				if name == "Players" then
					return launchPlayers
				end
				if name == "RunService" then
					return { RenderStepped = renderSignal }
				end
				if name == "ReplicatedStorage" then
					return {}
				end
				error(name)
			end,
		}
		local task = {
			spawn = function(callback)
				callback()
			end,
		}
		-- DRYDOCKCAMERA_SOURCE --
	end
	local DrydockCamera = loadDrydockCamera()
	local camera = workspace.CurrentCamera
	DrydockCamera.show(shop, false)
	assert(render)()
	check(
		camera.CameraType == Enum.CameraType.Scriptable and camera.FieldOfView == 50,
		"Browsing must focus the camera on the real drydock"
	)
	local target = previewOrigin.Position + Vector3.new(0, 1, 0)
	check(
		(target - camera.CFrame.Position):Dot(camera.CFrame.RightVector) > 0,
		"Desktop preview must frame the boat beside the left stat panel"
	)
	camera.ViewportSize = Vector2.new(390, 844)
	assert(render)()
	check(
		(target - camera.CFrame.Position):Dot(camera.CFrame.UpVector) > 0,
		"Portrait preview must frame the boat above the bottom stat panel"
	)
	shop:SetAttribute("LaunchStartedAt", cameraTime)
	DrydockCamera.show(shop, true)
	cameraTime += 7
	shop:SetAttribute("LaunchStartedAt", nil)
	assert(render)()
	check(
		(camera.Focus.Position - (launchFinish.Position + Vector3.new(0, 1, 0))).Magnitude < EPS,
		"Launch camera must track the boat all the way into water even after the server frees the bay"
	)
	DrydockCamera.stop()
	check(
		camera.CameraType == Enum.CameraType.Custom
			and camera.CameraSubject == oldSubject
			and camera.CFrame == originalFrame
			and camera.FieldOfView == 70,
		"Closing must restore the original camera settings"
	)
	check(
		render == nil and streams == 2 and renderDisconnects == 2,
		"Changing previews and closing must release render connections and request streaming"
	)
	DrydockCamera.show(shop, false, "FishingBoat")
	assert(render)()
	local fishingScale = math.sqrt(dependencies.BoatCatalog.FishingBoat.Length / dependencies.BoatCatalog.Rowboat.Length)
	check(
		(camera.Focus.Position - (fishingOrigin.Position + Vector3.new(0, fishingScale, 0))).Magnitude < EPS,
		"Browsing the fisher's boat must focus its own berth with room for the larger hull"
	)
	DrydockCamera.stop()
	DrydockCamera.show(shop, false)
	local newCharacter = Instance.new("Model")
	local newHumanoid = Instance.new("Humanoid")
	newHumanoid.Parent, launchPlayer.Character = newCharacter, newCharacter
	DrydockCamera.stop()
	check(camera.CameraSubject == newHumanoid, "Camera recovery must follow the current character after a respawn")
	DrydockCamera.show(shop, false)
	local shopParent = shop.Parent
	shop.Parent = nil
	assert(render)()
	check(
		render == nil and camera.CameraType == Enum.CameraType.Custom,
		"Removing the shop must restore player camera control"
	)
	shop.Parent = shopParent
end
checkLaunchFlow()
assert(failures == 0, tostring(failures) .. " drydock geometry checks failed")
print(
	string.format(
		"PASS: %d actual-builder assertions; %d walk-in route samples, %d rear stair/quay samples, separate boat berths, both preview launches and replenishment, hollow repair basins, submerged slipway, NPC prompt access, detailed docks with four-stud walking lanes, saved-map upgrades and six unchanged water launches. Roblox physics and rendering are not exercised.",
		checks,
		routeSamples,
		rearRouteSamples
	)
)
