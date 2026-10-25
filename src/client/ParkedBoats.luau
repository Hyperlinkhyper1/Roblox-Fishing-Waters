-- Parked hulls are anchored on the server so movers never fight people on deck.
-- Each client rolls them on the shared swell clock instead; the server releases
-- a hull at that same pose (Weather.parkedOffset), so driving off never snaps.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Weather = require(ReplicatedStorage.Shared.Weather)

local ParkedBoats = {}
local started = false

function ParkedBoats.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local heldRoot, heldBoat, heldAt, heldPosition
	-- Before physics, so a local character standing on deck collides with this pose.
	RunService.PreSimulation:Connect(function()
		local folder = workspace:FindFirstChild("PlayerBoats")
		if not folder then
			heldRoot, heldBoat, heldAt, heldPosition = nil, nil, nil, nil
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local avatarRoot = character and character:FindFirstChild("HumanoidRootPart")
		local ground
		if
			humanoid
			and avatarRoot
			and avatarRoot:IsA("BasePart")
			and humanoid.Health > 0
			and not avatarRoot.Anchored
			and not humanoid.SeatPart
			and not humanoid.Sit
			and not humanoid.Jump
			and humanoid.FloorMaterial ~= Enum.Material.Air
		then
			local state = humanoid:GetState()
			if
				state == Enum.HumanoidStateType.Running
				or state == Enum.HumanoidStateType.RunningNoPhysics
				or state == Enum.HumanoidStateType.Landed
			then
				local parameters = RaycastParams.new()
				parameters.FilterType = Enum.RaycastFilterType.Exclude
				parameters.FilterDescendantsInstances = { character }
				parameters.IgnoreWater = true
				parameters.RespectCanCollide = true
				parameters.CollisionGroup = avatarRoot.CollisionGroup
				-- R6 has zero HipHeight, but its legs still put the root above deck.
				local reach = math.max(3, humanoid.HipHeight + avatarRoot.Size.Y / 2) + 0.75
				ground = workspace:Raycast(avatarRoot.Position, Vector3.new(0, -reach, 0), parameters)
			end
		end
		local now = workspace:GetServerTimeNow()
		local holding = false
		for _, model in folder:GetChildren() do
			local root = model:IsA("Model") and model.PrimaryPart
			local rest, parkedAt = model:GetAttribute("ParkedFrame"), model:GetAttribute("ParkedAt")
			if
				root
				and root.Anchored
				and model:GetAttribute("Parked")
				and typeof(rest) == "CFrame"
				and type(parkedAt) == "number"
			then
				-- The hull is rigid, so its pivot keeps one offset from the root.
				local before = root.CFrame
				local pivot = rest * root.CFrame:ToObjectSpace(model:GetPivot())
				model:PivotTo(
					Weather.parkedOffset(
						rest,
						parkedAt,
						now,
						model:GetAttribute("DryFloorHeight"),
						model:GetAttribute("DryFloorHalfBeam"),
						model:GetAttribute("DryFloorHalfLength"),
						model:GetAttribute("WaterlineRootOffset")
					) * pivot
				)
				if ground and ground.Instance:IsDescendantOf(model) then
					local position = before:PointToObjectSpace(avatarRoot.Position)
					if humanoid.MoveDirection.Magnitude < 0.01 then
						-- CFrame animation supplies no platform velocity. Keep an idle
						-- rider at their deck position instead of accumulating slope slip.
						if
							heldRoot ~= avatarRoot
							or heldBoat ~= model
							or heldAt ~= parkedAt
							or not heldPosition
							or (position - heldPosition).Magnitude > 3
						then
							heldPosition = position
						end
						heldRoot, heldBoat, heldAt = avatarRoot, model, parkedAt
						position = Vector3.new(heldPosition.X, position.Y, heldPosition.Z)
						local velocity = avatarRoot.AssemblyLinearVelocity
						avatarRoot.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
						holding = true
					end
					-- Carry translation and tilt around the hull pivot while keeping
					-- the humanoid upright. Walking remains relative to the deck.
					local target = root.CFrame:PointToWorldSpace(position)
					avatarRoot.CFrame += target - avatarRoot.Position
				end
			end
		end
		if not holding then
			heldRoot, heldBoat, heldAt, heldPosition = nil, nil, nil, nil
		end
	end)
end

return ParkedBoats
