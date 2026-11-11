-- The invisible server-owned root remains the combat and navigation position.
-- Only the visible pieces are animated locally:
--   * a travelling body wave: each SharkShape joint bends in turn, lagging the
--     one ahead, from a steady head to a sweeping tail;
--   * a tail beat that quickens and deepens with swimming speed (chases);
--   * banking into turns;
--   * the lower jaw: barely parted while cruising, agape while hunting a boat,
--     snapping wide and shut on each bite (server "Hunting" / "BiteAt").
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SharkShape = require(ReplicatedStorage:WaitForChild("Shared").SharkShape)

-- Names this module's per-frame work in the MicroProfiler (otherwise it is all "Script_Client").
local function profiled<A...>(label: string, callback: (A...) -> ()): (A...) -> ()
	if not debug.profilebegin then
		return callback -- test runners without the MicroProfiler API
	end
	return function(...: A...)
		debug.profilebegin(label)
		callback(...)
		debug.profileend()
	end
end

local SharkSwim = {}
local JOINTS = {}
for index, joint in SharkShape.joints() do
	local pivot = CFrame.new(joint.pivot[1], joint.pivot[2], joint.pivot[3])
	JOINTS[index] = { pivot = pivot, inverse = pivot:Inverse(), amplitude = joint.amplitude, lag = joint.lag }
end
local jawPoint = SharkShape.jawPivot()
local JAW_PIVOT = CFrame.new(jawPoint[1], jawPoint[2], jawPoint[3])
local JAW_INVERSE = JAW_PIVOT:Inverse()
local SMOOTHING = 22
local REFRESH_INTERVAL = 0.5
-- Every piece is rewritten when a shark moves; past this range the body wave
-- can't be seen, so far sharks step every few frames.
local NEAR_DISTANCE = 250
local FAR_STRIDE = 4
-- Tail beat in radians per second, from cruising to a full chase (studs/s).
local CRUISE_BEAT, CHASE_BEAT, CHASE_SPEED = 4.5, 11, 55
local MAX_BANK = 0.35
-- Bite: open wide over BITE_OPEN seconds, slam shut over BITE_CLOSE, then hold.
local BITE_OPEN, BITE_CLOSE, BITE_HOLD = 0.15, 0.1, 0.25

local function approach(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-rate * dt))
end

-- How far the jaw is open (radians) for this shark now.
local function jawOpening(model: Model, state, now: number, dt: number): number
	local hunting = model:GetAttribute("Hunting") == true
	local target = if hunting
		then 0.26 + 0.08 * math.sin(now * 2.3 + state.seed)
		else 0.05 + 0.03 * math.sin(now * 0.9 + state.seed)
	state.jaw = approach(state.jaw, target, 6, dt)
	local biteAt = model:GetAttribute("BiteAt")
	if type(biteAt) == "number" then
		local age = now - biteAt
		if age >= 0 and age < BITE_OPEN then
			return SharkShape.JAW_OPEN * age / BITE_OPEN
		elseif age >= BITE_OPEN and age < BITE_OPEN + BITE_CLOSE then
			state.jaw = 0
			return SharkShape.JAW_OPEN * (1 - (age - BITE_OPEN) / BITE_CLOSE)
		elseif age >= 0 and age < BITE_OPEN + BITE_CLOSE + BITE_HOLD then
			state.jaw = 0
			return 0
		end
	end
	return state.jaw
end

function SharkSwim.start()
	local folder = workspace:WaitForChild("Sharks")
	local states = {}
	local function add(model)
		if model:IsA("Model") and not states[model] then
			local seed = math.random() * math.pi * 2
			states[model] = { parts = {}, refresh = 0, phase = seed, seed = seed, speed = 0, roll = 0, jaw = 0 }
		end
	end
	for _, model in folder:GetChildren() do
		add(model)
	end
	folder.ChildAdded:Connect(add)
	folder.ChildRemoved:Connect(function(model)
		states[model] = nil
	end)

	local frame = 0
	RunService.RenderStepped:Connect(profiled("SharkSwim", function(dt)
		frame += 1
		local camera = workspace.CurrentCamera
		local eye = camera and camera.CFrame.Position
		local now = workspace:GetServerTimeNow()
		local alpha = 1 - math.exp(-SMOOTHING * math.min(dt, 0.25))
		local moved, frames = {}, {}
		for model, state in states do
			local root = model.PrimaryPart
			if not root or not root:IsDescendantOf(model) then
				-- Streaming can remove and later restore the root and its pieces.
				state.frame, state.lastPosition, state.lastLook = nil, nil, nil
				continue
			end
			local target = root.CFrame
			if not state.frame or (state.frame.Position - target.Position).Magnitude > 35 then
				state.frame, state.lastPosition, state.lastLook = target, nil, nil
			else
				state.frame = state.frame:Lerp(target, alpha)
			end
			if now >= state.refresh then
				state.refresh = now + REFRESH_INTERVAL
				local parts = {}
				for _, piece in model:GetDescendants() do
					if piece:IsA("BasePart") and piece ~= root then
						local offset = piece:GetAttribute("SwimOffset")
						if typeof(offset) == "CFrame" then
							local segment = piece:GetAttribute("SwimSegment")
							table.insert(parts, {
								part = piece,
								offset = offset,
								segment = if type(segment) == "number" then segment else 0,
								jaw = piece:GetAttribute("SwimJaw") == true,
							})
						end
					end
				end
				state.parts = parts
			end

			-- Speed and turning come from the smoothed frame, so they follow what is seen.
			local step = math.max(dt, 1e-3)
			local position, look = state.frame.Position, state.frame.LookVector
			if state.lastPosition then
				local speed = math.min((position - state.lastPosition).Magnitude / step, 80)
				state.speed = approach(state.speed, speed, 3, dt)
			end
			if state.lastLook then
				local turn = math.atan2(state.lastLook:Cross(look).Y, state.lastLook:Dot(look)) / step
				state.roll = approach(state.roll, math.clamp(turn * 0.3, -MAX_BANK, MAX_BANK), 4, dt)
			end
			state.lastPosition, state.lastLook = position, look
			local effort = math.clamp(state.speed / CHASE_SPEED, 0, 1)
			state.phase += dt * (CRUISE_BEAT + (CHASE_BEAT - CRUISE_BEAT) * effort)
			local opening = jawOpening(model, state, now, dt)

			if
				eye
				and (position - eye).Magnitude > NEAR_DISTANCE
				and (frame + math.floor(state.seed * 10)) % FAR_STRIDE ~= 0
			then
				continue
			end
			-- The head swings against the tail; each joint lags the one ahead.
			local wave = state.phase
			local strength = 0.9 + 0.5 * effort
			local body = state.frame
				* CFrame.Angles(0, math.sin(wave) * 0.035 * strength, state.roll + math.sin(wave - 0.6) * 0.02)
			local segments = { [0] = body }
			for index, joint in JOINTS do
				segments[index] = segments[index - 1]
					* joint.pivot
					* CFrame.Angles(0, math.sin(wave - joint.lag) * joint.amplitude * strength, 0)
					* joint.inverse
			end
			local jaw = body * JAW_PIVOT * CFrame.Angles(-opening, 0, 0) * JAW_INVERSE
			for _, entry in state.parts do
				if entry.part:IsDescendantOf(model) then
					table.insert(moved, entry.part)
					local carrier = if entry.jaw then jaw else segments[entry.segment] or body
					table.insert(frames, carrier * entry.offset)
				end
			end
		end
		if #moved > 0 then
			workspace:BulkMoveTo(moved, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end))
end

return SharkSwim
