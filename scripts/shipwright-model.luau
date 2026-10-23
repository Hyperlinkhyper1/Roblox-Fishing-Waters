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
local Instance = {
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
		return setmetatable(item, {
			__newindex = function(self, key, value)
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
for _, frame in { CFrame.new(0, 0, 0), CFrame.new(50, 8, -32) * CFrame.Angles(0, math.pi / 2, 0) } do
	local npc = Shipwright.build(frame)
	check(npc.Name == "Shipwright" and npc.Parent == nil, "NPC model contract")
	check(npc:GetAttribute("NpcName") == "Mara" and npc:GetAttribute("Role") == "Shipwright", "NPC identity")
	local primary = npc.PrimaryPart
	check(primary.Name == "HumanoidRootPart", "PrimaryPart is humanoid root")
	check(close(primary.CFrame.Position, (frame * CFrame.new(0, 3, 0)).Position), "Floor origin transform")
	check(close(primary.CFrame.LookVector, frame.LookVector), "NPC faces local -Z")
	local parts, motors, welds, prompts, humanoids, anchors = 0, 0, 0, 0, 0, 0
	local body, incoming, jointNames = {}, {}, {}
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
					and item.WalkSpeed == 0
					and item.JumpPower == 0
					and item.JumpHeight == 0,
				"Stationary humanoid"
			)
		elseif item.ClassName == "Decal" then
			check(
				item.Name == "face" and item.Face == "Front" and item.Texture == "rbxasset://textures/face.png",
				"Native front face"
			)
		end
	end
	for _, name in { "Head", "Torso", "Right Arm", "Left Arm", "Right Leg", "Left Leg" } do
		check(body[name] ~= nil, "R6 body missing: " .. name)
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
	check(anchors == 1 and motors == 6 and welds == parts - 7, "Complete connected R6 assembly")
	check(prompts == 1 and humanoids == 1, "One NPC and talk prompt")
	check(parts < 50, "NPC part budget")
	print(
		"Shipwright construction: " .. parts .. " parts, six R6 joints, " .. welds .. " detail welds, one talk prompt"
	)
end
print(
	"Shipwright: "
		.. checks
		.. " recording-mock construction checks passed; rendering and native prompt interaction require Studio"
)
