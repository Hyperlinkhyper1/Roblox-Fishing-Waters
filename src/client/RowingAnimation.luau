-- Procedural strokes need no uploaded animation asset and support R6 and R15.
-- Every client animates the boats it has streamed in, including other players.
local RunService = game:GetService("RunService")
local RowingAnimation = {}
local started = false

local function restoreArms(record)
	for joint in record.arms do
		if joint.Parent then
			joint.Transform = CFrame.identity
		end
	end
	record.arms = {}
	record.occupant = nil
end

function RowingAnimation.start()
	if started then return end
	started = true
	local records = {}
	RunService.PreSimulation:Connect(function(dt)
		local folder = workspace:FindFirstChild("PlayerBoats")
		if folder then
			for _, model in folder:GetChildren() do
				if model:GetAttribute("BoatId") == "Rowboat" and not records[model] then
					local seat = model:FindFirstChild("RowerSeat", true)
					if seat then
						local oars = {}
						for _, joint in model:GetDescendants() do
							if joint:IsA("Motor6D") and joint:GetAttribute("RowSide") then
								oars[joint] = joint:GetAttribute("RowSide")
							end
						end
						records[model] = { seat = seat, oars = oars, drives = {}, arms = {}, blend = 0 }
					end
				end
			end
		end
		local phase = workspace:GetServerTimeNow() * math.pi * 1.5
		for model, record in records do
			if model.Parent ~= folder or not record.seat:IsDescendantOf(model) then
				restoreArms(record)
				for joint in record.oars do
					if joint.Parent then joint.Transform = CFrame.identity end
				end
				records[model] = nil
				continue
			end
			local occupant = record.seat.Occupant
			if occupant ~= record.occupant then
				restoreArms(record)
				record.occupant = occupant
				if occupant and occupant.Parent then
					for _, joint in occupant.Parent:GetDescendants() do
						if joint:IsA("Motor6D") then
							if joint.Name == "LeftShoulder" or joint.Name == "Left Shoulder" then
								record.arms[joint] = -1
							elseif joint.Name == "RightShoulder" or joint.Name == "Right Shoulder" then
								record.arms[joint] = 1
							end
						end
					end
				end
			end
			local throttle = if occupant and occupant.Health > 0 then model:GetAttribute("RowThrottle") or 0 else 0
			local steer = if occupant and occupant.Health > 0 then model:GetAttribute("RowSteer") or 0 else 0
			local effort = math.max(math.abs(throttle), math.abs(steer))
			record.blend += (effort - record.blend) * (1 - math.exp(-8 * math.min(dt, 0.1)))
			for joint, side in record.oars do
				local target = math.clamp(throttle + side * steer, -1, 1)
				local drive = (record.drives[joint] or 0)
				drive += (target - drive) * (1 - math.exp(-8 * math.min(dt, 0.1)))
				record.drives[joint] = drive
				local direction = if drive < 0 then -1 else 1
				local strength = math.abs(drive)
				joint.Transform = CFrame.Angles(0, side * math.sin(phase) * 0.38 * direction * strength,
					side * math.max(0, math.cos(phase)) * 0.16 * strength)
			end
			for joint, side in record.arms do
				local drive = math.clamp(throttle + side * steer, -1, 1)
				local stroke = math.sin(phase) * (if drive < 0 then -1 else 1)
				local pose = CFrame.Angles(-0.95 + stroke * 0.32, side * 0.12, side * 0.12)
				-- R6 shoulders use rotated joint bases; rotate in torso space.
				local rotation = joint.C0.Rotation
				pose = rotation:Inverse() * pose * rotation
				if record.blend > 0.001 then
					joint.Transform = CFrame.identity:Lerp(pose, record.blend)
				elseif record.posed then
					joint.Transform = CFrame.identity
				end
			end
			record.posed = record.blend > 0.001
		end
	end)
end

return RowingAnimation
