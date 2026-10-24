-- Production sources are inserted by check-rods.mjs. This recording harness
-- verifies connected geometry and motion/reset behavior, not Roblox rendering.
local vectorMeta, vectorMethods = {}, {}
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
	end
	if key == "Unit" then
		return a / a.Magnitude
	end
	return vectorMethods[key]
end
function vectorMethods:Dot(b)
	return self.X * b.X + self.Y * b.Y + self.Z * b.Z
end
function vectorMethods:Cross(b)
	return vector(self.Y * b.Z - self.Z * b.Y, self.Z * b.X - self.X * b.Z, self.X * b.Y - self.Y * b.X)
end
function vectorMethods:Lerp(b, alpha)
	return self + (b - self) * alpha
end
local Vector3 = { new = vector, zero = vector() }
local CFrame, frameMeta, frameMethods = {}, {}, {}
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
frameMeta.__index = frameMethods
function CFrame.fromMatrix(position, right, up, back)
	return setmetatable({ Position = position, RightVector = right, UpVector = up, ZVector = back }, frameMeta)
end
function CFrame.new(x, y, z)
	return CFrame.fromMatrix(
		if type(x) == "table" then x else vector(x, y, z),
		vector(1, 0, 0),
		vector(0, 1, 0),
		vector(0, 0, 1)
	)
end
CFrame.identity = CFrame.new()
function CFrame.Angles(x, y, z)
	local cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
	local rx = CFrame.fromMatrix(vector(), vector(1, 0, 0), vector(0, cx, sx), vector(0, -sx, cx))
	local ry = CFrame.fromMatrix(vector(), vector(cy, 0, -sy), vector(0, 1, 0), vector(sy, 0, cy))
	local rz = CFrame.fromMatrix(vector(), vector(cz, sz, 0), vector(-sz, cz, 0), vector(0, 0, 1))
	return rx * ry * rz
end
function frameMethods:VectorToWorldSpace(value)
	return transform(self, value)
end
function frameMethods:VectorToObjectSpace(value)
	return vector(value:Dot(self.RightVector), value:Dot(self.UpVector), value:Dot(self.ZVector))
end
function frameMethods:Inverse()
	return CFrame.fromMatrix(
		self:VectorToObjectSpace(-self.Position),
		vector(self.RightVector.X, self.UpVector.X, self.ZVector.X),
		vector(self.RightVector.Y, self.UpVector.Y, self.ZVector.Y),
		vector(self.RightVector.Z, self.UpVector.Z, self.ZVector.Z)
	)
end
function frameMethods:ToObjectSpace(other)
	return self:Inverse() * other
end
function frameMethods:ToAxisAngle()
	local angle = math.acos(math.clamp((self.RightVector.X + self.UpVector.Y + self.ZVector.Z - 1) / 2, -1, 1))
	if angle < 0.00001 then
		return vector(1, 0, 0), 0
	end
	return vector(
		self.UpVector.Z - self.ZVector.Y,
		self.ZVector.X - self.RightVector.Z,
		self.RightVector.Y - self.UpVector.X
	) / (2 * math.sin(angle)),
		angle
end
local Color3 = {
	fromRGB = function(...)
		return { ... }
	end,
}
local ColorSequence, NumberSequence =
	{
		new = function(value)
			return value
		end,
	}, {
		new = function(value)
			return value
		end,
	}
local Enum = setmetatable({}, {
	__index = function(self, key)
		local values = setmetatable({}, {
			__index = function(_, value)
				return value
			end,
		})
		rawset(self, key, values)
		return values
	end,
})
local function signal()
	local listeners = {}
	return {
		Connect = function(_, callback)
			listeners[callback] = true
			return {
				Disconnect = function()
					listeners[callback] = nil
				end,
			}
		end,
		Fire = function(_, ...)
			for callback in table.clone(listeners) do
				callback(...)
			end
		end,
		Count = function()
			local count = 0
			for _ in listeners do
				count += 1
			end
			return count
		end,
	}
end
local Instance = {}
function Instance.new(kind)
	local props = { ClassName = kind, children = {}, attributes = {}, Destroying = signal() }
	if kind == "Motor6D" then
		props.C0, props.C1, props.Transform = CFrame.identity, CFrame.identity, CFrame.identity
	end
	local methods = {}
	function methods:SetAttribute(key, value)
		props.attributes[key] = value
	end
	function methods:GetAttribute(key)
		return props.attributes[key]
	end
	function methods:IsA(class)
		return class == kind or (class == "BasePart" and kind == "Part")
	end
	function methods:GetDescendants()
		local all = {}
		local function add(parent)
			for _, child in parent.children do
				table.insert(all, child)
				add(child)
			end
		end
		add(self)
		return all
	end
	function methods:FindFirstChild(name)
		for _, child in props.children do
			if child.Name == name then
				return child
			end
		end
		return nil
	end
	function methods:FindFirstChildOfClass(class)
		for _, child in props.children do
			if child:IsA(class) then
				return child
			end
		end
		return nil
	end
	function methods:IsDescendantOf(parent)
		local current = props.Parent
		while current do
			if current == parent then
				return true
			end
			current = current.Parent
		end
		return false
	end
	function methods:Destroy()
		props.Destroying:Fire()
		for _, child in table.clone(props.children) do
			child:Destroy()
		end
		self.Parent = nil
	end
	return setmetatable({}, {
		__index = function(_, key)
			return methods[key] or props[key]
		end,
		__newindex = function(self, key, value)
			if key == "Parent" then
				if props.Parent then
					local index = table.find(props.Parent.children, self)
					if index then
						table.remove(props.Parent.children, index)
					end
				end
				if value then
					table.insert(value.children, self)
				end
				if kind == "WeldConstraint" and value then
					props.offset = props.Part0.CFrame:ToObjectSpace(props.Part1.CFrame)
				end
			end
			props[key] = value
		end,
	})
end
local workspace = Instance.new("Workspace")
workspace.Gravity = 196.2
local added, removed = signal(), signal()
local tags = {}
local collection = {
	AddTag = function(_, item, tag)
		tags[item] = tag
		added:Fire(item)
	end,
	GetTagged = function(_, tag)
		local result = {}
		for item, value in tags do
			if value == tag then
				table.insert(result, item)
			end
		end
		return result
	end,
	GetInstanceAddedSignal = function()
		return added
	end,
	GetInstanceRemovedSignal = function()
		return removed
	end,
}
local run = { PreSimulation = signal() }
local game = {
	GetService = function(_, name)
		if name == "CollectionService" then
			return collection
		end
		if name == "RunService" then
			return run
		end
		return {}
	end,
}
local function loadDynamics()
	-- ROD_DYNAMICS_SOURCE --
end
local dynamics = loadDynamics()
local function loadRod()
	-- FISHING_ROD_SOURCE --
end
local rodFactory = loadRod()
local function loadClient()
	-- ROD_CLIENT_SOURCE --
end
local client = loadClient()
local checks = 0
local function check(condition, message)
	checks += 1
	assert(condition, message)
end
local function near(a, b)
	return math.abs(a - b) < 0.00001
end
local function sameFrame(a, b)
	return (a.Position - b.Position).Magnitude < 0.00001
		and (a.RightVector - b.RightVector).Magnitude < 0.00001
		and (a.UpVector - b.UpVector).Magnitude < 0.00001
end
local stop = client.start()
check(client.start() == stop and run.PreSimulation:Count() == 1, "start must be idempotent")
local tool = rodFactory.build()
local handle = tool:FindFirstChild("Handle")
check(
	tool.Parent == nil and tool.Name == "Starter fishing rod" and tool:GetAttribute("RodId") == "StarterRod",
	"Tool identity"
)
check(tool.CanBeDropped == false and tool.RequiresHandle and handle:IsA("BasePart"), "Tool equipment settings")
local heldShaft = tool.Grip:Inverse():VectorToWorldSpace(vector(0, 1, 0))
check(heldShaft.Z < -0.7 and heldShaft.Y > 0, "held rod must point forward and above the water")
local parts, hinges, welds, beams = {}, {}, {}, {}
for _, item in tool:GetDescendants() do
	if item:IsA("BasePart") then
		table.insert(parts, item)
		check(
			not item.Anchored and item.Massless and not item.CanCollide and not item.CanTouch and not item.CanQuery,
			"unsafe physics part " .. item.Name
		)
		check(item.Size.X > 0 and item.Size.Y > 0 and item.Size.Z > 0, "invalid part dimensions")
	elseif item.ClassName == "Motor6D" then
		table.insert(hinges, item)
		check(
			sameFrame(item.Part0.CFrame * item.C0 * item.C1:Inverse(), item.Part1.CFrame),
			"neutral hinge does not join actual part frames"
		)
	elseif item.ClassName == "WeldConstraint" then
		table.insert(welds, item)
	elseif item.ClassName == "Beam" then
		table.insert(beams, item)
	end
end
check(#parts < 80 and #hinges == 9 and #beams == 6, "rod geometry or articulation budget")
local reached = { [handle] = true }
for _ = 1, #parts do
	for _, joint in hinges do
		if reached[joint.Part0] then
			reached[joint.Part1] = true
		end
	end
	for _, joint in welds do
		if reached[joint.Part0] then
			reached[joint.Part1] = true
		end
	end
end
for _, part in parts do
	check(reached[part], "loose part " .. part.Name)
end
for _, beam in beams do
	check(
		beam.Attachment0
			and beam.Attachment1
			and beam.Attachment0.Parent:IsA("BasePart")
			and beam.Attachment1.Parent:IsA("BasePart"),
		"line is disconnected"
	)
end
local function solve()
	for _ = 1, 10 do
		for _, joint in hinges do
			joint.Part1.CFrame = joint.Part0.CFrame * joint.C0 * joint.Transform * joint.C1:Inverse()
		end
		for _, joint in welds do
			joint.Part1.CFrame = joint.Part0.CFrame * joint.offset
		end
	end
end
local first = tool:FindFirstChild("RodSegment1"):FindFirstChild("RodBend1")
first.Transform = CFrame.Angles(0.2, 0, 0)
solve()
check(tool:FindFirstChild("RodSegment8").CFrame.Position.Z > 0.5, "hinge X must bend the upright shaft toward Z")
first.Transform = CFrame.identity
solve()

local zero = { bendX = 0, bendZ = 0, bobX = 0, bobZ = 0 }
local results = {}
for _, rate in { 10, 30, 60, 120 } do
	local state = dynamics.new()
	for step = 1, rate do
		dynamics.step(state, 1 / rate, { bendX = 0.3, bendZ = -0.2, bobX = 0.4, bobZ = -0.3 })
	end
	check(state.bendX > 0.28 and state.bendX < 0.32 and state.bobX > 0.3, "rod does not respond to applied motion")
	table.insert(results, state.bendX)
	for _ = 1, rate * 8 do
		dynamics.step(state, 1 / rate, zero)
	end
	check(math.abs(state.bendX) < 0.00001 and math.abs(state.bobX) < 0.0001, "springs do not settle")
	dynamics.step(state, 1 / rate, { bendX = math.huge, bendZ = -math.huge, bobX = math.huge, bobZ = -math.huge })
	check(math.abs(state.bendX) < 0.55 and math.abs(state.bobX) < 0.8, "unbounded spring under extreme motion")
	check(
		dynamics.step(state, 1, zero) == false and state.bendX == 0 and state.bobX == 0,
		"large dt must clear springs"
	)
end
for _, value in results do
	check(near(value, results[1]), "spring response depends on frame rate")
end

local backpack = Instance.new("Backpack")
tool.Parent = backpack
run.PreSimulation:Fire(1 / 60)
check(sameFrame(first.Transform, CFrame.identity), "backpack rod is simulated")
local character = Instance.new("Model")
character.Parent = workspace
local humanoid = Instance.new("Humanoid")
humanoid.Health, humanoid.Parent = 100, character
tool.Parent = character
local baseFrame = CFrame.new(0, 4, 0) * CFrame.Angles(-0.6, 0, 0)
local function tick(frame, dt)
	handle.CFrame = frame
	run.PreSimulation:Fire(dt or 1 / 60)
	solve()
end
for _ = 1, 120 do
	tick(baseFrame)
end
local rest = first.Transform.UpVector
local peak = 0
for step = 1, 60 do
	tick(CFrame.new(step / 10, 4, 0) * CFrame.Angles(-0.6, step / 80, 0))
	peak = math.max(peak, (first.Transform.UpVector - rest).Magnitude)
end
check(peak > 0.001, `walking and turning did not flex the rod (base hinge deflection {peak})`)
local sideways = CFrame.new(6, 4, 0) * CFrame.Angles(0, 0, math.pi / 2)
for _ = 1, 600 do
	tick(sideways)
end
local bobber = tool:FindFirstChild("RodBobber")
local bobberJoint = bobber:FindFirstChild("BobberSwing")
local tipPosition = (bobberJoint.Part0.CFrame * bobberJoint.C0).Position
check(
	(bobber.CFrame.Position - tipPosition - vector(0, -1.25, 0)).Magnitude < 0.001,
	"float should hang in world gravity when rod is sideways"
)
tool.Parent = backpack
run.PreSimulation:Fire(1 / 60)
for _, hinge in hinges do
	check(sameFrame(hinge.Transform, CFrame.identity), "unequip does not reset articulation")
end
tool.Parent = character
tick(CFrame.new(1000, 4, 0))
check(sameFrame(first.Transform, CFrame.identity), "teleport/re-equip must not inject stale velocity")
tick(CFrame.new(1000, 4, 0), 0.3)
check(sameFrame(first.Transform, CFrame.identity), "frame hitch does not reset articulation")
local lastSegment = tool:FindFirstChild("RodSegment8")
lastSegment.Parent = nil
tick(CFrame.new(1000, 4, 0))
check(sameFrame(first.Transform, CFrame.identity), "streamed-out segment must suspend simulation")
lastSegment.Parent = tool
for _ = 1, 30 do
	tick(CFrame.new(1000, 4, 0) * CFrame.Angles(-0.6, 0, 0))
end
check(not sameFrame(first.Transform, CFrame.identity), "streamed-in segment did not rebind")
humanoid.Health = 0
run.PreSimulation:Fire(1 / 60)
check(sameFrame(first.Transform, CFrame.identity), "death must reset articulation")
tool:Destroy()
run.PreSimulation:Fire(1 / 60)
stop()
check(run.PreSimulation:Count() == 0 and added:Count() == 0 and removed:Count() == 0, "client stop leaked connections")
print(
	`Fishing rod: {checks} checks passed; connected model, frame-rate-independent springs, movement, world-gravity float, streaming, unequip/death/teleport cleanup (recording mocks)`
)
