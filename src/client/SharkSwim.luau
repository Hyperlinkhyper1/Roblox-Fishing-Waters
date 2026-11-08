-- The invisible server-owned root remains the combat and navigation position.
-- Only the visible pieces are interpolated locally between server updates.
local RunService = game:GetService("RunService")

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
-- Joints in server SharkModel: SwimFlex pieces bend at the hips and SwimTail
-- pieces bend there and again at the tail stalk, so a wave runs down the body.
local FLEX_PIVOT = CFrame.new(0, -1.4, 1.6)
local TAIL_PIVOT = CFrame.new(0, -1.35, 3.2)
local FLEX_PIVOT_INVERSE = FLEX_PIVOT:Inverse()
local TAIL_PIVOT_INVERSE = TAIL_PIVOT:Inverse()
local SMOOTHING = 22
local REFRESH_INTERVAL = 0.5
-- Every piece is rewritten when a shark moves; past this range the body wave
-- can't be seen, so far sharks step every few frames.
local NEAR_DISTANCE = 250
local FAR_STRIDE = 4

function SharkSwim.start()
	local folder = workspace:WaitForChild("Sharks")
	local states = {}
	local function add(model)
		if model:IsA("Model") and not states[model] then
			states[model] = { parts = {}, refresh = 0, phase = math.random() * math.pi * 2 }
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
				state.frame = nil
				continue
			end
			local target = root.CFrame
			if not state.frame or (state.frame.Position - target.Position).Magnitude > 35 then
				state.frame = target
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
							local joint = if piece:GetAttribute("SwimTail") == true
								then "tail"
								elseif piece:GetAttribute("SwimFlex") == true then "flex"
								else nil
							table.insert(parts, { part = piece, offset = offset, joint = joint })
						end
					end
				end
				state.parts = parts
			end
			if eye and (state.frame.Position - eye).Magnitude > NEAR_DISTANCE and (frame + math.floor(state.phase * 10)) % FAR_STRIDE ~= 0 then
				continue
			end
			-- The head swings against the tail, each joint lagging the one ahead.
			local phase = now * 5 + state.phase
			local body = state.frame * CFrame.Angles(0, math.sin(phase) * 0.03, math.sin(phase - 0.6) * 0.035)
			local flex = FLEX_PIVOT * CFrame.Angles(0, math.sin(phase - 1.3) * 0.15, 0) * FLEX_PIVOT_INVERSE
			local joints = {
				flex = body * flex,
				tail = body
					* flex
					* TAIL_PIVOT
					* CFrame.Angles(0, math.sin(phase - 2.3) * 0.32, 0)
					* TAIL_PIVOT_INVERSE,
			}
			for _, entry in state.parts do
				if entry.part:IsDescendantOf(model) then
					table.insert(moved, entry.part)
					table.insert(frames, (if entry.joint then joints[entry.joint] else body) * entry.offset)
				end
			end
		end
		if #moved > 0 then
			workspace:BulkMoveTo(moved, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end))
end

return SharkSwim
