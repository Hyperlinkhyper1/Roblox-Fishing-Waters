-- Each client derives bend from replicated handle movement, including rods held
-- by other players. No per-frame remotes or server physics forces are needed.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local RodDynamics = require(ReplicatedStorage.Shared.RodDynamics)

local RodPhysics = {}
local stopCurrent: (() -> ())? = nil

local function limit(vector: Vector3, maximum: number): Vector3
	local magnitude = vector.Magnitude
	return if magnitude > maximum then vector * (maximum / magnitude) else vector
end

function RodPhysics.start()
	if stopCurrent then
		return stopCurrent
	end
	local records = {}
	local connections = {}
	local elapsed = 0

	local function reset(record)
		RodDynamics.reset(record.spring)
		record.lastFrame, record.linearVelocity, record.angularVelocity = nil, Vector3.zero, Vector3.zero
		record.acceleration, record.angularAcceleration = Vector3.zero, Vector3.zero
		if record.binding then
			for _, hinge in record.binding.hinges do
				hinge.joint.Transform = CFrame.identity
			end
			record.binding.bobber.Transform = CFrame.identity
		end
	end
	local function remove(tool)
		local record = records[tool]
		if record then
			reset(record)
			if record.destroying then
				record.destroying:Disconnect()
			end
			records[tool] = nil
		end
	end
	local function add(tool)
		if not tool:IsA("Tool") or tool:GetAttribute("RodId") ~= "StarterRod" or records[tool] then
			return
		end
		local record = { spring = RodDynamics.new(), nextBind = 0, active = false }
		records[tool] = record
		record.destroying = tool.Destroying:Connect(function()
			remove(tool)
		end)
		reset(record)
	end
	local function bind(tool, record)
		local handle = tool:FindFirstChild("Handle")
		local bobberPart = tool:FindFirstChild("RodBobber")
		local bobber = if bobberPart then bobberPart:FindFirstChild("BobberSwing") else nil
		if not handle or not handle:IsA("BasePart") or not bobber or not bobber:IsA("Motor6D") then
			return false
		end
		local hinges = {}
		for _, child in tool:GetDescendants() do
			if child:IsA("Motor6D") and child:GetAttribute("RodSegment") then
				if not child.Part0 or not child.Part1 then
					return false
				end
				table.insert(hinges, {
					joint = child,
					index = child:GetAttribute("RodSegment"),
					weight = child:GetAttribute("FlexWeight"),
				})
			end
		end
		if #hinges ~= tool:GetAttribute("RodSegmentCount") then
			return false
		end
		table.sort(hinges, function(a, b)
			return a.index < b.index
		end)
		if not bobber.Part0 or not bobber.Part1 then
			return false
		end
		record.binding = {
			handle = handle,
			bobber = bobber,
			hinges = hinges,
			lineLength = tool:GetAttribute("RodLineLength") or 1.25,
		}
		reset(record)
		return true
	end
	local function bindingPresent(tool, binding)
		if not binding.handle:IsDescendantOf(tool) or not binding.bobber:IsDescendantOf(tool) then
			return false
		end
		for _, hinge in binding.hinges do
			local joint = hinge.joint
			if
				not joint:IsDescendantOf(tool)
				or not joint.Part0
				or not joint.Part1
				or not joint.Part0:IsDescendantOf(tool)
				or not joint.Part1:IsDescendantOf(tool)
			then
				return false
			end
		end
		return binding.bobber.Part0 ~= nil and binding.bobber.Part1 ~= nil
	end
	local function articulate(record, dt: number)
		local binding = record.binding
		local frame = binding.handle.CFrame
		local previous = record.lastFrame
		if not previous or dt <= 0 or dt > 0.15 or (frame.Position - previous.Position).Magnitude > 12 then
			reset(record)
			record.lastFrame = frame
			return
		end
		record.lastFrame = frame
		local linearVelocity = limit((frame.Position - previous.Position) / dt, 100)
		local axis, angle = previous:ToObjectSpace(frame):ToAxisAngle()
		local angularVelocity = limit(previous:VectorToWorldSpace(axis * (angle / dt)), 14)
		local smoothing = 1 - math.exp(-14 * dt)
		record.acceleration =
			record.acceleration:Lerp(limit((linearVelocity - record.linearVelocity) / dt, 150), smoothing)
		record.angularAcceleration =
			record.angularAcceleration:Lerp(limit((angularVelocity - record.angularVelocity) / dt, 90), smoothing)
		record.linearVelocity, record.angularVelocity = linearVelocity, angularVelocity
		local acceleration = frame:VectorToObjectSpace(record.acceleration)
		local rotation = frame:VectorToObjectSpace(angularVelocity)
		local angularAcceleration = frame:VectorToObjectSpace(record.angularAcceleration)
		local gravity = workspace.Gravity
		local localGravity = frame:VectorToObjectSpace(Vector3.new(0, -gravity, 0))
		local spring = record.spring
		-- Wrist rotations from walking packs change direction rapidly. Their
		-- angular acceleration should add a little flex, not whip the shaft.
		RodDynamics.step(spring, dt, {
			bendX = (localGravity.Z * 0.14 - acceleration.Z) * 0.0028
				- rotation.X * 0.018
				- angularAcceleration.X * 0.0012,
			bendZ = (-localGravity.X * 0.14 + acceleration.X) * 0.0028
				- rotation.Z * 0.018
				- angularAcceleration.Z * 0.0012,
			bobX = -record.acceleration.X / math.max(gravity, 32),
			bobZ = -record.acceleration.Z / math.max(gravity, 32),
		})
		-- Reconstruct this frame's chain instead of reading last frame's segment
		-- positions; the Motor6D batch is applied after PreSimulation finishes.
		local parentFrame = frame
		for _, hinge in binding.hinges do
			local joint = hinge.joint
			local flex = hinge.weight * 0.27
			local transform = CFrame.Angles(spring.bendX * flex, 0, spring.bendZ * flex)
			joint.Transform = transform
			parentFrame = parentFrame * joint.C0 * transform * joint.C1:Inverse()
		end
		local tipFrame = parentFrame * binding.bobber.C0
		local direction = Vector3.new(spring.bobX, -1, spring.bobZ).Unit
		local desired = CFrame.new(tipFrame.Position + direction * binding.lineLength)
		binding.bobber.Transform = tipFrame:ToObjectSpace(desired) * binding.bobber.C1
	end

	for _, tool in CollectionService:GetTagged("FishingRod") do
		add(tool)
	end
	table.insert(connections, CollectionService:GetInstanceAddedSignal("FishingRod"):Connect(add))
	table.insert(connections, CollectionService:GetInstanceRemovedSignal("FishingRod"):Connect(remove))
	table.insert(
		connections,
		RunService.PreSimulation:Connect(function(dt)
			elapsed += dt
			for tool, record in records do
				local character = tool.Parent
				local humanoid = if character and character:IsA("Model")
					then character:FindFirstChildOfClass("Humanoid")
					else nil
				local equipped = humanoid and humanoid.Health > 0 and character:IsDescendantOf(workspace)
				if not equipped then
					if record.active then
						reset(record)
						record.active = false
					end
					continue
				end
				if record.binding and not bindingPresent(tool, record.binding) then
					reset(record)
					record.binding = nil
					record.nextBind = elapsed
				end
				if not record.binding then
					if elapsed < record.nextBind then
						continue
					end
					record.nextBind = elapsed + 0.25
					if not bind(tool, record) then
						continue
					end
				end
				record.active = true
				articulate(record, dt)
			end
		end)
	)
	stopCurrent = function()
		for _, connection in connections do
			connection:Disconnect()
		end
		for tool in records do
			remove(tool)
		end
		stopCurrent = nil
	end
	return stopCurrent
end

return RodPhysics
