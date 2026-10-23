-- Run node scripts/check-shipwright-model.cjs. Production Shipwright is inserted below.
-- Recording mocks exercise rig and interaction construction, not Roblox rendering,
-- native prompt visibility, Humanoid behavior, or live Studio gameplay.

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
local Vector2 = {
	new = function(x, y)
		return { X = x, Y = y }
	end,
}
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
local Instance
Instance = {
	new = function(kind)
		local item = { ClassName = kind, children = {}, attributes = {} }
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
		function item:FindFirstChild(name, recursive)
			for _, child in (if recursive then self:GetDescendants() else self.children) do
				if child.Name == name then
					return child
				end
			end
			return nil
		end
		function item:FindFirstChildOfClass(class)
			for _, child in self.children do
				if child:IsA(class) then
					return child
				end
			end
			return nil
		end
		function item:Destroy()
			local parent = rawget(self, "Parent")
			if parent then
				local at = table.find(parent.children, self)
				if at then
					table.remove(parent.children, at)
				end
			end
			rawset(self, "Parent", nil)
		end
		function item:ApplyDescriptionAsync(description)
			self.AppliedDescription = description
			local character = self.Parent or self
			local shirt = Instance.new("Shirt")
			shirt.Name = "Shirt"
			shirt.ShirtTemplate = "rbxassetid://" .. tostring(description.Shirt)
			shirt.Parent = character
			local pants = Instance.new("Pants")
			pants.Name = "Pants"
			pants.PantsTemplate = "rbxassetid://" .. tostring(description.Pants)
			pants.Parent = character
			for _, spec in { { "HatAccessory", "Hat" }, { "WaistAccessory", "Waist" } } do
				for _, id in string.split(description[spec[1]] or "", ",") do
					local accessory = Instance.new("Accessory")
					accessory.Name = spec[2] .. "Accessory"
					accessory:SetAttribute("AssetId", tonumber(id))
					accessory.Parent = character
				end
			end
		end
		return setmetatable(item, {
			__newindex = function(self, key, value)
				if key == "Parent" then
					local old = rawget(self, "Parent")
					if old then
						local at = table.find(old.children, self)
						if at then
							table.remove(old.children, at)
						end
					end
				end
				rawset(self, key, value)
				if key == "Parent" and value then
					table.insert(value.children, self)
				end
			end,
		})
	end,
}

function CFrame.Angles(x, y, z)
	local cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
	local rx = CFrame.fromMatrix(vector(0, 0, 0), vector(1, 0, 0), vector(0, cx, sx), vector(0, -sx, cx))
	local ry = CFrame.fromMatrix(vector(0, 0, 0), vector(cy, 0, -sy), vector(0, 1, 0), vector(sy, 0, cy))
	local rz = CFrame.fromMatrix(vector(0, 0, 0), vector(cz, sz, 0), vector(-sz, cz, 0), vector(0, 0, 1))
	return rx * ry * rz
end
function frameMeta.__index(a, key)
	if key == "ToObjectSpace" then
		return function(self, other)
			local function inverseVector(v)
				return vector(v:Dot(self.RightVector), v:Dot(self.UpVector), v:Dot(self.ZVector))
			end
			return CFrame.fromMatrix(
				inverseVector(other.Position - self.Position),
				inverseVector(other.RightVector),
				inverseVector(other.UpVector),
				inverseVector(other.ZVector)
			)
		end
	end
end
local function loadShipwright()
	-- SHIPWRIGHT_SOURCE --
end
local Shipwright = loadShipwright()
local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end
local function close(a, b)
	return (a - b).Magnitude < 0.0001
end
check(
	Shipwright.COSMETICS.Shirt == 6500613508
		and Shipwright.COSMETICS.Pants == 6500616492
		and Shipwright.COSMETICS.Hat == 9667880157
		and Shipwright.COSMETICS.Waist == 12127743738,
	"Marketplace cosmetic set"
)
for _, frame in { CFrame.new(0, 0, 0), CFrame.new(50, 8, -32) * CFrame.Angles(0, math.pi / 2, 0) } do
	local npc = Shipwright.build(frame)
	check(npc.Name == "Shipwright" and npc.Parent == nil, "NPC model contract")
	check(npc:GetAttribute("NpcName") == "Mara" and npc:GetAttribute("Role") == "Shipwright", "NPC identity")
	check(npc:GetAttribute("CosmeticsVersion") == 3, "Marketplace appearance must be applied and versioned")
	local primary = npc.PrimaryPart
	check(primary.Name == "HumanoidRootPart", "PrimaryPart is humanoid root")
	check(close(primary.CFrame.Position, (frame * CFrame.new(0, 3, 0)).Position), "Floor origin transform")
	check(close(primary.CFrame.LookVector, frame.LookVector), "NPC faces local -Z")
	local parts, motors, welds, prompts, humanoids, anchors, accessories = 0, 0, 0, 0, 0, 0, 0
	local body, incoming, jointNames, attachments = {}, {}, {}, {}
	for _, item in npc:GetDescendants() do
		if item:IsA("BasePart") then
			parts += 1
			if item.Anchored then
				anchors += 1
			end
			check(item.CanCollide == false and item.CanTouch == false, "NPC must not block players: " .. item.Name)
			if item ~= primary then
				check(not item.Anchored, "Only root anchored")
			end
			body[item.Name] = item
		elseif item.ClassName == "Motor6D" then
			motors += 1
			incoming[item.Part1] = (incoming[item.Part1] or 0) + 1
			jointNames[item.Name] = item
			check(item.Part0 and item.Part1 and item.Parent == item.Part0, "Joint body references")
			check(
				close((item.Part0.CFrame * item.C0).Position, (item.Part1.CFrame * item.C1).Position),
				"Joint attachment agreement: " .. item.Name
			)
		elseif item.ClassName == "WeldConstraint" then
			welds += 1
			incoming[item.Part1] = (incoming[item.Part1] or 0) + 1
			check(item.Part0 and item.Part1 and item.Parent == item.Part1, "Detail attached to body")
		elseif item.ClassName == "Attachment" then
			attachments[item.Name] = item
		elseif item.ClassName == "Shirt" then
			check(item.ShirtTemplate == "rbxassetid://6500613508", "Catalog coverall shirt applied")
		elseif item.ClassName == "Pants" then
			check(item.PantsTemplate == "rbxassetid://6500616492", "Catalog coverall pants applied")
		elseif item.ClassName == "Accessory" then
			accessories += 1
		elseif item.ClassName == "Decal" then
			check(
				item.Name == "face" and item.Parent.Name == "Head" and item.Texture == "rbxasset://textures/face.png",
				"Classic face on the head"
			)
		elseif item.ClassName == "ProximityPrompt" then
			prompts += 1
			check(
				item.Name == "TalkToShipwrightPrompt" and item.Parent.Name == "Head",
				"Talk prompt must target the visible head rather than the buried root"
			)
			check(item.ActionText == "Talk" and item.ObjectText == "Mara · Shipwright", "Talk identity")
			check(
				item.MaxActivationDistance == 8 and item.RequiresLineOfSight == false and item.HoldDuration == 0,
				"Talk interaction contract"
			)
			check(
				item.Enabled and item.Style == "Default" and item.Exclusivity == "AlwaysShow",
				"Talk UI must be enabled and cannot be hidden by camera occlusion or another prompt"
			)
			check(
				item.KeyboardKeyCode == "E" and item.GamepadKeyCode == "ButtonX" and item.ClickablePrompt,
				"Talk must support keyboard, controller, and touch/click"
			)
		elseif item.ClassName == "Humanoid" then
			humanoids += 1
			check(
				item.DisplayName == "Mara · Shipwright"
					and item.RigType == "R6"
					and item.WalkSpeed == 0
					and item.JumpPower == 0
					and item.JumpHeight == 0,
				"Stationary R6 humanoid"
			)
			local appearance = item.AppliedDescription
			check(
				appearance
					and appearance.Shirt == 6500613508
					and appearance.Pants == 6500616492
					and appearance.HatAccessory == "9667880157"
					and appearance.WaistAccessory == "12127743738",
				"Humanoid receives the Marketplace outfit"
			)
		end
	end
	for _, name in { "Head", "Torso", "Right Arm", "Left Arm", "Right Leg", "Left Leg" } do
		check(body[name] ~= nil, "R6 body missing: " .. name)
	end
	for _, spec in
		{
			{ "FaceCenterAttachment", "Head" },
			{ "FaceFrontAttachment", "Head" },
			{ "HairAttachment", "Head" },
			{ "HatAttachment", "Head" },
			{ "BodyBackAttachment", "Torso" },
			{ "BodyFrontAttachment", "Torso" },
			{ "LeftCollarAttachment", "Torso" },
			{ "NeckAttachment", "Torso" },
			{ "RightCollarAttachment", "Torso" },
			{ "WaistBackAttachment", "Torso" },
			{ "WaistCenterAttachment", "Torso" },
			{ "WaistFrontAttachment", "Torso" },
			{ "RightShoulderAttachment", "Right Arm" },
			{ "LeftShoulderAttachment", "Left Arm" },
		}
	do
		local point = attachments[spec[1]]
		check(point and point.Parent == body[spec[2]], "R6 accessory point: " .. spec[1])
	end
	for _, item in npc:GetDescendants() do
		if item:IsA("BasePart") then
			check(
				(incoming[item] or 0) == (if item == primary then 0 else 1),
				"Every secondary part has one body connection: " .. item.Name
			)
		end
	end
	for _, spec in
		{
			{ "RootJoint", primary, body.Torso },
			{ "Neck", body.Torso, body.Head },
			{ "Right Shoulder", body.Torso, body["Right Arm"] },
			{ "Left Shoulder", body.Torso, body["Left Arm"] },
			{ "Right Hip", body.Torso, body["Right Leg"] },
			{ "Left Hip", body.Torso, body["Left Leg"] },
		}
	do
		local joint = jointNames[spec[1]]
		check(joint and joint.Part0 == spec[2] and joint.Part1 == spec[3], "Correct R6 joint topology: " .. spec[1])
	end
	check(anchors == 1 and motors == 6 and welds == 0, "Complete connected R6 assembly")
	check(prompts == 1 and humanoids == 1, "One NPC and talk prompt")
	check(accessories == 2, "Hard hat and tool belt are attached as accessories")
	check(parts < 50, "NPC part budget")
	check(Shipwright.ensureAppearance(npc), "Applied appearance is cached")
	print(
		"Shipwright construction: " .. parts .. " parts, six R6 joints, " .. welds .. " accessory welds, one talk prompt"
	)
end

-- Saved maps may still contain the previous hand-modelled costume. Upgrading
-- them must remove those pieces before the catalog outfit is applied.
local legacy = Instance.new("Model")
legacy.Name = "Shipwright"
local legacyHumanoid = Instance.new("Humanoid")
legacyHumanoid.Name = "Humanoid"
legacyHumanoid.Parent = legacy
for _, name in { "Head", "Torso" } do
	local bodyPart = Instance.new("Part")
	bodyPart.Name = name
	bodyPart.Parent = legacy
end
local legacyHat = Instance.new("Part")
legacyHat.Name = "HardhatCrown"
legacyHat.Parent = legacy
local legacyFace = Instance.new("Decal")
legacyFace.Name = "face"
legacyFace.Parent = legacy:FindFirstChild("Head")
check(Shipwright.ensureAppearance(legacy), "Legacy shipwright must upgrade to Marketplace cosmetics")
check(legacy:FindFirstChild("HardhatCrown") == nil, "Legacy hand-modelled hard hat removed")
local upgradedFace = legacy:FindFirstChild("face", true)
check(
	upgradedFace
		and upgradedFace ~= legacyFace
		and upgradedFace.Parent.Name == "Head"
		and upgradedFace.Texture == "rbxasset://textures/face.png",
	"Legacy face decal replaced with the built-in classic face"
)
check(legacy:GetAttribute("CosmeticsVersion") == 3, "Upgraded shipwright records its appearance version")

print(
	"Shipwright: "
		.. checks
		.. " recording-mock construction checks passed; rendering and native prompt interaction require Studio"
)
